class_name IslandClaims
extends RefCounted
## Land claims (M8d Part B), who owns them (spec 18) and the dashed boundary mesh that marks them.
##
## CLAIMS2 / spec 29: a domain is a SET OF CELLS on a grid anchored at the island origin. One cell is
## DomainRules.cell_tiles() x cell_tiles() world tiles (4 by default, spec 29 section 3). The record is
## spec 29 section 3's: domain_id, kind, island_id, owner, cells, max_cells, status. A domain grows by
## contiguous expansion only (edge-adjacent cells, spec 29 section 2/4) and stops at the cap, which the
## Tamed Island takes from Pioneer rank milestones (spec 29 section 4, historical/provisional).
## `rt.claims` stays the list of tile rects the rest of the game reads (one rect per owned cell), so
## build placement, the claim outline and the banner keep working unchanged.
## Claimed land is bare: grass families are never scattered on it and a new cell drops the grass
## already inside it (the owner: "claimed land shouldn't have the grass").

const SELF_ID := "self"  ## owner id of this survivor's own claims
const KIND_TAMED := "tamed_island"
## ASSUMPTION: the owner asked for "no grass" on claimed land; these families are grass. FibreTuft,
## reeds, trees, rocks and bushes are resources the survivor gathers, so they stay.
const GRASS := ["Grass", "Grass_Short", "WildGrass", "DryGrassTuft"]
## Cells either side of the domain/centre a preview window shows (a phone has to see the grid).
const PREVIEW_RADIUS := 4
const NO_CELL := Vector2i(-2147483648, -2147483648)

# ---------------------------------------------------------------- the cell grid (spec 29 section 3)

static func cell_tiles() -> int:
	return DomainRules.cell_tiles()

## The tile rect of one cell. Cells are anchored at the island origin (tile 0,0 is a cell corner).
static func cell_rect(_rt: IslandRuntime, cell: Vector2i) -> Rect2i:
	var n := cell_tiles()
	return Rect2i(cell * n, Vector2i(n, n))

## The cell a tile falls in (floor division: it also works west/north of the origin).
static func cell_of(_rt: IslandRuntime, tile: Vector2i) -> Vector2i:
	var n := cell_tiles()
	return Vector2i(floori(float(tile.x) / float(n)), floori(float(tile.y) / float(n)))

## Cells covering a tile rect (a legacy 14x14 plot is not cell-aligned: every cell it touches counts).
static func cells_covering(_rt: IslandRuntime, rect: Rect2i) -> Array[Vector2i]:
	var n := cell_tiles()
	var out: Array[Vector2i] = []
	if not rect.has_area():
		return out
	var lo := Vector2i(floori(float(rect.position.x) / float(n)), floori(float(rect.position.y) / float(n)))
	var hi := Vector2i(floori(float(rect.end.x - 1) / float(n)), floori(float(rect.end.y - 1) / float(n)))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			out.append(Vector2i(x, y))
	return out

# ---------------------------------------------------------------- the domain record

static func domain(rt: IslandRuntime) -> Dictionary:
	return rt.domain

static func has_domain(rt: IslandRuntime) -> bool:
	return not rt.domain.is_empty() and not (rt.domain.get("cells", []) as Array).is_empty()

static func owned_cells(rt: IslandRuntime) -> Dictionary:
	var out := {}
	for c in rt.domain.get("cells", []):
		if c is Vector2i:
			out[c] = true
	return out

## Cells the domain already stands on for CONTIGUITY: its own cells plus the cells the camp's 14x14
## landing claim occupies. A domain is declared next to the camp and then grows from itself.
static func occupied_cells(rt: IslandRuntime) -> Dictionary:
	var out := owned_cells(rt)
	if rt.camp_claim.has_area():
		for c in cells_covering(rt, rt.camp_claim):
			out[c] = true
	return out

## Cells the domain holds.
static func used(rt: IslandRuntime) -> int:
	return owned_cells(rt).size()

## The cell cap: the Tamed Island's Pioneer-rank milestone (spec 29 section 4). A record may carry a
## higher floor (a migrated save that already held more cells than the cap): the land is never taken
## away, the floor just means no new cells until a milestone passes it.
static func cap(rt: IslandRuntime) -> int:
	return maxi(DomainRules.cap(), int(rt.domain.get("max_cells", 0)))

static func at_cap(rt: IslandRuntime) -> bool:
	return used(rt) >= cap(rt)

