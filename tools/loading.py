#!/usr/bin/env python3
"""Straturile ecranului de încărcare: din art/ui/loading (Codex) → build/loading → Open Cloud → src/first/LoadingAssets.luau.

  loading.py build     decupează verdele, taie, oglindește Bunica (privește spre hoț), redimensionează, banda de cusătură
  loading.py upload    urcă imaginile (assets.lock.json) și scrie src/first/LoadingAssets.luau

Roblox micșorează orice imagine la cel mult 1024 px, deci totul se pregătește la 1024.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "ui", "loading")
OUT = os.path.join(ROOT, "build", "loading")
KEY = os.path.expanduser("~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py")
LAYERS = ["bg", "logo_en", "logo_ro", "bunica", "hotoman", "stitch"]


def run(*cmd):
    subprocess.run(cmd, check=True, capture_output=True)


def build():
    os.makedirs(OUT, exist_ok=True)
    for name, src, flop in (("logo_en", "logo_en", False), ("logo_ro", "logo_ro", False),
                            ("bunica", "bunica_action", True), ("hotoman", "hotoman_sneak", False)):
        keyed = os.path.join(OUT, f"{src}_key.png")
        run("python3", KEY, "--input", os.path.join(SRC, f"{src}.png"), "--out", keyed, "--auto-key", "border",
            "--soft-matte", "--despill", "--force")
        run("convert", keyed, "-trim", "+repage", *(["-flop"] if flop else []), "-resize", "1024x1024",
            os.path.join(OUT, f"{name}.png"))
    run("convert", os.path.join(SRC, "bg.png"), "-resize", "1024x576^", "-gravity", "center", "-extent", "1024x576",
        os.path.join(OUT, "bg.png"))
    run("python3", os.path.join(ROOT, "tools", "stitch.py"), os.path.join(OUT, "stitch.png"), "--cell", "8")
    print("[loading] straturi în", OUT)


def upload():
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import assets
    import cloud
    from PIL import Image
    env = cloud.load_env()
    lines = ["--!strict", "-- GENERAT de tools/loading.py upload — imaginile ecranului de încărcare (art/ui/loading).",
             "-- Stă în ReplicatedFirst: rulează înainte ca restul jocului să existe pe client.", "", "return {"]
    for name in LAYERS:
        path = os.path.join(OUT, f"{name}.png")
        asset_id = assets.upload(env, f"loading.{name}", path, "Image", f"BUNICA loading {name}")
        w, h = Image.open(path).size
        lines.append(f"\t{name} = {{ image = \"rbxassetid://{asset_id}\", size = Vector2.new({w}, {h}) }},")
    # iconița papucului și sunetele (din configurațiile jocului, care pe client apar abia după încărcare)
    import re
    icons = open(os.path.join(ROOT, "src", "shared", "Config", "UiIcons.luau"), encoding="utf-8").read()
    slipper = re.search(r"slipper = (\d+)", icons).group(1)
    lines.append(f"\tslipper = {{ image = \"rbxassetid://{slipper}\", size = Vector2.new(232, 232) }},")
    atlas = open(os.path.join(ROOT, "src", "shared", "Config", "AudioAtlas.luau"), encoding="utf-8").read()
    audio_id = re.search(r"assetId = (\d+)", atlas).group(1)
    lines.append(f'\taudio = "rbxassetid://{audio_id}",')
    lines.append("\tregions = {")
    for region in ("music.zi", "sfx.whoosh", "sfx.pleosc", "sfx.open", "sfx.reward1"):
        m = re.search(r'\["' + re.escape(region) + r'"\] = \{ start = ([\d.]+), length = ([\d.]+)', atlas)
        lines.append(f'\t\t["{region}"] = {{ start = {m.group(1)}, length = {m.group(2)} }},')
    lines.append("\t},")
    lines.append("}")
    target = os.path.join(ROOT, "src", "first", "LoadingAssets.luau")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    open(target, "w").write("\n".join(lines) + "\n")
    print("[loading] scris", target)


if __name__ == "__main__":
    {"build": build, "upload": upload}[sys.argv[1]]()
