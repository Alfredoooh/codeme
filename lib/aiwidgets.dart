// ══════════════════════════════════════════════════════════════
// FILE: lib/aiwidgets.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'colors.dart';
import 'widgets.dart';
import 'richtext.dart' show buildAiTableFromWidgetJson;
import 'app_sheet.dart';
import 'sheets.dart';

// ══════════════════════════════════════════════════════════════
// FUNÇÃO AUXILIAR _parseColor
// ══════════════════════════════════════════════════════════════
Color? _parseColor(dynamic raw) {
  if (raw == null) return null;
  if (raw is Color) return raw;
  if (raw is int) return Color(raw);

  if (raw is String) {
    var hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(value);
    }
  }

  return null;
}

/// Remove caracteres estranhos de texto proveniente de JSON
String _sanitizeText(String? raw) {
  if (raw == null) return '';
  return raw
      .replaceAll('\n', ' ')
      .replaceAll('\r', '')
      .replaceAll('\t', ' ')
      .trim();
}

// ══════════════════════════════════════════════════════════════
// PALETA DEDICADA PARA MODO ESCURO
// ══════════════════════════════════════════════════════════════
// Os tons vindos de AppColorScheme (cardBackground/surface) ficam
// claros demais em dark mode quando comparados ao HTML de referência
// (#111 / #1c1c1e / #141414). Esta classe fornece tons mais profundos
// especificamente para estes widgets, mantendo o AppColorScheme
// intacto para o resto da app.
class _WidgetPalette {
  final AppColorScheme s;
  const _WidgetPalette(this.s);

  bool get isDark => s.isDark;

  // Fundo do card externo (moldura) — equivalente ao body #111 do HTML
  Color get cardOuter => isDark ? const Color(0xFF141414) : s.cardBackground;

  // Fundo do card interno (moldura .card) — equivalente a #1c1c1e
  Color get cardBg => isDark ? const Color(0xFF1C1C1E) : s.cardBackground;

  // Fundo da área de preview (mapa/gráfico) — equivalente a #141414
  Color get previewBg => isDark ? const Color(0xFF101010) : s.surface;

  // Fundo de elementos "hover" / pill de ações — equivalente a #252525
  Color get actionsBg => isDark ? const Color(0xFF232323) : s.hover;

  // Fundo de botões circulares secundários (nav, recentrar) — #1c1c1e
  Color get navBtnBg => isDark ? const Color(0xFF1C1C1E) : s.hover;

  // Fundo de badges flutuantes (localização) — rgba(20,20,20,0.85)
  Color get badgeBg => isDark
      ? const Color(0xFF141414).withOpacity(0.88)
      : s.cardBackground.withOpacity(0.9);

  // Fundo de opções de lista (seletor de camadas / par) — #252525
  Color get optionBg => isDark ? const Color(0xFF232323) : s.hover;

  Color get optionBgHover => isDark ? const Color(0xFF2E2E2E) : s.hover;

  Color get outline => isDark ? Colors.white.withOpacity(0.06) : s.outline.withOpacity(0.1);

  Color get onSurface => s.onSurface;
  Color get onSurfaceVariant => s.onSurfaceVariant;
  Color get primary => s.primary;
  Color get onPrimary => s.onPrimary;

  List<BoxShadow> get cardShadow => isDark
      ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ]
      : s.cardShadow;
}

// ══════════════════════════════════════════════════════════════
// IDS DE WIDGET SUPORTADOS (apenas market, calendar, map)
// ══════════════════════════════════════════════════════════════

const Set<String> kAiWidgetIds = {
  'widget_market',
  'widget_calendar',
  'widget_map',
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

/// Deteta se `raw` contém um bloco ```widget_x``` aberto mas não fechado.
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
    case 'widget_market':   return AiMarketWidget(json: block.json, s: s);
    case 'widget_calendar': return AiCalendarWidget(json: block.json, s: s);
    case 'widget_map':      return AiMapWidget(json: block.json, s: s);
    default: return const SizedBox.shrink();
  }
}

