# Apple's Official Description of Liquid Glass (WWDC25 to November 2026)

Method note: developer.apple.com pages were read directly. API reference and HIG pages were pulled as DocC JSON from `developer.apple.com/tutorials/data/...` and rendered locally; the citations below link the human-facing URLs. www.apple.com (Newsroom, iOS product page) and macrumors.com were blocked in this research environment. Claims from those sites rely on search-engine summaries and are marked "(via search summary)". The current Apple reference docs carry WWDC26 (June 2026) and September 2026 change-log entries, so they reflect the iOS/macOS 27 SDK era.

---

## 1. How Apple's WWDC25 sessions describe the material (optics, adaptivity, variants, motion, layering)

### Takeaway
Apple describes Liquid Glass as a "digital meta-material" whose main visual signature is real-time lensing: it bends and concentrates light rather than scattering it, so it is not only a blur. On top of that it adds geometry-aware specular highlights, shadows that react to the background, automatic light/dark flipping for small elements, thickness that scales with size, gel-like interactive response and morphing between shapes. Apple says it belongs only on the floating navigation/control layer, never in content and never stacked glass-on-glass. There are two variants that must not be mixed: Regular (adaptive) and Clear (permanently more transparent, needs a dimming layer).

### Cited Findings
**Optics: lensing, refraction, blur**
- "Lensing" is "the primary way Liquid Glass visually defines itself." In Apple's words: "Where as previous materials scattered light, this new set of materials dynamically bends, shapes, and concentrates light in real time." Also: "rather than trying to simply recreate a material from the physical world, Liquid Glass is a new digital meta-material that dynamically bends and shapes light." — [WWDC25 "Meet Liquid Glass" (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- The developer docs nonetheless include blur: "Liquid Glass is a material that blurs content behind it, reflects color and light of surrounding content, and reacts to touch and pointer interactions in real time." — [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- HIG: "The regular variant blurs and adjusts the luminosity of background content to maintain legibility of text and other foreground elements." — [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- Sampling model, which matters for reproduction: "The glass material reflects and refracts lights, picking colors from nearby content. This effect is achieved by sampling content from an area larger than itself. However, glass can not sample other glass…" — [WWDC25 "Build a SwiftUI app with the new design" (323)](https://developer.apple.com/videos/play/wwdc2025/323/). AppKit repeats this: "the glass material samples content from an area larger than itself… glass can't directly sample other glass" — [WWDC25 "Build an AppKit app with the new design" (310)](https://developer.apple.com/videos/play/wwdc2025/310/)
- Press release (June 9, 2025): Liquid Glass is "translucent," "behaves like glass in the real world," and "reflects and refracts its surroundings." Its "color is informed by surrounding content and intelligently adapts between light and dark environments." — [Apple Newsroom, "Apple introduces a delightful and elegant new software design"](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/) (via search summary)

**Specular highlights and motion**
- "Light sources inside of this environment shine on the material producing highlights that respond to geometry just as you'd expect." During lock/unlock, "these lights move in space, causing light to travel around the material, defining its silhouette." Also: "in some cases, the lighting responds to device motion, making it feel like Liquid Glass is aware of its position in the real world." — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/). The session says "device motion" and never uses the word "tilt."

**Adaptive shadows, tint and dynamic range**
- "The element is aware of what's behind it and increases the opacity of its shadow when it is over text… lowers the opacity of its shadow when it is over a solid light background." Also: "The amount of tint and the dynamic range shift to always ensure buttons remain legible, while letting as much of the content through as possible." — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- Tinting "maps a range of tones… to content brightness underneath" (it is not a flat color overlay). Apple's guidance: "Tinting should only be used to bring emphasis to primary elements and actions." — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- UIKit: "Tinted glass color, automatically adapts to a vibrant version." Content placed in the contentView "automatically becomes vibrant, based on its textColor." — [WWDC25 "Build a UIKit app with the new design" (284)](https://developer.apple.com/videos/play/wwdc2025/284/)

