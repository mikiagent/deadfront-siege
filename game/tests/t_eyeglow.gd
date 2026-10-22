extends SceneTree
## EYEGLOW acceptance: glowing eyes on the six predators (spec 27, "Glowing eyes").
## For each: the Eyes node hangs off a BoneAttachment3D on the Head bone with two dots; the shared
## eye material is at least 5x brighter at night 1.0 than at night 0.0; while a walk clip plays for
## 2 s each dot stays within 1 mm of the head bone; a dead creature hides its eyes; and a species
## without an "eyes" block (zebraceratops) has none.
## Run: Godot --headless --path game --script res://tests/t_eyeglow.gd -> "[t_eyeglow] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const SPECIES: Array[StringName] = [&"tyrannosaurus", &"utahraptor", &"deinonychus",
	&"velociraptor", &"coelophysis", &"compsognathus"]
const PLAIN: Array[StringName] = [&"zebraceratops"]
const DRIFT_LIMIT_M := 0.001

var _fails: PackedStringArray = []
var _started := false
var EYES: GDScript
var DD: Node
var WL: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_eyeglow] FAIL %s" % what)

func _spawn(id: StringName) -> Node:
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	root.add_child(c)
	c.spawn(DD.creature(id))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.anim.set_physics_process(false)
	return c

func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("[t_eyeglow] FAIL watchdog")
		quit(1))
	DD = root.get_node("Data")
	WL = load("res://scripts/world/world_lighting.gd")
	EYES = load("res://scripts/creatures/creature_eyes.gd")
	_expect(EYES != null, "creature_eyes.gd loads")
	if EYES == null:
		_finish()
		return
	_test_night_static()
	for id in SPECIES:
		await _test_species(id)
	await _test_plain()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_eyeglow] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_eyeglow] FAIL %s" % f)
		quit(1)

## WL.night is the one number the glow reads; drive() writes it every call.
func _test_night_static() -> void:
	var had: float = WL.night
	EYES.material_for(Color.WHITE)  # the shared table fills on first use
	WL.night = 0.0
	EYES.apply_night()
	var day: float = _energy()
	WL.night = 1.0
	EYES.apply_night()
	var night: float = _energy()
	_expect(day > 0.0, "a faint day glint stays on (level %.2f at night 0)" % day)
	_expect(night >= day * 5.0, "night 1.0 is at least 5x the day glint (%.2f vs %.2f)" % [night, day])
	WL.night = had

## Brightest shared eye material, whatever colour it is.
func _energy() -> float:
	var best := 0.0
	for key in EYES._materials:
		var m: StandardMaterial3D = EYES._materials[key]
		best = maxf(best, _material_brightness(m))
	return best

## How bright the dot draws: its emission colour times the energy multiplier.
func _material_brightness(m: StandardMaterial3D) -> float:
	if m == null or not m.emission_enabled:
		return 0.0
	var c := m.emission
	return maxf(c.r, maxf(c.g, c.b)) * m.emission_energy_multiplier

func _test_species(id: StringName) -> void:
	var block: Dictionary = (load("res://scripts/creatures/creature_view.gd") as GDScript).eyes_block(id)
	_expect(not block.is_empty() and block.get("bone") != null, "%s has an eyes block in its JSON" % id)
	if block.is_empty():
		return
	var c = _spawn(id)
	await process_frame
	await process_frame
	var eyes = c.view.get_node_or_null("Eyes")
	_expect(eyes != null, "%s has the Eyes node" % id)
	if eyes == null:
		c.queue_free()
		return
	var att: BoneAttachment3D = eyes.attachment
	_expect(att is BoneAttachment3D, "%s eyes sit under a BoneAttachment3D" % id)
	if att is BoneAttachment3D:
		_expect(att.bone_name == "Head", "%s attachment is on the Head bone (not %s)" % [id, att.bone_name])
		_expect(att.get_parent() is Skeleton3D, "%s attachment is parented to the Skeleton3D" % id)
	_expect(eyes.dots.size() == 2, "%s has two dots (got %d)" % [id, eyes.dots.size()])
	# Brightness in the frames the eye material actually uses.
	WL.night = 0.0
	EYES.apply_night()
	var day_e: float = _material_brightness(eyes.eye_material)
	WL.night = 1.0
	EYES.apply_night()
	var night_e: float = _material_brightness(eyes.eye_material)
	_expect(night_e >= day_e * 5.0, "%s eye material fireflies at night (%.2f vs day %.2f)" % [id, night_e, day_e])
	_expect(eyes.eye_material != null and eyes.eye_material.emission_enabled, "%s eye material is emissive" % id)
	# While a walk plays, every dot stays glued to the head bone: its place in the Head bone's own
	# space must not move as the clip animates it.
	var ap: AnimationPlayer = c.view.animation_player()
	_expect(ap != null and ap.has_animation(&"walk"), "%s has a walk clip" % id)
	if ap != null:
		var sk: Skeleton3D = c.view.rig.skeleton
		var bi := sk.find_bone("Head")
		var at_rest: Array[Vector3] = []
		var rest_inv := (sk.global_transform * sk.get_bone_global_pose(bi)).affine_inverse()
		for dot in eyes.dots:
			at_rest.append(rest_inv * (dot as Node3D).global_position)
		ap.play(&"walk")
		var worst := 0.0
		var frames := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2000:
			await process_frame
			frames += 1
			if frames % 4 != 0:
				continue
			var bone_inv := (sk.global_transform * sk.get_bone_global_pose(bi)).affine_inverse()
			for k in eyes.dots.size():
				var local := bone_inv * (eyes.dots[k] as Node3D).global_position
				worst = maxf(worst, local.distance_to(at_rest[k]))
		_expect(worst <= DRIFT_LIMIT_M, "%s dots stay within 1 mm of the head bone over 2 s of walk (%.5f m)" % [id, worst])
		_expect(frames > 50, "%s walk ran for 2 s (%d frames)" % [id, frames])
	# Dead: the dots go hidden.
	c.health.dead = true
	await process_frame
	await process_frame
	_expect(eyes.attachment != null and not eyes.attachment.visible, "%s hides its eyes when dead" % id)
	c.queue_free()
	await process_frame

func _test_plain() -> void:
	for id in PLAIN:
		var block: Dictionary = (load("res://scripts/creatures/creature_view.gd") as GDScript).eyes_block(id)
		_expect(block.is_empty(), "%s has no eyes block" % id)
		var c = _spawn(id)
		await process_frame
		await process_frame
		_expect(c.view.get_node_or_null("Eyes") == null, "%s has no Eyes node" % id)
		c.queue_free()
		await process_frame
