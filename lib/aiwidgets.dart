// ══════════════════════════════════════════════════════════════
// FILE: lib/aiwidgets.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'colors.dart';
import 'widgets.dart';
import 'richtext.dart' show buildAiTableFromWidgetJson;
import 'app_sheet.dart';
import 'sheets.dart';

// ══════════════════════════════════════════════════════════════
// FUNÇÕES AUXILIARES
// ══════════════════════════════════════════════════════════════
Color? _parseColor(dynamic raw) {
  if (raw == null) return null;
  if (raw is Color) return raw;
  if (raw is int) return Color(raw);
  if (raw is String) {
    var hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(value);
    }
  }
  return null;
}

String _sanitizeText(String? raw) {
  if (raw == null) return '';
  return raw.replaceAll('\n', ' ').replaceAll('\r', '').replaceAll('\t', ' ').trim();
}

// ══════════════════════════════════════════════════════════════
// PALETA DEDICADA — CORRIGIDA: moldura externa mais escura que o
// preview interno, para nunca mais colidirem visualmente no dark.
// ══════════════════════════════════════════════════════════════
class _WidgetPalette {
  final AppColorScheme s;
  const _WidgetPalette(this.s);

  bool get isDark => s.isDark;

  // Moldura externa (a "mãe") — agora mais escura que tudo lá dentro.
  Color get cardBg => isDark ? const Color(0xFF121214) : s.cardBackground;

  // Preview interno (mapa/gráfico/calendário) — um degrau acima da moldura.
  Color get previewBg => isDark ? const Color(0xFF1A1A1D) : s.surface;

  // Pill de ações inferior — mesmo nível do preview, para não competir com a moldura.
  Color get actionsBg => isDark ? const Color(0xFF1E1E21) : s.hover;

  Color get navBtnBg => isDark ? const Color(0xFF232326) : s.hover;

  Color get badgeBg => isDark
      ? const Color(0xFF141416).withOpacity(0.92)
      : s.cardBackground.withOpacity(0.9);

  Color get optionBg => isDark ? const Color(0xFF1E1E21) : s.hover;
  Color get optionBgHover => isDark ? const Color(0xFF29292C) : s.hover;

  Color get outline => isDark ? Colors.white.withOpacity(0.05) : s.outline.withOpacity(0.1);

  Color get onSurface => s.onSurface;
  Color get onSurfaceVariant => s.onSurfaceVariant;
  Color get primary => s.primary;
  Color get onPrimary => s.onPrimary;

  // Fundo de tela cheia (páginas de seleção)
  Color get pageBg => isDark ? const Color(0xFF0B0B0C) : s.pageBackground;

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 18, offset: const Offset(0, 5))]
      : s.cardShadow;
}

// ══════════════════════════════════════════════════════════════
// IDS DE WIDGET SUPORTADOS
// ══════════════════════════════════════════════════════════════
const Set<String> kAiWidgetIds = {'widget_market', 'widget_calendar', 'widget_map'};

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

final RegExp _kWidgetBlockRe = RegExp(r'```(widget_[a-z]+)\s*\n([\s\S]*?)```', multiLine: true);

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

bool hasOpenWidgetBlock(String raw) {
  final opens = RegExp(r'```widget_[a-z]+').allMatches(raw).length;
  final closesTotal = '```'.allMatches(raw).length;
  return opens > 0 && closesTotal % 2 == 1;
}

Widget buildAiWidget(AiWidgetBlock block, AppColorScheme s) {
  switch (block.id) {
    case 'widget_market':   return AiMarketWidget(json: block.json, s: s);
    case 'widget_calendar': return AiCalendarWidget(json: block.json, s: s);
    case 'widget_map':      return AiMapWidget(json: block.json, s: s);
    default: return const SizedBox.shrink();
  }
}

// ══════════════════════════════════════════════════════════════
// CACHE PERSISTENTE DE PAÍSES/PROVÍNCIAS (shared_preferences)
// ══════════════════════════════════════════════════════════════
class _GeoCache {
  static const _kCountriesKey = 'aiwidgets_geo_countries_v1';
  static const _kStatesPrefix = 'aiwidgets_geo_states_v1_';

  static List<String>? _memCountries;
  static final Map<String, List<String>> _memStates = {};

  static Future<List<String>> getCountries() async {
    if (_memCountries != null) return _memCountries!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_kCountriesKey);
      if (cached != null && cached.isNotEmpty) {
        _memCountries = cached;
        return cached;
      }
    } catch (_) {
      // shared_preferences pode falhar em ambientes de teste; segue para rede.
    }

    final res = await http
        .get(Uri.parse('https://countriesnow.space/api/v0.1/countries/positions'))
        .timeout(const Duration(seconds: 10));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (decoded['data'] as List? ?? [])
        .map((e) => _sanitizeText((e as Map)['name']?.toString()))
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    _memCountries = list;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kCountriesKey, list);
    } catch (_) {}
    return list;
  }

  static Future<List<String>> getStates(String country) async {
    if (_memStates.containsKey(country)) return _memStates[country]!;
    final key = '$_kStatesPrefix${country.toLowerCase()}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(key);
      if (cached != null && cached.isNotEmpty) {
        _memStates[country] = cached;
        return cached;
      }
    } catch (_) {}

    final res = await http
        .post(
          Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'country': country}),
        )
        .timeout(const Duration(seconds: 10));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final states = (data?['states'] as List? ?? [])
        .map((e) => _sanitizeText((e as Map)['name']?.toString()))
        .where((n) => n.isNotEmpty)
        .toList()
      ..sort();

    _memStates[country] = states;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, states);
    } catch (_) {}
    return states;
  }
}

