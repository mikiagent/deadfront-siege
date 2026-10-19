extends Node3D
## PRD §24 test 2: two knives from different primaries do not merge. Locked combat knife skipped.
## M8e: station skewer craft + held-item slot screenshots.
## W1-ITEMS: full-bag refusal, refunds kept at the station, recipe switch refunds, weapon in hand.
## Headless run asserts every step, prints "[craft_lab] PASS" and exits 1 on any FAIL.

var _player: Player
var _bonfire: Bonfire
var _bench: CraftStation
var _cam: Camera3D
var _fails: Array[String] = []

func _check(ok: bool, label: String) -> void:
	print("[craft_lab] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fails.append(label)

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	_cam = kit["cam"]
	_spawn(&"thicket", Vector3(5, 0, 3), &"fibre_stalk", {"climate": "thicket"}, &"knife", Color(0.18, 0.4, 0.18))
	_spawn(&"tree", Vector3(8, 0, 3), &"wood_log", {}, &"axe", Color(0.35, 0.22, 0.12))
	_spawn(&"rock", Vector3(5, 0, 6), &"stone", {}, &"pick", Color(0.5, 0.5, 0.48))
	_bench = CraftStation.make(&"workbench")
	_bench.position = Vector3(-3, 0, 2)
	add_child(_bench)
	var rack := CraftStation.make(&"drying_rack")
	rack.position = Vector3(-3, 0, 5)
	add_child(rack)
	_bonfire = Bonfire.make()
	_bonfire.position = Vector3(2, 0, 2)
	add_child(_bonfire)
	print("[boot] lab=craft_lab")
	if Game.shot_path != "":
		call_deferred("_shot_setup")
		return
	if DisplayServer.get_name() == "headless":
		get_tree().create_timer(0.4).timeout.connect(_demo)

func _shot_setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Game.time_of_day = 0.88
	LabKit.give(_player, &"work_axe", 1)
	LabKit.give(_player, &"stone_knife_work", 1)
	LabKit.give(_player, &"work_pick", 1)
	_player.inventory.set_equipped_tool_index(_player.inventory.find_first(&"work_axe"))
	_player.global_position = _bonfire.global_position + Vector3(1.2, 0, 0.4)
	_player.face_world(_bonfire.global_position)
	if Game.shot_path.contains("weapon") or Game.shot_path.contains("gathertool"):
		_weapon_shot_setup(Game.shot_path.contains("weapon"))
		return
	if _player.anim:
		_player.anim.on_gather()
	if _player.station_craft:
		_player.station_craft._sync_hand_tool()
	if Game.shot_path.contains("held"):
		if _player.station_craft and _player.station_craft.held_slot:
			_player.station_craft.held_slot.refresh()
			_player.station_craft.held_slot.open_swap_for_shot()
			print("[ui] held-slot shot ready tools=%d" % _player.inventory.gather_tools_in_bag().size())
		return
	if Game.shot_path.contains("stmenu_bonfire"):
		_player.global_position = _bonfire.global_position + Vector3(1.6, 0, 0.6)
		_player.face_world(_bonfire.global_position)
		_player.open_station_craft(_bonfire)
		print("[ui] station-menu shot ready station=bonfire")
		return
	if Game.shot_path.contains("stmenu_open"):
		_player.global_position = _bench.global_position + Vector3(1.6, 0, 0.6)
		_player.face_world(_bench.global_position)
		_player.open_station_craft(_bench)
		if _player.station_craft and _player.station_craft.menu.visible:
			_player.station_craft.menu._on_pressed(&"craft")
		print("[ui] station-menu open shot ready craft_ui=%s" % (_player.craft_ui.visible if _player.craft_ui else "none"))
		return
	if Game.shot_path.contains("stmenu"):
		_player.global_position = _bench.global_position + Vector3(1.6, 0, 0.6)
		_player.face_world(_bench.global_position)
		_player.open_station_craft(_bench)
		print("[ui] station-menu shot ready station=workbench ring=%s craft_ui=%s" % [
			_player.station_craft.menu._ring3d != null and _player.station_craft.menu._ring3d.visible,
			_player.craft_ui.visible if _player.craft_ui else "none",
		])
		return
	# craft-card shot: mid-progress skewer card + fire glow
	LabKit.give(_player, &"raw_meat", 2)
	LabKit.give(_player, &"branch", 2)
	if _player.station_craft:
		_player.station_craft.station = _bonfire
		_player.station_craft.recipe_id = &"skewer"
		var rec := Crafting.recipe(&"skewer")
		_player.station_craft._picks = Crafting.default_picks(_player.inventory, rec)
		_player.station_craft._refund = Crafting.consume_for_craft(_player.inventory, rec, _player.station_craft._picks)
		_player.station_craft.crafting = true
		_player.station_craft.duration = 3.0
		_player.station_craft.progress = 0.45
		# Freeze the session so the 2.6 s shot delay does not finish/hide the card.
		_player.station_craft.set_process(false)
		_player.station_craft._show_card(rec)
		_player.station_craft.force_progress_for_shot(0.45)
		# Pin card on-screen for the acceptance shot (unproject can miss in labs).
		if _player.station_craft.card:
			var card := _player.station_craft.card
			card.follow_station = false
			card.set_anchors_preset(Control.PRESET_TOP_LEFT)
			card.position = Vector2(640, 280)
			card.reset_size()
			print("[ui] craft-card shot ready visible=%s size=%s pos=%s" % [
				card.visible,
				card.size,
				card.position,
			])

## Close shot of the right hand: club while a hunt target is set, the work axe otherwise.
func _weapon_shot_setup(hunting: bool) -> void:
	LabKit.give(_player, &"club", 1)
	_player.inventory.equip(&"weapon", &"club")
	_player.global_position = Vector3(0, 0, -4)
	var prey := _prey(_player.global_position + Vector3(4.0, 0, 3.0))
	_player.face_world(_player.global_position + Vector3(1, 0, -1))
	_player.hunt.target = prey if hunting else null
	_player.station_craft._sync_hand_tool()
	if _cam:
		_cam.size = 4.0
	print("[ui] weapon-hand shot ready hunting=%s held=%s" % [hunting, _player.station_craft.held_model_id()])

func _prey(at: Vector3) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = at
	c.spawn(Data.creature(&"velociraptor"), &"")
	c.set_physics_process(false)
	return c

func _demo() -> void:
	# Locked combat knife must never auto-equip for the thicket.
	var locked := ItemStack.make(&"stone_knife", 1)
	locked.set_flag(&"locked", true)
	_player.inventory.add(locked)
	var thicket: HarvestNode = null
	for n in get_tree().get_nodes_in_group("harvest"):
		if (n as HarvestNode).node_id == &"thicket":
			thicket = n as HarvestNode
			break
	if thicket:
		var why := thicket.can_gather(_player.inventory)
		print("[item] refused %s: %s" % [thicket.node_id, why if why != "" else "open"])
		_check(why == "need tool knife", "locked combat knife is never used for the thicket")
		_player._begin_gather(thicket)
	# Work knife auto-equips and the locked combat knife stays unused.
	LabKit.give(_player, &"stone_knife_work", 1)
	if thicket:
		thicket.depleted = false
		thicket.visible = true
		_player._begin_gather(thicket)
		if _player.gather_target:
			_player._gathering = true
			_player._gather_left = 0.0
			_player._finish_gather()
	_check(_player.inventory.count_of(&"fibre_stalk") > 0, "work knife gathers the thicket")
	# PRD §24 test 2: bone-blade vs stone-blade knives differ and do not merge.
	_player.inventory.add(ItemStack.make(&"raptor_bone", 1, {"hardness": 2, "tint": "#d4c4a8"}))
	_player.inventory.add(ItemStack.make(&"stone", 1, {"tint": "#8a8a8a"}))
	_player.inventory.add(ItemStack.make(&"branch", 4))
	_player.inventory.add(ItemStack.make(&"twine", 4))
	var knife_rec: Dictionary = Data.recipes.get(&"improvised_stone_knife", {})
	var bone_idx := _player.inventory.find_first(&"raptor_bone")
	var stone_idx := _player.inventory.find_first(&"stone")
	var handle_idx := _player.inventory.find_first(&"branch")
	var lash_idx := _player.inventory.find_first(&"twine")
	var bone_picks: Array[int] = [bone_idx, handle_idx, lash_idx]
	Crafting.craft(_player, knife_rec, bone_picks)
	handle_idx = _player.inventory.find_first(&"branch")
	lash_idx = _player.inventory.find_first(&"twine")
	var stone_picks: Array[int] = [stone_idx, handle_idx, lash_idx]
	Crafting.craft(_player, knife_rec, stone_picks)
	var bone_k: ItemStack = null
	var stone_k: ItemStack = null
	for s in _player.inventory.slots:
		if s == null or s.def_id != &"stone_knife_work":
			continue
		if int(s.attributes.get("hardness", 0)) >= 2:
			bone_k = s
		elif str(s.attributes.get("tint", "")) == "#8a8a8a":
			stone_k = s
	var merge := false
	if bone_k and stone_k:
		merge = bone_k.can_merge_with(stone_k)
	print("[craft] knives bone=%s stone=%s merge=%s bone_tint=%s stone_tint=%s" % [
		bone_k != null, stone_k != null, merge,
		bone_k.attributes.get("tint", "") if bone_k else "",
		stone_k.attributes.get("tint", "") if stone_k else "",
	])
	_check(bone_k != null and stone_k != null and not merge, "bone and stone knives craft and stay apart")
	_check(bone_k != null and bone_k.uid != "" and bone_k.origin == "craft", "a crafted knife carries identity and origin craft")
	_level_mean_demo(knife_rec)
	# Butcher a velociraptor corpse (JSON drops via butchering.json).
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = Vector3(2, 0, 2)
	c.spawn(Data.creature(&"velociraptor"), &"")
	c.health.take_damage(9999.0, _player)
	await get_tree().create_timer(0.15).timeout
	var corpse: Corpse = null
	for n in get_tree().get_nodes_in_group("corpse"):
		corpse = n as Corpse
		if corpse:
			break
	if corpse:
		corpse.butcher(_player)
	await _m8e_skewer_demo()
	_full_bag_craft()
	_station_cancel_full_bag()
	_recipe_switch_refunds()
	_weapon_in_hand()
	if DisplayServer.get_name() == "headless":
		if _fails.is_empty():
			print("[craft_lab] PASS")
		else:
			print("[craft_lab] FAIL count=%d" % _fails.size())
		get_tree().quit(0 if _fails.is_empty() else 1)

func _empty_bag() -> void:
	for i in _player.inventory.slot_count:
		_player.inventory.slots[i] = null
	_player.inventory.equipment.clear()
	_player.inventory.equipped_tool_index = -1

## Fill every empty slot with a stack nothing else merges with.
func _fill_bag() -> void:
	var lvl := 1
	while _player.inventory.used_slots() < _player.inventory.slot_count:
		_player.inventory.add(ItemStack.make(&"berry", 1, {}, lvl))
		lvl += 1

func _units() -> int:
	var n := 0
	for s in _player.inventory.slots:
		if s:
			n += s.count
	return n

func _full_bag_craft() -> void:
	_empty_bag()
	for id in [&"stone", &"branch", &"twine"]:
		_player.inventory.add(ItemStack.make(id, 2, {}, 1))
	_fill_bag()
	var before := _player.inventory.to_array()
	var rec := Crafting.recipe(&"improvised_stone_knife")
	var out := Crafting.craft(_player, rec, Crafting.default_picks(_player.inventory, rec))
	var hud := get_tree().get_first_node_in_group("hud")
	var notices := str(hud.get("_events").notices) if hud and hud.get("_events") else ""
	_check(out == null and _player.inventory.to_array() == before, "full bag: craft refused, inputs unchanged")
	_check(notices.contains("Bag is full"), "full bag: refusal notice shown")

func _station_cancel_full_bag() -> void:
	var sc := _player.station_craft
	_empty_bag()
	_player.inventory.add(ItemStack.make(&"raw_meat", 1, {}, 4))
	_player.inventory.add(ItemStack.make(&"branch", 1, {}, 4))
	_player.global_position = _bonfire.global_position + Vector3(0.8, 0, 0)
	sc.station = _bonfire
	sc._begin_recipe(&"skewer")
	_player.clear_nav()
	sc._start_craft_cycle()
	_check(sc.crafting and _player.inventory.count_of(&"raw_meat") == 0, "station craft consumed its inputs")
	_fill_bag()
	var bag_units := _units()
	sc.cancel_and_refund()
	var held: Array = _bonfire.get_meta(StationCraft.HELD_META, [])
	var held_units := 0
	for row in held:
		held_units += int(row.get("count", 0))
	_check(held_units == 2 and _units() == bag_units, "station cancel with a full bag keeps the refund in the station")
	_player.inventory.remove_at(_player.inventory.slot_count - 1, 1)
	_player.inventory.remove_at(_player.inventory.slot_count - 2, 1)
	var back := sc.collect_held(_bonfire)
	_check(back == 2 and _player.inventory.count_of(&"raw_meat") == 1 and _player.inventory.count_of(&"branch") == 1 and not _bonfire.has_meta(StationCraft.HELD_META), "held refund returns once there is room")

func _recipe_switch_refunds() -> void:
	var sc := _player.station_craft
	_empty_bag()
	_player.inventory.add(ItemStack.make(&"raw_meat", 2, {}, 4))
	_player.inventory.add(ItemStack.make(&"branch", 1, {}, 4))
	_player.global_position = _bonfire.global_position + Vector3(0.8, 0, 0)
	sc.station = _bonfire
	sc._begin_recipe(&"skewer")
	_player.clear_nav()
	sc._start_craft_cycle()
	var mid_meat := _player.inventory.count_of(&"raw_meat")
	sc._on_recipe_chosen(&"sashimi")
	_check(mid_meat == 1 and _player.inventory.count_of(&"raw_meat") == 2 and _player.inventory.count_of(&"branch") == 1 and not sc.crafting, "switching recipe mid-craft refunds the first recipe's inputs")
	sc.cancel_and_refund()

func _weapon_in_hand() -> void:
	var sc := _player.station_craft
	_empty_bag()
	LabKit.give(_player, &"club", 1)
	LabKit.give(_player, &"work_axe", 1)
	_player.inventory.equip(&"weapon", &"club")
	_player.inventory.set_equipped_tool_index(_player.inventory.find_first(&"work_axe"))
	var prey := _prey(_player.global_position + Vector3(12, 0, 0))
	_player.hunt.target = prey
	sc._sync_hand_tool()
	var hunting_id := sc.held_model_id()
	_player.hunt.target = null
	sc._sync_hand_tool()
	var calm_id := sc.held_model_id()
	print("[craft_lab] hand hunting=%s calm=%s" % [hunting_id, calm_id])
	_check(hunting_id == &"club" and calm_id == &"work_axe", "the hand shows the club while hunting and the axe otherwise")
	prey.queue_free()

func _m8e_skewer_demo() -> void:
	# First station interaction only expands the ring/action hex. The action callback is
	# the second interaction and is the only step allowed to open the craft sheet.
	_player.open_station_craft(_bench)
	var first_step_ok: bool = _player.station_craft.menu.visible and not _player.craft_ui.visible
	_player.station_craft.menu._on_pressed(&"craft")
	var second_step_ok: bool = not _player.station_craft.menu.visible and _player.craft_ui.visible
	print("[craft] station_two_tap first=%s second=%s" % [first_step_ok, second_step_ok])
	if _player.craft_ui:
		_player.craft_ui.hide()
	# Blocked: meat without stick/branch.
	_player.inventory.add(ItemStack.make(&"raw_meat", 1))
	# Clear branches so the missing-ingredient path fires.
	while _player.inventory.count_of(&"branch") > 0:
		var bi := _player.inventory.find_first(&"branch")
		if bi < 0:
			break
		_player.inventory.remove_at(bi, _player.inventory.slots[bi].count)
	var blocked := Crafting.missing_ingredient_name(_player.inventory, Crafting.recipe(&"skewer"))
	print("[craft] blocked skewer: needs %s" % (blocked if blocked != "" else "branch"))
	# Full craft via station session (arrive instantly).
	_player.inventory.add(ItemStack.make(&"branch", 2))
	_player.global_position = _bonfire.global_position + Vector3(0.8, 0, 0)
	if _player.station_craft:
		_player.station_craft.station = _bonfire
		_player.station_craft._begin_recipe(&"skewer")
		# Skip nav: force start.
		_player.clear_nav()
		_player.station_craft._start_craft_cycle()
		var wait := 3.4
		while wait > 0.0 and (_player.station_craft.crafting or _player.station_craft.queue_left > 0 or _player.station_craft.recipe_id != &""):
			await get_tree().create_timer(0.1).timeout
			wait -= 0.1
	_check(first_step_ok and second_step_ok, "station needs two taps before the craft sheet")
	_check(blocked != "", "skewer without a handle is blocked")
	_check(_player.inventory.count_of(&"skewer") > 0, "station skewer craft completes")

func _spawn(id: StringName, pos: Vector3, def_id: StringName, attrs: Dictionary, tool: StringName, color: Color) -> void:
	var n: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	n.position = pos
	add_child(n)
	n.setup(id, def_id, 1, 1, attrs, tool, color)

func _level_mean_demo(rec: Dictionary) -> void:
	# PRD 8.4: the mean of the materials, clamped by the skill; a master skill shows the mean.
	_player.skills.trees["weapon_tools"]["level"] = 60
	_craft_knife_at(rec, 25, 5, 15, 15)
	_craft_knife_at(rec, 25, 40, 31, 32)
	_player.skills.trees["weapon_tools"]["level"] = 0
	_craft_knife_at(rec, 25, 40, 31, 1)

func _craft_knife_at(rec: Dictionary, stone_lv: int, branch_lv: int, twine_lv: int, expected: int) -> void:
	var stone := ItemStack.make(&"stone", 1, {"tint": "#8a8a8a"}, stone_lv)
	stone.level = stone_lv
	var branch := ItemStack.make(&"branch", 1, {}, branch_lv)
	branch.level = branch_lv
	var twine := ItemStack.make(&"twine", 1, {}, twine_lv)
	twine.level = twine_lv
	_player.inventory.add(stone)
	_player.inventory.add(branch)
	_player.inventory.add(twine)
	var picks: Array[int] = [
		_find_id_level(&"stone", stone_lv),
		_find_id_level(&"branch", branch_lv),
		_find_id_level(&"twine", twine_lv),
	]
	var out := Crafting.craft(_player, rec, picks)
	print("[craft] knife expected=%d got=%d blade=%d branch=%d lashing=%d" % [
		expected, out.level if out else -1, stone_lv, branch_lv, twine_lv
	])
	_check(out != null and out.level == expected, "knife level %d from materials %d/%d/%d" % [expected, stone_lv, branch_lv, twine_lv])

func _find_id_level(id: StringName, lv: int) -> int:
	for i in _player.inventory.slot_count:
		var s := _player.inventory.slots[i]
		if s and s.def_id == id and s.level == lv:
			return i
	return _player.inventory.find_first(id)
