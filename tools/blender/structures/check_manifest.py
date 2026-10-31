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
    # house kit (modular house parts, three material tiers): the same 2 m module in every tier
    "house_foundation": "house_foundation", "house_floor": "house_floor", "house_wall": "house_wall",
    "house_wall_window": "house_wall_window", "house_wall_doorway": "house_wall_doorway",
    "house_door": "house_door", "house_roof": "house_roof", "house_roof_corner": "house_roof_corner",
    "house_roof_gable": "house_roof_gable", "house_stairs": "house_stairs",
    "house_wall_timber": "house_wall_timber", "house_wall_window_timber": "house_wall_window_timber",
    "house_roof_timber": "house_roof_timber", "house_wall_stone": "house_wall_stone",
    "house_wall_window_stone": "house_wall_window_stone", "house_roof_stone": "house_roof_stone",
    "taming_pen": "fence",  # the pen ring is built from fence segments; same style as fence/gate
    "harbour": "pier",  # harbour.gd reads buildings.harbour.glb; the pier fits HarbourSite's 3x6 footprint
    # camp pieces that used to be Kenney placeholders (dsc camp set)
    "large_box": "large_box", "chest": "chest", "barrel": "barrel", "bucket": "bucket",
    "signpost": "signpost", "bedroll": "bedroll", "straw_roll": "straw_roll",
    "campfire_stand": "campfire_stand", "technical_workbench": "technical_workbench",
    "grindstone": "grindstone", "fishing_stand": "fishing_stand", "stone_grill": "stone_grill",
    "tent_canvas": "tent_canvas", "fence_fortified": "fence_fortified", "field_small": "field_small",
    "field_large": "field_large", "log_shelter": "log_shelter", "cabin_bed": "cabin_bed",
    # station art (dsc-stationart): the workbench tiers, the processing stations and the
    # construction-site stages
    "makeshift_workbench": "makeshift_workbench", "basic_workbench": "basic_workbench",
    "journeyman_workbench": "journeyman_workbench", "expert_workbench": "expert_workbench",
    "kiln": "kiln", "loom": "loom", "large_loom": "large_loom", "oven": "oven",
    "large_drying_rack": "large_drying_rack",
    "site_small_0": "site_small_0", "site_small_1": "site_small_1", "site_small_2": "site_small_2",
    "site_large_0": "site_large_0", "site_large_1": "site_large_1", "site_large_2": "site_large_2",
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
# Farm kit (dsc farmkit): models the game does not place as buildings yet (field plots, crop stages,
# path tiles and farm props). They live in their own manifest section so they never become a
# placeable kind, and the game can pick them up by name later.
FARM_MODELS = {
    "field_tilled": "tilled 2 x 2 m plot: dark furrowed soil, furrow rows, raised earth edge",
    "field_crop_0": "plot with seedlings (growth stage 0)",
    "field_crop_1": "plot with young plants (growth stage 1)",
    "field_crop_2": "plot with grown plants (growth stage 2)",
    "field_crop_3": "plot with ripe plants (growth stage 3, harvestable)",
    "path_dirt": "2 x 2 m packed dirt path tile, edges blend into the grass",
    "path_dirt_corner": "dirt path corner tile: the strip turns, grass inside the turn",
    "path_stone": "2 x 2 m flat stone path tile",
    "path_stone_corner": "stone path corner tile: the stones turn, grass inside the turn",
    "fence_post_rail": "2 m rail fence run with lashed posts",
    "fence_post_rail_gate": "2 m gate run with a hinged leaf (node Leaf, origin on the hinge)",
    "trellis": "bean trellis with climbing vines",
    "scarecrow": "scarecrow on a cross frame",
    "compost_heap": "slatted compost bin with a fork leaning on it",
    "water_trough": "wooden water trough with iron bands",
}
FARM_NOTE = ("farm kit model (dsc farmkit): %s. Sizes are an assumption: a field module is 2 x 2 m "
             "and a path tile 2 x 2 m, at most 0.05 m high")
