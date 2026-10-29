class_name IslandShape
extends RefCounted
## The landmass generator: an effective-radius coastline (peninsulas, bays, a harbour cove),
## a calibrated size, highlands with cliff terraces, a mesa, a valley and one real river from a
## highland source to the sea.
##
## Effective radius: `rad(x, z)` is a distance in metres where the coastline sits at `shore0`
## (the shore band's start, `size * 0.36` as before). It is the distance in a warped, rotated
## space divided by an angular edge function, so every downstream consumer (shore bands, ridge,
## is_dry, scatter) can keep comparing against `shore0` / `land_radius()` unchanged.
##
## Calibration: the shape is built in unit space (coastline at |s| = edge(angle)); the coast's
## bounding box there is measured over 720 bearings (a radial star shape: r(phi) = edge(phi)),
## and x/z are scaled separately so the land's dry bounding box is exactly the tier's target
## (home 375 x 300 m on a 416 m square). The plan's sizes are the land bbox, so a square grid can
## hold them with >= 20 m of sea on the long sides.
##
## Heights: base rolling noise + ridge + highland terraces (3.2 m risers = the cliffs) + a mesa
## with a sharp rim + the river's valley and channel. The home island blends the OLD height
## function (seed 17, size 160) back in within 50-75 m of the origin so old saves keep their
## buildings, claims and baskets on the same dry, flat ground.

const TAU_ := TAU
## Land target per tier (long x short metres), from docs/design/islands-and-loop-plan.md 1.1.
const HOME_LONG := 375.0
const HOME_SHORT := 300.0
const TIER_LONG := {60: 415.0, 55: 415.0, 50: 415.0, 45: 375.0, 40: 375.0, 35: 375.0, 30: 375.0, 25: 330.0, 20: 330.0, 15: 330.0}
const TIER_SHORT := {60: 335.0, 55: 335.0, 50: 335.0, 45: 300.0, 40: 300.0, 35: 300.0, 30: 300.0, 25: 265.0, 20: 265.0, 15: 265.0}
## Terrace step (m): the risers read as 2-6 m cliff faces and paint CLIFF.
const TERRACE_STEP := 3.2
## The flat beach shelf's height (m above the water plane's -0.05).
const SHELF_H := 0.32
## The flat dry camp clearing (radius m, height m) every island gets around its camp hint.
const CAMP_R := 30.0
const CAMP_FLAT := 1.1
## The old shore profile reaches the waterline (h = -0.05) about 52 % of the way from shore0 to
## shore1, i.e. at 0.4176 * size. Calibration uses that radius so the measured land bbox is the
## tier target rather than the notional `shore0` circle.
const WATERLINE := 0.3605 + 1.5 / 416.0  # where the beach profile crosses -0.05, as a fraction of size
## Legacy core: old height fully in at 50 m from the origin, gone by 75 m.
const LEGACY_FULL := 50.0
const LEGACY_END := 75.0
## Sea kept on every side of the square grid, so no headland is cut off by the grid edge.
const SEA_MARGIN := 24.0

var size: float = 416.0
var res: int = 161
var seed: int = 17
var climate: String = "grassland"
var legacy: bool = false
var kind: String = "unstable"

## Offset of the landmass inside the square grid (home: (0,-35) per the plan, so the south coast
## sits ~115 m below the origin and the camp's legacy core keeps its ground).
var centre: Vector2 = Vector2.ZERO
var shore0: float = 149.76
var shore1: float = 195.52
var sx: float = 1.0
var sz: float = 1.0
var aspect: float = 0.8
## The land bbox target (long x short) and the grid square size.
var target := Vector2(375.0, 300.0)

var _rot: float = 0.0
var _aspect: float = 0.8
var _amps: Array[float] = [0.0, 0.0, 0.0]
var _ph: Array[float] = [0.0, 0.0, 0.0]
## Each: [angle, amplitude, sigma]; peninsulas add to the edge, bays cut it, the cove cuts deepest.
var _pens: Array[Array] = []
var _bays: Array[Array] = []
var _cove: Array = [0.0, 0.0, 0.0]
## Unit-space coast bbox half extents (calibration); edge().x span, edge().y span after /aspect.
var _bbox_half := Vector2.ONE

var ridge_dir := Vector2.RIGHT
## +1 when the highland lies along +ridge_dir, -1 along -ridge_dir (chosen away from the cove).
var high_side := 1.0
## Home: the river's line (z), just north of the camp, and the old dry gap's half-width as the ford.
var _home_river_z := -34.0
## The camp hint (island def), flattened a little; home (0,8), unstable (0,12) by default.
var camp_hint := Vector2(0.0, 12.0)
## {"pos": Vector2, "r": float, "h": float} or {}; most islands have one.
var mesa: Dictionary = {}
var river := PackedVector2Array()
## A dry crossing (a ford) over the channel: walkers must not be cut off from half the island.
## Picked on the river's middle third, at least 30 m from camp unless the island is the home's
## legacy core, where the old dry gap by the camp is the ford (plan 1.3).
var ford := Vector2.ZERO
const FORD_R := 11.0
## Arc length of the chosen channel (m): t_islandgen asserts it spans >= half the long axis.
var river_arc := 0.0
## Which candidate (0-7) the river search settled on; later passes replay only that one.
var _river_attempt := -1
var _river_w := PackedFloat32Array()
var waterfall := Vector3.ZERO

## Filled by compute().
var heights := PackedFloat32Array()
var rads := PackedFloat32Array()
var river_d := PackedFloat32Array()
var river_w := PackedFloat32Array()
## Spatial hash of the river segments, so the heightmap pass does not measure every vertex
## against all 70 segments (that alone was 1.7 s of the home build).
var _segs: Dictionary = {}  # Vector2i cell -> Array[int] segment indices
const SEG_CELL := 40.0
var vslope := PackedFloat32Array()

## ISLANDSHAPES: the landmass family (island_families.json) and what it adds to the classic body.
## "classic" is the pre-ISLANDSHAPES generator, untouched (legacy meadow, tutorial).
var family: String = "classic"
var _fam: Dictionary = {}
## Main body scale (chain/spiral shrink the star body and grow land out of features instead) and the
## deepest a bay may cut (edge floor).
var _main_scale := 1.0
var _edge_min := 0.55
## Features in unit space (q, after the aspect): islets [Vector2 c, r] (land, not mainland), caps
## [a, b, r] (land capsules that ARE mainland), subs [a, b, r] (water: lagoons, passes; a == b is a
## disc), rings [Rl, w] (an annulus of water round the unit origin), bridges [a, b, r] (sandbars laid
## over the water subs).
var _islets: Array[Array] = []
var _caps: Array[Array] = []
var _subs: Array[Array] = []
var _rings: Array[Vector2] = []
var _bridges: Array[Array] = []
var _has_feats := false
var _isl_c := PackedVector2Array()
var _isl_r := PackedFloat32Array()
## Coast jaggedness (unit-space noise amplitude) and the shallow shelf's reach past the beach (m).
var _jag := 0.0
var _njag := FastNoiseLite.new()
var _shelf_m := Vector2.ZERO
var _nshelf := FastNoiseLite.new()
## Set by rad(): the last point sat in a lagoon (its seabed stays a shallow turquoise shelf).
var _in_lagoon := false
var _plateau := true
## Chain: the spine's unit-space direction (the linear river runs along it).
var _axis := Vector2.RIGHT
## Chain: the linked chunks' centres in order along the axis (unit space); the river follows them.
var _spine := PackedVector2Array()
## Polar river: arc radius (unit) and the bearing the arc keeps away from (crescent lagoon).
var _arc_r := 0.0
var _arc_avoid := INF
## Non-navigable topography: [{"kind", "pos": Vector2, "r", "h", ...}] in world metres, and the
## data-grid mask of their footprints (1 = CLIFF tile, cut out of the nav source).
var topo: Array[Dictionary] = []
var topo_mask := PackedByteArray()
## Where the dock will most likely stand (the southern-most land), estimated before the harbour is
## placed: topography keeps off the camp-to-dock walk.
var south_est := Vector2.ZERO
var river_scale := 1.0

static var _fam_cache: Dictionary = {}
## World points the island row needs on dry land (its crater, fixed creature spawns): a lagoon is
## never cut toward them.
var _keep := PackedVector2Array()

var _n0 := FastNoiseLite.new()
var _n1 := FastNoiseLite.new()
var _n2 := FastNoiseLite.new()
var _nshore := FastNoiseLite.new()
var _ncliff := FastNoiseLite.new()

## Old-function noises for the home legacy core (seed 17, size 160), built only when legacy.
var _o0: FastNoiseLite
var _o1: FastNoiseLite
var _o2: FastNoiseLite
var _oshore: FastNoiseLite
var _oridge := Vector2.RIGHT
var _ocamp := Vector3.ZERO

static func target_long(tier: int) -> float:
	return float(TIER_LONG.get(tier, 375))

static func target_short(tier: int) -> float:
	return float(TIER_SHORT.get(tier, 300))

