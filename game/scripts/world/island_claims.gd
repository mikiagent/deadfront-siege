class_name IslandClaims
extends RefCounted
## Land claims (M8d Part B), who owns them (spec 18) and the dashed boundary mesh that marks them.
##
## CLAIMS2: land grows on a predictable grid. Every plot is PLOT x PLOT cells on a grid anchored at
## the base plot (the camp plot here, the landing camp on an unstable island). A new plot is always
## one of the free grid cells that shares a full edge with land already held and passes
## block_reason - the candidates - so the CLAIM press can only ever stake the cell the survivor
## stands in, and the panel can draw all of them as ghosts before anything is spent. Saved plots
## that predate the grid (older saves) load exactly as saved; only new plots snap.
## Claimed land is bare: grass families are never scattered on it, and a plot clears the grass
## already inside it when it is staked (see clear_grass).

const SELF_ID := "self"  ## owner id of this survivor's own claims
const PLOT := 14  ## cells along one plot's side (the 14x14 plot the game has always staked)
const NO_CELL := Vector2i(-2147483648, -2147483648)  ## "the tile is in no candidate cell"
## ASSUMPTION: the owner asked for "no grass" on claimed land; these families are grass. FibreTuft,
## reeds, trees, rocks and bushes are resources the survivor plants around, so they stay.
const GRASS := ["Grass", "Grass_Short", "WildGrass", "DryGrassTuft"]
## ASSUMPTION: no doc gives a plot cap. The owner asked for one; these numbers are the starting
## point (rules.json "claims") and are meant to be tuned: 2 plots at Pioneer Level 0 (the base plot
## plus PRD 13.1's free expansion), +1 every 10 levels, never more than 9 at home; 2 staked plots
## on an unstable island on top of its landing camp.
const DEFAULT_LIMITS := {"home_base_plots": 2, "plots_per_levels": 10, "home_max_plots": 9, "unstable_max_plots": 2}

## Home: the camp plot (14x14 tiles) is claimed at creation plus whatever was saved.
## Unstable: whatever the player staked this visit. Buildings only go on claimed tiles.
static func setup(rt: IslandRuntime, def: Dictionary) -> void:
	rt.claims.clear()
	var camp_tile := BuildGrid.tile_of(rt._camp_pos)
	var saved: Array = World.claims_for_current()
	if str(def.get("kind", "")) == "private":
		var base := Rect2i(camp_tile - Vector2i(7, 7), Vector2i(PLOT, PLOT))
		rt.claims.append(base)
		for r in saved:
			if r is Array and (r as Array).size() >= 4:
				rt.claims.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		if saved.is_empty():
			World.home_claims = [[base.position.x, base.position.y, base.size.x, base.size.y]]
	else:
		# ASSUMPTION: the camp landing spot is always buildable on unstable islands (tents, pens).
		rt.claims.append(Rect2i(camp_tile - Vector2i(7, 7), Vector2i(PLOT, PLOT)))
		for r in saved:
			if r is Array and (r as Array).size() >= 4:
				rt.claims.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	_rebuild_claim_mesh(rt)

static func is_claimed(rt: IslandRuntime, tile: Vector2i) -> bool:
	for r in rt.claims:
		if r.has_point(tile):
			return true
	return false

static func is_grass(family: String) -> bool:
	return GRASS.has(family)

# ---------------------------------------------------------------- limits (rules.json "claims")

static func limits() -> Dictionary:
	var row: Variant = Data.world_rules.get("claims", {})
	var out := DEFAULT_LIMITS.duplicate()
	if row is Dictionary:
		for k in (row as Dictionary).keys():
			out[k] = row[k]
	return out

## Plots this survivor may hold on this island. Home grows with the Pioneer Level (PRD line 183);
## an unstable island always gives a landing camp plot, so its cap counts the plots staked on top.
static func limit(rt: IslandRuntime) -> int:
	var l := limits()
	if World.is_home():
		var per := maxi(1, int(l.get("plots_per_levels", 10)))
		var base := int(l.get("home_base_plots", 2))
		var grown := base + int(floor(float(World.pioneer_level) / float(per)))
		return mini(int(l.get("home_max_plots", 2)), grown)
	return 1 + int(l.get("unstable_max_plots", 2))

