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
var _daynight: DayNightDial  ## docked to the minimap's bottom-left edge, under the desktop quest card
var _map_tex: ImageTexture
var _map_island: StringName = &""
var _map_span: int = 0
var _menu_hex: HexButton
var _pets_hex: HexButton
var _build_hex: HexButton
var _skills_hex: HexButton
var _inspect_hex: HexButton
var _fatigue_rect := Rect2() ## screen rect of the fatigue face and bar, recorded in _draw; a tap opens the panel
var _fatigue_panel: FatiguePanel
var _sheet: PanelContainer
var _sheet_rows: ScrollContainer  ## the open sheet's rows; on a short canvas they scroll under a pinned header
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
var _domain := DomainBanner.new()  ## spec 18: "<owner>'s Domain" on walking into claimed land
var _ctx_hexes: Array[HexButton] = []
var _ctx_ids: Array = []
var _ctx_timer: float = 0.0
var _place_hexes: Array[HexButton] = []
var _claim_panel: ClaimPanel  ## the CLAIM confirm (a second claim asks first; claim_panel.gd)
var _claim_tile := Vector2i.ZERO  ## where the survivor stood when it opened
var _done_hex: HexButton
var _levelup_lines: Array = []
var _levelup_title: String = ""  ## the title line and one stat summary: the landscape-phone banner
var _levelup_summary: String = ""
var _levelup_t: float = -1.0
## Screen rects of the blocks _draw paints (vitals, quest card, map text, status badges, level line,
## target plate, level-up banner), rebuilt every draw. Layout gates check them with the controls, so
## nothing mirrors this file's geometry.
var drawn_blocks: Dictionary = {}
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
const SKILL_HEX := 72.0  # the hunt skill hexes (net / tackle / kick / roll)
const CAPTION_H := 18.0  # room for the action word HexButton draws under a hex
const NAME_PX := 15  # the survivor's name under its feet

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # status-chip icons: 128 px SVGs at 20 px
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	if TouchControls:
		TouchControls.hud_mode = true
	_build_minimap()
	_daynight = DayNightDial.new()
	add_child(_daynight)
	_build_fatigue_panel()
	_build_menu_row()
	_watch_skills()
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
	if Game.shot_path.contains("fatiguepanel") and player:
		# Dev screenshot: a believable mix of causes, then the panel open under the gauge.
		player.vitals.gap_zone_level = 35
		player.vitals.gap_char_level = 25
		player.vitals.level_gap_mult = 1.6
		player.vitals.add_fatigue(6.0, &"climate_heat")
		player.vitals.add_fatigue(4.0, &"walk")
		player.vitals.add_fatigue(3.0, &"gather")
		player.vitals.add_fatigue(2.0, &"combat")
		get_tree().create_timer(0.5).timeout.connect(func () -> void:
			_fatigue_panel.player = player
			_fatigue_panel.toggle()
			queue_redraw())
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
	_watch_skills()

## Skill feedback (spec 25 §7, islands-and-loop-plan §3.3): the XP toast and the bigger level-up toast
## on skill_xp_gained/skill_leveled, and the SKILLS hex's pulse from SkillRules.affordable_now.
## Connected here (a Player may be bound before or after this HUD enters the tree) and never twice.
var _skills_watched: SkillState = null
## Seconds between affordability recounts: node_state walks twelve trees, no need to do it per frame.
const SKILL_PULSE_TICK := 0.25
## The glow is a soft ring around the hex, never a jump; this is where in its cycle it is (0..1).
const SKILL_PULSE_SECONDS := 1.6
var skills_pulse_on: bool = false
var _pulse_clock: float = 0.0
var _pulse_check: float = 0.0

func _watch_skills() -> void:
	if player == null or player.skills == null:
		return
	if _skills_watched == player.skills:
		return
	_skills_watched = player.skills
	var sk := _skills_watched
	if sk.has_signal("skill_xp_gained"):
		sk.skill_xp_gained.connect(func (tree: StringName, amount: float, level: int) -> void:
			_events.add_skill_xp(str(tree), amount, level)
		)
	if sk.has_signal("skill_leveled"):
		sk.skill_leveled.connect(func (tree: StringName, level: int) -> void:
			_events.add_skill_level(str(tree), level)
		)
	if sk.has_signal("skill_changed"):
		# A purchase or a refund moves the SP, and the pulse must answer on the same frame.
		sk.skill_changed.connect(func (_tree: StringName, _level: int) -> void:
			_pulse_check = 0.0
			_refresh_skill_pulse()
		)
	_refresh_skill_pulse()

## The hex pulses when at least one buyable node is affordable with the SP held, and stops when none
## is. Public so a lab can read the state the HUD draws.
func skills_pulsing() -> bool:
	return skills_pulse_on and player != null and not player.dead

func _refresh_skill_pulse() -> void:
	if player == null or player.skills == null:
		skills_pulse_on = false
		return
	skills_pulse_on = SkillRules.affordable_now(player.skills)

# ---------------------------------------------------------------- layout

