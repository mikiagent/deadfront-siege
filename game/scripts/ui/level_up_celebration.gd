class_name LevelUpCelebration
extends RefCounted
## The HUD side of a level-up (owner 2026-10-21: "make it flashy ... watch out for glitchy movement
## of UI and player"), after docs/reference/durango-levelup-loot-reference.webp (a big gold level
## and the reward lines, top left) and durango-gather-hud-levelup.webp (a hex icon under a flare,
## "Skill Category Level Up", "Processing Lv. 4"). One level-up shows at a time, in arrival order:
## - character: "LEVEL UP" and the new level pop in (overshoot, then settle) over a glow and a short
##   ray fan, the reward lines slide in one by one, the level badge pulses gold;
## - skill category: its hex icon pops under a flare, with the category and its new level.
## On a phone both use the centre band (HudLayout.centre_band). A level-up that arrives while one
## shows waits (a character level ahead of waiting categories); the showing one then shortens to its
## *_min_s. A waiting level-up of the same kind (and category) is replaced by the newer one, so one XP
## grant worth three levels shows the last.
## Each level-up starts its LevelUpFx light at the survivor when it begins to show. Rects come from
## fixed anchors, never from the animation; only the pop and the reveal move, and a target plate
## appearing under a phone banner glides it down instead of snapping. HuntHud ticks and draws this.
## Timings and colours: data/level_fx.json "hud".
# ASSUMPTION: one level-up at a time, the newest of a kind replacing a waiting one, a character level
# first, a shorter hold while others wait (the references show one banner; the PRDs say nothing).
# ASSUMPTION: the skill banner sits top centre on the desktop (the gather reference) and in the
# centre band on a phone, like the character banner.

## AUDIO HOOK: emitted when a level-up starts to show (kind &"character" or &"skill", tree &"" for
## a character level). A sound package connects here; nothing plays a sound yet.
signal shown(kind: StringName, level: int, tree: StringName)

var queue: Array[Dictionary] = []
var current: Dictionary = {}
var _y := -1.0  ## the shown block's eased top, where a plate can push it down
var _warmed := false
var _fx: LevelUpFx  ## the light of the level-up shown last, while it plays

func push_character(level: int, lines: Array, title: String, summary: String) -> void:
	_enqueue({"kind": &"character", "tree": &"", "level": level, "lines": lines.duplicate(true), "title": title, "summary": summary})

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
	if is_instance_valid(_fx):
		_fx.queue_free()
	_fx = null

func showing() -> bool:
	return not current.is_empty()

## "character:<level>", "skill:<tree>:<level>", or "" when nothing shows.
func showing_key() -> String:
	if current.is_empty():
		return ""
	if current["kind"] == &"skill":
		return "skill:%s:%d" % [current["tree"], current["level"]]
	return "character:%d" % current["level"]

func tick(delta: float, hud: HuntHud) -> void:
	var p := hud.player
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
		if p and p.is_inside_tree() and not p.dead:
			_fx = LevelUpFx.spawn(p, current["kind"])
		shown.emit(current["kind"], int(current["level"]), current["tree"])
		return
	current["t"] = float(current["t"]) + delta
	var cfg := LevelUpFx.section("hud")
	var kind := str(current["kind"])
	var hold := float(cfg.get(kind + ("_min_s" if not queue.is_empty() else "_s"), 3.0))
	if float(current["out"]) < 0.0 and float(current["t"]) >= hold:
		current["out"] = current["t"]
	if float(current["out"]) >= 0.0 and float(current["t"]) - float(current["out"]) >= float(cfg.get("fade_s", 0.45)):
		current = {}

