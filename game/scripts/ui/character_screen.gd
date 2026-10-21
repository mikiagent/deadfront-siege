class_name CharacterScreen
extends GearScreen
## Character -> Gear (spec 13 s13-14, reference durango-character-gear): left, the survivor's card
## (portrait, name, occupation, the green XP bar "Lv. 13 (222 / 345)", Combat / Crafting /
## Gathering Power rows and Detailed Stats); centre, the yellow Gear tab, the numbered presets and
## the 3x3 gear cells; right, what fits the selected cell over Unequip. Picking a bag candidate opens
## Equipment to compare before wearing it (design assumption 19).

signal compare_requested(slot: StringName, uid: String)

var presets: GearPresetSelector
var stats_panel: DetailedStatsPanel
var details: Button
var power_rows: Array[Button] = []
var _info: Control
var _centre: Control
var _portrait: TextureRect
var _shot: SubViewport

func _build_body() -> void:
	_info = _panel(0.0)
	_info.draw.connect(_draw_info)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(_portrait)
	for group: String in InvStats.powers_data():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Detailed Stats"
		b.draw.connect(_draw_power.bind(b, group))
		b.pressed.connect(open_stats.bind(group))
		_info.add_child(b)
		power_rows.append(b)
	details = Button.new()
	details.text = "Detailed Stats"
	details.focus_mode = Control.FOCUS_NONE
	details.pressed.connect(open_stats.bind(""))
	_info.add_child(details)
	_centre = _panel(2.0)
	_centre.draw.connect(_draw_centre)
	presets = GearPresetSelector.new()
	presets.chosen.connect(_on_preset)
	_centre.add_child(presets)

func _ready() -> void:
	header.set_title("Character")

func _panel(seed_v: float) -> Control:
	var c := Control.new()
	c.clip_contents = true
	var surf := InvTheme.surface(InvTheme.PANEL, 1.1, seed_v)
	surf.show_behind_parent = true # the panel's own drawing (name, XP bar, Gear tab) goes over it
	c.add_child(surf)
	add_child(c)
	return c

func refresh() -> void:
	super.refresh()
	if presets and inventory:
		presets.show_state(inventory)
	if _info:
		_info.queue_redraw()
		_centre.queue_redraw()

## Detailed Stats over this screen, scrolled to `group` ("" = top).
func open_stats(group: String = "") -> void:
	if stats_panel == null:
		stats_panel = DetailedStatsPanel.new()
		add_child(stats_panel)
		stats_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stats_panel.back_pressed.connect(func() -> void: stats_panel.visible = false)
		stats_panel.close_pressed.connect(func() -> void: close_pressed.emit())
	stats_panel.open(player, group)

func _on_preset(k: int) -> void:
	_refusal = GearPresets.switch(player, k) if player else ""
	refresh()

## A bag candidate goes to Equipment for the comparison; the worn one stays here for Unequip.
func _on_pick(uid: String) -> void:
	var p := picked()
	if p and p != worn():
		list.select_uid("")
		compare_requested.emit(slot, uid)
		return
	super._on_pick(uid)

func _right_share() -> float:
	return 0.26

func _layout_body(area: Rect2) -> void:
	var m := _m
	var left_w := floorf(area.size.x * 0.52) # reference 2: 36 % : 33 % of the width
	_info.position = area.position
	_info.size = Vector2(left_w, area.size.y)
	var cx: float = area.position.x + left_w + float(m.gap)
	_centre.position = Vector2(cx, area.position.y)
	_centre.size = Vector2(area.end.x - cx, area.size.y)
	# Left card: portrait, name, status, XP bar, three power rows, Detailed Stats.
	var pad: float = m.margin
	var side := clampf(area.size.y * 0.16, 48.0, 140.0)
	_portrait.position = Vector2(pad, pad)
	_portrait.size = Vector2(side, side)
	_portrait.texture = _portrait_texture()
	var btn_h := 44.0 if m.compact else 64.0
	details.size = Vector2(maxf(left_w * 0.5, 160.0 if not m.compact else 120.0), btn_h)
	details.position = Vector2((left_w - details.size.x) * 0.5, area.size.y - pad - btn_h)
	details.add_theme_font_size_override("font_size", int(m.row_font))
	details.add_theme_color_override("font_color", InvTheme.TEXT_2)
	var rows_top := _xp_rect().end.y + pad * 0.5
	var row_h := clampf((details.position.y - pad * 0.5 - rows_top) / maxf(1.0, power_rows.size()), 44.0, 100.0)
	for i in power_rows.size():
		power_rows[i].position = Vector2(0, rows_top + row_h * i)
		power_rows[i].size = Vector2(left_w, row_h)
	# Centre: Gear tab, presets, title strip (desktop), then the 3x3.
	var tab_h := 40.0 if m.compact else 72.0
	var preset_h := 44.0 if m.compact else 76.0
	presets.position = Vector2(0, tab_h + 4.0)
	presets.size = Vector2(_centre.size.x, preset_h)
	presets.font_px = int(m.name_font) - (0 if m.compact else 6)
	var strip := 0.0 if m.compact else 64.0
	var top := presets.position.y + preset_h + 8.0 + (strip + 8.0 if strip > 0.0 else 0.0)
	EquipmentSlot.layout(cells, Rect2(_centre.position + Vector2(0, top), Vector2(_centre.size.x, _centre.size.y - top)), maxi(UiTokens.TYPE_MIN, int(m.lv_font) - 2))
	_info.queue_redraw()
	_centre.queue_redraw()

