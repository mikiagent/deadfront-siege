"""Eleventh drawing pass (HUDRULES): the stomach, inside the HUD's fullness ring (owner 2026-10-28: "add a
circular stomach indicator to the right of the health bar"). Solid polygons only, centred optically by
geo2.place like icons_g..o."""
import math
from geo2 import *
from icons_g import chaikin

G = {}


def tube(centre, widths):
    """A closed solid along a centreline whose width changes point by point (a band of varying width)."""
    left, right = [], []
    for i, p in enumerate(centre):
        a = centre[max(0, i - 1)]
        b = centre[min(len(centre) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * widths[i] / 2, dx / L * widths[i] / 2
        left.append((p[0] + nx, p[1] + ny))
        right.append((p[0] - nx, p[1] - ny))
    return left + right[::-1]


# stomach: the gullet comes down at the top, swells into the J of the body (round at the lower left),
# narrows at the pylorus on the right and turns down into the gut.
LINE = path((25, 5), (25.5, 13), ((26, 20), (14, 24), (16, 38)), ((18, 50), (36, 52), (44, 42)), ((47, 37), (52, 34), (55, 39)), (55, 44), (54, 53))
n = len(LINE)
W = []
for i, p in enumerate(LINE):
    t = i / (n - 1)
    # 7 at the gullet, swelling to 24 through the body, easing to 8 at the pylorus and the gut
    body = math.sin(math.pi * min(1.0, max(0.0, (t - 0.06) / 0.78))) ** 0.8
    W.append((7.0 if t < 0.45 else 8.0) + 17.0 * body)
G["stomach"] = [([chaikin(tube(LINE, W), 2)], False)]

# water_drop (WEATHER, owner 2026-10-28: an effect for wetness like bleed and poison): one big falling drop
# with a highlight knocked out of its left shoulder, and a small drop beside it.
DROP = path((30, 6), ((36, 16), (48, 26), (48, 38)), ((48, 49), (40, 57), (30, 57)), ((20, 57), (12, 49), (12, 38)),
            ((12, 26), (24, 16), (30, 6)))
SHINE = path((19.5, 39), ((19.5, 33), (22.5, 28.5), (25.5, 25)), ((27, 27), (25.5, 32), (25, 40)), ((23.5, 43), (19.5, 42.5), (19.5, 39)))
SMALL = path((51, 8), ((53.5, 12), (57, 15), (57, 18.5)), ((57, 21.5), (54.5, 23.5), (51, 23.5)), ((47.5, 23.5), (45, 21.5), (45, 18.5)),
             ((45, 15), (48.5, 12), (51, 8)))
G["water_drop"] = [([DROP, SHINE], True), ([SMALL], False)]

I = place(G)
