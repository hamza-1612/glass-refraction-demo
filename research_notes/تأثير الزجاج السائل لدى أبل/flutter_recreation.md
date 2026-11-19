# Recreating Apple Liquid Glass in Flutter: `BackdropFilter` + `ImageFilter.shader` on Impeller (state as of Nov 2026)

Method note: api.flutter.dev and docs.flutter.dev do not resolve from this research sandbox. Their text was read from the source files they are generated from: `engine/src/flutter/lib/ui/painting.dart` in flutter/flutter (master, commit f54b017, 2026-11-19) and the flutter/website Markdown sources (main). Both the canonical doc URL and the source URL are cited. Package code was read from clones of each package's GitHub `main` branch, as of these commits: liquid_glass_renderer 1.0.0-dev.2 (2026-10-29), liquid_glass_easy 5.2.0 (2026-11-02), oc_liquid_glass 0.3.0 (2026-06-25) and liquid_glass_widgets 1.18.0 (2026-11-19). GitHub issue threads were read through github.com pages.

## Q1. What Flutter documents about `ImageFilter.shader` in a `BackdropFilter`: uniforms, coordinate space, texture size, Y-flip, support checks, versions, and known bugs

### Takeaway
Flutter's only official contract has three parts. The engine fills the **first vec2 uniform (float indices 0–1)** with the **size of the bound input texture**. It fills the **first sampler2D** with the filter input. `FlutterFragCoord()` returns "local coordinates". Flutter never says that either value is the widget's size or origin, and in practice they are not. For a `BackdropFilter`, the input texture is the **backdrop of the enclosing render pass**: normally the whole screen or window in physical pixels. It can also be a **clip-cropped** or **subpass** texture, depending on the Flutter version, the clip, how far the widget is off-screen, and its ancestors. The OpenGLES Y-flip changed in **Flutter 3.47**: shaders that still flip on GLES now render upside down. A shader that assumes `uSize` equals the widget size will be wrong on every device. This is the most likely cause of the demo's "terrible on a real phone" result.

### Cited Findings

