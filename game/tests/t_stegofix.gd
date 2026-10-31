extends SceneTree
## STEGOFIX: the stegosaurus always draws its rigged Tripo model, never the procedural box placeholder.
## Both variants (graded, ochre) load with every clip the species file lists, the variant pick is deterministic
## and about 50/50, and the feet stay on the floor in the standing clips.
## Run: Godot --headless --path game --script res://tests/t_stegofix.gd  -> "[t_stegofix] PASS", exit 0.

const ID := &"stegosaurus"
const EXTRA_CLIPS: Array[StringName] = [&"walk_back", &"strafe_left", &"strafe_right", &"kick", &"charge"]
const FEET := ["hind_toe_L", "hind_toe_R", "front_toe_L", "front_toe_R"]
## Standing clips: the lowest toe stays within this of its rest height (m, game scale; the mesh is 6.4 m tall).
const GROUND_TOL := 0.06

var failures: Array[String] = []
var _started := false
var data: Node
## Game classes need the autoloads, so they are loaded on the first frame (as t_canim does).
var CV: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	CV = load("res://scripts/creatures/creature_view.gd")
	_test_no_placeholder_path()
	for v in [&"", &"graded", &"ochre"]:
		_test_variant(v)
	_test_pick()
	_test_wild_spawn_picks()
	if failures.is_empty():
		print("[t_stegofix] PASS")
		quit(0)
	else:
		print("[t_stegofix] FAIL %d" % failures.size())
		quit(1)
	return true

func _expect(ok: bool, what: String) -> void:
	print("[t_stegofix] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

## The code paths that drew the blocky stegosaurus are gone: the in-game override and the plated box fallback.
func _test_no_placeholder_path() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/creatures/creature_view.gd")
	_expect(not src.contains("force_safe_placeholder") and not src.contains("allow_stegosaurus_rig"), "no stegosaurus placeholder override in creature_view")
	_expect(not src.contains("&\"stegosaurus\""), "no stegosaurus special case left in creature_view (plated boxes)")
	_expect(ResourceLoader.exists("res://assets/creatures/stegosaurus/stegosaurus.glb"), "stegosaurus GLB exists")

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _albedo_path(view) -> String:
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var mat := m.get_active_material(0)
		var tex: Texture2D = (mat as ShaderMaterial).get_shader_parameter("albedo_tex") if mat is ShaderMaterial else (mat as StandardMaterial3D).albedo_texture
		return tex.resource_path if tex else ""
	return ""

func _test_variant(v: StringName) -> void:
	var def = data.creature(ID)
	var view = CV.new()
	root.add_child(view)
	view.setup(def, v)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	var tag := "variant '%s'" % v
	_expect(view.using_glb and view.rig != null, "%s draws the rigged GLB" % tag)
	_expect(_boxes(view) == 0, "%s has no box/cylinder placeholder meshes" % tag)
	if view.rig == null:
		view.free()
		return
	var alb := _albedo_path(view)
	var want := "ochre" if v == &"ochre" else "graded"
	_expect(alb.contains(want), "%s albedo is the %s map (%s)" % [tag, want, alb])
	var clips: Array = def.pipeline.get("clips", [])
	_expect(clips.size() >= 9, "%s species lists its clips" % tag)
	for clip in clips + EXTRA_CLIPS:
		var authored := ResourceLoader.exists("res://assets/creatures/stegosaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "%s clip %s authored and loaded" % [tag, clip])
	if v == &"":
		_test_grounded(view)
	view.free()

func _toe_heights(view) -> float:
	var sk: Skeleton3D = view.rig.skeleton
	var lo := INF
	for b in FEET:
		var i := sk.find_bone(b)
		lo = minf(lo, (sk.global_transform * sk.get_bone_global_pose(i)).origin.y - view.global_position.y)
	return lo

func _test_grounded(view) -> void:
	var ap: AnimationPlayer = view.rig.anim_player
	var sk: Skeleton3D = view.rig.skeleton
	for b in FEET:
		_expect(sk.find_bone(b) >= 0, "bone %s exists" % b)
	sk.reset_bone_poses()
	var rest := INF
	for b in FEET:
		var i := sk.find_bone(b)
		rest = minf(rest, (sk.global_transform * sk.get_bone_global_rest(i)).origin.y - view.global_position.y)
	for clip in [&"idle", &"walk", &"attack_primary", &"attack_heavy", &"hit_react", &"alert"]:
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 13:
			ap.seek(a.length * float(k) / 12.0, true)
			worst = maxf(worst, absf(_toe_heights(view) - rest))
		_expect(worst <= GROUND_TOL, "%s: lowest toe stays on the floor (worst %.3f m off rest)" % [clip, worst])

func _test_pick() -> void:
	var def = data.creature(ID)
	var n := {}
	for i in 400:
		var v: StringName = CV.pick_variant(def, "stegosaurus@(%d, 0, %d)" % [i * 7, i * 13])
		n[v] = int(n.get(v, 0)) + 1
	_expect(n.size() == 2 and n.has(&"graded") and n.has(&"ochre"), "picks both variants %s" % n)
	_expect(absi(int(n.get(&"graded", 0)) - 200) <= 50, "pick is about 50/50 %s" % n)
	_expect(CV.pick_variant(def, "k") == CV.pick_variant(def, "k"), "pick is deterministic")
	_expect(CV.pick_variant(data.creature(&"velociraptor"), "k") == &"", "species without variants pick none")

func _test_wild_spawn_picks() -> void:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	root.add_child(c)
	c.global_position = Vector3(31, 0, -17)
	c.spawn(data.creature(ID))
	_expect(c.variant in [&"graded", &"ochre"] and c.view.variant == c.variant, "a wild stegosaurus spawn gets a variant (%s)" % c.variant)
	_expect(c.view.using_glb and _boxes(c.view) == 0, "a wild stegosaurus spawn draws the GLB, no boxes")
	c.free()
