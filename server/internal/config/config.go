package config

import (
	"os"
	"strconv"
	"strings"
)

type Config struct {
	Port               int
	BindAddr           string
	DataDir            string
	PublicURL          string
	Name               string
	BootstrapAdmin     string // "username:password"
	BootstrapEmail     string
	MaxUploadMB        int64
	NtfyURL            string
	BackupPassphrase   string
	EventRetentionDays int
}

func Load() *Config {
	cfg := &Config{
		Port:               getEnvInt("WORKCHAT_PORT", getEnvInt("SUPERCHAT_PORT", getEnvInt("ATOMIC_PORT", 8080))),
		BindAddr:           getEnv("WORKCHAT_BIND_ADDR", getEnv("SUPERCHAT_BIND_ADDR", "0.0.0.0")),
		DataDir:            getEnv("WORKCHAT_DATA_DIR", getEnv("SUPERCHAT_DATA_DIR", "./data")),
		PublicURL:          strings.TrimRight(getEnv("WORKCHAT_PUBLIC_URL", getEnv("SUPERCHAT_PUBLIC_URL", "http://localhost:8080")), "/"),
		Name:               getEnv("WORKCHAT_NAME", getEnv("SUPERCHAT_NAME", "WorkChat")),
		BootstrapAdmin:     getEnv("WORKCHAT_BOOTSTRAP_ADMIN", getEnv("SUPERCHAT_BOOTSTRAP_ADMIN", "")),
		BootstrapEmail:     getEnv("WORKCHAT_BOOTSTRAP_EMAIL", getEnv("SUPERCHAT_BOOTSTRAP_EMAIL", "")),
		MaxUploadMB:        int64(getEnvInt("WORKCHAT_MAX_UPLOAD_MB", getEnvInt("SUPERCHAT_MAX_UPLOAD_MB", 100))),
		NtfyURL:            strings.TrimRight(getEnv("WORKCHAT_NTFY_URL", getEnv("SUPERCHAT_NTFY_URL", "")), "/"),
		BackupPassphrase:   getEnv("WORKCHAT_BACKUP_PASSPHRASE", getEnv("SUPERCHAT_BACKUP_PASSPHRASE", "")),
		EventRetentionDays: getEnvInt("WORKCHAT_EVENT_RETENTION_DAYS", 30),
	}
	return cfg
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func getEnvInt(key string, defaultVal int) int {
	if val := os.Getenv(key); val != "" {
		if n, err := strconv.Atoi(val); err == nil {
			return n
		}
	}
	return defaultVal
}
