// ══════════════════════════════════════════════════════════════
// FILE: lib/aiwidgets.dart
// ══════════════════════════════════════════════════════════════
// Widgets nativos Flutter portados 1:1 (visual e comportamento) dos
// widgets renderizados em JS puro no chat Svelte de referência.
// Cada widget consome um bloco de JSON vindo da IA no formato:
//   ```widget_table
//   { ...json... }
//   ```
// e é detetado por parseAiWidgetBlocks() a partir do texto bruto da
// resposta da IA. Blocos de código normais (```dart, ```python, etc)
// NÃO passam por aqui — vão para o sistema de Canvas em aitab.dart.
// ══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:math_expressions/math_expressions.dart' as me;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'dart:ui' as ui;
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// IDS DE WIDGET SUPORTADOS
// ══════════════════════════════════════════════════════════════

const Set<String> kAiWidgetIds = {
  'widget_table', 'widget_code', 'widget_bar', 'widget_pie',
  'widget_sheet', 'widget_market', 'widget_calendar', 'widget_timer',
  'widget_mindmap', 'widget_graph', 'widget_map',
};

// ══════════════════════════════════════════════════════════════
// PARSER
// ══════════════════════════════════════════════════════════════

class AiWidgetBlock {
  final String id;
  final Map<String, dynamic> json;
  const AiWidgetBlock({required this.id, required this.json});
}

class AiWidgetParseResult {
  final String textWithMarkers;
  final List<AiWidgetBlock> blocks;
  const AiWidgetParseResult({required this.textWithMarkers, required this.blocks});
}

final RegExp _kWidgetBlockRe = RegExp(
  r'```(widget_[a-z]+)\s*\n([\s\S]*?)```',
  multiLine: true,
);

AiWidgetParseResult parseAiWidgetBlocks(String raw) {
  final blocks = <AiWidgetBlock>[];
  final replaced = raw.replaceAllMapped(_kWidgetBlockRe, (m) {
    final id = m.group(1)!;
    if (!kAiWidgetIds.contains(id)) return m.group(0)!;
    final body = m.group(2)!.trim();
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }
    final idx = blocks.length;
    blocks.add(AiWidgetBlock(id: id, json: json));
    return '\u0000WB$idx\u0000';
  });
  return AiWidgetParseResult(textWithMarkers: replaced, blocks: blocks);
}

/// Deteta se `raw` contém, neste momento (possivelmente a meio do
/// streaming), um bloco ```widget_x``` aberto mas ainda não fechado.
/// Usado para decidir se devemos mostrar o pill "A criar..." em vez
/// de tentar renderizar JSON incompleto.
bool hasOpenWidgetBlock(String raw) {
  final opens = RegExp(r'```widget_[a-z]+').allMatches(raw).length;
  final closesTotal = '```'.allMatches(raw).length;
  // Cada bloco widget consome 2 marcadores ``` (abertura+fecho). Se o
  // total de ``` no texto for ímpar relativamente ao número de aberturas
  // widget_*, há um bloco widget em aberto.
  return opens > 0 && closesTotal % 2 == 1;
}

// ══════════════════════════════════════════════════════════════
// DISPATCHER
// ══════════════════════════════════════════════════════════════

Widget buildAiWidget(AiWidgetBlock block, AppColorScheme s) {
  switch (block.id) {
    case 'widget_table':    return AiTableWidget(json: block.json, s: s);
    case 'widget_code':     return AiCodeWidget(json: block.json, s: s);
    case 'widget_bar':      return AiBarChartWidget(json: block.json, s: s);
    case 'widget_pie':      return AiPieChartWidget(json: block.json, s: s);
    case 'widget_sheet':    return AiSheetWidget(json: block.json, s: s);
    case 'widget_market':   return AiMarketWidget(json: block.json, s: s);
    case 'widget_calendar': return AiCalendarWidget(json: block.json, s: s);
    case 'widget_timer':    return AiTimerWidget(json: block.json, s: s);
    case 'widget_mindmap':  return AiMindMapWidget(json: block.json, s: s);
    case 'widget_graph':    return AiMathGraphWidget(json: block.json, s: s);
    case 'widget_map':      return AiMapWidget(json: block.json, s: s);
    default: return const SizedBox.shrink();
  }
}

// ══════════════════════════════════════════════════════════════
// TABLE
// ══════════════════════════════════════════════════════════════

class AiTableWidget extends StatelessWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiTableWidget({super.key, required this.json, required this.s});

  @override
  Widget build(BuildContext context) {
    final headers = (json['headers'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final rows = (json['rows'] as List?)
            ?.map((r) => (r as List).map((c) => c.toString()).toList())
            .toList() ??
        const <List<String>>[];

    final headerBg = s.isDark ? const Color(0xFF232323) : const Color(0xFFF4F4F4);
    final bg = s.isDark ? const Color(0xFF1B1B1B) : Colors.white;
    final borderColor = s.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.10);

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(s.isDark ? 0.35 : 0.08), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: BorderSide(color: borderColor),
            verticalInside: BorderSide(color: borderColor),
          ),
          children: [
            if (headers.isNotEmpty)
              TableRow(
                decoration: BoxDecoration(color: headerBg),
                children: headers
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(h,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: s.onSurface)),
                        ))
                    .toList(),
              ),
            for (final row in rows)
              TableRow(
                children: row
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(e.value,
                              textAlign: e.key > 0 ? TextAlign.center : TextAlign.left,
                              style: TextStyle(fontSize: 15, color: s.onSurface)),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BAR CHART
// ══════════════════════════════════════════════════════════════

class AiBarChartWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiBarChartWidget({super.key, required this.json, required this.s});
  @override State<AiBarChartWidget> createState() => _AiBarChartWidgetState();
}

