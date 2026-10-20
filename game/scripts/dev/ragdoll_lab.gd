extends Node3D
## W2-RAGDOLL gate. Every species is killed on a heightmap collider (the island's collider type) in
## three set-ups: flat, a 20-degree slope (pushed downhill) and against a rock. After the freeze the
## POSED SKIN is measured (skinned vertices, not bone heads). Four cases run at once (the budget).
## Headless prints one [ragdoll_lab] line per case and a final PASS/FAIL line (exit code 0/1).
## Run: Godot --headless --fixed-fps 60 --path game -- --lab=ragdoll_lab [--rl-species=a,b]
##   [--rl-terrain=flat,slope,rock]   cases to run (default: all 11 species x 3)
##   [--rl-suggest]                   skin-based radius suggestions per profile body, no physics
##   [--rl-perf]                      4 simultaneous ragdolls on temperate_25: added physics ms
##   [--rl-shots=<dir>]               windowed: contact sheet per terrain + one PNG per case
##   [--rl-phone=<png>]               windowed 844x390: one corpse under the game's iso camera

const SPECIES: Array[StringName] = [&"coelophysis", &"compsognathus", &"deinonychus", &"gallimimus",
	&"megaloceros", &"protoceratops", &"stegosaurus", &"tyrannosaurus", &"utahraptor",
	&"velociraptor", &"zebraceratops"]
const TERRAINS: Array[String] = ["flat", "slope", "rock"]
const SLOPE_DEG := 20.0
const SPACING := 300.0  # metres between arenas
const BATCH := 4
const TOUCH_M := 0.06  # skin gap allowed above and below the ground
const LIE_FRAC := 0.5  # hips at most this share of the standing hips height
const FOOT_FRAC := 0.75  # no foot higher than this share of the standing hips height
const LIMIT_TOL_DEG := 8.0
const STRETCH_TOL := 0.01
const SETTLE_MAX_S := 3.5
const PERF_PASSES := 5
const PERF_MAX_MS := 2.0
const PERF_SPECIES: Array[StringName] = [&"tyrannosaurus", &"utahraptor", &"megaloceros", &"velociraptor"]

var _species: Array[StringName] = []
var _terrains: Array[String] = []
var _shots := ""
var _phone := ""
var _failures: Array[String] = []
var _cam: Camera3D
var _sheets: Dictionary = {}  # terrain -> Image

func _ready() -> void:
	_species = SPECIES.duplicate()
	_terrains = TERRAINS.duplicate()
	var suggest := false
	var perf := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rl-species="):
			_species.clear()
			for s in a.substr(13).split(",", false):
				_species.append(StringName(s))
		elif a.begins_with("--rl-terrain="):
			_terrains.clear()
			for t in a.substr(13).split(",", false):
				_terrains.append(t)
		elif a == "--rl-suggest":
			suggest = true
		elif a == "--rl-perf":
			perf = true
		elif a.begins_with("--rl-shots="):
			_shots = a.substr(11)
		elif a.begins_with("--rl-phone="):
			_phone = a.substr(11)
	# The creature view only uses the stegosaurus GLB when asked (its in-game override stays).
	CreatureView.allow_stegosaurus_rig = true
	Game.debug_overlay = false  # no creature debug labels in the shots
	print("[boot] lab=ragdoll_lab renderer=%s" % RenderingServer.get_current_rendering_method())
	if perf:
		_run_perf.call_deferred()
		return
	WorldLighting.install(self, "temperate")
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.current = true
	if suggest:
		_run_suggest.call_deferred()
	elif _phone != "":
		_run_phone.call_deferred()
	else:
		_run_cases.call_deferred()

# --- arenas -----------------------------------------------------------------------------------

func _height(terrain: String, x: float) -> float:
	return -tan(deg_to_rad(SLOPE_DEG)) * x if terrain == "slope" else 0.0

