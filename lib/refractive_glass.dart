import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Which path actually renders the glass.
enum GlassRenderMode { loading, refractive, frostedFallback, opaque }

/// Visual quality tiers (docs/glass-model.md, section 5).
///
/// [high] and [medium] use the refraction shader. [low] skips the shader and
/// uses the engine blur only, which is the cheapest translucent option.
enum GlassQuality { high, medium, low }

/// One glass shape, in the local coordinates of its [LiquidGlass] widget.
@immutable
class GlassShape {
  const GlassShape(this.rect, {required this.radius});
  final Rect rect;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is GlassShape && other.rect == rect && other.radius == radius;

  @override
  int get hashCode => Object.hash(rect, radius);
}

/// Optical parameters derived from the glass size (docs/glass-model.md §1.2).
///
/// Larger glass behaves like thicker material: a wider lens band and a
/// stronger bend. All values are logical pixels.
@immutable
class GlassOptics {
  const GlassOptics({
    required this.band,
    required this.amount,
    required this.blurSigma,
    this.vibrancy = 1.3,
  });

  factory GlassOptics.forSize(double minSide, {double strength = 1}) {
    final m = math.max(minSide, 1.0);
    final amount = (strength.clamp(0.0, 1.5) * (0.30 * m).clamp(6.0, 28.0))
        .clamp(0.0, 0.5 * m)
        .toDouble();
    return GlassOptics(
      band: (0.30 * m).clamp(12.0, 32.0).toDouble(),
      amount: amount,
      blurSigma: (0.04 * m).clamp(2.0, 6.0).toDouble(),
    );
  }

  final double band, amount, blurSigma, vibrancy;
}

/// Live liquid glass over whatever is painted behind this widget.
///
/// [shapes] (one or two) are positioned in this widget's local coordinates;
/// two shapes closer than [mergeSpacing] melt into one (smooth-min).
/// [child] is the foreground, painted on top and never distorted.
///
/// Requires Impeller for refraction. Without it, or at [GlassQuality.low],
/// each shape becomes an engine-blurred frost panel.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.shapes,
    required this.child,
    this.mergeSpacing = 20,
    this.strength = 1,
    this.dark = false,
    this.quality = GlassQuality.medium,
    this.adaptive = true,
    this.lensOutward = true,
    this.debug = false,
    this.reduceTransparency = false,
    this.forceFrostFallback = false,
    this.onModeChanged,
    this.onShaderError,
  }) : assert(mergeSpacing >= 0),
       assert(strength >= 0);

  final List<GlassShape> shapes;
  final Widget child;
  final double mergeSpacing, strength;
  final bool dark, adaptive, lensOutward, debug;
  final bool reduceTransparency, forceFrostFallback;
  final GlassQuality quality;
  final ValueChanged<GlassRenderMode>? onModeChanged;
  final void Function(Object, StackTrace)? onShaderError;

  static const Color lightTint = Color(0xFFF7FBFC);
  static const Color darkTint = Color(0xFF172D36);

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  static Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _shader;
  bool _loading = false;
  bool _failed = false;
  GlassRenderMode? _lastMode;

  bool get _wantsShader =>
      !widget.forceFrostFallback &&
      !widget.reduceTransparency &&
      widget.quality != GlassQuality.low &&
      ui.ImageFilter.isShaderFilterSupported;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LiquidGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    if (!_wantsShader || _loading || _shader != null || _failed) return;
    _loading = true;
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset(
        'shaders/glass_refraction.frag',
      ));
      if (!mounted) return;
      setState(() {
        _shader = program.fragmentShader(); // One mutable shader per surface.
        _loading = false;
      });
    } catch (error, stack) {
      _program = null; // Permit later instances to retry after an asset fix.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      widget.onShaderError?.call(error, stack);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'glass_refraction_demo',
          context: ErrorDescription(
            'loading glass shader; using frost fallback',
          ),
        ),
      );
    }
  }

  void _report(GlassRenderMode mode) {
    if (_lastMode == mode) return;
    _lastMode = mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lastMode == mode) widget.onModeChanged?.call(mode);
    });
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shapes.isEmpty || widget.shapes.length > 2) {
      throw FlutterError('LiquidGlass supports one or two shapes.');
    }
    final opaque =
        widget.reduceTransparency || MediaQuery.highContrastOf(context);
    final canRefract = _wantsShader && _shader != null;
    final mode = opaque
        ? GlassRenderMode.opaque
        : canRefract
        ? GlassRenderMode.refractive
        : _wantsShader && _loading && !_failed
        ? GlassRenderMode.loading
        : GlassRenderMode.frostedFallback;
    _report(mode);

    final dark = widget.dark;
    final foreground = DefaultTextStyle.merge(
      style: TextStyle(color: dark ? Colors.white : const Color(0xFF102D35)),
      child: IconTheme.merge(
        data: IconThemeData(
          color: dark ? Colors.white : const Color(0xFF102D35),
        ),
        child: widget.child,
      ),
    );

    final shadows = <Widget>[
      for (final shape in widget.shapes)
        Positioned.fromRect(
          rect: shape.rect,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(shape.radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? .22 : .10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];

    if (mode == GlassRenderMode.refractive) {
      final shortest = widget.shapes
          .map((s) => s.rect.shortestSide)
          .reduce(math.max);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          ...shadows,
          Positioned.fill(
            child: _GlassShaderSurface(
              shader: _shader!,
              shapes: widget.shapes,
              optics: GlassOptics.forSize(shortest, strength: widget.strength),
              mergeSpacing: widget.mergeSpacing,
              dark: dark,
              quality: widget.quality,
              adaptive: widget.adaptive,
              lensOutward: widget.lensOutward,
              debug: widget.debug,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              surfaceSize: View.of(context).physicalSize,
              child: foreground,
            ),
          ),
        ],
      );
    }

    // Frost and opaque fallbacks: one panel per shape, no merging.
    final tint = dark ? LiquidGlass.darkTint : LiquidGlass.lightTint;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ...shadows,
        for (final shape in widget.shapes)
          Positioned.fromRect(
            rect: shape.rect,
            child: _FallbackPanel(
              radius: shape.radius,
              tint: tint,
              dark: dark,
              opaque: opaque,
            ),
          ),
        Positioned.fill(child: foreground),
      ],
    );
  }
}

