extends SceneTree
## UICRAFT acceptance (docs/design/ui-redesign-spec.md §7 D1 / D2 / D3) at 1600x900 and 844x390, on the
## home island:
##   D1 craft stations: header ‹ / Build / ✕, station chooser, category grid, grouped recipe list and the
##      detail; every tap target >= 64 px, the panes inside the view and apart; Craft starts the craft.
##   D3 place materials: one chevron per slot, completion %, candidates with order badges; Place
##      material fills slot by slot (OK_GREEN), then Craft starts the craft with the placed instance
##      leading its slot (StationCraft._pick_uids).
##   D2 build mode: the drawer's tier tabs and hex tiles (>= 64 px), a tile starts the ghost with the
##      drawer still open, the HUD's ROTATE (icon only) / SAVE (OK_GREEN) / CANCEL row keeps off the drawer.
## Usage: godot --headless --path game --script res://tests/t_uicraft.gd -> "[t_uicraft] PASS", exit 0/1.

const OK_GREEN := Color(0.373, 0.827, 0.416, 1.0)  ## UiTokens.OK_GREEN (classes load after this compiles)

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _world: Node
var _size := Vector2i.ZERO

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	root.get_tree().create_timer(150.0).timeout.connect(func () -> void:
		print("[t_uicraft] FAIL watchdog: the run did not finish in 150 s")
		quit(1))
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_uicraft] %s %dx%d %s" % ["ok" if ok else "FAIL", _size.x, _size.y, what])

func _run() -> void:
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TUicraftHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("taken_rects"):
			_hud = c
	_world.home_claims = []
	_world.unstable_claims = []
	_world.free_claim_used = false
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	for s in [Vector2i(1600, 900), Vector2i(844, 390)]:
		_size = s
		root.size = s
		root.content_scale_size = s
		await _frames(3)
		await _test_d1()
		await _test_d3()
		await _test_d2()
	if _fails.is_empty():
		print("[t_uicraft] PASS")
		quit(0)
	else:
		print("[t_uicraft] FAIL count=%d" % _fails.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _view() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_size))

func _bag(items: Array) -> void:
	var inv = _player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	for row in items:
		inv.add(load("res://scripts/items/item_stack.gd").make(StringName(row[0]), 1, row[2] if row.size() > 2 else {}, int(row[1])))
	inv.changed.emit()

## Every visible Button, LineEdit and hex under `root_node` is at least 64 px each way.
func _taps_ok(root_node: Node, what: String) -> void:
	var small: Array[String] = []
	var n := 0
	for c in root_node.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not (ctl is BaseButton or ctl is LineEdit or ctl.is_in_group(&"hex_button")) or not ctl.is_visible_in_tree():
			continue
		n += 1
		if ctl.size.y < 63.5 or ctl.size.x < 63.5:
			small.append("%s %s" % [ctl.name, ctl.size])
	_expect(n > 0 and small.is_empty(), "%s: %d tap targets, all >= 64 px (%s)" % [what, n, small])

func _in_view(rects: Dictionary, what: String) -> void:
	var out: Array[String] = []
	for k in rects:
		if not _view().grow(0.5).encloses(rects[k]):
			out.append("%s %s" % [k, rects[k]])
	_expect(out.is_empty(), "%s: inside the view (%s)" % [what, out])

func _apart(rects: Dictionary, what: String) -> void:
	var hits: Array[String] = []
	var keys := rects.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if (rects[keys[i]] as Rect2).grow(-1.0).intersects((rects[keys[j]] as Rect2).grow(-1.0)):
				hits.append("%s x %s" % [keys[i], keys[j]])
	_expect(hits.is_empty(), "%s: no overlaps (%s)" % [what, hits])

# ---------------------------------------------------------------- D1