## A heightmap floor like the island's (HeightMapShape3D scaled by its cell), a matching mesh with
## a 1 m grid, and for "rock" a box rock beside the creature on the side it is pushed to.
func _arena(terrain: String, at: Vector3, size: float, rock_at: Vector3, rock_size: Vector3) -> Node3D:
	var host := Node3D.new()
	host.name = "Arena_%s" % terrain
	add_child(host)
	host.global_position = at
	var res := 97
	var cell := size / float(res - 1)
	var heights := PackedFloat32Array()
	heights.resize(res * res)
	for z in res:
		for x in res:
			heights[x + z * res] = _height(terrain, (float(x) - float(res - 1) * 0.5) * cell)
	var body := StaticBody3D.new()
	host.add_child(body)
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = res
	hs.map_depth = res
	hs.map_data = heights
	cs.shape = hs
	cs.scale = Vector3(cell, 1.0, cell)
	body.add_child(cs)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 48
	var step := size / float(n)
	for zi in n:
		for xi in n:
			var x0 := -size * 0.5 + xi * step
			var z0 := -size * 0.5 + zi * step
			var quad := [Vector3(x0, _height(terrain, x0), z0), Vector3(x0 + step, _height(terrain, x0 + step), z0),
				Vector3(x0 + step, _height(terrain, x0 + step), z0 + step), Vector3(x0, _height(terrain, x0), z0 + step)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(quad[idx].x, quad[idx].z))
				st.add_vertex(quad[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _grid_material()
	body.add_child(mi)
	if terrain == "rock":
		var rock := StaticBody3D.new()
		host.add_child(rock)
		rock.position = rock_at
		rock.rotation.y = 0.35
		var rs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = rock_size
		rs.shape = box
		rock.add_child(rs)
		var rm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = rock_size
		rm.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.48, 0.45)
		mat.roughness = 0.95
		rm.material_override = mat
		rock.add_child(rm)
	return host

func _grid_material() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.42, 0.52, 0.32))
	for i in 64:
		for w in 2:
			img.set_pixel(i, w, Color(0.3, 0.38, 0.22))
			img.set_pixel(w, i, Color(0.3, 0.38, 0.22))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 1.0
	return mat

func _spawn(id: StringName, host: Node3D, at: Vector3) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(Data.creature(id))
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	if c.label:
		c.label.visible = false
	return c

# --- the cases --------------------------------------------------------------------------------

func _run_cases() -> void:
	var cases: Array[Dictionary] = []
	for t in _terrains:
		for s in _species:
			cases.append({"species": s, "terrain": t})
	var ok_count := 0
	var i := 0
	while i < cases.size():
		var batch := cases.slice(i, i + BATCH)
		for k in batch.size():
			_setup_case(batch[k], Vector3((i + k) * SPACING, 0.0, 0.0))
		await _frames(30)  # idle pose settles, capsules land on the floor
		for c in batch:
			c["stand_hips"] = _hips_height(c)
		for c in batch:
			var cr: Creature = c["creature"]
			cr.health.take_damage(cr.health.hp + 1.0, c["source"])
		var waited := 0.0
		while waited < 8.0 and not _all_frozen(batch):
			await get_tree().physics_frame
			waited += get_physics_process_delta_time()
		await _frames(2)
		for c in batch:
			_keep_corpse(c)
		for c in batch:
			if _measure(c):
				ok_count += 1
			if _shots != "":
				await _shoot(c)
		for c in batch:
			(c["host"] as Node3D).queue_free()
		await _frames(2)
		i += BATCH
	if _shots != "":
		var rm := RenderingServer.get_current_rendering_method()
		for t in _sheets:
			var path := "%s/ragdoll_%s_%s.png" % [_shots, t, rm]
			(_sheets[t] as Image).save_png(path)
			print("[ragdoll_lab] sheet %s" % path)
	_verdict("cases=%d ok=%d" % [cases.size(), ok_count])

