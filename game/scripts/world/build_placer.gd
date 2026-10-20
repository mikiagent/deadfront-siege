class_name BuildPlacer
extends Node
## Grid-snap placement flow used by inventory and crafting, and the modular-building API:
##   begin_piece(kind, tier)  select a piece (foundation, wall, doorway, door, window, ceiling, roof,
##                            roof_peak, pillar, stairs, ramp) in a tier; the ghost snaps to the
##                            nearest free socket around the pointer (or aim_at()) with green/red
##                            snap points; rotate_clockwise(), confirm(player) and cancel() as for kits
##   upgrade(target, tier, player) / repair(target, player) / demolish(target, player) -> bool
## StructurePlacer does the snapping and the costs; structures.json holds every number.

const GRID_HALF_SPAN := 4

var placing: StringName = &""
## Layout mode (BUILD > Move buildings): tap a building to pick it up, tap tiles to move the
## ghost, ✓ drops it, ✕ puts it back, DONE saves. Tiles glow blue when valid, red when not.
var layout_mode: bool = false
var moving: Node3D
var dragging: bool = false
var _press_t: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _drag_world_offset: Vector3 = Vector3.ZERO
var _moving_cell: Vector2i = Vector2i.ZERO
var _moving_rot: int = 0
var valid: bool = false
var reason: String = ""
var cell: Vector2i = Vector2i.ZERO
var rot_step: int = 0
var _rot_manual: bool = false  # once the player rotates, fence/gate auto-alignment stops overriding it
var _repacked: bool = false  # the kit just paid for came from pack-up: place it without XP
var piece_tier: StringName = &"thatch"
var piece_at: Dictionary = {}  # the last StructurePlacer.snap() result while placing a piece
var _aim: Vector3 = Vector3.ZERO
var _aim_locked: bool = false  # aim_at() pins the aim (labs, tests); the pointer ray drives it otherwise
var _snap_points: MeshInstance3D
var _snap_key: Array = []

var _ghost_root: Node3D
var _ghost_visual: Node3D
var _ghost_grid: MeshInstance3D
var _ghost_cells: MeshInstance3D
var _ghost_label: Label3D

var _last_sync := [Vector2i(999999, 999999), -1, ""]  # cell, rot, placing: overlay rebuilt only on change
var _ghost_mat_valid: bool = false  # material currently on the ghost visual
var _ghost_mat_fresh: bool = false  # false until the first tint after a visual rebuild
var _last_label: String = ""
var _blocked_cache: Dictionary = {}  # Vector2i -> bool: nature-blocked is static for an island
var _blocked_cache_runtime: Node = null
var _mat_valid: StandardMaterial3D
var _mat_invalid: StandardMaterial3D
var _grid_mat: StandardMaterial3D
var _cell_mat: StandardMaterial3D  # vertex-coloured: one mesh draws every overlay quad

static var _kit_by_kind: Dictionary = {}  # place_as -> kit item id, built once from items.json

## The bag item that places (and packs back into) this kind: the item whose place_as names it.
static func kit_for(kind: StringName) -> StringName:
	if _kit_by_kind.is_empty():
		for id in Data.items:
			var def: ItemDef = Data.items[id]
			if def and def.place_as != &"" and not _kit_by_kind.has(def.place_as):
				_kit_by_kind[def.place_as] = StringName(id)
	return _kit_by_kind.get(kind, &"")

func _kit_id(kind: StringName) -> String:
	return str(kit_for(kind))

## Player-facing text for a can_place() code; the ghost and notices never show raw codes.
static func reason_text(code: String) -> String:
	match code:
		"too_far":
			return "Too far away"
		"reserved":
			return "Reserved for the camp"
		"overlap":
			return "Spot is taken"
		"unclaimed":
			return "Outside your claim"
		"water":
			return "Can't build on water"
		"slope":
			return "Ground too steep"
		"missing_kit":
			return "No kit in your bag"
		"occupied":
			return "Socket is taken"
		"no_support", "no_socket":
			return "Needs a foundation, wall or pillar to snap to"
		"stairwell":
			return "Needs open headroom"
		"max_level":
			return "Too high to build"
		"resource":
			return "A tree or rock is in the way"
		"floor_edge":
			return "Must stand fully on the floor"
		"missing_materials":
			return "Not enough materials"
		"locked":
			return "Needs a higher Construction level"
		"not_higher":
			return "Already this tier or better"
		"undamaged":
			return "Not damaged"
		"not_yours":
			return "Not yours"
		"no_runtime", "spawn_failed":
			return "Can't build here"
		"":
			return ""
		_:
			return code.replace("_", " ").capitalize()

