#!/usr/bin/env python3
"""Imaginile paginii jocului (iconiță 512, imagine principală 1920×1080), compuse din straturile ecranului de
încărcare (build/loading, din `tools/loading.py build`). Ieșire: art/ui/store/.

  store_art.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = os.path.join(ROOT, "build", "loading")
OUT = os.path.join(ROOT, "art", "ui", "store")


def load(name: str) -> Image.Image:
    im = Image.open(os.path.join(L, name)).convert("RGBA")
    im.putalpha(im.split()[3].point(lambda v: 0 if v < 48 else v))  # resturile aproape transparente ale decupării
    return im.crop(im.getbbox())


def fit_h(im, h):
    return im.resize((int(im.width * h / im.height), h), Image.LANCZOS)


def fit_w(im, w):
    return im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)


def shadow(canvas, im, xy, blur=18, off=(10, 14), alpha=110):
    # umbra pe o pânză mai mare: altfel blur-ul se taie la marginea imaginii și lasă un dreptunghi vizibil
    pad = blur * 3
    mask = Image.new("L", (im.width + 2 * pad, im.height + 2 * pad), 0)
    mask.paste(im.split()[3].point(lambda v: v * alpha // 255), (pad, pad))
    sh = Image.new("RGBA", mask.size, (40, 18, 10, 0))
    sh.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)))
    x, y = xy[0] + off[0] - pad, xy[1] + off[1] - pad
    sh = sh.crop((max(0, -x), max(0, -y), sh.width, sh.height))
    canvas.alpha_composite(sh, (max(0, x), max(0, y)))
    canvas.alpha_composite(im, xy)


def vignette(c):
    v = Image.new("L", c.size, 0)
    d = ImageDraw.Draw(v)
    for i in range(60):
        d.rectangle([i * 8, i * 5, c.width - i * 8, c.height - i * 5], outline=int(255 * (1 - i / 60) ** 2 * 0.5))
    dark = Image.new("RGBA", c.size, (40, 18, 10, 0))
    dark.putalpha(v.filter(ImageFilter.GaussianBlur(40)))
    c.alpha_composite(dark)


def keyart(logo_name: str, out: str):
    bg = Image.open(os.path.join(ROOT, "art", "ui", "loading", "bg.png")).convert("RGBA").resize((1920, 1080), Image.LANCZOS)
    c = bg.copy()
    vignette(c)
    b = fit_h(load("bunica_action_key.png").transpose(Image.FLIP_LEFT_RIGHT), 960)
    shadow(c, b, (1920 - b.width - 30, 1080 - b.height + 40))
    t = fit_h(load("hotoman_sneak_key.png"), 760)
    shadow(c, t, (140, 1080 - t.height + 10))
    lg = fit_w(load(logo_name), 980)
    shadow(c, lg, (110, 40), blur=14, off=(8, 12), alpha=140)
    c.convert("RGB").save(os.path.join(OUT, out), quality=95)


def icon():
    ic = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    d = ImageDraw.Draw(ic)
    for r in range(740, 0, -6):  # fundal cald, mai deschis spre centru
        k = r / 740
        d.ellipse([512 - r, 430 - r, 512 + r, 430 + r], fill=(int(255 - 50 * k), int(214 - 90 * k), int(140 - 90 * k), 255))
    b = fit_h(load("bunica_action_key.png").transpose(Image.FLIP_LEFT_RIGHT), 1400)
    shadow(ic, b, (512 - b.width // 2 + 40, 40), blur=20, off=(0, 16), alpha=90)
    ic.resize((512, 512), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, "icon.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    keyart("logo_en_key.png", "thumb_keyart.png")
    keyart("logo_ro_key.png", "thumb_keyart_ro.png")
    icon()
    print("[store] imagini în", OUT)
