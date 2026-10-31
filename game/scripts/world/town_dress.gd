class_name TownDress
extends Node3D
## TUTTOWN (owner 2026-10-29: "It should feel like a massive town"): the tutorial island's prebuilt
## town around the camp. Districts on rings and avenues: the harbour (stone warehouses, crates, fish
## racks), the market (stalls under striped canvas), homes (timber-framed, thatched), workshops (open
## shelters with busy stations: forges and grills that glow, racks with drying meat), farms (fields
## in crop, a well, scarecrows), pens with tamed animals, and the Faction Hall (FACTIONS) across the
## square from the dock as the landmark. Lamp posts line the streets, signposts mark the avenues, and townsfolk
## idle or work at the stations.
##
## Everything here is scenery, never a building: no node is saved, damaged, claimed or packed up.
## Cheap by construction (claude/mmo-tutperf profiles this island):
##   - every model is a MultiMesh instance, batched per 40 m chunk and part, with a visibility range;
##   - collision is one PhysicsServer3D static body of boxes (no nodes); the cells go into the
##     BuildGrid so the tile router walks the streets and nothing is built over a house;
##   - no lights except the busy forges and grills (StationState, 4 at most); lamps are emissive;
##   - townsfolk and pen animals hide and stop animating past NPC_RANGE_M.
## Roads are one terrain-hugging dirt mesh. Ground cover, dressing, scenery props and non-tutorial
## harvest nodes inside a house footprint or on a road are cleared.
## # ASSUMPTION: every layout number below (rings, avenues, districts, sizes, counts); open question TT1.

const CHUNK_M := 120.0  ## TOWNPOLISH: 80 -> 120 m keeps the batch count in budget with the town kit
const GLB := "res://assets/props/blender/%s.glb"
const PLAZA_R := 24.0  ## the camp square (hall desk, faction boards, market stall, bench, pit, herbs, trees)
## TOWNPOLISH2 (owner 2026-10-30: "The town should follow the same building rules the player follows
## and lock to the grid, ideally with the default orientation of the player (facing south)"):
## streets run on the grid axes, every footprint snaps to the 1 m BuildGrid in 90 degree steps with
## the player's slope rule (BuildGrid.MAX_SLOPE_SPREAD), fronts face south (rot 0, +Z) unless the
## street is on the other side, and the palisade is a square. # ASSUMPTION: every number below.
const AVENUE_W := 6  ## the four main streets out of the square, through the gates
const ROAD_W := 4  ## the side streets
const STREET_EVERY := 24  ## streets every 24 m, E-W and N-S
const STREET_K := 3  ## streets at 0, +-24, +-48, +-72 m from the camp
const HALF := 86  ## the square palisade, metres from the camp along each axis
const WICKET_EVERY := 12  ## a 4 m wicket gap every 12 panels (~22 m) of palisade
const PANEL_M := 1.84  ## fence and palisade modules have end posts 1.84 m apart: runs step by that, so joins share one post
const NPC_RANGE_M := 60.0
## Visibility ranges, metres from the camera. TOWNPOLISH: the iso camera stands distance_for(size)
## back (186 m at the default zoom, 240 m at the widest game zoom), so the old 110 m prop range
## hid every crate, fence, field and the palisade in play, and the 220 m house range dropped houses
## at max zoom. Both now cover the widest lab zoom plus a chunk.
static var FAR_HOUSE: float = IsoCamera.cull_range(CHUNK_M)
static var FAR_PROP: float = IsoCamera.cull_range(CHUNK_M * 0.5)
const MAX_FOLK := 16  ## townsfolk rigs (each a skinned survivor body)
const PLAZA_FOLK := 8  ## FACTIONS: the Faction Hall plaza crowd, on top of MAX_FOLK (FA12)
const MAX_ANIMALS := 6

## District by angle from the dock direction (degrees, -180..180).
static func district_of(deg: float) -> StringName:
	var a := absf(deg)
	if a < 40.0:
		return &"harbour"
	if deg >= 40.0 and deg < 110.0:
		return &"market"
	if deg >= 110.0 and deg < 160.0:
		return &"homes"
	if a >= 160.0:
		return &"pens"
	if deg <= -110.0:
		return &"farms"
	return &"workshops"

var rt: IslandRuntime
var camp: Vector3
var o := Vector2i.ZERO  ## the grid origin: the camp's tile corner nearest it
var gates: Array[Vector3] = []  ## where the main streets leave through the palisade
var _tut_tiles: Dictionary = {}  ## tiles of the tutorial's own harvest nodes (orders need them)
var dock_deg := 0.0
var stats := {"houses": 0, "stalls": 0, "workshops": 0, "fields": 0, "pens": 0, "npcs": 0, "animals": 0, "lamps": 0, "instances": 0, "mmi": 0, "boxes": 0, "cleared_nodes": 0}
var npcs: Array[Node3D] = []
var cells: Dictionary = {}  ## Vector2i -> true: tiles a house, stall, shelter or pen covers
var road_tiles: Dictionary = {}
var lots: Array[Vector3] = []  ## the centre of every footprint taken (capture probes aim at these)
var soft_cells: Dictionary = {}  ## the walk-through part of cells: fields, open shelters
var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}  ## "cx:cz:part:i" -> {"mesh", "xf", "colors", "far", "shadow", "occlude"}
var _boxes: Array = []  ## [Transform3D, Vector3 size]
var _body := RID()
var _shapes: Array[RID] = []
var _npc_left := 0.0
var _plaza := false  ## FACTIONS: npc() is placing the plaza crowd (its own cap and RNG)
var _plaza_folk := 0
var _night_was := -1.0
static var _parts: Dictionary = {}  ## glb name -> Array of [Mesh, Transform3D]
static var _mats: Dictionary = {}
static var _unit: Dictionary = {}

static func build(p_rt: IslandRuntime) -> TownDress:
	var t := TownDress.new()
	t.name = "TownDress"
	t.rt = p_rt
	t.camp = p_rt._camp_pos
	t.o = Vector2i(roundi(t.camp.x), roundi(t.camp.z))
	var h := p_rt.arrival_point() - t.camp
	t.dock_deg = rad_to_deg(atan2(h.z, h.x))
	t._rng.seed = 9091
	p_rt.add_child(t)
	t._lay_out()
	return t

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _body.is_valid():
		PhysicsServer3D.free_rid(_body)
		for sh in _shapes:
			PhysicsServer3D.free_rid(sh)

## Point at `deg` from the dock direction, `r` metres from the camp, on the ground.
func polar(deg: float, r: float) -> Vector3:
	var a := deg_to_rad(dock_deg + deg)
	var p := camp + Vector3(cos(a), 0.0, sin(a)) * r
	p.y = rt.surface_y(p.x, p.z)
	return p

## Yaw (radians, about +Y) that turns local +Z to point from the camp outward at `deg`.
func yaw_out(deg: float) -> float:
	var a := deg_to_rad(dock_deg + deg)
	return atan2(cos(a), sin(a))

static func _wrap(d: float) -> float:
	return wrapf(d, -180.0, 180.0)

## Half width (tiles) of street k (0 = a main avenue).
static func _half_w(k: int) -> int:
	return AVENUE_W / 2 if k == 0 else ROAD_W / 2

## Chebyshev distance (m) from the camp: the town is square, so "how far out" is the larger axis.
func out_of(p: Vector3) -> float:
	return maxf(absf(p.x - camp.x), absf(p.z - camp.z))

# ---------------------------------------------------------------- layout

func _lay_out() -> void:
	var t0 := Time.get_ticks_msec()
	_guild_hall()
	_adventurers_guild()
	_pit_shelter()
	for key in rt._harvest_nodes.keys():
		var node: Variant = rt._harvest_nodes[key]
		if str(key).begins_with("tutorial_") and is_instance_valid(node) and node is Node3D:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					_tut_tiles[BuildGrid.tile_of((node as Node3D).global_position) + Vector2i(dx, dz)] = true
	_street_tiles()
	_rows()
	_harbour()
	_infill()
	_greenery()
	_clutter()
	_wall()
	_roads()
	_street_props()
	_flush()
	_clear_ground()
	_domain()
	print("[tuttown] town built in %d ms: %s refused=%s" % [Time.get_ticks_msec() - t0, stats, refused])

## TOWNPOLISH2 (owner 2026-10-30: "with the town's domain, you should give it some name and profile
## picture and extend the domain to encompass the entire town"): the whole square inside and up to
## the palisade is the town's domain, a claim row with the island's town_name and town_emblem, so the
## domain banner and the claim outline show it like a survivor's land.
func _domain() -> void:
	var def: Dictionary = World.def_of(&"tutorial_isle") if World else {}
	var nm := str(def.get("town_name", ""))
	if nm == "":
		return
	var r := Rect2i(o.x - HALF - 1, o.y - HALF - 1, HALF * 2 + 2, HALF * 2 + 2)
	rt.set_other_claims([{"rect": [r.position.x, r.position.y, r.size.x, r.size.y],
		"owner": {"id": "town_" + nm.to_lower(), "name": nm, "emblem": str(def.get("town_emblem", ""))}}])
	stats["domain"] = nm

## The street grid's tiles: avenue k = 0 on both axes runs out through the gates, side streets stop
## inside the palisade; none crosses the square, a footprint already taken (the guild hall) or water.
func _street_tiles() -> void:
	for k in range(-STREET_K, STREET_K + 1):
		var hw := _half_w(k)
		var s := STREET_EVERY * k
		for a in range(-HALF - 8, HALF + 8):
			if k != 0 and absi(a) >= HALF - 1:
				continue
			for e in range(-hw, hw):
				_road_tile(Vector2i(o.x + a, o.y + s + e))
				_road_tile(Vector2i(o.x + s + e, o.y + a))

func _road_tile(t: Vector2i) -> void:
	var q := Vector3(float(t.x) + 0.5, 0.0, float(t.y) + 0.5)
	if Vector2(q.x - camp.x, q.z - camp.z).length() < PLAZA_R - 2.0:
		return
	if cells.has(t) or rt.build_grid._occupied.has(t) or not rt.is_dry(q):
		return
	road_tiles[t] = true

## Lots along both sides of every E-W street, west to east: the row north of a street faces south
## (rot 0, the player's default), the row south of it faces north onto it (rot 2).
func _rows() -> void:
	for k in range(-STREET_K, STREET_K + 1):
		var zs := o.y + STREET_EVERY * k
		var hw := _half_w(k)
		for side in [-1, 1]:
			var x := o.x - HALF + 3
			while x < o.x + HALF - 3:
				x += _row_lot(x, zs, hw, side) + 2

