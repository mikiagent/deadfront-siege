class_name CreatureColoration
extends RefCounted
## Per-individual natural colour variant, stored in CreatureGenetics beside the IVs so it follows the
## same tame and save path. A hue shift in degrees and a saturation / value scale around 1.0, all
## rolled at spawn from the species' `coloration` block in data/creatures/<species>.json. An optional
## weighted morph ("dark", "pale") may replace the plain roll with its own narrower ranges.
##
## Ranges are deliberately small: a wild animal may look sandy or olive, a little darker or paler,
## never neon. ASSUMPTION: the defaults below (hue +-12 deg, sat +-15 %, value +-10 %) are the
## natural-looking range when a species declares none.
##
## Rare morphs: about 1 in 50 wild animals (data-driven `rare_chance`, ASSUMPTION 0.02) rolls a
## wider range instead: a distinct but still believable morph (melanistic, leucistic, a stronger
## hue) with a bolder pattern. It is stored in the same profile, so taming and saving keep it.

const DEFAULT_RANGE := {"hue_deg": 12.0, "sat": 0.15, "val": 0.10}
const DEFAULT_RARE_CHANCE := 0.02
## A rare roll may leave the normal range by up to this much (still natural, never neon).
const RARE_SCALE := 2.4
## Rare hue may leave the normal +-HUE_LIMIT by this factor (a hue shift is far more visible than
## the saturation/value scales, so it gets a smaller allowance).
const RARE_HUE_SCALE := 1.5
## The pattern kinds the shader knows. Anything else saves as a plain hide.
const PATTERNS: Array[String] = ["stripes", "spots", "saddle", "countershade"]
## Hard bounds, also what a hand-edited save is clamped to: nothing here can leave "natural".
const HUE_LIMIT := 40.0
const SAT_LIMIT := 0.45
const VAL_LIMIT := 0.45

var hue_deg: float = 0.0
var sat: float = 1.0
var val: float = 1.0
var morph: StringName = &""
## True for the 1-in-50 wide morph (labelled in the lab; it only means "outside the normal range").
var rare: bool = false
## Pattern layer: "", "stripes", "spots", "saddle", "countershade". Drawn from the rest-pose vertex
## positions (never the UVs), tone taken from the body colour (darker or lighter, no foreign hue).
var pattern: StringName = &""
var pattern_scale: float = 1.0
var pattern_strength: float = 0.0
## -1 = lighter tone, +1 = darker tone.
var pattern_tone: float = 1.0
var pattern_seed: float = 0.0

## Roll from a species `coloration` block. `rng` lets callers share the spawn RNG (a seeded server
## roll stays replayable); a null rng randomises.
static func roll(block: Dictionary = {}, rng: RandomNumberGenerator = null) -> CreatureColoration:
	var roller := rng
	if roller == null:
		roller = RandomNumberGenerator.new()
		roller.randomize()
	var out := CreatureColoration.new()
	var ranges := _ranges(block, roller)
	# Rare morph: a wider roll from the rare range, about 1 in 50 animals.
	var rare_chance := clampf(_finite(block.get("rare_chance", DEFAULT_RARE_CHANCE), DEFAULT_RARE_CHANCE), 0.0, 0.5)
	var rare := roller.randf() < rare_chance
	if rare:
		var rare_range := _rare_range(block)
		out.rare = true
		out.hue_deg = clampf(roller.randf_range(rare_range["hue"].x, rare_range["hue"].y), -HUE_LIMIT * RARE_HUE_SCALE, HUE_LIMIT * RARE_HUE_SCALE)
		out.sat = clampf(roller.randf_range(rare_range["sat"].x, rare_range["sat"].y), 1.0 - SAT_LIMIT * RARE_SCALE, 1.0 + SAT_LIMIT * RARE_SCALE)
		out.val = clampf(roller.randf_range(rare_range["val"].x, rare_range["val"].y), 1.0 - VAL_LIMIT * RARE_SCALE, 1.0 + VAL_LIMIT * RARE_SCALE)
		out.morph = _rare_morph_for(out)
	else:
		out.hue_deg = clampf(roller.randf_range(ranges["hue"].x, ranges["hue"].y), -HUE_LIMIT, HUE_LIMIT)
		out.sat = clampf(roller.randf_range(ranges["sat"].x, ranges["sat"].y), 1.0 - SAT_LIMIT, 1.0 + SAT_LIMIT)
		out.val = clampf(roller.randf_range(ranges["val"].x, ranges["val"].y), 1.0 - VAL_LIMIT, 1.0 + VAL_LIMIT)
		out.morph = StringName(str(ranges["morph"]))
	_roll_pattern(out, block, roller)
	return out

