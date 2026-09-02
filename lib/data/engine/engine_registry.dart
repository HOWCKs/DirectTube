import '../engine/download_engine.dart';

/// Escolhe o motor certo para cada link.
///
/// Ordem importa: motores mais específicos primeiro (YouTube nativo) e o
/// genérico (yt-dlp) por último, como fallback para qualquer outro site.
class EngineRegistry {
  EngineRegistry(List<DownloadEngine> engines)
      : _engines = List<DownloadEngine>.unmodifiable(engines);

  final List<DownloadEngine> _engines;

  List<DownloadEngine> get engines => _engines;

  DownloadEngine? byId(String id) {
    for (final DownloadEngine engine in _engines) {
      if (engine.id == id) return engine;
    }
    return null;
  }

  /// Motores que aceitam o link pela sintaxe (sem consultar a rede).
  List<DownloadEngine> candidatesFor(String url) => _engines
      .where((DownloadEngine engine) => engine.canHandle(url))
      .toList(growable: false);

  /// Primeiro motor que aceita o link E está disponível no dispositivo.
  Future<DownloadEngine?> firstAvailableFor(String url) async {
    for (final DownloadEngine engine in candidatesFor(url)) {
      if (await engine.isAvailable()) return engine;
    }
    return null;
  }

  /// Resolve por id guardado na tarefa (retomar download) com fallback.
  Future<DownloadEngine?> resolveForTask({
    String? engineId,
    required String url,
  }) async {
    if (engineId != null) {
      final DownloadEngine? preferred = byId(engineId);
      if (preferred != null && await preferred.isAvailable()) return preferred;
    }
    return firstAvailableFor(url);
  }

  Future<void> dispose() async {
    for (final DownloadEngine engine in _engines) {
      await engine.dispose();
    }
  }
}
