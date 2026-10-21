extends "res://scripts/dev/route_bot_lab.gd"
## CONTROLS B4 gate: an interaction bot taps resource nodes, crafting stations and building parts through the
## player's own tap path (PlayerInput.interact_tap_target, what a tap on the thing calls) and plays the
## interaction through to its start, one physics frame at a time:
## - node: the gather radial opens, the bot picks a hex it has the tool for, success = the gather cycle runs;
## - station: the station's hex menu (step 1) opens, the bot presses its hex (step 2: CRAFT or COOK) and picks
##   a recipe it has the inputs for, success = the craft runs at that station;
## - building part: gate (door) success = it opened or closed; basket (chest) = its storage is on screen;
##   tent and straw roll (bed): the SLEEP hex, success = she sleeps.
## Success also needs her to be where the interaction is real: within its range (node 3.2 m, station 2.35 m,
## bed 3.2 m, door and chest 2.8 m, her body's centre to its origin), on an open line to it (no tile
## between her and its footprint that the capsule cannot stand on, the reference below), facing it (60 deg),
## never inside its footprint and with no teleport (a frame moving further than her speed allows).
## A thing acted on from where she stood when it was 5-40 m off fails all of that, as it should.
## Time-to-interact = from the tap to the start (the bot presses each hex on the frame it shows).
## Set-up (lab, not gameplay): a camp near the start through the real placer: route_bot_lab's fenced compound
## (gate, tent, workbench inside) plus a straw roll and a basket inside, a bonfire, a drying rack, a mortar,
## a stone grill and a basket outside against its walls. Wild animals removed and vitals topped up each time;
## the bag holds an axe, a pick, a knife, twine and raw meat. Nodes chain (each tap is made from where the
## last ended, 5-40 m off). For a station or a part she is set down 5-40 m from it first, behind the camp's
## walls (the straight line crosses one) on 40 % of them when such a spot exists.
## Headless: --headless --fixed-fps 60 --path game -- --lab=interact_bot_lab --island=home_grassland
##   [--nodes=50] [--stations=20] [--parts=20] [--seed=7] [--shot-dir=DIR]
## Windowed with --shot-dir saves shots of the first station, door and node interactions as they start.
## Always saves interact_map_<island>.png (top view, route_bot_lab's colours) and interact_camp_<island>.png.
## Prints "[interact] ..." lines, then "[interact] PASS" (exit 0) or FAIL lines (exit 1).

const INTERACT_GATE := 0.98
const BEHIND_SHARE := 0.4
const FACE_DEG := 60.0
## The range the interaction itself works at (her body's centre to the thing's origin).
const RANGE := {"node": 3.2, "station": 2.35, "bed": 3.2, "gate": 2.8, "basket": 2.8}

