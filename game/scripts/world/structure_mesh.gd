class_name StructureMesh
extends RefCounted
## Procedural stand-in meshes and collision for modular pieces, used whenever a piece's model path in
## structures.json is empty or missing. Chamfered boxes in per-tier patterns (thatch bundles, wood
## planks, stone courses, riveted metal panels) with vertex-colour variation over one triplanar-noise
## material per tier, so pieces read as material, not grey boxes. Built once per (kind, tier, variant)
## and shared by every instance. Local frames follow structures.json's model_contract.

static var _meshes: Dictionary = {}  # "kind|tier|variant" -> ArrayMesh
static var _mats: Dictionary = {}    # tier -> StandardMaterial3D
static var _noise: NoiseTexture2D

const STEP_DEG := 38.0  # foundation skirt / plinth slope: walkable (Player floor_max_angle is 45)

static func mesh_for(kind: StringName, tier: StringName, variant: int = 0) -> ArrayMesh:
	var key := "%s|%s|%d" % [kind, tier, variant]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := _Builder.new(st, tier, hash(key))
	match kind:
		&"foundation": _foundation(b, variant * 0.1)
		&"wall": _wall(b, [Rect2(-1.0, 0.0, 2.0, _h())])
		&"doorway": _doorway(b)
		&"window": _window(b)
		&"door": _door(b)
		&"ceiling": _ceiling(b)
		&"roof": _roof(b)
		&"roof_peak": _roof_peak(b)
		&"pillar": _pillar(b)
		&"stairs": _stairs(b)
		&"ramp": _ramp(b, variant * 0.1)
		_: b.box(Vector3(0, 0.5, 0), Vector3(1, 1, 1), b.tint, 0.05)
	st.set_material(material_for(tier))
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh

## Collision for a piece: [[Shape3D, Transform3D], ...] in the piece's local frame.
static func shapes_for(kind: StringName, variant: int = 0) -> Array:
	var h := _h()
	var t := _t()
	match kind:
		&"foundation":
			var s := maxf(0.2, variant * 0.1)
			var r := s / tan(deg_to_rad(STEP_DEG))
			return [[_hull([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1),
				Vector3(-1 - r, -s, -1 - r), Vector3(1 + r, -s, -1 - r), Vector3(1 + r, -s, 1 + r), Vector3(-1 - r, -s, 1 + r)]), Transform3D()]]
		&"wall":
			return [[_box_shape(Vector3(2.0, h, t)), Transform3D(Basis(), Vector3(0, h * 0.5, 0))]]
		&"doorway", &"window":
			var out: Array = []
			for r in _solid_rects(kind):
				var rr := r as Rect2
				out.append([_box_shape(Vector3(rr.size.x, rr.size.y, t)), Transform3D(Basis(), Vector3(rr.get_center().x, rr.get_center().y, 0))])
			return out
		&"door":
			var o := _opening(&"doorway")
			return [[_box_shape(Vector3(o.x - 0.04, o.y - 0.04, 0.08)), Transform3D(Basis(), Vector3(0, o.y * 0.5, 0))]]
		&"ceiling":
			return [[_box_shape(Vector3(2.0, 0.2, 2.0)), Transform3D(Basis(), Vector3(0, -0.1, 0))]]
		&"roof":
			var rise := _num(&"roof", "rise", 1.25)
			return [[_hull([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(-1, rise, 1), Vector3(1, rise, 1)]), Transform3D()]]
		&"roof_peak":
			var rise2 := _num(&"roof_peak", "rise", 1.25)
			var peak := _num(&"roof_peak", "peak", 0.6)
			return [[_hull([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1),
				Vector3(-1, rise2, -1), Vector3(1, rise2, -1), Vector3(-1, rise2, 1), Vector3(1, rise2, 1),
				Vector3(-1, rise2 + peak, 0), Vector3(1, rise2 + peak, 0)]), Transform3D()]]
		&"pillar":
			return [[_box_shape(Vector3(0.28, h, 0.28)), Transform3D(Basis(), Vector3(0, h * 0.5, 0))]]
		&"stairs":
			return [[_hull([Vector3(-0.9, 0, -1), Vector3(0.9, 0, -1), Vector3(-0.9, 0, 3), Vector3(0.9, 0, 3), Vector3(-0.9, h, 3), Vector3(0.9, h, 3)]), Transform3D()]]
		&"ramp":
			var d := maxf(0.1, variant * 0.1)
			return [[_hull([Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(-1, -d, -1), Vector3(1, -d, -1),
				Vector3(-1, -d - 0.3, -1), Vector3(1, -d - 0.3, -1), Vector3(-1, -d - 0.3, 1), Vector3(1, -d - 0.3, 1)]), Transform3D()]]
	return [[_box_shape(Vector3.ONE), Transform3D(Basis(), Vector3(0, 0.5, 0))]]

