#!/usr/bin/env bash
# Gate for jaw work: every species named has a Jaw bone in its rig, jaw keys in attack_primary/alert, and the
# game still imports every clip and boots. Usage: tools/jaw/verify_jaws.sh coelophysis compsognathus ...
set -u
cd "$(dirname "$0")/../.."
fail=0
for sp in "$@"; do
  python3 - "$sp" <<'PY' || fail=1
import json, struct, sys
sp = sys.argv[1]
def doc(p):
    b = open(p, 'rb').read(); n = struct.unpack('<I', b[12:16])[0]; return json.loads(b[20:20 + n])
rig = doc(f'game/assets/creatures/{sp}/{sp}.glb')
names = [n.get('name') for n in rig['nodes']]
ok = 'Jaw' in names
for clip in ('attack_primary', 'alert'):
    d = doc(f'game/assets/creatures/{sp}/anim/{clip}.glb')
    nm = [n.get('name') for n in d['nodes']]
    keyed = any(nm[c['target']['node']] == 'Jaw' for a in d.get('animations', []) for c in a['channels'])
    ok = ok and keyed
    print(f'{sp} {clip}: jaw keyed={keyed}')
print(f'{sp}: Jaw bone={"Jaw" in names} -> {"OK" if ok else "FAIL"}')
sys.exit(0 if ok else 1)
PY
done
G=$(tools/find_godot.sh 2>/dev/null || echo /Applications/Godot_mono.app/Contents/MacOS/Godot)
"$G" --headless --path game --import >/dev/null 2>&1
"$G" --headless --path game --script ../tools/verify_rig_imports.gd 2>&1 | grep -q 'RIG IMPORT PASS' || { echo "rig imports FAIL"; fail=1; }
tools/smoke.sh 2>&1 | grep -q 'SMOKE PASS' || { echo "smoke FAIL"; fail=1; }
[ $fail = 0 ] && echo "JAWS PASS" || echo "JAWS FAIL"
exit $fail
