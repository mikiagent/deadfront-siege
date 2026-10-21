extends SceneTree
## CONTROLS acceptance (docs/orchestration/reports/claude-mmo-controls.md).
## B1: the gather radial solves its layout when it opens and holds it against its node while the camera
## follows the survivor's walk (it re-solved every frame against the survivor's nameplate, so the hexes,
## the title and the labels jumped sides: owner "UI glitching up and down on resource nodes"); it solves
## again only when the held layout runs off the screen, and a jiggle at that edge does not flip it back.
## B2: WASD and the arrows move the survivor relative to the camera at walk speed (diagonals too), Shift
## sprints, a move key drops a tap-to-move path and pending work (a gather or a craft still walking to its
## station); on touch a left-half drag floats up a stick centred on the press (the press itself never reaches
## the tap path), a short tap there still taps, the right half, HUD controls, a pinch and building placement
## keep their touches, and a desktop click on the left half still walks.
## B3: on a real island (TilePath), a tap-to-move route is planned once and walked straight, easing off so
## the survivor stops on the tapped tile (it slid ~0.8 m past it); a fence dropped across the route ahead
## is walked around without touching it (the route was re-planned only on a timer or after bumping it); a
## survivor pressed against a fence starts her route on her own side of it (the start tile was the first
## free one in scan order, often behind the fence); an opened gate is used at once; a blocker the grid
## does not know stops the route within 2 s with "Can't get there." and no hop (it pushed for ever).
## Usage: godot --headless --path game --script res://tests/t_controls.gd   -> "[t_controls] PASS", exit 0/1.

const MAX_STEP := 2.0  ## px a hex, the title or a label may move against the node's anchor in one frame
const SWAP_DEG := 45.0  ## a hex whose bearing from the anchor turns more than this in a frame swapped sides
const WALK_MPS := 5.5
const REACH_M := 1.6
const CAM_SIZE := 22.0  ## zoomed out as a player does to tap a node 15 m off (gather_jitter_lab does the same)

var failures: Array[String] = []
var _started := false
var host: Node3D
var cam: Camera3D
var player
var radial
var node: Node3D

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_controls] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	host = Node3D.new()
	host.name = "TControls"
	get_root().add_child(host)
	# The real survivor, held still: the test walks it, and its nameplate is what the radial used to dodge.
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	# The game's follow camera on it (its own lerp, its own physics interpolation setting).
	cam = load("res://scripts/camera/iso_camera.gd").new()
	cam.size = CAM_SIZE
	cam.target_path = player.get_path()
	host.add_child(cam)
	cam.current = true
	node = Node3D.new()
	node.name = "Bush"
	host.add_child(node)
	var layer := CanvasLayer.new()
	host.add_child(layer)
	radial = load("res://scripts/ui/gather_radial.gd").new()
	layer.add_child(radial)
	await process_frame
	# Walks in from each side of the screen: the nameplate passes the node from left, right, above, below.
	var right := cam.global_basis.x * Vector3(1, 0, 1)
	var down := cam.global_basis.z * Vector3(1, 0, 1)
	for dir in [right.normalized(), -right.normalized(), down.normalized(), -down.normalized()]:
		await _walk_case(dir)
	await _edge_case()
	await _b2()
	await _b3()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_controls] PASS")
		quit(0)
	else:
		print("[t_controls] FAIL count=%d" % failures.size())
		quit(1)

func _options() -> Array:
	return [
		{"item": "fiber", "min": 1, "max": 2, "tool": "none", "seconds": 1.8, "left": 6},
		{"item": "berries", "min": 1, "max": 2, "tool": "none", "seconds": 1.8, "left": 4},
		{"item": "seeds", "min": 1, "max": 1, "tool": "none", "seconds": 2.4, "left": 2},
	]

func _anchor() -> Vector2:
	return cam.unproject_position(node.global_position + Vector3(0, radial.anchor_height * 0.45, 0))

## Each hex's centre, the title's centre and each label's centre, relative to the node's anchor.
func _parts() -> Array[Vector2]:
	var a := _anchor()
	var out: Array[Vector2] = []
	for b in radial._buttons:
		out.append(b.position + b.size * 0.5 - a)
	out.append((radial.title_box as Rect2).get_center() - a)
	for r in radial.label_rects:
		out.append((r as Rect2).get_center() - a)
	return out

