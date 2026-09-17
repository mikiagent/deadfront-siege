class_name CreatureClips
extends RefCounted
## Loads per-clip GLBs or synthesizes placeholder animations on CreatureView.pose_*.

const CONTRACT: Array[StringName] = [
	&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy",
	&"hit_react", &"knockdown", &"death", &"alert", &"feed",
]

static func attach(player: AnimationPlayer, view: CreatureView, def: CreatureDef) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var loaded: Dictionary = {}
	for clip in CONTRACT:
		var path := "res://assets/creatures/%s/anim/%s.glb" % [def.id, clip]
		if ResourceLoader.exists(path):
			var anim := _from_glb(path, view)
			if anim:
				lib.add_animation(clip, anim)
				loaded[clip] = true
				continue
		if not loaded.has(clip):
			lib.add_animation(clip, _placeholder(clip, view))
	if view.using_glb:
		_steal_embedded(player, lib, view)
	player.add_animation_library("", lib)
	return lib

static func _from_glb(path: String, view: CreatureView) -> Animation:
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
	_verify_tracks(copy, view)
	inst.free()
	return copy

static func _steal_embedded(player: AnimationPlayer, lib: AnimationLibrary, view: CreatureView) -> void:
	# If the main GLB already has walk/run, prefer those names when present on a child player.
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
			_verify_tracks(a, view)
			lib.add_animation(sn, a)

static func _verify_tracks(anim: Animation, view: CreatureView) -> void:
	var skel := view.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	for i in anim.get_track_count():
		var p := str(anim.track_get_path(i))
		if p.contains(":") and not view.has_node(NodePath(p.get_slice(":", 0))) and skel.find_bone(p.get_file()) == -1:
			print("[creature] missing bone %s" % p)

static func _placeholder(clip: StringName, _view: CreatureView) -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR if clip in [&"idle", &"walk", &"run"] else Animation.LOOP_NONE
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
	if clip == &"knockdown":
		anim.loop_mode = Animation.LOOP_NONE
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
