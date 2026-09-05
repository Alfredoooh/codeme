// ══════════════════════════════════════════════════════════════
// FILE: lib/features/ai_widgets/ai_widgets.dart
// ══════════════════════════════════════════════════════════════
// Barrel file: reexporta shared + os 3 widgets concretos, para que
// quem já importava "aiwidgets.dart" (agora "ai_widgets.dart")
// continue enxergando exatamente a mesma API pública de antes.
import 'package:flutter/material.dart';
import 'ai_widgets_shared.dart';
import 'market_widget.dart';
import 'calendar_widget.dart';
import 'map_widget.dart';

export 'ai_widgets_shared.dart';
export 'market_widget.dart';
export 'calendar_widget.dart';
export 'map_widget.dart';

Widget buildAiWidget(AiWidgetBlock block, AppColorScheme s) {
  switch (block.id) {
    case 'widget_market':   return AiMarketWidget(json: block.json, s: s);
    case 'widget_calendar': return AiCalendarWidget(json: block.json, s: s);
    case 'widget_map':      return AiMapWidget(json: block.json, s: s);
    default: return const SizedBox.shrink();
  }
}