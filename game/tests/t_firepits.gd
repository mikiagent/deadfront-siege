extends SceneTree
## FIREPITS acceptance (owner rules 2026-10-28): the permanent stone fire pit shows no wood and no
## flame until wood is loaded, burns while the fuel lasts and goes cold again when it runs out (the
## rocks stay); the temporary bonfire and campfire show wood and flame from placement, burn out after
## their fuel time, wear out over time and twice as fast outside a Domain, and are removed when burnt
## out or at 0 durability; cooking works only while the fire burns; fuel, burning and durability
## survive save/load, and an older save without those fields still loads.
## Run: Godot --headless --path game --script res://tests/t_firepits.gd -> "[t_firepits] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

class FakeRuntime:
	extends Node3D
	## Stands in for IslandRuntime's claim check (BuildGrid.can_place / BuildPlacer._on_owned_land).
	var claimed: bool = true
	func is_claimed(_tile: Vector2i) -> bool:
		return claimed

var _fails: PackedStringArray = []
var _started := false
var _done := false
var _host: Node3D
var _player: Node3D
var _world: Node
var _fake: Node3D
var _rng := RandomNumberGenerator.new()
var B: GDScript
var SM: GDScript
var IS: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_firepits] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _finish() -> void:
	if _done:
		return
	_done = true
	if _world != null and is_instance_valid(_world):
		_world.runtime = null
	if _fails.is_empty():
		print("[t_firepits] PASS")
	else:
		print("[t_firepits] FAIL count=%d: %s" % [_fails.size(), "; ".join(_fails)])
	quit(0 if _fails.is_empty() else 1)

func _run() -> void:
	B = load("res://scripts/world/bonfire.gd")
	SM = load("res://scripts/ui/station_menu.gd")
	IS = load("res://scripts/items/item_stack.gd")
	_host = Node3D.new()
	_host.name = "TFireHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_world = root.get_node("World")
	_fake = FakeRuntime.new()
	_fake.name = "TFireRuntime"
	_host.add_child(_fake)
	_world.runtime = _fake
	create_timer(60.0).timeout.connect(func () -> void:
		_expect(false, "watchdog: the test did not finish in 60 s")
		_finish())
	_test_pit_empty()
	_test_pit_wood()
	await _test_fuel_logs()
	_test_temporary_lit()
	_test_burn_out()
	_test_wear_inside_and_outside()
	_test_cooking_gate()
	await _test_info_lines()
	_test_save_load()
	_test_sanitized_save()
	_finish()

## A fire with its config applied as the game places it, inside `host` so queue_free works.
func _fire(kind: StringName) -> StaticBody3D:
	var f: StaticBody3D = B.make(kind)
	f.position = Vector3(0, 0, 0)
	_host.add_child(f)
	return f

func _wood_log() -> void:
	_player.inventory.consume(&"branch", _player.inventory.count_of(&"branch"))
	_player.inventory.add(IS.make(&"branch", 6))

# ---------------------------------------------------------------- stone fire pit: permanent

func _test_pit_empty() -> void:
	var pit := _fire(&"stone_fire_pit")
	_expect(pit.get("kind") == &"stone_fire_pit", "the pit keeps its kind")
	_expect(float(pit.get("fuel_seconds")) <= 0.0, "an empty pit holds no fuel")
	_expect(not bool(pit.call("burning")), "an empty pit is not burning")
	_expect(not bool(pit.call("wood_visible")), "an empty pit hides its wood")
	_expect(not bool(pit.call("flame_visible")), "an empty pit shows no flame")
	_expect(bool(pit.call("is_permanent")), "the pit is permanent")
	pit.call("tick", 3600.0)
	_expect(is_instance_valid(pit) and not pit.is_queued_for_deletion(), "a cold pit never decays or is removed")
	_expect(is_equal_approx(float(pit.get("durability")), 0.0), "a permanent pit carries no wear durability")
	pit.queue_free()

