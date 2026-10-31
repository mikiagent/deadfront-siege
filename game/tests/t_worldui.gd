extends SceneTree
## WORLDUI (owner 2026-10-31): "health bar bug on animals, it is appearing below the animal and i think it
## would be better above the animal and disappearing when you get close (health bar at the top of the
## screen) ... there was also a bug where resources would have a tag fly in and drop on the resource".
## 1. The floating bar's pill sits above the model's top for a compy and a MegaRex, and stays above
##    with the HUD crowding the top of the screen (it slid under the animal before).
## 2. Close up the top target bar shows the animal and its floating bar fades out; walking off brings
##    the floating bar back (with a gap so it does not flicker on the line).
## 3. A resource tag's first visible frame is at its anchored spot (no fly-in from a row it was given
##    while invisible).
## Usage: godot --headless --path game --script res://tests/t_worldui.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
var cam: Camera3D
var player
var hud
var data: Node
var CP: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	CP = load("res://scripts/ui/creature_plates.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_worldui] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	host = Node3D.new()
	host.name = "TWorldUi"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	cam = Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 14, 16)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	await _frames(10)
	await _test_anchor(&"compsognathus", Vector3(4.0, 0, -4.0))
	cam.look_at(Vector3(0, 6, -20))  # a MegaRex is tall: frame its head as the island camera would
	await _test_anchor(&"megarex", Vector3(0, 0, -20.0))
	cam.look_at(Vector3.ZERO)
	_test_never_below()
	var ui_layer := CanvasLayer.new()
	host.add_child(ui_layer)
	hud = (load("res://scripts/ui/hunt_hud.gd") as GDScript).new()
	hud.bind(player)
	ui_layer.add_child(hud)
	await _frames(20)
	await _test_dock()
	await _test_pill_no_flyin()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_worldui] PASS")
		quit(0)
	else:
		print("[t_worldui] FAIL count=%d" % failures.size())
		quit(1)