static func material_for(tier: StringName) -> StandardMaterial3D:
	if _mats.has(tier):
		return _mats[tier]
	if _noise == null:
		var n := FastNoiseLite.new()
		n.seed = 4127
		n.frequency = 0.045
		n.fractal_octaves = 3
		_noise = NoiseTexture2D.new()
		_noise.width = 128
		_noise.height = 128
		_noise.seamless = true
		_noise.noise = n
		# Grain, not grime: the noise only darkens the vertex colour by up to ~18 %.
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.82, 0.82, 0.82))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		_noise.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _noise  # mapped by the box-projected UVs the builder writes (see _Builder.tri)
	m.uv1_scale = Vector3.ONE * (1.6 if tier == &"stone" else 1.2)
	m.roughness = 0.9
	if tier == &"metal":
		m.metallic = 0.55
		m.roughness = 0.5
	_mats[tier] = m
	return m

# ------------------------------------------------------------------ piece builders

static func _foundation(b: _Builder, depth: float) -> void:
	depth = maxf(0.2, depth)
	var lip := 0.08
	b.box(Vector3(0, -lip * 0.5, 0), Vector3(2.0, lip, 2.0), b.tint, 0.03)
	_deck(b, 0.0)
	# Skirt: a sloped plinth down to the lowest terrain corner, matching the collision slope.
	var top := 1.0
	var y0 := -lip
	var y1 := -depth
	var bot := 1.0 + (depth - lip) / tan(deg_to_rad(STEP_DEG))
	var skirt := b.trim.lerp(Color(0.32, 0.26, 0.2), 0.35)
	for side in 4:
		var basis := Basis(Vector3.UP, side * PI * 0.5)
		var a := basis * Vector3(-top, y0, top)
		var c := basis * Vector3(top, y0, top)
		var d := basis * Vector3(bot, y1, bot)
		var e := basis * Vector3(-bot, y1, bot)
		var n := (basis * Vector3(0, cos(deg_to_rad(STEP_DEG)), sin(deg_to_rad(STEP_DEG)))).normalized()
		b.quad(a, c, d, e, n, b.jit(skirt, 0.06))

## Walkable top surface pattern at height y (foundation deck, ceiling top).
static func _deck(b: _Builder, y: float) -> void:
	match b.tier:
		&"thatch":
			for i in 5:
				var z := -0.8 + i * 0.4
				b.box(Vector3(0, y + 0.01, z), Vector3(1.94, 0.03, 0.36), b.jit(b.tint, 0.08), 0.015)
		&"wood":
			for i in 6:
				var z := -0.835 + i * 0.334
				b.box(Vector3(0, y + 0.012, z), Vector3(1.96, 0.035, 0.31), b.jit(b.tint, 0.1), 0.012)
		&"stone":
			for i in 3:
				for j in 3:
					b.box(Vector3(-0.66 + i * 0.66, y + 0.015, -0.66 + j * 0.66), Vector3(0.62, 0.04, 0.62), b.jit(b.tint, 0.1), 0.03)
		&"metal":
			b.box(Vector3(0, y + 0.01, 0), Vector3(1.8, 0.03, 1.8), b.jit(b.tint, 0.04), 0.01)
			for c in [Vector3(-0.85, 0, -0.85), Vector3(0.85, 0, -0.85), Vector3(0.85, 0, 0.85), Vector3(-0.85, 0, 0.85)]:
				b.box(c + Vector3(0, y + 0.03, 0), Vector3(0.06, 0.03, 0.06), b.trim, 0.01)

