package routes

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/admin"
	"github.com/uri-travoski/workchat/server/internal/auth"
	"github.com/uri-travoski/workchat/server/internal/backup"
	"github.com/uri-travoski/workchat/server/internal/bots"
	"github.com/uri-travoski/workchat/server/internal/config"
	"github.com/uri-travoski/workchat/server/internal/db"
	"github.com/uri-travoski/workchat/server/internal/hub"
	"github.com/uri-travoski/workchat/server/internal/push"
	"github.com/uri-travoski/workchat/server/internal/scheduled"
	"github.com/uri-travoski/workchat/server/internal/storage"
	"github.com/uri-travoski/workchat/server/internal/webhooks"
)

type Server struct {
	cfg       *config.Config
	database  *db.DB
	hub       *hub.Hub
	storage   *storage.Storage
	push      *push.Notifier
	bots      *bots.BotService
	webhooks  *webhooks.WebhookService
	scheduled *scheduled.ScheduledWorker
	backupMgr *backup.BackupManager
	admin     *admin.AdminHandler
	mux       *http.ServeMux
}

func NewServer(cfg *config.Config, database *db.DB, h *hub.Hub, st *storage.Storage, p *push.Notifier, b *bots.BotService, w *webhooks.WebhookService, s *scheduled.ScheduledWorker, bm *backup.BackupManager) *Server {
	srv := &Server{
		cfg:       cfg,
		database:  database,
		hub:       h,
		storage:   st,
		push:      p,
		bots:      b,
		webhooks:  w,
		scheduled: s,
		backupMgr: bm,
		admin:     admin.New(database, h, bm, cfg.PublicURL),
		mux:       http.NewServeMux(),
	}
	srv.registerRoutes()
	return srv
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Security & CORS headers
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Frame-Options", "DENY")
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	s.mux.ServeHTTP(w, r)
}

func (s *Server) registerRoutes() {
	// Health & Meta
	s.mux.HandleFunc("/healthz", s.handleHealth)
	s.mux.HandleFunc("/api/v1/health", s.handleHealth)
	s.mux.HandleFunc("/api/v1/meta", s.handleMeta)
	s.mux.HandleFunc("/api/v1/setup", s.handleSetup)

	// Auth
	s.mux.HandleFunc("/api/v1/login", s.handleLogin)
	s.mux.HandleFunc("/api/v1/login/link", s.handleLoginLink)
	s.mux.HandleFunc("/l/", s.handleLandingPage)
	s.mux.HandleFunc("/api/v1/refresh", s.handleRefresh)
	s.mux.HandleFunc("/api/v1/logout", s.requireAuth(s.handleLogout))
	s.mux.HandleFunc("/api/v1/me", s.requireAuth(s.handleMe))
	s.mux.HandleFunc("/api/v1/me/password", s.requireAuth(s.handleChangePassword))
	s.mux.HandleFunc("/api/v1/sessions", s.requireAuth(s.handleSessions))
	s.mux.HandleFunc("/api/v1/sessions/", s.requireAuth(s.handleSessionAction))

	// Users & Avatars
	s.mux.HandleFunc("/api/v1/users", s.requireAuth(s.handleUsers))
	s.mux.HandleFunc("/api/v1/users/", s.requireAuth(s.handleUserByID))
	s.mux.HandleFunc("/users/", s.handlePublicUserAvatar)

	// Sync & Events
	s.mux.HandleFunc("/api/v1/sync/bootstrap", s.requireAuth(s.handleBootstrap))
	s.mux.HandleFunc("/api/v1/events", s.requireAuth(s.handleEvents))
	s.mux.HandleFunc("/api/v1/ws", s.handleWS)

	// Conversations & Messages
	s.mux.HandleFunc("/api/v1/conversations", s.requireAuth(s.handleConversations))
	s.mux.HandleFunc("/api/v1/conversations/dm", s.requireAuth(s.handleCreateDM))
	s.mux.HandleFunc("/api/v1/conversations/self", s.requireAuth(s.handleCreateSelf))
	s.mux.HandleFunc("/api/v1/conversations/", s.requireAuth(s.handleConversationSubroutes))
	s.mux.HandleFunc("/api/v1/messages/", s.requireAuth(s.handleMessageSubroutes))

	// Threads
	s.mux.HandleFunc("/api/v1/threads", s.requireAuth(s.handleThreads))
	s.mux.HandleFunc("/api/v1/threads/", s.requireAuth(s.handleThreadActions))

	// Pins, Bookmarks, Prefs, Sections, Drafts, Saved, Labels, Activity
	s.mux.HandleFunc("/api/v1/me/prefs", s.requireAuth(s.handlePrefs))
	s.mux.HandleFunc("/api/v1/sections", s.requireAuth(s.handleSections))
	s.mux.HandleFunc("/api/v1/drafts", s.requireAuth(s.handleDrafts))
	s.mux.HandleFunc("/api/v1/saved", s.requireAuth(s.handleSaved))
	s.mux.HandleFunc("/api/v1/saved/", s.requireAuth(s.handleSavedItem))
	s.mux.HandleFunc("/api/v1/labels", s.requireAuth(s.handleLabels))
	s.mux.HandleFunc("/api/v1/activity", s.requireAuth(s.handleActivity))
	s.mux.HandleFunc("/api/v1/activity/read", s.requireAuth(s.handleActivityRead))

	// Files
	s.mux.HandleFunc("/api/v1/files", s.requireAuth(s.handleFiles))
	s.mux.HandleFunc("/api/v1/files/", s.handleFileByID)

	// Search
	s.mux.HandleFunc("/api/v1/search", s.requireAuth(s.handleSearch))

	// Push
	s.mux.HandleFunc("/api/v1/me/push", s.requireAuth(s.handlePush))
	s.mux.HandleFunc("/api/v1/me/push/", s.requireAuth(s.handlePushDelete))

	// Scheduled
	s.mux.HandleFunc("/api/v1/scheduled", s.requireAuth(s.handleScheduled))
	s.mux.HandleFunc("/api/v1/scheduled/", s.requireAuth(s.handleScheduledCancel))

	// Webhooks
	s.mux.HandleFunc("/hooks/", s.handleIncomingHook)

	// Telegram-compatible Bot API
	s.mux.HandleFunc("/bot", s.handleBotTelegram)

	// Admin API
	s.mux.HandleFunc("/api/v1/admin/overview", s.requireAdmin(func(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) { s.admin.Overview(w, r) }))
	s.mux.HandleFunc("/api/v1/admin/users", s.requireAdmin(s.handleAdminUsers))
	s.mux.HandleFunc("/api/v1/admin/users/", s.requireAdmin(s.handleAdminUserByID))
	s.mux.HandleFunc("/api/v1/admin/viewer/conversations", s.requireAdmin(func(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) { s.admin.ViewerConversations(w, r) }))
	s.mux.HandleFunc("/api/v1/admin/viewer/conversations/", s.requireAdmin(s.handleAdminViewerConv))
	s.mux.HandleFunc("/api/v1/admin/viewer/search", s.requireAdmin(func(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) { s.admin.ViewerSearch(w, r) }))

	// Admin Web Static Files & Redirect
	s.mux.HandleFunc("/", s.handleRoot)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]interface{}{"status": "ok", "version": "1.1.0"})
}

