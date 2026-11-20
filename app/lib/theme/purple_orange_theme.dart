import 'package:flutter/material.dart';
import 'theme_base.dart';

class PurpleOrangeTheme implements AppThemeDefinition {
  @override
  String get id => 'purple_orange';

  @override
  String get name => 'Purple + Sunset Orange';

  static const Color darkBg = Color(0xFF0F0A1C);
  static const Color darkSurface = Color(0xFF1E1435);
  static const Color darkBorder = Color(0xFF3B2A59);
  static const Color purplePrimary = Color(0xFF8B5CF6);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color lightBg = Color(0xFFFDF8FF);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE9D5FF);

  @override
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: purplePrimary,
      colorScheme: const ColorScheme.dark(
        primary: purplePrimary,
        secondary: orangeAccent,
        surface: darkSurface,
        onSurface: Color(0xFFFAF5FF),
        onPrimary: Colors.white,
        outline: darkBorder,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: orangeAccent,
        unselectedItemColor: Color(0xFFA78BFA),
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
      primaryColor: purplePrimary,
      colorScheme: const ColorScheme.light(
        primary: purplePrimary,
        secondary: orangeAccent,
        surface: lightSurface,
        onSurface: Color(0xFF1E1435),
        onPrimary: Colors.white,
        outline: lightBorder,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: orangeAccent,
        unselectedItemColor: Color(0xFF6B7280),
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
        foregroundColor: Color(0xFF1E1435),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF1E1435),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
