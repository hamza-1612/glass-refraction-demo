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
  double strength = 7;

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
      appBar: AppBar(title: const Text('Live glass • Flutter')),
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
                final width = math.min(340.0, bounds.maxWidth - 32);
                const height = 80.0;
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
                            painter: GridScene(phase: motion.value, dark: dark),
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
                          onPanUpdate: (event) =>
                              setState(() => drag += event.delta),
                          child: RefractiveGlass(
                            dark: dark,
                            radius: 40,
                            strength: strength,
                            forceFrostFallback: frostOnly,
                            reduceTransparency: opaque,
                            onModeChanged: (value) {
                              if (mounted && mode != value)
                                setState(() => mode = value);
                            },
                            child: FloatingNavigation(
                              dark: dark,
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
                min: 0, max: 14, divisions: 14, value: strength,
                label: strength.toStringAsFixed(0),
                onChanged: (value) => setState(() => strength = value),
              )),
              Text(strength.toStringAsFixed(0)),
            ]),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(GridScene old) => phase != old.phase || dark != old.dark;
}
