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
## Harvest picks keep the menu open: the chosen hex stays lit and its outline fills once
## per unit gathered (progress 0..1 from the player's gather cycle), then resets.
var active_index: int = -1
var _progress: float = 0.0
var _ring3d: MeshInstance3D  # selection hexagon on the ground, depth-tested so the plant stands on it

const HEX := 64.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_load_icons()

func is_open() -> bool:
	return _open

## Any press that is not on one of the hexes closes the menu (Durango: tap away to dismiss).
func _input(event: InputEvent) -> void:
	if not _open:
		return
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	else:
		return
	for b in _buttons:
		if b.get_global_rect().grow(6.0).has_point(pos):
			return
	close()

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
		b.color_icon = b.icon != null
		if b.icon == null:
			b.glyph = str(_display_name(item_id)).left(1)
		b.top_text = "%.1fs" % float(o.get("seconds", 1.8))
		b.bottom_text = str(int(o["left"])) if o.has("left") else ""  # units left on this yield
		var tool := StringName(str(o.get("tool", "none")))
		var blocked := tool != &"none" and tool != &"" and inv != null and not inv.has_tool_class(tool)
		var reason := ("needs %s" % tool) if blocked else str(o.get("blocked_reason", ""))
		blocked = blocked or reason != ""
		b.disabled = blocked
		b.badge = "⊘" if blocked else ""
		b.pressed.connect(_on_pick.bind(i))
		add_child(b)
		_buttons.append(b)
		_labels.append({"text": "%s  Lv. %d" % [_display_name(item_id), level], "reason": reason})
	_open = true
	visible = true
	_show_ring3d()
	_layout()
	queue_redraw()

## Hexagon flat on the terrain under the node (1.15 m), rebuilt on open; the mesh is depth-tested,
## so the trunk/bush occludes the far edge and the ring reads as sitting on the ground.
func _show_ring3d() -> void:
	if node == null:
		return
	if _ring3d == null:
		_ring3d = MeshInstance3D.new()
		_ring3d.name = "SelectHex3D"
		_ring3d.top_level = true
		_ring3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.75)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring3d.material_override = m
		_ring3d.mesh = ImmediateMesh.new()
		var host: Node = get_tree().current_scene
		if host:
			host.add_child(_ring3d)
		else:
			add_child(_ring3d)
	var im := _ring3d.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := node.global_position
	var rt := World.runtime if World else null
	var has_surf := rt != null and rt.has_method("surface_y")
	var r := 1.15
	var w := 0.07
	for i in 6:
		var a0 := deg_to_rad(60.0 * float(i))
		var a1 := deg_to_rad(60.0 * float(i + 1))
		var quad: Array[Vector3] = []
		for pair in [[a0, r - w], [a0, r + w], [a1, r + w], [a1, r - w]]:
			var p := c + Vector3(cos(pair[0]) * pair[1], 0.0, sin(pair[0]) * pair[1])
			p.y = (rt.surface_y(p.x, p.z) if has_surf else c.y) + 0.05
			quad.append(p)
		im.surface_add_vertex(quad[0])
		im.surface_add_vertex(quad[1])
		im.surface_add_vertex(quad[2])
		im.surface_add_vertex(quad[0])
		im.surface_add_vertex(quad[2])
		im.surface_add_vertex(quad[3])
	im.surface_end()
	_ring3d.global_transform = Transform3D.IDENTITY
	_ring3d.visible = true

func close() -> void:
	if _ring3d:
		_ring3d.visible = false
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_labels.clear()
	active_index = -1
	_progress = 0.0
	if _open:
		_open = false
		closed.emit()
	visible = false
	node = null

func _on_pick(i: int) -> void:
	var n := node
	if n is HarvestNode:
		active_index = i
		_progress = 0.0
		for j in _buttons.size():
			_buttons[j].selected = j == i
			_buttons[j].queue_redraw()
		picked.emit(n, i)
		queue_redraw()
		return
	close()
	picked.emit(n, i)

## Unit progress for the active hex's outline (0 resets after each unit lands in the bag).
## After each unit lands: re-read the node's pools so counts, labels and blocked badges update.
func refresh() -> void:
	if not _open or not (node is HarvestNode):
		return
	var opts := (node as HarvestNode).options()
	for i in mini(opts.size(), _buttons.size()):
		var o: Dictionary = opts[i]
		var b := _buttons[i]
		b.bottom_text = str(int(o["left"])) if o.has("left") else ""
		var reason := str(o.get("blocked_reason", ""))
		var tool := StringName(str(o.get("tool", "none")))
		if reason == "" and tool != &"none" and tool != &"" and _inventory != null and not _inventory.has_tool_class(tool):
			reason = "needs %s" % tool
		b.disabled = reason != ""
		b.badge = "⊘" if reason != "" else ""
		b.queue_redraw()
		if i < _labels.size():
			var item_id := StringName(str(o.get("item", "")))
			_labels[i] = {"text": "%s  Lv. %d" % [_display_name(item_id), level], "reason": reason}
	queue_redraw()

