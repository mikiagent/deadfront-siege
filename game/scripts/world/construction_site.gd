class_name ConstructionSite
extends StaticBody3D
## A placed but unfinished blueprint (owner's spec 30 §§6-8): a persistent world entity with a unique
## id, an owner, a blueprint, its reserved footprint and an escrow of the exact item instances
## deposited so far. It is deliberately NOT a CraftStation and has no job machinery: it never works
## as a station before completion. The escrow holds the real instances (no clones); withdrawing or
## cancelling hands them back. BuildFlow.complete consumes the escrow once and swaps the site for one
## finished CraftStation.

const GROUP := "construction_site"

var site_id: String = ""
var blueprint_id: StringName = &""
var owner_name: String = ""
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var persist_building: bool = true
## The BuildGrid kind whose footprint this site reserves (the station kind), set by BuildFlow.
var grid_kind: StringName = &"workbench"
## Per blueprint slot, the exact instances deposited there (unique ids and properties intact).
var slot_items: Array = []  ## Array[Array[ItemStack]]
## Per instance, who deposited it (spec 30 §7 contribution ownership).
var deposited_by: Dictionary = {}  ## uid -> name
## Construction work done so far, in seconds of the blueprint's work_seconds.
var work_progress: float = 0.0
## CRAFTRADIAL: the build timer runs by itself once the Construction panel placed every material.
## # ASSUMPTION: not saved (no save-format change); a reloaded site resumes when its panel reopens
## ("Start build") or through Work, as before.
var building: bool = false
var _pending: Dictionary = {}

func setup(bp_id: StringName, p_owner: String) -> void:
	blueprint_id = bp_id
	owner_name = p_owner
	site_id = "site_" + Crypto.new().generate_random_bytes(6).hex_encode()
	var bp := Blueprints.of(bp_id)
	slot_items.clear()
	for _slot in bp.get("slots", []):
		slot_items.append([])

func bp() -> Dictionary:
	return Blueprints.of(blueprint_id)

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group("placed_building")
	_apply_visual()
	if not _pending.is_empty():
		from_pending(_pending)
		_pending = {}
	if slot_items.is_empty():
		setup(blueprint_id, owner_name)
	_add_worksite_marks()

## Owner 2026-10-28: a worksite reads as a bare patch of trodden dirt the size of its footprint, with a
## faint grey round symbol of what is being built in the middle and its build progress over it.
func _add_worksite_marks() -> void:
	PropVisuals.ensure_foundation(self, grid_kind)
	if get_node_or_null("SiteIcon") == null:
		var disc := MeshInstance3D.new()
		disc.name = "SiteIconDisc"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.42
		cyl.height = 0.01
		cyl.radial_segments = 32
		disc.mesh = cyl
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.85, 0.85, 0.82, 0.35)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		disc.material_override = dm
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(0.0, 0.12, 0.0)
		add_child(disc)
		var icon := Sprite3D.new()
		icon.name = "SiteIcon"
		icon.texture = HexButton.grey_texture(ItemIcons.texture(icon_item()))
		icon.axis = Vector3.AXIS_Y # lies on the dirt, a symbol drawn on the plot
		icon.pixel_size = 0.6 / maxf(1.0, float(icon.texture.get_width()) if icon.texture else 1.0)
		icon.modulate = Color(1, 1, 1, 0.7)
		icon.transparent = true
		icon.shaded = false
		icon.position = Vector3(0.0, 0.13, 0.0)
		add_child(icon)
	_sync_progress_label()

## The item whose icon is the symbol: the station's kit (workbench_kit for a Workbench).
func icon_item() -> StringName:
	var kit := BuildPlacer.kit_for(grid_kind)
	return kit if kit != &"" else grid_kind

func _sync_progress_label() -> void:
	var l := get_node_or_null("SiteProgress") as Label3D
	if l == null:
		l = StationState.floating_label("SiteProgress", 1.2)
		add_child(l)
	l.text = "Building %d%%" % roundi(overall_progress() * 100.0)

var _label_left := 0.0

func _process(delta: float) -> void:
	_tick_build(delta)
	_label_left -= delta
	if _label_left <= 0.0:
		_label_left = 0.25
		_sync_progress_label()

