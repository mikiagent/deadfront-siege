extends Node3D
## CONTROLS B3 gate: a route bot taps the ground (the player's own ground-tap path) at random reachable
## spots on one island and measures every walk, one physics frame at a time.
## Reference: a 1 m grid of tiles where the survivor's capsule physically fits (dry terrain, no body
## but the ground overlapping it), searched 8-way without cutting corners. A target is a random tile on
## it 8-40 m from the survivor with a reference path under 60 m; every other one is 1-3 m from a
## resource node (where players tap, and where the trunks are). Routes chain: each starts where the last
## ended. Wild animals are removed and vitals topped up before each route (lab set-up: this measures the
## router and the walk, not fights or stamina).
## Buildings: before the reference is built the bot places a player compound near the start through the
## real placer (fences on three sides with a 4 m opening, a closed gate, a tent and a workbench
## inside). At route GATE_AT it opens the gate. Every DROP_EVERY-th route it drops a fence across the planned
## path 3-6 m ahead of the walking survivor and takes it away after the route (a dynamic obstacle); those
## routes are left out of the length gate, since the reference did not know the fence.
## Per route: arrived (within ARRIVE_M of the tapped tile's centre, in time), the longest stuck stretch
## (routed and slower than STUCK_SPEED), walked length against the reference path, heading change per
## metre walked (the velocity's direction), frames in contact with a solid that is not the ground, and
## hops (a frame that moves further than the speed allows: unstick or shoreline pushes).
## Headless: --headless --fixed-fps 60 --path game -- --lab=route_bot_lab --island=home_grassland
##   [--routes=100] [--seed=7] [--heading-bound=DEG_PER_M] [--shot-dir=DIR]
## Windowed with --shot-dir saves a shot mid-route on a few routes. Always saves route_map_<island>.png
## (top view: blocked tiles, the reference path, the walked trail, red where it touched a solid).
## Prints "[route] ..." lines, then "[route] PASS" (exit 0) or FAIL lines (exit 1).

const ARRIVE_M := 0.75
const STUCK_SPEED := 0.45     ## m/s: routed and slower than this counts toward a stuck stretch
const STUCK_GATE_S := 2.0
const SUCCESS_GATE := 0.99
const LENGTH_GATE := 1.15
const MIN_MOVING := 1.0       ## m/s: the heading is read only while moving at least this fast
const NO_TILE := Vector2i(-2147483648, -2147483648)
const DROP_EVERY := 5
const GATE_AT := 50           ## route index at which the compound's gate opens
## Mean heading change per metre walked (deg/m). The base measured 11-13.5 on the three islands (zig-zag
## around waypoints, re-plans every 1.5 s, scraping along trunks and fences); the gate asks for half.
const HEADING_BOUND := 6.0