**Official API contract (`ImageFilter.shader`)**
- Official API docs: "The first uniform value must be a vec2, this will be set by the engine to the size of the bound texture. There must also be at least one sampler2D uniform, the first of which will be set by the engine to contain the filter input." Source: [api.flutter.dev ImageFilter.shader](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html), read from [painting.dart source](https://github.com/flutter/flutter/blob/master/engine/src/flutter/lib/ui/painting.dart).
- "This API is only supported when using the Impeller rendering engine. On other backends, an [UnsupportedError] will be thrown." The runtime check is `static bool get isShaderFilterSupported => _impellerEnabled;`. Source: [painting.dart](https://github.com/flutter/flutter/blob/master/engine/src/flutter/lib/ui/painting.dart).
- If the shader has fewer than two float uniforms or no sampler, the constructor throws a `StateError`: "ImageFilter.shader requires that the first uniform is a vec2 and at least one sampler uniform is present." Source: [painting.dart](https://github.com/flutter/flutter/blob/master/engine/src/flutter/lib/ui/painting.dart). The missing `throw` in this validation was fixed in PR 180923, released in 3.44. Source: [3.44.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.44.0).
- An optional `filterQuality` parameter sets how the filter input is sampled. The default is `FilterQuality.none`, which means nearest-neighbour. Source: [painting.dart](https://github.com/flutter/flutter/blob/master/engine/src/flutter/lib/ui/painting.dart). It was added by "[Impeller] Add filterQuality support to ImageFilter.shader" (PR 188544) and first appears in the [3.50.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.50.0). Before that, the implicit backdrop sampler was always nearest. This caused "stair-step aliasing" in refraction and lens shaders, and the workaround was a manual 4-tap bilinear filter at about 4× the sampling cost. Source: [flutter#188365](https://github.com/flutter/flutter/issues/188365).
- On master (Nov 2026), the `painting.dart` doc comment still says: "When Impeller uses the OpenGL(ES) backend, the y-axis direction is reversed. Custom fragment shaders must invert the y-axis on GLES or they will render upside-down." Its example shader has `#ifdef IMPELLER_TARGET_OPENGLES uv.y = 1.0 - uv.y`. Source: [painting.dart](https://github.com/flutter/flutter/blob/master/engine/src/flutter/lib/ui/painting.dart). **This is out of date.** See the 3.47 breaking change below.

**docs.flutter.dev fragment-shaders page (ImageFilter API section)**
- "When using ImageFilter with BackdropFilter, a ClipRect can be used to limit the area that is affected by the ImageFilter. Without a ClipRect the BackdropFilter will be applied to the whole screen." Source: [Fragment shaders page](https://docs.flutter.dev/ui/design/graphics/fragment-shaders) ([source md](https://github.com/flutter/website/blob/main/sites/docs/src/content/ui/design/graphics/fragment-shaders.md)).
- "The sampler2D value at index 0 is set to the filter input image, and the float values at indices 0 and 1 are set to the image's width and height … you should not set them from your Dart code." Source: [Fragment shaders page](https://docs.flutter.dev/ui/design/graphics/fragment-shaders).
- `FlutterFragCoord`: "a varying value that contains the local coordinates for the particular fragment … distinct from gl_FragCoord … gl_FragCoord provides the screen space coordinates and should generally be avoided … When targeting a Skia backend, the calls to gl_FragCoord are rewritten to access local coordinates but this rewriting isn't possible with Impeller." Source: [Fragment shaders page](https://docs.flutter.dev/ui/design/graphics/fragment-shaders).
- On Impeller, `FlutterFragCoord()` returns the `_fragCoord` varying that `impeller/entity/shaders/runtime_effect.vert` outputs. On Skia it returns `gl_FragCoord.xy`. Source: [runtime_effect.glsl](https://github.com/flutter/flutter/blob/master/engine/src/flutter/impeller/compiler/shader_lib/flutter/runtime_effect.glsl).
- The docs page's ImageFilter example still includes the GLES `uv.y = 1.0 - uv.y` flip. Source: [Fragment shaders page](https://docs.flutter.dev/ui/design/graphics/fragment-shaders). This is also outdated for 3.47 and later.

**What `FlutterFragCoord`/`uSize` actually mean for backdrop filters (package authors' findings)**
- liquid_glass_renderer (whynotmake-it) states: "Filter fragment coordinates are local to the enclosing render pass. At the root that is the screen; inside a [LiquidGlassCapture] it is the capture's pixel-snapped clip." Source: [filter_pass_transform.dart](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/lib/src/internal/filter_pass_transform.dart).
- liquid_glass_renderer's final shader says: "Apple Metal surfaces expose global filter coordinates, while other backends may expose clip-local coordinates." Its `main()` computes `vec2 screenUV = FlutterFragCoord().xy / uSize;` and then maps fragCoord into widget space through a Dart-supplied affine transform. Source: [liquid_glass_final_render_core.glsl](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_final_render_core.glsl).
- liquid_glass_easy states: "Under ImageFilter.shader, FlutterFragCoord() is physical pixels measured from the corner of whatever surface the pass renders into — normally the window, so position and resolution are global." It adds an Android-specific warning: "An ancestor can render this lens into a filtered subpass — Android's stretch overscroll does, for exactly as long as the pull lasts — and the fragments then arrive in THAT texture's space … dividing by the window instead squeezes the whole page into the glass." Source: [render_liquid_glass_lens.dart](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/src/widgets/lens/render_liquid_glass_lens.dart).
- liquid_glass_easy also says the frame depends on the engine version: "Batched with a composed blur, where FlutterFragCoord counts from depends on the engine: some crop the shader's input to the pass's clip and count from its top-left, newer ones keep the surface's frame. Dart cannot tell which." Its workaround compares the engine-written size against the expected clip far corner inside the shader. Sources: [render_liquid_glass_lens.dart](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/src/widgets/lens/render_liquid_glass_lens.dart) and [liquid_glass.frag](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/assets/shaders/liquid_glass.frag).
  ```glsl
  vec2 fragOrigin() {
      if (!composePass()) return vec2(0.0);
      vec2 clipFar = u_imageOffset - u_imageSize;
      bool clipLocal = u_resolution.x < clipFar.x - 1.0 ||
                       u_resolution.y < clipFar.y - 1.0;
      return clipLocal ? u_imageOffset : vec2(0.0);
  }
  ```
- oc_liquid_glass treats `FlutterFragCoord()` as global physical pixels and `u_size` as the full backdrop size. It sends shape rects as `getTransformTo(null)` × devicePixelRatio and pushes `BackdropFilterLayer(filter: ImageFilter.shader(sh))` with no tight clip. Source: [oc_liquid_glass.dart](https://github.com/heyarny/oc_liquid_glass/blob/main/lib/oc_liquid_glass.dart) and [liquid_glass.frag](https://github.com/heyarny/oc_liquid_glass/blob/main/shaders/liquid_glass.frag).

**Clip and coordinate behaviour changes (GitHub issues)**
- flutter#178798 ("BackdropFilter shader UV sampling is incorrect on beta when using ClipRect"):
  - Reported on beta 3.39.0-0.1.pre, macOS, Impeller.
  - With a ClipRect, the UV mapping `FlutterFragCoord().xy / uSize` changed relative to 3.38.0 stable.
  - Engine member gaaclarke said the old behaviour "wasn't documented or tested", so the change was not technically breaking.
  - Closed by PR #178940 on 2025-11-27, which "Documents and fixes behavior when clipping background filter fragment…".
  - Source: [flutter#178798](https://github.com/flutter/flutter/issues/178798).
- flutter#181660 (3.41 beta): with ClipRect plus a composed blur, a backdrop shader sampled the wrong UVs. Rasterizing the blurred input is "sized to the clip rect, so the extra pixels a blur needs at the edges are missing". It was fixed by PR #181743 ("Add buffer around rerasterized input to fragment shaders", merged 2026-02-07) and cherry-picked to stable on 2026-02-24. Source: [flutter#181660](https://github.com/flutter/flutter/issues/181660).
- flutter#185175 (**open, P1**, opened 2026-04-16): "Shaders Applied Using ImageFilter.shader Do Not Use Full Child Rect When the Child Is Clipped".
  - When a widget scrolls partly off-screen, the engine-provided size uniform and `FlutterFragCoord()` shift to match the visible, clipped coverage. A clip at the top moves the origin, so UVs slide.
  - Reproduced on an iOS simulator, a **Pixel 6a**, and Windows with 3.47.4.
  - Traced to `ComputeSaveLayerCoverage` using `intersected_coverage` together with a `SizeDifferenceUnderThreshold` threshold.
  - gaaclarke: "I think this is working as intended"; supply constant numbers yourself if the effect must stay fixed.
  - Workaround: pass the full layout size and offset from Dart every frame.
  - Proposed fix: an `unclippedInput` option, PR #193275, still open.
  - Source: [flutter#185175](https://github.com/flutter/flutter/issues/185175).
- Other issues that came up in searches (titles only; threads not read):
  - #187820, closed 2026-06-10: "[Impeller] iOS device: BackdropFilter(ImageFilter.shader) stacked above another BackdropFilter samples stale previous-frame backdrop including its own output".
  - #170820, closed 2025-06-18: "ImageFilter.blur breaks ImageFilter.shader in a BackdropFilter together".
  - #193389, open: "[Impeller] UberSDF color-source fallback shifts a FragmentShader by the fractional part of the draw's origin".
  - #194832, open: "Impeller: Severe Performance Regression in ImageFilter.compose with Shared Backdrops: Re-rasterization Ignores Clip Bounds (#181743)".
  - #177795, open: "ImageFilter.compose: sampling outside of inner has backend differences".
  - #171378, open: "Opacity not working on a ImageFiltered using ImageFilter.shader".
  - Source: GitHub search API results for repo:flutter/flutter, e.g. [flutter#187820](https://github.com/flutter/flutter/issues/187820) and [flutter#194832](https://github.com/flutter/flutter/issues/194832).

**OpenGLES Y-flip history**
- flutter#169429 (3.32.0, Android emulator API 30 on GLES): shaders rendered upside down because impellerc did not define `IMPELLER_TARGET_OPENGLES` for runtime-effect shaders. PR #170375 ("[impellerc] add GLES shader define") fixed this on 2025-06-11. jonahwilliams's comment on coordinate conventions: "you're writing the shader, you opted into that." Source: [flutter#169429](https://github.com/flutter/flutter/issues/169429).
- "[Impeller] document reverse-y requirement for ImageFilter.shader" (PR 169761) shipped in 3.35. Source: [3.35.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.35.0).
- **Breaking change, stable 3.47** (landed in 3.46.0-0.1.pre): "Impeller's OpenGL ES backend now stores render-to-texture content top-down, the same as the Metal and Vulkan backends. A fragment shader … that … added a vertical flip to compensate for the old bottom-up orientation now renders that content upside down." Source: [Breaking change: OpenGL ES render-to-texture content is stored top-down](https://docs.flutter.dev/release/breaking-changes/opengles-render-to-texture-top-down) ([source md](https://github.com/flutter/website/blob/main/sites/docs/src/content/release/breaking-changes/opengles-render-to-texture-top-down.md)). Related PRs: 186556 ("Retire Y-coord-scale plumbing by flipping GLES at the vertex stage"), 187224, and 187686 ("Remove the texture coordinate system Y-flip workaround"), all in the [3.47.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.47.0).
- The migration uses a version-portable guard:
  ```glsl
  #if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
    uv.y = 1.0 - uv.y;
  #endif
  ```
  impellerc defines the macro for `kRuntimeStageGLES` and `kRuntimeStageGLES3`, with the comment "A temporary macro that allows fragment shader authors to target Flutter <= 3.44 before the OpenGLES flip was removed." Sources: [breaking change page](https://docs.flutter.dev/release/breaking-changes/opengles-render-to-texture-top-down) and [compiler.cc](https://github.com/flutter/flutter/blob/master/engine/src/flutter/impeller/compiler/compiler.cc).
- liquid_glass_easy's changelog describes the failure mode: "Flutter's OpenGLES coordinate-system unification (engine after 3.44.0) removed the framebuffer Y-flip, which turned the shaders' manual sampler/derivative Y-flips into a *double* flip … visible on Android emulators that fall back to OpenGL ES (real Vulkan/Metal devices were never affected)." Source: [liquid_glass_easy CHANGELOG](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/CHANGELOG.md).

**History, versions, and related APIs**
- Impeller support for `ImageFilter.shader` came from engine PR flutter/engine#53490, which closed flutter#132099 on 2024-11-08. Source: [flutter#132099](https://github.com/flutter/flutter/issues/132099). The fix "[ui] Fix ImageFilter.shader equality to consider uniform values" is in the [3.32.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.32.0). "docs: Impeller usage requirements for ImageFilter.shader and isShader…" (PR 179387) is in the [3.41.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.41.0).
- "Support backdrop key in flutter framework" (PR 157278) is in the [3.29.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.29.0).
- Current `BackdropGroup` and `BackdropFilter.grouped` docs: "Multiple backdrop filters can be combined into a single rendering operation by the Flutter engine if these backdrop filter widgets all share a common [BackdropKey] and have equivalent filter configurations … a 'bounded' blur … assigns unique layout bounds to each widget, which prevents the engine from collapsing them into a single blur pass (though the initial backdrop capture is still shared across the group)." Source: [basic.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/widgets/basic.dart) ([api.flutter.dev BackdropGroup](https://api.flutter.dev/flutter/widgets/BackdropGroup-class.html)).
- Gotcha: the `BackdropFilter` doc comment says only `BlendMode.srcOver` is supported on all platforms. Under a parent saveLayer such as `Opacity`, `BlendMode.src` "can produce more pleasing results". Source: [basic.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/widgets/basic.dart).

### Inferences
- The demo's assumption that "`uSize` = glass widget size and `FlutterFragCoord()` = widget-local" fails for this reason: on Impeller, `uSize` is the size of the backdrop texture (normally the full screen in physical pixels) and `FlutterFragCoord()` is in that texture's frame. The SDF is therefore computed as if the glass covered the whole screen, and refraction offsets are scaled against screen dimensions. This matches the reported "looks terrible" symptom. On a desktop or iOS-simulator preview where the widget nearly fills the window, the error is much less visible.
- `ClipRRect` around `BackdropFilter` only limits where the result is painted. It does not reliably move the shader's origin to the widget. Whether `uSize` and the origin become clip-local depends on the Flutter version (#178798) and on how much of the widget is off-screen (#185175). Robust code must not rely on either.
- The demo pins `flutter: '>=3.44.0'`, so it straddles the 3.47 GLES flip change. A plain `#ifdef IMPELLER_TARGET_OPENGLES` flip is correct on 3.44 and wrong on 3.47 and later. Use the `IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED` guard. Real Android phones usually run Impeller on Vulkan, so the flip matters mainly on emulators and GLES-fallback devices. The coordinate-space mismatch matters everywhere.
- The `FilterQuality.none` default (nearest sampling) makes displaced or refracted backdrops look jagged on phones. On 3.50 and later, pass `filterQuality: FilterQuality.low` or higher (linear). On older versions, use a manual bilinear fallback.

### Gaps
- No official doc defines the exact coordinate frame of `FlutterFragCoord()` for a `BackdropFilter` (global vs clip-local, physical vs logical). The evidence comes from package-author comments and issue threads. It shows physical pixels of the render-pass texture, with clip cropping that varies by version.
- I could not confirm which stable release first shipped `ImageFilter.shader` working inside `BackdropFilter`. Engine PR #53490 closed in Nov 2024, which suggests 3.29 (Feb 2025), but no release note found confirms this.
- I did not verify whether `BackdropGroup` and `BackdropFilter.grouped` themselves first shipped in 3.29 or 3.32. Only the backdrop key framework support is confirmed for 3.29.
- I did not read the threads for #187820, #170820, #193389, #194832 or #177795 beyond their titles.

## Q2. How popular packages do it: rect and size uniforms, backdrop capture, shader structure, Android limitations

### Takeaway
None of the mature packages trusts `uSize` as the widget size. They all compute the glass geometry in Dart at **paint or scene-build time** with `getTransformTo(null)` (or a capture or subpass ancestor) and multiply by `devicePixelRatio`. They pass the result as uniforms in the **same physical-pixel, render-pass space as `FlutterFragCoord()`**, and use `uSize` only to normalise texture lookups (`fragCoord / uSize`). On Impeller they capture with `BackdropFilterLayer(ImageFilter.shader)`. On Skia and web they fall back to `RepaintBoundary`/`toImage` snapshots or a "fake glass" blur. The most advanced package, liquid_glass_renderer 1.0, now pre-renders an SDF and normal "geometry matte" with Flutter GPU. Its main Android pitfalls are a Mali-Vulkan shader-compiler bug, the stretch-overscroll subpass, and the cost of each backdrop copy.

### Cited Findings

**liquid_glass_renderer (whynotmake-it/flutter_liquid_glass), 1.0.0-dev.2, Oct 2026**
- Requirements: Flutter 3.47 or later, plus "Impeller and Flutter GPU for full glass". Enable Flutter GPU with `--enable-flutter-gpu`, or with `io.flutter.embedding.android.EnableFlutterGPU` meta-data in `AndroidManifest.xml`. "Wherever full glass is unavailable, layers switch to `FakeGlass` automatically." Source: [README](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/README.md).
- Limitations: "Experimental", "At most 16 shapes per layer", "One corner radius per shape", and the child is painted on top of the glass and never refracted by it. Source: [README](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/README.md).
- Architecture: a `LiquidGlassLayer` "Samples the backdrop once and renders every glass shape below it". `LiquidGlassCapture` "Captures the backdrop once for glass that sits on other glass". Source: [README](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/README.md).
- Shader structure:
  - A Flutter GPU geometry pass renders a low-resolution RGBA16F "matte" holding edge distance, surface normal and displacement, at "one RGBA16F texel for every uLowResMatte.x x uLowResMatte.x block of matte pixels".
  - The final `ImageFilter.shader` pass reads the matte with one bilinear tap, then refracts the backdrop with dispersion, frost, tint, rim and glint lighting, and bevel shadow.
  - Uniforms include `uSize` (engine), `uGeometryOffset`/`uGeometrySize` (device px), `uFilterToMatteBasis`/`uFilterToMatteOffset` (affine map from filter frag coords to the layer matte), and `uBackdropBounds` ("Matte-space rect (LTRB, device px) the filter captured backdrop for. Outside it the filter input is transparent or clamped, so displaced samples are mirrored back in at its edge").
  - Source: [liquid_glass_final_render_core.glsl](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_final_render_core.glsl).
- Coordinate mapping in Dart: the package inverts `filterPassTransform(...)`, which is `owner.getTransformTo(null)` or relative to an enclosing capture or seeded pass. It writes a 2×2 basis plus an origin × devicePixelRatio at float index 46, and the backdrop bounds × devicePixelRatio at index 53:
  ```dart
  final globalToMatte = Matrix4.inverted(shaderCoordinateTransform);
  final origin = MatrixUtils.transformPoint(globalToMatte, Offset.zero);
  final axisX = MatrixUtils.transformPoint(globalToMatte, const Offset(1, 0));
  final axisY = MatrixUtils.transformPoint(globalToMatte, const Offset(0, 1));
  return (axisX.dx - origin.dx, axisY.dx - origin.dx,
          axisX.dy - origin.dy, axisY.dy - origin.dy,
          origin.dx * devicePixelRatio, origin.dy * devicePixelRatio);
  ```
  Source: [liquid_glass_layer.dart](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/lib/src/rendering/liquid_glass_layer.dart).
- GLES detail: when glass is undisplaced the shader uses `texelFetch`, but under `IMPELLER_TARGET_OPENGLES` it uses `texture()` because "The GLES runtime stages also emit GLSL ES 1.00, which has no texelFetch." Source: [liquid_glass_final_render_core.glsl](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_final_render_core.glsl).
- Android bug fixed in the package: "On Mali GPUs under Vulkan (Pixel 8 / Tensor G3, Pixel 9 Pro / Tensor G4), the ternary in decodeSignedEdgeDistance returns 0 for an empty matte texel … tint, contour and bevel shadow fill the whole bounding rectangle. Metal and Impeller OpenGL ES render correctly. Selecting the range with step()/mix() decodes correctly on all three." (#246). An earlier release had "FIX: render liquid glass correctly on all Android devices (#82)" in 0.1.1-dev.18. Source: [CHANGELOG](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/CHANGELOG.md).
- A Pixel 10 Vulkan driver crash is noted in code ("Vulkan (Pixel 10, PowerVR …) vulkan.powervr.so (CmdEndRenderPass2+188)"). Source: [flutter_gpu_geometry_renderer_native.dart](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/lib/src/internal/flutter_gpu_geometry_renderer_native.dart).

**liquid_glass_easy (AhmeedGamil), 5.2.0, Nov 2026**
- Render paths:
  - Impeller: "The lens refracts the live backdrop … No LiquidGlassView … needed".
  - Skia with `LiquidGlassView`: refracts a captured background.
  - Skia without a view: "degrades to a frosted look".
  - "Lite" mode: no shader.
  - Source: [README](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/README.md).
- Uniforms are packed into vec4s because "Impeller on iOS binds each runtime-effect uniform to its own Metal buffer and caps at ~30". Source: [liquid_glass.frag](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/assets/shaders/liquid_glass.frag).
- The Impeller lens packs its uniforms during `addToScene` "after all layout and paint — so the transform is final for the frame, scroll offsets included". It uses `getTransformTo(subpassAncestor)` × devicePixelRatio. Under a non-translation ancestor transform it switches to lens-local geometry plus an inverse map. Its batching snaps the clip to whole pixels ("the engine rounds it out"). Source: [render_liquid_glass_lens.dart](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/src/widgets/lens/render_liquid_glass_lens.dart).
- The texture mapping is explicit: "The bound texture (u_texture_input) covers the parent-space rectangle [u_imageOffset, u_imageOffset + u_imageSize] in the SAME pixel space as FlutterFragCoord / u_resolution. For a normal full-frame capture this is offset (0,0) and size u_resolution." The backdrop alpha is ignored on Impeller because "its alpha is not a transparency signal and reads 0 over dark regions". Source: [liquid_glass.frag](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/assets/shaders/liquid_glass.frag).
- Skia capture uses `picture.toImageSync(...)` for a shape cache, plus capture tuning (`pixelRatio`, `frameLimit`). Sources: [liquid_glass_shape_cache.dart](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/src/widgets/lens/liquid_glass_shape_cache.dart) and [README](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/README.md).

**oc_liquid_glass (heyarny), 0.3.0, Jun 2026, requires Flutter ≥3.32.5**
- "Works only on platforms that support Impeller engine". Source: [README](https://github.com/heyarny/oc_liquid_glass/blob/main/README.md).
- One `BackdropFilterLayer(filter: ImageFilter.shader(sh))` covers the group's render box, with up to 4 rounded rects (`uRect0..3` = center and size in physical pixels, plus a corner radius and tint each).
- `uBounds` holds the group's global bounding box in physical pixels and is used for a passthrough early-out: `if (fragPx outside uBounds) fragColor = vec4(0)`.
- The shader computes a smooth-union SDF, refraction with falloff/exponent, a radial blur, a specular highlight and a "light band".
- It applies `#ifdef IMPELLER_TARGET_OPENGLES sampleUv.y = 1.0 - sampleUv.y;` with no `UNFLIPPED` guard, so it would double-flip on GLES in Flutter 3.47 and later.
- Sources: [oc_liquid_glass.dart](https://github.com/heyarny/oc_liquid_glass/blob/main/lib/oc_liquid_glass.dart) and [liquid_glass.frag](https://github.com/heyarny/oc_liquid_glass/blob/main/shaders/liquid_glass.frag).
  ```dart
  final transform = shape.getTransformTo(null);
  final rect = MatrixUtils.transformRect(transform, Offset.zero & shape.size);
  ...
  ..setFloat(idx++, s.center.dx * _devicePixelRatio)
  ..setFloat(idx++, s.center.dy * _devicePixelRatio)
  ```

**liquid_glass_widgets (sdegenaar), 1.18.0, Nov 2026, ~860 stars**
- Its engine is "derived from liquid_glass_renderer … Upstream Baseline: v0.2.0-dev.4 … Forked 2026-03-28". Source: [ATTRIBUTION.md](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/lib/src/engine/ATTRIBUTION.md).
- Quality tiers: `premium` (Impeller refraction, blur and frost), `standard` (a lightweight single-pass shader for Skia, web and dense lists), and `minimal` (a shader-free `BackdropFilter`).
- Per platform: "Android (Vulkan): Full 16-shape shader pipeline …" and "Android (GLES fallback): GLES-optimized 8-shape shader intended to reduce runtime driver compile stalls".
- Interactive lenses are lazy-mounted (no shader until touched). An experimental `GlassAdaptiveScope` "steps quality down … under thermal throttle".
- Source: [README](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/README.md).

### Inferences
- The common pattern every working package uses, in four steps:
  1. Measure the glass in global physical pixels at paint or scene-build time.
  2. Treat `FlutterFragCoord()` as physical pixels in the backdrop texture's frame, and use `uSize` only for `uv = px / uSize`.
  3. Compute the SDF in pixel space against the passed rect.
  4. Sample the backdrop at `(fragPx + displacementPx) / uSize`.
- The "Liquid Glass" look in these packages is built from: a rounded-rect or superellipse SDF; a bevel or height profile near the edge, usually a quarter-circle `1 - sqrt(1 - x²)` (liquid_glass_renderer line ~573); a normal taken from the SDF gradient; displacement along the normal; optional chromatic dispersion; and frost blur, tint and saturation boost, rim specular, and glint.

### Gaps
- No package named exactly `flutter_liquid_glass` turned up on pub.dev. The GitHub repo "whynotmake-it/flutter_liquid_glass" is the monorepo for liquid_glass_renderer, and HadesPTIT/flutter_liquid_glass (10 stars, last pushed 2025-06) was not inspected.
- Package docs give no Android-specific limitations beyond the ones above (the Mali ternary bug, the GLES fallback, the stretch-overscroll subpass).

## Q3. Recommended uniform layout and Dart code for computing the glass rect in backdrop-texture coordinates

### Takeaway
Keep the engine's `uSize` at float indices 0–1 and the sampler at index 0. Then pass the glass rect and corner radius **in physical pixels, in the same frame as `FlutterFragCoord()`**. Compute them during paint (or in `addToScene`) with `getTransformTo(null)` × devicePixelRatio, not in `build`. Detect clip-local cropping in the shader by comparing `uSize` with the expected full surface size, and guard the GLES flip with `IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED`. Set `filterQuality` to linear on 3.50 and later. Clamp or mirror displaced samples to the captured bounds.

### Cited Findings
- Engine-reserved slots: floats 0–1 (texture width and height) and sampler 0. "You should not set them from your Dart code", so custom floats start at index 2. Source: [Fragment shaders page](https://docs.flutter.dev/ui/design/graphics/fragment-shaders).
- The package pattern of global transform × devicePixelRatio, captured after layout and paint so that scroll offsets are final: [render_liquid_glass_lens.dart](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/src/widgets/lens/render_liquid_glass_lens.dart) and [oc_liquid_glass.dart](https://github.com/heyarny/oc_liquid_glass/blob/main/lib/oc_liquid_glass.dart).
- Workaround for clipped or scrolled widgets: pass the full layout size and offset from Dart each frame and recompute UVs when the engine-provided size differs. Source: [flutter#185175](https://github.com/flutter/flutter/issues/185175).
- Outside the clip the filter input is transparent or clamped, so displaced samples should be mirrored or clamped back in. liquid_glass_renderer mirrors at `uBackdropBounds`, and liquid_glass_easy clamps to `[0.001, 0.999]`. Sources: [liquid_glass_final_render_core.glsl](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_final_render_core.glsl) and [liquid_glass.frag](https://github.com/AhmeedGamil/liquid_glass_easy/blob/main/lib/assets/shaders/liquid_glass.frag).
- oc_liquid_glass suggests inflating the clip: "If this is clipped for performance later, inflate the clip by the shader's refraction sample reach or edge pixels will clamp during strong refraction." Source: [oc_liquid_glass.dart](https://github.com/heyarny/oc_liquid_glass/blob/main/lib/oc_liquid_glass.dart).
- A newer setter API, `shader.setFloatUniforms(initialIndex: …, (value) { value.setFloats([...]); })`, is in use (liquid_glass_renderer, Flutter ≥3.47). Source: [liquid_glass_layer.dart](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/lib/src/rendering/liquid_glass_layer.dart). The older API, `setFloat(i, v)`, still works.

### Inferences (synthesised recommendation; not taken from one source)
Recommended GLSL layout (floats in declaration order):
```glsl
#include <flutter/runtime_effect.glsl>
uniform vec2  uSize;        // [0,1]  ENGINE: backdrop texture size (physical px)
uniform vec4  uRect;        // [2..5] glass rect L,T,W,H in physical px, surface frame
uniform float uRadius;      // [6]    corner radius, physical px
uniform vec2  uSurface;     // [7,8]  full surface (view) size in physical px
uniform vec4  uClip;        // [9..12] clip rect L,T,W,H physical px (rounded OUT to ints)
uniform float uBand;        // [13]   bevel width px
uniform float uStrength;    // [14]   displacement px
uniform sampler2D uBackdrop;// sampler 0 ENGINE
out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec4 sampleBackdrop(vec2 px, vec2 origin) {
  vec2 uv = clamp((px - origin) / uSize, vec2(0.5) / uSize, 1.0 - vec2(0.5) / uSize);
#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;   // only Flutter <= 3.44 GLES
#endif
  return texture(uBackdrop, uv);
}
void main() {
  // If the engine cropped the input to the clip, uSize ~= clip size, not surface size.
  bool clipLocal = abs(uSize.x - uClip.z) < 1.5 && abs(uSize.y - uClip.w) < 1.5
                   && (uSize.x < uSurface.x - 1.5 || uSize.y < uSurface.y - 1.5);
  vec2 origin = clipLocal ? uClip.xy : vec2(0.0);
  vec2 px = FlutterFragCoord().xy + origin;          // -> surface physical px
  vec2 c = uRect.xy + 0.5 * uRect.zw;
  float d = sdRoundRect(px - c, 0.5 * uRect.zw, uRadius);
  if (d > 1.0) { fragColor = sampleBackdrop(px, origin); return; }
  // ... edge profile from -d / uBand, normal from SDF gradient, displacement in px ...
}
```
- The `clipLocal` heuristic follows liquid_glass_easy's `fragOrigin()`. It covers both engine behaviours reported in #178798 and #185175, but it is heuristic. In the demo's widget-local logic, replace every use of `FlutterFragCoord()` with `px - uRect.xy`.

Dart side (a custom `RenderProxyBox`, or computed in a `CustomPainter`/`LayoutBuilder` post-frame; doing it in `paint` is preferable):
```dart
@override
void paint(PaintingContext context, Offset offset) {
  final dpr = _dpr; // MediaQuery.devicePixelRatioOf(context), pushed into the render object
  final m = getTransformTo(null);                       // includes scroll & transforms
  final r = MatrixUtils.transformRect(m, Offset.zero & size); // logical, global
  final phys = Rect.fromLTRB(r.left * dpr, r.top * dpr, r.right * dpr, r.bottom * dpr);
  final clip = Rect.fromLTRB(phys.left.floorToDouble(), phys.top.floorToDouble(),
                             phys.right.ceilToDouble(), phys.bottom.ceilToDouble());
  final surface = _viewPhysicalSize; // View.of(context).physicalSize
  var i = 2;                                            // 0,1 reserved for engine uSize
  _shader
    ..setFloat(i++, phys.left)..setFloat(i++, phys.top)
    ..setFloat(i++, phys.width)..setFloat(i++, phys.height)
    ..setFloat(i++, _radius * dpr)
    ..setFloat(i++, surface.width)..setFloat(i++, surface.height)
    ..setFloat(i++, clip.left)..setFloat(i++, clip.top)
    ..setFloat(i++, clip.width)..setFloat(i++, clip.height)
    ..setFloat(i++, _band * dpr)..setFloat(i++, _strength * dpr);
  context.pushClipRRect(needsCompositing, offset, Offset.zero & size,
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(_radius)),
      (ctx, o) => ctx.pushLayer(
          BackdropFilterLayer(filter: ui.ImageFilter.shader(_shader /*, filterQuality: FilterQuality.low on >=3.50 */)),
          super.paint, o));
}
```
- Repaint whenever the global position changes: during scroll, animation, or route transitions. Otherwise the uniforms go stale. liquid_glass_easy packs in `addToScene` for this reason.
- Rotation or scale ancestors: a rect-only uniform breaks under them. Pass an inverse affine map, as liquid_glass_renderer and liquid_glass_easy do.
- Android stretch overscroll: during a pull the glass renders into a subpass, so `uSize` then equals that subtree's size and not the screen. liquid_glass_easy handles this by measuring from the subpass ancestor. A simpler mitigation is `ScrollConfiguration` with `ClampingScrollPhysics` / `overscroll: false` around glass-over-scroll screens.

### Gaps
- No official Flutter sample shows mapping a widget rect into a `BackdropFilter` shader's frame. The recommended code above is a synthesis of package code and issue workarounds, not a documented API, and it has not been tested on a device as part of this research.
- `View.of(context).physicalSize` matching the backdrop texture size under all embeddings (edge-to-edge, cutouts, multi-window) was not verified.

## Q4. Performance numbers and tips on Android phones

### Takeaway
The cost unit is the **backdrop copy**. On Impeller, every independent `BackdropFilter` triggers a full-screen readback whatever the glass size. Share copies with `BackdropGroup` or a shared `BackdropKey`. Avoid tiny blur sigmas (≤ about 4 device px disables downsampling) and very large ones. Keep shadows, shape count and animated geometry low. Provide a no-backdrop fallback for weak or hot devices. All the hard numbers found are from a Pixel 10 (high-end); no published numbers for mid-range Android phones were found.

### Cited Findings
- Pixel 10 (Impeller/Vulkan, 120 Hz, SoC GPU power rail), 2026-09-13:
  - "every independent BackdropFilter costs ~115 mW just for Impeller's full-screen readback."
  - Per element: "A plain BackdropFilter(blur σ7) is ≈165 mW/element, FakeGlass ≈230, real glass ≈335."
  - Sharing: "Layers that share one BackdropGroup / BackdropKey pay the readback once (two real layers 797 → 688 mW; two plain blurs 426 → 312)."
  - "Glass shadows add ~75 mW per shape."
  - "Continuously animating blend-group geometry costs ~120 mW CPU and can miss 120 Hz."
  - Blur: "σ≤4 disables Impeller's downsample and costs more than σ7; σ20 costs ~3× σ7."
  - App-like scroll: "glass OFF 88 / FAKE 224 / REAL 247 mW GPU."
  - Source: [performance-audit.md](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/example/tool/results/performance-audit.md).
- Same audit: "Readbacks are full-screen regardless of shape size". Shader ALU micro-optimisations "moved every scenario by less than run noise … The PowerVR compiler already folds this; the shader is not a lever." A per-frame geometry rebuild costs about 2 ms on the UI thread (Flutter GPU encode and submit). Source: [performance-audit.md](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/example/tool/results/performance-audit.md).
- iPhone 15, for comparison: "real glass costs about 2 ms more GPU per 60 Hz frame than fake glass on the A16." Source: [performance-audit.md](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/example/tool/results/performance-audit.md).
- README tips:
  - "Count backdrop copies per frame. Put siblings in one layer … useBackdropGroup: true or a shared backdropKey."
  - "Keep layers small."
  - "Don't animate blend-group geometry every frame."
  - "Impeller picks a power-of-two downsample factor … and only starts downsampling above roughly 5.8 device pixels."
  - "For low power, don't sample the backdrop."
  - "Optionally await LiquidGlass.precache() before runApp."
  - Source: [README](https://github.com/whynotmake-it/flutter_liquid_glass/blob/main/packages/liquid_glass_renderer/README.md).
- `BackdropGroup` sharing caveat: a bounded blur gives each widget unique bounds, so "prevents the engine from collapsing them into a single blur pass (though the initial backdrop capture is still shared across the group)". Source: [basic.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/widgets/basic.dart).
- liquid_glass_widgets approach to scaling performance: a "GLES-optimized 8-shape shader intended to reduce runtime driver compile stalls" on Android GLES; lazy-mounted lenses; and adaptive quality stepping "premium → frost-off → standard → minimal" based on raster frame times and thermal throttle. Source: [README](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/README.md).
- Relevant open engine issues from searches (titles only):
  - #187009: "Impeller causes severe performance regression on older Adreno GPUs (e.g. Adreno 506)".
  - #194832: "Severe Performance Regression in ImageFilter.compose with Shared Backdrops: Re-rasterization Ignores Clip Bounds".
  - #193490: "[Android][Skia][Mali-G76] BackdropFilter + image uploads grow Graphics above 2 GiB".
  - Source: GitHub search results, e.g. [flutter#187009](https://github.com/flutter/flutter/issues/187009) and [flutter#194832](https://github.com/flutter/flutter/issues/194832).
- Reuse one `FragmentShader` across frames rather than creating a new one each frame. Source: [Fragment shaders page](https://docs.flutter.dev/ui/design/graphics/fragment-shaders).

### Inferences
- For the demo, on a mid-range phone:
  - Use one `BackdropFilter` per screen, or group them.
  - Avoid composing `ImageFilter.blur` with the shader. Composition forces re-rasterisation (#181660, #194832), so it is better to blur inside the shader with a few taps, or to accept frost from a separate shared blur.
  - Early-out on pixels outside the rounded rect.
  - Set `filterQuality` to low on 3.50 and later instead of a manual 4-tap bilinear.
  - Profile on device in `--profile` mode.
  - Expect older Adreno and Mali devices to be the weak spot.
- A mid-range Android GPU has much less headroom than a Pixel 10 or A16, so the "~115 mW per independent readback" finding probably translates into frame-time drops rather than just power. This is extrapolated, not measured.

### Gaps
- No published FPS or frame-time numbers were found for `BackdropFilter`+`ImageFilter.shader` glass on mid-range Android phones (e.g. Snapdragon 6/7-series, Dimensity 7xxx, Exynos 1x80). The numbers found are from a Pixel 10 and an iPhone 15. Blog posts and Medium articles were not reachable or searched in this pass.
- The threads for #187009 (older Adreno regression) were not read beyond the title, so their scope and status are unknown.
