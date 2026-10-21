

# ------------------------------------------------------------------ house kit (modular house parts)
# ASSUMPTION (the specs give no module numbers): the house module is 2.0 m wide, a storey 2.4 m
# high, walls 0.24 m thick and a roof slope 1.0 m of run for 0.6 m of rise. Every part is centred
# in plan on its module and based at z = 0 (the foundation sinks 0.48 m into the ground), so a
# house can be assembled from any mix of the three material tiers. The front faces -Y, which
# becomes +Z in Godot, towards the iso camera.
HOUSE_W = 2.0
HOUSE_H = 2.4
HOUSE_T = 0.24
ROOF_RUN = 1.0
ROOF_RISE = 0.6
ROOF_ANG = math.degrees(math.atan2(ROOF_RISE, ROOF_RUN))
ROOF_LEN = math.hypot(ROOF_RUN, ROOF_RISE)
WIN_W = 0.9
WIN_SILL = 1.0
WIN_HEAD = 1.9
DOOR_W = 1.0
DOOR_H = 2.0


def _stone_wall(p, x0, x1, z0, z1, row_h=0.4, skip=None, depth=HOUSE_T):
    """Courses of stone blocks filling a rectangle; `skip` is an (x0, x1, z0, z1) hole."""
    rows = max(1, int(round((z1 - z0) / row_h)))
    ch = (z1 - z0) / rows
    for i in range(rows):
        z = z0 + ch * (i + 0.5)
        off = (ch / 2) if (i % 2) else 0.0
        k = -1
        while True:
            bx = x0 + k * ch + off
            if bx > x1:
                break
            k += 1
            a, b = max(bx, x0), min(bx + ch, x1)
            if b - a < 0.12:
                continue
            cx = (a + b) / 2
            if skip and skip[0] < cx < skip[1] and skip[2] < z < skip[3]:
                continue
            p.box((b - a - 0.035, depth, ch - 0.035), (cx, 0, z),
                  "stone" if (i + k) % 3 else "stone_dark", tile_m=0.7)


def _window_frame(p, w=WIN_W, z0=WIN_SILL, z1=WIN_HEAD):
    """Frame, mullions and dark glass in the front face of a wall opening."""
    t = 0.07
    for x in (-w / 2 - t / 2, w / 2 + t / 2):
        p.box((t, 0.1, z1 - z0 + 2 * t), (x, -0.13, (z0 + z1) / 2), "wood_dark")
    for z in (z0 - t / 2, z1 + t / 2):
        p.box((w + 2 * t, 0.1, t), (0, -0.13, z), "wood_dark")
    p.box((0.05, 0.09, z1 - z0), (0, -0.13, (z0 + z1) / 2), "wood_dark")
    p.box((w, 0.09, 0.05), (0, -0.13, (z0 + z1) / 2), "wood_dark")
    # the dark opening behind the glass
    p.box((w - 0.02, 0.04, z1 - z0 - 0.02), (0, 0.06, (z0 + z1) / 2), "soot")


def house_foundation():
    """Stone plinth under a 2x2 m house module: the top course is at z = 0 and the base sinks
    0.48 m into the ground, so a house can stand on a slope."""
    p = Part("house_foundation")
    ch = 0.16
    for i in range(3):
        z = -ch * (i + 0.5)
        tile = "stone" if (i % 2) else "stone_dark"
        for sy in (-1, 1):
            for j in range(4):
                p.box((0.46, 0.24, ch * 0.94), (-0.75 + j * 0.5, sy * 0.88, z), tile, tile_m=0.5)
        for sx in (-1, 1):
            for j in range(4):
                p.box((0.24, 0.46, ch * 0.94), (sx * 0.88, -0.75 + j * 0.5, z), tile, tile_m=0.5)
    for i in range(6):
        a = i * 1.05
        p.rock(0.15, (math.cos(a) * 1.0, math.sin(a) * 1.0, -0.4 + 0.09 * (i % 2)),
               tile="stone_dark", squash=(1.1, 1.0, 0.7), seed=40 + i)
    return [(p, (0, 0, 0))]


def house_floor():
    """Plank deck of a 2x2 m module on three joists; the boards run across the module."""
    p = Part("house_floor")
    for x in (-0.86, 0.0, 0.86):
        p.box((0.12, 2.0, 0.07), (x, 0, 0.035), "wood_dark", tile_m=0.6)
    for i in range(8):
        p.box((2.0, 0.23, 0.06), (0, -0.875 + i * 0.25, 0.10),
              "plank" if i % 2 else "wood", tile_m=1.0)
    return [(p, (0, 0, 0))]