## CRAFTRADIAL: the build timer, once the Construction panel placed every material.
func _tick_build(delta: float) -> void:
	if not building or has_meta(&"tribe_builder"):  # TRIBE M2a: an assigned builder drives the work
		return
	if not materials_ready() or work_done():
		building = false
		return
	work_progress = minf(float(bp().get("work_seconds", 1.0)), work_progress + delta)

## Unfinished sites use the art pipeline's stage models when they exist (site_small_0/1/2,
## site_large_0/1/2 under assets/props/blender/), else a simple stand-in (PropVisuals fallback).
func _apply_visual() -> void:
	if get_node_or_null("Prop") != null or get_node_or_null("FallbackMesh") != null:
		return
	var stage := _stage_scene()
	if stage != null:
		var inst := stage.instantiate() as Node3D
		inst.name = "Prop"
		add_child(inst)
		PropVisuals.ensure_collision(self, PropVisuals.collision_size(&"sign", inst, Vector3(1.8, 1.2, 1.8)))
		return
	PropVisuals.apply_building_visual(self, &"workbench", Vector3(1.8, 1.2, 1.4), Color(0.42, 0.34, 0.22))

## The construction-site stage model for the current progress, or null before the art lands.
func _stage_scene() -> PackedScene:
	var large := _large_site()
	var stage := 0
	var p := overall_progress()
	if p >= 0.66:
		stage = 2
	elif p >= 0.33:
		stage = 1
	var base := "res://assets/props/blender/%s_%s_%d.glb" % ["site_large" if large else "site_small", "stage", stage]
	# The pipeline names them site_small_0/1/2, site_large_0/1/2.
	base = "res://assets/props/blender/%s_%d.glb" % ["site_large" if large else "site_small", stage]
	if ResourceLoader.exists(base):
		return load(base) as PackedScene
	var alt := "res://assets/props/blender/%s_%d.tscn" % ["site_large" if large else "site_small", stage]
	return load(alt) as PackedScene if ResourceLoader.exists(alt) else null

func _large_site() -> bool:
	var fp := Blueprints.footprint(bp())
	return fp.x * fp.y > 4

func progress() -> float:
	return overall_progress()

func overall_progress() -> float:
	var mats := materials_ratio()
	var work := work_ratio()
	return clampf((mats + work) * 0.5, 0.0, 1.0)

func materials_ratio() -> float:
	var need := 0
	var have := 0
	var slots: Array = bp().get("slots", [])
	for i in slots.size():
		need += int((slots[i] as Dictionary).get("quantity", 1))
		have += deposited(i)
	return 0.0 if need == 0 else clampf(float(have) / float(need), 0.0, 1.0)

func work_ratio() -> float:
	var secs := float(bp().get("work_seconds", 1.0))
	return 0.0 if secs <= 0.0 else clampf(work_progress / secs, 0.0, 1.0)

func work_done() -> bool:
	return work_progress >= float(bp().get("work_seconds", 1.0))

func materials_ready() -> bool:
	var slots: Array = bp().get("slots", [])
	for i in slots.size():
		if deposited(i) < needed(i):
			return false
	return not slots.is_empty()

func ready_to_finish() -> bool:
	return materials_ready() and work_done()

func slot_count() -> int:
	return (bp().get("slots", []) as Array).size()

func needed(slot: int) -> int:
	var slots: Array = bp().get("slots", [])
	if slot < 0 or slot >= slots.size():
		return 0
	return int((slots[slot] as Dictionary).get("quantity", 1))

func deposited(slot: int) -> int:
	if slot < 0 or slot >= slot_items.size():
		return 0
	var n := 0
	for s: ItemStack in slot_items[slot]:
		n += s.count
	return n

func slot_counts() -> Array[int]:
	var out: Array[int] = []
	for i in slot_count():
		out.append(deposited(i))
	return out

## The bag index of an instance this slot may take, preferring the lowest level (a default deposit
## never spends the rarest qualifying piece first), or -1.
func first_fitting(inv: Inventory, slot: int) -> int:
	var slots: Array = bp().get("slots", [])
	if inv == null or slot < 0 or slot >= slots.size():
		return -1
	var want: Dictionary = slots[slot]
	var best := -1
	for i in inv.slot_count:
		var s: ItemStack = inv.slots[i]
		if s == null or s.def_id == Inventory.LOCK or s.is_locked():
			continue
		if not Blueprints.fits(want, s):
			continue
		if best < 0 or s.level < inv.slots[best].level:
			best = i
	return best