## One lot at tile column x beside street zs: its kind by district and distance out. Returns the
## width used (2 when nothing fitted, so the walk moves on).
func _row_lot(x: int, zs: int, hw: int, side: int) -> int:
	var probe := Vector3(float(x) + 3.0, 0.0, float(zs) + float(side) * (float(hw) + 4.0))
	var dist := district_of(_deg_of(probe))
	var near := out_of(probe)
	var w := 2 * _rng.randi_range(2, 3)
	var d := 4 if near < 36.0 else 2 * _rng.randi_range(2, 3)
	if near > 56.0 and _rng.randf() < 0.25:
		w = 8  # a long house now and then
	var kind := "house"
	var style := "timber" if _rng.randf() < 0.7 else "plain"
	match dist:
		&"market":
			if near < 36.0 or (near < 60.0 and _rng.randf() < 0.5):
				kind = "stall"
				w = 4
				d = 3
			else:
				style = "plain"
		&"workshops":
			if near < 60.0:
				kind = "workshop"
				w = 6
				d = 5
			else:
				style = "stone"
		&"farms":
			if near >= 36.0:
				kind = "field"
				w = 8
				d = 6
		&"pens":
			if near > 56.0:
				kind = "pen"
				w = 10
				d = 8
			elif near >= 36.0:
				kind = "tent"
				w = 6
				d = 4
		&"harbour":
			style = "stone"
			w = 6
			d = 6
	var lot := _grid_at(x, zs, hw, side, w, d)
	if lot.is_empty():
		return 2
	match kind:
		"stall":
			_stall_lot(lot)
		"workshop":
			_workshop_lot(lot)
		"field":
			_field_lot(lot)
		"pen":
			_pen_lot(lot)
		"tent":
			_tent_lot(lot)
		_:
			_house_lot(lot, w, d, style, 2 if near < 40.0 and _rng.randf() < 0.3 else 1)
	return w

## A w x d footprint with its NW tile column at x, one tile back from street zs on `side` (-1 north,
## +1 south), front to the street. {} when the player's rules refuse it.
func _grid_at(x: int, zs: int, hw: int, side: int, w: int, d: int) -> Dictionary:
	var c := Vector3(float(x) + float(w) * 0.5, 0.0, float(zs) + float(side) * (float(hw) + 1.0 + float(d) * 0.5))
	var yaw := 0.0 if side < 0 else PI
	var base := lot_base(c, float(w), float(d), yaw)
	if is_nan(base):
		return {}
	c.y = base
	return {"c": c, "yaw": yaw, "b": Basis(Vector3.UP, yaw)}

## A rectangle (w x d around `c`, yaw a multiple of 90 degrees) passes the player's build rules:
## inside the palisade, off the square, the streets and anything taken (BuildGrid occupancy and
## reservations, the tutorial's own harvest nodes), on dry land, corner spread within
## BuildGrid.MAX_SLOPE_SPREAD. `margin` tiles round it must be free of footprints and streets too.
## Returns the base height (the lowest corner) or NAN.
func lot_base(c: Vector3, w: float, d: float, yaw: float, margin: float = 1.0) -> float:
	var swap := posmod(roundi(yaw / (PI * 0.5)), 2) == 1
	var ww := d if swap else w
	var dd := w if swap else d
	if absf(c.x - camp.x) + ww * 0.5 > float(HALF) - 2.0 or absf(c.z - camp.z) + dd * 0.5 > float(HALF) - 2.0:
		return _no("ring")
	var nearest := Vector2(clampf(camp.x, c.x - ww * 0.5, c.x + ww * 0.5), clampf(camp.z, c.z - dd * 0.5, c.z + dd * 0.5))
	if nearest.distance_to(Vector2(camp.x, camp.z)) < PLAZA_R:
		return _no("plaza")
	var x0 := floori(c.x - ww * 0.5 + 0.01)
	var z0 := floori(c.z - dd * 0.5 + 0.01)
	var x1 := ceili(c.x + ww * 0.5 - 0.01)
	var z1 := ceili(c.z + dd * 0.5 - 0.01)
	var m := floori(margin + 0.5)
	for tx in range(x0 - m, x1 + m):
		for tz in range(z0 - m, z1 + m):
			var t := Vector2i(tx, tz)
			if cells.has(t):
				return _no("taken")
			if road_tiles.has(t):
				return _no("street")
			if tx < x0 or tx >= x1 or tz < z0 or tz >= z1:
				continue
			if rt.build_grid._occupied.has(t) or rt.build_grid._reserved.has(t):
				return _no("taken")
			if _tut_tiles.has(t):
				return _no("resource")
			var q := Vector3(float(tx) + 0.5, 0.0, float(tz) + 0.5)
			if not rt.is_dry(q) or not rt.spawn_ok(q, false):
				return _no("wet")
	var lo := INF
	var hi := -INF
	for q: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		var y := rt.surface_y(q.x, q.y)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	if hi - lo > BuildGrid.MAX_SLOPE_SPREAD:
		return _no("steep")
	return lo

## Counts why lots were refused (the build line prints it; tuning the layout reads it).
var refused: Dictionary = {}
func _no(why: String) -> float:
	refused[why] = int(refused.get(why, 0)) + 1
	return NAN