## Draws what shows and returns its block (Rect2() when nothing shows). `band` is the phone's centre
## band (empty on the desktop), `plate` the target plate's drawn rect (empty when none).
func draw(hud: HuntHud, band: Rect2, plate: Rect2) -> Rect2:
	if current.is_empty():
		return Rect2()
	var cfg := LevelUpFx.section("hud")
	var t := float(current["t"])
	var a := 1.0
	if float(current["out"]) >= 0.0:
		a = 1.0 - clampf((t - float(current["out"])) / maxf(0.01, float(cfg.get("fade_s", 0.45))), 0.0, 1.0)
	var r := hud.get_viewport_rect().size
	var box := Rect2()
	if band.has_area():
		var top := band.position.y
		if plate.has_area():
			top = maxf(band.end.y, plate.end.y) + 8.0
		box = Rect2(band.position.x, _glide(top, hud), band.size.x, band.size.y if not plate.has_area() else 84.0)
	if current["kind"] == &"skill":
		if not box.has_area():
			var top := 70.0 if not plate.has_area() else plate.end.y + 10.0
			box = Rect2(r.x * 0.5 - 190.0, _glide(top, hud), 380.0, 140.0)
		return _draw_skill(hud, box, t, a, cfg, band.has_area())
	if box.has_area():
		return _draw_banner(hud, box, t, a, cfg)
	var v := HudLayout.vitals_rect(hud, r)
	return _draw_stack(hud, Vector2(v.position.x + 22.0, v.end.y + 24.0), t, a, cfg)

## Eases the block's top towards `top` (a plate appearing pushes it down) instead of snapping.
func _glide(top: float, hud: HuntHud) -> float:
	_y = top if _y < 0.0 else lerpf(_y, top, 1.0 - exp(-14.0 * hud.get_process_delta_time()))
	return roundf(_y) if absf(_y - top) > 0.5 else top

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
	_flare(hud, Vector2(at.x + maxf(head_w, lv_w) * 0.5, lv_base - 30.0), Vector2(maxf(head_w, lv_w) + 160.0, 150.0), t, a, cfg, 72.0)  # rays stay under the vitals
	var head_s := _pop(_u(t, 0.0, cfg), 0.6, 1.1)
	_scaled_text(hud, Vector2(at.x, head_base), "LEVEL UP", head_px, LevelUpFx.color_of(cfg, "bright", Color.WHITE), a * clampf(head_s * 2.0 - 0.6, 0.0, 1.0), head_s, Vector2(at.x, head_base - head_px * 0.35), cfg)
	var lv_s := _pop(_u(t, float(cfg.get("pop_delay_s", 0.12)), cfg), 0.2, float(cfg.get("overshoot", 1.24)))
	_scaled_text(hud, Vector2(at.x, lv_base), level, lv_px, gold, a * clampf(lv_s * 3.0, 0.0, 1.0), lv_s, Vector2(at.x + lv_w * 0.5, lv_base - lv_px * 0.35), cfg)
	var block := Rect2(at, Vector2(maxf(head_w, lv_w), lv_base + 8.0 - at.y))
	var ly := lv_base + 34.0
	for i in range(1, lines.size()):
		var line: Array = lines[i]
		var px := int(line[1])
		var w := _reveal(hud, Vector2(at.x, ly), str(line[0]), px, line[2], t, i - 1, a, cfg)
		block = block.merge(Rect2(at.x, ly - float(px), w + 1.0, float(px) + 6.0))
		ly += float(px) + 8.0
	return block

## Phone character level-up: the level, LEVEL UP, the title and one stat line in an ink box.
func _draw_banner(hud: HuntHud, box: Rect2, t: float, a: float, cfg: Dictionary) -> Rect2:
	var font := hud._font
	var gold := LevelUpFx.color_of(cfg, "gold", Color(1.0, 0.85, 0.35))
	_box(hud, box, t, a, cfg)
	var w := box.size.x - 24.0
	var level := LevelDisplay.label(int(current["level"]))
	var lw := font.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var base := box.position + Vector2(12.0, 34.0)
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
	_reveal(hud, Vector2(box.position.x + 12.0, ly), UiTokens.ellipsis(font, str(current["summary"]), w, 13), 13, Color.WHITE, t, row, a, cfg)
	return box

