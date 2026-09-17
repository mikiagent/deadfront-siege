#!/usr/bin/env python3
"""Batch-convert FBX props to GLB for Godot, keeping material colours.

Blender headless. Quaternius packs ship FBX with flat-colour materials and no
textures, which Godot's FBX importer handles less reliably than glTF.

Usage:
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/fbx_to_glb.py -- <in_dir> <out_dir>
Prints one line per file with the model's bounding box in metres.
"""
import pathlib, sys
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = pathlib.Path(argv[0]), pathlib.Path(argv[1])
dst.mkdir(parents=True, exist_ok=True)
for fbx in sorted(src.glob("*.fbx")):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in bpy.data.objects:
        if o.type == "MESH":
            for v in o.data.vertices:
                w = o.matrix_world @ v.co
                lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    # Quaternius FBX materials import with Principled Alpha = 0, which exports as a
    # fully transparent baseColorFactor. Force opaque.
    for mat in bpy.data.materials:
        mat.blend_method = "OPAQUE"
        if mat.use_nodes:
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Alpha"].default_value = 1.0
                c = bsdf.inputs["Base Color"].default_value
                bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
        mat.diffuse_color = (mat.diffuse_color[0], mat.diffuse_color[1], mat.diffuse_color[2], 1.0)
    out = dst / (fbx.stem + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True, export_apply=True,
                              export_animations=False, export_skins=False, export_materials="EXPORT")
    size = hi - lo
    print(f"CONVERTED {out.name} size_m=({size.x:.2f},{size.y:.2f},{size.z:.2f}) tris={sum(len(p.vertices)-2 for o in bpy.data.objects if o.type=='MESH' for p in o.data.polygons)}")
