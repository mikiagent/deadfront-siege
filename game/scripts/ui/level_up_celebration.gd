class_name LevelUpCelebration
extends RefCounted
## The HUD side of a level-up (owner 2026-10-21: "make it flashy ... watch out for glitchy movement
## of UI and player"), after docs/reference/durango-levelup-loot-reference.webp (a big gold level
## and the reward lines, top left) and durango-gather-hud-levelup.webp (a hex icon under a flare,
## "Skill Category Level Up", "Processing Lv. 4"). One level-up shows at a time, in arrival order:
## - character: "LEVEL UP" and the new level pop in (overshoot, then settle) over a glow and a short
##   ray fan, the reward lines slide in one by one, the level badge pulses gold;
## - skill category: a TopFeed row at the top middle (owner 2026-10-28), its hex icon popping under
##   a flare, with the category and its new level; this queue keeps its clock and its light.
## The desktop character stack hugs the left edge, centred between the vitals and the quick slots
## (owner 2026-10-28: "move this UI to the far left"); the XP feed and the status chips under the
## vitals keep off it. On a phone the character banner
## takes the centre band (HudLayout.centre_band) from the quest card.
## A level-up that arrives while one shows waits (a character level ahead of waiting categories); the
## showing one then shortens to its *_min_s. A waiting level-up of the same kind (and category) is
## replaced by the newer one, so one XP grant worth three levels shows the last.
## Each level-up starts its LevelUpFx light at the survivor when it begins to show. Rects come from
## fixed anchors, never from the animation; only the pop and the reveal move. A target plate
## appearing under a phone banner moves it below the plate at once and fades it back in there (it
## never slides across the plate); when the plate leaves, it glides back up. HuntHud ticks and draws
## this. Timings and colours: data/level_fx.json "hud".
# ASSUMPTION: one level-up at a time, the newest of a kind replacing a waiting one, a character level
# first, a shorter hold while others wait (the references show one banner; the PRDs say nothing).
# ASSUMPTION: the desktop stack is centred in the left column's free height; on a phone the
# character banner keeps the centre band (390 px leave no left column for 13 lines).
# ASSUMPTION: each level-up shown pulses the MENU hex and, in the open nav menu, the Skills entry's
# badge (the old Skills rail hex's halo moved there with the hex, owner 2026-10-28).

## AUDIO HOOK: emitted when a level-up starts to show (kind &"character" or &"skill", tree &"" for
## a character level). A sound package connects here; nothing plays a sound yet.
signal shown(kind: StringName, level: int, tree: StringName)

var queue: Array[Dictionary] = []
var current: Dictionary = {}
var _y := -1.0  ## the phone block's top and height, eased upwards (a plate left)
var _h := 0.0
var _form := ""  ## "band": a change of form re-places the block
var _in := 1.0  ## 0..1, the block fading back in after a plate pushed it down
var _warmed := false
var _fx: LevelUpFx  ## the light of the level-up shown last, while it plays
var _clip := Rect2()  ## desktop: where the flare's glow and streak may reach (the view)
var _pulse_t := -1.0  ## seconds since the last level-up began to show (MENU / Skills badge pulse)

## `lines`: [text, px, colour] rows, or [text, px, colour, icon id] for a row led by a UI icon (the brain
## for skill points). `sp`: the phone banner's skill points, drawn after `summary` behind the brain.
func push_character(level: int, lines: Array, title: String, summary: String, sp: String = "") -> void:
	_enqueue({"kind": &"character", "tree": &"", "level": level, "lines": lines.duplicate(true), "title": title, "summary": summary, "sp": sp})

## SkillState.level_up: a category reached `level` (not an unlock or the occupation's head start).
func push_skill(tree: StringName, level: int) -> void:
	_enqueue({"kind": &"skill", "tree": tree, "level": level})

