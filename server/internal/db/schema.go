package db

const Schema = `
CREATE TABLE IF NOT EXISTS users(
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE COLLATE NOCASE,
  display_name TEXT NOT NULL,
  email TEXT,
  password_hash TEXT NOT NULL,
  password_set INTEGER NOT NULL DEFAULT 1,
  role TEXT NOT NULL DEFAULT 'member',
  disabled INTEGER NOT NULL DEFAULT 0,
  deleted INTEGER NOT NULL DEFAULT 0,
  privacy_controls_enabled INTEGER NOT NULL DEFAULT 0,
  hide_last_active INTEGER NOT NULL DEFAULT 0,
  presence_pref TEXT NOT NULL DEFAULT 'auto',
  last_active_ms INTEGER,
  avatar_attachment TEXT,
  is_bot INTEGER NOT NULL DEFAULT 0,
  acked_cursor INTEGER NOT NULL DEFAULT 0,
  created_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  device_name TEXT NOT NULL DEFAULT '',
  client_version TEXT NOT NULL DEFAULT '',
  ip TEXT NOT NULL DEFAULT '',
  access_hash TEXT NOT NULL,
  access_exp_ms INTEGER NOT NULL,
  refresh_hash TEXT NOT NULL,
  refresh_exp_ms INTEGER NOT NULL,
  created_ms INTEGER NOT NULL,
  last_seen_ms INTEGER NOT NULL,
  revoked INTEGER NOT NULL DEFAULT 0,
  revoke_reason TEXT
);
CREATE INDEX IF NOT EXISTS sessions_access ON sessions(access_hash);
CREATE INDEX IF NOT EXISTS sessions_refresh ON sessions(refresh_hash);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS login_links(
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_ms INTEGER NOT NULL,
  expires_ms INTEGER NOT NULL,
  used_ms INTEGER
);

CREATE TABLE IF NOT EXISTS conversations(
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  name TEXT,
  topic TEXT,
  archived INTEGER NOT NULL DEFAULT 0,
  created_by TEXT,
  created_ms INTEGER NOT NULL,
  dm_key TEXT UNIQUE,
  last_seq INTEGER NOT NULL DEFAULT 0,
  last_ts INTEGER,
  avatar_attachment TEXT
);

CREATE TABLE IF NOT EXISTS members(
  conv_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  joined_ms INTEGER NOT NULL,
  PRIMARY KEY(conv_id, user_id)
);
CREATE INDEX IF NOT EXISTS members_user ON members(user_id);

CREATE TABLE IF NOT EXISTS messages(
  id TEXT PRIMARY KEY,
  conv_id TEXT NOT NULL,
  seq INTEGER NOT NULL,
  sender_id TEXT NOT NULL,
  client_id TEXT,
  body TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'text',
  ts INTEGER NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  edited_ms INTEGER,
  deleted INTEGER NOT NULL DEFAULT 0,
  thread_root TEXT,
  reply_to TEXT,
  mentions TEXT NOT NULL DEFAULT '[]',
  delivered_ms INTEGER,
  UNIQUE(conv_id, seq)
);
CREATE UNIQUE INDEX IF NOT EXISTS messages_client ON messages(sender_id, client_id) WHERE client_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS messages_ts ON messages(conv_id, ts);
CREATE INDEX IF NOT EXISTS messages_thread ON messages(conv_id, thread_root);

CREATE TABLE IF NOT EXISTS message_edits(
  message_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  body TEXT NOT NULL,
  ts INTEGER NOT NULL,
  PRIMARY KEY(message_id, version)
);

CREATE TABLE IF NOT EXISTS message_hidden(
  user_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  PRIMARY KEY(user_id, message_id)
);
CREATE INDEX IF NOT EXISTS hidden_msg ON message_hidden(message_id);

CREATE TABLE IF NOT EXISTS reactions(
  message_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  emoji TEXT NOT NULL,
  ts INTEGER NOT NULL,
  PRIMARY KEY(message_id, user_id, emoji)
);

CREATE TABLE IF NOT EXISTS attachments(
  id TEXT PRIMARY KEY,
  uploader_id TEXT NOT NULL,
  name TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  storage_key TEXT NOT NULL,
  purpose TEXT NOT NULL DEFAULT 'file',
  created_ms INTEGER NOT NULL,
  removed INTEGER NOT NULL DEFAULT 0,
  backup_id TEXT,
  meta TEXT
);

CREATE TABLE IF NOT EXISTS message_attachments(
  message_id TEXT NOT NULL,
  attachment_id TEXT NOT NULL,
  PRIMARY KEY(message_id, attachment_id)
);
CREATE INDEX IF NOT EXISTS ma_att ON message_attachments(attachment_id);

CREATE TABLE IF NOT EXISTS events(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  ts INTEGER NOT NULL,
  kind TEXT NOT NULL,
  ref TEXT,
  data TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS events_user ON events(user_id, id);

CREATE TABLE IF NOT EXISTS read_state(
  user_id TEXT NOT NULL,
  conv_id TEXT NOT NULL,
  last_read_seq INTEGER NOT NULL DEFAULT 0,
  marked_unread INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(user_id, conv_id)
);

CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS backups(
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  user_id TEXT,
  created_ms INTEGER NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  key TEXT NOT NULL,
  size INTEGER NOT NULL DEFAULT 0,
  attachments INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS pins(
  conv_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  pinned_by TEXT NOT NULL,
  ts INTEGER NOT NULL,
  PRIMARY KEY(conv_id, message_id)
);

CREATE TABLE IF NOT EXISTS bookmarks(
  id TEXT PRIMARY KEY,
  conv_id TEXT NOT NULL,
  title TEXT NOT NULL,
  url TEXT,
  attachment_id TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  created_by TEXT NOT NULL,
  created_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS bookmarks_conv ON bookmarks(conv_id);

CREATE TABLE IF NOT EXISTS user_groups(
  id TEXT PRIMARY KEY,
  handle TEXT NOT NULL UNIQUE COLLATE NOCASE,
  name TEXT NOT NULL,
  created_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS user_group_members(
  group_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  PRIMARY KEY(group_id, user_id)
);

CREATE TABLE IF NOT EXISTS thread_follows(
  user_id TEXT NOT NULL,
  thread_root TEXT NOT NULL,
  conv_id TEXT NOT NULL,
  following INTEGER NOT NULL DEFAULT 1,
  last_read_seq INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(user_id, thread_root)
);
CREATE INDEX IF NOT EXISTS thread_follows_root ON thread_follows(thread_root);

CREATE TABLE IF NOT EXISTS conv_prefs(
  user_id TEXT NOT NULL,
  conv_id TEXT NOT NULL,
  favourite INTEGER NOT NULL DEFAULT 0,
  section_id TEXT,
  mute_until_ms INTEGER,
  notify TEXT NOT NULL DEFAULT 'all',
  position INTEGER,
  PRIMARY KEY(user_id, conv_id)
);

CREATE TABLE IF NOT EXISTS avatar_overrides(
  viewer_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  target TEXT NOT NULL,
  attachment_id TEXT NOT NULL,
  updated_ms INTEGER NOT NULL,
  PRIMARY KEY(viewer_id, kind, target)
);

CREATE TABLE IF NOT EXISTS sections(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  collapsed INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS sections_user ON sections(user_id);

CREATE TABLE IF NOT EXISTS drafts(
  user_id TEXT NOT NULL,
  conv_id TEXT NOT NULL,
  thread_root TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL,
  updated_ms INTEGER NOT NULL,
  PRIMARY KEY(user_id, conv_id, thread_root)
);

CREATE TABLE IF NOT EXISTS push_registrations(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  session_id TEXT,
  kind TEXT NOT NULL,
  target TEXT NOT NULL,
  ntfy_url TEXT,
  device_name TEXT NOT NULL DEFAULT '',
  created_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS push_user ON push_registrations(user_id);

CREATE TABLE IF NOT EXISTS bots(
  user_id TEXT PRIMARY KEY,
  description TEXT NOT NULL DEFAULT '',
  token TEXT NOT NULL UNIQUE,
  home TEXT NOT NULL DEFAULT '{"blocks":[]}',
  webhook_url TEXT,
  webhook_secret TEXT,
  webhook_error TEXT,
  webhook_error_ms INTEGER,
  created_by TEXT,
  created_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS bot_updates(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bot_id TEXT NOT NULL,
  data TEXT NOT NULL,
  created_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS bot_updates_bot ON bot_updates(bot_id, id);

CREATE TABLE IF NOT EXISTS form_responses(
  message_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  button_id TEXT,
  data TEXT NOT NULL,
  ts INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS form_responses_msg ON form_responses(message_id);

CREATE TABLE IF NOT EXISTS webhooks_in(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  conv_id TEXT NOT NULL,
  secret TEXT NOT NULL,
  bot_user_id TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_by TEXT,
  created_ms INTEGER NOT NULL,
  last_used_ms INTEGER
);

CREATE TABLE IF NOT EXISTS webhooks_out(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  secret TEXT NOT NULL,
  events TEXT NOT NULL DEFAULT '[]',
  conv_id TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_by TEXT,
  created_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS deliveries(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,
  ref_id TEXT NOT NULL,
  url TEXT NOT NULL,
  secret TEXT,
  event TEXT NOT NULL,
  body TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  next_ms INTEGER NOT NULL,
  state TEXT NOT NULL DEFAULT 'pending',
  last_error TEXT,
  last_status INTEGER,
  created_ms INTEGER NOT NULL,
  done_ms INTEGER
);
CREATE INDEX IF NOT EXISTS deliveries_due ON deliveries(state, next_ms);
CREATE INDEX IF NOT EXISTS deliveries_ref ON deliveries(kind, ref_id);

CREATE TABLE IF NOT EXISTS scheduled(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  conv_id TEXT NOT NULL,
  body TEXT NOT NULL,
  thread_root TEXT,
  attachment_ids TEXT NOT NULL DEFAULT '[]',
  due_ms INTEGER NOT NULL,
  created_ms INTEGER NOT NULL,
  state TEXT NOT NULL DEFAULT 'pending',
  error TEXT,
  message_id TEXT,
  done_ms INTEGER
);
CREATE INDEX IF NOT EXISTS scheduled_due ON scheduled(state, due_ms);
CREATE INDEX IF NOT EXISTS scheduled_user ON scheduled(user_id);

CREATE TABLE IF NOT EXISTS labels(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS labels_user ON labels(user_id);

CREATE TABLE IF NOT EXISTS saved_items(
  user_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  conv_id TEXT NOT NULL,
  saved_ms INTEGER NOT NULL,
  PRIMARY KEY(user_id, message_id)
);

CREATE TABLE IF NOT EXISTS saved_labels(
  user_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  label_id TEXT NOT NULL,
  PRIMARY KEY(user_id, message_id, label_id)
);

CREATE TABLE IF NOT EXISTS activity_state(
  user_id TEXT PRIMARY KEY,
  read_ms INTEGER NOT NULL DEFAULT 0
);

CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(body, content='messages', content_rowid='rowid');

CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
  INSERT INTO messages_fts(rowid, body) VALUES (new.rowid, new.body);
END;

CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, body) VALUES('delete', old.rowid, old.body);
END;

CREATE TRIGGER IF NOT EXISTS messages_au AFTER UPDATE OF body ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, body) VALUES('delete', old.rowid, old.body);
  INSERT INTO messages_fts(rowid, body) VALUES (new.rowid, new.body);
END;
`
