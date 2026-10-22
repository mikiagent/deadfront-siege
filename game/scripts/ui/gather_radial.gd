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
var _label_left: Array[bool] = []  ## the side each label was solved on (a flip glides it alone)
var _inventory: Inventory
var _open: bool = false
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}
## Harvest picks keep the menu open: the chosen hex stays lit and its outline fills once
## per unit gathered (progress 0..1 from the player's gather cycle), then resets.
var active_index: int = -1
var _progress: float = 0.0
var _ring3d: MeshInstance3D  # selection hexagon on the ground, depth-tested so the plant stands on it
## Option label boxes as last drawn (the capture lab checks them against the nameplate).
var label_rects: Array[Rect2] = []
## The name + level backing as last drawn (the capture lab checks it against the HUD and the source).
var title_box: Rect2
var _hold := RadialHold.new()  # the layout solved on open, held against the node while the camera moves
var _offs_prev: Array[Vector2] = []  ## each part's offset from the node as drawn last frame (hard step cap)
## How many times the held layout had to be solved again (the lab gates the glide instead of a jump).
var solves := 0

const HEX := 64.0
const RING_R := 1.15  # selection hexagon radius on the ground, m
const RING_W := 0.07

func _ready() -> void:
	# Inside the tree set_anchors_preset keeps the current (empty) rect; reset the offsets too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 1  # after the camera's follow (priority 0): the hexes trailed the plant by a frame
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
		_labels.append({"text": "%s  %s" % [_display_name(item_id), LevelDisplay.label(level)], "reason": reason})
	_open = true
	visible = true
	_show_ring3d()
	_offs_prev.clear()
	_solve()  # a new menu: placed at once, then held against its node
	_paint(_anchor())
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
	var r := RING_R
	var w := RING_W
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
	_hold.reset()
	_offs_prev.clear()
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
			_labels[i] = {"text": "%s  %s" % [_display_name(item_id), LevelDisplay.label(level)], "reason": reason}
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
	var anchor := _anchor()
	var view := get_viewport_rect().size
	if not _hold.follow(anchor, view, UiTokens.safe_insets(get_viewport()), UiTokens.hud_reserved(view)):
		_solve()
	_hold.advance()
	_hold.clamp_offsets(_offs_prev, anchor, RadialHold.MAX_STEP)
	_paint(anchor)
	_check_label_sides(anchor, view)
	queue_redraw()

func _anchor() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null or node == null:
		return Vector2.ZERO
	return cam.unproject_position(node.global_position + Vector3(0, anchor_height * 0.45, 0))

