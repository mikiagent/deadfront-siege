class_name TownDress
extends Node3D
## TUTTOWN (owner 2026-10-29: "It should feel like a massive town"): the tutorial island's prebuilt
## town around the camp. Districts on rings and avenues: the harbour (stone warehouses, crates, fish
## racks), the market (stalls under striped canvas), homes (timber-framed, thatched), workshops (open
## shelters with busy stations: forges and grills that glow, racks with drying meat), farms (fields
## in crop, a well, scarecrows), pens with tamed animals, and the Adventurer's Guild hall on the
## square as the landmark. Lamp posts line the streets, signposts mark the avenues, and townsfolk
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

const CHUNK_M := 80.0
const GLB := "res://assets/props/blender/%s.glb"
const PLAZA_R := 24.0  ## the camp square stays as it was (guild, market stall, bench, pit, herbs, trees)
const AVENUE_W := 6.0
const RING_A := 44.0
const RING_B := 66.0
const ROAD_W := 5.0
const TOWN_R := 96.0  ## inside the island's town_safe_m (100)
const BANDS := [[29.0, -1.0], [36.5, 1.0], [55.0, -1.0], [75.0, -1.0]]  ## [ring radius, door faces +1 out / -1 in]
const AVENUES := [0.0, 72.0, 144.0, -72.0, -144.0]  ## degrees from the dock direction
const NPC_RANGE_M := 60.0
const FAR_HOUSE := 220.0
const FAR_PROP := 110.0
const MAX_FOLK := 16  ## townsfolk rigs (each a skinned survivor body)
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
var dock_deg := 0.0
var stats := {"houses": 0, "stalls": 0, "workshops": 0, "fields": 0, "pens": 0, "npcs": 0, "animals": 0, "lamps": 0, "instances": 0, "mmi": 0, "boxes": 0, "cleared_nodes": 0}
var npcs: Array[Node3D] = []
var cells: Dictionary = {}  ## Vector2i -> true: tiles a house, stall, shelter or pen covers
var road_tiles: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}  ## "cx:cz:part:i" -> {"mesh", "xf", "colors", "far", "shadow", "occlude"}
var _boxes: Array = []  ## [Transform3D, Vector3 size]
var _body := RID()
var _shapes: Array[RID] = []
var _npc_left := 0.0
static var _parts: Dictionary = {}  ## glb name -> Array of [Mesh, Transform3D]
static var _mats: Dictionary = {}
static var _unit: Dictionary = {}

static func build(p_rt: IslandRuntime) -> TownDress:
	var t := TownDress.new()
	t.name = "TownDress"
	t.rt = p_rt
	t.camp = p_rt._camp_pos
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

## Distance (m) from a point to the nearest street centre line (avenues, the two rings).
func street_d(p: Vector3) -> float:
	var v := Vector2(p.x - camp.x, p.z - camp.z)
	var r := v.length()
	var deg := _wrap(rad_to_deg(atan2(v.y, v.x)) - dock_deg)
	var best := minf(absf(r - RING_A), absf(r - RING_B))
	if r > PLAZA_R - 4.0:
		for av: float in AVENUES:
			var dd := deg_to_rad(_wrap(deg - av))
			if cos(dd) > 0.0:
				best = minf(best, absf(r * sin(dd)))
	return best

# ---------------------------------------------------------------- layout

func _lay_out() -> void:
	var t0 := Time.get_ticks_msec()
	_guild_hall()
	for band: Array in BANDS:
		_band(float(band[0]), float(band[1]))
	_outskirts()
	_roads()
	_street_props()
	_flush()
	_clear_ground()
	print("[tuttown] town built in %d ms: %s refused=%s" % [Time.get_ticks_msec() - t0, stats, refused])

