class_name ItemArtLab
extends Node
## --lab=item_art_lab: a 5x4 ArtSlot grid covering every rarity, with a row of white
## HUD action hexes beside it to show ArtSlot leaves action glyphs untouched.
## Headless (no --shot) it self-checks and quits 0/1.

const IDS: Array[StringName] = [
	&"copper_ingot", &"bronze_ingot", &"iron_ingot", &"steel_ingot", &"straw_roll_kit",
	&"raid_maul", &"raid_helm", &"raid_cuirass", &"black_iron", &"obsidian",
	&"pearl", &"work_axe", &"work_pick", &"stone_knife", &"slingshot",
	&"berries", &"mango", &"fish", &"workbench_kit", &"rope",
]

var slots: Array[ArtSlot] = []

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.19, 0.17)  # muted ground green, close to the island behind the HUD
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var view := get_viewport().get_visible_rect().size
	# canvas_items stretch: a portrait phone gets a tall logical view, so size by width share.
	var portrait := view.y > view.x
	var side := maxf(ArtSlot.MIN_SIZE, floorf(view.x * (0.92 if portrait else 0.45) / 5.6))
	var gap := floorf(side * 0.15)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(gap * 2.0))
	box.position = Vector2(maxf(12.0, (view.x - (side * 5.0 + gap * 4.0)) * 0.5), side * (0.4 + ArtSlot.RISE))
	layer.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap + side * ArtSlot.RISE))
	box.add_child(grid)
	for i in IDS.size():
		var s := ArtSlot.new()
		s.custom_minimum_size = Vector2(side, side)
		s.set_item(IDS[i], [1, 3, 12, 1, 5][i % 5])
		grid.add_child(s)
		slots.append(s)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", int(gap))
	box.add_child(actions)
	for spec in [["≡", "MENU"], ["★", "SKILLS"], ["⌂", "BUILD"], ["♞", "ANIMALS"]]:
		var h := HexButton.new(maxf(64.0, side * 0.7))
		h.glyph = spec[0]
		h.caption = spec[1]
		actions.add_child(h)
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		await get_tree().process_frame
		await get_tree().process_frame
		_self_check()

func _self_check() -> void:
	var seen := {}
	var rendered := 0
	var overflow_ok := true
	var count_ok := true
	for s in slots:
		seen[ItemArt.rarity(s.item_id)] = true
		rendered += 1 if ItemArt.is_rendered(s.item_id) else 0
		overflow_ok = overflow_ok and _framed(s)
		var px := s.count_font_size() * s.get_screen_transform().get_scale().y
		count_ok = count_ok and px >= ArtSlot.COUNT_PX - 0.5
	var ok := slots.size() == 20 and seen.size() == ItemArt.rarity_order().size() and rendered == 20 and overflow_ok and count_ok
	print("[itemart] slots=%d rarities=%d rendered=%d framed=%s count_px_ok=%s ok=%s" % [slots.size(), seen.size(), rendered, overflow_ok, count_ok, ok])
	get_tree().quit(0 if ok else 1)

## Every lab object (wide ones included) rises 12-20 % above the slot, its centre inside the
## slot and its bottom on or at most HOVER above the slot floor.
static func _framed(s: ArtSlot) -> bool:
	var r := s.art_rect()
	var lift := -r.position.y / s.size.y
	var centred := Rect2(Vector2.ZERO, s.size).has_point(r.get_center())
	var bottom := r.end.y / s.size.y
	var floor_ok := bottom <= ArtSlot.FLOOR + 0.005 and bottom >= ArtSlot.FLOOR - ArtSlot.HOVER - 0.005
	return centred and floor_ok and lift <= 0.20 + 0.005 and lift >= 0.12 - 0.005