func _ready() -> void:
	_build_materials()
	_ghost_root = Node3D.new()
	_ghost_root.name = "GhostRoot"
	_ghost_root.top_level = true
	_ghost_root.visible = false
	add_child(_ghost_root)
	_ghost_visual = Node3D.new()
	_ghost_visual.name = "GhostVisual"
	_ghost_root.add_child(_ghost_visual)
	_ghost_label = Label3D.new()
	_ghost_label.name = "GhostLabel"
	_ghost_label.position = Vector3(0.0, 3.2, 0.0)  # above the building name plates
	_ghost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ghost_label.modulate = Color(1.0, 1.0, 1.0, 0.92)
	# The default 32 px at 0.005 m/px rendered ~8 px tall at the build camera's distance; this is
	# ~17 px at 1600x900 and still fits a 390 px wide phone at the default 15 m zoom.
	_ghost_label.font_size = 48
	_ghost_label.pixel_size = 0.006
	_ghost_label.outline_size = 12
	_ghost_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	_ghost_label.no_depth_test = true
	_ghost_root.add_child(_ghost_label)
	var contact := MeshInstance3D.new()
	contact.name = "ContactShadow"
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := PlaneMesh.new()
	disc.size = Vector2(1.1, 1.1)
	contact.mesh = disc
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	contact.material_override = shadow_mat
	contact.position = Vector3(0.0, 0.03, 0.0)
	_ghost_root.add_child(contact)
	_ghost_grid = MeshInstance3D.new()
	_ghost_grid.name = "GhostGrid"
	_ghost_grid.top_level = true
	_ghost_grid.visible = false
	_ghost_grid.material_override = _grid_mat
	add_child(_ghost_grid)
	_ghost_cells = MeshInstance3D.new()
	_ghost_cells.name = "GhostCells"
	_ghost_cells.top_level = true
	_ghost_cells.visible = false
	_ghost_cells.material_override = _cell_mat
	_ghost_cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost_cells)
	_snap_points = MeshInstance3D.new()
	_snap_points.name = "SnapPoints"
	_snap_points.top_level = true
	_snap_points.visible = false
	_snap_points.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var snap_mat := _cell_mat.duplicate() as StandardMaterial3D
	snap_mat.no_depth_test = true  # sockets behind a wall stay visible
	_snap_points.material_override = snap_mat
	add_child(_snap_points)

func begin(kind: StringName) -> void:
	_last_sync = [Vector2i(999999, 999999), -1, ""]
	_snap_key = []
	_aim_locked = false
	placing = kind
	rot_step = 0
	_rot_manual = false
	reason = ""
	valid = false
	_rebuild_ghost_visual()
	_snap_to_pointer()
	_sync_grid_state()
	_ghost_root.visible = true
	_ghost_grid.visible = not is_piece()
	_ghost_cells.visible = not is_piece()
	_snap_points.visible = is_piece()
	var grid := _grid()
	if grid:
		grid.set_actor(get_parent() as Node3D)
	Game.show_grid = true
	TouchControls.set_context(&"place")

## Select a modular piece in a tier; the HUD's rotate / confirm / cancel then drive it like a kit.
func begin_piece(kind: StringName, tier: StringName = &"thatch") -> bool:
	if not StructurePiece.is_piece_kind(kind) or StructurePiece.blueprint(kind, tier).is_empty():
		return false
	piece_tier = tier
	piece_at = {}
	begin(kind)
	# The sheet button that started this is under the finger: start a step in front of the survivor
	# and let taps on the world move the aim (tap_ground), never the pointer over the HUD.
	var who := get_parent() as Node3D
	if who:
		aim_at(who.global_position - who.global_basis.z * StructurePiece.module_m())
	return true

func is_piece() -> bool:
	return StructurePiece.is_piece_kind(placing)

## Pin the ghost's aim to a world point (labs and tests; a tap or drag drives it otherwise).
func aim_at(world: Vector3) -> void:
	_aim = world
	_aim_locked = true
	_sync_grid_state()

func upgrade(target: Node, tier: StringName, player: Player) -> bool:
	return _report("upgrade", StructurePlacer.upgrade(target, tier, player), player)

func repair(target: Node, player: Player) -> bool:
	return _report("repair", StructurePlacer.repair(target, player), player)

func demolish(target: Node, player: Player) -> bool:
	return _report("demolish", StructurePlacer.demolish(target, player), player)

func upgrade_all(target: StructurePiece, tier: StringName, player: Player) -> bool:
	return _report("upgrade", StructurePlacer.upgrade_all(target, tier, player), player)

func repair_all(target: StructurePiece, player: Player) -> bool:
	return _report("repair", StructurePlacer.repair_all(target, player), player)

func _report(what: String, why: String, player: Player) -> bool:
	if why != "":
		print("[struct] %s refused: %s" % [what, why])
		if player and player.has_method("notice"):
			player.notice("Can't %s: %s" % [what, reason_text(why)])
	return why == ""

static func kind_of_building(n: Node) -> StringName:
	if n == null:
		return &""
	if n is TamingPen:
		return &"makeshift_taming_pen"
	if n is Bonfire:
		return (n as Bonfire).kind
	if n is CraftStation:
		return (n as CraftStation).station_id
	var k: Variant = n.get("kind")
	if k != null and str(k) != "":
		return StringName(str(k))
	return &""

