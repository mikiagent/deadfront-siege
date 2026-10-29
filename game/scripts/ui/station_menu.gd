class_name StationMenu
extends Control
## The radial over a tapped building (CRAFTRADIAL, docs/design/ui-redesign-spec.md §7 D4, Durango's
## station wheel): a dark ring around the station with its wedges as flat-top hexes, the station's
## main action on top (CRAFT, COOK, DRY, PEN, OPEN, SLEEP: ACTIONS), then PACKAGE (pack it back into its
## kit to move it, BuildPlacer.pack_up_node) and REMOVE (red; demolish, a second tap confirms). The
## station's name sits in the ring's centre; a card at the top left gives its name and level,
## durability and type; under the ring a horizontally scrolling row lists what the station makes
## (its recipes' outputs), each slot opening that recipe in the craft panel.
## Tapping a hex emits action_chosen; tapping elsewhere walks and the menu closes.

signal action_chosen(station: Node3D, action_id: StringName)

const HEX_SIZE := 64.0
const GAP := 12.0
const CLOSE_RANGE := 3.6
const MARGIN := 8.0
const RING_RADIUS := 1.15
const RING_WIDTH := 0.07
const EXPAND_SECONDS := 0.22

## Per-station hexes. icon resolves through data/icons_manifest.json and is drawn as a white
## symbol (actions are white); glyph is the plain-letter fallback, never a system emoji.
## # ASSUMPTION (docs silent): the cooking stations (stone grill = the "oven", crock pot, steamer,
## smoker) open their recipes as COOK, the drying rack as DRY; the pen and the basket (the "chest")
## lead with PEN / OPEN.
const ACTIONS := {
	&"tent": [{"id": &"sleep", "label": "SLEEP", "icon": "sleeping", "glyph": "Z"}],
	&"canvas_tent": [{"id": &"sleep", "label": "SLEEP", "icon": "sleeping", "glyph": "Z"}],
	&"straw_roll": [{"id": &"sleep", "label": "SLEEP", "icon": "sleeping", "glyph": "Z"}],
	&"workbench": [{"id": &"craft", "label": "CRAFT", "icon": "hammer", "glyph": "C"}],
	&"bonfire": [{"id": &"cook", "label": "COOK", "icon": "skewer", "glyph": "C"}],
	&"campfire": [{"id": &"cook", "label": "COOK", "icon": "skewer", "glyph": "C"}],
	&"stone_grill": [{"id": &"craft", "label": "COOK", "icon": "skewer", "glyph": "C"}],
	&"crock_pot": [{"id": &"craft", "label": "COOK", "icon": "skewer", "glyph": "C"}],
	&"steamer": [{"id": &"craft", "label": "COOK", "icon": "skewer", "glyph": "C"}],
	&"smoker": [{"id": &"craft", "label": "COOK", "icon": "skewer", "glyph": "C"}],
	&"drying_rack": [{"id": &"craft", "label": "DRY", "icon": "drying_rack_kit", "glyph": "D"}],
	&"makeshift_taming_pen": [{"id": &"pen", "label": "PEN", "icon": "makeshift_taming_pen", "glyph": "P"}],
	&"basket": [{"id": &"open", "label": "OPEN", "icon": "basket_kit", "glyph": "O"}],
}
## The two wedges every placed building gets after its own actions.
const PACKAGE := {"id": &"package", "label": "PACKAGE", "icon": "basket_kit", "glyph": "P"}
const REMOVE := {"id": &"remove", "label": "REMOVE", "icon": "", "glyph": "✕"}
## The info card's type line, by the main wedge's label.
const TYPES := {"CRAFT": "Crafting station", "COOK": "Cooking station", "DRY": "Drying station",
	"PEN": "Animal pen", "OPEN": "Storage", "SLEEP": "Bed"}
