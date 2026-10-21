"""Fifth drawing pass (spec 17, water): the statuses washing and drinking clear. Solid polygons only,
centred optically by geo2.place like icons_g, icons_h and icons_i."""
import math
from geo2 import *

G = {}

# dirty: a lumpy mud splat with flung droplets: irregular bumps, not radial points (the fallback
# "action" icon is a sparkle), and nothing like infected's gash and spores or bleed's drops.
def _r(a):
    return 15.5 + 2.4 * math.sin(3 * a + 0.4) + 1.6 * math.sin(7 * a + 1.1) + 0.8 * math.sin(11 * a + 2.0)
SPLAT = [(31 + _r(a) * math.cos(a), 34 + _r(a) * 0.86 * math.sin(a)) for a in [math.tau * i / 96 for i in range(96)]]
G["dirty"] = [([SPLAT, circle(10.5, 17, 4.4), circle(54.5, 15.5, 3.4), circle(53.5, 55, 3.0)], False)]

# thirsty: an empty drop, its inside dried and cracked (bleed is a full drop, drink a bowl under one).
DROP = [(32, 6)] + arcp(32, 40, 17, -30, 210, 40)
INNER = xf(DROP, about=(32, 39), scale=0.6)
G["thirsty"] = [([DROP, INNER], True), ([band([(31, 30), (35.5, 36), (29.5, 41.5), (33.5, 48)], 3.2)], False)]

I = place(G)