func (s *Server) handleMeta(w http.ResponseWriter, r *http.Request) {
	var userCount int
	s.database.QueryRow("SELECT COUNT(*) FROM users").Scan(&userCount)
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"name":           s.cfg.Name,
		"version":        "1.1.0",
		"setup_required": userCount == 0,
		"public_url":     s.cfg.PublicURL,
	})
}

func (s *Server) handleSetup(w http.ResponseWriter, r *http.Request) {
	var count int
	s.database.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
	if count > 0 {
		writeError(w, http.StatusForbidden, "Setup already completed")
		return
	}

	var req struct {
		Username    string `json:"username"`
		DisplayName string `json:"display_name"`
		Password    string `json:"password"`
		Email       string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "Invalid setup request")
		return
	}

	passHash, _ := auth.HashPassword(req.Password)
	id := uuid.New().String()
	now := db.NowMs()

	var emailVal *string
	if req.Email != "" {
		emailVal = &req.Email
	}

	_, err := s.database.Exec(`INSERT INTO users (id, username, display_name, email, password_hash, role, disabled, deleted, created_ms)
                              VALUES (?, ?, ?, ?, ?, 'owner', 0, 0, ?)`,
		id, req.Username, req.DisplayName, emailVal, passHash, now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	tokens, err := auth.CreateSession(s.database, id, "Web Setup", "1.1.0", r.RemoteAddr)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"tokens": tokens,
		"user": map[string]interface{}{
			"id":           id,
			"username":     req.Username,
			"display_name": req.DisplayName,
			"role":         "owner",
		},
	})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var req struct {
		Username      string `json:"username"`
		Password      string `json:"password"`
		DeviceName    string `json:"device_name"`
		ClientVersion string `json:"client_version"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	var u db.User
	var email sql.NullString
	var lastActiveMs sql.NullInt64
	var avatarAttachment sql.NullString

	query := `SELECT id, username, display_name, email, password_hash, role, disabled, deleted, privacy_controls_enabled, hide_last_active, presence_pref, last_active_ms, avatar_attachment, is_bot, acked_cursor, created_ms
              FROM users WHERE username = ? COLLATE NOCASE`

	err := s.database.QueryRow(query, req.Username).Scan(
		&u.ID, &u.Username, &u.DisplayName, &email, &u.PasswordHash, &u.Role, &u.Disabled, &u.Deleted, &u.PrivacyControlsEnabled, &u.HideLastActive, &u.PresencePref, &lastActiveMs, &avatarAttachment, &u.IsBot, &u.AckedCursor, &u.CreatedMs,
	)
	if err != nil || !auth.CheckPassword(req.Password, u.PasswordHash) {
		writeError(w, http.StatusUnauthorized, "Invalid username or password")
		return
	}

	if u.Disabled || u.Deleted {
		writeError(w, http.StatusForbidden, "Account is disabled")
		return
	}

	if email.Valid {
		u.Email = &email.String
	}
	if lastActiveMs.Valid {
		u.LastActiveMs = &lastActiveMs.Int64
	}
	if avatarAttachment.Valid {
		u.AvatarAttachment = &avatarAttachment.String
	}

	tokens, err := auth.CreateSession(s.database, u.ID, req.DeviceName, req.ClientVersion, r.RemoteAddr)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"tokens": tokens,
		"user":   u,
	})
}

func (s *Server) handleLoginLink(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Token         string `json:"token"`
		DeviceName    string `json:"device_name"`
		ClientVersion string `json:"client_version"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		writeError(w, http.StatusBadRequest, "token is required")
		return
	}

	tokens, user, err := auth.RedeemLoginLink(s.database, req.Token, req.DeviceName, req.ClientVersion, r.RemoteAddr)
	if err != nil {
		writeError(w, http.StatusUnauthorized, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"tokens": tokens,
		"user":   user,
	})
}

