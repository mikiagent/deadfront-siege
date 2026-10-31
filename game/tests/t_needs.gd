extends SceneTree
## NEEDS (owner: "we need to be able to eat, sleep, clean, drink, etc"): every survival verb a player
## can start is called through the same method the HUD or the pet radial calls, from a state the game
## really reaches, and the effect is measured:
##   eat        HUD bag's Eat button -> Player.begin_eat_slot -> PlayerActions.eat -> EatSession:
##              Energy rises, Full is applied; raw food can give Stomachache (PRD :404, :594).
##   drink      context hex Drink -> PlayerInput.context_action("drink") -> WaterAccess.drink:
##              Thirsty cleared, Quenched applied (PRD :314, 6.3).
##   wash       context hex Wash -> context_action("wash") -> WaterAccess.wash: Dirty/Very dirty
##              cleared, Clean applied (PRD :314, 6.4).
##   fill       context hex Fill -> context_action("fill") -> WaterAccess.fill: empty bucket ->
##              water bucket at the same level (PRD :314).
##   sleep      tent hex SLEEP -> StationCraft's action -> Player._start_sleep: fatigue falls
##              (PRD :803, :931).
##   fire_dry   bonfire Dry off -> Bonfire.dry_off: Wet cleared (PRD :285).
##   feed_pet   pet radial FEED -> PlayerPets.feed_best -> Food.feed_pet: pet hunger rises
##              (spec 02/09).
##   persist    statuses and pet hunger written by SaveGame.save_now and read back by the same
##              from_array / PetRecord.from_dict the load path uses.
## No hunger/thirst/hygiene/body-temperature meter may exist (PRD :72, :1030).
## Usage: godot --headless --path game --script res://tests/t_needs.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var data: Node
var rt
var W: Node
var IT: GDScript
var PetRecordS: GDScript
var ItemStackS: GDScript
var SG: GDScript
var FoodS: GDScript
var WAS: GDScript
var ITS: GDScript
var BonfireS: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	W = get_root().get_node("World")
	PetRecordS = load("res://scripts/pets/pet_record.gd")
	ItemStackS = load("res://scripts/items/item_stack.gd")
	SG = load("res://scripts/core/save_game.gd")
	FoodS = load("res://scripts/items/food.gd")
	WAS = load("res://scripts/player/water_access.gd")
	ITS = load("res://scripts/world/island_terrain.gd")
	BonfireS = load("res://scripts/world/bonfire.gd")
	IT = ITS
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_needs] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	host = Node3D.new()
	host.name = "TNeeds"
	get_root().add_child(host)
	W.home_terrain = &"meadow"
	W.set("creation_pending", false)
	W.player_name = "Needer"
	W.occupation = "student"
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	var cam := IsoCamera.new()
	cam.name = "IsoCamera"
	host.add_child(cam)
	cam.current = true
	cam.target_path = cam.get_path_to(player)
	cam._target = player
	cam._snap()
	W.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	rt = W.runtime
	player = W._player()
	_expect(player != null and rt != null, "the home island has a survivor")
	if player == null:
		_finish()
		return
	player.vitals.level_gap_mult = 1.0
	player.statuses.from_array([])
	await _frames(3)
	await _test_eat()
	await _test_water()
	await _test_sleep()
	await _test_bonfire_dry()
	await _test_feed_pet()
	await _test_persist()
	_test_no_meter()
	host.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[t_needs] PASS")
		quit(0)
	else:
		print("[t_needs] FAIL count=%d" % failures.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _status_ids() -> Array:
	var out: Array = []
	for inst in player.statuses.instances():
		out.append(inst.id)
	return out

# ---------------------------------------------------------------- eat

## The bag's Eat button (InventoryUI -> begin_eat_slot -> PlayerActions.eat -> EatSession). It takes
## EAT_SECONDS with no input; the test stands still and waits it out, as the player does.
func _test_eat() -> void:
	player.statuses.from_array([])
	var v = player.vitals
	v.energy = 20.0
	player.inventory.add(ItemStackS.make(&"skewer", 1))
	var idx: int = player.inventory.find_first(&"skewer")
	_expect(idx >= 0, "a cooked skewer is in the bag before eating")
	var before: float = v.energy
	var started: bool = player.begin_eat_slot(idx)
	_expect(started, "the bag's Eat starts an eat session on the skewer")
	# No input, no navigation: the session cannot cancel itself. The session is driven with fixed
	# deltas (a headless frame's delta is not the wall-clock half second this needs).
	for i in 40:
		if not player.eat_session.eating:
			break
		player.eat_session._process(0.1)
	await _frames(2)
	_expect(v.energy > before + 1.0, "eating raised Energy (%.1f -> %.1f)" % [before, v.energy])
	_expect(player.statuses.has(&"full"), "eating applied Full (statuses %s)" % [str(_status_ids())])
	_expect(player.inventory.find_first(&"skewer") < 0, "the eaten skewer left the bag")
	# HUNGER (memo Part 1 s1.4): the meal fills the stored stomach by its foods.json points, and the
	# Full status is no longer the gate - a stomach under the overfull line can take another bite.
	var dig = load("res://scripts/items/digestion.gd").of(player)
	var fed_before: float = dig.fullness()
	_expect(fed_before >= 25.0, "the skewer filled the stomach (%.1f points)" % fed_before)
	player.inventory.add(ItemStackS.make(&"berry", 1))
	var berry_idx: int = player.inventory.find_first(&"berry")
	_expect(player.statuses.has(&"full") and player.begin_eat_slot(berry_idx), "a fed stomach under the overfull line can eat again (Full is not the gate)")
	for i in 40:
		if not player.eat_session.eating:
			break
		player.eat_session._process(0.1)
	_expect(dig.fullness() > fed_before, "the second bite added its own points (%.1f -> %.1f)" % [fed_before, dig.fullness()])
	dig.set_fullness(0.0)  # leave the survivor as the other sections expect
	# Raw meat through the same Eat path: the session rolls the raw risk and, with a seed that poisons,
	# applies Stomachache (PRD :594: raw meat can poison). Energy still rises.
	player.statuses.from_array([])
	v.energy = 20.0
	player.inventory.add(ItemStackS.make(&"raw_meat", 1))
	var raw_idx: int = player.inventory.find_first(&"raw_meat")
	var rng := RandomNumberGenerator.new()
	var poison_seed := -1
	for s in 200:
		rng.seed = s
		if FoodS.raw_risk_roll(ItemStackS.make(&"raw_meat", 1), rng) == &"stomachache":
			poison_seed = s
			break
	_expect(poison_seed >= 0, "raw meat can poison (a seed gives Stomachache)")
	player.eat_session.rng = rng
	rng.seed = poison_seed
	var raw_before: float = v.energy
	var raw_started: bool = player.begin_eat_slot(raw_idx)
	for i in 40:
		if not player.eat_session.eating:
			break
		player.eat_session._process(0.1)
	await _frames(2)
	_expect(raw_started and v.energy > raw_before + 1.0, "eating raw meat raised Energy (%.1f -> %.1f)" % [raw_before, v.energy])
	_expect(player.statuses.has(&"stomachache"), "raw meat applied Stomachache (statuses %s)" % [str(_status_ids())])
	_expect(player.statuses.has(&"full"), "the raw meal applied Full too")
	player.eat_session.rng = null
	# The inspector the HUD shows before a tap says RAW / POISONED (PRD :21.3, no hidden food state).
	var raw_stack = ItemStackS.make(&"raw_meat", 1)
	var text: String = FoodS.inspector_text(raw_stack)
	_expect("RAW" in text, "the food card names raw meat RAW: '%s'" % text.replace("\n", " / "))
	raw_stack.flags.append(&"poisoned")
	_expect("POISONED" in FoodS.inspector_text(raw_stack), "the food card names poisoned food POISONED")
	player.statuses.from_array([])
	v.energy = 20.0
	player.eat_session.rng = null
	player.statuses.from_array([])
	v.energy = 20.0

# ---------------------------------------------------------------- water: drink, wash, fill

func _test_water() -> void:
	var river: Vector3 = _find_shallow(true)
	_expect(river != Vector3.ZERO, "the home island has fresh river water")
	var bank: Vector3 = _bank(river)
	await _stand(bank)
	player.statuses.from_array([])
	player.statuses.apply(&"thirsty")
	player.statuses.apply(&"dirty")
	player.inventory.add(ItemStackS.make(&"empty_bucket", 1))
	var hexes: Array = []
	for a in player.context_actions():
		hexes.append(str(a["id"]))
	_expect("drink" in hexes and "wash" in hexes and "fill" in hexes,
		"the HUD offers Drink, Wash and Fill at fresh water (ctx %s)" % [str(hexes)])
	# Drink: the HUD's context hex calls context_action("drink").
	player.context_action("drink")
	_expect(not player.statuses.has(&"thirsty"), "Drink cleared Thirsty (statuses %s)" % [str(_status_ids())])
	_expect(player.statuses.has(&"quenched"), "Drink applied Quenched")
	# Wash: the HUD's context hex calls context_action("wash").
	player.context_action("wash")
	_expect(not player.statuses.has(&"dirty"), "Wash cleared Dirty (statuses %s)" % [str(_status_ids())])
	_expect(player.statuses.has(&"clean"), "Wash applied Clean")
	# Very dirty, the harder case.
	player.statuses.from_array([])
	player.statuses.apply(&"very_dirty")
	player.context_action("wash")
	_expect(not player.statuses.has(&"very_dirty") and player.statuses.has(&"clean"), "Wash clears Very Dirty too")
	# Fill: the HUD's Fill hex.
	var level := 3
	var empty = player.inventory.slots[player.inventory.find_first(&"empty_bucket")]
	empty.level = level
	player.context_action("fill")
	var wb: int = player.inventory.find_first(&"water_bucket")
	_expect(wb >= 0, "Fill turned the empty bucket into a water bucket")
	if wb >= 0:
		_expect(int(player.inventory.slots[wb].level) == level, "the water bucket keeps the bucket's level %d (got %d)" % [level, int(player.inventory.slots[wb].level)])
	_expect(player.inventory.find_first(&"empty_bucket") < 0, "no empty bucket is left after filling")
	# Away from water the same hexes are refused (the verbs re-check, the HUD hides them).
	await _stand(_dry_mid())
	var away: Array = []
	for a in player.context_actions():
		away.append(str(a["id"]))
	_expect(not ("drink" in away), "no Drink hex away from water (ctx %s)" % [str(away)])
	player.statuses.from_array([])
	player.statuses.apply(&"thirsty")
	player.context_action("drink")
	_expect(player.statuses.has(&"thirsty"), "Drink away from water does nothing")

# ---------------------------------------------------------------- sleep

## A tent's SLEEP hex -> StationCraft._on_menu_action -> Player._start_sleep. The sleep completes on
## its own after sleep_duration seconds with no input.
func _test_sleep() -> void:
	await _stand(_dry_mid())
	player.statuses.from_array([])
	var tent = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"tent")
	host.add_child(tent)
	tent.global_position = player.global_position + Vector3(1.2, 0, 0)
	await _frames(3)
	var spot = player.sim.nearest_sleep_spot()
	_expect(spot != null, "the HUD finds the tent as a sleep spot")
	player.vitals.fatigue = 80.0
	var before: float = player.vitals.fatigue
	player._start_sleep(spot)
	_expect(player._sleep_left > 0.0, "Sleep started (%.1f s)" % player._sleep_left)
	# The sleep ticks inside PlayerSim every physics frame; drive it with fixed deltas here.
	for i in 40:
		if player._sleep_left <= 0.0:
			break
		player.sim._tick_sleep(0.5)
	player.sim.get_up()  # a tent keeps her asleep until she gets up
	await _frames(3)
	_expect(player.vitals.fatigue < before - 10.0, "sleep lowered fatigue (%.1f -> %.1f)" % [before, player.vitals.fatigue])
	_expect(int(spot.get("sleeps_left")) == 5, "the tent spent one of its six sleeps (%s left)" % str(spot.get("sleeps_left")))
	tent.queue_free()
	await _frames(2)

