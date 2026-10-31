class_name HudBuffRow
extends RefCounted
## HUDRULES (owner 2026-10-28: "reserve below the healthbar for buffs, boons, debuffs, etc with hover to
## view/click to toggle tooltip explanations of what they are"). The chip row under the vitals: every
## status whose statuses.json kind is buff / boon / debuff, then the food buffs (BuffSlots rows). Afflictions
## (kind "effect") are StatusFx's boxes beside the survivor and never show here.
## Desktop: hovering a chip shows its tooltip, a click pins or unpins it. Touch: a tap toggles it. On a
## compact canvas each chip's touch area is padded to 64 px tall and at least 64 px wide; where padded
## areas overlap the nearest chip wins. HuntHud owns the drawing order and calls draw / draw_tooltip / input.

## Owner 2026-10-28: "the buffs under the healthbars etc should be larger and black/white except for a blue
## arrow up or a red arrow down (indicating buff or debuff)". Chips are CHIP px, drawn black and white;
## the one colour is the corner arrow (UP_BLUE for a buff or boon, DOWN_RED for a debuff).
const CHIP := 38.0
const PITCH := 44.0
const ROW_H := 56.0  ## chip plus the countdown under it
const UP_BLUE := Color(0.24, 0.62, 1.0)
const DOWN_RED := Color(0.92, 0.22, 0.20)
const TOUCH := 64.0
const TIP_W := 270.0
const TIP_W_COMPACT := 210.0
const PAD := 8.0
const FOOD_ICON := &"eat"

## Drawn this frame: entry key -> chip rect (the CHIP px square), in row order.
var chips: Dictionary = {}
## The key whose tooltip is pinned (click / tap); "" = none. A hover shows without pinning.
var pinned: String = ""
var hovered: String = ""
## Drawn this frame (empty when no tooltip shows).
var tooltip_rect: Rect2 = Rect2()
var _hover_block: String = ""  # a click that unpinned this chip hides its hover until the pointer leaves it
var _entries: Dictionary = {}
var _compact := false

## Every modifier on her as {key, name, kind, desc, effect, time_left, icon, color}, statuses first.
static func entries(p: Player) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if p == null:
		return out
	if p.statuses:
		for inst in p.statuses.instances():
			var def := Data.status(inst.id)
			if def == null or not def.is_modifier():
				continue
			out.append({"key": str(inst.id), "name": def.display_name, "kind": def.kind, "desc": def.desc,
				"effect": "", "time_left": inst.time_left, "icon": inst.id, "color": def.fx_color, "stacks": inst.stacks})
	var slots := BuffSlots.of(p)
	if slots:
		for row in slots.rows():
			out.append({"key": "food:" + str(row.get("id", "")), "name": str(row.get("display_name", "")), "kind": &"buff",
				"desc": "Food buff (%s). Eating another food of this kind replaces it." % str(row.get("group_name", "")).replace("_", " "),
				"effect": stats_line(row.get("stats", {})), "time_left": float(row.get("time_left", 0.0)),
				"icon": FOOD_ICON, "color": UiTokens.GOLD, "stacks": 1})
	return out

## CREATURECHIPS: the same entry shape for a Creature's active statuses (bleed, venom, knockdown...),
## so its plate and the hunt target bar can draw the player's chip renderer with stack counts.
## Every active status shows (afflictions included — on an animal they are the point); kind passes
## straight through so draw_chip draws no arrow for a plain "effect".
static func creature_entries(c: Creature) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or c.statuses == null:
		return out
	for inst in c.statuses.instances():
		var def := Data.status(inst.id)
		if def == null:
			continue
		out.append({"key": str(inst.id), "name": def.display_name, "kind": def.kind, "desc": def.desc,
			"effect": "", "time_left": inst.time_left, "icon": inst.id, "color": def.fx_color,
			"stacks": inst.stacks})
	return out

## "Max Fatigue +132.8, Perception +20.9" from a BuffSlots row's stats.
static func stats_line(stats: Variant) -> String:
	var parts: PackedStringArray = []
	if stats is Dictionary:
		for k in stats:
			var s: Variant = stats[k]
			var label := str(k).replace("_", " ").capitalize()
			if s is Dictionary:
				if s.has("add"):
					parts.append("%s %+.1f" % [label, float(s["add"])])
				if s.has("sub"):
					parts.append("%s -%.1f" % [label, float(s["sub"])])
				if s.has("mult"):
					parts.append("%s x%.2f" % [label, float(s["mult"])])
	return ", ".join(parts)

