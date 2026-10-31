class_name SpacingStomp
extends RefCounted
## SPACING STOMP (owner 2026-10-31: "for animals that have weird hitboxes (like trex style where they hang over their legs)
## add a stomp mechanic that tosses the player backwards to the perfect range of a chomp style attack. Make the ground
## shake"). One shared, data-driven move (ai.json spacing_stomp) for every rig with a spacing_stomp clip (the overhanging
## theropods, tools/gait/make_thero_roar.py ... spacing_stomp). CreatureBrain owns one (for_creature) and ticks it before
## its own think, so no brain needs code of its own.
## When: its target (standing, not pinned) is tucked in where the jaws cannot reach: in front of the hips and short of the
## bite's reach (bite_reach less inner_margin_m), inside the body's width. (Not judged by a Hitbox preview of the bite: the
## big rexes' calibrated head spheres, 6.5-7.2 m, "reach" under their own chests.)
## The move: the right foot is hauled up and slammed down (hit_frac in anim_events): the ground shakes (TheroRoar's
## shake), a dust ring, a little damage (damage_mult), and she is shoved straight out in front and knocked down
## (PlayerSim.shove / PlayerKnock) so she lands at the bite's reach, measured from the species' own jaw hitbox at the
## bite's hit frame. When the clip ends the brain follows up at once: the bite combo or the bite (TacticalBrain), the
## timed bite (TyrantBrain), or a plain attack_primary.
## Not the big stomp (BIGSTOMP, the lethal pin under the foot): this one barely hurts and only fixes the spacing. Where a
## rig has both, BigStomp ticks first and takes her when she is in its ring and it is ready; this one fills in while it
## cools down or when she is tucked in outside its ring. It shares BigStomp's dust and shake (through TheroRoar).

const CLIP := &"spacing_stomp"

var creature: Creature
var cfg: Dictionary
var phase: StringName = &""  ## &"windup" until the foot lands, &"after" until the clip ends, &"wait" while she flies
var t := 0.0
var cd := 0.0
var victim: Node3D
## For tests and the review lab: stomps started, the push asked for (metres), the shake, and the bite reach used.
var stomps := 0
var last_push := 0.0
var last_shake := 0.0
var last_reach := 0.0
var followed := &""

static func section() -> Dictionary:
	var s: Variant = Data.creature_ai.get("spacing_stomp", {})
	return s if s is Dictionary else {}

## The move an animal uses, or null: a wild animal whose rig has the clip, unless spacing_stomp.species.<id>.enabled false.
static func for_creature(c: Creature) -> SpacingStomp:
	if c == null or c.def == null or c.is_pet or c.anim == null or not c.anim.has_state(CLIP):
		return null
	var s := SpacingStomp.new()
	s.creature = c
	s.cfg = section().duplicate(true)
	var rows: Variant = s.cfg.get("species", {})
	s.cfg.erase("species")
	if rows is Dictionary and (rows as Dictionary).has(str(c.def.id)):
		s.cfg.merge((rows as Dictionary)[str(c.def.id)], true)
	if not bool(s.cfg.get("enabled", true)):
		return null
	return s

func _num(k: String, d: float) -> float:
	return float(cfg.get(k, d))

func _fwd() -> Vector3:
	var f := -creature.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD

## How far ahead of the body's centre the jaws close at the bite's hit frame (the attack_primary hitbox's first part,
## the Jaw), flat metres; the brain's reach_to when the rig has no hitbox bake.
func bite_reach(target: Node3D) -> float:
	var samples := Hitbox.baked(creature, &"attack_primary")
	var sk := Hurtboxes.skeleton_of(creature)
	if samples.is_empty() or sk == null or (samples[-1] as Array).is_empty():
		return creature.brain.reach_to(target) if creature.brain else 3.0
	var jaw: Vector3 = sk.global_transform * ((samples[-1] as Array)[0][0] as Vector3)
	return (jaw - creature.global_position).dot(_fwd())

## Her (ahead, across) offset from the body's centre, flat metres.
func local_offset(v: Node3D) -> Vector2:
	var d := v.global_position - creature.global_position
	d.y = 0.0
	var f := _fwd()
	return Vector2(d.dot(f), d.dot(f.cross(Vector3.UP)))

## Tucked in under the chest or between the legs, where the bite cannot reach her.
func tucked(v: Node3D) -> bool:
	var o := local_offset(v)
	var reach := bite_reach(v)
	if o.x < -_num("behind_frac", 0.3) * creature.body_radius() or o.x > reach - _num("inner_margin_m", 0.8):
		return false
	return absf(o.y) <= creature.body_radius() * _num("width_frac", 0.9)

static func _standing(v: Node3D) -> bool:
	if v is Player:
		var p := v as Player
		return not p.dead and not p.statuses.has(&"knockdown") and not p.statuses.has(&"pinned") and not (p.sim and p.sim.knock.active())
	if v is Creature:
		var c := v as Creature
		return not c.health.dead and not c.statuses.has(&"knockdown") and not c.statuses.has(&"pinned")
	return false

