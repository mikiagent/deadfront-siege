class_name MapScreen
extends Control
## F2 World Atlas (docs/design/ui-redesign-spec.md §7 F2, target docs/design/ui-redesign/f2-world-atlas.webp).
## Left: a dark column with the title, your position line, the island cards (gold brackets on the
## selected one) and, at its foot, island facts with the GOLD "Back to camp" on an unstable island.
## Centre: the island map, north-up, terrain + fog + footsteps + symbols; tap land to walk there.
## Right: compass and ✕ at the top, the legend panel, then Harbour routes and zoom − / + at the foot.
##
## Public entry for the nav menu: HuntHud.open_map() (toggles) / HuntHud.open_atlas() (opens), which
## call open() here.

var hud: HuntHud
var player: Player
## Bottom-right action row: Harbour routes (and Warp home away from home).
var _btn_row: HBoxContainer
var _close: Button
var _cards: VBoxContainer
## The card column scrolls: fourteen catalogue islands do not fit one screen.
var _card_scroll: ScrollContainer
var _zoom_label: Label
var _zoom: float = 1.0
var _selected_region: String = ""
var _panel: Panel
var _title: Label
var _meta: Label
var _facts: VBoxContainer
var _cta: Button
var _rule: ColorRect
const MARGIN := 24.0
## Marker colours, one per kind, far apart from each other and from the green/sand/sea map.
const LEGEND := {
	"claim": [Color(0.72, 0.42, 0.12), "Claim"],
	"campfire": [Color(1.0, 0.98, 0.62), "Fire"],
	"facility": [Color(0.35, 0.95, 0.70), "Station"],
	"you": [Color(1.0, 1.0, 1.0), "You"],
	"trail": [Color(0.04, 0.04, 0.04), "Footsteps"],
	"other": [Color(0.45, 0.47, 0.52), "Other player"],
	"camp": [Color(1.0, 0.82, 0.22), "Camp"],
	"harbour": [Color(0.45, 0.70, 1.0), "Harbour"],
	"crater": [Color(1.0, 0.55, 0.0), "Crater"],
	"wild": [Color(0.95, 0.20, 0.25), "Wild animal"],
	"pet": [Color(0.80, 0.45, 1.0), "Pet"],
	"tree": [Color(0.12, 0.32, 0.16), "Trees"],
	"rock": [Color(0.80, 0.80, 0.84), "Rocks"],
	"plant": [Color(0.62, 1.0, 0.20), "Plants"],
}

## Light ring round every legend swatch: the dark tree green vanished on the near-black panel.
const SWATCH_RING := Color(0.92, 0.92, 0.9, 0.85)
## Phone legend columns: four per row ran "Wild animal" into the "Pet" swatch at 390 px.
const PHONE_LEGEND_COLS := 3
const LEGEND_ROW_H := 22.0
## Portrait phone bands, top to bottom: header, one island card, map, legend (three rows), zoom, actions.
const PHONE_CARD_TOP := 108.0
## Drawn half-size of one atlas symbol: readable at 844x390 without covering the island.
const ICON_PX := 26.0
## Legend rows. Spec 15's own legend (You, Other Player, Shelter, Harbor, Bonfire) plus spec 25's
## claims, facilities and the resource dots; eight fit the landscape-phone column.
const LEGEND_ORDER := ["claim", "campfire", "facility", "harbour", "camp", "other", "wild", "tree"]
const PHONE_MAP_TOP := 236.0
## Desktop legend panel: row pitch and width (the canvas: 150 px, 31 px rows).
const LEGEND_PITCH := 31.0
const LEGEND_W := 150.0
const SEA := Color(0.10, 0.17, 0.23)

static func legend_color(kind: String) -> Color:
	return (LEGEND[kind] as Array)[0]

## Left column width at `r` (the canvas: 480 of 1600).
static func panel_w(r: Vector2) -> float:
	if UiTokens.is_narrow(r):
		return r.x
	return clampf(r.x * 0.3, 240.0, 480.0)

static func compact_row(r: Vector2) -> float:
	return 22.0 if UiTokens.is_compact(r) else LEGEND_PITCH

