extends SceneTree
## W1-SAVE: crash-safe, sanitized, isolated saves. Prints "[t_save] PASS" (or FAIL lines), exits 0/1.
##   Godot --headless --path game --script res://tests/t_save.gd
## `-- --write-golden` re-stages a camp and rewrites the instance-format goldens (GOLDEN, AWAY_GOLDEN).
## Never rewrite save_v3_golden.json, save_v3_away_golden.json or save_truncated.json: they are the
## base's stacked saves from before W2-INV with W2-SKILLS' rev-1 skills, kept byte for byte as the
## real old saves both migrations must load; a rewritten one fails the run.
## Scripts that touch autoloads load on the first frame (see run_all.gd), so everything is load()ed.

const FIX := "res://tests/fixtures/"
## W2-INV: the current format (one instance per row, worn gear under inventory_extras.worn).
const GOLDEN := "save_v3_inst_golden.json"
const AWAY_GOLDEN := "save_v3_inst_away_golden.json"
## Stacked saves from before W2-INV; their round trip checks the split instead of byte equality.
const STACKED := ["save_v3_golden.json", "save_v3_away_golden.json"]
const RUN_DIR := "user://runs/t_save"
## Island state regenerated on load, not save format: excluded from field-for-field compares.
## A snare's life_left loses the 0-1 s of offline time each load counts.
const IGNORE := ["/saved_unix", "/unstable/harvested", "/ground_snares/0/life_left"]
## What each legacy fixture must still hold after its first load + save (not just idempotence):
## [building kinds, {item id: count} in the player's bag, t_stones, island_id].
const LEGACY := {
	"save_v0.json": [["basket"], {}, 20, "home_grassland"],
	"save_v1.json": [["basket"], {"stone": 3, "branch": 2}, 25, "home_grassland"],
	"save_v2.json": [[], {}, 20, "home_grassland"],
}

## Counts SCRIPT ERRORs so the run asserts "none unexpected" itself instead of relying on the log.
class ErrorCounter extends Logger:
	var script_errors := 0
	var engine_errors := 0
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			script_errors += 1
		elif error_type == ERROR_TYPE_ERROR:
			engine_errors += 1
	func _log_message(_message: String, _error: bool) -> void:
		pass

var errors := ErrorCounter.new()
var expected_script_errors := 0
var failures: Array[String] = []
var _started := false
var W: Node
var SG: GDScript
var SR: GDScript
var PetRecordS: GDScript
var IS: GDScript
var host: Node3D
var player: Node

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	OS.add_logger(errors)
	_run.call_deferred()
	return false

func _run() -> void:
	W = root.get_node("World")
	SG = load("res://scripts/core/save_game.gd")
	SR = load("res://scripts/core/save_restore.gd")
	PetRecordS = load("res://scripts/pets/pet_record.gd")
	IS = load("res://scripts/items/item_stack.gd")
	_check(str(SG.path) == RUN_DIR + "/save_1.json", "a --script run saves under user://runs/t_save/ (got %s)" % SG.path)
	_test_run_names()
	_test_fresh_run_dir()
	_test_offline_clamp()
	_clean()
	host = Node3D.new()
	host.name = "SaveHost"
	root.add_child(host)
	player = (load("res://scripts/dev/lab_kit.gd") as GDScript).build(host)["player"]
	W.home_terrain = &"meadow"
	W.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)
	await process_frame
	if "--write-golden" in OS.get_cmdline_user_args():
		await _write_golden()
		quit(0)
		return
	_test_two_saves()
	for name in ["save_v0.json", "save_v1.json", "save_v2.json", "save_v3_golden.json", "save_v3_away_golden.json", GOLDEN, AWAY_GOLDEN]:
		await _test_round_trip(name)
	await _test_rev1_skills()
	await _test_forged()
	await _test_stacked_migration()
	await _test_duplicate_uids_across_containers()
	await _test_truncated()
	await _test_future()
	await _test_backup_fallback()
	await _test_restore_refunds()
	await _test_full_cargo_refund()
	await _test_oversized_legacy_refund()
	await _test_pen_refunds()
	await _test_refused_save_keeps_camp()
	await _test_away_island()
	await _test_hostile_types()
	_test_gate_open_direct()
	await _test_aborted_load()
	await _test_sanitizer_abort()
	_test_skill_purchases()
	_finish()

func _test_run_names() -> void:
	var cases := [
		[["--lab=build_lab"], [], "build_lab"],
		[["--smoke"], [], "smoke"],
		[["--raid-gear-probe"], [], "raid-gear-probe"],
		[["--bot"], [], "bot"],
		[[], ["--headless", "--script", "res://tests/run_all.gd"], "run_all"],
		[["--occupation=soldier"], ["--path", "game"], ""],
		[["--lab=../../evil"], [], "______evil"],
		[["--lab=.."], [], "__"],
		[["--shot=/tmp/a.png", "--shot-delay=4"], [], "shot"],
		[["--lab=build_lab", "--shot=/tmp/a.png"], [], "build_lab"],
	]
	for c in cases:
		var got: String = SG.run_name(PackedStringArray(c[0]), PackedStringArray(c[1]))
		_check(got == c[2], "run_name(%s, %s) == '%s' (got '%s')" % [c[0], c[1], c[2], got])

## Every automated launch starts fresh: a .bak a previous run left must not be resumed (the bot
## used to load runs/bot/save_1.json.bak after its main file was deleted).
func _test_fresh_run_dir() -> void:
	_clean()
	for f in [SG.path + ".bak", SG.path + ".tmp", SG.path]:
		var fa := FileAccess.open(f, FileAccess.WRITE)
		fa.store_string("{}")
		fa.close()
	var again: String = SG._pick_path()
	_check(again == RUN_DIR + "/save_1.json" and not SG.exists(), "picking the run path wipes a leftover save, .bak and .tmp (exists=%s)" % SG.exists())
	var e0 := errors.engine_errors
	(load("res://scripts/core/save_migrations.gd") as GDScript).wipe_dir("user://runs/t_save_never_made")
	_check(errors.engine_errors == e0, "a new run name's first launch logs no engine ERROR (got %d)" % (errors.engine_errors - e0))

func _test_offline_clamp() -> void:
	var now := int(Time.get_unix_time_from_system())
	_check(SG.offline_seconds(0) == 7 * 24 * 3600, "saved_unix=0 clamps offline catch-up to 7 days (got %d)" % SG.offline_seconds(0))
	_check(SG.offline_seconds(now + 3600) == 0, "a save from the future gives no catch-up")
	_check(absi(SG.offline_seconds(now - 120) - 120) <= 1, "a 2-minute break is not clamped")

func _test_two_saves() -> void:
	_clean()
	_check(SG.save_now(), "first save writes")
	var first := FileAccess.get_file_as_string(SG.path)
	W.t_stones += 1
	_check(SG.save_now(), "second save writes")
	W.t_stones -= 1
	_check(FileAccess.get_file_as_string(SG.path + ".bak") == first, ".bak holds the first save")
	_check(not FileAccess.file_exists(SG.path + ".tmp"), "no .tmp remains after two saves")