def house_wall():
    """Log wall of a 2 m module: 2 m wide, 2.4 m high, 0.24 m thick."""
    p = Part("house_wall")
    _log_courses(p, -1.0, 1.0, 0.0, 2.4, r=0.12)
    for sx in (-1, 1):
        p.cyl(0.115, 2.4, (sx * 0.92, 0, 1.2), "bark", seg=7, cap_tile="log_end")
    return [(p, (0, 0, 0))]


def house_wall_window():
    """Log wall with a 0.9 x 0.9 m window (sill 1.0 m) framed and glazed on the front."""
    p = Part("house_wall")
    _log_courses(p, -1.0, 1.0, 0.0, WIN_SILL, r=0.12)
    for sx in (-1, 1):
        p.cyl(0.12, WIN_HEAD - WIN_SILL, (sx * 0.57, 0, (WIN_SILL + WIN_HEAD) / 2), "bark", seg=7,
              cap_tile="log_end")
    _log_courses(p, -1.0, 1.0, WIN_HEAD, 2.4, r=0.12)
    p.box((1.3, 0.28, 0.12), (0, 0, WIN_SILL + 0.06), "wood_dark")
    p.box((1.3, 0.28, 0.14), (0, 0, WIN_HEAD - 0.07), "wood_dark")
    _window_frame(p)
    return [(p, (0, 0, 0))]


def house_wall_doorway():
    """Log wall with a 1.0 x 2.0 m doorway for the hinged door leaf."""
    p = Part("house_wall")
    _log_courses(p, -1.0, -0.5, 0.0, 2.4, r=0.12)
    _log_courses(p, 0.5, 1.0, 0.0, 2.4, r=0.12)
    p.box((1.16, 0.3, 0.2), (0, 0, DOOR_H + 0.1), "wood_dark")
    p.box((2.0, 0.08, 0.08), (0, -0.06, 2.36), "wood_dark")
    p.box((DOOR_W, 0.3, 0.06), (0, 0, 0.03), "plank")
    return [(p, (0, 0, 0))]


def house_door():
    """Hinged plank door leaf for the 1.0 x 2.0 m doorway. Its origin sits on the hinge (the
    leaf starts at local x = 0), so code can swing it about local Y."""
    p = Part("house_door")
    for i in range(5):
        p.box((0.185, 0.06, 2.0), (0.095 + i * 0.19, 0, 1.0),
              "plank" if i % 2 else "wood", tile_m=0.9)
    for z in (0.35, 1.0, 1.65):
        p.box((0.95, 0.05, 0.13), (0.475, -0.055, z), "wood_dark")
    p.plank((0.08, -0.06, 0.28), (0.88, -0.06, 1.72), 0.1, 0.04, "wood_dark", up=(0, -1, 0))
    for z in (0.35, 1.65):
        p.box((0.3, 0.045, 0.07), (0.17, -0.075, z), "iron")
    p.cyl(0.035, 0.09, (0.8, -0.08, 1.0), "iron", rot=(90, 0, 0), seg=6)
    p.box((0.1, 0.03, 0.1), (0.8, -0.05, 1.0), "iron")
    return [(p, (0, 0, 0))]


def _roof_slope(p, tile, depth=0.16):
    """The 2 m wide sloping panel of a roof: 1.0 m of run for 0.6 m of rise, eave at z = 0."""
    p.box((2.0, ROOF_LEN, depth), (0, 0, ROOF_RISE / 2), tile, rot=(ROOF_ANG, 0, 0), tile_m=1.2)


def _roof_rafter_tails(p):
    """Rafter ends and an eave board, so the roof edge reads as built, not a slab."""
    p.plank((-1.0, -0.48, 0.05), (1.0, -0.48, 0.05), 0.14, 0.1, "wood_dark", up=(0, 0, 1))
    for x in (-0.78, -0.26, 0.26, 0.78):
        p.box((0.1, 0.24, 0.09), (x, -0.5, 0.03), "wood_dark")


def house_roof():
    """One thatch roof slope of a 2 m module: straw on the slope, bound with rope, fringed at
    the eave."""
    p = Part("house_roof")
    _roof_slope(p, "thatch")
    _roof_rafter_tails(p)
    for i in range(9):
        p.box((0.14, 0.08, 0.2), (-0.9 + i * 0.225, -0.55, 0.08), "thatch", rot=(0, -18, 0))
    for x in (-0.66, 0.0, 0.66):
        p.log((x, -0.42, 0.06), (x, 0.42, 0.6), 0.016, tile="rope", seg=4, end_tile="rope")
    p.plank((-1.0, 0.46, 0.6), (1.0, 0.46, 0.6), 0.1, 0.1, "wood_dark", up=(0, 0, 1))
    return [(p, (0, 0, 0))]