func (s *Server) handleLandingPage(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimPrefix(r.URL.Path, "/l/")
	if token == "" {
		http.Redirect(w, r, "/admin/", http.StatusTemporaryRedirect)
		return
	}

	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WorkChat - Sign In</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0F172A; color: #F8FAFC; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .card { background: #1E293B; border-radius: 12px; padding: 32px; max-width: 400px; width: 90%%; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
    h1 { color: #38BDF8; font-size: 24px; margin-bottom: 8px; }
    p { color: #94A3B8; font-size: 14px; margin-bottom: 24px; }
    .btn { display: block; background: #2563EB; color: white; text-decoration: none; padding: 12px 20px; border-radius: 8px; font-weight: 600; margin-bottom: 12px; transition: background 0.2s; cursor: pointer; border: none; width: 100%%; box-sizing: border-box; }
    .btn:hover { background: #1D4ED8; }
    .btn-secondary { background: #334155; color: #E2E8F0; }
    .btn-secondary:hover { background: #475569; }
    .token-box { background: #0F172A; padding: 12px; border-radius: 6px; font-family: monospace; word-break: break-all; font-size: 13px; color: #38BDF8; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <svg viewBox="0 0 24 24" width="64" height="64" style="margin-bottom: 12px;">
      <path fill="#2563EB" d="M18.999 2h-14c-1.103 0-2 .897-2 2v12c0 1.103.897 2 2 2h3.5l3.5 4 3.5-4h3.5c1.103 0 2-.897 2-2V4c0-1.103-.897-2-2-2z"></path>
      <path fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" d="M7.4 6.6L9.3 13.4 12 8.6 14.7 13.4 16.6 6.6"></path>
    </svg>
    <h1>WorkChat Login</h1>
    <p>Tap below to open your account in the WorkChat application.</p>
    <a href="workchat://login?token=%s" class="btn">Open in WorkChat App</a>
    <button class="btn btn-secondary" onclick="navigator.clipboard.writeText('%s'); alert('Token copied to clipboard! Paste it in the WorkChat login screen.');">Copy Login Token</button>
    <div class="token-box">%s</div>
  </div>
</body>
</html>`, token, token, token)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(html))
}

func (s *Server) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RefreshToken == "" {
		writeError(w, http.StatusBadRequest, "refresh_token is required")
		return
	}

	h := auth.HashToken(req.RefreshToken)
	now := db.NowMs()

	var sessID, userID string
	var revoked int
	err := s.database.QueryRow("SELECT id, user_id, revoked FROM sessions WHERE refresh_hash = ? AND refresh_exp_ms > ?", h, now).
		Scan(&sessID, &userID, &revoked)
	if err != nil || revoked == 1 {
		writeError(w, http.StatusUnauthorized, "Invalid or expired refresh token")
		return
	}

	newAccessToken, _ := auth.GenerateSecureToken(32)
	accessHash := auth.HashToken(newAccessToken)
	accessExp := now + 15*24*3600*1000

	s.database.Exec("UPDATE sessions SET access_hash = ?, access_exp_ms = ?, last_seen_ms = ? WHERE id = ?",
		accessHash, accessExp, now, sessID)

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"access_token":  newAccessToken,
		"access_exp_ms": accessExp,
	})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	s.database.Exec("UPDATE sessions SET revoked = 1, revoke_reason = 'user_logout' WHERE id = ?", sess.ID)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	if r.Method == http.MethodPatch {
		var req struct {
			DisplayName    *string `json:"display_name"`
			PresencePref   *string `json:"presence_pref"`
			HideLastActive *bool   `json:"hide_last_active"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		if req.DisplayName != nil {
			s.database.Exec("UPDATE users SET display_name = ? WHERE id = ?", *req.DisplayName, u.ID)
			u.DisplayName = *req.DisplayName
		}
		if req.PresencePref != nil {
			s.database.Exec("UPDATE users SET presence_pref = ? WHERE id = ?", *req.PresencePref, u.ID)
			u.PresencePref = *req.PresencePref
		}
		if req.HideLastActive != nil {
			val := 0
			if *req.HideLastActive {
				val = 1
			}
			s.database.Exec("UPDATE users SET hide_last_active = ? WHERE id = ?", val, u.ID)
			u.HideLastActive = *req.HideLastActive
		}
	}
	writeJSON(w, http.StatusOK, u)
}

func (s *Server) handleChangePassword(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	var req struct {
		OldPassword string `json:"old_password"`
		NewPassword string `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.NewPassword == "" {
		writeError(w, http.StatusBadRequest, "Invalid request")
		return
	}

	if !auth.CheckPassword(req.OldPassword, u.PasswordHash) {
		writeError(w, http.StatusUnauthorized, "Incorrect current password")
		return
	}

	newHash, _ := auth.HashPassword(req.NewPassword)
	s.database.Exec("UPDATE users SET password_hash = ? WHERE id = ?", newHash, u.ID)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleSessions(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	rows, err := s.database.Query(`SELECT id, user_id, device_name, client_version, ip, access_exp_ms, refresh_exp_ms, created_ms, last_seen_ms
                                   FROM sessions WHERE user_id = ? AND revoked = 0 ORDER BY last_seen_ms DESC`, u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var sessions []db.Session
	for rows.Next() {
		var s db.Session
		if err := rows.Scan(&s.ID, &s.UserID, &s.DeviceName, &s.ClientVersion, &s.IP, &s.AccessExpMs, &s.RefreshExpMs, &s.CreatedMs, &s.LastSeenMs); err == nil {
			sessions = append(sessions, s)
		}
	}
	writeJSON(w, http.StatusOK, sessions)
}

func (s *Server) handleSessionAction(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/sessions/")
	if path == "revoke-others" {
		s.database.Exec("UPDATE sessions SET revoked = 1, revoke_reason = 'revoke_others' WHERE user_id = ? AND id != ?", u.ID, sess.ID)
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}
	if path == "revoke-all" {
		s.database.Exec("UPDATE sessions SET revoked = 1, revoke_reason = 'revoke_all' WHERE user_id = ?", u.ID)
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}

	if r.Method == http.MethodDelete {
		s.database.Exec("UPDATE sessions SET revoked = 1, revoke_reason = 'user_revoked' WHERE user_id = ? AND id = ?", u.ID, path)
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}
	writeError(w, http.StatusNotFound, "not found")
}

func (s *Server) handleUsers(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	rows, err := s.database.Query("SELECT id, username, display_name, role, avatar_attachment, presence_pref, last_active_ms FROM users WHERE deleted = 0 AND disabled = 0")
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var users []map[string]interface{}
	for rows.Next() {
		var id, uname, dname, role, pref string
		var avatar sql.NullString
		var lastActive sql.NullInt64
		if err := rows.Scan(&id, &uname, &dname, &role, &avatar, &pref, &lastActive); err == nil {
			item := map[string]interface{}{
				"id":            id,
				"username":      uname,
				"display_name":  dname,
				"role":          role,
				"presence_pref": pref,
			}
			if avatar.Valid {
				item["avatar_attachment"] = avatar.String
			}
			if lastActive.Valid {
				item["last_active_ms"] = lastActive.Int64
			}
			users = append(users, item)
		}
	}
	writeJSON(w, http.StatusOK, users)
}

func (s *Server) handleUserByID(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	uid := strings.TrimPrefix(r.URL.Path, "/api/v1/users/")
	var target db.User
	var email, avatar sql.NullString
	var lastActive sql.NullInt64

	err := s.database.QueryRow("SELECT id, username, display_name, email, role, avatar_attachment, last_active_ms FROM users WHERE id = ? AND deleted = 0", uid).
		Scan(&target.ID, &target.Username, &target.DisplayName, &email, &target.Role, &avatar, &lastActive)
	if err != nil {
		writeError(w, http.StatusNotFound, "user not found")
		return
	}

	if email.Valid {
		target.Email = &email.String
	}
	if avatar.Valid {
		target.AvatarAttachment = &avatar.String
	}
	if lastActive.Valid {
		target.LastActiveMs = &lastActive.Int64
	}

	writeJSON(w, http.StatusOK, target)
}

func (s *Server) handlePublicUserAvatar(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) >= 3 && parts[0] == "users" && parts[2] == "avatar" {
		uid := parts[1]
		var attID sql.NullString
		s.database.QueryRow("SELECT avatar_attachment FROM users WHERE id = ?", uid).Scan(&attID)
		if !attID.Valid || attID.String == "" {
			http.NotFound(w, r)
			return
		}
		var storageKey, contentType string
		s.database.QueryRow("SELECT storage_key, content_type FROM attachments WHERE id = ?", attID.String).Scan(&storageKey, &contentType)
		filePath := s.storage.GetFilePath(storageKey)
		w.Header().Set("Content-Type", contentType)
		http.ServeFile(w, r, filePath)
		return
	}
	http.NotFound(w, r)
}

func (s *Server) handleBootstrap(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	// Conversations user is a member of
	rows, err := s.database.Query(`SELECT c.id, c.kind, c.name, c.topic, c.archived, c.created_by, c.created_ms, c.last_seq, c.last_ts, c.avatar_attachment,
                                          COALESCE(rs.last_read_seq, 0) as last_read_seq, COALESCE(rs.marked_unread, 0) as marked_unread
                                   FROM conversations c
                                   JOIN members m ON c.id = m.conv_id
                                   LEFT JOIN read_state rs ON c.id = rs.conv_id AND rs.user_id = ?
                                   WHERE m.user_id = ? AND c.archived = 0
                                   ORDER BY COALESCE(c.last_ts, c.created_ms) DESC`, u.ID, u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var convs []db.Conversation
	for rows.Next() {
		var c db.Conversation
		var name, topic, createdBy, avatar sql.NullString
		var lastTs sql.NullInt64
		var lastReadSeq int64
		var markedUnread int

		if err := rows.Scan(&c.ID, &c.Kind, &name, &topic, &c.Archived, &createdBy, &c.CreatedMs, &c.LastSeq, &lastTs, &avatar, &lastReadSeq, &markedUnread); err == nil {
			if name.Valid {
				c.Name = &name.String
			}
			if topic.Valid {
				c.Topic = &topic.String
			}
			if createdBy.Valid {
				c.CreatedBy = &createdBy.String
			}
			if avatar.Valid {
				c.AvatarAttachment = &avatar.String
			}
			if lastTs.Valid {
				c.LastTs = &lastTs.Int64
			}
			if c.LastSeq > lastReadSeq {
				c.UnreadCount = int(c.LastSeq - lastReadSeq)
			}
			convs = append(convs, c)
		}
	}

	// Fetch max event ID
	var cursor int64
	s.database.QueryRow("SELECT COALESCE(MAX(id), 0) FROM events WHERE user_id = ?", u.ID).Scan(&cursor)

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"user":          u,
		"conversations": convs,
		"cursor":        cursor,
		"now_ms":        db.NowMs(),
	})
}

func (s *Server) handleEvents(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	cursorStr := r.URL.Query().Get("cursor")
	cursor, _ := strconv.ParseInt(cursorStr, 10, 64)

	rows, err := s.database.Query("SELECT id, ts, kind, ref, data FROM events WHERE user_id = ? AND id > ? ORDER BY id ASC LIMIT 200", u.ID, cursor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var events []db.Event
	for rows.Next() {
		var e db.Event
		var ref sql.NullString
		if err := rows.Scan(&e.ID, &e.Ts, &e.Kind, &ref, &e.Data); err == nil {
			if ref.Valid {
				e.Ref = ref.String
			}
			e.UserID = u.ID
			events = append(events, e)
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"events": events,
		"cursor": cursor,
	})
}

func (s *Server) handleWS(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	cursorStr := r.URL.Query().Get("cursor")
	cursor, _ := strconv.ParseInt(cursorStr, 10, 64)

	u, sess, err := auth.ValidateAccessToken(s.database, token)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	s.hub.HandleWS(w, r, u.ID, sess.ID, cursor)
}

func (s *Server) handleConversations(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	if r.Method == http.MethodPost {
		var req struct {
			Kind    string   `json:"kind"` // "channel", "group_dm"
			Name    string   `json:"name"`
			Topic   string   `json:"topic"`
			Members []string `json:"members"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
			writeError(w, http.StatusBadRequest, "Invalid request")
			return
		}

		convID := uuid.New().String()
		now := db.NowMs()

		err := s.database.WithLock(func(tx *sql.Tx) error {
			_, err := tx.Exec(`INSERT INTO conversations (id, kind, name, topic, created_by, created_ms, last_seq, last_ts)
                              VALUES (?, ?, ?, ?, ?, ?, 0, ?)`,
				convID, req.Kind, req.Name, req.Topic, u.ID, now, now)
			if err != nil {
				return err
			}

			// Add creator as owner
			tx.Exec("INSERT INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'owner', ?)", convID, u.ID, now)

			// Add other members
			for _, mID := range req.Members {
				if mID != u.ID {
					tx.Exec("INSERT OR IGNORE INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'member', ?)", convID, mID, now)
				}
			}
			return nil
		})

		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}

		conv := db.Conversation{
			ID:        convID,
			Kind:      req.Kind,
			Name:      &req.Name,
			Topic:     &req.Topic,
			CreatedBy: &u.ID,
			CreatedMs: now,
			LastSeq:   0,
		}

		s.hub.EmitToMembers(convID, "conversation_created", convID, conv)
		writeJSON(w, http.StatusCreated, conv)
		return
	}

	// List conversations
	s.handleBootstrap(w, r, u, sess)
}

func (s *Server) handleCreateDM(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	var req struct {
		TargetUserID string `json:"target_user_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TargetUserID == "" {
		writeError(w, http.StatusBadRequest, "target_user_id is required")
		return
	}

	// Canonical DM key
	u1, u2 := u.ID, req.TargetUserID
	if u1 > u2 {
		u1, u2 = u2, u1
	}
	dmKey := fmt.Sprintf("%s:%s", u1, u2)

	var existingID string
	err := s.database.QueryRow("SELECT id FROM conversations WHERE dm_key = ?", dmKey).Scan(&existingID)
	if err == nil {
		// Existing DM found
		writeJSON(w, http.StatusOK, map[string]string{"id": existingID})
		return
	}

	convID := uuid.New().String()
	now := db.NowMs()

	err = s.database.WithLock(func(tx *sql.Tx) error {
		_, err := tx.Exec(`INSERT INTO conversations (id, kind, dm_key, created_by, created_ms, last_seq, last_ts)
                          VALUES (?, 'dm', ?, ?, ?, 0, ?)`,
			convID, dmKey, u.ID, now, now)
		if err != nil {
			return err
		}
		tx.Exec("INSERT INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'member', ?)", convID, u.ID, now)
		tx.Exec("INSERT INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'member', ?)", convID, req.TargetUserID, now)
		return nil
	})

	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"id": convID})
}

func (s *Server) handleCreateSelf(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	dmKey := fmt.Sprintf("self:%s", u.ID)
	var existingID string
	err := s.database.QueryRow("SELECT id FROM conversations WHERE dm_key = ?", dmKey).Scan(&existingID)
	if err == nil {
		writeJSON(w, http.StatusOK, map[string]string{"id": existingID})
		return
	}

	convID := uuid.New().String()
	now := db.NowMs()
	name := "Notes to Self"

	s.database.WithLock(func(tx *sql.Tx) error {
		tx.Exec(`INSERT INTO conversations (id, kind, name, dm_key, created_by, created_ms, last_seq, last_ts)
                 VALUES (?, 'self', ?, ?, ?, ?, 0, ?)`,
			convID, name, dmKey, u.ID, now, now)
		tx.Exec("INSERT INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'owner', ?)", convID, u.ID, now)
		return nil
	})

	writeJSON(w, http.StatusCreated, map[string]string{"id": convID})
}

func (s *Server) handleConversationSubroutes(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/conversations/"), "/"), "/")
	convID := parts[0]

	if len(parts) == 1 {
		// GET or PATCH /conversations/:id
		if r.Method == http.MethodPatch {
			var req struct {
				Name  *string `json:"name"`
				Topic *string `json:"topic"`
			}
			json.NewDecoder(r.Body).Decode(&req)
			if req.Name != nil {
				s.database.Exec("UPDATE conversations SET name = ? WHERE id = ?", *req.Name, convID)
			}
			if req.Topic != nil {
				s.database.Exec("UPDATE conversations SET topic = ? WHERE id = ?", *req.Topic, convID)
			}
			writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
			return
		}

		var c db.Conversation
		var name, topic, createdBy, avatar sql.NullString
		var lastTs sql.NullInt64
		err := s.database.QueryRow("SELECT id, kind, name, topic, archived, created_by, created_ms, last_seq, last_ts, avatar_attachment FROM conversations WHERE id = ?", convID).
			Scan(&c.ID, &c.Kind, &name, &topic, &c.Archived, &createdBy, &c.CreatedMs, &c.LastSeq, &lastTs, &avatar)
		if err != nil {
			writeError(w, http.StatusNotFound, "conversation not found")
			return
		}
		if name.Valid {
			c.Name = &name.String
		}
		if topic.Valid {
			c.Topic = &topic.String
		}
		if avatar.Valid {
			c.AvatarAttachment = &avatar.String
		}
		writeJSON(w, http.StatusOK, c)
		return
	}

	action := parts[1]
	switch action {
	case "messages":
		if r.Method == http.MethodPost {
			s.handleSendMessage(w, r, u, sess, convID)
			return
		}
		s.handleGetHistory(w, r, u, sess, convID)

	case "read":
		var req struct {
			Seq int64 `json:"seq"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		s.database.Exec(`INSERT INTO read_state (user_id, conv_id, last_read_seq, marked_unread)
                         VALUES (?, ?, ?, 0)
                         ON CONFLICT(user_id, conv_id) DO UPDATE SET last_read_seq = ?, marked_unread = 0`,
			u.ID, convID, req.Seq, req.Seq)
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})

	case "unread":
		s.database.Exec(`INSERT INTO read_state (user_id, conv_id, last_read_seq, marked_unread)
                         VALUES (?, ?, 0, 1)
                         ON CONFLICT(user_id, conv_id) DO UPDATE SET marked_unread = 1`,
			u.ID, convID)
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})

	case "pins":
		rows, _ := s.database.Query("SELECT message_id, pinned_by, ts FROM pins WHERE conv_id = ? ORDER BY ts DESC", convID)
		var pins []db.Pin
		if rows != nil {
			for rows.Next() {
				var p db.Pin
				p.ConvID = convID
				if err := rows.Scan(&p.MessageID, &p.PinnedBy, &p.Ts); err == nil {
					pins = append(pins, p)
				}
			}
			rows.Close()
		}
		writeJSON(w, http.StatusOK, pins)

	case "threads":
		if len(parts) >= 3 {
			rootMsgID := parts[2]
			s.handleGetThreadMessages(w, r, u, sess, convID, rootMsgID)
			return
		}

	default:
		writeError(w, http.StatusNotFound, "route not found")
	}
}