# ---------------------------------------------------------------- bonfire: dry off

## PRD :285: a bonfire clears Wet. The HUD's bonfire hex (Dry off) calls Bonfire.dry_off.
func _test_bonfire_dry() -> void:
	await _stand(_dry_mid())
	player.statuses.from_array([])
	var fire = BonfireS.make(&"bonfire")
	host.add_child(fire)
	fire.global_position = player.global_position + Vector3(1.4, 0, 0)
	await _frames(3)
	player.statuses.apply(&"wet")
	var ids: Array = []
	for a in player.context_actions():
		ids.append(str(a["id"]))
	_expect("dry" in ids, "the HUD offers Dry off at a bonfire while Wet (ctx %s)" % [str(ids)])
	player.context_action("dry")
	_expect(not player.statuses.has(&"wet"), "Dry off cleared Wet (statuses %s)" % [str(_status_ids())])
	fire.queue_free()
	await _frames(2)

# ---------------------------------------------------------------- feed a pet

## The pet radial's FEED -> PlayerPets.feed_best -> Food.feed_pet: the pet's hunger rises and the
## food leaves the bag.
func _test_feed_pet() -> void:
	await _stand(_dry_mid())
	player.statuses.from_array([])
	var rec = PetRecordS.from_def(data.creature(&"velociraptor"), &"A")
	player.bonded.append(rec)
	player.summon_pet(player.bonded.size() - 1)
	await _frames(5)
	var pet = player.pets.nearest(99.0)
	_expect(pet != null, "a bonded velociraptor is out")
	if pet == null:
		return
	pet.hunger = 20.0
	pet.hunger_max = 100.0
	if pet.pet_record:
		pet.pet_record.hunger = 20.0
		pet.pet_record.hunger_max = 100.0
	# One unit only: an earlier stack of raw meat is still in the bag and would merge with this one.
	while player.inventory.find_first(&"raw_meat") >= 0:
		player.inventory.remove_at(player.inventory.find_first(&"raw_meat"), 1)
	player.inventory.add(ItemStackS.make(&"raw_meat", 1))
	var before: float = pet.hunger
	var fed: bool = player.pets.feed_best(pet)
	_expect(fed, "the pet radial's Feed accepts raw meat")
	_expect(pet.hunger > before + 1.0, "feeding raised pet hunger (%.0f -> %.0f)" % [before, pet.hunger])
	_expect(player.inventory.find_first(&"raw_meat") < 0, "the fed meat left the bag")
	if pet.pet_record:
		_expect(is_equal_approx(pet.pet_record.hunger, pet.hunger), "the pet record carries the fed hunger")
	# Nothing it eats: refused, and the bag is untouched.
	player.inventory.add(ItemStackS.make(&"stone", 1))
	_expect(not player.pets.feed_best(pet), "a herbivore's radial Feed refuses stone")
	_expect(player.inventory.find_first(&"stone") >= 0, "a refused feed keeps the item")

