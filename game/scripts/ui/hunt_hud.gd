class_name HuntHud
extends Control
## The Durango HUD (docs/reference/durango-look-reference.webp, durango-combat-reference.jpg):
## top-left vitals bars, top-right minimap with survivable time and coordinates, bottom-left
## rail MENU / BUILD / BAG (owner 2026-10-28; Skills and Animals live in the MENU sheet), bottom-right
## INTERACT / ATTACK NEAREST / SPRINT (HudField), XP bar along the bottom, the survivor's name under her feet. During a hunt: red frame, top-centre target
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
var _build_hex: HexButton
var _bag_hex: HexButton
var _inspect_hex: HexButton
var field: HudField  ## INTERACT / ATTACK NEAREST / SPRINT and the MENU notice badge
var _fatigue_rect := Rect2() ## screen rect of the fatigue face and bar, recorded in _draw; a tap opens the panel
var _fatigue_panel: FatiguePanel
var _fat_rate := 0.0 ## EMA of d(fatigue)/dt, pt/s: rises while working awake, plunges on a sleep
var _fat_prev := -1.0e9 ## last sampled fatigue; sentinel until the first frame
var _fat_forgive := 0.0 ## countdown of fast forgetting after a one-off step (sleep/meal)
var _belt_phase := 0.0 ## treadmill belt scroll position, px
var _sheet: Control  ## the open sheet: a PanelContainer, or the NavMenu (B3) for &"menu"
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
var _swords_hex: TargetSwordsHex  # beside the selected wild animal: starts the fight (spec 23)
var _in_combat: bool = false
var _combat_alpha: float = 0.0
var _last_target: Creature  # top plate stays on the last creature attacked until it dies or a new one is hit
var _stance_label: Label
var _events := HudEventState.new()
var top_feed := TopFeed.new()  ## the top-middle column: skill level-ups and gains by tier (owner 2026-10-28; it retired UIGATHER's yield card)
var _rest_fx := HudRestBox.new()
var _status_fx := StatusFx.new()
var _buff_row := HudBuffRow.new()  ## HUDRULES: buffs / boons / debuffs under the vitals, with tooltips
var stomach_rect := Rect2()  ## HUDRULES: the fullness ring beside the bars, drawn this frame
var stomach_fill := 0.0  ## fullness, 1 = a full stomach, above 1 = overfull
var stomach_saturation := 0.0  ## the outer ring: 0..1 of the digestion cooldown left
var stomach_state: StringName = &"empty"
var stomach_glyph_scale := 0.92  ## eased toward HudStomach.GLYPH_SCALE[stomach_state]
var energy_bar_color := UiTokens.PLAYER_ENERGY  ## drawn this frame: the mount's darker blue while riding
var energy_bar_segments := 0
var orders_badge_rect := Rect2()  ## HUDRULES: the collapsed orders badge on the minimap, drawn this frame
var orders_badge_text := ""
var _orders_badge_px := 12
var _orders_flash := 0.0
var _orders_seen := -1
## HUDRULES (owner: "auto expand when you are doing something to complete the task"): seconds the card
## stays auto-expanded after the last progress on the shown order (or while the fight serves it).
var orders_auto_t := 0.0
var _orders_suppressed := false  # collapsed by hand during this activity: stays collapsed until it ends
var _orders_frac := -1.0
var _orders_frac_index := -1
var _orders_poll := 0.0
var _tasks_poll := 0.0  ## TASKSCREEN: seconds to the next claimable-task count for the MENU / Orders badge
const ORDERS_AUTO_S := 4.0  # ASSUMPTION: the owner asked for "a few seconds"
var _domain := DomainBanner.new()  ## spec 18: "<owner>'s Domain" on walking into claimed land
var _ctx_hexes: Array[HexButton] = []
var _claim_hex: HexButton  ## HUDTWEAK: the CLAIM context hex while it exists (above the day/night dial)
var _ctx_ids: Array = []
var _ctx_timer: float = 0.0
var _place_hexes: Array[HexButton] = []
var _claim_panel: ClaimPanel  ## the CLAIM confirm (a second claim asks first; claim_panel.gd)
var _claim_tile := Vector2i.ZERO  ## where the survivor stood when it opened
var _done_hex: HexButton
var _levelup_lines: Array = []
var _levelup_title: String = ""  ## the title line and one stat summary: the landscape-phone banner
var _levelup_summary: String = ""
var _levelup_sp: String = ""  ## the skill points the phone banner shows behind the brain glyph
var hp_bar_rect := Rect2()  ## LEVELBAR: the health bar as last drawn (the energy bar is the same width under it)
var xp_bar_rect := Rect2()  ## LEVELBAR: the bottom level bar as last drawn (tests read it)
var _badge_centre_drawn := Vector2.ZERO  ## HUDTWEAK: tests read where the badge was centred
var level_badge_rect := Rect2()  ## LEVELBADGE: the top-left level badge as last drawn, glow included
var bar_trail: Dictionary = {}  ## LEVELBADGE: per-bar (fill, ghost, hold) for the trailing ghost fill (_trail)
const TRAIL_HOLD := 0.4
const TRAIL_EASE := 6.0
var map_xy_text := ""  ## LEVELBADGE: the coordinates under the minimap, as last drawn
var _map_xy := Vector2i(1 << 30, 0)
var level_badge_tier := 0  ## its tier (HudLevelBadge.tier_of)
var exhaust_sticker_rect := Rect2()  ## LEVELBADGE: the exhaustion face riding the belt at the strain marker
var xp_bar_segments := 0  ## its segment count as last drawn
var _levelups := LevelUpCelebration.new()  ## level-ups queued, celebrated one at a time, with their light (LEVELFX)
## Screen rects of the blocks _draw paints (vitals, quest card, map text, status badges, level line,
## target plate, level-up banner), rebuilt every draw. Layout gates check them with the controls, so
## nothing mirrors this file's geometry.
var drawn_blocks: Dictionary = {}
## The target plate's name, nature tag and HP bar rects from the last draw (layout tests read them).
var target_rows: Dictionary = {}
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
const MAP_RIM := 6.0  ## LEVELBADGE: the minimap frame band
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
	field = HudField.new(self)
	if skills_pulse_on:  # bound (and counted) before the badge existed
		notify_menu(&"skills")
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
	if Game.shot_path.contains("statusfx"):  # STATUSFX captures: she bleeds (x3), and is poisoned too on "poison"
		get_tree().create_timer(0.6).timeout.connect(func () -> void:
			if player:
				player.statuses.apply(&"bleed_3")
				if Game.shot_path.contains("poison"):
					player.statuses.apply(&"venom"))
	if Game.shot_path.contains("hudrules") or Game.shot_path.contains("titles") or Game.shot_path.contains("levelbar") or Game.shot_path.contains("levelbadge"):  # HUDRULES captures: bleed, Well Rested, a food buff (HudrulesShot)
		get_tree().create_timer(0.6).timeout.connect(func () -> void: HudrulesShot.stage(self))
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
	top_feed.sync(p)
	_watch_skills()

## Skill feedback (spec 25 §7, islands-and-loop-plan §3.3): the XP toast and the bigger level-up toast
## on skill_xp_gained/skill_leveled, and the MENU badge's skill notices (a level-up, SP that buys a node).
## Connected here (a Player may be bound before or after this HUD enters the tree) and never twice.
var _skills_watched: SkillState = null
## Seconds between affordability recounts: node_state walks twelve trees, no need to do it per frame.
const SKILL_PULSE_TICK := 0.25
var skills_pulse_on: bool = false
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
			notify_menu(&"skills")  # MENU badge: a level-up to look at in Skills
			_levelups.push_skill(tree, level)  # LEVELFX: the light, the banner, the MENU / Skills badge pulse
		)
	if sk.has_signal("skill_changed"):
		# A purchase or a refund moves the SP, and the pulse must answer on the same frame.
		sk.skill_changed.connect(func (_tree: StringName, _level: int) -> void:
			_pulse_check = 0.0
			_refresh_skill_pulse()
		)
	_refresh_skill_pulse()

## True while at least one buyable node is affordable with the SP held (each time it turns true the
## MENU badge gets a skills notice; the SKILLS rail hex and its halo are gone). Public for labs and tests.
func skills_pulsing() -> bool:
	return skills_pulse_on and player != null and not player.dead

func _refresh_skill_pulse() -> void:
	if player == null or player.skills == null:
		skills_pulse_on = false
		return
	var was := skills_pulse_on
	skills_pulse_on = SkillRules.affordable_now(player.skills)
	if skills_pulse_on and not was and field:
		notify_menu(&"skills")  # MENU badge: SP now buys a node (counted once each time it becomes true)

# ---------------------------------------------------------------- layout

func _layout() -> void:
	var r := get_viewport_rect().size
	var inset := _safe_insets()
	_minimap.position = Vector2(r.x - MAP_PX - 16.0 - inset.x, 34.0 + inset.z)
	_daynight.dock(_minimap.get_rect())
	# Rail bottom-left: MENU, BUILD, BAG (owner 2026-10-28), captions under them inside the safe area.
	var rail := HudField.px(&"rail", r)
	var y := r.y - rail - CAPTION_H - 14.0 - inset.y
	var x := 16.0 + inset.w
	for h in [_menu_hex, _build_hex, _bag_hex]:
		HudField.fit(h, rail)
		h.position = Vector2(x, y)
		x += rail + 10.0
	# Quick slots above the rail: two quick-food hexes, CHASE in the third slot during a fight.
	var q := HudField.px(&"quick", r)
	var qy := quick_row_y()
	for i in _food_hexes.size():
		HudField.fit(_food_hexes[i], q)
		_food_hexes[i].position = Vector2(16.0 + inset.w + float(i) * (q + 10.0), qy)
	HudField.fit(_chase_hex, q)
	_chase_hex.position = Vector2(16.0 + inset.w + 2.0 * (q + 10.0), qy)
	# Debug hex stays off the minimap. On a phone it drops to the lower right so the vitals can sit beside the map.
	_inspect_hex.visible = Game.debug_overlay
	if UiTokens.is_phone(r):
		_inspect_hex.position = Vector2(r.x - HEX - 16.0 - inset.x, r.y - HEX * 2.0 - 36.0 - inset.y)
	else:
		_inspect_hex.position = Vector2(_minimap.position.x - 12.0 - 56.0, _daynight.position.y + _daynight.size.y + 8.0)  # under the dial
	field.place(r, inset, map_floor())
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

