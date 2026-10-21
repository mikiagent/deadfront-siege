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
## Of those, the ones the hand would still rather not cover (it sat on the LEVEL UP banner's icon), short of a HUD control.
const NOTES: PackedStringArray = ["toast", "notice", "levelup"]
const WorldUiScript := preload("res://scripts/ui/world_ui.gd")
## A clamped hand prefers a spot whose line runs at most RUN_MAX px within RUN_GAP px of the vitals or the
## card, turning up to TILT_MAX off its target for it (beside the Orders card at 844x390 it pointed along
## the card and read as "look at your orders").
const TILT_MAX := 0.35
const RUN_MAX := 16.0
const RUN_GAP := 20.0
## Motion (the owner's 2026-10-21 gate: no jumps, snaps or side swaps between frames).
const TURN := 10.0      ## rad/s: the hand turns to a new placement instead of snapping round
const GLIDE := 12.0     ## 1/s: on a new target the hand eases over from where it was ...
const GLIDE_MAX := 2000.0  ## ... at most this fast (px/s)
const STICK := 0.2      ## a placement stays while it covers at most this share of the hand more of the soft rects
const GAP_KEEP := 6.0   ## the current placement gives way this close to a HUD block or the screen edge (px) ...
const GAP_NEW := 18.0   ## ... and another takes over only this clear of them, so the hand never flips back and forth
const HOP_PX := 24.0    ## an anchor that moves farther than this in a frame (a new spot, not the target's motion) eases over
const FADE_S := 0.25    ## a move the glide would make across the vitals or the card cross-fades over this long instead
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
var _fade := 1.0        ## 0 -> 1 while the hand cross-fades in from where it was drawn (_ghost_tip, _ghost_angle)
var _ghost_tip := Vector2.ZERO
var _ghost_angle := 0.0
var _hex_off := Vector2.ZERO  ## where in the hex the tip is, as a share of its size from the centre

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
	var notes: Array[Rect2] = []
	for k: String in b:
		for n in NOTES:
			if k.begins_with(n):
				notes.append(b[k])
	var off: Array[Rect2] = soft.duplicate()  # what an on-screen hand covers as little of as it can
	off.append_array(notes)
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
		var near: Array[Rect2] = off.duplicate()
		near.append_array(r.label_rects)
		near.append(r.title_box)
		var own: Array[Rect2] = []  # the hex's own label: the hand keeps off it before any other where it can
		for i in mini(r.options.size(), r.label_rects.size()):
			if StringName(str((r.options[i] as Dictionary).get("item", ""))) == item:
				own.append(r.label_rects[i])
		if _key != "hex":
			_hex_off = Vector2.ZERO
		_key = "hex"
		# On the part of the hex clear of the vitals and the card: a radial beside the Orders card at
		# 844x390 put the Branch hex half on it, and no placement fitted its centre. Off its own label where
		# a placement allows with the tip in the middle half of that part (with the card 2 px above the hex,
		# a hand on its side fitted between them only with the tip 4 px above the centre).
		var firm: Array[Rect2] = keep_off.duplicate()
		firm.append_array(own)
		var tries: Array[Vector2] = [_hex_off, Vector2.ZERO]
		for k in range(1, 5):
			tries.append_array([Vector2(0.0, -k / 16.0), Vector2(0.0, k / 16.0)])
		tries.append_array([Vector2(-0.25, 0.0), Vector2(0.25, 0.0)])
		for o in tries:
			if not is_nan(pick_angle(hex.get_center() + o * hex.size, safe, firm, s, near)):
				_hex_off = o
				break
		return _aim(hex.get_center() + _hex_off * hex.size, safe, keep_off, s, near, 0.0, own)
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
		return _aim(_rect.get_center(), safe, keep_off, s, off, _rect.size.y * 0.3, others)
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
		return _aim(p, safe, keep_off, s, off)
	# On the safe-area edge where the line from the centre leaves the screen, pointing at the target. Where
	# the hand would land on a HUD block there (the minimap too: it only hints a direction), it walks along
	# the edge to the nearest clear spot. It never slides inward: there it tapped the camp tent.
	var edge := clamp_tip(p, behind, inner)
	var goal := p if not behind else inner.get_center() + (edge - inner.get_center()) * 100.0
	var keep := anchor if visible and _key == _key_was else Vector2(NAN, NAN)  # last frame's spot on this edge
	var controls := HudLayout.taken_rects(_hud, PASSING)
	var spot := edge_spot(edge, goal, inner, Rect2(Vector2.ZERO, view), avoid, controls, s, keep, notes, keep_off)
	if is_nan(spot.x):
		return false
	anchor = spot
	_want = edge_aim(spot, goal, Rect2(Vector2.ZERO, view), avoid, controls, notes, keep_off, s)
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
## where it would, it cross-fades from where it was drawn to its new place instead.
func _settle(delta: float, was: bool, key_was: String) -> void:
	var drawn_tip := tip
	var drawn_angle := angle
	var at_was := _at
	if not was:
		_fade = 1.0
	# An edge spot moves in SLIDE_STEP steps as it walks off a HUD block: the hand eases over those too.
	var hop := SLIDE_STEP - 0.5 if _key.begins_with("edge") else HOP_PX
	if not was or _key == "hex":
		_offset = Vector2.ZERO
	else:
		if _key != key_was or anchor.distance_to(_anchor_was) > hop:
			_offset = _at - anchor  # from where the hand was drawn; it eases on from there this same frame
		_offset = _offset.move_toward(Vector2.ZERO, minf(_offset.length() * (1.0 - exp(-GLIDE * delta)), GLIDE_MAX * delta))
	_anchor_was = anchor
	angle = rotate_toward(angle, _want, TURN * delta) if was else _want
	_at = anchor + _offset
	# Never faster than GLIDE_MAX, whatever the anchor did (a move under HOP_PX on top of a glide went past it).
	if was and _key != "hex" and _at.distance_to(at_was) > GLIDE_MAX * delta:
		_at = at_was + (_at - at_was).limit_length(GLIDE_MAX * delta)
		_offset = _at - anchor
	for k in _keep_off:
		if hand_rect(_at, angle, _s).intersects(k):
			_ghost_tip = drawn_tip
			_ghost_angle = drawn_angle
			_fade = 0.0
			angle = _want
			_offset = Vector2.ZERO
			_at = anchor
			break
	_fade = minf(1.0, _fade + delta / FADE_S)
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
	return get_tree().get_first_node_in_group(&"character_creation") != null or WorldUiScript.covering()

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
## off the HUD's other controls (`soft`), off passing `notes`, at most EDGE px off the `view`, and whose
## line (turned by edge_aim) clears `line_off` (the vitals and the card). Failing that, the nearest spot
## clear of all but the line, then off all but the notes, then off `hard` alone; Vector2(NAN, NAN) if none.
## `keep` (last frame's spot) beats any spot but a clear `edge` while it fits as well (its line aside) and
## is at most a quarter of the way round farther: at 844x390 the spots left of the card and below the
## minimap took turns as the target moved, and the hand swapped across the screen.
static func edge_spot(edge: Vector2, goal: Vector2, inner: Rect2, view: Rect2, hard: Array[Rect2], soft: Array[Rect2], s: float,
		keep := Vector2(NAN, NAN), notes: Array[Rect2] = [], line_off: Array[Rect2] = []) -> Vector2:
	var around := 2.0 * (inner.size.x + inner.size.y)
	var u0 := _arc(inner, edge)
	var kept := INF  # how far round `keep` is, less the quarter it may lose by
	var keep_fit := 0
	if not is_nan(keep.x):
		# Its line alone does not make a kept spot give way: the spots left of the card and below the minimap
		# took turns again as the tree moved. The line picks the spot when the hand first clamps.
		keep_fit = _spot_fit(keep, aim_angle(goal - keep), view, hard, soft, notes, s)
		if keep_fit == 3:
			keep_fit = 4
		var d := absf(_arc(inner, keep) - u0)
		# One that fits less well gives way to a clear spot up to a quarter of the way round farther than itself.
		kept = minf(d, around - d) + around * (-0.25 if keep_fit == 4 else 0.25)
	var best := Vector2(NAN, NAN)
	var best_fit := 0
	var grid := snappedf(u0, SLIDE_STEP)
	for k in int(around / SLIDE_STEP / 2.0) + 2:
		if k > 0 and k * SLIDE_STEP >= kept and keep_fit >= maxi(best_fit, 2):
			return keep
		for q: Vector2 in ([edge] if k == 0 else [_on_border(inner, grid + k * SLIDE_STEP), _on_border(inner, grid - k * SLIDE_STEP)]):
			var fit := _spot_level(q, goal, view, hard, soft, notes, line_off, s)
			if fit == 4:
				return q
			if fit > best_fit:
				best = q
				best_fit = fit
	return keep if keep_fit >= 2 and keep_fit >= best_fit else best

