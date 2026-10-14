#!/usr/bin/env python3
"""Stitch the tiles printed by `nature_wave_finish.py inspect` into one labeled sheet.
Usage: uv run --with pillow tools/nature_wave_sheet.py <title> <out.png> <label=tile.png> ..."""
import sys
from PIL import Image, ImageDraw

title, out, *pairs = sys.argv[1:]
tiles = [(p.split("=", 1)[0], Image.open(p.split("=", 1)[1]).convert("RGB")) for p in pairs]
w, h = tiles[0][1].size
cols = 3
rows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows + 40), (24, 24, 24))
d = ImageDraw.Draw(sheet)
d.text((10, 12), title, fill=(255, 255, 255))
for i, (label, im) in enumerate(tiles):
    x, y = (i % cols) * w, 40 + (i // cols) * h
    sheet.paste(im, (x, y))
    d.text((x + 8, y + 8), label, fill=(255, 255, 90))
sheet.save(out, quality=82) if out.lower().endswith((".jpg", ".jpeg")) else sheet.save(out)
