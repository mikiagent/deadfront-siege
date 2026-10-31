class_name CreatureAnim
extends Node
## AnimationTree state machine over the clip contract. Every state is clip -> TimeScale because a
## tree ignores AnimationPlayer.speed_scale: cadence, boss retiming and set_time_scale live here.

signal attack_windup(clip: StringName)
signal attack_hit(clip: StringName)
signal attack_done
signal knockdown_started
signal knockdown_ended
signal died

## One-shots that block locomotion until they finish; the attacks among them fire attack_hit.
const ONESHOT: Array[StringName] = [&"attack_primary", &"attack_heavy", &"tail_swipe", &"bite_combo", &"hop_back", &"leap_back", &"pounce", &"dodge_left", &"dodge_right", &"hit_react", &"alert", &"kick", &"sniff", &"charge_crouch", &"toss", &"pin_stab", &"spit", &"charge_turn", &"charge_windup", &"impale", &"charge_recover"]
const ATTACKS: Array[StringName] = [&"attack_primary", &"attack_heavy", &"tail_swipe", &"bite_combo", &"kick", &"pin_stab", &"spit"]
## One-shots during which a brain moves the body itself on an arc (TacticalBrain._arc_step), not by walking.
const LEAPS: Array[StringName] = [&"hop_back", &"leap_back", &"pounce", &"dodge_left", &"dodge_right", &"charge_turn"]
const HUBS: Array[StringName] = [&"idle", &"walk", &"run"]
const XFADE := 0.08
const GAIT_XFADE := 0.2  # walk <-> run: long enough that a gait change never pops
const PIN_XFADE := 0.3  # the stomp into the pin, and the foot back to its print on release
const LEGACY_TOP_MPS := 8.0  # creature.gd passes play_locomotion(speed / 8)
## ASSUMPTION: cadence guard for set_move_speed. Wide on purpose: several donor clips barely
## stride (megaloceros run 0.42 m/s natural at 7.6 m/s), and matching the ground beats a slide.
const CADENCE_MIN := 0.1
const CADENCE_MAX := 16.0

var timed_attack := false
var current_clip: StringName = &"idle"
var tree: AnimationTree
var player: AnimationPlayer
var _playback: AnimationNodeStateMachinePlayback
var _busy: bool = false
var _hold_knockdown: bool = false
## PINFEEL: holding pin_foot (a foot on a Pinned victim) until Creature.end_pin; nothing but death replaces it.
var _pinning: bool = false
var _dead: bool = false
var _forced: bool = false
var _def: CreatureDef
var _time_factors: Dictionary = {}  ## named retime factors (&"base", &"fracture", hit-stop...) multiplied together
var _time_scale := 1.0  ## product of _time_factors
var _scale: Dictionary = {}  ## state -> cadence before the global time scale
var _param: Dictionary = {}  ## state -> "parameters/<state>/ts/scale"; also the set of built states
var _natural: Dictionary = {}  ## &"walk" / &"run" -> planted-foot ground speed at cadence 1 (m/s)
## The one-shot being watched for its hit and end frames, in tree time so a mid-clip time-scale
## change (hit-stop, slows) moves them with the visible swing.
var _os_state: StringName = &""
var _os_t := 0.0
var _os_last := -1.0
var _os_hit_done := true
var _os_fracs: Array[float] = []
var _os_windup_frac := -1.0
## Index of the hit attack_hit just fired for (0, 1, 2 for bite_combo's three bites; 0 otherwise).
var hit_index := 0

func setup(ap: AnimationPlayer, at: AnimationTree) -> void:
	player = ap
	tree = at
	var host := get_parent() as Creature
	_def = host.def if host else null
	for gait in [&"walk", &"run"]:
		if player.has_animation(gait):
			var anim := player.get_animation(gait)
			CreatureClips.trim_frozen_tail(anim, "%s/%s" % [_def.id, gait] if _def else "")
			var nat := CreatureClips.natural_speed(_def, gait, anim.length)
			if nat > 0.0:
				_natural[gait] = nat
	_build_tree()
	tree.anim_player = tree.get_path_to(player)
	tree.active = true
	tree.mixer_applied.connect(_poll_oneshot)  # also fires on manual advance(); mixer_updated does not
	_playback = tree.get("parameters/playback")
	play_idle()

## aware: the brain knows of prey but is not attacking; a rig with an investigate loop plays it instead of idle.
func play_idle(aware: bool = false) -> void:
	if _dead or _hold_knockdown or _pinning:
		return
	var state := &"investigate" if aware and _param.has(&"investigate") else &"idle"
	_scale[state] = CreatureClips.clip_speed(state, _def)
	_travel(state)

