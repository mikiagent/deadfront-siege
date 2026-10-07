extends Node
var player: Player
var boss: Creature
var elapsed := 0.0
## Seeded gear/rest/arena entry on actual volcanic boss. Normal walking/attacks only.
var rolled_cycle := -1
var stagger_seen := 0
var last_phase: StringName = &""
var hits_seen := 0
var before_hp := 0.0
func run(host: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false): node.queue_free()
	World.raid_victory = false
	World.home_terrain = &"meadow"
	World.load_island(host,&"volcanic_60",Vector3(0,1,18),false)
	await get_tree().create_timer(0.3).timeout
	player = get_tree().get_first_node_in_group("player") as Player
	# Keep real island creatures and select the actual far-shore boss.
	for cr in get_tree().get_nodes_in_group("creatures"):
		if cr.def.id == &"tyrannosaurus": boss = cr
	player.inventory = Inventory.new(25)
	var correct := not "--tyrant-wrong-kit" in OS.get_cmdline_user_args()
	for pair in [[&"weapon",&"raid_maul" if correct else &"barbed_knife"],[&"head",&"raid_helm"],[&"body",&"raid_cuirass"],[&"legs",&"raid_greaves"]]:
		player.inventory.add(ItemStack.make(pair[1],1,{},60))
		player.inventory.equip(pair[0],pair[1])
	if correct:
		player.inventory.add(ItemStack.make(&"toxin_coating",1))
		player.coat_weapon()
	player.skills.trees["melee"]["level"] = 60
	player.refresh_equipment_vitals()
	player.vitals.heal(999)
	# Seeded rested fixture, not a survival or earned-supplies claim.
	player.vitals.energy = player.vitals.max_energy
	player.vitals.fatigue = 0
	print("[raidwindows] rested seed energy=%.0f fatigue=%.0f" % [player.vitals.energy,player.vitals.fatigue])
	if boss == null:
		print("[raidwindows] BLOCKED no real volcanic boss")
		get_tree().quit(1)
		return
	# Seeded arena entry isolates combat. Actual terrain/population remain live.
	player.global_position = boss.global_position+Vector3(4,1,0)
	boss.genetics = CreatureGenetics.from_dict({})
	boss.health.setup(boss.def.hp)
	if "--tyrant-varied-genetics" in OS.get_cmdline_user_args():
		var rng := RandomNumberGenerator.new()
		rng.seed = 61007
		boss.genetics = CreatureGenetics.roll(rng)
		boss.health.setup(boss.stat_value(&"health"))
	print("[raidwindows] real volcanic boss pos=%s creatures=%d hp=%.0f attack=%.1f defense=%.1f genetics=%s" % [boss.global_position,get_tree().get_nodes_in_group("creatures").size(),boss.health.max_hp,boss.attack_for(),boss.defense_for(),boss.genetics.to_dict()])
	player.hunt.start(boss)
	player.hunt.hold = true
	player.hunt.auto = false
	boss.brain.on_aggro(player)
	before_hp = boss.health.hp
	if "--tyrant-accelerated" in OS.get_cmdline_user_args(): Engine.time_scale = 10
	print("[raidwindows] kit=%s" % ["blunt+three-coated-hits" if correct else "cut-no-poison"])
	set_physics_process(true)
func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss) or player == null: return
	elapsed += delta
	var brain := boss.brain as TyrantBrain
	if brain.phase != last_phase:
		if brain.phase == &"stagger": stagger_seen += 1
		print("[raidwindows] t=%.1f phase=%s count=%d bossHP=%.0f playerHP=%.0f" % [elapsed,brain.phase,brain.counter_hits,boss.health.hp,player.vitals.health])
		last_phase = brain.phase
	if boss.health.hp < before_hp: hits_seen += 1
	before_hp = boss.health.hp
	if player.dead or boss.health.dead or elapsed > (90 if "--tyrant-normal-check" in OS.get_cmdline_user_args() else 700):
		print("[raidwindows] close t=%.1f bossHP=%.0f playerHP=%.0f stagger=%d damage-events=%d; seeded normal AI actual volcanic terrain/boss; seeded gear/rest/arena entry, not earned progression" % [elapsed,boss.health.hp,player.vitals.health,stagger_seen,hits_seen])
		for key in ["move_left","move_right","move_up","move_down"]: Input.action_release(key)
		get_tree().quit(0)
		return
	for key in ["move_left","move_right","move_up","move_down"]: Input.action_release(key)
	if brain.phase == &"windup":
		player.clear_nav()
		var away := player.global_position-boss.global_position
		away.y = 0
		var cam := get_viewport().get_camera_3d()
		var right := cam.global_basis.x
		var back := cam.global_basis.z
		right.y = 0; back.y = 0
		var u := away.normalized().dot(right.normalized())
		var v := away.normalized().dot(back.normalized())
		if away.length() < 4.5:
			Input.action_press("move_right" if u >= 0 else "move_left",absf(u))
			Input.action_press("move_down" if v >= 0 else "move_up",absf(v))
	else:
		if not player.rolling:
			if player.global_position.distance_to(boss.global_position) > Hunt.melee_reach(boss): player.nav_to(boss.global_position)
			elif (brain.phase == &"recovery" or brain.phase == &"stagger") and brain.phase_left > 0.55: player.hunt._auto_attack()
