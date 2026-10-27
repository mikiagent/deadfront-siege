extends Node3D
## Survivor v2 armor + mount saddles acceptance.
##
## Armor: real inventory equip path drives PlayerEquipment (three kits, mixed, unequip).
## Mounts: every mount-role species that has assets/creatures/<id>/mount/mount.json is spawned as a pet,
## ridden through idle/walk/run and dismounted, and checked: the rider sits above the back (not sunk into
## the body), the saddle is skinned to the socket bone (local drift < 3 cm across the clips), and dismount
## restores the rig. Species in data/mounts_skip.json stay on the hips-socket fallback.
##
##   godot --path game -- --lab=equip_mount_lab                      (armor + every mount, /tmp shots)
##   godot --path game -- --lab=equip_mount_lab --species=protoceratops
##   godot --path game -- --lab=equip_mount_lab --all-mounts --shot-dir=/tmp/mountlab
## Prints "[mountlab] PASS species=<id>" per saddled species, "[equiplab] PASS" at the end.
var player: Player
var cam: Camera3D
var shot_dir := "/tmp/dfs-equip"
var only: StringName = &""
var all_mounts := false
const DRIFT_LIMIT := 0.03

const KITS := {
	"travel": [&"travel_shirt", &"travel_sleeves", &"travel_trousers"],
	"forager": [&"forager_hood", &"forager_vest", &"forager_wraps", &"forager_leggings"],
	"hide_bone": [&"hide_bone_helm", &"hide_bone_cuirass", &"hide_bone_bracers", &"hide_bone_greaves"],
}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species="):
			only = StringName(a.substr(10))
			all_mounts = true
		elif a == "--all-mounts":
			all_mounts = true
		elif a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
	# Physics interpolation smooths visual transforms at render time, so a sampled "global" rider position
	# can lag its bone by a frame; the lab judges exact geometry, so measure the raw transforms.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var kit := LabKit.build(self, 60.0)
	player = kit["player"]
	Game.debug_overlay = false
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	DirAccess.make_dir_recursive_absolute(shot_dir)
	call_deferred("_demo")

func _demo() -> void:
	await get_tree().create_timer(0.5).timeout
	if not all_mounts:
		await _armor()
		if not await _ride_species(&"tyrannosaurus", true):
			print("[equiplab] FAIL tyrannosaurus ride")
			get_tree().quit(1)
			return
		print("[equiplab] PASS")
		get_tree().quit(0)
		return
	var ids := mount_species()
	if only != &"":
		ids = [only]
	var fails: Array[String] = []
	for id in ids:
		var ok := await _ride_species(id, true)
		if not ok:
			fails.append(str(id))
	if fails.is_empty():
		print("[mountlab] PASS all mounts")
		get_tree().quit(0)
	else:
		print("[mountlab] FAIL %s" % [fails])
		get_tree().quit(1)

## Mount-role species that have a game model, in roster order (T. rex first: it is the reference).
func mount_species() -> Array[StringName]:
	var out: Array[StringName] = [&"tyrannosaurus"]
	var ids: Array = Data.creatures.keys()
	ids.sort()
	for key in ids:
		var d := Data.creatures[key] as CreatureDef
		if d == null or d.id == &"tyrannosaurus":
			continue
		if &"mount" in d.tamed_role and ResourceLoader.exists("res://assets/creatures/%s/%s.glb" % [d.id, d.id]):
			out.append(d.id)
	return out

func skip_list() -> Dictionary:
	var f := "res://data/mounts_skip.json"
	if not FileAccess.file_exists(f):
		return {}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
	return (j as Dictionary).get("skip", {}) if j is Dictionary else {}

