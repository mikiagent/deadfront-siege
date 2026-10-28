extends SceneTree
## LOOTRADIAL acceptance, on the home island at 1600x900 and 844x390: a carcass's name pill and its
## interact open the gather radial on it with one hex per carcass part; a locked part is red (⊘ badge,
## its reason on the label) and refuses; picking a part runs the cut with the hex's pie fill, the part
## lands in the bag and on the top-middle gain feed; the cut budget on the title drops by one, and at 0
## every part left locks.
## Usage: godot --headless --path game --script res://tests/t_lootradial.gd -> "[t_lootradial] PASS", exit 0/1.
## Windowed with `-- --shots=<dir>` it also saves the fan open and mid-cut at both sizes.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _rt: Node
var _shots := ""
var CP: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_lootradial] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots = a.substr(8)
	CP = load("res://scripts/gather/carcass_parts.gd")
	_host = Node3D.new()
	_host.name = "TLootradialHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("hands_spot"):
			_hud = c
	root.get_node("World").load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = root.get_node("World").runtime
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # held where the test puts her
	_player.inventory.add(load("res://scripts/items/item_stack.gd").make(&"stone_knife_work", 1, {"material_tier": "flint"}, 1))
	for size in [Vector2i(1600, 900), Vector2i(844, 390)]:
		root.size = size
		root.content_scale_size = size
		if _shots != "":
			DisplayServer.window_set_size(size)
		await _frames(3)
		await _test_carcass(Vector2(size))
	if _fails.is_empty():
		print("[t_lootradial] PASS")
		quit(0)
	else:
		print("[t_lootradial] FAIL count=%d" % _fails.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## A rolled triceratops carcass beside the survivor, with a 2-cut budget.
func _carcass(at: Vector3):
	var c = load("res://scripts/creatures/corpse.gd").new()
	c.species = &"triceratops"
	c.level = 3
	load("res://scripts/gather/butcher_loot.gd").roll_into(c)
	c.apply_cut_state(2, 2, [])
	c.position = at
	_host.add_child(c)
	return c

func _shot(name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_shots, name])
	print("[t_lootradial] shot %s %s" % [name, img.get_size()])

