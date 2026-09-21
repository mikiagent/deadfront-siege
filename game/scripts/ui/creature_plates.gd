class_name CreaturePlates
extends CanvasLayer
## Screen-space creature and loot plates.

const MAX_DIST := 45.0
const NEAR_DIST := 10.0
const BASE_WIDTH := 176.0
const DAMAGE_CHUNK_SECONDS := 0.6
const STATUS_GLYPH_SCRIPT: GDScript = preload("res://scripts/ui/status_glyph.gd")

var _root: Control
var _entries: Dictionary = {} ## creature instance id -> Dictionary
var _corpse_entries: Dictionary = {} ## corpse instance id -> Dictionary
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}

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
	var player := get_tree().get_first_node_in_group("player") as Player
	if cam == null or player == null:
		return
	_tick_creatures(cam, player, delta)
	_tick_corpses(cam, player, delta)

func _tick_creatures(cam: Camera3D, player: Player, delta: float) -> void:
	var now := _now_s()
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
	for key in _entries.keys():
		if seen.has(key):
			continue
		_remove_entry(int(key))

func _tick_corpses(cam: Camera3D, player: Player, delta: float) -> void:
	var seen: Dictionary = {}
	for n in get_tree().get_nodes_in_group("corpse"):
		var corpse := n as Corpse
		if corpse == null:
			continue
		var dist := player.global_position.distance_to(corpse.global_position)
		if dist > MAX_DIST:
			continue
		seen[corpse.get_instance_id()] = true
		var e := _ensure_corpse_entry(corpse)
		var show := dist <= 14.0 or corpse.tapped_recently(3.0)
		var alpha := float(e.get("alpha", 0.0))
		alpha = move_toward(alpha, 1.0 if show else 0.0, delta * 4.5)
		e["alpha"] = alpha
		var node := e["node"] as Control
		node.visible = alpha > 0.02
		node.modulate.a = alpha
		var knife := e.get("knife", null) as TextureRect
		if knife:
			knife.visible = corpse.tapped_recently(4.0)
			knife.modulate = Color.WHITE if player.inventory.has_tool_class(&"knife") else Color(1.0, 0.4, 0.35)
		var world := corpse.plate_anchor()
		var screen := cam.unproject_position(world)
		node.position = screen + Vector2(-70, -28)
		_corpse_entries[corpse.get_instance_id()] = e
	for key in _corpse_entries.keys():
		if seen.has(key):
			continue
		_remove_corpse_entry(int(key))

func _forced_visible(c: Creature, player: Player, now: float) -> bool:
	if player.hunt and player.hunt.target == c:
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
	root.custom_minimum_size = Vector2(BASE_WIDTH, 78)
	root.size = root.custom_minimum_size
	root.pivot_offset = Vector2(BASE_WIDTH * 0.5, 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(root)
	var line1 := Label.new()
	line1.name = "Line1"
	line1.position = Vector2(8, 0)
	line1.size = Vector2(BASE_WIDTH - 16.0, 16.0)
	root.add_child(line1)
	var bar_bg := ColorRect.new()
	bar_bg.name = "BarBg"
	bar_bg.position = Vector2(8, 20)
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
	var hp_dbg := Label.new()
	hp_dbg.name = "HpDebug"
	hp_dbg.position = Vector2(172, 18)
	hp_dbg.size = Vector2(76, 16)
	root.add_child(hp_dbg)
	var line3 := HBoxContainer.new()
	line3.name = "Line3"
	line3.position = Vector2(8, 38)
	line3.custom_minimum_size = Vector2(160, 18)
	root.add_child(line3)
	var tame_row := HBoxContainer.new()
	tame_row.name = "TameRow"
	tame_row.position = Vector2(8, 56)
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
	tame_row.add_child(tame_label)
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
		"bar_fill": bar_fill,
		"bar_recent": bar_recent,
		"hp_dbg": hp_dbg,
		"line3": line3,
		"tame_row": tame_row,
		"tame_icon": tame_icon,
		"tame_label": tame_label,
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

func _ensure_corpse_entry(corpse: Corpse) -> Dictionary:
	var key := corpse.get_instance_id()
	if _corpse_entries.has(key):
		return _corpse_entries[key]
	var node := Control.new()
	node.custom_minimum_size = Vector2(140, 22)
	node.size = node.custom_minimum_size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.position = Vector2.ZERO
	label.size = node.size
	label.text = "Loot · %s" % corpse.species_display_name()
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.78))
	node.add_child(label)
	# Butchering needs a knife: show it, red while the bag has none.
	var knife := TextureRect.new()
	knife.name = "Knife"
	knife.texture = ItemIcons.texture(&"stone_knife")
	knife.custom_minimum_size = Vector2(12, 12)
	knife.size = Vector2(12, 12)
	knife.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knife.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	knife.position = Vector2(node.size.x + 4.0, 2.0)
	node.add_child(knife)
	_root.add_child(node)
	var entry := {"node": node, "alpha": 0.0, "knife": knife}
	_corpse_entries[key] = entry
	return entry