func _setup_case(c: Dictionary, at: Vector3) -> void:
	var def: CreatureDef = Data.creature(c["species"])
	var length := maxf(2.0, def.real_length_m)
	var size := maxf(30.0, length * 3.0)
	var push := Vector3.RIGHT  # the source stands on the creature's left (-X): the blow pushes +X
	# A low rock (15 % of the creature's height) where the blow lays its head and neck down, so the
	# front of the body comes to rest across it.
	var rock_size := Vector3(maxf(0.5, def.height_meters * 0.45), maxf(0.15, def.height_meters * 0.15), maxf(0.6, length * 0.2))
	var rock_at := Vector3(def.height_meters * 0.5, _height(c["terrain"], 0.0) + rock_size.y * 0.5 - 0.05, -length * 0.42)
	var host := _arena(c["terrain"], at, size, rock_at, rock_size)
	var cr := _spawn(c["species"], host, at + Vector3(0.0, 0.05, 0.0))
	var src := Node3D.new()
	src.name = "Blow"
	host.add_child(src)
	src.global_position = at - push * 3.0
	var tag := Label3D.new()
	tag.text = "%s · %s" % [c["species"], c["terrain"]]
	tag.font_size = 48
	tag.pixel_size = maxf(0.004, def.height_meters * 0.0035)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.outline_size = 12
	host.add_child(tag)
	tag.global_position = at + Vector3(0.0, def.height_meters * 1.25 + 0.4, 0.0)
	c["host"] = host
	c["creature"] = cr
	c["source"] = src
	c["origin"] = at

## Shots can take a while on a loaded machine; the corpse must not reach its 90 s fade meanwhile.
func _keep_corpse(c: Dictionary) -> void:
	var rd := (c["creature"] as Creature).get_node_or_null("Ragdoll") as Ragdoll
	if rd and rd.corpse:
		rd.corpse.set_process(false)

func _all_frozen(batch: Array) -> bool:
	for c in batch:
		var rd := (c["creature"] as Creature).get_node_or_null("Ragdoll") as Ragdoll
		if rd == null or rd.phase != &"frozen":
			return false
	return true

func _frames(n: int) -> void:
	for k in n:
		await get_tree().physics_frame

func _hips_height(c: Dictionary) -> float:
	var cr: Creature = c["creature"]
	var sk := cr.view.rig.skeleton if cr.view.rig else null
	if sk == null:
		return cr.def.height_meters * 0.5
	var hb := sk.find_bone(str(Ragdoll.profile(cr.def.id).get("hips", "Hips")))
	if hb < 0:
		return cr.def.height_meters * 0.5
	var p := sk.global_transform * sk.get_bone_global_pose(hb).origin
	return p.y - _ground_at(c, p)

func _ground_at(c: Dictionary, p: Vector3) -> float:
	var ex: Array[RID] = [(c["creature"] as Creature).get_rid()]  # a live creature's own capsule is on layer 1
	var rd := (c["creature"] as Creature).get_node_or_null("Ragdoll") as Ragdoll
	if rd and rd.corpse:
		ex.append(rd.corpse.get_rid())
	return RagdollSkin.ground_y(get_world_3d().direct_space_state, p, ex, -INF)

