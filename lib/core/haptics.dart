import 'dart:async';

import 'package:flutter/services.dart';

/// Estilos de resposta tátil usados pelo app.
///
/// Política: toque simples = `selection`; alternar estado = `light`;
/// ação destrutiva/erro = `heavy`. Nada de vibração contínua.
enum HapticStyle { none, selection, light, medium, heavy, success, error }

class Haptics {
  const Haptics._();

  /// Ligado/desligado pelo usuário em Ajustes (persistido em `SettingsStore`).
  static bool enabled = true;

  static Future<void> play(HapticStyle style) async {
    if (!enabled || style == HapticStyle.none) return;
    switch (style) {
      case HapticStyle.none:
        return;
      case HapticStyle.selection:
        await HapticFeedback.selectionClick();
      case HapticStyle.light:
        await HapticFeedback.lightImpact();
      case HapticStyle.medium:
        await HapticFeedback.mediumImpact();
      case HapticStyle.heavy:
        await HapticFeedback.heavyImpact();
      case HapticStyle.success:
        await HapticFeedback.mediumImpact();
      case HapticStyle.error:
        await HapticFeedback.heavyImpact();
    }
  }

  /// Versão "dispara e esquece" para callbacks de UI.
  static void fire(HapticStyle style) => unawaited(play(style));
}
