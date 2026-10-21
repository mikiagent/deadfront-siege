class_name CombatFx
extends Control
## Damage numbers (spec 24 as the owner corrected it: "small and informative but make them bigger if
## you hit a crit or did a lot of damage"). A number pops in at the struck creature or the survivor,
## then expands outward while it fades out, floating up about one number-height. White is damage you
## deal, red damage you or your pet take, green a heal, gold your crit. A crit starts ~1.5x and a big
## hit (big_hit_frac of the target's max HP) ~1.25x. Quick hits on one target take the nearest spot
## beside it whose path stays clear, so they never print over each other. CreaturePlates owns one
## on its layer (58), above the world and the plates. Tuning: data/combat_fx.json.

const PATH := "res://data/combat_fx.json"
const DAMAGE: Array[StringName] = [&"hit", &"weak", &"strong", &"crit", &"dot"]
## The HUD's fixed top blocks (HuntHud.drawn_blocks) a number stays under.
const TOP_HUD: Array[String] = ["vitals", "statuses", "plate", "quest", "map_title", "map_text"]

## Live numbers, oldest first. Each: kind, tier, text, color, outline, outline_px, font, w and h
## (canvas px at 1.0x), age, life, lane (px beside the anchor), target (instance id), anchor
## (WeakRef), height (m above the anchor's origin), at (last anchor point), floor (px: the top HUD's
## bottom over the anchor at spawn). Tests read it.
var floats: Array[Dictionary] = []
var _cfg: Dictionary = {}
var _bold: FontVariation
## Motion constants from the JSON, kept typed: the lane search evaluates the motion often per hit.
var _pop_s := 0.08
var _pop_from := 0.6
var _expand := 1.4
var _rise := 1.0
var _fade := 2.0

## A number over `anchor` from anywhere (CreatureAttack, Player); nothing without a CombatFx in the tree.
static func pop_number(anchor: Node3D, amount: float, kind: StringName) -> void:
	var fx := anchor.get_tree().get_first_node_in_group(&"combat_fx") as CombatFx if anchor and anchor.is_inside_tree() else null
	if fx:
		fx.add_number(anchor, amount, kind)

func _ready() -> void:
	add_to_group(&"combat_fx")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("[combatfx] %s did not parse" % PATH)
	_cfg = parsed if parsed is Dictionary else {}
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = num("bold_embolden", 0.6)
	_pop_s = maxf(0.001, num("pop_s", 0.08))
	_pop_from = num("pop_from", 0.6)
	_expand = num("expand_to", 1.4)
	_rise = num("rise_lines", 1.0)
	_fade = num("fade_power", 2.0)

func num(key: String, fallback: float) -> float:
	return float(_cfg.get(key, fallback))

## A damage, heal, XP or dodge number over `anchor` (a Creature or the Player). A hit on the survivor
## or on a pet reads as damage taken.
func add_number(anchor: Node3D, amount: float, kind: StringName) -> void:
	if amount < 0.5 and kind in DAMAGE:
		return  # a bleed tick under 1 HP read "0"
	var taken := anchor is Player or (anchor is Creature and (anchor as Creature).is_pet)
	var colors: Dictionary = _cfg.get("colors", {})
	var text := "%d" % int(round(amount))
	var color := str(colors.get("taken" if taken else "dealt", "#ffffff"))
	var tier := "normal"
	match kind:
		&"heal":
			text = "+" + text
			color = str(colors.get("heal", "#72ff80"))
		&"xp":
			text = "+%s XP" % text
			color = str(colors.get("xp", "#ffd95a"))
			tier = "small"
		&"dodge":
			text = "DODGE"
			color = str(colors.get("miss", "#c4c4c4"))
			tier = "small"
		&"dot":
			tier = "small"
		&"crit":
			tier = "crit"
			color = color if taken else str(colors.get("crit", "#ffd21c"))
		_:
			var max_hp := _max_hp(anchor)
			if max_hp > 0.0 and amount >= num("big_hit_frac", 0.1) * max_hp:
				tier = "big"
	_push(anchor, kind, tier, text, Color.html(color))

## A status name (BLEEDING, GROGGY...) in its colour, laned with the numbers.
func add_word(anchor: Node3D, text: String, color: Color) -> void:
	_push(anchor, &"status", "small", text, color)