static func _wall(b: _Builder, rects: Array) -> void:
	var t := _t()
	for r in rects:
		_fill(b, r as Rect2, t)
	# End posts finish every corner where two walls meet; a sill and a cap band mark each storey.
	for x in [-0.96, 0.96]:
		b.box(Vector3(x, _h() * 0.5, 0), Vector3(0.1, _h(), t + 0.05), b.trim if b.tier != &"stone" else b.jit(b.tint, 0.05).darkened(0.08), 0.025)
	b.box(Vector3(0, _h() - 0.07, 0), Vector3(2.0, 0.14, t + 0.1), b.trim, 0.03)
	for r in rects:
		var rr := r as Rect2
		if rr.position.y < 0.01:  # sill only under the solid parts, not across a doorway
			b.box(Vector3(rr.get_center().x, 0.06, 0), Vector3(rr.size.x, 0.12, t + 0.08), b.trim.darkened(0.15), 0.02)

static func _doorway(b: _Builder) -> void:
	_wall(b, _solid_rects(&"doorway"))
	var o := _opening(&"doorway")
	var t := _t()
	for x in [-o.x * 0.5 - 0.04, o.x * 0.5 + 0.04]:
		b.box(Vector3(x, o.y * 0.5, 0), Vector3(0.09, o.y, t + 0.06), b.trim, 0.02)
	b.box(Vector3(0, o.y + 0.05, 0), Vector3(o.x + 0.2, 0.11, t + 0.06), b.trim, 0.02)
	b.box(Vector3(0, 0.02, 0), Vector3(o.x, 0.04, t), b.trim.darkened(0.2), 0.01)

static func _window(b: _Builder) -> void:
	_wall(b, _solid_rects(&"window"))
	var o := _opening(&"window")  # width, height, sill
	var t := _t()
	var y0: float = o.z
	var y1: float = o.z + o.y
	b.box(Vector3(0, y0 - 0.03, 0), Vector3(o.x + 0.2, 0.07, t + 0.12), b.trim, 0.02)
	b.box(Vector3(0, y1 + 0.03, 0), Vector3(o.x + 0.12, 0.07, t + 0.06), b.trim, 0.02)
	for x in [-o.x * 0.5 - 0.03, o.x * 0.5 + 0.03]:
		b.box(Vector3(x, (y0 + y1) * 0.5, 0), Vector3(0.06, o.y, t + 0.06), b.trim, 0.015)
	b.box(Vector3(0, (y0 + y1) * 0.5, 0), Vector3(0.04, o.y, 0.05), b.trim, 0.01)
	b.box(Vector3(0, (y0 + y1) * 0.5, 0), Vector3(o.x, 0.04, 0.05), b.trim, 0.01)

## Door leaf, built around its hinge (x = 0 is the hinge line; the leaf spans +x).
static func _door(b: _Builder) -> void:
	var o := _opening(&"doorway")
	var w := o.x - 0.06
	var hh := o.y - 0.04
	match b.tier:
		&"thatch":
			for i in 5:
				b.box(Vector3(w * 0.5, 0.25 + i * 0.4, 0), Vector3(w, 0.38, 0.07), b.jit(b.tint, 0.08), 0.02)
			b.box(Vector3(w * 0.5, hh * 0.5, 0.04), Vector3(0.05, hh, 0.02), b.trim, 0.008)
		&"wood", &"stone":
			var n := 5
			for i in n:
				var pw := w / n
				b.box(Vector3(pw * (i + 0.5), hh * 0.5 + 0.02, 0), Vector3(pw - 0.015, hh, 0.07), b.jit(Color(0.55, 0.37, 0.2) if b.tier == &"stone" else b.tint, 0.08), 0.015)
			for y in [0.45, hh - 0.45]:
				b.box(Vector3(w * 0.5, y, 0.045), Vector3(w - 0.08, 0.12, 0.03), b.trim if b.tier == &"wood" else Color(0.32, 0.33, 0.35), 0.01)
		&"metal":
			b.box(Vector3(w * 0.5, hh * 0.5 + 0.02, 0), Vector3(w, hh, 0.07), b.jit(b.tint, 0.04), 0.02)
			for y in [0.3, hh * 0.5, hh - 0.3]:
				b.box(Vector3(w * 0.5, y, 0.04), Vector3(w - 0.06, 0.09, 0.025), b.trim, 0.008)
	b.box(Vector3(w - 0.12, 1.0, 0.06), Vector3(0.05, 0.14, 0.05), Color(0.2, 0.18, 0.16), 0.01)

