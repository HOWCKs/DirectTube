import 'package:flutter/material.dart';

import 'neu_palette.dart';

/// Temas claro e escuro construídos a partir de [NeuTokens].
class NeuTheme {
  const NeuTheme._();

  static ThemeData light() => _build(NeuTokens.light, Brightness.light);

  static ThemeData dark() => _build(NeuTokens.dark, Brightness.dark);

  static ThemeData _build(NeuPalette palette, Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: palette.surface,
    ).copyWith(
      primary: palette.accent,
      onSurface: palette.text,
      surface: palette.surface,
    );

    final TextTheme textTheme = TextTheme(
      displaySmall: TextStyle(
        fontSize: NeuTokens.textTitle,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: palette.text,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: palette.text,
      ),
      bodyMedium: TextStyle(
        fontSize: NeuTokens.textBody,
        color: palette.text,
      ),
      bodySmall: TextStyle(
        fontSize: NeuTokens.textSmall,
        color: palette.textMuted,
      ),
      labelSmall: TextStyle(
        fontSize: NeuTokens.textCaption,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: palette.textMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.surface,
      canvasColor: palette.surface,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.displaySmall,
        iconTheme: IconThemeData(color: palette.text),
      ),
      iconTheme: IconThemeData(color: palette.text),
      dividerColor: palette.textMuted.withValues(alpha: 0.16),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NeuTokens.radiusS),
        ),
      ),
    );
  }
}
