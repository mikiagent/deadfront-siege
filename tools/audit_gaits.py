#!/usr/bin/env python3
"""Gait audit across the creature fleet (tools/docs_wiki/wiki-maintenance.md §preview).

Reads the family rigs' anim/walk.glb and anim/run.glb with a stride-correct
glTF reader and reports, per clip:

- sampler time validity (strictly stepping; the 2026-10-27 "fleet-wide broken
  times" scare was an audit-script bug, not asset damage), and
- stance-foot drift within the stance window (foot z(end) − z(start) around the
  lowest point of the cycle) relative to the rig's rest-space facing.

A correct in-place walk pushes the stance foot backwards in rig space
(negative drift when the rig faces +z), so a clearly positive drift reads as an
authored backwards walk. Also compares run vs walk channel values on a common
normalized timeline: copies surface as IDENTICAL / NEAR-IDENTICAL.

Usage: python3 tools/audit_gaits.py [--gate]

--gate exits 1 when a +z-facing rig's planted foot slides forward (moonwalk, drift > +0.05) or its walk and run
are copies. Calibrated 2026-10-28: flags the Meshy-library bipeds (coelophysis, compsognathus, gallimimus,
utahraptor, velociraptor), passes deinonychus and the quadrupeds. Rigs facing another axis are listed as
unchecked (the drift is measured on the +z axis only).
"""
import struct
import json
import glob

