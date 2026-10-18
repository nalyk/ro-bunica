"""Coroana copacilor sculptați (Blender fără interfață), după post3d.

  blender -b -P tools/tree_crown.py -- <copac.glb> <ieșire.glb> [--clumps N] [--trunk-tris 1400] [--seed 7]
                                       [--preview fișier.png]

De ce: TRELLIS face trunchiul și crengile bine, dar frunzișul iese ca o coajă rară de frunze subțiri, care după
decimare arată ciuruit (2026-10-18, „all the new graphics is horrible”). Conceptele au coroane din smocuri
rotunde și pline.

Ce face:
1. citește culoarea texturii sub fiecare față: frunzele (verde), fructele (roșu, mov, galben închis) și florile
   (crem, alb) sunt scoase din trunchi, împreună cu fărâmele rămase;
2. grupează pozițiile frunzelor (k-means) și pune în fiecare grup un smoc plin (icosferă cu relief) și doi
   pui mai mici, cu culoarea medie a frunzelor din grup și umbrire coaptă în textură (sus luminos, jos umbrit);
3. pune fructele și florile pe marginea smocurilor, ca bile mici, în culorile lor;
4. trunchiul e decimat la `--trunk-tris`.
Rezultatul: două MeshPart-uri în Roblox (body = trunchiul cu textura TRELLIS, leaves = coroana cu atlasul ei).
"""

import colorsys
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector, noise

argv = sys.argv[sys.argv.index("--") + 1 :]
src, dst = argv[0], argv[1]


def opt(name, default, cast=float):
    return cast(argv[argv.index(name) + 1]) if name in argv else default


CLUMPS = opt("--clumps", 0, int)
TRUNK_TRIS = opt("--trunk-tris", 2600, int)
SEED = opt("--seed", 7, int)
LEAF_FLOOR = opt("--leaf-floor", 0.3)  # sub această fracție din înălțime nu sunt frunze
PREVIEW = opt("--preview", None, str)
random.seed(SEED)
rng = np.random.default_rng(SEED)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
body.name = "body"
body.data.name = "body"

# --- textura trunchiului: culoarea de sub fiecare față ------------------------------------------------------
image = None
for slot in body.data.materials:
    bsdf_node = slot.node_tree.nodes.get("Principled BSDF") if slot and slot.use_nodes else None
    if bsdf_node and bsdf_node.inputs["Base Color"].is_linked:
        # textura culorii (cealaltă e rugozitatea/metalul, verde în canalul G)
        image = bsdf_node.inputs["Base Color"].links[0].from_node.image
assert image is not None, "modelul nu are textură"
W, H = image.size
pixels = np.array(image.pixels[:], dtype=np.float32).reshape(H, W, image.channels)[:, :, :3]

bm = bmesh.new()
bm.from_mesh(body.data)
uv = bm.loops.layers.uv.active
bm.faces.ensure_lookup_table()

# insulele (după poziția vârfurilor: glTF desparte vârfurile la cusăturile UV): cea mai mare e trunchiul cu
# crengile; restul sunt frunzele rupte, fructele și florile
bm.faces.ensure_lookup_table()
parent = list(range(len(bm.faces)))


def find(i):
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i


owner = {}
for face in bm.faces:
    for vert in face.verts:
        key = (round(vert.co.x, 3), round(vert.co.y, 3), round(vert.co.z, 3))
        other = owner.setdefault(key, face.index)
        ra, rb = find(face.index), find(other)
        if ra != rb:
            parent[ra] = rb
groups = {}
for face in bm.faces:
    groups.setdefault(find(face.index), []).append(face)
trunk_root = max(groups, key=lambda k: len(groups[k]))
island_size = {root: len(faces) for root, faces in groups.items()}


def color_of(face):
    u = sum(loop[uv].uv.x for loop in face.loops) / len(face.loops)
    v = sum(loop[uv].uv.y for loop in face.loops) / len(face.loops)
    x = min(W - 1, max(0, int(u % 1.0 * W)))
    y = min(H - 1, max(0, int(v % 1.0 * H)))
    r, g, b = pixels[y, x]
    hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
    return (r, g, b), hue * 360, sat, val


leaves, fruits, flowers = [], [], []  # (poziție, culoare, arie)
doomed = []
for face in bm.faces:
    rgb, hue, sat, val = color_of(face)
    center, area = face.calc_center_median(), face.calc_area()
    high = center.z > LEAF_FLOOR * body.dimensions.z
    on_trunk = find(face.index) == trunk_root
    green = 65 <= hue <= 160 and sat > (0.5 if on_trunk else 0.25) and val > 0.18
    if high and green:
        leaves.append((center.copy(), rgb, area))
        doomed.append(face)
    elif on_trunk:
        continue  # scoarța rămâne întreagă (și petele ei verzui de mușchi)
    elif high and sat > 0.45 and val > 0.3 and (hue >= 330 or hue <= 14 or 260 <= hue < 330):
        fruits.append((center.copy(), rgb, area))
        doomed.append(face)
    elif high and sat < 0.22 and val > 0.74:
        flowers.append((center.copy(), rgb, area))
        doomed.append(face)
    elif island_size[find(face.index)] < 30:
        doomed.append(face)  # fărâme mici (crenguțe rupte); crengile mari rămân
