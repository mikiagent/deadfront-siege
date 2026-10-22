class_name BiomeMaterial
extends RefCounted
## Builds terrain and foliage materials for one climate from data/world/biomes.json.
## Not hooked into island generation yet (W2-TERRAIN / W2-SCATTER call these).

const PATH := "res://data/world/biomes.json"
const TERRAIN_SHADER: Shader = preload("res://scripts/world/terrain_tiles.gdshader")
const FOLIAGE_SHADER: Shader = preload("res://scripts/world/foliage_sway.gdshader")
const LAYERS: Dictionary = {"ground": "grass_tex", "dirt": "dirt_tex", "sand": "sand_tex", "rock": "rock_tex"}

## Absolute water colours; compat_gain leaves them alone.
const WATER_KEYS := ["shallow", "deep"]

static var _rows: Dictionary = {}
static var _loaded := false

## Parsed once; a broken file is reported once and then reads as empty (no error per call).
static func rows() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_rows = parsed
		else:
			push_error("[biome] cannot parse %s" % PATH)
	return _rows

static func row(climate: String) -> Dictionary:
	var r: Variant = rows().get(climate, {})
	return r if r is Dictionary else {}

## Every climate key in biomes.json: rows that carry the four texture paths. That skips "_about",
## "water_only_families", and BiomeZones' "zones" / "zone_rules" tables, which are dictionaries too.
static func climates() -> Array[String]:
	var out: Array[String] = []
	var all := rows()
	for k in all:
		var row: Variant = all[k]
		if row is Dictionary and (row as Dictionary).get("textures") is Dictionary:
			out.append(str(k))
	return out

static func color(hex: String, fallback: Color = Color.WHITE) -> Color:
	return Color.from_string(hex, fallback)

## Points an existing terrain_tiles material at the climate's textures, palette and shader knobs.
## Leaves map_size, tile_map_tex, noise_tex and grid uniforms to the caller.
static func apply_terrain(m: ShaderMaterial, climate: String) -> bool:
	var r := row(climate)
	if r.is_empty():
		return false
	var tex: Dictionary = r.get("textures", {})
	for layer in LAYERS:
		var path := str(tex.get(layer, ""))
		if ResourceLoader.exists(path):
			m.set_shader_parameter(LAYERS[layer], load(path) as Texture2D)
		else:
			push_error("[biome] %s missing %s texture %s" % [climate, layer, path])
	var pal: Dictionary = r.get("palette", {})
	var gain := compat_gain(r, RenderingServer.get_current_rendering_method())
	for key in pal:
		var c := color(str(pal[key]))
		var g := 1.0 if key in WATER_KEYS else gain
		m.set_shader_parameter("tint_%s" % key, Vector3(c.r, c.g, c.b) * g)
	var knobs: Dictionary = r.get("shader", {})
	for key in knobs:
		m.set_shader_parameter(str(key), float(knobs[key]))
	return true

## gl_compatibility (the web renderer) lights the ground about twice as bright as Forward+, so snow
## and dune sand clip to flat white there. A row's compat_gain scales its ground tints in compat only.
static func compat_gain(r: Dictionary, rendering_method: String) -> float:
	return float(r.get("compat_gain", 1.0)) if rendering_method == "gl_compatibility" else 1.0

## A standalone terrain material (labs, and the W2 island hook).
static func terrain(climate: String, map_size: float, tile_map: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("map_size", map_size)
	m.set_shader_parameter("tile_map_tex", tile_map)
	m.set_shader_parameter("noise_tex", noise_texture())
	# Zone palette for this climate's tile map; the caller still needs zone 0 (neutral) tiles if it
	# wants the bare climate set, as biome_lab's patches do.
	m.set_shader_parameter("biome_pal", ImageTexture.create_from_image(BiomeZones.palette_image(climate)))
	m.set_shader_parameter("biome_on", 1.0)
	apply_terrain(m, climate)
	return m

static func foliage(climate: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	var r := row(climate)
	if r.has("foliage_tint"):
		m.set_shader_parameter("tint", color(str(r["foliage_tint"])))
	if r.has("foliage_tip"):
		m.set_shader_parameter("tip_tint", color(str(r["foliage_tip"])))
	return m

## Same noise island_runtime builds, so a lab patch matches the island ground.
static func noise_texture() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = 4121
	n.frequency = 0.09
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	return t
