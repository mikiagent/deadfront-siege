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
var _animal_screen: AnimalScreen
var _inspector: Panel
# combat
var _end_btn: Button
var _skill_hexes: Array[HexButton] = []
var _auto_hex: HexButton
var _chase_hex: HexButton
var _feed_hex: HexButton
var _food_hexes: Array[HexButton] = []
var _whistle_hexes: Array[HexButton] = []  # attack / heel / guard, shown while a pet is out
var _in_combat: bool = false
var _combat_alpha: float = 0.0
var _last_target: Creature  # top plate stays on the last creature attacked until it dies or a new one is hit
var _stance_label: Label
var _events := HudEventState.new()
var _ctx_hexes: Array[HexButton] = []
var _ctx_ids: Array = []
var _ctx_timer: float = 0.0
var _place_hexes: Array[HexButton] = []
var _done_hex: HexButton
var _levelup_lines: Array = []
var _levelup_t: float = -1.0
var _titles: Dictionary = {}
var _level_gains: Dictionary = {}
# hits on the survivor: bite/crunch jaws + red numbers

# death
var _death_panel: Control
var _death_card: Panel
var _death_title: Label
var _death_cause: Label
var _death_note: Label
var _death_alpha: float = 0.0
var _death_btn: Button

const MAP_PX := 154.0
const MAP_SCALE := 0.95  # metres per pixel
const HEX := 64.0
const CAPTION_H := 18.0  # room for the action word HexButton draws under a hex

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	if TouchControls:
		TouchControls.hud_mode = true
	_build_minimap()
	_build_menu_row()
	_build_combat()
	_build_place_hexes()
	_build_death()
	add_to_group("hud")
	_load_level_data()
	if World.has_signal("pioneer_changed"):
		World.pioneer_changed.connect(_on_level_up)
	if Game.shot_path.contains("skills") or Game.shot_path.contains("tree"):
		get_tree().create_timer(0.8).timeout.connect(func () -> void: _toggle_skills("gathering" if Game.shot_path.contains("tree") else ""))
	if Game.shot_path.contains("layout"):
		get_tree().create_timer(0.9).timeout.connect(func () -> void:
			player.placer.begin_layout()
			var best: Node3D = null
			var bd := INF
			for n in get_tree().get_nodes_in_group("craft_station") + get_tree().get_nodes_in_group("placed_building"):
				if n is Node3D and BuildPlacer.is_movable(n):
					var d: float = player.global_position.distance_to((n as Node3D).global_position)
					if d < bd:
						bd = d
						best = n
			if best:
				Game.pointer = get_viewport().get_camera_3d().unproject_position(best.global_position)
				player.placer.pick_up(best)
				if Game.shot_path.contains("layoutdrag"):
					player.placer.drag_to(Game.pointer + Vector2(70.0, -18.0))
				player.placer.dragging = false
		)
	if Game.shot_path.contains("bigmap"):
		get_tree().create_timer(0.9).timeout.connect(_open_map)
	if Game.shot_path.contains("exhaustion") and player:
		player.vitals.fatigue = 96.0 if Game.shot_path.contains("sad") else (60.0 if Game.shot_path.contains("weary") else 0.0)
	if Game.shot_path.contains("levelup"):
		get_tree().create_timer(0.8).timeout.connect(func () -> void: World.pioneer_level += 1; World.pioneer_changed.emit(World.pioneer_level))
	get_viewport().size_changed.connect(_layout)
	_layout()
	if "--bite-test" in OS.get_cmdline_user_args():  # screenshot runs: snap the jaws every 0.45 s
		var t := Timer.new()
		t.wait_time = 0.45
		t.autostart = true
		t.timeout.connect(func () -> void: bite_on_player(12.0, randf() < 0.5))
		add_child(t)

func bind(p: Player) -> void:
	player = p

# ---------------------------------------------------------------- layout

func _layout() -> void:
	var r := get_viewport_rect().size
	var inset := _safe_insets()
	_minimap.position = Vector2(r.x - MAP_PX - 16.0 - inset.x, 34.0 + inset.z)
	var y := r.y - HEX - CAPTION_H - 14.0 - inset.y  # captions sit under the hexes, inside the safe area
	var x := 16.0 + inset.w
	for h in [_menu_hex, _pets_hex, _build_hex, _skills_hex]:
		h.position = Vector2(x, y)
		x += HEX + 10.0
	for i in _food_hexes.size():
		_food_hexes[i].position = Vector2(16.0 + inset.w + float(i) * (HEX + 10.0), y - HEX - CAPTION_H - 12.0)
	# Debug hex stays off the minimap. On a phone it drops to the lower right so the vitals can sit beside the map.
	_inspect_hex.visible = Game.debug_overlay
	if UiTokens.is_phone(r):
		_inspect_hex.position = Vector2(r.x - HEX - 16.0 - inset.x, r.y - HEX * 2.0 - 36.0 - inset.y)
	else:
		_inspect_hex.position = Vector2(_minimap.position.x - 56.0 - 12.0, _minimap.position.y + (MAP_PX - 56.0) * 0.5)
	_end_btn.position = Vector2(r.x - 200.0 - inset.x, r.y * 0.42)
	# Honeycomb cluster bottom-right: net / tackle / kick / roll, Auto below-right, stance text.
	var cx := r.x - 250.0 - inset.x
	var cy := r.y - 150.0 - inset.y
	var slots := [Vector2(-90, -60), Vector2(-10, -20), Vector2(-90, 40), Vector2(70, -50)]
	for i in _skill_hexes.size():
		_skill_hexes[i].position = Vector2(cx, cy) + slots[i]
	_auto_hex.position = Vector2(cx + 60.0, cy + 30.0)
	_feed_hex.position = Vector2(cx - 170.0, cy - 20.0)
	for i in _whistle_hexes.size():
		_whistle_hexes[i].position = Vector2(r.x - 16.0 - inset.x - 62.0, r.y - 250.0 - inset.y - float(i) * (66.0 + CAPTION_H))
	_stance_label.position = Vector2(cx + 20.0, cy + 118.0)
	_chase_hex.position = Vector2(16.0 + inset.w, r.y - HEX * 2.0 - CAPTION_H * 2.0 - 40.0 - inset.y)
	if _sheet:
		_sheet.position = Vector2(16.0 + inset.w, r.y - HEX - CAPTION_H - 30.0 - inset.y - _sheet.size.y)

func _safe_insets() -> Vector4:  # x=right, y=bottom, z=top, w=left
	return UiTokens.safe_insets(get_viewport())

# ---------------------------------------------------------------- build

