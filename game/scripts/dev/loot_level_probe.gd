extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("[lootlevel] %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures += 1
func run(host: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	for n in get_tree().root.find_children("CharacterCreation","CharacterCreation",true,false): n.queue_free()
	World.home_terrain = &"meadow"
	World.load_island(host,&"volcanic_60",Vector3(0,1,18),false)
	await get_tree().create_timer(0.5).timeout
	var boss: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		if n.def.id == &"tyrannosaurus": boss=n; break
	check(boss != null,"actual volcanic boss exists; fixture, not earned kill")
	if boss == null: get_tree().quit(1); return
	boss.set_physics_process(false)
	var original := boss.level
	for lvl in [1,55,60]:
		boss.level = lvl
		var corpse := Corpse.new()
		corpse.setup(boss)
		var hide := 0
		for st in corpse.loot.slots:
			if st == null: continue
			check(st.level == lvl,"boss%d drop %s level%d" % [lvl,st.def_id,st.level])
			if st.def().has_category(&"hide"): hide=st.level
		check(hide == lvl,"hide carries source creature quality%d" % lvl)
		var levels: Array[int] = []
		for i in 6: levels.append(60)
		for i in 4: levels.append(hide)
		print("[lootlevel] helm all-other-inputs60 hide%d -> level%d" % [hide,ProgressionScaling.crafted_level(levels,60,60)])
		corpse.free()
	boss.level=original
	boss.statuses.apply(&"poisoned_target")
	var spoiled:=Corpse.new()
	spoiled.setup(boss)
	for st in spoiled.loot.slots:
		if st: check(not st.def().has_category(&"meat"),"poison fixture excludes meat: %s" % st.def_id)
	spoiled.free()
	print("[lootlevel] done failures=%d seeded corpse creation, no hunt or earning proof" % failures)
	get_tree().quit(0 if failures == 0 else 1)
