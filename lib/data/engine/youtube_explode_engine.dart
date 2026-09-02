import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/errors.dart';
import '../../core/link_parser.dart';
import '../models/format_option.dart';
import '../models/media_item.dart';
import 'download_engine.dart';

/// Cliente HTTP com cara de navegador real (reduz rate-limit do YouTube).
class _BrowserHttpClient extends YoutubeHttpClient {
  _BrowserHttpClient() : super();

  @override
  Map<String, String> get headers => <String, String>{
        ...super.headers,
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 '
            'Mobile Safari/537.36',
        'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
      };
}

/// Motor YouTube implementado 100% em Dart (`youtube_explode_dart`).
///
/// Resiliência contra rate-limit (erro visto em IP de operadora móvel):
///   * `User-Agent` de navegador real;
///   * retry com backoff em `RequestLimitExceededException`/transientes;
///   * cache de manifesto por vídeo (abrir o painel 2x não refaz pedidos).
///
/// Limitação honesta: acima de 720p o YouTube serve vídeo e áudio separados;
/// juntar os dois pede FFmpeg, então esses formatos vêm `needsMuxing: true`
/// e a UI os mostra como indisponíveis.
class YoutubeExplodeEngine implements DownloadEngine {
  YoutubeExplodeEngine({YoutubeExplode? client})
      : _client = client ?? YoutubeExplode(httpClient: _BrowserHttpClient());

  final YoutubeExplode _client;

  static const int _maxAttempts = 3;
  static const Duration _throttle = Duration(milliseconds: 150);
  static const Duration _manifestTtl = Duration(minutes: 5);

  final Map<String, _CachedManifest> _manifestCache =
      <String, _CachedManifest>{};

  @override
  String get id => 'youtube-explode';

  @override
  String get displayName => 'YouTube (nativo)';

  @override
  bool canHandle(String url) {
    final ParsedLink? parsed = LinkParser.parse(url);
    return parsed != null &&
        parsed.host == MediaHost.youtube &&
        parsed.videoId != null;
  }

  @override
  Future<bool> isAvailable() async => true;