func _build_minimap() -> void:
	_minimap = Control.new()
	_minimap.name = "Minimap"
	_minimap.size = Vector2(MAP_PX, MAP_PX)
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap.clip_contents = true
	# The map is drawn square. A WebGL-safe opaque bezel hides the corners in
	# _draw_minimap; no CanvasItem shader participates in this path.
	World.island_changed.connect(_refresh_minimap_after_travel)
	_minimap.draw.connect(_draw_minimap)
	_minimap.gui_input.connect(func (ev: InputEvent) -> void:
		if (ev is InputEventScreenTouch and not (ev as InputEventScreenTouch).pressed) or (ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
			_open_map()
			_minimap.accept_event()
	)
	add_child(_minimap)

func _refresh_minimap_after_travel(_id: StringName) -> void:
	# The island signal fires before HuntHud creates the replacement map ImageTexture.
	# In WebGL the texture upload can invalidate this CanvasItem material, so the mask is
	# rebuilt in _ensure_map_texture after the new texture exists, not one frame early.
	_map_tex = null
	_map_island = &""
	_minimap.queue_redraw()

func _hex(glyph: String, size_px: float = HEX, caption: String = "") -> HexButton:
	var h := HexButton.new(size_px)
	h.glyph = glyph
	h.caption = caption
	add_child(h)
	return h

func _build_menu_row() -> void:
	_menu_hex = _hex("≡", HEX, "MENU")
	_menu_hex.pressed.connect(func () -> void: _toggle_sheet(&"menu"))
	_pets_hex = _hex("🦖", HEX, "ANIMALS")
	_pets_hex.pressed.connect(_open_animals)
	_build_hex = _hex("⌂", HEX, "BUILD")
	_build_hex.pressed.connect(func () -> void: _toggle_sheet(&"build"))
	_skills_hex = _hex("★", HEX, "SKILLS")
	_skills_hex.pressed.connect(_toggle_skills)
	for i in 2:
		var fh := HexButton.new(HEX)
		fh.glyph = "🍖"
		fh.caption = "EAT"
		fh.color_icon = true
		fh.visible = false
		var qi := i
		fh.pressed.connect(func () -> void: _eat_quick(qi))
		add_child(fh)
		_food_hexes.append(fh)
	_inspect_hex = _hex("🔍", 56.0, "DEBUG")
	_inspect_hex.pressed.connect(_toggle_debug)
	_inspect_hex.selected = Game.debug_overlay
	_inspect_hex.visible = Game.debug_overlay

## Quick-food hexes (bottom-left, above the menu row): icon + count of the two quick slots set
## in the bag; tap eats one. Hidden while a slot is empty or its food is gone.
func _refresh_food_hexes() -> void:
	if player == null or player.inventory == null:
		return
	for i in _food_hexes.size():
		var h := _food_hexes[i]
		var fid := str(player.inventory.quick_food[i]) if player.inventory.quick_food.size() > i else ""
		var n := player.inventory.count_of(StringName(fid)) if fid != "" else 0
		var show := fid != "" and n > 0
		if h.visible != show:
			h.visible = show
		if show:
			var tex := ItemIcons.texture(StringName(fid))
			if h.icon != tex or h.bottom_text != str(n):
				h.icon = tex
				h.color_icon = tex != null
				h.glyph = "" if tex else "🍖"
				h.bottom_text = "×%d" % n
				h.queue_redraw()

func _eat_quick(i: int) -> void:
	if player == null:
		return
	var fid := str(player.inventory.quick_food[i])
	var idx := player.inventory.find_first(StringName(fid)) if fid != "" else -1
	if idx >= 0:
		if not player.begin_eat_slot(idx):
			player.notice("Can't eat right now.")

## Debug items: perf line top-left, creature state labels, HP numbers on plates, path lines.
func _toggle_debug() -> void:
	Game.debug_overlay = not Game.debug_overlay
	_inspect_hex.selected = Game.debug_overlay
	_inspect_hex.visible = Game.debug_overlay
	_inspect_hex.queue_redraw()
	print("[hud] debug %s" % ("on" if Game.debug_overlay else "off"))


func _open_animals() -> void:
	_close_sheet()
	if _animal_screen == null:
		_animal_screen = AnimalScreen.new()
		_animal_screen.name = "AnimalScreen"
		var layer := CanvasLayer.new()
		layer.name = "AnimalLayer"
		layer.layer = 96
		add_child(layer)
		layer.add_child(_animal_screen)
	_animal_screen.open(player)

func _build_combat() -> void:
	_end_btn = Button.new()
	_end_btn.text = "End Combat"
	_end_btn.custom_minimum_size = Vector2(184, 64)
	_end_btn.add_theme_font_size_override("font_size", 16)
	_end_btn.add_theme_color_override("font_color", UiTokens.ACTION)
	var sb := UiTokens.button_style(false)
	_end_btn.add_theme_stylebox_override("normal", sb)
	_end_btn.add_theme_stylebox_override("hover", sb)
	_end_btn.add_theme_stylebox_override("pressed", UiTokens.button_style(true))
	_end_btn.pressed.connect(func () -> void:
		if player and player.hunt:
			player.hunt.stop()
	)
	_end_btn.visible = false
	add_child(_end_btn)
	var specs := [["🕸", "net", "NET"], ["💥", "tackle", "TACKLE"], ["🦵", "kick", "KICK"], ["↯", "roll", "ROLL"]]
	for s in specs:
		var h := HexButton.new(72.0)
		h.glyph = s[0]
		h.caption = s[2]
		h.visible = false
		h.pressed.connect(_on_skill.bind(StringName(s[1])))
		add_child(h)
		_skill_hexes.append(h)
	_auto_hex = HexButton.new(64.0)
	_auto_hex.glyph = "Auto"
	_auto_hex.visible = false
	_auto_hex.pressed.connect(func () -> void:
		if player and player.hunt:
			player.hunt.auto = not player.hunt.auto
			_auto_hex.selected = player.hunt.auto
			_auto_hex.queue_redraw()
	)
	add_child(_auto_hex)
	for spec in [["attack", "🦖", "SIC"], ["heel", "↩", "HEEL"], ["guard", "🛡", "GUARD"]]:
		var wh := HexButton.new(64.0)
		wh.glyph = spec[1]
		wh.caption = spec[2]
		wh.visible = false
		var cmd := StringName(str(spec[0]))
		wh.pressed.connect(func () -> void:
			if player:
				player.pet_order(cmd)
		)
		add_child(wh)
		_whistle_hexes.append(wh)
	_feed_hex = HexButton.new(64.0)
	_feed_hex.glyph = "FEED"
	_feed_hex.caption = "FEED"
	_feed_hex.visible = false
	_feed_hex.pressed.connect(func () -> void:
		if player and player.hunt and player.hunt.target and FieldTame.can_attempt(player.hunt.target):
			player._begin_field_tame(player.hunt.target)
	)
	add_child(_feed_hex)
	_stance_label = Label.new()
	_stance_label.text = "Attack Stance ◎"
	_stance_label.add_theme_font_size_override("font_size", 16)
	_stance_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_stance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stance_label.visible = false
	add_child(_stance_label)
	_chase_hex = HexButton.new(HEX)
	_chase_hex.glyph = "🏃"
	_chase_hex.caption = "CHASE"
	_chase_hex.visible = false
	_chase_hex.pressed.connect(func () -> void:
		if player and player.hunt:
			player.hunt.hold = not player.hunt.hold
			_chase_hex.selected = player.hunt.hold
			_chase_hex.glyph = "✋" if player.hunt.hold else "🏃"
			_chase_hex.caption = "HOLD" if player.hunt.hold else "CHASE"
			_chase_hex.queue_redraw()
	)
	add_child(_chase_hex)

## Deliberate death card. Shown while player.dead; the survivor stays on the ground until respawn.
func _build_death() -> void:
	_death_panel = Control.new()
	_death_panel.name = "Death"
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_panel.visible = false
	_death_panel.draw.connect(_draw_death)
	var death_layer := CanvasLayer.new()
	death_layer.name = "DeathLayer"
	death_layer.layer = 100
	add_child(death_layer)
	death_layer.add_child(_death_panel)
	_death_card = Panel.new()
	_death_card.name = "DeathCard"
	_death_card.custom_minimum_size = Vector2(280, 280)
	_death_card.add_theme_stylebox_override("panel", UiTokens.panel_style(1.0))
	_death_panel.add_child(_death_card)
	_death_title = Label.new()
	_death_title.name = "DeathTitle"
	_death_title.text = "YOU DIED"
	_death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_title.add_theme_color_override("font_color", UiTokens.DANGER)
	_death_card.add_child(_death_title)
	_death_cause = Label.new()
	_death_cause.name = "DeathCause"
	_death_cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_cause.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_cause.add_theme_color_override("font_color", UiTokens.TEXT)
	_death_card.add_child(_death_cause)
	_death_note = Label.new()
	_death_note.name = "DeathNote"
	_death_note.text = "Engaged dinosaurs retreat past their aggro ring. Your bag comes with you."
	_death_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_note.add_theme_color_override("font_color", UiTokens.META)
	_death_card.add_child(_death_note)
	_death_btn = Button.new()
	_death_btn.text = "Respawn at camp"
	_death_btn.custom_minimum_size = Vector2(260, 64)
	_death_btn.add_theme_color_override("font_color", UiTokens.ACTION)
	_death_btn.add_theme_stylebox_override("normal", UiTokens.button_style(true))
	_death_btn.add_theme_stylebox_override("hover", UiTokens.button_style(true))
	_death_btn.add_theme_stylebox_override("pressed", UiTokens.button_style(true))
	_death_btn.pressed.connect(func () -> void:
		if player:
			player.respawn()
	)
	_death_card.add_child(_death_btn)

func _tick_death(delta: float) -> void:
	var dead := player != null and player.dead
	_death_alpha = move_toward(_death_alpha, 1.0 if dead else 0.0, delta * (0.8 if dead else 4.0))
	var show := _death_alpha > 0.01
	if _death_panel.visible != show:
		_death_panel.visible = show
		if show:
			_close_sheet()
	if not show:
		return
	var r := get_viewport_rect().size
	_death_panel.position = Vector2.ZERO
	_death_panel.size = r
	var card_w := clampf(r.x - 32.0, 280.0, 520.0)
	var card_h := 300.0 if not UiTokens.is_phone(r) else 320.0
	_death_card.size = Vector2(card_w, card_h)
	_death_card.position = (r - _death_card.size) * 0.5
	var view_font := UiTokens.heading(r)
	_death_title.add_theme_font_size_override("font_size", view_font + (4 if not UiTokens.is_phone(r) else 0))
	_death_title.position = Vector2(16, 28)
	_death_title.size = Vector2(card_w - 32, 36)
	var cause := "Downed by the wilds."
	if player and player.downed_by != "":
		cause = "Downed by %s." % player.downed_by
	_death_cause.text = cause
	_death_cause.add_theme_font_size_override("font_size", UiTokens.body(r))
	_death_cause.position = Vector2(16, 84)
	_death_cause.size = Vector2(card_w - 32, 48)
	_death_note.add_theme_font_size_override("font_size", UiTokens.meta(r))
	_death_note.position = Vector2(16, 140)
	_death_note.size = Vector2(card_w - 32, 64)
	var btn_w := minf(260.0, card_w - 32.0)
	_death_btn.custom_minimum_size = Vector2(btn_w, 64)
	_death_btn.size = Vector2(btn_w, 64)
	_death_btn.position = Vector2((card_w - btn_w) * 0.5, card_h - 84.0)
	_death_btn.add_theme_font_size_override("font_size", UiTokens.body(r))
	_death_btn.visible = _death_alpha > 0.6
	_death_btn.modulate.a = clampf((_death_alpha - 0.6) / 0.4, 0.0, 1.0)
	_death_panel.modulate.a = _death_alpha
	_death_panel.queue_redraw()

func _draw_death() -> void:
	var r := _death_panel.size
	if r.x < 2.0:
		r = get_viewport_rect().size
	_death_panel.draw_rect(Rect2(Vector2.ZERO, r), Color(0.02, 0.025, 0.03, 0.88))

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

func _build_place_hexes() -> void:
	_done_hex = HexButton.new(64.0)
	_done_hex.glyph = "✓"
	_done_hex.caption = "DONE"
	_done_hex.accent = UiTokens.TEAL
	_done_hex.visible = false
	_done_hex.pressed.connect(func () -> void:
		if player and player.placer:
			player.placer.end_layout()
			player.notice("Layout saved.")
	)
	add_child(_done_hex)
	var specs := [["↻", "rotate", "ROTATE", "R"], ["✓", "confirm", "PLACE", "Enter"], ["✕", "cancel", "CANCEL", "Esc"]]
	for sp in specs:
		var h := HexButton.new(64.0)
		h.glyph = sp[0]
		h.caption = sp[2]
		h.top_text = sp[3]
		if sp[1] == "confirm":
			h.accent = UiTokens.TEAL
		h.visible = false
		var id: String = sp[1]
		h.pressed.connect(func () -> void:
			if player == null or player.placer == null:
				return
			match id:
				"rotate": player.placer.rotate_clockwise()
				"confirm": player.placer.confirm(player)
				"cancel": player.placer.cancel()
		)
		add_child(h)
		_place_hexes.append(h)

## A creature bit the survivor: Pokémon Bite/Crunch style jaws snap shut over her chest and the
## damage floats up in red. Heavy attacks get the bigger, redder Crunch.
func bite_on_player(amount: float, heavy: bool) -> void:
	_events.add_bite(amount, heavy)

func _draw_bites(cam: Camera3D) -> void:
	if cam == null or player == null:
		return
	var chest := cam.unproject_position(player.get_global_transform_interpolated().origin + Vector3(0, 0.95, 0))
	for f in _events.player_floats:
		var k: float = f["t"]
		var a := 1.0 - smoothstep(0.55, 0.95, k)
		var txt := "-%d" % int(round(float(f["n"])))
		var fs := 22
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var p := chest + Vector2(float(f["x"]) - w * 0.5, -30.0 - k * 46.0)
		draw_string(_font, p + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8 * a))
		draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.25, 0.2, a))
	for b in _events.bites:
		var k: float = b["t"]
		var heavy: bool = b["heavy"]
		var n := 7 if heavy else 5
		var s := 44.0 if heavy else 32.0
		var gap := lerpf(s * 1.3, 3.0, smoothstep(0.0, 0.14, k))  # jaws snap shut
		var a := 1.0 - smoothstep(0.3, 0.5, k)
		var c := chest + Vector2(float(b["x"]), 0.0)
		var tooth := Color(0.98, 0.97, 0.9, a)
		var gum := Color(0.75, 0.12, 0.12, a) if heavy else Color(0.35, 0.08, 0.1, a)
		var edge := Color(0.1, 0.05, 0.05, a)
		for side_v in [-1.0, 1.0]:
			var side: float = float(side_v)
			var base_y: float = c.y + side * gap
			var w := s * 0.62 * float(n)
			draw_rect(Rect2(c.x - w * 0.5, base_y - (s * 0.28 if side < 0.0 else 0.0), w, s * 0.28), gum)
			for i in n:
				var x := c.x + (float(i) - float(n - 1) * 0.5) * s * 0.62
				var h := s * (0.62 if i % 2 == 0 else 0.48)
				var tri := PackedVector2Array([Vector2(x - s * 0.3, base_y), Vector2(x + s * 0.3, base_y), Vector2(x, base_y + side * h)])
				draw_colored_polygon(tri, tooth)
				var outline := tri.duplicate()
				outline.append(tri[0])
				draw_polyline(outline, edge, 1.5, true)
		if k < 0.2 and heavy:
			draw_rect(Rect2(0, 0, get_viewport_rect().size.x, get_viewport_rect().size.y), Color(0.9, 0.1, 0.1, 0.18 * (1.0 - k / 0.2)))

