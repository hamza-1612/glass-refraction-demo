import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_refraction_demo/main.dart';
import 'package:glass_refraction_demo/refractive_glass.dart';

void main() {
  testWidgets('mobile demo switches lens, scenes and independent dispersion', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GlassDemo());
    await tester.pumpAndSettle();
    expect(find.byType(FloatingNavigation), findsOneWidget);
    await tester.tap(find.byKey(const Key('lens')));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingNavigation), findsNothing);
    final before = tester.getTopLeft(find.byKey(const Key('glass-drag')));
    await tester.drag(find.byKey(const Key('glass-drag')), const Offset(30, 35));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byKey(const Key('glass-drag')));
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
    final split = tester.widget<Slider>(find.byKey(const Key('dispersion')));
    split.onChanged!(0);
    await tester.pumpAndSettle();
    final glass = tester.widget<RefractiveGlass>(find.byType(RefractiveGlass));
    expect(glass.dispersion, 0);
    expect(glass.strength, 14);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('scene')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const Key('theme')));
    await tester.tap(find.byKey(const Key('lens')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plus')));
    await tester.pumpAndSettle();
    expect(find.text('Add presses: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
