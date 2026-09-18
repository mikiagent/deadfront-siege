extends Node3D
## Generates a private or unstable island: floor, nav, harvest, harbour, camp, optional crater.

var harvest_count: int = 0
var creature_count: int = 0
var harbour
var cargo
var cargo_basket

func build(def: Dictionary, terrain: StringName) -> void:
	var size := float(def.get("size_m", 160))
	var climate := str(def.get("climate", "grassland"))
	var tier := int(def.get("tier", 10))
	_env()
	_sun()
	_floor(size, climate)
	_nav_and_floor(size)
	var harbour_a: Array = def.get("harbour", [0, 0, 12])
	var camp_a: Array = def.get("camp", [0, 0, 6])
	harbour = (load("res://scripts/world/harbour.gd") as GDScript).new()
	harbour.position = Vector3(float(harbour_a[0]), 0, float(harbour_a[2]))
	add_child(harbour)
	_coziness(Vector3(float(camp_a[0]), 0, float(camp_a[2])))
	cargo = (load("res://scripts/world/cargo_warp.gd") as GDScript).new()
	cargo.position = Vector3(float(camp_a[0]) + 3.0, 0, float(camp_a[2]))
	add_child(cargo)
	if str(def.get("kind", "")) == "private":
		var PB := load("res://scripts/world/placed_building.gd") as GDScript
		cargo_basket = PB.make(&"basket")
		cargo_basket.is_cargo = true
		cargo_basket.storage = World.cargo_home
		cargo_basket.position = Vector3(float(harbour_a[0]) + 3.0, 0, float(harbour_a[2]))
		add_child(cargo_basket)
		var fire := Bonfire.new()
		fire.position = Vector3(float(camp_a[0]) - 2.0, 0, float(camp_a[2]))
		add_child(fire)
		var bench := CraftStation.make(&"workbench")
		bench.position = Vector3(float(camp_a[0]) + 2.0, 0, float(camp_a[2]))
		add_child(bench)
	_scatter(def, terrain, climate, tier, size)
	_creatures(def)
	var crater_v: Variant = def.get("crater", null)
	if crater_v is Array:
		_crater(Vector3(float(crater_v[0]), 0, float(crater_v[2])))
	print("[world] island %s nodes=%d creatures=%d" % [def.get("id", ""), harvest_count, creature_count])

func _env() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.52, 0.7, 0.88)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.85, 0.9)
	e.ambient_light_energy = 0.65
	e.ssao_enabled = false
	e.ssr_enabled = false
	e.glow_enabled = false
	env.environment = e
	add_child(env)

func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)

func _nav_and_floor(size: float) -> void:
	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	var nmesh := NavigationMesh.new()
	nmesh.agent_radius = 0.35
	nmesh.agent_max_climb = 0.5
	nav.navigation_mesh = nmesh
	add_child(nav)
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var fmesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, 1, size)
	fmesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.55, 0.28)
	fmesh.material_override = mat
	floor.add_child(fmesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size, 1, size)
	cs.shape = sh
	floor.add_child(cs)
	floor.position.y = -0.5
	nav.add_child(floor)
	nav.bake_navigation_mesh(false)

func _floor(_size: float, _climate: String) -> void:
	pass

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
	sh.radius = 8.0
	cs.shape = sh
	area.add_child(cs)
	area.body_entered.connect(func (b: Node) -> void:
		if b is Player:
			World.discover_crater()
	)
	add_child(area)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 6.0
	cyl.bottom_radius = 7.0
	cyl.height = 0.4
	mesh.mesh = cyl
	mesh.position = at + Vector3(0, 0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.22, 0.18)
	mesh.material_override = mat
	add_child(mesh)

