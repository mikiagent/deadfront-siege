# check_sprites2d.py <tree> <stage>: SPRITES2D checks (run with Blender's python3.13: numpy; dwebp/ffmpeg/ffprobe on PATH).
# stage 1: every green sheet is cut into trimmed RGBA PNGs with no screen green left in them.
# stage 2: + every sprite is mapped (kind, height, blocks, destroyable, pivot) by the rules in the task.
import json, os, subprocess, sys, glob
import numpy as np

tree, stage = sys.argv[1], int(sys.argv[2])
KEY = np.array([5, 250, 4])
fails = []

def fail(msg):
    fails.append(msg)

def rgba(path):
    w, h = map(int, subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                                    "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip().split(","))
    fmt = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=pix_fmt", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip()
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(h, w, 4).astype(int), fmt

sheets = sorted(os.path.basename(p)[:-5] for p in glob.glob(os.path.join(tree, "docs/reference/2d-assets/sheet-*.webp")))
man_path = os.path.join(tree, "game/data/world/sprites2d.json")
if not os.path.isfile(os.path.join(tree, "tools/sprites2d/cut.py")):
    fail("tools/sprites2d/cut.py is missing")
if not os.path.isfile(man_path):
    fail("game/data/world/sprites2d.json is missing")
    print("\n".join("FAIL " + f for f in fails)); sys.exit(1)
try:
    man = json.load(open(man_path))
    sprites = man["sprites"]
except Exception as e:
    print("FAIL sprites2d.json does not parse or has no 'sprites' list: %s" % e); sys.exit(1)

families = set(json.load(open(os.path.join(tree, "game/data/nature_manifest.json"))).get("families", {}).keys())
per_sheet = {s: 0 for s in sheets}
ids = set()
total_bytes = 0
for sp in sprites:
    sid = sp.get("id", "?")
    if sid in ids:
        fail("%s: duplicate id" % sid)
    ids.add(sid)
    sheet = sp.get("sheet")
    if sheet not in per_sheet:
        fail("%s: sheet %r is not one of %s" % (sid, sheet, sheets)); continue
    per_sheet[sheet] += 1
    f = str(sp.get("file", ""))
    if not f.startswith("res://assets/nature/sprites2d/%s/" % sheet) or not f.endswith(".png"):
        fail("%s: file %r is not res://assets/nature/sprites2d/%s/*.png" % (sid, f, sheet)); continue
    path = os.path.join(tree, "game", f[len("res://"):])
    if not os.path.isfile(path):
        fail("%s: %s does not exist" % (sid, f)); continue
    total_bytes += os.path.getsize(path)
    a, fmt = rgba(path)
    h, w = a.shape[:2]
    if "a" not in fmt:
        fail("%s: PNG has no alpha channel (pix_fmt %s)" % (sid, fmt))
    if list(sp.get("px", [])) != [w, h]:
        fail("%s: px %s but the PNG is %dx%d" % (sid, sp.get("px"), w, h))
    if w < 24 or h < 24:
        fail("%s: %dx%d is a speck, not an item (merge it or drop it)" % (sid, w, h))
    al = a[..., 3]
    ys, xs = np.nonzero(al > 8)
    if len(xs) == 0:
        fail("%s: fully transparent" % sid); continue
    if xs.min() > 3 or ys.min() > 3 or xs.max() < w - 4 or ys.max() < h - 4:
        fail("%s: not trimmed (alpha box x %d..%d y %d..%d in %dx%d)" % (sid, xs.min(), xs.max(), ys.min(), ys.max(), w, h))
    rgb = a[..., :3]
    dist = np.sqrt(((rgb - KEY) ** 2).sum(-1))
    solid = al >= 200
    edge = (al > 8) & (al < 200)
    if solid.sum() and (dist[solid] < 90).mean() > 0.003:
        fail("%s: %.2f%% of opaque pixels are screen green (limit 0.3%%)" % (sid, 100 * (dist[solid] < 90).mean()))
    if edge.sum() > 20 and (dist[edge] < 90).mean() > 0.03:
        fail("%s: %.1f%% of edge pixels are screen green (limit 3%%)" % (sid, 100 * (dist[edge] < 90).mean()))
    gd = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
    if edge.sum() > 20 and solid.sum() > 20 and gd[edge].mean() > gd[solid].mean() + 25:
        fail("%s: green fringe (edge G-max(R,B) %.0f vs inside %.0f; despill the edges)" % (sid, gd[edge].mean(), gd[solid].mean()))
    if stage >= 2:
        kind = str(sp.get("kind", ""))
        if not (kind in families or kind.startswith("prop:") or kind.startswith("icon:") or kind == "unused"):
            fail("%s: kind %r is not a nature family, prop:<name>, icon:<item> or unused" % (sid, kind))
        if not str(sp.get("name", "")).strip():
            fail("%s: no name" % sid)
        hm = sp.get("height_m")
        if not isinstance(hm, (int, float)) or not (0.05 <= hm <= 40):
            fail("%s: height_m %r outside 0.05..40" % (sid, hm))
            hm = 0
        for k in ("blocks", "destroyable"):
            if not isinstance(sp.get(k), bool):
                fail("%s: %s must be true or false" % (sid, k))
        pv = sp.get("pivot")
        if not (isinstance(pv, list) and len(pv) == 2 and 0 <= pv[0] <= w and 0 <= pv[1] <= h):
            fail("%s: pivot %r is not inside %dx%d" % (sid, pv, w, h))
        big = any(t in kind for t in ("cliff", "arch", "pillar", "mesa", "stack", "waterfall"))
        if kind.startswith("prop:") and big and hm >= 4 and sp.get("destroyable") is not False:
            fail("%s: a big cliff/arch/pillar/waterfall (>= 4 m) cannot be destroyed (owner rule)" % sid)
        hanging = kind.startswith("prop:vine") or kind.startswith("prop:root")
        if kind != "unused" and not kind.startswith("icon:") and not hanging and isinstance(hm, (int, float)):
            if kind in families:
                # Same rule as HarvestNode.blocks_movement(): trees, or a family height span whose top is over 1.25 m.
                fam = json.load(open(os.path.join(tree, "game/data/nature_manifest.json")))["families"][kind]
                role = str(fam.get("role", ""))
                span = fam.get("height")
                top = 1.3 if role == "rock" else 0.0
                if isinstance(span, list) and len(span) >= 2:
                    top = float(span[1])
                want = role.startswith("tree") or top > 1.25
            elif kind.startswith("prop:grass") or kind.startswith("prop:reed"):
                want = False  # ground cover never blocks (spec 28), however tall
            else:
                want = hm > 1.25
            if sp.get("blocks") is not want:
                fail("%s: blocks must be %s (families: the game's HarvestNode.blocks_movement rule; props: over 1.25 m blocks, grass/reed props never)" % (sid, want))

for s, n in per_sheet.items():
    if n < 10:
        fail("%s: only %d sprites (each sheet holds 15-45 items; cut at least 10)" % (s, n))
if stage >= 2:
    mapped = sum(1 for sp in sprites if sp.get("kind") != "unused")
    if sprites and mapped / len(sprites) < 0.6:
        fail("only %d of %d sprites are mapped (need 60%%)" % (mapped, len(sprites)))
if total_bytes > 24 * 1024 * 1024:
    fail("sprites total %.1f MB, budget 24 MB (the web pack is over its ceiling already)" % (total_bytes / 1048576))
print("sheets=%d sprites=%d bytes=%.1fMB per_sheet=%s" % (len(sheets), len(sprites), total_bytes / 1048576, per_sheet))
for f in fails[:40]:
    print("FAIL " + f)
if len(fails) > 40:
    print("FAIL ... and %d more" % (len(fails) - 40))
sys.exit(1 if fails else 0)
