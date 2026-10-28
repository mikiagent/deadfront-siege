extends SceneTree
## UIANIMALS: E1 Animals, F2 World Atlas and the Harbour sheet at the desktop gate (1600x900) and the
## landscape phone (844x390). Each opens; its controls are 64 px tap targets inside the view; panels
## do not overlap; E1 shows 3 of 7 pack slots with the locked range, the NatureChip directly under
## the name and the waiting-to-bond list; selecting a card moves the gold selection; the atlas zoom
## steps; the Harbour lists route cards whose locked Sail buttons are disabled.
## Usage: godot --headless --path game --script res://tests/t_uianimals.gd

const SIZES := [Vector2i(1600, 900), Vector2i(844, 390)]

var failures: Array[String] = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return false  # _run is a coroutine and quits itself; true here would end the run early
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	_run()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var data := get_root().get_node("Data")
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(p)
	var PR: GDScript = load("res://scripts/pets/pet_record.gd")
	var rex: RefCounted = PR.from_def(data.creature(&"velociraptor"))
	rex.name = "Rex"
	rex.nature = &"timid"
	p.bonded.append(rex)
	p.bonded.append(PR.from_def(data.creature(&"zebraceratops")))
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	p.inventory.add(IS.make(&"captured_animal", 1, {"species": "velociraptor"}))
	var layer := CanvasLayer.new()
	get_root().add_child(layer)
	var screen: Control = (load("res://scripts/ui/animal_screen.gd") as GDScript).new()
	layer.add_child(screen)
	for sz in SIZES:
		get_root().size = sz
		get_root().content_scale_size = sz  # the logical canvas (as DisplayMode.fit sets it on a phone)
		await _frames(2)
		await _animals(screen, p, Vector2(sz))
	screen.close_screen()
	for sz in SIZES:
		get_root().size = sz
		get_root().content_scale_size = sz  # the logical canvas (as DisplayMode.fit sets it on a phone)
		await _frames(2)
		await _atlas(p, Vector2(sz))
		await _harbour(Vector2(sz))
	if failures.is_empty():
		print("[t_uianimals] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_uianimals] FAIL %s" % f)
		quit(1)

func _inside(c: Control, view: Vector2) -> bool:
	return Rect2(Vector2.ZERO, view).grow(0.5).encloses(c.get_global_rect())

func _tap(c: Control, tag: String) -> void:
	var r := c.get_global_rect()
	_expect(r.size.y >= 64.0 - 0.5 and r.size.x >= 64.0 - 0.5, "%s is a 64 px target (%s)" % [tag, r.size])

func _animals(screen: Control, p: Node, view: Vector2) -> void:
	var tag := "E1 %dx%d" % [view.x, view.y]
	screen.open(p, p.bonded[0])
	await _frames(3)
	_expect(screen.visible, "%s opens" % tag)
	var panels: Array[Control] = [screen.get("_left"), screen.get("_centre"), screen.get("_right")]
	for i in panels.size():
		_expect(_inside(panels[i], view), "%s panel %s on screen (%s)" % [tag, panels[i].name, panels[i].get_global_rect()])
		for j in range(i + 1, panels.size()):
			_expect(not panels[i].get_global_rect().intersects(panels[j].get_global_rect()), "%s %s and %s do not overlap" % [tag, panels[i].name, panels[j].name])
	var chrome: Control = screen.get("chrome")
	for n in ["Back", "Close"]:
		var b := chrome.get_node(n) as Control
		_tap(b, "%s %s" % [tag, n])
		_expect(_inside(b, view), "%s %s on screen" % [tag, n])
	for n in ["_feed", "_ride", "_summon", "_release"]:
		var b := screen.get(n) as Button
		_tap(b, "%s %s" % [tag, n])
		_expect(_inside(b, view) and panels[2].get_global_rect().grow(0.5).encloses(b.get_global_rect()), "%s %s inside the stats panel" % [tag, n])
	_expect((screen.get("_release") as Button).disabled, "%s Release stays disabled (no bond-breaking in code)" % tag)
	_expect(str((screen.get("_bonded") as Label).text).contains("2 / 3") and str((screen.get("_bonded") as Label).text).contains("7"), "%s header shows bonded / cap and the 7 ceiling ('%s')" % [tag, (screen.get("_bonded") as Label).text])
	# pack slots: 2 cards, 1 empty, the 4-7 locked range, then the captured raptor waiting to bond
	var list: Control = screen.get("_list")
	var texts: PackedStringArray = []
	for l in list.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var joined := " | ".join(texts)
	_expect(joined.contains("Empty slot") and joined.contains("4 – 7 · locked"), "%s shows the empty slot and locked 4-7 (%s)" % [tag, joined])
	_expect(joined.contains("Waiting to bond") and joined.contains("Velociraptor · captured"), "%s lists the captured animal as waiting to bond" % tag)
	var cards: Array = screen.get("_cards")
	_expect(cards.size() == 2, "%s has one card per bonded pet (%d)" % [tag, cards.size()])
	for c in cards:
		_expect((c as Control).size.y >= 64.0, "%s card %s is >= 64 px tall" % [tag, (c as Control).name])
	var info := (cards[0] as Control).find_child("Info", true, false)
	var nm := info.get_node("Name") as Label
	var chip := info.get_node("NatureChip") as Control
	_expect(nm.text == "Rex" and chip.visible and chip.get_index() == nm.get_index() + 1, "%s NatureChip directly under the name" % tag)
	_expect(chip.get_global_rect().position.y >= nm.get_global_rect().position.y, "%s chip sits below the name's top" % tag)
	var dchip := screen.get("_detail_chip") as Control
	var dname := screen.get("_detail_name") as Control
	_expect(dchip.visible and dchip.get_global_rect().position.y >= dname.get_global_rect().end.y - 1.0, "%s detail chip under the detail name" % tag)
	# primary action: select the second card
	(cards[1] as Button).pressed.emit()
	await _frames(2)
	cards = screen.get("_cards")
	_expect(int(screen.get("selected")) == 1 and bool((cards[1] as Control).get("selected")) and not bool((cards[0] as Control).get("selected")), "%s tapping a card selects it" % tag)
	(cards[0] as Button).pressed.emit()
	await _frames(1)

