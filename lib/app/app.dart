import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/haptics.dart';
import '../data/services/download_manager.dart';
import '../data/services/player_service.dart';
import '../data/services/search_service.dart';
import '../data/services/settings_store.dart';
import '../design/neu_theme.dart';
import '../features/shell/app_shell.dart';
import '../l10n/app_strings.dart';
import 'app_scope.dart';

/// Raiz do app: tema neumórfico, idioma e injeção dos serviços.
class DirectTubeApp extends StatefulWidget {
  const DirectTubeApp({
    super.key,
    required this.settingsStore,
    required this.manager,
    required this.search,
    required this.audioPlayer,
  });

  final SettingsStore settingsStore;
  final DownloadManager manager;
  final SearchService search;
  final AudioPlayerService audioPlayer;

  @override
  State<DirectTubeApp> createState() => _DirectTubeAppState();
}

class _DirectTubeAppState extends State<DirectTubeApp> {
  late AppSettings _settings = widget.settingsStore.load();
  final AppNav _nav = AppNav();

  @override
  void initState() {
    super.initState();
    Haptics.enabled = _settings.hapticsEnabled;
    widget.manager.setStoragePath(_settings.storagePath);
  }

  @override
  void dispose() {
    _nav.dispose();
    super.dispose();
  }

  Future<void> _update(AppSettings next) async {
    setState(() => _settings = next);
    Haptics.enabled = next.hapticsEnabled;
    widget.manager.setStoragePath(next.storagePath);
    await widget.settingsStore.save(next);
  }

  static Locale _localeOf(String code) {
    final List<String> parts = code.split('_');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DirectTube',
      debugShowCheckedModeBanner: false,
      theme: NeuTheme.light(),
      darkTheme: NeuTheme.dark(),
      themeMode: _settings.darkTheme ? ThemeMode.dark : ThemeMode.light,
      locale: _localeOf(_settings.localeCode),
      supportedLocales: Strings.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        Strings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppScope(
        manager: widget.manager,
        settings: _settings,
        updateSettings: _update,
        search: widget.search,
        audioPlayer: widget.audioPlayer,
        nav: _nav,
        child: const AppShell(),
      ),
    );
  }
}
