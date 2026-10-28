class_name CommsUI
extends UiWorldSheet
## F3 Communication (docs/design/ui-redesign-spec.md §7 F3; systems PRD §15.1): the support
## organisations from data/world/factions.json, one row each (icon, name, rank line, a trust bar per
## rank), and the selected faction's detail: parchment header (name, tone), three mission offers with
## Accept / Abandon, the support-crate band for the current rank band, and Reroll offers / Contribute /
## Track on HUD. The header counts active missions (PRD: up to 4) and free rerolls (PRD: 3).
## Radio University is its own screen (RadioUniversityUI: career guides, no crates) [owner].
## Contribute opens the spec-29 contribution panel (CommCenterUI) that raises the Pioneer rank.
##
## ASSUMPTION: no faction, trust or mission logic exists in game/scripts yet. Everything here reads
## the data file and shows honest empty states: trust 0 (rank 0) for every faction, offers are the
## first three entries of the faction's mission_pool shown as a preview, and Accept / Reroll / Track
## are disabled with the reason. No quest mechanics are invented here.

const PATH := "res://data/world/factions.json"
const MAX_ACTIVE := 4  ## PRD §15.1: multiple active, up to 4 around level 20
const FREE_REROLLS := 3  ## PRD §15.1: 3 free rerolls, then Warp Gems
const OFFERS := 3
const RANKS := 10
const ICONS := {
	"company": &"harbour",
	"chlorophyll_forum": &"farming",
	"pioneer_council": &"defense",
	"committee": &"lock",
	"radio_university": &"chat",
}
const NOT_LIVE := "Missions are not in this build yet."

var player: Player
var factions: Array[Dictionary] = []  ## [{id, ...json row}] in file order
var selected := ""
var radio: RadioUniversityUI
var center_ui: CommCenterUI

var _list_panel: PanelContainer
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Dictionary = {}  ## id -> Button
var _detail: PanelContainer
var _parch: PanelContainer
var _d_name: Label
var _d_tone: Label
var _offers_head: Label
var _detail_scroll: ScrollContainer
var _offers: VBoxContainer
var _crate_head: Label
var _crate_row: HFlowContainer
var _foot: HBoxContainer
var _reroll: Button
var _contribute: Button
var _track: Button
var _radio_open: Button
var _why: Label

func _init() -> void:
	super("Communication")

static func load_factions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(PATH):
		return out
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not raw is Dictionary:
		return out
	for key in (raw as Dictionary).keys():
		var row: Variant = raw[key]
		if str(key).begins_with("_") or not row is Dictionary:
			continue
		var d: Dictionary = (row as Dictionary).duplicate(true)
		d["id"] = str(key)
		out.append(d)
	return out

## "gather_herbs" -> "Gather herbs".
static func pretty(id: String) -> String:
	var s := id.replace("_", " ").strip_edges()
	return s.left(1).to_upper() + s.substr(1) if s != "" else s

## ASSUMPTION: trust is not tracked anywhere yet, so every faction is at rank 0.
static func trust_rank(_id: String) -> int:
	return 0

## The crate band key ("1-3") that holds `rank` (rank 0 reads the first band: what rank 1 unlocks).
static func crate_band(f: Dictionary, rank: int) -> String:
	var bands: Dictionary = f.get("crate_bands", {})
	for key in bands.keys():
		var parts := str(key).split("-")
		if parts.size() == 2 and maxi(rank, 1) >= int(parts[0]) and maxi(rank, 1) <= int(parts[1]):
			return str(key)
	return str(bands.keys()[0]) if not bands.is_empty() else ""

func is_locked(f: Dictionary) -> bool:
	return unlock_level(f) > char_level()

static func unlock_level(f: Dictionary) -> int:
	return int(f.get("unlock_level", 0))

func char_level() -> int:
	return player.skills.character_level() if player != null and player.skills != null else 1