class _FallbackPanel extends StatelessWidget {
  const _FallbackPanel({
    required this.radius,
    required this.tint,
    required this.dark,
    required this.opaque,
  });
  final double radius;
  final Color tint;
  final bool dark, opaque;

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(
          alpha: opaque
              ? 1
              : dark
              ? .34
              : .26,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? .22 : .60),
          width: .8,
        ),
      ),
      child: const SizedBox.expand(),
    );
    if (opaque) return panel;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: panel,
      ),
    );
  }
}

/// Wraps a single child in one glass shape that fills the available box.
///
/// Kept for simple uses: `SizedBox(height: 80, child: RefractiveGlass(...))`.
class RefractiveGlass extends StatelessWidget {
  const RefractiveGlass({
    super.key,
    required this.child,
    this.radius = 28,
    this.strength = 1,
    this.dark = false,
    this.quality = GlassQuality.medium,
    this.debug = false,
    this.reduceTransparency = false,
    this.forceFrostFallback = false,
    this.onModeChanged,
    this.onShaderError,
  }) : assert(radius >= 0),
       assert(strength >= 0);

  final Widget child;
  final double radius, strength;
  final bool dark, debug, reduceTransparency, forceFrostFallback;
  final GlassQuality quality;
  final ValueChanged<GlassRenderMode>? onModeChanged;
  final void Function(Object, StackTrace)? onShaderError;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
        throw FlutterError(
          'RefractiveGlass needs finite width and height; wrap it in SizedBox or Positioned.',
        );
      }
      final size = constraints.biggest;
      if (size.shortestSide <= 0) return const SizedBox.shrink();
      return LiquidGlass(
        shapes: [
          GlassShape(
            Offset.zero & size,
            radius: radius.clamp(0.0, size.shortestSide / 2).toDouble(),
          ),
        ],
        strength: strength,
        dark: dark,
        quality: quality,
        debug: debug,
        reduceTransparency: reduceTransparency,
        forceFrostFallback: forceFrostFallback,
        onModeChanged: onModeChanged,
        onShaderError: onShaderError,
        child: child,
      );
    },
  );
}

class _GlassShaderSurface extends SingleChildRenderObjectWidget {
  const _GlassShaderSurface({
    required this.shader,
    required this.shapes,
    required this.optics,
    required this.mergeSpacing,
    required this.dark,
    required this.quality,
    required this.adaptive,
    required this.lensOutward,
    required this.debug,
    required this.devicePixelRatio,
    required this.surfaceSize,
    super.child,
  });

  final ui.FragmentShader shader;
  final List<GlassShape> shapes;
  final GlassOptics optics;
  final double mergeSpacing, devicePixelRatio;
  final bool dark, adaptive, lensOutward, debug;
  final GlassQuality quality;
  final Size surfaceSize;

  @override
  RenderGlassShaderSurface createRenderObject(BuildContext context) =>
      RenderGlassShaderSurface(shader: shader).._update(this);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassShaderSurface renderObject,
  ) => renderObject._update(this);
}

