extends Node
## Seeded loadout fight, real terrain/AI/movement/combat. No flat damage or immortality.
## Timed evasion inputs, no hidden AI/windup callbacks; seeded fixture, not earned play.
var elapsed := 0.0
var player: Player
var boss: Creature
var dodges := 0
var seen: Dictionary = {}
var last_health := 0.0
var contacts := 0
var finished := false
var next_roll := 0.0
var next_swing := 0.0
func run(host: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false): node.queue_free()
	World.home_terrain = &"meadow"
	World.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await get_tree().create_timer(0.3).timeout
	player = get_tree().get_first_node_in_group("player") as Player
	for creature in get_tree().get_nodes_in_group("creatures"): creature.queue_free()
	player.inventory = Inventory.new(20)
	for pair in [[&"weapon", &"raid_maul"], [&"head", &"raid_helm"], [&"body", &"raid_cuirass"], [&"legs", &"raid_greaves"]]:
		var s := ItemStack.make(pair[1], 1, {}, 60)
		player.inventory.add(s)
		player.inventory.equip(pair[0], pair[1])
	player.skills.trees["melee"]["level"] = 60
	player.refresh_equipment_vitals()
	player.vitals.heal(999)
	last_health = player.vitals.health
	if "--swing-cadence-probe" in OS.get_cmdline_user_args():
		var started_at := Time.get_ticks_msec()
		player.play_attack(true)
		await get_tree().create_timer(0.7).timeout
		print("[cadenceprobe] %s swing idle after0.7s" % ["PASS" if not player.anim._busy else "FAIL"])
		player._try_roll()
		print("[cadenceprobe] %s roll available after swing" % ["PASS" if player.rolling else "FAIL"])
		get_tree().quit(0)
		return
	var sp := Spawner.new()
	sp.species = &"tyrannosaurus"
	sp.count = 1
	sp.radius = 0.1
	sp.position = player.global_position + Vector3(1.8, 0, 0)
	World.runtime.add_child(sp)
	boss = sp.spawn_now()[0]
	boss.genetics = CreatureGenetics.from_dict({})
	boss.health.setup(boss.def.hp)
	print("[raidfight] fixture neutral genetics/catalogue stats")
	player.hunt.start(boss)
	player.hunt.hold = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if finished or player == null or boss == null: return
	elapsed += delta
	if player.vitals.health < last_health: contacts += 1
	last_health = player.vitals.health
	if int(elapsed) % 30 == 0 and int(elapsed-delta) != int(elapsed):
		print("[raidfight] t=%.0f bossHP=%.0f playerHP=%.0f stamina=%.0f rolls=%d contacts=%d" % [elapsed,boss.health.hp,player.vitals.health,player.vitals.energy,dodges,contacts])
		print("[raidfight] gap=%.2f busy=%s nav=%s auto=%s target=%s pos=%s boss=%s" % [player.global_position.distance_to(boss.global_position),player.anim._busy,player.nav_active,player.hunt.auto,player.hunt.target,player.global_position,boss.global_position])
	if player.dead or boss.health.dead or elapsed > 480:
		finished = true
		print("[raidfight] %s t=%.1f bossHP=%.0f playerHP=%.0f rolls=%d contacts=%d; seeded L60 gear/melee, home terrain, not earned volcanic raid" % ["PASS" if boss.health.dead and not player.dead else "PARTIAL", elapsed,boss.health.hp,player.vitals.health,dodges,contacts])
		get_tree().quit(0)
		return
	# New policy: timed swing gaps + rolls, uses player-visible animation/position only.
	player.hunt.auto = false
	player.hunt.hold = true
	if elapsed >= next_roll and not player.rolling:
		if not player.anim._busy:
			player.face_world(player.global_position + (player.global_position - boss.global_position))
			player._try_roll()
			if player.rolling:
				dodges += 1
				next_roll = elapsed + 2.0
	elif elapsed >= next_swing and not player.rolling:
		player.hunt._auto_attack()
		next_swing = elapsed + 1.0
	if not player.rolling and player.global_position.distance_to(boss.global_position) > Hunt.melee_reach(boss):
		player.nav_to(boss.global_position)
