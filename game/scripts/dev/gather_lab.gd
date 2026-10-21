extends Node3D
## W2-GATHER play session on the home island: the survivor gathers fibre, branches and stone
## bare-handed, then with stone tools (faster, logs unlocked, the knife wears on the bush), gathers a
## fibre stalk with a green rare trait, butchers a raptor by knife, and watches a node deplete and regrow. Every unit goes through PlayerActions.
## GAUNTLET gather rules checked on every pass: walked into reach (no teleport), the progress
## ring above the node, movement cancels, starter-island finds are level 1.
## Shots: --shot=<path.png> --shot-delay=900 saves <path>-<stage>.png per stage.

var _p: Player
var _fails: Array[String] = []
var _shot_base := ""
## Owner motion gate on real frames (_watch_motion): the worst per-frame move of a drawn stack beyond
## its own eased rise, frames watched, and the slowest frame seen.
var _motion := {"excess": 0.0, "frames": 0, "worst_dt": 0.0}

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

	# 3. A green rare trait at the real data odds (world-design.md:55: 5% per material). Home grassland
	# has no finds (each of its materials is some home node's own yield). The seed is picked so the very
	# next fibre item rolls a trait (the odds themselves are measured in t_gather).
	var knife := _p.inventory.find_gather_tool(&"knife")
	var dur_before := knife.durability if knife else -1
	GatherService.rng.seed = _trait_seed()
	var traited := _traited(&"fibre_stalk")
	await _gather(bush, &"fibre_stalk", 1, "rare", 0.35)
	_check(_traited(&"fibre_stalk") > traited, "a fibre stalk with a green rare trait landed in the bag")
	_check(knife != null and knife.durability < dur_before, "the knife wears on the bush it only helps with (%d -> %d)" % [dur_before, knife.durability if knife else -1])
	# The touch flow: tap the bush, pick Fibre on the radial; the picked hex shows the progress.
	GatherService.rng.seed = _trait_seed()
	traited = _traited(&"fibre_stalk")
	await _gather(bush, &"fibre_stalk", 1, "rare_radial", 0.35, true)
	_check(_traited(&"fibre_stalk") > traited, "a traited fibre stalk landed through the radial")
	await _notice_colours()
	for id in [&"flint", &"copper_ore", &"berries", &"herb_leaf"]:
		_check(_p.inventory.count_of(id) == 0, "no %s find on the home island" % id)
	for st in _p.inventory.slots:
		if st and st.def_id in [&"berries", &"fibre_stalk", &"branch", &"stone", &"wood_log"]:
			_check(st.level == 1, "starter-island %s is level 1 (got %d)" % [st.def_id, st.level])

	print("[gather_lab] motion: %d stack frames watched, worst move beyond the rise %.1f px, slowest frame %.0f ms" % [_motion["frames"], _motion["excess"], _motion["worst_dt"] * 1000.0])
	if DisplayServer.get_name() != "headless":
		_check(_motion["frames"] >= 10 and _motion["excess"] <= 0.0, "a drawn stack never jumps between frames (%d frames, %.1f px past its rise)" % [_motion["frames"], _motion["excess"]])

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
			if shot.begins_with("rare"):
				_watch_motion(node)  # not awaited: it follows the stack through its life
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
		_popup_clear(node, shot.begins_with("rare"))
		if via_radial:
			await _capture(shot + "_open")  # the radial as the player sees it, before the stop closes it
	# Stop before the capture: a slow windowed frame would otherwise keep the cycle running.
	_p.actions.cancel_work()
	if shot != "":
		await _capture(shot)
	return per

