"""Polygon helpers for the second drawing pass: shapes are point lists placed by hand on the
64 grid; these helpers only sample curves, move points and cut knockout gaps (a gap where one
shape crosses another, since the icons are one colour and cannot use masks)."""
import math
from geo import f

def cubic(p0, p1, p2, p3, n=10):
    out = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        out.append((u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
                    u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]))
    return out

def path(start, *segs):
    """Polygon from a start point and segments: a point (line) or a 3-tuple of points (cubic)."""
    pts = [start]
    for s in segs:
        if len(s) == 3 and isinstance(s[0], tuple):
            pts += cubic(pts[-1], s[0], s[1], s[2])
        else:
            pts.append(s)
    return pts

def arcp(cx, cy, r, a0, a1, n=None):
    """Points along a circle from angle a0 to a1 (degrees, screen space, either direction)."""
    n = n or max(4, int(abs(a1 - a0) / 6))
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def circle(cx, cy, r):
    return arcp(cx, cy, r, 0, 360, 48)[:-1]

def capsule(a, b, w):
    ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
    return arcp(b[0], b[1], w / 2, ang - 90, ang + 90, 10) + arcp(a[0], a[1], w / 2, ang + 90, ang + 270, 10)

def band(pts, w):
    """Solid band of width w along an open polyline, with round ends."""
    left, right = [], []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * w / 2, dx / L * w / 2
        left.append((p[0] + nx, p[1] + ny))
        right.append((p[0] - nx, p[1] - ny))
    e = pts[-1]
    s = pts[0]
    ae = math.degrees(math.atan2(pts[-1][1] - pts[-2][1], pts[-1][0] - pts[-2][0]))
    as_ = math.degrees(math.atan2(pts[1][1] - pts[0][1], pts[1][0] - pts[0][0]))
    return left + arcp(e[0], e[1], w / 2, ae + 90, ae - 90, 8)[1:-1] + right[::-1] + arcp(s[0], s[1], w / 2, as_ - 90, as_ - 270, 8)[1:-1]

def xf(pts, dx=0.0, dy=0.0, rot=0.0, about=(0.0, 0.0), scale=1.0):
    """Rotate (degrees, clockwise on screen) and scale about a point, then translate."""
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    out = []
    for x, y in pts:
        x0, y0 = (x - about[0]) * scale, (y - about[1]) * scale
        out.append((about[0] + x0 * c - y0 * s + dx, about[1] + x0 * s + y0 * c + dy))
    return out

def mirror_x(pts, cx=32.0):
    return [(2 * cx - x, y) for x, y in pts][::-1]

def clip(poly, a, b, c):
    """Keep the part of poly where a*x + b*y + c >= 0 (Sutherland-Hodgman, one half-plane)."""
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        dp, dq = a * p[0] + b * p[1] + c, a * q[0] + b * q[1] + c
        if dp >= 0:
            out.append(p)
        if (dp >= 0) != (dq >= 0):
            t = dp / (dp - dq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out

def cut(poly, p0, p1, gap):
    """Split poly along the line p0-p1, leaving a gap of `gap` on each side of the line."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    a, b = -dy / L, dx / L
    c = -(a * p0[0] + b * p0[1])
    return [q for q in (clip(poly, a, b, c - gap), clip(poly, -a, -b, -c - gap)) if len(q) >= 3]

def side(poly, p0, p1, gap, keep=1):
    """The part of poly on one side (keep=+1 left of p0->p1, -1 right) of the line, `gap` away from it."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    a, b = -dy / L * keep, dx / L * keep
    c = -(a * p0[0] + b * p0[1])
    return clip(poly, a, b, c - gap)

def d(*polys):
    """SVG path data for one or more closed polygons."""
    return " ".join("M" + " L".join("%s %s" % (f(x), f(y)) for x, y in p) + " Z" for p in polys if len(p) >= 3)

def solid(*polys, eo=False):
    return '<path%s d="%s"/>' % (' fill-rule="evenodd"' if eo else "", d(*polys))

# ---------------------------------------------------------------- optical centring (solid modules)
def inside(poly, x, y):
    c = False
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            c = not c
    return c

def mask(groups, lo=-16, hi=80):
    m = {}
    for polys, eo in groups:
        for y in range(lo, hi):
            for x in range(lo, hi):
                if m.get((x, y)):
                    continue
                hits = sum(1 for p in polys if inside(p, x + 0.5, y + 0.5))
                if (hits % 2 == 1) if eo else hits > 0:
                    m[(x, y)] = True
    return [k for k, v in m.items() if v]

def optical(groups):
    xs = mask(groups)
    cx = sum(p[0] + 0.5 for p in xs) / len(xs)
    cy = sum(p[1] + 0.5 for p in xs) / len(xs)
    lo = (min(p[0] for p in xs), min(p[1] for p in xs))
    hi = (max(p[0] for p in xs) + 1, max(p[1] for p in xs) + 1)
    return ((cx + (lo[0] + hi[0]) / 2) / 2, (cy + (lo[1] + hi[1]) / 2) / 2), lo, hi

LIVE = 52.0   # ink fits the 6..58 live area

def place(G, log=None):
    """Scale each drawing into the live area if it is larger, then move it so its optical centre (mean of
    the ink centroid and the box centre) sits on 32,32, in half-unit steps, never past the live area."""
    I = {}
    for k, groups in G.items():
        (ox, oy), lo, hi = optical(groups)
        span = max(hi[0] - lo[0], hi[1] - lo[1])
        if span > LIVE + 0.5:
            s = LIVE / span
            groups = [([xf(p, about=(ox, oy), scale=s) for p in polys], eo) for polys, eo in groups]
            (ox, oy), lo, hi = optical(groups)
            (log or (lambda *a: None))("%-16s scaled %.2f" % (k, s))
        dx = round((32 - ox) * 2) / 2
        dy = round((32 - oy) * 2) / 2
        dx = max(6 - lo[0], min(58 - hi[0], dx))
        dy = max(6 - lo[1], min(58 - hi[1], dy))
        # nonzero groups: one <path> per polygon, so overlapping parts of opposite winding never cancel into holes
        els = []
        for polys, eo in groups:
            moved = [xf(p, dx=dx, dy=dy) for p in polys]
            els += [solid(*moved, eo=True)] if eo else [solid(p) for p in moved]
        I[k] = {"s": els}
        (log or (lambda *a: None))("%-16s shift %5.1f %5.1f  bbox %s..%s" % (k, dx, dy, (lo[0] + dx, lo[1] + dy), (hi[0] + dx, hi[1] + dy)))
    return I
