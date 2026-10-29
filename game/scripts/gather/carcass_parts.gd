class_name CarcassParts
extends RefCounted
## Spec 12 §2 (Butchering: carcass part selection, not generic random loot): the survivor chooses
## which parts to cut off a carcass. The part list per species comes from data/butchering.json; every
## cut takes time and spends one unit of a per-carcass budget; parts never cut stay on the carcass and
## are lost when it despawns. Butchering skill nodes (Data.butcher_row_open), the survival-node tier
## and the knife still gate and scale each cut, and a part with a rare row rolls it once, on the cut.
##
## ASSUMPTION: the docs do not give the size of the cut budget, so it is 1 + floor(Butchering level / 10)
## (CUTS_BASE + level / LEVELS_PER_CUT). The 1.6 s per cut is the shipped corpse-take wait.
## Pure math + the one data read: no nodes, RNG injected, so the server can run the same cut.

## ASSUMPTION: a fresh survivor gets one cut; every ten Butchering levels adds one more.
const CUTS_BASE := 1
const LEVELS_PER_CUT := 10
## ASSUMPTION: a stone-knife cut at Butchering 0 takes as long as the shipped corpse take
## (PlayerActions.CORPSE_TAKE_SECONDS); cut_seconds shortens it.
const CUT_SECONDS := 1.6
## The most cuts a budget ever reaches (level 60 -> 7); also the clamp a save row is held to.
const CUTS_MAX := CUTS_BASE + 60 / LEVELS_PER_CUT

## Cuts a carcass offers this survivor: 1 + floor(Butchering level / 10).
static func cut_budget(skill_level: int) -> int:
	return CUTS_BASE + maxi(0, skill_level) / LEVELS_PER_CUT

## Seconds one cut takes for this context: CUT_SECONDS shortened by the knife tier and Butchering level
## (loot_tables.json butcher.cut_speed_*). Upgrades change the speed, never the one part a cut gives.
static func cut_seconds(ctx: Dictionary) -> float:
	var cfg := LootTables.butcher_cfg()
	var tier: StringName = ctx.get("knife_tier", &"")
	var tier_idx := ProgressionScaling.tier_index(tier) if tier != &"" else 0
	var speed := 1.0 + float(cfg.get("cut_speed_bonus_per_tier", 0.0)) * float(maxi(0, tier_idx)) \
			+ float(cfg.get("cut_speed_bonus_per_skill_level", 0.0)) * float(maxi(0, int(ctx.get("skill", 0))))
	return CUT_SECONDS / maxf(1.0, speed)

## The part list of a carcass: game/data/butchering.json's base rows, then its rare rows. One entry
## per item id (protoceratops lists raptor_bone twice: its rare row is the same cut's rare outcome).
## Each part is {"id": StringName, "row": Dictionary, "rare": Dictionary, "rare_only": bool}.
static func parts(species: StringName) -> Array[Dictionary]:
	return parts_of(Data.butcher_tables.get(str(species), {}))