static func is_movable(n: Node) -> bool:
	if n == null or not (n is Node3D):
		return false
	return n.has_method("set_grid_pose") and kind_of_building(n) != &""

## One pack-up for every placed kind. The kit and everything stored inside go back to the bag,
## all or nothing: when anything is refused (not your land, a camp piece, a used one-shot,
## or a bag without room for every unit) the structure and the bag are left exactly as they were.
static func pack_up_node(n: Node, player: Player) -> bool:
	if n == null or player == null or n.is_queued_for_deletion():
		return false
	var kind := kind_of_building(n)
	var why := pack_up_blocker(n)
	var back: Array[ItemStack] = []
	if why == "":
		back = _pack_returns(n)
		if not fits_in_bag(player.inventory, back):
			why = "Your bag has no room"
	if why != "":
		print("[build] pack_up refused %s: %s" % [kind, why])
		player.notice("Can't pack up: %s" % why)
		return false
	for s in back:
		player.inventory.add(s)
	var storage: Variant = n.get("storage")
	if storage is Inventory:
		(storage as Inventory).load_array([])  # the units now live in the bag; no second copy
	if n.get("occupant") is ItemStack:
		n.set("occupant", null)
	if World.runtime and World.runtime.get("build_grid") is BuildGrid:
		(World.runtime.get("build_grid") as BuildGrid).release(n)
	n.queue_free()
	print("[item] packed %s" % kind)
	return true

## Why this structure cannot be packed up right now ("" = it can). Kind-specific rules live on
## the structure's own pack_up_block_reason().
static func pack_up_blocker(n: Node) -> String:
	var kind := kind_of_building(n)
	if kit_for(kind) == &"":
		return "This can't be packed up"
	if n.get("is_cargo") == true or n.get("persist_building") == false:
		return "Camp pieces stay put"
	if not _on_owned_land(n):
		return "Not on your land"
	if n.has_method("pack_up_block_reason"):
		return str(n.call("pack_up_block_reason"))
	return ""

## ASSUMPTION: owned land = the home island or a claimed tile (single player owns every claim;
## per-player ownership arrives with server-side structures).
static func _on_owned_land(n: Node) -> bool:
	if World.is_home():
		return true
	var cell: Variant = n.get("build_cell")
	if not cell is Vector2i or World.runtime == null or not World.runtime.has_method("is_claimed"):
		return false
	return bool(World.runtime.is_claimed(cell))

static func _pack_returns(n: Node) -> Array[ItemStack]:
	var kit := ItemStack.make(kit_for(kind_of_building(n)), 1)
	# A repacked kit is not a new build: place -> pack -> place must not farm construction or
	# pioneer XP (the report documents the +8/+30 loop). The flag survives merging only with an
	# equal flag set, and the next placement consumes the unit that carries it.
	kit.set_flag(&"repacked", true)
	var out: Array[ItemStack] = [kit]
	var storage: Variant = n.get("storage")
	if storage is Inventory:
		for s in (storage as Inventory).slots:
			if s != null and str(s.def_id) != "_slot_lock":
				out.append(s.duplicate_stack())
	var occ: Variant = n.get("occupant")
	if occ is ItemStack:
		out.append((occ as ItemStack).duplicate_stack())
	# A harvested field keeps bonus fertiliser as units; packing it up used to destroy them.
	var fert: Variant = n.get("fertilizer_overflow")
	if fert != null and float(fert) >= 1.0:
		out.append(ItemStack.make(&"fruit_fertilizer", int(floor(float(fert)))))
	return out

## Dry run on a copy of the bag: true only when every unit of every stack would land.
static func fits_in_bag(inv: Inventory, stacks: Array[ItemStack]) -> bool:
	var sim := Inventory.new(inv.slot_count)
	for i in inv.slot_count:
		sim.slots[i] = inv.slots[i].duplicate_stack() if inv.slots[i] else null
	for s in stacks:
		if sim.add(s.duplicate_stack()) > 0:
			return false
	return true

func begin_layout() -> void:
	layout_mode = true
	Game.show_grid = true
	var grid := _grid()
	if grid:
		grid.ignore_distance = true
	TouchControls.set_context(&"place")
	print("[build] layout mode on")