## One map mark. The harbour is a square with a dark edge: as a light-blue dot it sat lost on the
## light-blue shallows. Claims, fires and facilities use their own symbols (MapIcons).
func _mark(at: Vector2, radius: float, kind: String, ring: Color) -> void:
	match kind:
		"harbour":
			var sq := Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			draw_rect(sq, legend_color(kind))
			draw_rect(sq.grow(1.0), ring, false, 2.0)
		"claim":
			MapIcons.claim(self, at, radius * 1.1, legend_color(kind), ring)
		"campfire":
			MapIcons.flame(self, at, radius * 0.8, legend_color(kind), ring)
		"facility":
			MapIcons.facility(self, at, radius * 0.8, legend_color(kind), ring)
		_:
			draw_circle(at, radius, legend_color(kind))
			draw_circle(at, radius, ring, false, 1.0)

## The fog this atlas draws (the current island's), or null without a world.
func _fog() -> MapFog:
	return World.map_fog

## Rebuilt fog overlay, tinted into the atlas. A null texture means "nothing greyed yet".
func _fog_texture() -> ImageTexture:
	var f := _fog()
	return f.texture() if f else null

## Every symbol the atlas puts on the map, measured from the live scene: claims, fires, facilities,
## the harbour, the camp and (online) other survivors. `at` is a world position, the caller maps it.
func _icon_marks() -> Array:
	var out: Array = []
	var rt := World.runtime
	if rt == null:
		return out
	for rect in World.claims_for_current():
		var r := Rect2i()
		if rect is Rect2i:
			r = rect as Rect2i
		elif rect is Array and (rect as Array).size() >= 4:  # the saved [x, z, w, d] row
			var row := rect as Array
			r = Rect2i(int(row[0]), int(row[1]), int(row[2]), int(row[3]))
		else:
			continue
		# A house on the claim's centre tile (the reference puts the owner's domain on the coast).
		out.append({"kind": "claim", "at": Vector3(float(r.get_center().x) + 0.5, 0.0, float(r.get_center().y) + 0.5)})
	# CLAIMS2: a domain is a set of cells on the runtime, not a list of rects; the legacy rows above are
	# an old save's shape. Mark the declared domain's centre so the atlas keeps its house icon.
	if out.is_empty() and IslandClaims.has_domain(rt):
		var cells := IslandClaims.owned_cells(rt)
		if not cells.is_empty():
			var sum := Vector2.ZERO
			for c: Vector2i in cells:
				sum += Vector2(c)
			var centre: Vector2 = sum / float(cells.size())
			out.append({"kind": "claim", "at": Vector3(centre.x + 0.5, 0.0, centre.y + 0.5)})
	var camp: Variant = rt.get("_camp_pos")
	if camp is Vector3:
		out.append({"kind": "camp", "at": camp})
	var harb: Variant = rt.get("_harbour_pos")
	if harb is Vector3:
		out.append({"kind": "harbour", "at": harb})
	for n in get_tree().get_nodes_in_group("placed_building"):
		if n == null or n.is_queued_for_deletion() or not rt.is_ancestor_of(n):
			continue
		var kind := str(n.get("kind") if n.get("kind") != null else "")
		var pos: Vector3 = (n as Node3D).global_position
		if kind in ["bonfire", "campfire", "stone_fire_pit"] or n.is_in_group("bonfire"):
			out.append({"kind": "campfire", "at": pos})
		elif n.get("station_id") != null or kind in ["workbench", "drying_rack", "mortar", "anvil", "forge", "smoker", "steamer", "stone_grill", "well", "crock_pot"]:
			out.append({"kind": "facility", "at": pos})
	for p in PlayerRegistry.all():
		if p == player:
			continue
		out.append({"kind": "other", "at": p.global_position})
	return out

## Other survivors on the map (grey dots). Empty offline: the atlas simply has none to draw.
func _player_dots() -> Array:
	return _icon_marks().filter(func (m: Dictionary) -> bool: return str(m["kind"]) == "other")

## Smallest atlas symbol hit box in px at `view`. The symbols are drawn at ICON_PX and the tap
## slop grows them to at least 64 px on a phone (44 on desktop), per the mobile tap-target rule.
func icon_min_px(view: Vector2) -> float:
	var base := 64.0 if UiTokens.is_compact(view) else 44.0
	return maxf(base, ICON_PX * 2.0)

