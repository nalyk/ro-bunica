"""Taie un personaj TRELLIS (o singură plasă texturată, în A-pose) în piese animabile: corp, cap, brațe.

  blender -b -P tools/split_character.py -- <intrare.glb> <ieșire.glb> --height 6.2 [--preview p.png]

Liniile de tăiere sunt în unități normalizate (înălțimea = 1, z de la -0,5 la 0,5), măsurate pe randarea
ortografică a modelului (vezi docs/ART_PIPELINE.md). Fiecare față merge în piesa în care îi cade centrul.
Pivoturile (gât, umeri) sunt exportate ca markeri mici („Pivot_Neck”, „Pivot_LeftShoulder”,
„Pivot_RightShoulder”); jocul le citește poziția, pune Motor6D-urile acolo și șterge markerii.
Fața spre -Y (→ -Z în Roblox); stânga personajului = +x în Blender.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
src, dst = argv[0], argv[1]
height = float(argv[argv.index("--height") + 1]) if "--height" in argv else 6.2
preview = argv[argv.index("--preview") + 1] if "--preview" in argv else None

# Liniile Bunicii (bunica_v2): gâtul la 68,5 %, umerii la ~73 %, marginea bundiței coboară spre mâini
NECK_Z = 0.185
HEAD_HALF_X = 0.17
SHOULDER = (0.135, 0.205)  # (|x|, z) al articulației umărului


def arm_boundary(z):
    """|x| de la care începe brațul, la înălțimea z (oblic, pe marginea bundiței)."""
    top_z, bottom_z = 0.24, -0.06
    if z >= top_z:
        return 0.135
    if z <= bottom_z:
        return 0.2
    t = (top_z - z) / (top_z - bottom_z)
    return 0.135 + t * (0.175 - 0.135)


CUFF_Z = -0.02  # sub manșete, brațul (antebrațul, mâna) se găsește prin conectivitate, nu prin poziție


def piece_by_position(c):
    if c.z > NECK_Z and abs(c.x) < HEAD_HALF_X:
        return "Head"
    if c.z > CUFF_Z and abs(c.x) > arm_boundary(c.z):
        return "LeftArm" if c.x > 0 else "RightArm"
    return "Body"


def classify(bm):
    """Piesa fiecărei fețe: poziția decide capul și mânecile; mâinile se adaugă pornind din mâneci pe fețele
    legate între ele (fusta nu e legată de mâini, deci rămâne la corp)."""
    label = {f.index: piece_by_position(f.calc_center_median()) for f in bm.faces}
    frontier = [f for f in bm.faces if label[f.index] in ("LeftArm", "RightArm")]
    while frontier:
        nxt = []
        for f in frontier:
            for e in f.edges:
                for g in e.link_faces:
                    c = g.calc_center_median()
                    if label[g.index] == "Body" and c.z <= CUFF_Z + 0.02 and abs(c.x) > 0.15 and c.z > -0.32:
                        label[g.index] = label[f.index]
                        nxt.append(g)
        frontier = nxt
    # insulele mici din zona mâinilor (degete separate de palmă), nelegate de corp, merg la brațul de pe partea lor
    seen = set()
    for f in bm.faces:
        if f.index in seen or label[f.index] != "Body":
            continue
        c = f.calc_center_median()
        if not (abs(c.x) > 0.15 and -0.32 < c.z <= CUFF_Z + 0.02):
            continue
        island, stack, touches_body = [], [f], False
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index in seen or label[h.index] != "Body":
                        continue
                    hc = h.calc_center_median()
                    if abs(hc.x) <= 0.15 or hc.z <= -0.32 or hc.z > CUFF_Z + 0.02:
                        touches_body = True
                        continue
                    seen.add(h.index)
                    stack.append(h)
        hand = Vector((0.29 if c.x > 0 else -0.29, c.y, -0.12))
        near_hand = sum(((g.calc_center_median() - hand).length for g in island)) / len(island) < 0.1
        if not touches_body and near_hand and len(island) < 600:
            side = "LeftArm" if c.x > 0 else "RightArm"
            for g in island:
                label[g.index] = side
    return label


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# normalizare: înălțimea 1, centrat pe x/y, z de la -0,5 la 0,5
vs = obj.data.vertices
lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
center = (lo + hi) / 2
span = hi.z - lo.z
for v in vs:
    v.co = (v.co - center) / span

# tăiere pe fețe (separare după material „piesă”)
pieces = ["Body", "Head", "LeftArm", "RightArm"]
bm = bmesh.new()
bm.from_mesh(obj.data)
bm.faces.ensure_lookup_table()
LABEL = classify(bm)
bm.free()

objects = {}
for name in pieces:
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = copy.data.name = name
    bpy.context.scene.collection.objects.link(copy)
    bm = bmesh.new()
    bm.from_mesh(copy.data)
    bm.faces.ensure_lookup_table()
    drop = [f for f in bm.faces if LABEL[f.index] != name]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(copy.data)
    bm.free()
    objects[name] = copy
bpy.data.objects.remove(obj)


# scara reală: baza la z = 0, înălțimea `height`
for o in objects.values():
    for v in o.data.vertices:
        v.co = Vector((v.co.x, v.co.y, v.co.z + 0.5)) * height
    for p in o.data.polygons:
        p.use_smooth = True


def marker(name, pos):
    """Marker mic de pivot, la poziția normalizată `pos` (convertită la studs), cu vârfurile în poziția finală."""
    final = Vector((pos[0], pos[1], pos[2] + 0.5)) * height
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.02, location=final)
    m = bpy.context.object
    m.name = m.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return m


marks = [marker("Pivot_Neck", (0, 0.0, NECK_Z)),
         marker("Pivot_LeftShoulder", (SHOULDER[0], 0.0, SHOULDER[1])),
         marker("Pivot_RightShoulder", (-SHOULDER[0], 0.0, SHOULDER[1]))]
everything = list(objects.values()) + marks

for name, o in objects.items():
    print("PIECE", name, sum(len(p.vertices) - 2 for p in o.data.polygons))

bpy.ops.object.select_all(action="DESELECT")
for o in everything:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_format="GLB", export_yup=True,
                          export_image_format="JPEG", export_jpeg_quality=92, export_apply=True)

if preview:
    colors = {"Body": (0.9, 0.9, 0.9, 1), "Head": (1, 0.4, 0.4, 1), "LeftArm": (0.4, 0.7, 1, 1),
              "RightArm": (0.4, 1, 0.5, 1)}
    for name, o in objects.items():
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = colors[name]
        o.data.materials.clear()
        o.data.materials.append(mat)
    scene = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = height * 1.1
    cam.location = (0, -20, height / 2)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = scene.render.resolution_y = 600
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
