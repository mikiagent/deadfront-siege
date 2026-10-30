class_name CommsUI
extends UiWorldSheet
## F3 Factions (docs/design/factions.md; ui-redesign-spec §7 F3; systems PRD §15.1): the five factions
## from data/world/factions.json, one row each (icon, name, tier title, a reputation bar with a ghost
## fill: a gain shows as a light lead the real fill eases up to, like the skill bars), and the selected
## faction's detail: parchment header (name, motto), what it pays for, its active missions (progress,
## Receive / Abandon), its mission offers (Accept) and what its next rank unlocks. Missions are Tasks
## rows (category "faction"); Receive is Tasks.claim (reputation and rank-up unlocks via Factions.add_rep).
## The header counts active missions (PRD: up to 4). Radio University's career guides also have their
## own screen (RadioUniversityUI) behind "Open Radio University". Contribute opens the spec-29 panel.
## Faction boards in the Faction Hall plaza open this screen on their faction (TownBuilding).

const ICONS := {
	"company": &"harbour",
	"chlorophyll_forum": &"farming",
	"pioneer_council": &"defense",
	"committee": &"lock",
	"radio_university": &"chat",
}
const GHOST_DELAY := 0.6  ## as HudEventState.SKILL_CATCHUP_DELAY: the ghost leads, then the fill eases up

var player: Player
var factions: Array[Dictionary] = []  ## [{id, ...json row}] in file order
var selected := ""
var radio: RadioUniversityUI
var center_ui: CommCenterUI
var last_result := ""  ## the last Receive / Accept outcome line (also shown on screen)

var _list_panel: PanelContainer
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Dictionary = {}  ## id -> Button
var _detail: PanelContainer
var _parch: PanelContainer
var _d_name: Label
var _d_tone: Label
var _detail_scroll: ScrollContainer
var _offers: VBoxContainer
var _foot: HBoxContainer
var _contribute: Button
var _radio_open: Button

func _init() -> void:
	super("Factions")

static func load_factions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in Factions.ids():
		var d := Factions.def(id).duplicate(true)
		d["id"] = id
		out.append(d)
	return out

## "gather_herbs" -> "Gather herbs".
static func pretty(id: String) -> String:
	var s := id.replace("_", " ").strip_edges()
	return s.left(1).to_upper() + s.substr(1) if s != "" else s

static func trust_rank(id: String) -> int:
	return Factions.rank(id)

static func crate_band(f: Dictionary, rank: int) -> String:
	return Factions.crate_band(f, rank)

static func unlock_level(f: Dictionary) -> int:
	return int(f.get("unlock_level", 0))

## Share of the way from the current rank to the next (1.0 at rank 10).
static func rank_frac(id: String) -> float:
	var r := Factions.rank(id)
	if r >= Factions.RANKS:
		return 1.0
	var lo := Factions.rank_need(r)
	return clampf(float(Factions.points(id) - lo) / float(maxi(1, Factions.rank_need(r + 1) - lo)), 0.0, 1.0)

func is_locked(f: Dictionary) -> bool:
	return not Factions.unlocked(str(f["id"]), char_level())

func char_level() -> int:
	return Factions.char_level(player)

func _build() -> void:
	name = "CommsUI"
	back_pressed.connect(close)
	close_pressed.connect(close)
	factions = load_factions()
	_list_panel = SheetChrome.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
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

	_detail = SheetChrome.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
	_detail.name = "Detail"
	body.add_child(_detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 0)
	_detail.add_child(dv)
	_parch = PanelContainer.new()
	_parch.name = "Parchment"
	_parch.add_theme_stylebox_override("panel", SheetChrome.parchment_style())
	dv.add_child(_parch)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	_parch.add_child(pv)
	_d_name = SheetChrome.label("", 30, UiTokens.PARCHMENT_INK, true)
	_d_name.name = "Name"
	pv.add_child(_d_name)
	_d_tone = SheetChrome.label("", 17, UiTokens.PARCHMENT_INK)
	_d_tone.name = "Tone"
	_d_tone.clip_text = true
	pv.add_child(_d_tone)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_detail_scroll)
	_offers = VBoxContainer.new()
	_offers.name = "Offers"
	_offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offers.add_theme_constant_override("separation", 0)
	_detail_scroll.add_child(_offers)
	var foot_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		foot_pad.add_theme_constant_override("margin_" + s, 12)
	dv.add_child(foot_pad)
	_foot = HBoxContainer.new()
	_foot.name = "Foot"
	_foot.add_theme_constant_override("separation", 10)
	foot_pad.add_child(_foot)
	_radio_open = SheetChrome.gold_button("Open Radio University")
	_radio_open.name = "OpenRadio"
	_radio_open.pressed.connect(open_radio)
	_contribute = SheetChrome.ghost_button("Contribute →")
	_contribute.name = "Contribute"
	_contribute.pressed.connect(open_contribution)
	for b in [_radio_open, _contribute]:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_foot.add_child(b)