func _push(anchor: Node3D, kind: StringName, tier: String, text: String, color: Color) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var crit := tier == "crit"
	var px := maxf(float(UiTokens.TYPE_MIN), num("size_px", 20.0) * float((_cfg.get("tiers", {}) as Dictionary).get(tier, 1.0)) * _ui_scale())
	var font: Font = _bold if crit else ThemeDB.fallback_font
	var height := num("player_anchor_m", 2.0) if anchor is Player else \
		((anchor as Creature).def.height_meters * num("anchor_height_frac", 0.7) if anchor is Creature else 1.0)
	var f := {"kind": kind, "tier": tier, "text": text, "color": color, "font": font,
		"outline": Color.html(str(_cfg.get("crit_outline_color" if crit else "outline_color", "#120c08"))),
		"outline_px": num("crit_outline_px" if crit else "outline_px", 4.0) * _ui_scale(),
		"w": font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(px))).x, "h": px,
		"age": 0.0, "life": num("life_s", 0.75), "lane": 0.0, "target": anchor.get_instance_id(),
		"anchor": weakref(anchor), "height": height, "at": anchor.global_position + Vector3.UP * height}
	f["lane"] = _free_lane(f)
	f["floor"] = _hud_floor(f)
	floats.append(f)
	var mine := floats.filter(func (g: Dictionary) -> bool: return g["target"] == f["target"])
	if mine.size() > int(num("max_per_target", 8)):
		floats.erase(mine[0])
	queue_redraw()

func _process(delta: float) -> void:
	if floats.is_empty():
		return
	for i in range(floats.size() - 1, -1, -1):
		floats[i]["age"] = float(floats[i]["age"]) + delta
		if float(floats[i]["age"]) >= float(floats[i]["life"]):
			floats.remove_at(i)
	queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var peak := _expand
	for f in floats:
		var c := placement(f, cam)
		var age := float(f["age"])
		var a := alpha_at(f, age)
		if c == Vector2.INF or a <= 0.0:
			continue
		# Glyphs raster once at the widest swell and scale down, so the size moves smoothly instead of
		# stepping a whole font px at a time.
		var raster := int(round(float(f["h"]) * peak))
		var s := scale_at(f, age) / peak
		var font: Font = f["font"]
		var text := str(f["text"])
		draw_set_transform(c, 0.0, Vector2(s, s))
		var o := UiTokens.centered_origin(font, text, raster, Vector2.ZERO)
		var edge: Color = f["outline"]
		var col: Color = f["color"]
		draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, raster, int(round(float(f["outline_px"]) * peak)), Color(edge, edge.a * a))
		draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, raster, Color(col, col.a * a))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Canvas centre of a number this frame, or Vector2.INF when its anchor is behind the camera. The
## anchor point is clamped for the number's whole path (its widest swell, its full rise), so it never
## clips at a screen edge and the clamp never shifts it mid-flight.
func placement(f: Dictionary, cam: Camera3D) -> Vector2:
	var anchor := (f["anchor"] as WeakRef).get_ref() as Node3D
	if anchor and anchor.is_inside_tree():
		f["at"] = anchor.get_global_transform_interpolated().origin + Vector3.UP * float(f["height"])
	var at: Vector3 = f["at"]
	if cam.is_position_behind(at):
		return Vector2.INF
	var view := get_viewport_rect().size
	var m := num("edge_margin_px", 8.0)
	var half := Vector2(float(f["w"]), float(f["h"])) * _expand * 0.5 + Vector2(m, m)
	var top := float(f.get("floor", 0.0)) + half.y + lift_at(f, float(f["life"]))
	var p := cam.unproject_position(at) + Vector2(float(f["lane"]), 0.0)
	p.x = clampf(p.x, half.x, maxf(half.x, view.x - half.x))
	p.y = clampf(p.y, top, maxf(top, view.y - half.y))
	return p - Vector2(0.0, lift_at(f, float(f["age"])))

## The number's box on the canvas this frame (tests and the lab measure overlap and edges with it).
func screen_rect(f: Dictionary, cam: Camera3D) -> Rect2:
	var c := placement(f, cam)
	if c == Vector2.INF:
		return Rect2()
	var size := Vector2(float(f["w"]), float(f["h"])) * scale_at(f, float(f["age"]))
	return Rect2(c - size * 0.5, size)

## Size at `age` over the number's 1.0x: the pop (pop_from -> 1, eased out over pop_s), then a smooth
## swell to expand_to by the end of its life.
func scale_at(f: Dictionary, age: float) -> float:
	var pop := _pop(age)
	return lerpf(_pop_from, 1.0, pop) * lerpf(1.0, _expand, smoothstep(0.0, 1.0, _fade_k(f, age)))

