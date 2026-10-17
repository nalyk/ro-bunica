"""Vopseaua schimbabilă a unui model texturat (Blender, fundal): pixelii vopsiți devin negri, cu alfa = umbra.

În Roblox, sub pixelii transparenți ai texturii se vede `MeshPart.Color`, deci rezultatul e Color × lumina
pixelului: aceeași sculptură, altă vopsea (porțile ogrăzilor, docs/RESEARCH_SAT_VIU.md §2).

    blender -b -P tools/paint_mask.py -- in.glb out.glb --hue 190,250 --min-sat 0.3
"""

import os
import sys
import tempfile

import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1 :]
src, dst = argv[0], argv[1]
hue = (190.0, 250.0)
min_sat = 0.3
for i, arg in enumerate(argv):
    if arg == "--hue":
        lo, hi = argv[i + 1].split(",")
        hue = (float(lo), float(hi))
    if arg == "--min-sat":
        min_sat = float(argv[i + 1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

painted_total = 0
for image in list(bpy.data.images):
    if image.size[0] == 0:
        continue
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[..., :3]
    v = rgb.max(axis=2)
    c = v - rgb.min(axis=2)
    s = np.where(v > 1e-4, c / np.maximum(v, 1e-4), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hdeg = np.zeros_like(v)
    nz = c > 1e-4
    rm = nz & (v == r)
    gm = nz & (v == g) & ~rm
    bm = nz & ~rm & ~gm
    hdeg[rm] = (60 * ((g - b)[rm] / c[rm])) % 360
    hdeg[gm] = 60 * ((b - r)[gm] / c[gm]) + 120
    hdeg[bm] = 60 * ((r - g)[bm] / c[bm]) + 240
    mask = (hdeg >= hue[0]) & (hdeg <= hue[1]) & (s >= min_sat) & (v > 0.08)
    if mask.sum() < 50:
        continue
    vref = float(np.percentile(v[mask], 92))
    light = np.clip(v / max(vref, 1e-3), 0, 1)
    alpha = np.clip(1 - light, 0, 0.9)
    px[..., 0][mask] = 0
    px[..., 1][mask] = 0
    px[..., 2][mask] = 0
    px[..., 3] = np.where(mask, alpha, 1.0)
    # o imagine nouă, cu alfa (exporterul glTF păstrează formatul sursei: JPEG, fără alfa); salvată ca PNG
    path = os.path.join(tempfile.mkdtemp(), "paint.png")
    fresh = bpy.data.images.new(image.name + "_paint", w, h, alpha=True)
    fresh.pixels[:] = px.reshape(-1)
    fresh.filepath_raw = path
    fresh.file_format = "PNG"
    fresh.save()
    fresh.pack()
    for mat in bpy.data.materials:
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image == image:
                    node.image = fresh
    bpy.data.images.remove(image)
    painted_total += int(mask.sum())

for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    nodes = mat.node_tree.nodes
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    base = bsdf.inputs["Base Color"].links if bsdf else []
    tex = base[0].from_node if base and base[0].from_node.type == "TEX_IMAGE" else None
    if bsdf and tex:
        mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.blend_method = "BLEND"

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="AUTO")
print(f"PAINT_OK {painted_total}")