func _update_entry(entry: Dictionary, c: Creature, cam: Camera3D, player: Player, dist: float, delta: float) -> void:
	var root := entry["node"] as Control
	var alpha := float(entry.get("alpha", 0.0))
	root.visible = alpha > 0.02
	root.modulate.a = alpha
	var scale := _distance_scale(dist)
	root.scale = Vector2(scale, scale)
	var top := c.get_global_transform_interpolated().origin + Vector3(0.0, c.def.height_meters + 0.3, 0.0)
	var screen := cam.unproject_position(top)
	root.position = screen + Vector2(-BASE_WIDTH * 0.5 * scale, -70.0 * scale)
	var line1 := entry["line1"] as Label
	var rel_col := _relation_color(c)
	line1.add_theme_color_override("font_color", rel_col)
	line1.text = ("Lv. %d  %s  [%s]" % [c.level, str(c.def.species).capitalize(), c.genetics.overall_tier() if c.genetics else &"?"]) if c.is_pet else ("Lv. %d  %s" % [c.level, str(c.def.species).capitalize()])
	var frac := c.health.fraction()
	var prev := float(entry.get("hp_frac", frac))
	if frac < prev:
		entry["recent_from"] = prev
		entry["recent_left"] = DAMAGE_CHUNK_SECONDS
		entry["flash_left"] = 0.12
	entry["hp_frac"] = frac
	var bar_fill := entry["bar_fill"] as ColorRect
	bar_fill.size.x = 160.0 * frac
	bar_fill.color = _hp_color(frac)
	var recent := entry["bar_recent"] as ColorRect
	var left := maxf(0.0, float(entry.get("recent_left", 0.0)) - delta)
	entry["recent_left"] = left
	if left > 0.0:
		var from_frac := float(entry.get("recent_from", frac))
		var shown_from := lerpf(frac, from_frac, left / DAMAGE_CHUNK_SECONDS)
		recent.position.x = 160.0 * frac
		recent.size.x = maxf(0.0, 160.0 * (shown_from - frac))
	else:
		recent.size.x = 0.0
	var flash_left := maxf(0.0, float(entry.get("flash_left", 0.0)) - delta)
	entry["flash_left"] = flash_left
	root.modulate = Color(1.0, 1.0, 1.0, alpha)
	if flash_left > 0.0:
		var f := clampf(flash_left / 0.12, 0.0, 1.0)
		root.modulate = Color(1.0, 0.6 + f * 0.4, 0.6 + f * 0.4, alpha)
	var hp_dbg := entry["hp_dbg"] as Label
	hp_dbg.visible = Game.debug_overlay
	if Game.debug_overlay:
		hp_dbg.text = "%.0f/%.0f" % [c.health.hp, c.health.max_hp]
	_tick_status_icons(entry, c)
	_tick_tame_hint(entry, c, player)
	_tick_floaters(entry, delta)

func _tick_tame_hint(entry: Dictionary, c: Creature, player: Player) -> void:
	var row := entry.get("tame_row", null) as Control
	var icon := entry.get("tame_icon", null) as TextureRect
	var label := entry.get("tame_label", null) as Label
	if row == null or label == null:
		return
	var hint := FieldTame.plate_hint(c, player.inventory if player else null)
	if hint.is_empty():
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
	match kind:
		&"pen":
			label.text = "Tame in pen"
			label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
		&"need":
			label.text = str(hint.get("text", "needs food"))
			label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.4))
		_:
			label.text = "Tame  %.0f/%.0f" % [progress, needed]
			label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))

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
				_icon_for(StringName(str(row.get("icon_id", ""))))
			)

func _status_rows(c: Creature) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_add_status(out, c.statuses, &"deep_bleed", "B", Color(0.95, 0.25, 0.2))
	if out.is_empty():
		_add_status(out, c.statuses, &"bleed", "B", Color(0.95, 0.3, 0.3))
	if out.is_empty():
		_add_status(out, c.statuses, &"bleeding_target", "B", Color(0.95, 0.3, 0.3))
	_add_status(out, c.statuses, &"venom", "V", Color(0.45, 0.95, 0.35))
	if not _has_status(c.statuses, &"venom"):
		_add_status(out, c.statuses, &"poisoned_target", "V", Color(0.45, 0.95, 0.35))
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
	var entry: Dictionary = _entries[key]
	var layer := entry["floats"] as Control
	var label := Label.new()
	var shown := "%d" % int(round(amount))
	if kind == &"heal":
		shown = "+%s" % shown
	elif kind == &"xp":
		shown = "+%s XP" % shown
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
	label.position = Vector2(40 + randf_range(-10.0, 10.0), -6)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Creature.status_color(id))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	layer.add_child(label)
	var nodes: Array = entry.get("float_nodes", [])
	nodes.append({"node": label, "age": -0.3, "y0": -6.0})
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
		return 0.7
	return lerpf(1.0, 0.7, (dist - 15.0) / 30.0)

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

func _remove_corpse_entry(key: int) -> void:
	if not _corpse_entries.has(key):
		return
	var e: Dictionary = _corpse_entries[key]
	var node := e.get("node", null) as Control
	if node and is_instance_valid(node):
		node.queue_free()
	_corpse_entries.erase(key)

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