var _player: Player
var _rt: IslandRuntime
var _ref := AStarGrid2D.new()
var _region := Rect2i()
var _rng := RandomNumberGenerator.new()
var _island: StringName = &"home_grassland"
var _routes := 100
var _bound := HEADING_BOUND
var _out := ""
var _shots := false
var _rows: Array[Dictionary] = []
var _fails: Array[String] = []
var _floor_rid := RID()
var _trails: Array = []       ## per route: [ref tiles (Array[Vector2i]), trail (PackedVector2Array), touches (PackedVector2Array)]
var _gate: Node3D
var _compound_at := NO_TILE
var _drops := 0
var _trace := -1

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("route-bot")
	var seed := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--island="):
			_island = StringName(a.substr(9))
		elif a.begins_with("--routes="):
			_routes = int(a.substr(9))
		elif a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--trace="):
			_trace = int(a.substr(8))
		elif a.begins_with("--heading-bound="):
			_bound = float(a.substr(16))
		elif a.begins_with("--shot-dir="):
			_out = a.substr(11)
			_shots = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(_out)
	_rng.seed = seed
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	World.home_terrain = &"meadow"
	World.load_island(self, _island, Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _run() -> void:
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
	var placed := _build_compound()
	_expect(placed >= 12, "the compound stands (%d of 14 pieces)" % placed)
	for f in 3:
		await get_tree().physics_frame
	var walkable := _build_ref()
	print("[route] island=%s routes=%d reference tiles=%d" % [_island, _routes, walkable])
	for i in _routes:
		_clear_creatures()
		_top_up()
		if i == GATE_AT and _gate and is_instance_valid(_gate):
			_gate.call("set_gate_open", true)
			await get_tree().physics_frame
			_retest_ref(_gate)
		var goal := _pick_target(i % 2 == 1)
		if goal == NO_TILE:
			_expect(false, "route %d: a reachable target 8-40 m off" % i)
			break
		await _route(i, goal)
	_summary()
	_map()
	_finish()

# ---------------------------------------------------------------- reference grid

func _build_ref() -> int:
	var rad := int(ceil(_rt.land_radius())) + 2
	_region = Rect2i(Vector2i(-rad, -rad), Vector2i(rad * 2 + 1, rad * 2 + 1))
	_ref.region = _region
	_ref.cell_size = Vector2.ONE
	_ref.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_ref.update()
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 2.0
	q.shape = cap
	q.collision_mask = 1
	q.exclude = [_player.get_rid(), _floor_rid]
	var space := get_world_3d().direct_space_state
	var n := 0
	for z in range(_region.position.y, _region.end.y):
		for x in range(_region.position.x, _region.end.x):
			var tile := Vector2i(x, z)
			var c := BuildGrid.tile_centre(tile, _rt)
			var ok := _rt.spawn_ok(c, false)
			if ok:
				q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, _rt.surface_y(c.x, c.z) + 1.15, c.z))
				ok = space.intersect_shape(q, 1).is_empty()
			_ref.set_point_solid(tile, not ok)
			if ok:
				n += 1
	return n

func _retest_ref(node: Node) -> void:
	var grid := _rt.build_grid
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 2.0
	q.shape = cap
	q.collision_mask = 1
	q.exclude = [_player.get_rid(), _floor_rid]
	for c in grid.cells_of(node):
		var at := BuildGrid.tile_centre(c, _rt)
		q.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, _rt.surface_y(at.x, at.z) + 1.15, at.z))
		_ref.set_point_solid(c, not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty())

## A player compound 8 x 8 tiles near the start, through the real placer (lab set-up: a claim over it and
## no reach limit). Returns how many of its pieces stand.
func _build_compound() -> int:
	var grid := _rt.build_grid
	var pieces: Array = [
		[&"fence", Vector2i(0, 0), 0], [&"fence", Vector2i(2, 0), 0], [&"fence", Vector2i(4, 0), 0], [&"fence", Vector2i(6, 0), 0],
		[&"fence", Vector2i(0, 1), 1], [&"fence", Vector2i(0, 3), 1], [&"fence", Vector2i(0, 5), 1],
		[&"fence", Vector2i(7, 1), 1], [&"fence", Vector2i(7, 3), 1], [&"gate", Vector2i(7, 5), 1],
		[&"fence", Vector2i(0, 7), 0], [&"fence", Vector2i(6, 7), 0],
		[&"tent", Vector2i(2, 2), 0], [&"workbench", Vector2i(5, 2), 1],
	]
	var around := BuildGrid.tile_of(_player.global_position)
	for ring in range(4, 30):
		for k in 16:
			var a := around + Vector2i(Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0)) * float(ring))
			if not _compound_fits(grid, a, pieces):
				continue
			_rt.claims.append(Rect2i(a - Vector2i(1, 1), Vector2i(10, 10)))
			grid.ignore_distance = true
			var n := 0
			for pc in pieces:
				LabKit.give(_player, BuildPlacer.kit_for(pc[0]), 1)
				_player.placer.begin(pc[0])
				_player.placer.cell = a + (pc[1] as Vector2i)
				for r in int(pc[2]):
					_player.placer.rotate_clockwise()
				if _player.placer.confirm(_player):
					n += 1
				else:
					_player.placer.cancel()
			grid.ignore_distance = false
			for g in get_tree().get_nodes_in_group("gate"):
				_gate = g as Node3D
			_compound_at = a
			print("[route] compound at (%d,%d): %d pieces" % [a.x, a.y, n])
			return n
	return 0