## Pick a placed building up: it becomes the ghost at its own spot with its cells freed.
func pick_up(n: Node3D) -> bool:
	if not layout_mode or not is_movable(n) or moving != null:
		return false
	var grid := _grid()
	if grid == null:
		return false
	moving = n
	_last_sync = [Vector2i(999999, 999999), -1, ""]
	_moving_cell = n.get("build_cell") if n.get("build_cell") != null else BuildGrid.tile_of(n.global_position)
	_moving_rot = int(n.get("build_rot")) if n.get("build_rot") != null else 0
	grid.release(n)
	n.visible = false
	placing = kind_of_building(n)
	rot_step = _moving_rot
	cell = _moving_cell
	reason = ""
	_rebuild_ghost_visual()
	_sync_grid_state()
	_ghost_root.visible = true
	_ghost_grid.visible = true
	_ghost_cells.visible = true
	dragging = true
	_press_t = Time.get_ticks_msec() * 0.001
	_press_pos = Game.pointer
	# Preserve the exact point the player grabbed instead of jumping the building's centre
	# under their finger. This also makes the first drag frame visibly respond immediately.
	var hit := _ground_at(Game.pointer)
	_drag_world_offset = n.global_position - hit.position if not hit.is_empty() else Vector3.ZERO
	_drag_world_offset.y = 0.0
	print("[build] pick up %s from (%d,%d)" % [placing, cell.x, cell.y])
	return true

## Finger/mouse released: a quick tap rotates the building in place, a drag drops it where it
## is if the spot is valid, otherwise it snaps back to where it came from.
func drag_end(player: Player) -> void:
	if moving == null:
		return
	dragging = false
	_ghost_visual.position = Vector3.ZERO
	var quick := (Time.get_ticks_msec() * 0.001 - _press_t) < 0.3 and Game.pointer.distance_to(_press_pos) < 14.0
	if quick:
		cell = _moving_cell
		rot_step = posmod(_moving_rot + 1, 4)
		_sync_grid_state()
		if valid:
			confirm(player)
		else:
			put_back()
			if player.has_method("notice"):
				player.notice("Can't rotate here: %s" % reason_text(reason))
		return
	_sync_grid_state()
	if valid:
		confirm(player)
	else:
		var why := reason
		put_back()
		if player.has_method("notice"):
			player.notice("Can't drop here: %s" % reason_text(why))

## While dragging, preserve the grabbed point under the finger.
func _snap_centered() -> void:
	_update_drag(Game.pointer)

## Update from the input event, not only on the next process frame. The placement footprint
## remains grid-snapped, while the building itself follows the finger continuously so crossing
## a tile boundary never feels like input lag.
func drag_to(screen_pos: Vector2) -> void:
	if moving == null or not dragging:
		return
	Game.pointer = screen_pos
	_update_drag(screen_pos)

func _update_drag(screen_pos: Vector2) -> void:
	var hit := _ground_at(screen_pos)
	if hit.is_empty():
		return
	var target: Vector3 = hit.position + _drag_world_offset
	var grid := _grid()
	var dims := grid.footprint(placing) if grid else Vector2i.ONE
	if posmod(rot_step, 4) % 2 == 1:
		dims = Vector2i(dims.y, dims.x)
	var under := BuildGrid.tile_of(target)
	cell = under - Vector2i(int(dims.x / 2), int(dims.y / 2))
	_sync_grid_state()
	# The overlay communicates the committed cell; only the translucent building follows every
	# pixel of finger travel. Keep its grounded Y from the snapped placement transform.
	var snapped: Vector3 = _ghost_root.global_position
	var visual_world := Vector3(target.x, snapped.y, target.z)
	_ghost_visual.position = _ghost_root.to_local(visual_world)

## Put a picked-up building back where it was (✕ while moving).
func put_back() -> void:
	if moving == null:
		return
	_ghost_visual.position = Vector3.ZERO
	var grid := _grid()
	if grid and is_instance_valid(moving):
		moving.visible = true
		moving.global_transform = grid.placement_transform(placing, _moving_cell, _moving_rot)
		moving.set_grid_pose(_moving_cell, _moving_rot)
		grid.occupy(moving, grid.cells_for(placing, _moving_cell, _moving_rot))
	moving = null
	placing = &""
	_ghost_root.visible = false
	_ghost_grid.visible = false
	_ghost_cells.visible = false

## DONE: drop anything still held back where it was, leave layout mode and save.
func end_layout() -> void:
	if moving:
		put_back()
	layout_mode = false
	var grid := _grid()
	if grid:
		grid.ignore_distance = false
	cancel()
	(load("res://scripts/core/save_game.gd") as GDScript).save_now()
	print("[build] layout saved")

func cancel() -> void:
	if moving:
		put_back()
		if layout_mode:
			return
	Game.show_grid = layout_mode
	var grid := _grid()
	if grid:
		grid.clear_actor(get_parent() as Node3D)
	placing = &""
	valid = false
	reason = ""
	_aim_locked = false
	_ghost_root.visible = false
	_ghost_grid.visible = false
	_ghost_cells.visible = false
	_snap_points.visible = false
	if not layout_mode:
		TouchControls.set_context(&"explore")

func rotate_clockwise() -> void:
	if placing == &"":
		return
	rot_step = posmod(rot_step + 1, 4)
	_rot_manual = true
	_sync_grid_state()

