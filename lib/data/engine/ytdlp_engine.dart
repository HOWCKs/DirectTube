import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/link_parser.dart';
import '../models/format_option.dart';
import '../models/media_item.dart';
import 'download_engine.dart';

/// Ponte para o yt-dlp embarcado no APK (cobre 1000+ sites).
///
/// O lado nativo é opcional: quando o módulo não está presente no build,
/// [isAvailable] devolve `false` e o `EngineRegistry` simplesmente ignora este
/// motor — o app continua funcionando com o motor YouTube nativo em Dart.
///
/// Contrato esperado do lado nativo (Kotlin + Chaquopy):
///   MethodChannel `com.directtube.app/ytdlp`
///     - isAvailable() -> bool
///     - resolve(url) -> {id, title, author, durationSeconds, thumbnailUrl}
///     - formats(url) -> [{id, label, ext, audioOnly, height, bitrateKbps, sizeBytes}]
///     - download(url, formatId, outputPath) -> bool
///     - cancel(outputPath) -> bool
///   EventChannel `com.directtube.app/ytdlp/progress`
///     - {outputPath, received, total, speed}
class YtDlpEngine implements DownloadEngine {
  YtDlpEngine();

  static const MethodChannel _channel =
      MethodChannel('com.directtube.app/ytdlp');
  static const EventChannel _progressChannel =
      EventChannel('com.directtube.app/ytdlp/progress');

  bool? _available;

  @override
  String get id => 'yt-dlp';

  @override
  String get displayName => 'yt-dlp (1000+ sites)';

  @override
  bool canHandle(String url) {
    final ParsedLink? parsed = LinkParser.parse(url);
    return parsed != null;
  }

  @override
  Future<bool> isAvailable() async {
    final bool? cached = _available;
    if (cached != null) return cached;
    try {
      _available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
    return _available ?? false;
  }

  @override
  Future<MediaItem> resolve(String url) async {
    await _ensureAvailable();
    final Map<String, dynamic>? raw = await _invokeMap('resolve', <String, dynamic>{'url': url});
    if (raw == null) {
      throw const EngineException('yt-dlp não retornou metadados para este link.');
    }
    final ParsedLink? parsed = LinkParser.parse(url);
    final int? seconds = (raw['durationSeconds'] as num?)?.toInt();
    return MediaItem(
      id: (raw['id'] as String?) ?? url,
      title: (raw['title'] as String?) ?? 'Mídia sem título',
      sourceUrl: url,
      host: parsed?.host ?? MediaHost.generic,
      author: raw['author'] as String?,
      duration: seconds == null ? null : Duration(seconds: seconds),
      thumbnailUrl: raw['thumbnailUrl'] as String?,
      engineId: id,
    );
  }

  @override
  Future<List<FormatOption>> formatsFor(MediaItem item) async {
    await _ensureAvailable();
    final List<dynamic>? raw = await _invokeList('formats', <String, dynamic>{
      'url': item.sourceUrl,
    });
    if (raw == null) return const <FormatOption>[];

    final List<FormatOption> options = <FormatOption>[];
    for (final dynamic entry in raw) {
      if (entry is! Map) continue;
      final Map<dynamic, dynamic> map = entry.cast<dynamic, dynamic>();
      options.add(FormatOption(
        id: (map['id'] ?? '').toString(),
        label: (map['label'] ?? 'Formato').toString(),
        extension: (map['ext'] ?? 'mp4').toString(),
        isAudioOnly: map['audioOnly'] == true,
        height: (map['height'] as num?)?.toInt(),
        bitrateKbps: (map['bitrateKbps'] as num?)?.toInt(),
        sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
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
    await _ensureAvailable();

    final StreamController<DownloadProgress> progress =
        StreamController<DownloadProgress>.broadcast();

    final StreamSubscription<dynamic> subscription =
        _progressChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is! Map) return;
      if (event['outputPath'] != outputPath) return;
      progress.add(DownloadProgress(
        receivedBytes: (event['received'] as num?)?.toInt() ?? 0,
        totalBytes: (event['total'] as num?)?.toInt(),
        speedBytesPerSecond: (event['speed'] as num?)?.toDouble() ?? 0,
      ));
    }, onError: (Object _) {/* progresso é opcional */});

    final Completer<bool> done = Completer<bool>();
    unawaited(_channel
        .invokeMethod<bool>('download', <String, dynamic>{
          'url': item.sourceUrl,
          'formatId': format.id,
          'outputPath': outputPath,
        })
        .then((bool? value) {
      if (!done.isCompleted) done.complete(value ?? false);
    }).catchError((Object error) {
      if (!done.isCompleted) done.completeError(error);
    }));

    if (token != null) {
      unawaited(_cancelWhenRequested(token, outputPath, done));
    }

    int lastReceived = 0;
    int? lastTotal;

    while (!done.isCompleted) {
      try {
        final DownloadProgress event = await progress.stream.first
            .timeout(const Duration(milliseconds: 500));
        lastReceived = event.receivedBytes;
        lastTotal = event.totalBytes;
        yield event;
      } on TimeoutException {
        continue;
      }
    }

    final bool ok = await done.future;
    await subscription.cancel();
    await progress.close();

    if (token?.isCanceled ?? false) throw const DownloadCanceledException();
    if (!ok) {
      throw const EngineException('O yt-dlp não concluiu este download.');
    }

    yield DownloadProgress(
      receivedBytes: lastReceived,
      totalBytes: lastTotal ?? lastReceived,
    );
  }

  Future<void> _cancelWhenRequested(
    CancellationToken token,
    String outputPath,
    Completer<bool> done,
  ) async {
    while (!done.isCompleted && !token.isCanceled) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (token.isCanceled && !done.isCompleted) {
      try {
        await _channel
            .invokeMethod<bool>('cancel', <String, dynamic>{'outputPath': outputPath});
      } on PlatformException {
        // Ignorado: o download pode já ter terminado.
      }
    }
  }

  Future<void> _ensureAvailable() async {
    if (!await isAvailable()) {
      throw const EngineUnavailableException(
        'O módulo yt-dlp não está incluído neste build.',
      );
    }
  }

  Future<Map<String, dynamic>?> _invokeMap(
      String method, Map<String, dynamic> args) async {
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMethod<Map<Object?, Object?>>(method, args);
      return result?.cast<String, dynamic>();
    } on PlatformException catch (error) {
      throw EngineException(error.message ?? 'Falha no yt-dlp.');
    }
  }

  Future<List<dynamic>?> _invokeList(
      String method, Map<String, dynamic> args) async {
    try {
      return await _channel.invokeMethod<List<dynamic>>(method, args);
    } on PlatformException catch (error) {
      throw EngineException(error.message ?? 'Falha no yt-dlp.');
    }
  }

  @override
  Future<void> dispose() async {
    _available = null;
  }
}