## Legend row i's text origin: rows in the right-hand legend panel, or PHONE_LEGEND_COLS per row
## over the buttons on a portrait phone.
static func legend_slot(i: int, r: Vector2) -> Vector2:
	if UiTokens.is_narrow(r):
		return Vector2(MARGIN + legend_col_w(r) * float(i % PHONE_LEGEND_COLS), phone_legend_y(r) + LEGEND_ROW_H * floorf(float(i) / float(PHONE_LEGEND_COLS)))
	var box := legend_rect(r)
	var pitch := compact_row(r)
	return Vector2(box.position.x + 18.0, box.position.y + pitch * (float(i) + 0.5) + 14.0)

static func legend_col_w(r: Vector2) -> float:
	return (r.x - MARGIN * 2.0) / float(PHONE_LEGEND_COLS) if UiTokens.is_narrow(r) else legend_w(r) - 18.0

static func legend_w(r: Vector2) -> float:
	return 128.0 if UiTokens.is_compact(r) else LEGEND_W

## The legend panel (off a portrait phone): right edge, under the compass and ✕.
static func legend_rect(r: Vector2) -> Rect2:
	var compact := UiTokens.is_compact(r)
	var top := (MARGIN + 64.0 + 8.0) if compact else 160.0
	var rows := float(LEGEND_ORDER.size())
	return Rect2(Vector2(r.x - MARGIN - legend_w(r), top), Vector2(legend_w(r), compact_row(r) * rows + 20.0))

func _ready() -> void:
	visible = false
	# Inside the tree set_anchors_preset keeps the current (empty) rect; reset the offsets too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 45
	theme = SheetChrome.ui_theme()
	_panel = Panel.new()
	_panel.name = "IslandPanel"
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(UiTokens.HEADER, 0.94)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)
	_title = SheetChrome.text("World Atlas", 40)
	SheetChrome.strong(_title, 500)
	_panel.add_child(_title)
	_meta = SheetChrome.text("", 18)
	_panel.add_child(_meta)
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "IslandScroll"
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_card_scroll)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 0)
	_card_scroll.add_child(_cards)
	_facts = VBoxContainer.new()
	_facts.name = "Facts"
	_facts.add_theme_constant_override("separation", 6)
	_panel.add_child(_facts)
	_rule = ColorRect.new()
	_rule.name = "FactsRule"
	_rule.color = Color(UiTokens.HUD_RIM, 0.12)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_rule)
	_cta = SheetChrome.action_button("Back to camp", &"cta")
	_cta.name = "BackToCamp"
	_cta.pressed.connect(func () -> void: close(); World.recall_camp())
	_panel.add_child(_cta)
	_btn_row = HBoxContainer.new()
	_btn_row.name = "Actions"
	_btn_row.add_theme_constant_override("separation", 12)
	add_child(_btn_row)
	_close = SheetChrome.Glyph.new(&"close")
	_close.name = "Close"
	_close.pressed.connect(close)
	add_child(_close)
	var zoom_row := HBoxContainer.new()
	zoom_row.name = "ZoomRow"
	zoom_row.add_theme_constant_override("separation", 12)
	add_child(zoom_row)
	zoom_row.add_child(_zoom_btn("−", func () -> void: _set_zoom(_zoom - 0.25)))
	_zoom_label = Label.new()
	_zoom_label.text = "Zoom 1.0×"
	_zoom_label.custom_minimum_size = Vector2(108, 64)
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_row.add_child(_zoom_label)
	zoom_row.add_child(_zoom_btn("+", func () -> void: _set_zoom(_zoom + 0.25)))

## Opens the atlas on the current island (the nav menu's World Atlas entry, the minimap tap, M).
func open() -> void:
	visible = true
	for c in _btn_row.get_children():
		c.queue_free()
	if World.is_unstable():
		_btn_row.add_child(_btn("Warp home", func () -> void: close(); World.travel(&"home_grassland", &"warp_home")))
	_btn_row.add_child(_btn("Harbour routes", func () -> void:
		close()
		var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
		if ui:
			ui.show_harbour()
	))
	_cta.visible = World.is_unstable()
	_selected_region = str(World.island_id)
	_rebuild_cards()
	_rebuild_facts()
	_place()
	queue_redraw()
	UiTokens.focus_first([_close])

