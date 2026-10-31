extends SceneTree
## UIWORLD screens (docs/design/ui-redesign-spec.md §7 F1, F3, E2): Domain, Communication, Radio
## University and the Taming Pen, opened through their HuntHud entry points on a real island at
## 844x390 and 1600x900. Each screen: opens, its key controls exist, every visible button is >= 64 px,
## inside the view and overlaps no other button, and its primary action works (Declare starts the
## ground preview and a held domain shows the plot grid; Radio University opens and Back returns;
## Tame puts the PICKED captured animal into the pen and the screen switches to the timer).
## Run: Godot --headless --path game --script res://tests/t_uiworld.gd -> "[t_uiworld] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const TARGET := 64.0

var _fails: PackedStringArray = []
var _ran := false
var _host: Node3D
var _player: Node
var _hud: Node
var _world: Node
var IC: GDScript
var BG: GDScript
var IS: GDScript
var TP: GDScript

func _process(_delta: float) -> bool:
	if _ran or root.get_node_or_null("Data") == null:
		return false
	_ran = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_uiworld] FAIL %s" % what)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	IC = load("res://scripts/world/island_claims.gd")
	BG = load("res://scripts/world/build_grid.gd")
	IS = load("res://scripts/items/item_stack.gd")
	TP = load("res://scripts/world/taming_pen.gd")
	_host = Node3D.new()
	_host.name = "TUiWorldHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 20.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("open_comms"):
			_hud = c
	_world = root.get_node("World")
	_world.set("home_terrain", &"meadow")
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	var kit_floor := _host.get_node_or_null("Floor")
	if kit_floor:
		kit_floor.free()
	await _frames(2)
	_expect(_hud != null, "the lab HUD has the UIWORLD entry points (open_comms)")
	if _hud == null:
		_done()
		return
	for view in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = view
		root.content_scale_size = view
		await _frames(2)
		await _test_domain(Vector2(view))
		await _test_comms(Vector2(view))
		await _test_pen(Vector2(view))
	_done()

func _done() -> void:
	if _fails.is_empty():
		print("[t_uiworld] PASS")
		quit(0)
	else:
		print("[t_uiworld] FAIL count=%d" % _fails.size())
		quit(1)

## Every visible button under `screen`: >= 64 px both ways, inside the view, no overlap. A button
## in a ScrollContainer is measured by the part its scroll shows (the rest scrolls into view).
func _check_targets(tag: String, screen: Node, view: Vector2) -> void:
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	var bounds := Rect2(Vector2.ZERO, view).grow(0.5)
	for n in screen.find_children("*", "Button", true, false):
		var b := n as Button
		if not b.is_visible_in_tree():
			continue
		var r := b.get_global_rect()
		_expect(r.size.x >= TARGET and r.size.y >= TARGET, "%s %s: %s is under %.0f px (%s)" % [tag, view, b.name, TARGET, r.size])
		var scroll := _scroll_of(b)
		if scroll != null:
			_expect(bounds.encloses(scroll.get_global_rect()), "%s %s: %s's scroll sits outside the view" % [tag, view, b.name])
			r = r.intersection(scroll.get_global_rect())
			if r.size.x < 1.0 or r.size.y < 1.0:
				continue
		else:
			_expect(bounds.encloses(r), "%s %s: %s sits outside the view (%s)" % [tag, view, b.name, r])
		for i in rects.size():
			_expect(not rects[i].grow(-0.5).intersects(r.grow(-0.5)), "%s %s: %s overlaps %s" % [tag, view, b.name, names[i]])
		rects.append(r)
		names.append(str(b.name))
	_expect(not rects.is_empty(), "%s %s: no visible buttons" % [tag, view])
	print("[t_uiworld] %s %s buttons=%d" % [tag, view, rects.size()])

static func _scroll_of(n: Node) -> ScrollContainer:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null

func _btn(screen: Node, node_name: String) -> Button:
	return screen.find_child(node_name, true, false) as Button