## Solve the layout around the node: the title box, the hexes and each label's box. A first solve places
## them; a later one is glided to (RadialHold.advance), so the ring never jumps when it has to give way.
func _solve() -> void:
	solves += 1
	var anchor := _anchor()
	var view := get_viewport_rect().size
	var tf := ThemeDB.fallback_font
	var ns := UiTokens.body(view)
	var tw := tf.get_string_size(UiTokens.ellipsis(tf, _node_name(), 168.0, ns), HORIZONTAL_ALIGNMENT_CENTER, -1, ns).x + 20.0
	var avoid := UiTokens.hud_reserved(view)
	var plate := nameplate()
	if plate.has_area():
		avoid.append(plate)
	var src := source_rect()
	var box := title_spot(src, Vector2(tw, ns + 26), view, avoid)
	# Where the ring could not turn clear of the title (a crowded edge), slide the title to the first
	# spot beside the hexes that is clear of all of them (one shift per hex moved it onto the other).
	var keep_off: Array[Rect2] = UiTokens.hud_reserved(view)
	keep_off.append_array([nameplate(), src])
	for x in _title_spots(box, view):
		var spot := Rect2(Vector2(clampf(x, 8.0, maxf(8.0, view.x - box.size.x - 8.0)), box.position.y), box.size)
		var clear := true
		for k in keep_off:
			clear = clear and not spot.intersects(k)
		if clear:
			box = spot
			break
	# The ring turns to clear the plant and its title as well as the HUD.
	avoid.append(src)
	avoid.append(box)
	var lw := 0.0
	for l in _labels:
		lw = maxf(lw, tf.get_string_size(UiTokens.ellipsis(tf, str(l["text"]), 148.0, ns), HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x)
	var spots := ContextRadial.hex_positions(anchor, _buttons.size(), view, UiTokens.safe_insets(get_viewport()), HEX, tw, avoid, lw)
	var labels: Array[Rect2] = []
	for i in spots.size():
		var text: String = UiTokens.ellipsis(tf, str(_labels[i]["text"]), 148.0, ns)
		var w := tf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		var blockers: Array[Rect2] = [box, plate]
		blockers.append_array(UiTokens.hud_reserved(view))
		for j in spots.size():
			if j != i:
				blockers.append(Rect2(spots[j], Vector2(HEX, HEX)))
		labels.append(pick_label_rect(ContextRadial.label_on_left(spots[i], HEX, view, anchor), Rect2(spots[i], Vector2(HEX, HEX)), w, view, blockers, [src]))
	_hold.solve(box, spots, labels)
	_hold.anchored(anchor)

## A label whose hex has moved to its other side glides across on its own: the hexes do not re-solve.
func _check_label_sides(anchor: Vector2, view: Vector2) -> void:
	if not _hold.held or _hold.gliding():
		return
	var font := ThemeDB.fallback_font
	var ts := UiTokens.body(view)
	var src := source_rect()
	for i in mini(_buttons.size(), _label_left.size()):
		var hex := Rect2(_hold.drawn(1 + i).position, Vector2(HEX, HEX))
		var left := ContextRadial.label_on_left(hex.position, HEX, view, anchor)
		if left == _label_left[i]:
			continue
		var text: String = UiTokens.ellipsis(font, str(_labels[i]["text"]), 148.0, ts)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var blockers: Array[Rect2] = [title_box, nameplate()]
		blockers.append_array(UiTokens.hud_reserved(view))
		for j in _buttons.size():
			if j != i:
				blockers.append(Rect2(_hold.drawn(1 + j).position, Vector2(HEX, HEX)))
		var r := pick_label_rect(left, hex, w, view, blockers, [src])
		_label_left[i] = left
		_hold.set_label_goal(i, r)

## The x positions the title may slide to: where it is, then just clear of each hex.
func _title_spots(box: Rect2, _view: Vector2) -> Array[float]:
	var xs: Array[float] = [box.position.x]
	for i in mini(_buttons.size(), _hold.drawn_count() - 1):
		var b := _hold.drawn(1 + i)
		xs.append_array([b.position.x - box.size.x - 12.0, b.position.x + b.size.x + 12.0])
	return xs

## Take the drawn (gliding) places for the title, hexes and labels; the lab and the tests read these.
func _paint(anchor: Vector2) -> void:
	if _hold.drawn_count() < 1 + _buttons.size() + _labels.size():
		return
	_offs_prev.clear()
	for i in _hold.drawn_count():
		_offs_prev.append(_hold.drawn(i).position - anchor)
	title_box = _hold.drawn(0)
	for i in _buttons.size():
		_buttons[i].position = _hold.drawn(1 + i).position
	label_rects.clear()
	for i in _labels.size():
		label_rects.append(_hold.drawn(1 + _buttons.size() + i))

func _draw() -> void:
	if not _open or node == null or label_rects.size() < _buttons.size():
		return
	var font := ThemeDB.fallback_font
	var view := get_viewport_rect().size
	var name := UiTokens.ellipsis(font, _node_name(), 168.0, UiTokens.body(view))
	var ns := UiTokens.body(view)
	var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, ns).x
	var name_pos := title_box.position + Vector2(10.0, float(ns))
	var lv := LevelDisplay.label(level)
	var lw := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, UiTokens.meta(view)).x
	# One backing for both lines: the level alone sat on the bright bush and did not read.
	draw_rect(title_box, UiTokens.INK)
	draw_string(font, name_pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color.WHITE)
	draw_string(font, Vector2(name_pos.x + nw * 0.5 - lw * 0.5, name_pos.y + 18.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), UiTokens.TEAL)
	for i in _buttons.size():
		var text: String = UiTokens.ellipsis(font, str(_labels[i]["text"]), 148.0, UiTokens.body(view))
		var reason: String = str(_labels[i]["reason"])
		var ts := UiTokens.body(view)
		var pos := label_rects[i].position + Vector2(4.0, 14.0)
		draw_rect(label_rects[i], UiTokens.INK)
		draw_string(font, pos + Vector2(2, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.95, 0.95, 0.95) if reason == "" else Color(0.75, 0.75, 0.75))
		if reason != "":
			var short := UiTokens.ellipsis(font, reason, 148.0, UiTokens.meta(view))
			draw_string(font, pos + Vector2(2, 24), short, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), UiTokens.DANGER)

func _node_name() -> String:
	return title

## Where the name + level box goes: under the source's selection ring, or above the plant where the
## bottom edge, the HUD or the nameplate is in the way (in the middle of the ring it hid the plant
## and the ring on a phone).
static func title_spot(src: Rect2, size: Vector2, view: Vector2, blockers: Array[Rect2]) -> Rect2:
	var x := clampf(src.get_center().x - size.x * 0.5, 8.0, maxf(8.0, view.x - size.x - 8.0))
	var below := Rect2(Vector2(x, src.end.y + 4.0), size)
	var ok := below.end.y <= view.y - 24.0  # ASSUMPTION: 24 px keeps the box off the bottom XP line
	for b in blockers:
		ok = ok and not below.intersects(b)
	return below if ok else Rect2(Vector2(x, src.position.y - 4.0 - size.y), size)

