# P2 hair split. Headless:
#   Blender -b --factory-startup -P tools/blender/survivor_appearance/split_hair.py -- <body_helmet.glb> <out_dir>
# Input is the pristine v2 head region (body/body_helmet.glb as shipped; build.sh extracts it from git).
# The baked hair is its own connected surface (welded by position): every component except the one that holds
# the neck seam is hair. Writes, next to the survivor's other parts:
#   head.glb          - the head without the hair shell (scalp keeps its original paint)
#   hair_current.glb  - the hair shell (today's hair)
# Both keep the template's FULL vertex arrays byte for byte and only split the triangle list, so the default
# look (head + hair_current) is the same triangles, normals, UVs, weights and mesh AABB as body_helmet.glb.
# Textures are not copied: the images point at the survivor's own maps (byte-identical to the body regions').
import sys, os, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)
js, bn = glb.read(src)
A = glb.mesh_arrays(js, bn)
tris = A["indices"].reshape(-1, 3)
wid = glb.weld_ids(A["POSITION"])
comp = glb.tri_components(wid[tris])
low = int(np.argmin(A["POSITION"][:, 1]))           # glTF is Y-up: the neck seam holds the lowest vertex
head_comp = comp[np.nonzero((tris == low).any(1))[0][0]]
is_head = comp == head_comp
labels, counts = np.unique(comp, return_counts=True)

SURV = "../survivor_%s_82d5db79-577f-4f8f-b6bf-930a520b5272.%s"
IMAGES = [{"uri": SURV % ("NormalGL", "png"), "name": "NormalGL"},
          {"uri": SURV % ("Color", "jpg"), "name": "Color"},
          {"uri": SURV % ("ORM", "jpg"), "name": "ORM"}]
assert [i["name"].split("_")[0] for i in js["images"]] == ["NormalGL", "Color", "ORM"], js["images"]


def piece(mask, name):
    arr = {k: v for k, v in A.items() if k != "indices"}
    arr["indices"] = tris[mask].reshape(-1)
    glb.write_piece(js, bn, f"{out}/{name}.glb", arr, name, IMAGES)
    used = np.unique(tris[mask])
    y = A["POSITION"][used, 1]
    jn = [js["nodes"][j]["name"] for j in js["skins"][0]["joints"]]
    w = A["WEIGHTS_0"][used]; jj = A["JOINTS_0"][used]
    wsum = {}
    for b, ww in zip(jj.reshape(-1), w.reshape(-1)):
        if ww > 0:
            wsum[jn[b]] = wsum.get(jn[b], 0.0) + float(ww)
    tot = sum(wsum.values())
    return {"triangles": int(mask.sum()), "vertices_used": int(len(used)), "y_range": [float(y.min()), float(y.max())],
            "weight_share": {k: round(v / tot, 4) for k, v in sorted(wsum.items(), key=lambda kv: -kv[1])}}


stats = {"source": os.path.basename(src), "triangles": int(len(tris)),
         "components": sorted([int(c) for c in counts], reverse=True),
         "head": piece(is_head, "head"), "hair_current": piece(~is_head, "hair_current")}
assert stats["head"]["triangles"] + stats["hair_current"]["triangles"] == len(tris)
# Rows for game/data/characters/appearance.json, part "hair" (CHARCREATE's shape: id, name, scene, attach_bone,
# genders). "head" replaces the survivor's head region (it carries that option's scalp paint) and "scene" is the
# piece in the "hair" region that helmets hide ("" = none); apply a row with PlayerEquipment.set_hair(head, scene).
# base_short is today's look: PlayerEquipment wears it as body/body_helmet.glb, the same triangles in one mesh.
# ASSUMPTION: genders ["m"] - these fit the v2 base only, which is a man; a female base needs its own set.
H = "res://assets/characters/survivor/hair/"
OPTIONS = [
    {"id": "base_short", "name": "Short", "head": H + "head.glb", "scene": H + "hair_current.glb"},
    {"id": "buzz", "name": "Buzz", "head": H + "head_buzz.glb", "scene": ""},
    {"id": "bald", "name": "Bald", "head": H + "head_bald.glb", "scene": ""},
    {"id": "crop", "name": "Crop", "head": H + "head.glb", "scene": H + "hair_crop.glb"},
]
for o in OPTIONS:
    o.update({"attach_bone": "Head", "region": "hair", "genders": ["m"]})
man = f"{out}/hair.json"
data = json.load(open(man)) if os.path.exists(man) else {}
data["options"] = OPTIONS
data["split"] = stats
json.dump(data, open(man, "w"), indent=1)
print("SPLIT", json.dumps(stats))
