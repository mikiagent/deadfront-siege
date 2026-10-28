class_name FoodEffects
extends RefCounted
## Spec 32 §8/§13: the evaluated effect bundle of one *instance*.
##
##     base definition + item level + inherited ingredient traits + preparation methods
##     + seasonings/recipe output rules  =  evaluated food effect bundle
##
## The evaluator runs once, inside the consumption transaction (spec 32 §11 step 2/5): a preview and
## the eat both call evaluate(), so what the panel shows is what is paid. Everything it reads is data
## (data/foods.json) or the instance's own state (level, attributes, flags, processing history); no
## balance number is written here. Reconstructed example values in foods.json keep their provenance
## tag and are never presented as original server constants (spec 32 opening warning, §13/§15).
##
## Effects are per-field transforms in listed order (spec 32 §8): add/subtract then multiply, or a
## set/remove. Unknown fields, unknown buff groups, unknown stat keys and two buffs of one exclusive
## group inside one bundle are reported in the bundle's "warnings" instead of being applied silently.

const PATH := "res://data/foods.json"

static var _doc: Dictionary = {}
static var _loaded := false

# ---------------------------------------------------------------- data

static func doc() -> Dictionary:
	if _loaded:
		return _doc
	_loaded = true
	if not FileAccess.file_exists(PATH):
		push_warning("[foodfx] %s is missing: every food keeps the old Energy-only behaviour" % PATH)
		return _doc
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_doc = parsed as Dictionary
	else:
		push_error("[foodfx] %s is unreadable" % PATH)
	return _doc

## The data entry for an item id, or {} when the item has no bundle (Energy-only food).
static func entry_for(def_id: StringName) -> Dictionary:
	var foods: Variant = doc().get("foods", {})
	if not foods is Dictionary:
		return {}
	var row: Variant = (foods as Dictionary).get(str(def_id))
	return row as Dictionary if row is Dictionary else {}

## The status a bad raw bite applies (catalog "Stomach Pain" by default, "Poisoned" for a mushroom).
static func risk_status(entry: Dictionary) -> StringName:
	var id := str(entry.get("risk_status", ""))
	return StringName(id) if id != "" else &"stomachache"

static func has_bundle(stack: ItemStack) -> bool:
	return stack != null and not entry_for(stack.def_id).is_empty()

static func defaults() -> Dictionary:
	var d: Variant = doc().get("defaults", {})
	return d as Dictionary if d is Dictionary else {}

static func cap_for(field: String) -> float:
	var caps: Variant = defaults().get("caps", {})
	if caps is Dictionary and (caps as Dictionary).has(field):
		return float((caps as Dictionary)[field])
	return INF

static func buff_groups() -> Dictionary:
	var g: Variant = doc().get("buff_groups", {})
	return g as Dictionary if g is Dictionary else {}

static func stat_keys() -> Dictionary:
	var s: Variant = doc().get("stat_keys", {})
	return s as Dictionary if s is Dictionary else {}

## Spec 32 §3: only the keys with a real gameplay consumer are wired; the rest are carried (the panel
## lists them) and change no check. A profession ability maps onto this build's one craft ability stat.
static func player_stat(stat: String) -> String:
	var map: Variant = stat_keys().get("_player_map", {})
	if map is Dictionary and (map as Dictionary).has(stat):
		return str((map as Dictionary)[stat])
	if stat == "max_fatigue" or stat == "max_energy":
		return stat
	var row: Variant = stat_keys().get(stat, {})
	var channel := str((row as Dictionary).get("channel", "")) if row is Dictionary else ""
	# Attributes and combat stats have no shared player stat in this build (the PRD's attribute
	# system is not implemented), so they are carried and displayed but move no number yet.
	return "" if channel == "attribute" or channel == "combat" else ""

## Spec 32 §2's split, as its own function so the rule is testable on its own:
##   instant = latent x clamp(ratio, 0, 1);  digested = latent - instant
static func split(latent: float, ratio: float) -> Dictionary:
	var r := clampf(ratio, 0.0, 1.0)
	var instant := latent * r
	return {"instant": instant, "digested": latent - instant}

