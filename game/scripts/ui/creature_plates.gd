class_name CreaturePlates
extends CanvasLayer
## Screen-space creature and loot plates.

## Opaque: at 0.72, and still at 0.96, a world label behind the plate ("Harbour") ghosted between glyphs.
const PILL_ALPHA := 1.0
const MAX_DIST := 45.0
const NEAR_DIST := 10.0
const BASE_WIDTH := 176.0
const DAMAGE_CHUNK_SECONDS := 0.6
const STATUS_GLYPH_SCRIPT: GDScript = preload("res://scripts/ui/status_glyph.gd")
## Rows of a full plate: name 0-20 (the 14 px font's ascent + descent: at 16 the tag hid the name's
## descenders), nature tag 20-34 (NATURES: a chip under the name, absent while the animal has no
## nature), a 4 px gap, HP bar 38-52, pet XP 52-56, status glyphs 56-82, tame 82-102.
## Without a nature the rows below the name move up by the chip and its gap (bar at 22).
const FULL_H := 102.0
## The nature tag sits directly under the name line, left-aligned with it.
const CHIP_POS := Vector2(8, 20)
## ASSUMPTION: 4 px between the nature tag and the HP bar; touching, the bar read as covering the tag.
const CHIP_GAP := 4.0
## Far plates shrink, but never below the 12 px type floor for their 14 px text.
const MIN_SCALE := 0.86

var _root: Control
var _entries: Dictionary = {} ## creature instance id -> Dictionary
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}
var _emphasis_id: int = 0

const TORPOR_COLOR := Color(0.58, 0.42, 1.0, 0.95)
const TORPOR_H := 4.0

func _ready() -> void:
	layer = 58
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_load_icon_manifest()

func reveal_creature(creature: Creature, seconds: float = 3.0) -> void:
	if creature == null:
		return
	var key := creature.get_instance_id()
	var e := _ensure_entry(creature)
	e["reveal_until"] = _now_s() + seconds
	_entries[key] = e

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var player := PlayerRegistry.local()
	if cam == null or player == null:
		return
	# This layer (58) is above the HUD's: a plate drew over an open HUD sheet.
	var hud := get_tree().get_first_node_in_group("hud") as HuntHud
	_root.visible = hud == null or not hud.sheet_open()
	_tick_creatures(cam, player, delta)  # a carcass has a HUD name pill (HudPills, LOOTRADIAL), no plate

func _tick_creatures(cam: Camera3D, player: Player, delta: float) -> void:
	var now := _now_s()
	_emphasis_id = _pick_emphasis(player)
	var seen: Dictionary = {}
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.health.dead:
			continue
		var dist := player.global_position.distance_to(c.global_position)
		if dist > MAX_DIST:
			continue
		seen[c.get_instance_id()] = true
		var e := _ensure_entry(c)
		var forced := _forced_visible(c, player, now)
		# Nearby wild creatures reveal their plate for inspection. Pets do not keep a plate
		# permanently visible just because they follow within the near-distance bubble.
		if not forced and ((dist <= NEAR_DIST and not c.is_pet) or c.tapped_recently(3.0)):
			e["reveal_until"] = now + 3.0
		var show := forced or now <= float(e.get("reveal_until", 0.0))
		var alpha := float(e.get("alpha", 0.0))
		alpha = move_toward(alpha, 1.0 if show else 0.0, delta * 4.5)
		e["alpha"] = alpha
		_update_entry(e, c, cam, player, dist, delta)
		_entries[c.get_instance_id()] = e
	_separate_visible_creature_plates()
	for key in _entries.keys():
		if seen.has(key):
			continue
		_remove_entry(int(key))

