class_name FoodInspector
extends PanelContainer
## Tap-food panel (spec 32 §12): item level, exact traits, Energy immediate / over time, Fullness,
## thirst, health, fatigue, max-stat effects, ability bonuses, negative effects, buff group, duration
## and consumption time, plus a line saying when this food would replace an active buff.
##
## Every value comes from FoodEffects.preview(stack), the same evaluation the eat commits, so the
## card cannot promise a number the meal does not pay. Plain Energy foods (no foods.json entry) keep
## the old lines. Tap targets are 64 px (mobile rule), the whole card stays inside a phone canvas,
## and `shown_min_px` / `shown_fits` are measured so the lab can check them.

signal eat_pressed(slot_index: int)
signal feed_pressed(slot_index: int)
signal closed

var slot_index: int = -1
var _title: Label
var _body: Label
var _scroll: ScrollContainer
var _eat_btn: Button
var _feed_btn: Button
var _close_btn: Button
## What the panel printed, measured after layout (tests and the lab read these, not the widgets).
var shown_min_px: float = 0.0
var shown_fits := false
var shown_replaces: Array = []

func _ready() -> void:
	visible = false
	z_index = 55
	custom_minimum_size = Vector2(360, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.94)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	# The body scrolls: a card with every s12 line is taller than a landscape phone, and the way out
	# (Close) must never be pushed off the canvas.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(320, 90)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(320, 0)
	_scroll.add_child(_body)
	_eat_btn = Button.new()
	_eat_btn.text = "Eat"
	_eat_btn.custom_minimum_size = Vector2(320, 64)
	_eat_btn.pressed.connect(func () -> void: eat_pressed.emit(slot_index); hide_panel())
	box.add_child(_eat_btn)
	_feed_btn = Button.new()
	_feed_btn.text = "Feed pet"
	_feed_btn.custom_minimum_size = Vector2(320, 64)
	_feed_btn.pressed.connect(func () -> void: feed_pressed.emit(slot_index); hide_panel())
	box.add_child(_feed_btn)
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(320, 64)
	_close_btn.pressed.connect(hide_panel)
	box.add_child(_close_btn)

func show_stack(stack: ItemStack, index: int, can_feed: bool = false) -> void:
	slot_index = index
	_title.text = str(stack.def().display_name) if stack and stack.def() else "Food"
	_body.text = card_text(stack)
	_eat_btn.disabled = Food.can_eat(_player_from_tree(), stack) != ""
	_feed_btn.visible = can_feed
	visible = true
	# Centre-ish for phone one-hand reach, and always fully on screen: on a 844x390 canvas the card
	# used to run past the bottom edge, so Close (the way out) was half off-screen.
	var vp := get_viewport_rect().size
	var short := vp.y < 520.0
	# Content floor: title + scroll floor + three 64 px buttons + separations.
	var floor_h := 24.0 + 90.0 + 3.0 * 64.0 + 32.0 + 24.0
	custom_minimum_size.y = clampf(vp.y - 24.0, minf(floor_h, vp.y - 24.0), 480.0)
	_scroll.custom_minimum_size.y = 90.0 if short else 160.0
	reset_size()
	var h := maxf(size.y, get_combined_minimum_size().y)
	position = Vector2(
		maxi(16, int(vp.x * 0.5 - 180)),
		int(clampf(vp.y * 0.12, 12.0, maxf(12.0, vp.y - 12.0 - h))))
	_measure()
	print("[foodfx] card at %s size %s canvas %s" % [str(position), str(size), str(vp)])

## Measured tap targets and layout, after the panel has laid out.
func _measure() -> void:
	var mins: Array[float] = []
	for b: Button in [_eat_btn, _feed_btn, _close_btn]:
		if b == null or not b.visible:
			continue
		mins.append(minf(b.size.x, b.size.y))
	shown_min_px = mins.min() if not mins.is_empty() else 0.0
	shown_fits = _inside(_eat_btn) and _inside(_close_btn)
	shown_replaces = _replaces

func _inside(c: Control) -> bool:
	if c == null:
		return false
	var r := Rect2(c.global_position, c.size)
	var vp := get_viewport_rect().size
	return r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= vp.x + 0.5 and r.end.y <= vp.y + 0.5

var _replaces: Array = []

