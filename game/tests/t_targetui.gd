extends SceneTree
## TARGETUI acceptance (spec 23, owner 2026-10-20): a tap on a wild animal selects it (plate, ring,
## red swords hex beside it) and starts no fight; the swords hex, E and F fight the selection through
## PlayerActions (online: the act.attack intent); a tap on the ground deselects; an animal that bites
## is still fought at once; a pet is never selected, never gets the swords and a tap on it keeps the fight.
## Usage: godot --headless --path game --script res://tests/t_targetui.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
var cam: Camera3D
## `godot --script` compiles this file before the autoloads exist: game classes are loaded at run
## time and used untyped (the t_player.gd pattern). `selection` is read with get() so the old code
## (no selection) fails these checks instead of stopping on a script error.
var player
var hud
var data: Node
var PetRecordS: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	PetRecordS = load("res://scripts/pets/pet_record.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_targetui] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	host = Node3D.new()
	host.name = "TTargetUi"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	cam = Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	var ui_layer := CanvasLayer.new()
	host.add_child(ui_layer)
	hud = (load("res://scripts/ui/hunt_hud.gd") as GDScript).new()
	hud.bind(player)
	ui_layer.add_child(hud)
	await _frames(30)
	await _test_tap_selects()
	await _test_swords_engage()
	await _test_keys()
	await _test_deselect()
	await _test_hostile_engaged()
	await _test_pets_excluded()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_targetui] PASS")
		quit(0)
	else:
		print("[t_targetui] FAIL count=%d" % failures.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _creature(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # rules under test, not AI
	return c

func _clear() -> void:
	player.hunt.stop()
	player.clear_nav()
	var sel = player.controls.get("selection")
	if sel:
		sel.clear()
	for c in get_nodes_in_group("creatures"):
		c.queue_free()
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 1.0, 0)
	player.actions.online = false
	await _frames(10)

## A tap through the real pick path (camera ray, then the 1 m bubble), as a finger would.
func _tap(world: Vector3) -> void:
	player.debug_tap_screen(cam.unproject_position(world))
	await _frames(3)

func _selected():
	var sel = player.controls.get("selection")
	return sel.current() if sel else null

func _swords() -> Control:
	return hud.get_node_or_null("TargetSwords") as Control

func _swords_shown() -> bool:
	var s := _swords()
	return s != null and s.is_visible_in_tree()

## Owner: "You can tap on an animal, that selects it". The old tap started the hunt and swung.
func _test_tap_selects() -> void:
	var wild = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	await _frames(5)
	var hp0: float = wild.health.hp
	var swings := [0]
	var count := func () -> void: swings[0] += 1
	player.hunt.swing_started.connect(count)
	await _tap(wild.global_position + Vector3(0, 0.5, 0))
	_expect(player.hunt.target == null, "a tap on a wild animal starts no hunt (hunt target %s)" % [player.hunt.target])
	_expect(_selected() == wild, "a tap on a wild animal selects it (selection %s)" % [_selected()])
	_expect(wild.get_node_or_null("SelectRing") != null, "the selected animal wears the select ring")
	await _frames(4)
	_expect(_swords_shown(), "the red swords hex shows for the selection")
	if _swords_shown():
		var at: Vector2 = cam.unproject_position(wild.global_position + Vector3(0, 0.5, 0))
		var d := _swords().get_global_rect().get_center().distance_to(at)
		_expect(d < 160.0, "the swords hex floats beside the animal (%.0f px from it)" % d)
	_expect((hud.get("drawn_blocks") as Dictionary).has("plate"), "the target plate shows for the selection, no fight needed")
	await create_timer(1.2, true, true).timeout
	_expect(swings[0] == 0 and is_equal_approx(wild.health.hp, hp0) and player.hunt.target == null,
		"1.2 s after the tap: no swing (%d), HP %.0f / %.0f, still no hunt" % [swings[0], wild.health.hp, hp0])
	player.hunt.swing_started.disconnect(count)

## Owner: "if you press red swords you initiate combat with it": through PlayerActions.
func _test_swords_engage() -> void:
	var wild = _selected()
	if wild == null or _swords() == null:
		_expect(false, "swords: nothing selected or no swords hex to press")
		await _clear()
		return
	player.actions.online = true
	var n0: int = player.actions.sent.size()
	_push_click(_swords())
	await _frames(2)
	var last: Dictionary = player.actions.sent.back() if player.actions.sent.size() > n0 else {}
	_expect(str(last.get("op", "")) == "act.attack" and int(last.get("a", {}).get("net_id", 0)) == wild.get_instance_id() and player.hunt.target == null,
		"online: the swords hex sends act.attack for the selection and applies nothing locally (%s)" % [last])
	player.actions.online = false
	_push_click(_swords())
	await _frames(4)
	_expect(player.hunt.target == wild, "offline: the swords hex starts the hunt on the selection")
	_expect(not _swords_shown(), "the swords hex hides once that animal is the fight")
	_expect(_selected() == wild, "the selection stays on the animal being fought")
	player.hunt.stop()
	await _frames(3)
	_expect(_swords_shown(), "End Combat: the swords hex is back to start it again")
	await _clear()

func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	player.controls.handle_unhandled(ev)

## E (the key the swords hex shows) and F fight the selection, not the nearest animal.
func _test_keys() -> void:
	var near = _creature(&"protoceratops", Vector3(-2.0, 0, 0))
	var picked = _creature(&"protoceratops", Vector3(4.0, 0, 1.0))
	await _frames(5)
	await _tap(picked.global_position + Vector3(0, 0.5, 0))
	_expect(_selected() == picked and player.hunt.target == null, "keys: the far animal is selected, no fight yet")
	_press(&"interact")
	_expect(player.hunt.target == picked, "E fights the selection (hunt %s)" % [player.hunt.target])
	player.hunt.stop()
	_press(&"attack")
	_expect(player.hunt.target == picked, "F fights the selection, not the nearer animal (hunt %s, nearer %s)" % [player.hunt.target, near])
	await _clear()

## "deselect by tapping empty ground or another target".
func _test_deselect() -> void:
	var a = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	var b = _creature(&"protoceratops", Vector3(-3.5, 0, 0))
	await _frames(5)
	await _tap(a.global_position + Vector3(0, 0.5, 0))
	await _tap(b.global_position + Vector3(0, 0.5, 0))
	await _frames(2)
	_expect(_selected() == b and a.get_node_or_null("SelectRing") == null and b.get_node_or_null("SelectRing") != null,
		"a tap on another animal moves the selection and its ring")
	await _tap(Vector3(0, 0, -5.0))
	await _frames(3)
	_expect(_selected() == null and b.get_node_or_null("SelectRing") == null and not _swords_shown(),
		"a tap on empty ground deselects: no ring, no swords")
	_expect(player.hunt.target == null, "deselecting started nothing")
	await _clear()

## A creature that is already fighting you is engaged at once, selection or not.
func _test_hostile_engaged() -> void:
	var calm = _creature(&"protoceratops", Vector3(4.0, 0, 0))
	var raptor = _creature(&"velociraptor", Vector3(-1.2, 0, 0))
	await _frames(5)
	await _tap(calm.global_position + Vector3(0, 0.5, 0))
	_expect(_selected() == calm and player.hunt.target == null, "hostile: a calm animal is selected")
	player.receive_creature_hit(raptor, &"attack_primary")
	_expect(player.hunt.target == raptor, "a raptor that bites is fought at once (hunt %s)" % [player.hunt.target])
	await _clear()

## Pets: never selected, never the swords; a tap on your pet opens its menu and keeps the fight going.
func _test_pets_excluded() -> void:
	var wild = _creature(&"protoceratops", Vector3(4.0, 0, 0))
	var pet = _creature(&"zebraceratops", Vector3(-3.0, 0, 1.0))
	pet.become_pet(PetRecordS.new())
	await _frames(5)
	await _tap(pet.global_position + Vector3(0, 0.6, 0))
	await _frames(3)
	_expect(_selected() == null and pet.get_node_or_null("SelectRing") == null and not _swords_shown(),
		"a tap on your pet selects nothing and shows no swords")
	_expect(player.hunt.target == null, "a tap on your pet starts no fight")
	var sel = player.controls.get("selection")
	if sel:
		sel.select(pet)
		_expect(sel.current() == null, "a pet cannot be selected even directly")
	player.actions.attack(wild)
	_expect(player.hunt.target == wild, "pets: the hunt is on the wild animal")
	await _tap(pet.global_position + Vector3(0, 0.6, 0))
	_expect(player.hunt.target == wild, "a tap on your pet during a fight keeps the fight (hunt %s)" % [player.hunt.target])
	await _clear()

func _push_click(c: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = get_root().get_final_transform() * c.get_global_rect().get_center()
	click.global_position = click.position
	get_root().push_input(click)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	get_root().push_input(up)
