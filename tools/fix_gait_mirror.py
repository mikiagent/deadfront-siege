#!/usr/bin/env python3
"""Design ground for the five-species backwards-gait repair (coelophysis,
compsognathus, gallimimus, utahraptor, velociraptor).

The fleet audit (tools/audit_gaits.py) shows these species' walk/run clips
sweeping the stance foot FORWARD in world space (+0.30..+0.53) while correct
in-place gaits sweep it BACKWARD (deinonychus control: −0.22..−0.24) — both
gaits read backwards in game.

This script reproduces the audit's forward-kinematic measurement with
configurable track overrides, so candidate channel transforms can be scored
against the control WITHOUT touching any asset bytes:

  python3 tools/fix_gait_mirror.py --analyze      # ablation + candidate matrix
  python3 tools/fix_gait_mirror.py --apply <species,...> --bak-dir <dir>
                                                  # (not yet: after analysis)

Everything imports from audit_gaits so the footing measurement is identical.
"""
import argparse
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from audit_gaits import read_glb, per_clip, resample, q2m, mul

ROOT = Path(__file__).resolve().parents[1]
CREATURES = ROOT / 'game/assets/creatures'
BAD = ['coelophysis', 'compsognathus', 'gallimimus', 'utahraptor', 'velociraptor']
CONTROL = ['deinonychus']
FEET_BONES = ('BackFoot.L', 'BackFoot.R')


def load(path):
    doc, acc = read_glb(str(path))
    per, dur = per_clip(doc, acc)
    return doc, acc, per, dur


def mul_c(A, B):
    return mul(A, B)


def quat_mirror_z(q):
    """Quaternion of S R S with S = diag(1,1,-1) (front-back mirror)."""
    w, x, y, z = q
    return (w, -x, -y, z)


def quat_mirror_x(q):
    """Quaternion of S R S with S = diag(-1,1,1) (left-right mirror)."""
    w, x, y, z = q
    return (w, x, -y, -z)


def build_sampler(track, transform):
    """Return a (kt, vals) sampler with the transform applied.

    transform is one of:
      ('mirror_tz', rest_z)  translation z -> 2*rest_z - z
      ('mirror_rot_z', None) rotation z-plane mirror
      ('mirror_rot_x', None) rotation x-plane mirror
    """
    kind, arg = transform
    kt, vals = track
    out = []
    for v in vals:
        if kind == 'mirror_tz':
            out.append((v[0], v[1], 2 * arg - v[2]))
        elif kind == 'mirror_rot_z':
            out.append(quat_mirror_z(v))
        elif kind == 'mirror_rot_x':
            out.append(quat_mirror_x(v))
        else:
            raise ValueError(kind)
    return kt, out


def foot_series(doc, per, dur, feet, override=None):
    """Same forward kinematics as audit_gaits.foot_clip, with track override.

    override: dict {(bone_name, path): sampler or None}; None unkeys the
    channel (falls back to the node's rest pose value).
    """
    idx = {n.get('name', ''): i for i, n in enumerate(doc['nodes'])}
    tracks = {}
    for (nm, path), keys in per.items():
        j = idx.get(nm)
        if j is not None:
            tracks.setdefault(j, {})[path] = keys
    parent = {}
    for i, n in enumerate(doc['nodes']):
        for c in n.get('children', []):
            parent[c] = i
    roots = [i for i in range(len(doc['nodes'])) if i not in parent]
    series = {f: [] for f in feet}
    N = 64
    for s_ in range(N + 1):
        t = dur * s_ / N
        Wc = {}

        def rec(i, P):
            n = doc['nodes'][i]
            nm = n.get('name', '')
            tr, ro, sc = list(n.get('translation', [0, 0, 0])), list(n.get('rotation', [0, 0, 0, 1])), list(n.get('scale', [1, 1, 1]))
            for path, keys in (tracks.get(i) or {}).items():
                vals_or_none = None
                if override is not None and (nm, path) in override:
                    vals_or_none = override[(nm, path)]
                if vals_or_none is None:
                    kt, vals = keys
                    v = resample(kt, vals, t)
                elif vals_or_none == 'REST' or vals_or_none is None:
                    v = None
                else:
                    kt, vals = vals_or_none
                    v = resample(kt, vals, t)
                if v is None:
                    continue
                if path == 'translation':
                    tr = list(v)
                elif path == 'rotation':
                    ro = list(v)
                else:
                    sc = list(v)
            Wc[i] = mul(P, q2m(ro, tr, sc))
            for c in n.get('children', []):
                rec(c, Wc[i])

        for r in roots:
            rec(r, [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])
        for f in feet:
            j = idx.get(f)
            if j is not None and j in Wc:
                W = Wc[j]
                series[f].append((t, W[2][3], W[1][3]))
    return series