## Move the exact instance at `idx` from `inv` into the slot's escrow. Returns false (and moves
## nothing) when the instance does not satisfy the slot's tags or minimum level.
func deposit(slot: int, idx: int, who: String = "") -> bool:
	var inv: Inventory = _bag
	if inv == null:
		inv = PlayerRegistry.local().inventory if PlayerRegistry.local() else null
	if inv == null or idx < 0 or idx >= inv.slot_count:
		return false
	var slots: Array = bp().get("slots", [])
	if slot < 0 or slot >= slots.size() or deposited(slot) >= needed(slot):
		return false
	var s: ItemStack = inv.slots[idx]
	if s == null or not Blueprints.fits(slots[slot], s):
		return false
	var taken: ItemStack = inv.remove_at(idx, 1)
	if taken == null:
		return false
	var by := who if who != "" else owner_name
	if taken.uid != "":
		deposited_by[taken.uid] = by
	# Spec 30 §7: the contributor is recorded on the instance itself, so it survives a save round
	# trip and a later withdrawal still says whose part it was.
	if taken.creator == "":
		taken.creator = by
	slot_items[slot].append(taken)
	print("[buildflow] %s deposit %s into %s (%d/%d)" % [site_id, taken.def_id, (slots[slot] as Dictionary).get("slot_id", slot), deposited(slot), needed(slot)])
	return true

## The bag deposits go into; BuildFlow and the site UI set it. Defaults to the local survivor's.
var _bag: Inventory

func bind_bag(inv: Inventory) -> void:
	_bag = inv

## Hand the last instance deposited in `slot` back to the bag (spec 30 §7 Withdraw). False when the
## bag cannot take it: nothing moves then.
func withdraw(slot: int, inv: Inventory = null) -> bool:
	var bag: Inventory = inv if inv != null else _bag
	if bag == null:
		var p := PlayerRegistry.local()
		bag = p.inventory if p else null
	if bag == null or slot < 0 or slot >= slot_items.size() or (slot_items[slot] as Array).is_empty():
		return false
	var s: ItemStack = slot_items[slot][slot_items[slot].size() - 1]
	if bag.add(s.duplicate_stack()) > 0:
		return false
	slot_items[slot].remove_at(slot_items[slot].size() - 1)
	if s.uid != "":
		deposited_by.erase(s.uid)
	return true

## Everything in escrow, in slot order (never a copy: these are the instances themselves).
func escrow() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for col in slot_items:
		for s: ItemStack in col:
			out.append(s)
	return out

func slot_instance(slot: int, i: int) -> ItemStack:
	if slot < 0 or slot >= slot_items.size():
		return null
	var col: Array = slot_items[slot]
	return col[i] if i >= 0 and i < col.size() else null

## The levels of the level-contributing instances deposited so far (one entry per unit).
func contributing_levels() -> Array[int]:
	var out: Array[int] = []
	var slots: Array = bp().get("slots", [])
	for i in slots.size():
		if not bool((slots[i] as Dictionary).get("level_contributing", false)):
			continue
		for s: ItemStack in slot_items[i]:
			for _n in s.count:
				out.append(s.level)
	return out

## The traits the primary (main) slot's first instance would pass to the finished building
## (spec 10 §3: ordinary inheritance reads the primary material only). Empty until one is deposited.
func contributing_traits() -> Array:
	return BuildingQuality.primary_traits(bp().get("slots", []), slot_items)

## What those traits will do to the finished station, by the blueprint's supported effects.
func preview_effects() -> Dictionary:
	return BuildingQuality.effects(BuildingQuality.station_supported(bp()), contributing_traits(), true)

## Preview of the structure level completion would give now (0 while materials are short).
func preview_level(construction_level: int) -> int:
	if not materials_ready():
		return 0
	return Blueprints.result_level(bp(), contributing_levels(), construction_level)

## Advance the work timer by `seconds` (never past the blueprint's workload). Returns true when the
## clock moved. XP is paid only on completion, never per work tick (spec 30 §3 exploit protection).
func work(seconds: float) -> bool:
	if not materials_ready() or work_done():
		return false
	var secs := float(bp().get("work_seconds", 1.0))
	work_progress = minf(secs, work_progress + maxf(0.01, seconds))
	print("[buildflow] %s work %.1f/%.1f" % [site_id, work_progress, secs])
	return true

