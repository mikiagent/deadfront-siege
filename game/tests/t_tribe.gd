extends SceneTree
## TRIBE M1 (owner 2026-10-28: "tribe members are like pals in palworld who can mine and fight";
## "keep the recruit in the harbor, we have to manually accept or deny them"). Vision §5 rules:
## a boat brings recruits who WAIT at the dock (cap, expiry), Accept joins them within the housing cap,
## Deny sends them away; a member saves and loads (an old save has none); gear goes into the seven
## slots; follow keeps a slot near the survivor; guard engages a hostile that is attacking her and
## damages it; a mining job harvests ONE item per pass at the tool's speed into the chosen chest;
## a hungry member eats from that chest, an exhausted one rests; one job at a time.
## Run: Godot --headless --path game --script res://tests/t_tribe.gd -> "[t_tribe] PASS".

var _fails: PackedStringArray = []
var _started := false
var _done := false
var _sections := 0
const WANT := 9
var data: Node
var player: Node
var host: Node3D
var IS: GDScript
var SS: GDScript
var GS: GDScript
var INV: GDScript
var EE: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	IS = load("res://scripts/items/item_stack.gd")
	SS = load("res://scripts/core/save_sanitizer.gd")
	GS = load("res://scripts/gather/gather_service.gd")
	INV = load("res://scripts/items/inventory.gd")
	EE = load("res://scripts/items/entity_equipment.gd")
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
	print("[t_tribe] FAIL watchdog (300 s)")
	quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_tribe] FAIL %s" % what)

func _finish() -> void:
	_done = true
	Engine.time_scale = 1.0
	_expect(_sections == WANT, "only %d of %d sections completed (a runtime error aborted the rest)" % [_sections, WANT])
	if _fails.is_empty():
		print("[t_tribe] PASS")
		quit(0)
	else:
		print("[t_tribe] FAIL count=%d" % _fails.size())
		quit(1)

func _run() -> void:
	var T = load("res://scripts/tribe/tribe.gd")
	T.rng.seed = 7
	_test_dock(T)
	_test_save(T)
	host = Node3D.new()
	host.name = "TTribeHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 120.0)
	player = kit["player"]
	player.global_position = Vector3(0, 1, 0)
	await process_frame
	await physics_frame
	_test_equip(T)
	await _test_follow(T)
	await _test_guard(T)
	await _test_mining(T)
	await _test_eat_rest(T)
	_test_one_job(T)
	_test_ui(T)
	_finish()

# ---------------------------------------------------------------- 1. dock: wait, cap, expire, accept, deny

func _test_dock(T) -> void:
	T.reset()
	var cap: int = T.pending_cap()
	_expect(cap == 3, "pending cap is %d (data says 3)" % cap)
	# The boat: nothing before one interval, one recruit after it, and they WAIT (not a member).
	T.tick(1.0)
	_expect(T.pending.is_empty(), "a recruit arrived before the first boat interval")
	T.tick(T.arrival_interval())
	_expect(T.pending.size() == 1 and T.members.is_empty(), "one boat interval: 1 waiting, 0 members (got %d / %d)" % [T.pending.size(), T.members.size()])
	var first = T.pending[0]
	_expect(first.name != "" and not first.look.is_empty() and first.potential != "", "a recruit has a name, a body and a potential")
	# Cap: the dock holds 3; a 4th boat turns back.
	T.arrive()
	T.arrive()
	_expect(T.arrive() == null and T.pending.size() == cap, "the dock queue is capped at %d (got %d)" % [cap, T.pending.size()])
	# Expire: ignored, the oldest leaves after wait_days; the others (arrived later) keep waiting.
	for r in T.pending:
		r.wait_left = T.wait_seconds()
	first.wait_left = 5.0
	var notices: Array = T.tick(6.0)
	_expect(not T.pending.has(first) and T.pending.size() == cap - 1, "the ignored oldest recruit left (pending %d)" % T.pending.size())
	_expect(notices.any(func (n: String) -> bool: return n.contains("left on the boat")), "a departure notice was raised")
	# Deny: they leave.
	var d = T.pending[0]
	T.deny(d)
	_expect(not T.pending.has(d) and not T.members.has(d), "deny sends the recruit away")
	# Accept within the housing cap, refused with a reason past it.
	var housing: int = T.housing_cap()
	_expect(housing == 2, "base housing is 2 with no beds (got %d)" % housing)
	var a = T.pending[0]
	_expect(T.accept(a) == "" and T.members.has(a) and not T.pending.has(a), "accept moves the recruit into the tribe")
	T.members.append(T.make_recruit(T.rng))  # fill the second bed
	var b = T.arrive()
	var why: String = T.accept(b)
	_expect(why.contains("housing") and T.pending.has(b) and T.members.size() == housing, "accept past the housing cap is refused with a reason (got '%s')" % why)
	# Rarity: mostly weak/mediocre, rarely exceptional.
	var counts := {}
	var r2 := RandomNumberGenerator.new()
	r2.seed = 11
	for i in 4000:
		var p: String = T.roll_potential(r2)
		counts[p] = int(counts.get(p, 0)) + 1
	var low := int(counts.get("weak", 0)) + int(counts.get("mediocre", 0))
	_expect(low > 3000 and int(counts.get("exceptional", 0)) < 80, "potential rolls are mostly weak/mediocre, exceptional rare (%s)" % str(counts))
	_sections += 1

