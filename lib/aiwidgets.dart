// ══════════════════════════════════════════════════════════════
//
// ATUALIZAÇÃO: os widgets deixam de receber JSON pronto (lat/lng,
// symbol, etc.) escrito pela IA. Em vez disso, a IA chama uma tool
// (search_market / search_place / search_calendar_date) com uma
// query em texto livre; o Flutter resolve essa query de verdade
// (CoinGecko, Frankfurter, Nominatim) e devolve o resultado à IA
// via mensagem role:"tool"; só depois a IA escreve o widget final
// já com o resultado resolvido dentro do JSON. Os construtores dos
// widgets abaixo continuam a receber um JSON no bloco — mas agora
// esse JSON já contém o resultado real da pesquisa (preenchido pela
// IA a partir do tool_result), não mais valores fixos/adivinhados.
//
// As três funções de resolução ficam expostas aqui como top-level
// (resolveMarketQuery / resolvePlaceQuery / resolveCalendarDateQuery)
// para serem chamadas por aitab.dart quando um ChatToolCallEvent
// chegar do stream.
//
// ATUALIZAÇÃO 2: passamos a importar kAllTools (todas as tools do
// servidor) em vez de apenas as 3 locais, para que a IA tenha acesso
// a todas as funções disponíveis (web_search, create_pdf, etc.).
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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
import 'api_service.dart' show ToolDefinition, kAllTools;

// ══════════════════════════════════════════════════════════════
// NOTA — GOOGLE MAPS SEM API KEY
// ══════════════════════════════════════════════════════════════
// Sem key do Google Cloud configurada nativamente (AndroidManifest.xml /
// Info.plist), não dá pra embutir o SDK real do Google Maps dentro da app.
// A opção "Google Maps" no popup de camadas abre a app/site do Google Maps
// via launchUrl — é o Google Maps a sério, só que como app externa, não
// embutida no card. Quando/se decidires obter a key, o ponto a mudar é a
// função _openInGoogleMaps() mais abaixo.

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
// TOOL DEFINITIONS — expostas para aitab.dart montar a lista
// `tools` do streamChat. Agora incluem todas as tools do servidor.
// ══════════════════════════════════════════════════════════════

const ToolDefinition kSearchMarketTool = ToolDefinition(
  name: 'search_market',
  description:
      'Pesquisa dados reais e atuais de um ativo financeiro (criptomoeda '
      'por nome ou símbolo, ex: "bitcoin", "ETH"; ou câmbio de moeda por '
      'código ISO, ex: "EUR", "USD/JPY"). Devolve preço, variação e série '
      'histórica reais. Usa esta função sempre que precisares de mostrar '
      'cotações de mercado ao utilizador — nunca inventes valores.',
  parameters: {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description':
            'Nome, símbolo ou código do ativo a pesquisar, tal como o '
            'utilizador o mencionou (ex: "bitcoin", "SOL", "EUR", "libra").',
      },
    },
    'required': ['query'],
  },
);

const ToolDefinition kSearchPlaceTool = ToolDefinition(
  name: 'search_place',
  description:
      'Pesquisa a localização real (coordenadas e nome formal) de um '
      'lugar — cidade, morada, ponto de interesse, país, região. Devolve '
      'latitude, longitude e o nome completo do lugar encontrado. Usa '
      'esta função sempre que precisares de mostrar um mapa ou localizar '
      'algo ao utilizador — nunca inventes coordenadas.',
  parameters: {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description':
            'Nome do lugar a pesquisar, tal como o utilizador o mencionou '
            '(ex: "Lisboa", "Torre Eiffel", "Maputo, Moçambique").',
      },
    },
    'required': ['query'],
  },
);

const ToolDefinition kSearchCalendarDateTool = ToolDefinition(
  name: 'search_calendar_date',
  description:
      'Resolve uma referência de data em linguagem natural (ex: '
      '"próxima sexta-feira", "daqui a duas semanas", "15 de setembro") '
      'para uma data absoluta no formato ISO (YYYY-MM-DD), usando a data '
      'atual do dispositivo como referência. Usa esta função sempre que '
      'precisares de agendar um evento a partir de uma data relativa.',
  parameters: {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description':
            'A referência de data em linguagem natural, tal como o '
            'utilizador a escreveu.',
      },
    },
    'required': ['query'],
  },
);

// kAllTools já contém as 3 acima + web_search, create_pdf, etc.
const List<ToolDefinition> kAiWidgetTools = kAllTools;

// ══════════════════════════════════════════════════════════════
// RESOLUÇÃO REAL — chamadas de rede que respondem às tool calls.
// Sem fallback cruzado: se a query não bater com a fonte certa,
// devolve notFound explicitamente em vez de tentar adivinhar
// noutra fonte (ex: "tesla" nunca cai para uma moeda TSLA lixo
// só porque existe uma no CoinGecko).
// ══════════════════════════════════════════════════════════════

class MarketResolveResult {
  final bool found;
  final String? type; // "crypto" | "forex"
  final String? symbol;
  final String? name;
  final String? coingeckoId;
  final String? notFoundReason;
  const MarketResolveResult._({
    required this.found,
    this.type,
    this.symbol,
    this.name,
    this.coingeckoId,
    this.notFoundReason,
  });

  factory MarketResolveResult.crypto({
    required String symbol,
    required String name,
    required String coingeckoId,
  }) =>
      MarketResolveResult._(
        found: true,
        type: 'crypto',
        symbol: symbol,
        name: name,
        coingeckoId: coingeckoId,
      );