class _AiBarChartWidgetState extends State<AiBarChartWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const _defaultColors = [
    Color(0xFF6F5AF6), Color(0xFFE74C3C), Color(0xFF27AE60), Color(0xFFF39C12),
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFEC4899), Color(0xFF8B5CF6),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final raw = (widget.json['data'] ?? widget.json['bars']) as List? ?? const [];
    final items = raw.asMap().entries.map((e) {
      final d = e.value as Map;
      return (
        label: (d['label'] ?? '?').toString(),
        value: (d['value'] is num) ? (d['value'] as num).toDouble() : double.tryParse(d['value'].toString()) ?? 0,
        color: _parseColor(d['color']) ?? _defaultColors[e.key % _defaultColors.length],
        unit: (d['unit'] ?? '').toString(),
      );
    }).toList();

    final maxVal = items.isEmpty ? 1.0 : items.map((e) => e.value).reduce(math.max);

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        SizedBox(
          height: 220,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in items) ...[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${item.value.toStringAsFixed(item.value == item.value.roundToDouble() ? 0 : 1)}${item.unit}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.onSurface)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 150,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: (maxVal > 0 ? (item.value / maxVal) : 0) * Curves.easeOut.transform(_c.value),
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 48),
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    boxShadow: [BoxShadow(color: item.color.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4))],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(item.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: s.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (item != items.last) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12, runSpacing: 6, alignment: WrapAlignment.center,
          children: items
              .map((item) => Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 6),
                    Text('${item.label} (${item.value.toStringAsFixed(item.value == item.value.roundToDouble() ? 0 : 1)})',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: s.onSurfaceVariant)),
                  ]))
              .toList(),
        ),
      ]),
    );
  }
}

Color? _parseColor(dynamic v) {
  if (v == null) return null;
  final str = v.toString().replaceAll('#', '');
  if (str.length == 6) return Color(int.parse('FF$str', radix: 16));
  if (str.length == 8) return Color(int.parse(str, radix: 16));
  return null;
}

// ══════════════════════════════════════════════════════════════
// PIE CHART
// ══════════════════════════════════════════════════════════════

class AiPieChartWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiPieChartWidget({super.key, required this.json, required this.s});
  @override State<AiPieChartWidget> createState() => _AiPieChartWidgetState();
}

