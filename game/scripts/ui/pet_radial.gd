class_name PetRadial
extends Control
## Durango pet radial (spec 23, docs/reference/durango-pet-radial.webp): tapping your own pet opens a
## dark ring of segments around a see-through centre disc on the pet, which shows its name, species
## and a fullness arc. Each segment is a white action icon with its label outside the ring. Rows come
## from PlayerPets.entries(), which leaves absent features out (no inert segments).
## A segment fires on release inside the segment it was pressed in (a label counts as its segment).
## A tap anywhere else closes the ring and does nothing else; so do Esc and the pet going away.
## Walking does not close it (the station menu's nav_active close hid it while the survivor still walked).
## HUD hexes under the ring or its labels fade out while it is open: a landscape phone in a fight has no
## free spot for it (its labels sat on CHASE and FISTS), and a tap there only closes the ring.

signal action_chosen(pet: Node3D, action_id: StringName)

## Near-opaque: world labels under the ring (a bush's name) ghosted through at 0.9.
const FILL := Color(0.09, 0.085, 0.075, 0.96)
const FILL_HOT := Color(0.27, 0.25, 0.21, 0.95)
const SEAM := Color(0.78, 0.74, 0.66, 0.55)
const RIM := Color(0.0, 0.0, 0.0, 0.55)
const CENTRE_TINT := Color(0.0, 0.0, 0.0, 0.16)
const METER := Color(0.97, 0.78, 0.2)
const METER_TRACK := Color(0.0, 0.0, 0.0, 0.5)
## The arc spans the right side of the centre disc, as in the reference, and fills from the bottom.
const METER_FROM := 1.1345  # 65 degrees, below the right edge
const METER_TO := -1.1345
## Hit slop around the ring, px.
const SLOP := 8.0

var player: Player
var pet: Creature
var rows: Array = []
## Centre on screen, laid out each frame (the pet moves, the window resizes).
var centre := Vector2.ZERO
var r_in := 88.0
var r_out := 166.0
var label_rects: Array[Rect2] = []
## Highlighted segment (hover, press or controller), -1 = none.
var hot := -1
## Segment the current press began on: -1 = off the segments, NO_PRESS = no press since the ring
## opened (the release of the tap that opened it must not close it).
const NO_PRESS := -2
var _press := NO_PRESS
var _icons: Array[Texture2D] = []
var _faded: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func show_for(c: Creature, entries: Array) -> void:
	pet = c
	rows = entries.duplicate()
	_icons.clear()
	for row in rows:
		_icons.append(UiIcons.icon(StringName(str((row as Dictionary).get("icon", "")))))
	_press = NO_PRESS
	hot = 0 if UiTokens.wants_focus() else -1
	visible = true
	_layout()
	queue_redraw()

func hide_menu() -> void:
	visible = false
	pet = null
	rows.clear()
	_press = NO_PRESS
	hot = -1
	_fade_covered()

func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for row in rows:
		out.append(StringName(str((row as Dictionary).get("id", ""))))
	return out

func choose(i: int) -> void:
	if i < 0 or i >= rows.size():
		return
	var c := pet
	var aid := ids()[i]
	hide_menu()
	action_chosen.emit(c, aid)

## Segment i's angular centre (radians, screen space: 0 = right, positive = clockwise). Segment 0
## ends straight up, so with six it sits top left like the reference's Animals menu.
func segment_angle(i: int) -> float:
	var step := TAU / float(maxi(1, rows.size()))
	return -PI * 0.5 - step * 0.5 + step * float(i)

## Middle of segment i's band, on screen (tests and labs tap here).
func segment_center(i: int) -> Vector2:
	var a := segment_angle(i)
	return centre + Vector2(cos(a), sin(a)) * (r_in + r_out) * 0.5

## The ring's bounding box on screen (the HUD's world label pills keep out of it).
func ring_rect() -> Rect2:
	return Rect2(centre - Vector2.ONE * r_out, Vector2.ONE * r_out * 2.0)

## Segment under a screen point: its band (with slop) or its label; -1 = outside or the centre.
func segment_at(pos: Vector2) -> int:
	if rows.is_empty():
		return -1
	var d := pos - centre
	var r := d.length()
	if r >= r_in - SLOP * 0.5 and r <= r_out + SLOP:
		var step := TAU / float(rows.size())
		var rel := fposmod(atan2(d.y, d.x) - (-PI * 0.5 - step), TAU)
		return clampi(int(rel / step), 0, rows.size() - 1)
	for i in label_rects.size():
		if label_rects[i].grow(4.0).has_point(pos):
			return i
	return -1