func _separate_visible_creature_plates() -> void:
	# Keep nearby herd members readable. Greedily lift a plate until its name/HP block no
	# longer overlaps an earlier one; horizontal separation still keeps unrelated plates free.
	var placed: Array[Rect2] = []
	var visible: Array[Control] = []
	var bodies := {}  ## plate node -> its creature's screen box
	var cam := get_viewport().get_camera_3d()
	for key in _entries:
		var node := (_entries[key] as Dictionary).get("node", null) as Control
		if node and node.visible:
			visible.append(node)
			var c := instance_from_id(int(key)) as Creature
			bodies[node] = creature_box(cam, c) if cam and c else Rect2()
	visible.sort_custom(func(a: Control, b: Control) -> bool: return a.position.y < b.position.y)
	# This layer is above the HUD's: an opaque plate hid the survivor's name and the HUD's hexes and
	# text. A plate's pill takes the nearest free spot up or down off the HUD's rects and the plates
	# before it (lifting only, a portrait plate climbed off the top), or hides when there is none.
	# World pills do not count: the plate is opaque over them on purpose.
	var hud := get_tree().get_first_node_in_group("hud") as HuntHud
	var hud_rects: Array[Rect2] = hud.taken_rects(PackedStringArray(["pill"])) if hud else ([] as Array[Rect2])
	var view := get_viewport().get_visible_rect().size
	for node in visible:
		var pos := node.position
		var sz := node.size * node.scale
		var rect := Rect2(pos, sz).grow(3.0)
		var attempts := 0
		while attempts < 6:
			var hit := false
			for prior in placed:
				if rect.intersects(prior):
					pos.y = prior.position.y - rect.size.y - 4.0
					rect.position.y = pos.y
					hit = true
					break
			if not hit:
				break
			attempts += 1
		var pill := node.get_node_or_null("Pill") as Control
		var shown := Rect2(pos + pill.position * node.scale, pill.size * node.scale) if pill else rect
		var taken := hud_rects.duplicate()
		taken.append_array(placed)
		# Its own creature too, above it first: pushed down off the HUD, the pill hid the compy it named.
		if (bodies[node] as Rect2).has_area():
			taken.append(bodies[node])
		var spot := UiTokens.free_spot(shown, taken, view, true)
		var clear := spot.has_area()
		if clear:
			pos.y += spot.position.y - shown.position.y
			rect.position.y += spot.position.y - shown.position.y
		node.visible = clear
		node.position = pos
		if clear:
			placed.append(rect)

## The creature on screen: a box as long as the def along its facing, body_radius to each side and
## def height tall, projected and bounded. Empty when a corner is behind the camera.
# ASSUMPTION: real_length_m spans nose to tail and body_radius() is half the body's width (no mesh bounds per frame).
static func creature_box(cam: Camera3D, c: Creature) -> Rect2:
	var xf := c.get_global_transform_interpolated()
	var fwd := Vector3(xf.basis.z.x, 0.0, xf.basis.z.z)  # yaw only: a fading creature's basis collapses
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP) * c.body_radius()
	fwd *= c.def.real_length_m * 0.5 * c.size_scale()
	var out := Rect2()
	for i in 8:
		var p := xf.origin + (side if (i & 1) != 0 else -side) + (fwd if (i & 2) != 0 else -fwd) + Vector3(0.0, c.def.height_meters * c.size_scale() if (i & 4) != 0 else 0.0, 0.0)
		if cam.is_position_behind(p):
			return Rect2()
		var s := cam.unproject_position(p)
		out = Rect2(s, Vector2.ZERO) if i == 0 else out.expand(s)
	return out

func _forced_visible(c: Creature, player: Player, now: float) -> bool:
	if (player.hunt and player.hunt.target == c) or player.controls.selection.target == c:
		return true
	if now - c.last_damaged_s <= 5.0:
		return true
	if now - c.last_aggro_s <= 5.0:
		return true
	if FieldTame.can_attempt(c):
		return true
	return false

