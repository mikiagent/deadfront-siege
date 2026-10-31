extends Node3D
## MAPLAB: a top-down island authoring tool. Paint land and sea, height classes, biome zones,
## rivers, lakes and roads on a grid at island scale, drop markers (town, dock, camp, guild,
## landmarks, resource clusters, creature spawns, claim-free areas) with their properties, then
## export game/data/maps/<name>.map.json (format: docs/current/map-format.md) and a preview PNG.
##
## Run: Godot --path game -- --lab=map_lab [--map=<name>] [--select=<marker id>] [--validate]
##   --map=<name>      open game/data/maps/<name>.map.json (else a blank home-size map)
##   --select=<id>     select that marker (its property fields show on the right)
##   --validate        run the validator at start (the issues list shows on the right)
##   --hide=a,b        start with these layers off (zone, height, water, road, markers)
##   --make-sample     write the sample island to game/data/maps/sample.map.json + .png and quit
## Mouse and touch: tap or drag on the map paints with the active tool; ctrl+Z / ctrl+Y undo/redo.

const EXPORT_DIR := "res://data/maps/"
const DRAFT_DIR := "user://maplab/"
const LEFT_W := 420.0
const RIGHT_W := 352.0
const TAP := 64.0

var doc: MapDoc
var tool := "land"
var fill_mode := false
var brush := 2.0
var show := {"zone": true, "height": true, "water": true, "road": true, "markers": true, "grid": false}
var selected := -1

var _root: Control
var _parts: Dictionary
var _canvas: MapCanvas
var _group := ButtonGroup.new()
var _brush_label: Label
var _name_edit: LineEdit
var _climate_opt: OptionButton
var _preset_opt: OptionButton
var _size_spin: SpinBox
var _cell_spin: SpinBox
var _props_box: VBoxContainer
var _issues: Label
var _status: Label
var _undo_b: Button
var _redo_b: Button
var _dragging_marker := false
var _last_cell := Vector2i(-999, -999)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--make-sample" in args:
		_make_sample()
		return
	doc = MapDoc.make()
	for a in args:
		if a.begins_with("--map="):
			var errs: Array = []
			var d := MapDoc.load_file(EXPORT_DIR + a.substr(6) + ".map.json", errs)
			if d != null:
				doc = d
			else:
				push_error("[map_lab] %s" % "; ".join(errs))
		elif a.begins_with("--hide="):
			for l in a.substr(7).split(","):
				show[l] = false
	_build_ui()
	for a in args:
		if a.begins_with("--select="):
			_select(int(a.substr(9)))
		elif a == "--validate":
			_validate()
	_refresh()
	print("[boot] lab=map_lab map=%s cells=%d" % [doc.name, doc.cells])

# ---------------------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)
	_parts = SheetChrome.build(_root, "Map Lab")
	(_parts["back"] as Button).pressed.connect(get_tree().quit)
	(_parts["close"] as Button).pressed.connect(get_tree().quit)
	var right: HBoxContainer = _parts["right"]
	_undo_b = _action("Undo", _undo)
	_redo_b = _action("Redo", _redo)
	for b in [_undo_b, _redo_b, _action("Validate", _validate), _action("Export", _export, &"cta")]:
		b.custom_minimum_size.x = 120
		right.add_child(b)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	(_parts["body"] as Control).add_child(row)
	row.add_child(_side(_tools_panel(), LEFT_W))
	_canvas = MapCanvas.new()
	_canvas.lab = self
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_canvas)
	row.add_child(_side(_map_panel(), RIGHT_W))
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	SheetChrome.fit(_parts, view, UiTokens.safe_insets(get_viewport()))

func _side(content: Control, w: float) -> Control:
	var p := SheetChrome.panel()
	p.custom_minimum_size.x = w
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	sc.add_child(m)
	m.add_child(content)
	return p