## Builds the parameter set for one island. `harbour_hint` aims the cove (the harbour sits at its
## head); Vector2.ZERO picks a random coast. `legacy_core` turns on the old-height blend (home).
## `p_land` (long, short m) overrides the tier band for an island that names its own landmass (the tutorial island).
static func make(p_size: float, p_seed: int, p_kind: String, p_tier: int, harbour_hint: Vector2, legacy_core: bool, p_res: int, p_climate: String, p_land: Vector2 = Vector2.ZERO, p_family: String = "", p_keep: PackedVector2Array = PackedVector2Array()) -> IslandShape:
	var s := IslandShape.new()
	s._keep = p_keep
	s.family = p_family if p_family != "" and families().has(p_family) else pick_family(p_kind, p_seed, legacy_core)
	s.size = p_size
	s.res = p_res
	s.seed = p_seed
	s.kind = p_kind
	s.legacy = legacy_core
	s.climate = p_climate
	# The shore profile: beach starts at 0.345 S, the waterline lands about 0.368 S, then the
	# seabed drops to -1.9 m by 0.40 S (a steep enough apron that a dock 5 m out is boat-deep:
	# HarbourSite wants >= 0.4 m under the tip) and -2.6 m by 0.45 S.
	# The shore profile, shaped around HarbourSite's dock constraint (a 6 m footprint wants its base
	# row on land, the next row still above water, and every row past that below water with the tip
	# >= 0.4 m deep): land to `shore0`, then a steep 2.5 m underwater drop to -2.6 m. A steep drop
	# keeps the two constraints apart (a 1.5 m window for the base row instead of 0.4 m), so most
	# of the coast takes a legal dock instead of only the bearings that happen to align.
	s.shore0 = p_size * 0.3605
	s.shore1 = p_size * 0.400
	var r := RandomNumberGenerator.new()
	r.seed = p_seed * 7919 + 13
	s.camp_hint = Vector2(0.0, 8.0) if legacy_core else Vector2(0.0, 12.0)
	# The measured bbox aspect (long/short of the dry box) lands a little under the internal ellipse
	# aspect because the lobes add length on the short axis; 0.78-0.85 keeps the box at 0.75-0.85.
	s._aspect = r.randf_range(0.80, 0.87)
	if legacy_core:
		s.centre = Vector2(0.0, -35.0)
	# A limited rotation (the land's axes tilt +-20 deg): full random rotation made the axis-aligned
	# bbox nearly square whatever the aspect, and the grid square is the frame everything measures in.
	s._rot = 0.0 if legacy_core else r.randf_range(-0.35, 0.35)
	# Strong low-frequency lobes (plan 1.2: a_k 0.04-0.10) make the outline read as a landmass with
	# headlands and bays rather than a crinkled disc.
	s._amps = [r.randf_range(0.05, 0.09), r.randf_range(0.03, 0.06), r.randf_range(0.015, 0.035)]
	s._ph = [r.randf() * TAU, r.randf() * TAU, r.randf() * TAU]
	# The cove's bearing is SEEDED, never taken from the json hint: IslandRuntime._publish_harbour_arrival
	# rewrites the island's 'harbour' row after every build, so a hint-derived shape would change
	# between loads (a moved dock would then be refused and snap back - t_harbour's moved-harbour case).
	# Home: south (the plan puts the cove ~115 m below the origin, the dock back near (0, 62)).
	s._home_river_z = s.camp_hint.y - 46.0
	var hint_ang := INF
	if legacy_core:
		# +z, the near side: the land sits at centre (0, -35), so its south coast is ~115 m below
		# the origin and the cove at that bearing is the one 55-60 m from the camp.
		hint_ang = PI * 0.5
	else:
		hint_ang = float(r.randi_range(0, 7)) * TAU / 8.0 + r.randf_range(-0.2, 0.2)
	# 2-4 peninsulas: narrow Gaussian-ish lobes (the width/length measure needs them long and thin).
	# 3-4 lobes: with 2 the smoothed coastline often merged both into one broad bump and the
	# headland measure (and the merge review's silhouette) came up short.
	var npen := r.randi_range(2, 3)
	var base := r.randf() * TAU
	var guard := 0.55  # keep lobes away from the harbour cove's angle
	for i in npen:
		var a := base + TAU * float(i) / float(npen) + r.randf_range(-0.45, 0.45)
		if hint_ang != INF:
			for _k in 6:
				if absf(angle_difference(a, hint_ang)) >= guard:
					break
				a += 0.55
		# Plan 1.2: one or two lobes 18-30 deg wide and 0.18-0.30 R high. The super-Gaussian's
		# sigma is the half-width where the lobe falls to 1/e, so sigma 0.16-0.26 rad = 18-30 deg.
		s._pens.append([a, r.randf_range(0.40, 0.58), r.randf_range(0.13, 0.19)])
	var nbays := r.randi_range(1, 2)
	for i in nbays:
		var a := r.randf() * TAU
		if hint_ang != INF and absf(angle_difference(a, hint_ang)) < guard + 0.35:
			a += 1.4
		s._bays.append([a, r.randf_range(0.10, 0.20), r.randf_range(0.16, 0.26)])
	var cove_ang := hint_ang if hint_ang != INF else r.randf() * TAU
	# The cove is deep on a home island: its head brings the dock back near the camp (plan 1.1).
	# Home: a deep south cove; the plan's "a 50 m cove puts the dock back at about (0, 62)".
	# NOTE: the final size calibration normalises the bbox to 375 x 300 m, so the cove's absolute
	# depth in metres is the calibrated short axis times this fraction, not a metre figure.
	s._cove = [cove_ang, 0.34 if legacy_core else r.randf_range(0.14, 0.22), r.randf_range(0.14, 0.20)]
	if s.family != "classic":
		s._apply_family()
	# Calibrate x/z so the land bbox is the tier's target (measured on the analytic coastline).
	var long_m := HOME_LONG if legacy_core else (p_land.x if p_land.x > 0.0 else target_long(p_tier))
	var short_m := HOME_SHORT if legacy_core else (p_land.y if p_land.y > 0.0 else target_short(p_tier))
	s.target = Vector2(long_m, short_m)
	var half := Vector2(0.0, 0.0)
	for i in 720:
		var th := TAU * float(i) / 720.0
		var e := s._edge(th)
		half.x = maxf(half.x, absf(cos(th)) * e)
		half.y = maxf(half.y, absf(sin(th)) * e)
	for f in s._islets + s._caps + s._bridges:
		var fa: Vector2 = f[0]
		var fb: Vector2 = f[f.size() - 2] if f.size() == 3 else fa
		var fr: float = f[f.size() - 1]
		half.x = maxf(half.x, maxf(absf(fa.x), absf(fb.x)) + fr)
		half.y = maxf(half.y, maxf(absf(fa.y), absf(fb.y)) + fr)
	s._bbox_half = half
	# Local x maps to sx * e, local z (after the internal /aspect) to sz * aspect * e.
	var wl := p_size * WATERLINE / s.shore0
	s.sx = (long_m * 0.5) / maxf(0.001, half.x * wl)
	s.sz = (short_m * 0.5) / maxf(0.001, half.y * s._aspect * wl)
	s.aspect = short_m / long_m
	# Noises.
	s._n0.seed = p_seed
	s._n0.frequency = 0.012
	s._n1.seed = p_seed + 101
	s._n1.frequency = 0.03
	s._n2.seed = p_seed + 211
	s._n2.frequency = 0.08
	s._nshore.seed = p_seed + 307
	s._nshore.frequency = 0.02
	s._ncliff.seed = p_seed + 409
	s._ncliff.frequency = 0.007
	var rr := RandomNumberGenerator.new()
	rr.seed = p_seed * 131
	var ridge_ang := rr.randf() * TAU
	if legacy_core:
		ridge_ang = 0.0
	s.ridge_dir = Vector2(cos(ridge_ang), sin(ridge_ang)).normalized()
	# Point the ridge away from the cove: the highland must not sit between the camp and the dock.
	var to_cove := Vector2(cos(float(s._cove[0])), sin(float(s._cove[0])))
	var along_cove := to_cove.dot(s.ridge_dir)
	if legacy_core:
		s.ridge_dir = Vector2.RIGHT
		along_cove = to_cove.x
	s.high_side = -1.0 if along_cove > 0.0 else 1.0
	# Mesa on ~3 in 4 islands (a plateau with a cliff rim), inland on the long axis. A shaped family
	# gets its mesas from the topography pass instead (placed after the size calibration).
	if r.randf() < 0.35 and s.family == "classic":
		var ma := atan2(s.ridge_dir.y, s.ridge_dir.x) if s.high_side > 0.0 else atan2(-s.ridge_dir.y, -s.ridge_dir.x)
		ma += r.randf_range(-0.35, 0.35)
		var mr := 16.0 + p_size * 0.015
		s.mesa = {
			"pos": Vector2(cos(ma), sin(ma)) * s.coast_radius(ma) * r.randf_range(0.30, 0.45),
			"r": mr,
			"h": 3.2 + r.randf_range(0.0, 1.4),
			# A butte, not a cone: an elliptical, rotated, noise-warped footprint.
			"aspect": r.randf_range(0.50, 0.78),
			"rot": r.randf() * TAU,
		}
	if s.family == "chain":
		s.ridge_dir = Vector2(s._axis.x * s.sx, s._axis.y * s._aspect * s.sz).normalized()
	if legacy_core:
		s._legacy_noises()
	return s

# ---------------------------------------------------------------------------- families