func tap_ground() -> void:
	if placing == &"":
		return
	if is_piece():
		var hit := _ground()
		if not hit.is_empty():
			aim_at(hit.position)  # the ghost snaps to the free socket nearest the tap
		return
	_snap_to_pointer()
	_sync_grid_state()

func _process(_delta: float) -> void:
	if placing == &"":
		return
	_fit_label()
	if is_piece():
		_sync_grid_state()  # the aim moves only by taps (tap_ground) and aim_at
		return
	if moving == null:
		_snap_to_pointer()
	elif dragging:
		_snap_centered()  # follows the finger while held
	_sync_grid_state()

## Keep the ghost's cost/refusal label about 20 px tall on any screen: the iso camera is orthographic,
## so a fixed pixel_size shrank to ~7 px on a 390 px tall phone.
func _fit_label() -> void:
	var cam := get_viewport().get_camera_3d()
	var h := get_viewport().get_visible_rect().size.y
	if cam and cam.projection == Camera3D.PROJECTION_ORTHOGONAL and h > 0.0:
		_ghost_label.pixel_size = maxf(0.006, 20.0 * cam.size / (48.0 * h))

func confirm(player: Player) -> bool:
	if placing == &"":
		return false
	_snap_key = []  # a piece re-snaps now: the bag or the grid may have changed since the last frame
	_sync_grid_state()
	if not valid:
		print("[build] rejected %s" % (reason if reason != "" else "invalid"))
		if player.has_method("notice"):
			player.notice("Can't place here: %s" % reason_text(reason))
		return false
	if moving:
		var g := _grid()
		if g == null or not is_instance_valid(moving):
			moving = null
			return false
		moving.visible = true
		moving.global_transform = g.placement_transform(placing, cell, rot_step)
		moving.set_grid_pose(cell, rot_step)
		if moving.has_method("reset_physics_interpolation"):
			moving.reset_physics_interpolation()
		g.occupy(moving, g.cells_for(placing, cell, rot_step))
		# Camp pieces are rebuilt each load from World.camp_layout, so remember where they went.
		var pv: Variant = moving.get("persist_building")
		if pv != null and not bool(pv):
			World.camp_layout[str(moving.name)] = {"cell": [cell.x, cell.y], "rot": posmod(rot_step, 4)}
		print("[build] moved %s to (%d,%d) rot=%d" % [placing, cell.x, cell.y, posmod(rot_step, 4) * 90])
		moving = null
		placing = &""
		_ghost_root.visible = false
		_ghost_grid.visible = false
		_ghost_cells.visible = false
		return true
	var runtime := World.runtime
	var grid := _grid()
	if runtime == null or grid == null:
		print("[build] rejected no_runtime")
		return false
	if is_piece():
		var res := StructurePlacer.place(grid.structures, runtime, placing, piece_tier, piece_at, player)
		_snap_key = []  # the grid changed: re-snap (the ghost stays up for the next piece)
		_sync_grid_state()
		return _report("place", str(res["reason"]), player)
	if not _can_pay(player):
		print("[build] rejected missing_kit")
		if player.has_method("notice"):
			player.notice("Can't place here: %s" % reason_text("missing_kit"))
		return false
	# Spawn before paying: a kind that fails to spawn must not eat the kit.
	var node := _spawn(placing)
	if node == null:
		print("[build] rejected spawn_failed %s" % placing)
		return false
	if not _pay(player):
		node.free()
		print("[build] rejected missing_kit")
		return false
	runtime.add_child(node)
	var pose := grid.placement_transform(placing, cell, rot_step)
	node.global_transform = pose
	if node.has_method("set_grid_pose"):
		node.set_grid_pose(cell, rot_step)
	grid.occupy(node, grid.cells_for(placing, cell, rot_step))
	print("[build] placed %s at (%d,%d) rot=%d" % [placing, cell.x, cell.y, posmod(rot_step, 4) * 90])
	if not _repacked:
		if player.skills:
			player.skills.add_xp("construction", 8)
		World.note_building(placing)
	_repacked = false
	cancel()
	return true

func _spawn(kind: StringName) -> Node3D:
	match kind:
		&"catapult":
			return FieldCatapult.new()
		&"makeshift_taming_pen":
			return TamingPen.make()
		&"bonfire":
			return Bonfire.make()
		&"stone_fire_pit":
			return Bonfire.make(&"stone_fire_pit")
		&"campfire":
			return Bonfire.make(&"campfire")
		&"workbench":
			return CraftStation.make(&"workbench")
		&"mortar":
			return CraftStation.make(&"mortar")
		&"well":
			return CraftStation.make(&"well")
		&"drying_rack":
			return CraftStation.make(&"drying_rack")
		&"smoker":
			return CraftStation.make(&"smoker")
		&"crock_pot":
			return CraftStation.make(&"crock_pot")
		&"stone_grill":
			return CraftStation.make(&"stone_grill")
		&"steamer":
			return CraftStation.make(&"steamer")
		&"field_small", &"field_large":
			return FieldPlot.make(kind)
		&"straw_roll", &"tent", &"canvas_tent", &"log_shelter", &"cabin_bed", &"basket", &"fence", &"gate", &"sign":
			return (load("res://scripts/world/placed_building.gd") as GDScript).make(kind)
		_:
			return null

