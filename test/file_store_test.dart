import 'package:directtube/data/services/file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileStore.sanitizeFileName', () {
    test('remove caracteres proibidos em sistemas de arquivo', () {
      expect(
        FileStore.sanitizeFileName('a/b\\c:d*e?f"g<h>i|j'),
        'a b c d e f g h i j',
      );
    });

    test('colapsa espaços e remove espaços das pontas', () {
      expect(FileStore.sanitizeFileName('  lo-fi   mix   '), 'lo-fi mix');
    });

    test('remove caracteres de controle', () {
      expect(FileStore.sanitizeFileName('musica\u0001\u001F.mp3'), 'musica.mp3');
    });

    test('nunca devolve vazio', () {
      expect(FileStore.sanitizeFileName(''), 'download');
      expect(FileStore.sanitizeFileName('///'), 'download');
      expect(FileStore.sanitizeFileName('...'), 'download');
    });

    test('não começa nem termina com ponto', () {
      expect(FileStore.sanitizeFileName('..oculto..'), 'oculto');
    });

    test('limita o tamanho sem cortar palavra no meio', () {
      final String long = List<String>.filled(40, 'palavra').join(' ');
      final String result = FileStore.sanitizeFileName(long, maxLength: 30);
      expect(result.length, lessThanOrEqualTo(30));
      expect(result.endsWith(' '), isFalse);
      expect(result.contains('palavra'), isTrue);
    });

    test('preserva acentos (nomes em português)', () {
      expect(
        FileStore.sanitizeFileName('Música: verão / 2026'),
        'Música verão 2026',
      );
    });
  });
}