func _build() -> void:
	name = "CommsUI"
	back_pressed.connect(close)
	close_pressed.connect(close)
	factions = load_factions()
	_list_panel = UiWorldSheet.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
	_list_panel.name = "Factions"
	body.add_child(_list_panel)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_panel.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	for f in factions:
		var id := str(f["id"])
		var b := _faction_row(f)
		b.pressed.connect(func () -> void: select(id))
		_rows[id] = b
		_list.add_child(b)

	_detail = UiWorldSheet.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
	_detail.name = "Detail"
	body.add_child(_detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 0)
	_detail.add_child(dv)
	_parch = PanelContainer.new()
	_parch.name = "Parchment"
	_parch.add_theme_stylebox_override("panel", UiWorldSheet.parchment_style())
	dv.add_child(_parch)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	_parch.add_child(pv)
	_d_name = UiWorldSheet.label("", 30, UiTokens.PARCHMENT_INK, true)
	_d_name.name = "Name"
	pv.add_child(_d_name)
	_d_tone = UiWorldSheet.label("", 17, UiTokens.PARCHMENT_INK)
	_d_tone.name = "Tone"
	_d_tone.clip_text = true
	pv.add_child(_d_tone)
	_offers_head = _band_label("Mission offers")
	dv.add_child(_offers_head.get_parent())
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_detail_scroll)
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 0)
	_detail_scroll.add_child(sv)
	_offers = VBoxContainer.new()
	_offers.name = "Offers"
	_offers.add_theme_constant_override("separation", 0)
	sv.add_child(_offers)
	_why = UiWorldSheet.label(NOT_LIVE, 15, UiTokens.MUTED)
	_why.name = "Why"
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var why_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		why_pad.add_theme_constant_override("margin_" + s, 12)
	why_pad.add_child(_why)
	sv.add_child(why_pad)
	_radio_open = UiWorldSheet.gold_button("Open Radio University")
	_radio_open.name = "OpenRadio"
	_radio_open.pressed.connect(open_radio)
	var radio_pad := MarginContainer.new()
	for s in ["left", "right"]:
		radio_pad.add_theme_constant_override("margin_" + s, 16)
	radio_pad.add_child(_radio_open)
	sv.add_child(radio_pad)
	var crate_box := VBoxContainer.new()
	crate_box.name = "Crate"
	crate_box.add_theme_constant_override("separation", 8)
	var crate_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		crate_pad.add_theme_constant_override("margin_" + s, 16)
	crate_pad.add_child(crate_box)
	sv.add_child(crate_pad)
	_crate_head = UiWorldSheet.label("", 15, UiTokens.MUTED)
	_crate_head.name = "CrateHead"
	crate_box.add_child(_crate_head)
	_crate_row = HFlowContainer.new()
	_crate_row.name = "CrateItems"
	_crate_row.add_theme_constant_override("h_separation", 8)
	_crate_row.add_theme_constant_override("v_separation", 6)
	crate_box.add_child(_crate_row)
	var foot_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		foot_pad.add_theme_constant_override("margin_" + s, 12)
	dv.add_child(foot_pad)
	_foot = HBoxContainer.new()
	_foot.name = "Foot"
	_foot.add_theme_constant_override("separation", 10)
	foot_pad.add_child(_foot)
	_reroll = UiWorldSheet.ghost_button("Reroll offers")
	_reroll.name = "Reroll"
	_contribute = UiWorldSheet.ghost_button("Contribute →")
	_contribute.name = "Contribute"
	_contribute.pressed.connect(open_contribution)
	_track = UiWorldSheet.gold_button("Track on HUD")
	_track.name = "Track"
	for b in [_reroll, _contribute, _track]:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_foot.add_child(b)
	# ASSUMPTION: rerolls and tracking need live missions; disabled until they exist.
	_reroll.disabled = true
	_track.disabled = true
	_reroll.tooltip_text = NOT_LIVE
	_track.tooltip_text = NOT_LIVE

func _band_label(text: String) -> Label:
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UiWorldSheet._box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0))
	var l := UiWorldSheet.label(text, 20, UiTokens.TEXT)
	band.add_child(l)
	return l

