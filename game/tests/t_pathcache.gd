extends SceneTree
## PERF2 route cache (TilePath): a replan toward the same far goal on an unchanged grid reuses the
## last long route instead of running A* over the whole distance again.
##   - the first far path misses, a replan from a tile further down the same route hits;
##   - the reused route still reaches the goal and its prefix ends about as near the goal as a fresh
##     A* prefix does (the tail of an optimal route is optimal; only the join is new);
##   - another goal, a changed grid (version bump) and a short route all re-run A*;
##   - the cached replan is cheaper than the fresh one (printed; asserted loosely).
## Run: Godot --headless --path game --script res://tests/t_pathcache.gd -> "[t_pathcache] PASS", 0/1.

var _fails: PackedStringArray = []
var _started := false

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_pathcache] FAIL %s" % what)

func _run() -> void:
	var W = root.get_node("World")
	var host := Node3D.new()
	root.add_child(host)
	W.load_island(host, &"home_grassland", Vector3(0, 1, 0), false)
	await process_frame
	var rt = W.runtime
	var tp = rt.pathing
	var start: Vector3 = rt.arrival_point()
	# The farthest reachable dry point we can find from the dock, at least 120 m away.
	var goal := Vector3.ZERO
	var best := 0.0
	for k in 48:
		var a := TAU * float(k) / 48.0
		for r in [180.0, 150.0, 120.0]:
			var p := start + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if not rt.is_dry(p):
				continue
			p.y = rt.surface_y(p.x, p.z)
			var probe: PackedVector3Array = tp.path(start, p, 0)
			if tp.last_reachable and probe.size() > 0 and r > best:
				best = r
				goal = p
			break
	_expect(best >= 120.0, "a reachable goal 120 m+ from the dock (%.0f m)" % best)
	if best < 120.0:
		_finish()
		return
	tp._grid_version += 1  # forget the probes' routes
	var hits0: int = tp.route_cache_hits
	var t0 := Time.get_ticks_usec()
	var first: PackedVector3Array = tp.path(start, goal)
	var fresh_us := Time.get_ticks_usec() - t0
	_expect(tp.route_cache_hits == hits0 and tp.last_reachable, "the first far path runs A* and reaches the goal")
	_expect(tp._route.size() >= tp.ROUTE_CACHE_MIN, "a far route is cached (%d tiles)" % tp._route.size())
	# Walk 30 tiles down the raw route (plus a tile off it, as a walker cutting a corner would be).
	var on: Vector2i = tp._route[mini(30, tp._route.size() - 1)]
	var mid := Vector3(float(on.x) + 1.5, 0.0, float(on.y) + 0.5)
	mid.y = rt.surface_y(mid.x, mid.z)
	t0 = Time.get_ticks_usec()
	var again: PackedVector3Array = tp.path(mid, goal)
	var cached_us := Time.get_ticks_usec() - t0
	_expect(tp.route_cache_hits == hits0 + 1, "a replan to the same goal reuses the route")
	_expect(tp.last_reachable and again.size() > 0, "the reused route still reaches the goal")
	var end_cached := Vector2(again[again.size() - 1].x - goal.x, again[again.size() - 1].z - goal.z).length()
	tp._grid_version += 1
	var fresh_again: PackedVector3Array = tp.path(mid, goal)
	var end_fresh := Vector2(fresh_again[fresh_again.size() - 1].x - goal.x, fresh_again[fresh_again.size() - 1].z - goal.z).length()
	_expect(absf(end_cached - end_fresh) <= 8.0, "the reused prefix ends as near the goal as a fresh one (%.1f vs %.1f m)" % [end_cached, end_fresh])
	print("[t_pathcache] fresh %.2f ms, cached %.2f ms (first %d pts)" % [fresh_us / 1000.0, cached_us / 1000.0, first.size()])
	_expect(cached_us < fresh_us, "the cached replan is cheaper than a fresh one")
	# Invalidation.
	var h := int(tp.route_cache_hits)
	tp._grid_version += 1
	tp.path(mid, goal)
	_expect(tp.route_cache_hits == h, "a changed grid re-runs A*")
	var other := goal + Vector3(6.0, 0.0, 0.0)
	tp.path(mid, other)
	_expect(tp.route_cache_hits == h, "another goal re-runs A*")
	var near := start + Vector3(8.0, 0.0, 0.0)
	tp.path(start, near)
	tp.path(start, near)
	_expect(tp.route_cache_hits == h, "a short route always re-runs A*")
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_pathcache] PASS")
		quit(0)
	else:
		print("[t_pathcache] FAIL count=%d" % _fails.size())
		quit(1)
