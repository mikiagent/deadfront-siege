extends SceneTree
## CONTROLS acceptance (docs/orchestration/reports/claude-mmo-controls.md).
## B1: the gather radial solves its layout when it opens and holds it against its node while the camera
## follows the survivor's walk (it re-solved every frame against the survivor's nameplate, so the hexes,
## the title and the labels jumped sides: owner "UI glitching up and down on resource nodes"); it solves
## again only when the held layout runs off the screen, and a jiggle at that edge does not flip it back.
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
