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
// widget_code também deixou de ser usado dentro do texto corrido:
// blocos de código markdown (```dart etc.) continuam a renderizar
// via AiCodeWidget quando widgetsEnabled=true (ver richtext.dart),
// mas agora AiCodeWidget ganhou expand + preview web (só para html).
//
// ATUALIZAÇÃO (preview real de código HTML): AiCodePreviewScreen
// deixou de ser um placeholder de texto e passa a renderizar o HTML
// real numa InAppWebView de ecrã inteiro. LanguageIcon NÃO foi
// alterado nesta sessão — já usa um fallback de glifos de texto
// (emoji/sigla curta por linguagem), sem depender de nenhum pacote
// de ícones SVG nem de assets/icons/lang/ (essa pasta não existe no
// pubspec.yaml real). Trocar por ícones SVG reais implicaria
// adicionar uma dependência nova ou uma pasta de assets nova, o que
// não foi pedido nem confirmado nesta sessão — mexer nisso agora
// seria inventar uma decisão de design não solicitada.
//
// CORREÇÕES DE COMPILAÇÃO (build real falhou, confirmado no log):
// 1) '$' sem escape dentro de strings com aspas simples ('sh': '$')
//    é interpretado por Dart como início de interpolação — corrigido
//    para '\$' nas entradas 'sh' e 'bash' de _fallbackGlyph.
// 2) 'Object' aparecia duas vezes na mesma literal `const Set<String>
//    _types` — Dart avalia Set const em tempo de compilação e
//    rejeita elementos duplicados; removida a segunda ocorrência.
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
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:ui' as ui;
import 'colors.dart';
import 'widgets.dart';
import 'richtext.dart' show buildAiTableFromWidgetJson;

// ══════════════════════════════════════════════════════════════
// IDS DE WIDGET SUPORTADOS
// ══════════════════════════════════════════════════════════════

