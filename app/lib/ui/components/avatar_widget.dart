import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/local_avatar_manager.dart';

class AvatarWidget extends StatelessWidget {
  final String userId;
  final String displayName;
  final String? serverAvatarId;
  final String serverUrl;
  final double size;

  const AvatarWidget({
    super.key,
    required this.userId,
    required this.displayName,
    this.serverAvatarId,
    required this.serverUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final localAvatarMgr = context.watch<LocalAvatarManager>();
    final overridePath = localAvatarMgr.getOverridePath(userId);

    // 1. Local override image
    if (overridePath != null && File(overridePath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.file(
          File(overridePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    // 2. Server profile avatar
    if (serverAvatarId != null && serverAvatarId!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          '$serverUrl/users/$userId/avatar',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(),
        ),
      );
    }

    // 3. Fallback Initials
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    final initials = displayName.isNotEmpty
        ? displayName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
        : '?';

    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF0D9488),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFF4A83BD),
    ];
    final color = colors[userId.hashCode.abs() % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
