"""Fourteenth drawing pass (BAGUI, owner 2026-10-28: the premium currency beside the T-stones): the Warp Gem,
a flat-top hexagon with four cut facets knocked out. Solid polygons, centred optically by geo2.place."""
from geo2 import *

G = {}

HEX = [(19.0, 9.0), (45.0, 9.0), (58.0, 32.0), (45.0, 55.0), (19.0, 55.0), (6.0, 32.0)]
FACETS = [
    [(23.0, 17.0), (19.5, 24.0), (32.0, 24.0), (28.5, 17.0)],
    [(35.5, 17.0), (32.0, 24.0), (44.5, 24.0), (41.0, 17.0)],
    [(15.0, 32.0), (23.0, 46.0), (28.0, 46.0), (22.0, 32.0)],
    [(42.0, 32.0), (36.0, 46.0), (41.0, 46.0), (49.0, 32.0)],
]
G["warp_gem"] = [([HEX] + FACETS, True)]

I = place(G)
