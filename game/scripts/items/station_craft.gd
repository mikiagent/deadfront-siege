class_name StationCraft
extends Node
## Station tap → hex interact menu over the station (StationMenu) → craft sheet / radial →
## walk → crouch craft card with consume/refund/queue.

const CANCEL_RANGE := 2.8
## Inputs stay in the bag until a craft finishes; consume and produce happen together then, so
## a cancel, a save, a burnt-out fire or a demolished station can never strand items (sec-loss-08).
## A finished craft whose output does not fit waits at 100 % and retries this often.
const FULL_RETRY_S := 1.0

var player: Player
var menu: StationMenu
var radial: StationRadial
var card: CraftCard
var held_slot: HeldItemSlot

var station: Node3D
var _pending_overflow: Array[ItemStack] = []  ## crafted units waiting for bag room
var _no_hand_model: Dictionary = {}  ## "<def_id>/<hunting>" -> true: no GLB, do not retry every frame
var recipe_id: StringName = &""
var crafting: bool = false
var progress: float = 0.0
var duration: float = 3.0
var queue_left: int = 0
var _picks: Array[int] = []
## uid per recipe slot of the instance the card showed ("" = a fungible stack: any of its kind).
var _pick_uids: Array[String] = []
var _full_wait: float = 0.0  # countdown to the next fit retry of a finished craft
var _told_full: bool = false
var _hand_tool: Node3D
var _hand_craft: bool = false  # recipe with no station: crafts in place over the survivor
var _batch_total: int = 1
var _burnt: bool = false
## The craft's decided plan (Crafting.plan_for_player): outcome, burn and level, kept across a
## full-bag wait so a retry can never re-roll them.
var _plan: Dictionary = {}
## Injectable for reproducible burn rolls (tests, server).
var rng: RandomNumberGenerator = null

func setup(p: Player, layer: CanvasLayer) -> void:
	player = p
	menu = StationMenu.new()
	menu.name = "StationMenu"
	layer.add_child(menu)
	menu.player = p
	menu.action_chosen.connect(_on_menu_action)
	radial = StationRadial.new()
	radial.name = "StationRadial"
	layer.add_child(radial)
	radial.recipe_chosen.connect(_on_recipe_chosen)
	card = CraftCard.new()
	card.name = "CraftCard"
	layer.add_child(card)
	held_slot = HeldItemSlot.new()
	held_slot.name = "HeldItemSlot"
	layer.add_child(held_slot)
	held_slot.bind(player)
	held_slot.equip_requested.connect(_on_equip)
	held_slot.unequip_requested.connect(_on_unequip)
	held_slot.gather_requested.connect(player.controls.gather_nearest)
	set_process(true)

func reparent_ui(layer: CanvasLayer) -> void:
	if layer == null:
		return
	for n in [menu, radial, card, held_slot]:
		if n and is_instance_valid(n) and n.get_parent() != layer:
			n.reparent(layer)

## Station tap entry point: hex interact menu over the station. Tapping the same station
## again toggles it closed. Actions dispatch in _on_menu_action.
func open_station_menu(st: Node3D) -> void:
	if st == null or not is_instance_valid(st) or menu == null:
		return
	if menu.visible and menu.station == st:
		menu.hide_menu()
		return
	var actions := StationMenu.filter_actions(st, StationMenu.actions_for(station_id_of(st), player))
	var ps := ProcessStation.of(st)
	if ps and ps.waiting_count() > 0:
		var waiting: ItemStack = ps.jobs[ps.jobs.size() - 1]["inputs"][0]
		actions.push_front({"id": &"take_back", "label": "TAKE BACK %d" % ps.waiting_count(), "icon": str(waiting.def_id), "glyph": "-"})
	if ps and ps.ready_count() > 0:
		var first: ItemStack = ps.outputs[0]["stack"]
		actions.push_front({"id": &"collect", "label": "COLLECT %d" % ps.ready_count(), "icon": str(first.def_id), "glyph": "+"})
	if actions.is_empty():
		print("[craft] no actions for station %s" % station_id_of(st))
		return
	close_radial()
	menu.show_for(st, actions)

