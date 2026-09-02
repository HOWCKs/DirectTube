import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';
import '../downloads/downloads_screen.dart';
import '../home/home_screen.dart';

/// Aba "Baixar": alterna entre Buscar (rolagem infinita) e a Fila de downloads.
class BaixarScreen extends StatelessWidget {
  const BaixarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final AppNav nav = AppScope.navOf(context);
    final int queueCount = AppScope.downloads(context).activeCount;

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
                    label: t.searchAction,
                    active: nav.baixarSub == 0,
                    onTap: () => nav.setBaixarSub(0),
                  ),
                  const SizedBox(width: 12),
                  NeuChip(
                    label: '${t.downloads} · $queueCount',
                    active: nav.baixarSub == 1,
                    onTap: () => nav.setBaixarSub(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: nav.baixarSub,
                children: const <Widget>[HomeScreen(), DownloadsScreen()],
              ),
            ),
          ],
        );
      },
    );
  }
}