const Set<String> kAiWidgetIds = {
  'widget_table', 'widget_code', 'widget_bar', 'widget_pie',
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
    case 'widget_code':     return AiCodeWidget(json: block.json, s: s);
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
    final raw = (widget.json['data'] ?? widget.json['slices'] ?? widget.json['bars'])
        as List? ??
        const [];
    _data = raw.asMap().entries.map((e) {
      final d = e.value as Map;
      return _ChartDataItem(
        (d['label'] ?? '?').toString(),
        (d['value'] is num) ? (d['value'] as num).toDouble() : double.tryParse(d['value'].toString()) ?? 0,
        _parseColor(d['color']) ?? _palette[e.key % _palette.length],
      );
    }).toList();
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
          ),
          child: AppIcon(icon, size: 15, color: Colors.white),
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
  }

  @override
  void dispose() {
    _titleController.dispose();
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
      _draftData.add(_ChartDataItem('Novo', 10, _colorPalette[_draftData.length % _colorPalette.length]));
    });
  }

  void _removeRow(int index) {
    setState(() {
      _draftData.removeAt(index);
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
                              controller: TextEditingController(text: item.label),
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
                              controller: TextEditingController(text: item.value.toString()),
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
// CODE WIDGET (novo design)
// ══════════════════════════════════════════════════════════════

class AiCodeWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiCodeWidget({super.key, required this.json, required this.s});
  @override
  State<AiCodeWidget> createState() => _AiCodeWidgetState();
}

class _AiCodeWidgetState extends State<AiCodeWidget> {
  bool _copied = false;

  String get _language {
    return (widget.json['language'] ?? widget.json['lang'] ?? 'text').toString().toLowerCase();
  }

  String get _code {
    return (widget.json['code'] ?? widget.json['content'] ?? widget.json['text'] ?? '').toString();
  }

  bool get _isHtml {
    final lang = _language;
    return lang == 'html' || lang == 'htm';
  }

  Color _cardBg()      => widget.s.isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color _previewBg()   => widget.s.isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5);
  Color _actionsBg()   => widget.s.isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0);
  Color _primary()     => const Color(0xFF2E8BC9);

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _code));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _downloadCode() {
    Clipboard.setData(ClipboardData(text: _code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado (download não implementado)')),
    );
  }

  void _openPreview() {
    if (_isHtml) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AiCodePreviewScreen(html: _code),
      ));
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pré-visualização'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Text(_code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
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
              child: _CodeBlockView(
                code: _code,
                language: _language,
                isDark: widget.s.isDark,
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
                    onTap: _openPreview,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _primary(),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon('play.svg', size: 14, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(
                            'Pré-visualizar',
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
                  icon: _copied ? 'check.svg' : 'copy.svg',
                  tooltip: 'Copiar',
                  onTap: _copyCode,
                  primary: _primary(),
                ),
                const SizedBox(width: 6),
                _CircularActionButton(
                  icon: 'download.svg',
                  tooltip: 'Download',
                  onTap: _downloadCode,
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

class _CodeBlockView extends StatelessWidget {
  final String code;
  final String language;
  final bool isDark;
  const _CodeBlockView({required this.code, required this.language, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lines = code.replaceAll('\r\n', '\n').split('\n');
    final lineNumberColor = isDark ? const Color(0xFF444444) : const Color(0xFFAAAAAA);
    final lineNumberBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFDDDDDD);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Números de linha (sticky left)
        Container(
          width: 36,
          color: lineNumberBg,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 1; i <= lines.length; i++)
                Text(
                  '$i',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.7,
                    color: lineNumberColor,
                  ),
                ),
            ],
          ),
        ),
        // Separador vertical
        Container(width: 1, color: borderColor),
        // Conteúdo do código com scroll horizontal
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: RichText(
                  text: _buildHighlightedCode(lines, language, isDark),
                  textDirection: TextDirection.ltr,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _buildHighlightedCode(List<String> lines, String lang, bool isDark) {
    final spans = <TextSpan>[];
    for (int i = 0; i < lines.length; i++) {
      final lineSpans = _highlightLine(lines[i], lang, isDark);
      spans.addAll(lineSpans);
      if (i < lines.length - 1) {
        spans.add(TextSpan(
          text: '\n',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.7,
            color: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF1A1A1A),
          ),
        ));
      }
    }
    return TextSpan(children: spans);
  }

  List<TextSpan> _highlightLine(String line, String lang, bool isDark) {
    // Cores adaptadas do design (tema escuro) e equivalentes claros
    final baseColor = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF1A1A1A);
    final tagColor = isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
    final attrColor = isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
    final valColor = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    final metaColor = isDark ? const Color(0xFF808080) : const Color(0xFF008000);
    final classColor = isDark ? const Color(0xFF4EC9B0) : const Color(0xFF267F99);
    final numColor = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    final punctColor = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF383A42);

    final tokenRe = RegExp(
      r'''("([^"\\]|\\.)*"|'([^'\\]|\\.)*'|`([^`\\]|\\.)*`|//.*|#.*|/\*[\s\S]*?\*/|<!--[\s\S]*?-->|\b\d+(\.\d+)?\b|[A-Za-z_][A-Za-z0-9_]*(?=\()|[A-Za-z_][A-Za-z0-9_]*|[{}()\[\];:,.<>=+\-*/%!&|^~?]''',
    );
    final spans = <TextSpan>[];
    int last = 0;
    for (final m in tokenRe.allMatches(line)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: line.substring(last, m.start),
          style: TextStyle(color: baseColor),
        ));
      }
      final tok = m.group(0)!;
      Color c = baseColor;
      FontWeight w = FontWeight.normal;
      FontStyle fs = FontStyle.normal;

      if (tok.startsWith('"') || tok.startsWith("'") || tok.startsWith('`')) {
        c = valColor;
      } else if (tok.startsWith('//') || tok.startsWith('#') || tok.startsWith('/*') || tok.startsWith('<!--')) {
        c = metaColor; fs = FontStyle.italic;
      } else if (RegExp(r'^\d').hasMatch(tok)) {
        c = numColor;
      } else if (_isHtmlTag(lang, tok)) {
        c = tagColor;
      } else if (RegExp(r'^[A-Z]').hasMatch(tok) || RegExp(r'^[a-z_][A-Za-z0-9_]*$').hasMatch(tok) && lang == 'html' && _isHtmlAttribute(tok)) {
        c = attrColor;
      } else if (RegExp(r'^[A-Z]').hasMatch(tok) || RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(tok) && lang == 'html' && _isHtmlClass(tok)) {
        c = classColor;
      } else if (RegExp(r'^[{}()\[\];:,.<>=+\-*/%!&|^~?]$').hasMatch(tok)) {
        c = punctColor;
      }
      spans.add(TextSpan(
        text: tok,
        style: TextStyle(color: c, fontWeight: w, fontStyle: fs),
      ));
      last = m.end;
    }
    if (last < line.length) {
      spans.add(TextSpan(
        text: line.substring(last),
        style: TextStyle(color: baseColor),
      ));
    }
    return spans;
  }

  bool _isHtmlTag(String lang, String token) {
    if (lang != 'html' && lang != 'htm' && lang != 'xml' && lang != 'svg') return false;
    return token.startsWith('<') || token.endsWith('>') || token.startsWith('</');
  }

  bool _isHtmlAttribute(String token) {
    // Heurística: atributos geralmente são palavras seguidas de = ou dentro de tag
    return token.contains('=') || token.endsWith('=');
  }

  bool _isHtmlClass(String token) {
    // Em HTML, classes aparecem como valores de class, mas também seletores CSS
    return token.startsWith('.') || token.startsWith('#');
  }
}