## One ring of lots: walk the ring in steps, fill each free lot by its district.
func _band(r: float, facing: float) -> void:
	var circ := TAU * r
	var s := 0.0
	while s < circ:
		var deg := _wrap(s / circ * 360.0)
		var dist := district_of(deg)
		var w := 2 * _rng.randi_range(2, 3)  # 4 or 6 m wide, 4 or 6 m deep
		var d := 4 if r < 40.0 else 2 * _rng.randi_range(2, 3)
		if r > 60.0 and _rng.randf() < 0.25:
			w = 8  # a long house now and then
		var used := 0.0
		match dist:
			&"market":
				used = _stall_lot(deg, r, facing) if r < 40.0 else _house_lot(deg, r, facing, w, d, "plain")
			&"workshops":
				used = _workshop_lot(deg, r, facing) if r < 60.0 else _house_lot(deg, r, facing, w, d, "stone")
			&"farms":
				used = _house_lot(deg, r, facing, w, d, "timber") if r < 40.0 else _field_lot(deg, r)
			&"pens":
				used = _house_lot(deg, r, facing, w, d, "timber") if r < 40.0 else (_pen_lot(deg, r) if r > 60.0 else _tent_lot(deg, r, facing))
			&"harbour":
				used = _house_lot(deg, r, facing, 6, 6, "stone")
			_:
				used = _house_lot(deg, r, facing, w, d, "timber" if _rng.randf() < 0.7 else "plain")
		s += maxf(used, 3.0) + 1.6

## A rectangle (local w x d around `c`, turned `yaw`) is free: dry, not steep, off the streets, off
## the square, off anything already placed. Returns the base height or NAN.
func lot_base(c: Vector3, w: float, d: float, yaw: float, margin: float = 1.0) -> float:
	var v := Vector2(c.x - camp.x, c.z - camp.z)
	if v.length() - maxf(w, d) * 0.5 < PLAZA_R or v.length() + maxf(w, d) * 0.5 > TOWN_R:
		return _no("ring")
	if street_d(c) < Vector2(w, d).length() * 0.5 + AVENUE_W * 0.5 - 0.5:
		return _no("street")
	var lo := INF
	var hi := -INF
	var b := Basis(Vector3.UP, yaw)
	for k in 9:
		var q := c + b * Vector3((float(k % 3) - 1.0) * (w * 0.5 + margin), 0.0, (float(k / 3) - 1.0) * (d * 0.5 + margin))
		if not rt.is_dry(q) or not rt.spawn_ok(q, false):
			return _no("wet")
		var y := rt.surface_y(q.x, q.z)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	if hi - lo > 2.0:
		return _no("steep")
	for t in _rect_tiles(c, w + margin, d + margin, yaw):
		if cells.has(t) or rt.build_grid._occupied.has(t) or rt.build_grid._reserved.has(t):
			return _no("taken")
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
			var q := c + b * Vector3(-w * 0.5 + float(i) * w / float(nx * 2), 0.0, -d * 0.5 + float(j) * d / float(nz * 2))
			var t := BuildGrid.tile_of(q)
			if not seen.has(t):
				seen[t] = true
				out.append(t)
	return out

## Mark a footprint taken (cells for the router and the build grid) and add its collision box.
func _take(c: Vector3, w: float, d: float, h: float, yaw: float, solid: bool = true) -> void:
	for t in _rect_tiles(c, w, d, yaw):
		cells[t] = true
	if solid:
		_boxes.append([Transform3D(Basis(Vector3.UP, yaw), c + Vector3(0, h * 0.5, 0)), Vector3(w, h, d)])

func _lot(deg: float, r: float, facing: float, w: float, d: float) -> Dictionary:
	var c := polar(deg, r)
	var yaw := yaw_out(deg) + (0.0 if facing > 0.0 else PI)
	var base := lot_base(c, w, d, yaw)
	if is_nan(base):
		return {}
	c.y = base
	return {"c": c, "yaw": yaw, "b": Basis(Vector3.UP, yaw)}

# ---------------------------------------------------------------- houses

const WALLS := {
	"timber": ["house_wall_timber", "house_wall_window_timber"],
	"plain": ["house_wall", "house_wall_window"],
	"stone": ["house_wall_stone", "house_wall_window_stone"],
}
const ROOF_COLORS := {"timber": Color(0.78, 0.64, 0.36), "plain": Color(0.72, 0.58, 0.33), "stone": Color(0.42, 0.40, 0.40)}

