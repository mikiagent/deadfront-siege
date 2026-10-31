"""Bake the carnotaurus ALPHA albedo (owner sheet 2: rust and black, heavy dark mottling, sharp black horns) from the
regular Tripo colour map, so alphas wear it on the same mesh and UVs (CreatureView.apply_alpha_skin, JSON
pipeline.alpha_texture).

The regular map's light/dark structure is kept (scales, spots, the pale belly) and recoloured: tan -> rust orange,
dark spots -> near black, pale belly -> dusty grey-tan. Black blotches come from 3D noise in the mesh's own space
(no UV seams), heavier on the back and flanks than on the belly. The horns are already dark in the regular map and
come out near black; painting them by position also blackened a shin patch (the Tripo UVs share texture space
between the horn and shin islands), so there is no horn mask. Everything is a shader, baked through an emission
pass into an image the size of the original.

usage: Blender -b -P tools/gait/make_carno_alpha_skin.py -- <carnotaurus.glb> <out.jpg>
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, OUT = argv[:2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
ob = next(o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers))
for o in list(bpy.data.objects):
    if o.type == "MESH" and o is not ob:
        bpy.data.objects.remove(o)
mat = ob.data.materials[0]
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
src = bsdf.inputs["Base Color"].links[0].from_node.image
W, H = src.size
print("source", src.name, W, H)
N, L = nt.nodes, nt.links


def node(kind, **inputs):
    n = N.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


tex = N.new("ShaderNodeTexImage"); tex.image = src
lum = N.new("ShaderNodeRGBToBW"); L.new(tex.outputs[0], lum.inputs[0])
# recolour by luminance: dark spots black, mid tan -> rust, light belly -> dusty grey-tan
ramp = N.new("ShaderNodeValToRGB"); L.new(lum.outputs[0], ramp.inputs[0])
cr = ramp.color_ramp
cr.elements[0].position, cr.elements[0].color = 0.05, (0.02, 0.015, 0.012, 1)
cr.elements[1].position, cr.elements[1].color = 0.75, (0.45, 0.36, 0.28, 1)
for pos, col in ((0.15, (0.16, 0.04, 0.012, 1)), (0.27, (0.42, 0.13, 0.03, 1)), (0.42, (0.58, 0.24, 0.08, 1))):
    e = cr.elements.new(pos); e.color = col
# black mottling: 3D noise in object space, stronger on the back (normal up) and flanks
tc = N.new("ShaderNodeTexCoord")
noise = node("ShaderNodeTexNoise", Scale=9.0, Detail=4.0, Roughness=0.6)
L.new(tc.outputs["Object"], noise.inputs["Vector"])
blot = N.new("ShaderNodeValToRGB"); L.new(noise.outputs["Fac"], blot.inputs[0])
blot.color_ramp.elements[0].position, blot.color_ramp.elements[0].color = 0.50, (0, 0, 0, 1)
blot.color_ramp.elements[1].position, blot.color_ramp.elements[1].color = 0.58, (1, 1, 1, 1)
geo = N.new("ShaderNodeNewGeometry")
sep = N.new("ShaderNodeSeparateXYZ"); L.new(geo.outputs["Normal"], sep.inputs[0])
dors = N.new("ShaderNodeMapRange"); L.new(sep.outputs["Z"], dors.inputs["Value"])
dors.inputs["From Min"].default_value, dors.inputs["From Max"].default_value = -0.6, 0.5
dors.inputs["To Min"].default_value, dors.inputs["To Max"].default_value = 0.0, 0.9
amt = N.new("ShaderNodeMath"); amt.operation = "MULTIPLY"
L.new(blot.outputs[0], amt.inputs[0]); L.new(dors.outputs[0], amt.inputs[1])
mott = N.new("ShaderNodeMix"); mott.data_type = "RGBA"
L.new(amt.outputs[0], mott.inputs["Factor"]); L.new(ramp.outputs[0], mott.inputs[6])
mott.inputs[7].default_value = (0.02, 0.014, 0.012, 1)
emit = N.new("ShaderNodeEmission"); L.new(mott.outputs[2], emit.inputs["Color"])
out = next(n for n in N if n.type == "OUTPUT_MATERIAL")
L.new(emit.outputs[0], out.inputs["Surface"])

img = bpy.data.images.new("alpha_albedo", W, H)
target = N.new("ShaderNodeTexImage"); target.image = img  # unlinked bake target, active
N.active = target
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 4
sc.cycles.device = "CPU"
for o in bpy.data.objects:
    o.select_set(o is ob)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.bake(type="EMIT", margin=8)
sc.render.image_settings.file_format = "JPEG"  # save_render writes the scene's output format, not the image's
sc.render.image_settings.color_mode = "RGB"
sc.render.image_settings.quality = 92
img.save_render(OUT)
print("WROTE", OUT)
