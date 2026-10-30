class_name MapDoc
extends RefCounted
## An authored island map (MAPLAB): a square grid of cells with five painted layers and a list of
## markers. The map lab (`--lab=map_lab`) paints it, `to_json` / `from_json` read and write the
## versioned `game/data/maps/<name>.map.json` (format: docs/current/map-format.md), `issues()`
## validates it, and `apply_to_shape` / `paint_zones` drive the island generator from it.
##
## Grid: `cells` x `cells`, `cell_m` metres a cell, centred on the world origin like the island
## grid. Cell (col, row) has its centre at x = -size/2 + (col + 0.5) cell, z = -size/2 + (row + 0.5)
## cell; row 0 is the north edge (-z). Markers carry world metres (x, z) and a props dictionary.

const FORMAT := "wildlands.map"
const VERSION := 1
const LAYERS: Array[String] = ["land", "height", "zone", "water", "road"]
## One character per cell per layer in the JSON rows (index = stored byte).
const CHARS := {
	"land": ".#",        # sea, land
	"height": "012",     # low, hill, mountain/cliff
	"zone": ".mfscbwer", # unset (generator decides), then BiomeZones.ZONE_NAMES in order
	"water": ".~o",      # none, river, lake
	"road": ".=",        # none, road/path
}
const HEIGHT_NAMES: Array[String] = ["low", "hill", "mountain"]
## ASSUMPTION: target ground height per class (metres above the waterline). The plan's hills are
## 3-6 m and its terraces 3.2 m risers; a mountain is two to three of those.
const HEIGHT_M: Array[float] = [1.2, 4.5, 10.0]
const WATER_NAMES: Array[String] = ["none", "river", "lake"]
const MARKER_KINDS: Array[String] = ["town", "dock", "camp", "guild", "landmark", "resource", "spawn", "claim_free"]
## Coarse resource groups a cluster marker names (the scatter picks the climate's families).
# ASSUMPTION: the PRDs name no cluster groups; these are the gather families' plain names.
const RESOURCES: Array[String] = ["trees", "rock", "fibre", "berries", "herbs", "clay", "reeds", "ore", "flint", "salt"]
## The size presets (grid square in metres). Home is the 416 m square (375 x 300 m land); the
## tutorial island is 880 m (795 x 636 m land, 4.5x the home's).
# ASSUMPTION: 880 m is the tutorial branch's size_m; that island is not in canon yet.
const PRESETS := {"home": 416.0, "tutorial": 880.0}
## IslandShape.SEA_MARGIN: the island plan wants this much sea on every side of the land.
const SEA_MARGIN := 24.0
const UNDO_MAX := 64

var name: String = "untitled"
var climate: String = "grassland"
var size_m: float = 416.0
# ASSUMPTION: 4 m cells (the owner's brief); the island data grid is 2.6 m, tiles 1 m.
var cell_m: float = 4.0
var cells: int = 104
var layers: Dictionary = {}  # layer name -> PackedByteArray (cells * cells)
var markers: Array[Dictionary] = []  # {id, kind, x, z, props}
var _next_id: int = 1
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

static func make(p_size: float = 416.0, p_cell: float = 4.0, p_climate: String = "grassland", p_name: String = "untitled") -> MapDoc:
	var d := MapDoc.new()
	d.resize(p_size, p_cell)
	d.climate = p_climate
	d.name = p_name
	return d

## A blank grid of this size (all sea), markers cleared. The size is rounded to whole cells.
func resize(p_size: float, p_cell: float) -> void:
	cell_m = clampf(p_cell, 1.0, 32.0)
	cells = maxi(8, int(ceil(p_size / cell_m)))
	size_m = float(cells) * cell_m
	for l in LAYERS:
		var a := PackedByteArray()
		a.resize(cells * cells)
		layers[l] = a
	markers.clear()
	_next_id = 1

# ---------------------------------------------------------------------------- cells

