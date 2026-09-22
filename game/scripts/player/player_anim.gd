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
## Work clips retargeted from the KevDev villager pack (tools/retarget_human.py); each is a
## short one-shot that the gather loop re-triggers, so no idle pop between units.
const GATHER_CLIPS: Array[StringName] = [&"gather", &"gather_chop", &"gather_mine", &"craft"]
var _gather_clip: StringName = &"gather"

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

## Clip by intent, not by measured speed: tap-to-walk and sprint run, joystick/keys walk.
## (Picking by speed flapped walk/run every frame at full walking pace.)
func play_locomotion(speed: float, running: bool = false) -> void:
	if _busy or _dead or _forced:
		return
	if player.mounted_on:
		_play(&"mount_idle")
		return
	if speed < 0.08:
		_play(&"idle")
		return
	_play(&"run" if running and speed > 2.5 else &"walk")

func play_clip(clip: StringName, forced: bool = false) -> void:
	if _dead and clip != &"death":
		return
	if clip == &"knockdown" and _busy and current_clip == &"knockdown":
		return  # already on the ground; every hit re-triggering the fall looked like a glitch
	_requested_clip = clip
	_forced = forced
	_busy = clip in [&"attack_primary", &"attack_heavy", &"punch", &"hit_react", &"roll", &"knockdown"] or clip in GATHER_CLIPS
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

## kind: &"chop" (trees), &"mine" (rocks), &"craft" (stations) or anything else for the
## berry-bush reach. Falls back to the plain gather clip when the rig lacks the variant.
func on_gather(kind: StringName = &"") -> void:
	var clip: StringName = &"gather"
	match kind:
		&"chop":
			clip = &"gather_chop"
		&"mine":
			clip = &"gather_mine"
		&"craft":
			clip = &"craft"
	if rig and not rig.has_clip(clip):
		clip = &"gather"
	if clip != _gather_clip:
		print("[player] work clip %s" % clip)
	_gather_clip = clip
	play_clip(clip)

func on_attack(heavy: bool = false) -> void:
	play_clip(&"attack_heavy" if heavy else &"attack_primary")

## Unarmed: the punch clip when the survivor has one (anim/punch.glb), else the thrust.
func on_punch() -> void:
	play_clip(&"punch" if rig and rig.has_clip(&"punch") else &"attack_primary")

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

func _physics_tick(speed: float, running: bool = false) -> void:
	if _busy and current_clip == &"knockdown" and player.statuses and not player.statuses.has_flag(&"knockdown"):
		release_knockdown()
	if player.rolling:
		return
	if player._gathering:
		if current_clip != _gather_clip:
			play_clip(_gather_clip)
		return
	if player.mounted_on:
		if not _busy:
			_play(&"mount_idle")
		return
	play_locomotion(speed, running)

func _play(clip: StringName) -> void:
	var resolved := _resolve(clip)
	if resolved == current_clip and rig and rig.anim_player and rig.anim_player.is_playing():
		if clip in [&"idle", &"walk", &"run", &"mount_idle"]:
			return
	var loco := [&"idle", &"walk", &"run", &"mount_idle"]
	var blend := 0.18 if (resolved in loco and current_clip in loco) else 0.0
	if resolved in loco and (current_clip in [&"punch", &"attack_primary", &"attack_heavy"] or current_clip in GATHER_CLIPS):
		blend = 0.12  # trimmed one-shots end mid-pose; ease back into locomotion
	current_clip = resolved
	var speed := 1.0
	if clip == &"attack_primary":
		speed = 1.5
	elif clip == &"punch":
		speed = 1.3
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
	if clip == &"attack_primary" or clip == &"attack_heavy" or clip == &"punch":
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
	if clip == &"attack_primary" or clip == &"attack_heavy" or clip == &"punch":
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
	if clip in GATHER_CLIPS and player and player._gathering:
		_play(clip)  # next unit of the same work, no idle frame in between
		return
	_busy = false
	_forced = false
	play_idle()
