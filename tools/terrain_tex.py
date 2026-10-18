#!/usr/bin/env python3
"""Texturile terenului satului (MaterialVariant): iarba, pământul drumurilor, noroiul cărărilor.

  terrain_tex.py gen [Nume ...]     concept Codex (vedere de sus) → art/terrain/<Nume>_src.png
  terrain_tex.py build [Nume ...]   seamless + hartă normală → art/terrain/<Nume>_color.png, _normal.png
  terrain_tex.py upload [Nume ...]  urcă imaginile (assets.lock.json) și scrie variantele (MaterialService „Sat<Nume>”)
                                    în default.project.json; serverul le pune peste iarbă, pământ și noroi

Seamless: textura se mută cu jumătate de pas (marginile ajung la mijloc) și se amestecă înapoi cu originalul
printr-o mască radială, deci nici marginile, nici crucea din mijloc nu se văd. Harta normală vine din
luminozitate (Sobel), în spațiul tangent OpenGL (cum o cere Roblox).
"""

import glob
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "terrain")
GEN = os.path.expanduser("~/.codex/generated_images")
SIZE = 1024

MATERIALS = {
    "Iarba": "short lush meadow grass of a Moldovan village in late spring, dense blades in fresh and warm "
             "greens with a few tiny clover leaves and sparse small white daisies",
    "Pamant": "packed dry dirt of a country road filling the whole frame uniformly: light warm brown earth with "
              "fine cracks, scattered small pebbles and a few dry grass bits; NO ruts, NO stripes, NO tracks, "
              "no directional features, no grass areas",
    "Noroi": "darker moist brown earth filling the whole frame uniformly, trodden and slightly damp, with scattered "
             "small stones and a few fallen leaves; NO path shape, NO grass strips, NO stripes, no directional features",
}


def prompt(name):
    return ("Use your built-in image generation tool to create ONE image (no code, no web search). "
            f"A seamless tileable ground texture seen straight from above (orthographic top-down, no perspective, "
            f"no horizon), evenly lit with no shadows of objects and no vignette, square: {MATERIALS[name]}. "
            "Stylized hand-painted look for a cheerful 3D village game, soft and readable from a distance, "
            "no text, no objects, no frame. Reply only with the absolute path of the saved image.")


def gen(name):
    out = os.path.join(OUT, f"{name}_src.png")
    if os.path.exists(out):
        return "există"
    before = set(glob.glob(os.path.join(GEN, "*", "*.png")))
    started = time.time()
    subprocess.run(["codex", "exec", "--skip-git-repo-check", "-s", "read-only", "--", prompt(name)],
                   capture_output=True, text=True, timeout=900, stdin=subprocess.DEVNULL)
    new = sorted(set(glob.glob(os.path.join(GEN, "*", "*.png"))) - before, key=os.path.getmtime)
    if not new:
        return "EȘEC"
    Image.open(new[-1]).convert("RGB").save(out)
    return f"{round(time.time() - started)} s"


def seamless(img):
    a = np.asarray(img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS), dtype=np.float32)
    shifted = np.roll(np.roll(a, SIZE // 2, axis=0), SIZE // 2, axis=1)
    y, x = np.mgrid[0:SIZE, 0:SIZE] / (SIZE - 1) * 2 - 1
    # 1 în mijloc (originalul), 0 spre margini (varianta mutată, ale cărei margini se potrivesc)
    w = np.clip(1.25 - np.maximum(np.abs(x), np.abs(y)) * 1.25, 0, 1) ** 0.8
    w = w[..., None]
    return Image.fromarray(np.clip(a * w + shifted * (1 - w), 0, 255).astype(np.uint8))


def normal_map(img, strength=2.2):
    h = np.asarray(img.convert("L").filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    n = np.dstack((-dx, dy, np.ones_like(h)))  # OpenGL: verdele în sus
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))


def build(name):
    src = Image.open(os.path.join(OUT, f"{name}_src.png"))
    color = seamless(src)
    color.save(os.path.join(OUT, f"{name}_color.png"))
    normal_map(color).save(os.path.join(OUT, f"{name}_normal.png"))
    return "gata"


VARIANTS = {"Iarba": ("Grass", 10), "Pamant": ("Ground", 8), "Noroi": ("Mud", 8)}


def upload(names):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import json

    import assets
    import cloud

    env = cloud.load_env()
    project_path = os.path.join(ROOT, "default.project.json")
    with open(project_path, encoding="utf-8") as handle:
        project = json.load(handle)
    service = project["tree"].setdefault("MaterialService", {"$className": "MaterialService"})
    for name, (base, studs) in VARIANTS.items():
        if names and name not in names:
            continue
        ids = {}
        for kind in ("color", "normal"):
            path = os.path.join(OUT, f"{name}_{kind}.png")
            if os.path.exists(path):
                ids[kind] = assets.upload(env, f"terrain.{name}.{kind}", path, "Image", f"BUNICA teren {name} {kind}")
        if "color" in ids:
            props = {"BaseMaterial": base, "StudsPerTile": studs, "ColorMap": f"rbxassetid://{ids['color']}"}
            if "normal" in ids:
                props["NormalMap"] = f"rbxassetid://{ids['normal']}"
            service["Sat" + name] = {"$className": "MaterialVariant", "$properties": props}
    with open(project_path, "w", encoding="utf-8") as handle:
        json.dump(project, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("gen", "build", "upload"):
        print(__doc__)
        return 2
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[2:] or list(MATERIALS)
    if sys.argv[1] == "upload":
        upload(sys.argv[2:])
        return 0
    for name in names:
        print(f"[teren] {name}: {gen(name) if sys.argv[1] == 'gen' else build(name)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
