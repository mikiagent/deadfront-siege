class_name TargetSwordsHex
extends HexButton
## Durango's red crossed-swords hex (docs/reference/durango-target-select.webp): floats beside the
## selected wild animal and follows it; a tap starts the fight (TargetSelect.engage). Hidden once
## that animal is the hunt target. Desktop draws the interact key ("E") beside it, as the reference does.

const SWORD_RED := Color(0.9, 0.12, 0.1)
const KEY := "E"  # input_setup.gd: interact

var player: Player

func _init() -> void:
	super(64.0)
	name = "TargetSwords"
	visible = false
	pressed.connect(func () -> void:
		if player:
			player.controls.selection.engage())

func _process(delta: float) -> void:
	super(delta)
	var c := _shown_for()
	if visible != (c != null):
		visible = c != null
	if c == null:
		return
	var cam := get_viewport().get_camera_3d()
	# Beside the body's middle as in the reference, nearer for a small animal; never off past a big one.
	var box := CreaturePlates.creature_box(cam, c)
	var mid := cam.unproject_position(c.global_position + Vector3(0, c.def.height_meters * 0.5, 0))
	var at := mid + Vector2(clampf(box.size.x * 0.3, 36.0, 140.0), -size.y * 0.5)
	var r := get_viewport_rect().size
	var inset := UiTokens.safe_insets(get_viewport())  # x right, y bottom, z top, w left
	position = at.clamp(Vector2(8.0 + inset.w, 8.0 + inset.z), r - size - Vector2(28.0 + inset.x, 8.0 + inset.y))

## The selection while it is not already the fight and its feet are in front of the camera.
func _shown_for() -> Creature:
	if player == null or player.dead:
		return null
	var c := player.controls.selection.current()
	var cam := get_viewport().get_camera_3d()
	if c == null or (player.hunt and player.hunt.target == c) or cam == null or cam.is_position_behind(c.global_position):
		return null
	return c

func _draw() -> void:
	super()
	var c := size * 0.5
	var s := (minf(size.x, size.y) * 0.5 - 2.0) * 0.6
	_sword(c, Vector2(-1, -1), s)
	_sword(c, Vector2(1, -1), s)
	if not UiTokens.is_compact(get_viewport_rect().size):  # phones have no key
		var font := ThemeDB.fallback_font
		var key := Rect2(Vector2(size.x - 4.0, c.y - 20.0), Vector2(20.0, 20.0))
		draw_rect(key, UiTokens.INK)
		draw_rect(key, Color(0.85, 0.85, 0.85), false, 1.5)
		UiTokens.draw_centered(self, font, key.get_center(), KEY, 14, UiTokens.TEXT)

## One sword across the hex: tip toward `dir` (a diagonal), hilt in the opposite corner.
func _sword(c: Vector2, dir: Vector2, s: float) -> void:
	var tip := c + dir * s
	var guard := c - dir * s * 0.55
	var pommel := c - dir * s * 0.95
	var side := Vector2(-dir.y, dir.x).normalized()
	var w := s * 0.17
	var shoulder := tip.lerp(guard, 0.18)  # the point's bevel; the blade keeps its width to the guard
	draw_colored_polygon(PackedVector2Array([tip, shoulder + side * w, guard + side * w, guard - side * w, shoulder - side * w]), SWORD_RED)
	draw_line(guard + side * s * 0.34, guard - side * s * 0.34, SWORD_RED, maxf(3.0, s * 0.16), true)
	draw_line(guard, pommel, SWORD_RED, maxf(3.0, s * 0.14), true)
	draw_circle(pommel, maxf(2.0, s * 0.12), SWORD_RED)