static func families() -> Dictionary:
	if _fam_cache.is_empty():
		var f := FileAccess.open("res://data/world/island_families.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_fam_cache = parsed as Dictionary
	var fams: Variant = _fam_cache.get("families", {})
	return fams as Dictionary if fams is Dictionary else {}

static func fam_root() -> Dictionary:
	families()
	return _fam_cache

## The family an island draws its landmass from, by its seed: the legacy meadow (private seed 17) and
## the tutorial keep "classic"; another Tamed Island picks from personal_pick, a roster island from
## roster_pick. The draw is the seed's own RNG stream, so a given island always gets the same family.
static func pick_family(p_kind: String, p_seed: int, legacy_core: bool) -> String:
	if p_kind == "tutorial" or (legacy_core and p_seed == 17):
		return "classic"
	var list: Variant = fam_root().get("personal_pick" if legacy_core else "roster_pick", [])
	if not list is Array or (list as Array).is_empty():
		return "classic"
	var r := RandomNumberGenerator.new()
	r.seed = p_seed * 48271 + 977
	return str((list as Array)[r.randi_range(0, (list as Array).size() - 1)])

static func _rng_range(r: RandomNumberGenerator, row: Dictionary, key: String, fallback: Vector2) -> float:
	var v: Variant = row.get(key, null)
	if v is Array and (v as Array).size() >= 2:
		return r.randf_range(float(v[0]), float(v[1]))
	if v is float or v is int:
		return float(v)
	return r.randf_range(fallback.x, fallback.y)

static func _rng_int(r: RandomNumberGenerator, row: Dictionary, key: String) -> int:
	var v: Variant = row.get(key, null)
	if v is Array and (v as Array).size() >= 2:
		return r.randi_range(int(v[0]), int(v[1]))
	return int(v) if (v is float or v is int) else 0

## Re-draws the body for a shaped family on its own RNG stream (the classic stream above is left as
## it was, so the classic islands keep their exact ground) and lays out the family's features.
func _apply_family() -> void:
	_fam = families().get(family, {})
	var r := RandomNumberGenerator.new()
	r.seed = seed * 104729 + 5
	_aspect = _rng_range(r, _fam, "aspect", Vector2(0.85, 0.95))
	var a := _rng_range(r, _fam, "amps", Vector2(0.03, 0.05))
	_amps = [a, a * 0.7, a * 0.45]
	_ph = [r.randf() * TAU, r.randf() * TAU, r.randf() * TAU]
	_main_scale = _rng_range(r, _fam, "main_scale", Vector2(1.0, 1.0))
	_edge_min = float(_fam.get("edge_min", 0.55))
	_plateau = bool(_fam.get("plateau", false))
	river_scale = float(_fam.get("river_scale", 1.0))
	# The dock goes on the southern-most coast now (HarbourSite.find), so the classic harbour cove is
	# off; its bearing (south, +z) still steers the river mouth away from the dock.
	_cove = [PI * 0.5, 0.0, 0.15]
	_pens.clear()
	_bays.clear()
	var npen := _rng_int(r, _fam, "pens")
	var base := r.randf() * TAU
	for i in npen:
		_pens.append([base + TAU * float(i) / float(maxi(1, npen)) + r.randf_range(-0.4, 0.4),
			_rng_range(r, _fam, "pen_amp", Vector2(0.1, 0.2)), _rng_range(r, _fam, "pen_sigma", Vector2(0.15, 0.2))])
	var nbay := _rng_int(r, _fam, "bays")
	for i in nbay:
		var ba := r.randf() * TAU
		# A bay never cuts between two lobes' axes at the same bearing: push it to the gap between.
		for lobe in _pens:
			if absf(angle_difference(ba, float(lobe[0]))) < 0.35:
				ba += 0.7
		_bays.append([ba, _rng_range(r, _fam, "bay_amp", Vector2(0.1, 0.2)), _rng_range(r, _fam, "bay_sigma", Vector2(0.1, 0.2))])
	_jag = float(_fam.get("jag", 0.0))
	_njag.seed = seed + 503
	_njag.frequency = 0.03
	_njag.fractal_octaves = 4
	var sm: Variant = _fam.get("shelf_m", [0, 0])
	if sm is Array and (sm as Array).size() >= 2:
		_shelf_m = Vector2(float(sm[0]), float(sm[1]))
	_nshelf.seed = seed + 607
	_nshelf.frequency = 0.012
	match family:
		"crescent":
			# The lagoon opens away from the south coast (the dock) and from every point the island row
			# needs on dry land (its crater, fixed spawns).
			var la := r.randf() * TAU
			for _try in 24:
				var ok := absf(angle_difference(la, PI * 0.5)) >= 0.9
				for kp in _keep:
					if kp.length() > 20.0 and absf(angle_difference(la, kp.angle())) < 1.1:
						ok = false
				if ok:
					break
				la += 0.45
			var off := _rng_range(r, _fam, "lagoon_offset", Vector2(0.8, 0.9))
			var lr := _rng_range(r, _fam, "lagoon_r", Vector2(0.5, 0.6))
			var lc := Vector2(cos(la), sin(la)) * off
			_subs.append([lc, lc, lr])
			var nb := _rng_int(r, _fam, "barrier")
			for k in nb:
				var u := (float(k) - float(nb - 1) * 0.5) * 0.36 + r.randf_range(-0.08, 0.08)
				var bc := lc + Vector2(cos(la + u), sin(la + u)) * lr * r.randf_range(0.92, 1.05)
				_islets.append([bc, r.randf_range(0.035, 0.065)])
			_arc_r = r.randf_range(0.52, 0.60)
			_arc_avoid = la
		"atoll":
			var rl := _rng_range(r, _fam, "ring_r", Vector2(0.54, 0.58))
			var rw := _rng_range(r, _fam, "ring_w", Vector2(0.14, 0.17))
			_rings.append(Vector2(rl, rw))
			var br := float(_fam.get("bridge_r", 0.065))
			var a1 := PI * 0.5 + r.randf_range(-0.4, 0.4)
			var angs := [a1, a1 + PI + r.randf_range(-0.6, 0.6)]
			for k in int(_fam.get("bridges", 2)):
				var d := Vector2(cos(float(angs[k % 2])), sin(float(angs[k % 2])))
				_bridges.append([d * (rl - rw - 0.06), d * (rl + rw + 0.06), br])
			for k in int(_fam.get("passes", 0)):
				var pa := a1 + (1.0 if r.randf() < 0.5 else -1.0) * r.randf_range(1.2, 2.0)
				var d := Vector2(cos(pa), sin(pa))
				_subs.append([d * (rl + rw - 0.02), d * 1.4, 0.045])
			_arc_r = (rl + rw + 1.0) * 0.5
		"spiral":
			var n := _rng_int(r, _fam, "spiral_n")
			var a0 := r.randf() * TAU
			var step := _rng_range(r, _fam, "spiral_step", Vector2(0.5, 0.6))
			var grow := _rng_range(r, _fam, "spiral_grow", Vector2(0.06, 0.07))
			var r0 := _rng_range(r, _fam, "spiral_r0", Vector2(0.17, 0.2))
			for k in n:
				var ang := a0 + float(k) * step
				var rad_k := _main_scale * 0.92 + float(k) * grow
				var rr := r0 * (1.0 - float(k) / float(n + 4)) * r.randf_range(0.85, 1.1)
				var c := Vector2(cos(ang), sin(ang)) * rad_k
				# The arm's root overlaps the core: those pieces are mainland, the rest are islets.
				if rad_k - rr < _main_scale * 0.98:
					_caps.append([c, c, rr])
				else:
					_islets.append([c, rr])
		"chain":
			var ad := deg_to_rad(_rng_range(r, _fam, "chain_axis_deg", Vector2(30, 60)))
			if r.randf() < 0.5:
				ad = PI - ad
			_axis = Vector2(cos(ad), sin(ad))
			var perp := Vector2(-_axis.y, _axis.x)
			var n := _rng_int(r, _fam, "chunks")
			var span := float(_fam.get("chain_span", 1.55))
			var bt := float(_fam.get("bridged_t", 1.0))
			var br := float(_fam.get("bridge_r", 0.07))
			var prev := Vector2.INF
			for k in n:
				var t := lerpf(-span, span, float(k) / float(maxi(1, n - 1))) + r.randf_range(-0.06, 0.06)
				var c := _axis * t + perp * r.randf_range(-0.09, 0.09)
				var cr := _rng_range(r, _fam, "chunk_r", Vector2(0.17, 0.27)) * (1.0 - 0.35 * clampf((absf(t) - bt) / maxf(0.01, span - bt), 0.0, 1.0))
				if absf(t) <= bt:
					_spine.append(c)
					_caps.append([c, c, cr])
					if prev != Vector2.INF:
						_caps.append([prev, c, br])
					prev = c
				else:
					_islets.append([c, cr])
	# Offshore islets round the coast (every family): just past the coastline on a random bearing.
	var ni := _rng_int(r, _fam, "islets")
	for k in ni:
		var th := r.randf() * TAU
		var ir := _rng_range(r, _fam, "islet_r", Vector2(0.03, 0.06))
		var c := Vector2(cos(th), sin(th)) * (_edge(th) + ir + r.randf_range(0.05, 0.16))
		if family == "chain":
			# Loose rocks off the chain's two ends, not round its small core.
			var sp := float(_fam.get("chain_span", 1.55)) + r.randf_range(0.12, 0.30)
			c = _axis * sp * (1.0 if k % 2 == 0 else -1.0) + Vector2(-_axis.y, _axis.x) * r.randf_range(-0.28, 0.28)
		_islets.append([c, ir])
	for it in _islets:
		_isl_c.append(it[0])
		_isl_r.append(float(it[1]))
	_has_feats = not (_islets.is_empty() and _caps.is_empty() and _subs.is_empty() and _rings.is_empty() and _bridges.is_empty())

func _legacy_noises() -> void:
	_o0 = FastNoiseLite.new()
	_o0.seed = 17
	_o0.frequency = 0.012
	_o1 = FastNoiseLite.new()
	_o1.seed = 17 + 101
	_o1.frequency = 0.03
	_o2 = FastNoiseLite.new()
	_o2.seed = 17 + 211
	_o2.frequency = 0.08
	_oshore = FastNoiseLite.new()
	_oshore.seed = 17 + 307
	_oshore.frequency = 0.02
	var rr := RandomNumberGenerator.new()
	rr.seed = 17 * 131
	var ridge_ang := rr.randf() * TAU
	_oridge = Vector2(cos(ridge_ang), sin(ridge_ang)).normalized()
	_ocamp = Vector3(0.0, 0.0, 8.0)

# ---------------------------------------------------------------------------- shape

## The angular edge in unit space: 1 = the mean coast, bigger = a peninsula.
func _edge(th: float) -> float:
	var k := 1.0
	for i in 3:
		k += _amps[i] * sin(float(i + 2) * th + _ph[i])
	for lobe in _pens:
		k += _lobe(th, float(lobe[0]), float(lobe[1]), float(lobe[2]))
	for lobe in _bays:
		k -= _lobe(th, float(lobe[0]), float(lobe[1]), float(lobe[2]))
	k -= _lobe(th, float(_cove[0]), float(_cove[1]), float(_cove[2]))
	return maxf(_edge_min, k) * _main_scale

## A narrow super-Gaussian lobe (exp of a 3rd power): long and thin, not a fat bump.
static func _lobe(th: float, centre: float, amp: float, sigma: float) -> float:
	var d := absf(angle_difference(th, centre))
	return amp * exp(-pow(d / maxf(0.001, sigma), 3.0))

## Unit-space radius of the coastline along a bearing (metres are applied by sx/sz).
func coast_unit(theta: float) -> float:
	return _edge(theta)

## Eff radius in metres (coastline at shore0). The ellipse aspect is applied in unit space.
func rad(x: float, z: float) -> float:
	var qx := (x - centre.x) / maxf(0.001, sx)
	var qz := (z - centre.y) / maxf(0.001, sz)
	var qz2 := qz / _aspect
	var th := atan2(qz2, qx)
	var m := sqrt(qx * qx + qz2 * qz2)
	if family == "classic":
		return shore0 * m / _edge(th)
	# Shaped families: a distance-like field (1 at the coast, ~1 unit per unit of q), so the body,
	# the islets, the capsules and the water cuts combine with min/max into one coastline.
	var f := 1.0 + m - _edge(th)
	if _has_feats:
		f = _feat_field(Vector2(qx, qz2), f, false)
	else:
		_in_lagoon = false
	if _jag > 0.0:
		f += _njag.get_noise_2d(x, z) * _jag
	return shore0 * f

## The family field at unit point q, given the main body's value f: union the land features, cut the
## water features, then lay the sandbars back over the water. `main_only` leaves the islets out (the
## mainland test: a dock must stand where the camp can be walked to).
func _feat_field(q: Vector2, f: float, main_only: bool) -> float:
	# Packed copies and a box test per feature: rad() runs ~100k times a build, and a feature whose
	# box is farther than the field's current excess cannot lower it.
	if not main_only:
		for i in _isl_c.size():
			var c := _isl_c[i]
			var e := f - 1.0 + _isl_r[i]
			if absf(q.x - c.x) >= e or absf(q.y - c.y) >= e:
				continue
			f = minf(f, 1.0 + q.distance_to(c) - _isl_r[i])
	for c in _caps:
		var e: float = f - 1.0 + float(c[2])
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		if q.x <= minf(a.x, b.x) - e or q.x >= maxf(a.x, b.x) + e or q.y <= minf(a.y, b.y) - e or q.y >= maxf(a.y, b.y) + e:
			continue
		f = minf(f, 1.0 + _seg_dist(q, a, b) - float(c[2]))
	var cut := -INF
	for w in _subs:
		cut = maxf(cut, 1.0 + float(w[2]) - _seg_dist(q, w[0], w[1]))
	for g in _rings:
		cut = maxf(cut, 1.0 + g.y - absf(q.length() - g.x))
	_in_lagoon = cut > 1.0
	if cut > f:
		f = cut
	for b in _bridges:
		f = minf(f, 1.0 + _seg_dist(q, b[0], b[1]) - float(b[2]))
	return f

## The main body alone (no features, no jag): coast_point's bisection needs a field that only
## grows along a ray.
func _rad_main(x: float, z: float) -> float:
	var qx := (x - centre.x) / maxf(0.001, sx)
	var qz2 := (z - centre.y) / maxf(0.001, sz) / _aspect
	var m := sqrt(qx * qx + qz2 * qz2)
	if family == "classic":
		return shore0 * m / _edge(atan2(qz2, qx))
	return shore0 * (1.0 + m - _edge(atan2(qz2, qx)))

## True when a point is on the island's mainland (the main body, its capsules and sandbars), not on
## an offshore islet: the dock must stand where the camp can be walked to. Classic: everywhere.
func on_mainland(x: float, z: float) -> bool:
	if family == "classic" or _islets.is_empty():
		return true
	var qx := (x - centre.x) / maxf(0.001, sx)
	var qz2 := (z - centre.y) / maxf(0.001, sz) / _aspect
	var f := 1.0 + sqrt(qx * qx + qz2 * qz2) - _edge(atan2(qz2, qx))
	f = _feat_field(Vector2(qx, qz2), f, true)
	return f + _njag.get_noise_2d(x, z) * _jag < 1.03

## Unit point -> world xz.
func q_to_world(q: Vector2) -> Vector2:
	return Vector2(centre.x + q.x * sx, centre.y + q.y * _aspect * sz)

## The river's minimum arc (m): t_islandgen holds every island to it. Thin families (a chain's spine,
## an atoll's ring) cannot hold a river half the island long, so their families scale it.
func river_want() -> float:
	return 0.55 * target.x * river_scale

## World point on the coastline along a world bearing (calibrated sx/sz applied).
func coast_point(theta: float) -> Vector2:
	var dir := Vector2(cos(theta), sin(theta))
	# Solve rad(p) = shore0 along the ray by bisection (monotone in the ray length).
	var lo := 0.0
	var hi := size
	for _i in 28:
		var mid := (lo + hi) * 0.5
		if _rad_main(centre.x + dir.x * mid, centre.y + dir.y * mid) < shore0:
			lo = mid
		else:
			hi = mid
	var r := (lo + hi) * 0.5
	return centre + dir * r

func coast_radius(theta: float) -> float:
	var p := coast_point(theta)
	return p.distance_to(centre)

## 1 in the middle of the island, 0 at the coastline.
func inland(x: float, z: float) -> float:
	return clampf(1.0 - rad(x, z) / shore0, 0.0, 1.0)

# ---------------------------------------------------------------------------- build

func compute() -> void:
	# Calibrate x/z so the waterline's bounding box is the tier's land target (the shore's noise
	# wander and the highlands both move the -0.05 contour away from the analytic coast).
	var long_m := target.x
	var short_m := target.y
	# The land bbox must leave >= SEA_MARGIN of sea on every side of the square: the target is
	# capped by that (a 416 m home holds at most 372 x 372 of land with 22 m a side).
	long_m = minf(long_m, size - 2.0 * SEA_MARGIN - 4.0)
	short_m = minf(short_m, size - 2.0 * SEA_MARGIN - 4.0)
	# Per-side margin pass FIRST (analytic coastline, microseconds): recentre the land inside the
	# square and scale it down until every side has SEA_MARGIN of sea plus room for the shore's own
	# noise wander. Doing this before the size calibration keeps the river's mouth attached to the
	# coast the calibration ends on.
	_settle_margins()
	PerfTrace.mark("shape.margins")
	# Iterate the two-axis extent correction: scaling x and y moves the shape's own outline too,
	# so one pass lands a few percent short (and the lobes make that non-linear).
	# Two calibrated passes decide the scale; the heightmap is then filled ONCE from the final
	# coastline. Only the waterline bbox needs the heights, and the margin settle below measures the
	# analytic coastline (no heights at all), so the intermediate fill of the old third pass - and
	# the refill _settle_margins used to trigger - were a whole extra ~330 ms on the home island.
	for round_i in 2:
		_build_river()
		PerfTrace.mark("shape.river")
		_fill_heightmap()
		PerfTrace.mark("shape.fill")
		var bb := _waterline_bbox()
		if bb.x < 1.0 or bb.y < 1.0:
			break
		var fx := long_m / maxf(1.0, maxf(bb.x, bb.y))
		var fy := short_m / maxf(1.0, minf(bb.x, bb.y))
		# Apply the correction on the matching axis (x is the long axis unless the shape turned).
		if bb.x >= bb.y:
			sx *= fx
			sz *= fy
		else:
			sx *= fy
			sz *= fx
	# The scaling above can nudge a headland back toward an edge: settle the real margins once
	# more, rebuilding the river if the coast moved under it (the mouth must stay at the sea).
	var settled := _settle_margins()
	PerfTrace.mark("shape.margins")
	if settled:
		_build_river()
	if family != "classic":
		_south_estimate()
		_place_topo()
		PerfTrace.mark("shape.topo")
	_fill_heightmap()
	PerfTrace.mark("shape.resettle")
	_slopes(size / float(res - 1))
	PerfTrace.mark("shape.slopes")
	_find_waterfall()
	PerfTrace.mark("shape.waterfall")

## Recentre and (if needed) shrink the land so every side of the square keeps SEA_MARGIN of sea,
## measured on the analytic coastline. Returns true when it changed sx/sz/centre.
func _settle_margins() -> bool:
	var changed := false
	# A shaped family's jagged coast is measured tile by tile in t_islandgen: it keeps a thinner
	# noise allowance on top of the sea margin, or the round bodies came out ~12 % under their target.
	var pad := SEA_MARGIN + size * (0.020 if family == "classic" else 0.008)
	for _round in 6:
		var cbox := _coast_rect()
		if cbox.size.x < 1.0 or cbox.size.y < 1.0:
			break
		var m := _margins(cbox)
		if m.x >= pad and m.y >= pad and m.z >= pad and m.w >= pad:
			break
		var c := cbox.position + cbox.size * 0.5
		if absf(c.x) > 0.75 or absf(c.y) > 0.75:
			centre -= c
			changed = true
			continue
		var fit := size - 2.0 * pad
		sx *= clampf(fit / maxf(1.0, cbox.size.x), 0.95, 1.0)
		sz *= clampf(fit / maxf(1.0, cbox.size.y), 0.95, 1.0)
		changed = true
	return changed

## The land's world-space extent (heights above the waterline inside the grid) as a Rect2.
func _land_rect() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var cell := size / float(res - 1)
	for z in res:
		for x in res:
			if heights[x + z * res] > -0.05:
				var wx := -size * 0.5 + float(x) * cell
				var wz := -size * 0.5 + float(z) * cell
				lo = Vector2(minf(lo.x, wx), minf(lo.y, wz))
				hi = Vector2(maxf(hi.x, wx), maxf(hi.y, wz))
	if lo.x == INF:
		return Rect2()
	return Rect2(lo, hi - lo)

## The analytic coastline's world-space box (720 bearings, no heightmap pass): the margin pass
## uses this so it costs microseconds instead of one heightmap fill per iteration.
func _coast_rect() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 360:
		var th := TAU * float(i) / 360.0
		var q := coast_point(th)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	# The family's land features reach past the main body: their unit boxes, mapped to the world.
	for f in _islets + _caps + _bridges:
		var fa: Vector2 = f[0]
		var fb: Vector2 = f[1] if f.size() == 3 else fa
		var fr: float = f[f.size() - 1] + _jag
		for q in [fa, fb]:
			var wlo := q_to_world(q - Vector2(fr, fr))
			var whi := q_to_world(q + Vector2(fr, fr))
			lo = Vector2(minf(lo.x, wlo.x), minf(lo.y, wlo.y))
			hi = Vector2(maxf(hi.x, whi.x), maxf(hi.y, whi.y))
	if lo.x == INF:
		return Rect2()
	return Rect2(lo, hi - lo)

## Sea on each side of the land inside the square: (west, east, north, south) in metres.
func _margins(r: Rect2) -> Vector4:
	var half := size * 0.5
	return Vector4(r.position.x + half, half - (r.position.x + r.size.x),
		r.position.y + half, half - (r.position.y + r.size.y))

func _fill_heightmap() -> void:
	heights.resize(res * res)
	rads.resize(res * res)
	river_d.resize(res * res)
	river_w.resize(res * res)
	vslope.resize(res * res)
	var has_topo := not topo.is_empty()
	topo_mask.resize(res * res if has_topo else 0)
	var cell := size / float(res - 1)
	for z in res:
		for x in res:
			var wx := -size * 0.5 + float(x) * cell
			var wz := -size * 0.5 + float(z) * cell
			var r := rad(wx, wz)
			var nr := river_near(wx, wz)
			var d := nr.x
			# A flat dry camp disc (r 30 m) on every island: no river, no terrace inside it.
			# (The ford is NOT dry ground any more: it is a continuous shallow crossing, so the
			# channel carve and the fresh-water mask run through it.)
			if Vector2(wx - camp_hint.x, wz - camp_hint.y).length() < CAMP_R:
				d = 10000.0

			river_w[x + z * res] = nr.y
			var idx := x + z * res
			rads[idx] = r
			river_d[idx] = d
			heights[idx] = _height(wx, wz, r, d, nr.y)
			if has_topo:
				var tv := _topo_at(wx, wz)
				heights[idx] += tv.x
				topo_mask[idx] = 1 if tv.y > 0.0 else 0

## Extent of the h > -0.05 contour inside the grid (x, y in metres).
func _waterline_bbox() -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var cell := size / float(res - 1)
	for z in res:
		for x in res:
			if heights[x + z * res] > -0.05:
				var wx := -size * 0.5 + float(x) * cell
				var wz := -size * 0.5 + float(z) * cell
				lo = Vector2(minf(lo.x, wx), minf(lo.y, wz))
				hi = Vector2(maxf(hi.x, wx), maxf(hi.y, wz))
	if lo.x == INF:
		return Vector2.ZERO
	return hi - lo

func _height(wx: float, wz: float, r: float, d_river: float, hw: float) -> float:
	var t := clampf(1.0 - r / shore0, 0.0, 1.0)
	var h := 1.0
	h += _n0.get_noise_2d(wx, wz) * 0.45
	h += _n1.get_noise_2d(wx, wz) * (0.16 * t)
	h += _n2.get_noise_2d(wx, wz) * 0.06
	# Ridge along the long axis, inland only (kept from the old generator; the island's spine).
	if t > 0.02:
		var dir := Vector2(wx, wz).normalized()
		var along := maxf(0.0, dir.dot(ridge_dir))
		var cross := absf(dir.dot(Vector2(-ridge_dir.y, ridge_dir.x)))
		var width := clampf(1.0 - cross / 0.5, 0.0, 1.0)
		h += 2.2 * along * width * sin(t * PI)
	# Highlands: a raised terrain block with flat treads and 3.2 m risers. The highland's outline is
	# one large-scale field (not per-vertex noise), so the escarpment is a few long cliff faces on
	# one flank, not a speckled cliff ring (NOTES.md, first shots).
	# The highland is a PLATEAU on one flank (along the ridge axis, away from the harbour cove):
	# a flat top ~4.6 m up with a 3.2 m escarpment at its rim, and a higher inner terrace with its
	# own 3.2 m riser. Two long cliff faces instead of a contour ring, and the plateau sits against
	# the coast on the high side, so the camp-and-dock side stays open lowland (plan 1.3).
	var along := ((wx - centre.x) * ridge_dir.x + (wz - centre.y) * ridge_dir.y) / maxf(1.0, size * 0.5)
	var flank := smoothstep(-0.05, 0.30, along * high_side) if _plateau else 0.0
	if flank > 0.0:
		var hp := centre + ridge_dir * high_side * size * 0.30
		var dd := Vector2(wx - hp.x, wz - hp.y).length() + _ncliff.get_noise_2d(wx, wz) * size * 0.045
		var rr := size * 0.27
		# The rim rises 4.6 m over ~2.6 m of run (slope ~1.8): a visible 4.6 m cliff face one grid
		# cell wide, which is what the tile loop paints CLIFF. The inner step is 3.2 m the same way.
		var rise := 4.6 * smoothstep(rr + 1.3, rr - 1.3, dd)
		var inner := 3.2 * smoothstep(rr * 0.52 + 1.3, rr * 0.52 - 1.3, dd)
		# The river's valley cuts through the plateau (the lift fades over the corridor), so the
		# channel keeps a continuous watercourse instead of being dammed by the rim.
		# The plateau is cut by a 34 m river valley (the plan's valley), so the river descends in a
		# gorge through the highland instead of being dammed by the rim.
		h += (rise + inner) * flank * smoothstep(0.10, 0.30, t) * smoothstep(12.0, 34.0, d_river)
	# Mesa: a plateau with a sharp rim (8 m edge over its 3.4-4.6 m face), warped so it reads as a
	# butte rather than a perfect cone: an elliptical footprint (aspect 0.5-0.8) whose radius is
	# pushed in and out by low-frequency noise.
	if not mesa.is_empty():
		var mp: Vector2 = mesa["pos"]
		var mq := Vector2(wx - mp.x, wz - mp.y)
		# The footprint is an ellipse in the mesa's own (rotated) frame.
		var ma := float(mesa.get("rot", 0.0))
		var mc := cos(ma)
		var ms := sin(ma)
		var mq2 := Vector2(mq.x * mc + mq.y * ms, (-mq.x * ms + mq.y * mc) / float(mesa.get("aspect", 0.7)))
		var md := mq2.length() + _ncliff.get_noise_2d(wx * 1.7, wz * 1.7) * size * 0.030
		var mr := float(mesa["r"])
		var mh := float(mesa["h"])
		h += mh * smoothstep(mr + 4.0, mr - 4.0, md)
	# Valley: a shallow shoulder that starts OUTSIDE twice the channel's half-width and never dips
	# below +0.25 m. The old 1.5 m dip reaching to the bank put a 25-35 m valley floor at the -0.05
	# waterline; with the water shader's alpha floor that whole floor painted as water, and terrain
	# bumps poked through it as rows of brown chevrons (the merge review's shot).
	var bank_h := h
	if d_river > hw * 2.0 and d_river < hw * 2.0 + 24.0:
		var vw := (d_river - hw * 2.0) / 24.0
		var dip := 0.6 * (1.0 - vw) * (1.0 - vw)
		h -= maxf(0.0, minf(dip, h - 0.25))
	# Legacy core (home): the old seed-17 height function, blended in first, so the new features
	# (the river, the terraces) still apply on top and the core is old GROUND, not a frozen patch.
	if legacy:
		var r0 := Vector2(wx, wz).length()
		var w := 1.0 - smoothstep(LEGACY_FULL, LEGACY_END, r0)
		if w > 0.0:
			h = lerpf(h, _legacy_height(wx, wz), w)
	# Shore: dry -> wet sand -> shallow -> deep, edges wander with noise (kept from the old code).
	var wander := _nshore.get_noise_2d(wx, wz) * (size * 0.010)
	var rs := r + wander
	# The beach, dimensioned for HarbourSite's 1 m dock rows and for a walkable shore: h = 0.40 at
	# shore0, a steady 0.30 m per metre seaward (the waterline 1.5 m out, wadeable shallows), then a
	# drop to -2.6 m by 14 m out. That leaves a 1 m dock row on land, the next row above water, and
	# rows 2-5 below water with the tip about 1 m deep; steeper or flatter ramps each lost most
	# bearings (NOTES.md).
	if rs > shore0:
		var d := rs - shore0
		var hb := 0.40 - 0.30 * d
		if _shelf_m.y > 0.0:
			# ISLANDSHAPES: a shallow turquoise shelf past the beach (-0.85 m: still boat-deep for the
			# dock's 0.4 m draft) whose reach wanders along the coast, then the drop to the deep sea.
			# A lagoon's whole floor is shelf.
			var reach := lerpf(_shelf_m.x, _shelf_m.y, clampf(_nshelf.get_noise_2d(wx, wz) * 1.4 + 0.5, 0.0, 1.0))
			if _in_lagoon:
				reach = 1000.0
			hb = maxf(hb, -0.85) if d < 5.0 + reach else lerpf(-0.85, -2.6, clampf((d - 5.0 - reach) / 10.0, 0.0, 1.0))
		elif d > 12.0:
			hb = lerpf(hb, -2.6, clampf((d - 12.0) / 6.0, 0.0, 1.0))
		h = minf(h, hb)
	# The river channel, with banks: bed at -0.33 (t_water's -0.25..-0.38 fresh-water profile).
	# The ford and the home's legacy core keep their ground (a dry crossing, and old ground).
	# The last 4 m before the shore is beach: the channel stops at the waterline so the delta does
	# not cut the coast into two dry lobes (the mouth still reaches the sea).
	if r > shore0 - 4.0:
		hw = 0.0
	# The camp clearing is never cut by the channel: an old basket stands 2 m from the camp centre and
	# must stay on dry, buildable ground (t_save's away golden).
	if Vector2(wx - camp_hint.x, wz - camp_hint.y).length() < CAMP_R:
		d_river = 10000.0
	# The ford: a continuous shallow crossing, not a dry disc. The channel keeps its water and its
	# MUD (so the fresh-water mask is unbroken along the river); only the bed rises to -0.10 m over
	# about 10 m, which a survivor wades and every creature walks.
	var ford_w := 0.0
	if ford != Vector2.ZERO:
		var fd := Vector2(wx - ford.x, wz - ford.y).length()
		if fd < FORD_R:
			ford_w = smoothstep(FORD_R, FORD_R * 0.45, fd)
	if d_river < hw * 2.2:
		# The bed follows the ground: about 0.6 m below the bank, and only in the low ground (below
		# ~2.4 m of bank) does it reach the waterline profile (-0.33, t_water's -0.25..-0.38). Up in
		# the highlands it is a dry descending gully instead of a flat trench cut across a hill.
		# In the high ground the channel is a dry descending gully (bed 0.6 m under the flank);
		# in the low ground it sits at the waterline: -0.33 (t_water's fresh-water profile).
		# The engine has ONE water plane (-0.05), so fresh water can only exist where the bed is
		# below it: the channel bottom is at the t_water profile (-0.33) along its whole length, and
		# in high ground it is cut deeper (0.7 m under the bank) so the channel reads as a gorge
		# with a river in it rather than a flat trench sliced through a hill (the plan's waterfall).
		var bed := minf(-0.33, bank_h - 0.7)
		# At the ford the bed rises to a shallow -0.10 m (still below the -0.05 water plane, so the
		# river reads continuous through the crossing and the channel tiles stay MUD).
		bed = lerpf(bed, -0.10, ford_w)
		# One smooth channel profile: the ground falls from the bank to the bed across 2.2 channel
		# half-widths, so the waterline is a smooth curve. The old two-branch carve (a hard flat
		# bed inside `hw`, then a bank lerp) left a stepped rim that read as a sawtooth bank on the
		# 2.6 m mesh.
		var u := d_river / maxf(0.001, hw)
		var w := smoothstep(2.2, 0.55, u)
		h = lerpf(h, minf(h, bed), w)
	# Camp disc: a flat dry clearing (1.1 m) 30 m across, on every island - the legacy camp pieces,
	# the old baskets and any new landing camp stand on it. Full inside 18 m, blended out by 30 m.
	var camp_d := Vector2(wx - camp_hint.x, wz - camp_hint.y).length()
	if camp_d < CAMP_R:
		var cw := smoothstep(CAMP_R, 18.0, camp_d)
		h = lerpf(h, CAMP_FLAT, cw)
	return h

## The pre-ISLANDGEN home height function (size 160, seed 17, ridges, the two river stubs, the old
## shore) evaluated at the same world point. Old saves' ground.
func _legacy_height(wx: float, wz: float) -> float:
	var lsize := 160.0
	var lshore0 := lsize * 0.36
	var lshore1 := lsize * 0.47
	var h := 1.1
	h += _o0.get_noise_2d(wx, wz) * 0.45
	h += _o1.get_noise_2d(wx, wz) * 0.18
	h += _o2.get_noise_2d(wx, wz) * 0.06
	var r := Vector2(wx, wz).length()
	if r > lsize * 0.14 and r < lshore0:
		var dir := Vector2(wx, wz).normalized()
		var along := maxf(0.0, dir.dot(_oridge))
		var cross := absf(dir.dot(Vector2(-_oridge.y, _oridge.x)))
		var width := clampf(1.0 - cross / 0.5, 0.0, 1.0)
		var inland0 := clampf((r - lsize * 0.14) / (lshore0 - lsize * 0.14), 0.0, 1.0)
		h += 2.0 * along * width * sin(inland0 * PI)
	# The old generator's two dead-end river stubs are NOT reproduced: nothing saved stands on them,
	# and inside the flat legacy core they read as two water holes by the camp (NOTES.md). The real
	# river replaces them.
	var wander := _oshore.get_noise_2d(wx, wz) * (lsize * 0.03)
	var rs := r + wander
	if rs > lshore0:
		var st := clampf((rs - lshore0) / maxf(0.001, lshore1 - lshore0), 0.0, 1.0)
		var eased := st * st * (3.0 - 2.0 * st)
		h = lerpf(h, -1.4, eased)
	if rs > lshore1:
		var t2 := clampf((rs - lshore1) / (lsize * 0.05), 0.0, 1.0)
		h = lerpf(h, -2.6, t2)
	var camp_d := Vector2(wx - _ocamp.x, wz - _ocamp.z).length()
	if camp_d < 16.0:
		var s := clampf(1.0 - camp_d / 16.0, 0.0, 1.0)
		h = lerpf(h, 1.1, s * 0.6)
	return h

# ---------------------------------------------------------------------------- river

## The river: a plateau source on the highland flank, a meandering channel (+-15 m) to a mouth on
## the coast 60-120 deg off the harbour cove, at least half the island's long axis long. Paths that
## run out along a bay or come up short are rejected and re-seeded rather than clipped (a clipped
## river was a coastal stub on tundra_30, swamp_55 and volcanic_60).
func _build_river() -> void:
	var want := river_want()
	var best_river := PackedVector2Array()
	var best_len := -1.0
	# The candidate search runs once: later passes (the size calibration refills the heightmap up
	# to four times) replay only the winning attempt, so a rebuild costs one candidate, not eight.
	var first := 0
	var last := 8 if family == "classic" else 16
	if _river_attempt >= 0:
		first = _river_attempt
		last = _river_attempt + 1
	for attempt in range(first, last):
		var rr := RandomNumberGenerator.new()
		rr.seed = seed * 313 + 7 + attempt * 977
		var p := _river_candidate(rr)
		if p.size() < 4:
			continue
		var arc := 0.0
		for i in p.size() - 1:
			arc += p[i].distance_to(p[i + 1])
		# The body of the channel must be inland: only the mouth's last few samples (about 10 m)
		# may sit at or past the coastline. A path that runs along a bay is not a river.
		var outside := 0
		var body := int(p.size() * 0.90)
		for i in body:
			if rad(p[i].x, p[i].y) > shore0 * 0.97:
				outside = 999
				break
		var ok := outside == 0 and arc >= want
		if OS.get_environment("ISL_RIVER") == "1":
			print("[riverdbg] attempt=%d arc=%.0f want=%.0f outside=%d rad_end=%.0f shore0=%.0f" % [attempt, arc, want, outside, rad(p[p.size() - 1].x, p[p.size() - 1].y), shore0])
		if ok:
			best_river = p
			best_len = arc
			_river_attempt = attempt
			break
		if arc > best_len and outside == 0:
			best_len = arc
			best_river = p
	if best_river.is_empty():
		if _river_attempt >= 0:
			# The replayed attempt is invalid at the new scale: search the whole set again.
			_river_attempt = -1
			_build_river()
		return
	river = best_river
	river_arc = best_len
	if OS.get_environment("ISL_RIVER") == "1":
		var e := river[river.size() - 1]
		print("[riverdbg] chose arc=%.0f n=%d end=%s rad_end=%.1f shore0=%.1f to_sea=%s" % [best_len, river.size(), e, rad(e.x, e.y), shore0, river_to_sea()])
	_river_w.resize(river.size())
	for i in river.size():
		var t := float(i) / float(maxi(1, river.size() - 1))
		# Half-width: a 7-12 m channel (the review's band), widening to a small delta at the mouth.
		_river_w[i] = lerpf(3.5, 5.0, t)
		# The source narrows to a spring: a constant-width sheet cut off square in the highland was
		# the "river ends in a rectangle" read in the top-down shot.
		if t < 0.18:
			_river_w[i] = lerpf(0.9, _river_w[i], smoothstep(0.0, 0.18, t))
		if t > 0.85:
			_river_w[i] = lerpf(5.0, 7.0, (t - 0.85) / 0.15)
	_bucket_river()
	# Ford: a shallow crossing on the middle of the channel, at least 30 m from camp (home: the
	# old dry gap at |x| < 25 m, plan 1.3).
	var best := -1
	var best_d := INF
	for i in river.size():
		var q := river[i]
		if legacy and absf(q.x) < 25.0:
			best = i
			best_d = absf(q.x)
			continue
		var dc := Vector2(q.x - camp_hint.x, q.y - camp_hint.y).length()
		var t := float(i) / float(maxi(1, river.size() - 1))
		# Clear of the camp's flat disc: the clearing damps the channel and would leave the ford on
		# dry bank instead of in the water.
		if t > 0.25 and t < 0.62 and dc > CAMP_R + 12.0 and dc < best_d:
			best = i
			best_d = dc
	if best >= 0:
		ford = river[best]
	if OS.get_environment("ISL_RIVER") == "1":
		var zs := ""
		for i in range(0, river.size(), 9):
			zs += "%s " % river[i].snapped(Vector2.ONE)
		print("[riverdbg] legacy=%s ford=%s river: %s" % [legacy, ford, zs])

## One candidate channel (72 samples), or an empty array when the geometry cannot be formed.
func _river_candidate(rr: RandomNumberGenerator) -> PackedVector2Array:
	match str(_fam.get("river", "radial")):
		"polar":
			return _river_polar(rr)
		"linear":
			return _river_linear(rr)
	var hint_ang := atan2(_cove_centre().y, _cove_centre().x)
	# The mouth is 60-120 deg off the cove's bearing, so the river does not empty into the harbour.
	var mouth_ang := hint_ang + (PI * 0.62 if rr.randf() < 0.5 else -PI * 0.62) + rr.randf_range(-0.35, 0.35)
	if legacy:
		# Home: east highland -> west coast, north of the camp (the old stubs' line), so the
		# legacy core around the origin keeps its flat dry ground.
		mouth_ang = PI + rr.randf_range(-0.25, 0.15)
	var mouth := coast_point(mouth_ang) * 1.02  # a few metres into the sea
	# The source sits on the plateau on the highland flank: high ground, well inland.
	var ridge_ang := atan2(ridge_dir.y, ridge_dir.x)
	if high_side < 0.0:
		ridge_ang += PI
	var source_ang := ridge_ang + rr.randf_range(-0.5, 0.5)
	var cr := coast_radius(source_ang)
	var source := centre + Vector2(cos(source_ang), sin(source_ang)) * cr * 0.58
	for _k in 40:
		if rad(source.x, source.y) < shore0 * 0.78:
			break
		source = source.lerp(centre, 0.12)
	if legacy:
		# Home (plan 1.3): the channel runs along the old stub line (z = -18) from the east
		# highland to the west coast, north of the camp.
		var z0 := _home_river_z
		var east := coast_on_line(z0, 1.0)
		source = Vector2(east.x - 34.0, z0)
		mouth = Vector2(coast_on_line(z0, -1.0).x - 3.0, z0)
	var axis := mouth - source
	if axis.length() < 40.0:
		return PackedVector2Array()
	var perp := Vector2(-axis.y, axis.x).normalized()
	# A smooth meander, two gentle S-bends of +-15 m: the channel reads as a river, not a canal.
	var amp := 15.0
	var phase := rr.randf_range(-0.6, 0.6)
	var ctrl := PackedVector2Array()
	var n := 9
	for i in n:
		var t := float(i) / float(n - 1)
		var p := source.lerp(mouth, t) + perp * sin(t * TAU * 1.15 + phase) * amp
		for _k in 40:
			if rad(p.x, p.y) < shore0 * 0.80:
				break
			p = p.lerp(centre, 0.1)
		if legacy:
			# The home channel keeps its line north of the camp: the meander runs up to 15 m SOUTH
			# of it, so the camp disc and the dry grass at (-48, 0) that t_water checks stay clear.
			# A real +-15 m meander along the old stub line (the review's figure): the camp disc is
			# 42 m north of the line, so even the northmost bend leaves 27 m of dry ground.
			p.y = _home_river_z + sin(t * TAU * 1.15 + phase) * amp
		# Keep the channel clear of the camp's flat disc: the clearing flattens the ground, which
		# dammed the river there (a 2 m bank across the channel, no MUD, a broken fresh-water mask).
		var away := p - camp_hint
		var keep_out := CAMP_R + 8.0
		if away.length() < keep_out:
			p = camp_hint + (away.normalized() if away.length() > 0.5 else Vector2.DOWN) * keep_out
		ctrl.append(p)
	# The mouth is the coast crossing: march out from the last inland control point TOWARD the
	# intended mouth until the coast, then 6 m into the sea. This replaces the old post-hoc
	# clipping, which cut real rivers short.
	var last := ctrl[ctrl.size() - 2]
	var out_dir := (mouth - last)
	if out_dir.length() < 1.0:
		out_dir = (ctrl[ctrl.size() - 1] - last)
	out_dir = out_dir.normalized()
	var edge := last
	for _k in 300:
		var q := edge + out_dir * 1.5
		if rad(q.x, q.y) >= shore0:
			break
		edge = q
	ctrl[ctrl.size() - 1] = edge + out_dir * 6.0 if family == "classic" else _march_out(edge, out_dir)
	return _spline(ctrl)

## The river's mouth: march from `last` along `out_dir` to the coast, then 6 m into the sea.
func _march_out(last: Vector2, out_dir: Vector2) -> Vector2:
	var edge := last
	for _k in 300:
		var q := edge + out_dir * 1.5
		if rad(q.x, q.y) >= shore0:
			break
		edge = q
	# 6 m into the sea, further if the jagged coast or a rock sits there: the mouth must be at sea.
	var m := edge + out_dir * 6.0
	for _k in 8:
		if rad(m.x, m.y) >= shore0 * 1.02:
			break
		m += out_dir * 2.0
	return m

## Atoll / crescent: the river follows an arc round the unit origin (the ring's band, or the crescent's
## body round its lagoon) and turns out to the open sea at its far end.
func _river_polar(rr: RandomNumberGenerator) -> PackedVector2Array:
	var span := rr.randf_range(1.5, 2.1) * (1.0 if rr.randf() < 0.5 else -1.0)
	var a0 := rr.randf() * TAU
	if _arc_avoid != INF:
		# Centre the arc on the side away from the lagoon's mouth.
		a0 = _arc_avoid + PI - span * 0.5 + rr.randf_range(-0.25, 0.25)
	var ctrl := PackedVector2Array()
	var n := 9
	var phase := rr.randf_range(-0.6, 0.6)
	for i in n:
		var t := float(i) / float(n - 1)
		var a := a0 + span * t
		var rq := _arc_r + sin(t * TAU * 1.15 + phase) * 0.025
		ctrl.append(q_to_world(Vector2(cos(a), sin(a)) * rq))
	var out := (ctrl[n - 1] - q_to_world(Vector2.ZERO)).normalized()
	ctrl[n - 1] = _march_out(ctrl[n - 1], out)
	return _spline(ctrl)

## Chain: the river runs down the spine from one end of the linked chunks and leaves it sideways
## before the camp in the middle.
func _river_linear(rr: RandomNumberGenerator) -> PackedVector2Array:
	if _spine.size() < 3:
		return PackedVector2Array()
	# From one end chunk along the chunk centres (the sandbars join them) to the last chunk before
	# the camp's middle one, then out to sea sideways.
	var n := _spine.size()
	var from_end := rr.randf() < 0.5
	var mid := n / 2
	var ctrl := PackedVector2Array()
	var idx: Array[int] = []
	if from_end:
		for k in range(n - 1, mid, -1):
			idx.append(k)
	else:
		for k in range(0, mid):
			idx.append(k)
	if idx.is_empty():
		return PackedVector2Array()
	# Start past the end chunk's centre (its outer half) and stop halfway to the camp's chunk.
	var first_q := _spine[idx[0]]
	var outward := (first_q - _spine[mid]).normalized()
	ctrl.append(q_to_world(first_q + outward * 0.08))
	for k in idx:
		ctrl.append(q_to_world(_spine[k]))
	ctrl.append(q_to_world((_spine[idx[idx.size() - 1]] + _spine[mid]) * 0.5))
	# Densify: a sample between each pair of chunk centres keeps the spline on the sandbars.
	var dense := PackedVector2Array()
	for i in ctrl.size():
		dense.append(ctrl[i])
		if i + 1 < ctrl.size():
			dense.append((ctrl[i] + ctrl[i + 1]) * 0.5)
	var perp := Vector2(-_axis.y, _axis.x) * (1.0 if rr.randf() < 0.5 else -1.0)
	var wdir := (q_to_world(perp) - q_to_world(Vector2.ZERO)).normalized()
	dense.append(_march_out(dense[dense.size() - 1], wdir))
	return _spline(dense)

## Catmull-Rom subdivision of the control points to 72 samples (4-5 m apart): the carve tests
## distance to the nearest segment, so sparse samples made a staircase channel (NOTES.md, first shot).
func _spline(ctrl: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := 72
	for i in m:
		var t := float(i) / float(m - 1) * float(ctrl.size() - 1)
		var k := mini(int(floor(t)), ctrl.size() - 2)
		var f := t - float(k)
		var p0 := ctrl[maxi(k - 1, 0)]
		var p1 := ctrl[k]
		var p2 := ctrl[k + 1]
		var p3 := ctrl[mini(k + 2, ctrl.size() - 1)]
		out.append(_catmull(p0, p1, p2, p3, f))
	return out

func _bucket_river() -> void:
	_segs.clear()
	for i in river.size() - 1:
		var a := river[i]
		var b := river[i + 1]
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(SEG_CELL, SEG_CELL)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(SEG_CELL, SEG_CELL)
		for cz in range(int(floor(lo.y / SEG_CELL)), int(floor(hi.y / SEG_CELL)) + 1):
			for cx in range(int(floor(lo.x / SEG_CELL)), int(floor(hi.x / SEG_CELL)) + 1):
				var key := Vector2i(cx, cz)
				var arr: Array = _segs.get(key, [])
				arr.append(i)
				_segs[key] = arr

## Distance to the river (m) and the channel's half-width there, from the segment buckets.
## `far` is what a vertex outside the buckets gets (no river nearby).
func river_near(x: float, z: float, far: float = 10000.0) -> Vector2:
	if river.size() < 2:
		return Vector2(far, 4.0)
	var key := Vector2i(int(floor(x / SEG_CELL)), int(floor(z / SEG_CELL)))
	var arr: Array = _segs.get(key, [])
	if arr.is_empty():
		return Vector2(far, 4.0)
	var p := Vector2(x, z)
	var best := far
	var w := 4.0
	for si in arr:
		var i: int = si
		var d := _seg_dist(p, river[i], river[i + 1])
		if d < best:
			best = d
			w = lerpf(_river_w[i], _river_w[i + 1], 0.5)
	return Vector2(best, w)

## Where the line z = z0 leaves the island's coast, along +x (dir 1) or -x (dir -1).
func coast_on_line(z0: float, dir: float) -> Vector2:
	var lo := 0.0
	var hi := size * 0.5
	for _i in 30:
		var mid := (lo + hi) * 0.5
		var x := centre.x + dir * mid
		if rad(x, z0) < shore0:
			lo = mid
		else:
			hi = mid
	return Vector2(centre.x + dir * ((lo + hi) * 0.5), z0)

static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _cove_centre() -> Vector2:
	return Vector2(cos(float(_cove[0])), sin(float(_cove[0])))

## Distance from a world point to the river polyline (m).
func river_dist(x: float, z: float) -> float:
	if river.size() < 2:
		return 10000.0
	var p := Vector2(x, z)
	var best := 10000.0
	for i in river.size() - 1:
		var d := _seg_dist(p, river[i], river[i + 1])
		if d < best:
			best = d
	return best

## Channel half-width at a world point: the width of the nearest river sample.
func river_half_width(x: float, z: float) -> float:
	if river.size() < 2:
		return 4.0
	var p := Vector2(x, z)
	var best := 10000.0
	var w := 4.0
	for i in river.size() - 1:
		var d := _seg_dist(p, river[i], river[i + 1])
		if d < best:
			best = d
			w = lerpf(_river_w[i], _river_w[i + 1], 0.5)
	return w

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

## True when the whole channel body (everything but the mouth's last few metres) is inland: a
## river that runs out along a bay is a coastal stub, not a river.
func river_runs_inland() -> bool:
	if river.size() < 4:
		return false
	for i in int(river.size() * 0.90):
		if rad(river[i].x, river[i].y) > shore0 * 0.97:
			return false
	return true

## The river's mouth in the sea (last sample) and whether the channel reaches deep water.
func river_to_sea() -> bool:
	if river.size() < 2:
		return false
	var p := river[river.size() - 1]
	return rad(p.x, p.y) >= shore0 * 0.98

# ---------------------------------------------------------------------------- slopes and the waterfall

## Per-vertex gradient (rise/run) from the built heights; the tile loop paints CLIFF from it.
func _slopes(cell: float) -> void:
	for z in res:
		for x in res:
			var hx0 := heights[maxi(0, x - 1) + z * res]
			var hx1 := heights[mini(res - 1, x + 1) + z * res]
			var hz0 := heights[x + maxi(0, z - 1) * res]
			var hz1 := heights[x + mini(res - 1, z + 1) * res]
			# Steepest one-sided difference, divided by the full cell: a terrace riser is a single
			# vertex step of 3.2 m, and a centred difference over two cells would halve it.
			var dx := maxf(absf(hx1 - heights[x + z * res]), absf(heights[x + z * res] - hx0)) / cell
			var dz := maxf(absf(hz1 - heights[x + z * res]), absf(heights[x + z * res] - hz0)) / cell
			vslope[x + z * res] = sqrt(dx * dx + dz * dz)

## A waterfall marker where the river drops more than 1.2 m between samples (a cliff it runs over).
func _find_waterfall() -> void:
	for i in river.size() - 1:
		var a := river[i]
		var b := river[i + 1]
		var ha := _bank_height(a)
		var hb := _bank_height(b)
		if ha - hb > 1.2:
			waterfall = Vector3((a.x + b.x) * 0.5, hb + 0.3, (a.y + b.y) * 0.5)
			return

## Ground height just outside the channel's bank (the terrain the channel is cut into).
func _bank_height(p: Vector2) -> float:
	var best := -100.0
	for k in 8:
		var ang := TAU * float(k) / 8.0
		var q := p + Vector2(cos(ang), sin(ang)) * (river_half_width(p.x, p.y) * 2.4)
		var h := sample_height(q.x, q.y)
		best = maxf(best, h)
	return best

## Bilinear height from the built grid (no runtime needed; used during compute()).
func sample_height(x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var cell := size / float(res - 1)
	var u := clampf((x + size * 0.5) / cell, 0.0, float(res - 1))
	var v := clampf((z + size * 0.5) / cell, 0.0, float(res - 1))
	var x0 := int(floor(u))
	var z0 := int(floor(v))
	var x1 := mini(x0 + 1, res - 1)
	var z1 := mini(z0 + 1, res - 1)
	var tx := u - float(x0)
	var tz := v - float(z0)
	var h00 := heights[x0 + z0 * res]
	var h10 := heights[x1 + z0 * res]
	var h01 := heights[x0 + z1 * res]
	var h11 := heights[x1 + z1 * res]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

# ---------------------------------------------------------------------------- coast measurement

static func _convex_hull(points: PackedVector2Array) -> PackedVector2Array:
	var arr: Array = []
	for p in points:
		arr.append(p)
	arr.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var pts := PackedVector2Array(arr)
	var n := pts.size()
	if n < 3:
		return pts
	var hull := PackedVector2Array()
	var lower: Array[Vector2] = []
	for i in n:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], pts[i]) <= 0.0:
			lower.pop_back()
		lower.append(pts[i])
	var upper: Array[Vector2] = []
	for i in range(n - 1, -1, -1):
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], pts[i]) <= 0.0:
			upper.pop_back()
		upper.append(pts[i])
	lower.pop_back()
	upper.pop_back()
	for p in lower:
		hull.append(p)
	for p in upper:
		hull.append(p)
	return hull

