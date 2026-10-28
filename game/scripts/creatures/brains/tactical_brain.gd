class_name TacticalBrain
extends CreatureBrain
## Tactical melee for archetypes with an ai.json "tactics" block (data, not per-species code).
## approach (close to the stand-off ring) -> circle (sidestep at a walk, facing the prey at the species
## turn rate) -> one manoeuvre, then back to the ring:
##   feint  - step in at a run and back out again, no bite
##   lunge  - short dash into a basic bite (attack) or, with energy, the chomp combo (combo)
##   pounce - telegraphed: windup (ground ring on the prey) -> leap -> hit at a fixed time -> recover
##   retreat - below the HP threshold: back off facing the prey, then circle wider before re-engaging
## Every move has its own cooldown; specials (pounce, combo) also need energy (Creature.try_special) and
## the dashes need Creature.can_sprint(). Natures scale it (natures.json tactic_* knobs).

## Every manoeuvre as it starts (tests, labs, debug): bite, combo, lunge, feint, pounce, leap, retreat.
signal tactic(kind: StringName)
## A tactical hit resolving: clip, the hit's index within the clip, and its damage multiplier.
signal tactic_hit(clip: StringName, index: int, mult: float)
## The attack-selection loop picked this move at distance d (it was the strongest one available).
signal attack_chosen(move: StringName, d: float)

const MOVES: Array[StringName] = [&"circle", &"feint", &"lunge", &"pounce", &"combo", &"attack", &"retreat", &"approach", &"hop"]

var tac: Dictionary = {}
var _cd: Dictionary = {}  ## move -> seconds until it may start again
var _left := 0.0  ## timer of the current manoeuvre
var _circle_sign := 1.0
var _lunge_into: StringName = &"attack_primary"
var _feint_out := false
var _pounce_phase: StringName = &""  ## windup, leap, recover
var _pounce_from := Vector3.ZERO
var _pounce_to := Vector3.ZERO
var _pounce_t := 0.0
var _wide_left := 0.0
var _retreat_cd := 0.0
var _telegraph: Telegraph
var last_bite_s := -999.0
var _circle_t := 0.0
## hop: the backward leap every back-off uses (owner: "it shouldnt walk back, it should jump back").
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_t := 0.0
var _hop_then: StringName = &"circle"
var _hop_timed := false

static func tactics_for(archetype: StringName) -> Dictionary:
	var row: Variant = (Data.creature_ai.get("archetypes", {}) as Dictionary).get(str(archetype), {})
	var t: Variant = (row as Dictionary).get("tactics") if row is Dictionary else null
	return t if t is Dictionary else {}

static func has_tactics(def: CreatureDef) -> bool:
	return not tactics_for(def.archetype).is_empty()

func setup(c: Creature) -> void:
	super.setup(c)
	tac = tactics_for(c.def.archetype)
	_circle_sign = _flank_sign
	state_changed.connect(_on_state_changed)

func on_aggro(who: Node) -> void:
	super.on_aggro(who)
	if who is Node3D:
		_propagate_alert(who as Node3D)

func _full_rate() -> bool:
	return state in MOVES

func _pre_think(dt: float) -> bool:
	var handled := super._pre_think(dt)
	if _pounce_phase != &"" and not _valid_target():
		_end_pounce()
	return handled

func _t(key: String, fallback: float) -> float:
	return float(tac.get(key, fallback))

## Cooldowns scale with the nature (Aggressive shorter).
func _start_cd(move: StringName) -> void:
	_cd[move] = _t(str(move) + "_cd", 2.0) * creature.nature_knob("tactic_cooldown_mult", 1.0)

func cooldown_left(move: StringName) -> float:
	return float(_cd.get(move, 0.0))

func _ready_to(move: StringName) -> bool:
	return cooldown_left(move) <= 0.0

