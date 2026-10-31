class_name StructurePlacer
extends RefCounted
## The modular-building half of BuildPlacer: socket snapping for the ghost, and the piece actions
## (place, upgrade, repair, demolish) with their material costs. BuildPlacer holds the state and the
## ghost; everything here is a static function of the grid, the player and structures.json.
## Every action returns "" on success or a reason code (BuildPlacer.reason_text words it).

const MAX_SOCKETS := 48  # snap points drawn around the ghost

## The socket a ghost aimed at `aim` snaps to: the nearest free socket that accepts the piece, or,
## when none does within snap_radius_m, the nearest socket at all with its refusal.
## {slot, rot, floor0, variant, span, reason, sockets: [[point, ok], ...]}
static func snap(sg: StructureGrid, kind: StringName, tier: StringName, aim: Vector3, rot: int, rot_manual: bool) -> Dictionary:
	var radius := float(StructurePiece.defs().get("snap_radius_m", 3.0))
	var base_y := _base_floor(sg, aim)
	var best_ok: Dictionary = {}
	var best_any: Dictionary = {}
	var sockets: Array = []
	for c in sg.candidates(kind, aim, 2):
		var r := rot if rot_manual else sg.suggested_rot(kind, c, rot)
		var res := sg.check(kind, c, r, tier)
		var ok := str(res["reason"]) == ""
		var f0: float = res["floor0"] if ok else base_y
		var point := socket_point(kind, c, r, f0)
		var d := point.distance_to(aim)
		res["slot"] = c
		res["rot"] = r
		res["dist"] = d
		if ok and d <= radius and (best_ok.is_empty() or d < float(best_ok["dist"])):
			best_ok = res
		if str(res["reason"]) != "occupied":
			if best_any.is_empty() or d < float(best_any["dist"]):
				best_any = res
			if d <= radius + 1.0 and sockets.size() < MAX_SOCKETS:
				sockets.append([point, ok])
	var out := best_ok if not best_ok.is_empty() else best_any
	if out.is_empty():
		out = {"slot": Vector4i(StructureGrid.module_of(aim).x, StructureGrid.module_of(aim).y, 0, StructurePiece.slot_code(kind)), "rot": rot,
			"floor0": base_y, "variant": 0, "span": 0, "reason": "no_socket"}
	elif best_ok.is_empty() and float(out["dist"]) > radius:
		out["reason"] = "no_socket" if str(out["reason"]) == "" else out["reason"]
	out["sockets"] = sockets
	return out

## Where a slot sits for snapping: the floor point of the slot (edge midpoint, corner, module centre).
static func socket_point(kind: StringName, s: Vector4i, r: int, f0: float) -> Vector3:
	return StructurePiece.pose(kind, s, r, f0).origin

## The level-0 floor the aim belongs to: the nearest piece's floor, else the ground under the aim.
static func _base_floor(sg: StructureGrid, aim: Vector3) -> float:
	var best := INF
	var y := sg._terrain_y(aim)
	for p in sg.pieces():
		var d := Vector2(p.global_position.x - aim.x, p.global_position.z - aim.z).length()
		if d < best and d < StructurePiece.module_m() * 3.0:
			best = d
			y = p.floor0
	return y

## "Wood Wall  plank ×4 · twine ×2": the ghost's label for a piece in a tier.
static func label(kind: StringName, tier: StringName) -> String:
	return "%s %s  %s" % [str(StructurePiece.tier_def(tier).get("label", tier)), str(StructurePiece.piece_def(kind).get("label", kind)), cost_text(StructurePiece.cost(kind, tier))]

