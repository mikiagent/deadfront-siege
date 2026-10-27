class_name MapFog
extends RefCounted
## Per-island fog of war and walked trail (spec 25: undiscovered areas grey, walking reveals like a
## brush, footsteps as black dots). One 2 m bitmap per island; saved as base64 in the save's "map"
## field. A save without it (older builds) starts with everything near the camp revealed.
##
## The bitmap is a bitset: bit i = cell (i % span, i / span) has been walked. Reveal is a circle
## of BRUSH_M around the survivor; the trail keeps one dot per TRAIL_STEP_M, last TRAIL_MAX, and
## fades each dot until it expires.

const CELL_M := 2.0
## ASSUMPTION: no doc gives a reveal radius; 25 m reads as a visible brush stroke on a 160 m island.
const BRUSH_M := 25.0
## ASSUMPTION: spec 25 says "your footsteps ... black dots" but not how often; 8 m keeps a readable line.
const TRAIL_STEP_M := 8.0
## ASSUMPTION: "the last ~200 kept" from the task brief.
const TRAIL_MAX := 200
## ASSUMPTION: the docs require a footstep trail but give no duration; 30 s leaves a useful recent
## route without turning the minimap into a permanent field of black dots.
const TRAIL_LIFETIME_S := 30.0
## ASSUMPTION: what an old save knows when it has no fog at all (the camp area, not the whole island).
const OLD_SAVE_REVEAL_M := 40.0

## Fire kinds that get the campfire icon; every other craft station is a facility icon.
const FIRE_KINDS := ["bonfire", "campfire", "stone_fire_pit"]

var island_id := ""
var size_m: float = 160.0
var span: int = 0
## One byte per cell: 0 unrevealed, 1 revealed. Serialised as a packed bitset.
var cells := PackedByteArray()
var trail: Array[Vector2] = []
## Kept parallel to `trail`; simulation time makes fading deterministic in tests.
var trail_ages: Array[float] = []
## Bumped on every change; the drawing side rebuilds its fog texture only when this moves.
var version: int = 0
## 1 = island land, 0 = sea; fog over sea is transparent (the reference keeps the coastline read).
var land := PackedByteArray()
var _tex: ImageTexture
var _tex_version := -1
var _tex_land_tag := -1

func setup(id: String, island_size: float) -> void:
	island_id = id
	# A forged save cannot ask for a gigabyte bitmap: clamp to the biggest island the docs allow
	# (unstable islands are built ~480 m across).
	size_m = clampf(maxf(CELL_M * 4.0, island_size), CELL_M * 4.0, 1000.0)
	span = maxi(1, int(ceil(size_m / CELL_M)))
	cells = PackedByteArray()
	cells.resize(span * span)
	cells.fill(0)
	land = PackedByteArray()
	land.resize(span * span)
	land.fill(1)
	trail.clear()
	trail_ages.clear()
	version = 0
	_tex = null
	_tex_version = -1

func matches(island_size: float) -> bool:
	return span == maxi(1, int(ceil(maxf(CELL_M * 4.0, island_size) / CELL_M)))

func _idx(x: int, z: int) -> int:
	return x + z * span

func cell_of(pos: Vector3) -> Vector2i:
	return cell_of_xz(pos.x, pos.z)

func cell_of_xz(x: float, z: float) -> Vector2i:
	return Vector2i(
		clampi(int(floor((x + size_m * 0.5) / CELL_M)), 0, span - 1),
		clampi(int(floor((z + size_m * 0.5) / CELL_M)), 0, span - 1))

func cell_centre(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * CELL_M - size_m * 0.5, (float(cell.y) + 0.5) * CELL_M - size_m * 0.5)

func is_revealed_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= span or cell.y >= span:
		return false
	return cells[_idx(cell.x, cell.y)] != 0

func revealed_at(pos: Vector3) -> bool:
	return is_revealed_cell(cell_of(pos))

## Marks every cell whose centre lies within `radius_m` of `pos`. Returns how many were new.
func reveal(pos: Vector3, radius_m: float = BRUSH_M) -> int:
	if span <= 0:
		return 0
	var c := cell_of(pos)
	var rc := int(ceil(radius_m / CELL_M)) + 1
	var r2 := radius_m * radius_m
	var p := Vector2(pos.x, pos.z)
	var added := 0
	for z in range(maxi(0, c.y - rc), mini(span, c.y + rc + 1)):
		for x in range(maxi(0, c.x - rc), mini(span, c.x + rc + 1)):
			if p.distance_squared_to(cell_centre(Vector2i(x, z))) > r2:
				continue
			var i := _idx(x, z)
			if cells[i] == 0:
				cells[i] = 1
				added += 1
	if added > 0:
		version += 1
	return added

## One step of walking: reveal the brush and add a trail dot once the survivor is TRAIL_STEP_M
## from the last one. The trail is capped, oldest first.
func walk(pos: Vector3) -> void:
	reveal(pos)
	var p := Vector2(pos.x, pos.z)
	if trail.is_empty() or trail[trail.size() - 1].distance_to(p) >= TRAIL_STEP_M:
		trail.append(p)
		trail_ages.append(0.0)
		while trail.size() > TRAIL_MAX:
			trail.remove_at(0)
			trail_ages.remove_at(0)
		version += 1

