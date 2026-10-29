"""Thirteenth drawing pass (STARVING, owner 2026-10-28: "if you're starving, it should show up like a status
effect"): the starving glyph, a ribcage showing through, for its status box beside the survivor. Solid
polygons only, centred optically by geo2.place like icons_g..q."""
from geo2 import *

G = {}

# starving: a spine down the middle and three pairs of ribs curving out and down from it, shorter toward
# the bottom (the ribs show when there is nothing left).
SPINE = capsule((32.0, 8.0), (32.0, 56.0), 4.0)
RIBS = []
for y, reach, drop in ((15.0, 19.0, 9.0), (26.0, 20.0, 9.0), (37.0, 17.0, 7.0)):
    right = band(path((34.0, y), ((40.0, y - 2.0), (32.0 + reach, y), (32.0 + reach, y + drop))), 3.4)
    RIBS += [right, mirror_x(right)]
G["starving"] = [([SPINE] + RIBS, False)]

I = place(G)
