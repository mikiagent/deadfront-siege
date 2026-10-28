class_name FatiguePanel
extends PanelContainer
## "What is tiring you": the recent share of fatigue by cause, one remedy line per cause, and
## how the island's level and climate are changing the rate. Opened by tapping the HUD fatigue
## gauge. Reads Vitals.fatigue_breakdown(); nothing here changes game state.

const REFRESH_S := 0.5
const MAX_ROWS := 4
const MIN_SHARE := 0.03 ## a cause under 3% is noise, not worth a row
const PANEL_W := 340.0
const SOURCE_NAMES := {
	"time": "Time awake",
	"walk": "Walking",
	"gather": "Gathering",
	"combat": "Fighting",
	"climate_heat": "Heat",
	"climate_cold": "Cold",
	"food": "Foods & drinks",
}
const SOURCE_REMEDIES := {
	"time": "Rest (sit down): faster by a fire or a tent. Sleeping in a tent or bed clears it.",
	"walk": "Make fewer long trips. A mount or a camp stop helps.",
	"gather": "Eat a meal to ease it, or rest between harvests.",
	"combat": "Avoid hits: roll, flank, end fights early.",
	"climate_heat": "Eat a Cooling Meal or learn light heat clothing.",
	"climate_cold": "Eat a Warming Meal or learn fur cold clothing.",
	"food": "Check the item's fatigue note; many meals ease it instead.",
}
const DEFAULT_REMEDY := "Wait it out, or cure the status."

var player: Player
## Latest HUD-side exhaustion drift (pt/s; negative while it eases). HuntHud writes it every
## frame from ExhaustTreadmill's EMA; refresh() turns it into one sentence in the context line.
var rate := 0.0
var _rows: VBoxContainer
var _header: Label
var _context: Label
var _elapsed := 0.0

func _ready() -> void:
	# B4 look (ui-redesign-spec §7 B4): HUD fill, a muted kicker, the title, GOLD share bars.
	mouse_filter = Control.MOUSE_FILTER_STOP
	var view := get_viewport_rect().size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTokens.HUD_FILL, 0.94)
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 18.0)
	sb.set_content_margin(SIDE_TOP, 12.0)
	sb.set_content_margin(SIDE_BOTTOM, 14.0)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size.x = PANEL_W
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var heads := VBoxContainer.new()
	heads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_theme_constant_override("separation", 0)
	top.add_child(heads)
	var kicker := Label.new()
	kicker.text = "FATIGUE"
	kicker.add_theme_font_size_override("font_size", UiTokens.meta(view))
	kicker.add_theme_color_override("font_color", UiTokens.MUTED)
	heads.add_child(kicker)
	_header = Label.new()
	_header.text = "What's tiring you"
	_header.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	_header.add_theme_font_size_override("font_size", UiTokens.heading(view))
	heads.add_child(_header)
	var close := Button.new()
	close.name = "FatigueClose"
	close.icon = UiIcons.icon(&"close")
	close.add_theme_constant_override("icon_max_width", 26)
	close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.flat = true
	close.custom_minimum_size = Vector2(64.0, 64.0)
	close.pressed.connect(hide)
	top.add_child(close)
	_context = Label.new()
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context.custom_minimum_size.x = PANEL_W - 36.0
	_context.add_theme_constant_override("line_spacing", -2)
	_context.add_theme_color_override("font_color", UiTokens.TEXT)
	_context.add_theme_font_size_override("font_size", UiTokens.meta(view))
	box.add_child(_context)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed >= REFRESH_S:
		_elapsed = 0.0
		refresh()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func refresh() -> void:
	if player == null or player.vitals == null or _rows == null:
		return
	var v := player.vitals
	_context.text = context_text(v, player, rate)
	for child in _rows.get_children():
		child.queue_free()
	var shown: Array[Dictionary] = []
	for row in v.fatigue_breakdown():
		if float(row["share"]) >= MIN_SHARE and shown.size() < MAX_ROWS:
			shown.append(row)
	if shown.is_empty():
		_rows.add_child(_plain("Nothing is tiring you right now."))
		return
	for row in shown:
		_rows.add_child(_row(str(row["source"]), float(row["share"])))

## The island/climate sentence plus the live drift direction, separate so a test can read it
## without building nodes. `rate` is HUD-sampled d(fatigue)/dt in pt/s (<= 0 eases).
static func context_text(v: Vitals, p: Player, rate: float = 0.0) -> String:
	var parts: Array[String] = []
	var drift := ExhaustTreadmill.direction(rate)
	if drift != 0:
		var per_min := absf(rate) * 60.0
		var how := "slowly" if per_min < 0.5 else ("steadily" if per_min < 1.8 else "fast")
		parts.append("Exhaustion is %s %s (+%.1f/min)." % ["falling" if drift < 0 else "rising", how, per_min])
	if v.gap_zone_level > 0:
		var pct := int(round((v.level_gap_mult - 1.0) * 100.0))
		# No second "your level" here: the gap uses the skill-tree average, which is not the player
		# level the HUD and atlas show (LevelDisplay), so naming it again showed a third number.
		var how := "no change to fatigue" if pct == 0 else ("%+d%% fatigue" % pct)
		parts.append("Island %s: %s." % [LevelDisplay.label(v.gap_zone_level), how])
	if p != null and p.current_climate != "":
		var short := p.climate_shortfall(p.current_climate)
		var heat := float(short.get("heat", 0.0))
		var cold := float(short.get("cold", 0.0))
		if heat > 0.0:
			parts.append("Heat resistance is %d short." % int(ceil(heat)))
		if cold > 0.0:
			parts.append("Cold resistance is %d short." % int(ceil(cold)))
	return " ".join(parts) if not parts.is_empty() else "Level and climate are not adding fatigue here."

func _plain(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UiTokens.META)
	l.add_theme_font_size_override("font_size", UiTokens.meta(get_viewport_rect().size))
	l.add_theme_constant_override("line_spacing", -4)
	return l

func _row(source: String, share: float) -> Control:
	var box := VBoxContainer.new()
	var top := HBoxContainer.new()
	var name := Label.new()
	name.text = str(SOURCE_NAMES.get(source, source.capitalize()))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var pct := Label.new()
	pct.text = "%d%%" % int(round(share * 100.0))
	top.add_child(pct)
	box.add_child(top)
	box.add_theme_constant_override("separation", 2)
	var pct_col := UiTokens.GOLD
	pct.add_theme_color_override("font_color", pct_col)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = share
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	var fg := StyleBoxFlat.new()
	fg.bg_color = pct_col
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	box.add_child(bar)
	var hint := _plain(str(SOURCE_REMEDIES.get(source, DEFAULT_REMEDY)))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = PANEL_W - 36.0
	box.add_child(hint)
	return box
