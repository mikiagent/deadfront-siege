"""Bake the per-climate ground texture sets (W1-BIOME).

Headless only (the Blender MCP lock belongs to another package):
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/terrain/bake_terrain.py -- [climate ...] [--size 1024]

Writes game/assets/terrain/<climate>/{ground,dirt,sand,rock}.png: seamless 1024 px colour maps that
terrain_tiles.gdshader samples as grass_tex / dirt_tex / sand_tex / rock_tex. Each layer is a
Cycles emission bake of procedural nodes on a unit plane. Every noise is sampled on a 4D Clifford
torus (cos u, sin u, cos v, sin v), which is flat, so features stay round and the tile wraps with
no seam. Recipes live in recipes.py next to this file.
"""
import math
import pathlib
import sys
import time

import bpy
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from recipes import RECIPES  # noqa: E402

ROOT = HERE.parents[2]
OUT = ROOT / "game" / "assets" / "terrain"
LAYERS = ("ground", "dirt", "sand", "rock")


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgba(hex_color: str) -> tuple:
    h = hex_color.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


def sock(sockets, name: str, kind: str):
    """Blender 5 nodes carry several same-named sockets per data type; pick the live one."""
    for s in sockets:
        if s.name == name and s.type == kind and s.enabled:
            return s
    raise KeyError(f"{name}:{kind}")


class Graph:
    """Small builder over one material's node tree; every method returns an output socket."""

    def __init__(self, mat: bpy.types.Material):
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.links = self.nt.links
        uv = self.nt.nodes.new("ShaderNodeTexCoord").outputs["UV"]
        sep = self.nt.nodes.new("ShaderNodeSeparateXYZ")
        self.links.new(uv, sep.inputs[0])
        self.u, self.v = sep.outputs["X"], sep.outputs["Y"]
        self._torus = {}

    def node(self, kind: str, **props):
        n = self.nt.nodes.new(kind)
        for k, val in props.items():
            setattr(n, k, val)
        return n

    def feed(self, socket, value):
        if isinstance(value, bpy.types.NodeSocket):
            self.links.new(value, socket)
        else:
            socket.default_value = value

    def math(self, op: str, a, b=0.0):
        n = self.node("ShaderNodeMath", operation=op)
        self.feed(n.inputs[0], a)
        self.feed(n.inputs[1], b)
        return n.outputs[0]

    def torus(self, sx: float = 1.0, sy: float = 1.0, seed: int = 0):
        """4D coordinates whose circumference is sx (u) and sy (v), so scale = features per tile."""
        key = (sx, sy, seed)
        if key in self._torus:
            return self._torus[key]
        out = []
        for axis, s in ((self.u, sx), (self.v, sy)):
            ang = self.math("MULTIPLY", axis, 2.0 * math.pi)
            r = s / (2.0 * math.pi)
            out.append(self.math("MULTIPLY", self.math("COSINE", ang), r))
            out.append(self.math("MULTIPLY", self.math("SINE", ang), r))
        off = (seed * 7.31, seed * 3.17, seed * 5.93, seed * 2.41)
        comb = self.node("ShaderNodeCombineXYZ")
        for i in range(3):
            self.feed(comb.inputs[i], self.math("ADD", out[i], off[i]))
        w = self.math("ADD", out[3], off[3])
        self._torus[key] = (comb.outputs[0], w)
        return self._torus[key]

    def noise(self, scale, detail=4.0, rough=0.55, distortion=0.0, seed=0, stretch=(1.0, 1.0), kind="FBM"):
        vec, w = self.torus(stretch[0], stretch[1], seed)
        n = self.node("ShaderNodeTexNoise", noise_dimensions="4D", noise_type=kind)
        self.feed(n.inputs["Vector"], vec)
        self.feed(n.inputs["W"], w)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distortion
        return n.outputs["Factor"]

    def voronoi(self, scale, feature="F1", seed=0, randomness=1.0, stretch=(1.0, 1.0)):
        vec, w = self.torus(stretch[0], stretch[1], seed)
        n = self.node("ShaderNodeTexVoronoi", voronoi_dimensions="4D", feature=feature)
        self.feed(n.inputs["Vector"], vec)
        self.feed(n.inputs["W"], w)
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = randomness
        return n.outputs["Distance"], n.outputs["Color"]

    def remap(self, value, lo, hi, smooth=True):
        n = self.node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP" if smooth else "LINEAR", clamp=True)
        self.feed(n.inputs["Value"], value)
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        return n.outputs["Result"]

    def ramp(self, fac, colors):
        n = self.node("ShaderNodeValToRGB")
        els = n.color_ramp.elements
        while len(els) < len(colors):
            els.new(0.5)
        for i, c in enumerate(colors):
            els[i].position = i / max(1, len(colors) - 1)
            els[i].color = rgba(c)
        self.feed(n.inputs["Fac"], fac)
        return n.outputs["Color"]

    def mix(self, a, b, fac, blend="MIX"):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type=blend, clamp_result=True)
        self.feed(sock(n.inputs, "Factor", "VALUE"), fac)
        self.feed(sock(n.inputs, "A", "RGBA"), a)
        self.feed(sock(n.inputs, "B", "RGBA"), b)
        return sock(n.outputs, "Result", "RGBA")

    def emit(self, color):
        em = self.node("ShaderNodeEmission")
        self.feed(em.inputs["Color"], color)
        out = self.node("ShaderNodeOutputMaterial")
        self.links.new(em.outputs[0], out.inputs["Surface"])


