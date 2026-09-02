import '../engine/engine_registry.dart';
import '../engine/youtube_explode_engine.dart';
import '../models/media_item.dart';

/// Busca de mídia. Hoje delega ao motor YouTube nativo; novos motores entram
/// aqui sem alterar nenhuma tela.
class SearchService {
  SearchService(this._registry);

  final EngineRegistry _registry;

  Future<List<MediaItem>> search(String query) async {
    final YoutubeExplodeEngine? engine =
        _registry.byId('youtube-explode') as YoutubeExplodeEngine?;
    if (engine == null) return const <MediaItem>[];
    return engine.search(query);
  }
}
