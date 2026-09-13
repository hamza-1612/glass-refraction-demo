import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum GlassRenderMode { loading, refractive, frostedFallback, opaque }

/// Wrap only the desired surface. Its backdrop must already be painted behind it.
/// Requires Impeller for refraction. Other backends show explicit frost fallback.
/// Use finite layout bounds; axis-aligned surfaces only until device verification.
class RefractiveGlass extends StatefulWidget {
  const RefractiveGlass({
    super.key,
    required this.child,
    this.radius = 28,
    this.strength = 14,
    this.edgeBand = 32,
    this.frost = 0.25,
    this.dispersion = 0.35,
    this.tintOpacity = 0.06,
    this.dark = false,
    this.reduceTransparency = false,
    this.forceFrostFallback = false,
    this.onModeChanged,
    this.onShaderError,
  }) : assert(radius >= 0),
       assert(strength >= 0),
       assert(edgeBand > 0),
       assert(frost >= 0),
       assert(dispersion >= 0),
       assert(tintOpacity >= 0 && tintOpacity <= 1);

  final Widget child;
  final double radius, strength, edgeBand, frost, dispersion, tintOpacity;
  final bool dark, reduceTransparency, forceFrostFallback;
  final ValueChanged<GlassRenderMode>? onModeChanged;
  final void Function(Object, StackTrace)? onShaderError;

  @override
  State<RefractiveGlass> createState() => _RefractiveGlassState();
}

class _RefractiveGlassState extends State<RefractiveGlass> {
  static Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _shader;
  bool _loading = false;
  bool _failed = false;
  GlassRenderMode? _lastMode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RefractiveGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.forceFrostFallback && !widget.forceFrostFallback) ||
        (oldWidget.reduceTransparency && !widget.reduceTransparency)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.forceFrostFallback ||
        widget.reduceTransparency ||
        !ui.ImageFilter.isShaderFilterSupported ||
        _loading ||
        _shader != null) {
      return;
    }
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
        throw FlutterError(
          'RefractiveGlass needs finite width and height; wrap it in SizedBox or Positioned.',
        );
      }
      final shortest = constraints.biggest.shortestSide;
      if (shortest <= 0) return const SizedBox.shrink();
      final radius = widget.radius.clamp(0.0, shortest / 2).toDouble();
      final opaque =
          widget.reduceTransparency || MediaQuery.highContrastOf(context);
      final canRefract =
          !widget.forceFrostFallback &&
          _shader != null &&
          ui.ImageFilter.isShaderFilterSupported;
      final mode = opaque
          ? GlassRenderMode.opaque
          : canRefract
          ? GlassRenderMode.refractive
          : _loading && !_failed && !widget.forceFrostFallback
          ? GlassRenderMode.loading
          : GlassRenderMode.frostedFallback;
      _report(mode);
      final tint = widget.dark
          ? const Color(0xFF172D36)
          : const Color(0xFFF7FBFC);
      final foreground = DecoratedBox(
        decoration: BoxDecoration(
          color: tint.withValues(alpha: opaque ? 1 : widget.tintOpacity),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: widget.dark ? .16 : .30),
            width: .8,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: widget.dark ? Colors.white : const Color(0xFF102D35),
          ),
          child: IconTheme.merge(
            data: IconThemeData(
              color: widget.dark ? Colors.white : const Color(0xFF102D35),
            ),
            child: widget.child,
          ),
        ),
      );
      ui.ImageFilter? filter;
      if (!opaque) {
        if (canRefract) {
          _shader!
            ..setFloat(2, radius / shortest)
            ..setFloat(3, widget.edgeBand / shortest)
            ..setFloat(4, widget.strength / shortest)
            ..setFloat(5, widget.frost / shortest)
            ..setFloat(6, widget.dispersion / shortest);
          filter = ui.ImageFilter.shader(_shader!);
        } else {
          filter = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
        }
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.dark ? .20 : .10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: filter == null
              ? foreground
              : BackdropFilter(filter: filter, child: foreground),
        ),
      );
    },
  );
}
