import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:glass_refraction_demo/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Impeller demo loads shader and survives movement/themes', (
    tester,
  ) async {
    expect(
      ui.ImageFilter.isShaderFilterSupported,
      isTrue,
      reason:
          'This gate must run on an Impeller device, not a frost-only backend.',
    );
    await tester.pumpWidget(const GlassDemo());
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final status = tester.widget<Text>(find.byKey(const Key('mode'))).data!;
      if (status.contains('refractive')) break;
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('mode'))).data,
      contains('refractive'),
    );
    await tester.tap(find.byKey(const Key('plus')));
    await tester.pump();
    expect(find.text('Add presses: 1'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('glass-drag')),
      const Offset(25, -35),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('motion')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('theme')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('opaque')));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('mode'))).data,
      contains('opaque'),
    );
    // Visual alignment, GLES orientation and frame timing still need device inspection.
  });
}