func _layout() -> void:
	var r := get_viewport_rect().size
	var inset := _safe_insets()
	_minimap.position = Vector2(r.x - MAP_PX - 16.0 - inset.x, 34.0 + inset.z)
	_daynight.dock(_minimap.get_rect())
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
		_inspect_hex.position = Vector2(_minimap.position.x - 12.0 - 56.0, _daynight.position.y + DayNightDial.DISC + 8.0)  # under the dial
	# Chase joins the quick-food row (slot 2): at the rail's left edge it sat on the first food hex.
	_chase_hex.position = Vector2(16.0 + inset.w + 2.0 * (HEX + 10.0), y - HEX - CAPTION_H - 12.0)
	if HudLayout.landscape_phone(r):
		HudLayout.place_landscape_phone(self, r, inset)
	elif UiTokens.is_narrow(r):
		HudLayout.place_portrait(self, r, inset, y)
	else:
		HudLayout.place_desktop(self, r, inset)
	if _sheet:
		HudLayout.fit_sheet(self, r, inset, y)
	# Context hexes are placed when built: rebuild them on the new canvas (CLAIM stayed off a resized view).
	_ctx_ids = []
	_ctx_timer = 0.0

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
	_pets_hex = _hex("", HEX, "ANIMALS")
	_pets_hex.icon = UiIcons.icon(&"animals")
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
			if h.icon != tex or h.bottom_text != "×%d" % n:
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
	for s in [["net", "NET"], ["tackle", "TACKLE"], ["kick", "KICK"], ["roll", "ROLL"]]:
		var h := HexButton.new(SKILL_HEX)
		h.icon = UiIcons.icon(StringName(str(s[0])))
		h.caption = s[1]
		h.visible = false
		h.pressed.connect(_on_skill.bind(StringName(s[0])))
		add_child(h)
		_skill_hexes.append(h)
	_auto_hex = HexButton.new(64.0)
	_auto_hex.icon = UiIcons.icon(&"auto")
	_auto_hex.caption = "AUTO"
	_auto_hex.visible = false
	_auto_hex.pressed.connect(func () -> void:
		if player and player.hunt:
			player.hunt.auto = not player.hunt.auto
			_auto_hex.selected = player.hunt.auto
			_auto_hex.queue_redraw()
	)
	add_child(_auto_hex)
	for spec in [["attack", "sic", "SIC"], ["heel", "heel", "HEEL"], ["guard", "guard", "GUARD"]]:
		var wh := HexButton.new(64.0)
		wh.icon = UiIcons.icon(StringName(str(spec[1])))
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
	_feed_hex.icon = UiIcons.icon(&"feed")
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
			var catapult := player._nearest_group("catapult") as FieldCatapult
			if catapult and player.global_position.distance_to(catapult.global_position) <= 3.0:
				catapult.fire(player,player.hunt.target)
				return
			var weapon := player.inventory.equipped_weapon()
			if weapon and weapon.def() and weapon.def().range_m > 0.0:
				player.hunt.fire_ranged()
			else:
				player.hunt.use_net()
		&"tackle":
			var catapult := player._nearest_group("catapult") as FieldCatapult
			if catapult and player.global_position.distance_to(catapult.global_position) <= 3.0:
				catapult.fire(player,player.hunt.target,true)
			else:
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

func _on_context(id: String) -> void:
	if id != "claim":
		claim_confirm_cancel()
	player.context_action(id)

func _refresh_context(delta: float) -> void:
	_ctx_timer -= delta
	if _ctx_timer > 0.0:
		return
	_ctx_timer = 0.3
	var actions: Array = player.context_actions() if player.has_method("context_actions") else []
	if _in_combat:
		# Siege actions use the two top combat hexes, not overlapping context controls.
		actions = []
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
	var phone := UiTokens.is_phone(r)
	# Portrait: no room beside the rail, so the context row sits one row above it, from the left.
	var x := 16.0 + inset.w if phone else r.x - 16.0 - inset.x - 74.0 - 60.0
	for a in actions:
		var h := HexButton.new(70.0)
		var id := str(a["id"])
		h.glyph = str(a.get("glyph", ""))
		h.icon = UiIcons.icon(StringName(id)) if UiIcons.path_for(StringName(id)) != "" else null
		h.caption = str(a["label"]).to_upper()
		h.bottom_text = str(a.get("uses", ""))
		if h.glyph == "" and h.icon == null:
			h.glyph = h.caption
			h.caption = ""
		h.pressed.connect(_on_context.bind(id))
		add_child(h)
		if id == "claim":
			# Land claim lives by the minimap (it is about the map, not the fight).
			# Portrait: the quest card is under the map, so the claim hex goes under the card.
			h.position = Vector2(_minimap.position.x + MAP_PX - 70.0, _minimap.position.y + MAP_PX + (52.0 + 72.0 + 8.0 if phone else 44.0))
		else:
			h.position = Vector2(x, r.y - 70.0 - 26.0 - inset.y - (96.0 if phone else 0.0))
			x += 78.0 if phone else -78.0
		_ctx_hexes.append(h)
	if _sheet:
		move_child(_sheet, -1)  # a context hex added later drew (and took taps) over the open sheet

## CLAIM pressed while this survivor already holds land here: ask, naming the plots that stay and the
## plot this press would stake (claim_panel.gd). Nothing is staked, spent or moved until the panel's
## CLAIM; Close, walking away or a second CLAIM press cancels it.
func open_claim_confirm() -> void:
	if player == null or World.runtime == null or player.actions == null:
		return
	if claim_panel_open():
		claim_confirm_cancel()
		return
	var rt: Node = World.runtime
	if not rt.has_method("claim_plot"):
		return
	_claim_tile = BuildGrid.tile_of(player.global_position)
	var plot: Rect2i = rt.call("claim_plot", _claim_tile)
	_claim_panel = ClaimPanel.new()
	add_child(_claim_panel)
	_claim_panel.answered.connect(_on_claim_answered)
	_claim_panel.open(rt.get("claims"), _claim_tile, plot, str(rt.call("claim_expand_reason", _claim_tile)), _claim_stake_due())
	_claim_panel.fit(get_viewport_rect().size, _safe_insets())

