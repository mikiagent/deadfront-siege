extends Node
## Seeded raid kit fixture: real craft allocation and formulas, neutral boss genetics, fixed RNG.
## Expected numbers follow W1-ITEMS scaling: base x (1 + 0.08 x 59) x tier(steel_ingot = steel 2.45).
## W2-DATA: the kit is made from steel; base values were rebased so these match the old shard-tier kit.
const MAUL_L60 := 112.0 * 5.72 * 2.45
const KIT_ARMOR_L60 := (153.0 + 357.0 + 153.0) * 5.72 * 2.45
var failures: Array[String] = []
var started := false
func check(ok: bool, label: String) -> void:
	print("[gear] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures.append(label)
## Catalog stacks as the game makes them (default attributes carry the material tier).
func stack(id: StringName, n: int = 1, level: int = 60) -> ItemStack:
	return ItemStack.make(id, n, {}, level)
func run(_host: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false):
		node.queue_free()
	var player := PlayerRegistry.local()
	player.set_physics_process(false)
	player.skills.trees["survival"]["level"] = 50
	for tree in ["weapon_tools", "tailoring", "processing", "melee"]:
		player.skills.trees[tree]["level"] = 60
	# Raid recipes need the steel rung's skill nodes (W2-DATA requires_node).
	player.skills.trees["weapon_tools"]["unlocked"].append("iron_weapons")
	player.skills.trees["tailoring"]["unlocked"].append("scute_armor")
	player.inventory = Inventory.new(40)
	player.inventory.add(stack(&"steel_ingot", 20))
	player.inventory.add(stack(&"branch", 10))
	player.inventory.add(stack(&"hide_strap", 30))
	player.inventory.add(stack(&"dried_hide", 30))
	for id in [&"raid_maul", &"raid_helm", &"raid_cuirass", &"raid_greaves"]:
		var rec := Crafting.recipe(id)
		var picks := Crafting.default_picks(player.inventory, rec)
		check(Crafting.progression_block(player, rec) == "", "%s level60 ingredients allowed" % id)
		check(Crafting.picks_valid(player.inventory, rec, picks), "%s exact ingredient allocation" % id)
		var parts := Crafting.consume_for_craft(player.inventory, rec, picks)
		var levels: Array[int] = []
		for part in parts:
			for i in part.count: levels.append(part.level)
		var out := Crafting.build_output(rec, parts[0], Crafting.crafted_level_for(rec, levels, player), parts)
		check(out.def_id == id and out.level == 60, "%s crafted output level60" % id)
		player.inventory.add(out)
		player.inventory.equip(Inventory.slot_for(out.def()), id)
	var maul := player.inventory.equipped_weapon()
	print("[gear] maul L%d %s dmg=%.1f kit armor=%.1f" % [maul.level, maul.material_tier(), maul.scaled_damage(), player.inventory.equipped_armor()])
	check(is_equal_approx(maul.scaled_damage(), MAUL_L60), "raid maul actual damage%.0f" % MAUL_L60)
	check(is_equal_approx(player.inventory.equipped_armor(), KIT_ARMOR_L60), "full kit armor%.0f" % KIT_ARMOR_L60)
	check(player.inventory.has_raid_protection(), "complete quality kit protects fracture/pinned")
	player.vitals.health = 100
	player.refresh_equipment_vitals()
	check(is_equal_approx(player.vitals.effective_max_health(), 298.0) and player.vitals.health == 100, "maxHP298 without equip heal")
	player.vitals.heal(999)
	World._save_now()
	player.vitals.equipment_health_bonus = 0
	World._load_now(get_parent())
	player.set_physics_process(false)
	check(is_equal_approx(player.vitals.health, 298.0) and player.inventory.has_raid_protection(), "save reload keeps full gear HP and equipment")
	var sp := Spawner.new()
	sp.species = &"tyrannosaurus"
	sp.count = 1
	sp.radius = 0.1
	sp.position = player.global_position + Vector3(1.5, 0, 0)
	get_parent().add_child(sp)
	var spawned := sp.spawn_now()
	var boss: Creature = spawned[0]
	boss.set_physics_process(false)
	# Rolled genetics moved the boss's attack run to run (qa-flaky-01); the fixture uses neutral IVs.
	boss.genetics = CreatureGenetics.neutral()
	if "--combat-reach-probe" in OS.get_cmdline_user_args():
		boss.global_position = player.global_position + Vector3(3.4, 0, 0)
		player.statuses.from_array([])
		player.hunt.start(boss)
		var hp := boss.health.hp
		player.hunt._auto_attack()
		check(boss.health.hp < hp, "survivor hits large body edge3.4m")
		check(Hunt.melee_reach(boss) > 3.4 and boss.brain.contact_reach() > 3.4, "both sides reach large body edge")
		boss.brain.attack_target = player
		player.vitals.heal(999)
		var before := player.vitals.health
		seed(1)
		CombatTuning.rng.seed = 1  # creature/survivor rolls go through CombatTuning.rng, which seed() does not touch
		for i in 5: boss._on_hit(&"attack_primary")
		check(player.vitals.health < before, "boss also hits edge3.4m")
		player.dead = false
		player.vitals.dead = false
		player.vitals.heal(999)
		boss.global_position = player.global_position + Vector3(9, 0, 0)
		before = player.vitals.health
		boss._on_hit(&"attack_primary")
		check(player.vitals.health == before, "windup cannot hit escaped target9m")
		player.hunt.stop()
		print("[reach] PARTIAL body-edge contact regression; evasive raid not passed; failures=%d" % failures.size())
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	seed(12345)
	CombatTuning.rng.seed = 12345
	CreatureAttack._apply_token(&"fracture", &"attack_primary", player, boss)
	CreatureAttack._apply_token(&"pinned", &"attack_primary", player, boss)
	CreatureAttack._apply_token(&"deafened", &"attack_primary", player, boss)
	check(not player.statuses.has(&"fracture") and not player.statuses.has(&"pinned") and player.statuses.has(&"deafened"), "kit keeps deafened, prevents fracture/pinned")
	if "--raid-gear-shot" in OS.get_cmdline_user_args():
		player.ui.bind(player.inventory, player)
		player.ui.visible = true
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/dfs-raid-gear.png")
		get_tree().quit(0)
		return
	# The kit's armour outweighs the bite, so every hit is the 5 % floor, x1.5 on a crit.
	var cap := boss.attack_for(false) * 0.05 * 1.5 + 0.01
	print("[gear] boss attack=%.1f floor=%.1f crit cap=%.2f" % [boss.attack_for(false), boss.attack_for(false) * 0.05, cap])
	var hits := 0
	var safety := 0
	while not player.dead and safety < 40:
		var before := player.vitals.health
		CreatureAttack._deal_damage(boss, player)
		var dealt := before - player.vitals.health
		if dealt > 0:
			hits += 1
			check(dealt <= cap, "real boss damage capped only by existing floor/crit")
		safety += 1
	check(player.dead and hits >= 4 and hits <= 6, "real boss contact kills in4-6 landed hits")
	player.inventory.unequip(&"head")
	check(not player.inventory.has_raid_protection(), "incomplete kit loses status protection")
	var inv := Inventory.new(10)
	inv.add(stack(&"steel_ingot", 4, 10))
	inv.add(stack(&"branch", 2, 10))
	inv.add(stack(&"hide_strap", 4, 10))
	player.inventory = inv
	check(Crafting.progression_block(player, Crafting.recipe(&"raid_maul")) != "", "low level ingredients cannot make raid gear")
	print("[gear] PARTIAL real formulas/craft allocation; acquisition, station movement and raid evasions untested; failures=%d" % failures.size())
	boss.free()
	get_tree().quit(0 if failures.is_empty() else 1)
