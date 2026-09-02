import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/haptics.dart';
import '../../core/link_parser.dart';
import '../../data/engine/download_engine.dart';
import '../../data/models/media_item.dart';
import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../shared/widgets.dart';
import 'format_sheet.dart';

/// Tela inicial: colar um link ou buscar de verdade no YouTube.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();

  List<MediaItem> _results = const <MediaItem>[];
  bool _busy = false;
  String? _error;
  bool _didSearch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final String value = raw.trim();
    if (value.isEmpty || _busy) return;

    Haptics.fire(HapticStyle.medium);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _results = const <MediaItem>[];
    });

    try {
      if (LinkParser.looksLikeLink(value)) {
        final MediaItem item = await AppScope.downloads(context).resolve(value);
        if (!mounted) return;
        setState(() {
          _results = <MediaItem>[item];
          _didSearch = true;
        });
      } else {
        final List<MediaItem> results =
            await AppScope.searchOf(context).search(value);
        if (!mounted) return;
        setState(() {
          _results = results;
          _didSearch = true;
        });
      }
    } on EngineException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFormats(MediaItem item) async {
    Haptics.fire(HapticStyle.light);
    final NeuPalette palette = NeuPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(NeuTokens.radiusL)),
      ),
      builder: (BuildContext sheetContext) => FormatSheet(
        item: item,
        manager: AppScope.downloads(context),
        preferAudio: AppScope.settingsOf(context).preferAudio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final NeuPalette palette = NeuPalette.of(context);

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
                const TextSpan(text: 'Direct'),
                TextSpan(text: 'Tube', style: TextStyle(color: palette.accent)),
              ],
            ),
          ),
        ),
        NeuField(
          controller: _controller,
          hintText: t.searchHint,
          prefixIcon: Icons.search_rounded,
          keyboardType: TextInputType.url,
          onSubmitted: _submit,
          suffix: NeuIconButton(
            icon: Icons.arrow_downward_rounded,
            tooltip: t.searchAction,
            size: 46,
            onTap: () => _submit(_controller.text),
          ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: Column(
                children: <Widget>[
                  CircularProgressIndicator(color: palette.accent, strokeWidth: 2.5),
                  const SizedBox(height: 14),
                  Text(
                    LinkParser.looksLikeLink(_controller.text)
                        ? t.resolving
                        : t.searching,
                    style: TextStyle(fontSize: 13, color: palette.textMuted),
                  ),
                ],
              ),
            ),
          ),
        if (!_busy && _error != null)
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: EmptyState(
              icon: Icons.link_off_rounded,
              message: _error!,
            ),
          ),
        if (!_busy && _error == null && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: EmptyState(
              icon: _didSearch ? Icons.search_off_rounded : Icons.link_rounded,
              message: _didSearch ? t.noResults : t.tagline,
            ),
          ),
        if (!_busy && _results.isNotEmpty) ...<Widget>[
          NeuSectionTitle(t.trendingTitle),
          for (final MediaItem item in _results)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NeuListRow(
                title: item.title,
                subtitle: <String>[
                  if (item.author != null) item.author!,
                  if (item.duration != null) Fmt.duration(item.duration),
                ].join(' · '),
                leading: MediaThumb(url: item.thumbnailUrl),
                onTap: () => _openFormats(item),
                trailing: NeuIconButton(
                  icon: Icons.download_rounded,
                  size: 42,
                  iconSize: 18,
                  onTap: () => _openFormats(item),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
