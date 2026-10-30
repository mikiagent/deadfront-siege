extends SceneTree
## 3D-FLAT (full-3D package 2): with rules.json terrain_relief = "flat" every island's land above the beach
## is one plane, the coast still reaches the sea, the dock still lands her on dry ground, and the
## heightmap default is unchanged.
## Run: Godot --headless --path game --script res://tests/t_flatland.gd -> "[t_flatland] PASS", exit 0/1.

const ISLANDS := [&"home_grassland", &"tutorial_isle"]
var failures: Array[String] = []
var FLAT_H: float = 1.0  # IslandShape.FLAT_H (read at run time: the test compiles before autoloads)
var _started := false

func _process(_d: float) -> bool:
	if _started or get_root().get_node_or_null("World") == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_flatland] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	var world = get_root().get_node("World")
	FLAT_H = load("res://scripts/world/island_shape.gd").FLAT_H
	var rules: Dictionary = get_root().get_node("Data").world_rules
	_expect(str(rules.get("terrain_relief", "")) == "heightmap", "the default stays heightmap until the owner flips it")
	var host := Node3D.new()
	get_root().add_child(host)
	for id: StringName in ISLANDS:
		if world.def_of(id).is_empty():
			continue
		for mode in ["heightmap", "flat"]:
			rules["terrain_relief"] = mode
			world.load_island(host, id, Vector3(0, 1, 18), false)
			await process_frame
			var rt = world.runtime
			var sh = rt._shape
			var land := 0
			var off := 0
			var hi := -INF
			for h: float in sh.heights:
				if h >= 0.9:
					land += 1
					hi = maxf(hi, h)
					if h > FLAT_H + 0.01:
						off += 1  # above the plane: relief left over (the 0.9-1.0 band is the beach ramp easing up to it)
			if mode == "flat":
				_expect(land > 100 and off == 0 and is_equal_approx(hi, FLAT_H), "%s flat: no land rises above the plane (%d of %d off, top %.2f)" % [id, off, land, hi])
				var arrive: Vector3 = rt.arrival_point()
				_expect(arrive.y > 0.0, "%s flat: the dock still lands her on dry ground (y %.2f)" % [id, arrive.y])
				var sea := 0
				for h: float in sh.heights:
					if h < -1.0:
						sea += 1
				_expect(sea > 0, "%s flat: the sea is still deep water (%d cells)" % [id, sea])
			else:
				_expect(hi > FLAT_H + 0.5, "%s heightmap: relief is unchanged (top %.2f)" % [id, hi])
	rules["terrain_relief"] = "heightmap"
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_flatland] PASS")
		quit(0)
	else:
		print("[t_flatland] FAIL count=%d" % failures.size())
		quit(1)
