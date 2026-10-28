extends SceneTree
## Spec 17 acceptance (owner: "when next to water, menu items pop up like washing and drinking").
## On the home island: Drink and Wash are offered 1 m from the river and standing in it, Fill too
## with an empty bucket; never once the survivor walks away, on dry grass, or at the salt sea
## (PRD :314-315). in_water follows the heightmap. Drink clears Thirsty and grants Quenched, which
## cuts heat fatigue and gives no Energy; Wash clears Dirty and Very dirty and grants Clean, with no
## direct fatigue rest; Fill turns an empty bucket into a water bucket at its level; the verbs go
## through PlayerActions (online they become intents). Gathering, butchering and hits make the
## survivor Dirty, then Very dirty; standing in the sea makes them Wet, not Thirsty (PRD :284).
## A harvested (BARE) tile in the river stays fresh. Statuses reach fatigue on every PlayerSim
## branch, not only walking. The statuses scale fatigue as statuses.json says, no
## thirst/hunger/hygiene meter exists, and the check is cheap.
## Usage: godot --headless --path game --script res://tests/t_water.gd

const WATER_Y := -0.05 ## HarbourSite.WATER_Y
const TILE_MUD := 6    ## IslandTerrain.TileType.MUD: the river channel and its banks
const NO_METER := ["thirst", "hunger", "hygien", "hydrat", "dirt", "clean", "quench", "satiet"]

