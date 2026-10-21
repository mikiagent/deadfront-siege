"""Fifth drawing pass (spec 17, water): the statuses washing and drinking clear. Solid polygons only,
centred optically by geo2.place like icons_g, icons_h and icons_i."""
import math
from geo2 import *

G = {}

# dirty: a mud splat with flung droplets (nothing like infected's gash and spores or bleed's drops).
SPLAT = [(32 + (16.5 + 4.2 * math.sin(5 * a + 0.6) + 1.6 * math.sin(3 * a)) * math.cos(a),
          33 + (16.5 + 4.2 * math.sin(5 * a + 0.6) + 1.6 * math.sin(3 * a)) * math.sin(a))
         for a in [math.tau * i / 72 for i in range(72)]]
G["dirty"] = [([SPLAT, circle(11.5, 15, 3.8), circle(54, 13.5, 3.0), circle(53, 54, 4.2), circle(10, 50.5, 2.6)], False)]

# thirsty: an empty drop, its inside dried and cracked (bleed is a full drop, drink a bowl under one).
DROP = [(32, 6)] + arcp(32, 40, 17, -30, 210, 40)
INNER = xf(DROP, about=(32, 39), scale=0.6)
G["thirsty"] = [([DROP, INNER], True), ([band([(31, 30), (35.5, 36), (29.5, 41.5), (33.5, 48)], 3.2)], False)]

I = place(G)