## B1 gate: the survivor walks ~2.7 s at walking speed from 15 m to the node's reach with the radial
## open, the camera following; per frame no part moves more than MAX_STEP px against the anchor and no
## hex turns to another side.
func _walk_case(dir: Vector3) -> void:
	radial.close()
	player.global_position = Vector3.ZERO
	node.global_position = dir * 15.0
	cam._snap()
	await process_frame
	radial.open_options(node, "Wild Grass", 1, 1.0, _options(), null)
	await process_frame
	await process_frame  # the first draw picks the labels
	var prev := _parts()
	var worst := 0.0
	var swaps := 0
	var frames := 0
	while player.global_position.distance_to(node.global_position) > REACH_M:
		var step := minf(WALK_MPS / 60.0, player.global_position.distance_to(node.global_position) - REACH_M)
		player.global_position += (node.global_position - player.global_position).normalized() * step
		await process_frame
		var cur := _parts()
		frames += 1
		if cur.size() != prev.size():
			swaps += 1
		else:
			for i in cur.size():
				worst = maxf(worst, (cur[i] - prev[i]).length())
				if i < radial._buttons.size() and absf(rad_to_deg(angle_difference(prev[i].angle(), cur[i].angle()))) > SWAP_DEG:
					swaps += 1
		prev = cur
	var tag := "walk from %s" % _side_name(dir)
	print("[t_controls] %s: frames=%d max_step=%.2f px swaps=%d" % [tag, frames, worst, swaps])
	_expect(frames >= 140, "%s: the survivor walked about 2.7 s with the radial open (%d frames)" % [tag, frames])
	_expect(worst <= MAX_STEP, "%s: hexes, title and labels hold against the node (max %.2f px per frame)" % [tag, worst])
	_expect(swaps == 0, "%s: no hex changes side (%d swaps)" % [tag, swaps])

## The held layout gives way only when it runs off the screen: pan the node from the centre to 10 px off
## the left edge; nothing moves against it while there is room, and at the edge every hex is still
## mostly on screen (tappable). Then a 3 px jiggle there for a second (hysteresis) never re-solves: the
## parts follow the node or hold still on screen, so nothing moves against it by more than the jiggle.
func _edge_case() -> void:
	radial.close()
	player.global_position = Vector3.ZERO
	node.global_position = Vector3.ZERO
	cam._snap()
	cam._target = null  # the test pans the camera itself
	await process_frame
	radial.open_options(node, "Wild Grass", 1, 1.0, _options(), null)
	await process_frame
	await process_frame
	var right := cam.global_basis.x
	var view: Vector2 = radial.get_viewport_rect().size
	var resolves := 0
	var early := 0
	var prev := _parts()
	var px_per_m := view.y / CAM_SIZE
	for f in 120:  # the node slides to 10 px from the left edge over 2 s
		cam.global_position += right * ((view.x * 0.5 - 10.0) / px_per_m / 120.0)
		await process_frame
		var cur := _parts()
		var moved := false
		for i in mini(cur.size(), prev.size()):
			moved = moved or (cur[i] - prev[i]).length() > MAX_STEP
		resolves += 1 if moved else 0
		early += 1 if moved and _anchor().x > 400.0 else 0  # the leftmost label ends ~290 px left of the anchor
		prev = cur
	var worst_on := 1.0
	for b in radial._buttons:
		var r := Rect2(b.position, b.size)
		worst_on = minf(worst_on, r.intersection(Rect2(Vector2.ZERO, view)).get_area() / r.get_area())
	print("[t_controls] edge: anchor=%s re-solves=%d (with room: %d) least of a hex on screen=%.2f" % [_anchor(), resolves, early, worst_on])
	_expect(early == 0, "edge: nothing moves against the node while the layout still fits (%d)" % early)
	_expect(resolves >= 1, "edge: the layout gives way once it runs off the screen (%d re-solves)" % resolves)
	_expect(worst_on >= 0.75, "edge: every hex stays at least 3/4 on screen at the edge (%.2f)" % worst_on)
	var held := _parts()
	var worst := 0.0
	for f in 60:
		cam.global_position += right * (3.0 / px_per_m) * (1.0 if f % 2 == 0 else -1.0)
		await process_frame
		var cur := _parts()
		for i in mini(cur.size(), held.size()):
			worst = maxf(worst, (cur[i] - held[i]).length())
	print("[t_controls] edge jiggle: max %.2f px against the node" % worst)
	_expect(worst <= 3.5, "edge: a 3 px jiggle at the edge does not re-solve the layout (max %.2f px)" % worst)