func _house_lot(deg: float, r: float, facing: float, w: int, d: int, style: String) -> float:
	var lot := _lot(deg, r, facing, float(w), float(d))
	if lot.is_empty():
		return 2.0
	house(lot["c"], w, d, lot["yaw"], style, 2 if r < 40.0 and _rng.randf() < 0.3 else 1)
	# Life at the door: a barrel, crates or a bench beside it.
	var b: Basis = lot["b"]
	var door: Vector3 = (lot["c"] as Vector3) + b * Vector3(float(w) * 0.5 - 0.6, 0.0, float(d) * 0.5 + 0.7)
	var pick: String = ["barrel", "large_box", "basket", "bucket", "chest"][_rng.randi_range(0, 4)]
	prop(pick, door, (lot["yaw"] as float) + _rng.randf_range(-0.4, 0.4))
	return float(w)

## A house: stone plinth, 2 m wall panels of one style (a doorway in front, windows here and there),
## timber corner posts and a gabled roof (thatch, or slate on stone houses). Local +Z is the front.
func house(c: Vector3, w: int, d: int, yaw: float, style: String, storeys: int = 1) -> void:
	var b := Basis(Vector3.UP, yaw)
	var lo := INF
	for k in 4:
		var q := c + b * Vector3((float(k % 2) - 0.5) * float(w), 0.0, (float(k / 2) - 0.5) * float(d))
		lo = minf(lo, rt.surface_y(q.x, q.z))
	var top := c.y + 0.35
	var plinth_h := top - lo + 0.25
	unit("plinth", Transform3D(b.scaled(Vector3(float(w) + 0.3, plinth_h, float(d) + 0.3)), Vector3(c.x, lo - 0.25, c.z)), Color(0.5, 0.48, 0.45), FAR_HOUSE)
	var pair: Array = WALLS.get(style, WALLS["timber"])
	var wall_h := 2.4
	for st in storeys:
		var y := top + wall_h * float(st)
		var wall_style: Array = pair if st == 0 or style != "stone" else WALLS["timber"]  # a stone hall gets a timber upper floor
		for side in 4:
			var along := w if side % 2 == 0 else d
			var across := d if side % 2 == 0 else w
			var sb := Basis(Vector3.UP, yaw + float(side) * PI * 0.5)
			var n := along / 2
			for i in n:
				var off := Vector3(-float(along) * 0.5 + 1.0 + 2.0 * float(i), 0.0, float(across) * 0.5)
				var at := Vector3(c.x, y, c.z) + sb * off
				var part: String = wall_style[0]
				if side == 0 and st == 0 and i == n / 2:
					part = "house_wall_doorway"
					part_at("house_door", Transform3D(sb, at + sb * Vector3(0, 0, 0.05)), FAR_HOUSE)
				elif _rng.randf() < 0.45:
					part = wall_style[1]
				part_at(part, Transform3D(sb, at), FAR_HOUSE, true)
		for k in 4:
			var q := Vector3((float(k % 2) - 0.5) * float(w), 0.0, (float(k / 2) - 0.5) * float(d))
			unit("box", Transform3D(b.scaled(Vector3(0.32, wall_h, 0.32)), Vector3(c.x, y, c.z) + b * q), Color(0.33, 0.22, 0.13), FAR_HOUSE)
	var eave := top + wall_h * float(storeys)
	var span := float(mini(w, d))
	var long := float(maxi(w, d))
	var rb := b if w >= d else Basis(Vector3.UP, yaw + PI * 0.5)  # ridge along the long side
	var rh := span * 0.55
	var col: Color = ROOF_COLORS.get(style, ROOF_COLORS["timber"])
	col = col.lerp(Color(0.6, 0.5, 0.3), _rng.randf() * 0.3)
	unit("roof", Transform3D(rb.scaled(Vector3(long + 0.8, rh, span + 1.0)), Vector3(c.x, eave, c.z)), col, FAR_HOUSE, true)
	for e in [-1.0, 1.0]:
		unit("gable", Transform3D(rb.scaled(Vector3(1.0, rh, span)), Vector3(c.x, eave, c.z) + rb * Vector3(e * long * 0.5, 0, 0)), Color(0.80, 0.72, 0.58), FAR_HOUSE)
	if style == "stone" or _rng.randf() < 0.3:
		var ch := Vector3(c.x, eave, c.z) + rb * Vector3(long * 0.3, 0, 0)
		unit("box", Transform3D(b.scaled(Vector3(0.6, rh + 0.9, 0.6)), ch), Color(0.45, 0.42, 0.4), FAR_HOUSE)
	_take(c, float(w), float(d), eave + rh - c.y, yaw)
	stats["houses"] += 1

