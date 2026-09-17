class_name CreatureAnim
extends Node
## AnimationTree state machine over the clip contract. Falls back to AnimationPlayer.play.

signal attack_windup(clip: StringName)
signal attack_hit(clip: StringName)
signal attack_done
signal knockdown_started
signal knockdown_ended
signal died

var current_clip: StringName = &"idle"
var tree: AnimationTree
var player: AnimationPlayer
var _playback: AnimationNodeStateMachinePlayback
var _busy: bool = false
var _hold_knockdown: bool = false
var _dead: bool = false
var _forced: bool = false

func setup(ap: AnimationPlayer, at: AnimationTree) -> void:
	player = ap
	tree = at
	_build_tree()
	tree.anim_player = tree.get_path_to(player)
	tree.active = true
	_playback = tree.get("parameters/playback")
	play_idle()

func play_idle() -> void:
	if _dead or _hold_knockdown:
		return
	_travel(&"idle")

func play_locomotion(speed_frac: float) -> void:
	if _busy or _dead or _hold_knockdown or _forced:
		return
	current_clip = &"run" if speed_frac > 0.55 else &"walk"
	_travel(&"locomotion")
	tree.set("parameters/locomotion/blend_position", clampf(speed_frac, 0.0, 1.0))

func play_clip(clip: StringName, forced: bool = false) -> void:
	if _dead and clip != &"death":
		return
	_forced = forced
	_busy = clip in [&"attack_primary", &"attack_heavy", &"hit_react", &"alert"]
	if clip == &"knockdown":
		_hold_knockdown = true
		knockdown_started.emit()
	if clip == &"death":
		_dead = true
		died.emit()
	if clip == &"attack_heavy":
		attack_windup.emit(clip)
	_travel(clip if clip != &"walk" and clip != &"run" else &"locomotion")
	if player and player.has_animation(clip):
		player.play(clip)
	current_clip = clip
	if clip in [&"attack_primary", &"attack_heavy", &"hit_react", &"alert"]:
		var anim := player.get_animation(clip) if player.has_animation(clip) else null
		var wait := anim.length if anim else 0.6
		var hit_at := wait * CreatureClips._hit_frac(clip)
		if clip == &"attack_primary" or clip == &"attack_heavy":
			get_tree().create_timer(hit_at).timeout.connect(func () -> void:
				if current_clip == clip:
					attack_hit.emit(clip)
			, CONNECT_ONE_SHOT)
		get_tree().create_timer(wait).timeout.connect(_oneshot_done.bind(clip), CONNECT_ONE_SHOT)

func release_knockdown() -> void:
	_hold_knockdown = false
	_forced = false
	knockdown_ended.emit()
	if not _dead:
		play_idle()

func on_event(kind: String, clip: String) -> void:
	if kind == "hit":
		attack_hit.emit(StringName(clip))
	elif kind == "windup":
		attack_windup.emit(StringName(clip))

func _oneshot_done(clip: StringName) -> void:
	if current_clip != clip:
		return
	_busy = false
	_forced = false
	if clip == &"attack_primary" or clip == &"attack_heavy":
		attack_done.emit()
	if clip == &"knockdown":
		# Hold last frame until release_knockdown.
		if player:
			player.speed_scale = 0.0
		return
	if clip == &"death":
		if player:
			player.speed_scale = 0.0
		return
	play_idle()

func _travel(state: StringName) -> void:
	if player:
		var host := get_parent() as Creature
		var clip := current_clip if state == &"locomotion" else state
		player.speed_scale = CreatureClips.clip_speed(clip, host.def if host else null)
	if state != &"locomotion":
		current_clip = state
	if _playback:
		_playback.travel(str(state))

func _build_tree() -> void:
	var sm := AnimationNodeStateMachine.new()
	_add_anim(sm, "idle", Vector2(0, 0))
	var blend := AnimationNodeBlendSpace1D.new()
	var walk_n := AnimationNodeAnimation.new()
	walk_n.animation = "walk"
	var run_n := AnimationNodeAnimation.new()
	run_n.animation = "run"
	blend.add_blend_point(walk_n, 0.0)
	blend.add_blend_point(run_n, 1.0)
	sm.add_node("locomotion", blend, Vector2(200, 0))
	for clip in ["attack_primary", "attack_heavy", "hit_react", "knockdown", "death", "alert", "feed"]:
		_add_anim(sm, clip, Vector2(0, 140))
	_trans(sm, "idle", "locomotion")
	_trans(sm, "locomotion", "idle")
	for clip in ["attack_primary", "attack_heavy", "hit_react", "knockdown", "death", "alert", "feed"]:
		_trans(sm, "idle", clip)
		_trans(sm, "locomotion", clip)
		_trans(sm, clip, "idle")
	tree.tree_root = sm

func _add_anim(sm: AnimationNodeStateMachine, name: String, pos: Vector2) -> void:
	var n := AnimationNodeAnimation.new()
	n.animation = name
	sm.add_node(name, n, pos)

func _trans(sm: AnimationNodeStateMachine, a: String, b: String) -> void:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = 0.08
	sm.add_transition(a, b, t)
