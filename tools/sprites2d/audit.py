#!/usr/bin/env python3.13
"""Audit view: sprites of one sheet at 2x, each on sand or dark grass, id under it.

    python3.13 tools/sprites2d/audit.py <sheet> [start] [count] [out.png]

Sand (225,205,160) and dark grass (70,90,60) are the two in-game grounds; a khaki matte or a
flat-tan leaf that survives on either one shows up here. Cells alternate the two grounds.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from contact import _text, _font, read_rgba  # noqa: E402
from cut import MANIFEST, ROOT, write_png  # noqa: E402

CELL = 300
COLS = 5
TOP = 34


def main():
    sheet = sys.argv[1]
    start = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 10**9
    out = sys.argv[4] if len(sys.argv) > 4 else "/tmp/sprites2d/audit_%s.png" % sheet
    man = [s for s in json.load(open(MANIFEST))["sprites"] if s["sheet"] == sheet]
    sel = man[start:start + count]
    rows = (len(sel) + COLS - 1) // COLS
    canvas = np.zeros((rows * CELL, COLS * CELL, 4), np.uint8)
    font = _font()
    for i, sp in enumerate(sel):
        cx, cy = (i % COLS) * CELL, (i // COLS) * CELL
        ground = (225, 205, 160) if i % 2 == 0 else (70, 90, 60)
        canvas[cy:cy + CELL, cx:cx + CELL, :3] = ground
        canvas[cy:cy + CELL, cx:cx + CELL, 3] = 255
        img = read_rgba(os.path.join(ROOT, "game", sp["file"][len("res://"):]))
        h, w = img.shape[:2]
        sc = min((CELL - 8) / w, (CELL - TOP - 8) / h, 2.0)
        tw, th = max(1, int(w * sc)), max(1, int(h * sc))
        ys = (np.arange(th) * h / th).astype(int)
        xs = (np.arange(tw) * w / tw).astype(int)
        sm = img[ys][:, xs]
        ox, oy = cx + (CELL - tw) // 2, cy + CELL - 6 - th
        cell = canvas[oy:oy + th, ox:ox + tw]
        a = sm[..., 3:4].astype(np.float32) / 255.0
        cell[..., :3] = (sm[..., :3] * a + cell[..., :3] * (1 - a)).astype(np.uint8)
        px, py = ox + int(sp["pivot"][0] * sc), oy + int(sp["pivot"][1] * sc)
        canvas[max(oy, py - 1):py + 2, max(cx, px - 4):px + 5, :3] = (255, 30, 30)
        _text(canvas, cx + 3, cy + 3, sp["id"][:40], (255, 255, 255), font)
        _text(canvas, cx + 3, cy + 11, "%s %sm %s%s sc%s" % (
            sp["kind"][:26], sp["height_m"], "B" if sp["blocks"] else "-",
            "" if sp["destroyable"] else " NO-DESTROY", sp.get("scale")), (240, 240, 180), font)
        _text(canvas, cx + 3, cy + 19, "%dx%d" % (w, h), (200, 200, 200), font)
    write_png(out, canvas)
    print(out, canvas.shape[1], canvas.shape[0], "%d..%d of %d" % (start, start + len(sel), len(man)))


if __name__ == "__main__":
    main()
