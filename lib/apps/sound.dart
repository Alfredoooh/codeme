import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors.dart';
import '../widgets.dart';

class SoundTrack {
  final String title;
  final String artist;
  final String coverColorHex;
  const SoundTrack({required this.title, required this.artist, required this.coverColorHex});
}

class SoundTabController extends ChangeNotifier {
  String? _pendingSearch;
  String? get pendingSearch => _pendingSearch;

  void requestSearch(String query) {
    _pendingSearch = query;
    notifyListeners();
  }

  void consumePendingSearch() {
    _pendingSearch = null;
  }
}

final SoundTabController soundTabController = SoundTabController();

class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key});
  @override State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> with ThemeReactive<SoundScreen> {
  List<SoundTrack> _tracks = _mockTracks('');
  int? _playingIndex;

  @override
  void initState() {
    super.initState();
    soundTabController.addListener(_onPendingSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingSearch());
  }

  @override
  void dispose() {
    soundTabController.removeListener(_onPendingSearch);
    super.dispose();
  }

  void _onPendingSearch() {
    final query = soundTabController.pendingSearch;
    if (query == null) return;
    setState(() {
      _tracks = _mockTracks(query);
      _playingIndex = null;
    });
    soundTabController.consumePendingSearch();
  }

  static List<SoundTrack> _mockTracks(String query) {
    final base = query.trim().isEmpty ? 'Sugestões' : query.trim();
    const covers = ['#2e8bc9', '#c92e6b', '#8bc92e', '#c9962e', '#6b2ec9'];
    return List.generate(5, (i) => SoundTrack(
          title: '$base — Faixa ${i + 1}',
          artist: 'Artista ${i + 1}',
          coverColorHex: covers[i % covers.length],
        ));
  }

  void _togglePlay(int index) {
    setState(() => _playingIndex = _playingIndex == index ? null : index);
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
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 70, 16, 24),
                itemCount: _tracks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _TrackRow(
                  s: s, track: _tracks[i], playing: _playingIndex == i,
                  onTap: () => _togglePlay(i),
                ),
              ),
              _SoundHeader(s: s),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SoundHeader extends StatelessWidget {
  final AppColorScheme s;
  const _SoundHeader({required this.s});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [s.pageBackground, s.pageBackground.withOpacity(0.0)],
          ),
        ),
        child: Row(children: [
          ScreenBackButton(s: s),
          const SizedBox(width: 6),
          Text('Sound', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: s.onSurface)),
        ]),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack track;
  final bool playing;
  final VoidCallback onTap;
  const _TrackRow({required this.s, required this.track, required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF')));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: s.cardBackground, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: cover, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.music_note, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: s.onSurface)),
              const SizedBox(height: 2),
              Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant)),
            ]),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: s.primary, shape: BoxShape.circle),
            child: Icon(playing ? Icons.pause : Icons.play_arrow, color: s.onPrimary, size: 20),
          ),
        ]),
      ),
    );
  }
}

class ScreenBackButton extends StatefulWidget {
  final AppColorScheme s;
  const ScreenBackButton({super.key, required this.s});
  @override State<ScreenBackButton> createState() => _ScreenBackButtonState();
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
          decoration: BoxDecoration(color: widget.s.cardBackground, shape: BoxShape.circle),
          child: AppIcon('back.svg', size: 20, color: widget.s.onSurface),
        ),
      ),
    );
  }
}