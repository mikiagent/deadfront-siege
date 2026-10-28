extends SceneTree
## UNCLAIM acceptance (owner: "Also need a way to unclaim land too"; spec 29 section 2 names a Release
## action but gives no rules, so the task's ASSUMPTIONs are the rules here): one plot of your Domain can
## be given up from a confirm that states the consequence; the LAST plot is refused, a release that
## would cut the Domain into two pieces is refused, and a plot with a building standing on it is refused
## until the building is packed up; the camp's own landing plot is not a Domain plot at all; a released
## plot can be claimed again later; the released cell is gone from the saved record and stays gone
## through a save and a reload. And the confirm is the only path: cancelling it, or asking without it,
## changes nothing.
## Run: Godot --headless --path game --script res://tests/t_unclaim.gd -> "[t_unclaim] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const ME := "Tess"

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var _rt: Node3D
var _player: Node3D
var IC: GDScript
var BG: GDScript
var CP: GDScript
var DS: GDScript
var PB: GDScript
var SP: GDScript
var SG: GDScript
var DR: GDScript
const DomainScreenRadius := 3  ## DomainScreen.GRID_RADIUS

var _changed := 0
var _last_changed := Rect2i()

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	root.get_tree().create_timer(90.0).timeout.connect(func () -> void:
		print("[t_unclaim] FAIL watchdog: the run did not finish in 90 s")
		quit(1))
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_unclaim] FAIL %s" % what)

