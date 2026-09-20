class_name PlayerAnim
extends Node
## Player clip state machine. Busy oneshots win over locomotion.

signal attack_hit(clip: StringName)
signal attack_done

var current_clip: StringName = &"idle"
var rig: RiggedModel
var player: Player
var _busy: bool = false
var _dead: bool = false
var _forced: bool = false
var _missing_logged: Dictionary = {}
var _resolved_missing: bool = false
var _requested_clip: StringName = &"idle"

func setup(p: Player, p_rig: RiggedModel) -> void:
	player = p
	rig = p_rig
	if rig:
		rig.clip_finished.connect(_on_clip_finished)
	play_idle()

func play_idle() -> void:
	if _dead:
		return
	_play(&"idle")

func play_locomotion(speed: float) -> void:
	if _busy or _dead or _forced:
		return
	if player.mounted_on:
		_play(&"mount_idle")
		return
	if speed < 0.08:
		_play(&"idle")
		return
	# Hysteresis: walk_speed is 5.5 and the old cut-off was 5.5, so the clip flapped walk/run
	# every frame at full walking pace (the "glitching" walk). Run only above 7.2, back to
	# walk below 6.2.
	var run := current_clip == &"run"
	if speed > 7.2:
		run = true
	elif speed < 6.2:
		run = false
	_play(&"run" if run else &"walk")

func play_clip(clip: StringName, forced: bool = false) -> void:
	if _dead and clip != &"death":
		return
	if clip == &"knockdown" and _busy and current_clip == &"knockdown":
		return  # already on the ground; every hit re-triggering the fall looked like a glitch
	_requested_clip = clip
	_forced = forced
	_busy = clip in [&"attack_primary", &"attack_heavy", &"hit_react", &"roll", &"gather", &"knockdown"]
	if clip == &"death":
		_dead = true
	_play(clip)
	if _busy and _resolved_missing:
		_schedule_missing_done(clip)

func on_damaged() -> void:
	if not _dead:
		play_clip(&"hit_react")

func on_death() -> void:
	if _dead:
		return  # already on the floor; never replay the fall
	play_clip(&"death")

## Respawn: unfreeze the rig and stand back up.
func revive() -> void:
	_dead = false
	_busy = false
	_forced = false
	if rig and rig.anim_player:
		rig.anim_player.speed_scale = 1.0
	current_clip = &""
	play_idle()

func on_roll() -> void:
	play_clip(&"roll")

func on_gather() -> void:
	play_clip(&"gather")

func on_attack(heavy: bool = false) -> void:
	play_clip(&"attack_heavy" if heavy else &"attack_primary")

## The knockdown clip freezes on its last frame and stays busy; nothing released it before,
## so after the first knockdown the survivor slid around frozen in that pose for the rest
## of the session (the "walking glitch"). Release once the status is gone.
func release_knockdown() -> void:
	if current_clip != &"knockdown":
		return
	_busy = false
	_forced = false
	if rig and rig.anim_player:
		rig.anim_player.speed_scale = 1.0
	play_idle()

func _physics_tick(speed: float) -> void:
	if _busy and current_clip == &"knockdown" and player.statuses and not player.statuses.has_flag(&"knockdown"):
		release_knockdown()
	if player.rolling:
		return
	if player._gathering:
		if current_clip != &"gather":
			on_gather()
		return
	if player.mounted_on:
		if not _busy:
			_play(&"mount_idle")
		return
	play_locomotion(speed)

func _play(clip: StringName) -> void:
	var resolved := _resolve(clip)
	if resolved == current_clip and rig and rig.anim_player and rig.anim_player.is_playing():
		if clip in [&"idle", &"walk", &"run", &"mount_idle"]:
			return
	var loco := [&"idle", &"walk", &"run", &"mount_idle"]
	var blend := 0.18 if (resolved in loco and current_clip in loco) else 0.0
	current_clip = resolved
	var speed := 1.0
	if clip == &"attack_primary":
		speed = 1.5
	elif _resolved_missing and clip in [&"attack_heavy", &"roll", &"gather", &"knockdown"]:
		speed = 1.35
	if rig:
		rig.play(resolved, speed, blend)

func _resolve(clip: StringName) -> StringName:
	_resolved_missing = false
	if rig and rig.has_clip(clip):
		return clip
	_resolved_missing = true
	if not _missing_logged.has(clip):
		_missing_logged[clip] = true
		print("[player] missing clip %s" % clip)
	if rig and rig.has_clip(&"idle"):
		return &"idle"
	return clip

func _schedule_missing_done(clip: StringName) -> void:
	var wait := 0.25
	match clip:
		&"attack_primary", &"attack_heavy":
			wait = 0.35
		&"roll":
			wait = 0.3
		&"gather":
			wait = 0.45
		&"knockdown":
			wait = 0.4
	get_tree().create_timer(wait).timeout.connect(_on_missing_done.bind(clip), CONNECT_ONE_SHOT)

func _on_missing_done(clip: StringName) -> void:
	if _requested_clip != clip:
		return
	if clip == &"attack_primary" or clip == &"attack_heavy":
		attack_done.emit()
	_busy = false
	_forced = false
	if clip == &"death":
		if rig and rig.anim_player:
			rig.anim_player.speed_scale = 0.0
		return
	play_idle()

func _on_clip_finished(clip: StringName) -> void:
	if current_clip != clip:
		return
	if clip == &"attack_primary" or clip == &"attack_heavy":
		attack_done.emit()
	if clip == &"death":
		_busy = false
		if rig and rig.anim_player:
			rig.anim_player.speed_scale = 0.0
		return
	if clip == &"knockdown":
		_busy = true
		if rig and rig.anim_player:
			rig.anim_player.speed_scale = 0.0
		return
	_busy = false
	_forced = false
	play_idle()
