class_name HarvestNode
extends StaticBody3D
## Click-to-gather world node. Player paths here, waits, then receives a stamped stack.

signal depleted_tile(node: HarvestNode, tile: Vector2i)
signal regrown_tile(node: HarvestNode, tile: Vector2i)

@export var node_id: StringName = &"node"
@export var required_tool_class: StringName = &"none"
@export var regen_seconds: float = 8.0
@export var gather_seconds: float = 1.2
@export var placeholder_color: Color = Color(0.45, 0.7, 0.35)
@export var pool_max: int = 0

var yield_def_id: StringName = &"fibre_stalk"
var yield_min: int = 1
var yield_max: int = 1
var yield_attributes: Dictionary = {}
var family: String = ""
var falls_to_log: bool = false
## Seconds per unit before tool power; gather_seconds is what the survivor actually waits.
var _base_seconds: float = 1.2
## Seconds a refill waits while someone stands in the node's footprint (phys-node-01).
const OCCUPIED_RETRY := 2.0

var depleted: bool = false
var pool: float = 0.0
var session_gathered: int = 0
## One pool per yield (berries and fibre on a bush are separate). The node stays up until every
## pool is empty; each emptied pool refills RESPAWN_SECONDS later (the dirt patch shows the timer).
var pools: Dictionary = {}       # item id -> float units left
var pool_maxes: Dictionary = {}  # item id -> int
var _pool_regen: Dictionary = {} # item id -> seconds until that pool refills
const RESPAWN_SECONDS := 3600.0
var _mesh: MeshInstance3D
var _falling: bool = false
var _batch: VegBatch
var _batch_idx: int = -1
var _empty_batch: VegBatch
var _empty_batch_idx: int = -1
## CARD2D: the card drawing this node and, when the family swaps models on depletion, its empty card.
var _card: CardProp
var _card_empty: CardProp
var _tile: Vector2i = Vector2i.ZERO
var _regen_left: float = 0.0
## ISLAND RESET (doc section 5.4): a landmark node on an expedition island regrows only partly: while
## any unit is left it gains one back every `trickle_seconds`, and a pool taken to 0 stays empty until
## the island resets. 0 = the normal rule (a spent pool refills after regen_seconds).
var trickle_seconds: float = 0.0

func setup(p_id: StringName, def_id: StringName, amin: int, amax: int, attrs: Dictionary, tool: StringName, color: Color, gather: float = 1.2, regen: float = 8.0, p_family: String = "", p_falls: bool = false, p_pool_max: int = 0) -> void:
	node_id = p_id
	yield_def_id = def_id
	yield_min = amin
	yield_max = amax
	yield_attributes = attrs.duplicate(true)
	required_tool_class = tool
	placeholder_color = color
	gather_seconds = gather
	_base_seconds = gather
	regen_seconds = regen
	family = p_family
	falls_to_log = p_falls
	# The island already chooses a regrowth time per family (60 s for river mud, 90 s for bushes,
	# 240 s for trees). Flattening every one of them to an hour meant a 14-minute session farmed
	# the area out in six minutes and then had nothing left to do. Honour the family's value and
	# keep the hour only as the fallback when nobody supplied one.
	if regen_seconds <= 0.0:
		regen_seconds = RESPAWN_SECONDS
	pool_max = _resolve_pool_max(p_pool_max)
	if pool <= 0.0:
		pool = float(pool_max)
	# setup() knows the family, so it defines the pools (a _ready before setup only saw the
	# fallback single option); a save restore comes after and overrides.
	pools.clear()
	pool_maxes.clear()
	_pool_regen.clear()
	_ensure_pools()
	depleted = _all_empty()
	_regen_left = regen_seconds if depleted else 0.0
	_apply_tint()

