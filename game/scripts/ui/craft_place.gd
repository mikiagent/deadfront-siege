class_name CraftPlace
extends HBoxContainer
## D3 "Craft, place materials" (docs/design/ui-redesign-spec.md §7 D3), a sub-view of CraftUI, and
## the Construction panel (§7 D5): `open_site(site)` fills a ConstructionSite's blueprint slot groups
## by tag (Blueprints.fits) with the same chevrons, candidate grid, numbered picks, Expected Result,
## "Fill Automatically" / "Place Material" and, once every material is in, the build timer.
## The player picks, slot by slot, which bag instance leads it:
##   left    - "Crafting complete n%" and one chevron per recipe slot (OK_GREEN once placed);
##   centre  - the slot's header (name n / need, what it accepts), the candidate grid (icon, level,
##             quality pips, an order badge on each instance the slot will use) and the footer note;
##   focus   - the focused candidate: parchment card with its level, durability and trait chips;
##   result  - the expected result (traits from slot 1 only: Crafting.build_output copies the primary's
##             attributes), a quantity stepper, the success rate, "Place material", then "Craft".
## Crafting rules stay in Crafting: a placed instance is an explicit pick (Crafting.picks_valid /
## preview / the plan), and Craft hands the picks' uids to StationCraft, which leads each slot with them.

## # ASSUMPTION: the stepper runs 1..10 crafts (the canvas shows no bound; D1 offers ×5).
const QTY_MAX := 10
## # ASSUMPTION: quality pips are the instance's rarity tier, the same cue the bag's art_slot draws
## (ItemArt.rarity_order), shown as three pips with one more lit per tier.
const PIPS := 3

var host: CraftUI
var rec: Dictionary = {}
## Construction mode: the site being filled (null = a recipe). `picked` holds, per slot, the bag
## indices chosen to place next, one unit each, in badge order.
var site: ConstructionSite = null
var picked: Array = []
var placed: Array[int] = []  ## bag index leading each slot, -1 = not placed yet
var slot_sel: int = 0
var focus_idx: int = -1
var qty: int = 1

var _chevrons: VBoxContainer
var _complete: Label
var _slot_title: Label
var _slot_accepts: Label
var _grid: GridContainer
var _note: Label
var _focus: VBoxContainer
var _result: VBoxContainer
var _qty_label: Label
var _success: Label
var _cta: Button
## TRIBE M2a: "Assign…" beside the CTA (a recipe) / "Assign builder" (a filled site).
var _assign: Button

func _ready() -> void:
	add_theme_constant_override("separation", 16)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var left := VBoxContainer.new()
	left.name = "PlaceSlots"
	left.add_theme_constant_override("separation", 0)
	add_child(left)
	var done := PanelContainer.new()
	done.add_theme_stylebox_override("panel", CraftUI.pad(Color(0.02, 0.025, 0.03, 0.95), 8, 8, 10, 10))
	left.add_child(done)
	var done_box := VBoxContainer.new()
	done_box.add_theme_constant_override("separation", -4)
	done.add_child(done_box)
	var cap := CraftUI._label("Crafting complete", UiTokens.TYPE_MIN + 2, UiTokens.TEXT)
	cap.name = "CompleteCap"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_box.add_child(cap)
	_complete = CraftUI._label("0%", 44, UiTokens.TEXT)
	_complete.name = "PlaceComplete"
	_complete.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	done_box.add_child(_complete)
	var chev_scroll := ScrollContainer.new()
	chev_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chev_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chev_scroll.add_theme_stylebox_override("panel", CraftUI.flat(Color(0.02, 0.025, 0.03, 0.85)))
	left.add_child(chev_scroll)
	_chevrons = VBoxContainer.new()
	_chevrons.name = "Chevrons"
	_chevrons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chevrons.add_theme_constant_override("separation", 6)
	chev_scroll.add_child(_chevrons)
	# Centre: slot header, candidates, note.
	var centre := VBoxContainer.new()
	centre.name = "PlaceCentre"
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_stretch_ratio = 1.6
	centre.add_theme_constant_override("separation", 14)
	add_child(centre)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", CraftUI.pad(Color(0.02, 0.025, 0.03, 0.9), 22, 22, 10, 12))
	centre.add_child(head)
	var head_box := VBoxContainer.new()
	head_box.add_theme_constant_override("separation", 0)
	head.add_child(head_box)
	_slot_title = CraftUI._label("", 30, UiTokens.TEXT)
	_slot_title.name = "SlotTitle"
	head_box.add_child(_slot_title)
	_slot_accepts = CraftUI._label("", 18, UiTokens.TEXT)
	_slot_accepts.name = "SlotAccepts"
	head_box.add_child(_slot_accepts)
	var cand := VBoxContainer.new()
	cand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cand.add_theme_constant_override("separation", 0)
	centre.add_child(cand)
	var grid_scroll := ScrollContainer.new()
	grid_scroll.name = "CandidateScroll"
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.add_theme_stylebox_override("panel", CraftUI.flat(Color(0.02, 0.025, 0.03, 0.85)))
	cand.add_child(grid_scroll)
	_grid = GridContainer.new()
	_grid.name = "Candidates"
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	grid_scroll.add_child(_grid)
	_note = CraftUI._label("", 18, UiTokens.TEXT)
	_note.name = "PlaceNote"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.custom_minimum_size = Vector2(0, 48)
	_note.add_theme_stylebox_override("normal", CraftUI.flat(Color(0.01, 0.012, 0.015, 0.95)))
	cand.add_child(_note)
	# Focus card.
	var focus_panel := PanelContainer.new()
	focus_panel.name = "FocusCard"
	focus_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_panel.add_theme_stylebox_override("panel", CraftUI.flat(Color(0.02, 0.025, 0.03, 0.9)))
	add_child(focus_panel)
	_focus = VBoxContainer.new()
	_focus.add_theme_constant_override("separation", 0)
	focus_panel.add_child(_focus)
	# Expected result.
	var result_panel := PanelContainer.new()
	result_panel.name = "ResultCard"
	result_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_panel.add_theme_stylebox_override("panel", CraftUI.pad(Color(0.02, 0.025, 0.03, 0.9), 0, 0, 0, 14))
	add_child(result_panel)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", 0)
	result_panel.add_child(rbox)
	_result = VBoxContainer.new()
	_result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result.add_theme_constant_override("separation", 0)
	rbox.add_child(_result)
	var step := HBoxContainer.new()
	step.name = "QtyStepper"
	step.alignment = BoxContainer.ALIGNMENT_CENTER
	step.add_theme_constant_override("separation", 8)
	var minus := _round_btn("−", func () -> void: _set_qty(qty - 1))
	minus.name = "QtyMinus"
	step.add_child(minus)
	_qty_label = CraftUI._label("1", 28, UiTokens.TEXT)
	_qty_label.name = "Qty"
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.add_child(_qty_label)
	var plus := _round_btn("+", func () -> void: _set_qty(qty + 1))
	plus.name = "QtyPlus"
	step.add_child(plus)
	rbox.add_child(_pad(step, 14, 6))
	var srow := HBoxContainer.new()
	var sk := CraftUI._label("Success rate", 20, UiTokens.TEXT)
	sk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sk)
	_success = CraftUI._label("", 20, UiTokens.TEXT)
	_success.name = "SuccessRate"
	_success.clip_text = false
	_success.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	srow.add_child(_success)
	rbox.add_child(_pad(srow, 16, 10))
	_cta = CraftUI.mk_btn("Place material", _on_cta, Vector2(0, 72), "cta")
	_cta.name = "PlaceCta"
	_cta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cta_row := HBoxContainer.new()
	cta_row.name = "CtaRow"
	cta_row.add_theme_constant_override("separation", 8)
	cta_row.add_child(_cta)
	_assign = CraftUI.mk_btn("Assign…", _on_assign, Vector2(0, 72), "ghost")
	_assign.name = "AssignCta"
	cta_row.add_child(_assign)
	rbox.add_child(_pad(cta_row, 14, 8))