func notice(text: String) -> void:
	_events.add_notice(text)

func toast(id: StringName, n: int) -> void:
	print("[ui] toast %s +%d" % [id, n])
	_events.add_toast(id, n)

func _refresh_context(delta: float) -> void:
	_ctx_timer -= delta
	if _ctx_timer > 0.0:
		return
	_ctx_timer = 0.3
	var actions: Array = player.context_actions() if player.has_method("context_actions") else []
	if _in_combat:
		actions = []  # the skill cluster owns the bottom-right during a hunt
	var ids: Array = []
	for a in actions:
		ids.append([a["id"], a.get("uses", "")])
	if ids == _ctx_ids:
		return
	_ctx_ids = ids
	for h in _ctx_hexes:
		h.queue_free()
	_ctx_hexes.clear()
	var r := get_viewport_rect().size
	var inset := _safe_insets()
	var x := r.x - 16.0 - inset.x - 74.0 - 60.0
	for a in actions:
		var h := HexButton.new(70.0)
		h.glyph = str(a.get("glyph", ""))
		h.caption = str(a["label"]).to_upper()
		h.bottom_text = str(a.get("uses", ""))
		if h.glyph == "":
			h.glyph = h.caption
			h.caption = ""
		var id := str(a["id"])
		h.pressed.connect(func () -> void: player.context_action(id))
		add_child(h)
		if id == "claim":
			# Land claim lives by the minimap (it is about the map, not the fight).
			h.position = Vector2(_minimap.position.x + MAP_PX - 70.0, _minimap.position.y + MAP_PX + 44.0)
		else:
			h.position = Vector2(x, r.y - 70.0 - 26.0 - inset.y)
			x -= 78.0
		_ctx_hexes.append(h)

