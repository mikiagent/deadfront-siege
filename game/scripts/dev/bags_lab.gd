extends Node3D
## Spec 31 lab: bag types, bag levels, material-inherited storage, Pocket, the bag inspect panel
## with its comparison and the crafting preview, on the real bag and craft screens.
## Saves <shot-dir>/bags_<n>_<step>_<w>x<h>.png and prints one
## "[bags] RESULT base_cap=... bag_types=..." line measured live from the same code the game runs.
## Windowed: --resolution 1600x900 -- --lab=bags_lab --shot-dir=DIR (844x390 too; add
## --rendering-method gl_compatibility for the web renderer).

var _player: Player
var _out := ""
var _fails: PackedStringArray = []
## Every number the RESULT line prints, filled by the steps below.
var _m: Dictionary = {}
var _shot_n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	if _out == "":
		_out = OS.get_user_data_dir().path_join("bags")
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 30.0)
	_player = kit["player"]
	# The bag is a modal above the HUD, as in main.gd.
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	(_player.ui as Node).reparent(modals)
	World.player_name = "Milan"
	World.occupation = "Gatherer"
	_player.skills.trees["tailoring"] = {"level": 40, "xp": 0.0, "unlocked": []}
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	print("[bags] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fails.append(label)

func _run() -> void:
	await get_tree().create_timer(0.4).timeout
	_logic()
	await _ui_shots()
	_report()
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------------------------------------------------------------- the numbers

## The bag recipe whose output is `id` (data/recipes.json, filtered by Data.recipe_list).
func _recipe_for(id: StringName) -> Dictionary:
	for r in Data.recipe_list:
		if r is Dictionary and str((r.get("output", {}) as Dictionary).get("id", "")) == str(id):
			return r
	return {}

## A bag stocked with what `rec` needs, one count-1 instance per space (so Placement is by hand and
## nothing stacks), and the lead each recipe slot picks. Returns the picks.
func _stock(inv: Inventory, rec: Dictionary, lead_level: int, lead_attrs: Dictionary) -> Array[int]:
	var picks: Array[int] = []
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		var row: Dictionary = slots[i]
		var cat := StringName(str(row.get("category", "")))
		var def_id := &"raw_hide" if cat == &"green_hide" else (&"fibre_stalk" if cat == &"fibre" else &"twine")
		for n in int(row.get("count", 1)):
			var attrs: Dictionary = {}
			if bool(row.get("primary", false)) and picks.size() == i:
				attrs = lead_attrs
			# Placed straight into a free space: Inventory.add would stack them, and two picks of one
			# instance are not two instances a player could have chosen.
			var idx := -1
			for k in inv.slot_count:
				if inv.slots[k] == null:
					idx = k
					break
			if idx < 0:
				break
			inv.slots[idx] = ItemStack.make(def_id, 1, attrs, lead_level)
			if n == 0:
				picks.append(idx)
	inv.changed.emit()
	return picks

func _reload(inv: Inventory) -> Inventory:
	var back := Inventory.new(inv.base_slots)
	back.load_array(JSON.parse_string(JSON.stringify(inv.to_array())))
	back.extras_from_dict(JSON.parse_string(JSON.stringify(inv.extras_to_dict())))
	return back

func _logic() -> void:
	var inv := Inventory.new()
	_m["base_cap"] = inv.capacity()
	_check(inv.capacity() == 100 and inv.slot_count == 100, "a fresh survivor has 100 spaces (%d/%d)" % [inv.capacity(), inv.slot_count])
	_m["bag_types"] = BagDef.all().size()
	_check(BagDef.all().size() >= 4, "%d bag types are defined" % BagDef.all().size())

	# A basic bag worn, then a level-60 one: level is not capacity.
	inv.add(ItemStack.make(&"basic_bag", 1, {}, 1))
	inv.equip_at(inv.find_first(&"basic_bag"))
	var cap1: int = inv.capacity()
	_m["basic_l1"] = cap1
	var high := Inventory.new()
	high.add(ItemStack.make(&"basic_bag", 1, {}, 60))
	high.equip_at(0)
	_m["basic_l60"] = high.capacity()
	_check(cap1 == 100 + BagDef.base_capacity(&"basic_bag", 1), "a level-1 basic bag gives %d" % cap1)
	_check(high.capacity() == 100 + BagDef.base_capacity(&"basic_bag", 60) and high.capacity() > cap1, "a level-60 basic bag gives the level-60 curve value (%d), not 60" % high.capacity())

	# Two level-30 bags of different types: only the inherited/Pocket side differs.
	var plain := ItemStack.make(&"basic_bag", 1, {}, 30)
	var rich := ItemStack.make(&"specialized_storage_bag", 1, {"pocket": 3}, 30)
	_m["same_level_diff"] = int(BagCapacity.of_stack(rich).get("total", 0)) - int(BagCapacity.of_stack(plain).get("total", 0))
	_check(int(_m["same_level_diff"]) > 0, "two level-30 bags differ by material (%d)" % int(_m["same_level_diff"]))

	# Pocket: 6 per level, never from level alone.
	_m["pocket1"] = int(BagCapacity.of_stack(ItemStack.make(&"basic_bag", 1, {"pocket": 1}, 1)).get("pocket", 0))
	_m["pocket5"] = int(BagCapacity.of_stack(ItemStack.make(&"basic_bag", 1, {"pocket": 5}, 1)).get("pocket", 0))
	_m["pocket_level60"] = int(BagCapacity.of_stack(ItemStack.make(&"basic_bag", 1, {}, 60)).get("pocket", 0))
	_check(int(_m["pocket1"]) == 6 and int(_m["pocket5"]) == 30, "Pocket Lv1 = +6, Lv5 = +30 (%d, %d)" % [int(_m["pocket1"]), int(_m["pocket5"])])
	_check(int(_m["pocket_level60"]) == 0, "a plain level-60 bag has no Pocket")

	# Several compatible modifiers at once, each once; an incompatible one adds nothing.
	var multi := ItemStack.make(&"specialized_storage_bag", 1, {"pocket": 2, "capacity": 10, "fluffy": 4}, 20)
	var mb := BagCapacity.of_stack(multi)
	var mbase: int = BagDef.base_capacity(&"specialized_storage_bag", 20)
	var ok_multi := int(mb.get("pocket", 0)) == 12 and int(mb.get("capacity", 0)) == 10 \
		and int(mb.get("total", 0)) == mbase + 12 + 10 + int(mb.get("other", 0))
	_m["multi_mod_ok"] = 1 if ok_multi else 0
	_check(ok_multi, "Pocket 2 + capacity 10 + the type's modifier add once each (%s)" % mb)
	_check(not str(mb).contains("fluffy"), "an incompatible material attribute adds nothing")

	# Ten equip/unequip rounds return to the same capacities.
	var rep := Inventory.new()
	rep.add(ItemStack.make(&"basic_bag", 1, {"pocket": 2}, 15))
	var stable := true
	var with_bag := 0
	for i in 10:
		stable = stable and rep.equip_at(rep.find_first(&"basic_bag"))
		if i == 0:
			with_bag = rep.capacity()
		stable = stable and rep.capacity() == with_bag
		stable = stable and rep.unequip(&"accessory1") and rep.capacity() == 100
	_m["reequip_stable"] = 1 if stable else 0
	_m["reequip_cap"] = with_bag
	_check(stable, "ten equip/unequip rounds keep the same capacities (%d / 100)" % with_bag)

	# Overflow: a full bag refuses the unequip and loses nothing.
	var full := Inventory.new()
	full.add(ItemStack.make(&"basic_bag", 1, {}, 1))
	full.equip_at(0)
	var cap := full.slot_count
	while full.used_slots() < cap:
		full.add(ItemStack.make(&"stone", 1))
	var before_uids: Dictionary = full.uids()
	var refused := not full.unequip(&"accessory1")
	var lost := 0
	var after_uids: Dictionary = full.uids()
	for k in before_uids:
		lost += 0 if after_uids.has(k) else 1
	_m["overflow_blocked"] = 1 if refused and full.worn(&"accessory1") != null else 0
	_m["items_lost"] = lost
	_check(refused and full.worn(&"accessory1") != null, "an unequip that would overflow is refused")
	_check(lost == 0, "the refusal loses nothing (%d items lost, %d/%d used)" % [lost, full.used_slots(), full.slot_count])

	# Preview == result: the same function, the same numbers, and the worn total it promises.
	var rec := _recipe_for(&"basic_bag")
	var cinv := Inventory.new()
	var picks: Array[int] = _stock(cinv, rec, 25, {"pocket": 2})
	var prev: Dictionary = Crafting.bag_preview(cinv, rec, picks, _player)
	var out := Crafting.preview(cinv, rec, picks)
	var made := BagCapacity.of_stack(out)
	_m["preview_level"] = int(prev.get("level", -1))
	_m["preview_bonus"] = int(prev.get("bonus", -1))
	_m["crafted_bonus"] = int(made.get("total", -2))
	var worn := Inventory.new()
	worn.add(out)
	worn.equip_at(0)
	_m["crafted_worn"] = worn.capacity()
	var matches := out != null and int(prev.get("bonus", -1)) == int(made.get("total", -2)) \
		and int(prev.get("base", -1)) == int(made.get("base", -2)) \
		and int(prev.get("pocket", -1)) == int(made.get("pocket", -2)) \
		and int(prev.get("level", -1)) == out.level \
		and worn.capacity() == int(prev.get("total_capacity", -1))
	_m["preview_matches"] = 1 if matches else 0
	_check(matches, "preview Lv%d +%d == crafted +%d, worn %d == previewed %d" % [int(prev.get("level", -1)), int(prev.get("bonus", -1)), int(made.get("total", -2)), worn.capacity(), int(prev.get("total_capacity", -1))])
	_check(out != null and int(out.attributes.get("pocket", 0)) == 2, "the crafted bag inherits the picked hide's Pocket (%s)" % (out.attributes if out else {}))

	# Save/load of an equipped bag and its attributes.
	var save := Inventory.new()
	save.add(ItemStack.make(&"basic_bag", 1, {"pocket": 2}, 40))
	save.equip_at(0)
	for k in 6:
		save.add(ItemStack.make(&"raptor_bone", 1, {}, 1 + k))
	var back := _reload(save)
	var bw := back.worn(&"accessory1")
	var roundtrip := bw != null and bw.def_id == &"basic_bag" and bw.level == 40 \
		and int(bw.attributes.get("pocket", 0)) == 2 and back.capacity() == save.capacity() \
		and back.uids() == save.uids()
	_m["save_roundtrip"] = 1 if roundtrip else 0
	_m["save_cap"] = back.capacity()
	_check(roundtrip, "an equipped bag saves and loads its level, Pocket and capacity (%d -> %d)" % [save.capacity(), back.capacity()])

	# Cargo is a separate inventory and never joins the personal total.
	var cargo := Inventory.new(200)
	cargo.add(ItemStack.make(&"stone", 1))
	_m["cargo_separate"] = 1 if cargo.capacity() == 200 and back.capacity() == save.capacity() and int(BagCapacity.inventory_total(back).get("total", 0)) == save.capacity() else 0
	_check(int(_m["cargo_separate"]) == 1, "a 200-space cargo holds 200 and leaves the bag at %d" % back.capacity())

# ---------------------------------------------------------------- the screens

func _shot(step: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_fails.append("no viewport image for %s" % step)
		return
	var path := _out.path_join("bags_%02d_%s_%dx%d.png" % [_shot_n, step, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
	img.save_png(path)
	print("[bags] shot %s" % path)

## A bag worth inspecting sits in slot `idx`; the panel is opened the way a tap opens it.
func _inspect(idx: int) -> BagInspect:
	var ui := _player.ui
	ui._select(idx)
	ui._on_inspect_bag()
	return ui._bag_inspector

func _ui_shots() -> void:
	var ui := _player.ui
	var inv := _player.inventory
	# A starting kit: a small bag worn, a better one and a worse one in the bag, and the materials
	# for the basic bag so the craft screen has a real preview (all three are picked by hand).
	var worn_bag := ItemStack.make(&"basic_bag", 1, {}, 1)
	inv.add(worn_bag)
	inv.equip_at(inv.find_first(&"basic_bag"), &"accessory1")
	inv.add(ItemStack.make(&"specialized_storage_bag", 1, {"pocket": 2}, 30))
	inv.add(ItemStack.make(&"small_pouch", 1, {}, 1))
	for k in 8:
		inv.add(ItemStack.make(&"raptor_bone", 1, {}, 1 + k))
	inv.add(ItemStack.make(&"raw_hide", 2, {"pocket": 3}, 25))
	inv.add(ItemStack.make(&"fibre_stalk", 3, {}, 25))
	inv.add(ItemStack.make(&"twine", 1, {}, 25))
	ui.visible = true
	ui.rebuild()
	# 15: the Bag header reads used / capacity from the data, at once.
	_m["header_ok"] = 1 if str(ui._cap_label.text) == "%d / %d" % [inv.used_slots(), inv.capacity()] else 0
	_m["header_text"] = str(ui._cap_label.text)
	_check(int(_m["header_ok"]) == 1, "the Bag header reads %s (used / capacity)" % ui._cap_label.text)
	ui._select(inv.find_first(&"basic_bag"))
	await _shot("bag_screen")
	# §9: the panel for the spare bag against the worn one: level, breakdown, quality, durability,
	# and a green capacity change.
	var up := _inspect(inv.find_first(&"specialized_storage_bag"))
	await get_tree().process_frame
	_m["compare_shown"] = 1 if up.visible and up._compare.visible and str(up._compare.text).contains("Capacity change:") and up.shown_change > 0 else 0
	_m["compare_change"] = up.shown_change
	_m["panel_fits"] = 1 if up.shown_fits else 0
	_check(up.shown_fits, "the inspect panel fits the screen with its Close button (%s in %s)" % [str(up.size), str(get_viewport().get_visible_rect().size)])
	_m["panel_close_px"] = up._close_btn.size.y if up._close_btn.size.y > 0.0 else up.shown_min_px
	_check(int(_m["compare_shown"]) == 1, "the panel compares against the worn bag (%s)" % str(up._compare.text).replace("\n", " | "))
	_check(str(up._body.text).contains("Level 30") and str(up._body.text).contains("Storage Capacity: +%d" % int(up.shown_breakdown.get("total", 0))), "the panel shows level and storage capacity (%s)" % str(up._body.text).replace("\n", " | "))
	await _shot("inspect_upgrade")
	# The same panel for a worse bag: the change line turns to the warning colour.
	var down := _inspect(inv.find_first(&"small_pouch"))
	await get_tree().process_frame
	var down_color := down._compare.get_theme_color("font_color")
	_m["compare_down"] = down.shown_change
	_check(down.visible and down.shown_change < 0 and down_color == Color(BagInspect.DOWN), "a smaller bag reads %+d in the warning colour" % down.shown_change)
	await _shot("inspect_downgrade")
	down.hide_panel()
	# 64 px (or the 44 px floor) tap targets on the bag screen and its panel.
	var cell_px := _player.ui._slot_px
	_m["bag_cell_px"] = cell_px
	_m["ui_min_px"] = minf(minf(float(_m["panel_close_px"]), cell_px), float(up.shown_min_px))
	_check(float(_m["ui_min_px"]) >= (64.0 if UiTokens.is_compact(get_viewport().get_visible_rect().size) else 44.0), "bag cells and panel buttons are %.0f px targets" % float(_m["ui_min_px"]))
	# §10: the craft screen previews the bag from the same function the craft uses. The bag screen sits
	# on the modal layer above craft_ui, so it is closed first or the shot shows two screens at once.
	up.hide_panel()
	ui.visible = false
	_player.craft_ui.show_ui()
	_player.craft_ui._choose_recipe("basic_bag")
	await get_tree().process_frame
	var label := _find_named(_player.craft_ui, "DetailBagPreview") as Label
	var prev: Dictionary = Crafting.bag_preview(inv, _recipe_for(&"basic_bag"), Crafting.default_picks(inv, _recipe_for(&"basic_bag")), _player)
	_m["preview_ui_ok"] = 1 if label != null and str(label.text).contains("Final storage: +%d" % int(prev.get("bonus", -1))) and str(label.text).contains("Worn bag capacity: %d" % int(prev.get("total_capacity", -1))) else 0
	_check(int(_m["preview_ui_ok"]) == 1, "the craft screen previews final storage +%d and worn capacity %d (%s)" % [int(prev.get("bonus", -1)), int(prev.get("total_capacity", -1)), (str(label.text).replace("\n", " | ") if label else "no label")])
	await _shot("craft_preview")

func _find_named(n: Node, name_: String) -> Node:
	if n.name == name_:
		return n
	for c in n.get_children():
		var hit := _find_named(c, name_)
		if hit != null:
			return hit
	return null

func _report() -> void:
	var keys := ["base_cap", "bag_types", "same_level_diff", "pocket1", "pocket5", "pocket_level60",
		"multi_mod_ok", "reequip_stable", "reequip_cap", "overflow_blocked", "items_lost",
		"preview_level", "preview_bonus", "crafted_bonus", "crafted_worn", "preview_matches",
		"save_roundtrip", "save_cap", "header_ok", "cargo_separate", "compare_shown",
		"compare_change", "panel_fits", "compare_down", "preview_ui_ok", "ui_min_px", "bag_cell_px", "panel_close_px"]
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s=%s" % [k, str(_m.get(k, 0))])
	if _fails.is_empty():
		print("[bags] RESULT %s" % " ".join(parts))
		print("[bags] PASS shots=%d dir=%s" % [_shot_n, _out])
	else:
		print("[bags] RESULT %s" % " ".join(parts))
		print("[bags] FAIL count=%d: %s" % [_fails.size(), ", ".join(_fails)])