# ---------------------------------------------------------------- the instance

## The tags a prepared instance carries: in-place steps, flags, and truthy inherited attributes.
static func tags_of(stack: ItemStack) -> Dictionary:
	var out := {}
	var hist: Variant = stack.attributes.get("processed", [])
	if hist is Array:
		for step: Variant in hist:
			out[str(step)] = true
	for f: StringName in stack.flags:
		out[str(f)] = true
	for k: Variant in stack.attributes:
		var key := str(k)
		if key == "processed":
			continue
		var v: Variant = stack.attributes[k]
		if v is bool:
			if bool(v):
				out[key] = true
		elif v is float or v is int:
			if float(v) != 0.0:
				out[key] = true
	for c: StringName in (stack.def().categories if stack.def() else []):
		out[str(c)] = true
	return out

## Ready-to-eat temperature condition (spec 32 §9): a carrying instance is "hot"/"cold".
static func temperature_of(stack: ItemStack, entry: Dictionary) -> String:
	var t := str(stack.attributes.get("temperature", entry.get("temperature", "")))
	return t if t in ["hot", "cold"] else ""

# ---------------------------------------------------------------- evaluate

## The full bundle for one instance. `ctx` may carry:
##   "latent" (float)          the meal's own Energy before the split, when the caller already has it
##   "taste_memory" (Dictionary) the survivor's flavour memory (Taste.score reads/updates it)
##   "now" (float)             unix seconds for the taste memory
##   "remember_taste" (bool)   record this flavour (only the authoritative transaction does)
static func evaluate(stack: ItemStack, ctx: Dictionary = {}) -> Dictionary:
	var out := {
		"def_id": "" if stack == null else str(stack.def_id),
		"display_name": "",
		"provenance": "",
		"channels": [],
		"latent_energy": 0.0,
		"instant_energy": 0.0,
		"digested_energy": 0.0,
		"digest_seconds": float(defaults().get("digest_seconds", 300.0)),
		"eat_seconds": float(defaults().get("eat_seconds", 3.0)),
		"full_seconds": float(defaults().get("full_seconds", 10.0)),
		"fullness": 0.0,
		"thirst": 0.0,
		"health": 0.0,
		"life": 0.0,
		"fatigue": 0.0,
		"max_energy": 0.0,
		"max_fatigue": 0.0,
		"stats": {},          # carried stat rows: stat -> {add, sub, mult, set}
		"buffs": [],
		"statuses": [],
		"taste": {},
		"temperature": "",
		"raw_risk": {"raw": false, "poison_chance": 0.0, "tastes_bad_chance": 0.0},
		"transforms": [],
		"warnings": [],
	}
	if stack == null:
		return out
	var d := stack.def()
	var entry := entry_for(stack.def_id)
	var tags := tags_of(stack)
	out["display_name"] = str(entry.get("display_name", d.display_name if d else str(stack.def_id)))
	out["provenance"] = str(entry.get("provenance", ""))
	out["channels"] = (entry.get("channels", []) as Array).duplicate()
	var warnings: Array = out["warnings"]
	for ch: Variant in out["channels"]:
		if not str(ch) in (doc().get("channels", []) as Array):
			warnings.append("unknown channel %s" % str(ch))
	# Temperature and the raw-food risk come from the instance, not only from the bundle.
	out["temperature"] = temperature_of(stack, entry)
	var raw := bool(entry.get("raw", false)) or Food.is_raw(stack)
	out["raw_risk"] = {
		"raw": raw,
		"poison_chance": float(entry.get("poison_chance", d.poison_chance if d else 0.0)),
		"tastes_bad_chance": float(entry.get("tastes_bad_chance", d.tastes_bad_chance if d else 0.0)),
		# FOODCAT: the catalog names what a bad raw bite does ("Stomach Pain Lv1", "Poisoned Lv4").
		"status": risk_status(entry),
		"level": int(entry.get("risk_level", 1)),
	}
	out["temperature_level"] = int(entry.get("temperature_level", 1))
	# --- Energy: latent -> instant + digested (spec 32 §2).
	var latent := float(ctx.get("latent", Food.energy_restore(stack)))
	# A food with no bundle keeps the behaviour it had before spec 32: its whole Energy at the
	# commit. A bundled food without an explicit ratio uses foods.json's default. # ASSUMPTION.
	var fallback_ratio := 1.0 if entry.is_empty() else float(defaults().get("instant_release_ratio", 0.5))
	var ratio := float(entry.get("energy", {}).get("instant_release_ratio", fallback_ratio))
	var digest := float(entry.get("energy", {}).get("digest_seconds", defaults().get("digest_seconds", 300.0)))
	var energy_fields := {"instant_release_ratio": ratio, "digest_seconds": digest, "latent": latent}
	# COOKROLES (spec 08 §4): a dish that INHERITED a trait through its recipe slots carries that
	# trait's effect rows; the same attribute on a raw ingredient does nothing here.
	var trs: Array = transforms_for(entry, tags)
	trs.append_array(CookRoles.effect_rows(stack))
	for tr: Variant in trs:
		var row: Dictionary = tr as Dictionary
		var field := str(row.get("field", ""))
		if not energy_fields.has(field):
			continue
		energy_fields[field] = apply_op(field, float(energy_fields[field]), row)
		out["transforms"].append(row)
	ratio = clampf(float(energy_fields["instant_release_ratio"]), 0.0, 1.0)
	latent = clampf(float(energy_fields["latent"]), -cap_for("latent"), cap_for("latent"))
	var parts := split(latent, ratio)
	out["latent_energy"] = latent
	out["instant_energy"] = float(parts["instant"])
	out["digested_energy"] = float(parts["digested"])
	out["digest_seconds"] = maxf(0.0, float(energy_fields["digest_seconds"]))
	out["eat_seconds"] = maxf(0.5, float(entry.get("eat_seconds", defaults().get("eat_seconds", 3.0))))
	out["full_seconds"] = maxf(1.0, float(entry.get("full_seconds", defaults().get("full_seconds", 10.0))))
	# --- Plain channels (Fullness, Thirst, Health, Life, Fatigue, capacity deltas).
	for field in ["fullness", "thirst", "health", "life", "fatigue", "max_energy", "max_fatigue"]:
		var v := float(entry.get(field, 0.0))
		for tr: Variant in trs:
			var row: Dictionary = tr as Dictionary
			if str(row.get("field", "")) != field:
				continue
			v = apply_op(field, v, row)
			out["transforms"].append(row)
		out[field] = clampf(v, -cap_for(field), cap_for(field))
	# --- Buffs, grouped (spec 32 §4): one per exclusive group per bundle.
	var groups := buff_groups()
	var taken := {}
	var buffs: Array = out["buffs"]
	# A roled recipe's topping/sauce/spice/broth bonus (spec 08 §3): its own bundle rows, evaluated by
	# the same group rules as the dish's own buffs.
	# The player's own topping first: it is what they chose to add, and an exclusive group keeps the
	# first row.
	var bundled: Array = CookRoles.buff_rows(stack)
	bundled.append_array((entry.get("buffs", []) as Array).duplicate())
	for row: Variant in bundled:
		if not row is Dictionary:
			continue
		var b: Dictionary = (row as Dictionary).duplicate(true)
		var gid := str(b.get("group", "enhanced_ability"))
		if not groups.has(gid):
			warnings.append("buff %s names unknown group %s" % [str(b.get("id", "?")), gid])
			continue
		if taken.has(gid):
			warnings.append("buff %s conflicts with %s in group %s (kept the first)" % [str(b.get("id", "?")), taken[gid], gid])
			continue
		taken[gid] = str(b.get("id", "?"))
		if float(b.get("duration", 0.0)) <= 0.0:
			warnings.append("buff %s has no duration" % str(b.get("id", "?")))
			continue
		var stats: Dictionary = {}
		var raw_stats: Variant = b.get("stats", {})
		if raw_stats is Dictionary:
			for key: Variant in raw_stats:
				var stat := str(key)
				if not stat_keys().has(stat):
					warnings.append("buff %s names unknown stat %s" % [str(b.get("id", "?")), stat])
					continue
				var ops: Dictionary = (raw_stats as Dictionary)[key] as Dictionary
				if cap_for(stat) < INF:
					for op in ["add", "sub"]:
						if ops.has(op):
							ops[op] = clampf(float(ops[op]), -cap_for(stat), cap_for(stat))
				stats[stat] = ops
		b["stats"] = stats
		b["group"] = gid
		b["group_name"] = str((groups[gid] as Dictionary).get("display_name", gid))
		b["player_stats"] = _player_stats(stats)
		buffs.append(b)
	# --- Statuses (negative effects and medicine: Stomach Pain, Caffeinated...).
	for row: Variant in entry.get("statuses", []):
		if row is Dictionary:
			out["statuses"].append({
				"id": str((row as Dictionary).get("id", "")),
				"duration": float((row as Dictionary).get("duration", 0.0)),
				"level": int((row as Dictionary).get("level", 1)),
			})
	# --- Taste (spec 32 §7), scored now so the panel shows the same grade the eat will use.
	var mem: Variant = ctx.get("taste_memory", {})
	var memory: Dictionary = mem as Dictionary if mem is Dictionary else {}
	out["taste"] = Taste.score(doc(), entry, memory, float(ctx.get("now", -1.0)), bool(ctx.get("remember_taste", false)))
	return out

