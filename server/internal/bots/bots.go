package bots

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/auth"
	"github.com/uri-travoski/workchat/server/internal/db"
	"github.com/uri-travoski/workchat/server/internal/hub"
)

type BotService struct {
	database *db.DB
	hub      *hub.Hub
	client   *http.Client
}

func New(database *db.DB, h *hub.Hub) *BotService {
	return &BotService{
		database: database,
		hub:      h,
		client:   &http.Client{Timeout: 15 * time.Second},
	}
}

func (s *BotService) CreateBot(username, displayName, description, createdBy string) (*db.Bot, *db.User, error) {
	token, err := auth.GenerateSecureToken(24)
	if err != nil {
		return nil, nil, err
	}
	botToken := fmt.Sprintf("%d:%s", time.Now().Unix()%1000000000, token)

	userID := uuid.New().String()
	now := db.NowMs()

	var newBot db.Bot
	var newUser db.User

	err = s.database.WithLock(func(tx *sql.Tx) error {
		// Insert bot user
		_, err := tx.Exec(`INSERT INTO users (id, username, display_name, password_hash, role, is_bot, created_ms)
                          VALUES (?, ?, ?, 'BOT_NO_PASSWORD', 'member', 1, ?)`,
			userID, username, displayName, now)
		if err != nil {
			return err
		}

		// Insert bot metadata
		_, err = tx.Exec(`INSERT INTO bots (user_id, description, token, home, created_by, created_ms)
                          VALUES (?, ?, ?, '{"blocks":[]}', ?, ?)`,
			userID, description, botToken, createdBy, now)
		if err != nil {
			return err
		}

		newBot = db.Bot{
			UserID:      userID,
			Description: description,
			Token:       botToken,
			Home:        `{"blocks":[]}`,
			CreatedBy:   &createdBy,
			CreatedMs:   now,
		}
		newUser = db.User{
			ID:          userID,
			Username:    username,
			DisplayName: displayName,
			Role:        "member",
			IsBot:       true,
			CreatedMs:   now,
		}
		return nil
	})

	if err != nil {
		return nil, nil, err
	}

	return &newBot, &newUser, nil
}

func (s *BotService) FindBotByToken(token string) (*db.Bot, *db.User, error) {
	var bot db.Bot
	var user db.User
	var createdBy, webhookURL, webhookSecret, webhookError sql.NullString
	var webhookErrorMs sql.NullInt64

	query := `SELECT b.user_id, b.description, b.token, b.home, b.webhook_url, b.webhook_secret, b.webhook_error, b.webhook_error_ms, b.created_by, b.created_ms,
                     u.id, u.username, u.display_name
              FROM bots b
              JOIN users u ON b.user_id = u.id
              WHERE b.token = ?`

	err := s.database.QueryRow(query, token).Scan(
		&bot.UserID, &bot.Description, &bot.Token, &bot.Home, &webhookURL, &webhookSecret, &webhookError, &webhookErrorMs, &createdBy, &bot.CreatedMs,
		&user.ID, &user.Username, &user.DisplayName,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil, errors.New("bot not found")
		}
		return nil, nil, err
	}

	if createdBy.Valid {
		bot.CreatedBy = &createdBy.String
	}
	if webhookURL.Valid {
		bot.WebhookURL = &webhookURL.String
	}
	if webhookSecret.Valid {
		bot.WebhookSecret = &webhookSecret.String
	}
	if webhookError.Valid {
		bot.WebhookError = &webhookError.String
	}
	if webhookErrorMs.Valid {
		bot.WebhookErrorMs = &webhookErrorMs.Int64
	}

	return &bot, &user, nil
}

// Telegram-compatible API response wrapper
type TelegramResp struct {
	Ok          bool        `json:"ok"`
	Result      interface{} `json:"result,omitempty"`
	Description string      `json:"description,omitempty"`
	ErrorCode   int         `json:"error_code,omitempty"`
}