func _ensure_entry(c: Creature) -> Dictionary:
	var key := c.get_instance_id()
	if _entries.has(key):
		return _entries[key]
	var root := Control.new()
	root.custom_minimum_size = Vector2(BASE_WIDTH, FULL_H)
	root.size = root.custom_minimum_size
	root.pivot_offset = Vector2(BASE_WIDTH * 0.5, 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(root)
	# Backing pill: the name, bar and glyphs read on bright grass and sky alike.
	var pill := Panel.new()
	pill.name = "Pill"
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(UiTokens.INK, PILL_ALPHA)
	pill_style.set_corner_radius_all(8)
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill)
	var line1 := Label.new()
	line1.name = "Line1"
	line1.position = Vector2(8, 0)
	line1.size = Vector2(BASE_WIDTH - 16.0, 16.0)
	line1.clip_text = true
	line1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line1.add_theme_font_size_override("font_size", 14)
	root.add_child(line1)
	# NATURES (owner 2026-10-28): the nature is a TAG under the name, never part of it.
	var chip := NatureChip.new()
	chip.position = CHIP_POS
	root.add_child(chip)
	var bar_bg := ColorRect.new()
	bar_bg.name = "BarBg"
	bar_bg.position = Vector2(8, bar_top(false))
	bar_bg.size = Vector2(160, 14)
	bar_bg.color = Color(0.04, 0.04, 0.04, 0.82)
	root.add_child(bar_bg)
	var bar_recent := ColorRect.new()
	bar_recent.name = "BarRecent"
	bar_recent.position = Vector2(0, 0)
	bar_recent.size = Vector2.ZERO
	bar_recent.color = Color(1.0, 1.0, 1.0, 0.82)
	bar_bg.add_child(bar_recent)
	var bar_fill := ColorRect.new()
	bar_fill.name = "BarFill"
	bar_fill.position = Vector2.ZERO
	bar_fill.size = Vector2(160, 14)
	bar_fill.color = Color(0.2, 0.85, 0.4, 0.95)
	bar_bg.add_child(bar_fill)
	# FOODTORPOR: the torpor bar, a thin violet strip right under the HP bar with a tick at the
	# knock-out threshold (purple/blue so it never reads as health).
	var torpor_bg := ColorRect.new()
	torpor_bg.name = "TorporBg"
	torpor_bg.color = Color(0.06, 0.04, 0.12, 0.9)
	torpor_bg.visible = false
	torpor_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(torpor_bg)
	var torpor_fill := ColorRect.new()
	torpor_fill.name = "TorporFill"
	torpor_fill.color = TORPOR_COLOR
	torpor_bg.add_child(torpor_fill)
	var torpor_tick := ColorRect.new()
	torpor_tick.name = "TorporTick"
	torpor_tick.color = Color(1, 1, 1, 0.9)
	torpor_bg.add_child(torpor_tick)
	var hp_dbg := Label.new()
	hp_dbg.name = "HpDebug"
	hp_dbg.position = Vector2(172, 18)
	hp_dbg.size = Vector2(76, 16)
	root.add_child(hp_dbg)
	var line3 := HBoxContainer.new()
	line3.name = "Line3"
	line3.position = Vector2(8, 47)
	line3.custom_minimum_size = Vector2(160, 26)
	line3.add_theme_constant_override("separation", 4)
	root.add_child(line3)
	var tame_row := HBoxContainer.new()
	tame_row.name = "TameRow"
	tame_row.position = Vector2(8, 73)
	tame_row.custom_minimum_size = Vector2(160, 20)
	tame_row.visible = false
	root.add_child(tame_row)
	var tame_icon := TextureRect.new()
	tame_icon.name = "TameIcon"
	tame_icon.custom_minimum_size = Vector2(18, 18)
	tame_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tame_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tame_row.add_child(tame_icon)
	var tame_label := Label.new()
	tame_label.name = "TameLabel"
	tame_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tame_label.add_theme_font_size_override("font_size", 14)
	tame_row.add_child(tame_label)
	var tame_bar := ProgressBar.new()
	tame_bar.name = "TameBar"
	tame_bar.custom_minimum_size = Vector2(56, 8)
	tame_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tame_bar.show_percentage = false
	tame_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tame_row.add_child(tame_bar)
	var xp_bg := ColorRect.new()
	xp_bg.name = "XpBg"
	xp_bg.position = Vector2(8, 43)
	xp_bg.size = Vector2(160, 4)
	xp_bg.color = Color(0.08, 0.08, 0.1, 0.9)
	xp_bg.visible = false
	root.add_child(xp_bg)
	var xp_fill := ColorRect.new()
	xp_fill.name = "XpFill"
	xp_fill.size = Vector2(0, 4)
	xp_fill.color = Color(0.90, 0.72, 0.22, 0.95)
	xp_bg.add_child(xp_fill)
	var floats := Control.new()
	floats.name = "Floats"
	floats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floats.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(floats)
	var cb := _on_creature_float.bind(c)
	if not c.combat_float.is_connected(cb):
		c.combat_float.connect(cb)
	var sb := _on_status_float.bind(c)
	if c.has_signal("status_float") and not c.status_float.is_connected(sb):
		c.status_float.connect(sb)
	var entry := {
		"node": root,
		"line1": line1,
		"chip": chip,
		"chip_nature": "",
		"chip_ready": false,
		"bar_fill": bar_fill,
		"bar_recent": bar_recent,
		"torpor_bg": torpor_bg,
		"torpor_fill": torpor_fill,
		"torpor_tick": torpor_tick,
		"hp_dbg": hp_dbg,
		"line3": line3,
		"tame_row": tame_row,
		"tame_icon": tame_icon,
		"tame_label": tame_label,
		"tame_bar": tame_bar,
		"pill": pill,
		"xp_bg": xp_bg,
		"xp_fill": xp_fill,
		"floats": floats,
		"float_nodes": [],
		"alpha": 0.0,
		"reveal_until": 0.0,
		"hp_frac": 1.0,
		"recent_from": 1.0,
		"recent_left": 0.0,
		"flash_left": 0.0,
	}
	_entries[key] = entry
	return entry