## Load a fixture, re-save, load that, re-save: both saves must match field for field.
func _test_round_trip(name: String) -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + name))
	SG.load_now(host)
	_check(SG.blocked_reason == "", "%s loads" % name)
	SG.save_now()
	var s1 := _saved()
	SG.load_now(host)
	SG.save_now()
	var s2 := _saved()
	var diffs: Array[String] = []
	_same(s1, s2, "", diffs)
	_same(s2, s1, "", diffs)
	_check(diffs.is_empty(), "%s re-saves field-for-field equal: %s" % [name, diffs.slice(0, 6)])
	if LEGACY.has(name):
		_check_legacy(name, s1)
	if name in STACKED:
		_check_v3_skills(name, s1)
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + name))
		var away := str(s1.get("island_id", "")) != "home_grassland"
		_check_split(name, old, s1, away)
		if away:
			# The home camp's contents wait as saved rows while the survivor is away; they split
			# when the camp is rebuilt on the way home (World.travel's two steps).
			W.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)
			SG._restore_buildings(W._home_buildings_cache, SaveMigrations.CURRENT_SCHEMA)
			await process_frame
			SG.save_now()
			var home_old := old.duplicate(true)
			home_old.erase("away") # what was built on the island left behind stays there
			_check_split(name + " back home", home_old, _saved())
	elif name.begins_with("save_v3_"):
		var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + name))
		_pad_contents(golden, s1)
		var gd: Array[String] = []
		# y is re-seated on the terrain at load; the schema marker moves on to the current one.
		_same(golden, s1, "", gd, ["/player/position/1", "/schema", "/pioneer_level", "/pioneer_xp"])
		_check(gd.is_empty(), "v3 golden survives load + save unchanged: %s" % [gd.slice(0, 6)])
		_check_xp_curve(name, golden, s1)
		_check(int(s1.get("schema", -1)) == int(SG.SCHEMA), "%s re-saves at the current schema" % name)
	print("[t_save] round trip %s fields=%d diffs=%d" % [name, s1.size(), diffs.size()])
	await process_frame

## Baskets grew from 60 to 100 slots (spec 05:14): a golden row list gets the empty tail a re-save
## writes, so every saved row is still compared slot for slot.
func _pad_contents(golden: Dictionary, s1: Dictionary) -> void:
	for side in ["home", "away"]:
		var g: Variant = golden.get(side)
		var s: Variant = s1.get(side)
		if not (g is Dictionary and s is Dictionary):
			continue
		var gb: Array = g.get("buildings", [])
		var sb: Array = s.get("buildings", [])
		for i in mini(gb.size(), sb.size()):
			var gc: Variant = gb[i].get("contents") if gb[i] is Dictionary else null
			var sc: Variant = sb[i].get("contents") if sb[i] is Dictionary else null
			if gc is Array and sc is Array and (gc as Array).size() < (sc as Array).size():
				(gc as Array).resize((sc as Array).size())  # the new slots are empty (null)

## The stacked v3 goldens are frozen rev-1 saves: never regenerate them, they are the migration's
## input. skills_v2 must equal the rev-2 result kept in save_v3_skills_rev2.json, field for field both
## ways; their stacks split on load (W2-INV), so _check_split checks the item containers and
## everything else must survive load + save unchanged.
## LEVELBAR: a save from before the exponential curve keeps its total XP, the level recomputed
## (floored at the stored one), and re-saves marked xp_curve 2 so the next load leaves it alone.
func _check_xp_curve(name: String, golden: Dictionary, s1: Dictionary) -> void:
	var want: Vector2i = W.migrate_linear_xp(int(golden.get("pioneer_level", 0)), int(golden.get("pioneer_xp", 0)))
	_check(int(s1.get("pioneer_level", -1)) == want.x and int(s1.get("pioneer_xp", -1)) == want.y and int(s1.get("xp_curve", 0)) == 2,
		"%s pioneer XP moves to the exponential curve: %s (got Lv %s xp %s curve %s)" % [name, want, s1.get("pioneer_level"), s1.get("pioneer_xp"), s1.get("xp_curve")])

