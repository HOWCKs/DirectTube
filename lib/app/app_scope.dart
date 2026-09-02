import 'package:flutter/widgets.dart';

import '../data/services/download_manager.dart';
import '../data/services/player_service.dart';
import '../data/services/search_service.dart';
import '../data/services/settings_store.dart';

/// Navegação entre as abas, acessível de qualquer tela.
///
/// Modelo de 3 abas (Baixar · Reproduzir · Configurações), cada uma com uma
/// sub-seção interna (ex.: Baixar tem "Buscar" e "Fila").
class AppNav extends ChangeNotifier {
  int _index = 0;
  int _baixarSub = 0;
  int _reproSub = 0;

  int get index => _index;
  int get baixarSub => _baixarSub;
  int get reproSub => _reproSub;

  void goTo(int value) {
    if (_index == value) return;
    _index = value;
    notifyListeners();
  }

  void setBaixarSub(int value) {
    if (_baixarSub == value) return;
    _baixarSub = value;
    notifyListeners();
  }

  void setReproSub(int value) {
    if (_reproSub == value) return;
    _reproSub = value;
    notifyListeners();
  }

  /// Atalho usado após enfileirar um download: vai p/ Baixar > Fila.
  void showQueue() {
    _baixarSub = 1;
    _index = 0;
    notifyListeners();
  }

  /// Atalho usado ao tocar em "reproduzir": vai p/ Reproduzir > Player.
  void showPlayer() {
    _reproSub = 0;
    _index = 1;
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

  static AppSettings settingsOf(BuildContext context) => of(context).settings;

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