## Ages existing dots and removes expired ones. Renderers redraw every frame, so age-only changes do
## not invalidate the fog texture cache.
func advance_trail(delta: float) -> void:
	if delta <= 0.0 or trail.is_empty():
		return
	for i in range(trail_ages.size() - 1, -1, -1):
		trail_ages[i] += delta
		if trail_ages[i] >= TRAIL_LIFETIME_S:
			trail_ages.remove_at(i)
			trail.remove_at(i)

func trail_alpha(index: int) -> float:
	if index < 0 or index >= trail_ages.size():
		return 0.0
	return clampf(1.0 - trail_ages[index] / TRAIL_LIFETIME_S, 0.0, 1.0)

func revealed_count() -> int:
	var n := 0
	for v in cells:
		if v != 0:
			n += 1
	return n

func revealed_fraction() -> float:
	var n := revealed_count()
	if n <= 0:
		return 0.0
	var land_n := 0
	for v in land:
		if v != 0:
			land_n += 1
	if land_n <= 0:
		return 0.0
	return float(n) / float(land_n)

## Land mask from the island's terrain: water cells never fog over, so the island outline stays.
func land_from(runtime: Node) -> void:
	if span <= 0 or runtime == null:
		return
	var types: PackedByteArray = runtime.get("tile_types")
	var res: int = int(runtime.get("_tile_span"))
	if types.is_empty() or res <= 0:
		return
	land = PackedByteArray()
	land.resize(span * span)
	for z in span:
		for x in span:
			var c := cell_centre(Vector2i(x, z))
			var tx := clampi(int(floor((c.x + size_m * 0.5) / size_m * float(res))), 0, res - 1)
			var tz := clampi(int(floor((c.y + size_m * 0.5) / size_m * float(res))), 0, res - 1)
			var t := int(types[tx + tz * res])
			land[_idx(x, z)] = 0 if (t == 4 or t == 8) else 1
	version += 1

func to_dict() -> Dictionary:
	var bit_len := span * span
	var bytes := PackedByteArray()
	bytes.resize((bit_len + 7) / 8)
	bytes.fill(0)
	for i in bit_len:
		if cells[i] != 0:
			bytes[i >> 3] = bytes[i >> 3] | (1 << (i & 7))
	var pts: Array = []
	for i in trail.size():
		var p := trail[i]
		pts.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(trail_ages[i], 0.01)])
	return {"id": island_id, "size": size_m, "fog": Marshalls.raw_to_base64(bytes), "trail": pts}

static func from_dict(d: Dictionary) -> MapFog:
	var f := MapFog.new()
	f.setup(str(d.get("id", "")), float(d.get("size", 160.0)))
	var raw := Marshalls.base64_to_raw(str(d.get("fog", "")))
	var bit_len := f.span * f.span
	# A short or corrupt bitmap leaves every cell unrevealed (the trail is still worth keeping).
	if raw.size() * 8 >= bit_len:
		for i in bit_len:
			f.cells[i] = 1 if (raw[i >> 3] & (1 << (i & 7))) != 0 else 0
	var row: Variant = d.get("trail", [])
	if row is Array:
		for p in row:
			if not (p is Array and (p as Array).size() >= 2):
				continue
			var a: Variant = (p as Array)[0]
			var b: Variant = (p as Array)[1]
			if not ((a is int or a is float) and (b is int or b is float)):
				continue
			if not (is_finite(float(a)) and is_finite(float(b))):
				continue
			# Rows from older saves contain only x/z and start fresh under the new finite lifetime.
			var age := 0.0
			if (p as Array).size() >= 3:
				var c: Variant = (p as Array)[2]
				if not (c is int or c is float) or not is_finite(float(c)):
					continue
				age = maxf(0.0, float(c))
			if age >= TRAIL_LIFETIME_S:
				continue
			f.trail.append(Vector2(float(a), float(b)))
			f.trail_ages.append(age)
	while f.trail.size() > TRAIL_MAX:
		f.trail.remove_at(0)
		f.trail_ages.remove_at(0)
	f.version += 1
	return f

## A save from before fog existed knows the camp area and nothing else (task: "old saves load with
## everything near the camp revealed"). The trail starts empty: it was never recorded.
static func for_old_save(id: String, island_size: float, camp: Vector3) -> MapFog:
	var f := MapFog.new()
	f.setup(id, island_size)
	f.reveal(camp, OLD_SAVE_REVEAL_M)
	return f

## Fog overlay image: transparent where walked, grey elsewhere; the rim of a revealed area is a
## lighter grey so the brush edge reads soft once the texture is drawn with linear filtering.
func texture() -> ImageTexture:
	if span <= 0:
		return null
	if _tex != null and _tex_version == version and _tex_land_tag == land.size():
		return _tex
	var img := Image.create(span, span, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var grey := Color(0.34, 0.35, 0.38)
	for z in span:
		for x in span:
			var i := _idx(x, z)
			if cells[i] != 0 or land[i] == 0:
				continue
			var near := false
			if x > 0 and cells[_idx(x - 1, z)] != 0: near = true
			elif x + 1 < span and cells[_idx(x + 1, z)] != 0: near = true
			elif z > 0 and cells[_idx(x, z - 1)] != 0: near = true
			elif z + 1 < span and cells[_idx(x, z + 1)] != 0: near = true
			var c := grey
			c.a = 0.62 if near else 0.94
			img.set_pixel(x, z, c)
	_tex = ImageTexture.create_from_image(img)
	_tex_version = version
	_tex_land_tag = land.size()
	return _tex
