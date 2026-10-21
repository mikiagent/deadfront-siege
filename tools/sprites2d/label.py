#!/usr/bin/env python3.13
"""Write tools/sprites2d/labels.json: name, kind, height, blocks, destroyable, pivot per sprite.

    python3.13 tools/sprites2d/label.py [--report]

Run after cut.py. The reading of the art lives in tools/sprites2d/label_table.json as rows of
[sheet, x, y, w, h, name, kind, height_m]: the sprite's src_rect on the full-resolution sheet.
Matching is by exact sheet+src_rect, falling back to IoU >= 0.7 (round-3 audit). Never by centre
distance and never by index: both slid labels onto neighbours when a split box changed the item
count. The script prints both directions of the match (sprites with no row, rows with no sprite).
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
    # hanging props hang from their top. root_ball must NOT match prop:root*: it is a ball lying
    # on the ground (palms_19). Waterfalls stand on the ground -> bottom pivot.
    hanging = kind.startswith("prop:vine") or kind == "prop:root_curtain"
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
    # hanging vines and root curtains never block (orchestrator round 3)
    if kind == "prop:root_curtain" or kind.startswith("prop:vine"):
        return False
    return height > 1.25


def slugify(s):
    s = "".join(c if c.isalnum() else "_" for c in s.lower())
    while "__" in s:
        s = s.replace("__", "_")
    return s.strip("_") or "item"


def iou(a, b):
    ax0, ay0, aw, ah = a
    bx0, by0, bw, bh = b
    ix = max(0, min(ax0 + aw, bx0 + bw) - max(ax0, bx0))
    iy = max(0, min(ay0 + ah, by0 + bh) - max(ay0, by0))
    inter = ix * iy
    union = aw * ah + bw * bh - inter
    return inter / float(union) if union else 0.0


def main():
    man = json.load(open(MANIFEST))["sprites"]
    families = json.load(open(os.path.join(ROOT, "game/data/nature_manifest.json"))).get("families", {})
    table = [r for r in json.load(open(TABLE))["rows"] if len(r) == 8]
    matched = 0
    # pass 1: exact src_rect on the same sheet. pass 2: best IoU >= 0.7, one-to-one.
    pick = {}
    taken = set()
    for i, sp in enumerate(man):
        for k, r in enumerate(table):
            if k in taken or r[0] != sp["sheet"]:
                continue
            if [int(v) for v in r[1:5]] == [int(v) for v in sp["src_rect"]]:
                pick[i] = k
                taken.add(k)
                break
    cand = []
    for i, sp in enumerate(man):
        if i in pick:
            continue
        for k, r in enumerate(table):
            if k in taken or r[0] != sp["sheet"]:
                continue
            v = iou(sp["src_rect"], r[1:5])
            if v >= 0.7:
                cand.append((-v, i, k))
    cand.sort()
    for _, i, k in cand:
        if i in pick or k in taken:
            continue
        pick[i] = k
        taken.add(k)
    no_row = []
    out = {"_about": "Sprite mapping keyed by (sheet, src_rect) from label_table.json, exact rect "
                     "first then IoU >= 0.7, one-to-one: a split or a re-cut can never slide a "
                     "label onto a neighbour.",
           "sheets": {}}
    seen = {}
    for i, sp in enumerate(man):
        seen[sp["sheet"]] = seen.get(sp["sheet"], 0) + 1
        n = seen[sp["sheet"]]
        x, y, w, h = sp["src_rect"]
        if i in pick:
            matched += 1
            best = table[pick[i]]
            name, kind, height = best[5], best[6], best[7]
        else:
            no_row.append((sp["sheet"], sp["id"], sp["src_rect"]))
            name, kind, height = "item", "unused", 0.5
        sid = "%s_%02d_%s" % (sp["sheet"][6:], n, slugify(name))
        path = os.path.join(ROOT, "game", sp["file"][len("res://"):])
        piv = pivot_for(path, kind) if os.path.isfile(path) else [0, 0]
        row = {
            "id": sid,
            "src_rect": sp["src_rect"],
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
    print("anchored %d, without a row %d, rows unused %d" % (matched, len(man) - matched, len(table) - len(taken)))
    if "--report" in sys.argv:
        for u in no_row:
            print("  sprite with no row:", u)
        for k, r in enumerate(table):
            if k not in taken:
                print("  row with no sprite:", r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
