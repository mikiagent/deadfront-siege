#!/usr/bin/env python3.13
"""Shared sprite rules: label matching and the game's blocks/destroyable/pivot conventions.

Used by cut.py (which bakes names and flags into the manifest) and label.py (which writes
labels.json and the human-readable report). Keeping one copy means the manifest and
labels.json can never disagree.
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TABLE = os.path.join(ROOT, "tools/sprites2d/label_table.json")
NATURE = os.path.join(ROOT, "game/data/nature_manifest.json")
IOU_MIN = 0.7


def load_table():
    """label_table.json rows: [sheet, x, y, w, h, name, kind, height_m]."""
    try:
        rows = json.load(open(TABLE))["rows"]
    except (OSError, ValueError, KeyError):
        return []
    return [r for r in rows if isinstance(r, list) and len(r) == 8]


def load_families():
    try:
        return json.load(open(NATURE)).get("families", {})
    except (OSError, ValueError):
        return {}


def iou(a, b):
    ax, ay, aw, ah = [float(v) for v in a]
    bx, by, bw, bh = [float(v) for v in b]
    ix = max(0.0, min(ax + aw, bx + bw) - max(ax, bx))
    iy = max(0.0, min(ay + ah, by + bh) - max(ay, by))
    inter = ix * iy
    union = aw * ah + bw * bh - inter
    return inter / union if union else 0.0


def match_rects(sheet, rects, rows):
    """One-to-one match of sprite rects to label rows: exact rect first, then IoU >= IOU_MIN.

    Never by centre distance and never by index: both slid labels onto neighbours whenever a
    split box changed the item count (round-1/2 bug). Returns {rect index: row index}.
    """
    mine = [(k, r) for k, r in enumerate(rows) if r[0] == sheet]
    pick = {}
    taken = set()
    for i, rect in enumerate(rects):
        key = [int(round(float(v))) for v in rect]
        for k, r in mine:
            if k in taken:
                continue
            if [int(v) for v in r[1:5]] == key:
                pick[i] = k
                taken.add(k)
                break
    cand = []
    for i, rect in enumerate(rects):
        if i in pick:
            continue
        for k, r in mine:
            if k in taken:
                continue
            v = iou(rect, r[1:5])
            if v >= IOU_MIN:
                cand.append((-v, i, k))
    cand.sort()
    for _, i, k in cand:
        if i in pick or k in taken:
            continue
        pick[i] = k
        taken.add(k)
    return pick


def match_rects_all(man, rows):
    """match_rects() over a whole manifest: returns {manifest index: table row index}."""
    out = {}
    for sheet in {sp["sheet"] for sp in man}:
        idx = [i for i, sp in enumerate(man) if sp["sheet"] == sheet]
        pick = match_rects(sheet, [man[i]["src_rect"] for i in idx], rows)
        for local, row in pick.items():
            out[idx[local]] = row
    return out


def blocks_for(kind, height, families):
    """Same rule as HarvestNode.blocks_movement(): tree roles block, and so does any family whose
    height span reaches above the 1.25 m step-over height. Ground cover never blocks (spec 28);
    hanging vines and root curtains hang from something, so they never block either."""
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
    if hanging(kind):
        return False
    return float(height) > 1.25


def hanging(kind):
    """Vines and root curtains hang from their top attachment. A root *ball* (palms_19) is a
    ball lying on the ground and a waterfall stands on the ground, so neither is hanging."""
    return kind.startswith("prop:vine") or kind == "prop:root_curtain"


def destroyable_for(kind, height):
    """Owner: most props can be destroyed except really big cliffs, arches, pillars and
    waterfalls (4 m or more)."""
    big = kind.startswith("prop:") and any(
        t in kind for t in ("cliff", "arch", "pillar", "mesa", "stack", "waterfall"))
    return not (big and float(height) >= 4.0)
