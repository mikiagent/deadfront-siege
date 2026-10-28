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
var _sleeping: bool = false
var _waking: bool = false
## REST: seated on the ground (the built "sit" pose). Uses the sleep flags, so locomotion leaves her
## alone and the visual is grounded as for sleep.
var _sitting: bool = false
const SIT_AT := 0.8      # sleep_down: low enough to blend into the sit
const STAND_FROM := 0.68 # sleep_up: its seated frame on the way up
var _sleep_ground_tween: Tween
var _visual_rest_y: float = 0.0
var _missing_logged: Dictionary = {}
var _resolved_missing: bool = false
var _requested_clip: StringName = &"idle"
## Work clips retargeted from the KevDev villager pack (tools/retarget_human.py); each is a
## short one-shot that the gather loop re-triggers, so no idle pop between units.
const GATHER_CLIPS: Array[StringName] = [&"gather", &"gather_chop", &"gather_mine", &"craft"]
var _gather_clip: StringName = &"gather"

func setup(p: Player, p_rig: RiggedModel) -> void:
	player = p
	_visual_rest_y = player.visual.position.y
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
	if clip not in [&"sleep", &"sleep_down", &"sleep_up", &"sit"]:
		if _sleeping or _waking:
			_ground_sleep_visual(false)
		_sleeping = false
		_waking = false
		_sitting = false
	if _dead and clip != &"death":
		return
	if clip == &"knockdown" and _busy and current_clip == &"knockdown":
		return  # already on the ground; every hit re-triggering the fall looked like a glitch
	_requested_clip = clip
	_forced = forced
	_busy = clip in [&"attack_primary", &"attack_heavy", &"punch", &"hit_react", &"roll", &"roll_back", &"knockdown"] or clip in GATHER_CLIPS
	if clip == &"death":
		_dead = true
	_play(clip)
	if _busy and _resolved_missing:
		_schedule_missing_done(clip)

func start_sleep() -> void:
	if _dead:
		return
	var from_sit := _sitting and current_clip in [&"sleep_down", &"sit"] and rig != null and rig.anim_player != null
	_sleeping = true
	_sitting = false
	_waking = false
	_busy = false
	if from_sit:
		# REST -> Sleep: lie down from the seated frame instead of restarting the clip.
		var settled := current_clip == &"sit"
		current_clip = &"sleep_down"
		rig.play(&"sleep_down", 1.0, SIT_BLEND if settled else 0.0)
		if settled:
			rig.anim_player.seek(SIT_LEGS, true)
		return
	_ground_sleep_visual(true)
	play_clip(&"sleep_down" if rig and rig.has_clip(&"sleep_down") else &"sleep", true)

## Exit the wake pose without waiting for the clip's finished signal. The survivor is immobile while
## _waking (PlayerSim.tick holds still), so a missed signal - a clip that did not load, a paused
## player, a renderer that skipped the frame - traps the player for good. PlayerSim calls this when the
## wake clip is not playing or has overrun its length.
func force_awake() -> void:
	_waking = false
	_sleeping = false
	_ground_sleep_visual(false)
	if not _dead:
		play_idle()

func wake_from_sleep() -> void:
	if not _sleeping or _dead:
		return
	_sleeping = false
	_ground_sleep_visual(false, 2.05)
	_waking = true
	play_clip(&"sleep_up", true)

## REST: sit down. sleep_down lowers her, then at SIT_AT she blends into the built "sit" pose (upright
## torso, knees up, arms at her sides; the rig has no sit clip). Falls back to lying down without sleep_down.
func sit() -> void:
	if _dead:
		return
	start_sleep()
	_sitting = true
	if rig and rig.has_clip(&"sleep_down") and _ensure_sit_clip():
		get_tree().create_timer(SIT_AT).timeout.connect(_settle_sit, CONNECT_ONE_SHOT)

func _settle_sit() -> void:
	var ap := rig.anim_player if rig else null
	if not _sitting or current_clip != &"sleep_down" or ap == null:
		return
	var early := SIT_AT - ap.current_animation_position
	if early > 0.02:  # a later sit restarted the clip: wait for its own frame
		get_tree().create_timer(early).timeout.connect(_settle_sit, CONNECT_ONE_SHOT)
		return
	current_clip = &"sit"
	rig.play(&"sit", 1.0, SIT_BLEND)

