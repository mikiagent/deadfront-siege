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
## GRAZERS (a profile on a herbivore archetype, e.g. pack_mule / zebraceratops): the tactics run only while
## the animal is provoked (CreatureBrain._provoked); otherwise it is a grazer (flee on sight, or, for a
## tactics.stand_ground_natures nature, a threat display). Extras: the display step, a straight horn charge
## (tactics.charge_straight), a hind kick at point blank when the prey is behind it, and herd defence.

## Every manoeuvre as it starts (tests, labs, debug): bite, combo, lunge, feint, pounce, leap, retreat.
signal tactic(kind: StringName)
## A tactical hit resolving: clip, the hit's index within the clip, and its damage multiplier.
signal tactic_hit(clip: StringName, index: int, mult: float)
## The attack-selection loop picked this move at distance d (it was the strongest one available).
signal attack_chosen(move: StringName, d: float)
## A combo sequence (tactics.sequences) started, and each of its steps as it starts.
signal sequence_started(seq_name: String, steps: Array)
signal sequence_step(step: StringName)
## The cooling filler picked: hold, strafe (strafe-walk), dodge (power strafe), feint or hop.
signal filler(kind: StringName)

const MOVES: Array[StringName] = [&"circle", &"feint", &"lunge", &"pounce", &"combo", &"attack", &"retreat", &"approach", &"hop", &"hold", &"dodge", &"charge", &"display", &"pin", &"charge_turn", &"bound", &"flank", &"spit", &"grab"]

var tac: Dictionary = {}
## This brain's own dice (picks, timings, overshoot), so a seeded test replays exactly whatever else
## draws from the global RNG.
var rng := RandomNumberGenerator.new()
var _cd: Dictionary = {}  ## move -> seconds until it may start again
var _left := 0.0  ## timer of the current manoeuvre
var _circle_sign := 1.0
var _lunge_into: StringName = &"attack_primary"
var _feint_out := false
var _pounce_phase: StringName = &""  ## windup, leap, recover
var _wide_left := 0.0
var _retreat_cd := 0.0
var _telegraph: Telegraph
var last_bite_s := -999.0
var _circle_t := 0.0
var _wait_t := 0.0  ## seconds spent repositioning while pressed, waiting for an opening
## Leaps (owner: "it shouldnt walk back, it should jump back"): one in flight at a time.
var _hop_then: StringName = &"circle"
var _hop_to := Vector3.ZERO
var _scurry_left := 0.0  ## a swarm's run-back instead of a leap (tactics.backoff "scurry")
var _flee_left := 0.0  ## seconds a swarm keeps fleeing (hurt, or a packmate died)
var _pack_seen := 0
var _fight_t := 0.0  ## seconds on the current prey (the surround ring turns with the leader's)  ## live pack size last think, to notice a packmate's death
var _just_disengaged := false
var _beat_since_basic := true  ## a hold/hop/feint/strafe beat since the last basic bite
var _basic_streak := 0  ## basics since the last special or two beats in a row  ## the last move was a back-leap: the next back-off waits for an attack or a hold
var _leaping := false  ## the lunge is a leap-in
var _j_from := Vector3.ZERO
var _j_to := Vector3.ZERO
var _j_t := 0.0
var _j_len := 0.55
var _j_air := Vector2(0.0, 1.0)  ## airborne window as fractions of _j_len
var _j_height := 0.7
var _j_timed := false
var _j_loop: StringName = &""  ## a loop clip standing in for a missing leap clip
var _pounce_hit_u := 1.0
var _pounce_hit_done := false
var _pounce_landed := false
var _overshot := false
var _pounce_dir := Vector3.FORWARD
## AMBUSH (tactics.ambush): lurk beside tree cover, strike first with a long pounce out of it.
## SEQUENCES (owner: "backstep -> strafe right -> pounce", "backstep -> strafe left -> charge").
var _seq: Array = []
var _seq_i := 0
var _charge_bite := false
var lurking := false
var _cover := Vector3.ZERO
var _cover_cd := 0.0
var _opening := false
var _open_left := 0.0  ## seconds the ambush keeps waiting to open with the pounce
## Straight charge (tactics.charge_straight): locked line, one body-slam impact (charge_shove_m knocks
## the survivor back), a miss staggers it.
var _charge_to := Vector3.ZERO
var _charge_dir := Vector3.FORWARD
var _charge_hit := false
## STYRAFIX horned charge (tactics.charge_impale, owner 2026-10-31): paw (head-down telegraph, stands still) ->
## run (committed line in its facing, ramped, the charge clip stride-matched) -> impale (the horn tip reaches her:
## the impale clip; at its hit frame she is caught where the horn tip is, carried up with it and flung at its
## release frame) or, on a miss, brake (decelerates on the charge clip) -> recover (winded, stands for
## charge_recover_s: the punish window). The whole move is one brain state, "charge".
var _charge_phase: StringName = &""
var _phase_t := 0.0
var _phase_len := 0.0
var _caught: Player = null
var _caught_y := 0.0  ## her standing centre height when caught
var _run_v := 0.0
## Flat metres from the horn tip to her centre at the impale's hit frame (-1 before one): read by t_styrafix.
var impale_gap := -1.0
static var _horn_local: Dictionary = {}  ## species -> the nose-horn tip in Head-bone rest space (model units)
## CHARGE TURN (tactics.charge_turn, carnotaurus): the charge's return pass is running (one per charge).
var _charge_return := false
var _turn_from := 0.0
var _tossing := false  ## WOOLLY RHINO: standing at the impact point while the toss clip plays
var _crouch := false  ## coiling in charge_crouch before the run
## BULL RESET (tactics.charge_reset "bull", pachycephalosaurus): back-hops left before the windup and the next charge.
var _bull_hops := 0
## SKITTISH-TERRITORIAL (tactics.territorial, owner 2026-10-31: "engage the player after running away once"):
## the first threat sends it running for flee_once_s, then it turns and fights while the threat stays.
## Under weak_frac HP it is no longer provoked and runs again; once the threat is gone the cycle resets.
var territorial := false
var _terr_fled_s := 0.0
var _terr_threat: Node3D
## PIN (tactics.pin, SP-SMILODON): the prey held down under the forepaws after a landed pounce.
var _pin_victim: Node3D
## SPIT (tactics spit_*, SP-DILOPHOSAURUS): the venom spit's glob has left the mouth (VenomSpit flies it).
var _spit_fired := false
var _pin_clip: StringName = &"pin_stab"  ## the clip the hold lasts for: pin_stab (smilodon) or grab_bite (allosaurus)
## BURST CHASER (tactics.burst / tactics.bound, SMILORUN, owner 2026-10-31: "jumping, leaping, bounding movement abilities
## that make it very hard to escape ... the ultimate burst chaser"). On prey running away it sprints in short bursts
## (burst.mps for burst.s, burst_cd between, energy costs.burst), bounds bound.min_m-max_m at it in one leap (the leap clip),
## lands a cut-off leap across her escape line when she runs across its path, hops onto a step it is stuck against, and a
## bound that lands in pounce range springs straight into the pounce (chase_pounce_telegraph_s: it is already coiled).
var _burst_left := 0.0
var _coiled_left := 0.0  ## seconds since a bound landed during which the pounce skips its crouch
var _stuck_t := 0.0  ## seconds the chase has been pushing into something (the step hop)
var _b_phys := false  ## the current leap lifts the body itself (over steps) instead of the view
var _b_from_y := 0.0
var _b_to_y := 0.0
var _b_struck := false  ## this bound's landing strike has been judged

static func tactics_for(archetype: StringName) -> Dictionary:
	var row: Variant = (Data.creature_ai.get("archetypes", {}) as Dictionary).get(str(archetype), {})
	var t: Variant = (row as Dictionary).get("tactics") if row is Dictionary else null
	return resolve(t) if t is Dictionary else {}

## A species' tactics: its own block (species JSON "tactics") when it has one, else its archetype's.
static func tactics_for_def(def: CreatureDef) -> Dictionary:
	return resolve(def.tactics) if not def.tactics.is_empty() else tactics_for(def.archetype)

## Distances a profile's "scale" multiplies (metres; not times, speeds or damage).
const SCALED_KEYS: Array[String] = ["ring_m", "strafe_m", "hop_m", "leap_back_m", "leap_in_max_m", "pounce_min_m",
	"pounce_max_m", "chase_pounce_max_m", "ambush_radius_m", "back_radius_m", "ambush_pounce_max_m", "cover_m",
	"max_retreat_m", "pounce_radius_m", "pounce_overshoot_m"]

## ONE PROFILE, MANY SPECIES (owner 2026-10-31: the deinonychus brain for coelophysis, gallimimus, utahraptor and
## velociraptor): a tactics block with "base" starts from that archetype's tactics, multiplies its distances by
## "scale", then takes every other key as an override (a dictionary such as enraged or alpha merges one level).
static func resolve(t: Dictionary) -> Dictionary:
	if not t.has("base"):
		return t
	var out: Dictionary = tactics_for(StringName(str(t["base"]))).duplicate(true)
	var k := float(t.get("scale", 1.0))
	for key in SCALED_KEYS:
		if out.has(key):
			out[key] = float(out[key]) * k
	for key in t:
		if key == "base" or key == "scale":
			continue
		if t[key] is Dictionary and out.get(key) is Dictionary:
			(out[key] as Dictionary).merge(t[key], true)
		else:
			out[key] = t[key]
	return out

## RAPTORFEEL on the tactics brain (velociraptor): a rig with investigate and sniff loops sniffs, then holds still in the
## investigate idle for RaptorPackBrain.INVESTIGATE_HOLD_S before it commits; prey in reach or a hit ends it at once.
func _spot(who: Node3D) -> void:
	super._spot(who)
	# The sizing-up hold is the sniff-then-investigate pair (velociraptor). The compy's investigate is its combat idle
	# (COMPYFEEL, aware_idle), not a reason to wait: a swarm commits at once.
	if creature.anim.has_state(&"investigate") and creature.anim.has_state(&"sniff") and not _is_herbivore():
		_alert_left = RaptorPackBrain.INVESTIGATE_HOLD_S

func _investigate_hold() -> void:
	if state != &"alert" or _alert_left <= 0.0 or not _valid_target() or not creature.anim.has_state(&"investigate"):
		return
	if _flat_dist(attack_target) <= reach_to(attack_target):
		_alert_left = 0.0
		return
	creature.stop_move()
	creature.face_towards(attack_target.global_position, 1.0 / THINK_HZ)

func _territorial_tick(delta: float) -> void:
	var row: Dictionary = tac.get("territorial", {})
	if row.is_empty():
		return
	if territorial:
		if not _valid_target():
			territorial = false  # the threat is gone: back to grazing, the next one sends it running again
			_terr_fled_s = 0.0
		return
	var healthy := creature.health.fraction() >= _weak_frac() and not _flee_nature()
	if state == &"flee" and _valid_target() and _flee_left <= 0.0 and not _enrage_fled:
		_terr_threat = attack_target
		_terr_fled_s += delta
		if _terr_fled_s >= float(row.get("flee_once_s", 3.0)) and healthy:
			_turn_territorial(_terr_threat)
	elif _terr_threat != null:
		# The flight ended (it outran the leash): a healthy animal turns on the threat if it is still near.
		var threat := _terr_threat
		_terr_threat = null
		_terr_fled_s = 0.0
		if healthy and is_instance_valid(threat) and threat.is_inside_tree() and _flat_dist(threat) <= _t_terr("leash_m", 30.0):
			_turn_territorial(threat)

func _turn_territorial(threat: Node3D) -> void:
	territorial = true
	_terr_threat = null
	_terr_fled_s = 0.0
	attack_target = threat
	_combat_memory_left = 4.0
	_seq = []
	_set_state(&"approach")
	tactic.emit(&"territorial")

func _t_terr(key: String, fallback: float) -> float:
	return float((tac.get("territorial", {}) as Dictionary).get(key, fallback))

## A territorial animal holds on to the threat out to territorial.leash_m (it ran that far first).
func aggro_radius() -> float:
	var r := super.aggro_radius()
	return maxf(r, _t_terr("leash_m", 30.0)) if territorial else r

func _weak_frac() -> float:
	return float((tac.get("territorial", {}) as Dictionary).get("weak_frac", 0.3))

static func has_tactics(def: CreatureDef) -> bool:
	return not tactics_for_def(def).is_empty()

func setup(c: Creature) -> void:
	super.setup(c)
	tac = tactics_for_def(c.def)
	# STYRAFIX: a species tactics block may set attack_range, the reach its strikes are judged by (the 3x
	# styracosaurus strikes with horns 6 m ahead of its centre, not its barrel).
	if c.def.tactics.has("attack_range"):
		profile["attack_range"] = c.def.tactics["attack_range"]
	# A variant's own moves (megaloceros doe: no antlers, so no ram; kick and stomp only).
	var over: Variant = CreatureView.variant_row(c.def, c.variant).get("tactics", {})
	if over is Dictionary and not (over as Dictionary).is_empty():
		tac = tac.duplicate(true)
		tac.merge(over, true)
	rng.randomize()
	if tac.get("grab", false):
		process_priority = 100  # _process holds grabbed prey in the jaws after the AnimationTree has posed them
	_circle_sign = _flank_sign
	state_changed.connect(_on_state_changed)

func on_aggro(who: Node) -> void:
	super.on_aggro(who)
	if state == &"alert" and creature.anim.has_state(&"investigate"):
		_alert_left = 0.0  # hit while sizing it up: it commits now (RAPTORFEEL)
	if who is Node3D:
		_propagate_alert(who as Node3D)
		if tac.get("herd_defend", false) and _is_herbivore() and _now_s() - _last_hit_s < 0.5:  # hit, not just spotted
			_rally_herd(who as Node3D)

## HERD DEFENCE (zebraceratops verb "herd solidarity"): a herdmate that is hit pulls the rest of the herd
## onto its attacker for defend_s. The flee natures run instead, and a member hit in the last few seconds
## keeps running (the hurt one gets away while the others turn on the attacker).
func _rally_herd(who: Node3D) -> void:
	for c in _pack_members():
		if c == creature or not c.brain is TacticalBrain:
			continue
		var b := c.brain as TacticalBrain
		if b._flee_nature() or _now_s() - b._last_hit_s < BrainFlight.FRESH_HIT_S:
			continue
		b.attack_target = who
		b._combat_memory_left = 4.0
		b._provoked_until = maxf(b._provoked_until, _now_s() + _t("defend_s", 8.0))
		if b.state in [&"roam", &"alert", &"flee", &"display", &"disengage", &"sleep"] and b._provoked():
			b._seq = []
			b._set_state(&"approach")
			b.tactic.emit(&"defend")

## Natures that never fight back (they only flee) and natures that stand their ground with a threat
## display instead of fleeing on sight (tactics.flee_natures / stand_ground_natures).
func _flee_nature() -> bool:
	return str(creature.nature_id()) in tac.get("flee_natures", [])

func _stands_ground() -> bool:
	return str(creature.nature_id()) in tac.get("stand_ground_natures", [])

## A grazer's provocation also ends when the prey is past guard_m from its home (it defends, it does
## not hunt), and a flee nature is never provoked.
func _provoked() -> bool:
	if _is_herbivore() and not tac.is_empty():
		if cornered.fighting() and _valid_target():
			return true  # chased into a fight: it holds it past guard_m and its flee nature (BrainCornered)
		if _flee_nature():
			return false
		if territorial and _valid_target():
			return creature.health.fraction() >= _weak_frac()
		if tac.has("guard_m") and _valid_target() and Vector2(attack_target.global_position.x - creature.spawn_home.x, attack_target.global_position.z - creature.spawn_home.z).length() > _t("guard_m", 16.0):
			return false
	return super._provoked()

