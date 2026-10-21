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

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SHEET_DIR = os.path.join(ROOT, "docs/reference/2d-assets")
OUT_DIR = os.path.join(ROOT, "game/assets/nature/sprites2d")
MANIFEST = os.path.join(ROOT, "game/data/world/sprites2d.json")
OVERRIDES = os.path.join(ROOT, "tools/sprites2d/overrides.json")
LABELS = os.path.join(ROOT, "tools/sprites2d/labels.json")
TMP = "/tmp/sprites2d"

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


D_SPILL = 95.0      # pixels this close to the key are spill, not paint (foliage sits 95+ away)


def _dilate(mask, n=1):
    m = mask.copy()
    for _ in range(n):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    return m


def despill(rgb, a):
    """Give every boundary pixel the colour of the paint just inside it.

    Un-mixing a pixel that is mostly screen amplifies noise and any remainder of the key leaves a
    green (or magenta) rim that the game then draws. The alpha already says how much of the pixel
    is visible, so its colour may just take the colour of the nearest real paint: same hue, no
    fringe. Boundary = part-transparent pixels and a 2 px ring just inside the silhouette (the
    painter left a green-tinted antialias row that the distance key reads as opaque). Pixels with
    no real paint nearby (thin fronds, grass blades) keep the un-mixed colour, pushed away from
    the key, and every boundary pixel's green excess is clamped to the item's own.
    """
    solid = a > 0.98
    d = np.sqrt(((rgb - KEY) ** 2).sum(-1))
    clear = a <= 0.01
    # A 3 px rim next to the background is where the painter's brush picked up the screen; it
    # reads as opaque green-yellow paint, so it needs the same treatment as a soft edge.
    # ... and any pixel that is close to the key colour is screen-mixed too, however opaque the
    # distance key made it (a brown frond strand blended with the screen stays green).
    near_key = d < D_SPILL
    boundary = (a > 0.01) & (_dilate(clear, 3) | ~solid | near_key)
    paint = solid & ~near_key & ~_dilate(clear, 3)   # opaque, clearly not screen green, interior
    if paint.sum() < 50:
        return rgb
    # grow the real paint outward, one ring per pass, filling only boundary pixels. The green
    # excess travels with the colour, so each rim pixel is capped at the excess of the paint
    # nearest to it (a sand/shell interior is far below max(R,B); its rim must be too).
    known = paint.copy()
    fill = rgb.copy()
    ge = np.zeros(a.shape, np.float32)
    ge[paint] = (rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2]))[paint]
    for _ in range(6):
        if (known | ~boundary).all():
            break
        acc = np.zeros_like(fill)
        gacc = np.zeros(a.shape, np.float32)
        cnt = np.zeros(a.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            v = np.roll(np.roll(fill, dy, 0), dx, 1)
            gv = np.roll(np.roll(ge, dy, 0), dx, 1)
            acc += v * k[..., None]
            gacc += gv * k
            cnt += k
        grow = boundary & ~known & (cnt > 0)
        if not grow.any():
            break
        n = np.maximum(cnt, 1)
        fill = np.where(grow[..., None], acc / n[..., None], fill)
        ge = np.where(grow, gacc / n, ge)
        known = known | grow
    reached = boundary & known
    rgb = np.where(reached[..., None], fill, rgb)
    # Boundary pixels with no paint reached: they are a green-screen mix on a thin frond tip or
    # a grass blade. Pull them away from the key by darkening the red/blue (not by raising green,
    # which would make them greener) and clamp their green to max(R,B): no rim colour at all.
    g = rgb[..., 1]
    rb = np.maximum(rgb[..., 0], rgb[..., 2])
    rgb[..., 1] = np.where((a > 0.0) & ~known & (g > rb + 2.0), rb + 2.0, g)
    # Rim cap: a rim pixel never keeps more green excess than the paint it grew from (the
    # average of the item, minus a margin, if no paint reached it).
    inside = paint if paint.sum() > 200 else (a > 0.0)
    fallback = float((g - rb)[inside].mean()) - 10.0
    fallback = min(max(fallback, -30.0), 60.0)
    cap = np.where(known, np.minimum(np.minimum(ge, 60.0) - 6.0, fallback), fallback)
    edge = (a > 0.0) & (a < 0.78)
    g = rgb[..., 1]
    rgb[..., 1] = np.where(edge & (g > rb + cap), rb + cap, g)
    # Belt and braces: no visible pixel may sit within 90 RGB units of the screen colour. Slight
    # desaturation of the green channel is invisible on paint this close to the key anyway.
    d = np.sqrt(((rgb - KEY) ** 2).sum(-1))
    stuck = (a > 0.0) & (d < 92.0)
    g = rgb[..., 1]
    rgb[..., 1] = np.where(stuck & (g > rb - 4.0), rb - 4.0, g)
    return rgb


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


def lookup_label(labels, sheet, sid, bbox):
    """labels.json: {"sheets": {sheet: [ {id, src_rect, name, kind, ...} ]}}"""
    rows = labels.get("sheets", {}).get(sheet, [])
    for r in rows:
        if r.get("id") == sid:
            return r
    cx, cy = bbox[0] + bbox[2] / 2.0, bbox[1] + bbox[3] / 2.0
    best, best_d = None, 1e9
    for r in rows:
        rc = r.get("src_rect")
        if not rc:
            continue
        d = abs(rc[0] + rc[2] / 2.0 - cx) + abs(rc[1] + rc[3] / 2.0 - cy)
        if d < best_d:
            best, best_d = r, d
    if best is not None and best_d < 60:
        return best
    return None


def default_pivot(alpha, kind):
    """Ground contact = centre of the bottom band; hanging vines/roots hang from the top."""
    h, w = alpha.shape
    ys, xs = np.nonzero(alpha > 0.3)
    if len(xs) == 0:
        return [w // 2, h]
    hanging = isinstance(kind, str) and (kind.startswith("prop:vine") or kind.startswith("prop:root")
                                         or kind.startswith("prop:waterfall"))
    if hanging:
        band = ys < ys.min() + max(2, (ys.max() - ys.min()) // 12)
        return [int(round(float(xs[band].mean()))), int(ys.min())]
    band = ys > ys.max() - max(2, (ys.max() - ys.min()) // 12)
    return [int(round(float(xs[band].mean()))), int(ys.max()) + 1]


# --- main ---------------------------------------------------------------------------------
def process_sheet(sheet_path, overrides, labels):
    name = os.path.basename(sheet_path)[:-5]
    short = name[6:] if name.startswith("sheet-") else name
    rgb = decode_webp(sheet_path)
    keyed, a = key_sheet(rgb)
    keyed = despill(keyed, a)
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
        rgba = np.zeros((py1 - py0, px1 - px0, 4), np.uint8)
        rgba[..., :3] = np.clip(crop, 0, 255).astype(np.uint8)
        rgba[..., 3] = np.round(alpha * 255.0).astype(np.uint8)
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
    # naming needs the ids of the previous run, so resolve labels after all crops exist
    manifest_rows = []
    for i, (rgba, row, alpha) in enumerate(rows, 1):
        lab = lookup_label(labels, name, None, row["src_rect"])
        slug = slugify(lab.get("name", "item")) if lab and lab.get("name") else "item"
        sid = "%s_%02d_%s" % (short, i, slug)
        rel = "res://assets/nature/sprites2d/%s/%s.png" % (name, sid)
        write_png(os.path.join(ROOT, "game", rel[len("res://"):]), rgba)
        kind = lab.get("kind", "unused") if lab else "unused"
        piv = lab.get("pivot") if lab and isinstance(lab.get("pivot"), list) else default_pivot(alpha, kind)
        manifest_rows.append({
            "id": sid,
            "sheet": name,
            "file": rel,
            "src_rect": row["src_rect"],
            "px": row["px"],
            "pivot": [int(piv[0]), int(piv[1])],
            "name": lab.get("name", slug.replace("_", " ").title()) if lab else "item",
            "kind": kind,
            "height_m": (lab.get("height_m", 0.5) if lab else 0.5),
            "blocks": bool(lab.get("blocks", False)) if lab else False,
            "destroyable": bool(lab.get("destroyable", True)) if lab else True,
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
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w") as f:
        json.dump({"sprites": all_rows}, f, indent=1)
        f.write("\n")
    print("total %d sprites -> %s" % (len(all_rows), MANIFEST))


if __name__ == "__main__":
    main()
