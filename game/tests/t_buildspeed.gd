extends SceneTree
## BUILDSPEED: the island build must stay the same island while it gets faster. Builds the islands
## game/data/perf_budget.json names (home plus the two unstable ones) through World.load_island,
## digests everything the build places - tile types, the fresh-water mask, harvest-node ids and
## positions, ground-cover/browse/prop scatter transforms - and compares each digest with the one
## recorded BEFORE the optimisation work started (the constants below). A single moved node, a
## dropped cover card or a repainted tile changes the digest and fails the run.
## Build time against the file's build_ms budget is measured too: five runs per island, every run
## timed around World.load_island. The island's figure is the FASTEST run (external load on this
## shared box only ever adds wall-clock time to a build; it never makes one finish early), and the
## worst run of the five is printed next to it, and the worst may only exceed the budget by
## build_ms.overrun_pct (35 %) before the test fails: a build that is fast once in five still fails,
## while one sample caught behind another job's Godot process does not.
## Run: Godot --headless --path game --script res://tests/t_buildspeed.gd -> "[t_buildspeed] PASS", 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before the autoloads exist.

const BUDGET_PATH := "res://data/perf_budget.json"
const WATCHDOG_S := 540.0
const RUNS := 5
## The gate is on: a fastest run over budget, or any single run over budget + overrun_pct, fails.
const EXPECTED_FAIL_TIME := false

## Recorded before any optimisation (2026-10-28, commit 5f0d6300 + the phase-timer marks, which
## change no output). These are the island the plan's budget is about; they may not change.
const BEFORE := {
	"home_grassland": "5899e136475de8d194cdb58a36df0954bca0cc791a20a06533e0f2db9bed3f7b",
	"savannah_15": "39124cf721d3dfb40a599bb47493700450317808ecbe82fa3f0129452c60223d",
	"volcanic_60": "aa21512f6fec687e3d4382e80f132be952db60eee8de32865378b83c463d3090",
}

var _fails: PackedStringArray = []
var _started := false
var _done := false
var _budget: Dictionary = {}
var _world: Node
var _host: Node3D

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	_watchdog()
	return false

func _watchdog() -> void:
	var t := 0.0
	while t < WATCHDOG_S:
		await create_timer(1.0).timeout
		t += 1.0
		if _done:
			return
	print("[t_buildspeed] FAIL watchdog (%.0f s)" % WATCHDOG_S)
	quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_buildspeed] FAIL %s" % what)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var text := FileAccess.get_file_as_string(BUDGET_PATH)
	var parsed: Variant = JSON.parse_string(text)
	_expect(parsed is Dictionary, "data/perf_budget.json parses into an object")
	if not (parsed is Dictionary):
		_finish()
		return
	_budget = parsed as Dictionary
	_world = root.get_node("World")
	# The phase table (terrain, scatter.cover, pathing, ...) prints for every build below, so a run
	# of this test is also the profile: "[buildprofile] island=<id> <phase>=<ms> ... total=<ms>".
	var trace := load("res://scripts/world/perf_trace.gd") as GDScript
	if trace != null:
		trace.set("force", true)
	_host = Node3D.new()
	_host.name = "TBuildspeed"
	root.add_child(_host)
	(load("res://scripts/world/world_lighting.gd") as GDScript).install(_host, "temperate")
	var islands: Array[String] = [String(str(_budget.get("islands", {}).get("home", "home_grassland")))]
	for row in _budget.get("islands", {}).get("unstable", []):
		islands.append(String(str(row)))
	# The first island of a process pays for lazy mesh/texture caches every later build reuses: one
	# throwaway build, exactly as t_perfgates does, so the timed runs are the island's own work.
	await _build(islands[0])
	_clear()
	await _frames(3)
	var kinds := "home"
	for id in islands:
		var build_max := float(((_budget["measures"] as Dictionary)["build_ms"] as Dictionary)[kinds + "_max"])
		var digests: Array[String] = []
		var ms: Array[float] = []
		for r in RUNS:
			_clear()
			await _frames(2)
			var t0 := Time.get_ticks_usec()
			await _build(id)
			ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
			digests.append(_digest())
		var best := INF
		var worst := 0.0
		for v in ms:
			best = minf(best, v)
			worst = maxf(worst, v)
		# A single slow sample fails only past this slack: this box runs other agents' Godot jobs and the
		# same build swings 10-20 % with the load, while a real regression moves every sample.
		var bm: Dictionary = (_budget["measures"] as Dictionary)["build_ms"] as Dictionary
		var ceiling := build_max * (1.0 + float(bm.get("overrun_pct", 35.0)) / 100.0)
		print("[t_buildspeed] island=%s digest=%s runs_ms=%s worst_ms=%.0f best_ms=%.0f budget_ms=%.0f" % [
			id, digests[0], str(ms), worst, best, build_max])
		for r in range(1, digests.size()):
			_expect(digests[r] == digests[0], "%s: run %d built a different island (digest %s vs %s)" % [
				id, r + 1, digests[r], digests[0]])
		var want := str(BEFORE.get(id, ""))
		_expect(want != "", "%s has a recorded before-digest" % id)
		_expect(digests[0] == want, "%s: the built island changed (digest %s, recorded %s)" % [id, digests[0], want])
		if best > build_max:
			if EXPECTED_FAIL_TIME:
				print("[t_buildspeed] OVER %s builds in %.0f ms (budget %.0f ms) - expected until the build is optimised" % [id, best, build_max])
			else:
				_expect(false, "%s builds in %.0f ms (budget %.0f ms): %s" % [id, best, build_max, str(ms)])
		else:
			print("[t_buildspeed] OK %s builds in %.0f ms (budget %.0f ms, worst of %d %.0f)" % [
				id, best, build_max, RUNS, worst])
		_expect(worst <= ceiling, "%s: a run took %.0f ms, over the %.0f ms single-run ceiling (budget %.0f + %.0f %%): %s" % [
			id, worst, ceiling, build_max, float(bm.get("overrun_pct", 35.0)), str(ms)])
		kinds = "unstable"
	_finish()

