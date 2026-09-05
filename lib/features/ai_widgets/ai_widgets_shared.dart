// ══════════════════════════════════════════════════════════════
// FILE: lib/features/ai_widgets/ai_widgets_shared.dart
// ══════════════════════════════════════════════════════════════
//
// Base compartilhada por market_widget.dart, calendar_widget.dart
// e map_widget.dart: funções auxiliares, tool definitions, os três
// resolvers (mercado/lugar/data), a paleta de cores dos widgets de
// IA, o parser de blocos ```widget_x```, o popup nativo, o app bar
// dedicado, o botão voltar, a barra de busca e o loader de pontos.
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../services/api_service.dart' show ToolDefinition, kAllTools;

// ══════════════════════════════════════════════════════════════
// NOTA — GOOGLE MAPS SEM API KEY
// ══════════════════════════════════════════════════════════════
// Sem key do Google Cloud configurada nativamente (AndroidManifest.xml /
// Info.plist), não dá pra embutir o SDK real do Google Maps dentro da app.
// A opção "Google Maps" no popup de camadas abre a app/site do Google Maps
// via launchUrl — é o Google Maps a sério, só que como app externa, não
// embutida no card. Quando/se decidires obter a key, o ponto a mudar é a
// função _openInGoogleMaps() em map_widget.dart.

// ══════════════════════════════════════════════════════════════
// FUNÇÕES AUXILIARES
// ══════════════════════════════════════════════════════════════
Color? parseAiColor(dynamic raw) {
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

String sanitizeAiText(String? raw) {
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

const Map<String, String> kForexCodeNames = {
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
    if (parts.length == 2 && kForexCodeNames.containsKey(parts[0]) && kForexCodeNames.containsKey(parts[1])) {
      return cleaned;
    }
    return null;
  }
  if (cleaned.length == 3 && kForexCodeNames.containsKey(cleaned)) return cleaned;
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
    final name = kForexCodeNames[forexCode] ?? forexCode;
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
class WidgetPalette {
  final AppColorScheme s;
  const WidgetPalette(this.s);

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

// NOTA: buildAiWidget referencia AiMarketWidget / AiCalendarWidget /
// AiMapWidget, que agora vivem em arquivos separados (market_widget.dart,
// calendar_widget.dart, map_widget.dart). Esta função foi movida para
// ai_widgets.dart (barrel file) — não fica aqui para não criar um import
// circular entre este arquivo e os três widgets concretos.

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
  required WidgetPalette p,
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
  required WidgetPalette p,
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
    leading: AiBackButton(p: p, onTap: onBack),
    title: Text(title, style: TextStyle(color: p.onSurface, fontSize: 17, fontWeight: FontWeight.w700)),
    actions: actions,
  );
}

class AiBackButton extends StatefulWidget {
  final WidgetPalette p;
  final VoidCallback onTap;
  const AiBackButton({super.key, required this.p, required this.onTap});
  @override
  State<AiBackButton> createState() => _AiBackButtonState();
}

class _AiBackButtonState extends State<AiBackButton> {
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
class AiSearchBar extends StatefulWidget {
  final WidgetPalette p;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const AiSearchBar({
    super.key,
    required this.p,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });
  @override
  State<AiSearchBar> createState() => _AiSearchBarState();
}

class _AiSearchBarState extends State<AiSearchBar> {
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
// SMALL DOTS LOADER
// ══════════════════════════════════════════════════════════════
class AiSmallDotsLoader extends StatefulWidget {
  final Color color;
  const AiSmallDotsLoader({super.key, required this.color});
  @override
  State<AiSmallDotsLoader> createState() => _AiSmallDotsLoaderState();
}

class _AiSmallDotsLoaderState extends State<AiSmallDotsLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 12,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final t = ((_ctrl.value * 3) - i) % 3;
              final scale = (0.5 + 0.5 * (1 - (t.clamp(0.0, 1.0)))).clamp(0.5, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}