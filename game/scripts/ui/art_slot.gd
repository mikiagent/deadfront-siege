class_name ArtSlot
extends Button
## Inventory-style slot whose rendered item art rises above the slot top edge,
## framed by a rarity-coloured rim and soft glow. Count sits bottom-right.
## A Button so focus, touch and InputMap gamepad confirm all work unchanged.

const MIN_SIZE := 64.0  # mobile tap floor
const RISE := 0.16      # art top sits 16 % of the slot height above the slot (spec: 12-20 %)
const RISE_MIN := 0.12 # spec floor for the rise: wide items lift until they reach it
const FLOOR := 0.80     # art bottom sits here, so every object stands on the same slot floor
const HOVER := 0.20     # a wide item may lift its bottom this far off FLOOR to reach RISE_MIN
const COUNT_PX := 14.0  # stack count floor in physical pixels (GAUNTLET: no illegible metadata)

var item_id: StringName = &""
var count: int = 0
var rim: Color = Color(0.66, 0.68, 0.70)
var _glow := StyleBoxFlat.new()  # cached: _draw runs for every slot on every redraw
var _wash := StyleBoxFlat.new()

func _init() -> void:
	custom_minimum_size = Vector2(MIN_SIZE, MIN_SIZE)
	flat = true  # we draw the frame ourselves
	focus_mode = Control.FOCUS_ALL
	clip_contents = false
	_glow.bg_color = Color(0.05, 0.055, 0.062, 0.94)
	_glow.set_corner_radius_all(UiTokens.RADIUS)
	_wash.set_corner_radius_all(UiTokens.RADIUS)
	_apply_rim()

func _apply_rim() -> void:
	_glow.border_color = rim
	_glow.shadow_color = Color(rim, 0.55 if item_id != &"" else 0.0)
	_wash.bg_color = Color(rim, 0.22)

func set_item(id: StringName, p_count: int = 1) -> void:
	item_id = id
	count = p_count
	rim = ItemArt.rim_color(id) if id != &"" else Color(0.4, 0.4, 0.4)
	var def: ItemDef = Data.item(id) if id != &"" else null
	tooltip_text = def.display_name if def else str(id)
	_apply_rim()
	queue_redraw()

## Where the object's opaque pixels land. Tall items stand on FLOOR and their top rises RISE
## above the slot. Wide items may use the full slot width (never past the rim) and lift off the
## floor (at most HOVER) until their top rises RISE_MIN; art wider than ~1.39:1 cannot, so the
## art builders stage flat items on a diagonal (kit.upright) or as a stack instead.
func art_rect() -> Rect2:
	var s := minf(size.x, size.y)
	var box := Rect2(Vector2(size.x * 0.06, -s * RISE), Vector2(size.x * 0.88, s * (RISE + FLOOR)))
	var src := ItemArt.content_rect(item_id) if item_id != &"" else Rect2()
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return box
	if src.size.x / src.size.y > box.size.x / box.size.y:
		box = box.grow_individual(size.x * 0.06, 0.0, size.x * 0.06, 0.0)  # out to the rim, not past it
	var k := minf(box.size.x / src.size.x, box.size.y / src.size.y)
	var dst := src.size * k
	var top := box.end.y - dst.y
	if top > -s * RISE_MIN:
		top = maxf(-s * RISE_MIN, box.end.y - s * HOVER - dst.y)
	return Rect2(Vector2(box.position.x + (box.size.x - dst.x) * 0.5, top), dst)

## Count font in logical px, floored so it is COUNT_PX on screen whatever the stretch scale.
func count_font_size() -> int:
	# The screen transform includes the window's stretch scale; outside the tree assume 1:1.
	var scale := maxf(get_screen_transform().get_scale().y, 0.01) if is_inside_tree() else 1.0
	return int(ceilf(maxf(size.y * 0.2, COUNT_PX / scale)))

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_glow.set_border_width_all(3 if has_focus() or button_pressed else 2)
	_glow.shadow_size = int(maxf(6.0, size.y * 0.12))
	draw_style_box(_glow, r)
	# Rarity wash in the lower half so the floor of the slot reads as the rim colour.
	draw_style_box(_wash, Rect2(Vector2(0, size.y * 0.45), Vector2(size.x, size.y * 0.55)).grow(-2))
	if item_id == &"":
		return
	var tex := ItemArt.texture_for(item_id)
	if tex:
		draw_texture_rect_region(tex, art_rect(), ItemArt.content_rect(item_id))
	if count > 1:
		var font := get_theme_default_font()
		var fs := count_font_size()
		var txt := "x%d" % count
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(size.x - w - 6, size.y - 6)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTokens.TEXT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