func _compound_fits(grid: BuildGrid, a: Vector2i, pieces: Array) -> bool:
	for dz in range(-1, 9):
		for dx in range(-1, 9):
			var c := a + Vector2i(dx, dz)
			if grid.blocks_path(c) or not _rt.pathing.is_walkable(c) or not _rt.spawn_ok(BuildGrid.tile_centre(c, _rt), false):
				return false
	var keep := _rt.claims.duplicate()
	_rt.claims.append(Rect2i(a - Vector2i(1, 1), Vector2i(10, 10)))
	grid.ignore_distance = true
	var ok := true
	for pc in pieces:
		if grid.can_place(pc[0], a + (pc[1] as Vector2i), int(pc[2])) != "":
			ok = false
			break
	grid.ignore_distance = false
	_rt.claims = keep
	return ok

## Drop a fence across the planned path 3-6 m (along it) ahead of the survivor. Returns it, or null.
func _drop_fence() -> Node3D:
	var pts := _player.sim.path_points()
	var grid := _rt.build_grid
	var from := _player.global_position
	var along := 0.0
	for k in range(_player.sim.path_index(), pts.size()):
		var seg := pts[k] - from
		seg.y = 0.0
		var seg_len := seg.length()
		for d: float in [3.0, 4.0, 5.0, 6.0]:
			if d < along or d > along + seg_len or seg_len < 0.01:
				continue
			var at3: Vector3 = from + seg * ((d - along) / seg_len)
			var rot := 1 if absf(seg.x) >= absf(seg.z) else 0  # across the walk
			var fence := _place_fence(grid, BuildGrid.tile_of(at3), rot)
			if fence:
				return fence
		along += seg_len
		from = pts[k]
	return null

func _place_fence(grid: BuildGrid, at: Vector2i, rot: int) -> Node3D:
	_rt.claims.append(Rect2i(at - Vector2i(2, 2), Vector2i(5, 5)))
	grid.ignore_distance = true
	LabKit.give(_player, BuildPlacer.kit_for(&"fence"), 1)
	var before := get_tree().get_nodes_in_group("fence").size()
	_player.placer.begin(&"fence")
	_player.placer.cell = at
	for r in rot:
		_player.placer.rotate_clockwise()
	var ok := _player.placer.confirm(_player)
	if not ok:
		_player.placer.cancel()
	grid.ignore_distance = false
	_rt.claims.pop_back()
	var fences := get_tree().get_nodes_in_group("fence")
	if ok and fences.size() > before:
		_drops += 1
		return fences[fences.size() - 1] as Node3D
	return null

func _ref_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _region.has_point(a) or not _region.has_point(b) or _ref.is_point_solid(a) or _ref.is_point_solid(b):
		return out
	for id in _ref.get_id_path(a, b):
		out.append(Vector2i(id))
	if out.is_empty() or out[out.size() - 1] != b:
		out.clear()
	return out

static func _tiles_len(tiles: Array[Vector2i]) -> float:
	var d := 0.0
	for k in range(1, tiles.size()):
		d += Vector2(tiles[k] - tiles[k - 1]).length()
	return d

func _pick_target(near_node: bool) -> Vector2i:
	var from := _start_tile()
	if from == NO_TILE:
		return NO_TILE
	var nodes: Array[Node3D] = []
	if near_node:
		for n in get_tree().get_nodes_in_group("harvest"):
			var hn := n as HarvestNode
			if hn and hn.visible and hn.collision_layer != 0:
				var d := _flat(hn.global_position).distance_to(_flat(_player.global_position))
				if d >= 8.0 and d <= 40.0:
					nodes.append(hn)
	for attempt in 400:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(8.0, 40.0)
		var at := _player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
		if not nodes.is_empty():
			at = nodes[_rng.randi() % nodes.size()].global_position + Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(1.0, 3.0)
		var tile := BuildGrid.tile_of(at)
		if not _region.has_point(tile) or _ref.is_point_solid(tile):
			continue
		var tiles := _ref_tiles(from, tile)
		if tiles.is_empty() or _tiles_len(tiles) > 60.0:
			continue
		return tile
	return NO_TILE