  factory MarketResolveResult.forex({required String symbol, required String name}) =>
      MarketResolveResult._(found: true, type: 'forex', symbol: symbol, name: name);

  factory MarketResolveResult.notFound(String query) => MarketResolveResult._(
        found: false,
        notFoundReason: 'Não foi encontrado nenhum ativo (cripto ou câmbio) para "$query".',
      );

  Map<String, dynamic> toToolResultJson() => found
      ? {
          'found': true,
          'type': type,
          'symbol': symbol,
          'name': name,
          if (coingeckoId != null) 'coingeckoId': coingeckoId,
        }
      : {'found': false, 'reason': notFoundReason};
}

const Map<String, String> _kForexCodeNames = {
  'EUR': 'Euro',
  'USD': 'Dólar americano',
  'GBP': 'Libra esterlina',
  'JPY': 'Iene japonês',
  'BRL': 'Real brasileiro',
  'CHF': 'Franco suíço',
  'CAD': 'Dólar canadiano',
  'AUD': 'Dólar australiano',
  'CNY': 'Yuan chinês',
  'INR': 'Rupia indiana',
  'MZN': 'Metical moçambicano',
  'AOA': 'Kwanza angolano',
  'CVE': 'Escudo cabo-verdiano',
};

/// Tenta resolver como código de câmbio ISO (3 letras, ou "XXX/YYY").
/// Só devolve resultado se a query bater literalmente com um código
/// conhecido — não adivinha por nome de país nem faz fuzzy matching.
String? _matchForexCode(String query) {
  final cleaned = query.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z/]'), '');
  if (cleaned.isEmpty) return null;
  if (cleaned.contains('/')) {
    final parts = cleaned.split('/');
    if (parts.length == 2 && _kForexCodeNames.containsKey(parts[0]) && _kForexCodeNames.containsKey(parts[1])) {
      return cleaned;
    }
    return null;
  }
  if (cleaned.length == 3 && _kForexCodeNames.containsKey(cleaned)) return cleaned;
  return null;
}

Future<MarketResolveResult> resolveMarketQuery(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return MarketResolveResult.notFound(query);

  // 1) CoinGecko — pesquisa por nome ou símbolo.
  try {
    final uri = Uri.parse('https://api.coingecko.com/api/v3/search?query=${Uri.encodeComponent(trimmed)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final coins = (decoded['coins'] as List? ?? []);
      if (coins.isNotEmpty) {
        final first = coins.first as Map<String, dynamic>;
        final id = first['id']?.toString();
        final symbol = (first['symbol']?.toString() ?? '').toUpperCase();
        final name = first['name']?.toString();
        if (id != null && id.isNotEmpty && symbol.isNotEmpty && name != null) {
          return MarketResolveResult.crypto(symbol: symbol, name: name, coingeckoId: id);
        }
      }
    }
  } catch (_) {}

  // 2) Frankfurter — só se a query bater literalmente com um código ISO.
  final forexCode = _matchForexCode(trimmed);
  if (forexCode != null) {
    if (forexCode.contains('/')) {
      return MarketResolveResult.forex(symbol: forexCode, name: forexCode);
    }
    final name = _kForexCodeNames[forexCode] ?? forexCode;
    return MarketResolveResult.forex(symbol: forexCode, name: name);
  }

  // Nada bateu — sem fallback cruzado, devolve explicitamente notFound.
  return MarketResolveResult.notFound(trimmed);
}

class PlaceResolveResult {
  final bool found;
  final String? name;
  final double? lat;
  final double? lng;
  final String? notFoundReason;
  const PlaceResolveResult._({required this.found, this.name, this.lat, this.lng, this.notFoundReason});

  factory PlaceResolveResult.found({required String name, required double lat, required double lng}) =>
      PlaceResolveResult._(found: true, name: name, lat: lat, lng: lng);

  factory PlaceResolveResult.notFound(String query) =>
      PlaceResolveResult._(found: false, notFoundReason: 'Não foi encontrado nenhum lugar para "$query".');

  Map<String, dynamic> toToolResultJson() =>
      found ? {'found': true, 'name': name, 'lat': lat, 'lng': lng} : {'found': false, 'reason': notFoundReason};
}

Future<PlaceResolveResult> resolvePlaceQuery(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return PlaceResolveResult.notFound(query);
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&limit=1'
      '&accept-language=pt&q=${Uri.encodeComponent(trimmed)}',
    );
    final res = await http.get(uri, headers: {'User-Agent': 'NexaApp/1.0'}).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      if (list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final lat = double.tryParse(first['lat']?.toString() ?? '');
        final lng = double.tryParse(first['lon']?.toString() ?? '');
        final name = first['display_name']?.toString();
        if (lat != null && lng != null && name != null) {
          return PlaceResolveResult.found(name: name, lat: lat, lng: lng);
        }
      }
    }
  } catch (_) {}
  return PlaceResolveResult.notFound(trimmed);
}

class CalendarDateResolveResult {
  final bool found;
  final String? isoDate; // YYYY-MM-DD
  final String? humanLabel;
  final String? notFoundReason;
  const CalendarDateResolveResult._({required this.found, this.isoDate, this.humanLabel, this.notFoundReason});

  factory CalendarDateResolveResult.found({required String isoDate, required String humanLabel}) =>
      CalendarDateResolveResult._(found: true, isoDate: isoDate, humanLabel: humanLabel);

  factory CalendarDateResolveResult.notFound(String query) => CalendarDateResolveResult._(
        found: false,
        notFoundReason: 'Não foi possível interpretar "$query" como uma data.',
      );

