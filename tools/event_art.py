#!/usr/bin/env python3
"""Imaginile pentru Experience Events (1920×1080): fundalul ecranului de încărcare, logo-ul, personajele din
concepte (decupate) și titlul evenimentului. Ieșire: art/ui/events/<cheie>.jpg.

  event_art.py            # toate
  event_art.py bazaar     # doar unul

Cere build/loading (`tools/loading.py build`). Fonturile: art/fonts (Luckiest Guy, Apache 2.0).
"""
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = os.path.join(ROOT, "build", "loading")
C = os.path.join(ROOT, "art", "concepts")
OUT = os.path.join(ROOT, "art", "ui", "events")
FONT = os.path.join(ROOT, "art", "fonts", "LuckiestGuy.ttf")
W, H = 1920, 1080

# cheie: (titlu, subtitlu, culoarea panglicii, personaje [(fișier, înălțime, x relativ)], efect)
EVENTS = {
    "saturday": ("SATURDAY IN THE VILLAGE", "Happenings, team games, a full bazaar", (196, 64, 44),
                 [("village/Lautar.png", 640, 0.60), ("loading:bunica.png", 760, 0.80), ("village/Satean1.png", 560, 0.95)], None),
    "bazaar": ("BIG SUNDAY BAZAAR", "12 stalls and merchants who pay well", (214, 140, 30),
               [("world/Taraba.png", 600, 0.62), ("village/Negustorul.png", 700, 0.80), ("creatures/DovleacDJ.png", 430, 0.95)], None),
    "easter": ("EASTER EGG HUNT", "Painted eggs hidden all over the village", (120, 70, 170),
               [("creatures/CozonacRobot.png", 520, 0.62), ("loading:bunica.png", 760, 0.80), ("village/Gaina.png", 380, 0.95)], None),
    "martisor": ("SPRING CHARMS", "Garden beds grow 20% faster", (204, 40, 60),
                 [("world/Cires.png", 520, 0.60), ("loading:bunica.png", 720, 0.76), ("creatures/Martisorel.png", 520, 0.93)], None),
    "dragaica": ("WREATH FESTIVAL", "Toss a wreath on the roof for 250 lei", (226, 170, 30),
                 [("village/Mireasa.png", 640, 0.62), ("village/Lautar.png", 620, 0.79), ("creatures/SarmalinaBallerina.png", 520, 0.95)], None),
    "harvest": ("HARVEST TIME", "Find the red corn cob, stomp the grapes", (150, 60, 110),
                [("world/ButucVie.png", 600, 0.57), ("world/Patul.png", 540, 0.75), ("creatures/StrugurelFurios.png", 500, 0.93)], None),
    "winter": ("WINTER CAROLS", "Carols at the gates, the Goat and the Bear", (40, 90, 170),
               [("village/Lautar.png", 620, 0.60), ("loading:bunica.png", 760, 0.79), ("village/Satean3.png", 560, 0.95)], "snow"),
}


def cutout(path: str) -> Image.Image:
    """Personajul fără fundal: din build/loading (deja decupat) sau din concept (albul de la margini scos)."""
    if path.startswith("loading:"):
        im = Image.open(os.path.join(L, path[8:])).convert("RGBA")
        return im.crop(im.getbbox())
    img = Image.open(os.path.join(C, path)).convert("RGB")
    a = np.asarray(img).astype(int)
    labels, _ = ndimage.label((255 - a).max(axis=2) <= 14)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    alpha = np.where(np.isin(labels, list(border)), 0, 255).astype(np.uint8)
    mask = Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(1.2))
    im = img.convert("RGBA")
    im.putalpha(mask)
    return im.crop(im.getbbox())


def fit_h(im: Image.Image, h: int) -> Image.Image:
    return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)


