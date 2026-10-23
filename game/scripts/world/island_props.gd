class_name IslandProps
extends Node3D
## Scenery layer: non-resource props (reeds, boulders, fallen logs, cliffs, pebbles...).
##
## Owner rules this file implements:
##   "Not every plant/rock/etc is a resource, the resources have the UI that is clickable and the props
##    do not." -> a prop is never in the "harvest" group, has no TapZone and no label. A tap on a prop
##    does nothing; tapping the resource next to it still opens the radial.
##   "Some props cause collision and some dont." -> collide kind = a StaticBody3D collider plus a
##    TilePath blocker; walk-through kind has neither.
##   "most props can be destroyed except for like really big cliffs" -> destroyable kinds clear on an
##    attack or when a building needs their tile; cliff/mesa/basalt-column rows in props.json never do.
##
## Placement: props.json lists, per kind, the models, biomes (with weights), scale range, collide,
## destroyable and a density per hectare. Biomes come from BiomeZones.biome_at() when that file
## exists (BIOMEZONES job) and otherwise from a local fallback read of height, slope and tile type.
## Visuals are batched through VegBatch (one MultiMesh per model per 32 m cell) so a dense island
## costs a handful of draws per cell instead of a node and a draw per prop.
##
## Save: cleared props are stored by tile ("x:y") and ride the existing harvest snapshot
## (IslandRuntime.harvest_tile_snapshot -> "props"), so no schema change.

const DATA_PATH := "res://data/world/props.json"
const BIOME_SCRIPT := "res://scripts/world/biome_zones.gd"
const PROP_GROUP := "props"
const COLLIDE_GROUP := "prop_collide"
## ASSUMPTION: scene nodes stay cheap by giving only colliding props a body; a walk-through prop is a
## batched instance and a dictionary row, nothing else.
const MAX_PROPS := 1400
const CLEAR_REACH_M := 2.6 ## how far in front of the attacker a prop can be cleared
## ASSUMPTION: props never grow on a building or under the camp fire.
const CAMP_KEEP_M := 7.0
## ASSUMPTION: a translucent dark overlay on every prop batch. Props share model files with resource
## nodes (Rock_1, WoodLog), and at iso zoom the silhouette alone does not say "not clickable".
const SCENERY_TINT := Color(0.34, 0.32, 0.28, 0.30)

static var _data_cache: Dictionary = {}
static var _biome_script: GDScript = null
static var _biome_checked := false

var runtime: IslandRuntime
var cleared_count: int = 0
var _rows: Array[Dictionary] = []      # one row per prop instance
var _cell_props: Dictionary = {}       # Vector2i -> Array[int] (centre cell + footprint)
var _cleared: Dictionary = {}          # "x:y" -> {"x","y","kind"}
var _biome_area: Dictionary = {}       # biome id -> m2
var _noise: FastNoiseLite
var _batches: Dictionary = {}          # model path -> VegBatch
var _card_batches: Dictionary = {}     # model path -> VegBatch (CARD2D stand-in)
var _rng := RandomNumberGenerator.new()

# ------------------------------------------------------------------ data