  Map<String, dynamic> toToolResultJson() => found
      ? {'found': true, 'isoDate': isoDate, 'humanLabel': humanLabel}
      : {'found': false, 'reason': notFoundReason};
}

const List<String> _kWeekdaysPt = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
const Map<String, int> _kMonthsPt = {
  'janeiro': 1, 'fevereiro': 2, 'março': 3, 'marco': 3, 'abril': 4,
  'maio': 5, 'junho': 6, 'julho': 7, 'agosto': 8, 'setembro': 9,
  'outubro': 10, 'novembro': 11, 'dezembro': 12,
};

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Resolução local, sem chamada de rede — datas relativas em PT-PT
/// resolvidas contra DateTime.now() do dispositivo.
Future<CalendarDateResolveResult> resolveCalendarDateQuery(String query) async {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return CalendarDateResolveResult.notFound(query);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (q.contains('hoje')) {
    return CalendarDateResolveResult.found(isoDate: _iso(today), humanLabel: 'hoje');
  }
  if (q.contains('amanhã') || q.contains('amanha')) {
    final d = today.add(const Duration(days: 1));
    return CalendarDateResolveResult.found(isoDate: _iso(d), humanLabel: 'amanhã');
  }
  if (q.contains('depois de amanhã') || q.contains('depois de amanha')) {
    final d = today.add(const Duration(days: 2));
    return CalendarDateResolveResult.found(isoDate: _iso(d), humanLabel: 'depois de amanhã');
  }

  // "daqui a N dias/semanas"
  final relMatch = RegExp(r'daqui a (\d+) (dia|dias|semana|semanas)').firstMatch(q);
  if (relMatch != null) {
    final n = int.tryParse(relMatch.group(1)!) ?? 0;
    final unit = relMatch.group(2)!;
    final days = unit.startsWith('semana') ? n * 7 : n;
    final d = today.add(Duration(days: days));
    return CalendarDateResolveResult.found(isoDate: _iso(d), humanLabel: query.trim());
  }

  // "próxima <dia da semana>" / "<dia da semana>"
  for (int i = 0; i < _kWeekdaysPt.length; i++) {
    if (q.contains(_kWeekdaysPt[i])) {
      final targetWeekday = i + 1; // 1=segunda ... 7=domingo (DateTime.weekday)
      var delta = targetWeekday - today.weekday;
      if (delta <= 0) delta += 7;
      final d = today.add(Duration(days: delta));
      return CalendarDateResolveResult.found(isoDate: _iso(d), humanLabel: query.trim());
    }
  }

  // "15 de setembro" / "15 setembro"
  final dayMonthMatch = RegExp(r'(\d{1,2})\s*(?:de\s*)?([a-zçã]+)').firstMatch(q);
  if (dayMonthMatch != null) {
    final day = int.tryParse(dayMonthMatch.group(1)!);
    final monthName = dayMonthMatch.group(2)!;
    final month = _kMonthsPt[monthName];
    if (day != null && month != null && day >= 1 && day <= 31) {
      var year = today.year;
      var candidate = DateTime(year, month, day);
      if (candidate.isBefore(today)) candidate = DateTime(year + 1, month, day);
      return CalendarDateResolveResult.found(isoDate: _iso(candidate), humanLabel: query.trim());
    }
  }

  // Já vem em ISO?
  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(q);
  if (isoMatch != null) {
    return CalendarDateResolveResult.found(isoDate: q, humanLabel: query.trim());
  }

  return CalendarDateResolveResult.notFound(query);
}

// ══════════════════════════════════════════════════════════════
// PALETA DEDICADA — APENAS DUAS CORES NO ESCURO, UMA NO CLARO
// ══════════════════════════════════════════════════════════════
class _WidgetPalette {
  final AppColorScheme s;
  const _WidgetPalette(this.s);

  bool get isDark => s.isDark;

  // Tema escuro: cardBg (fundo) e actionsBg (cartões)
  // Tema claro: cardBg (fundo dos cartões, mesma cor do settings)
  Color get cardBg => isDark ? const Color(0xFF1C1C1E) : s.cardBackground;
  Color get actionsBg => isDark ? const Color(0xFF2C2C2E) : s.cardBackground;

  // Para preview interno, usamos a mesma cor do actionsBg
  Color get previewBg => actionsBg;

  Color get navBtnBg => isDark ? const Color(0xFF2C2C2E) : s.hover;
  Color get badgeBg => isDark
      ? const Color(0xFF1C1C1E).withOpacity(0.92)
      : s.cardBackground.withOpacity(0.9);

  Color get optionBg => actionsBg;
  Color get optionBgHover => isDark ? const Color(0xFF3A3A3C) : s.hover;

  Color get outline => isDark ? Colors.white.withOpacity(0.08) : s.outline.withOpacity(0.15);

  Color get onSurface => s.onSurface;
  Color get onSurfaceVariant => s.onSurfaceVariant;
  Color get primary => s.primary;
  Color get onPrimary => s.onPrimary;

  Color get pageBg => isDark ? const Color(0xFF1C1C1E) : s.pageBackground;

