extends Node3D
## BAGUI look check: the bag panel (right) with the item card (left) on a perk-tier log, a chest
## open on its own tab with a deposit batch, and the Island Market Sell grid (test server) with the
## equipped knife in red. One PNG each at the window size.
##   godot --path game --resolution 1600x900 --position 6000,3000 -- --lab=bagui_lab --shot-dir=/tmp/bagui
## Prints "[baguilab] shot <path>", "[baguilab] rummage=<clip>" and "[baguilab] DONE".
var player: Player
var shot_dir := "/tmp/dfs-bagui"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
	var kit := LabKit.build(self, 60.0)
	player = kit["player"]
	Game.debug_overlay = false
	# As main.gd: the bag is a modal on layer 96, over the HUD (LabKit puts it under).
	var modals := CanvasLayer.new()
	modals.layer = 96
	add_child(modals)
	player.ui.reparent(modals)
	DirAccess.make_dir_recursive_absolute(shot_dir)
	_run.call_deferred()

func _tag() -> String:
	var v := get_viewport().get_visible_rect().size
	return "%dx%d" % [int(v.x), int(v.y)]

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var p := shot_dir.path_join("%s_%s.png" % [name, _tag()])
	get_viewport().get_texture().get_image().save_png(p)
	print("[baguilab] shot %s" % p)

func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	World.warp_gems = 1363
	World.t_stones = 9017
	var inv := player.inventory
	inv.add(ItemStack.make(&"basic_bag", 1, {"tint": "#6b5a3e"}, 20))
	inv.equip_at(inv.find_first(&"basic_bag"))
	var log := ItemStack.make(&"wood_log", 1, {"black_sheen": 4, "split_easily": 2, "firm": 6}, 51)
	inv.add(log)
	for id: StringName in [&"stone", &"berry", &"bone", &"metal_shard", &"stone_knife", &"branch", &"fibre_stalk", &"forager_hood", &"campfire_kit", &"plank"]:
		for k in 3:
			inv.add(ItemStack.make(id, 1, {}, 3 + k * 9))
	inv.slots[inv.find_first(&"stone")].set_flag(&"locked", true)
	var ui := player.ui
	ui.visible = true
	ui.rebuild()
	await get_tree().create_timer(0.6).timeout
	print("[baguilab] rummage=%s" % player.anim.current_clip)
	ui._on_bag_slot_tapped(inv.find_first(&"wood_log"))
	await _shot("bag_detail")
	# A chest: its own tab; a batch marked for Deposit.
	var chest := Inventory.new(105)
	for k in 6:
		chest.add(ItemStack.make(&"stone", 1, {}, 2 + k))
	ui.show_storage(chest, player, {"title": "Chest", "allow_deposit": true})
	ui._show_page("bag", "bag")
	ui._on_toggle_multi()
	for i in range(1, 5):
		ui._grid.toggle_multi(i)
	ui._update_batch_bar()
	await _shot("chest_bag_tab")
	ui._on_batch_store()
	ui._set_multi_mode(false)
	ui._show_page("bag", "store")
	await _shot("chest_tab")
	ui.hide_ui()
	await get_tree().create_timer(0.3).timeout
	print("[baguilab] after close=%s" % player.anim.current_clip)
	# The market Sell grid on the local test server.
	var h := MarketHarness.new(OS.get_user_data_dir().path_join("bagui_lab_econ"))
	h.seed_scene()
	MarketScreen.test_client = h.client()
	var host := Node.new()
	add_child(host)
	var s := MarketScreen.open_for(host, &"sell")
	await get_tree().process_frame
	s.show_tab(&"sell")
	var sell: MarketSell = s.panes[&"sell"]
	await _shot("market_sell")
	print("[baguilab] sell blocked=%s going=%d" % [sell.grid.blocked, sell.going])
	print("[baguilab] DONE")
	get_tree().quit(0)
