import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import '../colors.dart';
import '../widgets.dart';

// ══════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════

class SoundTrack {
  final String title;
  final String artist;
  final String coverColorHex;
  final String videoId;
  const SoundTrack({
    required this.title,
    required this.artist,
    required this.coverColorHex,
    required this.videoId,
  });
}

class Album {
  final String title;
  final String artist;
  final String coverColorHex;
  final List<SoundTrack> tracks;
  const Album({
    required this.title,
    required this.artist,
    required this.coverColorHex,
    required this.tracks,
  });
}

// ══════════════════════════════════════════════════════════════
// CONTROLLER (para pesquisa global)
// ══════════════════════════════════════════════════════════════

class SoundTabController extends ChangeNotifier {
  String? _pendingSearch;
  String? get pendingSearch => _pendingSearch;
  void requestSearch(String query) {
    _pendingSearch = query;
    notifyListeners();
  }
  void consumePendingSearch() => _pendingSearch = null;
}
final SoundTabController soundTabController = SoundTabController();

// ══════════════════════════════════════════════════════════════
// TELA PRINCIPAL
// ══════════════════════════════════════════════════════════════

class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key});
  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> with ThemeReactive<SoundScreen> {
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();
  List<Album> _albums = [];
  bool _loading = true;
  SoundTrack? _currentTrack;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    soundTabController.addListener(_onPendingSearch);
    _fetchDefaultAlbums();
    _player.playerStateStream.listen((state) {
      if (state.playing != _isPlaying && mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });
  }

  @override
  void dispose() {
    soundTabController.removeListener(_onPendingSearch);
    _player.dispose();
    _yt.close();
    super.dispose();
  }

  void _onPendingSearch() {
    final query = soundTabController.pendingSearch;
    if (query != null) {
      soundTabController.consumePendingSearch();
      _searchTracks(query);
    }
  }

  // Carrega uma playlist fixa (substitua pelo ID real da playlist)
  Future<void> _fetchDefaultAlbums() async {
    setState(() => _loading = true);
    try {
      const playlistId = 'PLAYLIST_ID'; // ex.: 'PLrAXtmErZgO...'
      final playlist = await _yt.playlists.get(playlistId);
      final videos = await _yt.playlists.getVideos(playlist.id).toList();

      final tracks = videos.map((video) => SoundTrack(
            title: video.title,
            artist: video.author,
            coverColorHex: '#2e8bc9',
            videoId: video.id.value,
          )).toList();

      final album = Album(
        title: playlist.title,
        artist: playlist.author ?? 'Vários artistas',
        coverColorHex: '#2e8bc9',
        tracks: tracks,
      );

      setState(() {
        _albums = [album];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao buscar playlist: $e');
      setState(() => _loading = false);
    }
  }

  // Pesquisa de vídeos (faixas)
  Future<void> _searchTracks(String query) async {
    setState(() => _loading = true);
    try {
      final searchResults = await _yt.search.search(query);
      final tracks = <SoundTrack>[];
      await for (final video in searchResults) {
        tracks.add(SoundTrack(
          title: video.title,
          artist: video.author,
          coverColorHex: '#2e8bc9',
          videoId: video.id.value,
        ));
        if (tracks.length >= 20) break;
      }

      setState(() {
        _albums = [
          Album(
            title: 'Resultados da pesquisa',
            artist: query,
            coverColorHex: '#2e8bc9',
            tracks: tracks,
          )
        ];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro na pesquisa: $e');
      setState(() => _loading = false);
    }
  }

  // Toca o áudio da faixa selecionada
  Future<void> _playTrack(SoundTrack track) async {
    try {
      final video = await _yt.videos.get(track.videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.audioOnly.withHighestBitrate();

      await _player.setUrl(streamInfo.url.toString());
      await _player.play();
      setState(() {
        _currentTrack = track;
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('Erro ao tocar: $e');
    }
  }

  void _togglePlay(SoundTrack track) {
    if (_currentTrack == track) {
      // Se é a mesma faixa, apenas pausa/retoma
      if (_player.playing) {
        _player.pause();
        setState(() => _isPlaying = false);
      } else {
        _player.play();
        setState(() => _isPlaying = true);
      }
    } else {
      // Nova faixa
      _playTrack(track);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: s.statusBarStyle,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Stack(children: [
              _buildAlbumList(s),
              _SoundAppBar(s: s),
              _FloatingPlayerBar(
                s: s,
                currentTrack: _currentTrack,
                isPlaying: _isPlaying,
                onTogglePlay: () {
                  if (_currentTrack != null) {
                    if (_player.playing) {
                      _player.pause();
                      setState(() => _isPlaying = false);
                    } else {
                      _player.play();
                      setState(() => _isPlaying = true);
                    }
                  }
                },
                onOpenFavorites: () {
                  // Navegar para favoritos
                },
                onOpenSearch: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SoundSearchScreen(s: s)),
                  );
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumList(AppColorScheme s) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_albums.isEmpty) {
      return Center(
        child: Text('Nenhum álbum encontrado',
            style: TextStyle(color: s.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
      itemCount: _albums.length,
      itemBuilder: (_, albumIndex) {
        final album = _albums[albumIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(int.parse(album.coverColorHex.replaceFirst('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.album, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(album.title,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: s.onSurface)),
                        Text(album.artist,
                            style: TextStyle(
                                fontSize: 13,
                                color: s.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...album.tracks.map((track) => _TrackTile(
                  s: s,
                  track: track,
                  isCurrent: _currentTrack == track,
                  isPlaying: _isPlaying && _currentTrack == track,
                  onTap: () => _togglePlay(track),
                )),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// APPBAR
// ══════════════════════════════════════════════════════════════

class _SoundAppBar extends StatelessWidget {
  final AppColorScheme s;
  const _SoundAppBar({required this.s});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.pageBackground, s.pageBackground.withOpacity(0.0)],
          ),
        ),
        child: Row(
          children: [
            ScreenBackButton(s: s),
            const Spacer(),
            // Botão de apps (ícone PNG de assets/icons/png/)
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: s.cardShadow,
                ),
                child: Image.asset(
                  'assets/icons/png/apps.png', // ajuste o caminho
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTTOMBAR FLUTUANTE (PLAYER/SHIMMER)
// ══════════════════════════════════════════════════════════════

class _FloatingPlayerBar extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack? currentTrack;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenSearch;

  const _FloatingPlayerBar({
    required this.s,
    required this.currentTrack,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onOpenFavorites,
    required this.onOpenSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            // Botão de favoritos (esquerda)
            _CircleActionButton(
              s: s,
              icon: Icons.bookmark_border,
              onTap: onOpenFavorites,
            ),
            const SizedBox(width: 8),
            // Área central: shimmer ou player
            Expanded(
              child: currentTrack == null
                  ? _ShimmerPlaceholder(s: s)
                  : _PlayerInfo(
                      s: s,
                      track: currentTrack!,
                      isPlaying: isPlaying,
                      onTogglePlay: onTogglePlay,
                    ),
            ),
            const SizedBox(width: 8),
            // Botão de pesquisa (direita)
            _CircleActionButton(
              s: s,
              icon: Icons.search,
              onTap: onOpenSearch,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final AppColorScheme s;
  final IconData icon;
  final VoidCallback onTap;
  const _CircleActionButton({
    required this.s,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: s.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: s.onSurface, size: 22),
      ),
    );
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  final AppColorScheme s;
  const _ShimmerPlaceholder({required this.s});
  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final opacity = 0.4 + 0.6 * _controller.value;
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: s.hover.withOpacity(opacity),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }
}

class _PlayerInfo extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack track;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  const _PlayerInfo({
    required this.s,
    required this.track,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF'))),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.music_note, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface)),
              Text(track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
              color: s.onSurface),
          onPressed: onTogglePlay,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA DE PESQUISA (mesmo design do ChatSearchScreen)
// ══════════════════════════════════════════════════════════════

class SoundSearchScreen extends StatefulWidget {
  final AppColorScheme s;
  const SoundSearchScreen({super.key, required this.s});

  @override
  State<SoundSearchScreen> createState() => _SoundSearchScreenState();
}

class _SoundSearchScreenState extends State<SoundSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';
  List<SoundTrack> _results = [];
  bool _loading = false;
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final searchResults = await _yt.search.search(query);
      final tracks = <SoundTrack>[];
      await for (final video in searchResults) {
        tracks.add(SoundTrack(
          title: video.title,
          artist: video.author,
          coverColorHex: '#2e8bc9',
          videoId: video.id.value,
        ));
        if (tracks.length >= 20) break;
      }
      setState(() {
        _results = tracks;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro na pesquisa: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: s.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildBody(s),
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: keyboardInset > 0
                    ? keyboardInset + 8
                    : MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: s.cardBackground,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: s.cardShadow,
                      ),
                      child: Row(children: [
                        AppIcon('search', color: s.onSurfaceVariant, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            onChanged: (v) {
                              setState(() => _query = v);
                              _performSearch(v);
                            },
                            style: TextStyle(fontSize: 15, color: s.onSurface),
                            cursorColor: s.primary,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Pesquisar músicas...',
                              hintStyle: TextStyle(
                                  fontSize: 15, color: s.onSurfaceVariant),
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _ctrl.clear();
                                _query = '';
                                _results = [];
                              });
                            },
                            child: AppIcon('close',
                                color: s.onSurfaceVariant, size: 14),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.cardBackground,
                        shape: BoxShape.circle,
                        boxShadow: s.cardShadow,
                      ),
                      child: AppIcon('close',
                          color: s.onSurfaceVariant, size: 16),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme s) {
    if (_query.isEmpty) {
      return _InitialSearchPrompt(key: const ValueKey('initial'), s: s);
    }
    if (_loading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_results.isEmpty) {
      return Center(
        key: const ValueKey('no-results'),
        child: Text(
          'Sem resultados para "${_query}"',
          style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('results'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final track = _results[i];
        return _SearchResultTile(s: s, track: track);
      },
    );
  }
}

class _InitialSearchPrompt extends StatelessWidget {
  final AppColorScheme s;
  const _InitialSearchPrompt({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.65,
              child: AppIcon('search', color: s.onSurfaceVariant, size: 52),
            ),
            const SizedBox(height: 18),
            Text(
              'Pesquise músicas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Digite para encontrar faixas e artistas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: s.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack track;
  const _SearchResultTile({required this.s, required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: s.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF'))),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.music_note, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface)),
              const SizedBox(height: 3),
              Text(track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Botão voltar reutilizável ─────────────────────────────────

class ScreenBackButton extends StatefulWidget {
  final AppColorScheme s;
  const ScreenBackButton({super.key, required this.s});
  @override
  State<ScreenBackButton> createState() => _ScreenBackButtonState();
}

class _ScreenBackButtonState extends State<ScreenBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: widget.s.cardShadow,
          ),
          child: AppIcon('back.svg', size: 20, color: widget.s.onSurface),
        ),
      ),
    );
  }
}