// ══════════════════════════════════════════════════════════════
// MARKET WIDGET — VERSÃO COMPLETA
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

  // Posição de arrasto no gráfico (0..1), null quando não há toque ativo
  double? _dragX;

  static const List<_MarketPair> _pairs = [
    _MarketPair(key: 'BTCUSD', label: 'BTC/USD', sub: 'Bitcoin', basePrice: 64200, volatility: 0.018, badge: 'cripto'),
    _MarketPair(key: 'ETHUSD', label: 'ETH/USD', sub: 'Ethereum', basePrice: 3180, volatility: 0.022, badge: 'cripto'),
    _MarketPair(key: 'SOLUSD', label: 'SOL/USD', sub: 'Solana', basePrice: 148, volatility: 0.028, badge: 'cripto'),
    _MarketPair(key: 'EURUSD', label: 'EUR/USD', sub: 'Euro / Dólar', basePrice: 1.087, volatility: 0.004, badge: 'forex'),
    _MarketPair(key: 'GBPUSD', label: 'GBP/USD', sub: 'Libra / Dólar', basePrice: 1.271, volatility: 0.005, badge: 'forex'),
    _MarketPair(key: 'USDJPY', label: 'USD/JPY', sub: 'Dólar / Iene', basePrice: 156.4, volatility: 0.006, badge: 'forex'),
    _MarketPair(key: 'XAUUSD', label: 'XAU/USD', sub: 'Ouro', basePrice: 2340, volatility: 0.009, badge: 'metal'),
    _MarketPair(key: 'XAGUSD', label: 'XAG/USD', sub: 'Prata', basePrice: 29.4, volatility: 0.013, badge: 'metal'),
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

  _WidgetPalette get _p => _WidgetPalette(widget.s);

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
    _currentPairKey = _sanitizeText(widget.json['symbol']);
    if (_currentPairKey.isEmpty || !_pairs.any((p) => p.key == _currentPairKey)) {
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
    if (pair.key == 'XAGUSD') return '\$${v.toStringAsFixed(2)}';
    if (v >= 1000) {
      final formatted = v.round().toString();
      return '\$$formatted';
    }
    return '\$${v.toStringAsFixed(2)}';
  }

  String _formatTimeLabel(double tMs, String tf) {
    final dt = DateTime.fromMillisecondsSinceEpoch(tMs.toInt());
    if (tf == '1D') {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (tf == '1Y') {
      const months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
      return months[dt.month - 1];
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  void _changePair(String key) {
    setState(() {
      _currentPairKey = key;
      _dragX = null;
      _animController.forward(from: 0);
    });
  }

  void _changeTimeframe(String tf) {
    setState(() {
      _currentTf = tf;
      _dragX = null;
      _animController.forward(from: 0);
    });
  }

  Future<void> _openPairSelector() async {
    final p = _p;
    final selected = await showCraftBottomSheet<String>(
      context: context,
      s: widget.s,
      child: Builder(builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escolher par',
              style: TextStyle(color: p.onSurface, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView(
                shrinkWrap: true,
                children: _pairs.map((pair) {
                  final active = pair.key == _currentPairKey;
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, pair.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: active ? p.primary.withOpacity(0.16) : p.optionBg,
                        border: Border.all(color: active ? p.primary : p.outline),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: p.optionBgHover,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  pair.badge,
                                  style: TextStyle(
                                    color: p.onSurfaceVariant,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(pair.label, style: TextStyle(color: p.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text(pair.sub, style: TextStyle(color: p.onSurfaceVariant, fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      )),
    );
    if (selected != null && selected != _currentPairKey) {
      _changePair(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final pair = _currentPair;
    final series = _getSeries(pair.key, _currentTf);
    final first = series.first.v;
    final last = series.last.v;
    final change = ((last - first) / first) * 100;
    final isUp = last >= first;
    final color = isUp ? const Color(0xFF4EC994) : const Color(0xFFE05E5E);

    final values = series.map((e) => e.v).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);

    // Valor sob o dedo, se estiver a arrastar
    _MarketDataPoint? hoverPoint;
    if (_dragX != null) {
      final idx = (_dragX! * (series.length - 1)).round().clamp(0, series.length - 1);
      hoverPoint = series[idx];
    }
    final displayValue = hoverPoint?.v ?? last;
    final displayLabel = hoverPoint != null
        ? _formatTimeLabel(hoverPoint.t, _currentTf)
        : 'Agora';

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: p.outline),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: p.previewBg,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Cabeçalho: par, badge, preço, variação, máx/mín ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pair.label,
                            style: TextStyle(
                              color: p.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.optionBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pair.badge,
                              style: TextStyle(
                                color: p.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            displayLabel,
                            style: TextStyle(
                              color: p.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatPrice(displayValue, pair),
                            style: TextStyle(
                              color: p.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          AnimatedRotation(
                            turns: isUp ? 0.0 : 0.5,
                            duration: const Duration(milliseconds: 150),
                            child: AppIcon('chevron_up', color: color, size: 14),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${isUp ? '+' : ''}${change.toStringAsFixed(2)}% · $_currentTf',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Máx ${_formatPrice(maxV, pair)}',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mín ${_formatPrice(minV, pair)}',
                            style: TextStyle(color: p.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Gráfico interativo com grid, tooltip e arrasto ──
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (d) => setState(() {
                            _dragX = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                          }),
                          onHorizontalDragUpdate: (d) => setState(() {
                            _dragX = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                          }),
                          onHorizontalDragEnd: (_) => setState(() => _dragX = null),
                          onHorizontalDragCancel: () => setState(() => _dragX = null),
                          onTapDown: (d) => setState(() {
                            _dragX = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                          }),
                          onTapUp: (_) => setState(() => _dragX = null),
                          child: CustomPaint(
                            painter: _MarketChartPainter(
                              series: series,
                              progress: _progress,
                              isUp: isUp,
                              dragX: _dragX,
                              gridColor: p.onSurfaceVariant.withOpacity(0.08),
                              axisTextColor: p.onSurfaceVariant.withOpacity(0.55),
                              tooltipBg: p.cardBg,
                              tooltipBorder: p.outline,
                              tooltipText: p.onSurface,
                              formatLabel: (t) => _formatTimeLabel(t, _currentTf),
                              formatPrice: (v) => _formatPrice(v, pair),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Seletor de timeframe ──
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
                              color: active ? p.optionBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tf.label,
                              style: TextStyle(
                                color: active ? p.onSurface : p.onSurfaceVariant,
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

          const SizedBox(height: 10),

          // ── Ação principal: alterar moeda ──
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: p.actionsBg,
              borderRadius: BorderRadius.circular(50),
            ),
            child: GestureDetector(
              onTap: _openPairSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('repaste', color: p.onPrimary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Alterar moeda',
                      style: TextStyle(
                        color: p.onPrimary,
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
  final double? dragX;
  final Color gridColor;
  final Color axisTextColor;
  final Color tooltipBg;
  final Color tooltipBorder;
  final Color tooltipText;
  final String Function(double) formatLabel;
  final String Function(double) formatPrice;

  _MarketChartPainter({
    required this.series,
    required this.progress,
    required this.isUp,
    required this.dragX,
    required this.gridColor,
    required this.axisTextColor,
    required this.tooltipBg,
    required this.tooltipBorder,
    required this.tooltipText,
    required this.formatLabel,
    required this.formatPrice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;

    final color = isUp ? const Color(0xFF4EC994) : const Color(0xFFE05E5E);
    final values = series.map((p) => p.v).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final avgV = values.reduce((a, b) => a + b) / values.length;
    final pad = (maxV - minV) * 0.15;
    final maxY = maxV + pad;
    final minY = minV - pad;

    const leftGutter = 4.0;
    const rightGutter = 4.0;
    const topGutter = 6.0;
    const bottomGutter = 22.0; // espaço para labels do eixo X

    final innerW = size.width - leftGutter - rightGutter;
    final innerH = size.height - topGutter - bottomGutter;

    Offset ptAt(int i) {
      final norm = (values[i] - minY) / (maxY - minY);
      final x = leftGutter + (innerW * i) / (values.length - 1);
      final yFull = topGutter + innerH - norm * innerH;
      final yBase = topGutter + innerH;
      final y = yBase - (yBase - yFull) * progress;
      return Offset(x, y);
    }

    // ── 1. Grid horizontal (4 linhas) ──
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = topGutter + (innerH / 3) * i;
      canvas.drawLine(Offset(leftGutter, y), Offset(leftGutter + innerW, y), gridPaint);
    }

    // ── 2. Linha de referência: preço médio do período ──
    final avgNorm = (avgV - minY) / (maxY - minY);
    final avgY = topGutter + innerH - avgNorm * innerH;
    final dashPaint = Paint()
      ..color = axisTextColor.withOpacity(0.5)
      ..strokeWidth = 1;
    double dashX = leftGutter;
    while (dashX < leftGutter + innerW) {
      canvas.drawLine(Offset(dashX, avgY), Offset(math.min(dashX + 4, leftGutter + innerW), avgY), dashPaint);
      dashX += 7;
    }

    // ── 3. Área de preenchimento (gradiente) ──
    final fillPath = Path()..moveTo(leftGutter, topGutter + innerH);
    for (int i = 0; i < values.length; i++) {
      final p = ptAt(i);
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(leftGutter + innerW, topGutter + innerH);
    fillPath.close();

    final gradient = ui.Gradient.linear(
      Offset(0, topGutter),
      Offset(0, topGutter + innerH),
      [color.withOpacity(0.28), color.withOpacity(0.0)],
    );
    canvas.drawPath(fillPath, Paint()..shader = gradient);

    // ── 4. Linha principal ──
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
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

    // ── 5. Labels do eixo X (início, meio, fim) ──
    void drawXLabel(int i, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(
          text: formatLabel(series[i].t),
          style: TextStyle(color: axisTextColor, fontSize: 9, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = ptAt(i).dx;
      double dx;
      if (align == TextAlign.left) {
        dx = x;
      } else if (align == TextAlign.right) {
        dx = x - tp.width;
      } else {
        dx = x - tp.width / 2;
      }
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - bottomGutter + 8));
    }

    drawXLabel(0, TextAlign.left);
    drawXLabel(values.length ~/ 2, TextAlign.center);
    drawXLabel(values.length - 1, TextAlign.right);

    // ── 6. Ponto final destacado (halo + core) ──
    final lastPt = ptAt(values.length - 1);
    canvas.drawCircle(lastPt, 7, Paint()..color = color.withOpacity(0.18));
    canvas.drawCircle(lastPt, 3.5, Paint()..color = color);
    canvas.drawCircle(lastPt, 3.5, Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // ── 7. Interação: linha vertical + tooltip no ponto arrastado ──
    if (dragX != null) {
      final idx = (dragX! * (values.length - 1)).round().clamp(0, values.length - 1);
      final hp = ptAt(idx);

      final vLinePaint = Paint()
        ..color = axisTextColor.withOpacity(0.35)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(hp.dx, topGutter), Offset(hp.dx, topGutter + innerH), vLinePaint);

      canvas.drawCircle(hp, 5, Paint()..color = tooltipBg);
      canvas.drawCircle(hp, 5, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      canvas.drawCircle(hp, 2.2, Paint()..color = color);

      // Caixa de tooltip com o preço exato
      final priceText = formatPrice(values[idx]);
      final tp = TextPainter(
        text: TextSpan(
          text: priceText,
          style: TextStyle(color: tooltipText, fontSize: 11, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final boxW = tp.width + 16;
      const boxH = 22.0;
      double boxX = hp.dx - boxW / 2;
      boxX = boxX.clamp(0.0, size.width - boxW);
      double boxY = hp.dy - boxH - 10;
      if (boxY < 0) boxY = hp.dy + 10;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxW, boxH),
        const Radius.circular(8),
      );
      canvas.drawRRect(rrect, Paint()..color = tooltipBg);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = tooltipBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      tp.paint(canvas, Offset(boxX + 8, boxY + (boxH - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter old) {
    return old.series != series ||
        old.progress != progress ||
        old.isUp != isUp ||
        old.dragX != dragX;
  }
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

  _WidgetPalette get _p => _WidgetPalette(widget.s);

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
      final date = _sanitizeText(d['date']);
      _events.putIfAbsent(date, () => []).add((
        name: _sanitizeText(d['name']),
        time: _sanitizeText(d['time']),
        color: _parseColor(d['color']) ?? const Color(0xFF6F5AF6),
      ));
    }
  }

  void _openNewEventSheet() {
    final p = _p;
    final s = widget.s;
    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    showCraftBottomSheet(
      context: context,
      s: s,
      child: Builder(builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Novo evento · $_selectedKey',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.onSurface)),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: p.onSurface),
                decoration: InputDecoration(
                  hintText: 'Nome do evento',
                  hintStyle: TextStyle(color: p.onSurfaceVariant),
                  filled: true, fillColor: p.optionBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timeCtrl,
                style: TextStyle(color: p.onSurface),
                decoration: InputDecoration(
                  hintText: 'Hora (ex: 14:00)',
                  hintStyle: TextStyle(color: p.onSurfaceVariant),
                  filled: true, fillColor: p.optionBg,
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
                  decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('Adicionar', style: TextStyle(color: p.onPrimary, fontWeight: FontWeight.w600, fontSize: 14.5)),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final y = _current.year, m = _current.month;
    final firstDay = DateTime(y, m, 1).weekday % 7;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final daysInPrev = DateTime(y, m, 0).day;

    final cells = <Widget>[];
    for (int i = firstDay - 1; i >= 0; i--) {
      final day = daysInPrev - i;
      cells.add(_buildDayCell(
        p: p,
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
        p: p,
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
        p: p,
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

    final selectedEvents = _events[_selectedKey] ?? const [];

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: p.outline),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: p.previewBg,
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
                            color: p.onSurface,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Row(
                          children: [
                            _buildNavButton(p: p, icon: 'chevron_left',
                              onTap: () => setState(() => _current = DateTime(_current.year, _current.month - 1, 1))),
                            const SizedBox(width: 8),
                            _buildNavButton(p: p, icon: 'chevron_right',
                              onTap: () => setState(() => _current = DateTime(_current.year, _current.month + 1, 1))),
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
                              color: p.onSurfaceVariant,
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
                  if (selectedEvents.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(color: selectedEvents.first.color, shape: BoxShape.circle)),
                          Expanded(
                            child: Text(
                              selectedEvents.length == 1
                                  ? selectedEvents.first.name
                                  : '${selectedEvents.first.name} +${selectedEvents.length - 1}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
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
              color: p.actionsBg,
              borderRadius: BorderRadius.circular(50),
            ),
            child: GestureDetector(
              onTap: _openNewEventSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('add', size: 14, color: p.onPrimary),
                    const SizedBox(width: 7),
                    Text(
                      'Novo evento',
                      style: TextStyle(
                        color: p.onPrimary,
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

  Widget _buildNavButton({required _WidgetPalette p, required String icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: p.navBtnBg,
          shape: BoxShape.circle,
        ),
        child: AppIcon(icon, size: 12, color: p.onSurfaceVariant),
      ),
    );
  }

  Widget _buildDayCell({
    required _WidgetPalette p,
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
                  ? p.primary
                  : isSelected
                      ? p.optionBg
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday || eventColors.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? p.onPrimary
                    : isOtherMonth
                        ? p.onSurfaceVariant.withOpacity(0.5)
                        : p.onSurface,
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
// MAP WIDGET — VERSÃO COMPLETA (paridade com o HTML de referência)
// ══════════════════════════════════════════════════════════════

enum _MapLayer { satellite, streets, dark, terrain }

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

  _MapLayer _layer = _MapLayer.satellite;
  bool _buildingsRelief = false; // efeito visual de relevo (sem lib 3D externa)

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _lat = (widget.json['lat'] is num) ? (widget.json['lat'] as num).toDouble() : 38.7223;
    _lng = (widget.json['lng'] is num) ? (widget.json['lng'] as num).toDouble() : -9.1393;
    _zoom = (widget.json['zoom'] is num) ? (widget.json['zoom'] as num).toDouble() : 13.0;
    _name = _sanitizeText(widget.json['name']);
    if (_name.isEmpty) _name = 'Localização';

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

  // ── Definições de camadas de tiles, equivalentes ao objeto layerDefs do HTML ──
  String get _tileUrl {
    switch (_layer) {
      case _MapLayer.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _MapLayer.streets:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _MapLayer.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case _MapLayer.terrain:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    }
  }

  List<String> get _tileSubdomains {
    switch (_layer) {
      case _MapLayer.satellite:
        return const [];
      case _MapLayer.dark:
        return const ['a', 'b', 'c', 'd'];
      case _MapLayer.streets:
      case _MapLayer.terrain:
        return const ['a', 'b', 'c'];
    }
  }

  String get _layerLabel {
    switch (_layer) {
      case _MapLayer.satellite: return 'Satélite';
      case _MapLayer.streets:   return 'Ruas';
      case _MapLayer.dark:      return 'Escuro';
      case _MapLayer.terrain:   return 'Terreno';
    }
  }

  String _layerIcon(_MapLayer l) {
    switch (l) {
      case _MapLayer.satellite: return 'satellite';
      case _MapLayer.streets:   return 'road';
      case _MapLayer.dark:      return 'moon';
      case _MapLayer.terrain:   return 'mountain';
    }
  }

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

  // ── Bottom sheet de seleção de camada + relevo (equivalente ao modal do HTML) ──
  Future<void> _openLayersSheet() async {
    final p = _p;
    await showCraftBottomSheet<void>(
      context: context,
      s: widget.s,
      child: StatefulBuilder(builder: (ctx, setSheetState) {
        Widget layerOption(_MapLayer l, String label) {
          final active = _layer == l;
          return GestureDetector(
            onTap: () {
              setState(() => _layer = l);
              setSheetState(() {});
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: active ? p.primary : p.optionBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  AppIcon(_layerIcon(l), size: 15, color: active ? p.onPrimary : p.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? p.onPrimary : p.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Vista do Mapa',
                      style: TextStyle(color: p.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: AppIcon('close', size: 16, color: p.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              layerOption(_MapLayer.satellite, 'Satélite'),
              layerOption(_MapLayer.streets, 'Ruas'),
              layerOption(_MapLayer.dark, 'Escuro'),
              layerOption(_MapLayer.terrain, 'Terreno'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: p.optionBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AppIcon('building', size: 15, color: p.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('Relevo de edifícios',
                            style: TextStyle(color: p.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Switch.adaptive(
                      value: _buildingsRelief,
                      activeColor: p.primary,
                      onChanged: (v) {
                        setState(() => _buildingsRelief = v);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: p.outline),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: p.previewBg,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // ── Camada base do mapa ──
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
                        subdomains: _tileSubdomains,
                      ),
                      // ── Efeito de "relevo de edifícios" (cosmético, sem lib 3D) ──
                      if (_buildingsRelief)
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.0),
                                  Colors.black.withOpacity(0.18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: ll.LatLng(_lat, _lng),
                            width: 36,
                            height: 36,
                            child: _PulsingMapMarker(
                              animation: _pulseAnim,
                              color: p.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Badge de localização ──
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: p.badgeBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon('location', color: p.primary, size: 13),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              _locating ? 'A localizar…' : _name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Botão de camadas (canto superior direito) ──
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _openLayersSheet,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: p.badgeBg,
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
                          child: AppIcon('layers', color: p.onSurface, size: 15),
                        ),
                      ),
                    ),
                  ),

                  // ── Chip com o nome da camada ativa ──
                  Positioned(
                    top: 54,
                    right: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _layerLabel,
                          style: TextStyle(color: p.onSurfaceVariant, fontSize: 9.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),

                  // ── Botão de recentrar ──
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _locateUser,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: p.navBtnBg,
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
                                  child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
                                )
                              : AppIcon('locate', color: p.onSurface, size: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Barra de pesquisa ──
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: p.actionsBg,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: p.onSurface, fontSize: 14),
                    cursorColor: p.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Procurar morada ou local…',
                      hintStyle: TextStyle(color: p.onSurfaceVariant, fontSize: 14),
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
                      color: p.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _searching
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: p.onPrimary),
                            )
                          : AppIcon('search', color: p.onPrimary, size: 15),
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