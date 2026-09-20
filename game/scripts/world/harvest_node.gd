class_name HarvestNode
extends StaticBody3D
## Click-to-gather world node. Player paths here, waits, then receives a stamped stack.

signal depleted_tile(node: HarvestNode, tile: Vector2i)
signal regrown_tile(node: HarvestNode, tile: Vector2i)

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
var _batch: VegBatch
var _batch_idx: int = -1
var _tile: Vector2i = Vector2i.ZERO
var _regen_left: float = 0.0

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
	_regen_left = regen_seconds if depleted else 0.0
	_apply_tint()

func _ready() -> void:
	var runtime := get_parent()
	if runtime and runtime.has_method("surface_y"):
		_tile = BuildGrid.tile_of(global_position)
		global_position = BuildGrid.tile_centre(_tile, runtime)
	else:
		_tile = BuildGrid.tile_of(global_position)
	add_to_group("harvest")
	collision_layer = 1
	collision_mask = 0
	pool_max = _resolve_pool_max(pool_max)
	if pool <= 0.0:
		pool = float(pool_max)
	depleted = pool_units_left() <= 0
	if get_node_or_null("Shape") == null:
		# Physics: a slim trunk so paths that pass next to the node never jam on it.
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		var tap := _collision_size()
		box.size = Vector3(0.9 if _is_rock() else 0.55, tap.y, 0.9 if _is_rock() else 0.55)
		shape.shape = box
		shape.position.y = box.size.y * 0.5
		add_child(shape)
		# Tap target: the wide box, on layer 2 so it is picked by taps but never collided with.
		var zone := Area3D.new()
		zone.name = "TapZone"
		zone.collision_layer = 2
		zone.collision_mask = 0
		zone.monitoring = false
		var zs := CollisionShape3D.new()
		var zb := BoxShape3D.new()
		zb.size = tap
		zs.shape = zb
		zs.position.y = tap.y * 0.5
		zone.add_child(zs)
		add_child(zone)
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
	if not depleted or regen_seconds <= 0.0:
		return
	if _regen_left <= 0.0:
		_regen_left = regen_seconds
	_regen_left = maxf(0.0, _regen_left - delta * Game.fast_regen_mult)
	if _regen_left <= 0.0:
		pool = float(pool_max)
		depleted = false
		_sync_visual_state()
		regrown_tile.emit(self, _tile)

## Everything this node can yield, one entry per manifest `harvest` item (reference: a tree
## offers Leaf / Log / Branch at once). Tool-gated options take longer.
## ASSUMPTION: wood_log needs an axe, stone/ore/clay a pick, bark and hide a knife; the rest is bare-handed.
const OPTION_TOOLS := {"wood_log": "axe", "stone": "pick", "ore_chunk": "pick", "clay": "pick", "bark_strip": "knife", "hide": "knife"}

func options() -> Array:
	var out: Array = []
	var fam: Dictionary = Data.nature_families.get(family, {})
	var harvest: Variant = fam.get("harvest", {})
	if harvest is Dictionary and not (harvest as Dictionary).is_empty():
		for k in harvest.keys():
			var id := StringName(str(k))
			if Data.item(id) == null:
				continue
			var pair: Variant = harvest[k]
			var amin := 1
			var amax := 1
			if pair is Array and (pair as Array).size() >= 2:
				amin = maxi(1, int(pair[0]))
				amax = maxi(amin, int(pair[1]))
			var tool := str(OPTION_TOOLS.get(str(k), "none"))
			out.append({"item": str(id), "min": amin, "max": amax, "tool": tool, "seconds": 3.0 if tool != "none" else 1.8})
	if out.is_empty():
		out.append({"item": str(yield_def_id), "min": yield_min, "max": yield_max, "tool": str(required_tool_class), "seconds": gather_seconds})
	return out

## Make one of options() the active yield for the next gathers.
func select_option(index: int) -> void:
	var opts := options()
	if opts.is_empty():
		return
	var o: Dictionary = opts[clampi(index, 0, opts.size() - 1)]
	yield_def_id = StringName(str(o["item"]))
	yield_min = int(o["min"])
	yield_max = int(o["max"])
	required_tool_class = StringName(str(o["tool"]))
	gather_seconds = float(o["seconds"])

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

func restore_snapshot(saved_pool: float, saved_max: int, saved_session: int = 0, saved_regen_left: float = -1.0) -> void:
	if saved_max > 0:
		pool_max = saved_max
	pool = clampf(saved_pool, 0.0, float(maxi(1, pool_max)))
	session_gathered = maxi(0, saved_session)
	depleted = pool_units_left() <= 0
	if saved_regen_left >= 0.0:
		_regen_left = saved_regen_left
	else:
		_regen_left = regen_seconds if depleted else 0.0
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

## Visual lives in a shared MultiMesh (VegBatch); this node only toggles its instance.
func set_batched_visual(batch: VegBatch, idx: int) -> void:
	_batch = batch
	_batch_idx = idx
	if _mesh:
		_mesh.visible = false
	_apply_batch()

func _set_tap_zone(on: bool) -> void:
	var z := get_node_or_null("TapZone") as Area3D
	if z:
		z.collision_layer = 2 if on else 0

func _apply_batch() -> void:
	if _batch:
		_batch.set_shown(_batch_idx, visible and not depleted)
	_set_tap_zone(visible and not depleted)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply_batch()

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
		(n as GeometryInstance3D).visibility_range_end = 30.0
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
	_regen_left = regen_seconds
	depleted_tile.emit(self, _tile)
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
		visible = false
		collision_layer = 0
		return
	if falls_to_log:
		rotation = Vector3.ZERO
		_falling = false
	visible = true
	collision_layer = 1

func regen_left() -> float:
	return _regen_left

func _collision_size() -> Vector3:
	var wide := _is_tree_or_rock()
	var w := 1.4 if wide else 1.0
	return Vector3(w, 1.6, w)

func _is_rock() -> bool:
	return str(Data.nature_families.get(family, {}).get("role", "")) == "rock"

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
