extends SceneTree
## SP-DEINONYCHUS (v4, from the owner's turnaround sheet: "this is deinonychus, fix"): the deinonychus draws its new
## rigged Tripo model (no box placeholder) with every listed clip, a real Jaw bone and ClawTip markers on the hands,
## 2.87 m tall and about 6 m long, its feet stay on the floor in the standing clips, each hit comes from its part at
## the hit frame (the jaws, the hand claws, the sickle foot), the arms (and the folded wings on them) swing in every
## attack, the kept moves (3-hit chomp combo, pounce, leap_back) are still there, the sickle slash lands through the
## hitboxes in front and misses beside the rump, the pounce lands through the hitboxes (no pin: that stays the Raptor's), the colour-morph hook
## is in place, and its spawn rows still spawn it.
## Run: Godot --headless --path game --script res://tests/t_sp_deinonychus.gd  -> "[t_sp_deinonychus] PASS", exit 0.

const ID := &"deinonychus"
const FEET := ["BackFoot.L", "BackFoot.R", "BackFoot.L_end", "BackFoot.R_end"]
const GROUND_TOL := 0.08  ## m: the lowest foot point stays this close to its rest height in standing clips
## clip -> [hit fracs, bone]: anim_events hit fracs and pipeline.hit_parts
const HITS := {&"attack_primary": [[0.42], "Head"], &"attack_heavy": [[0.72], "BackFoot.R"], &"pounce": [[0.7], "Head"]}

