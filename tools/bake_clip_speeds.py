#!/usr/bin/env python3
"""Bake each creature gait's natural ground speed into game/data/creatures/anim_events.json.

natural_speeds[species] = {height_m, walk, run, walk_len, run_len}: the planted-foot ground
speed (m/s) of the walk and run clips at cadence 1 and at the species' height_m, measured in
headless Godot with the game's own clip loader after CreatureClips.trim_frozen_tail (the stride
method of the dino-art audit: median foot z-velocity while the foot is within tol of its lowest
point). CreatureAnim.set_move_speed divides body speed by it to get the cadence. *_len is the
loop length the speed was measured on (shows the trim).

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

# Classes are loaded at runtime: `--script` compiles before the Data autoload exists.
GD = r'''extends SceneTree
const FEET := ["BackFoot.L", "Toe.L", "Metatarsal.L"]
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
			var foot := -1
			for f in FEET:
				if foot == -1:
					foot = skel.find_bone(f)
			var ap: AnimationPlayer = view.animation_player()
			var row := {"id": str(id), "height_m": def.height_meters}
			for gait in ["walk", "run"]:
				if foot != -1 and ap.has_animation(gait):
					var anim: Animation = ap.get_animation(gait)
					clips.trim_frozen_tail(anim)
					row[gait] = snappedf(_stride(view, skel, ap, gait, foot, anim.length, def.height_meters), 0.001)
					row[gait + "_len"] = snappedf(anim.length, 0.001)
			print("[bake] " + JSON.stringify(row))
		view.free()
	quit(0)

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
        print("%-14s h=%.1f walk=%s (len %s) run=%s (len %s)" % (
            sp, row["height_m"], row.get("walk"), row.get("walk_len"), row.get("run"), row.get("run_len")))
    if "--dry-run" in sys.argv:
        return 0
    with open(EVENTS) as f:
        events = json.load(f)
    events["natural_speeds"] = dict(sorted(rows.items()))
    with open(EVENTS, "w") as f:
        json.dump(events, f, indent=2)
        f.write("\n")
    print("BAKE OK: %d species -> %s" % (len(rows), os.path.relpath(EVENTS, ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
