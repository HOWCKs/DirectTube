import 'package:flutter/widgets.dart';

import '../data/services/download_manager.dart';
import '../data/services/player_service.dart';
import '../data/services/search_service.dart';
import '../data/services/settings_store.dart';

/// Navegação entre as abas, acessível de qualquer tela.
class AppNav extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void goTo(int value) {
    if (_index == value) return;
    _index = value;
    notifyListeners();
  }
}

/// Injeta os serviços globais sem depender de um package de injeção.
class AppScope extends InheritedNotifier<DownloadManager> {
  const AppScope({
    super.key,
    required DownloadManager manager,
    required this.settings,
    required this.updateSettings,
    required this.search,
    required this.audioPlayer,
    required this.nav,
    required super.child,
  }) : super(notifier: manager);

  final AppSettings settings;
  final ValueChanged<AppSettings> updateSettings;
  final SearchService search;
  final AudioPlayerService audioPlayer;
  final AppNav nav;

  static AppScope of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope ausente na árvore de widgets.');
    return scope!;
  }

  static DownloadManager downloads(BuildContext context) => of(context).notifier!;

  static AppSettings settings(BuildContext context) => of(context).settings;

  static SearchService searchOf(BuildContext context) => of(context).search;

  static AudioPlayerService audioOf(BuildContext context) =>
      of(context).audioPlayer;

  static AppNav navOf(BuildContext context) => of(context).nav;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings ||
      notifier != oldWidget.notifier ||
      nav != oldWidget.nav;
}
