class_name YieldCard
extends RefCounted
## The gain helpers (docs/design/ui-redesign-spec.md §4.5, §5) and the left XP feed (§6, owner §1.6).
## The per-node yield card this file drew (UIGATHER) is retired: TopFeed (top_feed.gd) now shows each
## gain at the top middle with its tier (owner 2026-10-28). Kept here: a stack's trait chips (grey
## negative, gold positive, green rare), their layout, the meta line, and the skill XP lines under the vitals.

static func _rank(polarity: StringName) -> int:
	return {&"rare": 0, &"positive": 1}.get(polarity, 2)

## [[text, polarity]] for a stack, rare first (InvAttributes: the same rows the bag inspector shows).
static func chips_for(stack: ItemStack) -> Array:
	var out: Array = []
	if stack == null:
		return out
	var sec := InvAttributes.sections(stack)
	for cls in ["rare", "positive", "negative"]:
		for row: Dictionary in sec[cls]:
			out.append([InvAttributes.line(row), StringName(cls)])
	return out

## "Stone · Lv. 1": the item's first category and the lot's level.
static func meta_line(stack: ItemStack, id: StringName) -> String:
	var def := Data.item(id)
	var cat := str(def.categories[0]).replace("_", " ").capitalize() if def and not def.categories.is_empty() else "Item"
	var lv := int(stack.attributes.get("level", stack.level)) if stack else 1
	return "%s · %s" % [cat, LevelDisplay.label(maxi(1, lv))]

## Chip rows wrapped to `width`: [[Rect2 local to the chip area, text, polarity]] and the area height.
static func layout_chips(font: Font, chips: Array, width: float, px: int) -> Array:
	var out: Array = []
	var x := 0.0
	var y := 0.0
	var h := float(px) + 10.0
	for c in chips:
		var text := "%s %s" % [UiTokens.trait_chip_prefix(c[1]), str(c[0])]
		var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 16.0, width)
		if x > 0.0 and x + w > width:
			x = 0.0
			y += h + 6.0
		out.append([Rect2(x, y, w, h), text, c[1]])
		x += w + 6.0
	return [out, (y + h) if not chips.is_empty() else 0.0]

## The left XP feed (§6): one row per skill toast under `top_left`, newest last — a small hex with the
## skill's initial, "Gathering +6 XP Lv. 1" and a thin bar of that tree's progress to its next level.
## Each row takes a free spot off `taken`; returns the rects drawn, keyed "skilltoast<i>".
static func draw_feed(hud: Control, font: Font, rows: Array, top_left: Vector2, taken: Array[Rect2], skills: SkillState) -> Dictionary:
	var out := {}
	var view := hud.get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	var row_h := 34.0 if compact else 44.0
	var px := 14 if compact else 18
	var w := 220.0 if compact else 290.0
	var y := top_left.y
	for i in rows.size():
		var e: Dictionary = rows[i]
		var age := float(e["t"])
		var life := float(e["life"])
		var a := 1.0 - smoothstep(life * 0.6, life, age)
		var big := bool(e["big"])
		var cand := Rect2(top_left.x, y, w, row_h)
		var box := UiTokens.free_spot(cand, taken, view)
		if not box.has_area():
			continue
		taken.append(box)
		out["skilltoast%d" % i] = box
		y = box.end.y + 6.0
		hud.draw_rect(box, Color(UiTokens.HUD_FILL, 0.8 * a))
		var hc := Vector2(box.position.x + row_h * 0.5 + 2.0, box.get_center().y)
		var hr := row_h * 0.38
		var hex := UiTokens.hex_points(hc, hr, true)
		hex.append(hex[0])
		var accent := UiTokens.GOLD if big else UiTokens.XP
		hud.draw_polyline(hex, Color(accent, a), 2.0, true)
		var tree := str(e["tree"])
		var nm := str(SkillState.NAMES.get(tree, tree))
		UiTokens.draw_centered(hud, font, hc, nm.left(1), int(hr * 1.0), Color(UiTokens.TEXT, a))
		var tx := hc.x + hr + 10.0
		var base := box.position.y + row_h * 0.5 + float(px) * 0.2
		var parts: Array = [[nm + " ", UiTokens.TEXT, px]]
		if big:
			parts = [["▲ " + nm + " ", UiTokens.GOLD, px]]
		else:
			parts.append(["+%d XP " % int(round(float(e["amount"]))), UiTokens.GOLD, px])
		var lv := int(e["level"])
		if lv <= 0 and skills:
			lv = skills.level_of(tree)
		if lv > 0:
			parts.append([LevelDisplay.label(lv), UiTokens.MUTED, px - 4])
		for p in parts:
			hud.draw_string(font, Vector2(tx, base), str(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(p[2]), Color(p[1], a))
			tx += font.get_string_size(str(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(p[2])).x
		if skills:
			var lvl := skills.level_of(tree)
			var f := clampf(skills.xp_of(tree) / maxf(1.0, SkillState.xp_to_next(lvl)), 0.0, 1.0)
			var bar := Rect2(hc.x + hr + 10.0, box.end.y - 7.0, box.end.x - hc.x - hr - 20.0, 3.0)
			hud.draw_rect(bar, Color(1, 1, 1, 0.15 * a))
			hud.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color(UiTokens.XP, a))
	return out