## Every gate for one frozen case; prints one line, records failures, returns true when all pass.
func _measure(c: Dictionary) -> bool:
	var cr: Creature = c["creature"]
	var rd := cr.get_node_or_null("Ragdoll") as Ragdoll
	var tag := "%s/%s" % [c["species"], c["terrain"]]
	var bad: Array[String] = []
	if rd == null:
		_fail(tag, ["no Ragdoll node"])
		return false
	var sk := cr.view.rig.skeleton if cr.view.rig else null
	var mi := rd.mesh_instance()
	if rd.phase != &"frozen":
		bad.append("not frozen (%s)" % rd.phase)
	if rd.mode != &"ragdoll":
		bad.append("mode %s (%s)" % [rd.mode, rd.reason])
	if rd.settle_time > SETTLE_MAX_S or rd.settle_time < 0.0:
		bad.append("settle %.2f s" % rd.settle_time)
	var line := "%s mode=%s settle=%.2fs%s peak=%.1fm/s" % [tag, rd.mode, rd.settle_time, "(cap: %s)" % rd.restless if rd.capped else "", rd.peak_speed]
	if rd.peak_speed >= 30.0:
		bad.append("peak %.1f m/s" % rd.peak_speed)
	if sk and mi:
		var ex: Array[RID] = []
		if rd.corpse:
			ex.append(rd.corpse.get_rid())
		var verts := 0
		for si in mi.mesh.get_surface_count():
			verts += mi.mesh.surface_get_array_len(si)
		var pts := RagdollSkin.posed_points(mi, sk, maxi(1, verts / 6000))
		var finite := true
		for p in pts:
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
				finite = false
				break
		var cl := RagdollSkin.clearance(get_world_3d().direct_space_state, pts, ex, 1, 2.0, TOUCH_M)
		var gap := float(cl["min"])
		line += " skin_min=%+.3fm below6cm=%d/%d conform=%+.2fm" % [gap, int(cl["below"]), int(cl["hits"]), rd.conform_m]
		line += " lowest=[%s]" % _lowest_parts(mi, sk, maxi(1, verts / 6000), pts, ex)
		if not finite:
			bad.append("NaN in skin")
		if absf(gap) > TOUCH_M:
			bad.append("lowest skin %+.3f m from ground" % gap)
		if int(cl["below"]) > 0:
			bad.append("%d vertices > 6 cm under ground" % int(cl["below"]))
		var hips := _hips_height(c)
		var stand := float(c.get("stand_hips", 1.0))
		line += " hips=%.2f/%.2fm" % [hips, stand]
		if hips > stand * LIE_FRAC:
			bad.append("hips %.2f > %.0f %% of standing %.2f" % [hips, LIE_FRAC * 100.0, stand])
		var foot := _highest_foot(c, sk, cr)
		line += " foot_max=%.2fm" % foot
		if foot > stand * FOOT_FRAC:
			bad.append("a foot %.2f m up (limb in the air; max %.0f %% of standing hips)" % [foot, FOOT_FRAC * 100.0])
		var up := _belly_up(sk, cr)
		line += " up_y=%+.2f" % up
		if up < -0.35:
			bad.append("legs up (body up axis y %.2f)" % up)
		var stretch := _worst_stretch(sk, rd)
		line += " stretch=%.3f" % stretch
		if stretch > STRETCH_TOL:
			bad.append("bone stretched %.1f %%" % (stretch * 100.0))
		var lim := _worst_limit(sk, rd)
		line += " limit_over=%.1fdeg(%s)" % [lim[0], lim[1]]
		if float(lim[0]) > LIMIT_TOL_DEG:
			bad.append("joint %s %.1f deg past its limit" % [lim[1], lim[0]])
		# Every Skeleton3D carries an inactive internal compat simulator; only active modifiers cost.
		var left := sk.find_children("*", "SkeletonModifier3D", true, false).filter(func(m: Node) -> bool: return (m as SkeletonModifier3D).active) \
			+ cr.find_children("*", "PhysicalBone3D", true, false)
		if not left.is_empty():
			bad.append("physics left on the frozen corpse: %s" % ", ".join(left.map(func(n: Node) -> String: return "%s(%s)" % [n.name, n.get_class()])))
		if cr.anim.tree.active or cr.is_physics_processing():
			bad.append("frozen corpse still animates or ticks physics")
	else:
		bad.append("no skinned mesh")
	if rd.corpse:
		var hips_w := cr.global_position
		var d := Vector2(rd.corpse.global_position.x - hips_w.x, rd.corpse.global_position.z - hips_w.z).length()
		if d > 0.05:
			bad.append("corpse %.2f m from the body root" % d)
		if rd.corpse.loot.used_slots() <= 0:
			bad.append("corpse has no loot")
	else:
		bad.append("no corpse")
	print("[ragdoll_lab] %s %s" % ["ok  " if bad.is_empty() else "FAIL", line])
	if not bad.is_empty():
		_fail(tag, bad)
	return bad.is_empty()