func _xp_rect() -> Rect2:
	var pad: float = _m.margin
	return Rect2(Vector2(0, _portrait.position.y + _portrait.size.y + pad * 0.6), Vector2(_info.size.x, _m.row_h))

func _draw_info() -> void:
	if _m.is_empty() or player == null:
		return
	var f := InvTheme.font()
	var pad: float = _m.margin
	_info.draw_rect(Rect2(_portrait.position, _portrait.size).grow(2.0), Color(0, 0, 0, 0.7), false, 3.0)
	var x := _portrait.position.x + _portrait.size.x + pad
	var w := _info.size.x - x - pad
	var npx := int(_m.name_font)
	var spx := int(_m.row_font)
	_info.draw_string(f, Vector2(x, _portrait.position.y + f.get_ascent(npx)), UiTokens.ellipsis(f, player.display_name(), w, npx), HORIZONTAL_ALIGNMENT_LEFT, -1, npx, InvTheme.TEXT)
	_info.draw_string(f, Vector2(x, _portrait.position.y + npx * 1.45 + f.get_ascent(spx)), UiTokens.ellipsis(f, _status(), w, spx), HORIZONTAL_ALIGNMENT_LEFT, -1, spx, InvTheme.TEXT_2)
	# Green XP bar: "Lv. 13 (222 / 345)", the current XP in yellow (reference).
	var bar := _xp_rect()
	_info.draw_rect(bar, Color("#0C0F0C"))
	_info.draw_rect(Rect2(bar.position, Vector2(bar.size.x * World.pioneer_progress(), bar.size.y)), Color("#235D23"))
	InvPaint.dashed(_info, Vector2(0, bar.position.y), Vector2(bar.size.x, bar.position.y), Color(1, 1, 1, 0.25))
	var parts := _xp_parts()
	var tw := 0.0
	for p in parts:
		tw += f.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, spx).x
	var tx := (bar.size.x - tw) * 0.5
	for p in parts:
		_info.draw_string(f, Vector2(tx, bar.position.y + (bar.size.y + f.get_ascent(spx) - f.get_descent(spx)) * 0.5), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, spx, p[1])
		tx += f.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, spx).x
	var sep_y := details.position.y - pad * 0.5
	InvPaint.dashed(_info, Vector2(0, sep_y), Vector2(_info.size.x, sep_y), Color(1, 1, 1, 0.18))
	InvPaint.frame(_info, Rect2(Vector2.ZERO, _info.size), 2.0 if _m.compact else 3.0, 3)

## "Lv. 13  (222 / 345)" in parts, the current XP yellow (reference).
func _xp_parts() -> Array:
	return [[LevelDisplay.player_label() + "  (", InvTheme.TEXT], ["%d" % World.pioneer_xp, InvTheme.SELECT],
		[" / %d)" % World.xp_for_level(LevelDisplay.player_level() - 1), InvTheme.TEXT]]

## The card's text as drawn: name, status, XP bar, title (labs and tests read it).
func profile_lines() -> PackedStringArray:
	var xp := ""
	for p in _xp_parts():
		xp += str(p[0])
	return PackedStringArray([player.display_name() if player else "", _status(), xp, _title()])

## Occupation (no clans exist); on the phone the title joins it (the title strip is desktop only).
func _status() -> String:
	var occ := World.occupation.capitalize() if World.occupation != "" else "Survivor"
	return "%s · %s" % [occ, _title()] if _m.get("compact", false) and _title() != "" else occ

func _title() -> String:
	return LevelDisplay.current_title(LevelDisplay.player_level())

