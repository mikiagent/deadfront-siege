"""Tile rendered item PNGs onto the UI ink colour for eyeballing (Blender -b -P ... -- out.png a.png b.png ...)."""
import pathlib
import sys

import bpy
import numpy as np

sys.dont_write_bytecode = True  # keep __pycache__ out of tools/blender/items
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import kit  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
out, files = argv[0], argv[1:]
cols = min(8, len(files))
rows = (len(files) + cols - 1) // cols
sheet = np.zeros((rows * 256, cols * 256, 4), dtype=np.float64)
sheet[..., :3] = (0.07, 0.08, 0.09)
sheet[..., 3] = 1.0
for i, f in enumerate(files):
    img = bpy.data.images.load(f)
    px = np.array(img.pixels[:]).reshape(256, 256, 4)[::-1]
    y, x = (i // cols) * 256, (i % cols) * 256
    if (i // cols + i % cols) % 2:
        sheet[y:y + 256, x:x + 256, :3] = (0.11, 0.12, 0.13)
    a = px[..., 3:4]
    sheet[y:y + 256, x:x + 256, :3] = px[..., :3] * a + sheet[y:y + 256, x:x + 256, :3] * (1 - a)
    print("SHEET %d %s" % (i, pathlib.Path(f).stem))
pathlib.Path(out).write_bytes(kit.encode_png(np.round(sheet * 255).astype(np.uint8)))
