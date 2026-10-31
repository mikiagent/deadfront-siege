extends SceneTree
## TUTTOWN menu guidance (owner 2026-10-29: "it points to a menu and doesn't tell you where to
## scroll"): every tutorial order that sends the player into a menu names its taps under "menu", and
## the shared guide (Tutorial.guide) can ring each one in turn. For every such order and every path,
## at 1600x900 and 844x390, on the tutorial island: the pointer names element i, the test taps it
## the way a player would, and the pointer moves on to element i+1. A target inside a list is
## scrolled into view (inside its ScrollContainer, no scroll cue). A wrong tab open blocks the entry
## (the pointer asks for the tab first), a list scrolled away shows the cue. The hint names the tab
## and the entry. The Craft / Build order: Materials first, Tool and Weapon together, All last, Build
## at the very bottom of the list page.
## Run: Godot --headless --path game --script res://tests/t_tutguide.gd -> "[t_tutguide] PASS".

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _p
var _hud
var W: Node
var _size := Vector2i.ZERO
var TUT: GDScript
var IS: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	create_timer(400.0).timeout.connect(func () -> void:
		print("[t_tutguide] FAIL watchdog")
		quit(2))
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_tutguide] %s %dx%d %s" % ["ok" if ok else "FAIL", _size.x, _size.y, what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	W = root.get_node("World")
	TUT = load("res://scripts/core/tutorial.gd")
	IS = load("res://scripts/items/item_stack.gd")
	_host = Node3D.new()
	_host.name = "TTutguideHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_p = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("taken_rects"):
			_hud = c
	(kit["nav"] as Node).queue_free()
	W.load_island(_host, &"tutorial_isle", Vector3(0, 1, 0), false)
	W.tutorial = {"done": false, "did": {}}
	await _frames(3)
	_p.process_mode = Node.PROCESS_MODE_DISABLED
	_p.skills.sp_extra = 5
	_test_order()
	for s in [Vector2i(1600, 900), Vector2i(844, 390)]:
		_size = s
		root.size = s
		root.content_scale_size = s
		await _frames(3)
		if s.x == 1600:
			await _test_pointer_glides()  # needs a sized viewport (the camera unprojects)
		var steps: Array = TUT.call("steps")
		for i in steps.size():
			var step: Dictionary = steps[i]
			if not step.has("menu"):
				continue
			W.objective = i
			var alts: Array = step["menu"]
			for a in alts.size():
				await _walk_path(step, alts, a)
		await _test_gate_and_cue(steps)
	if _fails.is_empty():
		print("[t_tutguide] PASS")
		quit(0)
	else:
		print("[t_tutguide] FAILED %d: %s" % [_fails.size(), "; ".join(_fails)])
		quit(1)

## The pointer eases (owner 2026-10-29: it jumped): a jump of the target is covered in bounded steps,
## it settles on a still target, keeps up with a moving one, and follows a world node every frame.
func _test_pointer_glides() -> void:
	var tps: GDScript = load("res://scripts/ui/tutorial_pointer.gd")
	var tp = tps.new()
	root.add_child(tp)
	tp.set_process(false)
	var box := Control.new()
	box.size = Vector2(64, 64)
	box.position = Vector2(100, 100)
	root.add_child(box)
	await _frames(1)
	var dt := 1.0 / 60.0
	var cap: float = float(tps.get_script_constant_map()["MAX_PX_S"]) * dt + 0.01
	tp.set_target({"ui": box})
	tp.step(dt)
	box.position = Vector2(900, 600)  # the target changes: no teleport
	var worst := 0.0
	for i in 90:
		tp.step(dt)
		worst = maxf(worst, tp.last_step)
	var settle: float = (tp.pos as Vector2).distance_to(box.get_global_rect().get_center())
	_expect(worst <= cap and worst > 1.0 and settle < 2.0, "the pointer glides to a new target: max step %.1f px/frame (cap %.1f), settles %.2f px off" % [worst, cap, settle])
	var lag := 0.0
	for i in 120:
		box.position += Vector2(4, 1)  # 240 px/s
		tp.step(dt)
		lag = (tp.pos as Vector2).distance_to(box.get_global_rect().get_center())
	_expect(lag < 30.0, "the pointer keeps up with a moving target (%.1f px behind)" % lag)
	var mover := Node3D.new()
	root.add_child(mover)
	var t := {"world": Vector3.ZERO, "node": mover}
	var before: Vector3 = tps.call("world_anchor", t)
	mover.position = Vector3(2, 0, 0)
	_expect((tps.call("world_anchor", t) as Vector3).distance_to(before) > 1.9, "a world target that moves is followed every frame (its node is read, not the picked spot)")
	for n in [tp, box, mover]:
		n.queue_free()
	await _frames(1)

