import 'package:flutter/material.dart';

class ToolFonts {
  static const String defaultFamily = 'Inter';
  static const String serifFamily = 'IndispensableSerif';
  static const String timesFamily = 'TimesNewRoman';

  static TextStyle regular({double size = 14, Color color = Colors.black}) {
    return TextStyle(fontFamily: defaultFamily, fontSize: size, color: color);
  }

  static TextStyle bold({double size = 14, Color color = Colors.black}) {
    return TextStyle(
      fontFamily: defaultFamily,
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static TextStyle serif({double size = 14, Color color = Colors.black}) {
    return TextStyle(fontFamily: serifFamily, fontSize: size, color: color);
  }
}