import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/link_parser.dart';
import '../models/format_option.dart';
import '../models/media_item.dart';
import 'download_engine.dart';

/// Motor nativo baseado no **NewPipeExtractor** (a mesma tecnologia de
/// extração do NewPipe), ponte via MethodChannel `com.directtube.app/newpipe`.
///
/// O lado nativo é opcional: se o módulo não estiver no build, [isAvailable]
/// devolve `false` e o registry cai no motor Dart. O download em si baixa as
/// URLs diretas retornadas pelo extractor, com progresso e cancelamento.
class NewPipeEngine implements DownloadEngine {
  NewPipeEngine();

  static const MethodChannel _channel =
      MethodChannel('com.directtube.app/newpipe');

  bool? _available;
  final http.Client _http = http.Client();

  @override
  String get id => 'newpipe';

  @override
  String get displayName => 'NewPipeExtractor (nativo)';

  @override
  bool canHandle(String url) => LinkParser.parse(url) != null;

  @override
  Future<bool> isAvailable() async {
    final bool? cached = _available;
    if (cached != null) return cached;
    try {
      _available = await _channel.invokeMethod<bool>('np_isAvailable') ?? false;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
    return _available ?? false;
  }

  @override
  Future<MediaItem> resolve(String url) async {
    final Map<Object?, Object?>? raw =
        await _channel.invokeMapMethod<Object?, Object?>('np_resolve', <String, dynamic>{
      'url': url,
    });
    if (raw == null) {
      throw const EngineException('Não consegui resolver este link (NewPipe).');
    }
    final ParsedLink? parsed = LinkParser.parse(url);
    return MediaItem(
      id: (raw['id'] as String?) ?? (parsed?.videoId ?? url),
      title: (raw['title'] as String?) ?? 'Sem título',
      sourceUrl: url,
      host: MediaHost.youtube,
      author: (raw['author'] as String?)?.isEmpty ?? true
          ? null
          : raw['author'] as String?,
      duration: Duration(
          seconds: ((raw['durationSeconds'] as num?) ?? 0).toInt()),
      thumbnailUrl: (raw['thumbnailUrl'] as String?)?.isEmpty ?? true
          ? null
          : raw['thumbnailUrl'] as String?,
      engineId: id,
    );
  }

  @override
  Future<List<FormatOption>> formatsFor(MediaItem item) async {
    final List<Object?>? raw =
        await _channel.invokeListMethod<Object?>('np_formats', <String, dynamic>{
      'url': item.sourceUrl,
    });
    if (raw == null || raw.isEmpty) {
      throw const EngineException(
          'Este conteúdo não expõe formatos baixáveis (NewPipe).');
    }

    final List<FormatOption> options = <FormatOption>[];
    for (final Object? entry in raw) {
      final Map<Object?, Object?> map = entry! as Map<Object?, Object?>;
      final String? url = map['url'] as String?;
      if (url == null || url.isEmpty) continue;
      options.add(FormatOption(
        id: url,
        label: (map['label'] as String?) ?? 'formato',
        extension: (map['ext'] as String?) ?? 'mp4',
        isAudioOnly: (map['audioOnly'] as bool?) ?? false,
        height: (map['height'] as num?)?.toInt(),
        bitrateKbps: (map['bitrateKbps'] as num?)?.toInt(),
        sizeBytes: (map['size'] as num?)?.toInt(),
        needsMuxing: (map['needsMuxing'] as bool?) ?? false,
      ));
    }
    if (options.isEmpty) {
      throw const EngineException('Nenhum formato utilizável (NewPipe).');
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
    final File file = File(outputPath);
    await file.parent.create(recursive: true);

    final http.Request request = http.Request('GET', Uri.parse(format.id));
    final http.StreamedResponse response = await _http.send(request);
    if (response.statusCode != 200) {
      throw EngineException(
          'O servidor recusou o download (HTTP ${response.statusCode}).');
    }

    final int? total = response.contentLength;
    final IOSink sink = file.openWrite();
    final Stopwatch stopwatch = Stopwatch()..start();
    int received = 0;
    DateTime lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      await for (final List<int> chunk in response.stream) {
        if (token?.isCanceled ?? false) {
          throw const DownloadCanceledException();
        }
        sink.add(chunk);
        received += chunk.length;

        final DateTime now = DateTime.now();
        if (now.difference(lastEmit) >= const Duration(milliseconds: 250)) {
          lastEmit = now;
          yield DownloadProgress(
            receivedBytes: received,
            totalBytes: total,
            speedBytesPerSecond: _speed(received, stopwatch),
          );
        }
      }
      await sink.flush();
      await sink.close();
      yield DownloadProgress(
        receivedBytes: received,
        totalBytes: total ?? received,
        speedBytesPerSecond: _speed(received, stopwatch),
      );
    } catch (_) {
      await sink.close();
      rethrow;
    }
  }

  double _speed(int received, Stopwatch stopwatch) {
    final double seconds = stopwatch.elapsedMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return received / seconds;
  }

  @override
  Future<void> dispose() async {
    _http.close();
  }
}
