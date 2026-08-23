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
    if (!kAiWidgetIds.contains(id)) return m.group(0)!; // mantém o bloco original
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
// MARKET WIDGET
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
    final selected = await showAppSheet<String>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escolher par',
              style: TextStyle(color: widget.s.onSurface, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
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
                        color: active ? widget.s.primaryContainer.withOpacity(0.3) : widget.s.hover,
                        border: Border.all(color: active ? widget.s.primary : widget.s.outline),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pair.label, style: TextStyle(color: widget.s.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(pair.sub, style: TextStyle(color: widget.s.onSurfaceVariant, fontSize: 11)),
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
        color: widget.s.cardBackground,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: widget.s.outline.withOpacity(0.1)),
        boxShadow: widget.s.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: widget.s.surface,
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
                              style: TextStyle(
                                color: widget.s.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.s.hover,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pair.badge,
                                style: TextStyle(
                                  color: widget.s.onSurfaceVariant,
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
                          style: TextStyle(
                            color: widget.s.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
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
                                color: active ? widget.s.hover : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                tf.label,
                                style: TextStyle(
                                  color: active ? widget.s.onSurface : widget.s.onSurfaceVariant,
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
              color: widget.s.hover,
              borderRadius: BorderRadius.circular(50),
            ),
            child: GestureDetector(
              onTap: _openPairSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: widget.s.primary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('repaste', color: widget.s.onPrimary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Alterar moeda',
                      style: TextStyle(
                        color: widget.s.onPrimary,
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
      final date = _sanitizeText(d['date']);
      _events.putIfAbsent(date, () => []).add((
        name: _sanitizeText(d['name']),
        time: _sanitizeText(d['time']),
        color: _parseColor(d['color']) ?? const Color(0xFF6F5AF6),
      ));
    }
  }

  Color _cardBg()          => widget.s.cardBackground;
  Color _previewBg()       => widget.s.surface;
  Color _monthTextColor()  => widget.s.onSurface;
  Color _navBtnBg()        => widget.s.hover;
  Color _navIconColor()    => widget.s.onSurfaceVariant;
  Color _weekdayColor()    => widget.s.onSurfaceVariant;
  Color _dayNumColor()     => widget.s.onSurface;
  Color _otherMonthColor() => widget.s.onSurfaceVariant.withOpacity(0.5);
  Color _selectedBg()      => widget.s.hover;
  Color _actionsBg()       => widget.s.hover;
  Color _accent()          => widget.s.primary;

  void _openNewEventSheet() {
    final s = widget.s;
    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    showAppSheet(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    final firstDay = DateTime(y, m, 1).weekday % 7;
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
        border: Border.all(color: widget.s.outline.withOpacity(0.1)),
        boxShadow: widget.s.cardShadow,
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
                              icon: 'chevron_left',
                              onTap: () => setState(() => _current = DateTime(_current.year, _current.month - 1, 1)),
                            ),
                            const SizedBox(width: 8),
                            _buildNavButton(
                              icon: 'chevron_right',
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
                    AppIcon('add', size: 14, color: widget.s.onPrimary),
                    const SizedBox(width: 7),
                    Text(
                      'Novo evento',
                      style: TextStyle(
                        color: widget.s.onPrimary,
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
                    ? widget.s.onPrimary
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
// MAP
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

  Color get _cardBg => widget.s.cardBackground;
  Color get _previewBg => widget.s.surface;
  Color get _actionsBg => widget.s.hover;
  Color get _badgeBg => widget.s.cardBackground.withOpacity(0.9);
  Color get _badgeText => widget.s.onSurface;
  Color get _searchText => widget.s.onSurface;
  Color get _searchHint => widget.s.onSurfaceVariant;
  Color get _recenterBg => widget.s.cardBackground;
  Color get _recenterIcon => widget.s.onSurface;

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
        border: Border.all(color: s.outline.withOpacity(0.1)),
        boxShadow: s.cardShadow,
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
                            'location',
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
                                  'locate',
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
                              'search',
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