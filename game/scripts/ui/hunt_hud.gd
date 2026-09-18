class_name HuntHud
extends Control
## The Durango HUD (docs/reference/durango-look-reference.webp, durango-combat-reference.jpg):
## top-left vitals bars, top-right minimap with survivable time and coordinates, bottom-left
## menu hexes (MENU / PETS / BUILD / SKILLS), bottom-right inspect hex, XP bar along the
## bottom, the survivor's name under her feet. During a hunt: red frame, top-centre target
## plate, End Combat, hex skill cluster with Auto and Attack Stance, Chase toggle.
## Everything is a tap; the old text HUD and the TouchControls button cluster are gone.

var player: Player
var _font: Font
var _minimap: Control
var _map_tex: ImageTexture
var _map_island: StringName = &""
var _map_span: int = 0
var _menu_hex: HexButton
var _pets_hex: HexButton
var _build_hex: HexButton
var _skills_hex: HexButton
var _inspect_hex: HexButton
var _sheet: PanelContainer
var _sheet_kind: StringName = &""
var _skills_panel: Control
var _inspector: Panel
# combat
var _end_btn: Button
var _skill_hexes: Array[HexButton] = []
var _auto_hex: HexButton
var _chase_hex: HexButton
var _in_combat: bool = false
var _combat_alpha: float = 0.0
var _stance_label: Label

const MAP_PX := 180.0
const MAP_SCALE := 1.5  # metres per pixel
const HEX := 66.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	if TouchControls:
		TouchControls.hud_mode = true
	_build_minimap()
	_build_menu_row()
	_build_combat()
	get_viewport().size_changed.connect(_layout)
	_layout()

func bind(p: Player) -> void:
	player = p

# ---------------------------------------------------------------- layout

func _layout() -> void:
	var r := get_viewport_rect().size
	var inset := _safe_insets()
	_minimap.position = Vector2(r.x - MAP_PX - 16.0 - inset.x, 34.0 + inset.z)
	var y := r.y - HEX - 14.0 - inset.y
	var x := 16.0 + inset.w
	for h in [_menu_hex, _pets_hex, _build_hex, _skills_hex]:
		h.position = Vector2(x, y)
		x += HEX + 10.0
	_inspect_hex.position = Vector2(r.x - 56.0 - 16.0 - inset.x, r.y - 56.0 - 14.0 - inset.y)
	_end_btn.position = Vector2(r.x - 200.0 - inset.x, r.y * 0.42)
	# Honeycomb cluster bottom-right: net / tackle / kick / roll, Auto below-right, stance text.
	var cx := r.x - 250.0 - inset.x
	var cy := r.y - 150.0 - inset.y
	var slots := [Vector2(-90, -60), Vector2(-10, -20), Vector2(-90, 40), Vector2(70, -50)]
	for i in _skill_hexes.size():
		_skill_hexes[i].position = Vector2(cx, cy) + slots[i]
	_auto_hex.position = Vector2(cx + 60.0, cy + 30.0)
	_stance_label.position = Vector2(cx + 20.0, cy + 118.0)
	_chase_hex.position = Vector2(16.0 + inset.w, r.y - HEX * 2.0 - 40.0 - inset.y)
	if _sheet:
		_sheet.position = Vector2(16.0 + inset.w, r.y - HEX - 30.0 - inset.y - _sheet.size.y)

func _safe_insets() -> Vector4:  # x=right, y=bottom, z=top, w=left
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var rect := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var scale := rect / win if win.x > 0.0 and win.y > 0.0 else Vector2.ONE
	var safe := DisplayServer.get_display_safe_area()
	return Vector4(maxf(0.0, win.x - (safe.position.x + safe.size.x)) * scale.x, maxf(0.0, win.y - (safe.position.y + safe.size.y)) * scale.y, maxf(0.0, safe.position.y) * scale.y, maxf(0.0, safe.position.x) * scale.x)

# ---------------------------------------------------------------- build

