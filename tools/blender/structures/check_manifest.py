"""Check (and optionally write) game/data/props_manifest.json against the built structure GLBs.

python3 tools/blender/structures/check_manifest.py           -> prints PASS or FAIL lines, exit 0/1
python3 tools/blender/structures/check_manifest.py --write   -> (re)writes glb/aabb_m/stages rows first

Rules: every building kind resolves to an existing GLB (a Blender `glb`, else the Kenney `model`
fallback, which is flagged art_status REPLACE). Blender GLBs: <= 4000 triangles, one material named
structures_atlas and no embedded image (Godot maps that name to the shared atlas .tres), origin at the
ground centre, horizontal size inside the footprint +5 %, and the measured AABB within 5 % of the
manifest's aabb_m. A row whose glb lives outside assets/props/blender belongs to another package:
--write leaves it alone and the check only asks that the file exists.
"""
import hashlib
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
OWN_PREFIX = "res://assets/props/blender/"
MAT_NAME = "structures_atlas"  # lib.MAT_NAME; the .import files remap it to structures_atlas.tres
MAX_TRIS = 4000
TOL = 0.05
ORIGIN_TOL_M = 0.15  # origin must sit at the ground centre: a fixed limit, not one that grows with the footprint

# kind -> GLB name. Kinds not listed keep their Kenney model and are marked REPLACE.
KIND_GLB = {
    "tent": "tent", "canvas_tent": "tent", "basket": "basket", "workbench": "workbench",
    "sign": "sign", "fence": "fence", "fence_gate": "gate", "campfire": "campfire",
    "bonfire": "bonfire", "stone_fire_pit": "stone_fire_pit", "drying_rack": "drying_rack",
    "smoker": "smoker", "crock_pot": "crock_pot", "steamer": "steamer", "mortar": "mortar",
    "well": "well", "catapult": "catapult", "floor": "floor", "wall": "wall",
    "wall_doorway": "wall_doorway", "roof": "roof",
    "taming_pen": "fence",  # the pen ring is built from fence segments; same style as fence/gate
    "harbour": "pier",  # harbour.gd reads buildings.harbour.glb; the pier fits HarbourSite's 3x6 footprint
    # camp pieces that used to be Kenney placeholders (dsc camp set)
    "large_box": "large_box", "chest": "chest", "barrel": "barrel", "bucket": "bucket",
    "signpost": "signpost", "bedroll": "bedroll", "straw_roll": "straw_roll",
}
# Owner rule (2026-10-19): low-quality and low-poly assets are marked for replacement. The
# building-system pieces are bare 1 m stand-ins for W2-BUILDSYS, so they are REPLACE outright; the
# rest of the set is hand-built low-poly (<1k tris, albedo only) and stays REVIEW with an upgrade path.
STAND_INS = {"floor", "wall", "wall_doorway", "roof"}
UPGRADE = ("low-poly hand-built Blender (%d tris, 4-10 segment cylinders, albedo-only atlas, no normal "
           "map); upgrade path: higher-poly model with PBR normal/roughness, same origin, pivots and aabb_m")
STAND_IN_UPGRADE = "stand-in only; W2-BUILDSYS replaces it with the tiered modular building kit"
STAGES = {"drying_rack": ["empty", "raw", "drying", "dried"]}
NODES = {
    "fence_gate": {"leaf_left": "LeafL", "leaf_right": "LeafR",
                   "note": "leaf origins sit on the hinges; swing about local Y"},
    "catapult": {"arm": "Arm", "note": "arm origin on its axle; throw = rotate about local Z"},
}
# The taming_pen row's GLB is one 2 m ring segment, but its collider is the whole pen: taming_pen.gd
# _ring_layout puts fence/gate segments at +-1.92 m, so aabb_m is the ring's extent, not the segment's.
ASSEMBLY_AABB = {"taming_pen": [4.05, 1.84, 4.12]}
NEW_ROWS = {
    "harbour": {"footprint": [3, 6]},
}