func _run() -> void:
	IC = load("res://scripts/world/island_claims.gd")
	BG = load("res://scripts/world/build_grid.gd")
	CP = load("res://scripts/ui/claim_panel.gd")
	DS = load("res://scripts/ui/domain_screen.gd")
	PB = load("res://scripts/world/placed_building.gd")
	DR = load("res://scripts/world/domain_rules.gd")
	SP = load("res://scripts/world/structure_piece.gd")
	SG = load("res://scripts/world/structure_grid.gd")
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TUnclaimHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_world.player_name = ME
	_world.home_claims = []
	_world.home_domain = {}
	_world.away_domain = {}
	_world.unstable_claims = []
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = _world.runtime
	_rt.claims_changed.connect(func (r: Rect2i) -> void:
		_changed += 1
		_last_changed = r)
	await _test_refusals()
	await _test_release_and_save()
	await _test_confirm_required()
	await _test_building_refused()
	await _test_ui_paths()
	if _fails.is_empty():
		print("[t_unclaim] PASS")
		quit(0)
	else:
		print("[t_unclaim] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- helpers

func _find_cell(take: Callable) -> Vector2i:
	var camp: Vector2i = IC.cell_of(_rt, BG.tile_of(_rt._camp_pos))
	for r in range(1, 12):
		for y in range(camp.y - r, camp.y + r + 1):
			for x in range(camp.x - r, camp.x + r + 1):
				var c := Vector2i(x, y)
				if IC.cell_block_reason(_rt, c) == "" and not IC.occupied_cells(_rt).has(c) and take.call(c):
					return c
	return IC.NO_CELL

## Three plots in a row (each sharing an edge with the one before), so the middle one is a cut.
func _chain() -> Array:
	var first := _find_cell(func (_c: Vector2i) -> bool: return true)
	if first == IC.NO_CELL:
		return []
	var out: Array = [first]
	for step in 2:
		var grown := false
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = (out.back() as Vector2i) + d
			if IC.cell_block_reason(_rt, n) == "" and not IC.occupied_cells(_rt).has(n) and not out.has(n):
				out.append(n)
				grown = true
				break
		if not grown:
			return []
	var batch: Array = out.duplicate()
	var res: Dictionary = _rt.claim_domain(batch)
	if not bool(res["ok"]):
		print("[t_unclaim] setup: the chain claim was refused (%s)" % [res["reason"]])
		return []
	return out

func _reset() -> void:
	_rt.domain = {}
	_rt.claims.clear()
	_rt.set_other_claims([])
	_changed = 0
	_last_changed = Rect2i()

# ---------------------------------------------------------------- the rules

func _test_refusals() -> void:
	_reset()
	# Nothing held: nothing to release.
	var free := _find_cell(func (_c: Vector2i) -> bool: return true)
	_expect(str(_rt.release_reason(free)) == "not_owned", "a plot you do not hold is refused (not_owned, got %s)" % _rt.release_reason(free))
	# Declare one plot: it is the last one.
	var out: Dictionary = _rt.claim_domain([free])
	_expect(bool(out["ok"]), "setup: one plot is declared (%s)" % [out["reason"]])
	_expect(str(_rt.release_reason(free)) == "last_cell", "your only plot is refused (last_cell, got %s)" % _rt.release_reason(free))
	var refused: Dictionary = _rt.release_cell(free)
	_expect(not bool(refused["ok"]) and str(refused["reason"]) == "last_cell", "releasing the last plot is refused (%s)" % [refused])
	_expect(_rt.claim_used() == 1, "the refused release left the plot in place (%d)" % _rt.claim_used())
	# The camp's own landing plot is claimed land but never a Domain plot.
	var camp_cell: Vector2i = IC.cell_of(_rt, BG.tile_of(_rt._camp_pos))
	_expect(str(_rt.release_reason(camp_cell)) == "camp_land", "the camp's own landing plot is refused as camp_land (got %s)" % _rt.release_reason(camp_cell))
	# A three-plot chain: its middle plot would cut the Domain in two.
	_reset()
	var chain := _chain()
	_expect(chain.size() == 3, "setup: three plots share edges in a row (%s)" % [chain])
	if chain.size() != 3:
		return
	var mid: Vector2i = chain[1]
	_expect(str(_rt.release_reason(mid)) == "split", "a release that would cut the Domain in two is refused (split, got %s)" % _rt.release_reason(mid))
	var cut: Dictionary = _rt.release_cell(mid)
	_expect(not bool(cut["ok"]) and _rt.claim_used() == 3, "the refused split changed nothing (%s, used=%d)" % [cut, _rt.claim_used()])
	print("[t_unclaim] refusals: last_cell + camp_land + split all refused, %d plot(s) kept" % _rt.claim_used())

# ---------------------------------------------------------------- release, save, reload, re-claim

func _test_release_and_save() -> void:
	_reset()
	var chain := _chain()
	_expect(chain.size() == 3, "setup: a three-plot chain for the release (%s)" % [chain])
	if chain.size() != 3:
		return
	var edge: Vector2i = chain[2]
	_changed = 0
	var out: Dictionary = _rt.release_cell(edge)
	_expect(bool(out["ok"]), "the end plot of the chain is released (%s)" % [out["reason"]])
	_expect(_rt.claim_used() == 2, "one plot left the Domain (%d remain)" % _rt.claim_used())
	var own: Dictionary = IC.owned_cells(_rt)
	_expect(not own.has(edge), "the released plot is no longer in the Domain (%s)" % [own.keys()])
	_expect(not _rt.is_claimed(IC.cell_rect(_rt, edge).get_center()), "the released plot's tiles are no longer claimed")
	_expect(own.has(chain[0]) and own.has(chain[1]), "the other plots stay yours (%s)" % [own.keys()])
	_expect(_changed == 1 and _last_changed == IC.cell_rect(_rt, edge), "the release fired claims_changed once with the released tiles (%d, %s)" % [_changed, _last_changed])
	# The world's saved copy (what a save writes) has no trace of the plot; a save writes only cells.
	var saved_cells: Array = (_world.home_domain.get("cells", []) as Array)
	_expect(saved_cells.size() == 2, "the saved record lists the two remaining plots (%s)" % [saved_cells])
	var saw_edge := false
	for c in saved_cells:
		if c is Array and (c as Array).size() >= 2 and Vector2i(int(c[0]), int(c[1])) == edge:
			saw_edge = true
	_expect(not saw_edge, "the released plot is gone from the saved record (%s)" % [saved_cells])
	# A reload rebuilds the Domain from the record: the plot stays released.
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	_rt = _world.runtime
	_rt.claims_changed.connect(func (r: Rect2i) -> void:
		_changed += 1
		_last_changed = r)
	_expect(_rt.claim_used() == 2, "a reload keeps the release (%d plots)" % _rt.claim_used())
	_expect(not IC.owned_cells(_rt).has(edge), "the released plot is still not yours after the reload (%s)" % [IC.owned_cells(_rt).keys()])
	_expect(IC.owned_cells(_rt).has(chain[1]), "the kept plot survived the reload (%s)" % [IC.owned_cells(_rt).keys()])
	# The released plot can be claimed again (it shares an edge with what is left).
	var why := str(_rt.claim_expand_reason(IC.cell_rect(_rt, edge).get_center()))
	_expect(why == "", "the released plot is claimable again (refused: %s)" % why)
	var back: Dictionary = _rt.claim_domain([edge])
	_expect(bool(back["ok"]) and IC.owned_cells(_rt).has(edge), "re-claiming the released plot works (%s)" % [back["reason"]])
	_expect(_rt.claim_used() == 3, "the re-claim restores the plot count (%d)" % _rt.claim_used())
	# The Domain's other rules still hold on the re-claimed land: it cannot take a non-adjacent plot
	# and it never exceeds the cap (a release never hands out land, and a re-claim is an ordinary claim).
	var cap: int = _rt.claim_cap()
	_expect(_rt.claim_used() <= cap, "the Domain never holds more plots than the cap (%d <= %d)" % [_rt.claim_used(), cap])
	var far := _find_cell(func (c: Vector2i) -> bool:
		return not IC.adjacent_to(c, IC.occupied_cells(_rt)) and IC.cell_block_reason(_rt, c) == "")
	if far != IC.NO_CELL:
		var hop: Dictionary = _rt.claim_domain([far])
		_expect(not bool(hop["ok"]) and str(hop["reason"]) == "not_adjacent", "a released plot does not loosen adjacency (%s)" % [hop["reason"]])
	# ... and the plot that was kept can be released now that it is an end plot again.
	var second: Dictionary = _rt.release_cell(edge)
	_expect(bool(second["ok"]), "a re-claimed plot can be released again (%s)" % [second["reason"]])
	print("[t_unclaim] release: %s -> %s, saved %d, reload %d, re-claim ok=%s" % [edge, chain, saved_cells.size(), _rt.claim_used(), back["ok"]])

# ---------------------------------------------------------------- the confirm gate

func _test_confirm_required() -> void:
	_reset()
	var chain := _chain()
	_expect(chain.size() == 3, "setup: a chain for the confirm gate (%s)" % [chain])
	if chain.size() != 3:
		return
	var edge: Vector2i = chain[2]
	# The panel is the confirm: opening it changes nothing, KEEP changes nothing.
	var panel: PanelContainer = CP.new()
	root.add_child(panel)
	var usable := panel.has_method("open_release")
	_expect(usable, "ClaimPanel has the release confirm (open_release)")
	if not usable:
		panel.queue_free()
		return
	panel.call("open_release", _rt, _rt.claim_used(), edge, str(_rt.release_reason(edge)), str(IC.building_on(_rt, edge)))
	await process_frame
	var text := str(panel.call("body_text")).replace("\n", " ")
	print("[t_unclaim] panel: %s" % text)
	_expect(text.contains("%dx%d" % [DR.cell_tiles(), DR.cell_tiles()]), "the panel names the plot's size and place: \"%s\"" % text)
	_expect(text.to_lower().contains("cannot build") or text.to_lower().contains("stops being yours"), "the panel states the consequence of giving the plot up: \"%s\"" % text)
	_expect(text.to_lower().contains("nothing is built") or text.to_lower().contains("no claim stake"), "the panel states what happens to anything built there and to the stake: \"%s\"" % text)
	_expect(_rt.claim_used() == 3, "opening the confirm changes nothing (%d)" % _rt.claim_used())
	# KEEP (the cancel answer): nothing is released.
	panel.emit_signal("answered", false)
	await process_frame
	_expect(_rt.claim_used() == 3 and IC.owned_cells(_rt).has(edge), "KEEP releases nothing (%d plots)" % _rt.claim_used())
	# The confirm is the only path: the panel's RELEASE PLOT button does it.
	var confirm := panel.find_child("ClaimConfirm", true, false) as Button
	_expect(confirm != null and str(confirm.text) == "Release plot", "the confirm's action is RELEASE PLOT (got %s)" % [confirm.text if confirm else ""])
	var cancel := panel.find_child("ClaimCancel", true, false) as Button
	_expect(cancel != null and str(cancel.text) == "Keep", "the confirm offers KEEP (got %s)" % [cancel.text if cancel else ""])
	_expect(confirm != null and confirm.custom_minimum_size.y >= 64.0, "the confirm buttons are 64 px or taller (%.0f)" % [confirm.custom_minimum_size.y if confirm else 0.0])
	if confirm != null:
		confirm.pressed.emit()
	await process_frame
	_expect(_rt.claim_used() == 2 and not IC.owned_cells(_rt).has(edge), "RELEASE PLOT gives the plot up (%d plots)" % _rt.claim_used())
	panel.queue_free()
	print("[t_unclaim] confirm gate: open/keep change nothing, release button drops exactly one plot")

# ---------------------------------------------------------------- a building on the plot

func _test_building_refused() -> void:
	_reset()
	var chain := _chain()
	_expect(chain.size() == 3, "setup: a chain for the building refusal (%s)" % [chain])
	if chain.size() != 3:
		return
	var cell: Vector2i = chain[2]
	var grid: Variant = _rt.get("build_grid")
	var tile: Vector2i = IC.cell_rect(_rt, cell).get_center()
	var basket: Node3D = PB.make(&"basket")
	_rt.add_child(basket)
	basket.global_transform = grid.placement_transform(&"basket", tile, 0)
	grid.occupy(basket, grid.cells_for(&"basket", tile, 0))
	await process_frame
	var why := str(_rt.release_reason(cell))
	_expect(why == "building", "a plot with a building on it is refused (building, got %s)" % why)
	var named := str(IC.building_on(_rt, cell))
	_expect(named != "", "the refusal names what stands on the plot (got \"%s\")" % named)
	var out: Dictionary = _rt.release_cell(cell)
	_expect(not bool(out["ok"]) and _rt.claim_used() == 3, "the refused release kept the plot and its building (%d plots)" % _rt.claim_used())
	_expect(is_instance_valid(basket) and basket.is_inside_tree(), "the building stays exactly where it was")
	var text := str(CP.describe_release(3, cell, why, named))
	print("[t_unclaim] building: %s" % text.replace("\n", " "))
	_expect(text.to_lower().contains("building") and text.to_lower().contains("nothing changes"), "the panel's text says why a built-on plot is refused: \"%s\"" % text)
	# Packed up: the same plot releases.
	grid.release(basket)
	basket.queue_free()
	await process_frame
	var after: Dictionary = _rt.release_cell(cell)
	_expect(bool(after["ok"]), "once the building is gone the plot releases (%s)" % [after["reason"]])
	# A modular piece counts too: a foundation inside the plot blocks it just the same.
	_reset()
	var again := _chain()
	if again.size() == 3:
		var pc: Vector2i = again[2]
		var m := Vector2i(IC.cell_rect(_rt, pc).position) / int(SG.cells_per_module())
		var piece: Node = SP.make(&"foundation", &"wood", Vector4i(m.x, m.y, 0, 0), 0, 0.0)
		_rt.add_child(piece)
		grid.structures.register(piece)
		await process_frame
		_expect(str(_rt.release_reason(pc)) == "building", "a foundation on the plot refuses the release too (got %s)" % _rt.release_reason(pc))
		grid.get("structures").unregister(piece)
		piece.queue_free()
		await process_frame
		var gone: Dictionary = _rt.release_cell(pc)
		_expect(bool(gone["ok"]), "the plot releases after the foundation is removed (%s)" % [gone["reason"]])
	print("[t_unclaim] building: kit and modular piece both refuse, release after removal")

# ---------------------------------------------------------------- the two UI entries

func _test_ui_paths() -> void:
	_reset()
	var chain := _chain()
	_expect(chain.size() == 3, "setup: a chain for the UI paths (%s)" % [chain])
	if chain.size() != 3:
		return
	# 1. The HUD's CLAIM press while standing on your own plot asks the RELEASE question
	# (ClaimPanel.open detects it: no second HUD path, no release without the confirm).
	var edge: Vector2i = chain[2]
	var tile: Vector2i = IC.cell_rect(_rt, edge).get_center()
	_player.global_position = BG.tile_centre(tile, _rt) + Vector3(0, 0.1, 0)
	await process_frame
	var panel: PanelContainer = CP.new()
	root.add_child(panel)
	panel.call("open", _rt.claims, tile, IC.cell_rect(_rt, edge), "already_owned", false)
	await process_frame
	var rc: Vector2i = panel.call("release_cell")
	_expect(rc == edge, "a press on your own plot opens the release confirm for that plot (got %s)" % [rc])
	var title := panel.find_child("ClaimTitle", true, false) as Label
	_expect(title != null and str(title.text) == str(CP.get_script_constant_map().get("RELEASE_TITLE", "")), "the panel's title asks about releasing (got %s)" % [title.text if title else ""])
	_expect(_rt.claim_used() == 3, "the panel alone releases nothing (%d plots)" % _rt.claim_used())
	panel.queue_free()
	await process_frame
	# 2. The Domain screen: the plot grid picks a plot, the release action asks, the confirm gives it up.
	var screen: Control = DS.new()
	root.add_child(screen)
	screen.call("open", _player)
	await process_frame
	var grid: Control = screen.get("_grid")
	_expect(grid != null and grid.has_signal("picked"), "the Domain plot grid takes a tap (picked signal)")
	if grid != null and grid.has_signal("picked"):
		var states: Dictionary = grid.call("states")
		var pick_cell: Vector2i = edge
		if not states.has(edge):
			for c: Vector2i in states.keys():
				if int(states[c]) == 0:
					pick_cell = c
					break
		# The tap goes through the grid's own coordinate mapping (a real press on that cell), not a
		# hand-made signal: cell_at() is what a mouse or touch press lands on.
		var c0: Vector2i = grid.call("centre_cell")
		var local := (Vector2(pick_cell - c0 + Vector2i(DomainScreenRadius, DomainScreenRadius)) + Vector2(0.5, 0.5)) * float(grid.get("cell"))
		grid.call("tap_at", local)
		await process_frame
		_expect(screen.get("_release_cell") == pick_cell, "a tap on your gold plot picks it for release (got %s)" % [screen.get("_release_cell")])
		var release_btn := screen.find_child("Release", true, false) as Button
		_expect(release_btn != null and not release_btn.disabled, "with a plot picked the Release action is live")
		_expect(release_btn != null and release_btn.custom_minimum_size.y >= 64.0, "the Release action is 64 px or taller (%.0f)" % [release_btn.custom_minimum_size.y if release_btn else 0.0])
		if release_btn != null:
			release_btn.pressed.emit()
			await process_frame
			var note := screen.find_child("Note", true, false) as Label
			_expect(note != null and note.text.to_lower().contains("plot"), "the release asks first and states the consequence: \"%s\"" % [note.text if note else ""])
			_expect(_rt.claim_used() == 3, "opening the Domain confirm releases nothing (%d plots)" % _rt.claim_used())
			var ok := screen.find_child("Confirm", true, false) as Button
			var keep := screen.find_child("Cancel", true, false) as Button
			_expect(ok != null and str(ok.text) == "Release plot", "the Domain confirm's action is RELEASE PLOT (got %s)" % [ok.text if ok else ""])
			_expect(keep != null and str(keep.text) == "Keep", "the Domain confirm offers KEEP (got %s)" % [keep.text if keep else ""])
			_expect(ok != null and ok.custom_minimum_size.y >= 64.0, "the Domain confirm's buttons are 64 px or taller")
			if keep != null:
				keep.pressed.emit()
				await process_frame
			_expect(_rt.claim_used() == 3, "KEEP in the Domain confirm releases nothing (%d plots)" % _rt.claim_used())
			grid.call("tap_at", local)
			await process_frame
			release_btn.pressed.emit()
			await process_frame
			var ok2 := screen.find_child("Confirm", true, false) as Button
			if ok2 != null:
				ok2.pressed.emit()
				await process_frame
			_expect(_rt.claim_used() == 2 and not IC.owned_cells(_rt).has(pick_cell), "the Domain confirm releases the picked plot (%d plots, %s)" % [_rt.claim_used(), IC.owned_cells(_rt).keys()])
	screen.call("close")
	screen.queue_free()
	await process_frame
	print("[t_unclaim] ui: HUD panel on your own plot asks release; Domain grid pick -> confirm -> released")
