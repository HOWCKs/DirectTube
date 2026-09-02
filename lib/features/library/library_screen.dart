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

enum LibraryFilter { all, music, videos }

/// Biblioteca: tudo que já foi baixado, pronto para tocar.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryFilter _filter = LibraryFilter.all;

  void _play(DownloadTask task) {
    final String? path = task.filePath;
    if (path == null) return;
    Haptics.fire(HapticStyle.light);

    final AudioPlayerService audio = AppScope.audioOf(context);
    final AppNav nav = AppScope.navOf(context);
    if (task.isAudioOnly) {
      audio.open(path: path, title: task.title);
    } else {
      audio.openVideo(path: path, title: task.title);
    }
    nav.showPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final NeuPalette palette = NeuPalette.of(context);
    final DownloadManager manager = AppScope.downloads(context);

    final List<DownloadTask> all = manager.library;
    final List<DownloadTask> items = all.where((DownloadTask task) {
      switch (_filter) {
        case LibraryFilter.all:
          return true;
        case LibraryFilter.music:
          return task.isAudioOnly;
        case LibraryFilter.videos:
          return !task.isAudioOnly;
      }
    }).toList(growable: false);

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
                TextSpan(text: t.library.toLowerCase()),
                TextSpan(
                  text: ' · ${all.length}',
                  style: TextStyle(color: palette.accent),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: <Widget>[
            NeuChip(
              label: '${t.home} (${all.length})',
              active: _filter == LibraryFilter.all,
              onTap: () => setState(() => _filter = LibraryFilter.all),
            ),
            const SizedBox(width: 12),
            NeuChip(
              label: t.music,
              active: _filter == LibraryFilter.music,
              onTap: () => setState(() => _filter = LibraryFilter.music),
            ),
            const SizedBox(width: 12),
            NeuChip(
              label: t.videos,
              active: _filter == LibraryFilter.videos,
              onTap: () => setState(() => _filter = LibraryFilter.videos),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.library_music_rounded,
            message: t.emptyLibrary,
          ),
        for (final DownloadTask task in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: NeuListRow(
              title: task.title,
              subtitle: <String>[
                task.formatLabel ?? task.extension.toUpperCase(),
                Fmt.bytes(task.totalBytes ?? 0),
              ].join(' · '),
              leading: MediaThumb(
                width: 56,
                height: 56,
                icon: task.isAudioOnly
                    ? Icons.music_note_rounded
                    : Icons.movie_rounded,
              ),
              onTap: () => _play(task),
              trailing: NeuIconButton(
                icon: Icons.play_arrow_rounded,
                size: 42,
                iconSize: 18,
                onTap: () => _play(task),
              ),
            ),
          ),
      ],
    );
  }
}