## A waiting entry of the same kind and category is replaced. A character level-up goes ahead of
## waiting categories: SkillState hears World.pioneer_changed before the HUD (the survivor is built
## first) and releases capped categories, so their level-ups arrive before the level that freed them.
func _enqueue(e: Dictionary) -> void:
	for i in queue.size():
		if queue[i]["kind"] == e["kind"] and queue[i]["tree"] == e["tree"]:
			queue[i] = e
			return
	if e["kind"] == &"character":
		queue.push_front(e)
	else:
		queue.append(e)

## Drops every waiting and showing level-up and ends the light now (labs and tests).
func clear() -> void:
	queue.clear()
	current = {}
	if _hud_feed:
		_hud_feed.clear()
	_pulse_t = -1.0
	if is_instance_valid(_fx):
		_fx.queue_free()
	_fx = null

func showing() -> bool:
	return not current.is_empty()

## On a phone the quest card yields the band to a character banner; a skill level-up is a TopFeed
## row and keeps it. HuntHud asks before it draws the card.
func hides_quest(_band: Rect2 = Rect2(), _quest: Rect2 = Rect2()) -> bool:
	return showing() and current["kind"] == &"character"

## "character:<level>", "skill:<tree>:<level>", or "" when nothing shows.
func showing_key() -> String:
	if current.is_empty():
		return ""
	if current["kind"] == &"skill":
		return "skill:%s:%d" % [current["tree"], current["level"]]
	return "character:%d" % current["level"]

var _hud_feed: TopFeed  ## the HUD's top-middle column, where skill rows show (set on the first tick)

func tick(delta: float, hud: HuntHud) -> void:
	_hud_feed = hud.top_feed
	delta = minf(delta, 0.1)  # a stalled frame (app backgrounded, a hitch) must not skip the celebration unseen
	var p := hud.player
	if _pulse_t >= 0.0:
		_pulse_t += delta
	if not _warmed and p and p.is_inside_tree():
		_warmed = true
		LevelUpFx.warm_up(p)
	if current.is_empty():
		# The next one waits for the last light too: two lights never play at once.
		if queue.is_empty() or is_instance_valid(_fx):
			return
		current = queue.pop_front()
		current["t"] = 0.0
		current["out"] = -1.0
		_y = -1.0
		_in = 1.0
		if p and p.is_inside_tree() and not p.dead:
			_fx = LevelUpFx.spawn(p, current["kind"])
		_pulse_t = 0.0
		if current["kind"] == &"skill":
			hud.top_feed.push_skill(current["tree"], int(current["level"]))  # the top-middle column draws it
		shown.emit(current["kind"], int(current["level"]), current["tree"])
		return
	current["t"] = float(current["t"]) + delta
	var cfg := LevelUpFx.section("hud")
	var kind := str(current["kind"])
	var hold := float(cfg.get(kind + ("_min_s" if not queue.is_empty() else "_s"), 3.0))
	if float(current["out"]) < 0.0 and float(current["t"]) >= hold:
		current["out"] = current["t"]
		if current["kind"] == &"skill":
			hud.top_feed.end_skill()
	if float(current["out"]) >= 0.0 and float(current["t"]) - float(current["out"]) >= float(cfg.get("fade_s", 0.45)):
		current = {}

## Draws what shows and returns its block (Rect2() when nothing shows). `band` is the phone's centre
## band (empty on the desktop), `plate` the target plate's drawn rect and `quest` the quest card's
## (each empty when not drawn this frame).
func draw(hud: HuntHud, band: Rect2, plate: Rect2, quest: Rect2 = Rect2()) -> Rect2:
	if current.is_empty():
		return Rect2()
	var cfg := LevelUpFx.section("hud")
	var t := float(current["t"])
	var a := 1.0
	if float(current["out"]) >= 0.0:
		a = 1.0 - clampf((t - float(current["out"])) / maxf(0.01, float(cfg.get("fade_s", 0.45))), 0.0, 1.0)
	if current["kind"] == &"skill":
		return Rect2()  # a TopFeed row (owner 2026-10-28: skill level-ups at the top middle)
	if not band.has_area():
		var at := desktop_anchor(hud, stack_height(current["lines"]))
		_clip = Rect2(Vector2.ZERO, hud.get_viewport_rect().size)
		return _draw_stack(hud, at, t, a, cfg)
	var box := band
	var form := "band"
	if plate.has_area():
		box = Rect2(band.position.x, maxf(band.end.y, plate.end.y) + 8.0, band.size.x, 84.0)
	box = _place(box, form, hud, cfg)
	a *= _in
	return _draw_banner(hud, box, t, a, cfg)

