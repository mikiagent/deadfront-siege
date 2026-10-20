class_name ItemStack
extends RefCounted
## One inventory occupant. Merges only when def, level, attributes, flags and durability match (D7).
## Non-fungible stacks carry an instance identity (contracts v2 §0.5) and never merge.

var def_id: StringName = &""
var count: int = 1
var level: int = 1
var process_count: int = 0
var attributes: Dictionary = {}
var flags: Array[StringName] = []
var durability: int = 0
var max_durability: int = 0
## Instance identity: empty for fungible stacks. The server issues "i<seq>"; offline mints "l<hex>".
var uid: String = ""
var origin: String = ""  # one of ORIGINS
const ORIGINS := ["gather", "loot", "craft", "tame", "breed", "settlers", "objective", "market"]
var creator: String = ""
var created_at: int = 0
## Where a stack came from does not make it a different good (inv-01): climate never splits stacks.
const MERGE_IGNORED_ATTRS := ["climate"]

func duplicate_stack() -> ItemStack:
	var s := ItemStack.new()
	s.def_id = def_id
	s.count = count
	s.level = level
	s.process_count = process_count
	s.attributes = attributes.duplicate(true)
	s.flags = flags.duplicate()
	s.durability = durability
	s.max_durability = max_durability
	s.uid = uid
	s.origin = origin
	s.creator = creator
	s.created_at = created_at
	return s

func def() -> ItemDef:
	return Data.item(def_id)

func apply_level_stats() -> void:
	var d := def()
	if d == null:
		return
	if d.max_durability > 0:
		max_durability = maxi(1, int(round(float(d.max_durability) * stat_multiplier())))
		durability = max_durability

## Level and material tier both scale finished gear (ladder-02, level-01); item_def's
## stats_per_level stays for data that predates this rule.
func stat_multiplier() -> float:
	return ProgressionScaling.stat_multiplier(level, material_tier())

func scaled_damage() -> float:
	var d := def()
	return d.damage * stat_multiplier() if d else 0.0

func scaled_armor() -> float:
	var d := def()
	return d.armor_value * stat_multiplier() if d else 0.0

func scaled_food_energy() -> float:
	var d := def()
	return d.food_energy_at(level) if d else 0.0

func material_tier() -> StringName:
	return ProgressionScaling.material_tier(def_id, attributes)

func gather_power() -> float:
	return ProgressionScaling.tool_power(level, material_tier())

func is_fungible() -> bool:
	var d := def()
	return d == null or d.stack_max > 1

## Give this stack an instance identity. Pass the server's uid when one exists.
func stamp_identity(p_origin: String, p_creator: String = "", p_uid: String = "") -> void:
	uid = p_uid if p_uid != "" else "l" + Crypto.new().generate_random_bytes(8).hex_encode()
	origin = p_origin
	creator = p_creator
	created_at = int(Time.get_unix_time_from_system())

## After a split the taken units are a new instance: keeping the source uid gave both halves the
## same identity (probe: '[probe] split shares uid=true'), which vault and market key on.
func remint_uid() -> void:
	if uid == "":
		return
	uid = "l" + Crypto.new().generate_random_bytes(8).hex_encode()

func slot_span() -> int:
	var d := def()
	return d.slot_span if d else 1

func is_locked() -> bool:
	return &"locked" in flags

func is_broken() -> bool:
	return max_durability > 0 and durability <= 0

func is_unstable() -> bool:
	return &"unstable" in flags

func set_flag(flag: StringName, on: bool) -> void:
	if on:
		if flag not in flags:
			flags.append(flag)
	else:
		flags.erase(flag)

func tint_color() -> Color:
	var t := str(attributes.get("tint", ""))
	if t.begins_with("#") and t.length() >= 7:
		return Color(t)
	return Color.WHITE

func wear(amount: int) -> bool:
	if max_durability <= 0:
		return true
	durability = maxi(0, durability - amount)
	return durability > 0

func can_merge_with(other: ItemStack) -> bool:
	if other == null:
		return false
	if uid != "" or other.uid != "":
		return false
	if def_id != other.def_id:
		return false
	if level != other.level:
		return false
	if process_count != other.process_count:
		return false
	if durability != other.durability or max_durability != other.max_durability:
		return false
	if not _attrs_equal(attributes, other.attributes):
		return false
	return _flags_equal(flags, other.flags)

func take_into(other: ItemStack) -> int:
	if not can_merge_with(other):
		return count
	var d := def()
	var cap: int = d.stack_max if d else 1
	var room: int = maxi(0, cap - other.count)
	var moved: int = mini(count, room)
	other.count += moved
	count -= moved
	return count

