extends SceneTree
## STEGO: the in-game stegosaurus is the v2 GLB (Tripo mesh, Opus rig), not the old box placeholder.
## Checks the real mesh, skeleton and every clip through the game's own spawn path, the -Z facing and
## 6.4 m scale, the hurt/knockdown/death/alert states, stride-matched walk and run through the game's
## physics step, and the skin in motion (CPU-skinned edge growth, which the v1 skin fails). Fails on
## the old forced placeholder. Needs the STEGO hooks patch (creature.gd stride_matched) applied.
## Run: Godot --headless --path game --script res://tests/t_stego.gd -> "[t_stego] PASS", exit 0.

const DT := 1.0 / 60.0
const ID := &"stegosaurus"
const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy", &"hit_react", &"knockdown", &"death", &"alert"]
const TOES: Array[String] = ["front_toe_L", "front_toe_R", "hind_toe_L", "hind_toe_R"]
## Planted toe speed / body speed window of t_canim's stride check.
const STRIDE_MIN := 0.75
const STRIDE_MAX := 1.30
## ASSUMPTION: a triangle edge growing more than 0.25 m in a pose is visible stretching on a 6.4 m animal.
## v2's worst is 0.20 m (a few shoulder-crease edges, death at 50 %); the v1 skin reaches 0.39 m in run.
const GROW_MAX := 0.25
const SECTIONS := 6

var failures: Array[String] = []
var _started := false
var _sections := 0  ## bumped at the end of each _test_*: a runtime error aborts one function, not the run
var data: Node
var clips: GDScript

## Creature classes reference the Data autoload, which exists only after the first frame.
func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	clips = load("res://scripts/creatures/creature_clips.gd")
	_test_real_model()
	_test_clips()
	_test_states()
	_test_stride()
	_test_skin_in_motion()
	_test_no_placeholder_code()
	_expect(_sections == SECTIONS, "%d of %d sections ran to the end" % [_sections, SECTIONS])
	if failures.is_empty():
		print("[t_stego] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_stego] FAIL " + f)
		quit(1)
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_stego] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _spawn():
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	root.add_child(c)
	c.spawn(data.creature(ID))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

## The GLB rig, or a failed expectation and the section skipped.
func _rigged(c, what: String) -> bool:
	if c.view.using_glb:
		return true
	_expect(false, "%s: no GLB rig" % what)
	c.free()
	_sections += 1
	return false

func _advance(c, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.00001:
		c.anim.tree.advance(DT)
		t += DT

func _bone(c, name: String) -> Vector3:
	var sk: Skeleton3D = c.view.rig.skeleton
	return c.to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(name)).origin)

func _mesh(c) -> MeshInstance3D:
	return c.view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D

func _test_real_model() -> void:
	var c = _spawn()
	_expect(c.view.using_glb and c.view.rig != null and c.view.get_node_or_null("Body") == null, "spawned stegosaurus is the GLB rig, not the box placeholder (using_glb=%s)" % c.view.using_glb)
	if not c.view.using_glb:
		c.free()
		_sections += 1
		return
	var sk: Skeleton3D = c.view.rig.skeleton
	var bones := sk.get_bone_count() if sk else 0
	_expect(bones == 34 and sk.find_bone("jaw") != -1 and sk.find_bone("tail_07") != -1, "v2 skeleton: %d bones (want 34, incl. jaw and tail_07)" % bones)
	var mi := _mesh(c)
	var tris: int = (mi.mesh.surface_get_array_index_len(0) / 3) if mi and mi.mesh else 0
	_expect(mi != null and mi.skin != null and tris > 10000, "skinned v2 mesh: %d triangles, skin %s" % [tris, mi.skin != null if mi else false])
	# Scale: rest AABB in the creature's frame spans 0 .. height_meters (feet on the ground, 6.4 m).
	var box: AABB = c.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
	_expect(absf(box.size.y - c.def.height_meters) <= 0.05 and absf(box.position.y) <= 0.05, "rest mesh spans y %.2f .. %.2f m (want 0 .. %.1f)" % [box.position.y, box.end.y, c.def.height_meters])
	# Facing: Godot forward is -Z. The head leads, the tail trails.
	var head := _bone(c, "head")
	var tail := _bone(c, "tail_07")
	_expect(head.z < -2.0 and tail.z > 4.0, "faces -Z: head z %.2f, tail tip z %.2f" % [head.z, tail.z])
	# Plates / HP bar anchor (creature_plates: height + 0.3) sits just above the animal's top in idle.
	_advance(c, 0.5)
	var top := _skinned_extent(c, true)
	_expect(top > c.def.height_meters - 0.8 and top <= c.def.height_meters + 0.2, "idle top of the back plates %.2f m; HP bar anchor at %.2f m sits above it" % [top, c.def.height_meters + 0.3])
	_expect(c.shape.shape is CapsuleShape3D and absf((c.shape.shape as CapsuleShape3D).height - c.def.height_meters) < 0.01, "collision capsule %.2f m tall" % (c.shape.shape as CapsuleShape3D).height)
	c.free()
	_sections += 1

