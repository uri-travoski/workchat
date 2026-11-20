package backup

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/db"
)

type BackupManager struct {
	database  *db.DB
	backupDir string
}

func New(database *db.DB, dataDir string) (*BackupManager, error) {
	bDir := filepath.Join(dataDir, "backups")
	if err := os.MkdirAll(bDir, 0755); err != nil {
		return nil, err
	}
	return &BackupManager{
		database:  database,
		backupDir: bDir,
	}, nil
}

type UserBackupData struct {
	User     db.User      `json:"user"`
	Messages []db.Message `json:"messages"`
	Contacts []string     `json:"contacts"`
}

func (bm *BackupManager) BackupUser(userID, passphrase, reason string) (string, error) {
	var user db.User
	var email, avatar sql.NullString
	var lastActiveMs sql.NullInt64

	err := bm.database.QueryRow(`SELECT id, username, display_name, email, role, disabled, deleted, privacy_controls_enabled, hide_last_active, presence_pref, last_active_ms, avatar_attachment, is_bot, acked_cursor, created_ms
                                FROM users WHERE id = ?`, userID).
		Scan(&user.ID, &user.Username, &user.DisplayName, &email, &user.Role, &user.Disabled, &user.Deleted, &user.PrivacyControlsEnabled, &user.HideLastActive, &user.PresencePref, &lastActiveMs, &avatar, &user.IsBot, &user.AckedCursor, &user.CreatedMs)
	if err != nil {
		return "", fmt.Errorf("user not found: %w", err)
	}

	// Fetch messages sent by user
	rows, err := bm.database.Query("SELECT id, conv_id, seq, sender_id, body, kind, ts, version FROM messages WHERE sender_id = ? ORDER BY ts ASC", userID)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var msgs []db.Message
	for rows.Next() {
		var m db.Message
		if err := rows.Scan(&m.ID, &m.ConvID, &m.Seq, &m.SenderID, &m.Body, &m.Kind, &m.Ts, &m.Version); err == nil {
			msgs = append(msgs, m)
		}
	}

	backupData := UserBackupData{
		User:     user,
		Messages: msgs,
	}

	dataBytes, err := json.Marshal(backupData)
	if err != nil {
		return "", err
	}

	backupID := uuid.New().String()
	keyHash := sha256.Sum256([]byte(passphrase + backupID))
	encData, err := encryptAESGCM(dataBytes, keyHash[:])
	if err != nil {
		return "", err
	}

	backupFilePath := filepath.Join(bm.backupDir, fmt.Sprintf("%s.bak", backupID))
	if err := os.WriteFile(backupFilePath, encData, 0600); err != nil {
		return "", err
	}

	now := db.NowMs()
	_, err = bm.database.Exec(`INSERT INTO backups (id, kind, user_id, created_ms, reason, key, size, attachments)
                              VALUES (?, 'user', ?, ?, ?, ?, ?, 0)`,
		backupID, userID, now, reason, fmt.Sprintf("%x", keyHash[:8]), len(encData))
	if err != nil {
		return "", err
	}

	return backupID, nil
}

func (bm *BackupManager) BackupBeforeClearOrDelete(userID string) error {
	_, err := bm.BackupUser(userID, "internal-auto-backup", "auto_before_clear")
	return err
}

func encryptAESGCM(plaintext []byte, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}

	ciphertext := gcm.Seal(nonce, nonce, plaintext, nil)
	return ciphertext, nil
}

func decryptAESGCM(ciphertext []byte, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, errors.New("ciphertext too short")
	}

	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	return gcm.Open(nil, nonce, ciphertext, nil)
}