func _tools_panel() -> Control:
	var v := _vbox()
	v.add_child(_section("Paint"))
	var g := _grid(3)
	g.add_child(_tool_btn("Land", "land", Color("#9aa070")))
	g.add_child(_tool_btn("Sea", "sea", Color("#2b5c7a")))
	g.add_child(_tool_btn("Erase", "erase", Color("#555555")))
	for i in MapDoc.HEIGHT_NAMES.size():
		var col := Color("#9aa070")
		col = col if i == 0 else (col.lightened(0.22) if i == 1 else col.lerp(Color("#6e655c"), 0.65))
		g.add_child(_tool_btn(MapDoc.HEIGHT_NAMES[i].capitalize(), "height:%d" % i, col))
	g.add_child(_tool_btn("River", "water:1", Color("#4a9ad8")))
	g.add_child(_tool_btn("Lake", "water:2", Color("#2f78b8")))
	g.add_child(_tool_btn("Road", "road", Color("#d8bd8a")))
	var fb := _action("Fill: off", Callable())
	fb.toggle_mode = true
	fb.toggled.connect(func(on: bool) -> void:
		fill_mode = on
		fb.text = "Fill: on" if on else "Fill: off")
	g.add_child(fb)
	v.add_child(g)
	var br := HBoxContainer.new()
	br.add_child(_action("-", func() -> void: _set_brush(brush - 1.0)))
	_brush_label = SheetChrome.label("", 22)
	_brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brush_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_brush_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(_brush_label)
	br.add_child(_action("+", func() -> void: _set_brush(brush + 1.0)))
	for b in [br.get_child(0), br.get_child(2)]:
		(b as Button).custom_minimum_size.x = TAP
	v.add_child(br)
	v.add_child(_section("Zones"))
	g = _grid(3)
	for i in BiomeZones.ZONE_NAMES.size():
		var z := BiomeZones.ZONE_NAMES[i]
		g.add_child(_tool_btn(z.capitalize(), "zone:%d" % (i + 1), Color.from_string(str(BiomeZones.row_of(z).get("map", "#888888")), Color.GRAY)))
	g.add_child(_tool_btn("Unset", "zone:0", Color("#9aa070")))
	v.add_child(g)
	v.add_child(_section("Markers"))
	g = _grid(3)
	g.add_child(_tool_btn("Select", "select", Color.WHITE))
	for k in MapDoc.MARKER_KINDS:
		g.add_child(_tool_btn("No-claim" if k == "claim_free" else k.capitalize(), "marker:" + k, MapDoc.MARKER_COLORS[k]))
	v.add_child(g)
	_set_brush(brush)
	return v

func _map_panel() -> Control:
	var v := _vbox()
	v.add_child(_section("Selected marker"))
	_props_box = _vbox()
	v.add_child(_props_box)
	v.add_child(_section("Issues"))
	_issues = SheetChrome.label("Press Validate.", 16, UiTokens.META)
	_issues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_issues.custom_minimum_size.x = RIGHT_W - 40.0
	v.add_child(_issues)
	v.add_child(_section("Map"))
	_name_edit = LineEdit.new()
	_name_edit.text = doc.name
	_name_edit.custom_minimum_size.y = TAP
	_name_edit.text_changed.connect(func(t: String) -> void: doc.name = t.strip_edges().validate_filename())
	v.add_child(_name_edit)
	_climate_opt = OptionButton.new()
	_climate_opt.custom_minimum_size.y = TAP
	for c in _climates():
		_climate_opt.add_item(c)
	_climate_opt.select(maxi(0, _climates().find(doc.climate)))
	_climate_opt.item_selected.connect(func(i: int) -> void:
		doc.begin_edit()
		doc.climate = _climate_opt.get_item_text(i)
		_refresh())
	v.add_child(_climate_opt)
	var g := _grid(2)
	_preset_opt = OptionButton.new()
	_preset_opt.custom_minimum_size.y = TAP
	for p in ["Home 416 m", "Tutorial 880 m", "Custom"]:
		_preset_opt.add_item(p)
	_preset_opt.select(0 if is_equal_approx(doc.size_m, 416.0) else (1 if is_equal_approx(doc.size_m, 880.0) else 2))
	_preset_opt.item_selected.connect(func(i: int) -> void:
		if i < 2:
			_size_spin.value = MapDoc.PRESETS["home" if i == 0 else "tutorial"])
	g.add_child(_preset_opt)
	_size_spin = _spin(64, 1200, 8, doc.size_m, " m")
	g.add_child(_size_spin)
	_cell_spin = _spin(2, 16, 1, doc.cell_m, " m cell")
	g.add_child(_cell_spin)
	g.add_child(_action("New map", func() -> void:
		doc.begin_edit()
		doc.resize(_size_spin.value, _cell_spin.value)
		selected = -1
		_refresh()))
	v.add_child(g)
	v.add_child(_section("Layers"))
	g = _grid(2)
	for l in ["zone", "height", "water", "road", "markers", "grid"]:
		var cb := CheckButton.new()
		cb.text = {"zone": "Zones", "height": "Height", "water": "Water", "road": "Roads", "markers": "Markers", "grid": "Grid"}[l]
		cb.button_pressed = bool(show[l])
		cb.custom_minimum_size.y = TAP
		cb.toggled.connect(func(on: bool) -> void:
			show[l] = on
			_refresh())
		g.add_child(cb)
	v.add_child(g)
	v.add_child(_section("Drafts"))
	g = _grid(2)
	g.add_child(_action("Save draft", _save_draft))
	g.add_child(_action("Load draft", _load_draft))
	v.add_child(g)
	_status = SheetChrome.label("", 16, UiTokens.META)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	v.add_child(_section("Legend"))
	g = _grid(2)
	for row in [["Sea", Color("#2b5c7a")], ["Land, no zone", Color("#9aa070")], ["Hill (lighter)", Color("#9aa070").lightened(0.22)],
			["Mountain", Color("#9aa070").lerp(Color("#6e655c"), 0.65)], ["River", Color("#4a9ad8")], ["Lake", Color("#2f78b8")], ["Road", Color("#d8bd8a")]]:
		g.add_child(_swatch_label(str(row[0]), row[1]))
	for k in MapDoc.MARKER_KINDS:
		g.add_child(_swatch_label(k.replace("_", "-").capitalize(), MapDoc.MARKER_COLORS[k]))
	v.add_child(g)
	return v

