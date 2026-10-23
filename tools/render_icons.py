#!/usr/bin/env python3
"""Render item art: procedural Blender models (tools/blender/items/*.py) under one studio rig
to transparent 256 px PNGs in game/assets/icons/render/, plus manifest.json.

Headless only (the Blender MCP lock belongs to another package):
  Blender -b --factory-startup -P tools/render_icons.py --                 # every item
  Blender -b --factory-startup -P tools/render_icons.py -- --only a,b      # some items
  Blender -b --factory-startup -P tools/render_icons.py -- --verify a,b    # re-render, byte-compare
  Blender -b --factory-startup -P tools/render_icons.py -- --verify all     # every item (gate: REPRO PASS n=122)
  Blender -b --factory-startup -P tools/render_icons.py -- --selftest       # manifest planning checks, no renders
  ... -- --out DIR   writes elsewhere (no manifest update)
  ... -- id=path.glb renders an existing GLB through the same rig
  ... -- --quality model_v2 id=path.glb   the quality tier recorded for those GLB renders
Model art already in the manifest (script "glb:...") is re-rendered from its GLB on a full run or
--verify all, never overwritten by the procedural builder; if its GLB is gone it is left as it is.
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
    "iron_ingot": "grey bar stack, not distinguishable from steel_ingot / ingot at slot size",
    "steel_ingot": "grey bar stack, not distinguishable from iron_ingot / ingot at slot size",
    "obsidian": "dark crystal, not distinguishable from black_iron at slot size",
    "burnt_food": "glowing lava-crack texture shared with lava / raid_maul; reads as a fire item",
    "fish": "noisy camouflage-like blotches, reads poorly",
    # Review 2026-10-20 (4): low contrast against the dark slot interior.
    "stone_knife": "dark grey blade on the near-black slot interior; brighten the blade",
    # Review 2026-10-20 (5): the commons and uncommons now have textured model art.
    "raid_helm": "plain brown dome with two horns; epic gear that reads worse than common model art",
}
PROCEDURAL = "procedural_v1"
# Known tiers, lowest first. A GLB render (the route for better art) never becomes procedural_v1.
QUALITY_TIERS = [PROCEDURAL, "model_v2"]

# The armour kits were cut with `extract_armor --keep-skin`, so a helmet piece carries the survivor's
# face and an arm piece the bare forearms and hands. Their base-colour textures put that skin at hue
# 21-23 deg, sat ~0.44, value ~0.75 (sRGB); straw, hide, cloth and bone sit at hue 28-35 or darker.
# A face is skin when it has that colour and lies within near_m of the base body's surface.
SKIN = {"hue": (10.0, 26.0), "sat": (0.28, 0.60), "val": 0.58, "near_m": 0.03}
SPECK = 0.01  # loose islands under 1 % of a piece's faces (eyes, brows, stray scan specks) go too

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


def body_bvh(glb):
    """BVH of the base body beside an armour kit piece (<char>/armor/<kit>/<slot>.glb ->
    <char>/body/body_*.glb), or None for any other GLB. Its objects are removed again."""
    import bpy
    from mathutils.bvhtree import BVHTree
    p = pathlib.Path(glb).resolve()
    bodies = sorted((p.parent.parent.parent / "body").glob("body_*.glb")) if p.parent.parent.name == "armor" else []
    if not bodies:
        return None
    before = set(bpy.data.objects)
    for b in bodies:
        bpy.ops.import_scene.gltf(filepath=str(b))
    bpy.context.view_layer.update()
    new = [o for o in bpy.data.objects if o not in before]
    verts, faces = [], []
    for o in new:
        if o.type == "MESH" and o.vertex_groups:  # the skinned body, not bone-display shapes
            off = len(verts)
            verts += [o.matrix_world @ v.co for v in o.data.vertices]
            faces += [[off + i for i in f.vertices] for f in o.data.polygons]
    for o in new:
        bpy.data.objects.remove(o)
    return BVHTree.FromPolygons(verts, faces)


def strip_skin(ob, bvh):
    """Deletes the survivor's skin (see SKIN) and loose specks from an armour piece, so the icon
    shows the armour alone (review 2026-10-20 (5): heads under helmets, bare forearms and hands)."""
    import colorsys
    import bmesh
    import numpy as np
    img = next((ln.from_node.image for sl in ob.material_slots if sl.material and sl.material.node_tree
                for n in sl.material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"
                for ln in n.inputs["Base Color"].links if ln.from_node.type == "TEX_IMAGE"), None)
    if img is None:
        return 0, 0
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv = bm.loops.layers.uv.active
    bm.verts.index_update()
    bm.faces.index_update()
    near = [bvh.find_nearest(ob.matrix_world @ v.co)[3] for v in bm.verts]

    def is_skin(f):
        if max(near[v.index] for v in f.verts) > SKIN["near_m"]:
            return False
        c = np.mean([px[min(h - 1, int(lp[uv].uv.y * h)), min(w - 1, int(lp[uv].uv.x * w)), :3] for lp in f.loops], axis=0)
        hu, sa, va = colorsys.rgb_to_hsv(*c)
        return SKIN["hue"][0] <= hu * 360.0 <= SKIN["hue"][1] and SKIN["sat"][0] <= sa <= SKIN["sat"][1] and va >= SKIN["val"]

    cand = [is_skin(f) for f in bm.faces]
    # Neighbours by edge position, not edge: glTF import splits vertices at UV seams, so every UV
    # island would otherwise count as a loose part.
    by_edge = {}

    def ekey(e):
        return tuple(sorted(tuple(round(c, 5) for c in v.co) for v in e.verts))

    def index_edges():
        by_edge.clear()
        for f in bm.faces:
            for e in f.edges:
                by_edge.setdefault(ekey(e), []).append(f.index)
    index_edges()

    def nbrs(f):
        return {g for e in f.edges for g in by_edge[ekey(e)] if g != f.index}
    # One majority pass over edge neighbours: texture noise leaves pinholes in armour and dots on skin.
    kill = [f for f in bm.faces if 2 * (cand[f.index] + sum(cand[g] for g in nbrs(f))) > 1 + len(nbrs(f))]
    n_skin = len(kill)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.faces.index_update()
    bm.faces.ensure_lookup_table()
    index_edges()
    seen, islands = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        seen.add(f.index)
        isl, todo = [f], [f]
        while todo:
            for g in nbrs(todo.pop()):
                if g not in seen:
                    seen.add(g)
                    isl.append(bm.faces[g])
                    todo.append(bm.faces[g])
        islands.append(isl)
    specks = [f for isl in islands if len(isl) < SPECK * len(bm.faces) for f in isl]
    bmesh.ops.delete(bm, geom=specks, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    return n_skin, len(specks)


def render_one(iid, build, out_dir, tmp):
    kit.reset(iid)
    if isinstance(build, str):
        import bpy
        bpy.ops.import_scene.gltf(filepath=build)
        # Armour kit GLBs carry a stray unskinned 2 m Icosphere that shrank the framed piece to a
        # speck: when a GLB has a skinned mesh, only skinned meshes are the item.
        meshes = [ob for ob in bpy.context.scene.objects if ob.type == "MESH"]
        if any(m.type == "ARMATURE" for ob in meshes for m in ob.modifiers):
            for ob in meshes:
                if not any(m.type == "ARMATURE" for m in ob.modifiers):
                    bpy.data.objects.remove(ob)
        bvh = body_bvh(build)
        if bvh is not None:
            for ob in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
                print("STRIP %s %s skin_faces=%d speck_faces=%d" % ((iid, ob.name) + strip_skin(ob, bvh)), flush=True)
        for ob in list(bpy.context.scene.objects):
            if ob.parent is None and ob is not kit.ROOT:
                ob.parent = kit.ROOT
        # A brim with no head under it is wider than a slot can lift (forager_hood 1.56:1): lean it
        # like the flat procedural items. A no-op for art already narrow enough.
        kit.upright()
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


def held_models(man):
    """id -> repo-relative GLB path for model art already recorded in the manifest."""
    return {k: e["script"][4:] for k, e in man.get("items", {}).items() if e.get("script", "").startswith("glb:")}


def plan(reg, man, only, glbs):
    """(registry with held model art swapped in, ids to render, manifest items to start from).
    Review 2026-10-20: a full run used to start from an empty manifest and re-render every
    procedural builder, silently replacing model_v2 art with procedural art."""
    reg = dict(reg)
    keep = set()
    for k, rel in held_models(man).items():
        if k in glbs:
            continue  # this run brings a new model for it
        if (ROOT / rel).exists():
            reg[k] = ("glb:%s" % rel, str(ROOT / rel))
        else:
            reg.pop(k, None)  # its PNG and entry stay as shipped
            keep.add(k)
    ids = [i for i in (only or (list(glbs) if glbs else sorted(reg))) if i not in keep]
    for k in sorted(keep & set(only or [])):
        print("SKIP %s model art whose GLB is missing" % k)
    items = man.get("items", {})
    # A partial run (--only or GLB ids) merges; a full run keeps only the model art entries.
    base = dict(items) if (only or glbs) else {k: e for k, e in items.items() if k in held_models(man)}
    return reg, ids, base


def entry(iid, script, sha, n, rect, prev, glbs, quality):
    """Manifest entry for a fresh render of iid; prev is its old entry ({} if none)."""
    e = {"script": script, "builder": iid, "png": "res://assets/icons/render/%s.png" % iid,
         "sha256": sha, "bytes": n, "rect": rect}
    if script.startswith("glb:"):
        # New model art takes this run's --quality and clears the mark; a held model re-rendered
        # from its GLB keeps its tier and any hand-set mark (review 2026-10-20 (5): it dropped them).
        e["quality"] = quality if iid in glbs else prev.get("quality", quality)
        if iid not in glbs and "replace" in prev:
            e["replace"] = prev["replace"]
    elif "replace" in prev and iid not in REPLACE:
        e["replace"] = prev["replace"]  # keep a hand-set mark
    return e


def selftest(reg):
    """Checks plan() against a synthetic manifest; renders nothing."""
    a, b = sorted(reg)[:2]
    here = pathlib.Path(__file__).resolve().relative_to(ROOT).as_posix()  # any file that exists
    man = {"items": {
        a: {"script": "glb:" + here, "quality": "model_v2"},
        b: {"script": "glb:game/assets/no_such_model.glb", "quality": "model_v2"},
        "x_proc": {"script": "tools/blender/items/food.py", "quality": PROCEDURAL},
    }}
    fails = []
    r2, ids, base = plan(reg, man, None, {})
    if not r2[a][0].startswith("glb:"):
        fails.append("full run renders %s from its GLB, not the builder" % a)
    if b in ids or b in r2:
        fails.append("full run leaves %s alone when its GLB is missing" % b)
    if base.get(b, {}).get("quality") != "model_v2" or base.get(a, {}).get("quality") != "model_v2":
        fails.append("full run keeps model_v2 entries")
    if "x_proc" in base:
        fails.append("full run drops stale procedural entries")
    r3, ids3, base3 = plan(reg, man, [b], {})
    if ids3 or "x_proc" not in base3:
        fails.append("--only of a missing-GLB model is skipped and the merge keeps other entries")
    held = {"script": "glb:x.glb", "quality": "model_v2", "replace": "why"}
    if entry("m", "glb:x.glb", "s", 1, [0, 0, 1, 1], held, {}, "model_v2").get("replace") != "why":
        fails.append("a re-render of held model art keeps its hand-set replace mark")
    if "replace" in entry("m", "glb:y.glb", "s", 1, [0, 0, 1, 1], held, {"m": "y.glb"}, "model_v2"):
        fails.append("new model art clears the replace mark")
    for f in fails:
        print("SELFTEST FAIL %s" % f)
    print("SELFTEST %s" % ("FAIL" if fails else "PASS"))
    sys.exit(1 if fails else 0)


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
        elif a == "--selftest":
            selftest(registry())
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
    man_path = OUT / "manifest.json"
    old = json.loads(man_path.read_text()) if man_path.exists() else {}
    reg, ids, items = plan(reg, old, only, glbs)
    with tempfile.TemporaryDirectory(prefix="icons_") as tmp:  # 512 px raw renders, removed on exit
        run(reg, ids, items, verify, out_dir, glbs, quality, man_path, tmp)


def run(reg, ids, items, verify, out_dir, glbs, quality, man_path, tmp):
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
    target = out_dir or OUT
    target.mkdir(parents=True, exist_ok=True)
    results = {iid: render_one(iid, reg[iid][1], target, tmp) for iid in ids}
    if out_dir is None:
        for iid, (sha, n, rect) in results.items():
            if n > MAX_BYTES:
                continue
            items[iid] = entry(iid, reg[iid][0], sha, n, rect, items.get(iid, {}), glbs, quality)
        for iid, e in items.items():
            if e["script"].startswith("glb:"):
                e.setdefault("quality", quality)
                continue  # never restamp model art as procedural; its marks are hand-set
            e["quality"] = PROCEDURAL
            if iid in REPLACE:
                e["replace"] = REPLACE[iid]
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