func _test_pit_wood() -> void:
	_wood_log()
	var pit := _fire(&"stone_fire_pit")
	var before: int = _player.inventory.count_of(&"branch")
	var added: float = pit.call("load_wood", _player)
	var after: int = _player.inventory.count_of(&"branch")
	print("[t_firepits] pit load_wood added=%.0fs branches %d->%d fuel=%.0fs" % [added, before, after, float(pit.get("fuel_seconds"))])
	_expect(added > 0.0 and after < before, "loading wood spends wood and adds fuel")
	_expect(bool(pit.call("burning")), "a loaded pit burns")
	_expect(bool(pit.call("wood_visible")), "a loaded pit shows its wood")
	_expect(bool(pit.call("flame_visible")), "a loaded pit shows a flame")
	# Fuel out: the wood goes, the flame goes, the pit stays.
	var fuel := float(pit.get("fuel_seconds"))
	pit.call("tick", fuel + 0.5)
	print("[t_firepits] pit after fuel out burning=%s wood=%s flame=%s alive=%s" % [
		bool(pit.call("burning")), bool(pit.call("wood_visible")), bool(pit.call("flame_visible")), not pit.is_queued_for_deletion()])
	_expect(not bool(pit.call("burning")), "a pit with no fuel left is not burning")
	_expect(not bool(pit.call("wood_visible")), "the wood disappears when the pit's fuel runs out")
	_expect(not bool(pit.call("flame_visible")), "the flame goes out when the pit's fuel runs out")
	_expect(not pit.is_queued_for_deletion(), "the rocks of the pit stay")
	# Loading again relights it.
	pit.call("load_wood", _player)
	_expect(bool(pit.call("burning")) and bool(pit.call("wood_visible")), "loading wood again relights the pit")
	pit.queue_free()

