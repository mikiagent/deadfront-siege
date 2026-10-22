#!/usr/bin/env python3.13
"""SPRITES2D: cut the owner's green-screen art sheets into trimmed RGBA game sprites.

    python3.13 tools/sprites2d/cut.py [--sheet sheet-palms] [--debug]

Reads every docs/reference/2d-assets/sheet-*.webp, keys out the pure-green background,
splits the remaining art into items, trims each item and writes
game/assets/nature/sprites2d/<sheet>/<short>_<nn>_<slug>.png plus game/data/world/sprites2d.json.

Only numpy is available (Blender's python). No PIL / scipy / OpenCV.
Names, kinds, heights and flags are kept between runs in tools/sprites2d/labels.json
(matched by id first, then by sprite centre on the sheet), so a re-run never loses the mapping.
Hand fixes for items that touch on the sheet live in tools/sprites2d/overrides.json.
"""
import json
import os
import struct
import subprocess
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rules  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SHEET_DIR = os.path.join(ROOT, "docs/reference/2d-assets")
OUT_DIR = os.path.join(ROOT, "game/assets/nature/sprites2d")
MANIFEST = os.path.join(ROOT, "game/data/world/sprites2d.json")
OVERRIDES = os.path.join(ROOT, "tools/sprites2d/overrides.json")
LABELS = os.path.join(ROOT, "tools/sprites2d/labels.json")
TMP = "/tmp/sprites2d"

# The screen green is not identical on every sheet the owner paints: the round-1 sheets and
# tall-grasses are ~(3, 250, 3), jungle-trees is ~(4, 234, 7), jungle-cliffs ~(2, 238, 3). The
# key is therefore measured per sheet from the border ring (set in detect_key()).
KEY = np.array([5, 250, 4], dtype=np.float32)

# --- thresholds (measured on the four sheets, see the report) -------------------------------
# Distance to the key colour (RGB units). Plant greens sit 95+ away; antialiased edges between.
D_CLEAR = 28.0      # at or below: fully transparent (key + its 2/u spread)
D_OPAQUE = 78.0     # at or above: fully opaque
SOLID = 0.35        # alpha used to build the item mask
MIN_AREA = 400      # px of a full-resolution item; smaller specks are paint noise
MIN_SIDE = 24       # px; the game never draws an item smaller than this
CLOSE_PX = 0
PAD = 2             # px of transparent padding around a trimmed item


# --- io -----------------------------------------------------------------------------------
def decode_webp(path):
    """dwebp -> PAM (P7, depth 3) -> uint8 HxWx3. No PIL in Blender's python."""
    os.makedirs(TMP, exist_ok=True)
    pam = os.path.join(TMP, os.path.basename(path) + ".pam")
    subprocess.run(["dwebp", "-quiet", path, "-pam", "-o", pam], check=True)
    with open(pam, "rb") as f:
        data = f.read()
    end = data.index(b"ENDHDR\n") + len(b"ENDHDR\n")
    header = {}
    for line in data[:end].decode("ascii", "replace").splitlines():
        parts = line.split()
        if len(parts) == 2:
            header[parts[0]] = parts[1]
    w, h = int(header["WIDTH"]), int(header["HEIGHT"])
    depth = int(header["DEPTH"])
    raw = np.frombuffer(data[end:end + w * h * depth], np.uint8)
    if depth == 4:
        return raw.reshape(h, w, 4)[:, :, :3].copy()
    return raw.reshape(h, w, 3).copy()


def write_png(path, rgba):
    """Minimal 8-bit RGBA PNG writer (zlib is in the stdlib)."""
    h, w = rgba.shape[:2]
    raw = np.ascontiguousarray(rgba).tobytes()
    stride = w * 4
    lines = b"".join(b"\x00" + raw[y * stride:(y + 1) * stride] for y in range(h))

    def chunk(tag, payload):
        c = tag + payload
        return struct.pack(">I", len(payload)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    ihdr = struct.pack(">II", w, h) + bytes([8, 6, 0, 0, 0])
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(lines, 9)) + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


# --- keying -------------------------------------------------------------------------------
def detect_key(rgb):
    """Median colour of a 6 px border ring: the screen the owner painted on."""
    ring = np.concatenate([
        rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3),
        rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3),
    ])
    return np.median(ring, axis=0).astype(np.float32)