func _rect_tiles(c: Vector3, w: float, d: float, yaw: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var b := Basis(Vector3.UP, yaw)
	var nx := int(ceil(w))
	var nz := int(ceil(d))
	var seen := {}
	for i in nx * 2 + 1:
		for j in nz * 2 + 1:
			# Inset 1 cm: an edge on a tile line must not take the tile past it.
			var q := c + b * Vector3(-w * 0.5 + 0.01 + float(i) * (w - 0.02) / float(nx * 2), 0.0, -d * 0.5 + 0.01 + float(j) * (d - 0.02) / float(nz * 2))
			var t := BuildGrid.tile_of(q)
			if not seen.has(t):
				seen[t] = true
				out.append(t)
	return out

## TOWNPOLISH2: a small solid (post, lamp, tree trunk, gate tower) standing at `at`: its collision box,
## and every tile within a walker's radius of it closed to the router. One tile per post let the
## router's string-pulled line graze the box (the tutorial bot wedged on a gate tower; factions found
## the same with a bench).
const WALKER_R := 0.4
func _solid(at: Vector3, size: Vector3) -> void:
	_boxes.append([Transform3D(Basis(), at + Vector3(0, size.y * 0.5, 0)), size])
	for t in _rect_tiles(at, size.x + WALKER_R * 2.0, size.z + WALKER_R * 2.0, 0.0):
		cells[t] = true

## Mark a footprint taken (cells for the router and the build grid) and add its collision box.
func _take(c: Vector3, w: float, d: float, h: float, yaw: float, solid: bool = true) -> void:
	lots.append(c)
	for t in _rect_tiles(c, w, d, yaw):
		cells[t] = true
		if not solid:
			soft_cells[t] = true
	if solid:
		_boxes.append([Transform3D(Basis(Vector3.UP, yaw), c + Vector3(0, h * 0.5, 0)), Vector3(w, h, d)])

# ---------------------------------------------------------------- houses

const WALLS := {
	"timber": ["house_wall_timber", "house_wall_window_timber"],
	"plain": ["house_wall", "house_wall_window"],
	"stone": ["house_wall_stone", "house_wall_window_stone"],
}
const ROOF_COLORS := {"timber": Color(0.78, 0.64, 0.36), "plain": Color(0.72, 0.58, 0.33), "stone": Color(0.42, 0.40, 0.40)}
## Roof finishes (one material, coloured per instance): thatch, wood shingle, slate, fired tile.
const ROOFS := {"thatch": Color(0.80, 0.66, 0.38), "shingle": Color(0.45, 0.30, 0.20), "slate": Color(0.34, 0.37, 0.42), "tile": Color(0.66, 0.30, 0.20)}
const ROOF_BY_STYLE := {"timber": ["thatch", "thatch", "shingle", "tile"], "plain": ["thatch", "tile", "shingle"], "stone": ["slate", "slate", "tile"]}

func _house_lot(lot: Dictionary, w: int, d: int, style: String, storeys: int) -> void:
	house(lot["c"], w, d, lot["yaw"], style, storeys)
	# Life at the door: a barrel, crates or a bench beside it.
	var b: Basis = lot["b"]
	var door: Vector3 = (lot["c"] as Vector3) + b * Vector3(float(w) * 0.5 - 0.6, 0.0, float(d) * 0.5 + 0.7)
	var pick: String = ["barrel", "large_box", "basket", "bucket", "chest"][_rng.randi_range(0, 4)]
	prop(pick, door, lot["yaw"])
	_door_path(lot["c"], b, float(d))
	if _rng.randf() < 0.45:
		_garden((lot["c"] as Vector3) + b * Vector3(0, 0, -float(d) * 0.5 - 3.0), float(w), lot["yaw"])
	if district_of(_deg_of(lot["c"])) == &"market" and _rng.randf() < 0.5:
		prop("sign", (lot["c"] as Vector3) + b * Vector3(-float(w) * 0.5 + 0.4, 0, float(d) * 0.5 + 0.6), lot["yaw"])

## A short footpath from a front door out to the street (a strip in the road mesh).
var _paths: Array = []  ## [from, to]
func _door_path(c: Vector3, b: Basis, d: float) -> void:
	var from := c + b * Vector3(0, 0, d * 0.5 + 0.4)
	var dir := b * Vector3(0, 0, 1)
	var to := from
	for k in 16:
		to = from + dir * float(k)
		var t := BuildGrid.tile_of(to)
		if road_tiles.has(t):
			break
		if k > 0 and cells.has(t) or not rt.is_dry(to) or k == 15:
			return  # a path that would cross another lot or never meets a street is no path
	if from.distance_to(to) > 0.9:
		_paths.append([from, to])

## A fenced kitchen garden behind a house: crop rows, sometimes a scarecrow or a water butt.
func _garden(c: Vector3, w: float, yaw: float) -> void:
	var gw := maxf(w, 4.0)
	if is_nan(lot_base(c, gw, 4.0, yaw, 0.3)):
		return
	var b := Basis(Vector3.UP, yaw)
	for i in int(gw / 2.0):
		var stage: String = ["field_crop_1", "field_crop_2", "field_crop_3", "field_tilled"][_rng.randi_range(0, 3)]
		var at := c + b * Vector3(-gw * 0.5 + 1.0 + 2.0 * float(i), 0, 0)
		at.y = rt.surface_y(at.x, at.z)
		prop(stage, at, yaw, 0.8)
	_fence_rect(c, gw + 0.4, 3.8, yaw, false)
	if _rng.randf() < 0.3:
		prop(["scarecrow", "barrel", "compost_heap"][_rng.randi_range(0, 2)], c + b * Vector3(gw * 0.5 + 0.8, 0, 0), yaw)
	_take(c, gw + 0.4, 3.8, 1.2, yaw, false)
	stats["gardens"] = int(stats.get("gardens", 0)) + 1

## A house: stone plinth, 2 m wall panels of one style (a doorway in front, windows here and there),
## timber corner posts and one town-kit roof (tools/blender/structures/townkit.py) sized to the plan,
## so the slopes, gable ends and ridge always sit on the walls. Local +Z is the front.
## TOWNPOLISH: the roof was a unit prism with a flat plaster triangle per gable that lit blue and
## floated; the door leaf hung half outside its doorway. Windows get a night glow; doors an awning
## now and then, front windows a flower box, side walls a woodpile.
## ISOCAM: `corner_door` cuts the front-right corner (south-east at yaw 0, the corner nearest the iso
## camera) on a 45 deg chamfer that holds the door, with windows above it.
func house(c: Vector3, w: int, d: int, yaw: float, style: String, storeys: int = 1, corner_door: bool = false) -> void:
	var b := Basis(Vector3.UP, yaw)
	var lo := INF
	for k in 4:
		var q := c + b * Vector3((float(k % 2) - 0.5) * float(w), 0.0, (float(k / 2) - 0.5) * float(d))
		lo = minf(lo, rt.surface_y(q.x, q.z))
	var top := c.y + 0.35
	var plinth_h := top - lo + 0.25
	unit("plinth", Transform3D(b.scaled_local(Vector3(float(w) + 0.3, plinth_h, float(d) + 0.3)), Vector3(c.x, lo - 0.25, c.z)), Color(0.5, 0.48, 0.45), FAR_HOUSE)
	var pair: Array = WALLS.get(style, WALLS["timber"])
	var wall_h := 2.4
	var extras := _rng.randf()
	for st in storeys:
		var y := top + wall_h * float(st)
		var wall_style: Array = pair if st == 0 or style != "stone" else WALLS["timber"]  # a stone hall gets a timber upper floor
		for side in 4:
			var along := w if side % 2 == 0 else d
			var across := d if side % 2 == 0 else w
			var sb := Basis(Vector3.UP, yaw + float(side) * PI * 0.5)
			var n := along / 2
			for i in n:
				if corner_door and (side == 0 and i == n - 1 or side == 1 and i == 0):
					continue  # the chamfer below stands in for these two panels
				var off := Vector3(-float(along) * 0.5 + 1.0 + 2.0 * float(i), 0.0, float(across) * 0.5)
				var at := Vector3(c.x, y, c.z) + sb * off
				var part: String = wall_style[0]
				if side == 0 and st == 0 and i == n / 2 and not corner_door:
					part = "house_wall_doorway"
					# The leaf's origin is its hinge (house kit): hang it on the doorway's left jamb.
					part_at("house_door", Transform3D(sb, at + sb * Vector3(-0.475, 0, 0.0)), FAR_HOUSE)
					if extras < 0.35:
						part_at("town_awning", Transform3D(sb, at + sb * Vector3(0, 2.25, 0.12)), FAR_HOUSE)
				elif _rng.randf() < 0.45:
					part = wall_style[1]
					# Warm glass behind the frame: dark by day, lit at night (_night).
					unit("winglow", Transform3D(sb.scaled_local(Vector3(0.86, 0.86, 0.04)), at + sb * Vector3(0, 1.02, 0.0)), Color.WHITE, FAR_HOUSE)
					if side == 0 and st == 0 and extras > 0.5:
						part_at("town_flowerbox", Transform3D(sb, at + sb * Vector3(0, 0.98, 0.2)), FAR_PROP)
				elif side == 1 and st == 0 and extras > 0.75 and i == 0:
					part_at("town_woodpile", Transform3D(sb, at + sb * Vector3(0, 0, 0.55)), FAR_PROP)
				part_at(part, Transform3D(sb, at), FAR_HOUSE, true)
			var posts: Array[Vector3] = []
			for k in 4:
				posts.append(Vector3((float(k % 2) - 0.5) * float(w), 0.0, (float(k / 2) - 0.5) * float(d)))
			if corner_door:
				posts[3] = Vector3(float(w) * 0.5 - 2.0, 0.0, float(d) * 0.5)
				posts.append(Vector3(float(w) * 0.5, 0.0, float(d) * 0.5 - 2.0))
				_chamfer(c, b, y, w, d, yaw, wall_style, st == 0)
			for q in posts:
				unit("box", Transform3D(b.scaled_local(Vector3(0.32, wall_h, 0.32)), Vector3(c.x, y, c.z) + b * q), Color(0.33, 0.22, 0.13), FAR_HOUSE)
	var eave := top + wall_h * float(storeys)
	var span := mini(w, d)
	var long := maxi(w, d)
	var rb := b if w >= d else Basis(Vector3.UP, yaw + PI * 0.5)  # ridge along the long side
	var finishes: Array = ROOF_BY_STYLE.get(style, ROOF_BY_STYLE["timber"])
	var fin: String = finishes[_rng.randi_range(0, finishes.size() - 1)]
	var roof := "town_roof_%s_%dx%d" % [fin, long, span]
	if not ResourceLoader.exists(GLB % roof):
		roof = "town_roof_%s_%dx%d" % [fin, 6 if span <= 4 else 8, 4 if span <= 4 else 6]
	part_at(roof, Transform3D(rb, Vector3(c.x, eave, c.z)), FAR_HOUSE, true)
	var rh := float(span) * 0.5 * (0.9 if fin == "thatch" else 0.62)
	if style == "stone" or _rng.randf() < 0.45:
		var ch := Vector3(c.x, eave, c.z) + rb * Vector3(float(long) * 0.3 * (1.0 if extras < 0.5 else -1.0), 0, -0.55)
		part_at("town_chimney", Transform3D(rb, ch), FAR_HOUSE)
	_take(c, float(w), float(d), eave + rh - c.y, yaw)
	stats["houses"] += 1

## The corner door's wall: a 2.83 m run across the cut corner, facing the camera's diagonal: the
## doorway (or a window upstairs) in the middle and a plain sliver either side.
func _chamfer(c: Vector3, b: Basis, y: float, w: int, d: int, yaw: float, wall_style: Array, ground: bool) -> void:
	var cb := Basis(Vector3.UP, yaw + PI * 0.25)
	var at := Vector3(c.x, y, c.z) + b * Vector3(float(w) * 0.5 - 1.0, 0.0, float(d) * 0.5 - 1.0)
	if ground:
		part_at("house_wall_doorway", Transform3D(cb, at), FAR_HOUSE, true)
		part_at("house_door", Transform3D(cb, at + cb * Vector3(-0.475, 0, 0.0)), FAR_HOUSE)
		part_at("town_awning", Transform3D(cb, at + cb * Vector3(0, 2.25, 0.12)), FAR_HOUSE)
	else:
		part_at(wall_style[1], Transform3D(cb, at), FAR_HOUSE, true)
		unit("winglow", Transform3D(cb.scaled_local(Vector3(0.86, 0.86, 0.04)), at + cb * Vector3(0, 1.02, 0.0)), Color.WHITE, FAR_HOUSE)
	var sliver := (2.0 * sqrt(2.0) - 2.0) * 0.5  # metres each side of the 2 m panel
	for sgn in [-1.0, 1.0]:
		part_at(wall_style[0], Transform3D(cb.scaled_local(Vector3(sliver * 0.5, 1.0, 1.0)), at + cb * Vector3(sgn * (1.0 + sliver * 0.5), 0, 0)), FAR_HOUSE, true)

# ---------------------------------------------------------------- the Adventurer's Guild

## ISOCAM (owner 2026-10-30: "make some buildings where the south corner is the door, we can interact
## with it (Adventurer's Guild or whatever)"): a two-storey hall on the grid beside the dock avenue,
## just south of the square, its door on the south-east corner (the one the iso camera looks at). The
## whole building is one TownBuilding (role adventurers_guild): a tap anywhere on it does what the
## Faction Hall's desk does. # ASSUMPTION: size, spot and style (open question ISOCAM).
const ADV_W := 10
const ADV_D := 8
func _adventurers_guild() -> void:
	var c := Vector3.INF
	# West of the avenue (its door then faces the avenue), first lot the player's build rules allow.
	for z in [31, 57, -21, -45]:
		var q := Vector3(float(o.x - AVENUE_W / 2 - 2) - float(ADV_W) * 0.5, 0.0, float(o.y + z))
		var base := lot_base(q, float(ADV_W), float(ADV_D), 0.0)
		if not is_nan(base):
			c = Vector3(q.x, base, q.z)
			break
	if c == Vector3.INF:
		return
	house(c, ADV_W, ADV_D, 0.0, "stone", 2, true)
	_boxes.pop_back()  # the house's box: the TownBuilding below carries the same box and takes the taps
	_pad_cells(c, float(ADV_W), float(ADV_D), 0.0)
	var gb := TownBuilding.make(&"sign", &"adventurers_guild", "Adventurer's Guild")
	rt._camp_place(gb, "AdventurersGuild", &"sign", BuildGrid.tile_of(c))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var h := 6.0
	box.size = Vector3(float(ADV_W), h, float(ADV_D))
	shape.shape = box
	gb.add_child(shape)
	shape.global_position = c + Vector3(0, h * 0.5, 0)
	var door := c + Vector3(float(ADV_W) * 0.5 - 0.6, 0.0, float(ADV_D) * 0.5 - 0.6)
	prop("signpost", door + Vector3(1, 0, 1).normalized() * 2.0 + Vector3(-1, 0, 1).normalized() * 2.2, PI * 0.25)
	stats["adventurers_guild"] = [c.x, c.z]

# ---------------------------------------------------------------- the Faction Hall

## FACTIONS (docs/design/factions.md §6): the Faction Hall, the island's Communications Center, stands
## across the square from the dock behind its desk (TownGuild keeps the tap): a two-storey stone hall
## with two one-storey wings, the five faction banners on tall poles along its front (banner order:
## Company, Chlorophyll Forum, Radio University over the door, Pioneer Council, Committee, so the two
## rivals hang on opposite wings), lamps at the door. Each faction board (TownBuilding "faction_board")
## gets a stall canvas in its faction's colour; benches ring the square; survivors stand in groups at
## the boards and walk dock -> square and along the hall front. # ASSUMPTION: sizes and counts (FA11, FA12).
const HALL_W := 14
const HALL_D := 10
const PLAZA_FOLK_IDLE := 6
func _guild_hall() -> void:
	var g := Vector3.INF
	for n in get_tree().get_nodes_in_group("town_building"):
		if n.get("role") == &"guild" and rt.is_ancestor_of(n):
			g = (n as Node3D).global_position
	if g == Vector3.INF:
		return
	# On the grid, front to the south (+Z) like a building the player places with its default rotation.
	var away := Vector3(0, 0, -1)
	var c := (g + away * (float(HALL_D) * 0.5 + 3.5)).round()
	c.y = rt.surface_y(c.x, c.z)
	var yaw := 0.0
	var b := Basis(Vector3.UP, yaw)
	house(c, HALL_W, HALL_D, yaw, "stone", 2)
	# The hall stands where the land starts to rise behind the square: a tall collider over the hall
	# and each wing, so nobody walks off the slope onto a roof (the house box stops at the ridge).
	_boxes.append([Transform3D(b, c + Vector3(0, 8.0, 0)), Vector3(HALL_W, 16.0, HALL_D)])
	for side in [-1.0, 1.0]:
		var wc := c + b * Vector3(side * (float(HALL_W) * 0.5 + 3.0), 0, 1.0)  # flush with the hall: no seam the router would think walkable
		wc.y = rt.surface_y(wc.x, wc.z)
		house(wc, 6, 8, yaw, "stone", 1)
		_boxes.append([Transform3D(b, wc + Vector3(0, 8.0, 0)), Vector3(6.0, 16.0, 8.0)])
		_pad_cells(wc, 6.0, 8.0, yaw)
	_pad_cells(c, float(HALL_W), float(HALL_D), yaw)
	var door := c + b * Vector3(0, 0, float(HALL_D) * 0.5 + 0.6)
	for s in [-2.0, 2.0]:
		lamp(door + b * Vector3(s, 0, 0.4), 2.4)
	var order := ["company", "chlorophyll_forum", "radio_university", "pioneer_council", "committee"]
	for i in order.size():
		var f := Factions.def(order[i])
		var col := Color(str(f.get("colour", "#888888")))
		var trim := Color(str(f.get("trim", "#cccccc")))
		if i == 2:  # the centre banner hangs on the hall front over the door, no pole in the doorway
			var hb := c + b * Vector3(0, 0, float(HALL_D) * 0.5 + 0.25)
			unit("box", Transform3D(b.scaled(Vector3(2.4, 1.9, 0.08)), hb + Vector3(0, 3.1, 0)), col, FAR_HOUSE)
			unit("box", Transform3D(b.scaled(Vector3(2.4, 0.35, 0.09)), hb + Vector3(0, 2.75, 0)), trim, FAR_HOUSE)
			continue
		var pole := c + b * Vector3([-9.0, -5.0, 0.0, 5.0, 9.0][i], 0, float(HALL_D) * 0.5 + 1.6)
		pole.y = rt.surface_y(pole.x, pole.z)
		var h := 8.5
		unit("box", Transform3D(b.scaled(Vector3(0.2, h, 0.2)), pole), Color(0.3, 0.2, 0.12), FAR_HOUSE)
		# A hanging banner: the faction colour with its trim colour as a band below.
		unit("box", Transform3D(b.scaled(Vector3(1.5, 2.6, 0.08)), pole + Vector3(0, h - 3.0, 0) + b * Vector3(0, 0, 0.18)), col, FAR_HOUSE)
		unit("box", Transform3D(b.scaled(Vector3(1.5, 0.35, 0.09)), pole + Vector3(0, h - 3.35, 0) + b * Vector3(0, 0, 0.18)), trim, FAR_HOUSE)
		unit("box", Transform3D(b.scaled(Vector3(1.8, 0.12, 0.12)), pole + Vector3(0, h - 0.4, 0)), Color(0.3, 0.2, 0.12), FAR_HOUSE)
		_boxes.append([Transform3D(b, pole + Vector3(0, h * 0.5, 0)), Vector3(0.25, h, 0.25)])
		cells[BuildGrid.tile_of(pole)] = true
	prop("signpost", door + b * Vector3(3.6, 0, 1.4), yaw)
	_pad_cells(g, 3.0, 3.0, yaw)  # and of the hall desk
	_boards()
	_benches()
	# The plaza crowd draws its looks from its own RNG, so the districts' townsfolk come out as before.
	var keep := _rng
	_rng = RandomNumberGenerator.new()
	_rng.seed = 4242
	_plaza = true
	_plaza_crowd(g, away)
	_plaza = false
	_rng = keep

## A 1 m ring of router cells round a turned footprint: the tile router samples a rotated rectangle's
## inside only, so a path could hug a corner the survivor's capsule then sticks on.
func _pad_cells(c: Vector3, w: float, d: float, yaw: float) -> void:
	for t in _rect_tiles(c, w + 2.0, d + 2.0, yaw):
		cells[t] = true

## A stall over each faction board: four posts, a canvas in the faction colour, a counter in front.
func _boards() -> void:
	for n in get_tree().get_nodes_in_group("town_building"):
		if n.get("role") != &"faction_board" or not rt.is_ancestor_of(n):
			continue
		var at := (n as Node3D).global_position
		var yaw := 0.0  # grid default: the stall's front faces south
		var bb := Basis(Vector3.UP, yaw)
		var fid := str(n.get("faction"))
		var col := Color(str(Factions.def(fid).get("colour", "#8a6a3a"))) if fid != "" else Color(0.55, 0.42, 0.26)
		for k in 4:
			var q := at + bb * Vector3((float(k % 2) - 0.5) * 3.0, 0.0, (float(k / 2) - 0.5) * 2.2 - 0.2)
			q.y = rt.surface_y(q.x, q.z)
			unit("box", Transform3D(bb.scaled(Vector3(0.14, 2.6, 0.14)), q), Color(0.36, 0.25, 0.14), FAR_PROP)
		unit("box", Transform3D(bb.scaled(Vector3(3.6, 0.16, 2.9)), at + Vector3(0, 2.6, 0)), col, FAR_PROP)  # the awning, flat in the faction colour
		if fid != "":
			unit("box", Transform3D(bb.scaled(Vector3(3.2, 0.3, 0.06)), at + Vector3(0, 2.25, 0) + bb * Vector3(0, 0, 1.2)), Color(str(Factions.def(fid).get("trim", "#cccccc"))), FAR_PROP)
		prop("barrel" if fid == "" else "large_box", at + bb * Vector3(-1.9, 0, -0.3), yaw + 0.3, 0.8)
		_pad_cells(at, 1.0, 1.0, yaw)  # the router keeps a step clear of the board's post (the bot snagged on it)
		stats["boards"] = int(stats.get("boards", 0)) + 1

## Benches round the square's edge between the avenues: the gathering spots of a busy hub.
func _benches() -> void:
	for deg in [-118.0, -100.0, -40.0, -22.0, 22.0, 40.0, 100.0, 118.0]:
		var p := polar(deg, PLAZA_R - 2.5)
		if not rt.is_dry(p) or cells.has(BuildGrid.tile_of(p)) or rt.build_grid._occupied.has(BuildGrid.tile_of(p)):
			continue
		p = Vector3(floorf(p.x) + 0.5, p.y, floorf(p.z) + 0.5)  # on a grid tile
		var yaw := snappedf(yaw_out(deg) + PI, PI * 0.5)  # seat faces the square, in 90 degree steps
		var bb := Basis(Vector3.UP, yaw)
		unit("box", Transform3D(bb.scaled(Vector3(1.8, 0.12, 0.5)), p + Vector3(0, 0.42, 0)), Color(0.45, 0.31, 0.17), FAR_PROP)
		unit("box", Transform3D(bb.scaled(Vector3(1.8, 0.5, 0.1)), p + Vector3(0, 0.5, 0) + bb * Vector3(0, 0, -0.25)), Color(0.42, 0.29, 0.16), FAR_PROP)
		for s in [-0.75, 0.75]:
			unit("box", Transform3D(bb.scaled(Vector3(0.12, 0.42, 0.42)), p + bb * Vector3(s, 0, 0)), Color(0.33, 0.22, 0.13), FAR_PROP)
		_boxes.append([Transform3D(bb, p + Vector3(0, 0.3, 0)), Vector3(1.8, 0.6, 0.5)])
		for t in _rect_tiles(p, 1.8, 0.5, yaw):  # every tile the seat covers, so the router walks round it
			cells[t] = true
		stats["benches"] = int(stats.get("benches", 0)) + 1

## Survivors milling: pairs at the boards (taking work), a walker from the dock to the square and one
## along the hall front. Stand-ins for real players until the server exists (FA12).
func _plaza_crowd(desk: Vector3, away: Vector3) -> void:
	var boards: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("town_building"):
		if (n.get("role") == &"faction_board" or n.get("role") == &"guild") and rt.is_ancestor_of(n):
			boards.append(n as Node3D)
	var idle := 0
	for i in boards.size():
		if idle >= PLAZA_FOLK_IDLE:
			break
		var at := boards[i].global_position
		var to_sq := Vector3(camp.x - at.x, 0, camp.z - at.z).normalized()
		var side := Vector3(-to_sq.z, 0, to_sq.x)
		var spot := at + to_sq * 2.4 + side * (0.7 if i % 2 == 0 else -0.7)
		if rt.is_dry(spot) and npc(spot, atan2(-to_sq.x, -to_sq.z), &"idle") != null:
			idle += 1
	var dock := rt.arrival_point()
	walker(dock + (camp - dock).normalized() * 3.0, polar(0.0, PLAZA_R - 6.0))
	var across := Vector3(-away.z, 0, away.x)
	walker(desk - away * 4.0 - across * 9.0, desk - away * 4.0 + across * 9.0)

## The square's stone fire pit stands under an open timber shelter (four posts and a thatched roof),
## so rain never stops the "light the fire" order (FireWeather.roof_over reads the fire_roof marker).
func _pit_shelter() -> void:
	var pit: Node3D = null
	for n in get_tree().get_nodes_in_group("bonfire"):
		if n.get("kind") == &"stone_fire_pit" and rt.is_ancestor_of(n):
			pit = n
	if pit == null:
		return
	var c := pit.global_position
	var y := c.y
	for k in 4:
		var q := c + Vector3((float(k % 2) - 0.5) * 4.4, 0.0, (float(k / 2) - 0.5) * 4.4)
		q.y = rt.surface_y(q.x, q.z)
		unit("box", Transform3D(Basis().scaled(Vector3(0.22, y + 2.9 - q.y, 0.22)), q), Color(0.34, 0.23, 0.13), FAR_HOUSE)
		_boxes.append([Transform3D(Basis(), q + Vector3(0, 1.4, 0)), Vector3(0.25, 2.8, 0.25)])
		cells[BuildGrid.tile_of(q)] = true
	unit("roof", Transform3D(Basis().scaled(Vector3(5.2, 1.3, 5.2)), Vector3(c.x, y + 2.9, c.z)), ROOFS["thatch"], FAR_HOUSE, true)
	var marker := Node3D.new()
	marker.name = "PitShelterRoof"
	marker.set_meta(&"half", 2.4)
	marker.add_to_group(&"fire_roof")
	add_child(marker)
	marker.global_position = Vector3(c.x, y + 3.0, c.z)

# ---------------------------------------------------------------- districts

## Market: a stall under a striped canvas (two colours), goods on the counter, barrels and baskets.
func _stall_lot(lot: Dictionary) -> void:
	var c: Vector3 = lot["c"]
	var b: Basis = lot["b"]
	var yaw: float = lot["yaw"]
	part_at("town_stall", Transform3D(b, c), FAR_PROP)
	var hues := [Color(0.75, 0.2, 0.15), Color(0.2, 0.4, 0.7), Color(0.85, 0.65, 0.2), Color(0.25, 0.55, 0.3)]
	var col: Color = hues[_rng.randi_range(0, hues.size() - 1)]
	unit("canvas", Transform3D(b.scaled_local(Vector3(4.2, 0.6, 3.2)), c + Vector3(0, 2.16, 0)), col, FAR_PROP)
	# A lantern on the front beam: the market stays lit after dark (glass + halo, no real light).
	var lan := c + b * Vector3(1.2, 1.78, 1.3)
	unit("lantern", Transform3D(b.scaled_local(Vector3(0.2, 0.28, 0.2)), lan), Color(1.0, 0.8, 0.5), FAR_PROP)
	unit("halo", Transform3D(Basis().scaled(Vector3.ONE * 1.8), lan + Vector3(0, 0.15, 0)), Color.WHITE, FAR_PROP)
	var goods := ["basket", "bucket", "chest", "barrel"]
	for i in 3:
		prop(goods[_rng.randi_range(0, 3)], c + b * Vector3(-1.2 + 1.2 * float(i), 0.9, 1.0), yaw, 0.55)
	prop("large_box", c + b * Vector3(-2.4, 0, -0.6), yaw)
	if _rng.randf() < 0.5:
		prop("sign", c + b * Vector3(1.9, 0, 1.6), yaw)
	prop(["barrel", "large_box", "basket"][_rng.randi_range(0, 2)], c + b * Vector3(2.4, 0, 0.3), yaw)
	_take(c, 4.0, 3.0, 2.4, yaw)
	stats["stalls"] += 1
	if _rng.randf() < 0.5:
		npc(c + b * Vector3(0, 0, -0.3), yaw, &"idle")

## Workshops: an open shelter over a station, its state on show. Every third one is a forge or a
## grill that is busy (StationState: hearth glow, sparks, the spit), the rest hold racks of drying
## meat, a kiln, an oven, looms or a grindstone, with a worker and the work loop.
const SHOPS := [
	["forge", "", &"work_forge"], ["drying_rack_drying", "", &"work_hang"], ["technical_workbench", "", &"work_hammer"],
	["stone_grill", "", &"work_stir"], ["kiln", "", &"idle"], ["loom", "", &"work_tan"],
	["oven", "", &"work_stir"], ["smoker", "", &"work_hang"], ["grindstone", "", &"work_hammer"],
	["large_drying_rack", "", &"work_hang"], ["journeyman_workbench", "", &"work_hammer"], ["crock_pot", "", &"work_stir"],
]
var _shop_i := 0
var _busy_lights := 0

func _workshop_lot(lot: Dictionary) -> void:
	var c: Vector3 = lot["c"]
	var b: Basis = lot["b"]
	var yaw: float = lot["yaw"]
	for k in 4:
		var q := Vector3((float(k % 2) - 0.5) * 5.6, 0.0, (float(k / 2) - 0.5) * 4.6)
		unit("box", Transform3D(b.scaled_local(Vector3(0.22, 2.7, 0.22)), c + b * q), Color(0.34, 0.23, 0.13), FAR_HOUSE)
	part_at("town_roof_%s_6x4" % ["thatch", "shingle", "tile"][_shop_i % 3], Transform3D(b, c + Vector3(0, 2.7, 0)), FAR_HOUSE, true)
	unit("plinth", Transform3D(b.scaled_local(Vector3(6.0, 0.3, 5.0)), c + Vector3(0, -0.2, 0)), Color(0.36, 0.29, 0.22), FAR_PROP)
	var row: Array = SHOPS[_shop_i % SHOPS.size()]
	_shop_i += 1
	var kind: String = row[0]
	var at := c + b * Vector3(0, 0.1, -0.6)
	if kind == "forge" or kind == "stone_grill":
		_busy_station(StringName(kind), at, yaw)
	else:
		prop(kind, at, yaw)
	prop(["barrel", "chest", "large_box", "basket"][_rng.randi_range(0, 3)], c + b * Vector3(2.2, 0.1, -1.6), yaw)
	prop("bucket", c + b * Vector3(-2.3, 0.1, -1.7), yaw)
	prop("sign", c + b * Vector3(-3.2, 0, 2.6), yaw)
	npc(c + b * Vector3(0.0, 0.1, 0.9), yaw + PI, row[2])
	_take(c, 6.0, 5.0, 2.8, yaw, false)
	for k in 4:  # only the posts block: the shelter stays walkable
		var q := Vector3((float(k % 2) - 0.5) * 5.6, 0.0, (float(k / 2) - 0.5) * 4.6)
		_boxes.append([Transform3D(b, c + b * q + Vector3(0, 1.35, 0)), Vector3(0.3, 2.7, 0.3)])
	stats["workshops"] += 1

## A station that is always at work: a plain host with StationState forced busy. Lights stay capped.
class BusyState extends StationState:
	func is_busy() -> bool:
		return true

func _busy_station(sid: StringName, at: Vector3, yaw: float) -> void:
	var host := Node3D.new()
	host.name = "Town_%s_%d" % [sid, _shop_i]
	add_child(host)
	host.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	if PropVisuals.attach_model(host, sid) == null and not StationState.config_for(sid).has("body"):
		prop("kiln", at, yaw)
	var st := BusyState.new()
	st.name = StationState.NODE_NAME
	st.station_id = sid
	st.cfg = StationState.config_for(sid).duplicate(true)
	if _busy_lights >= 4:
		st.cfg.erase("light")  # ASSUMPTION: 4 real lights in town; later forges glow by emission only
	else:
		_busy_lights += 1
	host.add_child(st)

## Farms: a fenced field in crop (four growth stages), a scarecrow or compost heap, a farmer.
func _field_lot(lot: Dictionary) -> void:
	var c: Vector3 = lot["c"]
	var b: Basis = lot["b"]
	var yaw: float = lot["yaw"]
	# TOWNPOLISH: the whole bed planted (4 x 3 modules of 2 m) in one or two crop stages, rows
	# running together, instead of six scattered patches (fields read as empty paddocks).
	var stages := ["field_crop_1", "field_crop_2", "field_crop_3", "field_crop_3", "field_tilled"]
	var s1: String = stages[_rng.randi_range(0, stages.size() - 1)]
	var s2: String = stages[_rng.randi_range(0, stages.size() - 1)]
	for i in 4:
		for j in 3:
			var at := c + b * Vector3(-3.0 + 2.0 * float(i), 0, -2.0 + 2.0 * float(j))
			at.y = rt.surface_y(at.x, at.z)  # each 2 m bed on its own ground: on a slope they sank under the grass
			prop(s1 if i < 2 else s2, at, yaw)
	_fence_rect(c, 8.6, 6.6, yaw, true)
	prop(["scarecrow", "compost_heap", "well", "trellis"][_rng.randi_range(0, 3)], c + b * Vector3(5.2, 0, 0), yaw)
	if _rng.randf() < 0.5:
		npc(c + b * Vector3(-1.2, 0, 3.8), yaw + PI, &"farm")
	_take(c, 8.6, 6.6, 1.2, yaw, false)
	stats["fields"] += 1

## Pens: a fenced paddock with a tamed animal or two (the real species art, idle loop).
const PEN_SPECIES := [&"zebraceratops", &"compsognathus"]  ## owner 2026-10-29: only these two on the tutorial island
var _pen_i := 0

func _pen_lot(lot: Dictionary) -> void:
	var c: Vector3 = lot["c"]
	var b: Basis = lot["b"]
	var yaw: float = lot["yaw"]
	_fence_rect(c, 10.0, 8.0, yaw, true)
	prop("water_trough" if ResourceLoader.exists(GLB % "water_trough") else "bucket", c + b * Vector3(-3.5, 0, -2.6), yaw)
	prop("straw_roll", c + b * Vector3(3.2, 0, -2.4), yaw + 0.3)
	var sp: StringName = PEN_SPECIES[_pen_i % PEN_SPECIES.size()]
	_pen_i += 1
	for k in (2 if sp == &"compsognathus" else 1):
		animal(sp, c + b * Vector3(-1.0 + 2.2 * float(k), 0, 0.5), yaw + _rng.randf_range(-1.2, 1.2))  # animals, not buildings: any heading
	_take(c, 10.0, 8.0, 1.5, yaw)
	stats["pens"] += 1

## Hide tents of the hunters by the north gate.
func _tent_lot(lot: Dictionary) -> void:
	var b: Basis = lot["b"]
	prop("tent" if _rng.randf() < 0.5 else "tent_canvas", (lot["c"] as Vector3) + b * Vector3(-1.2, 0, 0), lot["yaw"])
	prop("drying_rack_dried", (lot["c"] as Vector3) + b * Vector3(1.9, 0, 0), lot["yaw"])
	_take(lot["c"], 6.0, 4.0, 2.3, lot["yaw"])

func _fence_rect(c: Vector3, w: float, d: float, yaw: float, gate: bool) -> void:
	for side in 4:
		var along := w if side % 2 == 0 else d
		var across := d if side % 2 == 0 else w
		var sb := Basis(Vector3.UP, yaw + float(side) * PI * 0.5)
		# TOWNPOLISH2: n modules stretched to meet post on post (they stood 2 m apart with their own
		# end posts 1.84 m apart, so every join showed two posts); the corner posts coincide too.
		var n := maxi(1, ceili(along / PANEL_M - 0.05))
		var step := along / float(n)
		for i in n:
			var q := c + sb * Vector3(-along * 0.5 + step * (float(i) + 0.5), 0.0, across * 0.5)
			q.y = rt.surface_y(q.x, q.z)
			var nm := "gate" if gate and side == 0 and i == n / 2 else "fence"
			if ResourceLoader.exists(GLB % nm):
				part_at(nm, Transform3D(sb.scaled_local(Vector3(step / PANEL_M, 1.0, 1.0)), q), FAR_PROP)

## Fill the empty lots: every free spot left in town gets a cottage, a fenced garden or a yard
## (woodpile, crates, hay), on the grid, front to the south (the player's default facing).
func _infill() -> void:
	for gx in range(-HALF + 3, HALF - 3, 5):
		for gz in range(-HALF + 3, HALF - 3, 5):
			var c := Vector3(float(o.x + gx + _rng.randi_range(0, 2)), 0.0, float(o.y + gz + _rng.randi_range(0, 2)))
			if Vector2(c.x - camp.x, c.z - camp.z).length() < PLAZA_R + 3.0:
				continue
			var roll := _rng.randf()
			if roll < 0.55:
				var lot_y := lot_base(c, 4.0, 4.0, 0.0, 1.0)
				if is_nan(lot_y):
					continue
				c.y = lot_y
				var style: String = "stone" if district_of(_deg_of(c)) in [&"harbour", &"workshops"] else ("timber" if _rng.randf() < 0.7 else "plain")
				house(c, 4, 4, 0.0, style)
				_door_path(c, Basis.IDENTITY, 4.0)
				stats["infill"] = int(stats.get("infill", 0)) + 1
			elif roll < 0.8:
				_garden(c, 4.0, 0.0)
			else:
				c += Vector3(0.5, 0, 0.5)
				if is_nan(lot_base(c, 3.0, 3.0, 0.0, 0.3)):
					continue
				var rot := _rng.randi_range(0, 3)
				var yaw := float(rot) * PI * 0.5
				var b := Basis(Vector3.UP, yaw)
				prop(["large_box", "straw_roll", "barrel", "basket"][_rng.randi_range(0, 3)], c, yaw)
				prop(["barrel", "bucket", "chest", "large_box"][_rng.randi_range(0, 3)], c + b * Vector3(1.0, 0, 0.5), yaw)
				prop("straw_roll", c + b * Vector3(-1.0, 0, -0.5), yaw + PI * 0.5)
				_take(c, 3.0, 3.0, 1.2, 0.0)
				stats["yards"] = int(stats.get("yards", 0)) + 1

## TOWNPOLISH2: trees and shrubs on the grass the lots leave between homes (round-6 leftover). Owner
## 2026-10-30 "keep pushing to full 3D": the nature kit's own 3D models (assets/nature/generated),
## batched like every other town piece, scenery only (no harvest node). A tree's trunk tile is taken
## (collision, and the router steps round it); a shrub blocks nothing. Plants turn and scale freely:
## they are nature, not buildings, but they stand on tile centres.
const NATURE := "res://assets/nature/generated/%s.glb"
const GREEN_TREES := ["tree-common-a", "tree-common-b", "tree-birch-a", "tree-willow-a"]  ## # ASSUMPTION: the meadow's own trees
const GREEN_SHRUBS := ["bush-berries-a-empty", "bush-berries-b-empty", "plant-a"]
func _greenery() -> void:
	for gx in range(-HALF + 4, HALF - 4, 6):
		for gz in range(-HALF + 4, HALF - 4, 6):
			if _rng.randf() < 0.35:
				continue
			var c := Vector3(float(o.x + gx + _rng.randi_range(0, 2)) + 0.5, 0.0, float(o.y + gz + _rng.randi_range(0, 2)) + 0.5)
			if Vector2(c.x - camp.x, c.z - camp.z).length() < PLAZA_R + 4.0 or _in_gateway(c):
				continue
			var tree := _rng.randf() < 0.45
			if is_nan(lot_base(c, 3.0 if tree else 1.0, 3.0 if tree else 1.0, 0.0, 0.3 if tree else 0.0)):
				continue
			c.y = rt.surface_y(c.x, c.z)
			var names: Array = GREEN_TREES if tree else GREEN_SHRUBS
			var path: String = NATURE % names[_rng.randi_range(0, names.size() - 1)]
			if not ResourceLoader.exists(path):
				continue
			var h := _rng.randf_range(6.0, 8.5) if tree else _rng.randf_range(1.0, 1.6)
			var sc := h / VegBatch.mesh_height(path)
			part_at(path, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3.ONE * sc), c), FAR_HOUSE if tree else FAR_PROP, tree)
			if tree:
				_solid(c, Vector3(0.5, 3.0, 0.5))
			lots.append(c)
			stats["trees" if tree else "shrubs"] = int(stats.get("trees" if tree else "shrubs", 0)) + 1