## How well a clamped hand fits at `q`: _spot_fit pointing at `goal`, and 4 where it is clear and its line
## (edge_aim) also clears `line_off`.
static func _spot_level(q: Vector2, goal: Vector2, view: Rect2, hard: Array[Rect2], soft: Array[Rect2], notes: Array[Rect2], line_off: Array[Rect2], s: float) -> int:
	var fit := _spot_fit(q, aim_angle(goal - q), view, hard, soft, notes, s)
	if fit < 3:
		return fit
	return 4 if run_along(q, edge_aim(q, goal, view, hard, soft, notes, line_off, s), goal, view, line_off) <= RUN_MAX else 3

## A hand at `q` at angle `a`: 0 on a `hard` block, 1 on `soft` or over EDGE px off `view`, 2 only on
## `notes`, 3 clear.
static func _spot_fit(q: Vector2, a: float, view: Rect2, hard: Array[Rect2], soft: Array[Rect2], notes: Array[Rect2], s: float) -> int:
	var r := hand_rect(q, a, s)
	if hard.any(func (b: Rect2) -> bool: return r.intersects(b)):
		return 0
	if not view.grow(EDGE).encloses(Transform2D(a, Vector2(s, s), 0.0, q) * BOX) or soft.any(func (b: Rect2) -> bool: return r.intersects(b)):
		return 1
	return 2 if notes.any(func (b: Rect2) -> bool: return r.intersects(b)) else 3

