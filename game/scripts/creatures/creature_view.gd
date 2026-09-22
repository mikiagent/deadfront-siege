class_name CreatureView
extends Node3D
## Wraps the mesh. SCHEMA §3: Meshy faces +Z, Godot forward is -Z, so this node is yawed 180°.

const TINTS := {
	"velociraptor": Color(0.76, 0.58, 0.32),
	"deinonychus": Color(0.42, 0.55, 0.28),
	"utahraptor": Color(0.62, 0.32, 0.18),
	"protoceratops": Color(0.72, 0.64, 0.42),
}

var pose_kind: StringName = &"idle":
	set(v):
		pose_kind = v
		_apply_pose()
var pose_t: float = 0.0:
	set(v):
		pose_t = v
		_apply_pose()

var def: CreatureDef
var variant: StringName = &""
var using_glb: bool = false
var rig: RiggedModel
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _tint: Color = Color.WHITE
var _base_mats: Array[StandardMaterial3D] = []
var _fx_darken: float = 0.0
var _fx_tint: Color = Color.WHITE
var _wobble: float = 0.0
var _mount: Marker3D
var _hit_flash_left: float = 0.0
var _flinch_tw: Tween

## Procedural hurt: a quick shove back and a nod, then settle. Used instead of the synthesised
## hit_react clip ("death 0-35 % reversed") that made transplanted species start collapsing on
## every hit. Works on the rig node (GLB) or the placeholder body.
func flinch(strength: float = 1.0) -> void:
	var node: Node3D = rig if (using_glb and rig) else _body
	if node == null or def == null:
		return
	if _flinch_tw and _flinch_tw.is_valid():
		_flinch_tw.kill()
	var back := clampf(def.real_length_m * 0.07, 0.05, 0.35) * strength
	_flinch_tw = create_tween()
	_flinch_tw.tween_property(node, "position:z", back, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flinch_tw.parallel().tween_property(node, "rotation:x", -0.16 * strength, 0.07)
	_flinch_tw.tween_property(node, "position:z", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flinch_tw.parallel().tween_property(node, "rotation:x", 0.0, 0.2)

func setup(p_def: CreatureDef, p_variant: StringName = &"") -> void:
	def = p_def
	variant = p_variant
	using_glb = false
	_tint = TINTS.get(str(def.id), Color(0.55, 0.5, 0.4))
	var glb := "res://assets/creatures/%s/%s.glb" % [def.id, def.id]
	# The current transplanted Stegosaurus skin has catastrophic weights (worm-like stretching).
	# Keep it playable with the procedural quadruped until the asset-upgrade replacement lands.
	var force_safe_placeholder := def.id == &"stegosaurus"
	if ResourceLoader.exists(glb) and not force_safe_placeholder:
		rotation = Vector3.ZERO
		rig = RiggedModel.new()
		rig.name = "Rig"
		add_child(rig)
		var anim_dir := "res://assets/creatures/%s/anim" % def.id
		var axis := str(def.pipeline.get("forward_axis", "-Z"))
		if rig.setup(glb, anim_dir, axis, def.height_meters, "creature", false, float(def.pipeline.get("source_height_m", 0.0))):
			using_glb = true
			rig.fill_missing(CreatureClips.CONTRACT)
		else:
			rig.queue_free()
			rig = null
			rotation_degrees.y = 180.0
			_build_placeholder()
	else:
		# Placeholder nose sits at +Z; yaw the view so it still faces Godot -Z like before.
		rotation_degrees.y = 180.0
		_build_placeholder()
	_mount = Marker3D.new()
	_mount.name = "MountSocket"
	if using_glb and rig and rig.hips_socket:
		rig.hips_socket.add_child(_mount)
		_mount.position = Vector3(0.0, def.height_meters * 0.08, 0.05)
	else:
		_mount.position = Vector3(0.0, def.height_meters * 0.85, 0.0)
		add_child(_mount)

func animation_player() -> AnimationPlayer:
	if using_glb and rig:
		return rig.anim_player
	return null

func mount_socket() -> Marker3D:
	return _mount

func set_status_fx(darken: float, tint: Color, wobble: float) -> void:
	_fx_darken = darken
	_fx_tint = tint
	_wobble = wobble
	_apply_fx()

func flash_damage(seconds: float = 0.1) -> void:
	_hit_flash_left = maxf(_hit_flash_left, seconds)
	_apply_fx()

func _build_placeholder() -> void:
	var h := def.height_meters
	var L := def.real_length_m
	_body = _box(Vector3(h * 0.28, h * 0.32, L * 0.42), Vector3(0, h * 0.42, 0), _tint)
	_head = _box(Vector3(h * 0.22, h * 0.22, h * 0.32), Vector3(0, h * 0.62, L * 0.28), _tint.lightened(0.1))
	_tail = _box(Vector3(h * 0.08, h * 0.08, L * 0.45), Vector3(0, h * 0.48, -L * 0.32), _tint.darkened(0.15))
	_leg_l = _cyl(h * 0.05, h * 0.42, Vector3(-h * 0.1, h * 0.2, 0.05), _tint.darkened(0.2))
	_leg_r = _cyl(h * 0.05, h * 0.42, Vector3(h * 0.1, h * 0.2, 0.05), _tint.darkened(0.2))
	_body.name = "Body"

func _box(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	_base_mats.append(mat)
	add_child(mi)
	return mi

func _cyl(r: float, h: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	_base_mats.append(mat)
	add_child(mi)
	return mi

func _apply_pose() -> void:
	if using_glb or _body == null:
		if using_glb and rig:
			rig.rotation.z = sin(Time.get_ticks_msec() * 0.01) * _wobble * 0.15
		else:
			rotation.z = sin(Time.get_ticks_msec() * 0.01) * _wobble * 0.15
		return
	var t := pose_t
	var bob := sin(t * TAU) * 0.03
	match pose_kind:
		&"idle":
			_body.position.y = def.height_meters * 0.42 + bob
			_head.rotation.x = bob * 2.0
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = 0.0
		&"walk", &"run":
			var amp := 0.55 if pose_kind == &"run" else 0.35
			_leg_l.rotation.x = sin(t * TAU) * amp
			_leg_r.rotation.x = sin(t * TAU + PI) * amp
			_body.position.y = def.height_meters * 0.42 + absf(sin(t * TAU)) * 0.04
		&"attack_primary":
			_body.position.z = sin(t * PI) * 0.35
			_head.rotation.x = -t * 0.4
		&"attack_heavy":
			var lunge := 0.0 if t < 0.45 else sin((t - 0.45) / 0.55 * PI) * 0.8
			_body.position.z = lunge
			_body.rotation.x = -lunge * 0.4
		&"hit_react":
			_body.position.z = -sin(t * PI) * 0.2
		&"knockdown":
			rotation.z = lerpf(0.0, -PI * 0.5, clampf(t * 1.4, 0.0, 1.0))
		&"death":
			rotation.z = lerpf(0.0, PI * 0.5, clampf(t, 0.0, 1.0))
			_body.position.y = def.height_meters * 0.2
		&"alert":
			_head.position.y = def.height_meters * 0.62 + sin(t * PI) * 0.15
		&"feed":
			_head.rotation.x = 0.6
	rotation.z += sin(Time.get_ticks_msec() * 0.012) * _wobble * 0.12

func _apply_fx() -> void:
	if _hit_flash_left > 0.0:
		_hit_flash_left = maxf(0.0, _hit_flash_left - get_process_delta_time())
	for mat in _base_mats:
		var c := _tint.darkened(_fx_darken)
		c = c.lerp(_fx_tint, 0.35 if _fx_tint != Color.WHITE else 0.0)
		if _hit_flash_left > 0.0:
			c = c.lerp(Color(1.0, 0.2, 0.2), 0.65)
		mat.albedo_color = c
	if using_glb:
		# Placeholder-only materials; GLB tint is a child overlay later.
		pass
