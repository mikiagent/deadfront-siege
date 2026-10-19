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
const ONESHOT: Array[StringName] = [&"attack_primary", &"attack_heavy", &"tail_swipe", &"hit_react", &"alert"]
const ATTACKS: Array[StringName] = [&"attack_primary", &"attack_heavy", &"tail_swipe"]
const HUBS: Array[StringName] = [&"idle", &"walk", &"run"]
const XFADE := 0.08
const GAIT_XFADE := 0.2  # walk <-> run: long enough that a gait change never pops
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

func play_idle() -> void:
	if _dead or _hold_knockdown:
		return
	_scale[&"idle"] = CreatureClips.clip_speed(&"idle", _def)
	_travel(&"idle")

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
	return not (_busy or _dead or _hold_knockdown or _forced)

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
	if not _os_hit_done and _os_t >= length * CreatureClips._hit_frac(_os_state):
		_os_hit_done = true
		attack_hit.emit(_os_state)
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
		for hub in HUBS:
			if _param.has(hub):
				_trans(sm, hub, clip, XFADE)
		_trans(sm, clip, &"idle", XFADE)
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
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	sm.add_transition(a, b, t)
