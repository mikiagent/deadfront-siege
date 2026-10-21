#!/usr/bin/env python3.13
"""Contact sheet for SPRITES2D: every sprite on mid-grey with its id, grouped by sheet.

    python3.13 tools/sprites2d/contact.py [out.png]

Cells are 220x220 (sprite scaled to fit, 8 px label strip under it), 6 per row per sheet.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from cut import MANIFEST, ROOT, write_png  # noqa: E402

CELL = int(os.environ.get("CELL", "220"))
PAD = 8
COLS = int(os.environ.get("COLS", "6"))


def read_rgba(path):
    import subprocess
    w, h = map(int, subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
         "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip().split(","))
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(h, w, 4)


def scale_nn(img, w, h):
    ys = (np.arange(h) * img.shape[0] / h).astype(int)
    xs = (np.arange(w) * img.shape[1] / w).astype(int)
    return img[ys][:, xs]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs/orchestration/reports/dsc-sprites2d-sheet.png")
    man = json.load(open(MANIFEST))["sprites"]
    if len(sys.argv) > 2:
        only = set(sys.argv[2].split(","))
        man = [r for r in man if r["sheet"] in only]
    sheets = sorted({s["sheet"] for s in man})
    rows_of = []
    for sh in sheets:
        rows_of.extend([r for r in man if r["sheet"] == sh])
    per_row = COLS
    n_rows = sum((len([r for r in man if r["sheet"] == sh]) + per_row - 1) // per_row + 1 for sh in sheets)
    canvas = np.full((n_rows * CELL, per_row * CELL, 4), (128, 128, 128, 255), np.uint8)
    # 2x2 pixels per glyph so the ids stay readable when the sheet is viewed at half size
    glyph = 3
    y = 0
    font = _font()
    for sh in sheets:
        sprites = [r for r in man if r["sheet"] == sh]
        canvas[y:y + 14, :, :3] = 90
        _text(canvas, PAD, y + 2, "%s  (%d)" % (sh, len(sprites)), (255, 255, 255), font)
        y += 14
        for i, sp in enumerate(sprites):
            cx = (i % per_row) * CELL
            cy = y + (i // per_row) * CELL
            path = os.path.join(ROOT, "game", sp["file"][len("res://"):])
            img = read_rgba(path)
            h, w = img.shape[:2]
            avail_h = CELL - 52 - PAD
            avail_w = CELL - PAD * 2
            sc = min(avail_w / w, avail_h / h, 3.0)
            tw, th = max(1, int(w * sc)), max(1, int(h * sc))
            sm = scale_nn(img, tw, th)
            ox = cx + (CELL - tw) // 2
            oy = cy + PAD + (avail_h - th)
            cell = canvas[oy:oy + th, ox:ox + tw]
            a = sm[..., 3:4].astype(np.float32) / 255.0
            cell[..., :3] = (sm[..., :3] * a + cell[..., :3] * (1 - a)).astype(np.uint8)
            cell[..., 3] = 255
            # pivot marker: small red cross at the ground point
            px = ox + int(sp["pivot"][0] * sc)
            py = oy + int(sp["pivot"][1] * sc)
            canvas[max(0, py - 1):py + 2, max(0, px - 4):px + 5, :3] = (255, 40, 40)
            canvas[max(0, py - 4):py + 5, max(0, px - 1):px + 2, :3] = (255, 40, 40)
            _text(canvas, cx + 4, cy + CELL - 44, sp["id"][:34], (255, 255, 255), font, 2)
            _text(canvas, cx + 4, cy + CELL - 32, sp["kind"][:34], (220, 220, 160), font, 2)
            _text(canvas, cx + 4, cy + CELL - 20, "%sm" % sp["height_m"], (220, 220, 160), font, 2)
        y += ((len(sprites) + per_row - 1) // per_row) * CELL
    canvas = canvas[:y]
    os.makedirs(os.path.dirname(out), exist_ok=True)
    write_png(out, canvas)
    print("%s  %dx%d  %d sprites" % (out, canvas.shape[1], canvas.shape[0], len(man)))


def _font():
    """3x5 bitmap font, digits and A-Z, plus a few punctuation marks."""
    d = {
        "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
        "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
        "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
        "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
        "I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "010"],
        "K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
        "M": ["101", "111", "111", "101", "101"], "N": ["101", "111", "111", "111", "101"],
        "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
        "Q": ["010", "101", "101", "111", "011"], "R": ["110", "101", "110", "101", "101"],
        "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
        "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
        "W": ["101", "101", "111", "111", "101"], "X": ["101", "101", "010", "101", "101"],
        "Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
        "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
        "2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
        "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
        "6": ["011", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
        "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "110"],
        "_": ["000", "000", "000", "000", "111"], "-": ["000", "000", "111", "000", "000"],
        ".": ["000", "000", "000", "000", "010"], ":": ["000", "010", "000", "010", "000"],
        " ": ["000", "000", "000", "000", "000"],
    }
    return d


def _text(canvas, x, y, s, colour, font, scale=1):
    for ch in s.upper():
        glyph = font.get(ch, font[" "])
        for gy, row in enumerate(glyph):
            for gx, c in enumerate(row):
                if c == "1":
                    yy, xx = y + gy * scale, x + gx * scale
                    if 0 <= yy < canvas.shape[0] and 0 <= xx < canvas.shape[1]:
                        canvas[yy:yy + scale, xx:xx + scale, :3] = colour
        x += 4 * scale


if __name__ == "__main__":
    main()
