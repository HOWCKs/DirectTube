import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/haptics.dart';
import '../../data/models/download_task.dart';
import '../../data/services/download_manager.dart';
import '../../data/services/player_service.dart';
import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../shared/widgets.dart';

/// Fila de downloads: progresso real, pausa, retomada, cancelamento.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final NeuPalette palette = NeuPalette.of(context);
    // `AppScope.downloads` usa InheritedNotifier: a tela redesenha sozinha
    // a cada `notifyListeners` do DownloadManager.
    final List<DownloadTask> tasks = AppScope.downloads(context).tasks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 20),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: NeuTokens.textTitle,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: palette.text,
              ),
              children: <InlineSpan>[
                TextSpan(text: t.downloads.toLowerCase()),
                TextSpan(
                  text: ' · ${tasks.length}',
                  style: TextStyle(color: palette.accent),
                ),
              ],
            ),
          ),
        ),
        if (tasks.isEmpty)
          EmptyState(
            icon: Icons.download_rounded,
            message: t.emptyQueue,
          ),
        if (tasks.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: NeuButton(
                  label: t.pauseAll,
                  icon: Icons.pause_rounded,
                  expand: true,
                  onTap: () => AppScope.downloads(context).pauseAll(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: NeuButton(
                  label: t.clearFinished,
                  icon: Icons.cleaning_services_rounded,
                  expand: true,
                  onTap: () => AppScope.downloads(context).clearFinished(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (final DownloadTask task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DownloadCard(task: task),
            ),
        ],
      ],
    );
  }
}

/// Cartão de uma tarefa, com estado, progresso e ações.
class DownloadCard extends StatelessWidget {
  const DownloadCard({super.key, required this.task});

  final DownloadTask task;

  String _statusLabel(AppStrings t) {
    switch (task.status) {
      case DownloadStatus.queued:
        return t.queued;
      case DownloadStatus.running:
        return t.running;
      case DownloadStatus.paused:
        return t.paused;
      case DownloadStatus.completed:
        return t.completed;
      case DownloadStatus.failed:
        return t.failed;
      case DownloadStatus.canceled:
        return t.canceled;
    }
  }

  String _detail(AppStrings t) {
    final List<String> parts = <String>[
      if (task.formatLabel != null) task.formatLabel!,
      task.isAudioOnly ? t.audioOnly : '${task.extension.toUpperCase()}',
    ];
    if (task.status == DownloadStatus.running &&
        task.speedBytesPerSecond > 0) {
      parts.add(Fmt.speed(task.speedBytesPerSecond));
    }
    if (task.totalBytes != null) {
      parts.add('${Fmt.bytes(task.receivedBytes)} / ${Fmt.bytes(task.totalBytes)}');
    } else if (task.receivedBytes > 0) {
      parts.add(Fmt.bytes(task.receivedBytes));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final NeuPalette palette = NeuPalette.of(context);
    final DownloadManager manager = AppScope.downloads(context);
    final AppNav nav = AppScope.navOf(context);
    final AudioPlayerService audio = AppScope.audioOf(context);

    return NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.radiusM,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(
                label: _statusLabel(t),
                active: task.status == DownloadStatus.running ||
                    task.status == DownloadStatus.completed,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _detail(t),
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
          const SizedBox(height: 12),
          NeuProgressBar(
            value: task.isComplete ? 1 : task.progress,
            showThumb: task.status == DownloadStatus.running,
          ),
          if ((task.error ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              task.error!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: palette.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (task.status.canPause)
                NeuIconButton(
                  icon: Icons.pause_rounded,
                  size: 40,
                  iconSize: 18,
                  tooltip: t.pauseAll,
                  onTap: () => manager.pause(task.id),
                ),
              if (task.status.canResume) ...<Widget>[
                const SizedBox(width: 10),
                NeuIconButton(
                  icon: Icons.play_arrow_rounded,
                  size: 40,
                  iconSize: 18,
                  tooltip: t.retry,
                  onTap: () => manager.resume(task.id),
                ),
              ],
              if (task.isComplete && task.filePath != null) ...<Widget>[
                const SizedBox(width: 10),
                NeuIconButton(
                  icon: task.isAudioOnly
                      ? Icons.play_circle_outline_rounded
                      : Icons.smart_display_rounded,
                  size: 40,
                  iconSize: 18,
                  tooltip: t.player,
                  onTap: () {
                    Haptics.fire(HapticStyle.light);
                    final String path = task.filePath!;
                    if (task.isAudioOnly) {
                      audio.open(path: path, title: task.title);
                    } else {
                      audio.openVideo(path: path, title: task.title);
                    }
                    nav.showPlayer();
                  },
                ),
              ],
              if (task.status.canCancel) ...<Widget>[
                const SizedBox(width: 10),
                NeuIconButton(
                  icon: Icons.close_rounded,
                  size: 40,
                  iconSize: 18,
                  tooltip: t.cancel,
                  onTap: () => manager.cancel(task.id),
                ),
              ],
              const SizedBox(width: 10),
              NeuIconButton(
                icon: Icons.delete_outline_rounded,
                size: 40,
                iconSize: 18,
                tooltip: t.remove,
                onTap: () => manager.remove(task.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