# ---------------------------------------------------------------- state

func open(p_rec: Dictionary) -> void:
	site = null
	rec = p_rec
	var n := (rec.get("slots", []) as Array).size()
	placed.clear()
	placed.resize(n)
	placed.fill(-1)
	qty = 1
	_select_slot(0)

func subtitle() -> String:
	if site != null and is_instance_valid(site):
		return str(site.bp().get("display_name", "Site"))
	if rec.is_empty() or host == null:
		return ""
	var sid := Crafting.station_id(rec)
	return "%s · %s" % [host._output_name(rec), "by hand" if sid == "" else "at " + host.station_name(sid).to_lower()]

func _inv() -> Inventory:
	return host.player.inventory if host and host.player else null

func _slot(i: int) -> Dictionary:
	var slots: Array = site.bp().get("slots", []) if site else rec.get("slots", [])
	return slots[i] if i >= 0 and i < slots.size() and slots[i] is Dictionary else {}

## The bag indices that can go into slot `i` (its category, its allowed_ids).
func candidates(i: int) -> Array[int]:
	var out: Array[int] = []
	var inv := _inv()
	var slot := _slot(i)
	if inv == null or slot.is_empty():
		return out
	if site:
		for idx in inv.slot_count:
			var st: ItemStack = inv.slots[idx]
			if st != null and st.def_id != Inventory.LOCK and not st.is_locked() and Blueprints.fits(slot, st):
				out.append(idx)
		return out
	for idx in inv.find_by_category(StringName(str(slot.get("category", "")))):
		if inv.slots[idx] and Crafting._allowed(slot, inv.slots[idx]):
			out.append(idx)
	return out

## One lead per slot: the placed instance, else the default pick (the plan still fills each slot).
func picks() -> Array[int]:
	var inv := _inv()
	var out := Crafting.default_picks(inv, rec) if inv else ([] as Array[int])
	for i in mini(out.size(), placed.size()):
		if placed[i] >= 0:
			out[i] = placed[i]
	return out

func all_placed() -> bool:
	return not placed.is_empty() and not placed.has(-1)

## Share of the recipe's units sitting in placed slots, 0..1.
func completion() -> float:
	var total := 0
	var done := 0
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		var need := int((slots[i] as Dictionary).get("count", 1))
		total += need
		if placed[i] >= 0:
			done += need
	return float(done) / float(total) if total > 0 else 0.0

## Bag index -> 1-based order in slot `i` (the lead first, then the instances the plan adds).
func order_of(i: int) -> Dictionary:
	var out := {}
	if i < 0 or i >= placed.size() or placed[i] < 0:
		return out
	var plan := Crafting._plan(_inv(), rec, picks())
	if i >= plan.size():
		return out
	var k := 1
	for part: Dictionary in (plan[i] as Dictionary).get("parts", []):
		out[int(part["idx"])] = k
		k += 1
	return out