## Menu anchor height above the station origin, per station kind.
const HEIGHTS := {
	&"workbench": 1.55,
	&"bonfire": 1.25,
	&"campfire": 1.25,
	&"drying_rack": 1.5,
	&"crock_pot": 1.45,
}
const DEFAULT_HEIGHT := 1.45
## Kingdom Rush layout (owner 2026-10-28): six fixed slots around the station, the same slot for the
## same action every time. Angles in degrees from +x, screen y down: 0 top, 1 top-right, 2 bottom-right,
## 3 bottom, 4 bottom-left, 5 top-left.
const SLOT_ANGLES := [-90.0, -30.0, 30.0, 90.0, 150.0, -150.0]
## Fixed slots by action; the station's own main action takes the top (0); others take the first free.
const SLOT_OF := {&"package": 4, &"remove": 2, &"wood": 1, &"collect": 5, &"take_back": 3, &"cauterise": 3}
const OPEN_SECONDS := 0.15
const STAGGER := 0.03
## Ring radius in hexes: wide enough that neighbouring slots (60 degrees apart) never touch.
const RADIUS_HEX := 1.55

var station: Node3D
var player: Player
## A fire's state line under the ring ("Fuel 4:12 · Burning · Durability 288/300"); stations that
## have no info_text() keep the old look with no line.
var info_label: Label
var _buttons: Array[HexButton] = []
## The top-left card (icon, "Workbench Lv 3", durability, type) and the output row under the ring.
var info_card: PanelContainer
var output_row: ScrollContainer
## REMOVE was tapped once: the next tap demolishes (no hover-only confirm on a phone).
var remove_armed: bool = false
var _ring_center := Vector2.ZERO
var _anchor := Vector2.ZERO
var _anchored := false
var _ring_radius := 0.0
var _ring3d: MeshInstance3D
var _expand_elapsed: float = 0.0

## The hexes a station offers right now. Data-driven so new stations/actions slot in here.
static func actions_for(sid: StringName, p: Player) -> Array:
	var out: Array = []
	var list: Array = ACTIONS.get(sid, [])
	if list.is_empty() and not Crafting.recipes_for_station(sid).is_empty():
		list = [{"id": &"craft", "label": "CRAFT", "icon": "hammer", "glyph": "C"}]
	for a in list:
		out.append((a as Dictionary).duplicate())
	# FIREPITS / FIREFUEL: any fire takes wood; FUEL opens its fuel sheet (branches and logs).
	if sid in [&"bonfire", &"campfire"]:
		out.append({"id": &"wood", "label": "FUEL", "icon": "wood_log", "glyph": "W"})
	if sid == &"bonfire" and p != null and p.statuses \
			and (p.statuses.has(&"bleed") or p.statuses.has(&"deep_bleed")):
		out.append({"id": &"cauterise", "label": "CAUTERISE", "icon": "bonfire_kit", "glyph": "B"})
	if not out.is_empty():  # a placed building: it can go back into its kit, or come down
		if BuildPlacer.kit_for(sid) != &"":
			out.append(PACKAGE.duplicate())
		out.append(REMOVE.duplicate())
	return out

