"""Helpers for hand-placed icon geometry. Every call takes coordinates chosen by hand on the
64 grid; the helpers only spell out the SVG path syntax (capsules, circles, drops)."""
import math

def f(v):
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s

def pts(*p):
    return " ".join("%s %s" % (f(x), f(y)) for x, y in p)

def poly(*p):
    """Closed polygon subpath."""
    return "M" + pts(p[0]) + " L" + " L".join(pts(q) for q in p[1:]) + " Z"

def circ(cx, cy, r):
    """Circle as a subpath (for evenodd holes inside a solid path)."""
    return "M%s %s a%s %s 0 1 0 %s 0 a%s %s 0 1 0 %s 0 Z" % (f(cx - r), f(cy), f(r), f(r), f(2 * r), f(r), f(r), f(-2 * r))

def cap(x1, y1, x2, y2, w):
    """Capsule (rounded bar) from point 1 to point 2, width w."""
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * w / 2, dx / L * w / 2
    r = w / 2
    return "M%s L%s A%s %s 0 0 0 %s L%s A%s %s 0 0 0 %s Z" % (
        pts((x1 + nx, y1 + ny)), pts((x2 + nx, y2 + ny)), f(r), f(r), pts((x2 - nx, y2 - ny)),
        pts((x1 - nx, y1 - ny)), f(r), f(r), pts((x1 + nx, y1 + ny)))

def drop(cx, top, r):
    """Teardrop: point at (cx, top), round belly of radius r ending at top + 2.6r."""
    by = top + 1.6 * r
    return "M%s C%s %s %s A%s %s 0 0 1 %s C%s %s %s Z" % (
        pts((cx, top)), pts((cx + r * 0.35, top + r * 0.6)), pts((cx + r, by - r * 0.55)), pts((cx + r, by)),
        f(r), f(r), pts((cx - r, by)), pts((cx - r, by - r * 0.55)), pts((cx - r * 0.35, top + r * 0.6)), pts((cx, top)))

def star(cx, cy, R, r, n, rot=-90.0):
    p = []
    for i in range(n * 2):
        a = math.radians(rot + 180.0 * i / n)
        rr = R if i % 2 == 0 else r
        p.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return poly(*p)

def sparkle(cx, cy, s):
    """Four-point sparkle with concave sides."""
    k = s * 0.22
    return "M%s Q%s %s Q%s %s Q%s %s Q%s %s Z" % (
        pts((cx, cy - s)), pts((cx + k, cy - k)), pts((cx + s, cy)), pts((cx + k, cy + k)), pts((cx, cy + s)),
        pts((cx - k, cy + k)), pts((cx - s, cy)), pts((cx - k, cy - k)), pts((cx, cy - s)))

def gear(cx, cy, ro, ri, teeth, top_frac=0.42, base_frac=0.62):
    p = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        a = i * step - math.pi / 2
        for da, rr in ((-base_frac / 2, ri), (-top_frac / 2, ro), (top_frac / 2, ro), (base_frac / 2, ri)):
            aa = a + da * step
            p.append((cx + rr * math.cos(aa), cy + rr * math.sin(aa)))
    return poly(*p)

def arc_pt(cx, cy, r, deg):
    a = math.radians(deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))

def arc(cx, cy, r, a0, a1):
    """Clockwise arc (screen space, y down) from angle a0 to a1 in degrees, as an open subpath."""
    span = (a1 - a0) % 360.0
    p0, p1 = arc_pt(cx, cy, r, a0), arc_pt(cx, cy, r, a1)
    return "M%s A%s %s 0 %d 1 %s" % (pts(p0), f(r), f(r), 1 if span > 180 else 0, pts(p1))

def head(tip, back, w, notch=0.25):
    """Knapped flint arrowhead: tip point, direction from back centre to tip, half-width w."""
    tx, ty = tip
    bx, by = back
    dx, dy = tx - bx, ty - by
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy * w, ux * w
    nb = (bx + ux * L * notch, by + uy * L * notch)
    return poly(tip, (bx + nx, by + ny), nb, (bx - nx, by - ny))

# ---- shared hand-drawn shapes (placed in the 64 frame; callers wrap them in a transform)
def drum():
    """Drumstick: meat with a bite, bone shaft and knob end, all solid."""
    return ['<path transform="rotate(-38 37 27)" d="M20 27 A17 12.5 0 0 1 45.5 16.2 A4.6 4.6 0 0 0 50 19 A4.6 4.6 0 0 0 53.4 23.8 A17 12.5 0 0 1 20 27 Z"/>',
            '<path d="%s %s %s"/>' % (cap(27, 34.5, 15, 44.3, 5), circ(11.6, 42.6, 4.4), circ(16.6, 48.6, 4.4))]

def flame(hole=True):
    """Flame with base centre at (0,0), 24 tall, 20 wide."""
    d = "M0 -24 C5 -18.5 10 -14.5 10 -8.5 C10 -3.5 5.5 0 0 0 C-5.5 0 -10 -3.5 -10 -8.5 C-10 -12.5 -7.5 -15 -5.5 -18.5 C-4 -16 -3 -15 -2 -14.5 C-2.5 -18 -2 -21 0 -24 Z"
    if hole:
        return '<path fill-rule="evenodd" d="%s M0 -11 C1.8 -9 3 -7.5 3 -5.7 A3 3 0 0 1 -3 -5.7 C-3 -7.5 -1.8 -9 0 -11 Z"/>' % d
    return '<path d="%s"/>' % d


def g(transform, *els):
    return '<g transform="%s">%s</g>' % (transform, "".join(els))