## The lowest y the minimap column holds: the map, then its "X n  Y n" line under it.
func map_floor() -> float:
	return _minimap.position.y + MAP_PX + 24.0

## The quick row's top (food, food, CHASE above the rail).
func quick_row_y() -> float:
	var r := get_viewport_rect().size
	var q := HudField.px(&"quick", r)
	return r.y - HudField.px(&"rail", r) - CAPTION_H - 14.0 - _safe_insets().y - q - CAPTION_H - 12.0

## A notice for the MENU badge (HudField.notify): &"skills", &"market" (hook: no client market events
## yet) or any sheet id; urgent draws the badge red. Cleared when that sheet opens.
func notify_menu(kind: StringName, n: int = 1, urgent: bool = false) -> void:
	field.notify(kind, n, urgent)

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
	_minimap.draw.connect(_draw_orders_on_map)  # HUDRULES: after the map, so the badge sits over its corner
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
	_menu_hex.name = "MenuHex"
	_menu_hex.pressed.connect(func () -> void: _toggle_sheet(&"menu"))
	_build_hex = _hex("⌂", HEX, "BUILD")
	_build_hex.name = "BuildHex"
	_build_hex.pressed.connect(func () -> void: var b := BuildUI.ensure(player); if b: b.toggle())  # UICRAFT: the D2 drawer
	_bag_hex = _hex("", HEX, "BAG")
	_bag_hex.name = "BagHex"
	_bag_hex.icon = UiIcons.icon(&"bag")
	_bag_hex.key_hint = "I"
	_bag_hex.pressed.connect(func () -> void:
		if player:
			_close_sheet()
			player.controls.toggle_inventory())
	for h in [_menu_hex, _build_hex, _bag_hex]:
		h.rim_color = UiTokens.HUD_RIM
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


## The Animals screen; with a record (the pet radial's Animals segment) it opens on that pet.
func open_animals(rec: PetRecord = null) -> void:
	_close_sheet()
	if _animal_screen == null:
		_animal_screen = AnimalScreen.new()
		_animal_screen.name = "AnimalScreen"
		var layer := CanvasLayer.new()
		layer.name = "AnimalLayer"
		layer.layer = 96
		add_child(layer)
		layer.add_child(_animal_screen)
	_animal_screen.open(player, rec)

## TRIBE M1: the Animals screen's Tribe tab (a member or recruit tapped in the world opens it on them).
var _tribe_screen: TribeScreen

func open_tribe(rec: TribeRecord = null) -> TribeScreen:
	_close_sheet()
	if _animal_screen and _animal_screen.visible:
		_animal_screen.close_screen()
	if _tribe_screen == null or not is_instance_valid(_tribe_screen):
		var layer := CanvasLayer.new()
		layer.name = "TribeLayer"
		layer.layer = 96
		add_child(layer)
		_tribe_screen = TribeScreen.new()
		_tribe_screen.name = "TribeScreen"
		layer.add_child(_tribe_screen)
	_tribe_screen.open(player, rec)
	return _tribe_screen

## SADDLES: a tame's equipment (pet radial Gear, Animals screen Gear). Its own layer above the Animals
## screen, so ‹ shows the Animals screen again when it was opened from there.
var _pet_gear: PetGearSheet

func open_pet_gear(rec: PetRecord) -> PetGearSheet:
	if rec == null:
		return null
	if _pet_gear == null or not is_instance_valid(_pet_gear):
		var layer := CanvasLayer.new()
		layer.name = "PetGearLayer"
		layer.layer = 97
		add_child(layer)
		_pet_gear = PetGearSheet.new()
		layer.add_child(_pet_gear)
	_pet_gear.open(player, rec)
	return _pet_gear

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
		_combat_style(h)
		# ASSUMPTION (UIGATHER): only ROLL gets a desktop key cap; the canvas's 1/2/4 caps have no
		# handler behind them (tactic_1..4 are bound but nothing reads them), so they would lie.
		h.key_hint = "Q" if s[0] == "roll" else ""
		h.visible = false
		h.pressed.connect(_on_skill.bind(StringName(s[0])))
		add_child(h)
		_skill_hexes.append(h)
	_auto_hex = HexButton.new(64.0)
	_auto_hex.icon = UiIcons.icon(&"auto")
	_auto_hex.caption = "AUTO"
	_combat_style(_auto_hex)
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
	_combat_style(_feed_hex)
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
	_combat_style(_chase_hex)
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
	_swords_hex = TargetSwordsHex.new()
	_swords_hex.player = player
	add_child(_swords_hex)
	move_child(_swords_hex, 0)  # under every HUD control: where they meet, the HUD's tap wins

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
	var dsb := StyleBoxFlat.new()  # B4 death card: HUD fill, a LIFE top edge, a GOLD respawn button
	dsb.bg_color = Color(UiTokens.HUD_FILL, 1.0)
	dsb.border_color = UiTokens.LIFE
	dsb.border_width_top = 4
	_death_card.add_theme_stylebox_override("panel", dsb)
	_death_panel.add_child(_death_card)
	_death_title = Label.new()
	_death_title.name = "DeathTitle"
	_death_title.text = "YOU DIED"
	_death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_title.add_theme_color_override("font_color", UiTokens.LIFE)
	_death_title.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
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
	var gold := StyleBoxFlat.new()
	gold.bg_color = UiTokens.GOLD
	for st in ["normal", "hover", "pressed", "focus"]:
		_death_btn.add_theme_stylebox_override(st, gold)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_death_btn.add_theme_color_override(st, UiTokens.CTA_INK)
	_death_btn.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	_death_btn.pressed.connect(func () -> void:
		if player:
			player.respawn()
	)
	_death_card.add_child(_death_btn)

const DEATH_FADE_IN := 2.0

## The survivor's "HP / max" text. Rounded up, so 0 only ever means dead: "%.0f" showed a 0.4 HP survivor
## as "0 / 100" and she fought on at a seeming 0 (owner: "still alive at 0 health for a while").
static func hp_label(v: Vitals) -> String:
	return "%d / %d" % [ceili(v.health), ceili(v.effective_max_health())]

func _tick_death(delta: float) -> void:
	var dead := player != null and player.dead
	# EYESDEATH: full in 0.5 s (was 1.25 s at 0.8/s; the faint first second read as "alive at 0").
	_death_alpha = move_toward(_death_alpha, 1.0 if dead else 0.0, delta * (DEATH_FADE_IN if dead else 4.0))
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

## B2 hex restyle (spec §2/§3): HUD fill, light 3-4 px rim, gold when selected.
static func _combat_style(h: HexButton) -> void:
	h.rim_color = UiTokens.HUD_RIM
	h.rim_width = 4.0 if h.size.x >= 70.0 else 3.0
	h.fill = UiTokens.HUD_FILL

## Spec §7 B2 / spec 09: the NET hex turns GOLD-filled (dark net, GOLD rim) while a throw is allowed —
## the target is stunned or at or under 30 % and a net and technique cover its tier (the hex is enabled).
## TAMINGODDS: the hex's bottom_text is left free for a capture-odds figure.
static func _net_gold(h: HexButton, on: bool) -> void:
	h.fill = UiTokens.GOLD if on else UiTokens.HUD_FILL
	h.rim_color = UiTokens.GOLD if on else UiTokens.HUD_RIM
	h.glyph_color = UiTokens.CTA_INK if on else Color.WHITE

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
	# UICRAFT (spec §7 D2, owner §1.9): ROTATE is the icon alone, SAVE a green check, CANCEL a red cross;
	# the word sits inside the hex, no key letters.
	var specs := [["↻", "rotate", "", Color.WHITE], ["✓", "confirm", "SAVE", UiTokens.OK_GREEN], ["✕", "cancel", "CANCEL", UiTokens.LIFE]]
	for sp in specs:
		var h := HexButton.new(PLACE_HEX)
		h.name = "Place_" + str(sp[1])
		h.glyph = sp[0]
		h.bottom_text = sp[2]
		h.glyph_color = sp[3]
		h.fill = UiTokens.HUD_FILL
		h.rim_color = UiTokens.OK_GREEN if sp[1] == "confirm" else UiTokens.HUD_RIM
		h.rim_width = 4.0
		h.bottom_scale = 0.27
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

## CombatAvoid: "Dodged" / "Blocked" rises over her where a damage number would, smaller and grey.
func avoid_on_player(text: String) -> void:
	_events.add_float(text, CombatAvoid.COLOR, 0.0, CombatAvoid.PX)

func _draw_bites(cam: Camera3D) -> void:
	if cam == null or player == null:
		return
	var chest := cam.unproject_position(player.get_global_transform_interpolated().origin + Vector3(0, 0.95, 0))
	for f in _events.player_floats:
		var k: float = f["t"]
		var a := 1.0 - smoothstep(0.55, 0.95, k)
		var txt: String = str(f["txt"]) if f.has("txt") else "-%d" % int(round(float(f["n"])))
		var col: Color = f.get("col", Color(1.0, 0.25, 0.2))
		var fs := int(f.get("px", 22))
		if f.get("pop", false):
			fs = roundi(float(fs) * lerpf(0.7, 1.0, smoothstep(0.0, 0.15, k)))
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var p := chest + Vector2(float(f["x"]) - w * 0.5, -30.0 - k * 46.0 + float(f.get("dy", 0.0)))
		draw_string(_font, p + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8 * a))
		draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
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