## The card text (spec 32 §12). Plain Energy foods keep their old inspector lines.
func card_text(stack: ItemStack) -> String:
	if stack == null:
		return ""
	_replaces = []
	if not FoodEffects.has_bundle(stack):
		return Food.inspector_text(stack)
	var b := FoodEffects.preview(stack, _player_from_tree())
	var lines: PackedStringArray = []
	var d := stack.def()
	lines.append("level %d  process %d  eat %.1f s" % [stack.level, stack.process_count, float(b.get("eat_seconds", 3.0))])
	var named := Inventory.traits(stack)
	if not named.is_empty():
		var bits: PackedStringArray = []
		for k: Variant in named:
			var key := str(k)
			if key == "quality" or key == "flawless_bonus":
				continue
			bits.append("%s %s" % [key.replace("_", " ").capitalize(), str(named[key])])
		if not bits.is_empty():
			lines.append("traits: %s" % ", ".join(bits))
	var instant := float(b.get("instant_energy", 0.0))
	var digested := float(b.get("digested_energy", 0.0))
	if instant != 0.0 or digested != 0.0:
		lines.append("Energy %.1f now + %.1f over %s" % [instant, digested, _span(float(b.get("digest_seconds", 0.0)))])
	for pair in [["fullness", "Fullness"], ["thirst", "Thirst"], ["health", "Health"], ["life", "Life"], ["fatigue", "Fatigue"],
			["max_energy", "Max Energy"], ["max_fatigue", "Max Fatigue"]]:
		var v := float(b.get(str(pair[0]), 0.0))
		if v != 0.0:
			lines.append("%s %+.1f" % [str(pair[1]), v])
	# Buff rows: group, duration, and what each stat does. Ancient provenance stays in foods.json.
	var stats: Dictionary = b.get("stats", {})
	var group_lines: Dictionary = {}
	for row: Variant in b.get("buffs", []):
		if not row is Dictionary:
			continue
		var r: Dictionary = row as Dictionary
		var key := str(r.get("group_name", r.get("group", "")))
		var bits: PackedStringArray = group_lines.get(key, [])
		var stat_bits: PackedStringArray = []
		var raw_stats: Dictionary = r.get("stats", {})
		for stat: Variant in raw_stats:
			stat_bits.append(_stat_text(str(stat), raw_stats[stat] as Dictionary))
		bits.append("%s %s, %s" % [str(r.get("display_name", r.get("id", ""))), ", ".join(stat_bits), _span(float(r.get("duration", 0.0)))])
		group_lines[key] = bits
	for key: Variant in group_lines:
		lines.append("%s (%s): %s" % [str(key), _exclusive(str(key)), " | ".join(group_lines[key])])
	# Negative effects.
	var taste: Dictionary = b.get("taste", {})
	var grade := str(taste.get("grade", "normal"))
	var flavor := str(taste.get("flavor", ""))
	if grade != "":
		var extra := ""
		if grade in ["phenomenal", "delicious"]:
			extra = " +%d%% EXP" % int(round((float(taste.get("xp_mult", 1.0)) - 1.0) * 100.0))
		elif grade in ["horrible", "disgusting"]:
			extra = " +%d%% fatigue gain" % int(round((float(taste.get("fatigue_mult", 1.0)) - 1.0) * 100.0))
		lines.append("taste: %s (%s%s)" % [grade.capitalize(), flavor, extra])
	var risk: Dictionary = b.get("raw_risk", {})
	if bool(risk.get("raw", false)):
		lines.append("RAW: can cause Stomach Pain (%d%%)" % int(round(float(risk.get("poison_chance", 0.0)) * 100.0)))
	for row: Variant in b.get("statuses", []):
		if row is Dictionary:
			lines.append("effect: %s %s" % [str((row as Dictionary).get("id", "")), _span(float((row as Dictionary).get("duration", 0.0)))])
	if str(b.get("temperature", "")) != "":
		lines.append("served %s" % str(b.get("temperature", "")))
	if Food.is_poisoned(stack):
		lines.append("POISONED")
	# The replacement line (spec 32 §12): what this food would take away when it is eaten now.
	var slots := BuffSlots.of(_player_from_tree())
	if slots != null:
		var rep := slots.would_replace(b.get("buffs", []))
		_replaces = rep
		for r: Dictionary in rep:
			lines.append("replaces %s (%s)" % [str(r.get("old", "")), str(r.get("group_name", ""))])
		var active := slots.ids()
		if active.is_empty() and not b.get("buffs", []).is_empty():
			lines.append("no active food buff to replace")
	return "\n".join(lines)

func _exclusive(group: String) -> String:
	return "replaces the same group" if group != "" else ""

func _span(seconds: float) -> String:
	if seconds <= 0.0:
		return "no delay"
	if seconds >= 60.0:
		return "%d min" % int(round(seconds / 60.0))
	return "%d s" % int(round(seconds))

func _stat_text(stat: String, ops: Dictionary) -> String:
	var name := stat.replace("_", " ").capitalize()
	var player_stat := FoodEffects.player_stat(stat)
	var suffix := "" if player_stat != "" else " (no check yet)"
	if ops.has("add"):
		return "%s %+.1f%s" % [name, float(ops["add"]), suffix]
	if ops.has("sub"):
		return "%s %+.1f%s" % [name, -float(ops["sub"]), suffix]
	if ops.has("mult"):
		return "%s x%.2f%s" % [name, float(ops["mult"]), suffix]
	if ops.has("set"):
		return "%s %.1f%s" % [name, float(ops["set"]), suffix]
	return name

func hide_panel() -> void:
	visible = false
	slot_index = -1
	closed.emit()

func _player_from_tree() -> Player:
	return PlayerRegistry.local()