## Pattern layer: each species lists the kinds it may wear and their weights ("coloration.patterns",
## ASSUMPTION defaults: countershading plus a plain hide). One kind per animal, so a hide is either
## striped, spotted, saddled, countershaded or plain, never a pile of them. A rare morph is bolder.
static func _roll_pattern(out: CreatureColoration, block: Dictionary, roller: RandomNumberGenerator) -> void:
	var kinds := _pattern_kinds(block)
	if kinds.is_empty():
		return
	var total := 0.0
	for k in kinds:
		total += float(k["weight"])
	if total <= 0.0:
		return
	var pick := roller.randf() * total
	var chosen := {}
	for k in kinds:
		pick -= float(k["weight"])
		if pick < 0.0:
			chosen = k
			break
	if chosen.is_empty():
		return
	var id := str(chosen["id"])
	if id == "":
		return
	out.pattern = StringName(id)
	out.pattern_scale = clampf(_finite(chosen.get("scale", 1.0), 1.0) * roller.randf_range(0.85, 1.15), 0.3, 4.0)
	out.pattern_strength = clampf(_finite(chosen.get("strength", 0.30), 0.30) * roller.randf_range(0.8, 1.15), 0.05, 0.85)
	out.pattern_tone = 1.0 if roller.randf() < 0.7 else -1.0
	out.pattern_seed = roller.randf_range(0.0, 1000.0)
	if out.rare:
		out.pattern_scale *= 0.8
		out.pattern_strength = clampf(out.pattern_strength * 1.35, 0.05, 0.9)

## Per-species pattern list, weighted, with a "" (plain hide) entry. Missing JSON: countershading
## (weight 2) and plain (weight 3) — ASSUMPTION: every species countershades a little.
static func _pattern_kinds(block: Dictionary) -> Array:
	var raw: Variant = block.get("patterns", null)
	var out: Array = []
	if raw is Array:
		for row in raw:
			if not row is Dictionary:
				continue
			var id := str((row as Dictionary).get("id", ""))
			if id != "" and id not in ["stripes", "spots", "saddle", "countershade"]:
				continue
			out.append({"id": id, "weight": maxf(0.0, _finite((row as Dictionary).get("weight", 1.0), 1.0)),
				"scale": _finite((row as Dictionary).get("scale", 1.0), 1.0),
				"strength": _finite((row as Dictionary).get("strength", 0.45), 0.45)})
	if out.is_empty():
		out = [{"id": "countershade", "weight": 2.0, "scale": 1.0, "strength": 0.5},
			{"id": "", "weight": 3.0, "scale": 1.0, "strength": 0.0}]
	return out

## The wide ranges a rare morph rolls from: the species' "rare" block when it has one, else the
## normal range scaled by RARE_SCALE (hue wider, saturation and value further from 1.0).
static func _rare_range(block: Dictionary) -> Dictionary:
	var raw: Variant = block.get("rare", null)
	if raw is Dictionary:
		return {
			"hue": _range((raw as Dictionary).get("hue_deg", DEFAULT_RANGE["hue_deg"]), float(DEFAULT_RANGE["hue_deg"])),
			"sat": _scale_range((raw as Dictionary).get("sat", DEFAULT_RANGE["sat"]), float(DEFAULT_RANGE["sat"])),
			"val": _scale_range((raw as Dictionary).get("val", DEFAULT_RANGE["val"]), float(DEFAULT_RANGE["val"])),
		}
	var base := _ranges(block, null)
	return {
		"hue": base["hue"] * RARE_SCALE,
		"sat": Vector2(1.0 - (1.0 - base["sat"].x) * RARE_SCALE, 1.0 + (base["sat"].y - 1.0) * RARE_SCALE),
		"val": Vector2(1.0 - (1.0 - base["val"].x) * RARE_SCALE, 1.0 + (base["val"].y - 1.0) * RARE_SCALE),
	}