func _set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.75, 2.0)
	if _zoom_label:
		_zoom_label.text = "Zoom %.1f×" % _zoom
	queue_redraw()

## Every catalogue island, the current one first, then in harbour-route order.
func _island_ids() -> Array:
	var catalogue: Dictionary = Data.world_islands if Data else {}
	var ids: Array = []
	var current := str(World.island_id)
	if current != "" and catalogue.has(current):
		ids.append(current)
	if current != "home_grassland" and catalogue.has("home_grassland"):
		ids.append("home_grassland")
	for key in World.harbour_routes():
		if not ids.has(key) and catalogue.has(key):
			ids.append(key)
	for key in catalogue.keys():
		if not str(key).begins_with("_") and not ids.has(str(key)):
			ids.append(str(key))
	if ids.is_empty():
		ids.append(current if current != "" else "home")
	return ids

func _rebuild_cards() -> void:
	if _cards == null:
		return
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var ids := _island_ids()
	if _selected_region == "" or not ids.has(_selected_region):
		_selected_region = str(ids[0])
	var catalogue: Dictionary = Data.world_islands if Data else {}
	for id in ids:
		_cards.add_child(_region_card(str(id), catalogue.get(str(id), {}) as Dictionary))

func _region_card(id: String, entry: Dictionary) -> SheetChrome.Card:
	var r := get_viewport_rect().size
	var compact := UiTokens.is_compact(r)
	var climate := str(entry.get("climate", "unknown")).capitalize()
	var tier := int(entry.get("tier", 1))
	var here := id == str(World.island_id)
	var picked := _selected_region == id
	var card := SheetChrome.Card.new()
	card.name = "Island_" + id
	card.set_meta("island_id", id)
	card.selected = picked
	card.pressed.connect(_pick_region.bind(id))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0 if compact else 1)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12 if compact else 22
	box.offset_right = -(12 if compact else 22)
	box.offset_top = 8 if compact else 14
	box.offset_bottom = -(8 if compact else 14)
	card.add_child(box)
	var nm := SheetChrome.text(island_name(id), 17 if compact else 25, UiTokens.GOLD if picked else UiTokens.TEXT)
	nm.name = "Name"
	SheetChrome.strong(nm, 500)
	box.add_child(nm)
	var kind := "Tamed" if str(entry.get("kind", "")) == "private" or id == "home_grassland" else "Unstable"
	var line_px := 12 if compact else 16
	box.add_child(SheetChrome.text("%s · %s · %s" % [LevelDisplay.label(tier), climate, kind], line_px))
	box.add_child(SheetChrome.text(_material_line(str(entry.get("climate", ""))), line_px - 1, UiTokens.MUTED))
	box.add_child(SheetChrome.text(_species_line(entry), line_px - 1, UiTokens.MUTED))
	var status := _status_line(id)
	var st := SheetChrome.text(status[0], line_px, status[1])
	st.name = "Status"
	box.add_child(st)
	card.custom_minimum_size = Vector2(0, 104 if compact else 154)
	return card

## [text, colour] for a card's last line: here, the way there, or what it needs.
func _status_line(id: String) -> Array:
	if id == str(World.island_id):
		return ["You are here", UiTokens.OK_GREEN]
	if id == "home_grassland":
		return ["Harbour · free return home", UiTokens.TEXT]
	var need := World.route_level(StringName(id))
	var lvl := player.skills.level_of("survival") if player and player.skills else 0
	var cost := int(World.def_of(StringName(id)).get("sail_cost", 5))
	if lvl < need:
		return ["Needs Survival %d · harbour route" % need, UiTokens.MUTED]
	var seen := "Visited · " if World.visited_islands.has(id) else ""
	return ["%sHarbour route · %d Warp Gems" % [seen, cost], UiTokens.TEXT]