static func _ceiling(b: _Builder) -> void:
	b.box(Vector3(0, -0.1, 0), Vector3(2.0, 0.2, 2.0), b.jit(b.tint, 0.04).darkened(0.05), 0.03)
	_deck(b, 0.0)
	for z in [-0.55, 0.55]:
		b.box(Vector3(0, -0.26, z), Vector3(2.0, 0.14, 0.16), b.trim, 0.025)

static func _roof(b: _Builder) -> void:
	var rise := _num(&"roof", "rise", 1.25)
	_slope(b, Vector3(0, 0, -1), Vector3(0, rise, 1), 0.28)
	_gable(b, PackedVector2Array([Vector2(-1, 0), Vector2(1, 0), Vector2(1, rise)]))

static func _roof_peak(b: _Builder) -> void:
	var rise := _num(&"roof_peak", "rise", 1.25)
	var peak := _num(&"roof_peak", "peak", 0.6)
	_slope(b, Vector3(0, rise, -1), Vector3(0, rise + peak, 0), 0.0)
	_slope(b, Vector3(0, rise, 1), Vector3(0, rise + peak, 0), 0.0)
	b.box(Vector3(0, rise + peak + 0.04, 0), Vector3(2.04, 0.12, 0.16), b.trim, 0.03)
	_gable(b, PackedVector2Array([Vector2(-1, 0), Vector2(1, 0), Vector2(1, rise), Vector2(0, rise + peak), Vector2(-1, rise)]))

## A roof surface from the low edge `lo` up to the high edge `hi` (both at x = 0, spanning x +-1),
## covered in tier rows (thatch bundles, wood shingles, slate, metal ribs); `eave` overhangs the low edge.
static func _slope(b: _Builder, lo: Vector3, hi: Vector3, eave: float) -> void:
	var up := (hi - lo)
	var length := up.length() + eave
	var dir := up.normalized()
	var start := lo - dir * eave
	var ny := dir.cross(Vector3.RIGHT).normalized()
	if ny.y < 0.0:
		ny = -ny  # the box is symmetric, so a mirrored basis is fine; "up" must face the sky
	var basis := Basis(Vector3.RIGHT, ny, dir)
	var rows := 4 if b.tier == &"thatch" else (6 if b.tier == &"wood" else (7 if b.tier == &"stone" else 1))
	var under := b.trim.darkened(0.15)
	b.oriented_box(start + dir * length * 0.5 - basis.y * 0.06, basis, Vector3(2.1, 0.08, length), under, 0.02)
	if b.tier == &"metal":
		b.oriented_box(start + dir * length * 0.5, basis, Vector3(2.12, 0.05, length), b.jit(b.tint, 0.04), 0.015)
		for i in 8:
			b.oriented_box(start + dir * length * 0.5 + basis.x * (-0.92 + i * 0.263) + basis.y * 0.04, basis, Vector3(0.05, 0.05, length), b.trim, 0.01)
		return
	var row := length / rows
	for i in rows:
		var c := start + dir * (row * (i + 0.5)) + basis.y * (0.02 + 0.015 * float(i % 2))
		if b.tier == &"stone":
			var tiles := 6
			for j in tiles:
				var x := -1.05 + (2.1 / tiles) * (j + 0.5) + (0.08 if i % 2 else 0.0)
				b.oriented_box(c + basis.x * clampf(x, -0.9, 0.9), basis, Vector3(2.1 / tiles - 0.03, 0.06, row * 1.15), b.jit(b.tint.darkened(0.12), 0.1), 0.015)
		else:
			# Roof courses sit a shade toward the trim, alternating, so they read as rows in full sun.
			var shade := b.tint.lerp(b.trim, 0.18).darkened(0.1 * float(i % 2))
			b.oriented_box(c, basis, Vector3(2.14, 0.1 if b.tier == &"thatch" else 0.05, row * 1.25), b.jit(shade, 0.09), 0.03 if b.tier == &"thatch" else 0.012)