## A stand-ground grazer fights back from the first hit.
func note_damage(amount: float) -> void:
	if _is_herbivore() and _stands_ground() and creature and not creature.health.dead:
		_provoked_until = maxf(_provoked_until, _now_s() + PROVOKE_SECONDS)
	super.note_damage(amount)

## A tactical flight (hurt, a packmate's death, a Timid rage) keeps running even while provoked.
func _holds_flee() -> bool:
	return _flee_left > 0.0 or _enrage_fled

func _full_rate() -> bool:
	return state in MOVES

## SPACING STOMP waits out a body-carrying move: a leap, a charge, a pin, a pounce, a grab.
func _body_committed() -> bool:
	return _leaping or state in [&"pounce", &"lunge", &"charge", &"charge_turn", &"pin", &"bound", &"flank", &"dodge", &"hop"]

func _pre_think(dt: float) -> bool:
	# Before the shared rules (a disengage would skip the think): a packmate just died, the rest scatter.
	var pack_now := _pack_members().size()
	if tac.has("mate_death_flee_s") and _pack_seen > pack_now and _valid_target() and state != &"flee" and state != &"sleep":
		_start_flee(_t("mate_death_flee_s", 3.0))
	_pack_seen = pack_now
	var handled := super._pre_think(dt)
	if _pounce_phase != &"" and not _valid_target():
		_end_pounce()
	return handled

## ENRAGE (owner 2026-10-28: "more aggressive moves (more jumping around and using combo moves)"):
## while the creature is enraged, tactics.enraged scales a knob, pulled toward 1 by the nature's
## enrage_mult (Aggressive/Brave most, Docile least): value = 1 + (row - 1) x enrage_mult.
## The profile's situational modifier blocks, multiplied together (each a {knob: factor} row):
##   enraged    - while enraged, pulled toward 1 by the nature's enrage_mult;
##   pack_bold  - a pack of pack_bold.n or more live members on the fight (bolder in numbers);
##   alone      - no live packmate left;
##   weak_prey  - the prey's HP fraction is under weak_prey.hp_frac (opportunistic).
## fallback is returned when no active block names the knob.
func _mod(key: String, fallback: float) -> float:
	var out := fallback
	var hit := false
	for name in _active_mods():
		var row: Dictionary = tac.get(name, {})
		if not row.has(key):
			continue
		var f := float(row[key])
		if name == "enraged":
			f = 1.0 + (f - 1.0) * creature.nature_knob("enrage_mult", 1.0)
		out = (out if hit else 1.0) * f
		hit = true
	return maxf(0.05, out) if hit else fallback

func _active_mods() -> Array[String]:
	var on: Array[String] = []
	if creature.statuses.has(&"enraged"):
		on.append("enraged")
	if tac.has("pack_bold") or tac.has("alone"):
		var n := _pack_members().size()
		if tac.has("pack_bold") and n >= int((tac["pack_bold"] as Dictionary).get("n", 4)):
			on.append("pack_bold")
		elif tac.has("alone") and n <= 1:
			on.append("alone")
	if tac.has("weak_prey") and _valid_target() and _target_hp_frac() < float((tac["weak_prey"] as Dictionary).get("hp_frac", 0.4)):
		on.append("weak_prey")
	return on

func _target_hp_frac() -> float:
	if attack_target is Player:
		var v := (attack_target as Player).vitals
		return v.health / maxf(1.0, v.effective_max_health()) if v else 1.0
	if attack_target is Creature:
		return (attack_target as Creature).health.fraction()
	return 1.0

func _t(key: String, fallback: float) -> float:
	return float(tac.get(key, fallback))

## Cooldowns scale with the nature (Aggressive shorter).
func _start_cd(move: StringName) -> void:
	_cd[move] = _t(str(move) + "_cd", 2.0) * creature.nature_knob("tactic_cooldown_mult", 1.0) * _mod("cooldown_mult", 1.0)

func cooldown_left(move: StringName) -> float:
	return float(_cd.get(move, 0.0))

func _ready_to(move: StringName) -> bool:
	return cooldown_left(move) <= 0.0

## SP-TARBOSAURUS: a long-snouted body bites from its head, metres ahead of its middle (the tarbosaurus's jaws sit
## ~8 m ahead of its centre), so tactics.reach_m (metres at size 1) replaces the centre reach. Each hit still needs its
## part (pipeline.hit_parts): prey under the belly is out of the jaws' reach.
func contact_reach() -> float:
	return float(tac["reach_m"]) * creature.size_scale() if tac.has("reach_m") else super.contact_reach()

## How far short of the prey a leap lands: just past the body's radius, or for a long-snouted body (tactics.reach_m)
## with the jaws on the prey.
func _land_short() -> float:
	return contact_reach() - 0.8 if tac.has("reach_m") else creature.body_radius() + 0.2

## Stand-off radius, centre to centre: the archetype's ring, the nature's mult (Timid wider), the
## prey's extra size, and wider for a while after a retreat.
func ring_m() -> float:
	var r := _t("ring_m", 5.0) * creature.nature_knob("tactic_standoff_mult", 1.0) + _size_excess(attack_target)
	return r * (_t("wide_ring_mult", 1.6) if _wide_left > 0.0 else 1.0)

## HP fraction below which it backs off: the archetype's, times the nature's (Timid sooner, Brave later).
func retreat_frac() -> float:
	return clampf(_t("retreat_frac", 0.4) * creature.nature_knob("retreat_threshold_mult", 1.0) * _mod("retreat_frac_mult", 1.0), 0.0, 0.95)

func hit_damage_mult(clip: StringName, hit_index: int) -> float:
	var mult := 1.0
	if clip == &"bite_combo":
		var mults: Array = tac.get("combo_mults", [1.0, 1.3, 1.8])
		mult = float(mults[clampi(hit_index, 0, mults.size() - 1)])
	elif clip == &"kick":
		mult = _t("kick_mult", 1.0)
	elif clip == &"pin_stab":
		mult = _t("pin_mult", 1.0)
	elif clip == &"grab_bite" and tac.get("grab", false):
		mult = _t("grab_mult", 0.5) if hit_index == 0 else _t("pin_mult", 1.0)  # the hands' clamp, then the bites
	elif clip == &"attack_heavy":
		# ASSUMPTION (horned_charger): the sweeping horn swipe, x heavy_mult (2.2). Only the
		# anim-driven attack_heavy reads this (the charge and the pounce pass their own mult).
		mult = _t("heavy_mult", 1.0)
	tactic_hit.emit(clip, hit_index, mult)
	return mult

func _think(delta: float) -> void:
	_territorial_tick(delta)
	_investigate_hold()
	for k in _cd:
		_cd[k] = maxf(0.0, float(_cd[k]) - delta)
	_retreat_cd = maxf(0.0, _retreat_cd - delta)
	_wide_left = maxf(0.0, _wide_left - delta)
	_open_left = maxf(0.0, _open_left - delta)
	_burst_left = maxf(0.0, _burst_left - delta)
	_coiled_left = maxf(0.0, _coiled_left - delta)
	if _valid_target() and state in [&"circle", &"dodge", &"hold", &"hop"] and _prey_advancing():
		_wait_t += delta
	_opening = _opening and _open_left > 0.0
	speed_override = -1.0
	strafe_face = null
	gait_clip = &""
	line_dir = Vector3.ZERO
	if _flee_left > 0.0:
		_flee_left -= delta
		if _flee_left <= 0.0 and state == &"flee" and not _enrage_fled:
			_set_state(&"approach" if _valid_target() else &"roam")
	# GRAZER: a stand-ground nature that spotted a threat lowers its head instead of fleeing.
	if state == &"alert" and _valid_target() and _is_herbivore() and _stands_ground() and not _provoked():
		_alert_left -= delta
		if _alert_left <= 0.0:
			_seq = []
			_start_display()
		return
	if state == &"display" and not _valid_target():
		_set_state(&"roam")
	if not _valid_target() or not state in MOVES:
		_end_pounce()
		super._think(delta)  # roam, scan, alert, flee and the reacquire rule stay shared
		return
	# GRAZER: provocation over (time, or the prey left its guard_m): stand down and let the grazer rules
	# decide (flee on sight, display, or graze). The standoff display is not a fight.
	if _is_herbivore() and not (state == &"display" and _seq.is_empty()) and _flee_left <= 0.0 and not _provoked():
		_end_pounce()
		_seq = []
		_set_state(&"alert")
		_alert_left = 0.3
		tactic.emit(&"stand_down")
		return
	_combat_memory_left = 4.0
	_fight_t += delta
	var leader := _pack_leader()
	if leader and leader != creature and leader.brain and leader.brain._valid_target():
		attack_target = leader.brain.attack_target
	if state != &"retreat" and state != &"hop" and _pounce_phase != &"leap" and _retreat_cd <= 0.0 \
			and creature.health.fraction() < retreat_frac() and not creature.nature_flag("fear_immune"):
		_start_retreat(_t("retreat_s", 2.5))
	# Prey walking away is chased at a run, or pounced when the pounce is ready: no holding, strafing
	# or backing off while it leaves (owner 2026-10-28).
	if state in [&"circle", &"hold", &"feint", &"approach"] and _prey_leaving():
		var d := _flat_dist(attack_target)
		var pounce_ok: bool = (d <= _t("chase_pounce_max_m", 8.0) and _strike(d, ["pounce"])) or (tac.get("approach_spit", false) and _strike(d, ["spit"]))  # a short pounce only: a long one lets her walk off
		if not pounce_ok and d > reach_to(attack_target) and state != &"approach":
			_set_state(&"approach")
			_just_disengaged = false  # chasing is a real action between back-jumps
			tactic.emit(&"chase")
	match state:
		&"approach": _approach_ring()
		&"circle": _circle(delta)
		&"feint": _feint(delta)
		&"lunge": _lunge(delta)
		&"attack", &"combo": _swing(delta)
		&"pounce": _pounce(delta)
		&"retreat": _retreat_tick(delta)
		&"hop": _hop(delta)
		&"hold": _hold(delta)
		&"dodge": _dodge(delta)
		&"charge": _charge(delta)
		&"charge_turn": _charge_turn(delta)
		&"display": _display(delta)
		&"pin": _pin(delta)
		&"spit": _spit(delta)
		&"bound": _bound(delta)
		&"grab": _grab(delta)
		&"flank": _flank(delta)

## AMBUSH: roam is lurking at cover (crouched by a tree near home), not wandering.
func _roam(delta: float) -> void:
	if not _ambushes():
		super._roam(delta)
		return
	_cover_cd -= delta
	if _cover == Vector3.ZERO or _cover_cd <= 0.0:
		_cover = _find_cover()
		_cover_cd = 10.0
	lurking = _flat_dist_to(_cover) <= 1.2
	if lurking:
		creature.stop_move()
	else:
		creature.move_to(_cover)

## The tree nearest home within cover_m (a HarvestNode whose family role is a tree), standing just
## beside its trunk on the home side; home itself when there is none.
func _find_cover() -> Vector3:
	if _ambushes() and str(tac.get("ambush_cover", "")) == "water":
		return water_cover
	var home := creature.spawn_home
	var best := home
	var best_d := _t("cover_m", 14.0)
	for n in creature.get_tree().get_nodes_in_group("harvest"):
		var h := n as HarvestNode
		if h == null or not h.is_tree():
			continue
		var d := home.distance_to(h.global_position)
		if d < best_d:
			best_d = d
			var side := home - h.global_position
			side.y = 0.0
			best = h.global_position + (side.normalized() if side.length_squared() > 0.01 else Vector3.BACK) * (creature.body_radius() + 0.8)
	return best

## AMBUSH: no long-range spotting. Prey is struck only inside ambush_radius_m, or inside
## back_radius_m while the survivor's back is turned.
func _scan() -> void:
	if not _ambushes():
		super._scan()
		return
	if state != &"roam" or not flight.can_reacquire():
		return
	var who := _nearest_live_prey(_t("ambush_radius_m", 6.0))
	var player := PlayerRegistry.nearest(creature.global_position)
	if who == null and player and not player.dead and _flat_dist(player) <= _t("back_radius_m", 10.0) and _back_turned(player):
		who = player
	if who == null:
		return
	attack_target = who
	_combat_memory_left = 4.0
	lurking = false
	creature.mark_aggro_now()
	_propagate_alert(who)
	_opening = true
	_open_left = _t("ambush_open_s", 2.5)
	tactic.emit(&"ambush")
	_log("[ai] %s ambush %s" % [creature.def.id, who.name])
	_enter_circle(0.0)
	_strike(_flat_dist(who))

## WATER-EDGE AMBUSH (tactics.ambush_cover "water", SP-CERATOSAURUS, # ASSUMPTION): the lurk spot is a dry bank within
## cover_m of home beside the river channel or the shore, and the ambush pounce is its lunge out of the shallows. With
## no water near home (or no island, as in the lab) it does not ambush at all and hunts like any predator.
var water_cover := Vector3.INF
var _water_checked := false

func _ambushes() -> bool:
	if not tac.get("ambush", false):
		return false
	if str(tac.get("ambush_cover", "")) != "water":
		return true
	if not _water_checked:
		_water_checked = true
		water_cover = _find_water_edge()
	return water_cover != Vector3.INF

func _find_water_edge() -> Vector3:
	var rt := World.runtime as IslandRuntime if World else null
	if rt == null or not is_instance_valid(rt):
		return Vector3.INF
	var home := creature.spawn_home
	var far := _t("cover_m", 14.0)
	for i in 4:
		var r := far * (i + 1) / 4.0
		for k in 24:
			var a := TAU * k / 24.0
			var p := home + Vector3(cos(a), 0.0, sin(a)) * r
			var lp := rt.to_local(p)
			var wet := rt.river_dist_at(lp.x, lp.z) < _t("bank_river_m", 9.0) or rt.rad_at(lp.x, lp.z) > rt.land_radius() - 4.0
			if wet and rt.is_dry(lp):
				return Vector3(p.x, rt.global_transform.origin.y + rt.surface_y(lp.x, lp.z), p.z)
	return Vector3.INF

func _back_turned(p: Player) -> bool:
	var fwd := -p.visual.global_basis.z
	fwd.y = 0.0
	var to_me := creature.global_position - p.global_position
	to_me.y = 0.0
	return fwd.length_squared() > 0.01 and to_me.length_squared() > 0.01 and fwd.normalized().dot(to_me.normalized()) < -0.3

## Plates and debug read brain_state: a lurking ambusher shows "lurk".
func tick(dt: float) -> void:
	super.tick(dt)
	if lurking and state == &"roam":
		creature.brain_state = &"lurk"

func _to_me() -> Vector3:
	var v := creature.global_position - attack_target.global_position
	v.y = 0.0
	return v.normalized() if v.length_squared() > 0.0001 else Vector3.BACK

