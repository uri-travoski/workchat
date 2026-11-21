package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/google/uuid"
	"github.com/uri-travoski/workchat/server/internal/auth"
	"github.com/uri-travoski/workchat/server/internal/backup"
	"github.com/uri-travoski/workchat/server/internal/bots"
	"github.com/uri-travoski/workchat/server/internal/config"
	"github.com/uri-travoski/workchat/server/internal/db"
	"github.com/uri-travoski/workchat/server/internal/hub"
	"github.com/uri-travoski/workchat/server/internal/push"
	"github.com/uri-travoski/workchat/server/internal/routes"
	"github.com/uri-travoski/workchat/server/internal/scheduled"
	"github.com/uri-travoski/workchat/server/internal/storage"
	"github.com/uri-travoski/workchat/server/internal/webhooks"
)

func main() {
	log.Println("Starting WorkChat Server v1.2.3...")

	cfg := config.Load()

	if err := os.MkdirAll(cfg.DataDir, 0755); err != nil {
		log.Fatalf("Failed to create data dir: %v", err)
	}

	dbPath := filepath.Join(cfg.DataDir, "workchat.db")
	database, err := db.Open(dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer database.Close()

	// Bootstrap default users and channels
	bootstrapUsers(cfg, database)

	h := hub.New(database)
	go h.Run()

	st, err := storage.New(cfg.DataDir)
	if err != nil {
		log.Fatalf("Failed to initialize storage: %v", err)
	}

	p := push.New(database, cfg.NtfyURL)
	b := bots.New(database, h)

	w := webhooks.New(database, h)
	w.StartDeliveryWorker()

	s := scheduled.New(database, h)
	s.Start()

	bm, err := backup.New(database, cfg.DataDir)
	if err != nil {
		log.Fatalf("Failed to initialize backup manager: %v", err)
	}

	srvHandler := routes.NewServer(cfg, database, h, st, p, b, w, s, bm)

	addr := fmt.Sprintf("%s:%d", cfg.BindAddr, cfg.Port)
	server := &http.Server{
		Addr:         addr,
		Handler:      srvHandler,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Printf("WorkChat Server listening on %s (Public URL: %s)", addr, cfg.PublicURL)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server ListenAndServe error: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down WorkChat Server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("WorkChat Server exited cleanly.")
}

func bootstrapUsers(cfg *config.Config, database *db.DB) {
	adminUser := "reallybasic"
	adminPass := "t00lk1t1"
	if cfg.BootstrapAdmin != "" {
		parts := strings.SplitN(cfg.BootstrapAdmin, ":", 2)
		if len(parts) == 2 {
			adminUser, adminPass = parts[0], parts[1]
		}
	}

	// 1. Ensure reallybasic exists with owner role
	adminID := ensureUser(database, adminUser, "Really Basic", adminPass, "owner", cfg.BootstrapEmail)

	// 2. Ensure sam exists with member role
	samID := ensureUser(database, "sam", "Sam", "sam", "member", "")

	// 3. Ensure #general channel exists and both are members
	if adminID != "" && samID != "" {
		ensureGeneralAndDM(database, adminID, samID)
	}
}

func ensureUser(database *db.DB, username, displayName, password, role, email string) string {
	passHash, err := auth.HashPassword(password)
	if err != nil {
		log.Printf("Failed to hash password for %s: %v", username, err)
		return ""
	}

	var existingID string
	err = database.QueryRow("SELECT id FROM users WHERE LOWER(username) = LOWER(?)", username).Scan(&existingID)
	now := db.NowMs()
	var emailVal *string
	if email != "" {
		emailVal = &email
	}

	if err == nil {
		// Update password and ensure not disabled
		database.Exec(`UPDATE users SET password_hash = ?, role = ?, disabled = 0, deleted = 0 WHERE id = ?`,
			passHash, role, existingID)
		log.Printf("Updated credentials for user %s (role: %s)", username, role)
		return existingID
	}

	newID := uuid.New().String()
	query := `INSERT INTO users (id, username, display_name, email, password_hash, role, disabled, deleted, created_ms)
              VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)`
	_, err = database.Exec(query, newID, username, displayName, emailVal, passHash, role, now)
	if err != nil {
		log.Printf("Failed to insert user %s: %v", username, err)
		return ""
	}
	log.Printf("Successfully created user: %s (id: %s, role: %s)", username, newID, role)
	return newID
}

func ensureGeneralAndDM(database *db.DB, u1, u2 string) {
	now := db.NowMs()

	// 1. Check or create #general
	var generalID string
	err := database.QueryRow("SELECT id FROM conversations WHERE kind = 'channel' AND LOWER(name) = 'general'").Scan(&generalID)
	if err != nil {
		generalID = uuid.New().String()
		_, err = database.Exec(`INSERT INTO conversations (id, kind, name, topic, created_by, created_ms, last_seq, last_ts)
                               VALUES (?, 'channel', 'general', 'Company-wide announcements and general discussions 🌍', ?, ?, 0, ?)`,
			generalID, u1, now, now)
		if err == nil {
			log.Printf("Created default channel #general (id: %s)", generalID)
		}
	}

	if generalID != "" {
		database.Exec("INSERT OR IGNORE INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'admin', ?)", generalID, u1, now)
		database.Exec("INSERT OR IGNORE INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'member', ?)", generalID, u2, now)
	}

	// 2. Check or create DM between u1 and u2
	first, second := u1, u2
	if first > second {
		first, second = second, first
	}
	dmKey := fmt.Sprintf("%s:%s", first, second)

	var dmID string
	err = database.QueryRow("SELECT id FROM conversations WHERE dm_key = ?", dmKey).Scan(&dmID)
	if err != nil {
		dmID = uuid.New().String()
		_, err = database.Exec(`INSERT INTO conversations (id, kind, dm_key, created_by, created_ms, last_seq, last_ts)
                               VALUES (?, 'dm', ?, ?, ?, 0, ?)`,
			dmID, dmKey, u1, now, now)
		if err == nil {
			database.Exec("INSERT OR IGNORE INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'member', ?)", dmID, u1, now)
			database.Exec("INSERT OR IGNORE INTO members (conv_id, user_id, role, joined_ms) VALUES (?, ?, 'member', ?)", dmID, u2, now)
			log.Printf("Created direct message between %s and %s (id: %s)", u1, u2, dmID)
		}
	}
}
