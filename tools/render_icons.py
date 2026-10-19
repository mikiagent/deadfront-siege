#!/usr/bin/env python3
"""Render item art: procedural Blender models (tools/blender/items/*.py) under one studio rig
to transparent 256 px PNGs in game/assets/icons/render/, plus manifest.json.

Headless only (the Blender MCP lock belongs to another package):
  Blender -b --factory-startup -P tools/render_icons.py --                 # every item
  Blender -b --factory-startup -P tools/render_icons.py -- --only a,b      # some items
  Blender -b --factory-startup -P tools/render_icons.py -- --verify a,b    # re-render, byte-compare
  ... -- --out DIR   writes elsewhere (no manifest update)
  ... -- id=path.glb renders an existing GLB through the same rig
Prints ICON <id> <bytes> <sha> per item; --verify prints REPRO PASS|FAIL.
"""
import hashlib
import importlib
import json
import pathlib
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
ITEMS_DIR = HERE / "blender" / "items"
OUT = ROOT / "game" / "assets" / "icons" / "render"
FAMILIES = ["resources", "gear", "food", "camp"]
WHITE = {"_unknown"}  # the white symbol fallback is a silhouette, not coloured art
MAX_BYTES = 64 * 1024

sys.dont_write_bytecode = True  # keep __pycache__ out of tools/blender/items
sys.path.insert(0, str(ITEMS_DIR))
import kit  # noqa: E402


def registry():
    reg = {}
    for fam in FAMILIES:
        mod = importlib.import_module(fam)
        for iid, fn in mod.ITEMS.items():
            assert iid not in reg, "duplicate item %s" % iid
            reg[iid] = ("tools/blender/items/%s.py" % fam, fn)
    return reg


def render_one(iid, build, out_dir, tmp):
    kit.reset(iid)
    if isinstance(build, str):
        import bpy
        bpy.ops.import_scene.gltf(filepath=build)
        for ob in list(bpy.context.scene.objects):
            if ob.parent is None and ob is not kit.ROOT:
                ob.parent = kit.ROOT
    else:
        build()
    kit.normalise()
    kit.stage()
    import bpy
    raw = str(pathlib.Path(tmp) / ("%s_raw.png" % iid))
    bpy.context.scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    data = kit.encode_png(kit.post(raw, white=iid in WHITE))
    path = pathlib.Path(out_dir) / ("%s.png" % iid)
    path.write_bytes(data)
    sha = hashlib.sha256(data).hexdigest()
    flag = "" if len(data) <= MAX_BYTES else " OVER_64KB"
    print("ICON %s %d %s%s" % (iid, len(data), sha[:16], flag), flush=True)
    return sha, len(data)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only, verify, out_dir, glbs = None, None, None, {}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--only":
            only = argv[i + 1].split(",")
            i += 1
        elif a == "--verify":
            verify = argv[i + 1].split(",")
            i += 1
        elif a == "--out":
            out_dir = pathlib.Path(argv[i + 1])
            i += 1
        elif "=" in a:
            k, v = a.split("=", 1)
            glbs[k] = v
        i += 1
    reg = registry()
    for k, v in glbs.items():
        reg[k] = ("glb:%s" % v, v)
    tmp = tempfile.mkdtemp(prefix="icons_")
    if verify:
        ok = True
        for iid in verify:
            sha, _ = render_one(iid, reg[iid][1], tmp, tmp)
            ref = OUT / ("%s.png" % iid)
            same = ref.exists() and hashlib.sha256(ref.read_bytes()).hexdigest() == sha
            print("REPRO %s %s" % (iid, "identical" if same else "DIFFERS"))
            ok = ok and same
        print("REPRO %s n=%d" % ("PASS" if ok else "FAIL", len(verify)))
        sys.exit(0 if ok else 1)
    ids = only or (list(glbs) if glbs else sorted(reg))
    target = out_dir or OUT
    target.mkdir(parents=True, exist_ok=True)
    results = {iid: render_one(iid, reg[iid][1], target, tmp) for iid in ids}
    if out_dir is None:
        man_path = OUT / "manifest.json"
        man = json.loads(man_path.read_text()) if man_path.exists() and only else {}
        items = man.get("items", {})
        for iid, (sha, n) in results.items():
            script, fn = reg[iid]
            items[iid] = {"script": script, "builder": iid, "png": "res://assets/icons/render/%s.png" % iid,
                          "sha256": sha, "bytes": n}
        man = {
            "_about": "Rendered item art (W1-ICONART). Regenerate with tools/render_icons.py; "
                      "models are procedural bpy builders in tools/blender/items/.",
            "rig": kit.RIG,
            "blender": __import__("bpy").app.version_string,
            "items": dict(sorted(items.items())),
        }
        man_path.write_text(json.dumps(man, indent=1) + "\n")
    over = [k for k, (_, n) in results.items() if n > MAX_BYTES]
    print("ICONS DONE n=%d over_64kb=%d" % (len(results), len(over)))


main()
