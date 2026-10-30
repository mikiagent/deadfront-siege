extends SceneTree
## UNSTABLE ISLES acceptance (docs/design/unstable-isles.md section 7):
##   - N seeds (default 10, env UI_SEEDS) roll and build: each has a harbour, a tier inside the band
##     around the survivor's top sailable tier and a non-home climate, landmarks inside its budget
##     (the tier band + 2), every landmark reachable from the harbour by TilePath, a Rift Pool that
##     planted driftglass nodes and is never sealed, and sites at tier + 8;
##   - an offer nobody sails leaves the board after its window and the cooldown holds;
##   - running the life clock out on the isle sinks it: the survivor stands at the home harbour with
##     the bag as it was, the isle's row, clock and landmarks are gone, the harbour list drops it;
##   - driftglass grows only on isles (no roster climate, ambient or landmark, yields it);
##   - the board round-trips through a save; a forged row is dropped.
## Run: Godot --headless --path game --script res://tests/t_unstable_isles.gd -> "[t_unstable_isles] PASS", 0/1.

var _fails: PackedStringArray = []
var _started := false
var W: Node
var host: Node3D
var player: Node3D
var _IL: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_unstable_isles] FAIL %s" % what)

func _run() -> void:
	W = root.get_node("World")
	W.creation_pending = true  # no background rolls while the test drives the board itself
	_IL = load("res://scripts/world/island_landmarks.gd")
	host = Node3D.new()
	host.name = "IsleHost"
	root.add_child(host)
	player = (load("res://scripts/dev/lab_kit.gd") as GDScript).build(host)["player"]
	W.home_terrain = &"meadow"
	W.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)
	await process_frame
	_test_data()
	await _test_seeds()
	_test_expiry()
	await _test_sink()
	_test_save()
	if _fails.is_empty():
		print("[t_unstable_isles] PASS")
		quit(0)
	else:
		print("[t_unstable_isles] FAIL count=%d" % _fails.size())
		quit(1)

func _go(id: StringName) -> void:
	W.load_island(host, id, Vector3(0, 1, 12), false)
	await process_frame

func _test_data() -> void:
	var lm: Dictionary = (_IL.data() as Dictionary).get("climates", {})
	var fams: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/nature_manifest.json")) as Dictionary)["families"]
	var climates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/climates.json"))
	var growers: Array = []
	for fam in fams:
		if ((fams[fam] as Dictionary).get("harvest", {}) as Dictionary).has("driftglass"):
			growers.append(str(fam))
	_expect(growers == ["DriftglassNode"], "only DriftglassNode yields driftglass (%s)" % str(growers))
	for cl in climates:
		if climates[cl] is Dictionary:
			_expect(not ((climates[cl] as Dictionary).get("vegetation", []) as Array).has("DriftglassNode"), "climate %s does not grow driftglass ambient" % cl)
	for cl in lm:
		if cl == "generated":
			continue
		for row in lm[cl]:
			_expect(not ((row as Dictionary).get("nodes", {}) as Dictionary).has("DriftglassNode"), "roster landmark %s:%s has no driftglass" % [cl, (row as Dictionary).get("display", "")])
	var gen: Array = lm.get("generated", [])
	_expect(gen.size() >= 1 and bool((gen[0] as Dictionary).get("must", false)) and ((gen[0] as Dictionary).get("nodes", {}) as Dictionary).has("DriftglassNode"), "every isle draws a Rift Pool")

func _test_seeds() -> void:
	var n := int(OS.get_environment("UI_SEEDS")) if OS.get_environment("UI_SEEDS") != "" else 10
	var survivals := [10, 20, 30, 40, 50, 55]
	var off := int((W.drift_rules() as Dictionary).get("level_offset", 8))
	var seen_climates := {}
	for k in n:
		W.drift = {}
		var surv: int = survivals[k % survivals.size()]
		var id: String = W.roll_drift(1000 + k * 7919, surv)
		_expect(id != "", "seed #%d rolls an isle" % k)
		if id == "":
			continue
		var def: Dictionary = W.def_of(StringName(id))
		var top: int = W._sailable_top(surv)
		var tier := int(def.get("tier", 0))
		var tag := "%s (seed #%d tier %d %s %s)" % [id, k, tier, def.get("climate", ""), def.get("shape_family", "")]
		seen_climates[str(def.get("climate", ""))] = true
		_expect(tier >= 15 and tier <= 60 and absi(tier - top) <= 5, "%s tier within 5 of the top sailable %d" % [tag, top])
		_expect(str(def.get("kind", "")) == "unstable" and bool(def.get("generated", false)), "%s is a generated unstable island" % tag)
		_expect(not bool(((W.islands.get(str(def.get("template", "")), {}) as Dictionary).get("permanent", false))), "%s template is a roster island" % tag)
		_expect(W.harbour_routes().has(id), "%s is on the harbour list" % tag)
		await _go(StringName(id))
		var rt = W.runtime
		_expect(rt != null and rt.generated, "%s builds as a generated runtime" % tag)
		if rt == null:
			continue
		_expect(rt.harbour != null, "%s has a harbour" % tag)
		var sites: Array = rt.landmarks
		var band: Vector2i = _IL.budget_for(def)
		_expect(sites.size() >= band.x and sites.size() <= band.y, "%s landmarks %d inside %d-%d" % [tag, sites.size(), band.x, band.y])
		var landing: Vector3 = rt.arrival_point()
		var rift := 0
		for s in sites:
			_expect(_IL.reachable(rt, landing, s), "%s %s reachable from the harbour" % [tag, (s as Dictionary).get("id", "")])
			if str((s as Dictionary).get("type", "")) == "rift":
				rift += 1
				_expect(not bool((s as Dictionary).get("dormant", false)) and int((s as Dictionary).get("planted", 0)) > 0, "%s Rift Pool planted and never sealed" % tag)
		_expect(rift == 1, "%s has one Rift Pool (%d)" % [tag, rift])
		_expect(_IL.site_level(def, {}) == mini(60, tier + off), "%s sites at tier + %d" % [tag, off])
		var glass := 0
		for node in rt._harvest_nodes.values():
			if is_instance_valid(node) and str(node.family) == "DriftglassNode":
				glass += 1
		_expect(glass >= 4, "%s grows driftglass (%d nodes)" % [tag, glass])
		_expect(absf(float(W.expedition_lifetime(id)) - float((W.drift_rules() as Dictionary).get("life_s", 2400))) < 0.5, "%s lives life_s once landed" % tag)
		await _go(&"home_grassland")
		W._erase_drift(id)
		_expect(not W.islands.has(id), "%s is gone once erased" % tag)
	_expect(seen_climates.size() >= 3, "the seeds roll several climates (%s)" % str(seen_climates.keys()))

