class_name HudrulesShot
extends RefCounted
## HUDRULES captures (`--shot=...hudrules...png`): she bleeds, is Well Rested, has a food buff and a meal
## digesting. "expanded" opens the orders card (else the minimap badge); "tip" in the path pins the Well Rested tooltip; "combat" spawns a deinonychus beside her,
## makes "Hunt something for meat" (fight "*") the running order and starts the fight.

static func stage(hud: HuntHud) -> void:
	var tree := hud.get_tree()
	if tree.root.find_children("CharacterCreation", "CharacterCreation", true, false).size() > 0:
		for node in tree.root.find_children("CharacterCreation", "CharacterCreation", true, false):
			node.queue_free()  # a fresh capture profile: skip creation, stand her on the home island
		World.home_terrain = &"meadow"
		World.load_island(tree.current_scene, &"home_grassland", Vector3(0, 1, 18), false)
		World.finish_creation()
		tree.create_timer(1.0).timeout.connect(func () -> void: _dress(hud))
	else:
		_dress(hud)

static func _dress(hud: HuntHud) -> void:
	var p := hud.player
	if p == null:
		return
	if Game.shot_path.contains("titles"):  # TITLES captures: only a worn title over her name
		World.player_name = "Milan"
		World.pioneer_level = 6
		World.player_title = LevelDisplay.earned_titles(LevelDisplay.player_level())[-1]
		return
	p.statuses.apply(&"bleed")
	p.statuses.apply(&"well_rested")
	BuffSlots.of(p).apply(p, [{"id": "camp_stew_catalog", "group": "enhanced_ability", "group_name": "Enhanced Ability",
		"display_name": "Camp Stew: Perception +20.9", "duration": 1200.0, "stats": {"perception": {"add": 20.9}}}])
	var dig := Digestion.of(p)
	# "stomach_<state>": roasts (fullness 50) digesting so the ring shows that state (HudStomach).
	var meals := {"stomach_empty": [], "stomach_hungry": [0.5], "stomach_normal": [1.0], "stomach_full": [1.0, 0.7], "stomach_overfull": [1.0, 1.0, 1.0]}
	var picked := ""
	for k in meals:
		if Game.shot_path.contains(k):
			picked = k
	if picked == "":
		dig.schedule(&"camp_stew", 60.0, 300.0)
		dig.rows()[0]["remaining"] = 39.0  # two thirds digested-in
	for share in meals.get(picked, []):
		var row := dig.schedule(&"roast", 60.0, 300.0)
		row["remaining"] = 60.0 * float(share)
	OrdersSheet.hud_expanded = Game.shot_path.contains("expanded")
	if Game.shot_path.contains("tip"):
		hud._buff_row.pinned = "well_rested"
	if Game.shot_path.contains("mounted"):  # ride a zebraceratops: the energy bar is the mount's
		p.bonded.append(PetRecord.from_def(Data.creature(&"zebraceratops"), &"A"))
		var m := p.pets.summon(p.bonded.size() - 1)
		hud.get_tree().create_timer(0.5).timeout.connect(func () -> void:
			if is_instance_valid(m):
				p.pets.mount(m)
				m.energy = m.energy_max * 0.64)  # partly spent, so the fill and the segments both read
	if Game.shot_path.contains("combat"):
		var steps := Objectives._steps()
		for i in steps.size():
			if str((steps[i] as Dictionary).get("id", "")) == "meat":
				World.objective = i
		var c := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
		p.get_parent().add_child(c)
		c.global_position = p.global_position + Vector3(3.0, 0.0, 1.5)
		c.spawn(Data.creature(&"deinonychus"))
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # a still animal for the picture
		p.hunt.start(c)