## Builds "sit" once: hips and legs from sleep_down at SIT_LEGS (seated, knees up), spine, head and arms
## from idle, then the first spine bone turned so the head is straight over the hips. One key, looping,
## so the pose holds without a finished signal. The pre-merge review: the held sleep_down frame leaned
## back on one arm and read as a knockdown on open ground.
func _ensure_sit_clip() -> bool:
	if rig.has_clip(&"sit"):
		return true
	var sk := rig.skeleton
	var down := rig.library.get_animation(&"sleep_down")
	var idle := rig.library.get_animation(&"idle") if rig.has_clip(&"idle") else null
	if sk == null or down == null or idle == null:
		return false
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	var local := {}  # bone -> Transform3D of the built pose, for the lean fix below
	var rot_track := {}  # bone -> its rotation track in the built clip
	for i in down.get_track_count():
		var path := down.track_get_path(i)
		var bone := sk.find_bone(path.get_concatenated_subnames())
		var src := idle if bone >= 0 and _upper_body(sk.get_bone_name(bone)) else down
		var t := 0.0 if src == idle else SIT_LEGS
		var j := src.find_track(path, down.track_get_type(i))
		if j < 0:
			src = down
			t = SIT_LEGS
			j = i
		var k := a.add_track(down.track_get_type(i))
		a.track_set_path(k, path)
		match down.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				var q := src.rotation_track_interpolate(j, t)
				a.rotation_track_insert_key(k, 0.0, q)
				rot_track[bone] = k
				if bone >= 0:
					var tr: Transform3D = local.get(bone, sk.get_bone_rest(bone))
					local[bone] = Transform3D(Basis(q).scaled(tr.basis.get_scale()), tr.origin)
			Animation.TYPE_POSITION_3D:
				var v := src.position_track_interpolate(j, t)
				a.position_track_insert_key(k, 0.0, v)
				if bone >= 0:
					var tr: Transform3D = local.get(bone, sk.get_bone_rest(bone))
					local[bone] = Transform3D(tr.basis, v)
			Animation.TYPE_SCALE_3D:
				a.scale_track_insert_key(k, 0.0, src.scale_track_interpolate(j, t))
			_:
				a.remove_track(k)
	# Lean fix: sleep_down's pelvis is tipped back, so idle's spine on it leans back. Turn the three spine
	# bones, a share each (a curve, not one kink at the waist), until hips -> head points straight up.
	var hips := sk.find_bone("Hips")
	var head := sk.find_bone("Head")
	var chain: Array[int] = []
	for bn in ["Spine", "Spine1", "Spine2"]:
		var b := sk.find_bone(bn)
		if b >= 0:
			chain.append(b)
	if hips < 0 or head < 0 or chain.is_empty() or down.get_track_count() == 0:
		rig.library.add_animation(&"sit", a)
		return true
	var base := String(down.track_get_path(0)).get_slice(":", 0)
	var up := (sk.global_transform.basis.inverse() * Vector3.UP).normalized()
	for round_i in 2:
		for n in chain.size():
			var b := chain[n]
			var v := _global_pose(sk, local, head).origin - _global_pose(sk, local, hips).origin
			var axis := v.cross(up)
			if axis.length() < 1e-5:
				break
			var r := Basis(axis.normalized(), v.angle_to(up) / float(chain.size() - n))
			var pb := _global_pose(sk, local, sk.get_bone_parent(b)).basis.orthonormalized()
			var bl: Transform3D = local.get(b, sk.get_bone_rest(b))
			var q := (pb.inverse() * r * pb * Basis(bl.basis.get_rotation_quaternion())).get_rotation_quaternion()
			local[b] = Transform3D(Basis(q).scaled(bl.basis.get_scale()), bl.origin)
			if not rot_track.has(b):  # a bone the clips leave at rest gets a track
				rot_track[b] = a.add_track(Animation.TYPE_ROTATION_3D)
				a.track_set_path(rot_track[b], NodePath(base + ":" + sk.get_bone_name(b)))
				a.rotation_track_insert_key(rot_track[b], 0.0, q)
			a.track_set_key_value(rot_track[b], 0, q)
	rig.library.add_animation(&"sit", a)
	return true

const SIT_LEGS := 1.05 ## sleep_down: hips ~0.3 m off the ground, knees up
const SIT_BLEND := 0.4

static func _upper_body(bone: String) -> bool:
	return bone.begins_with("Spine") or bone in ["Neck", "Head", "HeadTop_End"] \
		or bone.contains("Shoulder") or bone.contains("Arm") or bone.contains("Hand")

## Skeleton-space pose of `bone` from the built locals (rest pose where the clip has no track).
static func _global_pose(sk: Skeleton3D, local: Dictionary, bone: int) -> Transform3D:
	var t: Transform3D = local.get(bone, sk.get_bone_rest(bone))
	var parent := sk.get_bone_parent(bone)
	return t if parent < 0 else _global_pose(sk, local, parent) * t

func is_sitting() -> bool:
	return _sitting