## Legacy gait pick from creature.gd's speed / 8. Run now really plays at its anim_events cadence.
func play_locomotion(speed_frac: float) -> void:
	if not _can_move():
		return
	var gait := &"run" if speed_frac > 0.55 else &"walk"
	_scale[gait] = CreatureClips.clip_speed(gait, _def)
	_travel(gait)

## Stride-matched locomotion: picks the gait whose natural stride suits mps and sets its cadence to
## mps / natural speed, so a planted foot keeps pace with the ground instead of sliding.
func set_move_speed(mps: float) -> void:
	if not is_finite(mps) or not _can_move():
		return
	if mps <= 0.05:
		play_idle()
		return
	if _natural.is_empty():
		play_locomotion(mps / LEGACY_TOP_MPS)
		return
	var gait := _pick_gait(mps)
	_scale[gait] = clampf(mps / float(_natural[gait]), CADENCE_MIN, CADENCE_MAX)
	_travel(gait)

## Direction-aware locomotion (owner 2026-10-28, every species and ridden mounts): the clip follows
## the velocity against the body's facing. Forward: walk/run (set_move_speed). Against facing
## (dot < -0.5): walk_back. Mostly sideways (|dot with right| > 0.7): strafe_left / strafe_right.
## Each is stride-matched; a rig without the clip falls back to the forward gait.
const BACK_DOT := -0.5
const SIDE_DOT := 0.7
## While a brain sidesteps facing its prey (strafe_face: circling the ring, a scurry), a diagonal past 60 deg
## off the facing is still a sidestep (owner 2026-10-28: "strafe left and strafe right animations are needed on
## compsagnathus"); at the default 0.7 a surround slot reached on a diagonal glided on the forward walk.
const FACING_SIDE_DOT := 0.5

static func pick_direction(vel: Vector3, basis: Basis, side_dot: float = SIDE_DOT) -> StringName:
	var v := Vector3(vel.x, 0.0, vel.z)
	if v.length_squared() < 0.0001:
		return &""
	v = v.normalized()
	var side := v.dot(basis.x)  # the body faces -Z, so +X is its right
	if absf(side) > side_dot:
		return &"strafe_right" if side > 0.0 else &"strafe_left"
	if v.dot(-basis.z) < BACK_DOT:
		return &"walk_back"
	return &""

func set_move_velocity(vel: Vector3, basis: Basis, side_dot: float = SIDE_DOT) -> void:
	var mps := Vector2(vel.x, vel.z).length()
	var clip := pick_direction(vel, basis, side_dot)
	if clip == &"" or not _param.has(clip) or mps <= 0.05:
		set_move_speed(mps)
		return
	if not _can_move():
		return
	# Sidesteps and walk_back (the walk reversed) stride like the walk: natural_speeds.<id>.<clip> when
	# baked, else the walk's natural speed (ASSUMPTION for the strafes).
	var nat := CreatureClips.natural_speed(_def, clip)
	if nat <= 0.0:
		nat = float(_natural.get(&"walk", 0.0))
	_scale[clip] = clampf(mps / nat, CADENCE_MIN, CADENCE_MAX) if nat > 0.0 else 1.0
	_travel(clip)

## A named loop (the charge) stride-matched at mps: natural_speeds.<id>.<clip>, else the run's. Falls
## back to the direction-aware gait when the rig lacks it.
func set_gait_clip(clip: StringName, mps: float, vel: Vector3, basis: Basis) -> void:
	if not _param.has(clip):
		set_move_velocity(vel, basis)
		return
	if not is_finite(mps) or not _can_move():
		return
	var nat := CreatureClips.natural_speed(_def, clip)
	if nat <= 0.0:
		nat = float(_natural.get(&"run", 0.0))
	_scale[clip] = clampf(mps / nat, CADENCE_MIN, CADENCE_MAX) if nat > 0.0 else 1.0
	_travel(clip)

## Global retime on top of every state's own cadence. Each caller owns a named factor (the limp is
## &"fracture", a hit-stop its own key) and the tree plays at their product, so one never erases another.
func set_time_scale(x: float, factor: StringName = &"base") -> void:
	if not is_finite(x):
		return
	_time_factors[factor] = maxf(0.0, x)
	_time_scale = 1.0
	for f in _time_factors.values():
		_time_scale *= float(f)
	for state in _scale:
		_apply(state)