func _select_slot(i: int) -> void:
	slot_sel = clampi(i, 0, maxi(0, placed.size() - 1))
	if site:
		var c := candidates(slot_sel)
		focus_idx = c[0] if not c.is_empty() else -1
		rebuild()
		return
	if slot_sel < placed.size() and placed[slot_sel] >= 0:
		focus_idx = placed[slot_sel]
	else:
		var p := picks()
		var cands := candidates(slot_sel)
		focus_idx = p[slot_sel] if slot_sel < p.size() and p[slot_sel] >= 0 else (cands[0] if not cands.is_empty() else -1)
	rebuild()

func _focus_on(idx: int) -> void:
	focus_idx = idx
	rebuild()

func _set_qty(n: int) -> void:
	qty = clampi(n, 1, QTY_MAX)
	rebuild()

## "Place material" puts the focused instance at the head of the slot (an explicit pick), refused
## when the plan cannot fill the recipe with it (another slot needs it); "Craft" once all are placed.
func _on_cta() -> void:
	if site:
		_site_cta()
		return
	if all_placed():
		var uids: Array[String] = []
		var inv := _inv()
		for idx in picks():
			uids.append(inv.slots[idx].uid if idx >= 0 and inv.slots[idx] else "")
		host.start_with(rec, qty, uids)
		return
	place_focused()

func place_focused() -> bool:
	if focus_idx < 0 or slot_sel >= placed.size():
		return false
	var was := placed[slot_sel]
	placed[slot_sel] = focus_idx
	if not Crafting.picks_valid(_inv(), rec, picks()):
		placed[slot_sel] = was
		if host and host.player:
			host.player.notice("That one can't go here: the recipe would run short.")
		rebuild()
		return false
	var next := placed.find(-1)
	if next >= 0:
		_select_slot(next)
	else:
		rebuild()
	return true

# ---------------------------------------------------------------- drawing

func rebuild() -> void:
	if site != null and not is_instance_valid(site):
		site = null
		if host:
			host.hide_ui()
		return
	if host == null or host.player == null or (rec.is_empty() and site == null):
		return
	if site:
		_rebuild_site()
		return
	var inv := _inv()
	# Bag indices move when the bag changes: drop any placement that no longer fits its slot.
	for i in placed.size():
		if placed[i] >= 0 and not candidates(i).has(placed[i]):
			placed[i] = -1
	if focus_idx >= 0 and not candidates(slot_sel).has(focus_idx):
		focus_idx = -1
	var view := get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	add_theme_constant_override("separation", 6 if compact else 16)
	(get_node("PlaceSlots") as Control).custom_minimum_size = Vector2(108 if compact else 190, 0)
	(get_node("FocusCard") as Control).custom_minimum_size = Vector2(176 if compact else 380, 0)
	(get_node("ResultCard") as Control).custom_minimum_size = Vector2(186 if compact else 330, 0)
	(get_node("FocusCard") as Control).size_flags_stretch_ratio = 0.01
	(get_node("ResultCard") as Control).size_flags_stretch_ratio = 0.01
	_complete.text = "%d%%" % int(round(completion() * 100.0))
	_complete.add_theme_font_size_override("font_size", 30 if compact else 46)
	(_complete.get_parent().get_node("CompleteCap") as Label).add_theme_font_size_override("font_size", UiTokens.TYPE_MIN if compact else 17)
	# Chevrons.
	for c in _chevrons.get_children():
		_chevrons.remove_child(c)
		c.queue_free()
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		var ch := _Chevron.new()
		ch.name = "Chevron_%d" % i
		ch.title = LevelDisplay.nice_name(str((slots[i] as Dictionary).get("category", "")))
		var need := int((slots[i] as Dictionary).get("count", 1))
		ch.count_text = "%d/%d" % [need if placed[i] >= 0 else 0, need]
		ch.filled = placed[i] >= 0
		ch.chosen = i == slot_sel
		ch.compact = compact
		ch.custom_minimum_size = Vector2(0, 96 if compact else 150)
		ch.pressed.connect(_select_slot.bind(i))
		_chevrons.add_child(ch)
	# Slot header.
	var slot := _slot(slot_sel)
	var need := int(slot.get("count", 1))
	var cands := candidates(slot_sel)
	_slot_title.text = "%s   %d / %d" % [LevelDisplay.nice_name(str(slot.get("category", ""))), need if placed[slot_sel] >= 0 else 0, need]
	_slot_title.add_theme_font_size_override("font_size", 20 if compact else 32)
	var names: PackedStringArray = []
	for idx in cands:
		var d := inv.slots[idx].def()
		var nm := d.display_name if d and d.display_name != "" else str(inv.slots[idx].def_id)
		if not names.has(nm):
			names.append(nm)
	_slot_accepts.text = ("Accepts: " + ", ".join(names)) if not names.is_empty() else "Nothing in the bag fits this slot."
	_slot_accepts.add_theme_font_size_override("font_size", 13 if compact else 20)
	_slot_accepts.add_theme_color_override("font_color", UiTokens.TEXT if not names.is_empty() else UiTokens.LIFE)
	(_slot_title.get_parent().get_parent() as PanelContainer).add_theme_stylebox_override("panel", CraftUI.pad(Color(0.02, 0.025, 0.03, 0.9), 10 if compact else 22, 10 if compact else 22, 4 if compact else 10, 6 if compact else 12))
	# Candidates.
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_grid.columns = 2 if compact else 4
	var order := order_of(slot_sel)
	for idx in cands:
		var s: ItemStack = inv.slots[idx]
		var cell := _Candidate.new()
		cell.name = "Cand_%d" % idx
		cell.icon_tex = ItemIcons.texture(s.def_id)
		cell.level = s.level
		cell.pips = clampi(1 + maxi(0, ItemArt.rarity_order().find(str(ItemArt.rarity(s.def_id)))), 1, PIPS)
		cell.order = int(order.get(idx, 0))
		cell.focused = idx == focus_idx
		cell.locked = s.is_locked()
		cell.custom_minimum_size = Vector2(0, 96 if compact else 140)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.pressed.connect(_focus_on.bind(idx))
		_grid.add_child(cell)
	var primary := Crafting.primary_index(rec)
	_note.text = "Slot %d sets the result's traits · If crafting fails, materials are lost" % (primary + 1) if not compact else "Slot %d sets the traits" % (primary + 1)
	_note.add_theme_font_size_override("font_size", 13 if compact else 19)
	_note.custom_minimum_size = Vector2(0, 30 if compact else 48)
	_fill_focus(compact)
	_fill_result(compact)
	_qty_label.text = str(qty)
	(_qty_label.get_parent().get_parent() as Control).visible = true
	_qty_label.add_theme_font_size_override("font_size", 22 if compact else 30)
	var rate := Crafting.success_for(rec, host.player)
	_success.text = "%d%%" % int(round(rate * 100.0))
	_cta.text = "Craft" if all_placed() else "Place material"
	_cta.disabled = not all_placed() and focus_idx < 0
	var tool := Crafting.tool_block(inv, rec)
	if tool != "" and all_placed():
		_cta.text = tool  # RECIPETOOLS: the gate reads on the button, like a station gate
		_cta.disabled = true
	_cta.add_theme_font_size_override("font_size", 20 if compact else 30)
	_cta.custom_minimum_size = Vector2(0, 64 if compact else 72)
	_sync_assign(compact)
	for m in [_qty_label.get_parent().get_parent(), _success.get_parent().get_parent(), _cta.get_parent().get_parent()]:
		(m as MarginContainer).add_theme_constant_override("margin_top", 2 if compact else 8)
		(m as MarginContainer).add_theme_constant_override("margin_bottom", 2 if compact else 8)
	_success.add_theme_font_size_override("font_size", 15 if compact else 20)
	(_success.get_parent().get_child(0) as Label).add_theme_font_size_override("font_size", 15 if compact else 20)
	if host:
		host.call_deferred("_layout_safe")

