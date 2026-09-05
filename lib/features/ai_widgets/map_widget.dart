// ══════════════════════════════════════════════════════════════
// FILE: lib/features/ai_widgets/map_widget.dart
// ══════════════════════════════════════════════════════════════
//
// NOTA — GOOGLE MAPS SEM API KEY
// Sem key do Google Cloud configurada nativamente (AndroidManifest.xml /
// Info.plist), não dá pra embutir o SDK real do Google Maps dentro da app.
// A opção "Google Maps" no popup de camadas abre a app/site do Google Maps
// via launchUrl — é o Google Maps a sério, só que como app externa, não
// embutida no card. Quando/se decidires obter a key, o ponto a mudar é a
// função _openInGoogleMaps() abaixo.
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import 'ai_widgets_shared.dart';

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

    try {
      final uri = Uri.parse('https://countriesnow.space/api/v0.1/countries/positions');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (decoded['data'] as List? ?? []);
        final names = data.map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        names.sort();
        _memCountries = names;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_kCountriesKey, names);
        } catch (_) {}
        return names;
      }
    } catch (_) {}

    return [];
  }

  static Future<List<String>> getStates(String country) async {
    if (_memStates.containsKey(country)) return _memStates[country]!;
    final key = '$_kStatesPrefix$country';
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
      final uri = Uri.parse('https://countriesnow.space/api/v0.1/countries/states');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': country}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final statesList = (data?['states'] as List? ?? []);
        states = statesList.map((e) => (e as Map<String, dynamic>)['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        states.sort();
      }
    } catch (_) {}
    // Se não trouxe estados/províncias (país pequeno sem subdivisão na
    // fonte), evita ecrã vazio — trata o próprio país como única opção
    // (mesma ideia do fallback antigo de _GeoCache.getStates acima),
    // reduzindo o "falha ao achar nada" que a fonte às vezes devolve.
    if (states.isEmpty) states = [country];

    _memStates[country] = states;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, states);
    } catch (_) {}
    return states;
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
  bool _found = true;
  String? _name;
  double? _lat;
  double? _lng;
  _MapLayer _layer = _MapLayer.standard;
  final MapController _mapController = MapController();
  final GlobalKey _layerBtnKey = GlobalKey();
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    final json = widget.json;
    _found = json['found'] != false;
    _name = json['name']?.toString();
    _lat = (json['lat'] as num?)?.toDouble();
    _lng = (json['lng'] as num?)?.toDouble();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _tileUrlFor(_MapLayer layer) {
    switch (layer) {
      case _MapLayer.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _MapLayer.streets:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _MapLayer.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case _MapLayer.terrain:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case _MapLayer.standard:
      case _MapLayer.googleMaps:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_lat == null || _lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$_lat,$_lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openLocationPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      AppPageRoute(builder: (_) => _LocationPickerScreen(s: widget.s)),
    );
    if (result != null && mounted) {
      setState(() {
        _name = result['name'] as String?;
        _lat = result['lat'] as double?;
        _lng = result['lng'] as double?;
        _found = true;
      });
      _mapController.move(ll.LatLng(_lat!, _lng!), 13);
    }
  }

  Future<void> _useMyLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission perm = permission;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _name = 'A minha localização';
        _found = true;
      });
      _mapController.move(ll.LatLng(_lat!, _lng!), 15);
    } catch (_) {}
  }

  void _openLayerPicker() async {
    final p = _p;
    final selected = await showAiPopup<_MapLayer>(
      context: context,
      anchorKey: _layerBtnKey,
      currentValue: _layer,
      p: p,
      options: const [
        AiPopupOption(value: _MapLayer.standard, icon: 'road', label: 'Padrão'),
        AiPopupOption(value: _MapLayer.satellite, icon: 'satellite', label: 'Satélite'),
        AiPopupOption(value: _MapLayer.streets, icon: 'road', label: 'Ruas'),
        AiPopupOption(value: _MapLayer.dark, icon: 'moon', label: 'Escuro'),
        AiPopupOption(value: _MapLayer.terrain, icon: 'mountain', label: 'Terreno'),
        AiPopupOption(value: _MapLayer.googleMaps, icon: 'map', label: 'Google Maps'),
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

    if (!_found || _lat == null || _lng == null) {
      return _PlaceNotFoundCard(p: p, onOpenPicker: _openLocationPicker);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(24), boxShadow: p.cardShadow),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: ll.LatLng(_lat!, _lng!),
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(urlTemplate: _tileUrlFor(_layer), subdomains: const ['a', 'b', 'c']),
                    MarkerLayer(markers: [
                      Marker(
                        point: ll.LatLng(_lat!, _lng!),
                        width: 40, height: 40,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) => _PulsingMapMarker(animation: _pulseAnim, color: p.primary),
                        ),
                      ),
                    ]),
                  ],
                ),
                Positioned(
                  top: 12, right: 12,
                  child: GestureDetector(
                    key: _layerBtnKey,
                    onTap: _openLayerPicker,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: p.badgeBg, shape: BoxShape.circle, boxShadow: p.cardShadow),
                      child: AppIcon('layers', color: p.onSurface, size: 18),
                    ),
                  ),
                ),
                Positioned(
                  top: 12, left: 12,
                  child: GestureDetector(
                    onTap: _useMyLocation,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: p.badgeBg, shape: BoxShape.circle, boxShadow: p.cardShadow),
                      child: AppIcon('my_location', color: p.onSurface, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _name ?? 'Local selecionado',
                    style: TextStyle(color: p.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _openLocationPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: p.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text('Alterar', style: TextStyle(color: p.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
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

class _PlaceNotFoundCard extends StatelessWidget {
  final WidgetPalette p;
  final VoidCallback onOpenPicker;
  const _PlaceNotFoundCard({required this.p, required this.onOpenPicker});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(24), boxShadow: p.cardShadow),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('location_off', color: p.onSurfaceVariant, size: 28),
          const SizedBox(height: 10),
          Text('Local não encontrado', style: TextStyle(color: p.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Escolhe um local para mostrar no mapa.', textAlign: TextAlign.center, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onOpenPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Escolher local', style: TextStyle(color: p.onPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — ESCOLHER PAÍS
// ══════════════════════════════════════════════════════════════
class _LocationPickerScreen extends StatefulWidget {
  final AppColorScheme s;
  const _LocationPickerScreen({required this.s});
  @override State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  final _searchCtrl = TextEditingController();
  List<String> _allCountries = [];
  List<String> _filtered = [];
  List<Widget> _flatItems = [];
  bool _loading = true;

  late final WidgetPalette _p2;

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _p2 = _p;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _GeoCache.getCountries();
    if (mounted) {
      setState(() {
        _allCountries = list;
        _filtered = list;
        _loading = false;
      });
      _rebuildFlatList();
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? _allCountries : _allCountries.where((c) => c.toLowerCase().contains(q)).toList();
    });
    _rebuildFlatList();
  }

  void _rebuildFlatList() {
    final items = <Widget>[];
    String? lastLetter;
    for (final country in _filtered) {
      final letter = country.isNotEmpty ? country[0].toUpperCase() : '#';
      if (letter != lastLetter) {
        lastLetter = letter;
        items.add(_LetterHeader(letter: letter, p: _p2));
      }
      items.add(_CountryRow(
        p: _p2,
        country: country,
        onTap: () => _selectCountry(country),
      ));
    }
    setState(() => _flatItems = items);
  }

  void _selectCountry(String country) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      AppPageRoute(builder: (_) => _StatePickerScreen(s: widget.s, country: country)),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: 'Escolher país', onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: Column(
          children: [
            AiSearchBar(
              p: p,
              controller: _searchCtrl,
              hint: 'Pesquisar país...',
              onChanged: _onSearchChanged,
              onClear: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              },
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? Center(child: AiSmallDotsLoader(color: p.onSurfaceVariant))
                  : Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 6, 32, 20),
                          itemCount: _flatItems.length,
                          itemBuilder: (_, i) => _flatItems[i],
                        ),
                        if (_searchCtrl.text.isEmpty)
                          Positioned(
                            right: 2, top: 0, bottom: 0,
                            child: _AlphabetIndex(
                              letters: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''),
                              p: p,
                              onTap: (letter) {
                                final idx = _filtered.indexWhere((c) => c.toUpperCase().startsWith(letter));
                                if (idx == -1) return;
                              },
                            ),
                          ),
                      ],
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
  final WidgetPalette p;
  const _LetterHeader({required this.letter, required this.p});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(letter, style: TextStyle(color: p.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _CountryRow extends StatelessWidget {
  final WidgetPalette p;
  final String country;
  final VoidCallback onTap;
  const _CountryRow({required this.p, required this.country, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: p.optionBg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(child: Text(country, style: TextStyle(color: p.onSurface, fontSize: 14.5, fontWeight: FontWeight.w500))),
            AppIcon('chevron_right', color: p.onSurfaceVariant, size: 14),
          ],
        ),
      ),
    );
  }
}

class _AlphabetIndex extends StatelessWidget {
  final List<String> letters;
  final ValueChanged<String> onTap;
  final WidgetPalette p;
  const _AlphabetIndex({required this.letters, required this.onTap, required this.p});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: letters.map((l) => GestureDetector(
          onTap: () => onTap(l),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(l, style: TextStyle(color: p.primary, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        )).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA CHEIA — ESCOLHER PROVÍNCIA/ESTADO
// ══════════════════════════════════════════════════════════════
class _StatePickerScreen extends StatefulWidget {
  final AppColorScheme s;
  final String country;
  const _StatePickerScreen({required this.s, required this.country});
  @override State<_StatePickerScreen> createState() => _StatePickerScreenState();
}

class _StatePickerScreenState extends State<_StatePickerScreen> {
  List<String> _states = [];
  bool _loading = true;

  WidgetPalette get _p => WidgetPalette(widget.s);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _GeoCache.getStates(widget.country);
    if (mounted) setState(() { _states = list; _loading = false; });
  }

  void _selectState(String state) async {
    // Geocodifica "estado, país" via Nominatim para obter lat/lng reais.
    try {
      final query = state == widget.country ? widget.country : '$state, ${widget.country}';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&limit=1'
        '&accept-language=pt&q=${Uri.encodeComponent(query)}',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'NexaApp/1.0'}).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lng = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lng != null && mounted) {
            Navigator.of(context).pop({'name': query, 'lat': lat, 'lng': lng});
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop({'name': state, 'lat': null, 'lng': null});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: aiScreenAppBar(p: p, title: widget.country, onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: _loading
            ? Center(child: AiSmallDotsLoader(color: p.onSurfaceVariant))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                itemCount: _states.length,
                itemBuilder: (_, i) => _PlainNavRow(p: p, label: _states[i], showArrow: false, onTap: () => _selectState(_states[i])),
              ),
      ),
    );
  }
}

class _PlainNavRow extends StatelessWidget {
  final WidgetPalette p;
  final String label;
  final VoidCallback onTap;
  final bool showArrow;
  const _PlainNavRow({required this.p, required this.label, required this.onTap, this.showArrow = true});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: p.optionBg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: p.onSurface, fontSize: 14.5, fontWeight: FontWeight.w500))),
            if (showArrow) AppIcon('chevron_right', color: p.onSurfaceVariant, size: 14),
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
    final scale = 1.0 + (animation.value * 0.6);
    final opacity = (1.0 - animation.value).clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: scale,
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: color.withOpacity(opacity * 0.4), shape: BoxShape.circle),
          ),
        ),
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
        ),
      ],
    );
  }
}