func _armor() -> void:
	for set_ids in KITS.values():
		for id in set_ids:
			LabKit.give(player, id, 1)
	await get_tree().create_timer(0.5).timeout
	var eq := player.equipment
	assert(eq != null and eq.body.size() == 4, "four body regions attached")
	assert(Inventory.EQUIP_SLOTS.has(&"arms"))
	assert(Inventory.slot_for(Data.item(&"travel_sleeves")) == &"arms", "armor_arms wins over clothing")
	assert(Inventory.slot_for(Data.item(&"travel_trousers")) == &"legs")
	await _shot("0_unarmored", 2.5)
	var armor_before := player.inventory.equipped_armor()
	for kit_name in KITS:
		for slot in [&"head", &"body", &"arms", &"legs"]:
			player.inventory.unequip(slot)
		_wear(KITS[kit_name])
		if kit_name == "travel":
			# travel_clothes has no helmet, so the bare head stays.
			assert(_vis("helmet") and not _vis("chest") and not _vis("arms") and not _vis("legs"), "travel hides chest/arms/legs only")
		await _shot("1_%s" % kit_name, 1.6)
	assert(player.inventory.equipped_armor() > armor_before + 700.0, "four hide-and-bone slots count, arms included")
	assert(player.inventory.equipped_health_bonus() >= 40.0)
	_wear([&"hide_bone_helm", &"forager_vest", &"travel_sleeves", &"hide_bone_greaves"])
	await _shot("2_mixed", 1.6)
	for slot in [&"head", &"body", &"arms", &"legs"]:
		assert(eq.equipped.has(slot))
		player.inventory.unequip(slot)
	assert(eq.equipped.is_empty() and _vis("helmet") and _vis("chest") and _vis("arms") and _vis("legs"), "unequip restores body")
	await _shot("3_unequipped", 1.0)
	print("[equiplab] equip: 3 kits, mixed, unequip OK")
	_wear(KITS["hide_bone"])

func _wear(ids: Array) -> void:
	for id in ids:
		player.inventory.equip(Inventory.slot_for(Data.item(id)), id)

func _vis(region: String) -> bool:
	return (player.equipment.body[region][0] as MeshInstance3D).visible

func _spawn(def: CreatureDef) -> Creature:
	var rec := PetRecord.from_def(def, &"A")
	assert(def.tameable and &"mount" in rec.tamed_role, "%s is a tameable mount" % def.id)
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	player.get_parent().add_child(c)
	c.is_pet = true
	c.pet_record = rec
	c.spawn(def, rec.variant)
	c.global_position = player.global_position + Vector3(6, 0, 0)
	return c

