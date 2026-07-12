#!/usr/bin/env python3
"""Generate the Play Store feature graphic from the same geometry as the icons.

    python tool/generate_playstore_assets.py

Writes branding/playstore_feature_graphic.png (1024x500, the exact size Play
Console requires). Reuses the mark/tile/gradient primitives from
generate_icons.py so the graphic can never drift from the launcher icon.

Typography: Space Grotesk (the website's display font). The variable-weight
TTF is fetched once from the google/fonts repo into branding/fonts/ and cached;
if the download fails (offline), Segoe UI Bold is used as a fallback and a
warning is printed — re-run online before uploading to Play in that case.
"""

from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_icons as gi  # noqa: E402  (needs the sys.path line above)

ROOT = gi.ROOT
FONTS = gi.BRANDING / "fonts"
OUT = gi.BRANDING / "playstore_feature_graphic.png"

W, H = 1024, 500          # Play Console: exactly 1024x500, PNG/JPEG, <= 15 MB
INK = (244, 244, 246)     # --ink
MUTED = (162, 162, 172)   # --muted
FAINT = (98, 98, 108)     # --faint

FONT_URL = ("https://raw.githubusercontent.com/google/fonts/main/"
            "ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf")
FONT_FILE = FONTS / "SpaceGrotesk[wght].ttf"


def display_font(size: int, weight: int) -> ImageFont.FreeTypeFont:
    if not FONT_FILE.exists():
        FONTS.mkdir(parents=True, exist_ok=True)
        try:
            urllib.request.urlretrieve(FONT_URL, FONT_FILE)
            print(f"  fetched {FONT_FILE.relative_to(ROOT)}")
        except OSError as e:
            print(f"  WARNING: Space Grotesk download failed ({e}); "
                  "falling back to Segoe UI — re-run online before uploading.")
            return ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", size)
    font = ImageFont.truetype(str(FONT_FILE), size)
    try:
        font.set_variation_by_axes([weight])
    except OSError:
        pass  # PIL without variable-font support: default instance is fine
    return font


def tracked_text(draw: ImageDraw.ImageDraw, xy, text, font, fill, tracking=0.0):
    """Draw text with letter-spacing (px between glyphs); returns end x."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill, anchor="ls")
        x += draw.textlength(ch, font=font) + tracking
    return x - tracking


def feature_graphic() -> Image.Image:
    img = gi.gradient(max(W, H)).crop((0, 0, W, H)).convert("RGB")
    d = ImageDraw.Draw(img)

    # Keep everything inside a ~50 px safe margin: some Play placements crop edges.
    mark = gi.icon(300)
    img.paste(mark, (96, (H - 300) // 2), mark)

    x0 = 470
    word = display_font(104, 700)
    tag = display_font(36, 500)
    small = display_font(21, 500)

    tracked_text(d, (x0, 240), "XPENC", word, INK, tracking=0.14 * 104)
    d.text((x0 + 4, 306), "Money, tracked honestly.", font=tag, fill=MUTED, anchor="ls")
    tracked_text(d, (x0 + 4, 356), "OFFLINE-FIRST  ·  OPEN SOURCE  ·  NO ADS",
                 small, FAINT, tracking=1.5)
    return img


def main() -> None:
    print("Play Store assets")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    feature_graphic().save(OUT, "PNG", optimize=True)
    size_kb = OUT.stat().st_size // 1024
    print(f"  {OUT.relative_to(ROOT)}  {W}x{H}  {size_kb} KB")


if __name__ == "__main__":
    main()
