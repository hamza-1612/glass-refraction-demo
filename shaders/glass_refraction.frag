#version 460 core
#include <flutter/runtime_effect.glsl>

// Engine-owned: do not set these from Dart for ImageFilter.shader.
uniform vec2 uSize;
uniform sampler2D uBackdrop;
// Fractions of min(texture width, height), independent of device pixel ratio.
uniform float uRadius;
uniform float uBand;
uniform float uStrength;
uniform float uFrost;
out vec4 fragColor;

float roundedDistance(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + vec2(radius);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}
vec4 backdrop(vec2 pixel) {
  vec2 uv = clamp(pixel / uSize, 0.5 / uSize, 1.0 - 0.5 / uSize);
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, uv);
}
void main() {
  vec2 pixel = FlutterFragCoord().xy;
  vec2 halfSize = uSize * 0.5;
  vec2 p = pixel - halfSize;
  float unitSize = min(uSize.x, uSize.y);
  float radius = clamp(uRadius * unitSize, 0.0, unitSize * 0.5);
  float d = roundedDistance(p, halfSize, radius);
  float band = max(uBand * unitSize, 1.0);
  float depth = max(-d, 0.0);
  // The rounded-rectangle distance gradient points outwards.
  vec2 q = abs(p) - halfSize + vec2(radius);
  vec2 corner = max(q, vec2(0.0));
  vec2 normal;
  if (length(corner) > 0.0001) {
    normal = normalize(corner) * sign(p);
  } else {
    normal = q.x > q.y ? vec2(sign(p.x), 0.0) : vec2(0.0, sign(p.y));
  }
  float weight = (1.0 - smoothstep(0.0, band, depth)) * smoothstep(0.0, 1.5, depth);
  // Inward sampling stays in bounds; no outside sampling margin is needed.
  vec2 sampleAt = pixel - normal * max(uStrength, 0.0) * unitSize * weight;
  float frost = max(uFrost, 0.0) * unitSize;
  vec4 color = backdrop(sampleAt) * 0.5;
  color += backdrop(sampleAt + vec2(frost, 0.0)) * 0.125;
  color += backdrop(sampleAt - vec2(frost, 0.0)) * 0.125;
  color += backdrop(sampleAt + vec2(0.0, frost)) * 0.125;
  color += backdrop(sampleAt - vec2(0.0, frost)) * 0.125;
  // ClipRRect clips this in Flutter. Keep an identity outside as well.
  fragColor = d > 0.0 ? backdrop(pixel) : color;
}