func _band_label(text: String) -> Control:
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", SheetChrome.box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0))
	var compact := UiTokens.is_compact(get_viewport_rect().size)
	band.add_child(SheetChrome.label(text, 14 if compact else 20, UiTokens.TEXT))
	return band

func _faction_row(f: Dictionary) -> Button:
	var id := str(f["id"])
	var b := Button.new()
	b.name = "Faction_%s" % id
	b.toggle_mode = true
	b.clip_contents = true
	b.add_theme_stylebox_override("focus", SheetChrome.box(Color(0, 0, 0, 0), UiTokens.GOLD, 1))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var sw := ColorRect.new()  # the faction's banner colour
	sw.name = "Swatch"
	sw.color = Color(str(f.get("colour", "#888888")))
	sw.custom_minimum_size = Vector2(8, 0)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sw)
	var ic := SheetChrome.icon_rect(ICONS.get(id, &"chat"), 48.0)
	ic.name = "Icon"
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(ic)
	var names := VBoxContainer.new()
	names.name = "Names"
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	var nl := SheetChrome.label(str(f.get("name", id)), 26, UiTokens.TEXT)
	nl.name = "Name"
	nl.clip_text = true
	names.add_child(nl)
	var sub := SheetChrome.label("", 17, UiTokens.MUTED)
	sub.name = "Sub"
	sub.clip_text = true
	names.add_child(sub)
	var trust := VBoxContainer.new()
	trust.name = "Trust"
	trust.alignment = BoxContainer.ALIGNMENT_CENTER
	trust.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trust)
	var tl := SheetChrome.label("", 16, UiTokens.TEXT)
	tl.name = "TrustLine"
	trust.add_child(tl)
	var bar := RepBar.new()
	bar.name = "Bar"
	bar.fill = Color(str(f.get("colour", "#888888"))).lerp(UiTokens.TEAL, 0.35)
	trust.add_child(bar)
	var mark := SheetChrome.Brackets.new()
	mark.name = "Brackets"
	b.add_child(mark)
	return b

# ---------------------------------------------------------------- open / select

## Opens the screen; `fid` preselects a faction (a faction board in the hall plaza).
func open(p: Player, fid: String = "") -> void:
	player = p
	visible = true
	if fid != "" and not Factions.def(fid).is_empty():
		selected = fid
	if selected == "" and not factions.is_empty():
		selected = str(factions[0]["id"])
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
	last_result = ""
	_refresh()
	relayout()

func faction(id: String) -> Dictionary:
	for f in factions:
		if str(f["id"]) == id:
			return f
	return {}

func open_radio() -> void:
	if radio == null or not is_instance_valid(radio):
		radio = RadioUniversityUI.new()
		get_parent().add_child(radio)
		radio.back_pressed.connect(func () -> void: radio.close(); open(player))
	radio.open(player)
	visible = false

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

# ---------------------------------------------------------------- actions

## Accept mission `key` (Tasks.accept). "" on success, else why not.
func accept(key: String) -> String:
	var why := Tasks.accept(key, player)
	last_result = "Accepted: %s" % str(Tasks.mission_def(key).get("title", key)) if why == "" else why
	_refresh()
	relayout()
	return why

func abandon(key: String) -> void:
	Tasks.abandon(key)
	last_result = "Abandoned: %s" % str(Tasks.mission_def(key).get("title", key))
	_refresh()
	relayout()