func _ready() -> void:
	# TUTPERF: only a regrowing node ticks (600-odd nodes per island used to run an empty _process).
	set_process(not _pool_regen.is_empty())
	var runtime := get_parent()
	if runtime and runtime.has_method("surface_y"):
		_tile = BuildGrid.tile_of(global_position)
		global_position = BuildGrid.tile_centre(_tile, runtime)
	else:
		_tile = BuildGrid.tile_of(global_position)
	add_to_group("harvest")
	collision_layer = 1 if blocks_movement() else 0
	collision_mask = 0
	pool_max = _resolve_pool_max(pool_max)
	if pool <= 0.0:
		pool = float(pool_max)
	_ensure_pools()
	depleted = _all_empty()
	if get_node_or_null("Shape") == null:
		# Physics: a slim trunk so paths that pass next to the node never jam on it.
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		var tap := _collision_size()
		var trunk := _trunk_width()
		box.size = Vector3(trunk, tap.y, trunk)
		shape.shape = box
		shape.position.y = box.size.y * 0.5
		add_child(shape)
		# Tap target: the wide box, on layer 2 so it is picked by taps but never collided with.
		var zone := Area3D.new()
		zone.name = "TapZone"
		zone.collision_layer = 2
		zone.collision_mask = 0
		zone.monitoring = false
		var zs := CollisionShape3D.new()
		var zb := BoxShape3D.new()
		zb.size = tap
		zs.shape = zb
		zs.position.y = tap.y * 0.5
		zone.add_child(zs)
		add_child(zone)
	if get_node_or_null("Mesh") == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		var m := BoxMesh.new()
		var c := _collision_size()
		m.size = Vector3(maxf(0.5, c.x * 0.55), c.y, maxf(0.5, c.z * 0.55))
		_mesh.mesh = m
		_mesh.position.y = c.y * 0.5
		add_child(_mesh)
	else:
		_mesh = $Mesh
	_sync_visual_state()
	_apply_tint()

func _process(delta: float) -> void:
	if _pool_regen.is_empty() or regen_seconds <= 0.0:
		set_process(false)
		return
	var refilled := false
	for item in _pool_regen.keys():
		var left: float = float(_pool_regen[item]) - delta * Game.fast_regen_mult
		if left <= 0.0 and depleted and _occupied():
			# Regrowing now would wrap the collider around whoever stands here.
			_pool_regen[item] = OCCUPIED_RETRY
			continue
		if left <= 0.0 and trickle_seconds > 0.0:
			var mx := float(pool_maxes.get(item, pool_max))
			pools[item] = minf(mx, float(pools.get(item, 0.0)) + 1.0)
			if float(pools[item]) >= mx:
				_pool_regen.erase(item)
			else:
				_pool_regen[item] = trickle_seconds
			refilled = true
		elif left <= 0.0:
			pools[item] = float(pool_maxes.get(item, pool_max))
			_pool_regen.erase(item)
			refilled = true
		else:
			_pool_regen[item] = left
	_regen_left = _min_regen()
	if refilled:
		var was_depleted := depleted
		depleted = false
		pool = float(pool_max)
		_sync_visual_state()
		if was_depleted:
			regrown_tile.emit(self, _tile)

func _min_regen() -> float:
	var best := 0.0
	for item in _pool_regen:
		var v: float = float(_pool_regen[item])
		if best <= 0.0 or v < best:
			best = v
	return best

## Pools for every option: the first (main) yield gets the full pool, the rest half of it.
func _ensure_pools() -> void:
	var opts := options()
	for i in opts.size():
		var item := str(opts[i].get("item", ""))
		if item == "" or pools.has(item):
			continue
		var mx := pool_max if i == 0 else maxi(3, int(pool_max / 2))
		pool_maxes[item] = mx
		pools[item] = float(mx)

func _all_empty() -> bool:
	if pools.is_empty():
		return pool_units_left() <= 0
	for item in pools:
		if int(floor(float(pools[item]) + 0.0001)) > 0:
			return false
	return true

## A node stays selectable until every one of its resource pools is exhausted. Callers that only
## inspect `pool_units_left()` accidentally treat an empty active choice (for example wood logs)
## as a depleted tree even when branches or fruit remain.
func has_harvests_left() -> bool:
	return not _all_empty()

func units_left_for(item: StringName) -> int:
	if pools.has(str(item)):
		return maxi(0, int(floor(float(pools[str(item)]) + 0.0001)))
	return pool_units_left()

func active_pool_max() -> int:
	return int(pool_maxes.get(str(yield_def_id), pool_max))

## Save/load of the per-yield pools (World.harvested).
func pools_snapshot() -> Dictionary:
	return {"pools": pools.duplicate(), "maxes": pool_maxes.duplicate(), "regen": _pool_regen.duplicate()}