## Where the phone block stands this frame. Moving up (a plate left) it glides there, its height
## easing too. Pushed down (a plate appeared) or changing form, it moves at once and fades back in
## over replace_in_s, so it never slides across the plate.
func _place(box: Rect2, form: String, hud: HuntHud, cfg: Dictionary) -> Rect2:
	var dt := hud.get_process_delta_time()
	if _y < 0.0 or form != _form or box.position.y > _y + 0.5:
		_in = 0.0 if _y >= 0.0 else 1.0
		_y = box.position.y
		_h = box.size.y
		_form = form
	else:
		var k := 1.0 - exp(-14.0 * dt)
		_y = lerpf(_y, box.position.y, k)
		_h = lerpf(_h, box.size.y, k)
	_in = minf(1.0, _in + dt / maxf(0.01, float(cfg.get("replace_in_s", 0.2))))
	var y := roundf(_y) if absf(_y - box.position.y) > 0.5 else box.position.y
	var h := roundf(_h) if absf(_h - box.size.y) > 0.5 else box.size.y
	return Rect2(box.position.x, y, box.size.x, h)

## Desktop character level-up: the Durango gold stack top left with LEVEL UP above the level.
func _draw_stack(hud: HuntHud, at: Vector2, t: float, a: float, cfg: Dictionary) -> Rect2:
	var font := hud._font
	var gold := LevelUpFx.color_of(cfg, "gold", Color(1.0, 0.85, 0.35))
	var lines: Array = current["lines"]
	var level := str(lines[0][0]) if not lines.is_empty() else LevelDisplay.label(int(current["level"]))
	var head_px := 34
	var lv_px := 46
	var head_base := at.y + float(head_px)
	var lv_base := head_base + 52.0
	var lv_w := font.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, lv_px).x
	var head_w := font.get_string_size("LEVEL UP", HORIZONTAL_ALIGNMENT_LEFT, -1, head_px).x
	_flare(hud, Vector2(at.x + maxf(head_w, lv_w) * 0.5, lv_base - 30.0), Vector2(maxf(head_w, lv_w) + 160.0, 150.0), t, a, cfg, 72.0, _clip)  # rays stay under the vitals
	var head_s := _pop(_u(t, 0.0, cfg), 0.6, 1.1)
	_scaled_text(hud, Vector2(at.x, head_base), "LEVEL UP", head_px, LevelUpFx.color_of(cfg, "bright", Color.WHITE), a * clampf(head_s * 2.0 - 0.6, 0.0, 1.0), head_s, Vector2(at.x, head_base - head_px * 0.35), cfg)
	var lv_s := _pop(_u(t, float(cfg.get("pop_delay_s", 0.12)), cfg), 0.2, float(cfg.get("overshoot", 1.24)))
	_scaled_text(hud, Vector2(at.x, lv_base), level, lv_px, gold, a * clampf(lv_s * 3.0, 0.0, 1.0), lv_s, Vector2(at.x + lv_w * 0.5, lv_base - lv_px * 0.35), cfg)
	var block := Rect2(at, Vector2(maxf(head_w, lv_w), lv_base + 8.0 - at.y))
	var ly := lv_base + 34.0
	for i in range(1, lines.size()):
		var line: Array = lines[i]
		var px := int(line[1])
		var w := _reveal(hud, Vector2(at.x, ly), str(line[0]), px, line[2], t, i - 1, a, cfg, StringName(line[3]) if line.size() > 3 else &"")
		block = block.merge(Rect2(at.x, ly - float(px), w + 1.0, float(px) + 6.0))
		ly += float(px) + 8.0
	return block

