"""Trusa de modelare procedurală BUNICA (Blender 4.3, fără interfață).

Stilul: forme rotunde și moi, culori plate pe „sloturi”, contur de desen animat (coajă inversată).

Fiecare primitivă primește un SLOT (de exemplu "body", "accent", "white", "pupil"). Culorile slotului
stau în paleta modelului (`kit.palette(...)`). La export, piesele cu același slot devin un singur
MeshPart numit după slot, iar jocul îi pune culoarea din config. Așa mutațiile (Auriu, Curcubeu) pot
recolora modelul în joc. Conturul („ink”) e o copie umflată a modelului, cu normalele întoarse: Roblox
îi desenează doar spatele, deci apare ca o linie în jurul siluetei.

Convenții: fața modelului spre -Y (Blender), baza la Z = 0, centrat pe X/Y. 1 unitate = 1 stud.
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

_PALETTE: dict = {}
_OUTLINE = {"enabled": True, "thickness": None, "color": "#2A1A14"}


# ---------- configurare ----------


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _PALETTE.clear()
    _OUTLINE.update({"enabled": True, "thickness": None, "color": "#2A1A14"})


def palette(**slots):
    """Definește culorile sloturilor: palette(body="#D4A464", white="#FFFFFF", ...)."""
    _PALETTE.update(slots)


def outline(enabled=True, thickness=None, color="#2A1A14"):
    _OUTLINE.update({"enabled": enabled, "thickness": thickness, "color": color})


def hexcolor(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,)


# ---------- primitive (toate primesc un slot) ----------


def _tag(obj, slot, smooth=True):
    obj["slot"] = slot
    for p in obj.data.polygons:
        p.use_smooth = smooth
    return obj


def _active():
    return bpy.context.object


def blob(parts, slot, resolution=0.06, name="blob"):
    """Formă organică din metaball-uri: [(poziție, rază, (sx, sy, sz)?), ...] (elipsoid dacă are scală)."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = 0.6
    obj = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(obj)
    for pos, radius, *scale in parts:
        el = mb.elements.new()
        el.co = Vector(pos)
        el.radius = radius
        if scale:
            el.type = "ELLIPSOID"
            el.size_x, el.size_y, el.size_z = (radius * s for s in scale[0])
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return _tag(_active(), slot)


def sphere(pos, radius, slot, scale=(1, 1, 1), rot=(0, 0, 0), segments=20, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=pos, rotation=rot)
    o = _active()
    o.scale = scale
    return _tag(o, slot)


def cylinder(pos, radius, depth, slot, rot=(0, 0, 0), verts=20, bevel=0.0, scale=(1, 1, 1), radius2=None):
    if radius2 is not None:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=depth, location=pos,
                                        rotation=rot)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=pos, rotation=rot)
    o = _active()
    o.scale = scale
    if bevel:
        m = o.modifiers.new("b", "BEVEL")
        m.width = bevel
        m.segments = 2
        m.limit_method = "ANGLE"
    return _tag(o, slot)


def cone(pos, radius, depth, slot, rot=(0, 0, 0), verts=16, tip=0.0):
    return cylinder(pos, radius, depth, slot, rot=rot, verts=verts, radius2=tip)


def box(pos, size, slot, rot=(0, 0, 0), bevel=0.06, smooth=True):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos, rotation=rot)
    o = _active()
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        m = o.modifiers.new("b", "BEVEL")
        m.width = bevel
        m.segments = 2
    return _tag(o, slot, smooth)


def torus(pos, major, minor, slot, rot=(0, 0, 0), scale=(1, 1, 1), major_segments=28, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=pos, rotation=rot,
                                     major_segments=major_segments, minor_segments=minor_segments)
    o = _active()
    o.scale = scale
    return _tag(o, slot)


