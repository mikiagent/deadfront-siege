class_name TopFeed
extends RefCounted
## The top-middle notification column (owner 2026-10-28: "move the skill category level up
## notifications to the top middle of the screen. Also use that same UI for gathering resources to see
## what you have gathered, effects range from grey (small whoop) yellow (wow) green (WOOO) using the
## item traits as a guide for how good the loot is"). One widget, two kinds of row:
## - skill: a category level-up (LevelUpCelebration starts and ends it, in step with its light);
## - gain: what a gain put in the bag, the item's art in its lot colour, name, "+n" and its trait chips.
##   Its tier (grey / yellow / green) comes from those traits by the rule in data/level_fx.json "gain",
##   and the pop, glow, sparkles and rays scale with it. A rare find (GatherFeedback) lifts its row to
##   green. A gain of an item whose row still shows adds to it ("+3 Wood" becomes "+5 Wood").
## At most max_rows rows show (fewer on a compact canvas); later ones wait their turn, a skill row
## first. A new row goes under those showing, so rows only ever move up (into a gap a row left). The column hangs under the top HUD band (the vitals' bottom on the desktop, under the centre
## band on a phone), centred, each row on the nearest free spot off the taken rects, easing there
## (never a jump). It replaces the per-node yield card (YieldCard keeps only the chip helpers and the
## left XP feed).
# ASSUMPTION: the tier rule, the row counts and every timing/colour in level_fx.json "gain" (no
# Durango numbers). The loot palette there is its own: never the status colours (green = healing).

## SOUND HOOK: a row starts to show. kind &"skill" or &"gain", tier &"grey"/&"yellow"/&"green"
## (&"skill" for a skill row), id the item or the tree. Nothing plays a sound yet.
signal shown(kind: StringName, tier: StringName, id: StringName)

const TIERS := [&"grey", &"yellow", &"green"]

var rows: Array[Dictionary] = []  ## showing, top to bottom
var waiting: Array[Dictionary] = []
var _uids: Dictionary = {}  ## the bag's instance uids at the last gain: the new ones are this gain's

static func cfg() -> Dictionary:
	return LevelUpFx.section("gain")

static func tier_cfg(tier: StringName) -> Dictionary:
	var v: Variant = (cfg().get("tiers", {}) as Dictionary).get(str(tier), {})
	return v if v is Dictionary else {}

static func tier_color(tier: StringName) -> Color:
	return LevelUpFx.color_of(tier_cfg(tier), "color", Color(0.72, 0.72, 0.72))

## The tier a gain earns from its chips ([[text, polarity]], YieldCard.chips_for) and the stack's
## attribute keys: green on a polarity in green_polarity or a key in green_keys, yellow on one in
## yellow_polarity, else grey.
static func tier_for(chips: Array, stack: ItemStack) -> StringName:
	var c := cfg()
	var keys: Array = c.get("green_keys", [])
	if stack:
		for k in stack.attributes:
			if keys.has(str(k)) and stack.attributes[k]:
				return &"green"
	for want in [["green_polarity", &"green"], ["yellow_polarity", &"yellow"]]:
		var pols: Array = c.get(want[0], [])
		for ch in chips:
			if pols.has(str(ch[1])):
				return want[1]
	return &"grey"

## The bag as it is now is the baseline: only instances that arrive after this count as a gain.
func sync(player: Player) -> void:
	_uids = player.inventory.uids() if player and player.inventory else {}

## A gain landed in the bag (HuntHud.toast): the instances it added give the art, colour and traits.
func push_gain(player: Player, id: StringName, n: int) -> void:
	if player == null or n <= 0:
		return
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
	# PERKCAP: the row shows ONE item's perks (the first fresh one), never a union over several lots.
	var chips: Array = YieldCard.chips_for(stack)
	sync(player)
	var tier := tier_for(chips, stack)
	for s in fresh:
		if tier_for(YieldCard.chips_for(s), s) == &"green":
			tier = &"green"
	_add({"kind": &"gain", "id": id, "n": n, "chips": chips, "stack": stack, "tier": tier})