## TOWNPOLISH: the gaps the lots leave (too small, a corner) get yard life instead of bare grass: a
## hand cart, a woodpile, barrels and crates, straw, a well now and then. On the grid, turned in
## 90 degree steps.
func _clutter() -> void:
	for gx in range(-HALF + 3, HALF - 3, 6):
		for gz in range(-HALF + 3, HALF - 3, 6):
			var c := Vector3(float(o.x + gx + _rng.randi_range(0, 3)), 0.0, float(o.y + gz + _rng.randi_range(0, 3)))
			if Vector2(c.x - camp.x, c.z - camp.z).length() < PLAZA_R + 2.0 or _rng.randf() < 0.35:
				continue
			var yaw := float(_rng.randi_range(0, 3)) * PI * 0.5
			var y := lot_base(c, 2.6, 2.6, yaw, 0.4)
			if is_nan(y):
				continue
			c.y = y
			var b := Basis(Vector3.UP, yaw)
			match _rng.randi_range(0, 5):
				0:
					prop("town_cart", c, yaw)
				1:
					prop("town_woodpile", c, yaw)
					prop("large_box", c + b * Vector3(1.3, 0, 0.2), yaw)
				2:
					prop("barrel", c, yaw)
					prop("barrel", c + b * Vector3(0.7, 0, 0.2), yaw)
					prop("large_box", c + b * Vector3(-0.8, 0, 0.1), yaw)
				3:
					prop("straw_roll", c, yaw)
					prop("straw_roll", c + b * Vector3(1.0, 0, 0.3), yaw)
				4:
					prop("well" if _rng.randf() < 0.3 else "water_trough", c, yaw)
				_:
					prop("chest", c, yaw)
					prop("basket", c + b * Vector3(0.8, 0, 0), yaw)
					prop("bucket", c + b * Vector3(0.4, 0, 0.7), yaw)
			lots.append(c)  # no cells: clutter never closes a lane to the router (t_tutorial's bot detoured)
			stats["clutter"] = int(stats.get("clutter", 0)) + 1

