extends SceneTree
## SP-WOOLLY_RHINO: the woolly rhino draws its rigged Tripo model with every clip, stands 2.95 m, keeps its feet on
## the floor, its signature moves hit with the right part at their hit frames (forefoot stamp, wide horn sweep, horn
## toss), the hits are judged at the horn / forefeet (a survivor behind it is not hit by the sweep), the paw-and-charge
## tactic runs and tosses a survivor, an alpha wears the alpha skin, and the tundra spawn tables list it.
## Run: Godot --headless --path game --script res://tests/t_sp_woolly_rhino.gd  -> "[t_sp_woolly_rhino] PASS", exit 0.

const ID := &"woolly_rhino"
const FEET := ["BackFoot.L", "BackFoot.R", "FrontFoot.L", "FrontFoot.R"]
const GROUND_TOL := 0.08  ## m: the lowest foot bone stays this close to its rest height in standing clips

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
	root.get_node("Game").time_of_day = 0.4  # daytime: a grazer asleep at night would not fight
	CV = load("res://scripts/creatures/creature_view.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_sp_woolly_rhino] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_data()
	_test_view()
	await _test_hits()
	await _test_charge()
	await _test_alpha()
	if failures.is_empty():
		print("[t_sp_woolly_rhino] PASS")
		quit(0)
	else:
		print("[t_sp_woolly_rhino] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _test_data() -> void:
	var def = data.creature(ID)
	_expect(def != null and def.tameable and def.climate == &"tundra", "species loads: tameable, tundra")
	_expect(def != null and &"mount" in def.tamed_role and &"bag" in def.tamed_role, "tamed roles bag + mount (ASSUMPTION cargo mount)")
	var TB: GDScript = load("res://scripts/creatures/brains/tactical_brain.gd")
	var tac: Dictionary = TB.tactics_for_def(def)
	var steps: Array = []
	for q in tac.get("sequences", []):
		steps.append(",".join((q as Dictionary).get("steps", [])))
	_expect("display,charge" in steps and float(tac.get("toss_lift_mps", 0.0)) > 0.0 and tac.has("heavy_cd"),
		"tactics: horned_charger base with paw (display) -> charge, toss lift, heavy sweep (%s)" % [steps])
	# Spawn tables: the tundra islands list it and it is eligible (has a model).
	var isl: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	for id in ["tundra_30", "tundra_55"]:
		var found := false
		for where in (isl[id]["spawns"] as Dictionary).values():
			for row in where:
				found = found or str((row as Dictionary).get("species", "")) == str(ID)
		_expect(found, "%s spawn table has woolly_rhino" % id)
	_expect(ResourceLoader.exists("res://assets/creatures/woolly_rhino/woolly_rhino.glb"), "model exists (spawns, not a fallthrough)")
	var panel: GDScript = load("res://scripts/dev/lab_spawn_panel.gd")
	_expect(ID in panel.listed_species(false), "creature lab dropdown lists it")

func _test_view() -> void:
	var def = data.creature(ID)
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null and _boxes(view) == 0, "draws the rigged GLB, no boxes")
	if view.rig == null:
		view.free()
		return
	for clip in def.pipeline.get("clips", []):
		var authored := ResourceLoader.exists("res://assets/creatures/woolly_rhino/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Horn", "HornTip", "Tail1"] + FEET:
		_expect(sk.find_bone(b) >= 0, "bone %s" % b)
	var aabb := AABB()
	var first := true
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	_expect(absf(aabb.size.y - 2.95) < 0.15, "stands %.2f m (1.8 m hump x1.6)" % aabb.size.y)
	_expect(maxf(aabb.size.x, aabb.size.z) > 5.5, "%.1f m nose to tail" % maxf(aabb.size.x, aabb.size.z))
	var ap: AnimationPlayer = view.rig.anim_player
	var vp: Vector3 = (view as Node3D).global_position
	sk.reset_bone_poses()
	var rest := INF
	for b in FEET:
		rest = minf(rest, (sk.global_transform * sk.get_bone_global_rest(sk.find_bone(b))).origin.y - vp.y)
	for clip in [&"idle", &"walk", &"run", &"charge", &"strafe_left", &"walk_back", &"alert", &"attack_primary", &"attack_heavy", &"toss", &"hit_react", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 13:
			ap.seek(a.length * float(k) / 12.0, true)
			var lo := INF
			for b in FEET:
				lo = minf(lo, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b))).origin.y - vp.y)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL, "%s: a foot stays planted (worst %.3f m off the floor)" % [clip, worst])
	# Signature moves at their hit frames (anim_events.json hit_frac).
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var tip := sk.find_bone("HornTip")
	var at_hit := func(clip: StringName, bone: int, dt: float) -> Array:
		sk.reset_bone_poses()
		ap.play(clip)
		var t: float = ap.get_animation(clip).length * float((data.anim_events["clips"][str(clip)] as Dictionary)["hit_frac"])
		ap.seek(t - dt, true)
		var b := (sk.global_transform * sk.get_bone_global_pose(bone)).origin
		ap.seek(t, true)
		return [(sk.global_transform * sk.get_bone_global_pose(bone)).origin, b]
	var sw: Array = at_hit.call(&"attack_heavy", tip, 0.1)
	var lateral: float = absf(((sw[0] as Vector3) - (sw[1] as Vector3)).dot(right)) / 0.1
	_expect(lateral > 4.0 and ((sw[0] as Vector3) - vp).dot(fwd) > 2.0, "horn sweep: the horn crosses the front at %.1f m/s, %.1f m ahead" % [lateral, ((sw[0] as Vector3) - vp).dot(fwd)])
	var ts: Array = at_hit.call(&"toss", tip, 0.08)
	_expect(((ts[0] as Vector3) - (ts[1] as Vector3)).y / 0.08 > 2.5, "toss: the horn hooks up at the hit (%.1f m/s)" % [((ts[0] as Vector3) - (ts[1] as Vector3)).y / 0.08])
	var best := -INF
	for f in ["FrontFoot.L", "FrontFoot.R"]:
		var st: Array = at_hit.call(&"attack_primary", sk.find_bone(f), 0.1)
		var rest_f: Vector3 = (sk.global_transform * sk.get_bone_global_rest(sk.find_bone(f))).origin
		if ((st[0] as Vector3).y - vp.y) < rest - vp.y + 0.15 + rest:
			best = maxf(best, ((st[0] as Vector3) - rest_f).dot(fwd))
	_expect(best > 0.5, "stamp: a forefoot lands %.2f m ahead of where it stands" % best)
	view.free()

