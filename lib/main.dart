import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'refractive_glass.dart';

void main() => runApp(const GlassDemo());

class GlassDemo extends StatefulWidget {
  const GlassDemo({super.key});
  @override
  State<GlassDemo> createState() => _GlassDemoState();
}

class _GlassDemoState extends State<GlassDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion;
  bool dark = false, moving = false, opaque = false;
  Offset drag = Offset.zero;
  GlassRenderMode mode = GlassRenderMode.loading;
  int presses = 0;
  int selectedTab = 0;
  bool frostOnly = false;
  bool lensOnly = false;
  int scene = 2;
  double strength = 14;
  double dispersion = 1.5;

  @override
  void initState() {
    super.initState();
    motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: Colors.teal,
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('Live glass • v0.2')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Drag the glass; animate the background.\nRenderer: ${ui.ImageFilter.isShaderFilterSupported ? "Impeller" : "no shader filter"} • ${mode.name}',
              key: const Key('mode'),
              textAlign: TextAlign.center,
            ),
          ),
          Text('Add presses: $presses', key: const Key('presses')),
          Expanded(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final width = math.min(lensOnly ? 210.0 : 340.0, bounds.maxWidth - 32);
                final height = lensOnly ? 120.0 : 80.0;
                final x = ((bounds.maxWidth - width) / 2 + drag.dx)
                    .clamp(8.0, math.max(8.0, bounds.maxWidth - width - 8))
                    .toDouble();
                final y = ((bounds.maxHeight - height) / 2 + drag.dy)
                    .clamp(8.0, math.max(8.0, bounds.maxHeight - height - 8))
                    .toDouble();
                return ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: motion,
                          builder: (_, _) => CustomPaint(
                            painter: GridScene(phase: motion.value, dark: dark, scene: scene),
                          ),
                        ),
                      ),
                      Positioned(
                        left: x,
                        top: y,
                        width: width,
                        height: height,
                        child: GestureDetector(
                          key: const Key('glass-drag'),
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (event) =>
                              setState(() => drag += event.delta),
                          child: RefractiveGlass(
                            dark: dark || scene == 2,
                            radius: height / 2,
                            strength: strength,
                            edgeBand: height * .4,
                            dispersion: dispersion,
                            tintOpacity: lensOnly ? .025 : .06,
                            forceFrostFallback: frostOnly,
                            reduceTransparency: opaque,
                            onModeChanged: (value) {
                              if (mounted && mode != value)
                                setState(() => mode = value);
                            },
                            child: lensOnly ? const SizedBox.expand() : FloatingNavigation(
                              dark: dark || scene == 2,
                              selected: selectedTab,
                              onSelect: (tab) => setState(() => selectedTab = tab),
                              onAdd: () => setState(() => presses++),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('Refraction'),
              Expanded(child: Slider(
                key: const Key('strength'),
                min: 0, max: 22, divisions: 22, value: strength,
                label: strength.toStringAsFixed(0),
                onChanged: (value) => setState(() => strength = value),
              )),
              Text(strength.toStringAsFixed(0)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('Edge colors'),
              Expanded(child: Slider(
                key: const Key('dispersion'),
                min: 0, max: 3, divisions: 12, value: dispersion,
                label: dispersion.toStringAsFixed(2),
                onChanged: (value) => setState(() => dispersion = value),
              )),
              Text(dispersion.toStringAsFixed(1)),
            ]),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                key: const Key('scene'),
                onPressed: () => setState(() => scene = (scene + 1) % 4),
                child: Text('Scene: ${['Grid', 'Lines', 'Text', 'Dots'][scene]}'),
              ),
              TextButton(
                key: const Key('lens'),
                onPressed: () => setState(() { lensOnly = !lensOnly; drag = Offset.zero; }),
                child: Text(lensOnly ? 'Show navigation' : 'Clear lens'),
              ),
              TextButton(
                key: const Key('frost'),
                onPressed: () => setState(() => frostOnly = !frostOnly),
                child: Text(frostOnly ? 'Use refraction' : 'Compare blur only'),
              ),
              TextButton(
                key: const Key('theme'),
                onPressed: () => setState(() => dark = !dark),
                child: Text(dark ? 'Light' : 'Dark'),
              ),
              TextButton(
                key: const Key('motion'),
                onPressed: () => setState(() {
                  moving = !moving;
                  if (moving) {
                    motion.repeat(reverse: true);
                  } else {
                    motion.stop();
                  }
                }),
                child: Text(moving ? 'Pause background' : 'Animate background'),
              ),
              TextButton(
                key: const Key('opaque'),
                onPressed: () => setState(() => opaque = !opaque),
                child: Text(opaque ? 'Glass' : 'Opaque fallback'),
              ),
            ],
          ),
          const SafeArea(top: false, child: SizedBox(height: 8)),
        ],
      ),
    ),
  );
}