func _on_menu_action(st: Node3D, action_id: StringName) -> void:
	if st == null or not is_instance_valid(st):
		return
	match action_id:
		&"craft", &"cook":
			var cui: Variant = player.get("craft_ui")
			if cui != null and cui.has_method("show_for_station"):
				cui.show_for_station(station_id_of(st))
			else:
				open_station(st)
		&"sleep":
			player._start_sleep(st)
		&"collect", &"take_back":
			# Verbs that change the bag go through the command layer (contracts.md §0.3: online they
			# are act.collect / act.take_back intents). call(): the two methods are W2-PLAYER's file,
			# added by this package's hooks patch.
			player.actions.call(action_id, st)
		&"wood":
			if st is Bonfire:
				(st as Bonfire).load_wood(player)
		&"cauterise":
			if st is Bonfire:
				(st as Bonfire).cauterise(player)
		_:
			print("[craft] unknown station action %s" % action_id)

func open_station(st: Node3D) -> void:
	if st == null or not is_instance_valid(st):
		return
	if crafting and station == st:
		return
	station = st
	var sid := station_id_of(st)
	var recipes := Crafting.recipes_for_station(sid)
	if recipes.is_empty():
		print("[craft] no recipes for station %s" % sid)
		return
	radial.show_for(st, recipes, player.inventory)

func close_radial() -> void:
	if radial:
		radial.hide_radial()

func close_menu() -> void:
	if menu:
		menu.hide_menu()

func station_id_of(st: Node3D) -> StringName:
	if st == null:
		return &""
	if st.get("station_id") != null and str(st.get("station_id")) != "":
		return StringName(str(st.get("station_id")))
	if st is CraftStation:
		return (st as CraftStation).station_id
	if st is Bonfire:
		return &"bonfire"
	return StringName(str(st.get("kind")))

static func is_craft_station(n: Object) -> bool:
	if n == null:
		return false
	if n is CraftStation or n is Bonfire:
		return true
	if n is Node and (n as Node).is_in_group("craft_station"):
		return true
	return false

## From the craft menu: craft `count` of a recipe. Hand recipes start at once; station recipes
## walk to the nearest station of that kind first (none built -> refused).
## `uids` (one per recipe slot) are the instances the player placed in the craft menu's place-materials
## view: they lead their slots instead of the default picks (the plan fills the rest of each slot).
func begin(rid: StringName, count: int = 1, uids: Array[String] = []) -> bool:
	var rec := Crafting.recipe(rid)
	if rec.is_empty():
		return false
	if crafting:
		cancel_and_refund()
	var sid := Crafting.station_id(rec)
	_hand_craft = sid == ""
	station = null
	if not _hand_craft:
		station = Crafting.nearest_station(player, StringName(sid))
		if station == null:
			print("[craft] blocked %s: no %s built" % [rid, sid])
			return false
		# FIREPITS: cooking works only while the fire burns.
		if station.has_method("can_cook") and not bool(station.call("can_cook")):
			print("[craft] blocked %s: %s" % [rid, str(station.call("cook_block_reason"))])
			player.notice("Can't cook: %s" % str(station.call("cook_block_reason")).to_lower())
			station = null
			return false
	_batch_total = maxi(1, count)
	_begin_recipe(rid)
	if recipe_id != rid:
		return false
	if uids.size() == _pick_uids.size():
		_pick_uids = uids.duplicate()
	queue_left = _batch_total - 1
	if _hand_craft:
		player.clear_nav()
		_start_craft_cycle()
	return true

func _on_recipe_chosen(rid: StringName) -> void:
	close_radial()
	if crafting and rid == recipe_id:
		queue_left += 1
		if card:
			card.set_queue(queue_left + 1)
		print("[craft] queue %s ×%d" % [rid, queue_left + 1])
		return
	_begin_recipe(rid)

func _begin_recipe(rid: StringName) -> void:
	var rec := Crafting.recipe(rid)
	if rec.is_empty():
		return
	# Switching recipe mid-craft gives the first recipe's inputs back (sec-craft-22).
	if crafting and rid != recipe_id:
		cancel_and_refund()
	var blocked := Crafting.progression_block(player, rec)
	if blocked != "":
		player.notice(blocked)
		return
	var missing := Crafting.missing_ingredient_name(player.inventory, rec)
	if missing != "":
		print("[craft] blocked %s: needs %s" % [rid, missing])
		return
	recipe_id = rid
	_picks = Crafting.default_picks(player.inventory, rec)
	if not Crafting.picks_valid(player.inventory, rec, _picks):
		print("[craft] blocked %s: needs %s" % [rid, Crafting.missing_ingredient_name(player.inventory, rec)])
		return
	_pick_uids.clear()
	for i in _picks:
		_pick_uids.append(player.inventory.slots[i].uid if i >= 0 and player.inventory.slots[i] else "")
	queue_left = 0
	if station and is_instance_valid(station):
		if player.global_position.distance_to(station.global_position) > Crafting.STATION_RANGE + 0.35:
			player.nav_to(player._closest_nav_point(station.global_position))
		else:
			player.face_world(station.global_position)
	# Arrival is polled in _process.