## Gable end walls at x = +-1: `poly` is (z, y) in the piece frame.
static func _gable(b: _Builder, poly: PackedVector2Array) -> void:
	var col := b.jit(b.tint.lerp(b.trim, 0.35), 0.03)
	for x in [-0.98, 0.98]:
		b.prism_x(poly, x - 0.04, x + 0.04, col)

static func _pillar(b: _Builder) -> void:
	var h := _h()
	b.box(Vector3(0, 0.08, 0), Vector3(0.36, 0.16, 0.36), b.trim, 0.03)
	b.box(Vector3(0, h * 0.5, 0), Vector3(0.26, h - 0.2, 0.26), b.jit(b.tint, 0.05) if b.tier != &"thatch" else b.trim.lightened(0.15), 0.04)
	b.box(Vector3(0, h - 0.07, 0), Vector3(0.34, 0.14, 0.34), b.trim, 0.03)

static func _stairs(b: _Builder) -> void:
	var h := _h()
	var steps := 10
	var run := 4.0 / steps
	var rise := h / steps
	for i in steps:
		var z := -1.0 + run * (i + 0.5)
		var y := rise * (i + 1)
		b.box(Vector3(0, y - rise * 0.5, z), Vector3(1.7, rise, run + 0.02), b.jit(b.tint, 0.08), 0.02)
	for x in [-0.88, 0.88]:
		var poly := PackedVector2Array([Vector2(-1.0, 0), Vector2(3.0, h - 0.05), Vector2(3.0, h + 0.12), Vector2(-1.0, 0.17)])
		b.prism_x(poly, x - 0.05, x + 0.05, b.trim)

static func _ramp(b: _Builder, drop: float) -> void:
	drop = maxf(0.1, drop)
	var poly := PackedVector2Array([Vector2(1, 0), Vector2(-1, -drop), Vector2(-1, -drop - 0.25), Vector2(1, -drop - 0.25)])
	b.prism_x(poly, -0.95, 0.95, b.trim.darkened(0.1))
	var dir := Vector3(0, drop, 2.0).normalized()
	var basis := Basis(Vector3.RIGHT, Vector3(0, 2.0, -drop).normalized(), dir)
	var length := Vector3(0, drop, 2.0).length()
	for i in 5:
		var c := Vector3(0, -drop, -1) + dir * (length / 5.0 * (i + 0.5)) + basis.y * 0.025
		b.oriented_box(c, basis, Vector3(1.9, 0.05, length / 5.0 - 0.03), b.jit(b.tint, 0.1), 0.012)

## Tier pattern over one solid wall rectangle (x along the wall, y up), thickness t.
static func _fill(b: _Builder, r: Rect2, t: float) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var cx := (x0 + x1) * 0.5
	var w := x1 - x0
	match b.tier:
		&"thatch":
			var n := maxi(1, roundi((y1 - y0) / 0.42))
			var bh := (y1 - y0) / n
			for i in n:
				var y := y0 + bh * (i + 0.5)
				b.box(Vector3(cx, y, 0), Vector3(w, bh - 0.02, t * 0.9), b.jit(b.tint, 0.09), 0.05)
				b.box(Vector3(cx, y, 0), Vector3(w + 0.005, 0.05, t * 0.98), b.trim, 0.01)
		&"wood":
			var n2 := maxi(1, roundi((y1 - y0) / 0.32))
			var ph := (y1 - y0) / n2
			for i in n2:
				b.box(Vector3(cx, y0 + ph * (i + 0.5), 0), Vector3(w, ph - 0.025, t * 0.82), b.jit(b.tint, 0.1), 0.025)
			b.box(Vector3(cx, (y0 + y1) * 0.5, 0), Vector3(w, y1 - y0, t * 0.6), b.trim.darkened(0.3), 0.0)
		&"stone":
			b.box(Vector3(cx, (y0 + y1) * 0.5, 0), Vector3(w, y1 - y0, t * 0.7), b.tint.darkened(0.45), 0.0)
			var rows := maxi(1, roundi((y1 - y0) / 0.31))
			var rh := (y1 - y0) / rows
			for i in rows:
				var x := x0
				var first := 0.28 if i % 2 else 0.5
				while x < x1 - 0.01:
					var bw := minf(first, x1 - x)
					first = 0.5 + b.rng.randf_range(-0.08, 0.1)
					if x1 - (x + bw) < 0.16:
						bw = x1 - x
					b.box(Vector3(x + bw * 0.5, y0 + rh * (i + 0.5), 0), Vector3(bw - 0.03, rh - 0.03, t * 0.95), b.jit(b.tint, 0.11), 0.035)
					x += bw
		&"metal":
			b.box(Vector3(cx, (y0 + y1) * 0.5, 0), Vector3(w, y1 - y0, t * 0.7), b.jit(b.tint, 0.04), 0.02)
			var y := y0 + 0.3
			while y < y1 - 0.15:
				b.box(Vector3(cx, y, 0), Vector3(w, 0.08, t * 0.85), b.trim, 0.012)
				var x2 := x0 + 0.12
				while x2 < x1 - 0.08:
					b.box(Vector3(x2, y, 0), Vector3(0.035, 0.035, t * 0.95), b.trim.lightened(0.25), 0.008)
					x2 += 0.3
				y += 0.62

