# Validation — 2026-11-19 (glass model v1)

The shader and widget were rewritten to follow `docs/glass-model.md`. The
earlier build looked broken on a real phone because the shader treated the
engine's `uSize` (the whole backdrop texture) as the glass size.

## Executed here

- `flutter analyze`: no issues (Flutter 3.50.0 stable).
- `flutter test test`: 8 tests pass. Covered: tabs and add button, the demo
  smoke test in fallback mode (morph, debug, lens, quality, adaptive, theme,
  drag, opaque), size-derived optics, tone hysteresis, and quality governor
  steps.
- `impellerc` compiles the shader for Vulkan, OpenGL ES (GLSL ES 1.00 and 3.00)
  and Metal.
- **Real Impeller render on Linux desktop** (OpenGL ES backend, Mesa software
  GL, under Xvfb):
  - The status line reports `refractive`.
  - The debug outline matches the glass widgets exactly, and the image is
    not flipped.
  - Edge refraction, merging, dark tone and the over-text case look as
    intended.
  - Screenshots: `evidence/linux-impeller-variants.png` and
    `evidence/linux-impeller-debug.png`.
  - Reproduce with `tool/linux_impeller_preview.sh`.

## Not executed

- A physical Android device:
  - Vulkan and Mali/Adreno drivers.
  - Real frame times.
  - Whether the backdrop texture is global or clip-local on that device. The
    debug corner marker shows this: green means global, orange means
    clip-local.
- Comparison with an iPhone screenshot over the same background; the
  numbers in `docs/glass-model.md` still need eye tuning.

The old host GLSL harness (`tool/verify_shader.py`) and its results tested the
previous uniform layout and were removed.
