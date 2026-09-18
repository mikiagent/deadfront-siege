class_name HarvestNode
extends StaticBody3D
## Click-to-gather world node. Player paths here, waits, then receives a stamped stack.

@export var node_id: StringName = &"node"
@export var required_tool_class: StringName = &"none"
@export var regen_seconds: float = 8.0
@export var gather_seconds: float = 1.2
@export var placeholder_color: Color = Color(0.45, 0.7, 0.35)
@export var pool_max: int = 0

var yield_def_id: StringName = &"fibre_stalk"
var yield_min: int = 1
var yield_max: int = 1
var yield_attributes: Dictionary = {}
var family: String = ""
var falls_to_log: bool = false

var depleted: bool = false
var pool: float = 0.0
var session_gathered: int = 0
var _mesh: MeshInstance3D
var _falling: bool = false

func setup(p_id: StringName, def_id: StringName, amin: int, amax: int, attrs: Dictionary, tool: StringName, color: Color, gather: float = 1.2, regen: float = 8.0, p_family: String = "", p_falls: bool = false, p_pool_max: int = 0) -> void:
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
	pool_max = _resolve_pool_max(p_pool_max)
	if pool <= 0.0:
		pool = float(pool_max)
	depleted = pool_units_left() <= 0
	_apply_tint()

func _ready() -> void:
	add_to_group("harvest")
	collision_layer = 1
	collision_mask = 0
	pool_max = _resolve_pool_max(pool_max)
	if pool <= 0.0:
		pool = float(pool_max)
	depleted = pool_units_left() <= 0
	if get_node_or_null("Shape") == null:
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = _collision_size()
		shape.shape = box
		shape.position.y = box.size.y * 0.5
		add_child(shape)
	if get_node_or_null("Mesh") == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		var m := BoxMesh.new()
		var c := _collision_size()
		m.size = Vector3(maxf(0.5, c.x * 0.55), c.y, maxf(0.5, c.z * 0.55))
		_mesh.mesh = m
		_mesh.position.y = c.y * 0.5
		add_child(_mesh)
	else:
		_mesh = $Mesh
	_sync_visual_state()
	_apply_tint()

func _process(delta: float) -> void:
	if regen_seconds > 0.0 and depleted and pool < float(pool_max):
		pool = minf(float(pool_max), pool + delta * (float(pool_max) / regen_seconds))
	_sync_visual_state()

func can_gather(inv: Inventory) -> String:
	if pool_units_left() <= 0:
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

func consume_unit() -> bool:
	if pool_units_left() <= 0:
		depleted = true
		return false
	pool = maxf(0.0, pool - 1.0)
	session_gathered += 1
	if pool_units_left() <= 0:
		_on_pool_empty()
	return true

func pool_units_left() -> int:
	return maxi(0, int(floor(pool + 0.0001)))

func top_of_node() -> float:
	var shape := get_node_or_null("Shape") as CollisionShape3D
	if shape and shape.shape is BoxShape3D:
		var box := shape.shape as BoxShape3D
		return shape.position.y + box.size.y * 0.5
	return 1.6

func restore_snapshot(saved_pool: float, saved_max: int, saved_session: int = 0) -> void:
	if saved_max > 0:
		pool_max = saved_max
	pool = clampf(saved_pool, 0.0, float(maxi(1, pool_max)))
	session_gathered = maxi(0, saved_session)
	_sync_visual_state()

func mark_gathered() -> void:
	consume_unit()

func _spawn_log() -> void:
	visible = false
	var log_n: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	log_n.position = global_position
	var parent := get_parent()
	if parent:
		parent.add_child(log_n)
	var attrs := yield_attributes.duplicate(true)
	log_n.setup(StringName("%s_log" % node_id), &"wood_log", 1, 2, attrs, &"none", Color(0.42, 0.28, 0.16), 1.0, 0.0, "WoodLog_Moss", false, 6)
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

func _on_pool_empty() -> void:
	depleted = true
	if falls_to_log and not _falling:
		_falling = true
		collision_layer = 0
		var tw := create_tween()
		tw.tween_property(self, "rotation_degrees:z", 88.0, 0.65)
		tw.tween_callback(_spawn_log)
		return
	if regen_seconds <= 0.0:
		visible = false
		queue_free()
		return
	visible = false
	collision_layer = 0

func _sync_visual_state() -> void:
	depleted = pool_units_left() <= 0
	if depleted:
		if regen_seconds <= 0.0:
			return
		if falls_to_log:
			# Tree trunk stays hidden while the pool rebuilds.
			if pool >= 1.0:
				rotation = Vector3.ZERO
				visible = true
				collision_layer = 1
				_falling = false
			else:
				visible = false
				collision_layer = 0
		else:
			visible = false
			collision_layer = 0
			if pool >= 1.0:
				visible = true
				collision_layer = 1
	else:
		visible = true
		collision_layer = 1

func _collision_size() -> Vector3:
	var wide := _is_tree_or_rock()
	var w := 1.4 if wide else 1.0
	return Vector3(w, 1.6, w)

func _is_tree_or_rock() -> bool:
	var role := str(Data.nature_families.get(family, {}).get("role", ""))
	return role.begins_with("tree") or role == "rock"

func _resolve_pool_max(override_max: int) -> int:
	if override_max > 0:
		return override_max
	var fam: Dictionary = Data.nature_families.get(family, {})
	var from_manifest := int(fam.get("pool", 0))
	if from_manifest > 0:
		return from_manifest
	var role := str(fam.get("role", ""))
	# ASSUMPTION: tap-to-gather defaults by family role until art data declares per-family pools.
	if role.begins_with("tree") or role == "rock":
		return 30
	if role == "bush" or role == "plant":
		return 12
	return 12
