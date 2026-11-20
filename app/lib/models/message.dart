import 'attachment.dart';

class Reaction {
  final String emoji;
  final String userId;

  Reaction({required this.emoji, required this.userId});

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      emoji: json['emoji'] as String,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'user_id': userId,
  };
}

class Message {
  final String id;
  final String convId;
  final int seq;
  final String senderId;
  final String? clientId;
  String body;
  final String kind;
  final int ts;
  int version;
  int? editedMs;
  bool deleted;
  final String? threadRoot;
  final String? replyTo;
  final List<String> mentions;
  List<Attachment> attachments;
  List<Reaction> reactions;
  int replyCount;
  int? lastReplyAt;
  List<String> labels;
  bool isSaved;

  Message({
    required this.id,
    required this.convId,
    required this.seq,
    required this.senderId,
    this.clientId,
    required this.body,
    this.kind = 'text',
    required this.ts,
    this.version = 1,
    this.editedMs,
    this.deleted = false,
    this.threadRoot,
    this.replyTo,
    this.mentions = const [],
    this.attachments = const [],
    this.reactions = const [],
    this.replyCount = 0,
    this.lastReplyAt,
    this.labels = const [],
    this.isSaved = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    var rawAtts = json['attachments'] as List<dynamic>? ?? [];
    var atts = rawAtts.map((a) => Attachment.fromJson(a as Map<String, dynamic>)).toList();

    var rawReactions = json['reactions'] as List<dynamic>? ?? [];
    var reacts = rawReactions.map((r) => Reaction.fromJson(r as Map<String, dynamic>)).toList();

    var rawMentions = json['mentions'] as List<dynamic>? ?? [];
    var ments = rawMentions.map((m) => m.toString()).toList();

    var rawLabels = json['labels'] as List<dynamic>? ?? [];
    var lbls = rawLabels.map((l) => l.toString()).toList();

    return Message(
      id: json['id'] as String,
      convId: json['conv_id'] as String,
      seq: json['seq'] as int? ?? 0,
      senderId: json['sender_id'] as String,
      clientId: json['client_id'] as String?,
      body: json['body'] as String? ?? '',
      kind: json['kind'] as String? ?? 'text',
      ts: json['ts'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
      editedMs: json['edited_ms'] as int?,
      deleted: json['deleted'] as bool? ?? false,
      threadRoot: json['thread_root'] as String?,
      replyTo: json['reply_to'] as String?,
      mentions: ments,
      attachments: atts,
      reactions: reacts,
      replyCount: json['reply_count'] as int? ?? 0,
      lastReplyAt: json['last_reply_at'] as int?,
      labels: lbls,
      isSaved: json['is_saved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conv_id': convId,
    'seq': seq,
    'sender_id': senderId,
    'client_id': clientId,
    'body': body,
    'kind': kind,
    'ts': ts,
    'version': version,
    'edited_ms': editedMs,
    'deleted': deleted,
    'thread_root': threadRoot,
    'reply_to': replyTo,
    'mentions': mentions,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'reactions': reactions.map((r) => r.toJson()).toList(),
    'reply_count': replyCount,
    'last_reply_at': lastReplyAt,
    'labels': labels,
    'is_saved': isSaved,
  };
}