## The hexes that station can actually offer: a fire that is not burning (the cold stone pit, a
## burnt-out fire) drops COOK and says why, instead of opening a craft flow that would refuse.
static func filter_actions(st: Node3D, actions: Array) -> Array:
	var out: Array = []
	var cook_why := ""
	if st != null and is_instance_valid(st) and st.has_method("cook_block_reason"):
		cook_why = str(st.call("cook_block_reason"))
	for a: Variant in actions:
		var aid := str((a as Dictionary).get("id", ""))
		if cook_why != "" and aid == "cook":
			continue
		out.append(a)
	return out

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inside the tree set_anchors_preset keeps the current (empty) rect; reset the offsets too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func show_for(st: Node3D, actions: Array) -> void:
	station = st
	remove_armed = false
	_anchored = false
	_clear()
	# A fire that is not burning offers no COOK (and a full fire no LOAD WOOD), whatever list the
	# caller hands over.
	for a: Variant in filter_actions(st, actions):
		var row: Dictionary = a
		var btn := HexButton.new(HEX_SIZE)
		btn.focus_mode = Control.FOCUS_ALL  # controller menu (HexButton defaults out of focus)
		# HexButton only emits after receiving its own press and release. Because this is
		# created after the station press, that opening gesture cannot activate the action.
		# Station entry is an action, so the symbol is drawn white. Item thumbnails live on the gather radial.
		var icon_id := str(row.get("icon", ""))
		btn.icon = ItemIcons.texture(StringName(icon_id)) if icon_id != "" else null
		btn.color_icon = false
		btn.glyph = "" if btn.icon else str(row.get("glyph", "?"))
		btn.bottom_text = str(row.get("label", ""))
		var aid := StringName(str(row.get("id", "")))
		btn.name = "Wedge_" + str(aid)
		btn.set_meta("aid", aid)  # the slot key; a name can get a suffix while the old menu frees
		btn.rim_color = UiTokens.GOLD if _buttons.is_empty() else UiTokens.HUD_RIM  # B4: the station's main action is gold-rimmed (COOK)
		btn.rim_width = 4.0 if _buttons.is_empty() else 3.0
		if aid == &"remove":
			btn.rim_color = UiTokens.LIFE
			btn.glyph_color = UiTokens.LIFE
		HudField.fit(btn, hex_px(get_viewport_rect().size))
		btn.pressed.connect(_on_pressed.bind(aid))
		add_child(btn)
		_buttons.append(btn)
	_show_info()
	_build_outputs()
	visible = true
	_expand_elapsed = 0.0
	_show_ring3d(0.22)
	_update_screen_pos()
	UiTokens.focus_first(_buttons)

## Skip the opening animation (tests, shots): every hex at its slot now.
func snap_open() -> void:
	_expand_elapsed = 1.0
	_update_screen_pos()

func station_kind() -> StringName:
	if station == null or not is_instance_valid(station):
		return &""
	return StringName(Crafting.node_station_id(station))

## The top-left card: icon, "Name Lv n", durability, type, and the station's own state line
## (FIREPITS rule 3: a fire shows the fuel left; `info_label` holds it, from the station's info_text()).
func _show_info() -> void:
	if info_card != null and is_instance_valid(info_card):
		info_card.queue_free()
	info_card = null
	info_label = null
	if station == null or not is_instance_valid(station):
		return
	var view := get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	var card := PanelContainer.new()
	card.name = "StationCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.HUD_FILL
	sb.border_color = Color(UiTokens.GOLD, 0.5)
	sb.border_width_left = 3
	sb.set_content_margin_all(8.0)
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var kind := station_kind()
	var ic := TextureRect.new()
	ic.texture = ItemIcons.texture(BuildPlacer.kit_for(kind)) if BuildPlacer.kit_for(kind) != &"" else null
	ic.custom_minimum_size = Vector2(40, 40) if compact else Vector2(56, 56)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var lv: Variant = station.get("station_level")
	var name := _title() + ("  " + LevelDisplay.label(int(lv)) if lv != null else "")
	col.add_child(_card_label(name, UiTokens.body(view) + 2, UiTokens.TEXT, "CardName"))
	var dur := durability_text()
	if dur != "":
		col.add_child(_card_label(dur, UiTokens.meta(view), UiTokens.MUTED, "CardDurability"))
	var main := str(_buttons[0].bottom_text) if not _buttons.is_empty() else ""
	col.add_child(_card_label(str(TYPES.get(main, "Building")), UiTokens.meta(view), UiTokens.GOLD, "CardType"))
	if station.has_method("info_text") and str(station.call("info_text")) != "":
		info_label = _card_label(str(station.call("info_text")), UiTokens.meta(view), UiTokens.TEXT, "StationInfo")
		col.add_child(info_label)
	add_child(card)
	info_card = card

static func _card_label(text: String, px: int, c: Color, n: String) -> Label:
	var l := Label.new()
	l.name = n
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	return l