  /// Retry com backoff para erros transientes e de limite de pedidos.
  Future<T> _retry<T>(Future<T> Function() operation) async {
    Object? lastError;
    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        return await operation();
      } on RequestLimitExceededException catch (error) {
        lastError = error;
        await Future<void>.delayed(
            Duration(milliseconds: 800 * (attempt + 1) * (attempt + 1)));
      } on TransientFailureException catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw EngineException(friendlyError(lastError ?? 'Falha de rede.'));
  }

  MediaItem _toItem(Video video, String sourceUrl) => MediaItem(
        id: video.id.value,
        title: video.title,
        sourceUrl: sourceUrl,
        host: MediaHost.youtube,
        author: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.mediumResUrl,
        engineId: id,
      );

  @override
  Future<MediaItem> resolve(String url) async {
    final ParsedLink? parsed = LinkParser.parse(url);
    final String? videoId = parsed?.videoId;
    if (videoId == null) {
      throw const EngineException('Não encontrei um ID de vídeo nesse link.');
    }
    final Video video = await _retry(() => _client.videos.get(videoId));
    return _toItem(video, url);
  }

  /// Busca real no YouTube. Retorna a primeira página (rolável via [moreResults]).
  /// Quem chama garante `query` não vazia.
  Future<VideoSearchList> searchPage(String query) {
    return _retry(() => _client.search.search(query, filter: TypeFilters.video));
  }

  /// Próxima página da busca (rolagem infinita). `null` quando acabou.
  Future<VideoSearchList?> moreResults(VideoSearchList current) {
    return _retry(() => current.nextPage());
  }

  List<MediaItem> mapResults(VideoSearchList page, {int limit = 30}) => page
      .take(limit)
      .map((Video video) => _toItem(
          video, 'https://www.youtube.com/watch?v=${video.id.value}'))
      .toList(growable: false);

  Future<StreamManifest> _manifest(String videoId) async {
    final _CachedManifest? cached = _manifestCache[videoId];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _manifestTtl) {
      return cached.manifest;
    }
    final StreamManifest manifest = await _retry(
        () => _client.videos.streamsClient.getManifest(videoId));
    _manifestCache[videoId] =
        _CachedManifest(manifest: manifest, at: DateTime.now());
    return manifest;
  }

  @override
  Future<List<FormatOption>> formatsFor(MediaItem item) async {
    final StreamManifest manifest = await _manifest(item.id);

    final List<FormatOption> options = <FormatOption>[];

    for (final MuxedStreamInfo stream in manifest.muxed) {
      final int? height = stream.videoResolution.height;
      options.add(FormatOption(
        id: stream.tag.toString(),
        label: '${height ?? 0}p ${stream.container.name.toUpperCase()}',
        extension: stream.container.name,
        isAudioOnly: false,
        height: height,
        bitrateKbps: stream.bitrate.kiloBitsPerSecond.round(),
        sizeBytes: stream.size.totalBytes,
      ));
    }

    for (final AudioOnlyStreamInfo stream in manifest.audioOnly) {
      final String ext = stream.container.name;
      final int kbps = stream.bitrate.kiloBitsPerSecond.round();
      options.add(FormatOption(
        id: stream.tag.toString(),
        label: '${ext.toUpperCase()} ${kbps}k',
        extension: ext,
        isAudioOnly: true,
        bitrateKbps: kbps,
        sizeBytes: stream.size.totalBytes,
      ));
    }

    for (final VideoOnlyStreamInfo stream in manifest.videoOnly) {
      final int? height = stream.videoResolution.height;
      if (height == null || height <= 720) continue;
      options.add(FormatOption(
        id: stream.tag.toString(),
        label: '${height}p ${stream.container.name.toUpperCase()}',
        extension: stream.container.name,
        isAudioOnly: false,
        height: height,
        bitrateKbps: stream.bitrate.kiloBitsPerSecond.round(),
        sizeBytes: stream.size.totalBytes,
        needsMuxing: true,
      ));
    }

    if (options.isEmpty) {
      throw const EngineException(
        'Este conteúdo não expõe formatos baixáveis agora. Tente novamente.',
      );
    }
    options.sort(
        (FormatOption a, FormatOption b) => b.sortKey.compareTo(a.sortKey));
    return options;
  }

  @override
  Stream<DownloadProgress> download({
    required MediaItem item,
    required FormatOption format,
    required String outputPath,
    CancellationToken? token,
  }) async* {
    if (format.needsMuxing) {
      throw const EngineException(
        'Este formato precisa combinar vídeo e áudio (módulo FFmpeg).',
      );
    }

    final StreamManifest manifest = await _manifest(item.id);

    final int? tag = int.tryParse(format.id);
    StreamInfo? info;
    for (final StreamInfo candidate in manifest.streams) {
      if (candidate.tag == tag) {
        info = candidate;
        break;
      }
    }
    if (info == null) {
      throw EngineException('O formato ${format.label} não está mais disponível.');
    }

    final File file = File(outputPath);
    await file.parent.create(recursive: true);

    final IOSink sink = file.openWrite();
    final Stopwatch stopwatch = Stopwatch()..start();
    final int? totalBytes = info.size.totalBytes;
    int received = 0;
    DateTime lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      await for (final List<int> chunk
          in _client.videos.streamsClient.get(info)) {
        if (token?.isCanceled ?? false) {
          throw const DownloadCanceledException();
        }
        sink.add(chunk);
        received += chunk.length;

        final DateTime now = DateTime.now();
        if (now.difference(lastEmit) >= _throttle) {
          lastEmit = now;
          yield DownloadProgress(
            receivedBytes: received,
            totalBytes: totalBytes,
            speedBytesPerSecond: _speed(received, stopwatch),
          );
        }
      }
      await sink.flush();
      await sink.close();
    } on RequestLimitExceededException catch (error) {
      await sink.close();
      await _deletePartial(file);
      throw EngineException(friendlyError(error));
    } catch (_) {
      await sink.close();
      await _deletePartial(file);
      rethrow;
    }

    yield DownloadProgress(
      receivedBytes: received,
      totalBytes: totalBytes ?? received,
      speedBytesPerSecond: _speed(received, stopwatch),
    );
  }

  Future<void> _deletePartial(File file) async {
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {
        // Parcial já removido.
      }
    }
  }

  double _speed(int received, Stopwatch stopwatch) {
    final double seconds = stopwatch.elapsedMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return received / seconds;
  }

  @override
  Future<void> dispose() async {
    _manifestCache.clear();
    _client.close();
  }
}

class _CachedManifest {
  const _CachedManifest({required this.manifest, required this.at});

  final StreamManifest manifest;
  final DateTime at;
}
