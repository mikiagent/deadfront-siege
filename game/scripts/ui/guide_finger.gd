class_name GuideFinger
extends Control
## The walkthrough finger (durango-prompts 22): a white pointing hand that taps, gently, at what the
## current order wants tapped next. A tree for a gather order, then that order's hex once the gather
## radial opens on it, the HUD's craft control, a station or a creature. It hides on the pick of the
## right hex or when the order advances, and that order never shows it again (World.guide_done, saved).
## It sits on its own canvas layer above the radial (64) and the work ring (65) and below the modals
## (96), and it never takes input: the radial closes on any press off a hex, and a tap on the hand must
## land on the hex under it.

const LAYER := 66
## Hand outline in local px: tip at the origin, finger pointing up; the cuff ends at y 78.
const BOX := Rect2(-28.0, -3.0, 65.0, 84.0)
const HAND_H := 78.0
const BOB := 10.0       ## the tap pulls the tip back at most this far along the finger (px at scale 1)
const TAP_HZ := 1.1
const EDGE := 20.0      ## an off-screen target clamps the tip this far inside the safe area
const REPICK_S := 0.5   ## the nearest world target is re-chosen this often; it is projected every frame
## Hand placements tried in order (finger angle, 0 = up): below-right, below-left, above-right, above-left,
## then square on (right, left, below, above) for targets in a corner, such as the MENU hex.
const ANGLES: Array[float] = [-0.5236, 0.5236, -2.618, 2.618, -1.5708, 1.5708, 0.0, 3.1416]
const WHITE := Color(1.0, 1.0, 1.0)
const CUFF := Color(0.84, 0.86, 0.88)
const INK := Color(0.07, 0.08, 0.09, 0.92)

var player: Player
## Read by the lab: where the drawn tip is, the angle, which step and target this frame.
var tip := Vector2.ZERO
var angle := 0.0
var clamped := false
var step_id := ""
var target: Node3D
var _plan: Dictionary = {}
var _index := -1
var _repick := 0.0
var _rect := Rect2()   ## a screen target (craft control); empty for a world one
var _t := 0.0
var _shapes: Array = []  ## [[outline polygon, fill polygon, fill color], ...] in local px
var _hud: HuntHud

## The finger's layer under `p` (PlayerView.setup_ui calls this once the gather radial exists).
static func mount(p: Player) -> GuideFinger:
	var layer := CanvasLayer.new()
	layer.name = "GuideLayer"
	layer.layer = LAYER
	p.add_child(layer)
	var f := GuideFinger.new()
	f.name = "GuideFinger"
	f.player = p
	layer.add_child(f)
	if p._gather_radial:
		p._gather_radial.picked.connect(f._on_picked)
	return f

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 100  # after the radial's per-frame layout and the camera follow
	visible = false
	_build_shapes()

func _process(delta: float) -> void:
	_t += delta
	var was := visible
	visible = _update(delta)
	if visible or was:
		queue_redraw()

