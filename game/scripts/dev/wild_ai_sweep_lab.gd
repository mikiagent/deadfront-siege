extends Node3D
## Headless sweep of the wild AI across every species (W1-AI acceptance). Prints one
## "[aisweep] <check> ..." line per check, then "[aisweep] PASS" or FAIL lines, and quits 0/1.
## Sections run one after another on one big flat floor, then on the temperate_25 island.

const FLOOR := 320.0
const WALK := 5.5 ## survivor walk speed (player.gd walk_speed)

var player: Player
var kit: Dictionary
var failures: Array[String] = []

func _ready() -> void:
	kit = LabKit.build(self, FLOOR)
	player = kit["player"]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	Game.debug_overlay = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _roam_all()  # also loads every species' model, so perf below measures no first loads
	await _perf(24, 2.0)
	await _perf(120, 8.0)
	await _sleep_and_wake()
	await _lone_flight()
	await _pet_bite_flight()
	await _pack_walkout()
	await _pet_reach_giants()
	_level_stats()
	await _island_levels_and_corpse()
	if failures.is_empty():
		print("[aisweep] PASS")
	else:
		for f in failures:
			print("[aisweep] FAIL %s" % f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)

func _spawn(id: StringName, at: Vector3, pack: int = 0) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = at
	# Average IVs (100 % speed): the sweep tests the AI, not the genetics dice. A low-IV
	# zebraceratops (85 % speed) flees at 5.4 m/s and a walking survivor does catch it.
	c.genetics = CreatureGenetics.neutral()
	c.spawn(Data.creature(id), &"", pack)
	return c

func _species() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Data.creatures:
		out.append(StringName(id))
	out.sort()
	return out

## Clears the floor between sections and brings the survivor back if a section killed her
## (a dead survivor is no prey, which would blind every later check).
func _clear() -> void:
	if player.dead:
		player.respawn()
	player.vitals.revive(1.0)
	for n in get_tree().get_nodes_in_group("creatures") + get_tree().get_nodes_in_group("corpse"):
		n.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Ring of creatures 45 m out: inside the 60 m AI LOD, outside every perception radius.
func _ring(ids: Array[StringName], radius: float = 45.0) -> Array[Creature]:
	var out: Array[Creature] = []
	for i in ids.size():
		var ang := TAU * float(i) / float(ids.size())
		out.append(_spawn(ids[i], Vector3(cos(ang), 0.0, sin(ang)) * radius))
	return out

func _roam_all() -> void:
	Game.time_of_day = 0.40
	player.global_position = Vector3(0, 1, 0)
	var ids := _species()
	var cs := _ring(ids)
	var start: Array[Vector3] = []
	var far: Array[float] = []
	for c in cs:
		start.append(c.global_position)
		far.append(0.0)
	# Farthest it got from its start: a roam that loops back home still roamed.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		await get_tree().physics_frame
		for i in cs.size():
			far[i] = maxf(far[i], _flat(start[i], cs[i].global_position))
	var stuck: Array[String] = []
	for i in cs.size():
		var d := far[i]
		if d < 0.5:
			stuck.append("%s=%.2f" % [cs[i].def.id, d])
	print("[aisweep] roam species=%d stuck=%s" % [cs.size(), stuck])
	_check(cs.size() == 19, "expected 19 species, found %d" % cs.size())
	_check(stuck.is_empty(), "species roamed < 0.5 m in 10 s: %s" % [stuck])
	await _clear()

func _herbivores() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _species():
		var row: Dictionary = (Data.creature_ai.get("archetypes", {}) as Dictionary).get(str(Data.creature(id).archetype), {})
		if bool(row.get("is_herbivore", false)):
			out.append(id)
	return out

