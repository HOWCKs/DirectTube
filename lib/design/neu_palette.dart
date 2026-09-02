import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Tokens de design do DirectTube.
///
/// Fonte de verdade: `design/neumorphic-preview/index.html`.
/// Regras invioláveis do neumorfismo usado aqui:
///   * fundo e superfície têm SEMPRE a mesma cor (nenhum cartão "branco");
///   * profundidade vem só do par de sombras (nunca de borda ou contorno);
///   * o acento aparece apenas em conteúdo ativo;
///   * raios entre 16 e 24.
class NeuTokens {
  const NeuTokens._();

  // Raios (sempre dentro da faixa 16–24)
  static const double radiusS = 16;
  static const double radiusM = 20;
  static const double radiusL = 24;

  // Movimento
  static const Duration duration = Duration(milliseconds: 140);
  static const Duration slow = Duration(milliseconds: 220);
  static const Curve curve = Cubic(0.32, 0.72, 0.24, 1);

  // Geometria das sombras — as cores vêm da [NeuPalette].
  static const Offset offset = Offset(9, 9);
  static const double blur = 18;
  static const Offset offsetSoft = Offset(5, 5);
  static const double blurSoft = 10;
  static const Offset offsetStrong = Offset(12, 12);
  static const double blurStrong = 24;

  // Tipografia
  static const double textTitle = 25;
  static const double textBody = 15;
  static const double textSmall = 13;
  static const double textCaption = 11.5;

  /// Paleta clara (spec original do projeto).
  static const NeuPalette light = NeuPalette(
    surface: Color(0xFFE0E5EC),
    shadowDark: Color(0xFFBEC3C9),
    shadowLight: Color(0xFFFFFFFF),
    accent: Color(0xFF4D6BFE),
    text: Color(0xFF2D3436),
    textMuted: Color(0xFF636E72),
  );

  /// Paleta escura neumórfica (mesma lógica, superfícies invertidas).
  static const NeuPalette dark = NeuPalette(
    surface: Color(0xFF23272E),
    shadowDark: Color(0xFF191C21),
    shadowLight: Color(0xFF2D323B),
    accent: Color(0xFF6D86FF),
    text: Color(0xFFE9ECF2),
    textMuted: Color(0xFF9AA4B2),
  );
}

/// Uma sombra: cor, deslocamento e raio de desfoque.
@immutable
class NeuShadow {
  const NeuShadow({required this.color, required this.offset, required this.blur});

  final Color color;
  final Offset offset;
  final double blur;

  /// Converte o raio CSS em sigma, igual ao que o Flutter faz em `BoxShadow`.
  double get sigma => blur * 0.57735 + 0.5;

  NeuShadow scale(double factor) => NeuShadow(
        color: color,
        offset: offset * factor,
        blur: blur * factor,
      );

  @override
  bool operator ==(Object other) =>
      other is NeuShadow &&
      other.color == color &&
      other.offset == offset &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(color, offset, blur);
}

/// Níveis de elevação. `pressed*` são os estados "afundados" (inset).
enum NeuElevation { raised, soft, strong, pressed, pressedSoft }

extension NeuElevationX on NeuElevation {
  bool get isInset =>
      this == NeuElevation.pressed || this == NeuElevation.pressedSoft;
}

/// Cores do tema, expostas como [ThemeExtension] para que o mesmo widget
/// funcione nos temas claro e escuro sem `if` espalhado pelo código.
@immutable
class NeuPalette extends ThemeExtension<NeuPalette> {
  const NeuPalette({
    required this.surface,
    required this.shadowDark,
    required this.shadowLight,
    required this.accent,
    required this.text,
    required this.textMuted,
  });

  /// Cor única de fundo e de todos os cartões/controles.
  final Color surface;

  /// Sombra inferior-direita (`9px 9px 18px #bec3c9` na spec).
  final Color shadowDark;

  /// Sombra superior-esquerda (`-9px -9px 18px #ffffff` na spec).
  final Color shadowLight;

  /// Acento único dos estados ativos.
  final Color accent;

  final Color text;
  final Color textMuted;

  bool get isDark =>
      ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;

  /// Par de sombras levantadas (padrão do spec).
  List<NeuShadow> get raised => _pair(NeuTokens.offset, NeuTokens.blur);

  List<NeuShadow> get soft => _pair(NeuTokens.offsetSoft, NeuTokens.blurSoft);

  List<NeuShadow> get strong =>
      _pair(NeuTokens.offsetStrong, NeuTokens.blurStrong);

  List<NeuShadow> shadowsFor(NeuElevation elevation) {
    switch (elevation) {
      case NeuElevation.raised:
      case NeuElevation.pressed:
        return raised;
      case NeuElevation.soft:
      case NeuElevation.pressedSoft:
        return soft;
      case NeuElevation.strong:
        return strong;
    }
  }

  List<NeuShadow> _pair(Offset offset, double blur) => <NeuShadow>[
        NeuShadow(color: shadowDark, offset: offset, blur: blur),
        NeuShadow(color: shadowLight, offset: Offset(-offset.dx, -offset.dy), blur: blur),
      ];

  static NeuPalette of(BuildContext context) =>
      Theme.of(context).extension<NeuPalette>() ?? NeuTokens.light;

  @override
  NeuPalette copyWith({
    Color? surface,
    Color? shadowDark,
    Color? shadowLight,
    Color? accent,
    Color? text,
    Color? textMuted,
  }) {
    return NeuPalette(
      surface: surface ?? this.surface,
      shadowDark: shadowDark ?? this.shadowDark,
      shadowLight: shadowLight ?? this.shadowLight,
      accent: accent ?? this.accent,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  NeuPalette lerp(ThemeExtension<NeuPalette>? other, double t) {
    if (other is! NeuPalette) return this;
    return NeuPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      shadowDark: Color.lerp(shadowDark, other.shadowDark, t)!,
      shadowLight: Color.lerp(shadowLight, other.shadowLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Desenha sombras INTERNAS (o efeito `inset` do CSS, que o Flutter não tem
/// nativamente em `BoxShadow`).
///
/// Técnica: recorta-se a área do widget, desenha-se um caminho que é o
/// "mundo inteiro menos o widget" e desfoca-se. Só a franja desfocada que
/// vaza para dentro aparece — exatamente o comportamento de `inset`.
class InnerShadowPainter extends CustomPainter {
  const InnerShadowPainter({required this.shadows, required this.borderRadius});

  final List<NeuShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty || size.isEmpty) return;
    final ui.RRect rrect = borderRadius.toRRect(Offset.zero & size);

    canvas.save();
    canvas.clipRRect(rrect);

    final Path outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTRB(
        -size.width,
        -size.height,
        size.width * 2,
        size.height * 2,
      ))
      ..addRRect(rrect);

    for (final NeuShadow shadow in shadows) {
      final Paint paint = Paint()
        ..color = shadow.color
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.sigma);
      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      canvas.drawPath(outside, paint);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(InnerShadowPainter oldDelegate) =>
      oldDelegate.shadows != shadows ||
      oldDelegate.borderRadius != borderRadius;
}
