class_name CreatureClips
extends RefCounted
## Loads per-clip GLBs, remaps skeleton tracks onto View/Mesh, synthesizes fallbacks.

const CONTRACT: Array[StringName] = [
	&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy",
	&"hit_react", &"knockdown", &"death", &"alert", &"feed",
]
const LOOPING: Array[StringName] = [&"idle", &"walk", &"lope", &"run", &"sprint", &"charge", &"strafe_left", &"strafe_right", &"walk_back", &"investigate", &"stalk"]
## Authored on some species only; loaded when the GLB exists, CreatureAnim falls back to idle where
## missing. bite_combo: deinonychus chomp, Chomp, CHOMP (three hit fracs in anim_events.json).
## hop_back / leap_back: short and long backward leaps, pounce: the forward leap (airborne fracs in
## anim_events); strafe_left/right and walk_back: direction-aware locomotion (CreatureAnim.set_move_velocity).
## investigate: the idle while aware of prey but not attacking (CreatureAnim.play_idle(true)); sniff: the inspect
## one-shot a brain plays when it spots prey (velociraptor, owner 2026-10-30: head tilts, curious but aggressive).
## pin_foot: a big predator's foot on a Pinned victim (T. rex, PINFEEL); held on its last frame until the pin ends.
## charge_turn: the hop round at the end of a straight charge (carnotaurus; TacticalBrain tactics.charge_turn).
## charge_crouch: the coil a TacticalBrain plays, body still, before a charge's run (compsognathus, owner 2026-10-31).
## toss: the woolly rhino's horn toss on a charge impact (TacticalBrain._charge_impact).
## stalk: the low hunting creep a tactics.stalk brain approaches in; pin_stab: the sabre stabs while it holds pinned prey
## (smilodon, SP-SMILODON). lope / sprint: extra gaits either side of the run (CreatureAnim._pick_gait's ladder), leap: the
## chase bound one-shot (airborne fracs in anim_events; smilodon, SMILORUN).
## stomp / shove_left / shove_right / tackle (the coil before its body check): the ankylosaurus'
## close-range moves (ClubTailBrain close_moves, ANKYLOCLOSE).
## spit: the venom spit; its hit frame launches VenomSpit (dilophosaurus, SP-DILOPHOSAURUS).
## grab_bite: the allosaurus' hands-then-jaws grab (TacticalBrain tactics.grab, SP-ALLOSAURUS); arm_bite: the utahraptor's bite with arms (UTAHARMS).
## spacing_stomp: the overhanging theropods' stomp that shoves prey under the chest out to bite reach (SpacingStomp).
## roar: the big theropods' rearing roar (TheroRoar, THERO-ROAR), played on aggro and boss phase changes in place of alert.
## bull_windup: head down, a foot pawing twice with snorts, before a charge (pachycephalosaurus, tactics.display_clip).
const OPTIONAL: Array[StringName] = [&"sleep", &"tail_swipe", &"bite_combo", &"hop_back", &"leap_back", &"pounce", &"dodge_left", &"dodge_right", &"strafe_left", &"strafe_right", &"walk_back", &"kick", &"charge", &"investigate", &"sniff", &"pin_foot", &"charge_crouch", &"toss", &"stalk", &"pin_stab", &"charge_turn", &"charge_windup", &"impale", &"charge_recover", &"bite_shake", &"lope", &"sprint", &"leap", &"stomp", &"shove_left", &"shove_right", &"tackle", &"bull_windup", &"flank_rake", &"grab_bite", &"arm_bite", &"spit", &"grab", &"big_stomp", &"roar", &"spacing_stomp"]
## grab: the megatherium's bear-hug windup (tactics.pounce_windup_clip, played timed before the pounce).
## big_stomp: the shared big-dinosaur stomp (BigStomp, BIGSTOMP).
## A loop whose last quarter or more holds one pose is a donor clip with a dead tail.
const FROZEN_TAIL_MIN := 0.25
const TRIM_SAMPLES := 120

static var _trim_cache: Dictionary = {}  ## "species/clip" -> cut length, so each species pays once
static var _stale_warned: Dictionary = {}  ## "species/clip" of stale natural-speed bakes already reported

static func attach(player: AnimationPlayer, view: CreatureView, def: CreatureDef) -> AnimationLibrary:
	if player.root_node == NodePath(""):
		player.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	var loaded: Dictionary = {}
	for clip in CONTRACT + OPTIONAL:
		var path := "res://assets/creatures/%s/anim/%s.glb" % [def.id, clip]
		if ResourceLoader.exists(path):
			var anim := _from_glb(path, view, player, clip)
			if anim:
				_set_loop(anim, clip)
				lib.add_animation(clip, anim)
				loaded[clip] = true
	if view.using_glb:
		_steal_embedded(player, lib, view, loaded)
	_apply_fallbacks(lib, loaded, def)
	if not view.using_glb:
		for clip in CONTRACT:
			if not lib.has_animation(clip):
				lib.add_animation(clip, _placeholder(clip, view))
	else:
		for clip in CONTRACT:
			if not lib.has_animation(clip) and lib.has_animation(&"idle"):
				print("[creature] missing clip %s falling back to idle" % clip)
				lib.add_animation(clip, lib.get_animation(&"idle").duplicate(true) as Animation)
	if player.has_animation_library(""):
		player.remove_animation_library("")
	player.add_animation_library("", lib)
	return lib

