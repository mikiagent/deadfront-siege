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
var badge_ink: Color = Color.WHITE  ## the badge's text (CTA_INK on a GOLD notice badge)
## A white UiIcons drawing painted in the badge instead of its text (the butcher fan's tool_needed).
var badge_icon: Texture2D
var label_text: String = ""   # optional label drawn to the right (station radial)
var caption: String = ""      # action word drawn under the hex, outside the outline (rail, skills)
var hint_text: String = ""    # small red line under the label (blocked reason)
var cooldown: float = 0.0     # 0..1 of the cooldown left (set_ability)
var cooldown_text: String = ""  ## whole seconds left, drawn big in the middle while cooling down
var lock_text: String = ""  ## why the ability can't be used now; replaces the caption, in red, with a lock badge
var selected: bool = false
var enabled_look: bool = true
## Item and creature thumbnails stay colored. Action glyphs and HUD symbols stay white.
var color_icon: bool = false
## Hex orientation (docs/design/ui-redesign-spec.md §3). One global switch: UiTokens.HEX_FLAT_TOP,
## which the owner set flat-top on 2026-10-28. A hex may still ask for pointy-top.
var flat_top: bool = UiTokens.HEX_FLAT_TOP
## Rim colour; a fully transparent value means "follow `accent`" (today's look, and what selected and
## blocked states keep overriding). Restyled screens set HUD_RIM / GOLD here instead.
var rim_color: Color = Color(0, 0, 0, 0)
## Rim stroke width in px. 2.0 is the shipped look; the spec's restyle uses 4.0 (3.0 under 70 px).
var rim_width: float = RIM_W
## Pie fill, 0..1, over the hex interior (§4). Separate from `cooldown`, which keeps its slice sweep.
var fill_ratio: float = 0.0
## Desaturate the icon (gather hexes draw the resource symbol greyed out).
var icon_grey: bool = false
## Small boxed key label at the hex's top-right on desktop ("Esc", "F", "⇧"); hidden on phones.
var key_hint: String = ""
## Tint of a white glyph / symbol (the build SAVE check draws OK_GREEN, the CANCEL cross LIFE red).
var glyph_color: Color = Color.WHITE
## bottom_text size as a share of the radius (0.40 shipped); a word like CANCEL inside the hex uses less.
var bottom_scale: float = 0.40

var _down: bool = false
var _hold: float = 0.0
## Shared by every white symbol (white_material()).
static var _white: ShaderMaterial

## Caption type size under the hex, shared by _draw and caption_rect().
const CAPTION_PX := 13
## Key cap glyph size and box (§3): a small boxed key label at the hex's top-right.
const HINT_PX := 14
## The shipped rim stroke: a 2 px outline centred on the edge. Kept as the default so every existing
## call site renders exactly as before the UI-token package.
const RIM_W := 2.0
## Pie fill colour: HUD_RIM at ~45% alpha over the dark interior (§4).
const PIE_ALPHA := 0.45
## Grey icon copies, keyed by source texture (desaturating 128 px icons on the CPU each frame hitched
## the phone in the white_material work, so it is done once and cached).
static var _grey: Dictionary = {}

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

## One call for every combat ability hex (tackle, kick, roll; owner 2026-10-31): `left` of `total` seconds of
## cooldown fill the hex clockwise from the top like the harvest pie (fill_ratio), the seconds left, rounded
## up, sit in the middle, and a `lock` reason greys it with a lock badge and takes the caption's place.
func set_ability(left: float, total: float, lock: String = "") -> void:
	cooldown = clampf(left / total, 0.0, 1.0) if left > 0.0 and total > 0.0 else 0.0
	cooldown_text = str(ceili(left)) if cooldown > 0.0 else ""
	lock_text = lock
	disabled = cooldown > 0.0 or lock != ""
	badge = "lock" if lock != "" else ""
	badge_icon = UiIcons.icon(&"lock") if lock != "" else null
	badge_color = Color(0.85, 0.15, 0.12, 0.95)
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

## The rim colour drawn this frame: rim_color when set, else the accent (today's look). Selected draws
## in GOLD on a restyled hex and TEAL on a shipped one; blocked greys it out.
func effective_rim(p_selected: bool = false) -> Color:
	var c := rim_color if rim_color.a > 0.0 else accent
	return (UiTokens.GOLD if rim_color.a > 0.0 else UiTokens.TEAL) if p_selected else c

## The hexagon's corners, from the one geometry source (UiTokens.hex_points).
func _hex(r: float, c: Vector2) -> PackedVector2Array:
	return UiTokens.hex_points(c, r, flat_top)