func in_grid(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < cells and r < cells

func get_cell(layer: String, c: int, r: int) -> int:
	if not in_grid(c, r):
		return 0
	return (layers[layer] as PackedByteArray)[c + r * cells]

func set_cell(layer: String, c: int, r: int, v: int) -> void:
	if not in_grid(c, r):
		return
	layers[layer][c + r * cells] = v
	# Sea carries nothing else: painting sea clears the cell's other layers.
	if layer == "land" and v == 0:
		for l in ["height", "zone", "water", "road"]:
			layers[l][c + r * cells] = 0

func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor((x + size_m * 0.5) / cell_m)), int(floor((z + size_m * 0.5) / cell_m)))

func cell_centre(c: int, r: int) -> Vector2:
	return Vector2(-size_m * 0.5 + (float(c) + 0.5) * cell_m, -size_m * 0.5 + (float(r) + 0.5) * cell_m)

func is_land(c: int, r: int) -> bool:
	return get_cell("land", c, r) == 1

## Brush: every cell whose centre is within `radius` cells of (c, r). The land-only layers
## (height, zone, water, road) paint on land cells only; the sea is the land layer's 0.
func paint(layer: String, c: int, r: int, radius: float, v: int) -> void:
	var ri := int(ceil(radius))
	for dr in range(-ri, ri + 1):
		for dc in range(-ri, ri + 1):
			if Vector2(dc, dr).length() > radius + 0.01 or not in_grid(c + dc, r + dr):
				continue
			if layer != "land" and not is_land(c + dc, r + dr):
				continue
			set_cell(layer, c + dc, r + dr, v)