# ---------------------------------------------------------------- persistence

## SaveGame.save_now writes the statuses and the pet records; the load path's from_array /
## PetRecord.from_dict read them back.
func _test_persist() -> void:
	player.statuses.from_array([])
	player.statuses.apply(&"full")
	player.statuses.apply(&"quenched")
	player.statuses.apply(&"clean")
	var rec = player.bonded[0] if not player.bonded.is_empty() else null
	if rec:
		rec.hunger = 37.0
		if player.pets.nearest(99.0):
			player.pets.nearest(99.0).hunger = 37.0
	_expect(SG.save_now(), "save_now wrote the save")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	_expect(not raw.is_empty(), "the save file parses (%s)" % SG.path)
	var saved_statuses: Array = raw.get("player", {}).get("statuses", [])
	var saved_ids: Array = []
	for row in saved_statuses:
		saved_ids.append(str(row.get("id", "")))
	_expect("full" in saved_ids and "quenched" in saved_ids and "clean" in saved_ids,
		"the save holds Full, Quenched and Clean (%s)" % [str(saved_ids)])
	var saved_pets: Array = raw.get("pets", [])
	_expect(not saved_pets.is_empty() and is_equal_approx(float(saved_pets[0].get("hunger", -1.0)), 37.0),
		"the save holds the pet's fed hunger")
	# The load path.
	player.statuses.from_array(saved_statuses)
	_expect(player.statuses.has(&"full") and player.statuses.has(&"quenched") and player.statuses.has(&"clean"),
		"the statuses come back after a load (statuses %s)" % [str(_status_ids())])
	var back = PetRecordS.from_dict(saved_pets[0])
	_expect(back != null and is_equal_approx(back.hunger, 37.0), "the pet's hunger comes back after a load")
	if back:
		player.bonded[0] = back
	# A timed status keeps its remaining time (Quenched 360 s), not a fresh full duration.
	player.statuses.from_array([])
	player.statuses.apply(&"quenched")
	var q = player.statuses.get_instance(&"quenched")
	if q:
		q.time_left = 42.0
	_expect(SG.save_now(), "save_now wrote the second save")
	var raw2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	player.statuses.from_array(raw2.get("player", {}).get("statuses", []))
	var q2 = player.statuses.get_instance(&"quenched")
	_expect(q2 != null and absf(q2.time_left - 42.0) < 1.0, "Quenched keeps its remaining time through a save (%s)" % str(q2.time_left if q2 else -1.0))
	# What the statuses do to the survivor survives too: Clean still cuts fatigue gain (0.8).
	player.statuses.from_array([{"id": "clean", "stacks": 1, "time_left": 100.0}])
	_expect(player.statuses.fatigue_mult() < 1.0, "a loaded Clean still cuts fatigue gain (x%.2f)" % player.statuses.fatigue_mult())
	player.statuses.from_array([{"id": "thirsty", "stacks": 1, "time_left": 100.0}])
	_expect(player.statuses.fatigue_mult() > 1.0, "a loaded Thirsty still raises fatigue gain (x%.2f)" % player.statuses.fatigue_mult())
	# And drinking clears the loaded Thirsty through the same verb.
	await _stand(_bank(_find_shallow(true)))
	player.context_action("drink")
	_expect(not player.statuses.has(&"thirsty"), "a loaded Thirsty is cleared by the Drink hex")

