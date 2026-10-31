extends SceneTree
## P1 WEAR (docs/design/tools-durability-crafting.md 3.1, 3.7, section 4): gather wear scales with the
## resource level against the tool level, clamp(1 + 0.04 x gap, 0.5, 2.5), rounded stochastically; a weapon
## used as a tool wears 3x; a damaging creature hit wears one worn armor piece (weighted by armor value, never
## a broken one, nothing on a dodge); a tribe worker stops with its tool at 1 durability and the Tribe screen
## says why; KNIFESPLIT: hunting never wears the Work Knife.
## Run: Godot --headless --path game --script res://tests/t_toolwear.gd -> "[t_toolwear] PASS".

var _fails: PackedStringArray = []
var _started := false
var _done := false
var data: Node
var player: Node
var host: Node3D
var IS: GDScript
var INV: GDScript
var GS: GDScript
var TUNE: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	GS = load("res://scripts/gather/gather_service.gd")
	TUNE = load("res://scripts/combat/combat_tuning.gd")
	_run.call_deferred()
	_watchdog()
	return false

func _watchdog() -> void:
	var t := 0.0
	while t < 300.0:
		await create_timer(1.0, true, false, true).timeout
		t += 1.0
		if _done:
			return
	print("[t_toolwear] FAIL watchdog (300 s)")
	quit(1)

