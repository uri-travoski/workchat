import 'package:flutter/material.dart';

abstract class AppThemeDefinition {
  String get id;
  String get name;
  ThemeData get lightTheme;
  ThemeData get darkTheme;

  Color chatStageBg(bool isDark);
  Color chatListBg(bool isDark);
  Color surfaceHeaderBg(bool isDark);
  Color leftRailBg(bool isDark);
  Color myBubbleBg(bool isDark);
  Color myBubbleTextColor(bool isDark);
  Color theirBubbleBg(bool isDark);
  Color theirBubbleTextColor(bool isDark);
  Color accentColor(bool isDark);
  Color borderColor(bool isDark);
}
