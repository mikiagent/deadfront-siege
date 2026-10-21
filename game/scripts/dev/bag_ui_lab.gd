extends Node3D
## INVUI lab (spec 13): one deterministic survivor whose bag looks like the Durango Bag reference.
## 91 of 100 slots used: berries Lv. 12/25/42 (the 42 has a rare trait), raptor bones Lv. 45/60
## (the 60 has Firm, Low Density and the rare Black Sheen), herb leaves, a caged animal (4 slots),
## a workbench kit, weapons, tools and armour; the newest pickups are NEW, two valuables are
## locked; forager hood and vest are worn and the work pick is the held tool; a bonded raptor
## carries cargo and a storage box sits beside the survivor.
##
## Shots (the judge is gl_compatibility at 1600x900; phones are landscape 844x390):
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility \
##     -- --lab=bag_ui_lab --screen=bag --shot=/tmp/bag.png --shot-delay=6
##   --screen= bag | inspect | character | equipment | storage | cargo | picker
## Headless (no --shot): checks the seed and the screen contract, prints "[bagui] PASS ..." or
## FAIL lines and exits 0/1. It FAILS until the builders give InventoryUI the contract below.
##
## Contract on InventoryUI the builders implement (docs/orchestration/mmo/invui-spec.md section 4):
##   open_bag(), open_character(), open_equipment(slot := &""), open_picker(rid, slot_index, on_pick),
##   select_uid(uid), current_screen() -> StringName; show_storage()/show_pet_bag() keep their
##   signatures and open the shared split view.

const SCREENS := [&"bag", &"inspect", &"character", &"equipment", &"storage", &"cargo", &"picker"]
const CONTRACT := ["open_bag", "select_uid", "current_screen"]
## Contract members a later build step adds; until then their screens are skipped, not failed.
const LATER := {"open_character": "B2", "open_equipment": "B2", "open_picker": "B3"}
const USED := 91
## Filler after the named items, in pickup order: [id, instances, first level, level step].
const FILL := [
	[&"herb_leaf", 16, 8, 3], [&"stone", 12, 4, 5], [&"branch", 10, 3, 4], [&"fibre_stalk", 8, 6, 7],
	[&"raw_meat", 6, 10, 6], [&"flint", 6, 5, 9], [&"wood_log", 4, 12, 8], [&"raptor_hide", 4, 15, 11],
	[&"mushroom", 3, 2, 13], [&"clay", 2, 7, 5], [&"resin", 1, 9, 1],
]

var player: Player
var storage_box: Inventory
var uids := {}  ## role -> uid, for selection and the checks
var _fails: PackedStringArray = []
var _screen: StringName = &"bag"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			_screen = StringName(a.substr(9))
	var kit := LabKit.build(self, 30.0)
	player = kit["player"]
	# Same layering as main.gd: the bag family is a modal above the HUD's canvas layers.
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	player.ui.reparent(modals)
	_seed()
	await get_tree().process_frame
	await get_tree().process_frame
	var opened := _open(_screen)
	print("[bagui] seed bag %d/%d worn=%d new=%d locked=%d screen=%s opened=%s" % [player.inventory.used_slots(),
		player.inventory.slot_count, _worn_count(), _flag_count(&"new"), _flag_count(&"locked"), _screen, opened])
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		_check()

# ---------------------------------------------------------------- seed