## Raw materials some kinds accept when the bag holds no kit (pre-kit recipes).
const _RAW_COST := {
	&"makeshift_taming_pen": {&"branch": 4, &"twine": 2},
	&"bonfire": {&"branch": 2},
	&"workbench": {&"branch": 4, &"twine": 2},
	&"drying_rack": {&"branch": 4, &"twine": 2},
}

## Consumes one kit unit and says whether it was a repacked one (then this build is not new).
static func _take_kit(inv: Inventory, kit: StringName) -> bool:
	var idx := inv.find_first(kit)
	if idx < 0:
		return false
	var repacked := &"repacked" in inv.slots[idx].flags
	inv.remove_at(idx, 1)
	return repacked

func _can_pay(player: Player) -> bool:
	var kit := kit_for(placing)
	if kit != &"" and player.inventory.count_of(kit) > 0:
		return true
	var raw: Dictionary = _RAW_COST.get(placing, {})
	if raw.is_empty():
		return false
	for id in raw:
		if player.inventory.count_of(id) < int(raw[id]):
			return false
	return true

func _pay(player: Player) -> bool:
	if not _can_pay(player):
		return false
	var kit := kit_for(placing)
	if kit != &"" and player.inventory.count_of(kit) > 0:
		_repacked = _take_kit(player.inventory, kit)
		return true
	var raw: Dictionary = _RAW_COST.get(placing, {})
	for id in raw:
		player.inventory.consume(id, int(raw[id]))
	return true

func _sync_grid_state() -> void:
	if placing == &"":
		return
	var grid := _grid()
	if grid == null:
		valid = false
		reason = "no_runtime"
		return
	if is_piece():
		_sync_piece(grid)
		return
	# Auto-alignment is only a suggestion for a fresh placement; a moved building keeps its pose.
	if not _rot_manual and moving == null:
		rot_step = grid.suggested_fence_rot(placing, cell, rot_step)
	# Rebuilding the grid overlay (an ImmediateMesh plus ~80 tile quads) every frame made dragging
	# stutter; only redo it when the ghost actually moved, rotated or changed kind.
	if _last_sync[0] == cell and _last_sync[1] == rot_step and _last_sync[2] == str(placing):
		return
	_last_sync = [cell, rot_step, str(placing)]
	reason = grid.can_place(placing, cell, rot_step)
	valid = reason == ""
	_ghost_root.global_transform = grid.placement_transform(placing, cell, rot_step)
	if not _ghost_mat_fresh or _ghost_mat_valid != valid:
		_ghost_mat_valid = valid
		_ghost_mat_fresh = true
		_apply_ghost_material(_ghost_visual, _mat_valid if valid else _mat_invalid)
	_draw_overlay(grid)
	_update_label(grid)

## Re-snap only when the aim moved 5 cm, the rotation, piece, tier or grid changed.
func _sync_piece(grid: BuildGrid) -> void:
	var key := [Vector3i((_aim * 20.0).round()), rot_step, _rot_manual, placing, piece_tier]
	if key == _snap_key:
		return
	_snap_key = key
	var old_variant := int(piece_at.get("variant", -1))
	piece_at = StructurePlacer.snap(grid.structures, placing, piece_tier, _aim, rot_step, _rot_manual)
	reason = str(piece_at["reason"])
	var player := get_parent()
	if reason == "" and player and player.get("inventory") is Inventory:
		reason = StructurePlacer.tier_gate(player, piece_tier)
		if reason == "" and not StructurePlacer.can_pay(player.get("inventory"), StructurePiece.cost(placing, piece_tier)):
			reason = "missing_materials"
	var who := player as Node3D
	var at: Vector3 = StructurePiece.pose(placing, piece_at["slot"], int(piece_at["rot"]), float(piece_at["floor0"])).origin
	# ASSUMPTION: pieces use the kits' 8 m reach, measured flat so a roof two storeys up is in reach.
	if reason == "" and who and not grid.ignore_distance and Vector2(at.x - who.global_position.x, at.z - who.global_position.z).length() > BuildGrid.MAX_PLACE_DISTANCE:
		reason = "too_far"
	valid = reason == ""
	if int(piece_at.get("variant", 0)) != old_variant:
		_rebuild_ghost_visual()
	_ghost_root.global_transform = StructurePiece.pose(placing, piece_at["slot"], int(piece_at["rot"]), float(piece_at["floor0"]))
	if not _ghost_mat_fresh or _ghost_mat_valid != valid:
		_ghost_mat_valid = valid
		_ghost_mat_fresh = true
		_apply_ghost_material(_ghost_visual, _mat_valid if valid else _mat_invalid)
	_snap_points.mesh = StructurePlacer.snap_points_mesh(piece_at.get("sockets", []))
	var label := StructurePlacer.label(placing, piece_tier) if valid else reason_text(reason)
	if label != _last_label:
		_last_label = label
		_ghost_label.text = label

