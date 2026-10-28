class_name CookRoles
extends RefCounted
## COOKROLES (spec 08 §2-4): a cooking recipe's slots have ROLES (main / topping / sauce / broth /
## spice / support) and per-slot INHERITANCE flags saying which of the exact ingredient INSTANCE's
## traits, in-place cooking history and flags pass into the finished dish.
##
## Rules this file implements, in the order spec 08 §3 states them:
##   - a role narrows what a slot accepts, so a spice can never fill the main slot (the slot's own
##     item category still has to match: the role is an extra restriction, never a replacement);
##   - only a recipe that sets "inherit": true transfers anything from its ingredients, and only from
##     the slots whose own flag allows it, so a recipe can explicitly opt out;
##   - traits pass from THAT instance, by key, FIRST WINS across the slots in slot order: two mains
##     carrying rich_cut do not add up and two levels do not average (spec 08 §3 names averaging for
##     recipes that opt into it; no recipe here does, and an unaveraged rule cannot silently
##     promote the best ingredient);
##   - rare (green) traits only pass when the slot's rule says so (spec 08 §3: "only if the recipe
##     defines a compatible conversion");
##   - toppings, sauces, broth and spice add their own role bonus even when they inherit nothing.
##
## What a dish inherited is stored on the dish itself (attributes.cooked_roles) as exact data, so a
## save/reload keeps it and FOODFX can evaluate the dish from its stored state (spec 08 §4): the
## trait effects below apply only through that record, never because a raw ingredient happens to
## carry the same attribute.

const PATH := "res://data/cook_roles.json"

static var _doc: Dictionary = {}
static var _loaded := false

# ---------------------------------------------------------------- data

static func doc() -> Dictionary:
	if _loaded:
		return _doc
	_loaded = true
	if not FileAccess.file_exists(PATH):
		push_warning("[cookroles] %s is missing: every recipe keeps its category-only slots" % PATH)
		return _doc
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_doc = parsed as Dictionary
	else:
		push_error("[cookroles] %s is unreadable" % PATH)
	return _doc

static func roles() -> Dictionary:
	var r: Variant = doc().get("roles", {})
	return r as Dictionary if r is Dictionary else {}

static func role_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in roles():
		if not str(k).begins_with("_"):
			out.append(str(k))
	return out

static func has_role(id: String) -> bool:
	return roles().has(id) and not id.begins_with("_")

## The role a recipe slot declares, or "" for a recipe that predates roles.
static func slot_role(slot: Dictionary) -> String:
	var r := str(slot.get("role", ""))
	return r if has_role(r) else ""

## True when any slot of the recipe names a role: only such a recipe gets role checks and
## inheritance. Every earlier recipe is untouched (category-only slots).
static func is_roled(rec: Dictionary) -> bool:
	for slot: Variant in rec.get("slots", []):
		if slot is Dictionary and slot_role(slot as Dictionary) != "":
			return true
	return false

## The role's accepted item categories ([] + "any": true means "whatever the slot category allows").
static func role_categories(role: String) -> Array:
	var row: Variant = roles().get(role, {})
	if not row is Dictionary:
		return []
	var cats: Variant = (row as Dictionary).get("categories", [])
	return cats as Array if cats is Array else []

## Spec 08 §3: does this instance's role allow it in this slot? A slot without a role accepts as
## before. A role with no categories and "any": true (support) accepts anything.
static func role_accepts(slot: Dictionary, stack: ItemStack) -> bool:
	var role := slot_role(slot)
	if role == "" or stack == null:
		return true
	var row: Variant = roles().get(role, {})
	if row is Dictionary and bool((row as Dictionary).get("any", false)):
		return true
	var d := stack.def()
	if d == null:
		return false
	# A role may name categories it refuses even when another of its categories would accept them
	# (a spice herb is also a herb, so a main/topping list that contains "herb" would take it).
	var never: Variant = (row as Dictionary).get("exclude", []) if row is Dictionary else []
	for cat: Variant in (never as Array if never is Array else []):
		if d.has_category(StringName(str(cat))):
			return false
	for cat: Variant in role_categories(role):
		if d.has_category(StringName(str(cat))):
			return true
	return false

## The inheritance rule for one slot: the role's defaults, then the slot's own "inherit" block.
## {} when the recipe does not opt into inheritance at all (spec 08 §3: support recipes that do not).
static func inherit_rule(rec: Dictionary, slot: Dictionary) -> Dictionary:
	if not bool(rec.get("inherit", false)):
		return {}
	var defaults: Variant = (doc().get("inherit", {}) as Dictionary).get(slot_role(slot), {})
	var rule: Dictionary = (defaults as Dictionary).duplicate(true) if defaults is Dictionary else {}
	var own: Variant = slot.get("inherit", {})
	if own is Dictionary:
		for k: Variant in own:
			rule[str(k)] = (own as Dictionary)[k]
	return rule

static func trait_effect(key: String) -> Dictionary:
	var block: Variant = doc().get("trait_effects", {})
	if not block is Dictionary:
		return {}
	var row: Variant = (block as Dictionary).get(key, {})
	return row as Dictionary if row is Dictionary else {}