## FIREFUEL (owner 2026-10-28): branch +1 min, log +5 min, 10 min max; the pit draws one log per
## minute left (ceil), 0 when out; the state reads roaring / burning / low / out as it runs down.
func _test_fuel_logs() -> void:
	_player.inventory.consume(&"wood_log", _player.inventory.count_of(&"wood_log"))
	_player.inventory.add(IS.make(&"wood_log", 4))
	_wood_log()
	var pit := _fire(&"stone_fire_pit")
	_expect(int(pit.call("logs_shown")) == 0 and int(pit.call("visible_log_count")) == 0 and pit.call("fuel_state") == &"out", "an empty pit draws 0 logs and reads out")
	var g1: float = pit.call("add_fuel", _player, &"branch")
	_expect(is_equal_approx(g1, 60.0) and int(pit.call("visible_log_count")) == 1, "a branch adds 1 min and draws 1 log")
	var g2: float = pit.call("add_fuel", _player, &"wood_log")
	_expect(is_equal_approx(g2, 300.0) and int(pit.call("visible_log_count")) == 6, "a log adds 5 min (6 min: 6 logs)")
	pit.call("add_fuel", _player, &"wood_log")
	var logs_before: int = _player.inventory.count_of(&"wood_log")
	var g3: float = pit.call("add_fuel", _player, &"wood_log")
	print("[t_firepits] fuel full=%.0fs logs=%d state=%s refused=%.0f" % [float(pit.get("fuel_seconds")), int(pit.call("visible_log_count")), pit.call("fuel_state"), g3])
	_expect(is_equal_approx(float(pit.get("fuel_seconds")), 600.0), "fuel caps at 10 min")
	_expect(g3 == 0.0 and _player.inventory.count_of(&"wood_log") == logs_before, "a full fire refuses wood and keeps it in the bag")
	_expect(int(pit.call("visible_log_count")) == 10 and pit.call("fuel_state") == &"roaring", "a full fire draws 10 logs and roars")
	# Burn down a minute at a time: the drawn logs follow ceil(minutes left).
	var match_all := true
	var states := {}
	for m in range(10, 0, -1):
		var want := m
		var got: int = pit.call("visible_log_count")
		states[m] = pit.call("fuel_state")
		if got != want or int(pit.call("logs_shown")) != want:
			match_all = false
			print("[t_firepits] at %d min drawn=%d" % [m, got])
		pit.call("tick", 30.0)
		if int(pit.call("visible_log_count")) != want:  # mid-minute still shows the started minute
			match_all = false
		pit.call("tick", 30.0)
	print("[t_firepits] states by minute %s" % str(states))
	_expect(match_all, "every minute the pit draws ceil(minutes left) logs, 10 down to 1")
	_expect(states[10] == &"roaring" and states[5] == &"burning" and states[2] == &"low" and states[1] == &"low", "the fire reads roaring, then burning, then low as it runs down")
	_expect(int(pit.call("visible_log_count")) == 0 and not bool(pit.call("wood_visible")) and not bool(pit.call("flame_visible")) and pit.call("fuel_state") == &"out", "burnt out: 0 logs, no flame")
	var fx_on := false
	for e in pit.find_children("*", "CPUParticles3D", true, false):
		fx_on = fx_on or (e as CPUParticles3D).emitting
	_expect(not fx_on, "an out fire emits no flame particles")
	pit.call("add_fuel", _player, &"wood_log")
	var emitting := 0
	for e in pit.find_children("*", "CPUParticles3D", true, false):
		emitting += 1 if (e as CPUParticles3D).emitting else 0
	_expect(emitting >= 3, "a lit fire runs its flame, ember and smoke particles (%d emitting)" % emitting)
	var big: float = (pit.get("_flame") as Node3D).scale.y
	pit.call("tick", 240.0)
	pit.call("_process", 0.0)
	var small: float = (pit.get("_flame") as Node3D).scale.y
	_expect(small < big, "the flame shrinks as the fuel runs low (%.2f -> %.2f)" % [big, small])
	# Save round trip: the fuel (and so the logs) come back.
	pit.set("fuel_seconds", 270.0)
	pit.call("_sync_fire_nodes")
	var back: StaticBody3D = B.from_dict(pit.call("to_dict"))
	_host.add_child(back)
	print("[t_firepits] save fuel=%.0f logs %d -> %d" % [float(back.get("fuel_seconds")), int(pit.call("visible_log_count")), int(back.call("visible_log_count"))])
	_expect(int(back.call("visible_log_count")) == 5 and is_equal_approx(float(back.get("fuel_seconds")), 270.0), "4:30 of fuel saves and loads as 5 logs")
	# The fuel sheet shows the same slots and feeds the fire.
	var hud: Node = get_first_node_in_group("hud")
	_expect(hud != null and hud.has_method("open_fire_fuel"), "the HUD opens a fire's fuel sheet")
	if hud != null:
		var sheet: Variant = hud.call("open_fire_fuel", back, _player)
		_expect(int(sheet.call("filled_slots")) == 5, "the fuel sheet fills 5 of 10 slots at 4:30")
		var gained: float = sheet.call("add", &"branch")
		_expect(gained > 0.0 and int(sheet.call("filled_slots")) == 6, "a branch from the sheet adds a minute and a slot")
		await process_frame
		await process_frame
		var lo := INF
		for b: Button in UiWorldSheet.buttons_in(sheet):
			print("[t_firepits] sheet button %s %s" % [b.name, str(b.get_global_rect().size)])
			lo = minf(lo, minf(b.size.x, b.size.y))
		_expect(lo >= 64.0 - 0.5, "every fuel sheet button is a 64 px tap target (%.0f)" % lo)
		sheet.call("close")
	back.queue_free()
	pit.queue_free()

# ---------------------------------------------------------------- bonfire / campfire: temporary

func _test_temporary_lit() -> void:
	for kind in [&"bonfire", &"campfire"]:
		var f := _fire(kind)
		print("[t_firepits] %s at placement fuel=%.0fs durability=%.0f/%.0f burning=%s" % [
			kind, float(f.get("fuel_seconds")), float(f.get("durability")), float(f.get("max_durability")), bool(f.call("burning"))])
		_expect(float(f.get("fuel_seconds")) > 0.0, "%s starts with a load of fuel" % kind)
		_expect(bool(f.call("burning")), "%s burns from placement" % kind)
		_expect(bool(f.call("wood_visible")), "%s shows its wood from placement" % kind)
		_expect(bool(f.call("flame_visible")), "%s shows a flame from placement" % kind)
		_expect(float(f.get("max_durability")) > 0.0 and is_equal_approx(float(f.get("durability")), float(f.get("max_durability"))), "%s starts at full durability" % kind)
		f.queue_free()