func _refresh_place_hexes() -> void:
	var placing := player.placer != null and player.placer.placing != &""
	var layout := player.placer != null and player.placer.layout_mode
	if _done_hex.visible != layout:
		_done_hex.visible = layout
	if layout:
		var r := get_viewport_rect().size
		_done_hex.position = Vector2(r.x * 0.5 - 36.0, r.y - 72.0 - 30.0)
	for h in _place_hexes:
		h.visible = placing and not layout  # layout mode is drag and drop, no confirm hexes
	if not placing:
		return
	var cam := get_viewport().get_camera_3d()
	var ghost: Node3D = player.placer.get("_ghost_root")
	if cam == null or ghost == null:
		return
	var base := cam.unproject_position(ghost.global_position) + Vector2(0, 40)
	var offs := [Vector2(-105, 0), Vector2(-22, 28), Vector2(60, 0)]
	for i in _place_hexes.size():
		_place_hexes[i].position = base + offs[i]

func _load_level_data() -> void:
	for pair in [["res://data/skills/titles.json", "t"], ["res://data/skills/pioneer_levels.json", "g"]]:
		if not FileAccess.file_exists(pair[0]):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pair[0]))
		if parsed is Dictionary:
			if pair[1] == "t":
				_titles = parsed
			else:
				_level_gains = parsed

## Reference: a gold text stack at the top-left for ~6 s on level-up.
func _on_level_up(level: int) -> void:
	_levelup_lines.clear()
	_levelup_lines.append(["Lv. %d" % level, 40, Color(1.0, 0.85, 0.35)])
	_levelup_lines.append(["👁 %d" % World.pioneer_xp, 18, Color.WHITE])
	_levelup_lines.append(["◎ %d" % World.t_stones, 18, Color.WHITE])
	var sp := Data.survival_nodes.size() - Data.survival_unlocked.size() if Data.get("survival_nodes") != null else 0
	_levelup_lines.append(["Available Skill Points: %d" % maxi(0, sp), 18, Color.WHITE])
	var title := str(_titles.get(str(level), ""))
	if title != "":
		_levelup_lines.append(["Title %s acquired." % title, 18, Color(1.0, 0.85, 0.35)])
		print("[world] pioneer level %d title=\"%s\"" % [level, title])
	else:
		print("[world] pioneer level %d" % level)
	var per: Dictionary = _level_gains.get("per_level", {})
	if player and player.vitals:
		player.vitals.max_health += float(per.get("max_health", 0))
		player.vitals.max_energy += float(per.get("max_energy", 0))
	var stats: Array = _level_gains.get("display_stats", [])
	var gain := int(_level_gains.get("display_gain", 5))
	var bonus := int(_level_gains.get("bonus_stat_gain", 6))
	for i in stats.size():
		var g := bonus if (i == level % maxi(1, stats.size())) else gain
		_levelup_lines.append(["%s + %d" % [stats[i], g], 18, Color(1.0, 0.85, 0.35)])
	_levelup_t = 0.0
	if player:
		player.toast(&"level", level)

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
			_sheet_btn(box, "Debug info: %s" % ("ON" if Game.debug_overlay else "OFF"), func () -> void: _toggle_debug(); _close_sheet(); _toggle_sheet(&"menu"))
		&"pets":
			title.text = "ANIMALS  %d owned" % player.bonded.size()
			if player.bonded.is_empty():
				var l := Label.new()
				l.text = "No bonded animals yet. Knock one down and feed it."
				box.add_child(l)
			var out_now := player.live_pets().size()
			title.text = "ANIMALS  %d owned   ·   equipped %d / %d" % [player.bonded.size(), out_now, Player.MAX_PETS_OUT]
			for i in player.bonded.size():
				var rec: PetRecord = player.bonded[i]
				var idx := i
				if rec.respawning():
					# Down after dying: circular cooldown ring instead of a Summon button.
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 10)
					row.add_child(RespawnRing.new(rec, func () -> void: _refresh_sheet()))
					var down := Button.new()
					down.text = "%s  Lv. %d %s  DOWN" % [str(rec.species).capitalize(), rec.level, rec.grade]
					down.disabled = true
					down.custom_minimum_size = Vector2(240, 60)
					down.add_theme_font_size_override("font_size", 18)
					row.add_child(down)
					box.add_child(row)
					continue
				var is_out := false
				for p in player.live_pets():
					if p.pet_record == rec:
						is_out = true
				_sheet_btn(box, "%s  %s  Lv. %d %s  hp %.0f  xp %.0f/%.0f" % ["Dismiss" if is_out else "Summon", str(rec.species).capitalize(), rec.level, rec.grade, rec.hp, rec.xp, PetRecord.xp_to_next(rec.level)], func () -> void: _close_sheet(); player.summon_pet(idx); _toggle_sheet(&"pets"))
		&"build":
			title.text = "Build"
			_sheet_btn(box, "Move buildings (layout mode)", func () -> void: _close_sheet(); if player.placer: player.placer.begin_layout())
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

## Rebuild the open sheet in place (e.g. a pet finished respawning and Summon is back).
func _refresh_sheet() -> void:
	if _sheet == null:
		return
	var kind := _sheet_kind
	_close_sheet()
	_toggle_sheet(kind)