# ---------------------------------------------------------------- Construction (site mode)

func open_site(s: ConstructionSite) -> void:
	site = s
	rec = {}
	qty = 1
	var n := s.slot_count()
	placed.clear()
	placed.resize(n)
	placed.fill(-1)
	picked.clear()
	for i in n:
		picked.append([])
	var first := 0
	for i in n:
		if s.deposited(i) < s.needed(i):
			first = i
			break
	_select_slot(first)

## Units still open in slot `i` once the deposited and the picked ones are counted.
func site_room(i: int) -> int:
	return site.needed(i) - site.deposited(i) - (picked[i] as Array).size()

## Units of bag index `idx` already picked in any slot (a stack of 3 can serve 3 picks).
func _picked_units(idx: int) -> int:
	var n := 0
	for col: Array in picked:
		n += col.count(idx)
	return n

## Tap on a candidate: pick one unit of it for this slot (next badge number), or drop it again.
func toggle_pick(idx: int) -> void:
	focus_idx = idx
	var col: Array = picked[slot_sel]
	if col.has(idx):
		col.erase(idx)
	elif site_room(slot_sel) > 0 and _picked_units(idx) < _inv().slots[idx].count:
		col.append(idx)
	rebuild()

## "Fill Automatically": every open unit of every slot gets the best eligible instance (highest
## level first), never more units of a stack than it holds.
func auto_fill() -> void:
	var inv := _inv()
	for i in picked.size():
		var cands := candidates(i)
		cands.sort_custom(func (a: int, b: int) -> bool: return inv.slots[a].level > inv.slots[b].level)
		for idx in cands:
			while site_room(i) > 0 and _picked_units(idx) < inv.slots[idx].count:
				(picked[i] as Array).append(idx)
	rebuild()

func has_picks() -> bool:
	for col: Array in picked:
		if not col.is_empty():
			return true
	return false

## "Place Material": the picked units go into the site's escrow (the exact instances, via
## ConstructionSite.deposit); once every slot is full the build timer starts.
func place_picks() -> int:
	var n := 0
	var inv := _inv()
	for i in picked.size():
		var uids: Array[String] = []
		for idx: int in picked[i]:
			uids.append(inv.slots[idx].uid if inv.slots[idx] else "")
		for k in (picked[i] as Array).size():
			# Indices can empty as units leave: find each unit again by uid, else by the slot's fit.
			var at := _uid_index(uids[k]) if uids[k] != "" else int(picked[i][k])
			if at >= 0 and site.deposit(i, at, World.player_name if World.player_name != "" else ""):
				n += 1
		(picked[i] as Array).clear()
	if site.materials_ready():
		site.building = true
	var next := -1
	for i in placed.size():
		if site.deposited(i) < site.needed(i):
			next = i
			break
	_select_slot(maxi(0, next) if next >= 0 else slot_sel)
	return n

