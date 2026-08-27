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
  final String? thumbnailUrl;
  final String videoId;
  const SoundTrack({
    required this.title,
    required this.artist,
    required this.coverColorHex,
    required this.videoId,
    this.thumbnailUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoundTrack &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId;

  @override
  int get hashCode => videoId.hashCode;
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

  List<SoundTrack> _feed = [];
  bool _loadingFeed = true;
  String? _feedError;

  SoundTrack? _currentTrack;
  bool _isPlaying = false;
  bool _isBuffering = false;

  // Termos usados para simular um feed de "populares agora".
  // Sem chave oficial de API não existe endpoint público de trending do
  // YouTube, então isso busca por termos que tendem a puxar conteúdo
  // popular no momento em que a tela é aberta — não é trending real.
  static const List<String> _trendingSeeds = [
    'top hits 2026',
    'músicas mais tocadas agora',
    'trending music this week',
  ];

  @override
  void initState() {
    super.initState();
    soundTabController.addListener(_onPendingSearch);
    _fetchFeed();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final buffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      if (state.playing != _isPlaying || buffering != _isBuffering) {
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = buffering;
        });
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
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, anim, __) => SoundSearchScreen(
            initialQuery: query,
            onPlay: _playTrack,
            currentTrack: _currentTrack,
            isPlaying: _isPlaying,
          ),
          transitionsBuilder: _fadeThroughTransition,
        ),
      );
    }
  }

  // Feed inicial: busca por termos de "populares agora" e mistura os
  // resultados. Roda de novo toda vez que a tela é reaberta, então o
  // conjunto varia entre sessões.
  Future<void> _fetchFeed() async {
    setState(() {
      _loadingFeed = true;
      _feedError = null;
    });

    try {
      final seed = _trendingSeeds[DateTime.now().second % _trendingSeeds.length];
      final searchResults = await _yt.search.search(seed);

      final tracks = <SoundTrack>[];
      for (final video in searchResults) {
        tracks.add(SoundTrack(
          title: video.title,
          artist: video.author,
          coverColorHex: _colorForSeed(video.id.value),
          thumbnailUrl: video.thumbnails.mediumResUrl,
          videoId: video.id.value,
        ));
        if (tracks.length >= 24) break;
      }

      if (!mounted) return;
      setState(() {
        _feed = tracks;
        _loadingFeed = false;
        _feedError = tracks.isEmpty ? 'Nenhuma música encontrada agora.' : null;
      });
    } catch (e) {
      debugPrint('Erro ao buscar feed: $e');
      if (!mounted) return;
      setState(() {
        _loadingFeed = false;
        _feedError = 'Não foi possível carregar o feed. Toque para tentar de novo.';
      });
    }
  }

  String _colorForSeed(String seed) {
    const palette = [
      '#2e8bc9',
      '#c9622e',
      '#7a4fd1',
      '#2ec9a0',
      '#d13f6a',
      '#c9a72e',
    ];
    final idx = seed.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length;
    return palette[idx];
  }

  Future<void> _playTrack(SoundTrack track) async {
    try {
      setState(() {
        _currentTrack = track;
        _isBuffering = true;
      });

      final manifest = await _yt.videos.streamsClient.getManifest(track.videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();

      await _player.setUrl(streamInfo.url.toString());
      await _player.play();

      if (!mounted) return;
      setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint('Erro ao tocar: $e');
      if (!mounted) return;
      setState(() {
        _isBuffering = false;
        _isPlaying = false;
      });
    }
  }

  void _togglePlay(SoundTrack track) {
    if (_currentTrack == track) {
      if (_player.playing) {
        _player.pause();
      } else {
        _player.play();
      }
    } else {
      _playTrack(track);
    }
  }

  void _onGlobalTogglePlay() {
    if (_currentTrack == null) return;
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _openApps() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, anim, __) => const AppsScreen(),
        transitionsBuilder: _fadeThroughTransition,
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, anim, __) => SoundSearchScreen(
          onPlay: _playTrack,
          currentTrack: _currentTrack,
          isPlaying: _isPlaying,
        ),
        transitionsBuilder: _fadeThroughTransition,
      ),
    );
  }

  static Widget _fadeThroughTransition(
      BuildContext context, Animation<double> anim, Animation<double> _, Widget child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
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
              _buildFeed(s),
              _SoundAppBar(s: s, onOpenApps: _openApps),
              _FloatingPlayerBar(
                s: s,
                currentTrack: _currentTrack,
                isPlaying: _isPlaying,
                isBuffering: _isBuffering,
                onTogglePlay: _onGlobalTogglePlay,
                onOpenFavorites: () {
                  // Navegar para favoritos
                },
                onOpenSearch: _openSearch,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildFeed(AppColorScheme s) {
    if (_loadingFeed) {
      return _FeedSkeleton(s: s);
    }
    if (_feedError != null && _feed.isEmpty) {
      return _FeedErrorState(s: s, message: _feedError!, onRetry: _fetchFeed);
    }
    return RefreshIndicator(
      onRefresh: _fetchFeed,
      color: s.primary,
      backgroundColor: s.cardBackground,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 88, 16, 128),
        itemCount: _feed.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.74,
        ),
        itemBuilder: (_, i) {
          final track = _feed[i];
          return _FeedCard(
            s: s,
            track: track,
            isCurrent: _currentTrack == track,
            isPlaying: _isPlaying && _currentTrack == track,
            isBuffering: _isBuffering && _currentTrack == track,
            onTap: () => _togglePlay(track),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CARD DE FEED (retangular, com capa + título + artista)
// ══════════════════════════════════════════════════════════════

class _FeedCard extends StatefulWidget {
  final AppColorScheme s;
  final SoundTrack track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTap;

  const _FeedCard({
    required this.s,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.isBuffering,
    required this.onTap,
  });

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final track = widget.track;
    final cover = Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF')));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: s.cardShadowSoft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: cover),
                    if (track.thumbnailUrl != null)
                      Image.network(
                        track.thumbnailUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(color: cover);
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: cover,
                          child: const Icon(Icons.music_note,
                              color: Colors.white, size: 34),
                        ),
                      )
                    else
                      const Center(
                        child: Icon(Icons.music_note,
                            color: Colors.white, size: 34),
                      ),
                    // Gradiente + botão de play/pause sobre a capa
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.0),
                              Colors.black.withOpacity(widget.isCurrent ? 0.35 : 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: widget.isCurrent ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: widget.isBuffering
                                ? const Padding(
                                    padding: EdgeInsets.all(9),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    widget.isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: s.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON LOADER DO FEED
// ══════════════════════════════════════════════════════════════

class _FeedSkeleton extends StatefulWidget {
  final AppColorScheme s;
  const _FeedSkeleton({required this.s});
  @override
  State<_FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<_FeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 128),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (_, i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final opacity = 0.35 + 0.25 * _controller.value;
            return Container(
              decoration: BoxDecoration(
                color: s.cardBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: s.hover.withOpacity(opacity),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 11,
                          width: 90,
                          decoration: BoxDecoration(
                            color: s.hover.withOpacity(opacity),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 9,
                          width: 60,
                          decoration: BoxDecoration(
                            color: s.hover.withOpacity(opacity),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ESTADO DE ERRO DO FEED
// ══════════════════════════════════════════════════════════════

class _FeedErrorState extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  final VoidCallback onRetry;
  const _FeedErrorState({required this.s, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: s.onSurfaceVariant, size: 40),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// APPBAR — botão de apps 100% circular
// ══════════════════════════════════════════════════════════════

class _SoundAppBar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onOpenApps;
  const _SoundAppBar({required this.s, required this.onOpenApps});

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
            _CircularIconButton(
              s: s,
              size: 40,
              onTap: onOpenApps,
              child: Image.asset(
                'assets/icons/png/apps.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Botão circular reutilizável (mesma base do ScreenBackButton)
class _CircularIconButton extends StatefulWidget {
  final AppColorScheme s;
  final double size;
  final VoidCallback onTap;
  final Widget child;
  const _CircularIconButton({
    required this.s,
    required this.size,
    required this.onTap,
    required this.child,
  });

  @override
  State<_CircularIconButton> createState() => _CircularIconButtonState();
}

class _CircularIconButtonState extends State<_CircularIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: widget.s.cardShadow,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BARRA FLUTUANTE — cápsula central + 2 círculos soltos (ref. imagem)
// ══════════════════════════════════════════════════════════════

class _FloatingPlayerBar extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack? currentTrack;
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTogglePlay;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenSearch;

  const _FloatingPlayerBar({
    required this.s,
    required this.currentTrack,
    required this.isPlaying,
    required this.isBuffering,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CircularIconButton(
            s: s,
            size: 56,
            onTap: onOpenFavorites,
            child: Icon(Icons.bookmark_border, color: s.onSurface, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axis: Axis.horizontal,
                  child: child,
                ),
              ),
              child: currentTrack == null
                  ? _PlayerSkeletonPill(key: const ValueKey('skeleton'), s: s)
                  : _PlayerPill(
                      key: ValueKey(currentTrack!.videoId),
                      s: s,
                      track: currentTrack!,
                      isPlaying: isPlaying,
                      isBuffering: isBuffering,
                      onTogglePlay: onTogglePlay,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          _CircularIconButton(
            s: s,
            size: 56,
            onTap: onOpenSearch,
            child: Icon(Icons.search, color: s.onSurface, size: 22),
          ),
        ],
      ),
    );
  }
}

// Cápsula escura com capa + título/artista + botão play/pause
class _PlayerPill extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack track;
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTogglePlay;
  const _PlayerPill({
    super.key,
    required this.s,
    required this.track,
    required this.isPlaying,
    required this.isBuffering,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    final cover = Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF')));
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: s.playerBarBackground,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40,
              height: 40,
              child: track.thumbnailUrl != null
                  ? Image.network(
                      track.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(color: cover),
                    )
                  : ColoredBox(
                      color: cover,
                      child: const Icon(Icons.music_note,
                          color: Colors.white, size: 18),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTogglePlay,
            child: SizedBox(
              width: 36,
              height: 36,
              child: isBuffering
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Skeleton loader da cápsula, no formato exato do player real
class _PlayerSkeletonPill extends StatefulWidget {
  final AppColorScheme s;
  const _PlayerSkeletonPill({super.key, required this.s});
  @override
  State<_PlayerSkeletonPill> createState() => _PlayerSkeletonPillState();
}

class _PlayerSkeletonPillState extends State<_PlayerSkeletonPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
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
      builder: (_, __) {
        final baseOpacity = 0.12 + 0.06 * _controller.value;
        final blockOpacity = 0.18 + 0.10 * _controller.value;
        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: s.playerBarBackground.withOpacity(0.6 + baseOpacity),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(blockOpacity),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 11,
                      width: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(blockOpacity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 9,
                      width: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(blockOpacity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(blockOpacity),
                  shape: BoxShape.circle,
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
// TELA DE PESQUISA
// ══════════════════════════════════════════════════════════════

class SoundSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final Future<void> Function(SoundTrack) onPlay;
  final SoundTrack? currentTrack;
  final bool isPlaying;

  const SoundSearchScreen({
    super.key,
    this.initialQuery,
    required this.onPlay,
    required this.currentTrack,
    required this.isPlaying,
  });

  @override
  State<SoundSearchScreen> createState() => _SoundSearchScreenState();
}

class _SoundSearchScreenState extends State<SoundSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final YoutubeExplode _yt = YoutubeExplode();

  String _query = '';
  List<SoundTrack> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _ctrl.text = widget.initialQuery!;
      _query = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _yt.close();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final searchResults = await _yt.search.search(query);
      final tracks = <SoundTrack>[];
      for (final video in searchResults) {
        tracks.add(SoundTrack(
          title: video.title,
          artist: video.author,
          coverColorHex: '#2e8bc9',
          thumbnailUrl: video.thumbnails.mediumResUrl,
          videoId: video.id.value,
        ));
        if (tracks.length >= 25) break;
      }
      if (!mounted) return;
      setState(() {
        _results = tracks;
        _loading = false;
        _error = tracks.isEmpty ? 'Sem resultados para "$query"' : null;
      });
    } catch (e) {
      debugPrint('Erro na pesquisa: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível pesquisar agora. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
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
                            onChanged: _onChanged,
                            onSubmitted: _performSearch,
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
                                _error = null;
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
                      child: AppIcon('close', color: s.onSurfaceVariant, size: 16),
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
      return _SearchResultsSkeleton(key: const ValueKey('loading'), s: s);
    }
    if (_error != null && _results.isEmpty) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('results'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final track = _results[i];
        return _SearchResultTile(
          s: s,
          track: track,
          isCurrent: widget.currentTrack == track,
          isPlaying: widget.isPlaying && widget.currentTrack == track,
          onTap: () => widget.onPlay(track),
        );
      },
    );
  }
}

class _SearchResultsSkeleton extends StatefulWidget {
  final AppColorScheme s;
  const _SearchResultsSkeleton({super.key, required this.s});
  @override
  State<_SearchResultsSkeleton> createState() => _SearchResultsSkeletonState();
}

class _SearchResultsSkeletonState extends State<_SearchResultsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final opacity = 0.35 + 0.25 * _controller.value;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: s.cardBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: s.hover.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 140,
                        decoration: BoxDecoration(
                          color: s.hover.withOpacity(opacity),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 90,
                        decoration: BoxDecoration(
                          color: s.hover.withOpacity(opacity),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            );
          },
        );
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
              style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
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
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  const _SearchResultTile({
    required this.s,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cover = Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF')));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent ? s.primary.withOpacity(0.08) : s.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: s.cardShadow,
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40,
              height: 40,
              child: track.thumbnailUrl != null
                  ? Image.network(
                      track.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(color: cover),
                    )
                  : ColoredBox(
                      color: cover,
                      child: const Icon(Icons.music_note,
                          color: Colors.white, size: 20),
                    ),
            ),
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
          const SizedBox(width: 8),
          Icon(
            isCurrent && isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: isCurrent ? s.primary : s.onSurfaceVariant,
            size: 28,
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TELA DE APPS — aberta ao tocar no botão circular de apps
// ══════════════════════════════════════════════════════════════
//
// PLACEHOLDER: não tenho a lista real dos apps do seu aplicativo, então
// isto está com 6 itens de exemplo. Troque `_placeholderApps` pela sua
// lista real (ou me passe os nomes/rotas que eu encaixo aqui).

class _AppEntry {
  final String name;
  final IconData icon;
  final VoidCallback? onTap;
  const _AppEntry({required this.name, required this.icon, this.onTap});
}

class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key});

  static const List<_AppEntry> _placeholderApps = [
    _AppEntry(name: 'Sound', icon: Icons.music_note),
    _AppEntry(name: 'Chat', icon: Icons.chat_bubble),
    _AppEntry(name: 'Notas', icon: Icons.note_alt),
    _AppEntry(name: 'Calendário', icon: Icons.calendar_today),
    _AppEntry(name: 'Câmera', icon: Icons.camera_alt),
    _AppEntry(name: 'Fotos', icon: Icons.photo_library),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      color: s.pageBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  ScreenBackButton(s: s),
                  const SizedBox(width: 12),
                  Text(
                    'Apps',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: s.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _placeholderApps.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (_, i) {
                  final app = _placeholderApps[i];
                  return _AppTile(s: s, app: app, index: i);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppTile extends StatefulWidget {
  final AppColorScheme s;
  final _AppEntry app;
  final int index;
  const _AppTile({required this.s, required this.app, required this.index});

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _enterAnim;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _enterAnim = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 30 * widget.index), () {
      if (mounted) _enterController.forward();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return FadeTransition(
      opacity: _enterAnim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(_enterAnim),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.app.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: s.cardBackground,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: s.cardShadowSoft,
                  ),
                  child: Icon(widget.app.icon, color: s.primary, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: s.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO VOLTAR REUTILIZÁVEL
// ══════════════════════════════════════════════════════════════

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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40,
          height: 40,
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