## "Durability 288 / 300" from the station's StructureHealth (or a fire's own durability), "" when none.
func durability_text() -> String:
	var h := StructureHealth.of(station, false)
	if h != null:
		return "Durability %d / %d" % [int(h.hp), int(h.max_hp)]
	if station.get("durability") != null and float(station.get("durability")) > 0.0:
		return "Durability %d" % int(float(station.get("durability")))
	return ""

## What the station makes: one slot per distinct recipe output (recipes.json), scrolling sideways.
static func outputs_for(sid: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for rec in Crafting.recipes_for_station(sid):
		var oid := str((rec.get("output", {}) as Dictionary).get("id", ""))
		if oid == "" or seen.has(oid):
			continue
		seen[oid] = true
		out.append({"recipe": StringName(str(rec.get("id", ""))), "item": StringName(oid)})
	return out

func _build_outputs() -> void:
	if output_row != null and is_instance_valid(output_row):
		output_row.queue_free()
	output_row = null
	var rows := outputs_for(station_kind())
	if rows.is_empty():
		return
	var scroll := ScrollContainer.new()
	scroll.name = "OutputRow"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.add_theme_stylebox_override("panel", CraftUI.flat(Color(UiTokens.HUD_FILL, 0.75)))
	var box := HBoxContainer.new()
	box.name = "Outputs"
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	var px := hex_px(get_viewport_rect().size) * (1.0 if UiTokens.is_compact(get_viewport_rect().size) else 0.85)
	for r: Dictionary in rows:
		var slot := OutputSlot.new()
		slot.name = "Out_" + str(r["recipe"])
		slot.item = r["item"]
		slot.recipe = r["recipe"]
		slot.custom_minimum_size = Vector2(px, px)
		slot.pressed.connect(_on_output.bind(r["recipe"]))
		box.add_child(slot)
	add_child(scroll)
	output_row = scroll

## An output slot: that recipe opens in the craft panel (the station's list, its detail page up).
func _on_output(rid: StringName) -> void:
	var sid := station_kind()
	var cui: Variant = player.get("craft_ui") if player else null
	hide_menu()
	if cui != null and cui.has_method("show_recipe"):
		cui.show_recipe(sid, rid)

func hide_menu() -> void:
	for n: Node in [info_card, output_row]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	info_card = null
	output_row = null
	info_label = null
	remove_armed = false
	_clear()
	station = null
	visible = false
	_expand_elapsed = 0.0
	if _ring3d:
		_ring3d.visible = false

func _on_pressed(aid: StringName) -> void:
	var st := station
	# FIREFUEL: FUEL opens the fire's fuel sheet; with no HUD (labs, bare tests) it loads one piece of
	# wood in place and keeps the menu open, so its fuel line updates.
	if aid == &"wood" and st != null and is_instance_valid(st) and st.has_method("load_wood"):
		var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
		if hud != null and hud.has_method("open_fire_fuel") and st is Bonfire:
			hide_menu()
			hud.call("open_fire_fuel", st, player)
			return
		st.call("load_wood", player)
		_show_info()
		return
	if aid == &"cook" and st != null and is_instance_valid(st) and st.has_method("can_cook") and not bool(st.call("can_cook")):
		if player != null:
			player.notice("Can't cook: %s" % str(st.call("cook_block_reason")).to_lower())
		return
	# REMOVE asks first: the wedge turns into CONFIRM and only a second tap demolishes.
	if aid == &"remove" and not remove_armed:
		remove_armed = true
		for b in _buttons:
			if b.name == "Wedge_remove":
				b.bottom_text = "CONFIRM"
				b.fill = Color(UiTokens.LIFE, 0.55)
				b.queue_redraw()
		if player != null:
			player.notice("Tap REMOVE again to demolish the %s." % _title().to_lower())
		queue_redraw()
		return
	hide_menu()
	action_chosen.emit(st, aid)

func _clear() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			if b.get_parent() == self:
				remove_child(b)  # detach first: the next menu's Wedge_* names must not collide
			b.queue_free()
	_buttons.clear()

func _process(delta: float) -> void:
	if not visible:
		return
	if station == null or not is_instance_valid(station):
		hide_menu()
		return
	# The craft sheet covers the station flow; walking away dismisses.
	var cui: Variant = player.get("craft_ui") if player else null
	if cui != null and cui is Control and (cui as Control).visible:
		hide_menu()
		return
	# Ground taps start navigation and dismiss the menu. Do not also close solely because
	# the first station tap came from farther than CLOSE_RANGE; that made the ring flash
	# for one frame at the opening camp.
	if player and player.nav_active:
		hide_menu()
		return
	_expand_elapsed = minf(1.0, _expand_elapsed + delta)
	var t := ease(minf(1.0, _expand_elapsed / EXPAND_SECONDS), 0.35)
	_show_ring3d(lerpf(0.22, RING_RADIUS, t))
	_update_screen_pos(delta)

## Where the info card sits: under the HUD's top-left block (desktop) or right of the left column
## (landscape phone), inside the safe area.
func _card_spot(view: Vector2, safe: Vector4) -> Vector2:
	if UiTokens.is_compact(view) and not UiTokens.is_narrow(view):
		return Vector2(safe.w + 8.0, safe.z + 116.0)  # under the vitals, over the (usually empty) whistle row
	return Vector2(safe.w + 12.0, safe.z + (100.0 if UiTokens.is_narrow(view) else 120.0))


## Slot index per button, in button order: fixed per action kind, the main action on top.
static func slots_for(ids: Array) -> Array[int]:
	var out: Array[int] = []
	var used := {}
	for aid: Variant in ids:
		var s: int = int(SLOT_OF.get(StringName(str(aid)), -1))
		if s >= 0 and used.has(s):
			s = -1
		out.append(s)
		if s >= 0:
			used[s] = true
	for i in out.size():
		if out[i] >= 0:
			continue
		for s in [0, 1, 5, 3, 2, 4]:
			if not used.has(s):
				out[i] = s
				used[s] = true
				break
	return out

## Hex top-left positions for `slots` around `center` (radius r, hex hx).
static func slot_positions(center: Vector2, slots: Array[int], r: float, hx: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s in slots:
		var a := deg_to_rad(float(SLOT_ANGLES[clampi(s, 0, 5)]))
		out.append(center + Vector2(cos(a), sin(a)) * r - Vector2(hx, hx) * 0.5)
	return out

## The station's anchor on screen. It follows a moving camera smoothly and holds still (no sub-pixel
## re-solve) once the camera does: a jittering anchor shook the old orbiting ring.
func _anchor_now(delta: float) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null or station == null:
		return _anchor
	var sid := StringName(str(station.get("station_id"))) if station.get("station_id") != null else &""
	var world := station.global_position + Vector3(0.0, float(HEIGHTS.get(sid, DEFAULT_HEIGHT)), 0.0)
	if cam.is_position_behind(world):
		return _anchor
	var target := cam.unproject_position(world)
	if not _anchored:
		_anchor = target
		_anchored = true
	elif _anchor.distance_to(target) > 0.75:
		_anchor = _anchor.lerp(target, clampf(delta * 14.0, 0.0, 1.0)) if delta > 0.0 else target
	return _anchor

func _update_screen_pos(delta: float = 0.0) -> void:
	if station == null:
		return
	var anchor := _anchor_now(delta)
	var view := get_viewport_rect().size
	var safe := UiTokens.safe_insets(get_viewport())
	var hx := hex_px(view)
	var r := hx * RADIUS_HEX
	if info_card != null and is_instance_valid(info_card):
		info_card.reset_size()
		info_card.position = _card_spot(view, safe)
	var slots := slots_for(_buttons.map(func (b: HexButton) -> String: return str(b.get_meta("aid", ""))))
	# The whole cluster (all six slot hexes, used or not, so it never shifts with the action count)
	# slides inside the safe area as one; single hexes are never clamped on their own.
	var all6: Array[int] = [0, 1, 2, 3, 4, 5]
	var box := Rect2(anchor, Vector2.ZERO)
	for p in slot_positions(anchor, all6, r, hx):
		box = box.merge(Rect2(p, Vector2(hx, hx)))
	var bounds := Rect2(Vector2(safe.w + 4.0, safe.z + 4.0), view - Vector2(safe.w + safe.x + 8.0, safe.z + safe.y + 8.0))
	var phone := UiTokens.is_compact(view) and not UiTokens.is_narrow(view)
	var row_h := 0.0
	if output_row != null and is_instance_valid(output_row):
		row_h = (output_row.get_child(0) as Control).get_combined_minimum_size().y
		if phone:  # the row takes the bottom band: the cluster stays above it
			bounds.size.y = maxf(box.size.y, view.y - safe.y - row_h - 34.0 - 4.0 - bounds.position.y)
	var shift := Vector2.ZERO
	shift.x = clampf(box.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - box.size.x)) - box.position.x
	shift.y = clampf(box.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - box.size.y)) - box.position.y
	var center := anchor + shift
	_ring_center = center
	# Open: each hex flies out from the station along its slot (ease-out, a small stagger).
	var spots := slot_positions(center, slots, r, hx)
	for i in _buttons.size():
		var t := clampf((_expand_elapsed - float(i) * STAGGER) / OPEN_SECONDS, 0.0, 1.0)
		t = 1.0 - pow(1.0 - t, 3.0)
		HudField.fit(_buttons[i], hx)
		_buttons[i].position = center - Vector2(hx, hx) * 0.5 + (spots[i] + Vector2(hx, hx) * 0.5 - center) * t
		_buttons[i].modulate.a = t
	_ring_radius = r * clampf(_expand_elapsed / OPEN_SECONDS, 0.0, 1.0)
	if output_row != null and is_instance_valid(output_row):
		var slot := (output_row.get_child(0) as Control).get_combined_minimum_size()
		var left := safe.w + (330.0 if phone else 8.0)
		var right := view.x - safe.x - 8.0 - (280.0 if phone else 0.0)
		var w := minf(slot.x, minf(right - left, 760.0))
		var y := view.y - safe.y - slot.y - 34.0 if phone else minf(center.y + r + hx * 0.675 + 10.0, view.y - safe.y - slot.y - 34.0)
		output_row.position = Vector2(clampf(center.x - w * 0.5, left, maxf(left, right - w)), y)
		output_row.size = Vector2(w, slot.y)
	queue_redraw()

