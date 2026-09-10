import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../app/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/haptics.dart';
import '../../core/link_parser.dart';
import '../../core/share.dart';
import '../../data/engine/download_engine.dart';
import '../../data/engine/youtube_explode_engine.dart';
import '../../data/models/media_item.dart';
import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../shared/widgets.dart';
import 'format_sheet.dart';
import 'video_card.dart';

/// Início no estilo dos grandes apps de download: feed de cards com
/// thumbnail + duração, canal · views e ações baixar/assistir/compartilhar,
/// além de chips de categoria e busca com rolagem infinita.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Category {
  const _Category(this.label, this.query);
  final String label;
  final String? query; // null = "Para você" (rotação de consultas populares)
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
  int _selectedCat = 0;

  static const List<String> _forYouPool = <String>[
    'músicas mais tocadas agora',
    'hits do momento brasil',
    'lançamentos música',
    'top músicas populares',
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted && _results.isEmpty && !_busy) _loadCategory(0);
    });
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

  List<_Category> _categories(AppStrings t) => <_Category>[
        _Category(t.forYou, null),
        const _Category('Funk', 'funk brasileiro'),
        const _Category('Sertanejo', 'sertanejo'),
        const _Category('Trap', 'trap brasil'),
        const _Category('Piseiro', 'piseiro'),
        const _Category('Lançamentos', 'músicas novas'),
        const _Category('Gospel', 'música gospel'),
        const _Category('Lo-fi', 'lofi beats'),
      ];

  String _feedQuery(int index) {
    final List<_Category> cats = _categories(Strings.of(context));
    final _Category cat = cats[index];
    if (cat.query != null) return cat.query!;
    final int slot =
        (DateTime.now().millisecondsSinceEpoch ~/ 3600000) % _forYouPool.length;
    return _forYouPool[slot];
  }

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

  Future<void> _loadCategory(int index) async {
    setState(() => _selectedCat = index);
    await _searchQuery(_feedQuery(index), fromFeed: true);
  }

  Future<void> _searchQuery(String query, {bool fromFeed = false}) async {
    if (query.isEmpty || _busy) return;
    Haptics.fire(HapticStyle.medium);
    setState(() {
      _busy = true;
      _error = null;
      _results = const <MediaItem>[];
      _cursor = null;
      _canMore = false;
      _didSearch = !fromFeed;
    });

    try {
      final YoutubeExplodeEngine? engine = _engine;
      if (engine == null) {
        setState(() => _error = AppStrings.forLocale(
            Localizations.localeOf(context)).noEngine);
        return;
      }
      final VideoSearchList page = await engine.searchPage(query);
      if (!mounted) return;
      setState(() {
        _cursor = page;
        _results = engine.mapResults(page);
        _canMore = true;
      });
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

  Future<void> _submit(String raw) async {
    final String value = raw.trim();
    if (value.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();

    if (LinkParser.looksLikeLink(value)) {
      Haptics.fire(HapticStyle.medium);
      setState(() {
        _busy = true;
        _error = null;
        _results = const <MediaItem>[];
        _didSearch = true;
      });
      try {
        final MediaItem item =
            await AppScope.downloads(context).resolve(value);
        if (!mounted) return;
        setState(() => _results = <MediaItem>[item]);
      } on EngineException catch (error) {
        if (!mounted) return;
        setState(() => _error = error.message);
      } catch (error) {
        if (!mounted) return;
        setState(() => _error = friendlySearchError(error));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      await _searchQuery(value);
    }
  }

  Future<void> _openFormats(MediaItem item, {bool preferAudio = false}) async {
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
        preferAudio: preferAudio || AppScope.settingsOf(context).preferAudio,
      ),
    );
  }

  Future<void> _watch(MediaItem item) async {
    Haptics.fire(HapticStyle.light);
    final YoutubeExplodeEngine? engine = _engine;
    if (engine == null) return;
    try {
      final String? url = await engine.previewUrl(item);
      if (!mounted) return;
      if (url == null) {
        _openFormats(item);
        return;
      }
      AppScope.audioOf(context).openVideoUrl(url: url, title: item.title);
      AppScope.navOf(context).showPlayer();
    } catch (_) {
      if (mounted) _openFormats(item);
    }
  }

  void _share(MediaItem item) {
    Haptics.fire(HapticStyle.light);
    shareText(item.sourceUrl);
  }

  Future<void> _openDetail(MediaItem item) async {
    Haptics.fire(HapticStyle.light);
    final NeuPalette palette = NeuPalette.of(context);
    final AppStrings t = Strings.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(NeuTokens.radiusL)),
      ),
      builder: (BuildContext sheet) {
        final String subtitle = <String>[
          if (item.author != null && item.author!.isNotEmpty) item.author!,
          if (item.viewCount != null && item.viewCount! > 0)
            '${Fmt.views(item.viewCount)} views',
        ].join(' · ');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.textMuted.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheet);
                    _watch(item);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(NeuTokens.radiusM),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          item.thumbnailUrl != null
                              ? Image.network(item.thumbnailUrl!,
                                  fit: BoxFit.cover)
                              : Container(color: palette.surface),
                          Container(color: Colors.black.withOpacity(0.25)),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.play_arrow_rounded,
                                  color: Colors.black87, size: 34),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: palette.text,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      subtitle,
                      style:
                          TextStyle(fontSize: 12.5, color: palette.textMuted),
                    ),
                  ),
                const SizedBox(height: 18),
                NeuButton(
                  label: t.save,
                  icon: Icons.download_rounded,
                  onTap: () {
                    Navigator.pop(sheet);
                    _openFormats(item);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: NeuButton(
                        label: t.music,
                        icon: Icons.headset_rounded,
                        onTap: () {
                          Navigator.pop(sheet);
                          _openFormats(item, preferAudio: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    NeuIconButton(
                      icon: Icons.share_rounded,
                      size: 48,
                      iconSize: 20,
                      onTap: () => _share(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chipsRow(AppStrings t) {
    final List<_Category> cats = _categories(t);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: cats.length,
        separatorBuilder: (BuildContext c, int i) =>
            const SizedBox(width: 10),
        itemBuilder: (BuildContext c, int i) => NeuChip(
          label: cats[i].label,
          active: _selectedCat == i,
          onTap: () => _loadCategory(i),
        ),
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
        const SizedBox(height: 18),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: Column(
                children: <Widget>[
                  CircularProgressIndicator(
                      color: palette.accent, strokeWidth: 2.5),
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
                  onTap: () => _didSearch
                      ? _submit(_controller.text)
                      : _loadCategory(_selectedCat),
                ),
              ],
            ),
          ),
        if (!_busy && _error == null) ...<Widget>[
          if (!_didSearch) ...<Widget>[
            _chipsRow(t),
            const SizedBox(height: 16),
          ],
          if (_results.isEmpty && !_loadingMore)
            EmptyState(
              icon: _didSearch ? Icons.search_off_rounded : Icons.whatshot_rounded,
              message: _didSearch ? t.noResults : t.tagline,
            ),
          for (final MediaItem item in _results)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: VideoCard(
                item: item,
                onTap: () => _openDetail(item),
                onDownload: () => _openFormats(item),
                onWatch: () => _watch(item),
                onShare: () => _share(item),
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