func _close_sheet() -> void:
	if _sheet:
		_sheet.queue_free()
		_sheet = null
	_sheet_kind = &""

var _skills_sheet: SkillsSheet

func _toggle_skills(tree: String = "") -> void:
	if player == null or player.skills == null:
		return
	if _skills_sheet == null:
		_skills_sheet = SkillsSheet.new()
		_skills_sheet.name = "SkillsSheet"
		add_child(_skills_sheet)
	if _skills_sheet.visible and tree == "":
		_skills_sheet.close()
	else:
		_skills_sheet.open(player.skills, tree)

var _map_screen: MapScreen

func map_texture() -> ImageTexture:
	_ensure_map_texture()
	return _map_tex

## The big map (minimap tap / map key). Travel routes moved onto it from the old text panel.
func _open_map() -> void:
	if _map_screen == null:
		_map_screen = MapScreen.new()
		_map_screen.name = "MapScreen"
		_map_screen.hud = self
		_map_screen.player = player
		var map_layer := CanvasLayer.new()
		map_layer.name = "MapLayer"
		map_layer.layer = 96
		add_child(map_layer)
		map_layer.add_child(_map_screen)
	if _map_screen.is_open():
		_map_screen.close()
	else:
		_close_sheet()
		_map_screen.open()

func open_map() -> void:
	_open_map()

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if player == null:
		return
	_tick_death(delta)
	var hunting := player.hunt != null and player.hunt.target != null and is_instance_valid(player.hunt.target)
	if hunting != _in_combat:
		_in_combat = hunting
		_end_btn.visible = hunting
		for h in _skill_hexes:
			h.visible = hunting
		_auto_hex.visible = hunting
		_stance_label.visible = hunting
		_chase_hex.visible = hunting
		if not hunting:
			_feed_hex.visible = false
		if hunting:
			var t := player.hunt.target
			print("[hud] target %s lv=%d hp=%.0f/%.0f" % [t.def.id, t.level, t.health.hp, t.health.max_hp])
	if hunting and player.hunt.target != _last_target:
		_last_target = player.hunt.target
	_combat_alpha = move_toward(_combat_alpha, 1.0 if hunting else 0.0, delta * 5.0)
	if hunting:
		var feedable: bool = FieldTame.can_attempt(player.hunt.target)
		if _feed_hex.visible != feedable:
			_feed_hex.visible = feedable
			_feed_hex.queue_redraw()
		_skill_hexes[0].disabled = not (player.hunt.target.capturable() and player.hunt._best_net_ok())
		_skill_hexes[1].disabled = player.hunt._tackle_cd > 0.0
		_skill_hexes[2].disabled = player.hunt._kick_cd > 0.0
		for h in _skill_hexes:
			h.queue_redraw()
	_refresh_context(delta)
	_refresh_place_hexes()
	_refresh_food_hexes()
	var pet_out := not player.live_pets().is_empty()
	for i in _whistle_hexes.size():
		var wh := _whistle_hexes[i]
		if wh.visible != pet_out:
			wh.visible = pet_out
		if pet_out and player.summoned_pet.brain:
			var m: StringName = player.summoned_pet.brain.get("mode") if player.summoned_pet.brain.get("mode") != null else &"guard"
			var want := (i == 0 and m == &"attack") or (i == 1 and m == &"heel") or (i == 2 and m == &"guard")
			if wh.selected != want:
				wh.selected = want
				wh.queue_redraw()
	if _levelup_t >= 0.0:
		_levelup_t += delta
		if _levelup_t > 6.5:
			_levelup_t = -1.0
	_events.tick(delta)
	_minimap.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if player == null or player.dead:
		return
	var r := get_viewport_rect().size
	var v := player.vitals
	if player.placer and player.placer.placing != &"":
		draw_rect(Rect2(Vector2.ZERO, r), Color(0.02, 0.03, 0.04, 0.28))
	var inset := _safe_insets()
	var x := 16.0 + inset.w
	var y := 12.0 + inset.z
	var phone := UiTokens.is_phone(r)
	var map_left := _minimap.position.x
	# Desktop: 300 px panel, 16 px HP/energy bars with body-size numbers (the audit called the
	# old 176 px / 12 px block "tiny desktop typography"). Phone keeps the compact block.
	var panel_w := 300.0 if not phone else maxf(148.0, map_left - x - 8.0)
	var bar_w := 232.0 if not phone else maxf(88.0, panel_w - 54.0)
	var big := 16.0 if not phone else 12.0
	var small := 10.0 if not phone else 8.0
	var gap := 6.0 if not phone else 6.0
	var num_px := UiTokens.body(r) - 1 if not phone else 12
	var bar_px := UiTokens.meta(r) if not phone else 12
	var panel_h := big * 2.0 + small + gap * 2.0 + 36.0
	draw_rect(Rect2(x - 8.0, y - 6.0, panel_w, panel_h), UiTokens.INK)
	var lvl_r := 18.0 if not phone else 16.0
	draw_circle(Vector2(x + lvl_r, y + lvl_r), lvl_r, Color(0.08, 0.09, 0.11, 0.95))
	draw_string(_font, Vector2(x, y + lvl_r + num_px * 0.36), str(World.pioneer_level), HORIZONTAL_ALIGNMENT_CENTER, lvl_r * 2.0, num_px, Color.WHITE)
	x += lvl_r * 2.0 + 8.0
	var yy := y
	_bar(Vector2(x, yy), Vector2(bar_w, big), v.health / maxf(1.0, v.effective_max_health()), Color(0.78, 0.13, 0.13), "", "%.0f / %.0f" % [v.health, v.effective_max_health()], num_px)
	yy += big + gap
	_bar(Vector2(x, yy), Vector2(bar_w, big), v.energy / maxf(1.0, v.max_energy), Color(0.20, 0.45, 0.80), "", "%.0f / %.0f" % [v.energy, v.max_energy], num_px)
	yy += big + gap
	var strain: float = clampf(v.fatigue / maxf(1.0, v.max_fatigue), 0.0, 1.0)
	var face_pos := Vector2(x + 11.0, yy + 10.0)
	_draw_exhaustion_face(face_pos, strain)
	var face_label := "RESTED" if strain < 0.25 else ("TIRED" if strain < 0.5 else ("WEARY" if strain < 0.75 else "EXHAUSTED"))
	var face_col := Color(0.42, 0.78, 0.53).lerp(Color(0.96, 0.42, 0.36), strain)
	draw_string(_font, Vector2(x + 27.0, yy + 14.0), face_label, HORIZONTAL_ALIGNMENT_LEFT, bar_w - 30.0, bar_px, face_col)
	yy += 22.0
	_bar(Vector2(x, yy), Vector2(bar_w, small), strain, face_col, "", "%d%%" % int(strain * 100.0), bar_px)
	# status badges live under the minimap (right side), left of the Claim hex
	var mp0 := _minimap.position
	var sx := mp0.x
	var sy := mp0.y + MAP_PX + 50.0
	if player.statuses:
		for inst in player.statuses.instances():
			draw_rect(Rect2(sx, sy, 26, 26), Color(0.1, 0.1, 0.12, 0.85))
			draw_string(_font, Vector2(sx + 4, sy + 19), str(inst.id).left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.75, 0.45))
			draw_string(_font, Vector2(sx, sy + 40), "%.0f" % inst.time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTokens.META)
			sx += 30
	var mp := _minimap.position
	var top := "Home" if World.is_home() else ("Survivable %d min" % int(ceil(World.remaining_lifetime / 60.0)))
	if World.island_id == &"":
		top = "Lab"
	var meta_px := UiTokens.meta(r)
	draw_string(_font, Vector2(mp.x, mp.y - 16.0), UiTokens.ellipsis(_font, top, MAP_PX, meta_px), HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, meta_px, Color.WHITE)
	var tile := BuildGrid.tile_of(player.global_position)
	draw_string(_font, Vector2(mp.x, mp.y + MAP_PX + 16), "X %d  Y %d" % [tile.x, tile.y], HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, meta_px, UiTokens.META)
	draw_string(_font, Vector2(mp.x, mp.y + MAP_PX + 32), "%s  %s" % [Game.clock_label(), Game.phase_name()], HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, meta_px, UiTokens.META)
	_draw_quest(r, mp)
	# --- XP bar along the bottom
	# One bar: the pioneer level, which every skill XP grant also feeds.
	var prog := World.pioneer_progress() if World.has_method("pioneer_progress") else 0.0
	var char_lv := World.pioneer_level
	draw_rect(Rect2(0, r.y - 4, r.x, 4), Color(0.05, 0.05, 0.07, 0.9))
	draw_rect(Rect2(0, r.y - 4, r.x * prog, 4), Color(0.90, 0.68, 0.12))
	var lv := "Lv. %d  %.1f%%" % [char_lv, prog * 100.0]
	var lw := _font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
	var lv_pos := Vector2(r.x - lw - 16.0 - inset.x, r.y - HEX - 22.0) if phone else Vector2(r.x * 0.5 - lw * 0.5, r.y - 7.0)
	draw_string(_font, lv_pos, lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# --- name under the survivor
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.unproject_position(player.get_global_transform_interpolated().origin - Vector3(0, 0.05, 0))
		var name := player.display_name() if player.has_method("display_name") else "Survivor"
		var nw := _font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
		draw_string(_font, Vector2(p.x - nw * 0.5 + 1, p.y + 21), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.7))
		draw_string(_font, Vector2(p.x - nw * 0.5, p.y + 20), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.95, 0.95))
	# --- label pills on buildings and nodes within 30 m (reference: base building)
	_draw_pills(cam)
	_draw_bites(cam)
	# --- level-up stack (gold, top-left under the bars)
	if _levelup_t >= 0.0:
		var la := 1.0 - smoothstep(5.5, 6.5, _levelup_t)
		var ly := 160.0
		for line in _levelup_lines:
			var col: Color = line[2]
			col.a *= la
			draw_string(_font, Vector2(31, ly + 1), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1]), Color(0, 0, 0, 0.6 * la))
			draw_string(_font, Vector2(30, ly), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1]), col)
			ly += float(line[1]) + 8.0
	# --- pickup toasts near the top-centre, rising and fading
	for i in _events.toasts.size():
		var t: Dictionary = _events.toasts[i]
		var k: float = t["t"]
		var alpha := 1.0 - smoothstep(0.7, 1.3, k)
		var ty := 120.0 + float(i) * 30.0 - k * 35.0
		var def := Data.item(t["id"])
		var label := "+%d  %s" % [int(t["n"]), def.display_name if def else str(t["id"])]
		var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		draw_rect(Rect2(r.x * 0.5 - tw * 0.5 - 10, ty - 20, tw + 20, 28), Color(0.05, 0.06, 0.08, 0.8 * alpha))
		draw_string(_font, Vector2(r.x * 0.5 - tw * 0.5, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, alpha))
	if player.placer and player.placer.layout_mode:
		var hint := "Layout mode: drag a building to move it · tap one to rotate · blue = ok, red = blocked · DONE saves" if player.placer.moving == null else "Release to drop (red snaps it back)"
		var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
		draw_rect(Rect2(r.x * 0.5 - hw * 0.5 - 12, 150, hw + 24, 28), Color(0.05, 0.15, 0.3, 0.85))
		draw_string(_font, Vector2(r.x * 0.5 - hw * 0.5, 170), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.92, 1.0))
	# --- notices (refusals, hints) under the toasts, centre-top
	for i in _events.notices.size():
		var n: Dictionary = _events.notices[i]
		var k: float = n["t"]
		var alpha := 1.0 - smoothstep(2.4, 3.2, k)
		var ny := 190.0 + float(i) * 30.0
		var txt: String = n["text"]
		var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
		draw_rect(Rect2(r.x * 0.5 - tw * 0.5 - 12, ny - 20, tw + 24, 30), Color(0.35, 0.08, 0.06, 0.85 * alpha))
		draw_string(_font, Vector2(r.x * 0.5 - tw * 0.5, ny + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.8, alpha))
	# --- combat layer
	if _combat_alpha > 0.01:
		var a := _combat_alpha
		draw_rect(Rect2(0, 0, r.x, 6), Color(0.85, 0.1, 0.1, 0.75 * a))
		draw_rect(Rect2(0, r.y - 6, r.x, 6), Color(0.85, 0.1, 0.1, 0.75 * a))
	# --- target plate: the current hunt target, else the last creature attacked while it lives
	var plate_t: Creature = player.hunt.target if (player.hunt and player.hunt.target and is_instance_valid(player.hunt.target)) else null
	if plate_t == null and _last_target and is_instance_valid(_last_target) and not _last_target.health.dead and player.global_position.distance_to(_last_target.global_position) < 40.0:
		plate_t = _last_target
	if plate_t:
		_draw_target_plate(plate_t, maxf(_combat_alpha, 0.85))