## Receive mission `key`: pays it (Tasks.claim); the reputation bar ghost-fills. False when not claimable.
func receive(key: String) -> bool:
	var fid := str(Tasks.mission_def(key).get("faction", ""))
	var before_rank := Factions.rank(fid)
	var before := rank_frac(fid)
	var r := Tasks.claim(key, player)
	if r.is_empty():
		return false
	var rw: Dictionary = r["rewards"]
	var bits: Array[String] = ["+%d reputation" % int(rw.get("rep", 0))]
	for k in ["t_stones", "sp", "xp"]:
		if int(rw.get(k, 0)) > 0:
			bits.append("+%d %s" % [int(rw[k]), {"t_stones": "Gold", "sp": "SP", "xp": "EXP"}[k]])
	var ranks: Array = r.get("ranks", [])
	last_result = "%s complete: %s" % [r["title"], ", ".join(bits)]
	if not ranks.is_empty():
		last_result += ". Rank %d: %s!" % [int(ranks[-1]), Factions.title(fid)]
	if player:
		player.notice(last_result)
	if _rows.has(fid):
		((_rows[fid] as Button).find_child("Bar", true, false) as RepBar).gain_from(before if Factions.rank(fid) == before_rank else 0.0)
	_refresh()
	relayout()
	return true

func _refresh() -> void:
	set_counter("Active missions [color=#%s]%d[/color] / %d" % [UiTokens.GOLD.to_html(false), Tasks.active.size(), int(Factions.rule("max_active", 4))])
	for f in factions:
		var id := str(f["id"])
		var b: Button = _rows[id]
		var on := id == selected
		var locked := is_locked(f)
		b.set_pressed_no_signal(on)
		var sb := SheetChrome.box(UiTokens.GOLD_DIM if on else Color(0, 0, 0, 0), Color(1, 1, 1, 0.06), 1)
		sb.border_width_top = 0
		sb.border_width_left = 0
		sb.border_width_right = 0
		for s in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		var dim := 0.45 if locked else 1.0
		var ink := UiTokens.GOLD if on else UiTokens.TEXT
		(b.find_child("Name", true, false) as Label).add_theme_color_override("font_color", Color(ink, dim))
		(b.find_child("Icon", true, false) as TextureRect).modulate = Color(UiTokens.TEXT, dim)
		var rank := Factions.rank(id)
		var sub := b.find_child("Sub", true, false) as Label
		sub.text = "Locked · Lv. %d" % unlock_level(f) if locked else Factions.title(id)
		sub.add_theme_color_override("font_color", Color(UiTokens.MUTED, dim))
		var tl := b.find_child("TrustLine", true, false) as Label
		tl.text = "Rank %d / %d" % [rank, Factions.RANKS]
		tl.add_theme_color_override("font_color", Color(UiTokens.TEXT, dim))
		var bar := b.find_child("Bar", true, false) as RepBar
		bar.set_target(rank_frac(id))
		bar.text = "%d / %d" % [Factions.points(id), Factions.rank_need(rank + 1)] if rank < Factions.RANKS else "%d · max" % Factions.points(id)
		bar.dim = dim
		bar.queue_redraw()
		(b.find_child("Brackets", true, false) as Control).visible = on
	_fill_detail(faction(selected))

func _fill_detail(f: Dictionary) -> void:
	for c in _offers.get_children():
		_offers.remove_child(c)
		c.queue_free()
	if f.is_empty():
		_d_name.text = "No factions"
		_d_tone.text = "data/world/factions.json is missing or empty."
		return
	var id := str(f["id"])
	var compact := UiTokens.is_compact(get_viewport_rect().size)
	_d_name.text = str(f.get("name", id))
	_d_tone.text = "\"%s\"  ·  %s" % [f.get("motto", ""), Factions.title(id)]
	_radio_open.visible = bool(f.get("career_guides", false))
	if last_result != "":
		_offers.add_child(_note(last_result, UiTokens.GOLD))
	var mine: Array[Dictionary] = []
	for r in Tasks.rows(&"faction", player):
		if str(r["faction"]) == id:
			mine.append(r)
	if not mine.is_empty():
		_offers.add_child(_band_label("Your missions"))
		for r in mine:
			_offers.add_child(_active_row(r, compact))
	_offers.add_child(_band_label("Career guides" if bool(f.get("career_guides", false)) else "Mission offers"))
	if is_locked(f):
		_offers.add_child(_note("Unlocks at character level %d (you are %d)." % [unlock_level(f), char_level()], UiTokens.MUTED))
	else:
		var keys := Tasks.offers(id, player)
		if keys.is_empty():
			_offers.add_child(_note("No offers left. New offers at 00:00 UTC.", UiTokens.MUTED))
		for key in keys:
			_offers.add_child(_offer_row(key, compact))
	_offers.add_child(_band_label("Next rank"))
	_offers.add_child(_note(_next_rank_text(f), UiTokens.TEXT))
	_offers.add_child(_band_label("About"))
	_offers.add_child(_note(str(f.get("values", "")) + "\nPays for: " + str(f.get("rewards", "")), UiTokens.MUTED))

