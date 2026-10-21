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
const NUDGE := 6.0      ## a clamped hand does not tap: it nudges this far (px at scale 1) toward the target ...
const NUDGE_HZ := 0.7   ## ... this often, with no press squash
const REPICK_S := 0.5   ## the nearest world target is re-chosen this often; it is projected every frame
const SLIDE_STEP := 8.0 ## a clamped hand walks along the edge off a HUD block on a grid this fine (px)
## HUD blocks that come and go (notices, toasts, level-ups, pills, name tags): a clamped hand does not
## walk away from those.
const PASSING: PackedStringArray = ["toast", "notice", "levelup", "pill", "nameplate", "plate"]
const WorldUiScript := preload("res://scripts/ui/world_ui.gd")
## Motion (the owner's 2026-10-21 gate: no jumps, snaps or side swaps between frames).
const TURN := 10.0      ## rad/s: the hand turns to a new placement instead of snapping round
const GLIDE := 12.0     ## 1/s: on a new target the hand eases over from where it was ...
const GLIDE_MAX := 2000.0  ## ... at most this fast (px/s)
const STICK := 0.2      ## a placement stays while it covers at most this share of the hand more of the soft rects
const GAP_KEEP := 6.0   ## the current placement gives way this close to a HUD block or the screen edge (px) ...
const GAP_NEW := 18.0   ## ... and another takes over only this clear of them, so the hand never flips back and forth
const HOP_PX := 24.0    ## an anchor that moves farther than this in a frame (a new spot, not the target's motion) eases over
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
var anchor := Vector2.ZERO  ## the point the tip taps this frame, before easing and the tap
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
var _want := 0.0        ## this frame's placement angle; `angle` turns toward it
var _key := ""          ## what the hand is on (hex, rect, node or edge plus the target): a change eases over
var _key_was := ""      ## last frame's _key: on a new one the placement is picked afresh
var _at := Vector2.ZERO ## the anchor as drawn (anchor plus the easing offset)
var _offset := Vector2.ZERO
var _anchor_was := Vector2.ZERO
var _keep_off: Array[Rect2] = []
var _s := 1.0

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
	_key_was = _key
	visible = _update(delta)
	if visible:
		_settle(delta, was, _key_was)
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
	if _hud == null or _hud.play_covered() or _world_covered():
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
	_s = s
	_keep_off = keep_off
	# While the gather radial is open the finger is only ever on its hex for this order's item, and would
	# rather not cover the radial's labels and title. Open on anything else, it waits: the hand pointing
	# past it sat on the radial's labels.
	var r := player._gather_radial
	if r and r.is_open():
		var item := StringName(str(_plan.get("item", "")))
		var hex := clear_part(r.hex_rect_for(item), keep_off) if str(_plan.get("kind", "")) == "gather" else Rect2()
		if not hex.has_area():
			return false
		clamped = false
		var near: Array[Rect2] = soft.duplicate()
		near.append_array(r.label_rects)
		near.append(r.title_box)
		var own: Array[Rect2] = []  # the hex's own label: the hand keeps off it before any other where it can
		for i in mini(r.options.size(), r.label_rects.size()):
			if StringName(str((r.options[i] as Dictionary).get("item", ""))) == item:
				own.append(r.label_rects[i])
		_key = "hex"
		# On the part of the hex clear of the vitals and the card: a radial beside the Orders card at
		# 844x390 put the Branch hex half on it, and no placement fitted its centre.
		return _aim(hex.get_center(), safe, keep_off, s, near, 0.0, own)
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
		_key = "rect"
		# Off the HUD's other controls where it can be (it lay across the ANIMALS hex beside MENU), with the
		# tip on the control's rim rather than its middle, so the icon it asks for stays in sight.
		var others: Array[Rect2] = []
		others.assign(HudLayout.taken_rects(_hud, PASSING).filter(func (k: Rect2) -> bool: return not k.intersects(_rect)))
		return _aim(_rect.get_center(), safe, keep_off, s, soft, _rect.size.y * 0.3, others)
	if target == null:
		return false
	var at := Guide.aim_point(target)
	var behind := cam.is_position_behind(at)
	var p := cam.unproject_position(at)
	var inner := safe.grow(-EDGE)
	var avoid: Array[Rect2] = keep_off.duplicate()
	avoid.append_array(soft)
	# A target under a HUD block is as hidden as one off screen: point at it from outside the block.
	clamped = behind or not inner.has_point(p) or avoid.any(func (k: Rect2) -> bool: return k.has_point(p))
	_key = "%s%d" % ["edge" if clamped else "node", target.get_instance_id()]
	if not clamped:
		return _aim(p, safe, keep_off, s, soft)
	# On the safe-area edge where the line from the centre leaves the screen, pointing at the target. Where
	# the hand would land on a HUD block there (the minimap too: it only hints a direction), it walks along
	# the edge to the nearest clear spot. It never slides inward: there it tapped the camp tent.
	var edge := clamp_tip(p, behind, inner)
	var goal := p if not behind else inner.get_center() + (edge - inner.get_center()) * 100.0
	var spot := edge_spot(edge, goal, inner, Rect2(Vector2.ZERO, view), avoid, HudLayout.taken_rects(_hud, PASSING), s)
	if is_nan(spot.x):
		return false
	anchor = spot
	_want = aim_angle(goal - spot)
	return true

