extends Node3D
## Headless sweep of the wild AI across every species (W1-AI acceptance). Prints one
## "[aisweep] <check> ..." line per check, then "[aisweep] PASS" or FAIL lines, and quits 0/1.
## Sections run one after another on one big flat floor, then on the temperate_25 island.

const FLOOR := 320.0
const WALK := 5.5 ## survivor walk speed (player.gd walk_speed)

var player: Player
var kit: Dictionary
var failures: Array[String] = []

## Counts real engine output lines that start with "[ai]" (any print path, not just _log).
class AiLineCounter extends Logger:
	var ai_lines := 0
	var probe_seen := false
	func _log_message(message: String, _error: bool) -> void:
		if message.begins_with("[ai]"):
			ai_lines += 1
		elif message.begins_with("[aisweep] logger_probe"):
			probe_seen = true

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
	await _lod_freeze()
	await _sleep_and_wake()
	await _wake_each_herbivore()
	await _hurt_grazer_flight()
	await _lone_flight()
	await _hit_react()
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

func _spawn(id: StringName, at: Vector3, pack: int = 0, genes: CreatureGenetics = null) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = at
	# Average IVs unless a check names its own: the sweep tests the AI, not the genetics dice.
	c.genetics = genes if genes else CreatureGenetics.neutral()
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
	# Dawn wakes everyone.
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
	for i in cs.size():
		var d: float = far[i]
		if cs[i].brain.state == &"sleep" or d < 1.0:
			bad.append("%s:%s/%.2f" % [cs[i].def.id, cs[i].brain.state, d])
	print("[aisweep] dawn herbivores=%d still_or_asleep=%s" % [cs.size(), bad])
	_check(bad.is_empty(), "herbivores did not wake and move >= 1 m within 10 s of dawn: %s" % [bad])
	Game.time_of_day = 0.40
	await _clear()

## Every sleeping herbivore wakes within 1 s once the survivor stands 2 m from its body.
func _wake_each_herbivore() -> void:
	Game.time_of_day = 0.05
	player.global_position = Vector3(0, 1, 0)
	var cs := _ring(_herbivores())
	await _wait(1.0)
	var slow: Array[String] = []
	var worst := 0.0
	for sleeper in cs:
		if sleeper.brain.state != &"sleep":
			slow.append("%s:not_asleep(%s)" % [sleeper.def.id, sleeper.brain.state])
			continue
		var to_p := (Vector3.ZERO - sleeper.global_position).normalized()
		player.global_position = sleeper.global_position + to_p * (sleeper.body_radius() + 2.0) + Vector3.UP
		var t0 := Time.get_ticks_msec()
		while sleeper.brain.state == &"sleep" and Time.get_ticks_msec() - t0 < 1500:
			await get_tree().physics_frame
		var wake_s := float(Time.get_ticks_msec() - t0) / 1000.0
		worst = maxf(worst, wake_s)
		if sleeper.brain.state == &"sleep" or wake_s > 1.0:
			slow.append("%s:%.2f" % [sleeper.def.id, wake_s])
	print("[aisweep] wake_near herbivores=%d worst_s=%.2f slow=%s" % [cs.size(), worst, slow])
	_check(slow.is_empty(), "herbivores did not wake within 1 s of a survivor at 2 m: %s" % [slow])
	Game.time_of_day = 0.40
	await _clear()

## A zebraceratops hit while asleep (8 m) runs and stays up; one shot in daylight from just past
## its leash runs too, instead of walking home (was: back to sleep at the leash edge, 0 m moved).
func _hurt_grazer_flight() -> void:
	for night in [true, false]:
		Game.time_of_day = 0.05 if night else 0.40
		player.global_position = Vector3(0, 1, 40)  # out of sight, inside the 60 m AI LOD
		var zeb := _spawn(&"zebraceratops", Vector3(0, 0, 0))
		await _wait(1.0)
		var slept := zeb.brain.state == &"sleep"
		var dist := 8.0 if night else zeb.brain.aggro_radius() + 0.5
		player.global_position = Vector3(-dist, 1, 0)
		var z0 := zeb.global_position
		var trail: Array[String] = [str(zeb.brain.state)]
		zeb.brain.state_changed.connect(func (_p: StringName, n: StringName) -> void: trail.append(str(n)))
		zeb.health.take_damage(1.0, player)
		var away := 0.0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 8000:
			await get_tree().physics_frame
			away = maxf(away, zeb.global_position.x - z0.x)
		var label := "asleep_8m" if night else "day_past_leash"
		print("[aisweep] hurt_flight case=%s slept=%s away=%.2f state=%s trail=%s" % [label, slept, away, zeb.brain.state, trail])
		_check(away >= 10.0 and zeb.brain.state != &"sleep" and not trail.has("disengage") and (slept or not night), "%s: away=%.2f state=%s trail=%s (want >= 10 m, awake, no walk home)" % [label, away, zeb.brain.state, trail])
		await _clear()
	Game.time_of_day = 0.40

