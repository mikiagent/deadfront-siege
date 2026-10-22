extends Node3D
## CRAFTFEEL lab (plan §3.3 "Crafting", P7; specs 04, 08, 25 §8): a craft has stakes, shown on the
## real craft screen. Measures the success curve, a failure's material loss, the flawless and rare
## trait rates over 2000 seeded crafts, the skewer's Food + Tool slots, preview vs result and the
## once-paid craft XP, saves shots of the preview, a failure and a flawless result, prints one
##   [craftfeel] RESULT success_curve_ok= fail_consumes= flawless_rate= rare_trait_rate= skewer_slots_ok=
##   preview_matches= xp_once= ui_min_px=
## line and quits. Every number is measured from the live scene, never written as a constant.
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=craftfeel_lab --shot-dir=DIR

const CRAFTS := 2000

var _player: Player
var _fire: Bonfire
var _out := ""
var _rng := RandomNumberGenerator.new()
var _shot_n := 0
var _shots: Array[String] = []
var _m := {
	"success_curve_ok": 0, "fail_consumes": 0, "flawless_rate": 0.0, "rare_trait_rate": 0.0,
	"skewer_slots_ok": 0, "preview_matches": 0, "xp_once": 0, "ui_min_px": 0.0,
}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	if _out == "":
		_out = OS.get_user_data_dir().path_join("craftfeel")
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 30.0)
	_player = kit["player"]
	_fire = Bonfire.make(&"bonfire")
	_fire.position = Vector3(1.5, 0, 0.5)
	add_child(_fire)
	World.player_name = "Milan"
	_player.skills.trees["cooking"] = {"level": 12, "xp": 0.0, "unlocked": []}
	_player.skills.trees["processing"] = {"level": 12, "xp": 0.0, "unlocked": []}
	_run.call_deferred()

func _run() -> void:
	_rng.seed = 20261022
	# Watchdog: the gate kills the lab at 900 s; quit by 120 s whatever happens.
	get_tree().create_timer(110.0).timeout.connect(func () -> void:
		print("[craftfeel] watchdog quit")
		_finish())
	await get_tree().create_timer(0.5).timeout
	await get_tree().physics_frame
	_measure_curve()
	_measure_fail()
	_measure_rates()
	_measure_skewer()
	_measure_preview()
	_measure_xp()
	await _shots_and_ui()
	_finish()

# ---------------------------------------------------------------- numbers

## A lab recipe: no station, one material slot, the ability requirement the caller names.
func _rec(required: float, extra: Dictionary = {}) -> Dictionary:
	var rec := {
		"id": "craftfeel_probe", "display_name": "Craftfeel Probe", "skill": "processing", "max_level": 60,
		"slots": [{"category": "blade_mat", "count": 1, "primary": true}],
		"output": {"id": "stone_knife", "count": 1}, "seconds": 1.0, "process_step": "knap",
	}
	if required > 0.0:
		rec["required_ability"] = required
	rec.merge(extra, true)
	return rec

func _clear_bag() -> void:
	for i in _player.inventory.slot_count:
		if _player.inventory.slots[i] != null:
			_player.inventory.remove_at(i, 999)
	_player.inventory.changed.emit()

func _units() -> int:
	var n := 0
	for s in _player.inventory.slots:
		if s != null:
			n += s.count
	return n

## Spec 04's curve at shortfall 0 / 50 / 100, read through the function the craft itself rolls.
func _measure_curve() -> void:
	var rec := _rec(100.0)
	var at0 := Crafting.success_chance(rec, 100.0)
	var at50 := Crafting.success_chance(rec, 50.0)
	var at100 := Crafting.success_chance(rec, 0.0)
	var open := Crafting.success_chance(_rec(0.0), 0.0)
	print("[craftfeel] curve 0=%.3f 50=%.3f 100=%.3f no_requirement=%.3f" % [at0, at50, at100, open])
	_m["success_curve_ok"] = 1 if is_equal_approx(at0, 1.0) and is_equal_approx(at50, 0.75) and is_equal_approx(at100, 0.0) and is_equal_approx(open, 1.0) else 0

## A failed craft spends the picked instances exactly once and makes nothing (spec 25 §8).
func _measure_fail() -> void:
	_clear_bag()
	_player.inventory.add(ItemStack.make(&"stone", 2, {}, 8))
	_player.inventory.add(ItemStack.make(&"twine", 1, {}, 8))
	var rec := _rec(0.0, {"slots": [
		{"category": "blade_mat", "count": 1, "primary": true},
		{"category": "lashing", "count": 1, "primary": false},
	]})
	# An outcome the roll cannot fake: the craft path is asked, with the failure already rolled.
	var picks := Crafting.default_picks(_player.inventory, rec)
	var made: ItemStack = Crafting.commit_outcome(_player, rec, picks, {"success": false, "flawless": false, "rare": &""})
	var stone := _player.inventory.count_of(&"stone")
	var twine := _player.inventory.count_of(&"twine")
	var knives := _player.inventory.count_of(&"stone_knife")
	print("[craftfeel] fail made=%s stone=%d twine=%d knives=%d" % [made == null, stone, twine, knives])
	_m["fail_consumes"] = 1 if made == null and stone == 1 and twine == 0 and knives == 0 else 0

