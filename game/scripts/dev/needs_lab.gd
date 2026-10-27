extends Node3D
## NEEDS lab: every survival verb a player starts, driven through the control the player taps, with
## one screenshot per action showing that control on the real HUD:
##   eat       bag -> tap the skewer -> Inspect -> the food card's Eat button (FoodInspector)
##   drink     context hex Drink at the river bank (HuntHud, PlayerInput.context_action)
##   wash      context hex Wash at the river bank
##   fill      context hex Fill at the river bank with an empty bucket
##   sleep     tap the tent -> the SLEEP hex over it (StationCraft menu) -> sleep runs out
##   fire_dry  context hex Dry off beside a bonfire while Wet (PRD :285)
##   feed_pet  tap the pet -> the FEED hex in its menu -> pet hunger rises
##   persist   SaveGame.save_now, then the load path reads the statuses and pet hunger back
## Each *_ok is measured from the effect on the live scene, not assumed. `unreachable` counts actions
## with no HUD control on the phone canvas; `ui_min_px` is the smallest tap target pressed, in px.
## Headless cannot draw (frame_post_draw never fires), so this lab needs a window:
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=needs_lab --shot-dir=DIR
##   (again with --resolution 844x390)
## Prints one line: "[needs] RESULT eat_ok=.. drink_ok=.. ... ui_min_px=.." then quits.

const SETTLE_S := 0.9
const WATER_Y := -0.05

var _out := ""
var _player: Player
var _hud: HuntHud
var _cam: IsoCamera
var _rt: IslandRuntime
var _min_px: float = 9999.0
var _unreachable: int = 0
var _ok := {
	"eat": 0, "drink": 0, "wash": 0, "fill": 0, "sleep": 0,
	"fire_dry": 0, "feed_pet": 0, "persist": 0,
}
var _notes: Array[String] = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_rt = World.runtime as IslandRuntime
	Game.time_of_day = 0.45
	await _do_eat()
	await _do_water()
	await _do_sleep()
	await _do_fire_dry()
	await _do_feed_pet()
	await _do_persist()
	var line := "[needs] RESULT"
	for k in ["eat", "drink", "wash", "fill", "sleep", "fire_dry", "feed_pet", "persist"]:
		line += " %s_ok=%d" % [k, int(_ok[k])]
	line += " unreachable=%d ui_min_px=%d" % [_unreachable, int(round(_min_px if _min_px < 9999.0 else 0.0))]
	print(line)
	for n in _notes:
		print("[needs] note %s" % n)
	get_tree().quit(0)

# ---------------------------------------------------------------- eat

## The bag's own flow: open the bag, tap the food (selects it), Inspect opens the food card, and the
## card's Eat button starts the meal. The card is the HUD control, so the eat is one tap from the bag.
func _do_eat() -> void:
	_player.statuses.from_array([])
	_player.vitals.energy = 20.0
	_player.inventory.add(ItemStack.make(&"skewer", 1))
	var idx: int = _player.inventory.find_first(&"skewer")
	_player.ui.visible = true
	_player.ui.rebuild()
	_player.ui._select(idx)
	_player.ui._on_inspect_food()
	await _wait(0.4)
	var card: FoodInspector = _player.ui._food_inspector
	var eat_btn: Button = card._eat_btn
	print("[needs] eat card visible=%s button=%.0fx%.0f" % [card.visible, eat_btn.size.x, eat_btn.size.y])
	await _shot("eat_food_card")
	# Every control the player taps for this action: the bag cell that picks the food, the Inspect
	# button and the card's Eat. A dead card that runs off the canvas is not a reachable control.
	var cell := _bag_cell_rect(idx)
	if cell.size.x > 0.0:
		_min_px = minf(_min_px, minf(cell.size.x, cell.size.y))
	else:
		_unreachable += 1
		_notes.append("eat: the bag slot holding the food is not on screen")
	_min_px = minf(_min_px, minf(eat_btn.size.x, eat_btn.size.y))
	if not _fully_on_screen(eat_btn) or not _fully_on_screen(card):
		_unreachable += 1
		_notes.append("eat: the food card runs off the %s canvas" % str(get_viewport().get_visible_rect().size))
	var before: float = _player.vitals.energy
	eat_btn.pressed.emit()
	var waited := 0.0
	while _player.eat_session.eating and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(0.3)
	_ok["eat"] = 1 if (_player.vitals.energy > before + 1.0 and _player.statuses.has(&"full")) else 0
	_notes.append("eat %.0f -> %.0f energy, full=%s" % [before, _player.vitals.energy, str(_player.statuses.has(&"full"))])
	await _shot("eat_after")
	_player.ui.hide_ui()