func _update_entry(entry: Dictionary, c: Creature, cam: Camera3D, player: Player, dist: float, delta: float) -> void:
	var root := entry["node"] as Control
	var alpha := float(entry.get("alpha", 0.0))
	root.visible = alpha > 0.02
	root.modulate.a = alpha
	var scale := _distance_scale(dist)
	root.scale = Vector2(scale, scale)
	var top := c.get_global_transform_interpolated().origin + Vector3(0.0, c.def.height_meters * c.size_scale() + 0.3, 0.0)
	var screen := cam.unproject_position(top)
	root.position = screen + Vector2(-BASE_WIDTH * 0.5 * scale, -70.0 * scale)
	var full := c.get_instance_id() == _emphasis_id
	var line1 := entry["line1"] as Label
	var rel_col := _relation_color(c)
	line1.visible = full
	line1.add_theme_color_override("font_color", rel_col)
	# NATURES (owner 2026-10-28): the name is the animal's name only ("Alpha Velociraptor") and its
	# nature is the TAG directly under it ("Timid"); no nature, no chip and no gap.
	var title := CreatureNatures.display_title(c)
	var raw_name := ("%s  %s  [%s]" % [LevelDisplay.label(c.level), title, c.genetics.overall_tier() if c.genetics else &"?"]) if c.is_pet else ("%s  %s" % [LevelDisplay.label(c.level), title])
	line1.text = UiTokens.ellipsis(ThemeDB.fallback_font, raw_name, BASE_WIDTH - 20.0, 14)
	# The tag is configured only when it changes (its label width is measured on configure), so a
	# plate that keeps its nature costs nothing per frame and never re-measures between frames.
	var chip := entry.get("chip", null) as NatureChip
	if chip:
		var nat := String(c.nature_id()) if full else ""
		if not bool(entry.get("chip_ready", false)) or str(entry.get("chip_nature", "")) != nat:
			chip.configure(StringName(nat))
			entry["chip_nature"] = nat
			entry["chip_ready"] = true
			chip.position = CHIP_POS
	var bar_bg := root.get_node_or_null("BarBg") as ColorRect
	if bar_bg:
		# Every row under the name hangs off the bar: tag, gap, bar; no tag, the bar right under the name.
		var by := bar_top(chip != null and chip.visible) if full else 2.0
		entry["bar_y"] = by
		bar_bg.position = Vector2(8, by)
		bar_bg.size = Vector2(160 if full else 96, 14 if full else 6)
		(entry["line3"] as Control).position = Vector2(8, by + 18.0)
		(entry["tame_row"] as Control).position = Vector2(8, by + 44.0)
	root.size = Vector2(BASE_WIDTH, FULL_H if full else 18)
	root.custom_minimum_size = root.size
	var frac := c.health.fraction()
	var prev := float(entry.get("hp_frac", frac))
	if frac < prev:
		entry["recent_from"] = prev
		entry["recent_left"] = DAMAGE_CHUNK_SECONDS
		entry["flash_left"] = 0.12
	entry["hp_frac"] = frac
	var bar_w := 160.0 if full else 96.0
	var bar_h := 14.0 if full else 6.0
	var bar_fill := entry["bar_fill"] as ColorRect
	bar_fill.size = Vector2(bar_w * frac, bar_h)
	bar_fill.color = _hp_color(frac)
	var recent := entry["bar_recent"] as ColorRect
	var left := maxf(0.0, float(entry.get("recent_left", 0.0)) - delta)
	entry["recent_left"] = left
	if left > 0.0:
		var from_frac := float(entry.get("recent_from", frac))
		var shown_from := lerpf(frac, from_frac, left / DAMAGE_CHUNK_SECONDS)
		recent.position.x = bar_w * frac
		recent.size = Vector2(maxf(0.0, bar_w * (shown_from - frac)), bar_h)
	else:
		recent.size.x = 0.0
	var flash_left := maxf(0.0, float(entry.get("flash_left", 0.0)) - delta)
	entry["flash_left"] = flash_left
	root.modulate = Color(1.0, 1.0, 1.0, alpha)
	if flash_left > 0.0:
		var f := clampf(flash_left / 0.12, 0.0, 1.0)
		root.modulate = Color(1.0, 0.6 + f * 0.4, 0.6 + f * 0.4, alpha)
	_tick_torpor(entry, c, full, bar_w, bar_h)
	var hp_dbg := entry["hp_dbg"] as Label
	hp_dbg.visible = Game.debug_overlay
	if Game.debug_overlay:
		hp_dbg.text = "%.0f/%.0f" % [c.health.hp, c.health.max_hp]
	# Landscape phone: an emphasised creature that is neither the hunt target nor tameable shows its
	# name and bar only; with its status and tame rows the 176x72 pill covered the survivor beside it.
	# ASSUMPTION: statuses of a creature you are not fighting or taming can wait for the target plate.
	var rows := full and (not UiTokens.is_compact(get_viewport().get_visible_rect().size) or _in_focus(c, player))
	var line3 := entry["line3"] as Control
	if line3:
		line3.visible = rows
	_tick_status_icons(entry, c)
	_tick_tame_hint(entry, c, player, rows)
	_tick_xp(entry, c, full)
	_tick_floaters(entry, delta)
	_fit_pill(entry, full)

