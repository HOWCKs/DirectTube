/// Opção de formato oferecida por um motor (ex.: "1080p MP4", "MP3 320k").
class FormatOption {
  const FormatOption({
    required this.id,
    required this.label,
    required this.extension,
    required this.isAudioOnly,
    this.height,
    this.bitrateKbps,
    this.sizeBytes,
    this.needsMuxing = false,
    this.conversionTarget,
  });

  /// Identificador do formato no motor de origem.
  final String id;

  /// Rótulo exibido nos chips (ex.: `1080p`, `MP3 320k`).
  final String label;

  /// Extensão final do arquivo (`mp4`, `m4a`, `mp3`…).
  final String extension;

  final bool isAudioOnly;

  /// Altura em pixels (vídeo).
  final int? height;

  final int? bitrateKbps;

  /// Tamanho estimado, quando o motor informa.
  final int? sizeBytes;

  /// `true` quando vídeo e áudio vêm separados e precisam ser combinados
  /// (requer o módulo FFmpeg; enquanto ele não está presente o app oferece
  /// apenas formatos progressivos/muxados).
  final bool needsMuxing;

  /// Alvo de conversão de áudio (ex.: `mp3`), quando aplicável.
  final String? conversionTarget;

  bool get isVideo => !isAudioOnly;

  /// Qualidade aproximada para ordenar a lista (maior = melhor).
  int get sortKey {
    if (isAudioOnly) return bitrateKbps ?? 0;
    return (height ?? 0) * 1000 + (bitrateKbps ?? 0);
  }

  @override
  String toString() => 'FormatOption($id, $label)';
}