  // Popup background e borda (idênticos ao settings)
  Color get popupBg => cardBg;
  Color get popupBorder => outline;

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
      : s.cardShadowSoft;
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
// POPUP NATIVO (com cores do settings)
// ══════════════════════════════════════════════════════════════
class AiPopupOption<T> {
  final T value;
  final String icon;
  final String label;
  const AiPopupOption({required this.value, required this.icon, required this.label});
}

Future<T?> showAiPopup<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<AiPopupOption<T>> options,
  required T currentValue,
  required _WidgetPalette p,
}) async {
  final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;
  final overlayState = Overlay.of(context);
  final overlayBox = overlayState.context.findRenderObject() as RenderBox;
  final anchorTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final anchorSize = renderBox.size;

  final RelativeRect position = RelativeRect.fromLTRB(
    anchorTopLeft.dx,
    anchorTopLeft.dy + anchorSize.height,
    overlayBox.size.width - (anchorTopLeft.dx + anchorSize.width),
    overlayBox.size.height - (anchorTopLeft.dy + anchorSize.height),
  );

  final result = await showMenu<T>(
    context: context,
    position: position,
    color: p.popupBg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: p.popupBorder, width: 1.0),
    ),
    items: options.map((opt) {
      final active = opt.value == currentValue;
      return PopupMenuItem<T>(
        value: opt.value,
        padding: EdgeInsets.zero,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? p.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              AppIcon(opt.icon, size: 15, color: active ? p.primary : p.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    color: active ? p.primary : p.onSurface,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (active) AppIcon('check', size: 14, color: p.primary),
            ],
          ),
        ),
      );
    }).toList(),
  );

  return result;
}

// ══════════════════════════════════════════════════════════════
// CABEÇALHO DE TELA CHEIA — COM BOTÃO VOLTAR EM CONTAINER
// ══════════════════════════════════════════════════════════════
PreferredSizeWidget aiScreenAppBar({
  required _WidgetPalette p,
  required String title,
  required VoidCallback onBack,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: p.pageBg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: 4,
    leadingWidth: 52,
    leading: _AiBackButton(p: p, onTap: onBack),
    title: Text(title, style: TextStyle(color: p.onSurface, fontSize: 17, fontWeight: FontWeight.w700)),
    actions: actions,
  );
}

class _AiBackButton extends StatefulWidget {
  final _WidgetPalette p;
  final VoidCallback onTap;
  const _AiBackButton({required this.p, required this.onTap});
  @override
  State<_AiBackButton> createState() => _AiBackButtonState();
}

class _AiBackButtonState extends State<_AiBackButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pressed ? p.optionBgHover : p.optionBg,
          shape: BoxShape.circle,
          boxShadow: p.cardShadow,
        ),
        child: AppIcon('back', size: 18, color: p.onSurface),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CAMPO DE BUSCA (IDÊNTICO AO CHAT SEARCH)
// ══════════════════════════════════════════════════════════════
class _AiSearchBar extends StatefulWidget {
  final _WidgetPalette p;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _AiSearchBar({
    required this.p,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });
  @override
  State<_AiSearchBar> createState() => _AiSearchBarState();
}