## Wild animals with any torpor: fill = torpor / max, the white tick = the knock-out threshold.
func _tick_torpor(entry: Dictionary, c: Creature, full: bool, bar_w: float, bar_h: float) -> void:
	var bg := entry.get("torpor_bg", null) as ColorRect
	if bg == null:
		return
	bg.visible = not c.is_pet and c.torpor > 0.05
	if not bg.visible:
		return
	var h := TORPOR_H if full else 3.0
	bg.position = Vector2(8, float(entry.get("bar_y", 2.0)) + bar_h + 1.0)
	bg.size = Vector2(bar_w, h)
	var fill := entry["torpor_fill"] as ColorRect
	fill.size = Vector2(bar_w * c.torpor_frac(), h)
	var tick := entry["torpor_tick"] as ColorRect
	tick.position = Vector2(bar_w * FieldTame.torpor_ko_frac() - 1.0, 0.0)
	tick.size = Vector2(2.0, h)

## Top of a full plate's HP bar: under the nature tag and its gap, else right under the name.
static func bar_top(has_nature: bool) -> float:
	return CHIP_POS.y + NatureChip.CHIP_H + CHIP_GAP if has_nature else CHIP_POS.y + 2.0

## Pill behind whatever rows are showing (compact: just the short bar).
func _fit_pill(entry: Dictionary, full: bool) -> void:
	var pill := entry.get("pill", null) as Control
	if pill == null:
		return
	if not full:
		pill.position = Vector2(4, -2)
		pill.size = Vector2(104, 10)
		return
	var by := float(entry.get("bar_y", bar_top(false)))
	var bottom := by + 17.0  # name, nature tag, then the HP bar
	var torpor := entry.get("torpor_bg", null) as Control
	if torpor and torpor.visible:
		bottom = by + 14.0 + 1.0 + TORPOR_H + 3.0  # the torpor strip under the HP bar
	var line3 := entry.get("line3", null) as Control
	if line3 and line3.visible:
		for g in line3.get_children():
			if (g as Control).visible:
				bottom = by + 44.0
				break
	var tame_row := entry.get("tame_row", null) as Control
	if tame_row and tame_row.visible:
		bottom = by + 64.0
	pill.position = Vector2(2, -2)
	pill.size = Vector2(BASE_WIDTH - 4.0, bottom + 2.0)