bmesh.ops.delete(bm, geom=doomed, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(body.data)
bm.free()
body.data.update()

bpy.context.view_layer.objects.active = body
body.select_set(True)
for _ in range(6):  # colapsul se oprește la cusăturile UV: câteva treceri până sub țintă
    current = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if current <= TRUNK_TRIS * 1.05:
        break
    mod = body.modifiers.new("decimate", "DECIMATE")
    mod.ratio = max(0.05, TRUNK_TRIS / current)
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
print("TRUNK", len(body.data.polygons), "fețe;", len(leaves), "frunze,", len(fruits), "fructe,", len(flowers), "flori")
assert len(leaves) > 20, "nu am găsit frunziș"

# --- grupurile de frunze (k-means pe pozițiile ponderate cu aria) -------------------------------------------
points = np.array([[p.x, p.y, p.z] for p, _, _ in leaves])
colors = np.array([c for _, c, _ in leaves])
weights = np.array([a for _, _, a in leaves]) + 1e-6
lo, hi = points.min(0), points.max(0)
extent = hi - lo
crown_size = float(np.linalg.norm(extent))
k = CLUMPS or int(np.clip(round(crown_size / 3.2), 5, 11))
centers = [points[np.argmax(weights)]]
for _ in range(k - 1):  # inițializare prin cel mai depărtat punct
    d = np.min([np.linalg.norm(points - c, axis=1) for c in centers], axis=0)
    centers.append(points[np.argmax(d * weights)])
centers = np.array(centers)
for _ in range(25):
    labels = np.argmin([np.linalg.norm(points - c, axis=1) for c in centers], axis=0)
    for j in range(k):
        mask = labels == j
        if mask.any():
            centers[j] = np.average(points[mask], axis=0, weights=weights[mask])

# --- atlasul coroanei: 4×4 casete; fiecare e un gradient de verde (sus luminos, jos umbrit) cu pete de frunze ----
SIZE, CELLS = 512, 4
cell = SIZE // CELLS
atlas = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
slots = []  # (u0, v0) colțul de jos al casetei, în coordonate UV


def paint(slot, base, speckle=True, highlight=False):
    row, col = divmod(slot, CELLS)
    yy, xx = np.mgrid[0:cell, 0:cell] / cell
    top = 1.0 - yy  # rândul 0 al imaginii e sus
    shade = 0.5 + 0.68 * top**0.9
    if highlight:  # fructele: o pată de lumină
        shade = 0.75 + 0.45 * np.exp(-(((xx - 0.35) ** 2 + (top - 0.75) ** 2) / 0.02))
    px = np.array(base)[None, None, :] * shade[..., None]
    if speckle:
        # pete de frunze netede: zgomot de joasă rezoluție, mărit și estompat (fără pătrățele sau dungi)
        n = rng.standard_normal((cell // 16 + 2, cell // 16 + 2))
        n = np.kron(n, np.ones((16, 16)))[:cell, :cell]
        for _ in range(3):
            n = (np.roll(n, 4, 0) + np.roll(n, -4, 0) + np.roll(n, 4, 1) + np.roll(n, -4, 1) + n) / 5
        px *= (1.0 + 0.10 * n / max(1e-6, np.abs(n).max()))[..., None]
    atlas[row * cell : (row + 1) * cell, col * cell : (col + 1) * cell] = np.clip(px, 0, 1)
    u0, v0 = col / CELLS, 1.0 - (row + 1) / CELLS
    return (u0, v0)


def muted(rgb, gain=0.92):
    # culorile ies mai aprinse în Roblox decât în Blender: puțin mai stinse
    h, s, v = colorsys.rgb_to_hsv(*rgb)
    # măsurat în joc (2026-10-18): verdele TRELLIS iese lămâie aprins în Roblox
    return colorsys.hsv_to_rgb(h, min(1.0, s * 0.72), min(1.0, v * gain * 0.86))


leaf_mean = np.average(colors, axis=0, weights=weights)
greens = []
for j in range(min(k, 10)):
    mask = labels == j
    mean = np.average(colors[mask], axis=0, weights=weights[mask]) if mask.any() else leaf_mean
    mean = 0.6 * mean + 0.4 * leaf_mean
    mean = mean * (0.92 + 0.16 * rng.random())
    greens.append(paint(len(greens), muted(tuple(mean))))
fruit_slot = flower_slot = None
if len(fruits) < 0.004 * len(leaves):
    fruits = []  # câteva fețe roșcate de scoarță nu sunt fructe
if len(flowers) < 0.004 * len(leaves):
    flowers = []
if fruits:
    fc = np.average(np.array([c for _, c, _ in fruits]), axis=0, weights=np.array([a for _, _, a in fruits]) + 1e-6)
    fruit_slot = paint(14, muted(tuple(fc), 1.0), speckle=False, highlight=True)
if flowers:
    flower_slot = paint(15, (0.95, 0.93, 0.82), speckle=True)

img = bpy.data.images.new("crown_atlas", SIZE, SIZE, alpha=False)
rgba = np.ones((SIZE, SIZE, 4), dtype=np.float32)
rgba[:, :, :3] = atlas
img.pixels.foreach_set(rgba[::-1].ravel())
img.pack()
mat = bpy.data.materials.new("leaves")
mat.use_nodes = True
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
bsdf = mat.node_tree.nodes.get("Principled BSDF")
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9

# --- smocurile ---------------------------------------------------------------------------------------------
crown = bmesh.new()
uvc = crown.loops.layers.uv.new("UVMap")
pad = 0.04 / CELLS


def blob(center, radius, slot, subdiv, squash=0.86, bump=0.13, seed=0.0):
    """Icosferă cu relief (zgomot), UV pe gradientul casetei după înălțimea în smoc."""
    ret = bmesh.ops.create_icosphere(crown, subdivisions=subdiv, radius=1.0)
    verts = ret["verts"]
    for v in verts:
        n = v.co.normalized()
        wobble = 1.0 + bump * noise.noise(n * 2.3 + Vector((seed, seed * 1.7, seed * 0.3)))
        v.co = Vector((n.x * radius * wobble, n.y * radius * wobble, n.z * radius * wobble * squash)) + center
    faces = {f for v in verts for f in v.link_faces}
    u0, v0 = slot
    for f in faces:
        f.smooth = True
        for loop in f.loops:
            local = (loop.vert.co - center) / max(radius, 1e-3)
            height = min(1.0, max(0.0, local.z * 0.5 + 0.5))
            angle = (math.atan2(local.y, local.x) / (2 * math.pi)) % 1.0
            loop[uvc].uv = (u0 + pad + angle * (1 / CELLS - 2 * pad), v0 + pad + height * (1 / CELLS - 2 * pad))
    return verts


radii = []
for j in range(k):
    mask = labels == j
    if not mask.any():
        continue
    d = np.linalg.norm(points[mask] - centers[j], axis=1)
    r = float(np.percentile(d, 75)) + 0.06 * crown_size
    r = max(r, 0.09 * crown_size)
    radii.append((Vector(centers[j]), r))
crown_center = Vector(points.mean(0))
for j, (c, r) in enumerate(radii):
    slot = greens[j % len(greens)]
    blob(c, r, slot, 2, seed=j * 3.1)
    out = (c - crown_center)
    out = out.normalized() if out.length > 1e-3 else Vector((0, 0, 1))
    for s in range(2):  # pui mai mici, spre exterior: conturul „conopidă” din concept
        jitter = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-0.3, 0.8))).normalized()
        offset = (out * 0.6 + jitter * 0.6).normalized() * r * 0.72
        blob(c + offset, r * random.uniform(0.48, 0.62), greens[(j + s + 1) % len(greens)], 1, seed=j * 7.3 + s)