## A rare result for `id` (GatherFeedback: a find, a rare part on a carcass): the row of that item
## that just showed turns green and says so; with none, a green row of its own (`where`, e.g. "on the
## raptor", stands in for "+n" when nothing reached the bag).
func push_rare(id: StringName, where: String = "") -> void:
	for r in rows + waiting:
		if r["kind"] == &"gain" and r["id"] == id and float(r.get("t", 0.0)) < 0.6:
			r["tier"] = &"green"
			_merge_chips(r["chips"], [["Rare find", &"rare"]])
			r["t"] = minf(float(r.get("t", 0.0)), 0.05)  # re-pops at its new tier
			return
	_add({"kind": &"gain", "id": id, "n": 0, "where": where, "chips": [["Rare find", &"rare"]], "stack": null, "tier": &"green"})

## A skill category level-up row; it stays until end_skill (LevelUpCelebration keeps the clock).
func push_skill(tree: StringName, level: int) -> void:
	var e := {"kind": &"skill", "id": tree, "tree": tree, "level": level, "tier": &"skill", "t": 0.0, "y": -1.0, "out": -1.0}
	if rows.size() < max_rows():
		rows.append(e)  # new rows go under the ones showing: a row never moves down under a newcomer
		shown.emit(&"skill", &"skill", tree)
	else:
		waiting.push_front(e)

func end_skill() -> void:
	for r in rows + waiting:
		if r["kind"] == &"skill" and float(r["out"]) < 0.0:
			r["out"] = float(r["t"])
	waiting = waiting.filter(func (r: Dictionary) -> bool: return r["kind"] != &"skill")

func clear() -> void:
	rows.clear()
	waiting.clear()

static func _merge_chips(into: Array, more: Array) -> void:
	for c in more:
		if not into.any(func (o: Array) -> bool: return o[0] == c[0]):
			into.append(c)
	into.sort_custom(func (a: Array, b: Array) -> bool: return YieldCard._rank(a[1]) < YieldCard._rank(b[1]))

func max_rows(compact: bool = _compact) -> int:
	return int(cfg().get("max_rows_compact" if compact else "max_rows", 2 if compact else 3))

var _compact := false

## Collapses into a showing (or waiting) row of the same item that is not fading yet: its count grows,
## its tier rises, it pops again; else a new row, or a waiting one when the column is full.
func _add(e: Dictionary) -> void:
	for r in rows + waiting:
		if r["kind"] == &"gain" and r["id"] == e["id"] and float(r.get("out", -1.0)) < 0.0 and str(r.get("where", "")) == str(e.get("where", "")):
			# The count is a running total of the collapsed gains; the chips, art and tier are the latest
			# item's own (PERKCAP: merging chips stacked Soft Lv. 1/2/3 from 21 different branches).
			r["n"] = int(r["n"]) + int(e["n"])
			r["gains"] = int(r.get("gains", 1)) + 1
			r["chips"] = e["chips"]
			r["stack"] = e["stack"]
			if TIERS.find(e["tier"]) < TIERS.find(r["tier"]):
				r["tier"] = e["tier"]
			if TIERS.find(e["tier"]) > TIERS.find(r["tier"]):
				r["tier"] = e["tier"]
				r["t"] = 0.0
			else:
				r["t"] = minf(float(r.get("t", 0.0)), float(cfg().get("bump_t", 0.12)))  # a small re-pop, the clock restarts
			r["life_t"] = 0.0
			return
	e["t"] = 0.0
	e["life_t"] = 0.0
	e["y"] = -1.0
	e["out"] = -1.0
	if rows.size() < max_rows():
		rows.append(e)
		shown.emit(&"gain", e["tier"], e["id"])
	else:
		waiting.append(e)

func tick(delta: float) -> void:
	delta = minf(delta, 0.1)
	var fade := float(cfg().get("fade_s", 0.4))
	for r in rows:
		r["t"] = float(r["t"]) + delta
		if r["kind"] == &"gain":
			r["life_t"] = float(r["life_t"]) + delta
			if float(r["out"]) < 0.0 and float(r["life_t"]) >= float(tier_cfg(r["tier"]).get("life", 3.0)):
				r["out"] = float(r["t"])
	rows = rows.filter(func (r: Dictionary) -> bool: return float(r["out"]) < 0.0 or float(r["t"]) - float(r["out"]) < fade)
	while rows.size() < max_rows() and not waiting.is_empty():
		var e: Dictionary = waiting.pop_front()
		e["t"] = 0.0
		e["life_t"] = 0.0
		rows.append(e)
		shown.emit(e["kind"], e["tier"], e["id"])

## HUDREDRAW: true while any row shows or waits (the column eases, pops and fades every frame).
func busy() -> bool:
	return not rows.is_empty() or not waiting.is_empty()