## Stand-off radius, centre to centre: the archetype's ring, the nature's mult (Timid wider), the
## prey's extra size, and wider for a while after a retreat.
func ring_m() -> float:
	var r := _t("ring_m", 5.0) * creature.nature_knob("tactic_standoff_mult", 1.0) + _size_excess(attack_target)
	return r * (_t("wide_ring_mult", 1.6) if _wide_left > 0.0 else 1.0)

## HP fraction below which it backs off: the archetype's, times the nature's (Timid sooner, Brave later).
func retreat_frac() -> float:
	return clampf(_t("retreat_frac", 0.4) * creature.nature_knob("retreat_threshold_mult", 1.0), 0.0, 0.95)

func hit_damage_mult(clip: StringName, hit_index: int) -> float:
	var mult := 1.0
	if clip == &"bite_combo":
		var mults: Array = tac.get("combo_mults", [1.0, 1.3, 1.8])
		mult = float(mults[clampi(hit_index, 0, mults.size() - 1)])
	tactic_hit.emit(clip, hit_index, mult)
	return mult

func _think(delta: float) -> void:
	for k in _cd:
		_cd[k] = maxf(0.0, float(_cd[k]) - delta)
	_retreat_cd = maxf(0.0, _retreat_cd - delta)
	_wide_left = maxf(0.0, _wide_left - delta)
	speed_override = -1.0
	strafe_face = null
	if not _valid_target() or not state in MOVES:
		_end_pounce()
		super._think(delta)  # roam, scan, alert, flee and the reacquire rule stay shared
		return
	_combat_memory_left = 4.0
	var leader := _pack_leader()
	if leader and leader != creature and leader.brain and leader.brain._valid_target():
		attack_target = leader.brain.attack_target
	if state != &"retreat" and state != &"hop" and _pounce_phase != &"leap" and _retreat_cd <= 0.0 \
			and creature.health.fraction() < retreat_frac() and not creature.nature_flag("fear_immune"):
		_start_retreat(_t("retreat_s", 2.5))
	match state:
		&"approach": _approach_ring()
		&"circle": _circle(delta)
		&"feint": _feint(delta)
		&"lunge": _lunge(delta)
		&"attack", &"combo": _swing(delta)
		&"pounce": _pounce(delta)
		&"retreat": _retreat_tick(delta)
		&"hop": _hop(delta)

func _to_me() -> Vector3:
	var v := creature.global_position - attack_target.global_position
	v.y = 0.0
	return v.normalized() if v.length_squared() > 0.0001 else Vector3.BACK

func _approach_ring() -> void:
	if _flat_dist(attack_target) <= ring_m() + 0.6:
		_enter_circle()
		return
	creature.move_to(attack_target.global_position + _to_me() * ring_m())

func _enter_circle(hold: float = -1.0) -> void:
	_set_state(&"circle")
	_circle_t = 0.0
	_left = hold if hold >= 0.0 else randf_range(_t("circle_min_s", 1.2), _t("circle_max_s", 2.6))

## Sidestep around the prey on the ring, facing it; pick a manoeuvre when the timer runs out.
func _circle(delta: float) -> void:
	var d := _flat_dist(attack_target)
	if d > ring_m() + 3.0:
		_set_state(&"approach")
		return
	strafe_face = attack_target
	_circle_t += delta
	speed_override = creature.walk_mps(creature.move_speed_mps()) * _t("circle_speed_frac", 0.8)
	var step := deg_to_rad(_t("circle_step_deg", 35.0)) * _circle_sign
	# Steering at a point `step` ahead settles at radius * cos(step); aim past the ring so it holds the ring.
	creature.move_to(attack_target.global_position + _to_me().rotated(Vector3.UP, step) * ring_m() / cos(step))
	# At the ring (or with prey that followed it into its jaws after a beat of backing off) the
	# strongest attack that is ready goes; while everything cools down it keeps moving.
	var at_ring := d >= ring_m() - 1.0
	var in_jaws := d <= reach_to(attack_target) and _circle_t >= _t("contact_after_s", 1.0)
	if (at_ring or in_jaws) and _strike(d):
		return
	if not at_ring and not creature.anim._busy and creature.stagger_left <= 0.0:
		_start_hop()  # inside the ring with nothing to throw: jump back out to it, never reverse-walk
		return
	_left -= delta
	if _left <= 0.0:
		_move_beat()

