#version 460 core

// Liquid Glass lens — the refraction half of XPENC's Glass theme.
//
// Run as a BackdropFilter (ImageFilter.shader), it bends whatever is behind
// a rounded-rect pane the way a thick slab of glass does: flat and clear in
// the middle, curving at the rim so the background there is pulled inward
// and magnified, with a faint colour split where the curve is steepest.
//
// It also lights the glass with what's behind it, the way real glass picks
// up the colour of what shines through it: the rim glows with the colour of
// the content just under it (light entering the edge and running along the
// curve), the whole pane takes a faint wash of the average colour beneath,
// and a specular highlight sits where the curve faces the light. Over plain
// black none of that shows; slide something colourful under the glass and
// the glass takes its light.
//
// Frost and the hairline rim are layered on separately in Dart.

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
// Strength of the light the glass takes from what's behind it, 0 … 1.
uniform float uLight;
// 1 on dark glass (light adds), 0 on light glass (light tints gently).
uniform float uDark;

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

float luma(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
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
  float band = max(uBand, 1.0);
  float depth = clamp(-d / band, 0.0, 1.0);
  float curve = 1.0 - depth;
  float bend = curve * curve * (3.0 - 2.0 * curve);

  vec2 lens = centre + p / uZoom;
  vec2 offset = -n * uRefraction * bend;

  float split = uChroma * bend;
  vec4 g = sampleAt(lens + offset);
  float rr = sampleAt(lens + offset * (1.0 + split)).r;
  float bb = sampleAt(lens + offset * (1.0 - split)).b;
  vec3 col = vec3(rr, g.g, bb);

  if (uLight <= 0.001) {
    fragColor = vec4(col, g.a);
    return;
  }

  // ── Light from behind ──
  // Colour, not brightness, is what reads as light through glass: every tap
  // is weighted by how colourful it is, so a small orange icon under the
  // rim lights it orange instead of being averaged away into grey.
  vec3 acc = vec3(0.0);
  float wsum = 0.0;
  for (int i = 0; i < 12; i++) {
    float ring = i < 6 ? 1.3 : 2.6;
    float a = 6.2831853 * float(i) / 6.0 + (i < 6 ? 0.4 : 0.9);
    vec3 c = sampleAt(frag + band * ring * vec2(cos(a), sin(a))).rgb;
    float chroma = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    float w = 0.04 + chroma * chroma * 10.0;
    acc += c * w;
    wsum += w;
  }
  vec3 near = acc / wsum;
  // The pane as a whole, the same way.
  vec3 pacc = vec3(0.0);
  float pw = 0.0;
  for (int i = 0; i < 8; i++) {
    float a = 6.2831853 * (float(i) + 0.5) / 8.0;
    vec3 c = sampleAt(centre + halfSize * 0.72 * vec2(cos(a), sin(a))).rgb;
    float chroma = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    float w = 0.04 + chroma * chroma * 10.0;
    pacc += c * w;
    pw += w;
  }
  vec3 pane = pacc / pw;

  // Hue at full strength, and how much colour there really is around.
  float nearMax = max(near.r, max(near.g, near.b));
  vec3 hue = near / max(nearMax, 0.04);
  float nearChroma = nearMax - min(near.r, min(near.g, near.b));
  float presence = smoothstep(0.03, 0.32, nearChroma);
  float paneMax = max(pane.r, max(pane.g, pane.b));
  float paneChroma = paneMax - min(pane.r, min(pane.g, pane.b));
  vec3 paneHue = pane / max(paneMax, 0.04);
  float panePresence = smoothstep(0.03, 0.3, paneChroma);

  // The rim carries the light: brightest at the edge, a soft band inside.
  float rim = pow(bend, 1.25);
  vec3 glow = hue * rim * presence * (0.35 + 0.65 * nearMax);
  // Plain grey surroundings add only a whisper — not a milky veil.
  glow += vec3(luma(near)) * rim * 0.06;

  // A specular sheen where the curve faces the light (top-left), tinted a
  // little by the light it's carrying.
  vec2 lightDir = normalize(vec2(-0.55, -0.85));
  float facing = max(dot(n, lightDir), 0.0);
  float spec = pow(facing, 3.0) * pow(bend, 2.2);
  vec3 sheen = mix(vec3(1.0), hue, 0.3 * presence) * spec;

  // Light passing through: the body of the glass takes a faint cast of the
  // colour beneath it.
  vec3 tint = paneHue * panePresence;
  vec3 body = mix(col, col * (0.75 + 0.5 * tint), 0.35 * panePresence * uLight);

  vec3 add = (glow * 0.62 + tint * 0.06 + sheen * 0.2) * uLight;
  // Dark glass: light adds. Light glass: light tints without greying.
  vec3 outCol = mix(body + add * 0.55, body + add, uDark);
  fragColor = vec4(clamp(outCol, 0.0, 1.0), g.a);
}