## Snap points for the ghost: a green diamond on each free socket that takes the piece, red on the
## ones that refuse it (vertex colours; null when there are none).
static func snap_points_mesh(sockets: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for row in sockets:
		var c: Vector3 = row[0] + Vector3(0, 0.08, 0)
		var col := Color(0.25, 0.95, 0.45, 0.9) if bool(row[1]) else Color(0.95, 0.25, 0.2, 0.75)
		var r := 0.13
		var tips := [c + Vector3(r, 0, 0), c + Vector3(0, 0, r), c + Vector3(-r, 0, 0), c + Vector3(0, 0, -r)]
		for i in 4:
			for y in [r * 1.4, -r * 1.4]:
				verts.append_array(PackedVector3Array([tips[i], tips[(i + 1) % 4], c + Vector3(0, y, 0)]))
				cols.append_array(PackedColorArray([col, col, col]))
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ------------------------------------------------------------------ costs and gates

## "" when the survivor may build this tier (Construction level and node from structures.json).
# ASSUMPTION: tiers open at Construction 0/5/20/35 (thatch/wood/stone/metal) with no skill node until
# W2-SKILLS defines the Construction tree's building nodes (structures.json requires_node).
static func tier_gate(player: Node, tier: StringName) -> String:
	var td := StructurePiece.tier_def(tier)
	var skills: Variant = player.get("skills") if player else null
	if skills == null:
		return ""
	if int((skills as SkillState).level_of("construction")) < int(td.get("requires_level", 0)):
		return "locked"
	var node := str(td.get("requires_node", ""))
	if node != "" and not (skills as SkillState).is_unlocked("construction", node):
		return "locked"
	return ""

## The tier one rank up (the HUD's Upgrade button), or &"" at the top.
static func next_tier(tier: StringName) -> StringName:
	for t in (StructurePiece.defs().get("tiers", {}) as Dictionary):
		if StructurePiece.tier_rank(StringName(t)) == StructurePiece.tier_rank(tier) + 1:
			return StringName(t)
	return &""

static func can_pay(inv: Inventory, cost: Dictionary) -> bool:
	for id in cost:
		if inv.count_of(id) < int(cost[id]):
			return false
	return true

## The exact bag units a def's `n` units would spend, least valuable first (Inventory.spend_key):
## [[bag index, units], ...]. Empty while the bag is short of `n`.
static func pick_units(inv: Inventory, id: StringName, n: int) -> Array:
	if inv == null or n <= 0:
		return []
	var rows: Array = []
	for i in inv.slot_count:
		var s: ItemStack = inv.slots[i]
		if s == null or s.def_id != id or s.is_locked():
			continue
		rows.append([i, s])
	rows.sort_custom(func (a: Array, b: Array) -> bool: return Inventory.spend_key(a[1]) < Inventory.spend_key(b[1]))
	var out: Array = []
	var left := n
	for row in rows:
		if left <= 0:
			break
		var take: int = mini(left, (row[1] as ItemStack).count)
		out.append([int(row[0]), take])
		left -= take
	return out if left <= 0 else []

## Pay a cost in the least valuable exact instances of each def (spec 05:23: a default pick never
## spends the rarest piece first), so the level a piece gets comes from the units it really took.
static func pay(inv: Inventory, cost: Dictionary) -> bool:
	if inv == null or not can_pay(inv, cost):
		return false
	var plan: Array = []
	for id in cost:
		var rows := pick_units(inv, id, int(cost[id]))
		if rows.is_empty():
			return false
		plan.append_array(rows)
	# Highest index first: removing an earlier unit shifts the indices behind it.
	plan.sort_custom(func (a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for row in plan:
		inv.remove_at(int(row[0]), int(row[1]))
	return true

## The levels of the exact units `kind`/`tier` would spend, one entry per level-contributing unit
## (structures.json material_slots: counts_for_level, else the primary/main row).
static func material_levels(kind: StringName, tier: StringName, inv: Inventory) -> Array[int]:
	var out: Array[int] = []
	for row: Variant in _cost_slots(kind, tier, true):
		var slot: Dictionary = row
		var id := StringName(str(slot.get("item", "")))
		var units := pick_units(inv, id, int(slot.get("quantity", 0)))
		for u: Array in units:
			var s: ItemStack = inv.slots[int(u[0])]
			for _n in int(u[1]):
				out.append(maxi(1, s.level))
	return out

## The traits the primary (main) material passes to the building, from the units it would spend.
static func material_traits(kind: StringName, tier: StringName, inv: Inventory) -> Array:
	for row: Variant in _cost_slots(kind, tier, false):
		var slot: Dictionary = row
		if str(slot.get("role", "primary")) not in ["primary", "main"]:
			continue
		var units := pick_units(inv, StringName(str(slot.get("item", ""))), int(slot.get("quantity", 0)))
		for u: Array in units:
			var s: ItemStack = inv.slots[int(u[0])]
			var tr := Inventory.traits(s)
			if not tr.is_empty():
				return BuildingQuality.attribute_rows(tr)
	return []

## A blueprint's material slots, restricted to the ones that count for the level (`only_level`).
static func _cost_slots(kind: StringName, tier: StringName, only_level: bool) -> Array:
	var out: Array = []
	for row: Variant in StructurePiece.blueprint(kind, tier).get("material_slots", []):
		if not row is Dictionary:
			continue
		var slot: Dictionary = row
		if str(slot.get("item", "")) == "":
			continue
		if only_level and not bool(slot.get("counts_for_level", str(slot.get("role", "primary")) in ["primary", "main"])):
			continue
		out.append(slot)
	return out

## Materials to bring a damaged structure back to full: a piece pays repair_fraction of its tier's
## blueprint, a kit its placed_kinds repair list, both scaled by the missing fraction, rounded up.
# ASSUMPTION: repair_fraction 0.5 and the placed_kinds repair lists are placeholders until the owner
# tunes them; spec 10's repair rules replace this with W2-CONSTRUCT.
static func repair_cost(target: Node) -> Dictionary:
	var h := StructureHealth.of(target, true)
	if h == null or h.missing() <= 0.0:
		return {}
	var full := {}
	var scale := h.missing() / h.max_hp
	if target is StructurePiece:
		full = StructurePiece.cost((target as StructurePiece).kind, (target as StructurePiece).tier)
		scale *= float(StructurePiece.defs().get("repair_fraction", 0.5))
	else:
		for s in StructurePiece.placed_kind(BuildPlacer.kind_of_building(target)).get("repair", []):
			if s is Dictionary:
				full[StringName(str(s.get("item", "")))] = int(s.get("quantity", 0))
	var out := {}
	for id in full:
		var n := ceili(float(full[id]) * scale - 0.0001)
		if n > 0:
			out[id] = n
	return out

# ------------------------------------------------------------------ actions

## Spawn a piece at a snap result, paying its tier's blueprint. The piece joins the grid at once.
## Spec 10 §§2-3: its level and inherited traits come from the exact instances the payment spends.
static func place(sg: StructureGrid, parent: Node, kind: StringName, tier: StringName, at: Dictionary, player: Node) -> Dictionary:
	if str(at.get("reason", "no_socket")) != "":
		return {"reason": str(at.get("reason", "no_socket"))}
	var gate := tier_gate(player, tier)
	if gate != "":
		return {"reason": gate}
	var inv: Inventory = player.get("inventory")
	var cost := StructurePiece.cost(kind, tier)
	if not can_pay(inv, cost):
		return {"reason": "missing_materials"}
	var levels := material_levels(kind, tier, inv)
	var traits := material_traits(kind, tier, inv)
	var p := StructurePiece.make(kind, tier, at["slot"], int(at["rot"]), float(at["floor0"]), int(at.get("variant", 0)))
	p.span = int(at.get("span", 0))
	pay(inv, cost)
	apply_quality(p, levels, traits, _construction_level(player))
	parent.add_child(p)
	sg.register(p)
	var skills: Variant = player.get("skills")
	if skills:
		(skills as SkillState).add_xp("construction", float(StructurePiece.piece_def(kind).get("xp", 1)))
	print("[struct] placed %s %s at %s rot=%d lv=%d traits=%s" % [tier, kind, p.slot, p.rot, p.build_level, p.inherited_attributes])
	return {"reason": "", "piece": p}

## The Construction category level that caps a piece's level (1 when the node has no skills).
static func _construction_level(player: Node) -> int:
	var skills: Variant = player.get("skills") if player else null
	return maxi(1, int((skills as SkillState).level_of("construction"))) if skills else 1

## Give a piece the level and inherited traits its materials produced (spec 10 §§2-3), and the
## durability its traits add where the blueprint supports it. Called by place, upgrade and the load
## path, so a preview and a finished piece always agree.
static func apply_quality(p: StructurePiece, levels: Array, traits: Array, construction_level: int) -> void:
	var bp := StructurePiece.blueprint(p.kind, p.tier)
	var lo := int(bp.get("minimum_level", 1))
	var hi := int(bp.get("maximum_level", 60))
	p.build_level = BuildingQuality.level(levels, lo, hi, construction_level) if not levels.is_empty() else 1
	p.inherited_attributes = traits.duplicate(true)
	var eff := BuildingQuality.effects(_supported(p.kind, bp), traits, false)
	p.quality_durability = int(eff.get("durability", 0))
	p.quality_storage = int(eff.get("storage_space", 0))
	if p.health:
		var share := clampf(p.health.hp / maxf(1.0, p.health.max_hp), 0.0, 1.0)
		p.health.setup(maxf(1.0, StructurePiece.max_durability(p.kind, p.tier) + float(p.quality_durability)), -1.0,
			float(StructurePiece.tier_def(p.tier).get("creature_mult", 1.0)))
		p.health.hp = clampf(p.health.max_hp * share, 0.0, p.health.max_hp)
	p.apply_storage_bonus()

## What a piece's blueprint lets its inherited traits do: its supported_building_effects, plus
## storage_space for a kind that has storage slots at all. # ASSUMPTION: the piece_tiers rows do not
## list storage_space, and rewriting all 14 of them to would change data the building tests pin.
static func _supported(kind: StringName, bp: Dictionary) -> Array:
	var out: Array = BuildingQuality.supported(bp).duplicate()
	if int(StructurePiece.piece_def(kind).get("storage_slots", 0)) > 0 and not ("storage_space" in out):
		out.append("storage_space")
	return out

## The line a piece's card shows: "Wood Wall  Lv 12 · High Density 3".
static func quality_text(p: StructurePiece) -> String:
	return BuildingQuality.summary(p.build_level, p.inherited_attributes)

## Upgrade in place to a higher tier for that tier's full blueprint cost.
# ASSUMPTION: an upgrade costs the new tier's whole blueprint (as in ARK), with no credit for the old one.
static func upgrade(target: Node, tier: StringName, player: Node) -> String:
	if not target is StructurePiece or not StructurePiece.is_tier(tier):
		return "not_a_piece"
	var p := target as StructurePiece
	if p.owner_id != "local":
		return "not_yours"
	if StructurePiece.tier_rank(tier) <= StructurePiece.tier_rank(p.tier):
		return "not_higher"
	if StructurePiece.blueprint(p.kind, tier).is_empty():
		return "no_blueprint"
	var gate := tier_gate(player, tier)
	if gate != "":
		return gate
	if not pay(player.get("inventory"), StructurePiece.cost(p.kind, tier)):
		return "missing_materials"
	var from := p.tier
	p.set_tier(tier)
	print("[struct] upgraded %s %s -> %s at %s hp=%.0f" % [from, p.kind, tier, p.slot, p.health.hp])
	return ""

static func repair(target: Node, player: Node) -> String:
	var h := StructureHealth.of(target, true)
	if h == null:
		return "not_a_structure"
	if target is StructurePiece and (target as StructurePiece).owner_id != "local":
		return "not_yours"
	if h.missing() <= 0.0:
		return "undamaged"
	var cost := repair_cost(target)
	if not pay(player.get("inventory"), cost):
		return "missing_materials"
	h.heal_full()
	print("[struct] repaired %s to %.0f for %s" % [BuildPlacer.kind_of_building(target) if not target is StructurePiece else (target as StructurePiece).kind, h.hp, cost])
	return ""

## Take a piece down: demolish_refund of its blueprint, scaled by its health, back to the bag
## (then home cargo, then a loot bag); whatever it held up collapses without a refund.
# ASSUMPTION: demolish_refund 0.5 x health share; collapsed pieces refund nothing.
static func demolish(target: Node, player: Node) -> String:
	if not target is StructurePiece:
		return "not_a_piece"
	var p := target as StructurePiece
	if p.owner_id != "local":
		return "not_yours"
	var share := float(StructurePiece.defs().get("demolish_refund", 0.5)) * p.health.fraction()
	var back := p.take_contents()  # contents first: they get the bag's room before the refund
	var cost := StructurePiece.cost(p.kind, p.tier)
	for id in cost:
		var n := floori(float(cost[id]) * share)
		if n > 0:
			back.append(ItemStack.make(id, n))
	StructureHealth.salvage(back, p.global_position, player)
	p.destroy("demolished", player)
	return ""

# ------------------------------------------------------------------ whole building

## Every piece connected to `p` (module cells side by side or diagonal, one storey apart at most):
## the building a wall's card offers Repair all / Upgrade all for, floors and roofs included.
static func building_of(p: StructurePiece) -> Array[StructurePiece]:
	var out: Array[StructurePiece] = [p]
	var g := p.grid()
	if g == null:
		return out
	var left := g.pieces()
	left.erase(p)
	var i := 0
	while i < out.size():
		var a := out[i]
		for b in left.duplicate():
			if absi(a.slot.x - b.slot.x) <= 1 and absi(a.slot.y - b.slot.y) <= 1 and absi(a.slot.z - b.slot.z) <= 1:
				out.append(b)
				left.erase(b)
		i += 1
	return out

static func _add_cost(into: Dictionary, cost: Dictionary) -> void:
	for id in cost:
		into[id] = int(into.get(id, 0)) + int(cost[id])

## Pieces of the building below `tier` that have a blueprint in it, and what lifting them all costs.
static func upgrade_all_plan(p: StructurePiece, tier: StringName) -> Dictionary:
	var todo: Array[StructurePiece] = []
	var cost := {}
	for q in building_of(p):
		if q.owner_id == "local" and StructurePiece.tier_rank(q.tier) < StructurePiece.tier_rank(tier) and not StructurePiece.blueprint(q.kind, tier).is_empty():
			todo.append(q)
			_add_cost(cost, StructurePiece.cost(q.kind, tier))
	return {"pieces": todo, "cost": cost}

static func repair_all_plan(p: StructurePiece) -> Dictionary:
	var todo: Array[StructurePiece] = []
	var cost := {}
	for q in building_of(p):
		var c := repair_cost(q)
		if q.owner_id == "local" and not c.is_empty():
			todo.append(q)
			_add_cost(cost, c)
	return {"pieces": todo, "cost": cost}

## All or nothing: the whole building's upgrade is paid up front or nothing changes.
static func upgrade_all(p: StructurePiece, tier: StringName, player: Node) -> String:
	var gate := tier_gate(player, tier)
	if gate != "":
		return gate
	var plan := upgrade_all_plan(p, tier)
	if (plan["pieces"] as Array).is_empty():
		return "not_higher"
	if not pay(player.get("inventory"), plan["cost"]):
		return "missing_materials"
	for q in plan["pieces"]:
		(q as StructurePiece).set_tier(tier)
	print("[struct] upgraded %d pieces to %s for %s" % [(plan["pieces"] as Array).size(), tier, plan["cost"]])
	return ""

static func repair_all(p: StructurePiece, player: Node) -> String:
	var plan := repair_all_plan(p)
	if (plan["pieces"] as Array).is_empty():
		return "undamaged"
	if not pay(player.get("inventory"), plan["cost"]):
		return "missing_materials"
	for q in plan["pieces"]:
		(q as StructurePiece).health.heal_full()
	print("[struct] repaired %d pieces for %s" % [(plan["pieces"] as Array).size(), plan["cost"]])
	return ""

## "plank ×4 · twine ×2"
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in cost:
		parts.append("%s ×%d" % [str(id).replace("_", " "), int(cost[id])])
	return " · ".join(parts)
