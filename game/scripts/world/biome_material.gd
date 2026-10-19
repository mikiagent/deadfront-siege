class_name BiomeMaterial
extends RefCounted
## Builds terrain and foliage materials for one climate from data/world/biomes.json.
## Not hooked into island generation yet (W2-TERRAIN / W2-SCATTER call these).

const PATH := "res://data/world/biomes.json"
const TERRAIN_SHADER: Shader = preload("res://scripts/world/terrain_tiles.gdshader")
const FOLIAGE_SHADER: Shader = preload("res://scripts/world/foliage_sway.gdshader")
const LAYERS: Dictionary = {"ground": "grass_tex", "dirt": "dirt_tex", "sand": "sand_tex", "rock": "rock_tex"}

static var _rows: Dictionary = {}

static func rows() -> Dictionary:
	if _rows.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_rows = parsed
		else:
			push_error("[biome] cannot parse %s" % PATH)
	return _rows

static func row(climate: String) -> Dictionary:
	var r: Variant = rows().get(climate, {})
	return r if r is Dictionary else {}

## Every climate key in biomes.json (skips "_about" and other non-row keys).
static func climates() -> Array[String]:
	var out: Array[String] = []
	for k in rows():
		if rows()[k] is Dictionary:
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
	for key in pal:
		var c := color(str(pal[key]))
		m.set_shader_parameter("tint_%s" % key, Vector3(c.r, c.g, c.b))
	var knobs: Dictionary = r.get("shader", {})
	for key in knobs:
		m.set_shader_parameter(str(key), float(knobs[key]))
	return true

## A standalone terrain material (labs, and the W2 island hook).
static func terrain(climate: String, map_size: float, tile_map: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("map_size", map_size)
	m.set_shader_parameter("tile_map_tex", tile_map)
	m.set_shader_parameter("noise_tex", noise_texture())
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
