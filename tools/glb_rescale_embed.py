#!/usr/bin/env python3
"""Re-export GLB props with a uniform scale and embedded textures (Blender headless).
Usage: Blender --background --python tools/glb_rescale_embed.py -- <in_dir> <out_dir> <scale>
Prints SIZE <name> (x,y,z) metres after scaling."""
import pathlib, sys
import bpy
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
src, dst, scale = pathlib.Path(argv[0]), pathlib.Path(argv[1]), float(argv[2])
dst.mkdir(parents=True, exist_ok=True)
for glb in sorted(src.glob("*.glb")):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    for o in bpy.data.objects:
        if o.parent is None:
            o.scale *= scale
    bpy.context.view_layer.update()
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in bpy.data.objects:
        if o.type == "MESH":
            for v in o.data.vertices:
                w = o.matrix_world @ v.co; lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    for img in bpy.data.images:
        if img.packed_file is None and img.filepath:
            try: img.pack()
            except RuntimeError: pass
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(dst / glb.name), export_format="GLB", export_yup=True, export_apply=True,
                              export_animations=False, export_image_format="AUTO", export_materials="EXPORT")
    s = hi - lo
    print(f"SIZE {glb.stem} ({s.x:.2f},{s.y:.2f},{s.z:.2f})")
