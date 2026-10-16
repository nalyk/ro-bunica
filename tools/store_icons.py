#!/usr/bin/env python3
"""Iconițele pentru game passes și developer products (Codex `image_gen`, în stilul iconițelor UI).

  store_icons.py            generează ce lipsește în art/ui/store/items (master: iconița papucului)
  store_icons.py compose    pune fiecare pe un disc cald, 512×512 (Roblox le decupează rotund) → build/store_items
  store_icons.py upload     urcă iconițele decupate (fără disc) pentru panoul din joc → Config/StoreIcons.luau
"""
import re
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "ui", "store", "items")
BUILD = os.path.join(ROOT, "build", "store_items")
GEN = os.path.expanduser("~/.codex/generated_images")
MASTER = os.path.join(ROOT, "art", "ui", "icons", "slipper.png")
KEY = os.path.expanduser("~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py")

ITEMS = {
    "vip": "a golden crown sitting on a red Moldovan embroidered headscarf, with sparkles",
    "doublelei": "two stacked shiny gold coins with a big bold white-outlined number 2 and a small x on top",
    "goldslipper": "a shiny solid-gold house slipper with a white pompom, golden sparkle trail behind it",
    "bigcellar": "a wooden cellar door opened wide showing many barrels and jars inside, warm light",
    "gardener": "a woven basket full of seed packets and a small green watering can",
    "lei_s": "a small cloth pouch with three gold coins peeking out",
    "lei_m": "a bulging burlap sack overflowing with gold coins",
    "lei_l": "an open wooden treasure chest overflowing with gold coins, painted with folk flowers",
    "fertilizer": "a small clay pot with a sprouting seedling and green sparkles of magic fertilizer",
    "restock": "a market stall crate full of colourful seed packets with a circular refresh arrow",
    "weather_gold": "a golden sun shining over golden wheat, golden sparkles raining down",
    "weather_rainbow": "a bright rainbow arching over two small fluffy clouds",
    # insignele (badges)
    "badge_hatch": "a cracked seed shell with a tiny happy potato creature popping out, sparkles",
    "badge_steal": "a brown burlap sack with a sneaky happy potato peeking out, a black domino mask on the sack",
    "badge_defend": "a red felt slipper with a white pompom hitting a big comic star burst that says PLEOSC",
    "badge_legend": "a golden star medal with a red-and-white embroidered ribbon",
    "badge_hora": "three small cartoon villagers holding hands dancing in a circle, folk costumes",
    "badge_million": "a tall stack of shiny gold coins with a small golden crown on top",
}
STYLE = ("Game store item icon for a cozy cartoon village game (Moldovan theme), premium mobile-game quality: chunky "
         "rounded shapes, thick dark-brown (#3A2218) outline of constant weight, soft 3D shading with light from "
         "top-left, warm saturated colors, centered, generous padding, single subject, no text except where asked, "
         "no background scene. Background: flat pure chroma green #00FF00 filling the whole canvas (it will be keyed "
         "out). Square 1024x1024.")


def gen(name: str, desc: str) -> str:
    out = os.path.join(OUT, f"{name}.png")
    if os.path.exists(out):
        return "există"
    prompt = (f"Use your built-in image generation tool to create ONE image (no code, no web search). {STYLE}\n"
              f"Subject: {desc}. Match exactly the style of Image 1 (same outline weight, shading, palette warmth, "
              "padding); draw a different subject.\nReply only with the absolute path of the saved image.")
    t = time.time()
    result = subprocess.run(["codex", "exec", "--skip-git-repo-check", "-s", "read-only", "-i", MASTER, "--", prompt],
                            capture_output=True, text=True, timeout=900, stdin=subprocess.DEVNULL)
    # calea din răspunsul lui Codex (nu „cel mai nou fișier”: în paralel s-ar amesteca imaginile între joburi)
    paths = re.findall(r"(" + re.escape(GEN) + r"/\S+?\.png)", result.stdout)
    if not paths or not os.path.exists(paths[-1]):
        return "EȘEC"
    subprocess.run(["cp", paths[-1], out], check=True)
    return f"{round(time.time() - t)} s"


def compose():
    from PIL import Image, ImageDraw
    os.makedirs(BUILD, exist_ok=True)
    for name in ITEMS:
        keyed = os.path.join(BUILD, f"{name}_key.png")
        subprocess.run(["python3", KEY, "--input", os.path.join(OUT, f"{name}.png"), "--out", keyed, "--auto-key",
                        "border", "--soft-matte", "--despill", "--force"], check=True, capture_output=True)
        icon = Image.open(keyed).convert("RGBA")
        icon = icon.crop(icon.getbbox())
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        d = ImageDraw.Draw(canvas)
        for r in range(256, 0, -2):  # disc cald, mai deschis spre centru
            k = r / 256
            d.ellipse([256 - r, 256 - r, 256 + r, 256 + r],
                      fill=(int(255 - 30 * k), int(226 - 80 * k), int(160 - 100 * k), 255))
        side = 360
        icon.thumbnail((side, side), Image.LANCZOS)
        canvas.alpha_composite(icon, ((512 - icon.width) // 2, (512 - icon.height) // 2))
        canvas.convert("RGB").save(os.path.join(BUILD, f"{name}.png"))
    print("[store] iconițe în", BUILD)


def upload():
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import assets
    import cloud
    from PIL import Image
    env = cloud.load_env()
    lines = ["--!strict", "-- GENERAT de tools/store_icons.py upload — iconițele din magazinul pe Robux.", "", "return {"]
    for name in ITEMS:
        keyed = os.path.join(BUILD, f"{name}_key.png")
        small = os.path.join(BUILD, f"{name}_256.png")
        im = Image.open(keyed).convert("RGBA")
        im = im.crop(im.getbbox())
        im.thumbnail((232, 232), Image.LANCZOS)
        canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        canvas.alpha_composite(im, ((256 - im.width) // 2, (256 - im.height) // 2))
        canvas.save(small)
        asset_id = assets.upload(env, f"store.{name}", small, "Image", f"BUNICA store {name}")
        lines.append(f"\t{name} = {asset_id},")
    lines.append("}")
    path = os.path.join(ROOT, "src", "shared", "Config", "StoreIcons.luau")
    open(path, "w").write("\n".join(lines) + "\n")
    print("[store] scris", path)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "compose":
        compose()
    elif len(sys.argv) > 1 and sys.argv[1] == "upload":
        upload()
    else:
        os.makedirs(OUT, exist_ok=True)
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(3) as pool:
            for name, result in zip(ITEMS, pool.map(lambda kv: gen(*kv), ITEMS.items())):
                print(f"[store] {name}: {result}", flush=True)