## Flood fill (4-connected) of the region that has the start cell's value in `layer`. Filling a
## land-only layer stays on land.
func fill(layer: String, c: int, r: int, v: int) -> void:
	if not in_grid(c, r):
		return
	var from := get_cell(layer, c, r)
	if from == v:
		return
	var need_land := layer != "land"
	if need_land and not is_land(c, r):
		return
	var stack: Array[Vector2i] = [Vector2i(c, r)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if not in_grid(p.x, p.y) or get_cell(layer, p.x, p.y) != from or (need_land and not is_land(p.x, p.y)):
			continue
		set_cell(layer, p.x, p.y, v)
		stack.append_array([p + Vector2i.RIGHT, p + Vector2i.LEFT, p + Vector2i.DOWN, p + Vector2i.UP])

func count(layer: String, v: int) -> int:
	return (layers[layer] as PackedByteArray).count(v)

# ---------------------------------------------------------------------------- markers

func add_marker(kind: String, x: float, z: float, props: Dictionary = {}) -> Dictionary:
	var m := {"id": _next_id, "kind": kind, "x": snappedf(x, 0.1), "z": snappedf(z, 0.1), "props": default_props(kind)}
	(m["props"] as Dictionary).merge(props, true)
	_next_id += 1
	markers.append(m)
	return m

func remove_marker(id: int) -> void:
	for i in markers.size():
		if int(markers[i]["id"]) == id:
			markers.remove_at(i)
			return

func marker(id: int) -> Dictionary:
	for m in markers:
		if int(m["id"]) == id:
			return m
	return {}

## The property fields each marker kind carries (and their defaults).
static func default_props(kind: String) -> Dictionary:
	match kind:
		"spawn":
			return {"species": "compsognathus", "level": 1, "count": 2, "radius_m": 20.0}
		"resource":
			return {"resource": "trees", "count": 6, "radius_m": 16.0}
		"claim_free":
			return {"name": "", "radius_m": 30.0}
		"landmark":
			# LANDMARKS M1: "type" names a site type of data/world/landmarks.json; an empty type is a
			# plain point of interest (a peak, a ruin) and places no resource site.
			return {"name": "", "type": ""}
		_:
			return {"name": ""}

# ---------------------------------------------------------------------------- undo / redo

## Call once before each stroke (or marker edit): the state before it becomes one undo step.
func begin_edit() -> void:
	_undo.append(_snapshot())
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_redo.clear()

func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	return true

func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	return true

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func _snapshot() -> Dictionary:
	var ls := {}
	for l in LAYERS:
		ls[l] = (layers[l] as PackedByteArray).duplicate()
	return {"size": size_m, "cell": cell_m, "climate": climate, "layers": ls, "markers": markers.duplicate(true), "next": _next_id}

func _restore(s: Dictionary) -> void:
	cell_m = float(s["cell"])
	size_m = float(s["size"])
	cells = int(round(size_m / cell_m))
	climate = str(s["climate"])
	layers = s["layers"]
	markers.assign(s["markers"])
	_next_id = int(s["next"])

# ---------------------------------------------------------------------------- JSON

func to_json() -> Dictionary:
	var ls := {}
	for l in LAYERS:
		var chars: String = CHARS[l]
		var a: PackedByteArray = layers[l]
		var rows: Array[String] = []
		for r in cells:
			var row := ""
			for c in cells:
				row += chars[mini(a[c + r * cells], chars.length() - 1)]
			rows.append(row)
		ls[l] = rows
	var legend := {}
	for l in LAYERS:
		var names: Array = []
		match l:
			"land": names = ["sea", "land"]
			"height": names = HEIGHT_NAMES.duplicate()
			"zone": names = ["unset"] + Array(BiomeZones.ZONE_NAMES)
			"water": names = WATER_NAMES.duplicate()
			"road": names = ["none", "road"]
		var row := {}
		for i in names.size():
			row[str(CHARS[l])[i]] = names[i]
		legend[l] = row
	return {
		"format": FORMAT, "version": VERSION, "name": name, "climate": climate,
		"size_m": size_m, "cell_m": cell_m, "cells": cells,
		"legend": legend, "height_m": Array(HEIGHT_M), "layers": ls, "markers": markers.duplicate(true),
	}

## Reads a map dictionary. Returns null (and fills `errors`) when it is not a readable v1 map.
static func from_json(d: Dictionary, errors: Array = []) -> MapDoc:
	if str(d.get("format", "")) != FORMAT:
		errors.append("not a %s file" % FORMAT)
		return null
	if int(d.get("version", 0)) != VERSION:
		errors.append("unsupported version %s (this build reads %d)" % [d.get("version"), VERSION])
		return null
	var doc := MapDoc.new()
	doc.resize(float(d.get("size_m", 416.0)), float(d.get("cell_m", 4.0)))
	if int(d.get("cells", doc.cells)) != doc.cells:
		errors.append("cells %s does not match size_m / cell_m = %d" % [d.get("cells"), doc.cells])
		return null
	doc.name = str(d.get("name", "untitled"))
	doc.climate = str(d.get("climate", "grassland"))
	var ls: Variant = d.get("layers", {})
	for l in LAYERS:
		var rows: Variant = (ls as Dictionary).get(l, null) if ls is Dictionary else null
		if rows == null:
			continue  # a missing layer reads as all default
		if not rows is Array or (rows as Array).size() != doc.cells:
			errors.append("layer %s needs %d rows" % [l, doc.cells])
			return null
		var chars: String = CHARS[l]
		var a: PackedByteArray = doc.layers[l]
		for r in doc.cells:
			var row := str(rows[r])
			if row.length() != doc.cells:
				errors.append("layer %s row %d is %d long, needs %d" % [l, r, row.length(), doc.cells])
				return null
			for c in doc.cells:
				var v := chars.find(row[c])
				if v < 0:
					errors.append("layer %s row %d col %d: unknown character '%s'" % [l, r, c, row[c]])
					return null
				a[c + r * doc.cells] = v
	var ms: Variant = d.get("markers", [])
	if ms is Array:
		for m in ms:
			if not m is Dictionary:
				continue
			var row: Dictionary = (m as Dictionary).duplicate(true)
			row["id"] = int(row.get("id", doc._next_id))
			row["x"] = float(row.get("x", 0.0))
			row["z"] = float(row.get("z", 0.0))
			row["kind"] = str(row.get("kind", "landmark"))
			if not row.get("props") is Dictionary:
				row["props"] = {}
			# JSON numbers come back as floats; whole-number fields stay ints so a re-export matches.
			for k in ["level", "count"]:
				if (row["props"] as Dictionary).has(k):
					row["props"][k] = int(row["props"][k])
			doc.markers.append(row)
			doc._next_id = maxi(doc._next_id, int(row["id"]) + 1)
	return doc

static func load_file(path: String, errors: Array = []) -> MapDoc:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("cannot open %s" % path)
		return null
	var v: Variant = JSON.parse_string(f.get_as_text())
	if not v is Dictionary:
		errors.append("%s is not a JSON object" % path)
		return null
	return from_json(v, errors)

func save_file(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_json(), "\t") + "\n")
	return OK

