class_name ArtSlot
extends Button
## Inventory-style slot whose rendered item art rises above the slot top edge,
## framed by a rarity-coloured rim and soft glow. Count sits bottom-right; rarity pips
## (0 common .. 4 legendary) climb the left rim so rarity never rests on colour alone.
## The frame is square: a tall slot frames a centred square cell (the rise is measured against
## the frame), a wide slot frames its full width; the whole button stays the tap target.
## Focus adds a white ring and a brighter rim and glow; a press also sinks the art.
## A Button so focus, touch and InputMap gamepad confirm all work unchanged.

const MIN_SIZE := 64.0  # mobile tap floor
const RISE := 0.16      # art top sits 16 % of the slot height above the slot (spec: 12-20 %)
const RISE_MIN := 0.12 # spec floor for the rise: wide items lift until they reach it
const FLOOR := 0.80     # art bottom sits here, so every object stands on the same slot floor
const HOVER := 0.20     # a wide item may lift its bottom this far off FLOOR to reach RISE_MIN
const COUNT_PX := 14.0  # stack count floor in physical pixels (GAUNTLET: no illegible metadata)
const PIP_PX := 4.0     # pip half-size floor in physical pixels: 8 px diamonds stay countable on a phone
# One step above UiTokens.INK_SOLID: dark items (stone_knife, obsidian, black_iron) vanished on near-black.
const INTERIOR := Color(0.12, 0.13, 0.14, 0.94)
const PRESS_SCALE := 0.92  # art shrinks toward its centre while pressed: touch feedback on a flat button

var item_id: StringName = &""
var count: int = 0
var rim: Color = Color(0.66, 0.68, 0.70)
var pips: int = 0  # rarity tier index: the non-colour rarity cue
var _glow := StyleBoxFlat.new()  # cached: _draw runs for every slot on every redraw
var _wash := StyleBoxFlat.new()
var _ring := StyleBoxFlat.new()

func _init() -> void:
	custom_minimum_size = Vector2(MIN_SIZE, MIN_SIZE)
	flat = true  # we draw the frame ourselves
	focus_mode = Control.FOCUS_ALL
	clip_contents = false
	# 256 px art drawn at ~56-64 px: mipmaps (enabled in the .import files) stop noisy textures shimmering.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_glow.bg_color = INTERIOR
	_glow.set_corner_radius_all(UiTokens.RADIUS)
	_wash.set_corner_radius_all(UiTokens.RADIUS)
	_ring.draw_center = false
	_ring.border_color = UiTokens.TEXT  # white reads against every rarity colour
	_ring.set_border_width_all(2)
	_ring.set_corner_radius_all(UiTokens.RADIUS + 4)
	_frame(false)

## Configures the cached frame for the idle or lit (focused / pressed) state and returns it.
func _frame(lit: bool) -> StyleBoxFlat:
	_glow.border_color = rim.lightened(0.45) if lit else rim
	_glow.set_border_width_all(3 if lit else 2)
	_glow.shadow_color = Color(rim, (0.95 if lit else 0.55) if item_id != &"" else (0.5 if lit else 0.0))
	_glow.shadow_size = int(maxf(6.0, cell().size.y * (0.22 if lit else 0.12)))
	_wash.bg_color = Color(rim, 0.34 if lit else 0.22)
	return _glow

func _is_down() -> bool:
	var m := get_draw_mode()
	return m == DRAW_PRESSED or m == DRAW_HOVER_PRESSED

func set_item(id: StringName, p_count: int = 1) -> void:
	item_id = id
	count = p_count
	rim = ItemArt.rim_color(id) if id != &"" else Color(0.4, 0.4, 0.4)
	pips = maxi(0, ItemArt.rarity_order().find(str(ItemArt.rarity(id)))) if id != &"" else 0
	var def: ItemDef = Data.item(id) if id != &"" else null
	tooltip_text = def.display_name if def else str(id)
	queue_redraw()

## The framed square (see the class comment): full width, at most as tall as wide, centred.
func cell() -> Rect2:
	var h := minf(size.y, size.x)
	return Rect2(Vector2(0.0, (size.y - h) * 0.5), Vector2(size.x, h))

