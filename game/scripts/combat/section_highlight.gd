class_name SectionHighlight
extends Node3D
## PARTCOMBAT: the body section the player picked, shown on the animal: a soft cyan glow over that section's hurtbox
## capsules (seen through the body), following the live pose. One per animal; show_on(c, &"") clears it.

const NAME := &"SectionHighlight"
const COLOR := Color(0.35, 0.9, 1.0, 0.28)

var creature: Creature
var section: StringName = &""
var _meshes: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D

static func show_on(c: Creature, sec: StringName) -> void:
	if c == null or not is_instance_valid(c):
		return
	var h := c.get_node_or_null(NodePath(NAME)) as SectionHighlight
	if sec == &"":
		if h:
			h.queue_free()
		return
	if h == null:
		h = SectionHighlight.new()
		h.name = NAME
		h.creature = c
		c.add_child(h)
	h.section = sec
	h._rebuild()

static func current(c: Creature) -> StringName:
	var h := c.get_node_or_null(NodePath(NAME)) as SectionHighlight if c and is_instance_valid(c) else null
	return h.section if h else &""

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = COLOR
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_mat.render_priority = 2

func _rebuild() -> void:
	for m in _meshes:
		m.queue_free()
	_meshes.clear()
	if creature == null:
		return
	if BodySections.is_split(creature, section):
		# A split (belly, frill, plates) shares its parent's capsule: a glow ball on its own side of it.
		var ball := MeshInstance3D.new()
		ball.mesh = SphereMesh.new()
		ball.material_override = _mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)
		_meshes.append(ball)
		_process(0.0)
		return
	for cap in BodySections.caps_of(creature, section):
		var mi := MeshInstance3D.new()
		mi.mesh = CapsuleMesh.new()
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta(&"cap", cap)
		add_child(mi)
		_meshes.append(mi)
	_process(0.0)

func _process(_d: float) -> void:
	if creature == null or not is_instance_valid(creature) or creature.health.dead:
		queue_free()
		return
	var hb := Hurtboxes.of(creature)
	if hb:
		hb.sync()
	for mi in _meshes:
		if not mi.has_meta(&"cap"):
			var big := 0.3
			for cap in BodySections.caps_of(creature, section):
				big = maxf(big, float(cap["wr"]))
			(mi.mesh as SphereMesh).radius = big * 0.6
			(mi.mesh as SphereMesh).height = big * 1.2
			mi.global_transform = Transform3D(Basis.IDENTITY, BodySections.aim_point(creature, section, false))
			continue
		var cap: Dictionary = mi.get_meta(&"cap")
		var a: Vector3 = cap["wa"]
		var b: Vector3 = cap["wb"]
		var r := float(cap["wr"]) * 1.04
		var cm := mi.mesh as CapsuleMesh
		cm.radius = r
		cm.height = a.distance_to(b) + 2.0 * r
		mi.global_transform = Transform3D(Hurtboxes._basis_along(b - a), (a + b) * 0.5)