func _build(id: String) -> void:
	_world.call("load_island", _host, StringName(id), Vector3(0, 1, 0), false)
	await _frames(2)

func _clear() -> void:
	_world.call("_clear_runtime")

func _finish() -> void:
	_done = true
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	_clear()
	if _fails.is_empty():
		print("[t_buildspeed] PASS")
		quit(0)
	else:
		print("[t_buildspeed] FAIL count=%d" % _fails.size())
		quit(1)

# ------------------------------------------------------------------ the digest

## Everything the build places, quantised to a millimetre and hashed (SHA-256). Values are appended
## in a fixed order: sorting by id/key, never by node or dictionary order.
func _digest() -> String:
	var rt: Node = _world.get("runtime")
	if rt == null:
		return "none"
	var ints := PackedInt64Array()
	# Tile types and the masks the build derives from them.
	var types: PackedByteArray = rt.get("tile_types")
	var fresh: PackedByteArray = rt.get("fresh_water")
	var walk: PackedByteArray = rt.get("dry_walk")
	ints.append(types.size())
	for b in types:
		ints.append(b)
	ints.append(fresh.size())
	for b in fresh:
		ints.append(b)
	ints.append(walk.size())
	for b in walk:
		ints.append(b)
	# Harvest nodes: the build's own ids, so a rename or a moved node shows up.
	var nodes: Array = []
	for n in get_nodes_in_group("harvest"):
		if not rt.is_ancestor_of(n):
			continue
		nodes.append(n)
	nodes.sort_custom(func (a: Node, b: Node) -> bool: return str(a.get("node_id")) < str(b.get("node_id")))
	ints.append(nodes.size())
	for n in nodes:
		var p: Vector3 = n.global_position
		ints.append(_q(p.x))
		ints.append(_q(p.y))
		ints.append(_q(p.z))
		_append_text(ints, str(n.get("node_id")))
		ints.append(int(n.get("collision_layer")))
		ints.append(1 if n.visible else 0)
	# Ground cover: the placement record and every cell's instance transforms.
	var gc: Node = rt.get_node_or_null("GroundCover")
	var cover: PackedVector3Array = PackedVector3Array()
	if gc != null:
		cover = gc.call("positions")
	ints.append(cover.size())
	for p in cover:
		_append_vec(ints, p)
	if gc != null:
		var cells: Array = gc.call("cell_nodes")
		cells.sort_custom(func (a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
		ints.append(cells.size())
		for c in cells:
			var mmi: MultiMeshInstance3D = c
			_append_text(ints, str(mmi.name))
			if mmi.multimesh == null:
				ints.append(-1)
				continue
			ints.append(mmi.multimesh.instance_count)
			for i in mmi.multimesh.instance_count:
				_append_xf(ints, mmi.multimesh.get_instance_transform(i))
	# Browse (biome dressing) positions.
	var dress: Node = rt.get_node_or_null("BiomeDress")
	var dpos: PackedVector3Array = PackedVector3Array()
	if dress != null:
		dpos = dress.call("positions")
	ints.append(dpos.size())
	for p in dpos:
		_append_vec(ints, p)
	# Scenery props: kind, transform, scale and collision rule.
	var props: Variant = rt.get("props")
	var rows: Array = []
	if props != null:
		rows = props.get("_rows") as Array
	ints.append(rows.size())
	for r in rows:
		var row: Dictionary = r
		_append_text(ints, str(row.get("kind", "")))
		_append_xf(ints, row.get("xf", Transform3D.IDENTITY))
		ints.append(_q(float(row.get("height", 0.0))))
		ints.append(1 if bool(row.get("collide", false)) else 0)
	# Tree dirt discs.
	var discs: Variant = rt.get("_tree_discs")
	if discs is MultiMeshInstance3D and (discs as MultiMeshInstance3D).multimesh != null:
		var dmm: MultiMesh = (discs as MultiMeshInstance3D).multimesh
		ints.append(dmm.instance_count)
		for i in dmm.instance_count:
			_append_xf(ints, dmm.get_instance_transform(i))
	else:
		ints.append(0)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(ints.to_byte_array())
	return ctx.finish().hex_encode()

## A string as its UTF-8 bytes after its length: no hash(), so the digest does not depend on how a
## given engine version hashes a string (it is a stable id, not a bucket).
func _append_text(ints: PackedInt64Array, s: String) -> void:
	var bytes := s.to_utf8_buffer()
	ints.append(bytes.size())
	for b in bytes:
		ints.append(int(b))

func _q(v: float) -> int:
	return int(round(v * 1000.0))

func _append_vec(ints: PackedInt64Array, v: Vector3) -> void:
	ints.append(_q(v.x))
	ints.append(_q(v.y))
	ints.append(_q(v.z))

func _append_xf(ints: PackedInt64Array, xf: Transform3D) -> void:
	ints.append(_q(xf.origin.x))
	ints.append(_q(xf.origin.y))
	ints.append(_q(xf.origin.z))
	for i in 3:
		ints.append(_q(xf.basis[i].x))
		ints.append(_q(xf.basis[i].y))
		ints.append(_q(xf.basis[i].z))