## Follows the stack a unit just raised over `node`, every frame until it is gone: relative to its
## anchor (the camera may move), it may move no more than its rise eases (RISE_PX * 2 / LIFE px per s).
func _watch_motion(node: HarvestNode) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var layer := get_tree().current_scene.get_node_or_null(GatherFeedback.LAYER_NAME)
	var box: Control = layer.get_child(layer.get_child_count() - 1) if layer and layer.get_child_count() > 0 else null
	var cam := get_viewport().get_camera_3d()
	if box == null or not box.visible or cam == null:
		return
	var at := node.global_position + Vector3(0, node.top_of_node() + 0.3, 0)
	var prev := box.position - cam.unproject_position(at)
	var last := Time.get_ticks_usec()
	while is_instance_valid(box) and not box.is_queued_for_deletion():
		await get_tree().process_frame
		if not is_instance_valid(box) or box.is_queued_for_deletion():
			break
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		var rel := box.position - cam.unproject_position(at)
		_motion["excess"] = maxf(_motion["excess"], (rel - prev).length() - (1.0 + GatherFeedback.RISE_PX * 2.0 / GatherFeedback.LIFE * dt))
		_motion["frames"] += 1
		_motion["worst_dt"] = maxf(_motion["worst_dt"], dt)
		prev = rel
		last = now

## The floating progress ring is up and drawn above the node's base on screen.
func _ring_above(node: HarvestNode) -> bool:
	var ring: GatherRing = _p._gather_ring
	var cam := get_viewport().get_camera_3d()
	return ring != null and cam != null and ring.visible and ring.target == node \
			and ring._screen_pos.y < cam.unproject_position(node.global_position).y