func (s *BotService) HandleTelegramRequest(w http.ResponseWriter, r *http.Request, token, method string) {
	bot, user, err := s.FindBotByToken(token)
	if err != nil {
		writeTelegramJSON(w, http.StatusUnauthorized, TelegramResp{Ok: false, ErrorCode: 401, Description: "Unauthorized: invalid bot token"})
		return
	}

	switch method {
	case "getMe":
		writeTelegramJSON(w, http.StatusOK, TelegramResp{
			Ok: true,
			Result: map[string]interface{}{
				"id":         1000 + len(user.ID),
				"is_bot":     true,
				"first_name": user.DisplayName,
				"username":   user.Username,
			},
		})

	case "sendMessage":
		var body map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeTelegramJSON(w, http.StatusBadRequest, TelegramResp{Ok: false, Description: "invalid json body"})
			return
		}

		chatIDStr := fmt.Sprintf("%v", body["chat_id"])
		text, _ := body["text"].(string)
		if text == "" {
			writeTelegramJSON(w, http.StatusBadRequest, TelegramResp{Ok: false, Description: "text is required"})
			return
		}

		replyToMsgID, _ := body["reply_to_message_id"].(string)

		msg, err := s.PostBotMessage(bot.UserID, chatIDStr, text, replyToMsgID)
		if err != nil {
			writeTelegramJSON(w, http.StatusInternalServerError, TelegramResp{Ok: false, Description: err.Error()})
			return
		}

		writeTelegramJSON(w, http.StatusOK, TelegramResp{
			Ok: true,
			Result: map[string]interface{}{
				"message_id": msg.ID,
				"text":       msg.Body,
				"date":       msg.Ts / 1000,
				"chat": map[string]interface{}{
					"id": msg.ConvID,
				},
			},
		})

	case "editMessageText":
		var body map[string]interface{}
		json.NewDecoder(r.Body).Decode(&body)
		msgID, _ := body["message_id"].(string)
		newText, _ := body["text"].(string)

		now := db.NowMs()
		_, err := s.database.Exec("UPDATE messages SET body = ?, edited_ms = ? WHERE id = ? AND sender_id = ?",
			newText, now, msgID, bot.UserID)
		if err != nil {
			writeTelegramJSON(w, http.StatusInternalServerError, TelegramResp{Ok: false, Description: err.Error()})
			return
		}

		writeTelegramJSON(w, http.StatusOK, TelegramResp{Ok: true, Result: true})

	case "deleteMessage":
		var body map[string]interface{}
		json.NewDecoder(r.Body).Decode(&body)
		msgID, _ := body["message_id"].(string)

		_, err := s.database.Exec("UPDATE messages SET deleted = 1 WHERE id = ? AND sender_id = ?", msgID, bot.UserID)
		if err != nil {
			writeTelegramJSON(w, http.StatusInternalServerError, TelegramResp{Ok: false, Description: err.Error()})
			return
		}
		writeTelegramJSON(w, http.StatusOK, TelegramResp{Ok: true, Result: true})

	case "setWebhook":
		var body map[string]interface{}
		json.NewDecoder(r.Body).Decode(&body)
		webhookURL, _ := body["url"].(string)
		secretToken, _ := body["secret_token"].(string)

		s.database.Exec("UPDATE bots SET webhook_url = ?, webhook_secret = ? WHERE user_id = ?",
			webhookURL, secretToken, bot.UserID)

		writeTelegramJSON(w, http.StatusOK, TelegramResp{Ok: true, Result: true, Description: "Webhook was set"})

	case "getWebhookInfo":
		writeTelegramJSON(w, http.StatusOK, TelegramResp{
			Ok: true,
			Result: map[string]interface{}{
				"url":                  bot.WebhookURL,
				"has_custom_certificate": false,
				"pending_update_count": 0,
			},
		})

	case "getUpdates":
		offsetStr := r.URL.Query().Get("offset")
		offset, _ := strconv.ParseInt(offsetStr, 10, 64)

		rows, err := s.database.Query("SELECT id, data FROM bot_updates WHERE bot_id = ? AND id >= ? ORDER BY id ASC LIMIT 100",
			bot.UserID, offset)
		if err != nil {
			writeTelegramJSON(w, http.StatusInternalServerError, TelegramResp{Ok: false, Description: err.Error()})
			return
		}
		defer rows.Close()

		var results []map[string]interface{}
		for rows.Next() {
			var id int64
			var data string
			if err := rows.Scan(&id, &data); err == nil {
				var parsed map[string]interface{}
				json.Unmarshal([]byte(data), &parsed)
				parsed["update_id"] = id
				results = append(results, parsed)
			}
		}

		writeTelegramJSON(w, http.StatusOK, TelegramResp{Ok: true, Result: results})

	default:
		writeTelegramJSON(w, http.StatusNotFound, TelegramResp{Ok: false, ErrorCode: 404, Description: "Method not found"})
	}
}

