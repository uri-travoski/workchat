package db

type User struct {
	ID                     string  `json:"id"`
	Username               string  `json:"username"`
	DisplayName            string  `json:"display_name"`
	Email                  *string `json:"email,omitempty"`
	PasswordHash           string  `json:"-"`
	PasswordSet            bool    `json:"password_set"`
	Role                   string  `json:"role"` // "owner", "admin", "member"
	Disabled               bool    `json:"disabled"`
	Deleted                bool    `json:"deleted"`
	PrivacyControlsEnabled bool    `json:"privacy_controls_enabled"`
	HideLastActive         bool    `json:"hide_last_active"`
	PresencePref           string  `json:"presence_pref"`
	LastActiveMs           *int64  `json:"last_active_ms,omitempty"`
	AvatarAttachment       *string `json:"avatar_attachment,omitempty"`
	IsBot                  bool    `json:"is_bot"`
	AckedCursor            int64   `json:"acked_cursor"`
	CreatedMs              int64   `json:"created_ms"`
}

type Session struct {
	ID            string `json:"id"`
	UserID        string `json:"user_id"`
	DeviceName    string `json:"device_name"`
	ClientVersion string `json:"client_version"`
	IP            string `json:"ip"`
	AccessHash    string `json:"-"`
	AccessExpMs   int64  `json:"access_exp_ms"`
	RefreshHash   string `json:"-"`
	RefreshExpMs  int64  `json:"refresh_exp_ms"`
	CreatedMs     int64  `json:"created_ms"`
	LastSeenMs    int64  `json:"last_seen_ms"`
	Revoked       bool   `json:"revoked"`
	RevokeReason  string `json:"revoke_reason,omitempty"`
}

type Conversation struct {
	ID               string  `json:"id"`
	Kind             string  `json:"kind"` // "dm", "group_dm", "channel", "self"
	Name             *string `json:"name,omitempty"`
	Topic            *string `json:"topic,omitempty"`
	Archived         bool    `json:"archived"`
	CreatedBy        *string `json:"created_by,omitempty"`
	CreatedMs        int64   `json:"created_ms"`
	DmKey            *string `json:"dm_key,omitempty"`
	LastSeq          int64   `json:"last_seq"`
	LastTs           *int64  `json:"last_ts,omitempty"`
	AvatarAttachment *string `json:"avatar_attachment,omitempty"`
	UnreadCount      int     `json:"unread_count,omitempty"`
	IsHidden         bool    `json:"is_hidden,omitempty"`
}

type Member struct {
	ConvID   string `json:"conv_id"`
	UserID   string `json:"user_id"`
	Role     string `json:"role"`
	JoinedMs int64  `json:"joined_ms"`
}

type Message struct {
	ID          string       `json:"id"`
	ConvID      string       `json:"conv_id"`
	Seq         int64        `json:"seq"`
	SenderID    string       `json:"sender_id"`
	ClientID    *string      `json:"client_id,omitempty"`
	Body        string       `json:"body"`
	Kind        string       `json:"kind"` // "text", "file", "system"
	Ts          int64        `json:"ts"`
	Version     int          `json:"version"`
	EditedMs    *int64       `json:"edited_ms,omitempty"`
	Deleted     bool         `json:"deleted"`
	ThreadRoot  *string      `json:"thread_root,omitempty"`
	ReplyTo     *string      `json:"reply_to,omitempty"`
	Mentions    []string     `json:"mentions"`
	DeliveredMs *int64       `json:"delivered_ms,omitempty"`
	Attachments []Attachment `json:"attachments,omitempty"`
	Reactions   []Reaction   `json:"reactions,omitempty"`
	ReplyCount  int          `json:"reply_count,omitempty"`
	LastReplyAt *int64       `json:"last_reply_at,omitempty"`
}

type Reaction struct {
	MessageID string `json:"message_id"`
	UserID    string `json:"user_id"`
	Emoji     string `json:"emoji"`
	Ts        int64  `json:"ts"`
}

type Attachment struct {
	ID          string  `json:"id"`
	UploaderID  string  `json:"uploader_id"`
	Name        string  `json:"name"`
	ContentType string  `json:"content_type"`
	Size        int64   `json:"size"`
	Sha256      string  `json:"sha256"`
	StorageKey  string  `json:"storage_key"`
	Purpose     string  `json:"purpose"`
	CreatedMs   int64   `json:"created_ms"`
	Removed     bool    `json:"removed"`
	Meta        *string `json:"meta,omitempty"`
}