func _test_d1() -> void:
	_bag([["stone", 6], ["branch", 8, {"firm": 2}], ["twine", 10], ["twine", 12], ["fibre_stalk", 3], ["fibre_stalk", 4]])
	var craft = _player.craft_ui
	craft._station = ""
	craft._category = ""
	craft.show_ui()
	await _frames(3)
	var hb: Control = craft.find_child("CraftHeader", true, false)
	var left: Control = craft.find_child("CraftLeft", true, false)
	var mid: Control = craft.find_child("CraftMid", true, false)
	var right: Control = craft.find_child("CraftRight", true, false)
	_expect(craft.find_child("Station_hand", true, false) != null and craft.find_child("Station_workbench", true, false) != null, "D1: station chooser lists By hand and Workbench")
	_expect(craft.find_child("Cat_all", true, false) != null and craft.find_child("Cat_weapon_tools", true, false) != null, "D1: category grid has All and Weapons & Tools")
	var groups: Array = craft._list.get_children().filter(func (n: Node) -> bool: return str(n.name).begins_with("Group_"))
	_expect(groups.size() >= 2, "D1: the recipe list is grouped (%d groups)" % groups.size())
	var odds: Label = craft.find_child("DetailOdds", true, false)
	_expect(odds != null and odds.text.count("%") == 2 and odds.text.count("·") == 2, "D1: detail shows time · success · flawless (%s)" % (odds.text if odds else "none"))
	_taps_ok(craft, "D1")
	var one: Control = craft.find_child("CraftOne", true, false)
	var five: Control = craft.find_child("CraftFive", true, false)
	var rects := {"header": Rect2(hb.global_position, hb.size), "left": left.get_global_rect(), "mid": mid.get_global_rect(), "right": right.get_global_rect()}
	_in_view(rects.merged({"craft": one.get_global_rect(), "craft5": five.get_global_rect()}), "D1 panes and Craft buttons")
	_apart(rects, "D1 header and columns")
	for n in ["CraftBack", "CraftClose", "BuildRow"]:
		var c: Control = craft.find_child(n, true, false)
		_expect(c != null and c.is_visible_in_tree() and Rect2(hb.global_position, hb.size).encloses(c.get_global_rect()), "D1: %s sits in the header" % n)
	# Labels in the detail stay inside its column (nothing spills over the right edge).
	var spill: Array[String] = []
	for l in craft._detail.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.is_visible_in_tree() and lab.get_global_rect().end.x > right.get_global_rect().end.x + 0.5:
			spill.append(lab.name)
	_expect(spill.is_empty(), "D1: detail text stays inside its column (%s)" % [spill])
	# Weapons & Tools narrows the list; picking the first craftable recipe and Craft starts it.
	(craft.find_child("Cat_weapon_tools", true, false) as Button).pressed.emit()
	await _frames(2)
	var all_ok := true
	for rec in craft._shown_recipes():
		all_ok = all_ok and str(rec.get("skill", "")) == "weapon_tools"
	_expect(all_ok and not craft._shown_recipes().is_empty(), "D1: the Weapons & Tools tile shows weapon_tools recipes only")
	(craft.find_child("Cat_all", true, false) as Button).pressed.emit()
	await _frames(1)
	var pick := ""
	for rec in craft._shown_recipes():
		if craft._block_reason(rec, craft._station_info("")) == "":
			pick = str(rec.get("id", ""))
			break
	_expect(pick != "", "D1: some hand recipe can be crafted from the test bag")
	if pick == "":
		craft.hide_ui()
		return
	var row: Button = craft.find_child("Recipe_" + pick, true, false)
	row.pressed.emit()
	await _frames(2)
	var bracket: Node = (craft.find_child("Recipe_" + pick, true, false) as Node).find_child("Brackets", false, false)
	_expect(bracket != null, "D1: the chosen recipe carries gold brackets")
	one = craft.find_child("CraftOne", true, false)
	_expect(not (one as Button).disabled, "D1: Craft is enabled for %s" % pick)
	(one as Button).pressed.emit()
	await _frames(2)
	var sc = _player.station_craft
	_expect(not craft.visible and sc.recipe_id == StringName(pick), "D1: Craft closes the sheet and starts %s (recipe %s)" % [pick, sc.recipe_id])
	sc.cancel_and_refund()
	await _frames(1)

# ---------------------------------------------------------------- D3

func _test_d3() -> void:
	_bag([["twine", 6], ["twine", 15, {"tough_fiber": 2}], ["twine", 10], ["branch", 8], ["branch", 4]])
	var craft = _player.craft_ui
	craft._station = ""
	craft.show_ui()
	await _frames(2)
	craft.open_place("capture_net_i")
	await _frames(3)
	var place = craft._place
	_expect(place.visible and not craft._body.visible, "D3: the place-materials view replaces the stations sheet")
	var chev: Array = place.find_children("Chevron_*", "", true, false)
	_expect(chev.size() == 2, "D3: one chevron per slot (%d)" % chev.size())
	_expect(place._complete.text == "0%", "D3: nothing placed reads 0%% (%s)" % place._complete.text)
	var cta: Button = place.find_child("PlaceCta", true, false)
	_expect(cta.text == "Place material", "D3: the action reads Place material (%s)" % cta.text)
	_taps_ok(place, "D3")
	var cols := {}
	for n in ["PlaceSlots", "PlaceCentre", "FocusCard", "ResultCard"]:
		cols[n] = (place.get_node(n) as Control).get_global_rect()
	_in_view(cols, "D3 columns")
	_apart(cols.merged({"header": (craft.find_child("CraftHeader", true, false) as Control).get_global_rect()}), "D3 header and columns")
	# Focus the Lv 15 twine (not the default pick: defaults spend the least valuable first) and place it.
	var inv = _player.inventory
	var best := -1
	for idx in place.candidates(0):
		if inv.slots[idx].level == 15:
			best = idx
	_expect(best >= 0 and (load("res://scripts/items/crafting.gd") as GDScript).default_picks(inv, place.rec)[0] != best, "D3: the Lv 15 twine is a candidate and not the default lead")
	(place.find_child("Cand_%d" % best, true, false) as Button).pressed.emit()
	await _frames(1)
	cta.pressed.emit()
	await _frames(2)
	_expect(place._complete.text == "67%", "D3: one of three units' slots placed reads 67%% (%s)" % place._complete.text)
	var c0 = place.find_child("Chevron_0", true, false)
	_expect(c0 != null and c0.filled and place.slot_sel == 1, "D3: slot 1's chevron turns OK_GREEN and the next slot is up")
	var order: Dictionary = place.order_of(0)
	_expect(int(order.get(best, 0)) == 1 and order.size() == 2, "D3: order badges 1, 2 on the lashing slot, the placed twine first (%s)" % [order])
	var chips: Node = place.find_child("ResultTraits", true, false)
	var chip_text := ""
	for l in (chips.find_children("*", "Label", true, false) if chips else []):
		chip_text += (l as Label).text + " "
	_expect(chip_text.contains("Tough Fiber"), "D3: the expected result inherits the slot-1 trait (%s)" % chip_text)
	cta = place.find_child("PlaceCta", true, false)
	cta.pressed.emit()
	await _frames(2)
	cta = place.find_child("PlaceCta", true, false)
	_expect(place._complete.text == "100%" and cta.text == "Craft", "D3: every slot placed: 100%% and Craft (%s, %s)" % [place._complete.text, cta.text])
	var uid: String = inv.slots[best].uid
	(place.find_child("QtyPlus", true, false) as Button).pressed.emit()
	await _frames(1)
	_expect(place.qty == 2, "D3: the stepper counts up (%d)" % place.qty)
	(place.find_child("PlaceCta", true, false) as Button).pressed.emit()
	await _frames(2)
	var sc = _player.station_craft
	_expect(sc.recipe_id == &"capture_net_i" and not sc._pick_uids.is_empty() and sc._pick_uids[0] == uid, "D3: Craft starts the net with the placed twine leading (%s)" % [sc._pick_uids])
	sc.cancel_and_refund()
	await _frames(1)

