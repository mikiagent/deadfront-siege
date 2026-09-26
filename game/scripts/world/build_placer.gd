class_name BuildPlacer
extends Node
## Grid-snap placement flow used by inventory and crafting.

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

func _kit_id(kind: StringName) -> String:
	match kind:
		&"makeshift_taming_pen":
			return "makeshift_taming_pen"
		&"bonfire":
			return "bonfire_kit"
		&"workbench":
			return "workbench_kit"
		&"drying_rack":
			return "drying_rack_kit"
		&"crock_pot":
			return "crock_pot_kit"
		&"tent":
			return "tent_kit"
		&"straw_roll":
			return "straw_roll_kit"
		&"basket":
			return "basket_kit"
		&"fence":
			return "fence_kit"
		&"gate":
			return "gate_kit"
		&"sign":
			return "sign_kit"
		_:
			return ""

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
	_ghost_label.position = Vector3(0.0, 2.6, 0.0)
	_ghost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ghost_label.modulate = Color(1.0, 1.0, 1.0, 0.92)
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

func begin(kind: StringName) -> void:
	_last_sync = [Vector2i(999999, 999999), -1, ""]
	placing = kind
	rot_step = 0
	reason = ""
	valid = false
	_rebuild_ghost_visual()
	_snap_to_pointer()
	_sync_grid_state()
	_ghost_root.visible = true
	_ghost_grid.visible = true
	_ghost_cells.visible = true
	var grid := _grid()
	if grid:
		grid.set_actor(get_parent() as Node3D)
	Game.show_grid = true
	TouchControls.set_context(&"place")

static func kind_of_building(n: Node) -> StringName:
	if n == null:
		return &""
	if n is TamingPen:
		return &"makeshift_taming_pen"
	if n is Bonfire:
		return &"bonfire"
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
				player.notice("Can't rotate here: %s" % reason.replace("_", " "))
		return
	_sync_grid_state()
	if valid:
		confirm(player)
	else:
		var why := reason
		put_back()
		if player.has_method("notice"):
			player.notice("Can't drop here: %s" % why.replace("_", " "))

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
	_ghost_root.visible = false
	_ghost_grid.visible = false
	_ghost_cells.visible = false
	if not layout_mode:
		TouchControls.set_context(&"explore")

func rotate_clockwise() -> void:
	if placing == &"":
		return
	rot_step = posmod(rot_step + 1, 4)
	_sync_grid_state()

func tap_ground() -> void:
	if placing == &"":
		return
	_snap_to_pointer()
	_sync_grid_state()

func _process(_delta: float) -> void:
	if placing == &"":
		return
	if moving == null:
		_snap_to_pointer()
	elif dragging:
		_snap_centered()  # follows the finger while held
	_sync_grid_state()

func confirm(player: Player) -> bool:
	if placing == &"":
		return false
	_sync_grid_state()
	if not valid:
		print("[build] rejected %s" % (reason if reason != "" else "invalid"))
		if player.has_method("notice"):
			player.notice("Can't place here: %s" % reason.replace("_", " "))
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
	if not _pay(player):
		print("[build] rejected missing_kit")
		return false
	var node := _spawn(placing)
	if node == null:
		return false
	var runtime := World.runtime
	var grid := _grid()
	if runtime == null or grid == null:
		if node:
			node.queue_free()
		print("[build] rejected no_runtime")
		return false
	runtime.add_child(node)
	var pose := grid.placement_transform(placing, cell, rot_step)
	node.global_transform = pose
	if node.has_method("set_grid_pose"):
		node.set_grid_pose(cell, rot_step)
	grid.occupy(node, grid.cells_for(placing, cell, rot_step))
	print("[build] placed %s at (%d,%d) rot=%d" % [placing, cell.x, cell.y, posmod(rot_step, 4) * 90])
	if player.skills:
		player.skills.add_xp("construction", 8)
	World.note_building(placing)
	cancel()
	return true

func _spawn(kind: StringName) -> Node3D:
	match kind:
		&"makeshift_taming_pen":
			return TamingPen.make()
		&"bonfire":
			return Bonfire.make()
		&"workbench":
			return CraftStation.make(&"workbench")
		&"drying_rack":
			return CraftStation.make(&"drying_rack")
		&"crock_pot":
			return CraftStation.make(&"crock_pot")
		&"straw_roll", &"tent", &"basket", &"fence", &"gate", &"sign":
			return (load("res://scripts/world/placed_building.gd") as GDScript).make(kind)
		_:
			return null

func _pay(player: Player) -> bool:
	var kit_id := StringName(str(_kit_id(placing)))
	if kit_id != &"" and player.inventory.count_of(kit_id) > 0:
		return player.inventory.consume(kit_id, 1)
	if placing == &"makeshift_taming_pen":
		if player.inventory.count_of(&"branch") < 4 or player.inventory.count_of(&"twine") < 2:
			return false
		player.inventory.consume(&"branch", 4)
		player.inventory.consume(&"twine", 2)
		return true
	if placing == &"bonfire":
		if player.inventory.count_of(&"branch") < 2:
			return false
		player.inventory.consume(&"branch", 2)
		return true
	if placing == &"workbench":
		if player.inventory.count_of(&"branch") < 4 or player.inventory.count_of(&"twine") < 2:
			return false
		player.inventory.consume(&"branch", 4)
		player.inventory.consume(&"twine", 2)
		return true
	if placing == &"drying_rack":
		if player.inventory.count_of(&"branch") < 4 or player.inventory.count_of(&"twine") < 2:
			return false
		player.inventory.consume(&"branch", 4)
		player.inventory.consume(&"twine", 2)
		return true
	if placing == &"tent":
		return player.inventory.consume(&"tent_kit", 1)
	if placing == &"straw_roll":
		return player.inventory.consume(&"straw_roll_kit", 1)
	if placing == &"basket":
		return player.inventory.consume(&"basket_kit", 1)
	if placing == &"fence":
		return player.inventory.consume(&"fence_kit", 1)
	if placing == &"gate":
		return player.inventory.consume(&"gate_kit", 1)
	if placing == &"sign":
		return player.inventory.consume(&"sign_kit", 1)
	return false

func _sync_grid_state() -> void:
	if placing == &"":
		return
	var grid := _grid()
	if grid == null:
		valid = false
		reason = "no_runtime"
		return
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
		label += "\n%s" % cost
	if not valid and reason != "":
		label += " · %s" % reason
	var contact := _ghost_root.get_node_or_null("ContactShadow") as MeshInstance3D
	if contact and contact.mesh is PlaneMesh:
		(contact.mesh as PlaneMesh).size = Vector2(maxf(0.8, float(fp.x)) * 0.92, maxf(0.8, float(fp.y)) * 0.92)
	if label == _last_label:
		return  # setting Label3D.text re-rasterises the font texture
	_last_label = label
	_ghost_label.text = label
