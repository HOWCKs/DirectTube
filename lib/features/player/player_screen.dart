import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/haptics.dart';
import '../../data/services/player_service.dart';
import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../shared/widgets.dart';

/// Player: áudio (just_audio) e vídeo (video_player) dos arquivos baixados.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final NeuPalette palette = NeuPalette.of(context);
    final AudioPlayerService audio = AppScope.audioOf(context);

    return AnimatedBuilder(
      animation: audio,
      builder: (BuildContext context, Widget? child) {
        if (!audio.hasItem) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              children: <Widget>[
                _title(t.nowPlaying, palette),
                const SizedBox(height: 20),
                EmptyState(
                  icon: Icons.graphic_eq_rounded,
                  message: t.nothingPlaying,
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: <Widget>[
            _title(t.nowPlaying, palette),
            const SizedBox(height: 18),
            if (audio.isVideo)
              VideoSurface(path: audio.videoPath!, title: audio.title ?? '')
            else
              AudioSurface(audio: audio),
          ],
        );
      },
    );
  }

  Widget _title(String text, NeuPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: NeuTokens.textTitle,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: palette.text,
        ),
      ),
    );
  }
}

/// Superfície de áudio: capa, barra de posição arrastável e controles.
class AudioSurface extends StatelessWidget {
  const AudioSurface({super.key, required this.audio});

  final AudioPlayerService audio;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NeuSurface(
          elevation: NeuElevation.raised,
          radius: NeuTokens.radiusL,
          height: 210,
          child: Center(
            child: NeuSurface(
              elevation: NeuElevation.pressedSoft,
              radius: NeuTokens.radiusL,
              width: 120,
              height: 120,
              child: Icon(Icons.music_note_rounded,
                  size: 44, color: palette.accent),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          audio.title ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 6),
        if ((audio.error ?? '').isNotEmpty)
          Text(
            audio.error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.accent),
          ),
        const SizedBox(height: 22),
        ValueListenableBuilder<Duration>(
          valueListenable: audio.position,
          builder: (BuildContext context, Duration position, Widget? child) {
            final Duration total = audio.duration;
            final double fraction = total.inMilliseconds == 0
                ? 0
                : (position.inMilliseconds / total.inMilliseconds)
                    .clamp(0.0, 1.0);
            return Column(
              children: <Widget>[
                _Seek(
                  fraction: fraction,
                  onSeek: (double value) {
                    final int millis =
                        (total.inMilliseconds * value).round();
                    audio.seek(Duration(milliseconds: millis));
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(Fmt.duration(position),
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: palette.textMuted)),
                    Text(Fmt.duration(total),
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: palette.textMuted)),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            NeuIconButton(
              icon: Icons.replay_10_rounded,
              size: 56,
              iconSize: 24,
              onTap: () => audio.skipBy(const Duration(seconds: -10)),
            ),
            const SizedBox(width: 18),
            Pressable(
              scale: 0.95,
              pressHaptic: HapticStyle.medium,
              onTap: () => audio.toggle(),
              builder: (BuildContext context, bool pressed) => NeuSurface(
                elevation:
                    pressed ? NeuElevation.pressed : NeuElevation.raised,
                radius: NeuTokens.radiusL,
                width: 78,
                height: 78,
                child: Icon(
                  audio.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 30,
                  color: palette.accent,
                ),
              ),
            ),
            const SizedBox(width: 18),
            NeuIconButton(
              icon: Icons.forward_10_rounded,
              size: 56,
              iconSize: 24,
              onTap: () => audio.skipBy(const Duration(seconds: 10)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Barra de posição interativa (trilho afundado + preenchimento no acento).
class _Seek extends StatelessWidget {
  const _Seek({required this.fraction, required this.onSeek});

  final double fraction;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails details) => _seekAt(context, details.globalPosition),
      onHorizontalDragUpdate: (DragUpdateDetails details) =>
          _seekAt(context, details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: NeuProgressBar(value: fraction, height: 8, showThumb: true),
      ),
    );
  }

  void _seekAt(BuildContext context, Offset globalPosition) {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset local = box.globalToLocal(globalPosition);
    final double value = (local.dx / box.size.width).clamp(0.0, 1.0);
    Haptics.fire(HapticStyle.selection);
    onSeek(value);
  }
}

/// Superfície de vídeo: `video_player` sobre arquivo local.
class VideoSurface extends StatefulWidget {
  const VideoSurface({super.key, required this.path, required this.title});

  final String path;
  final String title;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  late final VideoPlayerController _controller =
      VideoPlayerController.file(File(widget.path));

  bool _ready = false;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((void _) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
      _ticker = Timer.periodic(const Duration(milliseconds: 400), (Timer _) {
        if (mounted) setState(() {});
      });
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() => _error = 'Não consegui abrir este vídeo.');
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NeuSurface(
          elevation: NeuElevation.pressed,
          radius: NeuTokens.radiusL,
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(NeuTokens.radiusM),
            child: _error != null
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: 13, color: palette.accent),
                      ),
                    ),
                  )
                : !_ready
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: palette.accent, strokeWidth: 2.5),
                        ),
                      )
                    : AspectRatio(
                        aspectRatio: _controller.value.aspectRatio == 0
                            ? 16 / 9
                            : _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: palette.text),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            NeuIconButton(
              icon: Icons.replay_10_rounded,
              size: 56,
              iconSize: 24,
              onTap: () {
                final Duration target = _controller.value.position -
                    const Duration(seconds: 10);
                _controller
                    .seek(target < Duration.zero ? Duration.zero : target);
              },
            ),
            const SizedBox(width: 18),
            Pressable(
              scale: 0.95,
              pressHaptic: HapticStyle.medium,
              onTap: () {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
                setState(() {});
              },
              builder: (BuildContext context, bool pressed) => NeuSurface(
                elevation:
                    pressed ? NeuElevation.pressed : NeuElevation.raised,
                radius: NeuTokens.radiusL,
                width: 78,
                height: 78,
                child: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 30,
                  color: palette.accent,
                ),
              ),
            ),
            const SizedBox(width: 18),
            NeuIconButton(
              icon: Icons.forward_10_rounded,
              size: 56,
              iconSize: 24,
              onTap: () => _controller.seek(_controller.value.position +
                  const Duration(seconds: 10)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${Fmt.duration(_controller.value.position)} / '
          '${Fmt.duration(_controller.value.duration)}',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: palette.textMuted),
        ),
      ],
    );
  }
}
