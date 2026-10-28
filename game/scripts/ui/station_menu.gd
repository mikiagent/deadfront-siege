class_name StationMenu
extends Control
## Hexagonal interact menu floating over a tapped workstation. Workbench offers CRAFT,
## bonfire offers COOK (plus CAUTERISE while bleeding); any other station with recipes
## falls back to CRAFT. Add entries to ACTIONS to give a station its own hexes.
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
const ACTIONS := {
	&"tent": [{"id": &"sleep", "label": "SLEEP", "icon": "sleeping", "glyph": "Z"}],
	&"canvas_tent": [{"id": &"sleep", "label": "SLEEP", "icon": "sleeping", "glyph": "Z"}],
	&"straw_roll": [{"id": &"sleep", "label": "SLEEP", "icon": "sleeping", "glyph": "Z"}],
	&"workbench": [{"id": &"craft", "label": "CRAFT", "icon": "hammer", "glyph": "C"}],
	&"bonfire": [{"id": &"cook", "label": "COOK", "icon": "skewer", "glyph": "C"}],
	&"campfire": [{"id": &"cook", "label": "COOK", "icon": "skewer", "glyph": "C"}],
}
## Menu anchor height above the station origin, per station kind.
const HEIGHTS := {
	&"workbench": 1.55,
	&"bonfire": 1.25,
	&"campfire": 1.25,
	&"drying_rack": 1.5,
	&"crock_pot": 1.45,
}
const DEFAULT_HEIGHT := 1.45

var station: Node3D
var player: Player
## A fire's state line under the ring ("Fuel 4:12 · Burning · Durability 288/300"); stations that
## have no info_text() keep the old look with no line.
var info_label: Label
var _buttons: Array[HexButton] = []
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
	# FIREPITS: any fire takes wood; the permanent pit needs it to burn at all.
	if sid in [&"bonfire", &"campfire"]:
		out.append({"id": &"wood", "label": "LOAD WOOD", "icon": "branch", "glyph": "W"})
	if sid == &"bonfire" and p != null and p.statuses \
			and (p.statuses.has(&"bleed") or p.statuses.has(&"deep_bleed")):
		out.append({"id": &"cauterise", "label": "CAUTERISE", "icon": "bonfire_kit", "glyph": "B"})
	return out

## The hexes that station can actually offer: a fire that is not burning (the cold stone pit, a
## burnt-out fire) drops COOK and says why, instead of opening a craft flow that would refuse.
static func filter_actions(st: Node3D, actions: Array) -> Array:
	var out: Array = []
	var cook_why := ""
	if st != null and is_instance_valid(st) and st.has_method("cook_block_reason"):
		cook_why = str(st.call("cook_block_reason"))
	var wood_full := st != null and is_instance_valid(st) and st.has_method("can_load_wood") and not bool(st.call("can_load_wood"))
	for a: Variant in actions:
		var aid := str((a as Dictionary).get("id", ""))
		if cook_why != "" and aid == "cook":
			continue
		if aid == "wood" and wood_full:
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
		btn.rim_color = UiTokens.GOLD if _buttons.is_empty() else UiTokens.HUD_RIM  # B4: the station's main action is gold-rimmed (COOK)
		btn.rim_width = 4.0 if _buttons.is_empty() else 3.0
		HudField.fit(btn, hex_px(get_viewport_rect().size))
		var aid := StringName(str(row.get("id", "")))
		btn.pressed.connect(_on_pressed.bind(aid))
		add_child(btn)
		_buttons.append(btn)
	_show_info()
	visible = true
	_expand_elapsed = 0.0
	_show_ring3d(0.22)
	_update_screen_pos()
	UiTokens.focus_first(_buttons)

## The station's own state line (FIREPITS rule 3: a fire shows the fuel left, and a temporary fire
## its durability). Built from the station's info_lines(), so the card and the tests read the same text.
func _show_info() -> void:
	if info_label != null and is_instance_valid(info_label):
		info_label.queue_free()
	info_label = null
	if station == null or not is_instance_valid(station) or not station.has_method("info_text"):
		return
	var text := str(station.call("info_text"))
	if text == "":
		return
	var lbl := Label.new()
	lbl.name = "StationInfo"
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", int(UiTokens.meta(get_viewport_rect().size)))
	lbl.add_theme_color_override("font_color", UiTokens.TEXT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiTokens.HUD_FILL
	bg.set_content_margin_all(6.0)
	lbl.add_theme_stylebox_override("normal", bg)
	add_child(lbl)
	info_label = lbl

func hide_menu() -> void:
	if info_label != null and is_instance_valid(info_label):
		info_label.queue_free()
	info_label = null
	_clear()
	station = null
	visible = false
	_expand_elapsed = 0.0
	if _ring3d:
		_ring3d.visible = false

func _on_pressed(aid: StringName) -> void:
	var st := station
	# FIREPITS: these two act on the fire in place and keep the menu open, so its fuel line updates.
	if aid == &"wood" and st != null and is_instance_valid(st) and st.has_method("load_wood"):
		st.call("load_wood", player)
		_show_info()
		return
	if aid == &"cook" and st != null and is_instance_valid(st) and st.has_method("can_cook") and not bool(st.call("can_cook")):
		if player != null:
			player.notice("Can't cook: %s" % str(st.call("cook_block_reason")).to_lower())
		return
	hide_menu()
	action_chosen.emit(st, aid)

func _clear() -> void:
	for b in _buttons:
		if is_instance_valid(b):
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
	_expand_elapsed = minf(EXPAND_SECONDS, _expand_elapsed + delta)
	var t := ease(_expand_elapsed / EXPAND_SECONDS, 0.35)
	_show_ring3d(lerpf(0.22, RING_RADIUS, t))
	_update_screen_pos()

func _update_screen_pos() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or station == null:
		return
	var sid := StringName(str(station.get("station_id"))) if station.get("station_id") != null else &""
	var h := float(HEIGHTS.get(sid, DEFAULT_HEIGHT))
	var world := station.global_position + Vector3(0.0, h, 0.0)
	if cam.is_position_behind(world):
		return
	var anchor := cam.unproject_position(world)
	var view := get_viewport_rect().size
	var hx := hex_px(view)
	var spots := ContextRadial.hex_positions(anchor, _buttons.size(), view, UiTokens.safe_insets(get_viewport()), hx, 0.0, UiTokens.hud_reserved(view))
	if info_label != null and is_instance_valid(info_label) and info_label.text != "":
		# Under the ring: measured from the hex spots, so it never covers the actions.
		info_label.size = Vector2.ZERO
		info_label.reset_size()
		var w := info_label.get_minimum_size().x
		var box_below := anchor.y + hx * 1.6
		info_label.position = Vector2(clampf(anchor.x - w * 0.5, MARGIN, maxf(MARGIN, view.x - w - MARGIN)), minf(box_below, view.y - info_label.get_minimum_size().y - MARGIN))
	for i in _buttons.size():
		HudField.fit(_buttons[i], hx)
		if i < spots.size():
			_buttons[i].position = spots[i]

## Station radial hexes (spec §2 sizes: 64 px floor on a phone, larger on desktop like the canvas).
static func hex_px(view: Vector2) -> float:
	return HEX_SIZE if UiTokens.is_compact(view) else 96.0

## A station's name pill in a ring's centre: "● Bonfire" (B4), a green dot = usable here. The recipe
## radial draws it; the action menu leaves the name to the world label (HudPills) beside it.
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
