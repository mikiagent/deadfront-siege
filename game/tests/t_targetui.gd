extends SceneTree
## TARGETUI acceptance (spec 23, owner 2026-10-20): a tap on a wild animal selects it (plate, ring,
## red swords hex beside it) and starts no fight; the swords hex, E and F fight the selection through
## PlayerActions (online: the act.attack intent); a tap on the ground deselects; an animal that bites
## is still fought at once; a pet is never selected, never gets the swords and a tap on it keeps the fight.
## Review r1: the hex shows only while the animal is on screen and never sits on (or takes taps from) a
## HUD hex; E and SIC act on the selection only while its hex shows; no swords while it can be tamed;
## no E key cap while riding (E dismounts).
## Review r2: a press on the swords beside a bench fights (the click fallback opened the bench and
## dropped the selection); a tap on an animal beside a bench selects it; on a landscape phone the
## swords show whenever a clear spot touches the animal.
## Review r3: in a herd the hex sat on a neighbour and took the tap meant to select it; with the bag or
## the Animals screen open E fought an animal behind it; a selection with its swords hidden lingered;
## on a phone a selection alone took the quest card's centre band; the hex keeps off the survivor.
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
	await _test_offscreen()
	await _test_hud_wins()
	await _test_tame_and_mounted()
	await _test_beside_station()
	await _test_phone_coverage()
	await _test_herd()
	await _test_screens()
	await _test_drop()
	await _test_phone_quest()
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
	await _frames(3)
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

## A summoned pet (the whistle hexes show while one is out), its brain still so it stays put.
func _summon_pet():
	player.bonded.append(PetRecordS.from_def(data.creature(&"zebraceratops"), &"A"))
	var pet = player.pets.summon(player.bonded.size() - 1)
	pet.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	return pet

## Puts `c` where its middle (the hex's anchor) projects to `screen`.
func _place_mid(c, screen: Vector2) -> void:
	var h: float = c.def.height_meters * 0.5
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var hit: Vector3 = o + d * ((c.global_position.y + h - o.y) / d.y)
	c.global_position = Vector3(hit.x, c.global_position.y, hit.z)

func _sic_hex() -> Control:
	return (hud.get("_whistle_hexes") as Array)[0] as Control

## Clicks SIC; true when SIC ran (the pet's attack order) and the survivor started no hunt.
func _sic_ran(pet) -> bool:
	pet.brain.order(&"guard")
	_push_click(_sic_hex())
	await _frames(3)
	var ok: bool = pet.brain.mode == &"attack" and player.hunt.target == null
	player.hunt.stop()
	player.clear_nav()
	return ok

## Review r1 (probes F_far, X): an animal selected and then left off screen (26 m) still held E, and its
## hex pinned to the screen edge sat on SIC and took its tap, sending the survivor after it.
func _test_offscreen() -> void:
	var pet = await _summon_pet()
	var wild = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	await _frames(5)
	await _tap(wild.global_position + Vector3(0, 0.5, 0))
	await _frames(3)
	_expect(_selected() == wild and _swords_shown(), "off screen: selected on screen first, swords shown")
	wild.global_position = Vector3(27.0, 0, 0)  # in front of the camera, past the right edge, inside 28 m
	await _frames(4)
	var mid: Vector2 = cam.unproject_position(wild.global_position + Vector3(0, 0.5, 0))
	_expect(_selected() == wild and not cam.get_viewport().get_visible_rect().has_point(mid),
		"off screen: the selection holds while the animal is off screen (at %s)" % mid)
	_expect(not _swords_shown(), "off screen: no swords hex (shown at %s)" % (_swords().get_global_rect() if _swords_shown() else Rect2()))
	pet.global_position = player.global_position + Vector3(1.2, 0, 0)
	await _frames(2)
	_press(&"interact")
	await _frames(2)
	_expect(player.hunt.target == null, "off screen: E beside the pet does its own job, no hunt (hunt %s)" % [player.hunt.target])
	player.clear_nav()
	if player.pets.menu:
		player.pets.menu.visible = false
	_expect(await _sic_ran(pet), "off screen: a tap on SIC runs SIC and starts no hunt")
	await _clear()

