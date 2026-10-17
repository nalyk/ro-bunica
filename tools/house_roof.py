"""Reface acoperișul casei sculptate (Blender fără interfață), după post3d.

  blender -b -P tools/house_roof.py -- <casa.glb> <ieșire.glb> [--preview dir]

De ce: TRELLIS generează acoperișul ca o coajă subțire de țiglă, fără grosime și fără partea de jos.
Roblox desenează fețele dintr-o singură parte, deci de jos se vedea cerul prin el. Marginea țiglelor era
zdrențuită (țiglele, prea subțiri pentru rezoluția modelului, se rupeau în goluri), iar între țiglă, grinzi și
ziduri rămâneau găuri.

Ce face: taie tot ce e deasupra streașinii (acoperișul și hornul vechi) și construiește un acoperiș curat,
în patru ape, ca în concept:
- rânduri de olane cu relief real (marginea streașinii e ondulată) și o treaptă la fiecare rând;
- coame din țigle suprapuse peste cele patru muchii și peste coamă (acoperă orice îmbinare);
- scândura de streașină și tavanul de dedesubt (scânduri), care închid volumul (nimic nu se mai vede prin el);
- hornul alb cu căciulă de țiglă.
Două materiale noi, fiecare cu textura lui generată aici: „roof” (olane) și „trim” (lemn, tencuială).
Rezultatul: trei MeshPart-uri în Roblox (body, roof, trim), fiecare sub 20.000 de triunghiuri.
"""

import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
src, dst = argv[0], argv[1]
preview = argv[argv.index("--preview") + 1] if "--preview" in argv else None

# Dimensiunile măsurate pe casa post3d (înălțime 13, fața spre -Y, baza la z = 0), în studs
CUT_Z = 6.78  # tot ce trece de aici (acoperișul și hornul vechi) se șterge
SOFFIT_Z = 6.66  # tavanul de scânduri de sub streașină
EAVE_Z = 7.0  # marginea de jos a țiglelor, deasupra scândurii de streașină
RIDGE_Z = 11.75
HALF_X, HALF_Y = 9.4, 9.3  # dreptunghiul streașinii
RIDGE_HALF = 2.3  # coama, de-a lungul lui X
OVERHANG = 0.38  # țiglele trec de scândura de streașină
COL_W = 0.78  # lățimea unui olan
ROW_H = 0.92  # lungimea unui rând, pe pantă
WAVE = 0.22  # înălțimea olanelor
LIP = 0.15  # treapta dintre rânduri
SEG = 4  # segmente pe lățimea unui olan
CHIMNEY = (4.9, 0.9, 0.62)  # x, y, jumătate din latură
CHIMNEY_TOP = 12.7

random.seed(7)

# --- casa veche, fără acoperiș ----------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
body = meshes[0]
body.name = "body"
body.data.name = "body"
bm = bmesh.new()
bm.from_mesh(body.data)
doomed = [f for f in bm.faces if max(v.co.z for v in f.verts) > CUT_Z]
bmesh.ops.delete(bm, geom=doomed, context="FACES")
loose = [v for v in bm.verts if not v.link_faces]
bmesh.ops.delete(bm, geom=loose, context="VERTS")
bm.to_mesh(body.data)
bm.free()
print("BODY", len(body.data.polygons), "fețe după tăiere")


# --- texturi ------------------------------------------------------------------------------------------------
def image(name, pixels):
    h, w, _ = pixels.shape
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(pixels, 0, 1)
    img.pixels.foreach_set(rgba[::-1].ravel())  # Blender: rândul 0 e jos
    img.pack()
    return img