func _faction_row(f: Dictionary) -> Button:
	var id := str(f["id"])
	var b := Button.new()
	b.name = "Faction_%s" % id
	b.toggle_mode = true
	b.clip_contents = true
	b.add_theme_stylebox_override("focus", UiWorldSheet._box(Color(0, 0, 0, 0), UiTokens.GOLD, 1))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var ic := UiWorldSheet.icon_rect(ICONS.get(id, &"chat"), 48.0)
	ic.name = "Icon"
	row.add_child(ic)
	var names := VBoxContainer.new()
	names.name = "Names"
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	var nl := UiWorldSheet.label(str(f.get("name", id)), 26, UiTokens.TEXT)
	nl.name = "Name"
	nl.clip_text = true
	names.add_child(nl)
	var sub := UiWorldSheet.label("", 17, UiTokens.MUTED)
	sub.name = "Sub"
	sub.clip_text = true
	names.add_child(sub)
	var trust := VBoxContainer.new()
	trust.name = "Trust"
	trust.alignment = BoxContainer.ALIGNMENT_CENTER
	trust.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trust)
	var tl := UiWorldSheet.label("", 16, UiTokens.TEXT)
	tl.name = "TrustLine"
	trust.add_child(tl)
	var bar := _TrustBar.new()
	bar.name = "Bar"
	trust.add_child(bar)
	var mark := UiWorldSheet.Brackets.new()
	mark.name = "Brackets"
	b.add_child(mark)
	return b

# ---------------------------------------------------------------- open / select

func open(p: Player) -> void:
	player = p
	visible = true
	if selected == "" and not factions.is_empty():
		selected = str(factions[0]["id"])
	set_counter("Active missions [color=#%s]0[/color] / %d · Free rerolls [color=#%s]%d[/color]" % [UiTokens.GOLD.to_html(false), MAX_ACTIVE, UiTokens.GOLD.to_html(false), FREE_REROLLS])
	_refresh()
	relayout()
	if _rows.has(selected):
		UiTokens.focus_first([_rows[selected]])

func close() -> void:
	if radio != null and is_instance_valid(radio):
		radio.close()
	if center_ui != null and is_instance_valid(center_ui):
		center_ui.close()
	visible = false

func is_open() -> bool:
	return visible

func select(id: String) -> void:
	selected = id
	_refresh()
	relayout()

func faction(id: String) -> Dictionary:
	for f in factions:
		if str(f["id"]) == id:
			return f
	return {}

## Radio University is a separate screen [owner]; Back there returns here.
func open_radio() -> void:
	if radio == null or not is_instance_valid(radio):
		radio = RadioUniversityUI.new()
		get_parent().add_child(radio)
		radio.back_pressed.connect(func () -> void: radio.close(); open(player))
	radio.open(player)
	visible = false

## The spec-29 contribution panel (Pioneer rank), as a modal over this sheet.
func open_contribution() -> void:
	if center_ui == null or not is_instance_valid(center_ui):
		center_ui = CommCenterUI.new()
		add_child(center_ui)
		center_ui.closed.connect(func () -> void: _chrome(true); _refresh())
	_chrome(false)
	center_ui.open(player)

func _chrome(on: bool) -> void:
	backdrop.visible = on
	header.visible = on
	body.visible = on

