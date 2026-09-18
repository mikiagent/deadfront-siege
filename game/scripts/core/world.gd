extends Node
## Owns the loaded island, travel, pioneer level, T-stones, and cargo waiting at home.

signal island_changed(id: StringName)
signal pioneer_changed(level: int)

var islands: Dictionary = {} ## id string -> Dictionary
var island_id: StringName = &""
var island_def: Dictionary = {}
var home_terrain: StringName = &""
var t_stones: int = 20 ## ASSUMPTION: starting T-stones
var pioneer_level: int = 0
var pioneer_crafts: Dictionary = {}
var pioneer_buildings: Dictionary = {}
var cargo_home: Inventory = Inventory.new(60) ## ASSUMPTION: 60 slots for mobile UI
var remaining_lifetime: float = 0.0
var crater_discovered: bool = false
var _sink_warned: bool = false
var harvested: Dictionary = {} ## node_id -> {depleted, regen_left}
var runtime: Node3D
var last_save_unix: int = 0
var resting_in_tent: bool = false
var _home_buildings_cache: Array = []
var _save_acc: float = 0.0
var _fade: ColorRect

const SAVE_PATH := "user://save_1.json"
const CARGO_FEE := 2 ## ASSUMPTION: T-stones to cargo-warp a bag of unstable goods
const TENT_REST_PER_MIN := 8.0 ## ASSUMPTION: fatigue drained per real minute in a tent

func _ready() -> void:
	_load_islands("res://data/islands")
	_ensure_fade()
	call_deferred("_boot")

func _process(delta: float) -> void:
	if str(island_def.get("kind", "")) == "unstable" and remaining_lifetime > 0.0:
		remaining_lifetime = maxf(0.0, remaining_lifetime - delta)
		var warn_at := float(Data.world_rules.get("sink_warning_seconds", 60))
		if remaining_lifetime <= warn_at and remaining_lifetime > 0.0 and not _sink_warned:
			_sink_warned = true
			print("[world] sink warning %.0fs" % remaining_lifetime)
		if remaining_lifetime <= 0.0:
			print("[world] island sinking — return to camp")
			recall_camp()
	_save_acc += delta
	if _save_acc >= 60.0:
		_save_acc = 0.0
		_save_now()
	var player := _player()
	if player and resting_in_tent:
		player.vitals.rest(TENT_REST_PER_MIN / 60.0 * delta)

func is_home() -> bool:
	return str(island_def.get("kind", "")) == "private"

func is_unstable() -> bool:
	return str(island_def.get("kind", "")) == "unstable"

func def_of(id: StringName) -> Dictionary:
	return islands.get(str(id), {}) as Dictionary

func _boot() -> void:
	if Game.smoke_test:
		return
	if Game.lab_name != "" and Game.lab_name != "home_lab":
		return
	if Game.lab_name == "home_lab":
		return
	var host := get_tree().current_scene
	if host == null:
		return
	if _save_exists():
		_load_now(host)
	else:
		start_new(host)

func start_new(host: Node) -> void:
	home_terrain = &""
	island_id = &"home_grassland"
	load_island(host, island_id, Vector3(0, 1, 18), true)