# ---------------------------------------------------------------- water: drink, wash, fill

func _do_water() -> void:
	var bank := _bank(_find_shallow(true))
	await _stand(bank)
	_player.statuses.from_array([])
	_player.statuses.apply(&"thirsty")
	_player.statuses.apply(&"dirty")
	_player.inventory.add(ItemStack.make(&"empty_bucket", 1))
	var eb: int = _player.inventory.find_first(&"empty_bucket")
	if eb >= 0:
		_player.inventory.slots[eb].level = 3
	_refresh_ctx()
	await _wait(0.2)
	await _shot("water_hexes")
	var drink := _ctx_hex("drink")
	var wash := _ctx_hex("wash")
	var fill := _ctx_hex("fill")
	if drink == null or wash == null or fill == null:
		_unreachable += 1
		_notes.append("water: hexes missing drink=%s wash=%s fill=%s" % [drink != null, wash != null, fill != null])
		return
	_tap(drink)
	await _wait(0.2)
	_ok["drink"] = 1 if (not _player.statuses.has(&"thirsty") and _player.statuses.has(&"quenched")) else 0
	_refresh_ctx()
	await _wait(0.1)
	wash = _ctx_hex("wash")
	if wash:
		_tap(wash)
		await _wait(0.2)
	_ok["wash"] = 1 if (not _player.statuses.has(&"dirty") and _player.statuses.has(&"clean")) else 0
	_refresh_ctx()
	await _wait(0.1)
	fill = _ctx_hex("fill")
	if fill:
		_tap(fill)
		await _wait(0.2)
	var wb: int = _player.inventory.find_first(&"water_bucket")
	_ok["fill"] = 1 if (wb >= 0 and int(_player.inventory.slots[wb].level) == 3) else 0
	_notes.append("water: drink=%s wash=%s fill bucket lv=%s" % [
		str(_ok["drink"]), str(_ok["wash"]), str(int(_player.inventory.slots[wb].level) if wb >= 0 else -1)])
	await _shot("water_after")

# ---------------------------------------------------------------- sleep

## Tap the tent (PlayerActions.building_interact -> Player.open_station_craft), then the SLEEP hex
## over it. The sleep runs its own 10 s; the survivor must not move.
func _do_sleep() -> void:
	await _stand(_dry_mid())
	_player.statuses.from_array([])
	var tent = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"tent")
	add_child(tent)
	tent.global_position = _player.global_position + Vector3(1.4, 0, 0)
	await _wait(0.5)
	_player.vitals.fatigue = 85.0
	_player.open_station_craft(tent)
	await _wait(0.4)
	var hex := _station_hex(&"sleep")
	if hex == null:
		_unreachable += 1
		_notes.append("sleep: no SLEEP hex on the tent menu")
		return
	await _shot("sleep_tent_hex")
	var before: float = _player.vitals.fatigue
	_tap(hex)
	var waited := 0.0
	while _player._sleep_left > 0.0 and waited < 20.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(0.3)
	_ok["sleep"] = 1 if _player.vitals.fatigue < before - 10.0 else 0
	_notes.append("sleep fatigue %.0f -> %.0f (tent sleeps left %s)" % [before, _player.vitals.fatigue, str(tent.get("sleeps_left"))])
	await _shot("sleep_after")
	tent.queue_free()
	await _wait(0.3)

