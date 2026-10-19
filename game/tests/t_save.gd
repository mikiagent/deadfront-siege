extends SceneTree
## W1-SAVE: crash-safe, sanitized, isolated saves. Prints "[t_save] PASS" (or FAIL lines), exits 0/1.
##   Godot --headless --path game --script res://tests/t_save.gd
## `-- --write-golden` re-stages a camp and rewrites save_v3_golden.json and save_truncated.json.
## Scripts that touch autoloads load on the first frame (see run_all.gd), so everything is load()ed.

const FIX := "res://tests/fixtures/"
const RUN_DIR := "user://runs/t_save"
## Island state regenerated on load, not save format: excluded from field-for-field compares.
const IGNORE := ["/saved_unix", "/unstable/harvested"]
## What each legacy fixture must still hold after its first load + save (not just idempotence):
## [building kinds, {item id: count} in the player's bag, t_stones, island_id].
const LEGACY := {
	"save_v0.json": [["basket"], {}, 20, "home_grassland"],
	"save_v1.json": [["basket"], {"stone": 3, "branch": 2}, 25, "home_grassland"],
	"save_v2.json": [[], {}, 20, "home_grassland"],
}

var failures: Array[String] = []
var _started := false
var W: Node
var SG: GDScript
var IS: GDScript
var host: Node3D
var player: Node

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _run() -> void:
	W = root.get_node("World")
	SG = load("res://scripts/core/save_game.gd")
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
	for name in ["save_v0.json", "save_v1.json", "save_v2.json", "save_v3_golden.json"]:
		await _test_round_trip(name)
	await _test_forged()
	await _test_truncated()
	await _test_future()
	await _test_backup_fallback()
	await _test_restore_refunds()
	await _test_away_island()
	await _test_hostile_types()
	await _test_aborted_load()
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
	if name == "save_v3_golden.json":
		var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + name))
		var gd: Array[String] = []
		_same(golden, s1, "", gd, ["/player/position/1"]) # y is re-seated on the terrain at load
		_check(gd.is_empty(), "v3 golden survives load + save unchanged: %s" % [gd.slice(0, 6)])
	print("[t_save] round trip %s fields=%d diffs=%d" % [name, s1.size(), diffs.size()])
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

func _test_forged() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + "save_forged.json"))
	SG.load_now(host)
	var inv = player.inventory
	var helm = inv.slots[inv.find_first(&"raid_helm")] if inv.find_first(&"raid_helm") >= 0 else null
	_check(helm != null and helm.count == 1 and helm.level == 60, "forged raid_helm x5000 L9999 loads as x1 L60")
	_check(helm != null and helm.durability <= helm.max_durability and helm.max_durability <= 1000, "forged durability clamps to the item's ceiling")
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
	var cuirass: int = W.cargo_home.find_first(&"raid_cuirass")
	_check(cuirass >= 0 and W.cargo_home.slots[cuirass].count == 1, "cargo raid_cuirass x3000 loads as x1")
	var bought: Array = player.skills.trees["survival"]["unlocked"]
	_check(bought == ["island_access_15"] and player.skills.sp_spent == 5, "survival L10 listing every node keeps only island_access_15, sp_spent 5 (got %s, %d)" % [bought, player.skills.sp_spent])
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
	SG._place_building(b, {"kind": "basket", "cell": [cell.x, cell.y], "rot": 0}, W.runtime.get("build_grid"))
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
	for label in cases:
		_clean()
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v3_golden.json"))
		(cases[label] as Callable).call(d)
		_put(JSON.stringify(d))
		W.t_stones = 0
		player.inventory.load_array([])
		SG.load_now(host)
		var stacks := 0
		for st in player.inventory.slots:
			if st != null: stacks += 1
		var ok: bool = SG.blocked_reason == "" and int(W.t_stones) == 42 and stacks == 6
		_check(ok and SG.save_now(), "hostile '%s' loads completely and saves (blocked='%s' t_stones=%d stacks=%d)" % [label, SG.blocked_reason, W.t_stones, stacks])
		print("[t_save] hostile '%s' blocked='%s' t_stones=%d stacks=%d" % [label, SG.blocked_reason, W.t_stones, stacks])
		await process_frame

## A load that dies halfway (here: an unsanitized row handed straight to _apply) must leave saving
## refused, so the next autosave cannot write the half-built world over the good file. A later good
## load lifts the block.
func _test_aborted_load() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + "save_v3_golden.json"))
	var sha0 := FileAccess.get_sha256(SG.path)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v3_golden.json"))
	raw["t_stones"] = {}
	print("[t_save] the next SCRIPT ERROR (Nonexistent 'int' constructor) is the deliberate abort")
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
	inv.equip(&"head", &"raid_helm")
	inv.add(IS.make(&"raid_helm", 1))
	W.cargo_home.load_array([])
	W.cargo_home.add(IS.make(&"flint", 4))
	player.vitals.fatigue = 30.0
	var grid = W.runtime.get("build_grid")
	var PB := load("res://scripts/world/placed_building.gd") as GDScript
	var placed := 0
	for kind in [&"tent", &"basket", &"campfire", &"workbench"]:
		var cell := _free_cell(kind)
		var node: Node3D = SG._spawn_building({"kind": str(kind), "cell": [cell.x, cell.y], "rot": 1 if kind == &"workbench" else 0})
		W.runtime.add_child(node)
		SG._place_building(node, {"kind": str(kind), "cell": [cell.x, cell.y], "rot": 1 if kind == &"workbench" else 0}, grid)
		if kind == &"basket":
			node.storage.add(IS.make(&"stone", 5))
		placed += 1
	SG.save_now()
	SG.load_now(host)
	SG.save_now()
	var d := _saved()
	d["unstable"]["harvested"] = {}
	d["saved_unix"] = 1792000000
	var out := ProjectSettings.globalize_path(FIX + "save_v3_golden.json")
	var text := JSON.stringify(d, "\t")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
	var t := FileAccess.open(ProjectSettings.globalize_path(FIX + "save_truncated.json"), FileAccess.WRITE)
	t.store_string(text.left(text.length() / 2)) # a save cut off mid-write
	t.close()
	print("[t_save] wrote golden (%d buildings, %d bytes) and truncated fixtures" % [placed, text.length()])

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
	if failures.is_empty():
		print("[t_save] PASS")
		quit(0)
	else:
		print("[t_save] FAIL count=%d" % failures.size())
		quit(1)
