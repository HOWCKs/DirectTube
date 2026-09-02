import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../library/library_screen.dart';
import '../player/player_screen.dart';

/// Aba "Reproduzir": alterna entre o Player e a Biblioteca de baixados.
class ReproduzirScreen extends StatelessWidget {
  const ReproduzirScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final AppNav nav = AppScope.navOf(context);
    final int libraryCount = AppScope.downloads(context).completedCount;

    return AnimatedBuilder(
      animation: nav,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: <Widget>[
                  NeuChip(
                    label: t.player,
                    active: nav.reproSub == 0,
                    onTap: () => nav.setReproSub(0),
                  ),
                  const SizedBox(width: 12),
                  NeuChip(
                    label: '${t.library} · $libraryCount',
                    active: nav.reproSub == 1,
                    onTap: () => nav.setReproSub(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: nav.reproSub,
                children: const <Widget>[PlayerScreen(), LibraryScreen()],
              ),
            ),
          ],
        );
      },
    );
  }
}
