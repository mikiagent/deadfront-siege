"""Eighth drawing pass (REST): the Rest context action, the Resting chip and the Well Rested status.
Solid polygons only, centred optically by geo2.place like icons_g..l."""
from geo2 import *
from icons_g import figure

G = {}

# rest: the survivor sitting on the ground, leaning back on one straight arm with the knees up (sleep
# is the moon; heel, kick and chase are standing or running figures).
G["rest"] = [(figure((15.5, 12), [[(19.5, 27), (9.5, 47.5)], [(28, 46.5), (40.5, 30), (50, 50)]], w=7.0,
                     torso=[(20, 25.5), (28, 46)]), False),
             ([capsule((5, 56.5), (59, 56.5), 5.0)], False)]

# well_rested: a sun rising over a pillow (sleep is the moon; the morning after a good night). Eight rays
# around the sun, the pillow a fat capsule under it.
import math
RAYS = [capsule((32 + 13.5 * math.cos(a), 25 + 13.5 * math.sin(a)), (32 + 19.5 * math.cos(a), 25 + 19.5 * math.sin(a)), 4.4)
        for a in [math.radians(180 + 30 * k) for k in range(7)]]
G["well_rested"] = [([circle(32, 25, 8.5)] + RAYS + [capsule((12, 49), (52, 49), 11.0)], False)]

I = place(G)