func restore_pools(snap: Dictionary) -> void:
	var p: Variant = snap.get("pools", {})
	var m: Variant = snap.get("maxes", {})
	var r: Variant = snap.get("regen", {})
	if p is Dictionary and not (p as Dictionary).is_empty():
		pools = (p as Dictionary).duplicate()
	if m is Dictionary and not (m as Dictionary).is_empty():
		pool_maxes = (m as Dictionary).duplicate()
	if r is Dictionary:
		_pool_regen = (r as Dictionary).duplicate()
		set_process(not _pool_regen.is_empty())
	_ensure_pools()
	_regen_left = _min_regen()
	_sync_visual_state()

## Everything this node can yield, one entry per manifest `harvest` item (reference: a tree
## offers Leaf / Log / Branch at once). Tool-gated options take longer.
## ASSUMPTION: wood_log needs an axe, stone/ore/clay a pick, bark and hide a knife; the rest is bare-handed.
## Loose stone is hand-pickable like Durango's pebbles: every first tool needs a blade_mat,
## so gating stone behind a pick that itself needs stone made a fresh survivor unable to
## craft anything at all. A pick still pays off (ProgressionScaling.tool_power = faster
## passes and richer yields) and still gates ore and clay.
const OPTION_TOOLS := {"wood_log": "axe", "pine_log": "axe", "snow_pine": "axe", "willow_wood": "axe", "acacia_wood": "axe", "ore_chunk": "pick", "clay": "pick", "bark_strip": "knife", "hide": "knife"}
## One unit per pass; seconds per unit by item (bare-handed picks are quick, tool work is slow).
const OPTION_SECONDS := {"berries": 1.1, "berry": 1.1, "mushroom": 1.0, "petals": 1.0, "dry_grass": 0.9, "fibre_stalk": 1.3, "herb_leaf": 1.2, "reed": 1.2, "branch": 1.6, "palm_frond": 1.5, "coconut": 2.0, "root": 1.8, "cactus_flesh": 1.6, "bark_strip": 2.2, "clay": 2.4, "stone": 2.8, "wood_log": 3.0, "ore_chunk": 3.2, "hide": 2.4}

func options() -> Array:
	var out: Array = []
	var fam: Dictionary = Data.nature_families.get(family, {})
	var harvest: Variant = fam.get("harvest", {})
	if harvest is Dictionary and not (harvest as Dictionary).is_empty():
		for k in harvest.keys():
			var id := StringName(str(k))
			if Data.item(id) == null:
				continue
			var tier := min_pick_tier(id)
			var tool := "pick" if tier != &"" else str(OPTION_TOOLS.get(str(k), "none"))
			var secs := float(OPTION_SECONDS.get(str(k), 3.0 if tool != "none" else 1.6))
			# The manifest's [min, max] per pass (gather-02); a bare number is a fixed yield.
			var pair: Variant = harvest[k]
			var amin := 1
			var amax := 1
			if pair is Array and (pair as Array).size() >= 2:
				amin = maxi(0, int(pair[0]))
				amax = maxi(amin, int(pair[1]))
			elif pair is float or pair is int:
				amin = maxi(1, int(pair))
				amax = amin
			var row := {"item": str(id), "min": amin, "max": amax, "tool": tool, "seconds": secs}
			if tier != &"":
				row["min_tier"] = str(tier)
			out.append(row)
	if out.is_empty():
		out.append({"item": str(yield_def_id), "min": yield_min, "max": yield_max, "tool": str(required_tool_class), "seconds": gather_seconds})
	for o in out:
		var item := str(o["item"])
		if pools.has(item):
			o["left"] = maxi(0, int(floor(float(pools[item]) + 0.0001)))
			o["pool"] = int(pool_maxes.get(item, pool_max))
			if int(o["left"]) <= 0:
				var secs: float = float(_pool_regen.get(item, 0.0))
				o["blocked_reason"] = "none left · %dm" % int(ceil(secs / 60.0)) if secs > 0.0 else "none left"
	return out

## Make one of options() the active yield for the next gathers.
func select_option(index: int) -> void:
	var opts := options()
	if opts.is_empty():
		return
	var o: Dictionary = opts[clampi(index, 0, opts.size() - 1)]
	yield_def_id = StringName(str(o["item"]))
	yield_min = int(o["min"])
	yield_max = int(o["max"])
	required_tool_class = StringName(str(o["tool"]))
	gather_seconds = float(o["seconds"])
	_base_seconds = gather_seconds