func _refresh() -> void:
	for f in factions:
		var id := str(f["id"])
		var b: Button = _rows[id]
		var on := id == selected
		var locked := is_locked(f)
		b.set_pressed_no_signal(on)
		var sb := UiWorldSheet._box(UiTokens.GOLD_DIM if on else Color(0, 0, 0, 0), Color(1, 1, 1, 0.06), 1)
		sb.border_width_top = 0
		sb.border_width_left = 0
		sb.border_width_right = 0
		for s in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		var dim := 0.45 if locked else 1.0
		var ink := UiTokens.GOLD if on else UiTokens.TEXT
		(b.find_child("Name", true, false) as Label).add_theme_color_override("font_color", Color(ink, dim))
		(b.find_child("Icon", true, false) as TextureRect).modulate = Color(UiTokens.TEXT, dim)
		var rank := trust_rank(id)
		var sub := b.find_child("Sub", true, false) as Label
		if locked:
			sub.text = "Locked · Lv. %d" % unlock_level(f)
		elif bool(f.get("career_guides", false)):
			sub.text = "Career guides · no crates"
		else:
			sub.text = "Rank %d" % rank
		sub.add_theme_color_override("font_color", Color(UiTokens.MUTED, dim))
		var tl := b.find_child("TrustLine", true, false) as Label
		var ranks := int(f.get("ranks", RANKS))
		tl.text = "Trust · rank %d / %d" % [rank, ranks] if not bool(f.get("career_guides", false)) else "Reputation from career guides"
		tl.add_theme_color_override("font_color", Color(UiTokens.TEXT, dim))
		var bar := b.find_child("Bar", true, false) as _TrustBar
		bar.ratio = float(rank) / float(maxi(1, ranks))
		if bool(f.get("career_guides", false)):
			bar.text = "0 / %d guides" % (f.get("guides", []) as Array).size()
		else:
			bar.text = "No trust yet" if rank == 0 else "%d / %d" % [rank, ranks]
		bar.dim = dim
		bar.queue_redraw()
		(b.find_child("Brackets", true, false) as Control).visible = on
	_fill_detail(faction(selected))

func _fill_detail(f: Dictionary) -> void:
	for c in _offers.get_children():
		c.queue_free()
	for c in _crate_row.get_children():
		c.queue_free()
	if f.is_empty():
		_d_name.text = "No factions"
		_d_tone.text = "data/world/factions.json is missing or empty."
		return
	var id := str(f["id"])
	_d_name.text = str(f.get("name", id))
	_d_tone.text = pretty(str(f.get("tone", "")))
	var guides := bool(f.get("career_guides", false))
	var locked := is_locked(f)
	_offers_head.text = "Career guides" if guides else "Mission offers"
	_radio_open.visible = guides
	_crate_head.get_parent().visible = bool(f.get("crates", false))
	if guides:
		_why.text = "Dr. Lamar's one-man university: no crates, no fetch quests. Career guides are checklists of skills practised; each earns %d SP." % int(f.get("sp_per_guide", 0))
	elif locked:
		_why.text = "Unlocks at character level %d (you are %d)." % [unlock_level(f), char_level()]
	else:
		_why.text = NOT_LIVE + " The offers above preview this faction's mission pool."
	if not guides:
		var pool: Array = f.get("mission_pool", [])
		for i in mini(OFFERS, pool.size()):
			_offers.add_child(_offer_row(str(pool[i]), f, locked))
	var rank := trust_rank(id)
	var band := crate_band(f, rank)
	var lo_hi := band.split("-")
	_crate_head.text = "SUPPORT CRATE · RANKS %s" % band.replace("-", "–") + ("" if rank >= int(lo_hi[0]) else "  (rank %s unlocks)" % lo_hi[0])
	for item_id in (f.get("crate_bands", {}) as Dictionary).get(band, []):
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiWorldSheet._box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0))
		var def := Data.item(StringName(str(item_id)))
		chip.add_child(UiWorldSheet.label(def.display_name if def != null and def.display_name != "" else pretty(str(item_id)), 16, UiTokens.TEXT))
		_crate_row.add_child(chip)

func _offer_row(mission: String, f: Dictionary, locked: bool) -> Control:
	var pad := MarginContainer.new()
	pad.name = "Offer_%s" % mission
	for s in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + s, 16)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var compact := UiTokens.is_compact(get_viewport_rect().size)
	var t := UiWorldSheet.label(pretty(mission), 16 if compact else 22, UiTokens.TEXT)
	t.clip_text = true
	col.add_child(t)
	var pin := UiWorldSheet.label("Pin and turn-in: not set (missions not live)", 12 if compact else 15, UiTokens.MUTED)
	pin.clip_text = true
	col.add_child(pin)
	var mult := float(f.get("reward_multiplier", 1.0))
	var rw := "+%d trust" % int(f.get("trust_per_mission", 0))
	if mult != 1.0:
		rw += " · rewards x%.1f" % mult
	col.add_child(UiWorldSheet.label(rw, 12 if compact else 15, UiTokens.GOLD))
	var accept := UiWorldSheet.gold_button("Accept")
	accept.name = "Accept"
	accept.disabled = true  # ASSUMPTION: no mission state to accept into (see header)
	accept.tooltip_text = "Locked" if locked else NOT_LIVE
	accept.custom_minimum_size = Vector2(96.0 if compact else 120.0, 64.0)
	accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accept.add_theme_font_size_override("font_size", 16 if compact else 20)
	row.add_child(accept)
	return pad

