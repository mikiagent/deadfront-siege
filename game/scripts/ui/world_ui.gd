extends CanvasLayer
## Terrain pick, harbour routes, map, pause/save. Mobile-first 64 px targets.

static var _i

var _panel: Control
var _mode: StringName = &""

static func ensure():
	if _i and is_instance_valid(_i):
		return _i
	_i = (load("res://scripts/ui/world_ui.gd") as GDScript).new()
	_i.name = "WorldUI"
	var host: Node = Engine.get_main_loop().root.get_tree().current_scene
	host.add_child(_i)
	return _i

static func instance_on(host: Node):
	if _i and is_instance_valid(_i):
		return _i
	_i = (load("res://scripts/ui/world_ui.gd") as GDScript).new()
	_i.name = "WorldUI"
	host.add_child(_i)
	return _i

func _ready() -> void:
	layer = 40
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

func _unhandled_input(event: InputEvent) -> void:
	var player := PlayerRegistry.local()
	if player and player.placer and player.placer.placing != &"" and event.is_action_pressed("pause"):
		return
	if event.is_action_pressed("map"):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_map"):
			hud.open_map()  # toggles
		elif _mode == &"map":
			hide_all()
		else:
			show_map()
		get_viewport().set_input_as_handled()
	elif _mode == &"harbour" and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		hide_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if _mode == &"pause":
			hide_all()
		else:
			show_pause()
		get_viewport().set_input_as_handled()

## A survivor made this session must not save before picking an island (defect 1: the 60 s autosave
## did, and the reload skipped the pick). Whenever nothing is open at the end of a frame and the pick
## was never made, put the pick back up — closing it without choosing changes nothing.
func _process(_delta: float) -> void:
	# Only after character creation has closed, so the island pick never covers it.
	if World.creation_pending and _mode == &"" and get_tree().get_nodes_in_group(&"character_creation").is_empty():
		show_terrain()

func hide_all() -> void:
	_mode = &""
	_panel.visible = false
	for c in _panel.get_children():
		c.queue_free()