def shadow(canvas: Image.Image, im: Image.Image, xy, blur=18, off=(12, 16), alpha=120):
    pad = blur * 3
    mask = Image.new("L", (im.width + 2 * pad, im.height + 2 * pad), 0)
    mask.paste(im.split()[3].point(lambda v: v * alpha // 255), (pad, pad))
    sh = Image.new("RGBA", mask.size, (40, 18, 10, 0))
    sh.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)))
    x, y = xy[0] + off[0] - pad, xy[1] + off[1] - pad
    sh = sh.crop((max(0, -x), max(0, -y), sh.width, sh.height))  # alpha_composite nu primește poziții negative
    canvas.alpha_composite(sh, (max(0, x), max(0, y)))
    im = im.crop((max(0, -xy[0]), max(0, -xy[1]), im.width, im.height))
    canvas.alpha_composite(im, (max(0, xy[0]), max(0, xy[1])))


def text(draw: ImageDraw.ImageDraw, xy, s: str, size: int, fill, stroke=(60, 24, 10), width=8, anchor="la"):
    font = ImageFont.truetype(FONT, size)
    draw.text(xy, s, font=font, fill=fill, stroke_width=width, stroke_fill=stroke, anchor=anchor)
    return font.getbbox(s, stroke_width=width, anchor=anchor)


def fit_size(s: str, max_w: int, start: int) -> int:
    size = start
    while size > 40 and ImageFont.truetype(FONT, size).getlength(s) > max_w:
        size -= 4
    return size


def winter(canvas: Image.Image) -> Image.Image:
    """Fundalul de vară făcut iarnă: rece și stins, zăpadă pe pământ, fulgi."""
    gray = canvas.convert("L").convert("RGBA")
    cold = Image.blend(canvas, gray, 0.65)
    cold = Image.blend(cold, Image.new("RGBA", canvas.size, (120, 150, 210, 255)), 0.28)
    ground = Image.new("L", canvas.size, 0)
    gd = ImageDraw.Draw(ground)
    for y in range(int(H * 0.62), H):
        gd.line((0, y, W, y), fill=min(235, int((y - H * 0.62) / (H * 0.38) * 400)))
    white = Image.new("RGBA", canvas.size, (244, 248, 255, 0))
    white.putalpha(ground.filter(ImageFilter.GaussianBlur(30)))
    cold.alpha_composite(white)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rng = random.Random(7)
    for _ in range(360):
        x, y, r = rng.randrange(W), rng.randrange(H), rng.choice([3, 4, 5, 6, 8])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rng.randrange(150, 230)))
    cold.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1)))
    return cold


def build(key: str):
    title, subtitle, ribbon, figures, effect = EVENTS[key]
    bg = Image.open(os.path.join(L, "bg.png")).convert("RGBA").resize((W, H), Image.LANCZOS)
    canvas = bg.copy()
    if effect == "snow":
        canvas = winter(canvas)
    # personajele, de la stânga la dreapta, cu picioarele pe marginea de jos
    for path, h, rx in figures:
        im = fit_h(cutout(path), h)
        x = int(W * rx - im.width / 2)
        x = max(-40, min(W - im.width + 40, x))
        shadow(canvas, im, (x, H - im.height - 10))
    # logo-ul sus-stânga, titlul pe o panglică
    logo = Image.open(os.path.join(L, "logo_en.png")).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    logo = logo.resize((560, int(logo.height * 560 / logo.width)), Image.LANCZOS)
    shadow(canvas, logo, (60, 40), blur=12, off=(6, 8))
    draw = ImageDraw.Draw(canvas)
    size = fit_size(title, 900, 150)
    y = 40 + logo.height + 40
    band = Image.new("RGBA", (980, size + 70), ribbon + (235,))
    bd = ImageDraw.Draw(band)
    bd.rectangle((0, 0, band.width - 1, band.height - 1), outline=(60, 24, 10, 255), width=6)
    canvas.alpha_composite(band, (40, y))
    text(draw, (40 + 490, y + band.height // 2 + 6), title, size, (255, 248, 230), anchor="mm")
    sub = fit_size(subtitle, 900, 64)
    text(draw, (60, y + band.height + 30), subtitle, sub, (255, 244, 214), width=6)
    os.makedirs(OUT, exist_ok=True)
    canvas.convert("RGB").save(os.path.join(OUT, f"{key}.jpg"), quality=90)
    print("scris", os.path.relpath(os.path.join(OUT, f"{key}.jpg"), ROOT))


if __name__ == "__main__":
    for key in sys.argv[1:] or EVENTS:
        build(key)