func _approach_ring() -> void:
	if _prey_leaving():
		if creature.can_sprint():
			speed_override = creature.move_speed_mps()  # a full run after it, not the 0.7 chase pace
		var d := _flat_dist(attack_target)
		# A quick bite (or the pounce) on the run; the long combo would only let her walk off.
		# A bound-striker does not stop to swipe at prey sprinting off (the paw only rakes air): it bounds onto her instead.
		var swipe := not bool((tac.get("bound", {}) as Dictionary).get("strike", false)) or _prey_speed() < _t("swipe_max_prey_mps", 4.0)
		if (d <= _t("chase_pounce_max_m", 8.0) and _strike(d, ["pounce"])) or (swipe and d <= reach_to(attack_target) and _strike(d, ["bite"])):
			return
		if _burst_chase(d, delta_s()):
			return
		if tac.get("approach_spit", false) and _strike(d, ["spit"]):
			return  # SP-DILOPHOSAURUS: venom after her as she runs
		# tactics.chase_hop (swarm): at her heels with the bite not allowed yet (cooling, or no beat since the
		# last one) it hops back out instead of trotting glued to her forever; the hop is the beat, the chase
		# picks up again after it.
		if tac.get("chase_hop", false) and d <= reach_to(attack_target) and can_disengage():
			_start_hop(&"approach")
			return
		creature.move_to(attack_target.global_position)
		return
	# tactics.approach_pounce (swarm): coming in, it opens with a pounce as soon as one is in range (not a
	# lone one: timid alone).
	if tac.get("approach_pounce", false) and not "alone" in _active_mods() and _strike(_flat_dist(attack_target), ["pounce"]):
		return
	# tactics.approach_spit (dilophosaurus): coming in, it opens with the venom spit as soon as she is in spit range.
	if tac.get("approach_spit", false) and _strike(_flat_dist(attack_target), ["spit"]):
		return
	# The nav agent stops target_desired_distance (0.9 m) short of its goal: count that as arrived.
	if _flat_dist(attack_target) <= ring_m() + 0.6 + creature.agent.target_desired_distance:
		_enter_circle()
		return
	# tactics.stalk (saber cat): it closes in on the low hunting creep, slow and flat, until the pounce is in range.
	if tac.get("stalk", false) and creature.anim.has_state(&"stalk"):
		gait_clip = &"stalk"
		speed_override = creature.walk_mps(creature.move_speed_mps()) * _t("stalk_speed_frac", 0.5)
	creature.move_to(attack_target.global_position + _to_me() * ring_m())

func _prey_speed() -> float:
	var v: Vector3 = attack_target.velocity if attack_target is CharacterBody3D else Vector3.ZERO
	return Vector2(v.x, v.z).length()

## The prey moving away from it (> 1 m/s outward).
func _prey_leaving() -> bool:
	var v: Vector3 = attack_target.velocity if attack_target is CharacterBody3D else Vector3.ZERO
	return Vector3(v.x, 0.0, v.z).dot(-_to_me()) > 1.0

const CIRCLE_MIN_S := 0.3

func _enter_circle(hold: float = -1.0) -> void:
	_set_state(&"circle")
	_circle_t = 0.0
	_left = hold if hold >= 0.0 else rng.randf_range(_t("circle_min_s", 1.2), _t("circle_max_s", 2.6))

## Sidestep around the prey on the ring, facing it; pick a manoeuvre when the timer runs out.
func _circle(delta: float) -> void:
	var d := _flat_dist(attack_target)
	if d > ring_m() + 3.0:
		_set_state(&"approach")
		return
	strafe_face = attack_target
	_circle_t += delta
	speed_override = creature.walk_mps(creature.move_speed_mps()) * _t("circle_speed_frac", 0.8)
	if tac.get("surround", false) and _pack_members().size() > 1:
		var slot := _surround_slot()
		# Thrown off its slot (a back-leap, a strafe jump, a pounce), it hurries back at slot_catchup_mult.
		if _flat_dist_to(slot) > _t("slot_tolerance_m", 1.2):
			speed_override *= _t("slot_catchup_mult", 1.0)
		creature.move_to(slot)
	else:
		var step := deg_to_rad(_t("circle_step_deg", 35.0)) * _circle_sign
		# Steering at a point `step` ahead settles at radius * cos(step); aim past the ring so it holds the ring.
		creature.move_to(attack_target.global_position + _to_me().rotated(Vector3.UP, step) * ring_m() / cos(step))
	# At the ring (or with prey that followed it into its jaws after a beat of backing off) the
	# strongest attack that is ready goes; while everything cools down it keeps moving.
	# ASSUMPTION (KNOCKDOWN merge): a circle lasts at least CIRCLE_MIN_S before its next move, so a move that ends
	# into the circle never flips straight into another (charge -> circle -> charge in one frame read as flicker).
	if _circle_t < CIRCLE_MIN_S:
		return
	var in_jaws := d <= reach_to(attack_target) and _circle_t >= _t("contact_after_s", 1.0)
	if _offence(d, in_jaws):
		return
	_left -= delta
	if _left <= 0.0:
		_move_beat()

## SURROUND (swarm): each packmate holds its own slot on the ring, evenly spaced by pack index, the
## whole ring turning slowly (surround_turn_deg per second of the pack leader's fight clock, so every
## member agrees), so a pack closes in from every side.
func _surround_slot() -> Vector3:
	var members := _pack_members()
	var i := maxi(0, members.find(creature))
	var leader := _pack_leader()
	var clock: float = (leader.brain as TacticalBrain)._fight_t if leader and leader.brain is TacticalBrain else _fight_t
	var turn := deg_to_rad(_t("surround_turn_deg", 20.0)) * clock
	var ang := turn + TAU * float(i) / float(maxi(1, members.size()))
	return attack_target.global_position + Vector3(cos(ang), 0.0, sin(ang)) * ring_m()

func _can_swing() -> bool:
	# The hold's alert pose never blocks a strike: it is a pose, not a commitment.
	return (not creature.anim._busy or creature.anim.current_clip == &"alert") and creature.stagger_left <= 0.0 and _pack_ready()

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
			var far := _t("ambush_pounce_max_m", 10.0) if _opening else _t("pounce_max_m", 8.0)
			# Judged where the prey will be at the hit: windup plus flight at its current outward speed.
			var tv: Vector3 = attack_target.velocity if attack_target is CharacterBody3D else Vector3.ZERO
			var outward := maxf(0.0, Vector3(tv.x, 0.0, tv.z).dot(-_to_me()))
			var at_hit := d + outward * (_pounce_telegraph() + _clip_len(&"pounce", _t("pounce_leap_s", 0.4)) * CreatureClips._hit_frac(&"pounce"))
			return creature.can_sprint() and creature.can_use_special(creature.special_cost(&"pounce")) \
				and d >= _t("pounce_min_m", 4.0) and at_hit <= far + _size_excess(attack_target)
		&"charge":
			return creature.can_sprint() and d >= _t("charge_min_m", 0.0)
		&"spit":
			# SP-DILOPHOSAURUS: from spit_min_m to spit_max_m, with a clear line (the glob flies straight at her).
			return creature.anim.has_state(&"spit") and d >= _t("spit_min_m", 3.0) \
				and d <= _t("spit_max_m", 10.0) + _size_excess(attack_target) and MeleeQuery.blocker(creature, attack_target) == null
		&"kick":
			# tactics.kick_max_m (allosaurus shoulder ram): also prey pressed in under its chin, closer than the jaws work
			var close := tac.has("kick_max_m") and d <= _t("kick_max_m", 0.0) + _size_excess(attack_target)
			return creature.anim.has_state(&"kick") and in_reach and (_prey_behind() or close)
		&"grab":
			# tactics.grab, point blank in front. SP-ALLOSAURUS (a grab_bite clip): the hands-then-jaws grab at jaw range
			# (not under the chin), on prey it can hold. SP-SPINOSAURUS (bite_shake): the snap-and-shake, on prey its jaws can
			# lift (a survivor, or a creature no bigger than itself).
			if not tac.get("grab", false) or not in_reach or _prey_behind():
				return false
			if creature.anim.has_state(&"grab_bite"):
				return d > _t("kick_max_m", 0.0) + _size_excess(attack_target) and _pinnable(attack_target) != null
			return creature.anim.has_state(&"bite_shake") \
				and (attack_target is Player or (attack_target is Creature and (attack_target as Creature).body_radius() <= creature.body_radius()))
		&"heavy":
			# The sweeping horn swipe (the attack_heavy clip, a CONTRACT clip): point blank only,
			# in front (the horns sweep the head's arc). ASSUMPTION: heavy_mult, heavy_cd.
			# tactics.heavy_reach_m: an in-place kick only reaches as far as the feet do (gallimimus rake).
			return creature.anim.has_state(&"attack_heavy") and in_reach and d <= _t("heavy_reach_m", 1e9) + _size_excess(attack_target) \
				and not _prey_behind()
		&"bite":
			# Anti-spam (owner: "what i want to avoid is basic attack spam"): a non-attack beat between
			# two basics, and at most max_basic_streak basics before a beat or a special.
			if not _beat_since_basic or _basic_streak >= int(tac.get("max_basic_streak", 2)):
				return false
			return in_reach or creature.can_sprint()
	return false

## The strongest available attack, or false when everything is cooling down.
func _strike(d: float, only: Array = []) -> bool:
	var order := only if not only.is_empty() else attack_priority()
	if _open_left > 0.0:
		order = ["pounce"]  # the ambush opens with the leap out of cover; it waits a beat for it
	for m in order:
		var move := StringName(m)
		if not attack_available(move, d):
			continue
		var in_reach := d <= _bite_reach() + 0.1  # reach, less the bite_track lead on prey walking away
		attack_chosen.emit(move, d)
		_opening = false
		_open_left = 0.0
		_start_cd(move)  # committed: its cooldown runs from the choice, even if the dash falls short
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
			&"charge":
				_start_charge()
			&"spit":
				_start_spit()
			&"kick":
				_kick()
			&"heavy":
				_heavy()
			&"grab":
				if creature.anim.has_state(&"grab_bite"):
					_grab_hands()  # SP-ALLOSAURUS
				else:
					_start_grab()  # SP-SPINOSAURUS snap-and-shake
		return true
	return false

## Weighted pick among tactics.sequences whose last (offensive) step is ready: off its cooldown and
## affordable. Weight = the row's weight x the nature's tactic_w_<last step> (Aggressive charges more,
## Timid pounces more). {} when nothing is ready (the cooling fillers take over).
func pick_sequence(d: float) -> Dictionary:
	var rows: Array = tac.get("sequences", [])
	var total := 0.0
	var ok: Array = []
	for row in rows:
		var steps: Array = (row as Dictionary).get("steps", [])
		if steps.is_empty():
			continue
		var last := StringName(steps[-1])
		if not _terminal_ready(last, d):
			continue
		var w := float((row as Dictionary).get("weight", 1.0)) * creature.nature_knob("tactic_w_" + str(last), 1.0) \
			* _mod("w_" + str(last), 1.0) * (_mod("combo_seq_mult", 1.0) if (row["steps"] as Array).size() > 1 else 1.0)
		if w <= 0.0:
			continue
		ok.append([row, w])
		total += w
	if ok.is_empty():
		return {}
	var r := rng.randf() * total
	for pair in ok:
		r -= float(pair[1])
		if r <= 0.0:
			return pair[0]
	return ok[-1][0]

## The sequence's finisher can go once the steps before it have run: its cooldown, energy and sprint.
func _terminal_ready(last: StringName, d: float) -> bool:
	if not _ready_to(last) or not _can_swing() or _wide_left > 0.0 or _open_left > 0.0:
		return false
	match last:
		&"pounce":
			return creature.can_sprint() and creature.can_use_special(creature.special_cost(&"pounce"))
		&"combo":
			return creature.anim.has_state(&"bite_combo") and creature.can_use_special(creature.special_cost(&"bite_combo")) and creature.can_sprint()
		&"charge":
			return creature.can_sprint() and d >= _t("charge_min_m", 0.0) \
				and (tac.get("charge_straight", false) or _ready_to(&"bite"))  # a homing charge ends in a bite
		&"spit":
			return creature.anim.has_state(&"spit")
		&"flank":
			return tac.get("flank", false) and creature.anim.has_state(&"flank_rake") and creature.can_sprint() and d <= _t("flank_max_m", 16.0)
	return false

## The offensive pick from the ring or a hold: the ambush opener while it waits for its pounce, point
## blank the combo (or, last resort, the bite), else a sequence whose finisher is ready.
func _offence(d: float, in_jaws: bool) -> bool:
	if _open_left > 0.0:
		return _strike(d, ["pounce"])
	# Pressed (owner: "when a player pursues it should strafe and strafe walk to wait for an attack
	# opening"): while she closes in it repositions until her swing is recovering, her back is
	# turned, or it has waited wait_max_s; then it commits.
	if _prey_advancing() and not attack_opening() and _wait_t < _t("wait_max_s", 3.0) * _mod("wait_mult", 1.0):
		return false
	_wait_t = 0.0
	if in_jaws and _strike(d, tac.get("point_blank", ["combo", "bite"])):
		return true
	# A surrounding pack darts from its own slot: reach it first, so the bites come from every side.
	if tac.get("surround", false) and _pack_members().size() > 1 and _flat_dist_to(_surround_slot()) > _t("slot_tolerance_m", 1.2):
		return false
	return _start_sequence(d)

## An opening on the prey: a survivor whose swing is recovering (or playing) or whose back is turned.
func attack_opening() -> bool:
	var p := attack_target as Player
	if p == null:
		return true
	if p.hunt and (p.hunt._swing_cd > _t("opening_swing_cd_s", 0.2) or p.hunt._swing_pending):
		return true
	if p.anim and p.anim.current_clip in [&"attack_primary", &"attack_heavy", &"punch"]:
		return true
	return _back_turned(p)

func _start_sequence(d: float) -> bool:
	var row := pick_sequence(d)
	if row.is_empty():
		return false
	# tactics.healthy_commit_chance (opportunist, majungasaurus): above the weak_prey HP line a ready pick only goes
	# this often (a test rush); otherwise its cooldown is spent and it keeps circling the prey.
	if tac.has("healthy_commit_chance") and not "weak_prey" in _active_mods() and rng.randf() >= _t("healthy_commit_chance", 1.0):
		_start_cd(StringName((row.get("steps", []) as Array)[-1]))
		return false
	_seq = (row.get("steps", []) as Array).duplicate()
	_seq_i = 0
	var last := StringName(_seq[-1])
	attack_chosen.emit(last, d)
	_start_cd(last)  # committed: the finisher's cooldown runs from the pick
	sequence_started.emit(str(row.get("name", "")), _seq)
	_log("[ai] %s sequence %s" % [creature.def.id, _seq])
	_seq_next()
	return true

## Start the next step; the finisher hands over to the normal attack flow (and its one back-off).
func _seq_next() -> void:
	if _seq_i >= _seq.size():
		_seq = []
		_enter_circle()
		return
	var step := StringName(_seq[_seq_i])
	_seq_i += 1
	sequence_step.emit(step)
	match step:
		&"backstep":
			if can_disengage():
				_start_hop(&"seq")
			else:
				_seq_next()
		&"strafe_left", &"strafe_right":
			_start_dodge(1.0 if step == &"strafe_right" else -1.0)
		&"pounce":
			var d := _flat_dist(attack_target)
			if d >= _t("pounce_min_m", 4.0) and d <= _t("pounce_max_m", 8.0) + _size_excess(attack_target):
				_cd[&"pounce"] = 0.0  # its cooldown was committed at the pick; _start_pounce restarts it
				_start_pounce()
			elif _ready_to(&"bite"):
				_start_charge()  # out of pounce range after the reposition: run it down instead
			else:
				_seq = []
				_enter_circle()
		&"charge":
			_start_charge()
		&"spit":
			var d := _flat_dist(attack_target)
			if d >= _t("spit_min_m", 3.0) and d <= _t("spit_max_m", 10.0) + _size_excess(attack_target):
				_start_spit()
			elif d < _t("spit_min_m", 3.0) and _ready_to(&"bite"):
				_bite()  # she closed in during the reposition: snap at her instead
			else:
				_seq = []
				_enter_circle()
		&"display":
			_start_display()
		&"flank":
			_start_flank()
		&"combo":
			if _flat_dist(attack_target) <= reach_to(attack_target) and creature.try_special(&"bite_combo"):
				_combo()
			else:
				_start_lunge(&"bite_combo")
		_:
			_seq_next()

