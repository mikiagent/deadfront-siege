extends Node3D
## INVUI lab (spec 13): one deterministic survivor whose bag looks like the Durango Bag reference.
## 91 of 100 slots used: berries Lv. 12/25/42 (the 42 has a rare trait), raw meat Lv. 23 processed twice
## (the in-game reference's "Carne"; every other raw meat once), raptor bones Lv. 45/60
## (the 60 has Firm, Low Density and the rare Black Sheen), herb leaves, a caged animal (4 slots),
## a workbench kit, weapons, tools and armour; the newest pickups are NEW, two valuables are
## locked; forager hood and vest are worn and the work pick is the held tool; a bonded raptor
## carries cargo and a storage box sits beside the survivor.
##
## Shots (the judge is gl_compatibility at 1600x900; phones are landscape 844x390):
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility \
##     -- --lab=bag_ui_lab --screen=bag --shot=/tmp/bag.png --shot-delay=6
##   --screen= bag | inspect | character | equipment | storage | cargo | picker
##   (bag and inspect are the in-game Bag: the panel docked on the right over the live lab world, the
##   item card floating between them; --select=meat is the owner's in-game reference state)
##   (shot-only: storage_select = the storage reference's "1 Select" with a gold check; storage_notice =
##   a box that belongs to someone else, its notice over the grid; craft = the stew menu)
##   --insets=left,right,bottom[,top] lays the family out inside a phone's safe area (notch)
##   --query=<text> with a storage screen opens Search with that text
##   --select=<role> then selects that seeded instance (berry12/25/42, bone45/60, cage, knife, club, ...;
##   box_bone on the storage side, cargo_berry on the cargo side; with --screen=picker a berry);
##   with --screen=equipment it opens that item's gear cell with it picked (the compare state)
##   --recipe=<id> --recipe-slot=<n> with --screen=picker (default camp_stew slot 2, the berries)
##   --stats=<group> with --screen=character opens Detailed Stats at that group
##   --slot=<cell> with --screen=character|equipment selects that gear cell (accessory1 = the empty state)
##   --perf (windowed): fills a 142-slot bag, opens it and prints the build time and the time to its
##   first drawn frame ("[bagui] perf142 ..."), then shows that bag for the shot
## Headless (no --shot): checks the seed and the screen contract, prints "[bagui] PASS ..." or
## FAIL lines and exits 0/1. It FAILS until the builders give InventoryUI the contract below.
##
## Contract on InventoryUI the builders implement (docs/orchestration/mmo/invui-spec.md section 4):
##   open_bag(), open_character(), open_equipment(slot := &""), open_picker(rid, slot_index, on_pick),
##   select_uid(uid), current_screen() -> StringName; show_storage()/show_pet_bag() keep their
##   signatures and open the shared split view.

const SCREENS := [&"bag", &"inspect", &"character", &"equipment", &"storage", &"cargo", &"picker"]
## Shot-only screens: storage in multi-select and with a foreign box's notice (the owner's storage
## reference), and the craft menu's camp stew with the Lv. 25 berry chosen through the picker.
const SHOT_ONLY := [&"storage_select", &"storage_notice", &"craft"]
const CONTRACT := ["open_bag", "select_uid", "current_screen", "open_character", "open_equipment", "open_picker"]
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
var _slot: StringName = &"body"
var _recipe: StringName = &"camp_stew"
var _recipe_slot := 2
var _query := ""
var _perf := false