func _test_burn_out() -> void:
	var fuel_secs := 0.0
	for kind in [&"bonfire", &"campfire"]:
		var f := _fire(kind)
		var fuel := float(f.get("fuel_seconds"))
		# Just before the fuel time it still burns; past it the fire is spent and gone.
		f.call("tick", maxf(0.0, fuel - 1.0))
		_expect(not f.is_queued_for_deletion(), "%s still burns just before its fuel time" % kind)
		f.call("tick", 2.0)
		fuel_secs = fuel
		print("[t_firepits] %s burnt out after %.0fs queued=%s" % [kind, fuel, f.is_queued_for_deletion()])
		_expect(f.is_queued_for_deletion(), "%s is removed after its fuel time" % kind)
	if fuel_secs <= 0.0:
		_expect(false, "a temporary fire has a fuel time (docs give none: data value)")

func _test_wear_inside_and_outside() -> void:
	# Inside a Domain.
	(_fake as FakeRuntime).claimed = true
	var inside := _fire(&"bonfire")
	var h0 := float(inside.get("durability"))
	inside.call("tick", 60.0)
	var inside_loss := h0 - float(inside.get("durability"))
	_expect(inside_loss > 0.0, "a temporary fire wears down over time (inside a Domain lost %.1f/min)" % inside_loss)
	inside.queue_free()
	# Outside a Domain.
	(_fake as FakeRuntime).claimed = false
	var outside := _fire(&"bonfire")
	var h1 := float(outside.get("durability"))
	outside.call("tick", 60.0)
	var outside_loss := h1 - float(outside.get("durability"))
	print("[t_firepits] wear per minute inside=%.2f outside=%.2f ratio=%.2f" % [inside_loss, outside_loss, outside_loss / maxf(0.001, inside_loss)])
	_expect(is_equal_approx(outside_loss, inside_loss * 2.0), "a fire outside a Domain wears twice as fast")
	# At 0 durability the fire is gone, even with fuel left.
	outside.set("durability", 0.5)
	var had_fuel := float(outside.get("fuel_seconds")) > 0.0
	outside.call("tick", 30.0)
	print("[t_firepits] fire at 0 durability had_fuel=%s queued=%s" % [had_fuel, outside.is_queued_for_deletion()])
	_expect(had_fuel and outside.is_queued_for_deletion(), "a temporary fire at 0 durability is removed")
	(_fake as FakeRuntime).claimed = true

func _test_cooking_gate() -> void:
	var sc0: Variant = _player.get("station_craft")
	var menu: Variant = sc0.get("menu") if sc0 != null else null
	var pit := _fire(&"stone_fire_pit")
	_expect(not bool(pit.call("can_cook")), "a cold pit cannot cook")
	_expect(str(pit.call("cook_block_reason")) != "", "a cold pit says why cooking is refused")
	var actions: Array = SM.actions_for(&"bonfire", _player)
	var cold: Array = SM.filter_actions(pit, actions)
	var cook_off := true
	for a: Variant in cold:
		if str((a as Dictionary).get("id", "")) == "cook":
			cook_off = false
	_expect(cook_off, "the cold pit's menu offers no COOK")
	_wood_log()
	pit.call("load_wood", _player)
	_expect(bool(pit.call("can_cook")), "a burning pit can cook")
	var hot: Array = SM.filter_actions(pit, actions)
	var cook_on := false
	for a: Variant in hot:
		if str((a as Dictionary).get("id", "")) == "cook":
			cook_on = true
	_expect(cook_on, "a burning pit's menu offers COOK")
	# The menu itself refuses a COOK press on a fire that is not burning (even if a hex is built by
	# hand) and never emits the action, and pressing LOAD WOOD lights the pit from the menu.
	if menu != null:
		var emitted: Array = []
		menu.action_chosen.connect(func (st: Node3D, aid: StringName) -> void: emitted.append(str(aid)))
		var cold_pit := _fire(&"stone_fire_pit")
		menu.call("show_for", cold_pit, [{"id": &"cook", "label": "COOK"}])
		menu.call("_on_pressed", &"cook")
		_expect(emitted.is_empty(), "a COOK press on a cold pit emits nothing")
		_wood_log()
		menu.call("show_for", cold_pit, [{"id": &"wood", "label": "FUEL"}])
		menu.call("_on_pressed", &"wood")
		# FIREFUEL: FUEL opens the fire's fuel sheet; its Branch button lights the pit.
		var hud: Node = get_first_node_in_group("hud")
		var sheet: Variant = hud.get("_world_sheets").get(&"fire_fuel") if hud != null else null
		_expect(sheet != null and bool(sheet.call("is_open")) and sheet.get("fire") == cold_pit, "FUEL from the menu opens the fire's fuel sheet")
		if sheet != null:
			sheet.call("add", &"branch")
			sheet.call("close")
		_expect(float(cold_pit.get("fuel_seconds")) > 0.0 and bool(cold_pit.call("can_cook")), "a branch from the fuel sheet lights the pit")
		menu.call("hide_menu")
		cold_pit.queue_free()
	# A cook that is under way on the fire stops when the fire goes out, and its inputs stay in the bag.
	var sc1: Variant = _player.get("station_craft")
	if sc1 != null:
		sc1.set("station", pit)
		sc1.set("crafting", true)
		var branches_before: int = _player.inventory.count_of(&"branch")
		pit.call("tick", float(pit.get("fuel_seconds")) + 1.0)
		var stopped: bool = not bool(sc1.get("crafting"))
		print("[t_firepits] cook stopped with the fire: %s branches %d->%d" % [stopped, branches_before, _player.inventory.count_of(&"branch")])
		_expect(stopped, "a cook running on the pit stops when its fuel runs out")
		sc1.set("station", null)
	pit.queue_free()
	# A temporary fire that has burned out refuses too.
	var b := _fire(&"bonfire")
	b.call("tick", float(b.get("fuel_seconds")) + 1.0)
	_expect(not bool(b.call("can_cook")), "a burnt-out bonfire cannot cook")
	_expect(b.is_queued_for_deletion(), "a burnt-out bonfire is gone (removed, not ash)")

