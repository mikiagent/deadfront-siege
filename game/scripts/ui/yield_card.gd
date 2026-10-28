class_name YieldCard
extends RefCounted
## B1 yield card (docs/design/ui-redesign-spec.md §4.5, owner §1.3): what one gathered unit turned out
## to be, in a card above the node — thumbnail in the lot's natural colour (spec 35, the stack's
## `tint`), name, "Stone · Lv. 1 · +1", and its trait chips (§5: grey negative, gold positive, green
## rare) under a 3 px top edge in the best chip's colour. It replaces the top-centre "+n Item" toast
## (and pickup_toast.gd): one card at a time, ~3 s or until the next gain.
## Also draws the left XP feed (§6, owner §1.6): skill XP lines under the vitals, where the item toasts
## used to stand.

const LIFE := 3.0
const FADE := 0.4
const W_DESKTOP := 300.0
const W_COMPACT := 220.0

## {stack, chips, id, n, t, anchor (Node3D), height}; empty when no card shows.
var card: Dictionary = {}
var _uids: Dictionary = {}  ## the bag's instance uids at the last gain: the new ones are this gain's

## The bag as it is now is the baseline: only instances that arrive after this count as a gain.
func sync(player: Player) -> void:
	_uids = player.inventory.uids() if player and player.inventory else {}

## A gain landed in the bag (HuntHud.toast). Picks the instance that just arrived so its traits and
## colour show; anchors on the node being worked, else on the survivor.
func show_gain(player: Player, id: StringName, n: int) -> void:
	if player == null or n <= 0:
		return
	# The instances this gain added (one item per cell, so +2 is two of them): the card shows the first
	# and every trait any of them carries. None new (a gain the bag merged): the last such item stands in.
	var stack: ItemStack = null
	var fresh: Array[ItemStack] = []
	if player.inventory:
		for s: ItemStack in player.inventory.slots:
			if s != null and s.def_id == id:
				if not _uids.has(s.uid):
					fresh.append(s)
				stack = s
	if not fresh.is_empty():
		stack = fresh[0]
	var chips: Array = []
	var seen := {}
	for s in (fresh if not fresh.is_empty() else ([stack] if stack else [])):
		for c in chips_for(s):
			if not seen.has(c[0]):
				seen[c[0]] = true
				chips.append(c)
	chips.sort_custom(func (a: Array, b: Array) -> bool: return _rank(a[1]) < _rank(b[1]))
	sync(player)
	var anchor: Node3D = player
	var h := 2.2
	var gt: Variant = player.gather_target
	if gt is HarvestNode and is_instance_valid(gt):
		anchor = gt
		h = (gt as HarvestNode).top_of_node() + 0.4
	card = {"stack": stack, "chips": chips, "id": id, "n": n, "t": 0.0, "anchor": anchor, "height": h}

static func _rank(polarity: StringName) -> int:
	return {&"rare": 0, &"positive": 1}.get(polarity, 2)

func tick(delta: float) -> void:
	if card.is_empty():
		return
	card["t"] = float(card["t"]) + delta
	if float(card["t"]) >= LIFE or not is_instance_valid(card["anchor"]):
		card = {}

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

## The top edge's colour: the best chip (rare > positive > negative), else the plain rim.
static func edge_color(chips: Array) -> Color:
	if chips.is_empty():
		return Color(UiTokens.HUD_RIM, 0.5)
	return UiTokens.trait_chip_fg(chips[0][1])

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

## Draw the card above its anchor on a free spot off `taken`; returns the drawn box (empty if none).
func draw(hud: Control, font: Font, cam: Camera3D, taken: Array[Rect2]) -> Rect2:
	if card.is_empty() or cam == null:
		return Rect2()
	var anchor: Node3D = card["anchor"]
	var at := anchor.global_position + Vector3(0.0, float(card["height"]), 0.0)
	if cam.is_position_behind(at):
		return Rect2()
	var view := hud.get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	var w := W_COMPACT if compact else W_DESKTOP
	var thumb := 36.0 if compact else 52.0
	var name_px := 17 if compact else 22
	var meta_px := 13 if compact else 16
	var chip_px := UiTokens.CHIP_PX if compact else 15
	var pad := 8.0 if compact else 12.0
	var stack: ItemStack = card["stack"]
	var id: StringName = card["id"]
	var chips: Array = card["chips"]
	var lay := layout_chips(font, chips, w - pad * 2.0, chip_px)
	var chip_h: float = lay[1]
	var h := 3.0 + pad + thumb + (pad + chip_h if chip_h > 0.0 else 0.0) + pad
	var sp := cam.unproject_position(at)
	var cand := Rect2(Vector2(sp.x - w * 0.5, sp.y - h - 8.0), Vector2(w, h))
	var box := UiTokens.free_spot(cand, taken, view, true)
	if not box.has_area():
		return Rect2()
	var t := float(card["t"])
	var a := 1.0 - smoothstep(LIFE - FADE, LIFE, t)
	hud.draw_rect(box, Color(UiTokens.HUD_FILL, UiTokens.HUD_FILL.a * a))
	hud.draw_rect(Rect2(box.position, Vector2(w, 3.0)), Color(edge_color(chips), a))
	# Thumbnail: the item's art tinted with the lot's natural colour (never rarity, spec 35).
	var tr := Rect2(box.position + Vector2(pad, 3.0 + pad), Vector2(thumb, thumb))
	hud.draw_rect(tr, Color(0.16, 0.17, 0.18, a))
	var tex := ItemIcons.texture(id)
	if tex:
		var tint := stack.tint_color() if stack else Color.WHITE
		hud.draw_texture_rect(tex, tr.grow(-3.0), false, Color(tint, a))
	var def := Data.item(id)
	var nm := def.display_name if def and def.display_name != "" else str(id).replace("_", " ").capitalize()
	var tx := tr.end.x + pad
	var tw := box.end.x - pad - tx
	hud.draw_string(font, Vector2(tx, tr.position.y + float(name_px) * 0.95), UiTokens.ellipsis(font, nm, tw, name_px), HORIZONTAL_ALIGNMENT_LEFT, -1, name_px, Color(UiTokens.TEXT, a))
	var meta := meta_line(stack, id) + " · "
	var my := tr.position.y + float(name_px) * 1.1 + float(meta_px) + 4.0
	hud.draw_string(font, Vector2(tx, my), meta, HORIZONTAL_ALIGNMENT_LEFT, -1, meta_px, Color(UiTokens.MUTED, a))
	var mw := font.get_string_size(meta, HORIZONTAL_ALIGNMENT_LEFT, -1, meta_px).x
	hud.draw_string(font, Vector2(tx + mw, my), "+%d" % int(card["n"]), HORIZONTAL_ALIGNMENT_LEFT, -1, meta_px, Color(UiTokens.GOLD, a))
	var origin := Vector2(box.position.x + pad, tr.end.y + pad)
	for c in lay[0]:
		var r: Rect2 = c[0]
		r.position += origin
		var pol: StringName = c[2]
		var sb := UiTokens.trait_chip_style(pol)
		hud.draw_rect(r, Color(sb.bg_color, sb.bg_color.a * a))
		hud.draw_string(font, Vector2(r.position.x + 8.0, r.position.y + r.size.y * 0.5 + float(chip_px) * 0.36), str(c[1]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10.0, chip_px, Color(UiTokens.trait_chip_fg(pol), a))
	return box

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