func (s *BotService) PostBotMessage(botUserID, convID, body, replyTo string) (*db.Message, error) {
	// Auto-join bot to conv if not member
	s.database.Exec("INSERT OR IGNORE INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'member', ?)",
		convID, botUserID, db.NowMs())

	msgID := uuid.New().String()
	now := db.NowMs()

	var nextSeq int64
	err := s.database.WithLock(func(tx *sql.Tx) error {
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

		var replyToPtr *string
		if replyTo != "" {
			replyToPtr = &replyTo
		}

		_, err = tx.Exec(`INSERT INTO messages (id, conv_id, seq, sender_id, body, kind, ts, version, deleted, reply_to, mentions)
                          VALUES (?, ?, ?, ?, ?, 'text', ?, 1, 0, ?, '[]')`,
			msgID, convID, nextSeq, botUserID, body, now, replyToPtr)
		return err
	})

	if err != nil {
		return nil, err
	}

	msg := &db.Message{
		ID:       msgID,
		ConvID:   convID,
		Seq:      nextSeq,
		SenderID: botUserID,
		Body:     body,
		Kind:     "text",
		Ts:       now,
		Version:  1,
	}

	// Emit event to members
	s.hub.EmitToMembers(convID, "message_created", convID, msg)

	return msg, nil
}

// QueueBotUpdate queues an update for bots listening to a conversation.
func (s *BotService) QueueBotUpdate(convID string, message *db.Message) {
	rows, err := s.database.Query(`SELECT b.user_id, b.webhook_url, b.webhook_secret
                                   FROM bots b
                                   JOIN members m ON b.user_id = m.user_id
                                   WHERE m.conv_id = ? AND b.user_id != ?`, convID, message.SenderID)
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var botID string
		var webhookURL, webhookSecret *string
		if err := rows.Scan(&botID, &webhookURL, &webhookSecret); err == nil {
			updatePayload := map[string]interface{}{
				"message": map[string]interface{}{
					"message_id": message.ID,
					"text":       message.Body,
					"date":       message.Ts / 1000,
					"chat": map[string]interface{}{
						"id": message.ConvID,
					},
					"from": map[string]interface{}{
						"id": message.SenderID,
					},
				},
			}
			updateBytes, _ := json.Marshal(updatePayload)

			// Store in bot_updates
			s.database.Exec("INSERT INTO bot_updates (bot_id, data, created_ms) VALUES (?, ?, ?)",
				botID, string(updateBytes), db.NowMs())

			// If webhook configured, dispatch async
			if webhookURL != nil && *webhookURL != "" {
				go s.dispatchBotWebhook(*webhookURL, webhookSecret, updateBytes)
			}
		}
	}
}

func (s *BotService) dispatchBotWebhook(url string, secret *string, body []byte) {
	req, err := http.NewRequest("POST", url, strings.NewReader(string(body)))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	if secret != nil && *secret != "" {
		req.Header.Set("X-Telegram-Bot-Api-Secret-Token", *secret)
	}
	s.client.Do(req)
}

func writeTelegramJSON(w http.ResponseWriter, code int, resp TelegramResp) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(resp)
}
