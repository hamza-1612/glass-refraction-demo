#version 460 core
#include <flutter/runtime_effect.glsl>

// Liquid-glass backdrop shader. The math follows docs/glass-model.md.
//
// Coordinate contract (see research notes, flutter_recreation.md):
// - uSize is the size of the *backdrop texture*, normally the whole surface,
//   NOT the glass widget. FlutterFragCoord() is in that texture's frame.
// - Some engines crop the input to the clip and count from the clip's corner.
//   We detect that case and convert every fragment to surface pixels.
// - All geometry below is in surface physical pixels, supplied from Dart at
//   paint time.
// Avoid data-dependent ternaries: Mali/Vulkan drivers miscompiled them in a
// similar shader (liquid_glass_renderer #246); use step()/mix() instead.

// Engine-owned: never set from Dart.
uniform vec2 uSize;               // 0-1
uniform vec4 uRectA;              // 2-5   shape A: left, top, width, height
uniform vec4 uRectB;              // 6-9   shape B (width 0 = disabled)
uniform vec4 uShape;              // 10-13 radiusA, radiusB, merge k, aa width
uniform vec4 uOptics;             // 14-17 band h, amount A, blur radius, vibrancy
uniform vec4 uClip;               // 18-21 clip left, top, width, height
uniform vec4 uSurface;            // 22-25 surface w, h, dpr, debug (0/1)
uniform vec4 uTint;               // 26-29 tint rgb, tone (0 light, 1 dark)
uniform vec4 uLight;              // 30-33 light dir x, y, key, fill
uniform vec4 uMisc;               // 34-37 dispersion, adaptive, blur taps, lens sign
uniform sampler2D uBackdrop;      // engine-owned

out vec4 fragColor;

const float GOLDEN_ANGLE = 2.39996323;
const int MAX_TAPS = 24;

vec2 gOrigin = vec2(0.0);

float luma(vec3 c) { return dot(c, vec3(0.213, 0.715, 0.072)); }

