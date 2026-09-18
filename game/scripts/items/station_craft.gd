class_name StationCraft
extends Node
## Station tap radial → walk → crouch craft card with consume/refund/queue.

const CANCEL_RANGE := 2.8

var player: Player
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

func setup(p: Player, layer: CanvasLayer) -> void:
	player = p
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
	for n in [radial, card, toast, held_slot]:
		if n and is_instance_valid(n) and n.get_parent() != layer:
			n.reparent(layer)

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
		player.nav_to(player._closest_nav_point(station.global_position))
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
		player.anim.on_gather()
	_show_card(rec)
	player.clear_nav()

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
		if station == null or not is_instance_valid(station) \
				or player.global_position.distance_to(station.global_position) > CANCEL_RANGE:
			cancel_and_refund()
			return
		# Manual move cancels.
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input.length_squared() > 0.04:
			cancel_and_refund()
			return
		progress = minf(1.0, progress + delta / maxf(0.05, duration))
		if card:
			card.set_progress(progress)
		if progress >= 1.0:
			_finish_one()

func _finish_one() -> void:
	var rec := Crafting.recipe(recipe_id)
	var out := Crafting.finish_craft(player, rec, _refund)
	_refund.clear()
	if out:
		if toast:
			toast.show_gain(out.def_id, out.count)
	crafting = false
	progress = 0.0
	if queue_left > 0:
		queue_left -= 1
		_start_craft_cycle()
	else:
		if card:
			card.hide_card()
		recipe_id = &""

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
	_picks.clear()
	if card:
		card.hide_card()
	close_radial()

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
