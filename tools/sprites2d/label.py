#!/usr/bin/env python3.13
"""Write tools/sprites2d/labels.json from the manifest (the mapping the game reads).

    python3.13 tools/sprites2d/label.py [--report]

cut.py owns the naming: it matches tools/sprites2d/label_table.json rows to sprites by exact
sheet+src_rect, with an IoU >= 0.7 fallback (rules.match_rects), and bakes name/kind/height/
blocks/destroyable into game/data/world/sprites2d.json. This script re-reads the PNGs to measure
pivots and writes the same mapping as labels.json for humans and for CARD2D, and it reports both
directions of the match (sprites with no row, rows with no sprite).
"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rules  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MANIFEST = os.path.join(ROOT, "game/data/world/sprites2d.json")
LABELS = os.path.join(ROOT, "tools/sprites2d/labels.json")


def pivot_for(path, kind):
    """Ground contact: centre of the bottom band. Vines and root curtains hang from the top."""
    w, h = map(int, subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
         "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip().split(","))
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
                         capture_output=True).stdout
    a = np.frombuffer(raw, np.uint8).reshape(h, w, 4)[..., 3]
    ys, xs = np.nonzero(a > 60)
    if len(xs) == 0:
        return [w // 2, h - 1]
    if rules.hanging(kind):
        band = ys < ys.min() + 4
        return [int(round(float(xs[band].mean()))), int(ys.min())]
    band = ys >= ys.max() - 3
    return [int(round(float(xs[band].mean()))), int(ys.max())]


def main():
    man = json.load(open(MANIFEST))["sprites"]
    families = rules.load_families()
    table = rules.load_table()
    pick = rules.match_rects_all(man, table)
    out = {"_about": "Sprite mapping keyed by (sheet, src_rect) from label_table.json, exact rect "
                     "first then IoU >= 0.7, one-to-one: a split or a re-cut can never slide a "
                     "label onto a neighbour.",
           "sheets": {}}
    no_row = []
    for i, sp in enumerate(man):
        path = os.path.join(ROOT, "game", sp["file"][len("res://"):])
        piv = pivot_for(path, sp["kind"]) if os.path.isfile(path) else sp["pivot"]
        if i not in pick:
            no_row.append((sp["sheet"], sp["id"], sp["src_rect"]))
        height = float(sp["height_m"])
        out["sheets"].setdefault(sp["sheet"], []).append({
            "id": sp["id"],
            "src_rect": sp["src_rect"],
            "name": sp["name"],
            "kind": sp["kind"],
            "height_m": height,
            "blocks": rules.blocks_for(sp["kind"], height, families),
            "destroyable": rules.destroyable_for(sp["kind"], height),
            "pivot": piv,
        })
    with open(LABELS, "w") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    print("wrote", LABELS, {k: len(v) for k, v in out["sheets"].items()})
    print("anchored %d, without a row %d" % (len(man) - len(no_row), len(no_row)))
    if "--report" in sys.argv:
        for u in no_row:
            print("  sprite with no row:", u)
        used = set(pick.values())
        for k, r in enumerate(table):
            if k not in used:
                print("  row with no sprite:", r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