def stance_drift_nt(pts):
    """Concrete port of audit_gaits.stance_drift for (t,z,y) triples."""
    ys = [p[2] for p in pts]
    zs = [p[1] for p in pts]
    lo, hi = min(ys), max(ys)
    if hi - lo < 1e-4:
        return 0.0
    thr = lo + 0.35 * (hi - lo)
    I = ys.index(lo)
    a = b = I
    while a - 1 >= 0 and ys[a - 1] <= thr:
        a -= 1
    while b + 1 < len(pts) and ys[b + 1] <= thr:
        b += 1
    if b - a < 3:
        return 0.0
    return zs[b] - zs[a]


def min_ground_y(series):
    ys = [p[2] for pts in series.values() for p in pts]
    return min(ys)


def loop_delta(series):
    """max abs difference of each foot's (z, y) between first and last sample."""
    out = 0.0
    for pts in series.values():
        (t0, z0, y0), (tn, zn, yn) = pts[0], pts[-1]
        out = max(out, abs(z0 - zn), abs(y0 - yn))
    return out


def override_ref(doc, per, dur, groups):
    """Build an override dict that mirrors the named track groups about rest.

    groups: ('tz_feet', | ('rot_feet',) | ('rot_legs',) | ('tz_moving',) ...)
    'tz_moving' mirrors every translation track that moves.
    """
    idx = {n.get('name', ''): i for i, n in enumerate(doc['nodes'])}
    over = {}
    for (nm, path), (kt, vals) in per.items():
        i = idx.get(nm)
        if i is None:
            continue
        rest = doc['nodes'][i].get('translation', [0, 0, 0])
        isfoot = nm.endswith('.L') or nm.endswith('.R')
        if path == 'translation':
            travel = max(v[2] for v in vals) - min(v[2] for v in vals)
            if 'tz_comp' in groups:
                if travel < 1e-3:
                    continue
                over[(nm, path)] = build_sampler((kt, vals), ('mirror_tz', rest[2]))
            elif 'tz_all' in groups:
                over[(nm, path)] = build_sampler((kt, vals), ('mirror_tz', rest[2]))
        elif path == 'rotation':
            amp = max(max(v[k] for v in vals) for k in range(4)) - min(min(v[k] for v in vals) for k in range(4))
            if amp < 1e-4:
                continue
            if 'rot_comp' in groups:
                if isfoot or any(part in nm.lower() for part in ('leg', 'foot', 'shin', 'toe', 'claw', 'leg.l', 'leg.r')):
                    over[(nm, path)] = build_sampler((kt, vals), ('mirror_rot_z', None))
            elif 'rot_all' in groups:
                over[(nm, path)] = build_sampler((kt, vals), ('mirror_rot_z', None))
    return over


def analyze():
    specs = [(sp, c) for sp in BAD + CONTROL for c in ('walk', 'run')]
    print(f"{'species/clip':24} {'mode':12} {'driftL':>8} {'driftR':>8} {'minY':>7} {'loopΔ':>7}")
    cache = {}
    for sp, clip in specs:
        path = CREATURES / sp / 'anim' / f'{clip}.glb'
        doc, acc, per, dur = load(path)
        cache[(sp, clip)] = (doc, per, dur)
        modes = [
            ('as-is', None),
            ('unkey_tz', {k: 'REST' for k in per if k[1] == 'translation'}),
            ('unkey_rot', {k: 'REST' for k in per if k[1] == 'rotation'}),
            ('mir_tz_all', override_ref(doc, per, dur, ('tz_all',))),
            ('mir_rot_all', override_ref(doc, per, dur, ('rot_all',))),
            ('mir_both', override_ref(doc, per, dur, ('tz_all', 'rot_all'))),
        ]
        for name, over in modes:
            series = foot_series(doc, per, dur, FEET_BONES, over)
            dL, dR = [stance_drift_nt(series[f]) for f in FEET_BONES]
            print(f"{sp + '/' + clip:24} {name:12} {dL:+8.3f} {dR:+8.3f} {min_ground_y(series):7.3f} {loop_delta(series):7.4f}")
        print()


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--analyze', action='store_true')
    args = ap.parse_args()
    if args.analyze:
        analyze()
    else:
        ap.print_help()