func claim_panel_open() -> bool:
	return is_instance_valid(_claim_panel) and _claim_panel.visible

func claim_panel_text() -> String:
	return _claim_panel.body_text() if claim_panel_open() else ""

## Close the panel without staking (Close, Cancel, Esc, a HAUL / MOVE tap, walking away).
func claim_confirm_cancel() -> void:
	if is_instance_valid(_claim_panel):
		_claim_panel.queue_free()
	_claim_panel = null

## The panel's answer (`confirmed` = its CLAIM). The test and a headless run reach the same path.
func claim_confirm(confirmed: bool) -> void:
	claim_confirm_cancel()
	if confirmed and player and player.actions:
		player.actions.claim_confirmed()

func _on_claim_answered(confirmed: bool) -> void:
	claim_confirm(confirmed)

## The panel's confirm is about where the survivor stands when it is pressed.
func _claim_stake_due() -> bool:
	return not World.is_home() and World.free_claim_used

func _refresh_claim_panel() -> void:
	if not claim_panel_open():
		return
	var here := BuildGrid.tile_of(player.global_position) if player else _claim_tile
	if here != _claim_tile or player.placer.placing != &"":
		claim_confirm_cancel()
		return
	_claim_panel.fit(get_viewport_rect().size, _safe_insets())

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
	var base := HudLayout.placer_anchor(cam.unproject_position(ghost.global_position) + Vector2(0, 40), PLACE_OFFSETS, _placer_rel(), _placer_taken(), get_viewport_rect().size, _safe_insets())
	for i in _place_hexes.size():
		_place_hexes[i].position = base + (PLACE_OFFSETS[i] as Vector2)

const PLACE_OFFSETS := [Vector2(-105, 0), Vector2(-22, 28), Vector2(60, 0)]

## What each placer hex draws relative to its own corner (its hexagon, then its caption box), from the
## hexes themselves: the row is placed with the same geometry the check and the drawing use.
func _placer_rel() -> Array:
	var out: Array = []
	for h in _place_hexes:
		var hb := h as HexButton
		var at := hb.position
		var hex := hb.hex_rect()
		var cap := hb.caption_rect()
		out.append([Rect2(hex.position - at, hex.size), Rect2(cap.position - at, cap.size)])
	return out

## Every HUD rect the placer row must keep off: the same sources as HudLayout.taken_rects, minus the
## row's own three hexes and their captions (by node, not by where they happened to be last frame).
func _placer_taken() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k in drawn_blocks:
		out.append(drawn_blocks[k])
	for n in get_tree().get_nodes_in_group(&"hex_button"):
		var h := n as HexButton
		if h and h.is_visible_in_tree() and not _place_hexes.has(h):
			out.append(h.hex_rect())
			if h.caption != "":
				out.append(h.caption_rect())
	for c in get_children():
		var ctl := c as Control
		if ctl == null or ctl is HexButton or _place_hexes.has(ctl) or not ctl.is_visible_in_tree() or ctl.size.x < 8.0 or ctl.size.y < 8.0:
			continue
		if ctl is Label and (ctl as Label).text.strip_edges() == "":
			continue
		out.append(ctl.get_global_rect())
	var held: Control = player.station_craft.held_slot if player and player.station_craft else null
	if held and held.is_visible_in_tree():
		out.append(Rect2(held.get_global_rect().position, held.size + Vector2(0, 18)))
	var fig := figure_rect()
	if fig.has_area():
		out.append(fig)
	return out

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

## Reference: a gold text stack at the top-left for ~6 s on level-up. The signal carries the stored
## level; the banner, the title key, the bonus stat and the log use the shown one (titles.json was
## keyed by the level the player reads), from the argument, so a deferred emit stays right.
func _on_level_up(stored: int) -> void:
	var level := LevelDisplay.shown(stored)
	_levelup_lines.clear()
	_levelup_title = ""
	_levelup_lines.append([LevelDisplay.label(level), 40, Color(1.0, 0.85, 0.35)])
	_levelup_lines.append(["Pioneer XP %d" % World.pioneer_xp, 18, Color.WHITE])
	_levelup_lines.append(["T-stones %d" % World.t_stones, 18, Color.WHITE])
	# W2-SKILLS: character levels pay the SP (spec 03); show what SkillState holds (sp_now recounts,
	# since its own handler on this signal may not have run yet).
	var sp: int = player.skills.sp_now() if player and player.skills else 0
	_levelup_lines.append(["Available Skill Points: %d" % maxi(0, sp), 18, Color.WHITE])
	var title := str(_titles.get(str(level), ""))
	if title != "":
		_levelup_title = "Title %s acquired." % title
		_levelup_lines.append([_levelup_title, 18, Color(1.0, 0.85, 0.35)])
		print("[world] pioneer level %d title=\"%s\"" % [level, title])
	else:
		print("[world] pioneer level %d" % level)
	var per: Dictionary = _level_gains.get("per_level", {})
	if player and player.vitals:
		# Through Vitals, which remembers the level part in the save: added straight to max_health
		# (the old way) the next status sync erased it and a reload never brought it back.
		player.vitals.grant_level_bonus(float(per.get("max_health", 0)), float(per.get("max_energy", 0)))
	var stats: Array = _level_gains.get("display_stats", [])
	var gain := int(_level_gains.get("display_gain", 5))
	var bonus := int(_level_gains.get("bonus_stat_gain", 6))
	for i in stats.size():
		var g := bonus if (i == level % maxi(1, stats.size())) else gain
		_levelup_lines.append(["%s + %d" % [stats[i], g], 18, Color(1.0, 0.85, 0.35)])
	# The landscape banner's one stat line. No pickup toast: "+5  level" read as five levels gained.
	# ASSUMPTION: the banner alone announces a level-up (Durango shows one banner).
	var top_stat := str(stats[level % stats.size()]) if not stats.is_empty() else "Stats"
	_levelup_summary = "%s +%d · other stats +%d · Skill points %d" % [top_stat, bonus, gain, maxi(0, sp)]
	_levelup_t = 0.0

