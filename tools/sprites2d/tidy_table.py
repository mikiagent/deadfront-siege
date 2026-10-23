#!/usr/bin/env python3.13
"""Reconcile label_table.json with the current manifest after a re-cut.

    python3.13 tools/sprites2d/tidy_table.py [--write]

A split box or a new sheet changes src_rects, so rows drift away from the sprites they were
written for. This walks the manifest, keeps every exact row, re-anchors a row whose IoU with a
new crop is >= 0.5 (the item is the same, the crop moved by a pixel or two), and lists the crops
that have no row yet so they can be named. With --write it rewrites label_table.json in manifest
order; naming never comes from index or centre distance.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rules  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MANIFEST = os.path.join(ROOT, "game/data/world/sprites2d.json")
TABLE = os.path.join(ROOT, "tools/sprites2d/label_table.json")
NEW = os.path.join(ROOT, "tools/sprites2d/label_new.json")


def area(r):
    return float(r[2]) * float(r[3])


def main():
    man = json.load(open(MANIFEST))["sprites"]
    rows = rules.load_table()
    named = {}
    try:
        named = json.load(open(NEW))["items"]
    except (OSError, ValueError, KeyError):
        named = {}
    used = set()
    out = []
    new = []
    for sp in man:
        rect = [int(v) for v in sp["src_rect"]]
        key = "%s|%d,%d,%d,%d" % tuple([sp["sheet"]] + rect)
        hit = None
        for k, r in enumerate(rows):
            if k in used or r[0] != sp["sheet"]:
                continue
            if [int(v) for v in r[1:5]] == rect:
                hit = (k, r)
                break
        if hit is None:
            best, score = None, 0.5
            for k, r in enumerate(rows):
                if k in used or r[0] != sp["sheet"]:
                    continue
                v = rules.iou(rect, r[1:5])
                if v > score:
                    best, score = (k, r), v
            hit = best
        if hit is not None:
            used.add(hit[0])
            r = hit[1]
            out.append([sp["sheet"]] + rect + [r[5], r[6], r[7]])
        elif key in named:
            n = named[key]
            out.append([sp["sheet"]] + rect + [n[0], n[1], n[2]])
        else:
            out.append([sp["sheet"]] + rect + ["item", "unused", 0.5])
            new.append((sp["sheet"], sp["id"], rect))
    dead = [r for k, r in enumerate(rows) if k not in used]
    print("%d sprites, %d rows kept, %d sheets" % (len(out), len(used), len({r[0] for r in out})))
    print("rows with no sprite now: %d" % len(dead))
    for d in dead[:20]:
        print("  dead row:", d)
    print("sprites with no row: %d" % len(new))
    for n in new:
        print("  NEW %s %s %s" % n)
    if "--write" in sys.argv:
        with open(TABLE, "w") as f:
            json.dump({"_about": "rows: [sheet, x, y, w, h, name, kind, height_m] - src_rect in "
                                 "full-sheet pixels", "rows": out}, f, indent=0)
            f.write("\n")
        print("wrote", TABLE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