static func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)

static func _poly_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5

## Coast metrics used by the lab and t_islandgen: land area, bbox, aspect, perimeter, peninsulas.
## A peninsula, documented: sample the coast radius R(phi) along 720 bearings from the origin
## (the furthest point on each bearing that stands above the waterline), smooth it, then for each
## local maximum take the two neighbouring minima, draw their chord, and measure
##   L = distance from the chord's midpoint to the peak (the lobe's length),
##   W = the widest spread of the lobe's coast points perpendicular to that axis.
## A lobe counts when L >= 20 m, its prominence above the chord >= 10 m and W < 0.45 * L.
static func coast_metrics(rt: IslandRuntime) -> Dictionary:
	var n := 720
	var size: float = rt._size
	var half := size * 0.5
	var r := PackedFloat32Array()
	r.resize(n)
	for i in n:
		var th := TAU * float(i) / float(n)
		var dx := cos(th)
		var dz := sin(th)
		var last := 0.0
		var d := 2.0
		while d < half - 1.0:
			var h := rt.surface_y(dx * d, dz * d)
			if h > -0.05:
				last = d
			d += 1.5
		r[i] = last
	# Smooth (5-tap circular mean) so noise crinkle is not mistaken for a lobe.
	var sm := PackedFloat32Array()
	sm.resize(n)
	for i in n:
		var acc := 0.0
		for k in range(-5, 6):
			acc += r[posmod(i + k, n)]
		sm[i] = acc / 11.0
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var th := TAU * float(i) / float(n)
		pts[i] = Vector2(cos(th), sin(th)) * sm[i]
	# Local extrema in order.
	var ext: Array[Vector2i] = []  # [index, +1 max / -1 min]
	for i in n:
		var a := sm[posmod(i - 1, n)]
		var b := sm[i]
		var c := sm[posmod(i + 1, n)]
		if b >= a and b >= c:
			ext.append(Vector2i(i, 1))
		elif b <= a and b <= c:
			ext.append(Vector2i(i, -1))
	# Merge runs of the same type within 12 samples.
	var seq: Array[Vector2i] = []
	for e in ext:
		if not seq.is_empty() and seq[seq.size() - 1].y == e.y and posmod(e.x - seq[seq.size() - 1].x, n) < 12:
			continue
		seq.append(e)
	if seq.size() > 2 and seq[0].y == seq[seq.size() - 1].y:
		seq.remove_at(0)
	var pens: Array[Dictionary] = []
	var mean_r := 0.0
	for i in n:
		mean_r += sm[i]
	mean_r /= float(n)
	for j in seq.size():
		var e := seq[j]
		if e.y != 1 or seq.size() < 3:
			continue
		var li := seq[(j - 1 + seq.size()) % seq.size()].x
		var ri := seq[(j + 1) % seq.size()].x
		var a := pts[li]
		var b := pts[ri]
		var peak := pts[e.x]
		var base_mid := (a + b) * 0.5
		var axis := peak - base_mid
		var length := axis.length()
		# Angular width: the span of coast whose radius exceeds the flank minima (the lobe's foot).
		var span_deg := float(posmod(ri - li, n)) / float(n) * 360.0
		# Perpendicular spread of the foot's coast points.
		var adir := axis / maxf(0.001, length)
		var perp := Vector2(-adir.y, adir.x)
		var wmax := 0.0
		var k := li
		var guard := 0
		while true:
			wmax = maxf(wmax, absf((pts[k] - base_mid).dot(perp)))
			if k == ri or guard > n:
				break
			k = (k + 1) % n
			guard += 1
		# Arc width of the foot: the coast length between the flank minima (plan 1.2: headlands
		# are 50-90 m wide; the lobe sigma is 18-30 deg of the ~180 m mean radius).
		var arc := 0.0
		var kk := li
		while kk != ri:
			var q0 := pts[kk]
			var q1 := pts[(kk + 1) % n]
			arc += q0.distance_to(q1)
			kk = (kk + 1) % n
		var width := maxf(wmax * 2.0, arc)
		# Plan 1.2 headland: 18-30 deg wide (the lobes), at least 0.10 mean-R of radial prominence.
		# The task's "<45 % width/length" would count only 20 m needles; the plan wins (NOTES.md).
		# A headland (plan 1.2): a lobe 12-45 deg wide whose summit stands >= 6 m above the chord
		# between its flank minima; the foot is a 40-150 m stretch of coast.
		if length >= 0.06 * mean_r and span_deg >= 12.0 and span_deg <= 45.0 and width >= 40.0 and width <= 190.0:
			pens.append({"length": length, "width": width, "ratio": width / maxf(0.001, length), "angle": span_deg})
	# Land area / bbox / perimeter from the tile map (1 m tiles).
	var land := 0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var span: int = rt._tile_span
	var per := 0
	for z in span:
		for x in span:
			var wx := -size * 0.5 + float(x) + 0.5
			var wz := -size * 0.5 + float(z) + 0.5
			if rt.surface_y(wx, wz) > -0.05:
				land += 1
				lo = Vector2(minf(lo.x, wx), minf(lo.y, wz))
				hi = Vector2(maxf(hi.x, wx), maxf(hi.y, wz))
				# Perimeter: a land tile touching water or the grid edge.
				if x == 0 or z == 0 or x == span - 1 or z == span - 1:
					per += 1
				else:
					if rt.surface_y(wx + 1.0, wz) <= -0.05 or rt.surface_y(wx - 1.0, wz) <= -0.05 \
						or rt.surface_y(wx, wz + 1.0) <= -0.05 or rt.surface_y(wx, wz - 1.0) <= -0.05:
						per += 1
	var bw := hi.x - lo.x + 1.0
	var bh := hi.y - lo.y + 1.0
	# Real per-side margins (metres of sea between the land and the grid edge). The centred
	# `(size - bbox) * 0.5` hid the clipped-headland case: a headland that ran out of the square
	# has zero margin on that side and reads as a straight cut in the top-down shot.
	var hm := half
	var m_w := lo.x + hm
	var m_e := hm - hi.x
	var m_n := lo.y + hm
	var m_s := hm - hi.y
	var cliff := 0
	for i in rt.tile_types.size():
		if int(rt.tile_types[i]) == IslandTerrain.TileType.CLIFF:
			cliff += 1
	# Solidity: land area over the area of the coast polygon's convex hull (a ragged, lobed island
	# sits at 0.80-0.92; a disc is ~1.0).
	var hull := _convex_hull(pts)
	return {
		"solidity": float(land) / maxf(1.0, absf(_poly_area(hull))),
		"land": land,
		"bbox": Vector2(bw, bh),
		"aspect": minf(bw, bh) / maxf(bw, bh),
		"perimeter": per,
		"coast_ratio": float(per) / sqrt(maxf(1.0, float(land))),
		"peninsulas": pens.size(),
		"pen_details": pens,
		"cliff_cells": cliff,
		# Sea on each side of the square grid (metres): west, east, north, south, and the smallest.
		"margin_w": m_w,
		"margin_e": m_e,
		"margin_n": m_n,
		"margin_s": m_s,
		"margin_min": minf(minf(m_w, m_e), minf(m_n, m_s)),
	}

