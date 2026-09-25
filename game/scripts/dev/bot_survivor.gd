class_name BotSurvivor
extends Node
## Autonomous survivor that plays the real game so the early loop can be debugged.
##
## It drives the same entry points a human drives through the UI: tap a harvest node, pick a
## radial hex, craft a recipe through StationCraft, hunt a creature, run a context action.
## It never calls a gameplay rule directly, so whatever it fails to do is something a player
## also cannot do. Each objective is timed and ends OK, BLOCKED (with the reason) or TIMEOUT,
## and the closing report is the debug output: what the first hour of DEADFRONT actually is.
##
## Usage: <godot> --path game -- --bot [--bot-minutes=6] [--bot-shots=/tmp/deadfront-bot]

## One rung of the early game. `craft` is a recipe id; `then` is an extra verb to run after it.
const LADDER: Array[Dictionary] = [
	{"goal": "knife", "craft": "improvised_stone_knife"},
	{"goal": "club", "craft": "club"},
	{"goal": "axe", "craft": "work_axe"},
	{"goal": "pick", "craft": "work_pick"},
	{"goal": "fire", "craft": "bonfire_kit", "then": "build:bonfire"},
	{"goal": "bench", "craft": "workbench_kit", "then": "build:workbench"},
	{"goal": "basket", "craft": "basket_kit", "then": "build:basket"},
	{"goal": "hunt", "then": "hunt"},
	{"goal": "cook", "craft": "skewer"},
	{"goal": "net", "craft": "capture_net_i"},
	{"goal": "tame", "then": "tame"},
	{"goal": "sail", "then": "travel"},
	{"goal": "away", "then": "forage"},
	{"goal": "home", "then": "return_home"},
	{"goal": "grind", "then": "grind"},
]

## Concrete items the bot will try to gather for a recipe category, best first.
const CATEGORY_ITEMS := {
	"blade_mat": ["stone", "flint"],
	"handle": ["branch"],
	"lashing": ["bark_strip", "vine", "reed", "root", "twine"],
	"herb": ["herb_leaf", "berries", "berry", "petals"],
	"cloth": ["cloth_scrap", "cloth"],
	"wood": ["wood_log", "branch"],
	"fibre": ["fibre_stalk"],
	"fuel": ["charcoal"],
	"meat": ["raw_meat", "raptor_meat"],  # looted from a corpse, never gathered
	"stone_mat": ["stone"],
}

var player: Player
var minutes: float = 6.0
var shot_dir: String = ""

var _t: float = 0.0
var _events: Array[Dictionary] = []
var _rungs: Array[Dictionary] = []
var _goal: String = "boot"
var _goal_t: float = 0.0
var _busy_time: Dictionary = {}
var _shot_n: int = 0
var _next_shot: float = 0.0
var _xp_curve: Array[Dictionary] = []
var _next_sample: float = 0.0
var _walked: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _deaths: int = 0
var _hp_low: float = 100.0

func run(host: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot-minutes="):
			minutes = maxf(0.5, float(a.substr(14)))
		elif a.begins_with("--bot-shots="):
			shot_dir = a.substr(12)
	if shot_dir != "":
		DirAccess.make_dir_recursive_absolute(shot_dir)
	print("[bot] start minutes=%.1f shots=%s" % [minutes, shot_dir if shot_dir != "" else "-"])
	await get_tree().create_timer(0.5).timeout
	# A fresh survivor, not a loaded save: the point is to measure the new-player loop.
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false):
		node.free()
	World.home_terrain = &"meadow"
	if World.island_id == &"" or World.runtime == null:
		World.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await get_tree().create_timer(1.0).timeout
	player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		print("[bot] FAIL no player")
		get_tree().quit(1)
		return
	_last_pos = player.global_position
	_event("spawn", "pos=%.0f,%.0f bag=%d/%d" % [player.global_position.x, player.global_position.z, player.inventory.used_slots(), player.inventory.slots.size()])
	_survey()
	for rung in LADDER:
		if _t >= minutes * 60.0:
			break
		await _do_rung(rung)
	_report()
	get_tree().quit(0)

# ---------------------------------------------------------------- objectives

