import 'package:flutter/material.dart';
import 'theme_base.dart';

class DarkBlueYellowTheme implements AppThemeDefinition {
  @override
  String get id => 'dark_blue_yellow';

  @override
  String get name => 'Dark Blue + Yellow (High Contrast)';

  static const Color darkBg = Color(0xFF0B132B);
  static const Color darkListBg = Color(0xFF0E1A38);
  static const Color darkSurface = Color(0xFF14213D);
  static const Color darkBubbleMy = Color(0xFF1D4ED8);
  static const Color darkBubbleTheir = Color(0xFF1E2E4F);
  static const Color darkBorder = Color(0xFF263A63);
  static const Color bluePrimary = Color(0xFF2563EB);
  static const Color yellowAccent = Color(0xFFFACC15);

  static const Color lightBg = Color(0xFFF0F5FF);
  static const Color lightListBg = Color(0xFFF4F8FF);
  static const Color lightSurface = Colors.white;
  static const Color lightBubbleMy = Color(0xFF2563EB);
  static const Color lightBubbleTheir = Color(0xFFFEF9C3);
  static const Color lightBorder = Color(0xFFBFDBFE);

  @override
  Color chatStageBg(bool isDark) => isDark ? darkBg : lightBg;

  @override
  Color chatListBg(bool isDark) => isDark ? darkListBg : lightListBg;

  @override
  Color surfaceHeaderBg(bool isDark) => isDark ? darkSurface : lightSurface;

  @override
  Color leftRailBg(bool isDark) => isDark ? darkSurface : const Color(0xFFE0EDFF);

  @override
  Color myBubbleBg(bool isDark) => isDark ? darkBubbleMy : lightBubbleMy;

  @override
  Color myBubbleTextColor(bool isDark) => Colors.white;

  @override
  Color theirBubbleBg(bool isDark) => isDark ? darkBubbleTheir : lightBubbleTheir;

  @override
  Color theirBubbleTextColor(bool isDark) => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF422006);

  @override
  Color accentColor(bool isDark) => yellowAccent;

  @override
  Color borderColor(bool isDark) => isDark ? darkBorder : lightBorder;

  @override
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: bluePrimary,
      colorScheme: const ColorScheme.dark(
        primary: bluePrimary,
        primaryContainer: darkSurface,
        secondary: yellowAccent,
        surface: darkSurface,
        onSurface: Color(0xFFF8FAFC),
        onPrimary: Colors.white,
        outline: darkBorder,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: yellowAccent,
        unselectedItemColor: Color(0xFF93C5FD),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: const CardTheme(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: darkBorder, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: bluePrimary,
      colorScheme: const ColorScheme.light(
        primary: bluePrimary,
        primaryContainer: Color(0xFFDBEAFE),
        secondary: yellowAccent,
        surface: lightSurface,
        onSurface: Color(0xFF0B132B),
        onPrimary: Colors.white,
        outline: lightBorder,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFFD97706),
        unselectedItemColor: Color(0xFF64748B),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: const CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: lightBorder, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0B132B),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF0B132B),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