## Inside or beside a gate (the opening, the towers and a post-width either side: a wicket post there
## left a gap too narrow to pass that the router still took).
func _in_gateway(p: Vector3) -> bool:
	for g in gates:
		if Vector2(p.x - g.x, p.z - g.z).length() < 8.0:
			return true
	# Gates are laid after the lots: before that, the avenue ends count.
	for e: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if Vector2(p.x - float(o.x + e.x * HALF), p.z - float(o.y + e.y * HALF)).length() < 8.0:
			return true
	return false

func _deg_of(p: Vector3) -> float:
	return _wrap(rad_to_deg(atan2(p.z - camp.z, p.x - camp.x)) - dock_deg)

## The harbour front: the real dock (Harbour) plus moored piers to each side with their boats, crates
## and fish, stacks of barrels and crates on the quay, fish racks and a fishing stand.
func _harbour() -> void:
	var h: Node3D = rt.harbour
	if h == null:
		return
	var s2 := HarbourSite.seaward(int(h.get("build_rot")))
	var sea := Vector3(s2.x, 0, s2.y)
	var along := Vector3(-sea.z, 0, sea.x)
	var base := rt.arrival_point()
	for off in [-24.0, -15.0, 15.0, 24.0]:
		var p: Vector3 = base + along * off - sea * 12.0
		var k := 0
		while k < 40 and rt.is_dry(p):
			p += sea * 0.5
			k += 1
		if k >= 40 or k < 2:
			continue
		var pier_at: Vector3 = p + sea * 2.4
		pier_at.y = h.global_position.y
		part_at("pier", Transform3D(Basis(Vector3.UP, atan2(-sea.x, -sea.z)), pier_at), FAR_HOUSE)
		var quay: Vector3 = p - sea * 2.5
		quay.y = rt.surface_y(quay.x, quay.z)
		var yaw := atan2(sea.x, sea.z)
		var qb := Basis(Vector3.UP, yaw)
		prop("large_box", quay + qb * Vector3(1.6, 0, 0), yaw)
		prop("barrel", quay + qb * Vector3(-1.4, 0, 0.3), yaw)
		prop("barrel", quay + qb * Vector3(-2.2, 0, -0.4), yaw + 0.7)
		prop("drying_rack_dried" if absf(off) > 20.0 else "fishing_stand", quay + qb * Vector3(0, 0, -2.6), yaw)
		_take(quay, 5.0, 3.0, 1.4, yaw)
		stats["piers"] = int(stats.get("piers", 0)) + 1
	var sign_at := base - sea * 6.0 + along * 3.5
	prop("signpost", sign_at, atan2(sea.x, sea.z))
	lamp(base - sea * 5.0 - along * 3.0)
	lamp(base - sea * 5.0 + along * 3.0)