func _draw_target_plate(t: Creature, a: float) -> void:
	var r := get_viewport_rect().size
	if true:
		if t and is_instance_valid(t):
			var pw := minf(520.0, r.x - 24.0)
			var px := r.x * 0.5 - pw * 0.5
			var py := 14.0 + _safe_insets().z
			var nm := ("%s  [%s IV]" % [str(t.def.id).capitalize(), t.genetics.overall_tier() if t.genetics else &"?"]) if t.is_pet else str(t.def.id).capitalize()
			var name_px := UiTokens.heading(r)
			nm = UiTokens.ellipsis(_font, nm, pw - 150.0, name_px)
			draw_string(_font, Vector2(px + 12, py + 28), nm, HORIZONTAL_ALIGNMENT_LEFT, pw - 120.0, name_px, Color(1, 1, 1, a))
			var nmw := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
			draw_string(_font, Vector2(px + 18 + nmw, py + 28), "Lv. %d" % t.level, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px, UiTokens.DANGER)
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

func _draw_quest(r: Vector2, mp: Vector2) -> void:
	var phone := UiTokens.is_phone(r)
	var w := MAP_PX if phone else 240.0  # wide enough for "Home Grassland" at heading size
	var origin := Vector2(mp.x, mp.y + MAP_PX + 52.0) if phone else Vector2(mp.x - w - 12.0, mp.y)
	if origin.x < 8.0:
		origin.x = 8.0
	draw_rect(Rect2(origin, Vector2(w, 72.0)), UiTokens.INK)
	draw_rect(Rect2(origin, Vector2(3.0, 72.0)), UiTokens.TEAL)
	var step := Objectives.current(player)
	var head := UiTokens.heading(r) - 4
	var meta_px := UiTokens.meta(r)
	if step.is_empty():
		var island := str(World.island_id).replace("_", " ").capitalize()
		if island == "":
			island = "Uncharted"
		draw_string(_font, origin + Vector2(12, 16), "NOW", HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, meta_px, UiTokens.META)
		draw_string(_font, origin + Vector2(12, 38), UiTokens.ellipsis(_font, island, w - 24.0, head), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, head, UiTokens.TEXT)
		draw_string(_font, origin + Vector2(12, 58), "Survive, then return", HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, meta_px, UiTokens.TEXT)
		return
	draw_string(_font, origin + Vector2(12, 16), "ORDERS %d/%d" % [int(step["index"]) + 1, int(step["count"])], HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, meta_px, UiTokens.META)
	draw_string(_font, origin + Vector2(12, 38), UiTokens.ellipsis(_font, str(step["title"]), w - 24.0, head), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, head, UiTokens.TEXT)
	draw_string(_font, origin + Vector2(12, 58), UiTokens.ellipsis(_font, str(step["hint"]), w - 60.0, meta_px), HORIZONTAL_ALIGNMENT_LEFT, w - 60.0, meta_px, UiTokens.META)
	var pw := _font.get_string_size(str(step["progress"]), HORIZONTAL_ALIGNMENT_LEFT, -1, meta_px).x
	draw_string(_font, origin + Vector2(w - pw - 12.0, 58), str(step["progress"]), HORIZONTAL_ALIGNMENT_LEFT, -1, meta_px, UiTokens.TEAL)
	# A thin fill along the card's left edge shows how close the order is to done.
	draw_rect(Rect2(origin, Vector2(3.0, 72.0 * float(step["frac"]))), UiTokens.TEAL)

