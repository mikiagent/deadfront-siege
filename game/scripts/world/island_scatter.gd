class_name IslandScatter
extends RefCounted
## Island vegetation and resources: grass/flower multimeshes, harvest-node clumps, special
## tile resources and tree dirt discs. Static helpers over IslandRuntime state.

const FOLIAGE_SHADER: Shader = preload("res://scripts/world/foliage_sway.gdshader")

static func scatter(rt: IslandRuntime, def: Dictionary, terrain: StringName, climate: String, tier: int, size: float) -> void:
	var clim: Dictionary = Data.world_climates.get(climate, {})
	var families: Array = clim.get("vegetation", ["BirchTree", "Bush", "Grass", "Rock", "Flowers"])
	var counts: Dictionary = {}
	if def.has("terrains") and def["terrains"] is Dictionary:
		counts = def["terrains"].get(str(terrain), {})
	var home := str(def.get("kind", "")) == "private"
	var rng := RandomNumberGenerator.new()
	rng.seed = 17 if home else 25
	_multimesh_family(rt, "Grass", int(counts.get("grass", 260 if not home else 140)), size, rng)
	_multimesh_family(rt, "Flowers", int(counts.get("flower", 40 if not home else 24)), size, rng)
	# Durango's islands are dense: every family keeps a floor even when the island data is sparse.
	# Denser islands (owner asked for resources everywhere): home floors up 3-4x, unstable up ~1.5x.
	var floors := {"tree": 40 if home else 64, "bush": 36 if home else 44, "rock": 20 if home else 26, "plant": 24 if home else 24, "wild_grass": 48 if home else 60}
	var tree_families: Array[String] = []
	for fam in families:
		var fs := str(fam)
		if fs.begins_with("Grass") or fs == "Flowers":
			continue
		var role := str(Data.nature_families.get(fs, {}).get("role", "node"))
		if role.begins_with("tree"):
			tree_families.append(fs)
	for fam in families:
		var fs := str(fam)
		if fs.begins_with("Grass") or fs == "Flowers":
			continue
		var role := str(Data.nature_families.get(fs, {}).get("role", "node"))
		var n := 0
		var fallback := &"wood_log"
		var tool := &"axe"
		var col := Color(0.35, 0.22, 0.1)
		match role:
			"tree", "tree_dead":
				n = maxi(int(counts.get("tree", 0)), int(floors["tree"])) / maxi(1, tree_families.size())
			"bush":
				n = maxi(int(counts.get("bush", 0)), int(floors["bush"]))
				fallback = &"fibre_stalk"
				tool = &"knife"
				col = Color(0.2, 0.45, 0.18)
			"rock":
				n = maxi(int(counts.get("rock", 0)), int(floors["rock"]))
				fallback = &"stone"
				tool = &"pick"
				col = Color(0.5, 0.5, 0.48)
			"prop":
				n = 0
			_:
				n = int(floors["wild_grass"]) if fs == "WildGrass" else int(floors["plant"])
				fallback = &"dry_grass" if fs == "WildGrass" else &"herb_leaf"
				tool = &"none"
				col = Color(0.55, 0.62, 0.3) if fs == "WildGrass" else Color(0.35, 0.55, 0.25)
		# Generated resource families declare their own per-island count so a mineral or crater
		# plant stays a find, not a carpet.
		var fixed_count := int(Data.nature_families.get(fs, {}).get("count", 0))
		if fixed_count > 0:
			n = maxi(2, fixed_count / 2) if home else fixed_count
		if n <= 0:
			continue
		rt.harvest_count += _plant_family(rt, fs, role, n, fallback, tool, climate, tier, size, rng, col)
	_scatter_special_tiles(rt, climate, tier, rng)
	for b in rt._batches:
		b.commit()
	for node in rt._harvest_nodes.values():
		if is_instance_valid(node):
			node.refresh_batched_visual()
	_commit_tree_discs(rt)