func _draw() -> void:
	var tex: Texture2D = drawn_icon()
	var want: Material = white_material() if tex and not color_icon else null
	if material != want:
		material = want
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var f := fill
	var rim := effective_rim(selected)
	if disabled or not enabled_look:
		f = Color(0.05, 0.05, 0.06, 0.8)
		rim = Color(0.5, 0.5, 0.5, 0.8)
	if _down:
		f = f.lightened(0.15)
	# Draw order (spec §3): rim hex, the fill hex inside it, the pie sector, then icon and texts.
	var rw := maxf(1.0, rim_width)
	var fr := maxf(0.0, r - rw * 0.5)
	var outline := _hex(r, c)
	outline.append(outline[0])
	draw_polyline(outline, rim, rw, true)
	draw_colored_polygon(_hex(fr, c), f)
	if fill_ratio > 0.0:
		var pie := UiTokens.pie_points(c, fr, fill_ratio, flat_top)
		if pie.size() >= 3:
			draw_colored_polygon(pie, Color(UiTokens.HUD_RIM, PIE_ALPHA))
	if cooldown > 0.0:
		# The recharge: the harvest pie, filling clockwise from the top until the ability is ready.
		var cd_pie := UiTokens.pie_points(c, fr, 1.0 - cooldown, flat_top)
		if cd_pie.size() >= 3:
			draw_colored_polygon(cd_pie, Color(UiTokens.HUD_RIM, PIE_ALPHA))
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
		var tint := Color(1, 1, 1, 0.45 if disabled else 1.0) if color_icon else Color(glyph_color, 0.45 if disabled else 1.0)
		if cooldown_text != "":
			tint.a = 0.22  # the seconds read over a faint icon
		if icon_grey and not color_icon:
			tint = tint * Color(0.62, 0.62, 0.62)  # white symbol greyed; own-colour icons use the grey copy
		elif fill_ratio > 0.0:
			tint = tint * (1.0 + 0.4 * clampf(fill_ratio, 0.0, 1.0))
		draw_texture_rect(tex, Rect2(ic - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, tint)
	elif glyph != "":
		var short := glyph.length() <= 2
		var gs := maxi(UiTokens.TYPE_MIN, int(r * (0.72 if bottom_text != "" else 0.9)) if short else (int(r * 0.40) if glyph.length() <= 4 else int(r * 0.30)))
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, gs).x
		var gy := c.y + gs * (0.2 if bottom_text != "" else 0.35)
		draw_string(font, Vector2(c.x - w * 0.5, gy), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color(glyph_color, 0.5 if disabled else 1.0))
	if cooldown_text != "":
		var ns := maxi(UiTokens.TYPE_MIN, int(r * 0.85))
		var nw := font.get_string_size(cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		var np := Vector2(c.x - nw * 0.5, c.y + ns * 0.36)
		draw_string_outline(font, np, cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, 6, Color(0, 0, 0, 0.85))
		draw_string(font, np, cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color.WHITE)
	if top_text != "":
		UiTokens.draw_centered(self, font, Vector2(c.x, c.y - r * 0.52), top_text, int(r * 0.30), Color(0.85, 0.85, 0.85))
	if bottom_text != "":
		UiTokens.draw_centered(self, font, Vector2(c.x, c.y + r * 0.62), bottom_text, int(r * bottom_scale), Color.WHITE)
	if caption != "":
		var at := _caption_at(font)
		draw_string(font, Vector2(at.x, at.y), _caption_text(font), HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_PX, UiTokens.DANGER if lock_text != "" else Color(1, 1, 1, 0.55 if disabled else 1.0))
	if key_visible():
		var kr := key_rect()
		draw_rect(kr, UiTokens.INK)
		draw_rect(kr, Color(0.85, 0.85, 0.85), false, 1.5)
		UiTokens.draw_centered(self, font, kr.get_center(), key_hint, HINT_PX, UiTokens.TEXT)
	if badge != "" and badge_icon != null:
		var bc := c + Vector2(r * 0.74, -r * 0.62)  # on the upper-right edge, clear of the seconds on top
		var br := r * 0.3  # a drawing needs a little more room than one glyph
		draw_circle(bc, br, badge_color)
		draw_texture_rect(badge_icon, Rect2(bc - Vector2(br, br) * 0.8, Vector2(br, br) * 1.6), false, badge_ink)
	elif badge != "":
		var bc := c + Vector2(r * 0.55, -r * 0.55)
		draw_circle(bc, r * 0.26, badge_color)
		var bsz := maxi(UiTokens.TYPE_MIN, int(r * 0.34))
		var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, bsz).x
		draw_string(font, Vector2(bc.x - w * 0.5, bc.y + bsz * 0.36), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz, badge_ink)

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
	return UiTokens.ellipsis(font, lock_text if lock_text != "" else caption, size.x * 1.25, CAPTION_PX)

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

## The drawn hexagon's box, global: flat-top so 2r wide and sqrt(3)r tall, pointy-top the other way
## round, never the control's full width.
func hex_rect() -> Rect2:
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var half := Vector2(r, r * 0.866) if flat_top else Vector2(r * 0.866, r)
	return Rect2(get_global_rect().get_center() - half, half * 2.0)

## The texture _draw paints: the icon itself, or a cached grey copy when `icon_grey` and the icon
## keeps its own colours (white glyphs are greyed by the draw tint instead).
func drawn_icon() -> Texture2D:
	var tex: Texture2D = icon if icon else _glyph_icon
	if tex != null and icon_grey and color_icon:
		return grey_texture(tex)
	return tex

## A desaturated (luma) copy of `tex`, built once per texture. CPU work, not a shader: the icon
## share white_material with the hex polygons, which would grey the fill too.
static func grey_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var id := tex.get_instance_id()
	if _grey.has(id) and is_instance_valid(_grey[id]):
		return _grey[id]
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			var l := p.r * 0.299 + p.g * 0.587 + p.b * 0.114
			img.set_pixel(x, y, Color(l, l, l, p.a))
	var out := ImageTexture.create_from_image(img)
	_grey[id] = out
	return out

## Key hint shown? Never on a phone (either way up: a landscape phone is not `is_phone`).
func key_visible() -> bool:
	return key_hint != "" and not UiTokens.is_compact(get_viewport_rect().size)

## The key cap at the hex's top-right, local. Desktop only.
func key_rect() -> Rect2:
	var r := minf(size.x, size.y) * 0.5 - 2.0
	return Rect2(Vector2(size.x * 0.5 + r * 0.55, size.y * 0.5 - r * 0.95), Vector2(HINT_PX + 6.0, HINT_PX + 4.0))

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