func _arena() -> Array:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	return [host, player, c]

## The moves land through their parts: a survivor in front takes the stamp and the sweep; one standing behind the
## rump, inside the old centre reach, is not swept (the horn is nowhere near her).
func _test_hits() -> void:
	for case in [[&"attack_primary", -2.3, true], [&"attack_heavy", -2.6, true], [&"attack_heavy", 2.2, false]]:
		var a: Array = await _arena()
		var host: Node3D = a[0]
		var player = a[1]
		var c = a[2]
		player.process_mode = Node.PROCESS_MODE_DISABLED
		c.global_position = Vector3(0, 0.1, float(case[1]) * -1.0)
		c.spawn(data.creature(ID))
		# face -Z toward the survivor for the front cases, away from her for the rear case
		c.look_at(Vector3(0, 0.1, 0) if case[2] else c.global_position * 2.0 - Vector3(0, 0.1, 0), Vector3.UP)
		c.brain.attack_target = player
		if "_provoked_until" in c.brain:
			c.brain._provoked_until = c.brain._now_s() + 30.0
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		var hits := [0]
		c.anim.attack_hit.connect(func(clip: StringName) -> void:
			if clip == case[0]:
				hits[0] += 1)
		var hp0: float = player.vitals.health
		c.anim.play_clip(case[0])
		for _f in 150:
			await physics_frame
		var hurt: bool = player.vitals.health < hp0
		_expect(hits[0] == 1 and hurt == case[2], "%s with the survivor %s: hit frame %d, %s (hp %.0f -> %.0f)" % [case[0],
			"in front" if case[2] else "behind the rump", hits[0], "lands" if hurt else "misses", hp0, player.vitals.health])
		host.free()

