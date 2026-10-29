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
	rng.seed = int(def.get("seed", 17 if home else 25))
	# GROUND2D: the grass and flower families are painted ground cover now (scripts/world/ground_cover.gd):
	# dense camera-facing cards per 32 m cell, thinned with distance instead of switched off at a range,
	# never colliding. The counts stay data (ground_cover.json holds the density per m2).
	GroundCover.install(rt, climate, int(def.get("seed", 17 if home else 25)))
	PerfTrace.mark("scatter.cover")
	# BIOMEDRESS: the biome zones' own painted dressing (reeds at the water, termites on savanna,
	# basalt and crystals on volcanic, palms and ferns on tropical), from data/world/biome_dress.json.
	BiomeDress.install(rt, int(def.get("seed", 17 if home else 25)))
	PerfTrace.mark("scatter.dress")
	# Durango's islands are dense: every family keeps a floor even when the island data is sparse.
	# Denser islands (owner asked for resources everywhere): home floors up 3-4x, unstable up ~1.5x.
	# Owner wants islands that read full: counts come from area x props.json scatter.nodes_target. The
	# floors below stay as the old minimum for a tiny or a data-poor island.
	var target: Dictionary = _target_counts(rt, counts, home)
	var floors := {"tree": 24, "bush": 20, "rock": 12, "plant": 20, "wild_grass": 40}
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
				n = maxi(int(target.get("tree", 0)), int(floors["tree"])) / maxi(1, tree_families.size())
			"bush":
				n = maxi(int(target.get("bush", 0)), int(floors["bush"]))
				fallback = &"fibre_stalk"
				tool = &"knife"
				col = Color(0.2, 0.45, 0.18)
			"rock":
				n = maxi(int(target.get("rock", 0)), int(floors["rock"]))
				fallback = &"stone"
				tool = &"pick"
				col = Color(0.5, 0.5, 0.48)
			"prop":
				n = 0
			_:
				n = maxi(int(target.get("wild_grass", 0)), int(floors["wild_grass"])) if fs == "WildGrass" else maxi(int(target.get("plant", 0)), int(floors["plant"]))
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
	PerfTrace.mark("scatter.families")
	_scatter_special_tiles(rt, climate, tier, rng)
	PerfTrace.mark("scatter.special")
	# LANDMARKS M1: the named sites, their node groups, before the top-up so the top-up yields to them
	# (design doc section 3.3: "the scatter's top-up yields to landmarks").
	rt.landmark_stats = IslandLandmarks.build(rt, def)
	PerfTrace.mark("scatter.landmarks")
	_top_up(rt, total_target(counts, rt, home), climate, tier, size, rng)
	PerfTrace.mark("scatter.topup")
	PerfTrace.mark("scatter.commit")
	for node in rt._harvest_nodes.values():
		if is_instance_valid(node):
			node.refresh_batched_visual()
	_commit_tree_discs(rt)
	PerfTrace.mark("scatter.refresh")

## Plants a family in clumps of 3-6 (thickets and clearings, like the reference), on free
## dry tiles, avoiding the camp. Tree clumps near the shore become palms where the climate allows.
## The island's HarvestNode target (biome weights are acceptance probabilities, so the families above
## land short of it; the top-up fills the rest with small plant-role nodes).
static func total_target(counts: Dictionary, rt: IslandRuntime, home: bool) -> int:
	var t: Dictionary = _target_counts(rt, counts, home)
	var n := 0
	for k in t.keys():
		n += int(t[k])
	return n