## The survivor's tile, or the nearest reference tile when she stands on a blocked one's edge.
func _start_tile() -> Vector2i:
	var t := BuildGrid.tile_of(_player.global_position)
	if _region.has_point(t) and not _ref.is_point_solid(t):
		return t
	var best := NO_TILE
	var best_d := 9.0
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var c := t + Vector2i(dx, dz)
			if not _region.has_point(c) or _ref.is_point_solid(c):
				continue
			var d := Vector2(dx, dz).length()
			if d < best_d:
				best_d = d
				best = c
	return best

# ---------------------------------------------------------------- one route

func _route(i: int, goal: Vector2i) -> void:
	var start_tile := _start_tile()
	var ref := _ref_tiles(start_tile, goal)
	var ref_len := _tiles_len(ref)
	var goal_pos := BuildGrid.tile_centre(goal, _rt)
	var start := _player.global_position
	_player.controls._walk_to_tile(goal_pos)  # the ground tap's own path: cancel work, route, marker
	var limit := ref_len / 4.0 + 6.0
	var t := 0.0
	var walked := 0.0
	var turn := 0.0
	var stuck := 0.0
	var stuck_max := 0.0
	var touch_frames := 0
	var hops := 0
	var hop_max := 0.0
	var prev := _flat(_player.global_position)
	var prev_head := INF
	var trail := PackedVector2Array([prev])
	var touches := PackedVector2Array()
	var shot_at := (ref_len / 5.0) * 0.45 if _shots and i in [1, 4, 7] else -1.0
	var drop_at := 0.5 if i % DROP_EVERY == DROP_EVERY - 1 else -1.0
	var dropped: Node3D = null
	while t < limit:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		var now := _flat(_player.global_position)
		var step := now.distance_to(prev)
		walked += step
		var vel := Vector2(_player.velocity.x, _player.velocity.z)
		var speed := vel.length()
		if step > _player.sprint_speed * dt * 1.25 + 0.05:
			hops += 1
			hop_max = maxf(hop_max, step)
		if speed >= MIN_MOVING:
			var head := vel.angle()
			if prev_head != INF:
				turn += absf(angle_difference(prev_head, head))
			prev_head = head
		if _player.nav_active and step / maxf(dt, 0.0001) < STUCK_SPEED:
			stuck += dt
			stuck_max = maxf(stuck_max, stuck)
		else:
			stuck = 0.0
		if _touching_solid():
			touch_frames += 1
			touches.append(now)
		if trail[trail.size() - 1].distance_to(now) > 0.25:
			trail.append(now)
		prev = now
		if i == _trace and int(t * 60.0) % 6 == 0:
			var hit := ""
			for k in _player.get_slide_collision_count():
				var sc := _player.get_slide_collision(k)
				hit += " %s n=(%.2f,%.2f,%.2f)" % [str((sc.get_collider() as Node).name) if sc.get_collider() is Node else "?", sc.get_normal().x, sc.get_normal().y, sc.get_normal().z]
			print("[trace] t=%.2f pos=(%.2f,%.2f) v=(%.2f,%.2f) nav=%s idx=%d/%d pts=%s goal=(%.1f,%.1f)%s" % [t, now.x, now.y, vel.x, vel.y, _player.nav_active, _player.sim.path_index(), _player.sim.path_points().size(), str(_player.sim.path_points()).substr(0, 160), _player._path_goal.x, _player._path_goal.z, hit])
		if drop_at > 0.0 and t >= drop_at:
			drop_at = -1.0
			dropped = _drop_fence()
		if shot_at > 0.0 and t >= shot_at:
			shot_at = -1.0
			await _shot("route_%s_%d" % [_island, i])
		if not _player.nav_active:
			break
	var left := _flat(_player.global_position).distance_to(_flat(goal_pos))
	var ok := left <= ARRIVE_M and t < limit
	var row := {
		"i": i, "ok": ok, "t": t, "ref": ref_len, "walked": walked, "ratio": walked / maxf(ref_len, 0.001),
		"deg_m": rad_to_deg(turn) / maxf(walked, 0.001), "stuck": stuck_max, "touch": touch_frames,
		"hops": hops, "hop_max": hop_max, "left": left,
		"straight": _flat(start).distance_to(_flat(goal_pos)), "drop": dropped != null,
	}
	_rows.append(row)
	_trails.append([ref, trail, touches])
	print("[route] %3d %s ref=%5.1f walked=%5.1f ratio=%.3f deg/m=%5.1f stuck=%.2f touch=%d hops=%d left=%.2f t=%.1f%s" % [
		i, "ok  " if ok else "MISS", ref_len, walked, row["ratio"], row["deg_m"], stuck_max, touch_frames, hops, left, t,
		" drop" if dropped else ""])
	if dropped and is_instance_valid(dropped):
		dropped.queue_free()  # its grid cells are released on exit
		await get_tree().physics_frame
	if not ok:
		# Stand still a beat so a failed route does not leak its motion into the next one.
		_player.clear_nav()
		for f in 10:
			await get_tree().physics_frame

