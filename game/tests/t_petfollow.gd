extends SceneTree
## PETFOLLOW (owner 2026-10-28): "tames should follow within a certain radius of the player, not
## directly on top of the player". Each summoned pet gets a follow SLOT behind/beside the survivor,
## fanned by summon order and scaled by body size (a big tame hangs back further, a Loyal one closer);
## the pet walks only when it is farther than its outer radius from that slot and stops inside the
## inner one (hysteresis, no shuffling while the survivor stands still); it never stands inside the
## survivor's capsule and steps aside when the survivor walks into it. The numbers come from
## data/creatures/ai.json "follow" and are MEASURED from the live scene, not copied here.
## Run: Godot --headless --path game --script res://tests/t_petfollow.gd -> "[t_petfollow] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before the autoloads exist.

const CREATURE_SCENE := "res://scenes/creatures/creature.tscn"
const SETTLE_FRAMES := 900
const STILL_FRAMES := 300  ## 5 s at 60 Hz
const WALK_FRAMES := 200   ## 0.1 m a frame = 20 m

var _fails: PackedStringArray = []
var _started := false
var _done := false
var _sections := 0
var _want := 8
var data: Node
var player: Node
var host: Node3D
var PR: GDScript ## pet_record.gd

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	PR = load("res://scripts/pets/pet_record.gd")
	_run.call_deferred()
	_watchdog()
	return false

func _watchdog() -> void:
	var t := 0.0
	while t < 240.0:
		await create_timer(1.0).timeout
		t += 1.0
		if _done:
			return
	print("[t_petfollow] FAIL watchdog (240 s)")
	quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_petfollow] FAIL %s" % what)

func _finish() -> void:
	_done = true
	_expect(_sections == _want, "only %d of %d test sections completed (a runtime error aborted the rest)" % [_sections, _want])
	if _fails.is_empty():
		print("[t_petfollow] PASS")
		quit(0)
	else:
		print("[t_petfollow] FAIL count=%d" % _fails.size())
		quit(1)

## Every follow number the brain needs exists in ai.json (the old file has no "follow" block).
func _follow_cfg() -> Dictionary:
	var ai: Variant = data.creature_ai
	return (ai as Dictionary).get("follow", {}) if ai is Dictionary else {}

func _run() -> void:
	var cfg := _follow_cfg()
	_expect(not cfg.is_empty(), "data/creatures/ai.json has no \"follow\" block")
	for k in ["slot_m", "slot_size_mult", "slot_arc_deg", "inner_m", "outer_m", "clearance_margin_m"]:
		_expect(float(cfg.get(k, -1.0)) > 0.0, "ai.json follow.%s is missing or <= 0" % k)
	if _fails.size() > 0:
		_finish()
		return
	host = Node3D.new()
	host.name = "TPetFollowHost"
	root.add_child(host)
	# LabKit's floor sits under its NavigationRegion3D: keep the region, or the ground goes away.
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 80.0)
	player = kit["player"]
	var game: Node = root.get_node_or_null("Game")
	if game:
		game.time_of_day = 0.3
		game.debug_overlay = false
	player.global_position = Vector3(0, 1, 0)
	await process_frame
	await physics_frame
	_summon_three()
	await _test_settle()
	_test_geometry()
	_test_hysteresis()
	await _test_no_shuffle()
	await _test_walk()
	await _test_step_aside()
	_test_orders()
	await _test_stay()
	_finish()

# ---------------------------------------------------------------- setup

func _bond(species: StringName, nature: StringName = &"") -> void:
	var rec: RefCounted = PR.from_def(data.creature(species), &"A")
	rec.nature = nature
	player.bonded.append(rec)

func _summon_three() -> void:
	_bond(&"velociraptor")
	_bond(&"triceratops")   # the big body: its slot hangs back further
	_bond(&"compsognathus") # the small one
	for i in 3:
		player.summon_pet(i)
	await physics_frame

func _pets() -> Array:
	return player.live_pets()