## Review r1 (H_spot, [rv] OVERLAP): an animal beside the HUD put its hex on SIC / CLAIM / HANDS, and
## added after them it took their taps. Now it keeps off every HUD hex, and the HUD wins a shared spot.
func _test_hud_wins() -> void:
	var pet = await _summon_pet()
	var near = _creature(&"protoceratops", Vector3(-2.5, 0, 1.0))
	var wild = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	await _frames(5)
	await _tap(wild.global_position + Vector3(0, 0.5, 0))
	await _frames(3)
	_expect(_swords_shown(), "HUD: swords shown for the selection")
	_expect(_swords().get_index() < _sic_hex().get_index(), "HUD: the swords hex sits under the HUD hexes in tree order")
	# SIC with no fight and the swords on screen goes for the selection, not the nearer animal.
	pet.brain.order(&"guard")
	_push_click(_sic_hex())
	await _frames(3)
	_expect(pet.brain.order_target == wild and player.hunt.target == null,
		"SIC with the swords shown sics the selection (order %s, nearer %s)" % [pet.brain.order_target, near])
	near.queue_free()
	var sic := _sic_hex().get_global_rect()
	var overlaps := 0
	var bad_taps := 0
	for k in [36.0, 64.0, 92.0, 120.0, 148.0]:  # the old hex stood dx (36-140 px) right of the middle
		_place_mid(wild, sic.get_center() - Vector2(32.0 + k, 0.0))
		await _frames(4)
		if _swords_shown():
			for h in get_nodes_in_group(&"hex_button"):
				if h != _swords() and h.is_visible_in_tree() and h.hex_rect().intersects(_swords().hex_rect()):
					overlaps += 1
					print("[t_targetui] overlap k=%.0f swords %s with %s %s" % [k, _swords().hex_rect(), h.name, h.hex_rect()])
		if not await _sic_ran(pet):
			bad_taps += 1
	_expect(overlaps == 0, "HUD: beside SIC the swords never cover a HUD hex (%d overlaps)" % overlaps)
	_expect(bad_taps == 0, "HUD: every tap on SIC ran SIC, none started a hunt (%d did not)" % bad_taps)
	await _clear()

## Review r1: no swords beside an animal that can be field-tamed (FEED/NET own that state; a stray tap
## or E attacked it), and no E key cap while riding, where E dismounts.
func _test_tame_and_mounted() -> void:
	var pet = await _summon_pet()
	var wild = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	await _frames(5)
	await _tap(wild.global_position + Vector3(0, 0.5, 0))
	await _frames(3)
	_expect(_swords_shown() and _swords().get("_key_drawn") == true, "desktop: the swords show their E key cap")
	player.pets.mount(pet)
	await _frames(3)
	_expect(player.mounted_on == pet, "mounted: riding the zebraceratops")
	_expect(_swords_shown() and _swords().get("_key_drawn") == false, "mounted: the swords show, without the E key cap")
	player.dismount()
	await _frames(3)
	_expect(_swords().get("_key_drawn") == true, "dismounted: the E key cap is back")
	wild.health.hp = wild.health.max_hp * 0.2
	wild.statuses.apply(&"knockdown")
	await _frames(3)
	_expect(load("res://scripts/pets/field_tame.gd").can_attempt(wild) and _selected() == wild and not _swords_shown(),
		"knocked down and tameable: still selected, no swords")
	_press(&"interact")
	_expect(player.hunt.target == null, "knocked down and tameable: E does not attack it")
	await _clear()