// ══════════════════════════════════════════════════════════════
// CODE PREVIEW SCREEN (inalterado)
// ══════════════════════════════════════════════════════════════

class AiCodePreviewScreen extends StatelessWidget {
  final String html;
  const AiCodePreviewScreen({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Pré-visualização', style: TextStyle(fontSize: 15, color: Colors.black87)),
      ),
      body: InAppWebView(
        initialData: InAppWebViewInitialData(data: html),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          transparentBackground: true,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TIMER (novo design - cronómetro com anel)
// ══════════════════════════════════════════════════════════════

class AiTimerWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiTimerWidget({super.key, required this.json, required this.s});
  @override
  State<AiTimerWidget> createState() => _AiTimerWidgetState();
}

class _AiTimerWidgetState extends State<AiTimerWidget> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_running) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_running) {
        _stopwatch.stop();
        _running = false;
      } else {
        _stopwatch.start();
        _running = true;
      }
    });
  }

  void _reset() {
    setState(() {
      _stopwatch.reset();
      if (_running) {
        _stopwatch.start(); // continua a contar se estava em execução
      }
    });
  }

  String _formatMain(int elapsedMs) {
    final totalSeconds = elapsedMs ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatCentis(int elapsedMs) {
    final centis = (elapsedMs % 1000) ~/ 10;
    return '.${centis.toString().padLeft(2, '0')}';
  }

  double _ringProgress(int elapsedMs) {
    // Progresso dentro de um minuto (0..1)
    return (elapsedMs % 60000) / 60000;
  }

  Color _cardBg()    => widget.s.isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color _previewBg() => widget.s.isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5);
  Color _actionsBg() => widget.s.isDark ? const Color(0xFF252525) : const Color(0xFFF0F0F0);
  Color _primary()   => const Color(0xFF2E8BC9);
  Color _runningPrimary() => const Color(0xFF4EC994);

  @override
  Widget build(BuildContext context) {
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final progress = _ringProgress(elapsedMs);
    final runningColor = _running ? _runningPrimary() : _primary();

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
              child: Center(
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(168, 168),
                        painter: _TimerRingPainter(
                          progress: progress,
                          trackColor: widget.s.isDark ? const Color(0xFF232323) : const Color(0xFFDDDDDD),
                          progressColor: runningColor,
                          strokeWidth: 14,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMain(elapsedMs),
                            style: TextStyle(
                              color: widget.s.isDark ? Colors.white : Colors.black87,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [ui.FontFeature.tabularFigures()],
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            _formatCentis(elapsedMs),
                            style: TextStyle(
                              color: widget.s.isDark ? const Color(0xFF555555) : const Color(0xFF888888),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [ui.FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                    onTap: _toggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: runningColor,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(
                            _running ? 'pause.svg' : 'play.svg',
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _running ? 'Pausar' : 'Iniciar',
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
                // Botão circular de reset
                GestureDetector(
                  onTap: _reset,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.s.isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon('refresh.svg', size: 16, color: Colors.white),
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

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;
  _TimerRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Trilha
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progresso
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter old) {
    return old.progress != progress ||
        old.trackColor != trackColor ||
        old.progressColor != progressColor;
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
  Offset position = Offset.zero;
  _MindNode({required this.id, required this.label, required this.color, required this.children});
}

class AiMindMapWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMindMapWidget({super.key, required this.json, required this.s});
  @override
  State<AiMindMapWidget> createState() => _AiMindMapWidgetState();
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
// MATH GRAPH
// ══════════════════════════════════════════════════════════════

class AiMathGraphWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMathGraphWidget({super.key, required this.json, required this.s});
  @override
  State<AiMathGraphWidget> createState() => _AiMathGraphWidgetState();
}

class _EquationSolution {
  final double x, y;
  const _EquationSolution(this.x, this.y);
}

class _AiMathGraphWidgetState extends State<AiMathGraphWidget> {
  late double _xMin, _xMax;
  double _scale = 1.0;
  Offset _pan = Offset.zero;

  @override
  void initState() {
    super.initState();
    _xMin = (widget.json['xMin'] is num) ? (widget.json['xMin'] as num).toDouble() : -10;
    _xMax = (widget.json['xMax'] is num) ? (widget.json['xMax'] as num).toDouble() : 10;
  }

  List<Offset>? _evaluate(String expr, double xMin, double xMax, int samples) {
    try {
      final parser = me.Parser();
      final exp = parser.parse(expr);
      final variable = me.Variable('x');
      final points = <Offset>[];
      for (int i = 0; i <= samples; i++) {
        final x = xMin + (xMax - xMin) * i / samples;
        final ctx = me.ContextModel()..bindVariable(variable, me.Number(x));
        final y = exp.evaluate(me.EvaluationType.REAL, ctx);
        if (y is num && y.isFinite) points.add(Offset(x, y.toDouble()));
      }
      return points;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final expr = (widget.json['expression'] ?? 'x').toString();
    final points = _evaluate(expr, _xMin, _xMax, 200);

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
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(children: [
            Expanded(
              child: Text('y = $expr',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: s.onSurface, fontFamily: 'monospace')),
            ),
          ]),
        ),
        SizedBox(
          height: 260,
          child: points == null
              ? Center(child: Text('Expressão inválida', style: TextStyle(color: s.error, fontSize: 13)))
              : GestureDetector(
                  onScaleUpdate: (d) {
                    setState(() {
                      _scale = (_scale * d.scale).clamp(0.3, 4.0);
                      _pan += d.focalPointDelta;
                    });
                  },
                  child: CustomPaint(
                    painter: _MathGraphPainter(points: points, isDark: s.isDark, scale: _scale, pan: _pan),
                    child: const SizedBox.expand(),
                  ),
                ),
        ),
        _WidgetActionBar(s: s, actions: [
          _WidgetAction(icon: 'zoom_in.svg', label: 'Ampliar', onTap: () => setState(() => _scale = (_scale + 0.3).clamp(0.3, 4.0))),
          _WidgetAction(icon: 'zoom_out.svg', label: 'Reduzir', onTap: () => setState(() => _scale = (_scale - 0.3).clamp(0.3, 4.0))),
          _WidgetAction(icon: 'refresh.svg', label: 'Repor', onTap: () => setState(() { _scale = 1.0; _pan = Offset.zero; })),
        ]),
      ]),
    );
  }
}

class _MathGraphPainter extends CustomPainter {
  final List<Offset> points;
  final bool isDark;
  final double scale;
  final Offset pan;
  _MathGraphPainter({required this.points, required this.isDark, required this.scale, required this.pan});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final xs = points.map((p) => p.dx);
    final ys = points.map((p) => p.dy);
    final xMin = xs.reduce(math.min), xMax = xs.reduce(math.max);
    final yMin = ys.reduce(math.min), yMax = ys.reduce(math.max);
    final xRange = (xMax - xMin).abs() < 0.0001 ? 1.0 : (xMax - xMin);
    final yRange = (yMax - yMin).abs() < 0.0001 ? 1.0 : (yMax - yMin);

    Offset toScreen(Offset p) {
      final nx = (p.dx - xMin) / xRange;
      final ny = 1 - (p.dy - yMin) / yRange;
      return Offset(nx * size.width * scale + pan.dx, ny * size.height * scale + pan.dy);
    }

    final axisColor = isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC);
    final zeroX = toScreen(const Offset(0, 0));
    canvas.drawLine(Offset(0, zeroX.dy), Offset(size.width, zeroX.dy), Paint()..color = axisColor..strokeWidth = 1);
    canvas.drawLine(Offset(zeroX.dx, 0), Offset(zeroX.dx, size.height), Paint()..color = axisColor..strokeWidth = 1);

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final sp = toScreen(points[i]);
      if (i == 0) {
        path.moveTo(sp.dx, sp.dy);
      } else {
        path.lineTo(sp.dx, sp.dy);
      }
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF6F5AF6)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _MathGraphPainter old) => true;
}

