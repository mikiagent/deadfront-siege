extends SceneTree
## CREATURECHIPS acceptance (owner: "bleed on dinosaurs doesn't show stacks count and doesnt match the
## player's bleed", and the floating BLEED overlapped the plate's name): a creature's active statuses
## draw on BOTH the creature plate and the hunt target bar through the player's chip renderer
## (HudBuffRow.draw_chip) with the numbered stack badge — a 3-stack bleed reports stack count 3 from the
## same entries helper the player's row uses — and a status floater's rect never intersects the plate's
## name rect.
## Usage: godot --headless --path game --script res://tests/t_creaturechips.gd -> "[t_creaturechips] PASS"

var failures: Array[String] = []
var _started := false
var host: Node3D
var cam: Camera3D
var player
var hud
var data: Node

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_creaturechips] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	host = Node3D.new()
	host.name = "TCreatureChips"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(80, 1, 80)
	fs.shape = bs
	floor.add_child(fs)
	host.add_child(floor)
	cam = Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 12, 0)
	cam.look_at_from_position(Vector3(0, 12, 12), Vector3.ZERO)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	var ui_layer := CanvasLayer.new()
	get_root().add_child(ui_layer)
	hud = (load("res://scripts/ui/hunt_hud.gd") as GDScript).new()
	hud.bind(player)
	ui_layer.add_child(hud)
	data = get_root().get_node("Data")
	await _frames(5)

	var plates: Node = (load("res://scripts/ui/creature_plates.gd") as GDScript).new()
	host.add_child(plates)

	# --- a creature with 3 bleed stacks
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = Vector3(3.5, 0, 0)
	host.add_child(c)
	c.spawn(data.creature(&"protoceratops"))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	c.statuses.apply(&"bleed_3")
	await _frames(3)
	var inst = c.statuses.get_instance(&"bleed")
	_expect(inst != null and inst.stacks == 3, "the creature holds 3 bleed stacks (got %s)" % (str(inst.stacks) if inst else "none"))

	# The shared entries helper: the same shape and stack count the player's row draws from.
	var RW: GDScript = load("res://scripts/ui/hud_buff_row.gd")
	var entries: Array = RW.creature_entries(c)
	_expect(entries.size() == 1, "creature_entries lists the bleed once (%d rows)" % entries.size())
	if not entries.is_empty():
		var e: Dictionary = entries[0]
		_expect(int(e.get("stacks", 0)) == 3, "the entry reports stack count 3 (got %s)" % str(e.get("stacks", 0)))
		_expect(str(e.get("icon", "")) == "bleed", "the entry carries the bleed icon id (%s)" % str(e.get("icon", "")))
		# The plate's chips are the player's chip renderer with the badge.
		var key := c.get_instance_id()
		var pe: Dictionary = plates._entries.get(key, {})
		var line3 := pe.get("line3", null) as Control
		var found := false
		if line3:
			for g in line3.get_children():
				if g is Control and (g as Control).visible and (g as Control).get_script() == load("res://scripts/ui/creature_plate_chip.gd"):
					var chip := g as Control
					_expect(chip.get("stacks") == 3, "the plate chip shows the stack badge for 3 stacks (got %s)" % str(chip.get("stacks")))
					_expect(chip.size.x >= RW.CHIP and chip.size.y >= RW.CHIP, "the plate chip is the player's chip size (%s)" % str(chip.size))
					found = true
		_expect(found, "the plate draws its statuses through the player's chip renderer")

	# --- the hunt target bar: same renderer, same stack badge
	player.actions.attack(c)
	await _frames(4)
	var rows: Dictionary = hud.get("target_rows")
	var chips: Dictionary = rows.get("chips", {}) if rows is Dictionary else {}
	_expect(chips.has("bleed"), "the target bar draws the bleed chip (%s)" % str(chips.keys()))
	if chips.has("bleed"):
		var box: Rect2 = chips["bleed"]
		_expect(box.size.x >= RW.CHIP and box.size.y >= RW.CHIP, "the target bar chip is the player's chip size (%s)" % str(box.size))
	_expect((hud.get("drawn_blocks") as Dictionary).has("plate"), "the target plate shows for the fight")
	var src := FileAccess.get_file_as_string("res://scripts/ui/hunt_hud.gd")
	var plate_src := FileAccess.get_file_as_string("res://scripts/ui/creature_plates.gd")
	_expect(src.contains("HudBuffRow.creature_entries") and plate_src.contains("HudBuffRow.creature_entries"),
		"plate and target bar both take their entries from the shared helper")
	_expect(not src.contains("HudStatusChip.draw_named"), "the target bar no longer draws the old named pill")
	_expect(not plate_src.contains("STATUS_GLYPH_SCRIPT"), "the plate no longer draws the old glyph ring")

	# --- the status floater clears the plate's name line
	var pe2: Dictionary = plates._entries.get(c.get_instance_id(), {})
	var line1 := pe2.get("line1", null) as Label
	var floats := pe2.get("floats", null) as Control
	if line1 and floats:
		plates._on_status_float(&"bleed", c)
		await _frames(2)
		var latin: Font = (ThemeDB.fallback_font as FontVariation).base_font if ThemeDB.fallback_font is FontVariation else ThemeDB.fallback_font
		var name_r := Rect2(line1.position, Vector2(line1.size.x, latin.get_height(14)))
		var hit := false
		var floater_r := Rect2()
		for f in floats.get_children():
			var lb := f as Label
			if lb == null or not lb.visible:
				continue
			floater_r = Rect2(lb.position, Vector2(lb.size.x, latin.get_height(lb.get_theme_font_size("font_size"))))
			if floater_r.intersects(name_r):
				hit = true
		_expect(not hit and floater_r.has_area(), "the status floater's rect %s stays clear of the name rect %s" % [floater_r, name_r])

	# --- the damage-number colour rule: a status's damage colour is its own colour, green is healing only
	var CR: GDScript = load("res://scripts/creatures/creature.gd")
	_expect((CR.STATUS_COLORS["bleed"] as Color).r > 0.8 and (CR.STATUS_COLORS["bleed"] as Color).g < 0.5,
		"bleed's floater colour is red (its status colour), not green")
	_expect((CR.STATUS_COLORS["venom"] as Color).g > 0.8, "venom keeps its own colour")

	host.queue_free()
	plates.queue_free()
	if failures.is_empty():
		print("[t_creaturechips] PASS")
		quit(0)
	else:
		print("[t_creaturechips] FAIL count=%d" % failures.size())
		quit(1)
