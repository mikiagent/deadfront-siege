class_name StationCraft
extends Node
## Station tap → hex interact menu over the station (StationMenu) → craft sheet / radial →
## walk → crouch craft card with consume/refund/queue.

const CANCEL_RANGE := 2.8

var player: Player
var menu: StationMenu
var radial: StationRadial
var card: CraftCard
var toast: PickupToast
var held_slot: HeldItemSlot

var station: Node3D
var recipe_id: StringName = &""
var crafting: bool = false
var progress: float = 0.0
var duration: float = 3.0
var queue_left: int = 0
var _picks: Array[int] = []
var _refund: Array[ItemStack] = []
var _hand_tool: Node3D
var _hand_craft: bool = false  # recipe with no station: crafts in place over the survivor
var _batch_total: int = 1

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
	toast = PickupToast.new()
	toast.name = "PickupToast"
	layer.add_child(toast)
	held_slot = HeldItemSlot.new()
	held_slot.name = "HeldItemSlot"
	layer.add_child(held_slot)
	held_slot.bind(player)
	held_slot.equip_requested.connect(_on_equip)
	held_slot.unequip_requested.connect(_on_unequip)
	set_process(true)

func reparent_ui(layer: CanvasLayer) -> void:
	if layer == null:
		return
	for n in [menu, radial, card, toast, held_slot]:
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
	var actions := StationMenu.actions_for(station_id_of(st), player)
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
func begin(rid: StringName, count: int = 1) -> bool:
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
	_batch_total = maxi(1, count)
	_begin_recipe(rid)
	if recipe_id != rid:
		return false
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
	var missing := Crafting.missing_ingredient_name(player.inventory, rec)
	if missing != "":
		print("[craft] blocked %s: needs %s" % [rid, missing])
		return
	recipe_id = rid
	_picks = Crafting.default_picks(player.inventory, rec)
	if not Crafting.picks_valid(player.inventory, rec, _picks):
		print("[craft] blocked %s: needs %s" % [rid, Crafting.missing_ingredient_name(player.inventory, rec)])
		return
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
	_picks = Crafting.default_picks(player.inventory, rec)
	var missing := Crafting.missing_ingredient_name(player.inventory, rec)
	if missing != "":
		print("[craft] blocked %s: needs %s" % [recipe_id, missing])
		_clear_session()
		return
	if not Crafting.picks_valid(player.inventory, rec, _picks):
		print("[craft] blocked %s: needs %s" % [recipe_id, Crafting.missing_ingredient_name(player.inventory, rec)])
		_clear_session()
		return
	duration = Crafting.recipe_seconds(rec)
	progress = 0.0
	crafting = true
	_refund = Crafting.consume_for_craft(player.inventory, rec, _picks)
	print("[craft] start %s %.1fs" % [recipe_id, duration])
	if player.anim:
		player.anim.on_gather(&"craft")
	if station and is_instance_valid(station):
		player.face_world(station.global_position)
	player.clear_nav()
	_show_ring(rec)

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
	# Fill icons from refund stacks when available.
	if not _refund.is_empty():
		for i in mini(rows.size(), _refund.size()):
			if _refund[i]:
				rows[i]["def_id"] = _refund[i].def_id
				rows[i]["icon"] = card.icon_for(_refund[i].def_id)
				rows[i]["glyph"] = str(_refund[i].def_id).substr(0, 1).to_upper()
	card.show_recipe(station, str(rec.get("display_name", recipe_id)), rows, progress, queue_left + 1)

func _process(delta: float) -> void:
	if player == null:
		return
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
		if progress >= 1.0:
			_finish_one()

func _finish_one() -> void:
	var rec := Crafting.recipe(recipe_id)
	var out := Crafting.finish_craft(player, rec, _refund)
	_refund.clear()
	if out:
		if toast:
			toast.show_gain(out.def_id, out.count)
		player.toast(out.def_id, out.count)
	crafting = false
	progress = 0.0
	if queue_left > 0:
		queue_left -= 1
		_start_craft_cycle()
	else:
		if card:
			card.hide_card()
		_hide_ring()
		recipe_id = &""
		_hand_craft = false

func cancel_and_refund() -> void:
	if not _refund.is_empty():
		for stack in _refund:
			if stack:
				player.inventory.add(stack)
		print("[craft] cancelled refunded %s" % recipe_id)
	_refund.clear()
	_clear_session()

func _clear_session() -> void:
	crafting = false
	progress = 0.0
	queue_left = 0
	recipe_id = &""
	_hand_craft = false
	_picks.clear()
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
	var tool := player.inventory.equipped_gather_tool()
	var want_id := tool.def_id if tool else &""
	if _hand_tool and is_instance_valid(_hand_tool):
		if want_id == &"" or str(_hand_tool.get_meta("tool_id", "")) != str(want_id):
			_hand_tool.queue_free()
			_hand_tool = null
	if want_id == &"":
		return
	if _hand_tool and is_instance_valid(_hand_tool):
		return
	_hand_tool = PropVisuals.attach_tool_model(anchor, want_id)
	if _hand_tool:
		_hand_tool.set_meta("tool_id", str(want_id))
