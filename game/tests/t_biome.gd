extends SceneTree
## W1-BIOME: biomes.json covers every climate with real textures and sane allowlists;
## the 1k bakes ship at process/size_limit=512 (pack budget), so the imported texture is 512 px;
## shader defaults still reproduce the pre-biome look; BiomeMaterial builds both materials.
## Run: Godot --headless --path game --script res://tests/t_biome.gd -> "[t_biome] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before the autoloads and the
## global class cache exist, so naming Data/World/BiomeMaterial/BiomeZones/BiomePatch at compile time
## fails the build with "Identifier not found" (t_domain's pattern).

var failures: Array[String] = []
var _started := false
var BM: GDScript
var BZ: GDScript
var BP: GDScript

func _process(_delta: float) -> bool:
	if _started or root == null or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _run() -> void:
	BM = load("res://scripts/world/biome_material.gd")
	BZ = load("res://scripts/world/biome_zones.gd")
	BP = load("res://scripts/dev/biome_patch.gd")
	var climates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/climates.json"))
	var rows: Dictionary = BM.rows()
	var water_only: Array = rows.get("water_only_families", [])
	for climate in climates:
		if str(climate).begins_with("_"):
			continue
		var c: Dictionary = climates[climate]
		var r: Dictionary = BM.row(climate)
		if r.is_empty():
			failures.append("%s has no biomes.json row" % climate)
			continue
		var veg: Array = c.get("vegetation", [])
		for layer in BM.LAYERS:
			var path := str(r.get("textures", {}).get(layer, ""))
			var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
			if tex == null or tex.get_width() != 512:
				failures.append("%s %s texture missing or not 512 px: %s" % [climate, layer, path])
		for fam in r.get("ground_cover", []):
			if not fam in veg or fam in water_only:
				failures.append("%s ground_cover %s not allowed" % [climate, fam])
		for fam in r.get("palm_allowlist", []):
			if not fam in veg:
				failures.append("%s palm %s not in its vegetation" % [climate, fam])
		var has_ash := false
		for m in c.get("materials", []):
			has_ash = has_ash or str(m.get("id", "")) == "ash"
		if ("ash" in r.get("special_tiles", [])) != has_ash:
			failures.append("%s ash tile allowlist disagrees with its materials" % climate)
		# world-placement-08: berry bushes only where the climate grows BushBerries (none on the volcano).
		if ("berry_bush" in r.get("special_families", [])) != ("BushBerries" in veg):
			failures.append("%s berry_bush allowlist disagrees with its vegetation" % climate)
		_check_keys(climate, r)
		_check_import(climate, r)
	for dry in ["desert", "volcanic", "tundra", "snowfield"]:
		if not BM.row(dry).get("palm_allowlist", []).is_empty():
			failures.append("%s allows palms" % dry)
	_check_defaults()
	_check_materials()
	_check_lab_slope()
	_check_zone_palette()
	_check_detail()
	if failures.is_empty():
		print("[t_biome] PASS %d climates" % BM.climates().size())
		quit(0)
	else:
		for f in failures:
			print("[t_biome] FAIL %s" % f)
		quit(1)

## The new uniforms default to the constants the shaders hard-coded before W1-BIOME. Headless
## has no renderer to ask for defaults, so this reads the declarations.
func _check_defaults() -> void:
	var lines := {
		BM.TERRAIN_SHADER: ["uniform float slope_dry_lo = 0.12;", "uniform float slope_dry_hi = 0.30;",
			"uniform float slope_rock_lo = 0.32;", "uniform float slope_rock_hi = 0.50;",
			"uniform float macro_strength = 0.20;", "uniform float macro_scale = 15.0;",
			"albedo *= 1.0 - macro_strength * 0.5 + macro * macro_strength;"],
		BM.FOLIAGE_SHADER: ["uniform vec3 tip_tint : source_color = vec3(1.0);",
			"uniform float root_dark = 0.75;", "uniform float tip_gain = 0.35;",
			"ALBEDO = tint * mix(vec3(1.0), tip_tint, y) * (root_dark + tip_gain * y)"],  # SKYSHADOWS multiplies v_sky after it
	}
	for sh: Shader in lines:
		for line: String in lines[sh]:
			if not sh.code.contains(line):
				failures.append("%s lacks default line: %s" % [sh.resource_path, line])

## Every palette key must be a tint_<key> uniform and every knob a uniform, or
## set_shader_parameter drops the typo silently.
func _check_keys(climate: String, r: Dictionary) -> void:
	var names := _uniforms(BM.TERRAIN_SHADER)
	for key in r.get("palette", {}):
		if not ("tint_%s" % key) in names:
			failures.append("%s palette key %s has no tint_%s uniform" % [climate, key, key])
	for key in r.get("shader", {}):
		if not str(key) in names:
			failures.append("%s shader knob %s is not a uniform" % [climate, key])

## Uniform names from the renderer; headless has none, so fall back to the declarations.
func _uniforms(sh: Shader) -> PackedStringArray:
	var out := PackedStringArray()
	for u: Dictionary in sh.get_shader_uniform_list():
		out.append(str(u["name"]))
	if out.is_empty():
		var re := RegEx.create_from_string("(?m)^\\s*uniform\\s+\\w+\\s+(\\w+)")
		for m in re.search_all(sh.code):
			out.append(m.get_string(1))
	return out

