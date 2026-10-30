"""STEGOFIX: lift a clip so the skinned body never sinks below the floor. Samples the clip at 30 fps on the real
skin, and where the lowest point is below 0 it raises the root by that much (a new LINEAR root translation track
at the same rate; the root's parent must be an unrotated armature node so +Y is up). Everything else in the GLB is
kept byte for byte (the new track is appended to the binary chunk).
usage: Blender -b -P tools/gait/ground_clip.py -- <base.glb> <clip.glb> <out.glb>
"""
import bpy, sys, json, struct
import numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
base, clip, dst = a[:3]
FPS = 30
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
objs = set(bpy.data.objects); acts = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=clip)
act = max(set(bpy.data.actions) - acts, key=lambda x: x.frame_range[1])
for o in set(bpy.data.objects) - objs: bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data_create(); arm.animation_data.action = act
try: arm.animation_data.action_slot = act.slots[0]
except Exception: pass
blob = bytearray(open(clip, "rb").read())
jl = struct.unpack_from("<I", blob, 12)[0]; doc = json.loads(blob[20:20 + jl])
bl = struct.unpack_from("<I", blob, 20 + jl)[0]; bin_ = bytearray(blob[28 + jl:28 + jl + bl])
names = [n["name"] for n in doc["nodes"]]; r = names.index("root")
par = {c: i for i, n in enumerate(doc["nodes"]) for c in n.get("children", [])}
assert "rotation" not in doc["nodes"][par[r]] and "matrix" not in doc["nodes"][par[r]], "root parent is rotated"
A = doc["animations"][0]
def read(ai):
    ac = doc["accessors"][ai]; bv = doc["bufferViews"][ac["bufferView"]]; o = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    k = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[ac["type"]]
    return np.frombuffer(bytes(bin_[o:o + 4 * k * ac["count"]]), np.float32).reshape(ac["count"], k)
ch = next(c for c in A["channels"] if c["target"]["node"] == r and c["target"]["path"] == "translation")
s = A["samplers"][ch["sampler"]]; ti = read(s["input"])[:, 0]; tv = read(s["output"])
t0, t1 = float(min(read(x["input"]).min() for x in A["samplers"])), float(max(read(x["input"]).max() for x in A["samplers"]))
times = np.round(np.arange(t0, t1 + 1e-6, 1.0 / FPS), 6)
def root_at(t):
    if s.get("interpolation") == "STEP": return tv[max(0, np.searchsorted(ti, t, "right") - 1)]
    return np.array([np.interp(t, ti, tv[:, k]) for k in range(3)])
f0 = act.frame_range[0]
lift = []
for t in times:
    bpy.context.scene.frame_set(int(round(f0 + (t - t0) * FPS)))
    dg = bpy.context.evaluated_depsgraph_get(); e = body.evaluated_get(dg); me = e.to_mesh()
    low = min((body.matrix_world @ v.co).z for v in me.vertices); e.to_mesh_clear()
    lift.append(max(0.0, -low))
lift = np.array(lift)
print("LIFT max", round(float(lift.max()), 4), "frames lifted", int((lift > 0.002).sum()), "of", len(times))
if lift.max() <= 0.002:
    open(dst, "wb").write(blob); sys.exit(0)
vals = np.array([root_at(t) + np.array([0, l, 0]) for t, l in zip(times, lift)], np.float32)
def push(arr, typ):
    while len(bin_) % 4: bin_.append(0)
    off = len(bin_); bin_.extend(arr.astype(np.float32).tobytes())
    doc["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes})
    acc = {"bufferView": len(doc["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": typ}
    if typ == "SCALAR": acc.update(min=[float(arr.min())], max=[float(arr.max())])
    doc["accessors"].append(acc); return len(doc["accessors"]) - 1
A["samplers"].append({"input": push(times.astype(np.float32), "SCALAR"), "output": push(vals, "VEC3"), "interpolation": "LINEAR"})
ch["sampler"] = len(A["samplers"]) - 1
while len(bin_) % 4: bin_.append(0)
doc["buffers"][0]["byteLength"] = len(bin_)
js = json.dumps(doc, separators=(",", ":")).encode(); js += b" " * (-len(js) % 4)
out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(bin_)) + struct.pack("<I4s", len(js), b"JSON") + js + struct.pack("<I4s", len(bin_), b"BIN\x00") + bytes(bin_)
open(dst, "wb").write(out); print("WROTE", dst)
