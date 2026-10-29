class_name HudEventState
extends RefCounted
## Short-lived HUD messages and hit effects. HuntHud renders this state but no longer owns its lifecycle.

var toasts: Array = []
var notices: Array = []
var bites: Array = []
var player_floats: Array = []
## Skill XP bars (spec 25 §7 "it gives you an xp amount"): {tree, amount, level, text, big, life, t}.
## Owner 2026-10-28: "skill xp and progress updates should slow down and be batched": one bar per tree
## that stays while gains keep arriving. Each gain moves the light-green "pending" ghost at once; the real
## fill ("shown", in level units: 3.4 = Lv. 3, 40 %) eases up to it once gains stop for SKILL_CATCHUP_DELAY,
## flashing when it rolls over a level, then the bar lingers SKILL_LIFE and fades. A tree level-up is a
## bigger line of its own.
var skill_toasts: Array = []

## Kept for callers: a bar now takes every gain of its tree while it shows.
const SKILL_MERGE := 1.0
## Seconds a caught-up bar lingers before it is gone (it fades over the last 40 %).
const SKILL_LIFE := 2.5
const SKILL_LEVEL_LIFE := 3.0
## Seconds without a gain before the real fill starts to follow the ghost.
const SKILL_CATCHUP_DELAY := 0.6
## The real fill's ease toward the ghost: a share of the gap per second, never slower than the floor.
const SKILL_FILL_K := 2.5
const SKILL_FILL_MIN := 0.15
## Seconds the level roll-over flash lasts on the bar.
const SKILL_FLASH := 0.45
## At most this many skill lines on screen at once, newest kept: a burst of gains (or several tree
## levels from one banked grant) must not stack down over the survivor.
const SKILL_MAX := 4

## "+4 Gathering XP", the same words the HUD draws and the test reads.
static func skill_text(tree: String, amount: float) -> String:
	return "+%d %s XP" % [int(round(amount)), str(SkillState.NAMES.get(tree, tree))]

## The tree's progress in level units after its XP is resolved (level + share of the next rung), never
## past the level it may reach now. Read right after a gain, before SkillState._resolve has run.
static func progress_of(skills: SkillState, tree: String) -> float:
	if skills == null or not skills.trees.has(tree):
		return -1.0
	var lv := skills.level_of(tree)
	var x := skills.xp_of(tree)
	var cap := lv if SkillState.research_gated(tree) else maxi(lv, skills.level_cap(tree))  # a gated bar holds full
	while lv < cap and x >= SkillState.xp_to_next(lv):
		x -= SkillState.xp_to_next(lv)
		lv += 1
	return float(lv) + clampf(x / maxf(1.0, SkillState.xp_to_next(lv)), 0.0, 1.0)

## `progress` is the tree's level-unit progress after this gain (progress_of); without it the bar draws
## the live share only.
func add_skill_xp(tree: String, amount: float, level: int = 0, progress: float = -1.0) -> void:
	if amount <= 0.0:
		return
	# A level-up line of the same tree is not merged into: the level is the bigger news and sits above.
	for entry in skill_toasts:
		if str(entry["tree"]) == tree and not bool(entry["big"]):
			entry["amount"] = float(entry["amount"]) + amount
			entry["text"] = skill_text(tree, float(entry["amount"]))
			entry["level"] = level if level > 0 else int(entry["level"])
			entry["t"] = 0.0
			entry["idle"] = 0.0
			if progress >= 0.0:
				entry["pending"] = maxf(float(entry["pending"]), progress)
				if float(entry["shown"]) < 0.0:
					entry["shown"] = progress
			return
	# The real fill starts where this gain found the tree: back by the gain's share of its rung, not
	# below the level it is on (a gain that rolled a level starts the fill at the new level's floor).
	var shown := -1.0
	if progress >= 0.0:
		var rung := SkillState.xp_to_next(int(floor(progress)))
		shown = maxf(floor(progress), progress - amount / maxf(1.0, rung))
	skill_toasts.append({"tree": tree, "amount": amount, "level": level, "text": skill_text(tree, amount), "big": false, "life": SKILL_LIFE, "t": 0.0, "idle": 0.0, "pending": progress, "shown": shown, "flash": SKILL_FLASH})
	_trim_skill()