## The column's centre: the view's middle on the desktop; on a phone the middle of the centre band's
## part left of the day/night dial (the dial hangs off the minimap into the band).
static func column_cx(hud: HuntHud, view: Vector2) -> float:
	var band := HudLayout.centre_band(hud, view)
	if not band.has_area():
		return view.x * 0.5
	var right := band.end.x
	if hud._daynight and hud._daynight.is_visible_in_tree():
		right = minf(right, hud._daynight.get_global_rect().position.x - 8.0)
	return (band.position.x + right) * 0.5

## Draws the column and returns its rects: "levelup" for a skill row, "toast<i>" for gain rows.
## `top` is the column's top edge, `cx` its centre; every row keeps off `taken` (and is added to it).
func draw(hud: HuntHud, font: Font, cx: float, top: float, taken: Array[Rect2]) -> Dictionary:
	var out := {}
	var view := hud.get_viewport_rect().size
	_compact = UiTokens.is_compact(view)
	var c := cfg()
	var w := float(c.get("width_compact" if _compact else "width", 300 if _compact else 380))
	var dt := hud.get_process_delta_time()
	var y := top  # the gain rows' cursor: the top middle
	# LAYOUT (owner 2026-10-30: "the level-up banner goes left, below the hunger ring"): a skill row
	# keeps its own column, hung from the left edge under the stomach ring.
	var left := HudLayout.levelup_top(hud, view)
	var sy := left.y
	var gi := 0
	for r in rows:
		var h := _height(r, font, w)
		var skill: bool = r["kind"] == &"skill"
		var cand := Rect2(left.x, sy, minf(w, view.x - left.x - 8.0), h) if skill else Rect2(cx - w * 0.5, y, w, h)
		var box := UiTokens._slide(cand, taken, view, 1.0)  # down only: the column stays in order
		if not box.has_area():
			continue
		var target := box.position.y
		if float(r["y"]) < 0.0:
			r["y"] = target  # a new row appears where it belongs (its pop is the motion)
		else:
			r["y"] = lerpf(float(r["y"]), target, 1.0 - exp(-float(c.get("ease_k", 14.0)) * dt))
			if absf(float(r["y"]) - target) < 0.5:
				r["y"] = target
		box.position.y = roundf(float(r["y"]))
		for tk in taken:  # easing must not cross a block: then it stands at its spot at once
			if box.intersects(tk):
				box.position.y = target
				r["y"] = target
				break
		taken.append(box)
		if skill:
			sy = box.end.y + 6.0
		else:
			y = box.end.y + 6.0
		if r["kind"] == &"skill":
			_draw_skill(hud, font, box, r)
			out["levelup"] = box
		else:
			_draw_gain(hud, font, box, r)
			out["toast%d" % gi] = box
			gi += 1
	return out

func _height(r: Dictionary, font: Font, w: float) -> float:
	if r["kind"] == &"skill":
		return 36.0 if _compact else 84.0  # one row of the strip under a phone band (~38 px clear above her)
	if _compact:
		return 36.0  # one line on a phone: the strip under the band is ~60 px tall
	var pad := 6.0 if _compact else 10.0
	var thumb := 34.0 if _compact else 46.0
	var chip_px := UiTokens.CHIP_PX if _compact else 14
	var tx := pad + thumb + pad
	var chips: float = YieldCard.layout_chips(font, r["chips"], w - tx - pad, chip_px)[1]
	return maxf(thumb + pad * 2.0, pad + (16.0 if _compact else 22.0) + 6.0 + chips + pad) + 3.0

## 0..1 alpha, and the pop scale, of a row at its tier.
func _anim(r: Dictionary) -> Vector2:
	var t := float(r["t"])
	var tc := tier_cfg(r["tier"]) if r["kind"] == &"gain" else LevelUpFx.section("hud")
	var a := 1.0
	if float(r["out"]) >= 0.0:
		a = 1.0 - clampf((t - float(r["out"])) / maxf(0.01, float(cfg().get("fade_s", 0.4))), 0.0, 1.0)
	var u := clampf(t / maxf(0.01, float(tc.get("pop_s", 0.3))), 0.0, 1.0)
	var over := float(tc.get("overshoot", 1.15))
	var from := float(tc.get("pop_from", 0.6))
	if _compact:  # a phone row has no margin: it must not swell over the dial or the figure
		over = minf(over, 1.06)
		from = maxf(from, 0.75)
	var s := LevelUpCelebration._pop(u, from, over)
	return Vector2(a * clampf(t / 0.08, 0.0, 1.0), s)