def tube(points, radius, slot, taper=None, caps=True, resolution=6):
    """Tub neted printr-o listă de puncte (zâmbete, sprâncene, brațe, mustăți), cu capete rotunde."""
    if caps:
        r0 = radius * (taper[0] if taper else 1)
        r1 = radius * (taper[-1] if taper else 1)
        sphere(points[0], r0, slot, segments=10, rings=5)
        sphere(points[-1], r1, slot, segments=10, rings=5)
    curve = bpy.data.curves.new("tube", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    curve.use_fill_caps = True
    spline = curve.splines.new("NURBS")
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1)
    spline.use_endpoint_u = True
    spline.order_u = min(4, len(points))
    spline.resolution_u = resolution
    if taper:
        for p, r in zip(spline.points, taper):
            p.radius = r
    obj = bpy.data.objects.new("tube", curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return _tag(_active(), slot)


def mirror_x(fn, *args, **kwargs):
    """Apelează `fn` pentru x și -x (pos e primul argument). Întoarce cele două obiecte."""
    pos = args[0]
    a = fn(pos, *args[1:], **kwargs)
    b = fn((-pos[0], pos[1], pos[2]), *args[1:], **kwargs)
    return a, b


def eyes(center, spacing, radius, look=(0, 0), white="white", pupil="pupil", shine="white", lids=None,
         angry=0.0, squash=1.15):
    """Ochi mari de desen animat pe fața -Y. `look` = (x, z) direcția privirii, `lids` = slotul pleoapelor
    (pleoape pe jumătate: privire șmecheră/somnoroasă), `angry` = înclinarea sprâncenelor din pleoapă."""
    cx, cy, cz = center
    out = []
    for side in (-1, 1):
        x = cx + side * spacing / 2
        out.append(sphere((x, cy, cz), radius, white, scale=(1, 0.6, squash)))
        px = x + look[0] * radius * 0.3
        pz = cz + look[1] * radius * 0.3 - radius * 0.05
        out.append(sphere((px, cy - radius * 0.5, pz), radius * 0.56, pupil, scale=(1, 0.45, 1.1)))
        out.append(sphere((px + radius * 0.2, cy - radius * 0.78, pz + radius * 0.28), radius * 0.16, shine,
                          scale=(1, 0.5, 1)))
        if lids:
            lid = sphere((x, cy + radius * 0.02, cz + radius * 0.35), radius * 1.06, lids,
                         scale=(1.02, 0.66, 0.55), rot=(0, side * angry, 0))
            out.append(lid)
    return out


# ---------- finalizare și export ----------


def _apply_all():
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return meshes


def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def _tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _decimate(obj, max_tris):
    tris = _tris(obj)
    if tris > max_tris:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        m = obj.modifiers.new("dec", "DECIMATE")
        m.ratio = max_tris / tris
        bpy.ops.object.modifier_apply(modifier="dec")


def _make_hull(objs, thickness):
    """Coaja de contur: copie a tuturor pieselor, umflată pe normale, cu normalele întoarse."""
    copies = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        copies.append(c)
    hull = _join(copies, "ink")
    bm = bmesh.new()
    bm.from_mesh(hull.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=thickness * 0.2)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * thickness
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(hull.data)
    bm.free()
    for p in hull.data.polygons:
        p.use_smooth = True
    hull["slot"] = "ink"
    return hull


def finish(name, height=None, max_tris=2600, ink_tris=1600, outline_skip=(), keep_origin=False):
    """Aplică tot, scalează la `height`, pune pivotul la bază, unește pe sloturi, adaugă conturul.
    Întoarce lista de obiecte finale (câte unul per slot, plus „ink”).

    Personaje: sloturile se scriu „Segment__slot” (de exemplu „Head__skin”), iar conturul se face pe
    fiecare segment („Head__ink”), ca să se miște cu articulația. Cu `keep_origin`, coordonatele rămân
    neschimbate (originea = HumanoidRootPart)."""
    meshes = _apply_all()
    # scara și pivotul, pe tot ansamblul
    pts = [v.co.copy() for o in meshes for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    base = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    if keep_origin:
        base = Vector((0, 0, 0))
    s = height / (hi.z - lo.z) if height and not keep_origin else 1.0
    for o in meshes:
        for v in o.data.vertices:
            v.co = (v.co - base) * s
    # pe sloturi
    groups: dict = {}
    for o in meshes:
        groups.setdefault(o.get("slot", "body"), []).append(o)
    finals = []
    total_area = {}
    for slot, objs in groups.items():
        obj = _join(objs, slot)
        total_area[slot] = sum(p.area for p in obj.data.polygons)
        finals.append(obj)
    area_sum = sum(total_area.values())
    for obj in finals:  # bugetul de triunghiuri, proporțional cu suprafața (minim 60 per slot)
        budget = max(60, int(max_tris * total_area[obj.name] / area_sum))
        _decimate(obj, budget)
    if _OUTLINE["enabled"]:
        size = (hi - lo) * s
        thickness = _OUTLINE["thickness"] or max(size.x, size.y, size.z) * 0.018
        segments: dict = {}
        for o in finals:
            if o.name in outline_skip:
                continue
            segment = o.name.split("__")[0] if "__" in o.name else ""
            segments.setdefault(segment, []).append(o)
        for segment, objs in segments.items():
            hull = _make_hull(objs, thickness)
            if segment:
                hull.name = hull.data.name = f"{segment}__ink"
            share = sum(total_area[o.name] for o in objs) / area_sum
            _decimate(hull, max(80, int(ink_tris * share)) if segment else ink_tris)
            finals.append(hull)
    return finals


def stats(objs):
    pts = [v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return {"tris": sum(_tris(o) for o in objs), "size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3),
                                                           round(hi.y - lo.y, 3)],
            "slots": {o.name: _tris(o) for o in objs}}


def export(objs, out_dir, name):
    """GLB (Y în sus) + JSON cu paleta și statisticile. Fața: -Y în Blender → -Z în Roblox (vezi rotația)."""
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_materials="NONE", export_normals=True, export_apply=True)
    meta = {"name": name, **stats(objs), "palette": {k: v for k, v in _PALETTE.items()},
            "ink": _OUTLINE["color"] if _OUTLINE["enabled"] else None}
    with open(os.path.join(out_dir, name + ".json"), "w") as handle:
        json.dump(meta, handle, indent=1)
    return path, meta


# ---------- previzualizare (aceeași tehnică de contur ca în joc) ----------


def _mat(slot):
    mat = bpy.data.materials.new(slot)
    mat.use_nodes = True
    nt = mat.node_tree
    out = nt.nodes["Material Output"]
    if slot.split("__")[-1] == "ink":
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        transp = nt.nodes.new("ShaderNodeBsdfTransparent")
        emit = nt.nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = tuple(x**2.2 for x in hexcolor(_OUTLINE["color"])[:3]) + (1,)
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
        # ca în Roblox: fețele cu spatele la cameră se elimină; coaja (cu normalele întoarse) se vede
        # doar unde partea ei din spate iese de după model, adică pe contur
        nt.links.new(emit.outputs[0], mix.inputs[1])
        nt.links.new(transp.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
        return mat
    bsdf = nt.nodes["Principled BSDF"]
    c = hexcolor(_PALETTE.get(slot.split("__")[-1], "#FF00FF"))
    bsdf.inputs["Base Color"].default_value = tuple(x**2.2 for x in c[:3]) + (1,)
    bsdf.inputs["Roughness"].default_value = 0.55
    return mat


def preview(objs, path, size=480, yaw=25, pitch=18, distance=2.1, sky="#9CC9F0"):
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(_mat(o.name))
        if o.name.split("__")[-1] == "ink":  # conturul nu umbrește modelul (în joc: CastShadow = false)
            o.visible_shadow = False
            o.visible_diffuse = False
            o.visible_glossy = False
            o.visible_transmission = False
    scene = bpy.context.scene
    pts = [v.co for o in objs for v in o.data.vertices]
    zmin = min(p.z for p in pts)
    h = max(p.z for p in pts) - zmin
    w = max(max(p.x for p in pts) - min(p.x for p in pts), max(p.y for p in pts) - min(p.y for p in pts))
    span = max(h, w)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    a, b = math.radians(yaw), math.radians(pitch)
    d = span * distance
    target = Vector((0, 0, zmin + h * 0.48))
    cam.location = target + Vector((math.sin(a) * math.cos(b) * d, -math.cos(a) * math.cos(b) * d, math.sin(b) * d))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.data.color = (1, 0.96, 0.88)
    sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = tuple(x**2.2 for x in hexcolor(sky)[:3]) + (1,)
    bg.inputs[1].default_value = 1.0
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 20
    scene.cycles.use_denoising = True
    scene.cycles.transparent_max_bounces = 16
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main(build, name, height, max_tris=2600, ink_tris=1600, keep_origin=False, **preview_kw):
    """Punctul de intrare comun al scripturilor de model: `blender -b -P model.py -- <dir-ieșire>`."""
    out = sys.argv[sys.argv.index("--") + 1]
    reset()
    build()
    objs = finish(name, height, max_tris, ink_tris, keep_origin=keep_origin)
    path, meta = export(objs, out, name)
    preview(objs, os.path.join(out, name + ".png"), **preview_kw)
    print("MODEL", json.dumps({"name": name, "tris": meta["tris"], "size": meta["size"], "slots": meta["slots"]}))