def house_roof_corner():
    """Hip cap for a roof corner: a thatch pyramid over a 1 x 1 m plan, apex 0.6 m up, with a
    wooden hip roll along the outer corner."""
    p = Part("house_roof_corner")
    base = [(-0.5, -0.5, 0.0), (0.5, -0.5, 0.0), (0.5, 0.5, 0.0), (-0.5, 0.5, 0.0)]
    apex = (0.0, 0.0, ROOF_RISE)
    for i in range(4):
        a, b = base[i], base[(i + 1) % 4]
        n = (Vector(b) - Vector(a)).cross(Vector(apex) - Vector(a)).normalized()
        p.prism([a, b, apex], n * 0.09, "thatch", tile_m=1.0)
    p.log((-0.5, -0.5, 0.02), apex, 0.055, tile="wood_dark", seg=6)
    for i in range(4):
        a, b = base[i], base[(i + 1) % 4]
        p.plank((a[0], a[1], 0.04), (b[0], b[1], 0.04), 0.12, 0.08, "wood_dark", up=(0, 0, 1))
    return [(p, (0, 0, 0))]


def house_roof_gable():
    """Gable end that closes the roof: a 2 m wide triangle 0.6 m high, 0.24 m thick, boarded."""
    p = Part("house_roof_gable")
    p.prism([(-1.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, ROOF_RISE)], (0, 0.24, 0), "plank", tile_m=1.2)
    p.plank((-1.0, -0.03, 0.02), (0.0, -0.03, ROOF_RISE - 0.02), 0.1, 0.06, "wood_dark", up=(0, -1, 0))
    p.plank((1.0, -0.03, 0.02), (0.0, -0.03, ROOF_RISE - 0.02), 0.1, 0.06, "wood_dark", up=(0, -1, 0))
    p.box((2.0, 0.1, 0.1), (0, 0.1, 0.05), "wood_dark")
    for x in (-0.45, 0.0, 0.45):
        p.box((0.09, 0.26, 0.5), (x, 0.1, 0.28), "wood_dark")
    return [(p, (0, 0, 0))]


def house_stairs():
    """Four-tread timber stair up to a floor: 1.2 m wide, 0.3 m per tread, 0.2 m per rise."""
    p = Part("house_stairs")
    for x in (-0.55, 0.55):
        p.plank((x, -0.6, 0.05), (x, 0.6, 0.85), 0.12, 0.16, "wood_dark", up=(0, 0, 1))
    for i in range(4):
        p.box((1.24, 0.3, 0.07), (0, -0.45 + i * 0.3, 0.2 * (i + 1) - 0.035), "plank", tile_m=0.8)
    p.box((1.24, 0.32, 0.07), (0, 0.62, 0.8), "plank", tile_m=0.8)
    for z in (0.5, 1.0):
        p.cyl(0.05, 0.9, (0.68, -0.5, z + 0.45), "bark", seg=6, cap_tile="log_end")
    p.plank((0.68, -0.5, 1.0), (0.68, 0.5, 1.5), 0.08, 0.08, "wood", up=(0, 0, 1))
    return [(p, (0, 0, 0))]


def house_wall_timber():
    """Timber-frame wall of a 2 m module: posts, rails and braces over a plank infill."""
    p = Part("house_wall")
    p.box((2.0, 0.24, 0.14), (0, 0, 0.07), "wood_dark")
    p.box((2.0, 0.24, 0.16), (0, 0, 2.32), "wood_dark")
    for x in (-0.92, -0.46, 0.0, 0.46, 0.92):
        p.box((0.14, 0.22, 2.4), (x, 0, 1.2), "wood_dark")
    for z in (0.86, 1.72):
        p.box((2.0, 0.2, 0.12), (0, 0, z), "wood_dark")
    p.box((1.72, 0.1, 2.12), (0, 0.06, 1.2), "plank", tile_m=1.2)
    p.plank((-0.86, -0.11, 0.2), (-0.06, -0.11, 0.8), 0.1, 0.05, "wood_dark", up=(0, -1, 0))
    p.plank((0.06, -0.11, 1.78), (0.86, -0.11, 1.1), 0.1, 0.05, "wood_dark", up=(0, -1, 0))
    for x in (-0.7, 0.7):
        p.cyl(0.028, 0.06, (x, -0.12, 1.2), "iron", rot=(90, 0, 0), seg=5)
    return [(p, (0, 0, 0))]


