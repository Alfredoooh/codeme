// ══════════════════════════════════════════════════════════════
// FILE: lib/features/ai_widgets/market_widget.dart
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import 'ai_widgets_shared.dart';

// ══════════════════════════════════════════════════════════════
// CACHE PERSISTENTE DE ÍCONES DE CRIPTOMOEDAS
// ══════════════════════════════════════════════════════════════
class _CryptoIconCache {
  static const _kPrefix = 'aiwidgets_crypto_icon_v1_';
  static final Map<String, String?> _mem = {};

  static Future<String?> getIconUrl(String coingeckoId) async {
    if (_mem.containsKey(coingeckoId)) return _mem[coingeckoId];
    final key = '$_kPrefix$coingeckoId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(key);
      if (cached != null && cached.isNotEmpty) {
        _mem[coingeckoId] = cached;
        return cached;
      }
    } catch (_) {}

    try {
      final uri = Uri.parse('https://api.coingecko.com/api/v3/coins/$coingeckoId?localization=false&tickers=false&market_data=false&community_data=false&developer_data=false');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final image = decoded['image'] as Map<String, dynamic>?;
        final url = image?['small'] as String? ?? image?['thumb'] as String?;
        if (url != null) {
          _mem[coingeckoId] = url;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(key, url);
          } catch (_) {}
          return url;
        }
      }
    } catch (_) {}

    _mem[coingeckoId] = null;
    return null;
  }
}

// ══════════════════════════════════════════════════════════════
// MERCADO — DADOS DE PARES
// ══════════════════════════════════════════════════════════════
// A lista de pares abaixo deixou de ser a fonte de verdade para o
// que o widget pode mostrar — é apenas usada para os atalhos do
// _MarketSelectorScreen (navegação manual). O widget principal
// (AiMarketWidget) constrói o par a partir do JSON já resolvido
// que a IA escreveu no bloco, que por sua vez veio do resultado
// real de resolveMarketQuery — por isso já não está limitado a
// esta lista fixa nem cai sempre em Bitcoin por omissão.
class _MarketPair {
  final String key;
  final String label;
  final String sub;
  final String badge;
  final String? coingeckoId;
  final String? fiatCountryCode;
  final String? frankfurterCode;
  const _MarketPair({
    required this.key,
    required this.label,
    required this.sub,
    required this.badge,
    this.coingeckoId,
    this.fiatCountryCode,
    this.frankfurterCode,
  });
}

const List<_MarketPair> _kMarketPairs = [
  _MarketPair(key: 'BTCUSD', label: 'BTC/USD', sub: 'Bitcoin', badge: 'cripto', coingeckoId: 'bitcoin'),
  _MarketPair(key: 'ETHUSD', label: 'ETH/USD', sub: 'Ethereum', badge: 'cripto', coingeckoId: 'ethereum'),
  _MarketPair(key: 'SOLUSD', label: 'SOL/USD', sub: 'Solana', badge: 'cripto', coingeckoId: 'solana'),
  _MarketPair(key: 'BNBUSD', label: 'BNB/USD', sub: 'BNB', badge: 'cripto', coingeckoId: 'binancecoin'),
  _MarketPair(key: 'XRPUSD', label: 'XRP/USD', sub: 'XRP', badge: 'cripto', coingeckoId: 'ripple'),
  _MarketPair(key: 'ADAUSD', label: 'ADA/USD', sub: 'Cardano', badge: 'cripto', coingeckoId: 'cardano'),
  _MarketPair(key: 'DOGEUSD', label: 'DOGE/USD', sub: 'Dogecoin', badge: 'cripto', coingeckoId: 'dogecoin'),
  _MarketPair(key: 'EURUSD', label: 'EUR/USD', sub: 'Euro / Dólar', badge: 'forex', fiatCountryCode: 'eu', frankfurterCode: 'EUR'),
  _MarketPair(key: 'GBPUSD', label: 'GBP/USD', sub: 'Libra / Dólar', badge: 'forex', fiatCountryCode: 'gb', frankfurterCode: 'GBP'),
  _MarketPair(key: 'USDJPY', label: 'USD/JPY', sub: 'Dólar / Iene', badge: 'forex', fiatCountryCode: 'jp', frankfurterCode: 'JPY'),
  _MarketPair(key: 'USDBRL', label: 'USD/BRL', sub: 'Dólar / Real', badge: 'forex', fiatCountryCode: 'br', frankfurterCode: 'BRL'),
  _MarketPair(key: 'USDCHF', label: 'USD/CHF', sub: 'Dólar / Franco', badge: 'forex', fiatCountryCode: 'ch', frankfurterCode: 'CHF'),
  _MarketPair(key: 'XAUUSD', label: 'XAU/USD', sub: 'Ouro', badge: 'metal', coingeckoId: 'tether-gold'),
  _MarketPair(key: 'XAGUSD', label: 'XAG/USD', sub: 'Prata', badge: 'metal', coingeckoId: 'silver-token'),
];