## Phone character level-up: the level (over a glow kept inside the box), LEVEL UP, the title and
## one stat line in an ink box.
func _draw_banner(hud: HuntHud, box: Rect2, t: float, a: float, cfg: Dictionary) -> Rect2:
	var font := hud._font
	var gold := LevelUpFx.color_of(cfg, "gold", Color(1.0, 0.85, 0.35))
	_box(hud, box, t, a, cfg)
	var w := box.size.x - 24.0
	var level := LevelDisplay.label(int(current["level"]))
	var lw := font.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var base := box.position + Vector2(12.0, 34.0)
	_flare(hud, base + Vector2(lw * 0.5, -10.0), Vector2(lw + 140.0, 70.0), t, a, cfg, 34.0, box)
	var lv_s := _pop(_u(t, 0.0, cfg), 0.2, float(cfg.get("overshoot", 1.24)))
	_scaled_text(hud, base, level, 28, gold, a * clampf(lv_s * 3.0, 0.0, 1.0), lv_s, base + Vector2(lw * 0.5, -10.0), cfg)
	var head_s := _pop(_u(t, float(cfg.get("pop_delay_s", 0.12)), cfg), 0.6, 1.1)
	var head_at := base + Vector2(lw + 14.0, -2.0)
	var head := UiTokens.ellipsis(font, "LEVEL UP", maxf(1.0, w - lw - 14.0), 20)
	_scaled_text(hud, head_at, head, 20, LevelUpFx.color_of(cfg, "bright", Color.WHITE), a * clampf(head_s * 2.0 - 0.6, 0.0, 1.0), head_s, head_at + Vector2(0.0, -7.0), cfg)
	var ly := box.position.y + 58.0
	var row := 0
	if str(current["title"]) != "":
		_reveal(hud, Vector2(box.position.x + 12.0, ly), UiTokens.ellipsis(font, str(current["title"]), w, 14), 14, gold, t, row, a, cfg)
		ly += 22.0
		row += 1
	var sp := str(current.get("sp", ""))
	var sum_w := w - (font.get_string_size(sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24.0 if sp != "" else 0.0)
	var sw := _reveal(hud, Vector2(box.position.x + 12.0, ly), UiTokens.ellipsis(font, str(current["summary"]), sum_w, 13), 13, Color.WHITE, t, row, a, cfg)
	if sp != "":
		_reveal(hud, Vector2(box.position.x + 12.0 + sw + 6.0, ly), sp, 13, Color.WHITE, t, row, a, cfg, &"brain")
	return box

## The bottom level bar pulses gold through a character level-up (LEVELBAR moved it off the
## retired top-left badge): a gold wash over the bar and a glow spreading up from it.
func draw_bar_pulse(hud: HuntHud, bar: Rect2) -> void:
	if current.is_empty() or current["kind"] != &"character":
		return
	var cfg := LevelUpFx.section("hud")
	var t := float(current["t"])
	var gold := LevelUpFx.color_of(cfg, "gold", Color(1.0, 0.85, 0.35))
	var period := float(cfg.get("badge_pulse_s", 0.7))
	var wash := 0.0
	for i in int(cfg.get("badge_pulses", 3)):
		var u := (t - float(i) * period) / (period * 1.3)
		if u > 0.0 and u < 1.0:
			var e := 1.0 - pow(1.0 - u, 2.0)
			var h := bar.size.y + 14.0 * e
			hud.draw_rect(Rect2(bar.position.x, bar.end.y - h, bar.size.x, h), Color(gold, 0.35 * (1.0 - u)))
		wash = maxf(wash, 1.0 - absf(t - float(i) * period - 0.15) / (period * 0.5))
	if wash > 0.0:
		hud.draw_rect(bar, Color(gold, 0.75 * wash))
	var a := 1.0 if float(current["out"]) < 0.0 else 0.0
	hud.draw_rect(Rect2(bar.position.x, bar.position.y - 1.0, bar.size.x, 1.0), Color(gold, 0.8 * a))

## The desktop stack's top left (owner 2026-10-28: "move this UI to the far left please"): the
## view's left edge inside the safe area, centred in the height between the vitals' bottom and the
## quick slots' top (HuntHud.hands_spot), else from the vitals' bottom down. The left XP feed and
## the status chips under the vitals are drawn after it and keep off it.
static func desktop_anchor(hud: HuntHud, h: float) -> Vector2:
	var view := hud.get_viewport_rect().size
	var v := HudLayout.vitals_rect(hud, view)
	var x := v.position.x + 16.0  # the vitals' text column, inside the safe area
	var lo := v.end.y + 10.0
	var hi := hud.hands_spot().y - 12.0 - h
	return Vector2(x, roundf(clampf((view.y - h) * 0.5, lo, maxf(lo, hi))))

## The desktop stack's height for `lines` (_draw_stack's layout): LEVEL UP and the level, then a
## line per row.
static func stack_height(lines: Array) -> float:
	var h := 34.0 + 52.0 + 34.0 - 8.0
	for i in range(1, lines.size()):
		h += float(lines[i][1]) + 8.0
	return h

## 0..1, the MENU hex / Skills badge pulse: badge_pulses rings badge_pulse_s apart after a level-up
## began to show; 0 once they are done.
func menu_pulse() -> float:
	var cfg := LevelUpFx.section("hud")
	var span := float(cfg.get("badge_pulses", 3)) * float(cfg.get("badge_pulse_s", 0.7))
	return 0.0 if _pulse_t < 0.0 or _pulse_t > span + 0.6 else 1.0 - clampf((_pulse_t - span) / 0.6, 0.0, 1.0)

## Gold rings spreading out of a badge (or a hex's centre) while menu_pulse() runs; the same rhythm
## as the vitals badge. `r` is the badge's radius.
func draw_pulse_rings(ci: CanvasItem, centre: Vector2, r: float) -> void:
	if menu_pulse() <= 0.0:
		return
	var cfg := LevelUpFx.section("hud")
	var gold := LevelUpFx.color_of(cfg, "gold", Color(1.0, 0.85, 0.35))
	var period := float(cfg.get("badge_pulse_s", 0.7))
	for i in int(cfg.get("badge_pulses", 3)):
		var u := (_pulse_t - float(i) * period) / (period * 1.3)
		if u > 0.0 and u < 1.0:
			var e := 1.0 - pow(1.0 - u, 2.0)
			ci.draw_arc(centre, r * (1.0 + 1.4 * e), 0.0, TAU, 40, Color(gold, 0.9 * (1.0 - u)), 3.0 * (1.0 - u) + 1.0, true)

## The MENU hex while menu_pulse() runs: a gold glow and rim round the hex, and rings out of its
## badge corner (HexButton draws the badge at r * (0.55, -0.55) from its centre). HuntHud draws
## this under the hex (its children draw after it), so only the glow past the hex's edge shows.
func draw_menu_pulse(hud: HuntHud, hex: HexButton) -> void:
	var k := menu_pulse()
	if k <= 0.0 or hex == null or not hex.is_visible_in_tree():
		return
	var cfg := LevelUpFx.section("hud")
	var glow := LevelUpFx.color_of(cfg, "glow", Color(1.0, 0.7, 0.18))
	var hr := hex.hex_rect()
	var c := hr.get_center()
	var rr := (hr.size.x if hex.flat_top else hr.size.y) * 0.5  # circumradius
	var beat := 0.5 + 0.5 * cos(TAU * _pulse_t / float(cfg.get("badge_pulse_s", 0.7)))
	hud.draw_texture_rect(LevelUpFx._dot_texture(), Rect2(c - Vector2(rr, rr) * 1.9, Vector2(rr, rr) * 3.8), false, Color(glow, (0.25 + 0.35 * beat) * k))
	var pts := UiTokens.hex_points(c, rr * 1.08, hex.flat_top)
	pts.append(pts[0])
	hud.draw_polyline(pts, Color(LevelUpFx.color_of(cfg, "gold", Color(1.0, 0.85, 0.35)), (0.5 + 0.5 * beat) * k), 3.0, true)
	draw_pulse_rings(hud, c + Vector2(rr * 0.55, -rr * 0.55), rr * 0.26)

# ---------------------------------------------------------------- pieces

## Time since the pop of a piece starting at `delay`, over pop_s, as 0..1.
func _u(t: float, delay: float, cfg: Dictionary) -> float:
	return clampf((t - delay) / maxf(0.01, float(cfg.get("pop_s", 0.42))), 0.0, 1.0)

## Scale of a popping piece: from `from` up past 1 to `over` (eased out), then back to 1. Monotonic in
## each half, so it overshoots once and settles; 1 exactly from u = 1 on.
static func _pop(u: float, from: float, over: float) -> float:
	if u >= 1.0:
		return 1.0
	if u < 0.6:
		return lerpf(from, over, 1.0 - pow(1.0 - u / 0.6, 3.0))
	return lerpf(over, 1.0, smoothstep(0.6, 1.0, u))

## A warm glow, a lens streak and a slowly turning fan of rays behind a popping piece, fading out by
## rays_s. With `clip` (a phone banner) the glow and the streak stay inside it, off the vitals.
func _flare(hud: HuntHud, centre: Vector2, size: Vector2, t: float, a: float, cfg: Dictionary, ray_len: float, clip: Rect2 = Rect2()) -> void:
	var glow := LevelUpFx.color_of(cfg, "glow", Color(1.0, 0.7, 0.18))
	var rays_s := float(cfg.get("rays_s", 1.8))
	var burst := clampf(t / 0.15, 0.0, 1.0) * (1.0 - smoothstep(rays_s * 0.5, rays_s, t))
	var steady := 0.32 + 0.68 * burst
	var halo := Rect2(centre - size * 0.5, size)
	var streak := Rect2(centre - Vector2(size.x * 0.75, 6.0), Vector2(size.x * 1.5, 12.0))
	if clip.has_area():
		halo = halo.intersection(clip.grow(-2.0))
		streak = streak.intersection(clip.grow(-2.0))
	hud.draw_texture_rect(LevelUpFx._dot_texture(), halo, false, Color(glow, 0.55 * steady * a))
	hud.draw_texture_rect(LevelUpFx._dot_texture(), streak, false, Color(1.0, 0.95, 0.8, 0.7 * burst * a))
	if burst <= 0.0:
		return
	var n := 12
	for i in n:
		var ang := t * 0.35 + TAU * float(i) / float(n)
		var half := 0.045
		var inner := ray_len * 0.25
		var pts := PackedVector2Array([centre + Vector2.from_angle(ang - half) * inner, centre + Vector2.from_angle(ang) * ray_len * (0.75 + 0.25 * float(i % 2)), centre + Vector2.from_angle(ang + half) * inner])
		var cols := PackedColorArray([Color(glow, 0.5 * burst * a), Color(glow, 0.0), Color(glow, 0.5 * burst * a)])
		hud.draw_polygon(pts, cols)

## The ink box of a phone banner, a gold accent and a gold edge glow that fades after the pop.
func _box(hud: HuntHud, box: Rect2, t: float, a: float, cfg: Dictionary) -> void:
	var gold := LevelUpFx.color_of(cfg, "gold", Color(1.0, 0.85, 0.35))
	var edge := 1.0 - smoothstep(0.2, 1.4, t)
	hud.draw_rect(box, Color(UiTokens.INK, UiTokens.INK.a * a))
	hud.draw_rect(box, Color(gold, (0.25 + 0.6 * edge) * a), false, 2.0)
	hud.draw_rect(Rect2(box.position, Vector2(3.0, box.size.y)), Color(gold, a))
	var sweep := clampf(t / 0.7, 0.0, 1.0)
	if sweep < 1.0:
		var sw := minf(70.0, box.size.x * 0.25)
		var sx := lerpf(box.position.x, box.end.x - sw, sweep)
		hud.draw_texture_rect(LevelUpFx._dot_texture(), Rect2(sx, box.position.y + 2.0, sw, box.size.y - 4.0), false, Color(1.0, 0.92, 0.7, 0.28 * (1.0 - sweep) * a))

## A pointy-top hex (HexButton's shape) with a gold rim and the category's white icon, scaled `s`.
func _hex_icon(hud: HuntHud, centre: Vector2, r: float, tree: String, a: float, s: float, gold: Color) -> void:
	if a <= 0.0:
		return
	var rr := r * s
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(centre + Vector2.from_angle(deg_to_rad(60.0 * float(i) - 30.0)) * rr)
	hud.draw_colored_polygon(pts, Color(0.05, 0.05, 0.06, 0.92 * a))
	pts.append(pts[0])
	hud.draw_polyline(pts, Color(gold, a), 2.5, true)
	var icon := UiIcons.icon(StringName(tree))
	if icon:
		var isz := rr * 1.1
		hud.draw_texture_rect(icon, Rect2(centre - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, Color(1, 1, 1, a))

## A reward line sliding in from the left and fading in, `row` steps after the first, led by the UI
## icon `icon` when given (sized a little over the text, as on the Skills sheet). Returns its width.
func _reveal(hud: HuntHud, at: Vector2, text: String, px: int, col: Color, t: float, row: int, a: float, cfg: Dictionary, icon: StringName = &"") -> float:
	var u := clampf((t - float(cfg.get("line_at_s", 0.4)) - float(row) * float(cfg.get("line_stagger_s", 0.05))) / maxf(0.01, float(cfg.get("line_in_s", 0.28))), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	var dx := roundf(-float(cfg.get("line_slide_px", 14)) * (1.0 - e))
	var lead := 0.0
	var tex: Texture2D = UiIcons.icon(icon) if icon != &"" else null
	if tex:
		var isz := float(px) * 1.3
		hud.draw_texture_rect(tex, Rect2(at + Vector2(dx, -float(px) * 0.36 - isz * 0.5), Vector2(isz, isz)), false, Color(col, col.a * a * e))
		lead = isz + 6.0
	_text(hud, at + Vector2(dx + lead, 0.0), text, px, col, a * e)
	return lead + hud._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x

func _text(hud: HuntHud, at: Vector2, text: String, px: int, col: Color, a: float) -> void:
	if a <= 0.0:
		return
	hud.draw_string(hud._font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.6 * a))
	hud.draw_string(hud._font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, col.a * a))

## Glowing text scaled `s` about `pivot` (canvas px); drawn untransformed once it has settled.
func _scaled_text(hud: HuntHud, at: Vector2, text: String, px: int, col: Color, a: float, s: float, pivot: Vector2, cfg: Dictionary) -> void:
	if a <= 0.0 or s <= 0.01:
		return
	if s != 1.0:
		hud.draw_set_transform(pivot * (1.0 - s), 0.0, Vector2(s, s))
	var glow := LevelUpFx.color_of(cfg, "glow", Color(1.0, 0.7, 0.18))
	for i in 8:
		hud.draw_string(hud._font, at + Vector2.from_angle(TAU * float(i) / 8.0) * 2.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(glow, 0.2 * a))
	_text(hud, at, text, px, col, a)
	if s != 1.0:
		hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