## The tier's burst envelope: 0 before, up in 0.12 s, gone by burst_s.
static func _k(t: float, tc: Dictionary) -> float:
	var life := float(tc.get("burst_s", 1.2))
	return clampf(t / 0.12, 0.0, 1.0) * (1.0 - smoothstep(life * 0.4, life, t))

## Behind the row (drawn first): a soft halo that pulses then settles, and a sunburst of rays from
## the row's centre poking out above and below it; both scale with the tier (none for grey).
func _halo(hud: HuntHud, box: Rect2, r: Dictionary, col: Color, a: float, tc: Dictionary) -> void:
	var t := float(r["t"])
	var k := _k(t, tc)
	var glow := float(tc.get("glow", 0.0))
	if glow > 0.0:
		var steady := 0.3 + 0.7 * k
		hud.draw_texture_rect(LevelUpFx._dot_texture(), box.grow_individual(box.size.x * 0.35, box.size.y * 0.9, box.size.x * 0.35, box.size.y * 0.9), false, Color(col, glow * 0.6 * steady * a))
	var rays := int(tc.get("rays", 0))
	if k <= 0.0 or rays <= 0:
		return
	var c := box.get_center()
	for i in rays:
		var ang := t * 0.4 + TAU * float(i) / float(rays)
		var len := box.size.y * (1.6 + 0.8 * float(i % 2)) * k
		var dir := Vector2.from_angle(ang)
		var side := dir.orthogonal() * len * 0.09  # a wedge, wide enough to read past the row's edge
		var pts := PackedVector2Array([c + side, c + dir * len, c - side])
		hud.draw_polygon(pts, PackedColorArray([Color(col, 0.75 * k * a), Color(col, 0.0), Color(col, 0.75 * k * a)]))

## Over the row (drawn last): sparks flying out of its edge, their count and reach by the tier.
func _burst(hud: HuntHud, box: Rect2, r: Dictionary, col: Color, a: float, tc: Dictionary) -> void:
	var t := float(r["t"])
	var n := int(tc.get("sparks", 0))
	if n <= 0 or _k(t, tc) <= 0.0:
		return
	var u := clampf(t / float(tc.get("burst_s", 1.2)), 0.0, 1.0)
	var reach := float(tc.get("spark_px", 60.0))
	var c := box.get_center()
	var half := box.size * 0.5
	for i in n:
		var ang := float(i) * 2.39996  # golden angle: an even spread with no state
		var dir := Vector2.from_angle(ang)
		var edge := c + dir * minf(half.x / maxf(0.001, absf(dir.x)), half.y / maxf(0.001, absf(dir.y)))  # where the ray leaves the row
		var d := reach * (0.4 + 0.6 * float((i * 7) % 10) / 10.0) * (1.0 - pow(1.0 - u, 2.0))
		hud.draw_circle(edge + dir * d + Vector2(0.0, -16.0 * u), 3.4 * (1.0 - u) + 0.8, Color(col.lerp(Color.WHITE, 0.5), (1.0 - u) * a))

