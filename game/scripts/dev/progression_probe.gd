extends Node
## Fresh-state harbour-button fixture. Seeded proficiency/coins isolate UI gates and travel;
## this does NOT claim earned progression, raid combat, or pointer coverage.
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print("[progression] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func button(ui: CanvasLayer, id: String) -> Button:
	for node in ui.find_children("*", "Button", true, false):
		if str(node.get_meta("route_id", "")) == id and not node.is_queued_for_deletion():
			return node as Button
	return null

func run(host: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false):
		node.queue_free()
	World.home_terrain = &"meadow"
	World.visited_islands.clear()
	World.raid_victory = false
	World.objective = 0
	World.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await get_tree().create_timer(0.5).timeout
	var player := get_tree().get_first_node_in_group("player") as Player
	var ui: CanvasLayer = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
	World.t_stones = 100
	player.skills.trees["survival"]["level"] = 0
	ui.call("show_harbour")
	await get_tree().process_frame
	check(World.harbour_routes().size() == 14, "all 14 outbound catalogue routes listed")
	check(button(ui, "temperate_25").disabled, "fresh Survival0 cannot depart tier25")
	player.skills.add_xp("gathering", 20)
	check(player.skills.level_of("survival") == 1, "ordinary gathering XP mirrors into Survival")
	player.skills.trees["survival"]["level"] = 60
	World.t_stones = 0
	ui.call("show_harbour")
	await get_tree().process_frame
	check(button(ui, "temperate_25").disabled, "insufficient coins disables departure")
	World.t_stones = 100
	if "--progression-shot" in OS.get_cmdline_user_args():
		player.skills.trees["survival"]["level"] = 20
		ui.call("show_harbour")
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/dfs-harbour-ladder.png")
		get_tree().quit(0)
		return
	for id in World.harbour_routes():
		var need := World.route_level(StringName(id))
		player.skills.trees["survival"]["level"] = need - 1
		ui.call("show_harbour")
		await get_tree().process_frame
		check(button(ui, id).disabled, "%s below Survival%d locked" % [id, need])
		player.skills.trees["survival"]["level"] = need
		ui.call("show_harbour")
		await get_tree().process_frame
		var route := button(ui, id)
		check(route != null and not route.disabled, "%s threshold enabled" % id)
		var coins := World.t_stones
		route.pressed.emit()
		await get_tree().create_timer(0.7).timeout
		check(str(World.island_id) == id and World.t_stones == coins - 5, "%s UI departure and 5T debit" % id)
		check(World.visited_islands.has(id), "%s voyage recorded" % id)
		ui.call("show_harbour")
		await get_tree().process_frame
		button(ui, "home").pressed.emit()
		await get_tree().create_timer(0.7).timeout
		check(World.is_home() and World.t_stones == coins - 5, "free UI return from %s" % id)
	# Validate raid attribution without pretending to fight it.
	World.island_id = &"volcanic_60"
	World.record_raid_kill(&"tyrannosaurus", null)
	check(not World.raid_victory, "unattributed boss death does not win")
	World.island_id = &"home_grassland"
	World.record_raid_kill(&"tyrannosaurus", player)
	check(not World.raid_victory, "wrong-island kill does not win")
	World.island_id = &"volcanic_60"
	World.record_raid_kill(&"tyrannosaurus", player)
	check(World.raid_victory, "credited volcanic kill wins (fixture, combat untested)")
	World.objective = Data.world_objectives.size() - 1
	check(Objectives.current(player)["done"], "final standing order reads victory")
	World.island_id = &"home_grassland"
	World._save_now()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(World.SAVE_PATH))
	check(bool(data.get("raid_victory", false)) and data.get("visited_islands", {}).size() == 15, "save includes victory and all voyages")
	World.raid_victory = false
	World.visited_islands.clear()
	World._load_now(host)
	check(World.raid_victory and World.visited_islands.size() == 15, "save reload retains victory and voyages")
	if "--progression-shot" in OS.get_cmdline_user_args():
		player.skills.trees["survival"]["level"] = 20
		ui.call("show_harbour")
		await get_tree().create_timer(2.0).timeout
		var image := get_viewport().get_texture().get_image()
		image.save_png("/tmp/dfs-harbour-ladder.png")
	print("[progression] PARTIAL seeded gate fixture, earned loop and raid fight untested; failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