## Plan 3.3: flawless 5 %, rare trait 5 %, both within ±2 pp over 2000 seeded crafts.
func _measure_rates() -> void:
	var rec := _rec(0.0)
	var primary := ItemStack.make(&"stone", 1, {}, 10)
	var flawless := 0
	var rare := 0
	for i in CRAFTS:
		var o := Crafting.roll_outcome(rec, _player, primary, _rng)
		flawless += 1 if bool(o["flawless"]) else 0
		rare += 1 if str(o["rare"]) != "" else 0
	var f := float(flawless) / float(CRAFTS)
	var r := float(rare) / float(CRAFTS)
	print("[craftfeel] rates flawless=%d/%d (%.4f) rare=%d/%d (%.4f) targets %.3f/%.3f" % [flawless, CRAFTS, f, rare, CRAFTS, r, Crafting.flawless_chance(), float(Data.world_rules.get("rare_attribute_chance", 0.05))])
	var target_f := Crafting.flawless_chance()
	var target_r := float(Data.world_rules.get("rare_attribute_chance", 0.05))
	_m["flawless_rate"] = f if absf(f - target_f) <= 0.02 else -1.0
	_m["rare_trait_rate"] = r if absf(r - target_r) <= 0.02 else -1.0

## Spec 25 §8: Food slot (meat) + Tool slot (a stick or a leg bone), through the plan the craft uses.
func _measure_skewer() -> void:
	_clear_bag()
	var rec := Crafting.recipe(&"skewer")
	var slots: Array = rec.get("slots", [])
	var roles_ok: bool = slots.size() == 2 and str(slots[0].get("role", "")) == "food" and str(slots[1].get("role", "")) == "tool"
	var allowed: Array = slots[1].get("allowed_ids", []) if slots.size() > 1 else []
	_player.inventory.add(ItemStack.make(&"raw_meat", 1, {}, 10))
	_player.inventory.add(ItemStack.make(&"club", 1, {}, 4))
	var club_ok: bool = not Crafting.picks_valid(_player.inventory, rec, Crafting.default_picks(_player.inventory, rec))
	_player.inventory.remove_at(_player.inventory.find_first(&"club"), 1)
	_player.inventory.add(ItemStack.make(&"raptor_bone", 1, {}, 12))
	var bone_ok: bool = Crafting.picks_valid(_player.inventory, rec, Crafting.default_picks(_player.inventory, rec))
	print("[craftfeel] skewer roles=%s allowed=%s club_refused=%s bone_ok=%s" % [roles_ok, allowed, club_ok, bone_ok])
	_m["skewer_slots_ok"] = 1 if roles_ok and "branch" in allowed and "raptor_bone" in allowed and club_ok and bone_ok else 0

## The card's numbers are the craft's numbers: preview level and inherited traits vs the result.
func _measure_preview() -> void:
	_clear_bag()
	var meat := ItemStack.make(&"raptor_meat", 1, {"firm": 3, "pointy": 2}, 30)
	_player.inventory.add(meat)
	_player.inventory.add(ItemStack.make(&"branch", 1, {"firm": 4}, 30))
	var rec := Crafting.recipe(&"skewer")
	var picks := Crafting.default_picks(_player.inventory, rec)
	var primary: ItemStack = _player.inventory.slots[picks[Crafting.primary_index(rec)]]
	var qual := Crafting.preview_quality(rec, _player, primary)
	var shown := Crafting.preview(_player.inventory, rec, picks)
	var out := Crafting.commit_outcome(_player, rec, picks, {"success": true, "flawless": false, "rare": &""})
	var same_level: bool = out != null and shown != null and out.level == shown.level
	var traits_same: bool = out != null and "firm" in (qual["inherited"] as Array) and int(out.attributes.get("firm", 0)) > 0
	var chance_same: bool = is_equal_approx(float(qual["success"]), Crafting.success_for(rec, _player))
	print("[craftfeel] preview level=%s result=%s success=%.3f flawless=%.3f traits=%s" % [
		shown.level if shown else -1, out.level if out else -1, float(qual["success"]), float(qual["flawless"]), qual["inherited"]])
	_m["preview_matches"] = 1 if same_level and traits_same and chance_same else 0

## Craft XP is paid once per craft, on the recipe's own tree.
func _measure_xp() -> void:
	_clear_bag()
	_player.inventory.add(ItemStack.make(&"raptor_meat", 1, {}, 10))
	_player.inventory.add(ItemStack.make(&"branch", 1, {}, 10))
	var rec := Crafting.recipe(&"skewer")
	var want := 6.0 + float(Crafting.recipe_seconds(rec))
	var before := _player.skills.xp_of("cooking")
	var first := Crafting.commit_outcome(_player, rec, Crafting.default_picks(_player.inventory, rec), {"success": true, "flawless": false, "rare": &""})
	var paid := _player.skills.xp_of("cooking") - before
	# A second attempt with no materials must pay nothing (no repeat XP).
	Crafting.commit_outcome(_player, rec, Crafting.default_picks(_player.inventory, rec), {"success": true, "flawless": false, "rare": &""})
	var after_second := _player.skills.xp_of("cooking") - before
	print("[craftfeel] xp want=%.1f paid=%.1f after_second=%.1f" % [want, paid, after_second])
	_m["xp_once"] = 1 if first != null and is_equal_approx(paid, want) and is_equal_approx(after_second, want) else 0

