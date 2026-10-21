class_name DomainBanner
extends RefCounted
## Spec 18, owner: "When entering player's claimed regions, it says 'Player's Domain' with their
## profile picture." Crossing into claimed land shows "<owner>'s Domain" for a few seconds as the
## label spec 15's map draws (durango-island-map.webp): a dark pill, the owner's portrait in a round
## frame on its left end, the name gold and "'s Domain" white. Staying inside shows it once; leaving
## and coming back, or stepping straight into another owner's land, shows it again. HuntHud ticks
## it every frame and draws it before the toasts and notices, which then keep off it.

const SHOW_S := 3.5  ## on screen, fades included
const FADE_S := 0.35
## Outside this long before the domain counts as left, so walking along its edge does not flash it.
const LEAVE_S := 0.5
## A move this long in one frame is a respawn or a teleport, not a walk across the edge.
const JUMP_M := 6.0
const NAME_COLOR := Color(0.96, 0.71, 0.27)
const PILL_COLOR := Color(0.05, 0.05, 0.05, 0.9)
const FRAME_COLOR := Color(0.93, 0.89, 0.80)

var owner: Dictionary = {}  ## whose land the survivor stands on ({} outside)
var shown: Dictionary = {}  ## the owner on the banner
var age: float = -1.0  ## seconds the banner has been up; < 0 hidden
var _island_id: int = 0  ## the runtime the last tick saw
var _last_at := Vector3.INF
var _out_s: float = 0.0
var _pill := StyleBoxFlat.new()

func showing() -> bool:
	return age >= 0.0

func text() -> String:
	return "%s's Domain" % str(shown.get("name", "")) if showing() else ""

## `rt` is World.runtime (its owner_at is the claim data), `at` where the survivor stands.
func tick(delta: float, rt: Node, at: Vector3) -> void:
	if age >= 0.0:
		age += minf(delta, 0.1)  # one long frame (the first portrait render, a busy phone) must not eat it
		if age >= SHOW_S:
			age = -1.0
	var here: Dictionary = rt.call("owner_at", BuildGrid.tile_of(at)) if rt and rt.has_method("owner_at") else {}
	var id := rt.get_instance_id() if rt else 0
	var jumped := _last_at.distance_to(at) > JUMP_M
	_last_at = at
	if id != _island_id or jumped:
		# ASSUMPTION: arriving (boot, load, a voyage, a respawn, a teleport) is not entering a
		# domain: the banner waits for the survivor to walk or ride across a claim edge.
		_island_id = id
		owner = here
		_out_s = 0.0
		return
	if here.is_empty():
		_out_s += delta
		if _out_s >= LEAVE_S:
			owner = {}
		return
	_out_s = 0.0
	if str(here.get("id", "")) != str(owner.get("id", "")):
		owner = here
		shown = here
		age = 0.0

## Top centre, else the nearest free spot straight down (under the target plate, or the quest card
## on a landscape phone), off the vitals, minimap, quest card, hexes and the survivor, inside the
## safe area.
func draw(hud: HuntHud) -> void:
	if age < 0.0:
		return
	var r := hud.get_viewport_rect().size
	var compact := UiTokens.is_compact(r)
	var font := hud._font
	var inset := hud._safe_insets()
	# Compact: 40 px tall fits between a landscape phone's quest card and the survivor's head.
	var px := 17 if compact else 22
	var h := 34.0 if compact else 46.0
	var d := h + (6.0 if compact else 8.0)  # the portrait stands out of the pill above and below
	var tail := "'s Domain"
	var tail_w := font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var room := r.x - 32.0 - inset.x - inset.w - d - tail_w - 30.0
	var who := UiTokens.ellipsis(font, str(shown.get("name", "")), room, px)
	var who_w := font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var w := d + 10.0 + who_w + tail_w + 20.0
	var top := 14.0 + inset.z
	var box := UiTokens.free_spot(Rect2(inset.w + (r.x - inset.w - inset.x - w) * 0.5, top, w, d), hud.taken_rects(), r)
	if not box.has_area():
		return
	hud.drawn_blocks["domain"] = box
	var a := clampf(minf(age, SHOW_S - age) / FADE_S, 0.0, 1.0)
	var pill := Rect2(box.position + Vector2(d * 0.5, (d - h) * 0.5), Vector2(w - d * 0.5, h))
	_pill.bg_color = Color(PILL_COLOR, PILL_COLOR.a * a)
	_pill.set_corner_radius_all(int(h * 0.5))
	hud.draw_style_box(_pill, pill)
	var c := box.position + Vector2(d, d) * 0.5
	hud.draw_circle(c, d * 0.5, Color(PILL_COLOR, a))
	_draw_round(hud, PlayerPortrait.texture_for(shown, hud), c, d * 0.5 - 3.0, a)
	hud.draw_arc(c, d * 0.5 - 1.5, 0.0, TAU, 48, Color(FRAME_COLOR, a), 2.0, true)
	var base := Vector2(box.position.x + d + 10.0, pill.position.y + (h + font.get_ascent(px) - font.get_descent(px)) * 0.5)
	hud.draw_string(font, base, who, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(NAME_COLOR, a))
	hud.draw_string(font, base + Vector2(who_w, 0.0), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, a))

static func _draw_round(ci: CanvasItem, tex: Texture2D, c: Vector2, radius: float, a: float) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 40:
		var v := Vector2.from_angle(TAU * float(i) / 40.0)
		pts.append(c + v * radius)
		uvs.append(Vector2(0.5, 0.5) + v * 0.5)
	ci.draw_colored_polygon(pts, Color(1, 1, 1, a), uvs, tex)
