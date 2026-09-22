#!/usr/bin/env python3
"""Check exported skin deformation, loop seams, weight limits and bone rests.

The edge limits detect severe tearing, not artistic quality. Inspect renders too.
Edges shorter than 0.01% of model height are excluded by the Blender audit.
"""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('audit', type=Path)
p.add_argument('--baseline', type=Path)
a = p.parse_args()
report = json.loads(a.audit.read_text())
baseline = json.loads(a.baseline.read_text()) if a.baseline else {}
required = {'idle', 'walk', 'run', 'attack_primary', 'attack_heavy', 'hit_react', 'knockdown', 'death', 'alert'}
errors = []
for species, data in report.items():
    height = data['height']
    if set(data['clips']) != required:
        errors.append(f'{species}: incomplete clip contract')
    if data.get('max_influences', 4) > 4 or data.get('weight_sum_error', 0) > 1e-5:
        errors.append(f'{species}: invalid skin weights')
    for name, clip in data['clips'].items():
        if clip['max_edge_ratio'] > 10 or clip['p99_edge_ratio'] > 2.1:
            errors.append(f'{species}/{name}: severe strain max={clip["max_edge_ratio"]:.2f}, p99={clip["p99_edge_ratio"]:.2f}')
        if clip['bone_rest_mismatch'] > 1e-5:
            errors.append(f'{species}/{name}: base/clip rest mismatch')
        if clip['min_z'] < -.015 * height:
            errors.append(f'{species}/{name}: ground penetration')
        if name in {'idle', 'walk', 'run', 'hit_react'} and clip.get('loop_max_vertex_delta', 0) > .002 * height:
            errors.append(f'{species}/{name}: loop/recovery seam')
    if species in baseline:
        old = max(c['p99_edge_ratio'] for c in baseline[species]['clips'].values())
        new = max(c['p99_edge_ratio'] for c in data['clips'].values())
        if new >= old:
            errors.append(f'{species}: worst p99 strain did not improve')
if not report:
    errors.append('Empty report')
if errors:
    raise SystemExit('RIG QA FAIL\n' + '\n'.join(errors))
print(f'RIG QA PASS: {len(report)} creatures, {sum(len(d["clips"]) for d in report.values())} exported clips')