## Opacity at `age`: in over the pop, then 1 - k^fade_power to 0 at the end of its life (slow at
## first, so the value reads before it dissipates).
func alpha_at(f: Dictionary, age: float) -> float:
	return _pop(age) * (1.0 - pow(_fade_k(f, age), _fade))

## Pixels above the anchor at `age`: rise_lines number-heights over the whole life, eased out.
func lift_at(f: Dictionary, age: float) -> float:
	var u := clampf(age / maxf(0.001, float(f["life"])), 0.0, 1.0)
	return _rise * float(f["h"]) * (1.0 - (1.0 - u) * (1.0 - u))

func _pop(age: float) -> float:
	var u := clampf(age / _pop_s, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)

func _fade_k(f: Dictionary, age: float) -> float:
	return clampf((age - _pop_s) / maxf(0.001, float(f["life"]) - _pop_s), 0.0, 1.0)

## The spot beside the anchor (px, nearest first) where the new number `f` stays clear of this
## target's readable numbers for as long as both are readable: each older number it would meet
## blocks an interval around its own lane, and `f` takes the nearest free spot.
func _free_lane(f: Dictionary) -> float:
	var blocked: Array[Vector2] = []
	for g in floats:
		if g["target"] == f["target"]:
			var r := _reach(g, f)
			if r > 0.0:
				blocked.append(Vector2(float(g["lane"]) - r, float(g["lane"]) + r))
	var spots: Array[float] = [0.0]
	for b in blocked:
		spots.append(b.x)
		spots.append(b.y)
	spots.sort_custom(func (a: float, b: float) -> bool: return absf(a) < absf(b))
	for x in spots:
		if blocked.all(func (b: Vector2) -> bool: return x <= b.x + 0.01 or x >= b.y - 0.01):
			return x
	return spots[-1]  # not reached: the outermost edge is always free

## How far apart (px, centre to centre) `f` must sit beside an older `g` (same anchor) so the two
## stay pad_px apart on every frame (1/60 s) while both are readable; 0 when their heights never meet.
func _reach(g: Dictionary, f: Dictionary) -> float:
	var pad := num("pad_px", 3.0) * _ui_scale()
	var vis := num("visible_alpha", 0.3)
	var r := 0.0
	var s := 0.0
	var left := minf(float(g["life"]) - float(g["age"]), float(f["life"]))
	while s < left:
		var ga := float(g["age"]) + s
		var ag := alpha_at(g, ga)
		if ag < vis and ga > _pop_s:
			break  # g only fades from here on
		if ag >= vis and alpha_at(f, s) >= vis:
			var sg := scale_at(g, ga)
			var sf := scale_at(f, s)
			if absf(lift_at(g, ga) - lift_at(f, s)) < (float(g["h"]) * sg + float(f["h"]) * sf) * 0.5 + pad:
				r = maxf(r, (float(g["w"]) * sg + float(f["w"]) * sf) * 0.5 + pad)
		s += 1.0 / 60.0
	return r

## Bottom of the HUD's fixed top blocks over the anchor's column at spawn (0 without a HUD): the number's
## whole path stays under it, so a hit high on a big creature on a phone never covers the target's HP.
## Taken once per number so a status chip appearing later cannot make it jump.
func _hud_floor(f: Dictionary) -> float:
	var hud := get_tree().get_first_node_in_group(&"hud")
	var cam := get_viewport().get_camera_3d()
	var blocks: Variant = hud.get("drawn_blocks") if hud else null
	if not blocks is Dictionary or cam == null or cam.is_position_behind(f["at"]):
		return 0.0
	var x := cam.unproject_position(f["at"]).x
	var half := float(f["w"]) * _expand * 0.5
	var y := 0.0
	for k in TOP_HUD:
		var r: Rect2 = (blocks as Dictionary).get(k, Rect2())
		if r.has_area() and x + half > r.position.x and x - half < r.end.x:
			y = maxf(y, r.end.y)
	return y

func _max_hp(anchor: Node3D) -> float:
	if anchor is Player:
		return (anchor as Player).vitals.max_health
	if anchor is Creature:
		return (anchor as Creature).health.max_hp
	return 0.0

func _ui_scale() -> float:
	return num("compact_scale", 0.8) if UiTokens.is_compact(get_viewport_rect().size) else 1.0
