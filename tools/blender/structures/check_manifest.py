"""Check (and optionally write) game/data/props_manifest.json against the built structure GLBs.

python3 tools/blender/structures/check_manifest.py           -> prints PASS or FAIL lines, exit 0/1
python3 tools/blender/structures/check_manifest.py --write   -> (re)writes glb/aabb_m/stages rows first

Rules: every building kind resolves to an existing GLB (a Blender `glb`, else the Kenney `model`
fallback, which is flagged art_status REPLACE). Blender GLBs: <= 4000 triangles, one material,
one atlas image, origin at the ground centre, horizontal size inside the footprint +5 %, and the
measured AABB within 5 % of the manifest's aabb_m.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True
import glb_info  # noqa: E402

GAME = os.path.abspath(os.path.join(HERE, "..", "..", "..", "game"))
MANIFEST = os.path.join(GAME, "data", "props_manifest.json")
RES = "res://assets/props/blender/%s.glb"
MAX_TRIS = 4000
TOL = 0.05

# kind -> GLB name. Kinds not listed keep their Kenney model and are marked REPLACE.
KIND_GLB = {
    "tent": "tent", "canvas_tent": "tent", "basket": "basket", "workbench": "workbench",
    "sign": "sign", "fence": "fence", "fence_gate": "gate", "campfire": "campfire",
    "bonfire": "bonfire", "stone_fire_pit": "stone_fire_pit", "drying_rack": "drying_rack",
    "smoker": "smoker", "crock_pot": "crock_pot", "steamer": "steamer", "mortar": "mortar",
    "well": "well", "catapult": "catapult", "pier": "pier", "floor": "floor", "wall": "wall",
    "wall_doorway": "wall_doorway", "roof": "roof",
}
STAGES = {"drying_rack": ["empty", "raw", "drying", "dried"]}
NODES = {
    "fence_gate": {"leaf_left": "LeafL", "leaf_right": "LeafR",
                   "note": "leaf origins sit on the hinges; swing about local Y"},
    "catapult": {"arm": "Arm", "note": "arm origin on its axle; throw = rotate about local Z"},
}
NEW_ROWS = {
    "pier": {"footprint": [3, 8], "note": "harbour pier/dock; deck 1.2 m above the pile feet, seaward end towards -Z. # ASSUMPTION: W2-TERRAIN sinks the piles into the water and snaps it to the coast"},
}


def res_to_path(res):
    return os.path.join(GAME, res[len("res://"):])


def stage_glb(kind, stage):
    base = KIND_GLB[kind]
    return base if stage == "empty" else "%s_%s" % (base, stage)


def write(manifest):
    b = manifest["buildings"]
    for kind, row in NEW_ROWS.items():
        b.setdefault(kind, dict(row))
    for kind, row in b.items():
        name = KIND_GLB.get(kind)
        if name is None:
            row["art_status"] = "REPLACE"
            row.pop("glb", None)
            continue
        s = glb_info.summary(res_to_path(RES % name))
        row["glb"] = RES % name
        row["aabb_m"] = [round(s["aabb_max"][k] - s["aabb_min"][k], 3) for k in range(3)]
        row["art_status"] = "REVIEW"
        if kind in STAGES:
            row["stages"] = [{"id": st, "glb": RES % stage_glb(kind, st)} for st in STAGES[kind]]
        if kind in NODES:
            row["nodes"] = NODES[kind]
    manifest["_about"] = (
        "Building visuals. `glb` (res:// path) is the hand-built Blender structure set "
        "(tools/blender/structures, one shared 1024 atlas) and wins when present; `aabb_m` is its "
        "measured size in Godot axes (x, y up, z) for colliders; `stages` lists per-stage GLBs for "
        "processing stations. `model` is the old Kenney Survival Kit 2.0 (CC0) name under "
        "res://assets/props/kenney/<name>.glb, kept as the fallback; rows whose art_status is "
        "REPLACE still use it and are marked for replacement (docs/orchestration/mmo/asset-replacement.md). "
        "Footprints are grid cells (1 m). model_sizes_m are the Kenney sizes (Blender x, y, z=up)."
    )


def check_glb(kind, path, fp, aabb_m, errors):
    if not os.path.exists(path):
        errors.append("%s: missing %s" % (kind, path))
        return
    s = glb_info.summary(path)
    lo, hi = s["aabb_min"], s["aabb_max"]
    size = [hi[k] - lo[k] for k in range(3)]
    name = os.path.basename(path)
    if s["tris"] > MAX_TRIS:
        errors.append("%s: %s has %d tris > %d" % (kind, name, s["tris"], MAX_TRIS))
    if s["materials"] != 1 or s["images"] != 1:
        errors.append("%s: %s has %d materials / %d images (want 1/1)" % (kind, name, s["materials"], s["images"]))
    if not (-0.06 <= lo[1] <= 0.03):
        errors.append("%s: %s base at y=%.3f, not on the ground" % (kind, name, lo[1]))
    for k, dim in ((0, fp[0]), (2, fp[1])):
        centre = (lo[k] + hi[k]) / 2
        if abs(centre) > 0.12 * dim + 0.05:
            errors.append("%s: %s origin off centre on axis %d by %.2f m" % (kind, name, k, centre))
        if size[k] > dim * (1 + TOL):
            errors.append("%s: %s %.2f m wide on axis %d, footprint %d" % (kind, name, size[k], k, dim))
    if aabb_m:
        for k in range(3):
            if abs(size[k] - aabb_m[k]) > TOL * max(aabb_m[k], 0.2):
                errors.append("%s: %s AABB %.3f vs manifest %.3f on axis %d" % (kind, name, size[k], aabb_m[k], k))
    print("[check_manifest] %-16s %-24s %4d tris  aabb %s" % (kind, name, s["tris"], [round(v, 2) for v in size]))


def main():
    with open(MANIFEST) as f:
        manifest = json.load(f)
    if "--write" in sys.argv:
        write(manifest)
        with open(MANIFEST, "w") as f:
            f.write(json.dumps(manifest, indent=2) + "\n")
    errors = []
    replace = []
    for kind, row in manifest["buildings"].items():
        fp = row.get("footprint", [1, 1])
        if row.get("glb"):
            check_glb(kind, res_to_path(row["glb"]), fp, row.get("aabb_m"), errors)
            for st in row.get("stages", []):
                check_glb("%s.%s" % (kind, st["id"]), res_to_path(st["glb"]), fp, row.get("aabb_m"), errors)
        elif row.get("model"):
            p = os.path.join(GAME, "assets", "props", "kenney", row["model"] + ".glb")
            if not os.path.exists(p):
                errors.append("%s: kenney fallback %s missing" % (kind, p))
            if row.get("art_status") != "REPLACE":
                errors.append("%s: Kenney placeholder not marked art_status REPLACE" % kind)
            replace.append(kind)
        else:
            errors.append("%s: no glb and no model" % kind)
    if replace:
        print("[check_manifest] REPLACE (Kenney placeholder, marked for replacement): " + ", ".join(replace))
    for e in errors:
        print("[check_manifest] FAIL " + e)
    if errors:
        sys.exit(1)
    print("[check_manifest] PASS %d kinds resolve to existing GLBs (%d Blender, %d Kenney marked REPLACE)"
          % (len(manifest["buildings"]), len(manifest["buildings"]) - len(replace), len(replace)))


if __name__ == "__main__":
    main()