## AI LOD: an idle animal 80 m from the survivor does not think (stays put); one at 45 m roams.
func _lod_freeze() -> void:
	Game.time_of_day = 0.40
	player.global_position = Vector3(0, 1, 0)
	var near := _spawn(&"velociraptor", Vector3(45, 0, 0))
	var far := _spawn(&"velociraptor", Vector3(-80, 0, 0))
	var n0 := near.global_position
	var f0 := far.global_position
	var near_d := 0.0
	var far_d := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await get_tree().physics_frame
		near_d = maxf(near_d, _flat(n0, near.global_position))
		far_d = maxf(far_d, _flat(f0, far.global_position))
	print("[aisweep] lod near45_moved=%.2f far80_moved=%.2f" % [near_d, far_d])
	_check(near_d >= 0.5 and far_d < 0.05, "AI LOD: near45 moved %.2f (want >= 0.5), far80 moved %.2f (want 0)" % [near_d, far_d])
	await _clear()

## pc-hitreact-01: species with an authored hit_react clip play it when hit (not the flinch).
func _hit_react() -> void:
	player.global_position = Vector3(0, 1, -60)
	var ids: Array[StringName] = []
	for id in _species():
		# The tyrant never staggers or flinches by design (its counters are the tells).
		if id != &"tyrannosaurus" and (Data.creature(id).pipeline.get("authored_clips", {}) as Dictionary).has("hit_react"):
			ids.append(id)
	var missed: Array[String] = []
	var skipped: Array[String] = []
	var played := 0
	for id in ids:
		var c := _spawn(id, Vector3(0, 0, 0))
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		var t0 := Time.get_ticks_msec()
		while not c.view.using_glb and Time.get_ticks_msec() - t0 < 3000:
			await get_tree().physics_frame
		if not c.view.using_glb:
			# No rig loaded (stand-in body): the flinch is the designed fallback, not a miss.
			skipped.append(str(id))
			await _clear()
			continue
		c.health.take_damage(1.0, player)
		var seen := false
		for f in 6:
			seen = seen or c.anim.current_clip == &"hit_react"
			await get_tree().physics_frame
		if seen:
			played += 1
		else:
			missed.append("%s:%s" % [id, c.anim.current_clip])
		await _clear()
	print("[aisweep] hit_react species=%d played=%d missed=%s no_rig=%s" % [ids.size(), played, missed, skipped])
	_check(played > 0 and missed.is_empty(), "authored hit_react did not play: %s" % [missed])

## A lone zebraceratops chased by a survivor walking at 5.5 m/s for 10 s, at average IVs and at
## the worst IVs (all 0: 85 % speed, which the survivor caught before flee_min_mps).
func _lone_flight() -> void:
	var worst := CreatureGenetics.neutral()
	for stat in worst.ivs:
		worst.ivs[stat] = 0
	for genes in [CreatureGenetics.neutral(), worst]:
		await _lone_flight_one(genes, "avg" if genes != worst else "worst")

func _lone_flight_one(genes: CreatureGenetics, label: String) -> void:
	Game.time_of_day = 0.40
	var zeb := _spawn(&"zebraceratops", Vector3(0, 0, 0), 0, genes)
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
	print("[aisweep] lone_flight ivs=%s speed_mult=%.3f ahead=%.2f from_home=%.2f avg_mps=%.2f state=%s" % [label, genes.multiplier(&"speed"), ahead, from_home, ran / 10.0, zeb.brain.state])
	_check(ahead >= 8.0 and from_home >= 25.0, "lone zebraceratops (%s IVs) flight ahead=%.2f from_home=%.2f (want >= 8, >= 25)" % [label, ahead, from_home])
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
	var counter := AiLineCounter.new()
	OS.add_logger(counter)
	print("[aisweep] logger_probe")  # proves the counter sees prints, so 0 below is real
	var t := 0.0
	while t < 10.0:
		var dt := get_physics_process_delta_time()
		await get_tree().physics_frame
		t += dt
		player.global_position += Vector3(-WALK * dt, 0, 0)
	OS.remove_logger(counter)
	var lines := counter.ai_lines
	print("[aisweep] pack_walkout engaged=%s follower_changes=%d trail=%s ai_lines=%d logger_probe=%s" % [engaged, changes[0], trail, lines, counter.probe_seen])
	_check(changes[0] <= 6, "raptor followers changed state %d times in 10 s (want <= 6)" % changes[0])
	_check(counter.probe_seen, "the [ai] line counter saw no output at all")
	_check(lines == 0, "AI printed %d '[ai]' lines with the overlay off" % lines)
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
	# Median of five 1 s windows: one busy second on the shared box does not fail the budget.
	var windows: Array[float] = []
	var frames := 0
	for w in 5:
		var total := 0.0
		var wf := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1000:
			await get_tree().physics_frame
			total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			wf += 1
		windows.append(total / float(maxi(1, wf)))
		frames += wf
	var sorted := windows.duplicate()
	sorted.sort()
	var avg: float = sorted[2]
	print("[aisweep] perf creatures=%d physics_ms_avg=%.2f (median of %s) frames=%d budget=%.1f load=%s" % [n, avg, _ms(windows), frames, budget_ms, _load_avg()])
	_check(avg <= budget_ms, "%d creatures physics_ms_avg=%.2f > %.1f (load %s)" % [n, avg, budget_ms, _load_avg()])
	await _clear()

