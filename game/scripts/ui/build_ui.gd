class_name BuildUI
extends Control
## Build mode (docs/design/ui-redesign-spec.md §7 D2; owner's spec 30 §2, §7). Rebuilt from the
## stretched full-width row list (owner rule §11) into a drawer on the left over the world:
##   header   - "Build", Move buildings, ✕;
##   tier tabs - Thatch Lv. 1 / Wood Constr. 5 / Stone Constr. 20 / Metal Constr. 35 (structures.json);
##   tiles    - flat-top hex tiles by section: Parts (modular pieces of the tier), Stations (building
##              kits in the bag) and Blueprints (construction sites, BuildFlow); each tile shows its
##              cost under the name;
##   footer   - the tier's materials in the bag and the Construction level.
## A tile starts the placer and the drawer stays open, so the world to its right shows the ghost with
## the HUD's ROTATE / SAVE / CANCEL row; a banner says "Pick a building spot" and a bar under it what
## the piece costs. The ghost turns red when any cell is outside the Domain (BuildGrid / StructureGrid
## refuse "unclaimed"). A placed construction site opens its sheet in the same drawer (§7): its slots
## with the deposited instances and Work / Withdraw / Cancel site / Finish. Every rule stays in
## BuildPlacer, StructurePlacer and BuildFlow; this file only shows them.

const FOOTER_H := 64.0
const SITE_GROUP := "construction_site"
const TAP := 64.0
const SECTIONS := ["Parts", "Stations", "Blueprints"]

var player: Player
var site: ConstructionSite
var tier: StringName = &"thatch"
var _selected: String = ""
var _site_mode := false
var _phone_detail := false  ## kept for callers; the drawer has one pane
var _slot_buttons: Array[Button] = []

var _drawer: PanelContainer
var _title: Label
var _hint: Label
var _move_btn: Button
var _close_btn: Button
var _tiers: HBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _detail: VBoxContainer  ## the site sheet's rows (inside the scroll)
var _footer: HBoxContainer  ## site actions
var _stock: Label
var _banner: VBoxContainer
var _cost_bar: Label
var _stock_text := ""  ## the drawer's bottom line when no ghost is up