## The hunt target, or a creature the survivor can tame now: its plate keeps every row.
static func _in_focus(c: Creature, player: Player) -> bool:
	return (player.hunt != null and player.hunt.target == c) or FieldTame.can_attempt(c)

func _pick_emphasis(player: Player) -> int:
	if player.hunt and player.hunt.target and is_instance_valid(player.hunt.target) and not player.hunt.target.health.dead:
		return player.hunt.target.get_instance_id()
	var sel := player.controls.selection.current()  # the tapped animal shows its name, as in the reference
	if sel:
		return sel.get_instance_id()
	var best := 0
	var best_score := -1.0
	var now := _now_s()
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.health.dead:
			continue
		var score := 0.0
		if FieldTame.can_attempt(c):
			score = 100.0
		elif now - c.last_damaged_s <= 5.0:
			score = 50.0
		elif now - c.last_aggro_s <= 5.0:
			score = 40.0
		if score <= 0.0:
			continue
		score -= player.global_position.distance_to(c.global_position) * 0.02
		if score > best_score:
			best_score = score
			best = c.get_instance_id()
	return best

func _tick_xp(entry: Dictionary, c: Creature, full: bool) -> void:
	var bg := entry.get("xp_bg", null) as ColorRect
	var fill := entry.get("xp_fill", null) as ColorRect
	if bg == null or fill == null:
		return
	var show := c.is_pet and c.pet_record != null
	bg.visible = show
	if not show:
		return
	bg.position = Vector2(8, float(entry.get("bar_y", bar_top(false))) + 14.0 if full else 10.0)
	bg.size = Vector2(160 if full else 96, 4)
	var need := PetRecord.xp_to_next(c.pet_record.level)
	var frac := clampf(c.pet_record.xp / maxf(1.0, need), 0.0, 1.0)
	fill.size = Vector2(bg.size.x * frac, 4)

func _tick_tame_hint(entry: Dictionary, c: Creature, player: Player, full: bool = true) -> void:
	var row := entry.get("tame_row", null) as Control
	var icon := entry.get("tame_icon", null) as TextureRect
	var label := entry.get("tame_label", null) as Label
	if row == null or label == null:
		return
	var hint := FieldTame.plate_hint(c, player.inventory if player else null, player)
	if not full or hint.is_empty():
		row.visible = false
		return
	row.visible = true
	var food_id := StringName(str(hint.get("food_id", "")))
	if icon:
		icon.texture = _icon_for(food_id)
		icon.visible = icon.texture != null
	var kind := StringName(str(hint.get("kind", "")))
	var progress := float(hint.get("progress", 0.0))
	var needed := float(hint.get("needed", 3.0))
	var bar := entry.get("tame_bar", null) as ProgressBar
	if bar:
		bar.visible = kind != &"pen" and kind != &"need"
		bar.max_value = maxf(1.0, needed)
		bar.value = progress
	match kind:
		&"pen":
			label.text = "Tame in pen"
			label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
		&"need":
			label.text = str(hint.get("text", "needs food"))
			label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.4))
		_:
			# The odds the net will roll (FieldTame.plate_hint -> TamingOdds), before the survivor
			# commits; the feed progress rides along while feeds are still owed.
			var chance := float(hint.get("odds", -1.0))
			if chance >= 0.0:
				label.text = TamingOdds.caption(chance)
				if progress > 0.001 and progress + 0.001 < needed:
					label.text += "  %.0f/%.0f" % [progress, needed]
			else:
				label.text = "Tame  %.0f/%.0f" % [progress, needed]
			# Green when the throw is a good bet, amber when it is a coin flip or worse.
			label.add_theme_color_override("font_color",
				Color(0.55, 0.95, 0.65) if chance >= 0.5 else Color(0.95, 0.82, 0.45))

func _tick_status_icons(entry: Dictionary, c: Creature) -> void:
	var rows := _status_rows(c)
	var holder := entry["line3"] as HBoxContainer
	while holder.get_child_count() < rows.size():
		holder.add_child(STATUS_GLYPH_SCRIPT.new())
	for i in holder.get_child_count():
		var child := holder.get_child(i) as Control
		if i >= rows.size():
			child.visible = false
			continue
		var row: Dictionary = rows[i]
		child.visible = true
		if child.has_method("configure"):
			child.configure(
				str(row.get("glyph", "?")),
				row.get("color", Color.WHITE),
				float(row.get("frac", 1.0)),
				_status_icon(StringName(str(row.get("icon_id", ""))))
			)

