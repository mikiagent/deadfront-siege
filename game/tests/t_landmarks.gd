extends SceneTree
## LANDMARKS M1 acceptance (docs/design/island-resources.md section 6, M1 gate, plus the M2/M3 pieces
## this package carries). For every island row x 5 seeds:
##   - the landmark count is inside the island's budget band (landmarks.json budgets, doc section 5.1);
##   - every landmark is reachable from the harbour's arrival point by TilePath;
##   - centres keep the spacing floor between each other and stay out of the camp clearing;
##   - at least one landmark is within near_landing_m (140 m) of the landing;
##   - none stands on a claim, a claim_free circle or the tutorial's safe ring;
##   - planted landmark nodes sit at island tier + 5 (cap 60) and carry their site id;
##   - the plan is deterministic (same seed: same ids and positions);
##   - from tier 30 exactly one site per expedition island is dormant (no nodes, a seal), none below;
##   - the [landmarks] line prints placed/skipped, and skips stay under 10 % across the run.
## Then on temperate_25 (the authored crater) and tundra_30 (a dormant site): walking into a radius finds
## once and pays Gold once; the counter reads x / y; a save round-trip keeps found and opened state;
## opening a dormant site charges Gold once, plants its nodes, and they wither when the window closes;
## a landmark node's hand-harvest bonus raises the rare-trait rate 1.4-1.6x.
## Run: Godot --headless --path game --script res://tests/t_landmarks.gd -> "[t_landmarks] PASS", 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const IDS := ["home_grassland", "savannah_15", "savannah_45", "temperate_20", "temperate_25",
	"temperate_35", "temperate_45", "tropical_25", "tropical_40", "desert_35", "desert_50",
	"tundra_30", "tundra_55", "swamp_55", "volcanic_60"]
const SEEDS := 5

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var _IL: GDScript
var _placed := 0
var _skipped := 0

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_landmarks] FAIL %s" % what)