## Every authored clip is in the player from its own GLB: each track resolves to a bone of the v2
## skeleton (0 unresolved), the pose differs from idle (not an idle fallback), and the tree has a state.
func _test_clips() -> void:
	var c = _spawn()
	if not _rigged(c, "clips"):
		return
	var sk: Skeleton3D = c.view.rig.skeleton
	var ap: AnimationPlayer = c.anim.player
	var idle := ap.get_animation(&"idle")
	for clip in CLIPS:
		var a := ap.get_animation(clip) if ap.has_animation(clip) else null
		var tracks := a.get_track_count() if a else 0
		var unresolved := 0
		for t in tracks:
			var p := str(a.track_get_path(t))
			if p.find(":") == -1 or sk.find_bone(p.substr(p.find(":") + 1)) == -1:
				unresolved += 1
		var gap := 0.0 if clip == &"idle" or a == null else _pose_gap(idle, a)
		_expect(a != null and tracks > 0 and unresolved == 0 and (clip == &"idle" or gap > 0.05) and c.anim.has_state(clip),
			"%s: %d tracks, %d unresolved, %.2f s, largest rotation gap to idle %.2f rad, tree state %s" % [clip, tracks, unresolved, a.length if a else 0.0, gap, c.anim.has_state(clip)])
	c.free()
	_sections += 1

## The game's own triggers reach each clip: a real hit plays the authored hit_react (gated on
## pipeline.authored_clips), knockdown holds, death ends on the ground, alert returns to idle.
func _test_states() -> void:
	var c = _spawn()
	if not _rigged(c, "states"):
		return
	var pb: AnimationNodeStateMachinePlayback = c.anim.tree.get("parameters/playback")
	c._stagger_immune_until = -1.0
	c._on_damaged(1.0, null)
	_advance(c, 0.1)
	_expect(c.anim.current_clip == &"hit_react" and pb.get_current_node() == &"hit_react", "real hit plays hit_react (clip %s, state %s)" % [c.anim.current_clip, pb.get_current_node()])
	_advance(c, 1.0)
	_expect(pb.get_current_node() == &"idle", "hit_react returns to idle (%s)" % pb.get_current_node())
	for clip in [&"alert", &"attack_primary", &"attack_heavy"]:
		c.anim.play_clip(clip)
		_advance(c, 0.1)
		var on: bool = pb.get_current_node() == clip
		_advance(c, 4.0)
		_expect(on and pb.get_current_node() == &"idle", "%s plays, then idle (%s)" % [clip, pb.get_current_node()])
	c.anim.play_clip(&"knockdown")
	_advance(c, 4.0)
	var low := _skinned_extent(c, false)
	_expect(pb.get_current_node() == &"knockdown" and absf(low) < 0.35, "knockdown held, body on the ground: lowest skin %.2f m" % low)
	c.anim.release_knockdown()
	_advance(c, 0.5)
	c.anim.play_clip(&"death")
	_advance(c, 4.0)
	low = _skinned_extent(c, false)
	var top := _skinned_extent(c, true)
	_expect(pb.get_current_node() == &"death" and absf(low) < 0.35 and top < c.def.height_meters * 0.8, "death ends lying down: skin %.2f .. %.2f m" % [low, top])
	c.free()
	_sections += 1

