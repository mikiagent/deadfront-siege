class_name HarvestNode
extends StaticBody3D
## Click-to-gather world node. Player paths here, waits, then receives a stamped stack.

@export var node_id: StringName = &"node"
@export var required_tool_class: StringName = &"none"
@export var regen_seconds: float = 8.0
@export var gather_seconds: float = 1.2
@export var placeholder_color: Color = Color(0.45, 0.7, 0.35)

var yield_def_id: StringName = &"fibre_stalk"
var yield_min: int = 1
var yield_max: int = 1
var yield_attributes: Dictionary = {}
var family: String = ""
var falls_to_log: bool = false

var depleted: bool = false
var _regen_left: float = 0.0
var _mesh: MeshInstance3D

func setup(p_id: StringName, def_id: StringName, amin: int, amax: int, attrs: Dictionary, tool: StringName, color: Color, gather: float = 1.2, regen: float = 8.0, p_family: String = "", p_falls: bool = false) -> void:
	node_id = p_id
	yield_def_id = def_id
	yield_min = amin
	yield_max = amax
	yield_attributes = attrs.duplicate(true)
	required_tool_class = tool
	placeholder_color = color
	gather_seconds = gather
	regen_seconds = regen
	family = p_family
	falls_to_log = p_falls
	_apply_tint()

func _ready() -> void:
	add_to_group("harvest")
	collision_layer = 1
	collision_mask = 0
	if get_node_or_null("Shape") == null:
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = Vector3(0.8, 1.4, 0.8)
		shape.shape = box
		shape.position.y = 0.7
		add_child(shape)
	if get_node_or_null("Mesh") == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		var m := BoxMesh.new()
		m.size = Vector3(0.5, 1.4, 0.5)
		_mesh.mesh = m
		_mesh.position.y = 0.7
		add_child(_mesh)
	else:
		_mesh = $Mesh
	_apply_tint()

func _process(delta: float) -> void:
	if depleted:
		if regen_seconds <= 0.0:
			return
		_regen_left -= delta
		if _regen_left <= 0.0:
			depleted = false
			visible = true
			rotation = Vector3.ZERO
			collision_layer = 1

func can_gather(inv: Inventory) -> String:
	if depleted:
		return "depleted"
	if not inv.has_tool_class(required_tool_class):
		return "need tool %s" % required_tool_class
	return ""

func roll_yield() -> ItemStack:
	var n := randi_range(yield_min, yield_max)
	var stack := ItemStack.make(yield_def_id, n, yield_attributes)
	if World and World.is_unstable():
		stack.set_flag(&"unstable", true)
	return stack

func mark_gathered() -> void:
	depleted = true
	_regen_left = regen_seconds
	if falls_to_log:
		collision_layer = 0
		var tw := create_tween()
		tw.tween_property(self, "rotation_degrees:z", 88.0, 0.65)
		tw.tween_callback(_spawn_log)
	elif regen_seconds <= 0.0:
		visible = false
		queue_free()
	else:
		visible = false

func _spawn_log() -> void:
	visible = false
	var log_n: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	log_n.position = global_position
	var parent := get_parent()
	if parent:
		parent.add_child(log_n)
	var attrs := yield_attributes.duplicate(true)
	log_n.setup(StringName("%s_log" % node_id), &"wood_log", 1, 2, attrs, &"none", Color(0.42, 0.28, 0.16), 1.0, 0.0, "WoodLog_Moss", false)
	var path := "res://assets/nature/WoodLog_Moss.glb"
	if ResourceLoader.exists(path):
		log_n.set_visual(path)
	# ASSUMPTION: felled tree becomes a WoodLog prop for a second harvest; tree respawns after regen.

func set_visual(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var packed := load(path)
	if packed is PackedScene:
		var inst: Node = (packed as PackedScene).instantiate()
		inst.name = "VisualGlb"
		_apply_vis_range(inst)
		add_child(inst)
		if _mesh:
			_mesh.visible = false

func _apply_vis_range(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visibility_range_end = 70.0
		(n as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for c in n.get_children():
		_apply_vis_range(c)

func _apply_tint() -> void:
	if _mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = placeholder_color
	_mesh.material_override = mat
