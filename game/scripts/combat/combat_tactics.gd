class_name CombatTactics
extends RefCounted
## Body Tackle and Kick, pulled out of Hunt so it stays an auto-attack driver. The cooldowns
## and lock stay on Hunt because the HUD reads them there.

## Shared gate for Tackle and Kick: reach is measured body edge to body edge, so a T. rex at
## contact range is in reach (its centre is 3+ m away), and a wall between refuses the move.
static func reach_ok(h: Hunt, verb: String, tune: Dictionary) -> bool:
	if MeleeQuery.surface_gap(h.player, h.target) > float(tune.get("surface_reach_m", 2.4)):
		h.say("Too far to %s: get closer." % verb)
		return false
	if not MeleeQuery.clear(h.player, h.target):
		h.say("Something is in the way.")
		return false
	return true

## HITBOXES: step in up to the move's lunge_max_m (never into it), face it, then the move's part (feet for
## the kick, shoulders and chest for the tackle) must sweep through its hurtboxes. A whiff still costs the
## stamina and the cooldown. {} = missed; else the hit (part, region) or {"part": &""} for a body without a rig.
static func _step_and_strike(h: Hunt, move: StringName, lunge_max_m: float) -> Dictionary:
	var player := h.player
	var target := h.target
	player.clear_nav()
	var to := target.global_position - player.global_position
	to.y = 0.0
	var lunge_distance := minf(lunge_max_m, maxf(0.0, MeleeQuery.surface_gap(player, target) - 0.1))
	if lunge_distance > 0.0 and to.length_squared() > 0.0001:
		# Move the body now. The attack animation marks the player busy and the normal player
		# loop zeroes velocity, so a velocity-only lunge never actually happened.
		player.move_and_collide(to.normalized() * lunge_distance)
	player.face_world(target.global_position)
	if not Hitbox.applies(player, target):
		return {"part": &""}
	var hit := Hitbox.strike(player, move, target)
	if hit.is_empty():
		CombatAvoid.avoided(target, player, &"miss")
	else:
		Hitbox.mark(target, hit)
	return hit

## Body tackle: lunge into the target, groggy (then knockdown on the next hit), 6 damage.
static func tackle(h: Hunt) -> void:
	if h.target == null:
		h.say("Pick a target to tackle.")
		return
	if not h.can_start_tactic():
		h.say("Can't tackle right now.")
		return
	if h.cooldown_left(&"tackle") > 0.0:
		h.say("Tackle ready in %.0fs" % ceil(h.cooldown_left(&"tackle")))
		return
	var tune := CombatTuning.section("tackle")
	if not reach_ok(h, "tackle", tune):
		return
	var player := h.player
	var target := h.target
	if not player.vitals.spend_energy(float(tune.get("stamina", 15.0))):
		h.say("Out of stamina.")
		return
	h.last_auto_cast = &"tackle"
	if _step_and_strike(h, &"tackle", float(tune.get("lunge_max_m", 1.0))).is_empty():
		h.commit_tactic(&"tackle", float(tune.get("cooldown", 8.0)), float(tune.get("lock", 0.55)))
		player.play_tactic(&"tackle", true)
		print("[combat] body tackle %s missed: no hurtbox in the way" % target.def.id)
		return
	target.statuses.apply(&"groggy", player)
	target.next_hit_kind = &"strong"
	target.health.take_damage(float(tune.get("damage", 6.0)), player)
	target.status_float.emit(&"tackle")
	target.stagger_left = maxf(target.stagger_left, float(tune.get("stagger_s", 0.8)))  # a short stagger on the target
	h.commit_tactic(&"tackle", float(tune.get("cooldown", 8.0)), float(tune.get("lock", 0.55)))
	player.play_tactic(&"tackle", true)
	print("[combat] body tackle %s" % target.def.id)

## Body mass stand-in for shoves.
# ASSUMPTION: creature JSON has no mass, so length x height ranks bodies (compy 3.6, raptor 14,
# triceratops 108, T. rex 192).
static func mass_proxy(c: Creature) -> float:
	if c == null or c.def == null:
		return 1.0
	return maxf(0.1, c.def.real_length_m * c.def.height_meters)

## Shove distance for this body: full push up to ref_mass, falling off with mass, 0 for giants.
static func kick_push(c: Creature) -> float:
	var tune := CombatTuning.section("kick")
	var mass := mass_proxy(c)
	if mass >= float(tune.get("giant_mass", 60.0)):
		return 0.0
	var push := float(tune.get("push_m", 3.5)) * clampf(float(tune.get("ref_mass", 8.0)) / mass, 0.0, 1.0)
	return push if push >= float(tune.get("min_push_m", 0.3)) else 0.0

## Kick: shove the target back (scaled by its mass; giants do not budge) with 4 damage.
static func kick(h: Hunt) -> void:
	if h.target == null:
		h.say("Pick a target to kick.")
		return
	if not h.can_start_tactic():
		h.say("Can't kick right now.")
		return
	if h.cooldown_left(&"kick") > 0.0:
		h.say("Kick ready in %.0fs" % ceil(h.cooldown_left(&"kick")))
		return
	var tune := CombatTuning.section("kick")
	if not reach_ok(h, "kick", tune):
		return
	var player := h.player
	var target := h.target
	if not player.vitals.spend_energy(float(tune.get("stamina", 10.0))):
		h.say("Out of stamina.")
		return
	h.last_auto_cast = &"kick"
	var hit := _step_and_strike(h, &"kick", float(tune.get("lunge_max_m", 0.8)))
	player.play_tactic(&"kick", false)
	if hit.is_empty():
		h.commit_tactic(&"kick", float(tune.get("cooldown", 6.0)), float(tune.get("lock", 0.45)))
		print("[combat] kick %s missed: no hurtbox in the way" % target.def.id)
		return
	var push := kick_push(target)
	if push <= 0.0:
		h.say("Too heavy to shove: it barely feels the kick.")
	else:
		var away := target.global_position - player.global_position
		away.y = 0.0
		# Respect walls, props and terrain instead of teleporting the target through geometry.
		target.move_and_collide(away.normalized() * push)
	target.next_hit_kind = &"hit"
	target.health.take_damage(float(tune.get("damage", 4.0)), player)
	target.status_float.emit(&"kick")
	target.stagger_left = maxf(target.stagger_left, float(tune.get("stagger_s", 0.5)))
	h.commit_tactic(&"kick", float(tune.get("cooldown", 6.0)), float(tune.get("lock", 0.45)))
	print("[combat] kick %s push=%.2f" % [target.def.id, push])