ROOT = None
CT = {5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def read_glb(path):
    blob = open(path, 'rb').read()
    magic, _, _ = struct.unpack_from('<4sII', blob, 0)
    if magic != b'glTF':
        raise ValueError(f'{path}: not a GLB')
    jlen, jtype = struct.unpack_from('<II', blob, 12)
    doc = json.loads(blob[20:20 + jlen])
    off = 20 + jlen
    blen, _ = struct.unpack_from('<II', blob, off)
    binb = blob[off + 8:off + 8 + blen]

    def acc(i):
        a = doc['accessors'][i]
        fmt, size = CT[a['componentType']]
        ncomp = NC[a['type']]
        view = doc['bufferViews'][a['bufferView']]
        base = view.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = view.get('byteStride') or size * ncomp
        return [struct.unpack_from('<' + fmt * ncomp, binb, base + r * stride) for r in range(a['count'])]

    return doc, acc


def rig_state(names):
    return names


def q2m(q, t, s):
    x, y, z, w = q
    return [
        [(1 - 2 * (y * y + z * z)) * s[0], 2 * (x * y - z * w) * s[0], 2 * (x * z + y * w) * s[0], t[0]],
        [2 * (x * y + z * w) * s[1], (1 - 2 * (x * x + z * z)) * s[1], 2 * (y * z - x * w) * s[1], t[1]],
        [2 * (x * z - y * w) * s[2], 2 * (y * z + x * w) * s[2], (1 - 2 * (x * x + y * y)) * s[2], t[2]],
        [0, 0, 0, 1]]


def mul(A, B):
    return [[sum(A[r][k] * B[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def resample(kt, vals, t):
    """Linear sample over a real time array."""
    if t <= kt[0]:
        return list(vals[0])
    if t >= kt[-1]:
        return list(vals[-1])
    for i in range(len(kt) - 1):
        if kt[i] <= t <= kt[i + 1]:
            a, b = vals[i], vals[i + 1]
            f = (t - kt[i]) / (kt[i + 1] - kt[i] or 1e-9)
            return [a[k] + (b[k] - a[k]) * f for k in range(len(a))]
    return list(vals[-1])


def per_clip(doc, acc):
    names = [n.get('name', '') for n in doc['nodes']]
    per, dur = {}, 0.0
    for a in doc.get('animations', []):
        for c in a['channels']:
            s = a['samplers'][c['sampler']]
            kt = [x[0] for x in acc(s['input'])]
            per[(names[c['target']['node']], c['target']['path'])] = (kt, acc(s['output']))
            dur = max(dur, kt[-1] if kt else 0)
    return per, dur


def times_valid(doc, acc):
    broken = total = 0
    for a in doc.get('animations', []):
        for s in a['samplers']:
            total += 1
            i = s.get('input', -1)
            if not 0 <= i < len(doc['accessors']):
                broken += 1
                continue
            a_acc = doc['accessors'][i]
            if a_acc.get('type') != 'SCALAR' or len(a_acc.get('min', [0])) != 1:
                pass
            kt = [x[0] for x in acc(i)]
            if len(kt) > 1 and not all(kt[j] < kt[j + 1] + 1e-6 for j in range(len(kt) - 1)):
                broken += 1
    return total, broken


def foot_clip(doc, per, dur, feet):
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
            tr, ro, sc = list(n.get('translation', [0, 0, 0])), list(n.get('rotation', [0, 0, 0, 1])), list(n.get('scale', [1, 1, 1]))
            for path, (kt, vals) in (tracks.get(i) or {}).items():
                v = resample(kt, vals, t)
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


def stance_drift(pts):
    ys = [p[2] for p in pts]
    zs = [p[1] for p in pts]
    lo, hi = min(ys), max(ys)
    if hi - lo < 1e-4:
        return 0.0
    thr = lo + 0.35 * (hi - lo)
    Imid = ys.index(lo)
    a = b = Imid
    while a - 1 >= 0 and ys[a - 1] <= thr:
        a -= 1
    while b + 1 < len(pts) and ys[b + 1] <= thr:
        b += 1
    if b - a < 3:
        return 0.0
    return zs[b] - zs[a]


def compare(walk, run):
    per_w, dur_w = walk
    per_r, dur_r = run
    common = sorted(set(per_w) & set(per_r))
    if not common:
        return f'no common channels ({len(per_w)} vs {len(per_r)})'
    mx = 0.0
    for key in common:
        kw, vw = per_w[key]
        kr, vh = per_r[key]
        for i in range(49):
            t = i / 48
            aw = resample(kw, vw, t * kw[-1])
            ar = resample(kr, vh, t * kr[-1])
            if len(aw) == 4:
                d = max(min(abs(x - y), abs(x + y)) for x, y in zip(aw, ar))
            else:
                d = max(abs(x - y) for x, y in zip(aw, ar))
            mx = max(mx, d)
    if mx < 1e-5:
        return 'IDENTICAL'
    if mx < 0.01:
        return f'NEAR-IDENTICAL (re-exported copy, maxΔ {mx:.4f})'
    return f'distinct (maxΔ {mx:.4f})'


def facing(rig, names):
    idx = {nm: i for i, nm in enumerate(names)}
    W = [None] * len(rig['nodes'])
    parent = {}
    for i, n in enumerate(rig['nodes']):
        for c in n.get('children', []):
            parent[c] = i

    def rw(i, P):
        n = rig['nodes'][i]
        W[i] = mul(P, q2m(n.get('rotation', [0, 0, 0, 1]), n.get('translation', [0, 0, 0]), n.get('scale', [1, 1, 1])))
        for c in n.get('children', []):
            rw(c, W[i])

    for i in range(len(rig['nodes'])):
        if i not in parent:
            rw(i, [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])

    def world_near(keys):
        hits = [(nm, idx[nm]) for nm in keys if nm in idx]
        return hits[0][1] if hits else None

    head = world_near([n for n in names if 'head' in n.lower() and ('end' in n.lower() or n.lower() in ('head',))])
    tail = world_near([n for n in names if 'tail' in n.lower() and ('end' in n.lower() or 'tail_6' in n.lower())])
    fwd = 'n/a'
    anchors = []
    if head is not None and tail is not None:
        anchors = (head, tail)
    else:
        toeL = world_near([n for n in names if n.lower() in ('toe.l', 'toe_r')])
        hips = world_near([n for n in names if n.lower() in ('hips', 'torso')])
        if toeL is not None and hips is not None:
            anchors = (toeL, hips)
    if anchors:
        a, b = anchors
        dz = W[a][2][3] - W[b][2][3]
        dx = W[a][0][3] - W[b][0][3]
        fwd = '+z' if abs(dz) >= abs(dx) and dz > 0 else ('-z' if abs(dz) >= abs(dx) else ('+x' if dx > 0 else '-x'))
    return fwd


def main():
    import sys
    gate = '--gate' in sys.argv
    fails, unchecked = [], []
    fams = sorted(glob.glob('game/assets/creatures/*/*.glb')) + \
           sorted(glob.glob('game/assets/creatures/*/v1/*.glb')) + \
           sorted(glob.glob('game/assets/characters/*/*.glb'))
    for path in fams:
        sp = path.split('/')[-1].split('.')[0]
        rel = path
        rig, racc = read_glb(rel)
        names = [n.get('name', '') for n in rig['nodes']]
        feet = sorted({n for n in names if 'foot' in n.lower() and 'toe' not in n.lower() and not n.lower().endswith('_end')})
        if not feet and ('Toe.L' in names or 'Toe.R' in names):
            feet = sorted({n for n in names if n.startswith('Toe') and not n.endswith('_end')})
        fwd = facing(rig, names)
        base = rel.rsplit('/', 1)[0] + '/anim/'
        try:
            doc_w, acc_w = read_glb(base + 'walk.glb')
        except (OSError, FileNotFoundError):
            continue
        tw, bw = times_valid(doc_w, acc_w)
        per_w, dur_w = per_clip(doc_w, acc_w)
        try:
            doc_r, acc_r = read_glb(base + 'run.glb')
            tr, br = times_valid(doc_r, acc_r)
            per_r, dur_r = per_clip(doc_r, acc_r)
        except (OSError, FileNotFoundError):
            tr = br = per_r = dur_r = 0
        verdict = 'ok' if (bw + br) == 0 else f'{bw + br} BROKEN samplers'
        drift = foot_clip(doc_w, per_w, dur_w, feet) if feet and dur_w else {}
        wr = ', '.join(f'{nm.split(".")[-1]}: {stance_drift(p):+.3f}' for nm, p in sorted(drift.items()) if len(p) >= 8)
        drift_r = foot_clip(doc_r, per_r, dur_r, feet) if feet and dur_r else {}
        rr = ', '.join(f'{nm.split(".")[-1]}: {stance_drift(p):+.3f}' for nm, p in sorted(drift_r.items()) if len(p) >= 8)
        cmp_ = compare((per_w, dur_w), (per_r, dur_r)) if per_r else '(no run clip)'
        if fwd != '+z':
            unchecked.append(sp)
        else:
            slid = [f'{clip} {nm.split(".")[-1]} {stance_drift(p):+.2f}' for clip, d in (('walk', drift), ('run', drift_r))
                    for nm, p in d.items() if len(p) >= 8 and stance_drift(p) > 0.05]
            if slid or 'IDENTICAL' in cmp_:
                fails.append(f'{rel}: ' + ', '.join(slid + (['walk == run'] if 'IDENTICAL' in cmp_ else [])))
        print(f'{rel:52s} times {tw + tr:4d}/{verdict}')
        print(f'    fwd={fwd:3s} walk [{dur_w:.2f}s]: {wr or "(nothing trackable)"}  |  run [{dur_r:.2f}s]: {rr or "(nothing trackable)"}  |  run-vs-walk: {cmp_}')
    if gate:
        print('\nGATE unchecked (not +z facing):', ', '.join(unchecked) or 'none')
        for f in fails: print('GATE FAIL', f)
        print('GATE', 'FAIL' if fails else 'PASS')
        sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