func _check_v3_skills(name: String, s1: Dictionary) -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + name))
	_check(not (golden["skills_v2"] as Dictionary).has("rev"), "%s is still a rev-1 save (the migration input)" % name)
	var skip: Array = ["/skills_v2", "/player/position/1", "/player/inventory", "/player/inventory_extras", "/home/cargo", "/schema", "/pioneer_level", "/pioneer_xp"]
	_check_xp_curve(name, golden, s1)
	_check(int(s1.get("schema", -1)) == int(SG.SCHEMA), "%s re-saves at the current schema" % name)
	for side in ["home", "away"]:
		var part: Variant = golden.get(side)
		if part is Dictionary:
			for i in (part.get("buildings", []) as Array).size():
				skip.append("/%s/buildings/%d/contents" % [side, i])
	for i in (golden.get("pets", []) as Array).size():
		skip.append("/pets/%d/bag" % i)
	var gd: Array[String] = []
	_same(golden, s1, "", gd, skip) # y is re-seated on the terrain at load
	_check(gd.is_empty(), "%s: everything but item containers and skills_v2 survives load + save unchanged: %s" % [name, gd.slice(0, 6)])
	var want: Variant = (JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v3_skills_rev2.json")) as Dictionary).get(name)
	var sd: Array[String] = []
	_same(want, s1.get("skills_v2"), "/skills_v2", sd)
	_same(s1.get("skills_v2"), want, "/skills_v2", sd)
	_check(want is Dictionary and sd.is_empty(), "%s skills_v2 migrates to its rev-2 expectation: %s" % [name, sd.slice(0, 6)])

## W2-SKILLS migration end to end (SaveSanitizer, then SkillState): the rev-1 golden with nodes
## bought under the old per-tree award (old graph and prices, Survival 55) loads as rev 2 keeping
## every level, every node and every unspent SP, learns its Lv1 AUTO nodes, and stays so on a re-load.
func _test_rev1_skills() -> void:
	_clean()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v3_golden.json"))
	var sv: Dictionary = d["skills_v2"]
	var bought := {
		"survival": ["island_access_15", "belly_fat_1", "capture_technique_1", "capture_tool_1", "stealth_1", "island_access_25", "capture_technique_2", "climate_body_1", "island_access_35", "capture_technique_3", "animal_management_1", "island_access_45", "capture_technique_4", "animal_management_2"],
		"gathering": ["forage_1", "thickets", "mining_1", "herbs_1", "insects"], # forage_1 cost 5 then, AUTO now
	}
	sv["trees"]["survival"]["level"] = 55
	for tree in bought:
		sv["trees"][tree]["unlocked"] = bought[tree].duplicate()
	# Old award for gathering 20 + butchering 3 + survival 55 = 880 SP; these nodes cost 341 at rev-1 prices.
	sv["sp_spent"] = 341
	sv["sp_available"] = 880 - 341
	var old_levels := {}
	for tree in sv["trees"]:
		old_levels[tree] = int(sv["trees"][tree]["level"])
	_put(JSON.stringify(d))
	SG.load_now(host)
	var Rules: GDScript = load("res://scripts/skills/skill_rules.gd")
	for pass_name in ["first load", "re-load"]:
		var sk: Node = player.skills
		var levels_ok := true
		for tree in old_levels:
			levels_ok = levels_ok and sk.level_of(tree) == maxi(1, old_levels[tree])
		_check(levels_ok and sk.to_dict().get("rev") == 2, "%s: rev-1 levels kept, 0 reads Lv. 1, saved as rev 2" % pass_name)
		var autos := ["processing/cordage", "defense/roll", "farming/corn", "tailoring/leaf_outfit", "gathering/branch", "butchering/butcher_1"]
		_check(autos.all(func (a: String) -> bool: return sk.is_unlocked(a.get_slice("/", 0), a.get_slice("/", 1))), "%s: Lv1 AUTO nodes learned" % pass_name)
		var missing: Array = []
		for tree in bought:
			for nid in bought[tree]:
				if not sk.is_unlocked(tree, nid):
					missing.append(nid)
		_check(missing.is_empty(), "%s: every node bought under rev 1 is kept (missing %s)" % [pass_name, missing])
		var paid: int = Rules.paid_for_level(sk, 5) # pioneer_level 4 = character Lv. 5
		_check(sk.sp_available == 880 - 341, "%s: the 539 unspent SP are kept (got %d)" % [pass_name, sk.sp_available])
		_check(sk.sp_spent == 263 and sk.sp_extra == 539 + 263 - paid and sk.sp_earned == paid + sk.sp_extra, "%s: budget = character Lv. 5 (%d) + one-time extra %d, spent 263 at today's prices (earned %d, spent %d)" % [pass_name, paid, sk.sp_extra, sk.sp_earned, sk.sp_spent])
		_check(Rules.bonded_capacity(sk) == 5, "%s: Animal Handling I + II give 5 bonded slots (got %d)" % [pass_name, Rules.bonded_capacity(sk)])
		SG.save_now()
		SG.load_now(host)
	print("[t_save] rev-1 skills migrate: %d nodes kept, SP %d/%d" % [bought["survival"].size() + bought["gathering"].size(), player.skills.sp_available, player.skills.sp_earned])
	await process_frame

func _check_legacy(name: String, s1: Dictionary) -> void:
	var want: Array = LEGACY[name]
	var kinds: Array = []
	for b in s1.get("home", {}).get("buildings", []):
		kinds.append(str(b.get("kind", "")))
	var bag := {}
	for st in s1.get("player", {}).get("inventory", []):
		if st is Dictionary:
			bag[str(st["id"])] = int(bag.get(str(st["id"]), 0)) + int(st.get("count", 1))
	var ok: bool = kinds == want[0] and bag == want[1] and int(s1.get("t_stones", -1)) == want[2] and str(s1.get("island_id", "")) == want[3]
	_check(ok, "%s content survives migration: buildings=%s bag=%s t_stones=%s island=%s" % [name, kinds, bag, s1.get("t_stones"), s1.get("island_id")])
	print("[t_save] legacy %s buildings=%s bag=%s t_stones=%s island=%s" % [name, kinds, bag, s1.get("t_stones"), s1.get("island_id")])

## W2-INV: an old stacked save keeps every unit (per item id), each non-stacking unit in its own
## row with a distinct uid, and its def-id worn gear becomes a worn instance.
func _check_split(name: String, old: Dictionary, s1: Dictionary, skip_home_camp: bool = false) -> void:
	var want := _units(old)
	var got := _units(s1)
	var st := _instance_stats(s1, skip_home_camp)
	var worn: Dictionary = s1["player"]["inventory_extras"].get("worn", {})
	_check(got == want, "%s: no unit is lost splitting stacks: %s vs %s" % [name, got, want])
	_check(st[0] == 0 and st[1] == st[2] and st[2] > 0 and not st[3], "%s: every non-stacking unit is its own row with a distinct uid (rows=%d uids=%d multi=%d)" % [name, st[2], st[1], st[0]])
	_check(str(worn.get("head", {}).get("id", "")) == "raid_helm" and not s1["player"]["inventory_extras"].has("equipment"), "%s: def-id head=raid_helm became a worn instance" % name)
	print("[t_save] stacked %s units=%s instances=%d" % [name, got, st[2]])

## [non-stacking rows with count != 1, distinct uids, such rows, a row without a uid].
func _instance_stats(d: Dictionary, skip_home_camp: bool = false) -> Array:
	var uids := {}
	var multi := 0
	var rows := 0
	for row in _rows(d, skip_home_camp):
		var def = root.get_node("Data").item(StringName(str(row.get("id", ""))))
		if def and def.stack_max == 1:
			rows += 1
			multi += 1 if int(row.get("count", 1)) != 1 else 0
			uids[str(row.get("uid", ""))] = true
	return [multi, uids.size(), rows, uids.has("")]

## The base's stacked golden with its empty bag rows filled with legal old stacks (stone x20, the
## old stack_max): more units than the 100-slot bag. The bag fills, the rest lands in home cargo,
## and the migrated save re-saves unchanged.
func _test_stacked_migration() -> void:
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v3_golden.json"))
	var rows: Array = src["player"]["inventory"]
	for i in rows.size():
		if rows[i] == null:
			rows[i] = {"id": "stone", "count": 20}
	var want := _units(src)
	_clean()
	_put(JSON.stringify(src))
	SG.load_now(host)
	_check(SG.blocked_reason == "", "the full stacked save loads")
	SG.save_now()
	var s1 := _saved()
	_check_split("full stacked save", src, s1)
	var bag_used := 0
	for row in s1["player"]["inventory"]:
		bag_used += 1 if row is Dictionary else 0
	var cargo_stone := 0
	for row in s1["home"]["cargo"]:
		if row is Dictionary and str(row.get("id")) == "stone":
			cargo_stone += int(row.get("count", 1))
	# 99: the bag filled to 100, then the legacy head=raid_helm moved out of it into its slot.
	_check(bag_used == 99 and (s1["player"]["inventory"] as Array).size() == 100 and cargo_stone > 0, "the bag fills to 100 and the rest goes to home cargo (bag=%d cargo stone=%d of %d)" % [bag_used, cargo_stone, want.get("stone", 0)])
	SG.load_now(host)
	SG.save_now()
	var diffs: Array[String] = []
	_same(s1, _saved(), "", diffs)
	_check(diffs.is_empty(), "the migrated save re-saves unchanged: %s" % [diffs.slice(0, 4)])
	print("[t_save] stacked migration units=%s bag=%d cargo_stone=%d" % [_units(s1), bag_used, cargo_stone])

## W2-INV review 2 (spec 05:20/26): an edited save whose bag, basket and pet bag rows share one uid
## loads as three instances: the bag keeps the uid, the basket and pet copies are reminted.
func _test_duplicate_uids_across_containers() -> void:
	const U := "laaaa0001"
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + GOLDEN))
	var holders: Array = [src.player.inventory, src.pets[0].bag]
	for b in src.home.buildings:
		if str(b.kind) == "basket":
			holders.append(b.contents)
	for rows in holders:
		for row in rows:
			if row is Dictionary and str(row.id) == "stone":
				row["uid"] = U
				break
	_clean()
	_put(JSON.stringify(src))
	SG.load_now(host)
	SG.save_now()
	var s1 := _saved()
	var seen := {}
	var dup := 0
	for row in _rows(s1):
		var u := str(row.get("uid", ""))
		dup += 1 if u != "" and seen.has(u) else 0
		seen[u] = true
	var bag_keeps := (s1.player.inventory as Array).any(func (r: Variant) -> bool: return r is Dictionary and str(r.get("uid", "")) == U)
	_check(dup == 0 and bag_keeps, "a uid shared by bag, basket and pet bag rows loads as distinct instances, the bag keeps it (dup %d, bag keeps %s)" % [dup, bag_keeps])

## Every item row in a save: bag, worn gear, home cargo, building contents, pet bags.
func _rows(d: Dictionary, skip_home_camp: bool = false) -> Array:
	var out: Array = []
	out.append_array(d.get("player", {}).get("inventory", []))
	var extras: Dictionary = d.get("player", {}).get("inventory_extras", {})
	out.append_array((extras.get("worn", {}) as Dictionary).values())
	out.append_array(d.get("home", {}).get("cargo", []))
	for b in ([] if skip_home_camp else d.get("home", {}).get("buildings", [])) + d.get("away", {}).get("buildings", []):
		if b.get("contents") is Array:
			out.append_array(b.contents)
	for p in d.get("pets", []):
		if p.get("bag") is Array:
			out.append_array(p.bag)
	return out.filter(func (r: Variant) -> bool: return r is Dictionary)

func _units(d: Dictionary) -> Dictionary:
	var n := {}
	for row in _rows(d):
		n[str(row["id"])] = int(n.get(str(row["id"]), 0)) + int(row.get("count", 1))
	return n

