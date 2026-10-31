class_name CritSpotMarks
extends Node3D
## WEAK SPOTS: a faint gold glow on each of one animal's crit spots, shown through its body, so a player who found
## one learns where the rest are. CritSpots.land attaches it after that animal's first weak-spot hit. No hover:
## it is on for the rest of the animal's life (ASSUMPTION CS5), and a phone reads it at fight distance.

const NAME := &"CritSpotMarks"
const COLOR := Color(1.0, 0.82, 0.2)
const PULSE_HZ := 1.2
const ALPHA := Vector2(0.18, 0.42)  ## pulse range: subtle, never a solid ball

var body: Creature
var _balls: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _t := 0.0

static func attach(c: Creature) -> CritSpotMarks:
	var m := c.get_node_or_null(NodePath(NAME)) as CritSpotMarks
	if m:
		return m
	m = CritSpotMarks.new()
	m.name = NAME
	m.body = c
	c.add_child(m)
	return m

func _ready() -> void:
	top_level = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.no_depth_test = true  # the spots sit inside the body
	_mat.albedo_color = COLOR
	_mat.render_priority = 2

func _process(delta: float) -> void:
	if body == null or not is_instance_valid(body) or body.health.dead:
		queue_free()
		return
	_t += delta
	_mat.albedo_color.a = lerpf(ALPHA.x, ALPHA.y, 0.5 + 0.5 * sin(TAU * PULSE_HZ * _t))
	var spots := CritSpots.world(body)
	while _balls.size() < spots.size():
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radial_segments = 16
		sm.rings = 8
		mi.mesh = sm
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_balls.append(mi)
	for i in _balls.size():
		var on := i < spots.size()
		_balls[i].visible = on
		if on:
			var r := float(spots[i]["radius"])
			_balls[i].global_transform = Transform3D(Basis.from_scale(Vector3.ONE * r * 2.0), spots[i]["centre"])

## The spots it draws now (tests).
func shown() -> int:
	var n := 0
	for b in _balls:
		n += 1 if b.visible else 0
	return n