NEW_ROWS = {
    "harbour": {"footprint": [3, 6]},
    # station art (dsc-stationart). Footprints are grid cells (1 m): the workbench tiers take the
    # same 2x1 cell as the old workbench row, the sites take the footprint they are staked out on.
    "makeshift_workbench": {"footprint": [2, 1]},
    "basic_workbench": {"footprint": [2, 1]},
    "journeyman_workbench": {"footprint": [2, 1]},
    "expert_workbench": {"footprint": [2, 1]},
    "kiln": {"footprint": [2, 2]},
    "loom": {"footprint": [2, 1]},
    "large_loom": {"footprint": [3, 2]},
    "oven": {"footprint": [2, 2]},
    "large_drying_rack": {"footprint": [3, 1]},
    "site_small_0": {"footprint": [2, 2]},
    "site_small_1": {"footprint": [2, 2]},
    "site_small_2": {"footprint": [2, 2]},
    "site_large_0": {"footprint": [3, 3]},
    "site_large_1": {"footprint": [3, 3]},
    "site_large_2": {"footprint": [3, 3]},
}
# The house kit rows are added by --write (they are modular parts, not placeable grid cells, so
# they carry their module footprint instead of a 1 m grid footprint).
HOUSE_ROWS = {
    "house_foundation": {"footprint": [2, 2], "note": "stone plinth under a house module; sinks up to 0.5 m into the ground"},
    "house_floor": {"footprint": [2, 2], "note": "plank floor deck of a 2 x 2 m house module"},
    "house_wall": {"footprint": [2, 1], "note": "log wall of a 2 m house module (2.4 m storey)"},
    "house_wall_window": {"footprint": [2, 1], "note": "log wall with a glazed 0.9 x 0.9 m window"},
    "house_wall_doorway": {"footprint": [2, 1], "note": "log wall with a 1.0 x 2.0 m doorway"},
    "house_door": {"footprint": [1, 1], "note": "hinged plank door leaf; its origin is the hinge"},
    "house_roof": {"footprint": [2, 1], "note": "thatch roof slope of a 2 m house module"},
    "house_roof_corner": {"footprint": [1, 1], "note": "thatch hip cap for a roof corner"},
    "house_roof_gable": {"footprint": [1, 2], "note": "boarded gable end that closes the roof"},
    "house_stairs": {"footprint": [2, 2], "note": "timber stair up to a house floor"},
    "house_wall_timber": {"footprint": [2, 1], "note": "timber-frame wall of a 2 m house module"},
    "house_wall_window_timber": {"footprint": [2, 1], "note": "timber-frame wall with a glazed window"},
    "house_roof_timber": {"footprint": [2, 1], "note": "dark shingle roof slope of a 2 m house module"},
    "house_wall_stone": {"footprint": [2, 1], "note": "stone wall of a 2 m house module"},
    "house_wall_window_stone": {"footprint": [2, 1], "note": "stone wall with a glazed window"},
    "house_roof_stone": {"footprint": [2, 1], "note": "slate roof slope of a 2 m house module"},
}