func tooltip() -> String:
	var d := def()
	var title := d.display_name if d else str(def_id)
	var lines: PackedStringArray = ["%s x%d" % [title, count], "lv %d  process %d" % [level, process_count]]
	if d and d.place_as != &"":
		lines.append("footprint %dx%d" % [d.footprint.x, d.footprint.y])
	if d and d.has_category(&"tool"):
		lines.append("%s tier · %.2fx gather power" % [str(material_tier()).capitalize(), gather_power()])
	if max_durability > 0:
		lines.append("dur %d/%d%s" % [durability, max_durability, " BROKEN" if is_broken() else ""])
	var dmg := scaled_damage()
	if dmg > 0.0:
		lines.append("dmg %.1f" % dmg)
	var armor := scaled_armor()
	if armor > 0.0:
		lines.append("armor %.1f" % armor)
	if d and d.health_bonus > 0.0:
		lines.append("max health +%.1f (does not heal)" % d.health_bonus_at(level))
	if Food.is_food(self):
		lines.append("energy %.1f" % Food.energy_restore(self))
		if Food.is_raw(self):
			lines.append("RAW")
		if Food.is_poisoned(self):
			lines.append("POISONED")
		var buffs := Food.buff_ids(self)
		if not buffs.is_empty():
			var bn: PackedStringArray = []
			for b in buffs:
				bn.append(str(b))
			lines.append("buffs %s" % ", ".join(bn))
	elif scaled_food_energy() != 0.0:
		lines.append("energy %.1f" % scaled_food_energy())
	if not attributes.is_empty():
		lines.append("attr %s" % str(attributes))
	if not flags.is_empty():
		var flag_s: PackedStringArray = []
		for f in flags:
			flag_s.append(str(f))
		lines.append("flags %s" % ", ".join(flag_s))
	return "\n".join(lines)

func to_dict() -> Dictionary:
	var flag_s: Array = []
	for f in flags:
		flag_s.append(str(f))
	var out := {
		"id": str(def_id),
		"count": count,
		"level": level,
		"process_count": process_count,
		"attributes": attributes.duplicate(true),
		"flags": flag_s,
		"durability": durability,
		"max_durability": max_durability,
	}
	# Fungible rows keep the old save shape byte for byte.
	if uid != "":
		out["uid"] = uid
		out["origin"] = origin
		out["creator"] = creator
		out["created_at"] = created_at
	return out

static func from_dict(d: Dictionary) -> ItemStack:
	var s := make(StringName(str(d.get("id", ""))), int(d.get("count", 1)), d.get("attributes", {}), int(d.get("level", 1)))
	s.process_count = int(d.get("process_count", 0))
	s.durability = int(d.get("durability", s.durability))
	s.max_durability = int(d.get("max_durability", s.max_durability))
	s.flags.clear()
	var raw: Variant = d.get("flags", [])
	if raw is Array:
		for f in raw:
			s.flags.append(StringName(str(f)))
	# Provenance is trusted later by vault and market: null becomes "", unknown origins are blanked,
	# a uid must be a string in the minted format, and a timestamp is clamped to now + slack.
	var u: Variant = d.get("uid")
	s.uid = u if u is String and UID_RE.search(u) != null else ""
	var o := _text(d.get("origin"))
	s.origin = o if o in ORIGINS else ""
	s.creator = _text(d.get("creator"))
	var t: Variant = d.get("created_at", 0)
	var stamp := int(t) if (t is int or t is float) and is_finite(float(t)) else 0
	s.created_at = clampi(stamp, 0, int(Time.get_unix_time_from_system()) + CREATED_AT_SLACK_S)
	return s

static var UID_RE := RegEx.create_from_string("^[il][0-9a-f]+\\z") # \z, not $: $ also matches before a final newline
## A save cannot claim to have been made in the future: clock skew plus a day of slack.
const CREATED_AT_SLACK_S := 86400

static func _text(v: Variant) -> String:
	return "" if v == null else str(v)

static func make(id: StringName, amount: int = 1, attrs: Dictionary = {}, lvl: int = -1) -> ItemStack:
	var s := ItemStack.new()
	s.def_id = id
	s.count = amount
	# Negative means "use the catalog base level". An explicit level 1 must stay level 1;
	# the old lvl == 1 sentinel silently promoted starter-island resources to base levels.
	s.level = lvl
	var d := Data.item(id) if Data else null
	if d:
		s.attributes = d.default_attributes.duplicate(true)
		s.level = ProgressionScaling.resolved_item_level(lvl, d.base_level)
	for k in attrs:
		s.attributes[k] = attrs[k]
	# After attrs: durability depends on the material tier they carry.
	s.apply_level_stats()
	return s

static func _attrs_equal(a: Dictionary, b: Dictionary) -> bool:
	for k in b:
		if not a.has(k) and str(k) not in MERGE_IGNORED_ATTRS:
			return false
	for k in a:
		if str(k) in MERGE_IGNORED_ATTRS:
			continue
		if not b.has(k):
			return false
		# JSON restores integer attributes as floats. Equal numeric quality must
		# still merge with a newly harvested integer-stamped stack.
		if (a[k] is int or a[k] is float) and (b[k] is int or b[k] is float):
			if float(a[k]) != float(b[k]): return false
			continue
		if (a[k] is int or a[k] is float) != (b[k] is int or b[k] is float): return false
		if str(a[k]) != str(b[k]):
			return false
	return true

static func _flags_equal(a: Array[StringName], b: Array[StringName]) -> bool:
	if a.size() != b.size():
		return false
	var aa := a.duplicate()
	var bb := b.duplicate()
	aa.sort()
	bb.sort()
	for i in aa.size():
		if aa[i] != bb[i]:
			return false
	return true