# ---------------------------------------------------------------- 2. save / load

func _test_save(T) -> void:
	T.reset()
	var m = T.make_recruit(T.rng)
	T.members.append(m)
	m.equipment.put(&"weapon", IS.make(&"work_pick", 1, {}, 1))
	m.carry.add(IS.make(&"stone", 1, {}, 1))
	T.set_job(m, &"mine", Vector3(3, 0, 4), Vector3(5, 0, 6))
	m.fullness = 42.0
	var p = T.arrive()
	p.wait_left = 123.0
	var raw: Dictionary = JSON.parse_string(JSON.stringify({"tribe": T.to_save()}))
	var clean: Dictionary = SS.clean(raw)
	T.from_save(clean.get("tribe"))
	_expect(T.members.size() == 1 and T.pending.size() == 1, "members and pending survive save/load (%d / %d)" % [T.members.size(), T.pending.size()])
	if T.members.size() == 1 and T.pending.size() == 1:
		var l = T.members[0]
		_expect(l.uid == m.uid and l.name == m.name and l.potential == m.potential and l.look == m.look, "identity and body round-trip")
		_expect(l.equipment.worn(&"weapon") != null and l.equipment.worn(&"weapon").def_id == &"work_pick", "worn pick round-trips")
		_expect(l.carry.count_of(&"stone") == 1, "carried stone round-trips")
		_expect(l.order == &"work" and str(l.job.get("kind")) == "mine" and is_equal_approx(float(l.job["chest"][1]), 6.0), "the job and its chest round-trip")
		_expect(is_equal_approx(l.fullness, 42.0), "needs round-trip")
		_expect(T.pending[0].uid == p.uid and is_equal_approx(T.pending[0].wait_left, 123.0), "a waiting recruit and its time left round-trip")
	# An old save (no "tribe") loads with no members; a forged row is coerced.
	T.from_save(null)
	_expect(T.members.is_empty() and T.pending.is_empty(), "an old save loads with no members")
	T.from_save({"members": [{"name": 5, "order": "dance", "fullness": "x", "job": {"kind": "fly"}, "pos": ["a"]}, "junk"]})
	_expect(T.members.size() == 1 and T.members[0].order == &"stay" and T.members[0].job.is_empty() and T.members[0].fullness == 100.0, "a forged member row is coerced, junk dropped")
	T.reset()
	_sections += 1

# ---------------------------------------------------------------- 3. equip

func _member(T, order: StringName = &"stay"):
	var r = T.make_recruit(T.rng)
	T.members.append(r)
	T.set_order(r, order)
	return r

func _body(r) -> Node:
	return player.tribe.body_of(r)

func _test_equip(T) -> void:
	T.reset()
	var r = _member(T)
	var inv = player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	inv.add(IS.make(&"work_pick", 1, {}, 1))
	inv.add(IS.make(&"berries", 1, {}, 1))
	var pick_i: int = inv.find_first(&"work_pick")
	_expect(r.equipment.equip_from(inv, pick_i) == "" and r.equipment.worn(&"weapon").def_id == &"work_pick" and inv.count_of(&"work_pick") == 0, "a pick from the bag goes into the hand slot")
	_expect(r.equipment.equip_from(inv, inv.find_first(&"berries")) != "", "food cannot be worn")
	_expect(EE.HUMAN_SLOTS.size() == 7 and r.equipment.allowed.size() == 7, "a member has seven slots")
	_expect(r.equipment.unequip_to(inv, &"weapon") == "" and inv.count_of(&"work_pick") == 1, "unequip puts it back in the bag")
	T.reset()
	_sections += 1

