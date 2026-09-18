class_name GatherRadial
extends Control
## Tap a node → a hexagonal selection outline on its tile with name + level, and a fan of
## hex option buttons (icon, seconds on top, count below, label to the right). Blocked
## options carry a red badge and the reason. Reference: docs/reference/durango-gather-reference.webp

signal picked(anchor: Node3D, index: int)
signal closed

var node: Node3D
var options: Array = []
var title: String = ""
var level: int = 1
var anchor_height: float = 1.0
var _buttons: Array[HexButton] = []
var _labels: Array[Dictionary] = []
var _inventory: Inventory
var _open: bool = false
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}

const HEX := 76.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_load_icons()

func is_open() -> bool:
	return _open

func open(p_node: HarvestNode, p_options: Array, inv: Inventory) -> void:
	var fam := p_node.family if p_node.family != "" else str(p_node.node_id)
	open_options(p_node, fam.replace("_", " ").capitalize(), int(p_node.yield_attributes.get("level", 1)), p_node.top_of_node(), p_options, inv)

## Generic: any Node3D anchor (corpse, station) with option dicts
## {item, min, max, tool, seconds, [blocked_reason]}.
func open_options(p_anchor: Node3D, p_title: String, p_level: int, p_height: float, p_options: Array, inv: Inventory) -> void:
	close()
	node = p_anchor
	title = p_title
	level = p_level
	anchor_height = p_height
	options = p_options
	_inventory = inv
	for i in options.size():
		var o: Dictionary = options[i]
		var b := HexButton.new(HEX)
		var item_id := StringName(str(o.get("item", "")))
		b.icon = _icon_for(item_id)
		if b.icon == null:
			b.glyph = str(_display_name(item_id)).left(1)
		b.top_text = "%.1fs" % float(o.get("seconds", 1.8))
		var cmin := int(o.get("min", 1))
		var cmax := int(o.get("max", 1))
		b.bottom_text = str(cmax) if cmin == cmax else "%d-%d" % [cmin, cmax]
		var tool := StringName(str(o.get("tool", "none")))
		var blocked := tool != &"none" and tool != &"" and inv != null and not inv.has_tool_class(tool)
		var reason := ("needs %s" % tool) if blocked else str(o.get("blocked_reason", ""))
		blocked = blocked or reason != ""
		b.disabled = blocked
		b.badge = "⊘" if blocked else ""
		b.pressed.connect(_on_pick.bind(i))
		add_child(b)
		_buttons.append(b)
		_labels.append({"text": "%s Lv. %d" % [_display_name(item_id), level], "reason": reason})
	_open = true
	visible = true
	_layout()
	queue_redraw()

func close() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_labels.clear()
	if _open:
		_open = false
		closed.emit()
	visible = false
	node = null

func _on_pick(i: int) -> void:
	var n := node
	close()
	picked.emit(n, i)

func _process(_delta: float) -> void:
	if not _open:
		return
	if node == null or not is_instance_valid(node):
		close()
		return
	_layout()
	queue_redraw()

func _anchor() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null or node == null:
		return Vector2.ZERO
	return cam.unproject_position(node.global_position + Vector3(0, anchor_height * 0.45, 0))

func _layout() -> void:
	var base := _anchor()
	# Fan to the right, stacked diagonally like the reference (right-hand thumb reach).
	for i in _buttons.size():
		var off := Vector2(95.0 + float(i % 2) * 46.0, -80.0 + float(i) * 82.0)
		var b := _buttons[i]
		b.position = base + off - b.size * 0.5

func _draw() -> void:
	if not _open or node == null:
		return
	var cam := get_viewport().get_camera_3d()
	var base := _anchor()
	var font := ThemeDB.fallback_font
	# Selection hexagon around the node's tile (screen-space, squashed for the iso view).
	var ppm := 40.0
	if cam and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		ppm = get_viewport_rect().size.y / maxf(1.0, cam.size)
	var r := 1.35 * ppm
	var ground := cam.unproject_position(node.global_position) if cam else base
	var pts := PackedVector2Array()
	for i in 7:
		var a := deg_to_rad(60.0 * float(i))
		pts.append(ground + Vector2(cos(a) * r, sin(a) * r * 0.55))
	draw_polyline(pts, Color(1, 1, 1, 0.55), 2.0, true)
	var name := _node_name()
	var ns := 18
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, ns).x
	draw_string(font, Vector2(ground.x - nw * 0.5, ground.y + r * 0.55 + 22.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color.WHITE)
	var lv := "Lv. %d" % level
	var lw := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
	draw_string(font, Vector2(ground.x - lw * 0.5, ground.y + r * 0.55 + 42.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.9, 0.45))
	# Labels to the right of each hex, on a dark pill.
	for i in _buttons.size():
		var b := _buttons[i]
		var text: String = _labels[i]["text"]
		var reason: String = _labels[i]["reason"]
		var ts := 17
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var pos := b.position + Vector2(b.size.x + 6.0, b.size.y * 0.5)
		draw_rect(Rect2(pos + Vector2(-4, -14), Vector2(tw + 12, 26)), Color(0.05, 0.06, 0.07, 0.85))
		draw_string(font, pos + Vector2(2, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.95, 0.95, 0.95) if reason == "" else Color(0.75, 0.75, 0.75))
		if reason != "":
			draw_string(font, pos + Vector2(2, 26), reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.45, 0.4))

func _node_name() -> String:
	return title

func _display_name(id: StringName) -> String:
	var def := Data.item(id)
	if def and def.display_name != "":
		return def.display_name
	return str(id).replace("_", " ").capitalize()

func _load_icons() -> void:
	if not FileAccess.file_exists("res://data/icons_manifest.json"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/icons_manifest.json"))
	if parsed is Dictionary:
		_icons = parsed

func _icon_for(id: StringName) -> Texture2D:
	var key := str(id)
	if _icon_cache.has(key):
		return _icon_cache[key]
	var icons: Dictionary = _icons.get("icons", {})
	var aliases: Dictionary = _icons.get("aliases", {})
	var path := str(icons.get(key, ""))
	if path == "" and aliases.has(key):
		path = str(icons.get(str(aliases[key]), ""))
	if path == "":
		var def := Data.item(id)
		if def:
			var fb: Dictionary = _icons.get("category_fallback", {})
			for cat in def.categories:
				if fb.has(str(cat)):
					path = str(icons.get(str(fb[str(cat)]), ""))
					break
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	_icon_cache[key] = tex
	return tex
