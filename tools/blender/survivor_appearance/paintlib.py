# Shared helpers for projection-baked survivor paint: atlas IO through Blender, a UV rasteriser that gives every
# texel its triangle and barycentrics, 3D value noise, mesh-field smoothing and seam dilation.
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def load_atlas(path):
    im = bpy.data.images.load(path, check_existing=False)
    a = np.array(im.pixels[:], np.float32).reshape(im.size[1], im.size[0], 4)[::-1].copy()
    bpy.data.images.remove(im)
    return a


def save_atlas(a, path, quality=92, alpha=False):
    h, w = a.shape[:2]
    im = bpy.data.images.new("out", w, h, alpha=alpha)
    im.pixels.foreach_set(np.clip(a[::-1], 0, 1).astype(np.float32).ravel())
    im.filepath_raw = path
    im.file_format = "JPEG" if path.endswith(".jpg") else "PNG"
    try:
        im.save(filepath=path, quality=quality)
    except TypeError:
        im.save()
    bpy.data.images.remove(im)


def raster(uv, tris, W, H):
    """Texels whose centre lies in a triangle (glTF UVs: v=0 is the top row)."""
    rows, cols, tid, bary = [], [], [], []
    px = np.stack([uv[:, 0] * W, uv[:, 1] * H], 1)
    for t, (a, b, c) in enumerate(tris):
        A, B, C = px[a], px[b], px[c]
        x0, x1 = int(np.floor(min(A[0], B[0], C[0]))), int(np.ceil(max(A[0], B[0], C[0])))
        y0, y1 = int(np.floor(min(A[1], B[1], C[1]))), int(np.ceil(max(A[1], B[1], C[1])))
        xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1 + 1, W)), np.arange(max(y0, 0), min(y1 + 1, H)))
        p = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], 1)
        v0, v1 = B - A, C - A
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        d = p - A
        l1 = (d[:, 0] * v1[1] - v1[0] * d[:, 1]) / den
        l2 = (v0[0] * d[:, 1] - d[:, 0] * v0[1]) / den
        l0 = 1 - l1 - l2
        m = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if m.any():
            rows.append(ys.ravel()[m]); cols.append(xs.ravel()[m])
            tid.append(np.full(m.sum(), t)); bary.append(np.stack([l0[m], l1[m], l2[m]], 1))
    return {"row": np.concatenate(rows), "col": np.concatenate(cols), "tri": np.concatenate(tid),
            "bary": np.concatenate(bary)}


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF).astype(np.float64) / 65535.0


def vnoise(p, freq, seed):
    """Smooth 3D value noise in [0, 1] (freq in cycles per metre)."""
    q = np.asarray(p, np.float64) * freq
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def smooth_field(v, wtris, iters):
    """Average each welded vertex with its neighbours `iters` times (a soft edge around a 0/1 mask)."""
    e = np.concatenate([wtris[:, [0, 1]], wtris[:, [1, 2]], wtris[:, [2, 0]]])
    e = np.unique(np.sort(e, 1), axis=0)
    v = v.astype(np.float64).copy()
    deg = np.bincount(e.ravel(), minlength=len(v)).astype(np.float64)
    for _ in range(iters):
        s = np.zeros(len(v))
        np.add.at(s, e[:, 0], v[e[:, 1]])
        np.add.at(s, e[:, 1], v[e[:, 0]])
        v = np.where(deg > 0, 0.5 * v + 0.5 * s / np.maximum(deg, 1), v)
    return v


def smoothstep(a, b, x):
    t = np.clip((np.asarray(x, np.float64) - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def dilate_into(img, changed, covered, n):
    """Grow `changed` texels into texels no triangle covers (n px), so mip/bilinear sampling at UV island
    edges never pulls in the old colour."""
    h, w = changed.shape
    for _ in range(n):
        acc = np.zeros((h, w, 3)); cnt = np.zeros((h, w))
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            src = np.roll(np.roll(changed, dy, 0), dx, 1)
            col = np.roll(np.roll(img[..., :3], dy, 0), dx, 1)
            acc += col * src[..., None]; cnt += src
        grow = (cnt > 0) & ~changed & ~covered
        img[grow, :3] = acc[grow] / cnt[grow][:, None]
        changed |= grow


def weld(pos, nrm, tris):
    import glb
    wid = glb.weld_ids(pos)
    nw = wid.max() + 1
    wpos = np.zeros((nw, 3)); np.add.at(wpos, wid, pos); wpos /= np.bincount(wid)[:, None]
    wn = np.zeros((nw, 3)); np.add.at(wn, wid, nrm); wn /= np.linalg.norm(wn, axis=1, keepdims=True) + 1e-12
    return wid, wpos, wn, wid[tris]


def scalp_field(H, R, iters=6):
    """0..1 per welded head vertex: 1 where the hair shell covers the head (a ray along the vertex normal hits
    the hair within 5 cm), smoothed over the mesh so the hairline is soft. Returns wid, wpos, wn, field, wtris."""
    tris = H["indices"].reshape(-1, 3)
    wid, wpos, wn, wtris = weld(H["POSITION"], H["NORMAL"], tris)
    rt = R["indices"].reshape(-1, 3)
    bvh = BVHTree.FromPolygons([tuple(map(float, p)) for p in R["POSITION"]], [tuple(map(int, t)) for t in rt])
    cover = np.zeros(len(wpos))
    for w in np.unique(wtris):
        hit = bvh.ray_cast(Vector(wpos[w] + wn[w] * 5e-4), Vector(wn[w]), 0.05)
        cover[w] = 1.0 if hit[0] is not None else 0.0
    return wid, wpos, wn, smooth_field(cover, wtris, iters), wtris