func _sleep_and_wake() -> void:
	Game.time_of_day = 0.05
	player.global_position = Vector3(0, 1, 0)
	var cs := _ring(_herbivores())
	await _wait(1.0)
	var asleep := 0
	for c in cs:
		if c.brain.state == &"sleep":
			asleep += 1
	_check(asleep == cs.size(), "only %d/%d herbivores asleep at night" % [asleep, cs.size()])
	# Wake by proximity: the survivor stands 2 m from the first sleeper's body.
	var sleeper := cs[0]
	var to_p := (Vector3.ZERO - sleeper.global_position).normalized()
	player.global_position = sleeper.global_position + to_p * (sleeper.body_radius() + 2.0) + Vector3.UP
	var t0 := Time.get_ticks_msec()
	while sleeper.brain.state == &"sleep" and Time.get_ticks_msec() - t0 < 1500:
		await get_tree().physics_frame
	var wake_s := float(Time.get_ticks_msec() - t0) / 1000.0
	print("[aisweep] wake_near species=%s state=%s wake_s=%.2f" % [sleeper.def.id, sleeper.brain.state, wake_s])
	_check(sleeper.brain.state != &"sleep" and wake_s <= 1.0, "%s did not wake within 1 s of a survivor at 2 m (%.2f s)" % [sleeper.def.id, wake_s])
	player.global_position = Vector3(0, 1, 0)
	# Dawn wakes everyone else.
	var start: Array[Vector3] = []
	for c in cs:
		start.append(c.global_position)
	Game.time_of_day = 0.25
	var far: Array[float] = []
	far.resize(cs.size())
	far.fill(0.0)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 10000:
		await get_tree().physics_frame
		for i in cs.size():
			far[i] = maxf(far[i], _flat(start[i], cs[i].global_position))
	var bad: Array[String] = []
	for i in range(1, cs.size()):
		var d: float = far[i]
		if cs[i].brain.state == &"sleep" or d < 1.0:
			bad.append("%s:%s/%.2f" % [cs[i].def.id, cs[i].brain.state, d])
	print("[aisweep] dawn herbivores=%d still_or_asleep=%s" % [cs.size() - 1, bad])
	_check(bad.is_empty(), "herbivores did not wake and move >= 1 m within 10 s of dawn: %s" % [bad])
	Game.time_of_day = 0.40
	await _clear()

## A lone zebraceratops chased by a survivor walking at 5.5 m/s for 10 s.
func _lone_flight() -> void:
	Game.time_of_day = 0.40
	var zeb := _spawn(&"zebraceratops", Vector3(0, 0, 0))
	var home := zeb.spawn_home
	player.global_position = Vector3(-6, 1, 0)
	var t := 0.0
	while t < 10.0:
		var dt := get_physics_process_delta_time()
		await get_tree().physics_frame
		t += dt
		var to := zeb.global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.5:
			player.global_position += to.normalized() * WALK * dt
	var ran := _flat(zeb.global_position, home)
	var ahead := _flat(zeb.global_position, player.global_position)
	var from_home := _flat(zeb.global_position, home)
	print("[aisweep] lone_flight ahead=%.2f from_home=%.2f avg_mps=%.2f state=%s" % [ahead, from_home, ran / 10.0, zeb.brain.state])
	_check(ahead >= 8.0 and from_home >= 25.0, "lone zebraceratops flight ahead=%.2f from_home=%.2f (want >= 8, >= 25)" % [ahead, from_home])
	await _clear()

## A pet bites a herbivore while the survivor is 90 m off: it runs from the pet, not the survivor.
func _pet_bite_flight() -> void:
	player.global_position = Vector3(0, 1, 90)
	var herb := _spawn(&"zebraceratops", Vector3(0, 0, 0))
	var pet := _spawn(&"velociraptor", Vector3(-1.7, 0, 0))
	pet.become_pet(PetRecord.from_def(pet.def, &"normal"))
	(pet.brain as PetBrain).order(&"attack", herb)
	var pet0 := pet.global_position
	var herb0 := herb.global_position
	var bitten := [false]
	herb.health.damaged.connect(func (_a: float, s: Node) -> void: bitten[0] = bitten[0] or s == pet)
	var t0 := Time.get_ticks_msec()
	while not bitten[0] and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().physics_frame
	# Best progress away over 5 s: a crit bite can knock it down for a moment first.
	var away := 0.0
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 5000:
		await get_tree().physics_frame
		away = maxf(away, (herb.global_position - herb0).dot((herb0 - pet0).normalized()))
	print("[aisweep] pet_bite bitten=%s away_from_pet=%.2f state=%s target_is_pet=%s" % [bitten[0], away, herb.brain.state, herb.brain.attack_target == pet])
	_check(bitten[0] and away >= 1.0, "bitten herbivore did not move away from the pet (bitten=%s away=%.2f)" % [bitten[0], away])
	await _clear()