func _grid() -> BuildGrid:
	if World.runtime == null:
		return null
	var g: Variant = World.runtime.get("build_grid")
	if g is BuildGrid:
		return g as BuildGrid
	return null

func _snap_to_pointer() -> bool:
	var hit := _ground()
	if hit.is_empty():
		return false
	cell = BuildGrid.tile_of(hit.position)
	return true

func _ground() -> Dictionary:
	return _ground_at(Game.pointer)

func _ground_at(screen_pos: Vector2) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if get_parent() is CollisionObject3D:
		q.exclude = [(get_parent() as CollisionObject3D).get_rid()]  # a tap on the survivor aims at the ground under it
	return get_tree().root.get_world_3d().direct_space_state.intersect_ray(q)

func _build_materials() -> void:
	_mat_valid = StandardMaterial3D.new()
	_mat_valid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_valid.albedo_color = Color(0.18, 0.74, 0.70, 0.42)
	_mat_invalid = StandardMaterial3D.new()
	_mat_invalid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_invalid.albedo_color = Color(0.9, 0.2, 0.15, 0.42)
	_cell_mat = StandardMaterial3D.new()
	_cell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cell_mat.vertex_color_use_as_albedo = true
	_cell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_grid_mat = StandardMaterial3D.new()
	_grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.16)
	_grid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_grid_mat.no_depth_test = true

func _rebuild_ghost_visual() -> void:
	_ghost_mat_fresh = false
	for c in _ghost_visual.get_children():
		c.queue_free()
	var contact := _ghost_root.get_node_or_null("ContactShadow") as Node3D
	if contact:
		contact.visible = not is_piece()
	if is_piece():
		var mi := MeshInstance3D.new()
		mi.mesh = StructureMesh.mesh_for(placing, piece_tier, int(piece_at.get("variant", 0)))
		if placing == &"door":  # the leaf mesh starts at its hinge, as on the placed door
			mi.position.x = -float((StructurePiece.piece_def(&"doorway").get("opening", [1.1]) as Array)[0]) * 0.5 + 0.03
		_ghost_visual.add_child(mi)
		_apply_ghost_material(_ghost_visual, _mat_valid)
		return
	var path := PropVisuals.model_path(placing)
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			_ghost_visual.add_child((packed as PackedScene).instantiate())
	else:
		var box := MeshInstance3D.new()
		var dims := PropVisuals.footprint(placing)
		var shape := BoxMesh.new()
		shape.size = Vector3(maxf(0.8, float(dims.x)), 1.6, maxf(0.8, float(dims.y)))
		box.mesh = shape
		box.position.y = shape.size.y * 0.5
		_ghost_visual.add_child(box)
	_apply_ghost_material(_ghost_visual, _mat_valid)