func _creature(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # the plates under test, not the AI
	return c

func _clear() -> void:
	for c in get_nodes_in_group("creatures"):
		c.free()
	await _frames(3)

## The model's world box (rest pose), the same meshes the plate reads.
func _model_box(c) -> AABB:
	var out := AABB()
	var found := false
	for mi in c.view.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or m.skin == null:  # the body, not the eye trail
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		out = b if not found else out.merge(b)
		found = true
	return out

## 1. The pill's bottom sits HEAD_GAP over the model's top-centre on screen, above the feet and the body.
func _test_anchor(species: StringName, at: Vector3) -> void:
	var plates: Node = CP.new()
	host.add_child(plates)
	var c = _creature(species, at)
	plates.reveal_creature(c, 30.0)  # the MegaRex stands past the 10 m reveal bubble to fit on screen
	# Selected: the full plate (name, nature, HP bar, chips; 114 px budget). The old plate hung 44 px of
	# it under the anchor, into the animal.
	player.controls.selection.select(c)
	await _frames(40)  # the view loads, the plate reveals (wild, within 10 m) and fades in
	var top_local: Vector3 = CP.model_top_local(c)
	_expect(top_local != Vector3.INF, "%s: the plate reads the model's mesh top (%s)" % [species, top_local])
	var mbox := _model_box(c)
	var e: Dictionary = plates._entries.get(c.get_instance_id(), {})
	var pill: Rect2 = CP.pill_rect(e)
	var top_px: Vector2 = cam.unproject_position(plates.plate_anchor(c))
	var feet_px: Vector2 = cam.unproject_position(c.global_position)
	var mid_px: Vector2 = cam.unproject_position(mbox.get_center())
	print("[t_worldui] %s: model top %.2f m (def %.2f m), pill %s, top px %s, mid px %s, feet px %s" % [
		species, top_local.y, c.def.height_meters * c.size_scale(), pill, top_px, mid_px, feet_px])
	_expect(pill.has_area() and (e["node"] as Control).visible, "%s: the floating bar shows" % species)
	_expect(absf(top_local.y - mbox.end.y + c.global_position.y) < 0.05, "%s: the anchor is the model box's top (%.2f vs %.2f)" % [species, top_local.y, mbox.end.y - c.global_position.y])
	_expect(pill.end.y <= top_px.y - CP.HEAD_GAP + 0.5, "%s: the pill's bottom (%.1f) is above the head (%.1f)" % [species, pill.end.y, top_px.y])
	_expect(pill.end.y < mid_px.y and pill.end.y < feet_px.y, "%s: the pill is above the body's middle (%.1f) and the feet (%.1f), never under or inside it" % [species, mid_px.y, feet_px.y])
	_expect(absf(pill.get_center().x - top_px.x) < 2.0, "%s: the pill is centred on the head's top (%.1f vs %.1f)" % [species, pill.get_center().x, top_px.x])
	# Smooth: the anchor is the rest-pose box, so a walking animal's plate does not bob frame to frame.
	var ys: Array[float] = []
	for i in 6:
		await process_frame
		ys.append(CP.pill_rect(plates._entries.get(c.get_instance_id(), {})).end.y)
	_expect(ys.max() - ys.min() < 0.5, "%s: the still animal's plate holds still (%.2f px drift)" % [species, ys.max() - ys.min()])
	player.controls.selection.clear()
	plates.queue_free()
	await _clear()

## 1b. A HUD block over the animal's head: the plate lifts above it or hides; it never drops below.
func _test_never_below() -> void:
	var view := Vector2(1600, 900)
	var pill := Rect2(700, 300, 176, 60)
	var free: Rect2 = CP.lift_spot(pill, [] as Array[Rect2], view)
	_expect(free == pill, "a clear plate stays where it is (%s)" % free)
	var up: Rect2 = CP.lift_spot(pill, [Rect2(0, 340, 1600, 40)] as Array[Rect2], view)
	_expect(up.has_area() and up.end.y <= 340.0 - 2.0, "a block over its lower half: the plate lifts above it (%s)" % up)
	var crowded: Array[Rect2] = [Rect2(0, 0, 1600, 340)]
	var old: Rect2 = load("res://scripts/ui/ui_tokens.gd").free_spot(pill, crowded, view, true)
	var got: Rect2 = CP.lift_spot(pill, crowded, view)
	_expect(old.position.y > pill.position.y, "repro: the old rule dropped the plate below its spot (%s)" % old)
	_expect(not got.has_area(), "no room above: the plate hides rather than drop under the animal (%s)" % got)

## 2. Close: the top bar takes the animal, its floating bar fades; far again: the floating bar is back.
func _test_dock() -> void:
	var plates: Node = CP.new()
	host.add_child(plates)
	var c = _creature(&"zebraceratops", Vector3(3.5, 0, 0))
	await _frames(30)
	var e: Dictionary = plates._entries.get(c.get_instance_id(), {})
	var blocks: Dictionary = hud.get("drawn_blocks")
	_expect(hud.top_target() == c, "close (3.5 m): the top target bar shows the animal (%s)" % [hud.top_target()])
	_expect(blocks.has("plate"), "close: the top target bar is drawn")
	_expect(bool(e.get("docked", false)) and (e["pill"] as Control).modulate.a < 0.05, "close: the floating bar has faded out (dock %.2f)" % float(e.get("dock", -1.0)))
	_expect((e["floats"] as Control).modulate.a > 0.99, "close: damage numbers keep showing over the animal")
	# The gap: 7 m from its edge is past CLOSE_IN but inside CLOSE_OUT, so it stays at the top.
	var HT: GDScript = load("res://scripts/ui/hud_target.gd")
	c.global_position = Vector3(HT.CLOSE_IN + 1.0 + c.body_radius(), 0, 0)
	await _frames(6)
	_expect(hud.top_target() == c, "between the in and out ranges the bar holds (no flicker)")
	c.global_position = Vector3(HT.CLOSE_OUT + 3.0 + c.body_radius(), 0, 0)
	await _frames(30)
	blocks = hud.get("drawn_blocks")
	_expect(hud.top_target() == null and not blocks.has("plate"), "walked off: no top bar (target %s)" % [hud.top_target()])
	_expect(not bool(e.get("docked", true)) and (e["pill"] as Control).modulate.a > 0.95 and (e["node"] as Control).visible, "walked off: the floating bar is back (dock %.2f)" % float(e.get("dock", -1.0)))
	# A big animal is close by its body's edge, not its centre.
	await _clear()
	var rex = _creature(&"megarex", Vector3(0, 0, -(HT.CLOSE_IN - 1.0) - 0.0))
	rex.global_position = Vector3(0, 0, -(rex.body_radius() + HT.CLOSE_IN - 1.0))
	await _frames(10)
	_expect(hud.top_target() == rex, "a MegaRex %.1f m away (%.1f m from its edge) takes the top bar" % [rex.global_position.length(), HT.CLOSE_IN - 1.0])
	await _clear()
	# Landscape phone (the primary target): the close animal takes the centre band, orders collapsed.
	var keep := [get_root().size, get_root().content_scale_size]
	get_root().size = Vector2i(844, 390)
	get_root().content_scale_size = Vector2i(844, 390)
	load("res://scripts/ui/orders_sheet.gd").hud_expanded = false
	var near = _creature(&"zebraceratops", Vector3(3.5, 0, 0))
	await _frames(30)
	var pe: Dictionary = plates._entries.get(near.get_instance_id(), {})
	_expect(hud.top_target() == near and (hud.get("drawn_blocks") as Dictionary).has("plate") and bool(pe.get("docked", false)),
		"phone: a close animal moves to the top band and its floating bar fades (target %s, docked %s)" % [hud.top_target(), pe.get("docked")])
	get_root().size = keep[0]
	get_root().content_scale_size = keep[1]
	await _frames(5)
	plates.queue_free()
	await _clear()

## 3. A resource tag: on its first visible frame it is at its anchored spot, centred over the node's top.
func _test_pill_no_flyin() -> void:
	var HP: GDScript = load("res://scripts/ui/hud_pills.gd")
	var node_scene: PackedScene = load("res://scenes/world/harvest_node.tscn")
	var n = node_scene.instantiate()
	host.add_child(n)
	n.position = Vector3(12.0, 0, 0)  # out of the 8 m label range
	n.setup(&"t_worldui_rock", &"stone", 1, 1, {"level": 1}, &"none", Color.GRAY, 1.2, 8.0, "Rock")
	await _frames(5)
	# Walk in: 8.4 m, 8 m (laid out at alpha 0: the old code kept that row), then closer each frame.
	var first: Dictionary = {}
	var steps := 0
	for d in [8.4, 8.0, 7.9, 7.6, 7.2, 6.8, 6.4, 6.0, 5.6]:
		n.global_position = player.global_position + Vector3(d, -1.0, 0)
		await _frames(2)
		steps += 1
		for row: Dictionary in HP.last_drawn:
			if row["node"] == n and float(row.get("a", 0.0)) > 0.02:
				first = row
				break
		if not first.is_empty():
			break
	_expect(not first.is_empty(), "the rock's tag shows walking in (%d steps)" % steps)
	if not first.is_empty():
		var r: Rect2 = first["rect"]
		var at: Vector2 = first["anchor"]
		print("[t_worldui] tag first visible frame: rect %s, laid out %s, anchor %s, alpha %.2f" % [r, first["laid"], at, float(first["a"])])
		_expect(r == first["laid"], "first visible frame: the tag is at its laid-out spot, not gliding in (%s vs %s)" % [r.position, (first["laid"] as Rect2).position])
		_expect(absf(r.get_center().x - at.x) < 1.0 and absf(r.end.y - at.y) < 1.0, "first visible frame: the tag sits on the rock's top (bottom-centre %s, anchor %s)" % [Vector2(r.get_center().x, r.end.y), at])
		_expect(float(first["a"]) < 0.9, "it fades in gently (alpha %.2f on its first frame)" % float(first["a"]))
		var top_px: Vector2 = cam.unproject_position(n.global_position + Vector3(0, n.top_of_node() + 0.35, 0))
		_expect(at.distance_to(top_px) < 1.0, "its anchor is the rock's top (%s vs %s)" % [at, top_px])
	n.queue_free()
	await _frames(2)
