class_name HexButton
extends Control
## Durango-style hexagonal button: dark hex with a light rim, an icon or glyph in the
## middle, small text above (time) and below (count). Fires `pressed` on tap.
## Also used by the HUD skill cluster (M8c). Minimum 64 px across.

signal pressed
signal long_pressed

var icon: Texture2D
## A legacy glyph with a white UiIcons drawing (data/ui_icons.json "glyphs") draws that icon instead.
var glyph: String = "":
	set(v):
		glyph = v
		_glyph_icon = UiIcons.for_glyph(v) if v != "" else null
var _glyph_icon: Texture2D
var top_text: String = ""
var bottom_text: String = ""
var disabled: bool = false
var accent: Color = Color(0.95, 0.95, 0.95)
var fill: Color = Color(0.07, 0.08, 0.09, 0.93)
var badge: String = ""  # e.g. "⊘" when blocked
var badge_color: Color = Color(0.85, 0.15, 0.12, 0.95)
var label_text: String = ""   # optional label drawn to the right (station radial)
var caption: String = ""      # action word drawn under the hex, outside the outline (rail, skills)
var hint_text: String = ""    # small red line under the label (blocked reason)
var cooldown: float = 0.0     # 0..1 remaining sweep
var selected: bool = false
var enabled_look: bool = true
## Item and creature thumbnails stay colored. Action glyphs and HUD symbols stay white.
var color_icon: bool = false

var _down: bool = false
var _hold: float = 0.0
## Shared by every white symbol (white_material()).
static var _white: ShaderMaterial

## Caption type size under the hex, shared by _draw and caption_rect().
const CAPTION_PX := 13

## Compatibility with the station radial (M8e): icon or glyph, label, seconds on top, count below.
func setup(p_icon: Texture2D, p_glyph: String, p_label: String, p_seconds: String = "", p_count: String = "") -> void:
	icon = p_icon
	glyph = p_glyph if p_icon == null else ""
	label_text = p_label
	top_text = p_seconds
	bottom_text = p_count
	queue_redraw()

func set_blocked(hint: String) -> void:
	disabled = true
	badge = "⊘"
	badge_color = Color(0.85, 0.15, 0.12, 0.95)
	hint_text = hint if hint == "" or hint.begins_with("needs") else "needs %s" % hint
	queue_redraw()

func set_ok_badge(hint: String, color: Color = Color(0.95, 0.8, 0.2, 0.95)) -> void:
	badge = "✓"
	badge_color = color
	hint_text = hint
	queue_redraw()

func _process(delta: float) -> void:
	if _down:
		_hold += delta
		if _hold > 0.55:
			_hold = -999.0
			long_pressed.emit()
	if cooldown > 0.0:
		queue_redraw()

func _init(size_px: float = 72.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The 128 px icon SVGs are imported with mipmaps; without this they alias at ~30 px.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pivot_offset = size * 0.5
	# Out of focus by default: the HUD rails are hexes, and a focused one takes Space (roll) and the
	# arrows (move). Menus that a controller drives (station menu) set FOCUS_ALL; _draw shows a teal
	# ring on focus, and a tap or click drops it again (_gui_input).
	# ASSUMPTION: the station menu is the only hex menu a controller drives; the radials do not call focus_first yet.
	focus_mode = Control.FOCUS_NONE
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	# HuntHud.taken_rects finds every hex on screen (HUD, station and gather radials) through this.
	add_to_group(&"hex_button")

func _hex(r: float, c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * float(i) - 30.0)  # pointy top
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw() -> void:
	var tex: Texture2D = icon if icon else _glyph_icon
	var want: Material = white_material() if tex and not color_icon else null
	if material != want:
		material = want
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var f := fill
	var rim := accent
	if disabled or not enabled_look:
		f = Color(0.05, 0.05, 0.06, 0.8)
		rim = Color(0.5, 0.5, 0.5, 0.8)
	if selected:
		rim = UiTokens.TEAL
	if _down:
		f = f.lightened(0.15)
	draw_colored_polygon(_hex(r, c), f)
	var outline := _hex(r, c)
	outline.append(outline[0])
	draw_polyline(outline, rim, 2.0, true)
	if has_focus():
		var ring := _hex(r + 4.0, c)
		ring.append(ring[0])
		draw_polyline(ring, UiTokens.TEAL, 3.0, true)
	var font := ThemeDB.fallback_font
	var has_texts := top_text != "" or bottom_text != ""
	if tex:
		# Smaller icon when seconds/count sit above and below it, so the 12 px text clears the rim.
		var isz := r * (0.8 if has_texts else 1.05)
		var ic := c + Vector2(0.0, 2.0 if top_text != "" else 0.0)
		var tint := Color(1, 1, 1, 0.45 if disabled else 1.0)
		draw_texture_rect(tex, Rect2(ic - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, tint)
	elif glyph != "":
		var short := glyph.length() <= 2
		var gs := maxi(UiTokens.TYPE_MIN, int(r * (0.72 if bottom_text != "" else 0.9)) if short else (int(r * 0.40) if glyph.length() <= 4 else int(r * 0.30)))
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, gs).x
		var gy := c.y + gs * (0.2 if bottom_text != "" else 0.35)
		draw_string(font, Vector2(c.x - w * 0.5, gy), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color(1, 1, 1, 0.5 if disabled else 1.0))
	if top_text != "":
		UiTokens.draw_centered(self, font, Vector2(c.x, c.y - r * 0.52), top_text, int(r * 0.30), Color(0.85, 0.85, 0.85))
	if bottom_text != "":
		UiTokens.draw_centered(self, font, Vector2(c.x, c.y + r * 0.62), bottom_text, int(r * 0.40), Color.WHITE)
	if caption != "":
		var at := _caption_at(font)
		draw_string(font, Vector2(at.x, at.y), _caption_text(font), HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_PX, Color(1, 1, 1, 0.55 if disabled else 1.0))
	if badge != "":
		var bc := c + Vector2(r * 0.55, -r * 0.55)
		draw_circle(bc, r * 0.26, badge_color)
		var bsz := maxi(UiTokens.TYPE_MIN, int(r * 0.34))
		var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, bsz).x
		draw_string(font, Vector2(bc.x - w * 0.5, bc.y + bsz * 0.36), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz, Color.WHITE)

	if cooldown > 0.0:
		# Durango-style progress: a translucent circular dial fills in discrete slices.
		# The gaps make progress readable against foliage without another heavy hex outline.
		var slices := 16
		var filled := ceili(clampf(cooldown, 0.0, 1.0) * float(slices))
		var outer := r * 0.94
		var inner := r * 0.56
		for i in filled:
			var a0 := -PI * 0.5 + TAU * float(i) / float(slices) + 0.025
			var a1 := -PI * 0.5 + TAU * float(i + 1) / float(slices) - 0.025
			var wedge := PackedVector2Array([
				c + Vector2(cos(a0), sin(a0)) * inner,
				c + Vector2(cos(a0), sin(a0)) * outer,
				c + Vector2(cos(a1), sin(a1)) * outer,
				c + Vector2(cos(a1), sin(a1)) * inner,
			])
			draw_colored_polygon(wedge, Color(0.72, 0.72, 0.72, 0.42))
	if label_text != "":
		var ls := maxi(UiTokens.TYPE_MIN, int(r * 0.36))
		var shown := UiTokens.ellipsis(font, label_text, 140.0, ls)
		var lw := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
		var view_w := get_viewport_rect().size.x
		var global_x := get_global_rect().position.x
		var on_left := global_x + size.x + lw + 16.0 > view_w - 8.0
		var origin_x := (-lw - 16.0) if on_left else (size.x + 4.0)
		draw_rect(Rect2(Vector2(origin_x, c.y - ls * 0.9), Vector2(lw + 12.0, ls * 1.6)), UiTokens.INK)
		draw_string(font, Vector2(origin_x + 6.0, c.y + ls * 0.35), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Color(0.95, 0.95, 0.95))
		if hint_text != "":
			var hint := UiTokens.ellipsis(font, hint_text, 140.0, UiTokens.TYPE_MIN)
			draw_string(font, Vector2(origin_x + 6.0, c.y + ls * 1.45), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.TYPE_MIN, UiTokens.DANGER)