# ---------------------------------------------------------------- 4. follow

func _settle(frames: int) -> void:
	for i in frames:
		await physics_frame

func _test_follow(T) -> void:
	T.reset()
	var r = _member(T, &"follow")
	await _settle(4)
	var body = _body(r)
	_expect(body != null, "the director spawned a body for the member")
	if body == null:
		_sections += 1
		return
	body.global_position = player.global_position + Vector3(12, 0, 6)
	await _settle(360)
	var slot: Vector3 = body.follow_slot(player)
	var d := Vector2(body.global_position.x - slot.x, body.global_position.z - slot.z).length()
	var dp := Vector2(body.global_position.x - player.global_position.x, body.global_position.z - player.global_position.z).length()
	_expect(d < 4.0, "a following member settles near its slot (%.1f m)" % d)
	_expect(dp > 0.6 and dp < 8.0, "it stays near, not on top of, the survivor (%.1f m)" % dp)
	_expect(body.state == &"follow" and not r.order == &"work", "it is following, not working")
	T.reset()
	await _settle(2)
	_sections += 1

# ---------------------------------------------------------------- 5. guard

func _test_guard(T) -> void:
	T.reset()
	var r = _member(T, &"guard")
	r.equipment.put(&"weapon", IS.make(&"stone_knife", 1, {}, 1))
	await _settle(4)
	var body = _body(r)
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = player.global_position + Vector3(-5, 0.5, 0)
	host.add_child(c)
	c.spawn(data.creature(&"velociraptor"))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.set_physics_process(false)
	c.brain.attack_target = player  # it is attacking the survivor
	c.brain.state = &"attack"
	var hits: Array = []
	c.health.damaged.connect(func (amt: float, src: Node) -> void: hits.append([amt, src]))
	var hp0: float = c.health.hp
	await _settle(600)
	_expect(not hits.is_empty() and hits.all(func (h: Array) -> bool: return h[1] == body), "the guarding member hit the raptor attacking the survivor (%d hits)" % hits.size())
	_expect(c.health.hp < hp0, "the raptor took damage (%.0f -> %.0f)" % [hp0, c.health.hp])
	c.queue_free()
	T.reset()
	await _settle(2)
	_sections += 1

# ---------------------------------------------------------------- 6. mining job

var _basket: Node3D
var _rock: Node

func _place_basket(at: Vector3) -> Node3D:
	var b = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	host.add_child(b)
	b.global_position = at
	return b

func _place_rock(at: Vector3, units: int) -> Node:
	var n = (load("res://scenes/world/harvest_node.tscn") as PackedScene).instantiate()
	host.add_child(n)
	n.global_position = at
	n.setup(StringName("tribe_rock_%d" % n.get_instance_id()), &"stone", 1, 1, {"climate": "grassland", "level": 1}, &"none", Color.GRAY, 2.8, 8.0, "Rock", false, units)
	return n

func _test_mining(T) -> void:
	T.reset()
	_basket = _place_basket(Vector3(8, 0.3, -6))
	_rock = _place_rock(Vector3(14, 0, -6), 40)
	var r = _member(T)
	r.equipment.put(&"weapon", IS.make(&"work_pick", 1, {"material_tier": "stone"}, 1))
	var tools = INV.new(1)
	tools.slots[0] = r.equipment.worn(&"weapon")
	var want: float = GS.unit_seconds_for(tools, _rock, 1)
	var bare: float = GS.unit_seconds_for(INV.new(1), _rock, 1)
	_expect(want < bare, "the pick is faster than bare hands on rock (%.2f < %.2f)" % [want, bare])
	T.set_job(r, &"mine", Vector3(12, 0, -6), _basket.global_position)
	await _settle(4)
	var body = _body(r)
	body.global_position = Vector3(10, 1.0, -4)
	Engine.time_scale = 4.0
	var carry_n := int(T.num("carry_units", 5.0))
	var t := 0
	while t < 60 * 120 and body.deposited < carry_n:
		await physics_frame
		t += 1
	Engine.time_scale = 1.0
	var inv = _basket.storage
	_expect(body.deposited >= carry_n and inv.count_of(&"stone") == body.deposited, "the member mined and deposited into the chest (%d deposited, chest %d)" % [body.deposited, inv.count_of(&"stone")])
	_expect(body.harvests.size() >= carry_n and body.harvests.all(func (h: Dictionary) -> bool: return int(h["count"]) == 1), "every harvest is exactly one item")
	# The first pass is at Gathering 1; later passes may be a little faster as the member levels up.
	_expect(absf(float(body.harvests[0]["seconds"]) - want) < 0.01 and body.harvests.all(func (h: Dictionary) -> bool: return float(h["seconds"]) <= want + 0.01), "passes take the tool's time %.2f s (first %.2f)" % [want, float(body.harvests[0]["seconds"]) if not body.harvests.is_empty() else -1.0])
	_expect(r.equipment.worn(&"weapon").durability < r.equipment.worn(&"weapon").max_durability or r.equipment.worn(&"weapon").max_durability <= 0, "the pick wore")
	_sections += 1

