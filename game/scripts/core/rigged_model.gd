class_name RiggedModel
extends Node3D
## Mesh + clip merge: instantiate a base GLB, face Godot -Z, scale to height, merge anim/*.glb.

signal clip_finished(clip: StringName)

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var mesh_root: Node3D
var using_glb: bool = false
var hand_socket: BoneAttachment3D
var hips_socket: BoneAttachment3D
var library: AnimationLibrary
var log_tag: String = "creature"

const LOOPING: Array[StringName] = [&"idle", &"walk", &"run", &"mount_idle"]

func setup(base_glb: String, anim_dir: String, forward_axis: String, height_m: float, p_log: String = "creature", sockets: bool = false, source_h: float = 0.0) -> bool:
	log_tag = p_log
	if not ResourceLoader.exists(base_glb):
		return false
	var packed := load(base_glb)
	if packed == null or not (packed is PackedScene):
		return false
	mesh_root = (packed as PackedScene).instantiate() as Node3D
	if mesh_root == null:
		return false
	mesh_root.name = "Mesh"
	add_child(mesh_root)
	using_glb = true
	_orient(mesh_root, forward_axis)
	_scale_to_height(mesh_root, height_m, source_h)
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	anim_player.root_node = NodePath("..")
	add_child(anim_player)
	library = AnimationLibrary.new()
	_merge_dir(anim_dir)
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", library)
	anim_player.animation_finished.connect(_on_finished)
	if sockets:
		_attach_sockets()
	return true

func play(clip: StringName, speed: float = 1.0) -> void:
	if anim_player == null:
		return
	if not anim_player.has_animation(clip):
		return
	anim_player.speed_scale = speed
	anim_player.play(clip)

func has_clip(clip: StringName) -> bool:
	return library != null and library.has_animation(clip)

func fill_missing(clips: Array[StringName]) -> void:
	if library == null or not library.has_animation(&"idle"):
		return
	for clip in clips:
		if has_clip(clip):
			continue
		print("[%s] missing clip %s falling back to idle" % [log_tag, clip])
		var a := library.get_animation(&"idle").duplicate(true) as Animation
		_set_loop(a, clip)
		library.add_animation(clip, a)

func _on_finished(anim_name: StringName) -> void:
	clip_finished.emit(anim_name)

func _merge_dir(anim_dir: String) -> void:
	var loaded: Dictionary = {}
	var seen: Dictionary = {}
	var names: Array[String] = [
		"idle", "walk", "run", "hit_react", "death", "attack_primary", "attack_heavy",
		"roll", "gather", "knockdown", "mount_idle", "alert", "feed",
	]
	var da := DirAccess.open(anim_dir)
	if da:
		da.list_dir_begin()
		var fname := da.get_next()
		while fname != "":
			if not da.current_is_dir() and fname.ends_with(".glb"):
				var base := fname.get_basename()
				if base not in names:
					names.append(base)
			fname = da.get_next()
		da.list_dir_end()
	for base in names:
		if seen.has(base):
			continue
		seen[base] = true
		var path := "%s/%s.glb" % [anim_dir, base]
		if not ResourceLoader.exists(path):
			continue
		var clip := StringName(base)
		var anim := animation_from_glb(path, anim_player, self, clip, log_tag)
		if anim:
			if clip == &"gather" and anim.length > 2.0:
				anim.length = 2.0
			_set_loop(anim, clip)
			library.add_animation(clip, anim)
			loaded[clip] = true
	_steal_embedded(loaded)
	_fallbacks(loaded)

func _steal_embedded(loaded: Dictionary) -> void:
	if mesh_root == null:
		return
	var ap := mesh_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for n in ap.get_animation_list():
		var sn := StringName(n)
		if "|" in n or library.has_animation(sn):
			continue
		var a := ap.get_animation(n).duplicate(true) as Animation
		if remap_tracks(a, anim_player, self, sn, log_tag) > 0:
			continue
		_set_loop(a, sn)
		library.add_animation(sn, a)
		loaded[sn] = true

func _fallbacks(_loaded: Dictionary) -> void:
	if not library.has_animation(&"run") and library.has_animation(&"walk"):
		var rn := library.get_animation(&"walk").duplicate(true) as Animation
		_set_loop(rn, &"run")
		library.add_animation(&"run", rn)
	if not library.has_animation(&"alert") and library.has_animation(&"idle"):
		var al := library.get_animation(&"idle").duplicate(true) as Animation
		_set_loop(al, &"alert")
		library.add_animation(&"alert", al)
	if not library.has_animation(&"hit_react") and library.has_animation(&"knockdown"):
		library.add_animation(&"hit_react", _slice(library.get_animation(&"knockdown"), 0.4))
	if not library.has_animation(&"knockdown") and library.has_animation(&"death"):
		var kd := library.get_animation(&"death").duplicate(true) as Animation
		_set_loop(kd, &"knockdown")
		library.add_animation(&"knockdown", kd)
	if not library.has_animation(&"feed") and library.has_animation(&"idle"):
		library.add_animation(&"feed", library.get_animation(&"idle").duplicate(true) as Animation)

