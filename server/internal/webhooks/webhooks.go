package webhooks

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/db"
	"github.com/uri-travoski/workchat/server/internal/hub"
)

type WebhookService struct {
	database *db.DB
	hub      *hub.Hub
	client   *http.Client
}

func New(database *db.DB, h *hub.Hub) *WebhookService {
	return &WebhookService{
		database: database,
		hub:      h,
		client:   &http.Client{Timeout: 10 * time.Second},
	}
}

func (s *WebhookService) StartDeliveryWorker() {
	go func() {
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			s.processDueDeliveries()
		}
	}()
}

func (s *WebhookService) processDueDeliveries() {
	now := db.NowMs()
	rows, err := s.database.Query("SELECT id, kind, ref_id, url, secret, event, body, attempts FROM deliveries WHERE state = 'pending' AND next_ms <= ? LIMIT 50", now)
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var id int64
		var kind, refID, url, event, body string
		var secret *string
		var attempts int

		if err := rows.Scan(&id, &kind, &refID, &url, &secret, &event, &body, &attempts); err == nil {
			go s.deliver(id, url, secret, event, body, attempts)
		}
	}
}

func (s *WebhookService) deliver(id int64, url string, secret *string, event, body string, attempts int) {
	req, err := http.NewRequest("POST", url, bytes.NewBufferString(body))
	if err != nil {
		s.failDelivery(id, attempts, err.Error(), 0)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-WorkChat-Event", event)
	req.Header.Set("User-Agent", "WorkChat-Webhook-Delivery/1.1")

	if secret != nil && *secret != "" {
		mac := hmac.New(sha256.New, []byte(*secret))
		mac.Write([]byte(body))
		sig := hex.EncodeToString(mac.Sum(nil))
		req.Header.Set("X-WorkChat-Signature", "sha256="+sig)
	}

	resp, err := s.client.Do(req)
	now := db.NowMs()
	if err != nil {
		s.failDelivery(id, attempts, err.Error(), 0)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		s.database.Exec("UPDATE deliveries SET state = 'delivered', done_ms = ?, last_status = ? WHERE id = ?", now, resp.StatusCode, id)
	} else {
		s.failDelivery(id, attempts, fmt.Sprintf("HTTP %d", resp.StatusCode), resp.StatusCode)
	}
}

func (s *WebhookService) failDelivery(id int64, attempts int, errMsg string, statusCode int) {
	now := db.NowMs()
	newAttempts := attempts + 1
	if newAttempts >= 5 {
		s.database.Exec("UPDATE deliveries SET state = 'failed', done_ms = ?, attempts = ?, last_error = ?, last_status = ? WHERE id = ?",
			now, newAttempts, errMsg, statusCode, id)
	} else {
		// Exponential backoff: 5s, 15s, 45s, 135s
		nextDelay := int64(5 * (1 << (newAttempts - 1)) * 1000)
		s.database.Exec("UPDATE deliveries SET next_ms = ?, attempts = ?, last_error = ?, last_status = ? WHERE id = ?",
			now+nextDelay, newAttempts, errMsg, statusCode, id)
	}
}

// QueueOutgoingWebhook queues an event for all registered outgoing webhooks.
func (s *WebhookService) QueueOutgoingWebhook(event string, convID string, payload interface{}) {
	rows, err := s.database.Query("SELECT id, url, secret, conv_id FROM webhooks_out WHERE enabled = 1")
	if err != nil {
		return
	}
	defer rows.Close()

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return
	}

	now := db.NowMs()
	for rows.Next() {
		var id, url string
		var secret, filterConvID *string
		if err := rows.Scan(&id, &url, &secret, &filterConvID); err == nil {
			if filterConvID != nil && *filterConvID != "" && *filterConvID != convID {
				continue
			}
			s.database.Exec(`INSERT INTO deliveries (kind, ref_id, url, secret, event, body, attempts, next_ms, state, created_ms)
                             VALUES ('webhook', ?, ?, ?, ?, ?, 0, ?, 'pending', ?)`,
				id, url, secret, event, string(bodyBytes), now, now)
		}
	}
}

// HandleIncomingWebhook processes an incoming webhook POST at /hooks/{id}/{secret}.
func (s *WebhookService) HandleIncomingWebhook(w http.ResponseWriter, r *http.Request, hookID, secret string) {
	var convID, botUserID string
	var enabled int
	err := s.database.QueryRow("SELECT conv_id, bot_user_id, enabled FROM webhooks_in WHERE id = ? AND secret = ?", hookID, secret).
		Scan(&convID, &botUserID, &enabled)

	if err != nil || enabled == 0 {
		http.Error(w, `{"error":"invalid or disabled webhook"}`, http.StatusUnauthorized)
		return
	}

	var payload struct {
		Text string `json:"text"`
		Body string `json:"body"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}

	text := payload.Text
	if text == "" {
		text = payload.Body
	}
	if text == "" {
		http.Error(w, `{"error":"body is required"}`, http.StatusBadRequest)
		return
	}

	now := db.NowMs()
	s.database.Exec("UPDATE webhooks_in SET last_used_ms = ? WHERE id = ?", now, hookID)

	msgID := uuid.New().String()
	var nextSeq int64
	err = s.database.WithLock(func(tx *sql.Tx) error {
		var curSeq int64
		err := tx.QueryRow("SELECT last_seq FROM conversations WHERE id = ?", convID).Scan(&curSeq)
		if err != nil {
			return err
		}
		nextSeq = curSeq + 1

		_, err = tx.Exec("UPDATE conversations SET last_seq = ?, last_ts = ? WHERE id = ?", nextSeq, now, convID)
		if err != nil {
			return err
		}

		_, err = tx.Exec(`INSERT INTO messages (id, conv_id, seq, sender_id, body, kind, ts, version, deleted, mentions)
                          VALUES (?, ?, ?, ?, ?, 'text', ?, 1, 0, '[]')`,
			msgID, convID, nextSeq, botUserID, text, now)
		return err
	})

	if err != nil {
		http.Error(w, `{"error":"failed to save message"}`, http.StatusInternalServerError)
		return
	}

	msg := db.Message{
		ID:       msgID,
		ConvID:   convID,
		Seq:      nextSeq,
		SenderID: botUserID,
		Body:     text,
		Kind:     "text",
		Ts:       now,
		Version:  1,
	}

	s.hub.EmitToMembers(convID, "message_created", convID, msg)
	s.QueueOutgoingWebhook("message_created", convID, msg)

	log.Printf("Incoming webhook %s delivered message %s", hookID, msgID)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"ok": true, "message_id": msgID})
}