## Plants a family in clumps of 3-6 (thickets and clearings, like the reference), on free
## dry tiles, avoiding the camp. Tree clumps near the shore become palms where the climate allows.
static func _plant_family(rt: IslandRuntime, family: String, role: String, n: int, fallback_id: StringName, tool: StringName, climate: String, tier: int, size: float, rng: RandomNumberGenerator, color: Color) -> int:
	var placed := 0
	var half := size * 0.40
	var tries := 0
	var palms := family != "PalmTree" and role.begins_with("tree") and not (climate in ["tundra", "volcanic"]) and _models("PalmTree").size() > 0
	while placed < n and tries < n * 30:
		tries += 1
		var cx := rng.randf_range(-half, half)
		var cz := rng.randf_range(-half, half)
		var centre := Vector3(cx, rt.surface_y(cx, cz), cz)
		if not rt.spawn_ok(centre, false):
			continue
		if Vector2(cx - rt._camp_hint.x, cz - rt._camp_hint.z).length() < 9.0:
			continue
		var fam := family
		if palms and Vector2(cx, cz).length() > rt.land_radius() * 0.70:
			fam = "PalmTree"
		var clump := rng.randi_range(3, 6) if (role.begins_with("tree") or role == "bush") else rng.randi_range(1, 3)
		var spread := 3.2 if role.begins_with("tree") else 2.4
		for k in clump:
			if placed >= n:
				break
			var ox := cx + rng.randf_range(-spread, spread)
			var oz := cz + rng.randf_range(-spread, spread)
			var pos := Vector3(ox, rt.surface_y(ox, oz), oz)
			if not rt.spawn_ok(pos, false) or rt.near_harbour(pos):
				continue
			var tile := BuildGrid.tile_of(pos)
			if rt._used_tiles.has(tile):
				continue
			if Data.nature_families.get(fam, {}).has("depleted_models"):
				var crowded := false
				var centre_pos := BuildGrid.tile_centre(tile, rt)
				for other in rt._harvest_nodes.values():
					if is_instance_valid(other) and Data.nature_families.get(other.family, {}).has("depleted_models") and Vector2(other.position.x - centre_pos.x, other.position.z - centre_pos.z).length() < 3.8:
						crowded = true
						break
				if crowded:
					continue
			placed += plant_at(rt, fam, "%s_%s_%d" % [fam.to_lower(), role, placed], pos, fallback_id, tool, climate, rt.material_level(pos, tier), color)
	return placed

static func plant_at(rt: IslandRuntime, family: String, role: String, pos: Vector3, fallback_id: StringName, tool: StringName, climate: String, level: int, color: Color) -> int:
	var tile := BuildGrid.tile_of(pos)
	pos = BuildGrid.tile_centre(tile, rt)
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
	rt.add_child(node)
	var attrs := {"climate": climate, "level": level}
	var role_s := str(Data.nature_families.get(family, {}).get("role", ""))
	var pool_max := _family_pool_max(family, role_s)
	var regen_s := _family_regen_seconds(family, role_s)
	node.setup(
		StringName(role),
		yield_id,
		amin,
		amax,
		attrs,
		tool_s,
		color,
		1.2,
		regen_s,
		family,
		role_s.begins_with("tree"),
		pool_max
	)
	node.depleted_tile.connect(rt._on_tile_bare)
	node.regrown_tile.connect(rt._on_tile_regrown)
	rt._node_tiles[str(node.node_id)] = {"tile": tile, "base": IslandTerrain.tile_type_at_world(rt, pos.x, pos.z)}
	rt._harvest_nodes[str(node.node_id)] = node
	rt._used_tiles[tile] = true
	if models.size() > 0:
		var model := models[(rt.harvest_count + rt._used_tiles.size()) % models.size()]
		if model == "":
			model = models[0]
		var path := _nature_path(model)
		if ResourceLoader.exists(path):
			var card_id := "" if not cards_enabled() else CardProp.card_for_model(path)
			if card_id != "" and CardProp.baked(card_id):
				_attach_card(rt, node, card_id, path, role_s, family, pos)
			else:
				_attach_batched(rt, node, path, role_s, family, pos)
		else:
			print("[world] missing nature %s" % path)
	return 1

## Reference look: palms 8-11 m, trees 7-10 m, bushes 1.5-2.2 m, rocks knee-high.
static func _target_height(rt: IslandRuntime, role: String, family: String) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(family) + rt._used_tiles.size() * 7919
	var span: Variant = Data.nature_families.get(family, {}).get("height", null)
	if span is Array and (span as Array).size() >= 2:
		return r.randf_range(float(span[0]), float(span[1]))
	if family == "PalmTree":
		return r.randf_range(8.0, 11.0)
	if role.begins_with("tree"):
		return r.randf_range(7.0, 10.0)
	if role == "bush":
		return r.randf_range(1.5, 2.2)
	if role == "rock":
		return r.randf_range(0.7, 1.3)
	if family == "tree_stump":
		return 0.7
	return r.randf_range(0.6, 1.0)