func _touching_solid() -> bool:
	for k in _player.get_slide_collision_count():
		var col := _player.get_slide_collision(k)
		var who := col.get_collider()
		if who is CollisionObject3D and (who as CollisionObject3D).get_rid() == _floor_rid:
			continue
		if col.get_normal().y < 0.7:
			return true
	return false

# ---------------------------------------------------------------- summary

func _summary() -> void:
	var n := _rows.size()
	if n == 0:
		_expect(false, "routes ran")
		return
	var ok_rows: Array[Dictionary] = []
	var stuck_over := 0
	var long_ones := 0
	var hops := 0
	var touch := 0
	var t_sum := 0.0
	for r in _rows:
		if r["ok"]:
			ok_rows.append(r)
		if float(r["stuck"]) > STUCK_GATE_S:
			stuck_over += 1
		hops += int(r["hops"])
		touch += int(r["touch"])
	var ratios: Array[float] = []
	var degs: Array[float] = []
	var measured := 0
	for r in ok_rows:
		degs.append(float(r["deg_m"]))
		t_sum += float(r["t"])
		if r["drop"]:
			continue
		measured += 1
		ratios.append(float(r["ratio"]))
		if float(r["ratio"]) > LENGTH_GATE:
			long_ones += 1
	ratios.sort()
	degs.sort()
	var success := float(ok_rows.size()) / float(n)
	var deg_mean := _mean(degs)
	print("[route] summary island=%s routes=%d ok=%d (%.1f%%) stuck>2s=%d ratio mean=%.3f p95=%.3f max=%.3f over%.2f=%d deg/m mean=%.2f p50=%.2f p95=%.2f max=%.2f touch_frames=%d hops=%d mean_t=%.2fs drops=%d" % [
		_island, n, ok_rows.size(), success * 100.0, stuck_over, _mean(ratios), _pct(ratios, 0.95), _pct(ratios, 1.0),
		LENGTH_GATE, long_ones, deg_mean, _pct(degs, 0.5), _pct(degs, 0.95), _pct(degs, 1.0), touch, hops,
		t_sum / maxf(1.0, float(ok_rows.size())), _drops])
	_expect(success >= SUCCESS_GATE, "success %.1f%% >= %.0f%%" % [success * 100.0, SUCCESS_GATE * 100.0])
	_expect(stuck_over == 0, "no stuck stretch over %.0f s (%d routes had one)" % [STUCK_GATE_S, stuck_over])
	_expect(float(long_ones) <= float(measured) * (1.0 - SUCCESS_GATE), "walked length <= %.2fx the reference path on >= 99%% of routes (%d of %d over)" % [LENGTH_GATE, long_ones, measured])
	_expect(hops == 0, "no hops (%d)" % hops)
	if _bound > 0.0:
		_expect(deg_mean <= _bound, "heading change %.2f deg/m <= %.2f" % [deg_mean, _bound])

