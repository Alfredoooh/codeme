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
//
// widget_table foi REMOVIDO deste ficheiro — a tabela usada em toda
// a app é agora _AiTable (richtext.dart), reaproveitada também para
// blocos ```widget_table```. Ver buildAiWidget() abaixo.
//
// ── ATUALIZAÇÃO (Card universal de widget) ──────────────────────
// Todos os widgets "container" (mindmap, market, calendar, timer)
// passam a ter um rodapé de ações fixo, com botões específicos por
// tipo, usando o novo _WidgetActionBar. O card de documento (doc/
// sheet/slide) NÃO vive aqui — vive em aitab.dart (_DocumentWidgetCard)
// porque precisa de LocalCanvasItem, que é definido em aitab.dart.
// widget_code foi REMOVIDO deste ficheiro: agora os blocos de código
// markdown são renderizados exclusivamente pelo AiCodeBlock em
// richtext.dart, que já tem o botão de preview que navega para
// AiCodePreviewScreen (também em richtext.dart).
//
// CORREÇÕES DE COMPILAÇÃO (build real falhou, confirmado no log):
// 1) '$' sem escape dentro de strings com aspas simples ('sh': '$')
//    é interpretado por Dart como início de interpolação — corrigido
//    para '\$' nas entradas 'sh' e 'bash' de _fallbackGlyph.
// 2) 'Object' aparecia duas vezes na mesma literal `const Set<String>
//    _types` — Dart avalia Set const em tempo de compilação e
//    rejeita elementos duplicados; removida a segunda ocorrência.
// 3) Função _parseColor em falta — adicionada como função top-level.
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
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'colors.dart';
import 'widgets.dart';
import 'richtext.dart' show buildAiTableFromWidgetJson;

// ══════════════════════════════════════════════════════════════
// FUNÇÃO AUXILIAR _parseColor (adicionada para corrigir build)
// ══════════════════════════════════════════════════════════════
Color? _parseColor(dynamic raw) {
  if (raw == null) return null;
  if (raw is Color) return raw;
  if (raw is int) return Color(raw);

  if (raw is String) {
    var hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // adiciona opacidade total
    }
    if (hex.length == 8) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(value);
    }
  }

  return null;
}

// ══════════════════════════════════════════════════════════════
// IDS DE WIDGET SUPORTADOS
// ══════════════════════════════════════════════════════════════

const Set<String> kAiWidgetIds = {
  'widget_table', 'widget_bar', 'widget_pie',
  'widget_market', 'widget_calendar', 'widget_timer',
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
  return opens > 0 && closesTotal % 2 == 1;
}

// ══════════════════════════════════════════════════════════════
// DISPATCHER
// ══════════════════════════════════════════════════════════════