func _do_rung(rung: Dictionary) -> void:
	var name := str(rung.get("goal", "?"))
	_goal = name
	_goal_t = _t
	var outcome := "OK"
	var detail := ""
	var rid := str(rung.get("craft", ""))
	if rid != "":
		var rec := Crafting.recipe(StringName(rid))
		if rec.is_empty():
			outcome = "BLOCKED"
			detail = "no recipe %s in data" % rid
		else:
			var missing := await _acquire_for(rec)
			if missing != "":
				outcome = "BLOCKED"
				detail = missing
			else:
				var made := await _craft(rec)
				if not made:
					outcome = "BLOCKED"
					detail = "craft %s did not produce output (station or picks)" % rid
	if outcome == "OK" and rung.has("then"):
		var r := await _verb(str(rung["then"]))
		if r != "":
			outcome = "BLOCKED"
			detail = r
	_rungs.append({"goal": name, "outcome": outcome, "detail": detail, "t": _t, "took": _t - _goal_t})
	print("[bot] rung %-7s %-8s t=%5.1fs took=%5.1fs %s" % [name, outcome, _t, _t - _goal_t, detail])

## Gather everything a recipe still needs. Returns "" or the reason it cannot be finished.
func _acquire_for(rec: Dictionary, depth: int = 0) -> String:
	for slot_v in rec.get("slots", []):
		if not slot_v is Dictionary:
			continue
		var slot: Dictionary = slot_v
		var cat := str(slot.get("category", ""))
		var need := int(slot.get("count", 1))
		if player.inventory.find_by_category(StringName(cat)).size() > 0:
			var have := 0
			for idx in player.inventory.find_by_category(StringName(cat)):
				var st := player.inventory.slots[idx]
				if st:
					have += st.count
			if have >= need:
				continue
		var wants: Array = CATEGORY_ITEMS.get(cat, [])
		if wants.is_empty():
			return "category %s has no gatherable item mapped" % cat
		var got := false
		for item_v in wants:
			var item := StringName(str(item_v))
			var before := player.inventory.count_of(item)
			var why := await _gather(item, need)
			if why != "" and why.begins_with("walked"):
				why = await _gather(item, need)  # a bite or a bump cancels gathering; try once more
			if player.inventory.count_of(item) > before:
				got = true
				break
			if why != "" and why != "no node":
				_event("gather-blocked", "%s: %s" % [item, why])
		if not got:
			# Nothing on the ground carries this category, so look for a recipe that makes one.
			# This is how a player learns that lashing comes from twisting fibre into twine.
			var sub := _recipe_making(cat)
			if not sub.is_empty() and str(sub.get("id", "")) != str(rec.get("id", "")) and depth < 2:
				_event("substitute", "%s is crafted: %s" % [cat, sub.get("id", "?")])
				var sub_why := await _acquire_for(sub, depth + 1)
				if sub_why == "" and await _craft(sub):
					got = true
				elif sub_why != "":
					return "%s needs %s, which needs %s" % [cat, sub.get("id", "?"), sub_why]
		if not got:
			return "nothing on this island yields %s (tried %s)" % [cat, ", ".join(PackedStringArray(wants))]
	return ""

## A recipe whose output carries `cat`, or {}. Lets the bot discover crafted intermediates.
func _recipe_making(cat: String) -> Dictionary:
	for rec_v in Crafting.all_recipes():
		var rec: Dictionary = rec_v
		var out_id := StringName(str((rec.get("output", {}) as Dictionary).get("id", "")))
		var def := Data.item(out_id)
		if def and StringName(cat) in def.categories:
			return rec
	return {}

