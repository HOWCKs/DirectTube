import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/link_parser.dart';
import '../models/format_option.dart';
import '../models/media_item.dart';
import 'download_engine.dart';

/// Motor YouTube implementado 100% em Dart (`youtube_explode_dart`).
///
/// Vantagens: nenhum runtime Python no APK, início instantâneo, sem bridge
/// nativa. Limitação honesta: formatos acima de 720p exigem juntar vídeo e
/// áudio (muxing), o que depende do módulo FFmpeg — por isso esses formatos
/// são expostos com `needsMuxing: true` e a UI os mostra como indisponíveis.
class YoutubeExplodeEngine implements DownloadEngine {
  YoutubeExplodeEngine({YoutubeExplode? client})
      : _client = client ?? YoutubeExplode();

  final YoutubeExplode _client;

  /// Intervalo mínimo entre emissões de progresso (evita afogar a UI).
  static const Duration _throttle = Duration(milliseconds: 150);

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

  /// Busca real no YouTube (não usa API paga nem chave).
  Future<List<MediaItem>> search(String query, {int limit = 24}) async {
    if (query.trim().isEmpty) return const <MediaItem>[];
    final List<Video> results =
        await _client.search.search(query, filter: TypeFilters.video);
    return results
        .take(limit)
        .map((Video video) => MediaItem(
              id: video.id.value,
              title: video.title,
              sourceUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
              host: MediaHost.youtube,
              author: video.author,
              duration: video.duration,
              thumbnailUrl: video.thumbnails.mediumResUrl,
              engineId: id,
            ))
        .toList(growable: false);
  }

  @override
  Future<MediaItem> resolve(String url) async {
    final ParsedLink? parsed = LinkParser.parse(url);
    final String? videoId = parsed?.videoId;
    if (videoId == null) {
      throw const EngineException('Não encontrei um ID de vídeo nesse link.');
    }

    final Video video = await _client.videos.get(videoId);
    return MediaItem(
      id: video.id.value,
      title: video.title,
      sourceUrl: url,
      host: MediaHost.youtube,
      author: video.author,
      duration: video.duration,
      thumbnailUrl: video.thumbnails.mediumResUrl,
      engineId: id,
    );
  }

  @override
  Future<List<FormatOption>> formatsFor(MediaItem item) async {
    final StreamManifest manifest =
        await _client.videos.streamsClient.getManifest(item.id);

    final List<FormatOption> options = <FormatOption>[];

    // Progressivos (vídeo + áudio no mesmo arquivo): prontos para salvar.
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

    // Só áudio: M4A/WebM prontos para a biblioteca de música.
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

    // Alta resolução (1080p+): vídeo separado do áudio -> precisa de FFmpeg.
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

    options.sort((FormatOption a, FormatOption b) =>
        b.sortKey.compareTo(a.sortKey));
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

    final StreamManifest manifest =
        await _client.videos.streamsClient.getManifest(item.id);

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
      await for (final List<int> chunk in _client.videos.streamsClient.get(info)) {
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
    } catch (_) {
      await sink.close();
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // Arquivo parcial pode já ter sido removido.
        }
      }
      rethrow;
    }

    yield DownloadProgress(
      receivedBytes: received,
      totalBytes: totalBytes ?? received,
      speedBytesPerSecond: _speed(received, stopwatch),
    );
  }

  double _speed(int received, Stopwatch stopwatch) {
    final double seconds = stopwatch.elapsedMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return received / seconds;
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}
