extends SceneTree
## KICKTACKLE (owner: "i don't think we have kick or tackle animations"). The survivor has kick.glb (front
## push-kick, 0.46 s) and tackle.glb (shoulder-first lunge, 0.54 s), authored by tools/make_work_clips.py.
## Checks: both clips load; hunt.use_tackle() / use_kick() play them and still lunge the body / shove the
## target; the survivor is back in idle within the tactic lock + 0.3 s; through each clip the lowest foot bone
## stays within 3 cm of where the idle stands it (no sinking, no floating).
## Usage: godot --headless --path game --script res://tests/t_kicktackle.gd  -> "[t_kicktackle] PASS"
##        windowed with `-- --shots <dir>` it also writes a 4-frame contact sheet per clip.

const FOOT_TOL := 0.03
const FEET: Array[String] = ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]

var failures: Array[String] = []
var _started := false
var host: Node3D
var data: Node
var player
var shots := ""

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").debug_overlay = false
	var args := OS.get_cmdline_user_args()
	if "--shots" in args:
		shots = args[args.find("--shots") + 1]
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_kicktackle] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	host = Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	var fm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	fm.mesh = bm
	floor.add_child(fm)
	floor.position.y = -0.5
	host.add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	host.add_child(sun)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await _frames(20)
	var rig = player.rig
	_expect(rig != null and rig.has_clip(&"kick") and rig.has_clip(&"tackle"), "the survivor has kick and tackle clips")
	if rig == null or not rig.has_clip(&"kick") or not rig.has_clip(&"tackle"):
		_finish()
		return
	_feet_check(rig, &"kick")
	_feet_check(rig, &"tackle")
	await _ability(&"tackle", 0.55)
	await _ability(&"kick", 0.45)
	if shots != "":
		await _sheet(rig, cam, &"kick")
		await _sheet(rig, cam, &"tackle")
	_finish()

## Lowest foot bone height in the rig's own space at time t of a clip.
func _low_foot(rig, clip: StringName, t: float) -> float:
	var ap: AnimationPlayer = rig.anim_player
	ap.play(clip, 0.0)
	ap.seek(t, true)
	var sk: Skeleton3D = rig.skeleton
	var low := INF
	for b in FEET:
		var i := sk.find_bone(b)
		if i >= 0:
			low = minf(low, (rig.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(i).origin)).y)
	return low

func _feet_check(rig, clip: StringName) -> void:
	var ground := _low_foot(rig, &"idle", 0.0)
	var length: float = rig.anim_player.get_animation(clip).length
	var worst := 0.0
	var at := 0.0
	var n := 24
	for k in n + 1:
		var t := length * k / n
		var d := _low_foot(rig, clip, t) - ground
		if absf(d) > absf(worst):
			worst = d
			at = t
	_expect(absf(worst) <= FOOT_TOL, "%s: lowest foot stays within %.0f cm of the idle's ground (worst %+.1f cm at %.2f s, %.2f s clip)"
		% [clip, FOOT_TOL * 100.0, worst * 100.0, at, length])
	rig.anim_player.play(&"idle", 0.0)

func _ability(kind: StringName, lock: float) -> void:
	player.anim.play_idle()
	await _frames(10)
	var raptor = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(raptor)
	raptor.global_position = player.global_position + Vector3(0, 0, -2.6)
	raptor.spawn(data.creature(&"velociraptor"), &"", 0, null, 0, &"loyal")
	raptor.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	player.vitals.energy = player.vitals.effective_max_energy()
	var hunt = player.hunt
	hunt.start(raptor)
	var p0: Vector3 = player.global_position
	var r0: Vector3 = raptor.global_position
	if kind == &"tackle":
		hunt.use_tackle()
	else:
		hunt.use_kick()
	hunt.stop()  # no auto-swing afterwards: only the tactic's clip plays
	_expect(player.anim.current_clip == kind, "%s plays the %s clip (got %s)" % [kind, kind, player.anim.current_clip])
	if kind == &"tackle":
		var moved := Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
		_expect(moved > 0.2, "tackle still lunges the survivor (%.2f m)" % moved)
	else:
		var shoved := Vector2(raptor.global_position.x - r0.x, raptor.global_position.z - r0.z).length()
		_expect(shoved > 0.2, "kick still shoves the target (%.2f m)" % shoved)
	await _frames(int(ceil((lock + 0.3) * Engine.physics_ticks_per_second)))
	_expect(player.anim.current_clip == &"idle", "%s is back in idle within lock + 0.3 s (got %s)" % [kind, player.anim.current_clip])
	raptor.queue_free()
	await physics_frame

## 4 frames of the clip, three-quarter view, side by side in one PNG.
func _sheet(rig, cam: Camera3D, clip: StringName) -> void:
	var c: Vector3 = player.rig.global_position + Vector3(0, 0.95, 0)
	var fwd: Vector3 = player.rig.mesh_root.global_basis.z.normalized()  # the survivor faces the model root's +Z
	var side: Vector3 = fwd.cross(Vector3.UP).normalized()
	cam.current = true
	cam.fov = 40.0
	cam.look_at_from_position(c + side * 3.0 + fwd * 2.0 + Vector3(0, 0.4, 0), c)
	var ap: AnimationPlayer = rig.anim_player
	var length: float = ap.get_animation(clip).length
	var tiles: Array[Image] = []
	for k in 4:
		player.anim.play_clip(clip)
		ap.seek(length * (0.1 + 0.8 * k / 3.0), true)
		ap.pause()
		await process_frame
		await RenderingServer.frame_post_draw
		tiles.append(get_root().get_texture().get_image())
	var w := tiles[0].get_width()
	var h := tiles[0].get_height()
	var sheet := Image.create(w * 4, h, false, tiles[0].get_format())
	for k in 4:
		sheet.blit_rect(tiles[k], Rect2i(0, 0, w, h), Vector2i(w * k, 0))
	DirAccess.make_dir_recursive_absolute(shots)
	sheet.save_png(shots.path_join("godot_%s.png" % clip))
	print("[t_kicktackle] wrote %s" % shots.path_join("godot_%s.png" % clip))
	ap.play()
	player.anim.play_idle()

func _finish() -> void:
	print("[t_kicktackle] %s" % ("PASS" if failures.is_empty() else "FAIL %d: %s" % [failures.size(), ", ".join(failures)]))
	quit(0 if failures.is_empty() else 1)