## The column's foot: facts about this island (the canvas's fatigue / landmarks rows).
## ASSUMPTION: no landmark counter exists in code; the rows are island time and islands charted.
func _rebuild_facts() -> void:
	for c in _facts.get_children():
		_facts.remove_child(c)
		c.queue_free()
	var r := get_viewport_rect().size
	var px := 13 if UiTokens.is_compact(r) else 18
	var life := "Permanent" if World.is_home() or World.is_tutorial() else "%d min left" % int(ceil(World.remaining_lifetime / 60.0))
	_facts.add_child(_fact("Island time", life, UiTokens.TEXT, px))
	var charted := World.visited_islands.size() + (0 if World.visited_islands.has(str(World.island_id)) else 1)
	_facts.add_child(_fact("Islands visited", "%d / %d" % [charted, _island_ids().size()], UiTokens.GOLD, px))
	# LANDMARKS (doc section 5.6): the island's landmark count, shown once it has any.
	var lm := World.landmarks_found_count()
	if lm.y > 0:
		_facts.add_child(_fact("Landmarks Found", "%d / %d" % [lm.x, lm.y], UiTokens.GOLD, px))

func _fact(label: String, value: String, col: Color, px: int) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := SheetChrome.text(label, px)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := SheetChrome.text(value, px, col)
	v.clip_text = false
	v.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.add_child(v)
	return row

func _pick_region(id: String) -> void:
	_selected_region = id
	_rebuild_cards()
	_place()

func _species_line(entry: Dictionary) -> String:
	var names: PackedStringArray = []
	var spawns: Variant = entry.get("spawns", {})
	if spawns is Dictionary:
		for ring in (spawns as Dictionary).values():
			if ring is Array:
				for row in ring:
					var sp := _species_name(str((row as Dictionary).get("species", ""))) if row is Dictionary else ""
					if sp != "" and not names.has(sp):
						names.append(sp)
					if names.size() >= 3:
						break
	return " · ".join(names) if not names.is_empty() else "Species —"

func _material_line(climate: String) -> String:
	var block: Variant = Data.world_climates.get(climate, {}) if Data else {}
	var names: PackedStringArray = []
	if block is Dictionary:
		for row in (block as Dictionary).get("materials", []):
			if row is Dictionary:
				names.append(LevelDisplay.nice_name(str((row as Dictionary).get("id", ""))))
			if names.size() >= 3:
				break
	return " · ".join(names) if not names.is_empty() else "Resources —"

## Island name for people: its display name, or "<Climate> Island" when the data only has an id.
static func island_name(id: String) -> String:
	var def := World.def_of(StringName(id))
	var dn := str(def.get("display_name", ""))
	if dn == "" or dn == id.replace("_", " ").capitalize():
		var climate := str(def.get("climate", ""))
		return ("%s Island" % climate.capitalize()) if climate != "" else id.replace("_", " ").capitalize()
	return dn

static func _species_name(id: String) -> String:
	if id == "":
		return ""
	var def := Data.creature(StringName(id))
	return def.species if def and def.species != "" else id.replace("_", " ").capitalize()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

func _zoom_btn(text: String, cb: Callable) -> Button:
	var b := _btn(text, cb)
	b.custom_minimum_size = Vector2(64, 64)
	b.add_theme_font_size_override("font_size", 26)
	return b

func _btn(text: String, cb: Callable) -> Button:
	var b := SheetChrome.action_button(text, &"ghost")
	b.custom_minimum_size = Vector2(0, 64)
	b.clip_text = false  # sized by its text: a clipping button's minimum width is zero
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.pressed.connect(cb)
	return b

func _process(_delta: float) -> void:
	if not visible:
		return
	_place()
	queue_redraw()