static func clip_speed(clip: StringName, def: CreatureDef = null) -> float:
	var clips: Dictionary = Data.anim_events.get("clips", {})
	if clips.has(str(clip)) and clips[str(clip)] is Dictionary and (clips[str(clip)] as Dictionary).has("speed"):
		return float((clips[str(clip)] as Dictionary)["speed"])
	if clip == &"run" and def and not def.pipeline.is_empty() and def.pipeline.has("stand_in"):
		return 1.6
	return 1.0

## Planted-foot ground speed (m/s) of a gait at cadence 1, baked by tools/bake_clip_speeds.py
## into anim_events.json "natural_speeds" and scaled with the creature's height. 0 = unknown, marked
## for replacement, or stale: a bake measured on a clip length more than 1 % off clip_len (the GLB
## was swapped since) is ignored, with one warning per species and gait.
static func natural_speed(def: CreatureDef, clip: StringName, clip_len: float = -1.0) -> float:
	if def == null:
		return 0.0
	var row: Dictionary = (Data.anim_events.get("natural_speeds", {}) as Dictionary).get(str(def.id), {})
	var baked_len := float(row.get(str(clip) + "_len", -1.0))
	if clip_len > 0.0 and baked_len > 0.0 and absf(baked_len - clip_len) > clip_len * 0.01:
		var key := "%s/%s" % [def.id, clip]
		if not _stale_warned.has(key):
			_stale_warned[key] = true
			print("[creature] %s natural speed baked on a %.3f s clip, clip is %.3f s: ignored, rerun tools/bake_clip_speeds.py" % [key, baked_len, clip_len])
		return 0.0
	var baked_h := float(row.get("height_m", def.height_meters))
	return float(row.get(str(clip), 0.0)) * (def.height_meters / baked_h if baked_h > 0.0 else 1.0)

## Donor biped walks play one stride and then hold the start pose for the other half of the loop
## (51 % frozen). Cut a looping clip where a static tail of FROZEN_TAIL_MIN or more begins; the
## pose there matches the first frame, so the shortened loop is seamless. Returns the cut length.
static func trim_frozen_tail(anim: Animation, cache_key: String = "") -> float:
	if anim == null or anim.loop_mode == Animation.LOOP_NONE:
		return 0.0
	if cache_key != "" and _trim_cache.has(cache_key):
		anim.length = minf(anim.length, float(_trim_cache[cache_key]))
		return anim.length
	var length := anim.length
	var n := TRIM_SAMPLES
	var tail := n  # first sample index of the static tail
	var tracks: Array[PackedFloat32Array] = []  # per track: distance of each sample from the last
	for t in anim.get_track_count():
		var dev := _track_deviation(anim, t, n)
		if not dev.is_empty():
			tracks.append(dev)
	if tracks.is_empty():
		return length
	var tols: Array[float] = []
	for dev in tracks:
		var peak := 0.0
		for d in dev:
			peak = maxf(peak, d)
		tols.append(maxf(peak * 0.05, 0.0001))  # 5 % of the track's own swing counts as still
	while tail > 1:
		var still := true
		for k in tracks.size():
			if tracks[k][tail - 1] > tols[k]:
				still = false
				break
		if not still:
			break
		tail -= 1
	var cut := length * float(tail) / float(n)
	if 1.0 - float(tail) / float(n) >= FROZEN_TAIL_MIN and cut > length * 0.3:
		anim.length = cut
	if cache_key != "":
		_trim_cache[cache_key] = anim.length
	return anim.length

