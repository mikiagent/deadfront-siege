"""Write game/data/world/biome_assets.json from a full build run (source of truth for sizes).

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P write_manifest.py
It builds every asset (same gate as build_all.py), then writes one row per asset: path, kind, size_m
(width x height x depth in Godot axes), collide (the suggested collider shape), destroyable, biomes and
the measured triangle count. The rows' gameplay fields live in ROWS below; the numbers come from the
built meshes so they can never drift from the GLBs. Run it after any geometry change.
"""
import json
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import build_all  # noqa: E402
import bp_lib  # noqa: E402

OUT = os.path.join(bp_lib.REPO, "game", "data", "world", "biome_assets.json")

# kind: what the integrator places and how it reads. collide: "none" (walk through), "box" (AABB
# blocker), "cylinder" (round blocker for wide trunks/crystals). destroyable False only for the big
# landforms the owner said never break (mesas, cliffs, spires). biomes: plan zone ids from
# docs/design/islands-and-loop-plan.md 1.4 plus the spec-26 landmarks (canyon, volcanic, savanna deltas).
ROWS = {
    "reed_clump_a": dict(kind="reed_clump", collide="none", destroyable=True,
                         biomes=["riverbank", "delta", "oasis"], notes="river and delta banks"),
    "reed_clump_b": dict(kind="reed_clump", collide="none", destroyable=True,
                         biomes=["riverbank", "delta"], notes="smaller bank clump"),
    "plume_grass": dict(kind="plume_grass", collide="none", destroyable=True,
                        biomes=["riverbank", "delta", "dry_upland"], notes="white plumes on river mouths"),
    "fern_clump_a": dict(kind="fern", collide="none", destroyable=True,
                         biomes=["forest", "riverbank"], notes="damp understorey"),
    "fern_clump_b": dict(kind="fern", collide="none", destroyable=True,
                         biomes=["forest", "riverbank", "volcanic"], notes="tree-fern scale understorey"),
    "lily_pad_cluster": dict(kind="lily_pads", collide="none", destroyable=True,
                             biomes=["riverbank", "delta", "oasis", "hot_spring"],
                             notes="flat; sits on the water plane, no collider"),
    "aloe_flower": dict(kind="aloe", collide="none", destroyable=True,
                        biomes=["dry_upland", "savanna"], notes="red-flowered aloe"),
    "termite_mound_a": dict(kind="termite_mound", collide="cylinder", destroyable=True,
                            biomes=["dry_upland", "savanna"], notes="prop, not a resource"),
    "termite_mound_b": dict(kind="termite_mound", collide="cylinder", destroyable=True,
                            biomes=["dry_upland", "savanna"], notes="prop, not a resource"),
    "fallen_log_moss": dict(kind="fallen_log", collide="box", destroyable=True,
                            biomes=["forest", "riverbank"], notes="mossy; can be a log-bridge prop"),
    "fallen_log_dry": dict(kind="fallen_log", collide="box", destroyable=True,
                           biomes=["savanna", "delta", "dry_upland"], notes="dry driftwood along rivers"),
    "rock_spire_a": dict(kind="rock_spire", collide="box", destroyable=False,
                         biomes=["rocky_hills", "canyon"], notes="indestructible landmark"),
    "rock_spire_b": dict(kind="rock_spire", collide="box", destroyable=False,
                         biomes=["rocky_hills", "canyon"], notes="indestructible landmark"),
    "mesa_sandstone": dict(kind="mesa", collide="box", destroyable=False,
                           biomes=["canyon", "dry_upland"], notes="indestructible cliff chunk"),
    "mesa_basalt": dict(kind="mesa", collide="box", destroyable=False,
                        biomes=["volcanic", "rocky_hills"], notes="indestructible cliff chunk"),
    "cliff_chunk_red": dict(kind="cliff", collide="box", destroyable=False,
                            biomes=["canyon"], notes="indestructible cliff chunk"),
    "basalt_columns": dict(kind="basalt_columns", collide="box", destroyable=True,
                           biomes=["volcanic", "rocky_hills"], notes="cooling-joint basalt outcrop"),
    "boulder_pile_a": dict(kind="boulder_pile", collide="box", destroyable=True,
                           biomes=["rocky_hills", "dry_upland", "savanna"], notes="granite boulders"),
    "boulder_pile_b": dict(kind="boulder_pile", collide="box", destroyable=True,
                           biomes=["rocky_hills", "dry_upland"], notes="larger granite boulders"),
    "crystal_blue": dict(kind="crystal_cluster", collide="cylinder", destroyable=True,
                         biomes=["rocky_hills", "canyon"], notes="ore-node visual: pale blue"),
    "crystal_obsidian": dict(kind="crystal_cluster", collide="cylinder", destroyable=True,
                             biomes=["volcanic"], notes="ore-node visual: black obsidian"),
    "crystal_sulphur": dict(kind="crystal_cluster", collide="cylinder", destroyable=True,
                            biomes=["volcanic"], notes="ore-node visual: yellow sulphur"),
    "steam_vent": dict(kind="steam_vent", collide="cylinder", destroyable=True,
                       biomes=["volcanic"], notes="rim only; the steam is a vfx job"),
    "hot_spring_rim": dict(kind="hot_spring_rim", collide="box", destroyable=True,
                           biomes=["volcanic", "hot_spring"], notes="cream travertine terraces"),
    "pebble_patch": dict(kind="pebbles", collide="none", destroyable=True,
                         biomes=["riverbank", "beach", "dry_upland"], notes="flat scatter, no collider"),
}


def main():
    infos = build_all.main([])  # builds everything, same budget gate
    rows = []
    for info in infos:
        n = info["name"]
        if n not in ROWS:
            raise SystemExit("no manifest row for built asset %s" % n)
        r = dict(ROWS[n])
        row = {
            "id": n,
            "path": "res://assets/nature/biome/%s.glb" % n,
            "kind": r["kind"],
            "size_m": info["size_m"],
            "collide": r["collide"],
            "destroyable": r["destroyable"],
            "biomes": r["biomes"],
            "tris": info["tris"],
            "budget_tris": info["budget"],
            "origin": "ground_center",
            "notes": r["notes"],
        }
        rows.append(row)
    missing = sorted(set(ROWS) - {i["name"] for i in infos})
    if missing:
        raise SystemExit("manifest rows with no built asset: %s" % ", ".join(missing))
    doc = {
        "_about": ("Biome props built by tools/blender/biome_props (headless Blender). One row per GLB under "
                   "res://assets/nature/biome/. size_m is width x height x depth in Godot axes (x, y up, z), "
                   "origin at the ground centre, metres. collide is the suggested collider: none (walk through), "
                   "box (AABB), cylinder (round blocker). destroyable is false only for the big landforms "
                   "(mesas, cliffs, spires) the owner ruled indestructible; everything else can be broken. "
                   "biomes lists the plan zone ids (docs/design/islands-and-loop-plan.md 1.4) and spec-26 landmarks. "
                   "props_manifest.json is NOT touched: this file is consent for the island scatter to place "
                   "visual props that are not resources; only the crystal clusters are meant as ore-node visuals."),
        "assets": rows,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print("[biomeprops] wrote %s (%d rows)" % (OUT, len(rows)))


main()