## Buff stat rows in the shape Player.food_buffs (FoodBuffState) already reads: stat -> add/mult.
static func _player_stats(stats: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in stats:
		var pstat := player_stat(str(key))
		if pstat == "":
			continue
		var ops: Dictionary = stats[key]
		var row: Dictionary = out.get(pstat, {})
		if ops.has("add"):
			row["add"] = float(row.get("add", 0.0)) + float(ops["add"])
		if ops.has("sub"):
			row["add"] = float(row.get("add", 0.0)) - float(ops["sub"])
		if ops.has("mult"):
			row["mult"] = float(row.get("mult", 1.0)) * float(ops["mult"])
		if ops.has("set"):
			row["add"] = float(ops["set"]) - float(row.get("base", 0.0))
		out[pstat] = row
	return out

# ---------------------------------------------------------------- transforms

## Per-field transforms from the bundle's "transforms" list plus the document's shared "transforms"
## list, each gated by "tag" (a processing step, flag or inherited attribute of this instance).
static func transforms_for(entry: Dictionary, tags: Dictionary) -> Array:
	var out: Array = []
	for list: Variant in [doc().get("transforms", []), entry.get("transforms", [])]:
		if not list is Array:
			continue
		for tr: Variant in list:
			if not tr is Dictionary:
				continue
			var row: Dictionary = tr as Dictionary
			var tag := str(row.get("tag", ""))
			if tag != "" and not tags.has(tag):
				continue
			out.append(row)
	return out

## One operation (spec 32 §8): set, remove, add, sub, mult. Unknown ops are ignored (validated).
static func apply_op(field: String, value: float, row: Dictionary) -> float:
	var amount := float(row.get("value", 0.0))
	match str(row.get("op", "add")):
		"add":
			return value + amount
		"sub":
			return value - amount
		"mult":
			return value * amount
		"set":
			return amount
		"remove":
			return 0.0 if field != "instant_release_ratio" else value
	return value

# ---------------------------------------------------------------- preview

## The panel's projection for an instance, before the player commits (spec 32 §12). Same evaluation
## as the eat, without the transaction's side effects.
static func preview(stack: ItemStack, player: Player = null) -> Dictionary:
	var ctx := {}
	if player != null:
		var slots := BuffSlots.of(player)
		if slots != null:
			ctx["taste_memory"] = slots.taste_memory
	return evaluate(stack, ctx)