class FloatingNavigation extends StatelessWidget {
  const FloatingNavigation({super.key, required this.dark,
    required this.selected, required this.onSelect, required this.onAdd});
  final bool dark;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  Widget destination(int index, IconData icon, String label) {
    final active = selected == index;
    final control = Semantics(
        selected: active, button: true, label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: active
                ? (dark ? const Color(0xFF29424B) : const Color(0xFFF7FAFB))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              key: Key('tab-$index'),
              borderRadius: BorderRadius.circular(28),
              onTap: () => onSelect(index),
              child: SizedBox(height: 56, child: active
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 3),
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                  ])
                : Icon(icon, size: 24)),
            ),
          ),
        ),
    );
    return active ? Expanded(child: control) : SizedBox(width: 48, child: control);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(children: [
      Expanded(child: Row(children: [
        destination(0, Icons.home_outlined, 'Home'),
        destination(1, Icons.search, 'Search'),
      ])),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(width: 56, height: 56,
          child: Tooltip(message: 'Add', child: Semantics(button: true, label: 'Add',
            child: Material(color: Colors.transparent, shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: const BoxDecoration(shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                    colors: [Color(0xFFC4DDD0), Color(0xFF99CFB6), Color(0xFFBBDFD1)],
                  )),
                child: InkWell(key: const Key('plus'), onTap: onAdd,
                  customBorder: const CircleBorder(),
                  child: const Icon(Icons.add, size: 30, color: Color(0xFF123D30))),
              ),
            ),
          )),
        ),
      ),
      Expanded(child: Row(children: [
        destination(2, Icons.favorite_border, 'Saved'),
        destination(3, Icons.person_outline, 'Profile'),
      ])),
    ]),
  );
}

class GridScene extends CustomPainter {
  const GridScene({required this.phase, required this.dark, this.scene = 0});
  final double phase;
  final bool dark;
  final int scene;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = scene == 2 ? (dark ? const Color(0xFF08090C) : const Color(0xFF3434D9))
          : dark ? const Color(0xFF0B1015) : const Color(0xFFF1F2F6),
    );
    canvas.save();
    canvas.translate(-phase * 80, -phase * 40);
    if (scene != 0) {
      final ink = Paint()..color = scene == 2 || dark ? Colors.white : const Color(0xFF14151A);
      if (scene == 1) {
        for (double x = -80; x < size.width + 160; x += 36) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 16, size.height + 80), ink);
        }
        // Horizontal bars make vertical displacement independently visible.
        final cross = Paint()..color = const Color(0xFFEF8354);
        for (double y = 35; y < size.height + 80; y += 80) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width + 160, 6), cross);
        }
      } else if (scene == 3) {
        for (double y = 30; y < size.height + 80; y += 58) {
          for (double x = 30; x < size.width + 160; x += 58) {
            canvas.drawCircle(Offset(x, y), 18, ink);
          }
        }
      } else {
        for (double y = 20; y < size.height + 100; y += 68) {
          final text = TextPainter(
            text: const TextSpan(text: 'Glass in motion  Aa',
              style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w500)),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, Offset(14, y));
          text.dispose();
        }
      }
      canvas.restore();
      return;
    }
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(GridScene old) => phase != old.phase || dark != old.dark || scene != old.scene;
}