func _test_info_lines() -> void:
	_wood_log()
	var pit := _fire(&"stone_fire_pit")
	pit.call("load_wood", _player)
	var lines: PackedStringArray = pit.call("info_lines")
	var text := " | ".join(lines)
	print("[t_firepits] pit info: %s" % text)
	_expect(text.to_lower().contains("fuel"), "the pit's info shows the fuel left")
	_expect(not text.to_lower().contains("durability"), "the permanent pit shows no durability (it never decays)")
	var b := _fire(&"bonfire")
	var btext := " | ".join(b.call("info_lines") as PackedStringArray)
	print("[t_firepits] bonfire info: %s" % btext)
	_expect(btext.to_lower().contains("fuel") and btext.to_lower().contains("durability"), "a temporary fire's info shows fuel and durability")
	# The same text is on screen: the hex menu's own state line, over the burning pit and the bonfire.
	var sc: Variant = _player.get("station_craft")
	var menu: Variant = sc.get("menu") if sc != null else null
	_expect(menu != null, "the survivor has a station menu to show the fire's state")
	if menu != null:
		menu.call("show_for", pit, SM.filter_actions(pit, SM.actions_for(&"bonfire", _player)))
		var lbl: Label = menu.get("info_label")
		var shown := "" if lbl == null else lbl.text
		print("[t_firepits] menu info on screen: \"%s\"" % shown)
		_expect(shown.to_lower().contains("fuel") and shown.to_lower().contains("burning"), "the pit's menu shows its fuel and burning state on screen")
		menu.call("show_for", b, SM.filter_actions(b, SM.actions_for(&"bonfire", _player)))
		var lbl2: Label = menu.get("info_label")
		var shown2 := "" if lbl2 == null else lbl2.text
		print("[t_firepits] bonfire menu info on screen: \"%s\"" % shown2)
		_expect(shown2.to_lower().contains("fuel") and shown2.to_lower().contains("durability"), "the bonfire's menu shows fuel and durability on screen")
		menu.call("hide_menu")
	pit.queue_free()
	b.queue_free()