/// Constrói um _MarketPair dinâmico a partir do JSON resolvido pela
/// IA (que veio do resultado real de resolveMarketQuery), em vez de
/// depender exclusivamente da lista fixa _kMarketPairs. Cai na lista
/// fixa apenas se o JSON não trouxer dados suficientes, como último
/// recurso de compatibilidade com blocos antigos.
_MarketPair _pairFromWidgetJson(Map<String, dynamic> json) {
  final type = json['type']?.toString();
  final symbol = json['symbol']?.toString();
  final name = json['name']?.toString();
  final coingeckoId = json['coingeckoId']?.toString();

  if (type == 'crypto' && symbol != null && symbol.isNotEmpty) {
    return _MarketPair(
      key: '${symbol.toUpperCase()}USD',
      label: '${symbol.toUpperCase()}/USD',
      sub: name ?? symbol.toUpperCase(),
      badge: 'cripto',
      coingeckoId: coingeckoId,
    );
  }
  if (type == 'forex' && symbol != null && symbol.isNotEmpty) {
    if (symbol.contains('/')) {
      final parts = symbol.split('/');
      return _MarketPair(
        key: symbol.replaceAll('/', ''),
        label: symbol,
        sub: name ?? symbol,
        badge: 'forex',
        frankfurterCode: parts.length == 2 ? parts[1] : parts.first,
      );
    }
    return _MarketPair(
      key: '${symbol}USD',
      label: '$symbol/USD',
      sub: name ?? symbol,
      badge: 'forex',
      frankfurterCode: symbol,
    );
  }

  // Compatibilidade com blocos antigos (symbol solto sem type) —
  // procura na lista fixa antes de desistir.
  if (symbol != null) {
    final match = _kMarketPairs.where((p) => p.key == symbol || p.coingeckoId == coingeckoId);
    if (match.isNotEmpty) return match.first;
  }

  return _kMarketPairs.first;
}

class _MarketDataPoint {
  final double t;
  final double v;
  const _MarketDataPoint(this.t, this.v);
}

String _formatPairPrice(double v, _MarketPair pair) {
  if (pair.badge == 'forex') return v.toStringAsFixed(4);
  if (v >= 1000) return '\$${v.toStringAsFixed(0)}';
  if (v >= 1) return '\$${v.toStringAsFixed(2)}';
  return '\$${v.toStringAsFixed(4)}';
}

// ══════════════════════════════════════════════════════════════
// SERVIÇO DE DADOS REAIS DE MERCADO
// ══════════════════════════════════════════════════════════════
class MarketDataService {
  static final Map<String, ({DateTime fetchedAt, List<_MarketDataPoint> data})> _cache = {};
  static const _cacheTtl = Duration(seconds: 60);

  static int _daysForTf(String tf) {
    switch (tf) {
      case '1D': return 1;
      case '1W': return 7;
      case '1M': return 30;
      case '1Y': return 365;
      default: return 1;
    }
  }

  static Future<List<_MarketDataPoint>> getSeries(_MarketPair pair, String tf) async {
    final cacheKey = '${pair.key}_$tf';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.data;
    }