## The record's cap follows the survivor's Pioneer rank. Called when the island builds and when the
## Domain screen opens; never drops a cell.
## Keep the record's max_cells at the live cap when a domain is claimed or raised. The stored value
## is a floor only: cap() takes whichever of the rank milestone and the record is higher, so a rank
## change never has to rewrite the record (a save re-saved stays field-for-field the same).
static func sync_cap(rt: IslandRuntime) -> void:
	if not has_domain(rt):
		return
	rt.domain["max_cells"] = maxi(int(rt.domain.get("max_cells", 0)), DomainRules.cap())

static func is_claimed(rt: IslandRuntime, tile: Vector2i) -> bool:
	for r in rt.claims:
		if r.has_point(tile):
			return true
	return false

## Spec 29 section 3's fields for saving (cells as [[x, z], ...], JSON-safe).
static func to_save(rt: IslandRuntime) -> Dictionary:
	if rt.domain.is_empty():
		return {}
	var out: Dictionary = rt.domain.duplicate(true)
	var cells: Array = []
	var list: Array = (rt.domain.get("cells", []) as Array).duplicate()
	list.sort_custom(func (a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	for c in list:
		if c is Vector2i:
			cells.append([c.x, c.y])
	out["cells"] = cells
	return out

## A saved record as the runtime keeps it ({} when it is unusable).
static func from_save(row: Variant) -> Dictionary:
	if not row is Dictionary:
		return {}
	var d: Dictionary = (row as Dictionary).duplicate(true)
	var cells: Array = []
	for c in d.get("cells", []):
		if c is Array and (c as Array).size() >= 2 and (c[0] is int or c[0] is float) and (c[1] is int or c[1] is float):
			cells.append(Vector2i(int(c[0]), int(c[1])))
	d["cells"] = cells
	d["max_cells"] = maxi(1, int(d.get("max_cells", DomainRules.cap())))
	d["kind"] = str(d.get("kind", KIND_TAMED))
	d["status"] = str(d.get("status", "active"))
	d["domain_id"] = str(d.get("domain_id", "domain_%s" % str(World.island_id)))
	d["island_id"] = str(d.get("island_id", str(World.island_id)))
	d["owner"] = str(d.get("owner", SELF_ID))
	return d

static func make_record(rt: IslandRuntime, cells: Array, kind: String = KIND_TAMED) -> Dictionary:
	var sorted: Array = cells.duplicate()
	sorted.sort_custom(func (a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	return {
		"domain_id": "domain_%s" % str(World.island_id),
		"kind": kind,
		"island_id": str(World.island_id),
		"owner": SELF_ID,
		"owner_clan_id": "",
		"cells": sorted,
		"max_cells": DomainRules.cap(),
		"status": "active",
		"renewal_deadline": null,
		"permissions_profile_id": "owner_only",  # ASSUMPTION: no visitor permissions yet (spec 29 section 6 is later)
	}

## Refresh rt.claims (the tile rects the rest of the game reads) from the record's cells. The camp's
## own land stays first (it is buildable but is not a domain cell: spec 29's cap counts plots/cells,
## and a fresh island's camp claim must not eat one of the 13).
static func _rebuild_claim_rects(rt: IslandRuntime) -> void:
	var cells: Array = (rt.domain.get("cells", []) as Array).duplicate()
	cells.sort_custom(func (a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	rt.claims.clear()
	if rt.camp_claim.has_area():
		rt.claims.append(rt.camp_claim)
	for c in cells:
		rt.claims.append(cell_rect(rt, c))
	_publish(rt)

## Keep World's saved copy of this island's domain in step (the CLAIM path and the Domain screen
## both end here, so a save taken right after a claim has it).
static func _publish(rt: IslandRuntime) -> void:
	if World == null:
		return
	var row := to_save(rt)
	if World.is_home():
		World.home_domain = row
	else:
		World.away_domain = row

# ---------------------------------------------------------------- setup, migration (spec 29 section 4)

## Home: the starting domain (the camp's cells) or the saved/migrated one. Unstable: the landing
## camp's cell. An old save's 14x14 rects become the cells that cover them; every placed building's
## footprint is covered too, so nothing built is orphaned.
static func setup(rt: IslandRuntime, def: Dictionary) -> void:
	rt.domain = {}
	var saved := World.domain_for_current()
	# The world's copy is rewritten from this island's record below (or cleared when it has none), so a
	# domain never leaks from the island the survivor left to the one arriving.
	if World.is_home():
		World.home_domain = {}
	else:
		World.away_domain = {}
	var camp_tile := BuildGrid.tile_of(rt._camp_pos)
	# The camp's landing claim stays buildable land but is not a domain cell (spec 29's 13 is free
	# choice, and a fresh island starts with Declare). ASSUMPTION: it is a 4x4-cell block (16x16 tiles
	# at 4) snapped to the cell grid instead of M8d's 14x14, so a declared cell always shares a full
	# edge with it (a 14x14 block cuts the grid in half and leaves a gap). The block holds the whole
	# old 14x14 plot, so every building an old save placed on the camp land stays on claimed land
	# (t_save's v0 basket at (4,8)).
	var lo := cell_of(rt, camp_tile) - Vector2i(2, 2)
	var camp_cells := 4
	rt.camp_claim = Rect2i(lo * cell_tiles(), Vector2i.ONE * cell_tiles() * camp_cells)
	rt.claims.clear()
	if not saved.is_empty():
		rt.domain = from_save(saved)
		if rt.domain.is_empty() or (rt.domain.get("cells", []) as Array).is_empty():
			rt.domain = {}
	var legacy: Array = World.claims_for_current()
	if rt.domain.is_empty() and not legacy.is_empty():
		# An old save's first row was always the camp plot (setup wrote it first, and it is the
		# 14x14 the camp landing used): it stays the camp's land, not a domain cell.
		var rows: Array = legacy
		if str(def.get("kind", "")) == "private" and rows[0] is Array and (rows[0] as Array).size() >= 4:
			var base: Array = rows[0]
			rt.camp_claim = Rect2i(int(base[0]), int(base[1]), int(base[2]), int(base[3]))
			rows = rows.slice(1)
		rt.domain = _migrate_legacy(rt, rows)
		if not rt.domain.is_empty():
			print("[world] domain migrated from %d legacy plot rect(s): %d cell(s)" % [legacy.size(), used(rt)])
	# ASSUMPTION: only a Tamed Island (the private home) has a domain. An unstable island is a
	# temporary visit; its camp claim is buildable land, not a domain (spec 29's other territory types
	# are later phases), so no record is made or saved there until the survivor claims cells.
	sync_cap(rt)
	_rebuild_claim_rects(rt)
	# Home only, and only once a domain exists: the legacy rect list stays a mirror of the claimed
	# land (an older build, and t_claimfix, still read it): the camp plot first, then every domain
	# cell. A fresh island writes nothing, so a save with no declared domain keeps exactly the old
	# shape and re-saves field-for-field. The away island's rows are left as loaded (its cells save
	# in the domain record).
	if World.is_home() and has_domain(rt):
		World.home_claims = _claim_rows(rt)
	_clear_grass_cells(rt, rt.domain.get("cells", []))
	_rebuild_claim_mesh(rt)

## An old save's plot rects (plus every placed building's footprint) as a domain record. The cap may
## be exceeded: cells are never removed (the task's rule for migrated saves).
static func _migrate_legacy(rt: IslandRuntime, rows: Array) -> Dictionary:
	var seen := {}
	for row in rows:
		if row is Array and (row as Array).size() >= 4:
			var rect := Rect2i(int(row[0]), int(row[1]), int(row[2]), int(row[3]))
			for c in cells_covering(rt, rect):
				seen[c] = true
	if seen.is_empty():
		return {}  # no staked land in the save: nothing to migrate (the camp plot alone is no domain)
	var buildings: Array = World._home_buildings_cache if World.is_home() else []
	for b in buildings:
		if not b is Dictionary:
			continue
		var cell_v: Variant = (b as Dictionary).get("cell")
		if not (cell_v is Array and (cell_v as Array).size() >= 2):
			continue
		var kind := StringName(str(b.get("kind", "")))
		var fp := rt.build_grid.footprint(kind) if kind != &"" else Vector2i.ONE
		var rect := Rect2i(Vector2i(int(cell_v[0]), int(cell_v[1])), fp)
		for c in cells_covering(rt, rect):
			seen[c] = true
	var cells: Array = seen.keys()
	cells.sort_custom(func (a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	var rec := make_record(rt, cells)
	# A migrated save may hold more cells than the cap: the floor keeps every cell and allows no new
	# ones until a documented milestone passes it (the cap may be exceeded, never shrunk).
	rec["max_cells"] = maxi(DomainRules.cap(), cells.size())
	return rec

# ---------------------------------------------------------------- validity and expansion (spec 29 sections 2-4)

## The island's tile bounds (spec 29: a cell outside the island is invalid).
static func _island_rect(rt: IslandRuntime) -> Rect2i:
	var half := int(rt._size * 0.5)
	return Rect2i(-half, -half, int(rt._tile_span), int(rt._tile_span))

## Why a cell cannot be claimed at all ("" when the land is fine): "outside_the_island", "terrain"
## (water or a cliff), "ownership" (another survivor's land). The shape of the answer the preview
## colours and the refusals quote.
static func cell_block_reason(rt: IslandRuntime, cell: Vector2i) -> String:
	var rect := cell_rect(rt, cell)
	if not _island_rect(rt).encloses(rect):
		return "outside_the_island"
	var centre := rect.position + rect.size / 2
	var wet := 0
	for t in [centre, rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]:
		var tile: Vector2i = t
		if not rt.spawn_ok(BuildGrid.tile_centre(tile, rt), false):
			wet += 1
	if wet >= 3:  # ASSUMPTION: most of the cell under water (or off the land radius) is water
		return "terrain"
	var at := BuildGrid.tile_centre(centre, rt)
	if IslandTerrain.slope_deg(rt, at.x, at.z) > 40.0:  # ASSUMPTION: a 40 deg face is a cliff
		return "terrain"
	for row in rt.other_claims:
		if (row["rect"] as Rect2i).intersects(rect):
			return "ownership"
	return ""

## Edge-adjacent to a cell in `held` (orthogonal only: spec 29 section 2, no diagonal, no hop).
static func adjacent_to(cell: Vector2i, held: Dictionary) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if held.has(cell + d):
			return true
	return false

## The cells a domain may take now (spec 29 sections 2 and 4): edge-adjacent to the domain (no
## diagonal, no hop) and free. With no domain yet (Declare) any valid cell is eligible; `centre` with
## a radius >= 0 limits Declare's list to the preview window around it.
static func eligible_cells(rt: IslandRuntime, centre: Vector2i = NO_CELL, radius: int = -1) -> Array[Vector2i]:
	var held := occupied_cells(rt)
	var own := owned_cells(rt)
	var out: Array[Vector2i] = []
	if own.is_empty():
		var box := Rect2i(centre - Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1)) if radius >= 0 and centre != NO_CELL else _island_cells(rt)
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				var c := Vector2i(x, y)
				if not held.has(c) and cell_block_reason(rt, c) == "":
					out.append(c)
	else:
		# Growth is from the land the survivor holds: the domain's cells and the camp's own plot (a
		# domain is declared at the camp, spec 29 section 4: the home island's landing).
		var tried := {}
		for c: Vector2i in held.keys():
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if held.has(n) or tried.has(n):
					continue
				if radius >= 0 and centre != NO_CELL and (absi(n.x - centre.x) > radius or absi(n.y - centre.y) > radius):
					continue
				tried[n] = true
				if cell_block_reason(rt, n) == "":
					out.append(n)
	out.sort_custom(func (a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	return out

## Every cell of the island's tile bounds (the Declare list before a window narrows it).
static func _island_cells(rt: IslandRuntime) -> Rect2i:
	var n := cell_tiles()
	var isl := _island_rect(rt)
	var lo := Vector2i(floori(float(isl.position.x) / float(n)), floori(float(isl.position.y) / float(n)))
	var hi := Vector2i(floori(float(isl.end.x - 1) / float(n)), floori(float(isl.end.y - 1) / float(n)))
	return Rect2i(lo, hi - lo + Vector2i.ONE)

## How a cell reads in the preview: {"state": "claimed"|"eligible"|"invalid", "reason": String}.
static func classify(rt: IslandRuntime, cell: Vector2i) -> Dictionary:
	var held := occupied_cells(rt)
	if held.has(cell):
		# A cell the camp already covers is claimed land, not a domain cell: it is never selectable.
		return {"state": "claimed", "reason": ""}
	var why := cell_block_reason(rt, cell)
	if why != "":
		return {"state": "invalid", "reason": why}
	if not held.is_empty() and not adjacent_to(cell, held):
		return {"state": "invalid", "reason": "not_adjacent"}
	return {"state": "eligible", "reason": ""}

## The cells a preview shows around `centre` (a cell), grouped for drawing. "eligible" is what a tap
## may select; "invalid" rows carry the reason. With no domain yet every valid cell is eligible.
static func preview(rt: IslandRuntime, centre: Vector2i, radius: int = PREVIEW_RADIUS) -> Dictionary:
	var claimed: Array[Vector2i] = []
	var eligible: Array[Vector2i] = []
	var invalid: Array[Dictionary] = []
	var held := owned_cells(rt)
	for y in range(centre.y - radius, centre.y + radius + 1):
		for x in range(centre.x - radius, centre.x + radius + 1):
			var c := Vector2i(x, y)
			if held.has(c):
				continue
			var info := classify(rt, c)
			match str(info["state"]):
				"eligible":
					eligible.append(c)
				"claimed":
					claimed.append(c)
				_:
					invalid.append({"cell": c, "reason": str(info["reason"])})
	for c: Vector2i in held.keys():
		if absi(c.x - centre.x) <= radius and absi(c.y - centre.y) <= radius:
			claimed.append(c)
	return {"claimed": claimed, "eligible": eligible, "invalid": invalid}

## Human text for a refusal or a preview colour key.
static func reason_text(reason: String) -> String:
	match reason:
		"cap":
			return "Claim limit reached"
		"terrain":
			return "that cell is water or a cliff"
		"outside_the_island":
			return "that cell is outside the island"
		"ownership":
			return "another survivor's land"
		"not_adjacent":
			return "a cell must share an edge with your land (no diagonal, no hop)"
		"already_owned":
			return "that cell overlaps land you already hold"
		"no_cells":
			return "no cells selected"
		# UNCLAIM (releasing land)
		"not_owned":
			return "that plot is not part of your Domain"
		"camp_land":
			return "that is your camp's own landing plot, not a Domain plot"
		"last_cell":
			return "it is your only plot: a Domain needs at least one"
		"building":
			return "a building stands on that plot, so it cannot be released until it is packed up"
		"split":
			return "releasing it would cut your Domain into two pieces"
		_:
			return reason.replace("_", " ").capitalize() if reason != "" else ""

## The refusal for claiming `cells` as one batch ("" when it would work). Order matters: the cap is
## named first (it is the one the owner asked about), then each cell's land and ownership, then
## contiguity - a batch may also grow from its own earlier cells, so a blob is fine.
static func batch_reason(rt: IslandRuntime, cells: Array) -> String:
	if cells.is_empty():
		return "no_cells"
	var held := owned_cells(rt)
	var near := occupied_cells(rt)
	var fresh: Array[Vector2i] = []
	for c in cells:
		var cell: Vector2i = c
		if held.has(cell):
			return "already_owned"
		if near.has(cell) and not held.has(cell):
			return "already_owned"  # the camp's own land (buildable, not a domain cell)
		if fresh.has(cell):
			return "already_owned"
		fresh.append(cell)
	if used(rt) + fresh.size() > cap(rt):
		return "cap"
	for cell in fresh:
		var why := cell_block_reason(rt, cell)
		if why != "":
			return why
	if not near.is_empty():
		# Contiguous expansion (spec 29 section 2): from the domain, and for a first Declare from the
		# camp's own claimed land, so a domain always starts at the survivor's camp.
		var grow := near.duplicate()
		var pending: Array[Vector2i] = fresh.duplicate()
		var placed_any := true
		while placed_any and not pending.is_empty():
			placed_any = false
			for i in range(pending.size() - 1, -1, -1):
				if adjacent_to(pending[i], grow):
					grow[pending[i]] = true
					pending.remove_at(i)
					placed_any = true
		if not pending.is_empty():
			return "not_adjacent"
	return ""

## Claim a batch of cells (Declare or Expand). One answers what happened: {"ok", "reason", "cells"}.
## Clears the grass inside every new cell, rebuilds the outline and fires claims_changed ONCE for the
## batch. A refused batch changes nothing at all.
static func claim_cells(rt: IslandRuntime, cells: Array) -> Dictionary:
	var why := batch_reason(rt, cells)
	if why != "":
		return {"ok": false, "reason": why, "cells": []}
	var rec := rt.domain if not rt.domain.is_empty() else make_record(rt, [])
	var list: Array = (rec.get("cells", []) as Array).duplicate()
	var batch: Array[Vector2i] = []
	for c in cells:
		var cell: Vector2i = c
		list.append(cell)
		batch.append(cell)
	rec["cells"] = list
	rec["max_cells"] = DomainRules.cap()
	rt.domain = rec
	sync_cap(rt)
	_rebuild_claim_rects(rt)
	_rebuild_claim_mesh(rt)
	_clear_grass_cells(rt, batch)
	# CLAIMPROPS (owner: "I shouldn't have a tree stump or log within my claimed land"): the new land
	# holds no scenery, and no "harvest node" that has no gather option at all (that is a prop too).
	clean_claimed(rt)
	var bounds := cell_rect(rt, batch[0])
	for c in batch:
		bounds = bounds.merge(cell_rect(rt, c))
	rt.claims_changed.emit(bounds)
	print("[world] claimed %d cell(s) %s, %d/%d" % [batch.size(), str(batch), used(rt), cap(rt)])
	return {"ok": true, "reason": "", "cells": batch}

# ---------------------------------------------------------------- per-cell claim (the CLAIM press)

## Stake the cell the tile stands in; false when it cannot be claimed (the reason is in
## expand_reason). Kept for the CLAIM press and the existing callers.
static func claim_at(rt: IslandRuntime, tile: Vector2i, size: int = 0) -> bool:
	var cells: Array = [cell_of(rt, tile)]
	var out := claim_cells(rt, cells)
	if not out["ok"]:
		print("[world] claim refused: %s" % reason_text(str(out["reason"])))
		return false
	if World.is_home():
		World.home_claims = _claim_rows(rt)
	else:
		World.unstable_claims = _claim_rows(rt)
	return true

## Forget this island's domain (the CLAIM panel's tests and a released claim use it): the camp's
## own land stays claimed and buildable, no domain cells remain.
static func clear_domain(rt: IslandRuntime) -> void:
	rt.domain = {}
	_rebuild_claim_rects(rt)
	_rebuild_claim_mesh(rt)
	if World.is_home():
		World.home_claims = _claim_rows(rt)
	else:
		World.unstable_claims = _claim_rows(rt)

# ---------------------------------------------------------------- releasing a cell (UNCLAIM)

## Tiles a cell covers that hold something built: a kit's node, a construction site, a camp piece or
## a modular StructurePiece. Returns the first building found ("" when the plot is clear), so the
## refusal can say a building stands there. Buildings are never moved or destroyed by a release: the
## plot is simply refused until the survivor packs the building up (the safer of the task's two
## options, and it keeps storage contents with their owner).
static func building_on(rt: IslandRuntime, cell: Vector2i) -> String:
	var rect := cell_rect(rt, cell)
	var grid: Variant = rt.get("build_grid")
	if grid == null or not is_instance_valid(grid):
		return ""
	var g := grid as BuildGrid
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var node: Node = g.occupant(Vector2i(x, y))
			if node != null:
				return node.name if node.name != "" else "a building"
			if g.is_reserved(Vector2i(x, y)):
				return "a reserved plot"
	# Modular pieces (W2-BUILDSYS) live on the StructureGrid, not in the kit occupancy map: a
	# foundation, wall or ramp inside the cell is a building on the plot just the same.
	var structures: StructureGrid = g.structures
	if structures != null:
		for p in structures.pieces():
			if p == null or not is_instance_valid(p):
				continue
			for c in StructureGrid.module_cells(Vector2i(p.slot.x, p.slot.y)):
				if rect.has_point(c):
					return str(p.kind).capitalize() if str(p.kind) != "" else "a structure"
	return ""

## Why `cell` cannot be released right now ("" when it can): "not_owned" (the camp's own landing
## plot is never a domain cell: "camp_land"), "last_cell" (a Domain always keeps at least one plot),
## "building" (something stands on it), "split" (the rest of the Domain would fall into two pieces).
## ASSUMPTION: spec 29 names a Release action but gives no refund, cooldown or last-plot rule; the
## last plot stays (a domain with no cells is not a domain), no T-stones are refunded, no cooldown.
static func release_reason(rt: IslandRuntime, cell: Vector2i) -> String:
	var own := owned_cells(rt)
	if not own.has(cell):
		for c in cells_covering(rt, rt.camp_claim) if rt.camp_claim.has_area() else []:
			if c == cell:
				return "camp_land"
		return "not_owned"
	if own.size() <= 1:
		return "last_cell"
	if building_on(rt, cell) != "":
		return "building"
	var rest := own.duplicate()
	rest.erase(cell)
	if not _is_connected(rest):
		return "split"
	return ""

## Every cell in `cells` reachable from one of them by edge steps through `cells` only.
static func _is_connected(cells: Dictionary) -> bool:
	if cells.is_empty():
		return true
	var start: Vector2i = cells.keys()[0]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == cells.size()

## Release one cell: the ONE write path for UNCLAIM. A refused release changes nothing at all. On
## success the record loses the cell, rt.claims loses its rect (the camp's land and every other cell
## stay), the world's saved copy follows, the outline redraws and claims_changed fires once with the
## released rect. Saves need no format change: the cell is simply absent from the record. The land
## keeps whatever the claim cleaned (grass and props do not come back on their own).
## Answers {"ok", "reason", "cell"}.
static func release_cell(rt: IslandRuntime, cell: Vector2i) -> Dictionary:
	var why := release_reason(rt, cell)
	if why != "":
		return {"ok": false, "reason": why, "cell": cell}
	var rec := rt.domain
	var list: Array = (rec.get("cells", []) as Array).duplicate()
	for i in range(list.size() - 1, -1, -1):
		if list[i] is Vector2i and (list[i] as Vector2i) == cell:
			list.remove_at(i)
	rec["cells"] = list
	rt.domain = rec
	_rebuild_claim_rects(rt)
	_rebuild_claim_mesh(rt)
	if World.is_home():
		World.home_claims = _claim_rows(rt)
	else:
		World.unstable_claims = _claim_rows(rt)
	rt.claims_changed.emit(cell_rect(rt, cell))
	print("[world] released cell %s, %d/%d" % [str(cell), used(rt), cap(rt)])
	return {"ok": true, "reason": "", "cell": cell}

## The tile rect of the cell a claim at `tile` would take (Rect2i() only when the island has no grid).
static func plot_for(rt: IslandRuntime, tile: Vector2i) -> Rect2i:
	return cell_rect(rt, cell_of(rt, tile))

## `plot_at` (a rect centred on a tile) is no longer how land is staked; kept for the old callers
## that only need a display rect.
static func plot_at(tile: Vector2i, size: int = 4) -> Rect2i:
	return Rect2i(tile - Vector2i(size / 2, size / 2), Vector2i(size, size))

## Why a claim at `tile` would be refused, in words for the survivor ("" when it would be staked).
static func block_reason(rt: IslandRuntime, tile: Vector2i, _size: int = 0) -> String:
	return reason_text(batch_reason(rt, [cell_of(rt, tile)]))

## Why a claim at `tile` would not expand the land held here, in words ("" when it would). The CLAIM
## press and its confirm both ask this, so a stale panel can never stake a hop.
static func expand_reason(rt: IslandRuntime, tile: Vector2i, _size: int = 0) -> String:
	return reason_text(batch_reason(rt, [cell_of(rt, tile)]))

static func _claim_rows(rt: IslandRuntime) -> Array:
	var rows: Array = []
	for r in rt.claims:
		(rows as Array).append([r.position.x, r.position.y, r.size.x, r.size.y])
	return rows

# ---------------------------------------------------------------- grass on claimed land

static func is_grass(family: String) -> bool:
	return GRASS.has(family)

static func _clear_grass_cells(rt: IslandRuntime, cells: Array) -> int:
	var removed := 0
	for c in cells:
		removed += clear_grass(rt, cell_rect(rt, c))
	return removed

## Remove the grass inside `rect`: grass harvest nodes (WildGrass, DryGrassTuft) and the grass decor
## instances the scatter made (Grass, Grass_Short). Everything else stays.
static func clear_grass(rt: IslandRuntime, rect: Rect2i) -> int:
	var removed := 0
	var keys := []
	for key in rt._harvest_nodes.keys():
		var node: Variant = rt._harvest_nodes[key]
		if is_instance_valid(node) and node is Node3D and is_grass(str(node.get("family"))) and rect.has_point(BuildGrid.tile_of((node as Node3D).global_position)):
			keys.append(key)
	for key in keys:
		var node: Node = rt._harvest_nodes[key]
		rt._harvest_nodes.erase(key)
		rt._node_tiles.erase(key)
		var tile := BuildGrid.tile_of((node as Node3D).global_position)
		if rt._used_tiles.has(tile):
			rt._used_tiles.erase(tile)
		if node.has_method("hide_batched_visual"):
			node.call("hide_batched_visual")
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
		if not is_instance_valid(mmi) or (mmi as MultiMeshInstance3D).multimesh == null:
			continue
		var mm := (mmi as MultiMeshInstance3D).multimesh
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
			(mmi as Node).queue_free()
			continue
		var fresh := MultiMesh.new()
		fresh.transform_format = MultiMesh.TRANSFORM_3D
		fresh.mesh = mm.mesh
		fresh.instance_count = keep.size()
		for i in keep.size():
			fresh.set_instance_transform(i, keep[i])
		(mmi as MultiMeshInstance3D).multimesh = fresh
	return removed

## Grass still inside `plots` (harvest nodes plus decor instances): the lab's measured check.
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
		if not is_instance_valid(mmi) or (mmi as MultiMeshInstance3D).multimesh == null:
			continue
		var mm := (mmi as MultiMeshInstance3D).multimesh
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

# ---------------------------------------------------------------- props on claimed land (CLAIMPROPS)

## True when a harvest node really offers something: at least one option whose item exists. A node
## with no valid gather option is decoration the owner calls a prop ("especially if it can't be
## harvested"), so claimed land drops it.
static func node_gatherable(node: Node) -> bool:
	if node == null or not node.has_method("options"):
		return false
	for o in (node.call("options") as Array):
		var item := StringName(str((o as Dictionary).get("item", "")))
		if item != &"" and Data.item(item) != null:
			return true
	return false

## CLAIMPROPS: claimed land holds no scenery. Removes every prop standing on a claimed tile (the props
## layer does it by footprint) and every harvest node on a claimed tile that has no gather option at
## all. Harvestable nodes (trees, rocks, bushes, plants) stay: spec 29 says owning land grants the
## right to build and manage it, and does not say a domain is stripped of resources. Called when the
## island is built (a saved claim) and after every claim/expansion. Returns how many things went.
static func clean_claimed(rt: IslandRuntime) -> int:
	if rt == null:
		return 0
	var removed := 0
	var props: Variant = rt.get("props")
	if props != null and is_instance_valid(props) and props.has_method("clear_claimed"):
		removed += int(props.call("clear_claimed"))
	var keys: Array = []
	for key in rt._harvest_nodes.keys():
		var node: Variant = rt._harvest_nodes[key]
		if not is_instance_valid(node) or not node is Node3D:
			continue
		if not is_claimed(rt, BuildGrid.tile_of((node as Node3D).global_position)):
			continue
		if node_gatherable(node as Node):
			continue
		keys.append(key)
	for key in keys:
		var node: Node = rt._harvest_nodes[key]
		rt._harvest_nodes.erase(key)
		rt._node_tiles.erase(key)
		var tile := BuildGrid.tile_of((node as Node3D).global_position)
		if rt._used_tiles.has(tile):
			rt._used_tiles.erase(tile)
		var batch: Variant = node.get("_batch")
		if batch is VegBatch and int(node.get("_batch_idx")) >= 0:
			(batch as VegBatch).set_shown(int(node.get("_batch_idx")), false)
		var card: Variant = node.get("_card")
		if card != null and is_instance_valid(card):
			(card as Node).queue_free()
		var empty_card: Variant = node.get("_card_empty")
		if empty_card != null and is_instance_valid(empty_card):
			(empty_card as Node).queue_free()
		node.queue_free()
		removed += 1
	if removed > 0:
		print("[world] claimed land cleaned: %d scenery item(s) removed (props + non-gatherable nodes)" % removed)
	return removed

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
			var who_row := {"id": str(who["id"]), "name": str(who.get("name", "Survivor"))}
			if str(who.get("emblem", "")) != "":
				who_row["emblem"] = str(who["emblem"])  # TOWNPOLISH2: a town's picture (PlayerPortrait)
			rt.other_claims.append({"rect": rect, "owner": who_row})
	_rebuild_claim_mesh(rt)

static func _rebuild_claim_mesh(rt: IslandRuntime) -> void:
	if rt._claim_mesh == null:
		rt._claim_mesh = ClaimOutline.new()
		rt.add_child(rt._claim_mesh)
	(rt._claim_mesh as ClaimOutline).rebuild(rt)