## Planted toes keep pace with the body. One real physics step (creature.gd picks gait and cadence) at
## roam and chase speed, then set_move_speed at a walk (40 % of top, t_canim's assumption).
func _test_stride() -> void:
	var c = _spawn()
	if not _rigged(c, "stride"):
		return
	_expect(clips.natural_speed(c.def, &"walk", c.anim.player.get_animation(&"walk").length) > 0.0 \
		and clips.natural_speed(c.def, &"run", c.anim.player.get_animation(&"run").length) > 0.0, "walk and run natural speeds baked for the v2 clips")
	for state in [&"roam", &"approach"]:
		c.brain.state = state
		c._path_active = true
		c._path_goal = c.global_position + Vector3(0.0, 0.0, -8.0)
		c.velocity = Vector3.ZERO
		c._physics_process(DT)
		var v := Vector2(c.velocity.x, c.velocity.z).length()
		_advance(c, 0.5)
		_stride_line(c, v, "game physics step (%s)" % state)
	c._path_active = false
	var walk: float = c.move_speed_mps() * 0.4
	c.anim.set_move_speed(walk)
	_advance(c, 0.5)
	_stride_line(c, walk, "set_move_speed")
	c.free()
	_sections += 1

func _stride_line(c, v: float, what: String) -> void:
	var gait: StringName = c.anim.current_clip
	var cycle: float = c.anim.player.get_animation(gait).length / maxf(0.01, c.anim.cadence(gait))
	var feet := _planted(c, cycle * 2.0, 480)
	var ok := v > 0.5
	for f in feet:
		ok = ok and f / v >= STRIDE_MIN and f / v <= STRIDE_MAX
	_expect(ok, "%s at %.2f m/s -> %s x%.2f: planted toes %s m/s (want %.2f-%.2f of body)" % [what, v, gait, c.anim.cadence(gait), feet, STRIDE_MIN, STRIDE_MAX])

## Median toe speed while the toe is within tol of its lowest point (stride method of tools/bake_clip_speeds.py).
func _planted(c, seconds: float, samples: int) -> Array[float]:
	var ys: Array = []
	var zs: Array = []
	for t in TOES:
		ys.append(PackedFloat32Array())
		zs.append(PackedFloat32Array())
	var step := seconds / float(samples)
	for i in samples + 1:
		if i > 0:
			c.anim.tree.advance(step)
		for k in TOES.size():
			var p := _bone(c, TOES[k])
			ys[k].append(p.y)
			zs[k].append(p.z)
	var tol := maxf(0.02, c.def.height_meters * 0.015)
	var out: Array[float] = []
	for k in TOES.size():
		var ymin: float = ys[k][0]
		for y in ys[k]:
			ymin = minf(ymin, y)
		var vels: Array[float] = []
		for i in samples:
			if ys[k][i] <= ymin + tol and ys[k][i + 1] <= ymin + tol:
				vels.append((zs[k][i + 1] - zs[k][i]) / step)
		vels.sort()
		out.append(snappedf(absf(vels[vels.size() / 2]) if vels.size() > 0 else 0.0, 0.01))
	return out

## CPU-skins the mesh at 5 points of every clip and compares each triangle edge with its rest length:
## worm-like stretching or a plate tearing off its base shows as edges that grow tens of centimetres.
func _test_skin_in_motion() -> void:
	var c = _spawn()
	if not _rigged(c, "skin"):
		return
	var v2 := _stretch(c.view.rig, c.anim.player)
	_expect(v2[0] <= GROW_MAX, "v2 skin in motion: worst edge growth %.3f m in %s, %d edge-samples over 0.10 m (want <= %.2f m)" % [v2[0], v2[1], v2[2], GROW_MAX])
	c.free()
	# The check must catch the skin that earned the old override: v1 (transplanted, kept under v1/).
	var old: Node3D = load("res://scripts/core/rigged_model.gd").new()
	root.add_child(old)
	if old.setup("res://assets/creatures/stegosaurus/v1/stegosaurus.glb", "res://assets/creatures/stegosaurus/v1/anim", "+Z", 6.4, "creature", false, 0.8458):
		var v1 := _stretch(old, old.anim_player)
		_expect(v1[0] > GROW_MAX, "the v1 skin fails the same check: worst edge growth %.3f m in %s, %d edge-samples over 0.10 m" % [v1[0], v1[1], v1[2]])
	else:
		_expect(false, "v1 GLB loads for the control check")
	old.free()
	_sections += 1