func _ready() -> void:
	visible = false
	# The drawer catches taps; the rest of the screen stays the world (the ghost, the placer row).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 41  # above the craft menu, whose Build button opens this
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = UiTokens.ui_face()
	theme = th
	_drawer = PanelContainer.new()
	_drawer.name = "BuildDrawer"
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	# Opaque: the HUD's vitals and rail sit under it.
	_drawer.add_theme_stylebox_override("panel", CraftUI.flat(Color(0.035, 0.04, 0.045, 1.0), Color(1, 1, 1, 0.08), 1))
	add_child(_drawer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_drawer.add_child(col)
	var head := HBoxContainer.new()
	head.name = "BuildHead"
	head.add_theme_constant_override("separation", 10)
	col.add_child(_pad(head, 18, 10))
	_title = CraftUI._label("Build", 34, UiTokens.TEXT)
	_title.name = "BuildTitle"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	head.add_child(_title)
	_move_btn = CraftUI.mk_btn("Move buildings", _move_buildings, Vector2(150, TAP), "ghost")
	_move_btn.name = "MoveBuildings"
	_move_btn.add_theme_font_size_override("font_size", 18)
	head.add_child(_move_btn)
	_close_btn = CraftUI.mk_btn("✕", hide_ui, Vector2(TAP, TAP), "icon")
	_close_btn.name = "BuildClose"
	_close_btn.add_theme_font_size_override("font_size", 34)
	head.add_child(_close_btn)
	_hint = CraftUI._label("", 14, UiTokens.MUTED)
	_hint.name = "BuildHint"
	_hint.visible = false
	col.add_child(_pad(_hint, 18, 0))
	_tiers = HBoxContainer.new()
	_tiers.name = "TierTabs"
	_tiers.add_theme_constant_override("separation", 0)
	col.add_child(_tiers)
	_scroll = ScrollContainer.new()
	_scroll.name = "BuildScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 0)
	_scroll.add_child(inner)
	_list = VBoxContainer.new()
	_list.name = "BuildList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	inner.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.name = "BuildDetail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	inner.add_child(_pad(_detail, 16, 8))
	_footer = HBoxContainer.new()
	_footer.name = "BuildFooter"
	_footer.add_theme_constant_override("separation", 6)
	_footer.visible = false
	col.add_child(_pad(_footer, 12, 8))
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	_stock = CraftUI._label("", 18, UiTokens.TEXT)
	_stock.name = "BuildStock"
	_stock.custom_minimum_size = Vector2(0, 44)
	_stock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(_pad(_stock, 18, 0))
	# Over the world while a ghost is up: what to do, and what the piece costs.
	_banner = VBoxContainer.new()
	_banner.name = "PlaceBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_constant_override("separation", 0)
	add_child(_banner)
	var bt := CraftUI._label("Pick a building spot", 28, UiTokens.TEXT)
	bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bt.add_theme_constant_override("outline_size", 6)
	bt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_banner.add_child(bt)
	var bs := CraftUI._label("A building must sit fully inside your domain to be protected.", 17, UiTokens.TEXT)
	bs.name = "BannerSub"
	bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bs.add_theme_constant_override("outline_size", 5)
	bs.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_banner.add_child(bs)
	_cost_bar = CraftUI._label("", 20, UiTokens.TEXT)
	_cost_bar.name = "PlaceCost"
	_cost_bar.clip_text = false
	_cost_bar.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_cost_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_bar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_bar.add_theme_stylebox_override("normal", CraftUI.pad(Color(0.03, 0.035, 0.04, 0.92), 24, 24, 0, 0))
	add_child(_cost_bar)
	if get_viewport():
		get_viewport().size_changed.connect(_fit)
	resized.connect(_layout)

## One BuildUI per survivor, created on first use (main.gd is outside this task's files). It goes
## on the HUD's canvas layer, above the craft menu, and is bound to `p`.
static func ensure(p: Player) -> BuildUI:
	if p == null:
		return null
	if p.build_ui != null and is_instance_valid(p.build_ui):
		return p.build_ui as BuildUI
	var ui: BuildUI = (load("res://scenes/ui/build.tscn") as PackedScene).instantiate() as BuildUI
	ui.name = "BuildUI"
	var hud := p.get_tree().get_first_node_in_group("hud") if p.is_inside_tree() else null
	var layer: Node = hud.get_parent() if hud else null
	if layer == null:
		layer = p.get_tree().current_scene
	if layer:
		layer.add_child(ui)
	ui.bind(p)
	p.build_ui = ui
	return ui

## A runtime-created screen gets its size one frame late; fill the canvas explicitly.
func _fit() -> void:
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elif get_viewport():
		size = get_viewport().get_visible_rect().size
	_layout()

func bind(p: Player) -> void:
	player = p
	if player and player.inventory and not player.inventory.changed.is_connected(_on_inventory_changed):
		player.inventory.changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if visible:
		rebuild()

func _unhandled_input(event: InputEvent) -> void:
	# Esc cancels a ghost first (PlayerInput); with none up it closes the drawer.
	if visible and event.is_action_pressed("ui_cancel") and not _placing():
		hide_ui()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- opening

func toggle() -> void:
	if visible:
		hide_ui()
	else:
		open()

func open() -> void:
	site = null
	_site_mode = false
	visible = true
	_fit()
	rebuild()
	UiTokens.focus_first(_list.find_children("*", "HexButton", true, false))

func hide_ui() -> void:
	visible = false
	site = null
	_site_mode = false

## A tap on a placed site (ConstructionSite.interact lands here).
func show_site(s: ConstructionSite) -> void:
	# CRAFTRADIAL: a site opens the Construction panel (CraftUI's right pop-out, CraftPlace site mode).
	# The drawer's old site view stays for a survivor with no craft menu (labs).
	var cui: Variant = player.get("craft_ui") if player else null
	if cui != null and cui.has_method("open_site"):
		hide_ui()
		cui.open_site(s)
		return
	site = s
	_site_mode = true
	_selected = str(s.blueprint_id)
	visible = true
	_fit()
	rebuild()

## The drawer's screen rect, global.
func drawer_rect() -> Rect2:
	return _drawer.get_global_rect() if visible and _drawer else Rect2()

## What this screen holds over the world: the drawer, the banner and the cost bar. HuntHud keeps the
## placer row off them.
func taken_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not visible:
		return out
	out.append(drawer_rect())
	for c: Control in [_banner, _cost_bar]:
		if c.visible:
			out.append(c.get_global_rect())
	return out

func _placing() -> bool:
	return player != null and player.placer != null and player.placer.placing != &""

func _process(_delta: float) -> void:
	if not visible:
		return
	var placing := _placing() and not _site_mode
	_banner.visible = placing
	# A landscape phone has no free strip for the cost bar (quest card, hexes): the drawer's bottom
	# line says it instead.
	_cost_bar.visible = placing and _cost_bar.text != "" and not _compact()
	if _compact() and not _site_mode:
		var want := _cost_bar.text if placing else _stock_text
		if _stock.text != want:
			_stock.text = want

# ---------------------------------------------------------------- the drawer

func rebuild() -> void:
	if player == null:
		return
	_rebuild_content()
	_layout()  # after the content: a drawer laid out around the old (desktop) tiles kept their width

func _rebuild_content() -> void:
	for pane in [_list, _detail, _footer]:
		for c in pane.get_children():
			pane.remove_child(c)
			c.queue_free()
	_slot_buttons.clear()
	_tiers.visible = not _site_mode
	_move_btn.visible = not _site_mode
	_footer.visible = _site_mode
	(_detail.get_parent() as Control).visible = _site_mode
	if _site_mode:
		_refresh_site()
		return
	_title.text = "Build"
	_hint.visible = false
	_refresh_tiers()
	var compact := _compact()
	# Parts: the modular pieces this tier can build (structures.json piece_tiers).
	var parts: Array[Dictionary] = []
	for k in (StructurePiece.defs().get("pieces", {}) as Dictionary):
		var kind := StringName(str(k))
		if StructurePiece.blueprint(kind, tier).is_empty():
			continue
		var cost := StructurePiece.cost(kind, tier)
		parts.append({"name": "Piece_" + str(kind), "label": str(StructurePiece.piece_def(kind).get("label", k)), "cost": cost_text(cost),
			"icon": ItemIcons.texture(StringName(str(cost.keys()[0]))) if not cost.is_empty() else null,
			"blocked": StructurePlacer.tier_gate(player, tier) != "" or not StructurePlacer.can_pay(player.inventory, cost),
			"cb": pick_piece.bind(kind)})
	_section("Parts", parts, compact)
	# Stations: building kits in the bag (each places as its own kind).
	var kits: Array[Dictionary] = []
	var seen := {}
	for i in player.inventory.slot_count:
		var s: ItemStack = player.inventory.slots[i]
		if s == null:
			continue
		var def := Data.item(s.def_id)
		if def == null or str(def.get("place_as")) == "":
			continue
		var kind_id := StringName(str(def.get("place_as")))
		seen[kind_id] = int(seen.get(kind_id, 0)) + s.count
		if int(seen[kind_id]) > s.count:
			continue
		kits.append({"name": "Kit_" + str(kind_id), "label": def.display_name, "cost": "", "icon": ItemIcons.texture(s.def_id), "blocked": false, "cb": pick_kit.bind(kind_id), "kind": kind_id})
	for row in kits:
		row["cost"] = "in bag ×%d" % int(seen[row["kind"]])
	_section("Stations", kits, compact, "No building kits in the bag. Craft one at the workbench.")
	# Blueprints: construction sites (spec 30 §2-3), placed where the survivor stands.
	var bps: Array[Dictionary] = []
	for row in BuildFlow.menu_rows(player):
		var id := str(row.get("id", ""))
		var blocked := str(row.get("blocked", ""))
		bps.append({"name": "BP_" + id, "label": str(row.get("name", id)), "cost": "Buildable" if blocked == "" else blocked,
			"icon": ItemIcons.texture(&"workbench_kit"), "blocked": blocked != "", "cb": tap_blueprint.bind(id)})
	_section("Blueprints", bps, compact)
	_refresh_stock()

func _refresh_tiers() -> void:
	for c in _tiers.get_children():
		_tiers.remove_child(c)
		c.queue_free()
	var compact := _compact()
	for t in (StructurePiece.defs().get("tiers", {}) as Dictionary):
		var t_id := StringName(str(t))
		var td := StructurePiece.tier_def(t_id)
		var chosen := t_id == tier
		var locked := StructurePlacer.tier_gate(player, t_id) != ""
		var b := Button.new()
		b.name = "Tier_" + str(t_id)
		b.custom_minimum_size = Vector2(0, TAP if compact else 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := CraftUI.flat(Color(0.20, 0.18, 0.10, 1.0) if chosen else Color(0, 0, 0, 0))
		sb.border_color = UiTokens.GOLD
		sb.border_width_bottom = 4 if chosen else 0
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, sb)
		b.pressed.connect(_pick_tier.bind(t_id))
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", -4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var nm := CraftUI._label(str(td.get("label", t)), 17 if compact else 22, UiTokens.GOLD if chosen else (UiTokens.MUTED if locked else UiTokens.TEXT))
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nm)
		var req := int(td.get("requires_level", 0))
		var sub := CraftUI._label("Lv. 1" if req <= 1 else "Constr. %d" % req, UiTokens.TYPE_MIN, UiTokens.MUTED if not locked else UiTokens.LIFE)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
		_tiers.add_child(b)