func _start_craft_cycle() -> void:
	var rec := Crafting.recipe(recipe_id)
	if rec.is_empty():
		_clear_session()
		return
	var ps := ProcessStation.of(station) if station and is_instance_valid(station) else null
	if ps and ps.runs(recipe_id):
		_load_process_station(ps, rec)
		return
	_picks = Crafting.default_picks(player.inventory, rec)
	# The card's previewed instances, wherever the bag moved them while the survivor walked over.
	# Only the batch's first craft: a queued repeat takes whatever the bag holds then.
	if queue_left + 1 == _batch_total:
		for i in mini(_picks.size(), _pick_uids.size()):
			if _pick_uids[i] != "":
				var moved := _bag_index_of(_pick_uids[i])
				if moved < 0:
					player.notice("Craft stopped: its materials left the bag.")
					_clear_session()
					return
				_picks[i] = moved
	var blocked := Crafting.progression_block(player, rec)
	if blocked != "":
		player.notice(blocked)
		_clear_session()
		return
	var missing := Crafting.missing_ingredient_name(player.inventory, rec)
	if missing != "":
		print("[craft] blocked %s: needs %s" % [recipe_id, missing])
		_clear_session()
		return
	if not Crafting.picks_valid(player.inventory, rec, _picks):
		print("[craft] blocked %s: needs %s" % [recipe_id, Crafting.missing_ingredient_name(player.inventory, rec)])
		_clear_session()
		return
	# CRAFTFEEL: the outcome, the burn roll and the output level are decided once, when the work
	# starts, and kept: a full bag waits for room and then reuses this plan instead of re-rolling.
	_plan = Crafting.plan_for_player(player, rec, _picks, rng)
	_burnt = bool(_plan.get("burnt", false))
	if _plan.is_empty():
		Crafting.refuse_full(player, rec)
		_clear_session()
		return
	if not Crafting.plan_fits(player.inventory, rec, _plan):
		Crafting.refuse_full(player, rec)
		_clear_session()
		return
	duration = Crafting.recipe_seconds(rec)
	progress = 0.0
	_full_wait = 0.0
	_told_full = false
	crafting = true
	print("[craft] start %s %.1fs burn=%s success=%s" % [recipe_id, duration, _burnt, bool((_plan.get("outcome", {}) as Dictionary).get("success", true))])
	# CRAFTFEEL (plan §3.3): the odds and the loss warning ride on the live craft card, not only on
	# the menu's detail pane, so the stakes stay on screen while the survivor works.
	_show_card(rec)
	if player.anim:
		player.anim.on_gather(&"craft")
	if station and is_instance_valid(station):
		player.face_world(station.global_position)
	player.clear_nav()
	_show_ring(rec)

## Process stations take the inputs and run the job themselves; the survivor is free to leave. The
## first job takes the instances the card showed, found by uid wherever the bag moved them since; one
## that left the bag or has no processing left is refused with a notice, never substituted (spec
## 08:98 "consumes specific instance IDs"). Queued repeats auto-pick.
func _load_process_station(ps: ProcessStation, rec: Dictionary) -> void:
	var picks := Crafting.default_picks(player.inventory, rec)
	for i in mini(picks.size(), _pick_uids.size()):
		if _pick_uids[i] != "":
			picks[i] = _bag_index_of(_pick_uids[i])
	var why := ps.refuse_reason(player.inventory, recipe_id, player, picks)
	var n := ps.load_from(player.inventory, recipe_id, queue_left + 1, player, rng, picks)
	if n > 0:
		var when := ps.time_left_text()
		player.notice("%s: %d on the %s, %s." % [str(rec.get("display_name", recipe_id)), n, str(ps.station_id).replace("_", " "), ("ready in " + when) if when != "" else "waiting for a slot"])
	elif why != "":
		player.notice(why)
	_clear_session()

func _bag_index_of(uid: String) -> int:
	for i in player.inventory.slot_count:
		if player.inventory.slots[i] and player.inventory.slots[i].uid == uid:
			return i
	return -1