var _nodes_n := 50
var _stations_n := 20
var _parts_n := 20
var _stations: Array[Node3D] = []
var _parts: Array[Node3D] = []
var _irows: Array[Dictionary] = []
var _shot_done := {}

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nodes="):
			_nodes_n = int(a.substr(8))
		elif a.begins_with("--stations="):
			_stations_n = int(a.substr(11))
		elif a.begins_with("--parts="):
			_parts_n = int(a.substr(8))
	await get_tree().create_timer(2.0).timeout
	_rt = World.runtime as IslandRuntime
	_expect(_rt != null and _rt.pathing != null, "the island and its TilePath are up")
	if _rt == null:
		_finish()
		return
	var fl := _rt.get_node_or_null("Floor") as CollisionObject3D
	if fl:
		_floor_rid = fl.get_rid()
	_clear_creatures()
	var placed := _build_camp()
	_expect(placed >= 21, "the camp stands (%d of 22 pieces)" % placed)
	for f in 3:
		await get_tree().physics_frame
	var walkable := _build_ref()
	for id: StringName in [&"flint_axe", &"flint_pick", &"stone_knife"]:
		LabKit.give(_player, id, 1)
	LabKit.give(_player, &"twine", 30)
	LabKit.give(_player, &"raw_meat", 30)
	print("[interact] island=%s nodes=%d stations=%d (%d kinds) parts=%d (%d kinds) reference tiles=%d" % [
		_island, _nodes_n, _stations_n, _stations.size(), _parts_n, _parts.size(), walkable])
	var plan: Array[String] = []
	for i in _nodes_n:
		plan.append("node")
	for i in _stations_n:
		plan.append("station")
	for i in _parts_n:
		plan.append("part")
	for i in range(plan.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t := plan[i]
		plan[i] = plan[j]
		plan[j] = t
	var ns := 0
	var np := 0
	for i in plan.size():
		_clear_creatures()
		_top_up()
		match plan[i]:
			"node":
				await _node_case(i)
			"station":
				await _target_case(i, _stations[ns % _stations.size()], "station")
				ns += 1
			"part":
				await _target_case(i, _parts[np % _parts.size()], _part_kind(_parts[np % _parts.size()]))
				np += 1
	_isummary()
	_imap()
	_finish()

# ---------------------------------------------------------------- the camp

## route_bot_lab's compound (fences, a gate, a tent and a workbench) plus a straw roll and a basket inside,
## and a bonfire, a drying rack, a mortar, a stone grill and a basket outside against its walls.
func _build_camp() -> int:
	var grid := _rt.build_grid
	var pieces: Array = [
		[&"fence", Vector2i(0, 0), 0], [&"fence", Vector2i(2, 0), 0], [&"fence", Vector2i(4, 0), 0], [&"fence", Vector2i(6, 0), 0],
		[&"fence", Vector2i(0, 1), 1], [&"fence", Vector2i(0, 3), 1], [&"fence", Vector2i(0, 5), 1],
		[&"fence", Vector2i(7, 1), 1], [&"fence", Vector2i(7, 3), 1], [&"gate", Vector2i(7, 5), 1],
		[&"fence", Vector2i(0, 7), 0], [&"fence", Vector2i(6, 7), 0],
		[&"tent", Vector2i(2, 2), 0], [&"workbench", Vector2i(5, 2), 1],
		[&"straw_roll", Vector2i(1, 5), 0], [&"basket", Vector2i(6, 1), 0],
		[&"bonfire", Vector2i(-1, 3), 0], [&"drying_rack", Vector2i(3, -1), 0], [&"mortar", Vector2i(8, 2), 0],
		[&"stone_grill", Vector2i(8, 8), 0], [&"basket", Vector2i(-1, 7), 0], [&"basket", Vector2i(-1, -1), 0],
	]
	var around := BuildGrid.tile_of(_player.global_position)
	for ring in range(5, 60):
		for k in 24:
			var a := around + Vector2i(Vector2(cos(k * TAU / 24.0), sin(k * TAU / 24.0)) * float(ring))
			if not _camp_fits(grid, a, pieces):
				continue
			_rt.claims.append(Rect2i(a - Vector2i(3, 3), Vector2i(15, 15)))
			grid.ignore_distance = true
			var n := 0
			var named := {}
			for pc in pieces:
				LabKit.give(_player, BuildPlacer.kit_for(pc[0]), 1)
				var before := get_tree().get_nodes_in_group("placed_building").size()
				_player.placer.begin(pc[0])
				_player.placer.cell = a + (pc[1] as Vector2i)
				_turn(int(pc[2]))
				if not _player.placer.confirm(_player):
					_player.placer.cancel()
					continue
				n += 1
				var all := get_tree().get_nodes_in_group("placed_building")
				var made: Node3D = all[all.size() - 1] if all.size() > before else null
				if made and pc[0] != &"fence":
					named["%s_%d_%d" % [pc[0], (pc[1] as Vector2i).x, (pc[1] as Vector2i).y]] = made
			grid.ignore_distance = false
			for key in ["workbench_5_2", "bonfire_-1_3", "drying_rack_3_-1", "mortar_8_2", "stone_grill_8_8"]:
				if named.has(key):
					_stations.append(named[key])
			for key in ["gate_7_5", "basket_6_1", "tent_2_2", "straw_roll_1_5", "basket_-1_7"]:
				if named.has(key):
					_parts.append(named[key])
			_compound_at = a
			print("[interact] camp at (%d,%d): %d pieces, stations %s, parts %s" % [a.x, a.y, n, _names(_stations), _names(_parts)])
			return n
	return 0

func _camp_fits(grid: BuildGrid, a: Vector2i, pieces: Array) -> bool:
	for dz in range(-3, 12):
		for dx in range(-3, 12):
			var c := a + Vector2i(dx, dz)
			if grid.blocks_path(c) or not _rt.pathing.is_walkable(c) or not _rt.spawn_ok(BuildGrid.tile_centre(c, _rt), false):
				return false
	var keep := _rt.claims.duplicate()
	_rt.claims.append(Rect2i(a - Vector2i(3, 3), Vector2i(15, 15)))
	grid.ignore_distance = true
	var ok := true
	for pc in pieces:
		if grid.can_place(pc[0], a + (pc[1] as Vector2i), int(pc[2])) != "":
			ok = false
			break
	grid.ignore_distance = false
	_rt.claims = keep
	return ok

static func _names(list: Array[Node3D]) -> String:
	var out: Array[String] = []
	for n in list:
		out.append(_kind(n))
	return ", ".join(out)

static func _kind(n: Node3D) -> String:
	if n is HarvestNode:
		return "node"
	var sid: Variant = n.get("station_id")
	if sid != null and str(sid) != "":
		return str(sid)
	return str(n.get("kind"))

static func _part_kind(n: Node3D) -> String:
	var k := _kind(n)
	return "bed" if k in ["tent", "straw_roll", "canvas_tent"] else k

# ---------------------------------------------------------------- footprints and the reference

func _foot(t: Node3D) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _rt.build_grid.cells_of(t):
		out.append(c)
	if out.is_empty():
		out.append(BuildGrid.tile_of(t.global_position))
	return out

static func _near_on(foot: Array[Vector2i], a: Vector2) -> Vector2:
	var best := a
	var best_d := INF
	for c in foot:
		var q := Vector2(clampf(a.x, c.x + 0.05, c.x + 0.95), clampf(a.y, c.y + 0.05, c.y + 0.95))
		if a.distance_squared_to(q) < best_d:
			best_d = a.distance_squared_to(q)
			best = q
	return best

## The reference (capsule-fit tiles) has nothing between `a` and the footprint, past her body's 0.3 m.
## `skip_bulk`: tiles touching the footprint do not count (a boulder's own bulk is not a wall in front of it).
func _ref_open(foot: Array[Vector2i], a: Vector2, skip_bulk := false) -> bool:
	var q := _near_on(foot, a)
	var steps := maxi(1, ceili(a.distance_to(q) / 0.05))
	for k in steps + 1:
		var s := a.lerp(q, float(k) / float(steps))
		if a.distance_to(s) < 0.3:
			continue
		var c := Vector2i(floori(s.x), floori(s.y))
		if foot.has(c):
			return true
		if skip_bulk and _touches(foot, c):
			continue
		if not _region.has_point(c) or _ref.is_point_solid(c):
			return false
	return true

static func _touches(foot: Array[Vector2i], c: Vector2i) -> bool:
	for f in foot:
		if absi(f.x - c.x) <= 1 and absi(f.y - c.y) <= 1:
			return true
	return false

## Reference tiles beside the footprint (8-way).
func _ref_beside(foot: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in foot:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dz)
				if not foot.has(n) and not out.has(n) and _region.has_point(n) and not _ref.is_point_solid(n):
					out.append(n)
	return out

## Shortest reference path length from `from` to a tile beside the footprint (INF: none under 60 m).
func _ref_reach(from: Vector2i, foot: Array[Vector2i]) -> Array:
	var best: Array[Vector2i] = []
	var best_len := INF
	for n in _ref_beside(foot):
		var tiles := _ref_tiles(from, n)
		if tiles.is_empty():
			continue
		var length := _tiles_len(tiles)
		if length < best_len:
			best_len = length
			best = tiles
	return [best_len, best] if best_len <= 60.0 else [INF, best]

## A start 5-40 m from the target with a reference route to it; behind a wall (the straight line crosses a
## tile the capsule cannot stand on) when asked and one exists.
func _pick_start(t: Node3D, foot: Array[Vector2i], behind: bool) -> Vector2i:
	var at := t.global_position
	var fallback := NO_TILE
	for attempt in 400:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(5.0, 40.0)
		var tile := BuildGrid.tile_of(at + Vector3(cos(ang), 0.0, sin(ang)) * dist)
		if not _region.has_point(tile) or _ref.is_point_solid(tile):
			continue
		var crosses := not _ref_open(foot, Vector2(tile) + Vector2(0.5, 0.5), true)
		if crosses != behind and fallback != NO_TILE:
			continue
		if float(_ref_reach(tile, foot)[0]) == INF:
			continue
		if crosses == behind:
			return tile
		fallback = tile
	return fallback

## Lab set-up: set her down on a tile (standing on the ground, still, nothing pending).
func _set_down(tile: Vector2i) -> void:
	_player.clear_nav()
	_player.actions.cancel_work()
	var c := BuildGrid.tile_centre(tile, _rt)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(c.x, _rt.surface_y(c.x, c.z) + _player.half_height() + 0.02, c.z)
	_player.reset_physics_interpolation()
	for f in 4:
		await get_tree().physics_frame

# ---------------------------------------------------------------- one interaction

func _node_case(i: int) -> void:
	var node := _pick_node(true)
	if node == null:
		# Nothing gatherable 5-40 m off where she stands: set her down 5-40 m from one (lab set-up).
		node = _pick_node(false)
		if node:
			var start := _pick_start(node, _foot(node), false)
			if start != NO_TILE:
				await _set_down(start)
	if node == null:
		_expect(false, "interaction %d: a gatherable node 5-40 m off" % i)
		return
	await _interact(i, node, "node")

## A node with something to gather that the bag has the tool for, 5-40 m from her with a reference route
## (near) or anywhere on the island (not near).
func _pick_node(near: bool) -> HarvestNode:
	var from := _start_tile()
	var cands: Array[HarvestNode] = []
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or not hn.visible or hn.collision_layer == 0 or hn.depleted or hn.pool_units_left() <= 0 or _option_for(hn) < 0:
			continue
		var d := _flat(hn.global_position).distance_to(_flat(_player.global_position))
		if near and (d < 5.0 or d > 40.0):
			continue
		cands.append(hn)
	while not cands.is_empty():
		var k := _rng.randi() % cands.size()
		var hn := cands[k]
		cands.remove_at(k)
		if not near or float(_ref_reach(from, _foot(hn))[0]) < INF:
			return hn
	return null

## The first option of a node that it can be gathered for with this bag (-1: none).
func _option_for(hn: HarvestNode) -> int:
	var opts := hn.options()
	for k in opts.size():
		var o: Dictionary = opts[k]
		var tool := StringName(str(o.get("tool", "none")))
		if str(o.get("blocked_reason", "")) != "" or int(o.get("left", 1)) <= 0:
			continue
		if tool != &"none" and tool != &"" and not _player.inventory.has_tool_class(tool):
			continue
		return k
	return -1

func _target_case(i: int, t: Node3D, kind: String) -> void:
	if t == null or not is_instance_valid(t):
		_expect(false, "interaction %d: the %s stands" % [i, kind])
		return
	var foot := _foot(t)
	var behind := _rng.randf() < BEHIND_SHARE
	var start := _pick_start(t, foot, behind)
	if start == NO_TILE:
		_expect(false, "interaction %d: a start 5-40 m from the %s" % [i, _kind(t)])
		return
	await _set_down(start)
	if kind == "bed":
		_player.vitals.fatigue = 50.0
		_player._last_hit_taken_s = -999.0
	await _interact(i, t, kind)

## Tap, play the interaction through, measure every frame until it starts or the time runs out.
func _interact(i: int, t: Node3D, kind: String) -> void:
	var foot := _foot(t)
	var from := _start_tile()
	var reach: Array = _ref_reach(from, foot)
	var ref_len: float = reach[0]
	var ref_tiles: Array[Vector2i] = reach[1]
	var start_pos := _player.global_position
	var behind := not _ref_open(foot, _flat(start_pos), true)
	var limit := (ref_len if ref_len < INF else 40.0) / 4.0 + 8.0
	var gate_was: bool = bool(t.get("gate_open")) if kind == "gate" else false
	var opt := _option_for(t as HarvestNode) if kind == "node" else -1
	var rid := _recipe_for(t) if kind == "station" else &""
	_player.controls.interact_tap_target(t)
	var t_s := 0.0
	var walked := 0.0
	var hops := 0
	var inside := 0
	var touch := 0
	var stuck := 0.0
	var stuck_max := 0.0
	var prev := _flat(_player.global_position)
	var trail := PackedVector2Array([prev])
	var touches := PackedVector2Array()
	var stepped := false   # the bot's own step (hex, recipe) is done
	var started := false
	var why := ""
	while t_s < limit:
		# The bot acts on the frame the hex shows, before the frame runs.
		if not stepped:
			stepped = _bot_step(t, kind, opt, rid)
		started = _started(t, kind, gate_was)
		if started:
			break
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t_s += dt
		var now := _flat(_player.global_position)
		var step := now.distance_to(prev)
		walked += step
		if step > _player.sprint_speed * dt * 1.25 + 0.05:
			hops += 1
		if foot.has(Vector2i(floori(now.x), floori(now.y))):
			inside += 1
		if _player.nav_active and step / maxf(dt, 0.0001) < STUCK_SPEED:
			stuck += dt
			stuck_max = maxf(stuck_max, stuck)
		else:
			stuck = 0.0
		if _touching_solid():
			touch += 1
			touches.append(now)
		if trail[trail.size() - 1].distance_to(now) > 0.25:
			trail.append(now)
		prev = now
		if kind == "node" and stepped and _player.gather_target != t and not _player._gathering:
			why = "the gather was dropped"
			break
		if kind == "station" and stepped and _player.station_craft.recipe_id == &"" and not _player.station_craft.crafting:
			why = "the craft was dropped"
			break
	var here := _player.global_position
	var dist := here.distance_to(t.global_position)
	var near_pt := _near_on(foot, _flat(here))
	var fwd := -_player.visual.global_basis.z
	var face := rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(near_pt - _flat(here))))
	var open := _ref_open(foot, _flat(here))
	var in_range := dist <= float(RANGE[kind])
	if not started and why == "":
		why = "not started in %.1f s" % limit
	elif started and not in_range:
		why = "%.2f m off (range %.2f)" % [dist, float(RANGE[kind])]
	elif started and not open:
		why = "through a wall"
	elif started and face > FACE_DEG:
		why = "facing %.0f deg away" % face
	elif hops > 0:
		why = "%d teleport frames" % hops
	elif inside > 0:
		why = "%d frames inside it" % inside
	var ok := why == ""
	if started and ok and _shots and not _shot_done.has(kind):
		_shot_done[kind] = true
		await _shot("interact_%s_%s" % [_island, kind])
	var row := {"i": i, "kind": kind, "what": _kind(t), "ok": ok, "t": t_s, "ref": ref_len, "walked": walked,
		"hops": hops, "inside": inside, "touch": touch, "stuck": stuck_max, "behind": behind, "dist": dist, "face": face}
	_irows.append(row)
	_trails.append([ref_tiles, trail, touches])
	print("[interact] %3d %-7s %-12s %s t=%5.2f ref=%5.1f walked=%5.1f dist=%.2f face=%3.0f behind=%s touch=%d stuck=%.2f%s" % [
		i, kind, _kind(t), "ok  " if ok else "MISS", t_s, ref_len if ref_len < INF else -1.0, walked, dist, face,
		behind, touch, stuck_max, "" if ok else " (" + why + ")"])
	await _undo(t, kind)