## Small plant-role nodes on free dry ground until the island reaches its target. Keeps the total in
## the plan's band without touching the expensive tree and bush meshes.
static func _top_up(rt: IslandRuntime, target: int, climate: String, tier: int, size: float, rng: RandomNumberGenerator) -> void:
	if rt.harvest_count >= target:
		return
	var clim: Dictionary = Data.world_climates.get(climate, {})
	var families: Array = clim.get("vegetation", [])
	var pick: Array[String] = []
	for f in families:
		var fs := str(f)
		var role := str(Data.nature_families.get(fs, {}).get("role", ""))
		if role == "plant" or role == "bush":
			pick.append(fs)
	if pick.is_empty():
		pick.append("Plant")
	var half := size * 0.42
	var placed := 0
	var tries := 0
	var need := maxi(1, target - rt.harvest_count)
	while rt.harvest_count < target and tries < need * 60:
		tries += 1
		var ox := rng.randf_range(-half, half)
		var oz := rng.randf_range(-half, half)
		var hs := IslandTerrain.height_and_slope(rt, ox, oz)
		if hs.y > 30.0:
			continue
		var pos := Vector3(ox, hs.x, oz)
		if not rt.spawn_ok(pos, false) or rt.near_harbour(pos):
			continue
		var tile := BuildGrid.tile_of(pos)
		if rt._used_tiles.has(tile):
			continue
		if Vector2(ox - rt._camp_hint.x, oz - rt._camp_hint.z).length() < 9.0:
			continue
		var b := IslandProps.biome_of(rt, ox, oz)
		if IslandProps.biome_weight(b, "plant") <= 0.15:
			continue
		var fam := pick[placed % pick.size()]
		var role := str(Data.nature_families.get(fam, {}).get("role", "plant"))
		var fallback := &"herb_leaf"
		var tool := &"none"
		var col := Color(0.35, 0.55, 0.25)
		if role == "bush":
			fallback = &"fibre_stalk"
			tool = &"knife"
			col = Color(0.2, 0.45, 0.18)
		var made := plant_at(rt, fam, "topup_%d" % placed, pos, fallback, tool, climate, rt.material_level(pos, tier), col)
		placed += made
		rt.harvest_count += made

## Biome weighting thins a role in a biome (trees on savanna) but must not shrink the island's total.
## Scale the role's target by the inverse of its area-weighted mean weight, capped so a role that can
## only stand in one small zone stays a find instead of a carpet.
static func _role_scale(rt: IslandRuntime, channel: String) -> float:
	if rt._tile_span <= 0:
		return 1.0
	var sum := 0.0
	var n := 0
	for tz in range(0, rt._tile_span, 8):
		for tx in range(0, rt._tile_span, 8):
			var t := int(rt.tile_types[IslandTerrain.tile_idx(rt, tx, tz)])
			if t == IslandTerrain.TileType.DEEP or t == IslandTerrain.TileType.SHALLOW:
				continue
			var wx := -rt._size * 0.5 + float(tx) + 0.5
			var wz := -rt._size * 0.5 + float(tz) + 0.5
			sum += IslandProps.biome_weight(IslandProps.biome_of(rt, wx, wz), channel)
			n += 1
	if n <= 0:
		return 1.0
	var mean := sum / float(n)
	if mean <= 0.02:
		return 1.0
	return clampf(1.0 / mean, 1.0, 2.6)

## Per-island HarvestNode target split by role: land area (dry tiles) x scatter.nodes_target.per_ha,
## clamped to min/max, then role_share. Biome weights still decide where each family may stand
## (_role_weight / _biome_allows); the target keeps the total at the plan's 400-600 per island.
static func _target_counts(rt: IslandRuntime, counts: Dictionary, home: bool = false) -> Dictionary:
	var sc: Variant = IslandProps.scatter_row("nodes_target", {})
	var tgt: Dictionary = sc as Dictionary if sc is Dictionary else {}
	var land_m2 := 0.0
	if rt._tile_span > 0:
		for tz in range(0, rt._tile_span, 3):
			for tx in range(0, rt._tile_span, 3):
				var t := int(rt.tile_types[IslandTerrain.tile_idx(rt, tx, tz)])
				if t == IslandTerrain.TileType.DEEP or t == IslandTerrain.TileType.SHALLOW:
					continue
				land_m2 += 9.0
	var per_ha := float(tgt.get("per_ha", 300.0))
	var total := int(round(per_ha * land_m2 / 10000.0))
	# Plan P4: home 450-600 HarvestNodes, unstable 500-750. The max here keeps both inside the
	# 400-600 band this package was scoped to.
	var lo := int(tgt.get("min", 420))
	var hi := int(tgt.get("max", 600))
	total = clampi(total, lo, hi)
	var share: Variant = IslandProps.scatter_row("role_share", {})
	var shares: Dictionary = share as Dictionary if share is Dictionary else {}
	var out := {}
	var raw_total := 0.0
	for role in ["tree", "bush", "rock", "plant", "wild_grass"]:
		var s := float(shares.get(role, 0.2))
		var channel := "plant"
		if role == "tree":
			channel = "tree"
		elif role == "wild_grass":
			channel = "wild_grass"
		elif role != "bush" and role != "rock":
			channel = "plant"
		elif role == "bush":
			channel = "bush"
		elif role == "rock":
			channel = "rock"
		var v := float(total) * s * _role_scale(rt, channel)
		out[role] = v
		raw_total += v
	# The role scaling must not lift the island's total: renormalise back to the target.
	var norm := float(total) / maxf(1.0, raw_total)
	for role in out.keys():
		out[role] = int(round(float(out[role]) * norm))
	return out