## The palisade: a square of fortified panels HALF m out on each axis, a kit gate where each main
## avenue leaves (towers, lamps, a signpost outside), a wicket every WICKET_EVERY panels, nothing
## over water. Panels step PANEL_M so neighbours share their end posts.
func _wall() -> void:
	gates.clear()
	for e: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var g := Vector3(float(o.x + e.x * HALF), 0.0, float(o.y + e.y * HALF))
		g.y = rt.surface_y(g.x, g.z)
		if not rt.is_dry(g):
			refused["gate_wet"] = int(refused.get("gate_wet", 0)) + 1
			continue
		var out := Vector3(float(e.x), 0, float(e.y))
		var side := Vector3(-out.z, 0, out.x)
		var posts: Array[Vector3] = []
		for s in [-1.0, 1.0]:
			var post: Vector3 = g + side * s * 3.85
			post.y = rt.surface_y(post.x, post.z)
			posts.append(post)
		if not (rt.is_dry(posts[0]) and rt.is_dry(posts[1])):
			refused["gate_half_wet"] = int(refused.get("gate_half_wet", 0)) + 1
			continue  # never half a gate in the water
		g.y = minf(posts[0].y, posts[1].y)
		var yaw := atan2(out.x, out.z)  # the kit gate's +Z faces out
		part_at("town_gate", Transform3D(Basis(Vector3.UP, yaw), g), FAR_HOUSE)
		gates.append(g)
		for post in posts:
			lamp(post - out * 1.2)
			_solid(post, Vector3(1.0, 4.8, 1.0))
		prop("signpost", g + out * 3.0 + side * (float(AVENUE_W) * 0.5 + 1.5), yaw)
		stats["gates"] = int(stats.get("gates", 0)) + 1
	var n := ceili(float(HALF * 2) / PANEL_M)
	var step := float(HALF * 2) / float(n)
	var idx := 0
	for edge in 4:
		var horiz := edge < 2  # north and south runs go along x
		var sgn := -1.0 if edge % 2 == 0 else 1.0
		var yaw := 0.0 if horiz else PI * 0.5
		var b := Basis(Vector3.UP, yaw)
		for i in n:
			idx += 1
			var a := -float(HALF) + step * (float(i) + 0.5)
			var p := Vector3(float(o.x) + (a if horiz else sgn * float(HALF)), 0.0, float(o.y) + (sgn * float(HALF) if horiz else a))
			p.y = rt.surface_y(p.x, p.z)
			if absf(a) < float(AVENUE_W) * 0.5 + 1.2:
				continue  # the gate opening (or the avenue's end, where the gate stood in water)
			# A wicket (a gap between two posts) every WICKET_EVERY panels: walks out to the wild lands
			# and back stay short (the tutorial bot timed out detouring to the gates).
			if idx % WICKET_EVERY < 2:
				if idx % WICKET_EVERY == 0 and rt.is_dry(p) and not _in_gateway(p):
					# Posts at the two outer ends of the two skipped panels: a gap 2 panels wide.
					for s in [-0.5, 1.5]:
						var wp := p + b * Vector3(s * step, 0, 0)
						wp.y = rt.surface_y(wp.x, wp.z)
						unit("box", Transform3D(Basis().scaled_local(Vector3(0.4, 2.8, 0.4)), wp), Color(0.32, 0.22, 0.13), FAR_HOUSE)
						_solid(wp, Vector3(0.4, 2.8, 0.4))
				continue
			if not rt.is_dry(p) or not rt.spawn_ok(p, false):
				continue
			var t := BuildGrid.tile_of(p)
			if rt.build_grid._occupied.has(t) or rt.build_grid._reserved.has(t) or road_tiles.has(t):
				continue
			part_at("fence_fortified", Transform3D(b.scaled_local(Vector3(step / PANEL_M, 1.0, 1.0)), p), FAR_PROP)
			_boxes.append([Transform3D(b, p + Vector3(0, 1.1, 0)), Vector3(step, 2.2, 0.5)])
			# The panel's 0.5 m box straddles the tile line it stands on: both rows, or the router walks
			# the outer row and the survivor scrapes along the logs.
			for pt in _rect_tiles(p, step, 0.6, yaw):
				cells[pt] = true
			stats["wall"] = int(stats.get("wall", 0)) + 1

# ---------------------------------------------------------------- streets

## TOWNPOLISH2: the streets are one mesh of 1 m tiles on the grid, every corner on the drawn ground
## (surface_y) plus ROAD_LIFT, so the terrain never cuts through between samples (the old strips had a
## vertex every 2 m at the edges only and sank into any bulge). The road shader pulls the surface a
## little toward the camera (a decal's depth bias) and frays the outer edge with noise. Inside the
## inner streets (out_of < PAVED_M) the tiles are paved. Footpaths from the doors are tiles too.
const ROAD_LIFT := 0.04
const PAVED_M := 34.0
func _roads() -> void:
	for row: Array in _paths:
		var a3: Vector3 = row[0]
		var b3: Vector3 = row[1]
		var k := 0.0
		while k <= a3.distance_to(b3):
			var t := BuildGrid.tile_of(a3 + (b3 - a3).normalized() * k)
			if not cells.has(t):
				road_tiles[t] = true
			k += 0.5
	var paved := SurfaceTool.new()
	paved.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirt := SurfaceTool.new()
	dirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Vector2i in road_tiles:
		var st := paved if out_of(Vector3(float(t.x) + 0.5, 0, float(t.y) + 0.5)) < PAVED_M else dirt
		var corners := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
		var vs: Array[Vector3] = []
		var edge: Array[float] = []
		for cc: Vector2i in corners:
			var x := float(t.x + cc.x)
			var z := float(t.y + cc.y)
			vs.append(Vector3(x, rt.surface_y(x, z) + ROAD_LIFT, z))
			# The share of the four tiles round this corner that are road (1 inside, 0.5 on a side, 0.25
			# on an outer corner): the shader frays the edge with it.
			var share := 0.0
			for dd: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				share += 0.25 if road_tiles.has(t + cc + dd) else 0.0
			edge.append(share)
		for i in [0, 1, 2, 0, 2, 3]:  # clockwise from above: Godot's front face
			st.set_color(Color(1, 1, 1, edge[i]))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(vs[i].x, vs[i].z))
			st.add_vertex(vs[i])
	for pair in [[paved, "paved", "TownStreetsPaved"], [dirt, "road", "TownRoads"]]:
		(pair[0] as SurfaceTool).index()
		var m := (pair[0] as SurfaceTool).commit()
		if m.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = pair[2]
		mi.mesh = m
		mi.material_override = _road_mat(pair[1] == "paved")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