# ---------------------------------------------------------------------------- validation

## Problems an agent or the generator would trip on. Each: {level: "error"|"warn", code, msg}.
## Errors make the map unusable; warnings are worth a look.
func issues() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if count("land", 1) == 0:
		out.append(_issue("error", "no_land", "The map has no land."))
	var climates := BiomeMaterial.rows().keys()
	if not climates.has(climate) or climate.begins_with("_") or climate in ["zones", "zone_rules"]:
		out.append(_issue("error", "unknown_climate", "Climate '%s' is not in biomes.json." % climate))
	var edge := int(ceil(SEA_MARGIN / cell_m))
	var touches := false
	for r in cells:
		for c in cells:
			if is_land(c, r) and (c < edge or r < edge or c >= cells - edge or r >= cells - edge):
				touches = true
	if touches:
		out.append(_issue("warn", "land_at_edge", "Land within %.0f m of the map edge (the island plan keeps that much sea on every side)." % SEA_MARGIN))
	var species := _species()
	var kinds := {}
	for m in markers:
		var kind := str(m["kind"])
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		var p: Dictionary = m["props"]
		var cl := cell_of(float(m["x"]), float(m["z"]))
		var label := "%s #%d" % [kind, int(m["id"])]
		if not MARKER_KINDS.has(kind):
			out.append(_issue("error", "unknown_marker", "%s: unknown marker kind." % label))
		if not in_grid(cl.x, cl.y):
			out.append(_issue("error", "marker_off_map", "%s is outside the map." % label))
			continue
		if kind == "dock":
			if not _on_coast(cl):
				out.append(_issue("error", "dock_not_coast", "%s is not on the coast (needs land and sea within %.0f m)." % [label, cell_m * 2.0]))
		elif not is_land(cl.x, cl.y):
			out.append(_issue("error", "marker_in_sea", "%s is in the sea." % label))
		if p.has("count") and int(p["count"]) < 1:
			out.append(_issue("error", "bad_count", "%s: count must be 1 or more." % label))
		if kind == "spawn":
			if not species.is_empty() and not species.has(str(p.get("species", ""))):
				out.append(_issue("error", "unknown_species", "%s: species '%s' does not exist." % [label, p.get("species", "")]))
			var lv := int(p.get("level", 0))
			if lv < 1 or lv > 60:
				out.append(_issue("error", "bad_level", "%s: level %d is outside 1-60." % [label, lv]))
		if kind == "landmark" and str(p.get("type", "")) != "" and not landmark_types().has(str(p.get("type", ""))):
			out.append(_issue("warn", "unknown_landmark_type", "%s: landmark type '%s' is not one of %s." % [label, p.get("type", ""), ", ".join(landmark_types())]))
		if kind == "resource" and not RESOURCES.has(str(p.get("resource", ""))):
			out.append(_issue("error", "unknown_resource", "%s: resource '%s' is not one of %s." % [label, p.get("resource", ""), ", ".join(RESOURCES)]))
	if count("land", 1) > 0:
		if not kinds.has("dock"):
			out.append(_issue("warn", "no_dock", "No dock: travel needs a harbour on the coast."))
		if not kinds.has("camp") and not kinds.has("town"):
			out.append(_issue("warn", "no_camp", "No camp or town: the generator puts the camp beside the dock."))
		if _river_without_outlet():
			out.append(_issue("warn", "river_no_outlet", "A river does not reach the sea or a lake."))
	return out

func errors() -> Array[Dictionary]:
	return issues().filter(func(i: Dictionary) -> bool: return i["level"] == "error")

static func _issue(level: String, code: String, msg: String) -> Dictionary:
	return {"level": level, "code": code, "msg": msg}