## Lowest pick tier that can work this item here, from the family's manifest "min_pick_tier"
## (flint, obsidian, copper, iron). &"" means bare hands are fine, like loose stone.
func min_pick_tier(item: StringName) -> StringName:
	var gates: Variant = Data.nature_families.get(family, {}).get("min_pick_tier", {})
	if gates is Dictionary and (gates as Dictionary).has(str(item)):
		var tier := StringName(str(gates[str(item)]))
		return tier if tier in ProgressionScaling.TOOL_TIERS else &""
	return &""

## Best usable pick in the bag by tier, then level.
static func best_pick(inv: Inventory) -> ItemStack:
	var best: ItemStack = null
	for s in inv.slots:
		if s == null or s.is_broken() or s.def() == null or s.def().tool_class != &"pick":
			continue
		if best == null:
			best = s
			continue
		var ti := ProgressionScaling.tier_index(s.material_tier())
		var bi := ProgressionScaling.tier_index(best.material_tier())
		if ti > bi or (ti == bi and s.level > best.level):
			best = s
	return best

## Seconds per unit with the bag's tool (what the survivor waits; the server reuses it).
## One rule with PlayerActions: the role's tool helps, bare hands are slower (W2-GATHER).
func seconds_for(inv: Inventory, skill_level: int = 1) -> float:
	return GatherService.unit_seconds_for(inv, self, skill_level)

func can_gather(inv: Inventory) -> String:
	if pool_units_left() <= 0:
		return "depleted" if _all_empty() else "no %s left" % str(yield_def_id).replace("_", " ")
	var need := min_pick_tier(yield_def_id)
	if need != &"":
		var pick := best_pick(inv)
		if pick == null or ProgressionScaling.tier_index(pick.material_tier()) < ProgressionScaling.tier_index(need):
			return "needs %s pick" % need
		# Swap only when the equipped pick cannot work this node: a deliberately held lower-tier
		# pick that qualifies (to spare a better one's durability) stays in hand.
		# shortcut: equips from a query because player.gd (protected) swings the equipped slot; move to PlayerActions (W2-PLAYER).
		var held := inv.equipped_gather_tool()
		var held_ok := held != null and held.def().tool_class == &"pick" \
				and ProgressionScaling.tier_index(held.material_tier()) >= ProgressionScaling.tier_index(need)
		var idx := inv.slots.find(pick)
		if not held_ok and idx >= 0:
			inv.set_equipped_tool_index(idx)
	elif not inv.has_tool_class(required_tool_class):
		return "need tool %s" % required_tool_class
	# A gathering technique the survivor has not learned refuses its material: "Needs Mining 1 (Gathering
	# Lv. 10, 8 SP)". Only the tap/walk paths that reach this are local and offline; the online gather
	# intent never asks can_gather and needs the same check server-side (W3).
	var local := PlayerRegistry.local()
	if local and local.skills:
		var locked := SkillRules.gather_block(local.skills, str(yield_def_id))
		if locked != "":
			return locked
	gather_seconds = _base_seconds
	if _is_rock() and (required_tool_class == &"none" or required_tool_class == &""):
		# Loose stone stays bare-handed, but a held pick still works it faster.
		# shortcut: primes gather_seconds because player.gd (protected) reads the field; move to PlayerActions (W2-PLAYER).
		var pick := best_pick(inv)
		if pick:
			gather_seconds = _base_seconds / pick.gather_power()  # level, tier and TRAITGEAR elasticity
	return ""

## ONEGATHER (owner 2026-10-28, "cap it to 1 per harvest"): a pass is always ONE instance. yield_min/max
## (the manifest's old [min, max] per pass) no longer count; tools and skill change speed and quality.
## HARVESTROLL: each pass is its own lot (LootRoller.roll_lot): level inside the node's band and signed
## traits, skewed by `tool_tier` (&"" bare hands) and Gathering `skill`. `rng` defaults to GatherService.rng.
func roll_yield(rng: RandomNumberGenerator = null, tool_tier: StringName = &"", skill: int = 1) -> ItemStack:
	var n := 1
	var attrs := yield_attributes.duplicate(true)
	for k in ItemStack.MERGE_IGNORED_ATTRS:
		attrs.erase(k)
	attrs.merge(LootRoller.roll_lot(yield_def_id, int(yield_attributes.get("level", 1)), tool_tier, skill, rng if rng else GatherService.rng), true)
	var stack := ItemStack.make(yield_def_id, n, attrs, int(attrs["level"]))
	if World and World.is_unstable():
		stack.set_flag(&"unstable", true)
	return stack