func play_clip(clip: StringName, forced: bool = false) -> void:
	if _dead and clip != &"death":
		return
	if _pinning:
		if clip != &"death":
			return
		_pinning = false
	var state := clip if _param.has(clip) else &"idle"  # sleep / tail_swipe exist on some species only
	_forced = forced
	_busy = state in ONESHOT
	if state == &"knockdown":
		_hold_knockdown = true
		knockdown_started.emit()
	if state == &"death":
		timed_attack = false
		_dead = true
		died.emit()
	if state == &"attack_heavy":
		attack_windup.emit(state)
	_scale[state] = CreatureClips.clip_speed(state, _def)
	_travel(state)
	if state in ONESHOT:
		_os_state = state
		_os_t = 0.0
		_os_last = -1.0
		_os_hit_done = state not in ATTACKS
		_os_fracs = CreatureClips.hit_fracs(state)
		var tell: Variant = ((Data.anim_events.get("clips", {}) as Dictionary).get(str(state), {}) as Dictionary).get("tell_fracs")
		_os_windup_frac = float((tell as Array)[0]) if state in ATTACKS and tell is Array and not (tell as Array).is_empty() else -1.0
		hit_index = 0

## End a non-attack one-shot now (a brain that timed the move itself, e.g. a leap that has landed).
func release_oneshot() -> void:
	if not _busy or timed_attack or current_clip in ATTACKS:
		return
	_os_state = &""
	_busy = false
	_forced = false
	play_idle()

## PINFEEL: cut to pin_foot (it starts on the stomp's impact frame) and hold it; false when the rig has no
## pin_foot. A timed attack in flight (the tyrant's stomp) hands over to it.
func start_pin() -> bool:
	if _dead or not _param.has(&"pin_foot"):
		return false
	timed_attack = false
	_os_state = &""
	_busy = false
	_forced = true
	_pinning = true
	_scale[&"pin_foot"] = CreatureClips.clip_speed(&"pin_foot", _def)
	_travel(&"pin_foot")
	return true

func end_pin() -> void:
	if not _pinning:
		return
	_pinning = false
	_forced = false
	play_idle()

func is_pinning() -> bool:
	return _pinning

## PINFEEL: a Pinned animal lies in its knockdown pose for the pin. Unlike play_clip(&"knockdown") it opens no
## capture window (knockdown_started); off stands it up unless the Knockdown status still holds it.
func hold_down(on: bool) -> void:
	if on:
		if _dead:
			return
		_pinning = false
		_busy = false
		_forced = false
		_hold_knockdown = true
		_scale[&"knockdown"] = CreatureClips.clip_speed(&"knockdown", _def)
		_travel(&"knockdown")
	elif _hold_knockdown:
		_hold_knockdown = false
		play_idle()

func release_knockdown() -> void:
	_hold_knockdown = false
	_forced = false
	knockdown_ended.emit()
	if not _dead:
		play_idle()

func on_event(kind: String, clip: String) -> void:
	if timed_attack: return
	if kind == "hit":
		attack_hit.emit(StringName(clip))
	elif kind == "windup":
		attack_windup.emit(StringName(clip))

## Boss controller owns impact/recovery: the clip is retimed so its hit frame lands at windup.
func play_timed_attack(clip: StringName, windup: float) -> void:
	timed_attack = true
	_busy = true
	_forced = true
	var anim := player.get_animation(clip) if player and player.has_animation(clip) else null
	_scale[clip] = maxf(0.01, anim.length * CreatureClips._hit_frac(clip) / windup) if anim and windup > 0.0 else 1.0
	_travel(clip)

func end_timed_attack() -> void:
	if not timed_attack: return
	timed_attack = false
	_busy = false
	_forced = false
	if not _dead: play_idle()

func _can_move() -> bool:
	return not (_busy or _dead or _hold_knockdown or _forced or _pinning)

func _pick_gait(mps: float) -> StringName:
	var w := float(_natural.get(&"walk", 0.0))
	var r := float(_natural.get(&"run", 0.0))
	if w <= 0.0:
		return &"run"
	if r <= w:
		return &"walk"  # a run clip that strides no faster than the walk only adds cadence
	# ASSUMPTION: switch at the geometric mean, where either gait is equally far from cadence 1;
	# 10 % hysteresis stops flapping at the boundary.
	var cut := sqrt(w * r) * (0.9 if current_clip == &"run" else 1.1)
	return &"run" if mps > cut else &"walk"

