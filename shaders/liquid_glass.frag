#version 460 core

// Liquid Glass lens — the refraction half of XPENC's Glass theme.
//
// Run as a BackdropFilter (ImageFilter.shader), it bends whatever is behind
// a rounded-rect pane the way a thick slab of glass does: flat and clear in
// the middle, curving at the rim so the background there is pulled inward
// and magnified, with a faint colour split where the curve is steepest.
// Blur, frost and the specular rim are layered on separately in Dart.

#include <flutter/runtime_effect.glsl>

// Set by the engine: size of the bound backdrop texture, in pixels.
uniform vec2 uSize;
// The pane's top-left inside that texture (used only when the engine hands
// us more than the pane itself), its size, and its corner radius — pixels.
uniform vec2 uOrigin;
uniform vec2 uShape;
uniform float uRadius;
// How far, in pixels, the very edge pulls the background inward.
uniform float uRefraction;
// Width of the curved rim band, in pixels.
uniform float uBand;
// Colour split at the rim, 0 (none) … ~0.3.
uniform float uChroma;
// Whole-pane magnification, 1.0 = none.
uniform float uZoom;
// The screen's size in pixels — tells a full-screen backdrop apart from
// one cut to (or padded around) the pane.
uniform vec2 uScreen;

uniform sampler2D uTexture;

out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// No GLES y-flip here, unlike the generic ImageFilter.shader example: as a
// *backdrop* filter the snapshot already arrives in fragment orientation —
// flipping it mirrored the lens vertically on an Impeller-GLES device.
vec4 sampleAt(vec2 px) {
  vec2 uv = clamp(px / uSize, vec2(0.0), vec2(1.0));
  return texture(uTexture, uv);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;

  // The engine may hand us exactly the pane's region, the whole screen, or
  // the pane padded on every side. Place the pane inside the texture for
  // each, so the lens never samples the wrong spot.
  vec2 origin;
  if (abs(uSize.x - uShape.x) < 3.0 && abs(uSize.y - uShape.y) < 3.0) {
    origin = vec2(0.0);
  } else if (uSize.x >= uScreen.x - 3.0 && uSize.y >= uScreen.y - 3.0) {
    origin = uOrigin;
  } else {
    origin = (uSize - uShape) * 0.5;
  }

  vec2 halfSize = uShape * 0.5;
  vec2 centre = origin + halfSize;
  vec2 p = frag - centre;
  float r = min(uRadius, min(halfSize.x, halfSize.y));
  float d = sdRoundRect(p, halfSize, r);

  if (d > 0.5) {
    fragColor = sampleAt(frag);
    return;
  }

  // Outward normal from the distance field's gradient.
  float e = 1.0;
  vec2 grad = vec2(
    sdRoundRect(p + vec2(e, 0.0), halfSize, r) - sdRoundRect(p - vec2(e, 0.0), halfSize, r),
    sdRoundRect(p + vec2(0.0, e), halfSize, r) - sdRoundRect(p - vec2(0.0, e), halfSize, r)
  );
  vec2 n = length(grad) > 0.0001 ? normalize(grad) : vec2(0.0);

  // 0 deep inside → 1 at the edge, eased like the profile of a rounded slab.
  float depth = clamp(-d / max(uBand, 1.0), 0.0, 1.0);
  float curve = 1.0 - depth;
  float bend = curve * curve * (3.0 - 2.0 * curve);

  vec2 lens = centre + p / uZoom;
  vec2 offset = -n * uRefraction * bend;

  float split = uChroma * bend;
  vec4 g = sampleAt(lens + offset);
  float rr = sampleAt(lens + offset * (1.0 + split)).r;
  float bb = sampleAt(lens + offset * (1.0 - split)).b;
  fragColor = vec4(rr, g.g, bb, g.a);
}
