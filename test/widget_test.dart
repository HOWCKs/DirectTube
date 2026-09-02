// Arquivo propositalmente versionado: `flutter create` (rodado na CI para
// materializar o projeto Android) criaria um `test/widget_test.dart` padrão
// referenciando `MyApp`, que não existe aqui. Este smoke test toma o lugar.
import 'package:directtube/design/neu_palette.dart';
import 'package:directtube/design/neu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('superfície levantada mantém a cor única do spec',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NeuSurface(
              width: 120,
              height: 120,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    final Container container = tester.widget<Container>(find.byType(Container));
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, NeuTokens.light.surface);
    expect(decoration.boxShadow, hasLength(2));
  });

  testWidgets('NeuChip ativo usa o acento', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: NeuChip(label: '1080p', active: true))),
      ),
    );

    final Text label = tester.widget<Text>(find.text('1080p'));
    expect(label.style?.color, NeuTokens.light.accent);
  });
}
