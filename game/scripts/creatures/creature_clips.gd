class_name CreatureClips
extends RefCounted
## Loads per-clip GLBs, remaps skeleton tracks onto View/Mesh, synthesizes fallbacks.

const CONTRACT: Array[StringName] = [
	&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy",
	&"hit_react", &"knockdown", &"death", &"alert", &"feed",
]
const LOOPING: Array[StringName] = [&"idle", &"walk", &"run"]

static func attach(player: AnimationPlayer, view: CreatureView, def: CreatureDef) -> AnimationLibrary:
	if player.root_node == NodePath(""):
		player.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	var loaded: Dictionary = {}
	for clip in CONTRACT:
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

static func _from_glb(path: String, view: CreatureView, player: AnimationPlayer, clip: StringName) -> Animation:
	var packed := load(path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		inst.free()
		print("[creature] missing AnimationPlayer in %s" % path)
		return null
	var names := ap.get_animation_list()
	if names.is_empty():
		inst.free()
		return null
	var src := ap.get_animation(names[0])
	var copy := src.duplicate(true) as Animation
	var missing := _remap_tracks(copy, player, view, clip)
	inst.free()
	if missing > 0:
		return null
	return copy

static func _steal_embedded(player: AnimationPlayer, lib: AnimationLibrary, view: CreatureView, loaded: Dictionary) -> void:
	var mesh := view.get_node_or_null("Mesh")
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
	var skel := view.find_child("Skeleton3D", true, false) as Skeleton3D
	var tracks := anim.get_track_count()
	var remapped := 0
	var missing := 0
	if skel == null:
		print("[creature] clip %s tracks=%d remapped=0 missing=%d" % [clip, tracks, tracks])
		return tracks
	var root := player.get_node_or_null(player.root_node)
	if root == null:
		root = player.get_parent()
	var rel := str(root.get_path_to(skel))
	for i in tracks:
		var p := str(anim.track_get_path(i))
		if not p.contains(":"):
			continue
		var bone := p.get_slice(":", 1)
		if skel.find_bone(bone) != -1:
			anim.track_set_path(i, NodePath("%s:%s" % [rel, bone]))
			remapped += 1
		else:
			missing += 1
	print("[creature] clip %s tracks=%d remapped=%d missing=%d" % [clip, tracks, remapped, missing])
	return missing

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

static func _hit_frac(clip: StringName) -> float:
	var clips: Dictionary = Data.anim_events.get("clips", {})
	if clips.has(str(clip)):
		return float(clips[str(clip)].get("hit_frac", 0.55))
	return float(Data.anim_events.get("default_hit_frac", 0.55))