## Which bones carry the lowest skin (per dominant bone, gap to the ground), for profile tuning.
func _lowest_parts(mi: MeshInstance3D, sk: Skeleton3D, stride: int, pts: PackedVector3Array, ex: Array[RID]) -> String:
	var smp := RagdollSkin.sample(mi, stride)
	var w: PackedFloat32Array = smp["weights"]
	var b: PackedInt32Array = smp["bones"]
	var best: Dictionary = {}
	var space := get_world_3d().direct_space_state
	for i in pts.size():
		var top := 0
		for k in 4:
			if w[i * 4 + k] > w[i * 4 + top]:
				top = k
		var bind := b[i * 4 + top]
		var bone := mi.skin.get_bind_bone(bind)
		var bname := sk.get_bone_name(bone) if bone >= 0 else str(mi.skin.get_bind_name(bind))
		var gy := RagdollSkin.ground_y(space, pts[i], ex, -INF)
		var gap := pts[i].y - gy
		if not best.has(bname) or gap < float(best[bname]):
			best[bname] = gap
	var names := best.keys()
	names.sort_custom(func(x, y) -> bool: return float(best[x]) < float(best[y]))
	var out: Array[String] = []
	for n in names.slice(0, 4):
		out.append("%s %+.2f" % [n, float(best[n])])
	return ", ".join(out)

## Height above the ground of the highest of the profile's `feet` bones (a limb left in the air).
func _highest_foot(c: Dictionary, sk: Skeleton3D, cr: Creature) -> float:
	var top := 0.0
	for f in Ragdoll.profile(cr.def.id).get("feet", []):
		var b := sk.find_bone(str(f))
		if b >= 0:
			var p := sk.global_transform * sk.get_bone_global_pose(b).origin
			top = maxf(top, p.y - _ground_at(c, p))
	return top

## World y of the creature's up axis carried by its hips bone: 1 standing, ~0 on a flank, -1 legs up.
func _belly_up(sk: Skeleton3D, cr: Creature) -> float:
	var hb := sk.find_bone(str(Ragdoll.profile(cr.def.id).get("hips", "Hips")))
	if hb < 0:
		return 1.0
	var rot := sk.get_bone_global_pose(hb).basis.orthonormalized() * sk.get_bone_global_rest(hb).basis.orthonormalized().inverse()
	return (sk.global_basis.orthonormalized() * rot * Vector3.UP).normalized().y

## Bones keep their rest length (the ragdoll's root body is the only free one).
func _worst_stretch(sk: Skeleton3D, rd: Ragdoll) -> float:
	var free_bone := -1
	for j in rd.joints:
		if int(j["parent_body"]) < 0:
			free_bone = int(j["bone"])
	var worst := 0.0
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		if p < 0 or i == free_bone:
			continue
		var rest := sk.get_bone_rest(i).origin.length()
		if rest < 0.0005:
			continue
		var now := (sk.get_bone_global_pose(i).origin - sk.get_bone_global_pose(p).origin).length()
		worst = maxf(worst, absf(now - rest) / rest)
	return worst

## Largest overshoot of any simulated joint past its profile limit, measured from rest. Cones are
## checked per axis like the 6DOF joint that builds them: twist about the bone line, bend about the
## profile axis made square to it, side about the third axis.
func _worst_limit(sk: Skeleton3D, rd: Ragdoll) -> Array:
	var worst := 0.0
	var who := "-"
	for j in rd.joints:
		var kind := str(j["joint"])
		if kind == "" or kind == "pin":
			continue
		var cb := int(j["bone"])
		var pb := int(j["parent_bone"])
		var over := 0.0
		var shown := ""
		if kind == "hinge":
			var a := joint_angles(sk, pb, cb, j["axis"] as Vector3, j["axis"] as Vector3)
			over = maxf(maxf(float(j["min"]) - a.x, a.x - float(j["max"])), a.z - LIMIT_TOL_DEG)
			shown = "%.0f off-axis %.0f" % [a.x, a.z]
		else:
			var a := joint_angles(sk, pb, cb, j["dir_skel"] as Vector3, j["axis"] as Vector3)
			over = maxf(absf(a.x) - float(j["twist"]), maxf(float(j["min"]) - a.y, a.y - float(j["max"])))
			over = maxf(over, absf(a.z) - float(j["side"]))
			shown = "twist %.0f bend %.0f side %.0f" % [a.x, a.y, a.z]
		if over > worst:
			worst = over
			who = "%s %s %s" % [sk.get_bone_name(cb), kind, shown]
	return [worst, who]