# ---------------------------------------------------------------- bonfire: dry off

func _do_fire_dry() -> void:
	await _stand(_dry_mid())
	_player.statuses.from_array([])
	var fire := Bonfire.make(&"bonfire")
	add_child(fire)
	fire.global_position = _player.global_position + Vector3(1.5, 0, 0)
	await _wait(0.5)
	_player.statuses.apply(&"wet")
	_refresh_ctx()
	await _wait(0.2)
	var hex := _ctx_hex("dry")
	if hex == null:
		_unreachable += 1
		_notes.append("fire_dry: no Dry off hex at the bonfire")
		return
	await _shot("fire_dry_hex")
	_tap(hex)
	await _wait(0.2)
	_ok["fire_dry"] = 1 if not _player.statuses.has(&"wet") else 0
	await _shot("fire_dry_after")
	fire.queue_free()
	await _wait(0.2)

# ---------------------------------------------------------------- feed a pet

func _do_feed_pet() -> void:
	await _stand(_dry_mid())
	_player.statuses.from_array([])
	var rec = (load("res://scripts/pets/pet_record.gd") as GDScript).from_def(Data.creature(&"velociraptor"), &"A")
	_player.bonded.append(rec)
	_player.summon_pet(_player.bonded.size() - 1)
	await _wait(1.0)
	var pet = _player.pets.nearest(99.0)
	if pet == null:
		_unreachable += 1
		_notes.append("feed_pet: no pet out")
		return
	pet.hunger = 20.0
	pet.hunger_max = 100.0
	if pet.pet_record:
		pet.pet_record.hunger = 20.0
		pet.pet_record.hunger_max = 100.0
	_player.inventory.add(ItemStack.make(&"raw_meat", 1))
	_player.pets.interact(pet)
	await _wait(0.4)
	var hex := _station_hex(&"feed")
	if hex == null:
		_unreachable += 1
		_notes.append("feed_pet: no FEED hex in the pet menu")
		return
	await _shot("pet_feed_hex")
	var before: float = pet.hunger
	_tap(hex)
	await _wait(0.3)
	_ok["feed_pet"] = 1 if pet.hunger > before + 1.0 else 0
	_notes.append("feed_pet hunger %.0f -> %.0f" % [before, pet.hunger])
	await _shot("pet_feed_after")

# ---------------------------------------------------------------- persistence

func _do_persist() -> void:
	_player.statuses.from_array([])
	_player.statuses.apply(&"full")
	_player.statuses.apply(&"quenched")
	_player.statuses.apply(&"clean")
	var pet = _player.pets.nearest(99.0)
	if pet and pet.pet_record:
		pet.hunger = 41.0
		pet.pet_record.hunger = 41.0
	var saved: bool = SaveGame.save_now()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.path)) if saved else {}
	var ids: Array = []
	for row in raw.get("player", {}).get("statuses", []):
		ids.append(str(row.get("id", "")))
	var pets: Array = raw.get("pets", [])
	var pet_ok := not pets.is_empty() and is_equal_approx(float(pets[0].get("hunger", -1.0)), 41.0)
	# The load path itself.
	_player.statuses.from_array(raw.get("player", {}).get("statuses", []))
	var back_ok := _player.statuses.has(&"full") and _player.statuses.has(&"quenched") and _player.statuses.has(&"clean")
	_ok["persist"] = 1 if (saved and pet_ok and back_ok) else 0
	_notes.append("persist saved=%s statuses=%s pet_hunger_ok=%s reload_ok=%s" % [str(saved), str(ids), str(pet_ok), str(back_ok)])
	await _shot("persist_after")

# ---------------------------------------------------------------- controls