static func buff_row(id: String) -> Dictionary:
	var block: Variant = doc().get("buffs", {})
	if not block is Dictionary:
		return {}
	var row: Variant = (block as Dictionary).get(id, {})
	return row as Dictionary if row is Dictionary else {}

## Spec 08 §3/§4: a topping/sauce/spice/broth's own bonus, keyed by an item category it has.
## "" when the role has no bonus table or the ingredient matches none of its rows.
static func role_bonus(role: String, stack: ItemStack) -> String:
	var table: Variant = (doc().get("role_bonus", {}) as Dictionary).get(role, {})
	if not table is Dictionary or stack == null:
		return ""
	var d := stack.def()
	if d == null:
		return ""
	var rows: Dictionary = table as Dictionary
	var order: Array = role_categories(role)
	for cat: Variant in order:
		if rows.has(str(cat)) and d.has_category(StringName(str(cat))):
			return str(rows[str(cat)])
	return ""

# ---------------------------------------------------------------- inheritance

## Which keys of one instance may pass, and which were refused. `rule` is inherit_rule().
static func _split_traits(stack: ItemStack, rule: Dictionary) -> Dictionary:
	var keep := {}
	var drop := {}
	var traits := Inventory.traits(stack)
	var allow: Variant = rule.get("traits", false)
	for k: Variant in traits:
		var key := str(k)
		var allowed := false
		if allow is bool:
			allowed = bool(allow)
		elif allow is Array:
			allowed = key in (allow as Array).map(func(v: Variant) -> String: return str(v))
		if allowed and Crafting.is_rare_attribute(StringName(key)) and not bool(rule.get("rare", false)):
			allowed = false
		if allowed:
			keep[key] = traits[k]
		else:
			drop[key] = traits[k]
	return {"keep": keep, "drop": drop}

## What the dish takes from the plan's exact instances. `parts` are Crafting.plan_parts rows
## ({"slot","idx","count"}), `inv` the bag BEFORE the units are spent. Slots are processed in slot
## order and the first carrier of a key wins.
static func collect(rec: Dictionary, inv: Inventory, parts: Array[Dictionary]) -> Dictionary:
	var out := {
		"traits": {},
		"processed": [],
		"flags": [],
		"roles": [],       # one row per filled slot, the dish's inheritance record
		"buffs": [],       # role bonuses from the slots that grant one
	}
	if inv == null or not is_roled(rec):
		return out
	var slots: Array = rec.get("slots", [])
	var seen_slot := {}
	for part: Variant in parts:
		if not part is Dictionary:
			continue
		var row: Dictionary = part as Dictionary
		var i := int(row.get("slot", -1))
		if i < 0 or i >= slots.size() or not slots[i] is Dictionary:
			continue
		var slot: Dictionary = slots[i]
		var role := slot_role(slot)
		var idx := int(row.get("idx", -1))
		if idx < 0 or idx >= inv.slot_count or inv.slots[idx] == null:
			continue
		var stack: ItemStack = inv.slots[idx]
		# A recipe that does not inherit still gets its slots' role bonuses and its record (spec 08
		# §3: the bonus is a role's own, not the trait inheritance); only traits/history/flags are
		# gated by the recipe-level opt-in.
		var rule := inherit_rule(rec, slot)
		var keep := {}
		var drop := {}
		if not rule.is_empty() and role != "":
			var split := _split_traits(stack, rule)
			keep = split["keep"]
			drop = split["drop"]
		var traits: Dictionary = out["traits"]
		var dropped: Dictionary = {}
		for k: Variant in keep:
			if traits.has(k):
				dropped[k] = keep[k]  # a second carrier: first wins, this one is recorded as dropped
			else:
				traits[k] = keep[k]
		for k: Variant in drop:
			dropped[k] = drop[k]
		var hist: Array = []
		var proc: Variant = stack.attributes.get("processed", [])
		if bool(rule.get("processed", false)) and proc is Array:
			for step: Variant in proc:
				if str(step) not in hist:
					hist.append(str(step))
			for step: Variant in proc:
				if step not in out["processed"]:
					(out["processed"] as Array).append(step)
		var flags: Array = []
		if bool(rule.get("flags", false)):
			for f: StringName in stack.flags:
				if str(f) not in out["flags"]:
					(out["flags"] as Array).append(str(f))
		var bonus := role_bonus(role, stack)
		if bonus != "" and bonus not in out["buffs"]:
			(out["buffs"] as Array).append(bonus)
		# One record per filled slot (a slot filled by two stacks of the same def records each unit
		# it actually read, keyed by its exact instance value).
		var key := "%d/%s/%s" % [i, str(stack.def_id), str(stack.level)]
		seen_slot[key] = true
		(out["roles"] as Array).append({
			"slot": i,
			"role": role,
			"def_id": str(stack.def_id),
			"level": stack.level,
			"traits": keep.duplicate(true),
			"dropped": dropped.duplicate(true),
			"processed": hist,
			"flags": flags,
			"bonus": bonus,
		})
	return out

