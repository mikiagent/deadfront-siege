class_name HuntHud
extends Control
## Vitals, status icons, tactics labels.

var player: Player
var _vitals: Label
var _tactics: Label
var _icons: HBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals = Label.new()
	_vitals.position = Vector2(12, 40)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vitals)
	_tactics = Label.new()
	_tactics.position = Vector2(12, 120)
	_tactics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tactics)
	_icons = HBoxContainer.new()
	_icons.position = Vector2(12, 88)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icons)

func bind(p: Player) -> void:
	player = p

func _process(_delta: float) -> void:
	if player == null:
		return
	var v := player.vitals
	_vitals.text = "HP %.0f/%.0f  EN %.0f  FAT %.0f%s  bag %d/%d  pets %d/%d  scale x%.0f" % [
		v.health, v.effective_max_health(), v.energy, v.fatigue,
		" EXHAUSTED" if v.exhausted else "",
		player.inventory.used_slots(), player.inventory.slot_count,
		player.bonded.size(), Data.bonded_cap(), Game.time_scale,
	]
	if player.hunt:
		_tactics.text = "1 %s   2 %s   3 %s   4 %s   %s" % [
			player.hunt.tactic_label(1), player.hunt.tactic_label(2),
			player.hunt.tactic_label(3), player.hunt.tactic_label(4),
			"HOLD" if player.hunt.hold else "CHASE",
		]
	_draw_icons()

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