## Paw then charge: the tactic plays the paw-the-ground alert, charges, the horn reaches her, the toss clip plays and
## she is shoved and lifted.
func _test_charge() -> void:
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = a[2]
	c.global_position = Vector3(0, 0.1, 7.5)  # the arena has no navmesh: the direct-steer fallback reaches 12 m
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	var b = c.brain
	_expect((b.get_script() as Script).resource_path.ends_with("tactical_brain.gd"), "a TacticalBrain runs it")
	b.attack_target = player
	b._provoked_until = b._now_s() + 60.0
	b._seq = [&"charge"]
	b._start_display()
	_expect(c.anim.current_clip == &"alert", "display plays the paw-the-ground alert")
	var tossed := [false, 0.0]
	b.tactic.connect(func(t: StringName) -> void:
		if OS.has_environment("RHINO_DEBUG"):
			print("  tactic ", t, " d=", c.global_position.distance_to(player.global_position), " hp=", player.vitals.health)
		if t == &"toss":
			tossed[0] = true)
	player.vitals.max_health = 1000000.0  # a tier-38 ram one-shots a fresh survivor; keep her up to see the toss
	player.vitals.health = player.vitals.effective_max_health()
	var hp0: float = player.vitals.health
	var y0: float = player.global_position.y
	for _f in 600:
		await physics_frame
		tossed[1] = maxf(tossed[1], player.global_position.y - y0)
		if OS.has_environment("RHINO_DEBUG") and _f % 20 == 0:
			print("  f%d state=%s clip=%s d=%.2f pos=%s stag=%.2f vel=%s path=%s" % [_f, b.state, c.anim.current_clip, c.global_position.distance_to(player.global_position), c.global_position, c.stagger_left, c.velocity, c._path_active])
		if tossed[0] and _f > 0 and player.vitals.health < hp0 and tossed[1] > 1.0:
			break
	_expect(tossed[0], "the charge reaches her and tosses")
	_expect(player.vitals.health < hp0, "the charge hurts (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	_expect(tossed[1] > 1.0, "she is tossed off her feet (%.2f m)" % tossed[1])
	host.free()

func _test_alpha() -> void:
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var c = a[2]
	c.alpha_spawn = true
	c.spawn(data.creature(ID))
	_expect(c.is_alpha() and c.variant == &"alpha", "an alpha spawn wears the alpha variant (%s)" % c.variant)
	var tex_ok := false
	for mi in c.view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in (m.mesh.get_surface_count() if m.mesh else 0):
			var mat := m.get_active_material(i)
			tex_ok = tex_ok or (mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null \
				and (mat as BaseMaterial3D).albedo_texture.resource_path.ends_with("woolly_rhino_alpha_albedo.jpg"))
			tex_ok = tex_ok or (mat is ShaderMaterial and str((mat as ShaderMaterial).get_shader_parameter("albedo_tex").resource_path if (mat as ShaderMaterial).get_shader_parameter("albedo_tex") else "").ends_with("alpha_albedo.jpg"))
	_expect(tex_ok, "the alpha skin texture is on the hide")
	var c2 = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c2)
	c2.global_position = Vector3(20, 0.1, 0)
	c2.spawn(data.creature(ID))
	_expect(c2.variant == &"", "a regular spawn keeps the regular hide (%s)" % c2.variant)
	host.free()