## The gather-style hex over the station (or the survivor for hand recipes): the outside
## border fills once per item, the inner green edge is the batch.
func _show_ring(rec: Dictionary) -> void:
	var ring: Variant = player.get("_gather_ring")
	if ring == null or not ring.has_method("show_for_craft"):
		return
	var out_id := StringName(str((rec.get("output", {}) as Dictionary).get("id", "")))
	var anchor: Node3D = station if (station and is_instance_valid(station)) else player
	var height := 1.0 if anchor != player else 2.1
	var done := _batch_total - queue_left - 1
	ring.show_for_craft(anchor, height, progress, float(done) / float(maxi(1, _batch_total)), out_id, "%d/%d" % [done + 1, _batch_total])

func _hide_ring() -> void:
	var ring: Variant = player.get("_gather_ring")
	if ring and ring.has_method("fade_out"):
		ring.fade_out()

func _show_card(rec: Dictionary) -> void:
	if card == null or station == null:
		return
	var rows: Array[Dictionary] = []
	for slot in rec.get("slots", []):
		if not slot is Dictionary:
			continue
		var cat := StringName(str((slot as Dictionary).get("category", "")))
		var count := int((slot as Dictionary).get("count", 1))
		var def_id := Crafting.sample_def_for_category(player.inventory, cat)
		# Prefer refund snapshot ids when mid-craft.
		rows.append({
			"def_id": def_id,
			"count": count,
			"icon": card.icon_for(def_id),
			"glyph": str(def_id).substr(0, 1).to_upper() if str(def_id) != "" else "?",
		})
	# CRAFTFEEL: the card carries the same stake lines the detail pane showed (CraftUI.craftfeel_text),
	# built from the plan's own picks so the card and the craft describe one craft.
	var picks := _picks
	if picks.is_empty() or not Crafting.picks_valid(player.inventory, rec, picks):
		picks = Crafting.default_picks(player.inventory, rec)
	var primary: ItemStack = null
	if picks.size() > Crafting.primary_index(rec) and picks[Crafting.primary_index(rec)] >= 0:
		primary = player.inventory.slots[picks[Crafting.primary_index(rec)]]
	var odds: String = CraftUI.craftfeel_text(Crafting.preview_quality(rec, player, primary))
	card.show_recipe(station, str(rec.get("display_name", recipe_id)), rows, progress, queue_left + 1, odds)

## Overflow units waiting for a free slot (see _finish_one); put back as soon as the bag takes them.
func _flush_overflow() -> void:
	var i := _pending_overflow.size() - 1
	while i >= 0:
		if player.inventory.add(_pending_overflow[i]) <= 0:
			_pending_overflow.remove_at(i)
		i -= 1

func _process(delta: float) -> void:
	if player == null:
		return
	_flush_overflow()
	_sync_hand_tool()
	if recipe_id != &"" and not crafting and station and is_instance_valid(station):
		if not player.nav_active and player.global_position.distance_to(station.global_position) <= Crafting.STATION_RANGE + 0.35:
			_start_craft_cycle()
		elif player.nav_active and player.global_position.distance_to(station.global_position) > CANCEL_RANGE + 4.0:
			pass
	if crafting:
		if not _hand_craft and (station == null or not is_instance_valid(station) \
				or player.global_position.distance_to(station.global_position) > CANCEL_RANGE):
			cancel_and_refund()
			return
		# Moving (keys, or a tap elsewhere) cancels and refunds.
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input.length_squared() > 0.04 or player.nav_active or player.dead:
			cancel_and_refund()
			return
		progress = minf(1.0, progress + delta / maxf(0.05, duration))
		_show_ring(Crafting.recipe(recipe_id))
		if card and card.visible:
			card.set_progress(progress)
		if progress >= 1.0:
			_full_wait -= delta
			if _full_wait <= 0.0:
				_finish_one()