func _apply_ghost_material(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.material_override = mat
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_apply_ghost_material(c, mat)

func _draw_overlay(grid: BuildGrid) -> void:
	# Both overlays are ArrayMeshes built from packed arrays in one server call each; the old
	# ImmediateMesh (one GDScript->engine call per vertex, ~360 per rebuild) plus per-cell
	# MeshInstance3D churn was the drag-lag hotspot. Terrain heights are sampled once per
	# unique grid point (121) instead of once per vertex (360).
	var center := grid.placement_transform(placing, cell, rot_step).origin
	var heights := {}
	var height_at := func(x: float, z: float) -> float:
		var k := Vector2(x, z)
		var v: Variant = heights.get(k, null)
		if v == null:
			v = _surface_y(x, z)
			heights[k] = v
		return float(v)
	var start_x := floorf(center.x) - float(GRID_HALF_SPAN) + 0.5
	var start_z := floorf(center.z) - float(GRID_HALF_SPAN) + 0.5
	var verts := PackedVector3Array()
	for row in range(0, GRID_HALF_SPAN * 2 + 2):
		var z := start_z + float(row) - 0.5
		for step in range(0, GRID_HALF_SPAN * 2 + 1):
			var x0 := start_x + float(step) - 0.5
			var x1 := x0 + 1.0
			verts.append(Vector3(x0, height_at.call(x0, z) + 0.06, z))
			verts.append(Vector3(x1, height_at.call(x1, z) + 0.06, z))
	for col in range(0, GRID_HALF_SPAN * 2 + 2):
		var x := start_x + float(col) - 0.5
		for step in range(0, GRID_HALF_SPAN * 2 + 1):
			var z0 := start_z + float(step) - 0.5
			var z1 := z0 + 1.0
			verts.append(Vector3(x, height_at.call(x, z0) + 0.06, z0))
			verts.append(Vector3(x, height_at.call(x, z1) + 0.06, z1))
	var line_arrays := []
	line_arrays.resize(Mesh.ARRAY_MAX)
	line_arrays[Mesh.ARRAY_VERTEX] = verts
	var lines := ArrayMesh.new()
	lines.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)
	_ghost_grid.mesh = lines
	# Reference: while placing, tiles that cannot be built on show as translucent red diamonds.
	var qverts := PackedVector3Array()
	var qcols := PackedColorArray()
	var occupied := grid.occupied_cells()
	var reserved := grid.reserved_cells()
	var mine := grid.cells_for(placing, cell, rot_step)
	var blocked_col := Color(0.95, 0.2, 0.2, 0.35)
	for dz in range(-GRID_HALF_SPAN, GRID_HALF_SPAN + 1):
		for dx in range(-GRID_HALF_SPAN, GRID_HALF_SPAN + 1):
			var t := Vector2i(int(floorf(center.x)) + dx, int(floorf(center.z)) + dz)
			if mine.has(t):
				continue
			var bad := occupied.has(t) or reserved.has(t)
			if not bad:
				bad = _nature_blocked(t)
			if not bad:
				continue
			_overlay_quad(qverts, qcols, BuildGrid.tile_centre(t, World.runtime), 0.9, 0.045, blocked_col)
	var mine_col := Color(0.16, 0.72, 0.68, 0.40) if valid else Color(0.9, 0.2, 0.15, 0.42)
	for c in mine:
		_overlay_quad(qverts, qcols, BuildGrid.tile_centre(c, World.runtime), 0.96, 0.05, mine_col)
	var quad_arrays := []
	quad_arrays.resize(Mesh.ARRAY_MAX)
	quad_arrays[Mesh.ARRAY_VERTEX] = qverts
	quad_arrays[Mesh.ARRAY_COLOR] = qcols
	var quads := ArrayMesh.new()
	quads.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad_arrays)
	_ghost_cells.mesh = quads

## Water/steep-ground rejection for a tile. Terrain is static for a loaded island, so the
## answer is cached per tile instead of re-running spawn_ok for ~121 tiles every rebuild.
func _nature_blocked(t: Vector2i) -> bool:
	if not is_instance_valid(_blocked_cache_runtime) or World.runtime != _blocked_cache_runtime:
		_blocked_cache_runtime = World.runtime
		_blocked_cache.clear()
	var v: Variant = _blocked_cache.get(t, null)
	if v != null:
		return bool(v)
	var bad := false
	if World.runtime and World.runtime.has_method("spawn_ok"):
		bad = not World.runtime.spawn_ok(BuildGrid.tile_centre(t, World.runtime), false)
	_blocked_cache[t] = bad
	return bad

func _overlay_quad(qverts: PackedVector3Array, qcols: PackedColorArray, centre: Vector3, size: float, y_off: float, col: Color) -> void:
	var h := size * 0.5
	var y := centre.y + y_off
	var p0 := Vector3(centre.x - h, y, centre.z - h)
	var p1 := Vector3(centre.x + h, y, centre.z - h)
	var p2 := Vector3(centre.x + h, y, centre.z + h)
	var p3 := Vector3(centre.x - h, y, centre.z + h)
	qverts.append(p0)
	qverts.append(p1)
	qverts.append(p2)
	qverts.append(p0)
	qverts.append(p2)
	qverts.append(p3)
	for i in 6:
		qcols.append(col)

func _surface_y(x: float, z: float) -> float:
	if World.runtime and World.runtime.has_method("surface_y"):
		return World.runtime.surface_y(x, z)
	return 0.0

func _cost_text() -> String:
	var kit := _kit_id(placing)
	if kit == "":
		kit = str(placing)
	var rec: Variant = Data.recipes.get(StringName(kit), null)
	if not rec is Dictionary:
		return ""
	var parts: PackedStringArray = []
	for slot in (rec as Dictionary).get("slots", []):
		if slot is Dictionary:
			parts.append("%s ×%d" % [str((slot as Dictionary).get("category", "")).replace("_", " "), int((slot as Dictionary).get("count", 1))])
	return " · ".join(parts)

func _update_label(grid: BuildGrid) -> void:
	var fp := grid.footprint(placing)
	var label := "%dx%d" % [fp.x, fp.y]
	var cost := _cost_text()
	if cost != "":
		label += "  %s" % cost
	if not valid and reason != "":
		label = reason_text(reason)  # the cost line only adds noise when the spot is refused
	var contact := _ghost_root.get_node_or_null("ContactShadow") as MeshInstance3D
	if contact and contact.mesh is PlaneMesh:
		(contact.mesh as PlaneMesh).size = Vector2(maxf(0.8, float(fp.x)) * 0.92, maxf(0.8, float(fp.y)) * 0.92)
	if label == _last_label:
		return  # setting Label3D.text re-rasterises the font texture
	_last_label = label
	_ghost_label.text = label