func _can_swing() -> bool:
	return not creature.anim._busy and creature.stagger_left <= 0.0 and _pack_ready()

## Attack moves, strongest first (ai.json tactics.attack_priority): combo, pounce, bite by default.
func attack_priority() -> Array:
	return tac.get("attack_priority", ["combo", "pounce", "bite"])

## Ready right now: off its own cooldown, affordable (specials: energy and not winded), in range,
## and the body is free to swing. Dashing in also needs can_sprint() unless the prey is in reach.
func attack_available(move: StringName, d: float) -> bool:
	if not _ready_to(move) or not _can_swing() or _wide_left > 0.0:
		return false
	var in_reach := d <= reach_to(attack_target)
	match move:
		&"combo":
			return creature.anim.has_state(&"bite_combo") and creature.can_use_special(creature.special_cost(&"bite_combo")) \
				and (in_reach or creature.can_sprint())
		&"pounce":
			return creature.can_sprint() and creature.can_use_special(creature.special_cost(&"pounce")) \
				and d >= _t("pounce_min_m", 4.0) and d <= _t("pounce_max_m", 8.0) + _size_excess(attack_target)
		&"bite":
			return in_reach or creature.can_sprint()
	return false

## The strongest available attack, or false when everything is cooling down.
func _strike(d: float) -> bool:
	for m in attack_priority():
		var move := StringName(m)
		if not attack_available(move, d):
			continue
		var in_reach := d <= reach_to(attack_target)
		attack_chosen.emit(move, d)
		match move:
			&"combo":
				if not in_reach:
					_start_lunge(&"bite_combo")
				elif creature.try_special(&"bite_combo"):
					_combo()
				else:
					continue
			&"pounce":
				_start_pounce()
			&"bite":
				if in_reach:
					_bite()
				else:
					_start_lunge(&"attack_primary")
		return true
	return false

## Nothing ready: strafe on (sometimes the other way) or feint, then look again.
func _move_beat() -> void:
	_left = randf_range(_t("circle_min_s", 0.8), _t("circle_max_s", 1.6))
	if randf() < _t("flip_chance", 0.3):
		_circle_sign = -_circle_sign
	var feint := _t("feint_chance", 0.25) * creature.nature_knob("tactic_feint_mult", 1.0)
	if creature.can_sprint() and _flat_dist(attack_target) >= ring_m() - 1.0 and randf() < feint:
		_start_feint()

func _start_feint() -> void:
	_set_state(&"feint")
	_feint_out = false
	_left = _t("feint_s", 0.7)
	tactic.emit(&"feint")
	_log("[ai] %s feint" % creature.def.id)

func _feint(delta: float) -> void:
	strafe_face = attack_target
	_left -= delta
	var half := _t("feint_s", 0.7) * 0.5
	if not _feint_out and _left > half:
		speed_override = creature.move_speed_mps()
		creature.move_to(attack_target.global_position + _to_me() * maxf(reach_to(attack_target) + 0.6, ring_m() * 0.5))
	else:
		_start_hop()  # the step in is answered by a jump back out
		return
	if _left <= 0.0:
		_enter_circle()

func _start_lunge(into: StringName) -> void:
	_set_state(&"lunge")
	_lunge_into = into
	_left = _t("lunge_max_s", 1.2)
	tactic.emit(&"lunge")
	_log("[ai] %s lunge -> %s" % [creature.def.id, into])

## Short fast dash at the prey, then the bite or the combo at contact.
func _lunge(delta: float) -> void:
	_left -= delta
	speed_override = creature.move_speed_mps() * _t("lunge_speed_mult", 1.0)
	creature.move_to(attack_target.global_position)
	if _flat_dist(attack_target) <= reach_to(attack_target) - 0.1 and _can_swing():
		if _lunge_into == &"bite_combo" and creature.try_special(&"bite_combo"):
			_combo()
		elif _ready_to(&"bite"):
			_bite()
		else:
			_enter_circle(0.3)
	elif _left <= 0.0:
		_enter_circle()