def key_sheet(rgb):
    """Soft alpha from the distance to the key colour + un-mix of the green fringe."""
    f = rgb.astype(np.float32)
    d = np.sqrt(((f - KEY) ** 2).sum(-1))
    a = np.clip((d - D_CLEAR) / (D_OPAQUE - D_CLEAR), 0.0, 1.0)
    # Un-mix: C = a*F + (1-a)*KEY  ->  F = (C - (1-a)*KEY) / a (a is tiny at the edge, clamp).
    am = np.maximum(a, 0.02)[..., None]
    un = (f - (1.0 - a)[..., None] * KEY) / am
    out = np.clip(un, 0.0, 255.0)
    out = np.where(a[..., None] > 0.0, out, f)  # fully clear pixels keep their colour (invisible)
    return out, a


RIM_PX = 2          # px of rim that may be recoloured (audit round 3: never deeper)
D_SPILL = 95.0      # pixels this close to the key are spill, not paint (foliage sits 95+ away)


def _dilate(mask, n=1):
    m = mask.copy()
    for _ in range(n):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    return m


def despill(rgb, a):
    """Give the outermost 2-3 px of a silhouette the colour of the paint just inside it.

    The painter's antialias row (and screen showing through thin strands) is a blend the distance
    key reads as opaque: 50 % screen still sits ~140 RGB units from the key. Un-mixing cannot
    recover it, and the old "push green below max(R,B)" clamp turned frond tips black while lime
    rims survived.

    Round-3 rule (orchestrator): never recolour a pixel more than 2 px inside the item's alpha
    edge, and fade alpha instead of filling a rim with a mean colour. Earlier versions painted
    every pixel that was merely "greener than the item's average" or "not fully solid" and so
    flooded whole leaves with a flat tan (resources_09_red_helconia) and left a khaki matte on
    tall-grasses / jungle-cliffs. So now:
      1. rim = visible pixels within RIM_PX of clear background (plus the part-transparent row);
      2. each rim pixel takes the colour of the nearest real paint, grown inwards-to-outwards
         over at most 4 rings (BFS), so texture is copied, not averaged to a mean;
      3. a rim pixel the paint never reached is a screen blend without paint behind it: its alpha
         is faded by its distance to the key, and its colour is left alone (invisible anyway);
      4. rim green is capped to the paint's own green excess (which may be negative for sand,
         shell, rock), so no lime edge and no black tick.
    """
    f = rgb.astype(np.float32)
    d = np.sqrt(((f - KEY) ** 2).sum(-1))
    clear = a <= 0.01
    visible = a > 0.0
    solid = a > 0.95
    near_clear = _dilate(clear, RIM_PX)
    rim = visible & near_clear
    # paint = solid pixels at least RIM_PX+2 inside the silhouette and far from the key
    deep = solid & ~_dilate(clear, RIM_PX + 2) & (d > D_SPILL)
    if deep.sum() < 50:
        deep = solid & ~near_clear
    if deep.sum() < 20:
        return rgb, a, np.zeros(a.shape, bool)   # nothing to copy from (a sliver): leave it be
    exc = f[..., 1] - np.maximum(f[..., 0], f[..., 2])
    # The cap is the item's own green excess at its 90th percentile, not its mean: an item whose
    # edge is foliage and whose inside is rock (a cliff with plants on it) is green all over, and
    # a mean would call its own leaves a fringe.
    ref = float(np.percentile(exc[deep], 90))
    known = deep.copy()
    fill = f.copy()
    gex = exc.copy()
    for _ in range(4):
        todo = rim & ~known
        if not todo.any():
            break
        acc = np.zeros_like(fill)
        gacc = np.zeros(a.shape, np.float32)
        cnt = np.zeros(a.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += np.roll(np.roll(fill, dy, 0), dx, 1) * k[..., None]
            gacc += np.roll(np.roll(gex, dy, 0), dx, 1) * k
            cnt += k
        grow = todo & (cnt > 0)
        if not grow.any():
            break
        n = np.maximum(cnt, 1)
        fill = np.where(grow[..., None], acc / n[..., None], fill)
        gex = np.where(grow, gacc / n, gex)
        known = known | grow
    reached = rim & known
    # rim pixels keep the copied colour, with green capped to what the paint has
    rb = np.maximum(fill[..., 0], fill[..., 2])
    cap = np.minimum(gex, min(ref + 12.0, 55.0))
    fill[..., 1] = np.where(reached & (fill[..., 1] > rb + cap), rb + cap, fill[..., 1])
    out = np.where(reached[..., None], fill, f)
    # rim pixels no paint reached: fade by distance to the key, keep their own colour
    lost = rim & ~known
    fade = np.clip((d - 70.0) / 60.0, 0.0, 1.0)
    a = np.where(lost, a * fade, a)
    holes = np.zeros(a.shape, bool)
    # A visible pixel still within 95 units of the key is the screen itself showing through a thin
    # strand or a pinhole, not paint: nothing copies there and no amount of fading hides the lime,
    # so it goes fully transparent. (Measured: such pixels sit 1-6 px from the silhouette, i.e. in
    # the antialias band the paint fill already covers where there is paint behind them.)
    holes = (a > 0.0) & (d < 95.0)
    return np.clip(out, 0.0, 255.0), a, holes


def rim_fix(rgba):
    """Per-item rim pass: the rim may not be greener than the item's own interior.

    despill() runs on the whole sheet, so its notion of "the paint" is the sheet's average - a
    jungle green - which is wrong for a brown coconut or a grey rock (their rim came out greener
    than the item and read as a lime edge at 2x on grey). The item itself knows the answer: take
    the mean green excess of its opaque interior and clamp every rim pixel to it.
    """
    f = rgba.astype(np.float32)
    al = f[..., 3]
    inner = al >= 200
    if inner.sum() < 40:
        return rgba
    exc = f[..., 1] - np.maximum(f[..., 0], f[..., 2])
    deep = _erode(inner, 2)
    ref = float(exc[deep].mean()) if deep.sum() >= 20 else float(exc[inner].mean())
    rb = np.maximum(f[..., 0], f[..., 2])
    lim = rb + min(ref + 20.0, 55.0)
    # only the outermost 2 px may be touched (round-3 audit: no 4-8 px khaki matte)
    rim = (al > 0) & _dilate(al == 0, RIM_PX)
    f[..., 1] = np.where(rim & (f[..., 1] > lim), lim, f[..., 1])
    return np.clip(f, 0, 255).astype(np.uint8)


def _erode(mask, n):
    m = mask.copy()
    for _ in range(n):
        m = m & np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1)
    return m