func _test_forged() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + "save_forged.json"))
	SG.load_now(host)
	var inv = player.inventory
	var helm = inv.equipped_in(&"head") # the forged head=raid_helm wears it (W2-INV: worn gear leaves the bag)
	_check(helm != null and helm.count == 1 and helm.level == 60, "forged raid_helm x5000 L9999 loads as x1 L60")
	_check(helm != null and helm.durability <= helm.max_durability and helm.max_durability == IS.make(&"raid_helm", 1, {}, 60).max_durability, "forged durability clamps to the item's ceiling")
	var unknown := 0
	var negative := 0
	for s in inv.slots:
		if s != null and str(s.def_id) != "_slot_lock" and s.def() == null:
			unknown += 1
		if s != null and s.count < 1:
			negative += 1
	_check(unknown == 0 and inv.count_of(&"stone") == 0 and negative == 0, "unknown and negative stacks are dropped")
	_check(inv.count_of(&"branch") <= 999, "a branch x1000000 stack clamps to its stack size")
	_check(str(inv.equipment.get("chest", "")) == "", "equipment naming an unknown item is dropped")
	_check(int(W.t_stones) == 0, "t_stones -5 loads as 0 (got %d)" % W.t_stones)
	var top := 0
	for id in player.skills.trees:
		top = maxi(top, int(player.skills.trees[id]["level"]))
	_check(top <= 60, "skill 99 clamps to <= 60 (got %d)" % top)
	_check(player.skills.sp_available < 99999 and player.skills.sp_spent >= 0, "forged SP clamps to what the levels paid (sp=%d)" % player.skills.sp_available)
	_check(absf(player.global_position.x) < 0.01 and absf(player.global_position.z - 12.0) < 0.01, "empty position loads at the default spawn")
	_check(player.bonded.size() == 1 and player.bonded[0].level <= 60, "unknown pet species dropped, pet level clamps")
	var giant: Array = W.home_claims.filter(func (r: Array) -> bool: return r[2] > 14 or r[3] > 14)
	_check(giant.is_empty() and W.home_claims.size() == 1, "a forged 2000x2000 home claim is dropped, a 14x14 one kept (got %s)" % [W.home_claims])
	var cuirass: int = W.cargo_home.find_first(&"raid_cuirass")
	_check(cuirass >= 0 and W.cargo_home.slots[cuirass].count == 1, "cargo raid_cuirass x3000 loads as x1")
	var bought: Array = player.skills.trees["survival"]["unlocked"]
	# Stealth I is a Survival Lv. 10 node with no prerequisite since W2-SKILLS (spec 12), so it is reachable too.
	_check(bought == ["island_access_15", "stealth_1"] and player.skills.sp_spent == 5 + 2, "survival L10 listing every node keeps only island_access_15 and stealth_1, sp_spent 7 (got %s, %d)" % [bought, player.skills.sp_spent])
	var d = root.get_node("Data")
	_check(not d.is_survival_unlocked(&"capture_technique_I") and not d.survival_unlocked.has(&"made_up_node"), "legacy skills true without a bought tree node, or an unknown id, unlock nothing")
	await process_frame

func _test_truncated() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + "save_truncated.json"))
	var sha0 := FileAccess.get_sha256(SG.path)
	SG.load_now(host)
	var cc := host.get_node_or_null("CharacterCreation")
	var note: Label = cc.find_child("SaveWarning", true, false) if cc else null
	_check(note != null, "truncated save opens character creation with a warning")
	if note:
		var column := note.get_parent()
		_check(column is VBoxContainer and note.get_index() == 2, "the warning sits in the layout column under the subtitle, not over the bottom row (parent=%s index=%d)" % [column.get_class(), note.get_index()])
	_check(FileAccess.get_sha256(SG.path) == sha0, "truncated save: sha256 of the original unchanged")
	var kept := _corrupt()
	_check(kept.size() == 1 and FileAccess.get_sha256(RUN_DIR.path_join(kept[0])) == sha0, "truncated save: a .corrupt-* copy holds its bytes (%s)" % [kept])
	_check(not SG.save_now(), "save_now() returns false before confirm_new_game()")
	_check(FileAccess.get_sha256(SG.path) == sha0, "refused save leaves the file alone")
	SG.confirm_new_game()
	_check(not SG.save_now(), "a new game still defers saving while character creation is open")
	W.finish_creation()  # the new survivor's island pick, which ends creation in the game
	_check(SG.save_now(), "save_now() works after confirm_new_game()")
	_check(_corrupt().size() == 1, "the .corrupt-* copy outlives the new game")
	if cc:
		cc.free()
	await process_frame

func _test_future() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + "save_future.json"))
	var sha0 := FileAccess.get_sha256(SG.path)
	SG.load_now(host)
	_check(SG.blocked_reason != "", "a newer-schema save blocks saving")
	for i in 70:
		W._process(1.0) # 70 s on World's autosave clock (it saves every 60 s)
	_check(FileAccess.get_sha256(SG.path) == sha0, "future-schema save: bytes unchanged after 70 s of autosave")
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	print("[t_save] future fixture after 70 s on_disk_schema=%s" % (on_disk as Dictionary).get("schema"))
	SG.confirm_new_game()
	W.finish_creation()
	var cc := host.get_node_or_null("CharacterCreation")
	if cc:
		cc.free()
	await process_frame

func _test_backup_fallback() -> void:
	_clean()
	W.t_stones = 37
	SG.save_now()
	W.t_stones = 38
	SG.save_now()
	_put(FileAccess.get_file_as_string(SG.path).left(200))
	W.t_stones = 0
	SG.load_now(host)
	_check(int(W.t_stones) == 37 and SG.blocked_reason == "", "a damaged save falls back to .bak and keeps saving on")
	_check(not FileAccess.file_exists(SG.path) and _corrupt().size() == 1, "the damaged file is moved aside as .corrupt-*")
	SG.save_now()
	var bak: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.path + ".bak"))
	_check(int(bak.get("t_stones", -1)) == 37, "the next save does not rotate damaged bytes into .bak")
	await process_frame

## Overlapping and unknown rows are refunded to camp cargo instead of stacking or becoming boxes.
func _test_restore_refunds() -> void:
	_clean()
	var cell := _free_cell(&"basket")
	SG.save_now()
	var d := _saved()
	var flint3: Dictionary = IS.make(&"flint", 3).to_dict()
	var flint2: Dictionary = IS.make(&"flint", 2).to_dict()
	var stone4: Dictionary = IS.make(&"stone", 4).to_dict()
	d["home"]["cargo"] = []
	d["home"]["buildings"] = [
		{"kind": "basket", "cell": [cell.x, cell.y], "rot": 0, "contents": [flint3]},
		{"kind": "basket", "cell": [cell.x, cell.y], "rot": 0, "contents": [flint2]},
		{"kind": "watchtower_of_doom", "cell": [cell.x + 4, cell.y], "rot": 0, "contents": [stone4]},
		{"kind": "basket", "cell": _camp_cell("CampFire"), "rot": 0}, # on the island's own camp fire
	]
	_put(JSON.stringify(d))
	SG.load_now(host)
	var baskets := _baskets()
	_check(baskets[0] == 1 and baskets[1] == 0, "an overlapping basket is not rebuilt (baskets=%d)" % baskets[0])
	var c = W.cargo_home
	_check(c.count_of(&"basket_kit") == 2 and c.count_of(&"flint") == 2 and c.count_of(&"stone") == 4,
		"refunds reach camp cargo (kit=%d flint=%d stone=%d)" % [c.count_of(&"basket_kit"), c.count_of(&"flint"), c.count_of(&"stone")])
	var boxes := 0
	for n in get_nodes_in_group("placed_building"):
		if str(n.get("kind")) == "watchtower_of_doom" and not n.is_queued_for_deletion():
			boxes += 1
	_check(boxes == 0, "an unknown kind is not rebuilt as a box")
	await process_frame

