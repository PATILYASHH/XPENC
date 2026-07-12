#!/usr/bin/env python3
"""Generate every XPENC brand asset from one geometric definition.

    python tool/generate_icons.py

Writes Android launcher icons (legacy, round, adaptive, themed), the splash
marks, and the web/GitHub favicons. Nothing here is hand-drawn — re-running the
script reproduces every asset byte-for-byte, so the icons can never drift out
of sync with each other.

The mark
--------
A white "X" on a near-black squircle. The X is two stadium bars crossed at
right angles; the ascending bar is punched out of the descending one by a thin
transparent seam, so the two strokes read as separate objects at 48 dp instead
of merging into a blob. The seam is transparent rather than black, which is
what lets the same foreground sit on the adaptive icon's own background layer.

Anti-aliasing: PIL has none, so every shape is rasterised into a single-channel
mask at SS× scale and box-filtered down. Masks (not RGBA) because resizing an
RGBA image with transparent-black pixels drags the colour channels toward zero
and fringes the white edges.
"""

from __future__ import annotations

import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

# ── Brand ────────────────────────────────────────────────────────────────────
INK = (255, 255, 255)          # the X
TILE_TOP = (23, 23, 26)        # squircle gradient, top
TILE_BOTTOM = (0, 0, 0)        # squircle gradient, bottom — true black, AMOLED
RIM_ALPHA = 22                 # hairline light edge, keeps the tile off a dark wall

SS = 4                         # supersample factor
SQUIRCLE_N = 4.4               # superellipse exponent; 2 = ellipse, ∞ = square
TILE_INSET = 0.02              # breathing room so the shape edge can anti-alias

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
BRANDING = ROOT / "branding"


class Geometry:
    """Where the X sits inside its canvas, as fractions of canvas width."""

    def __init__(self, bar_len: float, thickness: float, seam: float):
        self.bar_len = bar_len
        self.thickness = thickness
        self.seam = seam

    def scaled(self, k: float) -> "Geometry":
        return Geometry(self.bar_len * k, self.thickness * k, self.seam * k)


# The one hand-chosen framing: on a legacy icon the X spans ~49% of the tile.
LEGACY = Geometry(bar_len=0.560, thickness=0.128, seam=0.030)

# An adaptive icon is a 108 dp canvas of which the launcher only ever shows the
# middle 72 dp. Shrinking the mark by exactly that ratio makes it come out the
# same optical size as the legacy icon — and well inside the 66 dp safe zone.
ADAPTIVE = LEGACY.scaled(72 / 108)

# The splash is just the mark, so it fills its bitmap rather than sitting in a tile.
SPLASH = LEGACY.scaled(1.5)

# The same numbers in the VectorDrawable's 108×108 viewport, for the themed icon.
VEC_BAR_LEN = ADAPTIVE.bar_len * 108
VEC_THICK = ADAPTIVE.thickness * 108


# ── Mask primitives ──────────────────────────────────────────────────────────
def _squircle_points(cx: float, cy: float, a: float, steps: int = 720):
    """Superellipse |x/a|^n + |y/a|^n = 1, walked as a polygon."""
    pts = []
    e = 2.0 / SQUIRCLE_N
    for i in range(steps):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        pts.append((
            cx + a * math.copysign(abs(ct) ** e, ct),
            cy + a * math.copysign(abs(st) ** e, st),
        ))
    return pts


def _stadium(draw: ImageDraw.ImageDraw, cx, cy, half, thick, angle_deg, value):
    """A rounded-cap bar of length 2*half through (cx, cy) at angle_deg."""
    rad = math.radians(angle_deg)
    dx, dy = math.cos(rad) * half, math.sin(rad) * half
    x0, y0 = cx - dx, cy - dy
    x1, y1 = cx + dx, cy + dy
    r = thick / 2
    draw.line([(x0, y0), (x1, y1)], fill=value, width=int(round(thick)))
    # PIL has no round caps — add them.
    for x, y in ((x0, y0), (x1, y1)):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=value)


def _downsample(mask: Image.Image, size: int) -> Image.Image:
    return mask.resize((size, size), Image.LANCZOS)


