/// Estado de um item na fila de downloads.
enum DownloadStatus { queued, running, paused, completed, failed, canceled }

extension DownloadStatusX on DownloadStatus {
  bool get canPause => this == DownloadStatus.running || this == DownloadStatus.queued;
  bool get canResume => this == DownloadStatus.paused || this == DownloadStatus.failed;
  bool get canCancel => this != DownloadStatus.completed && this != DownloadStatus.canceled;
  bool get isTerminal =>
      this == DownloadStatus.completed || this == DownloadStatus.canceled;
}

/// Tarefa de download persistível.
///
/// Imutável: toda transição devolve uma nova instância via [copyWith], o que
/// torna a fila trivialmente testável e segura para `ChangeNotifier`.
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.sourceUrl,
    required this.formatId,
    required this.extension,
    required this.isAudioOnly,
    required this.createdAt,
    this.engineId,
    this.formatLabel,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes,
    this.filePath,
    this.error,
    this.speedBytesPerSecond = 0,
    this.playlistIndex,
  });

  /// Identificador único desta tarefa na fila.
  final String id;

  /// Identificador da mídia no motor de origem (ex.: id do vídeo).
  final String mediaId;

  final String title;
  final String sourceUrl;
  final String formatId;
  final String extension;
  final bool isAudioOnly;
  final DateTime createdAt;

  final String? engineId;
  final String? formatLabel;
  final DownloadStatus status;
  final int receivedBytes;
  final int? totalBytes;
  final String? filePath;
  final String? error;
  final double speedBytesPerSecond;

  /// Índice dentro de uma playlist (para downloads em lote).
  final int? playlistIndex;

  double get progress {
    final int? total = totalBytes;
    if (total == null || total <= 0) return 0;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  bool get isComplete => status == DownloadStatus.completed;
  bool get isActive => status == DownloadStatus.running;
  bool get isAudio => isAudioOnly;

  DownloadTask copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? filePath,
    String? error,
    double? speedBytesPerSecond,
    String? formatLabel,
    String? engineId,
  }) {
    return DownloadTask(
      id: id,
      mediaId: mediaId,
      title: title,
      sourceUrl: sourceUrl,
      formatId: formatId,
      extension: extension,
      isAudioOnly: isAudioOnly,
      createdAt: createdAt,
      engineId: engineId ?? this.engineId,
      formatLabel: formatLabel ?? this.formatLabel,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      // Erro explícito vence; transicionar para fila/execução limpa o anterior.
      error: error ??
          (status == DownloadStatus.queued || status == DownloadStatus.running
              ? ''
              : this.error),
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      playlistIndex: playlistIndex,
    );
  }

  /// Transição usada ao retomar/tentar de novo: zera erro e velocidade.
  DownloadTask retry() => DownloadTask(
        id: id,
        mediaId: mediaId,
        title: title,
        sourceUrl: sourceUrl,
        formatId: formatId,
        extension: extension,
        isAudioOnly: isAudioOnly,
        createdAt: createdAt,
        engineId: engineId,
        formatLabel: formatLabel,
        status: DownloadStatus.queued,
        receivedBytes: 0,
        totalBytes: totalBytes,
        filePath: filePath,
        speedBytesPerSecond: 0,
        playlistIndex: playlistIndex,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'mediaId': mediaId,
        'title': title,
        'sourceUrl': sourceUrl,
        'formatId': formatId,
        'extension': extension,
        'isAudioOnly': isAudioOnly,
        'createdAt': createdAt.toIso8601String(),
        'engineId': engineId,
        'formatLabel': formatLabel,
        'status': status.name,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'filePath': filePath,
        'error': error,
        'speedBytesPerSecond': speedBytesPerSecond,
        'playlistIndex': playlistIndex,
      };

  static DownloadTask fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String? ?? json['id'] as String,
      title: json['title'] as String? ?? 'Sem título',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      formatId: json['formatId'] as String? ?? '',
      extension: json['extension'] as String? ?? 'mp4',
      isAudioOnly: json['isAudioOnly'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      engineId: json['engineId'] as String?,
      formatLabel: json['formatLabel'] as String?,
      status: DownloadStatus.values.firstWhere(
        (DownloadStatus s) => s.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      filePath: json['filePath'] as String?,
      error: json['error'] as String?,
      speedBytesPerSecond:
          (json['speedBytesPerSecond'] as num?)?.toDouble() ?? 0,
      playlistIndex: (json['playlistIndex'] as num?)?.toInt(),
    );
  }

  @override
  String toString() => 'DownloadTask($id, ${status.name}, ${progress.toStringAsFixed(2)})';
}
