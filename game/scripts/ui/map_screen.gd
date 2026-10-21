class_name MapScreen
extends Control
## Full-screen island map (tap the minimap or the map key). North-up and axis-aligned, so the
## island reads as a map rather than a diamond. Shows terrain, camp/harbour/crater, resource dots,
## creatures and the survivor; tap anywhere on land to walk there. Travel buttons along the bottom.

var hud: HuntHud
var player: Player
var _btn_row: HBoxContainer
var _close: Button
var _cards: VBoxContainer
## The card column scrolls: a phone shows about 1.5 cards, and dropping the rest hid charted islands.
var _card_scroll: ScrollContainer
var _zoom_label: Label
var _zoom: float = 1.0
var _selected_region: String = ""
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
const PHONE_MAP_TOP := 236.0

static func legend_color(kind: String) -> Color:
	return (LEGEND[kind] as Array)[0]

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

## Drawn radius of one atlas symbol: readable at 844x390 without covering the island.
const ICON_PX := 26.0

## Legend slot for item i of n: a column on desktop and landscape phones, PHONE_LEGEND_COLS per
## row on a portrait phone.
static func legend_slot(i: int, r: Vector2) -> Vector2:
	if UiTokens.is_narrow(r):
		return Vector2(MARGIN + legend_col_w(r) * float(i % PHONE_LEGEND_COLS), phone_legend_y(r) + LEGEND_ROW_H * floorf(float(i) / float(PHONE_LEGEND_COLS)))
	return Vector2(r.x - MARGIN - 200.0, MARGIN + 100.0 + LEGEND_ROW_H * float(i))

static func legend_col_w(r: Vector2) -> float:
	return (r.x - MARGIN * 2.0) / float(PHONE_LEGEND_COLS) if UiTokens.is_narrow(r) else 200.0

func _ready() -> void:
	visible = false
	# Inside the tree set_anchors_preset keeps the current (empty) rect; reset the offsets too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 45
	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", UiTokens.SPACE)
	add_child(_btn_row)
	_close = _btn("Close", close)
	add_child(_close)
	_card_scroll = ScrollContainer.new()
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_card_scroll)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", UiTokens.SPACE)
	_card_scroll.add_child(_cards)
	var zoom_row := HBoxContainer.new()
	zoom_row.name = "ZoomRow"
	zoom_row.add_theme_constant_override("separation", UiTokens.SPACE)
	add_child(zoom_row)
	zoom_row.add_child(_zoom_btn("−", func () -> void: _set_zoom(_zoom - 0.25)))
	_zoom_label = Label.new()
	_zoom_label.text = "Zoom 1.0×"
	_zoom_label.custom_minimum_size = Vector2(108, 56)
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_row.add_child(_zoom_label)
	zoom_row.add_child(_zoom_btn("+", func () -> void: _set_zoom(_zoom + 0.25)))

func open() -> void:
	visible = true
	for c in _btn_row.get_children():
		c.queue_free()
	if World.is_unstable():
		_btn_row.add_child(_btn("Return to camp", func () -> void: close(); World.recall_camp()))
		_btn_row.add_child(_btn("Warp home", func () -> void: close(); World.travel(&"home_grassland", &"warp_home")))
	_btn_row.add_child(_btn("Harbour routes", func () -> void:
		close()
		var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
		if ui:
			ui.show_harbour()
	))
	_selected_region = str(World.island_id)
	_rebuild_cards()
	queue_redraw()
	UiTokens.focus_first([_close])

func _set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.75, 2.0)
	if _zoom_label:
		_zoom_label.text = "Zoom %.1f×" % _zoom
	queue_redraw()

func _rebuild_cards() -> void:
	if _cards == null:
		return
	for c in _cards.get_children():
		c.queue_free()
	var catalogue: Dictionary = Data.world_islands if Data else {}
	var ids: Array = []
	var current := str(World.island_id)
	if current != "" and catalogue.has(current):
		ids.append(current)
	var limit := 4  # the column scrolls where they do not fit
	for key in catalogue.keys():
		if ids.size() >= limit:
			break
		if str(key).begins_with("_") or str(key) == current:
			continue
		ids.append(str(key))
	if ids.is_empty():
		ids.append(current if current != "" else "home")
	if _selected_region == "" or not ids.has(_selected_region):
		_selected_region = str(ids[0])
	for id in ids:
		_cards.add_child(_region_card(str(id), catalogue.get(str(id), {}) as Dictionary))