func _test_carcass(view: Vector2) -> void:
	var tag := "%dx%d" % [int(view.x), int(view.y)]
	var radial = _player._gather_radial
	radial.close()
	var here: Vector3 = Vector3(2.0, 0.0, 22.0)
	var y: float = _rt.surface_y(here.x, here.z)
	_player.global_position = Vector3(here.x, y + 1.0, here.z)
	_player.velocity = Vector3.ZERO
	var c = _carcass(Vector3(here.x + 1.2, y, here.z - 1.2))
	await _frames(6)
	var parts: int = CP.parts(&"triceratops").size()
	# The carcass's name pill, tapped through the HUD's input, opens the fan on it.
	var pill := Rect2()
	for d: Dictionary in load("res://scripts/ui/hud_pills.gd").hit_pills:
		if d["node"] == c:
			pill = d["rect"]
	_expect(pill.has_area(), "%s: the carcass has a tappable name pill" % tag)
	if pill.has_area():
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = pill.get_center()
		_hud._input(ev)
		await _frames(3)
		_expect(radial.is_open() and radial.node == c, "%s: a pill tap opens the radial on the carcass" % tag)
	# The interact opens it too (the Butcher action and a tap on the body end here).
	radial.close()
	c.open_loot(_player)
	await _frames(3)
	_expect(radial.is_open() and radial.node == c, "%s: the carcass interact opens the gather radial" % tag)
	if not radial.is_open():
		c.free()
		return
	_expect(radial._buttons.size() == parts, "%s: one hex per carcass part (%d of %d)" % [tag, radial._buttons.size(), parts])
	var want := 124.0 if view.y > 500 else 64.0
	var screen := Rect2(Vector2.ZERO, view)
	for b in radial._buttons:
		_expect(is_equal_approx(b.size.x, want), "%s: part hex %.0f px (want %.0f)" % [tag, b.size.x, want])
		_expect(screen.encloses(b.hex_rect()), "%s: hex on screen (%s)" % [tag, b.hex_rect()])
		_expect(b.top_text == "%.1fs" % CP.cut_seconds(c.cut_context(_player)), "%s: seconds per cut on top (%s)" % [tag, b.top_text])
	await _frames(30)  # the held layout settles
	var clash := []
	for i in radial.label_rects.size():
		for j in range(i + 1, radial.label_rects.size()):
			if radial.label_rects[i].intersects(radial.label_rects[j]):
				clash.append("%d/%d %s %s" % [i, j, radial.label_rects[i], radial.label_rects[j]])
		for b in radial._buttons:
			if radial.label_rects[i].intersects(b.hex_rect().grow(-2.0)):
				clash.append("label %d on a hex" % i)
	_expect(clash.is_empty(), "%s: no part label overlaps another label or a hex (%s)" % [tag, clash])
	_expect(radial._sub_line().ends_with("2 cuts left"), "%s: the title shows the budget (%s)" % [tag, radial._sub_line()])
	var by_id := {}
	for i in radial.options.size():
		by_id[str(radial.options[i]["item"])] = i
	# Units left at the bottom of each hex.
	var meat: int = by_id.get("raw_meat", -1)
	_expect(meat >= 0 and radial._buttons[meat].bottom_text == str(c.loot.count_of(&"raw_meat")), "%s: units left at the bottom (%s)" % [tag, radial._buttons[meat].bottom_text if meat >= 0 else "no meat hex"])
	# A rare part carries the gold star.
	var rare_ok := true
	for i in radial.options.size():
		if radial.options[i]["rare"] and not radial._buttons[i].disabled:
			rare_ok = rare_ok and radial._buttons[i].badge == "★"
	_expect(rare_ok, "%s: an open rare part is marked" % tag)
	# The locked part: red ⊘, its reason on the label, and a pick refuses.
	var scute: int = by_id.get("armor_scute", -1)
	_expect(scute >= 0 and radial._buttons[scute].disabled and radial._buttons[scute].badge == "⊘" and str(radial._labels[scute]["reason"]) != "",
		"%s: the locked part is red with its reason (%s)" % [tag, radial._labels[scute]["reason"] if scute >= 0 else "no hex"])
	if scute >= 0:
		_player.actions.on_option_picked(c, scute)
		_expect(not c.cut_running and c.cuts_left == 2, "%s: the locked part refuses (running %s, cuts %d)" % [tag, c.cut_running, c.cuts_left])
	await _shot("lootradial_%s_open" % tag)
	# Pick the meat: the hex pie-fills on the carcass's cut clock, the others lock.
	var feed = _hud.get("top_feed")
	feed.clear()
	var bag_meat: int = _player.inventory.count_of(&"raw_meat")
	radial._on_pick(meat)
	await _frames(1)
	_expect(c.cut_running and c.cutting_part() == &"raw_meat", "%s: picking the hex starts the cut" % tag)
	var t := 0
	while c.cut_running and c.cut_progress() < 0.5 and t < 200:
		await process_frame
		t += 1
	var fill: float = radial._buttons[meat].fill_ratio
	_expect(fill > 0.0 and fill < 1.0, "%s: the picked hex pie-fills mid-cut (%.2f)" % [tag, fill])
	var locked := true
	for i in radial._buttons.size():
		if i != meat:
			locked = locked and radial._buttons[i].disabled
	_expect(locked, "%s: the other hexes lock while the cut runs" % tag)
	await _shot("lootradial_%s_midcut" % tag)
	t = 0
	while c.cut_running and t < 400:
		await process_frame
		t += 1
	_expect(_player.inventory.count_of(&"raw_meat") == bag_meat + 1, "%s: the cut put exactly one part in the bag" % tag)
	var fed := false
	for r: Dictionary in feed.rows:
		fed = fed or (r["kind"] == &"gain" and r["id"] == &"raw_meat")
	_expect(fed, "%s: the cut shows in the top-middle gain feed" % tag)
	_expect(c.cuts_left == 1 and radial._sub_line().ends_with("1 cut left"), "%s: the budget drops to 1 (%s)" % [tag, radial._sub_line()])
	_expect(radial.is_open() and radial.active_index == -1 and is_zero_approx(radial._buttons[meat].fill_ratio), "%s: the fan stays open and frees up after the cut" % tag)
	_expect(radial._buttons[meat].disabled and str(radial._labels[meat]["reason"]) == "already cut", "%s: the cut part locks as already cut" % tag)
	# Spend the last cut: every part left locks with "no cuts left".
	var next := -1
	for i in radial._buttons.size():
		if not radial._buttons[i].disabled:
			next = i
			break
	_expect(next >= 0, "%s: another part is open to cut" % tag)
	if next >= 0:
		radial._on_pick(next)
		t = 0
		await process_frame
		while c.cut_running and t < 400:
			await process_frame
			t += 1
		var all_locked := true
		for i in radial._buttons.size():
			all_locked = all_locked and radial._buttons[i].disabled
		_expect(c.cuts_left == 0 and all_locked, "%s: at 0 cuts every part locks (cuts %d)" % [tag, c.cuts_left])
		var reason_ok := false  # a part still on the carcass says no cuts left (an empty one: nothing left)
		for i in radial._buttons.size():
			reason_ok = reason_ok or str(radial._labels[i]["reason"]) == "no cuts left"
		_expect(reason_ok and radial._sub_line().ends_with("No cuts left"), "%s: the rest say no cuts left (%s)" % [tag, radial._sub_line()])
	radial.close()
	c.free()
	await _frames(2)