## Craft / Build: Materials first, the tools together, All last; Build is the bottom row of the list page.
func _test_order() -> void:
	var cats: Array = (load("res://scripts/ui/craft_ui.gd") as GDScript).get_script_constant_map()["CATEGORIES"]
	var keys: Array = cats.map(func (r: Array) -> String: return str(r[0]))
	_expect(keys[0] == "processing" and str(cats[0][1]) == "Materials", "Materials is the first tab (%s)" % [keys])
	_expect(absi(keys.find("tool") - keys.find("weapon")) == 1, "Tool and Weapon sit together")
	_expect(keys[-1] == "", "All is the last tab")
	var craft = _p.craft_ui
	craft.toggle()
	var foot: Node = craft.find_child("CraftFootRow", true, false)
	var mid: Node = craft.find_child("CraftMid", true, false)
	var build: Node = craft.find_child("BuildRow", true, false)
	_expect(build != null and build.get_parent() == foot and foot.get_parent() == mid and foot.get_index() == mid.get_child_count() - 1,
		"Build is the very bottom row of Craft / Build")
	craft.hide_ui()

func _reset() -> void:
	_p.craft_ui.hide_ui()
	_p.craft_ui._category = ""  # every path starts on All, so its tab tap is exercised
	if _p.ui.visible:
		_p.controls.toggle_inventory()
	_hud._close_sheet()
	if _p.station_craft and _p.station_craft.menu:
		_p.station_craft.menu.visible = false
	for s in _hud.get("_world_sheets").values():
		if is_instance_valid(s):
			s.visible = false
	if _hud.get("_skills_sheet") and is_instance_valid(_hud._skills_sheet):
		_hud._skills_sheet.visible = false

func _bag(items: Dictionary) -> void:
	var inv = _p.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	for id in items:
		inv.add(IS.call("make", StringName(id), int(items[id])))
	inv.changed.emit()

## Play one path: the pointer must name element k, then the test taps it.
func _walk_path(step: Dictionary, alts: Array, a: int) -> void:
	var path: Array = (alts[a] as Array).duplicate()
	var sid := str(step.get("id", ""))
	var items := {"branch": 6, "stone": 4, "fibre_stalk": 10, "twine": 3, "berries": 3, "herb_leaf": 2, "raw_meat": 2, "herb_buff_meal": 1}
	var head := str(path[0])
	if head.begins_with("have:"):
		items[head.substr(5)] = 1
		path.remove_at(0)
	for b in a:  # an earlier alternative's have: item would win: leave it out
		var h := str((alts[b] as Array)[0])
		if h.begins_with("have:"):
			items.erase(h.substr(5))
	if path.size() == 1 and str(path[0]).begins_with("harvest:"):
		_bag(items)
		var g: Dictionary = TUT.call("guide", _p, step)
		_expect(g.has("world") and int(g.get("index", -1)) == 0, "%s: without the item it points at %s" % [sid, path[0]])
		return
	_reset()
	_bag(items)
	if sid == "tut_cook":
		var pit := _station(&"stone_fire_pit")
		_p.global_position = pit.global_position + Vector3(1.5, 0.5, 0)
		pit.call("load_wood", _p)
	await _frames(2)
	var k := 0
	while k < path.size():
		var el := str(path[k])
		var g: Dictionary = TUT.call("guide", _p, step)
		await _frames(1)
		g = TUT.call("guide", _p, step)
		var at := int(g.get("index", -1))
		if at > k and _skipped_ok(path, k, at):
			print("[t_tutguide] %s: %s already chosen, the pointer goes on to %s" % [sid, path[k], path[at]])
			k = at
			el = str(path[k])
		_expect(at == k, "%s path %d: the pointer names %s (got %s)" % [sid, a, el, str(path[at]) if at >= 0 else "nothing"])
		if at != k:
			return
		if g.has("ui"):
			var c: Control = g["ui"]
			var sc = g.get("scroll")
			var inside: bool = sc == null or (sc as ScrollContainer).get_global_rect().grow(1.0).encloses(c.get_global_rect())
			_expect(c.is_visible_in_tree() and inside and int(g.get("cue", 0)) == 0 and str(g.get("caption", "")).begins_with("Tap "),
				"%s: %s is on screen%s (%s; row %s list %s)" % [sid, el, " and scrolled into its list" if sc else "", g.get("caption", ""), c.get_global_rect(), (sc as ScrollContainer).get_global_rect() if sc else Rect2()])
		if k == path.size() - 1:
			break  # the last tap would do the order itself
		await _tap(el, g)
		await _frames(3)
		k += 1
	_reset()