func _seed() -> void:
	# Seeding is not a pickup: only the items marked below carry NEW.
	InvNewTracker.rebaseline(player.inventory)
	World.player_name = "Milan"
	World.occupation = "Gatherer"
	World.pioneer_level = 13
	World.pioneer_xp = 222
	World.t_stones = 345
	for tree in {"gathering": 4, "melee": 2, "processing": 5, "tailoring": 3, "survival": 6}.keys():
		var row: Variant = player.skills.trees.get(tree)
		if row is Dictionary:
			row["level"] = {"gathering": 4, "melee": 2, "processing": 5, "tailoring": 3, "survival": 6}[tree]
	var inv := player.inventory
	inv.slot_count = Inventory.BASE_SLOTS
	inv.slots.resize(inv.slot_count)
	# Newest pickups first in the reference: berries, leaves and the cage carry NEW.
	_add(&"berry", 12, {}, "berry12", true)
	_add(&"berry", 25, {}, "berry25", true)
	_add(&"berry", 42, {"full": 4, "vivid_inspiration": true}, "berry42", true)
	_add(&"raptor_bone", 45, {"firm": 6, "low_density": 2}, "bone45", true)
	_add(&"raptor_bone", 60, {"firm": 8, "low_density": 3, "black_sheen": true}, "bone60", false, true)
	_add(&"captured_animal", 13, {"species": "zebraceratops", "variant": "", "level": 13}, "cage", true)
	_add(&"workbench_kit", 1, {}, "workbench", false)
	_add(&"stone_knife", 18, {}, "knife", false)
	_add(&"club", 22, {}, "club", false, true)
	_add(&"slingshot", 15, {}, "slingshot", false)
	_add(&"work_pick", 10, {}, "pick", false)
	_add(&"work_axe", 9, {}, "axe", false)
	_add(&"travel_shirt", 6, {}, "shirt", false)
	_add(&"hide_bone_cuirass", 20, {}, "cuirass", false)
	_add(&"raid_helm", 30, {}, "helm", false)
	_add(&"forager_wraps", 11, {}, "wraps", false)
	_add(&"forager_leggings", 11, {}, "leggings", false)
	_add(&"forager_hood", 12, {}, "hood", false)
	_add(&"forager_vest", 12, {}, "vest", false)
	for row in FILL:
		for k in int(row[1]):
			if inv.used_slots() >= USED:
				break
			_add(row[0], 1 + (int(row[2]) + k * int(row[3])) % 60, {}, "", k < 6 and row[0] == &"herb_leaf")
	inv.equip_at(_index_of(uids["hood"]), &"head")
	inv.equip_at(_index_of(uids["vest"]), &"body")
	inv.set_equipped_tool_index(_index_of(uids["pick"]))
	# Pad back to USED after the two worn pieces left the bag.
	var k2 := 0
	while inv.used_slots() < USED:
		_add(&"herb_leaf", 20 + k2 * 7 % 40, {}, "", false)
		k2 += 1
	# A bonded raptor with cargo, and a storage box.
	var rec := PetRecord.from_def(Data.creature(&"velociraptor"), &"A")
	rec.bag.add(ItemStack.make(&"raw_meat", 1, {}, 18))
	rec.bag.add(ItemStack.make(&"raptor_hide", 1, {}, 21))
	rec.bag.add(ItemStack.make(&"berry", 1, {}, 33))
	player.bonded.append(rec)
	storage_box = Inventory.new(60)
	for id in [&"wood_log", &"stone", &"raptor_bone", &"herb_leaf", &"fibre_stalk"]:
		storage_box.add(ItemStack.make(id, 1, {}, 14))

func _add(id: StringName, lvl: int, attrs: Dictionary, role: String, is_new: bool, locked: bool = false) -> void:
	var s := ItemStack.make(id, 1, attrs, lvl)
	var before := {}
	for x in player.inventory.slots:
		if x:
			before[x.uid] = true
	if player.inventory.add(s) > 0:
		_fails.append("seed: %s did not fit" % id)
		return
	for x in player.inventory.slots:
		if x and x.uid != "" and not before.has(x.uid):
			if role != "":
				uids[role] = x.uid
			if is_new and not x.is_fungible():
				x.set_flag(&"new", true)
			if locked:
				x.set_flag(&"locked", true)

func _index_of(uid: String) -> int:
	for i in player.inventory.slot_count:
		var s: ItemStack = player.inventory.slots[i]
		if s and s.uid == uid:
			return i
	return -1

func _worn_count() -> int:
	var n := 0
	for slot in Inventory.EQUIP_SLOTS:
		n += 1 if player.inventory.worn(slot) else 0
	return n

func _flag_count(flag: StringName) -> int:
	var n := 0
	for s in player.inventory.slots:
		n += 1 if s and flag in s.flags else 0
	return n

# ---------------------------------------------------------------- screens

## Opens `screen` through the InventoryUI contract. Until the builders add it, falls back to the
## old bag so a shot still shows something, and says so.
func _open(screen: StringName) -> bool:
	var ui := player.ui
	for m in CONTRACT:
		if not ui.has_method(m):
			print("[bagui] FAIL skeleton: InventoryUI.%s missing (B1/B2/B3 build it)" % m)
			ui.visible = true
			ui.rebuild()
			return false
	for m in LATER:
		if str(screen) in str(m) and not ui.has_method(m):
			print("[bagui] SKIP %s: InventoryUI.%s comes in %s" % [screen, m, LATER[m]])
			return false
	match screen:
		&"bag":
			ui.call("open_bag")
			ui.call("select_uid", uids["cage"])
		&"inspect":
			ui.call("open_bag")
			ui.call("select_uid", uids["bone60"])
		&"character":
			ui.call("open_character")
		&"equipment":
			ui.call("open_equipment", &"body")
		&"storage":
			ui.show_storage(storage_box, player, {"title": "Storage Box", "allow_deposit": true})
			ui.call("select_uid", uids["berry42"])
		&"cargo":
			ui.show_pet_bag(player.bonded[0])
		&"picker":
			ui.call("open_picker", &"camp_stew", 2, func(_pick: Variant) -> void: pass)
		_:
			print("[bagui] FAIL unknown --screen=%s (one of %s)" % [screen, SCREENS])
			return false
	return str(ui.call("current_screen")) == str(screen if screen != &"inspect" else &"bag")