func _test_away_island() -> void:
	_clean()
	W.remaining_lifetime = 0.0
	W.load_island(host, &"temperate_25", Vector3(0, 1, 12), false)
	await process_frame
	var cell := _free_cell(&"basket")
	var b: Node3D = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	W.runtime.add_child(b)
	SR.place(b, {"kind": "basket", "cell": [cell.x, cell.y], "rot": 0}, W.runtime.get("build_grid"))
	b.storage.add(IS.make(&"stone", 9))
	_check(SG.save_now(), "save on an away island")
	SG.load_now(host)
	await process_frame
	var got := _baskets()
	print("[t_save] away island=%s is_home=%s placed_baskets=%d stone_in_baskets=%d" % [W.island_id, W.is_home(), got[0], got[1]])
	_check(str(W.island_id) == "temperate_25" and got[0] == 1 and got[1] == 9, "an away-island basket with 9 stone survives save and load")
	var fire: Array = _camp_cell("CampFire")
	var why: String = W.runtime.get("build_grid").can_place(&"basket", Vector2i(fire[0], fire[1]), 0)
	_check(why != "", "after an away load the camp fire's cells are still occupied (can_place='%s')" % why)
	W.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)
	await process_frame

## Wrong-typed leaves the loader casts with int()/float()/bool(): each must load completely
## (the golden's 42 t_stones and 6 stacks arrive) and keep saving, never abort halfway.
func _test_hostile_types() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + GOLDEN))
	SG.load_now(host) # the golden camp layout, so the pen cell below is free under it
	await process_frame
	var pen := _free_cell(&"makeshift_taming_pen")
	var cases := {
		"building rot {}": func (d: Dictionary) -> void: d["home"]["buildings"][0]["rot"] = {},
		"building hp/bool strings": func (d: Dictionary) -> void:
			d["home"]["buildings"][0]["sleeps_left"] = "x"
			d["home"]["buildings"][0]["cargo"] = "yes",
		"claims row with {}": func (d: Dictionary) -> void: d["home"]["claims"] = [[0, {}, 4, 4], [1, 2]],
		"vitals strings": func (d: Dictionary) -> void: d["player"]["vitals"] = {"health": "full", "energy": {}},
		"legacy skills {x: y}": func (d: Dictionary) -> void: d["skills"] = {"x": "y", "capture_technique_I": {}},
		"statuses/snares/layout junk": func (d: Dictionary) -> void:
			d["player"]["statuses"] = [{"id": "bleeding", "stacks": "lots", "time_left": []}, 7]
			d["ground_snares"] = [{"heavy": "y", "life_left": "z", "position": [0, 1, 12]}]
			d["home"]["camp_layout"] = {"CampFire": {"cell": [{}, 1], "rot": "r"}, "CampBench": {"rot": []}},
	}
	cases["stack process_count {}"] = func (d: Dictionary) -> void: d["player"]["inventory"][0]["process_count"] = {}
	cases["extras tool_index {}"] = func (d: Dictionary) -> void: d["player"]["inventory_extras"]["tool_index"] = {}
	cases["pet numbers and genetics junk"] = func (d: Dictionary) -> void:
		var pet: Dictionary = d["pets"][0]
		for key in ["hp", "attack", "defense", "speed", "xp", "hunger", "hunger_max", "xp_rate", "respawn_left", "level"]:
			pet[key] = {}
		pet["genetics"] = {"ivs": "x", "evs": {"hp": {}, "attack": "3"}, "level_gains": [], "extra": 1}
		pet["tamed_role"] = 5
		pet["bag"] = "no"
	cases["pet identity junk"] = func (d: Dictionary) -> void:
		var pet: Dictionary = d["pets"][0]
		pet["origin"] = "market_dupe"
		pet["uid"] = {"a": 1}
		pet["wild_level"] = 60
		pet["level"] = 3
		pet["name"] = "x".repeat(400)
		pet["tamed_at"] = 1e300
	cases["building gate open junk"] = func (d: Dictionary) -> void:
		d["home"]["buildings"] = [{"kind": "gate", "open": "true", "cell": [0, 12], "rot": 0}]
	# Pen occupants: [occupant row, whether the pen keeps an animal].
	var pens := {
		"pen occupant count {}": [{"id": "captured_animal", "count": {}, "attributes": {"species": "velociraptor"}}, false],
		"pen occupant unknown species": [{"id": "captured_animal", "count": 1, "attributes": {"species": {}, "grade_seed": {}}}, false],
		"pen occupant unknown id": [{"id": "dodo_egg_of_doom", "count": 1}, false],
		"pen occupant attribute junk": [{"id": "captured_animal", "count": 1, "level": "9", "attributes": {"species": "velociraptor", "grade_seed": {}, "variant": [], "genetics": {"ivs": "x", "evs": {"hp": {}, "attack": 3}, "level_gains": []}}}, true],
	}
	for label in pens:
		var row := _pen_row(pen, pens[label][0])
		cases[label] = func (d: Dictionary) -> void: d["home"]["buildings"] = [row]
	for label in cases:
		_clean()
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + GOLDEN))
		(cases[label] as Callable).call(d)
		_put(JSON.stringify(d))
		W.t_stones = 0
		player.inventory.load_array([])
		var errs := errors.script_errors # counted from before the load: a load-time abort is the bug
		SG.load_now(host)
		var stacks := 0
		for st in player.inventory.slots:
			if st != null: stacks += 1
		var ok: bool = SG.blocked_reason == "" and int(W.t_stones) == 42 and stacks == 25 and player.bonded.size() == 1 and not null in player.bonded
		var saved: bool = SG.save_now()
		_check(ok and saved and errors.script_errors == errs, "hostile '%s' loads completely and saves (blocked='%s' t_stones=%d stacks=%d pets=%d script_errors=%d)" % [label, SG.blocked_reason, W.t_stones, stacks, player.bonded.size(), errors.script_errors - errs])
		print("[t_save] hostile '%s' blocked='%s' t_stones=%d stacks=%d pets=%d saved=%s" % [label, SG.blocked_reason, W.t_stones, stacks, player.bonded.size(), saved])
		if pens.has(label):
			_check_pen(label, pens[label][1])
		if label == "pet identity junk":
			# from_dict sees one row only: the roster-level duplicate uid is the W2-INT validator's.
			var pet = player.bonded[0]
			print("[t_save] pet junk loads origin=%s uid_len=%d uid_ok=%s wild=%d lv=%d name_len=%d tamed_at=%d" % [
				pet.origin, pet.uid.length(), PetRecordS.UID_RE.search(pet.uid) != null, pet.wild_level, pet.level, pet.name.length(), pet.tamed_at])
			_check(str(pet.origin) == "tame" and PetRecordS.UID_RE.search(pet.uid) != null, "an unknown origin loads as tame and a junk uid is re-minted")
			_check(pet.wild_level <= pet.level and pet.name.length() <= PetRecordS.NAME_MAX, "wild_level <= level and name capped at %d (got %d / %d)" % [PetRecordS.NAME_MAX, pet.wild_level, pet.name.length()])
			_check(pet.tamed_at < int(Time.get_unix_time_from_system()) + 86401, "a forged tamed_at clamps")
			var nl_uid: String = PetRecordS.from_dict({"species": "velociraptor", "uid": "p_12\n"}).uid
			_check(nl_uid != "p_12\n" and PetRecordS.UID_RE.search(nl_uid) != null, "a pet uid with a trailing newline is re-minted (got %s)" % var_to_str(nl_uid))
		if label == "building gate open junk":
			var gates := 0
			for b in get_nodes_in_group("gate"):
				gates += 1
			_check(gates == 1 and SG.blocked_reason == "", "a gate with a string open flag still loads (gates=%d)" % gates)
		await process_frame