func _ready() -> void:
	var pick := ""
	var stats := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			_screen = StringName(a.substr(9))
		elif a.begins_with("--select="):
			pick = a.substr(9)
		elif a.begins_with("--stats="):
			stats = a.substr(8)
		elif a.begins_with("--slot="):
			_slot = StringName(a.substr(7))
		elif a.begins_with("--recipe="):
			_recipe = StringName(a.substr(9))
		elif a.begins_with("--recipe-slot="):
			_recipe_slot = int(a.substr(14))
		elif a.begins_with("--query="):
			_query = a.substr(8)
		elif a == "--perf":
			_perf = true
		elif a.begins_with("--insets="):
			var v := a.substr(9).split_floats(",")
			v.resize(4)
			InvTheme.forced_insets = Vector4(v[1], v[2], v[3], v[0]) # x right, y bottom, z top, w left
	var kit := LabKit.build(self, 30.0)
	player = kit["player"]
	# Same layering as main.gd: the bag family is a modal above the HUD's canvas layers.
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	player.ui.reparent(modals)
	(player.craft_ui as Node).reparent(modals) # main.gd puts the craft menu there too
	_seed()
	await get_tree().process_frame
	await get_tree().process_frame
	var opened := _open(_screen)
	if pick != "" and uids.has(pick) and _screen == &"equipment":
		var st: ItemStack = player.inventory.slots[_index_of(uids[pick])]
		player.ui.call("open_equipment", Inventory.slot_for(st.def()) if Inventory.slot_for(st.def()) != &"" else &"tool", uids[pick])
	elif pick != "" and uids.has(pick):
		player.ui.call("select_uid", uids[pick]) # e.g. --select=berry25 shows its actions
	if stats != "" and _screen == &"character":
		(player.ui.get("_character") as CharacterScreen).open_stats(stats)
	print("[bagui] seed bag %d/%d worn=%d new=%d locked=%d screen=%s opened=%s" % [player.inventory.used_slots(),
		player.inventory.slot_count, _worn_count(), _flag_count(&"new"), _flag_count(&"locked"), _screen, opened])
	if _perf:
		await _measure_open142()
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		_check()

# ---------------------------------------------------------------- seed

func _seed() -> void:
	# Seeding is not a pickup: only the items marked below carry NEW.
	InvNewTracker.rebaseline(player.inventory)
	World.player_name = "Milan"
	World.occupation = "Gatherer"
	World.pioneer_level = 12 # reads "Lv. 13" like the Character reference (LevelDisplay: stored + 1)
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
	_add(&"raw_meat", 23, {}, "meat", false, false, 2)
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
			_add(row[0], 1 + (int(row[2]) + k * int(row[3])) % 60, {}, "", k < 6 and row[0] == &"herb_leaf", false, 1 if row[0] == &"raw_meat" else 0)
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
	uids["cargo_berry"] = rec.bag.slots[rec.bag.find_first(&"berry")].uid
	player.bonded.append(rec)
	# A storage box filled like the owner's storage reference: a hide, sticks, ore with Firm / Heavy
	# pips, a processed iron ingot (Firm Lv. 4, Heavy Lv. 2, hammer ×3), leaves and logs; 47 / 80.
	storage_box = Inventory.new(80)
	_box(&"raptor_hide", 45, {})
	for k in 7:
		_box(&"branch", 60, {})
	_box(&"plank", 60, {"firm": 2})
	for k in 11:
		_box(&"ore", 60, {"firm": 3 + k % 2, "heavy": 2} if k % 3 == 0 else {"firm": 4})
	uids["box_ingot"] = _box(&"iron_ingot", 60, {"firm": 4, "heavy": 2}, 3)
	uids["box_bone"] = _box(&"raptor_bone", 52, {"firm": 5})
	for k in 4:
		_box(&"branch", 60, {})
	for k in 12:
		_box(&"herb_leaf", 40 + k * 2, {})
	for k in 9:
		_box(&"wood_log", 45 + k * 2, {"heavy": 1} if k % 4 == 0 else {})

## One instance into the storage box; returns its uid.
func _box(id: StringName, lvl: int, attrs: Dictionary, processed: int = 0) -> String:
	var s := ItemStack.make(id, 1, attrs, lvl)
	s.process_count = processed
	var before := storage_box.uids()
	storage_box.add(s)
	for u: String in storage_box.uids():
		if not before.has(u):
			return u
	return ""