## REST: get up from the sit (sleep_up from STAND_FROM); the visual rises as the clip ends.
func stand_up() -> void:
	if not _sitting or _dead:
		return
	_sitting = false
	_sleeping = false
	_waking = true
	var ap := rig.anim_player if rig else null
	var left := 0.0
	if ap and rig.has_clip(&"sleep_up"):
		# Blend out of the sit (no pop), into sleep_up where it is closest to sitting.
		_requested_clip = &"sleep_up"
		_forced = true
		_busy = false
		current_clip = &"sleep_up"
		rig.play(&"sleep_up", 1.0, SIT_BLEND if ap.current_animation == &"sit" else 0.0)
		ap.seek(minf(STAND_FROM, ap.current_animation_length), true)
		left = ap.current_animation_length - ap.current_animation_position
	else:
		play_clip(&"sleep_up", true)
	_ground_sleep_visual(false, left)

func _ground_sleep_visual(asleep: bool, delay: float = 0.0) -> void:
	if _sleep_ground_tween:
		_sleep_ground_tween.kill()
	# Player origin is capsule centre, while the imported sleeping mesh grounds at root0.
	# Match actual terrain beneath the survivor, without moving its collision capsule/rig.
	var offset := 0.9
	if World.runtime and World.runtime.has_method("surface_y"):
		offset = maxf(0.0, player.global_position.y - World.runtime.surface_y(player.global_position.x, player.global_position.z))
	var y := _visual_rest_y - offset if asleep else _visual_rest_y
	_sleep_ground_tween = create_tween()
	if delay > 0.0:
		_sleep_ground_tween.tween_interval(delay)
	_sleep_ground_tween.tween_property(player.visual, "position:y", y, 0.25)

func on_damaged() -> void:
	# REST: hurt while sitting, she gets up; a standing flinch from the floor would pop the pose.
	if _sitting:
		stand_up()
		return
	if _waking and current_clip == &"sleep_up" and not _sleeping:
		return
	_ground_sleep_visual(false)
	_sleeping = false
	_waking = false
	if not _dead and current_clip != &"hit_react":  # never restart a flinch already playing
		play_clip(&"hit_react")

## The hurt stun ended (PlayerSim): drop the hurt clip's hold so walk/run plays at once, never a
## lingering hurt pose while she runs.
func end_hurt() -> void:
	if current_clip == &"hit_react" and _busy:
		_busy = false
		_forced = false
		play_idle()

func on_death() -> void:
	_ground_sleep_visual(false)
	_sleeping = false
	_waking = false
	_sitting = false
	if _dead:
		return  # already on the floor; never replay the fall
	play_clip(&"death")

## Respawn: unfreeze the rig and stand back up.
func revive() -> void:
	_ground_sleep_visual(false)
	_sleeping = false
	_waking = false
	_sitting = false
	_dead = false
	_busy = false
	_forced = false
	if rig and rig.anim_player:
		rig.anim_player.speed_scale = 1.0
	current_clip = &""
	play_idle()

func on_roll() -> void:
	# The no-input roll goes backward with the facing kept (owner rule): play the back-roll clip when the rig has it.
	var back: bool = player.sim.roll_backward and rig != null and rig.has_clip(&"roll_back")
	play_clip(&"roll_back" if back else &"roll")

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
	if _sleeping or _waking:
		return
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
		if clip in [&"idle", &"walk", &"run", &"mount_idle", &"sleep"]:
			return
	var loco := [&"idle", &"walk", &"run", &"mount_idle"]
	var blend := 0.18 if (resolved in loco and current_clip in loco) else 0.0
	if resolved in loco and (current_clip in [&"punch", &"attack_primary", &"attack_heavy"] or current_clip in GATHER_CLIPS):
		blend = 0.12  # trimmed one-shots end mid-pose; ease back into locomotion
	current_clip = resolved
	var speed := 1.0
	if clip == &"attack_primary":
		speed = 1.0  # v2 clip is 1.21 s; the 1.5 floor was for the 3 s Meshy swing. The weapon-rate fit below still applies.
	elif clip == &"punch":
		speed = 1.3
	elif _resolved_missing and clip in [&"attack_heavy", &"roll", &"roll_back", &"gather", &"knockdown"]:
		speed = 1.35
	if rig:
		if clip in [&"attack_primary", &"attack_heavy", &"punch"] and rig.anim_player and rig.anim_player.has_animation(resolved):
			var weapon := player.inventory.equipped_weapon() if player and player.inventory else null
			var rate := weapon.def().attack_rate if weapon and weapon.def() else 1.0
			var duration := rig.anim_player.get_animation(resolved).length
			speed = maxf(speed, duration * maxf(0.2, rate) / 0.65)
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
		&"roll", &"roll_back":
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
	if clip == &"sleep_down" and _sleeping:
		play_clip(&"sleep", true)
		return
	if clip == &"sleep_up":
		_waking = false
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
