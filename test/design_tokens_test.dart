import 'package:directtube/design/neu_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Estes testes travam o contrato visual: qualquer desvio dos valores do
/// spec (design/neumorphic-preview/index.html) quebra a build.
void main() {
  group('Tokens de cor do spec', () {
    test('superfície #e0e5ec', () {
      expect(NeuTokens.light.surface, const Color(0xFFE0E5EC));
    });

    test('sombra escura #bec3c9', () {
      expect(NeuTokens.light.shadowDark, const Color(0xFFBEC3C9));
    });

    test('sombra clara #ffffff', () {
      expect(NeuTokens.light.shadowLight, const Color(0xFFFFFFFF));
    });

    test('acento único #4d6bfe', () {
      expect(NeuTokens.light.accent, const Color(0xFF4D6BFE));
    });

    test('texto #2d3436', () {
      expect(NeuTokens.light.text, const Color(0xFF2D3436));
    });

    test('tema claro não é detectado como escuro', () {
      expect(NeuTokens.light.isDark, isFalse);
      expect(NeuTokens.dark.isDark, isTrue);
    });
  });

  group('Raios entre 16 e 24', () {
    test('valores exatos', () {
      expect(NeuTokens.radiusS, 16);
      expect(NeuTokens.radiusM, 20);
      expect(NeuTokens.radiusL, 24);
    });

    test('nenhum raio sai da faixa', () {
      for (final double radius in <double>[
        NeuTokens.radiusS,
        NeuTokens.radiusM,
        NeuTokens.radiusL,
      ]) {
        expect(radius, greaterThanOrEqualTo(16));
        expect(radius, lessThanOrEqualTo(24));
      }
    });
  });

  group('Par de sombras', () {
    test('9px 9px 18px no canto inferior direito', () {
      final NeuShadow dark = NeuTokens.light.raised.first;
      expect(dark.color, const Color(0xFFBEC3C9));
      expect(dark.offset, const Offset(9, 9));
      expect(dark.blur, 18);
    });

    test('-9px -9px 18px no canto superior esquerdo', () {
      final NeuShadow light = NeuTokens.light.raised.last;
      expect(light.color, const Color(0xFFFFFFFF));
      expect(light.offset, const Offset(-9, -9));
      expect(light.blur, 18);
    });

    test('sempre duas sombras, nunca uma só', () {
      for (final NeuElevation elevation in NeuElevation.values) {
        expect(NeuTokens.light.shadowsFor(elevation).length, 2,
            reason: 'elevação $elevation');
      }
    });

    test('estados pressionados são marcados como inset', () {
      expect(NeuElevation.pressed.isInset, isTrue);
      expect(NeuElevation.pressedSoft.isInset, isTrue);
      expect(NeuElevation.raised.isInset, isFalse);
      expect(NeuElevation.soft.isInset, isFalse);
      expect(NeuElevation.strong.isInset, isFalse);
    });

    test('sigma equivalente ao desfoque CSS', () {
      // Flutter: blurRadius * 0.57735 + 0.5
      expect(
        const NeuShadow(color: Colors.black, offset: Offset.zero, blur: 18)
            .sigma,
        closeTo(10.892, 0.001),
      );
    });
  });

  group('ThemeExtension', () {
    test('copyWith mantém o resto', () {
      final NeuPalette changed =
          NeuTokens.light.copyWith(accent: const Color(0xFF000000));
      expect(changed.accent, const Color(0xFF000000));
      expect(changed.surface, NeuTokens.light.surface);
    });

    test('lerp interpola cores', () {
      final NeuPalette middle =
          NeuTokens.light.lerp(NeuTokens.dark, 0.5);
      expect(middle.accent, isNot(NeuTokens.light.accent));
      expect(middle.accent, isNot(NeuTokens.dark.accent));
    });

    test('lerp com tipo diferente devolve a própria paleta', () {
      expect(NeuTokens.light.lerp(null, 1), NeuTokens.light);
    });
  });
}
