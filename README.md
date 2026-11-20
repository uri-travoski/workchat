# WorkChat

WorkChat is a private, lightweight messaging platform supporting up to 100 users, built with a Go server and multi-platform Flutter client.

## Components

- **`server/`**: Single compiled Go binary running SQLite in WAL mode with WebSocket realtime sync, Telegram-compatible bot API, webhooks, file attachments, and hybrid push notifications (`ntfy` + FCM + APNs).
- **`app/`**: Multi-platform Flutter client (Android, Linux, Windows, iOS) featuring:
  - Theme based on the app icon palette (Slate Steel `#1E293B`)
  - Slack-style formatting toolbar (Bold, Italic, Lists, Inline Code, Code Blocks)
  - PIN / password protected hidden chats
  - Local per-contact avatar overrides stored strictly on-device
  - Universal file sharing with OS default viewer (`open_filex`)
  - Message threads with inline reply previews and dedicated thread views
  - Telegram-style reactions and emoji support
- **`packaging/`**: Packaging configurations for Windows (NSIS installer), Linux (.deb, .rpm, .AppImage, .flatpak), and Android split APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).

## Quick Start (Docker Compose)

```bash
docker compose -f server/docker-compose.yml up -d
```

Access the admin web panel at `http://localhost:8080/admin/`.

## License

MIT