# ---------------------------------------------------------------- the guild hall

## The Adventurer's Guild: a two-storey stone and timber hall behind the guild pavilion on the square
## (TownGuild keeps the tap), a banner pole and torches at its door. The landmark of the town.
func _guild_hall() -> void:
	var g := Vector3.INF
	for n in get_tree().get_nodes_in_group("town_building"):
		if n.get("role") == &"guild":
			g = (n as Node3D).global_position
	if g == Vector3.INF:
		return
	var away := Vector3(g.x - camp.x, 0, g.z - camp.z).normalized()
	var c := g + away * 10.0
	c.y = rt.surface_y(c.x, c.z)
	var yaw := atan2(-away.x, -away.z)  # its front faces the square
	house(c, 10, 8, yaw, "stone", 2)
	var b := Basis(Vector3.UP, yaw)
	var door := c + b * Vector3(0, 0, 4.6)
	for s in [-1.6, 1.6]:
		lamp(door + b * Vector3(s, 0, 0.4), 2.2)
	var pole := c + b * Vector3(-5.6, 0, 4.4)
	pole.y = rt.surface_y(pole.x, pole.z)
	unit("box", Transform3D(b.scaled(Vector3(0.18, 9.0, 0.18)), pole), Color(0.3, 0.2, 0.12), FAR_HOUSE)
	unit("flag", Transform3D(b.scaled(Vector3(2.2, 1.4, 1.0)), pole + Vector3(0, 7.4, 0) + b * Vector3(1.1, 0, 0)), Color(0.75, 0.16, 0.12), FAR_HOUSE)
	prop("signpost", door + b * Vector3(3.0, 0, 1.2), yaw)

# ---------------------------------------------------------------- districts

## Market: a stall under a striped canvas (two colours), goods on the counter, barrels and baskets.
func _stall_lot(deg: float, r: float, facing: float) -> float:
	var lot := _lot(deg, r + 2.0, facing, 4.0, 3.0)
	if lot.is_empty():
		return 2.0
	var c: Vector3 = lot["c"]
	var b: Basis = lot["b"]
	var yaw: float = lot["yaw"]
	for k in 4:
		var q := Vector3((float(k % 2) - 0.5) * 3.6, 0.0, (float(k / 2) - 0.5) * 2.6)
		unit("box", Transform3D(b.scaled(Vector3(0.14, 2.5 if k < 2 else 2.1, 0.14)), c + b * q), Color(0.36, 0.25, 0.14), FAR_PROP)
	var hues := [Color(0.75, 0.2, 0.15), Color(0.2, 0.4, 0.7), Color(0.85, 0.65, 0.2), Color(0.25, 0.55, 0.3)]
	var col: Color = hues[_rng.randi_range(0, hues.size() - 1)]
	unit("canvas", Transform3D(b.scaled(Vector3(4.2, 0.5, 3.2)), c + Vector3(0, 2.05, 0)), col, FAR_PROP)
	unit("box", Transform3D(b.scaled(Vector3(3.4, 0.9, 0.8)), c + b * Vector3(0, 0, 1.0)), Color(0.45, 0.32, 0.18), FAR_PROP)
	var goods := ["basket", "bucket", "chest", "barrel"]
	for i in 2:
		prop(goods[_rng.randi_range(0, 3)], c + b * Vector3(-0.9 + 1.8 * float(i), 0.9, 1.0), yaw, 0.6)
	prop(["barrel", "large_box", "basket"][_rng.randi_range(0, 2)], c + b * Vector3(2.4, 0, 0.3), yaw)
	_take(c, 4.0, 3.0, 2.4, yaw)
	stats["stalls"] += 1
	if _rng.randf() < 0.5:
		npc(c + b * Vector3(0, 0, -0.3), yaw, &"idle")
	return 4.0

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