func _uid_index(uid: String) -> int:
	var inv := _inv()
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].uid == uid:
			return i
	return -1

func _site_cta() -> void:
	if site.ready_to_finish():
		var p := host.player
		BuildFlow.complete(p, site)
		site = null
		host.hide_ui()
	elif site.materials_ready():
		site.building = true
		rebuild()
	elif has_picks():
		place_picks()
	else:
		auto_fill()

# ---------------------------------------------------------------- TRIBE M2a: assign a member

## The Assign button: shown when the tribe has members and the job can be handed off (a station
## recipe; a site), live once the picks are placed (a recipe) or every material is in (a site).
func _sync_assign(compact: bool) -> void:
	if _assign == null:
		return
	_assign.add_theme_font_size_override("font_size", 18 if compact else 24)
	_assign.custom_minimum_size = Vector2(0, 64 if compact else 72)
	if site:
		var who := TribeWork.worker_at(site)
		_assign.visible = not Tribe.members.is_empty()
		_assign.text = ("Stop " + who.name) if who else ("Assign" if compact else "Assign builder")
		_assign.disabled = who == null and (not site.materials_ready() or site.ready_to_finish())
		if who:
			_cta.text = "%s building…" % who.name
			_cta.disabled = true
		return
	_assign.visible = not Tribe.members.is_empty() and Crafting.station_id(rec) != ""
	_assign.text = "Assign…"
	_assign.disabled = not all_placed()

func assign_station() -> Node3D:
	return Crafting.nearest_station(host.player, StringName(Crafting.station_id(rec))) if host and host.player else null

## The picker's rows: every member with its skill, success, time, or why it can't.
func assign_rows() -> Array:
	var rows: Array = []
	var p := host.player if host else null
	for r in Tribe.members:
		var o := TribeWork.build_offer(r, site) if site else TribeWork.craft_offer(p, r, rec, assign_station(), picks())
		rows.append({"record": r, "text": TribeWork.offer_text(r, o), "why": str(o["why"])})
	return rows

func _on_assign() -> void:
	var p := host.player if host else null
	if p == null:
		return
	if site:
		var who := TribeWork.worker_at(site)
		if who:
			_refuse(TribeWork.cancel(p, who))
			rebuild()
			return
		TribeAssignPicker.open_on(host.get_parent(), "Assign a builder · %s" % str(site.bp().get("display_name", "site")), assign_rows(), _assign_to)
		return
	TribeAssignPicker.open_on(host.get_parent(), "Assign a crafter · %s" % host._output_name(rec), assign_rows(), _assign_to)

func _assign_to(r: TribeRecord) -> void:
	var p := host.player
	var why := ""
	if site:
		why = TribeWork.assign_build(r, site)
	else:
		var uids: Array[String] = []
		var inv := _inv()
		for idx in picks():
			uids.append(inv.slots[idx].uid if idx >= 0 and inv.slots[idx] else "")
		why = TribeWork.assign_craft(p, r, assign_station(), StringName(str(rec.get("id", ""))), uids)
	if _refuse(why):
		return
	p.notice("%s: %s" % [r.name, TribeWork.plate_text(r)])
	site = null
	host.hide_ui()

func _refuse(why: String) -> bool:
	if why != "" and host and host.player:
		host.player.notice(why)
	return why != ""

static func clock(seconds: float) -> String:
	var t := maxi(0, ceili(seconds))
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

func _process(_delta: float) -> void:
	if site != null and is_instance_valid(site) and visible and site.building:
		_timer_tick()

func _timer_tick() -> void:
	var lbl := _result.find_child("SiteTimer", true, false) as Label
	if lbl:
		lbl.text = clock(float(site.bp().get("work_seconds", 0.0)) - site.work_progress)
	if site.ready_to_finish() and _cta.text != "Finish":
		rebuild()