## tint: a rare result (gold find, green trait), drawn in its colour on ink instead of the red refusal
## box; GatherFeedback sets how long it lives (W2-GATHER).
func notice(text: String, tint: Color = Color(0, 0, 0, 0)) -> void:
	if tint.a > 0.0:
		GatherFeedback.add_notice(_events.notices, text, tint, player)  # W2-GATHER: a repeat counts up ("x2")
		return
	_events.add_notice(text)

func toast(id: StringName, n: int) -> void:
	print("[ui] toast %s +%d" % [id, n])
	_events.add_toast(id, n)
	top_feed.push_gain(player, id, n)

## A rare result (GatherFeedback: a find, a rare carcass part): its TopFeed row goes green.
func feed_rare(id: StringName, where: String = "") -> void:
	top_feed.push_rare(id, where)

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
	# INTERACT already shows (and runs) one of them: no second hex for the same thing.
	actions = actions.filter(func (a: Dictionary) -> bool: return str(a["id"]) != field.choice_id)
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
	var compact := UiTokens.is_compact(r)
	# The row runs right to left from SPRINT along the bottom line; past the rail it wraps one row up,
	# where on the left it stops short of the quick slots.
	var right := field.sprint_hex.position.x - 8.0
	var left := _bag_hex.position.x + _bag_hex.size.x + 12.0
	var row_y := r.y - UiTokens.xp_line_zone(r).size.y - CAPTION_H - 70.0 - inset.y  # captions clear the XP line
	if UiTokens.is_narrow(r):  # portrait: the row above the quick slots, from the left
		right = r.x - 16.0 - inset.x - field.interact_hex.size.x - 8.0
		row_y = quick_row_y() - CAPTION_H - 12.0 - 70.0
		left = 16.0 + inset.w
	var x := right - 70.0
	for a in actions:
		var h := HexButton.new(70.0)
		var id := str(a["id"])
		h.glyph = str(a.get("glyph", ""))
		h.icon = UiIcons.icon(StringName(id)) if UiIcons.path_for(StringName(id)) != "" else null
		h.caption = str(a["label"]).to_upper()
		h.bottom_text = str(a.get("uses", ""))
		h.rim_color = UiTokens.HUD_RIM
		if h.glyph == "" and h.icon == null:
			h.glyph = h.caption
			h.caption = ""
		h.name = "Ctx_" + id  # TUTORIAL ISLAND: the onboarding pointer finds a context action by name
		h.pressed.connect(_on_context.bind(id))
		add_child(h)
		if id == "claim":
			# Spec §6: a small gold-rim CLAIM hex by the minimap. HUDTWEAK (owner 2026-10-28): "Move claim to
			# above the day/night UI": centred over the dial's face, clear of the "X n  Y n" line under the
			# map. Portrait: under the quest card.
			var cp := HudField.px(&"claim", r)
			HudField.fit(h, cp)
			h.rim_color = Color(UiTokens.GOLD, 0.8)
			h.rim_width = 3.0
			# ASSUMPTION: on a landscape phone the 60 px between the map text and INTERACT takes the hex but
			# not a caption; it stays icon-only there.
			if compact and not UiTokens.is_narrow(r):
				h.caption = ""
			if UiTokens.is_narrow(r):
				h.position = Vector2(_minimap.position.x + MAP_PX - cp, _minimap.position.y + MAP_PX + 52.0 + 72.0 + 8.0)
			else:
				var face := _daynight.face_rect()
				var cap := CAPTION_H if h.caption != "" else 0.0  # the caption hangs under the hex, above the dial
				h.position = Vector2(face.get_center().x - cp * 0.5, face.position.y - cp - cap - 4.0)
			_claim_hex = h
		else:
			if x < left:  # wrap: one row up, from the right again, clear of the quick slots
				row_y -= 70.0 + CAPTION_H + 8.0
				x = right - 70.0
				left = _chase_hex.position.x + _chase_hex.size.x + 12.0
			h.position = Vector2(x, row_y)
			x -= 78.0
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
	var px := 64.0 if UiTokens.is_compact(get_viewport_rect().size) else PLACE_HEX
	var offs: Array = PLACE_OFFSETS.map(func (o: Vector2) -> Vector2: return o * (px / 64.0))
	for h in _place_hexes:
		if h.size.x != px:
			h.custom_minimum_size = Vector2(px, px)
			h.size = Vector2(px, px)
			h.pivot_offset = h.size * 0.5
	var base := HudLayout.placer_anchor(cam.unproject_position(ghost.global_position) + Vector2(0, 40), offs, _placer_rel(), _placer_taken(), get_viewport_rect().size, _safe_insets())
	for i in _place_hexes.size():
		_place_hexes[i].position = base + (offs[i] as Vector2)

## Offsets for 64 px hexes; a desktop canvas scales them to PLACE_HEX.
const PLACE_OFFSETS := [Vector2(-105, 0), Vector2(-22, 28), Vector2(60, 0)]
const PLACE_HEX := 88.0

## What each placer hex draws relative to its own corner (its hexagon, then its caption box), from the
## hexes themselves: the row is placed with the same geometry the check and the drawing use.
func _placer_rel() -> Array:
	var out: Array = []
	for h in _place_hexes:
		var hb := h as HexButton
		var at := hb.position
		var hex := hb.hex_rect()
		var cap := hb.caption_rect() if hb.caption != "" else hex  # SAVE / CANCEL write inside the hex
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
		if ctl == null or ctl is HexButton or not ctl.is_visible_in_tree() or ctl.size.x < 8.0 or ctl.size.y < 8.0:
			continue
		if ctl is Label and (ctl as Label).text.strip_edges() == "":
			continue
		out.append(ctl.get_global_rect())
	if player and player.build_ui and is_instance_valid(player.build_ui) and (player.build_ui as BuildUI).visible:
		out.append_array((player.build_ui as BuildUI).taken_rects())  # the build drawer stays open beside the ghost
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
	_levelup_lines.append(["Gold %d" % World.t_stones, 18, Color.WHITE])
	# W2-SKILLS: character levels pay the SP (spec 03); show what SkillState holds (sp_now recounts,
	# since its own handler on this signal may not have run yet).
	var sp: int = player.skills.sp_now() if player and player.skills else 0
	var sp_gain: int = player.skills.sp_for_level(level) if player and player.skills else 0
	# Skill points are the brain glyph, never words (owner, BRAINICON): a 4th entry names the icon drawn before the text.
	_levelup_lines.append(["%d%s" % [maxi(0, sp), "  (+%d)" % sp_gain if sp_gain > 0 else ""], 18, Color.WHITE, &"brain"])
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
	_levelup_summary = "%s +%d · other stats +%d ·" % [top_stat, bonus, gain]
	_levelup_sp = str(maxi(0, sp))  # drawn after the summary behind the brain glyph
	_levelups.push_character(level, _levelup_lines, _levelup_title, _levelup_summary, _levelup_sp)

# ---------------------------------------------------------------- sheets

func _toggle_sheet(kind: StringName) -> void:
	if _sheet and _sheet_kind == kind:
		_close_sheet()
		return
	_close_sheet()
	_sheet_kind = kind
	if kind == &"menu":  # B3 nav menu (nav_menu.gd): two columns over the live world
		_sheet = NavMenu.new(self)
		add_child(_sheet)
		return
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
	if player and player.build_ui and is_instance_valid(player.build_ui):
		(player.build_ui as BuildUI).hide_ui()  # the card opens where the build drawer sits
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

## True while one of the HUD's sheets is open. The creature plates sit on canvas layers above the
## HUD's and hide meanwhile.
func sheet_open() -> bool:
	return _sheet != null or (_skills_sheet != null and _skills_sheet.visible) or (_orders_sheet != null and _orders_sheet.visible)

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
		field.clear(&"skills")  # the MENU badge's skill notices are read

# ---------------------------------------------------------------- UICHAR entry points (nav menu B3)

var _orders_sheet: OrdersSheet

## C1 Character (character_sheet.gd, hosted by the bag's InventoryUI). ‹ comes back to the MENU.
func open_character() -> void:
	_close_sheet()
	if player == null or player.ui == null:
		return
	if not player.ui.menu_requested.is_connected(_back_to_menu):
		player.ui.menu_requested.connect(_back_to_menu)
	player.ui.open_character()

## C3 Skills (skills_sheet.gd), on `tree` or the last skill shown. ‹ comes back to the MENU.
func open_skills(tree: String = "") -> void:
	_close_sheet()
	if player == null or player.skills == null:
		return
	if _skills_sheet == null or not _skills_sheet.visible:
		_toggle_skills(tree)
	elif tree != "":
		_skills_sheet.open(player.skills, tree)
	if not _skills_sheet.back_requested.is_connected(_back_to_menu):
		_skills_sheet.back_requested.connect(_back_to_menu)

## C4 Orders (orders_sheet.gd); "Track on HUD" points the quest card here. ‹ comes back to the MENU.
func open_orders() -> void:
	_close_sheet()
	if _orders_sheet == null:
		_orders_sheet = OrdersSheet.new()
		_orders_sheet.name = "OrdersSheet"
		add_child(_orders_sheet)
		_orders_sheet.back_requested.connect(_back_to_menu)
	_orders_sheet.open(player)

## The nav menu, for screens whose ‹ returns to it (UIANIMALS calls this when it exists).
func open_menu() -> void:
	_back_to_menu()

func _back_to_menu() -> void:
	if _sheet_kind != &"menu":
		_toggle_sheet(&"menu")

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

## F2 World Atlas for the nav menu: opens it (open_map toggles).
func open_atlas() -> void:
	if _map_screen == null or not _map_screen.is_open():
		_open_map()