func (s *Server) handleSendMessage(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session, convID string) {
	var req struct {
		Body          string   `json:"body"`
		ClientID      *string  `json:"client_id"`
		ThreadRoot    *string  `json:"thread_root"`
		ReplyTo       *string  `json:"reply_to"`
		AttachmentIDs []string `json:"attachment_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || (req.Body == "" && len(req.AttachmentIDs) == 0) {
		writeError(w, http.StatusBadRequest, "body or attachment is required")
		return
	}

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

		kind := "text"
		if len(req.AttachmentIDs) > 0 {
			kind = "file"
		}

		_, err = tx.Exec(`INSERT INTO messages (id, conv_id, seq, sender_id, client_id, body, kind, ts, version, deleted, thread_root, reply_to, mentions)
                          VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 0, ?, ?, '[]')`,
			msgID, convID, nextSeq, u.ID, req.ClientID, req.Body, kind, now, req.ThreadRoot, req.ReplyTo)
		if err != nil {
			return err
		}

		for _, attID := range req.AttachmentIDs {
			tx.Exec("INSERT INTO message_attachments (message_id, attachment_id) VALUES (?, ?)", msgID, attID)
		}

		// Update sender read state automatically
		tx.Exec(`INSERT INTO read_state (user_id, conv_id, last_read_seq, marked_unread)
                 VALUES (?, ?, ?, 0)
                 ON CONFLICT(user_id, conv_id) DO UPDATE SET last_read_seq = ?, marked_unread = 0`,
			u.ID, convID, nextSeq, nextSeq)

		return nil
	})

	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	msg := db.Message{
		ID:         msgID,
		ConvID:     convID,
		Seq:        nextSeq,
		SenderID:   u.ID,
		ClientID:   req.ClientID,
		Body:       req.Body,
		Kind:       "text",
		Ts:         now,
		Version:    1,
		ThreadRoot: req.ThreadRoot,
		ReplyTo:    req.ReplyTo,
	}

	// Realtime broadcast to members
	s.hub.EmitToMembers(convID, "message_created", convID, msg)

	// Send Push notifications to offline/mobile members
	go func() {
		rows, _ := s.database.Query("SELECT user_id FROM members WHERE conv_id = ? AND user_id != ?", convID, u.ID)
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				var memberID string
				if err := rows.Scan(&memberID); err == nil {
					s.push.NotifyUser(memberID, push.PushPayload{
						Title:  u.DisplayName,
						Body:   req.Body,
						ConvID: convID,
						MsgID:  msgID,
					})
				}
			}
		}
	}()

	// Outgoing webhooks
	s.webhooks.QueueOutgoingWebhook("message_created", convID, msg)

	// Queue for bots
	s.bots.QueueBotUpdate(convID, &msg)

	writeJSON(w, http.StatusCreated, msg)
}

func (s *Server) handleGetHistory(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session, convID string) {
	beforeSeqStr := r.URL.Query().Get("before_seq")
	limitStr := r.URL.Query().Get("limit")

	limit := 50
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
		limit = l
	}

	var query string
	var args []interface{}

	if beforeSeq, err := strconv.ParseInt(beforeSeqStr, 10, 64); err == nil && beforeSeq > 0 {
		query = `SELECT id, conv_id, seq, sender_id, client_id, body, kind, ts, version, edited_ms, deleted, thread_root, reply_to, mentions
                 FROM messages WHERE conv_id = ? AND seq < ? ORDER BY seq DESC LIMIT ?`
		args = []interface{}{convID, beforeSeq, limit}
	} else {
		query = `SELECT id, conv_id, seq, sender_id, client_id, body, kind, ts, version, edited_ms, deleted, thread_root, reply_to, mentions
                 FROM messages WHERE conv_id = ? ORDER BY seq DESC LIMIT ?`
		args = []interface{}{convID, limit}
	}

	rows, err := s.database.Query(query, args...)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var msgs []db.Message
	for rows.Next() {
		var m db.Message
		var clientID, threadRoot, replyTo *string
		var editedMs sql.NullInt64
		var mentionsJSON string

		if err := rows.Scan(&m.ID, &m.ConvID, &m.Seq, &m.SenderID, &clientID, &m.Body, &m.Kind, &m.Ts, &m.Version, &editedMs, &m.Deleted, &threadRoot, &replyTo, &mentionsJSON); err == nil {
			m.ClientID = clientID
			m.ThreadRoot = threadRoot
			m.ReplyTo = replyTo
			if editedMs.Valid {
				m.EditedMs = &editedMs.Int64
			}
			json.Unmarshal([]byte(mentionsJSON), &m.Mentions)
			msgs = append(msgs, m)
		}
	}

	writeJSON(w, http.StatusOK, msgs)
}

func (s *Server) handleGetThreadMessages(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session, convID, rootMsgID string) {
	rows, err := s.database.Query(`SELECT id, conv_id, seq, sender_id, client_id, body, kind, ts, version, edited_ms, deleted, thread_root, reply_to, mentions
                                   FROM messages WHERE conv_id = ? AND (id = ? OR thread_root = ?) ORDER BY seq ASC`,
		convID, rootMsgID, rootMsgID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var msgs []db.Message
	for rows.Next() {
		var m db.Message
		var clientID, threadRoot, replyTo *string
		var editedMs sql.NullInt64
		var mentionsJSON string
		if err := rows.Scan(&m.ID, &m.ConvID, &m.Seq, &m.SenderID, &clientID, &m.Body, &m.Kind, &m.Ts, &m.Version, &editedMs, &m.Deleted, &threadRoot, &replyTo, &mentionsJSON); err == nil {
			m.ClientID = clientID
			m.ThreadRoot = threadRoot
			m.ReplyTo = replyTo
			if editedMs.Valid {
				m.EditedMs = &editedMs.Int64
			}
			json.Unmarshal([]byte(mentionsJSON), &m.Mentions)
			msgs = append(msgs, m)
		}
	}

	writeJSON(w, http.StatusOK, msgs)
}

func (s *Server) handleMessageSubroutes(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/messages/"), "/"), "/")
	msgID := parts[0]

	if len(parts) == 1 {
		if r.Method == http.MethodPatch {
			var req struct {
				Body string `json:"body"`
			}
			json.NewDecoder(r.Body).Decode(&req)
			now := db.NowMs()
			_, err := s.database.Exec("UPDATE messages SET body = ?, edited_ms = ?, version = version + 1 WHERE id = ? AND sender_id = ?",
				req.Body, now, msgID, u.ID)
			if err != nil {
				writeError(w, http.StatusInternalServerError, err.Error())
				return
			}
			writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
			return
		}

		if r.Method == http.MethodDelete {
			s.database.Exec("UPDATE messages SET deleted = 1 WHERE id = ? AND (sender_id = ? OR 'owner' = ?)", msgID, u.ID, u.Role)
			writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
			return
		}
	}

	if len(parts) >= 3 && parts[1] == "reactions" {
		emoji := parts[2]
		if r.Method == http.MethodPut {
			now := db.NowMs()
			s.database.Exec("INSERT OR IGNORE INTO reactions (message_id, user_id, emoji, ts) VALUES (?, ?, ?, ?)", msgID, u.ID, emoji, now)
			writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
			return
		}
		if r.Method == http.MethodDelete {
			s.database.Exec("DELETE FROM reactions WHERE message_id = ? AND user_id = ? AND emoji = ?", msgID, u.ID, emoji)
			writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
			return
		}
	}

	writeError(w, http.StatusNotFound, "route not found")
}

func (s *Server) handleThreads(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	rows, err := s.database.Query(`SELECT tf.thread_root, tf.conv_id, COUNT(m.id) as reply_count, MAX(m.ts) as last_reply_at
                                   FROM thread_follows tf
                                   JOIN messages m ON tf.thread_root = m.thread_root
                                   WHERE tf.user_id = ? AND tf.following = 1
                                   GROUP BY tf.thread_root ORDER BY last_reply_at DESC`, u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var threads []map[string]interface{}
	for rows.Next() {
		var root, cid string
		var count int
		var lastReply int64
		if err := rows.Scan(&root, &cid, &count, &lastReply); err == nil {
			threads = append(threads, map[string]interface{}{
				"thread_root":   root,
				"conv_id":       cid,
				"reply_count":   count,
				"last_reply_at": lastReply,
			})
		}
	}
	writeJSON(w, http.StatusOK, threads)
}

func (s *Server) handleThreadActions(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/threads/"), "/"), "/")
	rootID := parts[0]
	if len(parts) >= 2 {
		action := parts[1]
		if action == "follow" {
			if r.Method == http.MethodPut {
				var convID string
				s.database.QueryRow("SELECT conv_id FROM messages WHERE id = ?", rootID).Scan(&convID)
				s.database.Exec("INSERT OR REPLACE INTO thread_follows (user_id, thread_root, conv_id, following) VALUES (?, ?, ?, 1)", u.ID, rootID, convID)
				writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
				return
			}
			if r.Method == http.MethodDelete {
				s.database.Exec("UPDATE thread_follows SET following = 0 WHERE user_id = ? AND thread_root = ?", u.ID, rootID)
				writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
				return
			}
		}
	}
	writeError(w, http.StatusNotFound, "not found")
}

func (s *Server) handlePrefs(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	rows, err := s.database.Query("SELECT conv_id, favourite, section_id, mute_until_ms, notify, position FROM conv_prefs WHERE user_id = ?", u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var prefs []db.ConvPref
	for rows.Next() {
		var p db.ConvPref
		var secID sql.NullString
		var mute sql.NullInt64
		var pos sql.NullInt32
		p.UserID = u.ID
		if err := rows.Scan(&p.ConvID, &p.Favourite, &secID, &mute, &p.Notify, &pos); err == nil {
			if secID.Valid {
				p.SectionID = &secID.String
			}
			if mute.Valid {
				p.MuteUntilMs = &mute.Int64
			}
			if pos.Valid {
				v := int(pos.Int32)
				p.Position = &v
			}
			prefs = append(prefs, p)
		}
	}
	writeJSON(w, http.StatusOK, prefs)
}

func (s *Server) handleSections(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	rows, _ := s.database.Query("SELECT id, name, position, collapsed FROM sections WHERE user_id = ? ORDER BY position ASC", u.ID)
	var sections []db.Section
	if rows != nil {
		for rows.Next() {
			var sec db.Section
			sec.UserID = u.ID
			if err := rows.Scan(&sec.ID, &sec.Name, &sec.Position, &sec.Collapsed); err == nil {
				sections = append(sections, sec)
			}
		}
		rows.Close()
	}
	writeJSON(w, http.StatusOK, sections)
}

func (s *Server) handleDrafts(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	rows, _ := s.database.Query("SELECT conv_id, thread_root, body, updated_ms FROM drafts WHERE user_id = ?", u.ID)
	var drafts []db.Draft
	if rows != nil {
		for rows.Next() {
			var d db.Draft
			d.UserID = u.ID
			if err := rows.Scan(&d.ConvID, &d.ThreadRoot, &d.Body, &d.UpdatedMs); err == nil {
				drafts = append(drafts, d)
			}
		}
		rows.Close()
	}
	writeJSON(w, http.StatusOK, drafts)
}

func (s *Server) handleSaved(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	rows, _ := s.database.Query("SELECT message_id, conv_id, saved_ms FROM saved_items WHERE user_id = ? ORDER BY saved_ms DESC", u.ID)
	var saved []map[string]interface{}
	if rows != nil {
		for rows.Next() {
			var mid, cid string
			var sms int64
			if err := rows.Scan(&mid, &cid, &sms); err == nil {
				saved = append(saved, map[string]interface{}{"message_id": mid, "conv_id": cid, "saved_ms": sms})
			}
		}
		rows.Close()
	}
	writeJSON(w, http.StatusOK, saved)
}

func (s *Server) handleSavedItem(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	msgID := strings.TrimPrefix(r.URL.Path, "/api/v1/saved/")
	if r.Method == http.MethodPut {
		var cid string
		s.database.QueryRow("SELECT conv_id FROM messages WHERE id = ?", msgID).Scan(&cid)
		s.database.Exec("INSERT OR REPLACE INTO saved_items (user_id, message_id, conv_id, saved_ms) VALUES (?, ?, ?, ?)", u.ID, msgID, cid, db.NowMs())
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}
	if r.Method == http.MethodDelete {
		s.database.Exec("DELETE FROM saved_items WHERE user_id = ? AND message_id = ?", u.ID, msgID)
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}
	writeError(w, http.StatusNotFound, "not found")
}

func (s *Server) handleLabels(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	rows, _ := s.database.Query("SELECT id, name, color, position FROM labels WHERE user_id = ?", u.ID)
	var labels []db.Label
	if rows != nil {
		for rows.Next() {
			var l db.Label
			l.UserID = u.ID
			if err := rows.Scan(&l.ID, &l.Name, &l.Color, &l.Position); err == nil {
				labels = append(labels, l)
			}
		}
		rows.Close()
	}
	writeJSON(w, http.StatusOK, labels)
}

func (s *Server) handleActivity(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	// Mentions and replies targeting this user
	rows, err := s.database.Query(`SELECT id, conv_id, seq, sender_id, body, ts
                                   FROM messages WHERE (reply_to IN (SELECT id FROM messages WHERE sender_id = ?) OR mentions LIKE ?) AND sender_id != ?
                                   ORDER BY ts DESC LIMIT 50`, u.ID, "%"+u.ID+"%", u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var acts []map[string]interface{}
	for rows.Next() {
		var id, cid, sender, body string
		var seq, ts int64
		if err := rows.Scan(&id, &cid, &seq, &sender, &body, &ts); err == nil {
			acts = append(acts, map[string]interface{}{
				"id":        id,
				"conv_id":   cid,
				"seq":       seq,
				"sender_id": sender,
				"body":      body,
				"ts":        ts,
			})
		}
	}
	writeJSON(w, http.StatusOK, acts)
}

func (s *Server) handleActivityRead(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	now := db.NowMs()
	s.database.Exec("INSERT OR REPLACE INTO activity_state (user_id, read_ms) VALUES (?, ?)", u.ID, now)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleFiles(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	if r.Method == http.MethodPost {
		// Multipart file upload
		err := r.ParseMultipartForm(s.cfg.MaxUploadMB * 1024 * 1024)
		if err != nil {
			writeError(w, http.StatusBadRequest, "failed to parse multipart form")
			return
		}

		file, header, err := r.FormFile("file")
		if err != nil {
			writeError(w, http.StatusBadRequest, "file parameter is required")
			return
		}
		defer file.Close()

		contentType := header.Header.Get("Content-Type")
		if contentType == "" {
			contentType = "application/octet-stream"
		}

		att, err := s.storage.SaveFile(s.database, u.ID, header.Filename, contentType, file)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}

		writeJSON(w, http.StatusCreated, att)
		return
	}

	rows, _ := s.database.Query("SELECT id, name, content_type, size, created_ms FROM attachments WHERE uploader_id = ? AND removed = 0 ORDER BY created_ms DESC LIMIT 100", u.ID)
	var list []db.Attachment
	if rows != nil {
		for rows.Next() {
			var a db.Attachment
			a.UploaderID = u.ID
			if err := rows.Scan(&a.ID, &a.Name, &a.ContentType, &a.Size, &a.CreatedMs); err == nil {
				list = append(list, a)
			}
		}
		rows.Close()
	}
	writeJSON(w, http.StatusOK, list)
}

func (s *Server) handleFileByID(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/files/"), "/"), "/")
	attID := parts[0]

	var storageKey, contentType, name string
	err := s.database.QueryRow("SELECT storage_key, content_type, name FROM attachments WHERE id = ?", attID).
		Scan(&storageKey, &contentType, &name)
	if err != nil {
		writeError(w, http.StatusNotFound, "file not found")
		return
	}

	if len(parts) >= 2 && parts[1] == "thumb" {
		thumbPath := s.storage.GetThumbPath(attID)
		if _, err := os.Stat(thumbPath); err == nil {
			w.Header().Set("Content-Type", "image/png")
			http.ServeFile(w, r, thumbPath)
			return
		}
	}

	filePath := s.storage.GetFilePath(storageKey)
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Disposition", fmt.Sprintf(`inline; filename="%s"`, name))
	http.ServeFile(w, r, filePath)
}

func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if q == "" {
		writeJSON(w, http.StatusOK, []interface{}{})
		return
	}

	convID := r.URL.Query().Get("conv_id")
	var rows *sql.Rows
	var err error

	if convID != "" {
		rows, err = s.database.Query(`SELECT m.id, m.conv_id, m.seq, m.sender_id, u.display_name, m.body, m.ts
                                      FROM messages_fts f
                                      JOIN messages m ON f.rowid = m.rowid
                                      LEFT JOIN users u ON m.sender_id = u.id
                                      WHERE messages_fts MATCH ? AND m.conv_id = ? AND m.deleted = 0
                                      ORDER BY m.ts DESC LIMIT 50`, q, convID)
	} else {
		rows, err = s.database.Query(`SELECT m.id, m.conv_id, m.seq, m.sender_id, u.display_name, m.body, m.ts
                                      FROM messages_fts f
                                      JOIN messages m ON f.rowid = m.rowid
                                      LEFT JOIN users u ON m.sender_id = u.id
                                      WHERE messages_fts MATCH ? AND m.deleted = 0 AND m.conv_id IN (SELECT conv_id FROM members WHERE user_id = ?)
                                      ORDER BY m.ts DESC LIMIT 50`, q, u.ID)
	}

	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var id, cid, sender, body string
		var dname sql.NullString
		var seq, ts int64
		if err := rows.Scan(&id, &cid, &seq, &sender, &dname, &body, &ts); err == nil {
			results = append(results, map[string]interface{}{
				"id":           id,
				"conv_id":      cid,
				"seq":          seq,
				"sender_id":    sender,
				"display_name": dname.String,
				"body":         body,
				"ts":           ts,
			})
		}
	}
	writeJSON(w, http.StatusOK, results)
}

func (s *Server) handlePush(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	if r.Method == http.MethodPut {
		var req struct {
			Kind       string `json:"kind"` // "ntfy", "unifiedpush", "fcm", "apns"
			Target     string `json:"target"`
			NtfyURL    string `json:"ntfy_url"`
			DeviceName string `json:"device_name"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		reg, err := s.push.Register(u.ID, sess.ID, req.Kind, req.Target, req.NtfyURL, req.DeviceName)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, reg)
		return
	}

	list, err := s.push.List(u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, list)
}