def tile_texture(size=512, cells=4):
    """Olane: 4×4 țigle cu nuanțe ușor diferite; lumină pe mijlocul olanului, umbră sub treapta rândului."""
    rng = np.random.default_rng(3)
    base = np.array([0.62, 0.29, 0.17])  # cărămiziu stins, ca în concept (în Roblox textura iese mai aprinsă)
    px = np.zeros((size, size, 3), dtype=np.float32)
    cell = size // cells
    yy, xx = np.mgrid[0:cell, 0:cell] / cell
    for row in range(cells):
        for col in range(cells):
            hue = base * (0.94 + 0.12 * rng.random()) + np.array([0.025, 0.0, -0.012]) * rng.standard_normal()
            across = 0.70 + 0.36 * np.cos((xx - 0.5) * math.pi * 1.6) ** 2  # rotunjimea olanului
            down = 0.62 + 0.38 * np.clip(yy / 0.2, 0, 1)  # umbra de sub rândul de deasupra (sus în celulă)
            down *= 1.0 - 0.10 * np.clip((yy - 0.9) / 0.1, 0, 1)  # muchia de jos, puțin mai închisă
            grain = 1.0 + 0.05 * rng.standard_normal((cell, cell))
            shade = (across * down * grain)[..., None]
            px[row * cell : (row + 1) * cell, col * cell : (col + 1) * cell] = hue * shade
    # pete de vreme, foarte discrete
    noise = rng.standard_normal((size // 16, size // 16))
    noise = np.kron(noise, np.ones((16, 16)))
    px *= (1.0 + 0.035 * noise)[..., None]
    return px


def trim_texture(size=512):
    """Atlas: stânga lemn (scânduri cu fibră), dreapta-sus tencuială albă, dreapta-jos funingine."""
    rng = np.random.default_rng(5)
    px = np.zeros((size, size, 3), dtype=np.float32)
    half = size // 2
    wood = np.array([0.47, 0.28, 0.16])
    yy, xx = np.mgrid[0:size, 0:half]
    plank = (yy // 32) % 2
    fiber = 0.06 * np.sin(xx / 7.0 + yy / 3.0 + rng.random() * 6) + 0.04 * rng.standard_normal((size, half))
    gaps = np.where(yy % 32 < 2, 0.55, 1.0)
    px[:, :half] = wood * ((0.92 + 0.08 * plank + fiber) * gaps)[..., None]
    plaster = np.array([0.94, 0.92, 0.87])
    px[:half, half:] = plaster * (1.0 + 0.03 * rng.standard_normal((half, half)))[..., None]
    px[half:, half:] = np.array([0.16, 0.11, 0.09]) * (1.0 + 0.1 * rng.standard_normal((half, half)))[..., None]
    return px


def material(name, img):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


roof_mat = material("roof", image("roof_tiles", tile_texture()))
trim_mat = material("trim", image("roof_trim", trim_texture()))

# Regiunile din atlasul „trim” (u0, v0, u1, v1), în coordonatele UV ale Blender (v = 0 jos)
WOOD = (0.0, 0.0, 0.5, 1.0)
PLASTER = (0.5, 0.5, 1.0, 1.0)
SOOT = (0.5, 0.0, 1.0, 0.5)


# --- acoperișul: olane pe cele patru ape ---------------------------------------------------------------------
roof = bmesh.new()
uv_roof = roof.loops.layers.uv.new("UVMap")


def add_quad(bmx, uvl, pts, uvs, smooth=True):
    verts = [bmx.verts.new(p) for p in pts]
    face = bmx.faces.new(verts)
    face.smooth = smooth
    for loop, uv in zip(face.loops, uvs):
        loop[uvl].uv = uv
    return face


rise = RIDGE_Z - EAVE_Z


def plane_frame(side):
    """Pentru o apă: originea (mijlocul streașinii), axa de-a lungul streașinii, axa în sus pe pantă,
    lungimea pantei până la coamă, jumătatea streașinii și jumătatea coamei (pe această apă)."""
    if side in ("front", "back"):
        sign = -1 if side == "front" else 1
        run, half_eave, half_top = HALF_Y, HALF_X, RIDGE_HALF
        origin = Vector((0, sign * HALF_Y, EAVE_Z))
        along = Vector((1, 0, 0)) if side == "front" else Vector((-1, 0, 0))
        up = Vector((0, -sign * run, rise)).normalized()
    else:
        sign = 1 if side == "right" else -1
        run, half_eave, half_top = HALF_X - RIDGE_HALF, HALF_Y, 0.0
        origin = Vector((sign * HALF_X, 0, EAVE_Z))
        along = Vector((0, 1, 0)) if side == "right" else Vector((0, -1, 0))
        up = Vector((-sign * run, 0, rise)).normalized()
    slope = math.hypot(run, rise)
    normal = along.cross(up).normalized()
    if normal.z < 0:
        normal = -normal
    return origin, along, up, normal, slope, half_eave, half_top


def half_width(t, half_eave, half_top, slope):
    """Jumătatea lățimii apei la distanța t în sus pe pantă (scade liniar spre coamă: muchiile)."""
    return half_eave + (half_top - half_eave) * (t / slope)


for side in ("front", "back", "right", "left"):
    origin, along, up, normal, slope, half_eave, half_top = plane_frame(side)
    rows = math.ceil((slope + OVERHANG) / ROW_H)
    t_start = -OVERHANG
    for row in range(rows):
        t0 = t_start + row * ROW_H - (0.12 if row > 0 else 0.0)  # rândurile se suprapun puțin
        t1 = min(t_start + (row + 1) * ROW_H, slope)
        if t1 <= t0:
            continue
        w0 = half_width(max(t0, 0), half_eave, half_top, slope) + (OVERHANG if t0 < 0 else 0)
        w1 = half_width(max(t1, 0), half_eave, half_top, slope)
        if w0 <= 0.05:
            continue
        step = COL_W / SEG
        count = max(2, math.ceil(2 * w0 / step))
        xs = [-w0 + i * (2 * w0 / count) for i in range(count + 1)]

        def point(x, t, lip):
            wave = WAVE * (0.5 + 0.5 * math.cos(2 * math.pi * x / COL_W))
            return origin + along * x + up * t + normal * (wave + lip)

        for i in range(count):
            xa, xb = xs[i], xs[i + 1]
            # sus, marginile se strâng spre muchii (sub coamele de pe muchii)
            ta, tb = max(-w1, min(w1, xa)), max(-w1, min(w1, xb))
            pts = [point(xa, t0, LIP), point(xb, t0, LIP), point(tb, t1, 0.0), point(ta, t1, 0.0)]
            u0, u1 = xa / (COL_W * 4), xb / (COL_W * 4)
            v0 = (row % 4) / 4 + 0.0
            v1 = v0 + 0.25
            # jos în celulă = jos pe pantă (t0); sus în celulă (umbra rândului de deasupra) = t1
            add_quad(roof, uv_roof, pts, [(u0, v0), (u1, v0), (tb / (COL_W * 4), v1), (ta / (COL_W * 4), v1)])
        if row == 0:
            # dedesubtul rândului de la streașină (se vede de jos, cât iese peste scândură)
            for i in range(count):
                xa, xb = xs[i], xs[i + 1]
                low = [
                    point(xa, t0, LIP) - normal * 0.06,
                    point(xb, t0, LIP) - normal * 0.06,
                    point(xb, t0 + OVERHANG + 0.15, 0.0) - normal * 0.2,
                    point(xa, t0 + OVERHANG + 0.15, 0.0) - normal * 0.2,
                ]
                add_quad(roof, uv_roof, list(reversed(low)), [(0, 0)] * 4)
                # muchia groasă a olanului la streașină
                add_quad(roof, uv_roof, [low[0], low[1], point(xb, t0, LIP), point(xa, t0, LIP)], [(0, 0)] * 4)

# --- dedesubtul olanelor: câte o apă plină, închisă la culoare, puțin sub țigle: prin fanta dintre două
# rânduri se vede umbră, nu cer (în „trim”, pe funingine)
under_planes = []
for side in ("front", "back", "right", "left"):
    origin, along, up, normal, slope, half_eave, half_top = plane_frame(side)
    t_low = -OVERHANG + 0.05
    w_low = half_eave + OVERHANG - 0.05
    pts = [
        origin + along * (-w_low) + up * t_low - normal * 0.03,
        origin + along * w_low + up * t_low - normal * 0.03,
        origin + along * half_top + up * slope - normal * 0.03,
        origin + along * (-half_top) + up * slope - normal * 0.03,
    ]
    if half_top <= 0:
        pts = pts[:3]
    under_planes.append(pts)

# --- coamele: țigle suprapuse peste cele 4 muchii și peste coamă -------------------------------------------------
ridge_a, ridge_b = Vector((-RIDGE_HALF, 0, RIDGE_Z)), Vector((RIDGE_HALF, 0, RIDGE_Z))
corners = [
    (Vector((HALF_X + OVERHANG * 0.7, -HALF_Y - OVERHANG * 0.7, EAVE_Z - 0.15)), ridge_b),
    (Vector((-HALF_X - OVERHANG * 0.7, -HALF_Y - OVERHANG * 0.7, EAVE_Z - 0.15)), ridge_a),
    (Vector((HALF_X + OVERHANG * 0.7, HALF_Y + OVERHANG * 0.7, EAVE_Z - 0.15)), ridge_b),
    (Vector((-HALF_X - OVERHANG * 0.7, HALF_Y + OVERHANG * 0.7, EAVE_Z - 0.15)), ridge_a),
    (ridge_a - Vector((0.12, 0, 0)), ridge_b + Vector((0.12, 0, 0))),
]
CAP_R = 0.33
CAP_LEN = 0.85
CAP_SIDES = 9
for start, end in corners:
    axis = end - start
    length = axis.length
    direction = axis.normalized()
    side_vec = direction.cross(Vector((0, 0, 1)))
    if side_vec.length < 1e-3:
        side_vec = Vector((1, 0, 0))
    side_vec.normalize()
    up_vec = side_vec.cross(direction).normalized()
    if up_vec.z < 0:
        up_vec = -up_vec
    count = max(1, math.ceil(length / CAP_LEN))
    for k in range(count):
        a = start + direction * (k * length / count)
        b = start + direction * min((k + 1) * length / count + 0.12, length + 0.05)
        ring = []
        for end_point, radius in ((a, CAP_R * 1.12), (b, CAP_R)):  # fiecare țiglă de coamă se lărgește la capăt
            pts = []
            for s in range(CAP_SIDES + 1):
                angle = math.pi * s / CAP_SIDES  # jumătate de cilindru, deschis în jos (stă pe acoperiș)
                pts.append(end_point + up_vec * 0.06 + (side_vec * math.cos(angle) + up_vec * math.sin(angle)) * radius)
            ring.append(pts)
        for s in range(CAP_SIDES):
            pts = [ring[0][s + 1], ring[0][s], ring[1][s], ring[1][s + 1]]
            u0, u1 = s / CAP_SIDES * 0.25, (s + 1) / CAP_SIDES * 0.25
            add_quad(roof, uv_roof, pts, [(u1, 0.0), (u0, 0.0), (u0, 0.25), (u1, 0.25)])
        # capătul țiglei (inelul lărgit), ca să nu se vadă prin ea
        center = a + up_vec * 0.06
        for s in range(CAP_SIDES):
            tri = [roof.verts.new(center), roof.verts.new(ring[0][s]), roof.verts.new(ring[0][s + 1])]
            face = roof.faces.new(tri)
            for loop in face.loops:
                loop[uv_roof].uv = (0.1, 0.1)

# --- hornul: alb, cu căciulă de țiglă (în „roof” căciula, în „trim” zidăria) ---------------------------------
trim = bmesh.new()
uv_trim = trim.loops.layers.uv.new("UVMap")


def box(bmx, uvl, lo, hi, region, flat=True, skip_bottom=False, skip_top=False):
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    u0, v0, u1, v1 = region
    faces = [
        ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)),  # -Y
        ((x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)),  # +Y
        ((x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)),  # +X
        ((x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)),  # -X
    ]
    if not skip_top:
        faces.append(((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)))
    if not skip_bottom:
        faces.append(((x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)))
    for pts in faces:
        add_quad(bmx, uvl, [Vector(p) for p in pts], [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], smooth=not flat)


cx, cy, ch = CHIMNEY
box(trim, uv_trim, (cx - ch, cy - ch, 9.0), (cx + ch, cy + ch, CHIMNEY_TOP), PLASTER, skip_bottom=True, skip_top=True)
# gura hornului: un pătrat de funingine puțin sub buză
box(trim, uv_trim, (cx - ch + 0.12, cy - ch + 0.12, CHIMNEY_TOP - 0.3), (cx + ch - 0.12, cy + ch - 0.12, CHIMNEY_TOP - 0.29), SOOT)
# buza hornului (un inel de tencuială)
box(trim, uv_trim, (cx - ch - 0.08, cy - ch - 0.08, CHIMNEY_TOP - 0.18), (cx + ch + 0.08, cy + ch + 0.08, CHIMNEY_TOP), PLASTER)
# căciula: un mic acoperiș în patru ape, pe patru stâlpișori
cap_h = CHIMNEY_TOP + 0.45
for dx in (-1, 1):
    for dy in (-1, 1):
        box(trim, uv_trim, (cx + dx * (ch - 0.05) - 0.07, cy + dy * (ch - 0.05) - 0.07, CHIMNEY_TOP),
            (cx + dx * (ch - 0.05) + 0.07, cy + dy * (ch - 0.05) + 0.07, cap_h), PLASTER)
apex = Vector((cx, cy, cap_h + 0.42))
corner_pts = [Vector((cx + dx * (ch + 0.22), cy + dy * (ch + 0.22), cap_h)) for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
for i in range(4):
    a, b = corner_pts[i], corner_pts[(i + 1) % 4]
    face = roof.faces.new([roof.verts.new(a), roof.verts.new(b), roof.verts.new(apex)])
    for loop, uv in zip(face.loops, [(0, 0), (0.25, 0), (0.125, 0.25)]):
        loop[uv_roof].uv = uv
    under = roof.faces.new([roof.verts.new(b), roof.verts.new(a), roof.verts.new(Vector((cx, cy, cap_h)))])
    for loop in under.loops:
        loop[uv_roof].uv = (0.1, 0.1)

for pts in under_planes:
    u0, v0, u1, v1 = SOOT
    face = trim.faces.new([trim.verts.new(p) for p in pts])
    face.smooth = False
    for loop in face.loops:
        loop[uv_trim].uv = ((u0 + u1) / 2, (v0 + v1) / 2)

# --- streașina: scândura de jur împrejur și tavanul de scânduri de dedesubt ------------------------------------
T = 0.16  # grosimea scândurii
fascia_top = EAVE_Z - 0.06
for lo, hi in (
    ((-HALF_X, -HALF_Y, SOFFIT_Z), (HALF_X, -HALF_Y + T, fascia_top)),
    ((-HALF_X, HALF_Y - T, SOFFIT_Z), (HALF_X, HALF_Y, fascia_top)),
    ((-HALF_X, -HALF_Y + T, SOFFIT_Z), (-HALF_X + T, HALF_Y - T, fascia_top)),
    ((HALF_X - T, -HALF_Y + T, SOFFIT_Z), (HALF_X, HALF_Y - T, fascia_top)),
):
    box(trim, uv_trim, lo, hi, WOOD)
# tavanul: scândurile de-a lungul lui X (UV: un rând de scânduri la fiecare ~0,6 studs)
soffit = [Vector((-HALF_X + T, -HALF_Y + T, SOFFIT_Z + 0.01)), Vector((HALF_X - T, -HALF_Y + T, SOFFIT_Z + 0.01)),
          Vector((HALF_X - T, HALF_Y - T, SOFFIT_Z + 0.01)), Vector((-HALF_X + T, HALF_Y - T, SOFFIT_Z + 0.01))]
reps = (2 * HALF_Y) / 0.6 / 16  # textura are 16 scânduri pe înălțime
add_quad(trim, uv_trim, list(reversed(soffit)), [(0.5, 0), (0.0, 0), (0.0, reps), (0.5, reps)][::-1], smooth=False)
# deasupra tavanului (nu se vede, dar închide volumul dacă privești printre olane la streașină)
add_quad(trim, uv_trim, [p + Vector((0, 0, 0.02)) for p in soffit], [(0.5, 0), (0.0, 0), (0.0, reps), (0.5, reps)],
         smooth=False)


# --- obiectele finale ------------------------------------------------------------------------------------------
def to_object(bmx, name, mat):
    bmesh.ops.remove_doubles(bmx, verts=bmx.verts, dist=1e-4)
    mesh = bpy.data.meshes.new(name)
    bmx.to_mesh(mesh)
    bmx.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(mat)
    return obj


roof_obj = to_object(roof, "roof", roof_mat)
trim_obj = to_object(trim, "trim", trim_mat)
tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (body, roof_obj, trim_obj)}
print("TRIS", tris)
assert all(t < 20000 for t in tris.values()), tris

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_yup=True)
print("ROOF_OK", tris)

if preview:
    os.makedirs(preview, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 900, 700
    for o in (body, roof_obj, trim_obj):
        for m in o.data.materials:
            if m:
                m.use_backface_culling = True  # ca în Roblox: fețele se văd dintr-o singură parte
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.color = (0.62, 0.76, 0.95)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    scene.collection.objects.link(sun)
    sun.rotation_euler = (0.85, 0.15, 0.7)
    sun.data.energy = 3.2
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 26

    def shot(name, pos, target):
        cam.location = pos
        cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(preview, name + ".png")
        bpy.ops.render.render(write_still=True)

    shot("front", (0, -24, 4), (0, 0, 7))
    shot("under_eave", (3, -11.5, 2.2), (0, -6, 8))
    shot("corner_low", (14, -14, 2.5), (0, 0, 8))
    shot("back_low", (-6, 18, 2.0), (0, 0, 8))
    shot("top", (10, -16, 22), (0, 0, 7))
