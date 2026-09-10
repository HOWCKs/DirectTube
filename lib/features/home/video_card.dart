import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../data/models/media_item.dart';
import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';

/// Card de feed no estilo dos grandes apps de download: thumbnail 16:9 com
/// selo de duração, título, canal · visualizações e ações rápidas.
class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDownload,
    required this.onWatch,
    required this.onShare,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onWatch;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    final String subtitle = <String>[
      if (item.author != null && item.author!.isNotEmpty) item.author!,
      if (item.viewCount != null && item.viewCount! > 0)
        '${Fmt.views(item.viewCount)} views',
    ].join(' · ');

    return NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.radiusL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(NeuTokens.radiusL),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _Thumb(url: item.thumbnailUrl),
                    if (item.duration != null)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            Fmt.duration(item.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: palette.text,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _Action(icon: Icons.download_rounded, onTap: onDownload),
                _Action(icon: Icons.play_arrow_rounded, onTap: onWatch),
                _Action(icon: Icons.share_rounded, onTap: onShare),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeuIconButton(
      icon: icon,
      size: 38,
      iconSize: 17,
      onTap: onTap,
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    if (url == null || url!.isEmpty) {
      return Container(
        color: palette.surface,
        child: Icon(Icons.music_note_rounded, color: palette.textMuted, size: 40),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (BuildContext c, Widget child, ImageChunkEvent? p) {
        if (p == null) return child;
        return Container(
          color: palette.surface,
          child: Center(
            child: CircularProgressIndicator(
                color: palette.accent, strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (BuildContext c, Object e, StackTrace? s) => Container(
        color: palette.surface,
        child:
            Icon(Icons.music_note_rounded, color: palette.textMuted, size: 40),
      ),
    );
  }
}