func _caption_text(font: Font) -> String:
	return UiTokens.ellipsis(font, caption, size.x * 1.25, CAPTION_PX)

## Caption baseline origin (x, y) and width (z), local. Shared by _draw and caption_rect().
func _caption_at(font: Font) -> Vector3:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var cw := font.get_string_size(_caption_text(font), HORIZONTAL_ALIGNMENT_CENTER, -1, CAPTION_PX).x
	var cx := c.x - cw * 0.5
	# keep the word on screen when the hex hugs a screen edge (harbour / whistle hexes, right side)
	var vw := get_viewport_rect().size.x
	var gx := global_position.x
	if gx + size.x > vw - 40.0:
		cx = minf(cx, size.x + 6.0 - cw)
	cx = maxf(cx, 4.0 - gx)
	return Vector3(cx, c.y + r + 15.0, cw)

## The drawn hexagon's box, global: pointy-top, so sqrt(3) * r wide, not the control's full width.
func hex_rect() -> Rect2:
	var r := minf(size.x, size.y) * 0.5 - 2.0
	return Rect2(get_global_rect().get_center() - Vector2(r * 0.866, r), Vector2(r * 1.732, r * 2.0))

## The caption's box under the hex, global (empty without a caption). Layout gates check it.
func caption_rect() -> Rect2:
	if caption == "":
		return Rect2()
	var at := _caption_at(ThemeDB.fallback_font)
	return Rect2(global_position + Vector2(at.x, at.y - float(CAPTION_PX)), Vector2(at.z, float(CAPTION_PX) + 4.0))

## Durango-style HUD language: action symbols are white silhouettes (system emoji render in colour
## on macOS/iOS). This material draws every texture on its canvas item in the draw's tint, keeping the
## texture's alpha; shapes and text keep their colours. A shader, not a CPU copy: whitening 128 px
## icons pixel by pixel in GDScript hitched the first skills and craft open on a phone.
static func white_material() -> ShaderMaterial:
	if _white == null:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nvarying vec4 tint;\nvoid vertex() { tint = COLOR; }\nvoid fragment() { COLOR.rgb = tint.rgb; }\n"
		_white = ShaderMaterial.new()
		_white.shader = shader
	return _white

## Icon for the first id in `ids` that has one (item ids from icons_manifest.json). Draw it white
## with white_material(); a HexButton does that itself unless color_icon is set.
static func symbol(ids: Array) -> Texture2D:
	for id in ids:
		var tex := ItemIcons.texture(StringName(str(id)))
		if tex:
			return tex
	return null

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and has_focus():
		accept_event()
		if not disabled:
			pressed.emit()
		return
	var press := false
	var release := false
	if event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
		release = not press
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press = (event as InputEventMouseButton).pressed
		release = not press
	else:
		return
	if press:
		if has_focus():
			release_focus()
		_down = true
		_hold = 0.0
		queue_redraw()
		accept_event()
	elif release:
		var was := _down and _hold >= 0.0
		_down = false
		queue_redraw()
		accept_event()
		if was and not disabled:
			pressed.emit()

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _hex(minf(size.x, size.y) * 0.5, size * 0.5))
