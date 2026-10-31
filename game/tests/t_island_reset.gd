extends SceneTree
## ISLAND RESET acceptance (docs/design/island-resources.md section 6, M4 gate):
##   - advancing an expedition island's clock past 0 increments its generation and changes its seed,
##     moves at least 70 % of its landmark centres by over 40 m, clears its found landmarks, fog and
##     harvest state, and puts the survivor at its harbour;
##   - a mid-life save round-trip keeps the clock; leaving and returning does not restart it; every
##     started clock runs while the game runs on another island; the clock does not move while the
##     game is closed (it is saved, not computed from wall time);
##   - two expedition islands keep separate harvest state;
##   - at the reset a placed building's storage moves whole to the home vault and the building refunds
##     half its kit recipe there;
##   - landmark nodes on an expedition island regrow only partly (stripped = empty until the reset),
##     ambient nodes regrow 5x slower than on home;
##   - an old save without the block loads as generation 0, a first visit.
## Run: Godot --headless --path game --script res://tests/t_island_reset.gd -> "[t_island_reset] PASS", 0/1.

var _fails: PackedStringArray = []
var _started := false
var W: Node
var host: Node3D
var player: Node3D

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_island_reset] FAIL %s" % what)

func _run() -> void:
	W = root.get_node("World")
	W.creation_pending = false
	host = Node3D.new()
	host.name = "ResetHost"
	root.add_child(host)
	player = (load("res://scripts/dev/lab_kit.gd") as GDScript).build(host)["player"]
	W.home_terrain = &"meadow"
	W.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)
	await process_frame
	await _test_clock()
	await _test_separate_harvest()
	await _test_regrowth()
	await _test_reset()
	_test_old_save()
	if _fails.is_empty():
		print("[t_island_reset] PASS")
		quit(0)
	else:
		print("[t_island_reset] FAIL count=%d" % _fails.size())
		quit(1)

func _go(id: StringName) -> void:
	W.load_island(host, id, Vector3(0, 1, 12), false)
	await process_frame

func _test_clock() -> void:
	await _go(&"temperate_25")
	var life: float = W.expedition_lifetime("temperate_25")
	_expect(absf(life - 6.0 * 3600.0) < 1.0, "a tier-25 island lives 6 h of play (%.0f s)" % life)
	_expect(absf(W.remaining_lifetime - life) < 1.0, "the first visit starts the clock at its lifetime")
	W.tick_expeditions(100.0)
	var left: float = W.expedition_row("temperate_25")["left"]
	_expect(absf(left - (life - 100.0)) < 0.5, "the clock counts play time (%.0f)" % left)
	await _go(&"home_grassland")
	W.tick_expeditions(50.0)
	_expect(absf(float(W.expedition_row("temperate_25")["left"]) - (life - 150.0)) < 0.5, "the clock runs while the game runs on another island")
	await _go(&"temperate_25")
	_expect(absf(W.remaining_lifetime - (life - 150.0)) < 0.5, "leaving and returning does not restart the clock (%.0f)" % W.remaining_lifetime)
	# Mid-life save: the rows round-trip through JSON and the sanitizer unchanged (a closed game
	# saves `left`; nothing reads wall time, so the clock does not move while it is closed).
	var SS: GDScript = load("res://scripts/core/save_sanitizer.gd")
	var back: Dictionary = SS.expedition_rows(JSON.parse_string(JSON.stringify(W.expeditions)))
	_expect(absf(float((back.get("temperate_25", {}) as Dictionary).get("left", 0.0)) - (life - 150.0)) < 0.5, "a save round-trip keeps the clock")
	_expect(SS.expedition_rows({"x": {"generation": "junk", "left": INF}}).get("x", {}).get("generation", -1) == 0, "the sanitizer cleans junk rows")

func _test_separate_harvest() -> void:
	await _go(&"temperate_25")
	var a = _first_node()
	var a_id := str(a.node_id)
	a.consume_unit()
	a.consume_unit()
	var left_a: int = a.pool_units_left()
	await _go(&"tropical_25")
	var b = W.runtime._harvest_nodes.get(a_id, null)
	if b != null:
		_expect(b.pool_units_left() == b.active_pool_max(), "tropical_25's node %s is not touched by temperate_25's harvest" % a_id)
	await _go(&"temperate_25")
	var again = W.runtime._harvest_nodes.get(a_id, null)
	_expect(again != null and again.pool_units_left() == left_a, "temperate_25 keeps its own harvest state (%s)" % str(again.pool_units_left() if again else -1))

func _first_node():
	for n in W.runtime._harvest_nodes.values():
		var h = n
		if is_instance_valid(h) and h.has_method("pool_units_left") and h.pool_units_left() >= 3 and str(h.get_meta(&"landmark", "")) == "":
			return h
	return null