func _build_minimap() -> void:
	_minimap = Control.new()
	_minimap.name = "Minimap"
	_minimap.size = Vector2(MAP_PX, MAP_PX)
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap.draw.connect(_draw_minimap)
	_minimap.gui_input.connect(func (ev: InputEvent) -> void:
		if (ev is InputEventScreenTouch and not (ev as InputEventScreenTouch).pressed) or (ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
			_open_map()
			_minimap.accept_event()
	)
	add_child(_minimap)

func _hex(glyph: String, size_px: float = HEX) -> HexButton:
	var h := HexButton.new(size_px)
	h.glyph = glyph
	add_child(h)
	return h

func _build_menu_row() -> void:
	_menu_hex = _hex("≡")
	_menu_hex.pressed.connect(func () -> void: _toggle_sheet(&"menu"))
	_pets_hex = _hex("🦖")
	_pets_hex.pressed.connect(func () -> void: _toggle_sheet(&"pets"))
	_build_hex = _hex("⌂")
	_build_hex.pressed.connect(func () -> void: _toggle_sheet(&"build"))
	_skills_hex = _hex("★")
	_skills_hex.pressed.connect(_toggle_skills)
	_inspect_hex = _hex("🔍", 56.0)
	_inspect_hex.pressed.connect(func () -> void:
		Game.debug_overlay = not Game.debug_overlay
		print("[hud] inspect %s" % ("on" if Game.debug_overlay else "off"))
	)

func _build_combat() -> void:
	_end_btn = Button.new()
	_end_btn.text = "✕  End Combat"
	_end_btn.custom_minimum_size = Vector2(184, 64)
	_end_btn.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.72, 0.12, 0.12, 0.95)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_end_btn.add_theme_stylebox_override("normal", sb)
	_end_btn.add_theme_stylebox_override("hover", sb)
	_end_btn.add_theme_stylebox_override("pressed", sb)
	_end_btn.pressed.connect(func () -> void:
		if player and player.hunt:
			player.hunt.stop()
	)
	_end_btn.visible = false
	add_child(_end_btn)
	var specs := [["🕸", "net"], ["🔪", "tackle"], ["🦵", "kick"], ["↯", "roll"]]
	for s in specs:
		var h := HexButton.new(72.0)
		h.glyph = s[0]
		h.visible = false
		h.pressed.connect(_on_skill.bind(StringName(s[1])))
		add_child(h)
		_skill_hexes.append(h)
	_auto_hex = HexButton.new(80.0)
	_auto_hex.glyph = "Auto"
	_auto_hex.fill = Color(0.93, 0.72, 0.15, 0.95)
	_auto_hex.accent = Color(1.0, 0.9, 0.5)
	_auto_hex.visible = false
	_auto_hex.pressed.connect(func () -> void:
		if player and player.hunt:
			player.hunt.auto = not player.hunt.auto
			_auto_hex.fill = Color(0.93, 0.72, 0.15, 0.95) if player.hunt.auto else Color(0.25, 0.25, 0.25, 0.9)
			_auto_hex.queue_redraw()
	)
	add_child(_auto_hex)
	_stance_label = Label.new()
	_stance_label.text = "Attack Stance ◎"
	_stance_label.add_theme_font_size_override("font_size", 16)
	_stance_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_stance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stance_label.visible = false
	add_child(_stance_label)
	_chase_hex = HexButton.new(HEX)
	_chase_hex.glyph = "🏃"
	_chase_hex.fill = Color(0.93, 0.72, 0.15, 0.95)
	_chase_hex.visible = false
	_chase_hex.pressed.connect(func () -> void:
		if player and player.hunt:
			player.hunt.hold = not player.hunt.hold
			_chase_hex.fill = Color(0.25, 0.25, 0.25, 0.9) if player.hunt.hold else Color(0.93, 0.72, 0.15, 0.95)
			_chase_hex.queue_redraw()
	)
	add_child(_chase_hex)

func _on_skill(id: StringName) -> void:
	if player == null or player.hunt == null:
		return
	match id:
		&"net":
			player.hunt.use_net()
		&"tackle":
			player.hunt.use_tackle()
		&"kick":
			player.hunt.use_kick()
		&"roll":
			player._try_roll()

# ---------------------------------------------------------------- sheets