func consume_unit() -> bool:
	if pool_units_left() <= 0:
		depleted = _all_empty()
		return false
	var key := str(yield_def_id)
	if pools.has(key):
		pools[key] = maxf(0.0, float(pools[key]) - 1.0)
		if trickle_seconds > 0.0:
			# Partial regrowth: units left trickle back; a stripped pool stays empty until the reset.
			if int(floor(float(pools[key]) + 0.0001)) <= 0:
				_pool_regen.erase(key)
			elif not _pool_regen.has(key):
				_pool_regen[key] = trickle_seconds
				set_process(true)
			_regen_left = _min_regen()
		elif int(floor(float(pools[key]) + 0.0001)) <= 0 and regen_seconds > 0.0:
			_pool_regen[key] = regen_seconds  # the family's own regrowth time, not a flat hour
			set_process(true)
			_regen_left = _min_regen()
	else:
		pool = maxf(0.0, pool - 1.0)
	session_gathered += 1
	if _card:
		_card.rustle()
	if _all_empty():
		_on_pool_empty()
	elif _empty_batch:
		_sync_visual_state()
	return true

func pool_units_left() -> int:
	var key := str(yield_def_id)
	if pools.has(key):
		return maxi(0, int(floor(float(pools[key]) + 0.0001)))
	return maxi(0, int(floor(pool + 0.0001)))

func top_of_node() -> float:
	var shape := get_node_or_null("Shape") as CollisionShape3D
	if shape and shape.shape is BoxShape3D:
		var box := shape.shape as BoxShape3D
		return shape.position.y + box.size.y * 0.5
	return 1.6

func restore_snapshot(saved_pool: float, saved_max: int, saved_session: int = 0, saved_regen_left: float = -1.0) -> void:
	if saved_max > 0:
		pool_max = saved_max
	pool = clampf(saved_pool, 0.0, float(maxi(1, pool_max)))
	session_gathered = maxi(0, saved_session)
	depleted = pool_units_left() <= 0
	if saved_regen_left >= 0.0:
		_regen_left = saved_regen_left
	else:
		_regen_left = regen_seconds if depleted else 0.0
	_sync_visual_state()

func mark_gathered() -> void:
	consume_unit()

func _spawn_log() -> void:
	visible = false
	var log_n: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	log_n.position = global_position
	var parent := get_parent()
	if parent:
		parent.add_child(log_n)
	var attrs := yield_attributes.duplicate(true)
	log_n.setup(StringName("%s_log" % node_id), &"wood_log", 1, 2, attrs, &"none", Color(0.42, 0.28, 0.16), 1.0, 0.0, "WoodLog_Moss", false, 6)
	# SWITCH2D: under resource_render "card" the felled log is a card too, never a 3D model.
	if IslandScatter.cards_enabled() and parent is IslandRuntime:
		var vis: Dictionary = CardProp.visual_for("WoodLog_Moss", global_position)
		if str(vis.get("kind", "")) != "":
			IslandScatter._attach_card_visual(parent as IslandRuntime, log_n, vis, "prop", "WoodLog_Moss", global_position)
			return
	var path := "res://assets/nature/WoodLog_Moss.glb"
	if ResourceLoader.exists(path):
		log_n.set_visual(path)
	# ASSUMPTION: felled tree becomes a WoodLog prop for a second harvest; tree respawns after regen.

## Visual lives in a shared MultiMesh (VegBatch); this node only toggles its instance.
func set_batched_visual(batch: VegBatch, idx: int, empty_batch: VegBatch = null, empty_idx: int = -1) -> void:
	_batch = batch
	_batch_idx = idx
	_empty_batch = empty_batch
	_empty_batch_idx = empty_idx
	if _mesh:
		_mesh.visible = false
	_apply_batch()

func _set_tap_zone(on: bool) -> void:
	var z := get_node_or_null("TapZone") as Area3D
	if z:
		z.collision_layer = 2 if on else 0

func berries_available() -> bool:
	for item in ["berry", "berries"]:
		if pools.has(item) and units_left_for(StringName(item)) > 0:
			return true
	return false