## Skill category level-up: the category's hex icon under a flare, then "Skill Category Level Up"
## and "<Category> Lv. N". Desktop: centred at the top; phone: the icon left in the band.
func _draw_skill(hud: HuntHud, box: Rect2, t: float, a: float, cfg: Dictionary, phone: bool) -> Rect2:
	var font := hud._font
	var gold := LevelUpFx.color_of(cfg, "gold", Color(1.0, 0.85, 0.35))
	var tree := str(current["tree"])
	var what := "%s %s" % [SkillState.NAMES.get(tree, tree.capitalize()), LevelDisplay.label(int(current["level"]))]
	var head := "Skill Category Level Up"
	var r := 32.0
	var centre := Vector2(box.get_center().x, box.position.y + r + 6.0)
	var block := box
	if phone:
		_box(hud, box, t, a, cfg)
		r = minf(30.0, box.size.y * 0.34)
		centre = Vector2(box.position.x + 14.0 + r, box.get_center().y)
	_flare(hud, centre, Vector2(r * 8.0, r * 3.4), t, a, cfg, r * (1.4 if phone else 2.1), box if phone else Rect2())
	var s := _pop(_u(t, 0.0, cfg), 0.2, float(cfg.get("overshoot", 1.24)))
	_hex_icon(hud, centre, r, tree, a * clampf(s * 3.0, 0.0, 1.0), s, gold)
	var reveal := clampf((t - 0.1) / 0.25, 0.0, 1.0) * a
	if phone:
		var x := centre.x + r + 14.0
		var w := box.end.x - 12.0 - x
		_text(hud, Vector2(x, centre.y - 8.0), UiTokens.ellipsis(font, head, w, 13), 13, UiTokens.META, reveal)
		_text(hud, Vector2(x, centre.y + 20.0), UiTokens.ellipsis(font, what, w, 22), 22, gold, reveal)
		return block
	var hw := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var ww := font.get_string_size(what, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var plate := Rect2(centre.x - maxf(hw, ww) * 0.5 - 22.0, centre.y + r + 10.0, maxf(hw, ww) + 44.0, 60.0)
	hud.draw_rect(plate, Color(UiTokens.INK, UiTokens.INK.a * reveal))
	hud.draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2.0)), Color(gold, 0.8 * reveal))
	_text(hud, Vector2(centre.x - hw * 0.5, plate.position.y + 22.0), head, 15, UiTokens.TEXT, reveal)
	_text(hud, Vector2(centre.x - ww * 0.5, plate.position.y + 50.0), what, 24, gold, reveal)
	return Rect2(plate.position.x, box.position.y, plate.size.x, plate.end.y - box.position.y).merge(Rect2(centre - Vector2(r, r) - Vector2(0.0, 6.0), Vector2(r, r) * 2.0 + Vector2(0.0, 6.0)))

## The level badge on the vitals pulses gold through a character level-up: a gold wash with the
## number redrawn on it, and rings spreading out of it. HuntHud calls this after drawing the badge.
func draw_badge(hud: HuntHud, centre: Vector2, radius: float, num_px: int) -> void:
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
			hud.draw_arc(centre, radius * (1.0 + 0.7 * e), 0.0, TAU, 40, Color(gold, 0.9 * (1.0 - u)), 3.0 * (1.0 - u) + 1.0, true)
		wash = maxf(wash, 1.0 - absf(t - float(i) * period - 0.15) / (period * 0.5))
	if wash > 0.0:
		hud.draw_circle(centre, radius, Color(gold, 0.75 * wash))
		hud.draw_string(hud._font, Vector2(centre.x - radius, centre.y + num_px * 0.36), str(LevelDisplay.player_level()), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, num_px, Color(0.08, 0.06, 0.02).lerp(Color.WHITE, 1.0 - wash))
	var a := 1.0 if float(current["out"]) < 0.0 else 0.0
	hud.draw_arc(centre, radius + 1.0, 0.0, TAU, 40, Color(gold, 0.8 * a), 2.0, true)

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

## A reward line sliding in from the left and fading in, `row` steps after the first. Returns its width.
func _reveal(hud: HuntHud, at: Vector2, text: String, px: int, col: Color, t: float, row: int, a: float, cfg: Dictionary) -> float:
	var u := clampf((t - float(cfg.get("line_at_s", 0.4)) - float(row) * float(cfg.get("line_stagger_s", 0.05))) / maxf(0.01, float(cfg.get("line_in_s", 0.28))), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	var dx := roundf(-float(cfg.get("line_slide_px", 14)) * (1.0 - e))
	_text(hud, at + Vector2(dx, 0.0), text, px, col, a * e)
	return hud._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x

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