## The bar's draw state: [real fill 0..1, ghost fill 0..1, level shown, flash 0..1].
static func skill_bar(entry: Dictionary) -> Array:
	var shown := float(entry.get("shown", -1.0))
	var pending := float(entry.get("pending", -1.0))
	if shown < 0.0 or pending < 0.0:
		return [-1.0, -1.0, 0, 0.0]
	var lv := floori(shown)
	var ghost := 1.0 if floori(pending) > lv else pending - float(lv)
	var flash := 1.0 - clampf(float(entry.get("flash", SKILL_FLASH)) / SKILL_FLASH, 0.0, 1.0)
	return [shown - float(lv), ghost, lv, flash]

func _tick_skill(entry: Dictionary, delta: float) -> void:
	var pending := float(entry.get("pending", -1.0))
	var shown := float(entry.get("shown", -1.0))
	entry["flash"] = float(entry.get("flash", SKILL_FLASH)) + delta
	if bool(entry["big"]) or pending < 0.0 or shown < 0.0 or shown >= pending:
		entry["t"] = float(entry["t"]) + delta  # caught up: the linger clock runs
		return
	entry["idle"] = float(entry.get("idle", 0.0)) + delta
	if float(entry["idle"]) < SKILL_CATCHUP_DELAY:
		return  # gains still arriving: the ghost leads, the real fill waits
	var next := minf(pending, shown + maxf(SKILL_FILL_MIN, (pending - shown) * SKILL_FILL_K) * delta)
	if next >= pending - 0.002:
		next = pending
	if floori(next) > floori(shown):
		entry["flash"] = 0.0  # rolled over a level: fill to full, flash, start the next rung
	entry["shown"] = next

## Consecutive level-ups of one tree fold into one line with the newest level ("Survival Lv. 6"): a
## character level-up releases the banked XP of every tree at once, and four lines for two trees read
## as four separate events.
func add_skill_level(tree: String, level: int) -> void:
	for entry in skill_toasts:
		if str(entry["tree"]) == tree and bool(entry["big"]):
			entry["level"] = maxi(int(entry["level"]), level)
			entry["text"] = "%s %s" % [str(SkillState.NAMES.get(tree, tree)), LevelDisplay.label(int(entry["level"]))]
			entry["t"] = 0.0
			return
	skill_toasts.append({"tree": tree, "amount": 0.0, "level": level, "text": "%s %s" % [str(SkillState.NAMES.get(tree, tree)), LevelDisplay.label(level)], "big": true, "life": SKILL_LEVEL_LIFE, "t": 0.0})
	_trim_skill()

## Keeps the newest SKILL_MAX lines: the oldest gain gives way rather than the stack growing over the HUD.
func _trim_skill() -> void:
	while skill_toasts.size() > SKILL_MAX:
		skill_toasts.pop_front()

func add_bite(amount: float, heavy: bool) -> void:
	bites.append({"t": 0.0, "heavy": heavy, "x": randf_range(-6.0, 6.0)})
	player_floats.append({"t": 0.0, "n": amount, "x": randf_range(-18.0, 18.0)})

## A text float over the survivor (REST's recovery: "+3 HP", "-1 fatigue"), `dy` px below the damage row.
func add_float(text: String, color: Color, dy: float = 0.0) -> void:
	player_floats.append({"t": 0.0, "txt": text, "col": color, "x": 0.0, "dy": dy})

## STATUSFX: a damage-over-time tick's number over her ("-0.2", "-3"): smaller than a hit's 22 px, it
## pops in from 70 % and then rises and fades on the same path as a hit's number.
const TICK_PX := 16
## Two statuses ticking on one frame: the second number stands beside the first, not on it.
func add_tick(text: String, color: Color) -> void:
	var same := player_floats.filter(func (e: Dictionary) -> bool: return e.get("pop", false) and float(e["t"]) == 0.0).size()
	player_floats.append({"t": 0.0, "txt": text, "col": color, "x": randf_range(-5.0, 5.0) + 38.0 * float(same), "dy": 0.0, "px": TICK_PX, "pop": true})