func _region_card(id: String, entry: Dictionary) -> Button:
	var climate := str(entry.get("climate", "unknown")).capitalize()
	var tier := int(entry.get("tier", 1))
	var species := _species_line(entry)
	var materials := _material_line(str(entry.get("climate", "")))
	var here := id == str(World.island_id)
	var travel := "You are here" if here else "Charted"
	var b := Button.new()
	b.text = "%s\n%s    %s\n%s\n%s\n%s" % [island_name(id), LevelDisplay.label(tier), climate, materials, species, travel]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(220, 112)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", UiTokens.TEXT)
	b.add_theme_stylebox_override("normal", UiTokens.button_style(_selected_region == id or here))
	b.pressed.connect(_pick_region.bind(id))
	return b

func _pick_region(id: String) -> void:
	_selected_region = id
	_rebuild_cards()

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
	if names.is_empty():
		return "Species —"
	return UiTokens.ellipsis(ThemeDB.fallback_font, " · ".join(names), 200.0, 14)

func _material_line(climate: String) -> String:
	var block: Variant = Data.world_climates.get(climate, {}) if Data else {}
	var names: PackedStringArray = []
	if block is Dictionary:
		for row in (block as Dictionary).get("materials", []):
			if row is Dictionary:
				names.append(LevelDisplay.nice_name(str((row as Dictionary).get("id", ""))))
			if names.size() >= 3:
				break
	if names.is_empty():
		return "Resources —"
	return UiTokens.ellipsis(ThemeDB.fallback_font, " · ".join(names), 200.0, 14)

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
	b.custom_minimum_size = Vector2(64, 56)
	return b

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 56)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", UiTokens.ACTION)
	b.add_theme_stylebox_override("normal", UiTokens.button_style(false))
	b.pressed.connect(cb)
	return b

func _process(_delta: float) -> void:
	if not visible:
		return
	var r := get_viewport_rect().size
	var phone := UiTokens.is_narrow(r)  # portrait bands; a landscape phone keeps the desktop places
	var close_w := minf(160.0, maxf(96.0, r.x * 0.36))
	_close.custom_minimum_size = Vector2(close_w, 56)
	_close.size = Vector2(close_w, 56)
	_close.position = Vector2(r.x - close_w - MARGIN, MARGIN)
	var actions := _btn_row.get_child_count()
	var action_w := 200.0 if not phone else maxf(96.0, (r.x - MARGIN * 2.0 - UiTokens.SPACE * float(maxi(actions - 1, 0))) / float(maxi(actions, 1)))
	if UiTokens.is_compact(r) and not phone:  # landscape phone: away from home three 200 px actions ran under the zoom row
		action_w = minf(action_w, maxf(96.0, (zoom_left(r) - UiTokens.SPACE - MARGIN - UiTokens.SPACE * float(maxi(actions - 1, 0))) / float(maxi(actions, 1))))
	for child in _btn_row.get_children():
		var action := child as Control
		if action:
			action.custom_minimum_size = Vector2(action_w, 56)
	_btn_row.position = Vector2(MARGIN, r.y - 64.0 - MARGIN)
	if _card_scroll:
		_card_scroll.position = Vector2(MARGIN, PHONE_CARD_TOP if phone else 96.0)
		_card_scroll.size = Vector2(240.0 if not phone else r.x - MARGIN * 2.0, 112.0 if phone else r.y - 220.0)
	var zoom_row := get_node_or_null("ZoomRow") as Control
	if zoom_row:
		zoom_row.position = Vector2(zoom_left(r), r.y - 64.0 - MARGIN) if not phone else Vector2(MARGIN, r.y - 64.0 - MARGIN - 64.0 - UiTokens.SPACE)
	if _zoom_label:
		_zoom_label.add_theme_font_size_override("font_size", UiTokens.body(r))
		_zoom_label.add_theme_color_override("font_color", UiTokens.TEXT)
	queue_redraw()

## Left edge of the zoom row (bottom right, off a portrait phone).
static func zoom_left(r: Vector2) -> float:
	return r.x - (64.0 + 108.0 + 64.0 + UiTokens.SPACE * 2.0) - MARGIN

static func phone_legend_y(r: Vector2) -> float:
	return r.y - 64.0 - MARGIN - UiTokens.SPACE - 64.0 - UiTokens.SPACE * 2.0 - 30.0 - LEGEND_ROW_H

