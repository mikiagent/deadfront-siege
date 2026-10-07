extends Node
var player: Player
var boss: Creature
## Seeded kit, visible boss phase cues and normal actions. No guaranteed win.
var elapsed := 0.0
var rolled_cycle := -1
var stagger_seen := 0
var last_phase: StringName = &""
var hits_seen := 0
var before_hp := 0.0
func run(host: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false): node.queue_free()
	World.home_terrain = &"meadow"
	World.load_island(host,&"home_grassland",Vector3(0,1,18),false)
	await get_tree().create_timer(0.3).timeout
	player = get_tree().get_first_node_in_group("player") as Player
	for cr in get_tree().get_nodes_in_group("creatures"): cr.queue_free()
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
	var sp := Spawner.new()
	sp.species = &"tyrannosaurus"
	sp.count = 1
	sp.radius = 0.1
	sp.position = player.global_position + Vector3(5,0,0)
	World.runtime.add_child(sp)
	boss = sp.spawn_now()[0]
	boss.genetics = CreatureGenetics.from_dict({})
	boss.health.setup(boss.def.hp)
	player.hunt.start(boss)
	player.hunt.hold = true
	player.hunt.auto = false
	boss.brain.on_aggro(player)
	before_hp = boss.health.hp
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
	if player.dead or boss.health.dead or elapsed > 90:
		print("[raidwindows] close t=%.1f bossHP=%.0f playerHP=%.0f stagger=%d damage-events=%d; seeded normal AI home terrain, not earned volcanic win" % [elapsed,boss.health.hp,player.vitals.health,stagger_seen,hits_seen])
		get_tree().quit(0)
		return
	if brain.phase == &"windup":
		player.clear_nav()
		if rolled_cycle != brain.attack_number and brain.phase_left < (0.3 if brain.windup_clip == &"attack_primary" else 0.3) and not player.anim._busy:
			var tangent := (player.global_position-boss.global_position).rotated(Vector3.UP,PI/2)
			tangent.y = 0
			player.face_world(player.global_position+tangent)
			player._try_roll()
			if player.rolling: rolled_cycle = brain.attack_number
	else:
		if not player.rolling:
			if player.global_position.distance_to(boss.global_position) > Hunt.melee_reach(boss): player.nav_to(boss.global_position)
			elif (brain.phase == &"recovery" or brain.phase == &"stagger") and brain.phase_left > 0.7: player.hunt._auto_attack()