func _scatter(def: Dictionary, terrain: StringName, climate: String, tier: int, size: float) -> void:
	var counts: Dictionary = {}
	if def.has("terrains"):
		counts = def["terrains"].get(str(terrain), def["terrains"].get("meadow", {}))
	else:
		counts = {"tree": 14, "bush": 12, "grass": 60, "rock": 8, "flower": 6}
	var rng := RandomNumberGenerator.new()
	rng.seed = 17 if str(def.get("kind", "")) == "private" else 25
	_multimesh_grass(int(counts.get("grass", 40)), size, rng)
	harvest_count += _plant_family("BirchTree", "tree", int(counts.get("tree", 8)), &"wood_log", &"axe", climate, tier, size, rng, Color(0.35, 0.22, 0.1))
	harvest_count += _plant_family("Bush", "bush", int(counts.get("bush", 8)), &"fibre_stalk", &"knife", climate, tier, size, rng, Color(0.2, 0.45, 0.18))
	harvest_count += _plant_family("Rock", "rock", int(counts.get("rock", 6)), &"stone", &"pick", climate, tier, size, rng, Color(0.5, 0.5, 0.48))
	harvest_count += _plant_family("Flowers", "flower", int(counts.get("flower", 4)), &"herb_leaf", &"none", climate, tier, size, rng, Color(0.7, 0.35, 0.55))

func _plant_family(family: String, role: String, n: int, fallback_id: StringName, tool: StringName, climate: String, tier: int, size: float, rng: RandomNumberGenerator, color: Color) -> int:
	var models: PackedStringArray = _models(family)
	var harvest: Dictionary = _harvest(family)
	var yield_id := fallback_id
	var amin := 1
	var amax := 1
	if not harvest.is_empty():
		var first_key: String = str(harvest.keys()[0])
		yield_id = StringName(first_key)
		var pair: Variant = harvest[first_key]
		if pair is Array and pair.size() >= 2:
			amin = int(pair[0])
			amax = int(pair[1])
	var tool_s := tool
	var tjson := _family_tool(family)
	if tjson != &"":
		tool_s = tjson
	if not Data.item(yield_id):
		yield_id = fallback_id
	var placed := 0
	var half := size * 0.38
	for i in n:
		var pos := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		if pos.length() < 8.0:
			continue
		var node: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
		node.position = pos
		add_child(node)
		var attrs := {"climate": climate, "level": tier}
		node.setup(StringName("%s_%d" % [role, i]), yield_id, amin, amax, attrs, tool_s, color)
		if models.size() > 0:
			var model := models[i % models.size()]
			node.set_visual("res://assets/nature/%s.glb" % model)
		placed += 1
	return placed

func _multimesh_grass(n: int, size: float, rng: RandomNumberGenerator) -> void:
	var path := "res://assets/nature/Grass.glb"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path)
	var inst: Node = packed.instantiate() if packed is PackedScene else null
	var src_mesh: Mesh
	if inst:
		src_mesh = _first_mesh(inst)
		inst.queue_free()
	if src_mesh == null:
		var cap := CapsuleMesh.new()
		cap.radius = 0.08
		cap.height = 0.4
		src_mesh = cap
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = src_mesh
	mm.instance_count = n
	var half := size * 0.42
	for i in n:
		var t := Transform3D.IDENTITY
		t.origin = Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		t.basis = t.basis.rotated(Vector3.UP, rng.randf() * TAU)
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 70.0
	add_child(mmi)

func _creatures(def: Dictionary) -> void:
	var cap := Game.max_creatures_per_island
	for row in def.get("creatures", []):
		if not row is Dictionary:
			continue
		if creature_count >= cap:
			break
		var sp := Spawner.new()
		sp.species = StringName(str(row.get("species", "velociraptor")))
		sp.count = mini(int(row.get("count", 1)), cap - creature_count)
		sp.as_pack = bool(row.get("pack", true))
		var at: Array = row.get("at", [10, 0, 0])
		sp.position = Vector3(float(at[0]), 0, float(at[2]))
		add_child(sp)
		var made := sp.spawn_now()
		creature_count += made.size()

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