func _bite() -> void:
	creature.stop_move()
	creature.anim.play_clip(&"attack_primary")
	last_bite_s = _now_s()
	_start_cd(&"bite")
	_set_state(&"attack")
	_mark_pack()
	tactic.emit(&"bite")

func _combo() -> void:
	creature.stop_move()
	creature.anim.play_clip(&"bite_combo")
	_start_cd(&"combo")
	_start_cd(&"bite")
	_set_state(&"combo")
	_mark_pack()
	tactic.emit(&"combo")
	_log("[ai] %s chomp combo" % creature.def.id)

func _mark_pack() -> void:
	if _is_pack_member():
		_pack_cooldown_until[creature.pack_id] = _now_s() + _t("pack_gap_s", 0.6)

## Standing in a bite or the combo: face the prey, back to the ring when the clip ends.
func _swing(delta: float) -> void:
	creature.stop_move()
	creature.face_towards(attack_target.global_position, delta)
	if not creature.anim._busy:
		_start_hop()

func _start_pounce() -> void:
	if not creature.try_special(&"pounce"):
		_enter_circle(0.3)
		return
	_set_state(&"pounce")
	_pounce_phase = &"windup"
	_left = _t("pounce_telegraph_s", 0.8)
	creature.stop_move()
	# The heavy clip is retimed so its strike frame lands with the leap's hit time.
	creature.anim.play_timed_attack(&"attack_heavy", _left + _t("pounce_leap_s", 0.4))
	_telegraph = Telegraph.show_pounce(creature, attack_target.global_position, _t("pounce_radius_m", 1.6) + _size_excess(attack_target), _left + _t("pounce_leap_s", 0.4))
	_start_cd(&"pounce")
	_mark_pack()
	tactic.emit(&"pounce")
	_log("[ai] %s pounce windup" % creature.def.id)

## The pounce, every physics frame. Windup: crouched, turning to the prey, ring on the prey. Leap: a
## fixed-time arc to where the prey stood at take-off. Hit: exactly at the leap's end (a roll avoids it).
func _pounce(delta: float) -> void:
	match _pounce_phase:
		&"windup":
			creature.face_towards(attack_target.global_position, delta)
			if is_instance_valid(_telegraph):
				_telegraph.global_position = attack_target.global_position
			_left -= delta
			if _left <= 0.0:
				_pounce_phase = &"leap"
				_pounce_t = 0.0
				_pounce_from = creature.global_position
				var dir := -_to_me()
				var land := attack_target.global_position - dir * (creature.body_radius() + 0.2)
				var far := _t("pounce_max_m", 8.0) + _size_excess(attack_target)
				if _pounce_from.distance_to(land) > far:
					land = _pounce_from + (land - _pounce_from).normalized() * far
				_pounce_to = land
				tactic.emit(&"leap")
		&"leap":
			var leap_s := _t("pounce_leap_s", 0.4)
			_pounce_t += delta
			var f := clampf(_pounce_t / leap_s, 0.0, 1.0)
			_arc_step(_pounce_from, _pounce_to, f, _t("pounce_height_m", 1.0))
			if f >= 1.0:
				creature.view.position.y = 0.0
				_pounce_land()
				_pounce_phase = &"recover"
				_left = _t("pounce_recover_s", 0.7)
		&"recover":
			_left -= delta
			if _left <= 0.0:
				_end_pounce()
				_start_hop()

func _pounce_land() -> void:
	var tgt := attack_target
	if _flat_dist(tgt) > reach_to(tgt) + 0.3:
		_log("[ai] %s pounce missed" % creature.def.id)
		return
	if tgt is Player and (tgt as Player).dead:
		return
	# A roll is judged by CreatureAttack against the roll's opening window (RollRules), as for any bite.
	var mult := _t("pounce_mult", 1.5)
	tactic_hit.emit(&"pounce", 0, mult)
	if CreatureAttack.apply_for(creature, &"attack_heavy", tgt, mult) and tgt is Player:
		(tgt as Player).receive_creature_hit(creature, &"attack_heavy")

