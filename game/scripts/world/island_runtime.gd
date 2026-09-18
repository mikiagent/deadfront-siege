extends Node3D
## Generates a private or unstable island: heightmap, nav, harvest, harbour, camp, crater.

var harvest_count: int = 0
var creature_count: int = 0
var mm_count: int = 0
var harbour
var cargo
var cargo_basket
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var _size: float = 240.0
var _res: int = 65
var _heights: PackedFloat32Array = PackedFloat32Array()
var raining: bool = false
var _rain_left: float = 0.0
var _rain_cd: float = 40.0
var _wet_area: Area3D
var _rain_fx: GPUParticles3D
var _climate: String = "temperate"
var _tier: int = 25
var _camp_pos: Vector3 = Vector3.ZERO
var _harbour_pos: Vector3 = Vector3.ZERO
var spawn_rejected: int = 0

## Radius of dry, walkable land: the beach blend starts at 0.40 * size (see _terrain).
func land_radius() -> float:
	return _size * 0.40

## True when a creature may stand at pos: on dry land above the beach and the river,
## inside the land radius and (when strict) at least 25 m from camp and the harbour
## (rules.json landing ring: "nothing spawns within 25 m of camp").
func spawn_ok(pos: Vector3, strict: bool = true) -> bool:
	if _heights.is_empty():
		return true
	if Vector2(pos.x, pos.z).length() > land_radius() - 2.0:
		return false
	if surface_y(pos.x, pos.z) < 0.4:
		return false
	if strict:
		var keep := 25.0
		if Vector2(pos.x - _camp_pos.x, pos.z - _camp_pos.z).length() < keep:
			return false
		if Vector2(pos.x - _harbour_pos.x, pos.z - _harbour_pos.z).length() < keep * 0.6:
			return false
	return true

func build(def: Dictionary, terrain: StringName) -> void:
	var size := float(def.get("size_m", 160))
	# ASSUMPTION: rules.json island_size_m.unstable is 240 but rings extend to 240 m radius;
	# the generator uses diameter = 2 * far_shore so crater and far-shore rings fit on the mesh.
	if str(def.get("kind", "")) != "private":
		var rings: Dictionary = Data.world_rules.get("rings", {})
		var far: Variant = rings.get("far_shore", {})
		if far is Dictionary:
			var span: Array = (far as Dictionary).get("radius_m", [])
			if span.size() >= 2:
				size = maxf(size, float(span[1]) * 2.0)
	_climate = str(def.get("climate", "grassland"))
	_tier = int(def.get("tier", 10))
	_env()
	_sun()
	_terrain(size, _climate)
	var harbour_a: Array = def.get("harbour", [0, 0, 12])
	var camp_a: Array = def.get("camp", [0, 0, 6])
	_camp_pos = _at(float(camp_a[0]), float(camp_a[2]))
	_harbour_pos = _at(float(harbour_a[0]), float(harbour_a[2]))
	harbour = (load("res://scripts/world/harbour.gd") as GDScript).new()
	harbour.position = _harbour_pos
	add_child(harbour)
	_camp(_at(float(camp_a[0]), float(camp_a[2])))
	cargo = (load("res://scripts/world/cargo_warp.gd") as GDScript).new()
	cargo.position = _at(float(camp_a[0]) + 3.0, float(camp_a[2]))
	add_child(cargo)
	if str(def.get("kind", "")) == "private":
		var PB := load("res://scripts/world/placed_building.gd") as GDScript
		cargo_basket = PB.make(&"basket")
		cargo_basket.is_cargo = true
		cargo_basket.storage = World.cargo_home
		cargo_basket.position = _at(float(harbour_a[0]) + 3.0, float(harbour_a[2]))
		add_child(cargo_basket)
	_scatter(def, terrain, _climate, _tier, size)
	_creatures(def)
	var crater_v: Variant = def.get("crater", null)
	if crater_v is Array:
		_crater(_at(float(crater_v[0]), float(crater_v[2])))
	_rain_layer()
	print("[world] island %s nodes=%d creatures=%d spawn_rejected=%d" % [def.get("id", ""), harvest_count, creature_count, spawn_rejected])

