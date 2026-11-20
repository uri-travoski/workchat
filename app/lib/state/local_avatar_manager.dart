import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAvatarManager extends ChangeNotifier {
  static const String _prefPrefix = 'local_avatar_override_';
  final Map<String, String> _overrides = {}; // userId -> localImagePath

  Map<String, String> get overrides => _overrides;

  LocalAvatarManager() {
    _loadOverrides();
  }

  Future<void> _loadOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefPrefix));
    for (final k in keys) {
      final userId = k.substring(_prefPrefix.length);
      final path = prefs.getString(k);
      if (path != null && File(path).existsSync()) {
        _overrides[userId] = path;
      }
    }
    notifyListeners();
  }

  String? getOverridePath(String userId) {
    return _overrides[userId];
  }

  Future<void> setOverride(String userId, File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final ext = p.extension(imageFile.path);
    final targetPath = p.join(appDir.path, 'avatars', 'override_$userId$ext');

    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);
    await imageFile.copy(targetPath);

    _overrides[userId] = targetPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefPrefix$userId', targetPath);
    notifyListeners();
  }

  Future<void> removeOverride(String userId) async {
    _overrides.remove(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefPrefix$userId');
    notifyListeners();
  }
}
