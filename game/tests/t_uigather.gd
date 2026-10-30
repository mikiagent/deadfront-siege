extends SceneTree
## UIGATHER acceptance (docs/design/ui-redesign-spec.md §4, §6, §7 B1/B2), on the home island at 1600x900
## and 844x390: a harvest pill is tappable and opens the hex radial on its node; the gather hexes are
## 124 px on desktop and 64 on a phone, on screen and clear of each other and of the labels; the picked
## hex pie-fills while the others lock; a gather started without the fan opens it running; a gain shows
## the top-middle gain row (rare chip first, green tier, on screen) and an XP line in the left feed; the NET hex is gold only
## inside the capture window (spec 09).
## Usage: godot --headless --path game --script res://tests/t_uigather.gd -> "[t_uigather] PASS", exit 0/1.

const GOLD := Color(0.957, 0.769, 0.188, 1.0)  ## UiTokens.GOLD (game classes load after this script compiles)

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _rt: Node
var _world: Node

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
	print("[t_uigather] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TUigatherHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("quick_row_y"):
			_hud = c
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = _world.runtime
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # held where the test puts her
	for id in [&"work_pick", &"work_axe", &"stone_knife"]:
		_player.inventory.add(load("res://scripts/items/item_stack.gd").make(id, 1))
	for size in [Vector2i(1600, 900), Vector2i(844, 390)]:
		root.size = size
		root.content_scale_size = size
		await _frames(3)
		await _test_radial(Vector2(size))
	await _test_yield_card()
	await _test_net()
	if _fails.is_empty():
		print("[t_uigather] PASS")
		quit(0)
	else:
		print("[t_uigather] FAIL count=%d" % _fails.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _node():
	var best = null
	var bd := INF
	for n in _player.get_tree().get_nodes_in_group("harvest"):
		if n.options().size() < 2 or not n.has_harvests_left():
			continue
		var d: float = n.global_position.distance_to(_player.global_position)
		if d < bd:
			bd = d
			best = n
	return best

func _test_radial(view: Vector2) -> void:
	var tag := "%dx%d" % [int(view.x), int(view.y)]
	var node = _node()
	_expect(node != null, "%s: a multi-option node is near" % tag)
	if node == null:
		return
	var at: Vector3 = node.global_position + Vector3(-3.0, 0.0, 1.5)
	_player.global_position = Vector3(at.x, _rt.surface_y(at.x, at.z) + 1.0, at.z)
	var radial = _player._gather_radial
	radial.close()
	await _frames(4)
	# A tap on the node's pill, through the HUD's input, opens the fan on that node.
	var pill := Rect2()
	for d: Dictionary in load("res://scripts/ui/hud_pills.gd").hit_pills:
		if d["node"] == node:
			pill = d["rect"]
	_expect(pill.has_area(), "%s: the node has a tappable pill" % tag)
	if pill.has_area():
		_expect(pill.size.y >= (30.0 if view.y > 500 else 22.0), "%s: the pill is the spec's dark box (%s)" % [tag, pill])
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = pill.get_center()
		_hud._input(ev)
	await _frames(3)
	_expect(radial.is_open() and radial.node == node, "%s: a pill tap opens the radial on its node" % tag)
	if not radial.is_open():
		return
	var want := 124.0 if view.y > 500 else 64.0
	var screen := Rect2(Vector2.ZERO, view)
	var hexes: Array[Rect2] = []
	for b in radial._buttons:
		hexes.append(b.hex_rect())
		_expect(is_equal_approx(b.size.x, want) and b.size.x >= 64.0, "%s: gather hex %.0f px (want %.0f)" % [tag, b.size.x, want])
		_expect(b.icon_grey, "%s: the resource symbol is greyed" % tag)
		_expect(screen.encloses(b.hex_rect()), "%s: hex on screen (%s)" % [tag, b.hex_rect()])
	for i in hexes.size():
		for j in range(i + 1, hexes.size()):
			_expect(not hexes[i].grow(-1.0).intersects(hexes[j]), "%s: hexes %d and %d do not overlap" % [tag, i, j])
		for l in radial.label_rects:
			_expect(not l.intersects(hexes[i].grow(-2.0)), "%s: no label sits on hex %d (%s on %s)" % [tag, i, l, hexes[i]])
	for l in radial.label_rects:
		_expect(screen.encloses(l), "%s: label on screen (%s)" % [tag, l])
	# Pick: the pressed hex pie-fills, the others lock.
	var pick := -1
	for i in radial._buttons.size():
		if not radial._buttons[i].disabled:
			pick = i
			break
	_expect(pick >= 0, "%s: an option is open" % tag)
	if pick < 0:
		return
	radial._on_pick(pick)
	radial.set_progress(0.5)
	_expect(is_equal_approx(radial._buttons[pick].fill_ratio, 0.5), "%s: the running hex pie-fills (%.2f)" % [tag, radial._buttons[pick].fill_ratio])
	for i in radial._buttons.size():
		if i != pick:
			_expect(radial._buttons[i].disabled, "%s: hex %d locks while one runs" % [tag, i])
	radial.close()
	_player.actions.stop_gather_cycle(false)
	# A gather that starts without the fan opens it with its option running (the hex replaces the ring).
	node.select_option(1)
	_player.gather_target = node
	_player.actions._update_gather_ring(0.3)
	_expect(radial.is_open() and radial.active_index == 1 and is_equal_approx(radial._buttons[1].fill_ratio, 0.3),
		"%s: a fan-less gather opens the radial running option 1 (open %s, active %d)" % [tag, radial.is_open(), radial.active_index])
	_expect(not _player._gather_ring.visible, "%s: the floating gather ring stays hidden for a harvest node" % tag)
	radial.close()
	_player.gather_target = null

func _test_yield_card() -> void:
	# Owner 2026-10-28: the gain shows in the top-middle column (TopFeed), which retired the per-node
	# yield card; a rare trait makes it the green tier, its chip first.
	var view := Vector2(1600, 900)
	root.size = Vector2i(view)
	root.content_scale_size = Vector2i(view)
	await _frames(2)
	var Stack = load("res://scripts/items/item_stack.gd")
	var feed = _hud.get("top_feed")
	feed.clear()
	feed.sync(_player)
	var stack = Stack.make(&"branch", 1, {"level": 2, "split_easily": true})
	_player.inventory.add(stack)
	_player.gather_target = _node()
	_hud.toast(&"branch", 1)
	var rows: Array = feed.rows
	var chips: Array = rows[0].get("chips", []) if not rows.is_empty() else []
	_expect(rows.size() == 1 and not chips.is_empty() and chips[0][1] == &"rare", "the gain's rare trait is the first chip (%s)" % [chips])
	_expect(not rows.is_empty() and rows[0]["tier"] == &"green", "a rare trait makes the gain the green tier (%s)" % [rows[0].get("tier") if not rows.is_empty() else "none"])
	_hud.get("_events").add_skill_xp("gathering", 5.0, 1)
	_hud.queue_redraw()
	await _frames(3)
	var card: Rect2 = _hud.drawn_blocks.get("toast0", Rect2())
	_expect(card.has_area() and Rect2(Vector2.ZERO, view).encloses(card) and card.end.y < view.y * 0.5 and absf(card.get_center().x - view.x * 0.5) < 2.0, "the gain row is drawn at the top middle (%s)" % card)
	_expect(card.size.x == 380.0, "the row is 380 px wide on desktop (%s)" % card.size.x)
	var feed_row: Rect2 = _hud.drawn_blocks.get("skilltoast0", Rect2())
	# LAYOUT (owner 2026-10-30: "the skill XP + player XP UI lower, above EAT"): bottom-left, over the
	# quick-food row, climbing upwards from it.
	var quick_y: float = _hud.quick_row_y()
	_expect(feed_row.has_area() and feed_row.end.x < view.x * 0.35 and feed_row.end.y <= quick_y + 0.5 and feed_row.position.y > view.y * 0.4, "the XP line stands bottom-left over the EAT row (%s, quick row %.0f)" % [feed_row, quick_y])
	_expect(not feed_row.intersects(card), "the XP line and the gain row do not overlap")
	feed.clear()
	_player.gather_target = null

func _test_net() -> void:
	var sp = load("res://scripts/world/spawner.gd").new()
	sp.species = &"zebraceratops"
	sp.count = 1
	sp.radius = 0.5
	sp.as_pack = false
	sp.position = _player.global_position + Vector3(4.0, 0, 2.0)
	_rt.add_child(sp)
	var made: Array = sp.spawn_now()
	_expect(not made.is_empty(), "zebraceratops spawned")
	if made.is_empty():
		return
	var z = made[0]
	z.process_mode = Node.PROCESS_MODE_DISABLED
	_player.inventory.add(load("res://scripts/items/item_stack.gd").make(&"capture_net_i", 1))
	root.get_node("Data").set_survival_unlocked(&"capture_technique_I", true)
	z.health.hp = z.health.max_hp * 0.6
	_player.hunt.start(z)
	_player.hunt.auto = false
	_hud._process(0.1)
	var net = _hud._skill_hexes[0]
	_expect(net.visible and net.fill != GOLD, "NET is not gold at 60 %")
	_expect(net.bottom_text == "", "NET leaves its bottom line free for the taming odds")
	z.health.hp = z.health.max_hp * 0.25
	_hud._process(0.1)
	_expect(net.fill != GOLD, "FOODTORPOR: NET is not gold at 25 % with no torpor")
	z.torpor = z.torpor_max()  # knocked out = weak + torpor past the threshold
	_hud._process(0.1)
	_expect(not net.disabled and net.fill == GOLD and net.rim_color == GOLD, "NET turns gold at 25 % once sedated")
	_player.hunt.stop()
	z.queue_free()
