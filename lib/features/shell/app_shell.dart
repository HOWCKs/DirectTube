import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../baixar/baixar_screen.dart';
import '../reproduzir/reproduzir_screen.dart';
import '../settings/settings_screen.dart';

/// Casca do app: 3 abas (Baixar · Reproduzir · Configurações) como no Snaptube.
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
                      BaixarScreen(),
                      ReproduzirScreen(),
                      SettingsScreen(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  child: NeuTabBar(
                    items: <NeuTabItem>[
                      NeuTabItem(icon: Icons.download_rounded, label: t.download),
                      NeuTabItem(
                          icon: Icons.play_circle_outline_rounded,
                          label: t.player),
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