## The bot's own step on the frame the interaction's hexes show. True once done.
func _bot_step(t: Node3D, kind: String, opt: int, rid: StringName) -> bool:
	var sc := _player.station_craft
	match kind:
		"node":
			var radial := _player._gather_radial
			if radial and radial.is_open() and radial.node == t and opt >= 0 and opt < radial._buttons.size():
				radial._buttons[opt].pressed.emit()
				return true
		"station", "bed":
			if sc.menu.visible and sc.menu.station == t:
				var acts := StationMenu.actions_for(sc.station_id_of(t), _player)
				if acts.is_empty():
					return false
				sc.menu._on_pressed(StringName(str((acts[0] as Dictionary).get("id", ""))))
				if kind == "station":
					if _player.craft_ui and _player.craft_ui.visible:
						_player.craft_ui.hide_ui()
					_player.craft_recipe(rid)
				return true
		_:
			return true
	return false

func _started(t: Node3D, kind: String, gate_was: bool) -> bool:
	match kind:
		"node":
			return _player._gathering and _player.gather_target == t
		"station":
			return _player.station_craft.crafting and _player.station_craft.station == t
		"bed":
			return _player._sleep_left > 0.0
		"gate":
			return bool(t.get("gate_open")) != gate_was
		"basket":
			return _player.ui != null and _player.ui.visible and _player.ui.pet_bag == t.get("storage")
	return false