## Four readable expressions: smile -> neutral -> frown -> deep frown.
## Geometry is drawn rather than relying on platform-specific emoji fonts.
func _draw_exhaustion_face(center: Vector2, strain: float) -> void:
	var tier := mini(3, int(strain * 4.0))
	var col := Color(0.42, 0.78, 0.53).lerp(Color(0.96, 0.42, 0.36), strain)
	draw_circle(center, 10.0, col)
	draw_arc(center, 10.0, 0.0, TAU, 18, Color(0.06, 0.08, 0.08), 1.4)
	for side in [-1.0, 1.0]:
		draw_circle(center + Vector2(side * 3.4, -2.0), 1.0, Color(0.08, 0.1, 0.1))
	var dark := Color(0.08, 0.1, 0.1)
	match tier:
		0:
			draw_arc(center + Vector2(0, -0.2), 5.5, 0.15, PI - 0.15, 12, dark, 1.6)
		1:
			draw_line(center + Vector2(-4.5, 4.0), center + Vector2(4.5, 4.0), dark, 1.6)
		2:
			draw_arc(center + Vector2(0, 7.0), 4.5, PI + 0.35, TAU - 0.35, 12, dark, 1.5)
		3:
			draw_arc(center + Vector2(0, 9.0), 5.5, PI + 0.15, TAU - 0.15, 12, dark, 1.6)