func _add(id: StringName, lvl: int, attrs: Dictionary, role: String, is_new: bool, locked: bool = false, processed: int = 0) -> void:
	var s := ItemStack.make(id, 1, attrs, lvl)
	s.process_count = processed
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
	match screen:
		&"bag":
			ui.call("open_bag")
			ui.call("select_uid", uids["cage"])
		&"inspect":
			ui.call("open_bag")
			ui.call("select_uid", uids["bone60"])
		&"character":
			ui.call("open_character", _slot)
		&"equipment":
			ui.call("open_equipment", _slot)
		&"storage":
			ui.show_storage(storage_box, player, {"title": "Storage Box", "allow_deposit": true})
			ui.call("select_uid", uids["box_ingot"])
			if _query != "":
				(ui.get("_storage") as StorageScreen).toolbar.set_search(true, _query)
		&"storage_select", &"storage_notice":
			var opts := {"title": "Storage Box", "allow_deposit": true}
			if screen == &"storage_notice":
				opts = {"title": "Small Box", "readonly_reason": "This box belongs to someone else: cannot take."}
			ui.show_storage(storage_box, player, opts)
			var st: StorageScreen = ui.get("_storage")
			st.toolbar.set_select(true)
			st.toolbar.select_toggled.emit(true)
			ui.call("select_uid", uids["box_ingot"])
			return ui.call("current_screen") == &"storage" and st.box_grid.multi
		&"cargo":
			ui.show_pet_bag(player.bonded[0])
		&"picker":
			ui.call("open_picker", _recipe, _recipe_slot, func(_pick: Variant) -> void: pass)
		&"craft":
			var craft: Node = player.craft_ui
			craft.call("show_for_station", &"crock_pot")
			craft.call("_choose_recipe", "camp_stew")
			craft.call("_set_chosen", "camp_stew", 2, [_index_of(uids["berry25"])]) # what the picker's Use hands back
			craft.call("rebuild")
			return craft.visible
		_:
			print("[bagui] FAIL unknown --screen=%s (one of %s)" % [screen, SCREENS + SHOT_ONLY])
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
	var want: int = InvTheme.dock_metrics(bag.size).columns if bag else -1
	_expect(ui.call("current_screen") == &"bag" and bag != null and bag.grid.columns == want, "the Bag opens with its %d-column grid (screen %s, columns %s, size %s)" % [want, ui.call("current_screen"), bag.grid.columns if bag else -1, bag.size if bag else Vector2.ZERO])
	var leads := 0
	for s in player.inventory.slots:
		leads += 1 if s and s.def_id != Inventory.LOCK else 0
	_expect(bag.grid.item_cells().size() == leads and bag.grid.cells().size() == leads + player.inventory.slot_count - USED, "one cell per instance plus %d empty compartments (%d cells)" % [player.inventory.slot_count - USED, bag.grid.cells().size()])
	var rows := "\n".join(bag.inspect.rows())
	_expect(bag.inspect.title_text() == "Raptor Bone" and rows.contains("Firm Lv. 8") and rows.contains("Black Sheen"), "selecting the Lv. 60 bone inspects its traits")
	# The in-game reference's card: the twice-processed raw meat, its state, food values and Eat.
	ui.call("select_uid", uids["meat"])
	rows = "\n".join(bag.inspect.rows())
	var meat: ItemStack = player.inventory.slots[_index_of(uids["meat"])]
	_expect(bag.inspect.visible and bag.inspect.title_text() == "Raw Meat" and rows.contains("Processed  ×2") and rows.contains("\nRaw\n") \
		and rows.contains("Energy  +%.0f" % Food.energy_restore(meat)) and not bag.inspect.actions().is_empty() and bag.inspect.actions()[0] == &"eat", "the meat's card: Raw, hammer ×2, Energy, Eat first (%s | %s)" % [rows.replace("\n", " / "), bag.inspect.actions()])
	ui.call("select_uid", "")
	_expect(not bag.inspect.visible, "with nothing selected the card leaves the world clear")
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

