import 'package:flutter/material.dart';

abstract class AppThemeDefinition {
  String get id;
  String get name;
  ThemeData get lightTheme;
  ThemeData get darkTheme;
}