// ══════════════════════════════════════════════════════════════
// MERCADO — DADOS DE PARES (partilhado entre widget e tela cheia)
// ══════════════════════════════════════════════════════════════
class _MarketPair {
  final String key;
  final String label;
  final String sub;
  final String badge; // 'cripto' | 'forex' | 'metal'
  final double basePrice;
  final double volatility;
  final String? coingeckoId; // usado para o ícone PNG oficial
  final String? fiatCountryCode; // usado para bandeira (moedas fiat)
  const _MarketPair({
    required this.key,
    required this.label,
    required this.sub,
    required this.badge,
    required this.basePrice,
    required this.volatility,
    this.coingeckoId,
    this.fiatCountryCode,
  });
}

const List<_MarketPair> _kMarketPairs = [
  _MarketPair(key: 'BTCUSD', label: 'BTC/USD', sub: 'Bitcoin', basePrice: 64200, volatility: 0.018, badge: 'cripto', coingeckoId: 'bitcoin'),
  _MarketPair(key: 'ETHUSD', label: 'ETH/USD', sub: 'Ethereum', basePrice: 3180, volatility: 0.022, badge: 'cripto', coingeckoId: 'ethereum'),
  _MarketPair(key: 'SOLUSD', label: 'SOL/USD', sub: 'Solana', basePrice: 148, volatility: 0.028, badge: 'cripto', coingeckoId: 'solana'),
  _MarketPair(key: 'BNBUSD', label: 'BNB/USD', sub: 'BNB', basePrice: 592, volatility: 0.02, badge: 'cripto', coingeckoId: 'binancecoin'),
  _MarketPair(key: 'XRPUSD', label: 'XRP/USD', sub: 'XRP', basePrice: 0.62, volatility: 0.026, badge: 'cripto', coingeckoId: 'ripple'),
  _MarketPair(key: 'ADAUSD', label: 'ADA/USD', sub: 'Cardano', basePrice: 0.44, volatility: 0.03, badge: 'cripto', coingeckoId: 'cardano'),
  _MarketPair(key: 'DOGEUSD', label: 'DOGE/USD', sub: 'Dogecoin', basePrice: 0.14, volatility: 0.035, badge: 'cripto', coingeckoId: 'dogecoin'),
  _MarketPair(key: 'EURUSD', label: 'EUR/USD', sub: 'Euro / Dólar', basePrice: 1.087, volatility: 0.004, badge: 'forex', fiatCountryCode: 'eu'),
  _MarketPair(key: 'GBPUSD', label: 'GBP/USD', sub: 'Libra / Dólar', basePrice: 1.271, volatility: 0.005, badge: 'forex', fiatCountryCode: 'gb'),
  _MarketPair(key: 'USDJPY', label: 'USD/JPY', sub: 'Dólar / Iene', basePrice: 156.4, volatility: 0.006, badge: 'forex', fiatCountryCode: 'jp'),
  _MarketPair(key: 'USDBRL', label: 'USD/BRL', sub: 'Dólar / Real', basePrice: 5.42, volatility: 0.007, badge: 'forex', fiatCountryCode: 'br'),
  _MarketPair(key: 'USDCHF', label: 'USD/CHF', sub: 'Dólar / Franco', basePrice: 0.88, volatility: 0.004, badge: 'forex', fiatCountryCode: 'ch'),
  _MarketPair(key: 'XAUUSD', label: 'XAU/USD', sub: 'Ouro', basePrice: 2340, volatility: 0.009, badge: 'metal'),
  _MarketPair(key: 'XAGUSD', label: 'XAG/USD', sub: 'Prata', basePrice: 29.4, volatility: 0.013, badge: 'metal'),
];

String? _pairIconUrl(_MarketPair p) {
  if (p.coingeckoId != null) {
    // Ícones oficiais servidos pela CoinGecko (usados amplamente como fonte
    // pública de imagens de criptomoedas, sem necessidade de API key para o CDN de assets).
    return 'https://assets.coingecko.com/coins/images/1/small/${p.coingeckoId}.png';
  }
  if (p.fiatCountryCode != null) {
    // Bandeira como aproximação visual da moeda fiat — não é 1:1 perfeito
    // (ex: EUR não tem "um" país), mas é a convenção visual mais reconhecível.
    return 'https://flagcdn.com/w160/${p.fiatCountryCode}.png';
  }
  return null;
}

// Mapeamento correto de ids CoinGecko p/ URL de ícone (a rota /1/ acima é
// só um placeholder de proporção; o id real do asset precisa de lookup).
// Para evitar links quebrados, resolvemos via endpoint público de "coins/list"
// com "include_platform=false" quando necessário — aqui usamos diretamente
// o padrão de CDN estável da CoinGecko por symbol conhecido.
const Map<String, String> _kCoingeckoIconOverride = {
  'bitcoin': 'https://assets.coingecko.com/coins/images/1/small/bitcoin.png',
  'ethereum': 'https://assets.coingecko.com/coins/images/279/small/ethereum.png',
  'solana': 'https://assets.coingecko.com/coins/images/4128/small/solana.png',
  'binancecoin': 'https://assets.coingecko.com/coins/images/825/small/bnb-icon2_2x.png',
  'ripple': 'https://assets.coingecko.com/coins/images/44/small/xrp-symbol-white-128.png',
  'cardano': 'https://assets.coingecko.com/coins/images/975/small/cardano.png',
  'dogecoin': 'https://assets.coingecko.com/coins/images/5/small/dogecoin.png',
};

