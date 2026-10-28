extends RefCounted
## The checks behind t_uimarket.gd (loaded after the autoloads exist, like econ_bridge_checks.gd).

var failures: Array[String] = []
var _tree: SceneTree

func run(tree: SceneTree) -> Array[String]:
	_tree = tree
	var root := tree.get_root()
	var was_size := root.size
	var was_scale := root.content_scale_size
	_set_size(Vector2i(1600, 900))
	var host := Node.new()
	root.add_child(host)
	# --- offline: the player path (no test client)
	MarketScreen.test_client = null
	var s := MarketScreen.open_for(host, &"buy")
	await _tree.process_frame
	_expect(s.is_open() and not s.online(), "offline screen opens")
	for t: StringName in MarketScreen.TABS:
		s.show_tab(t)
		_expect(s.offline.visible and not s.panes[t].visible, "%s offline: card shown, pane hidden" % t)
		_expect(s.offline_body.text != "", "%s offline: says why" % t)
	_layout_checks(s, "offline")
	s.close_screen()
	_expect(not s.is_open(), "close hides the screen")
	# --- the local test server
	var dir := OS.get_user_data_dir().path_join("t_uimarket_econ")
	var h := MarketHarness.new(dir)
	h.seed_scene()
	_expect(h.failures.is_empty(), "harness seeds: %s" % ", ".join(h.failures))
	MarketScreen.test_client = h.client()
	s.open(&"buy")
	await _tree.process_frame
	_expect(s.online() and s.rail_note.text.contains("test server"), "test server is labelled")
	var buy: MarketBuy = s.panes[&"buy"]
	_expect(buy.rows.size() >= 5, "buy lists the other players' instances (%d rows)" % buy.rows.size())
	var uids := {}
	for r in buy.rows:
		_expect(int(r.v.listing.left) >= 1 and not uids.has(str(r.v.listing.id)), "one row per listing")
		uids[str(r.v.listing.id)] = true
	# sort by price descending puts the dearest first
	buy.sort_key = "price"
	buy.sort_asc = false
	buy.refresh()
	_expect(buy.rows.size() >= 2 and int(buy.rows[0].v.price) >= int(buy.rows[-1].v.price), "price sort descending")
	buy.sort_asc = true
	buy.refresh()
	var target: MarketRow = null
	for r in buy.rows:
		if int(r.v.listing.seller) != h.VIEWER and int(r.v.price) <= s.tradable():
			target = r
			break
	_expect(target != null, "an affordable listing by someone else")
	_layout_checks(s, "buy")
	if target:
		var before := int(s.wallet.wallet)
		var id := str(target.v.listing.id)
		buy.open_listing(target.v)
		_expect(s.confirm.visible and not s.confirm.primary.disabled, "buy confirm opens enabled")
		_on_screen(s.confirm.primary, "buy confirm primary")
		s.confirm.press_primary()
		_expect(s.confirm.status.text.begins_with("Bought"), "buy succeeds: %s" % s.confirm.status.text)
		_expect(int(s.wallet.wallet) == before - int(target.v.price), "wallet debited exactly once")
		s.confirm.press_primary() # a second tap after success sends nothing
		_expect(int(s.wallet.wallet) == before - int(target.v.price), "a double tap does not buy twice")
		var still := false
		for r in buy.rows:
			still = still or str(r.v.listing.id) == id
		_expect(not still, "the bought listing leaves the table")
		s.confirm.visible = false
	# --- My Market: Receive All takes storage into the server bag
	s.show_tab(&"my_market")
	var mine: MarketMine = s.panes[&"my_market"]
	_expect(not mine.stored.is_empty(), "something waits in storage")
	_layout_checks(s, "my_market")
	var bag_before := _bag_count(h)
	var got: Dictionary = mine.receive_all()
	_expect(int(got.received) > 0 and str(got.why) == "", "receive all: %s" % got)
	_expect(_bag_count(h) == bag_before + int(got.received), "received items are in the bag")
	_expect(mine.stored.is_empty(), "storage empty after receive all")
	for k in ["sold", "expired", "history"]:
		mine.sub = k
		mine.refresh()
		_expect(not mine.rows.is_empty(), "my market %s has rows" % k)
	# --- Sell: one exact instance
	s.show_tab(&"sell")
	var sell: MarketSell = s.panes[&"sell"]
	_expect(not sell.rows.is_empty(), "sell picker lists the server bag")
	_expect(sell.list_btn.disabled, "list is off without a price")
	var pick: MarketRow = null
	for r in sell.rows:
		if not r.disabled and r.v.deposit.has("bag_slot"):
			pick = r
			break
	_expect(pick != null, "a listable bag row")
	_layout_checks(s, "sell")
	if pick:
		sell.pick(pick)
		sell.price.text = "30"
		sell._update()
		_expect(not sell.list_btn.disabled, "list is on with a price")
		var f := sell.fees(30)
		_expect(int(f.fee) == 2 and int(f.tax) == 1 and int(f.net) == 29, "fee/tax/net preview matches the rules: %s" % f)
		var uid := str(pick.v.uid)
		var open_before := (h.op(h.VIEWER, "market.mine", {}).r.listings as Array).size()
		sell.press_list()
		_expect(sell.status.text.begins_with("Listed"), "list succeeds: %s" % sell.status.text)
		var ls: Array = h.op(h.VIEWER, "market.mine", {}).r.listings
		_expect(ls.size() == open_before + 1, "one new listing")
		var mine_l: Dictionary = {}
		for l: Dictionary in ls:
			if str(l.asset.get("uid", "")) == uid or (int(l.unit_price) == 30 and int(l.qty) == 1):
				mine_l = l
		_expect(not mine_l.is_empty() and int(mine_l.qty) == 1, "the listing is one unit of that instance")
		# My Market: cancel it
		s.show_tab(&"my_market")
		mine.sub = "active"
		mine.refresh()
		var row: MarketRow = null
		for r in mine.rows:
			if str(r.v.listing.id) == str(mine_l.get("id", "")):
				row = r
		_expect(row != null, "the new listing shows in Active")
		if row:
			mine.open_cancel(row.v)
			s.confirm.press_primary()
			_expect(s.confirm.status.text.begins_with("Listing cancelled"), "cancel succeeds: %s" % s.confirm.status.text)
			_expect(mine.stored.size() == 1, "the cancelled item waits in storage")
	# --- phone landscape
	_set_size(Vector2i(844, 390))
	await _tree.process_frame
	for t: StringName in MarketScreen.TABS:
		s.show_tab(t)
		await _tree.process_frame
		_layout_checks(s, "%s 844" % t)
	s.close_screen()
	MarketScreen.test_client = null
	MarketHarness.release_loggers()
	host.queue_free()
	_set_size(was_size, was_scale)
	return failures