func _on_coast(cl: Vector2i) -> bool:
	var land := false
	var sea := false
	for dr in range(-2, 3):
		for dc in range(-2, 3):
			if not in_grid(cl.x + dc, cl.y + dr):
				continue
			if is_land(cl.x + dc, cl.y + dr):
				land = true
			else:
				sea = true
	return land and sea

## True when some 8-connected group of river cells touches neither sea nor a lake.
func _river_without_outlet() -> bool:
	var seen := PackedByteArray()
	seen.resize(cells * cells)
	for r in cells:
		for c in cells:
			if get_cell("water", c, r) != 1 or seen[c + r * cells] == 1:
				continue
			var outlet := false
			var stack: Array[Vector2i] = [Vector2i(c, r)]
			seen[c + r * cells] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				for dr in range(-1, 2):
					for dc in range(-1, 2):
						var q := p + Vector2i(dc, dr)
						if not in_grid(q.x, q.y):
							continue
						if not is_land(q.x, q.y) or get_cell("water", q.x, q.y) == 2:
							outlet = true
						elif get_cell("water", q.x, q.y) == 1 and seen[q.x + q.y * cells] == 0:
							seen[q.x + q.y * cells] = 1
							stack.append(q)
			if not outlet:
				return true
	return false

## LANDMARKS M1: the site types data/world/landmarks.json defines (the map's landmark markers and
## IslandLandmarks share them).
static func landmark_types() -> Array:
	var f := FileAccess.open("res://data/world/landmarks.json", FileAccess.READ)
	if f == null:
		return []
	var v: Variant = JSON.parse_string(f.get_as_text())
	var t: Variant = (v as Dictionary).get("types", {}) if v is Dictionary else {}
	return (t as Dictionary).keys() if t is Dictionary else []

static func _species() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var data: Node = tree.root.get_node_or_null("Data") if tree else null
	if data == null:
		return []
	return (data.get("creatures") as Dictionary).keys().map(func(k: Variant) -> String: return str(k))

# ---------------------------------------------------------------------------- picture

## Map colours (also the lab canvas): zone map colours from biomes.json, height shading, water,
## roads. `show` toggles layers by name; markers are drawn by `preview_image`.
func image(show: Dictionary = {}) -> Image:
	var img := Image.create(cells, cells, false, Image.FORMAT_RGBA8)
	var sea := Color("#2b5c7a")
	var land := Color("#9aa070")
	var zcols: Array[Color] = []
	for z in BiomeZones.ZONE_NAMES:
		zcols.append(Color.from_string(str(BiomeZones.row_of(z).get("map", "#9aa070")), land))
	for r in cells:
		for c in cells:
			var col := sea
			if is_land(c, r):
				col = land
				var z := get_cell("zone", c, r)
				if z > 0 and show.get("zone", true):
					col = zcols[z - 1]
				if show.get("height", true):
					match get_cell("height", c, r):
						1: col = col.lightened(0.22)
						2: col = col.lerp(Color("#6e655c"), 0.65)
				if show.get("water", true):
					match get_cell("water", c, r):
						1: col = Color("#4a9ad8")
						2: col = Color("#2f78b8")
				if show.get("road", true) and get_cell("road", c, r) == 1:
					col = Color("#d8bd8a")
			img.set_pixel(c, r, col)
	return img

const MARKER_COLORS := {
	"town": Color("#f4c430"), "dock": Color("#ffffff"), "camp": Color("#ff8a3d"), "guild": Color("#c77dff"),
	"landmark": Color("#ff5f6d"), "resource": Color("#62d26f"), "spawn": Color("#e63946"), "claim_free": Color("#5ec8e5"),
}

## The export picture: `px` pixels a cell, markers as dots ringed in black.
func preview_image(px: int = 4) -> Image:
	var img := image()
	img.resize(cells * px, cells * px, Image.INTERPOLATE_NEAREST)
	var scale := float(px) / cell_m
	for m in markers:
		var p := Vector2((float(m["x"]) + size_m * 0.5) * scale, (float(m["z"]) + size_m * 0.5) * scale)
		var r := maxi(3, px + 2)
		img.fill_rect(Rect2i(int(p.x) - r - 1, int(p.y) - r - 1, 2 * r + 2, 2 * r + 2).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), Color.BLACK)
		img.fill_rect(Rect2i(int(p.x) - r, int(p.y) - r, 2 * r, 2 * r).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), MARKER_COLORS.get(str(m["kind"]), Color.WHITE))
	return img