static func data() -> Dictionary:
	if not _data_cache.is_empty():
		return _data_cache
	if Data != null and not Data.world_props.is_empty():
		_data_cache = Data.world_props
		return _data_cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("[props] cannot read %s" % DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_data_cache = parsed as Dictionary
	return _data_cache

static func kinds() -> Dictionary:
	var k: Variant = data().get("kinds", {})
	return k as Dictionary if k is Dictionary else {}

static func kind_row(kind: String) -> Dictionary:
	var k: Variant = kinds().get(kind, {})
	return k as Dictionary if k is Dictionary else {}

## Biome weighting used by both props and (through island_scatter) resource nodes.
static func biome_weight(biome: String, channel: String) -> float:
	var sc: Variant = data().get("scatter", {})
	if not sc is Dictionary:
		return 1.0
	var w: Variant = (sc as Dictionary).get("weights", {})
	if not w is Dictionary:
		return 1.0
	var row: Variant = (w as Dictionary).get(biome, null)
	if not row is Dictionary:
		return 1.0
	return float((row as Dictionary).get(channel, 1.0))

static func scatter_row(key: String, fallback: Variant) -> Variant:
	var sc: Variant = data().get("scatter", {})
	if sc is Dictionary and (sc as Dictionary).has(key):
		return (sc as Dictionary)[key]
	return fallback

# ------------------------------------------------------------------ biome

## The zone id at a world point: BiomeZones when the BIOMEZONES package is in the tree, else a
## fallback from height, slope, tile type and climate. One of the ids in props.json "biomes".
func biome_at(x: float, z: float) -> String:
	return biome_of(runtime, x, z)

## Static form so island_scatter can weight resources by biome before the props node exists.
static func biome_of(rt: IslandRuntime, x: float, z: float) -> String:
	if rt == null:
		return "meadow"
	var bz := _biome_module()
	if bz != null:
		var raw: Variant = bz.call("biome_at", rt, x, z)
		# BIOMEZONES may answer with a zone id (int) or a name; an id goes through zone_name(id).
		if raw is int or raw is float:
			if bz.has_method("zone_name"):
				var named: Variant = bz.call("zone_name", int(raw))
				if named != null and str(named) != "":
					return _map_biome_name(str(named))
			var ids: Variant = bz.get("IDS") if bz.get("IDS") != null else null
			if ids is Array and int(raw) >= 0 and int(raw) < (ids as Array).size():
				return _map_biome_name(str((ids as Array)[int(raw)]))
		elif raw != null and str(raw) != "":
			return _map_biome_name(str(raw))
	if rt.tile_types.is_empty():
		return "meadow"
	var t := IslandTerrain.tile_type_at_world(rt, x, z)
	var h := rt.surface_y(x, z)
	if t == IslandTerrain.TileType.SHALLOW or t == IslandTerrain.TileType.DEEP or h < 0.35:
		return "beach"
	if t == IslandTerrain.TileType.WET:
		return "beach"
	if t == IslandTerrain.TileType.MUD:
		return "wetland"
	if t == IslandTerrain.TileType.ASH:
		return "basalt"
	var slope := IslandTerrain.slope_deg(rt, x, z)
	if t == IslandTerrain.TileType.ROCK or slope > 32.0 or h > 5.0:
		var cl := str(rt._climate)
		if cl == "volcanic":
			return "basalt"
		if cl == "desert" or cl == "savannah":
			return "canyon"
		return "rocky"
	if t == IslandTerrain.TileType.SAND:
		return "beach"
	if t == IslandTerrain.TileType.DRY:
		return "savanna"
	var cl2 := str(rt._climate)
	if cl2 == "desert":
		return "canyon"
	if cl2 == "volcanic":
		return "basalt"
	if cl2 == "savannah":
		return "savanna"
	if cl2 == "swamp" or cl2 == "tropical":
		return "wetland" if cl2 == "swamp" else "forest"
	# Moisture patchwork: forest groves and meadow between them.
	if t == IslandTerrain.TileType.GRASS and _moisture(x, z) < 0.42:
		return "forest"
	if t == IslandTerrain.TileType.DIRT:
		return "meadow"
	return "meadow"

## Map a BiomeZones id ("forest floor", "red-earth canyon", ...) onto props.json's eight ids.
static func _map_biome_name(raw: String) -> String:
	var s := raw.replace("_", " ").to_lower()
	if s.contains("beach") or s.contains("shore") or s.contains("coast") or s.contains("sand"):
		return "beach"
	if s.contains("river") or s.contains("wetland") or s.contains("marsh") or s.contains("swamp"):
		return "wetland"
	if s.contains("canyon") or s.contains("mesa") or s.contains("red"):
		return "canyon"
	if s.contains("basalt") or s.contains("volcan") or s.contains("ash"):
		return "basalt"
	if s.contains("rock") or s.contains("highland") or s.contains("cliff"):
		return "rocky"
	if s.contains("savanna") or s.contains("golden") or s.contains("steppe") or s.contains("dry"):
		return "savanna"
	if s.contains("forest") or s.contains("grove") or s.contains("jungle") or s.contains("wood"):
		return "forest"
	return "meadow"

static func _biome_module() -> GDScript:
	if _biome_checked:
		return _biome_script
	_biome_checked = true
	if ResourceLoader.exists(BIOME_SCRIPT):
		_biome_script = load(BIOME_SCRIPT) as GDScript
	if _biome_script != null and not _biome_script.has_method("biome_at"):
		_biome_script = null
	return _biome_script

static var _moisture_noise: FastNoiseLite = null

static func _moisture(x: float, z: float) -> float:
	if _moisture_noise == null:
		_moisture_noise = FastNoiseLite.new()
		_moisture_noise.seed = 4121
		_moisture_noise.frequency = 0.02
	return clampf(_moisture_noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)

# ------------------------------------------------------------------ build

static func build(rt: IslandRuntime) -> IslandProps:
	var p := IslandProps.new()
	p.name = "Props"
	p.runtime = rt
	rt.add_child(p)
	p._build_all()
	return p

func _build_all() -> void:
	if runtime == null:
		return
	var def: Dictionary = {}
	if World != null:
		var row: Variant = World.island_def
		if row is Dictionary:
			def = row as Dictionary
	var seed_v := int(def.get("seed", hash(str(def.get("id", "island")) + str(runtime._climate))))
	if def.has("seed"):
		seed_v = int(def.get("seed", 17))
	# Home keeps a stable layout across builds; its seed comes from the island row when present.
	_rng.seed = seed_v
	_sample_biomes()
	# Want per kind first, then one proportional cut to MAX_PROPS: a budget spent in dict order
	# would give everything to pebbles and nothing to the cliffs.
	var plan: Array[Dictionary] = []
	var wanted_total := 0
	for kind: String in kinds().keys():
		if kind.begins_with("_"):
			continue
		var rows := kind_row(kind)
		if rows.is_empty():
			continue
		var models := _existing_models(rows)
		if models.is_empty():
			continue
		var biomes: Variant = rows.get("biomes", {})
		if not biomes is Dictionary:
			continue
		var density := float(rows.get("density_per_ha", 0.0))
		if density <= 0.0:
			continue
		var want := 0.0
		for b: String in (biomes as Dictionary).keys():
			var w := float((biomes as Dictionary)[b])
			if w <= 0.0:
				continue
			var area_m2 := float(_biome_area.get(b, 0.0))
			want += density * (area_m2 / 10000.0) * w
		var n := int(round(want * _rng.randf_range(0.85, 1.15)))
		if n <= 0:
			continue
		plan.append({"kind": kind, "rows": rows, "models": models, "n": n})
		wanted_total += n
	var scale := 1.0
	if wanted_total > MAX_PROPS:
		# Every kind keeps at least one (a kind that never appears is a broken row, not a budget).
		scale = float(MAX_PROPS) / float(wanted_total)
	for entry in plan:
		var n: int = maxi(1, int(round(float(entry["n"]) * scale)))
		_place_kind(str(entry["kind"]), entry["rows"], entry["models"], n)
	for b: VegBatch in _batches.values():
		b.commit()
	for b: VegBatch in _card_batches.values():
		b.commit()
	print("[props] built id=%s kinds=%d props=%d colliding=%d destroyable=%d cleared=%d batches=%d by_kind=%s" % [
		str(runtime._climate), _kind_count(), _rows.size(), colliding_count(), destroyable_count(),
		cleared_count, _batches.size() + _card_batches.size(), _by_kind_line()])

## Land area per biome, sampled every 2 m (the terrain is 1 m tile-indexed; 4 m per sample is
## enough to weight densities and keeps the build under a few ms per 100k samples).
func _sample_biomes() -> void:
	_biome_area.clear()
	if runtime == null:
		return
	var span := runtime._tile_span
	if span <= 0:
		return
	var step := 2
	for tz in range(0, span, step):
		var wz := -runtime._size * 0.5 + float(tz) + 1.0
		for tx in range(0, span, step):
			var wx := -runtime._size * 0.5 + float(tx) + 1.0
			var t := IslandTerrain.tile_type_at_world(runtime, wx, wz)
			if t == IslandTerrain.TileType.SHALLOW or t == IslandTerrain.TileType.DEEP:
				continue
			var b := biome_at(wx, wz)
			_biome_area[b] = float(_biome_area.get(b, 0.0)) + float(step * step)

func _by_kind_line() -> String:
	var seen := {}
	for r in _rows:
		var k := str(r.get("kind", ""))
		seen[k] = int(seen.get(k, 0)) + 1
	var parts := PackedStringArray()
	for k in seen.keys():
		parts.append("%s:%d" % [k, int(seen[k])])
	return ",".join(parts)

func _kind_count() -> int:
	var seen := {}
	for r in _rows:
		seen[str(r.get("kind", ""))] = true
	return seen.size()

## Manifest-style model names ("Rock_1") or full res:// paths; missing files are skipped (the
## BIOMEASSETS job adds res://assets/nature/biome/*.glb later, so a kind can list one now and
## start drawing it when it exists). At most 3 variants per kind to keep draw calls down.
## A kind with no model but an existing card returns one empty entry, so it is placed as a billboard.
func _existing_models(rows: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var arr: Variant = rows.get("models", [])
	if not arr is Array:
		arr = []
	if arr.is_empty() and _card_path(rows) != "":
		# Painted-card kind (CARD2D): no mesh is needed, the card is the visual.
		out.append("")
		return out
	for m in arr:
		var path := _model_path(str(m))
		if path == "" or not ResourceLoader.exists(path):
			continue
		if out.has(path):
			continue
		out.append(path)
		if out.size() >= 3:
			break
	return out

## The 2D card a kind draws as, "" when it has none yet. A kind's card is either a res:// path to a
## PNG/WebP, or "prop:<id>" naming a row of data/sprites2d.json (the owner's painted props, drawn by
## CardProp in the CARD2D job). Until both exist the kind falls back to its GLB models.
static func _card_path(rows: Dictionary) -> String:
	var card := str(rows.get("card", ""))
	if card == "":
		return ""
	if card.begins_with("res://"):
		return card if ResourceLoader.exists(card) else ""
	# sprites2d.json (SPRITES2D) is {"sprites": [...]}; a painted prop is the row whose kind is
	# "prop:<id>". Older shape was {"props": {id: {path}}} - keep reading it if it ever returns.
	var id := card.trim_prefix("prop:")
	var data := _sprites_data()
	if data.has("sprites") and data["sprites"] is Array:
		for r in data["sprites"]:
			if r is Dictionary and str((r as Dictionary).get("kind", "")) == "prop:" + id:
				var f := str((r as Dictionary).get("file", ""))
				if f != "" and ResourceLoader.exists(f):
					return f
	var spr: Variant = data.get("props", null)
	if spr is Dictionary:
		var row: Variant = (spr as Dictionary).get(id, null)
		if row is Dictionary:
			var p := str((row as Dictionary).get("path", ""))
			if p != "" and ResourceLoader.exists(p):
				return p
		elif row is String and ResourceLoader.exists(str(row)):
			return str(row)
	return ""

static var _sprites: Dictionary = {}
static var _sprites_loaded := false

static func _sprites_data() -> Dictionary:
	if _sprites_loaded:
		return _sprites
	_sprites_loaded = true
	if ResourceLoader.exists("res://data/world/sprites2d.json"):
		var f := FileAccess.open("res://data/world/sprites2d.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_sprites = parsed as Dictionary
	return _sprites

static func _model_path(model: String) -> String:
	if model == "":
		return ""
	if model.begins_with("res://"):
		return model
	return "res://assets/nature/%s.glb" % model

func _place_kind(kind: String, rows: Dictionary, models: PackedStringArray, n: int) -> int:
	var placed := 0
	var tries := 0
	var max_tries := n * 60
	var collide := bool(rows.get("collide", false))
	var destroyable := bool(rows.get("destroyable", true))
	var radius := float(rows.get("radius_m", 0.6))
	# size_m: the prop's largest dimension in metres. Scale is derived per model (want / model's
	# longest side) so a wide log and a tall stump of one kind both read at their documented size.
	var h_a: Array = rows.get("size_m", [1.0, 1.0]) if rows.get("size_m", []) is Array else [1.0, 1.0]
	var h0 := float(h_a[0]) if h_a.size() > 0 else 1.0
	var h1 := float(h_a[1]) if h_a.size() > 1 else h0
	var water: Array = rows.get("water", []) if rows.get("water", []) is Array else []
	var cliff_only := bool(rows.get("cliff", false))
	var biome_w: Dictionary = rows.get("biomes", {})
	var half := runtime._size * 0.46
	while placed < n and tries < max_tries:
		tries += 1
		var wx := _rng.randf_range(-half, half)
		var wz := _rng.randf_range(-half, half)
		var biome := biome_at(wx, wz)
		var w := float(biome_w.get(biome, 0.0))
		if w <= 0.0:
			continue
		if _rng.randf() > w:
			continue
		var h := runtime.surface_y(wx, wz)
		var tile_name := _tile_name(wx, wz)
		if water.size() > 0:
			if not water.has(tile_name):
				continue
			if h < -0.6 or h > 0.6:
				continue
		else:
			if tile_name in ["SHALLOW", "DEEP", "MUD"]:
				continue
			if not runtime.spawn_ok(Vector3(wx, h, wz), false):
				continue
		if cliff_only:
			var slope := IslandTerrain.slope_deg(runtime, wx, wz)
			if slope < 28.0 and not (tile_name in ["ROCK", "ASH"]):
				continue
		if runtime.near_harbour(Vector3(wx, h, wz)):
			continue
		if Vector2(wx - runtime._camp_hint.x, wz - runtime._camp_hint.z).length() < CAMP_KEEP_M:
			continue
		var tile := BuildGrid.tile_of(Vector3(wx, h, wz))
		if runtime._used_tiles.has(tile):
			continue
		if _cell_props.has(tile):
			continue
		if collide and radius >= 1.0 and _cells_taken(tile, int(round(radius))):
			continue
		var want_h := _rng.randf_range(h0, h1)
		var path := models[_rng.randi_range(0, models.size() - 1)]
		var longest := 1.0 if path == "" else maxf(0.02, VegBatch.mesh_longest(path))
		var sc := clampf(want_h / longest, 0.02, 60.0)
		_spawn(kind, path, Vector3(wx, h, wz), sc, collide, destroyable, radius, want_h)
		placed += 1
	return placed

func _cells_taken(tile: Vector2i, r: int) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if _cell_props.has(tile + Vector2i(dx, dz)):
				return true
	return false

func _tile_name(x: float, z: float) -> String:
	var t := IslandTerrain.tile_type_at_world(runtime, x, z)
	match t:
		IslandTerrain.TileType.GRASS: return "GRASS"
		IslandTerrain.TileType.DRY: return "DRY"
		IslandTerrain.TileType.DIRT: return "DIRT"
		IslandTerrain.TileType.SAND: return "SAND"
		IslandTerrain.TileType.SHALLOW: return "SHALLOW"
		IslandTerrain.TileType.ROCK: return "ROCK"
		IslandTerrain.TileType.MUD: return "MUD"
		IslandTerrain.TileType.BARE: return "BARE"
		IslandTerrain.TileType.DEEP: return "DEEP"
		IslandTerrain.TileType.ASH: return "ASH"
		IslandTerrain.TileType.WET: return "WET"
	return "GRASS"

func _spawn(kind: String, path: String, pos: Vector3, scale: float, collide: bool, destroyable: bool, radius: float, size_m: float) -> void:
	# A painted-card kind has no mesh: its card is `size_m` tall (the card batch scales it).
	var h := size_m
	if path != "":
		h = VegBatch.mesh_height(path) * scale
	if h <= 0.02:
		h = size_m
	var yaw := _rng.randf() * TAU
	var basis := Basis.IDENTITY.rotated(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	var xf := Transform3D(basis, pos)
	var row := {
		"kind": kind,
		"tile": BuildGrid.tile_of(pos),
		"pos": pos,
		"scale": scale,
		"height": h,
		"collide": collide,
		"destroyable": destroyable,
		"radius": radius,
		"batch": null,
		"idx": -1,
		"body": null,
		"path": path,
		"xf": xf,
	}
	# ONE visual entry point. Today a prop draws as a VegBatch instance of its GLB (or a card PNG
	# listed on the kind); the CARD2D follow-up swaps the body of _draw_prop for a CardProp sprite and
	# nothing else in this file changes. The row keeps its transform so a redraw is one call.
	_draw_prop(row)
	var i := _rows.size()
	_rows.append(row)
	var cells := _footprint_cells(row)
	var list: Array = _cell_props.get(row["tile"], [])
	list.append(i)
	_cell_props[row["tile"]] = list
	if collide:
		row["cells"] = cells
		for c in cells:
			var cl: Array = _cell_props.get(c, [])
			cl.append(i)
			_cell_props[c] = cl
		row["body"] = _make_body(row, h)
		_add_blocked(cells)

## Draws row["path"] at row["xf"] and records the batch handle on the row. Every prop visual in the
## island goes through here (see the note in _spawn): the CARD2D job replaces this body with
## CardProp.make(kind) sprites, keyed by the kind's card id in sprites2d.json (kind "prop:*").
func _draw_prop(row: Dictionary) -> void:
	var kind := str(row.get("kind", ""))
	var path := str(row.get("path", ""))
	var xf: Transform3D = row.get("xf", Transform3D.IDENTITY)
	var h := float(row.get("height", 1.0))
	var batch: VegBatch = null
	var card := _card_path(kind_row(kind))
	if card != "":
		batch = _card_batch(card, float(row.get("scale", 1.0)), h)
	else:
		batch = _batch_for(path)
	if batch == null:
		return
	row["batch"] = batch
	row["idx"] = batch.add(xf)
	if h >= Occlusion.TALL_M:
		Occlusion.make_occludable(batch, Occlusion.BETWEEN)

func _batch_for(path: String) -> VegBatch:
	if _batches.has(path):
		return _batches[path]
	var b := VegBatch.get_for(self, path)
	if b != null:
		# Scenery never casts a shadow: it is decoration, and its shadow cost is the one part of the
		# camp budget a prop can pull without touching gameplay reads (the plan's shadow gate).
		b.cast_shadow_override = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# ASSUMPTION: scenery is a little darker and flatter than the same model used as a resource
		# node, so a player never mistakes a prop for something to tap (owner: only resources have UI).
		b.overlay_color = SCENERY_TINT
		_batches[path] = b
	return b

## CARD2D stand-in: a billboard quad from a PNG/WebP card, same batch/cell/collider rules as a GLB.
## (# ASSUMPTION: the card is drawn `card_height_m` tall and as wide as its aspect ratio.)
func _card_batch(card_path: String, _scale: float, height: float = 1.6) -> VegBatch:
	if _card_batches.has(card_path):
		return _card_batches[card_path]
	var tex := load(card_path) as Texture2D
	if tex == null:
		return null
	var h := height
	var w := h * (float(tex.get_width()) / maxf(1.0, float(tex.get_height())))
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	quad.center_offset = Vector3(0, h * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	var b := VegBatch.get_for_mesh(self, card_path, quad)
	if b != null:
		b.overlay_color = SCENERY_TINT
		_card_batches[card_path] = b
	return b

func _footprint_cells(row: Dictionary) -> Array:
	var tile: Vector2i = row["tile"]
	var radius := float(row.get("radius", 0.6)) * float(row.get("scale", 1.0))
	var r := int(floor(radius - 0.5))
	var out: Array = [tile]
	if r <= 0:
		return out
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := tile + Vector2i(dx, dz)
			if out.has(c):
				continue
			out.append(c)
	return out

func _make_body(row: Dictionary, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Prop_%s_%d_%d" % [str(row["kind"]), (row["tile"] as Vector2i).x, (row["tile"] as Vector2i).y]
	body.position = row["pos"] as Vector3
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(PROP_GROUP)
	body.add_to_group(COLLIDE_GROUP)
	body.set_meta(&"prop_kind", str(row["kind"]))
	body.set_meta(&"prop_tile", row["tile"])
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var cyl := CylinderShape3D.new()
	var hh := float(row.get("height", 1.0))
	var rad := clampf(float(row.get("radius", 0.6)) * maxf(0.5, hh / 2.0), 0.25, 3.2)
	cyl.radius = rad
	cyl.height = maxf(0.6, height)
	shape.shape = cyl
	shape.position.y = cyl.height * 0.5
	body.add_child(shape)
	add_child(body)
	return body

## TilePath reads this through the runtime hook: every cell a colliding prop occupies.
func blocked_cells() -> Array:
	var out: Array = []
	for row in _rows:
		if not bool(row.get("collide", false)) or row.get("body") == null:
			continue
		for c in row.get("cells", []):
			out.append(c)
	return out

func _add_blocked(cells: Array) -> void:
	if runtime == null:
		return
	runtime.mark_pathing_dirty()

# ------------------------------------------------------------------ queries

func prop_count() -> int:
	return _rows.size()

func colliding_count() -> int:
	var n := 0
	for r in _rows:
		if bool(r.get("collide", false)) and r.get("body") != null:
			n += 1
	return n

func destroyable_count() -> int:
	var n := 0
	for r in _rows:
		if bool(r.get("destroyable", true)):
			n += 1
	return n

func passable_count() -> int:
	return _rows.size() - colliding_count()

func is_cleared(tile: Vector2i) -> bool:
	return _cleared.has("%d:%d" % [tile.x, tile.y])

func cleared_tiles() -> Array:
	var out: Array = []
	for k in _cleared.keys():
		out.append((_cleared[k] as Dictionary).duplicate())
	return out

## A prop row whose centre is on this tile (null when none; an emptied tile stays in the map so a
## cleared prop is not re-placed there).
func prop_at_tile(tile: Vector2i) -> Dictionary:
	var list: Variant = _cell_props.get(tile, null)
	if not list is Array:
		return {}
	for i in (list as Array):
		var row := _rows[int(i)]
		if (row["tile"] as Vector2i) == tile and not row.get("cleared", false):
			return row
	for i in (list as Array):
		var row2 := _rows[int(i)]
		if not row2.get("cleared", false):
			return row2
	return {}

## A prop kind that must refuse a building (indestructible cliff/mesa) anywhere under these cells,
## "" when the spot is free or holds only clearable props. Used by BuildGrid.can_place (props hook).
func blocking_kind_at_cells(cells: Array) -> String:
	for c in cells:
		if not c is Vector2i:
			continue
		var row := prop_at_tile(c)
		if row.is_empty():
			continue
		# Only a big prop (a cliff, a mesa, a basalt column) refuses; a boulder the size of a
		# backpack is cleared for the build like any other scenery.
		if not bool(row.get("destroyable", true)):
			return str(row.get("kind", ""))
	return ""

# ------------------------------------------------------------------ clearing

## Attack clearing: the nearest destroyable prop within `reach` of `who`, in front of them.
func clear_in_front(who: Node3D, reach: float = CLEAR_REACH_M) -> bool:
	if who == null:
		return false
	var fwd := -who.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var best := -1
	var best_d := reach
	var p := who.global_position
	for i in _rows.size():
		var row := _rows[i]
		if bool(row.get("cleared", false)) or not bool(row.get("destroyable", true)):
			continue
		var pos: Vector3 = row["pos"]
		var d := Vector2(pos.x - p.x, pos.z - p.z).length()
		if d > best_d:
			continue
		var to := Vector3(pos.x - p.x, 0.0, pos.z - p.z).normalized()
		if d > 0.7 and fwd.dot(to) < 0.35:
			continue
		best = i
		best_d = d
	if best < 0:
		return false
	return _clear_index(best, true)

## Building clearing: every destroyable prop whose footprint touches these grid cells.
func clear_cells(cells: Array) -> int:
	var n := 0
	for c in cells:
		var list: Variant = _cell_props.get(c, null)
		if not list is Array:
			continue
		for i in (list as Array):
			var row := _rows[int(i)]
			if bool(row.get("cleared", false)) or not bool(row.get("destroyable", true)):
				continue
			if _clear_index(int(i), true):
				n += 1
	return n

## Clear one prop by its tile; false when there is none or it refuses (a cliff).
func clear_at_tile(tile: Vector2i) -> bool:
	var row := prop_at_tile(tile)
	if row.is_empty():
		return false
	if not bool(row.get("destroyable", true)):
		return false
	return _clear_index(_rows.find(row), true)

func _clear_index(i: int, record: bool) -> bool:
	if i < 0 or i >= _rows.size():
		return false
	var row := _rows[i]
	if bool(row.get("cleared", false)):
		return false
	if not bool(row.get("destroyable", true)):
		return false
	row["cleared"] = true
	var batch: VegBatch = row.get("batch")
	if batch != null and int(row.get("idx", -1)) >= 0:
		batch.set_shown(int(row["idx"]), false)
	var body: Variant = row.get("body")
	if body != null and is_instance_valid(body):
		(body as Node).queue_free()
	row["body"] = null
	if runtime != null:
		runtime.mark_pathing_dirty()
	var tile: Vector2i = row["tile"]
	var key := "%d:%d" % [tile.x, tile.y]
	if record:
		cleared_count += 1
		_cleared[key] = {"x": tile.x, "y": tile.y, "kind": str(row.get("kind", ""))}
	print("[props] cleared %s at (%d,%d)" % [str(row.get("kind", "")), tile.x, tile.y])
	return true

# ------------------------------------------------------------------ save

## Rows for the harvest snapshot: one per cleared prop, keyed by tile.
func snapshot() -> Dictionary:
	var rows: Array = []
	for k in _cleared.keys():
		rows.append((_cleared[k] as Dictionary).duplicate())
	return {"cleared": rows}

func apply_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	var arr: Variant = snap.get("cleared", [])
	if not arr is Array:
		return
	for v in arr:
		if not v is Dictionary:
			continue
		var row := v as Dictionary
		var tile := Vector2i(int(row.get("x", 0)), int(row.get("y", 0)))
		var key := "%d:%d" % [tile.x, tile.y]
		_cleared[key] = {"x": tile.x, "y": tile.y, "kind": str(row.get("kind", ""))}
		var p := prop_at_tile(tile)
		if p.is_empty():
			continue
		var kind := str(row.get("kind", ""))
		if kind != "" and str(p.get("kind", "")) != kind:
			continue
		if bool(p.get("destroyable", true)):
			_clear_index(_rows.find(p), false)

## Place one prop of `kind` at a world point through the normal path (tests and the lab use this to
## get a cliff or a log exactly where they need it). False when the kind has no existing model.
func add_prop(kind: String, pos: Vector3, want_size: float = 2.0) -> bool:
	var rows := kind_row(kind)
	if rows.is_empty():
		return false
	var models := _existing_models(rows)
	if models.is_empty():
		return false
	if pos.y < -100.0:
		pos.y = runtime.surface_y(pos.x, pos.z)
	var path := models[0]
	var longest := 1.0 if path == "" else maxf(0.02, VegBatch.mesh_longest(path))
	var sc := clampf(want_size / longest, 0.02, 60.0)
	_spawn(kind, path, pos, sc, bool(rows.get("collide", false)), bool(rows.get("destroyable", true)),
		float(rows.get("radius_m", 0.6)), want_size)
	var batch: Variant = _batches.get(path, null)
	if batch != null:
		(batch as VegBatch).commit()
	if runtime != null:
		runtime.mark_pathing_dirty()
	return true

## One line for the lab and logs.
func counts_line() -> String:
	return "id=%s props=%d colliding=%d passable=%d destroyable=%d cleared=%d" % [
		str(runtime._climate) if runtime != null else "-", prop_count(), colliding_count(),
		passable_count(), destroyable_count(), cleared_count]