func _side_name(dir: Vector3) -> String:
	var s := cam.unproject_position(dir) - cam.unproject_position(Vector3.ZERO)
	if absf(s.x) >= absf(s.y):
		return "the left" if s.x > 0.0 else "the right"  # the node is right of the survivor: it walks in from the left
	return "above" if s.y > 0.0 else "below"

# ---------------------------------------------------------------- B2: WASD and the floating stick

const SPEED_TOL := 0.05  ## m/s

## The survivor stands on a floor and runs its own physics from here on; the camera follows it again.
func _b2() -> void:
	radial.close()
	var floor := StaticBody3D.new()
	floor.name = "B2Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -0.5
	host.add_child(floor)
	cam._target = player
	player.process_mode = Node.PROCESS_MODE_INHERIT
	await _keys_case()
	await _cancel_case()
	var tc := get_root().get_node("TouchControls")  # the autoload (not a global while this script compiles)
	tc._touch_mode = tc.MODE_TAP_ONLY  # what a phone, the web build or --touch boots in
	tc._apply_mode()
	var stick = tc.joystick
	# By path, not class_name: this script compiles before the autoloads that FloatStick's deps name.
	var floats: bool = stick != null and stick.get_script() == load("res://scripts/ui/float_stick.gd")
	_expect(floats and stick.is_visible_in_tree(), "the touch layer's default tap-only mode carries the floating stick (%s, visible=%s)" % [stick.get_script().resource_path if stick else "none", stick.is_visible_in_tree() if stick else false])
	if floats:
		await _mouse_case()
		await _stick_case(stick)
		await _stick_tap_case(stick)
		await _stick_refusals(stick)
	tc._touch_mode = tc.MODE_HIDDEN
	tc._apply_mode()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _reset_at(pos: Vector3) -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "sprint"]:
		Input.action_release(a)
	player.clear_nav()
	player.actions.cancel_work()
	player.velocity = Vector3.ZERO
	player.global_position = pos + Vector3(0, 1, 0)
	player.vitals.energy = player.vitals.max_energy
	cam._snap()
	await _frames(12)

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _cam_axes() -> Array[Vector3]:
	return [_flat(-cam.global_basis.z).normalized(), _flat(cam.global_basis.x).normalized()]

func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

## Canvas point -> the window point Input wants (the headless window is 64 px, the canvas 1600).
func _win(at: Vector2) -> Vector2:
	return get_root().get_final_transform() * at

