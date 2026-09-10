import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_refraction_demo/refractive_glass.dart';

void main() {
  testWidgets('forced frost keeps controls interactive and reports fallback', (
    tester,
  ) async {
    GlassRenderMode? reported;
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 100,
            child: RefractiveGlass(
              forceFrostFallback: true,
              onModeChanged: (m) => reported = m,
              child: TextButton(
                onPressed: () => count++,
                child: const Text('Add'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(reported, GlassRenderMode.frostedFallback);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('Add'));
    expect(count, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced transparency bypasses filtering in both themes', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      GlassRenderMode? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 240,
            height: 100,
            child: RefractiveGlass(
              key: ValueKey(dark),
              dark: dark,
              reduceTransparency: true,
              onModeChanged: (m) => reported = m,
              child: const Text('Readable'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(reported, GlassRenderMode.opaque);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Readable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