def resize_area(rgba, nw, nh):
    """Exact area-average resize (box filter) on premultiplied colour, so edges do not fringe.

    np.add.reduceat cannot express fractional source ranges, so integrate with cumulative sums:
    each destination pixel is the mean of the source pixels it covers.
    """
    h, w = rgba.shape[:2]
    if (nw, nh) == (w, h):
        return rgba
    f = rgba.astype(np.float32)
    al = f[..., 3:4] / 255.0
    prem = np.concatenate([f[..., :3] * al, al], axis=2)
    xs = np.linspace(0.0, w, nw + 1)
    ys = np.linspace(0.0, h, nh + 1)
    # integrate along x then y with linear (tent) weights per destination pixel
    tmp = _resample_axis(prem, xs, w, axis=1)
    out = _resample_axis(tmp, ys, h, axis=0)
    a = np.clip(out[..., 3:4], 0.0, 1.0)
    rgb = np.where(a > 1e-4, out[..., :3] / np.maximum(a, 1e-4), 0.0)
    res = np.zeros((nh, nw, 4), np.uint8)
    res[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    res[..., 3] = np.round(a[..., 0] * 255.0).astype(np.uint8)
    return res


def _weights(edges, n_src):
    """Per destination pixel: (first index, weights) for the linear coverage of each source px."""
    idx = np.arange(n_src)
    out = []
    for k in range(len(edges) - 1):
        lo, hi = edges[k], edges[k + 1]
        wgt = np.clip(np.minimum(idx + 1, hi) - np.maximum(idx, lo), 0.0, None)
        out.append(wgt / max(wgt.sum(), 1e-6))
    return out


def _resample_axis(arr, edges, n_src, axis):
    ws = _weights(edges, n_src)
    n_dst = len(ws)
    shape = list(arr.shape)
    shape[axis] = n_dst
    out = np.zeros(shape, np.float32)
    for k, wgt in enumerate(ws):
        if axis == 0:
            out[k] = (arr * wgt[:, None, None]).sum(0)
        else:
            out[:, k] = (arr * wgt[None, :, None]).sum(1)
    return out


# --- segmentation -------------------------------------------------------------------------
def pool2(mask):
    h, w = mask.shape
    h2, w2 = h // 2, w // 2
    return (mask[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2).any(axis=(1, 3)))


def up2(mask):
    return np.repeat(np.repeat(mask, 2, axis=0), 2, axis=1)


def close_gaps(mask, n):
    """Binary close: dilate n, then erode n (4-neighbourhood)."""
    m = mask.copy()
    for _ in range(n):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    for _ in range(n):
        m = m & np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1)
        m[:, 0] = False
        m[:, -1] = False
        m[0, :] = False
        m[-1, :] = False
    return m