## SaveSanitizer coerces "open" before from_dict runs, so the case above cannot see from_dict raise.
## Call it directly: a wrong-typed flag loads as a closed gate, with no script error.
func _test_gate_open_direct() -> void:
	var PB: GDScript = load("res://scripts/world/placed_building.gd")
	for v in ["true", [], {}, 1, null, true]:
		var errs := errors.script_errors
		var b = PB.from_dict({"kind": "gate", "open": v})
		var open: bool = b.gate_open
		b.free()
		print("[t_save] gate open=%s (%s) -> gate_open=%s script_errors=%d" % [var_to_str(v), type_string(typeof(v)), open, errors.script_errors - errs])
		_check(errors.script_errors == errs and open == (v is bool and v), "from_dict with open=%s loads without a script error as %s" % [var_to_str(v), v is bool and v])

## The pen survives its junk occupant. A kept animal finishes taming without a script error; a
## dropped one leaves the pen idle (a running pen with no animal reads null when its timer ends).
func _check_pen(label: String, keeps: bool) -> void:
	var live := _live_pens()
	_check(live.size() == 1, "hostile '%s': the pen is rebuilt (pens=%d)" % [label, live.size()])
	if live.size() != 1:
		return
	var p = live[0]
	var errs := errors.script_errors
	var tamed: int = player.bonded.size()
	if p.occupant != null:
		p.force_result = 1
		p.running = true
		p.remaining = 0.0
		p._process(1.0)
	var done: bool = player.bonded.size() == tamed + 1 if keeps else p.occupant == null
	_check(done and not p.running and errors.script_errors == errs, "hostile '%s': keeps animal=%s, the pen finishes without a script error (tamed +%d, running=%s, script_errors=%d)" % [label, keeps, player.bonded.size() - tamed, p.running, errors.script_errors - errs])
	print("[t_save] hostile '%s' pen kept_animal=%s tamed=+%d script_errors=%d" % [label, keeps, player.bonded.size() - tamed, errors.script_errors - errs])

## A load that dies halfway (here: an unsanitized row handed straight to _apply) must leave saving
## refused, so the next autosave cannot write the half-built world over the good file. A later good
## load lifts the block.
func _test_aborted_load() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + GOLDEN))
	var sha0 := FileAccess.get_sha256(SG.path)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + GOLDEN))
	raw["t_stones"] = {}
	print("[t_save] the next SCRIPT ERROR (Nonexistent 'int' constructor) is the deliberate abort")
	expected_script_errors += 1
	SG._apply_guarded(host, raw, 3, false)
	_check(SG.blocked_reason == SG.LOAD_UNFINISHED and not SG.save_now(), "an aborted load refuses saves (blocked='%s')" % SG.blocked_reason)
	for i in 70:
		W._process(1.0)
	_check(FileAccess.get_sha256(SG.path) == sha0, "aborted load: bytes unchanged after 70 s of autosave")
	SG.confirm_new_game()
	_check(FileAccess.file_exists(SG.path), "confirm_new_game() never deletes a readable save after an aborted load")
	SG.load_now(host)
	_check(SG.blocked_reason == "" and SG.save_now(), "a later complete load clears the block")
	await process_frame

## A row that cannot be rebuilt while camp cargo is full is kept, never thrown away: no item may
## vanish across load + save, and the refund lands once the cargo has room.
func _test_full_cargo_refund() -> void:
	_clean()
	SG.save_now()
	var d := _saved()
	var branch: Dictionary = IS.make(&"branch", maxi(1, root.get_node("Data").item(&"branch").stack_max)).to_dict()
	var full: Array = []
	for i in W.cargo_home.slot_count:
		full.append(branch.duplicate(true))
	d["home"]["cargo"] = full
	d["home"]["buildings"] = [{"kind": "basket", "cell": _camp_cell("CampFire"), "rot": 0,
		"contents": [IS.make(&"flint", 3).to_dict(), IS.make(&"stone", 7).to_dict()]}]
	_put(JSON.stringify(d))
	SG.load_now(host)
	SG.save_now()
	var held := _held_on_disk(_saved())
	_check(held == [3, 7, 1], "full cargo: flint, stone and the basket kit stay on disk after load + save (got %s, want [3, 7, 1])" % [held])
	W.cargo_home.load_array([])
	SG.save_now()
	SG.load_now(host)
	SG.save_now()
	var after := _saved()
	var c = W.cargo_home
	var cargo_ok: bool = c.count_of(&"flint") == 3 and c.count_of(&"stone") == 7 and c.count_of(&"basket_kit") == 1
	_check(cargo_ok and (after.get("pending_refunds", []) as Array).is_empty() and _held_on_disk(after) == [3, 7, 1],
		"with room again the kept row is refunded once (flint=%d stone=%d kit=%d pending=%d)" % [c.count_of(&"flint"), c.count_of(&"stone"), c.count_of(&"basket_kit"), (after.get("pending_refunds", []) as Array).size()])
	print("[t_save] full cargo refund held_on_disk=%s after_room=%s" % [held, _held_on_disk(after)])
	await process_frame

## W2-INV: a pending refund kept by a pre-W2-INV save holds stacks (stone 10 x 20). Split, its 200
## instances are more than the whole camp cargo holds, so all-or-nothing would keep it unreachable on
## every load; the cargo grows for it instead, as the migration overflow does.
func _test_oversized_legacy_refund() -> void:
	_clean()
	SG.save_now()
	var d := _saved()
	d["home"]["cargo"] = []
	var contents: Array = []
	for i in 10:
		contents.append({"id": "stone", "count": 20})
	d["pending_refunds"] = [{"kind": "basket", "cell": [4000, 4000], "rot": 0, "contents": contents}]
	_put(JSON.stringify(d))
	# Earlier tests grew the cargo in memory (a load never shrinks it); start from its base 60 slots.
	W.cargo_home.load_array([])
	load("res://scripts/items/inventory_equipment.gd").resize(W.cargo_home, W.cargo_home.base_slots)
	var base: int = W.cargo_home.slot_count
	SG.load_now(host)
	SG.save_now()
	var c = W.cargo_home
	var pending := (_saved().get("pending_refunds", []) as Array).size()
	_check(base < 200 and c.count_of(&"stone") == 200 and c.count_of(&"basket_kit") == 1 and pending == 0,
		"a legacy refund of 200 stone lands in a grown camp cargo (stone=%d kit=%d slots %d -> %d pending=%d)" % [c.count_of(&"stone"), c.count_of(&"basket_kit"), base, c.slot_count, pending])
	SG.load_now(host)
	_check(W.cargo_home.count_of(&"stone") == 200, "the grown cargo reloads with all 200 stone (got %d)" % W.cargo_home.count_of(&"stone"))
	print("[t_save] oversized legacy refund stone=%d slots %d -> %d pending=%d" % [c.count_of(&"stone"), base, c.slot_count, pending])
	await process_frame

## [flint, stone, basket kits] anywhere in a save: cargo, building contents, pending refund rows.
func _held_on_disk(d: Dictionary) -> Array:
	var bag: Array = (d.get("home", {}).get("cargo", []) as Array).duplicate()
	var kits := 0
	for row in d.get("home", {}).get("buildings", []) + d.get("pending_refunds", []):
		bag.append_array(row.get("contents", []))
	for row in d.get("pending_refunds", []):
		if str(row.get("kind", "")) == "basket":
			kits += 1
	var n := {"flint": 0, "stone": 0, "basket_kit": kits}
	for s in bag:
		if s is Dictionary and n.has(str(s.get("id", ""))):
			n[str(s["id"])] += int(s.get("count", 1))
	return [n["flint"], n["stone"], n["basket_kit"]]