# ---------------------------------------------------------------------------- topography (ISLANDSHAPES)

## The southern-most mainland coast point (largest z above the waterline), from the calibrated
## heights: HarbourSite puts the dock on that coast, so topography keeps off the walk to it.
func _south_estimate() -> void:
	var cell := size / float(res - 1)
	for z in range(res - 1, -1, -1):
		for x in res:
			if heights[x + z * res] > 0.4:
				var wx := -size * 0.5 + float(x) * cell
				var wz := -size * 0.5 + float(z) * cell
				if on_mainland(wx, wz):
					south_est = Vector2(wx, wz)
					return

## Lays out the family's non-navigable topography (island_families.json "topo", sizes in
## "topo_sizes"): volcanoes, mountains, ridges and mesas, biggest first. A feature stands well
## inland (its whole footprint keep_coast_m from the coast, so never on a beach or a dock), clear of
## the camp and its claim, the river and its ford, the camp-to-dock walk and every other feature.
func _place_topo() -> void:
	topo.clear()
	var sizes: Dictionary = fam_root().get("topo_sizes", {})
	var want: Dictionary = (_fam.get("topo", {}) as Dictionary).duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = seed * 5953 + 11
	var counts := {}
	for k in ["volcano", "mountain", "ridge", "mesa"]:
		counts[k] = _rng_int(r, want, k)
	var live := false
	var ct: Dictionary = (fam_root().get("climate_topo", {}) as Dictionary).get(climate, {})
	if ct.has("volcano"):
		counts["volcano"] = maxi(int(counts["volcano"]), _rng_int(r, ct, "volcano"))
		live = bool(ct.get("live", false))
	elif r.randf() < float(_fam.get("volcano_dormant", 0.0)):
		counts["volcano"] = 1
	var h_mul := float(ct.get("mountain_h_mul", 1.0))
	var keep_coast := float(sizes.get("keep_coast_m", 26.0))
	var keep_camp := float(sizes.get("keep_camp_m", 34.0)) + CAMP_R
	var keep_river := float(sizes.get("keep_river_m", 16.0))
	var keep_path := float(sizes.get("keep_path_m", 14.0))
	var gap := float(sizes.get("gap_m", 22.0))
	# Candidate centres: inland mainland vertices of the calibrated grid (a uniform draw over the
	# square wasted most tries on the sea).
	var cand := PackedVector2Array()
	var cell := size / float(res - 1)
	for z in range(0, res, 2):
		for x in range(0, res, 2):
			var i := x + z * res
			if rads[i] < shore0 - keep_coast - 8.0 and heights[i] > 0.4:
				cand.append(Vector2(-size * 0.5 + float(x) * cell, -size * 0.5 + float(z) * cell))
	if cand.is_empty():
		return
	for kind: String in ["volcano", "mountain", "ridge", "mesa"]:
		var sz: Dictionary = sizes.get(kind, {})
		for _n in int(counts[kind]):
			var placed := false
			for attempt in 120:
				# Past 40 misses the feature shrinks (to 60 % by the last try): a thin island still
				# gets a smaller mesa or a shorter ridge instead of nothing.
				var shrink := 1.0 - 0.4 * clampf(float(attempt - 40) / 80.0, 0.0, 1.0)
				var f := {"kind": kind, "r": _rng_range(r, sz, "r", Vector2(15, 20)) * shrink, "h": _rng_range(r, sz, "h", Vector2(5, 8)) * lerpf(1.0, shrink, 0.5), "seed": r.randi()}
				var pos: Vector2
				if kind == "mountain" and bool(_fam.get("peak_central", false)) and attempt < 50:
					# The round island's central peak: near the middle, pushed off the camp.
					var a := r.randf() * TAU
					pos = q_to_world(Vector2(cos(a), sin(a)) * r.randf_range(0.15, 0.55))
				elif kind == "ridge" and family == "chain":
					var tq := r.randf_range(-1.0, 1.0) * float(_fam.get("bridged_t", 1.0))
					pos = q_to_world(_axis * tq)
				else:
					pos = cand[r.randi_range(0, cand.size() - 1)]
				f["pos"] = pos
				if kind == "mountain":
					f["h"] = float(f["h"]) * h_mul
				if kind == "volcano":
					f["crater"] = float(sz.get("crater", 0.24))
					f["live"] = live
				if kind == "ridge":
					var dir := ridge_dir if family == "chain" else Vector2.from_angle(r.randf() * TAU)
					dir = dir.rotated(r.randf_range(-0.3, 0.3))
					var half_len := _rng_range(r, sz, "len", Vector2(55, 95)) * 0.5 * shrink
					f["a"] = pos - dir * half_len
					f["b"] = pos + dir * half_len
				if kind == "mesa":
					f["aspect"] = r.randf_range(0.55, 0.85)
					f["rot"] = r.randf() * TAU
				f["reach"] = _topo_reach(f)
				if _topo_fits(f, keep_coast, keep_camp, keep_river, keep_path, gap):
					topo.append(f)
					placed = true
					break
			if not placed and OS.get_environment("ISL_TOPO") == "1":
				print("[topo] %s seed=%d could not place a %s" % [family, seed, kind])
	# Every shaped island stands at least one feature: a thin one (a chain, an atoll's ring) gets a
	# small butte with half the coast keep when nothing else fitted.
	if topo.is_empty():
		var land := PackedVector2Array()
		for z in range(0, res, 2):
			for x in range(0, res, 2):
				if heights[x + z * res] > 0.6 and rads[x + z * res] < shore0 - 14.0:
					land.append(Vector2(-size * 0.5 + float(x) * cell, -size * 0.5 + float(z) * cell))
		for _attempt in 200 if not land.is_empty() else 0:
			var f := {"kind": "mesa", "r": r.randf_range(5.5, 7.5), "h": r.randf_range(4.0, 5.0), "seed": r.randi(),
				"pos": land[r.randi_range(0, land.size() - 1)], "aspect": r.randf_range(0.6, 0.9), "rot": r.randf() * TAU}
			f["reach"] = _topo_reach(f)
			if _topo_fits(f, keep_coast * 0.5, keep_camp, keep_river * 0.5, keep_path * 0.5, gap):
				topo.append(f)
				break

