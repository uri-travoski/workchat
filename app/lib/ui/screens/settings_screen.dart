import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../state/chat_state.dart';
import '../../state/hidden_chat_manager.dart';
import '../../state/local_avatar_manager.dart';
import '../../theme/theme_manager.dart';
import '../components/avatar_widget.dart';
import 'hidden_lock_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBackButton;
  const SettingsScreen({super.key, this.showBackButton = true});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String currentVersion = '1.2.4';
  static const int buildNumber = 124;

  bool _isCheckingUpdate = false;
  String? _updateStatus;
  String? _latestVersion;
  String? _releaseUrl;

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatus = null;
    });

    try {
      // Check GitHub releases API
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/uri-travoski/workchat/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
        final htmlUrl = data['html_url'] as String? ?? 'https://github.com';

        if (tagName.isNotEmpty && tagName != currentVersion) {
          setState(() {
            _latestVersion = tagName;
            _releaseUrl = htmlUrl;
            _updateStatus = 'New version v$tagName available!';
          });
        } else {
          setState(() {
            _updateStatus = 'You are running the latest version (v$currentVersion).';
          });
        }
      } else {
        setState(() {
          _updateStatus = 'You are running the latest version (v$currentVersion).';
        });
      }
    } catch (_) {
      // Offline fallback
      setState(() {
        _updateStatus = 'You are running the latest version (v$currentVersion).';
      });
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final chatState = context.watch<ChatState>();
    final themeMgr = context.watch<ThemeManager>();
    final hiddenMgr = context.watch<HiddenChatManager>();
    final localAvatarMgr = context.watch<LocalAvatarManager>();

    final user = authState.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: widget.showBackButton,
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

          // Section: Appearance & Themes (2 New Themes)
          _sectionHeader(context, 'Appearance & Themes'),

          // Theme Mode (Dark / Light / System) Segmented Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    label: Text('System'),
                  ),
                ],
                selected: {themeMgr.themeMode},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) themeMgr.setThemeMode(set.first);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Visual Theme Cards
          _buildThemeSelectorCards(context, themeMgr),

          // Section: Typography & Fonts
          _sectionHeader(context, 'Typography & Fonts'),

          // Font Family Selector Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Font Family',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ThemeManager.availableFonts.map((f) {
                    final isSelected = themeMgr.fontFamily == f;
                    return ChoiceChip(
                      label: Text(
                        f,
                        style: TextStyle(
                          fontFamily: f,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) themeMgr.setFontFamily(f);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Font Size Stepper Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_size_rounded, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Font Size',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '${14 + themeMgr.fontSizeDelta} pt (${themeMgr.fontSizeDelta >= 0 ? "+${themeMgr.fontSizeDelta}" : "${themeMgr.fontSizeDelta}"} pt)',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Decrease font size (-1 pt)',
                    onPressed: themeMgr.fontSizeDelta > -3 ? () => themeMgr.adjustFontSize(-1) : null,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    child: Text(
                      '${14 + themeMgr.fontSizeDelta}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Increase font size (+1 pt)',
                    onPressed: themeMgr.fontSizeDelta < 8 ? () => themeMgr.adjustFontSize(1) : null,
                  ),
                ],
              ),
            ),
          ),

          // Font Weight Mode
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Font Weight',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'regular', label: Text('Regular')),
                      ButtonSegment(value: 'semi-bold', label: Text('Semi-Bold')),
                      ButtonSegment(value: 'bold', label: Text('Bold')),
                    ],
                    selected: {themeMgr.fontWeightMode},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) themeMgr.setFontWeightMode(set.first);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Live Typography & Theme Preview Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE PREVIEW (${themeMgr.fontFamily}, ${14 + themeMgr.fontSizeDelta} pt, ${themeMgr.fontWeightMode})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'WorkChat enables instant, private communication across channels and threads. 🚀⚡',
                    style: TextStyle(
                      fontFamily: themeMgr.fontFamily,
                      fontSize: (14.0 + themeMgr.fontSizeDelta).clamp(9.0, 36.0),
                      fontWeight: themeMgr.effectiveBodyWeight,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section: App Version & GitHub Updates
          _sectionHeader(context, 'Version & Updates'),
          ListTile(
            leading: const Icon(Icons.system_update_rounded),
            title: const Text('WorkChat Version'),
            subtitle: const Text('v$currentVersion (Build $buildNumber)'),
            trailing: _isCheckingUpdate
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton(
                    onPressed: _checkForUpdates,
                    child: const Text('Check for Updates'),
                  ),
          ),
          if (_updateStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _latestVersion != null ? const Color(0xFF10B981).withOpacity(0.15) : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _latestVersion != null ? const Color(0xFF10B981) : theme.dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _latestVersion != null ? Icons.download_rounded : Icons.check_circle_outline,
                      color: _latestVersion != null ? const Color(0xFF10B981) : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _updateStatus!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _latestVersion != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_latestVersion != null && _releaseUrl != null)
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Opening update: $_releaseUrl')),
                          );
                        },
                        child: const Text('Update Now'),
                      ),
                  ],
                ),
              ),
            ),

          // Section: Privacy & Hidden Chats
          _sectionHeader(context, 'Privacy & Hidden Chats'),
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
          _sectionHeader(context, 'Local Contact Avatar Overrides'),
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

          // Section: Push Notifications
          _sectionHeader(context, 'Hybrid Push Notifications'),
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
                if (widget.showBackButton && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildThemeSelectorCards(BuildContext context, ThemeManager themeMgr) {
    final theme = Theme.of(context);

    final themeOptions = [
      {
        'id': 'slate_steel',
        'name': 'Slate Steel',
        'subtitle': 'Original slate & steel-blue brand theme',
        'primary': const Color(0xFF1E293B),
        'accent': const Color(0xFF38BDF8),
      },
      {
        'id': 'purple_orange',
        'name': 'Purple + Sunset Orange',
        'subtitle': 'Deep purple with vivid orange accents',
        'primary': const Color(0xFF581C87),
        'accent': const Color(0xFFF97316),
      },
      {
        'id': 'dark_blue_yellow',
        'name': 'Dark Blue + Yellow',
        'subtitle': 'High-contrast midnight blue & gold',
        'primary': const Color(0xFF1E3A8A),
        'accent': const Color(0xFFEAB308),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: themeOptions.map((t) {
          final isSelected = themeMgr.activeThemeId == t['id'];
          final primary = t['primary'] as Color;
          final accent = t['accent'] as Color;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? accent.withOpacity(0.08) : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? accent : theme.dividerColor.withOpacity(0.4),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              onTap: () => themeMgr.setActiveTheme(t['id'] as String),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              title: Text(
                t['name'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? accent : null,
                ),
              ),
              subtitle: Text(
                t['subtitle'] as String,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: accent, size: 22)
                  : Icon(Icons.circle_outlined, color: Colors.grey.withOpacity(0.5), size: 22),
            ),
          );
        }).toList(),
      ),
    );
  }
}