## A section bar and its tiles, three to a row (two on a phone).
func _section(title: String, rows: Array[Dictionary], compact: bool, empty_text: String = "") -> void:
	if rows.is_empty() and empty_text == "":
		return
	var head := CraftUI._label(title, 16 if compact else 20, UiTokens.TEXT)
	head.name = "Section_" + title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.custom_minimum_size = Vector2(0, 32 if compact else 40)
	head.add_theme_stylebox_override("normal", CraftUI.flat(Color(0.02, 0.022, 0.025, 1.0)))
	_list.add_child(head)
	if rows.is_empty():
		var l := CraftUI._label(empty_text, 13 if compact else 15, UiTokens.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		l.clip_text = false
		_list.add_child(_pad(l, 18, 10))
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 10)
	_list.add_child(_pad(grid, 8, 12))
	for row in rows:
		grid.add_child(_tile(row, compact))

## One blueprint tile: a flat-top hex with the material icon, the name, the cost (ellipsised).
func _tile(row: Dictionary, compact: bool) -> Control:
	var box := VBoxContainer.new()
	box.name = "Tile_" + str(row["name"])
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	var hex := HexButton.new(72.0 if compact else 112.0)
	hex.name = str(row["name"])
	hex.icon = row.get("icon", null) as Texture2D
	hex.color_icon = true
	hex.fill = Color(0.12, 0.125, 0.13, 0.97)
	hex.rim_color = UiTokens.HUD_RIM
	hex.rim_width = 4.0
	hex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hex.enabled_look = true
	if bool(row.get("blocked", false)):
		hex.rim_color = Color(0.55, 0.55, 0.55, 0.85)
		hex.fill = Color(0.07, 0.07, 0.075, 0.95)
	hex.selected = str(row["name"]) == "BP_" + _selected
	if hex.selected:
		hex.rim_color = UiTokens.GOLD
	hex.pressed.connect(row["cb"] as Callable)
	box.add_child(hex)
	var nm := CraftUI._label(str(row["label"]), 15 if compact else 19, UiTokens.GOLD if hex.selected else UiTokens.TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(nm)
	var cost := CraftUI._label(str(row["cost"]), UiTokens.TYPE_MIN, UiTokens.MUTED if not bool(row.get("blocked", false)) else Color(0.86, 0.55, 0.45))
	cost.name = "TileCost"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cost)
	return box

