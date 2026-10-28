"""Ninth drawing pass (STATUSFX): the claw mark, the bleed status (owner 2026-10-28: "bleed is a claw
mark"). Solid polygons only, centred optically by geo2.place like icons_g..m."""
import math
from geo2 import *

G = {}


def slash(a, b, w, bend):
    """One claw slash from a to b: pointed at both ends, widest (w) a little past the middle, bowed by bend."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    left, right = [], []
    for i in range(17):
        t = i / 16
        c = (a[0] + dx * t + nx * bend * math.sin(math.pi * t), a[1] + dy * t + ny * bend * math.sin(math.pi * t))
        h = w / 2 * math.sin(math.pi * t ** 0.8)
        left.append((c[0] + nx * h, c[1] + ny * h))
        right.append((c[0] - nx * h, c[1] - ny * h))
    return left + right[::-1][1:-1]


# claw: three raked slashes, upper right to lower left (auto puts three small ones inside its cycle
# arrow; this is the bare wound, larger and bowed harder).
G["claw"] = [([slash((41 + k, 7), (21 + k, 57), 9.0, 3.5) for k in (-14.0, 0.0, 14.0)], False)]

I = place(G)
