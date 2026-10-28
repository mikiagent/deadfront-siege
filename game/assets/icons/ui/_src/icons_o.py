"""Tenth drawing pass (BRAINICON): the brain, the skill point (owner 2026-10-28: "need a brain symbol for
skill points"). Solid polygons only, centred optically by geo2.place like icons_g..n."""
import math
from geo2 import *
from icons_g import chaikin

G = {}


def hemisphere(gap, rx, ry, lobes, depth):
    """Left half of the brain seen from above: a half-ellipse whose round side is a run of `lobes` bumps
    (cusps `depth` deep between them), its flat side `gap` left of the midline."""
    cx = 32 - gap
    pts = []
    for i in range(73):
        phi = math.pi * i / 72  # 0 = bottom of the midline, pi = top
        r = 1 - depth * (1 - abs(math.sin(lobes * phi)))
        a = math.pi / 2 + phi
        pts.append((cx + rx * r * math.cos(a), 32 + ry * r * math.sin(a)))
    return chaikin(pts + [(cx, 32 - ry * 0.55), (cx, 32 + ry * 0.55)], 1)


# brain: two hemispheres with a midline gap, three folds (gyri) knocked out of each.
LEFT = hemisphere(2.4, 21.5, 23.5, 3.5, 0.13)
FOLDS = [band(p, 4.0) for p in (path((26.5, 15.5), ((20, 15.5), (16.5, 19.5), (17.5, 25.5))),
                                path((12.5, 34), ((16, 28.5), (20, 29.5), (21.5, 33)), ((23, 36), (26, 35), (27, 31.5))),
                                path((17, 39.5), ((16.5, 45.5), (20, 49), (26.5, 48.5))))]
G["brain"] = [([LEFT] + FOLDS, True), ([mirror_x(LEFT)] + [mirror_x(p) for p in FOLDS], True)]

I = place(G)
