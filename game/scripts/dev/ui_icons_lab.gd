extends Node3D
## W1-UIICONS acceptance: every white action icon (data/ui_icons.json) on the real HexButton
## and on dark and light panels at 24/32/48/64 px with its id. Pick a view with --icons=:
##   sheet (default)  every icon in a real 64 px HexButton over the lab world, id as caption
##   sizes:<page>     rows: id | dark 12 16 24 32 48 64 | light panel (ink tint) 24 32 48 |
##                    status chip today (18 px, 12 px icon) and per hook 6 (24 px, 16 px icon) | 72 px hex
##   hud              the real HUD with its legacy glyphs swapped for icons (preview of the hooks)
##   filter           linear vs linear-with-mipmaps at 24 and 32 px (the mipmap hook)
##   blind            every icon at 24 px on a 50 px hex, shuffled, numbered, no ids: a label-free
##                    read; the number -> id key is printed as [uiicons_lab] blind key
## Headless (no --shot) it loads every icon through UiIcons, prints [uiicons_lab] and exits.

const SIZES: Array[int] = [12, 16, 24, 32, 48, 64]
const LIGHT := Color(0.86, 0.85, 0.81, 0.97)
const ROW_H := 84.0
## Letter and word glyphs the HUD sets directly (no emoji to look up): lab-side map for the preview.
const WORD_GLYPHS := {"Auto": &"auto", "FEED": &"feed", "F": &"fire_ranged", "V": &"toxin", "C": &"siege", "S": &"snare"}

var _mode := "sheet"
var _page := 0
var _ids: Array[StringName] = []
var _hud: HuntHud
var _canvas: Control

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--icons="):
			var v := a.substr(8).split(":")
			_mode = v[0]
			_page = int(v[1]) if v.size() > 1 else 0
	var kit := LabKit.build(self, 40.0)
	var player: Player = kit["player"]
	if TouchControls:
		TouchControls.visible = false
	_ids = _unique_ids()
	var ui: CanvasLayer = kit["ui"]
	for c in ui.get_children():
		if c is HuntHud:
			_hud = c
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		_headless_check()
		return
	if _mode == "hud":
		LabKit.give(player, &"stone_knife", 1)
		await get_tree().process_frame
		await get_tree().process_frame
		_force_combat_cluster()
		return
	if _hud:
		_hud.visible = false
	# Only the hud view shows the game; elsewhere the live hands slot and the survivor muddy the sheet.
	player.visible = false
	for n in get_tree().root.find_children("*", "HeldItemSlot", true, false):
		(n as CanvasItem).visible = false
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.add_child(_canvas)
	await get_tree().process_frame
	match _mode:
		"sizes": _build_sizes()
		"filter": _build_filter()
		"blind": _build_blind()
		_: _build_sheet()
	_canvas.queue_redraw()

## One entry per drawing (aliases share files): the file name is the primary id.
func _unique_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var seen := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(UiIcons.MANIFEST))
	for id in (parsed as Dictionary)["icons"]:
		var file := str((parsed as Dictionary)["icons"][id]).get_file().get_basename()
		if not seen.has(file):
			seen[file] = true
			out.append(StringName(file))
	return out

func _hex(id: StringName, px: float) -> HexButton:
	var h := HexButton.new(px)
	h.icon = UiIcons.icon(id)
	h.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # integrator hook 1
	return h

func _build_sheet() -> void:
	var r := _canvas.size
	var cell := Vector2(100, 104)
	var cols := int((r.x - 24.0) / cell.x)
	var origin := Vector2((r.x - cell.x * cols) * 0.5 + 18.0, 24.0)
	for i in _ids.size():
		var h := _hex(_ids[i], 64.0)
		h.caption = str(_ids[i])
		h.position = origin + Vector2(i % cols, i / cols) * cell
		_canvas.add_child(h)
	print("[uiicons_lab] sheet %d icons, %d columns, view %s" % [_ids.size(), cols, r])

## Label-free read: shuffled with a fixed seed so the key printed here matches the screenshot.
func _build_blind() -> void:
	var order := _ids.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: StringName = order[i]
		order[i] = order[j]
		order[j] = t
	var r := _canvas.size
	var cell := Vector2(78, 70)
	var cols := int((r.x - 24.0) / cell.x)
	var origin := Vector2((r.x - cell.x * cols) * 0.5 + 14.0, 14.0)
	var key: Array[String] = []
	for i in order.size():
		var h := _hex(order[i], 50.0)  # hex radius 23 -> HexButton draws the icon at 24 px
		h.top_text = str(i + 1)
		h.position = origin + Vector2(i % cols, i / cols) * cell
		_canvas.add_child(h)
		key.append("%d=%s" % [i + 1, order[i]])
	print("[uiicons_lab] blind key %s" % " ".join(key))

func _build_sizes() -> void:
	var r := _canvas.size
	var rows := int((r.y - 24.0) / ROW_H)
	var col_w := 780.0
	var cols := maxi(1, int(r.x / col_w))
	var per := rows * cols
	var first := _page * per
	for k in range(first, mini(first + per, _ids.size())):
		var slot := k - first
		var o := Vector2(16.0 + float(slot / rows) * col_w, 16.0 + float(slot % rows) * ROW_H)
		var h := _hex(_ids[k], 72.0)
		h.position = o + Vector2(688.0, 2.0)
		_canvas.add_child(h)
	_canvas.draw.connect(_draw_sizes.bind(first, rows, col_w, per))
	print("[uiicons_lab] sizes page %d of %d (%d per page)" % [_page, int(ceil(_ids.size() / float(per))) - 1, per])

