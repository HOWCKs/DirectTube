/// Identificação de links colados pelo usuário.
///
/// Lógica 100% pura e testável (`test/link_parser_test.dart`): nada de rede,
/// nada de plataforma. Os motores de download consomem o resultado.
enum MediaHost { youtube, directMedia, generic }

class ParsedLink {
  const ParsedLink({
    required this.url,
    required this.host,
    this.videoId,
    this.playlistId,
  });

  final String url;
  final MediaHost host;
  final String? videoId;
  final String? playlistId;

  bool get isPlaylist => playlistId != null && playlistId!.isNotEmpty;
  bool get isYouTube => host == MediaHost.youtube;

  @override
  String toString() =>
      'ParsedLink($host, videoId: $videoId, playlistId: $playlistId)';

  @override
  bool operator ==(Object other) =>
      other is ParsedLink &&
      other.url == url &&
      other.host == host &&
      other.videoId == videoId &&
      other.playlistId == playlistId;

  @override
  int get hashCode => Object.hash(url, host, videoId, playlistId);
}

class LinkParser {
  const LinkParser._();

  /// Encontra a primeira URL em um texto arbitrário (mensagem compartilhada,
  /// texto com emoji, etc.).
  static final RegExp _urlRegExp = RegExp(
    r'''https?://[^\s<>"'()\[\]]+''',
    caseSensitive: false,
  );

  /// IDs do YouTube têm exatamente 11 caracteres desta classe.
  static final RegExp _videoIdRegExp = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static const Set<String> _youtubeHosts = <String>{
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'www.youtu.be',
  };

  static const Set<String> _mediaExtensions = <String>{
    'mp4', 'mkv', 'webm', 'mov', 'm4v', 'mp3', 'm4a', 'aac', 'flac', 'opus', 'wav', 'ogg',
  };

  /// Extrai a primeira URL de um texto. Retorna `null` se não houver nenhuma.
  static String? extractUrl(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Caso comum: o usuário colou só a URL (possivelmente sem esquema).
    if (!trimmed.contains(' ')) {
      final String candidate = _normalize(trimmed);
      if (_urlRegExp.hasMatch(candidate)) return candidate;
    }

    final RegExpMatch? match = _urlRegExp.firstMatch(trimmed);
    return match == null ? null : _stripTrailingPunctuation(match.group(0)!);
  }

  static String _normalize(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}(/|$)', caseSensitive: false)
        .hasMatch(value)) {
      return 'https://$value';
    }
    return value;
  }

  static String _stripTrailingPunctuation(String url) {
    String result = url;
    while (result.isNotEmpty && '.,;:!?'.contains(result[result.length - 1])) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// Interpreta um texto/URL e devolve metadados de roteamento.
  static ParsedLink? parse(String input) {
    final String? raw = extractUrl(input);
    if (raw == null) return null;

    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return null;

    final String host = uri.host.toLowerCase();

    if (_youtubeHosts.contains(host)) {
      final String? id = youtubeVideoId(uri);
      final String? list = uri.queryParameters['list'];
      return ParsedLink(
        url: raw,
        host: MediaHost.youtube,
        videoId: id,
        playlistId: (list == null || list.isEmpty) ? null : list,
      );
    }

    final String path = uri.path.toLowerCase();
    final String ext = path.contains('.') ? path.split('.').last : '';
    if (_mediaExtensions.contains(ext)) {
      return ParsedLink(url: raw, host: MediaHost.directMedia);
    }

    return ParsedLink(url: raw, host: MediaHost.generic);
  }

  /// Extrai o ID de vídeo de qualquer forma canônica de URL do YouTube.
  /// Cobre: `watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`, `/live/`, `/v/`.
  static String? youtubeVideoId(Uri uri) {
    final String host = uri.host.toLowerCase();

    if (host == 'youtu.be' || host == 'www.youtu.be') {
      final List<String> segments = uri.pathSegments;
      if (segments.isNotEmpty && _videoIdRegExp.hasMatch(segments.first)) {
        return segments.first;
      }
      return null;
    }

    final String? v = uri.queryParameters['v'];
    if (v != null && _videoIdRegExp.hasMatch(v)) return v;

    const List<String> prefixes = <String>['shorts', 'embed', 'live', 'v'];
    final List<String> segments = uri.pathSegments;
    if (segments.length >= 2 && prefixes.contains(segments[0])) {
      final String candidate = segments[1];
      if (_videoIdRegExp.hasMatch(candidate)) return candidate;
    }

    return null;
  }

  /// `true` quando o texto parece um link aproveitável pelo app.
  static bool looksLikeLink(String text) => extractUrl(text) != null;
}
