import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/haptics.dart';
import '../data/models/download_task.dart';
import '../data/services/download_manager.dart';
import '../data/services/notifications_service.dart';
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
  final DownloadNotifications _notifications = DownloadNotifications();
  late final NotificationBridge _bridge = NotificationBridge(_notifications);

  @override
  void initState() {
    super.initState();
    Haptics.enabled = _settings.hapticsEnabled;
    widget.manager.setStoragePaths(
      base: _settings.storagePath,
      audio: _settings.audioStoragePath,
      video: _settings.videoStoragePath,
    );

    _notifications.init();
    DownloadNotifications.onOpen = _nav.showQueue;
    DownloadNotifications.onAction = (String taskId, String action) {
      if (action == 'cancel') {
        widget.manager.cancel(taskId);
        return;
      }
      DownloadStatus? status;
      for (final DownloadTask t in widget.manager.tasks) {
        if (t.id == taskId) {
          status = t.status;
          break;
        }
      }
      if (status == DownloadStatus.paused) {
        widget.manager.resume(taskId);
      } else {
        widget.manager.pause(taskId);
      }
    };
    widget.manager.addListener(_syncNotifications);
  }

  void _syncNotifications() {
    _bridge.sync(widget.manager.tasks);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_syncNotifications);
    _nav.dispose();
    super.dispose();
  }

  Future<void> _update(AppSettings next) async {
    setState(() => _settings = next);
    Haptics.enabled = next.hapticsEnabled;
    widget.manager.setStoragePaths(
      base: next.storagePath,
      audio: next.audioStoragePath,
      video: next.videoStoragePath,
    );
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