func _draw_sizes(first: int, rows: int, col_w: float, per: int) -> void:
	var font := ThemeDB.fallback_font
	for k in range(first, mini(first + per, _ids.size())):
		var slot := k - first
		var o := Vector2(16.0 + float(slot / rows) * col_w, 16.0 + float(slot % rows) * ROW_H)
		var tex := UiIcons.icon(_ids[k])
		_canvas.draw_rect(Rect2(o, Vector2(col_w - 20.0, ROW_H - 6.0)), Color(0, 0, 0, 0.35))
		_canvas.draw_string(font, o + Vector2(8, 44), str(_ids[k]), HORIZONTAL_ALIGNMENT_LEFT, 150, 16, UiTokens.TEXT)
		_canvas.draw_rect(Rect2(o + Vector2(160, 4), Vector2(276, 70)), UiTokens.INK)
		var x := o.x + 170.0
		for px in SIZES:
			_canvas.draw_texture_rect(tex, Rect2(Vector2(x, o.y + 39.0 - px * 0.5), Vector2(px, px)), false)
			x += px + 10.0
		_canvas.draw_rect(Rect2(o + Vector2(442, 4), Vector2(150, 70)), LIGHT)
		x = o.x + 452.0
		for px: int in [24, 32, 48]:
			_canvas.draw_texture_rect(tex, Rect2(Vector2(x, o.y + 39.0 - px * 0.5), Vector2(px, px)), false, UiTokens.INK_SOLID)
			x += px + 10.0
		_draw_chip(tex, o + Vector2(618, 39), 18.0, 12.0)
		_draw_chip(tex, o + Vector2(652, 39), 24.0, 24.0 * 0.42 * 1.6)

## A creature-plate status chip as status_glyph.gd draws it: dark disc, countdown ring, icon.
func _draw_chip(tex: Texture2D, c: Vector2, chip: float, icon_px: float) -> void:
	var r := chip * 0.42
	_canvas.draw_circle(c, r, Color(0.05, 0.05, 0.05, 0.82))
	_canvas.draw_arc(c, r, -PI * 0.5, PI * 0.9, 32, Color(0.95, 0.3, 0.3), 2.6, true)
	_canvas.draw_texture_rect(tex, Rect2(c - Vector2.ONE * icon_px * 0.5, Vector2.ONE * icon_px), false)

func _build_filter() -> void:
	for row in 2:
		var mip := row == 1
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if mip else CanvasItem.TEXTURE_FILTER_LINEAR
		c.draw.connect(_draw_filter_row.bind(c, 40.0 + row * 120.0, "linear + mipmaps (hook)" if mip else "linear (default canvas filter)"))
		_canvas.add_child(c)

func _draw_filter_row(c: Control, y: float, label: String) -> void:
	c.draw_rect(Rect2(16, y - 8.0, c.size.x - 32.0, 100.0), UiTokens.INK)
	c.draw_string(ThemeDB.fallback_font, Vector2(28, y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, 220, 16, UiTokens.TEXT)
	var x := 260.0
	for k in mini(20, _ids.size()):
		var tex := UiIcons.icon(_ids[k])
		c.draw_texture_rect(tex, Rect2(Vector2(x, y), Vector2(24, 24)), false)
		c.draw_texture_rect(tex, Rect2(Vector2(x, y + 38.0), Vector2(32, 32)), false)
		x += 64.0

## Preview of the integrator hooks on the real HUD: every glyph that has an icon becomes the icon.
func _process(_delta: float) -> void:
	if _mode != "hud" or _hud == null:
		return
	for n in _hud.find_children("*", "HexButton", true, false):
		var h := n as HexButton
		if h.glyph == "":
			continue
		var tex: Texture2D = UiIcons.icon(WORD_GLYPHS[h.glyph]) if WORD_GLYPHS.has(h.glyph) else UiIcons.for_glyph(h.glyph)
		if tex:
			if h.glyph == "Auto":
				h.caption = "AUTO"  # hook 3: the word was its only label
			h.icon = tex
			h.glyph = ""
			h.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			h.queue_redraw()
	for n in get_tree().root.find_children("*", "HeldItemSlot", true, false):
		var slot := n as HeldItemSlot
		var bare := {"HANDS": &"hands", "FISTS": &"fists"}
		if bare.has(slot._caption):
			slot._icon = UiIcons.icon(bare[slot._caption])
			slot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _force_combat_cluster() -> void:
	for h in _hud._skill_hexes:
		h.visible = true
	for h in [_hud._auto_hex, _hud._chase_hex, _hud._feed_hex]:
		h.visible = true
	for i in mini(3, _hud._whistle_hexes.size()):
		_hud._whistle_hexes[i].visible = true
	_hud._layout()

func _headless_check() -> void:
	var missing: Array[String] = []
	for id in _ids:
		var tex := UiIcons.icon(id)
		if tex == null or tex.get_width() != 128 or not tex.get_image().has_mipmaps():
			missing.append(str(id))
	var fb := UiIcons.icon(&"no_such_action")
	var ok := missing.is_empty() and fb != null and fb == UiIcons.icon(&"action")
	print("[uiicons_lab] icons=%d bad=%s fallback=%s" % [_ids.size(), missing, fb != null])
	get_tree().quit(0 if ok else 1)