## A filler dodge's side: in a surrounding pack, towards its own ring slot (a 2.5 m jump would otherwise
## throw it out of the surround); else the rolled side.
func _dodge_side(rolled: float) -> float:
	if not (tac.get("surround", false) and _pack_members().size() > 1):
		return rolled
	var facing := -_to_me()
	var off := _surround_slot() - creature.global_position
	var along := off.dot(Vector3(-facing.z, 0.0, facing.x))
	return signf(along) if absf(along) > 0.5 else rolled

## The powerful strafe: an explosive sideways dodge (dodge_left/right, else the strafe loop) of
## strafe_m across the prey's line, landing still facing it.
func _start_dodge(side: float) -> void:
	_beat()
	_just_disengaged = false
	_set_state(&"dodge")
	var facing := -_to_me()
	var right := Vector3(-facing.z, 0.0, facing.x)
	var clip := &"dodge_right" if side > 0.0 else &"dodge_left"
	if not creature.anim.has_state(clip):
		clip = &"strafe_right" if side > 0.0 else &"strafe_left"
	creature.stop_move()
	_jump_begin(creature.global_position + right * side * _t("strafe_m", 2.5), clip, _t("strafe_s", 0.42), 0.0, _t("dodge_height_per_m", 0.12))
	tactic.emit(&"dodge")

func _dodge(delta: float) -> void:
	creature.face_towards(attack_target.global_position, delta)
	if not _jump_tick(delta):
		return
	_jump_end()
	_seq_next() if not _seq.is_empty() else _enter_circle()

## Charge: run at the prey (the run clip) into a bite. tactics.charge_straight: a horn charge on a
## line locked at the start, through the prey's spot by charge_through_m; contact in front of it is
## one impact (charge_mult, the heavy hit's roll rules); a sidestep makes it miss and stagger.
func _start_charge(return_pass: bool = false) -> void:
	if tac.get("charge_impale", false) and _flat_dist(attack_target) < _t("charge_min_m", 0.0):
		_enter_circle(0.0)  # she closed in during the steps before it (a display): no run-up, fight point blank
		return
	_charge_return = return_pass
	_set_state(&"charge")
	_left = _t("charge_max_s", 1.6)
	_just_disengaged = false
	_seq = []
	_charge_hit = false
	_tossing = false
	_charge_dir = -_to_me()
	_charge_to = attack_target.global_position + _charge_dir * _t("charge_through_m", 2.5)
	if tac.get("charge_impale", false):
		_halt()
		creature.anim.release_oneshot()  # a hold/display pose must not run under the paw
		_phase(&"paw", &"charge_windup", 1.2)
		tactic.emit(&"charge_windup")
		return
	# A rig with a charge_crouch clip coils first (owner 2026-10-31, compy: "it should lower its center of gravity
	# and charge"): body still and turning to the prey until the clip ends, then the run.
	_crouch = creature.anim.has_state(&"charge_crouch")
	if _crouch:
		creature.stop_move()
		creature.anim.play_clip(&"charge_crouch")
	tactic.emit(&"charge")

func _phase(name: StringName, clip: StringName = &"", fallback_s: float = 0.0) -> void:
	_charge_phase = name
	_phase_t = 0.0
	_phase_len = fallback_s
	if clip != &"" and creature.anim.has_state(clip):
		creature.anim.play_clip(clip)
		_phase_len = _clip_len(clip, fallback_s)

## The horned charge's phases (see _charge_phase).
func _charge_impale(delta: float) -> void:
	_phase_t += delta
	match _charge_phase:
		&"paw":
			creature.stop_move()
			creature.face_towards(attack_target.global_position, delta)
			if _phase_t < _phase_len:
				return
			if _flat_dist(attack_target) < _t("charge_min_m", 0.0) * 0.5:
				_charge_cleanup()  # she walked in under the horns while it pawed: no run-up left, fight point blank
				_enter_circle(0.0)
				return
			var fwd := -creature.global_basis.z
			var aim := absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(-_to_me().x, -_to_me().z)))
			if aim > deg_to_rad(_t("charge_aim_deg", 15.0)) and _phase_t < _phase_len * 2.0:
				if not creature.anim.is_busy():
					creature.anim.play_clip(&"charge_windup")  # still turning onto her: paws again, up to one more length
				return
			_charge_dir = -creature.global_basis.z  # committed: the line it faces after the telegraph
			_charge_dir.y = 0.0
			_charge_dir = _charge_dir.normalized()
			_charge_to = creature.global_position + _charge_dir * (_flat_dist(attack_target) + _t("charge_through_m", 2.5))
			_left = _t("charge_max_s", 1.6)
			_run_v = 0.0
			creature.anim.play_clip(&"charge")  # a second paw may still be playing: the run clip takes over now, not idle
			_charge_phase = &"run"
			_phase_t = 0.0
			_drive(0.05)  # on the line this frame: Creature keeps the charge clip instead of falling back to idle
			tactic.emit(&"charge")
		&"run":
			_left -= delta
			var top := creature.move_speed_mps() * _t("charge_speed_mult", 1.5)
			_run_v = minf(top, _run_v + top / maxf(0.05, _t("charge_ramp_s", 0.4)) * delta)  # feet accelerate with it
			_drive(_run_v)
			if _impale_contact():
				_halt()
				_phase(&"impale", &"impale", 1.2)
				return
			_glance()
			if (creature.global_position - _charge_to).dot(_charge_dir) >= 0.0 or _left <= 0.0:
				_charge_phase = &"brake"
				_phase_t = 0.0
				if not _charge_hit:
					tactic.emit(&"charge_miss")
		&"brake":
			_run_v = maxf(0.0, _run_v - creature.move_speed_mps() * _t("charge_speed_mult", 1.5) / maxf(0.05, _t("charge_brake_s", 0.5)) * delta)
			if _run_v > 0.3:
				_drive(_run_v)
			else:
				_start_recover()
		&"impale":
			creature.stop_move()
			var row: Dictionary = (Data.anim_events.get("clips", {}) as Dictionary).get("impale", {})
			var hit := _phase_len * float(row.get("hit_frac", 0.26))
			var release := _phase_len * float(row.get("release_frac", 0.46))
			if not _charge_hit and _phase_t >= hit:
				_impale_hit()
			if _caught:
				if _phase_t < release:
					var tip := horn_tip()  # carried on the horn as it scoops up (never pushed into the ground)
					_caught.global_position = Vector3(tip.x, maxf(tip.y + 0.3, _caught_y), tip.z)
					_caught.velocity = Vector3.ZERO
				else:
					_fling()
			if _phase_t >= _phase_len:
				_fling()
				_start_recover()  # she is in the air: it stands, winded, while she lands (the punish window)
		&"recover":
			creature.stop_move()
			if _phase_t >= _phase_len:
				_charge_cleanup()
				# ASSUMPTION (HITBOXES merge): the charge cooldown runs from the end of the recover, so a missed charge
				# never paws into the next one the frame it stands up (t_styrafix's A->B->A check caught it).
				_start_cd(&"charge")
				if not _strike(_flat_dist(attack_target), ["kick"]):
					_after_charge()

func _start_recover() -> void:
	_halt()
	_phase(&"recover", &"charge_recover", 1.6)
	_phase_len = maxf(_phase_len, _t("charge_recover_s", 2.0))
	creature.stagger_left = maxf(creature.stagger_left, _phase_len)  # stands winded: the punish window
	tactic.emit(&"charge_recover")

## Planted this frame: no path, no line, no leftover velocity (the clip that starts now stands still).
func _halt() -> void:
	creature.stop_move()
	line_dir = Vector3.ZERO
	creature.velocity.x = 0.0
	creature.velocity.z = 0.0

## Straight along the locked line at v m/s, the charge clip stride-matched by Creature.
func _drive(v: float) -> void:
	line_dir = _charge_dir
	speed_override = v
	gait_clip = &"charge"