func _workshop_lot(deg: float, r: float, facing: float) -> float:
	var lot := _lot(deg, r, facing, 6.0, 5.0)
	if lot.is_empty():
		return 2.0
	var c: Vector3 = lot["c"]
	var b: Basis = lot["b"]
	var yaw: float = lot["yaw"]
	for k in 4:
		var q := Vector3((float(k % 2) - 0.5) * 5.6, 0.0, (float(k / 2) - 0.5) * 4.6)
		unit("box", Transform3D(b.scaled(Vector3(0.22, 2.7, 0.22)), c + b * q), Color(0.34, 0.23, 0.13), FAR_HOUSE)
	unit("roof", Transform3D(b.scaled(Vector3(6.6, 1.4, 5.6)), c + Vector3(0, 2.7, 0)), ROOF_COLORS["timber"], FAR_HOUSE, true)
	unit("plinth", Transform3D(b.scaled(Vector3(6.0, 0.3, 5.0)), c + Vector3(0, -0.2, 0)), Color(0.42, 0.36, 0.3), FAR_PROP)
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
	npc(c + b * Vector3(0.0, 0.1, 0.9), yaw + PI, row[2])
	_take(c, 6.0, 5.0, 2.8, yaw, false)
	for k in 4:  # only the posts block: the shelter stays walkable
		var q := Vector3((float(k % 2) - 0.5) * 5.6, 0.0, (float(k / 2) - 0.5) * 4.6)
		_boxes.append([Transform3D(b, c + b * q + Vector3(0, 1.35, 0)), Vector3(0.3, 2.7, 0.3)])
	stats["workshops"] += 1
	return 6.0

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
func _field_lot(deg: float, r: float) -> float:
	var lot := _lot(deg, r, 1.0, 8.0, 6.0)
	if lot.is_empty():
		return 2.0
	var c: Vector3 = lot["c"]
	var b: Basis = lot["b"]
	var yaw: float = lot["yaw"]
	for i in 3:
		for j in 2:
			var stage: String = ["field_crop_0", "field_crop_1", "field_crop_2", "field_crop_3", "field_tilled"][_rng.randi_range(0, 4)]
			prop(stage, c + b * Vector3(-2.4 + 2.4 * float(i), 0, -1.2 + 2.4 * float(j)), yaw)
	_fence_rect(c, 8.6, 6.6, yaw, true)
	prop(["scarecrow", "compost_heap", "well", "trellis"][_rng.randi_range(0, 3)], c + b * Vector3(5.2, 0, 0), yaw)
	if _rng.randf() < 0.5:
		npc(c + b * Vector3(-1.2, 0, 3.8), yaw + PI, &"farm")
	_take(c, 8.6, 6.6, 1.2, yaw, false)
	stats["fields"] += 1
	return 9.0

## Pens: a fenced paddock with a tamed animal or two (the real species art, idle loop).
const PEN_SPECIES := [&"protoceratops", &"zebraceratops", &"gallimimus", &"compsognathus"]
var _pen_i := 0

func _pen_lot(deg: float, r: float) -> float:
	var lot := _lot(deg, r, 1.0, 10.0, 8.0)
	if lot.is_empty():
		return 2.0
	var c: Vector3 = lot["c"]
	var b: Basis = lot["b"]
	var yaw: float = lot["yaw"]
	_fence_rect(c, 10.0, 8.0, yaw, true)
	prop("water_trough" if ResourceLoader.exists(GLB % "water_trough") else "bucket", c + b * Vector3(-3.5, 0, -2.6), yaw)
	prop("straw_roll", c + b * Vector3(3.2, 0, -2.4), yaw + 0.3)
	var sp: StringName = PEN_SPECIES[_pen_i % PEN_SPECIES.size()]
	_pen_i += 1
	for k in (2 if sp == &"compsognathus" else 1):
		animal(sp, c + b * Vector3(-1.0 + 2.2 * float(k), 0, 0.5), yaw + _rng.randf_range(-1.2, 1.2))
	_take(c, 10.0, 8.0, 1.5, yaw)
	stats["pens"] += 1
	return 11.0

## Hide tents of the hunters by the north gate.
func _tent_lot(deg: float, r: float, facing: float) -> float:
	var lot := _lot(deg, r, facing, 3.4, 3.4)
	if lot.is_empty():
		return 2.0
	prop("tent" if _rng.randf() < 0.5 else "tent_canvas", lot["c"], lot["yaw"])
	prop("drying_rack_dried", (lot["c"] as Vector3) + (lot["b"] as Basis) * Vector3(2.8, 0, 0), lot["yaw"])
	_take(lot["c"], 3.4, 3.4, 2.3, lot["yaw"])
	return 6.0