# The house kit is modular: its parts are sized by the house module (2.0 m x 2.0 m, a 2.4 m
# storey), not by the 1 m build grid, and some parts are not ground-standing (a roof slope hangs
# on a wall top, a foundation sinks into the ground) or not centred (the door leaf's origin is
# its hinge). `footprint` is the module footprint in metres; `ground` says the part stands on
# the ground; `hinge` says the origin sits on a pivot, not on the part's centre.
HOUSE_KIT = {
    "house_foundation": {"footprint": [2, 2], "ground": False},
    "house_floor": {"footprint": [2, 2]},
    "house_wall": {"footprint": [2, 1]},
    "house_wall_window": {"footprint": [2, 1]},
    "house_wall_doorway": {"footprint": [2, 1]},
    "house_door": {"footprint": [1, 1], "hinge": True},
    "house_roof": {"footprint": [2, 1], "ground": False},
    "house_roof_corner": {"footprint": [1, 1], "ground": False},
    "house_roof_gable": {"footprint": [1, 2], "ground": False},
    "house_stairs": {"footprint": [2, 2]},
    "house_wall_timber": {"footprint": [2, 1]},
    "house_wall_window_timber": {"footprint": [2, 1]},
    "house_roof_timber": {"footprint": [2, 1], "ground": False},
    "house_wall_stone": {"footprint": [2, 1]},
    "house_wall_window_stone": {"footprint": [2, 1]},
    "house_roof_stone": {"footprint": [2, 1], "ground": False},
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
    "campfire_stand": "cooking upgrade of the campfire: stone fire, spit and hanging pot",
    "technical_workbench": "heavy workbench with anvil, vise, hammer and tongs",
    "grindstone": "tool repair station: cranked round stone with a water trough",
    "fishing_stand": "fish-drying rack over a smoulder pit (placeable, decorative)",
    "stone_grill": "flat stone grill over a hearth ring",
    "tent_canvas": "cheap shade tent: canvas fly on poles with open sides",
    "fence_fortified": "fortified palisade run, 2 m; neighbours meet end to end like the plain fence",
    "field_small": "small tilled farm plot (hoe + seed) inside a log border",
    "field_large": "large tilled farm plot inside a log border",
    "log_shelter": "small log hut with a thatch roof and an open front",
    "cabin_bed": "wooden bed with a hide mattress and fur blanket",
    "harbour": "harbour dock: plank pier on log piles with a canvas shed, 3x6 like HarbourSite.FOOTPRINT; "
               "deck 1.2 m above the pile feet, seaward end towards -Z. HarbourSite keeps it on the coast",
    "makeshift_workbench": "workbench tier 0: lashed sticks and a flat stone slab; starter recipes",
    "basic_workbench": "workbench tier 1: rough planks on pillars with strap lashings",
    "journeyman_workbench": "workbench tier 2: trimmed planks, nailed, with a vice and a tool rack",
    "expert_workbench": "workbench tier 3: processed planks, iron fittings, drawers and glue pots",
    "kiln": "kiln station: clay dome with a firebox mouth and a chimney",
    "loom": "loom station: upright frame loom with warp threads and a partly woven cloth",
    "large_loom": "large loom station: wider frame with a weaver's bench and a cloth roll",
    "oven": "oven station: stone bread oven with a firebox mouth and a flue",
    "large_drying_rack": "large drying rack: two-bay rack on trimmed pillars",
    "site_small_0": "construction site (2x2), stage 0: staked-out ground with a string outline and a "
                    "pile of logs and straps",
    "site_small_1": "construction site (2x2), stage 1: scaffold frame half up, smaller material piles",
    "site_small_2": "construction site (2x2), stage 2: scaffold at full height with partial plank cladding",
    "site_large_0": "construction site (3x3), stage 0: staked-out ground with a string outline and a "
                    "pile of logs and straps",
    "site_large_1": "construction site (3x3), stage 1: scaffold frame half up, smaller material piles",
    "site_large_2": "construction site (3x3), stage 2: scaffold at full height with partial plank cladding",
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
    for kind, row in HOUSE_ROWS.items():
        b.setdefault(kind, dict(row))
    for kind, row in b.items():
        name = KIND_GLB.get(kind)
        if kind in HOUSE_KIT:
            row["footprint"] = HOUSE_KIT[kind]["footprint"]
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
        if kind in HOUSE_KIT and HOUSE_KIT[kind].get("hinge"):
            row["nodes"] = {"leaf": "house_door", "note": "leaf origin is the hinge; swing about local Y"}
        row["art_status"] = "REPLACE" if kind in STAND_INS else "REVIEW"
        row["upgrade"] = STAND_IN_UPGRADE if kind in STAND_INS else UPGRADE % s["tris"]
        if kind in STAGES:
            row["stages"] = [{"id": st, "glb": RES % stage_glb(kind, st)} for st in STAGES[kind]]
        if kind in NODES:
            row["nodes"] = NODES[kind]
        if kind in NOTES:
            row["note"] = NOTES[kind]
    write_farm(manifest)
    manifest["_about"] = (
        "Building visuals. `glb` (res:// path) is the hand-built Blender structure set "
        "(tools/blender/structures, one shared 1024 atlas) and wins when present; `aabb_m` is its "
        "measured size in Godot axes (x, y up, z) for colliders; `stages` lists per-stage GLBs for "
        "processing stations. `model` is the old Kenney Survival Kit 2.0 (CC0) name under "
        "res://assets/props/kenney/<name>.glb, kept as the fallback; rows whose art_status is "
        "REPLACE are marked for replacement (docs/orchestration/mmo/asset-replacement.md): Kenney rows, and "
        "the Blender building-system stand-ins. Every Blender row carries `upgrade`, its low-poly upgrade path. "
        "Footprints are grid cells (1 m). model_sizes_m are the Kenney sizes (Blender x, y, z=up). "
        "`farm` holds the farm kit models (dsc farmkit: field plots, crop stages, path tiles and farm "
        "props). They are not placeable building kinds; the game picks them up by name."
    )


def write_farm(manifest):
    """The farm kit's own section: models that are not placeable building kinds."""
    farm = manifest.setdefault("farm", {})
    for name, note in FARM_MODELS.items():
        path = os.path.join(GAME, "assets", "props", "blender", name + ".glb")
        if not os.path.exists(path):
            continue
        s = glb_info.summary(path)
        row = farm.setdefault(name, {})
        row["glb"] = RES % name
        row["aabb_m"] = [round(s["aabb_max"][k] - s["aabb_min"][k], 3) for k in range(3)]
        row["tris"] = s["tris"]
        row["art_status"] = "REVIEW"
        row["note"] = FARM_NOTE % note
        row["upgrade"] = UPGRADE % s["tris"]
    if "fence_post_rail_gate" in farm:
        farm["fence_post_rail_gate"]["nodes"] = {
            "leaf": "Leaf", "note": "leaf origin sits on the hinge; swing about local Y"}


def check_glb(kind, path, fp, aabb_m, errors):
    if not os.path.exists(path):
        errors.append("%s: missing %s" % (kind, path))
        return
    s = glb_info.summary(path)
    lo, hi = s["aabb_min"], s["aabb_max"]
    size = [hi[k] - lo[k] for k in range(3)]
    name = os.path.basename(path)
    kit = HOUSE_KIT.get(kind)
    if s["tris"] > MAX_TRIS:
        errors.append("%s: %s has %d tris > %d" % (kind, name, s["tris"], MAX_TRIS))
    if s["material_names"] != [MAT_NAME] or s["images"] != 0:
        errors.append("%s: %s has materials %s / %d images (want [%s] / 0)" % (kind, name, s["material_names"], s["images"], MAT_NAME))
    if not (-0.06 <= lo[1] <= 0.03) and not (kit and not kit.get("ground", True)):
        errors.append("%s: %s base at y=%.3f, not on the ground" % (kind, name, lo[1]))
    for k, dim in ((0, fp[0]), (2, fp[1])):
        centre = (lo[k] + hi[k]) / 2
        if abs(centre) > ORIGIN_TOL_M and not (kit and kit.get("hinge")):
            errors.append("%s: %s origin off centre on axis %d by %.2f m" % (kind, name, k, centre))
        # a house part is sized by the house module, not the 1 m build grid, so it gets a looser
        # bound (an eave board or a hip roll may overhang its module)
        limit = dim * (1.2 if kit else 1 + TOL)
        if size[k] > limit:
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
    farm = manifest.get("farm", {})
    for name, row in farm.items():
        path = res_to_path(str(row.get("glb", "")))
        if not os.path.exists(path):
            errors.append("farm.%s: missing %s" % (name, path))
            continue
        s = glb_info.summary(path)
        size = [s["aabb_max"][k] - s["aabb_min"][k] for k in range(3)]
        if s["tris"] > MAX_TRIS:
            errors.append("farm.%s: %d tris > %d" % (name, s["tris"], MAX_TRIS))
        if s["material_names"] != [MAT_NAME] or s["images"] != 0:
            errors.append("farm.%s: materials %s / %d images (want [%s] / 0)"
                          % (name, s["material_names"], s["images"], MAT_NAME))
        if not (-0.06 <= s["aabb_min"][1] <= 0.03):
            errors.append("farm.%s: base at y=%.3f, not on the ground" % (name, s["aabb_min"][1]))
        if abs(size[0] - size[2]) > 0.2 and name.startswith("field_"):
            errors.append("farm.%s: %.2f x %.2f m, the plot must be square" % (name, size[0], size[2]))
        print("[check_manifest] farm.%-20s %4d tris  aabb %s" % (name, s["tris"], [round(v, 2) for v in size]))
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
