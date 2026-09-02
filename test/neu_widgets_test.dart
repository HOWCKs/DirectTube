import 'package:directtube/design/neu_palette.dart';
import 'package:directtube/design/neu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('NeuButton dispara onTap', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(_host(
      NeuButton(label: 'Baixar', onTap: () => taps++),
    ));

    expect(find.text('Baixar'), findsOneWidget);
    await tester.tap(find.text('Baixar'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('NeuButton afunda enquanto pressionado e volta ao soltar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(const NeuButton(label: 'Baixar')));

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.text('Baixar')));
    await tester.pump(const Duration(milliseconds: 60));

    NeuSurface surface =
        tester.widgetList<NeuSurface>(find.byType(NeuSurface)).first;
    expect(surface.elevation, NeuElevation.pressedSoft);

    await gesture.up();
    await tester.pumpAndSettle();

    surface = tester.widgetList<NeuSurface>(find.byType(NeuSurface)).first;
    expect(surface.elevation, NeuElevation.soft);
  });

  testWidgets('NeuButton ativo fica permanentemente afundado',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(const NeuButton(label: 'MP3', active: true)));
    final NeuSurface surface =
        tester.widgetList<NeuSurface>(find.byType(NeuSurface)).first;
    expect(surface.elevation, NeuElevation.pressedSoft);
  });

  testWidgets('NeuToggle alterna o valor ao tocar',
      (WidgetTester tester) async {
    bool value = false;
    await tester.pumpWidget(_host(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => NeuToggle(
          value: value,
          onChanged: (bool next) => setState(() => value = next),
        ),
      ),
    ));

    await tester.tap(find.byType(NeuToggle));
    await tester.pumpAndSettle();
    expect(value, isTrue);

    await tester.tap(find.byType(NeuToggle));
    await tester.pumpAndSettle();
    expect(value, isFalse);
  });

  testWidgets('NeuProgressBar trunca valores fora de 0..1',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(const NeuProgressBar(value: 1.8)));
    expect(
      tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      1.0,
    );

    await tester.pumpWidget(_host(const NeuProgressBar(value: -0.4)));
    expect(
      tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      lessThan(0.001),
    );
  });

  testWidgets('NeuTabBar muda a aba selecionada',
      (WidgetTester tester) async {
    int index = 0;
    await tester.pumpWidget(_host(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => NeuTabBar(
          items: const <NeuTabItem>[
            NeuTabItem(icon: Icons.home_rounded, label: 'Início'),
            NeuTabItem(icon: Icons.tune_rounded, label: 'Ajustes'),
          ],
          index: index,
          onChanged: (int next) => setState(() => index = next),
        ),
      ),
    ));

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(index, 1);
  });

  testWidgets('NeuSurface usa a cor da superfície como fundo (nunca branco)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(const NeuSurface(child: SizedBox.shrink())));
    final Container container = tester.widget<Container>(find.byType(Container));
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, NeuTokens.light.surface);
    expect(decoration.boxShadow, hasLength(2));
  });

  testWidgets('estado pressionado não desenha sombra externa',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(
      const NeuSurface(
        elevation: NeuElevation.pressed,
        child: SizedBox.shrink(),
      ),
    ));
    final Container container = tester.widget<Container>(find.byType(Container));
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