String? _resolvedIconUrl(_MarketPair p) {
  if (p.coingeckoId != null && _kCoingeckoIconOverride.containsKey(p.coingeckoId)) {
    return _kCoingeckoIconOverride[p.coingeckoId];
  }
  return _pairIconUrl(p);
}

class _MarketDataPoint {
  final double t;
  final double v;
  const _MarketDataPoint(this.t, this.v);
}

int _hashKey(String str) {
  int h = 0;
  for (final code in str.codeUnits) {
    h = (h * 31 + code) & 0x7fffffff;
  }
  return h == 0 ? 1 : h;
}

List<_MarketDataPoint> _generateSeries(_MarketPair pair, String tfKey, int points) {
  final rand = math.Random(_hashKey('${pair.key}_$tfKey'));
  final list = <_MarketDataPoint>[];
  double price = pair.basePrice * (0.92 + rand.nextDouble() * 0.1);
  final now = DateTime.now().millisecondsSinceEpoch;
  final stepMs = tfKey == '1D' ? 60 * 60 * 1000 : tfKey == '1W' ? 24 * 60 * 60 * 1000 : tfKey == '1M' ? 24 * 60 * 60 * 1000 : 30 * 24 * 60 * 60 * 1000;
  for (int i = points; i >= 0; i--) {
    price *= (1 + (rand.nextDouble() - 0.48) * pair.volatility);
    list.add(_MarketDataPoint((now - i * stepMs).toDouble(), price));
  }
  return list;
}

String _formatPairPrice(double v, _MarketPair pair) {
  if (pair.badge == 'forex') return v.toStringAsFixed(4);
  if (v >= 1000) return '\$${v.round()}';
  return '\$${v.toStringAsFixed(2)}';
}

// ══════════════════════════════════════════════════════════════
// MARKET WIDGET (card)
// ══════════════════════════════════════════════════════════════
class AiMarketWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMarketWidget({super.key, required this.json, required this.s});
  @override State<AiMarketWidget> createState() => _AiMarketWidgetState();
}

