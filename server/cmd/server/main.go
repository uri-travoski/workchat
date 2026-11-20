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
	log.Println("Starting WorkChat Server v1.1.0...")

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

	// Bootstrap admin if provided
	bootstrapAdmin(cfg, database)

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

func bootstrapAdmin(cfg *config.Config, database *db.DB) {
	if cfg.BootstrapAdmin == "" {
		return
	}

	parts := strings.SplitN(cfg.BootstrapAdmin, ":", 2)
	if len(parts) != 2 {
		log.Println("Invalid WORKCHAT_BOOTSTRAP_ADMIN format. Expected username:password")
		return
	}

	username, password := parts[0], parts[1]
	var count int
	database.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
	if count > 0 {
		return
	}

	passHash, err := auth.HashPassword(password)
	if err != nil {
		log.Printf("Failed to hash bootstrap admin password: %v", err)
		return
	}

	id := uuid.New().String()
	now := db.NowMs()
	var emailVal *string
	if cfg.BootstrapEmail != "" {
		emailVal = &cfg.BootstrapEmail
	}

	query := `INSERT INTO users (id, username, display_name, email, password_hash, role, disabled, deleted, created_ms)
              VALUES (?, ?, 'Administrator', ?, ?, 'owner', 0, 0, ?)`

	_, err = database.Exec(query, id, username, emailVal, passHash, now)
	if err != nil {
		log.Printf("Failed to bootstrap admin user: %v", err)
		return
	}

	log.Printf("Successfully bootstrapped initial owner account: %s", username)
}