## The gathered source on screen: the hull of its selection ring and its top. The title, labels and
## hexes keep off it (the lab checks this hull); source_rect() is its box, for the avoid lists.
func source_hull() -> PackedVector2Array:
	var cam := get_viewport().get_camera_3d()
	if cam == null or node == null:
		return PackedVector2Array()
	var c := node.global_position
	var pts := PackedVector2Array([cam.unproject_position(c + Vector3.UP * anchor_height)])
	for i in 6:
		var a := deg_to_rad(60.0 * float(i))
		pts.append(cam.unproject_position(c + Vector3(cos(a), 0.0, sin(a)) * (RING_R + RING_W)))
	return Geometry2D.convex_hull(pts)

func source_rect() -> Rect2:
	var hull := source_hull()
	if hull.is_empty():
		return Rect2(_anchor(), Vector2.ZERO)
	var out := Rect2(hull[0], Vector2.ZERO)
	for p in hull:
		out = out.expand(p)
	return out

## The player's nameplate on screen (empty without a camera or player); hexes and labels keep off it.
func nameplate() -> Rect2:
	var cam := get_viewport().get_camera_3d()
	var who := PlayerRegistry.local()
	if cam == null or who == null:
		return Rect2()
	return HudLayout.nameplate_rect(cam, who, ThemeDB.fallback_font).grow(4.0)

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

## Where a hex's label is drawn on one side of it, after the same clamp the draw uses.
static func label_rect(hex: Rect2, label_w: float, left: bool, view_w: float) -> Rect2:
	var x := hex.position.x - label_w - 14.0 if left else hex.end.x + 8.0
	x = clampf(x, 8.0, maxf(8.0, view_w - label_w - 16.0))
	return Rect2(Vector2(x - 4.0, hex.position.y + hex.size.y * 0.5 - 14.0), Vector2(label_w + 12.0, 26.0))

## Where a hex's label goes. ContextRadial.label_on_left only looks at where the hex is, not how wide its
## label is, so a label that could not fit beside its hex was clamped back over it and lost its first
## letters. Try the preferred side, the other side, then above and below the hex (centred, then slid
## along it to clear each blocker), and keep the first spot that is inside the screen and clear of this hex and every blocker (other hexes, the title box, HUD).
## If nothing is clear, take the on-screen spot that covers the least blocker area (the preferred side
## on a tie): keeping the preferred side put a label on HANDS when the other side was nearly clear.
## `soft` blockers (the plant) count a tenth: a label may lie over leaves before it covers text.
static func pick_label_rect(prefer_left: bool, hex: Rect2, label_w: float, view: Vector2, blockers: Array = [], soft: Array = []) -> Rect2:
	var w := label_w + 12.0
	var cx := clampf(hex.get_center().x - w * 0.5, 8.0, maxf(8.0, view.x - w - 8.0))
	var candidates: Array[Rect2] = [
		label_rect(hex, label_w, prefer_left, view.x),
		label_rect(hex, label_w, not prefer_left, view.x),
		Rect2(Vector2(cx, hex.position.y - 30.0), Vector2(w, 26.0)),
		Rect2(Vector2(cx, hex.end.y + 4.0), Vector2(w, 26.0)),
	]
	# Above or below, the label may slide along its hex to just clear a blocker's edge (at 844x390
	# "Berries" above its hex touched the gather title by 2 px).
	var lo := minf(hex.position.x, hex.end.x - w)
	var hi := maxf(hex.position.x, hex.end.x - w)
	for blocker in blockers + soft:
		for x in [(blocker as Rect2).end.x + 2.0, (blocker as Rect2).position.x - w - 2.0]:
			for y in [hex.position.y - 30.0, hex.end.y + 4.0]:
				candidates.append(Rect2(Vector2(clampf(x, lo, hi), y), Vector2(w, 26.0)))
	var best := candidates[0]
	var best_cover := INF
	for rect in candidates:
		if rect.position.y < 0.0 or rect.end.y > view.y or rect.position.x < 0.0 or rect.end.x > view.x:
			continue
		if rect.intersects(hex):
			continue
		var cover := 0.0
		for blocker in blockers:
			cover += rect.intersection(blocker as Rect2).get_area()
		for blocker in soft:
			cover += rect.intersection(blocker as Rect2).get_area() * 0.1  # ASSUMPTION: leaves weigh a tenth of text
		if cover <= 0.0:
			return rect
		if cover < best_cover:
			best_cover = cover
			best = rect
	return best