## Places the column, the right-hand controls and the footer for the current view.
func _place() -> void:
	var r := get_viewport_rect().size
	var compact := UiTokens.is_compact(r)
	var narrow := UiTokens.is_narrow(r)
	var pw := panel_w(r)
	var pad := 12.0 if compact else 22.0
	# left column (a portrait phone: a top band with one card, the map below)
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(pw, PHONE_CARD_TOP + 112.0 if narrow else r.y)
	_title.add_theme_font_size_override("font_size", 22 if compact else 40)
	_title.position = Vector2(pad, 6.0 if compact else 20.0)
	_title.size = Vector2(pw - pad * 2.0 - (72.0 if narrow else 0.0), 30.0 if compact else 52.0)
	_meta.add_theme_font_size_override("font_size", 12 if compact else 18)
	_meta.position = Vector2(pad, _title.position.y + _title.size.y)
	_meta.size = Vector2(pw - pad * 2.0, 18.0 if compact else 26.0)
	var tile := BuildGrid.tile_of(player.global_position) if player else Vector2i.ZERO
	_meta.text = "You X %d · Y %d · %s · Gold %d" % [tile.x, -tile.y, LevelDisplay.player_label(), World.t_stones]
	var list_top := _meta.position.y + _meta.size.y + (6.0 if compact else 10.0)
	var cta_h := 64.0 if _cta.visible else 0.0
	var fact_px := 13 if compact else 18
	var facts_h := 0.0 if narrow else (2.0 * (fact_px + 12.0))
	_facts.visible = not narrow and not (compact and _cta.visible)
	if not _facts.visible:
		facts_h = 0.0
	var foot := pad + cta_h + (8.0 if cta_h > 0.0 else 0.0) + facts_h + (12.0 if facts_h > 0.0 else 0.0)
	_cta.position = Vector2(pad, _panel.size.y - pad - cta_h)
	_cta.size = Vector2(pw - pad * 2.0, cta_h)
	_cta.add_theme_font_size_override("font_size", 16 if compact else 24)
	_facts.position = Vector2(pad, _panel.size.y - foot + 6.0)
	_facts.size = Vector2(pw - pad * 2.0, facts_h)
	_rule.visible = _facts.visible
	_rule.position = Vector2(0.0, _facts.position.y - 8.0)
	_rule.size = Vector2(pw, 1.0)
	_card_scroll.position = Vector2(0.0, list_top)
	_card_scroll.size = Vector2(pw, maxf(64.0, _panel.size.y - list_top - foot))
	# right column: ✕ top right, legend panel, actions + zoom at the foot
	_close.position = Vector2(r.x - MARGIN - 64.0 + 10.0, MARGIN * 0.5)
	_close.size = Vector2(64, 64)
	var zoom_row := get_node_or_null("ZoomRow") as Control
	for b in _btn_row.get_children():
		(b as Control).add_theme_font_size_override("font_size", 15 if compact else 20)
	if _zoom_label:
		_zoom_label.add_theme_font_size_override("font_size", UiTokens.body(r) + (0 if compact else 4))
		_zoom_label.add_theme_color_override("font_color", UiTokens.TEXT)
		_zoom_label.custom_minimum_size = Vector2(88.0 if compact else 108.0, 64.0)
	var foot_y := r.y - 64.0 - (12.0 if compact else 32.0)
	if zoom_row:
		zoom_row.size = zoom_row.get_combined_minimum_size()
		zoom_row.position = Vector2(r.x - MARGIN - zoom_row.size.x if not narrow else MARGIN, foot_y if not narrow else foot_y - 64.0 - UiTokens.SPACE)
	_btn_row.size = _btn_row.get_combined_minimum_size()
	_btn_row.position = Vector2((zoom_row.position.x - 12.0 - _btn_row.size.x) if (zoom_row and not narrow) else MARGIN, foot_y)

## Left edge of the zoom row (bottom right, off a portrait phone).
static func zoom_left(r: Vector2) -> float:
	return r.x - (64.0 + 108.0 + 64.0 + 12.0 * 2.0) - MARGIN

static func phone_legend_y(r: Vector2) -> float:
	return r.y - 64.0 - MARGIN - UiTokens.SPACE - 64.0 - UiTokens.SPACE * 2.0 - 30.0 - LEGEND_ROW_H

## The map's square at zoom 1: between the island column and the legend, under the top and over
## the action row (portrait phone: under the column's band, over the legend rows).
func _layout() -> Dictionary:
	var r := get_viewport_rect().size
	var left := panel_w(r) + MARGIN
	var right := legend_rect(r).position.x - MARGIN
	var top := MARGIN
	var bottom := r.y - 64.0 - (12.0 if UiTokens.is_compact(r) else 32.0) - UiTokens.SPACE
	if UiTokens.is_narrow(r):
		left = MARGIN
		right = r.x - MARGIN
		top = PHONE_CARD_TOP + 112.0 + UiTokens.SPACE
		bottom = phone_legend_y(r) - 24.0
	elif UiTokens.is_compact(r):
		top = UiTokens.SPACE  # landscape phone: the square is height-bound, so it takes the top margin back
		right = legend_rect(r).position.x - UiTokens.SPACE
	var fit := maxf(40.0, minf(bottom - top, right - left))
	var centre := Vector2((left + right) * 0.5, (top + bottom) * 0.5)
	var rt := World.runtime
	var size_m: float = float(rt.get("_size")) if rt and rt.get("_size") != null else 200.0
	return {"centre": centre, "scale": fit / maxf(1.0, size_m) * _zoom, "fit": fit, "size_m": size_m}