## CARD2D: this node draws as a card (island_scatter when resource_render is "card"). An empty card
## is shown while the node is depleted, the way the batched path swaps to the family's depleted GLB.
func set_card_visual(card: CardProp, empty_card: CardProp = null) -> void:
	_card = card
	_card_empty = empty_card
	if _mesh:
		_mesh.visible = false
	_apply_card_state()
	_apply_batch()

## True when this node draws an "-empty" card while depleted (CARD2D).
func has_empty_card() -> bool:
	return _card_empty != null and is_instance_valid(_card_empty)

## The full card while the node has something left, the empty one while it is regrowing.
func _apply_card_state() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var full := visible and not depleted
	_card.visible = full
	if _card_empty and is_instance_valid(_card_empty):
		_card_empty.visible = visible and depleted

func refresh_batched_visual() -> void:
	_apply_batch()
	_apply_card_state()

func _apply_batch() -> void:
	if _empty_batch:
		# An empty visual represents an exhausted node, not merely an exhausted berry choice. A
		# multi-yield tree or bush must stay in its full state while any other resource remains.
		var full := has_harvests_left()
		_batch.set_shown(_batch_idx, visible and full)
		_empty_batch.set_shown(_empty_batch_idx, visible and not full)
	elif _batch:
		_batch.set_shown(_batch_idx, visible and not depleted)
	_set_tap_zone(visible and not depleted)

## The cards are children of the island runtime, not of this node (they keep their own transforms),
## so freeing this node must free them too or they stay standing with nothing to harvest.
func _exit_tree() -> void:
	for c in [_card, _card_empty]:
		if c != null and is_instance_valid(c):
			c.queue_free()
	_card = null
	_card_empty = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply_batch()
		_apply_card_state()

