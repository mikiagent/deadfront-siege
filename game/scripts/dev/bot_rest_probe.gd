extends Node
func run(host: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false): node.queue_free()
	World.home_terrain = &"meadow"
	World.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)
	await get_tree().create_timer(0.5).timeout
	var bot := BotSurvivor.new()
	add_child(bot)
	bot.player = get_tree().get_first_node_in_group("player") as Player
	bot._last_pos = bot.player.global_position
	var spot: Node3D = get_tree().get_first_node_in_group("sleep_spot")
	# Default isolates sleep. The opt-in stock location reproduces a Floor contact stall.
	var stock_position := "--bot-rest-stock-position" in OS.get_cmdline_user_args()
	bot.player.global_position = Vector3(5.02825, 1.37166, -6.268273) if stock_position else spot.global_position + Vector3(0,1,2)
	bot.player.vitals.fatigue = 90
	bot.player.vitals.energy = 0
	bot.player._last_hit_taken_s = -999
	var why := await bot._recover_for_work()
	print("[restprobe] %s reason=%s fatigue=%.1f energy=%.1f elapsed=%.1f; seeded fatigue fixture, stock-position=%s, not earned progression" % ["PASS" if why == "" and bot.player.vitals.fatigue < 10 and bot.player.vitals.energy > 25 else "PARTIAL", why,bot.player.vitals.fatigue,bot.player.vitals.energy,bot._t, stock_position])
	get_tree().quit(0)
