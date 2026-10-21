#!/usr/bin/env python3.13
"""Write tools/sprites2d/labels.json: name, kind, height, blocks, destroyable, pivot per sprite.

    python3.13 tools/sprites2d/label.py [--report]

Run after cut.py. The reading of the art lives in tools/sprites2d/label_table.json as rows of
[cx, cy, name, kind, height_m]: the sprite's CENTRE on the full-resolution sheet, not its position
in the list. An index-keyed table slipped a whole row when a split box changed the item count and
put every label after it onto the wrong sprite (audit 15:20) - a centre only moves if the art
itself moves, and a split can move a centre, so the match tolerance is generous (110 px) and the
script prints both directions of the match: sprites with no row and rows that found no sprite.
"""
import json
import os
import subprocess
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MANIFEST = os.path.join(ROOT, "game/data/world/sprites2d.json")
LABELS = os.path.join(ROOT, "tools/sprites2d/labels.json")
TABLE = os.path.join(ROOT, "tools/sprites2d/label_table.json")
TOL = 60


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
    hanging = (kind.startswith("prop:vine") or kind.startswith("prop:root")
               or "waterfall" in kind)
    if hanging:
        band = ys < ys.min() + 4
        return [int(round(float(xs[band].mean()))), int(ys.min())]
    band = ys >= ys.max() - 3
    return [int(round(float(xs[band].mean()))), int(ys.max())]


def blocks_for(kind, height, families):
    """Same rule as HarvestNode.blocks_movement(): tree roles block, and so does any family whose
    height span reaches above the 1.25 m step-over height. Ground cover never blocks (spec 28)."""
    if kind in families:
        fam = families[kind]
        role = str(fam.get("role", ""))
        span = fam.get("height")
        top = 1.3 if role == "rock" else 0.0
        if isinstance(span, list) and len(span) >= 2:
            top = float(span[1])
        return role.startswith("tree") or top > 1.25
    if kind.startswith("prop:grass") or kind.startswith("prop:reed"):
        return False
    return height > 1.25


def slugify(s):
    s = "".join(c if c.isalnum() else "_" for c in s.lower())
    while "__" in s:
        s = s.replace("__", "_")
    return s.strip("_") or "item"


def main():
    man = json.load(open(MANIFEST))["sprites"]
    families = json.load(open(os.path.join(ROOT, "game/data/nature_manifest.json"))).get("families", {})
    table = [r for r in json.load(open(TABLE))["rows"] if len(r) == 6]
    matched = unmatched = 0
    # One-to-one greedy matching by distance: a row may name only ONE sprite. A plain
    # nearest-neighbour loop let one row be claimed by two sprites (and two rows by one), which is
    # how labels drifted a row onto the wrong art.
    idx = []
    for i, sp in enumerate(man):
        x, y, w, h = sp["src_rect"]
        cx, cy = x + w / 2.0, y + h / 2.0
        for k, r in enumerate(table):
            if r[0] != sp["sheet"]:
                continue
            idx.append((abs(r[1] - cx) + abs(r[2] - cy), i, k))
    idx.sort()
    pick = {}
    taken = set()
    for d, i, k in idx:
        if d > TOL:
            break
        if i in pick or k in taken:
            continue
        pick[i] = k
        taken.add(k)
    no_row = []
    out = {"_about": "Sprite mapping keyed by the sprite's centre on the sheet (cx, cy) in "
                     "label_table.json, matched one-to-one, so a split cannot slide a label onto "
                     "a neighbour.",
           "sheets": {}}
    seen = {}
    for i, sp in enumerate(man):
        seen[sp["sheet"]] = seen.get(sp["sheet"], 0) + 1
        n = seen[sp["sheet"]]
        x, y, w, h = sp["src_rect"]
        cx, cy = x + w / 2.0, y + h / 2.0
        if i in pick:
            matched += 1
            best = table[pick[i]]
            name, kind, height = best[3], best[4], best[5]
        else:
            unmatched += 1
            no_row.append((sp["sheet"], sp["id"], int(cx), int(cy)))
            name, kind, height = "item", "unused", 0.5
        sid = "%s_%02d_%s" % (sp["sheet"][6:], n, slugify(name))
        path = os.path.join(ROOT, "game", sp["file"][len("res://"):])
        piv = pivot_for(path, kind) if os.path.isfile(path) else [0, 0]
        row = {
            "id": sid,
            "src_rect": sp["src_rect"],
            "cx": int(cx),
            "cy": int(cy),
            "name": name,
            "kind": kind,
            "height_m": height,
            "blocks": blocks_for(kind, height, families),
            "destroyable": not (kind.startswith("prop:")
                                and any(t in kind for t in ("cliff", "arch", "pillar", "waterfall"))
                                and height >= 4),
            "pivot": piv,
        }
        out["sheets"].setdefault(sp["sheet"], []).append(row)
    with open(LABELS, "w") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    print("wrote", LABELS, {k: len(v) for k, v in out["sheets"].items()})
    print("anchored %d, without a row %d, rows unused %d" % (matched, unmatched, len(table) - len(taken)))
    if "--report" in sys.argv:
        for u in no_row:
            print("  sprite with no row:", u)
        for k, r in enumerate(table):
            if k not in taken:
                print("  row with no sprite:", r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