# ---------------------------------------------------------------- headless check

## B1: the Bag shows one cell per instance with the lab's labels, and the selection inspects it.
func _check_bag() -> void:
	var ui := player.ui
	ui.call("open_bag")
	ui.call("select_uid", uids["bone60"])
	var bag: BagScreen = ui.get("_bag")
	# Headless windows are 64x64: the column count is the one InvTheme picks for the canvas (t_invui 20 pins 7 at 1600x900).
	var want: int = InvTheme.metrics(bag.size).columns if bag else -1
	_expect(ui.call("current_screen") == &"bag" and bag != null and bag.grid.columns == want, "the Bag opens with its %d-column grid (screen %s, columns %s, size %s)" % [want, ui.call("current_screen"), bag.grid.columns if bag else -1, bag.size if bag else Vector2.ZERO])
	var leads := 0
	for s in player.inventory.slots:
		leads += 1 if s and s.def_id != Inventory.LOCK else 0
	_expect(bag.grid.item_cells().size() == leads and bag.grid.cells().size() == leads + player.inventory.slot_count - USED, "one cell per instance plus %d empty compartments (%d cells)" % [player.inventory.slot_count - USED, bag.grid.cells().size()])
	var rows := "\n".join(bag.inspect.rows())
	_expect(bag.inspect.title_text() == "Raptor Bone" and rows.contains("Firm Lv. 8") and rows.contains("Black Sheen"), "selecting the Lv. 60 bone inspects its traits")
	var t0 := Time.get_ticks_usec()
	bag.grid.refresh()
	var us := Time.get_ticks_usec() - t0
	player.inventory.slot_count = 142
	player.inventory.slots.resize(142)
	t0 = Time.get_ticks_usec()
	bag.grid.refresh()
	var us142 := Time.get_ticks_usec() - t0
	player.inventory.slot_count = 100
	player.inventory.slots.resize(100)
	print("[bagui] grid refresh 100=%dus 142=%dus" % [us, us142])
	_expect(us < 50000 and us142 < 50000, "a bag refresh stays under 50 ms")

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[bagui] FAIL %s" % what)

func _check() -> void:
	var inv := player.inventory
	_expect(inv.used_slots() == USED and inv.slot_count == 100, "the bag is %d / 100 (got %d / %d)" % [USED, inv.used_slots(), inv.slot_count])
	var berries := []
	for s in inv.slots:
		if s and s.def_id == &"berry":
			berries.append(s.uid)
	_expect(berries.size() == 3 and berries[0] != berries[1] and berries[1] != berries[2], "three berries, three uids")
	_expect(_worn_count() == 2 and inv.equipped_gather_tool() != null, "hood and vest worn, the pick held")
	_expect(_flag_count(&"new") >= 8 and _flag_count(&"locked") == 2, "NEW and locked seeded")
	_expect(player.bonded.size() == 1 and player.bonded[0].bag.used_slots() == 3, "a bonded raptor with 3 cargo items")
	for m in CONTRACT:
		_expect(player.ui.has_method(m), "InventoryUI.%s exists" % m)
	if _fails.is_empty():
		# Open speed (spec 13 s20; design gate M2): each screen built and laid out in one go.
		var times := []
		for screen in SCREENS:
			var t0 := Time.get_ticks_usec()
			var ok := _open(screen)
			times.append("%s=%s" % [screen, ("%dus" % (Time.get_ticks_usec() - t0)) if ok else "later"])
		print("[bagui] open times %s" % ", ".join(PackedStringArray(times)))
		_check_bag()
	if _fails.is_empty():
		print("[bagui] PASS bag=%d/%d new=%d locked=%d" % [inv.used_slots(), inv.slot_count, _flag_count(&"new"), _flag_count(&"locked")])
	get_tree().quit(0 if _fails.is_empty() else 1)