## Where the object's opaque pixels land. Tall items stand on FLOOR and their top rises RISE
## above the slot. Wide items may use the full slot width (never past the rim) and lift off the
## floor (at most HOVER) until their top rises RISE_MIN; art wider than ~1.39:1 cannot, so the
## art builders stage flat items on a diagonal (kit.upright) or as a stack instead.
func art_rect() -> Rect2:
	var c := cell()
	var s := c.size.y
	var box := Rect2(Vector2(size.x * 0.06, c.position.y - s * RISE), Vector2(size.x * 0.88, s * (RISE + FLOOR)))
	var src := ItemArt.content_rect(item_id) if item_id != &"" else Rect2()
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return box
	if src.size.x / src.size.y > box.size.x / box.size.y:
		box = box.grow_individual(size.x * 0.06, 0.0, size.x * 0.06, 0.0)  # out to the rim, not past it
	var k := minf(box.size.x / src.size.x, box.size.y / src.size.y)
	var dst := src.size * k
	var top := box.end.y - dst.y
	if top > c.position.y - s * RISE_MIN:
		top = maxf(c.position.y - s * RISE_MIN, box.end.y - s * HOVER - dst.y)
	return Rect2(Vector2(box.position.x + (box.size.x - dst.x) * 0.5, top), dst)

## Count font in logical px, floored so it is COUNT_PX on screen whatever the stretch scale.
func count_font_size() -> int:
	return int(ceilf(maxf(cell().size.y * 0.2, COUNT_PX / screen_scale())))

## Pip half-size in logical px, floored to PIP_PX on screen like the count, and capped so
## four pips (2h + 3 * 2.3h = 8.9h) always fit inside the frame.
func pip_half() -> float:
	return minf(maxf(cell().size.y * 0.05, PIP_PX / screen_scale()), (cell().size.y - 12.0) / 8.9)

## One diamond per tier above common, climbing the left rim from the floor: a bottom row ran
## into the right-aligned count ("x999" on 3-pip epics) once pips grew to a legible size.
func pip_centres() -> PackedVector2Array:
	var h := pip_half()
	var out := PackedVector2Array()
	for i in pips:
		out.append(Vector2(6.0 + h, cell().end.y - 6.0 - h - i * h * 2.3))
	return out

## Logical px to physical px. get_screen_transform() leaves out the canvas_items stretch (it
## reported 1.0 in an 844x390 window where the stretch is 0.433), so take the viewport's final
## transform. Outside the tree assume 1:1.
func screen_scale() -> float:
	if not is_inside_tree():
		return 1.0
	return maxf((get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().y, 0.01)

func _draw() -> void:
	var r := cell()
	var down := _is_down()
	draw_style_box(_frame(down or has_focus()), r)
	if has_focus():
		draw_style_box(_ring, r.grow(4.0))
	# Rarity wash in the lower half so the floor of the slot reads as the rim colour.
	draw_style_box(_wash, Rect2(Vector2(0, r.position.y + r.size.y * 0.45), Vector2(size.x, r.size.y * 0.55)).grow(-2))
	if item_id == &"":
		return
	var tex := ItemArt.texture_for(item_id)
	if tex:
		var ar := art_rect()
		if down:
			ar = Rect2(ar.get_center() - ar.size * PRESS_SCALE * 0.5, ar.size * PRESS_SCALE)
		draw_texture_rect_region(tex, ar, ItemArt.content_rect(item_id))
	_draw_pips()
	if count > 1:
		var font := get_theme_default_font()
		var fs := count_font_size()
		var txt := "x%d" % count
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(size.x - w - 6, r.end.y - 6)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTokens.TEXT)

## Diamonds in the rim colour with an ink edge.
func _draw_pips() -> void:
	var h := pip_half()
	for c in pip_centres():
		var d := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
		var o := PackedVector2Array([c + Vector2(0, -h - 1.5), c + Vector2(h + 1.5, 0), c + Vector2(0, h + 1.5), c + Vector2(-h - 1.5, 0)])
		draw_colored_polygon(o, Color(0, 0, 0, 0.9))
		draw_colored_polygon(d, rim.lightened(0.25))

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