## Biome weight for a role at a world point (props.json scatter.weights). 0 means "never here";
## a family whose role is not weighted (ore nodes, crater plants) falls back to 0.35 so it stays a find.
static func _role_weight(rt: IslandRuntime, role: String, x: float, z: float) -> float:
	var b := IslandProps.biome_of(rt, x, z)
	var channel := "plant"
	if role.begins_with("tree"):
		channel = "tree"
	elif role == "bush":
		channel = "bush"
	elif role == "rock":
		channel = "rock"
	elif role == "wild_grass":
		channel = "wild_grass"
	var w := IslandProps.biome_weight(b, channel)
	return w

## Where a family belongs: trees in forest/meadow, reeds and flax by water (wetland), ore and crystal
## nodes on rocky/canyon/basalt ground. Empty = anywhere the climate allows.
static func _family_biomes(family: String, role: String) -> PackedStringArray:
	var out := PackedStringArray()
	var row: Dictionary = Data.nature_families.get(family, {})
	var n := str(family).to_lower()
	if n.contains("reed") or n.contains("flax") or n.contains("lily") or n.contains("clay") or n.contains("mud"):
		out.append_array(["wetland", "beach"])
	elif n.contains("ore") or n.contains("crystal") or n.contains("obsidian") or n.contains("flint") or n.contains("copper") or n.contains("iron") or n.contains("silver") or n.contains("salt") or n.contains("sulphur") or n.contains("lava") or n.contains("sandstone") or n.contains("ochre") or n.contains("ice") or n.contains("peat"):
		out.append_array(["rocky", "canyon", "basalt"])
	elif role.begins_with("tree"):
		out.append_array(["forest", "meadow"])
	elif role == "rock":
		out.append_array(["rocky", "canyon", "basalt", "meadow"])
	elif n.contains("cactus") or n.contains("aloe") or n.contains("drygrass") or n.contains("acacia"):
		out.append_array(["savanna", "canyon"])
	return out

static func _plant_family(rt: IslandRuntime, family: String, role: String, n: int, fallback_id: StringName, tool: StringName, climate: String, tier: int, size: float, rng: RandomNumberGenerator, color: Color) -> int:
	var placed := 0
	# Scatter windows: the grid square minus a 15 m sea margin (the shaped island's dry bounding box
	# is ~0.90 x 0.73 of the square; spawn_ok rejects the water anyway, but a tighter window keeps
	# the rejection loop from burning its tries in the sea).
	var half := size * 0.5 - 15.0
	var tries := 0
	# Only climates whose biomes.json row allows palms (tropical, blue_tropical) grow them by the shore.
	var palms := family != "PalmTree" and role.begins_with("tree") and (BiomeMaterial.row(climate).get("palm_allowlist", []) as Array).has("PalmTree") and _models("PalmTree").size() > 0
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
		# Palms grow near the shore: the outer 20 % of the effective radius (not a circle).
		if palms and rt.rad_at(cx, cz) > rt.land_radius() * 0.78:
			fam = "PalmTree"
		# Biome gate: a weighted role is accepted with probability weight (so trees thin out on
		# savanna and rock piles on rocky ground), and a family with preferred biomes must be inside
		# one of them somewhere nearby (reeds and flax by water, ore on rock).
		var w := _role_weight(rt, role, cx, cz)
		if w <= 0.02:
			continue
		if w < 0.999 and rng.randf() > w:
			continue
		var prefer := _family_biomes(family, role)
		if prefer.size() > 0 and not (IslandProps.biome_of(rt, cx, cz) in prefer):
			if prefer.has("wetland"):
				# Water-loving families also take the MUD/WET/SHALLOW tiles next to their zone.
				if IslandTerrain.tile_type_at_world(rt, cx, cz) != IslandTerrain.TileType.MUD:
					continue
			else:
				continue
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
			if IslandClaims.is_grass(fam) and rt.is_claimed(tile):
				continue  # CLAIMS2: claimed land is bare (no grass, no wild grass tufts)
			# CLAIMPROPS: claimed land holds no scenery. A family with no usable gather option is a
			# prop; a gatherable one (tree, rock, bush, plant, a harvestable stump) is a resource and
			# stays on owned land.
			if not family_gatherable(fam) and rt.is_claimed(tile):
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
	if cards_enabled():
		# SWITCH2D: under resource_render "card" no resource draws as a 3D model. The family's painted
		# sprite when it has one, else its BAKED card (families without art yet borrow their role's).
		var vis: Dictionary = CardProp.visual_for(family, pos)
		if str(vis.get("kind", "")) != "":
			_attach_card_visual(rt, node, vis, role_s, family, pos)
		else:
			print("[world] %s has no painted sprite or baked card (drawn bare)" % family)
	elif models.size() > 0:
		var model := models[(rt.harvest_count + rt._used_tiles.size()) % models.size()]
		if model == "":
			model = models[0]
		var path := _nature_path(model)
		if ResourceLoader.exists(path):
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