def build_layer(g: Graph, spec: dict):
    """Spec keys (all optional but base): base, ripples, splats, cracks, grain. See recipes.py."""
    b = spec["base"]
    t = g.noise(b.get("scale", 6.0), b.get("detail", 6.0), b.get("rough", 0.6), b.get("distortion", 0.0),
                b.get("seed", 1), tuple(b.get("stretch", (1.0, 1.0))))
    if "fine" in b:
        f = b["fine"]
        fine = g.noise(f.get("scale", 40.0), f.get("detail", 3.0), f.get("rough", 0.6), 0.0, f.get("seed", 2),
                       tuple(f.get("stretch", (1.0, 1.0))))
        t = g.math("ADD", g.math("MULTIPLY", t, 1.0 - f["amount"]), g.math("MULTIPLY", fine, f["amount"]))
    spread = b.get("spread", 0.18)
    col = g.ramp(g.remap(t, 0.5 - spread, 0.5 + spread, smooth=False), b["colors"])
    for s in spec.get("splats", []):
        if s.get("kind") == "dots":
            dist, cell = g.voronoi(s["scale"], "F1", s.get("seed", 7))
            mask = g.math("SUBTRACT", 1.0, g.remap(dist, s["size"] * 0.6, s["size"]))
            # Each dot keeps only a share of cells so the pattern does not read as a grid.
            keep = g.remap(g.math("MULTIPLY", g.node_color_r(cell), 1.0), 1.0 - s.get("share", 0.5) - 0.01,
                           1.0 - s.get("share", 0.5) + 0.01)
            mask = g.math("MULTIPLY", mask, keep)
        else:
            n = g.noise(s["scale"], s.get("detail", 4.0), s.get("rough", 0.55), s.get("distortion", 0.0),
                        s.get("seed", 5), tuple(s.get("stretch", (1.0, 1.0))))
            mask = g.remap(n, s["lo"], s["hi"])
        mask = g.math("MULTIPLY", mask, s.get("strength", 1.0))
        colors = s["colors"] if "colors" in s else [s["color"], s["color"]]
        tex = g.noise(s.get("tex_scale", 30.0), 3.0, 0.6, 0.0, s.get("seed", 5) + 11)
        scol = g.ramp(g.remap(tex, 0.35, 0.65, smooth=False), colors)
        col = g.mix(col, scol, mask)
    if "ripples" in spec:
        r = spec["ripples"]
        warp = g.noise(r.get("warp_scale", 2.5), 2.0, 0.5, 0.0, r.get("seed", 9))
        phase = g.math("ADD", g.math("MULTIPLY", g.v, float(r["count"])),
                       g.math("MULTIPLY", g.math("SUBTRACT", warp, 0.5), r.get("warp", 3.0)))
        wave = g.math("MULTIPLY", g.math("ADD", g.math("SINE", g.math("MULTIPLY", phase, 2.0 * math.pi)), 1.0), 0.5)
        wave = g.math("POWER", wave, r.get("sharp", 2.0))
        shade = g.ramp(wave, [r.get("dark", "#b8b0a0"), "#ffffff"])
        col = g.mix(col, g.mix(col, shade, 1.0, "MULTIPLY"), r.get("amount", 0.6))
    if "cracks" in spec:
        c = spec["cracks"]
        dist, _cell = g.voronoi(c["scale"], "DISTANCE_TO_EDGE", c.get("seed", 13))
        wob = g.noise(c["scale"] * 4.0, 2.0, 0.5, 0.0, c.get("seed", 13) + 1)
        dist = g.math("ADD", dist, g.math("MULTIPLY", g.math("SUBTRACT", wob, 0.5), c.get("wobble", 0.04)))
        mask = g.math("SUBTRACT", 1.0, g.remap(dist, c["width"] * 0.4, c["width"]))
        col = g.mix(col, g.ramp(mask, ["#ffffff", c["color"]]), g.math("MULTIPLY", mask, c.get("strength", 1.0)), "MULTIPLY")
    gr = spec.get("grain", {"scale": 90.0, "amount": 0.10})
    if gr["amount"] > 0.0:
        gn = g.noise(gr["scale"], 2.0, 0.5, 0.0, 31)
        lo = 1.0 - gr["amount"]
        grain = g.ramp(g.remap(gn, 0.3, 0.7, smooth=False), ["#%02x%02x%02x" % ((int(255 * lo),) * 3), "#ffffff"])
        col = g.mix(col, grain, 1.0, "MULTIPLY")
    g.emit(col)


