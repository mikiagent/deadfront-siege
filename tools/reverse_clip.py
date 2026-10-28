#!/usr/bin/env python3
"""Play a clip GLB backwards, in place: every animation output is reversed against unchanged, evenly spaced key times.

Fixes a moonwalk where a library walk/run was authored for the opposite facing (the planted foot slides forward;
`tools/audit_gaits.py --gate` flags it). Only LINEAR samplers on one shared, evenly spaced time track are handled;
anything else is refused, so a clip is never silently mangled.

  python3 tools/reverse_clip.py <clip.glb> [<clip.glb> ...]
"""
import json, struct, sys


def reverse(path):
    blob = bytearray(open(path, 'rb').read())
    jlen = struct.unpack_from('<I', blob, 12)[0]
    doc = json.loads(blob[20:20 + jlen])
    bin0 = 20 + jlen + 8
    size = {5126: 4, 5123: 2, 5121: 1, 5122: 2}
    comps = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
    done = set()
    for anim in doc.get('animations', []):
        inputs = {s['input'] for s in anim['samplers']}
        if len(inputs) != 1 or any(s.get('interpolation', 'LINEAR') != 'LINEAR' for s in anim['samplers']):
            sys.exit(f'{path}: needs LINEAR samplers on one time track')
        ia = doc['accessors'][inputs.pop()]
        bv = doc['bufferViews'][ia['bufferView']]
        o = bin0 + bv.get('byteOffset', 0) + ia.get('byteOffset', 0)
        ts = struct.unpack_from(f'<{ia["count"]}f', blob, o)
        steps = [b - a for a, b in zip(ts, ts[1:])]
        if steps and max(steps) - min(steps) > 1e-4:
            sys.exit(f'{path}: key times are not evenly spaced')
        for s in anim['samplers']:
            if s['output'] in done: continue
            done.add(s['output'])
            acc = doc['accessors'][s['output']]
            bv = doc['bufferViews'][acc['bufferView']]
            el = size[acc['componentType']] * comps[acc['type']]
            if bv.get('byteStride', el) != el:
                sys.exit(f'{path}: strided output not handled')
            o = bin0 + bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
            items = [bytes(blob[o + i * el:o + (i + 1) * el]) for i in range(acc['count'])]
            blob[o:o + el * len(items)] = b''.join(reversed(items))
    open(path, 'wb').write(blob)
    print(f'reversed {len(done)} channels in {path}')


if __name__ == '__main__':
    for p in sys.argv[1:]:
        reverse(p)