func _bar(pos: Vector2, size: Vector2, frac: float, col: Color, glyph: String, text: String, text_px: int = 12) -> void:
	draw_rect(Rect2(pos, size), Color(0.08, 0.08, 0.1, 0.85))
	draw_rect(Rect2(pos, Vector2(size.x * clampf(frac, 0.0, 1.0), size.y)), col)
	draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.6), false, 1.0)
	if glyph != "":
		draw_string(_font, pos + Vector2(-14, size.y - 3), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if text != "":
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, text_px).x
		draw_string(_font, pos + Vector2(size.x - w - 6, size.y * 0.5 + text_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px, Color.WHITE)

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
	# Camera-up map: the iso camera looks along a 45° diagonal, so a north-up map made running
	# left read as south-west. Everything below is drawn rotated by the camera yaw around the
	# centre (so screen-up on the map is screen-up in the world); the frame clips the corners.
	var centre := Vector2(MAP_PX * 0.5, MAP_PX * 0.5)
	var cam := get_viewport().get_camera_3d()
	var cam_yaw := cam.global_rotation.y if cam else 0.0
	c.draw_set_transform(centre, cam_yaw, Vector2.ONE)
	if _map_tex and rt:
		var size_m: float = float(rt.get("_size"))
		var span_px := MAP_PX * 1.45  # covers the frame's corners once rotated
		var half := span_px * 0.5 * MAP_SCALE  # metres from centre to the drawn edge
		var pp := player.global_position
		var u0 := (pp.x - half + size_m * 0.5)
		var v0 := (pp.z - half + size_m * 0.5)
		c.draw_texture_rect_region(_map_tex, Rect2(Vector2(-span_px * 0.5, -span_px * 0.5), Vector2(span_px, span_px)), Rect2(u0, v0, half * 2.0, half * 2.0))
		var to_px := func (w: Vector3) -> Vector2:
			return Vector2((w.x - pp.x) / MAP_SCALE, (w.z - pp.z) / MAP_SCALE)
		var marker_r := MAP_PX * 0.5 - 5.0
		var camp: Vector3 = rt.get("_camp_pos")
		var harb: Vector3 = rt.get("_harbour_pos")
		var camp_q: Vector2 = to_px.call(camp)
		var harb_q: Vector2 = to_px.call(harb)
		if camp_q.length() <= marker_r:
			c.draw_circle(camp_q, 4.0, Color(1.0, 0.85, 0.3))
		if harb_q.length() <= marker_r:
			c.draw_circle(harb_q, 4.0, Color(0.7, 0.85, 1.0))
		if World.crater_discovered:
			var cr: Vector3 = rt.get("_crater_pos")
			var crater_q: Vector2 = to_px.call(cr)
			if crater_q.length() <= marker_r:
				c.draw_circle(crater_q, 4.0, Color(0.9, 0.4, 0.2))
		for n in get_tree().get_nodes_in_group("creatures"):
			var cr := n as Creature
			if cr == null or cr.health.dead:
				continue
			var q: Vector2 = to_px.call(cr.global_position)
			if q.length() > marker_r:
				continue
			c.draw_circle(q, 2.5, Color(0.4, 0.9, 0.4) if cr.is_pet else Color(0.95, 0.35, 0.3))
	# player arrow: facing relative to the camera, so it points up when running up the screen
	var yaw := player.visual.rotation.y if player.visual else 0.0
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	c.draw_colored_polygon(PackedVector2Array([fwd * 8.0, -fwd * 5.0 + side * 5.0, -fwd * 5.0 - side * 5.0]), Color(1, 1, 1))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_minimap_bezel(c)

func _draw_minimap_bezel(c: Control) -> void:
	# Shader clipping was lost after island travel in WebGL. Cover the four square corners
	# with opaque polygons instead; this is pure Canvas draw state and survives texture swaps.
	var centre := c.size * 0.5
	var radius := MAP_PX * 0.5 - 1.5
	var cover := Color(0.035, 0.04, 0.05, 1.0)
	var corners := [
		[Vector2(centre.x, 0), Vector2(c.size.x, 0), Vector2(c.size.x, centre.y), 0.0, -PI * 0.5],
		[Vector2(c.size.x, centre.y), Vector2(c.size.x, c.size.y), Vector2(centre.x, c.size.y), PI * 0.5, 0.0],
		[Vector2(centre.x, c.size.y), Vector2(0, c.size.y), Vector2(0, centre.y), PI, PI * 0.5],
		[Vector2(0, centre.y), Vector2(0, 0), Vector2(centre.x, 0), PI * 1.5, PI],
	]
	for spec in corners:
		var pts := PackedVector2Array([spec[0], spec[1], spec[2]])
		for i in 13:
			var angle: float = lerpf(float(spec[3]), float(spec[4]), float(i) / 12.0)
			pts.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		c.draw_colored_polygon(pts, cover)
	c.draw_circle(centre, radius, Color(1, 1, 1, 0.48), false, 2.0)

func _gather_radial_node() -> Node3D:
	var gr: Variant = player.get("_gather_radial")
	if gr and gr.has_method("is_open") and gr.is_open():
		return gr.node
	return null

const TOOL_ICON_ITEM := {"axe": "work_axe", "pick": "work_pick", "knife": "stone_knife", "none": "hands", "": "hands"}

## [[icon, have]] per distinct tool the node's yields need; corpses need a knife.
func _tools_for_node(n3: Node3D, grp: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var classes: Array = []
	if grp == "harvest" and n3 is HarvestNode:
		for o in (n3 as HarvestNode).options():
			classes.append(str(o.get("tool", "none")))
	elif grp == "corpse":
		classes.append("knife")
	else:
		return out
	for c in classes:
		if seen.has(c):
			continue
		seen[c] = true
		var have := true
		if c != "none" and c != "" and player and player.inventory:
			have = player.inventory.has_tool_class(StringName(c))
		out.append([ItemIcons.texture(StringName(str(TOOL_ICON_ITEM.get(c, "hands")))), have])
	return out

func _draw_pills(cam: Camera3D) -> void:
	if cam == null or player == null:
		return
	var radial_node: Node3D = null
	if player.has_node("GatherRadialLayer/GatherRadial"):
		var gr := player.get_node("GatherRadialLayer/GatherRadial")
		if gr.is_open():
			radial_node = gr.node
	var rows: Array = []
	var pp := player.global_position
	# A bonfire is in "placed_building", "craft_station" AND "bonfire", so without this the camp
	# drew three identical labels stacked on one object.
	var labelled := {}
	for grp in ["placed_building", "craft_station", "bonfire", "taming_pen", "cargo_warp", "harbour", "harvest"]:
		for n in get_tree().get_nodes_in_group(grp):
			var n3 := n as Node3D
			if n3 == null or not n3.visible or n3 == radial_node:
				continue
			if labelled.has(n3.get_instance_id()):
				continue
			labelled[n3.get_instance_id()] = true
			var d := pp.distance_to(n3.global_position)
			# World labels are interaction hints, not permanent billboards. Keep the scene
			# clean until the survivor is close or the object is actively inspected.
			var active := n3 == radial_node or n3 == player.gather_target
			if d > 8.0 and not active:
				continue
			rows.append([d, n3, grp])
	rows.sort_custom(func (a: Array, b: Array) -> bool: return a[0] < b[0])
	var pending: Array = []
	var shown := 0
	# Durango labels the thing you are about to use, not every trunk in the grove. Two of any
	# one kind is enough to read the area; the rest would be a wall of identical chips.
	var per_kind := {}
	for row in rows:
		if shown >= 12:
			break
		var n3: Node3D = row[1]
		var grp: String = row[2]
		var d: float = row[0]
		var name := ""
		var dot := Color(0.35, 0.85, 0.35)
		var timer := ""
		var top := 1.2
		if grp == "harvest":
			var hn := n3 as HarvestNode
			if hn == null:
				continue
			name = (hn.family if hn.family != "" else str(hn.node_id)).replace("_", " ").capitalize()
			top = hn.top_of_node()
			if hn.depleted:
				dot = Color(0.5, 0.5, 0.5)
				var left := hn.regen_left()
				if left > 0.0:
					timer = "%dm %02ds" % [int(left / 60.0), int(left) % 60]
			elif hn.required_tool_class != &"" and hn.required_tool_class != &"none" and not player.inventory.has_tool_class(hn.required_tool_class):
				dot = UiTokens.DANGER
		else:
			var kind: Variant = n3.get("kind")
			if kind == null:
				kind = n3.get("station_id")
			name = str(kind if kind != null else n3.name).replace("_", " ").capitalize()
			if grp == "cargo_warp":
				name = "Cargo Warp"
			elif grp == "harbour":
				name = "Harbour"
		var active_row := n3 == radial_node or n3 == player.gather_target
		var kind_n := int(per_kind.get(name, 0))
		if kind_n >= 2 and not active_row:
			continue
		per_kind[name] = kind_n + 1
		var priority := 100 if active_row else int(40.0 - d)
		if name == "Workbench" or name == "Cargo Warp":
			priority += 5
		var text := UiTokens.ellipsis(_font, name, UiTokens.LABEL_MAX_W - 28.0, 14)
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var working := (grp == "harvest" and (n3 == player.gather_target or (_gather_radial_node() == n3))) or (grp == "corpse" and n3 is Corpse and (n3 as Corpse).tapped_recently(4.0))
		var tools: Array = _tools_for_node(n3, grp) if working else []
		var w := minf(tw + 28.0, UiTokens.LABEL_MAX_W)
		var sp := cam.unproject_position(n3.global_position + Vector3(0, top + 0.35, 0))
		pending.append({
			"anchor": sp, "w": w, "h": 22.0, "priority": priority,
			"text": text, "dot": dot, "timer": timer, "tools": tools,
			"a": 1.0 if n3 == radial_node else 1.0 - smoothstep(5.5, 8.0, d),
		})
		shown += 1
	var view := get_viewport_rect().size
	for item in UiTokens.layout_labels(pending, view):
		var rect: Rect2 = item["rect"]
		var a: float = item["a"]
		var text: String = item["text"]
		var dot: Color = item["dot"]
		var bg := UiTokens.INK
		bg.a *= a
		draw_rect(rect, bg)
		draw_circle(Vector2(rect.position.x + 10.0, rect.position.y + 11.0), 4.0, Color(dot.r, dot.g, dot.b, a))
		draw_string(_font, Vector2(rect.position.x + 20.0, rect.position.y + 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 14, Color(1, 1, 1, a))
		var tools: Array = item["tools"]
		var ix := rect.position.x + rect.size.x - 6.0 - float(tools.size()) * 14.0
		for t in tools:
			var tex: Texture2D = t[0]
			var ok: bool = t[1]
			if tex:
				draw_texture_rect(tex, Rect2(ix, rect.position.y - 8.0, 12.0, 12.0), false, Color(1, 1, 1, a) if ok else Color(1.0, 0.45, 0.4, a))
			ix += 14.0
		var timer: String = item["timer"]
		if timer != "":
			var tt := UiTokens.ellipsis(_font, timer, 96.0, UiTokens.meta(view))
			var ttw := _font.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view)).x
			var trect := Rect2(rect.position.x, rect.position.y + rect.size.y + 2.0, ttw + 16.0, 18.0)
			var tbg := UiTokens.INK
			tbg.a *= a
			draw_rect(trect, tbg)
			draw_string(_font, Vector2(trect.position.x + 8.0, trect.position.y + 14.0), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), Color(1, 0.9, 0.6, a))
		shown += 1