func _hud_stub() -> Node:
	var hud := get_root().get_node_or_null("HudStub")
	if hud:
		return hud
	var src := GDScript.new()
	src.source_code = "extends Node\nfunc map_texture() -> ImageTexture:\n\treturn null\nfunc notice(_t: String) -> void:\n\tpass\n"
	src.reload()
	hud = src.new()
	hud.name = "HudStub"
	get_root().add_child(hud)
	return hud

func _atlas(p: Node, view: Vector2) -> void:
	var tag := "F2 %dx%d" % [view.x, view.y]
	var layer := CanvasLayer.new()
	get_root().add_child(layer)
	var map: Control = (load("res://scripts/ui/map_screen.gd") as GDScript).new()
	map.player = p
	layer.add_child(map)
	map.open()
	await _frames(3)
	_expect(map.is_open(), "%s opens" % tag)
	var close := map.get("_close") as Control
	_tap(close, "%s close" % tag)
	_expect(_inside(close, view), "%s close on screen" % tag)
	var zoom := map.get_node("ZoomRow") as Control
	for b in zoom.get_children():
		if b is Button:
			_tap(b, "%s zoom %s" % [tag, (b as Button).text])
	_expect(_inside(zoom, view), "%s zoom row on screen (%s)" % [tag, zoom.get_global_rect()])
	var row := map.get("_btn_row") as Control
	var harbour: Button = null
	for b in row.get_children():
		if b is Button and (b as Button).text == "Harbour routes":
			harbour = b
	_expect(harbour != null, "%s has Harbour routes" % tag)
	if harbour:
		_tap(harbour, "%s Harbour routes" % tag)
		_expect(_inside(harbour, view) and not harbour.get_global_rect().intersects(zoom.get_global_rect()), "%s Harbour routes on screen, clear of zoom" % tag)
	var panel := map.get("_panel") as Control
	var legend: Rect2 = map.legend_rect(view)
	var square: Rect2 = map.call("_map_rect", map.call("_layout"))
	_expect(not panel.get_global_rect().intersects(legend), "%s legend clear of the island column" % tag)
	_expect(not square.intersects(legend) and not square.intersects(panel.get_global_rect()), "%s map square clear of the column and legend (%s)" % [tag, square])
	_expect(Rect2(Vector2.ZERO, view).encloses(legend) and not legend.intersects(close.get_global_rect()), "%s legend on screen and under the close" % tag)
	var cards := map.get("_cards") as Control
	_expect(cards.get_child_count() >= 2, "%s lists the islands (%d)" % [tag, cards.get_child_count()])
	var first := cards.get_child(0) as Control
	_expect(first != null and bool(first.get("selected")), "%s the first (current) island card is selected" % tag)
	if cards.get_child_count() >= 2:
		(cards.get_child(1) as Button).pressed.emit()
		await _frames(2)
		_expect(cards.get_child_count() >= 2, "%s cards rebuilt" % tag)
		var sel := 0
		for c in cards.get_children():
			if bool(c.get("selected")) and not c.is_queued_for_deletion():
				sel += 1
		_expect(sel == 1, "%s exactly one selected card after a tap (%d)" % [tag, sel])
	var z0 := float(map.get("_zoom"))
	((zoom.get_child(2)) as Button).pressed.emit()
	_expect(is_equal_approx(float(map.get("_zoom")), z0 + 0.25), "%s + zooms in" % tag)
	map.close()
	layer.queue_free()
	await _frames(1)

func _harbour(view: Vector2) -> void:
	var tag := "Harbour %dx%d" % [view.x, view.y]
	var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(get_root())
	await _frames(1)
	ui.show_harbour()
	await _frames(3)
	var grid := ui.find_child("RouteGrid", true, false) as GridContainer
	_expect(grid != null and grid.columns == (3 if view.y < 500.0 else 4), "%s route grid (%s columns)" % [tag, grid.columns if grid else -1])
	var routes := 0
	var locked := 0
	for b in ui.find_children("*", "Button", true, false):
		if str(b.get_meta("route_id", "")) == "":
			continue
		routes += 1
		_tap(b, "%s %s" % [tag, b.get_meta("route_id")])
		_expect(b.get_global_rect().position.x >= 0.0 and b.get_global_rect().end.x <= view.x + 0.5, "%s %s inside the width" % [tag, b.get_meta("route_id")])
		if (b as Button).disabled:
			locked += 1
	_expect(routes >= get_root().get_node("World").harbour_routes().size() - 1, "%s one Sail button per route (%d)" % [tag, routes])
	_expect(locked > 0, "%s a fresh survivor's high routes are locked (%d)" % [tag, locked])
	var stretched := 0
	for c in grid.get_children() if grid else []:
		if (c as Control).size.x > view.x * 0.5:
			stretched += 1
	_expect(stretched == 0, "%s no full-width rows" % tag)
	ui.hide_all()
	await _frames(1)
