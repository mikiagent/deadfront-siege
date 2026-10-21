extends Node3D
## W3-EXCHANGE lab: the Island Market screens over the deterministic local economy
## (MarketHarness: real VaultBridge, real other-account listings, labelled a test server).
## Run windowed: Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   -- --lab=market_ui_lab --screen=<one of SCREENS> --shot=<png> --shot-delay=6 [--insets=L,R,B]
## --insets stands in for a phone's safe area (px left, right, bottom) on a desktop window.
## buy_500 lists 490 more items by real ops and flings the Buy list to its end (needs a longer
## --shot-delay, ~40): "[market_lab] measure perf ..." is gate 12.
## The market is opened the owner's way: the HUD's MENU sheet, then its "Island Market" button
## (hook H0). Prints "[market_lab] measure ..." for exchange-spec §8 gates 1-3.

const SCREENS := ["menu", "buy", "buy_search", "buy_taming", "sell", "sell_pet", "sell_tool", "sell_none", "my_market", "my_market_sold",
	"my_market_history", "my_market_cancel", "my_market_received", "confirm", "offline", "buy_500"]

var screen := "buy"
var harness: MarketHarness
var _econ_dir := ""
var _hud: HuntHud
var _player: Player

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			screen = a.substr(9)
		elif a.begins_with("--insets="):
			var p := a.substr(9).split(",")
			MarketScreen.test_insets = Vector4(float(p[1]), float(p[2]), 0.0, float(p[0])) if p.size() == 3 else Vector4(-1, -1, -1, -1)
	if screen not in SCREENS:
		push_error("[market_lab] unknown --screen=%s (one of %s)" % [screen, ", ".join(SCREENS)])
		screen = "buy"
	Game.debug_overlay = false # before the HUD builds: players never see the DEBUG hex
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false) # a real island name for the header
	(kit["nav"] as Node).queue_free()
	MarketScreen.test_client = null
	if screen != "offline":
		# The run's own user dir (override.cfg + SaveGame.run_name convention), never the owner's.
		# Per run: shots of several screens run in parallel and must not share one journal.
		_econ_dir = OS.get_user_data_dir().path_join("runs/market_ui_lab/econ_%s_%d" % [screen, OS.get_process_id()])
		harness = MarketHarness.new(_econ_dir)
		harness.seed_scene()
		if screen == "buy_500":
			var t0 := Time.get_ticks_msec()
			harness.seed_bulk(490)
			print("[market_lab] seeded 490 more listings by real ops in %d ms" % (Time.get_ticks_msec() - t0))
		for f in harness.failures:
			push_error("[market_lab] harness: %s" % f)
		MarketScreen.test_client = harness.client()
	_show.call_deferred()

func _exit_tree() -> void:
	MarketScreen.test_client = null
	MarketScreen.test_insets = Vector4(-1, -1, -1, -1)
	MarketHarness.release_loggers()
	if _econ_dir != "":
		MarketHarness._wipe(_econ_dir)
		DirAccess.remove_absolute(_econ_dir)

func _show() -> void:
	await get_tree().process_frame
	if screen == "menu":
		_show_menu()
		return
	var ms := await _open_from_menu()
	if ms == null:
		push_error("[market_lab] the market did not open")
		return
	match screen:
		"buy_search":
			ms.buy.set_query("branch")
		"buy_taming":
			ms.buy.set_category("animal")
			for b in ms.buy.column.buttons:
				if b.name == "Cat_clade_Compsognathidae":
					b.pressed.emit()
		"confirm":
			for r in ms.buy.table.rows:
				if str(r.view.key) == "item:stone_knife_work":
					r.pressed.emit()
		"sell", "sell_pet", "sell_tool", "sell_none":
			ms.rail.select(&"sell")
			for e: Dictionary in ms.sell.entries: # sell: the bag's bone stack; sell_pet: the bonded pet; sell_tool: the crafted knife
				if (screen == "sell" and e.src == "bag" and str(e.asset.get("id", "")) == "bone") or (screen == "sell_pet" and e.src == "pet") \
						or (screen == "sell_tool" and str(e.asset.get("id", "")) == "stone_knife_work"):
					ms.sell.select(str(e.uid))
		"my_market", "my_market_sold", "my_market_history", "my_market_cancel", "my_market_received":
			ms.rail.select(&"my_market")
			match screen:
				"my_market_sold":
					ms.mine.show_sub(&"sold")
				"my_market_history":
					ms.mine.show_sub(&"history")
				"my_market_cancel":
					ms.mine.cancel_pressed.emit(ms.mine.rows[0].view)
				"my_market_received":
					await ms.mine.receive_all()
	for i in 3:
		await get_tree().process_frame
	_measure(ms)
	if screen == "buy_500":
		await _fling(ms)
	if screen == "sell":
		await _preview_each(ms)

