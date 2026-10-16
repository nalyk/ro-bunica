#!/usr/bin/env python3
"""Setul de iconițe UI, generat cu Codex `image_gen`: o iconiță master fixează stilul, restul o primesc ca referință.

  icons.py            → art/ui/icons/<nume>.png (fond verde #00FF00, de decupat) ; existente nu se refac
"""
import glob
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "ui", "icons")
GEN = os.path.expanduser("~/.codex/generated_images")
ICONS = {
    "lei": "a shiny gold coin with a tiny embossed slipper on its face",
    "seeds": "a small burlap seed sack tied with red string, a few sunflower seeds spilling out",
    "cellar": "a wooden cellar door / small barrel of preserves (jar of pickles) — the family cellar",
    "hora": "three tiny cartoon villagers holding hands dancing in a circle (Romanian hora)",
    "slipper": "a red felt house slipper with a white pompom",
    "rollingpin": "a wooden rolling pin",
    "rage": "a furious cartoon grandmother face with red headscarf, steam puffs from the head",
    "day": "a cheerful warm sun with soft rays",
    "night": "a crescent moon with two small stars",
    "alarm": "a startled rooster crowing, alarm motion lines",
    "family": "a small house with a heart above it",
    "shop": "a village market stall with a striped red-white awning",
    "close": "a round red button with a white X",
    "check": "a round green button with a white check mark",
    "pedestal": "a short wooden log-slice pedestal with a red-and-white embroidered towel draped over the top",
    "dog": "the friendly head of a shaggy brown-and-white village dog barking, mouth open, small motion lines",
    "sharp": "a pair of round wire grandma glasses with a sparkle on one lens",
    "fastslipper": "a red felt slipper with a white pompom flying fast to the right, three white speed lines behind it",
    "yard": "a small wooden toolbox with a hammer and a saw sticking out, a red ribbon bow on the handle",
}
STYLE = ("Game UI icon for a cozy cartoon village game (Moldovan theme), premium mobile-game quality: chunky rounded "
         "shapes, thick dark-brown (#3A2218) outline of constant weight, soft 3D shading with light from top-left, "
         "warm saturated colors, centered, generous padding, single object, no text, no background scene. "
         "Background: flat pure chroma green #00FF00 filling the whole canvas (it will be keyed out). Square 1024x1024.")


def gen(name, desc, ref=None):
    out = os.path.join(OUT, f"{name}.png")
    if os.path.exists(out):
        return "există"
    prompt = (f"Use your built-in image generation tool to create ONE image (no code, no web search). {STYLE}\n"
              f"Subject: {desc}." + (" Match exactly the style of Image 1 (same outline weight, shading, palette "
                                     "warmth, padding); draw a different subject." if ref else "") +
              "\nReply only with the absolute path of the saved image.")
    before = set(glob.glob(os.path.join(GEN, "*", "*.png")))
    cmd = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only"] + (["-i", ref, "--"] if ref else []) + [prompt]
    t = time.time()
    subprocess.run(cmd, capture_output=True, text=True, timeout=900, stdin=subprocess.DEVNULL)
    new = sorted(set(glob.glob(os.path.join(GEN, "*", "*.png"))) - before, key=os.path.getmtime)
    if not new:
        return "EȘEC"
    subprocess.run(["cp", new[-1], out], check=True)
    return f"{round(time.time() - t)} s"


def upload():
    """Decupează verdele, aduce la 256×256 și urcă fiecare iconiță ca imagine; scrie Config/UiIcons.luau."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import assets
    import cloud

    env = cloud.load_env()
    keyed_dir = os.path.join(ROOT, "build", "icons")
    os.makedirs(keyed_dir, exist_ok=True)
    ids = {}
    for name in ICONS:
        src = os.path.join(OUT, f"{name}.png")
        if not os.path.exists(src):
            continue
        keyed = os.path.join(keyed_dir, f"{name}_key.png")
        final = os.path.join(keyed_dir, f"{name}.png")
        subprocess.run(["python3", os.path.expanduser("~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py"),
                        "--input", src, "--out", keyed, "--auto-key", "border", "--soft-matte", "--despill",
                        "--force"], check=True, capture_output=True)
        subprocess.run(["convert", keyed, "-trim", "+repage", "-resize", "232x232", "-background", "none",
                        "-gravity", "center", "-extent", "256x256", final], check=True)
        ids[name] = assets.upload(env, f"icon.{name}", final, "Image", f"BUNICA icon {name}")
    lines = ["--!strict", "-- GENERAT de tools/icons.py upload — id-urile iconițelor UI (art/ui/icons). "
             "Lipsa unei iconițe = text/emoji.", "", "return table.freeze({"]
    lines += [f"\t{name} = {asset_id}," for name, asset_id in sorted(ids.items())]
    lines += ["} :: { [string]: number })", ""]
    path = os.path.join(ROOT, "src", "shared", "Config", "UiIcons.luau")
    open(path, "w").write("\n".join(lines))
    print("scris", path, len(ids), "iconițe")


if len(sys.argv) > 1 and sys.argv[1] == "upload":
    upload()
    sys.exit(0)

os.makedirs(OUT, exist_ok=True)
names = sys.argv[1:] or list(ICONS)
master = os.path.join(OUT, "slipper.png")
print("[icon] slipper (master):", gen("slipper", ICONS["slipper"]), flush=True)
for name in names:
    if name != "slipper":
        print(f"[icon] {name}:", gen(name, ICONS[name], master), flush=True)