float sdRoundRect(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Inigo Quilez quadratic smooth minimum.
float smin(float a, float b, float k) {
  float kk = max(k, 0.0001);
  float h = max(kk - abs(a - b), 0.0) / kk;
  return min(a, b) - h * h * kk * 0.25;
}

// Signed distance of the merged glass field, in surface pixels.
// radiusScale > 1 inflates the corners for smooth normals (Kyant0: 1.5x).
float field(vec2 px, float radiusScale) {
  vec2 hA = max(0.5 * uRectA.zw, vec2(0.5));
  float rA = min(uShape.x * radiusScale, min(hA.x, hA.y));
  float dA = sdRoundRect(px - (uRectA.xy + hA), hA, rA);
  vec2 hB = max(0.5 * uRectB.zw, vec2(0.5));
  float rB = min(uShape.y * radiusScale, min(hB.x, hB.y));
  float dB = sdRoundRect(px - (uRectB.xy + hB), hB, rB);
  float hasB = step(0.5, uRectB.z);
  dB = mix(100000.0, dB, hasB);
  return smin(dA, dB, uShape.z);
}

vec2 fieldNormal(vec2 px) {
  float e = 1.0;
  vec2 g = vec2(
    field(px + vec2(e, 0.0), 1.5) - field(px - vec2(e, 0.0), 1.5),
    field(px + vec2(0.0, e), 1.5) - field(px - vec2(0.0, e), 1.5));
  return g / max(length(g), 0.0001);
}

// Sample the backdrop at a surface-pixel position.
vec4 tap(vec2 px) {
  vec2 uv = (px - gOrigin) / uSize;
  uv = clamp(uv, 0.5 / uSize, 1.0 - 0.5 / uSize);
#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;  // only engines <= 3.44 stored GLES textures bottom-up
#endif
  return texture(uBackdrop, uv);
}

// Interleaved gradient noise: rotates the blur disk per pixel so a small
// number of taps reads as soft frost instead of ghost copies.
float ign(vec2 p) {
  return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;

  // Did the engine crop the input to our clip? Then frag counts from the clip.
  float sameAsClip = step(abs(uSize.x - uClip.z), 1.5) * step(abs(uSize.y - uClip.w), 1.5);
  float fullSurface = step(uSurface.x - 1.5, uSize.x) * step(uSurface.y - 1.5, uSize.y);
  float clipLocal = sameAsClip * (1.0 - fullSurface);
  gOrigin = uClip.xy * clipLocal;
  vec2 px = frag + gOrigin;

  float dpr = uSurface.z;
  float sd = field(px, 1.0);
  vec4 plain = tap(px);
  float debug = step(0.5, uSurface.w);

  vec3 outColor = plain.rgb;
  // Only pixels on or near the glass pay for the full shading.
  if (sd <= 2.0 * dpr || debug > 0.5) {
  // --- 1. Refraction: circular edge profile inside a band of width h -------
  float band = max(uOptics.x, 1.0);
  float t = clamp(-sd / band, 0.0, 1.0);          // 0 at the rim, 1 inside
  float x = 1.0 - t;
  float profile = 1.0 - sqrt(max(1.0 - x * x, 0.0));
  float disp = uOptics.y * profile;               // strongest at the rim
  vec2 n = fieldNormal(px);                       // points outwards
  vec2 ps = px + n * disp * uMisc.w;              // +1 outward (Apple), -1 inward

  // --- Blur: Vogel disk around the refracted point -------------------------
  float radius = uOptics.z;
  float taps = clamp(uMisc.z, 0.0, float(MAX_TAPS));
  float rot = ign(frag) * 6.2831853;
  vec3 centre = tap(ps).rgb;
  vec3 acc = centre;
  float lumSum = luma(centre);
  float lumSq = lumSum * lumSum;
  float count = 1.0;
  for (int i = 0; i < MAX_TAPS; i++) {
    float fi = float(i);
    if (fi >= taps) break;
    float r = radius * sqrt((fi + 0.5) / max(taps, 1.0));
    float a = fi * GOLDEN_ANGLE + rot;
    vec3 s = tap(ps + r * vec2(cos(a), sin(a))).rgb;
    float l = luma(s);
    acc += s;
    lumSum += l;
    lumSq += l * l;
    count += 1.0;
  }
  vec3 c = acc / count;

  // --- Optional dispersion at the rim (edge only, R out / B in) -----------
  float dispersion = uMisc.x * (1.0 - t);
  float dispOn = step(0.001, uMisc.x);
  vec2 dOff = n * disp * uMisc.w * 0.08;
  float rSample = tap(ps + dOff).r;
  float bSample = tap(ps - dOff).b;
  c.r = mix(c.r, mix(c.r, rSample, 0.5), dispersion * dispOn);
  c.b = mix(c.b, mix(c.b, bSample, 0.5), dispersion * dispOn);

  // --- Vibrancy -------------------------------------------------------------
  c = mix(vec3(luma(c)), c, uOptics.w);

  // --- 2. Adaptive tint / shadow from what is behind -----------------------
  float meanL = lumSum / count;
  float varL = max(lumSq / count - meanL * meanL, 0.0);
  float busy = clamp(3.0 * sqrt(varL), 0.0, 1.0);  // text / detail behind
  float adaptive = step(0.5, uMisc.y);
  float yb = luma(c);
  float tone = uTint.w;
  float shadowA = mix(0.10, clamp(0.06 + 0.14 * busy - 0.06 * yb, 0.0, 0.25), adaptive);
  float inner = shadowA * pow(1.0 - smoothstep(0.0, 0.5 * band, -sd), 2.0);
  float tintA = mix(0.10, mix(0.06, 0.16, busy), adaptive);
  tintA = mix(tintA, tintA + 0.12, tone);          // dark glass needs more body
  c = mix(c, uTint.rgb, tintA) * (1.0 - inner);

  // Compress the range so foreground stays legible.
  float targetY = mix(0.92, 0.18, tone);
  c = vec3(targetY) + (c - vec3(targetY)) * 0.9;

  // --- 4. Rim: darkened edge + two opposite highlights ---------------------
  float rimW = max(uShape.w, 1.0);
  float darkEdge = 0.08 * (1.0 - smoothstep(0.0, 3.0 * dpr, -sd));
  c *= 1.0 - darkEdge;
  float rim = 1.0 - smoothstep(0.0, rimW, -sd);
  vec2 L = normalize(uLight.xy);
  float spec = rim * (uLight.z * max(dot(n, L), 0.0) + uLight.w * max(dot(n, -L), 0.0));
  c += vec3(spec);

  // --- Anti-aliased composite over the untouched backdrop -------------------
  float aa = 0.75 * max(dpr, 1.0);
  float alpha = 1.0 - smoothstep(-aa, aa, sd);
  outColor = mix(plain.rgb, clamp(c, 0.0, 1.0), alpha);

  // --- Debug overlay: shows where the shader *thinks* the glass is ----------
  float outline = 1.0 - smoothstep(0.0, 1.5 * dpr, abs(sd));
  vec3 bandTint = mix(vec3(1.0, 0.1, 0.4), vec3(0.1, 0.4, 1.0), t);
  vec3 dbg = mix(plain.rgb, bandTint, 0.45 * step(sd, 0.0));
  dbg = mix(dbg, vec3(1.0, 0.95, 0.0), outline);
  // Corner marker inside the clip: green = global frame, orange = clip-local.
  vec2 inClip = px - uClip.xy;
  float marker = step(inClip.x, 10.0 * dpr) * step(inClip.y, 10.0 * dpr) *
                 step(0.0, inClip.x) * step(0.0, inClip.y);
  dbg = mix(dbg, mix(vec3(0.1, 0.9, 0.2), vec3(1.0, 0.5, 0.0), clipLocal), marker);
  outColor = mix(outColor, dbg, debug);
  }

  fragColor = vec4(outColor, 1.0);
}