## Child rotation relative to its parent body's bone, from rest, in degrees, as (twist about
## `line`, bend about `bend_axis` made square to `line`, the remaining side swing). For a hinge
## pass the hinge axis as both: x is then the hinge angle and z the swing off the hinge axis.
static func joint_angles(sk: Skeleton3D, parent: int, child: int, line: Vector3, bend_axis: Vector3) -> Vector3:
	var pr := sk.get_bone_global_rest(parent).basis.orthonormalized()
	var cr := sk.get_bone_global_rest(child).basis.orthonormalized()
	var pn := sk.get_bone_global_pose(parent).basis.orthonormalized()
	var cn := sk.get_bone_global_pose(child).basis.orthonormalized()
	var q := ((pn.transposed() * cn) * (pr.transposed() * cr).transposed()).get_rotation_quaternion()
	var a := (pr.transposed() * line).normalized()
	var tw_dot := Vector3(q.x, q.y, q.z).dot(a)
	var twist := Quaternion(a.x * tw_dot, a.y * tw_dot, a.z * tw_dot, q.w).normalized()
	var swing := q * twist.inverse()
	var tw_angle := wrapf(2.0 * atan2(tw_dot, q.w), -PI, PI)
	var sv := swing.get_axis() * wrapf(swing.get_angle(), -PI, PI) if swing.get_angle() > 1e-5 else Vector3.ZERO
	var b := (pr.transposed() * bend_axis)
	b = (b - a * b.dot(a)).normalized() if (b - a * b.dot(a)).length_squared() > 1e-6 else a.cross(Vector3.UP).normalized()
	if line.is_equal_approx(bend_axis):
		return Vector3(rad_to_deg(tw_angle), 0.0, rad_to_deg(sv.length()))
	return Vector3(rad_to_deg(tw_angle), rad_to_deg(sv.dot(b)), rad_to_deg(sv.dot(a.cross(b))))

func _fail(tag: String, why: Array[String]) -> void:
	for w in why:
		_failures.append("%s: %s" % [tag, w])

func _verdict(summary: String) -> void:
	for f in _failures:
		print("[ragdoll_lab] FAIL %s" % f)
	print("[ragdoll_lab] %s %s" % ["PASS" if _failures.is_empty() else "FAIL", summary])
	get_tree().quit(0 if _failures.is_empty() else 1)

# --- shots ------------------------------------------------------------------------------------

func _frame_corpse(c: Dictionary, elev_deg: float, az_deg: float) -> void:
	var cr: Creature = c["creature"]
	var rd := cr.get_node_or_null("Ragdoll") as Ragdoll
	var box := AABB(cr.global_position, Vector3.ZERO)
	var mi := rd.mesh_instance() if rd else null
	if mi and cr.view.rig and cr.view.rig.skeleton:
		for p in RagdollSkin.posed_points(mi, cr.view.rig.skeleton, 61):
			box = box.expand(p)
	var centre := box.get_center()
	var radius := maxf(0.6, box.size.length() * 0.5)
	var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 0.95
	var e := deg_to_rad(elev_deg)
	var az := deg_to_rad(az_deg)
	var dir := Vector3(sin(az) * cos(e), sin(e), cos(az) * cos(e))
	_cam.look_at_from_position(centre + dir * dist, centre)

func _shoot(c: Dictionary) -> void:
	_frame_corpse(c, 30.0 if c["terrain"] == "slope" else 18.0, 50.0 if c["terrain"] == "slope" else -60.0)
	await _frames(3)
	RenderingServer.force_draw(false)  # an occluded window on a busy desktop may not draw by itself
	var img := get_viewport().get_texture().get_image()
	var rm := RenderingServer.get_current_rendering_method()
	img.save_png("%s/%s_%s_%s.png" % [_shots, c["species"], c["terrain"], rm])
	var t: String = c["terrain"]
	if not _sheets.has(t):
		var sheet := Image.create(1600, 900, false, img.get_format())
		sheet.fill(Color(0.1, 0.1, 0.1))
		_sheets[t] = sheet
	var idx := SPECIES.find(c["species"])
	var tile := img.duplicate() as Image
	tile.resize(400, 225, Image.INTERPOLATE_BILINEAR)
	(_sheets[t] as Image).blit_rect(tile, Rect2i(0, 0, 400, 225), Vector2i((idx % 4) * 400, (idx / 4) * 225 + 112))

