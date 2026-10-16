#!/usr/bin/env python3
"""Generează concepte cu Codex CLI (`image_gen`, din abonamentul ChatGPT) din brief-urile din art/*/BRIEFS.md.

  concepts.py creatures [Id ...]     un concept per creatură → art/concepts/creatures/<Id>.png
  concepts.py world [Cheie ...]      obiectele satului → art/concepts/world/<Cheie>.png

Stilul e ancorat pe art/concepts/bunica_v2_apose.png (atașată cu -i). Conceptele existente nu se refac
(șterge fișierul pentru o variantă nouă). Fiecare concept trece apoi prin art/CONCEPT_QA.md.
"""

import glob
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANCHOR = os.path.join(ROOT, "art", "concepts", "bunica_v2_apose.png")
GEN = os.path.expanduser("~/.codex/generated_images")

STYLE = ("Style: premium 3D animated feature-film look, exactly the same rendering style, materials and charm as "
         "Image 1 (the grandmother, used ONLY as a style reference — do not draw her): stylized appealing shapes, "
         "soft matte materials with fine fabric/food texture, warm saturated colors, gentle rim light.")
FRAMING_CREATURE = ("Framing for image-to-3D: ONE single character, full body, front three-quarter view (about 20 degrees), "
                    "centered with generous margin, entire figure visible including feet/base, plain pure white background, "
                    "soft even studio lighting, no ground shadow, no text, no watermark.")
RULES = ("Rules: compact readable silhouette (no very thin parts), any held object clearly gripped (fingers wrap it, "
         "thumb opposed) or attached; both feet/base flat; symmetric eyes; cute and funny for kids; no real weapons, "
         "no rude gestures, no religious or political symbols.")


def briefs(kind):
    path = os.path.join(ROOT, "art", "creatures" if kind == "creatures" else "world", "BRIEFS.md")
    rows = {}
    for line in open(path, encoding="utf-8"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if kind == "creatures" and len(cells) == 4 and cells[0] != "Id" and re.match(r"^[A-Z][A-Za-z]+$", cells[0]):
            rows[cells[0]] = {"name": cells[1], "rarity": cells[2], "concept": cells[3]}
        if kind == "world" and len(cells) == 3 and cells[0].startswith("world."):
            rows[cells[0].split(".", 1)[1]] = {"size": cells[1], "concept": cells[2]}
    return rows


def prompt(kind, key, row):
    if kind == "creatures":
        return (f"Use your built-in image generation tool to create ONE image (no code, no web search). "
                f"Intended use: concept for a collectible creature in a Roblox comedy game set in a Moldovan village; "
                f"it will be converted to a 3D model. {STYLE}\n{FRAMING_CREATURE}\n"
                f"Subject: '{row['name']}' ({row['rarity']} rarity). {row['concept']}. A living food/object character "
                f"with big expressive cartoon eyes and a clear personality.\n{RULES}\n"
                f"Reply only with the absolute path of the saved image.")
    return (f"Use your built-in image generation tool to create ONE image (no code, no web search). "
            f"Intended use: environment prop concept for a Roblox game set in a Moldovan village; it will be converted "
            f"to a 3D model. {STYLE}\nFraming for image-to-3D: ONE single object, front three-quarter view from slightly "
            f"above, centered, fully visible with margin, plain pure white background, even lighting, no ground shadow, "
            f"no text, no people.\nSubject ({row['size']} studs, proportions matter): {row['concept']}\n"
            f"Reply only with the absolute path of the saved image.")


def generate(kind, key, row):
    out_dir = os.path.join(ROOT, "art", "concepts", kind)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{key}.png")
    if os.path.exists(out):
        return out, "există"
    before = set(glob.glob(os.path.join(GEN, "*", "*.png")))
    t = time.time()
    # „--” separă promptul de -i (care acceptă mai multe fișiere); stdin închis, altfel codex îl așteaptă
    result = subprocess.run(["codex", "exec", "--skip-git-repo-check", "-s", "read-only", "-i", ANCHOR, "--",
                             prompt(kind, key, row)], capture_output=True, text=True, timeout=900,
                            stdin=subprocess.DEVNULL)
    new = sorted(set(glob.glob(os.path.join(GEN, "*", "*.png"))) - before, key=os.path.getmtime)
    if not new:
        tail = (result.stdout + result.stderr).strip().splitlines()[-3:]
        return None, "EȘEC: " + " | ".join(tail)
    subprocess.run(["cp", new[-1], out], check=True)
    return out, f"{round(time.time() - t)} s"


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "creatures"
    rows = briefs(kind)
    keys = sys.argv[2:] or list(rows)
    for key in keys:
        if kind == "creatures" and "făcut" in rows[key]["concept"]:
            rows[key]["concept"] = rows[key]["concept"].split(":", 1)[1].strip()
        path, status = generate(kind, key, rows[key])
        print(f"[concept] {kind}/{key}: {status}", flush=True)


if __name__ == "__main__":
    main()
