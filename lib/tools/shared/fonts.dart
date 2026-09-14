=====================================================================
lib/tools/shared/fonts.dart
=====================================================================

// Helper de fontes customizadas para tools que desenham diretamente
// via Canvas (ex: table_image_tool, chart_tool, math_sheet_tool),
// em vez de depender só da fonte padrão do sistema.
//
// Usa as fontes já declaradas no pubspec.yaml (Inter, TimesNewRoman,
// IndispensableSerif) — carregadas via google_fonts ou diretamente
// como TextStyle com fontFamily, sem necessidade de ler bytes manual
// (ao contrário do satori no Node, o Flutter já resolve isso pelo
// pipeline normal de fontes do Skia).

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