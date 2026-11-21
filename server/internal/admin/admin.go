package admin

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/auth"
	"github.com/uri-travoski/workchat/server/internal/backup"
	"github.com/uri-travoski/workchat/server/internal/db"
	"github.com/uri-travoski/workchat/server/internal/hub"
)

type AdminHandler struct {
	database  *db.DB
	hub       *hub.Hub
	backupMgr *backup.BackupManager
	publicURL string
}

func New(database *db.DB, h *hub.Hub, bm *backup.BackupManager, publicURL string) *AdminHandler {
	return &AdminHandler{
		database:  database,
		hub:       h,
		backupMgr: bm,
		publicURL: publicURL,
	}
}

func (a *AdminHandler) Overview(w http.ResponseWriter, r *http.Request) {
	var userCount, convCount, msgCount, attCount, attTotalSize int64

	a.database.QueryRow("SELECT COUNT(*) FROM users WHERE deleted = 0").Scan(&userCount)
	a.database.QueryRow("SELECT COUNT(*) FROM conversations WHERE archived = 0").Scan(&convCount)
	a.database.QueryRow("SELECT COUNT(*) FROM messages WHERE deleted = 0").Scan(&msgCount)
	a.database.QueryRow("SELECT COUNT(*), COALESCE(SUM(size), 0) FROM attachments WHERE removed = 0").Scan(&attCount, &attTotalSize)

	res := map[string]interface{}{
		"users_count":         userCount,
		"conversations_count": convCount,
		"messages_count":      msgCount,
		"attachments_count":   attCount,
		"storage_bytes":       attTotalSize,
		"server_version":      "1.2.3",
		"now_ms":              db.NowMs(),
	}

	writeJSON(w, http.StatusOK, res)
}

func (a *AdminHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	rows, err := a.database.Query(`SELECT id, username, display_name, email, role, disabled, deleted, privacy_controls_enabled, hide_last_active, presence_pref, last_active_ms, avatar_attachment, is_bot, created_ms
                                   FROM users ORDER BY created_ms ASC`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var users []db.User
	for rows.Next() {
		var u db.User
		var email, avatar sql.NullString
		var lastActive sql.NullInt64

		if err := rows.Scan(&u.ID, &u.Username, &u.DisplayName, &email, &u.Role, &u.Disabled, &u.Deleted, &u.PrivacyControlsEnabled, &u.HideLastActive, &u.PresencePref, &lastActive, &avatar, &u.IsBot, &u.CreatedMs); err == nil {
			if email.Valid {
				u.Email = &email.String
			}
			if lastActive.Valid {
				u.LastActiveMs = &lastActive.Int64
			}
			if avatar.Valid {
				u.AvatarAttachment = &avatar.String
			}
			users = append(users, u)
		}
	}

	writeJSON(w, http.StatusOK, users)
}

func (a *AdminHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username    string `json:"username"`
		DisplayName string `json:"display_name"`
		Password    string `json:"password"`
		Role        string `json:"role"`
		Email       string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}

	if req.Username == "" || req.DisplayName == "" {
		writeError(w, http.StatusBadRequest, "username and display_name are required")
		return
	}

	if req.Role == "" {
		req.Role = "member"
	}

	var passHash string
	var err error
	if req.Password != "" {
		passHash, err = auth.HashPassword(req.Password)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
	} else {
		passHash, _ = auth.HashPassword(uuid.New().String())
	}

	id := uuid.New().String()
	now := db.NowMs()

	var emailVal *string
	if req.Email != "" {
		emailVal = &req.Email
	}

	query := `INSERT INTO users (id, username, display_name, email, password_hash, role, disabled, deleted, created_ms)
              VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)`

	_, err = a.database.Exec(query, id, req.Username, req.DisplayName, emailVal, passHash, req.Role, now)
	if err != nil {
		writeError(w, http.StatusBadRequest, fmt.Sprintf("failed to create user: %v", err))
		return
	}

	// Create one-time login link for user
	token, _ := auth.CreateLoginLink(a.database, id, 7*24*time.Hour)
	link := fmt.Sprintf("%s/l/%s", a.publicURL, token)

	u := db.User{
		ID:          id,
		Username:    req.Username,
		DisplayName: req.DisplayName,
		Email:       emailVal,
		Role:        req.Role,
		CreatedMs:   now,
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"user":       u,
		"login_link": link,
		"token":      token,
	})
}

