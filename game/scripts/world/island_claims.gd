class_name IslandClaims
extends RefCounted
## Land claims (M8d Part B), who owns them (spec 18) and the dashed boundary mesh that marks them.

const SELF_ID := "self"  ## owner id of this survivor's own claims

## Home: the camp plot (14x14 tiles) is claimed at creation plus whatever was saved.
## Unstable: whatever the player staked this visit. Buildings only go on claimed tiles.
static func setup(rt: IslandRuntime, def: Dictionary) -> void:
	rt.claims.clear()
	var camp_tile := BuildGrid.tile_of(rt._camp_pos)
	var saved: Array = World.claims_for_current()
	if str(def.get("kind", "")) == "private":
		var base := Rect2i(camp_tile - Vector2i(7, 7), Vector2i(14, 14))
		rt.claims.append(base)
		for r in saved:
			if r is Array and (r as Array).size() >= 4:
				rt.claims.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		if saved.is_empty():
			World.home_claims = [[base.position.x, base.position.y, base.size.x, base.size.y]]
	else:
		# ASSUMPTION: the camp landing spot is always buildable on unstable islands (tents, pens).
		rt.claims.append(Rect2i(camp_tile - Vector2i(7, 7), Vector2i(14, 14)))
		for r in saved:
			if r is Array and (r as Array).size() >= 4:
				rt.claims.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	_rebuild_claim_mesh(rt)

static func is_claimed(rt: IslandRuntime, tile: Vector2i) -> bool:
	for r in rt.claims:
		if r.has_point(tile):
			return true
	return false

## Claim a 14x14 plot centred on the tile; returns false when its centre is not dry land or the plot
## would take any tile another player holds.
static func claim_at(rt: IslandRuntime, tile: Vector2i, size: int = 14) -> bool:
	var rect := Rect2i(tile - Vector2i(size / 2, size / 2), Vector2i(size, size))
	var centre := BuildGrid.tile_centre(tile, rt)
	if not rt.spawn_ok(centre, false):
		return false
	for row in rt.other_claims:
		if rect.intersects(row["rect"]):
			return false
	rt.claims.append(rect)
	var row := [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if World.is_home():
		World.home_claims.append(row)
	else:
		World.unstable_claims.append(row)
	_rebuild_claim_mesh(rt)
	print("[world] claimed %dx%d at (%d,%d)" % [size, size, tile.x, tile.y])
	return true

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
