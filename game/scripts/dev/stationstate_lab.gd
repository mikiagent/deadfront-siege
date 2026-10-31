extends Node3D
## STATIONSTATE lab: a small late-game base, idle or busy (owner 2026-10-28 reference): a stone grill
## (spit only while roasting), a drying rack, a forge (glow + sparks only while working), two farm
## plots (crop stages + harvest timer), a large taming pen with an ankylosaurus overhanging its fence,
## and a workbench worksite (dirt patch + grey symbol + progress).
## Windowed: --lab=stationstate_lab --shot=<png> --state=idle|busy [--view=all|pen|stations]

var _player: Player
var _cam: IsoCamera

func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return fallback

func _ready() -> void:
	CreatureDef.allow_placeholder = true  # NOBOXES: this lab may show model-less species as boxes
	ProcessStation.clock_skew_s = 0.0
	var kit := LabKit.build(self, 60.0)
	_player = kit["player"]
	_cam = kit["cam"]
	var busy := _arg("state", "busy") == "busy"
	StationState.lab_force_busy = busy
	_station(&"stone_grill", Vector3(-3.0, 0, 0))
	var rack := _station(&"drying_rack", Vector3(0.0, 0, -0.4))
	var forge := _station(&"forge", Vector3(3.0, 0, 0))
	var f1 := FieldPlot.make(&"field_small")
	f1.position = Vector3(-3.0, 0, 4.0)
	add_child(f1)
	var f2 := FieldPlot.make(&"field_small")
	f2.position = Vector3(0.0, 0, 4.0)
	add_child(f2)
	var pen := TamingPen.make(&"taming_pen_large")
	pen.position = Vector3(8.5, 0, 4.0)
	add_child(pen)
	var small := TamingPen.make(&"makeshift_taming_pen")
	small.position = Vector3(-4.0, 0, 10.0)
	add_child(small)
	var site := ConstructionSite.new()
	site.setup(&"basic_workbench", "lab")
	site.grid_kind = &"workbench"
	site.position = Vector3(3.6, 0, 4.2)
	add_child(site)
	if busy:
		var inv := Inventory.new(24)
		inv.add(ItemStack.make(&"raw_meat", 6))
		ProcessStation.of(rack).load_from(inv, &"dry_meat", 4)
		f1.crop_id = &"corn"
		f1.growth = 0.42
		f2.crop_id = &"wheat"
		f2.growth = 1.0
		f2.mature = true
		# No ankylosaurus model exists yet (it draws as the long placeholder box), so the shot uses
		# species with models: a utahraptor (11 m) in the 6 m large pen, a velociraptor (6 m) in the 4 m one.
		_pen_animal(pen, "utahraptor", 50, 1453.0)
		_pen_animal(small, "velociraptor", 25, 610.0)
	print("[stationstate_lab] state=%s forge=%s" % ["busy" if busy else "idle", forge.name])
	call_deferred("_frame")

func _pen_animal(pen: TamingPen, sp: String, lvl: int, left: float) -> void:
	var cap := ItemStack.make(&"captured_animal", 1)
	cap.attributes["species"] = sp
	cap.attributes["level"] = lvl
	pen.occupant = cap
	pen.remaining = left
	pen.running = true

func _station(id: StringName, at: Vector3) -> CraftStation:
	var s := CraftStation.make(id)
	s.position = at
	add_child(s)
	return s

func _frame() -> void:
	await get_tree().process_frame
	var view := _arg("view", "all")
	var focus := Node3D.new()
	focus.position = Vector3(2.0, 0, 4.5) if view == "all" else (Vector3(8.5, 0, 4.0) if view == "pen" else Vector3(0, 0, 0.0))
	add_child(focus)
	_player.global_position = Vector3(-6.0, 0.2, 7.5)
	_cam._target = focus
	_cam.size = _cam.default_size * (1.3 if view == "all" else 0.45)
	_cam._snap()
