import 'package:flutter/material.dart';

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

class SoundSection {
  final String title;
  final List<SoundTrack> tracks;
  const SoundSection({required this.title, required this.tracks});
}

/// Categoria de música mostrada como chip/filtro no topo do feed.
/// `seedQuery` é o termo usado para popular a secção correspondente.
class SoundCategory {
  final String id;
  final String label;
  final String seedQuery;
  const SoundCategory({
    required this.id,
    required this.label,
    required this.seedQuery,
  });
}

/// Lista fixa de categorias. Os termos de pesquisa (`seedQuery`) são
/// escolhas razoáveis para o YouTube devolver resultados musicais —
/// não há garantia de cobertura perfeita por género, isso depende do
/// que o `youtube_explode_dart` encontrar em cada pesquisa.
const List<SoundCategory> kSoundCategories = [
  SoundCategory(id: 'for_you', label: 'Para si', seedQuery: 'músicas mais tocadas agora'),
  SoundCategory(id: 'top', label: 'Em alta', seedQuery: 'top hits 2026'),
  SoundCategory(id: 'pop', label: 'Pop', seedQuery: 'pop music hits'),
  SoundCategory(id: 'hiphop', label: 'Hip-Hop', seedQuery: 'hip hop rap hits'),
  SoundCategory(id: 'rock', label: 'Rock', seedQuery: 'rock songs classic'),
  SoundCategory(id: 'electronic', label: 'Eletrónica', seedQuery: 'electronic dance music'),
  SoundCategory(id: 'rnb', label: 'R&B', seedQuery: 'rnb soul music'),
  SoundCategory(id: 'chill', label: 'Relaxar', seedQuery: 'chill lofi music'),
];

/// Controller para pesquisa global (ex.: pedida a partir de outro tab).
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

/// Estado de reprodução partilhado entre a barra flutuante e o full player,
/// para que ambos reflitam exatamente o mesmo estado do AudioPlayer.
enum PlaybackStatus { idle, buffering, playing, paused, error }