## Finish the craft that was planned when the work started. A full bag pauses it (inputs untouched,
## the same plan re-checked) until there is room; a planned instance that left the bag stops it with
## no substitution (spec 08:98). The outcome is never re-rolled on a retry.
func _finish_one() -> void:
	var rec := Crafting.recipe(recipe_id)
	if _plan.is_empty():
		_plan = Crafting.plan_for_player(player, rec, Crafting.default_picks(player.inventory, rec), rng)
		if _plan.is_empty():
			player.notice("Craft stopped: its materials left the bag.")
			_clear_session()
			return
	var picks := Crafting.plan_picks(player.inventory, rec, _plan)
	if picks.is_empty():
		player.notice("Craft stopped: its materials left the bag.")
		_clear_session()
		return
	_picks = picks
	# A failure spends the picked instances and needs no bag room (spec 25 §8).
	var success := bool((_plan.get("outcome", {}) as Dictionary).get("success", true))
	if success and not Crafting.plan_fits(player.inventory, rec, _plan):
		if not _told_full:
			_told_full = true
			player.notice("Bag is full: make room to finish the %s." % str(rec.get("display_name", recipe_id)))
		_full_wait = FULL_RETRY_S
		return
	_full_wait = 0.0
	_told_full = false
	var overflow: Array[ItemStack] = []
	var res := Crafting.run_plan(rec, player.inventory, _plan, overflow)
	Crafting.report_plan(player, rec, res)
	var out: ItemStack = res.get("item", null)
	if not overflow.is_empty():
		# plan_fits runs first, so this should be unreachable; if it is ever hit, the units are
		# held here and retried every tick instead of being dropped silently.
		push_error("[craft] plan_fits passed but %d units overflowed; retrying the add" % overflow[0].count)
		for left in overflow:
			_pending_overflow.append(left)
	if out:
		player.toast(out.def_id, out.count)  # UIGATHER: the HUD's yield card (PickupToast retired)
	if str(res.get("status", "")) == "left":
		_clear_session()
		return
	crafting = false
	progress = 0.0
	_plan = {}
	_burnt = false
	if queue_left > 0:
		queue_left -= 1
		_start_craft_cycle()
	else:
		if card:
			card.hide_card()
		_hide_ring()
		recipe_id = &""
		_hand_craft = false

## Stops the craft. Nothing to give back: the inputs never left the bag (name kept for player.gd).
func cancel_and_refund() -> void:
	if crafting:
		print("[craft] cancelled %s; inputs stay in the bag" % recipe_id)
	_clear_session()

func _clear_session() -> void:
	crafting = false
	progress = 0.0
	_full_wait = 0.0
	_told_full = false
	queue_left = 0
	recipe_id = &""
	_hand_craft = false
	_picks.clear()
	_pick_uids.clear()
	_plan = {}
	if card:
		card.hide_card()
	_hide_ring()
	close_radial()
	close_menu()

func force_progress_for_shot(p: float) -> void:
	if card and card.visible:
		card.set_progress(p)

func _on_equip(idx: int) -> void:
	if player:
		player.inventory.set_equipped_tool_index(idx)
		held_slot.refresh()
		_sync_hand_tool()

func _on_unequip() -> void:
	if player:
		player.inventory.set_equipped_tool_index(-1)
		held_slot.refresh()
		_sync_hand_tool()

func _sync_hand_tool() -> void:
	if player == null:
		return
	var anchor := player.right_hand_anchor()
	if anchor == null:
		return
	var hunting := _hunting()
	var held := player.inventory.equipped_weapon() if hunting else player.inventory.equipped_gather_tool()
	if held == null and hunting:
		held = player.inventory.equipped_gather_tool()
	var want_id := held.def_id if held else &""
	if _hand_tool and is_instance_valid(_hand_tool):
		if want_id == &"" or str(_hand_tool.get_meta("tool_id", "")) != str(want_id):
			_hand_tool.queue_free()
			_hand_tool = null
	if want_id == &"" or (_hand_tool and is_instance_valid(_hand_tool)):
		return
	# A weapon with no model (spear, bow: props_manifest model null) resolves to null, and this
	# runs every frame: remember the answer per def so the attach is not retried.
	var cache_key := "%s/%s" % [str(want_id), hunting]
	if _no_hand_model.has(cache_key):
		return
	_hand_tool = HeldModel.attach(anchor, want_id, hunting)
	if _hand_tool:
		_hand_tool.set_meta("tool_id", str(want_id))
	else:
		_no_hand_model[cache_key] = true

func held_model_id() -> StringName:
	return StringName(str(_hand_tool.get_meta("tool_id", ""))) if _hand_tool and is_instance_valid(_hand_tool) else &""

## A hunt target means the fight is on: the hand shows the weapon, not the gather tool (pc-weapon-01).
func _hunting() -> bool:
	var h: Variant = player.get("hunt")
	return h != null and h.target != null and is_instance_valid(h.target)