static func _attach_batched(rt: IslandRuntime, node: HarvestNode, path: String, role: String, family: String, pos: Vector3) -> void:
	var batch := VegBatch.get_for(rt, path)
	if batch == null:
		node.set_visual(path)
		return
	if not rt._batches.has(batch):
		rt._batches.append(batch)
	var h := VegBatch.mesh_height(path)
	var scale := _target_height(rt, role, family) / h
	var yaw := float(hash(str(pos)) % 628) / 100.0
	var basis := Basis.IDENTITY.rotated(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	var xf := Transform3D(basis, pos)
	var idx := batch.add(xf)
	# Tall props can hide the survivor at the iso pitch: the part on the sight line dithers away.
	if scale * h >= Occlusion.TALL_M:
		Occlusion.make_occludable(batch, Occlusion.BETWEEN)
	var variants: Dictionary = Data.nature_families.get(family, {}).get("depleted_models", {})
	var empty_path := str(variants.get(path, ""))
	var empty_batch: VegBatch = VegBatch.get_for(rt, empty_path) if empty_path != "" else null
	var empty_idx := -1
	if empty_batch:
		if not rt._batches.has(empty_batch):
			rt._batches.append(empty_batch)
		empty_idx = empty_batch.add(xf)
	node.set_batched_visual(batch, idx, empty_batch, empty_idx)
	if role.begins_with("tree") or family == "tree_stump":
		rt._tree_disc_xforms.append(Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.08, 0)))

## CARD2D: rules.json resource_render "card", or --cards for a lab run. Default "model" is today's
## look, so nothing changes until the owner approves the trial.
static func cards_enabled() -> bool:
	if "--cards" in OS.get_cmdline_user_args():
		return true
	return str(Data.world_rules.get("resource_render", "model")) == "card"

## One harvest node drawn as a baked swaying card, scaled to the family's usual height and opt-in to
## the see-through fade. Tapping and gathering use the node's own collision and TapZone, untouched.
static func _attach_card(rt: IslandRuntime, node: HarvestNode, card_id: String, model_path: String, role: String, family: String, pos: Vector3) -> void:
	var card := CardProp.new()
	card.name = "Card_%s" % str(node.node_id)
	rt.add_child(card)
	card.position = pos
	var height := _target_height(rt, role, family)
	if not card.setup(card_id, height):
		card.queue_free()
		return
	# The family's depleted model (bush-berries-a -> bush-berries-a-empty) becomes its empty card.
	var variants: Dictionary = Data.nature_families.get(family, {}).get("depleted_models", {})
	var empty_card: CardProp = null
	var empty_model := str(variants.get(model_path, ""))
	var empty_id := CardProp.card_for_model(empty_model) if empty_model != "" else ""
	if empty_id != "" and CardProp.baked(empty_id):
		empty_card = CardProp.new()
		empty_card.name = "Empty_%s" % str(node.node_id)
		rt.add_child(empty_card)
		empty_card.position = pos
		if empty_card.setup(empty_id, height):
			empty_card.visible = false
		else:
			empty_card.queue_free()
			empty_card = null
	node.set_card_visual(card, empty_card)
	# A card tall enough to hide the survivor fades like a batched tree does (W2-OCCLUDE): its
	# material includes the same dither body, driven per instance.
	if height >= Occlusion.TALL_M:
		Occlusion.make_card_occludable(card, Occlusion.BETWEEN)
	if role.begins_with("tree") or family == "tree_stump":
		rt._tree_disc_xforms.append(Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.08, 0)))

static func _commit_tree_discs(rt: IslandRuntime) -> void:
	if rt._tree_disc_xforms.is_empty():
		return
	var PV := load("res://scripts/world/prop_visuals.gd") as GDScript
	rt._tree_discs = MultiMeshInstance3D.new()
	rt._tree_discs.name = "TreeDiscs"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = PV.make_disc_mesh(0.9)
	mm.instance_count = rt._tree_disc_xforms.size()
	for i in rt._tree_disc_xforms.size():
		mm.set_instance_transform(i, rt._tree_disc_xforms[i])
	rt._tree_discs.multimesh = mm
	rt._tree_discs.material_override = PV.disc_material(0.9, Color(0.66, 0.52, 0.38))
	rt._tree_discs.visibility_range_end = 60.0
	rt._tree_discs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rt.add_child(rt._tree_discs)

static func _family_pool_max(family: String, role: String) -> int:
	var row: Dictionary = Data.nature_families.get(family, {})
	var from_manifest := int(row.get("pool", 0))
	if from_manifest > 0:
		return from_manifest
	# ASSUMPTION: when pool is missing, trees/rocks start at 30 units and bushes/plants at 12.
	if role.begins_with("tree") or role == "rock":
		return 30
	return 12

static func _family_regen_seconds(family: String, role: String) -> float:
	if family == "mud" or family == "clay":
		# ASSUMPTION: fast regrowth for river-bed resources.
		return 60.0
	if family == "berry_bush" or role == "bush":
		# ASSUMPTION: bush-type nodes regrow in 90s.
		return 90.0
	if role.begins_with("tree") or family == "tree_stump":
		# ASSUMPTION: tree resources regrow in 240s.
		return 240.0
	return 120.0