    List<_MarketDataPoint> result;
    if (pair.coingeckoId != null) {
      result = await _fetchCryptoSeries(pair.coingeckoId!, tf);
    } else if (pair.frankfurterCode != null) {
      result = await _fetchForexSeries(pair, tf);
    } else {
      throw Exception('Par sem fonte de dados configurada: ${pair.key}');
    }

    _cache[cacheKey] = (fetchedAt: DateTime.now(), data: result);
    return result;
  }

  static Future<List<_MarketDataPoint>> _fetchCryptoSeries(String coingeckoId, String tf) async {
    final days = _daysForTf(tf);
    final uri = Uri.parse('https://api.coingecko.com/api/v3/coins/$coingeckoId/market_chart?vs_currency=usd&days=$days');
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode == 429) {
      throw Exception('Limite de pedidos da CoinGecko atingido. Tenta novamente em instantes.');
    }
    if (res.statusCode != 200) {
      throw Exception('Falha ao obter dados de mercado (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final prices = (decoded['prices'] as List? ?? []);
    if (prices.isEmpty) throw Exception('Sem dados disponíveis para este par.');
    return prices.map((e) {
      final pair = e as List;
      return _MarketDataPoint((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
    }).toList();
  }

  static Future<List<_MarketDataPoint>> _fetchForexSeries(_MarketPair pair, String tf) async {
    final days = _daysForTf(tf);
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    final fmt = (DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final base = pair.key.startsWith('USD') ? 'USD' : 'USD';
    final target = pair.frankfurterCode!;
    final uri = Uri.parse('https://api.frankfurter.app/${fmt(start)}..${fmt(end)}?from=$base&to=$target');
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Falha ao obter dados de câmbio (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rates = (decoded['rates'] as Map<String, dynamic>? ?? {});
    if (rates.isEmpty) throw Exception('Sem dados de câmbio disponíveis.');
    final entries = rates.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) {
      final date = DateTime.parse(e.key);
      final rateMap = e.value as Map<String, dynamic>;
      final rate = (rateMap[target] as num?)?.toDouble() ?? 0.0;
      return _MarketDataPoint(date.millisecondsSinceEpoch.toDouble(), rate);
    }).toList();
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL — CARD DE MERCADO
// ══════════════════════════════════════════════════════════════
class AiMarketWidget extends StatefulWidget {
  final Map<String, dynamic> json;
  final AppColorScheme s;
  const AiMarketWidget({super.key, required this.json, required this.s});
  @override
  State<AiMarketWidget> createState() => _AiMarketWidgetState();
}

class _AiMarketWidgetState extends State<AiMarketWidget> with SingleTickerProviderStateMixin {
  late _MarketPair _currentPair;
  bool _found = true;
  bool _loading = true;
  String? _error;
  String _timeframe = '1D';
  List<_MarketDataPoint> _series = [];
  String? _iconUrl;

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    final json = widget.json;
    _found = json['found'] != false;
    if (_found) {
      _currentPair = _pairFromWidgetJson(json);
      _loadIcon();
      _load();
    }
  }

  void _loadIcon() {
    if (_currentPair.coingeckoId != null) {
      _CryptoIconCache.getIconUrl(_currentPair.coingeckoId!).then((url) {
        if (mounted) setState(() => _iconUrl = url);
      });
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await MarketDataService.getSeries(_currentPair, _timeframe);
      if (mounted) setState(() { _series = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _openMarketSelector() async {
    final result = await Navigator.of(context).push<_MarketPair>(
      AppPageRoute(
        builder: (_) => _MarketSelectorScreen(s: widget.s, currentKey: _currentPair.key),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _currentPair = result;
        _iconUrl = null;
      });
      _loadIcon();
      _load();
    }
  }

  void _changeTimeframe(String tf) {
    if (tf == _timeframe) return;
    setState(() => _timeframe = tf);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;

    if (!_found) {
      return _MarketNotFoundCard(p: p, onOpenSelector: _openMarketSelector);
    }

    final pair = _currentPair;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _openMarketSelector,
            child: Row(
              children: [
                SizedBox(
                  width: 34, height: 34,
                  child: pair.badge == 'forex' && pair.fiatCountryCode != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            'https://flagcdn.com/w80/${pair.fiatCountryCode}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.optionBg, borderRadius: BorderRadius.circular(10))),
                          ),
                        )
                      : _iconUrl != null
                          ? ClipOval(
                              child: Image.network(
                                _iconUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle)),
                              ),
                            )
                          : Container(decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pair.label, style: TextStyle(color: p.onSurface, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(pair.sub, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                AppIcon('chevron_down', color: p.onSurfaceVariant, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: _loading
                ? Center(child: AiSmallDotsLoader(color: p.onSurfaceVariant))
                : _error != null
                    ? Center(
                        child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12)),
                      )
                    : _buildChart(p),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1D', '1W', '1M', '1Y'].map((tf) {
              final active = tf == _timeframe;
              return GestureDetector(
                onTap: () => _changeTimeframe(tf),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? p.primary.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(tf, style: TextStyle(color: active ? p.primary : p.onSurfaceVariant, fontSize: 12.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(WidgetPalette p) {
    if (_series.length < 2) {
      return Center(child: Text('Sem dados suficientes.', style: TextStyle(color: p.onSurfaceVariant, fontSize: 12)));
    }
    final values = _series.map((e) => e.v).toList();
    final first = values.first;
    final last = values.last;
    final isUp = last >= first;
    final color = isUp ? const Color(0xFF4EC994) : const Color(0xFFE05E5E);

    return CustomPaint(
      size: Size.infinite,
      painter: _MarketChartPainter(
        points: _series,
        color: color,
      ),
    );
  }
}

class _MarketNotFoundCard extends StatelessWidget {
  final WidgetPalette p;
  final VoidCallback onOpenSelector;
  const _MarketNotFoundCard({required this.p, required this.onOpenSelector});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(24), boxShadow: p.cardShadow),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('search_off', color: p.onSurfaceVariant, size: 28),
          const SizedBox(height: 10),
          Text('Ativo não encontrado', style: TextStyle(color: p.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Escolhe um ativo para acompanhar.', textAlign: TextAlign.center, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onOpenSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Escolher ativo', style: TextStyle(color: p.onPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketChartPainter extends CustomPainter {
  final List<_MarketDataPoint> points;
  final Color color;
  _MarketChartPainter({
    required this.points,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((e) => e.v).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final normalized = (points[i].v - minV) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter oldDelegate) => oldDelegate.points != points;
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
  final _searchCtrl = TextEditingController();
  List<_MarketPair> _results = [];
  bool _searching = false;
  Timer? _debounce;

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _results = _kMarketPairs;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _results = _kMarketPairs; _searching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(query.trim()));
  }

  Future<void> _doSearch(String query) async {
    setState(() => _searching = true);
    try {
      final uri = Uri.parse('https://api.coingecko.com/api/v3/search?query=${Uri.encodeComponent(query)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      final results = <_MarketPair>[];
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final coins = (decoded['coins'] as List? ?? []).take(20);
        for (final c in coins) {
          final coin = c as Map<String, dynamic>;
          final id = coin['id']?.toString();
          final symbol = (coin['symbol']?.toString() ?? '').toUpperCase();
          final name = coin['name']?.toString();
          if (id != null && symbol.isNotEmpty && name != null) {
            results.add(_MarketPair(key: '${symbol}USD', label: '$symbol/USD', sub: name, badge: 'cripto', coingeckoId: id));
          }
        }
      }
      // também filtra localmente os forex/metais fixos
      final localMatches = _kMarketPairs.where((p) =>
          p.label.toLowerCase().contains(query.toLowerCase()) ||
          p.sub.toLowerCase().contains(query.toLowerCase()));
      if (mounted) {
        setState(() {
          _results = [...localMatches, ...results];
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: 'Mercado', onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Column(
          children: [
            AiSearchBar(
              p: p,
              controller: _searchCtrl,
              hint: 'Pesquisar ativo...',
              onChanged: _onSearchChanged,
              onClear: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              },
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _searching
                  ? Center(child: AiSmallDotsLoader(color: p.onSurfaceVariant))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final pair = _results[i];
                        return _MarketPairRow(
                          s: widget.s,
                          pair: pair,
                          active: pair.key == widget.currentKey,
                          onTap: () async {
                            final selected = await Navigator.of(context).push<bool>(
                              AppPageRoute(builder: (_) => _MarketPairDetailScreen(s: widget.s, pair: pair)),
                            );
                            if (selected == true && context.mounted) {
                              Navigator.of(context).pop(pair);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketPairRow extends StatefulWidget {
  final AppColorScheme s;
  final _MarketPair pair;
  final bool active;
  final VoidCallback onTap;
  const _MarketPairRow({required this.s, required this.pair, required this.active, required this.onTap});
  @override State<_MarketPairRow> createState() => _MarketPairRowState();
}

class _MarketPairRowState extends State<_MarketPairRow> {
  bool _pressed = false;
  String? _iconUrl;

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    if (widget.pair.coingeckoId != null) {
      _CryptoIconCache.getIconUrl(widget.pair.coingeckoId!).then((url) {
        if (mounted) setState(() => _iconUrl = url);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final pair = widget.pair;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed ? p.optionBgHover : p.optionBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30, height: 30,
              child: pair.badge == 'forex' && pair.fiatCountryCode != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        'https://flagcdn.com/w80/${pair.fiatCountryCode}.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(9))),
                      ),
                    )
                  : _iconUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _iconUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.cardBg, shape: BoxShape.circle)),
                          ),
                        )
                      : Container(decoration: BoxDecoration(color: p.cardBg, shape: BoxShape.circle)),
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
            if (widget.active) AppIcon('check', color: p.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — DETALHE DO PAR
// ══════════════════════════════════════════════════════════════
class _MarketPairDetailScreen extends StatefulWidget {
  final AppColorScheme s;
  final _MarketPair pair;
  const _MarketPairDetailScreen({required this.s, required this.pair});
  @override State<_MarketPairDetailScreen> createState() => _MarketPairDetailScreenState();
}

class _MarketPairDetailScreenState extends State<_MarketPairDetailScreen> {
  bool _loading = true;
  String? _error;
  List<_MarketDataPoint> _series = [];
  String? _iconUrl;

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    if (widget.pair.coingeckoId != null) {
      _CryptoIconCache.getIconUrl(widget.pair.coingeckoId!).then((url) {
        if (mounted) setState(() => _iconUrl = url);
      });
    }
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await MarketDataService.getSeries(widget.pair, '1D');
      if (mounted) setState(() { _series = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final pair = widget.pair;

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: pair.label, onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: _buildBody(p, pair))),
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

  Widget _buildBody(WidgetPalette p, _MarketPair pair) {
    if (_loading) return AiSmallDotsLoader(color: p.onSurfaceVariant);
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 10),
          GestureDetector(onTap: _load, child: Text('Tentar novamente', style: TextStyle(color: p.primary, fontSize: 13, fontWeight: FontWeight.w700))),
        ],
      );
    }

    final series = _series;
    final first = series.first.v;
    final last = series.last.v;
    final change = first == 0 ? 0.0 : ((last - first) / first) * 100;
    final isUp = last >= first;
    final color = isUp ? const Color(0xFF4EC994) : const Color(0xFFE05E5E);
    final values = series.map((e) => e.v).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96, height: 96,
          child: pair.badge == 'forex' && pair.fiatCountryCode != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    'https://flagcdn.com/w320/${pair.fiatCountryCode}.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.optionBg, borderRadius: BorderRadius.circular(18))),
                  ),
                )
              : _iconUrl != null
                  ? ClipOval(
                      child: Image.network(
                        _iconUrl!,
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
    );
  }
}

class _DetailStat extends StatelessWidget {
  final WidgetPalette p;
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