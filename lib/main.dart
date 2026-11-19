import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'glass_adaptivity.dart';
import 'refractive_glass.dart';

void main() => runApp(const GlassDemo());

enum QualityChoice { auto, high, medium, low }

class GlassDemo extends StatefulWidget {
  const GlassDemo({super.key, this.enableProbe = true});

  /// Samples the backdrop luminance to flip the glass tone (§2.4).
  /// Widget tests turn it off: it uses GPU readback and timers.
  final bool enableProbe;

  @override
  State<GlassDemo> createState() => _GlassDemoState();
}

class _GlassDemoState extends State<GlassDemo> with TickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  late final AnimationController merge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final CurvedAnimation mergeCurve = CurvedAnimation(
    parent: merge,
    curve: Curves.easeInOutCubic,
  );
  final GlassPerformanceGovernor governor = GlassPerformanceGovernor();
  final GlobalKey backgroundKey = GlobalKey();
  final Throttle probeThrottle = Throttle(const Duration(milliseconds: 300));

  bool dark = false, moving = false, opaque = false, frostOnly = false;
  bool debug = false, lensOutward = true, adaptive = true;
  bool glassDark = false; // adaptive tone result
  Offset drag = Offset.zero;
  GlassRenderMode mode = GlassRenderMode.loading;
  QualityChoice qualityChoice = QualityChoice.auto;
  int presses = 0;
  int selectedTab = 0;
  double strength = 1;
  Rect probeRect = Rect.zero;
  double? lastLuminance;

  GlassQuality get quality => switch (qualityChoice) {
    QualityChoice.auto => governor.quality,
    QualityChoice.high => GlassQuality.high,
    QualityChoice.medium => GlassQuality.medium,
    QualityChoice.low => GlassQuality.low,
  };

  bool get effectiveGlassDark => adaptive ? glassDark : dark;

  @override
  void initState() {
    super.initState();
    glassDark = dark;
    governor.addListener(_onGovernor);
    governor.start();
    motion.addListener(_scheduleProbe);
    merge.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final displays = WidgetsBinding.instance.platformDispatcher.displays;
      if (displays.isNotEmpty)
        governor.refreshRate = displays.first.refreshRate;
      _scheduleProbe();
    });
  }

  void _onGovernor() {
    if (mounted && qualityChoice == QualityChoice.auto) setState(() {});
  }

  void _scheduleProbe() {
    if (!widget.enableProbe || !adaptive) return;
    probeThrottle(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
    });
  }

  Future<void> _probe() async {
    final boundary =
        backgroundKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || probeRect.isEmpty) return;
    try {
      final y = await sampleBackdropLuminance(boundary, probeRect);
      if (!mounted || y == null) return;
      final next = glassWantsDarkGlass(luminance: y, current: glassDark);
      setState(() {
        lastLuminance = y;
        glassDark = next;
      });
    } catch (_) {
      // Readback can fail while the boundary is being rebuilt; try next time.
    }
  }

  @override
  void dispose() {
    probeThrottle.cancel();
    governor.removeListener(_onGovernor);
    governor.dispose();
    mergeCurve.dispose();
    merge.dispose();
    motion.dispose();
    super.dispose();
  }

  String get statusLine {
    final renderer = ui.ImageFilter.isShaderFilterSupported
        ? 'Impeller'
        : 'no shader filter';
    final q = qualityChoice == QualityChoice.auto
        ? 'auto:${quality.name}'
        : quality.name;
    final y = lastLuminance == null
        ? ''
        : ' • Y ${lastLuminance!.toStringAsFixed(2)}';
    return 'Renderer: $renderer • ${mode.name} • $q$y';
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: Colors.teal,
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('Live glass • Flutter')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'Drag the glass; animate the background.\n$statusLine',
              key: const Key('mode'),
              textAlign: TextAlign.center,
            ),
          ),
          Text('Add presses: $presses', key: const Key('presses')),
          Expanded(child: LayoutBuilder(builder: _buildStage)),
          _controls(),
          const SafeArea(top: false, child: SizedBox(height: 4)),
        ],
      ),
    ),
  );

  Widget _buildStage(BuildContext context, BoxConstraints bounds) {
    const height = 64.0, bubble = 64.0, gap = 14.0;
    final group = math.min(360.0, bounds.maxWidth - 24);
    final barWidth = group - bubble - gap;
    final x = ((bounds.maxWidth - group) / 2 + drag.dx)
        .clamp(8.0, math.max(8.0, bounds.maxWidth - group - 8))
        .toDouble();
    final y = ((bounds.maxHeight - height) / 2 + drag.dy)
        .clamp(8.0, math.max(8.0, bounds.maxHeight - height - 8))
        .toDouble();
    final m = mergeCurve.value;
    // Merging stretches the bar until it swallows the bubble.
    final bar = Rect.fromLTWH(x, y, barWidth + m * (gap + bubble), height);
    final tabs = Rect.fromLTWH(x, y, barWidth, height);
    final plus = Rect.fromLTWH(x + barWidth + gap, y, bubble, bubble);
    probeRect = bar.expandToInclude(plus);
    final tone = effectiveGlassDark;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: backgroundKey,
              child: AnimatedBuilder(
                animation: motion,
                builder: (_, _) => CustomPaint(
                  painter: GridScene(phase: motion.value, dark: dark),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: LiquidGlass(
              shapes: [
                GlassShape(bar, radius: height / 2),
                GlassShape(plus, radius: bubble / 2),
              ],
              mergeSpacing: 20,
              strength: strength,
              dark: tone,
              quality: quality,
              adaptive: adaptive,
              lensOutward: lensOutward,
              debug: debug,
              forceFrostFallback: frostOnly,
              reduceTransparency: opaque,
              onModeChanged: (value) {
                if (mounted && mode != value) setState(() => mode = value);
              },
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: tabs,
                    child: GestureDetector(
                      key: const Key('glass-drag'),
                      onPanUpdate: (event) {
                        setState(() => drag += event.delta);
                        _scheduleProbe();
                      },
                      child: FloatingNavigation(
                        dark: tone,
                        selected: selectedTab,
                        onSelect: (tab) => setState(() => selectedTab = tab),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: plus,
                    child: Center(
                      child: AddButton(onAdd: () => setState(() => presses++)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Text('Refraction'),
            Expanded(
              child: Slider(
                key: const Key('strength'),
                min: 0,
                max: 1.5,
                divisions: 15,
                value: strength,
                label: strength.toStringAsFixed(1),
                onChanged: (value) => setState(() => strength = value),
              ),
            ),
            Text(strength.toStringAsFixed(1)),
          ],
        ),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: -8,
        children: [
          _button('morph', merge.value > .5 ? 'Separate' : 'Merge', () {
            if (merge.value > .5) {
              merge.reverse();
            } else {
              merge.forward();
            }
          }),
          _button('frost', frostOnly ? 'Use refraction' : 'Blur only', () {
            setState(() => frostOnly = !frostOnly);
          }),
          _button('theme', dark ? 'Light' : 'Dark', () {
            setState(() {
              dark = !dark;
              glassDark = dark;
            });
            _scheduleProbe();
          }),
          _button('motion', moving ? 'Pause bg' : 'Animate bg', () {
            setState(() {
              moving = !moving;
              if (moving) {
                motion.repeat(reverse: true);
              } else {
                motion.stop();
              }
            });
          }),
          _button('opaque', opaque ? 'Glass' : 'Opaque', () {
            setState(() => opaque = !opaque);
          }),
          _button('quality', 'Quality: ${qualityChoice.name}', () {
            setState(() {
              qualityChoice =
                  QualityChoice.values[(qualityChoice.index + 1) %
                      QualityChoice.values.length];
            });
          }),
          _button('adaptive', adaptive ? 'Adaptive on' : 'Adaptive off', () {
            setState(() {
              adaptive = !adaptive;
              glassDark = dark;
            });
            _scheduleProbe();
          }),
          _button('lens', lensOutward ? 'Lens: out' : 'Lens: in', () {
            setState(() => lensOutward = !lensOutward);
          }),
          _button('debug', debug ? 'Debug off' : 'Debug', () {
            setState(() => debug = !debug);
          }),
        ],
      ),
    ],
  );

  Widget _button(String key, String label, VoidCallback onPressed) =>
      TextButton(key: Key(key), onPressed: onPressed, child: Text(label));
}

class FloatingNavigation extends StatelessWidget {
  const FloatingNavigation({
    super.key,
    required this.dark,
    required this.selected,
    required this.onSelect,
  });
  final bool dark;
  final int selected;
  final ValueChanged<int> onSelect;

  Widget destination(int index, IconData icon, String label) {
    final active = selected == index;
    final control = Semantics(
      selected: active,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: active
              ? (dark ? const Color(0x3329424B) : const Color(0x66FFFFFF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            key: Key('tab-$index'),
            borderRadius: BorderRadius.circular(26),
            onTap: () => onSelect(index),
            child: SizedBox(
              height: 52,
              child: active
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Icon(icon, size: 24),
            ),
          ),
        ),
      ),
    );
    return active
        ? Expanded(child: control)
        : SizedBox(width: 44, child: control);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(
      children: [
        destination(0, Icons.home_outlined, 'Home'),
        destination(1, Icons.search, 'Search'),
        destination(2, Icons.favorite_border, 'Saved'),
        destination(3, Icons.person_outline, 'Profile'),
      ],
    ),
  );
}

/// Flat multitone circular action, sitting inside its own glass bubble.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: Tooltip(
      message: 'Add',
      child: Semantics(
        button: true,
        label: 'Add',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xCCC4DDD0),
                  Color(0xCC99CFB6),
                  Color(0xCCBBDFD1),
                ],
              ),
            ),
            child: InkWell(
              key: const Key('plus'),
              onTap: onAdd,
              customBorder: const CircleBorder(),
              child: const Icon(Icons.add, size: 30, color: Color(0xFF123D30)),
            ),
          ),
        ),
      ),
    ),
  );
}

class GridScene extends CustomPainter {
  const GridScene({required this.phase, required this.dark});
  final double phase;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF0B2029) : const Color(0xFFE9F0EF),
    );
    canvas.save();
    canvas.translate(-phase * 160, 0);
    final grid = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: .32)
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width + 180; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width + 180, y), grid);
    }
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(60 + i * 105.0, size.height * .48),
        42,
        Paint()
          ..color = [
            Colors.teal,
            Colors.amber,
            Colors.blue,
            Colors.pink,
            Colors.green,
          ][i].withValues(alpha: .75),
      );
    }
    // A strip of text so the adaptive shadow has something "busy" to react to.
    final text = TextPainter(
      text: TextSpan(
        text: 'Liquid glass bends light at the edge. ' * 3,
        style: TextStyle(
          color: dark ? Colors.white70 : Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width + 160);
    text.paint(canvas, Offset(8, size.height * .48 + 60));
    text.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(GridScene old) => phase != old.phase || dark != old.dark;
}