func _env() -> void:
	var scene := get_tree().current_scene
	if scene:
		var old_sun := scene.get_node_or_null("Sun") as DirectionalLight3D
		if old_sun:
			old_sun.visible = false
	world_env = get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		world_env.environment.background_color = Color(0.55, 0.72, 0.90)
		world_env.environment.ambient_light_energy = 0.95
		world_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world_env.environment.ambient_light_color = Color(0.92, 0.94, 0.88)
		return
	world_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.72, 0.90)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.94, 0.88)
	e.ambient_light_energy = 0.95
	e.ssao_enabled = false
	e.ssr_enabled = false
	e.glow_enabled = false
	e.fog_enabled = false
	world_env.environment = e
	add_child(world_env)

func _sun() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = OS.get_name() != "iOS"
	sun.directional_shadow_max_distance = 90.0
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)

func _process(delta: float) -> void:
	_drive_day()
	_weather(delta)

func surface_y(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var cell := _size / float(_res - 1)
	var u := clampf((x + _size * 0.5) / cell, 0.0, float(_res - 1))
	var v := clampf((z + _size * 0.5) / cell, 0.0, float(_res - 1))
	var x0 := int(floor(u))
	var z0 := int(floor(v))
	var x1 := mini(x0 + 1, _res - 1)
	var z1 := mini(z0 + 1, _res - 1)
	var tx := u - float(x0)
	var tz := v - float(z0)
	var h00 := _heights[x0 + z0 * _res]
	var h10 := _heights[x1 + z0 * _res]
	var h01 := _heights[x0 + z1 * _res]
	var h11 := _heights[x1 + z1 * _res]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func _at(x: float, z: float) -> Vector3:
	return Vector3(x, surface_y(x, z), z)

func ring_name(pos: Vector3) -> StringName:
	var r := Vector2(pos.x, pos.z).length()
	var rings: Dictionary = Data.world_rules.get("rings", {})
	for id in ["landing", "gathering", "working", "crater", "far_shore"]:
		var row: Variant = rings.get(id, {})
		if row is Dictionary:
			var span: Array = row.get("radius_m", [0, 0])
			if span.size() >= 2 and r >= float(span[0]) and r < float(span[1]):
				return StringName(id)
	return &"far_shore"

func material_level(pos: Vector3, tier: int) -> int:
	var rings: Dictionary = Data.world_rules.get("rings", {})
	var row: Dictionary = rings.get(str(ring_name(pos)), {})
	var off := int(row.get("level_offset", 0))
	return clampi(tier + off, 1, int(Data.world_rules.get("level_cap", 60)))

func _terrain(size: float, climate: String) -> void:
	_size = size
	_heights.resize(_res * _res)
	var noise := FastNoiseLite.new()
	noise.seed = 25 if climate == "temperate" else 17
	noise.frequency = 0.018
	var cell := size / float(_res - 1)
	for z in _res:
		for x in _res:
			var wx := -size * 0.5 + float(x) * cell
			var wz := -size * 0.5 + float(z) * cell
			var h := 2.2 + noise.get_noise_2d(wx, wz) * 2.4
			var rad := Vector2(wx, wz).length()
			var edge := size * 0.46
			if rad > edge:
				h = lerpf(h, -2.2, clampf((rad - edge) / (size * 0.08), 0.0, 1.0))
			elif rad > size * 0.40:
				h = lerpf(h, 0.35, clampf((rad - size * 0.40) / (size * 0.06), 0.0, 1.0))
			var river := absf(wz - sin(wx * 0.04) * 8.0)
			if river < 4.5 and rad > 32.0:
				h = minf(h, 0.12 - (4.5 - river) * 0.08)
			_heights[x + z * _res] = h
	_build_terrain_mesh(size, cell, climate)
	_sea(size)
	_river_trigger()
	_nav_bake()

func _build_terrain_mesh(size: float, cell: float, climate: String) -> void:
	var grass := Color(0.42, 0.62, 0.32) if climate != "savannah" else Color(0.62, 0.56, 0.32)
	var sand := Color(0.82, 0.74, 0.52)
	var dirt := Color(0.42, 0.32, 0.20)
	var body := StaticBody3D.new()
	body.name = "Floor"
	var tiles := 4
	var span := int((_res - 1) / tiles)
	for tz in tiles:
		for tx in tiles:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var x0 := tx * span
			var z0 := tz * span
			var x1 := _res - 1 if tx == tiles - 1 else (tx + 1) * span
			var z1 := _res - 1 if tz == tiles - 1 else (tz + 1) * span
			for z in range(z0, z1):
				for x in range(x0, x1):
					_tri(st, size, cell, x, z, grass, sand, dirt)
					_tri2(st, size, cell, x, z, grass, sand, dirt)
			st.generate_normals()
			var mi := MeshInstance3D.new()
			mi.name = "TerrainMesh_%d_%d" % [tx, tz]
			mi.mesh = st.commit()
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 1.0
			mat.metallic = 0.0
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = mat
			mi.extra_cull_margin = 80.0
			body.add_child(mi)
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = _res
	hs.map_depth = _res
	hs.map_data = _heights
	cs.shape = hs
	cs.position = Vector3.ZERO
	cs.scale = Vector3(cell, 1, cell)
	body.add_child(cs)
	add_child(body)

func _tri(st: SurfaceTool, size: float, cell: float, x: int, z: int, grass: Color, sand: Color, dirt: Color) -> void:
	_vert(st, size, cell, x, z, grass, sand, dirt)
	_vert(st, size, cell, x + 1, z, grass, sand, dirt)
	_vert(st, size, cell, x, z + 1, grass, sand, dirt)

func _tri2(st: SurfaceTool, size: float, cell: float, x: int, z: int, grass: Color, sand: Color, dirt: Color) -> void:
	_vert(st, size, cell, x + 1, z, grass, sand, dirt)
	_vert(st, size, cell, x + 1, z + 1, grass, sand, dirt)
	_vert(st, size, cell, x, z + 1, grass, sand, dirt)

func _vert(st: SurfaceTool, size: float, cell: float, x: int, z: int, grass: Color, sand: Color, dirt: Color) -> void:
	var wx := -size * 0.5 + float(x) * cell
	var wz := -size * 0.5 + float(z) * cell
	var h := _heights[x + z * _res]
	var col := grass
	if h < 0.05:
		col = sand
	if h < -0.2:
		col = Color(0.28, 0.46, 0.58)
	var rad := Vector2(wx, wz).length()
	if rad > 150.0 and h > 0.4:
		col = dirt
	st.set_color(col)
	st.add_vertex(Vector3(wx, h, wz))

func _sea(size: float) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size * 1.6, size * 1.6)
	water.mesh = plane
	water.position.y = -1.1
	water.extra_cull_margin = 300.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.42, 0.60, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = mat
	add_child(water)

