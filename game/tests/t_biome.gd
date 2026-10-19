extends SceneTree
## W1-BIOME: biomes.json covers every climate with real 1024 px textures and sane allowlists;
## shader defaults still reproduce the pre-biome look; BiomeMaterial builds both materials.

var failures: Array[String] = []

func _init() -> void:
	var climates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/climates.json"))
	var rows := BiomeMaterial.rows()
	var water_only: Array = rows.get("water_only_families", [])
	for climate in climates:
		if str(climate).begins_with("_"):
			continue
		var c: Dictionary = climates[climate]
		var r := BiomeMaterial.row(climate)
		if r.is_empty():
			failures.append("%s has no biomes.json row" % climate)
			continue
		var veg: Array = c.get("vegetation", [])
		for layer in BiomeMaterial.LAYERS:
			var path := str(r.get("textures", {}).get(layer, ""))
			var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
			if tex == null or tex.get_width() != 1024:
				failures.append("%s %s texture missing or not 1024 px: %s" % [climate, layer, path])
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
	for dry in ["desert", "volcanic", "tundra", "snowfield"]:
		if not BiomeMaterial.row(dry).get("palm_allowlist", []).is_empty():
			failures.append("%s allows palms" % dry)
	_check_defaults()
	_check_materials()
	if failures.is_empty():
		print("[t_biome] PASS %d climates" % BiomeMaterial.climates().size())
		quit(0)
	else:
		for f in failures:
			print("[t_biome] FAIL %s" % f)
		quit(1)

## The new uniforms default to the constants the shaders hard-coded before W1-BIOME. Headless
## has no renderer to ask for defaults, so this reads the declarations.
func _check_defaults() -> void:
	var lines := {
		BiomeMaterial.TERRAIN_SHADER: ["uniform float slope_dry_lo = 0.12;", "uniform float slope_dry_hi = 0.30;",
			"uniform float slope_rock_lo = 0.32;", "uniform float slope_rock_hi = 0.50;",
			"uniform float macro_strength = 0.20;", "uniform float macro_scale = 12.0;",
			"albedo *= 1.0 - macro_strength * 0.5 + texture(noise_tex, p / macro_scale).r * macro_strength;"],
		BiomeMaterial.FOLIAGE_SHADER: ["uniform vec3 tip_tint : source_color = vec3(1.0);",
			"uniform float root_dark = 0.75;", "uniform float tip_gain = 0.35;",
			"ALBEDO = tint * mix(vec3(1.0), tip_tint, y) * (root_dark + tip_gain * y);"],
	}
	for sh: Shader in lines:
		for line: String in lines[sh]:
			if not sh.code.contains(line):
				failures.append("%s lacks default line: %s" % [sh.resource_path, line])

func _check_materials() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_R8)
	var m := BiomeMaterial.terrain("desert", 40.0, ImageTexture.create_from_image(img))
	var g := m.get_shader_parameter("grass_tex") as Texture2D
	if g == null or g.resource_path != "res://assets/terrain/desert/ground.jpg":
		failures.append("desert terrain grass_tex is %s" % [g.resource_path if g else "null"])
	var vt: Variant = m.get_shader_parameter("tex_scale")
	if vt == null or absf(float(vt) - 6.0) > 0.001:
		failures.append("desert tex_scale knob not applied: %s" % [vt])
	var fol := BiomeMaterial.foliage("savannah")
	var tint: Variant = fol.get_shader_parameter("tint")
	if not (tint is Color) or (tint as Color).to_html(false) != "a0944e":
		failures.append("savannah foliage tint is %s" % [tint])
	if BiomeMaterial.apply_terrain(ShaderMaterial.new(), "no_such_climate"):
		failures.append("unknown climate applied")