def _node_color_r(self, color_socket):
    sep = self.node("ShaderNodeSeparateColor")
    self.links.new(color_socket, sep.inputs[0])
    return sep.outputs[0]


Graph.node_color_r = _node_color_r


def setup_scene(size: int):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4  # shared machine: leave cores for the other agents
    scene.render.bake.margin = 0
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    plane = bpy.context.active_object
    return scene, plane


def bake(plane, climate: str, layer: str, spec: dict, size: int) -> pathlib.Path:
    mat = bpy.data.materials.new(f"{climate}_{layer}")
    mat.use_nodes = True
    plane.data.materials.clear()
    plane.data.materials.append(mat)
    g = Graph(mat)
    build_layer(g, spec)
    img = bpy.data.images.new(f"{climate}_{layer}", size, size, alpha=False)
    tex = g.node("ShaderNodeTexImage")
    tex.image = img
    for n in g.nt.nodes:
        n.select = False
    tex.select = True
    g.nt.nodes.active = tex
    bpy.ops.object.bake(type="EMIT")
    out = OUT / climate / f"{layer}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.filepath_raw = str(out)
    img.file_format = "PNG"
    img.save()
    px = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)[:, :, :3]
    # Seam check: the wrap-around column/row step should look like any interior step.
    wrap = float(np.abs(px[:, 0] - px[:, -1]).mean() + np.abs(px[0] - px[-1]).mean()) * 0.5
    inner = float(np.abs(px[:, 1:] - px[:, :-1]).mean())
    mean = px.reshape(-1, 3).mean(axis=0)
    print("[bake] %s/%s mean_lin=(%.3f, %.3f, %.3f) seam=%.4f inner=%.4f" % (climate, layer, *mean, wrap, inner))
    bpy.data.images.remove(img)
    bpy.data.materials.remove(mat)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    size = 1024
    if "--size" in argv:
        i = argv.index("--size")
        size = int(argv[i + 1])
        del argv[i:i + 2]
    climates = argv or list(RECIPES.keys())
    scene, plane = setup_scene(size)
    for climate in climates:
        t0 = time.time()
        for layer in LAYERS:
            bake(plane, climate, layer, RECIPES[climate][layer], size)
        print("[bake] %s done in %.1fs" % (climate, time.time() - t0))
    print("[bake] PASS %d climates" % len(climates))


main()
