extends SceneTree
## THERO-ROAR: the big theropods' shared rearing roar.
##  - every species in SPECIES loads a roar clip; sampled in the engine at game scale, its feet stay within 5 cm of their
##    prints the whole clip, the head's heading sweeps >= 180 deg, the hips rise and the jaw opens;
##  - a ceratosaurus that spots the survivor roars (the roar clip, held in alert for the clip's length, the body not
##    sliding), fires the burst at the clip's hit_frac with a camera shake on her, and does not roar again on the next
##    encounter inside cooldown_s; a roaming one hit by her roars too;
##  - the shake falls off with distance and with size, to 0 out of range;
##  - MegaRex: a phase change opens with the roar (roar clip as the windup), and its impact fires the burst.
## Run: Godot --headless --path game --script res://tests/t_theroroar.gd  -> "[t_theroroar] PASS", exit 0.

const SPECIES: Array[StringName] = [&"ceratosaurus", &"tyrannosaurus", &"megarex", &"allosaurus", &"majungasaurus", &"tarbosaurus"]
const FEET := ["Metatarsal.L", "Metatarsal.R", "Toe.L", "Toe.R"]
const FOOT_TOL := 0.05
const STEPS := 48

var failures: Array[String] = []
var _started := false
var data: Node
var TR: GDScript  ## TheroRoar, CreatureClips, CreatureView: loaded at run time (class names need the autoloads first)
var CC: GDScript
var CV: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	TR = load("res://scripts/combat/thero_roar.gd")
	CC = load("res://scripts/creatures/creature_clips.gd")
	CV = load("res://scripts/creatures/creature_view.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_theroroar] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	for id in SPECIES:
		_test_clip(id)
	_test_shake_falloff()
	await _test_aggro()
	await _test_megarex_phase()
	if failures.is_empty():
		print("[t_theroroar] PASS")
		quit(0)
	else:
		print("[t_theroroar] FAIL %d" % failures.size())
		quit(1)

func _pos(sk: Skeleton3D, b: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin

func _test_clip(id: StringName) -> void:
	var def = data.creature(id)
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	if view.rig == null:
		_expect(false, "%s draws its rig" % id)
		view.free()
		return
	var ap: AnimationPlayer = view.rig.anim_player
	_expect(ap.has_animation(&"roar"), "%s has the roar clip" % id)
	if not ap.has_animation(&"roar"):
		view.free()
		return
	var sk: Skeleton3D = view.rig.skeleton
	var length := ap.get_animation(&"roar").length
	var start := {}
	var drift := 0.0
	var headings: Array[float] = []
	var hip0 := 0.0
	var rise := 0.0
	var gape := 0.0
	var head_i := sk.find_bone("Head")
	var jaw_i := sk.find_bone("Jaw")
	for i in STEPS + 1:
		sk.reset_bone_poses()
		ap.play(&"roar")
		ap.seek(length * i / STEPS, true)
		ap.pause()
		for f in FEET:
			var p := _pos(sk, f)
			if i == 0:
				start[f] = p
			drift = maxf(drift, p.distance_to(start[f]))
		var hb := sk.get_bone_global_pose(head_i).basis
		var y := (sk.global_basis * hb.y)
		headings.append(atan2(y.x, y.z))
		var hip := _pos(sk, "Hips").y
		if i == 0:
			hip0 = hip
		rise = maxf(rise, hip - hip0)
		gape = maxf(gape, rad_to_deg(hb.y.angle_to(sk.get_bone_global_pose(jaw_i).basis.y)))
	# unwrap the heading and take its range
	var lo := 0.0
	var hi := 0.0
	var acc := 0.0
	for i in range(1, headings.size()):
		acc += wrapf(headings[i] - headings[i - 1], -PI, PI)
		lo = minf(lo, acc)
		hi = maxf(hi, acc)
	var sweep := rad_to_deg(hi - lo)
	_expect(drift <= FOOT_TOL, "%s roar: feet stay planted (worst %.3f m, limit %.2f)" % [id, drift, FOOT_TOL])
	_expect(sweep >= 180.0, "%s roar: the head sweeps %.0f deg (>= 180)" % [id, sweep])
	_expect(rise > 0.0, "%s roar: it rears up (hips +%.2f m)" % [id, rise])
	_expect(gape >= 25.0, "%s roar: the jaw opens wide (%.0f deg between head and jaw)" % [id, gape])
	if id == SPECIES[0]:
		_expect(absf(CC._hit_frac(&"roar") - 0.34) < 0.001, "the roar's burst is at hit_frac 0.34")
	view.free()

func _test_shake_falloff() -> void:
	var def = data.creature(&"ceratosaurus")
	var big = data.creature(&"megarex")
	var near: float = TR.shake_at(def, 4.0, 3.0)
	var far: float = TR.shake_at(def, 4.0, 15.0)
	var out: float = TR.shake_at(def, 4.0, 40.0)
	_expect(near > far and far > 0.0 and out == 0.0, "shake fades with distance (%.2f at 3 m, %.2f at 15 m, %.2f at 40 m)" % [near, far, out])
	_expect(TR.shake_at(big, 10.4, 3.0) > near, "a bigger roarer shakes harder (megarex %.2f vs %.2f)" % [TR.shake_at(big, 10.4, 3.0), near])

func _arena() -> Array:
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	return [host, player]

func _spawn(host: Node3D, id: StringName, at: Vector3) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

func _test_aggro() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _spawn(host, &"ceratosaurus", Vector3(0, 0.1, -12.0))
	for _f in 5:
		await physics_frame
	var b = c.brain
	var bursts0: int = TR.bursts
	TR.last_shake = 0.0
	# (it may have spotted her by itself in the frames above; start this encounter fresh)
	c.remove_meta(&"thero_roar_at")
	c.anim.play_clip(&"idle")
	b._set_state(&"roam")
	b._spot(player)
	_expect(c.anim.current_clip == &"roar", "spotting her, the ceratosaurus roars (clip %s)" % c.anim.current_clip)
	var dur: float = TR.duration(c)
	_expect(b.state == &"alert" and b._alert_left >= dur - 0.05, "it holds in alert for the roar (%.2f s of %.2f)" % [b._alert_left, dur])
	var p0: Vector3 = c.global_position
	var shook := 0.0
	var t := 0.0
	while t < dur * CC._hit_frac(&"roar") + 0.3:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		shook = maxf(shook, TR.last_shake)
	_expect(TR.bursts > bursts0, "the burst fires at the roar's hit frame")
	_expect(shook > 0.0, "the burst shakes her camera (%.2f, 12 m away)" % shook)
	_expect(Vector2(c.global_position.x - p0.x, c.global_position.z - p0.z).length() < 0.1, "it roars in place (moved %.3f m)" % Vector2(c.global_position.x - p0.x, c.global_position.z - p0.z).length())
	# the next encounter inside cooldown_s: no second roar
	b._set_state(&"roam")
	c.anim.play_clip(&"idle")
	var started: int = TR.started
	b._spot(player)
	_expect(TR.started == started and c.anim.current_clip != &"roar", "once per encounter: no second roar inside the cooldown")
	# a roaming one hit by her answers with the roar
	var c2 = _spawn(host, &"allosaurus", Vector3(14, 0.1, -6.0))
	for _f in 5:
		await physics_frame
	c2.brain._set_state(&"roam")
	c2.brain.on_aggro(player)
	_expect(c2.anim.current_clip == &"roar", "an allosaurus hit while roaming roars (clip %s)" % c2.anim.current_clip)
	host.free()

func _test_megarex_phase() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _spawn(host, &"megarex", Vector3(0, 0.1, -10.0))
	for _f in 5:
		await physics_frame
	var b = c.brain
	var is_mr: bool = b != null and str(b.get_script().resource_path).ends_with("mega_rex_brain.gd")
	_expect(is_mr, "the megarex runs MegaRexBrain")
	if not is_mr:
		host.free()
		return
	b.attack_target = player
	b.locked_target = player
	c.health.hp = c.health.max_hp * 0.6
	b._update_phase()
	_expect(b.boss_phase == 2 and b.phase_roar, "phase 2 queues the roar")
	_expect(b._special_attack(Vector3(0, 0, 10)), "the next attack is the phase roar")
	_expect(b.windup_clip == &"roar" and c.anim.current_clip == &"roar", "it rears and roars (windup %s, clip %s)" % [b.windup_clip, c.anim.current_clip])
	var bursts0: int = TR.bursts
	b._impact()
	_expect(TR.bursts == bursts0 + 1 and TR.last_shake > 0.0, "the roar's impact fires the burst and shakes her (%.2f)" % TR.last_shake)
	_expect(not b._special_attack(Vector3(0, 0, 10)), "in phase 2 it does not roar again until the next phase")
	host.free()
