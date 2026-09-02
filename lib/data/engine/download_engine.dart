import 'dart:async';

import '../models/format_option.dart';
import '../models/media_item.dart';

/// Erro de motor com mensagem pronta para exibição.
class EngineException implements Exception {
  const EngineException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Motor existe no código, mas não está presente neste build
/// (ex.: módulo yt-dlp/Chaquopy não incluído).
class EngineUnavailableException extends EngineException {
  const EngineUnavailableException(String message) : super(message);
}

/// Download interrompido pelo usuário.
class DownloadCanceledException implements Exception {
  const DownloadCanceledException();

  @override
  String toString() => 'Download cancelado.';
}

/// Progresso emitido durante um download.
class DownloadProgress {
  const DownloadProgress({
    required this.receivedBytes,
    this.totalBytes,
    this.speedBytesPerSecond = 0,
  });

  final int receivedBytes;
  final int? totalBytes;
  final double speedBytesPerSecond;

  double get fraction {
    final int? total = totalBytes;
    if (total == null || total <= 0) return 0;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}

/// Sinal cooperativo de cancelamento compartilhado com o motor.
class CancellationToken {
  bool _canceled = false;

  bool get isCanceled => _canceled;

  void cancel() => _canceled = true;
}

/// Contrato único para qualquer motor de download.
///
/// Duas implementações vivem neste repositório:
///   * [YoutubeExplodeEngine] — extração 100% em Dart, sem runtime Python;
///   * [YtDlpEngine] — ponte para o yt-dlp embarcado (1000+ sites).
/// O app escolhe em tempo de execução via `EngineRegistry`, então adicionar um
/// motor novo não toca em nenhuma tela.
abstract class DownloadEngine {
  String get id;

  String get displayName;

  /// `true` se este motor aceita o link (sintaxe, não rede).
  bool canHandle(String url);

  /// `true` se o motor está de fato utilizável neste dispositivo/build.
  Future<bool> isAvailable();

  /// Busca os metadados da mídia.
  Future<MediaItem> resolve(String url);

  /// Lista os formatos disponíveis para download.
  Future<List<FormatOption>> formatsFor(MediaItem item);

  /// Baixa para [outputPath], emitindo progresso.
  /// Deve lançar [DownloadCanceledException] se [token] for cancelado.
  Stream<DownloadProgress> download({
    required MediaItem item,
    required FormatOption format,
    required String outputPath,
    CancellationToken? token,
  });

  Future<void> dispose();
}
