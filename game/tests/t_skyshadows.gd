extends SceneTree
## SKYSHADOWS acceptance: the system spawns with the climate's flyers, its cloud and flyer shadows
## move over time, the quality toggle removes them, night fades them, the sun dips under a cloud,
## and 2 min of simulated sky add no nodes or objects. Prints the per-frame CPU cost.
## Run: Godot --headless --path game --script res://tests/t_skyshadows.gd -> "[t_skyshadows] PASS".

const FRAME := 1.0 / 60.0
const SIM_FRAMES := 7200  # 2 min at 60 fps
## ASSUMPTION: "negligible" CPU is under 50 us a frame (0.3 % of a 16.7 ms frame) on this machine.
const MAX_STEP_US := 50.0

var _fails: PackedStringArray = []
var _started := false

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_skyshadows] FAIL %s" % what)

func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("[t_skyshadows] FAIL watchdog")
		quit(1))
	var SS: GDScript = load("res://scripts/world/sky_shadows.gd")
	var WL: GDScript = load("res://scripts/world/world_lighting.gd")
	_expect(SS.enabled_for(false, PackedStringArray()), "on by default on desktop and native")
	_expect(not SS.enabled_for(true, PackedStringArray()), "off by default on a phone browser")
	_expect(not SS.enabled_for(false, PackedStringArray(["--skyshadows=off"])), "--skyshadows=off")
	_expect(SS.enabled_for(true, PackedStringArray(["--skyshadows=on"])), "--skyshadows=on")
	for climate in ["grassland", "desert", "swamp", "tundra", "volcanic"]:
		var c: Dictionary = SS.config_for(climate)
		_expect(int(c.get("flyers", 0)) >= 1 and int(c.get("flyers", 0)) <= 3, "%s has 1-3 flyers" % climate)
	SS.enabled = true
	var host := Node3D.new()
	root.add_child(host)
	var wl = WL.install(host, "grassland")
	wl.set_process(false)
	root.get_node("Game").time_of_day = 0.5
	wl.drive(0.5)
	var sky = SS.install(host, "grassland", wl)
	sky.set_process(false)  # stepped by hand below, so the clock is exact
	await process_frame
	_expect(sky.is_inside_tree() and sky.is_in_group(&"sky_shadows"), "system spawns under the island")
	sky.step(FRAME)
	var active := 0
	for f in sky.last_flyers:
		if f.w > 0.0:
			active += 1
	_expect(active == int(SS.config_for("grassland")["flyers"]), "grassland shows its %d flyers (got %d)" % [int(SS.config_for("grassland")["flyers"]), active])
	_expect(sky.last_cloud.w > 0.0, "cloud shadows on by day")
	# Cover: the share of tile texels in cloud matches cloud_cover within 5 points.
	var inside := 0
	for y in 64:
		for x in 64:
			if sky.cover_at(Vector2(x, y) * (240.0 / 64.0)) >= 0.5:
				inside += 1
	var share := float(inside) / 4096.0
	_expect(absf(share - float(SS.config_for("grassland")["cloud_cover"])) < 0.05, "cloud share %.2f matches cloud_cover" % share)
	# Moves.
	var f0: Vector4 = sky.last_flyers[0]
	var c0: Vector4 = sky.last_cloud
	for i in 120:
		sky.step(FRAME)
	var f1: Vector4 = sky.last_flyers[0]
	_expect(Vector2(f1.x, f1.y).distance_to(Vector2(f0.x, f0.y)) > 5.0, "flyer shadow glides (%.1f m in 2 s)" % Vector2(f1.x, f1.y).distance_to(Vector2(f0.x, f0.y)))
	_expect(Vector2(sky.last_cloud.x, sky.last_cloud.y).distance_to(Vector2(c0.x, c0.y)) > 2.0, "clouds drift with the wind")
	# A flap folds the wings within one flap period.
	var min_span := 1.0
	for i in int(SS.FLAP_EVERY_S * 60.0):
		sky.step(FRAME)
		min_span = minf(min_span, sky.last_wing.x)
	_expect(min_span < 0.8, "flyer flaps (span %.2f)" % min_span)
	# Sun dip under a cloud: walk the clock until the anchor is covered.
	var dipped := false
	for i in SIM_FRAMES:
		wl.drive(0.5, false)
		var base: float = wl.sun.light_energy
		sky.step(FRAME)
		if sky.cover_here > 0.8:
			dipped = wl.sun.light_energy < base * 0.85 and wl.sun.light_energy > base * 0.6
			break
	_expect(dipped, "the sun dips subtly while a cloud covers the survivor")
	# Night fades everything.
	WL.night = 1.0
	sky.step(FRAME)
	var night_sum: float = sky.last_cloud.w
	for f in sky.last_flyers:
		night_sum += f.w
	_expect(night_sum == 0.0, "night fades every sky shadow")
	WL.night = 0.5
	sky.step(FRAME)
	_expect(sky.last_flyers[0].w > 0.0 and sky.last_flyers[0].w < SS.config_for("grassland")["flyer_strength"], "dusk half-fades")
	WL.night = 0.0
	# Toggle off removes them; on brings them back.
	SS.set_enabled(false, self)
	var off_sum: float = sky.last_cloud.w
	for f in sky.last_flyers:
		off_sum += f.w
	_expect(off_sum == 0.0 and not sky.is_processing() and sky.sun_scale == 1.0, "toggle off removes every shadow and the dip")
	SS.set_enabled(true, self)
	sky.set_process(false)
	_expect(sky.last_cloud.w > 0.0, "toggle on restores them")
	# 2 min of sky: no node or object growth, and the cost of a frame.
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objs0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var t0 := Time.get_ticks_usec()
	for i in SIM_FRAMES:
		sky.step(FRAME)
	var us := float(Time.get_ticks_usec() - t0) / float(SIM_FRAMES)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objs1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_expect(nodes1 == nodes0, "no node growth over 2 min (%d -> %d)" % [nodes0, nodes1])
	_expect(objs1 == objs0, "no object growth over 2 min (%d -> %d)" % [objs0, objs1])
	print("[t_skyshadows] cpu %.1f us/frame over %d frames (nodes %d, objects %d)" % [us, SIM_FRAMES, nodes1, objs1])
	_expect(us < MAX_STEP_US, "cpu %.1f us/frame under %.0f" % [us, MAX_STEP_US])
	host.queue_free()
	await process_frame
	if _fails.is_empty():
		print("[t_skyshadows] PASS")
		quit(0)
	else:
		quit(1)