## The live "+n" stack sits clear of the ring, HUD text and zones, plates and the radial.
func _popup_clear(node: HarvestNode, rare: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return  # no real screen layout headless: the windowed runs check placement
	var layer := get_tree().current_scene.get_node_or_null(GatherFeedback.LAYER_NAME)
	var box: Control = layer.get_child(layer.get_child_count() - 1) if layer and layer.get_child_count() > 0 else null
	var phone := UiTokens.is_compact(get_viewport().get_visible_rect().size)
	# Owner 2026-10-21 "make it flashy": a rare result gets its pop on phones too, so a phone's rare
	# stack must be drawn (under the ring when the sides are full); only a plain one may give way.
	# With the radial open a phone has no spot by the node at all; the notice carries the pop there.
	_check(not (phone and rare and not _p._gather_radial.is_open()) or (box != null and box.visible), "a phone draws the rare stack over %s" % node.family)
	if (box == null or not box.visible) and phone:
		# A plain "+n" on a phone shows only above the ring; with no room there the HUD toast carries it.
		var hud := get_tree().get_first_node_in_group("hud")
		var toasted := false
		for k in (hud.get("drawn_blocks") as Dictionary if hud else {}):
			toasted = toasted or str(k).begins_with("toast")
		_check(toasted, "no yield popup over %s and no HUD toast either" % node.family)
		_check(not rare or _rare_notice_fresh(), "a rare result the stack could not show is announced by a tinted HUD notice")
		print("[gather_lab] popup skipped over %s (no room by the node); HUD toast %s, rare notice %s" % [node.family, toasted, _rare_notice_fresh()])
		if rare:
			_rare_notice_clear()
		return
	_check(box != null and box.visible, "a yield popup showed over %s" % node.family)
	if box == null:
		return
	_check(not (rare and _rare_notice_fresh()), "a drawn rare stack is not repeated by a HUD notice")
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
	_check(not phone or rare or r.end.y <= a.y - GatherFeedback.RING_CLEAR + 1.0, "a phone's plain popup %s sits above the ring (%s, ring at %s)" % [texts, r, a])
	print("[gather_lab] popup %s at %s" % [texts, r])

## The tinted notices the HUD drew last frame keep off the open radial (labels, title, hexes), the
## creature plates and the survivor with their ring, and one result has one notice ("x2", not a copy).
func _rare_notice_clear() -> void:
	var hud := get_tree().get_first_node_in_group("hud") as HuntHud
	if hud == null:
		return
	var drawn := 0
	for k in hud.drawn_blocks:
		var i := int(str(k).trim_prefix("notice"))
		if not str(k).begins_with("notice") or i >= hud._events.notices.size() or not hud._events.notices[i].has("tint"):
			continue
		var r := Rect2((hud.drawn_blocks[k] as Rect2).position + hud.global_position, (hud.drawn_blocks[k] as Rect2).size)
		drawn += 1
		for t in _must_avoid():
			_check(not r.intersects(t), "rare notice '%s' at %s clear of %s" % [hud._events.notices[i]["text"], r, t])
		print("[gather_lab] rare notice '%s' at %s, radial open %s" % [hud._events.notices[i]["text"], r, _p._gather_radial.is_open()])
	var per := {}
	for n in hud._events.notices:
		if n.has("base"):
			per[n["base"]] = int(per.get(n["base"], 0)) + 1
	_check(drawn > 0, "the rare notice is drawn")
	_check(per.values().all(func(c: int) -> bool: return c == 1), "one notice per rare result, a repeat reads x2 (%s)" % per)

## What a rare notice must keep off, listed here and not by GatherFeedback (a change there cannot hide
## itself): the open radial's labels, title and hexes, the creature plates and the survivor with their ring.
func _must_avoid() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var gr := _p._gather_radial
	if gr and gr.is_open():
		out.append_array(gr.label_rects)
		out.append(gr.title_box)
		for c in gr.get_children():
			if c is Control and (c as Control).visible:
				out.append((c as Control).get_global_rect())
	if Game.creature_ui:
		for pill in Game.creature_ui.find_children("Pill", "Control", true, false):
			if (pill as Control).is_visible_in_tree():
				out.append((pill as Control).get_global_rect())
	out.append(GatherFeedback.survivor_rect(_p))
	return out

## The colour language on real pixels (windowed): a rare notice is its tint on ink, never the red refusal
## box. Raises the fallback notice the HUD shows when a stack cannot be drawn, and samples its edge and fill.
func _notice_colours() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hud := get_tree().get_first_node_in_group("hud") as HuntHud
	GatherFeedback.notice(_p, "Rare trait: Black Sheen Fibre Stalk", GatherFeedback.GREEN)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var box := Rect2()
	for k in hud.drawn_blocks:
		var i := int(str(k).trim_prefix("notice"))
		if str(k).begins_with("notice") and i < hud._events.notices.size() and hud._events.notices[i].has("tint"):
			box = Rect2((hud.drawn_blocks[k] as Rect2).position + hud.global_position, (hud.drawn_blocks[k] as Rect2).size)
	_check(box.has_area(), "the rare notice is drawn")
	if not box.has_area():
		return
	await get_tree().create_timer(GatherFeedback.PUNCH_S + 0.15).timeout  # sampled after its pop eased back
	await _capture("rare_notice")
	var img := get_viewport().get_texture().get_image()
	var sx := float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var edge := img.get_pixelv(Vector2i(((box.position + Vector2(box.size.x * 0.5, 0.0)) * sx).floor()))
	var fill := img.get_pixelv(Vector2i(((box.position + Vector2(4.0, 4.0)) * sx).round()))
	print("[gather_lab] rare notice at %s: edge %s fill %s" % [box, edge.to_html(false), fill.to_html(false)])
	_check(edge.g > edge.r and edge.g > 0.45, "the rare notice's edge is its green tint (%s)" % edge.to_html(false))
	_check(fill.get_luminance() < 0.15 and fill.r < 0.2, "the rare notice's fill is ink, not the refusal red (%s)" % fill.to_html(false))
	hud._events.notices.clear()

## A tinted "Rare ..." HUD notice raised for this unit (it starts at NOTICE_T0; this one is under 0.6 s old).
func _rare_notice_fresh() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return false
	for n in hud._events.notices:
		if str(n["text"]).begins_with("Rare") and float(n["t"]) < GatherFeedback.NOTICE_T0 + 0.6 and n.has("tint"):
			return true
	return false

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

## First seed whose first item roll lands a green rare trait (after_unit rolls traits before finds).
func _trait_seed() -> int:
	var probe := RandomNumberGenerator.new()
	for s in range(1, 5000):
		probe.seed = s
		if LootRoller.roll_trait(probe) != &"":
			return s
	return 1

## Units of `id` in the bag that carry a green rare trait.
func _traited(id: StringName) -> int:
	var traits: Array = LootTables.trait_cfg().get("traits", [])
	var n := 0
	for st in _p.inventory.slots:
		if st and st.def_id == id and traits.any(func(t): return st.attributes.has(str(t))):
			n += st.count
	return n

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
