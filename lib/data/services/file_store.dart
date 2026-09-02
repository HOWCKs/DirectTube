import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Onde os arquivos baixados são gravados e como os nomes são montados.
class FileStore {
  FileStore();

  static final RegExp _controlChars = RegExp(r'[\x00-\x1F]');
  static final RegExp _invalidChars = RegExp(r'[\\/:*?"<>|]');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Nome de arquivo seguro a partir de um título arbitrário.
  ///
  /// Puro e testável (`test/file_store_test.dart`): remove caracteres
  /// proibidos, colapsa espaços, limita o tamanho e nunca devolve vazio.
  static String sanitizeFileName(String input, {int maxLength = 120}) {
    // Caracteres de controle somem; os proibidos em nomes viram espaço.
    String value = input.replaceAll(_controlChars, '');
    value = value.replaceAll(_invalidChars, ' ');
    value = value.replaceAll(_whitespace, ' ').trim();
    // Pontos no início criam arquivos ocultos; no fim quebram a extensão.
    value = value.replaceAll(RegExp(r'^[.\s]+'), '');
    value = value.replaceAll(RegExp(r'[.\s]+$'), '');

    if (value.isEmpty) return 'download';
    if (value.length > maxLength) {
      value = value.substring(0, maxLength).trim();
      // Não corta no meio de uma palavra se der para evitar.
      final int lastSpace = value.lastIndexOf(' ');
      if (lastSpace > maxLength ~/ 2) value = value.substring(0, lastSpace);
    }
    return value.isEmpty ? 'download' : value;
  }

  /// Pasta base: externa do app quando disponível (visível ao usuário em
  /// `Android/data/<pacote>/files/DirectTube`), senão documentos internos.
  Future<Directory> baseDirectory() async {
    try {
      final Directory? external = await getExternalStorageDirectory();
      if (external != null) {
        final Directory dir = Directory('${external.path}/DirectTube');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {
      // Alguns dispositivos/emuladores não expõem armazenamento externo.
    }
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/DirectTube');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> videoDirectory() => _sub('Vídeos');

  Future<Directory> audioDirectory() => _sub('Músicas');

  Future<Directory> _sub(String name) async {
    final Directory base = await baseDirectory();
    final Directory dir = Directory('${base.path}/$name');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Caminho livre para gravar: acrescenta `(2)`, `(3)`… se já existir.
  Future<String> uniquePath({
    required String title,
    required String extension,
    required bool isAudio,
  }) async {
    final Directory dir = isAudio ? await audioDirectory() : await videoDirectory();
    final String safeTitle = sanitizeFileName(title);
    final String ext = extension.replaceAll('.', '').toLowerCase();

    String candidate = '${dir.path}/$safeTitle.$ext';
    int counter = 2;
    while (await File(candidate).exists()) {
      candidate = '${dir.path}/$safeTitle ($counter).$ext';
      counter++;
    }
    return candidate;
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<int> sizeOf(String path) async {
    final File file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }

  Future<void> delete(String path) async {
    final File file = File(path);
    if (await file.exists()) await file.delete();
  }
}