class _AiPieChartWidgetState extends State<AiPieChartWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _defaultColors = [
    Color(0xFF2F80ED), Color(0xFFE74C3C), Color(0xFF27AE60), Color(0xFFF39C12),
    Color(0xFF9B59B6), Color(0xFF1ABC9C), Color(0xFFE67E22), Color(0xFF34495E),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final raw = (widget.json['data'] ?? widget.json['slices']) as List? ?? const [];
    final items = raw.asMap().entries.map((e) {
      final d = e.value as Map;
      return (
        label: (d['label'] ?? '?').toString(),
        value: (d['value'] is num) ? (d['value'] as num).toDouble() : double.tryParse(d['value'].toString()) ?? 0,
        color: _parseColor(d['color']) ?? _defaultColors[e.key % _defaultColors.length],
      );
    }).toList();
    final total = items.fold<double>(0, (s, e) => s + e.value).clamp(0.0001, double.infinity);

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: _PiePainter(items: items, total: total, progress: Curves.easeOutCubic.transform(_c.value), textColor: Colors.white),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12, runSpacing: 6, alignment: WrapAlignment.center,
          children: items
              .map((item) => Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 6),
                    Text('${item.label} (${item.value.toStringAsFixed(item.value == item.value.roundToDouble() ? 0 : 1)})',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurfaceVariant)),
                  ]))
              .toList(),
        ),
      ]),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<({String label, double value, Color color})> items;
  final double total;
  final double progress;
  final Color textColor;
  _PiePainter({required this.items, required this.total, required this.progress, required this.textColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.9;
    var startAngle = -math.pi / 2;
    for (final item in items) {
      final sweep = (item.value / total) * 2 * math.pi * progress;
      final paint = Paint()..color = item.color..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, true, paint);
      if (progress > 0.85) {
        final mid = startAngle + sweep / 2;
        final tr = radius * 0.6;
        final pos = center + Offset(math.cos(mid) * tr, math.sin(mid) * tr);
        final pct = (item.value / total * 100).toStringAsFixed(1) + '%';
        final tp = TextPainter(
          text: TextSpan(text: pct, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════
// CODE WIDGET (syntax highlight leve + copiar)
// ══════════════════════════════════════════════════════════════

class AiCodeWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiCodeWidget({super.key, required this.json, required this.s});
  @override State<AiCodeWidget> createState() => _AiCodeWidgetState();
}

class _AiCodeWidgetState extends State<AiCodeWidget> {
  bool _copied = false;

  List<TextSpan> _highlight(String line, String lang, AppColorScheme s) {
    final kwColor = s.isDark ? const Color(0xFFFF7B72) : const Color(0xFFB00020);
    final strColor = s.isDark ? const Color(0xFFA5D6FF) : const Color(0xFF005CC5);
    final numColor = s.isDark ? const Color(0xFF79C0FF) : const Color(0xFF0969DA);
    final cmtColor = s.isDark ? const Color(0xFF8B949E) : const Color(0xFF6A737D);
    final base = s.onSurface;

    final spans = <TextSpan>[];
    final tokenRe = RegExp(
      r'''("([^"\\]|\\.)*"|'([^'\\]|\\.)*'|//.*|#.*|\b\d+(\.\d+)?\b|\b(function|const|let|var|return|if|else|for|while|do|switch|case|break|continue|class|extends|import|export|from|async|await|new|this|try|catch|throw|true|false|null|def|lambda|yield|and|or|not|public|private|static|void|int|float|double|string|bool|interface|select|insert|update|delete|create|table|where)\b)''',
    );
    int last = 0;
    for (final m in tokenRe.allMatches(line)) {
      if (m.start > last) spans.add(TextSpan(text: line.substring(last, m.start), style: TextStyle(color: base)));
      final tok = m.group(0)!;
      Color c = base;
      if (tok.startsWith('"') || tok.startsWith("'")) c = strColor;
      else if (tok.startsWith('//') || tok.startsWith('#')) c = cmtColor;
      else if (RegExp(r'^\d').hasMatch(tok)) c = numColor;
      else c = kwColor;
      spans.add(TextSpan(text: tok, style: TextStyle(color: c, fontWeight: c == kwColor ? FontWeight.w600 : FontWeight.normal)));
      last = m.end;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last), style: TextStyle(color: base)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final lang = (widget.json['language'] ?? widget.json['lang'] ?? 'code').toString();
    final code = (widget.json['code'] ?? widget.json['content'] ?? widget.json['text'] ?? '').toString();
    final lines = code.replaceAll('\r\n', '\n').split('\n');

    final bg = s.isDark ? const Color(0xFF1B1B1B) : Colors.white;
    final border = s.isDark ? const Color(0xFF2F2F2F) : const Color(0xFFD7D7D7);
    final headerTxt = s.isDark ? const Color(0xFFF2F2F2) : const Color(0xFF2A2A2A);
    final lineNumClr = s.isDark ? const Color(0xFF7D7D7D) : const Color(0xFF8A8A8A);

    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(s.isDark ? 0.18 : 0.05), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 42,
          padding: const EdgeInsets.only(left: 14, right: 12),
          child: Row(children: [
            Text(lang.toUpperCase(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: headerTxt, letterSpacing: 0.2)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                setState(() => _copied = true);
                Future.delayed(const Duration(milliseconds: 1000), () { if (mounted) setState(() => _copied = false); });
              },
              child: SizedBox(
                width: 26, height: 26,
                child: Icon(_copied ? Icons.check : Icons.copy, size: 14, color: s.onSurfaceVariant),
              ),
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.asMap().entries.map((e) {
                return IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 52,
                      child: Text('${e.key + 1}',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: lineNumClr)),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.7),
                          children: _highlight(e.value, lang, s),
                        ),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHEET
// ══════════════════════════════════════════════════════════════

class AiSheetWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiSheetWidget({super.key, required this.json, required this.s});
  @override State<AiSheetWidget> createState() => _AiSheetWidgetState();
}

class _AiSheetWidgetState extends State<AiSheetWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final lines = (widget.json['lines'] as List?)
            ?.map((l) => (text: (l is Map ? l['text'] : l).toString(), title: (l is Map && l['title'] == true)))
            .toList() ??
        const <({String text, bool title})>[];

    final surface = s.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFEF8);
    final border = s.isDark ? const Color(0xFF333333) : const Color(0xFFD6D6D6);
    final textClr = s.isDark ? const Color(0xFFE8E8E8) : const Color(0xFF222222);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(vertical: _expanded ? 0 : 6),
        width: _expanded ? MediaQuery.of(context).size.width : math.min(MediaQuery.of(context).size.width * 0.92, 640),
        height: _expanded ? MediaQuery.of(context).size.height : math.min(MediaQuery.of(context).size.height * 0.7, 320),
        decoration: BoxDecoration(
          color: surface,
          border: _expanded ? null : Border.all(color: border),
          boxShadow: _expanded ? null : [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Stack(children: [
          CustomPaint(
            painter: _SheetGridPainter(lines: lines, textColor: textClr),
            child: const SizedBox.expand(),
          ),
          if (_expanded)
            Positioned(
              top: 14, right: 14,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _SheetGridPainter extends CustomPainter {
  final List<({String text, bool title})> lines;
  final Color textColor;
  _SheetGridPainter({required this.lines, required this.textColor});

  static const double leftPad = 72, topPad = 34, gap = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = const Color(0x295F91FF)..strokeWidth = 1;
    final marginPaint = Paint()..color = const Color(0x33FF5A5A)..strokeWidth = 1;

    final rowCount = math.max(lines.length + 2, (size.height / gap).ceil());
    for (int i = 0; i <= rowCount; i++) {
      final y = i * gap.toDouble();
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final marginX = leftPad - 16;
    canvas.drawLine(Offset(marginX, 0), Offset(marginX, rowCount * gap), marginPaint);

    for (int i = 0; i < lines.length; i++) {
      final item = lines[i];
      final y = topPad + i * gap - 10;
      final tp = TextPainter(
        text: TextSpan(
          text: item.text,
          style: TextStyle(
            color: textColor,
            fontSize: item.title ? 15 : 13,
            fontWeight: item.title ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - leftPad - 20);
      tp.paint(canvas, Offset(leftPad, y));
    }
  }

  @override
  bool shouldRepaint(covariant _SheetGridPainter old) => true;
}

// ══════════════════════════════════════════════════════════════
// MARKET
// ══════════════════════════════════════════════════════════════

class AiMarketWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMarketWidget({super.key, required this.json, required this.s});
  @override State<AiMarketWidget> createState() => _AiMarketWidgetState();
}

class _MarketData {
  final double price;
  final double change;
  final List<double> prices;
  final String name;
  final String symbol;
  const _MarketData({required this.price, required this.change, required this.prices, required this.name, required this.symbol});
}

class _AiMarketWidgetState extends State<AiMarketWidget> {
  bool _loading = true;
  String? _error;
  _MarketData? _data;
  String _tf = '1D';

  static const Map<String, ({int days, int points, double vol})> _tfCfg = {
    '1D': (days: 1, points: 96, vol: 0.003),
    '1S': (days: 7, points: 168, vol: 0.005),
    '1M': (days: 30, points: 120, vol: 0.008),
    '3M': (days: 90, points: 90, vol: 0.010),
    '1A': (days: 365, points: 120, vol: 0.015),
  };

  static const Map<String, String> _cryptoIds = {
    'BTC': 'bitcoin', 'ETH': 'ethereum', 'SOL': 'solana', 'BNB': 'binancecoin',
    'XRP': 'ripple', 'ADA': 'cardano', 'DOGE': 'dogecoin', 'AVAX': 'avalanche-2',
  };

  @override
  void initState() { super.initState(); _load(_tf); }

  List<double> _simHist(double price, int points, double vol) {
    final rnd = math.Random();
    final out = <double>[];
    var p = price * (0.85 + rnd.nextDouble() * 0.1);
    for (int i = 0; i < points; i++) {
      p += (rnd.nextDouble() - 0.48) * price * vol;
      p = math.max(p, price * 0.5);
      out.add(p);
    }
    out.add(price);
    return out;
  }

  Future<void> _load(String tf) async {
    setState(() { _loading = true; _error = null; });
    final type = (widget.json['type'] ?? 'forex').toString();
    final symbol = (widget.json['symbol'] ?? 'USDEUR').toString();
    final name = (widget.json['name'] ?? symbol).toString();
    final cfg = _tfCfg[tf]!;
    try {
      _MarketData data;
      if (type == 'forex') {
        final base = symbol.substring(0, math.min(3, symbol.length)).toUpperCase();
        final quote = symbol.length >= 6 ? symbol.substring(3, 6).toUpperCase() : 'USD';
        final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/$base')).timeout(const Duration(seconds: 10));
        final d = jsonDecode(res.body);
        final rates = d['rates'] as Map<String, dynamic>?;
        final price = (rates?[quote] as num?)?.toDouble() ?? (rates?['USD'] as num?)?.toDouble() ?? 1.0;
        final prices = _simHist(price, cfg.points, 0.002);
        data = _MarketData(price: price, change: ((price - prices.first) / prices.first) * 100, prices: prices, name: '$base/$quote', symbol: '$base/$quote');
      } else if (type == 'crypto') {
        final sym = symbol.toUpperCase();
        final priceRes = await http.get(Uri.parse('https://api.coinbase.com/v2/prices/$sym-USD/spot')).timeout(const Duration(seconds: 10));
        final priceJson = jsonDecode(priceRes.body);
        final price = double.parse(priceJson['data']['amount'].toString());
        List<double> prices;
        try {
          final id = _cryptoIds[sym];
          final hRes = await http.get(Uri.parse('https://api.coingecko.com/api/v3/coins/$id/market_chart?vs_currency=usd&days=${cfg.days}&precision=2')).timeout(const Duration(seconds: 10));
          final hJson = jsonDecode(hRes.body);
          final rawPrices = (hJson['prices'] as List?)?.map((p) => (p[1] as num).toDouble()).toList() ?? [];
          if (rawPrices.isEmpty) throw Exception('no history');
          prices = rawPrices;
        } catch (_) {
          prices = _simHist(price, cfg.points, cfg.vol);
        }
        data = _MarketData(price: price, change: ((price - prices.first) / prices.first) * 100, prices: prices, name: name, symbol: sym);
      } else {
        final rnd = math.Random();
        final price = 100 + rnd.nextDouble() * 50;
        final prices = _simHist(price, cfg.points, cfg.vol);
        data = _MarketData(price: price, change: ((price - prices.first) / prices.first) * 100, prices: prices, name: name, symbol: symbol);
      }
      if (mounted) setState(() { _data = data; _loading = false; _tf = tf; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro: $e'; _loading = false; });
    }
  }

  String _fmtPrice(double p, String type) {
    if (type == 'forex') return p.toStringAsFixed(4);
    if (p >= 1000) return '\$${p.toStringAsFixed(2)}';
    if (p >= 1) return '\$${p.toStringAsFixed(2)}';
    return '\$${p.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final type = (widget.json['type'] ?? 'forex').toString();
    const bg = Color(0xFF111318);

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 32, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6F5AF6)))),
            )
          : _error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)))
              : _buildLoaded(context, type),
    );
  }

  Widget _buildLoaded(BuildContext context, String type) {
    final d = _data!;
    final isUp = d.change >= 0;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: Color(0xFF1E2128), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(d.symbol.substring(0, math.min(2, d.symbol.length)).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 2),
              Text('${d.symbol} · ${type.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmtPrice(d.price, type), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: isUp ? const Color(0xFF0D2E1A) : const Color(0xFF2E0D0D), borderRadius: BorderRadius.circular(6)),
              child: Text('${isUp ? '▲ +' : '▼ '}${d.change.abs().toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
            ),
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: SizedBox(
          height: 150,
          child: CustomPaint(painter: _MarketChartPainter(prices: d.prices, isUp: isUp), child: const SizedBox.expand()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _tfCfg.keys.map((tf) {
            final active = tf == _tf;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => _load(tf),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: active ? const Color(0xFF1E2128) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                  child: Text(tf, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFF444444))),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

class _MarketChartPainter extends CustomPainter {
  final List<double> prices;
  final bool isUp;
  _MarketChartPainter({required this.prices, required this.isUp});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;
    final minV = prices.reduce(math.min), maxV = prices.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final color = isUp ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final pts = prices.asMap().entries.map((e) {
      final x = (e.key / (prices.length - 1)) * size.width;
      final y = (1 - (e.value - minV) / range) * (size.height - 20) + 10;
      return Offset(x, y);
    }).toList();

    final fillPath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      fillPath.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    fillPath.lineTo(pts.last.dx, size.height);
    fillPath.lineTo(pts.first.dx, size.height);
    fillPath.close();

    final gradient = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [color.withOpacity(0.33), color.withOpacity(0)]);
    canvas.drawPath(fillPath, Paint()..shader = gradient);

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      linePath.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(linePath, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);

    canvas.drawCircle(pts.last, 4.5, Paint()..color = color);
    canvas.drawCircle(pts.last, 4.5, Paint()..color = const Color(0xFF111318)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter old) => old.prices != prices;
}

// ══════════════════════════════════════════════════════════════
// CALENDAR
// ══════════════════════════════════════════════════════════════

class AiCalendarWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiCalendarWidget({super.key, required this.json, required this.s});
  @override State<AiCalendarWidget> createState() => _AiCalendarWidgetState();
}

class _AiCalendarWidgetState extends State<AiCalendarWidget> {
  static const _months = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
  static const _weekdays = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];

  late DateTime _current;
  late DateTime _today;
  late String _selectedKey;
  late Map<String, List<({String name, String time, Color color})>> _events;

  String _key(int y, int m, int d) => '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _current = DateTime(_today.year, _today.month, 1);
    _selectedKey = _key(_today.year, _today.month, _today.day);
    _events = {};
    final rawEvents = (widget.json['events'] as List?) ?? const [];
    for (final e in rawEvents) {
      final d = e as Map;
      final date = (d['date'] ?? '').toString();
      _events.putIfAbsent(date, () => []).add((
        name: (d['name'] ?? d['title'] ?? '').toString(),
        time: (d['time'] ?? '').toString(),
        color: _parseColor(d['color']) ?? const Color(0xFF6F5AF6),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bg = s.isDark ? const Color(0xFF1B1B1B) : Colors.white;
    final border = s.isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
    final todayBg = s.isDark ? const Color(0xFF2A2A40) : const Color(0xFFEDE9FF);
    final todayTx = s.isDark ? const Color(0xFFA78BFA) : const Color(0xFF6F5AF6);
    const selBg = Color(0xFF6F5AF6);
    final mutedClr = s.isDark ? const Color(0xFF888888) : const Color(0xFF999999);
    final evBg = s.isDark ? const Color(0xFF252535) : const Color(0xFFF7F6FF);

    final y = _current.year, m = _current.month;
    final firstDay = DateTime(y, m, 1).weekday % 7;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final daysInPrev = DateTime(y, m, 0).day;

    final cells = <Widget>[];
    for (int i = firstDay - 1; i >= 0; i--) {
      cells.add(_dayCell((daysInPrev - i).toString(), other: true, isToday: false, isSel: false, onTap: null));
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final key = _key(y, m, d);
      final isToday = DateTime(y, m, d) == DateTime(_today.year, _today.month, _today.day);
      cells.add(_dayCell(d.toString(),
          other: false, isToday: isToday, isSel: key == _selectedKey, hasEvent: _events[key]?.isNotEmpty == true,
          onTap: () => setState(() => _selectedKey = key)));
    }
    final total = firstDay + daysInMonth;
    final rem = total % 7 == 0 ? 0 : 7 - total % 7;
    for (int d = 1; d <= rem; d++) {
      cells.add(_dayCell(d.toString(), other: true, isToday: false, isSel: false, onTap: null));
    }

    final dayEvents = _events[_selectedKey] ?? const [];

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 1.5), borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _navBtn(s, Icons.chevron_left, () => setState(() => _current = DateTime(_current.year, _current.month - 1, 1))),
          Text('${_months[m - 1]} $y', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: s.onSurface)),
          _navBtn(s, Icons.chevron_right, () => setState(() => _current = DateTime(_current.year, _current.month + 1, 1))),
        ]),
        const SizedBox(height: 10),
        Row(children: _weekdays.map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedClr)))))
            .toList()),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4, crossAxisSpacing: 4,
          children: cells,
        ),
        const SizedBox(height: 14),
        Divider(color: border, height: 1),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Text('EVENTOS DO DIA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: mutedClr, letterSpacing: 0.5))),
        const SizedBox(height: 10),
        if (dayEvents.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Nenhum evento neste dia', style: TextStyle(fontSize: 13, color: mutedClr.withOpacity(0.7))))
        else
          Column(children: dayEvents.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: evBg, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface)),
                Text(e.time, style: TextStyle(fontSize: 12, color: mutedClr)),
              ])),
            ]),
          )).toList()),
      ]),
    );
  }

  Widget _navBtn(AppColorScheme s, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: s.hover, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: s.onSurface),
        ),
      );

  Widget _dayCell(String num, {required bool other, required bool isToday, required bool isSel, bool hasEvent = false, VoidCallback? onTap}) {
    final s = widget.s;
    final todayBg = s.isDark ? const Color(0xFF2A2A40) : const Color(0xFFEDE9FF);
    final todayTx = s.isDark ? const Color(0xFFA78BFA) : const Color(0xFF6F5AF6);
    const selBg = Color(0xFF6F5AF6);
    final mutedClr = s.isDark ? const Color(0xFF888888) : const Color(0xFF999999);

    Color? bg; Color txt = s.onSurface; FontWeight weight = FontWeight.normal;
    if (other) { txt = mutedClr.withOpacity(0.4); }
    else if (isSel) { bg = selBg; txt = Colors.white; weight = FontWeight.w700; }
    else if (isToday) { bg = todayBg; txt = todayTx; weight = FontWeight.w700; }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Stack(alignment: Alignment.center, children: [
          Text(num, style: TextStyle(fontSize: 14, color: txt, fontWeight: weight)),
          if (hasEvent)
            Positioned(bottom: 3, child: Container(width: 5, height: 5, decoration: BoxDecoration(color: isSel ? Colors.white : const Color(0xFF6F5AF6), shape: BoxShape.circle))),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TIMER
// ══════════════════════════════════════════════════════════════

class AiTimerWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiTimerWidget({super.key, required this.json, required this.s});
  @override State<AiTimerWidget> createState() => _AiTimerWidgetState();
}

class _AiTimerWidgetState extends State<AiTimerWidget> {
  late int total;
  late int remaining;
  bool running = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    total = ((widget.json['seconds'] ?? widget.json['duration']) as num?)?.toInt() ?? 60;
    remaining = total;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String _fmt(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _toggle() {
    if (running) {
      _timer?.cancel();
      setState(() => running = false);
    } else {
      if (remaining <= 0) return;
      setState(() => running = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => remaining--);
        if (remaining <= 0) { _timer?.cancel(); setState(() => running = false); }
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() { running = false; remaining = total; });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bg = s.isDark ? const Color(0xFF1B1B1B) : Colors.white;
    final border = s.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5EA);
    final mutedClr = s.isDark ? const Color(0xFF939393) : const Color(0xFF888888);
    final label = (widget.json['label'] ?? widget.json['title'] ?? 'Temporizador').toString();

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 1.5), borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedClr, letterSpacing: 0.6)),
        const SizedBox(height: 16),
        Text(_fmt(remaining), style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: s.onSurface, letterSpacing: -1)),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: total > 0 ? remaining / total : 0,
            minHeight: 4,
            backgroundColor: border,
            valueColor: AlwaysStoppedAnimation(remaining <= 10 ? const Color(0xFFEF4444) : s.primary),
          ),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(12)),
              child: Text(running ? 'Pausar' : (remaining < total ? 'Continuar' : 'Iniciar'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(12)),
              child: Text('Reiniciar', style: TextStyle(color: s.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MIND MAP
// ══════════════════════════════════════════════════════════════

class _MindNode {
  final String id;
  final String label;
  final Color color;
  final List<_MindNode> children;
  _MindNode({required this.id, required this.label, required this.color, required this.children});

  factory _MindNode.fromJson(Map j, AppColorScheme s, int depth) {
    final childrenRaw = (j['children'] as List?) ?? const [];
    return _MindNode(
      id: (j['id'] ?? UniqueKey().toString()).toString(),
      label: (j['label'] ?? '').toString(),
      color: _parseColor(j['color']) ?? s.primary,
      children: childrenRaw.map((c) => _MindNode.fromJson(c as Map, s, depth + 1)).toList(),
    );
  }
}

class AiMindMapWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMindMapWidget({super.key, required this.json, required this.s});
  @override State<AiMindMapWidget> createState() => _AiMindMapWidgetState();
}

class _AiMindMapWidgetState extends State<AiMindMapWidget> {
  bool _expanded = false;
  final Set<String> _collapsed = {};
  final TransformationController _tc = TransformationController();
  late _MindNode _root;

  @override
  void initState() {
    super.initState();
    final treeJson = (widget.json['tree'] ?? widget.json['data']) as Map? ??
        {'id': 'root', 'label': widget.json['title'] ?? 'Root', 'children': []};
    _root = _MindNode.fromJson(treeJson, widget.s, 0);
  }

  double _subtreeHeight(_MindNode n) {
    if (_collapsed.contains(n.id) || n.children.isEmpty) return 56;
    return n.children.fold<double>(0, (s, c) => s + _subtreeHeight(c));
  }

  void _layout(_MindNode n, double x, double yStart, Map<String, Offset> pos) {
    final h = _subtreeHeight(n);
    pos[n.id] = Offset(x, yStart + h / 2);
    if (!_collapsed.contains(n.id) && n.children.isNotEmpty) {
      var curY = yStart;
      for (final c in n.children) {
        _layout(c, x + 170, curY, pos);
        curY += _subtreeHeight(c);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final cardBg = s.isDark ? const Color(0xFF1B1B1B) : Colors.white;
    final linkClr = s.isDark ? const Color(0xFF666666) : const Color(0xFFBBBBBB);

    final pos = <String, Offset>{};
    _layout(_root, 0, 0, pos);

    final content = InteractiveViewer(
      transformationController: _tc,
      minScale: 0.2, maxScale: 3,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(400),
      child: SizedBox(
        width: 1600, height: 1200,
        child: CustomPaint(
          painter: _MindMapPainter(root: _root, positions: pos, collapsed: _collapsed, linkColor: linkClr, offset: const Offset(120, 500)),
          child: Stack(children: _buildNodeButtons(pos)),
        ),
      ),
    );

    return GestureDetector(
      onTap: () { if (!_expanded) setState(() => _expanded = true); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(vertical: _expanded ? 0 : 6),
        width: _expanded ? MediaQuery.of(context).size.width : math.min(MediaQuery.of(context).size.width * 0.9, 520),
        height: _expanded ? MediaQuery.of(context).size.height : math.min(MediaQuery.of(context).size.height * 0.85, 520),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(_expanded ? 0 : 24),
          boxShadow: _expanded ? null : [BoxShadow(color: Colors.black.withOpacity(s.isDark ? 0.4 : 0.08), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(child: content),
          if (_expanded)
            Positioned(
              top: 14, right: 14,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  List<Widget> _buildNodeButtons(Map<String, Offset> pos) {
    final buttons = <Widget>[];
    void walk(_MindNode n) {
      final p = pos[n.id];
      if (p != null) {
        final w = math.max(70.0, n.label.length * 7.0 + 24);
        buttons.add(Positioned(
          left: p.dx + 120 - w / 2, top: p.dy + 500 - 20,
          width: w, height: 40,
          child: GestureDetector(
            onTap: () {
              if (n.children.isNotEmpty) {
                setState(() {
                  if (_collapsed.contains(n.id)) _collapsed.remove(n.id); else _collapsed.add(n.id);
                });
              }
            },
            child: Container(
              decoration: BoxDecoration(color: n.color, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Text(n.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ),
          ),
        ));
      }
      if (!_collapsed.contains(n.id)) { for (final c in n.children) walk(c); }
    }
    walk(_root);
    return buttons;
  }
}

class _MindMapPainter extends CustomPainter {
  final _MindNode root;
  final Map<String, Offset> positions;
  final Set<String> collapsed;
  final Color linkColor;
  final Offset offset;
  _MindMapPainter({required this.root, required this.positions, required this.collapsed, required this.linkColor, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = linkColor..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    void walk(_MindNode n) {
      if (!collapsed.contains(n.id)) {
        final fr = positions[n.id];
        for (final c in n.children) {
          final to = positions[c.id];
          if (fr != null && to != null) {
            final f = fr + offset, t = to + offset;
            final dx = t.dx - f.dx;
            final path = Path()
              ..moveTo(f.dx, f.dy)
              ..cubicTo(f.dx + dx * 0.5, f.dy, t.dx - dx * 0.5, t.dy, t.dx, t.dy);
            canvas.drawPath(path, paint);
          }
          walk(c);
        }
      }
    }
    walk(root);
  }

  @override
  bool shouldRepaint(covariant _MindMapPainter old) => true;
}

// ══════════════════════════════════════════════════════════════
// MATH GRAPH
// ══════════════════════════════════════════════════════════════

class AiMathGraphWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMathGraphWidget({super.key, required this.json, required this.s});
  @override State<AiMathGraphWidget> createState() => _AiMathGraphWidgetState();
}

class _AiMathGraphWidgetState extends State<AiMathGraphWidget> {
  late double xMin, xMax, yMin, yMax;
  me.Expression? _expr;
  final me.ContextModel _cm = me.ContextModel();
  final me.Variable _xVar = me.Variable('x');

  Offset? _panStart;
  double _panXMin = 0, _panXMax = 0, _panYMin = 0, _panYMax = 0;

  @override
  void initState() {
    super.initState();
    xMin = (widget.json['xMin'] as num?)?.toDouble() ?? -10;
    xMax = (widget.json['xMax'] as num?)?.toDouble() ?? 10;
    yMin = (widget.json['yMin'] as num?)?.toDouble() ?? -5;
    yMax = (widget.json['yMax'] as num?)?.toDouble() ?? 5;
    final exprStr = (widget.json['expression'] ?? widget.json['expr'] ?? 'sin(x)').toString();
    try {
      _expr = me.Parser().parse(exprStr);
    } catch (_) { _expr = null; }
    if (widget.json['yMin'] == null && widget.json['yMax'] == null) _autoY();
  }

  double? _eval(double x) {
    if (_expr == null) return null;
    try {
      _cm.bindVariable(_xVar, me.Number(x));
      final v = _expr!.evaluate(me.EvaluationType.REAL, _cm);
      if (v is num && v.isFinite) return v.toDouble();
    } catch (_) {}
    return null;
  }

  void _autoY() {
    double lo = double.infinity, hi = -double.infinity;
    for (int i = 0; i <= 400; i++) {
      final x = xMin + (i / 400) * (xMax - xMin);
      final y = _eval(x);
      if (y != null) { lo = math.min(lo, y); hi = math.max(hi, y); }
    }
    if (lo.isFinite && hi.isFinite) {
      final pad = math.max(1.0, (hi - lo) * 0.15);
      yMin = lo - pad; yMax = hi + pad;
      if ((yMax - yMin).abs() < 1e-6) { yMin -= 1; yMax += 1; }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Container(
      constraints: const BoxConstraints(maxWidth: 960),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: AspectRatio(
        aspectRatio: 960 / 540,
        child: GestureDetector(
          onScaleStart: (d) {
            _panStart = d.focalPoint;
            _panXMin = xMin; _panXMax = xMax; _panYMin = yMin; _panYMax = yMax;
          },
          onScaleUpdate: (d) {
            setState(() {
              if (d.scale != 1.0) {
                final cx = (_panXMin + _panXMax) / 2, cy = (_panYMin + _panYMax) / 2;
                final nxr = (_panXMax - _panXMin) / d.scale, nyr = (_panYMax - _panYMin) / d.scale;
                xMin = cx - nxr / 2; xMax = cx + nxr / 2; yMin = cy - nyr / 2; yMax = cy + nyr / 2;
              } else if (_panStart != null) {
                final box = context.findRenderObject() as RenderBox;
                final w = box.size.width, h = box.size.height;
                final dx = d.focalPoint.dx - _panStart!.dx, dy = d.focalPoint.dy - _panStart!.dy;
                final sx = (_panXMax - _panXMin) / w, sy = (_panYMax - _panYMin) / h;
                xMin = _panXMin - dx * sx; xMax = _panXMax - dx * sx;
                yMin = _panYMin + dy * sy; yMax = _panYMax + dy * sy;
              }
            });
          },
          child: CustomPaint(
            painter: _MathGraphPainter(xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax, eval: _eval, isDark: s.isDark),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _MathGraphPainter extends CustomPainter {
  final double xMin, xMax, yMin, yMax;
  final double? Function(double) eval;
  final bool isDark;
  _MathGraphPainter({required this.xMin, required this.xMax, required this.yMin, required this.yMax, required this.eval, required this.isDark});

  double _mapX(double x, Size size) => (x - xMin) / (xMax - xMin) * size.width;
  double _mapY(double y, Size size) => size.height - (y - yMin) / (yMax - yMin) * size.height;

  @override
  void paint(Canvas canvas, Size size) {
    final gridColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final axisColor = isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555);
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.8;
    final axisPaint = Paint()..color = axisColor..strokeWidth = 2;

    double xRange = xMax - xMin, yRange = yMax - yMin;
    double xStep = math.pow(10, (math.log(xRange.abs() / 6) / math.ln10).floor()).toDouble();
    if (xRange / xStep > 12) xStep *= 2;
    if (xRange / xStep < 4) xStep /= 2;
    double yStep = math.pow(10, (math.log(yRange.abs() / 6) / math.ln10).floor()).toDouble();
    if (yRange / yStep > 12) yStep *= 2;
    if (yRange / yStep < 4) yStep /= 2;

    final xZero = _mapX(0, size), yZero = _mapY(0, size);

    for (double x = (xMin / xStep).ceil() * xStep; x <= xMax; x += xStep) {
      final px = _mapX(x, size);
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), gridPaint);
    }
    for (double y = (yMin / yStep).ceil() * yStep; y <= yMax; y += yStep) {
      final py = _mapY(y, size);
      canvas.drawLine(Offset(0, py), Offset(size.width, py), gridPaint);
    }
    if (0 >= xMin && 0 <= xMax) canvas.drawLine(Offset(xZero, 0), Offset(xZero, size.height), axisPaint);
    if (0 >= yMin && 0 <= yMax) canvas.drawLine(Offset(0, yZero), Offset(size.width, yZero), axisPaint);

    final path = Path();
    bool started = false;
    final points = <Offset>[];
    for (int i = 0; i <= 500; i++) {
      final x = xMin + (i / 500) * (xMax - xMin);
      final y = eval(x);
      if (y != null && y.isFinite) {
        final px = _mapX(x, size), py = _mapY(y, size);
        if (!started) { path.moveTo(px, py); started = true; } else { path.lineTo(px, py); }
        points.add(Offset(px, py));
      } else {
        started = false;
      }
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF6CB6FF)..style = PaintingStyle.stroke..strokeWidth = 2.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    if (points.isNotEmpty) {
      final stepIdx = math.max(1, (points.length / 8).floor());
      for (int i = 0; i < points.length; i += stepIdx) {
        canvas.drawCircle(points[i], 3.5, Paint()..color = const Color(0xFFE74C3C));
        canvas.drawCircle(points[i], 3.5, Paint()..color = isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F4)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MathGraphPainter old) =>
      old.xMin != xMin || old.xMax != xMax || old.yMin != yMin || old.yMax != yMax;
}

// ══════════════════════════════════════════════════════════════
// MAP
// ══════════════════════════════════════════════════════════════

class AiMapWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMapWidget({super.key, required this.json, required this.s});
  @override State<AiMapWidget> createState() => _AiMapWidgetState();
}

class _AiMapWidgetState extends State<AiMapWidget> {
  bool _expanded = false;
  final MapController _mc = MapController();

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final lat = (widget.json['lat'] ?? widget.json['latitude'] ?? 0).toDouble();
    final lng = (widget.json['lng'] ?? widget.json['longitude'] ?? widget.json['lon'] ?? 0).toDouble();
    final zoom = (widget.json['zoom'] as num?)?.toDouble() ?? 12;
    final showMarker = widget.json['marker'] != false;
    final center = ll.LatLng(lat, lng);

    final content = FlutterMap(
      mapController: _mc,
      options: MapOptions(initialCenter: center, initialZoom: zoom, interactionOptions: InteractionOptions(flags: _expanded ? InteractiveFlag.all : InteractiveFlag.none)),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.craftlab.app'),
        if (showMarker)
          MarkerLayer(markers: [
            Marker(point: center, width: 40, height: 40, child: Icon(Icons.location_on, color: s.primary, size: 36)),
          ]),
      ],
    );

    return GestureDetector(
      onTap: () { if (!_expanded) setState(() => _expanded = true); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(vertical: _expanded ? 0 : 6),
        width: _expanded ? MediaQuery.of(context).size.width : math.min(MediaQuery.of(context).size.width * 0.9, 420),
        height: _expanded ? MediaQuery.of(context).size.height : math.min(MediaQuery.of(context).size.width * 0.9, 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_expanded ? 0 : 30),
          boxShadow: _expanded ? null : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(child: content),
          if (_expanded)
            Positioned(
              top: 14, right: 14,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                  child: const Icon(Icons.close, color: Colors.black87, size: 18),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LOADER PEQUENO — usado no pill "A criar widget..." em vez do
// BlinkingGridLoader inteiro (item 4/5: loader reduzido).
// ══════════════════════════════════════════════════════════════

class AiSmallDotsLoader extends StatefulWidget {
  final Color color;
  const AiSmallDotsLoader({super.key, required this.color});
  @override State<AiSmallDotsLoader> createState() => _AiSmallDotsLoaderState();
}

class _AiSmallDotsLoaderState extends State<AiSmallDotsLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.15;
          var t = (_c.value - delay) % 1.0;
          if (t < 0) t += 1.0;
          final op = t < 0.5 ? (0.3 + t) : (1.3 - t);
          return Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
            child: Opacity(
              opacity: op.clamp(0.3, 1.0),
              child: Container(width: 5, height: 5, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
            ),
          );
        }),
      ),
    );
  }
}