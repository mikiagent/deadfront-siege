extends SceneTree
## Temporary BUILDSPEED probe (deleted before commit): per-function costs and counts.

var _started := false
var _host: Node3D

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _time(label: String, n: int, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	var acc := 0.0
	for i in n:
		acc += float(f.call(i))
	var dt := float(Time.get_ticks_usec() - t0)
	print("[probe] %s n=%d total_ms=%.0f us_per_call=%.3f acc=%.1f" % [label, n, dt / 1000.0, dt / float(n), acc])

func _run() -> void:
	_host = Node3D.new()
	root.add_child(_host)
	(load("res://scripts/world/world_lighting.gd") as GDScript).install(_host, "temperate")
	var world := root.get_node("World")
	world.call("load_island", _host, &"home_grassland", Vector3(0, 1, 0), false)
	await process_frame
	var rt: IslandRuntime = world.get("runtime")
	await process_frame
	_time("surface_y", 200000, func (i: int) -> float: return rt.surface_y(-180.0 + float(i % 360), -100.0 + float(i % 97)))
	_time("slope_deg", 100000, func (i: int) -> float: return IslandTerrain.slope_deg(rt, -180.0 + float(i % 360), -100.0 + float(i % 97)))
	_time("is_dry", 200000, func (i: int) -> bool: return rt.is_dry(Vector3(-180.0 + float(i % 360), 1.0, -100.0 + float(i % 97))))
	_time("tile_type_at_world", 200000, func (i: int) -> int: return IslandTerrain.tile_type_at_world(rt, -180.0 + float(i % 360), -100.0 + float(i % 97)))
	_time("is_claimed", 200000, func (i: int) -> bool: return IslandClaims.is_claimed(rt, Vector2i(i % 360 - 180, i % 97 - 48)))
	var n := FastNoiseLite.new()
	n.seed = 7
	_time("noise2d", 200000, func (i: int) -> float: return n.get_noise_2d(float(i % 360) * 0.5, float(i % 97) * 0.5))
	_time("biome_at", 100000, func (i: int) -> int: return BiomeZones.biome_at(rt, -180.0 + float(i % 360), -100.0 + float(i % 97)))
	_time("vec2_len", 200000, func (i: int) -> float: return Vector2(float(i % 360), float(i % 97)).length())
	# zone_of cost over every tile centre, as the tile loop does.
	var ctx := BiomeZones.context(rt, "grassland", Vector3(0, 0, 8), 1001)
	var span := rt._tile_span
	var half := rt._size * 0.5
	_time("zone_of", span * span, func (i: int) -> int:
		var x := i % span
		var z := i / span
		return BiomeZones.zone_of(ctx, -half + float(x) + 0.5, -half + float(z) + 0.5, 1.0, 0.1, 100.0))
	_time("get_noise_noargs", 200000, func (i: int) -> float: return float(i))
	quit(0)