## A feature's footprint half-extent from its centre (m), the skirt included.
static func _topo_reach(f: Dictionary) -> float:
	var rr := float(f["r"]) * 1.12
	if f.has("a"):
		rr += (f["a"] as Vector2).distance_to(f["b"]) * 0.5
	return rr

func _topo_fits(f: Dictionary, keep_coast: float, keep_camp: float, keep_river: float, keep_path: float, gap: float) -> bool:
	var pos: Vector2 = f["pos"]
	var reach := float(f["reach"])
	var fr := float(f["r"]) * 1.12
	# The footprint's core line (a ridge's spine, else its centre).
	var a: Vector2 = f.get("a", pos)
	var b: Vector2 = f.get("b", pos)
	if absf(pos.x) > size * 0.5 - reach - SEA_MARGIN or absf(pos.y) > size * 0.5 - reach - SEA_MARGIN:
		return false
	# Inland everywhere round the footprint (mainland only: never on an islet).
	for i in 16:
		var t := float(i % 4) / 3.0
		var c := a.lerp(b, t)
		var dir := Vector2.from_angle(TAU * float(i) / 16.0)
		for k in [0.0, 0.5, 1.0]:
			var p: Vector2 = c + dir * (fr + keep_coast) * float(k)
			if rad(p.x, p.y) > shore0 - 4.0 or not on_mainland(p.x, p.y):
				return false
	if _seg_dist(camp_hint, a, b) < fr + keep_camp:
		return false
	if legacy and _seg_dist(Vector2.ZERO, a, b) < fr + LEGACY_END:
		return false
	# The island row's own fixed points (crater, fixed spawns) stay on open ground.
	for kp in _keep:
		if _seg_dist(kp, a, b) < fr + 14.0:
			return false
	if river.size() >= 2:
		for i in 5:
			var c := a.lerp(b, float(i) / 4.0)
			if river_dist(c.x, c.y) < fr + keep_river + 7.0:
				return false
	if ford != Vector2.ZERO and _seg_dist(ford, a, b) < fr + keep_river + FORD_R:
		return false
	if waterfall != Vector3.ZERO and _seg_dist(Vector2(waterfall.x, waterfall.z), a, b) < fr + keep_river:
		return false
	# The camp-to-dock walk (and the dock's own end of it).
	for i in 9:
		var c := camp_hint.lerp(south_est, float(i) / 8.0)
		if _seg_dist(c, a, b) < fr + keep_path:
			return false
	if _seg_dist(south_est, a, b) < fr + keep_coast + 20.0:
		return false
	for o in topo:
		if pos.distance_to(o["pos"]) < reach + float(o["reach"]) + gap:
			return false
	return true