## B2: Character and Equipment over the seeded gear, and the stat-once check through the screens:
## equip, equip again (a swap), unequip, then compare every number with the start.
func _check_gear() -> void:
	var ui := player.ui
	var inv := player.inventory
	ui.call("open_character", &"body")
	var ch: CharacterScreen = ui.get("_character")
	var vest := inv.equipped_in(&"body")
	_expect(ui.call("current_screen") == &"character" and ch.list.selected_uid() == "" and ch.primary.text == "Unequip", "Character opens on the worn vest with Unequip")
	_expect(ch.list.item_cells().size() == 3 and (ch.list.item_cells()[0] as InventorySlot).worn, "the torso list is the worn vest (marked) and the two bag pieces that fit")
	var s0 := InvStats.snapshot(player)
	# Pick the cuirass on Character: Equipment opens with it picked and previews it.
	ch.list.select_uid(uids["cuirass"])
	var eq: EquipmentScreen = ui.get("_equipment")
	var preview := InvStats.with_candidate(player, _index_of(uids["cuirass"]), &"body")
	_expect(ui.call("current_screen") == &"equipment" and eq.info_text("defense").contains("→"), "Equipment previews the cuirass (%s)" % eq.info_text("defense"))
	eq.primary.pressed.emit()
	var s1 := InvStats.snapshot(player)
	_expect(s1 == preview and inv.equipped_in(&"body").uid == uids["cuirass"], "Equip wears the cuirass and the numbers are the preview's")
	ui.call("open_equipment", &"body", uids["shirt"])
	eq.primary.pressed.emit()
	var s2 := InvStats.snapshot(player)
	var shirt_armor := inv.equipped_in(&"body").scaled_armor()
	_expect(is_equal_approx(float(s2.defense) - float(s0.defense), shirt_armor - vest.scaled_armor()), "a second Equip swaps: Defense counts only the shirt (%s -> %s)" % [s0.defense, s2.defense])
	# Put the vest back: every number is the start's again.
	ui.call("open_equipment", &"body", vest.uid)
	eq.primary.pressed.emit()
	_expect(InvStats.snapshot(player) == s0, "the vest back on restores every number")
	print("[bagui] gear stats defense start=%d cuirass=%d shirt=%d back=%d" % [roundi(float(s0.defense)), roundi(float(s1.defense)), roundi(float(s2.defense)), roundi(float(InvStats.snapshot(player).defense))])
	ui.call("open_character", &"body")
	ch.open_stats("combat")
	_expect(Array(ch.stats_panel.rows()).has("Attack  %s" % InvStats.fmt("attack", s0.attack)), "Detailed Stats shows the Attack the screens show")
	ui.call("hide_ui")

## B3: the storage split view, dinosaur cargo and the ingredient picker move and pick exact instances.
func _check_b3() -> void:
	var ui := player.ui
	var inv := player.inventory
	ui.show_storage(storage_box, player, {"title": "Storage Box", "allow_deposit": true, "take_all": true})
	var st: StorageScreen = ui.get("_storage")
	ui.call("select_uid", uids["berry42"])
	_expect(st.inspect.title_text() == "Berry" and st.inspect.actions() == [&"store"], "storage: the Lv. 42 berry is inspected with Store (%s)" % [st.inspect.actions()])
	st.action_button(&"store").pressed.emit()
	var at := storage_box.find_first(&"berry")
	var stored := storage_box.slots[at] if at >= 0 else null
	_expect(stored != null and stored.uid == uids["berry42"] and stored.level == 42 and stored.attributes.has("vivid_inspiration") and _index_of(uids["berry42"]) == -1, "storage: Store moved that exact berry with its trait")
	ui.call("select_uid", uids["berry42"])
	_expect(st.inspect.actions() == [&"take", &"take_all"], "storage: on the box side it offers Take and Take All (%s)" % [st.inspect.actions()])
	st.action_button(&"take").pressed.emit()
	_expect(_index_of(uids["berry42"]) >= 0 and storage_box.find_first(&"berry") < 0, "storage: Take brought it back")
	# The storage reference: Select on the box tab, two picked, one Transfer to Bag moves exactly them;
	# then both back from the Bag tab in one Transfer.
	st.show_tab(&"box")
	st.toolbar.set_select(true)
	st.toolbar.select_toggled.emit(true)
	st.box_grid.select_uid(uids["box_ingot"])
	st.box_grid.select_uid(uids["box_bone"])
	_expect(st.header.title == "Select" and st.header.get("_lead").text == "2" and st.action_button(&"take") != null and st.action_button(&"take").text == "Transfer to Bag", "storage: Select with two picked reads '2 Select' and offers Transfer to Bag")
	st.action_button(&"take").pressed.emit()
	_expect(_index_of(uids["box_ingot"]) >= 0 and _index_of(uids["box_bone"]) >= 0 and storage_box.used_slots() == 45, "storage: one Transfer moved the ingot and the bone, nothing else")
	ui.call("select_uid", uids["box_ingot"])
	st.bag_grid.select_uid(uids["box_bone"])
	st.action_button(&"store").pressed.emit()
	_expect(storage_box.uids().has(uids["box_ingot"]) and storage_box.uids().has(uids["box_bone"]) and inv.used_slots() == USED, "storage: Transfer to Storage Box put both back")
	ui.show_storage(storage_box, player, {"title": "Small Box", "readonly_reason": "This box belongs to someone else: cannot take."})
	ui.call("select_uid", uids["box_ingot"])
	_expect(st.notice_text().begins_with("This box belongs to someone else") and st.inspect.actions().is_empty(), "storage: someone else's box says so over the grid and offers no Transfer (%s)" % st.notice_text())
	ui.show_pet_bag(player.bonded[0])
	ui.call("select_uid", uids["cargo_berry"])
	_expect(ui.call("current_screen") == &"cargo" and st.inspect.actions() == [&"take"], "cargo: the raptor's berry offers Take")
	st.action_button(&"take").pressed.emit()
	_expect(_index_of(uids["cargo_berry"]) >= 0 and player.bonded[0].bag.find_first(&"berry") < 0, "cargo: Take moved that berry into the bag")
	var picked: Array = []
	ui.call("open_picker", &"camp_stew", 2, func(p: Array) -> void: picked.append_array(p))
	var pk: ItemPicker = ui.get("_picker")
	_expect(ui.call("current_screen") == &"picker" and pk.chosen() == [_index_of(uids["berry12"])] and pk.warning_text() == "", "picker: the plain Lv. 12 berry is preselected, no warning")
	pk.choose(_index_of(uids["berry42"]))
	_expect(pk.warning_text().contains("Vivid Inspiration"), "picker: choosing the Lv. 42 berry warns (%s)" % pk.warning_text())
	pk.confirm()
	_expect(picked == [_index_of(uids["berry42"])] and ui.call("current_screen") == &"", "picker: Use returns exactly that berry and closes")
	print("[bagui] b3 storage=store,take,multi2,notice cargo=take picker=berry42 bag=%d/%d box=%d/%d" % [inv.used_slots(), inv.slot_count, storage_box.used_slots(), storage_box.slot_count])

