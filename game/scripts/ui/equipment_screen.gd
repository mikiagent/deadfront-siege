class_name EquipmentScreen
extends GearScreen
## Equipment / My Info (spec 13 s15, reference durango-equipment-myinfo): the 3x3 gear cells on the
## left; centre, the tan "My Info" band over Attack / Defense / Accuracy and the hexagon row of
## combat tactics; right, what fits the selected cell over Equip. Picking a candidate previews its
## numbers on a copy of the bag (InvStats.with_candidate) as "58 → 61 +3" and lists every other
## change, so the player compares before wearing it; nothing changes until Equip.

const INFO := [["attack", "Attack"], ["defense", "Defense"], ["accuracy", "Accuracy"]]

var hexes: Array[HexButton] = []
var _grid_panel: Control
var _info: Control
var _tactics: Control
var _tactic_line: Label
var _changes: Label
var _base := {}
var _cand := {}

func _build_body() -> void:
	_grid_panel = _panel(4.0)
	_info = _panel(6.0, Color("#5A5846")) # lighter khaki under My Info, so its dark icons read (reference)
	_info.draw.connect(_draw_info)
	_tactics = _panel(7.0)
	var hx: Dictionary = InvView.data().get("hex_tactics", {})
	for id: String in hx.get("ids", []):
		var h := HexButton.new(72.0)
		h.icon = UiIcons.icon(StringName(id))
		h.tooltip_text = _tactic_text(id)
		h.pressed.connect(func() -> void: _tactic_line.text = _tactic_text(id))
		_tactics.add_child(h)
		hexes.append(h)
	_tactic_line = _label(_tactics, InvTheme.TEXT_2)
	_changes = _label(_info, InvTheme.TEXT)

func _ready() -> void:
	header.set_title("Equipment")

func _panel(seed_v: float, tint: Color = InvTheme.PANEL) -> Control:
	var c := Control.new()
	c.clip_contents = true
	var surf := InvTheme.surface(tint, 1.1, seed_v)
	surf.show_behind_parent = true # the panel's own drawing (My Info) goes over it
	c.add_child(surf)
	c.draw.connect(func() -> void: InvPaint.frame(c, Rect2(Vector2.ZERO, c.size), 2.0 if _m.get("compact", false) else 3.0, int(seed_v)))
	add_child(c)
	return c

