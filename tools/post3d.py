"""Pregătește un GLB TRELLIS pentru Roblox (Blender fără interfață).

  blender -b -P tools/post3d.py -- <intrare.glb> <ieșire.glb> --height 4 --tris 9000 [--texture 1024] [--preview x.png]

- Decimare (colaps cu UV-urile păstrate) până la `--tris`. Roblox acceptă cel mult ~20.000 de triunghiuri
  per MeshPart; la creaturi țintim mai puțin, pentru telefoane.
- Scară: înălțimea totală devine `--height` studs; pivotul la mijlocul bazei; fața spre -Y (→ -Z în Roblox).
- Textura (baseColor) e redimensionată la `--texture` px și împachetată în GLB.
- `--trim-base`: taie soclul din concept (piedestalul îl dă jocul). Fața de sus a soclului = cel mai înalt plan
  orizontal mare din sfertul de jos; se șterge tot ce e sub ea (talpa picioarelor rămâne deschisă, nu se vede).
- `--color-gain r,g,b`: corecție per canal a texturii (TRELLIS poate devia spre cald; factorii se măsoară pe
  zonele deschise ale corpului, concept vs textură).
"""

import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
src, dst = argv[0], argv[1]


def opt(name, default, cast=float):
    return cast(argv[argv.index(name) + 1]) if name in argv else default


height = opt("--height", 4.0)
max_tris = opt("--tris", 9000, int)
texture = opt("--texture", 1024, int)
preview = opt("--preview", None, str)
trim_base = "--trim-base" in argv
color_gain = [float(x) for x in opt("--color-gain", "1,1,1", str).split(",")]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

if trim_base:
    import bmesh

    zs = [v.co.z for v in obj.data.vertices]
    z0, z1 = min(zs), max(zs)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # aria fețelor orizontale (în sus) pe felii de 0,5 % din înălțime, în sfertul de jos
    bins = {}
    for f in bm.faces:
        c = f.calc_center_median()
        if f.normal.z > 0.9 and c.z < z0 + 0.25 * (z1 - z0):
            k = int((c.z - z0) / (z1 - z0) * 200)
            bins[k] = bins.get(k, 0) + f.calc_area()
    # plasele TRELLIS au pereți dubli: și fundul soclului are fețe în sus; fața soclului = cel mai înalt plan mare
    big = max(bins.values())
    top = z0 + (max(k for k, area in bins.items() if area > 0.3 * big) + 1) / 200 * (z1 - z0)
    drop = [f for f in bm.faces if f.calc_center_median().z < top + 0.004 * (z1 - z0)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    print("TRIM", round((top - z0) / (z1 - z0), 3))

tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if tris > max_tris:
    m = obj.modifiers.new("dec", "DECIMATE")
    m.ratio = max_tris / tris
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")

vs = obj.data.vertices
lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
base = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
s = height / (hi.z - lo.z)
for v in vs:
    v.co = (v.co - base) * s
obj.name = obj.data.name = "body"
for p in obj.data.polygons:
    p.use_smooth = True

if color_gain != [1.0, 1.0, 1.0]:
    for img in bpy.data.images:
        if img.size[0] > 0:
            px = list(img.pixels)
            for i in range(0, len(px), 4):
                px[i] = min(1.0, px[i] * color_gain[0])
                px[i + 1] = min(1.0, px[i + 1] * color_gain[1])
                px[i + 2] = min(1.0, px[i + 2] * color_gain[2])
            img.pixels.foreach_set(px)
            img.pack()

for img in bpy.data.images:
    if img.size[0] > texture:
        img.scale(texture, int(texture * img.size[1] / img.size[0]))
        img.pack()

final_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
size = [round((hi.x - lo.x) * s, 3), round(height, 3), round((hi.y - lo.y) * s, 3)]
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_format="GLB", export_yup=True,
                          export_image_format="JPEG", export_jpeg_quality=92, export_apply=True)
print("POST", {"tris": final_tris, "size": size})

if preview:
    scene = bpy.context.scene
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.78, 0.94, 1)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 20
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 360, 420
    scene.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    c = Vector((0, 0, height * 0.5))
    a = math.radians(25)
    d = max(size) * 2.3
    cam.location = c + Vector((math.sin(a) * d, -math.cos(a) * d, height * 0.2))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = preview
    bpy.ops.render.render(write_still=True)
