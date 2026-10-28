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
OUTER = chaikin(tube(LINE, W), 2)


def body(width_k, extra=0.0):
    """The stomach with its walls scaled by width_k (thin when empty) plus `extra` (swollen when overfull)."""
    return chaikin(tube(LINE, [max(4.0, w * width_k + extra) for w in W]), 2)


# HUDRULES round 3 (owner: "stomach symbol should change to different states empty stomach looks shrunk, full
# stomach looks big"): the shape carries the state; four drawings, since a fifth between hungry and full
# read as the same silhouette at 24 px (t_uiicons IoU check), so "normal" draws the full stomach a little smaller (HudStomach.GLYPH_SCALE). Empty is a thin, shrunken stomach, each state rounder and
# bigger, full the round stomach ("stomach"), overfull swollen past it with two pressure marks beside the
# gullet. Each variant also scales about the full stomach's optical centre (SCALE), so they share one centre.
SCALE = {"stomach_empty": 0.8, "stomach_hungry": 0.86, "stomach": 1.0, "stomach_overfull": 1.0}
VARIANTS = {
    "stomach_empty": [([body(0.55)], False)],
    "stomach_hungry": [([body(0.68)], False)],
    "stomach": [([OUTER], False)],
    "stomach_overfull": [([body(1.0, 5.0)], False), ([capsule((37.0, 15.0), (41.5, 10.0), 3.6), capsule((42.5, 22.0), (48.0, 19.0), 3.6)], False)],
}
(ox, oy), lo, hi = optical(VARIANTS["stomach"])
DX = round((32 - ox) * 2) / 2
DY = round((32 - oy) * 2) / 2
I = {}
for k, groups in VARIANTS.items():
    groups = [([xf(q, about=(ox, oy), scale=SCALE[k]) for q in polys], eo) for polys, eo in groups]
    pts = [p for polys, _ in groups for q in polys for p in xf(q, dx=DX, dy=DY)]
    over = max([6.0 - min(p[0] for p in pts), max(p[0] for p in pts) - 58.0, 6.0 - min(p[1] for p in pts), max(p[1] for p in pts) - 58.0, 0.0])
    fit = 26.0 / (26.0 + over)  # the swollen state scales about the centre to stay in the 6..58 live area
    els = []
    for polys, eo in groups:
        moved = [xf(xf(q, dx=DX, dy=DY), about=(32.0, 32.0), scale=fit) for q in polys if len(q) >= 3]
        els += [solid(*moved, eo=True)] if eo else [solid(q) for q in moved]
    I[k] = {"s": els}