static func animation_from_glb(path: String, player: AnimationPlayer, search: Node, clip: StringName, tag: String) -> Animation:
	var packed := load(path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		inst.free()
		print("[%s] missing AnimationPlayer in %s" % [tag, path])
		return null
	var names := ap.get_animation_list()
	if names.is_empty():
		inst.free()
		return null
	var copy := ap.get_animation(names[0]).duplicate(true) as Animation
	var missing := remap_tracks(copy, player, search, clip, tag)
	inst.free()
	if missing > 0:
		return null
	return copy

static func remap_tracks(anim: Animation, player: AnimationPlayer, search: Node, clip: StringName, tag: String) -> int:
	var skel := search.find_child("Skeleton3D", true, false) as Skeleton3D
	var tracks := anim.get_track_count()
	var remapped := 0
	var missing := 0
	if skel == null:
		print("[%s] clip %s tracks=%d remapped=0 missing=%d" % [tag, clip, tracks, tracks])
		return tracks
	var root := player.get_node_or_null(player.root_node)
	if root == null:
		root = player.get_parent()
	var rel := str(root.get_path_to(skel))
	for i in tracks:
		var p := str(anim.track_get_path(i))
		var colon := p.find(":")
		if colon < 0:
			continue
		var bone := p.substr(colon + 1)
		if skel.find_bone(bone) != -1:
			anim.track_set_path(i, NodePath("%s:%s" % [rel, bone]))
			remapped += 1
		else:
			missing += 1
	print("[%s] clip %s tracks=%d remapped=%d missing=%d" % [tag, clip, tracks, remapped, missing])
	return missing

static func _set_loop(anim: Animation, clip: StringName) -> void:
	anim.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE

static func _slice(src: Animation, frac: float) -> Animation:
	var anim := src.duplicate(true) as Animation
	anim.length = maxf(0.05, src.length * frac)
	_set_loop(anim, &"hit_react")
	return anim

func _orient(mesh: Node3D, axis: String) -> void:
	match axis:
		"+Z":
			mesh.rotation_degrees.y = 180.0
		"+X":
			mesh.rotation_degrees.y = 90.0
		"-X":
			mesh.rotation_degrees.y = -90.0
		_:
			mesh.rotation_degrees.y = 0.0

func _scale_to_height(mesh: Node3D, height_m: float, source_h: float = 0.0) -> void:
	mesh.force_update_transform()
	var measured := _mesh_height(mesh)
	if measured < 0.05 and source_h > 0.05:
		measured = source_h
	if measured < 0.01:
		return
	mesh.scale = Vector3.ONE * (height_m / measured)

func _mesh_height(root: Node3D) -> float:
	var best := 0.0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var local: AABB = mi.get_aabb()
		if local.size.y < 0.001 and mi.mesh:
			local = mi.mesh.get_aabb()
		best = maxf(best, local.size.y)
	return best

func _attach_sockets() -> void:
	if skeleton == null:
		if log_tag == "player":
			print("[%s] missing bone RightHand" % log_tag)
			print("[%s] missing bone Hips" % log_tag)
		return
	hand_socket = _bone_marker("RightHand", ["RightHand", "mixamorig:RightHand", "mixamorig_RightHand", "Hand_R", "hand.R"])
	hips_socket = _bone_marker("Hips", ["Hips", "mixamorig:Hips", "mixamorig_Hips", "Hip", "pelvis"])

func _bone_marker(label: String, names: Array) -> BoneAttachment3D:
	var idx := -1
	for n in names:
		idx = skeleton.find_bone(str(n))
		if idx != -1:
			break
	if idx == -1:
		for i in skeleton.get_bone_count():
			var bn := skeleton.get_bone_name(i)
			for n in names:
				if bn.ends_with(str(n)) or bn.contains(str(n)):
					idx = i
					break
			if idx != -1:
				break
	if idx == -1:
		if log_tag == "player":
			print("[%s] missing bone %s" % [log_tag, label])
		return null
	var att := BoneAttachment3D.new()
	att.name = "%sSocket" % label
	att.bone_idx = idx
	skeleton.add_child(att)
	var mark := Marker3D.new()
	mark.name = label
	att.add_child(mark)
	return att
