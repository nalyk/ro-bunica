"""Trusa de modelare procedurală pentru BUNICA (Blender headless).

Stil: forme rotunde, „moi”, culori plate pe vertecși (fără texturi), contur negru în joc
(Highlight). Fiecare piesă e o primitivă sau un metaball colorat; `finish` le unește,
netezește, reduce la bugetul de triunghiuri și exportă GLB.
"""

import math

import bpy
from mathutils import Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def hexcolor(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,)


def _paint(obj, color):
    mesh = obj.data
    if not mesh.color_attributes:
        mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    attr = mesh.color_attributes[0]
    # culorile din Blender sunt liniare; păstrăm sRGB-ul cerut
    lin = tuple(c**2.2 for c in color[:3]) + (1.0,)
    for item in attr.data:
        item.color = lin


def _shade(obj, smooth=True):
    for p in obj.data.polygons:
        p.use_smooth = smooth


def blob(parts, color, resolution=0.08, name="blob"):
    """Formă organică din metaball-uri: [(poziție, rază, (sx,sy,sz)), ...]."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    obj = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(obj)
    for pos, radius, *scale in parts:
        el = mb.elements.new()
        el.co = Vector(pos)
        el.radius = radius
        if scale:
            el.type = "ELLIPSOID"
            el.size_x, el.size_y, el.size_z = (radius * s for s in scale[0])
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    mesh_obj = bpy.context.object
    _shade(mesh_obj)
    _paint(mesh_obj, hexcolor(color))
    return mesh_obj


def sphere(pos, radius, color, scale=(1, 1, 1), segments=24, rings=12, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=pos, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    _shade(o)
    _paint(o, hexcolor(color))
    return o


def cylinder(pos, radius, depth, color, rot=(0, 0, 0), verts=24, bevel=0.0, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=pos, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    if bevel:
        m = o.modifiers.new("b", "BEVEL")
        m.width = bevel
        m.segments = 3
        m.limit_method = "ANGLE"
    _shade(o)
    _paint(o, hexcolor(color))
    return o


def box(pos, size, color, rot=(0, 0, 0), bevel=0.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        m = o.modifiers.new("b", "BEVEL")
        m.width = bevel
        m.segments = 3
    _shade(o)
    _paint(o, hexcolor(color))
    return o


def torus(pos, major, minor, color, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=pos, rotation=rot,
                                     major_segments=32, minor_segments=10)
    o = bpy.context.object
    o.scale = scale
    _shade(o)
    _paint(o, hexcolor(color))
    return o


def eyes(center, spacing, radius, look=(0, -1, 0), white="#FFFFFF", pupil="#1B1220", shine=True):
    """Ochi mari de desen animat, pe fața -Y (fața modelului)."""
    out = []
    cx, cy, cz = center
    for side in (-1, 1):
        x = cx + side * spacing / 2
        out.append(sphere((x, cy, cz), radius, white, scale=(1, 0.55, 1.15)))
        out.append(sphere((x + look[0] * radius * 0.2, cy - radius * 0.45, cz - radius * 0.1), radius * 0.55, pupil,
                          scale=(1, 0.5, 1.1)))
        if shine:
            out.append(sphere((x + radius * 0.2, cy - radius * 0.72, cz + radius * 0.3), radius * 0.17, "#FFFFFF",
                              scale=(1, 0.5, 1)))
    return out


def finish(name, max_tris=3000, height=None):
    """Aplică modificatorii, unește tot, scalează la `height` (studs), pune pivotul la bază."""
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > max_tris:
        m = obj.modifiers.new("dec", "DECIMATE")
        m.ratio = max_tris / tris
        bpy.ops.object.modifier_apply(modifier="dec")
    # pivot: centrul bazei
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    base = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    for v in obj.data.vertices:
        v.co -= base
    if height:
        s = height / (max(zs) - min(zs))
        obj.scale = (s, s, s)
        bpy.ops.object.transform_apply(scale=True)
    return obj


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export_glb(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    # Roblox: Y în sus; exportorul glTF convertește din Z-sus
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_materials="EXPORT")


def _material_vertex_color(obj):
    mat = bpy.data.materials.new("VC")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.65
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def preview(obj, path, size=512, yaw=25, outline=True):
    """Randare de verificare: aproximativ cum arată în joc (lumină caldă, contur negru)."""
    _material_vertex_color(obj)
    scene = bpy.context.scene
    zs = [ (obj.matrix_world @ v.co).z for v in obj.data.vertices]
    h = max(zs) - min(zs)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    dist = h * 2.6
    a = math.radians(yaw)
    cam.location = (math.sin(a) * dist * 0.6, -math.cos(a) * dist, h * 0.95)
    target = Vector((0, 0, h * 0.45))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.color = (1, 0.95, 0.85)
    sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(-30))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.75, 0.95, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.view_settings.view_transform = "Standard"
    if outline:
        scene.render.use_freestyle = True
        scene.render.line_thickness = 1.6
        fs = bpy.context.view_layer.freestyle_settings
        if not fs.linesets:
            ls = fs.linesets.new("contur")
            ls.select_by_visibility = True
            ls.select_silhouette = ls.select_border = True
            ls.select_crease = False
        lineset = fs.linesets[0]
        if lineset.linestyle is None:
            lineset.linestyle = bpy.data.linestyles.new("contur")
        lineset.linestyle.color = (0.1, 0.06, 0.05)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def tube(points, radius, color, taper=None, caps=True):
    """Tub neted printr-o listă de puncte (zâmbete, sprâncene, brațe, mustăți), cu capete rotunde."""
    if caps:
        r0 = radius * (taper[0] if taper else 1)
        r1 = radius * (taper[-1] if taper else 1)
        sphere(points[0], r0, color, segments=12, rings=6)
        sphere(points[-1], r1, color, segments=12, rings=6)
    curve = bpy.data.curves.new("tube", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    curve.use_fill_caps = True
    spline = curve.splines.new("NURBS")
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1)
    spline.use_endpoint_u = True
    spline.order_u = min(4, len(points))
    spline.resolution_u = 8
    if taper:
        for p, r in zip(spline.points, taper):
            p.radius = r
    obj = bpy.data.objects.new("tube", curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    _shade(o)
    _paint(o, hexcolor(color))
    return o


def smile(center, width, depth, radius, color, y_dir=-1):
    """Zâmbet: arc în planul feței (-Y)."""
    cx, cy, cz = center
    pts = []
    for i in range(7):
        t = i / 6 * 2 - 1
        pts.append((cx + t * width / 2, cy, cz - (1 - t * t) * depth))
    return tube(pts, radius, color)
