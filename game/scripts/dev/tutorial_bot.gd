extends BotSurvivor
## TUTORIAL ISLAND bot: plays every tutorial order with the real actions a player uses (tap a node
## and pick the wheel hex, craft through StationCraft, hunt and loot, Drink / Rest / Eat context
## actions, load wood, buy a skill node, place a kit, walk onto the dock, press the pick's buttons).
## BotSurvivor's helpers do the walking and gathering. t_tutorial drives run_steps headless;
## `-- --tutorial-bot [--tutorial-shots=<dir>]` runs it windowed from a new game and saves captures.

var shots_dir := ""
var log_prefix := "[tutorial-bot]"
## A failed order stops the run with this reason.
var failure := ""

## Windowed: make the survivor (the creation screen's own buttons), then play every order.
func run_windowed(host: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tutorial-shots="):
			shots_dir = a.substr(17)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	minutes = 60.0
	await get_tree().create_timer(1.5).timeout
	var cc := host.get_node_or_null("CharacterCreation") as CharacterCreation
	if cc:
		cc.select_occupation(str((SkillState.occupations()[0] as Dictionary).get("id", "")))
		cc.naming.field.text = "Tutor"
		cc._finish()
	await get_tree().create_timer(3.0).timeout
	player = PlayerRegistry.local()
	if player == null or not World.is_tutorial():
		print("%s FAIL no survivor on the tutorial island (island=%s)" % [log_prefix, World.island_id])
		get_tree().quit(1)
		return
	_last_pos = player.global_position
	await capture("01_spawn")
	var r := await run_steps(World.objective, Tutorial.steps().size())
	print("%s %s" % [log_prefix, "DONE" if r == "" else "FAIL " + r])
	get_tree().quit(0 if r == "" else 1)

## Plays tutorial orders [from, to). "" when each completed in order, else the reason it stopped.
func run_steps(from: int, to: int) -> String:
	var all := Tutorial.steps()
	for i in range(from, mini(to, all.size())):
		if World.objective > i:
			# Its condition already held when it became current (a fire that was burning anyway).
			print("%s step %2d %-13s OK (already true when it came up)" % [log_prefix, i + 1, str((all[i] as Dictionary).get("id", ""))])
			continue
		if World.objective != i:
			return "order %d expected to be running, World.objective=%d" % [i + 1, World.objective]
		var id := str((all[i] as Dictionary).get("id", ""))
		_goal = id
		var t0 := _t
		var why := ""
		# The island is live (a compsognathus can interrupt a craft): try an order up to 3 times, as a
		# player would, and fail with the last reason.
		for attempt in 3:
			why = await _do_step(id)
			if why == "":
				why = await _wait_done(i, 20.0)
			if why == "" or World.objective > i or not Tutorial.active():
				why = ""
				break
			print("%s step %2d %-13s retry after: %s" % [log_prefix, i + 1, id, why])
			await _beat(2.0)
		print("%s step %2d %-13s %s t=%.0fs took=%.0fs" % [log_prefix, i + 1, id, "OK" if why == "" else "FAIL " + why, _t, _t - t0])
		if why != "":
			failure = "step %d %s: %s" % [i + 1, id, why]
			return failure
		_receive_rewards()
	return ""

## TASKSCREEN: order rewards wait in Tasks > Main Task; a player presses Receive, so the bot does too
## (the XP's character levels lift the skill caps the hunt relies on), once tut_claim has taught it.
## The Task screen the way a player meets it: open it from the HUD, press the first Receive, OK, close.
func _claim_in_tasks() -> String:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("open_orders"):
		return "no HUD to open Tasks from"
	hud.call("open_orders")
	await _beat(0.5)
	var sheet: Node = hud.get("_orders_sheet")
	var rec := sheet.find_child("Receive", true, false) as Button if sheet else null
	if rec == null or not rec.is_visible_in_tree():
		return "Tasks shows no Receive button"
	var tgt := Tutorial.pointer_target(player)
	if not (tgt.get("ui") == rec):
		return "the pointer is not on Receive (%s)" % [tgt]
	rec.pressed.emit()
	await _beat(0.5)
	(sheet.get("_pop_ok") as Button).pressed.emit()
	sheet.call("close")
	return ""

func _receive_rewards() -> void:
	if not Tasks.claimed.keys().any(func (k: Variant) -> bool: return str(k).begins_with("main.")):
		return
	for r in Tasks.rows(&"main", player):
		if r["claimable"]:
			Tasks.claim(str(r["id"]), player)

func _wait_done(i: int, secs: float) -> String:
	var until := _t + secs
	while _t < until:
		if World.objective > i or not Tutorial.active():  # the last order ends the tutorial itself
			return ""
		await _beat(0.25)
	return "the order did not complete (%s)" % str(Objectives.current(player).get("progress", "?"))

func _do_step(id: String) -> String:
	match id:
		"tut_claim":
			return await _claim_in_tasks()
		"tut_camp":
			var guild: Variant = Tutorial.world_point(player, "guild")
			if guild == null:
				return "no guild in the town"
			var g := await _walk_to(guild as Vector3, 5.0)
			await _beat(0.8)
			await capture("02_guild_town")
			return g
		"tut_branches":
			return await _gather_to(&"branch", 3)
		"tut_stone":
			return await _gather_to(&"stone", 2)
		"tut_fibre":
			return await _gather_to(&"fibre_stalk", 4)
		"tut_drink":
			var water: Variant = Tutorial.nearest_fresh_water(player.global_position)
			if water == null:
				return "no fresh water within 260 m"
			var w := await _walk_to(water as Vector3, 0.6, func () -> bool: return WaterAccess.near_fresh(player.global_position))
			if w != "":
				return w
			if not WaterAccess.near_fresh(player.global_position):
				return "reached the bank but Drink is not offered (%s)" % player.global_position.snapped(Vector3.ONE)
			player.context_action("drink")
			await capture("02b_drink")
			await _beat(1.5)
			return ""
		"tut_eat":
			var g := await _gather_to(&"berries", 1)
			return g if g != "" else await _eat(&"berries")
		"tut_rest":
			await _beat(5.5)  # a fight or a hit within 5 s blocks resting, as for a player
			player.context_action("rest")
			await _beat(1.0)
			return ""
		"tut_twine":
			return "" if await _craft(Crafting.recipe(&"twine")) else "twine craft failed"
		"tut_knife":
			return await _make(&"improvised_stone_knife")
		"tut_axe":
			if player.inventory.count_of(&"twine") < 1:  # the hint's way: twist 2 more fibre
				var f := await _gather_to(&"fibre_stalk", 2)
				if f != "" or not await _craft(Crafting.recipe(&"twine")):
					return "no twine for the axe %s" % f
			return await _make(&"work_axe")
		"tut_dagger":
			if player.inventory.count_of(&"twine") < 1:  # the hint's way: twist 2 more fibre
				var f := await _gather_to(&"fibre_stalk", 2)
				if f != "" or not await _craft(Crafting.recipe(&"twine")):
					return "no twine for the dagger %s" % f
			return await _make(&"stone_knife")
		"tut_logs":
			return await _gather_to(&"wood_log", 2)
		"tut_hunt":
			return await _hunt_weak()
		"tut_butcher":
			return await _loot_corpse()
		"tut_fire":
			return await _light_fire()
		"tut_cook":
			var h := await _gather_to(&"herb_leaf", 1)
			if h != "":
				return h
			if player.inventory.count_of(&"branch") < 1:
				var b := await _gather_to(&"branch", 1)
				if b != "":
					return b
			var made := await _craft(Crafting.recipe(&"roled_herb_roast"))
			await capture("05_cook")
			return "" if made else "herb roast craft failed"
		"tut_meal":
			var e := await _eat(&"herb_buff_meal")
			await capture("06_meal_buff")
			return e
		"tut_skill":
			return _buy_skill()
		"tut_build":
			if player.inventory.count_of(&"twine") < 1:  # the hint's recipe: 3 fibre and 1 twine
				var f2 := await _gather_to(&"fibre_stalk", 5)
				if f2 != "" or not await _craft(Crafting.recipe(&"twine")):
					return "no twine for the bedroll %s" % f2
			var k := await _make(&"straw_roll_kit")
			if k != "":
				return k
			# Back to the camp: its landing claim is buildable land on any island.
			await _walk_to(World.runtime._camp_pos + Vector3(4.0, 0.0, 6.0), 2.0)
			var b2 := await _build(&"straw_roll")
			if b2 != "":
				var grid := World.runtime.build_grid as BuildGrid
				b2 += " (here: %s)" % grid.can_place(&"straw_roll", BuildGrid.tile_of(player.global_position), 0)
			await capture("07_build")
			return b2
		"tut_ferry":
			return await _ferry()
	return "no bot action for %s" % id

# ---------------------------------------------------------------- actions

func _walk_to(at: Vector3, reach: float, arrived: Callable = Callable()) -> String:
	player.nav_to(player._closest_nav_point(at))
	var until := _t + 60.0
	while _t < until:
		var d := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
		if d <= reach or (arrived.is_valid() and arrived.call()):
			player.clear_nav()
			return ""
		if not player.nav_active:
			player.nav_to(player._closest_nav_point(at))
		await _beat(0.25)
	return "could not walk to %s (%.0f m short, stopped at %s)" % [at.snapped(Vector3.ONE), player.global_position.distance_to(at), player.global_position.snapped(Vector3.ONE * 0.1)]

## Gather until the bag holds `n` (an earlier craft may have spent some).
func _gather_to(item: StringName, n: int) -> String:
	var why := ""
	for attempt in 6:
		var short := n - player.inventory.count_of(item)
		if short <= 0:
			return ""
		why = await _gather(item, short)
		if why != "":
			await _beat(1.0)  # an animation (drink, eat) still running refuses the walk; try again
	return "" if player.inventory.count_of(item) >= n else "still short of %s: %s" % [item, why]

## Gather what a recipe needs, then craft it.
func _make(rid: StringName) -> String:
	var rec := Crafting.recipe(rid)
	if rec.is_empty():
		return "no recipe %s" % rid
	var missing := await _acquire_for(rec)
	if missing != "":
		return missing
	return "" if await _craft(rec) else "%s craft failed" % rid

func _eat(item: StringName) -> String:
	for i in player.inventory.slot_count:
		var s := player.inventory.slots[i]
		if s != null and s.def_id == item:
			player.clear_nav()
			await _beat(0.3)
			if not player.begin_eat_slot(i):
				return "eating %s was refused" % item
			var until := _t + 12.0
			while _t < until and player.eat_session and player.eat_session.eating:
				await _beat(0.25)
			return ""
	return "no %s in the bag" % item

## The tutorial's weak animal: the nearest compsognathus a path reaches (never the zebraceratops).
## A target the route cannot reach for 20 s is dropped for the next, as a player would give up.
func _hunt_weak() -> String:
	var tried: Array = []
	for attempt in 4:
		var target := _reachable_compy(tried)
		if target == null:
			return "no reachable compsognathus (%d tried)" % tried.size()
		tried.append(target)
		player.hunt.start(target)
		var shot := false
		var until := _t + 60.0
		var last_gap := INF
		var stuck_since := _t
		while _t < until and is_instance_valid(target) and not target.health.dead:
			if get_tree().get_first_node_in_group("corpse") != null:
				break  # a retaliation (canon's hit-interrupt) can kill a different compy first: that carcass counts
			var gap := player.global_position.distance_to(target.global_position)
			if gap > 2.0 and not player.nav_active:
				player.nav_to(player._closest_nav_point(target.global_position))
			if gap < last_gap - 0.5:
				last_gap = gap
				stuck_since = _t
			elif _t - stuck_since > 20.0:
				break
			if not shot and gap < 4.0:
				shot = true
				await capture("03_fight")
			await _beat(0.25)
		if (is_instance_valid(target) and target.health.dead) or get_tree().get_first_node_in_group("corpse") != null:
			player.hunt.stop()
			return ""
		player.hunt.stop()
		player.clear_nav()
	return "no compsognathus died (%d tried)" % tried.size()

func _reachable_compy(skip: Array) -> Creature:
	var rt := World.runtime as IslandRuntime
	var best: Creature = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("creatures"):
		var c := node as Creature
		if c == null or c in skip or c.is_pet or c.health == null or c.health.dead or c.def == null or c.def.id != &"compsognathus" or c.is_alpha():  # ALPHAS: 3.9x HP is no first hunt
			continue
		var d := player.global_position.distance_to(c.global_position)
		if d >= best_d:
			continue
		if rt and rt.pathing:
			var pts: PackedVector3Array = rt.pathing.path(player.global_position, c.global_position, 0)
			if pts.is_empty() or not bool(rt.pathing.last_reachable):
				continue
		best_d = d
		best = c
	return best

func _loot_corpse() -> String:
	var corpse := get_tree().get_first_node_in_group("corpse") as Corpse
	if corpse == null:  # the hunt order was met by an earlier kill whose carcass is gone: hunt another
		var h := await _hunt_weak()
		if h != "":
			return h
		corpse = get_tree().get_first_node_in_group("corpse") as Corpse
	if corpse == null:
		return "no carcass"
	var w := await _walk_to(corpse.global_position, 2.2)
	if w != "":
		return w
	await _fight_off_attackers()
	if not is_instance_valid(corpse):
		return "carcass gone"
	w = await _walk_to(corpse.global_position, 2.2)
	if w != "":
		return w
	await _beat(5.5)  # a hit within the last seconds cancels a cut, as it does for a player
	player.context_action("loot")  # opens the part picker over the carcass (or the chest)
	await _beat(0.6)
	for attempt in 3:
		if player.inventory.count_of(&"raw_meat") + player.inventory.count_of(&"raptor_meat") > 0:
			break
		# The picker's Meat hex: ButcherPicker -> Corpse.begin_cut, a 1.6 s cut standing still.
		var why := corpse.begin_cut(&"raw_meat", player) if is_instance_valid(corpse) else "carcass gone"
		if why != "":
			return "meat cut refused: %s" % why
		await _beat(2.4)
	var pk := corpse.picker() if is_instance_valid(corpse) else null
	if pk:
		pk.visible = false
	if player.ui and player.ui.visible:
		player.ui.hide()
	return ""

## A wild animal that is after her cancels every cut (canon's hit-interrupt): fight it off first, as a
## player would. Up to 60 s; returns when nothing within 10 m is targeting her.
func _fight_off_attackers() -> void:
	var until := _t + 60.0
	while _t < until:
		var foe: Creature = null
		for node in get_tree().get_nodes_in_group("creatures"):
			var c := node as Creature
			if c and not c.is_pet and c.health and not c.health.dead and c.brain and c.brain.attack_target == player \
					and c.global_position.distance_to(player.global_position) < 10.0:
				foe = c
				break
		if foe == null:
			return
		player.hunt.start(foe)
		while _t < until and is_instance_valid(foe) and not foe.health.dead and foe.brain.attack_target == player:
			if foe.global_position.distance_to(player.global_position) > 2.0 and not player.nav_active:
				player.nav_to(player._closest_nav_point(foe.global_position))
			await _beat(0.25)
		player.hunt.stop()
		player.clear_nav()

## The stone fire pit's own public action (FIREPITS load_wood); before FIREPITS a pit always burns.
func _light_fire() -> String:
	var pit: Bonfire = null
	for n in get_tree().get_nodes_in_group("bonfire"):
		if n is Bonfire and (n as Bonfire).kind == &"stone_fire_pit":
			pit = n
	if pit == null:
		return "no stone fire pit on the island"
	var w := await _walk_to(pit.global_position, 2.4)
	if w != "":
		return w
	if pit.has_method("load_wood"):
		if player.inventory.count_of(&"branch") < 1:
			var b := await _gather_to(&"branch", 1)
			if b != "":
				return b
			await _walk_to(pit.global_position, 2.4)
		pit.call("load_wood", player)
	await capture("04_fire")
	return ""

## Learn the first affordable node with a cost, as the Skills sheet's Learn button does.
func _buy_skill() -> String:
	var sk := player.skills
	if sk == null:
		return "no skills"
	for tree in sk.trees.keys():
		for n in sk.nodes(str(tree)):
			if int((n as Dictionary).get("sp", 0)) <= 0:
				continue
			if str(sk.node_state(str(tree), n)[0]) == "available" and sk.unlock(str(tree), str((n as Dictionary).get("id", ""))):
				_event("skill", "%s / %s" % [tree, (n as Dictionary).get("id", "")])
				return ""
	return "no affordable skill node (SP %d)" % sk.sp_now()

## Walk onto the dock: the order opens the pick; press a shape card and SELECT AND MOVE.
func _ferry() -> String:
	var w := await _walk_to(World.runtime.arrival_point(), 4.0)
	if w != "":
		return w
	var until := _t + 20.0
	var pick: Node = null
	while _t < until and pick == null:
		await _beat(0.25)
		var ips := get_tree().get_nodes_in_group(&"island_pick")
		pick = ips[0] if not ips.is_empty() and (ips[0] as CanvasLayer).visible else null
	if pick == null:
		return "the Tamed Island pick never opened"
	await _beat(0.6)
	await capture("08_grant_pick")
	var card := pick.find_child("Shape_meadow", true, false) as Button
	var go := pick.find_child("SelectAndMove", true, false) as Button
	if card == null or go == null:
		return "the pick has no meadow card or SELECT AND MOVE"
	card.pressed.emit()
	go.pressed.emit()
	until = _t + 30.0
	while _t < until and not World.is_home():
		await _beat(0.25)
	if not World.is_home():
		return "SELECT AND MOVE did not ferry the survivor home"
	await _beat(2.5)
	await capture("09_home_arrival")
	return ""

func capture(tag: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 8:
		return
	var path := "%s/%s.png" % [shots_dir, tag]
	img.save_png(path)
	print("%s shot %s %dx%d" % [log_prefix, path, img.get_width(), img.get_height()])