def house_wall_window_timber():
    """Timber-frame wall with the same 0.9 x 0.9 m window opening as the log wall."""
    p = Part("house_wall")
    p.box((2.0, 0.24, 0.14), (0, 0, 0.07), "wood_dark")
    p.box((2.0, 0.24, 0.16), (0, 0, 2.32), "wood_dark")
    for x in (-0.92, -0.53, 0.53, 0.92):
        p.box((0.16, 0.22, 2.4), (x, 0, 1.2), "wood_dark")
    p.box((1.24, 0.2, 0.12), (0, 0, 0.5), "wood_dark")
    p.box((1.24, 0.2, 0.12), (0, 0, 2.1), "wood_dark")
    p.box((1.24, 0.2, 0.14), (0, 0, WIN_HEAD + 0.07), "wood_dark")
    p.box((1.24, 0.2, 0.12), (0, 0, WIN_SILL - 0.06), "wood_dark")
    # infill: below the sill, above the head and the two side panels
    p.box((1.0, 0.1, 0.7), (0, 0.06, 0.5), "plank", tile_m=0.8)
    p.box((1.0, 0.1, 0.28), (0, 0.06, 2.26), "plank", tile_m=0.8)
    for sx in (-1, 1):
        p.box((0.24, 0.1, 2.1), (sx * 0.73, 0.06, 1.2), "plank", tile_m=0.8)
    p.plank((-0.85, -0.11, 0.2), (-0.6, -0.11, 0.8), 0.1, 0.05, "wood_dark", up=(0, -1, 0))
    p.plank((0.6, -0.11, 1.9), (0.85, -0.11, 1.2), 0.1, 0.05, "wood_dark", up=(0, -1, 0))
    _window_frame(p)
    return [(p, (0, 0, 0))]


def house_roof_timber():
    """One roof slope of a 2 m module in the timber tier: dark cedar shingles on the slope."""
    p = Part("house_roof")
    _roof_slope(p, "shingle", depth=0.13)
    _roof_rafter_tails(p)
    p.plank((-1.0, 0.46, 0.6), (1.0, 0.46, 0.6), 0.12, 0.1, "wood_dark", up=(0, 0, 1))
    for x in (-0.8, -0.4, 0.0, 0.4, 0.8):
        p.log((x, -0.4, 0.1), (x, 0.4, 0.56), 0.022, tile="wood_dark", seg=4, end_tile="wood_dark")
    return [(p, (0, 0, 0))]


def house_wall_stone():
    """Stone wall of a 2 m module: coursed blocks with bigger quoins at the corners."""
    p = Part("house_wall")
    _stone_wall(p, -1.0, 1.0, 0.0, 2.4, row_h=0.4)
    for i in range(6):
        z = 0.2 + i * 0.4
        for sx in (-1, 1):
            p.box((0.34, 0.3, 0.3), (sx * 0.83, 0, z), "stone_dark", tile_m=0.6)
    return [(p, (0, 0, 0))]


def house_wall_window_stone():
    """Stone wall with the same 0.9 x 0.9 m window opening as the log wall."""
    p = Part("house_wall")
    _stone_wall(p, -1.0, 1.0, 0.0, WIN_SILL, row_h=0.25)
    _stone_wall(p, -1.0, 1.0, WIN_HEAD, 2.4, row_h=0.25)
    for sx in (-1, 1):
        _stone_wall(p, sx * 0.45, sx * 1.0, WIN_SILL, WIN_HEAD, row_h=0.3)
    p.box((1.24, 0.32, 0.16), (0, 0, WIN_HEAD + 0.06), "stone_dark", tile_m=0.6)
    p.box((1.24, 0.32, 0.12), (0, 0, WIN_SILL - 0.04), "stone_dark", tile_m=0.6)
    _window_frame(p)
    return [(p, (0, 0, 0))]


def house_roof_stone():
    """One roof slope of a 2 m module in the stone tier: slate on the slope."""
    p = Part("house_roof")
    _roof_slope(p, "slate", depth=0.14)
    _roof_rafter_tails(p)
    p.plank((-1.0, 0.46, 0.6), (1.0, 0.46, 0.6), 0.12, 0.1, "wood_dark", up=(0, 0, 1))
    for x in (-0.8, -0.4, 0.0, 0.4, 0.8):
        p.log((x, -0.4, 0.1), (x, 0.4, 0.56), 0.022, tile="wood_dark", seg=4, end_tile="wood_dark")
    return [(p, (0, 0, 0))]