## A clamped hand's angle at `q`: at `goal`, or turned up to TILT_MAX off it, as little as clears its line
## from `line_off` (see RUN_MAX), the hand staying as clear as it was.
static func edge_aim(q: Vector2, goal: Vector2, view: Rect2, hard: Array[Rect2], soft: Array[Rect2], notes: Array[Rect2], line_off: Array[Rect2], s: float) -> float:
	var a0 := aim_angle(goal - q)
	var best := a0
	var best_run := run_along(q, a0, goal, view, line_off)
	if best_run <= RUN_MAX:
		return a0
	var fit0 := _spot_fit(q, a0, view, hard, soft, notes, s)
	var open := [true, true]  # the hand turns through every step to its tilt: one that does not fit closes that side
	for k in range(1, 5):
		for i in 2:
			var a := a0 + (2.0 * i - 1.0) * TILT_MAX * k / 4.0
			if not open[i] or _spot_fit(q, a, view, hard, soft, notes, s) < fit0:
				open[i] = false
				continue
			var run := run_along(q, a, goal, view, line_off)
			if run < best_run:
				best = a
				best_run = run
		if best_run <= RUN_MAX:
			break
	return best

## How far the line from `q` at angle `a` runs within RUN_GAP px of a `blocks` rect (but the one `goal` is
## under) before it leaves `view`.
static func run_along(q: Vector2, a: float, goal: Vector2, view: Rect2, blocks: Array[Rect2]) -> float:
	var d := finger_dir(a)
	var out := _slab(q, d, view).y
	var run := 0.0
	for b in blocks:
		if not b.has_point(goal):
			var t := _slab(q, d, b.grow(RUN_GAP))
			run += maxf(0.0, minf(t.y, out) - maxf(t.x, 0.0))
	return run

## Where the line through `q` along `d` enters and leaves `r`, in px along `d` (x > y when it misses).
static func _slab(q: Vector2, d: Vector2, r: Rect2) -> Vector2:
	var lo := -INF
	var hi := INF
	for i in 2:
		if absf(d[i]) < 0.0001:
			if q[i] < r.position[i] or q[i] > r.end[i]:
				return Vector2(INF, -INF)
		else:
			var t0 := (r.position[i] - q[i]) / d[i]
			var t1 := (r.end[i] - q[i]) / d[i]
			lo = maxf(lo, minf(t0, t1))
			hi = minf(hi, maxf(t0, t1))
	return Vector2(lo, hi)

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
	if _fade < 1.0:
		_draw_hand(_ghost_tip, _ghost_angle, 1.0 - _fade)
	_draw_hand(tip, angle, _fade)

func _draw_hand(at: Vector2, a: float, alpha: float) -> void:
	var s := hand_scale(get_viewport_rect().size)
	var press := 0.0 if clamped else 1.0 - bob(_t) / BOB  # 1 while the tip is in: the hand squashes a touch
	draw_set_transform(at + Vector2(2.0, 3.0) * s, a, Vector2(s, s) * (1.0 - 0.04 * press))
	for sh: Array in _shapes:
		draw_colored_polygon(sh[0], Color(0, 0, 0, 0.28 * alpha))  # soft drop shadow
	draw_set_transform(at, a, Vector2(s, s) * (1.0 - 0.04 * press))
	for sh: Array in _shapes:
		draw_colored_polygon(sh[0], Color(INK, INK.a * alpha))
	for sh: Array in _shapes:
		draw_colored_polygon(sh[1], Color(sh[2] as Color, alpha))
	# Creases between the curled fingers and along the thumb.
	for y in [43.0, 53.0]:
		draw_line(Vector2(13.0, y), Vector2(30.0, y), Color(INK, 0.55 * alpha), 2.0, true)
	draw_line(Vector2(-6.0, 48.0), Vector2(-1.0, 40.0), Color(INK, 0.45 * alpha), 2.0, true)
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
