extends SceneTree
## SADDLES (owner 2026-10-28: "make saddles something you need to craft and equip per dinosaur"):
## a saddle per size class is crafted through the real planner and takes its hide's natural colour;
## a tame wears it in its own equipment (PetRecord.gear); riding is refused without a fitting saddle
## (pet radial row, Animals button, mount itself) and allowed with one; the wrong size is refused; the
## saddle mesh shows on the dinosaur only while equipped, tinted; save/load keeps it and an old save
## (no gear) loads; taking the saddle off the ridden tame dismounts her safely; the Gear sheet equips and
## unequips by tap and keeps every target >= 64 px.
## Usage: godot --headless --path game --script res://tests/t_saddles.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var hud
var data: Node
var PR: GDScript
var IS: GDScript
var CR: GDScript
var PG: GDScript

const TINT := "#8a3a22"  # a reddish hide (spec 35)

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	PR = load("res://scripts/pets/pet_record.gd")
	IS = load("res://scripts/items/item_stack.gd")
	CR = load("res://scripts/items/crafting.gd")
	PG = load("res://scripts/pets/pet_gear.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_saddles] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_test_sizes()
	_test_craft()
	_test_save()
	host = Node3D.new()
	host.name = "TSaddles"
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
	hud = (load("res://scripts/ui/hunt_hud.gd") as GDScript).new()
	hud.bind(player)
	ui_layer.add_child(hud)
	await _frames(10)
	await _test_ride_gate()
	await _test_sheet()
	host.queue_free()
	await _frames(2)
	if failures.is_empty():
		print("[t_saddles] PASS")
		quit(0)
	else:
		print("[t_saddles] FAIL %d: %s" % [failures.size(), failures])
		quit(1)

func _test_sizes() -> void:
	_expect(PR.saddle_size(data.creature(&"zebraceratops")) == &"small", "zebraceratops takes a small saddle")
	_expect(PR.saddle_size(data.creature(&"velociraptor")) == &"medium", "velociraptor takes a medium saddle")
	_expect(PR.saddle_size(data.creature(&"tyrannosaurus")) == &"large", "tyrannosaurus takes a large saddle")

## One recipe per class through the real planner; the saddle carries the primary hide's tint.
func _test_craft() -> void:
	for sz in ["small", "medium", "large"]:
		var rec: Dictionary = CR.recipe(StringName("saddle_" + sz))
		_expect(not rec.is_empty(), "recipe saddle_%s exists" % sz)
		if rec.is_empty():
			continue
		var inv = load("res://scripts/items/inventory.gd").new(40)
		for slot in rec["slots"]:
			var cat := str(slot["category"])
			var id: StringName = {"dried_hide": &"dried_hide", "cured_hide": &"dried_hide", "fibre": &"fibre_stalk", "lashing": &"hide_strap", "wood": &"branch", "bone": &"bone"}.get(cat, &"")
			for n in int(slot["count"]):
				inv.add(IS.make(id, 1, {"tint": TINT} if bool(slot.get("primary", false)) else {}, 5))
		var picks: Array[int] = CR.default_picks(inv, rec)
		var plan: Dictionary = CR.plan_craft(rec, inv, picks, 999.0, 5, 60, RandomNumberGenerator.new())
		_expect(not plan.is_empty(), "saddle_%s plans from its materials (picks %s)" % [sz, picks])
		if plan.is_empty():
			continue
		plan["outcome"] = {"success": true}
		plan["burnt"] = false
		var res: Dictionary = CR.run_plan(rec, inv, plan)
		var out = res.get("item")
		_expect(out != null and out.def_id == StringName("saddle_" + sz), "crafted a %s saddle (%s)" % [sz, res.get("status")])
		if out:
			_expect(out.tint_color().is_equal_approx(Color(TINT)), "the %s saddle has its hide's colour (%s)" % [sz, out.attributes.get("tint")])

func _test_save() -> void:
	var rec = PR.from_def(data.creature(&"velociraptor"), &"A")
	_expect(rec.gear.is_empty() and rec.ride_refusal() == "Needs a saddle", "a new tame has no saddle and cannot be ridden (%s)" % rec.ride_refusal())
	var s = IS.make(&"saddle_medium", 1, {"tint": TINT}, 7)
	s.uid = "l00ab12cd"
	rec.gear.put(&"saddle", s)
	var row: Dictionary = JSON.parse_string(JSON.stringify(rec.to_dict()))
	var clean: Dictionary = load("res://scripts/core/save_sanitizer.gd").clean({"pets": [row]})
	var back = PR.from_dict(clean["pets"][0])
	var b = back.saddle()
	_expect(b != null and b.def_id == &"saddle_medium" and b.level == 7 and b.uid == "l00ab12cd" and b.tint_color().is_equal_approx(Color(TINT)),
		"save/load keeps the saddle, its level, uid and colour")
	_expect(back.ride_refusal() == "", "the loaded tame can be ridden")
	row.erase("gear")
	var old = PR.from_dict(row)
	_expect(old != null and old.gear.is_empty() and old.ride_refusal() == "Needs a saddle", "an old save (no gear) loads with no saddle")
	row["gear"] = {"saddle": {"id": "berries"}, "hat": {"id": "saddle_small"}}
	var forged = PR.from_dict(load("res://scripts/core/save_sanitizer.gd").clean({"pets": [row]})["pets"][0])
	_expect(forged.gear.is_empty(), "a non-saddle or an unknown slot in gear is dropped")

func _saddle_shown(c) -> bool:
	return not c.view.saddle_meshes().is_empty()

func _test_ride_gate() -> void:
	var rec = PR.from_def(data.creature(&"velociraptor"), &"A")
	player.bonded.append(rec)
	var c = player.pets.summon(player.bonded.size() - 1)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	_expect(not _saddle_shown(c), "no saddle mesh on an unsaddled tame")
	var ride_row := {}
	for row in player.pets.entries(c):
		if row["id"] == &"ride":
			ride_row = row
	_expect(ride_row.get("label", "") == "Needs a saddle" and ride_row.get("disabled", false), "the pet radial's ride row says Needs a saddle (%s)" % [ride_row])
	_expect(player.pets.entries(c).any(func (r: Dictionary) -> bool: return r["id"] == &"gear"), "the pet radial offers Gear")
	player.mount(c)
	_expect(player.mounted_on == null, "riding is refused without a saddle")
	# The wrong size from the bag is refused and stays in the bag.
	var small = IS.make(&"saddle_small", 1, {"tint": TINT})
	player.inventory.add(small)
	var si: int = player.inventory.find_first(&"saddle_small")
	var why: String = PG.equip(player, rec, si)
	_expect(why == "Needs a medium saddle" and rec.saddle() == null and player.inventory.find_first(&"saddle_small") == si, "a small saddle is refused on a velociraptor (%s)" % why)
	# A wrong-size saddle put there by hand (a forged save) still refuses the ride.
	rec.gear.put(&"saddle", IS.make(&"saddle_large"))
	player.mount(c)
	_expect(player.mounted_on == null, "riding is refused with the wrong size on")
	rec.gear.put(&"saddle", null)
	# The fitting one equips from the bag, shows tinted, and rides.
	player.inventory.add(IS.make(&"saddle_medium", 1, {"tint": TINT}))
	var mi: int = player.inventory.find_first(&"saddle_medium")
	why = PG.equip(player, rec, mi)
	_expect(why == "" and rec.saddle() != null and player.inventory.find_first(&"saddle_medium") < 0, "a medium saddle equips from the bag (%s)" % why)
	await _frames(2)
	_expect(_saddle_shown(c), "the saddle mesh shows once equipped (not riding)")
	var tinted := false
	for m in c.view.saddle_meshes():
		for i in m.mesh.get_surface_count():
			var o = m.get_surface_override_material(i)
			if o is StandardMaterial3D and (o as StandardMaterial3D).albedo_color.is_equal_approx(Color(TINT)):
				tinted = true
	_expect(tinted, "the saddle leather is tinted by its material")
	player.mount(c)
	await _frames(3)
	_expect(player.mounted_on == c, "riding is allowed with a fitting saddle")
	# Unequip while riding: dismount first, through the dismount path, then the saddle comes off.
	why = PG.unequip(player, rec)
	await _frames(3)
	_expect(why == "" and player.mounted_on == null and player.get_parent() == host and player.inventory.find_first(&"saddle_medium") >= 0,
		"unequip while riding dismounts and returns the saddle (%s, parent %s)" % [why, player.get_parent().name])
	_expect(absf(player.global_position.y) < 2.0 and is_zero_approx(player.global_rotation.y), "she lands beside the tame, not in the air (y=%.2f)" % player.global_position.y)
	_expect(not _saddle_shown(c), "the saddle mesh is gone once unequipped")
	# A new summon of a saddled tame shows its saddle straight away.
	rec.gear.put(&"saddle", IS.make(&"saddle_medium"))
	player.pets.dismiss(c)
	await _frames(2)
	var c2 = player.pets.summon(player.bonded.find(rec))
	await _frames(3)
	_expect(c2 != null and _saddle_shown(c2), "a saddled tame summoned again wears its saddle")

func _test_sheet() -> void:
	var rec = player.bonded[0]
	rec.gear.put(&"saddle", null)
	player.inventory.add(IS.make(&"saddle_medium", 1, {"tint": TINT}))
	for vs in [Vector2i(1600, 900), Vector2i(844, 390)]:
		get_root().size = vs
		await _frames(2)
		var sheet = hud.open_pet_gear(rec)
		await _frames(4)
		_expect(sheet != null and sheet.visible, "Gear opens at %s" % vs)
		var cell = sheet.find_child("Cell*", true, false)
		_expect(cell != null, "the bag saddle is listed")
		_expect(sheet.min_target_px() >= 63.5, "every Gear target >= 64 px at %s (%.0f)" % [vs, sheet.min_target_px()])
		if cell:
			cell.pressed.emit()
			await _frames(2)
		_expect(rec.saddle() != null, "tapping a bag saddle equips it")
		var un = sheet.find_child("Unequip", true, false)
		if un:
			un.pressed.emit()
			await _frames(2)
		_expect(rec.saddle() == null and player.inventory.find_first(&"saddle_medium") >= 0, "Unequip puts it back in the bag")
		sheet.close()
