import 'package:flutter_test/flutter_test.dart';
import 'package:glass_refraction_demo/glass_adaptivity.dart';
import 'package:glass_refraction_demo/refractive_glass.dart';

void main() {
  test('optics follow docs/glass-model.md §1.2', () {
    final bar = GlassOptics.forSize(80);
    expect(bar.band, closeTo(24, 1e-9));
    expect(bar.amount, closeTo(24, 1e-9));
    expect(bar.blurSigma, closeTo(3.2, 1e-9));
    // Small glass: clamped band and amount never exceed half the shape.
    final small = GlassOptics.forSize(20, strength: 1.5);
    expect(small.band, 12);
    expect(small.amount, lessThanOrEqualTo(10));
    // Large glass is "thicker" but capped.
    final big = GlassOptics.forSize(400);
    expect(big.band, 32);
    expect(big.amount, 28);
    expect(big.blurSigma, 6);
    expect(GlassOptics.forSize(80, strength: 0).amount, 0);
  });

  test('tone flip has hysteresis', () {
    expect(glassWantsDarkGlass(luminance: .8, current: true), isFalse);
    expect(glassWantsDarkGlass(luminance: .2, current: false), isTrue);
    expect(glassWantsDarkGlass(luminance: .5, current: true), isTrue);
    expect(glassWantsDarkGlass(luminance: .5, current: false), isFalse);
  });

  test('governor steps down under sustained load and up once', () {
    final g = GlassPerformanceGovernor(initial: GlassQuality.high);
    var t = Duration.zero;
    void feed(double ms, Duration span) {
      final end = t + span;
      while (t < end) {
        g.addSample(ms, t);
        t += const Duration(milliseconds: 16);
      }
    }

    feed(15, const Duration(seconds: 3)); // > 75% of 16.7 ms
    expect(g.quality, GlassQuality.medium);
    feed(15, const Duration(seconds: 3));
    expect(g.quality, GlassQuality.low);
    feed(15, const Duration(seconds: 3));
    expect(g.quality, GlassQuality.low);
    feed(3, const Duration(seconds: 12)); // < 40%
    expect(g.quality, GlassQuality.medium);
    feed(3, const Duration(seconds: 12)); // only one step up per session
    expect(g.quality, GlassQuality.medium);
    g.dispose();
  });
}