func _draw_power(b: Button, group: String) -> void:
	var row: Dictionary = InvStats.powers_data().get(group, {})
	var f := InvTheme.font()
	var px := int(_m.row_font) + (2 if _m.compact else 6)
	var h := b.size.y
	var pad: float = _m.margin
	var ic := UiIcons.icon(StringName(str(row.get("icon", group))))
	var s := minf(h * 0.5, px * 1.4)
	if ic:
		b.draw_texture_rect(ic, Rect2(Vector2(pad, (h - s) * 0.5), Vector2(s, s)), false, Color(1, 1, 1, 0.9))
	var base := (h + f.get_ascent(px) - f.get_descent(px)) * 0.5
	b.draw_string(f, Vector2(pad * 1.5 + s, base), str(row.get("label", group)), HORIZONTAL_ALIGNMENT_LEFT, -1, px, InvTheme.TEXT)
	var chev := Rect2(Vector2(b.size.x - pad - h * 0.5, 0), Vector2(h * 0.5, h))
	InvGlyphs.chevron(b, chev, InvTheme.TEXT_2)
	var v := "%d" % (InvStats.power(player, group) if player else 0)
	var vw := f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, px + 4).x
	b.draw_string(f, Vector2(chev.position.x - vw - pad * 0.5, base), v, HORIZONTAL_ALIGNMENT_LEFT, -1, px + 4, InvTheme.SELECT)
	InvPaint.dashed(b, Vector2(pad, h - 1.0), Vector2(b.size.x - pad, h - 1.0), Color(1, 1, 1, 0.18))

func _draw_centre() -> void:
	if _m.is_empty():
		return
	var f := InvTheme.font()
	var w := _centre.size.x
	var tab_h := presets.position.y - 4.0
	# Only the Gear tab: no cosmetic gear exists, so a Decorative Gear tab would be empty (assumption 13).
	var tab := Rect2(Vector2.ZERO, Vector2(w * 0.5, tab_h))
	_centre.draw_rect(tab, InvTheme.PRIMARY)
	UiTokens.draw_centered(_centre, f, tab.get_center(), "Gear", int(_m.name_font) - (0 if _m.compact else 8), InvTheme.PRIMARY_INK)
	_centre.draw_line(Vector2(0, tab_h + 1.0), Vector2(w, tab_h + 1.0), InvTheme.PRIMARY.darkened(0.3), 2.0)
	if not _m.compact:
		var strip := Rect2(Vector2(8.0, presets.position.y + presets.size.y + 8.0), Vector2(w - 16.0, 64.0))
		_centre.draw_rect(strip, Color(0, 0, 0, 0.55))
		var t := _title() if _title() != "" else "No Title"
		_centre.draw_string(f, Vector2(strip.position.x + 24.0, strip.position.y + (strip.size.y + f.get_ascent(int(_m.row_font) + 4) - f.get_descent(int(_m.row_font) + 4)) * 0.5), UiTokens.ellipsis(f, t, strip.size.x - 48.0, int(_m.row_font) + 4), HORIZONTAL_ALIGNMENT_LEFT, -1, int(_m.row_font) + 4, InvTheme.TEXT_2)
	var g := cells[0].position - _centre.position
	_centre.draw_rect(Rect2(g, cells[0].size * 3.0).grow(1.0), InvTheme.FRAME_INK, false, 2.0)
	InvPaint.frame(_centre, Rect2(Vector2.ZERO, _centre.size), 2.0 if _m.compact else 3.0, 4)

## A one-shot render of the survivor model's head, as Durango's portrait square (design assumption 17).
func _portrait_texture() -> Texture2D:
	if _shot == null and is_inside_tree():
		var scene := load("res://assets/characters/survivor/survivor.glb") as PackedScene
		if scene == null or DisplayServer.get_name() == "headless": # nothing to render without a GPU
			return UiIcons.icon(&"survival")
		_shot = SubViewport.new()
		_shot.size = Vector2i(256, 256)
		_shot.own_world_3d = true
		_shot.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(_shot)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("#3B3A2C")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.55, 0.53, 0.48)
		_shot.add_child(env)
		var body := scene.instantiate() as Node3D
		_shot.add_child(body)
		var box := _bounds(body)
		var head := Vector3(box.get_center().x, box.end.y - box.size.y * 0.075, box.get_center().z)
		var cam := Camera3D.new()
		cam.fov = 30.0
		_shot.add_child(cam)
		cam.look_at_from_position(head + Vector3(0, box.size.y * 0.01, box.size.y * 0.55), head)
		var sun := DirectionalLight3D.new()
		_shot.add_child(sun)
		sun.look_at_from_position(head + Vector3(0.6, 1.0, 1.2), head)
	return _shot.get_texture() if _shot else null

static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 1.8, 0.6))
