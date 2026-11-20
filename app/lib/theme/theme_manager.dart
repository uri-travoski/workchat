import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_base.dart';
import 'slate_steel_theme.dart';

class ThemeManager extends ChangeNotifier {
  static const String _prefThemeMode = 'app_theme_mode';
  static const String _prefThemeId = 'app_theme_id';

  ThemeMode _themeMode = ThemeMode.dark;
  String _activeThemeId = 'slate_steel';

  final Map<String, AppThemeDefinition> _themes = {
    'slate_steel': SlateSteelTheme(),
  };

  ThemeMode get themeMode => _themeMode;
  String get activeThemeId => _activeThemeId;
  List<AppThemeDefinition> get availableThemes => _themes.values.toList();

  AppThemeDefinition get activeTheme =>
      _themes[_activeThemeId] ?? _themes['slate_steel']!;

  ThemeData get lightTheme => activeTheme.lightTheme;
  ThemeData get darkTheme => activeTheme.darkTheme;

  ThemeManager() {
    _loadPreferences();
  }

  void registerTheme(AppThemeDefinition theme) {
    _themes[theme.id] = theme;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefThemeMode, mode.name);
  }

  Future<void> setActiveTheme(String id) async {
    if (_themes.containsKey(id)) {
      _activeThemeId = id;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeId, id);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_prefThemeMode);
    if (modeStr != null) {
      if (modeStr == 'light') _themeMode = ThemeMode.light;
      if (modeStr == 'dark') _themeMode = ThemeMode.dark;
      if (modeStr == 'system') _themeMode = ThemeMode.system;
    }
    final themeId = prefs.getString(_prefThemeId);
    if (themeId != null && _themes.containsKey(themeId)) {
      _activeThemeId = themeId;
    }
    notifyListeners();
  }
}