## SWITCH2D: rules.json resource_render "card" (the default since the 2D switch), or --models for a
## lab run that draws the old 3D props. Under "card" every resource is a flat card.
static func cards_enabled() -> bool:
	if "--models" in OS.get_cmdline_user_args():
		return false
	return str(Data.world_rules.get("resource_render", "card")) == "card"

## One harvest node drawn as a swaying card, scaled to the family's usual height and opt-in to the
## see-through fade. `vis` is CardProp.visual_for(): a painted sprite from the owner's cut art, or a
## BAKED card. Tapping and gathering use the node's own collision and TapZone, untouched.
static func _attach_card_visual(rt: IslandRuntime, node: HarvestNode, vis: Dictionary, role: String, family: String, pos: Vector3) -> void:
	var card := CardProp.new()
	card.name = "Card_%s" % str(node.node_id)
	rt.add_child(card)
	card.position = pos
	var height := _target_height(rt, role, family)
	var ok := false
	if str(vis.get("kind", "")) == "painted":
		ok = card.setup_painted(vis.get("row", {}) as Dictionary, height)
	else:
		ok = card.setup(str(vis.get("card", "")), height)
	if not ok:
		card.queue_free()
		return
	# The family's depleted model (bush-berries-a -> bush-berries-a-empty) becomes its empty card.
	var variants: Dictionary = Data.nature_families.get(family, {}).get("depleted_models", {})
	var empty_card: CardProp = null
	var empty_id := ""
	for model_path in variants.keys():
		var cand := CardProp.card_for_model(str(variants[model_path]))
		if cand != "" and CardProp.baked(cand):
			empty_id = cand
			break
	if empty_id != "":
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
	rt._tree_discs.visibility_range_end = IsoCamera.cull_range(20.0)  # 60 m on the old 40 m camera
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

static func cover_within(rt: IslandRuntime, centre: Vector3, r: float) -> int:
	if rt == null:
		return 0
	var n := 0
	var r2 := r * r
	for p in rt.cover_points:
		if Vector2(p.x - centre.x, p.z - centre.z).length_squared() <= r2:
			n += 1
	return n

## Dry land in m2, from the tile map (every 3rd tile, like the resource target).
static func _land_area_m2(rt: IslandRuntime) -> float:
	if rt._tile_span <= 0:
		return 0.0
	var n := 0
	for tz in range(0, rt._tile_span, 3):
		for tx in range(0, rt._tile_span, 3):
			var t := int(rt.tile_types[IslandTerrain.tile_idx(rt, tx, tz)])
			if t != IslandTerrain.TileType.DEEP and t != IslandTerrain.TileType.SHALLOW:
				n += 1
	return float(n * 9)

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

## CLAIMPROPS: does this family offer anything a survivor can gather? A family whose whole harvest
## table names items the game does not have is scenery, whatever its role says.
static func family_gatherable(family: String) -> bool:
	var h := _harvest(family)
	if h.is_empty():
		return false
	for k in h.keys():
		if Data.item(StringName(str(k))) != null:
			return true
	return false

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
		var tile := BuildGrid.tile_of(pos)
		# CLAIMPROPS: claimed land holds no scenery (a family with no gather option is a prop).
		if not family_gatherable(family) and rt.is_claimed(tile):
			continue
		var uid := "%s_tile_%d" % [family, placed]
		rt.harvest_count += plant_at(rt, family, uid, pos, fallback_id, tool, climate, rt.material_level(pos, tier), tint)
		placed += 1