# ------------------------------------------------------------------ data + shapes

## Solid parts of a wall with an opening, as rectangles in (x, y) wall space.
static func _solid_rects(kind: StringName) -> Array:
	var h := _h()
	var o := _opening(kind)
	var hw: float = o.x * 0.5
	if kind == &"window":
		var y0: float = o.z
		var y1: float = o.z + o.y
		return [Rect2(-1.0, 0.0, 1.0 - hw, h), Rect2(hw, 0.0, 1.0 - hw, h), Rect2(-hw, 0.0, o.x, y0), Rect2(-hw, y1, o.x, h - y1)]
	return [Rect2(-1.0, 0.0, 1.0 - hw, h), Rect2(hw, 0.0, 1.0 - hw, h), Rect2(-hw, o.y, o.x, h - o.y)]

## Opening size: doorway (width, height, 0), window (width, height, sill height).
static func _opening(kind: StringName) -> Vector3:
	var v: Variant = StructurePiece.piece_def(kind).get("opening", [])
	var a: Array = v if v is Array else []
	if kind == &"window":
		return Vector3(float(a[0]) if a.size() > 0 else 0.9, float(a[1]) if a.size() > 1 else 0.8, float(a[2]) if a.size() > 2 else 1.0)
	return Vector3(float(a[0]) if a.size() > 0 else 1.1, float(a[1]) if a.size() > 1 else 2.1, 0.0)

static func _h() -> float:
	return float(StructurePiece.defs().get("storey_m", 2.5))

static func _t() -> float:
	return float(StructurePiece.defs().get("wall_thickness_m", 0.2))

static func _num(kind: StringName, key: String, fallback: float) -> float:
	return float(StructurePiece.piece_def(kind).get(key, fallback))

static func _box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s

static func _hull(points: Array) -> ConvexPolygonShape3D:
	var s := ConvexPolygonShape3D.new()
	s.points = PackedVector3Array(points)
	return s