func _river_trigger() -> void:
	_wet_area = Area3D.new()
	_wet_area.name = "Wet"
	_wet_area.monitoring = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_size, 2.0, 10.0)
	cs.shape = box
	cs.position.y = -0.2
	_wet_area.add_child(cs)
	_wet_area.body_entered.connect(func (b: Node) -> void:
		if b is Player:
			(b as Player).in_water = true
	)
	_wet_area.body_exited.connect(func (b: Node) -> void:
		if b is Player:
			(b as Player).in_water = false
	)
	add_child(_wet_area)

func _nav_bake() -> void:
	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	var nmesh := NavigationMesh.new()
	nmesh.agent_radius = 0.35
	nmesh.agent_max_climb = 1.2
	nmesh.agent_max_slope = 45.0
	nav.navigation_mesh = nmesh
	add_child(nav)
	var floor := get_node_or_null("Floor")
	if floor:
		for c in floor.get_children():
			if c is MeshInstance3D:
				var dup: Node = c.duplicate()
				dup.name = String(c.name) + "_nav"
				nav.add_child(dup)
	nav.bake_navigation_mesh(true)

func _camp(at: Vector3) -> void:
	_coziness(at)
	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 9.0
	cyl.bottom_radius = 9.0
	cyl.height = 0.12
	pad.mesh = cyl
	pad.position = at + Vector3(0, 0.06, 0)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.45, 0.58, 0.30)
	pad.material_override = pmat
	pad.extra_cull_margin = 80.0
	add_child(pad)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(36, 36)
	ground.mesh = plane
	ground.position = at + Vector3(0, 0.02, 0)
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.albedo_color = Color(0.38, 0.58, 0.28)
	ground.material_override = gmat
	ground.extra_cull_margin = 80.0
	add_child(ground)
	var fire := Bonfire.new()
	fire.position = at + Vector3(-2.0, 0, 0)
	fire.position.y = surface_y(fire.position.x, fire.position.z)
	add_child(fire)
	_attach_prop(fire, &"bonfire")
	var bench := CraftStation.make(&"workbench")
	bench.position = at + Vector3(2.0, 0, 0)
	bench.position.y = surface_y(bench.position.x, bench.position.z)
	add_child(bench)
	_attach_prop(bench, &"workbench")
	var shed := Node3D.new()
	shed.name = "CampShed"
	shed.position = at + Vector3(0, 0, -3.5)
	shed.position.y = surface_y(shed.position.x, shed.position.z)
	add_child(shed)
	_attach_prop(shed, &"tent")