## A recipe of this station the bag holds the inputs for.
func _recipe_for(t: Node3D) -> StringName:
	var sid := _player.station_craft.station_id_of(t)
	for rec in Crafting.recipes_for_station(sid):
		var picks := Crafting.default_picks(_player.inventory, rec)
		if Crafting.progression_block(_player, rec) == "" and Crafting.picks_valid(_player.inventory, rec, picks):
			return StringName(str(rec.get("id", "")))
	return &""

## Undo what the interaction started (stop the gather or the craft, wake her, close the chest) and leave
## the door as it is now (the reference learns it).
func _undo(t: Node3D, kind: String) -> void:
	_player.actions.cancel_work()
	_player.station_craft.close_menu()
	if _player.craft_ui:
		_player.craft_ui.hide_ui()
	if _player._gather_radial and _player._gather_radial.is_open():
		_player._gather_radial.close()
	if _player.ui:
		_player.ui.visible = false
	if kind == "bed" and _player._sleep_left > 0.0:
		Input.action_press("move_left")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("move_left")
		for f in 150:
			await get_tree().physics_frame
			if _player.anim == null or not _player.anim._waking:
				break
	if kind == "gate":
		await get_tree().physics_frame
		_retest_ref(t)
	_player.clear_nav()
	for f in 3:
		await get_tree().physics_frame

