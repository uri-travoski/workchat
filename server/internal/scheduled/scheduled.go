package scheduled

import (
	"database/sql"
	"encoding/json"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/db"
	"github.com/uri-travoski/workchat/server/internal/hub"
)

type ScheduledWorker struct {
	database *db.DB
	hub      *hub.Hub
}

func New(database *db.DB, h *hub.Hub) *ScheduledWorker {
	return &ScheduledWorker{
		database: database,
		hub:      h,
	}
}

func (w *ScheduledWorker) Start() {
	go func() {
		ticker := time.NewTicker(1 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			w.processDue()
		}
	}()
}

func (w *ScheduledWorker) processDue() {
	now := db.NowMs()
	rows, err := w.database.Query("SELECT id, user_id, conv_id, body, thread_root, attachment_ids FROM scheduled WHERE state = 'pending' AND due_ms <= ? LIMIT 20", now)
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var id, userID, convID, body, attIDsJSON string
		var threadRoot *string
		if err := rows.Scan(&id, &userID, &convID, &body, &threadRoot, &attIDsJSON); err == nil {
			w.dispatchMessage(id, userID, convID, body, threadRoot, attIDsJSON)
		}
	}
}

func (w *ScheduledWorker) dispatchMessage(schedID, userID, convID, body string, threadRoot *string, attIDsJSON string) {
	msgID := uuid.New().String()
	now := db.NowMs()

	var nextSeq int64
	err := w.database.WithLock(func(tx *sql.Tx) error {
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

		_, err = tx.Exec(`INSERT INTO messages (id, conv_id, seq, sender_id, body, kind, ts, version, deleted, thread_root, mentions)
                          VALUES (?, ?, ?, ?, ?, 'text', ?, 1, 0, ?, '[]')`,
			msgID, convID, nextSeq, userID, body, now, threadRoot)
		if err != nil {
			return err
		}

		// Attach any attachments
		var attIDs []string
		json.Unmarshal([]byte(attIDsJSON), &attIDs)
		for _, attID := range attIDs {
			tx.Exec("INSERT INTO message_attachments (message_id, attachment_id) VALUES (?, ?)", msgID, attID)
		}

		// Mark scheduled as sent
		_, err = tx.Exec("UPDATE scheduled SET state = 'sent', message_id = ?, done_ms = ? WHERE id = ?",
			msgID, now, schedID)
		return err
	})

	if err != nil {
		log.Printf("Failed to dispatch scheduled message %s: %v", schedID, err)
		w.database.Exec("UPDATE scheduled SET state = 'failed', error = ? WHERE id = ?", err.Error(), schedID)
		return
	}

	msg := db.Message{
		ID:         msgID,
		ConvID:     convID,
		Seq:        nextSeq,
		SenderID:   userID,
		Body:       body,
		Kind:       "text",
		Ts:         now,
		Version:    1,
		ThreadRoot: threadRoot,
	}

	w.hub.EmitToMembers(convID, "message_created", convID, msg)
}

func (w *ScheduledWorker) Create(userID, convID, body string, threadRoot *string, attachmentIDs []string, dueMs int64) (*db.ScheduledMessage, error) {
	id := uuid.New().String()
	now := db.NowMs()
	attJSON, _ := json.Marshal(attachmentIDs)

	query := `INSERT INTO scheduled (id, user_id, conv_id, body, thread_root, attachment_ids, due_ms, created_ms, state)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')`

	_, err := w.database.Exec(query, id, userID, convID, body, threadRoot, string(attJSON), dueMs, now)
	if err != nil {
		return nil, err
	}

	return &db.ScheduledMessage{
		ID:            id,
		UserID:        userID,
		ConvID:        convID,
		Body:          body,
		ThreadRoot:    threadRoot,
		AttachmentIDs: string(attJSON),
		DueMs:         dueMs,
		CreatedMs:     now,
		State:         "pending",
	}, nil
}

func (w *ScheduledWorker) Cancel(userID, id string) error {
	_, err := w.database.Exec("UPDATE scheduled SET state = 'cancelled' WHERE id = ? AND user_id = ? AND state = 'pending'", id, userID)
	return err
}

func (w *ScheduledWorker) List(userID string) ([]db.ScheduledMessage, error) {
	rows, err := w.database.Query("SELECT id, user_id, conv_id, body, thread_root, attachment_ids, due_ms, created_ms, state, error, message_id, done_ms FROM scheduled WHERE user_id = ? ORDER BY due_ms ASC", userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []db.ScheduledMessage
	for rows.Next() {
		var s db.ScheduledMessage
		if err := rows.Scan(&s.ID, &s.UserID, &s.ConvID, &s.Body, &s.ThreadRoot, &s.AttachmentIDs, &s.DueMs, &s.CreatedMs, &s.State, &s.Error, &s.MessageID, &s.DoneMs); err == nil {
			list = append(list, s)
		}
	}
	return list, nil
}