# Notes that described the Kenney/procedural placeholder this set replaces.
NOTES = {
    "drying_rack": "Blender rack in four stages (empty, raw red strips, darker drying strips, dark dried strips); "
                   "`stages[i].glb` is the model per stage, swapped by W2-PROCESS",
    "taming_pen": "ring of 2 m Blender fence segments (fence.glb) with the gate as doorway; centre marker for the animal",
    "mortar": "placed mortar unlocks raw-meat grinding",
    "well": "placed water source for fill-bucket recipe; no finite water reserve",
    "crock_pot": "crock-pot cooking station",
    "canvas_tent": "twelve completed sleeps, eight seconds each",
    "smoker": "smoking station; no fuel/weather system yet",
    "catapult": "Manual destructible siege platform",
    "large_box": "bulk storage, ~120 slots: plank crate on skids, rope handles, lid propped open",
    "chest": "locked storage: plank chest with iron straps and a lock plate",
    "barrel": "water/brine barrel, part filled; not a drink source, fill it from a well or the sea",
    "bucket": "small wooden bucket with a rope bail",
    "signpost": "wooden signpost with two carved boards (placeable, decorative)",
    "bedroll": "minimal rest: hide bedroll with a pillow and a blanket",
    "straw_roll": "single-use straw rest roll",
    "harbour": "harbour dock: plank pier on log piles with a canvas shed, 3x6 like HarbourSite.FOOTPRINT; "
               "deck 1.2 m above the pile feet, seaward end towards -Z. HarbourSite keeps it on the coast",
}
STALE_NOTE = ("kenney", "placeholder", "until a dedicated")


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
            glb = str(row.get("glb", ""))
            if glb and not glb.startswith(OWN_PREFIX):
                continue  # another package's model: never strip it
            row.pop("glb", None)  # only a stale row of this set's own GLBs is dropped
            row["art_status"] = "REPLACE"
            continue
        s = glb_info.summary(res_to_path(RES % name))
        row["glb"] = RES % name
        row["aabb_m"] = list(ASSEMBLY_AABB.get(kind) or [round(s["aabb_max"][k] - s["aabb_min"][k], 3) for k in range(3)])
        row["art_status"] = "REPLACE" if kind in STAND_INS else "REVIEW"
        row["upgrade"] = STAND_IN_UPGRADE if kind in STAND_INS else UPGRADE % s["tris"]
        if kind in STAGES:
            row["stages"] = [{"id": st, "glb": RES % stage_glb(kind, st)} for st in STAGES[kind]]
        if kind in NODES:
            row["nodes"] = NODES[kind]
        if kind in NOTES:
            row["note"] = NOTES[kind]
    manifest["_about"] = (
        "Building visuals. `glb` (res:// path) is the hand-built Blender structure set "
        "(tools/blender/structures, one shared 1024 atlas) and wins when present; `aabb_m` is its "
        "measured size in Godot axes (x, y up, z) for colliders; `stages` lists per-stage GLBs for "
        "processing stations. `model` is the old Kenney Survival Kit 2.0 (CC0) name under "
        "res://assets/props/kenney/<name>.glb, kept as the fallback; rows whose art_status is "
        "REPLACE are marked for replacement (docs/orchestration/mmo/asset-replacement.md): Kenney rows, and "
        "the Blender building-system stand-ins. Every Blender row carries `upgrade`, its low-poly upgrade path. "
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
    if s["material_names"] != [MAT_NAME] or s["images"] != 0:
        errors.append("%s: %s has materials %s / %d images (want [%s] / 0)" % (kind, name, s["material_names"], s["images"], MAT_NAME))
    if not (-0.06 <= lo[1] <= 0.03):
        errors.append("%s: %s base at y=%.3f, not on the ground" % (kind, name, lo[1]))
    for k, dim in ((0, fp[0]), (2, fp[1])):
        centre = (lo[k] + hi[k]) / 2
        if abs(centre) > ORIGIN_TOL_M:
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
        if row.get("glb") and not row["glb"].startswith(OWN_PREFIX):
            if not os.path.exists(res_to_path(row["glb"])):
                errors.append("%s: %s missing" % (kind, row["glb"]))
            print("[check_manifest] %-16s %s (not this set's; existence only)" % (kind, row["glb"]))
        elif row.get("glb"):
            aabb = row.get("aabb_m")
            if kind in ASSEMBLY_AABB:
                if aabb != ASSEMBLY_AABB[kind] or min(aabb[0], aabb[2]) < 0.9 * min(fp):
                    errors.append("%s: aabb_m %s is not the assembled ring %s" % (kind, aabb, ASSEMBLY_AABB[kind]))
                aabb = None  # the segment GLB is checked for size against its footprint only
            check_glb(kind, res_to_path(row["glb"]), fp, aabb, errors)
            seen = {}
            for st in row.get("stages", []):
                path = res_to_path(st["glb"])
                check_glb("%s.%s" % (kind, st["id"]), path, fp, row.get("aabb_m"), errors)
                if os.path.exists(path):
                    digest = hashlib.sha1(open(path, "rb").read()).hexdigest()
                    if digest in seen:
                        errors.append("%s: stage %s is the same GLB as stage %s" % (kind, st["id"], seen[digest]))
                    seen[digest] = st["id"]
            if kind in STAND_INS and row.get("art_status") != "REPLACE":
                errors.append("%s: building-system stand-in not marked art_status REPLACE" % kind)
            if not row.get("upgrade"):
                errors.append("%s: low-poly Blender row has no upgrade path" % kind)
            if any(w in row.get("note", "").lower() for w in STALE_NOTE):
                errors.append("%s: note still describes the placeholder: %r" % (kind, row["note"]))
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
    print("[check_manifest] PASS %d kinds resolve to existing GLBs (%d Blender (%d of them stand-ins marked REPLACE), "
          "%d Kenney marked REPLACE)" % (len(manifest["buildings"]), len(manifest["buildings"]) - len(replace),
                                         len(STAND_INS), len(replace)))


if __name__ == "__main__":
    main()
