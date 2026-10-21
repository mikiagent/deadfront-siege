# Clip gate for appearance pieces: skins the pieces with every survivor clip (linear blend skinning from the
# glTF data, as Godot does) and measures how far any piece vertex sinks into the posed head + chest surface.
#   Blender -b --factory-startup -P clip_penetration.py -- <survivor_dir> <out.json> <name>=<piece.glb> ...
# The surface is the default head (hair/head.glb) and body_chest.glb. Penetration is reported as the increase
# over the bind pose (some hair-edge vertices already touch or tuck into the skin at rest), max over 12 frames
# per clip, for all piece vertices and for those below the ear tops (y < 1.66 m).
import sys, os, json, glob
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb

argv = sys.argv[sys.argv.index("--") + 1:]
SD, OUT = argv[0], argv[1]
pieces = [(a.split("=", 1)[0], a.split("=", 1)[1]) for a in argv[2:]]
EAR_TOP = 1.66
FRAMES = 12


def quat_mat(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def trs(t, r, s):
    m = np.eye(4)
    m[:3, :3] = quat_mat(np.asarray(r, float)) * np.asarray(s, float)[None, :]
    m[:3, 3] = t
    return m


sjs, sbn = glb.read(f"{SD}/survivor.glb")
nodes = sjs["nodes"]
parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
rest = {n["name"]: (n.get("translation", [0, 0, 0]), n.get("rotation", [0, 0, 0, 1]), n.get("scale", [1, 1, 1])) for n in nodes}


def globals_for(local):
    """local: name -> (t, r, s). Returns name -> 4x4 global matrix (glTF scene space)."""
    cache = {}

    def g(i):
        if i in cache:
            return cache[i]
        n = nodes[i]["name"]
        m = trs(*local.get(n, rest[n]))
        if i in parent:
            m = g(parent[i]) @ m
        cache[i] = m
        return m
    return {nodes[i]["name"]: g(i) for i in range(len(nodes))}


def load_piece(path):
    js, bn = glb.read(path)
    A = glb.mesh_arrays(js, bn)
    names = [js["nodes"][j]["name"] for j in js["skins"][0]["joints"]]
    ibm = glb.accessor(js, bn, js["skins"][0]["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    tris = A["indices"].reshape(-1, 3)
    used = np.unique(tris)
    return {"pos": A["POSITION"].astype(float), "J": A["JOINTS_0"].astype(int), "W": A["WEIGHTS_0"].astype(float),
            "tris": tris, "used": used, "names": names, "ibm": ibm}


def skin(p, G):
    mats = np.stack([G[n] @ p["ibm"][k] for k, n in enumerate(p["names"])])        # (joints, 4, 4)
    v = np.concatenate([p["pos"], np.ones((len(p["pos"]), 1))], 1)
    out = np.zeros((len(v), 3))
    for k in range(4):
        out += p["W"][:, k:k + 1] * np.einsum("nij,nj->ni", mats[p["J"][:, k]], v)[:, :3]
    return out


def clip_tracks(path):
    js, bn = glb.read(path)
    an = js["animations"][0]
    tracks = []
    for ch in an["channels"]:
        smp = an["samplers"][ch["sampler"]]
        tt = glb.accessor(js, bn, smp["input"]).astype(float)
        vv = glb.accessor(js, bn, smp["output"]).astype(float)
        if np.allclose(vv, vv[0]):
            continue  # Godot drops immutable tracks on import: the bone keeps the survivor's rest
        tracks.append((js["nodes"][ch["target"]["node"]]["name"], ch["target"]["path"], tt, vv, smp.get("interpolation", "LINEAR")))
    dur = max(t[2][-1] for t in tracks) if tracks else 0.0
    return tracks, dur


def pose(tracks, t):
    local = {n: [list(v) for v in rest[n]] for n in rest}
    for name, path, tt, vv, interp in tracks:
        if name not in local:
            continue
        i = int(np.clip(np.searchsorted(tt, t) - 1, 0, len(tt) - 1))
        j = min(i + 1, len(tt) - 1)
        a = 0.0 if interp == "STEP" or j == i else float(np.clip((t - tt[i]) / (tt[j] - tt[i]), 0, 1))
        v = vv[i] * (1 - a) + vv[j] * a
        if path == "rotation":
            if np.dot(vv[i], vv[j]) < 0:
                v = vv[i] * (1 - a) - vv[j] * a
            v = v / np.linalg.norm(v)
        local[name][{"translation": 0, "rotation": 1, "scale": 2}[path]] = list(v)
    return globals_for({k: tuple(v) for k, v in local.items()})


head = load_piece(f"{SD}/hair/head.glb")
chest = load_piece(f"{SD}/body/body_chest.glb")
probes = {n: load_piece(p) for n, p in pieces}


def signed(target_pos, target_tris, pts):
    bvh = BVHTree.FromPolygons([tuple(v) for v in target_pos], [tuple(map(int, t)) for t in target_tris])
    d = np.zeros(len(pts))
    for k, p in enumerate(pts):
        loc, nrm, _, dist = bvh.find_nearest(Vector(p))
        d[k] = (Vector(p) - loc).dot(nrm)
    return d


T_all = np.concatenate([head["tris"], chest["tris"] + len(head["pos"])])
bindG = globals_for({})
bind_target = np.concatenate([skin(head, bindG), skin(chest, bindG)])
drift = float(np.abs(skin(head, bindG)[head["used"]] - head["pos"][head["used"]]).max())
assert drift < 1e-4, f"survivor rest pose is not the pieces' bind pose ({drift} m)"
base = {}
for n, p in probes.items():
    p["vs"] = np.unique(p["tris"])
    p["low"] = p["pos"][p["vs"], 1] < EAR_TOP
    base[n] = signed(bind_target, T_all, skin(p, bindG)[p["vs"]])
report = {"frames_per_clip": FRAMES, "ear_top_y": EAR_TOP, "bind_drift_m": drift, "clips": {}}
for path in sorted(glob.glob(f"{SD}/anim/*.glb")):
    clip = os.path.basename(path)[:-4]
    tracks, dur = clip_tracks(path)
    row = {}
    for f in range(FRAMES):
        G = pose(tracks, dur * f / max(FRAMES - 1, 1))
        target = np.concatenate([skin(head, G), skin(chest, G)])
        for n, p in probes.items():
            d = signed(target, T_all, skin(p, G)[p["vs"]])
            inc = np.maximum(0, -d) - np.maximum(0, -base[n])
            r = row.setdefault(n, {"max_mm": 0.0, "below_ears_mm": 0.0})
            r["max_mm"] = max(r["max_mm"], round(float(inc.max()) * 1000, 2))
            r["below_ears_mm"] = max(r["below_ears_mm"], round(float(inc[p["low"]].max(initial=0)) * 1000, 2))
    report["clips"][clip] = row
    print("CLIP", clip, json.dumps(row))
report["worst"] = {n: max(r[n]["max_mm"] for r in report["clips"].values()) for n in probes}
json.dump(report, open(OUT, "w"), indent=1)
print("WORST", json.dumps(report["worst"]))
