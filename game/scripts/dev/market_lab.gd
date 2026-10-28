extends Node
## UIMARKET screenshots: the Island Market offline (the player build), then Buy, the buy confirm,
## My Market and Sell on the local test server (MarketHarness, labelled as such on the rail).
## Windowed: --resolution WxH -- --lab=market_lab --shot-dir=DIR [--canvas=WxH]
## Saves market_<screen>_<W>x<H>.png and prints "[marketlab] DONE <n>".

var _out := "user://market_shots"
var _canvas := Vector2i(1600, 900)
var _n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			_canvas = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayMode.canvas_override = _canvas
	DisplayMode.fit(get_tree().root)
	_run.call_deferred()

func _run() -> void:
	MarketScreen.test_client = null
	var s := MarketScreen.open_for(self, &"buy")
	await _shot("offline")
	var h := MarketHarness.new(OS.get_user_data_dir().path_join("market_lab_econ"))
	h.seed_scene()
	if not h.failures.is_empty():
		push_warning("[marketlab] harness: %s" % ", ".join(h.failures))
	MarketScreen.test_client = h.client()
	s.open(&"buy")
	var buy: MarketBuy = s.panes[&"buy"]
	if buy.rows.size() > 1:
		buy.rows[1].picked = true
	await _shot("buy")
	for r in buy.rows:
		if int(r.v.listing.seller) != h.VIEWER:
			buy.open_listing(r.v)
			break
	await _shot("buy_confirm")
	s.confirm.visible = false
	s.show_tab(&"my_market")
	await _shot("my_market")
	s.show_tab(&"sell")
	var sell: MarketSell = s.panes[&"sell"]
	for r in sell.rows:
		if not r.disabled and str(r.v.icon) == "stone_knife_work":
			sell.pick(r)
	sell.price.text = "30"
	sell._update()
	await _shot("sell")
	MarketScreen.test_client = null
	MarketHarness.release_loggers()
	print("[marketlab] DONE %d" % _n)
	get_tree().quit(0)

func _shot(what: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var path := _out.path_join("market_%s_%dx%d.png" % [what, _canvas.x, _canvas.y])
	img.save_png(path)
	_n += 1
	print("[marketlab] shot %s" % path)
