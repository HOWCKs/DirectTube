import '../core/link_parser.dart';

/// Mídia resolvida por um motor (metadados, antes de qualquer download).
class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.sourceUrl,
    required this.host,
    this.author,
    this.duration,
    this.thumbnailUrl,
    this.engineId,
  });

  final String id;
  final String title;
  final String sourceUrl;
  final MediaHost host;
  final String? author;
  final Duration? duration;
  final String? thumbnailUrl;

  /// Motor que resolveu este item (útil para retomar o download depois).
  final String? engineId;

  MediaItem copyWith({
    String? title,
    String? author,
    Duration? duration,
    String? thumbnailUrl,
    String? engineId,
  }) {
    return MediaItem(
      id: id,
      title: title ?? this.title,
      sourceUrl: sourceUrl,
      host: host,
      author: author ?? this.author,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      engineId: engineId ?? this.engineId,
    );
  }

  @override
  String toString() => 'MediaItem($id, "$title")';
}