func _status_rows(c: Creature) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_add_status(out, c.statuses, &"deep_bleed", "B", Color(0.95, 0.25, 0.2))
	if out.is_empty():
		_add_status(out, c.statuses, &"bleed", "B", Color(0.95, 0.3, 0.3))
	if out.is_empty():
		_add_status(out, c.statuses, &"bleeding_target", "B", Color(0.95, 0.3, 0.3))
	_add_status(out, c.statuses, &"venom", "V", UiTokens.POISON)
	if not _has_status(c.statuses, &"venom"):
		_add_status(out, c.statuses, &"poisoned_target", "V", UiTokens.POISON)
	_add_status(out, c.statuses, &"knockdown", "K", Color(1.0, 0.72, 0.4))
	_add_status(out, c.statuses, &"groggy", "G", Color(1.0, 0.86, 0.35))
	if not _has_status(c.statuses, &"groggy"):
		_add_status(out, c.statuses, &"dizziness", "G", Color(1.0, 0.86, 0.35))
	_add_status(out, c.statuses, &"fracture", "F", Color(0.93, 0.91, 1.0))
	if c.brain_state == &"sleep":
		out.append({"icon_id": "sleeping", "glyph": "Z", "color": Color(0.68, 0.72, 0.78), "frac": 1.0})
	return out

func _add_status(out: Array[Dictionary], statuses: StatusEffects, id: StringName, glyph: String, color: Color) -> void:
	var inst := statuses.get_instance(id)
	if inst == null:
		return
	var def := Data.status(id)
	var dur := def.duration if def else inst.time_left
	var frac := clampf(inst.time_left / maxf(0.001, dur), 0.0, 1.0)
	out.append({"icon_id": str(id), "glyph": glyph, "color": color, "frac": frac})

func _has_status(statuses: StatusEffects, id: StringName) -> bool:
	return statuses.get_instance(id) != null

func _on_creature_float(amount: float, kind: StringName, c: Creature) -> void:
	var key := c.get_instance_id()
	if not _entries.has(key):
		return
	if amount < 0.5 and kind != &"heal" and kind != &"xp" and not CombatAvoid.TEXT.has(kind):
		return  # a bleed tick under 1 HP read "-0" over the plate
	var entry: Dictionary = _entries[key]
	var layer := entry["floats"] as Control
	var label := Label.new()
	var shown := "%d" % int(round(amount))
	if kind == &"heal":
		shown = "+%s" % shown
	elif kind == &"xp":
		shown = "+%s XP" % shown
	elif CombatAvoid.TEXT.has(kind):  # an avoided hit emits 0.0; it read "-0" over the plate
		shown = CombatAvoid.TEXT[kind]
	else:
		shown = "-%s" % shown
	# White = normal, grey = not very effective, orange = super effective, red = critical.
	var col := Color(1.0, 1.0, 1.0)
	var fs := 16
	match kind:
		&"heal":
			col = Color(0.45, 1.0, 0.5)
		&"xp":
			col = Color(1.0, 0.85, 0.35)
			fs = 15
		&"dot":
			col = Color(0.95, 0.4, 0.4)
			fs = 14
		&"weak":
			col = Color(0.62, 0.62, 0.62)
			fs = 14
		&"dodge", &"block":
			col = CombatAvoid.COLOR
			fs = 14
		&"strong":
			col = Color(1.0, 0.6, 0.15)
			fs = 20
		&"crit":
			col = Color(1.0, 0.18, 0.12)
			fs = 24
			shown += "!"
	label.text = shown
	label.position = Vector2(70 + randf_range(-16.0, 16.0), 12)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4 if fs >= 20 else 3)
	layer.add_child(label)
	var nodes: Array = entry.get("float_nodes", [])
	nodes.append({"node": label, "age": 0.0})
	entry["float_nodes"] = nodes
	_entries[key] = entry