## Same-species raptor pack engages, then the survivor walks out at 5.5 m/s for 10 s.
func _pack_walkout() -> void:
	player.global_position = Vector3(0, 1, 0)
	var pack: Array[Creature] = []
	for i in 3:
		pack.append(_spawn(&"velociraptor", Vector3(6.0, 0, -1.5 + 1.5 * float(i)), 41))
	await get_tree().physics_frame
	var leader: Creature = pack[0].brain._pack_leader()
	var changes := [0]
	var trail: Array[String] = []
	for c in pack:
		if c != leader:
			c.brain.state_changed.connect(func (_p: StringName, n: StringName) -> void:
				changes[0] += 1
				trail.append(str(n)))
	await _wait(1.0)
	var engaged := leader.brain.state
	changes[0] = 0  # count only the walk-out, not the first engagement
	trail.clear()
	var lines0 := CreatureBrain.debug_lines
	var t := 0.0
	while t < 10.0:
		var dt := get_physics_process_delta_time()
		await get_tree().physics_frame
		t += dt
		player.global_position += Vector3(-WALK * dt, 0, 0)
	var lines := CreatureBrain.debug_lines - lines0
	print("[aisweep] pack_walkout engaged=%s follower_changes=%d trail=%s debug_lines=%d" % [engaged, changes[0], trail, lines])
	_check(changes[0] <= 6, "raptor followers changed state %d times in 10 s (want <= 6)" % changes[0])
	_check(lines == 0, "AI printed %d debug lines with the overlay off" % lines)
	await _clear()

## A velociraptor pet ordered onto a triceratops and onto a T. rex lands damage within 8 s.
func _pet_reach_giants() -> void:
	player.global_position = Vector3(0, 1, -40)
	for id in [&"triceratops", &"tyrannosaurus"]:
		var giant := _spawn(id, Vector3(0, 0, 0))
		giant.brain.process_mode = Node.PROCESS_MODE_DISABLED  # a punching bag, not a fight
		var pet := _spawn(&"velociraptor", Vector3(-giant.body_radius() - 4.0, 0, 0))
		pet.become_pet(PetRecord.from_def(pet.def, &"normal"))
		(pet.brain as PetBrain).order(&"attack", giant)
		var hp0 := giant.health.hp
		var t0 := Time.get_ticks_msec()
		while giant.health.hp >= hp0 and Time.get_ticks_msec() - t0 < 8000:
			await get_tree().physics_frame
		var dmg := hp0 - giant.health.hp
		print("[aisweep] pet_reach target=%s damage=%.1f s=%.2f" % [id, dmg, float(Time.get_ticks_msec() - t0) / 1000.0])
		_check(dmg > 0.0, "velociraptor pet dealt 0 damage to %s in 8 s" % id)
		await _clear()

## Mixed species in packs of three, 20-55 m round the survivor (inside the LOD radius, so
## every brain is live: this is the worst case, not the frozen one).
func _perf(n: int, budget_ms: float) -> void:
	Game.time_of_day = 0.40
	player.global_position = Vector3(0, 1, 0)
	var ids := _species()
	for i in n:
		var ang := TAU * float(i) / float(n)
		var r := 20.0 + 35.0 * float(i % 7) / 6.0
		_spawn(ids[(i / 3) % ids.size()], Vector3(cos(ang), 0.0, sin(ang)) * r, 500 + i / 3)
	await _wait(2.0)
	var total := 0.0
	var frames := 0
	var f0 := Engine.get_physics_frames()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await get_tree().physics_frame
		total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		frames += 1
	var avg := total / float(maxi(1, frames))
	print("[aisweep] perf creatures=%d physics_ms_avg=%.2f frames=%d budget=%.1f" % [n, avg, Engine.get_physics_frames() - f0, budget_ms])
	_check(avg <= budget_ms, "%d creatures physics_ms_avg=%.2f > %.1f" % [n, avg, budget_ms])
	await _clear()

func _level_stats() -> void:
	var c := _spawn(&"velociraptor", Vector3(0, 0, 100))
	c.level = c.def.tier
	var at_tier := c.stat_value(&"health")
	c.level = c.def.tier + 5
	var above := c.stat_value(&"health")
	print("[aisweep] level_stats tier=%d hp_at_tier=%.1f hp_at_tier_plus5=%.1f" % [c.def.tier, at_tier, above])
	_check(above > at_tier, "tier+5 health %.1f not above tier health %.1f" % [above, at_tier])
	c.queue_free()

