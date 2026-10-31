class_name TheroRoar
extends RefCounted
## THERO-ROAR (owner 2026-10-31, fighting the ceratosaurus in the fight lab: "give the T-rex adjacent dinosaurs a roar
## animation where they stand on their hind legs and roar in almost a circular motion with special effects and screen
## shake"). One shared, data-driven roar for every big theropod: any rig with a `roar` clip
## (tools/gait/make_thero_roar.py: rears up on planted feet, arms raised, the head sweeping a wide arc with the jaws
## wide, then settles) uses it, tuned by ai.json thero_roar (species rows override). No per-species code.
## Where it fires (the existing alert/roar wiring, its cooldowns kept):
##   - on aggro: CreatureBrain._spot (it acquires prey from roam) and on_aggro (hit while roaming or asleep) play it in
##     place of the alert clip, once per encounter: cooldown_s between roars of one animal;
##   - on a boss phase change: MegaRexBrain's roar (phase 2 and 3 open with it, phase 3 repeats on ROAR_COOLDOWN).
## The burst (the clip's hit_frac in anim_events): a breath ring from the jaws, a shockwave ring and dust on the ground,
## and a camera shake on the local survivor, scaled by the animal's size and her distance.
## No roar sound exists in the game yet (no audio assets on canon), so it is silent.

const CLIP := &"roar"

## For tests and the review lab: roars started, the burst count and the last burst's shake (before IsoCamera's own
## reduce-shake setting).
static var started := 0
static var bursts := 0
static var last_shake := 0.0

static func cfg(def: CreatureDef) -> Dictionary:
	var s: Variant = Data.creature_ai.get("thero_roar", {})
	var out: Dictionary = (s as Dictionary).duplicate(true) if s is Dictionary else {}
	var rows: Variant = out.get("species", {})
	out.erase("species")
	if def != null and rows is Dictionary and (rows as Dictionary).has(str(def.id)):
		out.merge((rows as Dictionary)[str(def.id)], true)
	return out

## The rig has the roar clip and the species is not opted out (thero_roar.species.<id>.enabled false).
static func has_roar(c: Creature) -> bool:
	return c != null and c.def != null and c.anim != null and c.anim.has_state(CLIP) and bool(cfg(c.def).get("enabled", true))

## Plays the roar if this animal has one and its cooldown is up; true when it started. The brain holds still for
## duration() (CreatureBrain's alert hold).
static func try_roar(c: Creature) -> bool:
	if not has_roar(c) or c.health.dead:
		return false
	var now := Time.get_ticks_msec() * 0.001
	if c.has_meta(&"thero_roar_at") and now - float(c.get_meta(&"thero_roar_at")) < float(cfg(c.def).get("cooldown_s", 30.0)):
		return false
	c.set_meta(&"thero_roar_at", now)
	started += 1
	c.stop_move()
	c.anim.play_clip(CLIP)
	var at := duration(c) * CreatureClips._hit_frac(CLIP)
	c.get_tree().create_timer(at, false, true).timeout.connect(func() -> void:
		if is_instance_valid(c) and not c.health.dead and c.anim.current_clip == CLIP:
			burst(c))
	print("[ai] %s roars (%.1fs)" % [c.def.id, duration(c)])
	return true

## The roar clip's length at the speed it plays (0 without one).
static func duration(c: Creature) -> float:
	var ap := c.anim.player
	if ap == null or not ap.has_animation(CLIP):
		return 0.0
	return ap.get_animation(CLIP).length / maxf(0.01, c.anim.cadence(CLIP))

static func height(c: Creature) -> float:
	return c.def.height_meters * c.size_scale()

## The burst: the rings and dust, and the shake on the local survivor (0 out of range).
static func burst(c: Creature) -> float:
	bursts += 1
	var h := height(c)
	fx(c.view, h, c)
	last_shake = 0.0
	var local := PlayerRegistry.local()
	if local and not local.dead:
		last_shake = shake_at(c.def, h, Vector2(local.global_position.x - c.global_position.x, local.global_position.z - c.global_position.z).length())
		if last_shake > 0.0:
			IsoCamera.shake(local, last_shake)
	return last_shake