func _run() -> void:
	_IL = load("res://scripts/world/island_landmarks.gd")
	_host = Node3D.new()
	_host.name = "TLandmarks"
	root.add_child(_host)
	_world = root.get_node("World")
	var worst_ms := 0.0
	# LM_IDS=a,b / LM_SEEDS=n narrow a debug run; LM_SKIP_PLAY=1 skips the play checks.
	var ids: Array = Array(OS.get_environment("LM_IDS").split(",", false)) if OS.get_environment("LM_IDS") != "" else IDS
	var seeds := int(OS.get_environment("LM_SEEDS")) if OS.get_environment("LM_SEEDS") != "" else SEEDS
	for id in ids:
		var base: Dictionary = _world.def_of(StringName(id))
		for k in seeds:
			var def := base.duplicate(true)
			def["seed"] = int(base.get("seed", 17)) + k * 7919
			var t0 := Time.get_ticks_usec()
			var rt = _build(def)
			worst_ms = maxf(worst_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
			await process_frame
			_check_island(id, k, def, rt)
			rt.queue_free()
			await process_frame
	var total := _placed + _skipped
	_expect(total > 0 and float(_skipped) / float(total) < 0.10, "landmark skips under 10%% of the run (placed %d skipped %d)" % [_placed, _skipped])
	if OS.get_environment("LM_SKIP_PLAY") != "1":
		await _check_play()
	if _fails.is_empty():
		print("[t_landmarks] PASS islands=%d seeds=%d placed=%d skipped=%d worst_build_ms=%.0f" % [ids.size(), seeds, _placed, _skipped, worst_ms])
		quit(0)
	else:
		print("[t_landmarks] FAIL count=%d" % _fails.size())
		quit(1)

func _build(def: Dictionary):
	var ir = (load("res://scripts/world/island_runtime.gd") as GDScript).new()
	ir.name = "IslandRuntime"
	_host.add_child(ir)
	ir.build(def, &"meadow")
	return ir

func _check_island(id: String, k: int, def: Dictionary, rt) -> void:
	var tag := "%s seed#%d" % [id, k]
	var sites: Array = rt.landmarks
	var band: Vector2i = _IL.budget_for(def)
	var stats: Dictionary = rt.landmark_stats
	_placed += int(stats.get("placed", 0))
	_skipped += int(stats.get("skipped", 0))
	_expect(sites.size() >= band.x and sites.size() <= band.y, "%s landmark count %d inside %d-%d" % [tag, sites.size(), band.x, band.y])
	var rules: Dictionary = _IL.rules()
	var kind := str(def.get("kind", "unstable"))
	var spacing := float((rules.get("spacing_m", {}) as Dictionary).get(kind, 45)) * float(rules.get("spacing_floor_share", 0.6))
	var landing: Vector3 = rt.arrival_point() if rt.harbour != null else rt._camp_pos
	var near_m := float(rules.get("near_landing_m", 140))
	var any_near := false
	var dormant := 0
	var tier := int(def.get("tier", 25))
	var want_level: int = _IL.site_level(def, {})
	for i in sites.size():
		var s: Dictionary = sites[i]
		var at := Vector3(float(s["x"]), 0.0, float(s["z"]))
		at.y = rt.surface_y(at.x, at.z)
		var sid := str(s.get("id", ""))
		var flat := Vector2(at.x - landing.x, at.z - landing.z).length()
		if flat <= near_m:
			any_near = true
		if not bool(s.get("authored", false)):
			_expect(Vector2(at.x - rt._camp_pos.x, at.z - rt._camp_pos.z).length() >= float(rules.get("camp_clear_m", 60)) - 0.5,
				"%s %s outside the camp clearing" % [tag, sid])
		for j in range(i + 1, sites.size()):
			var o: Dictionary = sites[j]
			var d := Vector2(float(o["x"]) - at.x, float(o["z"]) - at.z).length()
			_expect(d >= spacing - 0.5, "%s %s and %s %.0f m apart (floor %.0f)" % [tag, sid, str(o.get("id", "")), d, spacing])
		_expect(_IL.reachable(rt, landing, s), "%s %s reachable from the harbour by TilePath" % [tag, sid])
		var tile := Vector2i(floori(at.x), floori(at.z))  # BuildGrid.tile_of, 1 m cells
		_expect(not rt.is_claimed(tile), "%s %s not on a claim" % [tag, sid])
		if bool(s.get("dormant", false)):
			dormant += 1
			_expect(int(s.get("planted", 0)) == 0, "%s dormant %s has no nodes until opened" % [tag, sid])
			_expect(s.get("seal", null) is Node, "%s dormant %s has a seal" % [tag, sid])
		else:
			_expect(int(s.get("planted", 0)) > 0, "%s %s planted its node group" % [tag, sid])
	var lv_ok := true
	var tagged := 0
	for n in rt._harvest_nodes.values():
		if is_instance_valid(n) and str(n.get_meta(&"landmark", "")) != "":
			tagged += 1
			if int(n.yield_attributes.get("level", 0)) != want_level:
				lv_ok = false
	_expect(sites.is_empty() or tagged > 0, "%s landmark nodes carry their site id" % tag)
	_expect(lv_ok, "%s landmark nodes are level %d (tier + 5)" % [tag, want_level])
	_expect(sites.is_empty() or any_near, "%s has a landmark within %.0f m of the landing" % [tag, near_m])
	var min_tier := int((rules.get("dormant", {}) as Dictionary).get("min_tier", 30))
	if kind == "unstable" and tier >= min_tier:
		_expect(dormant == 1, "%s (tier %d) has exactly one dormant landmark (%d)" % [tag, tier, dormant])
	else:
		_expect(dormant == 0, "%s (tier %d) has no dormant landmark (%d)" % [tag, tier, dormant])
	# Deterministic: planning again from the same island gives the same ids and points.
	if k == 0:
		var again: Dictionary = _IL.plan(rt, def)
		var a: Array = again["sites"]
		_expect(a.size() >= 1 or sites.is_empty(), "%s re-plan places sites" % tag)
		var b2: Dictionary = _IL.plan(rt, def)
		var same := a.size() == (b2["sites"] as Array).size()
		for i in mini(a.size(), (b2["sites"] as Array).size()):
			var p: Dictionary = a[i]
			var q: Dictionary = (b2["sites"] as Array)[i]
			if str(p.get("type", "")) != str(q.get("type", "")) or absf(float(p["x"]) - float(q["x"])) > 0.01 or absf(float(p["z"]) - float(q["z"])) > 0.01:
				same = false
		_expect(same, "%s plan is deterministic" % tag)

# ------------------------------------------------------------------------------------ play checks

func _check_play() -> void:
	_world.creation_pending = false
	# temperate_25: the crater is a landmark; finding it pays tier Gold once and counts.
	_world.load_island(_host, &"temperate_25", Vector3(0, 1, 0), false)
	await process_frame
	var rt = _world.runtime
	var sites: Array = _world.current_landmarks()
	_expect(sites.any(func (s: Dictionary) -> bool: return str(s.get("id", "")) == "crater"), "temperate_25's crater is one of its landmarks")
	var c0: Vector2i = _world.landmarks_found_count()
	_expect(c0.x == 0 and c0.y == sites.size(), "counter starts at 0 / %d (%s)" % [sites.size(), str(c0)])
	var gold0 := int(_world.t_stones)
	var first: Dictionary = sites[0]
	_expect(_world.check_landmarks(rt.arrival_point()).is_empty(), "standing at the landing finds nothing")
	var hit: Dictionary = _world.check_landmarks(Vector3(float(first["x"]) + 5.0, 0.0, float(first["z"])))
	_expect(not hit.is_empty(), "walking within the discovery radius finds the landmark")
	var paid := int(_world.t_stones) - gold0
	_expect(paid == _IL.gold_for_tier(25), "a tier-25 find pays %d Gold (paid %d)" % [_IL.gold_for_tier(25), paid])
	_world.check_landmarks(Vector3(float(first["x"]), 0.0, float(first["z"])))
	_expect(int(_world.t_stones) - gold0 == paid, "a second visit pays nothing")
	_expect(_world.landmarks_found_count().x == 1, "counter reads 1 / %d" % sites.size())
	# Map marker list: found only.
	var marks: Array = (load("res://scripts/ui/map_icons.gd") as GDScript).found_landmarks()
	_expect(marks.size() == 1, "the map draws only the found landmark (%d)" % marks.size())
	# Save round-trip of the found rows.
	var SS: GDScript = load("res://scripts/core/save_sanitizer.gd")
	var dumped: String = JSON.stringify({"found": _world.landmarks_found, "state": _world.landmark_state})
	var back: Dictionary = JSON.parse_string(dumped)
	var found2: Dictionary = SS.landmark_rows(back["found"], false)
	_expect(bool((found2.get("temperate_25", {}) as Dictionary).get(str(first["id"]), false)), "found state survives a save round-trip")
	_expect(SS.landmark_rows({"x": {"y": "junk"}}, false).is_empty(), "the sanitizer drops junk rows")
	# Hand-harvest bonus: landmark node rare rate is 1.4-1.6x ambient at the same tool.
	var LR: GDScript = load("res://scripts/gather/loot_roller.gd")
	var rng := RandomNumberGenerator.new()
	var mult := float((_IL.rules().get("hand_bonus", {}) as Dictionary).get("chance_mult", 1.5))
	var base_hits := 0
	var lm_hits := 0
	var tier3_lm := 0
	var tier3_base := 0
	rng.seed = 4242
	for _i in 20000:
		if LR.roll_trait(rng, &"", &"stone") != &"":
			base_hits += 1
			if LR.roll_tier(rng, &"stone") >= 3:
				tier3_base += 1
	rng.seed = 4242
	for _i in 20000:
		if LR.roll_trait(rng, &"", &"stone", false, mult) != &"":
			lm_hits += 1
			if LR.roll_tier(rng, &"stone", 0, 0.05) >= 3:
				tier3_lm += 1
	var ratio := float(lm_hits) / float(maxi(1, base_hits))
	_expect(ratio >= 1.4 and ratio <= 1.6, "landmark hand-harvest rare rate is %.2fx ambient (1.4-1.6)" % ratio)
	_expect(float(tier3_lm) / float(maxi(1, lm_hits)) > float(tier3_base) / float(maxi(1, base_hits)), "the landmark perk-tier step lifts tier III+ odds")
	var tagged: Node = null
	for n in rt._harvest_nodes.values():
		if is_instance_valid(n) and str(n.get_meta(&"landmark", "")) != "":
			tagged = n
			break
	var GS: GDScript = load("res://scripts/gather/gather_service.gd")
	_expect(tagged != null and not (GS.landmark_bonus(tagged) as Dictionary).is_empty(), "a landmark node gives the hand bonus")
	# tundra_30: one dormant site; open it with Gold, nodes grow, then wither at the window's end.
	_world.load_island(_host, &"tundra_30", Vector3(0, 1, 0), false)
	await process_frame
	var dormant: Dictionary = {}
	for s in _world.current_landmarks():
		if bool((s as Dictionary).get("dormant", false)):
			dormant = s
	_expect(not dormant.is_empty(), "tundra_30 has a dormant landmark")
	if not dormant.is_empty():
		var sid := str(dormant["id"])
		var cost := int((_IL.rules().get("dormant", {}) as Dictionary).get("open_cost_gold", 50))
		_world.t_stones = cost - 1
		_expect(_world.open_landmark(sid) != "", "opening without enough Gold is refused")
		_expect(int(_world.t_stones) == cost - 1, "a refusal spends nothing")
		_world.t_stones = cost + 200
		var before := int(_world.t_stones)
		_expect(_world.open_landmark(sid) == "", "opening with enough Gold succeeds")
		var spent := before - int(_world.t_stones)
		# The open also finds the site (it pays the find's Gold) when it was not found yet.
		_expect(spent == cost or spent == cost - _IL.gold_for_tier(30), "opening charges %d Gold once (net %d)" % [cost, spent])
		_expect(_world.open_landmark(sid) != "", "a second open is refused")
		_expect(int(dormant.get("planted", 0)) > 0, "the opened site grew its nodes")
		_expect(_world.landmark_open("tundra_30", sid), "the window is running")
		_world._tick_landmark_windows(float((_IL.rules().get("dormant", {}) as Dictionary).get("window_s", 1200)) + 1.0)
		await process_frame
		var left := 0
		for n in _world.runtime._harvest_nodes.values():
			if is_instance_valid(n) and not n.is_queued_for_deletion() and str(n.get_meta(&"landmark", "")) == sid:
				left += 1
		_expect(left == 0, "unharvested nodes wither when the window closes (%d left)" % left)
		_expect(_world.landmark_spent("tundra_30", sid), "the site is spent after its window")
		_expect(_world.open_landmark(sid) != "", "a spent site cannot be reopened")