# ---------------------------------------------------------------- no meters

func _test_no_meter() -> void:
	var meters: Array = []
	for name in ["thirst", "hunger", "hygiene", "hydration", "stamina_meter"]:
		if player.get(name) != null or player.vitals.get(name) != null:
			meters.append(name)
	_expect(meters.is_empty(), "no hunger/thirst/hygiene meter exists on the survivor (%s)" % [str(meters)])

# ---------------------------------------------------------------- spots (as t_water)

const WATER_Y := -0.05

func _is_water(x: float, z: float) -> bool:
	return rt.surface_y(x, z) < WATER_Y

func _is_river(x: float, z: float) -> bool:
	return ITS.tile_type_at_world(rt, x, z) == ITS.TileType.MUD

func _find_shallow(river: bool) -> Vector3:
	var from: Vector3 = rt._camp_pos if river else rt.arrival_point()
	var ring := 38.0 if river else 12.0
	var best := Vector3.ZERO
	var best_d := INF
	var half: float = rt._size * 0.5 - 2.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var h: float = rt.surface_y(x, z)
			if h < (-0.25 if river else -0.12) and h > -0.38 and _is_river(x, z) == river and (not river or absf(z) > 8.0):
				var d := absf(Vector2(x - from.x, z - from.z).length() - ring)
				if d < best_d:
					best_d = d
					best = Vector3(x, h, z)
			z += 0.5
		x += 0.5
	return best

func _bank(water: Vector3) -> Vector3:
	var best := water
	var best_steps := 1 << 30
	for d in [Vector2(0, 1), Vector2(0, -1)]:
		var at := Vector2(water.x, water.z)
		var steps := 0
		while _is_water(at.x, at.y) and steps < 200:
			at += d * 0.05
			steps += 1
		if steps < best_steps:
			best_steps = steps
			best = Vector3(at.x + d.x, 0.0, at.y + d.y)
	return best

## Dry land away from water on the home island.
func _dry_mid() -> Vector3:
	var half: float = rt._size * 0.5 - 4.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			if rt.surface_y(x, z) > 0.5 and not WAS.near_fresh(Vector3(x, 0, z)):
				return Vector3(x, 0, z)
			z += 2.0
		x += 2.0
	return Vector3(0, 0, 0)

func _stand(at: Vector3) -> void:
	player.clear_nav()
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(at.x, rt.surface_y(at.x, at.z) + 0.2, at.z)
	player.reset_physics_interpolation()
	await _frames(6)