## Called by CreatureBrain every physics frame before it thinks; true while the stomp owns the body.
func tick(delta: float, brain: CreatureBrain) -> bool:
	cd = maxf(0.0, cd - delta)
	if phase != &"":
		_step(delta, brain)
		return phase != &""
	if cd > 0.0 or not brain.spacing_ready():
		return false
	var v := brain.attack_target
	if not _standing(v) or not tucked(v):
		return false
	_start(v)
	return true

func _start(v: Node3D) -> void:
	victim = v
	phase = &"windup"
	t = 0.0
	stomps += 1
	followed = &""
	creature.stop_move()
	creature.anim.play_clip(CLIP)
	print("[ai] %s spacing stomp (prey %.1f m ahead, bite reach %.1f m)" % [creature.def.id, local_offset(v).x, bite_reach(v)])

func _len() -> float:
	var ap := creature.anim.player
	var l := ap.get_animation(CLIP).length if ap and ap.has_animation(CLIP) else 1.0
	return l / maxf(0.01, creature.anim.cadence(CLIP))

func _step(delta: float, brain: CreatureBrain) -> void:
	t += delta
	if creature.health.dead or (t > 0.1 and phase != &"wait" and creature.anim.current_clip != CLIP):
		_end()  # knocked down, killed or cut off
		return
	creature.stop_move()
	if phase == &"windup":
		if t >= _len() * CreatureClips._hit_frac(CLIP):
			phase = &"after"
			_land()
	elif phase == &"after" and t >= _len() - 0.02:
		phase = &"wait"
		creature.anim.play_idle()
	if phase == &"wait" and (not _airborne(victim) or t >= _len() + _num("wait_max_s", 1.5)):
		_end()
		_follow_up(brain)

## Still in the air from a throw: the bite waits until she is down on the ground.
static func _airborne(v: Node3D) -> bool:
	return v is Player and is_instance_valid(v) and (v as Player).sim != null and (v as Player).sim.knock.phase == PlayerKnock.Phase.AIR

func _land() -> void:
	var h := TheroRoar.height(creature)
	var foot := creature.global_position
	var sk := Hurtboxes.skeleton_of(creature)
	if sk and sk.find_bone("Toe.R") >= 0:
		foot = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Toe.R")).origin
		foot.y = creature.global_position.y
	TheroRoar.ground_fx(creature.get_parent(), foot, h, _num("ring_h", 0.9) * h)
	last_shake = TheroRoar.shake_local(creature.def, h, foot) * _num("shake_mult", 1.0)
	if not is_instance_valid(victim) or not _standing(victim):
		return
	last_reach = bite_reach(victim)
	if _num("push_to_m", 0.0) > 0.0:  # ALLOCHARGE (spacing_stomp.species.allosaurus): out to charge range, not bite range
		last_reach = _num("push_to_m", 0.0) * creature.size_scale()
	var o := local_offset(victim)
	last_push = maxf(0.0, last_reach - o.x)
	if not CreatureAttack._deal_damage(creature, victim, CLIP, _num("damage_mult", 0.15)):
		return  # rolled clear (its opening window) or otherwise dodged
	var push := _fwd() * last_push
	if victim is Player:
		var pl := victim as Player
		var land := PlayerKnock.push_to_land(last_push, creature)  # a big one throws her: its tumble carries her on
		if pl.sim and last_push > 0.05:
			pl.sim.shove(_fwd() * float(land[0]), 0.6, float(land[1]), creature)
		if not pl.sim or not pl.sim.knock.active():
			pl.statuses.apply(&"knockdown", creature, 1)  # a short shove is a light tier: lay her down anyway
	elif victim is Creature:
		var cr := victim as Creature
		cr.global_position += push
		cr.statuses.apply(&"knockdown", creature, 1)
		cr.anim.play_clip(&"knockdown")

## The chomp while she is down: the brain's own bite path, so its hitbox, damage and statuses apply as usual.
func _follow_up(brain: CreatureBrain) -> void:
	if not is_instance_valid(victim) or brain.attack_target != victim:
		return
	if brain is TyrantBrain:
		(brain as TyrantBrain).follow_up_bite()
		followed = (brain as TyrantBrain).windup_clip
	elif brain is TacticalBrain and str(cfg.get("follow", "")) == "bull":
		# ALLOCHARGE (owner 2026-10-31: "stomp throw back, huff huff, charge ... jump and bite"): the bull reset, the windup
		# (its display_clip) and the charge
		(brain as TacticalBrain)._start_bull_reset()
		followed = creature.anim.current_clip
	elif brain is TacticalBrain:
		var tb := brain as TacticalBrain
		tb._beat_since_basic = true  # the stomp was the beat between basics
		if tb._strike(tb._flat_dist(victim), ["combo", "bite"]):
			followed = creature.anim.current_clip
		else:
			tb._bite()
			followed = &"attack_primary"
	else:
		creature.anim.play_clip(&"attack_primary")
		followed = &"attack_primary"

func _end() -> void:
	phase = &""
	cd = _num("cooldown_s", 4.0)
