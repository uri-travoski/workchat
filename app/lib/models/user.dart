class User {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String role;
  final String? avatarAttachment;
  final String presencePref;
  final int? lastActiveMs;
  final bool isBot;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    required this.role,
    this.avatarAttachment,
    this.presencePref = 'auto',
    this.lastActiveMs,
    this.isBot = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'member',
      avatarAttachment: json['avatar_attachment'] as String?,
      presencePref: json['presence_pref'] as String? ?? 'auto',
      lastActiveMs: json['last_active_ms'] as int?,
      isBot: json['is_bot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'email': email,
    'role': role,
    'avatar_attachment': avatarAttachment,
    'presence_pref': presencePref,
    'last_active_ms': lastActiveMs,
    'is_bot': isBot,
  };
}