static var _road_mats: Dictionary = {}
static func _road_mat(paved: bool) -> ShaderMaterial:
	if _road_mats.has(paved):
		return _road_mats[paved]
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/world/town_road.gdshader")
	m.set_shader_parameter("tint", Color(0.56, 0.53, 0.48) if paved else Color(0.46, 0.39, 0.31))
	m.set_shader_parameter("cobble", 1.0 if paved else 0.0)
	m.set_shader_parameter("noise_tex", _noise(0.35 if paved else 0.08, Vector2.ONE))
	var fray := NoiseTexture2D.new()  # full 0..1 range (_noise's ramp would never cut)
	fray.width = 128
	fray.height = 128
	fray.seamless = true
	fray.noise = FastNoiseLite.new()
	(fray.noise as FastNoiseLite).frequency = 0.08
	m.set_shader_parameter("fray_tex", fray)
	_road_mats[paved] = m
	return m

## Lamp posts along the streets (alternate sides, every 13 m), signposts where an avenue leaves the
## square, and a few walkers on the avenues. On the grid: a lamp stands on a tile centre.
func _street_props() -> void:
	for k in range(-STREET_K, STREET_K + 1):
		var hw := float(_half_w(k))
		var s := float(STREET_EVERY * k)
		var i := 0
		for a in range(-HALF + 4, HALF - 4, 13):
			var off := (hw + 0.5) * (1.0 if i % 2 == 0 else -1.0)
			i += 1
			for q: Vector3 in [Vector3(float(o.x + a) + 0.5, 0, float(o.y) + s + off), Vector3(float(o.x) + s + off, 0, float(o.y + a) + 0.5)]:
				if Vector2(q.x - camp.x, q.z - camp.z).length() < PLAZA_R:
					continue
				if rt.is_dry(q) and not cells.has(BuildGrid.tile_of(q)) and not road_tiles.has(BuildGrid.tile_of(q)):
					lamp(q)
	for e: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var out := Vector3(float(e.x), 0, float(e.y))
		var side := Vector3(-out.z, 0, out.x)
		var sp := Vector3(camp.x, 0, camp.z) + out * PLAZA_R + side * (float(AVENUE_W) * 0.5 + 1.2)
		if rt.is_dry(sp) and not cells.has(BuildGrid.tile_of(sp)):
			sp.y = rt.surface_y(sp.x, sp.z)
			prop("signpost", sp, atan2(out.x, out.z))
	# A few walkers on the avenues.
	var dirs := [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 0, 1)]
	for i in 4:
		var d: Vector3 = dirs[i]
		var a := Vector3(float(o.x), 0, float(o.y)) + d * (PLAZA_R + 4.0) + Vector3(-d.z, 0, d.x) * 1.0
		var z := Vector3(float(o.x), 0, float(o.y)) + d * float(STREET_EVERY * 2) + Vector3(-d.z, 0, d.x) * 1.0
		if rt.is_dry(a) and rt.is_dry(z):
			walker(a, z)

## A street lamp (town kit): post, iron cage, the glass lit at night with a soft halo round it.
func lamp(at: Vector3, _h: float = 2.6) -> void:
	# Never within 2 m of a wall or post: a lamp beside a house corner left a pinch the router took
	# and the tutorial bot wedged in.
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if cells.has(BuildGrid.tile_of(at) + Vector2i(dx, dz)):
				return
	at.y = rt.surface_y(at.x, at.z)
	var yaw := _rng.randf() * TAU
	part_at("town_lamp", Transform3D(Basis(Vector3.UP, yaw), at), FAR_PROP)
	unit("lantern", Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(0.24, 0.34, 0.24)), at + Vector3(0, 2.63, 0)), Color(1.0, 0.8, 0.5), FAR_HOUSE)
	unit("halo", Transform3D(Basis().scaled(Vector3.ONE * 2.2), at + Vector3(0, 2.8, 0)), Color.WHITE, FAR_PROP)
	_solid(at, Vector3(0.3, 2.6, 0.3))  # the router steps round the post instead of into it
	stats["lamps"] += 1

# ---------------------------------------------------------------- people and animals

## A townsperson: the survivor body with a random look, playing one loop where it stands, facing
## the way local +Z of `yaw` points (the rig itself faces -Z). Walkers keep 4 of the slots.
func npc(at: Vector3, yaw: float, clip: StringName, walking: bool = false) -> Node3D:
	if _plaza:
		if _plaza_folk >= PLAZA_FOLK:
			return null
		_plaza_folk += 1
	elif stats["npcs"] - _plaza_folk >= (MAX_FOLK if walking else MAX_FOLK - 4):
		return null
	var root := Node3D.new()
	root.name = "Townsfolk_%d" % npcs.size()
	add_child(root)
	at.y = rt.surface_y(at.x, at.z)
	root.global_transform = Transform3D(Basis(Vector3.UP, yaw + PI), at)
	var rig := CharacterLook.build_rig(root, "townsfolk")
	rig.scale *= 1.18
	var g: String = CharacterLook.GENDERS[_rng.randi_range(0, CharacterLook.GENDERS.size() - 1)]
	CharacterLook.apply(rig, CharacterLook.randomized(g, _rng))
	rig.play(clip)
	root.set_meta(&"clip", clip)
	npcs.append(root)
	stats["npcs"] += 1
	return root

## A townsperson who walks a street back and forth.
func walker(a: Vector3, z: Vector3) -> void:
	var n := npc(a, 0.0, &"walk", true)
	if n == null:
		return
	n.set_meta(&"walk", [a, z])
	var tw := n.create_tween().set_loops()
	var secs := a.distance_to(z) / 1.3
	for leg in [[a, z], [z, a]]:
		tw.tween_callback(func () -> void:
			var d: Vector3 = (leg[1] as Vector3) - (leg[0] as Vector3)
			n.rotation.y = atan2(d.x, d.z) + PI)
		tw.tween_method(func (t: float) -> void:
			var p := (leg[0] as Vector3).lerp(leg[1] as Vector3, t)
			p.y = rt.surface_y(p.x, p.z)
			n.global_position = p, 0.0, 1.0, secs)

func animal(sp: StringName, at: Vector3, yaw: float) -> void:
	var def := Data.creature(sp)
	if def == null or stats["animals"] >= MAX_ANIMALS:
		return
	var v := CreatureView.new()
	v.name = "PenAnimal_%s_%d" % [sp, stats["animals"]]
	add_child(v)
	at.y = rt.surface_y(at.x, at.z)
	v.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	v.setup(def)
	if v.rig:
		v.rig.play(&"idle")
	v.set_meta(&"clip", &"idle")
	npcs.append(v)
	stats["animals"] += 1

## Townsfolk and pen animals past NPC_RANGE_M from the camera focus hide and stop animating.
func _process(delta: float) -> void:
	_npc_left -= delta
	if _npc_left > 0.0:
		return
	_npc_left = 0.5
	_night()
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var p := PlayerRegistry.local()
	var focus: Vector3 = p.global_position if p else (cam.global_position if cam else camp)
	for n in npcs:
		var near := n.global_position.distance_to(focus) < NPC_RANGE_M
		if n.visible != near:
			n.visible = near
			n.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED

# ---------------------------------------------------------------- batching

## A GLB prop at `at`, turned `yaw`, scaled `s`.
func prop(name: String, at: Vector3, yaw: float, s: float = 1.0) -> void:
	if not ResourceLoader.exists(GLB % name):
		return
	part_at(name, Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3.ONE * s), at), FAR_PROP)

func part_at(name: String, xf: Transform3D, far: float, occlude: bool = false) -> void:
	var parts := _glb_parts(name)
	for i in parts.size():
		var row: Array = parts[i]
		var label := ("nature_" + name.get_file().get_basename()) if name.begins_with("res://") else name
		_add("%s:%d" % [label, i], row[0], xf * (row[1] as Transform3D), Color.WHITE, far, occlude)

## Procedural pieces: plinth, box, roof, gable, canvas, flag, lantern (unit meshes, coloured per instance).
func unit(kind: String, xf: Transform3D, col: Color, far: float, occlude: bool = false) -> void:
	_add("u_" + kind, _unit_mesh(kind), xf, col, far, occlude)

func _add(key: String, mesh: Mesh, xf: Transform3D, col: Color, far: float, occlude: bool) -> void:
	if mesh == null:
		return
	var ch := Vector2i(floori(xf.origin.x / CHUNK_M), floori(xf.origin.z / CHUNK_M))
	var k := "%d:%d:%s" % [ch.x, ch.y, key]
	if not _batches.has(k):
		_batches[k] = {"mesh": mesh, "xf": [], "colors": [], "far": far, "occlude": occlude, "unit": key.begins_with("u_")}
	(_batches[k]["xf"] as Array).append(xf)
	(_batches[k]["colors"] as Array).append(col)