func _next_rank_text(f: Dictionary) -> String:
	var id := str(f["id"])
	var rank := Factions.rank(id)
	if rank >= Factions.RANKS:
		return "Rank 10: %s. Nothing above this." % Factions.title(id)
	var u := Factions.rank_unlock(id, rank + 1)
	var what: Array[String] = []
	for item_id in u["items"]:
		var def := Data.item(StringName(str(item_id)))
		what.append(def.display_name if def != null and def.display_name != "" else pretty(str(item_id)))
	var pay := "Support crate (%s)" % ", ".join(what) if bool(f.get("crates", false)) else "%d skill point" % int(u["sp"])
	var nxt_tier := Factions.tier_of_rank(rank + 1)
	var titles: Array = f.get("titles", [])
	var title_line := ""
	if nxt_tier > Factions.tier_of_rank(rank) and titles.size() >= nxt_tier:
		title_line = " and the title %s" % str(titles[nxt_tier - 1])
	return "Rank %d at %d reputation: %s%s." % [rank + 1, Factions.rank_need(rank + 1), pay, title_line]

func _note(t: String, col: Color) -> Control:
	var pad := MarginContainer.new()
	for s in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + s, 16)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	var l := SheetChrome.label(t, 12 if UiTokens.is_compact(get_viewport_rect().size) else 16, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pad.add_child(l)
	return pad

static func reward_text(m: Dictionary, f: Dictionary) -> String:
	var mult := float(f.get("reward_multiplier", 1.0))
	var bits: Array[String] = ["+%d rep" % int(m.get("rep", 0))]
	if int(m.get("t_stones", 0)) > 0:
		bits.append("%d Gold" % int(round(int(m["t_stones"]) * mult)))
	if int(m.get("sp", 0)) > 0:
		bits.append("%d SP" % int(m["sp"]))
	if int(m.get("xp", 0)) > 0:
		bits.append("%d EXP" % int(m["xp"]))
	return " · ".join(bits) + "  ·  " + str(m.get("cadence", "daily")).capitalize()

func _mission_shell(key: String, title: String, sub: String, rw: String, compact: bool) -> Array:
	var pad := MarginContainer.new()
	pad.name = "Mission_%s" % key.replace(".", "_")
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
	var t := SheetChrome.label(title, 16 if compact else 22, UiTokens.TEXT)
	t.clip_text = true
	col.add_child(t)
	var d := SheetChrome.label(sub, 12 if compact else 15, UiTokens.MUTED)
	d.clip_text = true
	col.add_child(d)
	var r := SheetChrome.label(rw, 12 if compact else 15, UiTokens.GOLD)
	r.clip_text = true
	col.add_child(r)
	return [pad, row, col]

func _button(t: String, gold: bool, compact: bool) -> Button:
	var b := SheetChrome.gold_button(t) if gold else SheetChrome.ghost_button(t)
	b.name = t
	b.custom_minimum_size = Vector2(96.0 if compact else 124.0, 64.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 16 if compact else 20)
	return b

func _offer_row(key: String, compact: bool) -> Control:
	var m := Tasks.mission_def(key)
	var f := Factions.def(str(m.get("faction", "")))
	var desc := str(m.get("desc", ""))
	var parts := _mission_shell(key, str(m.get("title", key)), desc % int(m.get("want", 1)) if desc.contains("%d") else desc, reward_text(m, f), compact)
	var accept_b := _button("Accept", true, compact)
	var why := Tasks.accept_block(key, player)
	accept_b.disabled = why != ""
	accept_b.tooltip_text = why
	accept_b.pressed.connect(func () -> void: accept(key))
	(parts[1] as HBoxContainer).add_child(accept_b)
	return parts[0]

func _active_row(r: Dictionary, compact: bool) -> Control:
	var key := str(r["id"])
	var m := Tasks.mission_def(key)
	var parts := _mission_shell(key, str(r["title"]), "%s  %d / %d" % [r["desc"], int(r["got"]), int(r["want"])], reward_text(m, Factions.def(str(r["faction"]))), compact)
	(parts[2] as VBoxContainer).add_child(SheetChrome.thin_bar(float(r["frac"]), UiTokens.GOLD, 4.0))
	if bool(r["claimable"]):
		var rec := _button("Receive", true, compact)
		rec.pressed.connect(func () -> void: receive(key))
		(parts[1] as HBoxContainer).add_child(rec)
	else:
		var ab := _button("Abandon", false, compact)
		ab.pressed.connect(func () -> void: abandon(key))
		(parts[1] as HBoxContainer).add_child(ab)
	return parts[0]

# ---------------------------------------------------------------- layout

func _layout_body(view: Vector2, rect: Rect2) -> void:
	var compact := UiTokens.is_compact(view)
	var gap := 8.0 if compact else 20.0
	var lw := floorf((rect.size.x - gap) * (0.42 if compact else 0.44))
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
		row.add_theme_constant_override("separation", 8 if compact else 20)
		row.offset_left = 0.0
		row.offset_right = -(10.0 if compact else 24.0)
		(b.find_child("Icon", true, false) as Control).custom_minimum_size = Vector2.ONE * (26.0 if compact else 48.0)
		var names := b.find_child("Names", true, false) as Control
		names.custom_minimum_size.x = 120.0 if compact else 230.0
		(b.find_child("Name", true, false) as Label).add_theme_font_size_override("font_size", 14 if compact else 24)
		(b.find_child("Sub", true, false) as Label).add_theme_font_size_override("font_size", 12 if compact else 17)
		(b.find_child("TrustLine", true, false) as Label).add_theme_font_size_override("font_size", 12 if compact else 16)
		var bar := b.find_child("Bar", true, false) as RepBar
		bar.custom_minimum_size.y = 18.0 if compact else 30.0
		bar.px = 11 if compact else 16
	_d_name.add_theme_font_size_override("font_size", 18 if compact else 30)
	_d_tone.add_theme_font_size_override("font_size", 12 if compact else 17)
	var ps := _parch.get_theme_stylebox("panel") as StyleBoxTexture
	ps.content_margin_left = 10 if compact else 20
	ps.content_margin_top = 4 if compact else 10
	ps.content_margin_bottom = 4 if compact else 10
	for b in [_radio_open, _contribute]:
		(b as Button).custom_minimum_size = Vector2(0.0, 64.0)
		(b as Button).add_theme_font_size_override("font_size", 14 if compact else 22)

## A reputation bar: dark track, the faction-tinted fill, the value centred. A gain first shows as a
## light ghost lead (target); after GHOST_DELAY the real fill (shown) eases up to it (skill-bar style).
class RepBar extends Control:
	var shown := 0.0
	var target := 0.0
	var text := ""
	var dim := 1.0
	var px := 16
	var fill := UiTokens.TEAL
	var _wait := 0.0
	var _primed := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(120, 30)
	## The bar's value now. The first call snaps; later rises animate (ghost first), drops snap.
	func set_target(v: float) -> void:
		target = clampf(v, 0.0, 1.0)
		if not _primed or target < shown:
			shown = target
		_primed = true
	## A gain that started at `from` (share of this rank; 0 after a rank-up): the real fill restarts there.
	func gain_from(from: float) -> void:
		shown = clampf(from, 0.0, 1.0)
		_wait = 0.0
		_primed = true
	func _process(delta: float) -> void:
		if shown >= target:
			return
		_wait += delta
		if _wait < GHOST_DELAY:
			return
		shown = minf(target, shown + maxf(0.15, (target - shown) * 2.5) * delta)
		if shown >= target - 0.002:
			shown = target
			_wait = 0.0
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.55 * dim))
		if target > shown:  # the ghost lead: reputation gained but not yet counted in
			draw_rect(Rect2(r.position, Vector2(r.size.x * target, r.size.y)), Color(fill.lerp(Color.WHITE, 0.55), 0.75 * dim))
		draw_rect(Rect2(r.position, Vector2(r.size.x * shown, r.size.y)), Color(fill, dim))
		draw_rect(r, Color(1, 1, 1, 0.18 * dim), false, 1.0)
		UiTokens.draw_centered(self, UiTokens.ui_face(), r.get_center(), text, px, Color(UiTokens.TEXT, 0.9 * dim))
