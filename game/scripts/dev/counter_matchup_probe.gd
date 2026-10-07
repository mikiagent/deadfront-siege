extends Node
var player: Player
var enemy: Creature
var elapsed := 0.0
## Seeded offensive comparison with shared raid armor, not earned/tier-matched play.
var next_swing := 0.0
var next_roll := 1.5
var rolls := 0
var contact := 0
var last_hp := 0.0
var correct := false
var species: StringName = &"velociraptor"
func run(host: Node) -> void:
	seed(41)
	for arg in OS.get_cmdline_user_args():
		if arg == "--correct-kit": correct = true
		if arg.begins_with("--match-species="): species = StringName(arg.substr(16))
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false): node.queue_free()
	World.home_terrain = &"meadow"
	World.load_island(host, &"home_grassland", Vector3(0,1,12), false)
	await get_tree().create_timer(0.5).timeout
	player = get_tree().get_first_node_in_group("player") as Player
	for cr in get_tree().get_nodes_in_group("creatures"): cr.queue_free()
	player.inventory = Inventory.new(20)
	var fast := species == &"velociraptor"
	var weapon := &"barbed_knife" if (fast and correct) or (not fast and not correct) else &"bone_hammer"
	player.inventory.add(ItemStack.make(weapon,1,{},25))
	player.inventory.equip(&"weapon",weapon)
	# Shared seeded armor isolates matchup damage, not a fresh progression loadout.
	for pair in [[&"head",&"raid_helm"],[&"body",&"raid_cuirass"],[&"legs",&"raid_greaves"]]:
		player.inventory.add(ItemStack.make(pair[1],1,{},25))
		player.inventory.equip(pair[0],pair[1])
	player.skills.trees["melee"]["level"] = 25
	player.refresh_equipment_vitals()
	player.vitals.heal(999)
	last_hp = player.vitals.health
	if correct and not fast:
		player.inventory.add(ItemStack.make(&"toxin_coating",1))
		player.context_action("coat_weapon")
	await get_tree().create_timer(0.8).timeout
	player.face_world(player.global_position + Vector3(0,0,5))
	if correct and fast:
		player.inventory.add(ItemStack.make(&"rope_snare",1))
		print("[matchsetup] trap=%s" % player.place_snare(&"rope_snare"))
	var sp := Spawner.new()
	sp.species = species
	sp.count = 1
	sp.radius = 0.1
	sp.position = player.global_position + Vector3(0,0,2)
	World.runtime.add_child(sp)
	enemy = sp.spawn_now()[0]
	enemy.genetics = CreatureGenetics.from_dict({})
	enemy.health.setup(enemy.def.hp)
	player.hunt.start(enemy)
	player.hunt.hold = true
	player.hunt.auto = false
	set_physics_process(true)
var next_diag := 15.0
func _physics_process(delta: float) -> void:
	if player == null or enemy == null: return
	elapsed += delta
	if player.vitals.health < last_hp: contact += 1
	last_hp = player.vitals.health
	if elapsed > next_diag:
		next_diag += 15
		print("[matchdiag] t=%.0f gap=%.1f hp=%.0f eHP=%.0f busy=%s nav=%s roll=%s energy=%.0f fracture=%s" % [elapsed, player.global_position.distance_to(enemy.global_position), player.vitals.health,enemy.health.hp,player.anim._busy,player.nav_active,player.rolling,player.vitals.energy,player.statuses.has(&"fracture")])
	if player.dead or enemy.health.dead or elapsed > 90:
		print("[matchup] species=%s correct=%s win=%s time=%.1f hp=%.0f enemyHP=%.0f rolls=%d health_drops=%d poison=%s bleed=%s; seededL25weapon/melee and sharedL25raidarmor, not earned progression" % [species,correct,enemy.health.dead and not player.dead,elapsed,player.vitals.health,enemy.health.hp,rolls,contact,enemy.statuses.has(&"poisoned_target"),enemy.statuses.has(&"bleeding_target")])
		get_tree().quit(0)
		set_physics_process(false)
		return
	if elapsed >= next_roll and player.vitals.energy >= 15 and player.global_position.distance_to(enemy.global_position) < Hunt.melee_reach(enemy) + 0.5 and not player.anim._busy and not player.rolling:
		player.face_world(player.global_position + (player.global_position-enemy.global_position))
		player._try_roll()
		if player.rolling: rolls += 1
		next_roll = elapsed + 2
	if elapsed >= next_swing and not player.rolling and not player.anim._busy:
		player.hunt._auto_attack()
		next_swing = elapsed + 0.8
	if not player.rolling and player.global_position.distance_to(enemy.global_position) > Hunt.melee_reach(enemy):
		player.nav_to(enemy.global_position)