func _rebuild_site() -> void:
	var inv := _inv()
	var view := get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	for i in picked.size():  # bag indices move when the bag changes: drop picks that no longer fit
		var keep: Array = []
		for idx: int in picked[i]:
			if candidates(i).has(idx):
				keep.append(idx)
		picked[i] = keep
	add_theme_constant_override("separation", 6 if compact else 16)
	(get_node("PlaceSlots") as Control).custom_minimum_size = Vector2(108 if compact else 190, 0)
	(get_node("FocusCard") as Control).custom_minimum_size = Vector2(150 if compact else 320, 0)
	(get_node("ResultCard") as Control).custom_minimum_size = Vector2(186 if compact else 330, 0)
	(get_node("FocusCard") as Control).size_flags_stretch_ratio = 0.01
	(get_node("ResultCard") as Control).size_flags_stretch_ratio = 0.01
	(_complete.get_parent().get_node("CompleteCap") as Label).add_theme_font_size_override("font_size", UiTokens.TYPE_MIN if compact else 17)
	_complete.text = "%d%%" % int(round(site.materials_ratio() * 100.0))
	_complete.add_theme_font_size_override("font_size", 30 if compact else 46)
	for c in _chevrons.get_children():
		_chevrons.remove_child(c)
		c.queue_free()
	for i in site.slot_count():
		var ch := _Chevron.new()
		ch.name = "Chevron_%d" % i
		ch.title = Blueprints.slot_label(_slot(i))
		ch.count_text = "%d/%d" % [site.deposited(i), site.needed(i)]
		ch.filled = site.deposited(i) >= site.needed(i)
		ch.chosen = i == slot_sel
		ch.compact = compact
		ch.custom_minimum_size = Vector2(0, 96 if compact else 130)
		ch.pressed.connect(_select_slot.bind(i))
		_chevrons.add_child(ch)
	var slot := _slot(slot_sel)
	var cands := candidates(slot_sel)
	_slot_title.text = "%s   %d / %d" % [Blueprints.slot_label(slot), site.deposited(slot_sel) + (picked[slot_sel] as Array).size(), site.needed(slot_sel)]
	_slot_title.add_theme_font_size_override("font_size", 20 if compact else 30)
	var tags: PackedStringArray = []
	for t: Variant in slot.get("accepted_tags", []):
		tags.append(LevelDisplay.nice_name(str(t)))
	_slot_accepts.text = "Material: %s  ·  %s or higher  ·  accepts %s" % [Blueprints.slot_label(slot), LevelDisplay.label(int(slot.get("min_level", 1))), " / ".join(tags) if not tags.is_empty() else "anything"]
	_slot_accepts.add_theme_font_size_override("font_size", 12 if compact else 18)
	_slot_accepts.add_theme_color_override("font_color", UiTokens.TEXT if not cands.is_empty() or site.deposited(slot_sel) >= site.needed(slot_sel) else UiTokens.LIFE)
	(_slot_title.get_parent().get_parent() as PanelContainer).add_theme_stylebox_override("panel", CraftUI.pad(Color(0.02, 0.025, 0.03, 0.9), 10 if compact else 22, 10 if compact else 22, 4 if compact else 10, 6 if compact else 12))
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_grid.columns = 3 if compact else 5
	# Placed instances first, with a gold check; then the bag's eligible ones (badges = pick order).
	var placed_n := 0
	if slot_sel < site.slot_items.size():
		for st: ItemStack in site.slot_items[slot_sel]:
			var cell := _cand_cell(st, compact)
			cell.name = "Placed_%d" % placed_n
			cell.placed_check = true
			cell.disabled = true
			_grid.add_child(cell)
			placed_n += 1
	var col: Array = picked[slot_sel]
	for idx in cands:
		var cell := _cand_cell(inv.slots[idx], compact)
		cell.name = "Cand_%d" % idx
		cell.order = col.find(idx) + 1
		cell.focused = idx == focus_idx
		cell.pressed.connect(toggle_pick.bind(idx))
		_grid.add_child(cell)
	_note.text = "Placed materials stay in the site until it is finished or cancelled."
	_note.add_theme_font_size_override("font_size", 12 if compact else 17)
	_note.custom_minimum_size = Vector2(0, 30 if compact else 44)
	_fill_focus(compact)
	_fill_site_result(compact)
	(_qty_label.get_parent().get_parent() as Control).visible = false
	_success.text = "100%"  # ASSUMPTION: spec 30 gives construction no failure roll
	_success.add_theme_font_size_override("font_size", 15 if compact else 20)
	(_success.get_parent().get_child(0) as Label).add_theme_font_size_override("font_size", 15 if compact else 20)
	if site.ready_to_finish():
		_cta.text = "Finish"
	elif site.materials_ready():
		_cta.text = "Building…" if site.building else "Start build"
	elif has_picks():
		_cta.text = "Place Material"
	else:
		_cta.text = "Fill Automatically"
	_cta.disabled = site.materials_ready() and site.building and not site.ready_to_finish()
	_sync_assign(compact)
	_cta.add_theme_font_size_override("font_size", 18 if compact else 26)
	_cta.custom_minimum_size = Vector2(0, 64 if compact else 72)
	if host:
		host.call_deferred("_layout_safe")

func _cand_cell(st: ItemStack, compact: bool) -> _Candidate:
	var cell := _Candidate.new()
	cell.icon_tex = ItemIcons.texture(st.def_id)
	cell.level = st.level
	cell.pips = clampi(1 + maxi(0, ItemArt.rarity_order().find(str(ItemArt.rarity(st.def_id)))), 1, PIPS)
	cell.locked = st.is_locked()
	cell.custom_minimum_size = Vector2(64, 96 if compact else 120)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cell