## Give the built dish exactly what its ingredients' rules allow. A roled recipe does NOT keep the
## primary's wholesale attribute copy Crafting.build_output makes for every other recipe: what is
## not inherited must not appear on the dish (spec 08 §3's "support recipes that do not inherit").
## Bookkeeping (level, quality, flawless bonus, the recipe's own food_buff) is kept.
static func apply_to_output(out: ItemStack, rec: Dictionary, got: Dictionary) -> ItemStack:
	if out == null or not is_roled(rec) or got.is_empty():
		return out
	var d := out.def()
	var defaults: Dictionary = d.default_attributes if d else {}
	for key: Variant in out.attributes.keys():
		var k := str(key)
		if k in ItemStack.MERGE_IGNORED_ATTRS or k in Inventory.PLAIN_ATTRS:
			continue
		if defaults.has(k) or k in ["quality", "flawless_bonus", "food_buff", "temperature"]:
			continue
		out.attributes.erase(key)
	for k: Variant in (got["traits"] as Dictionary):
		out.attributes[k] = (got["traits"] as Dictionary)[k]
	if not (got["processed"] as Array).is_empty():
		out.attributes["processed"] = (got["processed"] as Array).duplicate()
	else:
		out.attributes.erase("processed")
	# Poison survives cooking (PRD §9.3 "MAY keep") whatever the slot flags say; other flags follow
	# the rules. A flag the rules refused that the base craft copied from the primary is removed.
	var keep_flags: Array = (got["flags"] as Array).duplicate()
	if &"poisoned" in out.flags and "poisoned" not in keep_flags:
		keep_flags.append("poisoned")
	out.flags.clear()
	for f: Variant in keep_flags:
		out.set_flag(StringName(str(f)), true)
	out.attributes["cooked_roles"] = got["roles"]
	if (got["buffs"] as Array).is_empty():
		out.attributes.erase("cooked_buffs")
	else:
		out.attributes["cooked_buffs"] = (got["buffs"] as Array).duplicate()
	return out

# ---------------------------------------------------------------- the dish's stored record

## FOODFX transforms contributed by the traits this dish INHERITED (spec 08 §4: benefits come from
## the prepared item's stored state). Empty for an ingredient that merely carries the attribute raw.
static func effect_rows(stack: ItemStack) -> Array:
	var out: Array = []
	if stack == null:
		return out
	var roles: Variant = stack.attributes.get("cooked_roles", [])
	if not roles is Array:
		return out
	for entry: Variant in roles:
		if not entry is Dictionary:
			continue
		var traits: Variant = (entry as Dictionary).get("traits", {})
		if not traits is Dictionary:
			continue
		for key: Variant in traits:
			var def := trait_effect(str(key))
			var rows: Variant = def.get("effects", [])
			if not rows is Array:
				continue
			var level := float((traits as Dictionary)[key]) if ((traits as Dictionary)[key] is int or (traits as Dictionary)[key] is float) else 1.0
			for row: Variant in rows:
				if not row is Dictionary:
					continue
				var r: Dictionary = (row as Dictionary).duplicate(true)
				if bool(r.get("per_level", false)):
					var v := float(r.get("value", 0.0))
					# A multiplier's per-level share is its bonus, never the whole factor: a lv3
					# x1.15 trait is x1.45, not x3.45.
					r["value"] = 1.0 + (v - 1.0) * level if str(r.get("op", "")) == "mult" else v * level
				r["source"] = "cook_role"
				r["trait"] = str(key)
				out.append(r)
	return out

## FOODFX buff bundles granted by role bonuses the dish recorded (a topping's own bonus).
static func buff_rows(stack: ItemStack) -> Array:
	var out: Array = []
	if stack == null:
		return out
	var ids: Variant = stack.attributes.get("cooked_buffs", [])
	if not ids is Array:
		return out
	for id: Variant in ids:
		var row := buff_row(str(id)).duplicate(true)
		if row.is_empty():
			continue
		row["id"] = str(id)
		out.append(row)
	return out

## The dish's human-readable inheritance, for the inspector and the report: inherited and discarded.
static func summary(stack: ItemStack) -> Array[String]:
	var out: Array[String] = []
	if stack == null:
		return out
	var roles: Variant = stack.attributes.get("cooked_roles", [])
	if not roles is Array:
		return out
	for entry: Variant in roles:
		if not entry is Dictionary:
			continue
		var row: Dictionary = entry as Dictionary
		var got: Dictionary = row.get("traits", {}) if row.get("traits", {}) is Dictionary else {}
		var lost: Dictionary = row.get("dropped", {}) if row.get("dropped", {}) is Dictionary else {}
		if got.is_empty() and lost.is_empty() and str(row.get("bonus", "")) == "":
			continue
		var bits: PackedStringArray = []
		for k: Variant in got:
			bits.append("%s %s" % [str(k).replace("_", " "), str(got[k])])
		for k: Variant in lost:
			bits.append("%s %s (kept out)" % [str(k).replace("_", " "), str(lost[k])])
		if str(row.get("bonus", "")) != "":
			bits.append(str(row["bonus"]))
		out.append("%s %s: %s" % [str(row.get("role", "")).capitalize(), str(row.get("def_id", "")), ", ".join(bits)])
	return out