class _AiSearchBarState extends State<_AiSearchBar> {
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: p.actionsBg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: p.cardShadow,
        ),
        child: Row(children: [
          AppIcon('search', color: p.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              style: TextStyle(fontSize: 15, color: p.onSurface),
              cursorColor: p.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: TextStyle(fontSize: 15, color: p.onSurfaceVariant),
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClear,
              child: AppIcon('close_circular', color: p.onSurfaceVariant, size: 18),
            ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CACHE PERSISTENTE DE PAÍSES/PROVÍNCIAS — agora com fallback de
// tradução PT-PT quando a fonte devolve inglês (a API countriesnow
// devolve os nomes tal como estão na sua base, frequentemente em
// inglês para países que não sejam de língua inglesa).
// ══════════════════════════════════════════════════════════════
class _GeoCache {
  static const _kCountriesKey = 'aiwidgets_geo_countries_v2';
  static const _kStatesPrefix = 'aiwidgets_geo_states_v2_';

  static List<String>? _memCountries;
  static final Map<String, List<String>> _memStates = {};

  // Tradução dos nomes de país mais comuns que a fonte devolve em
  // inglês. Não é exaustiva — cobre os casos mais frequentes; nomes
  // não mapeados aqui ficam como a fonte os devolveu.
  static const Map<String, String> _kCountryNamePt = {
    'Germany': 'Alemanha', 'Spain': 'Espanha', 'France': 'França',
    'Italy': 'Itália', 'United Kingdom': 'Reino Unido', 'Ireland': 'Irlanda',
    'Netherlands': 'Países Baixos', 'Belgium': 'Bélgica', 'Switzerland': 'Suíça',
    'Austria': 'Áustria', 'Poland': 'Polónia', 'Sweden': 'Suécia',
    'Norway': 'Noruega', 'Denmark': 'Dinamarca', 'Finland': 'Finlândia',
    'Greece': 'Grécia', 'Portugal': 'Portugal', 'Russia': 'Rússia',
    'United States': 'Estados Unidos', 'Canada': 'Canadá', 'Mexico': 'México',
    'Brazil': 'Brasil', 'Argentina': 'Argentina', 'Chile': 'Chile',
    'China': 'China', 'Japan': 'Japão', 'South Korea': 'Coreia do Sul',
    'India': 'Índia', 'Australia': 'Austrália', 'New Zealand': 'Nova Zelândia',
    'South Africa': 'África do Sul', 'Egypt': 'Egito', 'Morocco': 'Marrocos',
    'Nigeria': 'Nigéria', 'Kenya': 'Quénia', 'Angola': 'Angola',
    'Mozambique': 'Moçambique', 'Cape Verde': 'Cabo Verde',
    'Guinea-Bissau': 'Guiné-Bissau', 'São Tomé and Príncipe': 'São Tomé e Príncipe',
    'East Timor': 'Timor-Leste', 'Equatorial Guinea': 'Guiné Equatorial',
    'Turkey': 'Turquia', 'Ukraine': 'Ucrânia', 'Czech Republic': 'República Checa',
    'Romania': 'Roménia', 'Hungary': 'Hungria', 'Croatia': 'Croácia',
    'Iceland': 'Islândia', 'Luxembourg': 'Luxemburgo', 'Cyprus': 'Chipre',
    'Saudi Arabia': 'Arábia Saudita', 'United Arab Emirates': 'Emirados Árabes Unidos',
    'Israel': 'Israel', 'Thailand': 'Tailândia', 'Vietnam': 'Vietname',
    'Indonesia': 'Indonésia', 'Philippines': 'Filipinas', 'Malaysia': 'Malásia',
    'Singapore': 'Singapura', 'Pakistan': 'Paquistão', 'Bangladesh': 'Bangladeche',
  };

  static String _translateCountry(String english) => _kCountryNamePt[english] ?? english;

  static Future<List<String>> getCountries() async {
    if (_memCountries != null) return _memCountries!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_kCountriesKey);
      if (cached != null && cached.isNotEmpty) {
        _memCountries = cached;
        return cached;
      }
    } catch (_) {}

    final res = await http
        .get(Uri.parse('https://countriesnow.space/api/v0.1/countries/positions'))
        .timeout(const Duration(seconds: 10));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (decoded['data'] as List? ?? [])
        .map((e) => _sanitizeText((e as Map)['name']?.toString()))
        .where((n) => n.isNotEmpty)
        .map(_translateCountry)
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

  /// Nome original (possivelmente inglês) que a API espera, a partir
  /// do nome traduzido mostrado na UI — necessário porque o endpoint
  /// de states espera o nome tal como veio da fonte, não o traduzido.
  static String _originalNameFor(String translated) {
    for (final entry in _kCountryNamePt.entries) {
      if (entry.value == translated) return entry.key;
    }
    return translated;
  }

  static Future<List<String>> getStates(String country) async {
    if (_memStates.containsKey(country)) return _memStates[country]!;
    final apiCountryName = _originalNameFor(country);
    final key = '$_kStatesPrefix${apiCountryName.toLowerCase()}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(key);
      if (cached != null && cached.isNotEmpty) {
        _memStates[country] = cached;
        return cached;
      }
    } catch (_) {}

    List<String> states = [];
    try {
      final res = await http
          .post(
            Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiCountryName}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      states = (data?['states'] as List? ?? [])
          .map((e) => _sanitizeText((e as Map)['name']?.toString()))
          .where((n) => n.isNotEmpty)
          .toList()
        ..sort();
    } catch (_) {
      states = [];
    }

    // Se a fonte não devolveu nada (país sem subdivisões na base, ou
    // erro de rede), tentamos uma segunda fonte (Nominatim) como
    // reforço, em vez de deixar a lista vazia silenciosamente.
    if (states.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&limit=1'
          '&featureType=country&accept-language=pt&q=${Uri.encodeComponent(apiCountryName)}',
        );
        final countryRes = await http.get(uri, headers: {'User-Agent': 'NexaApp/1.0'}).timeout(const Duration(seconds: 8));
        if (countryRes.statusCode == 200) {
          final list = jsonDecode(countryRes.body) as List;
          if (list.isNotEmpty) {
            final osmId = (list.first as Map)['osm_id']?.toString();
            if (osmId != null) {
              final subUri = Uri.parse(
                'https://nominatim.openstreetmap.org/search?format=json&limit=50'
                '&countrycodes=&accept-language=pt&addressdetails=1'
                '&q=${Uri.encodeComponent(apiCountryName)}',
              );
              final subRes = await http.get(subUri, headers: {'User-Agent': 'NexaApp/1.0'}).timeout(const Duration(seconds: 8));
              if (subRes.statusCode == 200) {
                final subList = jsonDecode(subRes.body) as List;
                final names = subList
                    .map((e) => (e as Map)['address'] is Map ? (e['address']['state']?.toString() ?? '') : '')
                    .where((n) => n.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                states = names;
              }
            }
          }
        }
      } catch (_) {}
    }

    _memStates[country] = states;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, states);
    } catch (_) {}
    return states;
  }
}

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
    String fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final baseIsUsd = pair.key.startsWith('USD');
    final from = baseIsUsd ? 'USD' : pair.frankfurterCode!;
    final to = baseIsUsd ? pair.frankfurterCode! : 'USD';

    final uri = Uri.parse('https://api.frankfurter.app/${fmt(start)}..${fmt(end)}?from=$from&to=$to');
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Falha ao obter câmbio (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rates = decoded['rates'] as Map<String, dynamic>? ?? {};
    if (rates.isEmpty) throw Exception('Sem dados de câmbio disponíveis.');

    final entries = rates.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries.map((e) {
      final date = DateTime.parse(e.key);
      final ratesForDay = e.value as Map<String, dynamic>;
      final rate = (ratesForDay[to] as num).toDouble();
      return _MarketDataPoint(date.millisecondsSinceEpoch.toDouble(), rate);
    }).toList();
  }
}