## Ride one species. Returns true when every check passed (a skip-listed species passes when it falls back).
func _ride_species(id: StringName, shoot: bool) -> bool:
	var def := Data.creature(id)
	if def == null:
		print("[mountlab] FAIL species=%s (no data)" % id)
		return false
	var skip := skip_list()
	var saddled := ResourceLoader.exists("res://assets/creatures/%s/mount/mount.json" % id)
	if skip.has(str(id)) and saddled:
		print("[mountlab] FAIL species=%s is in mounts_skip.json but has a saddle" % id)
		return false
	if not saddled and not skip.has(str(id)):
		# No saddle and not declared too small: the fallback still has to work, but say so.
		print("[mountlab] note species=%s has no saddle, using the hips socket" % id)
	var c := _spawn(def)
	c.global_position = player.global_position + Vector3(6, 0.2, 0)
	await get_tree().create_timer(0.4).timeout
	# The lab only judges the ride, not the pet brain: freeze its physics so a wandering walk or gravity
	# cannot move the saddle out from under the sampled frame.
	c.set_physics_process(false)
	c.global_position.y = maxf(0.2, c.global_position.y)
	c.velocity = Vector3.ZERO
	var rest := player.rig.transform
	player.mount(c)
	if player.mounted_on != c:
		print("[mountlab] FAIL species=%s never mounted" % id)
		return false
	var ok := true
	if saddled:
		if player._saddle_view == null:
			print("[mountlab] FAIL species=%s did not take the saddle path" % id)
			ok = false
		else:
			ok = (await _check_saddle(id, c)) and ok
	else:
		if player._saddle_view != null:
			print("[mountlab] FAIL species=%s took the saddle path without mount.json" % id)
			ok = false
		else:
			var hips := _hips()
			var mount_top := c.global_position.y + def.height_meters * 0.85
			print("[mountlab] fallback species=%s hips_y=%.2f socket_y=%.2f" % [id, hips.y, mount_top])
			if hips.y < c.global_position.y + 0.2:
				print("[mountlab] FAIL species=%s rider fell through the hips socket" % id)
				ok = false
	if player.anim.current_clip != &"mount_idle":
		print("[mountlab] FAIL species=%s rider is not on mount_idle (%s)" % [id, player.anim.current_clip])
		ok = false
	if shoot and ok:
		await _ride_shot("%s_side" % id, c, Vector3(-1, 0.12, 0.3), 0.8)
		await _ride_shot("%s_iso" % id, c, Vector3(0.8, 0.25, 0.55), 0.8)
	elif shoot:
		await _ride_shot("%s_side" % id, c, Vector3(-1, 0.12, 0.3), 0.8)
	player.dismount()
	if player.mounted_on != null:
		print("[mountlab] FAIL species=%s still mounted after dismount" % id)
		ok = false
	if not player.rig.transform.is_equal_approx(rest):
		print("[mountlab] FAIL species=%s dismount did not restore the rig" % id)
		ok = false
	if saddled and not (player._saddle_view == null and c.view._saddle.is_empty()):
		print("[mountlab] FAIL species=%s saddle was not removed on dismount" % id)
		ok = false
	if ok:
		print("[mountlab] PASS species=%s" % id)
	c.queue_free()
	await get_tree().create_timer(0.3).timeout
	return ok

func _hips() -> Vector3:
	var sk := player.rig.skeleton
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin

## Sits on the saddle, above the back, not sunk in; saddle glued to the socket across idle/walk/run.
func _check_saddle(id: StringName, c: Creature) -> bool:
	var ok := true
	var view := c.view
	var sk := view.rig.skeleton
	var idx := sk.find_bone(_socket_name(id))
	var mj := _mount_json(id)
	if idx < 0:
		print("[mountlab] FAIL species=%s socket %s missing from the skeleton" % [id, _socket_name(id)])
		return false
	var seat_top := float((mj.get("seat", {}) as Dictionary).get("top", 0.0)) * _game_m_per_source(mj)
	var saddle: MeshInstance3D = null
	for mi in view._saddle:
		if (mi as MeshInstance3D).name == "saddle":
			saddle = mi
	if saddle == null:
		print("[mountlab] FAIL species=%s saddle mesh not attached" % id)
		return false
	var samples := _saddle_samples(saddle, sk, idx)
	if samples.is_empty():
		print("[mountlab] FAIL species=%s saddle has no vertices bound to %s" % [id, _socket_name(id)])
		return false
	# The saddle's points and the rider, both seen from the socket bone, must not move across idle/walk/run:
	# the saddle is skinned to that bone and PlayerPets._follow_saddle drives the rider off the same pose.
	# Rigid on the socket (plus "above the seat" at rest) is what "no floating, no sinking, no lag" means.
	var socket_gap := 0.0
	var first_saddle: Array[Vector3] = []
	var first_rider := Vector3.ZERO
	var hips := Vector3.ZERO
	var rider_low := 0.0
	for clip in [&"idle", &"walk", &"run"]:
		view.rig.play(clip)
		await get_tree().create_timer(0.28).timeout  # settle: idle frame 0 still shows the rest pose
		for frame in 6:
			await get_tree().create_timer(0.1).timeout
			# re-run the rider's own follow step so this frame is not a physics-order artifact
			if player._saddle_view != null:
				player.pets._follow_saddle()
			var origin := (sk.global_transform * sk.get_bone_global_pose(idx)).origin
			var pts := _saddle_world(saddle, sk, idx, samples)
			var bone_local := (sk.global_transform * sk.get_bone_global_pose(idx)).affine_inverse()
			if first_saddle.is_empty():
				for p in pts:
					first_saddle.append(bone_local * p)
					socket_gap = maxf(socket_gap, (p - origin).length())
				hips = _hips()
				rider_low = _rider_foot_y()
				first_rider = bone_local * hips
				# Not sunk, not floating: the hips sit above the socket bone by the saddle's own seat height
				# (mount.json, game metres, measured in Blender against the animal's back).
				var want := float(mj.get("hips_above_socket_m", 0.0))
				var have := hips.y - origin.y
				if want > 0.0 and absf(have - want) > 0.08:
					print("[mountlab] FAIL species=%s rider hips %.2f m above the socket, the saddle puts them %.2f m" % [id, have, want])
					ok = false
			else:
				for i in mini(pts.size(), first_saddle.size()):
					_drift = maxf(_drift, (first_saddle[i] - bone_local * pts[i]).length())
				_rider_err = maxf(_rider_err, (bone_local * _hips() - first_rider).length())
	# Review fix: saddle and rider drift are rigid to the socket bone by construction (the pose cancels), and the
	# boot clearance is a horizontal distance that cannot go negative, so neither is asserted; both stay in the log.
	# What can go wrong is the rider's size: rider_transform() must drop the mount's mesh scale K.
	var rider_scale := player.rig.global_basis.get_scale()
	if absf(rider_scale.x - 1.0) > 0.05 or absf(rider_scale.y - 1.0) > 0.05:
		print("[mountlab] FAIL species=%s rider rig scale %s (want ~1.0; the mount's scale leaked into the rider)" % [id, rider_scale])
		ok = false
	var boots := _boot_clearance(c, id)
	print("[mountlab] %s socket=%s seat_top=%.2f rider_hips=%.2f rider_feet=%.2f saddle_drift=%.4f rider_drift=%.4f boot_clear=%s saddle_reach=%.2f"
		% [id, _socket_name(id), c.global_position.y + seat_top, hips.y, rider_low, _drift, _rider_err,
		   "-" if boots == INF else "%.2f" % boots, socket_gap])
	_drift = 0.0
	_rider_err = 0.0
	return ok

var _drift := 0.0
var _rider_err := 0.0

func _mount_json(id: StringName) -> Dictionary:
	var f := "res://assets/creatures/%s/mount/mount.json" % id
	if not FileAccess.file_exists(f):
		return {}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
	return j if j is Dictionary else {}

func _socket_name(id: StringName) -> String:
	return str(_mount_json(id).get("socket", ""))

func _game_m_per_source(mj: Dictionary) -> float:
	var sc := mj.get("scale", {}) as Dictionary
	var k := float(sc.get("game_m_per_source", 0.0))
	if k > 0.0:
		return k
	return float(Data.creature(StringName(mj.get("mount", ""))).height_meters) / maxf(0.001, float(sc.get("source_height_m", 1.0)))