# ---------------------------------------------------------------- 7. eat and rest

func _test_eat_rest(T) -> void:
	var r = T.members[0] if not T.members.is_empty() else null
	var body = _body(r)
	if r == null or body == null:
		_expect(false, "no working member for eat/rest")
		_sections += 1
		return
	var inv = _basket.storage
	inv.add(IS.make(&"berries", 1, {}, 1))
	inv.add(IS.make(&"berries", 1, {}, 1))
	var berries: int = inv.count_of(&"berries")
	r.fullness = 10.0
	Engine.time_scale = 4.0
	var t := 0
	while t < 60 * 40 and body.meals == 0:
		await physics_frame
		t += 1
	_expect(body.meals >= 1 and inv.count_of(&"berries") == berries - body.meals and r.fullness > 10.0, "a hungry member ate from the chest (meals %d, fullness %.0f)" % [body.meals, r.fullness])
	r.fatigue = 80.0
	t = 0
	var rested := false
	while t < 60 * 60:
		await physics_frame
		t += 1
		if body.state == &"rest":
			rested = true
		if rested and body.state != &"rest":
			break
	Engine.time_scale = 1.0
	_expect(rested, "an exhausted member rests")
	_expect(r.fatigue <= T.num("rest_until", 10.0) + 3.0, "rest brought fatigue down (%.0f)" % r.fatigue)
	_sections += 1

# ---------------------------------------------------------------- 8. one job at a time

func _test_one_job(T) -> void:
	var r = T.members[0] if not T.members.is_empty() else _member(T)
	T.set_job(r, &"mine", Vector3.ZERO)
	T.set_job(r, &"chop", Vector3(1, 0, 1))
	_expect(r.order == &"work" and str(r.job["kind"]) == "chop", "a new job replaces the old one")
	T.set_order(r, &"follow")
	_expect(r.job.is_empty() and r.order == &"follow", "following ends the job (opportunity cost)")
	T.set_order(r, &"work")
	_expect(r.order == &"follow", "work with no job is refused")
	_expect(T.take_control(r) != "", "direct control is the M2 hook (refused in M1)")
	_sections += 1

# ---------------------------------------------------------------- 9. UI and badge

func _test_ui(T) -> void:
	T.reset()
	var hud: Node = get_first_node_in_group("hud")
	var rec = T.arrive()
	_expect(hud != null and hud.field.count(&"animals") >= 1, "a waiting recruit badges Animals")
	var screen = hud.open_tribe(rec)
	_expect(screen.visible and screen.selected == rec, "the Tribe screen opens on the recruit")
	T.members.append(T.make_recruit(T.rng))
	T.members.append(T.make_recruit(T.rng))
	screen.rebuild()
	var accept: Button = screen.find_child("Act_Accept", true, false)
	_expect(accept != null, "a recruit shows Accept")
	if accept:
		accept.pressed.emit()
		_expect(screen.last_refusal.contains("housing") and T.pending.has(rec), "Accept with a full house shows the reason")
	T.members.clear()
	screen.rebuild()
	accept = screen.find_child("Act_Accept", true, false)
	if accept:
		accept.pressed.emit()
	_expect(T.members.has(rec) and not T.pending.has(rec), "Accept on the screen joins the recruit")
	_expect(hud.field.count(&"animals") == 0, "the badge clears once nobody waits")
	screen.close_screen()
	_sections += 1
