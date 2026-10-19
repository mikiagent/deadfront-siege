#!/usr/bin/env python3
"""Bake each creature gait's natural ground speed into game/data/creatures/anim_events.json.

natural_speeds[species] = {height_m, walk, run, walk_len, run_len}: the planted-foot ground
speed (m/s) of the walk and run clips at cadence 1 and at the species' height_m, measured in
headless Godot with the game's own clip loader after CreatureClips.trim_frozen_tail (the stride
method of the dino-art audit: median foot z-velocity while the foot is within tol of its lowest
point), on the left and right foot (*_l, *_r); the speed is their mean. CreatureAnim.set_move_speed
divides body speed by it to get the cadence. *_len is the loop length the speed was measured on;
the runtime ignores a bake whose *_len no longer matches the clip (stale after a GLB swap).

The speeds live in anim_events.json, not a clip_speeds.json, because Data._load_creatures
parses every other *.json in data/creatures as a species.

Usage: tools/bake_clip_speeds.py [--dry-run]    GODOT=/path/to/Godot overrides find_godot.sh
Rebake after changing a creature's walk/run GLB.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")
EVENTS = os.path.join(GAME, "data", "creatures", "anim_events.json")
# ASSUMPTION: a gait whose faster planted foot strides more than 1.6x the slower one gets no speed and
# is marked for replacement (row "<gait>_replace"): past 1.67x no cadence from the mean keeps both feet
# inside the [0.75, 1.30] foot/body window, so a baked number would just pick which foot slides.
FEET_DISAGREE = 1.6

# Classes are loaded at runtime: `--script` compiles before the Data autoload exists.
GD = r'''extends SceneTree
const FEET := ["BackFoot", "Toe", "Metatarsal"]  # + ".L" / ".R": first bone the rig has
const N := 240
var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _run() -> void:
	var data: Node = root.get_node("Data")
	var view_script: GDScript = load("res://scripts/creatures/creature_view.gd")
	var clips: GDScript = load("res://scripts/creatures/creature_clips.gd")
	var ids: Array = data.creatures.keys()
	ids.sort()
	for id in ids:
		var def = data.creature(id)
		var view = view_script.new()
		root.add_child(view)
		view.setup(def)
		if view.using_glb and view.rig and view.rig.skeleton:
			var skel: Skeleton3D = view.rig.skeleton
			var feet := {"l": _foot(skel, ".L"), "r": _foot(skel, ".R")}
			var ap: AnimationPlayer = view.animation_player()
			var row := {"id": str(id), "height_m": def.height_meters}
			for gait in ["walk", "run"]:
				if feet["l"] != -1 and feet["r"] != -1 and ap.has_animation(gait):
					var anim: Animation = ap.get_animation(gait)
					clips.trim_frozen_tail(anim)
					for side in feet:
						row[gait + "_" + side] = snappedf(_stride(view, skel, ap, gait, feet[side], anim.length, def.height_meters), 0.001)
					row[gait + "_len"] = snappedf(anim.length, 0.001)
			print("[bake] " + JSON.stringify(row))
		view.free()
	quit(0)

func _foot(skel: Skeleton3D, side: String) -> int:
	for f in FEET:
		var b := skel.find_bone(f + side)
		if b != -1:
			return b
	return -1

func _stride(view: Node3D, skel: Skeleton3D, ap: AnimationPlayer, gait: String, foot: int, length: float, h: float) -> float:
	ap.play(gait)
	var ys := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for i in N + 1:
		ap.seek(length * float(i) / float(N), true)
		var p: Vector3 = view.to_local(skel.global_transform * skel.get_bone_global_pose(foot).origin)
		ys.append(p.y)
		zs.append(p.z)
	var ymin := ys[0]
	for y in ys:
		ymin = minf(ymin, y)
	var tol := maxf(0.02, h * 0.015)
	var vels: Array[float] = []
	for i in N:
		if ys[i] <= ymin + tol and ys[i + 1] <= ymin + tol:
			vels.append((zs[i + 1] - zs[i]) / (length / float(N)))
	vels.sort()
	return absf(vels[vels.size() / 2]) if vels.size() > 0 else 0.0
'''


def main() -> int:
    godot = os.environ.get("GODOT") or subprocess.check_output(
        [os.path.join(ROOT, "tools", "find_godot.sh")], text=True).strip()
    with tempfile.TemporaryDirectory() as tmp:
        script = os.path.join(tmp, "bake_clip_speeds.gd")
        with open(script, "w") as f:
            f.write(GD)
        run = subprocess.run(
            [godot, "--headless", "--audio-driver", "Dummy", "--path", GAME, "--script", script],
            capture_output=True, text=True, timeout=600)
    rows = {}
    for line in run.stdout.splitlines():
        if line.startswith("[bake] "):
            row = json.loads(line[7:])
            rows[row.pop("id")] = row
    if not rows:
        sys.stderr.write(run.stdout[-4000:] + run.stderr[-4000:])
        print("BAKE FAIL: no [bake] rows")
        return 1
    for sp, row in sorted(rows.items()):
        for gait in ("walk", "run"):
            l, r = row.get(gait + "_l", 0.0), row.get(gait + "_r", 0.0)
            if min(l, r) <= 0.0 or max(l, r) / min(l, r) > FEET_DISAGREE:
                row[gait + "_replace"] = "feet disagree: L %.3f R %.3f m/s" % (l, r)
            else:
                row[gait] = round((l + r) / 2.0, 3)
        print("%-14s h=%.1f walk=%s (L %s R %s, len %s) run=%s (L %s R %s, len %s)" % (
            sp, row["height_m"], row.get("walk", "REPLACE"), row.get("walk_l"), row.get("walk_r"), row.get("walk_len"),
            row.get("run", "REPLACE"), row.get("run_l"), row.get("run_r"), row.get("run_len")))
    if "--dry-run" in sys.argv:
        return 0
    with open(EVENTS) as f:
        text = f.read()
    # Splice natural_speeds in as the last key so the hand-formatted rest of the file stays byte-identical.
    at = text.find('"natural_speeds"')
    if at != -1:
        text = text[:text.rfind(",", 0, at)] + "\n}\n"
    body = json.dumps(dict(sorted(rows.items())), indent=2).replace("\n", "\n  ")
    text = text[:text.rstrip().rfind("}")].rstrip() + ',\n  "natural_speeds": ' + body + "\n}\n"
    json.loads(text)  # refuse to write a broken file
    with open(EVENTS, "w") as f:
        f.write(text)
    print("BAKE OK: %d species -> %s" % (len(rows), os.path.relpath(EVENTS, ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