## The map square at zoom 1 (the fit), in screen space.
func _map_rect(L: Dictionary) -> Rect2:
	var side: float = L["fit"]
	return Rect2((L["centre"] as Vector2) - Vector2(side, side) * 0.5, Vector2(side, side))

var _sea: Color = SEA
var _sea_tex: Texture2D

## The open water in the corner of the HUD's map picture (read once per picture).
func _sea_colour() -> Color:
	var tex := hud.map_texture() if hud else null
	if tex and tex != _sea_tex:
		_sea_tex = tex
		var img := tex.get_image()
		if img and not img.is_empty():
			_sea = img.get_pixel(1, 1)
			_sea.a = 1.0
	return _sea

func _legend_kinds() -> Array:
	return LEGEND_ORDER.duplicate()

func _draw() -> void:
	if player == null or hud == null:
		return
	var r := get_viewport_rect().size
	var font := UiTokens.ui_face()
	# Sea: the map texture's own open-water colour, so the square it is drawn in does not show.
	draw_rect(Rect2(Vector2.ZERO, r), _sea_colour())
	var L := _layout()
	var centre: Vector2 = L["centre"]
	var s: float = L["scale"]
	var size_m: float = L["size_m"]
	var to_map := func (w: Vector3) -> Vector2:
		return Vector2(w.x * s, w.z * s)
	draw_set_transform(centre, 0.0, Vector2.ONE)  # north-up
	var tex := hud.map_texture()
	if tex:
		var px := size_m * s
		draw_texture_rect(tex, Rect2(Vector2(-px * 0.5, -px * 0.5), Vector2(px, px)), false)
	var fog_tex := _fog_texture()
	if fog_tex:
		var fpx := size_m * s
		draw_texture_rect(fog_tex, Rect2(Vector2(-fpx * 0.5, -fpx * 0.5), Vector2(fpx, fpx)), false)
	var rt := World.runtime
	# Footsteps: black dots from where you came from (spec 25), over the terrain, under the icons.
	var f := _fog()
	if f:
		var trail_pts: Array = []
		var trail_alphas: Array[float] = []
		for i in f.trail.size():
			var p := f.trail[i]
			trail_pts.append(Vector2(p.x * s, p.y * s))
			trail_alphas.append(f.trail_alpha(i))
		MapIcons.trail(self, trail_pts, clampf(s * 1.6, 1.8, 3.6), trail_alphas)
	# resource dots: trees dark green, rocks grey, bushes/plants light green
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or not hn.visible or hn.depleted:
			continue
		if f and not f.revealed_at(hn.global_position):
			continue  # fog: you cannot see trees you have not walked near
		var role := str(Data.nature_families.get(hn.family, {}).get("role", ""))
		var col := legend_color("plant")
		if role.begins_with("tree"):
			col = legend_color("tree")
		elif role == "rock":
			col = legend_color("rock")
		draw_circle(to_map.call(hn.global_position), 2.2, col)
	if rt:
		for m in _icon_marks():
			var kind := str(m["kind"])
			if kind in ["camp", "harbour", "other"]:
				continue
			_mark(to_map.call(m["at"]), ICON_PX * 0.5, kind, Color(0.02, 0.05, 0.12, 0.95))
		var camp: Vector3 = rt.get("_camp_pos")
		var harb: Vector3 = rt.get("_harbour_pos")
		draw_circle(to_map.call(camp), 4.5, legend_color("camp"))
		_mark(to_map.call(harb), 7.0, "harbour", Color(0.02, 0.05, 0.12, 0.95))
		if World.crater_discovered and World.current_landmarks().is_empty():
			draw_circle(to_map.call(rt.get("_crater_pos")), 6.0, legend_color("crater"))
		# LANDMARKS: found sites only (the crater is one of them now), with their names.
		for lm in MapIcons.found_landmarks():
			var q: Vector2 = to_map.call(lm["at"])
			MapIcons.landmark(self, q, 7.0, bool(lm["sealed"]), Color(0.02, 0.05, 0.12, 0.95))
			draw_string(ThemeDB.fallback_font, q + Vector2(9.0, 4.0), str(lm["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))
		for m in _player_dots():
			draw_circle(to_map.call(m["at"]), 4.0, legend_color("other"))
			draw_circle(to_map.call(m["at"]), 4.0, Color(0.9, 0.9, 0.95, 0.7), false, 1.0)
	for n in get_tree().get_nodes_in_group("creatures"):
		var cr := n as Creature
		if cr == null or cr.health.dead:
			continue
		if f and not f.revealed_at(cr.global_position):
			continue  # fog: a dinosaur you have never seen is not on your map
		draw_circle(to_map.call(cr.global_position), 3.2, legend_color("pet") if cr.is_pet else legend_color("wild"))
	var pp := player.global_position
	var pyaw := player.visual.rotation.y if player.visual else 0.0
	var fwd := Vector2(-sin(pyaw), -cos(pyaw))
	var side := Vector2(-fwd.y, fwd.x)
	var pm: Vector2 = to_map.call(pp)
	var arrow := PackedVector2Array([pm + fwd * 14.0, pm - fwd * 9.0 + side * 9.0, pm - fwd * 4.0, pm - fwd * 9.0 - side * 9.0])
	draw_colored_polygon(arrow, Color(1, 1, 1))
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.02, 0.03, 0.04), 1.5, true)
	if player.nav_active:
		var goal: Vector2 = to_map.call(player._path_goal)
		draw_arc(goal, 6.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Compass: a dark disc left of ✕ (the atlas is north-up; the HUD minimap turns with the camera and carries its own N marker).
	var np := Vector2(_close.position.x - 40.0, _close.position.y + 32.0)
	draw_circle(np, 24.0, Color(0.02, 0.025, 0.03, 0.9))
	draw_colored_polygon(PackedVector2Array([np + Vector2(0, -16), np + Vector2(-6, -6), np + Vector2(6, -6)]), Color.WHITE)
	UiTokens.draw_centered(self, font, np + Vector2(0, 7), "N", 14, Color.WHITE)
	# Legend: a dark panel on the right (three rows over the buttons on a portrait phone).
	var kinds := _legend_kinds()
	var meta_px := UiTokens.meta(r) if UiTokens.is_compact(r) else 18
	var label_w := legend_col_w(r) - 22.0
	if not UiTokens.is_narrow(r):
		draw_rect(legend_rect(r), Color(UiTokens.HEADER, 0.92))
	for i in kinds.size():
		var row: Array = LEGEND[kinds[i]]
		var at := legend_slot(i, r)
		_mark(at + Vector2(6, -5), 5.0 if UiTokens.is_compact(r) else 6.0, kinds[i], SWATCH_RING)
		draw_string(font, at + Vector2(20, 0), UiTokens.ellipsis(font, str(row[1]), label_w, meta_px), HORIZONTAL_ALIGNMENT_LEFT, -1, meta_px, Color(0.93, 0.94, 0.95))

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var release := false
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
		release = true
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
		release = true
	if not release:
		return
	accept_event()
	var r := get_viewport_rect().size
	if not UiTokens.is_narrow(r) and legend_rect(r).has_point(pos):
		return  # the legend is a key, not land
	var L := _layout()
	var local := pos - (L["centre"] as Vector2)
	var s: float = L["scale"]
	var world := Vector3(local.x / s, 0.0, local.y / s)
	var rt := World.runtime
	if rt == null or not rt.has_method("spawn_ok") or not rt.spawn_ok(world, false):
		return  # water or off the island
	world.y = rt.surface_y(world.x, world.z) if rt.has_method("surface_y") else 0.0
	if player.has_method("nav_to"):
		player.nav_to(player._closest_nav_point(world))
		player.notice("Walking to X %d  Y %d" % [BuildGrid.tile_of(world).x, -BuildGrid.tile_of(world).y])
	close()