var failures: Array[String] = []
var _started := false
var data: Node
var CV: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	CV = load("res://scripts/creatures/creature_view.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_sp_deinonychus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_slash_part()
	await _test_pounce()
	_test_kept_moves()
	_test_hook()
	if failures.is_empty():
		print("[t_sp_deinonychus] PASS")
		quit(0)
	else:
		print("[t_sp_deinonychus] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _bone_pos(sk: Skeleton3D, b: String, rest: bool = false) -> Vector3:
	var i := sk.find_bone(b)
	return sk.global_transform * (sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i)).origin

func _test_view() -> void:
	var def = data.creature(ID)
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/deinonychus/deinonychus.glb"), "deinonychus data and GLB exist")
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null, "draws the rigged GLB")
	_expect(_boxes(view) == 0, "no box/cylinder placeholder meshes")
	if view.rig == null:
		view.free()
		return
	var clips: Array = def.pipeline.get("clips", [])
	_expect(clips.size() >= 21, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/deinonychus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Tail5", "ClawTip.L", "ClawTip.R"] + FEET:
		_expect(sk.find_bone(b) >= 0, "bone %s in the rig" % b)
	var aabb := AABB()
	var first := true
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	var long_side := maxf(aabb.size.x, aabb.size.z)
	_expect(absf(aabb.size.y - def.height_meters) < 0.15, "height %.2f m (data %.2f)" % [aabb.size.y, def.height_meters])
	_expect(long_side > 5.5 and long_side < 6.6, "%.1f m long: between velociraptor (3.7 m) and the raptor (7.5 m)" % long_side)
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in FEET:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	# Standing clips: some foot point stays on the floor every sampled frame (the slash stands on one leg).
	# (walk/walk_back lift the heel and toe bones mid-stride; their skin contact is gated by tools/gait/check_raptor.py)
	for clip in [&"idle", &"strafe_left", &"strafe_right", &"attack_heavy", &"hit_react", &"alert", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 24:
			ap.seek(a.length * float(k) / 24.0, true)
			var lo := INF
			for b in FEET:
				lo = minf(lo, _bone_pos(sk, b).y)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL, "%s: a foot stays on the floor (worst %.3f m off rest)" % [clip, worst])
	# Each hit's part, at its hit frame, is out in front of the body (the jaws, the sickle foot driven forward).
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	sk.reset_bone_poses()
	var head_rest := _bone_pos(sk, "Head", true)
	var foot_rest := _bone_pos(sk, "BackFoot.R", true)
	for clip in HITS:
		for frac in HITS[clip][0]:
			sk.reset_bone_poses()
			ap.play(clip)
			var a := ap.get_animation(clip)
			ap.seek(a.length * float(frac), true)
			var p := _bone_pos(sk, str(HITS[clip][1]))
			var ahead: float = (p - origin).dot(fwd)
			_expect(ahead > 1.5, "%s@%.2f: %s %.2f m ahead of the body centre" % [clip, frac, HITS[clip][1], ahead])
			if clip == &"attack_heavy":
				_expect((p - foot_rest).dot(fwd) > 1.0, "the slash drives the sickle foot %.2f m forward of its print" % (p - foot_rest).dot(fwd))
	# Arms in the attacks (owner: raptor-type species use their arms): the hand claws reach out ahead at the bite.
	for clip in [&"attack_primary", &"bite_combo", &"pounce"]:
		sk.reset_bone_poses()
		var claw_rest := _bone_pos(sk, "ClawTip.R", true)
		ap.play(clip)
		var a2 := ap.get_animation(clip)
		var best := -INF
		for k in 24:
			ap.seek(a2.length * float(k) / 24.0, true)
			best = maxf(best, (_bone_pos(sk, "ClawTip.R") - claw_rest).dot(fwd))
		_expect(best > 0.3, "%s: the hand claws reach %.2f m forward of rest" % [clip, best])
	view.free()

## The owner's verdicts: keep the 3-hit chomp combo, the pounce and the leap_back; the hitbox rows strike from the
## jaws and the ClawTip markers.
func _test_kept_moves() -> void:
	var ev: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/anim_events.json"))
	_expect((ev["clips"]["bite_combo"]["hit_fracs"] as Array).size() == 3, "bite_combo keeps its three chomps")
	for clip in ["bite_combo", "pounce", "leap_back", "hop_back", "charge"]:
		_expect(ResourceLoader.exists("res://assets/creatures/deinonychus/anim/%s.glb" % clip), "%s kept" % clip)
	var def = data.creature(ID)
	# HOPSTRAFE: it keeps its strafe (mixed), and the strafe step is a stride, not twinkle toes.
	_expect(load("res://scripts/creatures/brains/tactical_brain.gd").reposition_style(def) == &"mixed", "still a hop/strafe mix")
	var ns: Dictionary = ev["natural_speeds"][str(ID)]
	var step := float(ns["strafe_left"]) * float(ns["strafe_left_len"])
	_expect(step >= 1.1, "a strafe cycle carries it %.2f m (>= 1.1 m: big steps)" % step)
	var hb: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/hitboxes.json"))["species"][str(ID)]
	for mv in ["attack_primary", "bite_combo", "pounce"]:
		var bones: Array = (hb["moves"][mv]["parts"] as Array).map(func(p: Dictionary) -> String: return str(p["bone"]))
		_expect(bones.has("Jaw") and bones.has("ClawTip.L") and bones.has("ClawTip.R"), "%s strikes from the Jaw and both ClawTips (%s)" % [mv, bones])
	var calibrated := 0
	for mv in hb["moves"]:
		for p in hb["moves"][mv]["parts"]:
			if p.get("calibrated", false) and str(p["bone"]) in ["Jaw", "ClawTip.L", "ClawTip.R"]:
				calibrated += 1
	_expect(calibrated >= 4, "calibrated rows on the Jaw and the ClawTips (%d)" % calibrated)

## The colour-morph hook: pipeline.model_variants exists with the authored brown, ready for a red/blue albedo.
func _test_hook() -> void:
	var def = data.creature(ID)
	var rows: Dictionary = CV.model_variants(def)
	_expect(rows.has("brown"), "model_variants hook with the authored brown (%s)" % [rows.keys()])

## The species' rows in islands.json: temperate/tropical islands, and the model means nothing falls through.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect(islands.size() >= 5, "its spawn rows are still there (%d: %s)" % [islands.size(), islands])
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(deinonychus): its rows spawn deinonychus")
	_expect(cdef.eligible(ID, [ID]) == ID, "eligible(deinonychus) is the deinonychus itself")
	var def = data.creature(ID)
	_expect(def.tameable and def.tamed_role.has(&"mount") and ResourceLoader.exists("res://assets/creatures/deinonychus/mount/saddle.glb"), "tameable, rideable, with a saddle")

func _find_rows(n: Variant, out: Array, island: String) -> void:
	if n is Dictionary:
		var d := n as Dictionary
		var here := str(d.get("id", island))
		if str(d.get("species", "")) == str(ID):
			out.append(island)
		for k in d:
			_find_rows(d[k], out, here)
	elif n is Array:
		for x in n:
			_find_rows(x, out, island)

func _arena() -> Array:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(140, 1, 140)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	return [host, player]

func _dino(host: Node3D, at: Vector3, variant: StringName = &"") -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID), variant)
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## The sickle slash lands from the foot: in front it hits; beside the hindquarters (inside the centre reach, out of
## the foot's) it misses.
func _test_slash_part() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _dino(host, Vector3(0, 0.1, -3.0))
	_expect(c.brain != null and str(c.brain.get_script().resource_path).ends_with("tactical_brain.gd"), "it runs the TacticalBrain (pack_flanker)")
	_expect(c.brain.tac.get("point_blank", []).has("heavy") and not c.brain.tac.get("pin", false), "its tactics add the slash (no pin)")
	c.brain.attack_target = player
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # no turning toward her during the held windup: the foot strikes where it faces
	var parts: Array = []
	var HX: GDScript = load("res://scripts/combat/hitbox.gd")
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append(not HX.strike(c, clip, player, 0, &"", true).is_empty()))
	# Beside the rump first (a landed slash kills a fresh survivor): inside the centre reach, out of the foot's.
	var back: Vector3 = c.global_transform.basis.z.normalized()
	var right: Vector3 = c.global_transform.basis.x.normalized()
	var front: Vector3 = player.global_position
	player.global_position = c.global_position + back * 1.9 + right * 1.5 + Vector3(0, 0.8, 0)
	var flat: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(flat < c.brain.reach_to(player), "the rump spot is inside the centre reach (%.2f < %.2f m)" % [flat, c.brain.reach_to(player)])
	var hp0: float = player.vitals.health
	c.brain._set_state(&"attack")
	c.anim.play_clip(&"attack_heavy")
	for _f in 240:  # the clip holds its windup (anim_events windup_hold) before the slash
		await physics_frame
	_expect(parts == [false] and is_equal_approx(player.vitals.health, hp0), "the slash misses a survivor beside the rump: the foot does not reach (hp %.0f -> %.0f, foot %s)" % [hp0, player.vitals.health, parts])
	player.global_position = front
	parts.clear()
	c.brain._set_state(&"attack")
	c.anim.play_clip(&"attack_heavy")
	for _f in 240:
		await physics_frame
	_expect(parts == [true] and player.vitals.health < hp0, "the sickle slash lands in front (hp %.0f -> %.0f, foot %s)" % [hp0, player.vitals.health, parts])
	host.free()