func _process(_delta: float) -> void:
	if not visible:
		return
	if pet == null or not is_instance_valid(pet) or pet.health.dead \
			or (pet.pet_record != null and not pet.pet_record.summoned):
		hide_menu()
		return
	# A sheet opened over the world (bag, craft) takes over; the ring would sit on top of it.
	if player and ((player.ui and player.ui.visible) or (player.craft_ui and player.craft_ui.visible)):
		hide_menu()
		return
	_layout()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	var press := false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
		press = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
		press = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseMotion:
		var over := segment_at((event as InputEventMouseMotion).position)
		if over != hot and _press < 0:
			hot = over
			queue_redraw()
		return
	else:
		return
	accept_event()
	var i := segment_at(at)
	if press:
		_press = i
		hot = i
		queue_redraw()
		return
	var was := _press
	_press = NO_PRESS
	if was >= 0 and i == was:
		choose(i)
	elif was == -1:
		hide_menu()  # pressed and released off the segments: a tap outside closes, and only closes

## Keys and pads: Esc / B closes, Tab / Shift+Tab / d-pad pick a segment, Enter / A fires the picked
## (or hovered) one. Not the arrows or Space: movement is polled, so the arrows also walked her, and Space
## (roll) fired the segment the mouse rested on. Taken in _input so these keys do nothing else meanwhile.
func _input(event: InputEvent) -> void:
	if not visible or rows.is_empty() or not (event is InputEventKey or event is InputEventJoypadButton):
		return
	var pad := event is InputEventJoypadButton
	var key := event as InputEventKey
	if event.is_action_pressed("ui_cancel"):
		hide_menu()
	elif event.is_action_pressed("ui_focus_prev") or (pad and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"))):
		hot = posmod(hot - 1, rows.size())
	elif event.is_action_pressed("ui_focus_next") or (pad and (event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"))):
		hot = posmod(hot + 1, rows.size())
	elif hot >= 0 and ((pad and event.is_action_pressed("ui_accept")) \
			or (key and key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER])):
		choose(hot)
	else:
		return
	queue_redraw()
	get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- layout and drawing

func _layout() -> void:
	var view := get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	var compact := UiTokens.is_compact(view)
	# Reference: outer radius ~19 % of the screen height, the hole about half of it. 64 px bands on a phone.
	r_in = 52.0 if compact else 88.0
	r_out = 116.0 if compact else 166.0
	var anchor := view * 0.5
	var cam := get_viewport().get_camera_3d()
	if cam and pet and is_instance_valid(pet):
		var world := pet.global_position + Vector3(0.0, pet.def.height_meters * 0.5 if pet.def else 0.5, 0.0)
		if not cam.is_position_behind(world):
			anchor = cam.unproject_position(world)
	# Labels laid out around the origin first, then the whole ring slides in to keep them on screen.
	var font := ThemeDB.fallback_font
	var fs := UiTokens.body(view)
	var rel: Array[Rect2] = []
	var box := Rect2(-Vector2.ONE * r_out, Vector2.ONE * r_out * 2.0)
	for i in rows.size():
		var r := _label_rect(i, font, fs)
		rel.append(r)
		box = box.merge(r)
	var safe := UiTokens.safe_insets(get_viewport())
	var lo := Vector2(safe.w, safe.z) + Vector2(8.0, 8.0) - box.position
	# A landscape phone keeps the ring under the vitals/quest band where it can.
	if compact and not UiTokens.is_narrow(view):
		lo.y = maxf(lo.y, UiTokens.hud_reserved(view)[0].end.y - box.position.y)
	var hi := view - Vector2(safe.x, safe.y) - Vector2(8.0, 8.0) - box.end
	centre = Vector2(clampf(anchor.x, lo.x, maxf(lo.x, hi.x)), clampf(anchor.y, minf(lo.y, hi.y), hi.y))
	label_rects.clear()
	for r in rel:
		label_rects.append(Rect2(r.position + centre, r.size))
	_fade_covered()

## Fades the HUD's hexes and the HANDS slot where the ring or a label covers them (only the HUD's:
## other menus animate their own), and brings back the ones it no longer covers; all once it closes.
func _fade_covered() -> void:
	for c in _faded:
		if is_instance_valid(c):
			c.modulate.a = 1.0
	_faded.clear()
	var hud := get_tree().get_first_node_in_group(&"hud") if visible and is_inside_tree() else null
	if hud == null:
		return
	var held: Control = player.station_craft.held_slot if player and player.station_craft else null
	# Its caption hangs 18 px below the slot (HudLayout.taken_rects).
	if held and held.is_visible_in_tree() and covers(Rect2(held.get_global_rect().position, held.size + Vector2(0, 18))):
		held.modulate.a = 0.0
		_faded.append(held)
	for n in get_tree().get_nodes_in_group(&"hex_button"):
		var h := n as HexButton
		if h and h.is_visible_in_tree() and hud.is_ancestor_of(h) and (covers(h.hex_rect()) or covers(h.caption_rect())):
			h.modulate.a = 0.0
			_faded.append(h)

## Whether a screen rect touches the ring or one of its labels.
func covers(r: Rect2) -> bool:
	if not r.has_area():
		return false
	var near := Vector2(clampf(centre.x, r.position.x, r.end.x), clampf(centre.y, r.position.y, r.end.y))
	if near.distance_to(centre) < r_out:
		return true
	for l in label_rects:
		if l.intersects(r):
			return true
	return false

## Segment i's label box relative to the centre: outside the ring along the segment's middle, growing
## away from the ring (left of it on the left half, right of it on the right half).
func _label_rect(i: int, font: Font, fs: int) -> Rect2:
	var text := _label_text(i, font, fs)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var h := float(fs) + 12.0
	var a := segment_angle(i)
	var at := Vector2(cos(a), sin(a)) * (r_out + 4.0)
	var x := at.x - w * 0.5
	if cos(a) > 0.2:
		x = at.x
	elif cos(a) < -0.2:
		x = at.x - w
	var y := at.y - h * 0.5
	if absf(cos(a)) <= 0.2:
		y = at.y - h if sin(a) < 0.0 else at.y
	return Rect2(Vector2(x, y), Vector2(w, h))

func _label_text(i: int, font: Font, fs: int) -> String:
	return UiTokens.ellipsis(font, str((rows[i] as Dictionary).get("label", "")), UiTokens.LABEL_MAX_W, fs)

func _draw() -> void:
	if not visible or rows.is_empty():
		return
	var view := get_viewport_rect().size
	var n := rows.size()
	var step := TAU / float(n)
	# Centre disc: a light tint so the name reads, the pet itself stays visible through it.
	draw_circle(centre, r_in, CENTRE_TINT)
	for i in n:
		var a0 := segment_angle(i) - step * 0.5
		draw_colored_polygon(_band(a0, a0 + step, r_in, r_out), FILL_HOT if i == hot else FILL)
	draw_arc(centre, r_in, 0.0, TAU, 64, RIM, 3.0, true)
	for i in n:
		var a := segment_angle(i) - step * 0.5
		draw_line(centre + Vector2(cos(a), sin(a)) * r_in, centre + Vector2(cos(a), sin(a)) * r_out, SEAM, 2.0, true)
	var isz := 30.0 if UiTokens.is_compact(view) else 40.0
	for i in n:
		var tex := _icons[i] if i < _icons.size() else null
		if tex:
			draw_texture_rect(tex, Rect2(segment_center(i) - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false)
	var font := ThemeDB.fallback_font
	var fs := UiTokens.body(view)
	for i in mini(n, label_rects.size()):
		var r := label_rects[i]
		draw_rect(r, UiTokens.INK)
		if i == hot:
			draw_rect(r, UiTokens.TEAL, false, 2.0)
		draw_string(font, r.position + Vector2(7.0, r.size.y * 0.5 + float(fs) * 0.36), _label_text(i, font, fs), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTokens.TEXT)
	_draw_meter(view)
	_draw_names(view, font)

func _band(a0: float, a1: float, ri: float, ro: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := maxi(6, int(absf(a1 - a0) / TAU * 72.0))
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / float(steps))
		pts.append(centre + Vector2(cos(a), sin(a)) * ro)
	for k in steps + 1:
		var a := lerpf(a1, a0, float(k) / float(steps))
		pts.append(centre + Vector2(cos(a), sin(a)) * ri)
	return pts

## Fullness: hunger / hunger_max, the meter Feed acts on. HP stays on the pet's world plate.
# ASSUMPTION: the reference's yellow arc is the pet's fullness (no doc names it); HP when the species has no hunger.
func meter_fraction() -> float:
	if pet == null or not is_instance_valid(pet):
		return 0.0
	if pet.hunger_max > 0.0:
		return clampf(pet.hunger / pet.hunger_max, 0.0, 1.0)
	return pet.health.fraction()

func _draw_meter(view: Vector2) -> void:
	var w := 4.0 if UiTokens.is_compact(view) else 5.0
	var r := r_in - w * 0.5 - 3.0
	draw_arc(centre, r, METER_FROM, METER_TO, 32, METER_TRACK, w + 2.0, true)
	var f := meter_fraction()
	if f > 0.0:
		draw_arc(centre, r, METER_FROM, lerpf(METER_FROM, METER_TO, f), 32, METER, w, true)

func _draw_names(view: Vector2, font: Font) -> void:
	if pet == null or not is_instance_valid(pet):
		return
	var species := str(pet.def.species).capitalize() if pet.def else ""
	var given := pet.pet_record.name if pet.pet_record else ""
	var title := given if given != "" else species
	var width := r_in * 2.0 - 8.0  # may run onto the ring's inner edge; drawn on top of it
	var big := UiTokens.heading(view) - 4
	var small := UiTokens.meta(view)
	# A long title steps down to the small size before it is cut ("Compsognathus" on a phone).
	while big > small and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x > width:
		big -= 1
	_shadowed(font, centre + Vector2(0.0, r_in * 0.3), UiTokens.ellipsis(font, title, width, big), big)
	if given != "" and species != "":
		_shadowed(font, centre + Vector2(0.0, r_in * 0.3 + float(big)), UiTokens.ellipsis(font, species, width, small), small)

func _shadowed(font: Font, at: Vector2, text: String, fs: int) -> void:
	var o := UiTokens.centered_origin(font, text, fs, at)
	draw_string(font, o + Vector2(1.0, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
	draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTokens.TEXT)