func set_progress(frac: float) -> void:
	_progress = clampf(frac, 0.0, 1.0)
	queue_redraw()

func active_node() -> Node3D:
	return node if _open and active_index >= 0 else null

## Partial hexagon outline just outside a hex button, clockwise from its top vertex.
static func _hex_sweep(c: Vector2, r: float, frac: float) -> PackedVector2Array:
	var hex := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * float(i) - 90.0)
		hex.append(c + Vector2(cos(a), sin(a)) * r)
	var out := PackedVector2Array()
	var total := clampf(frac, 0.0, 1.0) * 6.0
	out.append(hex[0])
	for i in 6:
		var a := hex[i]
		var b := hex[(i + 1) % 6]
		if total >= float(i + 1):
			out.append(b)
		else:
			out.append(a.lerp(b, total - float(i)))
			break
	return out

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
	var view := get_viewport_rect().size
	var spots := ContextRadial.hex_positions(base, _buttons.size(), view, UiTokens.safe_insets(get_viewport()), HEX)
	for i in _buttons.size():
		if i < spots.size():
			_buttons[i].position = spots[i]

func _draw() -> void:
	if not _open or node == null:
		return
	var cam := get_viewport().get_camera_3d()
	var base := _anchor()
	var font := ThemeDB.fallback_font
	# The selection hexagon itself is a 3D mesh on the terrain (_show_ring3d); the name and level
	# sit under it in screen space.
	var ppm := 40.0
	if cam and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		ppm = get_viewport_rect().size.y / maxf(1.0, cam.size)
	var r := 1.35 * ppm
	var ground := cam.unproject_position(node.global_position) if cam else base
	var view := get_viewport_rect().size
	var name := UiTokens.ellipsis(font, _node_name(), 168.0, UiTokens.body(view))
	var ns := UiTokens.body(view)
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, ns).x
	var name_pos := Vector2(ground.x - nw * 0.5, ground.y + minf(r, 72.0) * 0.35 + 18.0)
	draw_rect(Rect2(name_pos + Vector2(-10, -ns), Vector2(nw + 20, ns + 8)), UiTokens.INK)
	draw_string(font, name_pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color.WHITE)
	var lv := "Lv. %d" % level
	var lw := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, UiTokens.meta(view)).x
	draw_string(font, Vector2(ground.x - lw * 0.5, name_pos.y + 18.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), UiTokens.TEAL)
	for i in _buttons.size():
		var b := _buttons[i]
		var text: String = UiTokens.ellipsis(font, str(_labels[i]["text"]), 148.0, UiTokens.body(view))
		var reason: String = str(_labels[i]["reason"])
		var ts := UiTokens.body(view)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var left := ContextRadial.label_on_left(b.position, b.size.x, view)
		var pos := b.position + (Vector2(-tw - 14.0, b.size.y * 0.5) if left else Vector2(b.size.x + 8.0, b.size.y * 0.5))
		pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - tw - 16.0))
		draw_rect(Rect2(pos + Vector2(-4, -14), Vector2(tw + 12, 26)), UiTokens.INK)
		draw_string(font, pos + Vector2(2, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.95, 0.95, 0.95) if reason == "" else Color(0.75, 0.75, 0.75))
		if reason != "":
			var short := UiTokens.ellipsis(font, reason, 148.0, UiTokens.meta(view))
			draw_string(font, pos + Vector2(2, 24), short, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), UiTokens.DANGER)
	# Gather progress: a thick outline sweeping around the picked hex, once per unit.
	if active_index >= 0 and active_index < _buttons.size():
		var ab := _buttons[active_index]
		var hc := ab.position + ab.size * 0.5
		var hr := minf(ab.size.x, ab.size.y) * 0.5 + 4.0
		var track := _hex_sweep(hc, hr, 1.0)
		track.append(track[0])
		draw_polyline(track, Color(0.05, 0.05, 0.05, 0.6), 6.0, true)
		if _progress > 0.002:
			draw_polyline(_hex_sweep(hc, hr, _progress), Color(1.0, 0.92, 0.5, 0.98), 6.0, true)

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