static func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / float(a.size())

static func _pct(sorted: Array[float], q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(ceil(q * float(sorted.size()))) - 1, 0, sorted.size() - 1)]

# ---------------------------------------------------------------- top-view map

func _map() -> void:
	_map_image(_region, clampi(900 / maxi(_region.size.x, 1), 3, 8), "route_map_%s.png" % _island)
	if _compound_at != NO_TILE:
		_map_image(Rect2i(_compound_at - Vector2i(14, 14), Vector2i(36, 36)), 14, "route_compound_%s.png" % _island)

## Top view of `rect` at `px` pixels a tile: ground, the reference's blocked tiles (dark), tiles only the
## router blocks (brown), reference paths (blue), walked trails (yellow), contact with a solid (red).
func _map_image(rect: Rect2i, px: int, file: String) -> void:
	var img := Image.create(rect.size.x * px, rect.size.y * px, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.2, 0.32))
	var o := Vector2(rect.position)
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var tile := Vector2i(x, z)
			if not _region.has_point(tile) or not _rt.spawn_ok(BuildGrid.tile_centre(tile, _rt), false):
				continue
			var col := Color(0.32, 0.42, 0.26)
			if _ref.is_point_solid(tile):
				col = Color(0.15, 0.15, 0.13)
			elif not _rt.pathing.is_walkable(tile):
				col = Color(0.45, 0.4, 0.25)
			img.fill_rect(Rect2i((tile - rect.position) * px, Vector2i(px, px)), col)
	var to_px := func (w: Vector2) -> Vector2i: return Vector2i(((w - o) * float(px)).floor())
	for tr in _trails:
		var ref: Array[Vector2i] = tr[0]
		for k in range(1, ref.size()):
			_line(img, to_px.call(Vector2(ref[k - 1]) + Vector2(0.5, 0.5)), to_px.call(Vector2(ref[k]) + Vector2(0.5, 0.5)), Color(0.4, 0.6, 1.0))
		var trail: PackedVector2Array = tr[1]
		for k in range(1, trail.size()):
			_line(img, to_px.call(trail[k - 1]), to_px.call(trail[k]), Color(1.0, 0.95, 0.6))
		for at in (tr[2] as PackedVector2Array):
			var q: Vector2i = to_px.call(at)
			img.fill_rect(Rect2i(q - Vector2i(2, 2), Vector2i(5, 5)).intersection(Rect2i(Vector2i.ZERO, img.get_size())), Color(1, 0.15, 0.1))
	var path := _out.path_join(file)
	img.save_png(path)
	print("[route] map %s" % path)

static func _line(img: Image, a: Vector2i, b: Vector2i, col: Color) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in n + 1:
		var p := Vector2i(Vector2(a).lerp(Vector2(b), float(k) / float(maxi(n, 1))).round())
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixelv(p, col)

# ---------------------------------------------------------------- helpers

func _clear_creatures() -> void:
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Creature and not (c as Creature).is_pet:
			c.queue_free()

func _top_up() -> void:
	var v := _player.vitals
	v.health = v.effective_max_health()
	v.energy = v.max_energy
	v.fatigue = 0.0

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var vs := get_viewport().get_visible_rect().size
	var path := _out.path_join("%s_%dx%d.png" % [tag, int(vs.x), int(vs.y)])
	get_viewport().get_texture().get_image().save_png(path)
	print("[route] shot %s" % path)

func _expect(ok: bool, what: String) -> void:
	if ok:
		print("[route] ok %s" % what)
	else:
		_fails.append(what)
		print("[route] FAIL %s" % what)

func _finish() -> void:
	if _fails.is_empty():
		print("[route] PASS")
		get_tree().quit(0)
	else:
		print("[route] FAIL count=%d" % _fails.size())
		get_tree().quit(1)
