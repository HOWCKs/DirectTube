import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/haptics.dart';
import '../../data/engine/download_engine.dart';
import '../../data/models/format_option.dart';
import '../../data/models/media_item.dart';
import '../../data/services/download_manager.dart';
import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../shared/widgets.dart';

/// Painel inferior com os formatos reais disponíveis para uma mídia.
///
/// Formatos que exigiriam juntar vídeo+áudio (muxing) aparecem marcados e
/// desabilitados — nunca prometemos algo que o build não entrega.
class FormatSheet extends StatefulWidget {
  const FormatSheet({
    super.key,
    required this.item,
    required this.manager,
    required this.preferAudio,
  });

  final MediaItem item;
  final DownloadManager manager;
  final bool preferAudio;

  @override
  State<FormatSheet> createState() => _FormatSheetState();
}

class _FormatSheetState extends State<FormatSheet> {
  late final Future<List<FormatOption>> _formats =
      widget.manager.formatsFor(widget.item);

  int? _selected;
  bool _starting = false;

  int? _defaultIndex(List<FormatOption> options) {
    final List<FormatOption> usable =
        widget.manager.downloadableFormats(options);
    if (usable.isEmpty) return null;
    for (int i = 0; i < options.length; i++) {
      if (options[i].needsMuxing) continue;
      if (widget.preferAudio && !options[i].isAudioOnly) continue;
      if (!widget.preferAudio && options[i].isAudioOnly) continue;
      return i;
    }
    for (int i = 0; i < options.length; i++) {
      if (!options[i].needsMuxing) return i;
    }
    return null;
  }

  Future<void> _start(FormatOption format) async {
    if (_starting) return;
    Haptics.fire(HapticStyle.medium);
    setState(() => _starting = true);

    final AppNav nav = AppScope.navOf(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final AppStrings t = Strings.of(context);

    try {
      await widget.manager.enqueue(item: widget.item, format: format);
      navigator.pop();
      nav.goTo(1);
      messenger.showSnackBar(
        SnackBar(content: Text('${t.queued}: ${widget.item.title}')),
      );
    } on EngineException catch (error) {
      if (!mounted) return;
      setState(() => _starting = false);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _starting = false);
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final NeuPalette palette = NeuPalette.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 46,
              height: 5,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: palette.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(NeuTokens.radiusS),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              MediaThumb(url: widget.item.thumbnailUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      <String>[
                        if (widget.item.author != null) widget.item.author!,
                        if (widget.item.duration != null)
                          Fmt.duration(widget.item.duration),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          NeuSectionTitle(t.formats),
          Flexible(
            child: FutureBuilder<List<FormatOption>>(
              future: _formats,
              builder: (BuildContext context,
                  AsyncSnapshot<List<FormatOption>> snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: palette.accent,
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      message: snapshot.error.toString(),
                    ),
                  );
                }

                final List<FormatOption> options =
                    snapshot.data ?? const <FormatOption>[];
                _selected ??= _defaultIndex(options);

                return SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      for (int i = 0; i < options.length; i++)
                        _chip(options[i], i, t),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          NeuButton(
            label: _starting ? '${t.running}…' : t.startDownload,
            icon: Icons.download_rounded,
            expand: true,
            enabled: _selected != null && !_starting,
            onTap: () {
              final int? index = _selected;
              if (index == null) return;
              // Reconstrói a opção escolhida a partir do estado da lista.
              _formats.then((List<FormatOption> options) {
                if (index < options.length) _start(options[index]);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(FormatOption option, int index, AppStrings t) {
    if (option.needsMuxing) {
      return Tooltip(
        message: t.needsMuxing,
        child: Opacity(
          opacity: 0.45,
          child: NeuChip(
            label: '${option.label} · ${option.isAudioOnly ? t.audioOnly : t.quality}',
            enabled: false,
          ),
        ),
      );
    }
    final String suffix = option.sizeBytes == null
        ? ''
        : ' · ${Fmt.bytes(option.sizeBytes)}';
    return NeuChip(
      label: '${option.label}$suffix',
      active: _selected == index,
      onTap: () {
        setState(() => _selected = index);
      },
    );
  }
}
