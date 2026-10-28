"""Draws the app icon (three fanned aces on a felt-green badge). Output: assets/icon/*.png

Requires Pillow. Run from the project root: python tool/make_icon.py
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"
S = 2048          # supersampled canvas, downscaled to 1024
FINAL = 1024
GOLD = (232, 184, 74)
GOLD_DARK = (184, 138, 36)
RED = (198, 40, 40)
INK = (27, 27, 27)


def font(size):
    for name in ("arialbd.ttf", "Arial Bold.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def radial(size, inner, mid, outer):
    """Felt-like radial gradient, light in the upper middle."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx, cy = size * 0.5, size * 0.38
    maxd = math.hypot(size * 0.7, size * 0.8)
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - cx, y - cy) / maxd)
            if t < 0.5:
                k = t / 0.5
                a, b = inner, mid
            else:
                k = (t - 0.5) / 0.5
                a, b = mid, outer
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))
    return img


def heart(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r * 0.95, cx, cy + r * 0.05], fill=fill)
    d.ellipse([cx, cy - r * 0.95, cx + r, cy + r * 0.05], fill=fill)
    d.polygon([(cx - r * 0.98, cy - r * 0.18), (cx + r * 0.98, cy - r * 0.18), (cx, cy + r * 1.05)], fill=fill)


def spade(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r * 0.1, cx, cy + r * 0.9], fill=fill)
    d.ellipse([cx, cy - r * 0.1, cx + r, cy + r * 0.9], fill=fill)
    d.polygon([(cx - r * 0.98, cy + r * 0.3), (cx + r * 0.98, cy + r * 0.3), (cx, cy - r * 1.05)], fill=fill)
    d.polygon([(cx - r * 0.18, cy + r * 0.6), (cx + r * 0.18, cy + r * 0.6), (cx + r * 0.42, cy + r * 1.25),
               (cx - r * 0.42, cy + r * 1.25)], fill=fill)


def diamond(d, cx, cy, r, fill):
    d.polygon([(cx, cy - r * 1.15), (cx + r * 0.8, cy), (cx, cy + r * 1.15), (cx - r * 0.8, cy)], fill=fill)


def card(w, h, suit):
    """One ace card on a transparent layer, with a soft shadow baked in."""
    pad = int(w * 0.18)
    layer = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([pad, pad + w * 0.04, pad + w, pad + h + w * 0.04], w * 0.09,
                                             fill=(0, 0, 0, 150))
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(w * 0.05)))
    d = ImageDraw.Draw(layer)
    box = [pad, pad, pad + w, pad + h]
    d.rounded_rectangle(box, w * 0.09, fill=(250, 246, 236), outline=(212, 200, 170), width=max(2, w // 120))
    color = INK if suit == "spade" else RED
    f = font(int(w * 0.34))
    d.text((pad + w * 0.1, pad + h * 0.02), "A", font=f, fill=color)
    small = w * 0.075
    shape = {"spade": spade, "heart": heart, "diamond": diamond}[suit]
    shape(d, pad + w * 0.22, pad + h * 0.31, small, color)
    shape(d, pad + w * 0.5, pad + h * 0.58, w * 0.26, color)
    return layer


def fan(scale, canvas):
    """Three aces fanned out from a pivot at the bottom centre of the cards."""
    w = int(canvas * 0.36)
    h = int(w * 1.4)
    pivot = (canvas / 2, canvas * 0.745)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    # PIL rotates counter-clockwise for positive angles.
    for suit, ang in (("heart", 30), ("diamond", -30), ("spade", 0)):
        c = card(w, h, suit)
        layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        pad = (c.width - w) // 2
        layer.alpha_composite(c, (int(pivot[0] - c.width / 2), int(pivot[1] - pad - h)))
        out.alpha_composite(layer.rotate(ang, resample=Image.BICUBIC, center=pivot))
    if scale != 1.0:
        small = out.resize((int(canvas * scale), int(canvas * scale)), Image.LANCZOS)
        out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        out.alpha_composite(small, ((canvas - small.width) // 2, (canvas - small.height) // 2))
    return out


def badge_background():
    bg = radial(S, (24, 138, 88), (11, 93, 59), (6, 40, 27))
    d = ImageDraw.Draw(bg)
    m = int(S * 0.055)
    d.ellipse([m, m, S - m, S - m], outline=GOLD, width=int(S * 0.012))
    d.ellipse([m * 2, m * 2, S - m * 2, S - m * 2], outline=GOLD_DARK, width=int(S * 0.004))
    return bg


def save(img, name, size=FINAL):
    img.resize((size, size), Image.LANCZOS).save(OUT / name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bg = badge_background().convert("RGBA")

    # Full icon: badge + fan.
    full = bg.copy()
    full.alpha_composite(fan(1.0, S))
    # Square (iOS/web/Windows): flatten onto the felt without the rounded badge edges.
    square = radial(S, (24, 138, 88), (11, 93, 59), (6, 40, 27)).convert("RGBA")
    square.alpha_composite(fan(1.0, S))
    save(square, "icon.png")

    # Adaptive icon: Android masks the outer ~1/6, so keep the fan well inside.
    save(radial(S, (24, 138, 88), (11, 93, 59), (6, 40, 27)).convert("RGBA"), "icon_background.png")
    save(fan(0.74, S), "icon_foreground.png")
    # Monochrome (themed icons): a white silhouette of the fan.
    mono = fan(0.74, S)
    alpha = mono.split()[3].point(lambda a: 255 if a > 40 else 0)
    white = Image.new("RGBA", mono.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    save(white, "icon_monochrome.png")
    # Rounded preview (README / store listing).
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S, S], S * 0.22, fill=255)
    prev = square.copy()
    prev.putalpha(mask)
    save(prev, "icon_preview.png")


if __name__ == "__main__":
    main()
