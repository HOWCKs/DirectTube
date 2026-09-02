import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors.dart';
import '../../core/haptics.dart';
import '../../core/link_parser.dart';
import '../engine/download_engine.dart';
import '../engine/engine_registry.dart';
import '../models/download_task.dart';
import '../models/format_option.dart';
import '../models/media_item.dart';
import 'download_queue.dart';
import 'file_store.dart';

/// Orquestra fila, motores e arquivos.
///
/// É a única peça que conhece os três mundos ao mesmo tempo: a fila pura
/// ([DownloadQueue]), o motor escolhido ([EngineRegistry]) e o disco
/// ([FileStore]). As telas só ouvem `notifyListeners`.
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required EngineRegistry registry,
    required FileStore files,
    SharedPreferences? prefs,
    int maxConcurrent = 2,
  })  : _registry = registry,
        _files = files,
        _prefs = prefs,
        queue = DownloadQueue(maxConcurrent: maxConcurrent) {
    _restore();
  }

  static const String _queueKey = 'directtube.queue.v1';

  final EngineRegistry _registry;
  final FileStore _files;
  final SharedPreferences? _prefs;

  final DownloadQueue queue;
  final Map<String, CancellationToken> _tokens = <String, CancellationToken>{};

  EngineRegistry get registry => _registry;

  /// Aplica a pasta escolhida pelo usuário (vinda de `AppSettings`).
  void setStoragePath(String? path) {
    _files.overrideBase = (path == null || path.isEmpty) ? null : path;
  }

  List<DownloadTask> get tasks => queue.tasks;

  int get activeCount => queue.activeCount;

  int get completedCount => queue.completedCount;

  /// Itens prontos, mais recentes primeiro (alimenta a Biblioteca).
  List<DownloadTask> get library {
    final List<DownloadTask> done = tasks
        .where((DownloadTask t) => t.isComplete && t.filePath != null)
        .toList();
    done.sort((DownloadTask a, DownloadTask b) =>
        b.createdAt.compareTo(a.createdAt));
    return done;
  }

  // ---------------------------------------------------------------- resolução

  /// Interpreta o texto colado e devolve a mídia correspondente.
  Future<MediaItem> resolve(String input) async {
    final String? url = LinkParser.extractUrl(input);
    if (url == null) {
      throw const EngineException('Cole um link válido para começar.');
    }
    final DownloadEngine? engine = await _registry.firstAvailableFor(url);
    if (engine == null) {
      throw EngineException('Nenhum motor disponível para $url');
    }
    return engine.resolve(url);
  }

  Future<List<FormatOption>> formatsFor(MediaItem item) async {
    final DownloadEngine? engine =
        await _registry.resolveForTask(engineId: item.engineId, url: item.sourceUrl);
    if (engine == null) {
      throw const EngineException('Motor indisponível para listar formatos.');
    }
    final List<FormatOption> formats = await engine.formatsFor(item);
    if (formats.isEmpty) {
      throw const EngineException('Este conteúdo não expõe formatos baixáveis.');
    }
    return formats;
  }

  /// Formatos que este build consegue salvar de fato (sem módulo FFmpeg,
  /// formatos que precisam de muxing ficam de fora).
  List<FormatOption> downloadableFormats(List<FormatOption> formats) =>
      formats.where((FormatOption f) => !f.needsMuxing).toList(growable: false);

  // -------------------------------------------------------------------- fila

  Future<DownloadTask> enqueue({
    required MediaItem item,
    required FormatOption format,
  }) async {
    final String path = await _files.uniquePath(
      title: item.title,
      extension: format.extension,
      isAudio: format.isAudioOnly,
    );

    final DownloadTask task = DownloadTask(
      id: '${item.id}_${format.id}_${DateTime.now().microsecondsSinceEpoch}',
      mediaId: item.id,
      title: item.title,
      sourceUrl: item.sourceUrl,
      formatId: format.id,
      extension: format.extension,
      isAudioOnly: format.isAudioOnly,
      createdAt: DateTime.now(),
      engineId: item.engineId,
      formatLabel: format.label,
      filePath: path,
    );

    if (!queue.add(task)) return task;
    notifyListeners();
    unawaited(_persist());
    unawaited(pump());
    return task;
  }

  /// Baixa uma playlist inteira (um item por formato escolhido).
  Future<List<DownloadTask>> enqueueAll({
    required List<MediaItem> items,
    required FormatOption Function(MediaItem item) pickFormat,
  }) async {
    final List<DownloadTask> created = <DownloadTask>[];
    for (int i = 0; i < items.length; i++) {
      created.add(await enqueue(item: items[i], format: pickFormat(items[i])));
    }
    return created;
  }

  /// Dispara os downloads que cabem na janela de concorrência.
  Future<void> pump() async {
    for (final DownloadTask task in queue.startable()) {
      if (queue.update(task.copyWith(status: DownloadStatus.running))) {
        notifyListeners();
        unawaited(_run(task.id));
      }
    }
    unawaited(_persist());
  }

  void pause(String id) {
    _tokens[id]?.cancel();
    if (queue.pause(id)) {
      notifyListeners();
      unawaited(_persist());
    }
  }

  int pauseAll() {
    for (final DownloadTask task in queue.tasks) {
      if (task.status.canPause) _tokens[task.id]?.cancel();
    }
    final int count = queue.pauseAll();
    if (count > 0) {
      notifyListeners();
      unawaited(_persist());
    }
    return count;
  }

  void resume(String id) {
    if (queue.resume(id)) {
      notifyListeners();
      unawaited(_persist());
      unawaited(pump());
    }
  }

  void cancel(String id) {
    _tokens[id]?.cancel();
    if (queue.cancel(id)) {
      notifyListeners();
      unawaited(_persist());
    }
  }

  Future<void> remove(String id) async {
    final DownloadTask? task = queue.byId(id);
    _tokens[id]?.cancel();
    if (task?.filePath != null) {
      await _files.delete(task!.filePath!);
    }
    if (queue.remove(id)) {
      notifyListeners();
      unawaited(_persist());
    }
  }

  Future<int> clearFinished() async {
    final List<DownloadTask> removed = queue.clearFinished();
    notifyListeners();
    unawaited(_persist());
    return removed.length;
  }

  // ---------------------------------------------------------------- execução

  Future<void> _run(String id) async {
    final DownloadTask? task = queue.byId(id);
    if (task == null) return;

    final CancellationToken token = CancellationToken();
    _tokens[id] = token;

    try {
      final DownloadEngine? engine = await _registry.resolveForTask(
        engineId: task.engineId,
        url: task.sourceUrl,
      );
      if (engine == null) {
        throw const EngineException('Nenhum motor disponível para retomar.');
      }

      final MediaItem item = MediaItem(
        id: task.mediaId,
        title: task.title,
        sourceUrl: task.sourceUrl,
        host: MediaHost.generic,
        engineId: engine.id,
      );

      final FormatOption format = FormatOption(
        id: task.formatId,
        label: task.formatLabel ?? task.formatId,
        extension: task.extension,
        isAudioOnly: task.isAudioOnly,
      );

      final String outputPath = task.filePath ??
          await _files.uniquePath(
            title: task.title,
            extension: task.extension,
            isAudio: task.isAudioOnly,
          );

      await for (final DownloadProgress progress in engine.download(
        item: item,
        format: format,
        outputPath: outputPath,
        token: token,
      )) {
        if (token.isCanceled) throw const DownloadCanceledException();
        queue.update(task.copyWith(
          status: DownloadStatus.running,
          receivedBytes: progress.receivedBytes,
          totalBytes: progress.totalBytes,
          speedBytesPerSecond: progress.speedBytesPerSecond,
          filePath: outputPath,
        ));
        notifyListeners();
      }

      queue.complete(id, outputPath);
      Haptics.fire(HapticStyle.success);
    } on DownloadCanceledException {
      queue.pause(id);
    } on EngineException catch (error) {
      queue.fail(id, error.message);
      Haptics.fire(HapticStyle.error);
    } catch (error) {
      queue.fail(id, _humanize(error));
      Haptics.fire(HapticStyle.error);
    } finally {
      _tokens.remove(id);
      notifyListeners();
      unawaited(_persist());
      unawaited(pump());
    }
  }

  static String _humanize(Object error) => friendlyError(error);

  // ------------------------------------------------------------- persistência

  Future<void> _persist() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final List<Map<String, dynamic>> json =
        queue.tasks.map((DownloadTask t) => t.toJson()).toList(growable: false);
    await prefs.setString(_queueKey, jsonEncode(json));
  }

  void _restore() {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final String? raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<DownloadTask> restored = decoded
          .whereType<Map<String, dynamic>>()
          .map(DownloadTask.fromJson)
          .toList(growable: false);
      queue.restore(restored);
    } catch (_) {
      // Fila corrompida: começa limpo em vez de quebrar o app.
    }
  }

  @override
  void dispose() {
    for (final CancellationToken token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    unawaited(_registry.dispose());
    super.dispose();
  }
}