# ---------------------------------------------------------------- summary

func _isummary() -> void:
	var n := _irows.size()
	if n == 0:
		_expect(false, "interactions ran")
		return
	var by := {}
	var teleports := 0
	var t_all: Array[float] = []
	var ok_n := 0
	for r in _irows:
		var k: String = r["kind"]
		if not by.has(k):
			by[k] = {"n": 0, "ok": 0, "t": [] as Array[float], "behind": 0, "behind_ok": 0}
		var b: Dictionary = by[k]
		b["n"] += 1
		teleports += int(r["hops"])
		if r["behind"]:
			b["behind"] += 1
		if r["ok"]:
			ok_n += 1
			b["ok"] += 1
			(b["t"] as Array[float]).append(float(r["t"]))
			t_all.append(float(r["t"]))
			if r["behind"]:
				b["behind_ok"] += 1
	for k in by:
		var b: Dictionary = by[k]
		print("[interact] kind=%s n=%d ok=%d mean_t=%.2fs behind=%d (ok %d)" % [k, b["n"], b["ok"], _mean(b["t"]), b["behind"], b["behind_ok"]])
	var groups := {"node": ["node"], "station": ["station"], "part": ["gate", "basket", "bed"]}
	var success := float(ok_n) / float(n)
	var line := "[interact] summary island=%s n=%d ok=%d (%.1f%%) mean_t=%.2fs teleports=%d" % [_island, n, ok_n, success * 100.0, _mean(t_all), teleports]
	for g in groups:
		var gn := 0
		var gok := 0
		var gt: Array[float] = []
		for k in groups[g]:
			if by.has(k):
				gn += int(by[k]["n"])
				gok += int(by[k]["ok"])
				gt.append_array(by[k]["t"])
		line += " %s=%d/%d mean_t=%.2fs" % [g, gok, gn, _mean(gt)]
	print(line)
	_expect(success >= INTERACT_GATE, "success %.1f%% >= %.0f%%" % [success * 100.0, INTERACT_GATE * 100.0])
	_expect(teleports == 0, "no teleports (%d frames)" % teleports)

func _imap() -> void:
	_map_image(_region, clampi(900 / maxi(_region.size.x, 1), 3, 8), "interact_map_%s.png" % _island)
	if _compound_at != NO_TILE:
		_map_image(Rect2i(_compound_at - Vector2i(14, 14), Vector2i(36, 36)), 14, "interact_camp_%s.png" % _island)

func _expect(ok: bool, what: String) -> void:
	if ok:
		print("[interact] ok %s" % what)
	else:
		_fails.append(what)
		print("[interact] FAIL %s" % what)

func _finish() -> void:
	if _fails.is_empty():
		print("[interact] PASS")
		get_tree().quit(0)
	else:
		print("[interact] FAIL count=%d" % _fails.size())
		get_tree().quit(1)