## UIMARKET: the Island Market on its own layer (tab: buy | my_market | sell); its ‹ comes back to MENU.
func open_market(tab: StringName = &"buy") -> MarketScreen:
	var s := MarketScreen.open_for(self, tab)
	if not s.back_pressed.is_connected(_market_back):
		s.back_pressed.connect(_market_back)
	return s

func _market_back() -> void:
	_toggle_sheet(&"menu")

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

# ---------------------------------------------------------------- UIWORLD screens (nav menu entry points)

var _world_sheets: Dictionary = {}  ## StringName -> UiWorldSheet, made on first open

## The sheet `key`, made once with `make`, on its own canvas layer at the Domain screen's depth.
func _world_sheet(key: StringName, make: Callable) -> UiWorldSheet:
	var s: UiWorldSheet = _world_sheets.get(key)
	if s != null and is_instance_valid(s):
		return s
	var layer := get_node_or_null("WorldSheetLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "WorldSheetLayer"
		layer.layer = 96
		add_child(layer)
	s = make.call()
	layer.add_child(s)
	s.back_pressed.connect(_back_to_menu)  # ‹ returns to the nav menu (§8)
	_world_sheets[key] = s
	return s

## F1: open the Domain screen (never toggles it shut, unlike the old menu path).
func open_domain() -> DomainScreen:
	_close_sheet()
	if _domain_screen == null or not _domain_screen.is_open():
		_open_domain()
	return _domain_screen

## F3: the Communication screen (factions, trust, offers).
func open_comms() -> CommsUI:
	_close_sheet()
	var s := _world_sheet(&"comms", func () -> UiWorldSheet: return CommsUI.new()) as CommsUI
	s.open(player)
	return s

## F3: Radio University (career guides), its own screen; Back returns to Communication.
func open_radio_university() -> RadioUniversityUI:
	var comms := open_comms()
	comms.open_radio()
	return comms.radio

## E2: the Taming Pen screen for `pen` (PlayerActions.pen_interact calls this; null = bag only).
func open_taming_pen(pen: TamingPen = null) -> TamingPenUI:
	_close_sheet()
	var s := _world_sheet(&"pen", func () -> UiWorldSheet: return TamingPenUI.new()) as TamingPenUI
	s.open(player, pen)
	return s

## FIREFUEL: a fire's fuel sheet (StationMenu's FUEL hex calls this).
func open_fire_fuel(fire: Bonfire, who: Player = null) -> FireFuelSheet:
	_close_sheet()
	var s := _world_sheet(&"fire_fuel", func () -> UiWorldSheet: return FireFuelSheet.new()) as FireFuelSheet
	s.open(who if who != null else player, fire)
	return s

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
	if not sheet_open() and _orders_press(event):  # HUDRULES: the orders badge / card collapse toggle
		if player.controls:
			player.controls._desktop_click_fallback_pending = false
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if not sheet_open() and _status_fx.input(event):  # a press on a status box pins its tooltip
		if player.controls:
			player.controls._desktop_click_fallback_pending = false
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if not sheet_open() and _buff_row.input(event):  # HUDRULES: chip hover / click / tap toggles its tooltip
		if player.controls:
			player.controls._desktop_click_fallback_pending = false  # the chip took it: no world tap behind
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pill := HudPills.node_at(event.position)  # UIGATHER: a harvest pill is tappable like its node
		if pill and not sheet_open() and not player.controls.tap_blocked():
			player.controls._desktop_click_fallback_pending = false  # the pill took it: no world tap behind
			player._interact_tap_target(pill)
			get_viewport().set_input_as_handled()
			return
		if _fatigue_rect.has_point(event.position):
			_fatigue_panel.player = player
			_fatigue_panel.toggle()
			queue_redraw()
			get_viewport().set_input_as_handled()

## A tap (touch) or a real click on the orders badge or card toggles it; the mouse press a touch also
## sends is swallowed without toggling back.
func _orders_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch and event.pressed and _orders_toggle_at(event.position):
		orders_tap()
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _orders_toggle_at(event.position):
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			orders_tap()
		return true
	return false

func _process(delta: float) -> void:
	if player == null:
		return
	if World.objective != _orders_seen:  # HUDRULES: a finished order flashes the collapsed badge
		_orders_flash = HudOrdersBadge.FLASH_S if _orders_seen >= 0 and World.objective > _orders_seen else 0.0
		_orders_seen = World.objective
	_orders_flash = maxf(0.0, _orders_flash - delta)
	_tick_orders_auto(delta)
	_tick_death(delta)
	# Exhaustion drift sampling (ExhaustTreadmill): sleep/meals arrive as one-off steps, work and
	# climate as a steady creep; the EMA over fatigue deltas drives the belt's direction and speed.
	if not player.dead and player.vitals != null:
		var vf := player.vitals.fatigue
		if _fat_prev > -1.0e8:
			if absf(vf - _fat_prev) >= ExhaustTreadmill.STEP_AFTER:
				_fat_forgive = ExhaustTreadmill.FORGET_HOLD_S
			var instant := (vf - _fat_prev) / maxf(delta, 1.0 / 240.0)
			if player.vitals.blocks_fatigue_gain:  # Well Rested: the treadmill pauses
				_fat_rate = ExhaustTreadmill.paused_rate(_fat_rate, instant, delta)
			else:
				_fat_rate = ExhaustTreadmill.sample_rate(_fat_rate, instant, delta, _fat_forgive)
		_fat_prev = vf
		_fat_forgive = maxf(0.0, _fat_forgive - delta)
		_belt_phase = ExhaustTreadmill.phase(_belt_phase, _fat_rate, delta)
		ExhaustTreadmill.tick(delta, clampf(vf / maxf(1.0, player.vitals.max_fatigue), 0.0, 1.0), player.vitals.blocks_fatigue_gain)
		if _fatigue_panel != null:
			_fatigue_panel.rate = _fat_rate
	var hunting := player.hunt != null and player.hunt.target != null and is_instance_valid(player.hunt.target)
	field.tick(delta)
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
		_skill_hexes[0].disabled = player.inventory.count_of(weapon.def().ammo_id) <= 0 if ranged else not (player.hunt._net_health_ok() and player.hunt._best_net_ok())
		if siege:
			_skill_hexes[0].caption = "SIEGE %d" % player.inventory.count_of(&"stone_shot")
			_skill_hexes[0].icon = UiIcons.icon(&"siege")
			_skill_hexes[0].disabled = catapult.reload_left > 0 or player.inventory.count_of(&"stone_shot") == 0
		_net_gold(_skill_hexes[0], not ranged and not siege and not _skill_hexes[0].disabled)
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
	_levelups.tick(delta, self)
	if _levelups.menu_pulse() > 0.0 and _sheet is NavMenu:
		(_sheet as NavMenu).root.queue_redraw()  # the Skills entry's badge pulses
	GatherFeedback.tick_notices(_events.notices, player, drawn_blocks)  # W2-GATHER: rare notice life, off _draw
	_events.tick(delta)
	top_feed.tick(delta)
	_rest_fx.tick(player, _events, delta)
	_status_fx.tick(player, _events, delta)  # STATUSFX: boxes' slots, the emitters on her, tick numbers  # REST: recovery floats over her while she rests or sleeps
	_pulse_check -= delta
	if _pulse_check <= 0.0:
		_pulse_check = SKILL_PULSE_TICK
		_refresh_skill_pulse()
	_domain.tick(delta, World.runtime, player.global_position)
	_minimap.queue_redraw()
	queue_redraw()

## The bottom level bar: a track, the green fill, and a gap after every `unit` XP of the level's
## `cost` (the last segment is what is left over, so widths stay proportional to XP).
func _draw_xp_bar(rect: Rect2, xp: int, cost: int, unit: int) -> void:
	draw_rect(rect, Color(0.05, 0.05, 0.07, 0.9))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(float(xp) / maxf(1.0, cost), 0.0, 1.0), rect.size.y)), UiTokens.XP_GREEN)
	var step := rect.size.x * float(unit) / maxf(1.0, cost)
	var gap_x := rect.position.x + step
	while gap_x < rect.end.x - 1.0:
		draw_rect(Rect2(gap_x - 1.0, rect.position.y, 2.0, rect.size.y), Color(0.02, 0.02, 0.03, 0.95))
		gap_x += step