func _test_expiry() -> void:
	W.drift = {}
	W.drift_cooldown = 0.0
	var id: String = W.roll_drift(4242, 30)
	var window := float((W.drift_rules() as Dictionary).get("offer_window_s", 1200))
	W.tick_drifts(window - 5.0)
	_expect(W.islands.has(id) and not W.drift.is_empty(), "the offer stays on the board inside its window")
	W.tick_drifts(10.0)
	_expect(not W.islands.has(id) and W.drift.is_empty(), "an offer nobody sailed leaves the board")
	_expect(not W.harbour_routes().has(id), "the expired route is off the harbour list")
	var cd := float((W.drift_rules() as Dictionary).get("offer_every_s", 1800))
	_expect(absf(W.drift_cooldown - cd) < 0.5, "the cooldown starts (%.0f)" % W.drift_cooldown)

func _test_sink() -> void:
	W.drift = {}
	var id: String = W.roll_drift(777, 30)
	await _go(StringName(id))
	_expect(W.drift_landed(), "landing starts the isle's clock")
	# A landed isle cannot expire off the board.
	W.tick_drifts(100000.0)
	_expect(W.islands.has(id), "a landed isle does not leave the board")
	var ItemStack: GDScript = load("res://scripts/items/item_stack.gd")
	var st = ItemStack.make(&"stone", 1)
	st.set_flag(&"unstable", true)
	player.inventory.add(st)
	var bag_before := _bag_count()
	var vault_before := _vault_count()
	W.tick_expeditions(float(W.expedition_row(id)["left"]) + 1.0)
	await process_frame
	await process_frame
	_expect(str(W.island_id) == "home_grassland", "the survivor is home after the sink (%s)" % str(W.island_id))
	var arrival: Vector3 = W.runtime.arrival_point()
	_expect(Vector2(player.global_position.x - arrival.x, player.global_position.z - arrival.z).length() < 3.0, "the survivor stands at the home harbour")
	_expect(_bag_count() == bag_before, "the bag comes home as it was (%d vs %d)" % [_bag_count(), bag_before])
	_expect(_vault_count() == vault_before, "a sink refunds nothing to the vault")
	_expect(not W.islands.has(id) and not W.expeditions.has(id) and not W.landmarks_found.has(id), "the isle's row, clock and landmarks are gone")
	_expect(not W.harbour_routes().has(id), "the sunk isle is off the harbour list")
	_expect(W.drift.is_empty(), "no isle is live after the sink")

func _bag_count() -> int:
	var n := 0
	for s in player.inventory.slots:
		if s != null:
			n += s.count
	return n

func _vault_count() -> int:
	var n := 0
	for s in W.cargo_home.slots:
		if s != null:
			n += s.count
	return n

func _test_save() -> void:
	var SS: GDScript = load("res://scripts/core/save_sanitizer.gd")
	W.drift = {}
	W.drift_cooldown = 0.0
	var id: String = W.roll_drift(99, 40)
	var block := {"row": W.drift, "cooldown": 12.0, "count": W.drift_count}
	var back: Dictionary = SS.drift_block(JSON.parse_string(JSON.stringify(block)))
	var row: Dictionary = back["row"]
	_expect(str(row.get("id", "")) == id and int(row.get("seed", 0)) == int(W.drift["seed"]) and int(row.get("tier", 0)) == int(W.drift["tier"]), "the offer round-trips through a save")
	_expect(absf(float(back["cooldown"]) - 12.0) < 0.01 and int(back["count"]) == W.drift_count, "the cooldown and roll count round-trip")
	var forged := (W.drift as Dictionary).duplicate()
	forged["template"] = "home_grassland"
	_expect((SS.drift_block({"row": forged}) as Dictionary)["row"].is_empty(), "a row naming a non-roster template is dropped")
	_expect((SS.drift_block(null) as Dictionary)["row"].is_empty(), "no block = no isle")
	# Reinstalling the saved roll rebuilds the same catalogue row.
	var before: Dictionary = (W.islands[id] as Dictionary).duplicate(true)
	W.islands.erase(id)
	W.drift = row
	W._install_drift()
	_expect(W.islands.has(id) and int(W.islands[id]["seed"]) == int(before["seed"]) and str(W.islands[id]["shape_family"]) == str(before["shape_family"]), "a loaded roll rebuilds the same isle")
	W._erase_drift(id)
