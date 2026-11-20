package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/uri-travoski/workchat/server/internal/db"
	"golang.org/x/crypto/bcrypt"
)

func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

func CheckPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

func GenerateSecureToken(length int) (string, error) {
	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

func HashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

type SessionTokens struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	AccessExpMs  int64  `json:"access_exp_ms"`
	RefreshExpMs int64  `json:"refresh_exp_ms"`
	SessionID    string `json:"session_id"`
}

func CreateSession(database *db.DB, userID, deviceName, clientVersion, ip string) (*SessionTokens, error) {
	accessToken, err := GenerateSecureToken(32)
	if err != nil {
		return nil, err
	}
	refreshToken, err := GenerateSecureToken(32)
	if err != nil {
		return nil, err
	}

	sessionID, err := GenerateSecureToken(16)
	if err != nil {
		return nil, err
	}

	now := db.NowMs()
	accessExp := now + 15*24*3600*1000  // 15 days
	refreshExp := now + 60*24*3600*1000 // 60 days

	accessHash := HashToken(accessToken)
	refreshHash := HashToken(refreshToken)

	query := `INSERT INTO sessions (id, user_id, device_name, client_version, ip, access_hash, access_exp_ms, refresh_hash, refresh_exp_ms, created_ms, last_seen_ms, revoked)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`

	_, err = database.Exec(query, sessionID, userID, deviceName, clientVersion, ip, accessHash, accessExp, refreshHash, refreshExp, now, now)
	if err != nil {
		return nil, fmt.Errorf("failed to create session: %w", err)
	}

	return &SessionTokens{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		AccessExpMs:  accessExp,
		RefreshExpMs: refreshExp,
		SessionID:    sessionID,
	}, nil
}

func ValidateAccessToken(database *db.DB, token string) (*db.User, *db.Session, error) {
	if token == "" {
		return nil, nil, errors.New("empty token")
	}

	tokenHash := HashToken(token)
	now := db.NowMs()

	var sess db.Session
	var user db.User
	var email sql.NullString
	var lastActiveMs sql.NullInt64
	var avatarAttachment sql.NullString

	query := `SELECT s.id, s.user_id, s.device_name, s.client_version, s.ip, s.access_exp_ms, s.refresh_exp_ms, s.created_ms, s.last_seen_ms, s.revoked,
                     u.id, u.username, u.display_name, u.email, u.role, u.disabled, u.deleted, u.privacy_controls_enabled, u.hide_last_active, u.presence_pref, u.last_active_ms, u.avatar_attachment, u.is_bot, u.acked_cursor, u.created_ms
              FROM sessions s
              JOIN users u ON s.user_id = u.id
              WHERE s.access_hash = ? AND s.revoked = 0 AND s.access_exp_ms > ?`

	err := database.QueryRow(query, tokenHash, now).Scan(
		&sess.ID, &sess.UserID, &sess.DeviceName, &sess.ClientVersion, &sess.IP, &sess.AccessExpMs, &sess.RefreshExpMs, &sess.CreatedMs, &sess.LastSeenMs, &sess.Revoked,
		&user.ID, &user.Username, &user.DisplayName, &email, &user.Role, &user.Disabled, &user.Deleted, &user.PrivacyControlsEnabled, &user.HideLastActive, &user.PresencePref, &lastActiveMs, &avatarAttachment, &user.IsBot, &user.AckedCursor, &user.CreatedMs,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil, errors.New("invalid or expired session")
		}
		return nil, nil, err
	}

	if user.Disabled || user.Deleted {
		return nil, nil, errors.New("account disabled or deleted")
	}

	if email.Valid {
		user.Email = &email.String
	}
	if lastActiveMs.Valid {
		user.LastActiveMs = &lastActiveMs.Int64
	}
	if avatarAttachment.Valid {
		user.AvatarAttachment = &avatarAttachment.String
	}

	// Update last_seen_ms asynchronously or quickly
	go func(sid, uid string) {
		t := db.NowMs()
		database.Exec("UPDATE sessions SET last_seen_ms = ? WHERE id = ?", t, sid)
		database.Exec("UPDATE users SET last_active_ms = ? WHERE id = ?", t, uid)
	}(sess.ID, user.ID)

	return &user, &sess, nil
}

func CreateLoginLink(database *db.DB, userID string, expireDuration time.Duration) (string, error) {
	rawToken, err := GenerateSecureToken(32)
	if err != nil {
		return "", err
	}

	tokenHash := HashToken(rawToken)
	now := db.NowMs()
	exp := now + int64(expireDuration/time.Millisecond)

	_, err = database.Exec("INSERT INTO login_links (token_hash, user_id, created_ms, expires_ms) VALUES (?, ?, ?, ?)",
		tokenHash, userID, now, exp)
	if err != nil {
		return "", err
	}

	return rawToken, nil
}

func RedeemLoginLink(database *db.DB, rawToken, deviceName, clientVersion, ip string) (*SessionTokens, *db.User, error) {
	tokenHash := HashToken(rawToken)
	now := db.NowMs()

	var userID string
	var expiresMs int64
	var usedMs sql.NullInt64

	err := database.QueryRow("SELECT user_id, expires_ms, used_ms FROM login_links WHERE token_hash = ?", tokenHash).Scan(&userID, &expiresMs, &usedMs)
	if err != nil {
		return nil, nil, errors.New("invalid login link")
	}

	if usedMs.Valid {
		return nil, nil, errors.New("login link already used")
	}

	if expiresMs < now {
		return nil, nil, errors.New("login link expired")
	}

	// Mark used
	database.Exec("UPDATE login_links SET used_ms = ? WHERE token_hash = ?", now, tokenHash)

	// Fetch user
	var user db.User
	var email sql.NullString
	var lastActiveMs sql.NullInt64
	var avatarAttachment sql.NullString

	err = database.QueryRow("SELECT id, username, display_name, email, role, disabled, deleted, privacy_controls_enabled, hide_last_active, presence_pref, last_active_ms, avatar_attachment, is_bot, acked_cursor, created_ms FROM users WHERE id = ?", userID).Scan(
		&user.ID, &user.Username, &user.DisplayName, &email, &user.Role, &user.Disabled, &user.Deleted, &user.PrivacyControlsEnabled, &user.HideLastActive, &user.PresencePref, &lastActiveMs, &avatarAttachment, &user.IsBot, &user.AckedCursor, &user.CreatedMs,
	)
	if err != nil {
		return nil, nil, err
	}

	if user.Disabled || user.Deleted {
		return nil, nil, errors.New("account disabled or deleted")
	}

	if email.Valid {
		user.Email = &email.String
	}
	if lastActiveMs.Valid {
		user.LastActiveMs = &lastActiveMs.Int64
	}
	if avatarAttachment.Valid {
		user.AvatarAttachment = &avatarAttachment.String
	}

	sessTokens, err := CreateSession(database, userID, deviceName, clientVersion, ip)
	if err != nil {
		return nil, nil, err
	}

	return sessTokens, &user, nil
}