func _label(parent: Control, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## "Tackle: lunge ... 15 stamina, 8 s cooldown." from data/inv_ui.json and combat_tuning.json.
static func _tactic_text(id: String) -> String:
	var line := str(((InvView.data().get("hex_tactics", {}) as Dictionary).get("lines", {}) as Dictionary).get(id, id.capitalize()))
	var t := CombatTuning.section(id)
	if t.has("stamina") and t.has("cooldown"):
		line += " %d stamina, %d s cooldown." % [int(t.stamina), int(t.cooldown)]
	return line

## Open on cell `s` with bag candidate `uid` picked (the Bag's or Character's Equip).
func preselect(s: StringName, uid: String = "") -> void:
	select_slot(s)
	if uid != "":
		list.select_uid(uid)

func _right_share() -> float:
	return 0.25

func _update() -> void:
	if player:
		_base = InvStats.snapshot(player)
		var p := picked()
		_cand = InvStats.with_candidate(player, list.selected_index(), slot) if p and p != worn() and not p.is_locked() else {}
	var lines := PackedStringArray()
	var p2 := picked()
	if p2 and p2 != worn():
		var w := worn()
		lines.append("Replaces: %s" % (_name(w) if w else "nothing (empty slot)"))
		for d: Array in InvStats.diff(_base, _cand):
			if not str(d[0]) in ["Attack", "Defense", "Accuracy"]:
				lines.append("%s  %s → %s" % d.slice(0, 3))
		if _cand.is_empty() and not p2.is_locked():
			lines.append("Bag is full: it cannot be worn now.")
	if _changes:
		_changes.text = "\n".join(lines)
		_info.queue_redraw()
	super._update()

static func _name(s: ItemStack) -> String:
	var d := s.def()
	return "%s %s" % [d.display_name if d and d.display_name != "" else str(s.def_id), LevelDisplay.label(s.level)]

## The three My Info numbers as shown: "58", or "58 → 61 +3" while a candidate is picked.
func info_text(key: String) -> String:
	var a := roundi(float(_base.get(key, 0)))
	var b := roundi(float(_cand.get(key, a)))
	if _cand.is_empty() or b == a:
		return InvStats.fmt(key, a)
	return "%s → %s %s%d" % [InvStats.fmt(key, a), InvStats.fmt(key, b), "+" if b > a else "−", absi(b - a)]

func _layout_body(area: Rect2) -> void:
	var m := _m
	var gap: float = m.gap
	var left_w := floorf(area.size.x * 0.5) # reference 3: 35 % : 33 % of the width
	_grid_panel.position = area.position
	_grid_panel.size = Vector2(left_w, area.size.y)
	EquipmentSlot.layout(cells, Rect2(area.position, _grid_panel.size).grow(-4.0), maxi(UiTokens.TYPE_MIN, int(m.lv_font) - 2))
	var cx: float = area.position.x + left_w + gap
	var cw: float = area.end.x - cx
	# The compare lines under the numbers set My Info's height when they need more than its share
	# (a notched phone cut "Max health 100 → 156" off); the tactics keep room for 44 px hexes.
	var cpx := int(m.row_font) - (2 if m.compact else 4)
	_changes.add_theme_font_size_override("font_size", cpx)
	var ls := -roundi(cpx * 0.45) # the font's tall line box read as gaps between the lines
	_changes.add_theme_constant_override("line_spacing", ls)
	_changes.size = Vector2(cw - float(m.margin) * 2.0, 0.0)
	var top := _cols_rect().end.y + 4.0
	var pitch := float(_changes.get_line_height()) + ls
	var need := top + float(_changes.get_line_count()) * pitch - ls + float(m.margin) * 0.5 if _changes.text != "" else 0.0
	var info_h := minf(maxf(floorf(area.size.y * (0.62 if m.compact else 0.56)), ceilf(need)), area.size.y - gap - 44.0 - float(m.margin) * 1.5)
	_info.position = Vector2(cx, area.position.y)
	_info.size = Vector2(cw, info_h)
	_tactics.position = Vector2(cx, area.position.y + info_h + gap)
	_tactics.size = Vector2(cw, area.size.y - info_h - gap)
	var hs := clampf(_tactics.size.y * 0.5, 44.0, 96.0)
	for i in hexes.size():
		hexes[i].custom_minimum_size = Vector2(hs, hs)
		hexes[i].size = Vector2(hs, hs)
		hexes[i].pivot_offset = hexes[i].size * 0.5
		hexes[i].position = Vector2(float(m.margin) + i * (hs + 8.0), float(m.margin) * 0.5)
	_tactic_line.add_theme_font_size_override("font_size", int(m.row_font) - (0 if m.compact else 2))
	_tactic_line.position = Vector2(m.margin, hs + float(m.margin) * 0.75)
	_tactic_line.size = Vector2(cw - float(m.margin) * 2.0, _tactics.size.y - _tactic_line.position.y)
	_changes.position = Vector2(m.margin, top)
	_changes.size = Vector2(cw - float(m.margin) * 2.0, maxf(0.0, info_h - top))
	_changes.max_lines_visible = maxi(1, floori((info_h - top - ls) / maxf(1.0, pitch))) # never a half-cut line
	_info.queue_redraw()

## Tan band, then the three columns (icon, black label band, number).
func _band_h() -> float:
	return roundf(float(_m.name_font) * (1.6 if _m.compact else 1.9))

func _cols_rect() -> Rect2:
	var big := float(_m.name_font) * (1.3 if _m.compact else 1.6)
	var h: float = _band_h() * 0.2 + _icon_px() + float(_m.row_h) + big * 1.5 + float(_m.row_font) * 1.4 # + the "321 → 1102 +781" line
	return Rect2(Vector2(0, _band_h()), Vector2(_info.size.x, h))

func _icon_px() -> float:
	return roundf(float(_m.name_font) * (1.5 if _m.compact else 2.4))

func _draw_info() -> void:
	if _m.is_empty():
		return
	var f := InvTheme.font()
	var w := _info.size.x
	var band := Rect2(Vector2.ZERO, Vector2(w, _band_h()))
	_info.draw_rect(band, InvTheme.TAN)
	_info.draw_dashed_line(Vector2(0, band.end.y), Vector2(w, band.end.y), Color(0, 0, 0, 0.45), 1.5, 5.0)
	UiTokens.draw_centered(_info, f, band.get_center(), "My Info", int(_m.name_font) - (0 if _m.compact else 4), InvTheme.PRIMARY_INK)
	var cols := _cols_rect()
	var cw := w / 3.0
	var ip := _icon_px()
	var lpx := int(_m.row_font)
	var big := int(float(_m.name_font) * (1.3 if _m.compact else 1.6))
	for i in INFO.size():
		var key: String = INFO[i][0]
		var x := cw * i
		if i > 0:
			_info.draw_line(Vector2(x, cols.position.y + 12.0), Vector2(x, cols.end.y - 8.0), Color(0, 0, 0, 0.4), 1.5)
		var icon_r := Rect2(Vector2(x + (cw - ip) * 0.5, cols.position.y + _band_h() * 0.2), Vector2(ip, ip))
		var tex := UiIcons.icon(StringName(key)) if key != "accuracy" else null
		var ink := Color(0.06, 0.06, 0.05) # the reference draws these three dark on khaki
		if tex:
			_info.draw_texture_rect(tex, icon_r, false, ink)
		else:
			InvGlyphs.target(_info, icon_r, ink)
		var lab := Rect2(Vector2(x + 6.0, icon_r.end.y + 6.0), Vector2(cw - 12.0, _m.row_h))
		_info.draw_rect(lab, Color(0.02, 0.02, 0.02, 0.92))
		UiTokens.draw_centered(_info, f, lab.get_center(), str(INFO[i][1]), lpx, InvTheme.TEXT)
		var text := info_text(key)
		var cy := lab.end.y + big * 0.85
		var parts := text.split(" ")
		if parts.size() == 1:
			UiTokens.draw_centered(_info, f, Vector2(x + cw * 0.5, cy), text, big, InvTheme.TEXT)
		else: # "58 → 61 +3": the new number large, the old one and the change small under it
			UiTokens.draw_centered(_info, f, Vector2(x + cw * 0.5, cy), parts[2], big, InvTheme.POSITIVE if parts[3].begins_with("+") else InvTheme.TEXT_2)
			UiTokens.draw_centered(_info, f, Vector2(x + cw * 0.5, cy + big * 0.8), "%s → %s  %s" % [parts[0], parts[2], parts[3]], maxi(UiTokens.TYPE_MIN, lpx - 2), InvTheme.POSITIVE if parts[3].begins_with("+") else InvTheme.TEXT_2)