## Gather up to `n` of one item from the nearest node that offers it. "" on success.
func _gather(item: StringName, n: int) -> String:
	var best: HarvestNode = null
	var best_d := INF
	var best_i := -1
	var reason := "no node"
	for node in get_tree().get_nodes_in_group("harvest"):
		var hn := node as HarvestNode
		if hn == null or hn.depleted:
			continue
		var opts := hn.options()
		for i in opts.size():
			var o: Dictionary = opts[i]
			if str(o.get("item", "")) != str(item):
				continue
			if o.has("blocked_reason"):
				reason = str(o["blocked_reason"])
				continue
			var tool := StringName(str(o.get("tool", "none")))
			if tool != &"" and tool != &"none" and not player.inventory.has_tool_class(tool):
				reason = "needs a %s" % tool
				continue
			var d := player.global_position.distance_to(hn.global_position)
			if d < best_d:
				best_d = d
				best = hn
				best_i = i
	if best == null:
		return reason
	_goal = "gather:%s" % item
	var start := player.inventory.count_of(item)
	player._interact_tap_target(best)
	await _beat(0.35)  # the radial needs a beat to open, same as a human tap
	if player._gather_radial and player._gather_radial.is_open():
		player._gather_radial._on_pick(best_i)
	else:
		return "tapping the %s opened no gather radial" % best.family
	var deadline := _t + 30.0
	var grace := _t + 1.5  # the pick takes a frame or two to become a route; do not judge it yet
	while _t < deadline and player.inventory.count_of(item) < start + n:
		if not await _beat(0.25):
			break
		if _t > grace and not player._gathering and not player.nav_active and player.gather_target == null:
			break
	var gained := player.inventory.count_of(item) - start
	if gained > 0:
		_event("gather", "%s x%d (%.0f m away)" % [item, gained, best_d])
		return ""
	return "walked %.0f m to a %s and got none" % [best_d, best.family]

func _craft(rec: Dictionary) -> bool:
	var rid := StringName(str(rec.get("id", "")))
	var out_id := StringName(str((rec.get("output", {}) as Dictionary).get("id", "")))
	var before := player.inventory.count_of(out_id)
	_goal = "craft:%s" % rid
	var station := Crafting.station_id(rec)
	if station != "":
		var st := Crafting.nearest_station(player, StringName(station))
		if st == null:
			_event("craft-blocked", "%s needs a %s and none is built" % [rid, station])
			return false
		player.nav_to(player._closest_nav_point(st.global_position))
		var walk := _t + 25.0
		while _t < walk and player.global_position.distance_to(st.global_position) > Crafting.STATION_RANGE:
			if not await _beat(0.25):
				break
		if player.global_position.distance_to(st.global_position) > Crafting.STATION_RANGE:
			_event("craft-blocked", "%s: could not reach the %s (%.0f m short)" % [rid, station, player.global_position.distance_to(st.global_position)])
			return false
	player.craft_recipe(rid, 1)
	var deadline := _t + 40.0
	while _t < deadline and player.inventory.count_of(out_id) <= before:
		if not await _beat(0.25):
			break
	if player.inventory.count_of(out_id) > before:
		_event("craft", "%s -> %s" % [rid, out_id])
		return true
	return false

## Extra verbs a rung can ask for. Returns "" or the blocker.
func _verb(kind: String) -> String:
	if kind.begins_with("build:"):
		return await _build(StringName(kind.substr(6)))
	match kind:
		"hunt":
			return await _hunt()
		"tame":
			return await _tame()
		"travel":
			return await _travel()
		"forage":
			return await _forage()
		"return_home":
			return await _return_home()
		"grind":
			return await _grind()
	return ""

func _build(kind: StringName) -> String:
	_goal = "build:%s" % kind
	var placer = player.placer
	if placer == null:
		return "player has no build placer"
	if DisplayServer.get_name() == "headless":
		# The ghost snaps to the mouse pointer, and headless has no pointer, so a refusal here
		# would say nothing about the game. Build placement is checked in the windowed run.
		return "skipped: placement follows the mouse pointer, which headless has none of"
	# Building needs ground you have claimed; the HUD's CLAIM hex is the real player flow.
	var acts: Array = []
	for a in player.context_actions():
		acts.append(str(a["id"]))
	if acts.has("claim"):
		player.context_action("claim")
		await _beat(0.4)
		_event("claim", "claimed the plot under the survivor")
	var before := get_tree().get_nodes_in_group("placed_building").size()
	placer.begin(kind)
	await _beat(0.4)
	if placer.placing == &"":
		return "build placer refused %s (cost or unlock)" % kind
	var cam := get_viewport().get_camera_3d()
	var ok := false
	var tried := 0
	for offset in [Vector3(2.5, 0, 2.5), Vector3(-2.5, 0, 2.5), Vector3(2.5, 0, -2.5), Vector3(5, 0, 0), Vector3(0, 0, 5)]:
		tried += 1
		if cam:
			Input.warp_mouse(cam.unproject_position(player.global_position + offset))
			await _beat(0.3)
			placer.tap_ground()
			await _beat(0.2)
		ok = placer.confirm(player)
		await _beat(0.4)
		if ok and get_tree().get_nodes_in_group("placed_building").size() > before:
			break
		ok = false
	if not ok:
		placer.cancel()
		return "%s refused on %d spots: %s" % [kind, tried, placer.reason if placer.reason != "" else "invalid"]
	_event("build", "%s placed" % kind)
	return ""