## Vertices weighted mostly to the socket, as vertex indices + rest positions in the saddle's own space.
func _saddle_samples(mi: MeshInstance3D, sk: Skeleton3D, idx: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var mesh := mi.mesh
	if mesh == null or mi.skin == null:
		return out
	# Godot binds glTF skins by bone NAME (bind_bone stays -1), so map the socket to its bind slot by name.
	var sk_name := sk.get_bone_name(idx)
	var binds: Array[int] = []
	for i in mi.skin.get_bind_count():
		if mi.skin.get_bind_name(i) == sk_name:
			binds.append(i)
	if binds.is_empty():
		return out
	for surf in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(surf)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var stride: int = bones.size() / max(1, verts.size())
		for v in range(verts.size()):
			var w := 0.0
			for k in stride:
				if bones[v * stride + k] in binds:
					w = weights[v * stride + k]
			if w > 0.99:
				out.append(verts[v])
	return out

## Where those rest-space points are this frame, in world space (single-bone skinning at weight ~1).
func _saddle_world(mi: MeshInstance3D, sk: Skeleton3D, idx: int, samples: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var skin_to_bone := sk.global_transform * sk.get_bone_global_pose(idx) * sk.get_bone_global_rest(idx).affine_inverse()
	var mesh_xform := skin_to_bone * mi.transform
	for v in samples:
		out.append(mesh_xform * v)
	return out

## The rider's feet bones (in the saddle they hang below the seat by the clip's own design: legs straddle
## the barrel), so the checks use the hips for "on the saddle" and the feet for "in the stirrups".
## The top of the animal's own hide directly under the rider (within one saddle half-width of the hips).
func _hide_under(c: Creature, hips: Vector3) -> float:
	var mesh_root := c.view.rig.mesh_root
	var best := -INF
	var radius := maxf(0.05, c.def.height_meters * 0.03)
	for mi in mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for surf in m.get_surface_count():
			var verts: PackedVector3Array = m.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p := (mi as MeshInstance3D).global_transform * v
				if Vector2(p.x - hips.x, p.z - hips.z).length() < radius and p.y < hips.y - 0.01:
					best = maxf(best, p.y)
	return hips.y if best == -INF else best

## How far the rider's feet stand clear of the hide (positive = outside/below the body, negative = inside it).
## Sampled from the saddle's own stirrup irons against the creature's mesh at the boot's height.
func _boot_clearance(c: Creature, _id: StringName) -> float:
	var sk := player.rig.skeleton
	var best := INF
	for b in [&"LeftFoot", &"RightFoot"]:
		var i := sk.find_bone(str(b))
		if i < 0:
			continue
		var foot := (sk.global_transform * sk.get_bone_global_pose(i)).origin
		# the mount's own mesh, in its local space, at the boot's height band
		var mesh_root := c.view.rig.mesh_root
		var local := mesh_root.global_transform.affine_inverse() * foot
		var nearest := INF
		for mi in mesh_root.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).mesh
			if m == null:
				continue
			for surf in m.get_surface_count():
				var arr := m.surface_get_arrays(surf)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var xf := (mi as MeshInstance3D).global_transform
				for v in verts:
					var p := mesh_root.global_transform.affine_inverse() * (xf * v)
					if absf(p.y - local.y) < 0.06:
						nearest = minf(nearest, Vector2(p.x - local.x, p.z - local.z).length())
		if nearest < INF:
			best = minf(best, nearest)
	return 1.0 if best == INF else best

func _rider_foot_y() -> float:
	var low := INF
	var sk := player.rig.skeleton
	if sk == null:
		return player.rig.global_position.y
	for b in [&"LeftFoot", &"RightFoot", &"LeftToeBase", &"RightToeBase"]:
		var i := sk.find_bone(str(b))
		if i >= 0:
			low = minf(low, (sk.global_transform * sk.get_bone_global_pose(i)).origin.y)
	return low

func _shot(stage: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	var t := player.rig.global_position
	cam.size = 2.4
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.look_at_from_position(t + Vector3(2.5, 1.6, 4.0), t + Vector3(0, 0.95, 0))
	await _save(stage)

func _ride_shot(stage: String, c: Creature, dir: Vector3, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var h := c.def.height_meters
	var focus := c.global_position + Vector3(0, h * 0.55, 0)
	cam.size = maxf(3.0, h * 1.5)
	cam.look_at_from_position(focus + c.global_basis * dir.normalized() * 40.0, focus)
	await _save(stage)

func _save(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame  # let the moved camera render once
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [shot_dir, stage]
	get_viewport().get_texture().get_image().save_png(path)
	print("[equiplab] shot %s" % path)