func _run_phone() -> void:
	var c := {"species": &"velociraptor", "terrain": "flat"}
	if not _species.is_empty():
		c["species"] = _species[0]
	_setup_case(c, Vector3.ZERO)
	await _frames(30)
	c["stand_hips"] = _hips_height(c)
	(c["creature"] as Creature).health.take_damage(1e6, c["source"])
	while not _all_frozen([c]):
		await get_tree().physics_frame
	var iso := IsoCamera.new()
	add_child(iso)
	var tgt := Node3D.new()
	add_child(tgt)
	tgt.global_position = (c["creature"] as Creature).global_position
	iso.current = true
	iso._target = tgt
	iso._snap()
	_keep_corpse(c)
	await _frames(6)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(_phone)
	print("[ragdoll_lab] phone shot %s" % _phone)
	_measure(c)
	_verdict("phone")

# --- suggestions for profile authors ------------------------------------------------------------

## Per profile body: radial distance of the vertices it carries (dominant weight on its bone or a
## bone that follows it) from its capsule line, at the 50th/80th/95th percentile, and how far skin
## reaches past the capsule's ends. Radii near p80 keep the skin within a few cm of the capsules.
func _run_suggest() -> void:
	for id in _species:
		var host := Node3D.new()
		add_child(host)
		var cr := _spawn(id, host, Vector3.ZERO)
		var prof := Ragdoll.profile(id)
		var sk := cr.view.rig.skeleton if cr.view.rig else null
		var mi := Ragdoll._first_skinned(cr.view.rig.mesh_root) if cr.view.rig else null
		if sk == null or mi == null or prof.is_empty():
			print("[rl-suggest] %s skipped (rig=%s profile=%s)" % [id, sk != null, not prof.is_empty()])
			host.queue_free()
			continue
		cr.anim.tree.active = false
		var rig := RagdollRig.build(sk, prof, Ragdoll.data().get("physics", {}))
		if rig == null:
			print("[rl-suggest] %s profile does not fit the rig" % id)
			host.queue_free()
			continue
		rig.release()
		sk.reset_bone_poses()
		var s := RagdollSkin.sample(mi, 1)
		var pts := RagdollSkin.posed_points(mi, sk, 1)
		var inv := sk.global_transform.affine_inverse()
		var owner_body: Dictionary = {}
		for k in rig.info.size():
			owner_body[int(rig.info[k]["bone"])] = k
		var bind_bone: Array[int] = []
		for b in mi.skin.get_bind_count():
			var bb := mi.skin.get_bind_bone(b)
			bind_bone.append(bb if bb >= 0 else sk.find_bone(mi.skin.get_bind_name(b)))
		var per: Array = []
		for k in rig.info.size():
			per.append([])
		var lo_y := INF
		for i in pts.size():
			var best := 0
			for w in 4:
				if (s["weights"] as PackedFloat32Array)[i * 4 + w] > (s["weights"] as PackedFloat32Array)[i * 4 + best]:
					best = w
			var bone := bind_bone[(s["bones"] as PackedInt32Array)[i * 4 + best]]
			while bone >= 0 and not owner_body.has(bone):
				bone = sk.get_bone_parent(bone)
			if bone >= 0:
				(per[int(owner_body[bone])] as Array).append(inv * pts[i])
			lo_y = minf(lo_y, pts[i].y)
		print("[rl-suggest] %s scale=%.3f bodies=%d verts=%d lowest_rest_vertex_y=%.3f" % [id, rig.scale, rig.info.size(), pts.size(), lo_y])
		for k in rig.info.size():
			var row: Dictionary = rig.info[k]
			var a: Vector3 = row["head_skel"]
			var b2: Vector3 = row["tip_skel"]
			var dists: Array[float] = []
			var past_tip := 0.0
			var before_head := 0.0
			var ab := b2 - a
			for p in per[k]:
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), -1e9, 1e9)
				past_tip = maxf(past_tip, (t - 1.0) * ab.length() * rig.scale)
				before_head = maxf(before_head, -t * ab.length() * rig.scale)
				dists.append((p - (a + ab * clampf(t, 0.0, 1.0))).length() * rig.scale)
			dists.sort()
			var q := func(f: float) -> float: return dists[int(f * (dists.size() - 1))] if not dists.is_empty() else 0.0
			print("[rl-suggest]   %-16s r_now=%.3f len=%.3f p50=%.3f p80=%.3f p95=%.3f past_tip=%.3f before_head=%.3f verts=%d" % [
				sk.get_bone_name(int(row["bone"])), row["radius_m"], row["length_m"], q.call(0.5), q.call(0.8), q.call(0.95), past_tip, before_head, dists.size()])
		host.queue_free()
		await _frames(1)
	get_tree().quit(0)

