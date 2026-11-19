# Rendering Technique Behind Apple's Liquid Glass (iOS 26 / macOS Tahoe 26+), via Reverse-Engineering and Graphics Breakdowns

Research date: 2026-11-19. Scope: how the look is rendered, in enough detail to rebuild it as a fragment shader.

**Network limits in this session.** These hosts failed DNS resolution, so their pages were never read in full: kube.io, sspai.com, habr.com, dev.to, fatbobman.com, tympanus.net (Codrops), blog.mws.rocks, cdn.jsdelivr.net and chrisbanes.github.io. Where a claim from one of them appears below, it comes from search-result snippets or aggregator summaries and is marked **[snippet]**. The kube.io surface formulas are marked **[recalled, not re-fetched]**: they come from my prior knowledge of the article and were only partly confirmed by snippets.

**Evidence labels.**
- **APPLE (official):** Apple's own description.
- **RE (reverse-engineered):** read from private Apple frameworks at runtime by third parties.
- **RECON (reconstruction):** a third-party shader that imitates the look. It is not proof of how Apple does it.

---

## 1. Refraction model (SDF of rounded rect/squircle, bevel height profile, displacement along normal, Snell's law, interior magnification vs. edge-only bending)

### Takeaway
Apple says only that the material works by "lensing": it bends and concentrates light instead of scattering it. Reverse-engineering shows the shape is passed to the compositor as a signed distance field (SDF) texture. A private `glassBackground` filter then refracts the backdrop, with separate **inner** and **outer** refraction amounts that have a pixel/point reach (inner around -80 to -110, reaching about 30 pt inward). Every public reconstruction uses the same recipe:
- Take a rounded-rect or superellipse SDF.
- Build a convex bevel height field near the edge (a circular arc or squircle profile).
- Take normals from the SDF gradient.
- Apply Snell's law with an index of refraction (IOR) around 1.5, and offset the backdrop UV along the inward normal.
- Leave the interior flat or nearly flat.

The bending is concentrated in an edge band; the interior is not strongly magnified.

### Cited Findings
**APPLE (official)**
- Apple describes the material: "Liquid Glass is a new digital meta-material that dynamically bends and shapes light." It adds that "the primary way Liquid Glass visually defines itself is through something called Lensing," and that unlike earlier materials, which "scattered light, this new set of materials dynamically bends, shapes, and concentrates light in real time." — [WWDC25 "Meet Liquid Glass" (session 219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- Refraction strength depends on element size (official): "When glass flexes and morphs to larger sizes … its material characteristics change to simulate a thicker, more substantial material. It casts deeper, richer shadows, has more pronounced lensing and refraction effects, and a softer scattering of light." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)
- Appear and disappear transitions animate the refraction itself: "Liquid Glass objects materialize in and out by gradually modulating the light bending and lensing" instead of fading opacity. — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)

