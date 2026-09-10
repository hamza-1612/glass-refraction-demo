import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_refraction_demo/main.dart';

void main() {
  testWidgets('flat action stays centered and separate from destination selection', (tester) async {
    for (final dark in [false, true]) {
      for (final rtl in [false, true]) {
        for (final selected in [0, 1, 2, 3]) {
          var adds = 0;
          int? tab;
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
            child: Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: SizedBox(width: 288, height: 80, child: FloatingNavigation(
                dark: dark, selected: selected,
                onSelect: (value) => tab = value, onAdd: () => adds++,
              )),
            ),
          ))));
          await tester.pump();
          final plus = find.byKey(const Key('plus'));
          final nav = find.byType(FloatingNavigation);
          expect(tester.getSize(plus), const Size(56, 56));
          expect(tester.getCenter(plus).dx, closeTo(tester.getCenter(nav).dx, .01));
          await tester.tap(plus);
          expect(adds, 1);
          expect(tab, isNull);
          await tester.tap(find.byKey(const Key('tab-2')));
          expect(tab, 2);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