func _h(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _slot_of(pet: Node) -> Vector3:
	return pet.brain.follow_slot(player)

func _clearance(pet: Node) -> float:
	return pet.brain.player_clearance(player)

func _settled(pet: Node) -> bool:
	var d := _h(pet.global_position, _slot_of(pet))
	return d <= float(pet.brain.follow_inner()) + 0.3 and not bool(pet._path_active)

func _wait_settle(frames: int) -> int:
	for i in frames:
		await physics_frame
		var all_ok := true
		for pet in _pets():
			if not _settled(pet):
				all_ok = false
				break
		if all_ok:
			return i
	return -1

# ---------------------------------------------------------------- 1. slots, hysteresis radii, body size, nature

func _test_geometry() -> void:
	var pets := _pets()
	_expect(pets.size() == 3, "summoned %d pets, want 3" % pets.size())
	if pets.size() < 3:
		return
	var slots: Array[Vector3] = []
	for pet in pets:
		slots.append(_slot_of(pet))
		print("[t_petfollow] pet %s slot d=%.2f inner=%.2f outer=%.2f clear=%.2f" % [
			pet.def.id, pet.brain.slot_distance(), pet.brain.follow_inner(), pet.brain.follow_outer(), _clearance(pet)])
		_expect(float(pet.brain.follow_inner()) < float(pet.brain.follow_outer()), "%s inner %.2f is not under outer %.2f" % [pet.def.id, pet.brain.follow_inner(), pet.brain.follow_outer()])
		_expect(_h(slots[-1], player.global_position) > _clearance(pet), "%s slot sits inside the survivor's capsule" % pet.def.id)
	# Distinct slots: summon order fans the pets so they do not queue at one point.
	_expect(slots[0].distance_to(slots[1]) > 1.5 and slots[1].distance_to(slots[2]) > 1.5, "the three slots are not fanned apart: %s %s %s" % [slots[0], slots[1], slots[2]])
	# Body size: the triceratops (tame index 1) hangs back further than the compsognathus (index 2).
	_expect(float(pets[1].brain.slot_distance()) > float(pets[2].brain.slot_distance()) + 0.5,
		"a big tame's slot (%.2f m) is not farther than a small one's (%.2f m)" % [pets[1].brain.slot_distance(), pets[2].brain.slot_distance()])
	# NATURES: a Loyal pet keeps a closer slot than the same species with no nature.
	var plain := _stray(&"velociraptor", &"")
	var loyal := _stray(&"velociraptor", &"loyal")
	print("[t_petfollow] loyal slot=%.2f plain slot=%.2f" % [loyal.brain.slot_distance(), plain.brain.slot_distance()])
	_expect(float(loyal.brain.slot_distance()) < float(plain.brain.slot_distance()) - 0.2, "a Loyal pet's slot is not closer (%.2f vs %.2f)" % [loyal.brain.slot_distance(), plain.brain.slot_distance()])
	_expect(float(loyal.brain.follow_inner()) < float(plain.brain.follow_inner()), "a Loyal pet's inner radius is not closer")
	for c in [plain, loyal]:
		c.free()
	_sections += 1

## A one-off pet beside the survivor (not summoned, not in the fleet), for a brain-only measurement.
func _stray(species: StringName, nature: StringName) -> Node:
	var c: Node = load(CREATURE_SCENE).instantiate()
	root.add_child(c)
	c.global_position = player.global_position + Vector3(-6, 0, 0)
	c.spawn(data.creature(species))
	var rec: RefCounted = PR.from_def(data.creature(species), &"A")
	rec.nature = nature
	c.become_pet(rec)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

# ---------------------------------------------------------------- 2. settling

func _test_settle() -> void:
	var got := await _wait_settle(SETTLE_FRAMES)
	_expect(got >= 0, "the pets did not settle at their slots within %.0f s" % (SETTLE_FRAMES / 60.0))
	var pets := _pets()
	for pet in pets:
		var d := _h(pet.global_position, _slot_of(pet))
		var clear := _clearance(pet)
		print("[t_petfollow] settled %s slot_d=%.2f (inner %.2f outer %.2f) player_d=%.2f clear=%.2f" % [pet.def.id, d, pet.brain.follow_inner(), pet.brain.follow_outer(), _h(pet.global_position, player.global_position), clear])
		_expect(d <= float(pet.brain.follow_outer()), "%s settled %.2f m from its slot, outside the outer radius %.2f" % [pet.def.id, d, pet.brain.follow_outer()])
		_expect(_h(pet.global_position, player.global_position) >= clear - 0.05, "%s stands %.2f m from the survivor, inside its %.2f m clearance" % [pet.def.id, _h(pet.global_position, player.global_position), clear])
	# No two pets overlap: (r1 + r2) apart, not stacked.
	for i in pets.size():
		for j in range(i + 1, pets.size()):
			var a: Node = pets[i]
			var b: Node = pets[j]
			var want: float = float(a.body_radius()) + float(b.body_radius())
			var got_d := _h(a.global_position, b.global_position)
			_expect(got_d >= want, "%s and %s stand %.2f m apart, inside r1+r2 = %.2f" % [a.def.id, b.def.id, got_d, want])
	_sections += 1

# ---------------------------------------------------------------- 3. hysteresis

func _test_hysteresis() -> void:
	var pets := _pets()
	var pet: Node = pets[0]
	var slot := _slot_of(pet)
	var inner := float(pet.brain.follow_inner())
	var outer := float(pet.brain.follow_outer())
	var mid := (inner + outer) * 0.5
	# Between the two radii: a settled pet holds, it does not start shuffling.
	pet.global_position = slot + Vector3(0, 0, mid)
	pet.stop_move()
	if pet.brain:
		pet.brain.set("_following", false)
		pet.brain._think(0.1)
	var held := not bool(pet._path_active)
	# Past the outer radius: it walks.
	pet.global_position = slot + Vector3(0, 0, outer + 0.5)
	pet.stop_move()
	pet.brain._think(0.1)
	var walked := bool(pet._path_active)
	print("[t_petfollow] hysteresis: at %.2f m (inner %.2f outer %.2f) holds=%s; at %.2f m walks=%s" % [mid, inner, outer, held, outer + 0.5, walked])
	_expect(held, "a pet %.2f m from its slot (between inner %.2f and outer %.2f) started walking" % [mid, inner, outer])
	_expect(walked, "a pet %.2f m from its slot (outside outer %.2f) did not walk" % [outer + 0.5, outer])
	pet.stop_move()
	await physics_frame
	_sections += 1

# ---------------------------------------------------------------- 4. no shuffling while the survivor stands still

func _test_no_shuffle() -> void:
	await _wait_settle(SETTLE_FRAMES)
	var before: Array[Vector3] = []
	for pet in _pets():
		before.append(pet.global_position)
	for i in STILL_FRAMES:
		await physics_frame
	var moved := 0.0
	var pets := _pets()
	for i in pets.size():
		moved = maxf(moved, pets[i].global_position.distance_to(before[i]))
	print("[t_petfollow] still 5 s: max pet movement %.3f m" % moved)
	_expect(moved < 0.05, "a settled pet moved %.3f m while the survivor stood still" % moved)
	for pet in pets:
		_expect(_h(pet.global_position, _slot_of(pet)) <= float(pet.brain.follow_inner()) + 0.35, "%s drifted out of its inner radius while the survivor stood still" % pet.def.id)
	_sections += 1

# ---------------------------------------------------------------- 5. walking 20 m: they follow and settle

func _test_walk() -> void:
	var start: Vector3 = player.global_position
	var step := Vector3(0.1, 0, 0)
	for i in WALK_FRAMES:
		player.global_position += step
		await physics_frame
	var walked := _h(player.global_position, start)
	_expect(walked > 19.0, "the survivor only walked %.1f m, want 20" % walked)
	var got := await _wait_settle(SETTLE_FRAMES)
	_expect(got >= 0, "the pets did not settle again after a 20 m walk within %.0f s" % (SETTLE_FRAMES / 60.0))
	for pet in _pets():
		var d := _h(pet.global_position, _slot_of(pet))
		print("[t_petfollow] after walk %s slot_d=%.2f player_d=%.2f" % [pet.def.id, d, _h(pet.global_position, player.global_position)])
		_expect(d <= float(pet.brain.follow_outer()), "%s is %.2f m from its slot after the walk (outer %.2f)" % [pet.def.id, d, pet.brain.follow_outer()])
		_expect(_h(pet.global_position, player.global_position) >= _clearance(pet) - 0.05, "%s is inside the survivor's clearance after the walk" % pet.def.id)
	_sections += 1

# ---------------------------------------------------------------- 6. the survivor walks into a pet

func _test_step_aside() -> void:
	var pets := _pets()
	var pet: Node = pets[0]
	var clear := _clearance(pet)
	# Stacked on the survivor's capsule: the pet must step out, not stand under it.
	pet.global_position = player.global_position + Vector3(0, 0, 0.15)
	pet.stop_move()
	if pet.brain:
		pet.brain.set("_following", true)
	var inside := _h(pet.global_position, player.global_position)
	for i in 90:
		await physics_frame
		if _h(pet.global_position, player.global_position) >= clear:
			break
	var after := _h(pet.global_position, player.global_position)
	print("[t_petfollow] step aside: %.2f m -> %.2f m (clearance %.2f)" % [inside, after, clear])
	_expect(after >= clear - 0.05, "the survivor walked into a pet and it stayed %.2f m away (clearance %.2f)" % [after, clear])
	_sections += 1

# ---------------------------------------------------------------- 7. orders keep working

func _test_orders() -> void:
	var pets := _pets()
	var pet: Node = pets[0]
	var guard_slot := float(pet.brain.slot_distance())
	pet.brain.order(&"heel")
	_expect(pet.brain.mode == &"heel", "HEEL did not set the pet's mode")
	var heel_slot := float(pet.brain.slot_distance())
	_expect(heel_slot < guard_slot, "HEEL's slot %.2f is not closer than guard's %.2f" % [heel_slot, guard_slot])
	_expect(float(pet.brain.guard_radius(player)) > 0.0, "a pet's guard radius is not positive")
	pet.brain.order(&"guard")
	_expect(pet.brain.mode == &"guard" and pet.brain.order_target == null, "GUARD did not return the pet to guard")
	var target := _stray(&"velociraptor", &"")
	target.brain.process_mode = Node.PROCESS_MODE_DISABLED
	pet.brain.order(&"attack", target)
	_expect(pet.brain.mode == &"attack" and pet.brain.order_target == target, "SIC did not take the ordered target")
	target.free()
	pet.brain.order(&"guard")
	_sections += 1

# ---------------------------------------------------------------- 8. PETSTAY: Stay holds, fights back, returns; Follow

## A wild animal beside the pet that does not think (it only has to be there to be fought).
func _wild(species: StringName, at: Vector3) -> Node:
	var c: Node = load(CREATURE_SCENE).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(species))
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _test_stay() -> void:
	await _wait_settle(SETTLE_FRAMES)
	var pet: Node = _pets()[0]
	var rec: RefCounted = pet.pet_record
	player.pets.set_command(pet, &"stay")
	_expect(pet.brain.mode == &"stay" and rec.command == &"stay", "Stay did not set the pet's mode and record (%s / %s)" % [pet.brain.mode, rec.command])
	_expect(&"follow" in player.pets.entries(pet).map(func(r): return r["id"]), "a staying pet's radial does not offer Follow")
	var spot: Vector3 = pet.global_position
	# 1. The survivor walks 20 m: the staying pet does not follow.
	for i in WALK_FRAMES:
		player.global_position += Vector3(0.1, 0, 0)
		await physics_frame
	for i in 120:
		await physics_frame
	var drift := _h(pet.global_position, spot)
	print("[t_petfollow] stay: survivor walked 20 m, pet moved %.3f m" % drift)
	_expect(drift < 0.5, "a staying pet moved %.2f m while the survivor walked 20 m" % drift)
	# 2. Hit it: it turns on the attacker, then walks back once the attacker is dead.
	var foe := _wild(&"compsognathus", spot + Vector3(0, 0, 4.0))
	pet.health.take_damage(1.0, foe)
	var fought := false
	var left_spot := 0.0
	for i in 240:
		await physics_frame
		if pet.brain.attack_target == foe and pet.brain.state in [&"chase", &"attack"]:
			fought = true
		left_spot = maxf(left_spot, _h(pet.global_position, spot))
		if fought and left_spot > 1.0:
			break
	print("[t_petfollow] stay: hit -> fought=%s state=%s left spot %.2f m" % [fought, pet.brain.state, left_spot])
	_expect(fought, "a staying pet did not fight back the animal that hit it")
	foe.health.take_damage(99999.0, player)
	var back := INF
	for i in 600:
		await physics_frame
		back = _h(pet.global_position, spot)
		if back < 0.5 and not bool(pet._path_active):
			break
	print("[t_petfollow] stay: foe dead, pet %.2f m from its stay spot" % back)
	_expect(back < 0.6, "a staying pet did not walk back to its stay spot after the fight (%.2f m)" % back)
	_expect(_h(pet.global_position, player.global_position) > 15.0, "a staying pet followed the survivor after the fight")
	# 3. Save format: the additive "command" key round-trips; an old row without it loads as follow.
	var row: Dictionary = rec.to_dict()
	_expect(str(row.get("command", "")) == "stay", "PetRecord.to_dict has no command=stay (%s)" % row.get("command"))
	_expect(PR.from_dict(row).command == &"stay", "a saved Stay does not load as Stay")
	row.erase("command")
	_expect(PR.from_dict(row).command == &"follow", "an old save without command does not load as Follow")
	# 4. Dismiss and summon: it comes back staying.
	var idx: int = player.bonded.find(rec)
	player.summon_pet(idx)  # out -> dismissed
	player.summon_pet(idx)
	await physics_frame
	var again: Node = null
	for c in _pets():
		if c.pet_record == rec:
			again = c
	_expect(again != null and again.brain.mode == &"stay", "a stayed pet did not come back staying after dismiss/summon")
	if again == null:
		return
	# 5. Follow: it comes back to its slot beside the survivor.
	player.pets.set_command(again, &"follow")
	_expect(again.brain.mode == &"guard" and rec.command == &"follow", "Follow did not return the pet to guard")
	var reached := false
	for i in SETTLE_FRAMES:
		await physics_frame
		if _settled(again):
			reached = true
			break
	print("[t_petfollow] follow: pet %.2f m from its slot" % _h(again.global_position, _slot_of(again)))
	_expect(reached, "Follow did not bring the pet back to its slot")
	_sections += 1