**Light/dark adaptation and size dependence**
- Small elements such as nav bars and tab bars "flip from light to dark based on the background." Larger elements such as menus and sidebars "adapt based on context, but they don't flip from light to dark" because that "would be distracting." Symbols and glyphs mirror the flip, and "All content placed on the Regular variant will automatically receive this treatment." — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- "Glass adapts the appearance based on its size. A larger size is more opaque. A smaller size is clearer, and switches between light and dark mode automatically, to increase contrast." — [UIKit session (284)](https://developer.apple.com/videos/play/wwdc2025/284/)
- Larger glass simulates thicker material: "It casts deeper, richer shadows, has more pronounced lensing and refraction effects, and a softer scattering of light." On big surfaces such as sidebars, "Light from colorful content nearby can subtly spill onto its surface." — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)

**Regular vs Clear**
- Two variants that "should never be mixed." Regular is "the most versatile… works in any size, over any content." Clear "does not have adaptive behaviors. It is permanently more transparent" and "needs a dimming layer… Without it, legibility gets noticeably worse." Use Clear only when all three hold: the element is over media-rich content, the content layer tolerates a dimming layer, and the content on top is bold and bright. — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- HIG: "If the underlying content is bright, consider adding a dark dimming layer of 35% opacity." No dimming is needed if the content is already dark or if AVKit controls supply their own. — [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- API doc example dimming: `.glassEffect(.clear).background(.black.opacity(0.3))`, i.e. 30% in code versus the HIG's 35%. — [Glass.clear](https://developer.apple.com/documentation/swiftui/glass/clear)

**Morphing, materialize, interaction**
- "Liquid Glass dynamically morphs between the controls in each context… a singular floating plane." Also: "Instead of fading, Liquid Glass objects materialize in and out by gradually modulating the light bending and lensing." — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- Touch: "instantly flexing and energizing with light," with "an inherent gel-like flexibility." The glow starts "right under your fingertips… spreads throughout the element and onto any Liquid Glass elements nearby." When a Mac or iPad window loses focus, the glass "visually recedes." — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- Interactive glass "reacts to user interaction by scaling, bouncing, and shimmering." — [SwiftUI session (323)](https://developer.apple.com/videos/play/wwdc2025/323/)
- Merging in UIKit: "As long as there is space between them, they appear as two separate views. Only if they get closer, they start merging like small droplets of water." — [UIKit session (284)](https://developer.apple.com/videos/play/wwdc2025/284/)

**Scroll edge effects**
- **Soft (default):** "gently dissolves the content into the background." When darker content scrolls under, it "intelligently switches to apply a subtle dimming instead."
- **Hard:** applied "uniformly across the height of the toolbar and the pinned accessory view."
- Source for both: [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- Scroll edge effects are "not decorative. They don't block or darken like overlays." Soft is the default on iOS/iPadOS; "Hard is mostly used on macOS." Apply "one scroll edge effect per view" and avoid mixing or stacking the two styles. — [WWDC25 "Get to know the new design system" (356)](https://developer.apple.com/videos/play/wwdc2025/356/)
- SwiftUI describes it as "a subtle blur and fade effect applied to content under system toolbars." Remove any custom dark backgrounds behind bar items. — [SwiftUI session (323)](https://developer.apple.com/videos/play/wwdc2025/323/)

**Layering and geometry**
- Glass is "best reserved for the navigation layer that floats above the content." Avoid stacking glass on glass. Content on top of glass should use "fills, transparency, and vibrancy." Avoid intersections between content and glass in steady states. — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- Concentricity: "fixed shapes have a constant corner radius. Capsules use a radius that's half the height of the container. And concentric shapes calculate their radius by subtracting padding from the parent's." Use a concentric shape with a fallback radius for components that appear both nested and standalone. — [Get to know the new design system (356)](https://developer.apple.com/videos/play/wwdc2025/356/)
- Sheets: "when focus shifts, like dragging a sheet upward, Liquid Glass subtly recedes, becoming more opaque and gently growing in size." Interrupting tasks pair glass with a dimming layer. — [Get to know the new design system (356)](https://developer.apple.com/videos/play/wwdc2025/356/)
- Apply glass "directly to the control, not its inner views." — [Get to know the new design system (356)](https://developer.apple.com/videos/play/wwdc2025/356/)

### Inferences
- A faithful recreation outside Apple platforms would combine:
  - edge-weighted refraction or displacement (lensing) sampled from a region larger than the shape;
  - a light blur and luminosity adjustment for Regular;
  - a geometry-following rim or specular highlight;
  - a background-dependent shadow and tint;
  - size-dependent "thickness," where larger shapes get stronger refraction, softer scatter and more opacity;
  - SDF-style merging (smooth-union) of nearby shapes within a spacing threshold.
- Apple's "droplet" and "union" language fits a smooth-min blend of shape fields. Apple never names the algorithm.

### Gaps
- Apple publishes no refraction index, blur radius, highlight intensity, shadow parameters or merge formula. Every numeric value has to be found empirically. The only official numbers are the 35% (HIG) and 30% (code sample) dimming layers.
- No official Apple page found using the word "tilt" or "gyroscope." The official wording is "device motion."

---

## 2. Public APIs and their documented parameters and behaviors

### Takeaway
SwiftUI uses `glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape())`, with a capsule as the default shape. `Glass` has `.regular`, `.clear` and `.identity`, plus the chainable `.tint(Color?)` and `.interactive(Bool = true)`. Multiple glass shapes go in `GlassEffectContainer(spacing:)`. Morphing uses `glassEffectID`, merging at rest uses `glassEffectUnion`, and transitions use `glassEffectTransition` (`.matchedGeometry`, `.materialize`, `.identity`). UIKit uses `UIGlassEffect(style: .regular/.clear)` with `tintColor` and `isInteractive`, inside `UIVisualEffectView`, and `UIGlassContainerEffect.spacing`. AppKit uses `NSGlassEffectView` (`contentView`, `cornerRadius`, `tintColor`, `style`, `effectIsInteractive`) and `NSGlassEffectContainerView` (`contentView`, `spacing`). All are available from the 26.0 OS releases.

### Cited Findings
**SwiftUI**
- Declaration: `nonisolated func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View`. The system "Renders a shape anchored behind a view with the Liquid Glass material" and "Applies the foreground effects of Liquid Glass over a view." The default is `regular` in a `Capsule`, anchored to the view's bounds including padding. Available on iOS, iPadOS, Mac Catalyst, macOS, tvOS and watchOS 26.0. visionOS is not listed. — [glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- `struct Glass` members:
  - `regular`: "The regular variant of the Liquid Glass material."
  - `clear`: "The clear variant of glass."
  - `identity`: "your content remains unaffected as if no glass effect was applied."
  - `tint(_ color: Color?) -> Glass`
  - `interactive(_ isEnabled: Bool = true) -> Glass`
  - Sources: [Glass](https://developer.apple.com/documentation/swiftui/glass), [tint(_:)](https://developer.apple.com/documentation/swiftui/glass/tint(_:)), [interactive(_:)](https://developer.apple.com/documentation/swiftui/glass/interactive(_:)), [identity](https://developer.apple.com/documentation/swiftui/glass/identity)
- Doc samples: `.glassEffect(in: .rect(cornerRadius: 16.0))` and `.glassEffect(.regular.tint(.orange).interactive())`. "Apply the `glassEffect(_:in:)` modifier after other modifiers that affect the appearance of the view" (it captures the content). — [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- `GlassEffectContainer` "combines multiple Liquid Glass shapes into a single shape that can morph individual shapes into one another… SwiftUI renders the effects together, improving rendering performance." Also: "The higher the spacing, the sooner blending begins as the shapes approach each other." — [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- Spacing rule: "A spacing value on the container that's larger than the spacing of an interior HStack… causes Liquid Glass effects to blend together at rest." The example uses `GlassEffectContainer(spacing: 40.0)` with `HStack(spacing: 40.0)` and 80×80 symbols. The eraser morphs into the pencil "when the eraser's nearest edge is less than or equal to the container's spacing." — [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- `glassEffectUnion(id: (some Hashable & Sendable)?, namespace: Namespace.ID)`: "All Liquid Glass effects with the same shape and Liquid Glass variant will be combined into a single shape." — [glassEffectUnion(id:namespace:)](https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:))
- `GlassEffectTransition` has three values:
  - `.matchedGeometry`: the default when a shape is within the container spacing.
  - `.materialize`: "will fade in content and animate in or out the glass material but will not attempt to match the geometry," used for shapes farther apart than the spacing.
  - `.identity`
  - Apple notes: "The system applies more than opacity changes with the available transition types."
  - Sources: [GlassEffectTransition](https://developer.apple.com/documentation/swiftui/glasseffecttransition), [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- Button styles: `.buttonStyle(.glass)` ("applies a Liquid Glass effect based on the button's context"; on tvOS it applies the effect "regardless of whether the button has focus") and `.buttonStyle(.glassProminent)`. — [PrimitiveButtonStyle.glass](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass), [GlassButtonStyle](https://developer.apple.com/documentation/swiftui/glassbuttonstyle), [SwiftUI session (323)](https://developer.apple.com/videos/play/wwdc2025/323/)
- Related SwiftUI APIs:
  - `scrollEdgeEffectStyle(.hard, for: .top)`
  - `backgroundExtensionEffect()` ("mirrored and blurred outside of the safe area")
  - `ToolbarSpacer(.fixed/.flexible)`
  - `.sharedBackgroundVisibility(.hidden)`
  - `tabBarMinimizeBehavior(.onScrollDown)`
  - `tabViewBottomAccessory`
  - `.rect(corner: .containerConcentric)`
  - Source: [SwiftUI session (323)](https://developer.apple.com/videos/play/wwdc2025/323/)

**UIKit**
- `UIGlassEffect` ("A visual effect that renders a glass material") has `init(style: UIGlassEffect.Style)` with `.regular` or `.clear`, plus `isInteractive` and `tintColor`. Available on iOS, iPadOS, Mac Catalyst and tvOS 26.0. — [UIGlassEffect](https://developer.apple.com/documentation/uikit/uiglasseffect), [UIGlassEffect.Style](https://developer.apple.com/documentation/uikit/uiglasseffect/style)
- `UIGlassContainerEffect` "renders multiple glass elements into a combined effect… behind the visual effect view's contentView." `spacing` is "the distance between elements at which they begin to merge." — [UIGlassContainerEffect](https://developer.apple.com/documentation/uikit/uiglasscontainereffect)
- Usage:
  - Set `effectView.effect = glassEffect` inside `UIView.animate` to get the "materialize animation," and set it to `nil` to dematerialize.
  - "Always prefer setting the effect property over the alpha."
  - The default shape is a capsule. Use `cornerConfiguration = .fixed(8)` or `.containerRelative()`.
  - Sample: `containerEffect.spacing = 20`.
  - Source: [UIKit session (284)](https://developer.apple.com/videos/play/wwdc2025/284/)
- Other UIKit APIs:
  - `UIScrollEdgeEffect` (`style`, `isHidden`), e.g. `scrollView.topEdgeEffect.style = .hard`
  - `UIScrollEdgeElementContainerInteraction` for custom overlays
  - `UIBackgroundExtensionView`
  - `UIButton.Configuration.glass()` and `prominentGlass()`
  - Sources: [UIScrollEdgeEffect](https://developer.apple.com/documentation/uikit/uiscrolledgeeffect), [UIKit updates](https://developer.apple.com/documentation/updates/uikit), [UIKit session (284)](https://developer.apple.com/videos/play/wwdc2025/284/)

**AppKit (macOS 26.0)**
- `NSGlassEffectView` ("embeds its content view in a dynamic glass effect") has `contentView`, `cornerRadius`, `effectIsInteractive`, `style` (`.regular` / `.clear`) and `tintColor` ("The color the glass effect view uses to tint the background and glass effect toward"). — [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview), [NSGlassEffectView.Style](https://developer.apple.com/documentation/appkit/nsglasseffectview/style-swift.enum)
- `NSGlassEffectContainerView` "efficiently merges descendant glass effect views together when they are within a specified proximity." It has `contentView` and `spacing`. Tip: it "can improve performance by reducing the number of passes required to render similar glass effect views." — [NSGlassEffectContainerView](https://developer.apple.com/documentation/appkit/nsglasseffectcontainerview)
- Session guidance:
  - Put content in `contentView`, not behind the glass as a sibling view.
  - The sample uses `cornerRadius = 999` to get a capsule.
  - Other glass-related AppKit APIs: `NSToolbarItem.style = .prominent`, `backgroundTintColor`, the glass bezel style with `bezelColor`, `tintProminence`, `NSBackgroundExtensionView`.
  - Source: [AppKit session (310)](https://developer.apple.com/videos/play/wwdc2025/310/)

**Opting out**
- `UIDesignRequiresCompatibility` was the Info.plist key that kept the old look when building with the 26 SDKs. — [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- At WWDC26 Apple said: "We'll be removing support for opting to use the old design… once your app is recompiled with Xcode 27, it will automatically begin to use the new design." — [WWDC26 Platforms State of the Union](https://developer.apple.com/videos/play/wwdc2026/102/)

### Inferences
- The same model (glass shape + container + spacing threshold + materialize/matched-geometry transitions) runs across all three frameworks. A cross-platform reproduction can use one parameter set: variant, tint, interactive, corner shape and container spacing.
- `cornerRadius = 999` in AppKit and capsule defaults elsewhere show that capsules are the canonical shape.

### Gaps
- No public API exposes refraction strength, blur radius or highlight intensity. Apple exposes only the variant, tint and interactivity.
- The default `spacing` values of the containers are not documented.
- The June 2026 SwiftUI and UIKit update logs list no new `Glass` members or glass-specific APIs for the 27 SDKs. The current `Glass` page still lists only regular/clear/identity/tint/interactive. — [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui), [Glass](https://developer.apple.com/documentation/swiftui/glass)

---

## 3. Human Interface Guidelines: when and how to use the material

### Takeaway
The HIG treats Liquid Glass as a separate functional layer for controls and navigation, with standard materials (ultraThin through thick) for the content layer. Use glass sparingly. Choose Clear only over visually rich media, with a 35% dimming layer when the background is bright. Regular is for text-heavy components such as alerts, sidebars and popovers.

### Cited Findings
- "Don't use Liquid Glass in the content layer… use Standard materials for elements in the content layer." Exception: transient controls such as sliders and toggles take on glass "when a person activates it." — [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- "Use Liquid Glass effects sparingly… Limit these effects to the most important functional elements in your app." — [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- Variant guidance:
  - Use Regular "when background content might create legibility issues, or when components have a significant amount of text, such as alerts, sidebars, or popovers."
  - Clear is "highly translucent… for components that float above media backgrounds — such as photos and videos."
  - "Scroll edge effects further enhance legibility by blurring and reducing the opacity of background content."
  - Source: [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- visionOS windows use a separate, "unmodifiable system-defined material called glass" that "limits the range of background color information." visionOS has no Dark Mode; glass "automatically adapts to the luminance of the objects and colors behind it." — [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- tvOS: Liquid Glass appears in navigation, Top Shelf and Control Center, and "image views and buttons, adopt Liquid Glass when they gain focus." — [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- HIG Materials change log: "June 9, 2025 — Added guidance for Liquid Glass" and "September 9, 2025 — Updated guidance for Liquid Glass." No later Liquid Glass entry appears on the page as fetched in November 2026. — [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- Color and contrast: if you color controls, use system colors or custom colors with light and dark variants "and an increased contrast option for each variant." Avoid "layering Liquid Glass elements on top of each other." — [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- System colors were "adjusted… across Light, Dark and Increased Contrast appearances, so that they work in harmony with Liquid Glass." — [Get to know the new design system (356)](https://developer.apple.com/videos/play/wwdc2025/356/)
- Sizing: macOS Mini, Small and Medium controls keep rounded rectangles. Large controls use capsules, and a new X-Large size "takes advantage of Liquid Glass to provide emphasis." — [Get to know the new design system (356)](https://developer.apple.com/videos/play/wwdc2025/356/)
- Sheets: half sheets are inset from the display edge, and "When a half sheet expands to full height, it transitions to a more opaque appearance." — [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)

### Inferences
- For a web or other recreation, the HIG supports: glass only on floating chrome; a 35% black scrim under Clear over bright media; a progressive blur-and-fade "scroll edge" under bars; and higher opacity for large or text-heavy panels.

### Gaps
- The HIG gives no numeric contrast ratios or minimum sizes for glass. The "Liquid Glass color" section linked from Materials was not separately retrieved.

---

## 4. Post-launch changes (betas through November 2026) and accessibility behavior

### Takeaway
Accessibility settings modify glass automatically:
- Reduce Transparency makes it frostier.
- Increase Contrast makes it mostly black or white with a contrasting border.
- Reduce Motion lowers effect intensity and turns off the elastic behavior.

After launch, user controls were added in stages:
- **iOS/iPadOS/macOS 26.1:** a Clear vs Tinted choice (first seen in beta 4, October 2025).
- **iOS 26.2:** a Liquid Glass opacity slider for the Lock Screen clock (beta in November 2025, release in December 2025).
- **27 releases (WWDC26, June 2026):** Apple re-tuned the material itself, with better diffusion of complex content, a darkened edge and brighter specular highlights. A systemwide slider runs "from ultra clear to fully tinted." Apple also removed the opt-out for apps rebuilt with Xcode 27.

### Cited Findings
**Accessibility (official)**
- "Reduced Transparency makes Liquid Glass frostier and obscures more of the content behind it." "Increased Contrast makes elements predominantly black or white and highlights them with a contrasting border." "Reduced Motion decreases the intensity of some effects and disables any elastic properties for the material." These apply automatically "whenever you use the new material." — [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219/)
- "people can choose a preferred look for Liquid Glass in their device's settings, or turn on accessibility settings that reduce transparency or motion… These settings can remove or modify certain effects." — [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- WWDC26: "Liquid Glass seamlessly adapts to a variety of accessibility settings… such as reducing transparency or increasing contrast." Also: "macOS 27 also supports the 'show borders' environment value, just like iOS." — [WWDC26 Platforms State of the Union](https://developer.apple.com/videos/play/wwdc2026/102/)

**26.1 Clear/Tinted (October–November 2025)**
- Added in iOS 26.1, iPadOS 26.1 and macOS 26.1 beta 4. It lives at Settings > Display & Brightness > Liquid Glass on iPhone and under Appearance on Mac. Apple's in-settings wording: "Clear is more transparent, revealing the content beneath" and "Tinted increases opacity and adds more contrast." It applies across the OS, including apps and Lock Screen notifications, and is independent of Light/Dark mode. — [MacRumors, Oct 20 2025](https://www.macrumors.com/2025/10/20/ios-26-1-liquid-glass-toggle/); [TechCrunch, Oct 20 2025](https://techcrunch.com/2025/10/20/apple-will-let-users-roll-back-the-liquid-glass-look-with-new-tinted-option); [Engadget](https://www.engadget.com/mobile/smartphones/how-to-adjust-the-liquid-glass-effect-in-ios-261-203634681.html) (via search summaries)

**26.2 Lock Screen clock slider (November–December 2025)**
- iOS 26.2 beta 1 (around Nov 4, 2025) added a slider for the Liquid Glass Lock Screen clock, from nearly fully clear to more opaque. It is shown when the "Glass" clock style is selected, and a separate "Solid" option still exists. It affects the clock only and shipped publicly in December 2025. — [MacRumors, Nov 4 2025](https://www.macrumors.com/2025/11/04/ios-26-2-liquid-glass-slider/); [9to5Mac](https://9to5mac.com/2025/11/04/ios-26-2-adds-liquid-glass-slider-to-customize-your-lock-screen/); [TechCrunch, Dec 12 2025](https://techcrunch.com/2025/12/12/with-ios-26-2-apple-lets-you-roll-back-liquid-glass-again-this-time-on-the-lock-screen/) (via search summaries)

**27 releases (WWDC26, June 2026). Official statements:**
- "we tuned Liquid Glass so it more effectively diffuses complex content behind it."
- "to establish more depth and separation, we also introduced a darkened edge along with brighter specular highlights."
- "a new slider in settings to adjust Liquid Glass anywhere from ultra clear to fully tinted."
- "Apps already using Liquid Glass get these improvements automatically… without even needing to recompile."
- Source for the four statements above: [WWDC26 Platforms State of the Union](https://developer.apple.com/videos/play/wwdc2026/102/)
- Sidebars and windows: sidebars "expand to the edges on Mac and iPad… still refracting content from your app and the wallpaper." Sidebar icons regain accent color. All macOS windows get a "tighter corner radius." When content scrolls under floating bars, "a uniform toolbar appears across the top" (customizable through the existing scroll edge effect APIs). — [WWDC26 Platforms State of the Union](https://developer.apple.com/videos/play/wwdc2026/102/)
- Icons: Liquid Glass in icons is "sharper and more defined," with selectively applied "refraction," and Icon Composer supports "multiple layers of Liquid Glass." — [WWDC26 Platforms State of the Union](https://developer.apple.com/videos/play/wwdc2026/102/)
- SwiftUI on 27:
  - "Liquid Glass has a refined look and automatically responds to the new Liquid Glass slider to adjust its tint."
  - On macOS, custom glass can be marked "interactive" and is "optimized to work great with the mouse pointer."
  - New `toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)` and `Tab(role: .prominent)`.
  - Source: [WWDC26 "What's new in SwiftUI" (269)](https://developer.apple.com/videos/play/wwdc2026/269/), [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui)
- Apple's iOS 27 page and June 2026 Newsroom (via search summary): the update gives better readability through "more even refraction and stronger contrast," and the slider runs "from ultra-clear to fully tinted." — [apple.com/os/ios](https://www.apple.com/os/ios/); [Apple Newsroom, June 2026](https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/); [About iOS 27 Updates](https://support.apple.com/en-us/149076)
- Third-party beta reporting (secondary, via search summary):
  - The iOS 27 slider sits in Settings → Appearance → Liquid Glass, with Apple's default at the midpoint.
  - Beta 5 made the most transparent end even more transparent.
  - The gyroscope-driven specular highlight from iOS 26 "appears to have been removed" in iOS 27 beta 1.
  - Sources: [MacRumors, June 10 2026](https://macrumors.com/2026/06/10/how-liquid-glass-is-changing-in-ios-27); [9to5Mac, June 15 2026](https://9to5mac.com/2026/06/15/ios-27-adds-new-liquid-glass-slider-on-iphone-heres-what-it-lets-you-do/); [9to5Mac, June 12 2026](https://9to5mac.com/2026/06/12/ios-27-fixes-liquid-glass-and-not-just-with-a-slider/); [MacStories iOS 27 review](https://www.macstories.net/stories/ios-and-ipados-27-review/2/). Apple did not confirm the gyroscope removal in any source found.
- September 2026 doc updates add "controls on the vertical axis" (bars placed on the vertical edge) and iPhone Duo hinge APIs. Neither is glass-specific. — [UIKit updates](https://developer.apple.com/documentation/updates/uikit)

### Inferences
- As of November 2026 (27.x), the "current" look has three parts: refined diffusion, a dark rim with a brighter specular edge, and a user-controlled clear↔tinted continuum. That continuum replaces the 26.1 binary toggle. Treat the iOS 26 motion-reactive highlight as possibly superseded.
- A recreation should expose a "tint/opacity" parameter that matches Apple's slider.

### Gaps
- No primary source was retrieved for the iOS 26 beta-period tweaks (for example the frostier and more opaque changes around betas 2 and 3 in summer 2025). Not documented here.
- No official confirmation was found of the exact iOS 27 slider location or default position, or of the reported removal of motion-reactive highlights. These rest on press reporting only.
- No sources were found for 27.1 or 27.2 changes to Liquid Glass through November 2026.
- An official support.apple.com page describing the slider was not retrieved directly.

---

## 5. Performance, battery, and hardware or Metal statements

### Takeaway
Apple's official performance guidance is qualitative: group glass in containers so the effect needs one sampling pass for the whole group, and limit how many glass effects are on screen. The only hardware gate Apple documents is tvOS, where Liquid Glass needs Apple TV 4K (2nd generation) or newer. No official battery figure or Metal-feature statement was found.

### Cited Findings
- "Creating too many Liquid Glass effect containers and applying too many effects to views outside of containers can degrade performance. Limit the use of Liquid Glass effects onscreen at the same time." — [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- A shared container "improves the performance of the glass effect, since it only needs one sampling pass for the entire group." — [AppKit session (310)](https://developer.apple.com/videos/play/wwdc2025/310/)
- `NSGlassEffectContainerView` "can improve performance by reducing the number of passes required to render similar glass effect views." — [NSGlassEffectContainerView](https://developer.apple.com/documentation/appkit/nsglasseffectcontainerview)
- "Apple TV 4K (2nd generation) and newer models support Liquid Glass effects. On older devices, your app maintains its current appearance." watchOS glass changes are "minimal" and appear even without rebuilding. — [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- The UIKit session makes no quantitative performance statements. — [UIKit session (284)](https://developer.apple.com/videos/play/wwdc2025/284/)

### Inferences
- "Sampling pass" wording suggests a backdrop-capture render pass per glass group, so merging glass into one container is the main cost lever. This matters when reproducing the effect with WebGL, Metal or shaders.

### Gaps
- No official Apple statement found on battery impact, GPU or Metal feature requirements, or minimum iPhone/iPad/Mac hardware for Liquid Glass, beyond the tvOS model gate.