static func _flat_between(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Contact: she is where the horn tip will be at the impale's hit frame (impale_reach_m ahead of the body on
## the line: the running horns pass over her head and dip onto her), within impale_r_m of the line.
func _impale_contact() -> bool:
	var to := attack_target.global_position - creature.global_position
	var along := to.dot(_charge_dir)
	var reach := _t("impale_reach_m", 0.0) * creature.size_scale()
	if reach <= 0.0:
		return _flat_between(horn_tip(), attack_target.global_position) <= _t("impale_r_m", 1.6)
	# Approached from in front: the first frame inside the window is within one step (~0.15 m) of reach + 0.2.
	return along <= reach + 0.2 and along >= reach - 0.8 and _flat_between(to, _charge_dir * along) <= _t("impale_r_m", 1.6)

## The impale's hit frame: she is caught where the horn tip is now (gap = how far she was from it).
func _impale_hit() -> void:
	_charge_hit = true
	impale_gap = _flat_between(horn_tip(), attack_target.global_position)
	var horned := {}
	if Hitbox.applies(creature, attack_target):
		# HITBOXES: the impale clip's horns (hitboxes.json <species>.moves.impale) must reach her hurtboxes.
		horned = Hitbox.strike(creature, &"impale", attack_target)
		if horned.is_empty():
			tactic.emit(&"charge_miss")
			return
		Hitbox.mark(attack_target, horned)
	elif impale_gap > _t("impale_r_m", 1.6) + 0.8:
		tactic.emit(&"charge_miss")  # she got clear between contact and the hit frame
		return
	var mult := _t("charge_mult", 1.8)
	tactic_hit.emit(&"charge", 0, mult)
	tactic.emit(&"impale")
	tactic.emit(&"charge_hit")
	_mark_pack()
	if CreatureAttack.apply_for(creature, &"attack_heavy", attack_target, mult) and attack_target is Player:
		var pl := attack_target as Player
		pl.receive_creature_hit(creature, &"attack_heavy")
		if pl.sim:
			_caught = pl
			_caught_y = pl.global_position.y
			pl.sim.shove(_charge_dir * 0.01, 2.0)  # no control while on the horn; _fling sets the real throw

## Thrown off the horns: up at toss_up_mps and forward charge_shove_m along the line.
func _fling() -> void:
	if _caught == null or not is_instance_valid(_caught):
		_caught = null
		return
	var up := _t("toss_up_mps", 6.0)
	var air := 2.0 * up / 9.8
	# KNOCKDOWN: the lift makes it a throw (PlayerKnock: ballistic arc, lands on her butt, gets up winded).
	_caught.sim.shove(_charge_dir * _t("charge_shove_m", 4.0), air, up, creature)
	if not _caught.sim.knock.active():
		_caught.velocity.y = up  # rolling, swimming or pinned: the plain shove with the old lift
	_caught = null

## A body-check off the line: she is beside the horns but against its flank. Shoved clear sideways (one
## charge hit), so the run never stalls against her capsule.
func _glance() -> void:
	if _charge_hit:
		return
	var to := attack_target.global_position - creature.global_position
	to.y = 0.0
	if to.length() > creature.body_radius() + 0.9 or to.dot(_charge_dir) < 0.0:
		return
	_charge_hit = true
	var side := (to - _charge_dir * to.dot(_charge_dir)).normalized()
	tactic_hit.emit(&"charge", 0, 1.0)
	tactic.emit(&"charge_hit")
	if CreatureAttack.apply_for(creature, &"attack_heavy", attack_target, 1.0) and attack_target is Player:
		var pl := attack_target as Player
		pl.receive_creature_hit(creature, &"attack_heavy")
		if pl.sim:
			pl.sim.shove((side + _charge_dir * 0.5).normalized() * _t("charge_shove_m", 4.0) * 0.6, _t("charge_shove_stagger_s", 0.6), 0.0, creature)

## Back to the ring, or straight after her when she is already past it (no one-frame circle in between).
func _after_charge() -> void:
	_charge_cleanup()
	if _flat_dist(attack_target) > ring_m() + 3.0:
		_set_state(&"approach")
	else:
		_enter_circle()

func _charge_cleanup() -> void:
	_fling()
	_charge_phase = &""

## Hit reactions do not interrupt a committed charge (paw, run, impale); brake and recover can be punished.
func super_armor() -> bool:
	return (state == &"charge" and _charge_phase in [&"paw", &"run", &"impale"]) or (state == &"grab" and _held != null)

## World position of the nose-horn tip on the live pose: the mesh's frontmost rest vertex, kept in Head-bone
## space and carried by the bone (so it follows the dip and scoop). No rig: a point ahead of the body.
func horn_tip() -> Vector3:
	var fallback := creature.global_position - creature.global_basis.z * (creature.body_radius() + 1.0)
	var rig := creature.view.rig if creature.view else null
	var sk := rig.skeleton if rig else null
	var bone := sk.find_bone("Head") if sk else -1
	if bone < 0:
		return fallback
	if not _horn_local.has(creature.def.id):
		_horn_local[creature.def.id] = _measure_horn(sk, bone)
	var local: Variant = _horn_local[creature.def.id]
	if local == null:
		return fallback
	return sk.global_transform * sk.get_bone_global_pose(bone) * (local as Vector3)

func _measure_horn(sk: Skeleton3D, bone: int) -> Variant:
	var fwd := (sk.global_basis.inverse() * -creature.global_basis.z).normalized()
	var best := -INF
	var tip: Variant = null
	for mi in sk.find_children("*", "MeshInstance3D", false):
		var m := (mi as MeshInstance3D).mesh
		if m == null or (mi as MeshInstance3D).has_meta(&"creature_gear"):
			continue
		for sf in m.get_surface_count():
			for v in (m.surface_get_arrays(sf)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var p := (mi as MeshInstance3D).transform * v
				if p.dot(fwd) > best:
					best = p.dot(fwd)
					tip = p
	return sk.get_bone_global_rest(bone).affine_inverse() * (tip as Vector3) if tip != null else null

func _charge(delta: float) -> void:
	if _charge_phase != &"":
		_charge_impale(delta)
		return
	if _tossing:
		# No glide: the toss plays in place where the horn met her; the line ends when the clip does.
		creature.stop_move()
		if creature.anim.current_clip == &"toss" and creature.anim.is_busy():
			return
		_tossing = false
		_charge_end()
		return
	if _crouch:
		creature.stop_move()
		creature.face_towards(attack_target.global_position, delta)
		if creature.anim.current_clip == &"charge_crouch" and creature.anim.is_busy():
			return
		_crouch = false
		_charge_dir = -_to_me()  # a straight charge locks its line as it launches, not before the coil
		_charge_to = attack_target.global_position + _charge_dir * _t("charge_through_m", 2.5)
	_left -= delta
	if tac.get("charge_straight", false):
		speed_override = creature.move_speed_mps() * _t("charge_speed_mult", 1.5)  # committed: no can_sprint gate mid-line
		gait_clip = &"charge"
		creature.move_to(_charge_to)
		var to := attack_target.global_position - creature.global_position
		to.y = 0.0
		if not _charge_hit and to.length() <= reach_to(attack_target) and to.normalized().dot(_charge_dir) > 0.2 \
				and (Hitbox.applies(creature, attack_target) or creature.part_hit(&"charge", attack_target)):
			_charge_impact()
		if _flat_dist_to(_charge_to) <= 1.0 or _left <= 0.0:
			_charge_end()
		return
	if creature.can_sprint():
		speed_override = creature.move_speed_mps() * _t("charge_speed_mult", 1.5)  # visibly faster than its run
		gait_clip = &"charge"  # the low "naruto run" when the rig has it, else the run at charge speed
	creature.move_to(attack_target.global_position)
	if _flat_dist(attack_target) <= _bite_reach() and (not creature.anim._busy) and creature.stagger_left <= 0.0:
		_bite(true)
	elif _left <= 0.0:
		_enter_circle()

## A contact hit of this brain's animal landed (Creature._on_hit). tactics.heavy_shove_m: the horn ram
## (attack_heavy) throws the survivor back along the line from the animal to her, like the charge's shove (the allosaurus'
## shoulder ram); tactics.kick_shove_m the same for its kick. THERIZINOSAURUS: tactics.primary_shove_m, the claw sweep
## (attack_primary) pushes her back to claw's length; tactics.hook_pull_m, the combo's first hit (the claw hook) drags her
## in toward it, never closer than hook_stop_m. SP-ALLOSAURUS (tactics.grab): the grab_bite's first hit (the hands' clamp)
## pins her for the bites that follow (the utahraptor's bite with arms is its own clip, arm_bite).
## tactics.bite_pin (majungasaurus): a landed crushing bite (attack_primary) holds on: the grab (_start_pin;
## pin_stab shakes the held prey), off pin_cd.
func landed(clip: StringName, target: Node) -> void:
	if clip == &"attack_primary" and tac.get("bite_pin", false) and target == attack_target and _ready_to(&"pin"):
		_start_cd(&"pin")
		_start_pin.call_deferred()  # after the bite's attack_hit returns: started inside it, pin_stab skipped its first hit
		return
	if clip == &"grab_bite" and tac.get("grab", false) and creature.anim.hit_index == 0:
		if _hold_victim(target as Node3D, &"grab_bite"):
			tactic.emit(&"grabbed")
		return
	if not target is Player:
		return
	var pl := target as Player
	var away := pl.global_position - creature.global_position
	away.y = 0.0
	if pl.sim == null or away.length_squared() <= 0.0001:
		return
	if clip == &"attack_heavy" and _t("heavy_shove_m", 0.0) > 0.0:
		pl.sim.shove(away.normalized() * _t("heavy_shove_m", 0.0), _t("heavy_shove_stagger_s", 0.6), 0.0, creature)
		tactic.emit(&"heavy_shove")
	elif clip == &"kick" and _t("kick_shove_m", 0.0) > 0.0:
		pl.sim.shove(away.normalized() * _t("kick_shove_m", 0.0), _t("kick_shove_stagger_s", 0.6), 0.0, creature)
		tactic.emit(&"kick_shove")
	elif clip == &"attack_primary" and _t("primary_shove_m", 0.0) > 0.0:
		pl.sim.shove(away.normalized() * _t("primary_shove_m", 0.0), _t("primary_shove_stagger_s", 0.5))
		tactic.emit(&"sweep_shove")
	elif clip == &"bite_combo" and creature.anim.hit_index == 0 and _t("hook_pull_m", 0.0) > 0.0:
		var pull := minf(_t("hook_pull_m", 0.0), away.length() - _t("hook_stop_m", 4.0) * creature.size_scale())
		if pull > 0.05:
			pl.sim.shove(-away.normalized() * pull, _t("hook_pull_stagger_s", 0.45))
			tactic.emit(&"hook_pull")

## SP-ALLOSAURUS grab (tactics.grab): the grab_bite clip in place; its first hit clamps the hands on the prey (landed ->
## _hold_victim: Pinned, held pin_reach_m ahead), the next two are bites (x pin_mult). A missed clamp is just a miss.
func _grab_hands() -> void:
	_just_disengaged = false
	_basic_streak = 0
	creature.stop_move()
	creature.anim.play_clip(&"grab_bite")
	_start_cd(&"grab")
	_set_state(&"attack")
	_mark_pack()
	tactic.emit(&"grab")
	_log("[ai] %s grab" % creature.def.id)

func _charge_impact() -> void:
	# HITBOXES: the ram lands when the head and horns (the charge part) reach her body, not at the reach ring.
	var hit := {}
	if Hitbox.applies(creature, attack_target):
		hit = Hitbox.strike(creature, &"charge", attack_target)
		if hit.is_empty():
			return  # still closing: the next frame tries again
		Hitbox.mark(attack_target, hit)
	_charge_hit = true
	var mult := _t("charge_mult", 1.8)
	tactic_hit.emit(&"charge", 0, mult)
	tactic.emit(&"charge_hit")
	_mark_pack()
	# WOOLLY RHINO: a rig with a toss clip hooks the horn up through the target at impact (the clip is cosmetic: the
	# hit is this impact) and the shove lifts her off her feet (tactics.toss_lift_mps, ASSUMPTION 5.5 m/s ~ 1.5 m).
	var tossing := creature.anim.has_state(&"toss")
	if tossing:
		creature.stop_move()
		creature.anim.play_clip(&"toss")
		_tossing = true
		tactic.emit(&"toss")
	if CreatureAttack.apply_for(creature, &"attack_heavy", attack_target, mult) and attack_target is Player:
		var pl := attack_target as Player
		pl.receive_creature_hit(creature, &"attack_heavy")
		# A ram, not a horn stab (owner 2026-10-29: "tackling/ramming"): the body-slam shoves her along the line.
		# tactics.charge_toss_deg (carnotaurus): the horns hook her that far off the line, to the side she is on,
		# so the runner can carry on through (straight ahead she stood in its path and stopped it dead).
		# KNOCKDOWN: push x this animal's size picks the reaction (PlayerKnock): a light shove, knocked down, or thrown.
		var push := _charge_dir
		var toss := deg_to_rad(_t("charge_toss_deg", 0.0))
		if toss != 0.0:
			var side := Vector3(-_charge_dir.z, 0.0, _charge_dir.x)
			var s := signf(side.dot(pl.global_position - creature.global_position))
			push = _charge_dir.rotated(Vector3.UP, -toss * (s if s != 0.0 else 1.0))
		if pl.sim:
			# SP-TRIKEALPHA: a toss with toss_side_m throws her sideways, to the animal's right (the clip's twist).
			var throw := Vector3(-_charge_dir.z, 0.0, _charge_dir.x) * (_t("toss_side_m", 0.0) if tossing else 0.0)
			pl.sim.shove(push * _t("charge_shove_m", 0.0) + throw, _t("charge_shove_stagger_s", 0.6), _t("toss_lift_mps", 0.0) if tossing else 0.0, creature)

## End of the line: after a hit, a hind kick when the prey ended up behind it, else the one back-off;
## after a miss it stands staggered for charge_miss_recover_s (the punish window).
func _charge_end() -> void:
	# CHARGE TURN: a fast runner that cannot turn at speed (turn_rate) plants at the end of the line, hops round
	# (the charge_turn clip) and charges straight back through her, once per charge.
	if tac.get("charge_turn", false) and not _charge_return and creature.anim.has_state(&"charge_turn") and _valid_target() \
			and creature.can_sprint() and _flat_dist(attack_target) <= _t("charge_turn_max_m", 18.0):
		_start_charge_turn()
		return
	if str(tac.get("charge_reset", "")) == "bull" and _valid_target():
		if not _charge_hit:
			tactic.emit(&"charge_miss")  # ASSUMPTION: no stagger; the hops and the windup are the punish window
		_start_bull_reset()
		return
	if _charge_hit:
		if not _strike(_flat_dist(attack_target), ["kick"]):
			_back_off()
		return
	tactic.emit(&"charge_miss")
	creature.stagger_left = maxf(creature.stagger_left, _t("charge_miss_recover_s", 1.5))
	_start_hold()

func _start_charge_turn() -> void:
	_set_state(&"charge_turn")
	creature.stop_move()
	_turn_from = creature.rotation.y
	# Its momentum carries it on along the old line while it is in the air; the yaw swings only then.
	_jump_begin(creature.global_position + _charge_dir * _t("charge_turn_skid_m", 2.0), &"charge_turn", 0.7, 0.0, _t("charge_turn_height_per_m", 0.05))
	tactic.emit(&"charge_turn")
	_log("[ai] %s charge turn" % creature.def.id)

## Swing the body round to face the prey inside the clip's airborne window only (anim_events charge_turn.airborne),
## always turning to its left like the clip; on the ground the yaw holds, so the planted feet never skid.
func _charge_turn(delta: float) -> void:
	var to := attack_target.global_position - creature.global_position
	var want := atan2(-to.x, -to.z)
	var left := fposmod(want - _turn_from, TAU)  # counter-clockwise from above = to its left
	var done := _jump_tick(delta)
	var u := clampf((_j_t / maxf(0.01, _j_len) - _j_air.x) / maxf(0.01, _j_air.y - _j_air.x), 0.0, 1.0)
	creature.rotation.y = _turn_from + left * u * u * (3.0 - 2.0 * u)
	if not done:
		return
	_jump_end()
	_start_charge(true)
	tactic.emit(&"charge_return")

## The prey is in its rear arc (the hind kick's side).
func _prey_behind() -> bool:
	var fwd := -creature.global_basis.z
	var to := attack_target.global_position - creature.global_position
	fwd.y = 0.0
	to.y = 0.0
	return fwd.length_squared() > 0.01 and to.length_squared() > 0.01 and fwd.normalized().dot(to.normalized()) < -0.3

## Hind kick (the kick clip; hit at its anim_events hit_frac, x kick_mult): only at point blank with
## the prey behind it. Not a basic: no anti-spam beat needed.
func _kick() -> void:
	_just_disengaged = false
	_basic_streak = 0
	creature.stop_move()
	creature.anim.play_clip(&"kick")
	_set_state(&"attack")
	_mark_pack()
	tactic.emit(&"kick")

## The sweeping horn swipe (horned_charger, ASSUMPTION): the attack_heavy clip at point blank with
## the prey in front — a wide head sweep, x heavy_mult. Not a basic: no anti-spam beat needed.
func _heavy() -> void:
	_just_disengaged = false
	_basic_streak = 0
	creature.stop_move()
	creature.anim.play_clip(&"attack_heavy")
	_start_cd(&"heavy")
	_set_state(&"attack")
	_mark_pack()
	tactic.emit(&"heavy")
	_log("[ai] %s horn swipe" % creature.def.id)

## Threat display (owner 2026-10-28: "head lowering"): it stops, faces the threat and plays the alert
## pose for display_s. In a sequence it leads into the charge. As a grazer's standoff (not provoked)
## it charges when the threat comes within display_charge_m and grazes again once it has gone.
func _start_display() -> void:
	_set_state(&"display")
	_left = _t("display_s", 1.2)
	creature.stop_move()
	# tactics.display_clip (pachycephalosaurus: bull_windup, paw and snort): the display plays it for its whole length.
	var clip := StringName(tac.get("display_clip", "alert"))
	if clip != &"alert" and creature.anim.has_state(clip):
		creature.anim.play_clip(clip)
		_left = _clip_len(clip, _left)
	elif creature.anim.has_state(&"alert") and not creature.anim._busy:
		creature.anim.play_clip(&"alert")
	tactic.emit(&"display")

func _display(delta: float) -> void:
	creature.stop_move()
	creature.face_towards(attack_target.global_position, delta)
	_left -= delta
	if not _seq.is_empty():
		if _left <= 0.0:
			_seq_next()
		return
	if _provoked() or _surface_dist(attack_target) <= _t("display_charge_m", 5.0):
		_provoked_until = maxf(_provoked_until, _now_s() + PROVOKE_SECONDS)
		_enter_circle(0.0)
		return
	if _flat_dist(attack_target) > _effective_perception() * 1.2:
		attack_target = null
		_set_state(&"roam")
		return
	if _left <= 0.0:
		_start_display()

## Nothing ready: one weighted pick among hold (stand its ground facing the prey, alert pose), strafe,
## feint and hop back (owner: "it should be holding its ground sometimes too"). A back-leap needs its
## own cooldown, a free slot (never two disengages without an attack or a hold between) and room
## under max_retreat_m. Holding is twice as likely while the prey is not advancing. Natures scale
## hold (Brave, Aggressive) and back-off (Timid) weights.
func _move_beat() -> void:
	_left = rng.randf_range(_t("circle_min_s", 0.8), _t("circle_max_s", 1.6)) * _mod("beat_mult", 1.0)
	var d := _flat_dist(attack_target)
	# Reposition (owner): while the basic bite is cooling down, or while she presses it, the filler is
	# only strafe-walk, the power strafe and one backstep; hold and feint wait for later.
	var reposition := not _ready_to(&"bite") or _prey_advancing()
	var w_hold := 0.0 if reposition else _t("w_hold", 0.35) * creature.nature_knob("tactic_hold_mult", 1.0) * (1.0 if _prey_advancing() else 2.0)
	var w_strafe := _t("w_strafe", 0.35) * _mod("w_strafe", 1.0)
	var w_dodge := _t("w_dodge", 0.3) * _mod("w_dodge", 1.0) if creature.can_sprint() else 0.0
	# A swarm's feint is a dart in and out (tactics.feint_repositions): it stays a repositioning filler.
	var feint_ok := not reposition or bool(tac.get("feint_repositions", false))
	var w_feint := 0.0 if not feint_ok else (_t("w_feint", 0.15) * creature.nature_knob("tactic_feint_mult", 1.0) * _mod("w_feint", 1.0) if creature.can_sprint() and d >= ring_m() - 1.0 else 0.0)
	var w_hop := _t("w_hop", 0.15) * creature.nature_knob("tactic_backoff_mult", 1.0) * _mod("w_hop", 1.0) if can_disengage() and d < ring_m() - 0.5 else 0.0
	var r := rng.randf() * (w_hold + w_strafe + w_dodge + w_feint + w_hop)
	if r < w_hold:
		filler.emit(&"hold")
		_start_hold()
	elif r < w_hold + w_strafe:
		filler.emit(&"strafe")
		_beat()
		_just_disengaged = false  # a strafe is the action between two back-jumps
		tactic.emit(&"strafe")
		if rng.randf() < _t("flip_chance", 0.3):
			_circle_sign = -_circle_sign
	elif r < w_hold + w_strafe + w_dodge:
		filler.emit(&"dodge")
		_start_dodge(_dodge_side(1.0 if rng.randf() < 0.5 else -1.0))
	elif r < w_hold + w_strafe + w_dodge + w_feint:
		filler.emit(&"feint")
		_start_feint()
	else:
		filler.emit(&"hop")
		_start_hop()

## A back-leap is allowed: off its cooldown and not straight after another back-leap.
func can_disengage() -> bool:
	return _ready_to(&"hop") and not _just_disengaged

## The prey closing in on it (> 0.5 m/s towards it).
func _prey_advancing() -> bool:
	var v: Vector3 = attack_target.velocity if attack_target is CharacterBody3D else Vector3.ZERO
	return Vector3(v.x, 0.0, v.z).dot(_to_me()) > 0.5

## A non-attack beat happened (hold, hop, feint, a strafe pick): the next basic may go. Two beats in a
## row also clear the basic streak.
func _beat() -> void:
	if _beat_since_basic:
		_basic_streak = 0
	_beat_since_basic = true

func _start_hold() -> void:
	_beat()
	_set_state(&"hold")
	_left = rng.randf_range(_t("hold_min_s", 0.8), _t("hold_max_s", 1.6))
	creature.stop_move()
	if creature.anim.has_state(&"alert") and not creature.anim._busy:
		creature.anim.play_clip(&"alert")  # the threat pose (wings flare where the rig has them)
	tactic.emit(&"hold")

## Standing its ground: face the prey; strike the moment something is ready, else beat again.
func _hold(delta: float) -> void:
	creature.stop_move()
	creature.face_towards(attack_target.global_position, delta)
	var d := _flat_dist(attack_target)
	if _offence(d, d <= reach_to(attack_target)):
		return
	_left -= delta
	if _left <= 0.0:
		_enter_circle()

func _start_feint() -> void:
	_beat()
	_just_disengaged = false
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
		_back_off()  # the step in is answered by a jump back out (or it stands there, daring)
		return
	if _left <= 0.0:
		_enter_circle()

## In the fight but not striking (circling, holding, between moves): a rig with an investigate loop stands in it
## (the compy's twitchy "itching for a fight" idle) instead of its calm idle.
func aware_idle() -> bool:
	return _valid_target() and not state in [&"roam", &"flee", &"retreat", &"disengage", &"sleep", &"dead", &"downed"]

func _start_lunge(into: StringName) -> void:
	_set_state(&"lunge")
	_lunge_into = into
	_left = _t("lunge_max_s", 1.2)
	_leaping = _t("leap_in_max_m", 0.0) > 0.0
	if _leaping:
		# Leap-in (ambushers): one long forward arc to biting distance instead of running in.
		var gap := maxf(0.0, _flat_dist(attack_target) - (reach_to(attack_target) - 0.4))
		creature.stop_move()
		_jump_begin(creature.global_position - _to_me() * minf(gap, _t("leap_in_max_m", 6.0)), &"pounce", _t("leap_in_s", 0.45), 0.0)
	tactic.emit(&"lunge")
	_log("[ai] %s %s -> %s" % [creature.def.id, "leap-in" if _leaping else "lunge", into])

## Short fast dash (or the leap-in arc) at the prey, then the bite or the combo at contact.
func _lunge(delta: float) -> void:
	_left -= delta
	if _leaping:
		creature.face_towards(attack_target.global_position, delta)
		if not _jump_tick(delta):
			return
		_jump_end()
		_leaping = false
		_left = 0.0  # landed: strike now if in reach, else back out
	else:
		speed_override = creature.move_speed_mps() * _t("lunge_speed_mult", 1.0)
		creature.move_to(attack_target.global_position)
	if _flat_dist(attack_target) <= _bite_reach() and _can_swing():
		if _lunge_into == &"bite_combo":
			if creature.try_special(&"bite_combo"):
				_combo()
			else:
				_back_off()
		else:
			_bite()
	elif _left <= 0.0:
		_back_off() if _flat_dist(attack_target) < ring_m() - 1.0 else _enter_circle()

## charge: the bite that ends a charge (an offensive move, not a basic: no anti-spam beat needed).
func _bite(charge: bool = false) -> void:
	_just_disengaged = false
	_charge_bite = charge
	if not charge:
		_beat_since_basic = false
		_basic_streak += 1
	creature.stop_move()
	# UTAHARMS (owner 2026-10-31: the utahraptor "just needs to use its arms in the attacks too sometimes"): a rig with
	# tactics.bite_alt plays that clip (the grab-and-bite) instead of the plain bite bite_alt_chance of the time.
	var alt := StringName(str(tac.get("bite_alt", "")))
	var clip := alt if alt != &"" and creature.anim.has_state(alt) and rng.randf() < _t("bite_alt_chance", 0.5) else &"attack_primary"
	creature.anim.play_clip(clip)
	last_bite_s = _now_s()
	_start_cd(&"bite")
	_set_state(&"attack")
	_mark_pack()
	tactic.emit(&"charge_bite" if charge else &"bite")

func _combo() -> void:
	_just_disengaged = false
	_basic_streak = 0
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
		_pack_cooldown_until[creature.pack_id] = _sim_s() + _t("pack_gap_s", 0.6)

## How close a running charge or lunge closes before it bites. tactics.bite_track (swarm, owner 2026-10-28: "it
## should land some attacks"): prey walking away gets a lead of its outward speed x the time to the bite's contact
## frame, so the jaws still reach her there. It used to slide the body after her during the bite, which glided
## (owner 2026-10-31); a bite now plays in place and the run carries it close enough first.
func _bite_reach() -> float:
	var r := reach_to(attack_target) - 0.1
	if not tac.get("bite_track", false):
		return r
	var v: Vector3 = attack_target.velocity if attack_target is CharacterBody3D else Vector3.ZERO
	var out := maxf(0.0, Vector3(v.x, 0.0, v.z).dot(-_to_me()))
	var to_hit := _clip_len(&"attack_primary", 0.4) * CreatureClips._hit_frac(&"attack_primary")
	return maxf(r * _t("bite_track_frac", 0.6), r - out * to_hit)

## Standing in a bite or the combo: face the prey, leap back out when the clip ends.
func _swing(delta: float) -> void:
	creature.stop_move()  # the bite plays in place (no glide): bite_track leads it instead (_bite_reach)
	if creature.anim.current_clip != &"kick":  # a hind kick keeps its back to the prey
		creature.face_towards(attack_target.global_position, delta)
	if not creature.anim._busy:
		_back_off()

## The ONE back-off after an attack: a leap back when allowed, else it holds its ground.
func _back_off() -> void:
	if _prey_leaving():
		_set_state(&"approach")  # she is leaving: after her, not away
	elif can_disengage():
		_start_hop(&"circle", true)
	else:
		_start_hold()

func _start_pounce() -> void:
	if not creature.try_special(&"pounce"):
		_enter_circle(0.3)
		return
	_set_state(&"pounce")
	_just_disengaged = false
	_basic_streak = 0
	_pounce_phase = &"windup"
	_left = _pounce_telegraph()
	creature.stop_move()
	# Windup pose: the heavy clip retimed to reach its strike frame as the windup ends. Coiled from a chase bound there is
	# no crouch: the pounce clip's own 0.2 crouch is the lead-in (the ring still shows from now to the hit).
	if _left > 0.05:
		creature.anim.play_timed_attack(&"attack_heavy", _left)
	_telegraph = Telegraph.show_pounce(creature, attack_target.global_position, _t("pounce_radius_m", 1.6) + _size_excess(attack_target), _left + 1.0)
	_start_cd(&"pounce")
	_mark_pack()
	tactic.emit(&"pounce")
	_log("[ai] %s pounce windup" % creature.def.id)

## The pounce, every physics frame. Windup: turning to the prey with the ring on it. Leap: the pounce
## clip (or a timed arc) to where the prey stood at take-off. Hit: at the pounce clip's hit_frac
## (anim_events), else the arc's end, a fixed time a roll's window can avoid. Then a short recovery.
func _pounce(delta: float) -> void:
	match _pounce_phase:
		&"windup":
			creature.face_towards(attack_target.global_position, delta)
			if is_instance_valid(_telegraph):
				_telegraph.global_position = attack_target.global_position
			_left -= delta
			if _left <= 0.0:
				_pounce_phase = &"leap"
				creature.anim.end_timed_attack()
				# Aim where the prey will be when it lands (lead by its velocity over the flight), and
				# sometimes sail past it (overshoot): a prey that stops or sidesteps is jumped over.
				var flight := _clip_len(&"pounce", _t("pounce_leap_s", 0.4)) * CreatureClips._hit_frac(&"pounce")
				var tv: Vector3 = attack_target.velocity if attack_target is CharacterBody3D else Vector3.ZERO
				var aim := attack_target.global_position + Vector3(tv.x, 0.0, tv.z) * flight
				var from := creature.global_position
				var dir := Vector3(aim.x - from.x, 0.0, aim.z - from.z)
				dir = dir.normalized() if dir.length_squared() > 0.01 else -_to_me()
				var land := aim - dir * _land_short()
				_overshot = rng.randf() < _t("pounce_overshoot_chance", 0.25) * creature.nature_knob("tactic_overshoot_mult", 1.0)
				if _overshot:
					land = aim + dir * _t("pounce_overshoot_m", 3.0)
				var far := maxf(_t("pounce_max_m", 8.0), _t("ambush_pounce_max_m", 0.0)) + _size_excess(attack_target) + (_t("pounce_overshoot_m", 3.0) if _overshot else 0.0)
				if from.distance_to(land) > far:
					land = from + (land - from).normalized() * far
				_pounce_dir = dir
				_jump_begin(land, &"pounce", _t("pounce_leap_s", 0.4), 0.0)
				_pounce_hit_u = _j_air.y if _j_timed else CreatureClips._hit_frac(&"pounce")
				_pounce_hit_done = false
				if is_instance_valid(_telegraph):
					_telegraph._life = _j_len * _pounce_hit_u + Telegraph.LINGER
				tactic.emit(&"leap")
		&"leap":
			var done := _jump_tick(delta)
			if not _pounce_hit_done and _j_t >= _j_len * _pounce_hit_u:
				_pounce_hit_done = true
				_pounce_land()
			if done:
				_jump_end()
				if _pounce_landed and _start_pin():
					return
				_pounce_phase = &"recover"
				# A miss (overshoot, or the prey stepped out) leaves it open longer: the punish window.
				_left = _t("pounce_recover_s", 0.7) if _pounce_landed else _t("pounce_miss_recover_s", 1.5)
				if not _pounce_landed:
					tactic.emit(&"pounce_miss")
		&"recover":
			_left -= delta
			if _left <= 0.0:
				_end_pounce()
				_back_off()

## clip: the part rows the hit is judged on (pipeline.hit_parts): the pounce's sabres, or a chase bound's forepaws (leap).
func _pounce_land(clip: StringName = &"pounce") -> void:
	var tgt := attack_target
	_pounce_landed = false
	var ahead := tgt.global_position - creature.global_position
	ahead.y = 0.0
	# Jaws first: prey it sailed past (behind it along the flight) is missed, however close. With hurtboxes the
	# pounce clip's parts decide below instead (the smilodon's sabres included); else a species with pounce hit
	# parts (pipeline.hit_parts) must also reach it with them.
	if not Hitbox.applies(creature, tgt) and (_flat_dist(tgt) > reach_to(tgt) + 0.3 or ahead.dot(_pounce_dir) < 0.0 or not creature.part_hit(clip, tgt)):
		_log("[ai] %s pounce missed" % creature.def.id)
		if tgt is Player or tgt is Creature:
			CombatAvoid.avoided(tgt, creature, &"miss")
		return
	if tgt is Player and (tgt as Player).dead:
		return
	# HITBOXES: the jaws and claws of the pounce clip must sweep through her hurtboxes.
	if Hitbox.applies(creature, tgt):
		var hit := Hitbox.strike(creature, clip, tgt)
		if hit.is_empty():
			_log("[ai] %s pounce missed (no part touched)" % creature.def.id)
			if tgt is Player or tgt is Creature:
				CombatAvoid.avoided(tgt, creature, &"miss")
			return
		Hitbox.mark(tgt, hit)
	# A roll is judged by CreatureAttack against the roll's opening window (RollRules), as for any bite.
	var mult := _t("pounce_mult", 2.5)
	_pounce_landed = true
	tactic_hit.emit(&"pounce", 0, mult)
	if CreatureAttack.apply_for(creature, &"attack_heavy", tgt, mult) and tgt is Player:
		(tgt as Player).receive_creature_hit(creature, &"attack_heavy")

## SP-DILOPHOSAURUS venom spit: it stops and faces the prey, the frill flares and the head draws back (the spit clip's
## windup) under a ground ring on the prey that follows her until the glob leaves; then the glob flies at where she
## stood (launch_spit), so stepping or rolling out of the ring dodges it. Not a basic: no anti-spam beat needed.
func _start_spit() -> void:
	_set_state(&"spit")
	_just_disengaged = false
	_basic_streak = 0
	_spit_fired = false
	creature.stop_move()
	creature.anim.play_clip(&"spit")
	_start_cd(&"spit")
	var wind := _clip_len(&"spit", 1.4) * CreatureClips._hit_frac(&"spit")
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = Telegraph.show_pounce(creature, attack_target.global_position, _t("spit_radius_m", 1.0) + _size_excess(attack_target), wind + 1.0, "SPIT - DODGE!")
	_mark_pack()
	tactic.emit(&"spit")
	_log("[ai] %s venom spit windup" % creature.def.id)

func _spit(delta: float) -> void:
	creature.stop_move()
	if not _spit_fired:
		creature.face_towards(attack_target.global_position, delta)
		if is_instance_valid(_telegraph):
			_telegraph.global_position = attack_target.global_position
	if not creature.anim._busy:
		_back_off()

## The spit clip's hit frame (Creature._on_hit): the glob leaves the jaws for the prey's chest where she stands now,
## at spit_speed_mps; it lands spit_mult x attack within spit_radius_m of that point (VenomSpit), Venom riding on it.
func launch_spit() -> VenomSpit:
	if state != &"spit" or _spit_fired or not _valid_target():
		return null
	_spit_fired = true
	var from := creature.global_position + Vector3.UP * creature.def.height_meters * creature.size_scale() * 0.7
	var sk: Skeleton3D = creature.view.rig.skeleton if creature.view and creature.view.rig else null
	var jaw := sk.find_bone("Jaw") if sk else -1
	if jaw >= 0:
		from = sk.global_transform * sk.get_bone_global_pose(jaw).origin
	var aim := attack_target.global_position
	aim.y = MeleeQuery.feet_y(attack_target) + minf(1.1, MeleeQuery.body_height(attack_target) * 0.6)
	var shot := VenomSpit.fire(creature, attack_target, from, aim, _t("spit_speed_mps", 16.0), _t("spit_mult", 0.8), _t("spit_radius_m", 1.0))
	if is_instance_valid(_telegraph):
		_telegraph.global_position = attack_target.global_position
		_telegraph._life = shot.flight_s() + Telegraph.LINGER
	tactic.emit(&"spit_launch")
	return shot

## Seconds a clip plays at its cadence, or fallback without the clip.
func _clip_len(clip: StringName, fallback: float) -> float:
	if not creature.anim.has_state(clip):
		return fallback
	return creature.anim.player.get_animation(clip).length / maxf(0.01, creature.anim.cadence(clip))

## One leap (pounce, leap-in, hop_back, leap_back) from here to `to`. With the clip the body moves only
## inside its airborne fracs (anim_events <clip>.airborne); without it the heavy clip is retimed over
## fallback_s and land_s follows. The arc height scales with the distance (leap_height_per_m).
func _jump_begin(to: Vector3, clip: StringName, fallback_s: float, land_s: float, height_per_m: float = -1.0) -> void:
	_j_loop = &""
	_j_from = creature.global_position
	_j_to = to
	_j_t = 0.0
	_j_height = (height_per_m if height_per_m >= 0.0 else _t("leap_height_per_m", 0.2)) * Vector2(to.x - _j_from.x, to.z - _j_from.z).length()
	_j_timed = not creature.anim.has_state(clip)
	if _j_timed:
		creature.anim.play_timed_attack(&"attack_heavy", fallback_s)
		_j_len = fallback_s + land_s
		_j_air = Vector2(0.0, fallback_s / maxf(0.01, _j_len))
		return
	if clip in CreatureClips.LOOPING:
		# A loop stands in (no dodge clip): played over fallback_s, the body moving the whole time.
		_j_loop = clip
		creature.anim.play_clip(clip)
		_j_len = fallback_s + land_s
		_j_air = Vector2(0.0, fallback_s / maxf(0.01, _j_len))
		_j_height = 0.0
		return
	creature.anim.play_clip(clip)
	_j_len = creature.anim.player.get_animation(clip).length / maxf(0.01, creature.anim.cadence(clip))
	_j_air = Vector2(0.2, 0.65)
	var air: Variant = ((Data.anim_events.get("clips", {}) as Dictionary).get(str(clip), {}) as Dictionary).get("airborne")
	if air is Array and (air as Array).size() == 2:
		_j_air = Vector2(float(air[0]), float(air[1]))

## One frame of the leap; true once the clip (or the timed landing) is over.
func _jump_tick(delta: float) -> bool:
	_j_t += delta
	if _j_loop != &"" and creature.anim.current_clip != _j_loop:
		creature.anim.play_clip(_j_loop)  # the body's idle reset would otherwise stop the stand-in loop
	var u := _j_t / maxf(0.01, _j_len)
	if u <= _j_air.y:
		_arc_step(_j_from, _j_to, clampf((u - _j_air.x) / maxf(0.01, _j_air.y - _j_air.x), 0.0, 1.0), _j_height)
	else:
		_arc_step(_j_from, _j_to, 1.0, _j_height)
		creature.view.position.y = 0.0
	return _j_t >= _j_len

func _jump_end() -> void:
	_j_loop = &""
	_b_phys = false
	if creature and creature.view:
		creature.view.position.y = 0.0
	if creature.anim.current_clip in [&"pounce", &"hop_back", &"leap_back", &"dodge_left", &"dodge_right", &"charge_turn", &"leap", &"flank_rake"]:
		creature.anim.release_oneshot()  # landed: the clip's last frame must not hold the next strike
	if _j_timed:
		_j_timed = false
		creature.anim.end_timed_attack()

## One frame of a leap: along from -> to at fraction f, the body (view) lifted on a sine arc.
func _arc_step(from: Vector3, to: Vector3, f: float, height: float) -> void:
	var step := from.lerp(to, f) - creature.global_position
	if _b_phys:
		# BURST CHASER bound: the body itself flies the arc (over steps) from its height to the landing ground, sliding
		# along anything it still meets; gravity is held off while it flies.
		step.y = lerpf(_b_from_y, _b_to_y, f) + sin(PI * f) * height - creature.global_position.y
		var hit := creature.move_and_collide(step)
		if hit:
			creature.move_and_collide(hit.get_remainder().slide(hit.get_normal()))
		creature.velocity.y = 0.0
		creature.view.position.y = 0.0
		return
	step.y = 0.0
	creature.move_and_collide(step)
	creature.view.position.y = sin(PI * f) * height

## Jump back away from the prey, facing it (never a walk back): hop_back over hop_m, or with `long`
## leap_back over leap_back_m (hop_back, then the timed arc, when the rig lacks it). Then `then` resumes.
func _start_hop(then: StringName = &"circle", long: bool = false, dist_mult: float = 1.0) -> void:
	creature.stop_move()
	_set_state(&"hop")
	_hop_then = then
	var clip := &"leap_back" if long and creature.anim.has_state(&"leap_back") else &"hop_back"
	var dist := (_t("leap_back_m", 5.0) if long else _t("hop_m", 3.5)) * dist_mult
	# Never past max_retreat_m from the prey: beyond it, it holds or re-engages instead.
	dist = clampf(dist, 0.0, maxf(0.0, _t("max_retreat_m", 11.0) - 0.3 - _flat_dist(attack_target)))
	_start_cd(&"hop")
	_just_disengaged = true
	_beat()
	_hop_to = creature.global_position + _to_me() * dist
	_scurry_left = _t("scurry_s", 0.6) if str(tac.get("backoff", "leap")) == "scurry" else 0.0
	if _scurry_left <= 0.0:
		_jump_begin(_hop_to, clip, _t("hop_s", 0.4), _t("hop_land_s", 0.15))
	tactic.emit(&"hop")

func _hop(delta: float) -> void:
	if _scurry_left > 0.0:
		# Scurry (swarm): dart back out at a run facing the prey (walk_back / strafes by direction).
		_scurry_left -= delta
		strafe_face = attack_target
		speed_override = creature.move_speed_mps()
		creature.move_to(_hop_to)
		if _scurry_left > 0.0 and _flat_dist_to(_hop_to) > 0.4:
			return
		_scurry_left = 0.0
		creature.stop_move()
	else:
		creature.face_towards(attack_target.global_position, delta)
		if not _jump_tick(delta):
			return
		_jump_end()
	if _hop_then == &"retreat":
		_set_state(&"retreat")
	elif _hop_then == &"approach":
		_set_state(&"approach")
	elif _hop_then == &"seq":
		_seq_next()
	elif _hop_then == &"bull":
		_bull_next()
	else:
		_enter_circle()

## BULL RESET (owner 2026-10-31, pachycephalosaurus: "instead of it walking back slowly, have it jump backwards and
## wind up like a bull, huff huff, and then charge"): after every charge, bull_hops quick back-hops of bull_hop_m
## (hop_back, facing the prey), then the display (its display_clip, the bull windup) and the charge again.
func _start_bull_reset() -> void:
	_bull_hops = int(_t("bull_hops", 2))
	_bull_next()

func _bull_next() -> void:
	if _bull_hops > 0:
		_bull_hops -= 1
		var dist := _t("bull_hop_m", 1.6)
		_start_hop(&"bull", false, dist / maxf(0.01, _t("hop_m", 3.5)))
		return
	_seq = [&"charge"]
	_seq_i = 0
	_start_display()

## The pounce's windup: shorter (or none) straight after a chase bound, the animal already coiled.
func _pounce_telegraph() -> float:
	if _coiled_left > 0.0 and tac.has("chase_pounce_telegraph_s"):
		return _t("chase_pounce_telegraph_s", 0.0)
	return _t("pounce_telegraph_s", 0.8)

func delta_s() -> float:
	return get_physics_process_delta_time()

## BURST CHASER, while the prey runs: a bound when she is bound.min_m-max_m off, a step hop when stuck, else a burst
## sprint (burst.mps for burst.s). True when it took off (state bound).
func _burst_chase(d: float, delta: float) -> bool:
	var b: Dictionary = tac.get("bound", {})
	if not b.is_empty() and creature.anim.has_state(&"leap") and _ready_to(&"bound"):
		# Stuck: chasing but hardly moving (move_and_slide already zeroed the velocity it ran into the step with).
		var got := creature.get_real_velocity()
		_stuck_t = _stuck_t + delta if Vector2(got.x, got.z).length() < 1.0 and creature.can_sprint() else 0.0
		if _stuck_t >= float(b.get("stuck_s", 0.3)):
			_start_bound(float(b.get("step_m", 3.0)))
			return true
		# Judged on the jump it would make: to where she will be when it lands, less the landing gap.
		var jump := _flat_dist_to(_bound_aim()) - _land_short()
		if creature.can_sprint() and jump >= float(b.get("min_m", 5.0)) and jump <= float(b.get("max_m", 10.0)) + _size_excess(attack_target) \
				and creature.try_special(&"leap"):
			_start_bound()
			return true
	var u: Dictionary = tac.get("burst", {})
	if u.is_empty():
		return false
	if _burst_left <= 0.0 and _ready_to(&"burst") and d >= float(u.get("min_m", 3.0)) and creature.can_sprint() and creature.try_special(&"burst"):
		_burst_left = float(u.get("s", 2.0))
		_start_cd(&"burst")
		tactic.emit(&"burst")
	if _burst_left > 0.0 and creature.can_sprint():
		speed_override = float(u.get("mps", 13.0)) / Creature.run_speed_mult()  # the sprint state multiplies it back
	return false

## One bound at the prey: aimed where she will be when it lands (her velocity over the flight), short of her by the body
## radius, or with cut-off (she runs across its line by more than bound.cutoff_deg) bound.cutoff_ahead_m beyond her on her
## own line, in her escape path. step_m > 0: the short hop over a step it was stuck on. The body itself rises on the arc
## (bound.height_m) and lands on the ground found under the landing point, so it clears steps and never ends in a slope.
func _start_bound(step_m: float = -1.0) -> void:
	var b: Dictionary = tac.get("bound", {})
	creature.stop_move()
	_set_state(&"bound")
	_start_cd(&"bound")
	_stuck_t = 0.0
	_beat()  # a bound is a beat: the swipe may follow it
	var from := creature.global_position
	var tv: Vector3 = attack_target.velocity if attack_target is CharacterBody3D else Vector3.ZERO
	tv.y = 0.0
	var to_prey := attack_target.global_position - from
	to_prey.y = 0.0
	var aim := _bound_aim()
	var dir := Vector3(aim.x - from.x, 0.0, aim.z - from.z)
	dir = dir.normalized() if dir.length_squared() > 0.01 else -_to_me()
	var cut := step_m <= 0.0 and tv.length() > 2.0 and rad_to_deg(tv.angle_to(to_prey)) > float(b.get("cutoff_deg", 35.0))
	var land := aim + tv.normalized() * float(b.get("cutoff_ahead_m", 2.0)) if cut else aim - dir * _land_short()
	var far := step_m if step_m > 0.0 else float(b.get("max_m", 10.0)) + _size_excess(attack_target)
	if step_m > 0.0:
		land = from + dir * step_m
	elif from.distance_to(land) > far:
		land = from + (land - from).normalized() * far
	var space := creature.get_world_3d().direct_space_state
	land.y = RagdollSkin.ground_y(space, land, [creature.get_rid()], from.y)
	_b_phys = true
	_b_struck = false
	_b_from_y = from.y
	_b_to_y = land.y
	_jump_begin(land, &"leap", _t("bound_s", 0.5), 0.0, float(b.get("height_per_m", 0.12)))
	_j_height = maxf(_j_height, float(b.get("min_height_m", 0.6)))
	tactic.emit(&"cutoff" if cut else (&"step_hop" if step_m > 0.0 else &"bound"))
	_log("[ai] %s %s %.1f m" % [creature.def.id, "cut-off leap" if cut else "bound", from.distance_to(land)])

## Where the prey will be when a bound launched now lands (her velocity over the flight).
func _bound_aim() -> Vector3:
	var tv: Vector3 = attack_target.velocity if attack_target is CharacterBody3D else Vector3.ZERO
	return attack_target.global_position + Vector3(tv.x, 0.0, tv.z) * _clip_len(&"leap", 0.75) * float(_leap_air().y)

func _leap_air() -> Vector2:
	var air: Variant = ((Data.anim_events.get("clips", {}) as Dictionary).get("leap", {}) as Dictionary).get("airborne")
	return Vector2(float(air[0]), float(air[1])) if air is Array and (air as Array).size() == 2 else Vector2(0.2, 0.65)

func _bound(delta: float) -> void:
	creature.face_towards(_j_to if _j_t < _j_len * _j_air.y else attack_target.global_position, delta)
	var done := _jump_tick(delta)
	# bound.strike: the forepaws come down on her as it lands (leap hit_parts) - the chase's pounce, pin and all. It is the
	# pounce (its cooldown, energy and pounce_mult), with no windup: a roll still dodges it (CreatureAttack's roll window).
	if not _b_struck and _j_t >= _j_len * _j_air.y:
		_b_struck = true
		if bool((tac.get("bound", {}) as Dictionary).get("strike", false)) and _ready_to(&"pounce") and creature.try_special(&"pounce"):
			_start_cd(&"pounce")
			_pounce_dir = Vector3(_j_to.x - _j_from.x, 0.0, _j_to.z - _j_from.z).normalized()
			_pounce_land(&"leap")
			if _pounce_landed:
				_jump_end()
				if _start_pin():
					return
	if not done:
		return
	_jump_end()
	_coiled_left = _t("coiled_s", 0.6)
	var d := _flat_dist(attack_target)
	# Landed: the swipe if she is in reach, the coiled pounce if she is in its range, else run on.
	if (d <= reach_to(attack_target) and _strike(d, ["bite"])) or _strike(d, ["pounce"]):
		return
	_set_state(&"approach")

func _end_pounce() -> void:
	if _pounce_phase == &"":
		return
	_pounce_phase = &""
	_jump_end()
	creature.anim.end_timed_attack()
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null

## PIN (tactics.pin, SP-SMILODON): a landed pounce holds the prey down under the forepaws. The prey gets Pinned (it cannot
## act; PINFEEL lays it down in its pinned pose) and is held pin_reach_m in front of the body while pin_stab drives the
## sabres in (anim_events pin_stab hit_fracs, x pin_mult each, from the Head part). It lets go when the clip ends, the
## prey is no longer Pinned, or either dies. Prey bigger than itself is not pinned.
func _start_pin() -> bool:
	if not tac.get("pin", false) or not creature.anim.has_state(&"pin_stab") or _pinnable(attack_target) == null:
		return false
	_hold_victim(attack_target, &"pin_stab")  # the state change first: leaving the pounce ends its timed clip
	creature.anim.play_clip(&"pin_stab")
	return true

## The statuses of prey this animal can hold down: a live survivor, or a live creature no bigger than itself.
func _pinnable(tgt: Node3D) -> StatusEffects:
	if tgt is Player and not (tgt as Player).dead:
		return (tgt as Player).statuses
	if tgt is Creature and not (tgt as Creature).health.dead and (tgt as Creature).body_radius() <= creature.body_radius():
		return (tgt as Creature).statuses
	return null

## Pin the prey for as long as `clip` (already playing or just started) runs: Pinned, the pin state, the hold.
func _hold_victim(tgt: Node3D, clip: StringName) -> bool:
	var st := _pinnable(tgt)
	if st == null:
		return false
	_set_state(&"pin")
	_pin_victim = tgt
	_pin_clip = clip
	st.apply(&"pinned", creature, 1)
	creature.stop_move()
	tactic.emit(&"pin")
	_log("[ai] %s pins %s" % [creature.def.id, tgt.name])
	return true

func _pin(delta: float) -> void:
	var v := _pin_victim
	var gone := not is_instance_valid(v) or (v is Player and ((v as Player).dead or not (v as Player).statuses.has(&"pinned"))) \
		or (v is Creature and ((v as Creature).health.dead or not (v as Creature).statuses.has(&"pinned")))
	if gone or creature.anim.current_clip != _pin_clip:
		_end_pin()
		if _valid_target():
			_back_off()
		return
	creature.stop_move()
	creature.face_towards(v.global_position, delta)
	# Held under the forepaws: slid toward the pin point in front of the chest (the stab lands there).
	var fwd := -creature.global_basis.z
	fwd.y = 0.0
	var hold := creature.global_position + fwd.normalized() * _t("pin_reach_m", 1.5) * creature.size_scale()
	var d := hold - v.global_position
	d.y = 0.0
	v.global_position += d * (1.0 - exp(-delta / 0.12))

func _end_pin() -> void:
	var v := _pin_victim
	_pin_victim = null
	if not is_instance_valid(v):
		return
	var st: StatusEffects = (v as Player).statuses if v is Player else ((v as Creature).statuses if v is Creature else null)
	if st:
		st.clear_id(&"pinned")

## SNAP-AND-SHAKE (tactics.grab, SP-SPINOSAURUS): the bite_shake clip at point blank. The windup (head drawn back, the
## long jaws gaping, claws raised, the ground ring on her) is the tell; at the clip's hit_frac (anim_events) the jaws
## clamp, and only if they reach her (pipeline.hit_parts.bite_shake) she is caught: carried between the jaws with no
## control while the head thrashes (x grab_mult on the clamp), then flung off to its left at release_frac (shove + lift:
## the throw tier once PlayerKnock is on canon). A miss snaps shut on air and leaves it open for the rest of the clip.
var _grab_t := 0.0
var _grab_len := 0.0
var _grab_done := false
var _held: Player = null
var _held_y := 0.0
## Where the clamp caught her (metres from the jaw point to her, -1 before one, INF on a miss): read by t_sp_spinosaurus.
var grab_gap := -1.0

func _start_grab() -> void:
	_just_disengaged = false
	_basic_streak = 0
	creature.stop_move()
	creature.anim.play_clip(&"bite_shake")
	_grab_len = creature.anim.player.get_animation(&"bite_shake").length
	_grab_t = 0.0
	_grab_done = false
	_set_state(&"grab")
	var hit := _grab_len * CreatureClips._hit_frac(&"bite_shake")
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = Telegraph.show_pounce(creature, attack_target.global_position, _t("grab_radius_m", 2.0) + _size_excess(attack_target), hit / maxf(0.01, creature.anim.cadence(&"bite_shake")))
	_mark_pack()
	tactic.emit(&"grab")
	_log("[ai] %s snap-and-shake windup" % creature.def.id)

func _grab(delta: float) -> void:
	# Clip time as the tree plays it (the travel into bite_shake cross-fades, so a wall clock runs ~0.15 s ahead of the pose).
	var an := creature.anim
	_grab_t = an._os_t if an._os_state == &"bite_shake" and an._os_last >= 0.0 else _grab_t
	creature.stop_move()
	var row: Dictionary = (Data.anim_events.get("clips", {}) as Dictionary).get("bite_shake", {})
	var hit := _grab_len * float(row.get("hit_frac", 0.3))
	var release := _grab_len * float(row.get("release_frac", 0.78))
	if not _grab_done:
		creature.face_towards(attack_target.global_position, delta)  # tracks her through the windup
		if is_instance_valid(_telegraph):
			_telegraph.global_position = attack_target.global_position
		if _grab_t >= hit:
			_grab_done = true
			_grab_clamp()
	if _held:
		if _grab_t < release and is_instance_valid(_held) and not _held.dead:
			_hold_in_jaws()
		else:
			_grab_fling()
	if _grab_t >= _grab_len or creature.anim.current_clip != &"bite_shake":
		_end_grab()
		if _valid_target():
			_back_off()

func _hold_in_jaws() -> void:
	var at := grab_point()
	_held.global_position = Vector3(at.x, maxf(at.y - 0.9, _held_y), at.z)  # her middle in the jaws, never in the ground
	_held.velocity = Vector3.ZERO

## Held prey follows the jaws on the drawn pose too: the thrash swings the snout metres per frame, and the physics-rate
## think runs before the animation advances. process_priority (setup) puts this after the creature's AnimationTree.
func _process(_delta: float) -> void:
	if _held != null and is_instance_valid(_held) and state == &"grab":
		_hold_in_jaws()

## The jaw point: 60 % of the way from the jaw hinge to the snout tip (between the jaws), on the live pose.
func grab_point() -> Vector3:
	var rig := creature.view.rig if creature.view else null
	var sk := rig.skeleton if rig else null
	var jaw := sk.find_bone("Jaw") if sk else -1
	if jaw < 0:
		return horn_tip()
	var hinge := sk.global_transform * sk.get_bone_global_pose(jaw).origin
	return hinge.lerp(horn_tip(), 0.6)

func _grab_clamp() -> void:
	var tgt := attack_target
	var ahead := tgt.global_position - creature.global_position
	ahead.y = 0.0
	if _flat_dist(tgt) > reach_to(tgt) + 0.3 or ahead.dot(-creature.global_basis.z) < 0.0 or not creature.part_hit(&"bite_shake", tgt):
		grab_gap = INF
		tactic.emit(&"grab_miss")
		if tgt is Player or tgt is Creature:
			CombatAvoid.avoided(tgt, creature, &"miss")
		return
	grab_gap = _flat_between(grab_point(), tgt.global_position)
	var mult := _t("grab_mult", 1.6)
	tactic_hit.emit(&"bite_shake", 0, mult)
	tactic.emit(&"grab_hit")
	if not CreatureAttack.apply_for(creature, &"bite_shake", tgt, mult):
		return
	if tgt is Player:
		var pl := tgt as Player
		pl.receive_creature_hit(creature, &"bite_shake")
		if pl.sim and not pl.dead:
			_held = pl
			_held_y = pl.global_position.y
			pl.sim.shove(-creature.global_basis.z * 0.01, _grab_len)  # no control while in the jaws; the fling sets the throw

## Flung off to its left (the clip whips the head that way and opens the jaws): grab_fling_m along the ground, up at grab_up_mps.
func _grab_fling() -> void:
	if _held == null or not is_instance_valid(_held):
		_held = null
		return
	var pl := _held
	_held = null
	var dir := (-creature.global_basis.x - creature.global_basis.z * 0.4)
	dir.y = 0.0
	var up := _t("grab_up_mps", 5.0)
	# KNOCKDOWN (on canon since this branch): the lift makes it a throw (PlayerKnock), as the rhino's toss.
	pl.sim.shove(dir.normalized() * _t("grab_fling_m", 5.0), 2.0 * up / 9.8, up, creature)
	if not pl.sim.knock.active():
		pl.velocity.y = up  # rolling, swimming or pinned: the plain shove with the old lift
	tactic.emit(&"grab_fling")

func _end_grab() -> void:
	_grab_fling()
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null

func _start_retreat(seconds: float) -> void:
	if str(tac.get("retreat_mode", "leap")) == "flee":
		_start_flee(_t("flee_s", 3.0))
		_retreat_cd = _t("retreat_cd", 10.0)
		return
	_end_pounce()
	_retreat_left = seconds
	_retreat_cd = _t("retreat_cd", 10.0)
	_wide_left = maxf(_wide_left, _t("wide_circle_s", 4.0))
	tactic.emit(&"retreat")
	_just_disengaged = false  # being hurt earns a back-leap
	_start_hop(&"retreat", true, _t("retreat_hop_mult", 1.2))

## Hurt: jump back (again while still inside the wide ring), then strafe the wide ring facing the prey
## until the retreat time is up; the wide ring holds for wide_circle_s before it re-engages.
func _retreat_tick(delta: float) -> void:
	_wide_left = maxf(_wide_left, _t("wide_circle_s", 4.0))
	if _flat_dist(attack_target) < ring_m() - 1.0 and can_disengage():
		_start_hop(&"retreat", true, _t("retreat_hop_mult", 1.2))
		return
	strafe_face = attack_target
	speed_override = creature.walk_mps(creature.move_speed_mps()) * _t("retreat_speed_frac", 1.2)
	var step := deg_to_rad(_t("circle_step_deg", 35.0)) * _circle_sign
	creature.move_to(attack_target.global_position + _to_me().rotated(Vector3.UP, step) * ring_m() / cos(step))
	_retreat_left -= delta
	if _retreat_left <= 0.0:
		_enter_circle()

## Swarm flight: run from the prey (BrainFlight.flee) for `seconds`, then come back to the fight.
func _start_flee(seconds: float) -> void:
	_end_pounce()
	_seq = []
	_flee_left = maxf(_flee_left, seconds)
	_set_state(&"flee")
	tactic.emit(&"flee")

## FLANK (tactics.flank, RAPTORFLANK; owner 2026-10-31 on the raptor: "There should be a move that's like run past,
## turn, strafe, attack from behind"). A sequence finisher in four phases:
##   pass   - runs at the charge gait past the prey on one side, to flank_past_m beyond its line and flank_lane_m out
##   turn   - the charge_turn clip (a skid-turn hop): the yaw swings round to the prey, the short way, only while airborne
##   strafe - sidesteps round the prey facing it (the strafe clips, stride-matched) on flank_ring_m toward its back (where
##            its back was when the flank began), until it stands more than flank_behind_deg off the prey's facing (after
##            flank_strafe_min_s, so the strafe shows). A survivor who keeps turning to face it can deny her live back;
##            then it rakes from where her back was (# ASSUMPTION: the counter is turning, the move still finishes)
##   rake   - the flank_rake leap from behind onto it (the brain carries the arc inside the clip's airborne window);
##            at its hit_frac both sickle feet and the jaws must reach it (pipeline.hit_parts flank_rake), x flank_mult
## It gives up (back to the ring) when the strafe runs out of time before it gets behind. # ASSUMPTION every number.
var _flank_phase: StringName = &""
var _flank_to := Vector3.ZERO
var _flank_dir := Vector3.FORWARD
var _flank_turn_from := 0.0
var _flank_hit_done := false
var _flank_landed := false
var _flank_face0 := Vector3.FORWARD  ## the prey's facing when the flank began
## Degrees off the prey's facing when the rake took off (tests, labs).
var flank_behind_deg := 0.0

## The way the prey faces: a survivor's model (it turns without the body), else the body.
func _prey_facing() -> Vector3:
	var b: Basis = (attack_target as Player).visual.global_basis if attack_target is Player and (attack_target as Player).visual else attack_target.global_basis
	var f := -b.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD

## How far round from the prey's facing it stands (0 = in front of it, 180 = straight behind).
func behind_deg() -> float:
	return rad_to_deg(_prey_facing().angle_to(_to_me()))

func _start_flank() -> void:
	_set_state(&"flank")
	_seq = []
	_just_disengaged = false
	_basic_streak = 0
	_flank_dir = -_to_me()  # toward the prey
	_flank_face0 = _prey_facing()
	# Past it on the side its back is nearer (the shorter strafe afterwards), else a coin flip.
	var side_v := Vector3(-_flank_dir.z, 0.0, _flank_dir.x)
	var s := signf(side_v.dot(-_prey_facing()))
	if s == 0.0:
		s = 1.0 if rng.randf() < 0.5 else -1.0
	_flank_to = attack_target.global_position + _flank_dir * _t("flank_past_m", 3.0) + side_v * s * _t("flank_lane_m", 4.5)
	_flank_phase = &"pass"
	_left = _t("flank_pass_max_s", 3.0)
	_mark_pack()
	tactic.emit(&"flank")
	_log("[ai] %s flank: runs past" % creature.def.id)

func _flank(delta: float) -> void:
	match _flank_phase:
		&"pass":
			_left -= delta
			speed_override = creature.move_speed_mps() * _t("charge_speed_mult", 1.5)
			gait_clip = &"charge" if creature.anim.has_state(&"charge") else &""
			# A carrot at most 8 m ahead on the line: Creature steers straight at a goal within 12 m when the nav map has
			# no path yet (sparse labs), and the pass is a straight dash anyway.
			var ahead := _flank_to - creature.global_position
			ahead.y = 0.0
			creature.move_to(_flank_to if ahead.length() <= 8.0 else creature.global_position + ahead.normalized() * 8.0)
			if _flat_dist_to(_flank_to) <= _t("flank_arrive_m", 1.5) or _left <= 0.0:
				_flank_phase = &"turn"
				creature.stop_move()
				_flank_turn_from = creature.rotation.y
				var run := -creature.global_basis.z
				run.y = 0.0
				_jump_begin(creature.global_position + run.normalized() * _t("flank_skid_m", 1.5), &"charge_turn", 0.7, 0.0, 0.05)
				tactic.emit(&"flank_turn")
		&"turn":
			var to := attack_target.global_position - creature.global_position
			var turn := wrapf(atan2(-to.x, -to.z) - _flank_turn_from, -PI, PI)  # the short way round
			var done := _jump_tick(delta)
			var u := clampf((_j_t / maxf(0.01, _j_len) - _j_air.x) / maxf(0.01, _j_air.y - _j_air.x), 0.0, 1.0)
			creature.rotation.y = _flank_turn_from + turn * u * u * (3.0 - 2.0 * u)
			if done:
				_jump_end()
				_flank_phase = &"strafe"
				_left = _t("flank_strafe_max_s", 4.0)
				_circle_t = 0.0
				tactic.emit(&"flank_strafe")
		&"strafe":
			_left -= delta
			_circle_t += delta
			var behind := behind_deg()
			var behind_then := rad_to_deg(_flank_face0.angle_to(_to_me()))
			if _circle_t >= _t("flank_strafe_min_s", 0.8) and maxf(behind, behind_then) >= _t("flank_behind_deg", 140.0) \
					and _flat_dist(attack_target) <= _t("flank_rake_max_m", 7.0) + _size_excess(attack_target):
				_start_flank_rake(behind)
				return
			if _left <= 0.0:
				tactic.emit(&"flank_abort")
				_end_flank()
				_enter_circle()
				return
			strafe_face = attack_target
			speed_override = _t("flank_strafe_mps", 2.2) * creature.size_scale()
			# Toward the prey's back: the short way round, on flank_ring_m.
			var back := -_prey_facing() if behind >= behind_then else -_flank_face0
			var sgn := signf(_to_me().cross(back).y)
			var step := deg_to_rad(_t("circle_step_deg", 35.0)) * (sgn if sgn != 0.0 else 1.0)
			creature.move_to(attack_target.global_position + _to_me().rotated(Vector3.UP, step) * _t("flank_ring_m", 5.5) / cos(step))
		&"rake":
			creature.face_towards(attack_target.global_position, delta)
			var done := _jump_tick(delta)
			if not _flank_hit_done and _j_t >= _j_len * CreatureClips._hit_frac(&"flank_rake"):
				_flank_hit_done = true
				_flank_rake_hit()
			if done:
				_jump_end()
				_flank_phase = &"recover"
				_left = _t("flank_recover_s", 0.5) if _flank_landed else _t("flank_miss_recover_s", 1.2)
		&"recover":
			creature.stop_move()
			_left -= delta
			if _left <= 0.0:
				_end_flank()
				_back_off()

func _start_flank_rake(behind: float) -> void:
	_flank_phase = &"rake"
	flank_behind_deg = behind
	_flank_hit_done = false
	_flank_landed = false
	creature.stop_move()
	var land := attack_target.global_position + _to_me() * (_t("flank_land_m", 2.4) * creature.size_scale() + _size_excess(attack_target))
	_jump_begin(land, &"flank_rake", 0.5, 0.0, _t("flank_height_per_m", 0.15))
	tactic.emit(&"flank_rake")
	_log("[ai] %s flank: rakes from behind (%.0f deg off its facing)" % [creature.def.id, behind])

func _flank_rake_hit() -> void:
	var tgt := attack_target
	if _flat_dist(tgt) > reach_to(tgt) + 0.6 or not creature.part_hit(&"flank_rake", tgt):
		_log("[ai] %s flank rake missed" % creature.def.id)
		if tgt is Player or tgt is Creature:
			CombatAvoid.avoided(tgt, creature, &"miss")
		return
	if tgt is Player and (tgt as Player).dead:
		return
	var mult := _t("flank_mult", 2.0)
	_flank_landed = true
	tactic_hit.emit(&"flank_rake", 0, mult)
	tactic.emit(&"flank_hit")
	if CreatureAttack.apply_for(creature, &"attack_heavy", tgt, mult) and tgt is Player:
		(tgt as Player).receive_creature_hit(creature, &"attack_heavy")

func _end_flank() -> void:
	if _flank_phase == &"":
		return
	_flank_phase = &""
	_jump_end()

func _on_state_changed(prev: StringName, _next: StringName) -> void:
	if prev == &"spit" and not _spit_fired and is_instance_valid(_telegraph):
		_telegraph.queue_free()  # cut off before the glob left (hit, knocked down): no ring for a spit that never comes
	if prev == &"flank":
		_end_flank()
	if prev == &"charge":
		_charge_cleanup()  # never leave her hanging on the horn
	if prev == &"pin":
		_end_pin()
	if prev == &"grab":
		_end_grab()
	if prev == &"pounce":
		_end_pounce()
	elif prev == &"hop" or prev == &"lunge" or prev == &"dodge" or prev == &"bound":
		_jump_end()
		_leaping = false

func _exit_tree() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