def label(mask):
    """4-connected components of a boolean mask, via run-length row union-find."""
    h, w = mask.shape
    parent = {}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(x, y):
        rx, ry = find(x), find(y)
        if rx != ry:
            parent[ry] = rx

    runs = []  # (row, start, end, label_id)
    prev = []
    nxt_id = 0
    for y in range(h):
        row = mask[y]
        if not row.any():
            prev = []
            continue
        idx = np.flatnonzero(np.diff(np.concatenate(([0], row.view(np.int8), [0]))))
        starts, ends = idx[0::2], idx[1::2]
        cur = []
        j = 0
        for s, e in zip(starts, ends):
            rid = nxt_id
            nxt_id += 1
            parent[rid] = rid
            while j < len(prev) and prev[j][1] <= s:
                j += 1
            k = j
            while k < len(prev) and prev[k][0] < e:
                union(rid, prev[k][2])
                k += 1
            cur.append((int(s), int(e), rid))
            runs.append((y, int(s), int(e), rid))
        prev = cur
    lab = np.zeros(mask.shape, np.int32)
    remap = {}
    for y, s, e, rid in runs:
        r = find(rid)
        if r not in remap:
            remap[r] = len(remap) + 1
        lab[y, s:e] = remap[r]
    return lab


def box_mask(shape, box):
    h, w = shape
    x, y, bw, bh = box
    m = np.zeros(shape, bool)
    m[max(0, y):min(h, y + bh), max(0, x):min(w, x + bw)] = True
    return m