func _coziness(at: Vector3) -> void:
	var area := Area3D.new()
	area.name = "CampCozy"
	area.add_to_group("coziness")
	area.position = at
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(12, 4, 12)
	cs.shape = sh
	cs.position.y = 2
	area.add_child(cs)
	add_child(area)

func _crater(at: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Crater"
	area.add_to_group("crater")
	area.position = at
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 10.0
	cs.shape = sh
	area.add_child(cs)
	area.body_entered.connect(func (b: Node) -> void:
		if b is Player:
			World.discover_crater()
	)
	add_child(area)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 7.0
	cyl.bottom_radius = 8.0
	cyl.height = 0.5
	mesh.mesh = cyl
	mesh.position = at + Vector3(0, 0.15, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.24, 0.18)
	mesh.material_override = mat
	mesh.extra_cull_margin = 80.0
	add_child(mesh)
	var cpad := MeshInstance3D.new()
	var cplane := PlaneMesh.new()
	cplane.size = Vector2(28, 28)
	cpad.mesh = cplane
	cpad.position = at + Vector3(0, 0.02, 0)
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = Color(0.40, 0.28, 0.20)
	cpad.material_override = cmat
	cpad.extra_cull_margin = 80.0
	add_child(cpad)
	var crater_lv := clampi(_tier + 5, 1, 60)
	for i in 6:
		var ang := float(i) * TAU / 6.0
		var p := Vector3(at.x + cos(ang) * 9.0, 0.0, at.z + sin(ang) * 9.0)
		p.y = surface_y(p.x, p.z)
		harvest_count += _plant_at("Plant", "crater_node_%d" % i, p, &"herb_leaf", &"none", _climate, crater_lv, Color(0.45, 0.2, 0.35))

func _scatter(def: Dictionary, terrain: StringName, climate: String, tier: int, size: float) -> void:
	var clim: Dictionary = Data.world_climates.get(climate, {})
	var families: Array = clim.get("vegetation", ["BirchTree", "Bush", "Grass", "Rock", "Flowers"])
	var counts: Dictionary = {}
	if def.has("terrains") and def["terrains"] is Dictionary:
		counts = def["terrains"].get(str(terrain), {})
	var rng := RandomNumberGenerator.new()
	rng.seed = 17 if str(def.get("kind", "")) == "private" else 25
	_multimesh_family("Grass", int(counts.get("grass", 90 if climate == "temperate" else 60)), size, rng)
	_multimesh_family("Flowers", int(counts.get("flower", 20)), size, rng)
	for fam in families:
		var fs := str(fam)
		if fs.begins_with("Grass") or fs == "Flowers":
			continue
		var role := str(Data.nature_families.get(fs, {}).get("role", "node"))
		var n := 8
		match role:
			"tree":
				n = int(counts.get("tree", 14))
			"bush":
				n = int(counts.get("bush", 10))
			"prop":
				n = 5
			_:
				n = int(counts.get("rock", 8)) if fs.begins_with("Rock") else 6
		var fallback := &"wood_log"
		var tool := &"axe"
		var col := Color(0.35, 0.22, 0.1)
		if fs.begins_with("Rock"):
			fallback = &"stone"
			tool = &"pick"
			col = Color(0.5, 0.5, 0.48)
		elif fs.begins_with("Bush"):
			fallback = &"fibre_stalk"
			tool = &"knife"
			col = Color(0.2, 0.45, 0.18)
		elif fs == "Plant":
			fallback = &"herb_leaf"
			tool = &"none"
			col = Color(0.35, 0.55, 0.25)
			n = 8
		harvest_count += _plant_family(fs, role if role != "" else "node", n, fallback, tool, climate, tier, size, rng, col)

func _plant_family(family: String, role: String, n: int, fallback_id: StringName, tool: StringName, climate: String, tier: int, size: float, rng: RandomNumberGenerator, color: Color) -> int:
	var placed := 0
	var half := size * 0.42
	for i in n:
		var pos := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		if Vector2(pos.x, pos.z).length() < 25.0:
			continue
		if surface_y(pos.x, pos.z) < 0.05:
			continue
		pos.y = surface_y(pos.x, pos.z)
		placed += _plant_at(family, "%s_%d" % [role, i], pos, fallback_id, tool, climate, material_level(pos, tier), color)
	return placed

func _plant_at(family: String, role: String, pos: Vector3, fallback_id: StringName, tool: StringName, climate: String, level: int, color: Color) -> int:
	var models: PackedStringArray = _models(family)
	var harvest: Dictionary = _harvest(family)
	var yield_id := fallback_id
	var amin := 1
	var amax := 1
	if not harvest.is_empty():
		for k in harvest.keys():
			var cand := StringName(str(k))
			if Data.item(cand):
				yield_id = cand
				var pair: Variant = harvest[k]
				if pair is Array and pair.size() >= 2:
					amin = int(pair[0])
					amax = int(pair[1])
				break
	var tool_s := tool
	var tjson := _family_tool(family)
	if tjson != &"":
		tool_s = tjson
	if not Data.item(yield_id):
		yield_id = fallback_id
	var node: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	node.position = pos
	add_child(node)
	var attrs := {"climate": climate, "level": level}
	var role_s := str(Data.nature_families.get(family, {}).get("role", ""))
	var pool_max := _family_pool_max(family, role_s)
	node.setup(
		StringName(role),
		yield_id,
		amin,
		amax,
		attrs,
		tool_s,
		color,
		1.2,
		8.0,
		family,
		role_s.begins_with("tree"),
		pool_max
	)
	if models.size() > 0:
		var model := models[harvest_count % models.size()] if models.size() > 0 else ""
		if model == "":
			model = models[0]
		var path := "res://assets/nature/%s.glb" % model
		if ResourceLoader.exists(path):
			node.set_visual(path)
		else:
			print("[world] missing nature %s" % path)
	return 1

func _family_pool_max(family: String, role: String) -> int:
	var row: Dictionary = Data.nature_families.get(family, {})
	var from_manifest := int(row.get("pool", 0))
	if from_manifest > 0:
		return from_manifest
	# ASSUMPTION: when pool is missing, trees/rocks start at 30 units and bushes/plants at 12.
	if role.begins_with("tree") or role == "rock":
		return 30
	return 12

func _multimesh_family(family: String, n: int, size: float, rng: RandomNumberGenerator) -> void:
	var models := _models(family)
	if models.is_empty() or n <= 0:
		return
	var path := "res://assets/nature/%s.glb" % models[0]
	if not ResourceLoader.exists(path):
		print("[world] missing nature %s" % path)
		return
	var packed := load(path)
	var inst: Node = packed.instantiate() if packed is PackedScene else null
	var src_mesh: Mesh
	if inst:
		src_mesh = _first_mesh(inst)
		inst.queue_free()
	if src_mesh == null:
		return
	var xforms: Array[Transform3D] = []
	var half := size * 0.42
	for i in n:
		var ox := rng.randf_range(-half, half)
		var oz := rng.randf_range(-half, half)
		var y := surface_y(ox, oz)
		if y < 0.02:
			continue
		var t := Transform3D.IDENTITY
		t.origin = Vector3(ox, y, oz)
		t.basis = t.basis.rotated(Vector3.UP, rng.randf() * TAU)
		xforms.append(t)
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = src_mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 70.0
	add_child(mmi)
	mm_count += 1

func _creatures(def: Dictionary) -> void:
	var cap := Game.max_creatures_per_island
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for row in def.get("creatures", []):
		if not row is Dictionary:
			continue
		if creature_count >= cap:
			break
		var placed := Spawner.new()
		placed.species = StringName(str(row.get("species", "velociraptor")))
		placed.count = mini(int(row.get("count", 1)), cap - creature_count)
		placed.as_pack = bool(row.get("pack", true))
		var at: Array = row.get("at", [10, 0, 0])
		var want := _at(float(at[0]), float(at[2]))
		var fixed := _nearest_valid(want)
		if fixed.is_empty():
			spawn_rejected += 1
			print("[world] no dry land for %s at %s; skipped" % [placed.species, want])
			placed.queue_free()
			continue
		placed.position = fixed["pos"]
		add_child(placed)
		var made0 := placed.spawn_now()
		creature_count += made0.size()
	var rings: Dictionary = Data.world_rules.get("rings", {})
	var spawns: Variant = def.get("spawns", {})
	if spawns is Dictionary:
		for ring_id in spawns:
			var rows: Variant = spawns[ring_id]
			if not rows is Array:
				continue
			var span: Array = rings.get(str(ring_id), {}).get("radius_m", [40, 80])
			for row in rows:
				if not row is Dictionary:
					continue
				var groups := int(row.get("groups", 1))
				var chance := float(row.get("chance", 1.0))
				for _g in groups:
					if creature_count >= cap:
						return
					if chance < 1.0 and rng.randf() > chance:
						continue
					var r0 := float(span[0]) if span.size() > 0 else 40.0
					var r1 := float(span[1]) if span.size() > 1 else r0 + 20.0
					# rules.json rings are written for a 240 m land radius; a 160 m home island
					# has 64 m of land, so clamp the band to what exists instead of spawning at sea.
					var land := land_radius() - 4.0
					r1 = minf(r1, land)
					r0 = minf(r0, r1 - 8.0)
					if r1 <= r0 + 4.0:
						r1 = r0 + 8.0
					var pos := _ring_point(rng, r0, r1)
					if pos.is_empty():
						spawn_rejected += 1
						print("[world] no valid spawn for %s in ring %s (r %.0f-%.0f); skipped" % [
							row.get("species", "?"), ring_id, r0, r1])
						continue
					var sp := Spawner.new()
					sp.species = StringName(str(row.get("species", "velociraptor")))
					sp.count = mini(int(row.get("count", 1)), cap - creature_count)
					sp.as_pack = sp.count > 1
					sp.position = pos["pos"]
					add_child(sp)
					var made := sp.spawn_now()
					creature_count += made.size()

## Up to 40 draws in the band [r0, r1]; returns {"pos": Vector3} or {} when the band has no dry land.
func _ring_point(rng: RandomNumberGenerator, r0: float, r1: float) -> Dictionary:
	for _try in 40:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(r0 + 2.0, maxf(r0 + 2.0, r1 - 2.0))
		var pos := Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		pos.y = surface_y(pos.x, pos.z) + 0.3
		if spawn_ok(pos):
			return {"pos": pos}
	return {}

## Walk a fixed spawn point toward the island centre until it sits on dry land.
func _nearest_valid(want: Vector3) -> Dictionary:
	var p := want
	for _step in 12:
		p.y = surface_y(p.x, p.z) + 0.3
		if spawn_ok(p, false):
			return {"pos": p}
		p.x *= 0.9
		p.z *= 0.9
	return {}

func _models(family: String) -> PackedStringArray:
	var man: Dictionary = Data.nature_families.get(family, {})
	var out := PackedStringArray()
	for m in man.get("models", []):
		out.append(str(m))
	return out

func _harvest(family: String) -> Dictionary:
	var man: Dictionary = Data.nature_families.get(family, {})
	var h: Variant = man.get("harvest", {})
	return h if h is Dictionary else {}

func _family_tool(family: String) -> StringName:
	var man: Dictionary = Data.nature_families.get(family, {})
	var t: Variant = man.get("tool_class", null)
	if t == null:
		return &""
	var s := str(t)
	if s == "" or s == "<null>" or s == "null":
		return &"none"
	return StringName(s)

func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null

func _attach_prop(host: Node3D, kind: StringName) -> void:
	var buildings: Dictionary = Data.props_manifest.get("buildings", {})
	var row: Variant = buildings.get(str(kind), {})
	if not row is Dictionary:
		return
	var model := str(row.get("model", ""))
	if model == "":
		return
	var path := "res://assets/props/kenney/%s.glb" % model
	if not ResourceLoader.exists(path):
		return
	var inst: Node = load(path).instantiate()
	inst.name = "Prop"
	host.add_child(inst)

func _drive_day() -> void:
	if sun == null:
		return
	var tod := Game.time_of_day
	var from_noon := absf(tod - 0.5) * 2.0
	sun.rotation_degrees = Vector3(lerpf(-62.0, 12.0, from_noon), 30.0, 0.0)
	sun.light_energy = lerpf(1.45, 0.12, from_noon)
	if world_env and world_env.environment:
		var night := Game.phase_name() == &"night"
		world_env.environment.background_color = Color(0.10, 0.12, 0.20) if night else Color(0.55, 0.72, 0.90)
		world_env.environment.ambient_light_energy = 0.40 if night else 0.95
		world_env.environment.ambient_light_color = Color(0.55, 0.62, 0.85) if night else Color(0.92, 0.94, 0.88)

func _rain_layer() -> void:
	_rain_fx = GPUParticles3D.new()
	_rain_fx.emitting = false
	_rain_fx.amount = 400
	_rain_fx.lifetime = 0.9
	_rain_fx.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 20, 80))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 4.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -14, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18, 0.2, 18)
	mat.color = Color(0.65, 0.75, 0.9, 0.7)
	_rain_fx.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.03
	draw.height = 0.12
	_rain_fx.draw_pass_1 = draw
	add_child(_rain_fx)

func _weather(delta: float) -> void:
	_rain_cd -= delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if raining:
		_rain_left -= delta
		if p:
			p.vitals.add_fatigue(delta * 0.6, &"rain")
			p.statuses.apply(&"wet", null)
		if _rain_fx:
			if p:
				_rain_fx.global_position = p.global_position + Vector3(0, 10, 0)
			_rain_fx.emitting = true
		if _rain_left <= 0.0:
			raining = false
			_rain_cd = randf_range(50.0, 90.0)
			if _rain_fx:
				_rain_fx.emitting = false
	elif _rain_cd <= 0.0:
		raining = true
		_rain_left = 18.0
		print("[world] rain")
	if p:
		p.tick_climate_fatigue(delta, _climate)
