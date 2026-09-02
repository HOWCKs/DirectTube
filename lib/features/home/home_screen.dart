import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../app/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/haptics.dart';
import '../../core/link_parser.dart';
import '../../data/engine/download_engine.dart';
import '../../data/engine/youtube_explode_engine.dart';
import '../../data/models/media_item.dart';
import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../shared/widgets.dart';
import 'format_sheet.dart';

/// Busca com rolagem infinita: cola um link ou pesquisa e vai paginando.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<MediaItem> _results = const <MediaItem>[];
  VideoSearchList? _cursor;
  bool _busy = false;
  bool _loadingMore = false;
  bool _canMore = false;
  String? _error;
  bool _didSearch = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  YoutubeExplodeEngine? get _engine => AppScope.downloads(context)
      .registry
      .byId('youtube-explode') as YoutubeExplodeEngine?;

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final ScrollPosition position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final YoutubeExplodeEngine? engine = _engine;
    final VideoSearchList? cursor = _cursor;
    if (engine == null || cursor == null || !_canMore || _loadingMore) return;

    setState(() => _loadingMore = true);
    try {
      final VideoSearchList? next = await engine.moreResults(cursor);
      if (!mounted) return;
      if (next == null || next.isEmpty) {
        setState(() {
          _canMore = false;
          _loadingMore = false;
        });
        return;
      }
      setState(() {
        _cursor = next;
        _results = <MediaItem>[..._results, ...engine.mapResults(next)];
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
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
      _cursor = null;
      _canMore = false;
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
        final YoutubeExplodeEngine? engine = _engine;
        if (engine == null) {
          setState(() => _error = AppStrings.forLocale(
              Localizations.localeOf(context)).noEngine);
          return;
        }
        final VideoSearchList page = await engine.searchPage(value);
        if (!mounted) return;
        setState(() {
          _cursor = page;
          _results = engine.mapResults(page);
          _canMore = true;
          _didSearch = true;
        });
      }
    } on EngineException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlySearchError(error));
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
      controller: _scroll,
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
            child: Column(
              children: <Widget>[
                EmptyState(icon: Icons.link_off_rounded, message: _error!),
                const SizedBox(height: 14),
                NeuButton(
                  label: t.retry,
                  icon: Icons.refresh_rounded,
                  onTap: () => _submit(_controller.text),
                ),
              ],
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
          if (_loadingMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: CircularProgressIndicator(
                    color: palette.accent, strokeWidth: 2),
              ),
            ),
        ],
      ],
    );
  }
}

String friendlySearchError(Object error) {
  final String text = error.toString();
  if (text.contains('RequestLimitExceededException') ||
      text.contains('rate limit')) {
    return 'Muitas buscas vindas deste IP agora. Aguarde um pouco e tente de novo.';
  }
  if (text.length > 160) return '${text.substring(0, 160)}…';
  return text;
}