def mark_mask(size: int, g: Geometry) -> Image.Image:
    """Alpha mask of the X, anti-aliased, seam knocked out to zero."""
    s = size * SS
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)

    c = s / 2
    half = g.bar_len * s / 2
    thick = g.thickness * s
    seam = g.seam * s

    _stadium(d, c, c, half, thick, 45, 255)                 # descending ↘
    _stadium(d, c, c, half, thick + 2 * seam, -45, 0)       # carve the seam
    _stadium(d, c, c, half, thick, -45, 255)                # ascending ↗
    return _downsample(m, size)


def tile_mask(size: int, circle: bool = False) -> Image.Image:
    s = size * SS
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    inset = TILE_INSET * s
    if circle:
        d.ellipse([inset, inset, s - inset, s - inset], fill=255)
    else:
        d.polygon(_squircle_points(s / 2, s / 2, s / 2 - inset), fill=255)
    return _downsample(m, size)


def rim_mask(size: int, circle: bool = False) -> Image.Image:
    s = size * SS
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    inset = TILE_INSET * s
    w = max(1, int(round(0.006 * s)))
    if circle:
        d.ellipse([inset, inset, s - inset, s - inset], outline=255, width=w)
    else:
        d.polygon(_squircle_points(s / 2, s / 2, s / 2 - inset),
                  outline=255, width=w)
    return _downsample(m, size)


def gradient(size: int) -> Image.Image:
    g = Image.new("RGB", (1, size))
    px = g.load()
    for y in range(size):
        t = y / max(1, size - 1)
        px[0, y] = tuple(
            round(TILE_TOP[i] + (TILE_BOTTOM[i] - TILE_TOP[i]) * t) for i in range(3)
        )
    return g.resize((size, size), Image.NEAREST)


# ── Composites ───────────────────────────────────────────────────────────────
def tile(size: int, circle: bool = False) -> Image.Image:
    """The shaped, gradient-filled, rim-lit background — transparent outside."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.paste(gradient(size), (0, 0))
    img.putalpha(tile_mask(size, circle))

    rim = Image.new("RGBA", (size, size), INK + (0,))
    rim.putalpha(rim_mask(size, circle).point(lambda v: v * RIM_ALPHA // 255))
    return Image.alpha_composite(img, rim)


def icon(size: int, circle: bool = False) -> Image.Image:
    """Full launcher / favicon artwork: X on tile."""
    base = tile(size, circle)
    ink = Image.new("RGBA", (size, size), INK + (0,))
    ink.putalpha(mark_mask(size, LEGACY))
    return Image.alpha_composite(base, ink)


def foreground(size: int) -> Image.Image:
    """Adaptive-icon foreground: the X alone, on transparency."""
    img = Image.new("RGBA", (size, size), INK + (0,))
    img.putalpha(mark_mask(size, ADAPTIVE))
    return img


def background(size: int) -> Image.Image:
    """Adaptive-icon background: full-bleed gradient, launcher applies the mask."""
    return gradient(size).convert("RGBA")


def splash_mark(size: int, colour) -> Image.Image:
    img = Image.new("RGBA", (size, size), tuple(colour) + (0,))
    img.putalpha(mark_mask(size, SPLASH))
    return img


# ── Android resources ────────────────────────────────────────────────────────
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_icons.py — do not hand-edit. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
"""


def _bar_path(length: float, thick: float) -> str:
    """One stadium bar as SVG/VectorDrawable path data, centred on (54, 54)."""
    r = thick / 2
    x0, x1 = 54 - length / 2 + r, 54 + length / 2 - r
    y0, y1 = 54 - r, 54 + r
    return (f"M{x0:.2f},{y0:.2f} H{x1:.2f} "
            f"A{r:.2f},{r:.2f} 0 0 1 {x1:.2f},{y1:.2f} "
            f"H{x0:.2f} A{r:.2f},{r:.2f} 0 0 1 {x0:.2f},{y0:.2f} Z")