// ══════════════════════════════════════════════════════════════
// MAP
// ══════════════════════════════════════════════════════════════

class AiMapWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMapWidget({super.key, required this.json, required this.s});
  @override
  State<AiMapWidget> createState() => _AiMapWidgetState();
}

class _AiMapWidgetState extends State<AiMapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final lat = (widget.json['lat'] is num) ? (widget.json['lat'] as num).toDouble() : 38.7223;
    final lng = (widget.json['lng'] is num) ? (widget.json['lng'] as num).toDouble() : -9.1393;
    final zoom = (widget.json['zoom'] is num) ? (widget.json['zoom'] as num).toDouble() : 12.0;
    final name = (widget.json['name'] ?? '').toString();

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: 240,
          child: Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: ll.LatLng(lat, lng), initialZoom: zoom),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.nexa.app'),
                MarkerLayer(markers: [
                  Marker(
                    point: ll.LatLng(lat, lng),
                    width: 36, height: 36,
                    child: const Icon(Icons.location_pin, color: Color(0xFFE74C3C), size: 36),
                  ),
                ]),
              ],
            ),
            if (name.isNotEmpty)
              Positioned(
                left: 10, bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(8)),
                  child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
        _WidgetActionBar(s: s, actions: [
          _WidgetAction(icon: 'zoom_in.svg', label: 'Ampliar', onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
          _WidgetAction(icon: 'zoom_out.svg', label: 'Reduzir', onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SMALL DOTS LOADER
// ══════════════════════════════════════════════════════════════

class AiSmallDotsLoader extends StatefulWidget {
  final Color color;
  const AiSmallDotsLoader({super.key, required this.color});
  @override
  State<AiSmallDotsLoader> createState() => _AiSmallDotsLoaderState();
}

class _AiSmallDotsLoaderState extends State<AiSmallDotsLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

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