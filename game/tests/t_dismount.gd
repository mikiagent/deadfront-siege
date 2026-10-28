extends SceneTree
## DISMOUNT (owner 2026-10-28: "dismounting some animals (like Trex) causes you to fall through the map").
## For every mount-role species (T. rex first): summon, mount, ride ~0.6 s, dismount, then for 3 s check
## the survivor stands on the ground: feet within 0.3 m of the ground under her, on_floor, not falling,
## not inside a collider, no collision exception left with the mount. Spots: flat heightmap, a 22 deg
## heightmap slope, and beside a rock wall on the mount's right. Then the T. rex 20 times in a row.
## The floor is a HeightMapShape3D like island_terrain.gd (one-sided: a body whose centre gets under it
## falls forever). Run: Godot --headless --path game --script res://tests/t_dismount.gd -> "[t_dismount] PASS".

const RES := 129
var failures: Array[String] = []
var data: Node
var host: Node3D
var player
var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		print("[t_dismount] FAIL " + what)
		failures.append(what)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

## Flat at 0 for x < 10, then rising 0.4 m per m (about 22 deg).
static func _h(x: float) -> float:
	return maxf(0.0, x - 10.0) * 0.4

func _ground_y(at: Vector3, exclude: Array[RID]) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0)
	q.exclude = exclude
	var hit := host.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if hit else -INF

func _overlaps() -> Array:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.9
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), player.global_position + Vector3.UP * 0.06)
	q.exclude = [player.get_rid()]
	var out := []
	for h in host.get_world_3d().direct_space_state.intersect_shape(q, 4):
		out.append(str(h["collider"].name))
	return out

func _run() -> void:
	host = Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = RES
	hs.map_depth = RES
	var heights := PackedFloat32Array()
	heights.resize(RES * RES)
	for z in RES:
		for x in RES:
			heights[x + z * RES] = _h(float(x - RES / 2))
	hs.map_data = heights
	cs.shape = hs
	floor.add_child(cs)
	host.add_child(floor)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 40, 0)
	cam.rotation = Vector3(-PI * 0.5 + 0.01, 0, 0)  # looks down, so move_up rides -Z
	cam.current = true
	player = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector3(-40, 1.2, -40)
	host.add_child(player)
	await _frames(20)
	var ids: Array = []
	for key in data.creatures.keys():
		if &"mount" in data.creatures[key].tamed_role:
			ids.append(key)
	ids.sort()
	ids.erase(&"tyrannosaurus")
	ids.push_front(&"tyrannosaurus")
	var PR = load("res://scripts/pets/pet_record.gd")
	for id in ids:
		player.bonded.clear()
		player.bonded.append(PR.from_def(data.creature(id), &"A"))
		player.bonded[-1].fit_saddle()  # SADDLES: riding needs one
		for spot in [&"flat", &"slope", &"rock"]:
			await _case(id, spot)
	# 20 in a row on the rex.
	player.bonded.clear()
	player.bonded.append(PR.from_def(data.creature(&"tyrannosaurus"), &"A"))
	player.bonded[-1].fit_saddle()  # SADDLES: riding needs one
	var m = await _summon_at(Vector3(-20, 0, 20))
	for i in 20:
		player.pets.mount(m)
		await _frames(3)
		player.pets.dismount()
		await _frames(30)
		_check_standing("tyrannosaurus repeat %d" % i, m)
	await _frames(120)
	_check_standing("tyrannosaurus after 20 in a row", m)
	player.pets.dismiss(m)
	if failures.is_empty():
		print("[t_dismount] PASS (%d species)" % ids.size())
		quit(0)
	else:
		print("[t_dismount] FAIL %d checks" % failures.size())
		quit(1)

func _summon_at(at: Vector3):
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(at.x - 4.0, _h(at.x - 4.0) + 1.1, at.z + 4.0)
	await _frames(5)
	var m = player.pets.summon(0)
	m.brain.process_mode = Node.PROCESS_MODE_DISABLED
	m.velocity = Vector3.ZERO
	m.global_position = Vector3(at.x, _h(at.x), at.z)
	m.rotation = Vector3.ZERO
	await _frames(10)
	return m

func _case(id: StringName, spot: StringName) -> void:
	var at: Vector3 = {&"flat": Vector3(-30, 0, 30), &"slope": Vector3(28, 0, 20), &"rock": Vector3(-10, 0, 30)}[spot]
	var rock: StaticBody3D = null
	var m = await _summon_at(at)
	if spot == &"rock":
		# A wall right beside the mount's +X flank (where a fixed world-+X dismount lands) and in front of
		# its nose, so the first-choice spots are blocked and the fallback has to find a free side.
		rock = StaticBody3D.new()
		rock.name = "Rock"
		var rs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4, 4, 30)
		rs.shape = box
		rock.add_child(rs)
		host.add_child(rock)
		rock.global_position = Vector3(m.global_position.x + m.body_radius() + 0.25 + 2.0, 2.0, at.z - 6.0)
	player.pets.mount(m)
	await _frames(5)
	_expect(player.mounted_on == m, "%s %s: mounted" % [id, spot])
	Input.action_press("move_up")
	await _frames(36)
	Input.action_release("move_up")
	await _frames(10)
	var before: Vector3 = m.global_position
	player.pets.dismount()
	await _frames(2)
	var worst := 0.0
	var fell := false
	for i in 180:
		await physics_frame
		var g := _ground_y(player.global_position, [player.get_rid(), m.get_rid()])
		var off: float = player.feet_position().y - g
		worst = maxf(worst, absf(off))
		if player.global_position.y < before.y - 3.0 or g == -INF:
			fell = true
	var g2 := _ground_y(player.global_position, [player.get_rid(), m.get_rid()])
	print("[t_dismount] %s %s: mount at %s, rider at %s, feet-ground %.2f (worst %.2f), on_floor=%s vy=%.2f" % [
		id, spot, before, player.global_position, player.feet_position().y - g2, worst, player.is_on_floor(), player.velocity.y])
	_expect(not fell, "%s %s: fell through (y %.2f, mount %.2f)" % [id, spot, player.global_position.y, before.y])
	_expect(worst < 0.35, "%s %s: feet %.2f m off the ground at worst" % [id, spot, worst])
	_check_standing("%s %s" % [id, spot], m)
	_expect(player.feet_position().y < before.y + 2.0, "%s %s: landed on top of something (feet %.2f, mount %.2f)" % [
		id, spot, player.feet_position().y, before.y])
	player.pets.dismiss(m)
	if rock:
		rock.free()
	await _frames(5)

func _check_standing(what: String, m) -> void:
	var g := _ground_y(player.global_position, [player.get_rid(), m.get_rid()])
	var off: float = player.feet_position().y - g
	_expect(absf(off) < 0.3, "%s: feet %.2f m from the ground" % [what, off])
	_expect(player.is_on_floor(), "%s: not on the floor" % what)
	_expect(player.velocity.y > -1.0, "%s: falling (vy %.2f)" % [what, player.velocity.y])
	_expect(player.mounted_on == null and player.get_parent() == host, "%s: still attached" % what)
	_expect(player.get_collision_exceptions().is_empty(), "%s: collision exception left" % what)
	var ov := _overlaps()
	_expect(ov.is_empty(), "%s: inside %s" % [what, ov])
