#!/usr/bin/env python3.13
"""Write tools/sprites2d/labels.json: name, kind, height, blocks, destroyable, pivot per sprite.

    python3.13 tools/sprites2d/label.py

Run after cut.py. The table below is per sheet, in sprite order (id index), and is the human
reading of the art (see docs/design/durango-prompts/27..., 28...). Any sprite the table does not
cover keeps kind "unused". Pivot is measured from the PNG: bottom-centre of the visible pixels for
ground items, top-centre for hanging vines/roots (ASSUMPTION, see the report).
Re-running this script does not destroy extra hand edits unless a sprite's index is in the table.
"""
import json
import os
import subprocess
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MANIFEST = os.path.join(ROOT, "game/data/world/sprites2d.json")
LABELS = os.path.join(ROOT, "tools/sprites2d/labels.json")

# name, kind, height_m
T = {
    # --- sheet-resources: crystals, boulders, clay, logs, plants, fruit, bones, shells ---------
    "sheet-resources": [
        ("crystal_cluster", "prop:crystal_cluster", 1.5),
        ("mossy_boulder_pile", "GraniteBoulder", 2.0),
        ("clay_mound", "clay", 0.9),
        ("rock_chip_small", "prop:rock_chip", 0.25),
        ("mossy_fallen_log", "WoodLog_Moss", 0.9),
        ("cut_log_pile", "WoodLog", 0.8),
        ("bamboo_bundle", "prop:bamboo_bundle", 1.1),
        ("berry_palm", "MangoBush", 2.2),
        ("red_heliconia", "Plant", 1.0),
        ("white_flower_herb", "HerbPlant", 0.6),
        ("blue_mushroom_clump", "prop:mushroom_clump_blue", 0.6),
        ("amanita_clump", "prop:mushroom_clump_red", 0.7),
        ("banana_bunch", "icon:bananas", 0.6),
        ("coconut_bunch", "icon:coconuts", 0.5),
        ("chestnut_cluster", "icon:chestnuts", 0.5),
        ("chestnut_pod", "icon:chestnut_pod", 0.35),
        ("bones", "icon:bones", 0.4),
        ("tusk", "icon:tusk", 0.5),
        ("seashells", "icon:seashells", 0.2),
        ("oyster_shells", "icon:oyster_shells", 0.3),
        ("driftwood_log", "prop:driftwood", 0.5),
        ("driftwood_log_b", "prop:driftwood", 0.5),
        ("rock_chip", "prop:rock_chip", 0.25),
        ("rock_chip_b", "prop:rock_chip", 0.2),
    ],
    # --- sheet-palms: palms, crowns, fronds, trunk, stump, root ball, coconuts ----------------
    "sheet-palms": [
        ("coconut_palm_large", "PalmTree", 12.0),
        ("coconut_palm_tall", "PalmTree", 11.0),
        ("coconut_palm_leaning", "PalmTree", 10.0),
        ("palm_cluster_young", "PalmTree", 8.0),
        ("palm_crown_short", "prop:palm_crown", 1.2),
        ("palm_crown_topdown", "prop:palm_crown", 1.2),
        ("palm_crown_topdown_b", "prop:palm_crown", 1.2),
        ("young_palm_rooted", "PalmTree", 2.5),
        ("frond", "unused", 0.5),
        ("frond_b", "unused", 0.5),
        ("frond_dry", "unused", 0.5),
        ("frond_c", "unused", 0.5),
        ("palm_crown_cut", "unused", 0.5),
        ("frond_d", "unused", 0.5),
        ("frond_dead", "unused", 0.5),
        ("frond_e", "unused", 0.5),
        ("coconut_bunch_green", "icon:coconuts", 0.4),
        ("fallen_palm_trunk", "prop:fallen_trunk", 0.7),
        ("broken_palm_stump", "TreeStump", 1.2),
        ("palm_root_ball", "prop:root_ball", 1.0),
        ("coconut_cluster", "icon:coconuts", 0.4),
        ("coconut", "icon:coconut", 0.3),
    ],
    # --- sheet-jungle-plants: ferns, cycads, vines, ivy, reeds, grass, root tangles -----------
    "sheet-jungle-plants": [
        ("fern_cluster", "Plant", 0.9),
        ("fern_cluster_b", "Plant", 0.9),
        ("cycad", "Plant", 1.1),
        ("hanging_vine", "VinePlant", 1.2),
        ("hanging_vine_b", "VinePlant", 1.2),
        ("hanging_vine_c", "VinePlant", 1.2),
        ("broadleaf_plant", "Plant", 0.9),
        ("red_flower_plant", "Plant", 0.8),
        ("cycad_cluster", "Plant", 1.2),
        ("big_leaf_shrub", "Plant", 1.3),
        ("red_flower_pair", "Plant", 1.1),
        ("fan_palm_shrub", "Plant", 1.2),
        ("broadleaf_shrub", "Plant", 1.0),
        ("fan_palm_cluster", "Plant", 1.4),
        ("tall_grass_b", "WildGrass", 1.2),
        ("tall_grass", "WildGrass", 1.4),
        ("ivy_mound", "Plant", 0.7),
        ("aloe_rosette", "Plant", 1.0),
        ("bromeliad_red", "Plant", 1.0),
        ("log_tangle_roots", "prop:log_tangle", 1.2),
        ("ivy_on_branch", "prop:log_tangle", 1.1),
        ("white_lily_plant", "Plant", 0.9),
        ("red_flower_cluster", "Plant", 0.9),
        ("mossy_rock_plant", "prop:moss_rock", 0.5),
        ("broadleaf_plant_b", "Plant", 0.8),
        ("broadleaf_plant_c", "Plant", 0.9),
        ("fern_e", "Plant", 0.8),
        ("fern_f", "Plant", 0.8),
        ("leaf", "unused", 0.4),
        ("leaf_b", "unused", 0.4),
        ("leaf_c", "unused", 0.4),
        ("frond_small", "unused", 0.4),
        ("leaf_d", "unused", 0.4),
        ("leaf_e", "unused", 0.4),
        ("leaf_f", "unused", 0.4),
        ("leaf_g", "unused", 0.3),
        ("leaf_h", "unused", 0.4),
        ("leaf_i", "unused", 0.4),
        ("leaf_j", "unused", 0.3),
        ("leaf_k", "unused", 0.3),
        ("leaf_l", "unused", 0.3),
        ("moss_mound", "Plant", 0.6),
    ],
    # --- sheet-beach-shells: single shells, shell piles, driftwood, coral rock ----------------
    "sheet-beach-shells": [
        ("clam_shell", "icon:clam_shell", 0.2),
        ("clam_shell_b", "icon:clam_shell", 0.2),
        ("clam_shell_c", "icon:clam_shell", 0.2),
        ("scallop_shell", "icon:scallop", 0.2),
        ("open_shell", "icon:open_shell", 0.2),
        ("open_shell_b", "icon:open_shell", 0.2),
        ("scallop_shell_b", "icon:scallop", 0.2),
        ("open_shell_c", "icon:open_shell", 0.2),
        ("shell_scatter", "prop:shells", 0.3),
        ("shell_scatter_b", "prop:shells", 0.3),
        ("shell_scatter_c", "prop:shells", 0.3),
        ("shell_scatter_d", "prop:shells", 0.3),
        ("shell_scatter_e", "prop:shells", 0.3),
        ("shell_scatter_f", "prop:shells", 0.3),
        ("shell_pile", "prop:shells", 0.3),
        ("shell_pile_b", "prop:shells", 0.3),
        ("shell_pile_c", "prop:shells", 0.3),
        ("shell_pile_seaweed", "prop:shells", 0.35),
        ("shell_pile_d", "prop:shells", 0.35),
        ("shell_pile_e", "prop:shells", 0.3),
        ("shell_pile_f", "prop:shells", 0.3),
        ("shell_pile_driftwood", "prop:shells", 0.4),
        ("shell_pile_g", "prop:shells", 0.4),
        ("open_shell_d", "icon:open_shell", 0.25),
        ("shell_driftwood", "prop:driftwood", 0.4),
        ("shell_cluster", "prop:shells", 0.35),
        ("shell_pair", "icon:shell_pair", 0.2),
        ("coral_rock", "prop:coral_rock", 1.0),
        ("giant_open_shell", "prop:shells", 0.35),
        ("big_clam_shell", "icon:clam_shell", 0.25),
    ],
}