func _layout() -> Dictionary:
	var r := get_viewport_rect().size
	var fit := minf(r.x, r.y) - MARGIN * 2.0 - 90.0
	var centre := Vector2(r.x * 0.58, r.y * 0.48)
	if UiTokens.is_narrow(r):
		var map_h := phone_legend_y(r) - 24.0 - PHONE_MAP_TOP
		fit = minf(r.x - MARGIN * 2.0, map_h)
		centre = Vector2(r.x * 0.5, PHONE_MAP_TOP + fit * 0.5)
	elif UiTokens.is_compact(r):
		# Landscape phone: between the card column and the legend, under the header, over the buttons.
		var top := MARGIN + 48.0
		var bottom := r.y - 64.0 - MARGIN - UiTokens.SPACE
		var left := MARGIN + 240.0 + UiTokens.SPACE
		var right := r.x - MARGIN - 200.0 - UiTokens.SPACE
		fit = minf(bottom - top, right - left)
		centre = Vector2((left + right) * 0.5, (top + bottom) * 0.5)
		# The square is height-bound (222 px of 390 at 844x390). Where the action row leaves the
		# middle of the bottom free, it runs down between the actions and the zoom row instead.
		# ASSUMPTION: the map may sit between the footer buttons on a landscape phone.
		var low_left := maxf(left, MARGIN + _btn_row.get_combined_minimum_size().x + UiTokens.SPACE)
		var low_right := minf(right, zoom_left(r) - UiTokens.SPACE)
		var tall := minf(r.y - MARGIN - top, low_right - low_left)
		if tall > fit:
			fit = tall
			centre = Vector2((low_left + low_right) * 0.5, top + fit * 0.5)
	var rt := World.runtime
	var size_m: float = float(rt.get("_size")) if rt and rt.get("_size") != null else 200.0
	return {"centre": centre, "scale": fit / maxf(1.0, size_m) * _zoom, "fit": fit, "size_m": size_m}

## The map square at zoom 1 (the fit), in screen space.
func _map_rect(L: Dictionary) -> Rect2:
	var side: float = L["fit"]
	return Rect2((L["centre"] as Vector2) - Vector2(side, side) * 0.5, Vector2(side, side))

## Legend rows. Capped at eight: the landscape-phone legend is one column between the header and
## the action row, and a ninth row ran into the buttons. Spec 15's own legend (You, Other Player,
## Shelter, Harbor, Bonfire) plus spec 25's claims, facilities and the resource dots.
const LEGEND_ORDER := ["claim", "campfire", "facility", "harbour", "camp", "other", "wild", "tree"]

func _legend_kinds() -> Array:
	return LEGEND_ORDER.duplicate()