func _test_save_load() -> void:
	for kind in [&"stone_fire_pit", &"bonfire", &"campfire"]:
		var f := _fire(kind)
		if kind == &"stone_fire_pit":
			_wood_log()
			f.call("load_wood", _player)
		if kind != &"stone_fire_pit":
			f.call("tick", 30.0)
		var saved: Dictionary = f.call("to_dict")
		var back: StaticBody3D = B.from_dict(saved)
		_expect(is_equal_approx(float(back.get("fuel_seconds")), float(f.get("fuel_seconds"))), "%s fuel survives save/load" % kind)
		_expect(is_equal_approx(float(back.get("durability")), float(f.get("durability"))), "%s durability survives save/load" % kind)
		_expect(bool(back.call("burning")) == bool(f.call("burning")), "%s burning state survives save/load" % kind)
		print("[t_firepits] %s saved fuel=%.1f durability=%.1f" % [kind, float(saved.get("fuel_seconds", -1.0)), float(saved.get("durability", -1.0))])
		back.free()
		f.queue_free()
	# An older save row (no fuel/durability fields at all) still loads sanely.
	var old_fire: StaticBody3D = B.from_dict({"kind": "bonfire", "cell": [1, 2], "rot": 1, "x": 0.0, "z": 0.0})
	print("[t_firepits] old bonfire row fuel=%.0f durability=%.0f/%.0f" % [float(old_fire.get("fuel_seconds")), float(old_fire.get("durability")), float(old_fire.get("max_durability"))])
	_expect(float(old_fire.get("fuel_seconds")) > 0.0 and float(old_fire.get("durability")) > 0.0, "an old save row loads a lit, whole fire")
	old_fire.free()
	var old_pit: StaticBody3D = B.from_dict({"kind": "stone_fire_pit"})
	_expect(float(old_pit.get("fuel_seconds")) <= 0.0, "an old save row loads the permanent pit cold (it never stored wood)")
	old_pit.free()
	var legacy: StaticBody3D = B.from_dict({"kind": "bonfire"})
	_expect(float(legacy.get("seconds_left")) < 0.0, "a permanent-kind row keeps seconds_left at -1 (older saves read it)")
	legacy.free()

## The real save path: a JSON round trip through SaveSanitizer.clean keeps a fire's fuel and durability,
## and a forged/typoed field is dropped rather than crashing the load.
func _test_sanitized_save() -> void:
	var SAN = load("res://scripts/core/save_sanitizer.gd")
	for kind in [&"bonfire", &"campfire", &"stone_fire_pit"]:
		var f := _fire(kind)
		if kind == &"stone_fire_pit":
			_wood_log()
			f.call("load_wood", _player)
		else:
			f.call("tick", 90.0)
		var payload := {"home": {"buildings": [f.call("to_dict")]}}
		var text := JSON.stringify(payload)
		var parsed: Variant = JSON.parse_string(text)
		var cleaned: Dictionary = SAN.clean(parsed)
		var rows: Array = (cleaned["home"] as Dictionary).get("buildings", [])
		_expect(rows.size() == 1, "%s survives the save sanitizer as one row" % kind)
		if rows.size() == 1:
			var back: StaticBody3D = B.from_dict(rows[0])
			print("[t_firepits] sanitized %s fuel=%.1f durability=%.1f" % [kind, float(back.get("fuel_seconds")), float(back.get("durability"))])
			_expect(is_equal_approx(float(back.get("fuel_seconds")), float(f.get("fuel_seconds"))), "%s fuel survives the sanitizer" % kind)
			_expect(is_equal_approx(float(back.get("durability")), float(f.get("durability"))), "%s durability survives the sanitizer" % kind)
			back.free()
		f.queue_free()
	# A forged row (fuel/durability as text) is cleaned, not fatal: the fire loads with sane numbers.
	var bad: Dictionary = SAN.clean({"home": {"buildings": [{"kind": "bonfire", "fuel_seconds": "lots", "durability": "lots"}]}})
	var bad_row: Dictionary = (bad["home"] as Dictionary)["buildings"][0]
	print("[t_firepits] forged row after clean: %s" % str(bad_row))
	_expect(not bad_row.has("fuel_seconds") and not bad_row.has("durability"), "a forged fuel/durability field is dropped by the sanitizer")
	var sane: StaticBody3D = B.from_dict(bad_row)
	_expect(float(sane.get("fuel_seconds")) > 0.0 and float(sane.get("durability")) > 0.0, "the cleaned forged row loads a lit, whole fire")
	sane.free()
	# A cold pit saved after its fuel ran out comes back cold, not relit.
	var pit := _fire(&"stone_fire_pit")
	var cold_row: Dictionary = pit.call("to_dict")
	var cold_back: StaticBody3D = B.from_dict(cold_row)
	_expect(not bool(cold_back.call("burning")), "a pit saved cold loads cold")
	cold_back.free()
	pit.queue_free()
