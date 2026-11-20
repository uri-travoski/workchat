import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../state/chat_state.dart';
import '../../state/hidden_chat_manager.dart';
import '../../state/local_avatar_manager.dart';
import '../../theme/theme_manager.dart';
import '../components/avatar_widget.dart';
import 'hidden_lock_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final chatState = context.watch<ChatState>();
    final themeMgr = context.watch<ThemeManager>();
    final hiddenMgr = context.watch<HiddenChatManager>();
    final localAvatarMgr = context.watch<LocalAvatarManager>();

    final user = authState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User profile card
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AvatarWidget(
                        userId: user.id,
                        displayName: user.displayName,
                        serverAvatarId: user.avatarAttachment,
                        serverUrl: authState.serverUrl,
                        size: 64,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text('@${user.username}', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(user.role.toUpperCase(), style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Section: Appearance & Theme
          _sectionHeader('Appearance & Theme'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme Mode'),
            subtitle: Text(themeMgr.themeMode.name.toUpperCase()),
            trailing: DropdownButton<ThemeMode>(
              value: themeMgr.themeMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              ],
              onChanged: (mode) {
                if (mode != null) themeMgr.setThemeMode(mode);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brush_outlined),
            title: const Text('Theme Palette'),
            subtitle: Text(themeMgr.activeTheme.name),
            trailing: const Icon(Icons.check, color: Color(0xFF38BDF8)),
          ),

          // Section: Privacy & Hidden Chats
          _sectionHeader('Privacy & Hidden Chats'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Hidden Chats PIN'),
            subtitle: Text(hiddenMgr.hasPin ? 'PIN is configured' : 'No PIN configured'),
            trailing: TextButton(
              onPressed: () {
                showDialog(context: context, builder: (_) => const HiddenLockDialog());
              },
              child: Text(hiddenMgr.hasPin ? 'Change PIN' : 'Set PIN'),
            ),
          ),
          if (hiddenMgr.hasPin)
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Lock Hidden Chats Now'),
              trailing: ElevatedButton(
                onPressed: () {
                  hiddenMgr.lock();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hidden chats locked')),
                  );
                },
                child: const Text('Lock'),
              ),
            ),

          // Section: Local Per-Contact Avatar Override
          _sectionHeader('Local Contact Avatar Overrides'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Assign custom local photos as avatars for other contacts strictly on your own device. Overrides are never sent to the server or shared.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ...chatState.users.where((u) => u.id != user?.id).map((otherUser) {
            final hasOverride = localAvatarMgr.getOverridePath(otherUser.id) != null;
            return ListTile(
              leading: AvatarWidget(
                userId: otherUser.id,
                displayName: otherUser.displayName,
                serverAvatarId: otherUser.avatarAttachment,
                serverUrl: authState.serverUrl,
                size: 36,
              ),
              title: Text(otherUser.displayName),
              subtitle: Text(hasOverride ? 'Custom local image assigned' : '@${otherUser.username}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Set custom local image',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null && result.files.single.path != null) {
                        await localAvatarMgr.setOverride(otherUser.id, File(result.files.single.path!));
                      }
                    },
                  ),
                  if (hasOverride)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: 'Remove local override',
                      onPressed: () {
                        localAvatarMgr.removeOverride(otherUser.id);
                      },
                    ),
                ],
              ),
            );
          }),

          // Section: Cache Retention
          _sectionHeader('Storage & Longevity'),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Local Cache Retention'),
            subtitle: Text('Keep offline messages for up to 6 months (auto-pruned)'),
            trailing: Text('6 Months', style: TextStyle(fontWeight: FontWeight.w600)),
          ),

          // Section: Push Notifications
          _sectionHeader('Hybrid Push Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Self-Hosted ntfy Push'),
            subtitle: const Text('Publish and receive instant push via Docker ntfy container'),
            trailing: Switch(value: true, onChanged: (_) {}),
          ),

          // Sign out
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                authState.logout();
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF38BDF8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