## Emits flat-shaded, vertex-coloured triangles with clockwise front faces (Godot's convention).
class _Builder:
	var st: SurfaceTool
	var tier: StringName
	var tint: Color
	var trim: Color
	var rng := RandomNumberGenerator.new()

	func _init(p_st: SurfaceTool, p_tier: StringName, seed_v: int) -> void:
		st = p_st
		tier = p_tier
		var td := StructurePiece.tier_def(p_tier)
		tint = Color.from_string(str(td.get("tint", "#9a6a3c")), Color(0.6, 0.42, 0.24))
		trim = Color.from_string(str(td.get("trim", "#4f3520")), Color(0.3, 0.2, 0.12))
		rng.seed = seed_v

	func jit(c: Color, amount: float) -> Color:
		var k := rng.randf_range(-amount, amount)
		return Color(clampf(c.r + k, 0, 1), clampf(c.g + k * 0.9, 0, 1), clampf(c.b + k * 0.8, 0, 1))

	func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
		if (b - a).cross(c - a).dot(n) > 0.0:
			var tmp := b
			b = c
			c = tmp
		var an := n.abs()  # box projection: the plane the face is most parallel to
		for p in [a, b, c]:
			st.set_color(col)
			st.set_normal(n)
			st.set_uv(Vector2(p.z, p.y) if an.x >= an.y and an.x >= an.z else (Vector2(p.x, p.z) if an.y >= an.z else Vector2(p.x, p.y)))
			st.add_vertex(p)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
		tri(a, b, c, n, col)
		tri(a, c, d, n, col)

	func box(center: Vector3, size: Vector3, col: Color, bevel: float) -> void:
		oriented_box(center, Basis(), size, col, bevel)

	## Chamfered box: 6 inset faces, 12 edge bevels and 8 corner facets.
	func oriented_box(center: Vector3, basis: Basis, size: Vector3, col: Color, bevel: float) -> void:
		var h := size * 0.5
		var bv := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
		var ax: Array[Vector3] = [basis.x.normalized(), basis.y.normalized(), basis.z.normalized()]
		var he: Array[float] = [h.x, h.y, h.z]
		var shade := [0.0, 0.06, -0.04]  # top faces a touch lighter, sides darker: reads at iso angles
		for a in 3:
			var u := (a + 1) % 3
			var v := (a + 2) % 3
			for s in [-1.0, 1.0]:
				var n: Vector3 = ax[a] * s
				var c0: Vector3 = center + n * he[a]
				var du: Vector3 = ax[u] * (he[u] - bv)
				var dv: Vector3 = ax[v] * (he[v] - bv)
				var fc := col.lightened(shade[1]) if (a == 1 and s > 0.0) else (col.darkened(0.08) if a == 1 else col)
				quad(c0 - du - dv, c0 + du - dv, c0 + du + dv, c0 - du + dv, n, fc)
		if bv <= 0.0005:
			return
		for a in 3:
			var b2 := (a + 1) % 3
			var c := (a + 2) % 3
			for sa in [-1.0, 1.0]:
				for sb in [-1.0, 1.0]:
					var p1: Vector3 = center + ax[a] * sa * he[a] + ax[b2] * sb * (he[b2] - bv)
					var p2: Vector3 = center + ax[a] * sa * (he[a] - bv) + ax[b2] * sb * he[b2]
					var dc: Vector3 = ax[c] * (he[c] - bv)
					var n2: Vector3 = (ax[a] * sa + ax[b2] * sb).normalized()
					quad(p1 - dc, p1 + dc, p2 + dc, p2 - dc, n2, col)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var px: Vector3 = center + ax[0] * sx * he[0] + ax[1] * sy * (he[1] - bv) + ax[2] * sz * (he[2] - bv)
					var py: Vector3 = center + ax[0] * sx * (he[0] - bv) + ax[1] * sy * he[1] + ax[2] * sz * (he[2] - bv)
					var pz: Vector3 = center + ax[0] * sx * (he[0] - bv) + ax[1] * sy * (he[1] - bv) + ax[2] * sz * he[2]
					tri(px, py, pz, (ax[0] * sx + ax[1] * sy + ax[2] * sz).normalized(), col)

	## A polygon in the (z, y) plane extruded along x from x0 to x1 (gable ends, stair stringers).
	func prism_x(poly: PackedVector2Array, x0: float, x1: float, col: Color) -> void:
		var n := poly.size()
		var centroid := Vector2.ZERO
		for p in poly:
			centroid += p
		centroid /= float(n)
		for i in range(1, n - 1):
			for x in [x0, x1]:
				tri(Vector3(x, poly[0].y, poly[0].x), Vector3(x, poly[i].y, poly[i].x), Vector3(x, poly[i + 1].y, poly[i + 1].x), Vector3(signf(x - (x0 + x1) * 0.5), 0, 0), col)
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			var edge := b - a
			var out := Vector2(edge.y, -edge.x).normalized()
			if out.dot((a + b) * 0.5 - centroid) < 0.0:
				out = -out
			quad(Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x), Vector3(0, out.y, out.x), col.darkened(0.05))