## Name for a rare morph, taken from the colour that was actually rolled so the label never lies
## (a rare that renders olive must not be called rufous). The species' "rare_morphs" list is only a
## vocabulary hint; the roll decides.
static func _rare_morph_for(p: CreatureColoration) -> StringName:
	if p.sat >= 1.22:
		return &"vivid"
	if p.val <= 0.86:
		return &"dark"
	if p.val >= 1.14:
		return &"pale"
	if p.hue_deg >= 16.0:
		return &"golden"
	if p.hue_deg <= -16.0:
		return &"rufous"
	return &"rare"

## Deterministic profile for an animal that has none (a save written before colour profiles): the
## same pet id always derives the same colours, so loading twice never repaints it.
static func derive(pet_id: String, block: Dictionary = {}) -> CreatureColoration:
	return roll(block, seeded_rng(pet_id))

## RNG whose stream depends only on `key`: same key, same roll, on every load and every run.
static func seeded_rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = fnv1a(key)
	# Godot's PCG is weak on the first draws right after seeding (nearby keys pull the same first
	# value, which put 29 of 30 seeded morph picks on "dark"); warm it up before anything reads it.
	for _i in 4:
		rng.randf()
	return rng

## 64-bit FNV-1a. Stable across runs and Godot versions (String.hash() is not promised to be), so a
## derived profile is identical every load.
static func fnv1a(text: String) -> int:
	var h: int = -3750763034362895579 # 0xcbf29ce484222325 as a signed 64-bit int
	for i in text.length():
		h = (h ^ int(text.unicode_at(i))) * 1099511628211
	return h

## Compared with a tolerance: a JSON round trip and the float32 the shader reads back differ in
## the last bits, which must not count as "another colour".
func equals(other: CreatureColoration) -> bool:
	return other != null and absf(other.hue_deg - hue_deg) < 0.0001 \
		and absf(other.sat - sat) < 0.0001 and absf(other.val - val) < 0.0001 \
		and other.morph == morph and other.rare == rare and other.pattern == pattern \
		and absf(other.pattern_scale - pattern_scale) < 0.0001 \
		and absf(other.pattern_strength - pattern_strength) < 0.0001 \
		and absf(other.pattern_tone - pattern_tone) < 0.0001 \
		and absf(other.pattern_seed - pattern_seed) < 0.001

## Identity for tests and lab labels.
func label() -> String:
	var parts := "%+.1f°, x%.2f, x%.2f" % [hue_deg, sat, val]
	if rare:
		parts += " RARE[%s]" % str(morph)
	elif morph != &"":
		parts += " [%s]" % str(morph)
	if pattern != &"":
		parts += " %s x%.2f/%.2f%s" % [str(pattern), pattern_scale, pattern_strength, " dark" if pattern_tone > 0.0 else " light"]
	return parts

## Rounded to 4 decimals: the JSON a save writes and reads back must compare equal to the live
## profile (float64 text round trips through JSON with last-bit noise otherwise), and 0.0001 of a
## hue turn is far below what an eye can see.
func to_dict() -> Dictionary:
	return {
		"hue_deg": snappedf(hue_deg, 0.0001), "sat": snappedf(sat, 0.0001), "val": snappedf(val, 0.0001),
		"morph": str(morph), "rare": rare,
		"pattern": str(pattern), "pattern_scale": snappedf(pattern_scale, 0.0001),
		"pattern_strength": snappedf(pattern_strength, 0.0001),
		"pattern_tone": snappedf(pattern_tone, 0.0001), "pattern_seed": snappedf(pattern_seed, 0.001),
	}