func show_terrain() -> void:
	for c in _panel.get_children():
		c.queue_free()
	_mode = &"terrain"
	_panel.visible = true
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.035, 0.045, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(scrim)
	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_left = 12.0
	sheet.offset_right = -12.0
	sheet.offset_top = -168.0
	sheet.offset_bottom = -10.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.085, 0.96)
	style.border_color = Color(0.28, 0.52, 0.48, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	sheet.add_theme_stylebox_override("panel", style)
	_panel.add_child(sheet)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	sheet.add_child(content)
	var title := Label.new()
	title.text = "CHOOSE YOUR FIRST ISLAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 7)
	content.add_child(cards)
	var terrains: Array = [
		["MEADOW", "Open grass", "●", Color(0.20, 0.48, 0.25), &"meadow"],
		["FOREST", "Dense wood", "♣", Color(0.10, 0.34, 0.20), &"forest"],
		["ROCKY", "Stone-rich", "▲", Color(0.34, 0.35, 0.34), &"rocky"],
		["RIVER", "Fresh water", "≈", Color(0.12, 0.36, 0.48), &"riverside"],
		["COAST", "Wide shore", "◒", Color(0.40, 0.39, 0.20), &"coastal"],
	]
	for row in terrains:
		var b := Button.new()
		b.text = "%s  %s\n%s" % [row[2], row[0], row[1]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 86)
		b.add_theme_font_size_override("font_size", 18)
		var normal := StyleBoxFlat.new()
		normal.bg_color = row[3]
		normal.set_corner_radius_all(9)
		normal.border_color = Color(0.75, 0.9, 0.78, 0.45)
		normal.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", normal)
		var id: StringName = row[4]
		b.pressed.connect(func () -> void: _choose_terrain(id))
		cards.add_child(b)
	UiTokens.focus_first(cards.get_children())

func _choose_terrain(id: StringName) -> void:
	World.home_terrain = id
	var host: Node = World.runtime.get_parent() if World.runtime else get_tree().current_scene
	var harbour: Array = World.island_def.get("harbour", [0, 0, 18])
	World.load_island(host, &"home_grassland", Vector3(float(harbour[0]), 1.0, float(harbour[2])), false)
	World.finish_creation()  # creation and the pick are done: saving starts here
	(load("res://scripts/core/save_game.gd") as GDScript).save_now()
	hide_all()
	_show_arrival(host)


func _show_arrival(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArrivalWelcome"
	layer.layer = 92
	host.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.05, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 14)
	centre.add_child(box)
	var title := Label.new()
	title.text = "YOU MADE IT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	box.add_child(title)
	var body := Label.new()
	body.text = "Your survivor is at the harbour. Tap the world to move and interact."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	box.add_child(body)
	var go := Button.new()
	go.text = "START EXPLORING"
	go.custom_minimum_size = Vector2(0, 68)
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(layer.queue_free)
	box.add_child(go)

## The Harbour (§7 F2, owner §11: the stretched "Sail ..." row list is rebuilt, not patched): the
## sheet chrome, then one card per destination in a grid, each with its own Sail button. A route's
## button carries meta "route_id" (the island id, "home" or "camp") and is disabled when the survivor
## lacks the Survival level or the T-stones; the reason is on the card. Pressing it departs at once,
## as the old row did (dev/progression_probe.gd and the bot press these buttons).
func show_harbour() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	_mode = &"harbour"
	_panel.visible = true
	var player := PlayerRegistry.local()
	var level := player.skills.level_of("survival") if player and player.skills else 0
	var view := _panel.get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	var root := Control.new()
	root.name = "Harbour"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = SheetChrome.ui_theme()
	_panel.add_child(root)
	root.add_child(SheetChrome.backdrop())
	var chrome := SheetChrome.new("Harbour")
	root.add_child(chrome)
	chrome.counter.text = "Survival %d  ·  Warp Gems %d" % [level, World.warp_gems]
	chrome.back_pressed.connect(func () -> void:
		hide_all()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_atlas"):
			hud.call("open_atlas")  # ‹ returns to the World Atlas the Harbour routes button came from
	)
	chrome.close_pressed.connect(hide_all)
	chrome.layout(view)
	var side := SheetChrome.side_for(view)
	var top := SheetChrome.body_top(view)
	var scroll := ScrollContainer.new()
	scroll.name = "Routes"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(side, top)
	scroll.size = Vector2(view.x - side * 2.0, view.y - top - (8.0 if compact else 32.0))
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "RouteGrid"
	grid.columns = 3 if compact else 4
	var gap := 8 if compact else 16
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var card_w := (scroll.size.x - float(gap * (grid.columns - 1)) - 12.0) / float(grid.columns)
	if not World.is_home():
		grid.add_child(_route_card("Home island", "Your tamed island", "Free · any time", UiTokens.OK_GREEN, "Free return home", &"home", false, card_w, compact))
		grid.add_child(_route_card("Camp", MapScreen.island_name(str(World.island_id)), "Walk back to this island's camp", UiTokens.MUTED, "Return to camp", &"camp", false, card_w, compact))
	for key in World.harbour_routes():
		if key == str(World.island_id):
			continue
		var id := StringName(key)
		var dest := World.def_of(id)
		var required := World.route_level(id)
		var cost := int(dest.get("sail_cost", 5))
		var line := "%s · %s" % [LevelDisplay.label(int(dest.get("tier", 1))), str(dest.get("climate", "")).capitalize()]
		if World.is_drift(key):
			# UNSTABLE ISLES: the route's own countdown (off the board, or sinking once landed).
			var t := int(World.drift_time_left())
			line += " · %s %d:%02d" % ["sinks in" if World.drift_landed() else "leaves the board in", t / 60, t % 60]
		var need := "Ready to sail"
		var col := UiTokens.OK_GREEN
		if level < required:
			need = "Needs Survival %d · you are %d" % [required, level]
			col = UiTokens.LIFE
		elif World.warp_gems < cost:
			need = "Needs %d Warp Gems · you have %d" % [cost, World.warp_gems]
			col = UiTokens.LIFE
		elif World.visited_islands.has(key):
			need = "Visited · ready to sail"
		grid.add_child(_route_card(MapScreen.island_name(key), line, need, col, "Sail · %d Warp Gems" % cost, id, level < required or World.warp_gems < cost, card_w, compact))
	var buttons: Array = []
	for b in grid.find_children("*", "Button", true, false):
		if not (b as Button).disabled:
			buttons.append(b)
	UiTokens.focus_first(buttons)

func _route_card(title: String, line: String, need: String, need_col: Color, action: String, id: StringName, locked: bool, w: float, compact: bool) -> Control:
	var card := PanelContainer.new()
	card.name = "Route_" + str(id)
	card.custom_minimum_size = Vector2(w, 0)
	var sb := SheetChrome.panel_style()
	for m in ["content_margin_left", "content_margin_right", "content_margin_top", "content_margin_bottom"]:
		sb.set(m, 10.0 if compact else 18.0)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2 if compact else 4)
	card.add_child(box)
	var nm := SheetChrome.text(title, 16 if compact else 24, UiTokens.MUTED if locked else UiTokens.TEXT)
	SheetChrome.strong(nm, 500)
	box.add_child(nm)
	box.add_child(SheetChrome.text(line, 12 if compact else 16, UiTokens.TEXT))
	box.add_child(SheetChrome.text(need, 12 if compact else 15, need_col))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2 if compact else 8)
	box.add_child(gap)
	var b := SheetChrome.action_button(action, &"ghost" if locked else &"cta")
	b.set_meta("route_id", str(id))
	b.disabled = locked
	b.add_theme_font_size_override("font_size", 14 if compact else 20)
	b.pressed.connect(func () -> void:
		hide_all()
		match id:
			&"home": World.travel(&"home_grassland", &"harbour_home")
			&"camp": World.recall_camp()
			_: World.travel(id, &"sail")
	)
	box.add_child(b)
	return card

