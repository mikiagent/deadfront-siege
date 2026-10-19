#!/usr/bin/env python3
"""Render item art: procedural Blender models (tools/blender/items/*.py) under one studio rig
to transparent 256 px PNGs in game/assets/icons/render/, plus manifest.json.

Headless only (the Blender MCP lock belongs to another package):
  Blender -b --factory-startup -P tools/render_icons.py --                 # every item
  Blender -b --factory-startup -P tools/render_icons.py -- --only a,b      # some items
  Blender -b --factory-startup -P tools/render_icons.py -- --verify a,b    # re-render, byte-compare
  Blender -b --factory-startup -P tools/render_icons.py -- --verify all     # every item (gate: REPRO PASS n=122)
  ... -- --out DIR   writes elsewhere (no manifest update)
  ... -- id=path.glb renders an existing GLB through the same rig
  ... -- --quality model_v2 id=path.glb   the quality tier recorded for those GLB renders
Prints ICON <id> <bytes> <sha> per item; --verify prints REPRO PASS|FAIL.
"""
import hashlib
import os
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
# Owner rule: low-quality / low-poly art is marked for replacement by newer, higher-quality art.
# The whole set is procedural primitives (tier "procedural_v1"); these few read worst at slot size.
REPLACE = {
    "metal_shard": "two flat grey slabs; reads as nothing at slot size",
    "raw_hide": "flat single-colour cut-out, no fur or edge detail",
    "raptor_hide": "flat striped cut-out, no fur or edge detail",
    "dried_hide": "flat slab with painted stripes",
    "clay": "untextured blob, low poly",
    "pillar": "plain box with straps, low detail",
    "sign_kit": "bare plank on a post, low detail",
    "tent_kit": "flat cloth plane on sticks, reads poorly",
    "ingot": "generic ingot duplicate of the metal ingots",
    "raid_cuirass": "brown slab with bone dots; epic gear that reads as scrap",
    "raid_greaves": "brown slabs with bone dots; epic gear that reads as scrap",
    "cloth": "stacked coloured slabs, no fold or weave",
    "grilled_meat": "striped disc, does not read as meat",
    "armor_scute": "flat plate, no bony texture",
    "heavy_snare": "low-detail frame, reads poorly at slot size",
    # Pairs that are not told apart at slot size (review 2026-10-19).
    "capture_net_ii": "not distinguishable from capture_net_i at slot size",
    "dense_bone": "not distinguishable from bone at slot size",
    "smoked_meat": "not distinguishable from roast / seasoned_roast at slot size",
    "seasoned_roast": "not distinguishable from roast / smoked_meat at slot size",
    "pine_log": "not distinguishable from wood_log at slot size",
    "black_iron": "dark crystal, not distinguishable from obsidian at slot size",
    "berry": "plain blue sphere, no stem, leaf or cluster",
    "mango": "noisy green/orange blotches, reads poorly",
}
PROCEDURAL = "procedural_v1"
# Known tiers, lowest first. A GLB render (the route for better art) never becomes procedural_v1.
QUALITY_TIERS = [PROCEDURAL, "model_v2"]

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
    rgba = kit.post(raw, white=iid in WHITE)
    data = kit.encode_png(rgba)
    sha = hashlib.sha256(data).hexdigest()
    over = len(data) > MAX_BYTES
    if not over:  # an over-budget render never reaches the game folder
        (pathlib.Path(out_dir) / ("%s.png" % iid)).write_bytes(data)
    print("ICON %s %d %s%s" % (iid, len(data), sha[:16], " OVER_64KB (not written)" if over else ""), flush=True)
    return sha, len(data), opaque_rect(rgba)


def opaque_rect(rgba):
    """[x, y, w, h] of pixels with alpha > 0 (matches Godot's Image.get_used_rect), so the
    game fits the object without a GPU readback."""
    import numpy as np
    ys, xs = np.nonzero(rgba[..., 3])
    if len(xs) == 0:
        return [0, 0, 0, 0]
    return [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]


def missing_ids(rendered):
    """items.json ids with no render: they fall back to the white symbol and need art too."""
    items = json.loads((ROOT / "game" / "data" / "items.json").read_text()).get("items", [])
    return sorted(e["id"] for e in items if e["id"] not in rendered)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only, verify, out_dir, glbs, quality = None, None, None, {}, "model_v2"
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--only":
            only = argv[i + 1].split(",")
            i += 1
        elif a == "--verify":
            verify = argv[i + 1].split(",")
            i += 1
        elif a == "--quality":
            quality = argv[i + 1]
            assert quality in QUALITY_TIERS[1:], "--quality must be one of %s" % QUALITY_TIERS[1:]
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
        # Repo-relative in the committed manifest: never leak a developer machine path.
        rel = pathlib.Path(os.path.relpath(pathlib.Path(v).resolve(), ROOT))
        assert not str(rel).startswith(".."), "GLB must live inside the repo: %s" % v
        reg[k] = ("glb:%s" % rel.as_posix(), v)
    tmp = tempfile.mkdtemp(prefix="icons_")
    if verify:
        if verify == ["all"]:
            verify = sorted(reg)
        ok = True
        for iid in verify:
            if iid not in reg:
                print("REPRO %s UNKNOWN" % iid)
                ok = False
                continue
            sha, _, _ = render_one(iid, reg[iid][1], tmp, tmp)
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
        # A partial run (--only or GLB ids) merges; only a full run starts from scratch.
        man = json.loads(man_path.read_text()) if man_path.exists() and (only or glbs) else {}
        items = man.get("items", {})
        for iid, (sha, n, rect) in results.items():
            if n > MAX_BYTES:
                continue
            script, fn = reg[iid]
            prev = items.get(iid, {})
            items[iid] = {"script": script, "builder": iid, "png": "res://assets/icons/render/%s.png" % iid,
                          "sha256": sha, "bytes": n, "rect": rect}
            if script.startswith("glb:"):
                # New model art: this run's --quality, and the replacement mark is cleared.
                items[iid]["quality"] = quality
            elif "replace" in prev and iid not in REPLACE:
                items[iid]["replace"] = prev["replace"]  # keep a hand-set mark
        for iid, entry in items.items():
            if entry["script"].startswith("glb:"):
                entry.setdefault("quality", quality)
                continue  # never restamp model art as procedural, never re-mark it
            entry["quality"] = PROCEDURAL
            if iid in REPLACE:
                entry["replace"] = REPLACE[iid]
        man = {
            "_about": "Rendered item art (W1-ICONART). Regenerate with tools/render_icons.py; "
                      "models are procedural bpy builders in tools/blender/items/.",
            "quality": "procedural_v1 = low-poly bpy primitives, a placeholder tier; every item is to be "
                       "replaced by higher-quality art. 'replace' marks the weakest first; 'missing' lists "
                       "items.json ids with no render yet (they show the flat white symbol).",
            "rig": kit.RIG,
            "blender": __import__("bpy").app.version_string,
            "items": dict(sorted(items.items())),
            "missing": missing_ids(items),
        }
        man_path.write_text(json.dumps(man, indent=1) + "\n")
    over = [k for k, (_, n, _) in results.items() if n > MAX_BYTES]
    print("ICONS DONE n=%d over_64kb=%d" % (len(results), len(over)))
    sys.exit(1 if over else 0)


main()
