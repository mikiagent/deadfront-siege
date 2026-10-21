extends SceneTree
## PETRADIAL (spec 23): tapping your own pet opens the Durango pet radial, not the old hex menu. Each
## segment, pressed through the viewport like a tap, runs the real action: Animals opens the Animals
## screen on that pet, Bag the pet's bag, Feed feeds it from the survivor's bag, Ride mounts (and the
## ring on the mount offers Dismount), Dismiss sends it home, Rename takes the character-name rule.
## Absent features are left out; a tap outside closes and does not walk; Esc closes; walking does
## not close it; tapping the pet mid-fight keeps the fight. Keys: Space over a hovered segment does not
## fire it, Tab picks and Enter fires; typing a name does not walk her; the rename card follows a
## resize. The open ring is a taken rect (plates, toasts and pills keep off it), and the Animals row
## keeps EQUIPPED readable after a long rename.
## Usage: godot --headless --path game --script res://tests/t_petradial.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
## `godot --script` compiles this file before the autoloads exist: game classes are loaded at run
## time and used untyped (the run_all.gd pattern).
var player
var hud
var data: Node
var PetRecordS: GDScript
var ItemStackS: GDScript
var RadialS: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	PetRecordS = load("res://scripts/pets/pet_record.gd")
	ItemStackS = load("res://scripts/items/item_stack.gd")
	RadialS = load("res://scripts/ui/pet_radial.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_petradial] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	host = Node3D.new()
	host.name = "TPetRadial"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	var ui_layer := CanvasLayer.new()
	host.add_child(ui_layer)
	var inv_ui = (load("res://scenes/ui/inventory.tscn") as PackedScene).instantiate()
	ui_layer.add_child(inv_ui)
	player.ui = inv_ui
	inv_ui.bind(player.inventory, player)
	hud = (load("res://scripts/ui/hunt_hud.gd") as GDScript).new()
	hud.bind(player)
	ui_layer.add_child(hud)
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	await _frames(10)
	await _test_segments()
	await _test_absent_outside_esc()
	await _test_rename_rule()
	await _test_fight_and_walk()
	await _test_keys_and_layout()
	host.queue_free()
	await _frames(2)
	if failures.is_empty():
		print("[t_petradial] PASS")
		quit(0)
	else:
		print("[t_petradial] FAIL %d: %s" % [failures.size(), failures])
		quit(1)

func _summon(species: StringName, nm: String):
	var rec = PetRecordS.from_def(data.creature(species), &"A")
	rec.name = nm
	player.bonded.append(rec)
	return player.pets.summon(player.bonded.size() - 1)

## The ring the pets layer shows, or null (the old StationMenu hex menu is not one).
func _radial():
	var m = player.pets.get("menu")
	return m if m != null and RadialS != null and m.get_script() == RadialS else null

## What a tap on the pet does (PlayerInput.interact_tap_target is the tap's dispatch for a creature).
func _open(c) -> void:
	player.controls.interact_tap_target(c)
	await _frames(1)

## A left click through the root viewport at a canvas point (in window pixels: the root stretches its
## canvas), GUI first, then the world's tap handling.
func _tap_at(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = get_root().get_final_transform() * pos
	down.global_position = down.position
	get_root().push_input(down)
	await _frames(1)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	get_root().push_input(up)
	await _frames(1)

func _tap_segment(id: StringName) -> bool:
	var r = _radial()
	if r == null or not r.visible:
		return false
	var i: int = r.ids().find(id)
	if i < 0:
		return false
	await _tap_at(r.segment_center(i))
	return true

func _test_segments() -> void:
	var rex = _summon(&"zebraceratops", "REX")
	var rec = rex.pet_record
	await _frames(5)
	await _open(rex)
	var r = _radial()
	_expect(r != null and r.visible, "tapping your own pet opens the pet radial (menu=%s)" % [player.pets.get("menu")])
	if r == null:
		return
	_expect(r.ids() == [&"animals", &"bag", &"feed", &"ride", &"dismiss", &"rename"], "zebraceratops segments %s" % [r.ids()])
	# Feed: one berry from the survivor's bag into the pet.
	player.inventory.add(ItemStackS.make(&"berries", 3))
	rex.hunger = 1.0
	var berries: int = player.inventory.count_of(&"berries")
	var fed := await _tap_segment(&"feed")
	_expect(fed and rex.hunger > 1.0 and player.inventory.count_of(&"berries") == berries - 1 and not r.visible,
		"Feed feeds the pet (hunger %.1f, berries %d -> %d)" % [rex.hunger, berries, player.inventory.count_of(&"berries")])
	# Bag: the pet's cargo in the bag screen.
	await _open(rex)
	await _tap_segment(&"bag")
	_expect(player.ui.visible and player.ui.pet_bag == rec.bag, "Bag opens the pet's bag")
	player.ui.hide_ui()
	# Animals: the Animals screen, on this pet.
	player.bonded.push_front(PetRecordS.from_def(data.creature(&"velociraptor"), &"B"))  # REX is not row 0
	await _open(rex)
	await _tap_segment(&"animals")
	var screen = hud.find_child("AnimalScreen", true, false)
	_expect(screen != null and screen.visible and screen.selected == player.bonded.find(rec),
		"Animals opens the Animals screen on the pet (selected %s, pet row %d)" % [screen.selected if screen else "-", player.bonded.find(rec)])
	if screen:
		screen.close_screen()
	player.bonded.pop_front()
	# Ride, then Dismount from the ring on the mount.
	await _open(rex)
	await _tap_segment(&"ride")
	_expect(player.mounted_on == rex, "Ride mounts the pet")
	await _open(rex)
	_expect(r.visible and &"dismount" in r.ids() and not (&"ride" in r.ids()), "the ring on your mount offers Dismount %s" % [r.ids()])
	await _tap_segment(&"dismount")
	_expect(player.mounted_on == null, "Dismount gets off")
	await _frames(3)
	# Rename: refused with the character-name reason, then accepted.
	await _open(rex)
	await _tap_segment(&"rename")
	var dialog = player.pets.get("rename_dialog")
	_expect(dialog != null and dialog.visible, "Rename opens the name dialog")
	if dialog:
		var field := dialog.find_child("NameField", true, false) as LineEdit
		_expect(field != null and field.text == "REX", "the dialog starts from the current name")
		field.text = "R!"
		dialog.submit()
		_expect(dialog.visible and dialog.refusal() != "" and rec.name == "REX", "a bad name is refused (%s)" % dialog.refusal())
		field.text = "Rex II"
		dialog.submit()
		_expect(not dialog.visible and rec.name == "Rex II", "Rename sets the name (%s)" % rec.name)
	# Dismiss: sent home through the summon path (HP kept), off the field.
	await _open(rex)
	await _tap_segment(&"dismiss")
	await _frames(2)
	_expect(not is_instance_valid(rex) or not player.live_pets().has(rex), "Dismiss sends the pet home")
	_expect(not rec.summoned and not r.visible, "the record is no longer out and the ring closed")
	player.bonded.erase(rec)

func _test_absent_outside_esc() -> void:
	var compy = _summon(&"compsognathus", "")
	await _frames(5)
	await _open(compy)
	var r = _radial()
	if r == null:
		_expect(false, "no radial for the compsognathus")
		return
	# Every record has a bag (PetRecord.bag_slots_for), so Bag stays; Ride is the absent one.
	_expect(r.ids() == [&"animals", &"bag", &"feed", &"dismiss", &"rename"], "a combat-only species has no Ride %s" % [r.ids()])
	await _open(compy)
	_expect(not r.visible, "tapping the same pet again closes the ring")
	await _open(compy)
	player.clear_nav()
	var view: Vector2 = get_root().get_visible_rect().size
	await _tap_at(Vector2(12.0, view.y * 0.5))
	await _frames(2)
	_expect(not r.visible and not player.nav_active, "a tap outside closes the ring and does not walk (nav %s)" % player.nav_active)
	await _open(compy)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	get_root().push_input(esc)
	await _frames(1)
	_expect(not r.visible, "Esc closes the ring")
	player.pets.dismiss(compy)
	player.bonded.erase(compy.pet_record)
	await _frames(2)

## Same rule as the character name: whatever the server's char.create takes (after the trim the
## character screen does), Rename takes, and nothing else. Online it is an act.pet_rename intent.
func _test_rename_rule() -> void:
	var store = (load("res://scripts/server/character_store.gd") as GDScript).new((load("res://scripts/server/world_facade.gd") as GDScript).new(), "", 7)
	if not player.actions.has_method("rename_pet"):
		_expect(false, "PlayerActions has a rename_pet verb")
		return
	var rec = PetRecordS.from_def(data.creature(&"zebraceratops"), &"A")
	var names := ["Rex", "Rex II", "ab", "R!x", "abcdefghijklmnopqrstu", "abcdefghijklmnopqrst", "  Rexy  ", "Zebra_1-2", "", "Ré", "a b"]
	var agree := true
	for i in names.size():
		var nm: String = names[i]
		var server_ok: bool = store.apply("char.create", 100 + i, {"name": nm.strip_edges()}, 1).get("ok", false)
		rec.name = "before"
		var why: String = player.actions.rename_pet(rec, nm)
		var pet_ok: bool = why == "" and rec.name == nm.strip_edges()
		if server_ok != pet_ok or (not pet_ok and rec.name != "before"):
			agree = false
			print("[t_petradial] name '%s': char.create %s, rename %s (%s)" % [nm, server_ok, pet_ok, why])
	_expect(agree, "Rename accepts exactly the names char.create accepts (%d names)" % names.size())
	player.actions.online = true
	rec.name = "before"
	var why_online: String = player.actions.rename_pet(rec, "Rexy")
	player.actions.online = false
	var last: Dictionary = player.actions.sent.back() if not player.actions.sent.is_empty() else {}
	_expect(why_online == "" and rec.name == "before" and str(last.get("op", "")) == "act.pet_rename" \
		and last["a"]["pet_uid"] == rec.uid and last["a"]["name"] == "Rexy", "online Rename is an act.pet_rename intent (%s)" % [last])

func _test_fight_and_walk() -> void:
	var rex = _summon(&"zebraceratops", "REX")
	var wild = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	wild.position = Vector3(-4, 0, 0)
	host.add_child(wild)
	wild.spawn(data.creature(&"protoceratops"))
	wild.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	player.hunt.start(wild)
	await _open(rex)
	var r = _radial()
	_expect(player.hunt.target == wild, "tapping your pet mid-fight keeps the fight (target %s)" % [player.hunt.target])
	player.hunt.stop()
	player.nav_to(Vector3(6, 0, 6))
	await _frames(4)
	_expect(r != null and r.visible, "walking does not close the ring (nav %s)" % player.nav_active)
	player.clear_nav()
	if r:
		r.hide_menu()
	player.pets.dismiss(rex)
	player.bonded.erase(rex.pet_record)
	wild.queue_free()
	await _frames(2)

func _key(code: Key, unicode: int = 0, held_s: float = 0.0) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.unicode = unicode
	k.pressed = true
	# Through Input, like a keyboard: polled movement sees it as well as the GUI.
	Input.parse_input_event(k)
	if held_s > 0.0:
		await create_timer(held_s).timeout
	else:
		await _frames(1)
	var up := k.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)

func _test_keys_and_layout() -> void:
	var rex = _summon(&"zebraceratops", "REX")
	await _frames(5)
	await _open(rex)
	var r = _radial()
	if r == null:
		_expect(false, "no radial for the key and layout checks")
		return
	_expect(hud.taken_rects().has(r.ring_rect()), "the open ring is a taken rect: creature plates, toasts and pills keep off it")
	# Space (roll) with the mouse resting on Bag: no bag. Then Tab picks Feed and Enter fires it.
	player.inventory.add(ItemStackS.make(&"berries", 3))
	rex.hunger = 1.0
	var berries: int = player.inventory.count_of(&"berries")
	var mm := InputEventMouseMotion.new()
	mm.position = get_root().get_final_transform() * r.segment_center(r.ids().find(&"bag"))
	mm.global_position = mm.position
	get_root().push_input(mm)
	await _frames(1)
	await _key(KEY_SPACE)
	_expect(r.visible and not player.ui.visible, "Space over the hovered Bag does not fire it (ring open %s, bag %s)" % [r.visible, player.ui.visible])
	player.ui.hide_ui()
	if r.visible:
		await _key(KEY_TAB)
		_expect(r.hot >= 0 and r.ids()[r.hot] == &"feed", "Tab picks the next segment (%s)" % [r.ids()[r.hot] if r.hot >= 0 else "-"])
		await _key(KEY_ENTER)
		_expect(not r.visible and rex.hunger > 1.0 and player.inventory.count_of(&"berries") == berries - 1, "Enter fires the picked segment (Feed: hunger %.1f)" % rex.hunger)
	r.hide_menu()
	await create_timer(1.0).timeout  # the Space roll runs out
	# Typing a name: the letter goes into the field and the survivor stays put.
	await _open(rex)
	await _tap_segment(&"rename")
	var dialog = player.pets.get("rename_dialog")
	var field := dialog.find_child("NameField", true, false) as LineEdit if dialog else null
	if field == null or not dialog.visible:
		_expect(false, "the rename dialog for the typing check")
		return
	var at: Vector3 = player.global_position
	await _key(KEY_D, "d".unicode_at(0), 0.4)
	var moved := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
	_expect(field.text == "d" and moved < 0.1, "typing d fills the field (%s) and does not walk (%.2f m)" % [field.text, moved])
	# The window goes to phone size with the dialog open: the card follows it.
	var win: Vector2i = get_root().size
	get_root().size = Vector2i(844, 390)
	await _frames(3)
	var card := dialog.find_child("Card", true, false) as Control
	var view: Rect2 = get_root().get_visible_rect()
	_expect(card != null and view.encloses(card.get_global_rect()) and absf(card.get_global_rect().get_center().x - view.get_center().x) < 2.0,
		"the rename card follows a resize (card %s, view %s)" % [card.get_global_rect() if card else Rect2(), view])
	get_root().size = win
	await _frames(3)
	# A long name keeps EQUIPPED on the Animals row (the name gives way).
	field.text = "Abcdefghijklmnopqrst"
	dialog.submit()
	hud.open_animals(rex.pet_record)
	await _frames(2)
	var screen = hud.find_child("AnimalScreen", true, false)
	var row := ""
	for b in (screen.find_children("*", "Button", true, false) if screen else []):
		if (b as Button).text.begins_with("Abc"):
			row = (b as Button).text
	_expect(row.ends_with("EQUIPPED"), "the Animals row keeps EQUIPPED after a long name (%s)" % row)
	if screen:
		screen.close_screen()
	player.pets.dismiss(rex)
	player.bonded.erase(rex.pet_record)
	await _frames(2)