func show_map() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_map"):
		hud.open_map()  # the drawn island map; this text panel is the lab fallback
		_mode = &"map"
		return
	var life := "permanent" if World.is_home() else "%.0fs left" % World.remaining_lifetime
	var crater := "yes" if World.crater_discovered else "no"
	var player := PlayerRegistry.local()
	var fat := 0.0
	if player:
		fat = player.vitals.fatigue
	var body := "Island %s\n%s\nPioneer %d   Gold %d\nFatigue %.0f  (walk / gather / climate)\nCrater discovered: %s" % [
		World.island_id, life, LevelDisplay.player_level(), World.t_stones, fat, crater]
	var rows: Array = [["Warp home", &"warp"], ["Harbour routes", &"harbour"]]
	if World.is_unstable():
		rows.append(["Return to camp", &"camp"])
	_fill(body, rows, func (id: StringName) -> void:
		match id:
			&"warp":
				hide_all()
				World.travel(&"home_grassland", &"warp_home")
			&"harbour":
				show_harbour()
			&"camp":
				hide_all()
				World.recall_camp()
	)
	_mode = &"map"

func show_pause() -> void:
	_fill("Paused", [["Save", &"save"], [DisplayMode.label(), &"fullscreen"], ["Resume", &"resume"]], func (id: StringName) -> void:
		if id == &"save":
			(load("res://scripts/core/save_game.gd") as GDScript).save_now()
		elif id == &"fullscreen":
			DisplayMode.toggle()  # runs inside the button press, which the browser needs for fullscreen
		hide_all()
	)

func _fill(title: String, rows: Array, cb: Callable) -> void:
	for c in _panel.get_children():
		c.queue_free()
	_mode = &"panel"
	_panel.visible = true
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.04, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func (event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			hide_all()
		elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			hide_all()
	)
	_panel.add_child(scrim)
	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_left = 12.0
	sheet.offset_right = -12.0
	sheet.offset_top = -minf(650.0, get_viewport().get_visible_rect().size.y * 0.75) if rows.size() > 4 else (-148.0 if rows.size() <= 2 else -220.0)
	sheet.offset_bottom = -10.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.08, 0.96)
	style.border_color = Color(0.26, 0.49, 0.46, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	sheet.add_theme_stylebox_override("panel", style)
	_panel.add_child(sheet)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	box.add_child(heading)
	var lab := Label.new()
	lab.text = title
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("font_size", 22)
	heading.add_child(lab)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(54, 54)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(hide_all)
	heading.add_child(close)
	var actions: BoxContainer
	if rows.size() > 4:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		actions = VBoxContainer.new()
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(actions)
	else:
		actions = HBoxContainer.new()
		box.add_child(actions)
	actions.add_theme_constant_override("separation", 8)
	for i in rows.size():
		var row: Array = rows[i]
		var b := Button.new()
		b.text = str(row[0]).to_upper()
		b.set_meta("route_id", str(row[1]))
		b.disabled = bool(row[2]) if row.size() > 2 else false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 20)
		if i == 0:
			var primary := StyleBoxFlat.new()
			primary.bg_color = Color(0.16, 0.50, 0.37)
			primary.set_corner_radius_all(10)
			b.add_theme_stylebox_override("normal", primary)
		var id: StringName = row[1]
		b.pressed.connect(func () -> void: cb.call(id))
		actions.add_child(b)
	UiTokens.focus_first(actions.get_children())