## Every sellable instance in turn: its fee / tax / proceeds preview must show above List with no
## scrolling of the panel (the phone panel is the tight one). Ends on the bone again for the shot.
func _preview_each(ms: MarketScreen) -> void:
	var f := ms.sell.form
	var keep := ms.sell.selected
	var hidden: PackedStringArray = []
	var checked := 0
	for e: Dictionary in ms.sell.entries:
		if str(e.why) != "":
			continue
		await ms.sell.select(str(e.uid))
		for i in 2:
			await get_tree().process_frame
		checked += 1
		var net := f.preview_values.net as Label
		var box := net.get_parent() as Control
		while box != null and not box is ScrollContainer:
			box = box.get_parent() as Control
		var shown_to := box.get_global_rect().end.y if box != null else f.list_btn.get_global_rect().position.y
		if net.get_global_rect().position.y + net.get_combined_minimum_size().y * 0.8 > shown_to: # its glyphs are cut by the panel's edge
			hidden.append("%s (%d > %d)" % [e.name, net.get_global_rect().end.y, shown_to])
	await ms.sell.select(keep)
	for i in 2:
		await get_tree().process_frame
	print("[market_lab] measure sell previews checked=%d hidden_under_list=%d %s" % [checked, hidden.size(), ", ".join(hidden)])

## Gate 12: flings the Buy list from its top to its end at 120 px a frame. Every page the list asks
## for on the way is one market.search and 20 new rows (MarketTable.build_us); a frame time is the
## wall-clock gap between two frames (vsync included), the first 10 frames after opening excluded.
func _fling(ms: MarketScreen) -> void:
	var t := ms.buy.table
	var sc := t.get_node("Rows") as ScrollContainer
	var builds: Array[int] = [t.build_us]
	ms.buy.loaded.connect(func (_r: Dictionary) -> void: builds.append(t.build_us))
	for i in 10:
		await get_tree().process_frame
	var worst := 0
	var over := 0
	var frames := 0
	var last := Time.get_ticks_usec()
	var t0 := last
	for i in 3000:
		var before := sc.scroll_vertical
		sc.scroll_vertical += 120
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		over += 1 if now - last > 33000 else 0
		last = now
		frames += 1
		if sc.scroll_vertical == before and t.page >= t.pages and not t.loading:
			break
	var uids := {}
	for r in t.rows:
		uids[r.model.uid] = true
	print("[market_lab] measure perf listings=%d rows=%d unique=%d pages=%d build_max=%.2fms frames=%d in %.1fs frame_max=%.1fms over33=%d" % [
		t.total, t.rows.size(), uids.size(), t.page, builds.max() / 1000.0, frames, (last - t0) / 1e6, worst / 1000.0, over])

## The HUD's MENU sheet itself: the Island Market row is there and every row fits without scrolling.
func _show_menu() -> void:
	_hud.call("_toggle_sheet", &"menu")
	for i in 3:
		await get_tree().process_frame
	var rows := _hud.find_child("SheetRows", true, false) as ScrollContainer
	var names: PackedStringArray = []
	for b in rows.find_children("*", "Button", true, false):
		names.append((b as Button).text)
	var bar := rows.get_v_scroll_bar()
	print("[market_lab] measure menu rows=%s scrolls=%s" % [", ".join(names), bar.max_value > rows.size.y + 0.5])

## HUD MENU -> "Island Market" (the real button); without hook H0 the lab says so and opens it directly.
func _open_from_menu() -> MarketScreen:
	_hud.call("_toggle_sheet", &"menu")
	await get_tree().process_frame
	var sheet := _hud.find_child("HudSheet", true, false)
	var entry: Button = null
	if sheet:
		for b in sheet.find_children("*", "Button", true, false):
			if (b as Button).text == "Island Market":
				entry = b
	if entry:
		print("[market_lab] menu: pressing the HUD's Island Market button")
		entry.pressed.emit()
	else:
		print("[market_lab] HOOK H0 absent: no Island Market row in the HUD menu; opening the screen directly")
		_hud.call("_close_sheet")
		var layer := CanvasLayer.new()
		layer.layer = 96
		add_child(layer)
		var direct := MarketScreen.new()
		layer.add_child(direct)
		direct.open(_player)
	await get_tree().process_frame
	return get_tree().root.find_child("MarketScreen", true, false) as MarketScreen