func _flush() -> void:
	for k: String in _batches:
		var b: Dictionary = _batches[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = bool(b["unit"])
		mm.mesh = b["mesh"]
		var xs: Array = b["xf"]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			if mm.use_colors:
				mm.set_instance_color(i, (b["colors"] as Array)[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Town_" + k.replace(":", "_")
		mmi.multimesh = mm
		mmi.visibility_range_end = float(b["far"])
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if float(b["far"]) < FAR_HOUSE:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		if bool(b["occlude"]):
			if not k.contains(":nature_"):
				mmi.set_meta(&"occl_box", true)  # buildings fade only when in the sight line's box (Occlusion._instance_hit)
			Occlusion.make_occludable(mmi, Occlusion.BETWEEN)
		stats["instances"] += xs.size()
		stats["mmi"] += 1
	_batches.clear()
	# One static body of boxes for every wall, stall, pen and post.
	_body = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(_body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(_body, rt.get_world_3d().space)
	PhysicsServer3D.body_set_collision_layer(_body, 1)
	PhysicsServer3D.body_set_collision_mask(_body, 0)
	PhysicsServer3D.body_attach_object_instance_id(_body, get_instance_id())  # a tap on a wall hits TownDress, not null
	for row: Array in _boxes:
		var sh := PhysicsServer3D.box_shape_create()
		PhysicsServer3D.shape_set_data(sh, (row[1] as Vector3) * 0.5)
		PhysicsServer3D.body_add_shape(_body, sh, row[0])
		_shapes.append(sh)
	stats["boxes"] = _boxes.size()
	_boxes.clear()

## Every mesh of a GLB with its transform inside the model, loaded once per name.
static func _glb_parts(name: String) -> Array:
	if _parts.has(name):
		return _parts[name]
	var out: Array = []
	var ps := load(name if name.begins_with("res://") else GLB % name) as PackedScene
	if ps:
		var s := ps.instantiate()
		for m in s.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var xf := mi.transform
			var p := mi.get_parent()
			while p != s and p is Node3D:
				xf = (p as Node3D).transform * xf
				p = p.get_parent()
			var mesh := mi.mesh
			if mi.material_override != null or mi.get_surface_override_material_count() > 0:
				var copy := mesh.duplicate() as Mesh
				for i in copy.get_surface_count():
					var mat: Material = mi.material_override if mi.material_override else mi.get_surface_override_material(i)
					if mat and copy is ArrayMesh:
						(copy as ArrayMesh).surface_set_material(i, mat)
				mesh = copy
			out.append([mesh, xf])
		s.free()
	_parts[name] = out
	return out

static func _unit_mesh(kind: String) -> Mesh:
	if _unit.has(kind):
		return _unit[kind]
	var m: Mesh
	match kind:
		"plinth", "box":
			var bm := BoxMesh.new()  # origin at the bottom centre
			var st := SurfaceTool.new()
			st.create_from(bm, 0)
			var am := st.commit()
			m = _shift(am, Vector3(0, 0.5, 0))
			m.surface_set_material(0, _mat("stone" if kind == "plinth" else "wood", Color.WHITE))
		"lantern", "winglow":
			var st4 := SurfaceTool.new()
			st4.create_from(BoxMesh.new(), 0)
			m = _shift(st4.commit(), Vector3(0, 0.5, 0))
			m.surface_set_material(0, _mat("glow" if kind == "lantern" else "winglow", Color.WHITE))
		"halo":
			var qm := QuadMesh.new()
			qm.size = Vector2.ONE
			var st5 := SurfaceTool.new()
			st5.create_from(qm, 0)
			m = st5.commit()
			m.surface_set_material(0, _mat("halo", Color.WHITE))
		"roof", "canvas":
			m = _prism(kind == "canvas")
			m.surface_set_material(0, _mat("thatch" if kind == "roof" else "cloth", Color.WHITE))
		"gable":
			var st2 := SurfaceTool.new()
			st2.begin(Mesh.PRIMITIVE_TRIANGLES)
			for v in [Vector3(0, 0, -0.5), Vector3(0, 1, 0), Vector3(0, 0, 0.5)]:
				st2.set_normal(Vector3.RIGHT)
				st2.add_vertex(v)
			m = st2.commit()
			m.surface_set_material(0, _mat("plaster", Color.WHITE))
		"flag":
			var st3 := SurfaceTool.new()
			st3.begin(Mesh.PRIMITIVE_TRIANGLES)
			for v in [Vector3(-0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(0.5, -0.5, 0), Vector3(-0.5, -0.5, 0), Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0)]:
				st3.set_normal(Vector3.BACK)
				st3.add_vertex(v)
			m = st3.commit()
			m.surface_set_material(0, _mat("cloth", Color.WHITE))
	_unit[kind] = m
	return m

## A unit gabled roof: x -0.5..0.5 along the ridge, z -0.5..0.5, y 0 (eaves) to 1 (ridge).
static func _prism(flat_top: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 1.0
	for side in [-1.0, 1.0]:
		var e0 := Vector3(-0.5, 0, 0.5 * side)
		var e1 := Vector3(0.5, 0, 0.5 * side)
		var r0 := Vector3(-0.5, top, 0.0 if not flat_top else 0.0)
		var r1 := Vector3(0.5, top, 0.0)
		var n := Vector3(0, 0.5, side).normalized()
		for v in ([e0, r0, r1, e0, r1, e1] if side > 0 else [e0, r1, r0, e0, e1, r1]):
			st.set_normal(n)
			st.set_uv(Vector2(v.x + 0.5, absf(v.z) * 2.0) * Vector2(3.0, 1.5))
			st.add_vertex(v)
	return st.commit()

static func _shift(am: ArrayMesh, by: Vector3) -> ArrayMesh:
	var arrays := am.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += by
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

static func _mat(kind: String, _c: Color) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	match kind:
		"thatch":
			m.albedo_texture = _noise(0.09, Vector2(1.0, 0.12))
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"cloth":
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_texture = _stripe_tex()  # TOWNPOLISH: striped market canvas, tinted per stall
		"plaster", "stone", "wood":
			m.albedo_texture = _noise(0.05, Vector2.ONE)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED if kind == "plaster" else BaseMaterial3D.CULL_BACK
		"glow", "winglow":
			# Lantern glass and lit windows; _night() turns them up after dusk and down by day.
			m.emission_enabled = true
			m.emission = Color(1.0, 0.62, 0.28)
			m.emission_energy_multiplier = 2.2
			m.albedo_color = Color(0.25, 0.2, 0.15) if kind == "winglow" else Color.WHITE
		"halo":
			# A soft additive glow card round each lantern at night (no real light: TUTPERF caps them).
			m.vertex_color_use_as_albedo = false
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
			m.no_depth_test = false
			m.albedo_texture = _halo_tex()
			m.albedo_color = Color(1.0, 0.7, 0.35, 0.0)
		"paved":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.56, 0.53, 0.48)
			m.albedo_texture = _noise(0.35, Vector2.ONE)
		"road":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.47, 0.38, 0.27)
			m.albedo_texture = _noise(0.08, Vector2.ONE)
			m.uv1_scale = Vector3(1, 1, 1)
	_mats[kind] = m
	return m

static func _stripe_tex() -> ImageTexture:
	var img := Image.create(64, 8, false, Image.FORMAT_RGB8)
	for x in 64:
		var v := 1.0 if (x / 8) % 2 == 0 else 0.62
		for y in 8:
			img.set_pixel(x, y, Color(v, v * 0.97, v * 0.92))
	return ImageTexture.create_from_image(img)

static func _halo_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t

## 0 by day, 1 at night, ramping through dusk and dawn (Game's phase bounds, 0.22 and 0.80).
static func night_of(tod: float) -> float:
	return clampf(maxf(smoothstep(0.30, 0.20, tod), smoothstep(0.74, 0.82, tod)), 0.0, 1.0)

## Lamps and windows follow the clock: the shared materials change, no per-instance work.
func _night() -> void:
	var n := night_of(float(Game.time_of_day))
	if absf(n - _night_was) < 0.02:
		return
	_night_was = n
	(_mat("glow", Color.WHITE) as StandardMaterial3D).emission_energy_multiplier = lerpf(0.15, 3.2, n)
	(_mat("winglow", Color.WHITE) as StandardMaterial3D).emission_energy_multiplier = lerpf(0.0, 1.6, n)
	(_mat("halo", Color.WHITE) as StandardMaterial3D).albedo_color.a = 0.55 * n

static func _noise(freq: float, stretch: Vector2) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	var t := NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.72, 0.72, 0.72))
	g.set_color(1, Color(1.0, 1.0, 1.0))
	t.color_ramp = g
	t.set_meta(&"stretch", stretch)
	return t

# ---------------------------------------------------------------- clearing

## Inside the square palisade.
func _inside(t: Vector2i) -> bool:
	return out_of(Vector3(float(t.x) + 0.5, 0, float(t.y) + 0.5)) < float(HALF)

## TOWNPOLISH: a lived-in town is trodden, so inside the wall only some of the ground cover
## stays (a stable hash per tile), and the tall bushes and reeds of the biome dress go entirely.
func _trodden(t: Vector2i) -> bool:
	# TOWNPOLISH2: a third kept left the bare base texture showing, which read washed-out pale in
	# daylight (owner bug); three quarters stay now, still cleared off every lot and street.
	return _inside(t) and (absi(t.x * 73856093 ^ t.y * 19349663) % 100) >= 75

## Collapse ground cover and dressing, clear scenery props and remove (non-tutorial) harvest nodes on
## every taken tile and every road tile; then tell the build grid and the router.
func _clear_ground() -> void:
	var all := cells.duplicate()
	all.merge(road_tiles)
	# FACTIONS: the square itself is trodden (a busy hub): no ground-cover grass on it. Its scenery
	# props, dress and harvest nodes stay (WildGrass is a gather prop the tutorial's fibre order uses).
	var cover := all.duplicate()
	var pr := int(PLAZA_R - 1.0)
	for dx in range(-pr, pr + 1):
		for dz in range(-pr, pr + 1):
			if dx * dx + dz * dz <= pr * pr:
				cover[BuildGrid.tile_of(camp + Vector3(dx, 0, dz))] = true
	var gc := rt.get_node_or_null("GroundCover")
	if gc:
		for key: Vector2i in gc._cells:
			var mmi := gc._cells[key] as MultiMeshInstance3D
			if mmi == null:
				continue
			var tiles: Array = gc._tiles.get(key, [])
			var hit := false
			for i in mini(tiles.size(), mmi.multimesh.instance_count):
				# Tall cards (reeds, ferns) never stay inside the wall; short grass thins to a third.
				if cover.has(tiles[i]) or _trodden(tiles[i]) or (_inside(tiles[i]) and mmi.multimesh.get_instance_transform(i).basis.y.length() > 0.8):
					mmi.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))
					# TOWNPOLISH: with physics interpolation on, the renderer kept drawing the previous
					# transform of a cleared card (reeds stood on the streets); reset it with the new one.
					mmi.multimesh.reset_instance_physics_interpolation(i)
					hit = true
					stats["cover_cleared"] = int(stats.get("cover_cleared", 0)) + 1
			if hit:
				mmi.multimesh = mmi.multimesh
	var bd := rt.get_node_or_null("BiomeDress")
	if bd:
		for i in bd._points.size():
			var t := BuildGrid.tile_of(bd._points[i])
			if all.has(t) or _inside(t):
				bd._clear_slot(t, bd._points[i])
		# Static cards need no physics interpolation; with it on, cleared cards kept drawing.
		for m in bd.find_children("*", "MultiMeshInstance3D", true, false):
			(m as Node).physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if rt.props and rt.props.has_method("clear_cells"):
		rt.props.clear_cells(all.keys())
	var drop: Array = []
	for key in rt._harvest_nodes.keys():
		var node: Variant = rt._harvest_nodes[key]
		if not is_instance_valid(node) or not node is Node3D or str(key).begins_with("tutorial_"):
			continue
		if all.has(BuildGrid.tile_of((node as Node3D).global_position)):
			drop.append(key)
	for key in drop:
		var node: Node = rt._harvest_nodes[key]
		rt._harvest_nodes.erase(key)
		rt._node_tiles.erase(key)
		var batch: Variant = node.get("_batch")
		if batch is VegBatch and int(node.get("_batch_idx")) >= 0:
			(batch as VegBatch).set_shown(int(node.get("_batch_idx")), false)
		for k in ["_card", "_card_empty"]:
			var card: Variant = node.get(k)
			if card != null and is_instance_valid(card):
				(card as Node).queue_free()
		node.queue_free()
		rt.harvest_count -= 1
	stats["cleared_nodes"] = drop.size()
	var taken: Array[Vector2i] = []
	for t: Vector2i in cells:
		taken.append(t)
	rt.build_grid.occupy(self, taken)
	rt.mark_pathing_dirty()