class _AiMarketWidgetState extends State<AiMarketWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _progress = 0.0;
  double? _dragX;

  static const List<({String key, String label, int points})> _timeframes = [
    (key: '1D', label: '1D', points: 24),
    (key: '1W', label: '1W', points: 7),
    (key: '1M', label: '1M', points: 30),
    (key: '1Y', label: '1Y', points: 12),
  ];

  late String _currentPairKey;
  late String _currentTf;
  final Map<String, List<_MarketDataPoint>> _seriesCache = {};

  _MarketPair get _currentPair => _kMarketPairs.firstWhere((p) => p.key == _currentPairKey, orElse: () => _kMarketPairs.first);
  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
      ..addListener(() => setState(() => _progress = Curves.easeOutCubic.transform(_animController.value)));
    _currentTf = '1D';
    _currentPairKey = _sanitizeText(widget.json['symbol']);
    if (_currentPairKey.isEmpty || !_kMarketPairs.any((p) => p.key == _currentPairKey)) {
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
    return _seriesCache.putIfAbsent(cacheKey, () {
      final pair = _kMarketPairs.firstWhere((p) => p.key == pairKey);
      final tf = _timeframes.firstWhere((t) => t.key == tfKey);
      return _generateSeries(pair, tfKey, tf.points);
    });
  }

  String _formatTimeLabel(double tMs, String tf) {
    final dt = DateTime.fromMillisecondsSinceEpoch(tMs.toInt());
    if (tf == '1D') return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (tf == '1Y') {
      const months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
      return months[dt.month - 1];
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  void _changeTimeframe(String tf) {
    setState(() {
      _currentTf = tf;
      _dragX = null;
      _animController.forward(from: 0);
    });
  }

  Future<void> _openMarketSelector() async {
    final result = await Navigator.of(context).push<String>(
      CupertinoPageRoute(
        builder: (_) => _MarketSelectorScreen(s: widget.s, currentKey: _currentPairKey),
      ),
    );
    if (result != null && result != _currentPairKey) {
      setState(() {
        _currentPairKey = result;
        _dragX = null;
        _animController.forward(from: 0);
      });
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

    _MarketDataPoint? hoverPoint;
    if (_dragX != null) {
      final idx = (_dragX! * (series.length - 1)).round().clamp(0, series.length - 1);
      hoverPoint = series[idx];
    }
    final displayValue = hoverPoint?.v ?? last;
    final displayLabel = hoverPoint != null ? _formatTimeLabel(hoverPoint.t, _currentTf) : 'Agora';
    final iconUrl = _resolvedIconUrl(pair);

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
            decoration: BoxDecoration(color: p.previewBg, borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (iconUrl != null)
                            ClipOval(
                              child: Image.network(
                                iconUrl,
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          if (iconUrl != null) const SizedBox(width: 8),
                          Text(pair.label, style: TextStyle(color: p.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: p.optionBg, borderRadius: BorderRadius.circular(8)),
                            child: Text(pair.badge, style: TextStyle(color: p.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                          const Spacer(),
                          Text(displayLabel, style: TextStyle(color: p.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPairPrice(displayValue, pair),
                        style: TextStyle(color: p.onSurface, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
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
                          Text('${isUp ? '+' : ''}${change.toStringAsFixed(2)}% · $_currentTf',
                              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('Máx ${_formatPairPrice(maxV, pair)}', style: TextStyle(color: p.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text('Mín ${_formatPairPrice(minV, pair)}', style: TextStyle(color: p.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (d) => setState(() => _dragX = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)),
                          onHorizontalDragUpdate: (d) => setState(() => _dragX = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)),
                          onHorizontalDragEnd: (_) => setState(() => _dragX = null),
                          onHorizontalDragCancel: () => setState(() => _dragX = null),
                          onTapDown: (d) => setState(() => _dragX = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)),
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
                              formatPrice: (v) => _formatPairPrice(v, pair),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        );
                      },
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
                            decoration: BoxDecoration(color: active ? p.optionBg : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: Text(tf.label, style: TextStyle(color: active ? p.onSurface : p.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700)),
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
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(50)),
            child: GestureDetector(
              onTap: _openMarketSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(50)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('repaste', color: p.onPrimary, size: 16),
                    const SizedBox(width: 8),
                    Text('Alterar moeda', style: TextStyle(color: p.onPrimary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1)),
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
    required this.series, required this.progress, required this.isUp, required this.dragX,
    required this.gridColor, required this.axisTextColor, required this.tooltipBg,
    required this.tooltipBorder, required this.tooltipText, required this.formatLabel, required this.formatPrice,
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

    const leftGutter = 4.0, rightGutter = 4.0, topGutter = 6.0, bottomGutter = 22.0;
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

    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = topGutter + (innerH / 3) * i;
      canvas.drawLine(Offset(leftGutter, y), Offset(leftGutter + innerW, y), gridPaint);
    }

    final avgNorm = (avgV - minY) / (maxY - minY);
    final avgY = topGutter + innerH - avgNorm * innerH;
    final dashPaint = Paint()..color = axisTextColor.withOpacity(0.5)..strokeWidth = 1;
    double dashX = leftGutter;
    while (dashX < leftGutter + innerW) {
      canvas.drawLine(Offset(dashX, avgY), Offset(math.min(dashX + 4, leftGutter + innerW), avgY), dashPaint);
      dashX += 7;
    }

    final fillPath = Path()..moveTo(leftGutter, topGutter + innerH);
    for (int i = 0; i < values.length; i++) {
      final p = ptAt(i);
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(leftGutter + innerW, topGutter + innerH);
    fillPath.close();
    final gradient = ui.Gradient.linear(Offset(0, topGutter), Offset(0, topGutter + innerH), [color.withOpacity(0.28), color.withOpacity(0.0)]);
    canvas.drawPath(fillPath, Paint()..shader = gradient);

    final linePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
    final linePath = Path();
    for (int i = 0; i < values.length; i++) {
      final p = ptAt(i);
      if (i == 0) linePath.moveTo(p.dx, p.dy); else linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(linePath, linePaint);

    void drawXLabel(int i, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(text: formatLabel(series[i].t), style: TextStyle(color: axisTextColor, fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = ptAt(i).dx;
      double dx = align == TextAlign.left ? x : align == TextAlign.right ? x - tp.width : x - tp.width / 2;
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - bottomGutter + 8));
    }
    drawXLabel(0, TextAlign.left);
    drawXLabel(values.length ~/ 2, TextAlign.center);
    drawXLabel(values.length - 1, TextAlign.right);

    final lastPt = ptAt(values.length - 1);
    canvas.drawCircle(lastPt, 7, Paint()..color = color.withOpacity(0.18));
    canvas.drawCircle(lastPt, 3.5, Paint()..color = color);
    canvas.drawCircle(lastPt, 3.5, Paint()..color = Colors.white.withOpacity(0.9)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    if (dragX != null) {
      final idx = (dragX! * (values.length - 1)).round().clamp(0, values.length - 1);
      final hp = ptAt(idx);
      final vLinePaint = Paint()..color = axisTextColor.withOpacity(0.35)..strokeWidth = 1;
      canvas.drawLine(Offset(hp.dx, topGutter), Offset(hp.dx, topGutter + innerH), vLinePaint);
      canvas.drawCircle(hp, 5, Paint()..color = tooltipBg);
      canvas.drawCircle(hp, 5, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(hp, 2.2, Paint()..color = color);

      final priceText = formatPrice(values[idx]);
      final tp = TextPainter(
        text: TextSpan(text: priceText, style: TextStyle(color: tooltipText, fontSize: 11, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      final boxW = tp.width + 16;
      const boxH = 22.0;
      double boxX = (hp.dx - boxW / 2).clamp(0.0, size.width - boxW);
      double boxY = hp.dy - boxH - 10;
      if (boxY < 0) boxY = hp.dy + 10;
      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(8));
      canvas.drawRRect(rrect, Paint()..color = tooltipBg);
      canvas.drawRRect(rrect, Paint()..color = tooltipBorder..style = PaintingStyle.stroke..strokeWidth = 1);
      tp.paint(canvas, Offset(boxX + 8, boxY + (boxH - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter old) =>
      old.series != series || old.progress != progress || old.isUp != isUp || old.dragX != dragX;
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — SELETOR DE MERCADO
// ══════════════════════════════════════════════════════════════
class _MarketSelectorScreen extends StatefulWidget {
  final AppColorScheme s;
  final String currentKey;
  const _MarketSelectorScreen({required this.s, required this.currentKey});
  @override State<_MarketSelectorScreen> createState() => _MarketSelectorScreenState();
}

class _MarketSelectorScreenState extends State<_MarketSelectorScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _searchingRemote = false;
  List<_MarketPair> _remoteResults = [];
  Timer? _debounce;

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_MarketPair> get _localFiltered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _kMarketPairs;
    return _kMarketPairs.where((p) =>
        p.key.toLowerCase().contains(q) ||
        p.label.toLowerCase().contains(q) ||
        p.sub.toLowerCase().contains(q)).toList();
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() => _remoteResults = []);
      return;
    }
    // Se já há resultado local suficiente, não bate na API pública.
    if (_localFiltered.isNotEmpty) {
      setState(() => _remoteResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _searchRemote(v.trim()));
  }

  Future<void> _searchRemote(String q) async {
    setState(() => _searchingRemote = true);
    try {
      // API pública da CoinGecko para localizar símbolos de cripto que não
      // estão na nossa lista curada local.
      final uri = Uri.parse('https://api.coingecko.com/api/v3/search?query=${Uri.encodeComponent(q)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final coins = (decoded['coins'] as List? ?? []).take(8);
        final results = coins.map((c) {
          final m = c as Map<String, dynamic>;
          final symbol = (m['symbol'] as String? ?? '').toUpperCase();
          final id = m['id'] as String? ?? '';
          final name = m['name'] as String? ?? symbol;
          final thumb = m['large'] as String? ?? m['thumb'] as String?;
          return _MarketPair(
            key: '${symbol}USD',
            label: '$symbol/USD',
            sub: name,
            badge: 'cripto',
            basePrice: 1,
            volatility: 0.02,
            coingeckoId: id,
          )..let((p) => thumb != null ? _kCoingeckoIconOverride[id] = thumb : null);
        }).toList();
        if (mounted) setState(() => _remoteResults = results);
      }
    } catch (_) {
      // Falha de rede: mantém lista vazia, sem travar a tela.
    } finally {
      if (mounted) setState(() => _searchingRemote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final results = _query.trim().isEmpty
        ? _kMarketPairs
        : (_localFiltered.isNotEmpty ? _localFiltered : _remoteResults);

    return CupertinoPageScaffold(
      backgroundColor: p.pageBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.pageBg,
        border: null,
        middle: Text('Mercado', style: TextStyle(color: p.onSurface, fontWeight: FontWeight.w700)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: _searchingRemote
                          ? CupertinoActivityIndicator(color: p.onSurfaceVariant)
                          : Text('Sem resultados', style: TextStyle(color: p.onSurfaceVariant, fontSize: 14)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final pair = results[i];
                        final active = pair.key == widget.currentKey;
                        return _MarketPairRow(
                          s: widget.s,
                          pair: pair,
                          active: active,
                          onTap: () async {
                            final confirmed = await Navigator.of(context).push<bool>(
                              CupertinoPageRoute(
                                builder: (_) => _MarketPairDetailScreen(s: widget.s, pair: pair),
                              ),
                            );
                            if (confirmed == true && mounted) {
                              Navigator.of(context).pop(pair.key);
                            }
                          },
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  children: [
                    AppIcon('search', color: p.onSurfaceVariant, size: 17),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onQueryChanged,
                        style: TextStyle(color: p.onSurface, fontSize: 14),
                        cursorColor: p.primary,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Procurar símbolo, ex: BTC, EUR…',
                          hintStyle: TextStyle(color: p.onSurfaceVariant, fontSize: 14),
                        ),
                      ),
                    ),
                    if (_searchingRemote)
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: p.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pequeno helper de encadeamento (evita variável intermédia no map acima)
extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class _MarketPairRow extends StatelessWidget {
  final AppColorScheme s;
  final _MarketPair pair;
  final bool active;
  final VoidCallback onTap;
  const _MarketPairRow({required this.s, required this.pair, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = _WidgetPalette(s);
    final iconUrl = _resolvedIconUrl(pair);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30, height: 30,
              child: iconUrl != null
                  ? ClipOval(
                      child: Image.network(
                        iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle)),
                      ),
                    )
                  : Container(decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pair.label, style: TextStyle(color: p.onSurface, fontSize: 14.5, fontWeight: FontWeight.w600)),
                  Text(pair.sub, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            if (active) AppIcon('check', color: p.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — DETALHE DO PAR (ícone grande + poucos dados)
// ══════════════════════════════════════════════════════════════
class _MarketPairDetailScreen extends StatelessWidget {
  final AppColorScheme s;
  final _MarketPair pair;
  const _MarketPairDetailScreen({required this.s, required this.pair});

  @override
  Widget build(BuildContext context) {
    final p = _WidgetPalette(s);
    final series = _generateSeries(pair, '1D', 24);
    final first = series.first.v;
    final last = series.last.v;
    final change = ((last - first) / first) * 100;
    final isUp = last >= first;
    final color = isUp ? const Color(0xFF4EC994) : const Color(0xFFE05E5E);
    final values = series.map((e) => e.v).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final iconUrl = _resolvedIconUrl(pair);

    return CupertinoPageScaffold(
      backgroundColor: p.pageBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.pageBg,
        border: null,
        middle: Text(pair.label, style: TextStyle(color: p.onSurface, fontWeight: FontWeight.w700)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 96, height: 96,
                      child: iconUrl != null
                          ? ClipOval(
                              child: Image.network(
                                iconUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle)),
                              ),
                            )
                          : Container(decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle)),
                    ),
                    const SizedBox(height: 18),
                    Text(pair.sub, style: TextStyle(color: p.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      _formatPairPrice(last, pair),
                      style: TextStyle(color: p.onSurface, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedRotation(
                          turns: isUp ? 0.0 : 0.5,
                          duration: const Duration(milliseconds: 150),
                          child: AppIcon('chevron_up', color: color, size: 14),
                        ),
                        const SizedBox(width: 4),
                        Text('${isUp ? '+' : ''}${change.toStringAsFixed(2)}% hoje', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DetailStat(p: p, label: 'Máxima 24h', value: _formatPairPrice(maxV, pair)),
                        Container(width: 1, height: 30, color: p.outline, margin: const EdgeInsets.symmetric(horizontal: 18)),
                        _DetailStat(p: p, label: 'Mínima 24h', value: _formatPairPrice(minV, pair)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('Selecionar', style: TextStyle(color: p.onPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final _WidgetPalette p;
  final String label;
  final String value;
  const _DetailStat({required this.p, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: p.onSurface, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: p.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CALENDÁRIO — CARD (abre tela cheia ao tocar em "Novo evento")
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

  Future<void> _openNewEventScreen() async {
    final result = await Navigator.of(context).push<({String name, String time, String color})>(
      CupertinoPageRoute(
        builder: (_) => _NewEventScreen(s: widget.s, dateKey: _selectedKey),
      ),
    );
    if (result != null) {
      setState(() {
        _events.putIfAbsent(_selectedKey, () => []).add((
          name: result.name,
          time: result.time,
          color: _parseColor(result.color) ?? const Color(0xFF6F5AF6),
        ));
      });
    }
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
      cells.add(_buildDayCell(p: p, label: day.toString(), isOtherMonth: true, isToday: false, isSelected: false, eventColors: const [], onTap: null));
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final key = _key(y, m, d);
      final isToday = DateTime(y, m, d) == DateTime(_today.year, _today.month, _today.day);
      final dayEvents = _events[key] ?? const [];
      cells.add(_buildDayCell(
        p: p, label: d.toString(), isOtherMonth: false, isToday: isToday, isSelected: key == _selectedKey,
        eventColors: dayEvents.map((e) => e.color).toList(),
        onTap: () => setState(() => _selectedKey = key),
      ));
    }
    final total = firstDay + daysInMonth;
    final rem = total % 7 == 0 ? 0 : 7 - total % 7;
    for (int d = 1; d <= rem; d++) {
      cells.add(_buildDayCell(p: p, label: d.toString(), isOtherMonth: true, isToday: false, isSelected: false, eventColors: const [], onTap: null));
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
      decoration: BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(32), border: Border.all(color: p.outline), boxShadow: p.cardShadow),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(color: p.previewBg, borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_months[m - 1]} $y', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.onSurface, letterSpacing: 0.2)),
                        Row(
                          children: [
                            _buildNavButton(p: p, icon: 'chevron_left', onTap: () => setState(() => _current = DateTime(_current.year, _current.month - 1, 1))),
                            const SizedBox(width: 8),
                            _buildNavButton(p: p, icon: 'chevron_right', onTap: () => setState(() => _current = DateTime(_current.year, _current.month + 1, 1))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(children: _weekdays.map((w) => Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.onSurfaceVariant, letterSpacing: 0.5))))).toList()),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(children: rows.map((row) => Expanded(child: Row(children: row.map((cell) => Expanded(child: cell)).toList()))).toList()),
                    ),
                  ),
                  if (selectedEvents.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: selectedEvents.first.color, shape: BoxShape.circle)),
                          Expanded(
                            child: Text(
                              selectedEvents.length == 1 ? selectedEvents.first.name : '${selectedEvents.first.name} +${selectedEvents.length - 1}',
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
            decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(50)),
            child: GestureDetector(
              onTap: _openNewEventScreen,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(50)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('add', size: 14, color: p.onPrimary),
                    const SizedBox(width: 7),
                    Text('Novo evento', style: TextStyle(color: p.onPrimary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1)),
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
      child: Container(width: 28, height: 28, decoration: BoxDecoration(color: p.navBtnBg, shape: BoxShape.circle), child: AppIcon(icon, size: 12, color: p.onSurfaceVariant)),
    );
  }

  Widget _buildDayCell({required _WidgetPalette p, required String label, required bool isOtherMonth, required bool isToday, required bool isSelected, required List<Color> eventColors, required VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24, alignment: Alignment.center,
            decoration: BoxDecoration(color: isToday ? p.primary : isSelected ? p.optionBg : Colors.transparent, shape: BoxShape.circle),
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isToday || eventColors.isNotEmpty ? FontWeight.w700 : FontWeight.w500, color: isToday ? p.onPrimary : isOtherMonth ? p.onSurfaceVariant.withOpacity(0.5) : p.onSurface)),
          ),
          if (eventColors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(children: eventColors.take(2).map((c) => Container(width: 4, height: 4, margin: const EdgeInsets.only(bottom: 1), decoration: BoxDecoration(color: c, shape: BoxShape.circle))).toList()),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — NOVO EVENTO (inputs organizados)
// ══════════════════════════════════════════════════════════════
class _NewEventScreen extends StatefulWidget {
  final AppColorScheme s;
  final String dateKey;
  const _NewEventScreen({required this.s, required this.dateKey});
  @override State<_NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends State<_NewEventScreen> {
  final _nameCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final List<Color> _palette = const [
    Color(0xFF6F5AF6), Color(0xFF4EC994), Color(0xFFE05E5E),
    Color(0xFFE0A63E), Color(0xFF4F9FDC), Color(0xFFD062C4),
  ];
  late Color _selectedColor;

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _selectedColor = _palette.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final colorHex = '#${_selectedColor.value.toRadixString(16).substring(2)}';
    Navigator.of(context).pop((
      name: _nameCtrl.text.trim(),
      time: _timeCtrl.text.trim(),
      color: colorHex,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return CupertinoPageScaffold(
      backgroundColor: p.pageBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.pageBg,
        border: null,
        middle: Text('Novo evento', style: TextStyle(color: p.onSurface, fontWeight: FontWeight.w700)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.dateKey, style: TextStyle(color: p.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),

              _FieldLabel(p: p, text: 'Nome do evento'),
              const SizedBox(height: 6),
              _StyledField(p: p, controller: _nameCtrl, hint: 'Ex: Reunião com equipa'),

              const SizedBox(height: 18),
              _FieldLabel(p: p, text: 'Hora'),
              const SizedBox(height: 6),
              _StyledField(p: p, controller: _timeCtrl, hint: 'Ex: 14:00', keyboardType: TextInputType.datetime),

              const SizedBox(height: 18),
              _FieldLabel(p: p, text: 'Cor'),
              const SizedBox(height: 10),
              Row(
                children: _palette.map((c) {
                  final active = c.value == _selectedColor.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 34, height: 34,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: active ? Border.all(color: p.onSurface, width: 2.5) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),
              GestureDetector(
                onTap: _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('Adicionar evento', style: TextStyle(color: p.onPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final _WidgetPalette p;
  final String text;
  const _FieldLabel({required this.p, required this.text});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600));
}

class _StyledField extends StatelessWidget {
  final _WidgetPalette p;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  const _StyledField({required this.p, required this.controller, required this.hint, this.keyboardType});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: p.optionBg, borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: p.onSurface, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.onSurfaceVariant),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MAP WIDGET — CARD SIMPLIFICADO (sem badge, sem recentrar, sem
// switch 3D, sem pesquisa; só o mapa + botão longo de local +
// popup menu de camadas)
// ══════════════════════════════════════════════════════════════
enum _MapLayer { standard, satellite, streets, dark, terrain, googleMaps }

class AiMapWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMapWidget({super.key, required this.json, required this.s});
  @override State<AiMapWidget> createState() => _AiMapWidgetState();
}

class _AiMapWidgetState extends State<AiMapWidget> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late double _lat;
  late double _lng;
  late double _zoom;
  late String _name;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  _MapLayer _layer = _MapLayer.satellite;

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _lat = (widget.json['lat'] is num) ? (widget.json['lat'] as num).toDouble() : 38.7223;
    _lng = (widget.json['lng'] is num) ? (widget.json['lng'] as num).toDouble() : -9.1393;
    _zoom = (widget.json['zoom'] is num) ? (widget.json['zoom'] as num).toDouble() : 13.0;
    _name = _sanitizeText(widget.json['name']);
    if (_name.isEmpty) _name = 'Lisboa, Portugal';

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.4).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _tileUrl {
    switch (_layer) {
      case _MapLayer.standard:
      case _MapLayer.googleMaps: // fallback de tiles enquanto não há chave do Google Maps SDK nativo
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
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
      case _MapLayer.satellite: return const [];
      case _MapLayer.dark: return const ['a', 'b', 'c', 'd'];
      default: return const ['a', 'b', 'c'];
    }
  }

  String get _layerLabel {
    switch (_layer) {
      case _MapLayer.standard: return 'Padrão';
      case _MapLayer.satellite: return 'Satélite';
      case _MapLayer.streets: return 'Ruas';
      case _MapLayer.dark: return 'Escuro';
      case _MapLayer.terrain: return 'Terreno';
      case _MapLayer.googleMaps: return 'Google Maps';
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<({String name, double lat, double lng})>(
      CupertinoPageRoute(builder: (_) => _LocationPickerScreen(s: widget.s)),
    );
    if (result != null) {
      setState(() {
        _lat = result.lat;
        _lng = result.lng;
        _name = result.name;
        _zoom = 12.0;
      });
      _mapController.move(ll.LatLng(_lat, _lng), _zoom);
    }
  }

  void _openLayersPopup(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final p = _p;
    final selected = await showMenu<_MapLayer>(
      context: buttonContext,
      position: position,
      color: p.optionBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        _buildMenuItem(p, _MapLayer.standard, 'road', 'Padrão'),
        _buildMenuItem(p, _MapLayer.satellite, 'satellite', 'Satélite'),
        _buildMenuItem(p, _MapLayer.streets, 'road', 'Ruas'),
        _buildMenuItem(p, _MapLayer.dark, 'moon', 'Escuro'),
        _buildMenuItem(p, _MapLayer.terrain, 'mountain', 'Terreno'),
        const PopupMenuDivider(height: 12),
        _buildMenuItem(p, _MapLayer.googleMaps, 'map', 'Google Maps'),
      ],
    );

    if (selected != null) setState(() => _layer = selected);
  }

  PopupMenuItem<_MapLayer> _buildMenuItem(_WidgetPalette p, _MapLayer value, String icon, String label) {
    final active = _layer == value;
    return PopupMenuItem<_MapLayer>(
      value: value,
      height: 42,
      child: Row(
        children: [
          AppIcon(icon, size: 15, color: active ? p.primary : p.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: active ? p.primary : p.onSurface, fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          if (active) ...[const Spacer(), AppIcon('check', size: 14, color: p.primary)],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(32), border: Border.all(color: p.outline), boxShadow: p.cardShadow),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(color: p.previewBg, borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: ll.LatLng(_lat, _lng),
                      initialZoom: _zoom,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                      TileLayer(urlTemplate: _tileUrl, userAgentPackageName: 'com.nexa.app', subdomains: _tileSubdomains),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: ll.LatLng(_lat, _lng),
                            width: 36, height: 36,
                            child: _PulsingMapMarker(animation: _pulseAnim, color: p.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Chip discreto com a camada ativa (mantido apenas como
                  // indicador passivo, sem botões extra sobre o mapa).
                  Positioned(
                    top: 10, right: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: p.badgeBg, borderRadius: BorderRadius.circular(10)),
                        child: Text(_layerLabel, style: TextStyle(color: p.onSurfaceVariant, fontSize: 9.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Ações: botão longo de local + botão circular de camadas ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(50)),
                  child: GestureDetector(
                    onTap: _openLocationPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(50)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon('location', color: p.onPrimary, size: 15),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(color: p.onPrimary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (btnContext) => Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(50)),
                  child: GestureDetector(
                    onTap: () => _openLayersPopup(btnContext),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: p.navBtnBg, shape: BoxShape.circle),
                      child: AppIcon('layers', color: p.onSurface, size: 17),
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

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — SELETOR DE LOCALIZAÇÃO (países A-Z → províncias)
// Sem cards: apenas nome + seta, com search input fixo em baixo.
// ══════════════════════════════════════════════════════════════
class _LocationPickerScreen extends StatefulWidget {
  final AppColorScheme s;
  const _LocationPickerScreen({required this.s});
  @override State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loadingCountries = true;
  List<String> _countries = [];
  String? _error;

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() { _loadingCountries = true; _error = null; });
    try {
      final list = await _GeoCache.getCountries();
      if (mounted) setState(() { _countries = list; _loadingCountries = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Não foi possível carregar países.'; _loadingCountries = false; });
    }
  }

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _countries;
    return _countries.where((c) => c.toLowerCase().contains(q)).toList();
  }

  void _openCountry(String country) async {
    final result = await Navigator.of(context).push<({String name, double lat, double lng})>(
      CupertinoPageRoute(builder: (_) => _StatePickerScreen(s: widget.s, country: country)),
    );
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final items = _filtered;

    return CupertinoPageScaffold(
      backgroundColor: p.pageBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.pageBg,
        border: null,
        middle: Text('Escolher país', style: TextStyle(color: p.onSurface, fontWeight: FontWeight.w700)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loadingCountries
                  ? Center(child: CupertinoActivityIndicator(color: p.onSurfaceVariant))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: TextStyle(color: p.onSurfaceVariant, fontSize: 14)),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _loadCountries,
                                child: Text('Tentar novamente', style: TextStyle(color: p.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        )
                      : items.isEmpty
                          ? Center(child: Text('Sem resultados', style: TextStyle(color: p.onSurfaceVariant, fontSize: 14)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: items.length,
                              itemBuilder: (_, i) => _PlainNavRow(
                                p: p,
                                label: items[i],
                                onTap: () => _openCountry(items[i]),
                              ),
                            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  children: [
                    AppIcon('search', color: p.onSurfaceVariant, size: 17),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(color: p.onSurface, fontSize: 14),
                        cursorColor: p.primary,
                        decoration: InputDecoration(
                          isDense: true, border: InputBorder.none,
                          hintText: 'Procurar país…',
                          hintStyle: TextStyle(color: p.onSurfaceVariant, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatePickerScreen extends StatefulWidget {
  final AppColorScheme s;
  final String country;
  const _StatePickerScreen({required this.s, required this.country});
  @override State<_StatePickerScreen> createState() => _StatePickerScreenState();
}

class _StatePickerScreenState extends State<_StatePickerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  List<String> _states = [];
  String? _error;

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _GeoCache.getStates(widget.country);
      if (mounted) setState(() { _states = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Não foi possível carregar as regiões.'; _loading = false; });
    }
  }

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _states;
    return _states.where((s) => s.toLowerCase().contains(q)).toList();
  }

  void _selectState(String stateName) async {
    // Geocodifica "Estado, País" via Nominatim para obter lat/lng reais.
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent('$stateName, ${widget.country}')}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final list = jsonDecode(res.body) as List;
      if (list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final lat = double.parse(first['lat'].toString());
        final lng = double.parse(first['lon'].toString());
        if (mounted) Navigator.of(context).pop((name: '$stateName, ${widget.country}', lat: lat, lng: lng));
        return;
      }
    } catch (_) {
      // segue para o fallback abaixo
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível localizar esta região.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final items = _filtered;

    return CupertinoPageScaffold(
      backgroundColor: p.pageBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.pageBg,
        border: null,
        middle: Text(widget.country, style: TextStyle(color: p.onSurface, fontWeight: FontWeight.w700)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? Center(child: CupertinoActivityIndicator(color: p.onSurfaceVariant))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: TextStyle(color: p.onSurfaceVariant, fontSize: 14)),
                              const SizedBox(height: 10),
                              GestureDetector(onTap: _load, child: Text('Tentar novamente', style: TextStyle(color: p.primary, fontSize: 14, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        )
                      : items.isEmpty
                          ? Center(child: Text('Sem regiões disponíveis', style: TextStyle(color: p.onSurfaceVariant, fontSize: 14)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: items.length,
                              itemBuilder: (_, i) => _PlainNavRow(p: p, label: items[i], showArrow: false, onTap: () => _selectState(items[i])),
                            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  children: [
                    AppIcon('search', color: p.onSurfaceVariant, size: 17),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(color: p.onSurface, fontSize: 14),
                        cursorColor: p.primary,
                        decoration: InputDecoration(
                          isDense: true, border: InputBorder.none,
                          hintText: 'Procurar região…',
                          hintStyle: TextStyle(color: p.onSurfaceVariant, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlainNavRow extends StatelessWidget {
  final _WidgetPalette p;
  final String label;
  final bool showArrow;
  final VoidCallback onTap;
  const _PlainNavRow({required this.p, required this.label, required this.onTap, this.showArrow = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: p.onSurface, fontSize: 15, fontWeight: FontWeight.w500))),
            if (showArrow) AppIcon('chevron_right', size: 14, color: p.onSurfaceVariant),
          ],
        ),
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
          width: 36, height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(scale: ringScale, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: color.withOpacity(0.35), shape: BoxShape.circle))),
              Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
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
            return Transform.scale(scale: scale, child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)));
          }),
        ),
      ),
    );
  }
}