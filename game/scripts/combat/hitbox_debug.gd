class_name HitboxDebug
extends MeshInstance3D
## HITBOXES debug draw: every hurtbox green, each hitbox sweep red for a moment after it is judged
## (bright where it touched). On while Hitbox.debug_draw is (debug toggle, fight lab key H).

const GREEN := Color(0.2, 1.0, 0.35)
const RED := Color(1.0, 0.15, 0.1)
const HIT := Color(1.0, 0.9, 0.1)
const RING := 10

static var _inst: HitboxDebug

## Put the one drawer under the tree root when the draw turns on.
static func ensure() -> void:
	if not Hitbox.debug_draw or (_inst != null and is_instance_valid(_inst)):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_inst = HitboxDebug.new()
	_inst.name = "HitboxDebug"
	tree.root.add_child.call_deferred(_inst)

func _ready() -> void:
	top_level = true
	mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.render_priority = 3
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(_d: float) -> void:
	var im := mesh as ImmediateMesh
	im.clear_surfaces()
	visible = Hitbox.debug_draw
	if not visible:
		return
	global_transform = Transform3D.IDENTITY
	var now := Time.get_ticks_msec()
	Hitbox.recent = Hitbox.recent.filter(func(r: Array) -> bool: return int(r[0]) > now)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for body in get_tree().get_nodes_in_group(&"creatures") + get_tree().get_nodes_in_group(PlayerRegistry.GROUP):
		var hb := Hurtboxes.of(body as Node)
		if hb == null or ((body as Creature).health.dead if body is Creature else false):
			continue
		for c in hb.world_capsules():
			_capsule(im, c[0], c[1], float(c[2]), GREEN)
	for r in Hitbox.recent:
		_capsule(im, r[1], r[2], float(r[3]), HIT if r[4] else RED)
	im.surface_end()

func _capsule(im: ImmediateMesh, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var basis := Hurtboxes._basis_along(b - a)
	for end in [a, b]:
		for ax in [[basis.x, basis.z], [basis.x, basis.y], [basis.z, basis.y]]:
			for i in RING:
				var u := TAU * float(i) / RING
				var v := TAU * float(i + 1) / RING
				im.surface_set_color(col)
				im.surface_add_vertex(end + (ax[0] * cos(u) + ax[1] * sin(u)) * r)
				im.surface_set_color(col)
				im.surface_add_vertex(end + (ax[0] * cos(v) + ax[1] * sin(v)) * r)
	for side in [basis.x, -basis.x, basis.z, -basis.z]:
		im.surface_set_color(col)
		im.surface_add_vertex(a + side * r)
		im.surface_set_color(col)
		im.surface_add_vertex(b + side * r)
