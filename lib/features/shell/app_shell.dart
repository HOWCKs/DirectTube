import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../downloads/downloads_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../player/player_screen.dart';
import '../settings/settings_screen.dart';

/// Casca do app: conteúdo + barra de navegação inferior neumórfica.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final AppNav nav = AppScope.navOf(context);

    return AnimatedBuilder(
      animation: nav,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: IndexedStack(
                    index: nav.index,
                    children: const <Widget>[
                      HomeScreen(),
                      DownloadsScreen(),
                      PlayerScreen(),
                      LibraryScreen(),
                      SettingsScreen(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  child: NeuTabBar(
                    items: <NeuTabItem>[
                      NeuTabItem(icon: Icons.home_rounded, label: t.home),
                      NeuTabItem(
                          icon: Icons.download_rounded, label: t.downloads),
                      NeuTabItem(
                          icon: Icons.play_circle_outline_rounded,
                          label: t.player),
                      NeuTabItem(
                          icon: Icons.video_library_rounded, label: t.library),
                      NeuTabItem(icon: Icons.tune_rounded, label: t.settings),
                    ],
                    index: nav.index,
                    onChanged: nav.goTo,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
