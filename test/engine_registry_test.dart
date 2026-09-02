import 'package:directtube/core/link_parser.dart';
import 'package:directtube/data/engine/download_engine.dart';
import 'package:directtube/data/engine/engine_registry.dart';
import 'package:directtube/data/models/format_option.dart';
import 'package:directtube/data/models/media_item.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEngine implements DownloadEngine {
  _FakeEngine(
    this.id, {
    this.available = true,
    this.youTubeOnly = false,
  });

  @override
  final String id;

  final bool available;
  final bool youTubeOnly;

  int resolveCalls = 0;

  @override
  String get displayName => 'Fake $id';

  @override
  bool canHandle(String url) =>
      !youTubeOnly || url.contains('youtube.com') || url.contains('youtu.be');

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<MediaItem> resolve(String url) async {
    resolveCalls++;
    return MediaItem(
      id: id,
      title: 'Resolvido por $id',
      sourceUrl: url,
      host: MediaHost.generic,
      engineId: id,
    );
  }

  @override
  Future<List<FormatOption>> formatsFor(MediaItem item) async =>
      const <FormatOption>[];

  @override
  Stream<DownloadProgress> download({
    required MediaItem item,
    required FormatOption format,
    required String outputPath,
    CancellationToken? token,
  }) async* {
    yield const DownloadProgress(receivedBytes: 10, totalBytes: 10);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  const String youTubeUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  const String otherUrl = 'https://vimeo.com/76979871';

  group('EngineRegistry', () {
    test('prefere o primeiro motor que aceita E está disponível', () async {
      final _FakeEngine native = _FakeEngine('youtube-explode');
      final _FakeEngine ytdlp = _FakeEngine('yt-dlp');
      final EngineRegistry registry =
          EngineRegistry(<DownloadEngine>[native, ytdlp]);

      final DownloadEngine? chosen =
          await registry.firstAvailableFor(youTubeUrl);
      expect(chosen?.id, 'youtube-explode');
      expect(registry.candidatesFor(youTubeUrl).length, 2);
    });

    test('cai para o motor genérico em outros sites', () async {
      final _FakeEngine native =
          _FakeEngine('youtube-explode', youTubeOnly: true);
      final _FakeEngine ytdlp = _FakeEngine('yt-dlp');
      final EngineRegistry registry =
          EngineRegistry(<DownloadEngine>[native, ytdlp]);

      expect(registry.candidatesFor(otherUrl).length, 1);
      expect((await registry.firstAvailableFor(otherUrl))?.id, 'yt-dlp');
    });

    test('pula motor indisponível (yt-dlp fora do build)', () async {
      final _FakeEngine native =
          _FakeEngine('youtube-explode', youTubeOnly: true);
      final _FakeEngine ytdlp = _FakeEngine('yt-dlp', available: false);
      final EngineRegistry registry =
          EngineRegistry(<DownloadEngine>[native, ytdlp]);

      expect(await registry.firstAvailableFor(otherUrl), isNull);
      expect((await registry.firstAvailableFor(youTubeUrl))?.id,
          'youtube-explode');
    });

    test('resolveForTask usa o motor gravado na tarefa', () async {
      final _FakeEngine native = _FakeEngine('youtube-explode');
      final _FakeEngine ytdlp = _FakeEngine('yt-dlp');
      final EngineRegistry registry =
          EngineRegistry(<DownloadEngine>[native, ytdlp]);

      final DownloadEngine? chosen = await registry.resolveForTask(
        engineId: 'yt-dlp',
        url: youTubeUrl,
      );
      expect(chosen?.id, 'yt-dlp');
    });

    test('resolveForTask cai no padrão quando o motor gravado sumiu', () async {
      final _FakeEngine native = _FakeEngine('youtube-explode');
      final EngineRegistry registry =
          EngineRegistry(<DownloadEngine>[native]);

      final DownloadEngine? chosen = await registry.resolveForTask(
        engineId: 'motor-removido',
        url: youTubeUrl,
      );
      expect(chosen?.id, 'youtube-explode');
    });

    test('byId', () {
      final _FakeEngine native = _FakeEngine('youtube-explode');
      final EngineRegistry registry =
          EngineRegistry(<DownloadEngine>[native]);
      expect(registry.byId('youtube-explode'), same(native));
      expect(registry.byId('nada'), isNull);
    });

    test('dispose encerra todos os motores', () async {
      final EngineRegistry registry = EngineRegistry(<DownloadEngine>[
        _FakeEngine('a'),
        _FakeEngine('b'),
      ]);
      await registry.dispose();
    });
  });

  group('DownloadProgress', () {
    test('fração calculada e truncada', () {
      expect(
        const DownloadProgress(receivedBytes: 5, totalBytes: 20).fraction,
        0.25,
      );
      expect(
        const DownloadProgress(receivedBytes: 99, totalBytes: 20).fraction,
        1.0,
      );
      expect(const DownloadProgress(receivedBytes: 99).fraction, 0);
    });
  });

  group('CancellationToken', () {
    test('começa livre e trava ao cancelar', () {
      final CancellationToken token = CancellationToken();
      expect(token.isCanceled, isFalse);
      token.cancel();
      expect(token.isCanceled, isTrue);
    });
  });
}