## Tap entry: the construction site sheet (BuildUI). PlayerActions routes a site tap to the UI.
func interact(player: Player) -> bool:
	var ui: Variant = player.get("build_ui") if player else null
	if ui == null:
		return false
	ui.show_site(self)
	return true

## Give every escrowed instance back and remove the site (spec 30 §7 Cancel). All or nothing: a bag
## that cannot hold every unit leaves the site and its escrow untouched.
func cancel(player: Player) -> bool:
	var back := escrow()
	var inv: Inventory = player.inventory if player else null
	if inv == null:
		return false
	if not BuildPlacer.fits_in_bag(inv, back):
		player.notice("Bag is full: make room to cancel this site.")
		return false
	for s in back:
		inv.add(s.duplicate_stack())
	for col in slot_items:
		(col as Array).clear()
	deposited_by.clear()
	print("[buildflow] %s cancelled, %d instances returned" % [site_id, back.size()])
	_remove()
	return true

## What the site held, handed over and cleared (duck-typed like every other building).
func salvage_contents() -> Array[ItemStack]:
	var out := escrow()
	for col in slot_items:
		(col as Array).clear()
	deposited_by.clear()
	return out

## A site cannot be packed into a kit: it is cancelled (which returns the materials) or completed.
func pack_up_block_reason() -> String:
	return "Finish or cancel the %s" % str(bp().get("display_name", "site"))

func _remove() -> void:
	if World.runtime and World.runtime.get("build_grid") is BuildGrid:
		(World.runtime.get("build_grid") as BuildGrid).release(self)
	queue_free()

# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	var rows: Array = []
	for s in escrow():
		rows.append(s.to_dict())
	return {
		"kind": "construction_site",
		"grid_kind": str(grid_kind),
		"site_id": site_id,
		"blueprint": str(blueprint_id),
		"owner": owner_name,
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"x": global_position.x,
		"z": global_position.z,
		"contents": rows,
		"work": work_progress,
		"contributors": deposited_by.duplicate(),
	}

## Built (not yet in the tree) with its escrow already restored: SaveRestore.spawn hands the node
## back before it is added, so a reload's deposits must exist on the instance itself.
static func from_dict(d: Dictionary) -> ConstructionSite:
	var s := ConstructionSite.new()
	s.build_cell = SaveRestore.cell_of(d)
	s.build_rot = int(d.get("rot", 0))
	s.from_pending(d)
	return s

func from_pending(d: Dictionary) -> void:
	blueprint_id = StringName(str(d.get("blueprint", "")))
	grid_kind = StringName(str(d.get("grid_kind", "workbench")))
	site_id = str(d.get("site_id", ""))
	owner_name = str(d.get("owner", ""))
	work_progress = clampf(float(d.get("work", 0.0)), 0.0, float(bp().get("work_seconds", 1.0)))
	if site_id == "":
		site_id = "site_" + Crypto.new().generate_random_bytes(6).hex_encode()
	setup(blueprint_id, owner_name)
	slot_items.clear()
	for _slot in bp().get("slots", []):
		slot_items.append([])
	var by: Variant = d.get("contributors", {})
	if by is Dictionary:
		for k in by:
			deposited_by[str(k)] = str(by[k])
	var slots: Array = bp().get("slots", [])
	for row: Variant in SaveSanitizer.stacks(d.get("contents", [])):
		if not row is Dictionary:
			continue
		var s := ItemStack.from_dict(row as Dictionary)
		if s.def() == null or s.count <= 0:
			continue
		# The escrow is exact: a saved row that no longer fits any slot is handed back by
		# salvage_contents (it stays in escrow, so nothing is deleted).
		var placed := false
		for i in slots.size():
			if Blueprints.fits(slots[i], s) and deposited(i) + s.count <= needed(i):
				slot_items[i].append(s)
				placed = true
				break
		if not placed:
			print("[buildflow] %s saved %s no longer fits: kept for salvage" % [site_id, s.def_id])
			if slot_items.is_empty():
				slot_items.append([])
			(slot_items[0] as Array).append(s)

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)