func set_visual(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var packed := load(path)
	if packed is PackedScene:
		var inst: Node = (packed as PackedScene).instantiate()
		inst.name = "VisualGlb"
		_apply_vis_range(inst)
		add_child(inst)
		if _mesh:
			_mesh.visible = false

func _apply_vis_range(n: Node) -> void:
	if n is GeometryInstance3D:
		# Fallback visuals must obey the same visible/interactable lifetime as this body. A
		# render-only distance cutoff leaves an invisible resource that can still be tapped.
		(n as GeometryInstance3D).visibility_range_end = 0.0
	for c in n.get_children():
		_apply_vis_range(c)

func _apply_tint() -> void:
	if _mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = placeholder_color
	_mesh.material_override = mat

func _on_pool_empty() -> void:
	depleted = true
	_regen_left = _min_regen() if not _pool_regen.is_empty() else regen_seconds
	depleted_tile.emit(self, _tile)
	if falls_to_log and not _falling:
		_falling = true
		collision_layer = 0
		var tw := create_tween()
		tw.tween_property(self, "rotation_degrees:z", 88.0, 0.65)
		tw.tween_callback(_spawn_log)
		return
	if regen_seconds <= 0.0:
		visible = false
		queue_free()
		return
	if _empty_batch or _card_empty:
		_sync_visual_state()
		return
	visible = false
	collision_layer = 0

func _sync_visual_state() -> void:
	depleted = _all_empty()
	if depleted:
		# A depleted berry bush keeps showing its empty model (or, in the card path, its -empty card);
		# only a node with neither disappears.
		visible = _empty_batch != null or has_empty_card()
		collision_layer = 0
		_apply_batch()
		_apply_card_state()
		return
	if falls_to_log:
		rotation = Vector3.ZERO
		_falling = false
	visible = true
	collision_layer = 1 if blocks_movement() else 0
	_apply_batch()
	_apply_card_state()

func regen_left() -> float:
	return _regen_left

## Tap box. Height follows the manifest's "height" span (rocks are knee-high, not 1.6 m).
func _collision_size() -> Vector3:
	var wide := _is_tree_or_rock()
	var w := 1.4 if wide else 1.0
	var span: Variant = Data.nature_families.get(family, {}).get("height", null)
	var h := 1.3 if _is_rock() else 1.6  # island_runtime's rock default tops out at 1.3 m
	if span is Array and (span as Array).size() >= 2:
		h = clampf(float(span[1]), 0.4, 1.6)
	return Vector3(w, h, w)

## TRIBE M1: half the ground footprint of what the player SEES (the batched or own mesh), at least the
## collision box: a worker stands at this edge instead of inside a big boulder's mesh.
func visual_radius() -> float:
	var box := _collision_size()
	var r := maxf(box.x, box.z) * 0.5
	var aabb := AABB()
	var sc := Vector3.ONE
	if _card and is_instance_valid(_card) and _card.visible:
		# ASSUMPTION: the painted subject fills about 80 % of its card's width.
		return maxf(r, _card._quad_size.x * _card.global_basis.get_scale().x * 0.5 * 0.8)
	if _batch and _batch_idx >= 0 and _batch_idx < _batch._xforms.size() and _batch._mesh:
		aabb = _batch._mesh.get_aabb()
		sc = _batch._xforms[_batch_idx].basis.get_scale()
	elif get_node_or_null("VisualGlb"):
		var inv := global_transform.affine_inverse()
		for mi: MeshInstance3D in get_node("VisualGlb").find_children("*", "MeshInstance3D", true, false):
			var box_i := (inv * mi.global_transform) * mi.get_aabb()
			aabb = box_i if aabb.size == Vector3.ZERO else aabb.merge(box_i)
		sc = global_basis.get_scale()
	elif _mesh and _mesh.mesh and _mesh.visible:
		aabb = _mesh.mesh.get_aabb()
		sc = _mesh.global_basis.get_scale()
	return maxf(r, maxf(aabb.size.x * sc.x, aabb.size.z * sc.z) * 0.5)

## Physics box: rocks as wide as they are tall (capped), trunks slim so paths never jam.
func _trunk_width() -> float:
	if _is_rock():
		return clampf(_collision_size().y * 0.8, 0.5, 0.9)
	return 0.55

func _occupied() -> bool:
	var reach := _trunk_width() * 0.5 + 0.45
	for group in [&"player", &"creatures"]:
		for n in get_tree().get_nodes_in_group(group):
			if n is Node3D:
				var d := (n as Node3D).global_position - global_position
				if Vector2(d.x, d.z).length() < reach:
					return true
	return false

## Survivor work clip for this node: chop for trees, mine for rocks, the bush reach otherwise.
func gather_kind() -> StringName:
	var role := str(Data.nature_families.get(family, {}).get("role", ""))
	if role.begins_with("tree"):
		return &"chop"
	if role == "rock":
		return &"mine"
	return &"gather"

## Owner 2026-10-21: animals got stuck on grass. Small resources (grass, fibre, herbs, bushes, low rocks,
## stumps) are stepped over; trees and anything taller than BLOCK_HEIGHT keep a solid trunk and block paths
## (tile_path skips nodes on layer 0). The tap zone (layer 2) is unchanged, so every node stays tappable.
const BLOCK_HEIGHT := 1.25  # ASSUMPTION: m; ore nodes and boulders (1.3-1.4 m) block, flax (1.2 m) does not
func blocks_movement() -> bool:
	var fam: Dictionary = Data.nature_families.get(family, {})
	var role := str(fam.get("role", ""))
	if role.begins_with("tree"):
		return true
	var span: Variant = fam.get("height", null)
	var top := 1.3 if role == "rock" else 0.0  # a rock without a height span is a full boulder (1.3 m)
	if span is Array and (span as Array).size() >= 2:
		top = float(span[1])
	return top > BLOCK_HEIGHT

func _is_rock() -> bool:
	return str(Data.nature_families.get(family, {}).get("role", "")) == "rock"

## A tree of any kind (cover for ambush predators: TacticalBrain).
func is_tree() -> bool:
	return str(Data.nature_families.get(family, {}).get("role", "")).begins_with("tree")

func _is_tree_or_rock() -> bool:
	var role := str(Data.nature_families.get(family, {}).get("role", ""))
	return role.begins_with("tree") or role == "rock"

func _resolve_pool_max(override_max: int) -> int:
	if override_max > 0:
		return override_max
	var fam: Dictionary = Data.nature_families.get(family, {})
	var from_manifest := int(fam.get("pool", 0))
	if from_manifest > 0:
		return from_manifest
	var role := str(fam.get("role", ""))
	# ASSUMPTION: tap-to-gather defaults by family role until art data declares per-family pools.
	if role.begins_with("tree") or role == "rock":
		return 30
	if role == "bush" or role == "plant":
		return 12
	return 12
