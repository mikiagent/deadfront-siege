extends "res://scripts/dev/ui_real_capture_lab.gd"
## UI screenshot pass for the docs wiki and the art review (tools/ui_screens.sh runs it). Walks every
## screen the UI gate lab opens (its gates are ignored here: shots only), then the screens it does not
## open (fatigue, domain, comm center, build, claim, food and bag inspect, island pick), and saves
## <name>.png per screen in --shot-dir. --canvas=WxH fixes the logical canvas (default 844x390, the
## landscape phone), so a 2x window (--resolution 1688x780) draws the phone layout at 2x pixels.
## Windowed: --resolution 1688x780 -- --lab=ui_screens_lab --shot-dir=DIR [--canvas=844x390]
## Prints "[uiscreens] shot <path>" per screen, then "[uiscreens] DONE <n> shots" (exit 0).

var _count := 0

func _ready() -> void:
	var canvas := Vector2i(844, 390)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			canvas = Vector2i(int(wh[0]), int(wh[1]))
	DisplayMode.canvas_override = canvas
	DisplayMode.fit(get_tree().root)
	super._ready()

## Shot only, named by screen (the gate lab's checks are skipped).
func _capture(shot_name: String, _roots: Array, _logical: Vector2, _gated: bool = true) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("[uiscreens] %s: no pixels (run windowed, not --headless)" % shot_name)
		return
	var path := _out.path_join(shot_name + ".png")
	img.save_png(path)
	_count += 1
	print("[uiscreens] shot %s" % path)

## The gate's live-resize check is not a screen.
func _resize(_logical: Vector2) -> void:
	pass

func _finish(_phone: bool, logical: Vector2) -> void:
	await _extra_screens(logical)
	print("[uiscreens] DONE %d shots in %s" % [_count, _out])
	get_tree().quit(0)

func _extra_screens(logical: Vector2) -> void:
	# fatigue: "what is tiring you", from a tap on the HUD fatigue gauge
	var fatigue := _hud.get("_fatigue_panel") as FatiguePanel
	if fatigue:
		fatigue.toggle()
		await _settle()
		await _capture("fatigue", [], logical)
		fatigue.toggle()
	# claim: the CLAIM confirm panel
	_hud.open_claim_confirm()
	await _settle()
	if _hud.claim_panel_open():
		await _capture("claim", [], logical)
	_hud.claim_confirm_cancel()
	# domain (menu -> Domain), then its comm center contribution panel
	_hud.call("_open_domain")
	await _settle()
	var domain := _hud.domain_screen()
	if domain and domain.is_open():
		await _capture("domain", [], logical)
		domain.call("_on_center")
		await _settle()
		await _capture("comm_center", [], logical)
		if domain.center_ui:
			domain.center_ui.close()
		domain.close()
	# market: the Island Market (menu -> Island Market), offline state
	var market := _hud.call("open_market", &"buy") as Control
	if market:
		await _settle()
		await _capture("market", [], logical)
		market.call("close_screen")
	# build: the construction menu (menu -> Build)
	var build := BuildUI.ensure(_player)
	if build:
		build.open()
		await _settle()
		await _capture("build", [], logical)
		build.toggle()
	# bag with a food and a bag selected: the food and bag inspect panels
	var inv := _player.inventory
	var food_i := _free_slot(inv)
	if food_i >= 0:
		inv.slots[food_i] = ItemStack.make(&"grilled_meat", 3)
	var bag_i := _free_slot(inv)
	if bag_i >= 0:
		inv.slots[bag_i] = ItemStack.make(&"basic_bag", 1)
	_player.ui.visible = true
	_player.ui.call("rebuild")
	await _settle()
	for pair in [[food_i, "bag_food_inspect", "_on_inspect_food", "_food_inspector"], [bag_i, "bag_bag_inspect", "_on_inspect_bag", "_bag_inspector"]]:
		if int(pair[0]) < 0:
			continue
		_player.ui.call("_select", int(pair[0]))
		_player.ui.call(pair[2])
		await _settle()
		await _capture(pair[1], [], logical)
		var panel := _player.ui.get(pair[3]) as Control
		if panel:
			panel.visible = false
	_player.ui.visible = false
	# island pick: the permanent tamed-island choice after character creation
	var pick := IslandPick.instance_on(self)
	pick.open()
	await _settle()
	await _capture("island_pick", [], logical)
	pick.visible = false

func _settle() -> void:
	await _frames(3)
	await get_tree().create_timer(0.3).timeout

static func _free_slot(inv: Inventory) -> int:
	for k in inv.slot_count:
		if inv.slots[k] == null:
			return k
	return -1