# ---------------------------------------------------------------- sheets

func _toggle_sheet(kind: StringName) -> void:
	if _sheet and _sheet_kind == kind:
		_close_sheet()
		return
	_close_sheet()
	_sheet_kind = kind
	_sheet = PanelContainer.new()
	_sheet.name = "HudSheet"
	var land := HudLayout.landscape_phone(get_viewport_rect().size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 1.0 if land else 0.94)  # opaque where it may cover the vitals
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_sheet.add_theme_stylebox_override("panel", sb)
	# Title and Close pinned on top; the rows scroll under them when the canvas is short. A landscape
	# phone lays the rows in two columns so the menu fits without a scroll.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_sheet.add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	outer.add_child(head)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var close := Button.new()
	close.name = "SheetClose"
	close.text = "Close"
	close.custom_minimum_size = Vector2(110, UiTokens.TARGET_PRIMARY)
	close.pressed.connect(_close_sheet)
	head.add_child(close)
	_sheet_rows = ScrollContainer.new()
	_sheet_rows.name = "SheetRows"
	_sheet_rows.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_sheet_rows)
	var box: Container
	if land:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		box = grid
	else:
		box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
	_sheet_rows.add_child(box)
	match kind:
		&"menu":
			title.text = "Menu"
			_sheet_btn(box, "Bag", func () -> void: _close_sheet(); if player.ui: player.ui.visible = not player.ui.visible)
			_sheet_btn(box, "Craft", func () -> void: _close_sheet(); if player.craft_ui: player.craft_ui.toggle())
			_sheet_btn(box, "Build", func () -> void: _close_sheet(); var b := BuildUI.ensure(player); if b: b.toggle())
			_sheet_btn(box, "Map", func () -> void: _close_sheet(); _open_map())
			# spec 29 section 2: Gameplay HUD -> Main Menu -> Domain.
			_sheet_btn(box, "Domain", func () -> void: _close_sheet(); _open_domain())
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
			StructureSheet.fill_build(player, func (t: String, cb: Callable) -> void: _sheet_btn(box, t, cb), _refresh_sheet, _close_sheet)
			any = true  # modular pieces are always buildable from materials: no "no kits" note eating the rows
			if not any:
				# Under the rows, wrapped to the sheet's width (in the two-column grid it stretched the sheet to 708 px).
				var l := Label.new()
				l.text = "No building kits in the bag. Craft one at the workbench."
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				outer.add_child(l)
		&"structure":
			title.text = StructureSheet.fill_card(box, player, func (t: String, cb: Callable) -> void: _sheet_btn(box, t, cb), _close_sheet)
	add_child(_sheet)
	_layout()
	await get_tree().process_frame
	_layout()

## A tapped modular piece (W2-BUILDSYS): its card in the bottom sheet.
func open_structure(sp: StructurePiece) -> void:
	StructureSheet.card = sp
	_close_sheet()
	_toggle_sheet(&"structure")

