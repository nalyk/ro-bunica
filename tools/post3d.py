"""Pregătește un GLB TRELLIS pentru Roblox (Blender fără interfață).

  blender -b -P tools/post3d.py -- <intrare.glb> <ieșire.glb> --height 4 --tris 9000 [--texture 1024] [--preview x.png]

- Decimare (colaps cu UV-urile păstrate) până la `--tris`. Roblox acceptă cel mult ~20.000 de triunghiuri
  per MeshPart; la creaturi țintim mai puțin, pentru telefoane.
- Scară: înălțimea totală devine `--height` studs; pivotul la mijlocul bazei; fața spre -Y (→ -Z în Roblox).
- Textura (baseColor) e redimensionată la `--texture` px și împachetată în GLB.
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