## Decide this frame's target and placement; false hides the hand.
func _update(delta: float) -> bool:
	if player == null or player.dead or player != PlayerRegistry.local():
		return false
	if _index >= 0 and World.objective == _index + 1:
		_finish(str(Objectives.step(_index).get("id", "")))  # the order advanced: that step is done
	if _index != World.objective:
		_index = World.objective
		_plan = Guide.current_plan()
		target = null
		_repick = 0.0
	if _hud == null or not is_instance_valid(_hud):
		_hud = get_tree().get_first_node_in_group("hud") as HuntHud
	if _hud == null or _hud.play_covered():
		return false
	var cur := Objectives.current(player)
	step_id = str(cur.get("id", ""))
	if cur.is_empty() or bool(cur["done"]) or World.guide_done.has(step_id):
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var view := get_viewport_rect().size
	var ins := UiTokens.safe_insets(get_viewport())
	var safe := Rect2(Vector2(ins.w, ins.z), view - Vector2(ins.w + ins.x, ins.z + ins.y))
	# Never on the vitals or the Orders card; off the minimap where it can be (its title and text bracket it).
	var b := _hud.drawn_blocks
	var keep_off: Array[Rect2] = []
	for k in ["vitals", "quest"]:
		if b.has(k):
			keep_off.append(b[k])
	var soft: Array[Rect2] = []
	if b.has("map_title") and b.has("map_text"):
		soft.append((b["map_title"] as Rect2).merge(b["map_text"]))
	var s := hand_scale(view)
	# A gather order's hex, once the radial is open on a node that offers the item. The hand would
	# rather not cover the radial's labels and title either.
	if str(_plan.get("kind", "")) == "gather":
		var r := player._gather_radial
		var hex := r.hex_rect_for(StringName(str(_plan["item"]))) if r else Rect2()
		if hex.has_area():
			clamped = false
			var near: Array[Rect2] = soft.duplicate()
			near.append_array(r.label_rects)
			near.append(r.title_box)
			return _aim(hex.get_center(), safe, keep_off, s, near)
	if not is_instance_valid(target):
		target = null  # freed with its island (travel, a reload); a freed object passes a != null check
	_repick -= delta
	if _repick <= 0.0:
		_repick = REPICK_S
		var found := Guide.world_target(player, _plan, _hud, target)
		target = found.get("node", null)
		_rect = found.get("rect", Rect2())
	if _rect.has_area():
		clamped = false
		return _aim(_rect.get_center(), safe, keep_off, s, soft)
	if target == null:
		return false
	var at := Guide.aim_point(target)
	var behind := cam.is_position_behind(at)
	var p := cam.unproject_position(at)
	var inner := safe.grow(-EDGE)
	clamped = behind or not inner.has_point(p)
	if not clamped:
		return _aim(p, safe, keep_off, s, soft)
	# On the edge where the line from the centre leaves the screen, pointing out along it; where the hand
	# would land on a HUD block there (the minimap too: it only hints a direction), it slides in along the
	# same line until it clears.
	var edge := clamp_tip(p, behind, inner)
	var a := aim_angle(edge - inner.get_center())
	var avoid: Array[Rect2] = keep_off.duplicate()
	avoid.append_array(soft)
	for k in 9:
		if _place(edge.lerp(inner.get_center(), float(k) / 8.0), a, avoid, s):
			return true
	return false

## Tip on `at`, hand on screen, off `keep_off` and covering as little of `soft` as it can.
func _aim(at: Vector2, safe: Rect2, keep_off: Array[Rect2], s: float, soft: Array[Rect2] = []) -> bool:
	var a := pick_angle(at, safe, keep_off, s, soft)
	return not is_nan(a) and _place(at, a, keep_off, s)

## An edge-clamped hand may run off the screen behind the tip, never onto a `keep_off` block.
func _place(anchor: Vector2, a: float, keep_off: Array[Rect2], s: float) -> bool:
	for k in keep_off:
		if hand_rect(anchor, a, s).intersects(k):
			return false
	angle = a
	tip = anchor - Vector2(sin(a), -cos(a)) * bob(_t) * s
	return true

func _on_picked(_anchor: Node3D, i: int) -> void:
	var r := player._gather_radial if player else null
	if r == null or str(_plan.get("kind", "")) != "gather" or i < 0 or i >= r.options.size():
		return
	if str((r.options[i] as Dictionary).get("item", "")) == str(_plan["item"]):
		_finish(str(Objectives.step(World.objective).get("id", "")))
		visible = false
		queue_redraw()

## Record a finished step once and save it, so a reload does not bring the finger back.
func _finish(id: String) -> void:
	if id == "" or World.guide_done.has(id):
		return
	World.guide_done.append(id)
	print("[guide] done %s" % id)
	SaveGame.save_now()

# ---------------------------------------------------------------- placement (static: unit-tested)

## The hand is at least 64 px tall on a landscape phone and a little larger on a desktop canvas.
static func hand_scale(view: Vector2) -> float:
	return 0.9 if UiTokens.is_compact(view) else 1.1

## The tap: the tip eases back along the finger and presses in again, TAP_HZ times a second.
static func bob(t: float) -> float:
	return BOB * (0.5 + 0.5 * cos(TAU * TAP_HZ * t))

## Finger angle that points along `dir` (0 = up, positive = clockwise).
static func aim_angle(dir: Vector2) -> float:
	return atan2(dir.x, -dir.y)

## Screen rect the hand covers with its tip on `at` (both ends of the tap).
static func hand_rect(at: Vector2, a: float, s: float) -> Rect2:
	return (Transform2D(a, Vector2(s, s), 0.0, at) * BOX).grow(BOB * s)

static func hand_clear(at: Vector2, a: float, s: float, safe: Rect2, keep_off: Array[Rect2]) -> bool:
	var r := hand_rect(at, a, s)
	if not safe.encloses(r):
		return false
	for k in keep_off:
		if r.intersects(k):
			return false
	return true