/// Computes the glass geometry at paint time, in the backdrop texture's
/// physical-pixel frame, and feeds it to the shader (docs/glass-model.md).
class RenderGlassShaderSurface extends RenderProxyBox {
  RenderGlassShaderSurface({required ui.FragmentShader shader})
    : _shader = shader;

  ui.FragmentShader _shader;
  List<GlassShape> _shapes = const [];
  GlassOptics _optics = GlassOptics.forSize(80);
  double _merge = 20, _dpr = 1;
  bool _dark = false, _adaptive = true, _outward = true, _debug = false;
  GlassQuality _quality = GlassQuality.medium;
  Size _surface = Size.zero;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();
  final LayerHandle<BackdropFilterLayer> _filterLayer =
      LayerHandle<BackdropFilterLayer>();

  void _update(_GlassShaderSurface w) {
    _shader = w.shader;
    _shapes = w.shapes;
    _optics = w.optics;
    _merge = w.mergeSpacing;
    _dark = w.dark;
    _quality = w.quality;
    _adaptive = w.adaptive;
    _outward = w.lensOutward;
    _debug = w.debug;
    _dpr = w.devicePixelRatio;
    _surface = w.surfaceSize;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void dispose() {
    _clipLayer.layer = null;
    _filterLayer.layer = null;
    super.dispose();
  }

  /// Local rect of everything the filter must cover, with room for the
  /// outward samples and the blur disk.
  Rect get _localClip {
    var union = _shapes.first.rect;
    for (final s in _shapes.skip(1)) {
      union = union.expandToInclude(s.rect);
    }
    final reach = _optics.amount + 2 * _optics.blurSigma + 4;
    return union.inflate(reach).intersect(Offset.zero & size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final clip = _localClip;
    if (clip.isEmpty) {
      super.paint(context, offset);
      return;
    }
    _writeUniforms(clip);
    final filterLayer = _filterLayer.layer ??= BackdropFilterLayer();
    filterLayer.filter = ui.ImageFilter.shader(
      _shader,
      filterQuality: FilterQuality.low, // bilinear; default is nearest
    );
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      clip,
      (ctx, o) => ctx.pushLayer(filterLayer, super.paint, o),
      oldLayer: _clipLayer.layer,
    );
  }

  Rect _toPhysical(Matrix4 toGlobal, Rect local) {
    final r = MatrixUtils.transformRect(toGlobal, local);
    return Rect.fromLTRB(
      r.left * _dpr,
      r.top * _dpr,
      r.right * _dpr,
      r.bottom * _dpr,
    );
  }

  void _writeUniforms(Rect localClip) {
    final toGlobal = getTransformTo(null);
    final a = _toPhysical(toGlobal, _shapes[0].rect);
    final b = _shapes.length > 1
        ? _toPhysical(toGlobal, _shapes[1].rect)
        : Rect.zero;
    final c = _toPhysical(toGlobal, localClip);
    // The engine rounds clip bounds out to whole pixels.
    final clip = Rect.fromLTRB(
      c.left.floorToDouble(),
      c.top.floorToDouble(),
      c.right.ceilToDouble(),
      c.bottom.ceilToDouble(),
    );
    final scale = MatrixUtils.getAsScale(toGlobal) ?? 1.0;
    final px = _dpr * scale;
    final tint = _dark ? LiquidGlass.darkTint : LiquidGlass.lightTint;
    final taps = _quality == GlassQuality.high ? 20.0 : 12.0;
    final values = <double>[
      // uRectA
      a.left, a.top, a.width, a.height,
      // uRectB
      b.left, b.top, b.width, b.height,
      // uShape: radii, merge k, rim width
      _shapes[0].radius * px,
      _shapes.length > 1 ? _shapes[1].radius * px : 0,
      _merge * px,
      1.5 * px,
      // uOptics: band, amount, blur disk radius (1.25 sigma), vibrancy
      _optics.band * px,
      _optics.amount * px,
      1.25 * _optics.blurSigma * px,
      _optics.vibrancy,
      // uClip
      clip.left, clip.top, clip.width, clip.height,
      // uSurface: size, dpr, debug
      _surface.width, _surface.height, px, _debug ? 1 : 0,
      // uTint: rgb, tone
      tint.r, tint.g, tint.b, _dark ? 1 : 0,
      // uLight: direction (top-left), key, fill
      -1, -1, _dark ? 0.45 : 0.7, _dark ? 0.2 : 0.3,
      // uMisc: dispersion, adaptive, taps, lens sign
      _quality == GlassQuality.high ? 1 : 0,
      _adaptive ? 1 : 0,
      taps,
      _outward ? 1 : -1,
    ];
    for (var i = 0; i < values.length; i++) {
      _shader.setFloat(2 + i, values[i]); // 0-1 are the engine's uSize
    }
  }
}