Widget buildAiWidget(AiWidgetBlock block, AppColorScheme s) {
  switch (block.id) {
    case 'widget_table':    return buildAiTableFromWidgetJson(block.json, s);
    case 'widget_bar':      return AiChartWidget(json: block.json, s: s, defaultType: 'bar');
    case 'widget_pie':      return AiChartWidget(json: block.json, s: s, defaultType: 'pie');
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
// WIDGET ACTION BAR
// ══════════════════════════════════════════════════════════════

class _WidgetAction {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _WidgetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
}

class _WidgetActionBar extends StatelessWidget {
  final AppColorScheme s;
  final List<_WidgetAction> actions;
  const _WidgetActionBar({required this.s, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final border = s.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5EA);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 34, color: border),
            Expanded(child: _WidgetActionButton(s: s, action: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _WidgetActionButton extends StatefulWidget {
  final AppColorScheme s;
  final _WidgetAction action;
  const _WidgetActionButton({required this.s, required this.action});
  @override
  State<_WidgetActionButton> createState() => _WidgetActionButtonState();
}

class _WidgetActionButtonState extends State<_WidgetActionButton> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final a = widget.action;
    final color = a.primary ? s.primary : s.onSurfaceVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       a.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _h ? s.hover : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(a.icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                a.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// UNIFIED CHART WIDGET
// ══════════════════════════════════════════════════════════════

class AiChartWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  final String? defaultType; // 'bar' | 'line' | 'area' | 'pie'
  const AiChartWidget({super.key, required this.json, required this.s, this.defaultType});
  @override
  State<AiChartWidget> createState() => _AiChartWidgetState();
}

class _ChartDataItem {
  String label;
  double value;
  Color color;
  _ChartDataItem(this.label, this.value, this.color);
}

class _AiChartWidgetState extends State<AiChartWidget>
    with SingleTickerProviderStateMixin {
  static const _palette = [
    Color(0xFF2E8BC9), Color(0xFFE05E5E), Color(0xFF4EC994),
    Color(0xFFF0A500), Color(0xFFC77DFF), Color(0xFF5ECBE0),
    Color(0xFFE0785E), Color(0xFF8ECC4E),
  ];

  late List<_ChartDataItem> _data;
  late String _title;
  late String _chartType;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _parseInitialData();
    _initChartType();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _parseInitialData() {
    final raw = widget.json['data'] ?? widget.json['slices'] ?? widget.json['bars'];
    if (raw is List) {
      _data = raw.asMap().entries.map((e) {
        final d = e.value as Map;
        return _ChartDataItem(
          (d['label'] ?? '?').toString(),
          (d['value'] is num) ? (d['value'] as num).toDouble() : double.tryParse(d['value'].toString()) ?? 0,
          _parseColor(d['color']) ?? _palette[e.key % _palette.length],
        );
      }).toList();
    } else {
      _data = const [];
    }
    _title = (widget.json['title'] ?? 'Dados').toString();
  }

  void _initChartType() {
    if (widget.defaultType != null) {
      _chartType = widget.defaultType!;
      return;
    }
    final t = (widget.json['type'] ?? '').toString().toLowerCase();
    if (['bar', 'line', 'area', 'pie'].contains(t)) {
      _chartType = t;
    } else {
      _chartType = 'bar';
    }
  }

  Color _cardBg()        => widget.s.isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color _previewBg()     => widget.s.isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5);
  Color _titleColor()    => widget.s.isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1A1A1A);
  Color _legendText()    => widget.s.isDark ? const Color(0xFF999999) : const Color(0xFF666666);
  Color _actionsBg()     => widget.s.isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0);
  Color _primary()       => const Color(0xFF2E8BC9);

  Future<void> _openOptions() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChartOptionsSheet(
        initialType: _chartType,
        initialTitle: _title,
        initialData: List<_ChartDataItem>.from(_data.map((d) => _ChartDataItem(d.label, d.value, d.color))),
        isDark: widget.s.isDark,
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _chartType = result['type'] as String;
        _title = result['title'] as String;
        _data = (result['data'] as List).cast<_ChartDataItem>();
        _animController.forward(from: 0);
      });
    }
  }

  void _copyData() {
    final lines = _data.map((d) => '${d.label}: ${d.value}').join('\n');
    Clipboard.setData(ClipboardData(text: '$_title\n$lines'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados copiados!')),
    );
  }

  void _downloadChart() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download em breve')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg(),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.s.isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: _previewBg(),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _titleColor(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (_, __) => CustomPaint(
                        painter: _UnifiedChartPainter(
                          data: _data,
                          chartType: _chartType,
                          isDark: widget.s.isDark,
                          progress: Curves.easeOutCubic.transform(_animController.value),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.start,
                      children: _data.asMap().entries.map((e) {
                        final item = e.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: _legendText(),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _actionsBg(),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openOptions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _primary(),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon('sliders.svg', size: 14, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(
                            'Opções',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _CircularActionButton(
                  icon: 'copy.svg',
                  tooltip: 'Copiar',
                  onTap: _copyData,
                  primary: _primary(),
                ),
                const SizedBox(width: 6),
                _CircularActionButton(
                  icon: 'download.svg',
                  tooltip: 'Download',
                  onTap: _downloadChart,
                  primary: _primary(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularActionButton extends StatelessWidget {
  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color primary;
  const _CircularActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
          ),
          child: AppIcon(icon, size: 13, color: Colors.white),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// MODAL DE OPÇÕES DO GRÁFICO
// ────────────────────────────────────────────────────────────

class _ChartOptionsSheet extends StatefulWidget {
  final String initialType;
  final String initialTitle;
  final List<_ChartDataItem> initialData;
  final bool isDark;
  const _ChartOptionsSheet({
    required this.initialType,
    required this.initialTitle,
    required this.initialData,
    required this.isDark,
  });

  @override
  State<_ChartOptionsSheet> createState() => _ChartOptionsSheetState();
}

class _ChartOptionsSheetState extends State<_ChartOptionsSheet> {
  late String _draftType;
  late TextEditingController _titleController;
  late List<_ChartDataItem> _draftData;
  late List<TextEditingController> _labelControllers;
  late List<TextEditingController> _valueControllers;

  final List<({String key, String icon})> _chartTypes = [
    (key: 'bar', icon: 'chart_bar.svg'),
    (key: 'line', icon: 'chart_line.svg'),
    (key: 'area', icon: 'chart_area.svg'),
    (key: 'pie', icon: 'chart_pie.svg'),
  ];

  static const _colorPalette = [
    Color(0xFF2E8BC9), Color(0xFFE05E5E), Color(0xFF4EC994),
    Color(0xFFF0A500), Color(0xFFC77DFF), Color(0xFF5ECBE0),
    Color(0xFFE0785E), Color(0xFF8ECC4E),
  ];

  @override
  void initState() {
    super.initState();
    _draftType = widget.initialType;
    _titleController = TextEditingController(text: widget.initialTitle);
    _draftData = List<_ChartDataItem>.from(
        widget.initialData.map((d) => _ChartDataItem(d.label, d.value, d.color)));
    _labelControllers = _draftData.map((d) => TextEditingController(text: d.label)).toList();
    _valueControllers = _draftData.map((d) => TextEditingController(text: d.value.toString())).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _labelControllers) c.dispose();
    for (final c in _valueControllers) c.dispose();
    super.dispose();
  }

  Color _inputBg()      => widget.isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5);
  Color _inputBorder()  => widget.isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD);
  Color _inputText()    => widget.isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A);
  Color _label()        => widget.isDark ? const Color(0xFF888888) : const Color(0xFF777777);
  Color _chipInactiveBg() => widget.isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE);
  Color _chipInactiveBorder() => widget.isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD);
  Color _chipInactiveText() => widget.isDark ? const Color(0xFF888888) : const Color(0xFF666666);
  Color _sheetBg()      => widget.isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color _primary()      => const Color(0xFF2E8BC9);

  Future<void> _pickColor(int index) async {
    final selected = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _sheetBg(),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _label(),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Escolher cor', style: TextStyle(color: _inputText(), fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorPalette.map((c) => GestureDetector(
                onTap: () => Navigator.pop(ctx, c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _draftData[index].color = selected;
      });
    }
  }

  void _addRow() {
    setState(() {
      final newItem = _ChartDataItem('Novo', 10, _colorPalette[_draftData.length % _colorPalette.length]);
      _draftData.add(newItem);
      _labelControllers.add(TextEditingController(text: 'Novo'));
      _valueControllers.add(TextEditingController(text: '10'));
    });
  }

  void _removeRow(int index) {
    setState(() {
      _draftData.removeAt(index);
      _labelControllers[index].dispose();
      _valueControllers[index].dispose();
      _labelControllers.removeAt(index);
      _valueControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: BoxDecoration(
          color: _sheetBg(),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _label(),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Opções do gráfico',
                style: TextStyle(color: _inputText(), fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Text('Tipo de gráfico',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _label(), letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Row(
              children: _chartTypes.map((t) {
                final active = _draftType == t.key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _draftType = t.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active ? _primary() : _chipInactiveBg(),
                        border: Border.all(color: active ? _primary() : _chipInactiveBorder()),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: AppIcon(t.icon, size: 17, color: active ? Colors.white : _chipInactiveText()),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text('Título',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _label(), letterSpacing: 0.4)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: TextStyle(color: _inputText(), fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: _inputBg(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _inputBorder()),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _inputBorder()),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primary()),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Valores',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _label(), letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: _draftData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _pickColor(index),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: item.color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _labelControllers[index],
                              onChanged: (v) => item.label = v,
                              style: TextStyle(color: _inputText(), fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _inputBg(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: _inputBorder()),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: _inputBorder()),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: _primary()),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _valueControllers[index],
                              onChanged: (v) => item.value = double.tryParse(v) ?? 0,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: TextStyle(color: _inputText(), fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _inputBg(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: _inputBorder()),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: _inputBorder()),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: _primary()),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeRow(index),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _chipInactiveBg(),
                              ),
                              child: AppIcon('close.svg', size: 12, color: _chipInactiveText()),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _addRow,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: _chipInactiveBorder(), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('add.svg', size: 12, color: _label()),
                    const SizedBox(width: 6),
                    Text('Adicionar valor',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _label())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _chipInactiveBg(),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _chipInactiveBorder()),
                      ),
                      alignment: Alignment.center,
                      child: Text('Cancelar',
                          style: TextStyle(color: _chipInactiveText(), fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context, {
                        'type': _draftType,
                        'title': _titleController.text.trim().isEmpty ? 'Dados' : _titleController.text.trim(),
                        'data': _draftData,
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _primary(),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text('Aplicar',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// PAINTER UNIFICADO
// ────────────────────────────────────────────────────────────

class _UnifiedChartPainter extends CustomPainter {
  final List<_ChartDataItem> data;
  final String chartType; // 'bar' | 'line' | 'area' | 'pie'
  final bool isDark;
  final double progress;

  _UnifiedChartPainter({
    required this.data,
    required this.chartType,
    required this.isDark,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    switch (chartType) {
      case 'bar':
        _drawBar(canvas, size);
        break;
      case 'line':
        _drawLine(canvas, size, filled: false);
        break;
      case 'area':
        _drawLine(canvas, size, filled: true);
        break;
      case 'pie':
        _drawPie(canvas, size);
        break;
    }
  }

  void _drawBar(Canvas canvas, Size size) {
    const padBottom = 22.0, padTop = 10.0, padSide = 6.0;
    final maxVal = data.map((d) => d.value).reduce(math.max);
    final innerW = size.width - padSide * 2;
    final innerH = size.height - padBottom - padTop;
    final gap = 10.0;
    final barW = (innerW - gap * (data.length - 1)) / data.length;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final color = d.color;
      final barH = (d.value / maxVal) * innerH * progress;
      final x = padSide + i * (barW + gap);
      final y = size.height - padBottom - barH;
      final r = math.min(6.0, barW / 2);

      final paint = Paint()..color = color;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barW, barH),
        topLeft: Radius.circular(r),
        topRight: Radius.circular(r),
      );
      canvas.drawRRect(rect, paint);

      final tp = TextPainter(
        text: TextSpan(
          text: d.label,
          style: TextStyle(color: isDark ? const Color(0xFF777777) : const Color(0xFF888888), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, size.height - 7));
    }
  }

  void _drawLine(Canvas canvas, Size size, {required bool filled}) {
    const padBottom = 22.0, padTop = 14.0, padSide = 10.0;
    final maxVal = data.map((d) => d.value).reduce(math.max);
    final minVal = math.min(0.0, data.map((d) => d.value).reduce(math.min));
    final innerW = size.width - padSide * 2;
    final innerH = size.height - padBottom - padTop;
    final stepX = data.length > 1 ? innerW / (data.length - 1) : 0;

    Offset ptAt(int i) {
      final d = data[i];
      final norm = (d.value - minVal) / (maxVal - minVal).abs().clamp(0.0001, double.infinity);
      final x = padSide + stepX * i;
      final yFull = padTop + innerH - norm * innerH;
      final yBase = padTop + innerH;
      final y = yBase - (yBase - yFull) * progress;
      return Offset(x, y);
    }

    final linePaint = Paint()
      ..color = data.first.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    if (filled) {
      final fillPath = Path()..moveTo(padSide, padTop + innerH);
      for (int i = 0; i < data.length; i++) {
        fillPath.lineTo(ptAt(i).dx, ptAt(i).dy);
      }
      fillPath.lineTo(padSide + innerW, padTop + innerH);
      fillPath.close();
      final gradient = ui.Gradient.linear(
        Offset(0, padTop),
        Offset(0, padTop + innerH),
        [data.first.color.withOpacity(0.33), data.first.color.withOpacity(0.05)],
      );
      canvas.drawPath(fillPath, Paint()..shader = gradient);
    }

    final linePath = Path();
    for (int i = 0; i < data.length; i++) {
      final p = ptAt(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(linePath, linePaint);

    for (int i = 0; i < data.length; i++) {
      final p = ptAt(i);
      canvas.drawCircle(p, 4, Paint()..color = data.first.color);
      canvas.drawCircle(p, 4, Paint()..color = isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5)..style = PaintingStyle.stroke..strokeWidth = 2);
      final tp = TextPainter(
        text: TextSpan(
          text: data[i].label,
          style: TextStyle(color: isDark ? const Color(0xFF777777) : const Color(0xFF888888), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, size.height - 7));
    }
  }

  void _drawPie(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 4);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final total = data.fold<double>(0, (sum, d) => sum + math.max(d.value, 0));
    final safeTotal = total.clamp(0.0001, double.infinity);

    var startAngle = -math.pi / 2;
    for (final d in data) {
      final slice = (math.max(d.value, 0) / safeTotal) * 2 * math.pi * progress;
      final endAngle = startAngle + slice;
      final paint = Paint()..color = d.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        slice,
        true,
        paint,
      );
      startAngle = endAngle;
    }

    canvas.drawCircle(center, radius * 0.55, Paint()..color = isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5));
    final tp = TextPainter(
      text: TextSpan(
        text: total.round().toString(),
        style: TextStyle(
          color: isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1A1A1A),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _UnifiedChartPainter old) {
    return old.data != data || old.chartType != chartType || old.progress != progress;
  }
}

// ══════════════════════════════════════════════════════════════
// MARKET WIDGET (design atualizado)
// ══════════════════════════════════════════════════════════════

class AiMarketWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMarketWidget({super.key, required this.json, required this.s});
  @override State<AiMarketWidget> createState() => _AiMarketWidgetState();
}

class _MarketPair {
  final String key;
  final String label;
  final String sub;
  final String badge;
  final double basePrice;
  final double volatility;
  const _MarketPair({
    required this.key,
    required this.label,
    required this.sub,
    required this.badge,
    required this.basePrice,
    required this.volatility,
  });
}

class _MarketDataPoint {
  final double t;
  final double v;
  const _MarketDataPoint(this.t, this.v);
}

class _AiMarketWidgetState extends State<AiMarketWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _progress = 0.0;

  static const List<_MarketPair> _pairs = [
    _MarketPair(key: 'BTCUSD', label: 'BTC/USD', sub: 'Bitcoin', basePrice: 64200, volatility: 0.018, badge: 'cripto'),
    _MarketPair(key: 'ETHUSD', label: 'ETH/USD', sub: 'Ethereum', basePrice: 3180, volatility: 0.022, badge: 'cripto'),
    _MarketPair(key: 'EURUSD', label: 'EUR/USD', sub: 'Euro / Dólar', basePrice: 1.087, volatility: 0.004, badge: 'forex'),
    _MarketPair(key: 'GBPUSD', label: 'GBP/USD', sub: 'Libra / Dólar', basePrice: 1.271, volatility: 0.005, badge: 'forex'),
    _MarketPair(key: 'USDJPY', label: 'USD/JPY', sub: 'Dólar / Iene', basePrice: 156.4, volatility: 0.006, badge: 'forex'),
    _MarketPair(key: 'XAUUSD', label: 'XAU/USD', sub: 'Ouro', basePrice: 2340, volatility: 0.009, badge: 'metal'),
  ];

  static const List<({String key, String label, int points})> _timeframes = [
    (key: '1D', label: '1D', points: 24),
    (key: '1W', label: '1W', points: 7),
    (key: '1M', label: '1M', points: 30),
    (key: '1Y', label: '1Y', points: 12),
  ];

  late String _currentPairKey;
  late String _currentTf;
  final Map<String, List<_MarketDataPoint>> _seriesCache = {};

  _MarketPair get _currentPair => _pairs.firstWhere((p) => p.key == _currentPairKey);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
        setState(() => _progress = Curves.easeOutCubic.transform(_animController.value));
      });
    _currentTf = '1D';
    _currentPairKey = (widget.json['symbol'] ?? 'BTCUSD').toString().toUpperCase();
    if (!_pairs.any((p) => p.key == _currentPairKey)) {
      _currentPairKey = 'BTCUSD';
    }
    _animController.forward(from: 0);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<_MarketDataPoint> _getSeries(String pairKey, String tfKey) {
    final cacheKey = '${pairKey}_$tfKey';
    if (_seriesCache.containsKey(cacheKey)) return _seriesCache[cacheKey]!;

    final pair = _pairs.firstWhere((p) => p.key == pairKey);
    final tf = _timeframes.firstWhere((t) => t.key == tfKey);
    final rand = math.Random(_hashKey(cacheKey));

    final points = <_MarketDataPoint>[];
    double price = pair.basePrice * (0.92 + rand.nextDouble() * 0.1);
    final now = DateTime.now().millisecondsSinceEpoch;
    final stepMs = tf.key == '1D' ? 60 * 60 * 1000 : 
                    tf.key == '1W' ? 24 * 60 * 60 * 1000 :
                    tf.key == '1M' ? 24 * 60 * 60 * 1000 :
                    30 * 24 * 60 * 60 * 1000;

    for (int i = tf.points; i >= 0; i--) {
      price *= (1 + (rand.nextDouble() - 0.48) * pair.volatility);
      points.add(_MarketDataPoint((now - i * stepMs).toDouble(), price));
    }
    _seriesCache[cacheKey] = points;
    return points;
  }

  int _hashKey(String str) {
    int h = 0;
    for (final code in str.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return h == 0 ? 1 : h;
  }

  String _formatPrice(double v, _MarketPair pair) {
    if (pair.badge == 'forex') return v.toStringAsFixed(4);
    if (v >= 1000) {
      final formatted = v.round().toString();
      return '\$$formatted';
    }
    return '\$${v.toStringAsFixed(2)}';
  }

  void _changePair(String key) {
    setState(() {
      _currentPairKey = key;
      _animController.forward(from: 0);
    });
  }

  void _changeTimeframe(String tf) {
    setState(() {
      _currentTf = tf;
      _animController.forward(from: 0);
    });
  }

  Future<void> _openPairSelector() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Escolher par',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _pairs.map((pair) {
                  final active = pair.key == _currentPairKey;
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, pair.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF1C3A52) : const Color(0xFF232323),
                        border: Border.all(color: active ? const Color(0xFF2E8BC9) : Colors.transparent),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pair.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(pair.sub, style: const TextStyle(color: Color(0xFF777777), fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && selected != _currentPairKey) {
      _changePair(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pair = _currentPair;
    final series = _getSeries(pair.key, _currentTf);
    final first = series.first.v;
    final last = series.last.v;
    final change = ((last - first) / first) * 100;
    final isUp = last >= first;
    final color = isUp ? const Color(0xFF4EC994) : const Color(0xFFE05E5E);

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              pair.label,
                              style: const TextStyle(
                                color: Color(0xFFE8E8E8),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF262626),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pair.badge,
                                style: const TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatPrice(last, pair),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              color: color,
                              size: 18,
                            ),
                            Text(
                              '${isUp ? '+' : ''}${change.toStringAsFixed(2)}% · $_currentTf',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: CustomPaint(
                        painter: _MarketChartPainter(
                          series: series,
                          progress: _progress,
                          isUp: isUp,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: _timeframes.map((tf) {
                        final active = tf.key == _currentTf;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _changeTimeframe(tf.key),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: active ? const Color(0xFF262626) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                tf.label,
                                style: TextStyle(
                                  color: active ? Colors.white : const Color(0xFF777777),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(50),
            ),
            child: GestureDetector(
              onTap: _openPairSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E8BC9),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.repeat, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Alterar moeda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketChartPainter extends CustomPainter {
  final List<_MarketDataPoint> series;
  final double progress;
  final bool isUp;
  _MarketChartPainter({
    required this.series,
    required this.progress,
    required this.isUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;

    final color = isUp ? const Color(0xFF4EC994) : const Color(0xFFE05E5E);
    final values = series.map((p) => p.v).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final pad = (maxV - minV) * 0.12;
    final maxY = maxV + pad;
    final minY = minV - pad;

    final innerW = size.width - 8;
    final innerH = size.height - 12;

    Offset ptAt(int i) {
      final norm = (values[i] - minY) / (maxY - minY);
      final x = 4 + (innerW * i) / (values.length - 1);
      final yFull = 6 + innerH - norm * innerH;
      final yBase = 6 + innerH;
      final y = yBase - (yBase - yFull) * progress;
      return Offset(x, y);
    }

    final fillPath = Path()..moveTo(4, 6 + innerH);
    for (int i = 0; i < values.length; i++) {
      final p = ptAt(i);
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(4 + innerW, 6 + innerH);
    fillPath.close();

    final gradient = ui.Gradient.linear(
      Offset(0, 6),
      Offset(0, 6 + innerH),
      [color.withOpacity(0.25), color.withOpacity(0.0)],
    );
    canvas.drawPath(fillPath, Paint()..shader = gradient);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    for (int i = 0; i < values.length; i++) {
      final p = ptAt(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(linePath, linePaint);

    final lastPt = ptAt(values.length - 1);
    canvas.drawCircle(lastPt, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter old) {
    return old.series != series || old.progress != progress || old.isUp != isUp;
  }
}

// ══════════════════════════════════════════════════════════════
// CALENDAR (mantido, sem alterações)
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

  Color _cardBg()          => widget.s.isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color _previewBg()       => widget.s.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
  Color _monthTextColor()  => widget.s.isDark ? Colors.white : Colors.black87;
  Color _navBtnBg()        => widget.s.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
  Color _navIconColor()    => widget.s.isDark ? const Color(0xFFAAAAAA) : Colors.black54;
  Color _weekdayColor()    => widget.s.isDark ? const Color(0xFF555555) : Colors.black45;
  Color _dayNumColor()     => widget.s.isDark ? const Color(0xFFCCCCCC) : Colors.black87;
  Color _otherMonthColor() => widget.s.isDark ? const Color(0xFF3A3A3A) : Colors.black26;
  Color _selectedBg()      => widget.s.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE);
  Color _actionsBg()       => widget.s.isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0);
  Color _accent()          => const Color(0xFF2E8BC9);

  void _openNewEventSheet() {
    final s = widget.s;
    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: s.floatingSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SheetGrabber(s: s)),
              Text('Novo evento · $_selectedKey',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: s.onSurface),
                decoration: InputDecoration(
                  hintText: 'Nome do evento',
                  hintStyle: TextStyle(color: s.onSurfaceVariant),
                  filled: true, fillColor: s.hover,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timeCtrl,
                style: TextStyle(color: s.onSurface),
                decoration: InputDecoration(
                  hintText: 'Hora (ex: 14:00)',
                  hintStyle: TextStyle(color: s.onSurfaceVariant),
                  filled: true, fillColor: s.hover,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    _events.putIfAbsent(_selectedKey, () => []).add((
                      name: nameCtrl.text.trim(),
                      time: timeCtrl.text.trim(),
                      color: const Color(0xFF6F5AF6),
                    ));
                  });
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('Adicionar', style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w600, fontSize: 14.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final y = _current.year, m = _current.month;
    final firstDay = DateTime(y, m, 1).weekday % 7; // 0 = Dom
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final daysInPrev = DateTime(y, m, 0).day;

    final cells = <Widget>[];
    for (int i = firstDay - 1; i >= 0; i--) {
      final day = daysInPrev - i;
      cells.add(_buildDayCell(
        label: day.toString(),
        isOtherMonth: true,
        isToday: false,
        isSelected: false,
        eventColors: const [],
        onTap: null,
      ));
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final key = _key(y, m, d);
      final isToday = DateTime(y, m, d) == DateTime(_today.year, _today.month, _today.day);
      final dayEvents = _events[key] ?? const [];
      cells.add(_buildDayCell(
        label: d.toString(),
        isOtherMonth: false,
        isToday: isToday,
        isSelected: key == _selectedKey,
        eventColors: dayEvents.map((e) => e.color).toList(),
        onTap: () => setState(() => _selectedKey = key),
      ));
    }
    final total = firstDay + daysInMonth;
    final rem = total % 7 == 0 ? 0 : 7 - total % 7;
    for (int d = 1; d <= rem; d++) {
      cells.add(_buildDayCell(
        label: d.toString(),
        isOtherMonth: true,
        isToday: false,
        isSelected: false,
        eventColors: const [],
        onTap: null,
      ));
    }

    final rows = <List<Widget>>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, math.min(i + 7, cells.length)));
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg(),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.s.isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: _previewBg(),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_months[m - 1]} $y',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _monthTextColor(),
                            letterSpacing: 0.2,
                          ),
                        ),
                        Row(
                          children: [
                            _buildNavButton(
                              icon: 'chevron_left.svg',
                              onTap: () => setState(() => _current = DateTime(_current.year, _current.month - 1, 1)),
                            ),
                            const SizedBox(width: 8),
                            _buildNavButton(
                              icon: 'chevron_right.svg',
                              onTap: () => setState(() => _current = DateTime(_current.year, _current.month + 1, 1)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: _weekdays.map((w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _weekdayColor(),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: rows.map((row) => Expanded(
                          child: Row(
                            children: row.map((cell) => Expanded(child: cell)).toList(),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _actionsBg(),
              borderRadius: BorderRadius.circular(50),
            ),
            child: GestureDetector(
              onTap: _openNewEventSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _accent(),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('add.svg', size: 14, color: Colors.white),
                    const SizedBox(width: 7),
                    Text(
                      'Novo evento',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({required String icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _navBtnBg(),
          shape: BoxShape.circle,
        ),
        child: AppIcon(icon, size: 12, color: _navIconColor()),
      ),
    );
  }

  Widget _buildDayCell({
    required String label,
    required bool isOtherMonth,
    required bool isToday,
    required bool isSelected,
    required List<Color> eventColors,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday
                  ? _accent()
                  : isSelected
                      ? _selectedBg()
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday || eventColors.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? Colors.white
                    : isOtherMonth
                        ? _otherMonthColor()
                        : _dayNumColor(),
              ),
            ),
          ),
          if (eventColors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                children: eventColors.take(2).map((c) => Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 1),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TIMER (mantido, sem alterações)
// ══════════════════════════════════════════════════════════════

class AiTimerWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiTimerWidget({super.key, required this.json, required this.s});
  @override State<AiTimerWidget> createState() => _AiTimerWidgetState();
}

class _AiTimerWidgetState extends State<AiTimerWidget> {
  late int _totalSeconds;
  late int _remaining;
  Timer? _timer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = (widget.json['seconds'] is num) ? (widget.json['seconds'] as num).toInt() : 300;
    _remaining = _totalSeconds;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining <= 0) {
          _timer?.cancel();
          setState(() => _running = false);
          return;
        }
        setState(() => _remaining--);
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() { _remaining = _totalSeconds; _running = false; });
  }

  String get _label => (widget.json['label'] ?? '').toString();

  String get _formatted {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final sec = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final progress = _totalSeconds > 0 ? (_remaining / _totalSeconds) : 0.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: s.isDark ? const Color(0xFF1B1B1B) : Colors.white,
        border: Border.all(color: s.isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(children: [
            if (_label.isNotEmpty) ...[
              Text(_label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: s.onSurfaceVariant)),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: 140, height: 140,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(
                  size: const Size(140, 140),
                  painter: _TimerRingPainter(progress: progress, isDark: s.isDark),
                ),
                Text(_formatted, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: s.onSurface, letterSpacing: -0.5)),
              ]),
            ),
          ]),
        ),
        _WidgetActionBar(s: s, actions: [
          _WidgetAction(
            icon: _running ? 'pause.svg' : 'play.svg',
            label: _running ? 'Pausar' : 'Iniciar',
            primary: true,
            onTap: _toggle,
          ),
          _WidgetAction(icon: 'refresh.svg', label: 'Reiniciar', onTap: _reset),
        ]),
      ]),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _TimerRingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final trackColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5EA);
    canvas.drawCircle(center, radius, Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = 8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = const Color(0xFF6F5AF6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════
// MIND MAP (mantido, sem alterações)
// ══════════════════════════════════════════════════════════════

class _MindNode {
  final String id;
  final String label;
  final Color color;
  final List<_MindNode> children;
  Offset position = Offset.zero;
  _MindNode({required this.id, required this.label, required this.color, required this.children});
}

class AiMindMapWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMindMapWidget({super.key, required this.json, required this.s});
  @override State<AiMindMapWidget> createState() => _AiMindMapWidgetState();
}

class _AiMindMapWidgetState extends State<AiMindMapWidget> {
  late _MindNode _root;
  double _scale = 1.0;
  Offset _pan = Offset.zero;

  _MindNode _buildNode(Map json) {
    final childrenRaw = (json['children'] as List?) ?? const [];
    return _MindNode(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      color: _parseColor(json['color']) ?? const Color(0xFF6F5AF6),
      children: childrenRaw.whereType<Map>().map((c) => _buildNode(c)).toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    final treeJson = widget.json['tree'] as Map? ?? {'id': 'root', 'label': 'Tema'};
    _root = _buildNode(treeJson);
    _layout(_root, 0, [0]);
  }

  void _layout(_MindNode node, int depth, List<double> yTracker) {
    const dx = 160.0, dy = 70.0;
    if (node.children.isEmpty) {
      node.position = Offset(depth * dx, yTracker[0]);
      yTracker[0] += dy;
      return;
    }
    final startY = yTracker[0];
    for (final child in node.children) {
      _layout(child, depth + 1, yTracker);
    }
    final endY = yTracker[0] - dy;
    node.position = Offset(depth * dx, (startY + endY) / 2);
  }

  void _collectEdges(_MindNode node, List<(Offset, Offset, Color)> edges) {
    for (final child in node.children) {
      edges.add((node.position, child.position, child.color));
      _collectEdges(child, edges);
    }
  }

  void _collectNodes(_MindNode node, List<_MindNode> out) {
    out.add(node);
    for (final c in node.children) _collectNodes(c, out);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final edges = <(Offset, Offset, Color)>[];
    _collectEdges(_root, edges);
    final nodes = <_MindNode>[];
    _collectNodes(_root, nodes);

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: s.isDark ? const Color(0xFF1B1B1B) : Colors.white,
        border: Border.all(color: s.isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: 320,
          child: GestureDetector(
            onScaleUpdate: (d) {
              setState(() {
                _scale = (_scale * d.scale).clamp(0.5, 2.5);
                _pan += d.focalPointDelta;
              });
            },
            child: ClipRect(
              child: Transform(
                transform: Matrix4.identity()
                  ..translate(_pan.dx + 40, _pan.dy + 140)
                  ..scale(_scale),
                child: CustomPaint(
                  painter: _MindMapPainter(edges: edges, isDark: s.isDark),
                  child: Stack(
                    children: nodes.map((n) => Positioned(
                          left: n.position.dx - 60,
                          top: n.position.dy - 16,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 120),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: n.color, borderRadius: BorderRadius.circular(8)),
                            child: Text(n.label,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        )).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        _WidgetActionBar(s: s, actions: [
          _WidgetAction(icon: 'zoom_in.svg', label: 'Ampliar', onTap: () => setState(() => _scale = (_scale + 0.2).clamp(0.5, 2.5))),
          _WidgetAction(icon: 'zoom_out.svg', label: 'Reduzir', onTap: () => setState(() => _scale = (_scale - 0.2).clamp(0.5, 2.5))),
          _WidgetAction(icon: 'refresh.svg', label: 'Repor', onTap: () => setState(() { _scale = 1.0; _pan = Offset.zero; })),
        ]),
      ]),
    );
  }
}

class _MindMapPainter extends CustomPainter {
  final List<(Offset, Offset, Color)> edges;
  final bool isDark;
  _MindMapPainter({required this.edges, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to, color) in edges) {
      final paint = Paint()..color = color.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2;
      final path = Path()..moveTo(from.dx, from.dy);
      final cx = (from.dx + to.dx) / 2;
      path.cubicTo(cx, from.dy, cx, to.dy, to.dx, to.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapPainter old) => true;
}

// ══════════════════════════════════════════════════════════════
// MATH GRAPH (novo — todos os tipos, sliders, animação, modal)
// ══════════════════════════════════════════════════════════════

class _ParamDef {
  final String key;
  final String symbol;
  final double min;
  final double max;
  final double step;
  final double defaultValue;
  const _ParamDef(this.key, this.symbol, this.min, this.max, this.step, this.defaultValue);
}

class _MathFunctionDef {
  final String key;
  final String label;
  final Color color;
  final List<_ParamDef> params;
  final String Function(Map<String, double> p) eq;
  final double Function(double x, Map<String, double> p) fn;
  final List<double>? Function(Map<String, double> p)? roots;
  final double? Function(Map<String, double> p)? asymptoteX;
  final double? Function(Map<String, double> p)? excludeAt;
  final double? Function(Map<String, double> p)? markerX;
  final double? Function(Map<String, double> p)? markerY;
  final bool isParametric;
  final double Function(double t, Map<String, double> p)? parametricX;
  final double Function(double t, Map<String, double> p)? parametricY;
  final List<double> domain;
  final List<double> range;

  const _MathFunctionDef({
    required this.key,
    required this.label,
    required this.color,
    required this.params,
    required this.eq,
    required this.fn,
    required this.domain,
    required this.range,
    this.roots,
    this.asymptoteX,
    this.excludeAt,
    this.markerX,
    this.markerY,
    this.isParametric = false,
    this.parametricX,
    this.parametricY,
  });
}

class AiMathGraphWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMathGraphWidget({super.key, required this.json, required this.s});
  @override State<AiMathGraphWidget> createState() => _AiMathGraphWidgetState();
}

class _AiMathGraphWidgetState extends State<AiMathGraphWidget> {
  late Map<String, _MathFunctionDef> _functionDefs;
  late String _currentType;
  late Map<String, double> _params;

  Timer? _animTimer;
  bool _animating = false;
  double _animDir = 1;

  @override
  void initState() {
    super.initState();
    _buildFunctionDefs();
    final typeFromJson = (widget.json['type'] ?? widget.json['function'] ?? '').toString().toLowerCase();
    _currentType = _functionDefs.containsKey(typeFromJson) ? typeFromJson : 'quadratic';
    _params = _defaultParams(_currentType);
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  void _buildFunctionDefs() {
    _functionDefs = {
      'linear': _MathFunctionDef(
        key: 'linear', label: 'Linear', color: const Color(0xFF2E8BC9),
        params: [
          const _ParamDef('m', 'm', -5, 5, 0.1, 1),
          const _ParamDef('b', 'b', -8, 8, 0.5, 0),
        ],
        eq: (p) => 'y = ${_fmt(p['m']!)}x${_signed(p['b']!)}',
        fn: (x, p) => p['m']! * x + p['b']!,
        roots: (p) => p['m'] == 0 ? const [] : [-p['b']! / p['m']!],
        domain: const [-10, 10], range: const [-9, 9],
      ),
      'quadratic': _MathFunctionDef(
        key: 'quadratic', label: 'Quadrática', color: const Color(0xFFE05E5E),
        params: [
          const _ParamDef('a', 'a', -3, 3, 0.1, 1),
          const _ParamDef('h', 'h', -5, 5, 0.5, 0),
          const _ParamDef('k', 'k', -6, 6, 0.5, -2),
        ],
        eq: (p) => 'y = ${_fmt(p['a']!)}${_sup('2')}${_signed(p['h']! * -1)}${_signed(p['k']!)}',
        fn: (x, p) => p['a']! * math.pow(x - p['h']!, 2).toDouble() + p['k']!,
        roots: (p) {
          if (p['a'] == 0) return const [];
          final disc = -p['k']! / p['a']!;
          if (disc < 0) return const [];
          final d = math.sqrt(disc);
          return disc == 0 ? [p['h']!] : [p['h']! - d, p['h']! + d];
        },
        domain: const [-10, 10], range: const [-9, 9],
      ),
      'cubic': _MathFunctionDef(
        key: 'cubic', label: 'Cúbica', color: const Color(0xFF8ECC4E),
        params: [
          const _ParamDef('a', 'a', -1.5, 1.5, 0.05, 0.3),
          const _ParamDef('h', 'h', -4, 4, 0.5, 0),
          const _ParamDef('k', 'k', -6, 6, 0.5, 0),
        ],
        eq: (p) => 'y = ${_fmt(p['a']!)}${_sup('3')}${_signed(p['h']! * -1)}${_signed(p['k']!)}',
        fn: (x, p) => p['a']! * math.pow(x - p['h']!, 3).toDouble() + p['k']!,
        roots: (p) {
          if (p['a'] == 0) return const [];
          final val = -p['k']! / p['a']!;
          final cbrt = val < 0 ? -math.pow(-val, 1 / 3).toDouble() : math.pow(val, 1 / 3).toDouble();
          return [p['h']! + cbrt];
        },
        domain: const [-10, 10], range: const [-9, 9],
      ),
      'exponential': _MathFunctionDef(
        key: 'exponential', label: 'Exponencial', color: const Color(0xFF2E8BC9),
        params: [
          const _ParamDef('b', 'b', 1.1, 4, 0.1, 2),
          const _ParamDef('x0', 'x', -3, 3, 0.1, 1.2),
        ],
        eq: (p) => 'y = ${_fmt(p['b']!)}ˣ',
        fn: (x, p) => math.pow(p['b']!, x).toDouble(),
        markerX: (p) => p['x0']!,
        markerY: (p) => math.pow(p['b']!, p['x0']!).toDouble(),
        domain: const [-8, 8], range: const [-2, 9],
      ),
      'logarithmic': _MathFunctionDef(
        key: 'logarithmic', label: 'Logarítmica', color: const Color(0xFF4EC994),
        params: [
          const _ParamDef('b', 'b', 1.1, 4, 0.1, 2),
        ],
        eq: (p) => 'y = log${_sub(_fmt(p['b']!))}(x)',
        fn: (x, p) => math.log(x) / math.log(p['b']!),
        roots: (_) => const [1],
        domain: const [0.01, 12], range: const [-4, 5],
      ),
      'sine': _MathFunctionDef(
        key: 'sine', label: 'Seno', color: const Color(0xFFF0A500),
        params: [
          const _ParamDef('a', 'a', 0.5, 4, 0.1, 1),
          const _ParamDef('f', 'f', 0.2, 3, 0.1, 1),
          const _ParamDef('p', 'φ', -3.14, 3.14, 0.1, 0),
        ],
        eq: (p) => 'y = ${_fmt(p['a']!)}sen(${_fmt(p['f']!)}x${_signed(p['p']!)})',
        fn: (x, p) => p['a']! * math.sin(p['f']! * x + p['p']!),
        roots: (p) {
          if (p['f'] == 0) return const [];
          final roots = <double>[];
          for (int n = -4; n <= 4; n++) {
            final x = (n * math.pi - p['p']!) / p['f']!;
            if (x >= -10 && x <= 10) roots.add(x);
          }
          return roots;
        },
        domain: const [-10, 10], range: const [-5, 5],
      ),
      'cosine': _MathFunctionDef(
        key: 'cosine', label: 'Cosseno', color: const Color(0xFFF0A500),
        params: [
          const _ParamDef('a', 'a', 0.5, 4, 0.1, 1),
          const _ParamDef('f', 'f', 0.2, 3, 0.1, 1),
          const _ParamDef('p', 'φ', -3.14, 3.14, 0.1, 0),
        ],
        eq: (p) => 'y = ${_fmt(p['a']!)}cos(${_fmt(p['f']!)}x${_signed(p['p']!)})',
        fn: (x, p) => p['a']! * math.cos(p['f']! * x + p['p']!),
        roots: (p) {
          if (p['f'] == 0) return const [];
          final roots = <double>[];
          for (int n = -4; n <= 4; n++) {
            final x = ((n + 0.5) * math.pi - p['p']!) / p['f']!;
            if (x >= -10 && x <= 10) roots.add(x);
          }
          return roots;
        },
        domain: const [-10, 10], range: const [-5, 5],
      ),
      'absolute': _MathFunctionDef(
        key: 'absolute', label: 'Módulo', color: const Color(0xFFC77DFF),
        params: [
          const _ParamDef('a', 'a', -3, 3, 0.1, 1),
          const _ParamDef('h', 'h', -6, 6, 0.5, 0),
          const _ParamDef('k', 'k', -6, 6, 0.5, -2),
        ],
        eq: (p) => 'y = ${_fmt(p['a']!)}|x${_signed(p['h']! * -1)}|${_signed(p['k']!)}',
        fn: (x, p) => p['a']! * (x - p['h']!).abs() + p['k']!,
        roots: (p) {
          if (p['a'] == 0) return const [];
          final v = -p['k']! / p['a']!;
          if (v < 0) return const [];
          if (v == 0) return [p['h']!];
          return [p['h']! - v, p['h']! + v];
        },
        domain: const [-10, 10], range: const [-9, 9],
      ),
      'rational': _MathFunctionDef(
        key: 'rational', label: 'Racional', color: const Color(0xFF5ECBE0),
        params: [
          const _ParamDef('a', 'a', -6, 6, 0.25, 2),
          const _ParamDef('h', 'h', -5, 5, 0.5, 0),
          const _ParamDef('k', 'k', -5, 5, 0.5, 0),
        ],
        eq: (p) => 'y = ${_fmt(p['a']!)}/(x${_signed(p['h']! * -1)})${_signed(p['k']!)}',
        fn: (x, p) => p['a']! / (x - p['h']!) + p['k']!,
        asymptoteX: (p) => p['h']!,
        excludeAt: (p) => p['h']!,
        roots: (p) {
          if (p['k'] == 0) return const [];
          return [-p['a']! / p['k']! + p['h']!];
        },
        domain: const [-10, 10], range: const [-9, 9],
      ),
      'circle': _MathFunctionDef(
        key: 'circle', label: 'Círculo', color: const Color(0xFFC77DFF),
        params: [
          const _ParamDef('r', 'r', 1, 6, 0.25, 3),
          const _ParamDef('cx', 'cx', -5, 5, 0.5, 0),
          const _ParamDef('cy', 'cy', -5, 5, 0.5, 0),
        ],
        eq: (p) => '(x${_signed(p['cx']! * -1)})² + (y${_signed(p['cy']! * -1)})² = ${_fmt(p['r']!)}²',
        fn: (x, p) => 0, // não usado
        isParametric: true,
        parametricX: (t, p) => p['cx']! + p['r']! * math.cos(t),
        parametricY: (t, p) => p['cy']! + p['r']! * math.sin(t),
        domain: const [-8, 8], range: const [-7, 7],
      ),
    };
  }

  Map<String, double> _defaultParams(String type) {
    final def = _functionDefs[type]!;
    final map = <String, double>{};
    for (final param in def.params) {
      map[param.key] = param.defaultValue;
    }
    return map;
  }

  _MathFunctionDef get _currentDef => _functionDefs[_currentType]!;
  String get _eqString => _currentDef.eq(_params);
  String? get _rootsString {
    final roots = _currentDef.roots?.call(_params) ?? const [];
    final filtered = roots.where((r) => r.isFinite).toList();
    if (filtered.isEmpty) return null;
    if (filtered.length == 1) return 'raiz: x = ${_fmt(filtered.first)}';
    final parts = filtered.map((r) => 'x = ${_fmt(r)}').join(', ');
    return 'raízes:\n$parts';
  }

  void _updateParam(String key, double value) {
    setState(() => _params[key] = value);
  }

  void _reset() {
    _animTimer?.cancel();
    _animating = false;
    setState(() {
      _params = _defaultParams(_currentType);
    });
  }

  void _toggleAnimation() {
    if (_animating) {
      _animTimer?.cancel();
      setState(() => _animating = false);
      return;
    }
    final def = _currentDef;
    if (def.params.isEmpty) return;
    final firstParam = def.params.first;
    _animDir = 1;
    _animating = true;
    setState(() {});
    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final key = firstParam.key;
      final speed = (firstParam.max - firstParam.min) / 140;
      final current = _params[key]!;
      var next = current + speed * _animDir;
      if (next >= firstParam.max) {
        next = firstParam.max;
        _animDir = -1;
      } else if (next <= firstParam.min) {
        next = firstParam.min;
        _animDir = 1;
      }
      setState(() => _params[key] = next);
    });
  }

  Future<void> _openEditSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MathTypeSheet(
        currentType: _currentType,
        functionDefs: _functionDefs,
        isDark: widget.s.isDark,
        primary: widget.s.primary,
        onSurface: widget.s.onSurface,
        onSurfaceVariant: widget.s.onSurfaceVariant,
      ),
    );
    if (selected != null && selected != _currentType) {
      setState(() {
        _currentType = selected;
        _params = _defaultParams(selected);
      });
    }
  }

  Widget _buildSliders() {
    final def = _currentDef;
    return Column(
      children: def.params.map((param) {
        final value = _params[param.key] ?? param.defaultValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Center(
                  child: Text(
                    param.symbol,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Georgia',
                      color: widget.s.onSurface,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.s.primary,
                    inactiveTrackColor: widget.s.isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                    thumbColor: Colors.white,
                    overlayColor: widget.s.primary.withOpacity(0.2),
                    trackHeight: 5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    value: value.clamp(param.min, param.max),
                    min: param.min,
                    max: param.max,
                    divisions: ((param.max - param.min) / param.step).round().clamp(1, 1000),
                    onChanged: (v) => _updateParam(param.key, v),
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  _fmt(value),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.s.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend() {
    final def = _currentDef;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Row(
        children: [
          _LegendItem(color: def.color, label: def.label),
          const SizedBox(width: 14),
          _LegendItem(color: widget.s.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFCCCCCC), label: 'eixos'),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: widget.s.isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _openEditSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: widget.s.primary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit_rounded, size: 15, color: Colors.white),
                    const SizedBox(width: 7),
                    Text(
                      'Editar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _CircleActionButton(
            icon: _animating ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onTap: _toggleAnimation,
            active: _animating,
          ),
          const SizedBox(width: 6),
          _CircleActionButton(
            icon: Icons.refresh_rounded,
            onTap: _reset,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: s.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(s.isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: s.isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _eqString,
                            style: TextStyle(
                              color: s.isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1A1A1A),
                              fontSize: 15,
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        if (_rootsString != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _rootsString!,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: s.onSurfaceVariant,
                              fontSize: 10.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      painter: _MathGraphPainter(
                        def: _currentDef,
                        params: _params,
                        isDark: s.isDark,
                        primary: s.primary,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  _buildLegend(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: s.isDark ? const Color(0xFF202020) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _buildSliders(),
          ),
          const SizedBox(height: 10),
          _buildActionBar(),
        ],
      ),
    );
  }
}

// ─── Botão circular para ações do math graph ───
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1F6A9E) : s.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}

// ─── Item de legenda ───
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.of(context).onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Modal de seleção do tipo de função ───
class _MathTypeSheet extends StatefulWidget {
  final String currentType;
  final Map<String, _MathFunctionDef> functionDefs;
  final bool isDark;
  final Color primary;
  final Color onSurface;
  final Color onSurfaceVariant;
  const _MathTypeSheet({
    required this.currentType,
    required this.functionDefs,
    required this.isDark,
    required this.primary,
    required this.onSurface,
    required this.onSurfaceVariant,
  });

  @override
  State<_MathTypeSheet> createState() => _MathTypeSheetState();
}

class _MathTypeSheetState extends State<_MathTypeSheet> {
  late String _pendingType;

  @override
  void initState() {
    super.initState();
    _pendingType = widget.currentType;
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.functionDefs.keys.toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Editar gráfico',
            style: TextStyle(
              color: widget.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: types.map((key) {
              final def = widget.functionDefs[key]!;
              final active = key == _pendingType;
              return GestureDetector(
                onTap: () => setState(() => _pendingType = key),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? widget.primary : (widget.isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE)),
                    border: Border.all(
                      color: active ? widget.primary : (widget.isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    def.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : widget.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF262626) : const Color(0xFFEEEEEE),
                      border: Border.all(color: widget.isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: widget.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, _pendingType),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Aplicar',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Painter do gráfico ───
class _MathGraphPainter extends CustomPainter {
  final _MathFunctionDef def;
  final Map<String, double> params;
  final bool isDark;
  final Color primary;
  _MathGraphPainter({
    required this.def,
    required this.params,
    required this.isDark,
    required this.primary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 10 || size.height < 10) return;

    const padLeft = 32.0;
    const padRight = 12.0;
    const padTop = 12.0;
    const padBottom = 24.0;
    final graphRect = Rect.fromLTRB(padLeft, padTop, size.width - padRight, size.height - padBottom);

    final domain = def.domain;
    final range = def.range;
    final xMin = domain[0], xMax = domain[1];
    final yMin = range[0], yMax = range[1];

    Offset mapPoint(double x, double y, Rect rect) {
      final px = rect.left + (x - xMin) / (xMax - xMin) * rect.width;
      final py = rect.bottom - (y - yMin) / (yMax - yMin) * rect.height;
      return Offset(px, py);
    }

    final gridColor = isDark ? const Color(0xFF252525) : const Color(0xFFE0E0E0);
    final axisColor = isDark ? const Color(0xFF4A4A4A) : const Color(0xFF999999);
    final labelColor = isDark ? const Color(0xFF5A5A5A) : const Color(0xFF777777);

    final stepX = _niceStep(xMax - xMin, 8);
    final stepY = _niceStep(yMax - yMin, 6);
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;

    for (double x = (xMin / stepX).ceil() * stepX; x <= xMax; x += stepX) {
      final p = mapPoint(x, 0, graphRect);
      canvas.drawLine(Offset(p.dx, graphRect.top), Offset(p.dx, graphRect.bottom), gridPaint);
    }
    for (double y = (yMin / stepY).ceil() * stepY; y <= yMax; y += stepY) {
      final p = mapPoint(0, y, graphRect);
      canvas.drawLine(Offset(graphRect.left, p.dy), Offset(graphRect.right, p.dy), gridPaint);
    }

    final origin = mapPoint(0, 0, graphRect);
    final originY = origin.dy.clamp(graphRect.top, graphRect.bottom);
    final originX = origin.dx.clamp(graphRect.left, graphRect.right);

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(graphRect.left, originY), Offset(graphRect.right, originY), axisPaint);
    final arrowX = Path()
      ..moveTo(graphRect.right - 8, originY - 4)
      ..lineTo(graphRect.right, originY)
      ..lineTo(graphRect.right - 8, originY + 4);
    canvas.drawPath(arrowX, axisPaint);

    canvas.drawLine(Offset(originX, graphRect.top), Offset(originX, graphRect.bottom), axisPaint);
    final arrowY = Path()
      ..moveTo(originX - 4, graphRect.top + 8)
      ..lineTo(originX, graphRect.top)
      ..lineTo(originX + 4, graphRect.top + 8);
    canvas.drawPath(arrowY, axisPaint);

    _drawText(canvas, 'x', Offset(graphRect.right - 14, originY - 8), labelColor, fontSize: 11, fontStyle: FontStyle.italic);
    _drawText(canvas, 'y', Offset(originX + 8, graphRect.top + 14), labelColor, fontSize: 11, fontStyle: FontStyle.italic);

    _drawTicks(canvas, graphRect, stepX, stepY, originY, originX, labelColor);

    final asymptoteX = def.asymptoteX?.call(params);
    if (asymptoteX != null) {
      final ax = mapPoint(asymptoteX, 0, graphRect).dx.clamp(graphRect.left, graphRect.right);
      final dashPaint = Paint()
        ..color = isDark ? const Color(0xFF555555) : const Color(0xFF999999)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final dashPath = Path();
      const dashWidth = 4.0;
      const dashGap = 4.0;
      double y = graphRect.top;
      while (y < graphRect.bottom) {
        dashPath.moveTo(ax, y);
        dashPath.lineTo(ax, math.min(y + dashWidth, graphRect.bottom));
        y += dashWidth + dashGap;
      }
      canvas.drawPath(dashPath, dashPaint);
    }

    final curvePaint = Paint()
      ..color = def.color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final curvePath = Path();
    bool first = true;

    if (def.isParametric) {
      final steps = 200;
      for (int i = 0; i <= steps; i++) {
        final t = (i / steps) * 2 * math.pi;
        final x = def.parametricX!(t, params);
        final y = def.parametricY!(t, params);
        final pt = mapPoint(x, y, graphRect);
        if (first) {
          curvePath.moveTo(pt.dx, pt.dy);
          first = false;
        } else {
          curvePath.lineTo(pt.dx, pt.dy);
        }
      }
    } else {
      final samples = 320;
      final excludeAt = def.excludeAt?.call(params);
      for (int s = 0; s <= samples; s++) {
        final x = xMin + (xMax - xMin) * (s / samples);
        if (def.key == 'logarithmic' && x <= 0) {
          first = true;
          continue;
        }
        if (excludeAt != null && (x - excludeAt).abs() < 0.03) {
          first = true;
          continue;
        }
        final y = def.fn(x, params);
        if (!y.isFinite || y < yMin - 4 || y > yMax + 4) {
          first = true;
          continue;
        }
        final pt = mapPoint(x, y, graphRect);
        if (first) {
          curvePath.moveTo(pt.dx, pt.dy);
          first = false;
        } else {
          curvePath.lineTo(pt.dx, pt.dy);
        }
      }
    }
    canvas.drawPath(curvePath, curvePaint);

    final roots = def.roots?.call(params) ?? const [];
    for (final root in roots) {
      if (!root.isFinite || root < xMin || root > xMax) continue;
      final rp = mapPoint(root, 0, graphRect);
      final rootPaint = Paint()..color = Colors.white;
      canvas.drawCircle(rp, 5, rootPaint);
      final rootStroke = Paint()
        ..color = def.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(rp, 5, rootStroke);
    }

    final markerX = def.markerX?.call(params);
    final markerY = def.markerY?.call(params);
    if (markerX != null && markerY != null && markerX >= xMin && markerX <= xMax && markerY >= yMin && markerY <= yMax) {
      final mp = mapPoint(markerX, markerY, graphRect);
      final markerFill = Paint()..color = def.color;
      canvas.drawCircle(mp, 6, markerFill);
      final markerStroke = Paint()
        ..color = isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(mp, 6, markerStroke);
    }
  }

  void _drawTicks(Canvas canvas, Rect rect, double stepX, double stepY, double originY, double originX, Color color) {
    final domain = def.domain;
    final range = def.range;
    final xMin = domain[0], xMax = domain[1];
    final yMin = range[0], yMax = range[1];

    for (double x = (xMin / stepX).ceil() * stepX; x <= xMax; x += stepX) {
      if ((x.abs()) < stepX / 4) continue;
      final px = rect.left + (x - xMin) / (xMax - xMin) * rect.width;
      if (px < rect.left || px > rect.right) continue;
      final tp = TextPainter(
        text: TextSpan(text: _fmt(x), style: TextStyle(color: color, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, originY + 4));
    }

    for (double y = (yMin / stepY).ceil() * stepY; y <= yMax; y += stepY) {
      if ((y.abs()) < stepY / 4) continue;
      final py = rect.bottom - (y - yMin) / (yMax - yMin) * rect.height;
      if (py < rect.top || py > rect.bottom) continue;
      final tp = TextPainter(
        text: TextSpan(text: _fmt(y), style: TextStyle(color: color, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left - tp.width - 6, py - tp.height / 2));
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, {double fontSize = 11, FontStyle fontStyle = FontStyle.normal}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontStyle: fontStyle, fontFamily: 'Georgia'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MathGraphPainter old) {
    return old.def != def || old.params != params || old.isDark != isDark || old.primary != primary;
  }
}

// ─── Helpers de formatação ───
String _fmt(double n) {
  final r = (n * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return r.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

String _signed(double n) {
  final r = (n * 100).round() / 100;
  if (r == 0) return '';
  return (r > 0 ? ' + ' : ' - ') + _fmt(r.abs());
}

String _sub(String s) {
  const map = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉', '.': '.',
  };
  return s.split('').map((c) => map[c] ?? c).join();
}

String _sup(String s) {
  const map = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  };
  return s.split('').map((c) => map[c] ?? c).join();
}

double _niceStep(double range, int maxTicks) {
  if (range == 0) return 1;
  final rough = range / maxTicks;
  final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final normalized = rough / magnitude;
  final double nice;
  if (normalized <= 1) {
    nice = 1.0;
  } else if (normalized <= 2) {
    nice = 2.0;
  } else if (normalized <= 5) {
    nice = 5.0;
  } else {
    nice = 10.0;
  }
  return nice * magnitude;
}

// ══════════════════════════════════════════════════════════════
// MAP (redesenhado — estilo card do HTML)
// ══════════════════════════════════════════════════════════════

class AiMapWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMapWidget({super.key, required this.json, required this.s});
  @override
  State<AiMapWidget> createState() => _AiMapWidgetState();
}

class _AiMapWidgetState extends State<AiMapWidget>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;

  late double _lat;
  late double _lng;
  late double _zoom;
  late String _name;

  final TextEditingController _searchCtrl = TextEditingController();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  bool _locating = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _lat = (widget.json['lat'] is num) ? (widget.json['lat'] as num).toDouble() : 38.7223;
    _lng = (widget.json['lng'] is num) ? (widget.json['lng'] as num).toDouble() : -9.1393;
    _zoom = (widget.json['zoom'] is num) ? (widget.json['zoom'] as num).toDouble() : 13.0;
    _name = (widget.json['name'] ?? 'Localização').toString();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Color get _cardBg => widget.s.isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get _previewBg => widget.s.isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5);
  Color get _actionsBg => widget.s.isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0);
  Color get _badgeBg => widget.s.isDark
      ? Colors.black.withOpacity(0.8)
      : Colors.white.withOpacity(0.85);
  Color get _badgeText => widget.s.isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A);
  Color get _searchText => widget.s.isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A);
  Color get _searchHint => widget.s.isDark ? const Color(0xFF777777) : const Color(0xFF999999);
  Color get _recenterBg => widget.s.isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get _recenterIcon => widget.s.isDark ? const Color(0xFFDDDDDD) : const Color(0xFF444444);

  String get _tileUrl => widget.s.isDark
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

  Future<void> _locateUser() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _lat = position.latitude;
      _lng = position.longitude;
      _zoom = 15.0;
      _name = 'A sua localização';
      _mapController.move(ll.LatLng(_lat, _lng), _zoom);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível obter a localização.')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty || _searching) return;

    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(query)}');
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('Erro na pesquisa');

      final list = jsonDecode(res.body) as List;
      if (list.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Local não encontrado.')),
          );
        }
        return;
      }

      final first = list.first as Map<String, dynamic>;
      final lat = double.parse(first['lat'].toString());
      final lon = double.parse(first['lon'].toString());
      final displayName = (first['display_name'] as String? ?? query)
          .split(',')
          .take(2)
          .join(',');

      _lat = lat;
      _lng = lon;
      _zoom = 14.0;
      _name = displayName;

      _mapController.move(ll.LatLng(lat, lon), _zoom);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro na pesquisa.')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(s.isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: _previewBg,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: ll.LatLng(_lat, _lng),
                      initialZoom: _zoom,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _tileUrl,
                        userAgentPackageName: 'com.nexa.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: ll.LatLng(_lat, _lng),
                            width: 36,
                            height: 36,
                            child: _PulsingMapMarker(
                              animation: _pulseAnim,
                              color: s.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _badgeBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(
                            'location.svg',
                            color: s.primary,
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _name,
                            style: TextStyle(
                              color: _badgeText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _locateUser,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _recenterBg,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _locating
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: s.primary,
                                  ),
                                )
                              : AppIcon(
                                  'locate.svg',
                                  color: _recenterIcon,
                                  size: 15,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _actionsBg,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: _searchText, fontSize: 14),
                    cursorColor: s.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Procurar morada ou local…',
                      hintStyle: TextStyle(color: _searchHint, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _search,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: s.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _searching
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: s.onPrimary,
                              ),
                            )
                          : AppIcon(
                              'search.svg',
                              color: s.onPrimary,
                              size: 15,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingMapMarker extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  const _PulsingMapMarker({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final ringScale = animation.value;
        return SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SMALL DOTS LOADER
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32, height: 8,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            var t = (_c.value - delay) % 1.0;
            if (t < 0) t += 1.0;
            final scale = 0.5 + 0.5 * (t < 0.5 ? (t * 2) : (2 - t * 2));
            return Transform.scale(
              scale: scale,
              child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
            );
          }),
        ),
      ),
    );
  }
}