func _hunt() -> String:
	_goal = "hunt"
	var target: Creature = null
	var best := INF
	for node in get_tree().get_nodes_in_group("creatures"):
		var c := node as Creature
		if c == null or c.is_pet or c.health == null or c.health.dead:
			continue
		var d := player.global_position.distance_to(c.global_position)
		if d < best:
			best = d
			target = c
	if target == null:
		return "no wild creature anywhere on the home island"
	var species := str(target.def.id) if target.def else "?"
	_event("hunt-start", "%s %.0f m away" % [species, best])
	player.hunt.start(target)
	var deadline := _t + 90.0
	while _t < deadline and target and is_instance_valid(target) and not target.health.dead:
		# Starting a hunt does not walk the survivor there; close the distance like a player.
		var gap := player.global_position.distance_to(target.global_position)
		if gap > 2.0 and not player.nav_active:
			player.nav_to(player._closest_nav_point(target.global_position))
		if not await _beat(0.25):
			break
		if player.dead:
			return "the survivor died to a %s" % species
	if target == null or not is_instance_valid(target):
		return "the %s vanished mid-hunt" % species
	if not target.health.dead:
		return "could not kill a %s in 90 s (hp %.0f, %.0f m away)" % [species, target.health.health, player.global_position.distance_to(target.global_position)]
	_event("kill", species)
	var corpse := get_tree().get_first_node_in_group("corpse") as Corpse
	if corpse == null:
		return "kill left no corpse to loot"
	player.nav_to(corpse.global_position)
	var wait := _t + 20.0
	while _t < wait and player.global_position.distance_to(corpse.global_position) > 2.5:
		if not await _beat(0.25):
			break
	var meat := player.inventory.count_of(&"raw_meat") + player.inventory.count_of(&"raptor_meat")
	player.context_action("loot")
	await _beat(1.0)
	# Opening the chest is not taking anything: pull every slot so the meat is actually in the bag.
	var taken := 0
	for pass_i in 8:
		var opts := corpse.loot_options(player.inventory)
		if opts.is_empty():
			break
		player._begin_corpse_take(corpse, int((opts[0] as Dictionary)["slot"]))
		if not await _beat(1.8):
			break
		taken += 1
	if player.ui and player.ui.visible:
		player.ui.hide()
	var gained := player.inventory.count_of(&"raw_meat") + player.inventory.count_of(&"raptor_meat") - meat
	_event("loot", "%d slots taken, meat +%d" % [taken, gained])
	if gained <= 0 and taken == 0:
		return "the corpse gave up nothing"
	return ""

