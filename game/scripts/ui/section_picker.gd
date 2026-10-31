class_name SectionPicker
extends Control
## PARTCOMBAT section picker on the target card: while she fights an animal with hurtboxes, one 64 px "AIM" chip under the
## top target bar shows the picked body section ("Auto" = none). A tap opens a grid of that animal's sections (64 px
## buttons; armoured ones say ARMOUR, ones holding a crit spot say WEAK, a Wound or Armor break says so); a tap on one
## picks it (Hunt.set_aim_section: ranged shots aim there, melee steers its swings there) and the section glows on the
## animal (SectionHighlight). Tapping the animal's body in the world picks the section under the finger too.

const CHIP := Vector2(196, 64)
const CELL := Vector2(120, 64)
const COLS := 6

var player: Player
var _chip: Button
var _grid: GridContainer
var _shown_for: Creature
var _top := 128.0

func setup(p: Player) -> void:
	player = p
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip = Button.new()
	_chip.name = "AimChip"
	_chip.custom_minimum_size = CHIP
	_chip.focus_mode = Control.FOCUS_NONE
	_chip.add_theme_font_size_override("font_size", 20)
	_chip.pressed.connect(func() -> void: open(not _grid.visible))
	add_child(_chip)
	_grid = GridContainer.new()
	_grid.name = "SectionGrid"
	_grid.columns = COLS
	_grid.visible = false
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)

func target() -> Creature:
	var t: Creature = player.hunt.target if player and player.hunt and player.hunt.target and is_instance_valid(player.hunt.target) else null
	return t if t and not t.health.dead and Hurtboxes.of(t) else null

func open(on: bool) -> void:
	_grid.visible = on and target() != null
	if _grid.visible:
		_fill(target())

func _fill(t: Creature) -> void:
	for ch in _grid.get_children():
		ch.queue_free()
	var crits := BodySections.crit_sections(t)
	var secs: Array[StringName] = [&""]
	secs.append_array(BodySections.names(t))
	for s in secs:
		var b := Button.new()
		b.custom_minimum_size = CELL
		b.focus_mode = Control.FOCUS_NONE
		var tags := []
		if s != &"" and BodySections.is_armoured(t, s):
			tags.append("BROKEN" if BodyWounds.has(t, s, BodyWounds.BREAK) else "ARMOUR")
		if s != &"" and BodyWounds.has(t, s, BodyWounds.WOUND):
			tags.append("WOUND")
		elif s in crits:
			tags.append("WEAK")
		b.text = ("Auto" if s == &"" else BodySections.label(s)) + ("\n" + " ".join(tags) if not tags.is_empty() else "")
		b.add_theme_font_size_override("font_size", 16)
		if s == player.hunt.aim_section:
			b.modulate = Color(0.6, 1.0, 1.0)
		b.pressed.connect(func() -> void:
			player.hunt.set_aim_section(s)
			open(false))
		_grid.add_child(b)

func _process(_d: float) -> void:
	var t := target()
	_chip.visible = t != null
	if t != _shown_for:
		if _shown_for != null:
			_grid.visible = false  # a new target closes the grid
		_shown_for = t
	if t == null:
		_grid.visible = false
		return
	var sec := player.hunt.aim_section
	_chip.text = "AIM: %s" % ("Auto" if sec == &"" else BodySections.label(sec))
	var w := get_viewport_rect().size.x
	_chip.position = Vector2(w * 0.5 - CHIP.x * 0.5, _top)
	_grid.position = Vector2(w * 0.5 - (CELL.x * COLS + 6 * (COLS - 1)) * 0.5, _top + CHIP.y + 6)
