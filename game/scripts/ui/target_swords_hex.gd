class_name TargetSwordsHex
extends HexButton
## Durango's red crossed-swords hex (docs/reference/durango-target-select.webp): floats beside the
## selected wild animal and follows it; a tap starts the fight (TargetSelect.engage). Shown only while
## the animal is on screen, in hunt range and clear of the HUD; hidden once it is the hunt target or
## can be field-tamed. Desktop draws the interact key ("E") beside it, as the reference does.

const SWORD_RED := Color(0.9, 0.12, 0.1)
const KEY := "E"  # input_setup.gd: interact
const KEY_PX := 20.0
const SEARCH_STEP := 16.0  # px grid of the crowded-screen search around the animal

var player: Player
var _key_drawn := false

func _init() -> void:
	super(64.0)
	name = "TargetSwords"
	visible = false
	fill = Color(0.18, 0.18, 0.19, 0.72)  # the reference's translucent grey hex with a dark rim
	accent = Color(0.04, 0.04, 0.05, 0.6)
	add_to_group(&"target_swords")
	pressed.connect(func () -> void:
		if player:
			player.controls.selection.engage())

func _process(delta: float) -> void:
	super(delta)
	var keyed := _keyed()
	if keyed != _key_drawn:
		_key_drawn = keyed
		queue_redraw()
	var spot := _spot()
	if visible != spot.has_area():
		visible = spot.has_area()
	if visible:
		position = spot.position

## The selection while it is not already the fight, is in hunt range and cannot be field-tamed
## (FEED/NET own that state: a stray tap here would attack the animal being tamed).
func _shown_for() -> Creature:
	if player == null or player.dead:
		return null
	var c := player.controls.selection.current()
	if c == null or (player.hunt and player.hunt.target == c) or FieldTame.can_attempt(c):
		return null
	if player.global_position.distance_to(c.global_position) > PlayerActions.ATTACK_SEEK_RANGE:
		return null  # the hunt drops past this range, so the swords would start nothing
	return c

## Where the hex goes this frame: beside the selection's middle (right, else left), slid at most one hex
## up or down off the HUD, as in the reference. Crowded (on a phone the selection's own plate, the
## minimap or a hex cluster often sits there), the clear spot touching the animal's screen box that is
## nearest the right-hand one, never over its middle: touch has no other way to start the fight.
## Empty (hidden) when the selection is off screen or no clear spot touches it: pinned to the screen
## edge it sat on SIC beside nothing and took SIC's taps.
func _spot() -> Rect2:
	var c := _shown_for()
	var cam := get_viewport().get_camera_3d()
	if c == null or cam == null or cam.is_position_behind(c.global_position):
		return Rect2()
	var view := get_viewport_rect()
	var mid := cam.unproject_position(c.global_position + Vector3(0, c.def.height_meters * 0.5, 0))
	if not view.has_point(mid):
		return Rect2()
	var hud := get_parent() as HuntHud
	var taken: Array[Rect2] = hud.taken_rects(PackedStringArray(["pill"])) if hud else []
	if visible:
		taken.erase(hex_rect())  # itself
	var inset := UiTokens.safe_insets(get_viewport())  # x right, y bottom, z top, w left
	var safe := Rect2(Vector2(8.0 + inset.w, 8.0 + inset.z), view.size - Vector2(16.0 + inset.w + inset.x, 16.0 + inset.z + inset.y))
	var w := Vector2(maxf(size.x, _key_rect().end.x) if _key_drawn else size.x, size.y)
	var box := CreaturePlates.creature_box(cam, c)
	# Nearer for a small animal, never off past a big one.
	var dx := clampf(box.size.x * 0.3, 36.0, 140.0)
	var want := mid + Vector2(dx, -size.y * 0.5)
	for at: Vector2 in [want, mid - Vector2(dx + w.x, size.y * 0.5)]:
		var spot := UiTokens.free_spot(Rect2(at, w), taken, view.size)
		if spot.has_area() and absf(spot.position.y - at.y) <= size.y and safe.encloses(spot):
			return spot
	if not box.has_area():
		box = Rect2(mid, Vector2.ZERO)
	var reach := box.grow_individual(w.x, w.y, w.x, w.y).intersection(safe)
	var best := Rect2()
	var y := reach.position.y
	while y + w.y <= reach.end.y:
		var x := reach.position.x
		while x + w.x <= reach.end.x:
			var r := Rect2(Vector2(x, y), w)
			if not r.has_point(mid) and (not best.has_area() or r.position.distance_squared_to(want) < best.position.distance_squared_to(want)) and _clear_of(r, taken):
				best = r
			x += SEARCH_STEP
		y += SEARCH_STEP
	return best

static func _clear_of(r: Rect2, taken: Array[Rect2]) -> bool:
	for t in taken:
		if r.intersects(t.grow(2.0)):
			return false
	return true

## Desktop only, and not while riding: there E dismounts (PlayerInput.interact checks that first).
func _keyed() -> bool:
	return not UiTokens.is_compact(get_viewport_rect().size) and player != null and player.mounted_on == null

## The key cap overlaps the hex's right edge, flush as in the reference.
func _key_rect() -> Rect2:
	var r := minf(size.x, size.y) * 0.5 - 2.0
	return Rect2(Vector2(size.x * 0.5 + r * 0.866 - 6.0, size.y * 0.5 - KEY_PX * 0.5), Vector2(KEY_PX, KEY_PX))

func _draw() -> void:
	super()
	var c := size * 0.5
	var s := (minf(size.x, size.y) * 0.5 - 2.0) * 0.6
	_sword(c, Vector2(-1, -1), s)
	_sword(c, Vector2(1, -1), s)
	if _key_drawn:
		var key := _key_rect()
		draw_rect(key, UiTokens.INK)
		draw_rect(key, Color(0.85, 0.85, 0.85), false, 1.5)
		UiTokens.draw_centered(self, ThemeDB.fallback_font, key.get_center(), KEY, 14, UiTokens.TEXT)

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
