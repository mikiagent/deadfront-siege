extends Node
## Fresh30-minute20x interaction fixture. Not pointer, normal-speed or raid-clear proof.
func run(host: Node) -> void:
	await get_tree().create_timer(0.8).timeout
	for n in get_tree().root.find_children("CharacterCreation","CharacterCreation",true,false): n.queue_free()
	World.home_terrain=&"meadow"
	World.load_island(host,&"home_grassland",Vector3(0,1,18),false)
	await get_tree().create_timer(0.5).timeout
	var bot:=BotSurvivor.new()
	add_child(bot)
	bot.player=get_tree().get_first_node_in_group("player") as Player
	bot.minutes=30.0
	bot._last_pos=bot.player.global_position
	print("[earnedtrain] START fresh0skills bag%d coins%d no occupation; accelerated20x interactions, no items/XP/vital seeds" % [bot.player.inventory.used_slots(),World.t_stones])
	Engine.time_scale=20
	for rung in BotSurvivor.LADDER.slice(0,7): await bot._do_rung(rung)
	var cycle:=0
	while bot._t < bot.minutes*60-10:
		cycle+=1
		var before:=bot._t
		for pair in [[&"stone",6],[&"fibre_stalk",4],[&"branch",2]]:
			var why:=await bot._gather(pair[0],pair[1])
			if why!="": print("[earnedtrain] gather %s blocked=%s" % [pair[0],why])
		for rid in [&"thread",&"club",&"twine"]:
			var rec:=Crafting.recipe(rid)
			if await bot._acquire_for(rec)=="": await bot._craft(rec)
		if bot.player.inventory.used_slots() >= 15:
			var basket: Node3D = null
			for b in get_tree().get_nodes_in_group("placed_building"):
				if str(b.get("kind"))=="basket" and b.storage.used_slots()<b.storage.slot_count: basket=b; break
			if basket:
				bot.player.nav_to(bot.player._closest_nav_point(basket.global_position))
				var deadline:=bot._t+40
				while bot._t<deadline and bot.player.global_position.distance_to(basket.global_position)>2.7:
					if not await bot._beat(0.25): break
				bot.player.clear_nav()
				if bot.player.global_position.distance_to(basket.global_position)<=2.8:
					bot.player._building_interact(basket)
					for i in bot.player.inventory.slots.size():
						var st:=bot.player.inventory.slots[i]
						if st and st.def_id in [&"club",&"thread",&"twine"]:
							bot.player.ui._select(i)
							bot.player.ui._store_selected()
					bot.player.ui.hide_ui()
					print("[earnedtrain] stored surplus through writable basket UI bag%d storage%d" % [bot.player.inventory.used_slots(),basket.storage.used_slots()])
		print("[earnedtrain] cycle%d t%.1f bag%d survival%d gathering%d processing%d weapon%d tailoring%d deaths%d" % [cycle,bot._t,bot.player.inventory.used_slots(),bot.player.skills.level_of("survival"),bot.player.skills.level_of("gathering"),bot.player.skills.level_of("processing"),bot.player.skills.level_of("weapon_tools"),bot.player.skills.level_of("tailoring"),bot._deaths])
		if bot._t-before < 0.1: break
	bot._report()
	print("[earnedtrain] END skills=%s" % JSON.stringify(bot.player.skills.trees))
	get_tree().quit(0)