## Runs after every tree update (idle or manual advance): fires attack_hit at the clip's hit
## fraction and ends the one-shot at its last frame, both measured in tree time.
func _poll_oneshot() -> void:
	if _os_state == &"" or timed_attack:
		return
	if current_clip != _os_state:
		_os_state = &""
		return
	if _playback.get_current_node() != _os_state:
		return  # the travel lands on the next update
	var length := _playback.get_current_length()
	var pos := _playback.get_current_play_position()
	_os_t = pos if _os_last < 0.0 else _os_t + (fposmod(pos - _os_last, length) if length > 0.0 else 0.0)
	_os_last = pos
	# tell_fracs [start, end] (anim_events): the tell before a combo's last bite raises its ring at start.
	if _os_windup_frac >= 0.0 and _os_t >= length * _os_windup_frac:
		_os_windup_frac = -1.0
		attack_windup.emit(_os_state)
	while not _os_hit_done and hit_index < _os_fracs.size() and _os_t >= length * _os_fracs[hit_index]:
		var clip := _os_state
		attack_hit.emit(clip)
		hit_index += 1
		_os_hit_done = hit_index >= _os_fracs.size()
	if _os_state == &"":
		return
	if _os_t >= length - 0.001 or pos >= length - 0.001:
		var done := _os_state
		_os_state = &""
		_oneshot_done(done)

func _oneshot_done(clip: StringName) -> void:
	if timed_attack: return
	if current_clip != clip:
		return
	_busy = false
	_forced = false
	if clip in ATTACKS:
		attack_done.emit()
	play_idle()

func _effective(state: StringName) -> float:
	return float(_scale.get(state, 1.0)) * _time_scale

func _apply(state: StringName) -> void:
	if tree and _param.has(state):
		tree.set(_param[state], _effective(state))

func _travel(state: StringName) -> void:
	_apply(state)
	current_clip = state
	if _playback:
		if state in ONESHOT and _playback.get_current_node() == state:
			_playback.start(str(state))  # travel to the node the machine is still on would not replay it
		else:
			_playback.travel(str(state))

## Read-only views for tests and labs.
func current_state() -> StringName:
	return _playback.get_current_node() if _playback else &""

func is_busy() -> bool:
	return _busy

func cadence(state: StringName) -> float:
	return _effective(state)

func has_state(clip: StringName) -> bool:
	return _param.has(clip)

func _build_tree() -> void:
	var sm := AnimationNodeStateMachine.new()
	for clip in CreatureClips.CONTRACT + CreatureClips.OPTIONAL:
		if player.has_animation(clip):
			sm.add_node(clip, _clip_node(clip))
			_param[clip] = StringName("parameters/%s/ts/scale" % clip)
	for a in HUBS:
		for b in HUBS:
			if a != b and _param.has(a) and _param.has(b):
				_trans(sm, a, b, GAIT_XFADE if a != &"idle" and b != &"idle" else XFADE)
	for clip in _param:
		if clip in HUBS:
			continue
		# The investigate loop holds a deep crouch: a longer blend in and out so the body does not drop in one frame.
		var xf := GAIT_XFADE if clip == &"investigate" else (PIN_XFADE if clip == &"pin_foot" else XFADE)
		for hub in HUBS:
			if _param.has(hub):
				_trans(sm, hub, clip, xf)
				_trans(sm, clip, hub, xf)  # STYRAFIX: out to walk/run directly too, not through idle
		# STYRAFIX: straight from any other non-hub clip too (strafe -> walk_back, charge -> impale, windup ->
		# charge). Without it travel() routed through idle and the idle pose blinked in between.
		for other in _param:
			if other != clip and not other in HUBS:
				_trans(sm, other, clip, xf)
	if _param.has(&"pin_foot"):
		for a in ATTACKS:  # the stomp (or any swing) lands and the foot goes straight onto the victim
			if _param.has(a):
				_trans(sm, a, &"pin_foot", PIN_XFADE)
		# A self-transition (attack -> attack) would fade a back-to-back replay, but Godot's state
		# machine made the node report a zero length and broke hit/done timing, so the one-frame
		# replay pop stays (accepted polish in the report; attacks are gated by _busy anyway).
	tree.tree_root = sm

func _clip_node(clip: StringName) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var a := AnimationNodeAnimation.new()
	a.animation = clip
	bt.add_node(&"anim", a)
	bt.add_node(&"ts", AnimationNodeTimeScale.new())
	bt.connect_node(&"ts", 0, &"anim")
	bt.connect_node(&"output", 0, &"ts")
	return bt

func _trans(sm: AnimationNodeStateMachine, a: StringName, b: StringName, xfade: float) -> void:
	if sm.has_transition(a, b):
		return  # STYRAFIX's all-pairs links may already hold it (the pin_foot links below)
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	sm.add_transition(a, b, t)