# ---------------------------------------------------------------------------- importer

## The island definition the runtime builds from this map: size, climate, camp and harbour from
## the camp/town and dock markers, creatures from the spawn markers. `base` fills everything else
## (id, kind, tier, seed...).
func island_def(base: Dictionary = {}) -> Dictionary:
	var def := base.duplicate(true)
	def["size_m"] = size_m
	def["climate"] = climate
	def["map_doc"] = self
	var creatures: Array = []
	for m in markers:
		var at := [float(m["x"]), 0.0, float(m["z"])]
		match str(m["kind"]):
			"dock":
				def["harbour"] = at
			"camp":
				def["camp"] = at
			"town":
				if not def.has("camp"):
					def["camp"] = at
			"spawn":
				var p: Dictionary = m["props"]
				creatures.append({"species": str(p.get("species", "")), "count": int(p.get("count", 1)), "pack": int(p.get("count", 1)) > 1, "at": at, "level": int(p.get("level", 1))})
	# An explicit camp marker wins over the town's centre.
	for m in markers:
		if str(m["kind"]) == "camp":
			def["camp"] = [float(m["x"]), 0.0, float(m["z"])]
	def["creatures"] = creatures
	if not def.has("seed"):
		def["seed"] = hash(name)
	return def

## Fills the shape's grids (heights, effective radius, river distance and width, slopes) from the
## map instead of IslandShape.compute(): land/sea from the land layer, ground height from the height
## classes (blurred over about 3 cells so hills are slopes), rivers and lakes carved to the MUD bed.
## The shape keeps its noises (the beach plan reads them) and its size; the map's size must match.
func apply_to_shape(shape: IslandShape) -> void:
	var n := cells
	var sd := _signed_coast_distance()
	var wd := _distance_to(func(i: int) -> bool: return (layers["water"] as PackedByteArray)[i] != 0)
	var target := PackedFloat32Array()
	target.resize(n * n)
	var hb: PackedByteArray = layers["height"]
	for i in n * n:
		target[i] = HEIGHT_M[hb[i]]
	target = _blur(target, 2)
	target = _blur(target, 2)
	var res := shape.res
	var size := shape.size
	var cell := size / float(res - 1)
	var land_r := size * 0.36
	shape.heights.resize(res * res)
	shape.rads.resize(res * res)
	shape.river_d.resize(res * res)
	shape.river_w.resize(res * res)
	shape.vslope.resize(res * res)
	shape.river = PackedVector2Array()
	shape.waterfall = Vector3.ZERO
	var hw := cell_m * 0.5
	var sum := Vector2.ZERO
	var nland := 0
	for z in res:
		for x in res:
			var wx := -size * 0.5 + float(x) * cell
			var wz := -size * 0.5 + float(z) * cell
			var s := _sample(sd, wx, wz)
			var rd := maxf(0.0, _sample(wd, wx, wz) - hw * 0.5)
			var h: float
			# ASSUMPTION: sea floor 0.6 m down per metre out (to -3 m), a 6 m shore ramp inland.
			if s <= 0.0:
				h = maxf(-3.0, -0.05 + 0.6 * s)
			else:
				var ground := _sample(target, wx, wz)
				h = lerpf(0.1, ground, clampf(s / 6.0, 0.0, 1.0))
				if rd < hw:
					h = -0.3
				elif rd < hw + 3.0:
					h = lerpf(0.12, h, (rd - hw) / 3.0)
				sum += Vector2(wx, wz)
				nland += 1
			var idx := x + z * res
			shape.heights[idx] = h
			shape.rads[idx] = land_r - s
			shape.river_d[idx] = rd if s > 0.0 else 10000.0
			shape.river_w[idx] = hw
	if nland > 0:
		shape.centre = sum / float(nland)
	shape._slopes(cell)