## Pounce from 9 m: it leaps, lands and the pounce lands once from its jaws and hand claws (hitboxes); no pin.
func _test_pounce() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _dino(host, Vector3(0, 0.1, -9.0))
	var b = c.brain
	b.tac = b.tac.duplicate()
	b.tac["pounce_overshoot_chance"] = 0.0  # the sail-past miss is its own (random) branch
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: landed[clip] = int(landed.get(clip, 0)) + 1)
	root.get_node("Game").god_mode = true
	b._start_pounce()
	_expect(b.state == &"pounce", "the pounce starts (state %s)" % b.state)
	for _f in 240:
		await physics_frame
		if landed.has(&"pounce") and b.state != &"pounce":
			break
	_expect(seen.has(&"leap"), "it leaps")
	_expect(int(landed.get(&"pounce", 0)) == 1, "the pounce lands once (%s)" % landed)
	_expect(not seen.has(&"pin") and not player.statuses.has(&"pinned"), "no pin")
	root.get_node("Game").god_mode = false
	host.free()

func _albedo(v: Node) -> Texture2D:
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var mat := m.get_active_material(0)
		if mat is ShaderMaterial:
			return (mat as ShaderMaterial).get_shader_parameter("albedo_tex") as Texture2D
		if mat is StandardMaterial3D:
			return (mat as StandardMaterial3D).albedo_texture
	return null

func _untextured_surfaces(v: Node) -> int:
	var n := 0
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter("albedo_tex") == null:
				n += 1
			elif mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture == null:
				n += 1
	return n
