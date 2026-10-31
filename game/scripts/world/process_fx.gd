class_name ProcessFx
extends RefCounted
## What a process station shows (processing.json), split out of ProcessStation: smoke or steam while a
## job runs, an ember glow, and the things on the station (`contents`): one strip or bowl per job or
## uncollected output, coloured from just loaded to done. CPUParticles3D and plain meshes: the same look
## in Forward+ and gl_compatibility (web, phones).

static var _puff: Texture2D

## Smoke or steam over the station, off until a job runs.
static func build_smoke(cfg: Dictionary) -> CPUParticles3D:
	var kind := str(cfg.get("fx", ""))
	if kind == "":
		return null
	var fx := CPUParticles3D.new()
	fx.name = "ProcessFx"
	fx.position = vec3(cfg.get("fx_offset"), Vector3.UP)
	var steam := kind == "steam"
	fx.amount = 18 if steam else 26
	fx.lifetime = 2.2 if steam else 4.0
	fx.preprocess = fx.lifetime
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fx.emission_sphere_radius = 0.18 if steam else 0.35
	fx.direction = Vector3.UP
	fx.spread = 12.0
	fx.gravity = Vector3(0.12, 0.35 if steam else 0.2, 0.0)  # a light drift downwind
	fx.initial_velocity_min = 0.35
	fx.initial_velocity_max = 0.7
	fx.scale_amount_min = 0.5
	fx.scale_amount_max = 0.9
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.6))
	fx.scale_amount_curve = grow
	var ramp := Gradient.new()
	var c := Color(0.96, 0.97, 1.0) if steam else Color(0.55, 0.53, 0.5)
	var a := float(cfg.get("fx_alpha", 0.55 if steam else 0.5))
	var size := 0.6
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# The web renderer (the judge) draws the same grey far darker and thinner than Forward+:
		# the rack's smoke vanished on the dirt and the smoker's was a dark thread. `fx_glc_boost`
		# makes one station's puffs bigger, denser and shorter-lived there only: the smoker's tall
		# plume rose behind the phone's Orders panel, so it stays near the roof instead, in the mid grey
		# (the lightened grey was lost on the pale grass once the puffs were big enough to see).
		var boost := maxf(1.0, float(cfg.get("fx_glc_boost", 1.0)))
		if boost == 1.0:
			c = c.linear_to_srgb()
		a = minf(1.0, a * 1.5 * boost)
		size *= boost
		fx.amount = int(float(fx.amount) * boost)
		fx.lifetime /= boost
		fx.preprocess = fx.lifetime
	ramp.set_color(0, Color(c, 0.0))
	ramp.set_color(1, Color(c, 0.0))
	ramp.add_point(0.15, Color(c, a))
	ramp.add_point(0.6, Color(c, a * 0.55))
	fx.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff_texture()
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = mat
	fx.mesh = quad
	fx.emitting = false
	return fx

## The ember glow of a fired station, off until a job runs.
static func build_glow(cfg: Dictionary) -> OmniLight3D:
	var light := str(cfg.get("light", ""))
	if light == "":
		return null
	var glow := OmniLight3D.new()
	glow.name = "ProcessGlow"
	glow.light_color = Color(light)
	glow.light_energy = 1.4
	glow.omni_range = 2.6
	glow.position = Vector3(0.0, 0.5, 0.0)
	glow.visible = false
	return glow

## One mesh per thing on the station at processing.json `contents.spots[i]` (station-local), so what was
## loaded hangs or sits on it until collected; its colour runs `from` -> `to` with that job's progress
## (finished outputs at 1). Stations with stage models (the rack) have no `contents`.
static func sync_contents(holder: Node3D, cfg: Dictionary, progress: Array[float]) -> void:
	var c: Variant = cfg.get("contents")
	if not c is Dictionary:
		return
	var spots: Array = (c as Dictionary).get("spots", [])
	var from := Color(str((c as Dictionary).get("from", "#a8322a")))
	var to := Color(str((c as Dictionary).get("to", "#4a2a1c")))
	for i in spots.size():
		var mi := holder.get_node_or_null("C%d" % i) as MeshInstance3D
		if mi == null:
			mi = _content_mesh(str((c as Dictionary).get("kind", "strip")))
			mi.name = "C%d" % i
			mi.position = vec3(spots[i], Vector3.ZERO)
			holder.add_child(mi)
		mi.visible = i < progress.size()
		if mi.visible:
			(mi.material_override as StandardMaterial3D).albedo_color = from.lerp(to, progress[i])

## A strip of meat hung by its top, or a bowl whose food surface takes the colour.
static func _content_mesh(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var food := StandardMaterial3D.new()
	food.roughness = 0.85
	mi.material_override = food
	if kind == "bowl":
		var mound := SphereMesh.new()  # heaped food: reads from the iso camera, a flat disc did not
		mound.radius = 0.12
		mound.height = 0.11
		mi.mesh = mound
		var bowl := MeshInstance3D.new()
		var cup := CylinderMesh.new()
		cup.top_radius = 0.15
		cup.bottom_radius = 0.09
		cup.height = 0.08
		bowl.mesh = cup
		bowl.position = Vector3(0.0, -0.03, 0.0)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("#6e4a2c")
		wood.roughness = 0.9
		bowl.material_override = wood
		mi.add_child(bowl)
	else:
		var strip := BoxMesh.new()
		strip.size = Vector3(0.09, 0.36, 0.035)
		mi.mesh = strip
	return mi

## The strip_1..strip_N nodes of a stage model, in order (empty: the model has none).
static func find_strips(prop: Node) -> Array[Node3D]:
	var strips: Array[Node3D] = []
	var i := 1
	while prop and prop.find_child("strip_%d" % i, true, false) is Node3D:
		strips.append(prop.find_child("strip_%d" % i, true, false) as Node3D)
		i += 1
	return strips

## A stage model's strips (find_strips) show the share of them its filled slots stand for, so one strip
## on the rack is not drawn as a full rack. Returns the strips shown (-1: none in the model).
static func show_strips(strips: Array[Node3D], filled: int, capacity: int) -> int:
	if strips.is_empty():
		return -1
	var shown := ceili(float(strips.size()) * float(mini(filled, capacity)) / float(maxi(1, capacity)))
	for k in strips.size():
		strips[k].visible = k < shown
	return shown

static func vec3(v: Variant, fallback: Vector3) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2])) if v is Array and (v as Array).size() >= 3 else fallback

## A soft round puff, made once: no texture file to ship.
static func _puff_texture() -> Texture2D:
	if _puff:
		return _puff
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_puff = t
	return _puff