**RE (reverse-engineered)**
- AlexStrNik's ShatteredGlass project takes apart the macOS 26 layer tree:
  - A `CABackdropLayer` "renders the distorted background using the `glassBackground` filter."
  - A child `CASDFLayer` named "@0" "supplies the SDF texture to the backdrop layer through `CASDFOutputEffect`," and the shape itself is a `CASDFElementLayer`.
  - The filter is wired up with `inputSourceSublayerName = "@0"`.
  - The README says `glassBackground` applies "refraction, blur, vibrancy, and tone mapping."
  - So refraction is driven by a distance field computed in the compositor, not by a precomputed displacement image. — [ShatteredGlass (GitHub)](https://github.com/AlexStrNik/ShatteredGlass)
- Private `glassBackground` input keys reported by the LiquidGlassFallback project, which zeroes them to "neutralize" glass on macOS 26/27: `inputInnerRefractionAmount`, `inputOuterRefractionAmount`, `inputRefractionOpacity` and `inputAberrationAmount`.
  - Reported stock Control Center values: `inputInnerRefractionAmount = -80` and `inputOuterRefractionAmount = 9.996`.
  - Note: the repo now returns 404, so this is **[snippet]**. — [LiquidGlassFallback (GitHub, via search snippet)](https://github.com/AotianNeo/LiquidGlassFallback)
- A macOS "islet" app that retunes the private Liquid `glassBackground` filter sets "blur 0, refraction opacity 1, inner refraction -110 over 30 pt, face white 0.8." That suggests inner refraction has both a magnitude and a reach in points (the width of the bevel band). — [ruben4reall/islet PR #22](https://github.com/ruben4reall/islet/pull/22)
- boring.notch PR #1698 drives `CABackdropLayer` + `CASDFLayer` through the Objective-C runtime so the desktop is "bent along the signed distance field of the notch shape."
  - Its user-facing controls: Refraction (default 24, range 0–100, "how hard the desktop is bent at the glass edge"), Blur (default 0.5, range 0–30), Dispersion (default 4, range 0–15) and "Lens height" (default 23 pt, range 10–60 pt, "how far inward refraction and dispersion reach").
  - These are UI labels; how they map to filter keys was not visible. — [boring.notch PR #1698](https://github.com/TheBoredTeam/boring.notch/pull/1698)
- A Chinese-language write-up says the author diffed simulator runtime headers for iOS 26 against iOS 18 **[snippet]**:
  - The backdrop layer's filter list contains the new filter type `glassBackground`, and several parameters can be set via lldb.
  - Disabling the filter by swizzling `setFilters` makes the glass render as a "blue-green texture." That texture is very likely the raw SDF/normal encoding the filter consumes; this reading is mine, not the author's. — [sspai.com/post/100983](https://sspai.com/post/100983)

**RECON (third-party reconstructions)**
- **kube.io, "Liquid Glass in the Browser: Refraction with CSS and SVG" (Sep 9, 2025)** **[snippet]**
  - It covers "light refraction through Snell's Law, surface function modeling, displacement vector field generation, and SVG filter implementation."
  - It notes Apple's glass "appears to favor convex profiles," and its demos use a "convex squircle" bezel.
  - Derived projects describe the method as tracing a vertical ray through a squircle bezel with Snell's law at n = 1.5, then baking the shift into an SVG `feDisplacementMap`, "swept around the rounded rectangle into an RGBA map." One requires corner radius ≥ bezel width.
  - Sources: [kube.io](https://kube.io/blog/liquid-glass-css-svg/); [daily.dev summary](https://daily.dev/posts/liquid-glass-in-the-browser-refraction-with-css-and-svg-kube-io-9titwb303); [PecoFence PR #9](https://github.com/DayuanJiang/PecoFence/pull/9)
- **kube.io surface functions [recalled, not re-fetched]**, where x ∈ [0,1] is the distance from the outer edge across the bezel and y is the surface height:
  ```
  convex_circle(x)   = sqrt(1 - (1 - x)^2)
  convex_squircle(x) = (1 - (1 - x)^4)^(1/4)    // flatter top, softer transition into the flat interior
  concave(x)         = 1 - convex_circle(x)
  lip(x)             = mix(convex(x), concave(x), smootherstep(x))
  // per sample along the bezel: normal from the derivative dy/dx; incident ray straight down (view-orthogonal);
  // refracted = refract(incident, normal, 1/1.5); lateral offset = refracted.xy * (thickness / refracted.z);
  // the 1-D displacement profile is precomputed, then rotated along each pixel's SDF normal to fill the 2-D map;
  // vectors are normalized by the max displacement and fed to feDisplacementMap's `scale`.
  ```
  Source: [kube.io](https://kube.io/blog/liquid-glass-css-svg/)
- **Prismal (Android, styropyr0)** gives the most explicit full pipeline found:
  - Height `t = clamp(-dist / tw, 0, 1); h = sqrt(2t - t²)`. This is a circular arc: 0 at the silhouette, 1 at full depth.
  - Transition width `tw = max(heightTransitionWidth·(1+0.38·dome) + minDim·0.085, 1)`.
  - Normals by central differences (1 px step) of h: `N = normalize(-grad·normalStrength, 1)`, plus a "meniscus" blend that bends normals outward near the silhouette.
  - Two-surface Snell refraction: `refract()` with `1/IOR` going into the glass, then `IOR` coming out. The lateral offset is scaled by thickness and displacementScale, with `refrStr = height·(0.5 + 0.35·F)`.
  - An extra lens term `1 - sqrt(1 - x²)` plus a parallax term `gradLens·height·(7 + 22·F)`.
  - Total UV offset is `lensDeltaUv + snellOff + bulgeUv`. — [Prismal TECHNICAL.md](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md)
- **ybouane/liquidglass (GLSL ES 1.0)** is described as a "rounded-rect SDF with pill-bevel height field, dual-surface (biconvex) refraction, and chromatic aberration," plus edge-weighted sampling of a pre-blurred background and Fresnel. **[snippet]** — [shaders.ts on jsDelivr](https://cdn.jsdelivr.net/npm/@ybouane/liquidglass@1.0.3/src/shaders.ts)
- Other reconstructions (Prismal and a Flutter tutorial) also use the analytic SDF gradient as the 2-D outward normal that steers the refraction direction, along with a "virtual height" per pixel. **[snippet]** — [Prismal](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md); [besthub.dev Flutter article](https://www.besthub.dev/articles/how-to-recreate-ios-26-liquid-glass-in-flutter-shaders-sdf-and-real-time-effects-9a4634181842)
- An "Optically Correct Liquid Glass" post treats the UI underneath as a "floor" directly below the glass and gets normals from a 2-D SDF. **[snippet]** — [blog.mws.rocks/p/96](https://blog.mws.rocks/p/96)
- One web analysis observes that "some Apple elements refract content beyond their borders, which can't be replicated using backdrop-filter alone." This fits the existence of a separate `inputOuterRefractionAmount`. **[snippet]** — [Frontend Masters, "Liquid Glass on the Web"](https://frontendmasters.com/blog/?p=6644)

### Inferences
- Apple refracts in two zones, an inner band and an outer band.
  - The inner band is a negative amount (about -80 to -110) over roughly 30 pt. Its sign suggests sampling inward, which compresses and magnifies edge content toward the center the way a convex lens rim does.
  - The outer band is a small positive amount (about 10). It probably pulls a little content from outside the silhouette into the edge band, or pushes it out, which produces the "refracts beyond its border" look.
  - For a shader this means: `offset = N_inward · f(d)`, where `d` is the SDF distance and `f` peaks at the silhouette and falls to 0 at the bevel width (about 20–30 pt).
- The interior seems almost flat, with no global magnification. Every reconstruction puts nearly all the displacement in the bevel band, and Apple's controls exposed through reverse-engineering use "edge" terms with a finite reach. Apple's "more pronounced lensing" for larger elements points to a bevel width and amount that grow with element size; Prismal's `minDim·0.085` term does the same thing.
- Because Apple feeds the filter an SDF texture rather than a displacement map, normals and offsets are probably evaluated per pixel on the GPU from distance and gradient. So it works for any shape, including merged blobs.

### Gaps
- The exact profile function `f(d)` inside `glassBackground` (circular, squircle, or something else) and the units of `inputInnerRefractionAmount` (points? pixels? scaled by something?) have not been published. No disassembly of the filter's Metal shader was found.
- I could not fetch the full kube.io article (DNS block), so its numeric bezel widths and the exact sample count of its 1-D precompute are not verified here.

---

## 2. Specular highlights / rim lighting (light direction, gyroscope/tilt response, Fresnel-like edge brightening)

### Takeaway
Officially, virtual lights in an "environment" produce geometry-aware highlights. The lights move on interactions such as lock and unlock, and "in some cases" follow device motion. Reverse-engineering shows the highlights are separate layers, not part of the refraction pass:
- Two `CASDFLayer`s ("@1" and "@2") run a `CASDFGlassHighlightEffect` at opposite angles, with a `vibrantColorMatrix` color filter.
- They take their shape from a portal of the same SDF element.
- `glassBackground` itself has "KeyFill" highlight inputs and shadow inputs.

### Cited Findings
**APPLE (official)**
- Apple: "Light sources inside of this environment shine on the material producing highlights that respond to geometry … On interactions, such as locking and unlocking your phone, these lights move in space, causing light to travel around the material, defining its silhouette … in some cases, the lighting responds to device motion." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)
- Touch response, also from Apple: "the material illuminates from within as a form of feedback … Starting right under your fingertips, the glow spreads throughout the element and onto any Liquid Glass elements nearby." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)

**RE (reverse-engineered)**
- Highlight layer tree: `CASDFLayer "@1"` and `"@2"` "add edge highlights at opposite angles, using `CASDFGlassHighlightEffect` and the `vibrantColorMatrix` filter."
  - `SDFPortalLayer`, a `CAPortalLayer` variant, mirrors the `CASDFElementLayer` into both highlight layers.
  - `vibrantColorMatrix` "applies a custom 4×5 color matrix to the highlight output." — [ShatteredGlass](https://github.com/AlexStrNik/ShatteredGlass)
- Highlight and shadow keys on `glassBackground` that LiquidGlassFallback zeroes **[snippet]**: `inputKeyFillHighlightAmount`, `inputKeyFillHighlightSpread`, `inputKeyFillHighlightHeight`, `inputKeyFillHighlightEffectOffset`, `inputKeyFillHighlightColorBias`, `inputShadowAmount` and `inputShadowHeight`. — [LiquidGlassFallback](https://github.com/AotianNeo/LiquidGlassFallback)
  - "Key/fill" is standard lighting vocabulary for a primary key light plus a weaker fill light.
- The Habr write-up and others name `CASDFGlassHighlightEffect` and `vibrantColorMatrix` for the highlights. **[snippet]** — [habr.com/ru/post/978924](https://habr.com/ru/post/978924)

**RECON (third-party reconstructions)**
- Prismal lights the glass with two Blinn-Phong lights:
  - Key light `Lp = normalize(lightDir, 1.45)`, plus a fill light that is a partly negated, offset copy of it.
  - `spec = pow(N·Hp, shininess)·specular·1.05 + pow(N·Hs, shininess·0.68)·specular·0.48`, gated by `0.32 + 0.68·height` and tinted `(0.99, 0.993, 1.0)`.
  - Rim terms: `FedgeRim = (1 - cosVN)^3.25`; `rimBothBorders = |N_grad·L|`, which lights both the lit edge and the opposite edge; `rimLitSide = max(0, N_grad·L)^1.3`.
  - Schlick Fresnel `F = r0 + (1-r0)(1-cosV)^5` with `r0 = ((1-IOR)/(1+IOR))² ≈ 0.043` at IOR 1.52, "artificially boosted near the silhouette." — [Prismal TECHNICAL.md](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md)
- The Codrops Three.js/TSL grid builds its rim light from a smoothstep on the SDF distance, "a thin band that hugs the edge of the card." **[snippet]** — [Codrops, "Building an Infinite Liquid Glass Grid"](https://tympanus.net/codrops/2026/09/08/building-an-infinite-liquid-glass-grid-with-three-js-webgpu-and-tsl/)
- Liquid Glass Studio (iyinchao) exposes "glare with a customizable angle" with hardness, color and size controls. — [liquid-glass-studio README](https://raw.githubusercontent.com/iyinchao/liquid-glass-studio/main/README.md)

### Inferences
- The pair of highlight layers at "opposite angles" matches the look on device: a bright arc on one corner or edge (key) and a weaker arc diagonally opposite (fill). Prismal's `|N·L|` term reproduces exactly this two-sided rim.
- A shader version (my synthesis):
  ```
  rim = band(d, 0..w_rim) · ( a_key·max(0, dot(N2, L))^p + a_fill·max(0, dot(N2, -L))^p )
  ```
  where N2 is the SDF gradient, L is a 2-D light direction rotated by device tilt or an animated angle, and `band` is a smoothstep window about 1–3 px inside the edge.
- Add it after refraction, through a colour matrix: brighten and desaturate, roughly the 4×5 `vibrantColorMatrix`.

### Gaps
- No source gives `CASDFGlassHighlightEffect`'s parameters (angle, width, falloff) or default values.
- No source shows the exact gyroscope→light-angle mapping or which elements use device motion (Apple says only "in some cases").

---

## 3. Chromatic aberration, blur (and how it combines with refraction), adaptive tint/luminance/shadow, saturation

### Takeaway
`glassBackground` has an explicit `inputAberrationAmount` (dispersion) and an `inputBlurRadius`. Per ShatteredGlass, the same filter also does vibrancy (saturation) and tone mapping. Apple officially describes:
- Content-adaptive shadow opacity.
- Small elements flipping between light and dark; large ones do not.
- Tint mapped to the brightness of the content underneath.

Reconstructions apply dispersion only near the edge, sample a pre-blurred copy of the backdrop at the refracted UV, and raise saturation by about 1.3–1.4×.

### Cited Findings
**RE (reverse-engineered)**
- `glassBackground` does "refraction, blur, vibrancy, and tone mapping" in a single filter. — [ShatteredGlass](https://github.com/AlexStrNik/ShatteredGlass)
- `inputAberrationAmount` is a refraction-related key. The fallback project sets blur through `inputBlurRadius = 25.0`, its "pure frosted glass" replacement value, not Apple's stock value. **[snippet]** — [LiquidGlassFallback](https://github.com/AotianNeo/LiquidGlassFallback)
- The islet app sets "face white 0.8" to keep its white content readable, which implies a face whiteness/tint input. Its "Transparent" mode instead uses "`CABackdropLayer` with `CAFilter` blur, brightness and saturation." — [islet PR #22](https://github.com/ruben4reall/islet/pull/22)

**APPLE (official)**
- Shadow: "The element is aware of what's behind it and increases the opacity of its shadow when it is over text. Conversely, it lowers the opacity of its shadow when it is over a solid light background." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)
- Light/dark: "Small elements like navbars and tabbars … flip from light to dark based on the background … Bigger elements, like menus or sidebars also adapt based on context, but they don't flip." Glyphs on top flip too, "mirroring the glass's behavior to maximize contrast." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)
- Tint: "Selecting a color generates a range of tones that are mapped to content brightness underneath the tinted element … changing its hue, brightness and saturation depending on whats behind without deviating too much from the intended color." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)
- Light spill on large surfaces: "Light from colorful content nearby can subtly spill onto its surface … the light reflects, scatters, and bleeds into the shadow as well." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)
- Variants:
  - Regular is adaptive.
  - Clear "does not have adaptive behaviors. It is permanently more transparent … it needs a dimming layer to darken the underlying content."
  - Reduce Transparency makes it "frostier"; Increase Contrast makes it "predominantly black or white … with a contrasting border." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)

**RECON (third-party reconstructions)**
- Prismal's dispersion samples R, G and B at different UVs along the radial direction (R outward, B inward), with multipliers `u_dispersionR` and `u_dispersionB` (default 1.0).
  - It is gated to the edge by `pow(smoothstep(chromaFar, 0, edgeDist), 1.8)`.
  - Blur is a separable two-pass Gaussian, applied to a captured bitmap. The shader mixes sharp and blurred textures.
  - Vibrancy is `mix(luma, color, 1.28)`, with luma weights (0.213, 0.715, 0.072).
  - Inner shadow is `pow(1 - smoothstep(0, falloff, edgeDist), 2)·0.85·(0.28 + 0.72·height)`. — [Prismal TECHNICAL.md](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md)
- A WebGL library offsets R, G and B "in opposite directions at the edges of the glass element," and only at edge pixels, to save cost. **[snippet]** — [dev.to (maxgeris) WebGL library](https://dev.to/maxgeris/webgl-based-javascript-library-for-pixel-perfect-ios-liquid-glass-effect-with-refractions-and-3p8m)
- liquid-glass-react defaults: `displacementScale 70`, `blurAmount 0.0625`, `saturation 140` (%), `aberrationIntensity 2`, `elasticity 0.15`, `cornerRadius 999`. An `overLight` flag handles light backgrounds. — [rdev/liquid-glass-react README](https://raw.githubusercontent.com/rdev/liquid-glass-react/master/README.md)
- Chris Banes' Android Haze library has a PR titled "Pass the sharp backdrop input to the native Glass refraction detail," which suggests a sharp backdrop and a blurred backdrop are fed separately to the refraction pass (title only). — [chrisbanes/haze PR #1700](https://github.com/chrisbanes/haze/pull/1700)

### Inferences
- The order inside one filter is probably:
  1. Refract the UV (per-channel UVs for dispersion).
  2. Sample a blurred backdrop, possibly mixed with a sharp one at the edge.
  3. Apply a saturation/vibrancy colour matrix.
  4. Tone-map toward a target "face white" or tint.
  5. Composite highlights and the shadow.
- Blur and refraction are combined by sampling the blurred texture at the displaced coordinate, not by blurring after displacement. That is cheaper and keeps edge distortion sharp.
- Adaptive behavior (shadow opacity, light/dark flip, tint tone mapping) needs a luminance statistic of the backdrop under the element, such as an average over a heavily downsampled or mip-mapped backdrop. That reading is mine; no source has confirmed the mechanism.

### Gaps
- Apple's stock values for `inputBlurRadius`, `inputAberrationAmount` and the saturation factor were not found. The 25.0 blur is a third-party replacement value.
- The hysteresis and thresholds for the light/dark flip, and how luminance is measured, are undocumented.

---

## 4. Morphing/merging of multiple glass shapes (smooth-min / metaball SDF blending)

### Takeaway
Apple's architecture is SDF-native: `CASDFElementLayer` elements are rendered into an SDF texture by `CASDFOutputEffect`. That makes it natural for several elements in a container to union smoothly into one field, which gives the "gel-like" merging. Reconstructions use Inigo Quilez's polynomial smooth-min.

### Cited Findings
- **APPLE.** Apple describes "an inherent gel-like flexibility," and says glass "dynamically morphs between the controls in each context." — [WWDC25 session 219](https://developer.apple.com/videos/play/wwdc2025/219/)
- **RE.** Shapes are `CASDFElementLayer`s grouped under a `CASDFLayer`, whose `CASDFOutputEffect` "converts shape layers into SDF textures compatible with the backdrop." — [ShatteredGlass](https://github.com/AlexStrNik/ShatteredGlass)
- **RE.** One analysis (summarized in Fatbobman's Swift Weekly #88, reporting Cyandev's exploration) describes a "backdrop layer with CASDFLayer, plus a glass background filter and generated SDF textures," wrapped in a UIKit-managed container. **[snippet]** — [Fatbobman's Swift Weekly #88](https://fatbobman.com/en/weekly/issue-088/)
- **RECON.** Liquid Glass Studio uses "SDF Defined shapes and smooth merge function," citing Inigo Quilez's 2-D distance functions and smin articles. — [liquid-glass-studio README](https://raw.githubusercontent.com/iyinchao/liquid-glass-studio/main/README.md)
- **RECON.** Prismal's `sdRoundBox` uses a polynomial smooth min/max with blend parameter `k`. — [Prismal TECHNICAL.md](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md)
- **RECON.** Inigo Quilez's standard quadratic smin, widely used for this:
  ```
  float smin(float a, float b, float k){ float h = max(k - abs(a-b), 0.0)/k; return min(a,b) - h*h*k*0.25; }
  ```
  Source: [Inigo Quilez, smooth minimum](https://iquilezles.org/articles/smin/)

### Inferences
- In the public API, a `GlassEffectContainer` (SwiftUI) or `UIGlassContainerEffect` probably maps to one `CASDFLayer` holding several `CASDFElementLayer`s, so all of them share one field, one refraction pass and one highlight pass. This is my inference from the RE layer tree; the merge function itself (smin, or a blur-and-threshold SDF) is not confirmed.
- To build it, compute `d = smin(sdA, sdB, k)` with k ≈ 10–20 px (my suggestion, not a measured value). Use `d` and its gradient for both refraction and the rim.

### Gaps
- Apple's merge kernel and its blend radius are not public or reverse-engineered in any source found.

---

## 5. Backdrop capture in Apple's compositor (CABackdropLayer, CAFilter types, private names), resolution/downsampling, performance tricks

### Takeaway
Liquid Glass runs inside the render server (backboardd/WindowServer) as a `CABackdropLayer`. It grabs already-composited content beneath it and applies the private `CAFilter` `glassBackground`, sourcing the SDF from a sublayer named "@0". Highlights are separate `CASDFLayer`s using `CASDFGlassHighlightEffect` and `vibrantColorMatrix`. Apps never see the pixels, which is why test tools and screen capture misbehave. No source gives the downsampling factor.

### Cited Findings
- **RE.** `CABackdropLayer` is the layer behind `UIVisualEffectView` and `NSVisualEffectView`, and predates Liquid Glass (2018 article). — [avaidyam blog, 2018](https://avaidyam.github.io/blog/2018/02/17/)
- **RE.** Full layer tree, from ShatteredGlass:
  ```
  CustomGlassView (NSView)
   └ SwiftUI.SDFLayer (optional, "hidden delegate logic")
      ├ CABackdropLayer          filters=[glassBackground(inputSourceSublayerName="@0")]
      │   └ CASDFLayer "@0"      effect=CASDFOutputEffect → CALayer → CASDFElementLayer (shape)
      ├ CASDFLayer "@1"          effect=CASDFGlassHighlightEffect, filter=vibrantColorMatrix → SDFPortalLayer(src=element)
      └ CASDFLayer "@2"          (same, opposite angle)
  ```
  Status: "Basic `glassBackground` on macOS: partial … filter tuning ongoing"; a "Liquid Lens effect (Slider, Toggle)" is in progress. — [ShatteredGlass](https://github.com/AlexStrNik/ShatteredGlass)
- **RE.** The iOS 26 runtime-header diff found the new filter type `glassBackground`; its parameters can be changed via lldb; swizzling `setFilters` exposes the raw texture. **[snippet]** — [sspai.com/post/100983](https://sspai.com/post/100983)
- **RE / claim.** A Russian article calls the backdrop "direct access to the compositor's render buffer." This is the author's interpretation. **[snippet]** — [habr.com/ru/post/978924](https://habr.com/ru/post/978924)
- **RE.** Third-party apps load these private classes by name at runtime. boring.notch "probes" every private CoreAnimation symbol once and falls back to a solid background if one is missing. islet sets "only the filter and inputs that exist," and reapplies them whenever the island opens or the appearance changes, because macOS may rebuild the glass layers. — [boring.notch PR #1698](https://github.com/TheBoredTeam/boring.notch/pull/1698); [islet PR #22](https://github.com/ruben4reall/islet/pull/22)
- **RE.** LiquidGlassFallback hooks `CAFilter` and `CALayer` `setValue:` methods to force the optical inputs to 0, and intercepts `CASDFLayer` calls to remove highlight overlays on the macOS 27 Dock. **[snippet]** — [LiquidGlassFallback](https://github.com/AotianNeo/LiquidGlassFallback)
- **Side effects (observed).**
  - Detox reports that on iOS 27 a SwiftUI-hosted Liquid Glass backdrop "is treated as an opaque occluder." — [wix/Detox issue #4982](https://github.com/wix/Detox/issues/4982)
  - An Expo repro shows reading CASDFLayer-backed content can yield black samples. — [adaptive-status-bar-glass-repro](https://github.com/dawid-bytys/adaptive-status-bar-glass-repro)
- **RECON.** LiquidGlassKit uses `CABackdropLayer`, with a root-view rendering fallback "for App Store safety." **[snippet]** — [liquidglasskit (docsearch)](https://docsearch.algolia.com/mcp/docs/repo/dnv1ex/liquidglasskit)
- **RECON performance tricks (non-Apple):**
  - Dispersion only at edge pixels. — [dev.to WebGL library](https://dev.to/maxgeris/webgl-based-javascript-library-for-pixel-perfect-ios-liquid-glass-effect-with-refractions-and-3p8m)
  - Sample loops unrolled at compile time. **[snippet]** — [Codrops](https://tympanus.net/codrops/2026/09/08/building-an-infinite-liquid-glass-grid-with-three-js-webgpu-and-tsl/)
  - A separable Gaussian on a captured bitmap. — [Prismal](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md)
  - Multipass Gaussian. — [Liquid Glass Studio](https://raw.githubusercontent.com/iyinchao/liquid-glass-studio/main/README.md)

### Inferences
- Apple's existing `CABackdropLayer` path already supports a downsampled capture and a blur (UIVisualEffectView has done this for years), and `glassBackground` is a newer filter on that path. Capture resolution and blur are therefore probably shared with the older blur materials. This is unverified.
- Feeding a compact SDF texture, rather than per-pixel displacement maps, keeps memory low and lets shapes animate and morph without regenerating images.

### Gaps
- No source found states the backdrop capture scale, mip usage, or a GPU cost per glass element.
- No class dump listing every `glassBackground` input with types and defaults was retrievable. The GlassExplorer project mentioned in the sspai article could not be found by search.

---

## 6. Concrete numbers measured or reverse-engineered

### Takeaway
Few hard numbers exist. Most come from apps that read or override the private filter, and the rest from reconstruction defaults that were tuned by eye.

### Cited Findings
| Quantity | Value | Kind / who | Source |
|---|---|---|---|
| `inputInnerRefractionAmount` (Control Center, stock) | -80 | RE, LiquidGlassFallback [snippet] | [link](https://github.com/AotianNeo/LiquidGlassFallback) |
| `inputOuterRefractionAmount` (Control Center, stock) | 9.996 | RE, LiquidGlassFallback [snippet] | [link](https://github.com/AotianNeo/LiquidGlassFallback) |
| Inner refraction / reach chosen by islet | -110 over 30 pt; blur 0; refraction opacity 1; face white 0.8 | RE override, islet | [link](https://github.com/ruben4reall/islet/pull/22) |
| `inputBlurRadius` (replacement "frosted" value) | 25.0 | Override, LiquidGlassFallback [snippet] | [link](https://github.com/AotianNeo/LiquidGlassFallback) |
| boring.notch defaults | Refraction 24 (0–100), Blur 0.5 (0–30), Dispersion 4 (0–15), Lens height 23 pt (10–60) | UI over private stack | [link](https://github.com/TheBoredTeam/boring.notch/pull/1698) |
| IOR used in reconstructions | 1.5 (kube.io-derived); 1.3–1.9, typically 1.52 (Prismal) | RECON | [kube.io](https://kube.io/blog/liquid-glass-css-svg/), [PecoFence PR #9](https://github.com/DayuanJiang/PecoFence/pull/9), [Prismal](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md) |
| Glass thickness | 18 dp for large cards, 5 dp for icon buttons (52 dp circle); keep ≤ 0.35·min(w,h)/2 | RECON, Prismal | [link](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md) |
| Fresnel r0 at IOR 1.52 | ≈ 0.043 | RECON, Prismal | [link](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md) |
| Saturation / vibrancy | 1.28 (Prismal); 140% (liquid-glass-react) | RECON | [Prismal](https://raw.githubusercontent.com/styropyr0/Prismal/master/TECHNICAL.md), [liquid-glass-react](https://raw.githubusercontent.com/rdev/liquid-glass-react/master/README.md) |
| liquid-glass-react defaults | displacementScale 70, blurAmount 0.0625, aberrationIntensity 2, cornerRadius 999 | RECON | [link](https://raw.githubusercontent.com/rdev/liquid-glass-react/master/README.md) |
| Bezel constraint | corner radius ≥ bezel width | RECON (kube.io-derived) | [PecoFence PR #9](https://github.com/DayuanJiang/PecoFence/pull/9) |

### Inferences
- The two independent sources agree on scale: an inner refraction of about 80–110 units over a band of about 23–30 pt. That points to an edge lens band of roughly 20–30 pt and a peak displacement of tens of points at the silhouette.
- Suggested starting parameters for a fragment shader (my synthesis; tune by eye):
  - Bevel width w ≈ 24 pt (scale with element size).
  - Peak inward displacement ≈ 0.3–0.5·w.
  - Blur sigma ≈ 2–8 pt for "regular", near 0 for "clear".
  - Dispersion ≈ 1–4 px at the edge only.
  - Saturation ≈ 1.3–1.4.
  - Two-sided rim highlight about 1–2 px wide, key ≈ 0.6–0.8, fill ≈ 0.3.
- A minimal shader skeleton based on the sources above:
  ```glsl
  float d   = sdSuperellipseOrRoundRect(p, size, radius);   // <0 inside
  vec2  N   = normalize(gradient(d));                        // outward 2-D normal
  float x   = clamp(-d / bevelW, 0., 1.);                    // 0 at edge -> 1 at bevel end
  float h   = pow(1. - pow(1. - x, 4.), 0.25);               // convex squircle bezel (kube.io)
  float dh  = dHeight_dx(x);                                 // slope -> refraction strength
  vec3  r   = refract(vec3(0,0,-1), normalize(vec3(-N*dh, 1.)), 1./1.5);
  vec2  off = r.xy * thickness / max(-r.z, 1e-3);            // inward pull at the rim
  vec3 col; col.r = texture(blurredBg, uv + off*(1.+disp)).r;
              col.g = texture(blurredBg, uv + off).g;
              col.b = texture(blurredBg, uv + off*(1.-disp)).b;  // edge-gated dispersion
  col = mix(vec3(luma(col)), col, 1.3);                      // vibrancy
  col += rimBand(d) * (kKey*max(0.,dot(N,L)) + kFill*max(0.,dot(N,-L)));  // two opposite highlights
  ```

### Gaps
- Apple's stock values for most `glassBackground` keys (blur radius, aberration, highlight amount/spread/height, shadow amount/height) were not found.
- No one has published measurements from pixel analysis of screenshots, such as fitting bevel width or peak displacement from images.
- Corner shape: Apple's continuous-corner (squircle-like) rounded rect is assumed by reconstructions; no source here measured it for Liquid Glass specifically.