static func used(rt: IslandRuntime) -> int:
	return rt.claims.size()

static func at_limit(rt: IslandRuntime) -> bool:
	return used(rt) >= limit(rt)

## The notice a CLAIM press gets at the cap; "" below it.
static func limit_reason(rt: IslandRuntime) -> String:
	if not at_limit(rt):
		return ""
	return "Land limit reached (%d/%d). Raise your Pioneer Level to claim more." % [used(rt), limit(rt)]

# ---------------------------------------------------------------- the plot grid

## Anchor of the plot grid: the first plot, the base plot the island was created with.
static func anchor(rt: IslandRuntime) -> Vector2i:
	if rt.claims.is_empty():
		return BuildGrid.tile_of(rt._camp_pos) - Vector2i(7, 7)
	var base: Rect2i = rt.claims[0]
	return base.position

static func cell_rect(rt: IslandRuntime, cell: Vector2i) -> Rect2i:
	return Rect2i(anchor(rt) + cell * PLOT, Vector2i(PLOT, PLOT))

## The grid cell a tile falls in (floor division, so it works either side of the anchor).
static func cell_of(rt: IslandRuntime, tile: Vector2i) -> Vector2i:
	var d := tile - anchor(rt)
	return Vector2i(floori(float(d.x) / float(PLOT)), floori(float(d.y) / float(PLOT)))

## True when `rect` is exactly one grid cell (a plot made by this build, not an older save's).
static func on_grid(rt: IslandRuntime, rect: Rect2i) -> bool:
	if rect.size != Vector2i(PLOT, PLOT):
		return false
	return cell_rect(rt, cell_of(rt, rect.position)) == rect

## Cells held on the grid (saved off-grid plots hold land but seed no new cells).
static func held_cells(rt: IslandRuntime) -> Dictionary:
	var out := {}
	for r in rt.claims:
		var rect: Rect2i = r
		if on_grid(rt, rect):
			out[cell_of(rt, rect.position)] = true
	return out