func _draw() -> void:
	if station == null or _buttons.is_empty() or _ring_radius <= 1.0:
		return
	var hx := hex_px(get_viewport_rect().size)
	var band := hx * 1.35
	# The dark ring the wedges sit on, split into the six fixed slots.
	draw_arc(_ring_center, _ring_radius, 0.0, TAU, 72, Color(0.02, 0.025, 0.03, 0.62), band, true)
	draw_arc(_ring_center, _ring_radius + band * 0.5, 0.0, TAU, 72, Color(UiTokens.HUD_RIM, 0.25), 1.5, true)
	draw_arc(_ring_center, maxf(1.0, _ring_radius - band * 0.5), 0.0, TAU, 72, Color(UiTokens.HUD_RIM, 0.25), 1.5, true)
	for k in 6:
		var a := deg_to_rad(float(SLOT_ANGLES[k]) + 30.0)
		var d := Vector2(cos(a), sin(a))
		draw_line(_ring_center + d * maxf(0.0, _ring_radius - band * 0.5), _ring_center + d * (_ring_radius + band * 0.5), Color(UiTokens.HUD_RIM, 0.25), 1.5, true)
	draw_pill(self, _ring_center, _title(), get_viewport_rect().size)

func _title() -> String:
	var kind := str(station_kind())
	return kind.replace("_", " ").capitalize() if kind != "" else (str(station.name) if station else "")