func _sheet_btn(box: Container, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	var land := HudLayout.landscape_phone(get_viewport_rect().size)
	b.custom_minimum_size = Vector2(150, UiTokens.TARGET_PRIMARY) if land else Vector2(300, 60)
	b.add_theme_font_size_override("font_size", 16 if land else 18)
	b.pressed.connect(cb)
	box.add_child(b)

## True while one of the HUD's sheets is open. HANDS (held_item_slot.gd) and the creature plates sit
## on canvas layers above the HUD's and hide meanwhile: on a landscape phone HANDS sat on the sheet's
## Close, so a tap there swapped the held tool.
func sheet_open() -> bool:
	return _sheet != null or (_skills_sheet != null and _skills_sheet.visible)

## Screen rects the HUD holds this frame (see HudLayout.taken_rects).
func taken_rects(skip: PackedStringArray = []) -> Array[Rect2]:
	return HudLayout.taken_rects(self, skip)

## The survivor on screen, head to name (see HudLayout.figure_rect).
func figure_rect() -> Rect2:
	return HudLayout.figure_rect(self)

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
		_sheet_rows = null
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

var _domain_screen: DomainScreen

## spec 29: the Domain screen (four territory tabs, Declare/Expand with the ground preview).
func _open_domain() -> void:
	if _domain_screen == null:
		_domain_screen = DomainScreen.new()
		var layer := CanvasLayer.new()
		layer.name = "DomainLayer"
		layer.layer = 96
		add_child(layer)
		layer.add_child(_domain_screen)
	if _domain_screen.is_open():
		_domain_screen.close()
	else:
		_domain_screen.open(player)

## The Domain screen, when the HUD has made one (the lab and tests read it).
func domain_screen() -> DomainScreen:
	return _domain_screen

# ---------------------------------------------------------------- per frame

func _build_fatigue_panel() -> void:
	_fatigue_panel = FatiguePanel.new()
	_fatigue_panel.player = player
	_fatigue_panel.visible = false
	add_child(_fatigue_panel)

## A tap on the fatigue face or bar opens "what is tiring you".
func _input(event: InputEvent) -> void:
	if player == null or player.dead or _fatigue_panel == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _fatigue_rect.has_point(event.position):
			_fatigue_panel.player = player
			_fatigue_panel.toggle()
			queue_redraw()
			get_viewport().set_input_as_handled()

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
		var catapult := player._nearest_group("catapult") as FieldCatapult
		var siege := catapult != null and player.global_position.distance_to(catapult.global_position) <= 3.0
		_skill_hexes[1].caption = "TOXIN %d" % player.inventory.count_of(&"toxin_pot") if siege else "TACKLE"
		_skill_hexes[1].icon = UiIcons.icon(&"toxin" if siege else &"tackle")
		_skill_hexes[1].queue_redraw()
		var weapon := player.inventory.equipped_weapon()
		var ranged := weapon != null and weapon.def() != null and weapon.def().range_m > 0.0
		_skill_hexes[0].caption = "FIRE %d" % player.inventory.count_of(weapon.def().ammo_id) if ranged else "NET"
		_skill_hexes[0].icon = UiIcons.icon(&"fire_ranged" if ranged else &"net")
		_skill_hexes[0].disabled = player.inventory.count_of(weapon.def().ammo_id) <= 0 if ranged else not (player.hunt.target.capturable() and player.hunt._best_net_ok())
		if siege:
			_skill_hexes[0].caption = "SIEGE %d" % player.inventory.count_of(&"stone_shot")
			_skill_hexes[0].icon = UiIcons.icon(&"siege")
			_skill_hexes[0].disabled = catapult.reload_left > 0 or player.inventory.count_of(&"stone_shot") == 0
		_skill_hexes[0].queue_redraw()
		_skill_hexes[1].disabled = (catapult.reload_left > 0 or player.inventory.count_of(&"toxin_pot") == 0) if siege else player.hunt._tackle_cd > 0.0
		_skill_hexes[2].disabled = player.hunt._kick_cd > 0.0
		for h in _skill_hexes:
			h.queue_redraw()
	_refresh_context(delta)
	_refresh_claim_panel()
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
	_pulse_clock += delta
	_pulse_check -= delta
	if _pulse_check <= 0.0:
		_pulse_check = SKILL_PULSE_TICK
		_refresh_skill_pulse()
	_domain.tick(delta, World.runtime, player.global_position)
	_minimap.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if player == null or player.dead:
		return
	var r := get_viewport_rect().size
	drawn_blocks.clear()
	var v := player.vitals
	if player.placer and player.placer.placing != &"":
		draw_rect(Rect2(Vector2.ZERO, r), Color(0.02, 0.03, 0.04, 0.28))
	var inset := _safe_insets()
	var x := 16.0 + inset.w
	var y := 12.0 + inset.z
	var phone := UiTokens.is_phone(r)
	# Desktop: 300 px panel, 16 px HP/energy bars with body-size numbers (the audit called the
	# old 176 px / 12 px block "tiny desktop typography"). Phone keeps the compact block.
	var vitals := HudLayout.vitals_rect(self, r)
	var panel_w := vitals.size.x
	var bar_w := 232.0 if not phone else maxf(88.0, panel_w - 54.0)
	var big := 16.0 if not phone else 12.0
	var small := 10.0 if not phone else 8.0
	var gap := 6.0
	var num_px := UiTokens.body(r) - 1 if not phone else 12
	var bar_px := UiTokens.meta(r) if not phone else 12
	draw_rect(vitals, UiTokens.INK)
	drawn_blocks["vitals"] = vitals
	var lvl_r := 18.0 if not phone else 16.0
	draw_circle(Vector2(x + lvl_r, y + lvl_r), lvl_r, Color(0.08, 0.09, 0.11, 0.95))
	draw_string(_font, Vector2(x, y + lvl_r + num_px * 0.36), str(LevelDisplay.player_level()), HORIZONTAL_ALIGNMENT_CENTER, lvl_r * 2.0, num_px, Color.WHITE)
	x += lvl_r * 2.0 + 8.0
	var yy := y
	_bar(Vector2(x, yy), Vector2(bar_w, big), v.health / maxf(1.0, v.effective_max_health()), Color(0.78, 0.13, 0.13), "", "%.0f / %.0f" % [v.health, v.effective_max_health()], num_px)
	yy += big + gap
	_bar(Vector2(x, yy), Vector2(bar_w, big), v.energy / maxf(1.0, v.effective_max_energy()), Color(0.20, 0.45, 0.80), "", "%.0f / %.0f" % [v.energy, v.effective_max_energy()], num_px)
	yy += big + gap
	var strain: float = clampf(v.fatigue / maxf(1.0, v.max_fatigue), 0.0, 1.0)
	var face_pos := Vector2(x + 11.0, yy + 10.0)
	_draw_exhaustion_face(face_pos, strain)
	# The words follow spec 01's fatigue scale (0-24 rested, 25-49 slightly tired, 50-74 tired,
	# 75-99 exhausted); the playtest read "TIRED" a few minutes into a walk and it was 25 %.
	var face_label := "RESTED" if strain < 0.25 else ("WORN" if strain < 0.5 else ("TIRED" if strain < 0.75 else "EXHAUSTED"))
	var face_col := Color(0.42, 0.78, 0.53).lerp(Color(0.96, 0.42, 0.36), strain)
	draw_string(_font, Vector2(x + 27.0, yy + 14.0), face_label, HORIZONTAL_ALIGNMENT_LEFT, bar_w - 30.0, bar_px, face_col)
	yy += 22.0
	_bar(Vector2(x, yy), Vector2(bar_w, small), strain, face_col, "", "%d%%" % int(strain * 100.0), bar_px)
	_fatigue_rect = Rect2(x, face_pos.y - 14.0, bar_w, maxf(UiTokens.TARGET_MIN, yy + small - face_pos.y + 14.0))
	if _fatigue_panel and _fatigue_panel.visible:
		_fatigue_panel.position = Vector2(_fatigue_rect.position.x, _fatigue_rect.end.y + 8.0)
	# status badges live under the minimap (right side), left of the Claim hex; on a landscape phone
	# End Combat stands there, so they go under the vitals, after the whistle row
	var mp0 := _minimap.position
	var sx := mp0.x
	var sy := mp0.y + MAP_PX + 50.0
	if HudLayout.landscape_phone(r):
		sx = 16.0 + inset.w + (3.0 * (HEX + 10.0) if _whistle_hexes[0].visible else 0.0)
		sy = vitals.end.y + 8.0
	if player.statuses:
		var sx0 := sx
		for inst in player.statuses.instances():
			HudStatusChip.draw(self, _font, Vector2(sx, sy), inst.id, Color(1, 0.75, 0.45))
			if inst.time_left < 3600.0:  # "until washed / treated" statuses (9999 s) show no countdown
				draw_string(_font, Vector2(sx, sy + 40), "%.0f" % inst.time_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTokens.META)
			sx += 30
		if sx > sx0:
			drawn_blocks["statuses"] = Rect2(sx0, sy, sx - sx0 - 4.0, 44.0)
		# SAVEFIX: a status that lowers max HP says so under its chip (the number alone was a mystery).
		var hp_note: String = player.statuses.max_health_note()
		if hp_note != "":
			var ny := sy + 46.0
			var nw := _font.get_string_size(hp_note, HORIZONTAL_ALIGNMENT_LEFT, -1, bar_px).x
			draw_string(_font, Vector2(sx0, ny), hp_note, HORIZONTAL_ALIGNMENT_LEFT, -1, bar_px, Color(0.96, 0.62, 0.42))
			drawn_blocks["status_maxhp"] = Rect2(sx0, ny - bar_px, nw, bar_px + 4.0)
	var mp := _minimap.position
	var top := "Home" if World.is_home() else ("Survivable %d min" % int(ceil(World.remaining_lifetime / 60.0)))
	if World.island_id == &"":
		top = "Lab"
	var meta_px := UiTokens.meta(r)
	draw_string(_font, Vector2(mp.x, mp.y - 16.0), UiTokens.ellipsis(_font, top, MAP_PX, meta_px), HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, meta_px, Color.WHITE)
	drawn_blocks["map_title"] = Rect2(mp.x, mp.y - 16.0 - meta_px, MAP_PX, meta_px + 4.0)
	var tile := BuildGrid.tile_of(player.global_position)
	draw_string(_font, Vector2(mp.x, mp.y + MAP_PX + 16), "X %d  Y %d" % [tile.x, tile.y], HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, meta_px, UiTokens.META)
	# The clock and phase line moved into the day/night dial's label: the dial shows the phase already.
	drawn_blocks["map_text"] = Rect2(mp.x, mp.y + MAP_PX + 16.0 - meta_px, MAP_PX, meta_px + 4.0)
	# The target plate (current hunt target, else the last creature attacked while it lives) and the
	# level-up banner take over the landscape phone's centre band from the quest card while they show.
	var plate_t: Creature = player.hunt.target if (player.hunt and player.hunt.target and is_instance_valid(player.hunt.target)) else null
	if plate_t == null and _last_target and is_instance_valid(_last_target) and not _last_target.health.dead and player.global_position.distance_to(_last_target.global_position) < 40.0:
		plate_t = _last_target
	var band := HudLayout.centre_band(self, r)
	if not band.has_area() or (plate_t == null and _levelup_t < 0.0):
		_draw_quest(r, mp)
	# --- XP bar along the bottom
	# One bar: the pioneer level, which every skill XP grant also feeds.
	var prog := World.pioneer_progress() if World.has_method("pioneer_progress") else 0.0
	draw_rect(Rect2(0, r.y - 4, r.x, 4), Color(0.05, 0.05, 0.07, 0.9))
	draw_rect(Rect2(0, r.y - 4, r.x * prog, 4), Color(0.90, 0.68, 0.12))
	var lv := "%s  %.1f%%" % [LevelDisplay.player_label(), prog * 100.0]
	var lw := _font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
	var lv_pos := Vector2(r.x - lw - 16.0 - inset.x, r.y - HEX - 22.0) if phone else Vector2(r.x * 0.5 - lw * 0.5, r.y - 7.0)
	draw_string(_font, lv_pos, lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	drawn_blocks["level"] = Rect2(lv_pos - Vector2(0.0, 12.0), Vector2(lw, 15.0))
	# --- name under the survivor
	var cam := get_viewport().get_camera_3d()
	if cam:
		drawn_blocks["nameplate"] = HudLayout.nameplate_rect(cam, player, _font)
		var at := (drawn_blocks["nameplate"] as Rect2).position + Vector2(0.0, NAME_PX)
		draw_string(_font, at + Vector2.ONE, player.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX, Color(0, 0, 0, 0.7))
		draw_string(_font, at, player.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX, Color(0.95, 0.95, 0.95))
	_draw_bites(cam)
	# --- level-up: a gold stack top-left under the bars; on a landscape phone a short banner in the
	# centre band (its 13 lines ran over the rail and off the bottom of a 390 px canvas)
	if plate_t:
		_draw_target_plate(plate_t, maxf(_combat_alpha, 0.85), band)
	if _levelup_t >= 0.0:
		var la := 1.0 - smoothstep(5.5, 6.5, _levelup_t)
		if band.has_area():
			var below := maxf(band.end.y, (drawn_blocks.get("plate", band) as Rect2).end.y) + 8.0
			HudLayout.draw_levelup_banner(self, band if plate_t == null else Rect2(band.position.x, below, band.size.x, 84.0), la)
		else:
			var ly := 160.0
			var stack := Rect2()
			for line in _levelup_lines:
				var col: Color = line[2]
				col.a *= la
				draw_string(_font, Vector2(31, ly + 1), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1]), Color(0, 0, 0, 0.6 * la))
				draw_string(_font, Vector2(30, ly), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1]), col)
				var lr := Rect2(30.0, ly - float(line[1]), _font.get_string_size(str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(line[1])).x + 1.0, float(line[1]) + 6.0)
				stack = lr if not stack.has_area() else stack.merge(lr)
				ly += float(line[1]) + 8.0
			drawn_blocks["levelup"] = stack
	# --- the domain banner, before the moving text so it keeps off the banner
	_domain.draw(self)
	# --- pickup toasts near the top-centre, rising and fading, then the notices: each takes the nearest
	# free spot up or down its column, off every block and hex (on a landscape phone they crossed the
	# quest card at y 100-128). On a phone the toasts stack under the vitals instead: in the centre
	# they covered the survivor. One with no room left on screen is skipped.
	# ASSUMPTION: pickup toasts may move to the left edge on a phone (no reference for it).
	var taken := taken_rects()
	var toast_left := UiTokens.is_compact(r)
	var cx := band.get_center().x if band.has_area() else r.x * 0.5  # a phone's free middle, off HANDS and the map
	# --- skill XP and tree level-up toasts (spec 25 §7 "it gives you an xp amount", islands-and-loop-plan
	# §3.3). They take their spot first, so a pickup toast gives way rather than covering one. A level-up
	# line is bigger and gold; the small XP lines sit under it. Every one is drawn only on a free spot,
	# so none covers the vitals, the map, the plate or the survivor.
	var skill_rows: Array = _events.skill_toasts
	for i in skill_rows.size():
		var e: Dictionary = skill_rows[i]
		var age := float(e["t"])
		var life := float(e["life"])
		var alpha := 1.0 - smoothstep(life * 0.6, life, age)
		var is_big := bool(e["big"])
		var px := 22 if is_big else 16
		var label := str(e["text"])
		if is_big:
			label = "▲ " + label
		var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, px).x
		var rise := 26.0 * (1.0 - minf(age, 1.0))
		var h := float(px) + 12.0
		var cand := Rect2(cx - tw * 0.5 - 12.0, 64.0 + rise, tw + 24.0, h)
		if toast_left:
			cand.position = Vector2(vitals.position.x, vitals.end.y + 8.0 + rise)
		var box := UiTokens.free_spot(cand, taken, r)
		if not box.has_area():
			continue
		taken.append(box)
		drawn_blocks["skilltoast%d" % i] = box
		draw_rect(box, Color(0.05, 0.06, 0.08, (0.86 if is_big else 0.74) * alpha))
		if is_big:
			draw_rect(Rect2(box.position, Vector2(4.0, box.size.y)), Color(1.0, 0.85, 0.35, alpha))
		var col := Color(1.0, 0.87, 0.45, alpha) if is_big else Color(1, 1, 1, alpha)
		draw_string(_font, box.position + Vector2(12.0, box.size.y * 0.5 + float(px) * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

	for i in _events.toasts.size():
		var t: Dictionary = _events.toasts[i]
		var k: float = t["t"]
		var alpha := 1.0 - smoothstep(0.7, 1.3, k)
		var def := Data.item(t["id"])
		var label := "+%d  %s" % [int(t["n"]), def.display_name if def else str(t["id"])]
		var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		var rise := 35.0 * (1.0 - minf(k, 1.0))
		var cand := Rect2(cx - tw * 0.5 - 10, 65.0 + rise, tw + 20, 28)
		if toast_left:
			cand.position = Vector2(vitals.position.x, vitals.end.y + 8.0 + rise)
		var box := UiTokens.free_spot(cand, taken, r)
		if not box.has_area():
			continue
		taken.append(box)
		drawn_blocks["toast%d" % i] = box
		draw_rect(box, Color(0.05, 0.06, 0.08, 0.8 * alpha))
		draw_string(_font, box.position + Vector2(10, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, alpha))
	# --- the SKILLS hex pulse: a soft gold halo while a buyable node is affordable (islands-and-loop-plan
	# §3.3). Drawn by the HUD, under the hex itself, so it needs nothing from HexButton; it breathes on a
	# sine and never jumps, and it is a halo rather than a size change so the touch target stays put.
	_draw_skill_pulse()
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
		var txt: String = UiTokens.ellipsis(_font, n["text"], r.x - 48.0, 17)
		var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
		var box := UiTokens.free_spot(Rect2(cx - tw * 0.5 - 12, 170.0, tw + 24, 30), taken, r)
		if not box.has_area():
			continue
		taken.append(box)
		drawn_blocks["notice%d" % i] = box
		draw_rect(box, Color(0.35, 0.08, 0.06, 0.85 * alpha))
		draw_string(_font, box.position + Vector2(12, 21), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.8, alpha))
	# --- label pills on buildings and nodes within 8 m (reference: base building), last: they give way
	# to everything above and to the open radials
	HudPills.draw(self, cam, taken)
	# --- combat layer
	if _combat_alpha > 0.01:
		var a := _combat_alpha
		draw_rect(Rect2(0, 0, r.x, 6), Color(0.85, 0.1, 0.1, 0.75 * a))
		draw_rect(Rect2(0, r.y - 6, r.x, 6), Color(0.85, 0.1, 0.1, 0.75 * a))

## The SKILLS hex's "something is affordable" halo (islands-and-loop-plan §3.3). A gold ring just outside
## the hex outline that breathes between 25 % and 80 % of its strength over SKILL_PULSE_SECONDS; it is
## drawn around the same pointy-top hex hex_button.gd outlines, so it reads as the hex glowing, and the
## touch target and the caption never move. Off while the sheet is open (the sheet is the answer).
func _draw_skill_pulse() -> void:
	if _skills_hex == null or not skills_pulsing() or (_skills_sheet != null and _skills_sheet.visible):
		return
	var c := _skills_hex.get_global_rect().get_center() - get_global_rect().position
	var rad := minf(_skills_hex.size.x, _skills_hex.size.y) * 0.5 - 2.0
	var breathe := 0.25 + 0.55 * (0.5 + 0.5 * sin(TAU * fmod(_pulse_clock, SKILL_PULSE_SECONDS) / SKILL_PULSE_SECONDS))
	var pts := PackedVector2Array()
	for i in 7:
		var a := deg_to_rad(60.0 * float(i % 6) - 30.0)
		pts.append(c + Vector2(cos(a), sin(a)) * (rad + 4.0))
	draw_polyline(pts, Color(1.0, 0.85, 0.35, 0.18 * breathe), 7.0, true)
	draw_polyline(pts, Color(1.0, 0.85, 0.35, breathe), 2.5, true)
	drawn_blocks["skillpulse"] = Rect2(c - Vector2(rad + 5.0, rad + 5.0), Vector2(rad + 5.0, rad + 5.0) * 2.0)

func _draw_target_plate(t: Creature, a: float, band: Rect2 = Rect2()) -> void:
	var r := get_viewport_rect().size
	if true:
		if t and is_instance_valid(t):
			var pw := minf(520.0, r.x - 24.0)
			var px := r.x * 0.5 - pw * 0.5
			var py := 14.0 + _safe_insets().z
			if band.has_area():  # landscape phone: between the vitals and the map, not across them
				pw = band.size.x
				px = band.position.x
				py = band.position.y + 8.0
			var block := Rect2(px, py - 4.0, pw, 70.0)
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
			if t.brain is TyrantBrain:
				var label := (t.brain as TyrantBrain).opening_label()
				draw_rect(Rect2(px,py+108,pw,26),Color(0.1,0.1,0.12,0.9*a))
				draw_string(_font,Vector2(px+8,py+128),label,HORIZONTAL_ALIGNMENT_LEFT,pw-16,16,Color(1,0.85,0.2,a))
				block = block.merge(Rect2(px, py + 108.0, pw, 26.0))
			var ix := px
			if t.statuses:
				for inst in t.statuses.instances():
					HudStatusChip.draw(self, _font, Vector2(ix, py + 74), inst.id, Color(1, 0.6, 0.5), a)
					block = block.merge(Rect2(ix, py + 74.0, 26.0, 26.0))
					ix += 30
			drawn_blocks["plate"] = block

func _draw_quest(r: Vector2, mp: Vector2) -> void:
	var phone := UiTokens.is_phone(r)
	var w := MAP_PX if phone else 240.0  # wide enough for "Home Grassland" at heading size
	var origin := Vector2(mp.x, mp.y + MAP_PX + 52.0) if phone else Vector2(mp.x - w - 12.0, mp.y)
	if origin.x < 8.0:
		origin.x = 8.0
	draw_rect(Rect2(origin, Vector2(w, 72.0)), UiTokens.INK)
	draw_rect(Rect2(origin, Vector2(3.0, 72.0)), UiTokens.TEAL)
	drawn_blocks["quest"] = Rect2(origin, Vector2(w, 72.0))
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
