import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_refraction_demo/main.dart';

void main() {
  testWidgets('tabs select in every theme and direction', (tester) async {
    for (final dark in [false, true]) {
      for (final rtl in [false, true]) {
        for (final selected in [0, 1, 2, 3]) {
          int? tab;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Directionality(
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: SizedBox(
                      width: 282,
                      height: 64,
                      child: FloatingNavigation(
                        dark: dark,
                        selected: selected,
                        onSelect: (value) => tab = value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final target = (selected + 2) % 4;
          await tester.tap(find.byKey(Key('tab-$target')));
          expect(tab, target);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('add button keeps its size and only counts presses', (
    tester,
  ) async {
    var adds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: AddButton(onAdd: () => adds++)),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('plus'))), const Size(56, 56));
    await tester.tap(find.byKey(const Key('plus')));
    expect(adds, 1);
  });

  testWidgets('demo builds, falls back without Impeller and morphs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GlassDemo(enableProbe: false));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('mode'))).data,
      contains('frostedFallback'),
    );
    await tester.tap(find.byKey(const Key('plus')));
    await tester.pump();
    expect(find.text('Add presses: 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('morph')));
    await tester.pumpAndSettle();
    expect(find.text('Separate'), findsOneWidget);
    for (final key in ['debug', 'lens', 'quality', 'adaptive', 'theme']) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }
    await tester.drag(
      find.byKey(const Key('glass-drag')),
      const Offset(20, -30),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('opaque')));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('mode'))).data,
      contains('opaque'),
    );
    expect(tester.takeException(), isNull);
  });
}
