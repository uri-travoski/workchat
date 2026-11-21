import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_base.dart';
import 'slate_steel_theme.dart';
import 'purple_orange_theme.dart';
import 'dark_blue_yellow_theme.dart';

class ThemeManager extends ChangeNotifier {
  static const String _prefThemeMode = 'app_theme_mode';
  static const String _prefThemeId = 'app_theme_id';
  static const String _prefFontFamily = 'app_font_family';
  static const String _prefFontSizeDelta = 'app_font_size_delta';
  static const String _prefFontWeightMode = 'app_font_weight_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  String _activeThemeId = 'slate_steel';
  String _fontFamily = 'Inter'; // Inter, Plus Jakarta Sans, IBM Plex Sans, Roboto
  int _fontSizeDelta = 0; // -3 to +8 points
  String _fontWeightMode = 'regular'; // 'regular', 'semi-bold', 'bold'

  final Map<String, AppThemeDefinition> _themes = {
    'slate_steel': SlateSteelTheme(),
    'purple_orange': PurpleOrangeTheme(),
    'dark_blue_yellow': DarkBlueYellowTheme(),
  };

  ThemeMode get themeMode => _themeMode;
  String get activeThemeId => _activeThemeId;
  String get fontFamily => _fontFamily;
  int get fontSizeDelta => _fontSizeDelta;
  String get fontWeightMode => _fontWeightMode;

  List<AppThemeDefinition> get availableThemes => _themes.values.toList();
  static const List<String> availableFonts = [
    'Inter',
    'Plus Jakarta Sans',
    'IBM Plex Sans',
    'Roboto',
  ];

  AppThemeDefinition get activeTheme =>
      _themes[_activeThemeId] ?? _themes['slate_steel']!;

  ThemeData get lightTheme => _applyTypography(activeTheme.lightTheme);
  ThemeData get darkTheme => _applyTypography(activeTheme.darkTheme);

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

  Future<void> setFontFamily(String family) async {
    if (availableFonts.contains(family)) {
      _fontFamily = family;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefFontFamily, family);
    }
  }

  Future<void> adjustFontSize(int delta) async {
    _fontSizeDelta = (_fontSizeDelta + delta).clamp(-3, 8);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefFontSizeDelta, _fontSizeDelta);
  }

  Future<void> setFontWeightMode(String mode) async {
    if (['regular', 'semi-bold', 'bold'].contains(mode)) {
      _fontWeightMode = mode;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefFontWeightMode, mode);
    }
  }

  FontWeight get effectiveBodyWeight {
    switch (_fontWeightMode) {
      case 'semi-bold':
        return FontWeight.w600;
      case 'bold':
        return FontWeight.bold;
      default:
        return FontWeight.normal;
    }
  }

  ThemeData _applyTypography(ThemeData base) {
    final weight = effectiveBodyWeight;

    // Apply exact point adjustment: baseSize + _fontSizeDelta
    TextStyle styleFor(double baseSize, {FontWeight? customWeight, Color? color}) {
      final finalWeight = customWeight ?? weight;
      return TextStyle(
        fontFamily: _fontFamily,
        fontSize: (baseSize + _fontSizeDelta).clamp(9.0, 36.0),
        fontWeight: finalWeight,
        color: color,
      );
    }

    final isDark = base.brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final textTheme = TextTheme(
      displayLarge: styleFor(32, customWeight: FontWeight.bold, color: primaryTextColor),
      displayMedium: styleFor(28, customWeight: FontWeight.bold, color: primaryTextColor),
      displaySmall: styleFor(24, customWeight: FontWeight.bold, color: primaryTextColor),
      headlineLarge: styleFor(22, customWeight: FontWeight.w600, color: primaryTextColor),
      headlineMedium: styleFor(20, customWeight: FontWeight.w600, color: primaryTextColor),
      headlineSmall: styleFor(18, customWeight: FontWeight.w600, color: primaryTextColor),
      titleLarge: styleFor(18, customWeight: FontWeight.w600, color: primaryTextColor),
      titleMedium: styleFor(16, color: primaryTextColor),
      titleSmall: styleFor(14, customWeight: FontWeight.w600, color: primaryTextColor),
      bodyLarge: styleFor(16, color: primaryTextColor),
      bodyMedium: styleFor(14, color: primaryTextColor),
      bodySmall: styleFor(12, color: secondaryTextColor),
      labelLarge: styleFor(14, customWeight: FontWeight.w600, color: primaryTextColor),
      labelMedium: styleFor(12, color: secondaryTextColor),
      labelSmall: styleFor(11, color: secondaryTextColor),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: styleFor(18, customWeight: FontWeight.w600, color: primaryTextColor),
        toolbarTextStyle: styleFor(14, color: primaryTextColor),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        titleTextStyle: styleFor(18, customWeight: FontWeight.bold, color: primaryTextColor),
        contentTextStyle: styleFor(14, color: primaryTextColor),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: styleFor(15, customWeight: FontWeight.w600, color: primaryTextColor),
        subtitleTextStyle: styleFor(13, color: secondaryTextColor),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        selectedLabelStyle: styleFor(12, customWeight: FontWeight.bold),
        unselectedLabelStyle: styleFor(11),
      ),
    );
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
    final family = prefs.getString(_prefFontFamily);
    if (family != null && availableFonts.contains(family)) {
      _fontFamily = family;
    }
    _fontSizeDelta = prefs.getInt(_prefFontSizeDelta) ?? 0;
    final wMode = prefs.getString(_prefFontWeightMode);
    if (wMode != null && ['regular', 'semi-bold', 'bold'].contains(wMode)) {
      _fontWeightMode = wMode;
    }
    notifyListeners();
  }
}