## B4 performance (spec 13 s20; design gate P1): a full 142-slot bag opens in under 50 ms. Pads the
## bag to 142 / 142 with instances (traits on some, NEW on some), closes the family, then times
## open_bag() twice: the first open of the run (cold: the grain shader and the glyph caches are made
## on that first frame) and a second one (warm, every open after). Windowed, it also waits for the
## open's first drawn frame and times a frame of the world with the family closed beside it (vsync and
## the 3D world are in both). Returns [warm build us, warm frame us] (frame -1 headless).
func _measure_open142() -> Array:
	var inv := player.inventory
	inv.slot_count = 142
	inv.slots.resize(142)
	var k := 0
	while inv.used_slots() < 142:
		_add(&"ore" if k % 3 else &"raptor_bone", 10 + k % 50, {"firm": 1 + k % 5, "heavy": 2} if k % 4 == 0 else {}, "", k % 5 == 0)
		k += 1
	var windowed := DisplayServer.get_name() != "headless"
	var out := []
	for pass_name in ["cold", "warm"]:
		player.ui.call("hide_ui")
		await get_tree().process_frame
		var base := -1
		if windowed:
			await RenderingServer.frame_post_draw
			var b0 := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			base = Time.get_ticks_usec() - b0
		var t0 := Time.get_ticks_usec()
		player.ui.call("open_bag")
		var bag: BagScreen = player.ui.get("_bag")
		bag.grid.item_cells() # the grid is built (refresh is not deferred on open)
		var build := Time.get_ticks_usec() - t0
		var frame := -1
		if windowed:
			await RenderingServer.frame_post_draw
			frame = Time.get_ticks_usec() - t0
		print("[bagui] perf142 %s bag=%d/%d cells=%d build=%dus first_frame=%s world_frame=%s" % [pass_name, inv.used_slots(), inv.slot_count, bag.grid.cells().size(), build, ("%dus" % frame) if frame >= 0 else "headless", ("%dus" % base) if base >= 0 else "headless"])
		out = [build, frame]
	return out

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
		_check_gear()
		_check_b3()
		var perf: Array = await _measure_open142()
		_expect(int(perf[0]) < 50000, "a full 142-slot bag opens in under 50 ms (%d us)" % perf[0])
	if _fails.is_empty():
		print("[bagui] PASS bag=%d/%d new=%d locked=%d" % [inv.used_slots(), inv.slot_count, _flag_count(&"new"), _flag_count(&"locked")])
	get_tree().quit(0 if _fails.is_empty() else 1)