// ══════════════════════════════════════════════════════════════
// MARKET WIDGET (card) — assíncrono / real-time
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

  static const List<({String key, String label})> _timeframes = [
    (key: '1D', label: '1D'),
    (key: '1W', label: '1W'),
    (key: '1M', label: '1M'),
    (key: '1Y', label: '1Y'),
  ];

  late _MarketPair _currentPair;
  late String _currentTf;

  bool _loading = true;
  String? _error;
  bool _notFound = false;
  List<_MarketDataPoint> _series = [];
  String? _iconUrl;

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
      ..addListener(() => setState(() => _progress = Curves.easeOutCubic.transform(_animController.value)));
    _currentTf = '1D';

    if (widget.json['found'] == false) {
      _notFound = true;
      _loading = false;
      _currentPair = _kMarketPairs.first;
      return;
    }

    _currentPair = _pairFromWidgetJson(widget.json);
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    final pair = _currentPair;

    if (pair.coingeckoId != null) {
      _CryptoIconCache.getIconUrl(pair.coingeckoId!).then((url) {
        if (mounted) setState(() => _iconUrl = url);
      });
    } else {
      _iconUrl = null;
    }

    try {
      final data = await MarketDataService.getSeries(pair, _currentTf);
      if (!mounted) return;
      setState(() {
        _series = data;
        _loading = false;
        _dragX = null;
      });
      _animController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
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
    if (tf == _currentTf) return;
    setState(() => _currentTf = tf);
    _loadData();
  }

  Future<void> _openMarketSelector() async {
    final result = await Navigator.of(context).push<_MarketPair>(
      CupertinoPageRoute(
        builder: (_) => _MarketSelectorScreen(s: widget.s, currentKey: _currentPair.key),
      ),
    );
    if (result != null && result.key != _currentPair.key) {
      setState(() => _currentPair = result);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;

    if (_notFound) {
      return _MarketNotFoundCard(p: p, onOpenSelector: _openMarketSelector);
    }

    final pair = _currentPair;

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
            child: _buildPreviewContent(p, pair),
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

  Widget _buildPreviewContent(_WidgetPalette p, _MarketPair pair) {
    if (_loading) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Center(child: AiSmallDotsLoader(color: p.onSurfaceVariant)),
      );
    }
    if (_error != null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('warning', size: 22, color: p.onSurfaceVariant),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _loadData,
                child: Text('Tentar novamente', style: TextStyle(color: p.primary, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
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

    _MarketDataPoint? hoverPoint;
    if (_dragX != null) {
      final idx = (_dragX! * (series.length - 1)).round().clamp(0, series.length - 1);
      hoverPoint = series[idx];
    }
    final displayValue = hoverPoint?.v ?? last;
    final displayLabel = hoverPoint != null ? _formatTimeLabel(hoverPoint.t, _currentTf) : 'Agora';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildPairIcon(p, pair, size: 20),
                  const SizedBox(width: 8),
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
    );
  }

  Widget _buildPairIcon(_WidgetPalette p, _MarketPair pair, {required double size}) {
    if (pair.badge == 'forex' && pair.fiatCountryCode != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: size, height: size * 0.72,
          child: Image.network(
            'https://flagcdn.com/w160/${pair.fiatCountryCode}.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.optionBg, borderRadius: BorderRadius.circular(5))),
          ),
        ),
      );
    }
    if (_iconUrl != null) {
      return ClipOval(
        child: Image.network(
          _iconUrl!,
          width: size, height: size,
          errorBuilder: (_, __, ___) => Container(width: size, height: size, decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle)),
        ),
      );
    }
    return Container(width: size, height: size, decoration: BoxDecoration(color: p.optionBg, shape: BoxShape.circle));
  }
}