func _toggle_sheet(kind: StringName) -> void:
	if _sheet and _sheet_kind == kind:
		_close_sheet()
		return
	_close_sheet()
	_sheet_kind = kind
	_sheet = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_sheet.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_sheet.add_child(box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	match kind:
		&"menu":
			title.text = "Menu"
			_sheet_btn(box, "Bag", func () -> void: _close_sheet(); if player.ui: player.ui.visible = not player.ui.visible)
			_sheet_btn(box, "Craft", func () -> void: _close_sheet(); if player.craft_ui: player.craft_ui.toggle())
			_sheet_btn(box, "Map", func () -> void: _close_sheet(); _open_map())
			_sheet_btn(box, "Save", func () -> void: _close_sheet(); (load("res://scripts/core/save_game.gd") as GDScript).save_now())
		&"pets":
			title.text = "Pets  %d / %d" % [player.bonded.size(), Data.bonded_cap()]
			if player.bonded.is_empty():
				var l := Label.new()
				l.text = "No bonded animals yet. Knock one down and feed it."
				box.add_child(l)
			for i in player.bonded.size():
				var rec: PetRecord = player.bonded[i]
				var idx := i
				_sheet_btn(box, "%s  grade %s  hp %.0f" % [rec.species, rec.grade, rec.hp], func () -> void: _close_sheet(); player.summon_pet(idx))
			if player.summoned_pet and is_instance_valid(player.summoned_pet):
				_sheet_btn(box, "Dismiss %s" % player.summoned_pet.def.id, func () -> void: _close_sheet(); player.summon_pet())
		&"build":
			title.text = "Build"
			var any := false
			for i in player.inventory.slot_count:
				var s: ItemStack = player.inventory.slots[i]
				if s == null:
					continue
				var def := Data.item(s.def_id)
				if def == null or str(def.get("place_as")) == "":
					continue
				any = true
				var kind_id := StringName(str(def.get("place_as")))
				var fp: Variant = def.get("footprint")
				var fp_txt := ""
				if fp is Array and (fp as Array).size() >= 2:
					fp_txt = "  %d×%d" % [int(fp[0]), int(fp[1])]
				_sheet_btn(box, "%s%s  ×%d" % [def.display_name, fp_txt, s.count], func () -> void: _close_sheet(); player.placer.begin(kind_id))
			if not any:
				var l := Label.new()
				l.text = "No building kits in the bag. Craft one at the workbench."
				box.add_child(l)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(240, 56)
	close.pressed.connect(_close_sheet)
	box.add_child(close)
	add_child(_sheet)
	_sheet.size = Vector2(320, 0)
	await get_tree().process_frame
	_layout()

func _sheet_btn(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 60)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	box.add_child(b)

func _close_sheet() -> void:
	if _sheet:
		_sheet.queue_free()
		_sheet = null
	_sheet_kind = &""

func _toggle_skills() -> void:
	var p := get_tree().root.find_child("SkillDebug", true, false)
	if p == null:
		var sd := SkillDebug.new()
		sd.name = "SkillDebug"
		get_parent().add_child(sd)
		p = sd
	p.visible = not p.visible
	if p.visible and p.has_method("_rebuild"):
		p._rebuild()

func _open_map() -> void:
	var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
	if ui:
		ui.show_map()

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if player == null:
		return
	var hunting := player.hunt != null and player.hunt.target != null and is_instance_valid(player.hunt.target)
	if hunting != _in_combat:
		_in_combat = hunting
		_end_btn.visible = hunting
		for h in _skill_hexes:
			h.visible = hunting
		_auto_hex.visible = hunting
		_stance_label.visible = hunting
		_chase_hex.visible = hunting
		if hunting:
			var t := player.hunt.target
			print("[hud] target %s lv=%d hp=%.0f/%.0f" % [t.def.id, t.level, t.health.hp, t.health.max_hp])
	_combat_alpha = move_toward(_combat_alpha, 1.0 if hunting else 0.0, delta * 5.0)
	if hunting:
		_skill_hexes[0].disabled = not (player.hunt.target.capturable() and player.hunt._best_net_ok())
		_skill_hexes[1].disabled = player.hunt._tackle_cd > 0.0
		_skill_hexes[2].disabled = player.hunt._kick_cd > 0.0
		for h in _skill_hexes:
			h.queue_redraw()
	_minimap.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	var r := get_viewport_rect().size
	var v := player.vitals
	# --- vitals top-left
	var x := 30.0
	var y := 14.0
	_bar(Vector2(x, y), Vector2(230, 16), v.health / maxf(1.0, v.effective_max_health()), Color(0.78, 0.13, 0.13), "♥", "%.0f / %.0f" % [v.health, v.effective_max_health()])
	_bar(Vector2(x, y + 22), Vector2(230, 16), v.energy / maxf(1.0, v.max_energy), Color(0.20, 0.45, 0.80), "⚡", "%.0f / %.0f" % [v.energy, v.max_energy])
	_bar(Vector2(x, y + 44), Vector2(230, 8), clampf(v.fatigue / maxf(1.0, v.max_fatigue), 0.0, 1.0), Color(0.55, 0.55, 0.55), "", "")
	if v.exhausted:
		draw_string(_font, Vector2(x + 236, y + 52), "EXHAUSTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.6, 0.4))
	# status icons row
	var sx := x
	if player.statuses:
		for inst in player.statuses.instances():
			draw_rect(Rect2(sx, y + 60, 26, 26), Color(0.1, 0.1, 0.12, 0.85))
			draw_string(_font, Vector2(sx + 4, y + 79), str(inst.id).left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.75, 0.45))
			draw_string(_font, Vector2(sx, y + 100), "%.0f" % inst.time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
			sx += 30
	# --- minimap captions
	var mp := _minimap.position
	var top := "Home" if World.is_home() else ("Survivable for %d min" % int(ceil(World.remaining_lifetime / 60.0)))
	if World.island_id == &"":
		top = "Lab"
	draw_string(_font, Vector2(mp.x, mp.y - 8), top, HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, 15, Color.WHITE)
	var tile := BuildGrid.tile_of(player.global_position)
	draw_string(_font, Vector2(mp.x, mp.y + MAP_PX + 18), "X %d  Y %d" % [tile.x, tile.y], HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, 13, Color(0.9, 0.85, 0.6))
	draw_string(_font, Vector2(mp.x, mp.y + MAP_PX + 36), "%s  %s" % [Game.clock_label(), Game.phase_name()], HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, 13, Color(0.85, 0.85, 0.85))
	# --- XP bar along the bottom
	var prog := World.pioneer_progress() if World.has_method("pioneer_progress") else 0.0
	draw_rect(Rect2(0, r.y - 7, r.x, 7), Color(0.05, 0.05, 0.07, 0.9))
	draw_rect(Rect2(0, r.y - 7, r.x * prog, 7), Color(0.55, 0.25, 0.75))
	var lv := "Lv. %d  %.1f%%" % [World.pioneer_level, prog * 100.0]
	var lw := _font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
	draw_string(_font, Vector2(r.x * 0.5 - lw * 0.5, r.y - 10), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# --- name under the survivor
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.unproject_position(player.global_position - Vector3(0, 0.05, 0))
		var name := player.display_name() if player.has_method("display_name") else "Survivor"
		var nw := _font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
		draw_string(_font, Vector2(p.x - nw * 0.5 + 1, p.y + 21), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.7))
		draw_string(_font, Vector2(p.x - nw * 0.5, p.y + 20), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.95, 0.95))
	# --- combat layer
	if _combat_alpha > 0.01:
		var a := _combat_alpha
		draw_rect(Rect2(0, 0, r.x, 6), Color(0.85, 0.1, 0.1, 0.75 * a))
		draw_rect(Rect2(0, r.y - 6, r.x, 6), Color(0.85, 0.1, 0.1, 0.75 * a))
		var t := player.hunt.target if player.hunt else null
		if t and is_instance_valid(t):
			var pw := 520.0
			var px := r.x * 0.5 - pw * 0.5
			var py := 14.0
			var nm := "%s" % str(t.def.id).capitalize()
			draw_string(_font, Vector2(px + 40, py + 30), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, a))
			var nmw := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string(_font, Vector2(px + 40 + nmw + 14, py + 30), "Lv. %d" % t.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.3, 0.25, a))
			draw_rect(Rect2(px + pw - 60, py - 4, 52, 52), Color(0.12, 0.12, 0.14, 0.9 * a))
			draw_string(_font, Vector2(px + pw - 48, py + 32), str(t.def.id).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, a))
			var frac := clampf(t.health.hp / maxf(1.0, t.health.max_hp), 0.0, 1.0)
			draw_rect(Rect2(px, py + 44, pw, 22), Color(0.12, 0.05, 0.05, 0.9 * a))
			draw_rect(Rect2(px, py + 44, pw * frac, 22), Color(0.80, 0.12, 0.12, 0.95 * a))
			var hp := "%.0f / %.0f" % [t.health.hp, t.health.max_hp]
			var hw := _font.get_string_size(hp, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
			draw_string(_font, Vector2(px + pw * 0.5 - hw * 0.5, py + 61), hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, a))
			var ix := px
			if t.statuses:
				for inst in t.statuses.instances():
					draw_rect(Rect2(ix, py + 74, 26, 26), Color(0.1, 0.1, 0.12, 0.85 * a))
					draw_string(_font, Vector2(ix + 4, py + 93), str(inst.id).left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.6, 0.5, a))
					ix += 30
		# labels for the hex cluster
		draw_string(_font, _chase_hex.position + Vector2(HEX + 8, HEX * 0.5 + 6), "Hold" if player.hunt.hold else "Chase", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, a))