func _draw() -> void:
	if player == null or player.dead:
		return
	var r := get_viewport_rect().size
	drawn_blocks.clear()
	_status_fx.draw_vignette(self, player, r)  # STATUSFX: under everything the HUD draws
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
	# LEVELBADGE (owner 2026-10-28): the level badge is back at the left, its ring richer toward Lv 60; the bars follow it.
	var full_w := panel_w - HudLevelBadge.COLUMN - 24.0 if UiTokens.is_compact(r) or phone else 276.0
	var big := 16.0 if not phone else 12.0
	var gap := 6.0
	# Owner 2026-10-28: the stomach ring moved down to lead the buff row, so the bars take the full width.
	var bar_w := full_w
	var num_px := UiTokens.body(r) - 1 if not phone else 12
	var bar_px := UiTokens.meta(r) if not phone else 12
	# LEVELBADGE (owner): no dark box behind the vitals; each piece carries its own rim and shadow.
	drawn_blocks["vitals"] = vitals
	var badge_c := HudLayout.badge_centre(self, r)
	_badge_centre_drawn = badge_c
	level_badge_rect = HudLevelBadge.draw(self, badge_c, HudLevelBadge.R, LevelDisplay.player_level(), Time.get_ticks_msec() * 0.001, _font)
	level_badge_tier = HudLevelBadge.tier_of(LevelDisplay.player_level())
	_levelups.draw_pulse_rings(self, badge_c, HudLevelBadge.R)  # LEVELFX: gold rings out of the badge on a level-up
	x += HudLevelBadge.COLUMN
	var yy := y
	hp_bar_rect = Rect2(Vector2(x, yy), Vector2(bar_w, big))
	_bar(Vector2(x, yy), Vector2(bar_w, big), v.health / maxf(1.0, v.effective_max_health()), Color(0.78, 0.13, 0.13), "", hp_label(v), num_px, 0, &"hp")
	yy += big + gap
	var en := energy_reading(player)
	var en_text := "%.0f / %.0f" % [en.value, en.max]
	# The mount's name leads the numbers when it fits (a phone bar may only fit the numbers; amber still says "mount").
	if en.name != "" and _font.get_string_size("%s  %s" % [en.name, en_text], HORIZONTAL_ALIGNMENT_LEFT, -1, num_px).x <= bar_w - 12.0:
		en_text = "%s  %s" % [en.name, en_text]
	# Owner 2026-10-28: riding, the bar is the mount's, segmented and a darker blue (UiTokens.MOUNT_ENERGY).
	energy_bar_color = UiTokens.MOUNT_ENERGY if en.name != "" else UiTokens.PLAYER_ENERGY
	energy_bar_segments = UiTokens.MOUNT_ENERGY_SEGMENTS if en.name != "" else 0
	_bar(Vector2(x, yy), Vector2(bar_w, big), en.value / maxf(1.0, en.max), energy_bar_color, "", en_text, num_px, energy_bar_segments, StringName("en:" + en.name))
	yy += big + gap
	stomach_fill = HudStomach.fullness_of(player)
	stomach_saturation = HudStomach.saturation_of(player)
	stomach_state = HudStomach.state_of(stomach_fill)
	stomach_glyph_scale = move_toward(stomach_glyph_scale, float(HudStomach.GLYPH_SCALE[stomach_state]), get_process_delta_time() * HudStomach.SCALE_SPEED)
	var strain: float = clampf(v.fatigue / maxf(1.0, v.max_fatigue), 0.0, 1.0)
	var face_col := Color(0.42, 0.78, 0.53).lerp(Color(0.96, 0.42, 0.36), strain)
	# Owner 2026-10-27: this row is a treadmill — the tread chevrons point and scroll right while
	# exhaustion rises (work, climate, wet) and left while it eases (sleep, meals); scroll speed
	# carries how fast it is changing. The drift is sampled in _process. HUDTWEAK (owner 2026-10-28):
	# no tier word; the belt sits right under the energy bar and the face sticker says the tier.
	var belt := Rect2(Vector2(x, yy), Vector2(full_w, ExhaustTreadmill.BELT_H))
	draw_rect(Rect2(belt.position + Vector2(0, 2), belt.size), Color(0, 0, 0, 0.35))  # drop shadow, no panel behind
	ExhaustTreadmill.draw_belt(self, belt, _fat_rate, _belt_phase, strain, face_col, _font, bar_px)
	# Owner 2026-10-28: the face rides the belt like a sticker, at the strain marker.
	var sticker := Vector2(clampf(ExhaustTreadmill.marker_rect.get_center().x, belt.position.x + 11.0, belt.end.x - 11.0), belt.get_center().y)
	_draw_exhaustion_face(sticker, strain)
	exhaust_sticker_rect = Rect2(sticker - Vector2(12, 12), Vector2(24, 24))
	_fatigue_rect = Rect2(x, belt.get_center().y - UiTokens.TARGET_MIN * 0.5, full_w, maxf(UiTokens.TARGET_MIN, ExhaustTreadmill.BELT_H))
	if _fatigue_panel and _fatigue_panel.visible:
		_fatigue_panel.position = Vector2(_fatigue_rect.position.x, _fatigue_rect.end.y + 8.0)
	# Player conditions belong with the player's vitals, directly beneath the top-left panel. On a
	# landscape phone with pet commands visible, keep the row after those commands so they do not
	# occupy the same strip; both remain within the wide compact vitals block.
	# HUDTWEAK (owner 2026-10-28): the chip row starts at the health bar's left edge; the stomach ring is
	# the badge's size, centred under it. A landscape phone's whistle row takes the same strip, so the chips drop under it.
	var sx := hp_bar_rect.position.x
	var sy := vitals.end.y + 8.0
	if HudLayout.landscape_phone(r) and _whistle_hexes[0].visible:
		sy = _whistle_hexes[0].position.y + _whistle_hexes[0].size.y + 6.0
	var sc := HudLayout.stomach_circle(self, r)
	stomach_rect = HudStomach.draw(self, Vector2(sc.x, sc.y), sc.z, stomach_fill, stomach_saturation, stomach_glyph_scale)
	drawn_blocks["stomach"] = stomach_rect  # tooltips and notices place around it
	if player.statuses:
		var sx0 := sx
		var rest_lines := player.sim.rest.hud_lines() if player.sim else PackedStringArray()
		if not rest_lines.is_empty():  # REST: the Resting chip comes first while she rests or sleeps
			HudBuffRow.draw_chip(self, _font, Rect2(Vector2(sx, sy), Vector2(HudBuffRow.CHIP, HudBuffRow.CHIP)), &"resting", &"")
			sx += HudBuffRow.PITCH
		# HUDRULES: only buffs, boons and debuffs here; afflictions are StatusFx's boxes beside her.
		var row := _buff_row.draw(self, _font, Vector2(sx, sy), player, r)
		if row.has_area():
			sx = row.end.x + 4.0
		if sx > sx0:
			drawn_blocks["statuses"] = Rect2(sx0, sy, sx - sx0 - (HudBuffRow.PITCH - HudBuffRow.CHIP), HudBuffRow.ROW_H)
		# SAVEFIX: a status that lowers max HP says so under its chip (the number alone was a mystery).
		var hp_note: String = player.statuses.max_health_note()
		var rest_y := sy + HudBuffRow.ROW_H + 2.0
		if hp_note != "":
			var ny := sy + HudBuffRow.ROW_H + 2.0
			var nw := _font.get_string_size(hp_note, HORIZONTAL_ALIGNMENT_LEFT, -1, bar_px).x
			draw_string(_font, Vector2(sx0, ny), hp_note, HORIZONTAL_ALIGNMENT_LEFT, -1, bar_px, Color(0.96, 0.62, 0.42))
			drawn_blocks["status_maxhp"] = Rect2(sx0, ny - bar_px, nw, bar_px + 4.0)
			rest_y = ny + 8.0
		if not rest_lines.is_empty():  # REST: its live rates in a box right under the chips (and the max-HP note)
			drawn_blocks["rest"] = HudRestBox.draw(self, _font, Vector2(sx0, rest_y), UiTokens.body(r), rest_lines)
	var mp := _minimap.position
	var top := "Home" if World.is_home() else ("Tutorial Island" if World.is_tutorial() else "Survivable %d min" % int(ceil(World.remaining_lifetime / 60.0)))
	if World.island_id == &"":
		top = "Lab"
	var meta_px := UiTokens.meta(r)
	var top_s := UiTokens.ellipsis(_font, top, MAP_PX, meta_px)
	draw_string_outline(_font, Vector2(mp.x, mp.y - 16.0), top_s, HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, meta_px, 3, Color(0, 0, 0, 0.75))
	draw_string(_font, Vector2(mp.x, mp.y - 16.0), top_s, HORIZONTAL_ALIGNMENT_LEFT, MAP_PX, meta_px, Color.WHITE)
	drawn_blocks["map_title"] = Rect2(mp.x, mp.y - 16.0 - meta_px, MAP_PX, meta_px + 4.0)
	# Owner 2026-10-28: "X 503 Y 295" centred under the map, her world X / Z in whole metres.
	var xy := Vector2i(roundi(player.global_position.x), roundi(player.global_position.z))
	if xy != _map_xy:  # format only when a metre changes
		_map_xy = xy
		map_xy_text = "X %d  Y %d" % [xy.x, xy.y]
	var xy_pos := Vector2(mp.x, mp.y + MAP_PX + 16)
	draw_string_outline(_font, xy_pos, map_xy_text, HORIZONTAL_ALIGNMENT_CENTER, MAP_PX, meta_px, 3, Color(0, 0, 0, 0.75))
	draw_string(_font, xy_pos, map_xy_text, HORIZONTAL_ALIGNMENT_CENTER, MAP_PX, meta_px, Color(0.92, 0.94, 0.96))
	# The clock and phase line moved into the day/night dial's label: the dial shows the phase already.
	drawn_blocks["map_text"] = Rect2(mp.x, mp.y + MAP_PX + 16.0 - meta_px, MAP_PX, meta_px + 4.0)
	# The target plate (current hunt target, else on desktop the selection, else the last creature attacked while it lives) and
	# the level-up banner take over the landscape phone's centre band from the quest card while they show.
	var band := HudLayout.centre_band(self, r)
	var plate_t: Creature = player.hunt.target if (player.hunt and player.hunt.target and is_instance_valid(player.hunt.target)) else null
	if plate_t == null and not band.has_area():
		plate_t = player.controls.selection.current()  # a tap selects: its plate shows before any fight (a phone keeps the quest card)
	if plate_t == null and _last_target and is_instance_valid(_last_target) and not _last_target.health.dead and player.global_position.distance_to(_last_target.global_position) < 40.0:
		plate_t = _last_target
	# HUDRULES (owner 2026-10-28): in combat the card hides unless the fight serves the shown order.
	# Collapsed (the default, OrdersSheet.hud_expanded) it is a badge in the minimap's corner.
	var fight_order := _in_combat and quest_served_by_fight()
	orders_badge_rect = Rect2()
	if not _in_combat or fight_order:
		if orders_expanded() and (not band.has_area() or (plate_t == null and not _levelups.hides_quest(band, quest_rect(r, mp)))):
			_draw_quest(r, mp)
		elif not (orders_expanded() and fight_order and _draw_quest_strip(r)):
			_draw_orders_badge(mp, meta_px)  # collapsed, or the phone band is taken and no strip fits
	# --- XP bar along the bottom
	# One bar: the pioneer level, which every skill XP grant also feeds.
	# LEVELBAR (owner 2026-10-28): one segment per unit of XP, so a dearer level draws more, thinner ones.
	var xb := LevelDisplay.xp_bar()
	xp_bar_rect = Rect2(0, r.y - UiTokens.XP_BAR_H, r.x, UiTokens.XP_BAR_H)
	xp_bar_segments = int(xb["segments"])
	_draw_xp_bar(xp_bar_rect, int(xb["xp"]), int(xb["cost"]), int(xb["unit"]))
	_levelups.draw_bar_pulse(self, xp_bar_rect)
	var lv := "%s  %d / %d XP  · %d XP each" % [LevelDisplay.player_label(), int(xb["xp"]), int(xb["cost"]), int(xb["unit"])]
	var lw := _font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
	var lv_pos := Vector2(r.x - lw - 16.0 - inset.x, r.y - HEX - 22.0) if phone else Vector2(r.x * 0.5 - lw * 0.5, r.y - UiTokens.XP_BAR_H - 5.0)
	draw_string_outline(_font, lv_pos, lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0.0, 0.0, 0.0, 0.7))
	draw_string(_font, lv_pos, lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	drawn_blocks["level"] = Rect2(lv_pos - Vector2(0.0, 12.0), Vector2(lw, 15.0))
	# --- name under the survivor
	var cam := get_viewport().get_camera_3d()
	# Not under the pet radial: its see-through centre shows the pet, and the ring cut the name in two.
	if cam and not (player.pets.menu and player.pets.menu.visible):
		drawn_blocks["nameplate"] = HudLayout.nameplate_rect(cam, player, _font)
		HudLayout.draw_nameplate(self, _font, drawn_blocks["nameplate"], player)
	_status_fx.draw_tint(self, player, HudLayout.figure_rect(self))
	_draw_bites(cam)
	# --- level-up: a gold stack top-left under the bars; on a landscape phone a short banner in the
	# centre band (its 13 lines ran over the rail and off the bottom of a 390 px canvas)
	if plate_t:
		_draw_target_plate(plate_t, maxf(_combat_alpha, 0.85), band)
	var levelup := _levelups.draw(self, band, drawn_blocks.get("plate", Rect2()) if plate_t else Rect2(), drawn_blocks.get("quest", Rect2()))
	if levelup.has_area():
		drawn_blocks["levelup"] = levelup
	_levelups.draw_menu_pulse(self, _menu_hex)  # LEVELFX: the MENU hex pulses with a level-up's new notice
	# --- the domain banner, before the moving text so it keeps off the banner
	_domain.draw(self)
	# --- STATUSFX: the status boxes beside her, before the moving text so toasts keep off them
	var sfx := _status_fx.draw_boxes(self, _font, player, HudLayout.figure_rect(self), taken_rects(), r)
	if sfx.has_area():
		drawn_blocks["statusfx"] = sfx
	var sfx_tip := _status_fx.draw_tip(self, _font, taken_rects(), r)  # the status box's tooltip
	if sfx_tip.has_area():
		drawn_blocks["statusfx_tip"] = sfx_tip
	# HUDRULES: the open chip tooltip, before the moving text so the feed and the toasts keep off it
	var tip := _buff_row.draw_tooltip(self, _font, taken_rects(), r)
	if tip.has_area():
		drawn_blocks["buff_tip"] = tip
	# --- the left XP feed and the yield card, then the notices: each takes the nearest free spot off
	# every block and hex. One with no room left on screen is skipped.
	var taken := taken_rects()
	var cx := band.get_center().x if band.has_area() else r.x * 0.5  # a phone's free middle, off HANDS and the map
	# UIGATHER (spec §6, owner §1.6): skill XP lines are the left feed under the vitals; item gains are
	# the yield card above the node (YieldCard, spec §4.5) instead of the top-centre toast.
	drawn_blocks.merge(YieldCard.draw_feed(self, _font, _events.skill_toasts, Vector2(vitals.position.x, vitals.end.y + 8.0), taken, player.skills), true)
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
		var txt: String = UiTokens.ellipsis(_font, n["text"], r.x - 48.0 - HudEventState.NOTICE_GLYPH, 17)
		var tw := HudEventState.notice_width(_font, txt, 17, r) if not n.has("tint") else _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x + 24.0
		var cand := Rect2(cx - tw * 0.5, 170.0, tw, 30)
		# W2-GATHER: a rare (tinted) notice also keeps off the radial, plates and the survivor, and keeps its side
		var box := GatherFeedback.notice_box(n, player, cand, taken, r) if n.has("tint") else UiTokens.free_spot(cand, taken, r)
		if not box.has_area():
			continue
		taken.append(box)
		drawn_blocks["notice%d" % i] = box
		if n.has("tint"):
			var pu := GatherFeedback.notice_punch(n)  # lands big and bright, eases back
			var c := GatherFeedback.notice_colors(n["tint"], alpha, pu.y)
			draw_set_transform(box.get_center() * (1.0 - pu.x), 0.0, Vector2.ONE * pu.x)
			draw_rect(box, c[0])
			draw_rect(box, c[1], false, 2.0)
			draw_string(_font, box.position + Vector2(12, 21), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, c[2])
			draw_set_transform(Vector2.ZERO)
			continue
		HudEventState.draw_notice(self, _font, box, txt, 17, alpha, bool(n.get("ok", false)))  # B4 warning / ok row
	# --- the top-middle column (TopFeed): under the vitals' bottom on the desktop, under the centre
	# band (and a plate in it) on a phone; after the notices, so its rows ease around them, never they around it
	var feed_top := HudLayout.vitals_rect(self, r).end.y + 10.0
	if band.has_area():
		feed_top = maxf(band.end.y, (drawn_blocks.get("plate", Rect2()) as Rect2).end.y if plate_t else 0.0) + 8.0
	var feed_taken := taken + GatherFeedback.radial_rects(player)
	var fb := top_feed.draw(self, _font, TopFeed.column_cx(self, r), feed_top, feed_taken)
	for k in fb:
		taken.append(fb[k])
	drawn_blocks.merge(fb, true)
	# --- label pills on buildings and nodes within 8 m (reference: base building), last: they give way
	# to everything above and to the open radials
	if _combat_alpha > 0.01:
		_draw_capture_hint(cam, taken, _combat_alpha)  # before the pills, so they give way to it
		if drawn_blocks.has("capturehint"):
			taken.append(drawn_blocks["capturehint"])
	HudPills.draw(self, cam, taken)
	# --- combat layer
	if _combat_alpha > 0.01:
		var a := _combat_alpha
		draw_rect(Rect2(0, 0, r.x, 6), Color(0.85, 0.1, 0.1, 0.75 * a))
		draw_rect(Rect2(0, r.y - 6, r.x, 6), Color(0.85, 0.1, 0.1, 0.75 * a))

## B2: a gold line by the fought animal saying whether the net can go now (spec 09 window).
func _draw_capture_hint(cam: Camera3D, taken: Array[Rect2], a: float) -> void:
	var t: Creature = player.hunt.target if player.hunt else null
	if cam == null or t == null or not is_instance_valid(t) or t.def == null or not t.def.tameable or t.is_pet:
		return
	var at := t.global_position + Vector3.UP * 1.2
	if cam.is_position_behind(at):
		return
	var text := "Knocked out — throw the net!" if FieldTame.capture_window(t) else ("Sedate it: torpor %d%% / %d%%" % [int(round(100.0 * t.torpor_frac())), int(round(100.0 * FieldTame.torpor_ko_frac()))] if FieldTame.is_weak(t) else "Weaken to %d%% to capture" % int(round(FieldTame.CAPTURE_HEALTH_FRAC * 100.0)))
	var view := get_viewport_rect().size
	var px := UiTokens.body(view)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 16.0
	var sp := cam.unproject_position(at)
	var box := UiTokens.free_spot(Rect2(sp.x - w * 0.5, sp.y - float(px) - 18.0, w, float(px) + 10.0), taken + GatherFeedback.plate_rects(4.0), view, true)
	drawn_blocks.erase("capturehint")
	if not box.has_area():
		return
	drawn_blocks["capturehint"] = box
	draw_string(_font, Vector2(box.position.x + 9.0, box.end.y - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.7 * a))
	draw_string(_font, Vector2(box.position.x + 8.0, box.end.y - 7.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(UiTokens.GOLD, a))

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
			# NATURES (§11): the nature tag sits under the name; with one, the bar and every row below drop by dy.
			var nat := t.nature_id()
			var name_px := UiTokens.heading(r)
			# The name's Latin line box: the symbol fallbacks inflate _font's own ascent/descent, never this text's.
			var latin: Font = (_font as FontVariation).base_font if _font is FontVariation else _font
			var chip_y := py + 29.0 + latin.get_descent(name_px)  # 1 px under the name's line box
			var dy := maxf(0.0, chip_y + NatureChip.CHIP_H + CreaturePlates.CHIP_GAP - (py + 44.0)) if NatureChip.text_for(nat) != "" else 0.0
			var block := Rect2(px, py - 4.0, pw, 70.0 + dy)
			var nm := ("%s  [%s IV]" % [str(t.def.id).capitalize(), t.genetics.overall_tier() if t.genetics else &"?"]) if t.is_pet else str(t.def.id).capitalize()
			nm = UiTokens.ellipsis(_font, nm, pw - 150.0, name_px)
			draw_rect(Rect2(px, py - 4, pw, 48 + dy), Color(UiTokens.INK, 0.75 * a))  # the reference's dark band: the name reads on foliage
			draw_string(_font, Vector2(px + 12, py + 28), nm, HORIZONTAL_ALIGNMENT_LEFT, pw - 120.0, name_px, Color(1, 1, 1, a))
			var nmw := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
			var asc := latin.get_ascent(name_px)
			target_rows = {"name": Rect2(px + 12, py + 28 - asc, nmw, asc + latin.get_descent(name_px))}
			target_rows["chip"] = NatureChip.draw_at(self, _font, Vector2(px + 12, chip_y), nat, a)
			draw_string(_font, Vector2(px + 18 + nmw, py + 28), "Lv. %d" % t.level, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px, UiTokens.DANGER)
			draw_rect(Rect2(px + pw - 60, py - 4, 52, 52), Color(0.12, 0.12, 0.14, 0.9 * a))
			# ASSUMPTION: no per-species portrait art exists yet; the Animals head stands in for the reference's portrait.
			draw_texture_rect(UiIcons.icon(&"animals"), Rect2(px + pw - 54, py + 2, 40, 40), false, Color(1, 1, 1, a))
			var frac := clampf(t.health.hp / maxf(1.0, t.health.max_hp), 0.0, 1.0)
			py += dy  # everything below the tag
			target_rows["bar"] = Rect2(px, py + 44, pw, 22)
			draw_rect(Rect2(px, py + 44, pw, 22), Color(0.12, 0.05, 0.05, 0.9 * a))
			var window := FieldTame.capture_window(t)  # weak + torpor past the threshold: the bar turns GOLD
			draw_rect(Rect2(px, py + 44, pw * frac, 22), Color(UiTokens.GOLD, 0.95 * a) if window else Color(0.80, 0.12, 0.12, 0.95 * a))
			var hp := "%.0f / %.0f" % [t.health.hp, t.health.max_hp]
			var hw := _font.get_string_size(hp, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
			draw_string(_font, Vector2(px + pw * 0.5 - hw * 0.5, py + 61), hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, a))
			if not t.is_pet and t.torpor > 0.05:  # FOODTORPOR: violet torpor strip + the knock-out tick
				draw_rect(Rect2(px, py + 67, pw, 5), Color(0.06, 0.04, 0.12, 0.9 * a))
				draw_rect(Rect2(px, py + 67, pw * t.torpor_frac(), 5), Color(CreaturePlates.TORPOR_COLOR, 0.95 * a))
				draw_rect(Rect2(px + pw * FieldTame.torpor_ko_frac() - 1.0, py + 67, 2, 5), Color(1, 1, 1, 0.9 * a))
				target_rows["torpor"] = Rect2(px, py + 67, pw, 5)
			if t.brain is TyrantBrain:
				var label := (t.brain as TyrantBrain).opening_label()
				draw_rect(Rect2(px,py+108,pw,26),Color(0.1,0.1,0.12,0.9*a))
				draw_string(_font,Vector2(px+8,py+128),label,HORIZONTAL_ALIGNMENT_LEFT,pw-16,16,Color(1,0.85,0.2,a))
				block = block.merge(Rect2(px, py + 108.0, pw, 26.0))
			var ix := px
			if t.statuses:
				for inst in t.statuses.instances():
					var chip := HudStatusChip.draw_named(self, _font, Vector2(ix, py + 74), inst.id, a, 13 if band.has_area() else 15)
					block = block.merge(chip)
					ix += chip.size.x + 6.0
			drawn_blocks["plate"] = block

## HUDRULES: true while she fights an animal the shown order's `fight` list names (objectives.json).
func quest_served_by_fight() -> bool:
	var t: Creature = player.hunt.target if player and player.hunt and is_instance_valid(player.hunt.target) else null
	return t != null and OrdersSheet.served_by_fight(OrdersSheet.shown_index(), t)

func _draw_orders_badge(mp: Vector2, px: int) -> void:
	var step := OrdersSheet.hud_step(player)
	var text := "%d/%d" % [int(step["index"]) + 1, int(step["count"])] if not step.is_empty() else "Done"
	orders_badge_text = text
	_orders_badge_px = px
	orders_badge_rect = HudOrdersBadge.rect_for(_font, mp, text, px)
	drawn_blocks["orders_badge"] = orders_badge_rect  # drawn by _draw_minimap: the map control paints over the HUD

## The card shows expanded: by hand (OrdersSheet.hud_expanded), or auto while she works on the order
## unless she collapsed it during this activity.
func orders_expanded() -> bool:
	return OrdersSheet.hud_expanded or (orders_auto_t > 0.0 and not _orders_suppressed)

## A tap on the badge expands; a tap on the card collapses (and keeps an auto-expanded card down).
func orders_tap() -> void:
	if orders_expanded():
		OrdersSheet.hud_expanded = false
		_orders_suppressed = orders_auto_t > 0.0
	else:
		OrdersSheet.hud_expanded = true

## Progress on the shown order (its fill rose) or a fight that serves it keeps the auto timer up.
func _tick_orders_auto(delta: float) -> void:
	orders_auto_t = maxf(0.0, orders_auto_t - delta)
	if orders_auto_t <= 0.0:
		_orders_suppressed = false
	_tasks_poll -= delta
	if _tasks_poll <= 0.0:
		_tasks_poll = 1.0
		var ready := Tasks.claimable_count(player)
		if ready != field.tasks_ready:
			field.tasks_ready = ready
			field.apply_badge()
	_orders_poll -= delta
	if _orders_poll > 0.0:
		return
	_orders_poll = 0.25
	var step := OrdersSheet.hud_step(player)
	var i := int(step.get("index", -1))
	var frac := float(step.get("frac", 0.0))
	if i == _orders_frac_index and frac > _orders_frac + 0.0001:
		orders_auto_t = ORDERS_AUTO_S
	_orders_frac = frac
	_orders_frac_index = i
	if _in_combat and quest_served_by_fight():
		orders_auto_t = ORDERS_AUTO_S

func _draw_orders_on_map() -> void:
	if orders_badge_rect.has_area():
		var local := Rect2(orders_badge_rect.position - _minimap.global_position, orders_badge_rect.size)
		HudOrdersBadge.draw(_minimap, _font, local, orders_badge_text, _orders_badge_px, _orders_flash)

## HUDRULES: a press on the orders badge expands the card; a press on the card collapses it.
func _orders_toggle_at(pos: Vector2) -> bool:
	var compact := UiTokens.is_compact(get_viewport_rect().size)
	var hit := (orders_badge_rect.has_area() and HudOrdersBadge.touch_rect(orders_badge_rect, compact).has_point(pos)) \
		or (drawn_blocks.has("quest") and (drawn_blocks["quest"] as Rect2).has_point(pos))
	return hit

## A landscape phone in a fight that serves the order: the plate owns the centre band, so the order shows
## as a 40 px strip (title and progress) on a free spot under the vitals' chip row. False when none is free.
func _draw_quest_strip(r: Vector2) -> bool:
	var step := OrdersSheet.hud_step(player)
	if step.is_empty():
		return false
	var v := HudLayout.vitals_rect(self, r)
	var top := maxf(v.end.y + 8.0, stomach_rect.end.y + 6.0)  # under the stomach ring that leads the buff row
	for k in ["statuses", "status_maxhp", "rest"]:
		if drawn_blocks.has(k):
			top = maxf(top, (drawn_blocks[k] as Rect2).end.y + 6.0)
	var box := UiTokens.free_spot(Rect2(v.position.x, top, minf(260.0, v.size.x), 40.0), taken_rects(), r)
	if not box.has_area():
		return false
	var px := UiTokens.meta(r)
	draw_rect(box, UiTokens.INK)
	draw_rect(Rect2(box.position, Vector2(3.0, box.size.y)), UiTokens.TEAL)
	draw_rect(Rect2(box.position, Vector2(3.0, box.size.y * float(step["frac"]))), UiTokens.TEAL.lightened(0.3))
	var prog := str(step["progress"])
	var pw := _font.get_string_size(prog, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, box.position + Vector2(10, 15), "ORDERS %d/%d" % [int(step["index"]) + 1, int(step["count"])], HORIZONTAL_ALIGNMENT_LEFT, -1, px - 2, UiTokens.META)
	draw_string(_font, box.position + Vector2(10, 33), UiTokens.ellipsis(_font, str(step["title"]), box.size.x - pw - 26.0, px + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px + 1, UiTokens.TEXT)
	draw_string(_font, box.position + Vector2(box.size.x - pw - 8.0, 33), prog, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UiTokens.TEAL)
	drawn_blocks["quest"] = box
	return true

## The quest card's rect: under the map on a phone, left of it otherwise.
func quest_rect(r: Vector2, mp: Vector2) -> Rect2:
	var phone := UiTokens.is_phone(r)
	var w := MAP_PX if phone else 240.0  # wide enough for "Home Grassland" at heading size
	var origin := Vector2(mp.x, mp.y + MAP_PX + 52.0) if phone else Vector2(mp.x - w - 12.0, mp.y)
	if not phone and is_instance_valid(_claim_hex) and _claim_hex.is_visible_in_tree():
		origin.x = minf(origin.x, _claim_hex.hex_rect().position.x - w - 8.0)  # HUDTWEAK: CLAIM sits over the dial
	return Rect2(maxf(origin.x, 8.0), origin.y, w, 72.0)

func _draw_quest(r: Vector2, mp: Vector2) -> void:
	var q := quest_rect(r, mp)
	var origin := q.position
	var w := q.size.x
	draw_rect(q, UiTokens.INK)
	draw_rect(Rect2(origin, Vector2(3.0, 72.0)), UiTokens.TEAL)
	drawn_blocks["quest"] = q
	var step := OrdersSheet.hud_step(player)  # the running order, or the one tracked in Orders
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
	draw_circle(center + Vector2(0, 1.5), 12.5, Color(0, 0, 0, 0.45), true, -1.0, true)  # sticker: shadow, white peel rim
	draw_circle(center, 12.0, Color(0.97, 0.97, 0.94), true, -1.0, true)
	draw_circle(center, 10.0, col, true, -1.0, true)
	draw_arc(center, 10.0, 0.0, TAU, 24, Color(0.06, 0.08, 0.08), 1.2, true)
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

## What the energy bar shows: the ridden mount's pool while mounted (named, amber), else the
## survivor's stamina. The exhaustion face and treadmill stay the survivor's either way.
static func energy_reading(pl: Player) -> Dictionary:
	var m: Creature = pl.mounted_on if pl and is_instance_valid(pl.mounted_on) else null
	if m:
		var nm: String = m.pet_record.name if m.pet_record and m.pet_record.name != "" else m.def.species
		return {"value": m.energy, "max": m.energy_max, "name": nm}
	return {"value": pl.vitals.energy, "max": pl.vitals.effective_max_energy(), "name": ""}

func _bar(pos: Vector2, size: Vector2, frac: float, col: Color, glyph: String, text: String, text_px: int = 12, segments: int = 0, trail_key: StringName = &"") -> void:
	# LEVELBADGE: no panel behind, so each bar has its own shadow, dark rim and a lit top edge.
	draw_rect(Rect2(pos + Vector2(-1, 1), size + Vector2(2, 2)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(pos, size), Color(0.08, 0.08, 0.1, 0.85))
	frac = clampf(frac, 0.0, 1.0)
	if trail_key != &"":  # a pale ghost trails a loss and leads a gain; the real fill moves, never jumps up
		var t := _trail(trail_key, frac, get_process_delta_time())
		frac = t.x
		if t.y > t.x:
			draw_rect(Rect2(pos + Vector2(size.x * t.x, 0), Vector2(size.x * (t.y - t.x), size.y)), col.lerp(Color.WHITE, 0.55))
	draw_rect(Rect2(pos, Vector2(size.x * frac, size.y)), col)
	draw_rect(Rect2(pos, Vector2(size.x * frac, maxf(1.0, size.y * 0.3))), Color(1, 1, 1, 0.16))
	for k in range(1, segments):  # a 2 px dark gap between segments
		draw_rect(Rect2(pos.x + size.x * float(k) / float(segments) - 1.0, pos.y, 2.0, size.y), Color(0.02, 0.03, 0.05, 0.9))
	draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.6), false, 1.0)
	if glyph != "":
		draw_string(_font, pos + Vector2(-14, size.y - 3), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if text != "":
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, text_px).x
		draw_string_outline(_font, pos + Vector2(size.x - w - 6, size.y * 0.5 + text_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px, 3, Color(0, 0, 0, 0.6))
		draw_string(_font, pos + Vector2(size.x - w - 6, size.y * 0.5 + text_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px, Color.WHITE)

## Pokémon-style bar motion (owner 2026-10-28): bar_trail[key] = (drawn fill, ghost, hold). A loss drops
## the fill at once and the ghost holds at the old value TRAIL_HOLD s, then eases down; a gain puts the
## ghost at the new value and the fill eases up to it. Returns (fill, ghost) to draw.
func _trail(key: StringName, target: float, dt: float) -> Vector2:
	var s: Vector3 = bar_trail.get(key, Vector3(target, target, 0.0))
	if target < s.x - 0.0005:
		s.y = maxf(s.y, s.x)
		s.x = target
		s.z = TRAIL_HOLD
	elif target > s.x:
		s.y = maxf(s.y, target)
		s.x = target if target - s.x < 0.002 else lerpf(s.x, target, 1.0 - exp(-TRAIL_EASE * dt))
	if s.z > 0.0:
		s.z -= dt
	else:  # the ghost settles on the target (down after a loss; on a gain it already sits there)
		s.y = target if absf(s.y - target) < 0.002 else lerpf(s.y, target, 1.0 - exp(-TRAIL_EASE * dt))
	s.y = maxf(s.y, s.x)
	bar_trail[key] = s
	return Vector2(s.x, s.y)

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
	# Grass and dry land are coloured by biome zone (BiomeZones), everything else by tile type.
	var img := BiomeZones.map_image(rt)
	_map_tex = ImageTexture.create_from_image(img)
	_map_island = World.island_id
	_map_span = span

func _draw_minimap() -> void:
	var c := _minimap
	# LEVELBADGE (owner 2026-10-28): no square box; the map is a disc drawn as a UV polygon (clipped by
	# geometry, so nothing covers the corners), framed by a shadowed metal rim.
	var centre := Vector2(MAP_PX * 0.5, MAP_PX * 0.5)
	var disc_r := MAP_PX * 0.5 - MAP_RIM
	c.draw_circle(centre + Vector2(0, 2.0), MAP_PX * 0.5 - 1.0, Color(0, 0, 0, 0.45), true, -1.0, true)
	c.draw_circle(centre, disc_r, Color(0.05, 0.06, 0.08, 0.92), true, -1.0, true)
	_ensure_map_texture()
	if player == null:
		return
	var rt := World.runtime
	# Camera-up map: the iso camera looks along a 45° diagonal, so a north-up map made running
	# left read as south-west. Everything below is drawn rotated by the camera yaw around the
	# centre (so screen-up on the map is screen-up in the world); the frame clips the corners.
	var cam := get_viewport().get_camera_3d()
	var cam_yaw := cam.global_rotation.y if cam else 0.0
	c.draw_set_transform(centre, cam_yaw, Vector2.ONE)
	if _map_tex and rt:
		var size_m: float = float(rt.get("_size"))
		var half := disc_r * MAP_SCALE  # metres from centre to the disc's edge
		var pp := player.global_position
		_map_disc(c, _map_tex, disc_r, Vector2(pp.x + size_m * 0.5, pp.z + size_m * 0.5), MAP_SCALE)  # one texel per metre
		var to_px := func (w: Vector3) -> Vector2:
			return Vector2((w.x - pp.x) / MAP_SCALE, (w.z - pp.z) / MAP_SCALE)
		# Fog of war: the same per-island bitmap the atlas draws, camera-up like the terrain. The
		# survivor is at the centre, so the brush is always the middle of the disc.
		var fog := World.map_fog
		var fog_tex: ImageTexture = fog.texture() if fog else null
		if fog_tex:
			# The fog image is one pixel per fog cell, not per terrain tile.
			var cell_m := size_m / float(maxi(1, fog.span))
			_map_disc(c, fog_tex, disc_r, Vector2(pp.x + size_m * 0.5, pp.z + size_m * 0.5) / cell_m, MAP_SCALE / cell_m)
		var trail_pts: Array = []
		var trail_alphas: Array[float] = []
		if fog:
			for i in fog.trail.size():
				var tp := fog.trail[i]
				var q := Vector2((tp.x - pp.x) / MAP_SCALE, (tp.y - pp.z) / MAP_SCALE)
				if q.length() <= disc_r:
					trail_pts.append(q)
					trail_alphas.append(fog.trail_alpha(i))
			MapIcons.trail(c, trail_pts, 1.6, trail_alphas)
		var marker_r := disc_r - 4.0
		var camp: Vector3 = rt.get("_camp_pos")
		var harb: Vector3 = rt.get("_harbour_pos")
		var camp_q: Vector2 = to_px.call(camp)
		var harb_q: Vector2 = to_px.call(harb)
		if camp_q.length() <= marker_r:
			MapIcons.flame(c, camp_q, 3.4, Color(1.0, 0.90, 0.55), Color(0.02, 0.03, 0.05, 0.9))
		if harb_q.length() <= marker_r:
			MapIcons.anchor(c, harb_q, 3.6, Color(0.70, 0.85, 1.0), Color(0.02, 0.03, 0.05, 0.9))
		if World.crater_discovered:
			var cr: Vector3 = rt.get("_crater_pos")
			var crater_q: Vector2 = to_px.call(cr)
			if crater_q.length() <= marker_r:
				c.draw_circle(crater_q, 4.0, Color(0.9, 0.4, 0.2))
		for n in get_tree().get_nodes_in_group("creatures"):
			var cr := n as Creature
			if cr == null or cr.health.dead:
				continue
			if fog and not fog.revealed_at(cr.global_position):
				continue  # fog: unseen animals stay off the minimap
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
	# LEVELBADGE: a dark rim, a bronze band lit on its top-left, and a fine inner line; no corner covers.
	var centre := c.size * 0.5
	var r := MAP_PX * 0.5 - MAP_RIM * 0.5
	c.draw_arc(centre, r, 0.0, TAU, 64, Color(0.02, 0.02, 0.03, 0.95), MAP_RIM + 2.0, true)
	c.draw_arc(centre, r, 0.0, TAU, 64, Color(0.55, 0.45, 0.30), MAP_RIM - 1.5, true)
	c.draw_arc(centre, r, PI * 0.95, PI * 1.85, 24, Color(0.95, 0.85, 0.62, 0.85), (MAP_RIM - 1.5) * 0.45, true)
	c.draw_arc(centre, r, -0.05 * PI, 0.85 * PI, 24, Color(0.20, 0.15, 0.08, 0.8), (MAP_RIM - 1.5) * 0.4, true)
	c.draw_arc(centre, MAP_PX * 0.5 - MAP_RIM - 0.5, 0.0, TAU, 64, Color(0, 0, 0, 0.6), 1.0, true)
	# A small compass pip at the bottom of the rim, where the coordinates hang.
	var b := Vector2(centre.x, MAP_PX - MAP_RIM * 0.5)
	c.draw_colored_polygon(PackedVector2Array([b + Vector2(0, -5), b + Vector2(4, 0), b + Vector2(0, 5), b + Vector2(-4, 0)]), Color(0.02, 0.02, 0.03))
	c.draw_colored_polygon(PackedVector2Array([b + Vector2(0, -3.5), b + Vector2(2.6, 0), b + Vector2(0, 3.5), b + Vector2(-2.6, 0)]), Color(0.98, 0.86, 0.55))

## A texture as a disc of radius `r` around the map centre (already rotated to the camera):
## `at` is the texel under the centre, `per_px` texels per map pixel.
func _map_disc(c: Control, tex: Texture2D, r: float, at: Vector2, per_px: float) -> void:
	var ts := tex.get_size()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 48:
		var d := Vector2.from_angle(TAU * float(i) / 48.0) * r
		pts.append(d)
		uvs.append((at + d * per_px) / ts)
	c.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)