## Untrusted input: anything that is not a finite number falls back to neutral, then is clamped.
static func from_dict(data: Variant) -> CreatureColoration:
	var out := CreatureColoration.new()
	if not data is Dictionary:
		return out
	var d: Dictionary = data
	out.rare = d.get("rare", false) == true
	# A rare morph legitimately sits outside the normal range (roll() lets it go to RARE_LIMIT), so
	# the clamp has to follow the same bounds or a saved rare would come back a different colour.
	var span := RARE_SCALE if out.rare else 1.0
	var hue_span := RARE_HUE_SCALE if out.rare else 1.0
	out.hue_deg = clampf(_finite(d.get("hue_deg", 0.0), 0.0), -HUE_LIMIT * hue_span, HUE_LIMIT * hue_span)
	out.sat = clampf(_finite(d.get("sat", 1.0), 1.0), 1.0 - SAT_LIMIT * span, 1.0 + SAT_LIMIT * span)
	out.val = clampf(_finite(d.get("val", 1.0), 1.0), 1.0 - VAL_LIMIT * span, 1.0 + VAL_LIMIT * span)
	var m: Variant = d.get("morph", "")
	out.morph = StringName(str(m).substr(0, 24)) if m is String else &""
	var pat: Variant = d.get("pattern", "")
	var pid := str(pat).substr(0, 16) if pat is String else ""
	out.pattern = StringName(pid if pid in PATTERNS else "")
	out.pattern_scale = clampf(_finite(d.get("pattern_scale", 1.0), 1.0), 0.3, 4.0)
	out.pattern_strength = clampf(_finite(d.get("pattern_strength", 0.0), 0.0), 0.0, 0.9)
	out.pattern_tone = 1.0 if _finite(d.get("pattern_tone", 1.0), 1.0) >= 0.0 else -1.0
	out.pattern_seed = fposmod(_finite(d.get("pattern_seed", 0.0), 0.0), 1000.0)
	return out

static func _finite(v: Variant, fallback: float) -> float:
	if not (v is int or v is float):
		return fallback
	var f := float(v)
	return f if is_finite(f) else fallback

