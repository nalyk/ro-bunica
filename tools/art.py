#!/usr/bin/env python3
"""Construiește modelele din `art/` (Blender fără interfață), le urcă pe Roblox și generează config-ul.

  art.py build [filtru]     construiește modelele schimbate → build/art/<cheie>.{glb,json,png} + planșă
  art.py upload [filtru]    urcă GLB-urile schimbate (assets.lock.json) și regenerează ArtAssets.luau
  art.py all [filtru]       build + upload

Cheia unui model: <categorie>.<Nume> (de exemplu creature.CartofelAgent), din art/<categorie>/<fișier>.py.
Un model se reconstruiește doar când i se schimbă scriptul sau trusa (hash pe surse), deci un upload
nou apare doar pentru modelele modificate.
"""

import glob
import hashlib
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

import assets
import cloud

ROOT = cloud.ROOT
ART = os.path.join(ROOT, "art")
OUT = os.path.join(ROOT, "build", "art")
CATEGORIES = {"creatures": "creature", "characters": "char", "world": "world", "props": "prop"}
LUAU = os.path.join(ROOT, "src", "shared", "Config", "ArtAssets.luau")


def sources():
    kit = open(os.path.join(ART, "lib", "kit.py"), "rb").read()
    for folder, prefix in CATEGORIES.items():
        for path in sorted(glob.glob(os.path.join(ART, folder, "*.py"))):
            text = open(path, "rb").read()
            # numele modelului: primul argument din kit.main(build, "Nume", ...) sau numele fișierului
            name = None
            for line in text.decode().splitlines():
                if line.startswith("kit.main(") or line.startswith("kit.main_many("):
                    name = line.split('"')[1] if '"' in line else None
            name = name or os.path.splitext(os.path.basename(path))[0]
            digest = hashlib.sha256(kit + text).hexdigest()[:16]
            yield f"{prefix}.{name}", path, digest


def build_one(key, path, digest):
    stamp = os.path.join(OUT, key + ".stamp")
    if os.path.exists(stamp) and open(stamp).read() == digest and os.path.exists(os.path.join(OUT, key + ".glb")):
        return key, "neschimbat", None
    tmp = os.path.join(OUT, "_tmp_" + key)
    os.makedirs(tmp, exist_ok=True)
    result = subprocess.run(["blender", "-b", "-P", path, "--", tmp], capture_output=True, text=True, timeout=600)
    line = next((l for l in result.stdout.splitlines() if l.startswith("MODEL ")), None)
    if result.returncode != 0 or not line:
        tail = "\n".join((result.stdout + result.stderr).splitlines()[-15:])
        return key, "EROARE", tail
    info = json.loads(line[6:])
    for ext in ("glb", "json", "png"):
        os.replace(os.path.join(tmp, f"{info['name']}.{ext}"), os.path.join(OUT, f"{key}.{ext}"))
    os.rmdir(tmp)
    with open(stamp, "w") as handle:
        handle.write(digest)
    return key, f"{info['tris']} tri, {info['size']}", None


def contact_sheet(keys):
    pngs = [os.path.join(OUT, k + ".png") for k in keys if os.path.exists(os.path.join(OUT, k + ".png"))]
    if not pngs:
        return None
    sheet = os.path.join(OUT, "_planse.png")
    labeled = []
    for p in pngs:
        out = p.replace(".png", ".lbl.png")
        subprocess.run(["convert", p, "-resize", "320x320", "-gravity", "South", "-background", "#FFF4DE",
                        "-splice", "0x28", "-pointsize", "18", "-annotate", "+0+4",
                        os.path.basename(p)[:-4], out], check=True)
        labeled.append(out)
    subprocess.run(["montage", *labeled, "-tile", "6x", "-geometry", "+4+4", "-background", "#3A2218", sheet],
                   check=True)
    for p in labeled:
        os.remove(p)
    return sheet


def build(filter_):
    os.makedirs(OUT, exist_ok=True)
    jobs = [s for s in sources() if not filter_ or filter_ in s[0]]
    failed = False
    with ThreadPoolExecutor(max_workers=4) as pool:
        for key, status, error in pool.map(lambda j: build_one(*j), jobs):
            print(f"[art] {key:34} {status}")
            if error:
                failed = True
                print(error)
    sheet = contact_sheet([k for k, _, _ in jobs])
    if sheet:
        print("[art] planșa:", sheet)
    return not failed


def color3(hexstr):
    h = hexstr.lstrip("#")
    return f"Color3.fromRGB({int(h[0:2], 16)}, {int(h[2:4], 16)}, {int(h[4:6], 16)})"


def write_luau():
    lock = assets.load_lock()
    lines = ["--!strict", "-- GENERAT de tools/art.py — nu edita de mână.",
             "-- Modelele din art/: asset-ul încărcat, culorile sloturilor (MeshPart-uri numite după slot),",
             "-- conturul („ink”) și mărimea. Lipsa unei chei = jocul folosește forma procedurală.", "",
             "export type Art = { assetId: number, palette: { [string]: Color3 }, ink: Color3?, size: Vector3 }",
             "", "return table.freeze({"]
    for key, path, _ in sources():
        meta_path = os.path.join(OUT, key + ".json")
        if key not in lock or not os.path.exists(meta_path):
            continue
        meta = json.load(open(meta_path))
        pal = ", ".join(f"{slot} = {color3(c)}" for slot, c in sorted(meta["palette"].items()))
        ink = color3(meta["ink"]) if meta.get("ink") else "nil"
        sx, sy, sz = meta["size"]
        lines.append(f'\t["{key}"] = {{ assetId = {lock[key]["id"]}, palette = {{ {pal} }}, ink = {ink}, '
                     f"size = Vector3.new({sx}, {sy}, {sz}) }},")
    lines += ["} :: { [string]: Art })", ""]
    with open(LUAU, "w") as handle:
        handle.write("\n".join(lines))
    # formatul standard al repo-ului (altfel `stylua --check` din tools.sh pică pe fișierul generat)
    subprocess.run(["bash", "-c", f'. ~/.rokit/env && cd "{ROOT}" && stylua "{LUAU}"'], check=False)
    print("[art] scris", os.path.relpath(LUAU, ROOT))


def upload(filter_):
    env = cloud.load_env()
    for key, _, _ in sources():
        if filter_ and filter_ not in key:
            continue
        glb = os.path.join(OUT, key + ".glb")
        if os.path.exists(glb):
            assets.upload(env, key, glb, "Model", f"BUNICA {key}")
    write_luau()


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("build", "upload", "all"):
        print(__doc__)
        return 2
    filter_ = sys.argv[2] if len(sys.argv) > 2 else None
    if sys.argv[1] in ("build", "all") and not build(filter_):
        return 1
    if sys.argv[1] in ("upload", "all"):
        upload(filter_)
    return 0


if __name__ == "__main__":
    sys.exit(main())