## Wear the animal below the capture threshold, tackle it over, then feed it.
func _tame() -> String:
	_goal = "tame"
	var target: Creature = null
	for node in get_tree().get_nodes_in_group("creatures"):
		var c := node as Creature
		if c == null or c.is_pet or c.health == null or c.health.dead:
			continue
		if not (c.def and c.def.tameable):
			continue
		# Prefer the lowest capture tier: that is the species the game means as a first tame.
		if target == null or c.def.capture_tier < target.def.capture_tier:
			target = c
	if target == null:
		return "no tameable creature on this island"
	var species := str(target.def.id)
	# Food first, or the knockdown window is wasted walking to a bush.
	var menu: Array[StringName] = []
	menu.assign(target.def.preferred_food)
	menu.append_array(target.def.accepted_food)
	for food in menu:
		if FieldTame.food_in_bag(player.inventory, target) != &"":
			break
		await _gather(food, 3)
	if FieldTame.food_in_bag(player.inventory, target) == &"":
		return "nothing on this island a %s will eat (wants %s)" % [species, ", ".join(PackedStringArray(menu))]
	_event("tame-start", "%s, food %s" % [species, FieldTame.food_in_bag(player.inventory, target)])
	player.hunt.start(target)
	var deadline := _t + 120.0
	while _t < deadline and is_instance_valid(target) and not target.health.dead:
		if not await _beat(0.25):
			break
		if player.dead:
			return "the survivor died taming a %s" % species
		if target.statuses.has_flag(&"knockdown"):
			break
		# Below the capture threshold a tackle puts it on the ground; that is the window.
		if FieldTame.health_allows_capture(target.health.health / maxf(1.0, target.health.max_health)):
			player.hunt.use_tackle()
			await _beat(0.4)
	if not is_instance_valid(target) or target.health.dead:
		return "the %s died before it could be knocked down" % species
	if not target.statuses.has_flag(&"knockdown"):
		return "could not knock a %s down in 120 s (hp %.0f%%)" % [species, 100.0 * target.health.health / maxf(1.0, target.health.max_health)]
	_event("knockdown", species)
	var bonded := player.bonded.size()
	var feeds := 0
	var feed_deadline := _t + 50.0
	while _t < feed_deadline and player.bonded.size() <= bonded:
		var food := FieldTame.food_in_bag(player.inventory, target)
		if food == &"":
			return "ran out of food %d feeds into the %s" % [feeds, species]
		if FieldTame.apply_feed(player, target, food):
			feeds += 1
		if not await _beat(FieldTame.FEED_SECONDS + 0.2):
			break
	if player.bonded.size() > bonded:
		_event("tame", "%s bonded after %d feeds" % [species, feeds])
		return ""
	return "fed a %s %d times and it never bonded" % [species, feeds]

func _travel() -> String:
	_goal = "travel"
	var before := World.island_id
	World.travel(&"savannah_15", &"sail")
	await _beat(2.0)
	if World.island_id == before:
		return "travel to savannah_15 refused (level, cost or harbour)"
	_event("travel", "%s -> %s" % [before, World.island_id])
	return ""

## Gather what the unstable island offers that home does not.
func _forage() -> String:
	_goal = "forage"
	if World.is_home():
		return "still on the home island"
	var wanted: Array[StringName] = [&"stone", &"branch", &"fibre_stalk", &"berries"]
	var got := 0
	for item in wanted:
		if _t >= minutes * 60.0:
			break
		var before := player.inventory.count_of(item)
		await _gather(item, 3)
		got += player.inventory.count_of(item) - before
	if got <= 0:
		return "gathered nothing on %s" % World.island_id
	_event("forage", "%d units off %s" % [got, World.island_id])
	return ""

func _return_home() -> String:
	_goal = "return_home"
	if World.is_home():
		return ""
	var before := World.island_id
	World.travel(&"home_grassland", &"harbour_home")
	await _beat(2.0)
	if not World.is_home():
		return "could not get home from %s" % before
	_event("return", "%s -> home" % before)
	return ""

## Play out the rest of the session the way a session actually goes: gather, craft, repeat.
## This is what measures whether the loop sustains, rather than whether it starts.
func _grind() -> String:
	_goal = "grind"
	var cycles := 0
	var start_xp := World.pioneer_xp
	var start_level := World.pioneer_level
	while _t < minutes * 60.0 - 5.0:
		for item in [&"fibre_stalk", &"branch", &"stone", &"berries"]:
			if _t >= minutes * 60.0 - 5.0:
				break
			await _gather(item, 4)
		for rid in [&"twine", &"rope", &"charcoal", &"plank"]:
			var rec := Crafting.recipe(rid)
			if rec.is_empty():
				continue
			if await _acquire_for(rec) == "":
				await _craft(rec)
		cycles += 1
		if cycles > 20:
			break
	_event("grind", "%d cycles, level %d -> %d, xp +%d" % [cycles, start_level, World.pioneer_level, World.pioneer_xp - start_xp])
	return ""

# ---------------------------------------------------------------- housekeeping