func _touch(index: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _win(at)
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _win(at)
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _view() -> Vector2:
	return get_root().get_visible_rect().size

## Keys: each press walks along the camera's ground axes at walk speed; two keys walk the diagonal at
## the same speed; Shift sprints.
func _keys_case() -> void:
	var ax := _cam_axes()
	var fwd: Vector3 = ax[0]
	var right: Vector3 = ax[1]
	var walk: float = player.walk_speed * player.statuses.move_mult()
	var cases := [
		["W", [KEY_W], fwd, walk], ["Up arrow", [KEY_UP], fwd, walk], ["D", [KEY_D], right, walk],
		["Left arrow", [KEY_LEFT], -right, walk], ["S", [KEY_S], -fwd, walk],
		["W+D", [KEY_W, KEY_D], (fwd + right).normalized(), walk],
		["Down+Left arrows", [KEY_DOWN, KEY_LEFT], -(fwd + right).normalized(), walk],
		["Shift+W", [KEY_SHIFT, KEY_W], fwd, player.sprint_speed * player.statuses.move_mult()],
	]
	for c in cases:
		await _reset_at(Vector3.ZERO)
		for k: Key in c[1]:
			_key(k, true)
		await _frames(30)
		var v := _flat(player.velocity)
		for k: Key in c[1]:
			_key(k, false)
		var want: Vector3 = c[2]
		var dot := v.normalized().dot(want) if v.length() > 0.01 else 0.0
		print("[t_controls] keys %s: %.2f m/s, along the camera axis %.4f" % [c[0], v.length(), dot])
		_expect(absf(v.length() - float(c[3])) <= SPEED_TOL and dot > 0.999, "keys %s: %.2f m/s (want %.2f) along the camera's %s (dot %.4f)" % [c[0], v.length(), c[3], "axis", dot])

## A move key drops a tap-to-move path and its ground marker, a gather walk and a craft still walking to its
## station (it used to start the craft once the survivor walked past the bench).
func _cancel_case() -> void:
	await _reset_at(Vector3.ZERO)
	player.nav_to(Vector3(20, 0, 0))
	player.view.show_ground_marker(Vector3(20, 0, 0))
	var hn: Node3D = load("res://scripts/world/harvest_node.gd").new()
	player.gather_target = hn
	var bench := Node3D.new()
	host.add_child(bench)
	bench.global_position = Vector3(-18, 0, 0)
	var sc = player.station_craft
	sc.station = bench
	sc.recipe_id = &"t_controls_recipe"
	await _frames(3)
	var routed: bool = player.nav_active
	_key(KEY_A, true)
	await _frames(2)
	_key(KEY_A, false)
	var marker: Node3D = player.view._ground_marker
	print("[t_controls] move key: nav=%s marker=%s gather=%s craft pending=%s" % [player.nav_active, marker.visible if marker else false, player.gather_target != null, sc.recipe_id])
	_expect(routed and not player.nav_active and not (marker and marker.visible), "a move key drops a tap-to-move path and its marker")
	_expect(player.gather_target == null, "a move key drops a gather walk")
	_expect(sc.recipe_id == &"", "a move key drops a craft still walking to its station (pending %s)" % sc.recipe_id)
	sc.station = null
	bench.queue_free()
	hn.free()

## A desktop click on the left half (where the stick lives) still walks there.
func _mouse_case() -> void:
	await _reset_at(Vector3.ZERO)
	var at := cam.unproject_position(player.feet_position() - _cam_axes()[1] * 6.0)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = _win(at)
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await _frames(2)
	var walking: bool = player.nav_active
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	print("[t_controls] mouse click at %s (left half %s): nav=%s" % [at, at.x < _view().x * 0.5, walking])
	_expect(at.x < _view().x * 0.5 and walking, "a mouse click on the left half still walks there")

## Press on the left half, drag: the stick floats up centred on the press after the dead zone, walks at
## part deflection, clamps the knob and sprints at the rim, and goes away on release with the survivor
## stopping. The press never reached the tap path.
func _stick_case(stick) -> void:
	await _reset_at(Vector3.ZERO)
	var view := _view()
	var press := Vector2(view.x * 0.22, view.y * 0.62)
	var right: Vector3 = _cam_axes()[1]
	_touch(0, press, true)
	await _frames(3)
	var tapped: bool = player.nav_active
	_drag(0, press + Vector2(8, 0))
	await _frames(2)
	var early: bool = stick.active
	var still := _flat(player.velocity).length()
	_drag(0, press + Vector2(36, 0))
	await _frames(30)
	var v := _flat(player.velocity)
	var centred: bool = stick.active and stick._origin.distance_to(press) < 0.5
	var walk_ok := absf(v.length() - player.walk_speed * player.statuses.move_mult()) <= SPEED_TOL and v.normalized().dot(right) > 0.999
	var sprint_part := Input.is_action_pressed("sprint")
	_drag(0, press + Vector2(400, 0))
	await _frames(30)
	var knob: float = stick.vector.length()
	var vr := _flat(player.velocity)
	var run_ok := absf(vr.length() - player.sprint_speed * player.statuses.move_mult()) <= SPEED_TOL and vr.normalized().dot(right) > 0.999
	_touch(0, press + Vector2(400, 0), false)
	await _frames(30)
	var after := _flat(player.velocity).length()
	print("[t_controls] stick: tapped at press=%s active at 8 px=%s (moved %.2f m/s) centred=%s walk %.2f m/s sprint held=%s rim knob=%.3f run %.2f m/s after release active=%s %.2f m/s nav=%s" % [tapped, early, still, centred, v.length(), sprint_part, knob, vr.length(), stick.active, after, player.nav_active])
	_expect(not tapped, "stick: the left-half press does not reach the tap path")
	_expect(not early and still < 0.01, "stick: nothing within the %.0f px dead zone" % stick.DEAD_ZONE_PX)
	_expect(centred, "stick: past the dead zone it floats up centred on the press")
	_expect(walk_ok and not sprint_part, "stick: part deflection walks to camera-right at walk speed (%.2f m/s)" % v.length())
	_expect(knob <= 1.0001 and run_ok, "stick: the knob clamps to its radius (%.3f) and the rim sprints (%.2f m/s)" % [knob, vr.length()])
	_expect(not stick.active and after < 0.01 and Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO and not player.nav_active, "stick: release hides it, stops the survivor and taps nothing")

## A short tap on the left half (no drag past the dead zone) still taps: here it walks to the ground point.
func _stick_tap_case(stick) -> void:
	await _reset_at(Vector3.ZERO)
	var at := cam.unproject_position(player.feet_position() - _cam_axes()[1] * 6.0)
	_touch(0, at, true)
	await _frames(3)
	var early: bool = player.nav_active
	_drag(0, at + Vector2(5, 3))
	_touch(0, at + Vector2(5, 3), false)
	await _frames(3)
	print("[t_controls] stick tap at %s: walking at press=%s after release=%s stick=%s" % [at, early, player.nav_active, stick.active])
	_expect(not early and player.nav_active and not stick.active, "stick: a short tap on the left half still taps (walks there on release)")

## The right half keeps its role (tap at the press), a HUD control keeps its touch, a pinch is not a stick,
## placing buildings keeps the drag, and the base stays inside the screen when the finger lands at the edge.
func _stick_refusals(stick) -> void:
	var view := _view()
	await _reset_at(Vector3.ZERO)
	var rp := cam.unproject_position(player.feet_position() + _cam_axes()[1] * 6.0)
	_touch(0, rp, true)
	await _frames(2)
	var tapped: bool = player.nav_active
	_drag(0, rp + Vector2(60, 0))
	await _frames(2)
	var right_stick: bool = stick.active
	_touch(0, rp + Vector2(60, 0), false)
	_expect(rp.x > view.x * 0.5 and tapped and not right_stick, "right half: a press still taps there and a drag floats no stick")
	# A HUD control on the left half.
	await _reset_at(Vector3.ZERO)
	var hud := CanvasLayer.new()
	host.add_child(hud)
	var btn := Button.new()
	btn.position = Vector2(view.x * 0.1, view.y * 0.3)
	btn.size = Vector2(120, 120)
	hud.add_child(btn)
	await process_frame
	var on := btn.position + Vector2(60, 60)
	_touch(0, on, true)
	_drag(0, on + Vector2(50, 0))
	await _frames(3)
	var hud_stick: bool = stick.active
	var hud_move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_touch(0, on + Vector2(50, 0), false)
	hud.queue_free()
	_expect(not hud_stick and hud_move == Vector2.ZERO and not player.nav_active, "a press on a HUD control on the left half floats no stick and taps nothing")
	# Pinch: two fingers land together on the left half.
	await _reset_at(Vector3.ZERO)
	var a := Vector2(view.x * 0.2, view.y * 0.5)
	_touch(0, a, true)
	_touch(1, a + Vector2(120, 40), true)
	_drag(0, a - Vector2(60, 0))
	_drag(1, a + Vector2(180, 40))
	await _frames(3)
	var pinch_stick: bool = stick.active
	_touch(0, a - Vector2(60, 0), false)
	_touch(1, a + Vector2(180, 40), false)
	_expect(not pinch_stick, "a two-finger pinch on the left half floats no stick")
	# Arranging buildings drags them, not the survivor.
	await _reset_at(Vector3.ZERO)
	player.placer.layout_mode = true
	_touch(0, a, true)
	_drag(0, a + Vector2(60, 0))
	await _frames(3)
	var busy_stick: bool = stick.active
	_touch(0, a + Vector2(60, 0), false)
	player.placer.layout_mode = false
	_expect(not busy_stick, "arranging buildings: a left-half drag floats no stick")
	# Safe area: the base stays whole on screen for a press in the bottom-left corner.
	await _reset_at(Vector3.ZERO)
	var corner := Vector2(4, view.y - 4)
	_touch(0, corner, true)
	_drag(0, corner + Vector2(30, -30))
	await _frames(2)
	var base := Rect2(stick._origin - Vector2(stick.radius, stick.radius), Vector2(stick.radius, stick.radius) * 2.0)
	var whole := Rect2(Vector2.ZERO, view).encloses(base)
	var moving := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_touch(0, corner + Vector2(30, -30), false)
	print("[t_controls] corner press: base %s on screen=%s, stick input %s" % [base, whole, moving])
	_expect(stick.active == false and whole and moving.x > 0.0 and moving.y < 0.0, "a corner press floats the base whole on screen, deflection from the press")

# ---------------------------------------------------------------- B3: routes on a real island

var _rt: Node3D
var _pathing
var _said: Array = []
var _BG: GDScript  ## BuildGrid by path: `--script` compiles this file before the autoloads it names exist

func _b3() -> void:
	var b2_floor := host.get_node_or_null("B2Floor")
	if b2_floor:
		b2_floor.free()
	_BG = load("res://scripts/world/build_grid.gd")
	var world := get_root().get_node("World")
	world.home_terrain = &"meadow"
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await _frames(20)
	_rt = world.runtime
	_pathing = _rt.get("pathing")
	_expect(_rt != null and _pathing != null and player.get_parent() == _rt and player.sim.use_tile_path(), "B3: the survivor routes on the island's TilePath")
	if _pathing == null:
		return
	# Notices land on a stand-in HUD so the test can read them.
	var hud_script := GDScript.new()
	hud_script.source_code = "extends Node\nvar said: Array = []\nfunc notice(t: String) -> void:\n\tsaid.append(t)\n"
	hud_script.reload()
	var hud := Node.new()
	hud.set_script(hud_script)
	hud.add_to_group("hud")
	host.add_child(hud)
	_said = hud.said
	var block := _open_block(Vector2i(24, 13))
	_expect(block.x != -9999, "B3: an open 24 x 13 block of walkable tiles")
	if block.x == -9999:
		return
	await _b3_straight(block)
	await _b3_drop(block)
	await _b3_fence_side(block)
	await _b3_gate(block)
	await _b3_give_up(block)
	hud.queue_free()

func _tile(c: Vector2i) -> Vector3:
	return _BG.tile_centre(c, _rt)

## Top-left of a block of tiles that are all walkable, nearest the survivor's spawn first.
func _open_block(size: Vector2i) -> Vector2i:
	for r in range(0, 50, 2):
		for z in range(-r, r + 1, 2):
			for x in range(-r, r + 1, 2):
				if maxi(absi(x), absi(z)) != r:
					continue
				var o := Vector2i(x, z + 12)
				var ok := true
				for dz in size.y:
					for dx in size.x:
						if not _pathing.is_walkable(o + Vector2i(dx, dz)):
							ok = false
							break
					if not ok:
						break
				if ok:
					return o
	return Vector2i(-9999, -9999)

func _clear_creatures() -> void:
	for c in get_root().get_tree().get_nodes_in_group("creatures"):
		c.queue_free()

func _stand(c: Vector2i, offset := Vector2.ZERO) -> void:
	_clear_creatures()
	player.clear_nav()
	player.actions.cancel_work()
	var at: Vector3 = _tile(c) + Vector3(offset.x, 0.0, offset.y)
	at.y = _rt.surface_y(at.x, at.z) + 1.0
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.reset_physics_interpolation()
	player.vitals.energy = player.vitals.max_energy
	cam._snap()
	await _frames(6)
	_said.clear()

func _fence(cell: Vector2i, rot: int, kind := &"fence") -> Node3D:
	var grid = _rt.build_grid
	var f = load("res://scripts/world/placed_building.gd").make(kind)
	_rt.add_child(f)
	f.global_transform = grid.placement_transform(kind, cell, rot)
	f.set_grid_pose(cell, rot)
	grid.occupy(f, grid.cells_for(kind, cell, rot))
	return f

## Walks a tap route for up to `limit` s; returns the walk's numbers. `on_frame` runs each frame with t.
func _walk(goal: Vector3, limit: float, watch: Node = null, on_frame := Callable()) -> Dictionary:
	player.controls._walk_to_tile(goal)
	var t := 0.0
	var walked := 0.0
	var turn := 0.0
	var head := INF
	var contact := 0
	var hop := 0.0
	var decel := 0.0
	var crossed_z := -INF
	var prev: Vector3 = player.global_position
	var prev_v := Vector2(player.velocity.x, player.velocity.z)
	while t < limit and player.nav_active:
		await physics_frame
		var dt := 1.0 / float(Engine.physics_ticks_per_second)
		t += dt
		var now: Vector3 = player.global_position
		var step := Vector2(now.x - prev.x, now.z - prev.z).length()
		walked += step
		hop = maxf(hop, step)
		var v := Vector2(player.velocity.x, player.velocity.z)
		decel = maxf(decel, (prev_v.length() - v.length()) / dt)
		if v.length() >= 1.0:
			if head != INF:
				turn += absf(angle_difference(head, v.angle()))
			head = v.angle()
		for k in player.get_slide_collision_count():
			var who: Object = player.get_slide_collision(k).get_collider()
			if watch != null and who == watch:
				contact += 1
			elif watch == null and who is Node and (who as Node).name != "Floor":
				contact += 1
		crossed_z = maxf(crossed_z, -now.z)
		prev = now
		prev_v = v
		if on_frame.is_valid():
			on_frame.call(t)
	return {"t": t, "walked": walked, "deg_m": rad_to_deg(turn) / maxf(walked, 0.01), "contact": contact, "hop": hop,
		"decel": decel, "routed": player.nav_active, "min_z": -crossed_z}

## Open ground: one plan, a straight walk, and she eases off onto the tapped tile instead of sliding past.
func _b3_straight(block: Vector2i) -> void:
	await _stand(block + Vector2i(1, 6))
	var goal := _tile(block + Vector2i(19, 6))
	var plans := [0]
	var last_pts := [PackedVector3Array()]
	var count := func (_t: float) -> void:
		var pts: PackedVector3Array = player.sim.path_points()
		if not pts.is_empty() and pts != last_pts[0]:
			plans[0] += 1
			last_pts[0] = pts
	var w := await _walk(goal, 6.0, null, count)
	await _frames(30)
	var off: float = Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length()
	var top: float = player.accel + 1.0
	print("[t_controls] B3 straight: %.2f s walked %.2f m (straight 18.00) deg/m %.2f plans %d, at rest %.2f m from the tile, max decel %.1f m/s2" % [w["t"], w["walked"], w["deg_m"], plans[0], off, w["decel"]])
	_expect(not w["routed"] and w["walked"] <= 18.0 * 1.03 and w["deg_m"] <= 2.0, "B3: an open 18 m tap route is walked straight (%.2f m, %.2f deg/m)" % [w["walked"], w["deg_m"]])
	_expect(off <= 0.3, "B3: she stops on the tapped tile, not past it (%.2f m off at rest)" % off)
	_expect(w["decel"] <= top, "B3: she slows no harder than her acceleration (%.1f m/s2)" % w["decel"])

## A fence dropped across the route 4 m ahead: she re-plans at once and never touches it.
func _b3_drop(block: Vector2i) -> void:
	await _stand(block + Vector2i(1, 6))
	var goal := _tile(block + Vector2i(19, 6))
	var fence: Array = [null]
	var drop := func (t: float) -> void:
		if fence[0] == null and t >= 0.3:
			var c: Vector2i = _BG.tile_of(player.global_position) + Vector2i(5, -1)
			fence[0] = _fence(Vector2i(c.x, block.y + 5), 1)  # 1 x 2, across the walk
			var f2 := _fence(Vector2i(c.x, block.y + 7), 1)
			f2.name = "DropFence2"
	var w := await _walk(goal, 8.0, null, drop)
	var arrived: bool = not w["routed"] and Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length() <= 0.5
	print("[t_controls] B3 drop: fence=%s arrived=%s in %.2f s, walked %.2f m, contact frames %d, said %s" % [fence[0] != null, arrived, w["t"], w["walked"], w["contact"], _said])
	_expect(fence[0] != null and arrived and w["contact"] == 0, "B3: a fence dropped across the route ahead is walked around without touching it (%d contact frames)" % w["contact"])
	for f in [fence[0], _rt.get_node_or_null("DropFence2")]:
		if f:
			f.queue_free()
	await _frames(2)

## Pressed against a fence's face (inside its tile row), a tap further along her side walks along her
## side: the route starts on the nearest free tile, not the first one in scan order behind the fence.
func _b3_fence_side(block: Vector2i) -> void:
	var row := block.y + 6
	var f := _fence(Vector2i(block.x + 8, row), 0)
	var f2 := _fence(Vector2i(block.x + 10, row), 0)
	# The fence runs along x through the middle of its row; she stands against its +z face.
	await _stand(Vector2i(block.x + 9, row), Vector2(0.0, 0.1 + 0.36))
	var goal := _tile(Vector2i(block.x + 15, row + 2))
	var w := await _walk(goal, 5.0)
	var arrived: bool = not w["routed"] and Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length() <= 0.5
	var side_ok: bool = w["min_z"] > float(row) + 0.5
	print("[t_controls] B3 fence side: arrived=%s in %.2f s, contact frames %d, nearest z %.2f (fence at %.2f)" % [arrived, w["t"], w["contact"], w["min_z"], float(row) + 0.5])
	_expect(arrived and side_ok and w["contact"] <= 3, "B3: pressed against a fence, a route along her side stays on her side (contact %d frames, z >= %.2f)" % [w["contact"], w["min_z"]])
	f.queue_free()
	f2.queue_free()
	await _frames(2)

## A fence line with a closed gate between her and the goal: she heads round the end, and when the gate
## opens she takes it (an open gate is passable, a closed one is not).
func _b3_gate(block: Vector2i) -> void:
	var col := block.x + 10
	var parts: Array[Node3D] = []
	for z in [block.y, block.y + 2, block.y + 4, block.y + 8, block.y + 10]:
		parts.append(_fence(Vector2i(col, z), 1))
	var gate := _fence(Vector2i(col, block.y + 6), 1, &"gate")
	parts.append(gate)
	await _stand(block + Vector2i(4, 7))
	var goal := _tile(block + Vector2i(16, 7))
	var open := func (t: float) -> void:
		if t >= 0.2 and not gate.get("gate_open"):
			gate.call("set_gate_open", true)
	var w := await _walk(goal, 8.0, gate, open)
	var arrived: bool = not w["routed"] and Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length() <= 0.5
	print("[t_controls] B3 gate: arrived=%s in %.2f s, walked %.2f m (12.00 straight through the gate), gate contact %d" % [arrived, w["t"], w["walked"], w["contact"]])
	_expect(arrived and w["walked"] <= 13.5 and w["contact"] == 0, "B3: an opened gate is used at once (walked %.2f m)" % w["walked"])
	for p_ in parts:
		p_.queue_free()
	await _frames(2)

## A blocker the grid does not know (a wall body with no cells): she re-plans, then gives up within 2 s of
## pushing with a notice, and never hops.
func _b3_give_up(block: Vector2i) -> void:
	await _stand(block + Vector2i(2, 6))
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 3.0, 13.0)
	cs.shape = box
	wall.add_child(cs)
	_rt.add_child(wall)
	var mid := _tile(block + Vector2i(8, 6))
	wall.global_position = Vector3(mid.x, _rt.surface_y(mid.x, mid.z) + 1.0, mid.z)
	var goal := _tile(block + Vector2i(14, 6))
	var first := [-1.0]
	var note := func (t: float) -> void:
		if first[0] < 0.0:
			for k in player.get_slide_collision_count():
				if player.get_slide_collision(k).get_collider() == wall:
					first[0] = t
	var w := await _walk(goal, 8.0, wall, note)
	var pushing: float = w["t"] - first[0] if first[0] >= 0.0 else -1.0
	print("[t_controls] B3 give up: routed after %.2f s=%s, pushed %.2f s, said %s, biggest frame step %.3f m" % [w["t"], w["routed"], pushing, _said, w["hop"]])
	_expect(not w["routed"] and pushing >= 0.0 and pushing <= 2.0 and _said.has("Can't get there."), "B3: a blocker the grid does not know ends the route within 2 s with \"Can't get there.\" (pushed %.2f s)" % pushing)
	_expect(w["hop"] <= player.sprint_speed / 60.0 * 1.25 + 0.05, "B3: no hop while stuck (biggest step %.3f m)" % w["hop"])
	wall.queue_free()
	await _frames(2)