## Status name in its colour (BLEED, VENOM, GROGGY...) rising a little slower than numbers.
func _on_status_float(id: StringName, c: Creature) -> void:
	var key := c.get_instance_id()
	if not _entries.has(key):
		return
	var entry: Dictionary = _entries[key]
	var layer := entry["floats"] as Control
	var def := Data.status(id)
	var label := Label.new()
	label.text = (def.display_name if def else str(id)).replace("_", " ").to_upper() + ("!" if def == null else "")
	var nodes: Array = entry.get("float_nodes", [])
	# Statuses applied together (knockdown + groggy + bleed) stack down over the plate instead of
	# printing over each other; stacked upward they rose into the HUD above a lifted plate.
	var y0 := -6.0
	for row in nodes:
		y0 += 18.0 if (row as Dictionary).has("y0") else 0.0
	label.position = Vector2(40 + randf_range(-10.0, 10.0), y0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Creature.status_color(id))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	layer.add_child(label)
	nodes.append({"node": label, "age": -0.3, "y0": y0})
	entry["float_nodes"] = nodes
	_entries[key] = entry

func _tick_floaters(entry: Dictionary, delta: float) -> void:
	var nodes: Array = entry.get("float_nodes", [])
	for i in range(nodes.size() - 1, -1, -1):
		var row: Dictionary = nodes[i]
		var node := row.get("node", null) as Label
		if node == null or not is_instance_valid(node):
			nodes.remove_at(i)
			continue
		var age := float(row.get("age", 0.0)) + delta
		row["age"] = age
		var y0 := float(row.get("y0", 12.0))
		node.position.y = y0 - maxf(0.0, age) * 34.0
		node.modulate.a = clampf(1.0 - age / 0.9, 0.0, 1.0)
		nodes[i] = row
		if age >= 0.9:
			node.queue_free()
			nodes.remove_at(i)
	entry["float_nodes"] = nodes

func _relation_color(c: Creature) -> Color:
	if c.is_pet:
		return Color(0.42, 0.95, 0.5)
	if c.brain_state == &"sleep":
		return Color(0.72, 0.72, 0.72)
	if _is_herbivore(c):
		return Color(0.95, 0.78, 0.32)
	return Color(0.95, 0.35, 0.28)

func _is_herbivore(c: Creature) -> bool:
	var all: Dictionary = Data.creature_ai.get("archetypes", {})
	var row: Variant = all.get(str(c.def.archetype), {})
	if row is Dictionary:
		return bool((row as Dictionary).get("is_herbivore", false))
	return bool(Data.creature_ai.get("default", {}).get("is_herbivore", false))

func _distance_scale(dist: float) -> float:
	if dist <= 15.0:
		return 1.0
	if dist >= 45.0:
		return MIN_SCALE
	return lerpf(1.0, MIN_SCALE, (dist - 15.0) / 30.0)

func _hp_color(frac: float) -> Color:
	if frac >= 0.6:
		return Color(0.22, 0.9, 0.4, 0.95)
	if frac >= 0.3:
		return Color(0.95, 0.78, 0.22, 0.95)
	return Color(0.95, 0.22, 0.22, 0.95)

func _remove_entry(key: int) -> void:
	if not _entries.has(key):
		return
	var e: Dictionary = _entries[key]
	var node := e.get("node", null) as Control
	if node and is_instance_valid(node):
		node.queue_free()
	_entries.erase(key)

func _load_icon_manifest() -> void:
	var path := "res://data/icons_manifest.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var icons: Variant = (parsed as Dictionary).get("icons", {})
		if icons is Dictionary:
			_icons = icons as Dictionary

## White status drawing from the UiIcons set; the coloured item-manifest icon only when it has none.
func _status_icon(id: StringName) -> Texture2D:
	return UiIcons.icon(id) if UiIcons.path_for(id) != "" else _icon_for(id)

func _icon_for(id: StringName) -> Texture2D:
	if id == &"":
		return null
	var icon_path := str(_icons.get(str(id), ""))
	if icon_path == "":
		return null
	if _icon_cache.has(icon_path):
		return _icon_cache[icon_path] as Texture2D
	if not ResourceLoader.exists(icon_path):
		return null
	var tex := load(icon_path) as Texture2D
	if tex:
		_icon_cache[icon_path] = tex
	return tex

func _now_s() -> float:
	return float(Time.get_ticks_msec()) * 0.001