## The tier's materials in the bag and the Construction level (the canvas's bottom line).
func _refresh_stock() -> void:
	var ids: Array[StringName] = []
	for k in (StructurePiece.defs().get("pieces", {}) as Dictionary):
		for id in StructurePiece.cost(StringName(str(k)), tier):
			if not ids.has(StringName(str(id))):
				ids.append(StringName(str(id)))
	var parts: PackedStringArray = []
	for id in ids:
		parts.append("%s %d" % [_item_name(id), player.inventory.count_of(id)])
	var lv := int((player.skills as SkillState).level_of("construction")) if player.get("skills") else 0
	_stock_text = "   ".join(parts) + ("   " if not parts.is_empty() else "") + "Construction %s" % LevelDisplay.label(lv)
	_stock.text = _stock_text

func _pick_tier(t_id: StringName) -> void:
	tier = t_id
	StructureSheet.tier = t_id  # the HUD's own build sheet follows the same tier
	rebuild()

## A Parts tile: the modular piece's ghost; the drawer stays open beside it.
func pick_piece(kind: StringName) -> void:
	if player == null or player.placer == null:
		return
	player.placer.begin_piece(kind, tier)
	_cost_bar.text = "%s · %s" % [str(StructurePiece.piece_def(kind).get("label", kind)), cost_text(StructurePiece.cost(kind, tier))]
	_layout()

## A Stations tile: the kit's ghost (BuildPlacer.begin pays the kit on confirm).
func pick_kit(kind: StringName) -> void:
	if player == null or player.placer == null:
		return
	player.placer.begin(kind)
	_cost_bar.text = "%s · 1 kit" % LevelDisplay.nice_name(str(kind))
	_layout()

func _move_buildings() -> void:
	hide_ui()
	if player and player.placer:
		player.placer.begin_layout()