## Elements the pointer may skip: a tab, skill or recipe that is already the chosen one.
func _skipped_ok(path: Array, from: int, to: int) -> bool:
	for j in range(from, to):
		var c: Node = null
		for r in [_hud, _p.craft_ui, _p.ui]:
			c = r.find_child(str(path[j]), true, false) if c == null else c
		if str(path[j]) == "skill:buyable":
			for n in _hud.find_children("Skill_*", "Button", true, false):
				if n.find_child("Unread", true, false) != null:
					c = n
					break
		if c == null or not bool(c.get_meta(&"tut_chosen", false)):
			return false
	return true

func _station(kind: StringName) -> Node3D:
	for n in get_nodes_in_group("bonfire") + get_nodes_in_group("craft_station"):
		if n.get("kind") == kind or n.get("station_id") == kind:
			return n
	return null

func _tap(el: String, g: Dictionary) -> void:
	if el.begins_with("world:"):
		var st := _station(&"workbench") if el == "world:bench" else _station(&"stone_fire_pit")
		_p.global_position = st.global_position + Vector3(1.5, 0.5, 0)
		_p.open_station_craft(st)
		return
	var c: Control = g["ui"]
	if el.begins_with("bag:"):
		_p.ui._on_bag_slot_tapped(int(c.get("index")))
		return
	c.emit_signal("pressed")

## A wrong tab blocks the entry: the pointer asks for the tab. A list scrolled away shows the cue.
func _test_gate_and_cue(steps: Array) -> void:
	for i in steps.size():
		if str((steps[i] as Dictionary).get("id", "")) == "tut_build":
			W.objective = i
			var step: Dictionary = steps[i]
			_reset()
			_bag({"fibre_stalk": 6, "twine": 2})
			var craft = _p.craft_ui
			craft.toggle()
			craft._pick_category("weapon")
			await _frames(2)
			var g: Dictionary = TUT.call("guide", _p, step)
			_expect(g.has("ui") and (g["ui"] as Control).name == "Cat_construction", "a wrong tab open: the pointer asks for Building Components")
			craft._pick_category("")
			await _frames(2)
			g = TUT.call("guide", _p, step)
			_expect(g.has("ui") and (g["ui"] as Control).name == "Cat_construction", "All open: the pointer still asks for the tab, not the row")
			craft._pick_category("construction")
			await _frames(2)
			g = TUT.call("guide", _p, step)
			var sc := craft.find_child("RecipeScroll", true, false) as ScrollContainer
			sc.scroll_vertical = 0 if g.has("ui") and (g["ui"] as Control).get_global_rect().position.y > sc.get_global_rect().get_center().y else 100000
			await _frames(3)
			g = TUT.call("guide", _p, step)
			var row: Control = g.get("ui")
			var out := row != null and not sc.get_global_rect().grow(1.0).encloses(row.get_global_rect())
			_expect(not out or int(g.get("cue", 0)) != 0, "the row scrolled away: a scroll cue (%d), not a ring" % int(g.get("cue", 0)))
			var hint := str(step.get("hint", ""))
			_expect(hint.contains("Building Components") and hint.contains("Straw Roll") and hint.contains("Build"), "the hint names the tab, the entry and Build: %s" % hint)
			_reset()
	for s in steps:
		var st: Dictionary = s
		if not st.has("menu"):
			continue
		for alt in st["menu"]:
			for el in alt:
				var e := str(el)
				if e.begins_with("Cat_"):
					var label := ""
					for r in (load("res://scripts/ui/craft_ui.gd") as GDScript).get_script_constant_map()["CATEGORIES"]:
						if "Cat_" + (str(r[0]) if str(r[0]) != "" else "all") == e:
							label = str(r[1])
					_expect(label != "" and str(st.get("hint", "")).contains(label), "%s: the hint names the %s tab" % [st.get("id"), label])
