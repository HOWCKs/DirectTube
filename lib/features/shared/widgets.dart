import 'package:flutter/material.dart';

import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';

/// Miniatura de mídia em moldura afundada (mantém o idioma neumórfico).
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    this.url,
    this.width = 96,
    this.height = 68,
    this.icon,
  });

  final String? url;
  final double width;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(NeuTokens.radiusS);

    return NeuSurface(
      elevation: NeuElevation.pressedSoft,
      radius: NeuTokens.radiusS,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: url == null || url!.isEmpty
            ? Icon(icon ?? Icons.movie_outlined, size: 22, color: palette.textMuted)
            : Image.network(
                url!,
                fit: BoxFit.cover,
                width: width,
                height: height,
                errorBuilder: (BuildContext _, Object __, StackTrace? ___) =>
                    Icon(icon ?? Icons.movie_outlined,
                        size: 22, color: palette.textMuted),
                loadingBuilder:
                    (BuildContext _, Widget child, ImageChunkEvent? progress) {
                  if (progress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.accent,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Rótulo de status com a cor do acento quando ativo.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: active ? 0.14 : 0.0),
        borderRadius: BorderRadius.circular(NeuTokens.radiusS),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: active ? palette.accent : palette.textMuted,
        ),
      ),
    );
  }
}

/// Estado vazio padrão (fila vazia, busca sem resultado, biblioteca vazia).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return NeuSurface(
      elevation: NeuElevation.pressed,
      radius: NeuTokens.radiusL,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 34, color: palette.textMuted),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: NeuTokens.textSmall + 1,
              height: 1.5,
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