## Shake for a survivor `dist` metres from a roaring animal `h` metres tall: the size picks between the two shake
## numbers, and it fades to nothing at shake_range_h body heights.
static func shake_at(def: CreatureDef, h: float, dist: float) -> float:
	var k := cfg(def)
	var s: Array = k.get("shake", [0.35, 0.8])
	var hr: Array = k.get("size_range_m", [4.0, 10.5])
	var size_t := clampf((h - float(hr[0])) / maxf(0.01, float(hr[1]) - float(hr[0])), 0.0, 1.0)
	var fall := clampf(1.0 - dist / maxf(0.01, float(k.get("shake_range_h", 6.0)) * h), 0.0, 1.0)
	return lerpf(float(s[0]), float(s[1]), size_t) * fall

## Visuals only (the review lab calls it on a bare CreatureView): a breath ring blown out of the jaws, a shockwave ring
## and a dust ring round the feet. Nothing on a headless run.
static func fx(view: Node3D, h: float, c: Creature) -> void:
	if view == null or not view.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var parent := view.get_parent()
	var k := cfg(c.def if c else null)
	var feet := view.global_position
	var fwd := -view.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	var mouth := feet + fwd * 0.6 * h + Vector3.UP * 0.9 * h
	var aim := fwd
	var rig: RiggedModel = (view as CreatureView).rig if view is CreatureView else null
	if rig and rig.skeleton:
		var sk := rig.skeleton
		var j := sk.find_bone("Jaw")
		var hd := CreatureView.head_bone(sk)
		if j >= 0:
			mouth = sk.global_transform * sk.get_bone_global_pose(j).origin
		if hd >= 0:  # the snout's direction: the head bone runs from the neck to the nose
			var y := (sk.global_basis * sk.get_bone_global_pose(hd).basis.y).normalized()
			aim = y if y.length_squared() > 0.5 else fwd
	var ring_r := float(k.get("ring_h", 1.6)) * h
	# the breath: a ring at the jaws, square to where the snout points, blown out along it and fading
	var breath := _ring(parent, mouth, 0.08 * h, Color(1.0, 0.96, 0.88, 0.45))
	breath.look_at(mouth + aim, Vector3.UP if absf(aim.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD)
	breath.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	_grow(breath, 0.45 * ring_r / (0.08 * h), 0.55, mouth + aim * 0.6 * h)
	# the shockwave on the ground, and the dust it raises
	var wave := _ring(parent, feet + Vector3.UP * 0.15, 0.1 * h, Color(1.0, 0.92, 0.75, 0.6))
	_grow(wave, ring_r / (0.1 * h), 0.7, wave.global_position)
	_dust(parent, feet, h, ring_r)

static func _ring(parent: Node, at: Vector3, r: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r * 0.82
	t.outer_radius = r
	t.rings = 48
	t.ring_segments = 8
	m.mesh = t
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = at
	return m

## Scales the ring out (flattening its tube so it reads as a thin wave) and fades it, then frees it.
static func _grow(m: MeshInstance3D, scale_to: float, secs: float, to: Vector3) -> void:
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(scale_to, 1.0, scale_to), secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "global_position", to, secs)
	tw.tween_property(m.material_override, "albedo_color:a", 0.0, secs).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(m.queue_free)

## Dust kicked up round the feet and out along the ground (one-shot particles, freed when done).
static func _dust(parent: Node, at: Vector3, h: float, ring_r: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 64
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.35 * h
	p.emission_ring_inner_radius = 0.15 * h
	p.emission_ring_height = 0.1
	p.direction = Vector3(1, 0.35, 0)
	p.spread = 180.0
	p.flatness = 0.7
	p.initial_velocity_min = ring_r * 0.6
	p.initial_velocity_max = ring_r * 1.1
	p.gravity = Vector3(0, -1.5, 0)
	p.damping_min = ring_r * 0.5
	p.damping_max = ring_r * 0.9
	p.scale_amount_min = 0.35 + 0.1 * h
	p.scale_amount_max = 0.7 + 0.18 * h
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.53, 0.42, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	p.global_position = at + Vector3.UP * 0.2
	p.emitting = true
	p.finished.connect(p.queue_free)