func _set_size(sz: Vector2i, scale: Vector2i = Vector2i.ZERO) -> void:
	_tree.get_root().size = sz
	_tree.get_root().content_scale_size = scale if scale != Vector2i.ZERO else sz

func _bag_count(h: MarketHarness) -> int:
	var n := 0
	for row: Variant in h.bridge.chars.character(h.VIEWER).d.bag:
		if row is Dictionary and str(row.id) != str(CharacterState.LOCK):
			n += int(row.count)
	return n

## Header, rail and the shown pane's key controls: on screen, taps >= 64 px, and no overlaps.
func _layout_checks(s: MarketScreen, what: String) -> void:
	s._layout()
	var view := s.get_viewport_rect().size
	var taps: Array[Control] = [s.back_btn, s.close_btn]
	for t: StringName in MarketScreen.TABS:
		taps.append(s.rail_btns[t])
	var p: Control = s.panes[s.tab]
	if p.visible:
		if p is MarketBuy:
			taps.append_array((p as MarketBuy).cat_btns.slice(0, 1))
			taps.append_array((p as MarketBuy).sort_btns)
		elif p is MarketSell:
			taps.append_array([(p as MarketSell).list_btn, (p as MarketSell).price, (p as MarketSell).dur_btn])
		elif p is MarketMine:
			taps.append((p as MarketMine).receive)
			taps.append_array((p as MarketMine).sub_btns.values())
	for c in taps:
		_on_screen(c, "%s %s" % [what, c.name])
		_expect(c.size.y >= 63.5 and c.size.x >= 63.5, "%s %s is %s (tap >= 64)" % [what, c.name, c.size])
	var blocks: Array[Control] = [s.header]
	for t: StringName in MarketScreen.TABS:
		blocks.append(s.rail_btns[t])
	blocks.append(p if p.visible else s.offline)
	for i in blocks.size():
		for j in range(i + 1, blocks.size()):
			var a := blocks[i].get_global_rect()
			var b := blocks[j].get_global_rect()
			_expect(not a.grow(-1.0).intersects(b.grow(-1.0)), "%s: %s overlaps %s" % [what, blocks[i].name, blocks[j].name])
	if p is MarketSell and p.visible:
		var ps := p as MarketSell
		_expect(not ps.picker.get_global_rect().grow(-1.0).intersects(ps.detail.get_global_rect()), "%s: picker overlaps detail" % what)
		_expect(ps.list_btn.get_global_rect().end.y <= ps.detail.get_global_rect().end.y + 0.5, "%s: List inside the detail panel" % what)

func _on_screen(c: Control, what: String) -> void:
	var view := Rect2(Vector2.ZERO, c.get_viewport_rect().size)
	var r := c.get_global_rect()
	_expect(c.is_visible_in_tree() and view.encloses(r), "%s on screen (%s in %s)" % [what, r, view.size])

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