func _fence_rect(c: Vector3, w: float, d: float, yaw: float, gate: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	for side in 4:
		var along := w if side % 2 == 0 else d
		var across := d if side % 2 == 0 else w
		var sb := Basis(Vector3.UP, yaw + float(side) * PI * 0.5)
		var n := int(round(along / 2.0))
		for i in n:
			var q := c + sb * Vector3(-along * 0.5 + 1.0 + 2.0 * float(i) * along / (2.0 * float(n)), 0.0, across * 0.5)
			q.y = rt.surface_y(q.x, q.z)
			prop("gate" if gate and side == 0 and i == n / 2 else "fence", q, yaw + float(side) * PI * 0.5)

## Outskirts past the outer ring by the farms and pens: more fields and a well.
func _outskirts() -> void:
	for deg in range(-178, -100, 14):
		_field_lot(float(deg), 88.0)
	for deg in range(160, 200, 16):
		_pen_lot(_wrap(float(deg)), 88.0)

# ---------------------------------------------------------------- streets

## Dirt avenues and ring roads: one mesh hugging the ground, cover cleared under it.
func _roads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for av: float in AVENUES:
		var prev: Array = []
		var r := PLAZA_R - 6.0
		while r <= TOWN_R:
			var p := polar(av, r)
			var side := Vector3(-sin(deg_to_rad(dock_deg + av)), 0, cos(deg_to_rad(dock_deg + av)))
			prev = _road_step(st, prev, p, side, AVENUE_W)
			r += 2.0
	for ring in [RING_A, RING_B]:
		var prev: Array = []
		var n := int(TAU * float(ring) / 2.0)
		for i in n + 1:
			var deg := 360.0 * float(i) / float(n)
			var p := polar(deg, ring)
			var a := deg_to_rad(dock_deg + deg)
			prev = _road_step(st, prev, p, Vector3(cos(a), 0, sin(a)), ROAD_W)
	var m := st.commit()
	if m.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "TownRoads"
	mi.mesh = m
	mi.material_override = _mat("road", Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## One road quad from the previous cross-section to this one; a wet or steep point breaks the strip.
func _road_step(st: SurfaceTool, prev: Array, p: Vector3, side: Vector3, w: float) -> Array:
	if not rt.is_dry(p):
		return []
	var l := p + side * w * 0.5
	var r := p - side * w * 0.5
	l.y = rt.surface_y(l.x, l.z) + 0.07
	r.y = rt.surface_y(r.x, r.z) + 0.07
	for k in int(w) + 1:
		road_tiles[BuildGrid.tile_of(p + side * (float(k) - w * 0.5))] = true
	if not prev.is_empty():
		var pl: Vector3 = prev[0]
		var pr: Vector3 = prev[1]
		for v in [[pl, Vector2(0, 0)], [l, Vector2(0, 1)], [r, Vector2(1, 1)], [pl, Vector2(0, 0)], [r, Vector2(1, 1)], [pr, Vector2(1, 0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv((v[1] as Vector2) * Vector2(1, 0.5) + Vector2(0, (v[0] as Vector3).x * 0.13 + (v[0] as Vector3).z * 0.11))
			st.add_vertex(v[0])
	return [l, r]

## Lamp posts along the avenues and rings, signposts where an avenue leaves the square.
func _street_props() -> void:
	for av: float in AVENUES:
		var r := PLAZA_R + 2.0
		var k := 0
		while r < TOWN_R:
			var off := AVENUE_W * 0.5 + 0.6
			var p := polar(av, r)
			var a := deg_to_rad(dock_deg + av)
			var q := p + Vector3(-sin(a), 0, cos(a)) * off * (1.0 if k % 2 == 0 else -1.0)
			if rt.is_dry(q) and not cells.has(BuildGrid.tile_of(q)):
				lamp(q)
			r += 13.0
			k += 1
		var s := polar(av, PLAZA_R) + Vector3(-sin(deg_to_rad(dock_deg + av)), 0, cos(deg_to_rad(dock_deg + av))) * (AVENUE_W * 0.5 + 1.2)
		if rt.is_dry(s):
			prop("signpost", s, yaw_out(av))
	for ring in [RING_A, RING_B]:
		for i in int(TAU * ring / 24.0):
			var deg := 360.0 * float(i) / float(int(TAU * ring / 24.0)) + 9.0
			var q := polar(deg, ring + ROAD_W * 0.5 + 0.6)
			if rt.is_dry(q) and not cells.has(BuildGrid.tile_of(q)) and street_d(q) > 2.0:
				lamp(q)
	# A few walkers on the streets.
	for i in 4:
		var av: float = AVENUES[(i * 2 + 1) % AVENUES.size()]
		var a := polar(av, PLAZA_R + 4.0)
		var z := polar(av, RING_B - 4.0)
		if rt.is_dry(a) and rt.is_dry(z):
			walker(a + Vector3(0, 0, 0.8 * float(i % 2)), z)

func lamp(at: Vector3, h: float = 2.6) -> void:
	at.y = rt.surface_y(at.x, at.z)
	unit("box", Transform3D(Basis().scaled(Vector3(0.14, h, 0.14)), at), Color(0.25, 0.17, 0.1), FAR_PROP)
	unit("lantern", Transform3D(Basis().scaled(Vector3(0.32, 0.38, 0.32)), at + Vector3(0, h, 0)), Color(1.0, 0.72, 0.35), FAR_HOUSE)
	_boxes.append([Transform3D(Basis(), at + Vector3(0, h * 0.5, 0)), Vector3(0.2, h, 0.2)])
	cells[BuildGrid.tile_of(at)] = true  # the router steps round the post instead of into it
	stats["lamps"] += 1

# ---------------------------------------------------------------- people and animals

## A townsperson: the survivor body with a random look, playing one loop where it stands, facing
## the way local +Z of `yaw` points (the rig itself faces -Z). Walkers keep 4 of the slots.
func npc(at: Vector3, yaw: float, clip: StringName, walking: bool = false) -> Node3D:
	if stats["npcs"] >= (MAX_FOLK if walking else MAX_FOLK - 4):
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
	part_at(name, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at), FAR_PROP)

func part_at(name: String, xf: Transform3D, far: float, occlude: bool = false) -> void:
	var parts := _glb_parts(name)
	for i in parts.size():
		var row: Array = parts[i]
		_add("%s:%d" % [name, i], row[0], xf * (row[1] as Transform3D), Color.WHITE, far, occlude)

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
	var ps := load(GLB % name) as PackedScene
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
		"lantern":
			var st4 := SurfaceTool.new()
			st4.create_from(BoxMesh.new(), 0)
			m = _shift(st4.commit(), Vector3(0, 0.5, 0))
			m.surface_set_material(0, _mat("glow", Color.WHITE))
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
		"plaster", "stone", "wood":
			m.albedo_texture = _noise(0.05, Vector2.ONE)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED if kind == "plaster" else BaseMaterial3D.CULL_BACK
		"glow":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.65, 0.3)
			m.emission_energy_multiplier = 2.2
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"road":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.47, 0.38, 0.27)
			m.albedo_texture = _noise(0.08, Vector2.ONE)
			m.uv1_scale = Vector3(1, 1, 1)
	_mats[kind] = m
	return m

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

## Collapse ground cover and dressing, clear scenery props and remove (non-tutorial) harvest nodes on
## every taken tile and every road tile; then tell the build grid and the router.
func _clear_ground() -> void:
	var all := cells.duplicate()
	all.merge(road_tiles)
	var gc := rt.get_node_or_null("GroundCover")
	if gc:
		for key: Vector2i in gc._cells:
			var mmi := gc._cells[key] as MultiMeshInstance3D
			if mmi == null:
				continue
			var tiles: Array = gc._tiles.get(key, [])
			var hit := false
			for i in mini(tiles.size(), mmi.multimesh.instance_count):
				if all.has(tiles[i]):
					mmi.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))
					hit = true
			if hit:
				mmi.multimesh = mmi.multimesh
	var bd := rt.get_node_or_null("BiomeDress")
	if bd:
		for i in bd._points.size():
			var t := BuildGrid.tile_of(bd._points[i])
			if all.has(t):
				bd._clear_slot(t, bd._points[i])
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
