#!/usr/bin/env python3
"""Play a clip GLB backwards, in place.

Fixes a moonwalk where a library walk/run was authored for the opposite facing (the planted foot slides forward;
`tools/audit_gaits.py --gate` flags it), and turns a forward roll into a back roll. Each time track maps t -> end - t
and its values are reversed. LINEAR and STEP samplers only; CUBICSPLINE is refused so a clip is never mangled.

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
        if any(s.get('interpolation', 'LINEAR') == 'CUBICSPLINE' for s in anim['samplers']):
            sys.exit(f'{path}: CUBICSPLINE tangents not handled')
        inputs = {s['input'] for s in anim['samplers']}
        dur = max(doc['accessors'][i]['max'][0] for i in inputs)
        for i in inputs:  # t -> dur - t, in ascending order again
            ia = doc['accessors'][i]
            bv = doc['bufferViews'][ia['bufferView']]
            o = bin0 + bv.get('byteOffset', 0) + ia.get('byteOffset', 0)
            ts = struct.unpack_from(f'<{ia["count"]}f', blob, o)
            new_ts = [dur - t for t in reversed(ts)]
            struct.pack_into(f'<{ia["count"]}f', blob, o, *new_ts)
            ia['min'], ia['max'] = [min(new_ts)], [max(new_ts)]
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
    # accessor min/max changed: rebuild the JSON chunk (padded to 4 bytes); the binary chunk is unchanged
    js = json.dumps(doc, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    rest = bytes(blob[20 + jlen:])
    out = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(js) + len(rest)) + struct.pack('<I4s', len(js), b'JSON') + js + rest
    open(path, 'wb').write(out)
    print(f'reversed {len(done)} channels in {path}')


if __name__ == '__main__':
    for p in sys.argv[1:]:
        reverse(p)