func _draw_gain(hud: HuntHud, font: Font, box: Rect2, r: Dictionary) -> void:
	var an := _anim(r)
	var a := an.x
	if a <= 0.0:
		return
	var tier: StringName = r["tier"]
	var tc := tier_cfg(tier)
	var col := tier_color(tier)
	var pad := 5.0 if _compact else 10.0
	var thumb := 26.0 if _compact else 46.0
	var tr := Rect2(box.position + Vector2(pad, 3.0 + pad), Vector2(thumb, thumb))
	_halo(hud, box, r, col, a, tc)
	if an.y != 1.0:
		hud.draw_set_transform(box.get_center() * (1.0 - an.y), 0.0, Vector2(an.y, an.y))
	hud.draw_rect(box, Color(UiTokens.HUD_FILL, UiTokens.HUD_FILL.a * a))
	hud.draw_rect(Rect2(box.position, Vector2(box.size.x, 3.0)), Color(col, a))
	var edge := float(tc.get("edge", 0.0)) * (1.0 - smoothstep(0.2, 1.2, float(r["t"])))
	if edge > 0.0:
		hud.draw_rect(box, Color(col, edge * a), false, 2.0)
	var id: StringName = r["id"]
	var stack: ItemStack = r["stack"]
	hud.draw_rect(tr, Color(0.16, 0.17, 0.18, a))
	var tex := ItemIcons.texture(id)
	if tex:
		hud.draw_texture_rect(tex, tr.grow(-3.0), false, Color(stack.tint_color() if stack else Color.WHITE, a))
	var name_px := 15 if _compact else 21
	var tx := tr.end.x + pad
	var plus := ("+%d%s" % [int(r["n"]), " total" if int(r.get("gains", 1)) > 1 else ""]) if int(r["n"]) > 0 else str(r.get("where", ""))
	var pw := font.get_string_size(plus, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
	var base := tr.position.y + float(name_px) * 0.9 if not _compact else tr.get_center().y + float(name_px) * 0.36
	var chip_px := UiTokens.CHIP_PX if _compact else 14
	var chips: Array = r["chips"]
	var cw := 0.0
	if _compact and not chips.is_empty():  # one line: the best chip only, before the count
		chips = [chips[0]]
		cw = minf(font.get_string_size("%s %s" % [UiTokens.trait_chip_prefix(chips[0][1]), str(chips[0][0])], HORIZONTAL_ALIGNMENT_LEFT, -1, chip_px).x + 16.0, (box.size.x - tx + box.position.x) * 0.5)
	hud.draw_string(font, Vector2(tx, base), UiTokens.ellipsis(font, GatherFeedback.item_name(id), box.end.x - pad - tx - pw - cw - 12.0, name_px), HORIZONTAL_ALIGNMENT_LEFT, -1, name_px, Color(UiTokens.TEXT, a))
	hud.draw_string(font, Vector2(box.end.x - pad - pw, base), plus, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px, Color(col if tier != &"grey" else UiTokens.GOLD, a))
	var lay := YieldCard.layout_chips(font, chips, (cw if _compact else box.end.x - pad - tx), chip_px)
	var origin := Vector2(tx, base + 8.0) if not _compact else Vector2(box.end.x - pad - pw - 6.0 - cw, box.get_center().y - (float(chip_px) + 10.0) * 0.5 + 1.5)
	for ch in lay[0]:
		var cr: Rect2 = ch[0]
		cr.position += origin
		var sb := UiTokens.trait_chip_style(ch[2])
		hud.draw_rect(cr, Color(sb.bg_color, sb.bg_color.a * a))
		hud.draw_string(font, Vector2(cr.position.x + 8.0, cr.position.y + cr.size.y * 0.5 + float(chip_px) * 0.36), str(ch[1]), HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 10.0, chip_px, Color(UiTokens.trait_chip_fg(ch[2]), a))
	if an.y != 1.0:
		hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_burst(hud, box, r, col, a, tc)

## The category's hex icon under the level-up flare, "Skill Category Level Up", "<Category> Lv. N".
func _draw_skill(hud: HuntHud, font: Font, box: Rect2, r: Dictionary) -> void:
	var an := _anim(r)
	var a := an.x
	if a <= 0.0:
		return
	var hc := LevelUpFx.section("hud")
	var gold := LevelUpFx.color_of(hc, "gold", Color(1.0, 0.85, 0.35))
	var cel := hud._levelups
	var t := float(r["t"])
	var rad := box.size.y * (0.4 if _compact else 0.34)
	var centre := Vector2(box.position.x + (8.0 if _compact else 14.0) + rad, box.get_center().y)
	cel._box(hud, box, t, a, hc)
	cel._flare(hud, centre, Vector2(rad * 8.0, rad * 3.4), t, a, hc, rad * 1.6, box)
	cel._hex_icon(hud, centre, rad, str(r["tree"]), a * clampf(an.y * 3.0, 0.0, 1.0), an.y, gold)
	var x := centre.x + rad + 14.0
	var w := box.end.x - 12.0 - x
	var reveal := clampf((t - 0.1) / 0.25, 0.0, 1.0) * a
	var head_px := 12 if _compact else 15
	var what_px := 16 if _compact else 24
	var what := "%s %s" % [str(SkillState.NAMES.get(str(r["tree"]), str(r["tree"]).capitalize())), LevelDisplay.label(int(r["level"]))]
	var head_y := centre.y - (4.0 if _compact else 6.0)
	cel._text(hud, Vector2(x, head_y), UiTokens.ellipsis(font, "Skill Category Level Up", w, head_px), head_px, UiTokens.META, reveal)
	cel._text(hud, Vector2(x, head_y + float(what_px) + (2.0 if _compact else float(what_px) * 0.1 + 4.0)), UiTokens.ellipsis(font, what, w, what_px), what_px, gold, reveal)
