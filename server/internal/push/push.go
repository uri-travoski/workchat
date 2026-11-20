package push

import (
	"bytes"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/db"
)

type Notifier struct {
	database *db.DB
	ntfyURL  string
	client   *http.Client
}

func New(database *db.DB, ntfyURL string) *Notifier {
	return &Notifier{
		database: database,
		ntfyURL:  ntfyURL,
		client:   &http.Client{Timeout: 10 * time.Second},
	}
}

type PushPayload struct {
	Title    string `json:"title"`
	Body     string `json:"body"`
	ConvID   string `json:"conv_id"`
	MsgID    string `json:"msg_id"`
	IsHidden bool   `json:"is_hidden"`
}

func (n *Notifier) NotifyUser(targetUserID string, payload PushPayload) {
	rows, err := n.database.Query("SELECT id, kind, target, ntfy_url FROM push_registrations WHERE user_id = ?", targetUserID)
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var id, kind, target string
		var customNtfyURL *string
		if err := rows.Scan(&id, &kind, &target, &customNtfyURL); err == nil {
			go n.dispatch(kind, target, customNtfyURL, payload)
		}
	}
}

func (n *Notifier) dispatch(kind, target string, customNtfyURL *string, payload PushPayload) {
	// If hidden chat, suppress sensitive details according to PRD section 4.4:
	// "Incoming notifications for hidden chats must not leak sender names or message previews on lock screens or notification banners."
	title := payload.Title
	body := payload.Body
	if payload.IsHidden {
		title = "WorkChat"
		body = "New encrypted message received"
	}

	switch kind {
	case "ntfy", "unifiedpush":
		url := n.ntfyURL
		if customNtfyURL != nil && *customNtfyURL != "" {
			url = *customNtfyURL
		}
		if url == "" {
			return
		}

		endpoint := fmt.Sprintf("%s/%s", strings.TrimRight(url, "/"), target)
		req, err := http.NewRequest("POST", endpoint, strings.NewReader(body))
		if err != nil {
			return
		}
		req.Header.Set("Title", title)
		req.Header.Set("Priority", "default")
		req.Header.Set("Tags", "speech_balloon")
		req.Header.Set("Click", fmt.Sprintf("workchat://conv/%s", payload.ConvID))

		n.client.Do(req)

	case "fcm":
		// FCM relay
		// When configured in settings, forward to Firebase Cloud Messaging HTTP v1 API
	case "apns":
		// Apple Push Notification service relay
	}
}

func (n *Notifier) Register(userID, sessionID, kind, target, ntfyURL, deviceName string) (*db.PushRegistration, error) {
	id := uuid.New().String()
	now := db.NowMs()

	query := `INSERT INTO push_registrations (id, user_id, session_id, kind, target, ntfy_url, device_name, created_ms)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)`

	_, err := n.database.Exec(query, id, userID, sessionID, kind, target, ntfyURL, deviceName, now)
	if err != nil {
		return nil, err
	}

	return &db.PushRegistration{
		ID:         id,
		UserID:     userID,
		SessionID:  &sessionID,
		Kind:       kind,
		Target:     target,
		NtfyURL:    &ntfyURL,
		DeviceName: deviceName,
		CreatedMs:  now,
	}, nil
}

func (n *Notifier) Unregister(userID, registrationID string) error {
	_, err := n.database.Exec("DELETE FROM push_registrations WHERE id = ? AND user_id = ?", registrationID, userID)
	return err
}

func (n *Notifier) List(userID string) ([]db.PushRegistration, error) {
	rows, err := n.database.Query("SELECT id, user_id, session_id, kind, target, ntfy_url, device_name, created_ms FROM push_registrations WHERE user_id = ?", userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []db.PushRegistration
	for rows.Next() {
		var r db.PushRegistration
		var sid, nurl *string
		if err := rows.Scan(&r.ID, &r.UserID, &sid, &r.Kind, &r.Target, &nurl, &r.DeviceName, &r.CreatedMs); err == nil {
			r.SessionID = sid
			r.NtfyURL = nurl
			list = append(list, r)
		}
	}
	return list, nil
}

func (n *Notifier) PublishNtfyTest(topic, title, message string) error {
	if n.ntfyURL == "" {
		return fmt.Errorf("ntfy URL not configured")
	}
	endpoint := fmt.Sprintf("%s/%s", strings.TrimRight(n.ntfyURL, "/"), topic)
	req, err := http.NewRequest("POST", endpoint, bytes.NewBufferString(message))
	if err != nil {
		return err
	}
	req.Header.Set("Title", title)
	resp, err := n.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return fmt.Errorf("ntfy returned status %d", resp.StatusCode)
	}
	return nil
}
