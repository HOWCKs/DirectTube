import 'package:flutter/services.dart';

/// Publica um arquivo baixado na memória pública (MediaStore) via código
/// nativo (`MainActivity.kt`, canal `com.directtube.app/media`).
///
/// Devolve o caminho absoluto público (`/storage/.../Music/arquivo.m4a`).
/// Se o lado nativo não existir (build sem o plugin), lança — o chamador
/// mantém o arquivo no armazenamento privado como fallback.
class MediaPublisher {
  MediaPublisher();

  static const MethodChannel _channel =
      MethodChannel('com.directtube.app/media');

  Future<String> publish({
    required String path,
    required bool isAudio,
    required String title,
  }) async {
    final String? result = await _channel.invokeMethod<String>('publish', <String, dynamic>{
      'path': path,
      'isAudio': isAudio,
      'title': title,
    });
    if (result == null || result.isEmpty) {
      throw const PlatformException(code: 'publish', message: 'Sem caminho público.');
    }
    return result;
  }
}