## The placement whose hand stays inside `safe`, off `keep_off`, and covers the least of `soft` (the
## first such on a tie); NAN when none fits (the finger hides rather than cover the vitals or the card).
static func pick_angle(at: Vector2, safe: Rect2, keep_off: Array[Rect2], s: float, soft: Array[Rect2] = []) -> float:
	var best := NAN
	var best_cover := INF
	for a in ANGLES:
		if not hand_clear(at, a, s, safe, keep_off):
			continue
		var cover := 0.0
		for k in soft:
			cover += hand_rect(at, a, s).intersection(k).get_area()
		if cover < best_cover:
			best = a
			best_cover = cover
		if cover <= 0.0:
			break
	return best

## Where a target off `inner` (or behind the camera, whose projection mirrors) meets its edge on the
## line from the centre: the finger sits there and points out at it.
static func clamp_tip(p: Vector2, behind: bool, inner: Rect2) -> Vector2:
	var c := inner.get_center()
	var d := (p - c) * (-1.0 if behind else 1.0)
	if d.length() < 1.0:
		d = Vector2.UP
	var t := INF
	if d.x > 0.0:
		t = minf(t, (inner.end.x - c.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, (inner.position.x - c.x) / d.x)
	if d.y > 0.0:
		t = minf(t, (inner.end.y - c.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, (inner.position.y - c.y) / d.y)
	return c + d * t

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not visible:
		return
	var s := hand_scale(get_viewport_rect().size)
	var press := 1.0 - bob(_t) / BOB  # 1 while the tip is in: the hand squashes a touch
	draw_set_transform(tip + Vector2(2.0, 3.0) * s, angle, Vector2(s, s) * (1.0 - 0.04 * press))
	for sh: Array in _shapes:
		draw_colored_polygon(sh[0], Color(0, 0, 0, 0.28))  # soft drop shadow
	draw_set_transform(tip, angle, Vector2(s, s) * (1.0 - 0.04 * press))
	for sh: Array in _shapes:
		draw_colored_polygon(sh[0], INK)
	for sh: Array in _shapes:
		draw_colored_polygon(sh[1], sh[2])
	# Creases between the curled fingers and along the thumb.
	for y in [43.0, 53.0]:
		draw_line(Vector2(13.0, y), Vector2(30.0, y), Color(INK, 0.55), 2.0, true)
	draw_line(Vector2(-6.0, 48.0), Vector2(-1.0, 40.0), Color(INK, 0.45), 2.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## A gloved right hand from the back: index up, three curled fingers to its right, thumb at the left,
## a grey cuff. Each part is drawn twice: 3 px larger in ink (the outline), then white.
func _build_shapes() -> void:
	var o := 3.0
	var parts := [
		["cap", Vector2(-10.0, 50.0), Vector2(-18.0, 37.0), 6.5, WHITE],  # thumb
		["box", Rect2(-10.0, 30.0, 36.0, 38.0), 10.0, WHITE],             # palm
		["cap", Vector2(14.0, 38.0), Vector2(26.0, 38.0), 6.5, WHITE],     # curled fingers
		["cap", Vector2(14.0, 48.0), Vector2(27.0, 48.0), 6.5, WHITE],
		["cap", Vector2(14.0, 58.0), Vector2(25.0, 58.0), 6.0, WHITE],
		["cap", Vector2(0.0, 8.0), Vector2(0.0, 38.0), 8.0, WHITE],        # index finger, tip at the origin
		["box", Rect2(-8.0, 64.0, 32.0, 14.0), 4.0, CUFF],                # cuff
	]
	_shapes.clear()
	for part: Array in parts:
		if part[0] == "cap":
			_shapes.append([_capsule(part[1], part[2], part[3] + o), _capsule(part[1], part[2], part[3]), part[4]])
		else:
			_shapes.append([_round_rect((part[1] as Rect2).grow(o), part[2] + o), _round_rect(part[1], part[2]), part[3]])

static func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d := (b - a).angle() if a != b else 0.0
	for i in 11:
		out.append(b + Vector2.from_angle(d - PI * 0.5 + PI * float(i) / 10.0) * r)
	for i in 11:
		out.append(a + Vector2.from_angle(d + PI * 0.5 + PI * float(i) / 10.0) * r)
	return out

static func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad), r.position + Vector2(rad, rad)]
	for c in 4:
		for i in 6:
			out.append(corners[c] + Vector2.from_angle(-PI * 0.5 + PI * 0.5 * float(c) + PI * 0.5 * float(i) / 5.0) * rad)
	return out