## Writes the painted zones over the generator's zone map (unset cells keep the generator's).
func paint_zones(rt: IslandRuntime) -> void:
	var bio := BiomeZones.biome_types(rt)
	var span := rt._tile_span
	if bio.size() != span * span:
		return
	var zb: PackedByteArray = layers["zone"]
	var half := rt._size * 0.5
	for tz in span:
		for tx in span:
			var cl := cell_of(-half + float(tx) + 0.5, -half + float(tz) + 0.5)
			if in_grid(cl.x, cl.y) and zb[cl.x + cl.y * cells] > 0 and is_land(cl.x, cl.y):
				bio[tx + tz * span] = zb[cl.x + cl.y * cells] - 1
	BiomeZones.install(rt, bio)

## Metres from each cell centre to the coast: + on land, - at sea (two-pass chamfer on the grid).
func _signed_coast_distance() -> PackedFloat32Array:
	var land: PackedByteArray = layers["land"]
	var din := _distance_to(func(i: int) -> bool: return land[i] == 0)
	var dout := _distance_to(func(i: int) -> bool: return land[i] == 1)
	var out := PackedFloat32Array()
	out.resize(cells * cells)
	for i in out.size():
		# Half a cell either side: the coastline runs along the cell edges.
		out[i] = (din[i] - cell_m * 0.5) if land[i] == 1 else -(dout[i] - cell_m * 0.5)
	return out

## Chamfer (1, sqrt 2) distance in metres from every cell to the nearest cell where `is_src`.
func _distance_to(is_src: Callable) -> PackedFloat32Array:
	var n := cells
	var d := PackedFloat32Array()
	d.resize(n * n)
	var big := 1e6
	for i in n * n:
		d[i] = 0.0 if is_src.call(i) else big
	var a := cell_m
	var b := cell_m * 1.41421
	for r in n:
		for c in n:
			var i := c + r * n
			var v := d[i]
			if c > 0: v = minf(v, d[i - 1] + a)
			if r > 0:
				v = minf(v, d[i - n] + a)
				if c > 0: v = minf(v, d[i - n - 1] + b)
				if c < n - 1: v = minf(v, d[i - n + 1] + b)
			d[i] = v
	for r in range(n - 1, -1, -1):
		for c in range(n - 1, -1, -1):
			var i := c + r * n
			var v := d[i]
			if c < n - 1: v = minf(v, d[i + 1] + a)
			if r < n - 1:
				v = minf(v, d[i + n] + a)
				if c < n - 1: v = minf(v, d[i + n + 1] + b)
				if c > 0: v = minf(v, d[i + n - 1] + b)
			d[i] = v
	return d

## Separable box blur of radius `k` cells.
func _blur(src: PackedFloat32Array, k: int) -> PackedFloat32Array:
	var n := cells
	var tmp := PackedFloat32Array()
	tmp.resize(n * n)
	for r in n:
		for c in n:
			var s := 0.0
			for d in range(-k, k + 1):
				s += src[clampi(c + d, 0, n - 1) + r * n]
			tmp[c + r * n] = s / float(2 * k + 1)
	var out := PackedFloat32Array()
	out.resize(n * n)
	for r in n:
		for c in n:
			var s := 0.0
			for d in range(-k, k + 1):
				s += tmp[c + clampi(r + d, 0, n - 1) * n]
			out[c + r * n] = s / float(2 * k + 1)
	return out

## Bilinear sample of a cell field at a world point (cell centres are the samples).
func _sample(f: PackedFloat32Array, wx: float, wz: float) -> float:
	var u := clampf((wx + size_m * 0.5) / cell_m - 0.5, 0.0, float(cells - 1))
	var v := clampf((wz + size_m * 0.5) / cell_m - 0.5, 0.0, float(cells - 1))
	var c0 := int(floor(u))
	var r0 := int(floor(v))
	var c1 := mini(c0 + 1, cells - 1)
	var r1 := mini(r0 + 1, cells - 1)
	var tx := u - float(c0)
	var tz := v - float(r0)
	return lerpf(lerpf(f[c0 + r0 * cells], f[c1 + r0 * cells], tx), lerpf(f[c0 + r1 * cells], f[c1 + r1 * cells], tx), tz)