func _vbox() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	return v

func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	return g

func _section(t: String) -> Label:
	return SheetChrome.section_label(t, get_viewport().get_visible_rect().size)

func _action(t: String, cb: Callable, kind: StringName = &"ghost") -> Button:
	var b := SheetChrome.action_button(t, kind)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

func _swatch(col: Color) -> ImageTexture:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK if col.a > 0.0 else Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(1, 1, 16, 16), col)
	return ImageTexture.create_from_image(img)

func _tool_btn(t: String, id: String, col: Color) -> Button:
	var b := _action(t, func() -> void: tool = id)
	b.toggle_mode = true
	b.button_group = _group
	b.button_pressed = id == tool
	b.icon = _swatch(col)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("pressed", SheetChrome.action_style(&"cta", false))
	b.add_theme_stylebox_override("hover_pressed", SheetChrome.action_style(&"cta", false, 0.08))
	b.add_theme_color_override("font_pressed_color", UiTokens.CTA_INK)
	b.add_theme_color_override("font_hover_pressed_color", UiTokens.CTA_INK)
	return b

func _swatch_label(t: String, col: Color) -> Control:
	var h := HBoxContainer.new()
	var r := TextureRect.new()
	r.texture = _swatch(col)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(r)
	h.add_child(SheetChrome.label(t, 16, UiTokens.META))
	return h