static func _multimesh_family(rt: IslandRuntime, family: String, n: int, size: float, rng: RandomNumberGenerator) -> void:
	var models := _models(family)
	if models.is_empty() or n <= 0:
		return
	var path := _nature_path(models[0])
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
		var y := rt.surface_y(ox, oz)
		if not rt.spawn_ok(Vector3(ox, y, oz), false):
			continue
		if (family == "Grass" or family == "Flowers") and IslandTerrain.slope_deg(rt, ox, oz) > 35.0:
			continue
		var t := Transform3D.IDENTITY
		t.origin = Vector3(ox, y, oz)
		t.basis = _basis_from_normal(IslandTerrain.normal_at(rt, ox, oz), rng.randf() * TAU)
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
	mmi.visibility_range_end = 48.0
	if family == "Grass" or family == "Flowers":
		if rt._foliage_mat == null:
			rt._foliage_mat = ShaderMaterial.new()
			rt._foliage_mat.shader = FOLIAGE_SHADER
		mmi.material_override = rt._foliage_mat
	rt.add_child(mmi)
	rt.mm_count += 1

static func _basis_from_normal(up: Vector3, yaw: float) -> Basis:
	var n := up.normalized()
	var t := n.cross(Vector3.FORWARD)
	if t.length_squared() < 0.001:
		t = n.cross(Vector3.RIGHT)
	t = t.normalized()
	var b := t.cross(n).normalized()
	var basis := Basis(t, n, b)
	return basis.rotated(n, yaw)

## Manifest models are Quaternius names under res://assets/nature/, or full res:// paths
## (the generated Meshy trees, minerals and plants live in their own folders).
static func _nature_path(model: String) -> String:
	if model.begins_with("res://"):
		return model
	return "res://assets/nature/%s.glb" % model

static func _models(family: String) -> PackedStringArray:
	var man: Dictionary = Data.nature_families.get(family, {})
	var out := PackedStringArray()
	for m in man.get("models", []):
		out.append(str(m))
	return out

static func _harvest(family: String) -> Dictionary:
	var man: Dictionary = Data.nature_families.get(family, {})
	var h: Variant = man.get("harvest", {})
	return h if h is Dictionary else {}

static func _family_tool(family: String) -> StringName:
	var man: Dictionary = Data.nature_families.get(family, {})
	var t: Variant = man.get("tool_class", null)
	if t == null:
		return &""
	var s := str(t)
	if s == "" or s == "<null>" or s == "null":
		return &"none"
	return StringName(s)

static func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null

static func _scatter_special_tiles(rt: IslandRuntime, climate: String, tier: int, rng: RandomNumberGenerator) -> void:
	_spawn_special_family(rt, "mud", 3, [IslandTerrain.TileType.MUD, IslandTerrain.TileType.SAND], -0.2, 0.55, &"mud", &"none", climate, tier, Color(0.35, 0.27, 0.20), rng)
	_spawn_special_family(rt, "clay", 2, [IslandTerrain.TileType.MUD, IslandTerrain.TileType.DIRT], -0.1, 0.9, &"clay", &"pick", climate, tier, Color(0.44, 0.30, 0.22), rng)
	_spawn_special_family(rt, "berry_bush", 3, [IslandTerrain.TileType.GRASS, IslandTerrain.TileType.DRY], 0.25, 6.0, &"berry", &"none", climate, tier, Color(0.58, 0.24, 0.24), rng)
	_spawn_special_family(rt, "tree_stump", 1, [IslandTerrain.TileType.GRASS, IslandTerrain.TileType.DRY], 0.25, 6.5, &"wood_log", &"axe", climate, tier, Color(0.41, 0.27, 0.19), rng)

static func _spawn_special_family(rt: IslandRuntime, family: String, count: int, tile_kinds: Array, min_h: float, max_h: float, fallback_id: StringName, tool: StringName, climate: String, tier: int, tint: Color, rng: RandomNumberGenerator) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 120:
		tries += 1
		var tx := rng.randi_range(0, rt._tile_span - 1)
		var tz := rng.randi_range(0, rt._tile_span - 1)
		var idx := IslandTerrain.tile_idx(rt, tx, tz)
		var tile_t := int(rt.tile_types[idx])
		if not tile_kinds.has(tile_t):
			continue
		var wx := -rt._size * 0.5 + float(tx) + 0.5
		var wz := -rt._size * 0.5 + float(tz) + 0.5
		var h := rt.surface_y(wx, wz)
		if h < min_h or h > max_h:
			continue
		var pos := Vector3(wx, h, wz)
		if family != "mud" and family != "clay" and not rt.spawn_ok(pos, false):
			continue
		if rt.near_harbour(pos):
			continue
		var uid := "%s_tile_%d" % [family, placed]
		rt.harvest_count += plant_at(rt, family, uid, pos, fallback_id, tool, climate, rt.material_level(pos, tier), tint)
		placed += 1
