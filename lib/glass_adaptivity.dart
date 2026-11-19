import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'refractive_glass.dart';

/// Picks a [GlassQuality] from measured raster times (docs/glass-model.md §5.3).
///
/// Steps down when the 90th-percentile raster time stays above 75% of the
/// frame budget for 2 s; steps up (once per session) when it stays under 40%
/// for 10 s. Only frames that are actually drawn are measured.
class GlassPerformanceGovernor extends ChangeNotifier {
  GlassPerformanceGovernor({
    GlassQuality initial = GlassQuality.medium,
    this.refreshRate = 60,
  }) : _quality = initial;

  /// Display refresh rate in Hz; sets the frame budget.
  double refreshRate;

  GlassQuality _quality;
  GlassQuality get quality => _quality;

  final List<double> _rasterMs = <double>[];
  Duration? _overSince, _underSince;
  bool _steppedUp = false;
  bool _listening = false;
  double _lastP90 = 0;

  /// Latest 90th-percentile raster time in milliseconds.
  double get p90 => _lastP90;
  double get budgetMs => 1000 / math.max(refreshRate, 1);

  void start() {
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_listening) return;
    _listening = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final t in timings) {
      addSample(
        t.rasterDuration.inMicroseconds / 1000,
        Duration(
          microseconds: t.timestampInMicroseconds(ui.FramePhase.rasterFinish),
        ),
      );
    }
  }

  /// Feeds one raster time; exposed for tests.
  void addSample(double rasterMs, Duration at) {
    _rasterMs.add(rasterMs);
    while (_rasterMs.length > 120) {
      _rasterMs.removeAt(0);
    }
    if (_rasterMs.length < 20) return;
    final sorted = [..._rasterMs]..sort();
    _lastP90 =
        sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)];
    final budget = budgetMs;
    if (_lastP90 > 0.75 * budget) {
      _underSince = null;
      _overSince ??= at;
      if (at - _overSince! >= const Duration(seconds: 2)) _step(-1);
    } else if (_lastP90 < 0.40 * budget) {
      _overSince = null;
      _underSince ??= at;
      if (!_steppedUp && at - _underSince! >= const Duration(seconds: 10)) {
        _steppedUp = _step(1) || _steppedUp;
      }
    } else {
      _overSince = null;
      _underSince = null;
    }
  }

  bool _step(int direction) {
    final next = (_quality.index - direction).clamp(
      0,
      GlassQuality.values.length - 1,
    );
    _overSince = null;
    _underSince = null;
    if (next == _quality.index) return false;
    _quality = GlassQuality.values[next];
    _rasterMs.clear();
    notifyListeners();
    return true;
  }
}

/// Light/dark decision for foreground on glass, with hysteresis
/// (docs/glass-model.md §2.4): dark content above 0.62, light below 0.45.
bool glassWantsDarkGlass({required double luminance, required bool current}) {
  if (luminance > 0.62) return false; // bright backdrop: light glass, dark ink
  if (luminance < 0.45) return true; // dark backdrop: dark glass, light ink
  return current;
}

/// Measures the average luminance of a [RenderRepaintBoundary] under a rect by
/// rasterising it at a tiny scale. Costs one small GPU readback per call, so
/// call it on change or on a slow timer, never every frame.
Future<double?> sampleBackdropLuminance(
  RenderRepaintBoundary boundary,
  Rect localRect, {
  double pixelRatio = 0.08,
}) async {
  if (!boundary.attached || localRect.isEmpty) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final w = image.width, h = image.height;
    final r = Rect.fromLTRB(
      (localRect.left * pixelRatio).floorToDouble().clamp(0, w - 1),
      (localRect.top * pixelRatio).floorToDouble().clamp(0, h - 1),
      (localRect.right * pixelRatio).ceilToDouble().clamp(1, w.toDouble()),
      (localRect.bottom * pixelRatio).ceilToDouble().clamp(1, h.toDouble()),
    );
    var sum = 0.0;
    var n = 0;
    for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
      for (var x = r.left.toInt(); x < r.right.toInt(); x++) {
        final i = (y * w + x) * 4;
        double lin(int v) => v / 255.0;
        sum +=
            0.213 * lin(data.getUint8(i)) +
            0.715 * lin(data.getUint8(i + 1)) +
            0.072 * lin(data.getUint8(i + 2));
        n++;
      }
    }
    return n == 0 ? null : sum / n;
  } finally {
    image.dispose();
  }
}

/// Runs [action] at most every [interval] while [active]; used for the probe.
class Throttle {
  Throttle(this.interval);
  final Duration interval;
  Timer? _timer;
  bool _pending = false;

  void call(void Function() action) {
    if (_timer != null) {
      _pending = true;
      return;
    }
    action();
    _timer = Timer(interval, () {
      _timer = null;
      if (_pending) {
        _pending = false;
        call(action);
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = false;
  }
}