def pivot_for(path, kind):
    w, h = map(int, subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
         "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip().split(","))
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
                         capture_output=True).stdout
    a = np.frombuffer(raw, np.uint8).reshape(h, w, 4)[..., 3]
    ys, xs = np.nonzero(a > 60)
    if len(xs) == 0:
        return [w // 2, h - 1]
    if kind.startswith("prop:vine") or kind.startswith("prop:root") or "vine" in kind.lower():
        band = ys < ys.min() + 4
        return [int(round(float(xs[band].mean()))), int(ys.min())]
    band = ys >= ys.max() - 3
    return [int(round(float(xs[band].mean()))), int(ys.max())]


def main():
    man = json.load(open(MANIFEST))["sprites"]
    rows = json.load(open(LABELS)) if os.path.isfile(LABELS) else {}
    out = {"_about": "Sprite mapping by sheet, in sprite order. Matched back to a sprite by id, "
                     "then by the centre of src_rect, so a re-cut keeps the mapping.",
           "sheets": {}}
    for sheet, table in T.items():
        sprites = [s for s in man if s["sheet"] == sheet]
        rows_out = []
        for i, sp in enumerate(sprites):
            if i >= len(table):
                break
            name, kind, height = table[i]
            path = os.path.join(ROOT, "game", sp["file"][len("res://"):])
            hang = kind.startswith("prop:vine") or kind.startswith("prop:root")
            blocks = False
            if kind in ("PalmTree", "ReedPlant", "GraniteBoulder", "MangoBush"):
                blocks = True          # HarvestNode.blocks_movement: tree role or family top > 1.25
            elif kind.startswith("prop:"):
                blocks = height > 1.25
            destroyable = True         # no cliffs/arches/pillars/waterfalls >= 4 m on these sheets
            rows_out.append({
                "id": "%s_%02d_%s" % (sheet[6:], i + 1, name),
                "src_rect": sp["src_rect"],
                "name": name,
                "kind": kind,
                "height_m": height,
                "blocks": blocks,
                "destroyable": destroyable,
                "pivot": pivot_for(path, kind),
            })
        # keep rows beyond the table (hand-added later) untouched
        old = rows.get("sheets", {}).get(sheet, [])
        out["sheets"][sheet] = rows_out
        for r in old:
            if not any(abs(r["src_rect"][0] - n["src_rect"][0]) < 20 and
                       abs(r["src_rect"][1] - n["src_rect"][1]) < 20 for n in rows_out):
                out["sheets"][sheet].append(r)
    with open(LABELS, "w") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    print("wrote", LABELS, {k: len(v) for k, v in out["sheets"].items()})


if __name__ == "__main__":
    sys.exit(main())
