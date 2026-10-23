#!/bin/zsh
# Each out clip must match its input clip's skin/joint/node structure and carry no mesh/image; walk/run equal input.
setopt nullglob; cd "$(dirname "$0")"; rc=0
for s in protoceratops megaloceros; do
  for c in walk run; do cmp -s out/$s/anim/$c.glb input/$s/anim/$c.glb || { echo "FAIL $s $c.glb must equal the input"; rc=1; }; done
  for f in out/$s/anim/*.glb; do c=${f:t}; [[ -f input/$s/anim/$c ]] || continue
  python3 -I - "$f" "input/$s/anim/$c" <<'PY' || rc=1
import json,struct,sys
def j(p):
    b=open(p,'rb').read(); l=struct.unpack('<I',b[12:16])[0]; return json.loads(b[20:20+l])
o=j(sys.argv[1]); r=j(sys.argv[2]); bad=[]
if o.get('meshes') or o.get('images') or o.get('materials'): bad.append('has mesh/images/materials')
if len(o.get('skins',[]))!=len(r.get('skins',[])): bad.append('skins %d != input %d'%(len(o.get('skins',[])),len(r.get('skins',[]))))
elif o.get('skins') and len(o['skins'][0]['joints'])!=len(r['skins'][0]['joints']): bad.append('joint count differs')
if sorted(n.get('name','') for n in o['nodes'])!=sorted(n.get('name','') for n in r['nodes']): bad.append('node names differ from input')
if len(o.get('animations',[]))!=1: bad.append('animations != 1')
print(('FAIL ' if bad else 'PASS ')+sys.argv[1]+(' '+'; '.join(bad) if bad else '')); sys.exit(1 if bad else 0)
PY
  done
  for c in sleep feed; do [[ -f out/$s/anim/$c.glb ]] && python3 -I -c "
import json,struct,sys
b=open('out/$s/anim/$c.glb','rb').read(); l=struct.unpack('<I',b[12:16])[0]; d=json.loads(b[20:20+l])
ok=len(d.get('skins',[]))==1 and not d.get('meshes') and len(d.get('animations',[]))==1
print(('PASS ' if ok else 'FAIL ')+'out/$s/anim/$c.glb skin+no-mesh'); sys.exit(0 if ok else 1)" || rc=1; done
done
./verify.sh >/dev/null || { echo "FAIL verify.sh"; rc=1; }
exit $rc
