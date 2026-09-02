import 'package:directtube/data/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('padrões do projeto', () {
      const AppSettings defaults = AppSettings();
      expect(defaults.hapticsEnabled, isTrue);
      expect(defaults.wifiOnly, isTrue);
      expect(defaults.backgroundDownloads, isTrue);
      expect(defaults.darkTheme, isFalse);
      expect(defaults.localeCode, 'pt_BR');
      expect(defaults.maxConcurrent, 2);
      expect(defaults.preferAudio, isFalse);
    });

    test('ida e volta em JSON', () {
      const AppSettings changed = AppSettings(
        hapticsEnabled: false,
        wifiOnly: false,
        backgroundDownloads: false,
        darkTheme: true,
        localeCode: 'en',
        maxConcurrent: 4,
        preferAudio: true,
      );
      expect(AppSettings.fromJson(changed.toJson()), changed);
    });

    test('JSON incompleto cai nos padrões', () {
      final AppSettings restored =
          AppSettings.fromJson(<String, dynamic>{'darkTheme': true});
      expect(restored.darkTheme, isTrue);
      expect(restored.localeCode, 'pt_BR');
      expect(restored.maxConcurrent, 2);
    });

    test('copyWith altera só o que foi pedido', () {
      const AppSettings base = AppSettings();
      final AppSettings next = base.copyWith(darkTheme: true);
      expect(next.darkTheme, isTrue);
      expect(next.localeCode, base.localeCode);
      expect(next == base, isFalse);
      expect(base.copyWith() == base, isTrue);
    });
  });
}