## A script error inside clean() still returns a (half-checked) Dictionary in Godot 4.7: read()
## must treat it as unreadable rather than apply it.
func _test_sanitizer_abort() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + GOLDEN))
	var San: GDScript = load("res://scripts/core/save_sanitizer.gd")
	San.set("abort_for_test", true)
	print("[t_save] the next SCRIPT ERROR (call on a null instance) is the deliberate sanitizer abort")
	expected_script_errors += 1
	var sha0 := FileAccess.get_sha256(SG.path)
	var r: Dictionary = (load("res://scripts/core/save_migrations.gd") as GDScript).read(SG.path)
	_check(r.has("error") and not r.has("data"), "an aborted sanitizer makes read() report an error (got %s)" % [r.keys()])
	expected_script_errors += 1
	SG.load_now(host) # the whole loader path, as a launch would take it
	San.set("abort_for_test", false)
	_check(SG.blocked_reason != "" and not SG.save_now(), "an aborted sanitizer refuses saves (blocked='%s')" % SG.blocked_reason)
	for i in 70:
		W._process(1.0)
	_check(FileAccess.get_sha256(SG.path) == sha0, "aborted sanitizer: bytes unchanged after 70 s of autosave")
	var forged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + GOLDEN))
	forged[San.get("CHECKED")] = true
	_put(JSON.stringify(forged))
	var ok: Dictionary = (load("res://scripts/core/save_migrations.gd") as GDScript).read(SG.path)
	_check(ok.has("data") and not (ok["data"] as Dictionary).has(San.get("CHECKED")), "the sentinel never reaches the loader")
	print("[t_save] sanitizer abort read=%s" % [r.get("error", "applied")])
	await process_frame

## A pen or field that cannot be rebuilt gives back everything it holds: the kit, the pen's captured
## animal, the field's seed. With full cargo all of it stays on disk until the cargo has room, and a
## pen the grid still accepts keeps its animal.
func _test_pen_refunds() -> void:
	_clean()
	var golden := FileAccess.get_file_as_string(FIX + GOLDEN)
	_put(golden)
	SG.load_now(host)
	await process_frame
	var free := _free_cell(&"makeshift_taming_pen")
	var off := free + Vector2i(60, 60)
	var off_field := off + Vector2i(0, 8)
	var grid = W.runtime.get("build_grid")
	grid.ignore_distance = true
	var whys := [grid.can_place(&"makeshift_taming_pen", off, 0), grid.can_place(&"field_small", off_field, 0)]
	grid.ignore_distance = false
	_check(whys[0] != "" and whys[1] != "", "the refund cells are rejected by the grid (%s)" % [whys])
	var occ := {"id": "captured_animal", "count": 1, "attributes": {"species": "velociraptor", "variant": "", "grade_seed": 7, "genetics": {}}}
	var rows := [_pen_row(off, occ), {"kind": "field_small", "cell": [off_field.x, off_field.y], "rot": 0, "crop_id": "corn", "growth": 0.5}]
	var d: Dictionary = JSON.parse_string(golden)
	d["home"]["cargo"] = []
	d["home"]["buildings"] = rows.duplicate(true)
	_put(JSON.stringify(d))
	SG.load_now(host)
	var c = W.cargo_home
	var at: int = c.find_first(&"captured_animal")
	var species: String = str(c.slots[at].attributes.get("species", "")) if at >= 0 else ""
	var got := [c.count_of(&"captured_animal"), species, c.count_of(&"makeshift_taming_pen"), c.count_of(&"field_small_kit"), c.count_of(&"corn_seed")]
	_check(got == [1, "velociraptor", 1, 1, 1], "a refunded pen and field give back the animal, both kits and the seed (got %s)" % [got])
	print("[t_save] pen refund cargo [animal, species, pen kit, field kit, corn_seed]=%s whys=%s" % [got, whys])
	var branch: Dictionary = IS.make(&"branch", maxi(1, root.get_node("Data").item(&"branch").stack_max)).to_dict()
	var full: Array = []
	for i in W.cargo_home.slot_count:
		full.append(branch.duplicate(true))
	d["home"]["cargo"] = full
	_put(JSON.stringify(d))
	SG.load_now(host)
	SG.save_now()
	var kept := 0
	for row in _saved().get("pending_refunds", []):
		if row.get("occupant") is Dictionary and str(row["occupant"].get("id", "")) == "captured_animal":
			kept += 1
	_check(kept == 1, "full cargo: the pen's captured animal stays on disk in pending_refunds (got %d)" % kept)
	W.cargo_home.load_array([])
	SG.save_now()
	SG.load_now(host)
	_check(c.count_of(&"captured_animal") == 1 and c.count_of(&"corn_seed") == 1, "with room again the kept animal and seed are refunded (animal=%d seed=%d)" % [c.count_of(&"captured_animal"), c.count_of(&"corn_seed")])
	d["home"]["cargo"] = []
	d["home"]["buildings"] = [_pen_row(free, occ)]
	_put(JSON.stringify(d))
	SG.load_now(host)
	var live := _live_pens()
	_check(live.size() == 1 and live[0].occupant != null and c.count_of(&"captured_animal") == 0, "a pen on a free claimed cell keeps its animal (pens=%d)" % live.size())
	print("[t_save] pen refund full_cargo_kept=%d free_cell_pens=%d" % [kept, live.size()])
	await process_frame

## World.travel snapshots the home camp through save_now() and rebuilds it from that cache: a refused
## save must still record this session's buildings, or sailing away and back loses them.
func _test_refused_save_keeps_camp() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + GOLDEN))
	SG.load_now(host) # the golden basket holds 5 stone
	await process_frame
	var cell := _free_cell(&"basket")
	var b: Node3D = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	W.runtime.add_child(b)
	SR.place(b, {"kind": "basket", "cell": [cell.x, cell.y], "rot": 0}, W.runtime.get("build_grid"))
	b.storage.add(IS.make(&"stone", 11))
	SG.blocked_reason = SG.LOAD_UNFINISHED
	var saved: bool = SG.save_now()
	# What World.travel does next: a new runtime, then the camp rebuilt from the cache.
	W.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)
	SG._restore_buildings(W._home_buildings_cache, SG.SCHEMA)
	await process_frame
	var got := _baskets()
	_check(not saved and got == [2, 16], "a refused save still refreshes the home camp cache: both baskets and 16 stone come back (got %s)" % [got])
	print("[t_save] refused save camp cache baskets=%d stone=%d" % [got[0], got[1]])
	SG.blocked_reason = ""

## Purchases are checked against trees.json and the SP the levels paid, not just type-checked.
func _test_skill_purchases() -> void:
	var San: GDScript = load("res://scripts/core/save_sanitizer.gd")
	var sv := {"trees": {"survival": {"level": 20, "xp": 0, "unlocked": ["island_access_15", "capture_technique_1", "belly_fat_1", "island_access_25", "ghost"]}}, "sp_spent": 0, "sp_available": 0}
	San._skills(sv)
	var kept: Array = sv["trees"]["survival"]["unlocked"]
	# island_access_25 is within level 20 but needs stealth_1, which was not bought; ghost is no node.
	_check(kept == ["island_access_15", "belly_fat_1", "capture_technique_1"], "reachable known nodes kept in tree order, the rest dropped (%s)" % [kept])
	_check(int(sv["sp_spent"]) == 5 + 6 + 8, "sp_spent is the cost of the kept nodes (%d)" % sv["sp_spent"])
	var legacy: Dictionary = San._legacy_survival({"capture_technique_I": true, "capture_technique_II": true, "nope": true, "animal_management_I": 1}, sv)
	_check(legacy == {"capture_technique_I": true, "capture_technique_II": false}, "legacy survival flags follow the bought tree nodes (%s)" % legacy)

