import 'package:directtube/core/formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fmt.bytes', () {
    test('usa vírgula decimal e unidades binárias', () {
      expect(Fmt.bytes(0), '0 B');
      expect(Fmt.bytes(null), '—');
      expect(Fmt.bytes(512), '512 B');
      expect(Fmt.bytes(1536), '1,5 KB');
      expect(Fmt.bytes(1572864), '1,5 MB');
      expect(Fmt.bytes(1073741824), '1,0 GB');
    });
  });

  group('Fmt.duration', () {
    test('com e sem horas', () {
      expect(Fmt.duration(null), '--:--');
      expect(Fmt.duration(const Duration(seconds: 65)), '1:05');
      expect(Fmt.duration(const Duration(seconds: 4624)), '1:17:04');
      expect(Fmt.duration(const Duration(hours: 3, minutes: 1, seconds: 22)),
          '3:01:22');
    });
  });

  group('Fmt.speed', () {
    test('acrescenta /s', () {
      expect(Fmt.speed(4400000), '4,2 MB/s');
    });
  });

  group('Fmt.percent', () {
    test('arredonda e trunca', () {
      expect(Fmt.percent(0.42), '42%');
      expect(Fmt.percent(1.4), '100%');
      expect(Fmt.percent(-0.2), '0%');
    });
  });
}