## Hue, saturation and value ranges for this roll. A weighted morph, when the species lists one,
## replaces the base ranges with its own.
static func _ranges(block: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := {
		"hue": _range(block.get("hue_deg"), float(DEFAULT_RANGE["hue_deg"])),
		"sat": _scale_range(block.get("sat"), float(DEFAULT_RANGE["sat"])),
		"val": _scale_range(block.get("val"), float(DEFAULT_RANGE["val"])),
		"morph": "",
	}
	var morphs: Variant = block.get("morphs", [])
	# Without an RNG (only the rare-range math asks for that) no morph is picked.
	if rng == null or not morphs is Array or (morphs as Array).is_empty():
		return out
	var total := 0.0
	for m in morphs:
		if m is Dictionary:
			total += maxf(0.0, _finite((m as Dictionary).get("weight", 1.0), 1.0))
	if total <= 0.0:
		return out
	var pick := rng.randf() * total
	for m in morphs:
		if not m is Dictionary:
			continue
		var md: Dictionary = m
		var w := maxf(0.0, _finite(md.get("weight", 1.0), 1.0))
		if pick < w or md == morphs[morphs.size() - 1]:
			# A morph narrows the species range but never leaves it: every normal roll stays inside
			# the range the species declares, only a rare morph goes wide.
			out["hue"] = _clamp_range(_range(md.get("hue_deg"), float(DEFAULT_RANGE["hue_deg"])), _range(block.get("hue_deg"), float(DEFAULT_RANGE["hue_deg"])))
			out["sat"] = _clamp_range(_scale_range(md.get("sat"), float(DEFAULT_RANGE["sat"])), _scale_range(block.get("sat"), float(DEFAULT_RANGE["sat"])))
			out["val"] = _clamp_range(_scale_range(md.get("val"), float(DEFAULT_RANGE["val"])), _scale_range(block.get("val"), float(DEFAULT_RANGE["val"])))
			out["morph"] = str(md.get("id", ""))
			return out
		pick -= w
	return out

## Intersects a morph range with the species range, so a morph is a narrowing, never a widening.
static func _clamp_range(morph: Vector2, base: Vector2) -> Vector2:
	var lo := maxf(morph.x, base.x)
	var hi := minf(morph.y, base.y)
	if lo > hi:
		return base
	return Vector2(lo, hi)

## Scalar = +-degrees ("hue_deg": 14 -> -14..14); a two-number array = explicit [min, max] degrees.
static func _range(raw: Variant, default_abs: float) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		var a := _finite(raw[0], -default_abs)
		var b := _finite(raw[1], default_abs)
		return Vector2(minf(a, b), maxf(a, b))
	var v := absf(_finite(raw, default_abs))
	return Vector2(-v, v)

## Scalar = +-value around 1.0 ("sat": 0.18 -> 0.82..1.18); a two-number array = signed offsets
## from 1.0 ("val": [-0.22, -0.10] -> 0.78..0.90, a darker morph), so every species and morph uses
## the same units as the scalar and nothing has to know whether the author meant a scale or a delta.
static func _scale_range(raw: Variant, default_abs: float) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		var a := 1.0 + _finite(raw[0], -default_abs)
		var b := 1.0 + _finite(raw[1], default_abs)
		return Vector2(minf(a, b), maxf(a, b))
	var v := absf(_finite(raw, default_abs))
	return Vector2(1.0 - v, 1.0 + v)

## ALPHAS: darker and richer natural colours (val x val_mult, sat x sat_mult, a bolder pattern), never a
## foreign hue. Clamped to the same limits from_dict uses, so a saved alpha comes back identical.
func alpha_tone(val_mult: float, sat_mult: float, pattern_mult: float) -> void:
	var span := RARE_SCALE if rare else 1.0
	val = clampf(val * val_mult, 1.0 - VAL_LIMIT * span, 1.0 + VAL_LIMIT * span)
	sat = clampf(sat * sat_mult, 1.0 - SAT_LIMIT * span, 1.0 + SAT_LIMIT * span)
	if pattern != &"":
		pattern_strength = clampf(pattern_strength * pattern_mult, 0.0, 0.9)

## GENETICS: a child's colours between its two parents' (hue, saturation, value and pattern strength
## each a random blend), then moved by at most mutation.hue_deg / sat / val. The pattern kind comes
## from one parent. A child is never rare: the wide morph is a wild roll only (ASSUMPTION). Clamped to
## the normal natural limits.
static func blend(a: CreatureColoration, b: CreatureColoration, mutation: Dictionary, r: RandomNumberGenerator) -> CreatureColoration:
	var out := CreatureColoration.new()
	var mh := absf(_finite(mutation.get("hue_deg", 2.0), 2.0))
	var ms := absf(_finite(mutation.get("sat", 0.03), 0.03))
	var mv := absf(_finite(mutation.get("val", 0.03), 0.03))
	out.hue_deg = clampf(lerpf(a.hue_deg, b.hue_deg, r.randf()) + r.randf_range(-mh, mh), -HUE_LIMIT, HUE_LIMIT)
	out.sat = clampf(lerpf(a.sat, b.sat, r.randf()) + r.randf_range(-ms, ms), 1.0 - SAT_LIMIT, 1.0 + SAT_LIMIT)
	out.val = clampf(lerpf(a.val, b.val, r.randf()) + r.randf_range(-mv, mv), 1.0 - VAL_LIMIT, 1.0 + VAL_LIMIT)
	var from := a if r.randf() < 0.5 else b
	out.pattern = from.pattern
	if out.pattern != &"":
		var other := b if from == a else a
		var same := other.pattern == from.pattern
		out.pattern_scale = lerpf(from.pattern_scale, other.pattern_scale, r.randf()) if same else from.pattern_scale
		out.pattern_strength = clampf(lerpf(from.pattern_strength, other.pattern_strength, r.randf()) if same else from.pattern_strength, 0.0, 0.9)
		out.pattern_tone = from.pattern_tone
		out.pattern_seed = from.pattern_seed
	return out

static func neutral() -> CreatureColoration:
	return CreatureColoration.new()

## The same HSV shift the shader does, for the placeholder path (no texture to sample).
func shift_color(c: Color) -> Color:
	return apply_hsv(c, hue_deg, sat, val)

static func apply_hsv(c: Color, hue: float, saturation: float, value: float) -> Color:
	# Godot 4 Color exposes h / s / v (0..1), not the 3.x `hsv` Vector3.
	return Color.from_hsv(
		fposmod(c.h + hue / 360.0, 1.0),
		clampf(c.s * saturation, 0.0, 1.0),
		clampf(c.v * value, 0.0, 1.0),
		c.a)