## Review r2 (K probes): the deferred desktop-click fallback picked the bench within 96 px of the
## swords hex after the hex took the press, so the bench opened, the selection dropped and no fight
## started. Touch sends the same mouse press (emulate_mouse_from_touch).
func _test_beside_station() -> void:
	var wild = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	await _frames(5)
	await _tap(wild.global_position + Vector3(0, 0.5, 0))
	await _frames(3)
	_expect(_selected() == wild and _swords_shown(), "station: selected, swords shown")
	if not _swords_shown():
		await _clear()
		return
	# A workbench whose tap point (0.7 m up) projects right under the swords hex.
	var hc := _swords().get_global_rect().get_center()
	var o := cam.project_ray_origin(hc)
	var d := cam.project_ray_normal(hc)
	var hit: Vector3 = o + d * ((0.7 - o.y) / d.y)
	var st: Node3D = (load("res://scripts/world/craft_station.gd") as GDScript).make(&"workbench")
	host.add_child(st)
	st.global_position = Vector3(hit.x, 0.0, hit.z)
	await _frames(4)
	var menu: Control = player.station_craft.menu if player.station_craft else null
	var px := cam.unproject_position(st.global_position + Vector3(0, 0.7, 0)).distance_to(_swords().get_global_rect().get_center())
	_push_click(_swords())
	await _frames(4)
	_expect(player.hunt.target == wild and _selected() == wild and not (menu and menu.visible),
		"station: the swords %.0f px from a bench fight the selection (hunt %s, selection %s, bench menu %s)" % [px, player.hunt.target, _selected(), menu and menu.visible])
	if menu:
		menu.visible = false
	player.hunt.stop()
	player.clear_nav()
	player.controls.get("selection").clear()
	await _frames(3)
	var at: Vector3 = wild.global_position + Vector3(0, 0.5, 0)
	px = cam.unproject_position(st.global_position + Vector3(0, 0.7, 0)).distance_to(cam.unproject_position(at))
	await _tap(at)
	_expect(px < 96.0 and _selected() == wild and not (menu and menu.visible),
		"station: a tap on an animal %.0f px from a bench selects it (selection %s, bench menu %s)" % [px, _selected(), menu and menu.visible])
	if menu:
		menu.visible = false
	st.queue_free()
	await _clear()

## Review r2 (844x390 sweeps): the swords hid for an animal in plain view whenever its sides sat under
## the selection's own plate, the minimap or a hex cluster, and touch had no other way to fight. Now
## they show whenever a hex-sized spot clear of the HUD touches the animal's screen box.
func _test_phone_coverage() -> void:
	var start_size: Vector2i = get_root().size
	var start_canvas: Vector2i = get_root().content_scale_size
	get_root().size = Vector2i(844, 390)
	get_root().content_scale_size = Vector2i(844, 390)  # the 1:1 canvas DisplayMode gives a landscape phone
	await _frames(10)
	var view: Rect2 = cam.get_viewport().get_visible_rect()
	var safe := Rect2(Vector2(8, 8), view.size - Vector2(16, 16))
	var missed: Array[String] = []
	var boxed: Array[String] = []  # hidden, no clear spot touches the animal: the HUD covers it
	var shown := 0
	var cases := 0
	for species: StringName in [&"protoceratops", &"tyrannosaurus"]:
		for dist: float in [6.0, 12.0]:
			for i in 12:
				var ang := TAU * float(i) / 12.0
				var c = _creature(species, Vector3(cos(ang) * dist, 0.0, sin(ang) * dist))
				await _frames(2)
				player.controls.get("selection").select(c)
				await _frames(4)
				var mid: Vector2 = cam.unproject_position(c.global_position + Vector3(0, c.def.height_meters * 0.5, 0))
				if view.has_point(mid):
					cases += 1
					if _swords_shown():
						shown += 1
					elif _free_near(c, mid, safe):
						missed.append("%s %.0fm %d deg" % [species, dist, int(rad_to_deg(ang))])
					else:
						boxed.append("%s %.0fm %d deg at %s" % [species, dist, int(rad_to_deg(ang)), mid.round()])
				player.controls.get("selection").clear()
				c.queue_free()
				await _frames(2)
	print("[t_targetui] phone sweep: swords %d of %d on-screen cases, hidden with a clear spot: %s; hidden, no clear spot: %s" % [shown, cases, missed, boxed])
	_expect(cases >= 24 and missed.is_empty(), "phone: the swords show whenever a clear spot touches the animal (%d of %d shown, missed %s)" % [shown, cases, missed])
	get_root().size = start_size
	get_root().content_scale_size = start_canvas
	await _clear()

## A hex-sized spot (32 px grid) touching the animal's screen box, inside the safe view, clear of
## every HUD block and hex and not over the animal's middle.
func _free_near(c, mid: Vector2, safe: Rect2) -> bool:
	var box: Rect2 = load("res://scripts/ui/creature_plates.gd").creature_box(cam, c)
	if not box.has_area():
		box = Rect2(mid, Vector2.ZERO)
	var reach := box.grow(64.0).intersection(safe)
	var taken: Array = hud.taken_rects(PackedStringArray(["pill"]))
	var y := reach.position.y
	while y + 64.0 <= reach.end.y:
		var x := reach.position.x
		while x + 64.0 <= reach.end.x:
			var r := Rect2(x, y, 64.0, 64.0)
			var clear := not r.has_point(mid)
			for t: Rect2 in taken:
				clear = clear and not r.intersects(t.grow(2.0))
			if clear:
				return true
			x += 32.0
		y += 32.0
	return false

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

