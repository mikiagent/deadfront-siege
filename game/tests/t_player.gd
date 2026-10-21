extends SceneTree
## W2-PLAYER acceptance: the survivor stands on the floor, rolls out of a swing toward the stick,
## HOLD and Auto-off still swing, F never picks a pet, pets keep their HP through dismiss and summon,
## Bag opens a pet's bag, full bags keep corpse loot and pet-bag overflow where they were, walking
## into small dinosaurs does not lift her, a summon is never launched, and footsteps + the ear exist.
## Usage: godot --headless --path game --script res://tests/t_player.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
## `godot --script` compiles this file before the autoloads exist, so game classes are loaded at
## run time and used untyped (the run_all.gd pattern).
var player
var data: Node
var PetRecordS: GDScript
var ItemStackS: GDScript
var InventoryS: GDScript
var CorpseS: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	PetRecordS = load("res://scripts/pets/pet_record.gd")
	ItemStackS = load("res://scripts/items/item_stack.gd")
	InventoryS = load("res://scripts/items/inventory.gd")
	CorpseS = load("res://scripts/creatures/corpse.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_player] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	host = Node3D.new()
	host.name = "TPlayer"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	# Camera behind +Z looking at the origin: move_up walks -Z, move_right walks +X.
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	var ui_layer := CanvasLayer.new()
	host.add_child(ui_layer)
	var inv_ui = (load("res://scenes/ui/inventory.tscn") as PackedScene).instantiate()
	ui_layer.add_child(inv_ui)
	player.ui = inv_ui
	inv_ui.bind(player.inventory, player)
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	await _test_grounded()
	await _test_roll()
	await _test_hold_and_manual_swing()
	await _test_f_skips_pets()
	await _test_pet_hp_and_summon()
	await _test_pet_menu_bag_feed_dump()
	await _test_corpse_full_bag()
	await _test_corpse_take_xp()
	await _test_no_creature_climb()
	await _test_footsteps_and_ear()
	_test_structure_interact()
	CombatTuning.reset_overrides()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_player] PASS")
		quit(0)
	else:
		print("[t_player] FAIL count=%d" % failures.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _creature(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # rules under test, not AI
	return c

func _clear_creatures() -> void:
	player.hunt.stop()
	for c in get_nodes_in_group("creatures"):
		c.queue_free()
	await process_frame

func _reset_at(pos: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = pos
	player.vitals.energy = player.vitals.max_energy
	await _frames(20)

## pc-anim-01: the rig's lowest bone sits on the floor at idle (was 0.95 m above it).
func _test_grounded() -> void:
	await _frames(40)
	var sk: Skeleton3D = player.rig.skeleton
	var low := INF
	for b in sk.get_bone_count():
		low = minf(low, (sk.global_transform * sk.get_bone_global_pose(b)).origin.y)
	print("[t_player] idle feet_y=%.3f lowest_bone_y=%.3f clip=%s" % [player.feet_position().y, low, player.anim.current_clip])
	_expect(player.is_on_floor() and absf(low) <= 0.05, "idle lowest bone within 0.05 m of the floor (%.3f m)" % low)

## pc-combat-01: roll 0.3 s into a swing is accepted 20/20, dashes along the stick, and the busy
## state ends with the dash; a roll mid-swing loses the swing's hit.
func _test_roll() -> void:
	var press := InputEventAction.new()
	press.action = &"roll"
	press.pressed = true
	var sticks: Array[StringName] = [&"move_right", &"move_left", &"move_up", &"move_down"]
	var accepted := 0
	var worst_dir := 1.0
	var worst_busy := 0.0
	for i in 20:
		await _reset_at(Vector3(0, 1.0, 0))
		player.play_attack()
		await create_timer(0.3, true, true).timeout
		var mid_swing: bool = player.anim._busy and player.anim.current_clip == &"attack_primary"
		Input.action_press(sticks[i % 4])
		var want: Vector3 = player.sim.cam_dir(player.sim.input_vector())
		player.controls.handle_unhandled(press)
		Input.action_release(sticks[i % 4])
		if not (mid_swing and player.rolling):
			continue
		accepted += 1
		await physics_frame
		worst_dir = minf(worst_dir, Vector3(player.velocity.x, 0, player.velocity.z).normalized().dot(want))
		var frames := 1
		var dash_end := -1
		var busy_end := -1
		while frames < 120 and (dash_end < 0 or busy_end < 0):
			await physics_frame
			frames += 1
			if dash_end < 0 and not player.rolling:
				dash_end = frames
			if busy_end < 0 and not player.anim._busy:
				busy_end = frames
		worst_busy = maxf(worst_busy, absf(busy_end - dash_end) / float(Engine.physics_ticks_per_second))
	_expect(accepted == 20, "roll accepted 0.3 s into an attack in %d of 20 tries" % accepted)
	_expect(worst_dir > 0.99, "dash follows the input vector (worst dot %.3f)" % worst_dir)
	_expect(worst_busy <= 0.05, "busy clears within 0.05 s of the dash end (worst %.3f s)" % worst_busy)
	player._sleep_left = 5.0
	_expect(player.sim.roll_refusal() == "Can't roll while resting.", "a refused roll says why (%s)" % player.sim.roll_refusal())
	player._sleep_left = 0.0
	# A real swing in reach, rolled out of at 0.3 s: its hit (due at ~0.39 s) is lost.
	await _reset_at(Vector3(0, 1.0, 0))
	CombatTuning.force_accuracy = 1.0
	CombatTuning.force_dodge = 0.0
	var dummy = _creature(&"velociraptor", Vector3(0, 0, -1.4))
	var hits := [0]
	var count := func (_t) -> void: hits[0] += 1
	player.hunt.hit_landed.connect(count)
	player.hunt.auto = false
	player.hunt.start(dummy)
	var swung: bool = player.hunt.swing_now()
	await create_timer(0.3, true, true).timeout
	Input.action_press(&"move_right")
	player.controls.handle_unhandled(press)
	Input.action_release(&"move_right")
	await create_timer(0.6, true, true).timeout
	_expect(swung and hits[0] == 0, "rolling out of a swing loses its hit (swung=%s hits=%d)" % [swung, hits[0]])
	player.hunt.hit_landed.disconnect(count)
	player.hunt.auto = true
	await _clear_creatures()

## pc-combat-04: HOLD with a target in reach lands at least one hit per swing period; Auto off,
## F (attack) still swings.
func _test_hold_and_manual_swing() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	CombatTuning.force_accuracy = 1.0
	CombatTuning.force_dodge = 0.0
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -1.4))
	raptor.health.max_hp = 1.0e6
	raptor.health.hp = 1.0e6
	var hits := [0]
	var count := func (_t) -> void: hits[0] += 1
	player.hunt.hit_landed.connect(count)
	player.hunt.hold = true
	player.hunt.start(raptor)
	var window := 4.5
	await create_timer(window, true, true).timeout
	var period := 1.0  # unarmed attack_rate 1.0 -> one swing per second (Hunt.begin_swing)
	_expect(hits[0] >= int(window / period), "HOLD in reach: %d hits in %.1f s (period %.1f s)" % [hits[0], window, period])
	player.hunt.hold = false
	player.hunt.auto = false
	await create_timer(1.1, true, true).timeout
	hits[0] = 0
	var attack := InputEventAction.new()
	attack.action = &"attack"
	attack.pressed = true
	player.controls.handle_unhandled(attack)
	await create_timer(0.6, true, true).timeout
	_expect(hits[0] == 1, "Auto off: F swings and lands once (%d)" % hits[0])
	player.hunt.auto = true
	player.hunt.hit_landed.disconnect(count)
	await _clear_creatures()

## pc-bug-01: F with only a pet nearby starts no hunt.
func _test_f_skips_pets() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	var pet = _creature(&"velociraptor", Vector3(1.5, 0, 0))
	pet.is_pet = true
	var attack := InputEventAction.new()
	attack.action = &"attack"
	attack.pressed = true
	player.controls.handle_unhandled(attack)
	_expect(player.hunt.target == null, "F with only a pet nearby starts no hunt")
	# Online (W3 stub): the verb becomes an act.attack intent and nothing changes locally.
	var wild = _creature(&"velociraptor", Vector3(-1.5, 0, 0))
	player.actions.online = true
	player.controls.handle_unhandled(attack)
	player.actions.online = false
	var last: Dictionary = player.actions.sent.back() if not player.actions.sent.is_empty() else {}
	_expect(str(last.get("op", "")) == "act.attack" and int(last["a"]["net_id"]) == wild.get_instance_id() and player.hunt.target == null,
		"online F sends act.attack and applies nothing locally (%s)" % [last])
	# A fresh tame runs become_pet before bonded.append: it already has an owner, a wild one never.
	var reg: GDScript = load("res://scripts/core/player_registry.gd")
	var fresh = _creature(&"compsognathus", Vector3(0, 0, 2.0))
	fresh.become_pet(PetRecordS.new())
	_expect(reg.owner_of(fresh) == player and reg.owner_of(wild) == null and reg.credit_for(wild) == null,
		"an unbonded fresh tame belongs to the local survivor, a wild animal to nobody")
	await _clear_creatures()

func _out_for(rec):
	for c in player.live_pets():
		if c.pet_record == rec:
			return c
	return null

## tame-11 + phys-spawn-01: a pet dismissed at 40 % comes back at 40 %; a summon is placed before
## it enters the tree, so a block at the parent's origin (where it used to appear) cannot launch it.
func _test_pet_hp_and_summon() -> void:
	var block := StaticBody3D.new()
	var bs := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = Vector3(1.5, 1.5, 1.5)
	bs.shape = bb
	block.add_child(bs)
	block.position = Vector3(0, 0.75, 0)
	host.add_child(block)
	await _reset_at(Vector3(4, 1.0, 4))
	var rec = PetRecordS.from_def(data.creature(&"velociraptor"), &"A")
	player.bonded.append(rec)
	var idx: int = player.bonded.size() - 1
	player.summon_pet(idx)
	var c = _out_for(rec)
	var fast := 0.0
	for i in 60:
		await physics_frame
		if is_instance_valid(c):
			fast = maxf(fast, c.velocity.length())
	_expect(c != null and fast <= 15.0, "summon at the origin: top pet speed %.1f m/s" % fast)
	c.health.hp = c.health.max_hp * 0.4
	player.summon_pet(idx)  # dismiss
	await process_frame
	player.summon_pet(idx)  # summon again
	var back = _out_for(rec)
	_expect(back != null and absf(back.health.fraction() - 0.4) < 0.01, "dismissed at 40 %%, summoned back at %.0f %%" % (back.health.fraction() * 100.0 if back else -1.0))
	player.summon_pet(idx)
	player.bonded.erase(rec)
	block.queue_free()
	await process_frame

## tame-13, tame-16, build-storage-01: the pet menu offers Bag on a protoceratops (a mount with a
## bag), Bag opens that bag, Feed reaches the pet whose menu was opened (not just the first one),
## and a bag dump into full storage keeps what did not fit.
func _test_pet_menu_bag_feed_dump() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	var raptor_rec = PetRecordS.from_def(data.creature(&"velociraptor"), &"A")
	var proto_rec = PetRecordS.from_def(data.creature(&"protoceratops"), &"A")
	player.bonded.append(raptor_rec)
	player.bonded.append(proto_rec)
	player.summon_pet(player.bonded.size() - 1)  # the protoceratops is out first
	player.summon_pet(player.bonded.size() - 2)
	await physics_frame
	var raptor = _out_for(raptor_rec)
	var proto = _out_for(proto_rec)
	var ids: Array = []
	for e in player.pets.entries(proto):
		ids.append(e["id"])
	_expect(&"ride" in ids and &"bag" in ids and &"feed" in ids and &"orders" in ids, "protoceratops menu: %s" % [ids])
	player.pets.interact(proto)
	_expect(player.pets.menu.visible and player.mounted_on == null, "tapping a mount pet opens its menu instead of mounting it")
	player.pets._on_menu(proto, &"bag")
	_expect(player.ui.visible and player.ui.pet_bag == proto_rec.bag, "Bag opens the protoceratops's bag")
	player.ui.visible = false
	# Feed: the menu was opened on the raptor, the second pet out (the first, a herbivore, refuses meat).
	player.inventory.add(ItemStackS.make(&"raw_meat", 1))
	player.pets.interact(raptor)
	player.pets.menu.hide_menu()
	raptor.hunger = 1.0
	var slot: int = player.inventory.find_first(&"raw_meat")
	player.feed_summoned_pet_slot(slot)
	_expect(raptor.hunger > 1.0, "feeding reaches the focused pet, not only the first summoned (hunger %.1f)" % raptor.hunger)
	# Dump into a one-slot store: one stack moves, the other stays in the pet's bag.
	proto_rec.bag.add(ItemStackS.make(&"stone", 1))
	proto_rec.bag.add(ItemStackS.make(&"branch", 1))
	var store = InventoryS.new(1)
	var moved: int = player.pets.dump_bag_into(proto, store)
	_expect(moved == 1 and proto_rec.bag.used_slots() == 1 and store.used_slots() == 1, "pet bag dump keeps the overflow (moved %d, kept %d)" % [moved, proto_rec.bag.used_slots()])
	player.summon_pet(player.bonded.find(raptor_rec))
	player.summon_pet(player.bonded.find(proto_rec))
	player.bonded.erase(raptor_rec)
	player.bonded.erase(proto_rec)
	await process_frame

## sec-loss-08 + sec-xpfarm-07: a radial take with a full bag leaves the stack in the corpse and
## pays no XP; with room it moves and pays Butchering XP once.
func _test_corpse_full_bag() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	var corpse = CorpseS.new()
	host.add_child(corpse)
	corpse.global_position = Vector3(1.2, 0, 0)
	corpse.loot.add(ItemStackS.make(&"raw_meat", 3))
	var slot: int = corpse.loot.find_first(&"raw_meat")
	var bag = player.inventory
	player.inventory = InventoryS.new(1)
	player.inventory.add(ItemStackS.make(&"stone", 1))
	var xp0: float = player.skills.xp_of("butchering")
	player._begin_corpse_take(corpse, slot)
	player._on_arrived()
	var take_s: float = (load("res://scripts/player/player_actions.gd") as GDScript).get_script_constant_map()["CORPSE_TAKE_SECONDS"]
	await create_timer(take_s + 0.3, true, true).timeout
	var left = corpse.loot.slots[slot]
	_expect(left != null and corpse.loot.count_of(&"raw_meat") == 3 and is_equal_approx(player.skills.xp_of("butchering"), xp0), "full bag: the meat stays in the corpse, no XP (count %d)" % corpse.loot.count_of(&"raw_meat"))
	player.inventory = bag
	var moved: int = player.actions.loot(corpse, slot)
	# W2-INV: three meat are three instances; a take moves the one in its slot.
	_expect(moved == 1 and corpse.loot.slots[slot] == null and is_equal_approx(player.skills.xp_of("butchering") - xp0, 3.0), "with room: moved %d, XP +%.0f once" % [moved, player.skills.xp_of("butchering") - xp0])
	corpse.queue_free()
	await process_frame

## W2-INV review 2: corpse loot is one instance per unit, so a flat +3 per take paid per unit.
## Butchering XP is 3 per drop kind, the first time any of it leaves the corpse: radial takes,
## chest takes of each item and Take all pay the same.
func _test_corpse_take_xp() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	if not player.inventory.has_tool_class(&"knife"):
		player.inventory.add(ItemStackS.make(&"stone_knife_work", 1))
	var paid: Array = []
	for way in ["radial", "chest", "take_all"]:
		var corpse = CorpseS.new()
		host.add_child(corpse)
		corpse.global_position = Vector3(1.2, 0, 0)
		corpse.loot.add_growing(ItemStackS.make(&"raw_meat", 3))
		corpse.loot.add_growing(ItemStackS.make(&"raptor_hide", 2))
		var xp0 := _butchering_total()
		if way == "radial":
			for i in corpse.loot.slot_count:
				if corpse.loot.slots[i]:
					player.actions.loot(corpse, i)
		else:
			corpse.open_loot(player)
			if way == "chest":
				for i in corpse.loot.slot_count:
					if corpse.loot.slots[i]:
						player.ui._take_storage(i)
			else:
				player.ui._take_all_storage()
			player.ui.hide_ui()
		paid.append(snappedf(_butchering_total() - xp0, 0.01))
		_expect(corpse.loot.used_slots() == 0, "%s takes every loot instance (left %d)" % [way, corpse.loot.used_slots()])
		corpse.queue_free()
	_expect(paid == [6.0, 6.0, 6.0], "radial takes, chest takes and Take all each pay 3 per drop kind (paid %s)" % [paid])
	await process_frame

## Butchering XP earned in all, across level-ups (xp_of is the XP into the current level).
func _butchering_total() -> float:
	var n: float = player.skills.xp_of("butchering")
	for l in player.skills.level_of("butchering"):
		n += player.skills.xp_to_next(l)
	return n

## phys-climb-01: a tap-to-walk route straight through a compsognathus, zebraceratops and
## velociraptor, held for 5 s, raises her at most 0.15 m (was +0.97, +1.16 and +1.82 m: the stall
## fallback hopped her onto their backs); unstick never steps into a creature.
func _test_no_creature_climb() -> void:
	for sp: StringName in [&"compsognathus", &"zebraceratops", &"velociraptor"]:
		await _reset_at(Vector3(0, 1.0, 10))
		var c = _creature(sp, Vector3(0, 0, 7))
		await _frames(10)
		var y0: float = player.global_position.y
		var top := y0
		var touched := false
		for i in 300:
			if not player.nav_active:
				player.nav_to(Vector3(0, 1.0, 0))  # the goal is behind the animal
			await physics_frame
			top = maxf(top, player.global_position.y)
			for k in player.get_slide_collision_count():
				touched = touched or player.get_slide_collision(k).get_collider() == c
		player.clear_nav()
		_expect(touched and top - y0 <= 0.15, "routed into a %s for 5 s (contact=%s) raises her %.2f m" % [sp, touched, top - y0])
		var stepped: bool = player.sim.unstick((c.global_position - player.global_position).normalized())
		_expect(not stepped or not _inside_creature(), "unstick toward a %s does not step into it" % sp)
		await _clear_creatures()

func _inside_creature() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := player.get_node("Shape") as CollisionShape3D
	q.shape = shape.shape
	q.transform = player.global_transform * shape.transform
	q.exclude = [player.get_rid()]
	for row in player.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var col = row.get("collider")
		if col is Node and col.is_in_group("creatures"):
			return true
	return false

## audio-footsteps-08 + audio-spatial-12: walking emits footsteps; the ear is current at head height.
func _test_footsteps_and_ear() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	var steps := [0]
	var count := func (_foot: int, _surface: int, _speed: float) -> void: steps[0] += 1
	player.footstep.connect(count)
	Input.action_press(&"move_right")
	await create_timer(2.0, true, true).timeout
	Input.action_release(&"move_right")
	player.footstep.disconnect(count)
	_expect(steps[0] >= 8, "2 s of walking emitted %d footsteps" % steps[0])
	var ear = player.view.listener
	var above: float = ear.global_position.y - player.feet_position().y if ear else -1.0
	var want: float = (load("res://scripts/player/player_view.gd") as GDScript).get_script_constant_map()["EAR_ABOVE_FEET"]
	_expect(ear != null and ear.is_current() and absf(above - want) < 0.05, "AudioListener3D current, %.2f m above her feet" % above)

## build-gate-01: a structure's own interact() runs before the generic building handling.
func _test_structure_interact() -> void:
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar hits := 0\nfunc interact(_p) -> bool:\n\thits += 1\n\treturn true\n"
	s.reload()
	var gate: Node3D = s.new()
	host.add_child(gate)
	player.actions.building_interact(gate)
	_expect(int(gate.get("hits")) == 1, "a tapped structure's interact() runs")
	gate.queue_free()