## One frame of a leap: along from -> to at fraction f, the body (view) lifted on a sine arc.
func _arc_step(from: Vector3, to: Vector3, f: float, height: float) -> void:
	var step := from.lerp(to, f) - creature.global_position
	step.y = 0.0
	creature.move_and_collide(step)
	creature.view.position.y = sin(PI * f) * height

## Backward leap away from the prey, facing it: hop_m in hop_s on a hop_height_m arc, then a short
## landing before `then` resumes. hop_back plays when the rig has it, else the pounce pose retimed.
func _start_hop(then: StringName = &"circle", dist_mult: float = 1.0) -> void:
	creature.stop_move()
	_set_state(&"hop")
	_hop_then = then
	_hop_t = 0.0
	_hop_from = creature.global_position
	_hop_to = _hop_from + _to_me() * _t("hop_m", 3.5) * dist_mult
	_hop_timed = not creature.anim.has_state(&"hop_back")
	if _hop_timed:
		creature.anim.play_timed_attack(&"attack_heavy", _t("hop_s", 0.4))
	else:
		creature.anim.play_clip(&"hop_back")
	tactic.emit(&"hop")

func _hop(delta: float) -> void:
	creature.face_towards(attack_target.global_position, delta)
	_hop_t += delta
	var hop_s := _t("hop_s", 0.4)
	if _hop_t <= hop_s:
		_arc_step(_hop_from, _hop_to, _hop_t / hop_s, _t("hop_height_m", 0.7))
		return
	creature.view.position.y = 0.0
	if _hop_timed:
		_hop_timed = false
		creature.anim.end_timed_attack()
	if _hop_t >= hop_s + _t("hop_land_s", 0.15):
		if _hop_then == &"retreat":
			_set_state(&"retreat")
		else:
			_enter_circle()

func _end_hop() -> void:
	if creature and creature.view:
		creature.view.position.y = 0.0
	if _hop_timed:
		_hop_timed = false
		creature.anim.end_timed_attack()

func _end_pounce() -> void:
	if _pounce_phase == &"":
		return
	_pounce_phase = &""
	if creature and creature.view:
		creature.view.position.y = 0.0
	creature.anim.end_timed_attack()
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null

func _start_retreat(seconds: float) -> void:
	_end_pounce()
	_retreat_left = seconds
	_retreat_cd = _t("retreat_cd", 10.0)
	_wide_left = maxf(_wide_left, _t("wide_circle_s", 4.0))
	tactic.emit(&"retreat")
	_start_hop(&"retreat", _t("retreat_hop_mult", 1.4))

## Hurt: jump back (again while still inside the wide ring), then strafe the wide ring facing the prey
## until the retreat time is up; the wide ring holds for wide_circle_s before it re-engages.
func _retreat_tick(delta: float) -> void:
	_wide_left = maxf(_wide_left, _t("wide_circle_s", 4.0))
	if _flat_dist(attack_target) < ring_m() - 1.0:
		_start_hop(&"retreat", _t("retreat_hop_mult", 1.4))
		return
	strafe_face = attack_target
	speed_override = creature.walk_mps(creature.move_speed_mps()) * _t("retreat_speed_frac", 1.2)
	var step := deg_to_rad(_t("circle_step_deg", 35.0)) * _circle_sign
	creature.move_to(attack_target.global_position + _to_me().rotated(Vector3.UP, step) * ring_m() / cos(step))
	_retreat_left -= delta
	if _retreat_left <= 0.0:
		_enter_circle()

func _on_state_changed(prev: StringName, _next: StringName) -> void:
	if prev == &"pounce":
		_end_pounce()
	elif prev == &"hop":
		_end_hop()

func _exit_tree() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