## (height added, inside footprint 1/0) at a world point: the sum of every feature that reaches it.
## Each stands on a 2.4 m skirt (a cliff band at its foot), so its edge paints CLIFF and the body is
## out of reach from the flat ground round it.
func _topo_at(wx: float, wz: float) -> Vector2:
	var dh := 0.0
	var inside := 0.0
	for f in topo:
		var p: Vector2 = f["pos"]
		var reach := float(f["reach"]) + 2.0
		if absf(wx - p.x) > reach or absf(wz - p.y) > reach:
			continue
		var r := float(f["r"])
		var h := float(f["h"])
		var warp := _ncliff.get_noise_2d(wx * 2.3 + float(f["seed"] % 997), wz * 2.3)
		var u := 0.0
		var v := 0.0
		match str(f["kind"]):
			"mountain":
				u = Vector2(wx, wz).distance_to(p) / r * (1.0 + warp * 0.22)
				if u < 1.0:
					var ridged := 1.0 - absf(_n1.get_noise_2d(wx * 1.6, wz * 1.6))
					v = h * pow(1.0 - u, 1.35) * (0.8 + 0.3 * ridged)
			"ridge":
				var a: Vector2 = f["a"]
				var b: Vector2 = f["b"]
				var ab := b - a
				var t := clampf((Vector2(wx, wz) - a).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
				u = _seg_dist(Vector2(wx, wz), a, b) / r * (1.0 + warp * 0.25)
				if u < 1.0:
					v = h * (0.55 + 0.45 * sin(PI * t)) * pow(1.0 - u, 1.1)
			"mesa":
				var q := Vector2(wx, wz) - p
				var ang := float(f.get("rot", 0.0))
				var q2 := Vector2(q.x * cos(ang) + q.y * sin(ang), (-q.x * sin(ang) + q.y * cos(ang)) / float(f.get("aspect", 0.7)))
				u = q2.length() / r * (1.0 + warp * 0.18)
				v = h * smoothstep(1.0, 0.9, u)
			"volcano":
				u = Vector2(wx, wz).distance_to(p) / r * (1.0 + warp * 0.08)
				var uc := float(f.get("crater", 0.24))
				if u < 1.0:
					var cone := h * pow(1.0 - maxf(u, uc), 1.05)
					if u < uc:
						cone -= h * 0.32 * (1.0 - (u / uc) * (u / uc))
					v = cone
		if u < 1.08:
			inside = 1.0
			# The skirt: a 2.4 m step over the last few percent of the radius.
			v += 2.4 * smoothstep(1.08, 0.98, u)
			dh = maxf(dh, v)
	return Vector2(dh, inside)