type Event struct {
	ID     int64  `json:"id"`
	UserID string `json:"user_id"`
	Ts     int64  `json:"ts"`
	Kind   string `json:"kind"`
	Ref    string `json:"ref,omitempty"`
	Data   string `json:"data"`
}

type ReadState struct {
	UserID       string `json:"user_id"`
	ConvID       string `json:"conv_id"`
	LastReadSeq  int64  `json:"last_read_seq"`
	MarkedUnread bool   `json:"marked_unread"`
}

type Bot struct {
	UserID          string  `json:"user_id"`
	Description     string  `json:"description"`
	Token           string  `json:"token"`
	Home            string  `json:"home"`
	WebhookURL      *string `json:"webhook_url,omitempty"`
	WebhookSecret   *string `json:"webhook_secret,omitempty"`
	WebhookError    *string `json:"webhook_error,omitempty"`
	WebhookErrorMs  *int64  `json:"webhook_error_ms,omitempty"`
	CreatedBy       *string `json:"created_by,omitempty"`
	CreatedMs       int64   `json:"created_ms"`
}

type PushRegistration struct {
	ID         string  `json:"id"`
	UserID     string  `json:"user_id"`
	SessionID  *string `json:"session_id,omitempty"`
	Kind       string  `json:"kind"` // "ntfy", "fcm", "apns", "unifiedpush"
	Target     string  `json:"target"`
	NtfyURL    *string `json:"ntfy_url,omitempty"`
	DeviceName string  `json:"device_name"`
	CreatedMs  int64   `json:"created_ms"`
}

type ScheduledMessage struct {
	ID            string  `json:"id"`
	UserID        string  `json:"user_id"`
	ConvID        string  `json:"conv_id"`
	Body          string  `json:"body"`
	ThreadRoot    *string `json:"thread_root,omitempty"`
	AttachmentIDs string  `json:"attachment_ids"`
	DueMs         int64   `json:"due_ms"`
	CreatedMs     int64   `json:"created_ms"`
	State         string  `json:"state"` // "pending", "sent", "cancelled", "failed"
	Error         *string `json:"error,omitempty"`
	MessageID     *string `json:"message_id,omitempty"`
	DoneMs        *int64  `json:"done_ms,omitempty"`
}

type Pin struct {
	ConvID    string `json:"conv_id"`
	MessageID string `json:"message_id"`
	PinnedBy  string `json:"pinned_by"`
	Ts        int64  `json:"ts"`
}

type Bookmark struct {
	ID           string  `json:"id"`
	ConvID       string  `json:"conv_id"`
	Title        string  `json:"title"`
	URL          *string `json:"url,omitempty"`
	AttachmentID *string `json:"attachment_id,omitempty"`
	Position     int     `json:"position"`
	CreatedBy    string  `json:"created_by"`
	CreatedMs    int64   `json:"created_ms"`
}

type UserGroup struct {
	ID        string `json:"id"`
	Handle    string `json:"handle"`
	Name      string `json:"name"`
	CreatedMs int64  `json:"created_ms"`
}

type Section struct {
	ID        string `json:"id"`
	UserID    string `json:"user_id"`
	Name      string `json:"name"`
	Position  int    `json:"position"`
	Collapsed bool   `json:"collapsed"`
}

type Draft struct {
	UserID     string `json:"user_id"`
	ConvID     string `json:"conv_id"`
	ThreadRoot string `json:"thread_root"`
	Body       string `json:"body"`
	UpdatedMs  int64  `json:"updated_ms"`
}

type Label struct {
	ID       string `json:"id"`
	UserID   string `json:"user_id"`
	Name     string `json:"name"`
	Color    string `json:"color"`
	Position int    `json:"position"`
}

type ConvPref struct {
	UserID       string  `json:"user_id"`
	ConvID       string  `json:"conv_id"`
	Favourite    bool    `json:"favourite"`
	SectionID    *string `json:"section_id,omitempty"`
	MuteUntilMs  *int64  `json:"mute_until_ms,omitempty"`
	Notify       string  `json:"notify"`
	Position     *int    `json:"position,omitempty"`
}

type AvatarOverride struct {
	ViewerID     string `json:"viewer_id"`
	Kind         string `json:"kind"` // "user" or "conv"
	Target       string `json:"target"`
	AttachmentID string `json:"attachment_id"`
	UpdatedMs    int64  `json:"updated_ms"`
}
