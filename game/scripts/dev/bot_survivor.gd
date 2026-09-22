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
	{"goal": "fire", "craft": "bonfire_kit", "then": "build"},
	{"goal": "hunt", "then": "hunt"},
	{"goal": "cook", "then": "cook"},
	{"goal": "net", "craft": "capture_net_i"},
	{"goal": "tame", "then": "tame"},
	{"goal": "travel", "then": "travel"},
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
	if station != "" and Crafting.nearest_station(player, StringName(station)) == null:
		_event("craft-blocked", "%s needs a %s and none is built" % [rid, station])
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
	match kind:
		"build":
			return await _build_bonfire()
		"hunt":
			return await _hunt()
		"cook":
			return await _cook()
		"tame":
			return await _tame()
		"travel":
			return await _travel()
	return ""

func _build_bonfire() -> String:
	_goal = "build"
	var placer = player.placer
	if placer == null:
		return "player has no build placer"
	placer.begin(&"bonfire")
	await _beat(0.5)
	if placer.placing == &"":
		return "build placer refused bonfire (cost or unlock)"
	var ok: bool = placer.confirm(player)
	await _beat(0.5)
	if not ok:
		placer.cancel()
		return "bonfire placement refused where the survivor stands"
	_event("build", "bonfire placed")
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
	var deadline := _t + 70.0
	while _t < deadline and target and is_instance_valid(target) and not target.health.dead:
		if not await _beat(0.25):
			break
		if player.dead:
			return "the survivor died to a %s" % species
	if target and is_instance_valid(target) and not target.health.dead:
		return "could not kill a %s in 70 s (hp %.0f)" % [species, target.health.health]
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
	await _beat(1.5)
	if player.ui and player.ui.visible:
		player.ui.hide()
	_event("loot", "corpse opened, meat=%d" % meat)
	return ""

func _cook() -> String:
	_goal = "cook"
	var fire := player._nearest_group("bonfire")
	if fire == null:
		return "no bonfire exists to cook at"
	player.nav_to(fire.global_position)
	var deadline := _t + 25.0
	while _t < deadline and player.global_position.distance_to(fire.global_position) > 2.5:
		if not await _beat(0.25):
			break
	var acts: Array = []
	for a in player.context_actions():
		acts.append(str(a["id"]))
	if not acts.has("cook"):
		return "standing at the bonfire offers no cook action (%s)" % [acts]
	_event("cook", "cook action available at the bonfire")
	return ""

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
		return "no tameable creature on the home island"
	_event("tame-start", str(target.def.id))
	player.hunt.start(target)
	var deadline := _t + 60.0
	while _t < deadline and is_instance_valid(target) and not target.statuses.has_flag(&"knockdown"):
		if not await _beat(0.25):
			break
		if target.health.dead:
			return "the %s died before it could be knocked down" % target.def.id
	if not is_instance_valid(target) or not target.statuses.has_flag(&"knockdown"):
		return "could not knock a %s down in 60 s" % target.def.id
	_event("knockdown", str(target.def.id))
	return ""

func _travel() -> String:
	_goal = "travel"
	var before := World.island_id
	World.travel(&"savannah_15", &"sail")
	await _beat(2.0)
	if World.island_id == before:
		return "travel to savannah_15 refused (level, cost or harbour)"
	_event("travel", "%s -> %s" % [before, World.island_id])
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
				"hunger": player.vitals.hunger, "thirst": player.vitals.thirst})
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
		print("[bot]   t=%5.0f lvl=%d bag=%d hp=%.0f energy=%.0f hunger=%.0f thirst=%.0f" % [
			s["t"], s["lvl"], s["bag"], s["hp"], s["energy"], s["hunger"], s["thirst"]])
	print("[bot] events=%d shots=%d" % [_events.size(), _shot_n])
	print("[bot] PASS" if ok > 0 else "[bot] FAIL no rung reached")