## Marks blueprint `id` as the selected tile (gold rim).
func select(id: String) -> void:
	_selected = id
	rebuild()

## A Blueprints tile: place its construction site in front of the survivor (the real BuildFlow call),
## or say exactly which prerequisite is unmet (spec 30 §3: the drawer never hides a gate).
func tap_blueprint(id: String) -> void:
	_selected = id
	var bp := Blueprints.of(StringName(id))
	var unmet := Blueprints.unmet(player, bp) if not bp.is_empty() else []
	if not unmet.is_empty():
		player.notice("%s: %s" % [str(bp.get("display_name", id)), str(unmet[0])])
		rebuild()
		return
	var why := BuildFlow.place_reason(player, StringName(id), _here_cell(), 0)
	if why != "":
		player.notice("%s: %s" % [str(bp.get("display_name", id)), why])
		rebuild()
		return
	_place_selected()

## The cell in front of the survivor, the one the ghost would land on.
func _here_cell() -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	return BuildGrid.tile_of(player.global_position)

func _placeable_now() -> bool:
	if player == null or _selected == "":
		return false
	return BuildFlow.place_reason(player, StringName(_selected), _here_cell(), 0) == ""

func _place_selected() -> void:
	if player == null:
		return
	var s := BuildFlow.place_site(player, StringName(_selected), _here_cell(), 0)
	if s == null:
		return
	# The survivor kicks the dirt to mark the site (clip from claude/mmo-rummage; played once it lands).
	if player.anim and ResourceLoader.exists("res://assets/characters/survivor/anim/kick_dirt.glb"):
		player.anim.play_clip(&"kick_dirt")
	show_site(s)
	print("[ui] build placed %s site %s" % [_selected, s.site_id])

# ---------------------------------------------------------------- the site sheet (§7)

func _refresh_site() -> void:
	if site == null or not is_instance_valid(site):
		site = null
		_site_mode = false
		_rebuild_content()
		return
	var view := get_viewport_rect().size
	var compact := _compact()
	_title.text = str(site.bp().get("display_name", "Construction")) + " site"
	_hint.visible = true
	_hint.text = "Site %s · %d%% built · %d instance(s) logged" % [site.site_id.substr(0, 11), int(site.overall_progress() * 100.0), site.deposited_by.size()]
	var progress := CraftUI._label("Materials %d%%  ·  Work %d%%  ·  %d/%d s" % [int(site.materials_ratio() * 100.0), int(site.work_ratio() * 100.0), int(site.work_progress), int(site.bp().get("work_seconds", 0))], UiTokens.body(view) + (0 if compact else 2), UiTokens.TEXT)
	progress.name = "SiteProgress"
	_detail.add_child(progress)
	var how := CraftUI._label("Tap a slot to deposit the lowest-level part that fits, work the site to 0 s, then Finish.", UiTokens.meta(view), UiTokens.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	how.clip_text = false
	_detail.add_child(how)
	var slots: Array = site.bp().get("slots", [])
	for i in slots.size():
		var s: Dictionary = slots[i]
		var done := site.deposited(i) >= site.needed(i)
		var row := CraftUI.mk_btn("%s   %d / %d   ·   %s" % [Blueprints.slot_label(s), site.deposited(i), site.needed(i), _instance_levels(i)], _deposit_slot.bind(i), Vector2(0, TAP), "bar")
		row.name = "SiteSlot_%d" % i
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 2))
		row.add_theme_color_override("font_color", UiTokens.OK_GREEN if done else UiTokens.TEXT)
		_detail.add_child(row)
		_slot_buttons.append(row)
	var who := ""
	for k in site.deposited_by:
		who += "%s: %s  " % [str(k).substr(0, 6), str(site.deposited_by[k])]
	var by := CraftUI._label("Contributors  " + (who if who != "" else "none yet"), UiTokens.meta(view), UiTokens.MUTED)
	_detail.add_child(by)
	_mk_footer("Work", _work, "cta").disabled = not site.materials_ready() or site.work_done()
	_mk_footer("Withdraw", _withdraw).disabled = site.escrow().is_empty()
	var cancel := _mk_footer("Cancel site", _cancel_site)
	cancel.add_theme_color_override("font_color", UiTokens.LIFE)
	_mk_footer("Finish", _finish, "cta").disabled = not site.ready_to_finish()
	_stock.text = "Construction %s" % LevelDisplay.label(int((player.skills as SkillState).level_of("construction")) if player.get("skills") else 0)

