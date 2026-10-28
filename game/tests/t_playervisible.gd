extends SceneTree
## INVIS (owner: "player model has disappeared", night, exhausted, standing in the river). The cause
## was a stale .godot class cache: a merge added class_name scripts, the run had no import, data.gd
## failed to compile and the survivor rig never loaded. ClassCacheGuard finds such classes (and
## ShellLoader re-imports on them); this test checks it finds none here and catches a missing one.
## Then on the home island, on dry land, ankle-deep in the river, wading its deepest spot and in deep
## sea, at noon and at night, at fatigue 0 / 50 / 75 %: the survivor's mesh is loaded and visible,
## her head is in the camera's view and above the water, she never swims where she can stand, and
## she swims (head and shoulders out) in deep water.
## Usage: godot --headless --path game --script res://tests/t_playervisible.gd

const WATER_Y := -0.05 ## HarbourSite.WATER_Y
const TILE_MUD := 6    ## IslandTerrain.TileType.MUD
const HEAD_CLEAR_M := 0.3 ## her head bone at least this far above the water plane

var failures: Array[String] = []
var _started := false
var rt
var player
var cam: Camera3D

func _process(_delta: float) -> bool:
	if _started or get_root().get_node_or_null("World") == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_playervisible] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	var guard: GDScript = load("res://scripts/core/class_cache_guard.gd")
	var missing: PackedStringArray = guard.missing_classes()
	_expect(missing.is_empty(), "the class cache knows every class_name (missing %s)" % [missing])
	var stale: PackedStringArray = guard.missing_classes(["res://scripts/world"], {"IslandTerrain": true})
	_expect("FireWeather" in stale and "LightningBolt" in stale and not "IslandTerrain" in stale,
		"a cache without FireWeather / LightningBolt is caught (%d missing)" % stale.size())
	var host := Node3D.new()
	get_root().add_child(host)
	var world := get_root().get_node("World")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	rt = world.runtime
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	cam = (load("res://scripts/camera/iso_camera.gd") as GDScript).new()
	host.add_child(cam)
	cam.current = true
	cam.set("_target", player)
	player.global_position = rt._camp_pos + Vector3(0, 1, 0)
	await _frames(5)
	_expect(player.rig != null and player.rig.skeleton != null, "the survivor rig loaded")
	if player.rig == null or player.rig.skeleton == null:
		_finish()
		return
	var spots := _spots()
	_expect(spots.size() == 4, "found dry, river, wading and deep spots %s" % [spots])
	var game := get_root().get_node("Game")
	for tod in [0.5, 0.2]:
		game.time_of_day = tod
		for fat in [0.0, 0.5, 0.75]:
			for s in spots:
				player.vitals.fatigue = fat * player.vitals.effective_max_fatigue()
				await _check("%s %s fatigue %d%%" % [s, "noon" if tod == 0.5 else "night", int(fat * 100)], spots[s], s == "deep")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[t_playervisible] PASS")
		quit(0)
	else:
		print("[t_playervisible] FAIL count=%d" % failures.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

## Dry camp ground, river 0.1-0.3 m deep, the river's deepest point, deep sea on +x.
func _spots() -> Dictionary:
	var out := {"dry": rt._camp_pos}
	var deepest := 0.0
	var half: float = rt._size * 0.5 - 2.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var h: float = rt.surface_y(x, z)
			if int(load("res://scripts/world/island_terrain.gd").tile_type_at_world(rt, x, z)) == TILE_MUD and h < WATER_Y:
				var d := WATER_Y - h
				if not out.has("river") and d > 0.1 and d < 0.3:
					out["river"] = Vector3(x, h, z)
				if d > deepest:
					deepest = d
					out["wading"] = Vector3(x, h, z)
			z += 1.0
		x += 1.0
	x = 0.0
	while rt.surface_y(x, 0.0) > WATER_Y - 2.0 and x < rt._size * 0.5:
		x += 0.5
	if rt.surface_y(x, 0.0) <= WATER_Y - 2.0:
		out["deep"] = Vector3(x, 0.0, 0.0)
	return out

func _check(tag: String, at: Vector3, deep: bool) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(at.x, rt.surface_y(at.x, at.z) + player.half_height() + 0.3, at.z)
	await _frames(40)
	cam.call("_snap")
	var rig = player.rig
	var sk: Skeleton3D = rig.skeleton
	var head := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin
	var shown := 0
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and m.is_visible_in_tree() and m.transparency < 0.5:
			shown += 1
	var why := "clip %s, head y %.2f, rig y %.2f" % [player.anim.current_clip, head.y, rig.global_position.y]
	_expect(shown > 0 and rig.is_visible_in_tree(), "%s: her body mesh is visible (%d parts)" % [tag, shown])
	_expect(cam.is_position_in_frustum(head), "%s: her head is in the camera's view (%s)" % [tag, why])
	_expect(head.y > WATER_Y + HEAD_CLEAR_M, "%s: her head is above the water (%s)" % [tag, why])
	_expect(player.swimming == deep, "%s: %s (%s)" % [tag, "swimming in deep water" if deep else "standing, not swimming", why])