func _ms(xs: Array[float]) -> String:
	var out: Array[String] = []
	for x in xs:
		out.append("%.2f" % x)
	return "[%s]" % ", ".join(out)

## Machine load next to every perf reading, so a FAIL on a busy shared box can be judged.
func _load_avg() -> String:
	var out: Array = []
	if OS.execute("sysctl", ["-n", "vm.loadavg"], out) == 0 and not out.is_empty():
		return str(out[0]).strip_edges()
	return "?"

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
	var raptors := 0
	var raptor_bad: Array[String] = []
	var crater_offset := 0
	for row in (World.island_def.get("spawns", {}) as Dictionary).get("crater", []):
		if row is Dictionary and str(row.get("species", "")) == "velociraptor":
			crater_offset = int(row.get("tier_offset", 0))
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
		elif c.def.id == &"velociraptor" and ring == "crater":
			raptors += 1
			var want := c.def.tier + int((rings["crater"] as Dictionary).get("level_offset", 0)) + crater_offset
			if c.level != want:
				raptor_bad.append("%d!=%d" % [c.level, want])
	print("[aisweep] level velociraptor ring=crater count=%d row_tier_offset=%d wrong=%s" % [raptors, crater_offset, raptor_bad])
	_check(proto != null, "no protoceratops spawned in the gathering ring")
	_check(raptors > 0 and crater_offset != 0, "no velociraptor (or no tier_offset row) in the crater")
	_check(raptor_bad.is_empty(), "crater velociraptor levels wrong: %s" % [raptor_bad])
	if proto == null:
		return
	# Corpse: the body must rest on the terrain, not on its own loot cylinder. Once killed while
	# roaming, once killed standing still (brain off): the still one hovered 0.1 m when idle
	# bodies skipped move_and_slide.
	var still: Creature
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and c != proto and c.def and not c.health.dead and _flat(c.global_position, proto.global_position) > 12.0:
			still = c
			break
	_check(still != null, "no second creature for the standing-kill corpse check")
	if still:
		still.brain.process_mode = Node.PROCESS_MODE_DISABLED
		still.stop_move()
	player.global_position = proto.global_position + Vector3(30, 0, 0)
	await _wait(0.5)
	var corpse := await _kill_and_gap(proto, "roaming")
	if still:
		await _kill_and_gap(still, "standing")
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

## Kills c, waits for the corpse, prints and checks the feet gap to the terrain under it.
func _kill_and_gap(c: Creature, how: String) -> Corpse:
	c.health.take_damage(c.health.max_hp + 1.0, player)
	await _wait(2.5)
	var corpse: Corpse
	for n in get_tree().get_nodes_in_group("corpse"):
		if (n as Corpse)._owner == c:
			corpse = n
	var q := PhysicsRayQueryParameters3D.create(c.global_position + Vector3.UP * 3.0, c.global_position + Vector3.DOWN * 5.0, 1)
	q.exclude = [c.get_rid()] + ([corpse.get_rid()] if corpse else [])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var gap: float = c.global_position.y - (hit["position"] as Vector3).y if hit else 99.0
	print("[aisweep] corpse species=%s killed=%s feet_gap=%.3f" % [c.def.id, how, gap])
	_check(absf(gap) <= 0.05, "%s corpse (%s) feet gap %.3f m (want <= 0.05)" % [c.def.id, how, gap])
	return corpse

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