func _expect(ok: bool, what: String) -> void:
	print("[t_toolwear] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _run() -> void:
	GS.rng.seed = 42
	_test_gather_wear()
	host = Node3D.new()
	host.name = "TToolwearHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 120.0)
	player = kit["player"]
	player.global_position = Vector3(0, 1, 0)
	await process_frame
	await physics_frame
	_test_armor()
	_test_knifesplit()
	await _test_tribe()
	TUNE.reset_overrides()
	_done = true
	Engine.time_scale = 1.0
	if _fails.is_empty():
		print("[t_toolwear] PASS")
		quit(0)
	else:
		print("[t_toolwear] FAIL count=%d" % _fails.size())
		quit(1)

func _tool(id: StringName, lvl: int):
	var s = IS.make(id, 1, {}, lvl)
	s.max_durability = 1000000
	s.durability = s.max_durability
	return s

## Average wear over n gathers of a `lvl` tool on a `res_level` lot.
func _avg(id: StringName, lvl: int, res_level: int, n: int = 1000) -> float:
	var inv = INV.new(4)
	var s = _tool(id, lvl)
	inv.slots[0] = s
	for i in n:
		inv.wear_tool(s, res_level)
	return float(s.max_durability - s.durability) / float(n)

func _test_gather_wear() -> void:
	var low := _avg(&"stone_knife_work", 1, 26)
	_expect(absf(low - 2.0) <= 0.1, "a level-1 work knife on a level-26 lot wears %.3f per gather (2.0 +- 0.1)" % low)
	# The doc's "level-30 knife 0.5" is the clamp floor; its own formula gives 1 - 0.04 x 4 = 0.84 at level 30.
	var l30 := _avg(&"stone_knife_work", 30, 26)
	_expect(absf(l30 - 0.84) <= 0.05, "a level-30 knife on the same lot wears %.3f (0.84 +- 0.05)" % l30)
	var l40 := _avg(&"stone_knife_work", 40, 26)
	_expect(absf(l40 - 0.5) <= 0.05, "a level-40 knife hits the 0.5 floor: %.3f" % l40)
	var even := _avg(&"stone_knife_work", 26, 26, 200)
	_expect(even == 1.0, "an equal-level knife wears exactly 1 (%.3f)" % even)
	var flat := _avg(&"stone_knife_work", 1, -1, 50)
	_expect(flat == 1.0, "unknown resource level keeps the flat 1 (%.3f)" % flat)
	var dag := _avg(&"stone_knife", 26, 26, 200)
	_expect(dag == 3.0, "a weapon used as a tool is 3x the work tool (%.3f)" % dag)
	var dag_low := _avg(&"stone_knife", 1, 26)
	_expect(absf(dag_low - 6.0) <= 0.3, "and 3x on the level gap too (%.3f ~ 6.0)" % dag_low)
	var lo := 9.0
	var hi := 0.0
	for gap in range(-200, 201, 7):
		var m: float = INV.wear_mult(100 + gap, 100)
		lo = minf(lo, m)
		hi = maxf(hi, m)
	_expect(lo >= 0.5 and hi <= 2.5 and is_equal_approx(lo, 0.5) and is_equal_approx(hi, 2.5), "the multiplier stays in 0.5-2.5 (%.2f-%.2f)" % [lo, hi])

func _clear_bag() -> void:
	var inv = player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	inv.equipment.clear()
	inv.equipped_tool_index = -1

func _raptor():
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = player.global_position + Vector3(0, 0, -1.6)
	host.add_child(c)
	c.spawn(data.creature(&"velociraptor"))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _test_armor() -> void:
	_clear_bag()
	var inv = player.inventory
	var ids := {&"head": &"forager_hood", &"body": &"forager_vest", &"arms": &"forager_wraps", &"legs": &"forager_leggings"}
	var pieces := {}
	for slot in ids:
		inv.add(IS.make(ids[slot], 1, {}, 1))
		_expect(inv.equip(slot, ids[slot]), "equip %s" % ids[slot])
		pieces[slot] = inv.equipped_in(slot)
	var start := {}
	for slot in pieces:
		start[slot] = pieces[slot].durability
	TUNE.force_accuracy = 1.0
	TUNE.force_dodge = 0.0
	TUNE.rng.seed = 5
	var c = _raptor()
	var crc = load("res://scripts/combat/creature_attack.gd")
	var landed := 0
	for i in 100:
		player.vitals.health = player.vitals.max_health
		if crc._deal_damage(c, player):
			landed += 1
	var lost := {}
	var total := 0
	for slot in pieces:
		lost[slot] = int(start[slot]) - int(pieces[slot].durability)
		total += int(lost[slot])
	_expect(landed == 100 and total == 100, "100 damaging hits take 100 durability across four pieces (landed %d, lost %s)" % [landed, lost])
	_expect(int(lost[&"body"]) > int(lost[&"arms"]), "the higher-armor vest wears more than the wraps (%d > %d)" % [lost[&"body"], lost[&"arms"]])
	# Dodged: nothing wears.
	TUNE.force_dodge = 1.0
	TUNE.force_accuracy = 0.0
	var before: int = 0
	for slot in pieces:
		before += int(pieces[slot].durability)
	for i in 20:
		player.vitals.health = player.vitals.max_health
		crc._deal_damage(c, player)
	var after: int = 0
	for slot in pieces:
		after += int(pieces[slot].durability)
	_expect(after == before, "dodged hits wear nothing (%d -> %d)" % [before, after])
	# A broken piece is never picked.
	TUNE.force_accuracy = 1.0
	TUNE.force_dodge = 0.0
	pieces[&"body"].durability = 0
	var arms0: int = pieces[&"arms"].durability + pieces[&"head"].durability + pieces[&"legs"].durability
	for i in 50:
		player.vitals.health = player.vitals.max_health
		crc._deal_damage(c, player)
	var arms1: int = pieces[&"arms"].durability + pieces[&"head"].durability + pieces[&"legs"].durability
	_expect(pieces[&"body"].durability == 0 and arms0 - arms1 == 50, "a broken vest is never picked; the other three took all 50 (%d)" % (arms0 - arms1))
	player.vitals.health = player.vitals.max_health
	c.free()
	TUNE.reset_overrides()

func _test_knifesplit() -> void:
	_clear_bag()
	var inv = player.inventory
	inv.add(IS.make(&"stone_knife_work", 1))
	inv.add(IS.make(&"stone_knife", 1))
	var knife = inv.slots[inv.find_first(&"stone_knife_work")]
	var k0: int = knife.durability
	TUNE.force_accuracy = 1.0
	TUNE.force_dodge = 0.0
	var c = _raptor()
	for i in 50:
		c.health.hp = c.health.max_hp
		player.hunt.land_hit(c, player.hunt._weapon())
	_expect(knife.durability == k0, "50 hits with the Work Knife and Stone Dagger carried leave the Work Knife untouched (%d -> %d)" % [k0, knife.durability])
	c.free()
	TUNE.reset_overrides()

func _test_tribe() -> void:
	var T = load("res://scripts/tribe/tribe.gd")
	T.reset()
	var basket = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	host.add_child(basket)
	basket.global_position = Vector3(8, 0.3, -6)
	var tree = (load("res://scenes/world/harvest_node.tscn") as PackedScene).instantiate()
	host.add_child(tree)
	tree.global_position = Vector3(14, 0, -6)
	tree.setup(&"toolwear_tree", &"wood_log", 1, 1, {"climate": "grassland", "level": 1}, &"axe", Color.BROWN, 1.0, 8.0, "CommonTree", false, 40)
	var r = T.make_recruit(T.rng)
	T.members.append(r)
	T.set_order(r, &"stay")
	var axe = IS.make(&"work_axe", 1, {"material_tier": "stone"}, 1)
	axe.durability = 3
	r.equipment.put(&"weapon", axe)
	T.set_job(r, &"chop", Vector3(12, 0, -6), basket.global_position)
	for i in 4:
		await physics_frame
	var body = player.tribe.body_of(r)
	body.global_position = Vector3(10, 1.0, -4)
	Engine.time_scale = 4.0
	var t := 0
	while t < 60 * 90 and not (body.tool_worn and body.state == &"idle"):
		await physics_frame
		t += 1
	Engine.time_scale = 1.0
	_expect(axe.durability == 1 and not axe.is_broken(), "a worker with a 3-durability axe on a level-1 tree stops with it at 1 (now %d, %d harvests)" % [axe.durability, body.harvests.size()])
	_expect(body.harvests.size() == 2, "two passes wore 3 -> 1, then the worker stopped (%d)" % body.harvests.size())
	var screen = load("res://scripts/ui/tribe_screen.gd").new()
	screen.player = player
	var doing: String = screen._doing(r)
	screen.free()
	_expect(doing.contains("tool worn"), "the Tribe screen says why ('%s')" % doing)
	T.reset()