## "4:32 left", "Until treated" for the 9999 s statuses.
static func time_text(t: float) -> String:
	if t >= 3600.0:
		return "Until treated"
	var s := int(ceil(maxf(0.0, t)))
	return "%d:%02d left" % [s / 60, s % 60]

## The row from `at`; returns its rect (empty when nothing shows).
func draw(ci: CanvasItem, font: Font, at: Vector2, p: Player, r: Vector2) -> Rect2:
	chips.clear()
	_entries.clear()
	_compact = UiTokens.is_compact(r)
	var x := at.x
	for e in entries(p):
		var key: String = e["key"]
		var box := Rect2(Vector2(x, at.y), Vector2(CHIP, CHIP))
		draw_chip(ci, font, box, e["icon"], e["kind"], key == shown())
		if float(e["time_left"]) < 3600.0:  # "until washed / treated" statuses (9999 s) show no countdown
			var tt := "%.0f" % float(e["time_left"])
			ci.draw_string_outline(font, Vector2(x, at.y + CHIP + 14.0), tt, HORIZONTAL_ALIGNMENT_CENTER, CHIP, 12, 3, Color(0, 0, 0, 0.8))
			ci.draw_string(font, Vector2(x, at.y + CHIP + 14.0), tt, HORIZONTAL_ALIGNMENT_CENTER, CHIP, 12, Color.WHITE)
		chips[key] = box
		_entries[key] = e
		x += PITCH
	if pinned != "" and not chips.has(pinned):
		pinned = ""  # the buff ended
	if hovered != "" and not chips.has(hovered):
		hovered = ""
	return Rect2(at, Vector2(x - at.x - (PITCH - CHIP), ROW_H)) if not chips.is_empty() else Rect2()

## One chip in black and white: a shadow, a black tile with a white rim (GOLD while its tooltip shows), the
## white icon, and for `kind` buff / boon / debuff the coloured arrow on a black disc at the top-right.
## CREATURECHIPS: `stacks` > 1 draws the numbered stack badge (a white-rim disc, the count in white) at
## the chip's bottom-right — the same badge the player's chips will show for multi-stack statuses.
static func draw_chip(ci: CanvasItem, font: Font, box: Rect2, icon: StringName, kind: StringName, lit: bool = false, stacks: int = 1) -> void:
	ci.draw_rect(Rect2(box.position + Vector2(0, 2), box.size), Color(0, 0, 0, 0.45))
	ci.draw_rect(box, Color(0.04, 0.04, 0.05, 0.92))
	ci.draw_rect(box.grow(-1.0), UiTokens.GOLD if lit else Color(0.95, 0.95, 0.95), false, 2.0)
	var tex := HudStatusChip.icon_for(icon)
	var inner := box.grow(-6.0)
	if tex:
		ci.draw_texture_rect(tex, inner, false, Color.WHITE)
	else:
		ci.draw_string(font, Vector2(box.position.x, box.get_center().y + 5.0), str(icon).left(2).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, Color.WHITE)
	if kind == &"debuff" or kind == &"buff" or kind == &"boon":
		var up := kind != &"debuff"
		var c := box.position + Vector2(box.size.x - 2.0, 2.0)
		ci.draw_circle(c, 8.0, Color(0, 0, 0, 0.95), true, -1.0, true)
		ci.draw_circle(c, 8.0, Color(0.95, 0.95, 0.95), false, 1.2, true)
		var tri := PackedVector2Array([c + Vector2(0, -5), c + Vector2(4.6, 1.5), c + Vector2(-4.6, 1.5)]) if up else PackedVector2Array([c + Vector2(0, 5), c + Vector2(4.6, -1.5), c + Vector2(-4.6, -1.5)])
		ci.draw_colored_polygon(tri, UP_BLUE if up else DOWN_RED)
		ci.draw_rect(Rect2(c + Vector2(-1.5, 1.0 if up else -4.5), Vector2(3, 3.5)), UP_BLUE if up else DOWN_RED)
	if stacks > 1:
		draw_stack_badge(ci, font, box, stacks)

## The numbered stack badge: a black disc with a white rim at the chip's bottom-right, count in white.
static func draw_stack_badge(ci: CanvasItem, font: Font, box: Rect2, stacks: int) -> void:
	var c := box.position + Vector2(box.size.x - 1.0, box.size.y - 1.0)
	ci.draw_circle(c, 8.0, Color(0, 0, 0, 0.95), true, -1.0, true)
	ci.draw_circle(c, 8.0, Color(0.95, 0.95, 0.95), false, 1.2, true)
	ci.draw_string(font, c + Vector2(-8.0, 4.5), str(stacks), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 12, Color.WHITE)