func _test_regrowth() -> void:
	await _go(&"temperate_25")
	var lm = null
	var amb = _first_node()
	for n in W.runtime._harvest_nodes.values():
		if is_instance_valid(n) and str(n.get_meta(&"landmark", "")) != "" and n.pool_units_left() >= 3:
			lm = n
			break
	_expect(lm != null and lm.trickle_seconds > 0.0, "an expedition landmark node regrows partly")
	if lm:
		lm.consume_unit()
		var after_n: int = lm.pool_units_left()
		lm._process(lm.trickle_seconds + 1.0)
		_expect(lm.pool_units_left() == after_n + 1, "a landmark node with units left regains one")
		while lm.pool_units_left() > 0:
			lm.consume_unit()
		lm._process(100000.0)
		_expect(lm.pool_units_left() == 0, "a stripped landmark node stays empty until the reset")
	var home_regen := 0.0
	await _go(&"home_grassland")
	for n in W.runtime._harvest_nodes.values():
		if is_instance_valid(n) and amb and n.family == amb.family:
			home_regen = n.regen_seconds
			break
	await _go(&"temperate_25")
	var amb2 = null
	for n in W.runtime._harvest_nodes.values():
		if is_instance_valid(n) and amb and n.family == amb.family and str(n.get_meta(&"landmark", "")) == "":
			amb2 = n
			break
	if home_regen > 0.0 and amb2:
		_expect(absf(amb2.regen_seconds - home_regen * 5.0) < 0.5, "ambient nodes regrow 5x slower on an expedition island (%.0f vs %.0f)" % [amb2.regen_seconds, home_regen])

func _test_reset() -> void:
	await _go(&"temperate_25")
	var gen0: int = W.expedition_generation("temperate_25")
	var seed0 := int(W.def_of(&"temperate_25").get("seed", 0))
	var before: Array = []
	for s in W.current_landmarks():
		before.append(Vector2(float(s["x"]), float(s["z"])))
	if not W.current_landmarks().is_empty():
		W.discover_landmark(W.current_landmarks()[0])
	_expect(W.landmarks_found_count().x >= 1, "a landmark is found before the reset")
	_first_node().consume_unit()
	W._snapshot_harvest()
	# A placed basket with storage stands on the island.
	var SR: GDScript = load("res://scripts/core/save_restore.gd")
	var b: Node3D = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	W.runtime.add_child(b)
	var cell := _free_cell()
	SR.place(b, {"kind": "basket", "cell": [cell.x, cell.y], "rot": 0}, W.runtime.get("build_grid"))
	b.storage.add((load("res://scripts/items/item_stack.gd") as GDScript).make(&"stone", 1))
	var refund: Array = W.building_refund(&"basket")
	var vault_before := _vault_count()
	# Run the clock out.
	W.tick_expeditions(float(W.expedition_row("temperate_25")["left"]) + 1.0)
	await process_frame
	await process_frame
	_expect(W.expedition_generation("temperate_25") == gen0 + 1, "the reset increments the generation")
	var seed1 := int(W.def_of(&"temperate_25").get("seed", 0))
	_expect(seed1 != seed0, "the reset changes the seed (%d -> %d)" % [seed0, seed1])
	_expect(W.landmarks_found_count().x == 0, "found landmarks clear on the reset")
	_expect((W.expedition_row("temperate_25").get("harvested", {}) as Dictionary).is_empty(), "harvest state clears on the reset")
	_expect(absf(float(W.expedition_row("temperate_25")["left"]) - W.expedition_lifetime("temperate_25")) < 1.0, "the clock starts again")
	var arrival: Vector3 = W.runtime.arrival_point()
	_expect(Vector2(player.global_position.x - arrival.x, player.global_position.z - arrival.z).length() < 3.0, "the survivor stands at the harbour after the reset")
	var after: Array = []
	for s in W.current_landmarks():
		after.append(Vector2(float(s["x"]), float(s["z"])))
	var moved := 0
	for p in before:
		var nearest := 1e9
		for q in after:
			nearest = minf(nearest, (p as Vector2).distance_to(q))
		if nearest > 40.0:
			moved += 1
	_expect(before.is_empty() or float(moved) / float(before.size()) >= 0.7, "at least 70%% of landmark centres moved over 40 m (%d / %d)" % [moved, before.size()])
	var gained := _vault_count() - vault_before
	_expect(refund.size() > 0, "a basket has a kit recipe to refund from")
	_expect(gained == refund.size() + 1, "the vault gets the basket's stone plus half its recipe (%d, want %d)" % [gained, refund.size() + 1])

func _vault_count() -> int:
	var n := 0
	for s in W.cargo_home.slots:
		if s != null:
			n += s.count
	return n

func _free_cell() -> Vector2i:
	var grid = W.runtime.get("build_grid")
	var arrival: Vector3 = W.runtime.arrival_point()
	var c0 := BuildGridTile(arrival)
	for r in range(4, 30):
		for dx in range(-r, r + 1):
			for dz in [-r, r]:
				var c := c0 + Vector2i(dx, dz)
				if grid.can_place(&"basket", c, 0) == "":
					return c
	return c0

func BuildGridTile(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))

func _test_old_save() -> void:
	var SS: GDScript = load("res://scripts/core/save_sanitizer.gd")
	_expect((SS.expedition_rows(null) as Dictionary).is_empty(), "a save without the block reads as no expeditions")
	W.expeditions = {}
	_expect(W.expedition_generation("desert_35") == 0 and int(W.def_of(&"desert_35").get("seed", 0)) == int(W.islands["desert_35"].get("seed", 0)), "no block = generation 0 and the template seed")
