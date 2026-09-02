import 'package:directtube/core/link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkParser.extractUrl', () {
    test('extrai URL de texto compartilhado com ruído', () {
      expect(
        LinkParser.extractUrl(
          'Olha esse vídeo https://youtu.be/dQw4w9WgXcQ muito bom!',
        ),
        'https://youtu.be/dQw4w9WgXcQ',
      );
    });

    test('remove pontuação final', () {
      expect(
        LinkParser.extractUrl('veja: https://youtube.com/watch?v=dQw4w9WgXcQ.'),
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('aceita URL sem esquema', () {
      expect(LinkParser.extractUrl('youtu.be/dQw4w9WgXcQ'),
          'https://youtu.be/dQw4w9WgXcQ');
    });

    test('retorna null quando não há URL', () {
      expect(LinkParser.extractUrl('apenas um texto qualquer'), isNull);
      expect(LinkParser.extractUrl('   '), isNull);
      expect(LinkParser.extractUrl(''), isNull);
    });
  });

  group('LinkParser.youtubeVideoId', () {
    const String id = 'dQw4w9WgXcQ';

    test('watch?v=', () {
      expect(
        LinkParser.parse('https://www.youtube.com/watch?v=$id')?.videoId,
        id,
      );
    });

    test('youtu.be', () {
      expect(LinkParser.parse('https://youtu.be/$id')?.videoId, id);
    });

    test('shorts', () {
      expect(LinkParser.parse('https://www.youtube.com/shorts/$id')?.videoId, id);
    });

    test('embed', () {
      expect(LinkParser.parse('https://www.youtube.com/embed/$id')?.videoId, id);
    });

    test('live', () {
      expect(LinkParser.parse('https://www.youtube.com/live/$id')?.videoId, id);
    });

    test('music.youtube.com', () {
      expect(
        LinkParser.parse('https://music.youtube.com/watch?v=$id')?.videoId,
        id,
      );
    });

    test('rejeita id com tamanho errado', () {
      expect(LinkParser.parse('https://youtu.be/curto')?.videoId, isNull);
    });

    test('detecta playlist', () {
      final ParsedLink? parsed = LinkParser.parse(
        'https://www.youtube.com/watch?v=$id&list=PL1234567890abc',
      );
      expect(parsed?.isPlaylist, isTrue);
      expect(parsed?.playlistId, 'PL1234567890abc');
    });
  });

  group('LinkParser.parse', () {
    test('classifica hosts', () {
      expect(
        LinkParser.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ')?.host,
        MediaHost.youtube,
      );
      expect(
        LinkParser.parse('https://exemplo.com/video.mp4')?.host,
        MediaHost.directMedia,
      );
      expect(
        LinkParser.parse('https://exemplo.com/pagina')?.host,
        MediaHost.generic,
      );
    });

    test('looksLikeLink', () {
      expect(LinkParser.looksLikeLink('baixe https://youtu.be/dQw4w9WgXcQ'),
          isTrue);
      expect(LinkParser.looksLikeLink('lo-fi para estudar'), isFalse);
    });
  });
}