## Tip on `at` (pulled `pull` px back toward the hand), hand on screen, off `keep_off` and covering as
## little of `soft` as it can; off `firm` too where any placement allows. On a new target the placement
## is picked afresh: the one kept from the tree covered the Branch hex's own label.
func _aim(at: Vector2, safe: Rect2, keep_off: Array[Rect2], s: float, soft: Array[Rect2] = [], pull: float = 0.0, firm: Array[Rect2] = []) -> bool:
	var prefer := _want if visible and _key == _key_was else NAN  # visible: last frame's
	var a := NAN
	if not firm.is_empty():
		var both: Array[Rect2] = keep_off.duplicate()
		both.append_array(firm)
		a = pick_angle(at, safe, both, s, soft, prefer, pull)
	if is_nan(a):
		a = pick_angle(at, safe, keep_off, s, soft, prefer, pull)
	return not is_nan(a) and _place(at - finger_dir(a) * pull, a, keep_off, s)

## The hand with its tip on `at`, unless that puts it on a `keep_off` block.
func _place(at: Vector2, a: float, keep_off: Array[Rect2], s: float) -> bool:
	for k in keep_off:
		if hand_rect(at, a, s).intersects(k):
			return false
	anchor = at
	_want = a
	return true

## Ease onto this frame's placement: on a new target (another tree, the edge giving way to the tree on
## screen) the hand glides over, and it turns rather than snapping round. A gather hex is tracked exactly
## (the tip is on it from the frame the radial opens). The eased hand never covers the vitals or the card:
## it snaps instead.
func _settle(delta: float, was: bool, key_was: String) -> void:
	if not was or _key == "hex":
		_offset = Vector2.ZERO
	elif _key != key_was or anchor.distance_to(_anchor_was) > HOP_PX:
		_offset = _at - anchor
	else:
		_offset = _offset.move_toward(Vector2.ZERO, minf(_offset.length() * (1.0 - exp(-GLIDE * delta)), GLIDE_MAX * delta))
	_anchor_was = anchor
	angle = rotate_toward(angle, _want, TURN * delta) if was else _want
	_at = anchor + _offset
	for k in _keep_off:
		if hand_rect(_at, angle, _s).intersects(k):
			angle = _want
			_offset = Vector2.ZERO
			_at = anchor
			break
	tip = _at - finger_dir(angle) * (nudge(_t) if clamped else bob(_t)) * _s

func _on_picked(_anchor: Node3D, i: int) -> void:
	var r := player._gather_radial if player else null
	if r == null or str(_plan.get("kind", "")) != "gather" or i < 0 or i >= r.options.size():
		return
	if str((r.options[i] as Dictionary).get("item", "")) == str(_plan["item"]):
		_finish(str(Objectives.step(World.objective).get("id", "")))
		visible = false
		queue_redraw()

## A screen the HUD does not own is up: WorldUI's sheet (terrain pick, harbour, map, pause), its arrival
## welcome, or character creation (HANDS hides for that one the same way). All but the welcome (92) draw
## under this layer.
func _world_covered() -> bool:
	if get_tree().get_first_node_in_group(&"character_creation") != null:
		return true
	var w: Variant = WorldUiScript._i
	if not is_instance_valid(w):
		return false
	var ui: WorldUiScript = w
	return ui._panel.visible or (ui.is_inside_tree() and ui.get_parent().has_node(^"ArrivalWelcome"))

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

## A clamped hand's nudge toward what it points at: smaller and slower than the tap, and unsquashed.
static func nudge(t: float) -> float:
	return NUDGE * (0.5 + 0.5 * cos(TAU * NUDGE_HZ * t))

## Unit vector the finger points along at angle `a`.
static func finger_dir(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))

## Finger angle that points along `dir` (0 = up, positive = clockwise).
static func aim_angle(dir: Vector2) -> float:
	return atan2(dir.x, -dir.y)

## Screen rect the hand covers with its tip on `at`: both ends of the tap (which only pulls it back along
## the finger) and the drop shadow.
static func hand_rect(at: Vector2, a: float, s: float) -> Rect2:
	var r := Transform2D(a, Vector2(s, s), 0.0, at) * BOX
	return r.merge(Rect2(r.position - finger_dir(a) * BOB * s, r.size)).grow(3.0 * s)

static func hand_clear(at: Vector2, a: float, s: float, safe: Rect2, keep_off: Array[Rect2], gap: float = 0.0) -> bool:
	var r := hand_rect(at, a, s).grow(gap)
	if not safe.encloses(r):
		return false
	for k in keep_off:
		if r.intersects(k):
			return false
	return true