## Stage a camp with every save-relevant field populated, then keep the save -> load -> save result.
func _write_golden() -> void:
	_clean()
	W.t_stones = 42
	W.pioneer_level = 3
	W.pioneer_xp = 57
	W.objective = 2
	W.objective_best = 1
	W.player_name = "Golden"
	W.occupation = "student"
	player.skills.apply_occupation("student")
	player.skills.add_xp("butchering", 120.0)
	var inv = player.inventory
	inv.load_array([])
	var knife = IS.make(&"stone_knife_work", 1)
	knife.wear(7)
	inv.add(knife)
	inv.add(IS.make(&"work_axe", 1))
	inv.add(IS.make(&"stone", 12))
	inv.add(IS.make(&"branch", 7))
	inv.add(IS.make(&"raw_meat", 3))
	inv.add(IS.make(&"raid_helm", 1))
	inv.equip(&"head", &"raid_helm")
	inv.add(IS.make(&"raid_helm", 1))
	W.cargo_home.load_array([])
	W.cargo_home.add(IS.make(&"flint", 4))
	player.vitals.fatigue = 30.0
	player.statuses.apply(&"bleeding")
	var pet = (load("res://scripts/pets/pet_record.gd") as GDScript).from_def(root.get_node("Data").creature(&"velociraptor"), &"B")
	pet.bag.add(IS.make(&"stone", 2))
	player.bonded.clear()
	player.bonded.append(pet)
	var bench := _free_cell(&"workbench")
	W.camp_layout = {"CampBench": {"cell": [bench.x, bench.y], "rot": 1}}
	W.load_island(host, &"home_grassland", Vector3(0, 1, 12), false) # rebuild the camp with the moved bench
	await process_frame
	var grid = W.runtime.get("build_grid")
	var PB := load("res://scripts/world/placed_building.gd") as GDScript
	var placed := 0
	for kind in [&"tent", &"basket", &"campfire", &"workbench"]:
		var cell := _free_cell(kind)
		var node: Node3D = SG._spawn_building({"kind": str(kind), "cell": [cell.x, cell.y], "rot": 1 if kind == &"workbench" else 0})
		W.runtime.add_child(node)
		SR.place(node, {"kind": str(kind), "cell": [cell.x, cell.y], "rot": 1 if kind == &"workbench" else 0}, grid)
		if kind == &"basket":
			node.storage.add(IS.make(&"stone", 5))
		placed += 1
	var snare_at: Vector3 = W.runtime.get("_camp_pos") + Vector3(3, 0, 3)
	(load("res://scripts/combat/ground_snare.gd") as GDScript).restore({"position": [snare_at.x, W.runtime.surface_y(snare_at.x, snare_at.z), snare_at.z], "life_left": 100.0, "arm_left": 0.0, "heavy": false}, W.runtime)
	SG.save_now()
	SG.load_now(host)
	SG.save_now()
	var d := _saved()
	d["unstable"]["harvested"] = {}
	d["saved_unix"] = 4000000000 # clamps to now at load: no offline time, so the snare round-trips
	var out := ProjectSettings.globalize_path(FIX + GOLDEN)
	var text := JSON.stringify(d, "\t")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	# save_truncated.json stays the base's (any cut-off save tests the same path).
	print("[t_save] wrote golden (%d buildings, %d pets, %d snares, %d bytes)" % [placed, d["pets"].size(), d["ground_snares"].size(), text.length()])
	# Away golden: the survivor standing on an unstable island with a stocked basket there.
	W.remaining_lifetime = 0.0
	W.load_island(host, &"temperate_25", Vector3(0, 1, 12), false)
	await process_frame
	var cell := _free_cell(&"basket")
	var b: Node3D = PB.make(&"basket")
	W.runtime.add_child(b)
	SR.place(b, {"kind": "basket", "cell": [cell.x, cell.y], "rot": 0}, W.runtime.get("build_grid"))
	b.storage.add(IS.make(&"stone", 9))
	SG.save_now()
	SG.load_now(host)
	SG.save_now()
	var a := _saved()
	a["unstable"]["harvested"] = {}
	a["saved_unix"] = 4000000000
	var af := FileAccess.open(ProjectSettings.globalize_path(FIX + AWAY_GOLDEN), FileAccess.WRITE)
	af.store_string(JSON.stringify(a, "\t") + "\n")
	af.close()
	print("[t_save] wrote away golden island=%s away_buildings=%d" % [a.get("island_id"), (a.get("away", {}).get("buildings", []) as Array).size()])

# ---------------------------------------------------------------- helpers

func _free_cell(kind: StringName) -> Vector2i:
	var grid = W.runtime.get("build_grid")
	var camp: Vector3 = W.runtime.get("_camp_pos")
	var at := Vector2i(floori(camp.x), floori(camp.z))
	var was: bool = grid.ignore_distance
	grid.ignore_distance = true
	for r in range(2, 9):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := at + Vector2i(dx, dz)
				if grid.can_place(kind, c, 0) == "" and grid.can_place(kind, c, 1) == "":
					grid.ignore_distance = was
					return c
	grid.ignore_distance = was
	_check(false, "no free cell for %s near the camp" % kind)
	return at

## [x, y] cell of one of the island's own camp pieces (CampFire, CampBench, CampShed).
func _camp_cell(name: String) -> Array:
	var n: Node = W.runtime.get_node_or_null(name)
	var c: Vector2i = n.get("build_cell") if n else Vector2i.ZERO
	_check(n != null, "camp piece %s exists" % name)
	return [c.x, c.y]

func _pen_row(cell: Vector2i, occupant: Dictionary) -> Dictionary:
	return {"kind": "makeshift_taming_pen", "cell": [cell.x, cell.y], "rot": 0, "running": true, "remaining": 100.0, "occupant": occupant.duplicate(true)}

func _live_pens() -> Array:
	return get_nodes_in_group("taming_pen").filter(func (p: Node) -> bool: return not p.is_queued_for_deletion() and W.runtime.is_ancestor_of(p))

## [count, stone] of live, non-cargo baskets on the current island.
func _baskets() -> Array:
	var n := 0
	var stone := 0
	for b in get_nodes_in_group("basket"):
		if b.is_queued_for_deletion() or b.get("storage") == null or bool(b.get("is_cargo")) or not W.runtime.is_ancestor_of(b):
			continue
		n += 1
		stone += int(b.storage.count_of(&"stone"))
	return [n, stone]

func _same(a: Variant, b: Variant, at: String, diffs: Array[String], skip: Array = []) -> void:
	if at in IGNORE or at in skip:
		return
	if a is Dictionary:
		if not b is Dictionary:
			diffs.append("%s: dict vs %s" % [at, type_string(typeof(b))])
			return
		for k in a:
			if not (b as Dictionary).has(k):
				diffs.append("%s/%s missing" % [at, k])
			else:
				_same(a[k], b[k], "%s/%s" % [at, k], diffs, skip)
	elif a is Array:
		if not b is Array or (a as Array).size() != (b as Array).size():
			diffs.append("%s: array size" % at)
			return
		for i in (a as Array).size():
			_same(a[i], b[i], "%s/%d" % [at, i], diffs, skip)
	elif (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > 1e-6 * maxf(1.0, absf(float(a))):
			diffs.append("%s: %s vs %s" % [at, a, b])
	elif a != b:
		diffs.append("%s: %s vs %s" % [at, a, b])

func _clean() -> void:
	SG.blocked_reason = ""
	var dir := ProjectSettings.globalize_path(RUN_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))

func _corrupt() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(RUN_DIR)):
		if f.begins_with("save_1.json.corrupt-"):
			out.append(f)
	return out

func _put(text: String) -> void:
	var f := FileAccess.open(SG.path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _saved() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	return parsed as Dictionary if parsed is Dictionary else {}

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
		print("[t_save] FAIL %s" % what)

func _finish() -> void:
	_check(errors.script_errors == expected_script_errors, "no unexpected SCRIPT ERROR (got %d, %d deliberate)" % [errors.script_errors, expected_script_errors])
	if failures.is_empty():
		print("[t_save] PASS")
		quit(0)
	else:
		print("[t_save] FAIL count=%d" % failures.size())
		quit(1)
