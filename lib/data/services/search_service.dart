import '../engine/engine_registry.dart';
import '../engine/youtube_explode_engine.dart';
import '../models/media_item.dart';

/// Busca de mídia. Hoje delega ao motor YouTube nativo; novos motores entram
/// aqui sem alterar nenhuma tela.
class SearchService {
  SearchService(this._registry);

  final EngineRegistry _registry;

  YoutubeExplodeEngine? get _youtube =>
      _registry.byId('youtube-explode') as YoutubeExplodeEngine?;

  Future<List<MediaItem>> search(String query) async {
    final YoutubeExplodeEngine? engine = _youtube;
    if (engine == null || query.trim().isEmpty) return const <MediaItem>[];
    final results = await engine.searchPage(query);
    return engine.mapResults(results);
  }
}