func (s *Server) handlePushDelete(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	id := strings.TrimPrefix(r.URL.Path, "/api/v1/me/push/")
	s.push.Unregister(u.ID, id)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleScheduled(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	if r.Method == http.MethodPost {
		var req struct {
			ConvID        string   `json:"conv_id"`
			Body          string   `json:"body"`
			ThreadRoot    *string  `json:"thread_root"`
			AttachmentIDs []string `json:"attachment_ids"`
			DueMs         int64    `json:"due_ms"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ConvID == "" || req.DueMs == 0 {
			writeError(w, http.StatusBadRequest, "conv_id and due_ms are required")
			return
		}

		item, err := s.scheduled.Create(u.ID, req.ConvID, req.Body, req.ThreadRoot, req.AttachmentIDs, req.DueMs)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusCreated, item)
		return
	}

	list, err := s.scheduled.List(u.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, list)
}

func (s *Server) handleScheduledCancel(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	id := strings.TrimPrefix(r.URL.Path, "/api/v1/scheduled/")
	s.scheduled.Cancel(u.ID, id)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) handleIncomingHook(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/hooks/"), "/"), "/")
	if len(parts) >= 2 {
		hookID, secret := parts[0], parts[1]
		s.webhooks.HandleIncomingWebhook(w, r, hookID, secret)
		return
	}
	http.NotFound(w, r)
}

func (s *Server) handleBotTelegram(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/bot")
	slashIdx := strings.Index(path, "/")
	if slashIdx == -1 {
		http.NotFound(w, r)
		return
	}
	token := path[:slashIdx]
	method := path[slashIdx+1:]
	s.bots.HandleTelegramRequest(w, r, token, method)
}

func (s *Server) handleAdminUsers(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	if r.Method == http.MethodPost {
		s.admin.CreateUser(w, r)
		return
	}
	s.admin.ListUsers(w, r)
}

func (s *Server) handleAdminUserByID(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/admin/users/"), "/"), "/")
	targetID := parts[0]

	if len(parts) == 1 {
		if r.Method == http.MethodPatch {
			s.admin.UpdateUser(w, r, targetID)
			return
		}
		if r.Method == http.MethodDelete {
			s.database.Exec("UPDATE users SET deleted = 1 WHERE id = ?", targetID)
			writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
			return
		}
	}

	if len(parts) >= 2 {
		action := parts[1]
		switch action {
		case "login-link":
			s.admin.CreateLoginLink(w, r, targetID)
		case "revoke-sessions":
			s.admin.RevokeUserSessions(w, r, targetID)
		case "clear-history":
			s.admin.ClearHistory(w, r, targetID)
		case "delete-range":
			s.admin.DeleteRange(w, r, targetID)
		default:
			writeError(w, http.StatusNotFound, "action not found")
		}
	}
}

func (s *Server) handleAdminViewerConv(w http.ResponseWriter, r *http.Request, u *db.User, sess *db.Session) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/admin/viewer/conversations/"), "/"), "/")
	convID := parts[0]
	if len(parts) >= 2 && parts[1] == "messages" {
		s.admin.ViewerMessages(w, r, convID)
		return
	}
	http.NotFound(w, r)
}

func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
	// Serve admin static files if available under server/static/admin
	adminDir := "./static/admin"
	if _, err := os.Stat(adminDir); err == nil {
		if r.URL.Path == "/" || r.URL.Path == "/admin" {
			http.Redirect(w, r, "/admin/", http.StatusTemporaryRedirect)
			return
		}
		if strings.HasPrefix(r.URL.Path, "/admin/") {
			rel := strings.TrimPrefix(r.URL.Path, "/admin/")
			target := adminDir + "/" + rel
			if info, err := os.Stat(target); err == nil && !info.IsDir() {
				http.ServeFile(w, r, target)
				return
			}
			http.ServeFile(w, r, adminDir+"/index.html")
			return
		}
	}

	if r.URL.Path == "/" {
		http.Redirect(w, r, "/admin/", http.StatusTemporaryRedirect)
		return
	}
	http.NotFound(w, r)
}

// Auth Middleware
func (s *Server) requireAuth(fn func(http.ResponseWriter, *http.Request, *db.User, *db.Session)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := extractToken(r)
		if token == "" {
			writeError(w, http.StatusUnauthorized, "authorization required")
			return
		}

		u, sess, err := auth.ValidateAccessToken(s.database, token)
		if err != nil {
			writeError(w, http.StatusUnauthorized, err.Error())
			return
		}

		fn(w, r, u, sess)
	}
}

// Admin Auth Middleware
func (s *Server) requireAdmin(fn func(http.ResponseWriter, *http.Request, *db.User, *db.Session)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := extractToken(r)
		if token == "" {
			writeError(w, http.StatusUnauthorized, "admin authorization required")
			return
		}

		u, sess, err := auth.ValidateAccessToken(s.database, token)
		if err != nil || (u.Role != "owner" && u.Role != "admin") {
			writeError(w, http.StatusForbidden, "forbidden: admin role required")
			return
		}

		fn(w, r, u, sess)
	}
}

func extractToken(r *http.Request) string {
	authHeader := r.Header.Get("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
	}
	return r.URL.Query().Get("token")
}

func writeJSON(w http.ResponseWriter, code int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}