## Station radial hexes (spec §2 sizes: 64 px floor on a phone, larger on desktop like the canvas).
static func hex_px(view: Vector2) -> float:
	return HEX_SIZE if UiTokens.is_compact(view) else 96.0

## A station's name pill in a ring's centre: "● Bonfire" (B4), a green dot = usable here.
static func pill_width(text: String, view: Vector2) -> float:
	if text == "":
		return 0.0
	return UiTokens.ui_face().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.body(view)).x + 40.0

static func draw_pill(ci: CanvasItem, center: Vector2, text: String, view: Vector2, dot: Color = UiTokens.OK_GREEN) -> Rect2:
	if text == "":
		return Rect2()
	var font := UiTokens.ui_face()
	var px := UiTokens.body(view)
	var box := Rect2(center - Vector2(pill_width(text, view), px + 14.0) * 0.5, Vector2(pill_width(text, view), px + 14.0))
	ci.draw_rect(box, UiTokens.HUD_FILL)
	ci.draw_circle(Vector2(box.position.x + 14.0, box.get_center().y), 4.0, dot)
	ci.draw_string(font, Vector2(box.position.x + 26.0, box.get_center().y + px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UiTokens.TEXT)
	return box


## Ground selection ring shared visually with gathering. It grows from the station on first tap;
## the action hex sits above it and needs its own second tap.
func _show_ring3d(radius: float) -> void:
	if station == null or not is_instance_valid(station):
		return
	if _ring3d == null:
		_ring3d = MeshInstance3D.new()
		_ring3d.name = "StationSelectHex3D"
		_ring3d.top_level = true
		_ring3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.92, 0.5, 0.82)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring3d.material_override = material
		_ring3d.mesh = ImmediateMesh.new()
		var host: Node = get_tree().current_scene
		if host:
			host.add_child(_ring3d)
		else:
			add_child(_ring3d)
	var im := _ring3d.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := station.global_position
	var rt := World.runtime if World else null
	var has_surface := rt != null and rt.has_method("surface_y")
	var inner := maxf(0.03, radius - RING_WIDTH)
	for i in 6:
		var a0 := deg_to_rad(60.0 * float(i))
		var a1 := deg_to_rad(60.0 * float(i + 1))
		var quad: Array[Vector3] = []
		for pair in [[a0, inner], [a0, radius], [a1, radius], [a1, inner]]:
			var point := c + Vector3(cos(pair[0]) * pair[1], 0.0, sin(pair[0]) * pair[1])
			point.y = (rt.surface_y(point.x, point.z) if has_surface else c.y) + 0.05
			quad.append(point)
		im.surface_add_vertex(quad[0])
		im.surface_add_vertex(quad[1])
		im.surface_add_vertex(quad[2])
		im.surface_add_vertex(quad[0])
		im.surface_add_vertex(quad[2])
		im.surface_add_vertex(quad[3])
	im.surface_end()
	_ring3d.global_transform = Transform3D.IDENTITY
	_ring3d.visible = true


## One slot of the output row: the item's icon with its quality dots (rarity tier, ItemArt), tap to
## open the recipe. 64 px or more.
class OutputSlot extends Button:
	var item: StringName = &""
	var recipe: StringName = &""

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		tooltip_text = str(item).replace("_", " ").capitalize()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(-1.0), Color(0.06, 0.065, 0.07, 0.95))
		draw_rect(r.grow(-1.0), Color(UiTokens.GOLD, 0.6) if has_focus() else Color(1, 1, 1, 0.10), false, 1.5)
		var tex := ItemIcons.texture(item)
		var s := size.y * 0.6
		if tex:
			draw_texture_rect(tex, Rect2(Vector2((size.x - s) * 0.5, size.y * 0.08), Vector2(s, s)), false)
		var tier := maxi(0, ItemArt.rarity_order().find(str(ItemArt.rarity(item))))
		var dot := maxf(3.0, size.y * 0.045)
		var total := 3.0 * dot * 2.0 + 2.0 * dot
		for i in 3:
			var c := Vector2(size.x * 0.5 - total * 0.5 + dot + i * dot * 3.0, size.y * 0.86)
			draw_circle(c, dot, ItemArt.rim_color(item) if i <= tier else Color(0.4, 0.4, 0.42))