# ---------------------------------------------------------------- D2

func _test_d2() -> void:
	_bag([["branch", 20], ["fibre_stalk", 20], ["stone", 10]])
	var build = (load("res://scripts/ui/build_ui.gd") as GDScript).ensure(_player)
	build.open()
	await _frames(3)
	var tiers: Array = build.find_children("Tier_*", "Button", true, false)
	_expect(tiers.size() == 4, "D2: four tier tabs (%d)" % tiers.size())
	var tiles: Array = build.find_children("Piece_*", "", true, false)
	_expect(tiles.size() >= 3, "D2: Parts shows the tier's pieces as hex tiles (%d)" % tiles.size())
	_expect(tiles.all(func (h) -> bool: return h.flat_top), "D2: tiles are flat-top hexes")
	_taps_ok(build._drawer, "D2 drawer")
	var drawer: Rect2 = build.drawer_rect()
	_in_view({"drawer": drawer}, "D2 drawer")
	# Wood tab switches the tier.
	(build.find_child("Tier_wood", true, false) as Button).pressed.emit()
	await _frames(1)
	_expect(build.tier == &"wood", "D2: the Wood tab picks the wood tier")
	(build.find_child("Tier_thatch", true, false) as Button).pressed.emit()
	await _frames(1)
	var foundation = build.find_child("Piece_foundation", true, false)
	_expect(foundation != null, "D2: a Foundation tile")
	if foundation == null:
		return
	foundation.pressed.emit()
	await _frames(4)
	_expect(_player.placer.placing == &"foundation" and build.visible, "D2: the tile starts the ghost and the drawer stays open (%s)" % _player.placer.placing)
	# A landscape phone says the cost in the drawer's bottom line (no free strip over the world).
	var cost_line: String = build._stock.text if _size.y < 500 else (build._cost_bar.text if build._cost_bar.visible else "")
	_expect(build._banner.visible and cost_line.begins_with("Foundation"), "D2: banner and the cost line (%s)" % cost_line)
	var hexes: Array = _hud.get("_place_hexes")
	var rot = hexes[0]
	var save = hexes[1]
	var cancel = hexes[2]
	_expect(rot.caption == "" and rot.bottom_text == "" and rot.top_text == "" and rot.glyph == "↻", "D2: ROTATE is the icon alone")
	_expect(save.bottom_text == "SAVE" and save.rim_color == OK_GREEN and save.glyph_color == OK_GREEN, "D2: SAVE has an OK_GREEN check and rim")
	_expect(cancel.bottom_text == "CANCEL", "D2: CANCEL says CANCEL")
	var row := {}
	for h in hexes:
		_expect((h as Control).is_visible_in_tree() and (h as Control).size.x >= 64.0, "D2: %s shown at >= 64 px" % h.name)
		row[h.name] = h.hex_rect()
	_in_view(row, "D2 placement row")
	var off_drawer := true
	for k in row:
		off_drawer = off_drawer and not (row[k] as Rect2).intersects(drawer)
	_expect(off_drawer, "D2: the placement row keeps off the drawer (%s vs %s)" % [row, drawer])
	_player.placer.cancel()
	await _frames(2)
	_expect(not build._banner.visible, "D2: the banner goes with the ghost")
	build.hide_ui()
	await _frames(1)