var failures: Array[String] = []
var _started := false
var host: Node3D
## `godot --script` compiles this file before the autoloads exist, so game classes are loaded at
## run time and used untyped (the t_player pattern).
var player
var data: Node
var rt
var IT: GDScript
var WA: GDScript
var ItemStackS: GDScript
var CorpseS: GDScript
var dirt: Dictionary = {}

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	IT = load("res://scripts/world/island_terrain.gd")
	ItemStackS = load("res://scripts/items/item_stack.gd")
	CorpseS = load("res://scripts/creatures/corpse.gd")
	if ResourceLoader.exists("res://scripts/player/water_access.gd"):
		WA = load("res://scripts/player/water_access.gd")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/water.json")) if FileAccess.file_exists("res://data/water.json") else null
	dirt = (parsed as Dictionary).get("dirt", {}) if parsed is Dictionary else {}
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_water] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	host = Node3D.new()
	host.name = "TWater"
	get_root().add_child(host)
	var world := get_root().get_node("World")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	rt = world.runtime
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	# FULLFATIGUE: an empty stomach doubles every fatigue gain. Hold her at "normal" (x1.0) with one meal that
	# never digests, so each status multiplier below is checked alone.
	var dig = load("res://scripts/items/digestion.gd").of(player)
	dig.rows().clear()  # the starter meal every survivor gets would drain over the test
	dig.starter_given = true
	dig.schedule(&"starter", 1.0, 1.0e9)
	player.global_position = rt._camp_pos + Vector3(0, 1, 0)
	await _frames(5)
	var river: Vector3 = _find_shallow(true)
	var bank: Vector3 = _bank(river)
	var sea: Vector3 = _find_shallow(false)
	var deep: Vector3 = _find_deep()
	print("[t_water] spots river=%s bank=%s (water %.1f m away) sea=%s deep=%s" % [river, bank, _water_dist(bank), sea, deep])
	_expect(river != Vector3.ZERO and sea != Vector3.ZERO, "the home island has wadeable river and sea water")
	_expect(deep != Vector3.ZERO, "the home island has deep swimmable water")
	_test_hexes(river, bank, sea)
	_test_bare_river_tile(river)
	await _test_in_water_and_thirst(river, sea)
	await _test_wading_and_swimming(river, deep)
	await _test_walk_in_swim()
	await _test_sea_hint(sea)
	await _test_staggered(river)
	_test_drink(bank)
	_test_wash(bank)
	_test_fill(bank)
	_test_command_layer(bank)
	await _test_fatigue(bank)
	_test_dirt()
	_test_no_meter()
	_test_cheap(bank)
	await _test_save_load(river, bank)
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_water] PASS")
		quit(0)
	else:
		print("[t_water] FAIL count=%d" % failures.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

# ---------------------------------------------------------------- spots

func _is_water(x: float, z: float) -> bool:
	return rt.surface_y(x, z) < WATER_Y

func _is_river(x: float, z: float) -> bool:
	return int(IT.tile_type_at_world(rt, x, z)) == TILE_MUD

## The deep middle of the river (or wadeable sea), nearest a point 38 m from camp (or 12 m from
## the harbour arrival), off the z = 0 line the base's straight "Wet" box covered.
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

func _find_deep() -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	var half: float = rt._size * 0.5 - 1.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var h: float = rt.surface_y(x, z)
			if h < WATER_Y - 1.5:  # past WaterAccess.SWIM_DEPTH_M (1.3 m)
				var d := Vector2(x, z).length()
				if d < best_d:
					best_d = d
					best = Vector3(x, h, z)
			z += 1.0
		x += 1.0
	return best

## Dry ground 1 m past the river's edge, walking out of the water the short way along z.
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

func _water_dist(at: Vector3) -> float:
	if _is_water(at.x, at.z):
		return 0.0
	var r := 0.1
	while r <= 15.0:
		for k in 48:
			var a := TAU * float(k) / 48.0
			if _is_water(at.x + cos(a) * r, at.z + sin(a) * r):
				return r
		r += 0.1
	return INF

## Away from `bank` along the line from the river, `metres` further inland.
func _inland(river: Vector3, bank: Vector3, metres: float) -> Vector3:
	var out := Vector3(bank.x - river.x, 0.0, bank.z - river.z).normalized()
	return bank + out * metres

func _ids_at(at: Vector3) -> Array:
	player.global_position = Vector3(at.x, rt.surface_y(at.x, at.z) + 0.1, at.z)
	var ids: Array = []
	for a in player.context_actions():
		ids.append(str(a["id"]))
	return ids

# ---------------------------------------------------------------- the hexes

func _test_hexes(river: Vector3, bank: Vector3, sea: Vector3) -> void:
	var ids := _ids_at(bank)
	_expect(_water_dist(bank) <= 1.2 and not _is_water(bank.x, bank.z), "bank spot is dry with the river %.1f m away" % _water_dist(bank))
	_expect("drink" in ids and "wash" in ids, "1 m from the river: Drink and Wash are offered %s" % [ids])
	ids = _ids_at(river)
	_expect("drink" in ids and "wash" in ids, "standing in the river: Drink and Wash are offered %s" % [ids])
	var far := _inland(river, bank, 2.5)
	ids = _ids_at(far)
	_expect(not "drink" in ids and not "wash" in ids, "walked %.1f m from the river: the hexes are gone %s" % [_water_dist(far), ids])
	far = _inland(river, bank, 8.0)
	ids = _ids_at(far)
	_expect(not "drink" in ids and not "wash" in ids, "%.1f m from the river: no hexes %s" % [_water_dist(far), ids])
	ids = _ids_at(sea)
	_expect(not "drink" in ids and not "wash" in ids, "standing in the salt sea: no Drink/Wash (PRD :315) %s" % [ids])
	var shore: Vector3 = sea - Vector3(sea.x, 0.0, sea.z).normalized() * 1.0
	while _is_water(shore.x, shore.z):
		shore -= Vector3(sea.x, 0.0, sea.z).normalized() * 0.25
	ids = _ids_at(shore)
	_expect(not "drink" in ids and not "wash" in ids, "on the beach by the sea: no Drink/Wash %s" % [ids])
	# The base's straight 10 m "Wet" box on z = 0 offered them on dry grass across the island.
	var mid := Vector3(-48.0, 0.0, 0.0)
	ids = _ids_at(mid)
	_expect(_water_dist(mid) > 8.0 and not "drink" in ids and not "wash" in ids, "dry grass on z = 0, %.1f m from water: no hexes %s" % [_water_dist(mid), ids])
	ids = _ids_at(bank)
	_expect(not "fill" in ids, "no empty bucket: no Fill hex (no inert button) %s" % [ids])
	player.inventory.add(ItemStackS.make(&"empty_bucket", 1))
	ids = _ids_at(bank)
	_expect("fill" in ids, "with an empty bucket by the river: Fill is offered %s" % [ids])
	ids = _ids_at(far)
	_expect(not "fill" in ids, "with an empty bucket away from water: no Fill %s" % [ids])
	player.inventory.consume(&"empty_bucket", 1)
	var icons: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_icons.json")) as Dictionary).get("icons", {})
	for id in ["drink", "wash", "fill"]:
		_expect(str(icons.get(id, "")).begins_with("res://assets/icons/ui/"), "the %s hex has a white UI icon (%s)" % [id, icons.get(id, "none")])

# ---------------------------------------------------------------- in water, Wet, Thirsty

func _stand(at: Vector3, frames: int = 10) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(at.x, rt.surface_y(at.x, at.z) + 0.1, at.z)
	await _frames(frames)

func _test_in_water_and_thirst(river: Vector3, sea: Vector3) -> void:
	await _stand(Vector3(-48.0, 0.0, 0.0))
	_expect(not player.in_water, "in_water is false on dry grass on z = 0 (the old Wet box said true)")
	await _stand(river)
	_expect(player.in_water, "in_water is true standing in the river (ground %.2f)" % rt.surface_y(player.global_position.x, player.global_position.z))
	player.statuses.from_array([])
	player.sim._wet_acc = 4.95
	await _frames(10)
	_expect(player.statuses.has(&"wet") and not player.statuses.has(&"thirsty"), "5 s in the river: Wet, not Thirsty %s" % [_status_ids()])
	await _stand(sea)
	_expect(player.in_water, "in_water is true standing in the sea")
	player.statuses.from_array([])
	player.sim._wet_acc = 4.95
	await _frames(10)
	_expect(player.statuses.has(&"wet") and not player.statuses.has(&"thirsty"), "5 s in the sea: Wet, not Thirsty (PRD :284; seawater thirst is for drinking it) %s" % [_status_ids()])
	player.statuses.from_array([])

func _test_wading_and_swimming(shallow: Vector3, deep: Vector3) -> void:
	_expect(WA != null and WA.has_method("depth") and WA.has_method("movement_speed_multiplier"),
		"water access distinguishes shallow and deep water")
	_expect(player.has_method("is_swimming"), "player exposes swimming state")
	if WA == null or not WA.has_method("depth") or not WA.has_method("movement_speed_multiplier") or not player.has_method("is_swimming"):
		return
	var shallow_depth: float = WA.depth(shallow)
	var deep_depth: float = WA.depth(deep)
	var wade_mult: float = WA.movement_speed_multiplier(shallow)
	var swim_mult: float = WA.movement_speed_multiplier(deep)
	_expect(shallow_depth > 0.0 and deep_depth > shallow_depth, "water depth follows the terrain (%.2f m / %.2f m)" % [shallow_depth, deep_depth])
	_expect(wade_mult < 1.0 and swim_mult <= wade_mult, "wading and swimming slow movement (x%.2f / x%.2f)" % [wade_mult, swim_mult])
	await _stand(shallow)
	_expect(not player.is_swimming(), "shallow water is wading, not swimming")
	await _stand(deep)
	_expect(player.is_swimming(), "deep water enters swimming state")
	var hp0: float = player.vitals.health
	player.vitals.energy = 0.0
	player.sim._swim_damage_acc = 0.95
	await _frames(10)
	_expect(player.vitals.health < hp0, "swimming while out of energy damages the survivor")
	player.vitals.energy = player.vitals.max_energy

## Owner 2026-10-28: "i cant swim". Walking off a beach with the move keys must lift her off the
## seabed and float her (the old position nudge lost to move_and_slide's floor snap every frame,
## so she walked along the bottom); the swim clips play, and walking back out she walks again.
func _test_walk_in_swim() -> void:
	var dirv := Vector3(1, 0, 0)
	var r := 0.0
	while r < rt._size * 0.5 and rt.surface_y(r, 0.0) > 0.3:
		r += 0.5
	var start := dirv * (r - 4.0)
	_expect(rt.surface_y(start.x, start.z) > 0.3 and rt.surface_y(r + 20.0, 0.0) < WATER_Y - 1.5, "a beach at +x runs into deep sea")
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.current = true
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(start.x, rt.surface_y(start.x, start.z) + player.half_height(), start.z)
	await _frames(20)
	cam.global_position = player.global_position + Vector3(-5, 5, 0)
	cam.look_at(player.global_position)  # camera forward is +x: move_up walks into the sea
	Input.action_press("move_up")
	await _frames(360)
	var p: Vector3 = player.global_position
	var depth: float = WA.depth(p)
	var clip: StringName = player.anim.current_clip
	_expect(depth > 1.5 and player.is_swimming(), "walked off the beach into deep sea (%.2f m deep): swimming" % depth)
	_expect(player.feet_position().y > rt.surface_y(p.x, p.z) + 0.8 and absf(p.y - (WATER_Y + 0.08)) < 0.15,
		"she floats at the surface (centre y %.2f), not on the seabed (%.2f)" % [p.y, rt.surface_y(p.x, p.z)])
	_expect(clip == &"swim", "the swim clip plays while she swims forward (%s)" % clip)
	_expect(player.anim.swim_lift > 0.0, "the crawl is lifted into the water (%.2f)" % player.anim.swim_lift)
	Input.action_release("move_up")
	await _frames(40)
	_expect(player.anim.current_clip == &"swim_idle", "treading water when she stops (%s)" % player.anim.current_clip)
	cam.global_position = player.global_position + Vector3(5, 5, 0)
	cam.look_at(player.global_position)  # camera forward is now -x: back to the beach
	Input.action_press("move_up")
	await _frames(600)
	Input.action_release("move_up")
	await _frames(10)
	p = player.global_position
	_expect(not player.in_water and not player.is_swimming() and player.is_on_floor(), "swam back to the beach and stands on it (ground %.2f)" % rt.surface_y(p.x, p.z))
	_expect(player.anim.current_clip != &"swim" and player.anim.current_clip != &"swim_idle" and player.anim.swim_lift == 0.0,
		"on land the swim clips stop (%s, lift %.2f)" % [player.anim.current_clip, player.anim.swim_lift])
	cam.queue_free()
	player.vitals.energy = player.vitals.max_energy

## INTERACT in the salt sea offers nothing (PRD :314-315); its press then names the river (hud_field).
func _test_sea_hint(sea: Vector3) -> void:
	await _stand(sea)
	var pick := str(player.controls.interact_choice().get("id", ""))
	_expect(player.in_water and pick != "drink", "INTERACT never offers Drink in the salt sea (%s)" % pick)

## The water verbs after a save and reload: a Dirty, Thirsty survivor saved at the river loads with
## both statuses, INTERACT offers Drink and the hexes Wash, and both still work.
func _test_save_load(river: Vector3, bank: Vector3) -> void:
	var SG: GDScript = load("res://scripts/core/save_game.gd")
	await _stand(river)
	player.statuses.from_array([])
	player.statuses.apply(&"very_dirty")
	player.statuses.apply(&"thirsty")
	_expect(SG.save_now(), "a save at the river writes")
	player.statuses.from_array([])
	SG.load_now(host)
	await _frames(10)
	rt = get_root().get_node("World").runtime  # the reload rebuilds the island
	await _stand(bank)
	_expect(player.statuses.has(&"very_dirty") and player.statuses.has(&"thirsty"), "after the reload she is still Very dirty and Thirsty %s" % [_status_ids()])
	var ids := _ids_at(bank)
	_expect(ids.has("drink") and ids.has("wash"), "after the reload Drink and Wash are offered by the river %s" % [ids])
	var pick := str(player.controls.interact_choice().get("id", ""))
	_expect(pick == "drink", "INTERACT offers Drink by the river (%s)" % pick)
	player.context_action("drink")
	player.context_action("wash")
	_expect(not player.statuses.has(&"thirsty") and player.statuses.has(&"quenched"), "after the reload Drink clears Thirsty %s" % [_status_ids()])
	_expect(not player.statuses.has(&"very_dirty") and player.statuses.has(&"clean"), "after the reload Wash clears Very dirty and grants Clean %s" % [_status_ids()])

## Harvesting a node turns its tile BARE until it regrows; a river tile must stay fresh water.
func _test_bare_river_tile(river: Vector3) -> void:
	if WA == null:
		return
	var tile := Vector2i(floori(river.x), floori(river.z))
	var base := int(IT.tile_type_at_world(rt, river.x, river.z))
	IT.set_tile_type(rt, tile, 7)  # IslandTerrain.TileType.BARE, as IslandRuntime._on_tile_bare does
	var bare := int(IT.tile_type_at_world(rt, river.x, river.z)) == 7
	_expect(bare and WA.is_fresh(river), "a harvested (BARE) river tile is still fresh water (bare=%s)" % bare)
	IT.set_tile_type(rt, tile, base)

## Statuses and in_water refresh on every PlayerSim branch, not only while walking.
func _test_staggered(river: Vector3) -> void:
	player.statuses.from_array([])
	player.statuses.apply(&"dirty")
	player.vitals.fatigue_gain_mult = 1.0
	player.in_water = false
	player.sim._stagger_left = 10.0
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(river.x, rt.surface_y(river.x, river.z) + 0.1, river.z)
	await _frames(3)
	_expect(player.sim._stagger_left > 0.0 and is_equal_approx(player.vitals.fatigue_gain_mult, 1.2) and player.in_water,
		"staggered in the river: Dirty's x1.2 and in_water still apply (mult %.2f, in_water %s)" % [player.vitals.fatigue_gain_mult, player.in_water])
	player.sim._stagger_left = 0.0
	player.statuses.from_array([])

func _status_ids() -> Array:
	return player.statuses.to_array().map(func (r: Dictionary) -> String: return str(r["id"]))

# ---------------------------------------------------------------- the effects

func _test_drink(bank: Vector3) -> void:
	_ids_at(bank)
	player.statuses.from_array([])
	player.statuses.apply(&"thirsty")
	_expect(player.statuses.has(&"thirsty"), "Thirsty is a status in statuses.json")
	player.vitals.energy = 50.0
	player.context_action("drink")
	_expect(not player.statuses.has(&"thirsty") and player.statuses.has(&"quenched"), "Drink clears Thirsty and grants Quenched %s" % [_status_ids()])
	_expect(is_equal_approx(player.vitals.energy, 50.0), "Drink gives no Energy (food fills Energy, PRD 6.2; was +5): %.1f" % player.vitals.energy)
	var q = data.status(&"quenched")
	_expect(q != null and q.get("heat_fatigue_mult") != null and float(q.heat_fatigue_mult) < 1.0, "Quenched cuts heat fatigue (PRD :314)")

func _test_wash(bank: Vector3) -> void:
	_ids_at(bank)
	for id in [&"dirty", &"very_dirty"]:
		player.statuses.from_array([])
		player.statuses.apply(id)
		_expect(player.statuses.has(id), "%s is a status in statuses.json" % id)
		player.vitals.fatigue = 40.0
		player.context_action("wash")
		_expect(not player.statuses.has(id) and player.statuses.has(&"clean"), "Wash clears %s and grants Clean %s" % [id, _status_ids()])
		_expect(is_equal_approx(player.vitals.fatigue, 40.0), "Wash is no instant rest (was -2 fatigue): %.1f" % player.vitals.fatigue)
	var c = data.status(&"clean")
	_expect(c != null and is_equal_approx(c.duration, 360.0) and is_equal_approx(float(c.get("fatigue_mult")), 0.8), "Clean lasts 6 min at -20 % fatigue gain (PRD 6.4)")
	# Away from water the verb refuses even when called directly (a sent intent is not the HUD).
	player.statuses.from_array([])
	player.statuses.apply(&"dirty")
	_ids_at(Vector3(-48.0, 0.0, 0.0))
	player.context_action("wash")
	_expect(player.statuses.has(&"dirty") and not player.statuses.has(&"clean"), "Wash away from water changes nothing")
	player.statuses.from_array([])

func _test_fill(bank: Vector3) -> void:
	_ids_at(bank)
	player.inventory.add(ItemStackS.make(&"empty_bucket", 1, {}, 7))
	var water0: int = player.inventory.count_of(&"water_bucket")
	player.context_action("fill")
	var i: int = player.inventory.find_first(&"water_bucket")
	_expect(player.inventory.count_of(&"empty_bucket") == 0 and player.inventory.count_of(&"water_bucket") == water0 + 1, "Fill turns the empty bucket into a water bucket")
	_expect(i >= 0 and player.inventory.slots[i].level == 7, "the water bucket keeps the bucket's level 7 (as the well's fill_bucket does): %s" % [player.inventory.slots[i].level if i >= 0 else "none"])
	player.inventory.consume(&"water_bucket", player.inventory.count_of(&"water_bucket"))

func _test_command_layer(bank: Vector3) -> void:
	_ids_at(bank)
	var acts = player.actions
	_expect(acts.has_method("drink") and acts.has_method("wash") and acts.has_method("fill_water"), "PlayerActions has the drink / wash / fill_water verbs")
	if not acts.has_method("drink"):
		return
	acts.online = true
	acts.sent.clear()
	player.statuses.from_array([])
	player.statuses.apply(&"thirsty")
	player.context_action("drink")
	player.context_action("wash")
	var ops: Array = acts.sent.map(func (s: Dictionary) -> String: return str(s["op"]))
	_expect(ops == ["act.drink", "act.wash"] and player.statuses.has(&"thirsty"), "online, Drink and Wash become intents and change nothing locally %s" % [ops])
	acts.online = false
	acts.sent.clear()
	player.statuses.from_array([])

# ---------------------------------------------------------------- fatigue

func _test_fatigue(bank: Vector3) -> void:
	var want := {&"dirty": 1.2, &"very_dirty": 1.5, &"thirsty": 1.2, &"clean": 0.8, &"quenched": 1.0}
	for id in want:
		var def = data.status(id)
		_expect(def != null and def.get("fatigue_mult") != null and is_equal_approx(float(def.fatigue_mult), float(want[id])), "%s fatigue gain x%.1f in statuses.json" % [id, want[id]])
	if not player.statuses.has_method("fatigue_mult"):
		_expect(false, "StatusEffects.fatigue_mult exists")
		return
	# The survivor's real fatigue gain: PlayerSim applies the statuses every physics frame.
	await _stand(bank, 2)
	player.statuses.from_array([])
	player.statuses.apply(&"dirty")
	await _frames(3)
	_expect(is_equal_approx(player.vitals.fatigue_gain_mult, 1.2), "Dirty: fatigue gain x1.2 on the survivor (%.2f)" % player.vitals.fatigue_gain_mult)
	player.statuses.from_array([])
	player.statuses.apply(&"very_dirty")
	player.statuses.apply(&"thirsty")
	await _frames(3)
	_expect(is_equal_approx(player.vitals.fatigue_gain_mult, 1.8), "Very dirty and Thirsty stack: x1.8 (%.2f)" % player.vitals.fatigue_gain_mult)
	player.statuses.from_array([])
	player.statuses.apply(&"clean")
	await _frames(3)
	_expect(is_equal_approx(player.vitals.fatigue_gain_mult, 0.8), "Clean: fatigue gain x0.8 (%.2f)" % player.vitals.fatigue_gain_mult)
	# Heat: Quenched cuts the climate_heat gain by a fifth, in one synchronous step.
	player.statuses.from_array([])
	var g = get_root().get_node("Game")
	var tod: float = g.time_of_day
	g.time_of_day = 0.45
	player.vitals.fatigue_gain_mult = 1.0
	player.vitals.fatigue = 10.0
	player.tick_climate_fatigue(1.0, "desert")
	var plain: float = player.vitals.fatigue - 10.0
	player.statuses.apply(&"quenched")
	player.vitals.fatigue = 10.0
	player.tick_climate_fatigue(1.0, "desert")
	var cut: float = player.vitals.fatigue - 10.0
	g.time_of_day = tod
	_expect(plain > 0.0 and is_equal_approx(cut / plain, 0.8), "Quenched: desert heat fatigue x0.8 (%.4f -> %.4f)" % [plain, cut])
	player.statuses.from_array([])

# ---------------------------------------------------------------- dirt

func _grime() -> float:
	return float(WA.grime(player)) if WA else 0.0

func _test_dirt() -> void:
	if WA == null:
		_expect(false, "WaterAccess exists (scripts/player/water_access.gd)")
		return
	player.statuses.from_array([])
	player.set_meta(WA.GRIME, 0.0)
	# Gathering: one unit from a bare-hand node through the real finish_gather.
	var node = null
	for n in get_nodes_in_group("harvest"):
		if n.pool_units_left() > 0 and n.can_gather(player.inventory) == "":
			node = n
			break
	_expect(node != null, "a bare-hand harvest node exists")
	if node:
		player.gather_target = node
		player.actions.finish_gather()
		player.actions.cancel_work()
		_expect(is_equal_approx(_grime(), float(dirt.get("gather", 1))), "a gathered unit adds %s grime (%.1f)" % [dirt.get("gather"), _grime()])
	var g0 := _grime()
	player.receive_creature_hit(null, &"")
	_expect(is_equal_approx(_grime() - g0, float(dirt.get("hit", 2))), "a hit taken adds %s grime" % dirt.get("hit"))
	g0 = _grime()
	var corpse = CorpseS.new()
	host.add_child(corpse)
	corpse.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
	corpse.loot.add(ItemStackS.make(&"raw_meat", 2))
	player.actions.loot(corpse, corpse.loot.find_first(&"raw_meat"))
	corpse.queue_free()
	_expect(is_equal_approx(_grime() - g0, float(dirt.get("butcher", 3))), "a butchered loot stack adds %s grime" % dirt.get("butcher"))
	_expect(not player.statuses.has(&"dirty"), "a little work does not make you Dirty yet")
	player.statuses.apply(&"clean")
	while _grime() < float(dirt.get("dirty_at", 20)):
		WA.soil(player, &"gather")
	_expect(player.statuses.has(&"dirty") and not player.statuses.has(&"clean"), "at %s grime: Dirty (and no longer Clean)" % dirt.get("dirty_at"))
	while _grime() < float(dirt.get("very_dirty_at", 60)):
		WA.soil(player, &"butcher")
	_expect(player.statuses.has(&"very_dirty") and not player.statuses.has(&"dirty"), "at %s grime: Very dirty replaces Dirty" % dirt.get("very_dirty_at"))
	# A reload keeps the status; the hidden count restarts at its threshold.
	player.set_meta(WA.GRIME, 0.0)
	_expect(is_equal_approx(_grime(), float(dirt.get("very_dirty_at", 60))), "a reloaded Very dirty survivor counts from %s" % dirt.get("very_dirty_at"))
	player.statuses.from_array([])
	player.set_meta(WA.GRIME, 0.0)

# ---------------------------------------------------------------- no meters, cheap

func _test_no_meter() -> void:
	var meters: Array = []
	for obj in [player, player.vitals, player.statuses]:
		for prop in obj.get_property_list():
			for bad in NO_METER:
				if str(prop["name"]).to_lower().contains(bad):
					meters.append("%s.%s" % [obj.name, prop["name"]])
	_expect(meters.is_empty(), "no thirst / hunger / hygiene / dirt meter on the survivor, vitals or statuses %s" % [meters])
	var keys: Array = player.vitals.to_dict().keys()
	keys.sort()
	_expect(keys == ["energy", "fatigue", "health", "level_energy", "level_health", "max_energy", "max_fatigue", "max_health"], "the saved vitals are Health, Energy and fatigue only, plus the pioneer-level part of their maxima %s" % [keys])
	var hud := FileAccess.get_file_as_string("res://scripts/ui/hunt_hud.gd").to_lower()
	for bad in ["thirst", "hunger", "hygien"]:
		_expect(not hud.contains(bad), "the HUD draws no %s bar" % bad)

func _test_cheap(bank: Vector3) -> void:
	if WA == null:
		return
	var mid := Vector3(-48.0, 0.0, 0.0)  # worst case: no water, every sample runs
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		WA.near_fresh(mid if i % 2 == 0 else bank)
	var per := float(Time.get_ticks_usec() - t0) / 2000.0
	print("[t_water] near_fresh %.1f us per call" % per)
	_expect(per < 200.0, "near_fresh is cheap enough for every frame (%.1f us < 200 us)" % per)
