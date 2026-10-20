extends Node3D
## W2-GATHER play session on the home island: the survivor gathers fibre, branches and stone
## bare-handed, then with stone tools (faster, logs unlocked), finds a rare berry seed, butchers a raptor
## by knife, and watches a node deplete and regrow. Every unit goes through PlayerActions.
## GAUNTLET gather rules checked on every pass: walked into reach (no teleport), the progress
## ring above the node, movement cancels, starter-island finds are level 1.
## Shots: --shot=<path.png> --shot-delay=900 saves <path>-<stage>.png per stage.

var _p: Player
var _fails: Array[String] = []
var _shot_base := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_base = a.substr(7).trim_suffix(".png")
	var kit := LabKit.build(self, 24.0)
	_p = kit["player"]
	Game.max_creatures_per_island = 0
	Game.debug_overlay = false
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 12), false)
	var floor := get_node_or_null("Nav/Floor")
	if floor:
		floor.queue_free()
	await get_tree().create_timer(0.6).timeout
	var rt: Node3D = World.runtime
	# Off the home camp so its station labels do not sit on the yield popups.
	var base := _p.global_position + Vector3(9.0, 0.0, 7.0)
	_p.global_position = base + Vector3(0.0, 0.0, 1.5)
	var bush := _plant(rt, "Bush", "glab_bush", base + Vector3(-3.0, 0, -3.0))
	var tree := _plant(rt, "CommonTree", "glab_tree", base + Vector3(0.0, 0, -4.0))
	var rock := _plant(rt, "Rock", "glab_rock", base + Vector3(3.0, 0, -3.0))
	for b in rt._batches:
		b.commit()
	for n in rt._harvest_nodes.values():
		n.refresh_batched_visual()
	var cam: IsoCamera = kit["cam"]
	cam.size = 11
	cam._snap()
	_empty_bag()
	await get_tree().create_timer(0.5).timeout

	# 1. Bare hands: fibre, branches, loose stone. Logs refuse without an axe.
	var hand := {}
	hand["fibre"] = await _gather(bush, &"fibre_stalk", 2, "")
	hand["branch"] = await _gather(tree, &"branch", 2, "hands")
	hand["stone"] = await _gather(rock, &"stone", 2, "")
	var log_why := tree.can_gather(_p.inventory) if _select(tree, &"wood_log") else "no log option"
	_check(log_why != "", "logs refuse bare hands (got '%s')" % log_why)
	print("[gather_lab] hands s/unit fibre %.2f branch %.2f stone %.2f; log refusal '%s'" % [hand["fibre"], hand["branch"], hand["stone"], log_why])

	# 2. Stone tools: the role's tool works each node faster, and an axe unlocks logs.
	# ASSUMPTION: the lab hands over the starter tools; the craft loop itself is craft_lab's proof.
	LabKit.give(_p, &"stone_knife_work", 1)
	LabKit.give(_p, &"work_axe", 1)
	LabKit.give(_p, &"work_pick", 1)
	var tool := {}
	tool["fibre"] = await _gather(bush, &"fibre_stalk", 2, "")
	tool["branch"] = await _gather(tree, &"branch", 2, "")
	tool["stone"] = await _gather(rock, &"stone", 2, "")
	var logs_before := _p.inventory.count_of(&"wood_log")
	tool["log"] = await _gather(tree, &"wood_log", 1, "tools")
	print("[gather_lab] tools s/unit fibre %.2f branch %.2f stone %.2f log %.2f" % [tool["fibre"], tool["branch"], tool["stone"], tool["log"]])
	_check(_p.inventory.count_of(&"wood_log") > logs_before, "a stone axe gathers logs")
	for k in ["fibre", "branch", "stone"]:
		_check(tool[k] < hand[k], "%s is faster with the stone tool (%.2f < %.2f)" % [k, tool[k], hand[k]])

	# 2b. Movement cancels: a move input mid-pass stops the cycle and no further unit lands.
	await _move_cancels(bush)

	# A pet beside the survivor, so the rare shot shows its plate next to the popups.
	_summon_pet()

	# 3. Rare find at the real data odds. Home grassland finds are its own materials (world-design s4:
	# no flint or copper here), so the bush gives a berry seed. The seed is picked so the very next
	# fibre unit rolls a find (the odds themselves are measured in t_gather).
	GatherService.rng.seed = _lucky_seed(bush, &"berry_seed")
	var seeds_before := _p.inventory.count_of(&"berry_seed")
	await _gather(bush, &"fibre_stalk", 1, "rare", 0.35)
	_check(_p.inventory.count_of(&"berry_seed") > seeds_before, "a rare berry seed landed in the bag")
	# The touch flow: tap the bush, pick Fibre on the radial; the picked hex shows the progress.
	GatherService.rng.seed = _lucky_seed(bush, &"berry_seed")
	seeds_before = _p.inventory.count_of(&"berry_seed")
	await _gather(bush, &"fibre_stalk", 1, "rare_radial", 0.35, true)
	_check(_p.inventory.count_of(&"berry_seed") > seeds_before, "a rare berry seed landed through the radial")
	_check(_p.inventory.count_of(&"flint") == 0 and _p.inventory.count_of(&"copper_ore") == 0, "no flint or copper off home-grassland rock")
	for st in _p.inventory.slots:
		if st and st.def_id in [&"berry_seed", &"fibre_stalk", &"branch", &"stone", &"wood_log"]:
			_check(st.level == 1, "starter-island %s is level 1 (got %d)" % [st.def_id, st.level])

	# 4. Butcher a raptor with the stone knife: meat, hide, bone scale with the knife.
	await _butcher()

	# 5. Deplete and regrow.
	_deplete_and_regrow(bush)

	print("[gather_lab] bag %s" % _bag_summary())
	if _fails.is_empty():
		print("[gather_lab] PASS")
	else:
		for f in _fails:
			print("[gather_lab] FAIL %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)

## Climate and level come from the island, as scatter plants them (so the level-1 check is real).
func _plant(rt: Node3D, family: String, id: String, pos: Vector3) -> HarvestNode:
	rt._plant_at(family, id, pos, &"fibre_stalk", &"none", rt._climate, rt.material_level(pos, rt._tier), Color.GREEN)
	return rt._harvest_nodes[id]

func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails.append(label)

func _empty_bag() -> void:
	for i in _p.inventory.slot_count:
		_p.inventory.slots[i] = null

func _select(node: HarvestNode, item: StringName) -> bool:
	var opts := node.options()
	for i in opts.size():
		if StringName(str(opts[i]["item"])) == item:
			node.select_option(i)
			return true
	return false

func _option(node: HarvestNode, item: StringName) -> int:
	var opts := node.options()
	for i in opts.size():
		if StringName(str(opts[i]["item"])) == item:
			return i
	return -1

## Gather `units` passes of `item` through PlayerActions; returns measured seconds per pass
## (the walk is excluded: timing starts when the first pass lands).
func _gather(node: HarvestNode, item: StringName, units: int, shot: String, shot_after: float = 0.25, via_radial: bool = false) -> float:
	var idx := _option(node, item)
	if idx < 0:
		_fails.append("%s has no %s option" % [node.family, item])
		return 0.0
	var passes := 0
	var started := -1.0
	var last := _p.inventory.count_of(item)
	var prev := _p.global_position
	var max_step := 0.0
	var ring_above := false
	if via_radial:
		_p._gather_radial.open(node, node.options(), _p.inventory)
		_p._gather_radial._on_pick(idx)
	else:
		_p.actions.gather(node, idx)
	var deadline := Time.get_ticks_msec() + 30000
	while passes < units and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		max_step = maxf(max_step, _p.global_position.distance_to(prev))
		prev = _p.global_position
		ring_above = ring_above or _ring_above(node) or (via_radial and _p._gather_radial.is_open() and _p._gather_radial.active_index == idx)
		var now := _p.inventory.count_of(item)
		if now > last:
			passes += 1
			last = now
			if started < 0.0:
				started = _now()
				var reach := Vector2(_p.global_position.x - node.global_position.x, _p.global_position.z - node.global_position.z).length()
				_check(reach <= 3.2, "%s gathered from reach (%.2f m)" % [item, reach])
	# GAUNTLET: gathering is from reach without teleport; progress appears above the node.
	_check(max_step < 1.0, "%s: the survivor walked to the node (largest frame step %.2f m)" % [item, max_step])
	_check(ring_above, "%s: the progress ring (or the picked radial hex) showed" % item)
	var per := (_now() - started) / float(maxi(1, passes - 1)) if passes > 1 else GatherService.unit_seconds(_p, node)
	if passes < units:
		_fails.append("gathered %d/%d %s" % [passes, units, item])
	if shot != "":
		await get_tree().create_timer(shot_after).timeout
		_popup_clear(node)
	# Stop before the capture: a slow windowed frame would otherwise keep the cycle running.
	_p.actions.cancel_work()
	if shot != "":
		await _capture(shot)
	return per

## The floating progress ring is up and drawn above the node's base on screen.
func _ring_above(node: HarvestNode) -> bool:
	var ring: GatherRing = _p._gather_ring
	var cam := get_viewport().get_camera_3d()
	return ring != null and cam != null and ring.visible and ring.target == node \
			and ring._screen_pos.y < cam.unproject_position(node.global_position).y

## The live "+n" stack sits clear of the ring, HUD text and zones, plates and the radial.
func _popup_clear(node: HarvestNode) -> void:
	if DisplayServer.get_name() == "headless":
		return  # no real screen layout headless: the windowed runs check placement
	var layer := get_tree().current_scene.get_node_or_null(GatherFeedback.LAYER_NAME)
	var box: Control = layer.get_child(layer.get_child_count() - 1) if layer and layer.get_child_count() > 0 else null
	_check(box != null and box.visible, "a yield popup showed over %s" % node.family)
	if box == null:
		return
	var a := get_viewport().get_camera_3d().unproject_position(node.global_position + Vector3(0, node.top_of_node() + 0.3, 0))
	var r := box.get_global_rect()
	var texts := []
	for l in box.get_children():
		texts.append((l as Label).text)
	# Hard limits only: nature-node pills may give way when nothing else is free (gather_feedback.gd).
	var taken := GatherFeedback.taken_rects(_p, a, false)
	taken.append_array(UiTokens.hud_reserved(get_viewport().get_visible_rect().size))
	for t in taken:
		_check(not r.intersects(t), "popup %s at %s clear of %s" % [texts, r, t])
	print("[gather_lab] popup %s at %s" % [texts, r])

func _move_cancels(node: HarvestNode) -> void:
	var idx := _option(node, &"fibre_stalk")
	_p.actions.gather(node, idx)
	var deadline := Time.get_ticks_msec() + 15000
	while not _p._gathering and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	Input.action_press("move_down")
	await get_tree().create_timer(0.25).timeout
	Input.action_release("move_down")
	var after := _p.inventory.count_of(&"fibre_stalk")
	_check(not _p._gathering and _p.gather_target == null, "a move input cancels the gather")
	await get_tree().create_timer(GatherService.unit_seconds(_p, node) * 1.5).timeout
	_check(_p.inventory.count_of(&"fibre_stalk") == after, "no unit lands after the move cancelled the gather")
	print("[gather_lab] move cancels: gathering=%s fibre %d" % [_p._gathering, _p.inventory.count_of(&"fibre_stalk")])

func _summon_pet() -> void:
	var rec := PetRecord.new()
	rec.species = &"velociraptor"
	rec.hp = Data.creature(&"velociraptor").hp
	_p.bonded.append(rec)
	_p.summon_pet(_p.bonded.size() - 1)
	for pet in _p.summoned_pets:
		Game.reveal_creature_plate(pet, 60.0)

func _now() -> float:
	return float(Time.get_ticks_msec()) * 0.001

## First seed whose first rare roll on this node lands `item` with the held tool.
func _lucky_seed(node: HarvestNode, item: StringName) -> int:
	var tool := GatherService.effective_tool(_p.inventory, node)
	var tier: StringName = tool.material_tier() if tool else &""
	var skill := maxi(1, _p.skills.level_of("gathering")) if _p.skills else 1
	var probe := RandomNumberGenerator.new()
	for s in range(1, 5000):
		probe.seed = s
		if LootRoller.roll_gather_rares(node.family, GatherService.role_of(node), str(node.yield_attributes.get("climate", "")), tier, skill, probe).has(item):
			return s
	return 1

func _butcher() -> void:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = _p.global_position + Vector3(1.6, 0, 1.2)
	c.spawn(Data.creature(&"velociraptor"), &"")
	await get_tree().create_timer(0.3).timeout
	c.health.take_damage(9999.0, _p)
	await get_tree().create_timer(0.4).timeout
	var corpse: Corpse = null
	for n in get_tree().get_nodes_in_group("corpse"):
		corpse = n as Corpse
		if corpse:
			break
	_check(corpse != null, "the kill leaves a corpse")
	if corpse == null:
		return
	var parts := []
	for st in corpse.loot.slots:
		if st:
			parts.append("%s x%d L%d" % [st.def_id, st.count, st.level])
	print("[gather_lab] raptor carcass (stone knife): %s" % ", ".join(parts))
	_p.actions.open_corpse_loot(corpse)
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline and not (_p.ui and _p.ui.visible):
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _capture("loot_screen")
	if _p.ui:
		_p.ui.hide_ui()
	var took := 0
	for i in corpse.loot.slot_count:
		if corpse.loot.slots[i]:
			took += _p.actions.loot(corpse, i)
	await get_tree().create_timer(0.3).timeout
	await _capture("butcher")
	_check(_p.inventory.count_of(&"raptor_meat") > 0 and _p.inventory.count_of(&"raptor_hide") > 0 and _p.inventory.count_of(&"raptor_bone") > 0, "butchering gave meat, hide and bone")
	print("[gather_lab] butchered %d units: meat %d hide %d bone %d" % [took, _p.inventory.count_of(&"raptor_meat"), _p.inventory.count_of(&"raptor_hide"), _p.inventory.count_of(&"raptor_bone")])

func _deplete_and_regrow(node: HarvestNode) -> void:
	_p.global_position = node.global_position + Vector3(0, 1, 6)
	_select(node, &"fibre_stalk")
	# The same consume path a pass uses, run to empty (the real passes above proved the pass).
	var guard := 0
	while not node.depleted and guard < 200:
		for item in node.pools.keys():
			_select(node, StringName(str(item)))
			while node.units_left_for(StringName(str(item))) > 0 and guard < 200:
				node.consume_unit()
				guard += 1
	var why := node.can_gather(_p.inventory)
	_check(node.depleted and why == "depleted", "an emptied bush is depleted and refuses ('%s')" % why)
	var wait := node.regen_left()
	node._process(wait + 0.1)
	_check(not node.depleted and node.units_left_for(&"fibre_stalk") > 0, "the bush regrows after its %.0f s regen" % wait)
	print("[gather_lab] bush depleted after %d units, regrew after %.0f s, fibre %d" % [guard, wait, node.units_left_for(&"fibre_stalk")])

func _bag_summary() -> String:
	var parts := []
	for s in _p.inventory.slots:
		if s:
			parts.append("%s x%d" % [s.def_id, s.count])
	return ", ".join(parts)

func _capture(stage: String) -> void:
	if DisplayServer.get_name() == "headless" or _shot_base == "":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s-%s.png" % [_shot_base, stage]
	get_viewport().get_texture().get_image().save_png(path)
	print("[gather_lab] shot %s" % path)