## [worst growth in metres, "clip@t", edge-samples grown > 0.10 m] over CLIPS sampled at 0, 25, 50, 75, 100 %.
func _stretch(rig: Node3D, ap: AnimationPlayer) -> Array:
	var mi := rig.mesh_root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var sk: Skeleton3D = rig.skeleton
	var scale: float = rig.mesh_root.scale.x  # v1 is scaled x7.6 above the skeleton; v2 is authored at size
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var edges := PackedInt32Array()
	var seen := {}
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := idx[t + e]
			var b := idx[t + (e + 1) % 3]
			var key := mini(a, b) * verts.size() + maxi(a, b)
			if not seen.has(key):
				seen[key] = true
				edges.append(a)
				edges.append(b)
	var rest := PackedFloat32Array()
	rest.resize(edges.size() / 2)
	for i in rest.size():
		rest[i] = verts[edges[i * 2]].distance_to(verts[edges[i * 2 + 1]])
	var worst := 0.0
	var at := ""
	var over := 0
	for clip in CLIPS:
		if not ap.has_animation(clip):
			continue
		sk.reset_bone_poses()  # a clip leaves the bones it does not key where the previous one put them
		ap.play(clip)
		var length := ap.get_animation(clip).length
		for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
			ap.seek(length * f, true)
			var pos := _skin(mi, sk, arr)
			for i in rest.size():
				var g := (pos[edges[i * 2]].distance_to(pos[edges[i * 2 + 1]]) - rest[i]) * scale
				if g > 0.10:
					over += 1
				if g > worst:
					worst = g
					at = "%s@%d%%" % [clip, int(f * 100.0)]
	ap.stop()
	return [worst, at, over]

## Skinned positions in the skeleton's space (bone global pose x bind pose x vertex).
func _skin(mi: MeshInstance3D, sk: Skeleton3D, arr: Array) -> PackedVector3Array:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / verts.size()
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = sk.find_bone(skin.get_bind_name(i))
		mats.append(sk.get_bone_global_pose(b) * skin.get_bind_pose(i))
	var out := PackedVector3Array()
	out.resize(verts.size())
	for v in verts.size():
		var p := Vector3.ZERO
		for k in per:
			var w := weights[v * per + k]
			if w > 0.0:
				p += (mats[bones[v * per + k]] * verts[v]) * w
		out[v] = p
	return out

## Highest (top=true) or lowest skinned vertex height above the creature's feet plane, current pose.
func _skinned_extent(c, top: bool) -> float:
	var mi := _mesh(c)
	var to_c: Transform3D = c.global_transform.affine_inverse() * mi.global_transform
	var best := -INF if top else INF
	for p in _skin(mi, c.view.rig.skeleton, mi.mesh.surface_get_arrays(0)):
		var y := (to_c * p).y
		best = maxf(best, y) if top else minf(best, y)
	return best

func _pose_gap(a: Animation, b: Animation) -> float:
	var gap := 0.0
	for t in b.get_track_count():
		if b.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var ta := a.find_track(b.track_get_path(t), Animation.TYPE_ROTATION_3D)
		if ta == -1:
			continue
		for f in [0.25, 0.5, 0.75]:
			var qa := a.rotation_track_interpolate(ta, a.length * f)
			var qb := b.rotation_track_interpolate(t, b.length * f)
			gap = maxf(gap, qa.angle_to(qb))
	return gap

## The box placeholder for this species is gone from the view script (no dead fallback left behind).
func _test_no_placeholder_code() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/creatures/creature_view.gd")
	_expect(not src.is_empty() and not src.contains("stegosaurus"), "creature_view.gd has no stegosaurus override or fallback")
	_sections += 1
