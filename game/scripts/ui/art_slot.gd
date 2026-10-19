class_name ArtSlot
extends Button
## Inventory-style slot whose rendered item art rises above the slot top edge,
## framed by a rarity-coloured rim and soft glow. Count sits bottom-right.
## A Button so focus, touch and InputMap gamepad confirm all work unchanged.

const MIN_SIZE := 64.0  # mobile tap floor
const RISE := 0.16      # art top sits 16 % of the slot height above the slot (spec: 12-20 %)

var item_id: StringName = &""
var count: int = 0
var rim: Color = Color(0.66, 0.68, 0.70)

func _init() -> void:
	custom_minimum_size = Vector2(MIN_SIZE, MIN_SIZE)
	flat = true  # we draw the frame ourselves
	focus_mode = Control.FOCUS_ALL
	clip_contents = false

func set_item(id: StringName, p_count: int = 1) -> void:
	item_id = id
	count = p_count
	rim = ItemArt.rim_color(id) if id != &"" else Color(0.4, 0.4, 0.4)
	var def: ItemDef = Data.item(id) if id != &"" else null
	tooltip_text = def.display_name if def else str(id)
	queue_redraw()

## Where the object's opaque pixels land: fitted into a box that starts RISE above the slot
## top and ends near the slot floor, centred, top-anchored so every item pops out of the frame.
func art_rect() -> Rect2:
	var s := minf(size.x, size.y)
	var box := Rect2(Vector2(size.x * 0.06, -s * RISE), Vector2(size.x * 0.88, s * (RISE + 0.80)))
	var src := ItemArt.content_rect(item_id) if item_id != &"" else Rect2()
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return box
	var k := minf(box.size.x / src.size.x, box.size.y / src.size.y)
	var dst := src.size * k
	return Rect2(Vector2(box.position.x + (box.size.x - dst.x) * 0.5, box.position.y), dst)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.05, 0.055, 0.062, 0.94)
	glow.set_corner_radius_all(UiTokens.RADIUS)
	glow.set_border_width_all(3 if has_focus() or button_pressed else 2)
	glow.border_color = rim
	glow.shadow_color = Color(rim, 0.55 if item_id != &"" else 0.0)
	glow.shadow_size = int(maxf(6.0, size.y * 0.12))
	draw_style_box(glow, r)
	# Rarity wash in the lower half so the floor of the slot reads as the rim colour.
	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(rim, 0.22)
	wash.set_corner_radius_all(UiTokens.RADIUS)
	draw_style_box(wash, Rect2(Vector2(0, size.y * 0.45), Vector2(size.x, size.y * 0.55)).grow(-2))
	if item_id == &"":
		return
	var tex := ItemArt.texture_for(item_id)
	if tex:
		draw_texture_rect_region(tex, art_rect(), ItemArt.content_rect(item_id))
	if count > 1:
		var font := get_theme_default_font()
		var fs := maxi(12, int(size.y * 0.2))
		var txt := "x%d" % count
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(size.x - w - 6, size.y - 6)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTokens.TEXT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