leaf_tris = sum(len(f.verts) - 2 for f in crown.faces)


def surface_points(count, lower_bias):
    """Puncte pe marginea smocurilor, mai ales pe partea de jos și din afară (fructele atârnă)."""
    out = []
    for _ in range(count):
        c, r = random.choice(radii)
        d = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1 - lower_bias))).normalized()
        out.append(c + d * r * 0.93)
    return out


if fruit_slot:
    count = int(np.clip(len(fruits) / max(1, len(leaves)) * 220, 10, 32))
    size = 0.045 * crown_size
    for p in surface_points(count, 0.9):
        blob(p, size, fruit_slot, 1, squash=1.05, bump=0.03, seed=p.x)
if flower_slot:
    count = int(np.clip(len(flowers) / max(1, len(leaves)) * 160, 8, 18))
    for p in surface_points(count, 1.2):
        for t in range(3):  # ciorchinele de salcâm atârnă
            blob(p - Vector((0, 0, t * 0.05 * crown_size)), 0.03 * crown_size, flower_slot, 1, squash=1.2, bump=0.05)

mesh = bpy.data.meshes.new("leaves")
crown.to_mesh(mesh)
crown.free()
for poly in mesh.polygons:
    poly.use_smooth = True  # smocurile rotunde, fără fațete
leaves_obj = bpy.data.objects.new("leaves", mesh)
bpy.context.scene.collection.objects.link(leaves_obj)
mesh.materials.append(mat)

tris = {
    "body": sum(len(p.vertices) - 2 for p in body.data.polygons),
    "leaves": sum(len(p.vertices) - 2 for p in leaves_obj.data.polygons),
}
size = [round(x, 3) for x in body.dimensions]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_yup=True)
print("CROWN_OK", tris)

if PREVIEW:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 500, 560
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.88, 0.96, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    corners = [o.matrix_world @ Vector(c) for o in (body, leaves_obj) for c in o.bound_box]
    lo_c = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi_c = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    height = (hi_c - lo_c).length
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = (lo_c + hi_c) / 2
    cam.location = target + Vector((height * 0.5, -height * 1.45, height * 0.2))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