## The free cells orthogonally next to held land that pass block_reason, in a stable order
## (top row first, then left to right). These are the only cells a CLAIM can stake.
static func candidates(rt: IslandRuntime) -> Array[Vector2i]:
	var held := held_cells(rt)
	var seen := {}
	var out: Array[Vector2i] = []
	for c: Vector2i in held.keys():
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if held.has(n) or seen.has(n):
				continue
			seen[n] = true
			var rect := cell_rect(rt, n)
			if _own_overlap(rt, rect):
				continue
			if block_reason(rt, rect.get_center(), PLOT) != "":
				continue
			out.append(n)
	out.sort_custom(func (a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out

## The candidate cell `tile` stands in (NO_CELL when it stands in none).
static func candidate_of(rt: IslandRuntime, tile: Vector2i) -> Vector2i:
	if rt.claims.is_empty():
		return NO_CELL
	var cell := cell_of(rt, tile)
	return cell if candidates(rt).has(cell) else NO_CELL

static func _own_overlap(rt: IslandRuntime, rect: Rect2i) -> bool:
	for r in rt.claims:
		if (r as Rect2i).intersects(rect):
			return true
	return false

# ---------------------------------------------------------------- claiming

## Stake a plot. Grid claim: the candidate cell the tile stands in is staked, exactly, so the
## neighbour plots always line up (no more plot centred on wherever the survivor happened to stand).
## A tile outside every candidate cell claims nothing. Returns false when it is refused.
static func claim_at(rt: IslandRuntime, tile: Vector2i, size: int = PLOT) -> bool:
	var rect: Rect2i
	if rt.claims.is_empty():
		# The first plot ever on this island is free-standing (an island with no camp plot).
		if block_reason(rt, tile, size) != "":
			return false
		rect = plot_at(tile, size)
	else:
		var cell := candidate_of(rt, tile)
		if cell == NO_CELL:
			return false
		rect = cell_rect(rt, cell)
		if block_reason(rt, rect.get_center(), PLOT) != "":
			return false
	rt.claims.append(rect)
	var row := [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if World.is_home():
		World.home_claims.append(row)
	else:
		World.unstable_claims.append(row)
	clear_grass(rt, rect)
	_rebuild_claim_mesh(rt)
	rt.claims_changed.emit(rect)
	print("[world] claimed %dx%d at (%d,%d)" % [rect.size.x, rect.size.y, rect.position.x, rect.position.y])
	return true

## The 14x14 plot centred on `tile` (a free-standing first claim; not on the base grid).
static func plot_at(tile: Vector2i, size: int = PLOT) -> Rect2i:
	return Rect2i(tile - Vector2i(size / 2, size / 2), Vector2i(size, size))

## The plot the CLAIM press would stake at `tile`: the candidate grid cell it stands in, the centred
## plot while the island holds no land yet, Rect2i() when it stands in no candidate cell.
static func plot_for(rt: IslandRuntime, tile: Vector2i) -> Rect2i:
	if rt.claims.is_empty():
		return plot_at(tile, PLOT)
	var cell := candidate_of(rt, tile)
	return Rect2i() if cell == NO_CELL else cell_rect(rt, cell)

## Why a claim at `tile` would be refused ("" when it would be staked): not dry land, or the plot
## would take a tile another player holds. One answer for the confirm panel and claim_at.
static func block_reason(rt: IslandRuntime, tile: Vector2i, size: int = PLOT) -> String:
	if not rt.spawn_ok(BuildGrid.tile_centre(tile, rt), false):
		return "not dry land"
	var rect := plot_at(tile, size)
	for row in rt.other_claims:
		if rect.intersects(row["rect"]):
			return "another survivor's land"
	return ""

## Why a claim at `tile` would not be an expansion of this survivor's land ("" when it would):
## with land held, a claim is one grid cell orthogonally next to it (PRD 13.1 "orthogonal only, no
## diagonal"), so the tile must stand inside one of the candidates.
static func expand_reason(rt: IslandRuntime, tile: Vector2i, size: int = PLOT) -> String:
	if rt.claims.is_empty():
		return block_reason(rt, tile, size)
	if is_claimed(rt, tile):
		return "that plot overlaps land you already hold"
	if candidate_of(rt, tile) == NO_CELL:
		return "stand inside a dashed plot beside your land (share a full edge, no diagonal, no hop)"
	return ""

# ---------------------------------------------------------------- grass on claimed land

## Remove the grass inside `rect`: grass harvest nodes (WildGrass, DryGrassTuft) and the grass
## decor instances the scatter made (Grass, Grass_Short). Everything else stays.
static func clear_grass(rt: IslandRuntime, rect: Rect2i) -> int:
	var removed := 0
	var keys := []
	for key in rt._harvest_nodes.keys():
		var node: Node = rt._harvest_nodes[key]
		if is_instance_valid(node) and is_grass(str(node.get("family"))) and rect.has_point(BuildGrid.tile_of((node as Node3D).global_position)):
			keys.append(key)
	for key in keys:
		var node: Node = rt._harvest_nodes[key]
		rt._harvest_nodes.erase(key)
		rt._node_tiles.erase(key)
		var tile := BuildGrid.tile_of((node as Node3D).global_position)
		if rt._used_tiles.has(tile) and rt._used_tiles[tile] == true:
			rt._used_tiles.erase(tile)
		var batch: Variant = node.get("_batch")
		if batch is VegBatch:
			(batch as VegBatch).set_shown(int(node.get("_batch_idx")), false)
		node.queue_free()
		removed += 1
	removed += clear_grass_instances(rt, rect)
	return removed

## Drop the grass decor instances inside `rect` from their multimeshes; returns how many went.
static func clear_grass_instances(rt: IslandRuntime, rect: Rect2i) -> int:
	var removed := 0
	for mmi in rt.grass_mm:
		if not is_instance_valid(mmi) or mmi.multimesh == null:
			continue
		var mm := mmi.multimesh
		var keep: Array[Transform3D] = []
		for i in mm.instance_count:
			var xf := mm.get_instance_transform(i)
			if rect.has_point(BuildGrid.tile_of(xf.origin)):
				removed += 1
			else:
				keep.append(xf)
		if keep.size() == mm.instance_count:
			continue
		if keep.is_empty():
			rt.grass_mm.erase(mmi)
			mmi.queue_free()
			continue
		var fresh := MultiMesh.new()
		fresh.transform_format = MultiMesh.TRANSFORM_3D
		fresh.mesh = mm.mesh
		fresh.instance_count = keep.size()
		for i in keep.size():
			fresh.set_instance_transform(i, keep[i])
		mmi.multimesh = fresh
	return removed

## Grass still inside `plots`: harvest nodes plus decor instances (the lab and the tests use it).
static func grass_in(rt: IslandRuntime, plots: Array) -> int:
	var n := 0
	for node in rt._harvest_nodes.values():
		if is_instance_valid(node) and is_grass(str(node.get("family"))):
			var tile := BuildGrid.tile_of((node as Node3D).global_position)
			for r in plots:
				if (r as Rect2i).has_point(tile):
					n += 1
					break
	for mmi in rt.grass_mm:
		if not is_instance_valid(mmi) or mmi.multimesh == null:
			continue
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var tile := BuildGrid.tile_of(mm.get_instance_transform(i).origin)
			for r in plots:
				if (r as Rect2i).has_point(tile):
					n += 1
					break
	return n

## Non-grass harvest nodes inside `plots` (must survive a claim).
static func other_nodes_in(rt: IslandRuntime, plots: Array) -> int:
	var n := 0
	for node in rt._harvest_nodes.values():
		if not is_instance_valid(node) or is_grass(str(node.get("family"))):
			continue
		var tile := BuildGrid.tile_of((node as Node3D).global_position)
		for r in plots:
			if (r as Rect2i).has_point(tile):
				n += 1
				break
	return n

# ---------------------------------------------------------------- ownership

## Whose land the tile is: this survivor's claims first ({"id": SELF_ID, "name", "own": true}), then
## other players' ({"id", "name"} as the server sent them), {} when nobody holds it. The one place
## claim ownership is read (the domain banner, the claim outline); online only set_others' rows change.
static func owner_at(rt: IslandRuntime, tile: Vector2i) -> Dictionary:
	if is_claimed(rt, tile):
		var me := PlayerRegistry.local()
		return {"id": SELF_ID, "name": me.display_name() if me else World.player_name, "own": true}
	for row in rt.other_claims:
		if (row["rect"] as Rect2i).has_point(tile):
			return row["owner"]
	return {}

## Replaces the other players' claims on this island with `rows` ({"rect": [x, z, w, d], "owner":
## {"id", "name"}}), skipping malformed rows, cutting each rect to the island, and redraws the
## outline. Offline nothing calls it; online the server's claim rows land here.
static func set_others(rt: IslandRuntime, rows: Array) -> void:
	rt.other_claims.clear()
	var island := Rect2i(-Vector2i.ONE * int(rt._size * 0.5), Vector2i.ONE * rt._tile_span)
	for row in rows:
		var r: Variant = row.get("rect") if row is Dictionary else null
		var who: Variant = row.get("owner") if row is Dictionary else null
		if not (r is Array and (r as Array).size() >= 4 and who is Dictionary and str(who.get("id", "")) not in ["", SELF_ID]):
			continue
		var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		if rect.size.x > 0 and rect.size.y > 0:
			rect = rect.intersection(island)
		if rect.has_area():
			rt.other_claims.append({"rect": rect, "owner": {"id": str(who["id"]), "name": str(who.get("name", "Survivor"))}})
	_rebuild_claim_mesh(rt)

static func _rebuild_claim_mesh(rt: IslandRuntime) -> void:
	if rt._claim_mesh == null:
		rt._claim_mesh = ClaimOutline.new()
		rt.add_child(rt._claim_mesh)
	(rt._claim_mesh as ClaimOutline).rebuild(rt)