## The placement whose hand stays inside `safe`, off `keep_off`, and covers the least of `soft` (the
## first such on a tie); NAN when none fits (the finger hides rather than cover the vitals or the card).
## No swapping sides frame to frame: `prefer` (the current placement) stays while it is GAP_KEEP clear and
## covers at most STICK of the hand more than the best; another must be GAP_NEW clear to take over. Only
## when nothing is that clear does any fit do.
## `pull` moves the tip that far back toward the hand from `at` (onto a control's rim).
static func pick_angle(at: Vector2, safe: Rect2, keep_off: Array[Rect2], s: float, soft: Array[Rect2] = [], prefer: float = NAN, pull: float = 0.0) -> float:
	for loose in [false, true]:
		var best := NAN
		var best_cover := INF
		var kept := INF
		for a in ANGLES:
			var t := at - finger_dir(a) * pull
			if not hand_clear(t, a, s, safe, keep_off, 0.0 if loose else (GAP_KEEP if a == prefer else GAP_NEW)):
				continue
			var cover := 0.0
			for k in soft:
				cover += hand_rect(t, a, s).intersection(k).get_area()
			if a == prefer:
				kept = cover
			if cover < best_cover:
				best = a
				best_cover = cover
		if not is_nan(best):
			return prefer if kept < INF and kept <= best_cover + STICK * hand_rect(at, 0.0, s).get_area() else best
	return NAN

## The biggest part of `r` clear of every rect in `blocks` (the strip beside, above or below each one it
## meets); empty when they cover it.
static func clear_part(r: Rect2, blocks: Array[Rect2]) -> Rect2:
	for k in blocks:
		if not r.intersects(k):
			continue
		var best := Rect2()
		for part in [Rect2(r.position, Vector2(k.position.x - r.position.x, r.size.y)),
				Rect2(Vector2(k.end.x, r.position.y), Vector2(r.end.x - k.end.x, r.size.y)),
				Rect2(r.position, Vector2(r.size.x, k.position.y - r.position.y)),
				Rect2(Vector2(r.position.x, k.end.y), Vector2(r.size.x, r.end.y - k.end.y))]:
			if (part as Rect2).size.x > 0.0 and (part as Rect2).size.y > 0.0 and (part as Rect2).get_area() > best.get_area():
				best = part
		r = best
	return r

## Where a clamped hand goes: `edge` itself, or the nearest spot along the border of `inner` (on a grid,
## so it holds still) where the hand pointing at `goal` is off `hard` (the vitals, the card, the minimap),
## off the HUD's other controls (`soft`) and at most EDGE px off the `view`. Failing that, the nearest spot
## off `hard` alone; Vector2(NAN, NAN) if there is none.
static func edge_spot(edge: Vector2, goal: Vector2, inner: Rect2, view: Rect2, hard: Array[Rect2], soft: Array[Rect2], s: float) -> Vector2:
	var around := 2.0 * (inner.size.x + inner.size.y)
	var u0 := _arc(inner, edge)
	var fallback := Vector2(NAN, NAN)
	var on_screen := view.grow(EDGE)
	var grid := snappedf(u0, SLIDE_STEP)
	for k in int(around / SLIDE_STEP / 2.0) + 2:
		for q: Vector2 in ([edge] if k == 0 else [_on_border(inner, grid + k * SLIDE_STEP), _on_border(inner, grid - k * SLIDE_STEP)]):
			var a := aim_angle(goal - q)
			var body := Transform2D(a, Vector2(s, s), 0.0, q) * BOX
			var r := hand_rect(q, a, s)
			if hard.any(func (b: Rect2) -> bool: return r.intersects(b)):
				continue
			if is_nan(fallback.x):
				fallback = q
			if on_screen.encloses(body) and not soft.any(func (b: Rect2) -> bool: return r.intersects(b)):
				return q
	return fallback

## The point `u` px clockwise along the border of `r` from its top-left corner.
static func _on_border(r: Rect2, u: float) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	u = fposmod(u, 2.0 * (w + h))
	if u < w:
		return r.position + Vector2(u, 0.0)
	if u < w + h:
		return Vector2(r.end.x, r.position.y + u - w)
	if u < 2.0 * w + h:
		return Vector2(r.end.x - (u - w - h), r.end.y)
	return Vector2(r.position.x, r.end.y - (u - 2.0 * w - h))

## How far clockwise from the top-left corner of `r` its border point nearest `q` is.
static func _arc(r: Rect2, q: Vector2) -> float:
	var w := r.size.x
	var h := r.size.y
	var side := [absf(q.y - r.position.y), absf(q.x - r.end.x), absf(q.y - r.end.y), absf(q.x - r.position.x)]
	match side.find(side.min()):
		0:
			return clampf(q.x - r.position.x, 0.0, w)
		1:
			return w + clampf(q.y - r.position.y, 0.0, h)
		2:
			return w + h + clampf(r.end.x - q.x, 0.0, w)
	return 2.0 * w + h + clampf(r.end.y - q.y, 0.0, h)

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
	var press := 0.0 if clamped else 1.0 - bob(_t) / BOB  # 1 while the tip is in: the hand squashes a touch
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