func _draw() -> void:
	if player == null or hud == null:
		return
	var r := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, r), Color(0.03, 0.035, 0.04, 1.0))
	draw_rect(Rect2(Vector2(12, 12), r - Vector2(24, 24)), Color(0.05, 0.055, 0.06, 0.4), false, 2.0)
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
		for p in f.trail:
			trail_pts.append(Vector2(p.x * s, p.y * s))
		MapIcons.trail(self, trail_pts, 1.8)
	# resource dots: trees dark green, rocks grey, bushes/plants light green
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or not hn.visible or hn.depleted:
			continue
		var role := str(Data.nature_families.get(hn.family, {}).get("role", ""))
		var col := legend_color("plant")
		if role.begins_with("tree"):
			col = legend_color("tree")
		elif role == "rock":
			col = legend_color("rock")
		draw_circle(to_map.call(hn.global_position), 2.2, col)
	if rt:
		# Claims, campfires and facilities first (under the survivor and the creatures).
		for m in _icon_marks():
			var kind := str(m["kind"])
			if kind in ["camp", "harbour", "other"]:
				continue
			_mark(to_map.call(m["at"]), ICON_PX * 0.5, kind, Color(0.02, 0.05, 0.12, 0.95))
		var camp: Vector3 = rt.get("_camp_pos")
		var harb: Vector3 = rt.get("_harbour_pos")
		draw_circle(to_map.call(camp), 6.0, legend_color("camp"))
		_mark(to_map.call(harb), 7.0, "harbour", Color(0.02, 0.05, 0.12, 0.95))
		if World.crater_discovered:
			draw_circle(to_map.call(rt.get("_crater_pos")), 6.0, legend_color("crater"))
		for m in _player_dots():
			draw_circle(to_map.call(m["at"]), 4.0, legend_color("other"))
			draw_circle(to_map.call(m["at"]), 4.0, Color(0.9, 0.9, 0.95, 0.7), false, 1.0)
	for n in get_tree().get_nodes_in_group("creatures"):
		var cr := n as Creature
		if cr == null or cr.health.dead:
			continue
		draw_circle(to_map.call(cr.global_position), 3.2, legend_color("pet") if cr.is_pet else legend_color("wild"))
	var pp := player.global_position
	var pyaw := player.visual.rotation.y if player.visual else 0.0
	var fwd := Vector2(-sin(pyaw), -cos(pyaw))
	var side := Vector2(-fwd.y, fwd.x)
	var pm: Vector2 = to_map.call(pp)
	draw_colored_polygon(PackedVector2Array([pm + fwd * 11.0, pm - fwd * 7.0 + side * 7.0, pm - fwd * 7.0 - side * 7.0]), Color(1, 1, 1))
	if player.nav_active:
		var goal: Vector2 = to_map.call(player._path_goal)
		draw_circle(goal, 5.0, Color(1.0, 1.0, 1.0, 0.0))
		draw_arc(goal, 6.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# North marker: the atlas is north-up while the HUD minimap turns with the camera.
	var mr := _map_rect(L)
	var np := Vector2(mr.end.x - 18.0, mr.position.y + 22.0)
	draw_circle(np, 14.0, Color(0.03, 0.035, 0.04, 0.85))
	draw_colored_polygon(PackedVector2Array([np + Vector2(0, -12), np + Vector2(-4, -6), np + Vector2(4, -6)]), Color.WHITE)
	UiTokens.draw_centered(self, font, np + Vector2(0, 3), "N", UiTokens.TYPE_MIN, Color.WHITE)
	# header + legend (screen space)
	var title := "WORLD ATLAS"
	var head := UiTokens.heading(r)
	var phone := UiTokens.is_narrow(r)
	var close_w := minf(160.0, maxf(96.0, r.x * 0.36))
	var text_w := r.x - MARGIN * 2.0 - close_w - 12.0
	draw_string(font, Vector2(MARGIN, MARGIN + head), title, HORIZONTAL_ALIGNMENT_LEFT, text_w, head, Color.WHITE)
	var sub := "%s   %s" % [island_name(str(World.island_id)), "Home" if World.is_home() else "Survivable %d min" % int(ceil(World.remaining_lifetime / 60.0))]
	var sub_pos := Vector2(MARGIN, MARGIN + head + 22) if phone else Vector2(MARGIN + 220, MARGIN + head)
	var sub_w := text_w if phone else minf(r.x * 0.4, text_w - 220.0)
	draw_string(font, sub_pos, UiTokens.ellipsis(font, sub, sub_w, UiTokens.body(r)), HORIZONTAL_ALIGNMENT_LEFT, sub_w, UiTokens.body(r), UiTokens.TEAL)
	var tile := BuildGrid.tile_of(pp)
	var meta := "You  X %d  Y %d    %s    T-stones %d" % [tile.x, tile.y, LevelDisplay.player_label(), World.t_stones]
	var meta_y := MARGIN + head + (44.0 if phone else 22.0)
	draw_string(font, Vector2(MARGIN, meta_y), UiTokens.ellipsis(font, meta, text_w, UiTokens.meta(r)), HORIZONTAL_ALIGNMENT_LEFT, text_w, UiTokens.meta(r), UiTokens.META)
	# Legend: a column under Close, or three rows over the buttons on a portrait phone.
	var kinds := _legend_kinds()
	var meta_px := UiTokens.meta(r)
	var label_w := legend_col_w(r) - 22.0
	for i in kinds.size():
		var row: Array = LEGEND[kinds[i]]
		var at := legend_slot(i, r)
		_mark(at + Vector2(6, -5), 5.0, kinds[i], SWATCH_RING)
		draw_string(font, at + Vector2(16, 0), UiTokens.ellipsis(font, str(row[1]), label_w, meta_px), HORIZONTAL_ALIGNMENT_LEFT, -1, meta_px, Color(0.9, 0.9, 0.9))

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
		player.notice("Walking to X %d  Y %d" % [BuildGrid.tile_of(world).x, BuildGrid.tile_of(world).y])
	close()
