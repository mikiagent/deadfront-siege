extends Node3D
## W3-EXCHANGE lab: the Island Market screens over the deterministic local economy
## (MarketHarness: real VaultBridge, real other-account listings, labelled a test server).
## Run windowed: Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   -- --lab=market_ui_lab --screen=buy|buy_taming|sell|my_market|confirm|offline --shot=<png> --shot-delay=6
## Skeleton (design step): seeds the economy and shows what the screen will read. B1 replaces
## _show() with MarketScreen opened from the HUD's MENU sheet (the owner's navigation).

const SCREENS := ["buy", "buy_taming", "sell", "my_market", "confirm", "offline"]

var screen := "buy"
var harness: MarketHarness
var _hud: HuntHud

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			screen = a.substr(9)
	if screen not in SCREENS:
		push_error("[market_lab] unknown --screen=%s (one of %s)" % [screen, ", ".join(SCREENS)])
		screen = "buy"
	Game.debug_overlay = false # before the HUD builds: players never see the DEBUG hex
	var kit := LabKit.build(self, 4.0)
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false) # a real island name for the header
	(kit["nav"] as Node).queue_free()
	if screen != "offline":
		# The run's own user dir (override.cfg + SaveGame.run_name convention), never the owner's.
		harness = MarketHarness.new(OS.get_user_data_dir().path_join("runs/market_ui_lab/econ"))
		harness.seed_scene()
		for f in harness.failures:
			push_error("[market_lab] harness: %s" % f)
	_show.call_deferred()

func _show() -> void:
	var lines: PackedStringArray = ["Island Market lab (skeleton) screen=%s island=%s" % [screen, MapScreen.island_name(str(World.island_id))]]
	if harness == null:
		lines.append("offline: no transport")
	else:
		var mc := harness.client()
		lines.append(mc.label())
		var w: Dictionary = (await mc.request("wallet.get")).get("r", {})
		lines.append("wallet %d (bound %d)" % [int(w.get("wallet", 0)), int(w.get("bound", 0))])
		var found: Dictionary = (await mc.request("market.search", {"page_size": 50})).get("r", {})
		for v: Dictionary in found.get("results", []):
			lines.append("%s  %s  Lv.%d  %d  by %s" % [v.id, v.key, int(v.asset.level), int(v.unit_price), v.seller_name])
	print("[market_lab] " + "\n[market_lab] ".join(lines))
	var layer := CanvasLayer.new()
	layer.layer = 96
	add_child(layer)
	var label := Label.new()
	label.text = "\n".join(lines)
	label.position = Vector2(24, 24)
	layer.add_child(label)