# ---------------------------------------------------------------- F1 Domain

func _test_domain(view: Vector2) -> void:
	var rt: Node = _world.get("runtime")
	IC.clear_domain(rt)
	var dom: Node = _hud.call("open_domain")
	await _frames(3)
	_expect(dom != null and dom.call("is_open"), "%s: open_domain() opens the Domain screen" % view)
	if dom == null:
		return
	_expect((dom.get("_tab_buttons") as Dictionary).size() == 4, "four territory tabs")
	var declare := _btn(dom, "Declare")
	_expect(declare != null and declare.is_visible_in_tree() and not declare.disabled, "%s: no domain yet -> a live Declare Domain button" % view)
	_expect(not dom.call("showing_plots"), "no domain yet -> no plot grid")
	_check_targets("domain_declare", dom, view)
	# Declare opens the ground preview; the sheet steps aside to Confirm / Cancel.
	declare.pressed.emit()
	await _frames(3)
	_expect(dom.call("is_previewing"), "%s: Declare starts the ground preview" % view)
	_expect(_btn(dom, "Confirm").is_visible_in_tree() and _btn(dom, "Cancel").is_visible_in_tree(), "the preview shows Confirm and Cancel")
	_expect(not (dom.get("header") as Control).visible, "the sheet's header steps aside during the preview")
	_check_targets("domain_preview", dom, view)
	_btn(dom, "Cancel").pressed.emit()
	await _frames(3)
	_expect(not dom.call("is_previewing"), "Cancel ends the preview")
	# A held domain: the plot grid view.
	var cells: Array = IC.eligible_cells(rt, IC.cell_of(rt, BG.tile_of(_player.global_position)), 4)
	var want: Array = []
	for c in cells:
		if want.is_empty() or IC.adjacent_to(c, _as_set(want)):
			want.append(c)
		if want.size() >= 3:
			break
	var out: Dictionary = IC.claim_cells(rt, want)
	_expect(bool(out.get("ok", false)), "the test claims three plots (%s)" % [out])
	dom.call("select_tab", "tamed_island")
	await _frames(3)
	_expect(dom.call("showing_plots"), "%s: a held domain shows the plot grid" % view)
	var states: Dictionary = (dom.get("_grid") as Object).call("states")
	var gold := 0
	for c in states.keys():
		if int(states[c]) == 0:
			gold += 1
	_expect(gold == want.size(), "the grid draws every domain plot GOLD (%d of %d)" % [gold, want.size()])
	_expect(states.size() == 49, "the grid is 7 x 7 (%d)" % states.size())
	_expect(_btn(dom, "Expand").is_visible_in_tree() and _btn(dom, "Center").is_visible_in_tree(), "Expand and the Communications Center link show")
	_check_targets("domain_plots", dom, view)
	dom.call("select_tab", "outpost")
	await _frames(2)
	_expect(not dom.call("showing_plots") and str((dom.get("_headline") as Label).text).contains("Outpost"), "the Outpost tab says it is a later phase")
	_check_targets("domain_outpost", dom, view)
	(dom.get("close_btn") as Button).pressed.emit()
	_expect(not dom.call("is_open"), "✕ closes the Domain screen")
	IC.clear_domain(rt)

static func _as_set(a: Array) -> Dictionary:
	var d := {}
	for c in a:
		d[c] = true
	return d

# ---------------------------------------------------------------- F3 Communication