# --- performance ------------------------------------------------------------------------------

## Four ragdolls at once on the real island: physics frame time while they simulate minus the
## same creatures standing just before, median of PERF_PASSES passes. Run headless with --fixed-fps 60.
## Species without a profile yet are replaced by velociraptor so four bodies always simulate.
func _run_perf() -> void:
	var kit := LabKit.build(self, 20.0)
	var player: Player = kit["player"]
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	await _frames(120)
	var diffs: Array[float] = []
	var frozen_diffs: Array[float] = []
	for pass_i in PERF_PASSES:
		var host := Node3D.new()
		add_child(host)
		var batch: Array[Creature] = []
		for k in PERF_SPECIES.size():
			var ang := TAU * float(k) / float(PERF_SPECIES.size()) + float(pass_i)
			var at := player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * (9.0 + 3.0 * k)
			at.y = World.runtime.surface_y(at.x, at.z) + 0.1 if World.runtime else at.y
			var id: StringName = PERF_SPECIES[k] if not Ragdoll.profile(PERF_SPECIES[k]).is_empty() else &"velociraptor"
			batch.append(_spawn(id, host, at))
		await _frames(150)  # spawn hitches (trees, shaders, nav) are over
		var base := await _physics_ms(60)
		for cr in batch:
			cr.health.take_damage(1e6, player)
		await _frames(int(0.35 * Engine.physics_ticks_per_second))
		var simulating := Ragdoll.active_count()
		var during := await _physics_ms(45)
		var still := Ragdoll.active_count()
		var waited := 0
		while waited < 600 and Ragdoll.active_count() > 0:
			await get_tree().physics_frame
			waited += 1
		var after := await _physics_ms(60)
		diffs.append(during - base)
		frozen_diffs.append(after - base)
		print("[ragdoll_lab] perf pass %d: base=%.3fms simulating(%d->%d)=%.3fms frozen=%.3fms added=%.3fms" % [pass_i, base, simulating, still, during, after, during - base])
		if simulating < PERF_SPECIES.size():
			_failures.append("perf pass %d: only %d ragdolls simulating" % [pass_i, simulating])
		host.queue_free()
		await _frames(30)
	diffs.sort()
	frozen_diffs.sort()
	var med := diffs[diffs.size() / 2]
	var fmed := frozen_diffs[frozen_diffs.size() / 2]
	print("[ragdoll_lab] perf median added=%.3fms (max %.1f) frozen_added=%.3fms" % [med, PERF_MAX_MS, fmed])
	if med > PERF_MAX_MS:
		_failures.append("4 ragdolls add %.3f ms physics (max %.1f)" % [med, PERF_MAX_MS])
	_verdict("perf")

## Median wall time of one frame (ms) over `frames` frames. Run with --fixed-fps 60 headless: every
## frame is then exactly one physics tick and no drawing, so the difference between two windows is
## the physics cost of what changed between them (the ragdolls' step, state syncs, pose write-back
## and their monitor). Performance.TIME_PHYSICS_PROCESS is a per-second MAX, useless for this, and
## means were dominated by stalls of other processes on this shared machine, hence medians.
func _physics_ms(frames: int) -> float:
	var samples: Array[float] = []
	await get_tree().process_frame
	var prev := Time.get_ticks_usec()
	for k in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - prev) / 1000.0)
		prev = now
	samples.sort()
	return samples[samples.size() / 2]