static func parts_of(table: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := {}
	for row_v in table.get("base", []):
		var part := _part(row_v, false)
		if part.is_empty():
			continue
		var id: StringName = part["id"]
		if at.has(id):
			continue  # one cut per item id; the first row is the cut
		at[id] = out.size()
		out.append(part)
	for row_v in table.get("rare", []):
		var part := _part(row_v, true)
		if part.is_empty():
			continue
		var id: StringName = part["id"]
		if at.has(id):
			out[at[id]]["rare"] = part["row"]
		else:
			at[id] = out.size()
			out.append(part)
	return out

## One part entry from one data row, or {} for a row this build cannot cut (no id / unknown item).
static func _part(row_v: Variant, rare_only: bool) -> Dictionary:
	if not (row_v is Dictionary):
		return {}
	var row := row_v as Dictionary
	var id := StringName(str(row.get("id", "")))
	if id == &"" or Data.item(id) == null:
		return {}
	return {"id": id, "row": row, "rare": row if rare_only else {}, "rare_only": rare_only}

## Why this survivor cannot cut `part` now ("" = it can). The knife, the part's Butchering node, the
## survival-node tier, the cut budget and the carcass's spoiled meat all answer here.
static func reason(part: Dictionary, ctx: Dictionary) -> String:
	var id: StringName = part["id"]
	var inv: Inventory = ctx.get("inv") as Inventory
	if inv == null or not inv.has_tool_class(&"knife"):
		return "need tool knife"
	var cut: Array = ctx.get("cut", [])
	if cut.has(id):
		return "already cut"
	if int(ctx.get("cuts_left", 0)) <= 0:
		return "no cuts left"
	var row: Dictionary = part["row"]
	var node_tier := int(ctx.get("node_tier", 0))
	if node_tier < int(row.get("skill", 0)):
		return "needs Butchering %d" % int(row.get("skill", 1))
	var p := PlayerRegistry.local()
	if p != null and p.skills != null:
		var block := SkillRules.butcher_block(p.skills, str(id))
		if block != "":
			return block
	var def := Data.item(id)
	if def != null and bool(ctx.get("no_meat", false)) and def.has_category(&"raw_meat"):
		return "meat spoiled"
	return ""

## The cut context a real survivor brings (also what tests build): knife tier, Butchering level,
## survival-node tier, spoiled meat, bag, the carcass's cuts left and the parts already cut.
static func context(p: Player, level: int, no_meat: bool, cuts_left: int, cut: Array) -> Dictionary:
	var inv: Inventory = p.inventory if p != null else null
	var knife: ItemStack = inv.find_gather_tool(&"knife") if inv != null else null
	var skill := maxi(0, p.skills.level_of("butchering")) if p != null and p.skills != null else 0
	return {
		"level": level,
		"knife_tier": knife.material_tier() if knife != null else &"",
		"node_tier": Data.butchering_level(),
		"skill": skill,
		"no_meat": no_meat,
		"inv": inv,
		"cuts_left": cuts_left,
		"cut": cut,
	}

## One chosen cut: exactly one instance of this part (LootRoller.roll_part), its rare row rolled once
## for this cut (a hit makes that one instance the rare one; knife tier and Butchering raise the odds). A rare-only part (a talon) rolls
## its odds to exist at all; a miss still spends the cut. Returns
## {"ok", "reason", "stacks": Array[ItemStack], "rares": Array[StringName], "missed": bool}.
static func cut(part: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var why := reason(part, ctx)
	if why != "":
		return _refused(why)
	var level := int(ctx.get("level", 1))
	var tier: StringName = ctx.get("knife_tier", &"")
	var node_tier := int(ctx.get("node_tier", 0))
	var skill := int(ctx.get("skill", 0))
	var no_meat := bool(ctx.get("no_meat", false))
	var stacks: Array[ItemStack] = []
	var rares: Array[StringName] = []
	var missed := false
	var id: StringName = part["id"]
	if bool(part.get("rare_only", false)):
		if rng.randf() >= LootRoller.part_rare_chance(part["row"], tier, skill):
			missed = true
		else:
			var st := LootRoller.roll_part(part["row"], level, tier, node_tier, skill, no_meat, rng)
			if st != null:
				stacks.append(st)
				rares.append(id)
	else:
		var st := LootRoller.roll_part(part["row"], level, tier, node_tier, skill, no_meat, rng)
		if st != null:
			stacks.append(st)
		var rare_v: Variant = part.get("rare", {})
		if rare_v is Dictionary and not (rare_v as Dictionary).is_empty():
			var rare := rare_v as Dictionary
			if rng.randf() < LootRoller.part_rare_chance(rare, tier, skill):
				var rs := LootRoller.roll_part(rare, level, tier, node_tier, skill, no_meat, rng)
				if rs != null:
					stacks = [rs]  # one part per cut: the rare roll upgrades it, never adds a second
					rares.append(id)
	return {"ok": true, "reason": "", "stacks": stacks, "rares": rares, "missed": missed}

## A cut that spent nothing (refused before any roll).
static func _refused(why: String) -> Dictionary:
	return {"ok": false, "reason": why, "stacks": [] as Array[ItemStack], "rares": [] as Array[StringName], "missed": false}

# ---------------------------------------------------------------- save/load

## The carcass state a save keeps while it lies on the ground (spec 12 §2: the parts cut so far
## survive a reload). SaveSanitizer.clean shapes the row; SaveRestore.carcasses spawns it back.
static func to_row(corpse: Corpse) -> Dictionary:
	var parts: Array = []
	for id in corpse.cut_parts:
		parts.append(str(id))
	return {
		"species": str(corpse.species),
		"level": corpse.level,
		"cuts_left": corpse.cuts_left,
		"cuts_budget": corpse.cuts_budget,
		"cut_parts": parts,
		# A corpse outside the tree (a test, a row rebuilt before it is added) has no global transform.
		"position": [(corpse.global_position if corpse.is_inside_tree() else corpse.position).x,
			(corpse.global_position if corpse.is_inside_tree() else corpse.position).y,
			(corpse.global_position if corpse.is_inside_tree() else corpse.position).z],
		"loot": corpse.loot.to_array(),
	}

## A corpse from a save row (already cleaned by SaveSanitizer). Unknown species: null.
static func corpse_from_row(row: Dictionary) -> Corpse:
	var species := StringName(str(row.get("species", "")))
	if species == &"" or not Data.butcher_tables.has(str(species)):
		return null
	var c := Corpse.new()
	c.species = species
	c.level = maxi(1, int(row.get("level", 1)))
	c.loot.load_array(row.get("loot", []))
	c.apply_cut_state(int(row.get("cuts_budget", CUTS_BASE)), int(row.get("cuts_left", CUTS_BASE)), row.get("cut_parts", []))
	var pos: Variant = row.get("position", [])
	if pos is Array and (pos as Array).size() >= 3:
		c.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	return c