# ---------------------------------------------------------------- the screen

func _shots_and_ui() -> void:
	await _preview_screen()
	await _shot("preview")
	await _failure_screen()
	await _shot("failure")
	await _flawless_screen()
	await _shot("flawless")
	print("[craftfeel] shots %s" % [_shots])

## The craft screen on the skewer: success %, flawless %, inherited traits, the loss warning.
func _preview_screen() -> void:
	_clear_bag()
	_player.inventory.add(ItemStack.make(&"raptor_meat", 1, {"firm": 3, "pointy": 2}, 30))
	_player.inventory.add(ItemStack.make(&"branch", 1, {"firm": 4}, 30))
	_player.global_position = _fire.global_position + Vector3(1.6, 0, 1.2)
	_player.face_world(_fire.global_position)
	var ui: CraftUI = _player.craft_ui
	ui.show_for_station(&"bonfire")
	ui._choose_recipe("skewer")
	await get_tree().process_frame
	await get_tree().process_frame
	_m["ui_min_px"] = _measure_targets()
	print("[craftfeel] ui min target %.0f px at %s" % [float(_m["ui_min_px"]), str(get_viewport().get_visible_rect().size)])

func _failure_screen() -> void:
	await _preview_screen()
	_player.craft_ui.hide_ui()
	# A craft that cannot succeed, through the ordinary path: the materials are lost.
	var rec := _rec(1000.0)
	_player.inventory.add(ItemStack.make(&"stone", 1, {}, 8))
	var before := _units()
	var made := Crafting.craft(_player, rec, Crafting.default_picks(_player.inventory, rec), _rng)
	print("[craftfeel] failure screen made=%s units %d -> %d" % [made, before, _units()])
	await get_tree().process_frame

func _flawless_screen() -> void:
	_clear_bag()
	_player.global_position = _fire.global_position + Vector3(1.0, 0, 0.6)
	await get_tree().physics_frame
	var meat := ItemStack.make(&"raptor_meat", 1, {"firm": 3}, 20)
	_player.inventory.add(meat)
	_player.inventory.add(ItemStack.make(&"branch", 1, {}, 20))
	var rec := Crafting.recipe(&"skewer")
	var out := Crafting.commit_outcome(_player, rec, Crafting.default_picks(_player.inventory, rec), {"success": true, "flawless": true, "rare": &"black_sheen"})
	print("[craftfeel] flawless item=%s level=%d flags=%s quality=%s" % [out.def_id if out else "none", out.level if out else -1, out.flags if out else [], out.attributes.get("quality", "") if out else ""])
	var ui: InventoryUI = _player.ui
	ui.visible = true
	ui.rebuild()
	await get_tree().process_frame
	var idx := _player.inventory.find_first(&"skewer")
	ui._select(idx)
	ui._on_inspect_food()
	await get_tree().process_frame

## The smallest visible tap target of the craft screen (phones need 64 px, desktop 44 px).
func _measure_targets() -> float:
	var small := INF
	for n in _player.craft_ui.find_children("*", "Button", true, false):
		var b := n as Button
		if b and b.is_visible_in_tree() and b.size.x > 0.0 and b.size.y > 0.0:
			var px := minf(b.size.x, b.size.y)
			if px < 64.0:
				print("[craftfeel] small target %.0f px: %s %s" % [px, b.name, b.text.replace("\n", " ")])
			small = minf(small, px)
	return 0.0 if small == INF else small

func _shot(step: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var path := _out.path_join("craftfeel_%02d_%s_%dx%d.png" % [_shot_n, step, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
	img.save_png(path)
	_shots.append(path)
	print("[craftfeel] shot %s" % path)

func _finish() -> void:
	print("[craftfeel] RESULT success_curve_ok=%d fail_consumes=%d flawless_rate=%.4f rare_trait_rate=%.4f skewer_slots_ok=%d preview_matches=%d xp_once=%d ui_min_px=%d" % [
		int(_m["success_curve_ok"]), int(_m["fail_consumes"]), float(_m["flawless_rate"]), float(_m["rare_trait_rate"]),
		int(_m["skewer_slots_ok"]), int(_m["preview_matches"]), int(_m["xp_once"]), int(_m["ui_min_px"])])
	get_tree().quit(0 if int(_m["success_curve_ok"]) == 1 and int(_m["fail_consumes"]) == 1 and int(_m["skewer_slots_ok"]) == 1 and int(_m["preview_matches"]) == 1 and int(_m["xp_once"]) == 1 else 1)