## Distance of each of n + 1 evenly spaced samples from the final sample; empty for non-bone tracks.
static func _track_deviation(anim: Animation, t: int, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var kind := anim.track_get_type(t)
	if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
		return out
	var last: Variant = _sample(anim, t, kind, anim.length)
	for i in n + 1:
		var v: Variant = _sample(anim, t, kind, anim.length * float(i) / float(n))
		if kind == Animation.TYPE_ROTATION_3D:
			var a: Quaternion = v
			var b: Quaternion = last
			out.append(minf((a - b).length(), (a + b).length()))  # q and -q are the same rotation
		else:
			out.append(((v as Vector3) - (last as Vector3)).length())
	return out

static func _sample(anim: Animation, t: int, kind: int, at: float) -> Variant:
	match kind:
		Animation.TYPE_POSITION_3D:
			return anim.position_track_interpolate(t, at)
		Animation.TYPE_ROTATION_3D:
			return anim.rotation_track_interpolate(t, at)
		_:
			return anim.scale_track_interpolate(t, at)

static func _from_glb(path: String, view: CreatureView, player: AnimationPlayer, clip: StringName) -> Animation:
	return RiggedModel.animation_from_glb(path, player, view, clip, "creature")

static func _steal_embedded(player: AnimationPlayer, lib: AnimationLibrary, view: CreatureView, loaded: Dictionary) -> void:
	var mesh: Node = view.rig.mesh_root if view.rig else view.get_node_or_null("Mesh")
	if mesh == null:
		return
	var ap := mesh.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for n in ap.get_animation_list():
		var sn := StringName(n)
		if sn in CONTRACT and not lib.has_animation(sn):
			var a := ap.get_animation(n).duplicate(true) as Animation
			if _remap_tracks(a, player, view, sn) > 0:
				continue
			_set_loop(a, sn)
			lib.add_animation(sn, a)
			loaded[sn] = true

static func _remap_tracks(anim: Animation, player: AnimationPlayer, view: CreatureView, clip: StringName) -> int:
	return RiggedModel.remap_tracks(anim, player, view, clip, "creature")

static func _apply_fallbacks(lib: AnimationLibrary, _loaded: Dictionary, _def: CreatureDef) -> void:
	if not lib.has_animation(&"knockdown") and lib.has_animation(&"death"):
		var kd := lib.get_animation(&"death").duplicate(true) as Animation
		_set_loop(kd, &"knockdown")
		lib.add_animation(&"knockdown", kd)
	if not lib.has_animation(&"hit_react") and lib.has_animation(&"knockdown"):
		lib.add_animation(&"hit_react", _slice(lib.get_animation(&"knockdown"), 0.4))
	if not lib.has_animation(&"alert") and lib.has_animation(&"idle"):
		var al := lib.get_animation(&"idle").duplicate(true) as Animation
		_set_loop(al, &"alert")
		lib.add_animation(&"alert", al)
	if not lib.has_animation(&"run") and lib.has_animation(&"walk"):
		var rn := lib.get_animation(&"walk").duplicate(true) as Animation
		_set_loop(rn, &"run")
		lib.add_animation(&"run", rn)
	if not lib.has_animation(&"feed") and lib.has_animation(&"idle"):
		lib.add_animation(&"feed", lib.get_animation(&"idle").duplicate(true) as Animation)

static func _slice(src: Animation, frac: float) -> Animation:
	var anim := src.duplicate(true) as Animation
	anim.length = maxf(0.05, src.length * frac)
	_set_loop(anim, &"hit_react")
	return anim

static func _set_loop(anim: Animation, clip: StringName) -> void:
	anim.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE

static func _placeholder(clip: StringName, _view: CreatureView) -> Animation:
	var anim := Animation.new()
	_set_loop(anim, clip)
	var len := _len(clip)
	anim.length = len
	var kind_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(kind_track, NodePath("View:pose_kind"))
	anim.value_track_set_update_mode(kind_track, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(kind_track, 0.0, clip)
	var t_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_track, NodePath("View:pose_t"))
	anim.track_insert_key(t_track, 0.0, 0.0)
	anim.track_insert_key(t_track, len, 1.0)
	return anim

static func _len(clip: StringName) -> float:
	match clip:
		&"idle":
			return 1.6
		&"walk":
			return 0.8
		&"run":
			return 0.5
		&"attack_primary":
			return 0.7
		&"attack_heavy":
			return 1.35
		&"hit_react":
			return 0.35
		&"knockdown":
			return 0.8
		&"death":
			return 1.1
		&"alert":
			return 0.9
		&"feed":
			return 1.2
		_:
			return 0.8

## Every hit frame of a clip as clip fractions: hit_fracs when listed (bite_combo has three), else [hit_frac].
static func hit_fracs(clip: StringName) -> Array[float]:
	var out: Array[float] = []
	var row: Variant = (Data.anim_events.get("clips", {}) as Dictionary).get(str(clip))
	if row is Dictionary and (row as Dictionary).get("hit_fracs") is Array:
		for f in (row as Dictionary)["hit_fracs"]:
			out.append(float(f))
	if out.is_empty():
		out.append(_hit_frac(clip))
	return out

static func _hit_frac(clip: StringName) -> float:
	var clips: Dictionary = Data.anim_events.get("clips", {})
	if clips.has(str(clip)):
		return float(clips[str(clip)].get("hit_frac", 0.55))
	return float(Data.anim_events.get("default_hit_frac", 0.55))
