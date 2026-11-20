import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    TextTheme textTheme;
    try {
      switch (_fontFamily) {
        case 'Plus Jakarta Sans':
          textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
          break;
        case 'IBM Plex Sans':
          textTheme = GoogleFonts.ibmPlexSansTextTheme(base.textTheme);
          break;
        case 'Roboto':
          textTheme = GoogleFonts.robotoTextTheme(base.textTheme);
          break;
        case 'Inter':
        default:
          textTheme = GoogleFonts.interTextTheme(base.textTheme);
          break;
      }
    } catch (_) {
      textTheme = base.textTheme;
    }

    // Apply font size delta and font weight mode across styles
    final scale = 1.0 + (_fontSizeDelta * 0.07);
    final weight = effectiveBodyWeight;

    TextStyle scaleStyle(TextStyle? style, {bool applyWeight = true}) {
      if (style == null) return TextStyle(fontSize: 14 * scale);
      return style.copyWith(
        fontSize: (style.fontSize ?? 14) * scale,
        fontWeight: applyWeight && weight != FontWeight.normal ? weight : style.fontWeight,
      );
    }

    final scaledTextTheme = textTheme.copyWith(
      bodyLarge: scaleStyle(textTheme.bodyLarge),
      bodyMedium: scaleStyle(textTheme.bodyMedium),
      bodySmall: scaleStyle(textTheme.bodySmall, applyWeight: false),
      titleLarge: scaleStyle(textTheme.titleLarge, applyWeight: false),
      titleMedium: scaleStyle(textTheme.titleMedium),
      titleSmall: scaleStyle(textTheme.titleSmall),
      labelLarge: scaleStyle(textTheme.labelLarge),
      labelMedium: scaleStyle(textTheme.labelMedium),
      labelSmall: scaleStyle(textTheme.labelSmall, applyWeight: false),
    );

    return base.copyWith(
      textTheme: scaledTextTheme,
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