def split_sheet(rgb, a, sheet_name, ov):
    """Return a list of (bbox, full-res mask) items for one sheet."""
    h, w = a.shape
    mask_full = a > SOLID
    # Segment at full resolution: a frond is often joined to its palm by a 1-2 px line, and
    # half-res sampling plus closing either loses the frond or welds two neighbouring items.
    mask = close_gaps(mask_full, CLOSE_PX)
    ov = ov.get(sheet_name, {})
    # Split boxes are cut out of the mask before labelling: two items that touch on the sheet
    # become separate components, and thin parts that the box removes are simply lost.
    for box in ov.get("split", []):
        mask = mask & ~box_mask(mask.shape, box)
    lab = label(mask)
    n = int(lab.max())

    comps = {}
    for i in range(1, n + 1):
        sel = lab == i
        ys, xs = np.nonzero(sel)
        if len(xs) == 0:
            continue
        comps[i] = [ys, xs]

    # drop boxes: whole components that sit inside a drop rectangle
    for box in ov.get("drop", []):
        bm = box_mask(mask.shape, box)
        for i in list(comps):
            ys, xs = comps[i]
            inside = bm[ys, xs]
            if inside.mean() > 0.5:
                del comps[i]

    # merge boxes: every component overlapping the box becomes one item
    for box in ov.get("merge", []):
        bm = box_mask(mask.shape, box)
        group = [i for i, (ys, xs) in comps.items() if bm[ys, xs].any()]
        if len(group) < 2:
            continue
        keep = group[0]
        ys = np.concatenate([comps[i][0] for i in group])
        xs = np.concatenate([comps[i][1] for i in group])
        comps[keep] = [ys, xs]
        for i in group[1:]:
            del comps[i]

    items = []
    used_split = set()
    for i, (ys, xs) in comps.items():
        y0, y1 = int(ys.min()), int(ys.max()) + 1
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        m = np.zeros(mask.shape, bool)
        m[ys, xs] = True
        items.append((m, i))
    del comps

    # trim to full-res alpha, ignore specks, keep items at least MIN_SIDE in both directions
    out = []
    for m, _ in items:
        alpha_m = m & mask_full
        al = np.where(alpha_m, a, 0.0)
        ys, xs = np.nonzero(al > 0.0)
        if len(xs) < MIN_AREA:
            continue
        y0, y1 = int(ys.min()), int(ys.max()) + 1
        x0, x1 = int(xs.min()), int(xs.max()) + 1
        if x1 - x0 < MIN_SIDE or y1 - y0 < MIN_SIDE:
            continue
        out.append([x0, y0, x1, y1, m])
    out.sort(key=lambda b: (b[1] // 48, b[0]))
    return out


# --- labels -------------------------------------------------------------------------------
def slugify(s):
    s = "".join(c if c.isalnum() else "_" for c in s.lower())
    while "__" in s:
        s = s.replace("__", "_")
    return s.strip("_") or "item"


def default_pivot(alpha, kind):
    """Ground contact = centre of the bottom band; hanging vines/roots hang from the top."""
    h, w = alpha.shape
    ys, xs = np.nonzero(alpha > 0.3)
    if len(xs) == 0:
        return [w // 2, h]
    if isinstance(kind, str) and rules.hanging(kind):
        band = ys < ys.min() + max(2, (ys.max() - ys.min()) // 12)
        return [int(round(float(xs[band].mean()))), int(ys.min())]
    band = ys > ys.max() - max(2, (ys.max() - ys.min()) // 12)
    return [int(round(float(xs[band].mean()))), int(ys.max()) + 1]


# --- main ---------------------------------------------------------------------------------
def process_sheet(sheet_path, overrides, labels):
    global KEY
    name = os.path.basename(sheet_path)[:-5]
    short = name[6:] if name.startswith("sheet-") else name
    rgb = decode_webp(sheet_path)
    KEY = detect_key(rgb)
    keyed, a = key_sheet(rgb)
    keyed, a, holes = despill(keyed, a)   # holes are cleared per item later, not before the cut
    boxes = split_sheet(rgb, a, name, overrides)
    rows = []
    outdir = os.path.join(OUT_DIR, name)
    for i, (x0, y0, x1, y1, m) in enumerate(boxes, 1):
        # trimmed image, PAD px of transparency around the pixels that survive the alpha box
        sub_a = a[y0:y1, x0:x1]
        px0 = max(0, x0 - PAD)
        py0 = max(0, y0 - PAD)
        px1 = min(a.shape[1], x1 + PAD)
        py1 = min(a.shape[0], y1 + PAD)
        crop = keyed[py0:py1, px0:px1]
        # only this item's own pixels survive: anything else inside the box is a neighbour
        alpha = np.clip(a[py0:py1, px0:px1], 0.0, 1.0) * m[py0:py1, px0:px1]
        alpha[holes[py0:py1, px0:px1]] = 0.0
        rgba = np.zeros((py1 - py0, px1 - px0, 4), np.uint8)
        rgba[..., :3] = np.clip(crop, 0, 255).astype(np.uint8)
        rgba[..., 3] = np.round(alpha * 255.0).astype(np.uint8)
        # Clearing the screen pinholes can shave the outermost row: trim again so the PNG stays
        # trimmed to its real pixels (the checker requires alpha within 3 px of every border).
        vis = rgba[..., 3] > 0
        if vis.any():
            vy, vx = np.nonzero(vis)
            ty0, ty1 = int(vy.min()), int(vy.max()) + 1
            tx0, tx1 = int(vx.min()), int(vx.max()) + 1
            if (ty0, ty1, tx0, tx1) != (0, rgba.shape[0], 0, rgba.shape[1]):
                rgba = rgba[ty0:ty1, tx0:tx1]
                alpha = alpha[ty0:ty1, tx0:tx1]
                px0 += tx0
                py0 += ty0
                px1 = px0 + (tx1 - tx0)
                py1 = py0 + (ty1 - ty0)
        rgba = rim_fix(rgba)
        # kill any leftover alpha outside the item's own component
        band = np.zeros_like(alpha, bool)
        band[:, :] = alpha > 0
        hh, ww = alpha.shape
        lab_row = {
            "src_rect": [int(px0), int(py0), int(px1 - px0), int(py1 - py0)],
            "sheet": name,
            "px": [int(ww), int(hh)],
        }
        rows.append((rgba, lab_row, alpha))
    # Labels are matched afterwards, once every crop exists: one-to-one by exact sheet+src_rect,
    # IoU >= 0.7 fallback (rules.match_rects). Never by index or centre distance - both slid
    # names onto neighbouring items whenever a split box changed the item count.
    table = rules.load_table()
    families = rules.load_families()
    pick = rules.match_rects(name, [row["src_rect"] for _, row, _ in rows], table)
    manifest_rows = []
    for i, (rgba, row, alpha) in enumerate(rows, 1):
        lab = table[pick[i - 1]] if (i - 1) in pick else None
        item_name = lab[5] if lab else "item"
        kind = lab[6] if lab else "unused"
        height_m = float(lab[7]) if lab else 0.5
        slug = slugify(item_name)
        sid = "%s_%02d_%s" % (short, i, slug)
        rel = "res://assets/nature/sprites2d/%s/%s.png" % (name, sid)
        # Pivot measured from this run's alpha, never from a stored value: a split box or a
        # downscale changes the crop and a stored pivot goes stale (audit: "pivot outside PNG").
        piv = default_pivot(alpha, kind)
        # Web pack budget: perceived size is set by height_m, not by the painted pixels, so tall
        # items keep more resolution (the camera sees them close up as a 2D card). Everything ships
        # at <= 512 px on the longest side, or <= 768 px at height_m >= 8; `scale` records the
        # factor so the game can hold size by height_m.
        hh, ww = rgba.shape[:2]
        maxside = 704 if height_m >= 8.0 else 448
        sc = min(1.0, maxside / float(max(ww, hh)))
        if sc < 1.0:
            nw, nh = max(1, int(round(ww * sc))), max(1, int(round(hh * sc)))
            rgba = resize_area(rgba, nw, nh)
            row["px"] = [nw, nh]
            piv = [int(round(float(piv[0]) * nw / ww)), int(round(float(piv[1]) * nh / hh))]
            sc = nw / float(ww)
        write_png(os.path.join(ROOT, "game", rel[len("res://"):]), rgba)
        manifest_rows.append({
            "id": sid,
            "sheet": name,
            "file": rel,
            "src_rect": row["src_rect"],
            "px": row["px"],
            "pivot": [int(piv[0]), int(piv[1])],
            "scale": round(float(sc), 4),
            "name": item_name,
            "kind": kind,
            "height_m": height_m,
            "blocks": rules.blocks_for(kind, height_m, families),
            "destroyable": rules.destroyable_for(kind, height_m),
        })
    return manifest_rows


def main():
    args = sys.argv[1:]
    only = None
    if "--sheet" in args:
        only = args[args.index("--sheet") + 1]
    overrides = load_json(OVERRIDES, {})
    labels = load_json(LABELS, {})
    sheets = sorted(p for p in os.listdir(SHEET_DIR) if p.startswith("sheet-") and p.endswith(".webp"))
    if only:
        sheets = [p for p in sheets if p[:-5] == only]
        if not sheets:
            sys.exit("no such sheet: %s" % only)
    all_rows = []
    for s in sheets:
        rows = process_sheet(os.path.join(SHEET_DIR, s), overrides, labels)
        print("%-22s %3d sprites" % (s, len(rows)))
        all_rows.extend(rows)
    if only:
        # keep the other sheets' rows so a one-sheet run does not shrink the manifest
        old = load_json(MANIFEST, {"sprites": []}).get("sprites", [])
        kept = [r for r in old if r.get("sheet") != only]
        all_rows = kept + all_rows
    # remove PNGs from earlier runs whose id no longer exists (names change as labels are set)
    keep = {r["file"] for r in all_rows}
    for d in os.listdir(OUT_DIR):
        p = os.path.join(OUT_DIR, d)
        if not os.path.isdir(p):
            continue
        for f in os.listdir(p):
            if f.endswith(".png") and "res://assets/nature/sprites2d/%s/%s" % (d, f) not in keep:
                os.remove(os.path.join(p, f))
                # Godot's import sidecar goes with the PNG, or the editor re-imports a ghost
                side = os.path.join(p, f + ".import")
                if os.path.exists(side):
                    os.remove(side)
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w") as f:
        json.dump({"sprites": all_rows}, f, indent=1)
        f.write("\n")
    print("total %d sprites -> %s" % (len(all_rows), MANIFEST))


if __name__ == "__main__":
    main()