## terrain_tiles samples with filter_linear_mipmap, so the sets must import with mipmaps
## (VRAM compressed keeps each set under 3 MB per platform).
func _check_import(climate: String, r: Dictionary) -> void:
	for layer in BM.LAYERS:
		var cfg := ConfigFile.new()
		var path := str(r.get("textures", {}).get(layer, "")) + ".import"
		if cfg.load(path) != OK:
			failures.append("%s cannot read %s" % [climate, path])
			continue
		if not cfg.get_value("params", "mipmaps/generate", false):
			failures.append("%s imports without mipmaps" % path)
		if int(cfg.get_value("params", "compress/mode", -1)) != 2:
			failures.append("%s is not VRAM compressed" % path)
		if int(cfg.get_value("params", "process/size_limit", 0)) > 512:
			failures.append("%s imports at size_limit %s, over the 512 pack budget" % [path, cfg.get_value("params", "process/size_limit")])

## The lab patch must reach every climate's rock band, or the rock layer never shows in a shot.
func _check_lab_slope() -> void:
	var need := 0.50
	for climate in BM.climates():
		need = maxf(need, float(BM.row(climate).get("shader", {}).get("slope_rock_hi", 0.50)))
	var got: float = float(BP.max_slope())
	if got < need:
		failures.append("biome_lab steepest v_slope %.2f is under slope_rock_hi %.2f" % [got, need])
	else:
		print("[t_biome] lab steepest v_slope %.2f >= %.2f" % [got, need])

## Every climate's zone palette must tint the zones differently from the plain baked set, or the
## ground painting is a no-op; the shader must also still default to painting (biome_on = 1).
func _check_zone_palette() -> void:
	for climate in BM.climates():
		var img: Image = BZ.palette_image(climate)
		var tints := {}
		for i in BZ.zone_count():
			tints[img.get_pixel(i, 0).to_html()] = true
		if tints.size() < 4:
			failures.append("%s zone palette has only %d distinct tints" % [climate, tints.size()])
	if not BM.TERRAIN_SHADER.code.contains("uniform float biome_on = 1.0;"):
		failures.append("terrain shader does not default biome_on to 1")

## Pixel detail (mean |lum - 3x3 blur| / mean lum) on the centre 128 px of each source image must
## match the Poly Haven layer it replaces; the first bake was flat cloud noise at a fifth of it.
const REFERENCE := {"ground": "aerial_grass_rock_diff_1k.jpg", "dirt": "brown_mud_leaves_01_diff_1k.jpg",
	"sand": "aerial_beach_01_diff_1k.jpg", "rock": "rocky_trail_diff_1k.jpg"}
## Snow and dune ground are compared with the beach, as the bake does (recipes.py floor_ref).
const SAND_LIKE := ["snowfield", "desert"]

func _check_detail() -> void:
	var ref := {}
	for layer in REFERENCE:
		ref[layer] = _detail("res://assets/terrain/" + REFERENCE[layer])
	for climate in BM.climates():
		var tex: Dictionary = BM.row(climate).get("textures", {})
		for layer in BM.LAYERS:
			var against: String = "sand" if layer == "ground" and climate in SAND_LIKE else layer
			var d := _detail(str(tex.get(layer, "")))
			if d < float(ref[against]) * 0.9:
				failures.append("%s %s detail %.4f under the Poly Haven %s %.4f" % [climate, layer, d, against, ref[against]])

func _detail(path: String) -> float:
	var img := Image.new()  # raw jpg bytes: the imported texture is VRAM compressed
	if img.load_jpg_from_buffer(FileAccess.get_file_as_bytes(path)) != OK or img.is_empty():
		failures.append("cannot read %s" % path)
		return 0.0
	img.convert(Image.FORMAT_RGB8)
	var n := 128
	var x0 := img.get_width() / 2 - n / 2
	var crop := img.get_region(Rect2i(x0, x0, n, n))
	var lum := PackedFloat32Array()
	lum.resize(n * n)
	var data := crop.get_data()
	for i in n * n:
		lum[i] = (data[i * 3] + data[i * 3 + 1] + data[i * 3 + 2]) / 765.0
	var hf := 0.0
	var mean := 0.0
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			var box := 0.0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					box += lum[(y + dy) * n + x + dx]
			hf += absf(lum[y * n + x] - box / 9.0)
			mean += lum[y * n + x]
	return hf / maxf(mean, 0.0001)

func _check_materials() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_R8)
	var m: ShaderMaterial = BM.terrain("desert", 40.0, ImageTexture.create_from_image(img))
	var g := m.get_shader_parameter("grass_tex") as Texture2D
	if g == null or g.resource_path != "res://assets/terrain/desert/ground.jpg":
		failures.append("desert terrain grass_tex is %s" % [g.resource_path if g else "null"])
	var vt: Variant = m.get_shader_parameter("tex_scale")
	if vt == null or absf(float(vt) - 6.0) > 0.001:
		failures.append("desert tex_scale knob not applied: %s" % [vt])
	var fol: ShaderMaterial = BM.foliage("savannah")
	var tint: Variant = fol.get_shader_parameter("tint")
	if not (tint is Color) or (tint as Color).to_html(false) != "a0944e":
		failures.append("savannah foliage tint is %s" % [tint])
	var snow: Dictionary = BM.row("snowfield")
	if BM.compat_gain(snow, "gl_compatibility") >= 0.9 or BM.compat_gain(snow, "forward_plus") != 1.0:
		failures.append("snowfield compat_gain must dim compat only")
	if BM.apply_terrain(ShaderMaterial.new(), "no_such_climate"):
		failures.append("unknown climate applied")