func _instance_levels(slot: int) -> String:
	var lv: Array[int] = []
	for s in site.slot_items[slot] if slot < site.slot_items.size() else []:
		for _n in s.count:
			lv.append(s.level)
	return "-" if lv.is_empty() else ", ".join(PackedStringArray(lv.map(func (n: int) -> String: return "Lv %d" % n)))

## Tap on a slot: deposit the lowest-level instance the bag has that fits it (the site itself
## refuses a wrong tag; the button just offers the default).
func _deposit_slot(slot: int) -> void:
	if site == null or player == null:
		return
	var idx: int = site.first_fitting(player.inventory, slot)
	if idx < 0:
		player.notice("No %s in the bag." % Blueprints.slot_label((site.bp().get("slots", []) as Array)[slot]))
		return
	site.deposit(slot, idx)
	rebuild()

func _withdraw() -> void:
	if site == null:
		return
	for i in site.slot_items.size():
		if not (site.slot_items[i] as Array).is_empty() and site.withdraw(i):
			break
	rebuild()

func _work() -> void:
	if site == null:
		return
	site.work(1.0)
	rebuild()

func _cancel_site() -> void:
	if site == null or player == null:
		return
	if site.cancel(player):
		hide_ui()

func _finish() -> void:
	if site == null or player == null:
		return
	BuildFlow.complete(player, site)
	site = null
	_site_mode = false
	hide_ui()

# ---------------------------------------------------------------- layout and widgets

func _compact() -> bool:
	return UiTokens.is_compact(get_viewport_rect().size)

func _layout() -> void:
	if _drawer == null:
		return
	var view := get_viewport_rect().size
	if view.x < 8.0:
		return
	var safe := UiTokens.safe_insets(get_viewport())
	var compact := _compact()
	# Full height from the left edge: it covers the HUD's left column (vitals, rail) instead of letting
	# their edges peek out around a floating panel.
	var w := (minf(view.x * 0.42, 312.0) if compact else 494.0) + safe.w
	_drawer.position = Vector2.ZERO
	_drawer.size = Vector2(w, view.y)
	_title.add_theme_font_size_override("font_size", 24 if compact else 34)
	_move_btn.text = "Move" if compact else "Move buildings"
	_move_btn.custom_minimum_size = Vector2(92 if compact else 150, TAP)
	_stock.add_theme_font_size_override("font_size", 13 if compact else 18)
	_stock.custom_minimum_size = Vector2(0, 32 if compact else 44)
	# Banner and cost bar sit over the world right of the drawer, clear of the HUD's top-right map
	# column and the bottom XP line.
	var free_l := _drawer.position.x + _drawer.size.x + 12.0
	var free_r := view.x - safe.x - (240.0 if compact else 450.0)
	var bw := maxf(160.0, free_r - free_l)
	(_banner.get_child(0) as Label).add_theme_font_size_override("font_size", 18 if compact else 28)
	(_banner.get_child(1) as Label).visible = not compact
	_banner.position = Vector2(free_l, safe.z + (6.0 if compact else 30.0))
	_banner.size = Vector2(bw, 0)
	_cost_bar.add_theme_font_size_override("font_size", 14 if compact else 20)
	var cw := minf(_cost_bar.get_combined_minimum_size().x, view.x - free_l - safe.x - 8.0)
	var ch := 32.0 if compact else 44.0
	var xp := UiTokens.xp_line_zone(view)
	_cost_bar.size = Vector2(cw, ch)
	_cost_bar.position = Vector2(clampf(view.x * 0.5 - cw * 0.5, free_l, view.x - safe.x - cw - 8.0), xp.position.y - ch - 6.0)

func _mk_footer(text: String, cb: Callable, kind: String = "ghost") -> Button:
	var b := CraftUI.mk_btn(text, cb, Vector2(0, TAP), kind)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15 if _compact() else 18)
	_footer.add_child(b)
	_footer.visible = true
	return b

func _pad(c: Control, side: int, v: int) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", side)
	mc.add_theme_constant_override("margin_right", side)
	mc.add_theme_constant_override("margin_top", v)
	mc.add_theme_constant_override("margin_bottom", v)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(c)
	return mc

static func _item_name(id: StringName) -> String:
	var d := Data.item(id)
	return d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(id))

## "Branch ×6 · Fibre Stalk ×6" (display names; StructurePlacer.cost_text keeps the ids).
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in cost:
		parts.append("%s ×%d" % [_item_name(StringName(str(id))), int(cost[id])])
	return " · ".join(parts)
