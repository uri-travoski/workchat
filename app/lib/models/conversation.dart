class Conversation {
  final String id;
  final String kind; // "dm", "group_dm", "channel", "self"
  String? name;
  String? topic;
  final bool archived;
  final String? createdBy;
  final int createdMs;
  int lastSeq;
  int? lastTs;
  String? avatarAttachment;
  int unreadCount;
  bool isHidden; // Client-side hidden chat flag
  bool isPinned; // Pinned chat flag
  bool isMuted;  // Muted notification flag
  int pinOrder;  // User custom drag-and-drop order for pinned chats

  Conversation({
    required this.id,
    required this.kind,
    this.name,
    this.topic,
    this.archived = false,
    this.createdBy,
    required this.createdMs,
    this.lastSeq = 0,
    this.lastTs,
    this.avatarAttachment,
    this.unreadCount = 0,
    this.isHidden = false,
    this.isPinned = false,
    this.isMuted = false,
    this.pinOrder = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      kind: json['kind'] as String,
      name: json['name'] as String?,
      topic: json['topic'] as String?,
      archived: json['archived'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdMs: json['created_ms'] as int? ?? 0,
      lastSeq: json['last_seq'] as int? ?? 0,
      lastTs: json['last_ts'] as int?,
      avatarAttachment: json['avatar_attachment'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      isHidden: json['is_hidden'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      pinOrder: json['pin_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'name': name,
    'topic': topic,
    'archived': archived,
    'created_by': createdBy,
    'created_ms': createdMs,
    'last_seq': lastSeq,
    'last_ts': lastTs,
    'avatar_attachment': avatarAttachment,
    'unread_count': unreadCount,
    'is_hidden': isHidden,
    'is_pinned': isPinned,
    'is_muted': isMuted,
    'pin_order': pinOrder,
  };
}