## One time slice. Returns false when the run is over.
func _beat(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	_t += seconds
	if player and is_instance_valid(player) and player.dead:
		_deaths += 1
		_event("death", "died during %s (deaths=%d)" % [_goal, _deaths])
		player.respawn()
		await get_tree().create_timer(1.0).timeout
		_t += 1.0
	_busy_time[_goal] = float(_busy_time.get(_goal, 0.0)) + seconds
	if player and is_instance_valid(player):
		_walked += _last_pos.distance_to(player.global_position)
		_last_pos = player.global_position
		_hp_low = minf(_hp_low, player.vitals.health)
	if _t >= _next_sample:
		_next_sample = _t + 15.0
		if player and player.skills:
			_xp_curve.append({"t": _t, "lvl": World.pioneer_level, "bag": player.inventory.used_slots(),
				"hp": player.vitals.health, "energy": player.vitals.energy,
				"exhaustion": player.vitals.fatigue})
	if shot_dir != "" and _t >= _next_shot:
		_next_shot = _t + 10.0
		_shot()
	return _t < minutes * 60.0

func _shot() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.get_width() < 8:
		return
	img.save_png("%s/%03d_%s.png" % [shot_dir, _shot_n, _goal.replace(":", "_")])
	_shot_n += 1

func _event(kind: String, detail: String) -> void:
	_events.append({"t": _t, "kind": kind, "detail": detail})
	print("[bot] t=%6.1f %-14s %s" % [_t, kind, detail])

## What the island actually offers a new survivor, before the bot touches anything.
func _survey() -> void:
	var families := {}
	var items := {}
	for node in get_tree().get_nodes_in_group("harvest"):
		var hn := node as HarvestNode
		if hn == null:
			continue
		var d := player.global_position.distance_to(hn.global_position)
		families[hn.family] = int(families.get(hn.family, 0)) + 1
		for o in hn.options():
			var it := str((o as Dictionary).get("item", ""))
			var row: Dictionary = items.get(it, {"n": 0, "near": INF})
			row["n"] = int(row["n"]) + 1
			row["near"] = minf(float(row["near"]), d)
			items[it] = row
	var creatures := {}
	for node in get_tree().get_nodes_in_group("creatures"):
		var c := node as Creature
		if c and c.def:
			creatures[str(c.def.id)] = int(creatures.get(str(c.def.id), 0)) + 1
	print("[bot] survey nodes=%d families=%d creatures=%s" % [get_tree().get_nodes_in_group("harvest").size(), families.size(), creatures])
	var line: Array[String] = []
	for it in items:
		line.append("%s x%d @%.0fm" % [it, int((items[it] as Dictionary)["n"]), float((items[it] as Dictionary)["near"])])
	line.sort()
	print("[bot] survey yields %s" % ", ".join(PackedStringArray(line)))

func _report() -> void:
	print("[bot] ---------------- report ----------------")
	var ok := 0
	for r in _rungs:
		if str(r["outcome"]) == "OK":
			ok += 1
	print("[bot] rungs %d/%d reached in %.0f s, walked %.0f m, deaths=%d, lowest hp=%.0f" % [ok, _rungs.size(), _t, _walked, _deaths, _hp_low])
	for r in _rungs:
		print("[bot]   %-8s %-8s t=%6.1f  %s" % [r["goal"], r["outcome"], r["t"], r["detail"]])
	print("[bot] time by activity:")
	var keys: Array = _busy_time.keys()
	keys.sort_custom(func (a, b) -> bool: return float(_busy_time[a]) > float(_busy_time[b]))
	for k in keys:
		var secs: float = _busy_time[k]
		if secs >= 1.0:
			print("[bot]   %-22s %5.1f s  %4.1f%%" % [k, secs, 100.0 * secs / maxf(1.0, _t)])
	print("[bot] vitals / progress samples:")
	for s in _xp_curve:
		print("[bot]   t=%5.0f lvl=%d bag=%d hp=%.0f energy=%.0f exhaustion=%.0f" % [
			s["t"], s["lvl"], s["bag"], s["hp"], s["energy"], s["exhaustion"]])
	print("[bot] events=%d shots=%d" % [_events.size(), _shot_n])
	print("[bot] PASS" if ok > 0 else "[bot] FAIL no rung reached")
