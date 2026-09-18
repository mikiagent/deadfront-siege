class_name HuntHud
extends Control
## Vitals, clock, status icons, tactics labels, fatigue inspector.

var player: Player
var _vitals: Label
var _clock: Label
var _tactics: Label
var _icons: HBoxContainer
var _fat_btn: Button
var _inspector: Panel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock = Label.new()
	_clock.position = Vector2(12, 36)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clock)
	_vitals = Label.new()
	_vitals.position = Vector2(12, 56)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vitals)
	_fat_btn = Button.new()
	_fat_btn.text = "FAT"
	_fat_btn.position = Vector2(12, 150)
	_fat_btn.custom_minimum_size = Vector2(96, 64)
	_fat_btn.pressed.connect(_toggle_inspector)
	add_child(_fat_btn)
	_tactics = Label.new()
	_tactics.position = Vector2(12, 220)
	_tactics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tactics)
	_icons = HBoxContainer.new()
	_icons.position = Vector2(12, 118)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icons)

func bind(p: Player) -> void:
	player = p

func _process(_delta: float) -> void:
	if player == null:
		return
	var v := player.vitals
	_clock.text = "%s  %s" % [Game.clock_label(), Game.phase_name()]
	_vitals.text = "HP %.0f/%.0f  EN %.0f  FAT %.0f%s  bag %d/%d  pets %d/%d  P%d  T%d  %s" % [
		v.health, v.effective_max_health(), v.energy, v.fatigue,
		" EXHAUSTED" if v.exhausted else "",
		player.inventory.used_slots(), player.inventory.slot_count,
		player.bonded.size(), Data.bonded_cap(), World.pioneer_level, World.t_stones,
		str(World.island_id) if World.island_id != &"" else "lab",
	]
	if player.hunt:
		_tactics.text = "1 %s   2 %s   3 %s   4 %s   %s" % [
			player.hunt.tactic_label(1), player.hunt.tactic_label(2),
			player.hunt.tactic_label(3), player.hunt.tactic_label(4),
			"HOLD" if player.hunt.hold else "CHASE",
		]
	_draw_icons()

func _toggle_inspector() -> void:
	if _inspector and is_instance_valid(_inspector):
		_inspector.queue_free()
		_inspector = null
		return
	_inspector = Panel.new()
	_inspector.position = Vector2(12, 220)
	_inspector.custom_minimum_size = Vector2(360, 220)
	add_child(_inspector)
	var lab := Label.new()
	lab.position = Vector2(12, 12)
	lab.custom_minimum_size = Vector2(336, 196)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines := PackedStringArray()
	lines.append("Fatigue sources")
	if player and player.vitals:
		var log: Dictionary = player.vitals.fatigue_log
		if log.is_empty():
			lines.append("(none yet)")
		else:
			for k in log.keys():
				lines.append("%s  %.1f" % [k, float(log[k])])
	lab.text = "\n".join(lines)
	_inspector.add_child(lab)

func _draw_icons() -> void:
	for c in _icons.get_children():
		c.queue_free()
	if player.statuses == null:
		return
	for inst in player.statuses.instances():
		var lab := Label.new()
		lab.text = "%s x%d %.0fs" % [inst.id, inst.stacks, inst.time_left]
		lab.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
		_icons.add_child(lab)
