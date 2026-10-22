class_name SaveRestore
extends RefCounted
## Rebuilds saved building rows into the live island, and refunds the ones the grid no longer
## accepts. Split out of SaveGame, which only reads and writes the snapshot.

## Building rows that could not be rebuilt and whose kit and contents do not fit in camp cargo yet.
## Saved as-is and retried on every load, so a full cargo never destroys items.
static var pending_refunds: Array = []

## Saved rows are rebuilt only where the grid would accept them now. An unknown kind or a row that
## fails can_place (overlap, off the claim, water, slope) is refunded to the camp cargo instead,
## or kept in pending_refunds while the cargo cannot take all of it.
static func buildings(rows: Array, schema: int) -> void:
	if World.runtime == null:
		return
	var grid := World.runtime.get("build_grid") as BuildGrid
	var was_ignoring := false
	# No clear_occupancy(): the runtime is fresh, and the cells it holds are the island's own camp
	# pieces, which restored rows must not overlap.
	if grid:
		was_ignoring = grid.ignore_distance
		grid.ignore_distance = true # nobody stands beside a building while it is loaded
	var kits := _kits_by_kind()
	for row in rows:
		if not row is Dictionary:
			continue
		var normalized := _normalize(row as Dictionary, schema)
		var kind := StringName(str(normalized.get("kind", "")))
		var why := "" if (kits.has(kind) or kind == &"construction_site") else "unknown kind"
		if why == "" and grid:
			why = grid.can_place(kind, cell_of(normalized), int(normalized.get("rot", 0)))
		if why != "":
			_refund(normalized, kits.get(kind, &""), why)
			continue
		var b := spawn(normalized)
		if b == null:
			continue
		World.runtime.add_child(b)
		place(b, normalized, grid)
	if grid:
		grid.ignore_distance = was_ignoring

## Rows a previous load kept for later: refunded now if the cargo has room, else kept again.
static func retry_refunds(rows: Array) -> void:
	var kits := _kits_by_kind()
	for row in rows:
		_refund(row, kits.get(StringName(str(row.get("kind", ""))), &""), "retry")

static func spawn(row: Dictionary) -> Node3D:
	var kind := StringName(str(row.get("kind", "basket")))
	match kind:
		&"catapult":
			return FieldCatapult.from_dict(row) if float(row.get("hp",200)) > 0 else null
		&"workbench", &"drying_rack", &"smoker", &"crock_pot", &"mortar", &"stone_grill", &"steamer", &"well", &"forge", &"anvil":
			return CraftStation.from_dict(row)
		&"bonfire", &"stone_fire_pit", &"campfire":
			return Bonfire.from_dict(row)
		&"makeshift_taming_pen":
			return TamingPen.from_dict(row)
		&"field_small", &"field_large":
			return FieldPlot.from_dict(row)
		&"construction_site":
			return ConstructionSite.from_dict(row)
		_:
			return (load("res://scripts/world/placed_building.gd") as GDScript).from_dict(row)

static func place(node: Node3D, row: Dictionary, grid: BuildGrid) -> void:
	var kind := StringName(str(row.get("kind", "basket")))
	var cell := cell_of(row)
	var rot := int(row.get("rot", 0))
	if grid:
		node.global_transform = grid.placement_transform(kind, cell, rot)
		if node.has_method("set_grid_pose"):
			node.set_grid_pose(cell, rot)
		grid.occupy(node, grid.cells_for(kind, cell, rot))
		return
	node.global_position = Vector3(float(row.get("x", 0.0)), 0.0, float(row.get("z", 0.0)))

static func cell_of(row: Dictionary) -> Vector2i:
	var cell_v: Variant = row.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		return Vector2i(int(cell_v[0]), int(cell_v[1]))
	return Vector2i.ZERO

## Placeable kinds -> the kit item that places them (items.json place_as).
static func _kits_by_kind() -> Dictionary:
	var out := {}
	for id in Data.items:
		var def: ItemDef = Data.items[id]
		if def.place_as != &"":
			out[def.place_as] = id
	return out

## Every item a row holds: its kit, storage contents, a pen's captured animal, a field's seed, a
## process station's jobs and outputs.
static func _items_of(row: Dictionary, kit: StringName) -> Array[ItemStack]:
	var back: Array[ItemStack] = []
	if kit != &"":
		back.append(ItemStack.make(kit, 1))
	for s in row.get("contents", []):
		if s is Dictionary and str(s.get("id", "")) != SaveSanitizer.SLOT_LOCK:
			back.append(ItemStack.from_dict(s))
	var occupant: Variant = row.get("occupant")
	if occupant is Dictionary: # shaped by SaveSanitizer._stack
		back.append(ItemStack.from_dict(occupant))
	var process: Variant = row.get("process")
	if process is Dictionary: # what hung on a drying rack, smoker, crock pot or steamer
		back.append_array(ProcessStation.saved_stacks(process))
	var crop := str(row.get("crop_id", ""))
	if crop != "" and not bool(row.get("failed", false)):
		# ASSUMPTION: a planted crop comes back as the seed it took, whatever its growth.
		var seed := StringName(str(FieldPlot._crop_row(StringName(crop)).get("seed", "")))
		if Data.item(seed) != null:
			back.append(ItemStack.make(seed, 1))
	return back

## All or nothing: tried on a scratch copy of the cargo first, so a partial fit never drops items.
## A refund bigger than the whole cargo (W2-INV: a legacy stacked row, e.g. stone x200, splits into
## one instance per slot) would wait forever, so the cargo grows for it, as the migration overflow does.
static func _refund(row: Dictionary, kit: StringName, why: String) -> void:
	var back := _items_of(row, kit)
	var left := _left_over(back, World.cargo_home.to_array())
	if left > 0 and _left_over(back, []) == 0:
		pending_refunds.append(row)
		print("[save] kept %s at %s (%s) for a later refund: camp cargo is short of room for %d items" % [row.get("kind", "?"), cell_of(row), why, left])
		return
	var slots_before := World.cargo_home.slot_count
	for stack in back:
		World.cargo_home.add_growing(stack)
	print("[save] refunded %s at %s (%s): %d stacks to camp cargo (%d -> %d slots)" % [row.get("kind", "?"), cell_of(row), why, back.size(), slots_before, World.cargo_home.slot_count])

## Units of `back` that do not fit a cargo-sized container holding `rows`.
static func _left_over(back: Array[ItemStack], rows: Array) -> int:
	var scratch := Inventory.new(World.cargo_home.slot_count)
	scratch.load_array(rows)
	var left := 0
	for stack in back:
		left += scratch.add(stack.duplicate_stack())
	return left

static func _normalize(row: Dictionary, schema: int) -> Dictionary:
	var out := row.duplicate(true)
	if schema >= 2 and out.has("cell"):
		return out
	var x := float(out.get("x", 0.0))
	var z := float(out.get("z", 0.0))
	var tile := BuildGrid.tile_of(Vector3(x, 0.0, z))
	out["cell"] = [tile.x, tile.y]
	out["rot"] = int(out.get("rot", 0))
	return out