var _desk: Array[Vector2i] = []  # root and canvas size before a phone case

func _phone(on: bool) -> void:
	if on:
		_desk = [get_root().size, get_root().content_scale_size]
		get_root().size = Vector2i(844, 390)
		get_root().content_scale_size = Vector2i(844, 390)  # the 1:1 canvas DisplayMode gives a landscape phone
	else:
		get_root().size = _desk[0]
		get_root().content_scale_size = _desk[1]
	await _frames(10)

## The game's IsoCamera view (orthographic, size 17 as main.tscn, pitch -35.264, yaw 45) on the survivor.
func _iso(on: bool) -> void:
	if on:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 17.0
		cam.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
		cam.global_position = player.global_position + cam.global_basis.z * 40.0
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.position = Vector3(0, 12, 12)
		cam.look_at(Vector3.ZERO)

func _mid(c) -> Vector2:
	return cam.unproject_position(c.global_position + Vector3(0, c.def.height_meters * 0.5, 0))

## A real click at a viewport point: the GUI first (a HUD control or the swords hex takes it), then the world.
func _click_at(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = get_root().get_final_transform() * at
	move.global_position = move.position
	get_root().push_input(move)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = move.position
	click.global_position = move.position
	get_root().push_input(click)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	get_root().push_input(up)
	await _frames(3)

## Review r3 (herd probe, 844x390): five animals shoulder to shoulder; the hex beside one sat on a
## neighbour's middle, so the tap meant to select the neighbour pressed the swords and started a fight.
## Also the hex keeps off the survivor's figure wherever the selection stands round it.
func _test_herd() -> void:
	await _phone(true)
	_iso(true)
	var right := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var herd := []
	for i in 5:
		herd.append(_creature(&"protoceratops", Vector3(player.global_position.x, 0.0, player.global_position.z) + right * (3.2 + 1.6 * i)))
	await _frames(5)
	var sel = player.controls.get("selection")
	var wrong: Array[String] = []
	var covered := 0
	for i in herd.size():
		for j in herd.size():
			if i == j:
				continue
			sel.select(herd[i])
			await _frames(4)
			if _swords_shown() and _swords().get_global_rect().has_point(_mid(herd[j])):
				covered += 1
			await _click_at(_mid(herd[j]))
			if _selected() != herd[j] or player.hunt.target != null:
				wrong.append("%d->%d sel %s hunt %s" % [i, j, herd.find(_selected()), herd.find(player.hunt.target)])
			player.hunt.stop()
			player.clear_nav()
	print("[t_targetui] herd mids %s" % [herd.map(func (c) -> Vector2: return _mid(c).round())])
	_expect(covered == 0, "herd: the swords never sit on a neighbour's middle (%d did)" % covered)
	_expect(wrong.is_empty(), "herd: tapping a neighbour selects it, no fight (%d of 20 wrong: %s)" % [wrong.size(), wrong])
	for c in herd:
		c.queue_free()
	await _frames(3)
	var wild = _creature(&"protoceratops", Vector3(3.0, 0, 0))
	await _frames(3)
	sel.select(wild)
	var fig: Rect2 = hud.figure_rect()
	var on_fig := 0
	var shown := 0
	for ox in [-180.0, -120.0, -80.0, -40.0, 40.0, 80.0, 120.0]:
		for oy in [-40.0, 0.0, 40.0]:
			_place_mid(wild, fig.get_center() + Vector2(ox, oy))
			await _frames(3)
			if _swords_shown():
				shown += 1
				if _swords().hex_rect().intersects(hud.figure_rect()):
					on_fig += 1
	_expect(shown > 0 and on_fig == 0, "survivor: round the survivor the swords keep off its figure (%d of %d shown on it)" % [on_fig, shown])
	_iso(false)
	await _phone(false)
	await _clear()

## Review r3 (S_animals_open, U_bag_open): with a screen over the world the swords stayed live, so E
## fought an animal hidden behind the Animals screen and SIC still went for it.
func _test_screens() -> void:
	var pet = await _summon_pet()
	var near = _creature(&"protoceratops", Vector3(-2.0, 0, 1.0))
	var wild = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	await _frames(5)
	await _tap(wild.global_position + Vector3(0, 0.5, 0))
	await _frames(3)
	_expect(_selected() == wild and _swords_shown(), "screens: selected, swords shown")
	var inv = (load("res://scenes/ui/inventory.tscn") as PackedScene).instantiate()
	hud.get_parent().add_child(inv)
	inv.bind(player.inventory, player)
	player.ui = inv
	inv.visible = true
	await _frames(3)
	_expect(not _swords_shown(), "bag open: no swords")
	_press(&"interact")
	_expect(player.hunt.target == null, "bag open: E does not fight the selection behind it (hunt %s)" % [player.hunt.target])
	player.hunt.stop()
	player.clear_nav()
	inv.visible = false
	await _frames(3)
	_expect(_swords_shown(), "bag closed: the swords are back")
	hud.open_animals()
	await _frames(3)
	_expect(not _swords_shown(), "Animals open: no swords")
	_press(&"interact")
	_expect(player.hunt.target == null, "Animals open: E does not fight the selection behind it (hunt %s)" % [player.hunt.target])
	pet.brain.order(&"guard")
	player.pets.order(&"attack")
	_expect(pet.brain.order_target == near, "Animals open: SIC goes for the nearest animal, not the hidden selection (order %s)" % [pet.brain.order_target])
	hud.get("_animal_screen").close_screen()
	hud.call("_toggle_sheet", &"menu")
	await _frames(3)
	_expect(hud.sheet_open() and not _swords_shown(), "menu sheet open: no swords")
	hud.call("_close_sheet")
	player.ui = null
	inv.queue_free()
	await _clear()

## Review r3: a selection whose swords stay hidden (off screen here) lingered, holding the plate and E;
## past hunt range it held to 40 m. Now ~3 s hidden or past ATTACK_SEEK_RANGE drops it; the fight's own
## target stays selected so its swords return after End Combat.
func _test_drop() -> void:
	var wild = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	await _frames(5)
	await _tap(wild.global_position + Vector3(0, 0.5, 0))
	wild.global_position = Vector3(27.0, 0, 0)  # off screen, inside 28 m
	await _frames(4)
	_expect(_selected() == wild and not _swords_shown(), "drop: off screen the selection holds at first")
	await create_timer(3.4, true, true).timeout
	_expect(_selected() == null, "drop: hidden ~3 s, the selection drops (selection %s)" % [_selected()])
	wild.global_position = Vector3(3.5, 0, 0)
	player.controls.get("selection").select(wild)
	await _frames(3)
	player.actions.attack(wild)
	await create_timer(3.4, true, true).timeout
	_expect(player.hunt.target == wild and _selected() == wild, "drop: the fight's own target stays selected (selection %s)" % [_selected()])
	player.hunt.stop()
	player.clear_nav()
	await _frames(3)
	_expect(_swords_shown(), "drop: End Combat, its swords are back")
	wild.global_position = player.global_position + Vector3(0.0, 0.0, -29.0)
	await _frames(2)
	_expect(_selected() == null, "drop: past ATTACK_SEEK_RANGE (29 m) the selection drops (selection %s)" % [_selected()])
	await _clear()

## Review r3: on a landscape phone the selection's plate took the centre band from the quest card
## before any fight. A selection alone leaves the band to the quest card; the fight takes it.
func _test_phone_quest() -> void:
	await _phone(true)
	var wild = _creature(&"protoceratops", Vector3(3.5, 0, 0))
	await _frames(5)
	player.controls.get("selection").select(wild)
	await _frames(4)
	var blocks: Dictionary = hud.get("drawn_blocks")
	_expect(blocks.has("quest") and not blocks.has("plate") and _swords_shown(), "phone: a selection alone leaves the centre band to the quest card (quest %s, plate %s)" % [blocks.has("quest"), blocks.has("plate")])
	player.actions.attack(wild)
	await _frames(4)
	blocks = hud.get("drawn_blocks")
	_expect(blocks.has("plate") and not blocks.has("quest"), "phone: the fight's plate takes the band (plate %s, quest %s)" % [blocks.has("plate"), blocks.has("quest")])
	await _phone(false)
	await _clear()