// Card de "não encontrado" — mostrado quando o resultado da tool
// call trouxe found:false. Sem retry automático da IA (fora do
// escopo sem tool loop multi-turno); o utilizador pode abrir o
// seletor manual para escolher outro ativo.
class _MarketNotFoundCard extends StatelessWidget {
  final _WidgetPalette p;
  final VoidCallback onOpenSelector;
  const _MarketNotFoundCard({required this.p, required this.onOpenSelector});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: p.outline),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('warning', size: 26, color: p.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            'Não foi possível encontrar este ativo',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.onSurface, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tenta escolher manualmente ou pede outro ativo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onOpenSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Escolher manualmente',
                  style: TextStyle(color: p.onPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
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
    final safeRange = (maxY - minY).abs() < 0.0000001 ? 1.0 : (maxY - minY);

    const leftGutter = 4.0, rightGutter = 4.0, topGutter = 6.0, bottomGutter = 22.0;
    final innerW = size.width - leftGutter - rightGutter;
    final innerH = size.height - topGutter - bottomGutter;

    Offset ptAt(int i) {
      final norm = (values[i] - minY) / safeRange;
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

    final avgNorm = (avgV - minY) / safeRange;
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
// TELA CHEIA — SELETOR DE MERCADO (agora com lista mais longa —
// pesquisa em tempo real na CoinGecko em vez de ficar limitada
// aos 14 pares fixos; a lista fixa continua a aparecer quando o
// campo de busca está vazio, como atalho rápido).
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
    // Sempre dispara pesquisa remota a partir de 2 caracteres, mesmo
    // que a lista local já tenha resultados — assim a lista fica
    // realmente longa e dinâmica em vez de parar nos 14 pares fixos.
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchRemote(v.trim()));
  }

  Future<void> _searchRemote(String q) async {
    setState(() => _searchingRemote = true);
    try {
      final uri = Uri.parse('https://api.coingecko.com/api/v3/search?query=${Uri.encodeComponent(q)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final coins = (decoded['coins'] as List? ?? []).take(30);
        final results = <_MarketPair>[];
        for (final c in coins) {
          final m = c as Map<String, dynamic>;
          final symbol = (m['symbol'] as String? ?? '').toUpperCase();
          final id = m['id'] as String? ?? '';
          final name = m['name'] as String? ?? symbol;
          if (id.isEmpty || symbol.isEmpty) continue;
          results.add(_MarketPair(key: '${symbol}USD', label: '$symbol/USD', sub: name, badge: 'cripto', coingeckoId: id));
        }
        if (mounted) setState(() => _remoteResults = results);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searchingRemote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    // Combina local + remoto sem duplicar por coingeckoId/key, para
    // dar uma lista longa (empresas/moedas incluídas) em vez de só
    // os 14 pares fixos quando o utilizador está a pesquisar.
    final combined = <String, _MarketPair>{};
    if (_query.trim().isEmpty) {
      for (final p in _kMarketPairs) combined[p.key] = p;
    } else {
      for (final p in _localFiltered) combined[p.key] = p;
      for (final p in _remoteResults) combined.putIfAbsent(p.key, () => p);
    }
    final results = combined.values.toList();

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: 'Mercado', onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: _searchingRemote
                          ? CircularProgressIndicator(strokeWidth: 2, color: p.onSurfaceVariant)
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
                              Navigator.of(context).pop(pair);
                            }
                          },
                        );
                      },
                    ),
            ),
            _AiSearchBar(
              p: p,
              controller: _searchCtrl,
              hint: 'Procurar símbolo ou empresa, ex: BTC, Tesla, EUR…',
              onChanged: _onQueryChanged,
              onClear: () {
                setState(() {
                  _searchCtrl.clear();
                  _query = '';
                  _remoteResults = [];
                });
              },
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
  String? _iconUrl;

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
    final p = _WidgetPalette(widget.s);
    final pair = widget.pair;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30, height: 30,
              child: pair.badge == 'forex' && pair.fiatCountryCode != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        'https://flagcdn.com/w160/${pair.fiatCountryCode}.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(color: p.optionBg, borderRadius: BorderRadius.circular(6))),
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

  _WidgetPalette get _p => _WidgetPalette(widget.s);

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

  Widget _buildBody(_WidgetPalette p, _MarketPair pair) {
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
// CALENDÁRIO — CARD
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
// TELA CHEIA — NOVO EVENTO — botão de guardar movido para container
// fixo no fundo do ecrã, mesmo padrão do _LogoutButton em settings.
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
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: 'Novo evento', onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
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
                ],
              ),
            ),
            // Botão fixo no fundo — mesmo padrão do _LogoutButton em
            // settings.dart: container com gradiente fade-to-transparent.
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [p.pageBg, p.pageBg.withOpacity(0.0)],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: GestureDetector(
                    onTap: _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
                      child: Text('Adicionar evento', style: TextStyle(color: p.onPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
// MAP WIDGET — CARD
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
  bool _notFound = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  final GlobalKey _layersBtnKey = GlobalKey();
  _MapLayer _layer = _MapLayer.satellite;

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.json['found'] == false) {
      _notFound = true;
      _lat = 38.7223;
      _lng = -9.1393;
      _zoom = 13.0;
      _name = '';
    } else {
      _lat = (widget.json['lat'] is num) ? (widget.json['lat'] as num).toDouble() : 38.7223;
      _lng = (widget.json['lng'] is num) ? (widget.json['lng'] as num).toDouble() : -9.1393;
      _zoom = (widget.json['zoom'] is num) ? (widget.json['zoom'] as num).toDouble() : 13.0;
      _name = _sanitizeText(widget.json['name']);
      if (_name.isEmpty) _name = 'Local';
    }

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
      case _MapLayer.googleMaps:
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
        _notFound = false;
      });
      _mapController.move(ll.LatLng(_lat, _lng), _zoom);
    }
  }

  Future<void> _openInGoogleMaps() async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$_lat,$_lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível abrir o Google Maps.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openLayersPopup() async {
    final selected = await showAiPopup<_MapLayer>(
      context: context,
      anchorKey: _layersBtnKey,
      currentValue: _layer,
      p: _p,
      options: const [
        AiPopupOption(value: _MapLayer.standard, icon: 'road', label: 'Padrão'),
        AiPopupOption(value: _MapLayer.satellite, icon: 'satellite', label: 'Satélite'),
        AiPopupOption(value: _MapLayer.streets, icon: 'road', label: 'Ruas'),
        AiPopupOption(value: _MapLayer.dark, icon: 'moon', label: 'Escuro'),
        AiPopupOption(value: _MapLayer.terrain, icon: 'mountain', label: 'Terreno'),
        AiPopupOption(value: _MapLayer.googleMaps, icon: 'map', label: 'Abrir no Google Maps'),
      ],
    );

    if (selected == null) return;
    if (selected == _MapLayer.googleMaps) {
      _openInGoogleMaps();
      return;
    }
    setState(() => _layer = selected);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;

    if (_notFound) {
      return _PlaceNotFoundCard(p: p, onOpenPicker: _openLocationPicker);
    }

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
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: p.actionsBg, borderRadius: BorderRadius.circular(50)),
                child: GestureDetector(
                  key: _layersBtnKey,
                  onTap: _openLayersPopup,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                    child: AppIcon('layers', color: p.onPrimary, size: 17),
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

// Card de "lugar não encontrado" — mesmo princípio do market: sem
// retry automático da IA, o utilizador escolhe manualmente.
class _PlaceNotFoundCard extends StatelessWidget {
  final _WidgetPalette p;
  final VoidCallback onOpenPicker;
  const _PlaceNotFoundCard({required this.p, required this.onOpenPicker});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: p.outline),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('warning', size: 26, color: p.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            'Não foi possível encontrar este lugar',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.onSurface, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tenta escolher manualmente ou pede outro lugar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onOpenPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Escolher manualmente',
                  style: TextStyle(color: p.onPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — SELETOR DE LOCALIZAÇÃO (com índice alfabético)
// ══════════════════════════════════════════════════════════════
class _LocationPickerScreen extends StatefulWidget {
  final AppColorScheme s;
  const _LocationPickerScreen({required this.s});
  @override State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _loadingCountries = true;
  List<String> _countries = [];
  String? _error;

  final Map<String, int> _letterIndexMap = {};
  List<Widget> _flatItems = [];

  _WidgetPalette get _p => _WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() { _loadingCountries = true; _error = null; });
    try {
      final list = await _GeoCache.getCountries();
      if (mounted) {
        setState(() {
          _countries = list;
          _loadingCountries = false;
          _buildFlatItems();
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Não foi possível carregar países.'; _loadingCountries = false; });
    }
  }

  void _buildFlatItems() {
    _flatItems.clear();
    _letterIndexMap.clear();

    final groups = <String, List<String>>{};
    for (final country in _countries) {
      final letter = country.substring(0, 1).toUpperCase();
      final normalized = _normalizeLetter(letter);
      if (!groups.containsKey(normalized)) groups[normalized] = [];
      groups[normalized]!.add(country);
    }

    final sortedLetters = groups.keys.toList()..sort();

    int currentIndex = 0;
    for (final letter in sortedLetters) {
      _letterIndexMap[letter] = currentIndex;
      _flatItems.add(_LetterHeader(letter: letter, p: _p));
      currentIndex++;
      for (final country in groups[letter]!) {
        _flatItems.add(_CountryRow(
          p: _p,
          country: country,
          onTap: () => _openCountry(country),
        ));
        currentIndex++;
      }
    }
  }

  String _normalizeLetter(String s) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const without = 'aaaaaeeeeiiiiooooouuuuc';
    final lower = s.toLowerCase();
    final index = accents.indexOf(lower);
    if (index != -1) {
      return without[index].toUpperCase();
    }
    return s.toUpperCase();
  }

  void _scrollToLetter(String letter) {
    final index = _letterIndexMap[letter];
    if (index == null) return;
    const itemHeight = 52.0;
    final targetOffset = index * itemHeight;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _openCountry(String country) async {
    final result = await Navigator.of(context).push<({String name, double lat, double lng})>(
      CupertinoPageRoute(builder: (_) => _StatePickerScreen(s: widget.s, country: country)),
    );
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  List<String> get _filteredCountries {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _countries;
    return _countries.where((c) => c.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final searching = _query.trim().isNotEmpty;
    final filtered = _filteredCountries;

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: 'Escolher país', onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _loadingCountries
                      ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.onSurfaceVariant))
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
                          : searching
                              ? ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) => _CountryRow(
                                    p: p,
                                    country: filtered[i],
                                    onTap: () => _openCountry(filtered[i]),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: _flatItems.length,
                                  itemBuilder: (_, i) => _flatItems[i],
                                ),
                ),
                _AiSearchBar(
                  p: p,
                  controller: _searchCtrl,
                  hint: 'Procurar país…',
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
              ],
            ),
            if (!searching && !_loadingCountries && _error == null)
              Positioned(
                right: 8,
                top: 20,
                bottom: 80,
                child: _AlphabetIndex(
                  letters: _letterIndexMap.keys.toList()..sort(),
                  onTap: _scrollToLetter,
                  p: p,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LetterHeader extends StatelessWidget {
  final String letter;
  final _WidgetPalette p;
  const _LetterHeader({required this.letter, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: p.primary,
        ),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  final _WidgetPalette p;
  final String country;
  final VoidCallback onTap;
  const _CountryRow({required this.p, required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                country,
                style: TextStyle(color: p.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            AppIcon('chevron_right', size: 14, color: p.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _AlphabetIndex extends StatelessWidget {
  final List<String> letters;
  final ValueChanged<String> onTap;
  final _WidgetPalette p;
  const _AlphabetIndex({required this.letters, required this.onTap, required this.p});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: letters.map((letter) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(letter),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: p.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — SELETOR DE PROVÍNCIAS — agora com fallback de
// segunda fonte quando a API principal não devolve nada (ver
// _GeoCache.getStates acima), reduzindo o "falha ao achar
// províncias" para os casos em que ambas as fontes falham mesmo.
// ══════════════════════════════════════════════════════════════
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
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&limit=1&accept-language=pt&q=${Uri.encodeComponent('$stateName, ${widget.country}')}');
      final res = await http.get(uri, headers: {'User-Agent': 'NexaApp/1.0'}).timeout(const Duration(seconds: 8));
      final list = jsonDecode(res.body) as List;
      if (list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final lat = double.parse(first['lat'].toString());
        final lng = double.parse(first['lon'].toString());
        if (mounted) Navigator.of(context).pop((name: '$stateName, ${widget.country}', lat: lat, lng: lng));
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível localizar esta região.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final items = _filtered;

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: widget.country, onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: p.onSurfaceVariant))
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
            _AiSearchBar(
              p: p,
              controller: _searchCtrl,
              hint: 'Procurar região…',
              onChanged: (v) => setState(() => _query = v),
              onClear: () => setState(() {
                _searchCtrl.clear();
                _query = '';
              }),
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