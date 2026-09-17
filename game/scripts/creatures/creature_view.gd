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

func setup(p_def: CreatureDef, p_variant: StringName = &"") -> void:
	def = p_def
	variant = p_variant
	rotation_degrees.y = 180.0
	_tint = TINTS.get(str(def.id), Color(0.55, 0.5, 0.4))
	var glb := "res://assets/creatures/%s/%s.glb" % [def.id, def.id]
	if ResourceLoader.exists(glb):
		var inst := load(glb).instantiate() as Node3D
		inst.name = "Mesh"
		add_child(inst)
		using_glb = true
		_check_aabb(inst)
	else:
		_build_placeholder()
	_mount = Marker3D.new()
	_mount.name = "MountSocket"
	_mount.position = Vector3(0.0, def.height_meters * 0.85, 0.0)
	add_child(_mount)

func mount_socket() -> Marker3D:
	return _mount

func set_status_fx(darken: float, tint: Color, wobble: float) -> void:
	_fx_darken = darken
	_fx_tint = tint
	_wobble = wobble
	_apply_fx()

func _check_aabb(root: Node) -> void:
	var aabb := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = (mi as MeshInstance3D).get_aabb()
		var xf: Transform3D = (mi as MeshInstance3D).global_transform
		var world := AABB(xf * local.position, xf.basis * local.size)
		if first:
			aabb = world
			first = false
		else:
			aabb = aabb.merge(world)
	if first:
		return
	var h := aabb.size.y
	var tol := def.height_meters * 0.15
	if absf(h - def.height_meters) > tol:
		print("[creature] warning AABB height=%.2f def.height_meters=%.2f species=%s" % [h, def.height_meters, def.id])

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
	for mat in _base_mats:
		var c := _tint.darkened(_fx_darken)
		c = c.lerp(_fx_tint, 0.35 if _fx_tint != Color.WHITE else 0.0)
		mat.albedo_color = c
	if using_glb:
		# Placeholder-only materials; GLB tint is a child overlay later.
		pass