## A refusal or hint (warning look); `ok` gives a confirmation ("Game saved") the green look instead.
func add_notice(text: String, ok: bool = false) -> void:
	for entry in notices:
		if entry["text"] == text and entry["t"] < 1.5:
			entry["t"] = 0.0
			return
	notices.append({"text": text, "t": 0.0, "ok": ok})

## Notice row (spec §7 B4): a warning on dark red with a LIFE edge and a warning triangle; a
## confirmation on ink with an OK_GREEN edge and a check. Text left of the glyph; `box` comes from
## notice_width() so the glyph has room.
const NOTICE_GLYPH := 16.0
const WARN_BG := Color(0.36, 0.08, 0.06, 0.9)

## The glyph is desktop only: on a compact canvas the 22 px it adds left no free spot for a second
## notice beside HANDS and the nameplate (ui_real_capture_lab "busy" at 844x390).
static func notice_glyph(view: Vector2) -> bool:
	return not UiTokens.is_compact(view)

static func notice_width(font: Font, text: String, px: int, view: Vector2 = Vector2(1600, 900)) -> float:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return tw + (NOTICE_GLYPH + 26.0 if notice_glyph(view) else 24.0)  # 8 pad, glyph, 6 gap, text, 12 pad

static func draw_notice(ci: CanvasItem, font: Font, box: Rect2, text: String, px: int, alpha: float, ok: bool) -> void:
	var edge := UiTokens.OK_GREEN if ok else UiTokens.LIFE
	ci.draw_rect(box, Color(UiTokens.HUD_FILL, 0.88 * alpha) if ok else Color(WARN_BG, WARN_BG.a * alpha))
	ci.draw_rect(Rect2(box.position, Vector2(4.0, box.size.y)), Color(edge, alpha))
	var ink := Color(1, 0.94, 0.88, alpha)
	if not notice_glyph(ci.get_viewport_rect().size):
		ci.draw_string(font, Vector2(box.position.x + 12.0, box.get_center().y + px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
		return
	var c := Vector2(box.position.x + 8.0 + NOTICE_GLYPH * 0.5, box.get_center().y)
	var g := minf(NOTICE_GLYPH, box.size.y - 8.0) * 0.55
	if ok:
		ci.draw_polyline(PackedVector2Array([c + Vector2(-g * 0.6, 0), c + Vector2(-g * 0.15, g * 0.45), c + Vector2(g * 0.65, -g * 0.5)]), Color(edge, alpha), 2.5, true)
	else:
		var tri := PackedVector2Array([c + Vector2(0, -g * 0.85), c + Vector2(g * 0.95, g * 0.75), c + Vector2(-g * 0.95, g * 0.75), c + Vector2(0, -g * 0.85)])
		ci.draw_polyline(tri, ink, 2.0, true)
		ci.draw_line(c + Vector2(0, -g * 0.3), c + Vector2(0, g * 0.25), ink, 2.0)
		ci.draw_circle(c + Vector2(0, g * 0.5), 1.4, ink)
	ci.draw_string(font, Vector2(c.x + NOTICE_GLYPH * 0.5 + 6.0, box.get_center().y + px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)

func add_toast(id: StringName, count: int) -> void:
	for entry in toasts:
		if entry["id"] == id and entry["t"] < 0.6:
			entry["n"] += count
			entry["t"] = 0.0
			return
	toasts.append({"id": id, "n": count, "t": 0.0})

func tick(delta: float) -> void:
	for entry in toasts:
		entry["t"] += delta
	toasts = toasts.filter(func(entry: Dictionary) -> bool: return entry["t"] < 1.3)
	for entry in skill_toasts:
		_tick_skill(entry, delta)
	skill_toasts = skill_toasts.filter(func(entry: Dictionary) -> bool: return float(entry["t"]) < float(entry["life"]))
	for entry in notices:
		entry["t"] += delta
	notices = notices.filter(func(entry: Dictionary) -> bool: return entry["t"] < 3.2)
	for entry in bites:
		entry["t"] += delta
	bites = bites.filter(func(entry: Dictionary) -> bool: return entry["t"] < 0.5)
	for entry in player_floats:
		entry["t"] += delta
	player_floats = player_floats.filter(func(entry: Dictionary) -> bool: return entry["t"] < 0.95)