# ---------------------------------------------------------------- layout

func _layout_body(view: Vector2, rect: Rect2) -> void:
	var compact := UiTokens.is_compact(view)
	var gap := 8.0 if compact else 20.0
	var lw := floorf((rect.size.x - gap) * (0.5 if compact else 0.56))
	_list_panel.position = rect.position
	_list_panel.size = Vector2(lw, rect.size.y)
	_detail.position = Vector2(rect.position.x + lw + gap, rect.position.y)
	_detail.size = Vector2(rect.size.x - lw - gap, rect.size.y)
	var n := maxi(1, factions.size())
	var row_h := maxf(64.0, floorf(rect.size.y / float(n)))
	for f in factions:
		var b: Button = _rows[str(f["id"])]
		b.custom_minimum_size = Vector2(0.0, row_h)
		var row := b.get_node("Row") as HBoxContainer
		row.add_theme_constant_override("separation", 10 if compact else 24)
		row.offset_left = 10.0 if compact else 28.0
		row.offset_right = -(10.0 if compact else 26.0)
		(b.find_child("Icon", true, false) as Control).custom_minimum_size = Vector2.ONE * (26.0 if compact else 52.0)
		var names := b.find_child("Names", true, false) as Control
		names.custom_minimum_size.x = 140.0 if compact else 240.0
		(b.find_child("Name", true, false) as Label).add_theme_font_size_override("font_size", 15 if compact else 26)
		(b.find_child("Sub", true, false) as Label).add_theme_font_size_override("font_size", 12 if compact else 17)
		(b.find_child("TrustLine", true, false) as Label).add_theme_font_size_override("font_size", 12 if compact else 16)
		var bar := b.find_child("Bar", true, false) as _TrustBar
		bar.custom_minimum_size.y = 18.0 if compact else 30.0
		bar.px = 11 if compact else 16
	_d_name.add_theme_font_size_override("font_size", 18 if compact else 30)
	_d_tone.add_theme_font_size_override("font_size", 12 if compact else 17)
	var ps := _parch.get_theme_stylebox("panel") as StyleBoxTexture
	ps.content_margin_left = 10 if compact else 20
	ps.content_margin_top = 4 if compact else 10
	ps.content_margin_bottom = 4 if compact else 10
	_offers_head.add_theme_font_size_override("font_size", 14 if compact else 20)
	_why.add_theme_font_size_override("font_size", 12 if compact else 15)
	_crate_head.add_theme_font_size_override("font_size", 12 if compact else 15)
	for c in _crate_row.get_children():
		(c.get_child(0) as Label).add_theme_font_size_override("font_size", 12 if compact else 16)
	_radio_open.custom_minimum_size = Vector2(0.0, 64.0)
	_radio_open.add_theme_font_size_override("font_size", 16 if compact else 22)
	for b in [_reroll, _contribute, _track]:
		(b as Button).custom_minimum_size = Vector2(0.0, 64.0)
		(b as Button).add_theme_font_size_override("font_size", 14 if compact else 22)

## A trust bar: dark track, TEAL fill (progress fills stay TEAL, §2), the value centred.
class _TrustBar extends Control:
	var ratio := 0.0
	var text := ""
	var dim := 1.0
	var px := 16
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(120, 30)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.55 * dim))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), Color(UiTokens.TEAL.darkened(0.25), dim))
		draw_rect(r, Color(1, 1, 1, 0.18 * dim), false, 1.0)
		UiTokens.draw_centered(self, UiTokens.ui_face(), r.get_center(), text, px, Color(UiTokens.TEXT, 0.9 * dim))
