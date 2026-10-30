class_name AutoAbility
extends RefCounted
## AUTO-ABILITY (owner: "an auto-ability button that uses the player's most powerful ability off
## cooldown and prioritizes that over basic attacks", on by default). Data-driven candidate list in
## data/combat_tuning.json "auto_ability".abilities; the picker ranks by expected damage per cast
## (the row's damage x the weapon's damage — the rows are flat ability damage today, so the rank is
## the row damage), tie-break the longer cooldown. # ASSUMPTION: only Tackle and Kick are
## auto-castable; Roll (a dodge) and Net (a capture tool) stay manual unless a row marks auto=true.

const PATH := "res://data/combat_tuning.json"

## One castable ability row: id, damage, cooldown, energy, auto (data/combat_tuning.json).
static func rows() -> Array:
	var sect: Dictionary = CombatTuning.section("auto_ability")
	var out: Array = []
	for row: Variant in sect.get("abilities", []):
		if row is Dictionary and bool(row.get("auto", false)):
			out.append(row)
	return out

## The best ready ability for this hunt: highest damage, tie-break longer cooldown, and it must be
## off cooldown, affordable (stamina) and in body-edge reach. "" when nothing qualifies.
static func pick(h: Hunt) -> StringName:
	if h == null or h.player == null or h.target == null:
		return &""
	var best: Dictionary = {}
	var best_key := Vector2(-1.0, -1.0)  # damage, then cooldown
	for row: Variant in rows():
		var d := row as Dictionary
		var id := StringName(str(d.get("id", "")))
		if h.cooldown_left(id) > 0.0:
			continue
		if not h.player.vitals.spendable_energy(float(d.get("energy", 0.0))):
			continue
		if not _in_reach(h, d):
			continue
		# HOLD keeps her still, so a push (Kick) would shove the target out of her reach.
		# ASSUMPTION (HOLDKICK): under HOLD the auto-cast skips push abilities; the manual press still works.
		if h.hold and float(CombatTuning.section(str(d.get("tune", id))).get("push_m", 0.0)) > 0.0:
			continue
		var key := Vector2(float(d.get("damage", 0.0)), float(d.get("cooldown", 0.0)))
		if key.x > best_key.x or (is_equal_approx(key.x, best_key.x) and key.y > best_key.y):
			best = d
			best_key = key
	return StringName(str(best.get("id", ""))) if not best.is_empty() else &""

## Body-edge reach, shared with the manual cast, but silent: an auto-cast never spams the notice.
static func _in_reach(h: Hunt, d: Dictionary) -> bool:
	var tune := CombatTuning.section(str(d.get("tune", d.get("id", ""))))
	if MeleeQuery.surface_gap(h.player, h.target) > float(tune.get("surface_reach_m", 2.4)):
		return false
	return MeleeQuery.clear(h.player, h.target)

## Cast the picked ability through CombatTactics (the same damage, stagger, lock and cooldown the
## manual press runs). True = cast this frame, so the auto-attack skips its basic swing.
static func try_cast(h: Hunt) -> bool:
	if h == null or not h.auto_ability or h.target == null:
		return false
	if not h.can_start_tactic():
		return false
	var id := pick(h)
	if id == &"":
		return false
	# The manual casts say() their refusals; here every gate already passed, so the cast lands.
	if id == &"tackle":
		CombatTactics.tackle(h)
		return true
	if id == &"kick":
		CombatTactics.kick(h)
		return true
	return false  # ASSUMPTION: an unknown row id casts nothing (the basic attack stays in charge)