func _fill_site_result(compact: bool) -> void:
	for c in _result.get_children():
		_result.remove_child(c)
		c.queue_free()
	var bp := site.bp()
	var cap := CraftUI._label("Expected Result", 12 if compact else 15, UiTokens.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_result.add_child(_pad(cap, 10, 2 if compact else 6))
	var lvl := int((host.player.skills as SkillState).level_of("construction")) if host.player.get("skills") else 0
	var name := CraftUI._label("", 16 if compact else 26, UiTokens.TEXT)
	name.name = "ResultName"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text = "%s  %s" % [str(bp.get("display_name", "Station")), LevelDisplay.label(site.preview_level(lvl))] if site.materials_ready() else "Select all materials to preview"
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.clip_text = false
	name.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_result.add_child(_pad(name, 8, 2 if compact else 6))
	# ASSUMPTION: blueprints name no station to build at; the requirement shown is the blueprint's
	# Construction level (spec 30 §1).
	var req := CraftUI._label("Construction %s" % LevelDisplay.label(int(bp.get("construction_level", 1))), 12 if compact else 18, UiTokens.GOLD if lvl >= int(bp.get("construction_level", 1)) else UiTokens.LIFE)
	req.name = "SiteRequirement"
	req.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_child(_pad(req, 8, 2))
	var timer := CraftUI._label(clock(float(bp.get("work_seconds", 0.0)) - site.work_progress), 18 if compact else 30, UiTokens.TEXT)
	timer.name = "SiteTimer"
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_child(_pad(timer, 8, 2 if compact else 8))

func _fill_focus(compact: bool) -> void:
	for c in _focus.get_children():
		_focus.remove_child(c)
		c.queue_free()
	var inv := _inv()
	if focus_idx < 0 or inv.slots[focus_idx] == null:
		var none := CraftUI._label("Pick a material.", 16, UiTokens.MUTED)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_focus.add_child(_pad(none, 10, 20))
		return
	var s: ItemStack = inv.slots[focus_idx]
	var d := s.def()
	var card := VBoxContainer.new()
	card.name = "FocusParchment"
	card.add_theme_constant_override("separation", 0)
	var parch := PanelContainer.new()
	parch.add_theme_stylebox_override("panel", CraftUI.pad(UiTokens.PARCHMENT_TOP, 12 if compact else 18, 12 if compact else 18, 8, 8))
	parch.add_child(card)
	_focus.add_child(parch)
	var nm := CraftUI._label(d.display_name if d and d.display_name != "" else str(s.def_id), 18 if compact else 30, UiTokens.PARCHMENT_INK)
	nm.name = "FocusName"
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	card.add_child(nm)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var ic := TextureRect.new()
	ic.texture = ItemIcons.texture(s.def_id)
	ic.custom_minimum_size = Vector2(40, 40) if compact else Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(ic)
	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", -4)
	txt.add_child(CraftUI._label(LevelDisplay.nice_name(str(_slot(slot_sel).get("category", ""))), 13 if compact else 20, Color(UiTokens.PARCHMENT_INK, 0.7)))
	var lv := CraftUI._label(LevelDisplay.label(s.level), 18 if compact else 30, UiTokens.PARCHMENT_INK)
	lv.name = "FocusLevel"
	txt.add_child(lv)
	row.add_child(txt)
	card.add_child(row)
	if s.max_durability > 0:
		var dur := CraftUI._label("Durability %d / %d" % [s.durability, s.max_durability], 13 if compact else 22, UiTokens.PARCHMENT_INK)
		card.add_child(dur)
	var chips := trait_chips(s, compact)
	chips.name = "FocusTraits"
	_focus.add_child(_pad(chips, 10 if compact else 14, 12))

func _fill_result(compact: bool) -> void:
	for c in _result.get_children():
		_result.remove_child(c)
		c.queue_free()
	var inv := _inv()
	var out := Crafting.preview(inv, rec, picks())
	var cap := CraftUI._label("Expected result", 12 if compact else 15, UiTokens.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_result.add_child(_pad(cap, 10, 2 if compact else 6))
	var out_id := StringName(str(CraftUI.output_row(inv, rec, picks()).get("id", "")))
	var ic := TextureRect.new()
	ic.texture = ItemIcons.texture(out.def_id if out else out_id)
	ic.custom_minimum_size = Vector2(0, 80)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.visible = not compact  # a landscape phone has no height for it; the name says what it makes
	_result.add_child(ic)
	var name := CraftUI._label("", 18 if compact else 28, UiTokens.TEXT)
	name.name = "ResultName"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d := Data.item(out.def_id if out else out_id)
	name.text = "%s  %s" % [d.display_name if d else str(out_id), LevelDisplay.label(out.level) if out else LevelDisplay.NONE]
	_result.add_child(_pad(name, 8, 0 if compact else 4))
	if out and out.max_durability > 0:
		var dur := CraftUI._label("Durability %d / %d" % [out.durability, out.max_durability], 13 if compact else 20, UiTokens.TEXT)
		_result.add_child(_pad(dur, 14, 4))
	var need := Crafting.tool_need(rec)
	if not need.is_empty():
		var t := Crafting.recipe_tool(inv, rec)
		var tl := CraftUI._label(Crafting.tool_block(inv, rec) if t == null else "Uses %s (1 durability)" % t.def().display_name, 13 if compact else 18, UiTokens.DANGER if t == null else UiTokens.MUTED)
		tl.name = "ResultTool"
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_result.add_child(_pad(tl, 14, 2))
	var chips := trait_chips(out, compact) if out else HFlowContainer.new()
	chips.name = "ResultTraits"
	_result.add_child(_pad(chips, 14, 6))
	var from := CraftUI._label("Traits come from slot %d only" % (Crafting.primary_index(rec) + 1), 12 if compact else 14, UiTokens.MUTED)
	from.visible = not compact  # the centre column's note says it there
	_result.add_child(_pad(from, 14, 2))

## Trait chips for an instance (§5): rare (green ✦), positive (gold +), negative (grey −), from
## InvAttributes (inv_ui.json classes, rules.json rare list).
static func trait_chips(s: ItemStack, compact: bool = false) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var sec := InvAttributes.sections(s)
	for cls in ["rare", "positive", "negative"]:
		for row: Dictionary in sec[cls]:
			flow.add_child(chip(InvAttributes.line(row), StringName(cls), compact))
	if flow.get_child_count() == 0:
		var none := CraftUI._label("No traits", 12 if compact else 15, UiTokens.MUTED)
		none.clip_text = false
		none.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		flow.add_child(none)
	return flow

static func chip(text: String, polarity: StringName, compact: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Chip"
	p.add_theme_stylebox_override("panel", UiTokens.trait_chip_style(polarity))
	var l := CraftUI._label("%s %s" % [UiTokens.trait_chip_prefix(polarity), text], 12 if compact else 17, UiTokens.trait_chip_fg(polarity))
	l.clip_text = false
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	p.add_child(l)
	return p

func _round_btn(glyph: String, cb: Callable) -> Button:
	var b := CraftUI.mk_btn(glyph, cb, Vector2(64, 64), "ghost")
	var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
	for k in ["normal", "hover", "pressed"]:
		var s := (b.get_theme_stylebox(k) as StyleBoxFlat)
		s.set_corner_radius_all(32)
		s.bg_color = Color(0.25, 0.27, 0.29, 1.0) if k != "pressed" else Color(0.18, 0.19, 0.2, 1.0)
		s.set_border_width_all(0)
	sb.set_corner_radius_all(32)
	b.add_theme_font_size_override("font_size", 30)
	return b

func _pad(c: Control, side: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m

# ---------------------------------------------------------------- drawn pieces

## One recipe slot as a chevron (a shield: square top, V bottom): name, n / need in a dark box,
## OK_GREEN once placed, gold outline on the slot being filled.
class _Chevron extends Button:
	var title := ""
	var count_text := ""
	var filled := false
	var chosen := false
	var compact := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		flat = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var v := minf(28.0, h * 0.2)
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h - v), Vector2(w * 0.5, h), Vector2(0, h - v)])
		var fill := UiTokens.OK_GREEN if filled else Color(0.17, 0.18, 0.19, 1.0)
		draw_colored_polygon(pts, fill)
		var rim := pts.duplicate()
		rim.append(pts[0])
		draw_polyline(rim, UiTokens.GOLD if chosen else Color(1, 1, 1, 0.12), 4.0 if chosen else 1.5, true)
		var font := UiTokens.ui_face()
		var fs := 18 if compact else 30
		var ink := Color(0.06, 0.12, 0.06) if filled else UiTokens.TEXT
		UiTokens.draw_centered(self, font, Vector2(w * 0.5, h * 0.24), UiTokens.ellipsis(font, title, w - 12.0, fs), fs, ink)
		var box := Rect2(Vector2(w * 0.08, h * 0.42), Vector2(w * 0.84, h * 0.3))
		draw_rect(box, Color(0.03, 0.06, 0.04, 0.92) if filled else Color(0.02, 0.025, 0.03, 0.95))
		UiTokens.draw_centered(self, font, box.get_center(), count_text, fs, UiTokens.TEXT)

## One candidate instance: icon, "Lv. n" top-right, quality pips, a gold order badge when the slot
## uses it, gold brackets and a gold wash when focused.
class _Candidate extends Button:
	var icon_tex: Texture2D
	var level := 1
	var pips := 1
	var order := 0
	var focused := false
	var locked := false
	var placed_check := false  ## Construction: already in the site's escrow

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		flat = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.20, 0.18, 0.10, 1.0) if focused else (Color(0.10, 0.09, 0.06, 1.0) if order > 0 else Color(0.06, 0.065, 0.07, 1.0)))
		draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)
		var font := UiTokens.ui_face()
		var fs := clampi(int(size.y * 0.11), UiTokens.TYPE_MIN, 15)
		var lv := LevelDisplay.label(level)
		var lw := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x - lw - 8.0, fs + 6.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTokens.MUTED)
		var s := minf(size.y * 0.42, size.x * 0.5)
		if icon_tex:
			draw_texture_rect(icon_tex, Rect2(size * 0.5 - Vector2(s, s) * 0.5 - Vector2(0, size.y * 0.04), Vector2(s, s)), false, Color(1, 1, 1, 0.55 if locked else 1.0))
		var pw := maxf(5.0, size.y * 0.05)
		var gap := pw * 0.5
		var total := PIPS * pw + (PIPS - 1) * gap
		var py := size.y * 0.78
		for i in PIPS:
			draw_rect(Rect2(Vector2(size.x * 0.5 - total * 0.5 + i * (pw + gap), py), Vector2(pw, pw)), UiTokens.GOLD if i < pips else Color(0.45, 0.45, 0.45))
		if order > 0:
			var bc := Vector2(maxf(14.0, size.y * 0.14), maxf(14.0, size.y * 0.14))
			var br := maxf(11.0, size.y * 0.09)
			draw_circle(bc, br, UiTokens.GOLD)
			UiTokens.draw_centered(self, UiTokens.ui_face(UiTokens.WEIGHT_BOLD), bc, str(order), maxi(UiTokens.TYPE_MIN, int(br * 1.2)), UiTokens.CTA_INK)
		if placed_check:
			var cc := Vector2(size.x - maxf(14.0, size.y * 0.14), size.y - maxf(14.0, size.y * 0.14))
			draw_circle(cc, maxf(11.0, size.y * 0.09), UiTokens.GOLD)
			var k := maxf(5.0, size.y * 0.05)
			draw_polyline(PackedVector2Array([cc + Vector2(-k, 0), cc + Vector2(-k * 0.3, k * 0.7), cc + Vector2(k, -k * 0.7)]), UiTokens.CTA_INK, 2.5, true)
		if focused:
			UiTokens.draw_brackets(self, r.grow(-4.0), UiTokens.GOLD, minf(22.0, size.y * 0.16), UiTokens.BRACKET_W)
