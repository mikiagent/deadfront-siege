"""Twelfth drawing pass (WEATHER, owner 2026-10-28): the Wet effect's water drop and Smoke Inhalation's
smoke cloud, for their status boxes beside the survivor. Solid polygons only, centred optically by
geo2.place like icons_g..p."""
from geo2 import *

G = {}

# water_drop (WEATHER, owner 2026-10-28: an effect for wetness like bleed and poison): one big falling drop
# with a highlight knocked out of its left shoulder, and a small drop beside it.
DROP = path((30, 6), ((36, 16), (48, 26), (48, 38)), ((48, 49), (40, 57), (30, 57)), ((20, 57), (12, 49), (12, 38)),
            ((12, 26), (24, 16), (30, 6)))
SHINE = path((19.5, 39), ((19.5, 33), (22.5, 28.5), (25.5, 25)), ((27, 27), (25.5, 32), (25, 40)), ((23.5, 43), (19.5, 42.5), (19.5, 39)))
SMALL = path((51, 8), ((53.5, 12), (57, 15), (57, 18.5)), ((57, 21.5), (54.5, 23.5), (51, 23.5)), ((47.5, 23.5), (45, 21.5), (45, 18.5)),
             ((45, 15), (48.5, 12), (51, 8)))
G["water_drop"] = [([DROP, SHINE], True), ([SMALL], False)]

# smoke_inhalation (owner 2026-10-28: a hazard, "the smoke should make you take damage"): a heavy smoke
# cloud low down with three wisps curling up out of it.
CLOUD = [circle(18, 45, 9.5), circle(31, 40, 12.5), circle(45, 45, 9.5), capsule((17, 50), (46, 50), 8)]
WISPS = [band([(21, 31), (18, 24), (22, 17), (19, 11)], 5.6), band([(32, 28), (35, 21), (31, 14), (34, 8)], 5.6),
         band([(43, 32), (46, 25), (42, 18), (44, 13)], 5.2)]
G["smoke_inhalation"] = [(CLOUD, False), (WISPS, False)]

I = place(G)