func _test_comms(view: Vector2) -> void:
	var comms: Node = _hud.call("open_comms")
	await _frames(3)
	_expect(comms != null and comms.call("is_open"), "%s: open_comms() opens Factions" % view)
	if comms == null:
		return
	comms.call("select", "company")
	await _frames(2)
	var rows := comms.find_children("Faction_*", "Button", true, false)
	_expect(rows.size() == 5, "five factions from factions.json (%d)" % rows.size())
	var accepts := comms.find_children("Accept", "Button", true, false)
	_expect(accepts.size() == 3, "three mission offers for the Company (%d)" % accepts.size())
	for a in accepts:
		_expect(not (a as Button).disabled, "FACTIONS: Accept is live for the Company (unlocked at the tutorial)")
	_expect(str((comms.get("counter") as RichTextLabel).get_parsed_text()).contains("0 / 4"), "the header counts active missions out of 4")
	_check_targets("comms", comms, view)
	comms.call("select", "committee")
	await _frames(2)
	var sub := comms.find_child("Faction_committee", true, false).find_child("Sub", true, false) as Label
	_expect(sub.text.begins_with("Locked"), "the Committee reads Locked below level 20 (%s)" % sub.text)
	comms.call("select", "radio_university")
	await _frames(2)
	var go := _btn(comms, "OpenRadio")
	_expect(go != null and go.is_visible_in_tree(), "Radio University's detail offers its own screen")
	go.pressed.emit()
	await _frames(3)
	var radio: Node = comms.get("radio")
	_expect(radio != null and radio.call("is_open") and not comms.call("is_open"), "Radio University opens as a separate screen")
	if radio != null:
		_expect(radio.find_children("Guide_*", "", true, false).size() == 7, "seven career guides from data")
		_check_targets("radio", radio, view)
		(radio.get("back_btn") as Button).pressed.emit()
		await _frames(2)
		_expect(not radio.call("is_open") and comms.call("is_open"), "Back on Radio University returns to Communication")
	(comms.get("close_btn") as Button).pressed.emit()
	_expect(not comms.call("is_open"), "✕ closes Communication")

# ---------------------------------------------------------------- E2 Taming pen

func _test_pen(view: Vector2) -> void:
	var pen = TP.make()
	_host.add_child(pen)
	pen.global_position = _player.global_position + Vector3(3, 0, 0)
	var inv = _player.get("inventory")
	inv.add(IS.make(&"captured_animal", 1, {"species": "zebraceratops", "level": 13, "nature": "docile"}))
	inv.add(IS.make(&"captured_animal", 1, {"species": "velociraptor", "level": 9}))
	(_player.get("actions") as Object).call("pen_interact", pen)
	await _frames(3)
	var ui: Node = (_hud.get("_world_sheets") as Dictionary).get(&"pen")
	_expect(ui != null and ui.call("is_open"), "%s: pen_interact opens the Taming Pen screen" % view)
	if ui == null:
		pen.queue_free()
		return
	_expect(not pen.running, "opening the screen starts nothing")
	_expect(_btn(ui, "Tame").is_visible_in_tree() and _btn(ui, "Store").is_visible_in_tree(), "tame-or-store: Tame and Store show")
	var filled := 0
	for c in ui.find_children("Cell*", "Button", true, false):
		if (c as Button).icon != null:
			filled += 1
	_expect(filled == 2, "the pen grid shows both captured animals (%d)" % filled)
	_check_targets("pen", ui, view)
	ui.call("_on_cell", 1)  # pick the raptor
	_btn(ui, "Tame").pressed.emit()
	await _frames(2)
	_expect(pen.running and pen.occupant != null and str(pen.occupant.attributes.get("species", "")) == "velociraptor", "Tame puts the PICKED animal in the pen (%s)" % [pen.occupant.attributes if pen.occupant else "none"])
	_expect(inv.count_of(&"captured_animal") == 1, "one captured animal left in the bag")
	_expect(_btn(ui, "OK").is_visible_in_tree() and not _btn(ui, "Tame").is_visible_in_tree(), "the screen switches to the timer (OK, no Tame)")
	_expect(str((ui.get("_q") as Label).text).begins_with("Taming started"), "the header reads Taming started")
	_check_targets("pen_started", ui, view)
	_btn(ui, "OK").pressed.emit()
	_expect(not ui.call("is_open"), "OK closes the screen")
	inv.consume(&"captured_animal", inv.count_of(&"captured_animal"))
	pen.occupant = null
	pen.running = false
	pen.queue_free()
	await _frames(1)