## A context hex by id, built by the HUD itself for the survivor's spot.
func _ctx_hex(id: String) -> HexButton:
	for i in _hud._ctx_ids.size():
		var row: Array = _hud._ctx_ids[i]
		if str(row[0]) == id and i < _hud._ctx_hexes.size():
			return _hud._ctx_hexes[i]
	return null

## Force the HUD's 0.3 s context refresh now instead of waiting for its timer.
func _refresh_ctx() -> void:
	_hud._ctx_timer = 0.0
	_hud._refresh_context(0.05)

## A hex in the open station / pet menu, by its caption ("SLEEP", "FEED"), which is the row's label.
func _station_hex(id: StringName) -> HexButton:
	var menus: Array = []
	if _player.pets.menu:
		menus.append(_player.pets.menu)
	if _player.station_craft and _player.station_craft.menu:
		menus.append(_player.station_craft.menu)
	for m in menus:
		var menu := m as StationMenu
		if not menu.visible:
			continue
		for b in menu._buttons:
			var hex := b as HexButton
			if hex.bottom_text.to_lower() == str(id):
				return hex
	return null

## The bag slot cell showing `slot_index` (the control that selects the food), or an empty rect.
# ASSUMPTION: reading InventoryUI's grid + cell table directly is a lab-only shortcut; the player
# taps the same Button, the lab only needs its rect to measure the tap target.
func _bag_cell_rect(slot_index: int) -> Rect2:
	var ui = _player.ui
	for k in mini(ui._grid.get_child_count(), ui._cells.size()):
		var cell: Dictionary = ui._cells[k]
		var btn := ui._grid.get_child(k) as Control
		if btn and btn.visible and int(cell.get("slot", -2)) == slot_index:
			return btn.get_global_rect()
	return Rect2()

## True when the whole control is on the canvas (a control half off it cannot be tapped).
func _fully_on_screen(c: Control) -> bool:
	var vp := get_viewport().get_visible_rect().size
	var r := c.get_global_rect()
	return r.position.x >= -1.0 and r.position.y >= -1.0 and r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0

## Tap a control: a press + release at its centre, the same two events a finger makes.
func _tap(c: Control) -> void:
	var at := c.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	c._gui_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	c._gui_input(up)
	_min_px = minf(_min_px, minf(c.size.x, c.size.y))

func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(path)
	print("[needs] shot %s" % path)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

# ---------------------------------------------------------------- spots (as water_lab)

func _is_water(x: float, z: float) -> bool:
	return _rt.surface_y(x, z) < WATER_Y

func _is_river(x: float, z: float) -> bool:
	return IslandTerrain.tile_type_at_world(_rt, x, z) == IslandTerrain.TileType.MUD

func _find_shallow(river: bool) -> Vector3:
	var from: Vector3 = _rt._camp_pos if river else _rt.arrival_point()
	var ring := 38.0 if river else 12.0
	var best := Vector3.ZERO
	var best_d := INF
	var half := _rt._size * 0.5 - 2.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var h := _rt.surface_y(x, z)
			if h < (-0.25 if river else -0.12) and h > -0.38 and _is_river(x, z) == river and (not river or absf(z) > 8.0):
				var d := absf(Vector2(x - from.x, z - from.z).length() - ring)
				if d < best_d:
					best_d = d
					best = Vector3(x, h, z)
			z += 0.5
		x += 0.5
	return best

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
			best = Vector3(at.x + d.x * 0.6, 0.0, at.y + d.y * 0.6)
	return best

func _dry_mid() -> Vector3:
	var half := _rt._size * 0.5 - 6.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			if _rt.surface_y(x, z) > 0.5 and not WaterAccess.near_fresh(Vector3(x, 0, z)):
				return Vector3(x, 0, z)
			z += 2.0
		x += 2.0
	return Vector3(0, 0, 0)

func _stand(at: Vector3) -> void:
	_player.clear_nav()
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(at.x, _rt.surface_y(at.x, at.z) + 0.2, at.z)
	_player.reset_physics_interpolation()
	_cam._snap()
	await _wait(SETTLE_S)