func _measure(ms: MarketScreen) -> void:
	var view := ms.get_viewport_rect().size
	var m: Dictionary = ms._m # the screen's own metrics (tmin = 44 pt in canvas px)
	var pts := DisplayMode.window_points(get_window())
	var t := ms.buy.table
	var rows_vis := floori(t.get_node("Rows").size.y / float(m.row_h)) if ms.buy.visible else 0
	print("[market_lab] measure view=%s header=%.1f%% (%dpx) rail=%.1f%% cat=%s row=%.1f%% (%dpx) rows=%d visible=%d chip=%s client=%s" % [
		view, 100.0 * m.header_h / view.y, int(m.header_h), 100.0 * ms.rail.size.x / view.x,
		("%.1f%%" % (100.0 * ms.buy.column.size.x / view.x)) if ms.buy.column.visible else "-",
		100.0 * m.row_h / view.y, int(m.row_h), t.rows.size(), rows_vis, not t.chips.is_empty(), ms.client.kind()])
	var small: PackedStringArray = []
	for b in ms.find_children("*", "BaseButton", true, false):
		var c := b as Control
		if c.is_visible_in_tree() and (c.size.x < m.tmin - 0.5 or c.size.y < m.tmin - 0.5):
			small.append("%s %dx%d" % [c.name, c.size.x, c.size.y])
	var clipped: PackedStringArray = []
	for l in ms.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.is_visible_in_tree() and lab.autowrap_mode == TextServer.AUTOWRAP_OFF and lab.get_minimum_size().x > lab.size.x + 0.5:
			clipped.append("%s '%s'" % [lab.name, lab.text])
	var plus := 0
	for b in ms.find_children("*", "Button", true, false):
		if (b as Button).text.strip_edges() == "+":
			plus += 1
	print("[market_lab] measure window=%s pt canvas=%s target_min=%dpx (44 pt) type_min=%.1fpt" % [pts, view, int(m.tmin), UiTokens.TYPE_MIN * pts.x / view.x])
	print("[market_lab] measure targets_under_44=%d %s clipped_labels=%d %s plus_buttons=%d" % [small.size(), ", ".join(small), clipped.size(), ", ".join(clipped), plus])
	# Every visible target inside the safe area (a phone's notch and home bar; --insets on a desktop).
	var safe: Rect2 = ms._m.get("safe", Rect2(Vector2.ZERO, view))
	var outside: PackedStringArray = []
	for b in ms.find_children("*", "BaseButton", true, false):
		var c := b as Control
		var clip := c.get_parent_control()
		while clip != null and not clip.clip_contents:
			clip = clip.get_parent_control()
		var r := c.get_global_rect() if clip == null else c.get_global_rect().intersection(clip.get_global_rect())
		if c.is_visible_in_tree() and r.has_area() and not safe.grow(0.5).encloses(r):
			outside.append("%s %s" % [c.name, r])
	print("[market_lab] measure safe=%s outside_safe=%d %s" % [safe, outside.size(), ", ".join(outside)])
	if ms.buy.visible:
		var cut := t.rows.filter(func (r: MarketRow) -> bool: return r.name_cut).map(func (r: MarketRow) -> String: return r.model.name)
		print("[market_lab] measure table=%dpx heads_cut=%d %s names_cut=%d %s" % [t.size.x, t.heads_cut.size(), ", ".join(t.heads_cut), cut.size(), ", ".join(cut)])
	if ms.sell.visible:
		var pk := ms.sell.picker
		var f := ms.sell.form
		var cell: float = pk.cells[0].size.x if not pk.cells.is_empty() else 0.0
		print("[market_lab] measure sell picker=%.1f%% cols=%d cell=%dpx cells=%d form=%dx%d form_min=%dx%d fits=%s list=%dx%d '%s' status='%s'" % [
			100.0 * pk.size.x / view.x, pk._grid.columns, int(cell), pk.cells.size(), f.size.x, f.size.y,
			f.get_combined_minimum_size().x, f.get_combined_minimum_size().y, f.get_combined_minimum_size().x <= f.size.x + 0.5 and f.size.y <= view.y,
			f.list_btn.size.x, f.list_btn.size.y, f.list_btn.text, f.status.text])
	if ms.mine.visible:
		var mm := ms.mine
		var cancels := mm.find_children("Cancel_*", "Button", true, false)
		print("[market_lab] measure my_market tab=%s rows=%d visible=%d row=%dpx cancel=%s receive=%dx%d '%s' waiting='%s' status='%s'" % [
			mm.tab, mm.rows.size(), floori(mm.get_node("MineRows").size.y / float(m.row_h)), int(m.row_h),
			"%dx%d" % [(cancels[0] as Control).size.x, (cancels[0] as Control).size.y] if not cancels.is_empty() else "-",
			mm.receive_btn.size.x, mm.receive_btn.size.y, mm.receive_btn.text, mm._waiting_label.text, mm.status.text])
		print("[market_lab] my_market rows: %s" % ", ".join(mm.rows.map(func (r: MarketRow) -> String: return "%s | %s | %d" % [r.model.name, r.model.dur, r.model.price])))
	if harness:
		print("[market_lab] %s; rows: %s" % [ms.client.label(), ", ".join(t.rows.map(func (r: MarketRow) -> String: return "%s %s %d" % [r.model.name, r.model.uid, r.model.price]))])