def monochrome_vector() -> str:
    """Themed-icon drawable (Android 13+). Single tint, so no seam is drawn."""
    bar = _bar_path(VEC_BAR_LEN, VEC_THICK)
    groups = "\n".join(
        f'''    <group android:pivotX="54" android:pivotY="54" android:rotation="{rot}">
        <path android:fillColor="#FFFFFFFF" android:pathData="{bar}" />
    </group>'''
        for rot in (45, -45)
    )
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_icons.py — do not hand-edit. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
{groups}
</vector>
"""


def svg_master() -> str:
    """Scalable source of truth for the web / press kit."""
    pts = _squircle_points(512, 512, 512 * (1 - TILE_INSET), steps=180)
    poly = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    bar_len, thick = LEGACY.bar_len * 1024, LEGACY.thickness * 1024
    r = thick / 2
    x0, x1 = 512 - bar_len / 2 + r, 512 + bar_len / 2 - r
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <title>XPENC</title>
  <defs>
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="rgb{TILE_TOP}"/>
      <stop offset="1" stop-color="rgb{TILE_BOTTOM}"/>
    </linearGradient>
    <clipPath id="squircle"><polygon points="{poly}"/></clipPath>
  </defs>
  <g clip-path="url(#squircle)">
    <rect width="1024" height="1024" fill="url(#tile)"/>
  </g>
  <g stroke="#FFFFFF" stroke-width="{thick:.1f}" stroke-linecap="round" fill="none">
    <line x1="{x0:.1f}" y1="{x0:.1f}" x2="{x1:.1f}" y2="{x1:.1f}"/>
    <line x1="{x0:.1f}" y1="{x1:.1f}" x2="{x1:.1f}" y2="{x0:.1f}"
          stroke="#000000" stroke-width="{thick + 2 * LEGACY.seam * 1024:.1f}"/>
    <line x1="{x0:.1f}" y1="{x1:.1f}" x2="{x1:.1f}" y2="{x0:.1f}" stroke="#FFFFFF"/>
  </g>
</svg>
"""


def write(path: Path, img: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print(f"  {path.relative_to(ROOT)}  {img.width}×{img.height}")


def main() -> None:
    print("Android launcher icons")
    for name, scale in DENSITIES.items():
        legacy = round(48 * scale)
        adapt = round(108 * scale)
        splash = round(160 * scale)

        write(RES / f"mipmap-{name}" / "ic_launcher.png", icon(legacy))
        write(RES / f"mipmap-{name}" / "ic_launcher_round.png", icon(legacy, circle=True))
        write(RES / f"mipmap-{name}" / "ic_launcher_foreground.png", foreground(adapt))
        write(RES / f"mipmap-{name}" / "ic_launcher_background.png", background(adapt))
        write(RES / f"drawable-{name}" / "splash_mark_on_light.png",
              splash_mark(splash, (10, 10, 11)))
        write(RES / f"drawable-{name}" / "splash_mark_on_dark.png",
              splash_mark(splash, INK))

    for f in ("ic_launcher.xml", "ic_launcher_round.xml"):
        p = RES / "mipmap-anydpi-v26" / f
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(ADAPTIVE_XML, encoding="utf-8")
        print(f"  {p.relative_to(ROOT)}")

    p = RES / "drawable" / "ic_launcher_monochrome.xml"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(monochrome_vector(), encoding="utf-8")
    print(f"  {p.relative_to(ROOT)}")

    # The stock template ships a -v21 variant that shadows drawable/ on every
    # device we support, so our themed splash would never be seen.
    stale = RES / "drawable-v21" / "launch_background.xml"
    if stale.exists():
        shutil.rmtree(stale.parent)
        print(f"  removed {stale.parent.relative_to(ROOT)} (shadowed drawable/)")

    print("\nWeb / GitHub")
    write(BRANDING / "xpenc_icon_1024.png", icon(1024))
    write(BRANDING / "xpenc_icon_512.png", icon(512))
    write(BRANDING / "icon_192.png", icon(192))
    write(BRANDING / "apple_touch_icon_180.png", icon(180))
    write(BRANDING / "favicon_32.png", icon(32))
    write(BRANDING / "favicon_16.png", icon(16))

    ico = BRANDING / "favicon.ico"
    icon(256).save(ico, sizes=[(s, s) for s in (16, 32, 48, 64, 128, 256)])
    print(f"  {ico.relative_to(ROOT)}  multi-size")

    svg = BRANDING / "xpenc_icon.svg"
    svg.write_text(svg_master(), encoding="utf-8")
    print(f"  {svg.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