func _island_levels_and_corpse() -> void:
	await _clear()
	(kit["nav"] as Node).queue_free()  # the lab floor would hold bodies above the island terrain
	Game.max_creatures_per_island = 60
	World.harvested.clear()
	World.load_island(self, &"temperate_25", Vector3(0, 1, 18), false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rt: Node = World.runtime
	var rings: Dictionary = Data.world_rules.get("rings", {})
	var proto: Creature
	var raptor_seen := false
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.def == null:
			continue
		var ring := str(rt.ring_name(c.global_position))
		if c.def.id == &"protoceratops" and ring == "gathering":
			proto = c
			var want := c.def.tier + int((rings["gathering"] as Dictionary).get("level_offset", 0))
			print("[aisweep] level protoceratops ring=gathering level=%d want=%d" % [c.level, want])
			_check(c.level == want, "protoceratops in gathering ring level=%d want %d" % [c.level, want])
		elif c.def.id == &"velociraptor" and ring == "crater" and not raptor_seen:
			raptor_seen = true
			var want := c.def.tier + int((rings["crater"] as Dictionary).get("level_offset", 0)) + 3
			print("[aisweep] level velociraptor ring=crater level=%d want=%d" % [c.level, want])
			_check(c.level == want, "velociraptor in crater level=%d want %d" % [c.level, want])
	_check(proto != null, "no protoceratops spawned in the gathering ring")
	_check(raptor_seen, "no velociraptor spawned in the crater")
	if proto == null:
		return
	# Corpse: the body must rest on the terrain, not on its own loot cylinder.
	player.global_position = proto.global_position + Vector3(30, 0, 0)
	proto.health.take_damage(proto.health.max_hp + 1.0, player)
	await _wait(2.5)
	var corpse: Corpse
	for n in get_tree().get_nodes_in_group("corpse"):
		if (n as Corpse)._owner == proto:
			corpse = n
	var q := PhysicsRayQueryParameters3D.create(proto.global_position + Vector3.UP * 3.0, proto.global_position + Vector3.DOWN * 5.0, 1)
	q.exclude = [proto.get_rid()] + ([corpse.get_rid()] if corpse else [])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var gap: float = proto.global_position.y - (hit["position"] as Vector3).y if hit else 99.0
	print("[aisweep] corpse species=protoceratops feet_gap=%.3f" % gap)
	_check(absf(gap) <= 0.05, "corpse feet gap %.3f m (want <= 0.05)" % gap)
	_check(corpse != null, "no corpse for the dead protoceratops")
	if corpse == null:
		return
	# 50 loot taps with a full bag: nothing moves, so no Butchering XP.
	var filler: StringName = &""
	for id in Data.items:
		if not _loot_has(corpse, StringName(id)):
			filler = StringName(id)
			break
	for i in player.inventory.slot_count:
		player.inventory.slots[i] = ItemStack.make(filler, 1)
	var xp0 := player.skills.xp_of("butchering")
	var lvl0 := player.skills.level_of("butchering")
	for tap in 50:
		_tap_take(corpse)
	var gained := player.skills.xp_of("butchering") - xp0
	print("[aisweep] loot_full_bag taps=50 xp_gained=%.1f level_change=%d" % [gained, player.skills.level_of("butchering") - lvl0])
	_check(is_zero_approx(gained) and player.skills.level_of("butchering") == lvl0, "full-bag loot taps paid %.1f XP" % gained)

func _loot_has(corpse: Corpse, id: StringName) -> bool:
	for st in corpse.loot.slots:
		if st and st.def_id == id:
			return true
	return false

## What InventoryUI does for one slot tap: move the stack, put back what did not fit, notify.
func _tap_take(corpse: Corpse) -> void:
	for i in corpse.loot.slot_count:
		var s: ItemStack = corpse.loot.slots[i]
		if s == null:
			continue
		var taken := corpse.loot.remove_at(i, s.count)
		var left := player.inventory.add(taken)
		if left > 0:
			taken.count = left
			corpse.loot.add(taken)
		corpse._on_take_from_loot()
		return