func _bar(pos: Vector2, size: Vector2, frac: float, col: Color, glyph: String, text: String) -> void:
	draw_rect(Rect2(pos, size), Color(0.08, 0.08, 0.1, 0.85))
	draw_rect(Rect2(pos, Vector2(size.x * clampf(frac, 0.0, 1.0), size.y)), col)
	draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.6), false, 1.0)
	if glyph != "":
		draw_string(_font, pos + Vector2(-14, size.y - 3), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if text != "":
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
		draw_string(_font, pos + Vector2(size.x - w - 6, size.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

# ---------------------------------------------------------------- minimap

func _ensure_map_texture() -> void:
	var rt := World.runtime
	if rt == null or not rt.has_method("surface_y"):
		return
	if _map_tex != null and _map_island == World.island_id:
		return
	var types: PackedByteArray = rt.get("tile_types")
	var span: int = int(rt.get("_tile_span"))
	if types.is_empty() or span <= 0:
		return
	var img := Image.create(span, span, false, Image.FORMAT_RGB8)
	for z in span:
		for x in span:
			var t := int(types[x + z * span])
			var c := Color(0.36, 0.52, 0.28)  # grass
			match t:
				1: c = Color(0.52, 0.50, 0.32)
				2, 7: c = Color(0.42, 0.32, 0.22)
				3: c = Color(0.80, 0.72, 0.52)
				10: c = Color(0.62, 0.55, 0.42)
				4: c = Color(0.55, 0.78, 0.82)
				8: c = Color(0.16, 0.30, 0.46)
				5, 9: c = Color(0.45, 0.45, 0.44)
				6: c = Color(0.36, 0.28, 0.20)
			img.set_pixel(x, z, c)
	_map_tex = ImageTexture.create_from_image(img)
	_map_island = World.island_id
	_map_span = span

func _draw_minimap() -> void:
	var c := _minimap
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.05, 0.06, 0.08, 0.85))
	_ensure_map_texture()
	if player == null:
		return
	var rt := World.runtime
	if _map_tex and rt:
		var size_m: float = float(rt.get("_size"))
		var half := MAP_PX * 0.5 * MAP_SCALE  # metres covered from centre to edge
		var pp := player.global_position
		var u0 := (pp.x - half + size_m * 0.5)
		var v0 := (pp.z - half + size_m * 0.5)
		c.draw_texture_rect_region(_map_tex, Rect2(Vector2.ZERO, c.size), Rect2(u0, v0, half * 2.0, half * 2.0))
		var to_px := func (w: Vector3) -> Vector2:
			return Vector2((w.x - pp.x) / MAP_SCALE + MAP_PX * 0.5, (w.z - pp.z) / MAP_SCALE + MAP_PX * 0.5)
		var camp: Vector3 = rt.get("_camp_pos")
		var harb: Vector3 = rt.get("_harbour_pos")
		c.draw_circle(to_px.call(camp), 4.0, Color(1.0, 0.85, 0.3))
		c.draw_circle(to_px.call(harb), 4.0, Color(0.7, 0.85, 1.0))
		if World.crater_discovered:
			var cr: Vector3 = rt.get("_crater_pos")
			c.draw_circle(to_px.call(cr), 4.0, Color(0.9, 0.4, 0.2))
		for n in get_tree().get_nodes_in_group("creatures"):
			var cr := n as Creature
			if cr == null or cr.health.dead:
				continue
			var q: Vector2 = to_px.call(cr.global_position)
			if q.x < 0 or q.y < 0 or q.x > MAP_PX or q.y > MAP_PX:
				continue
			c.draw_circle(q, 2.5, Color(0.4, 0.9, 0.4) if cr.is_pet else Color(0.95, 0.35, 0.3))
	# player arrow (north up; yaw around Y)
	var centre := Vector2(MAP_PX * 0.5, MAP_PX * 0.5)
	var yaw := player.visual.rotation.y if player.visual else 0.0
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	c.draw_colored_polygon(PackedVector2Array([centre + fwd * 8.0, centre - fwd * 5.0 + side * 5.0, centre - fwd * 5.0 - side * 5.0]), Color(1, 1, 1))
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 1, 1, 0.35), false, 1.5)
