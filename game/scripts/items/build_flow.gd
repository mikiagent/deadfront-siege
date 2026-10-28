class_name BuildFlow
extends RefCounted
## The Craft/Build blueprint pipeline (owner's spec 30 phases 2-3): prerequisite details, placement
## validation through the existing claim and grid systems (never a second claimant), creating one
## persistent ConstructionSite, and the atomic completion that consumes the escrow once, computes the
## structure level (spec 30 §9) and swaps the site for exactly one finished CraftStation.

## Why `bp_id` cannot be placed at `cell`/`rot` now, in the player's words ("" = it can).
## Blueprint prerequisites first, then the established BuildGrid (claims, water, slope, overlap) and
## the 8 m reach, so the panel and the ghost never disagree.
static func place_reason(player: Player, bp_id: StringName, cell: Vector2i, rot: int, grid: BuildGrid = null) -> String:
	var bp := Blueprints.of(bp_id)
	if bp.is_empty():
		return "Unknown blueprint"
	if player == null or player.skills == null:
		return "No survivor"
	var unmet := Blueprints.unmet(player, bp)
	if not unmet.is_empty():
		return unmet[0]
	if grid == null:
		grid = _grid()
	if grid == null:
		return "Can't build here"
	return BuildPlacer.reason_text(grid.can_place(_grid_kind(bp_id), cell, rot))

## True when placing now would work (the details panel's "currently placeable" line).
static func can_place(player: Player, bp_id: StringName, cell: Vector2i, rot: int, grid: BuildGrid = null) -> bool:
	return place_reason(player, bp_id, cell, rot, grid) == ""

## Create the site (never a working station). Null when any check refuses: the refusals are the same
## ones `place_reason` reports. The caller (BuildUI / the build lab) confirms the placement.
static func place_site(player: Player, bp_id: StringName, cell: Vector2i, rot: int, grid: BuildGrid = null) -> ConstructionSite:
	var why := place_reason(player, bp_id, cell, rot, grid)
	if why != "":
		print("[buildflow] place refused %s at (%d,%d): %s" % [bp_id, cell.x, cell.y, why])
		if player:
			player.notice("Can't build: %s" % why)
		return null
	if grid == null:
		grid = _grid()
	var runtime := World.runtime
	if runtime == null or grid == null:
		return null
	var site := ConstructionSite.new()
	site.setup(bp_id, World.player_name if World.player_name != "" else "Survivor")
	site.bind_bag(player.inventory if player else null)
	# The site reserves the blueprint's own footprint: a working Workbench can never share it and a
	# finished one can never be placed on the site.
	site.grid_kind = _grid_kind(bp_id)
	runtime.add_child(site)
	site.global_transform = grid.placement_transform(site.grid_kind, cell, rot)
	site.set_grid_pose(cell, rot)
	grid.occupy(site, grid.cells_for(site.grid_kind, cell, rot))
	print("[buildflow] %s site %s at (%d,%d) rot=%d" % [bp_id, site.site_id, cell.x, cell.y, posmod(rot, 4) * 90])
	return site

## The grid kind a blueprint's site reserves: a real kind with the blueprint's footprint (the station
## kind), so overlap runs both ways. A rotation swaps the footprint the same way for both.
static func _grid_kind(bp_id: StringName) -> StringName:
	var cfg: Dictionary = Blueprints.of(bp_id).get("station", {})
	return StringName(str(cfg.get("kind", "workbench")))

static func _grid() -> BuildGrid:
	if World.runtime == null:
		return null
	var g: Variant = World.runtime.get("build_grid")
	return g as BuildGrid if g is BuildGrid else null

## Finish the site atomically (spec 30 §8): consume the escrow exactly once, work out the level,
## remove the site and add exactly one tagged, leveled CraftStation of the blueprint's station kind.
## Refuses (and changes nothing) unless every slot is full and the work is done.
static func complete(player: Player, site: Node) -> CraftStation:
	if site == null or not is_instance_valid(site) or not (site is ConstructionSite):
		return null
	var cs := site as ConstructionSite
	if not cs.ready_to_finish():
		if player:
			player.notice("The %s still needs materials and work." % str(cs.bp().get("display_name", "site")))
		return null
	var grid := _grid()
	var runtime := World.runtime
	if runtime == null or grid == null:
		return null
	var bp := cs.bp()
	var cell := cs.build_cell
	var rot := cs.build_rot
	# Compute before consuming: the levels come from the exact instances about to be spent.
	var level := Blueprints.result_level(bp, cs.contributing_levels(), player.skills.level_of("construction") if player and player.skills else 1)
	var station_cfg: Dictionary = bp.get("station", {})
	var kind := StringName(str(station_cfg.get("kind", "workbench")))
	# Consume the escrow once; the instances are not copied anywhere else.
	var spent := cs.escrow()
	for col in cs.slot_items:
		(col as Array).clear()
	cs.deposited_by.clear()
	var station := CraftStation.make(kind)
	station.station_level = level
	station.station_tags = _names(station_cfg.get("tags", ["workbench"]))
	station.build_cell = cell
	station.build_rot = rot
	runtime.add_child(station)
	grid.release(cs)
	station.global_transform = grid.placement_transform(kind, cell, rot)
	station.set_grid_pose(cell, rot)
	grid.occupy(station, grid.cells_for(kind, cell, rot))
	cs.queue_free()
	print("[buildflow] %s complete: %s lv %d from %s" % [cs.site_id, kind, level, spent.map(func (s: ItemStack) -> int: return s.level)])
	# XP once, on completion only (never per work tick, cancel or reopen). XPECON: the blueprint's own
	# reward and World.note_building's first/repeat/spam award (rules.json xp) go in one grant.
	World.note_building(kind, station.global_position, player, int(bp.get("xp", 25.0)))
	return station

static func _names(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array:
		for e: Variant in v:
			out.append(StringName(str(e)))
	return out

## Every blueprint as a menu row: {id, name, category, where (the first category it appears under),
## blocked (the first unmet prerequisite or ""), placeable_hint}.
static func menu_rows(player: Player) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bp in Blueprints.list():
		var unmet := Blueprints.unmet(player, bp)
		out.append({
			"id": str(bp.get("id", "")),
			"name": str(bp.get("display_name", bp.get("id", "?"))),
			"category": Blueprints.category_of(bp),
			"where": str((bp.get("categories", []) as Array)[1]) if (bp.get("categories", []) as Array).size() > 1 else Blueprints.category_of(bp),
			"blocked": unmet[0] if not unmet.is_empty() else "",
			"unmet": unmet,
		})
	return out
