extends Node3D
## REXJAW: side close-ups of the T. rex's head in each bite clip at closed, half-open and full-open, as the game draws
## it (colour shader, double-sided, game lighting). Phases come from the Jaw bone itself: the widest frame, the first
## frame at half of it, and the clip's first frame. Writes <shot-dir>/<clip>_<closed|half|full>.png and quits.
##
##   godot --path game --position 6000,3000 --resolution 1200x900 -- --lab=rexjaw_lab --shot-dir=/tmp/rexjaw \
##     --skip-charcreate [--clips=attack_primary,attack_heavy,roar,alert] [--species=tyrannosaurus]

const WATCHDOG_S := 120.0

var shot_dir := "/tmp/rexjaw"
var species: StringName = &"tyrannosaurus"
var clips: Array[StringName] = [&"attack_primary", &"attack_heavy", &"roar", &"alert"]
var _cam: Camera3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
		elif a.begins_with("--species="):
			species = StringName(a.substr(10))
		elif a.begins_with("--clips="):
			clips.clear()
			for c in a.substr(8).split(","):
				clips.append(StringName(c))
	Game.debug_overlay = false
	Game.day_length_seconds = 1.0e9
	Game.time_of_day = 0.45
	var kit := LabKit.build(self, 60.0)
	for k in ["player", "nav"]:
		(kit[k] as Node).queue_free()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	TouchControls.visible = false
	DirAccess.make_dir_recursive_absolute(shot_dir)
	get_tree().create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("[rexjaw] FAIL watchdog")
		get_tree().quit(1))
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.current = true
	add_child(_cam)
	_run.call_deferred()

func _run() -> void:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.spawn(Data.creature(species))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	if c.label:
		c.label.visible = false
	await get_tree().create_timer(0.5).timeout
	c.anim.tree.active = false
	var player: AnimationPlayer = c.anim.player
	var sk: Skeleton3D = c.view.rig.skeleton
	var jaw := sk.find_bone("Jaw")
	var head := sk.find_bone("Head")
	for clip in clips:
		if not player.has_animation(clip):
			print("[rexjaw] FAIL no clip %s" % clip)
			continue
		var anim := player.get_animation(clip)
		player.play(clip)
		# the jaw's angle off its rest, relative to the head, sampled over the clip
		var n := 60
		var ang: Array[float] = []
		for i in n + 1:
			player.seek(anim.length * i / n, true)
			var rel := sk.get_bone_pose_rotation(jaw) * sk.get_bone_rest(jaw).basis.get_rotation_quaternion().inverse()
			ang.append(rad_to_deg(rel.get_angle()))
		var peak := 0
		for i in ang.size():
			if ang[i] > ang[peak]:
				peak = i
		var half := 0
		while half < peak and ang[half] < ang[peak] * 0.5:
			half += 1
		for shot in [["closed", 0], ["half", half], ["full", peak]]:
			player.seek(anim.length * int(shot[1]) / n, true)
			await get_tree().process_frame
			# side-on from the animal's left, level with the head, centred a little toward the snout
			var hp := sk.global_transform * sk.get_bone_global_pose(head)
			var fwd := -c.global_basis.z
			var tgt := hp.origin + fwd * 1.3 - Vector3(0, 0.4, 0)
			_cam.size = 4.5
			_cam.global_position = tgt - c.global_basis.x * 30.0
			_cam.look_at(tgt, Vector3.UP)
			for _f in 4:
				await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%s.png" % [shot_dir, clip, shot[0]])
			print("[rexjaw] %s %s t=%.2f jaw %.1f deg" % [clip, shot[0], anim.length * int(shot[1]) / n, ang[int(shot[1])]])
		player.stop()
	print("[rexjaw] done -> %s" % shot_dir)
	get_tree().quit(0)