func (a *AdminHandler) UpdateUser(w http.ResponseWriter, r *http.Request, userID string) {
	var req struct {
		DisplayName            *string `json:"display_name"`
		Role                   *string `json:"role"`
		Disabled               *bool   `json:"disabled"`
		PrivacyControlsEnabled *bool   `json:"privacy_controls_enabled"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	if req.DisplayName != nil {
		a.database.Exec("UPDATE users SET display_name = ? WHERE id = ?", *req.DisplayName, userID)
	}
	if req.Role != nil {
		a.database.Exec("UPDATE users SET role = ? WHERE id = ?", *req.Role, userID)
	}
	if req.Disabled != nil {
		val := 0
		if *req.Disabled {
			val = 1
			// Revoke all sessions on disable
			a.database.Exec("UPDATE sessions SET revoked = 1, revoke_reason = 'account_disabled' WHERE user_id = ?", userID)
		}
		a.database.Exec("UPDATE users SET disabled = ? WHERE id = ?", val, userID)
	}
	if req.PrivacyControlsEnabled != nil {
		val := 0
		if *req.PrivacyControlsEnabled {
			val = 1
		}
		a.database.Exec("UPDATE users SET privacy_controls_enabled = ? WHERE id = ?", val, userID)
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *AdminHandler) CreateLoginLink(w http.ResponseWriter, r *http.Request, userID string) {
	token, err := auth.CreateLoginLink(a.database, userID, 7*24*time.Hour)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	link := fmt.Sprintf("%s/l/%s", a.publicURL, token)
	writeJSON(w, http.StatusOK, map[string]string{
		"token": token,
		"url":   link,
	})
}

func (a *AdminHandler) RevokeUserSessions(w http.ResponseWriter, r *http.Request, userID string) {
	_, err := a.database.Exec("UPDATE sessions SET revoked = 1, revoke_reason = 'admin_revoked' WHERE user_id = ?", userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *AdminHandler) ClearHistory(w http.ResponseWriter, r *http.Request, userID string) {
	// Requirements from Atomic Chat PRD:
	// "Automatic backup before Clear history or Delete: the action is refused if the backup fails."
	if err := a.backupMgr.BackupBeforeClearOrDelete(userID); err != nil {
		writeError(w, http.StatusInternalServerError, fmt.Sprintf("Automatic backup before clear failed: %v", err))
		return
	}

	// Soft delete user messages & revoke sessions
	a.database.Exec("UPDATE messages SET deleted = 1 WHERE sender_id = ?", userID)
	a.database.Exec("UPDATE sessions SET revoked = 1, revoke_reason = 'history_cleared' WHERE user_id = ?", userID)

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *AdminHandler) DeleteRange(w http.ResponseWriter, r *http.Request, userID string) {
	var req struct {
		FromMs         int64 `json:"from_ms"`
		ToMs           int64 `json:"to_ms"`
		DeleteBothWays bool  `json:"delete_both_ways"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	if req.ToMs == 0 {
		req.ToMs = db.NowMs()
	}

	// Requirements: "date-range delete: delete messages between two dates, with an optional also delete the other person's copy"
	if req.DeleteBothWays {
		// Find conversations user is part of
		a.database.Exec(`UPDATE messages SET deleted = 1
                         WHERE ts >= ? AND ts <= ? AND conv_id IN (SELECT conv_id FROM members WHERE user_id = ?)`,
			req.FromMs, req.ToMs, userID)
	} else {
		a.database.Exec(`UPDATE messages SET deleted = 1 WHERE sender_id = ? AND ts >= ? AND ts <= ?`,
			userID, req.FromMs, req.ToMs)
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *AdminHandler) ViewerConversations(w http.ResponseWriter, r *http.Request) {
	rows, err := a.database.Query(`SELECT c.id, c.kind, c.name, c.topic, c.last_seq, c.last_ts, COUNT(m.user_id) as member_count
                                   FROM conversations c
                                   LEFT JOIN members m ON c.id = m.conv_id
                                   WHERE c.archived = 0
                                   GROUP BY c.id ORDER BY COALESCE(c.last_ts, c.created_ms) DESC`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var list []map[string]interface{}
	for rows.Next() {
		var id, kind string
		var name, topic *string
		var lastSeq int64
		var lastTs sql.NullInt64
		var memberCount int

		if err := rows.Scan(&id, &kind, &name, &topic, &lastSeq, &lastTs, &memberCount); err == nil {
			item := map[string]interface{}{
				"id":           id,
				"kind":         kind,
				"name":         name,
				"topic":        topic,
				"last_seq":     lastSeq,
				"member_count": memberCount,
			}
			if lastTs.Valid {
				item["last_ts"] = lastTs.Int64
			}
			list = append(list, item)
		}
	}

	writeJSON(w, http.StatusOK, list)
}

func (a *AdminHandler) ViewerMessages(w http.ResponseWriter, r *http.Request, convID string) {
	limitStr := r.URL.Query().Get("limit")
	limit := 100
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
		limit = l
	}

	rows, err := a.database.Query(`SELECT m.id, m.conv_id, m.seq, m.sender_id, u.display_name, m.body, m.kind, m.ts, m.deleted
                                   FROM messages m
                                   LEFT JOIN users u ON m.sender_id = u.id
                                   WHERE m.conv_id = ?
                                   ORDER BY m.seq DESC LIMIT ?`, convID, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var msgs []map[string]interface{}
	for rows.Next() {
		var id, cid, senderID, body, kind string
		var displayName sql.NullString
		var seq, ts int64
		var deleted int

		if err := rows.Scan(&id, &cid, &seq, &senderID, &displayName, &body, &kind, &ts, &deleted); err == nil {
			msgs = append(msgs, map[string]interface{}{
				"id":           id,
				"conv_id":      cid,
				"seq":          seq,
				"sender_id":    senderID,
				"display_name": displayName.String,
				"body":         body,
				"kind":         kind,
				"ts":           ts,
				"deleted":      deleted == 1,
			})
		}
	}

	writeJSON(w, http.StatusOK, msgs)
}

func (a *AdminHandler) ViewerSearch(w http.ResponseWriter, r *http.Request) {
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	if query == "" {
		writeJSON(w, http.StatusOK, []interface{}{})
		return
	}

	rows, err := a.database.Query(`SELECT m.id, m.conv_id, m.seq, m.sender_id, u.display_name, m.body, m.ts
                                   FROM messages_fts f
                                   JOIN messages m ON f.rowid = m.rowid
                                   LEFT JOIN users u ON m.sender_id = u.id
                                   WHERE messages_fts MATCH ? AND m.deleted = 0
                                   ORDER BY m.ts DESC LIMIT 50`, query)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var id, convID, senderID, body string
		var displayName sql.NullString
		var seq, ts int64
		if err := rows.Scan(&id, &convID, &seq, &senderID, &displayName, &body, &ts); err == nil {
			results = append(results, map[string]interface{}{
				"id":           id,
				"conv_id":      convID,
				"seq":          seq,
				"sender_id":    senderID,
				"display_name": displayName.String,
				"body":         body,
				"ts":           ts,
			})
		}
	}

	writeJSON(w, http.StatusOK, results)
}

func writeJSON(w http.ResponseWriter, code int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}
