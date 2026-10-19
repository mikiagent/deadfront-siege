"""Point every structure GLB's Godot import at the one shared atlas material and drop the copy of
the atlas embedded in each GLB, so Godot loads a single texture for the whole set.

Run after the first `Godot --headless --path game --import` has written the .import files, then
import again: python3 tools/blender/structures/godot_import_settings.py
"""
import glob
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.abspath(os.path.join(HERE, "..", "..", "..", "game", "assets", "props", "blender"))
TRES = "res://assets/props/blender/structures_atlas.tres"
SUB = ('_subresources={\n"materials": {\n"structures_atlas": {\n"use_external/enabled": true,\n'
       '"use_external/fallback_path": "%s",\n"use_external/path": "%s"\n}\n}\n}' % (TRES, TRES))

for path in sorted(glob.glob(os.path.join(DIR, "*.glb.import"))):
    lines = open(path).read().split("\n")
    out = []
    depth = 0
    for ln in lines:
        if depth == 0 and ln.startswith("_subresources="):
            out.append(SUB)
            depth = ln.count("{") - ln.count("}")
            continue
        if depth > 0:  # drop the rest of the old multi-line value
            depth += ln.count("{") - ln.count("}")
            continue
        if ln.startswith("gltf/embedded_image_handling="):
            ln = "gltf/embedded_image_handling=0"
        out.append(ln)
    open(path, "w").write("\n".join(out))
    print("[import_settings]", os.path.basename(path))
for junk in glob.glob(os.path.join(DIR, "*_atlas_structures.jpg*")):
    os.remove(junk)