func load_island(host: Node, id: StringName, at: Vector3, show_terrain: bool) -> void:
	_clear_runtime()
	island_id = id
	island_def = def_of(id)
	_sink_warned = false
	if remaining_lifetime <= 0.0 and not bool(island_def.get("permanent", false)):
		remaining_lifetime = float(island_def.get("lifetime_seconds", 7200))
	var ir = (load("res://scripts/world/island_runtime.gd") as GDScript).new()
	ir.name = "IslandRuntime"
	host.add_child(ir)
	var terrain := home_terrain if is_home() and home_terrain != &"" else &"meadow"
	ir.build(island_def, terrain)
	runtime = ir
	var dp := host.get_node_or_null("DefaultPlayfield")
	if dp:
		dp.visible = false
		dp.process_mode = Node.PROCESS_MODE_DISABLED
	var player := _player()
	if player:
		if player.get_parent() != ir:
			player.reparent(ir)
		at.y = ir.surface_y(at.x, at.z) + 1.0
		player.global_position = at
		_apply_harvested(ir)
	print("[world] island %s nodes=%d creatures=%d terrain=%s" % [
		id, int(ir.harvest_count), int(ir.creature_count), terrain])
	island_changed.emit(id)
	if show_terrain and is_home() and home_terrain == &"":
		(load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(host).show_terrain()

func travel(to_id: StringName, mode: StringName) -> void:
	var dest := def_of(to_id)
	if dest.is_empty():
		print("[world] unknown island %s" % to_id)
		return
	var player := _player()
	if player == null:
		return
	if mode == &"sail":
		var cost := int(dest.get("sail_cost", 0))
		if t_stones < cost:
			print("[world] need %d T-stones" % cost)
			return
		t_stones -= cost
	if mode == &"harbour_home" or (mode == &"warp_home"):
		_strip_unstable_on_foot(player)
	var host := runtime.get_parent() if runtime else get_tree().current_scene
	var harbour: Array = dest.get("harbour", [0, 0, 12])
	var pos := Vector3(float(harbour[0]), 1.0, float(harbour[2]))
	await _fade_to(func () -> void:
		if str(island_def.get("kind", "")) == "unstable":
			_snapshot_harvest()
		load_island(host, to_id, pos, false)
		_save_now()
	)

func warp_home() -> void:
	travel(&"home_grassland", &"warp_home")

func recall_camp() -> void:
	if runtime == null or not is_unstable():
		return
	var camp: Array = island_def.get("camp", [0, 0, 8])
	var player := _player()
	if player:
		player.global_position = Vector3(float(camp[0]), 1.0, float(camp[2]))
		if runtime and runtime.has_method("surface_y"):
			player.global_position.y = runtime.surface_y(float(camp[0]), float(camp[2])) + 1.0
	print("[world] returned to camp")

func cargo_warp(player: Player) -> void:
	if not is_unstable():
		print("[world] cargo warp is at the unstable camp")
		return
	if t_stones < CARGO_FEE:
		print("[world] cargo warp needs %d T-stones" % CARGO_FEE)
		return
	var moved := 0
	for i in range(player.inventory.slot_count - 1, -1, -1):
		var s := player.inventory.slots[i]
		if s == null or not s.is_unstable():
			continue
		var taken := player.inventory.remove_at(i, s.count)
		if taken:
			taken.set_flag(&"unstable", false)
			cargo_home.add(taken)
			moved += 1
	if moved <= 0:
		print("[world] nothing unstable to warp")
		return
	t_stones -= CARGO_FEE
	print("[world] cargo warp %d stacks fee=%d" % [moved, CARGO_FEE])

func note_craft(recipe_id: StringName) -> void:
	if pioneer_crafts.has(str(recipe_id)):
		return
	pioneer_crafts[str(recipe_id)] = true
	pioneer_level += 1
	pioneer_changed.emit(pioneer_level)

func note_building(kind: StringName) -> void:
	if not is_home():
		return
	pioneer_buildings[str(kind)] = int(pioneer_buildings.get(str(kind), 0)) + 1
	pioneer_level += 1
	pioneer_changed.emit(pioneer_level)

func discover_crater() -> void:
	if crater_discovered:
		return
	crater_discovered = true
	var player := _player()
	if player:
		var drop := absf(float(Data.world_rules.get("craters", {}).get("discover_fatigue", -20)))
		player.vitals.rest(drop)
	t_stones += int(Data.world_rules.get("craters", {}).get("discover_tstones", 30))
	print("[world] crater discovered")

func _strip_unstable_on_foot(player: Player) -> void:
	var lost := 0
	for i in range(player.inventory.slot_count - 1, -1, -1):
		var s := player.inventory.slots[i]
		if s and s.is_unstable():
			player.inventory.remove_at(i, s.count)
			lost += 1
	if lost > 0:
		print("[world] unstable goods destroyed")

func _snapshot_harvest() -> void:
	harvested.clear()
	if runtime == null:
		return
	for n in runtime.get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node == null:
			continue
		harvested[str(node.node_id)] = {"depleted": node.depleted, "regen_left": node._regen_left}

func _apply_harvested(ir: Node) -> void:
	for n in ir.get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node == null:
			continue
		var row: Variant = harvested.get(str(node.node_id), null)
		if row is Dictionary:
			node.depleted = bool(row.get("depleted", false))
			node._regen_left = float(row.get("regen_left", 0.0))
			node.visible = not node.depleted

func _clear_runtime() -> void:
	if runtime and is_instance_valid(runtime):
		runtime.queue_free()
	runtime = null

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _ensure_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.name = "WorldFade"
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

func _fade_to(cb: Callable) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	cb.call()
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.25)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _save_now() -> void:
	(load("res://scripts/core/save_game.gd") as GDScript).save_now()

func _save_exists() -> bool:
	return bool((load("res://scripts/core/save_game.gd") as GDScript).exists())

func _load_now(host: Node) -> void:
	(load("res://scripts/core/save_game.gd") as GDScript).load_now(host)

func _load_islands(_dir: String) -> void:
	islands.clear()
	for key in Data.world_islands.keys():
		if key.begins_with("_"):
			continue
		var row: Variant = Data.world_islands[key]
		if row is Dictionary:
			islands[str((row as Dictionary).get("id", key))] = (row as Dictionary).duplicate(true)
	var da := DirAccess.open("res://data/islands")
	if da:
		da.list_dir_begin()
		var fname := da.get_next()
		while fname != "":
			if not da.current_is_dir() and fname.ends_with(".json"):
				var f := FileAccess.open("res://data/islands/%s" % fname, FileAccess.READ)
				if f:
					var parsed: Variant = JSON.parse_string(f.get_as_text())
					if parsed is Dictionary:
						var id := str(parsed.get("id", fname.get_basename()))
						var base: Dictionary = islands.get(id, {})
						for k in parsed:
							base[k] = parsed[k]
						islands[id] = base
			fname = da.get_next()
		da.list_dir_end()
	for id in islands.keys():
		var d: Dictionary = islands[id]
		if not d.has("kind"):
			d["kind"] = "private" if bool(d.get("permanent", false)) else "unstable"
		if not d.has("size_m"):
			var sizes: Dictionary = Data.world_rules.get("island_size_m", {})
			d["size_m"] = sizes.get("home" if d["kind"] == "private" else "unstable", 240)
		if not d.has("lifetime_seconds"):
			d["lifetime_seconds"] = float(d.get("lifetime_hours", 6)) * 3600.0
		islands[id] = d
	Game.max_creatures_per_island = int(Data.world_rules.get("creature_cap_mobile", 24))