## The key whose tooltip shows: the pinned one, else the hovered one.
func shown() -> String:
	return pinned if pinned != "" else hovered

## Where a press counts as this chip: the chip itself on desktop; on a compact canvas padded to 64 px.
func touch_rect(key: String) -> Rect2:
	var b: Rect2 = chips.get(key, Rect2())
	if not _compact or not b.has_area():
		return b
	return Rect2(b.get_center() - Vector2(TOUCH, TOUCH) * 0.5, Vector2(TOUCH, TOUCH))

## The chip under `pos` (nearest centre among the areas that contain it), "" for none.
func chip_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for key in chips:
		if touch_rect(key).has_point(pos):
			var d := pos.distance_to((chips[key] as Rect2).get_center())
			if d < best_d:
				best = key
				best_d = d
	return best

## Click / tap toggles the pin; mouse motion hovers. True when the event was a press on a chip.
func input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return false  # a finger has no hover
		var k := chip_at(event.position)
		if k != _hover_block:
			_hover_block = ""
		hovered = k if k != _hover_block else ""
		return false
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return chip_at(event.position) != ""  # the touch already toggled it; just keep it off the world
		pos = event.position
	if pos == Vector2.INF:
		return false
	var key := chip_at(pos)
	if key == "":
		return false
	toggle(key)
	return true

func toggle(key: String) -> void:
	if pinned == key:
		pinned = ""
		hovered = ""
		_hover_block = key
	else:
		pinned = key
		_hover_block = ""

## The open tooltip under (or above) its chip, on screen and off `taken`. Returns its rect.
func draw_tooltip(ci: CanvasItem, font: Font, taken: Array[Rect2], r: Vector2) -> Rect2:
	tooltip_rect = Rect2()
	var key := shown()
	if key == "" or not _entries.has(key):
		return tooltip_rect
	var e: Dictionary = _entries[key]
	var w := TIP_W_COMPACT if _compact else TIP_W
	var head_px := UiTokens.body(r)
	var px := UiTokens.meta(r)
	var tw := w - PAD * 2.0
	var kind_word := str(e["kind"]).capitalize()
	var body: String = e["desc"]
	if str(e["effect"]) != "":
		body = "%s\n%s" % [e["effect"], body]
	var body_h := font.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, tw, px).y if body != "" else 0.0
	var h := PAD + head_px + 6.0 + body_h + 6.0 + px + PAD
	var chip: Rect2 = chips[key]
	# Under the chip first; then shifted along the row, then right of the chip, each sliding off `taken`.
	var spot := Rect2()
	for x in [chip.position.x, chip.position.x - w * 0.5, chip.end.x + 12.0, r.x * 0.5 - w * 0.5]:
		spot = UiTokens.free_spot(Rect2(Vector2(clampf(x, 8.0, r.x - w - 8.0), chip.end.y + 22.0), Vector2(w, h)), taken, r)
		if spot.has_area():
			break
	if not spot.has_area():
		return tooltip_rect
	var col: Color = e["color"]
	ci.draw_rect(spot, UiTokens.HUD_FILL)
	ci.draw_rect(Rect2(spot.position, Vector2(spot.size.x, 3.0)), col)
	ci.draw_rect(spot.grow(-0.5), Color(col, 0.6), false, 1.0)
	var y := spot.position.y + PAD + head_px * 0.8
	var title := str(e["name"])
	if int(e.get("stacks", 1)) > 1:
		title += " x%d" % int(e["stacks"])
	ci.draw_string(font, Vector2(spot.position.x + PAD, y), UiTokens.ellipsis(font, title, tw - 60.0, head_px), HORIZONTAL_ALIGNMENT_LEFT, -1, head_px, Color.WHITE)
	ci.draw_string(font, Vector2(spot.position.x + PAD, y), kind_word.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, tw, px, col.lightened(0.2))
	y += 6.0
	if body != "":
		ci.draw_multiline_string(font, Vector2(spot.position.x + PAD, y + px * 0.8), body, HORIZONTAL_ALIGNMENT_LEFT, tw, px, -1, UiTokens.TEXT)
		y += body_h
	ci.draw_string(font, Vector2(spot.position.x + PAD, y + 6.0 + px * 0.8), time_text(float(e["time_left"])), HORIZONTAL_ALIGNMENT_LEFT, -1, px, UiTokens.META)
	tooltip_rect = spot
	return spot
