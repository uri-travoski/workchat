import 'package:flutter/material.dart';
import 'theme_base.dart';

class SlateSteelTheme implements AppThemeDefinition {
  @override
  String get id => 'slate_steel';

  @override
  String get name => 'Slate Steel (Icon Palette)';

  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateSurface = Color(0xFF1E293B); // Exact background of app-icon.svg
  static const Color slateBorder = Color(0xFF334155);
  static const Color steelBlueAccent = Color(0xFF4A83BD); // Steel-blue from PRD
  static const Color slateLightAccent = Color(0xFF38BDF8);
  static const Color crispWhite = Color(0xFFFFFFFF);

  @override
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: slateDark,
      primaryColor: steelBlueAccent,
      colorScheme: const ColorScheme.dark(
        primary: steelBlueAccent,
        primaryContainer: slateSurface,
        secondary: slateLightAccent,
        surface: slateSurface,
        onSurface: Color(0xFFF8FAFC),
        onPrimary: crispWhite,
        outline: slateBorder,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: slateSurface,
        selectedItemColor: slateLightAccent,
        unselectedItemColor: Color(0xFF94A3B8),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: const CardTheme(
        color: slateSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: slateBorder, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: slateBorder,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: slateSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: crispWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Noto Sans',
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFF8FAFC), fontFamily: 'Noto Sans'),
        bodyMedium: TextStyle(color: Color(0xFFCBD5E1), fontFamily: 'Noto Sans'),
        bodySmall: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Noto Sans'),
      ),
    );
  }

  @override
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      primaryColor: steelBlueAccent,
      colorScheme: const ColorScheme.light(
        primary: steelBlueAccent,
        primaryContainer: Color(0xFFE2E8F0),
        secondary: slateSurface,
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
        onPrimary: crispWhite,
        outline: Color(0xFFE2E8F0),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: steelBlueAccent,
        unselectedItemColor: Color(0xFF64748B),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: const CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Noto Sans',
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Noto Sans'),
        bodyMedium: TextStyle(color: Color(0xFF334155), fontFamily: 'Noto Sans'),
        bodySmall: TextStyle(color: Color(0xFF64748B), fontFamily: 'Noto Sans'),
      ),
    );
  }
}