func _spin(lo: float, hi: float, step: float, v: float, suffix: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.suffix = suffix
	s.custom_minimum_size = Vector2(0, TAP)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

func _climates() -> Array:
	return BiomeMaterial.rows().keys().filter(func(k: Variant) -> bool:
		return BiomeMaterial.rows()[k] is Dictionary and (BiomeMaterial.rows()[k] as Dictionary).has("zones") and str(k) != "zones")

func _set_brush(v: float) -> void:
	brush = clampf(v, 0.0, 12.0)
	_brush_label.text = "Brush %d" % int(brush)

# ---------------------------------------------------------------------------- painting

## A press on the map at world point `w` (metres).
func press(w: Vector2) -> void:
	var cl := doc.cell_of(w.x, w.y)
	_last_cell = Vector2i(-999, -999)
	if tool == "select":
		selected = _marker_at(w)
		_dragging_marker = selected >= 0
		if _dragging_marker:
			doc.begin_edit()
		_select(selected)
		return
	if tool.begins_with("marker:"):
		if not doc.in_grid(cl.x, cl.y):
			return
		doc.begin_edit()
		var m := doc.add_marker(tool.substr(7), w.x, w.y)
		_select(int(m["id"]))
		_refresh()
		return
	doc.begin_edit()
	if fill_mode and tool != "erase":
		var lv := _layer_value()
		doc.fill(lv[0], cl.x, cl.y, lv[1])
	else:
		_stroke(cl)
	_refresh()

func drag(w: Vector2) -> void:
	if tool == "select":
		if _dragging_marker:
			var m := doc.marker(selected)
			m["x"] = snappedf(clampf(w.x, -doc.size_m * 0.5, doc.size_m * 0.5), 0.1)
			m["z"] = snappedf(clampf(w.y, -doc.size_m * 0.5, doc.size_m * 0.5), 0.1)
			_canvas.queue_redraw()
		return
	if tool.begins_with("marker:") or fill_mode:
		return
	var cl := doc.cell_of(w.x, w.y)
	# Interpolate so a fast drag leaves a continuous line, not dots.
	if _last_cell.x > -999:
		var steps := maxi(1, int(Vector2(cl - _last_cell).length() * 2.0))
		for i in steps:
			var p := Vector2(_last_cell).lerp(Vector2(cl), float(i + 1) / float(steps))
			_stroke(Vector2i(roundi(p.x), roundi(p.y)))
	else:
		_stroke(cl)
	_refresh()

func release() -> void:
	_dragging_marker = false
	_last_cell = Vector2i(-999, -999)
	if tool == "select" and selected >= 0:
		_select(selected)

func _stroke(cl: Vector2i) -> void:
	_last_cell = cl
	if tool == "erase":
		for l in ["height", "zone", "water", "road"]:
			doc.paint(l, cl.x, cl.y, brush, 0)
		return
	var lv := _layer_value()
	doc.paint(lv[0], cl.x, cl.y, brush, lv[1])

func _layer_value() -> Array:
	match tool:
		"land": return ["land", 1]
		"sea": return ["land", 0]
		"road": return ["road", 1]
	var parts := tool.split(":")
	return [parts[0], int(parts[1])]

func _marker_at(w: Vector2) -> int:
	var best := -1
	var best_d := doc.cell_m * 4.0
	for m in doc.markers:
		var d := w.distance_to(Vector2(float(m["x"]), float(m["z"])))
		if d < best_d:
			best_d = d
			best = int(m["id"])
	return best

func _undo() -> void:
	doc.undo()
	_after_history()

func _redo() -> void:
	doc.redo()
	_after_history()

func _after_history() -> void:
	if doc.marker(selected).is_empty():
		selected = -1
	_select(selected)
	_size_spin.value = doc.size_m
	_cell_spin.value = doc.cell_m
	_refresh()

func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or not (k.ctrl_pressed or k.meta_pressed):
		return
	if k.keycode == KEY_Z and k.shift_pressed or k.keycode == KEY_Y:
		_redo()
	elif k.keycode == KEY_Z:
		_undo()

func _refresh() -> void:
	_canvas.set_doc_image(doc.image(show))
	_undo_b.disabled = not doc.can_undo()
	_redo_b.disabled = not doc.can_redo()
	var land := doc.count("land", 1)
	_status.text = "%s, %d x %d cells of %.0f m, land %.0f%% (%.0f ha), %d markers" % [
		doc.climate, doc.cells, doc.cells, doc.cell_m, 100.0 * float(land) / float(doc.cells * doc.cells),
		float(land) * doc.cell_m * doc.cell_m / 10000.0, doc.markers.size()]
	_climate_opt.select(maxi(0, _climates().find(doc.climate)))

# ---------------------------------------------------------------------------- marker properties

func _select(id: int) -> void:
	selected = id
	for c in _props_box.get_children():
		c.queue_free()
	var m := doc.marker(id)
	if m.is_empty():
		_props_box.add_child(SheetChrome.label("Tap a marker with Select.", 16, UiTokens.META))
		_canvas.queue_redraw()
		return
	_props_box.add_child(SheetChrome.label("%s #%d at %.0f, %.0f m" % [str(m["kind"]).capitalize(), id, float(m["x"]), float(m["z"])], 18))
	var p: Dictionary = m["props"]
	var keys := p.keys()
	keys.sort()
	for key in keys:
		var k := str(key)
		var h := HBoxContainer.new()
		var l := SheetChrome.label(k.replace("_m", " (m)").capitalize(), 16, UiTokens.META)
		l.custom_minimum_size.x = 110
		h.add_child(l)
		var field: Control
		match k:
			"species", "resource", "type":
				var o := OptionButton.new()
				var opts: Array = MapDoc._species() if k == "species" else (MapDoc.landmark_types() if k == "type" else Array(MapDoc.RESOURCES))
				# LANDMARKS M1: an empty landmark type is a plain point of interest.
				if k == "type":
					opts = [""] + opts
				opts.sort()
				for s in opts:
					o.add_item(str(s))
				o.select(opts.find(str(p[k])))
				o.item_selected.connect(func(i: int) -> void: _set_prop(id, k, o.get_item_text(i)))
				field = o
			"level", "count", "radius_m":
				var s := _spin(1, 60 if k == "level" else (200 if k == "radius_m" else 50), 1, float(p[k]), "")
				s.value_changed.connect(func(v: float) -> void: _set_prop(id, k, int(v) if k != "radius_m" else v))
				field = s
			_:
				var e := LineEdit.new()
				e.text = str(p[k])
				e.text_submitted.connect(func(t: String) -> void: _set_prop(id, k, t))
				e.focus_exited.connect(func() -> void: _set_prop(id, k, e.text))
				field = e
		field.custom_minimum_size.y = TAP
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(field)
		_props_box.add_child(h)
	_props_box.add_child(_action("Delete marker", func() -> void:
		doc.begin_edit()
		doc.remove_marker(id)
		_select(-1)
		_refresh(), &"danger"))
	_canvas.queue_redraw()

func _set_prop(id: int, k: String, v: Variant) -> void:
	var m := doc.marker(id)
	if m.is_empty() or (m["props"] as Dictionary).get(k) == v:
		return
	doc.begin_edit()
	m["props"][k] = v
	_refresh()
	_canvas.queue_redraw()

# ---------------------------------------------------------------------------- files

func _validate() -> Array[Dictionary]:
	var list := doc.issues()
	var lines: PackedStringArray = []
	for i in list:
		lines.append("%s  %s" % ["ERROR" if i["level"] == "error" else "warn", i["msg"]])
	_issues.text = "No issues." if lines.is_empty() else "\n".join(lines)
	_issues.add_theme_color_override("font_color", UiTokens.LIFE if not doc.errors().is_empty() else UiTokens.META)
	return list

func _save_draft() -> void:
	var path := DRAFT_DIR + doc.name + ".map.json"
	_status.text = "Saved draft %s" % path if doc.save_file(ProjectSettings.globalize_path(path)) == OK else "Could not save %s" % path

func _load_draft() -> void:
	for path in [DRAFT_DIR + doc.name + ".map.json", EXPORT_DIR + doc.name + ".map.json"]:
		if FileAccess.file_exists(path):
			var errs: Array = []
			var d := MapDoc.load_file(path, errs)
			if d != null:
				d.begin_edit()  # an empty first step; history starts at the load
				doc = d
				_size_spin.value = doc.size_m
				_cell_spin.value = doc.cell_m
				_select(-1)
				_refresh()
				_status.text = "Loaded %s" % path
			else:
				_status.text = "; ".join(errs)
			return
	_status.text = "No draft named %s" % doc.name

## Writes <name>.map.json and <name>.png under game/data/maps (the export an agent builds from).
func _export() -> void:
	_validate()
	var out := export_to(doc, EXPORT_DIR)
	_status.text = "Exported %s" % out if out != "" else "Export failed"

static func export_to(d: MapDoc, dir: String) -> String:
	var json := ProjectSettings.globalize_path(dir + d.name + ".map.json")
	if d.save_file(json) != OK:
		return ""
	d.preview_image(4).save_png(ProjectSettings.globalize_path(dir + d.name + ".png"))
	return json

# ---------------------------------------------------------------------------- sample island

## The sample island: a home-size grassland with every layer and marker kind, painted with the
## same calls the tools make.
static func build_sample() -> MapDoc:
	var d := MapDoc.make(416.0, 4.0, "grassland", "sample")
	var n := d.cells
	var cx := 52.0
	var cz := 50.0
	for r in n:
		for c in n:
			var dx := (float(c) - cx) / 37.0
			var dz := (float(r) - cz) / 33.0
			var th := atan2(dz, dx)
			var edge := 1.0 + 0.08 * cos(2.0 * th + 0.6) + 0.06 * cos(3.0 * th + 1.9) + 0.05 * sin(5.0 * th)
			# A peninsula to the east, a cove on the south coast for the dock.
			edge += 0.14 * exp(-pow((th - 0.15) / 0.22, 2.0)) - 0.12 * exp(-pow((th - 1.62) / 0.16, 2.0))
			if sqrt(dx * dx + dz * dz) < edge:
				d.set_cell("land", c, r, 1)
	d.fill("zone", 52, 50, 1)  # meadow everywhere first
	d.paint("zone", 30, 36, 11.0, 2)  # forest to the north-west
	d.paint("zone", 24, 50, 7.0, 2)
	d.paint("zone", 70, 66, 9.0, 3)  # savanna to the south-east
	d.paint("zone", 68, 30, 10.0, 8)  # rocky hills to the north-east
	d.paint("height", 68, 30, 9.0, 1)
	d.paint("height", 70, 27, 4.0, 2)
	# Beach on the coast cells.
	for r in n:
		for c in n:
			if d.is_land(c, r) and (not d.is_land(c + 1, r) or not d.is_land(c - 1, r) or not d.is_land(c, r + 1) or not d.is_land(c, r - 1)):
				d.paint("zone", c, r, 1.0, 7)
	# A river from the hills to the west coast, wetland along it, a lake in the low ground.
	var river := [Vector2(64, 34), Vector2(56, 40), Vector2(46, 42), Vector2(36, 46), Vector2(26, 44), Vector2(12, 46), Vector2(2, 46)]
	for pass_i in 2:
		for i in river.size() - 1:
			var steps := int((river[i] as Vector2).distance_to(river[i + 1]) * 2.0) + 1
			for t in steps + 1:
				var p: Vector2 = (river[i] as Vector2).lerp(river[i + 1], float(t) / float(steps))
				if pass_i == 0:
					d.paint("zone", roundi(p.x), roundi(p.y), 3.0, 6)  # wetland banks
				else:
					d.paint("water", roundi(p.x), roundi(p.y), 0.8, 1)
	d.paint("zone", 40, 62, 5.0, 6)
	d.paint("water", 40, 62, 3.0, 2)
	# The dock at the head of the south cove; the town just inland, a road between them.
	var dock_c := 52
	var dock_r := 50
	while d.is_land(dock_c, dock_r + 1):
		dock_r += 1
	var dock := d.cell_centre(dock_c, dock_r)
	var town := d.cell_centre(52, dock_r - 10)
	for r in range(dock_r - 10, dock_r + 1):
		d.paint("road", 52, r, 0.0, 1)
	for c in range(52, 62):
		d.paint("road", c, dock_r - 10, 0.0, 1)
	d.add_marker("dock", dock.x, dock.y, {"name": "South Cove"})
	d.add_marker("town", town.x, town.y, {"name": "Landing"})
	d.add_marker("guild", town.x + 14.0, town.y - 6.0, {"name": "Adventurer's Guild"})
	d.add_marker("camp", town.x - 22.0, town.y + 6.0, {"name": "Camp"})
	d.add_marker("claim_free", town.x, town.y, {"name": "Town", "radius_m": 36.0})
	var peak := d.cell_centre(70, 27)
	d.add_marker("landmark", peak.x, peak.y, {"name": "Lookout Peak"})
	var lake := d.cell_centre(40, 62)
	d.add_marker("landmark", lake.x + 16.0, lake.y, {"name": "Reed Pond"})
	d.add_marker("resource", d.cell_centre(30, 36).x, d.cell_centre(30, 36).y, {"resource": "trees", "count": 14, "radius_m": 30.0})
	d.add_marker("resource", d.cell_centre(66, 33).x, d.cell_centre(66, 33).y, {"resource": "rock", "count": 8, "radius_m": 20.0})
	d.add_marker("resource", d.cell_centre(48, 56).x, d.cell_centre(48, 56).y, {"resource": "fibre", "count": 10, "radius_m": 18.0})
	d.add_marker("resource", d.cell_centre(36, 58).x, d.cell_centre(36, 58).y, {"resource": "berries", "count": 6, "radius_m": 14.0})
	d.add_marker("resource", d.cell_centre(40, 66).x, d.cell_centre(40, 66).y, {"resource": "clay", "count": 3, "radius_m": 8.0})
	d.add_marker("spawn", d.cell_centre(44, 52).x, d.cell_centre(44, 52).y, {"species": "compsognathus", "level": 1, "count": 2, "radius_m": 16.0})
	d.add_marker("spawn", d.cell_centre(72, 64).x, d.cell_centre(72, 64).y, {"species": "zebraceratops", "level": 3, "count": 3, "radius_m": 24.0})
	d.add_marker("spawn", d.cell_centre(62, 26).x, d.cell_centre(62, 26).y, {"species": "gallimimus", "level": 5, "count": 2, "radius_m": 18.0})
	return d

func _make_sample() -> void:
	var d := build_sample()
	var out := export_to(d, EXPORT_DIR)
	for i in d.issues():
		print("[map_lab] %s %s %s" % [i["level"], i["code"], i["msg"]])
	print("[map_lab] sample -> %s (errors=%d)" % [out, d.errors().size()])
	get_tree().quit(0 if out != "" and d.errors().is_empty() else 1)

# ---------------------------------------------------------------------------- canvas

## The map view: the doc's colour image scaled to fit (nearest), grid lines, markers with radius
## rings. Mouse input (a touch arrives as mouse through emulate_mouse_from_touch) paints.
class MapCanvas extends Control:
	var lab
	var tex: ImageTexture

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func set_doc_image(img: Image) -> void:
		if tex != null and tex.get_size() == Vector2(img.get_size()):
			tex.update(img)
		else:
			tex = ImageTexture.create_from_image(img)
		queue_redraw()

	func map_rect() -> Rect2:
		var s := minf(size.x, size.y)
		return Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))

	func to_world(p: Vector2) -> Vector2:
		var r := map_rect()
		var d: MapDoc = lab.doc
		return (p - r.position) / r.size.x * d.size_m - Vector2.ONE * d.size_m * 0.5

	func to_screen(w: Vector2) -> Vector2:
		var r := map_rect()
		var d: MapDoc = lab.doc
		return r.position + (w + Vector2.ONE * d.size_m * 0.5) / d.size_m * r.size.x

	func _draw() -> void:
		var r := map_rect()
		draw_rect(r.grow(2), Color(0, 0, 0, 0.6))
		if tex:
			draw_texture_rect(tex, r, false)
		var d: MapDoc = lab.doc
		var px := r.size.x / float(d.cells)
		if lab.show.get("grid", false):
			for i in d.cells + 1:
				var a := Color(0, 0, 0, 0.35 if i % 10 == 0 else 0.12)
				draw_line(r.position + Vector2(i * px, 0), r.position + Vector2(i * px, r.size.y), a)
				draw_line(r.position + Vector2(0, i * px), r.position + Vector2(r.size.x, i * px), a)
		if not lab.show.get("markers", true):
			return
		var font := get_theme_default_font()
		var mpp := r.size.x / d.size_m
		for m in d.markers:
			var p := to_screen(Vector2(float(m["x"]), float(m["z"])))
			var col: Color = MapDoc.MARKER_COLORS.get(str(m["kind"]), Color.WHITE)
			var props: Dictionary = m["props"]
			if props.has("radius_m"):
				draw_arc(p, float(props["radius_m"]) * mpp, 0.0, TAU, 48, Color(col, 0.85), 2.0)
			if int(m["id"]) == lab.selected:
				draw_circle(p, 17.0, UiTokens.GOLD)
			draw_circle(p, 12.0, Color.BLACK)
			draw_circle(p, 10.0, col)
			var letter := str(m["kind"]).substr(0, 1).to_upper()
			draw_string(font, p + Vector2(-5, 6), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
			var label := str(props.get("name", ""))
			if label == "":
				label = str(props.get("species", props.get("resource", "")))
				if props.has("level"):
					label += " L%d" % int(props["level"])
				if props.has("count"):
					label += " x%d" % int(props["count"])
			if label != "":
				draw_string_outline(font, p + Vector2(16, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
				draw_string(font, p + Vector2(16, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and map_rect().has_point(mb.position):
				lab.press(to_world(mb.position))
			elif not mb.pressed:
				lab.release()
			accept_event()
			return
		var mm := e as InputEventMouseMotion
		if mm != null and mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			lab.drag(to_world(mm.position))
			accept_event()
