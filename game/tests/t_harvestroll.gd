extends SceneTree
## HARVESTROLL (owner 2026-10-28: "it kept giving me the same branch"): every pass on one tree is its own
## lot. 30 passes on one level-20 BirchTree branch node give varied results (level inside 15..20, signed
## traits), each pass is exactly one item (ONEGATHER), and the same seed replays the same sequence.
## Gathering and tool tier skew the band's top; the server's act.gather rolls through the same LootRoller.

var failures: Array[String] = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	var node_scene: PackedScene = load("res://scenes/world/harvest_node.tscn")
	var lr: GDScript = load("res://scripts/gather/loot_roller.gd")
	var n = node_scene.instantiate()
	n.setup(&"t_birch", &"branch", 1, 1, {"level": 20, "climate": "temperate"}, &"none", Color.GRAY, 1.2, 8.0, "BirchTree")
	get_root().add_child(n)
	var seq_a := _passes(n, 1234)
	var seq_b := _passes(n, 1234)
	var distinct := {}
	for s in seq_a:
		distinct[s] = true
	_expect(distinct.size() >= 5, "30 passes give varied lots (%d distinct)" % distinct.size())
	_expect(seq_a == seq_b, "same seed replays the same sequence")
	_expect(seq_a != _passes(n, 99), "another seed gives another sequence")
	var levels := {}
	for s: String in seq_a:
		levels[int(s.get_slice("|", 1))] = true
	_expect(levels.size() >= 2, "levels vary inside the band (%s)" % [levels.keys()])
	for l: int in levels:
		_expect(l >= 15 and l <= 20, "level %d inside 15..20" % l)
	# Skill and tool skew to the top of the band: mean level over 400 rolls.
	var novice := _mean_level(lr, &"", 1)
	var expert := _mean_level(lr, &"steel", 60)
	_expect(expert > novice + 0.5, "expert mean level %.2f above novice %.2f" % [expert, novice])
	# A level-1 node never yields below 1 or above 1.
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 50:
		_expect(int(lr.roll_lot(&"branch", 1, &"", 1, r)["level"]) == 1, "level-1 node yields level 1")
	_test_perk_cap(n)
	_test_feed_latest()
	n.queue_free()
	if failures.is_empty():
		print("[t_harvestroll] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_harvestroll] FAIL ", f)
		quit(1)
	return true

func _passes(n, seed_v: int) -> Array[String]:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out: Array[String] = []
	for i in 30:
		var st = n.roll_yield(r)
		_expect(st.count == 1, "pass %d gives exactly one item" % i)
		var keys: Array = st.attributes.keys()
		keys.sort()
		var sig := "%s|%d" % [st.def_id, st.level]
		for k in keys:
			if k != "level" and k != "tint":
				sig += "|%s=%s" % [k, st.attributes[k]]
		out.append(sig)
	return out

## PERKCAP (owner: "1-2 perks on each gathered item max"): 200 passes through the real yield + green-trait
## stamp (steel tool, so the gold and green odds are at their highest) never exceed 2 perks or carry a
## trait with its opposite; the grey rate sits near lot.negative_chance (35%).
func _test_perk_cap(n) -> void:
	var gs: GDScript = load("res://scripts/gather/gather_service.gd")
	var inv_s: GDScript = load("res://scripts/items/inventory.gd")
	var ia: GDScript = load("res://scripts/ui/inv_attributes.gd")
	var opp: Dictionary = load("res://scripts/gather/loot_tables.gd").lot_cfg().get("opposites", {})
	var r := RandomNumberGenerator.new()
	r.seed = 2028
	var grey := 0
	var green := 0
	var worst := 0
	for i in 200:
		var bag = inv_s.new(20)
		var had: Dictionary = bag.uids()
		var st = n.roll_yield(r, &"steel", 60)
		bag.add(st)
		gs.stamp_traits(bag, had, st, 1, r, &"steel")
		var item = bag.slots.filter(func (x) -> bool: return x != null)[0]
		var sec: Dictionary = ia.sections(item)
		var keys: Array = []
		for cls in ["rare", "positive", "negative"]:
			for row: Dictionary in sec[cls]:
				keys.append(str(row["key"]))
		worst = maxi(worst, keys.size())
		if not (sec["negative"] as Array).is_empty():
			grey += 1
		if not (sec["rare"] as Array).is_empty():
			green += 1
		for k: String in keys:
			_expect(not keys.has(str(opp.get(k, ""))), "pass %d carries %s with its opposite (%s)" % [i, k, keys])
	print("[t_harvestroll] 200 passes: most perks %d, grey %d, green %d" % [worst, grey, green])
	_expect(worst <= 2, "no gathered item carries more than 2 perks (worst %d)" % worst)
	_expect(grey >= 45 and grey <= 95, "grey rate near 35%% (%d of 200)" % grey)

## The feed row's chips are the latest item's own; the count is a labelled running total.
func _test_feed_latest() -> void:
	var feed = load("res://scripts/ui/top_feed.gd").new()
	feed._add({"kind": &"gain", "id": &"branch", "n": 1, "chips": [["Soft Lv. 1", &"negative"]], "stack": null, "tier": &"grey"})
	feed._add({"kind": &"gain", "id": &"branch", "n": 1, "chips": [["Heavy Lv. 2", &"negative"]], "stack": null, "tier": &"grey"})
	feed._add({"kind": &"gain", "id": &"branch", "n": 1, "chips": [["Firm Lv. 3", &"positive"]], "stack": null, "tier": &"yellow"})
	var rows: Array = feed.rows
	_expect(rows.size() == 1 and int(rows[0]["n"]) == 3 and int(rows[0].get("gains", 1)) == 3, "three branch gains collapse into one +3 total row")
	_expect(rows.size() == 1 and rows[0]["chips"] == [["Firm Lv. 3", &"positive"]], "the row shows the latest item's perks only (%s)" % [rows[0]["chips"] if not rows.is_empty() else []])

func _mean_level(lr: GDScript, tier: StringName, skill: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	var sum := 0
	for i in 400:
		sum += int(lr.roll_lot(&"branch", 50, tier, skill, r)["level"])
	return float(sum) / 400.0

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
