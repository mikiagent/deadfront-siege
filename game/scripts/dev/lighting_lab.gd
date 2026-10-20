extends Node3D
## Lighting acceptance (W1-LIGHT): temperate_25 under the shared WorldLighting. Measures the
## shadows of a 1x3x1 box, a 0.3 m pole and the survivor (all shadow-only) on lit grey ground,
## at the desktop atlas and again at the 1024 mobile atlas, then the camp view's blown pixels
## and ground luminance; prints [lighting] lines and exits 0 on PASS, 1 on FAIL, 2 when run
## headless (nothing is measured; --allow-skip opts out).
## --light-shots=<dir> also saves the frames plus night (tod 0.0) and dusk (tod 0.73) views.

## ASSUMPTION: mid-morning (sun ~51 deg up) is the measured daylight; the spec names no time.
const TOD := 0.42
const MAX_SHADOW_RATIO := 0.75
## Character-scale casters: the owner's "invisible shadows" were these, not the box.
const MAX_THIN_RATIO := 0.8
## project.godot's directional_shadow/size.mobile; desktop runs never see it otherwise.
const MOBILE_ATLAS := 1024
const WATCHDOG_S := 120.0
const MAX_BLOWN_PCT := 1.0
const GROUND_LUM := Vector2(0.25, 0.55)
## Camp dirt within 20 % of the grass beside it (Durango: trodden earth, not pale sand).
const DISC_RATIO := Vector2(0.8, 1.2)
## At midnight the compat renderer's moon shadow made the pads near-black halos (0.087 vs 0.241 in
## Forward+). A pad may read darker than the grass beside it, but not below 0.6x of it.
const NIGHT_DISC_RATIO := 0.6
## ASSUMPTION: terrain 8-10 m out from the fire at midnight reads at >= 0.05 mean luminance.
const MIN_NIGHT_LUM := 0.05
const NIGHT_FROM_M := 8.0

var _player: Player
var _cam: IsoCamera
var _out := ""
var _tag := ""

func _ready() -> void:
	Game.time_of_day = TOD
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 19.0
	_cam.distance = 28.0
	(kit["nav"] as Node).visible = false
	World.harvested.clear()
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	_cam._target = _player
	_cam._snap()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--light-shots="):
			_out = a.substr(14)
	_tag = "compat" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "fwd"
	print("[boot] lab=lighting_lab")
	# Fail closed: a broken await or missing node must not leave the lab running forever.
	get_tree().create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("[lighting] FAIL watchdog: no verdict after %d s" % int(WATCHDOG_S))
		get_tree().quit(1))
	if DisplayServer.get_name() == "headless":
		# Headless measures nothing: exiting 0 let a CI gate pass without a single pixel read.
		# --allow-skip is for a job that knowingly runs the lab without a display.
		if "--allow-skip" in OS.get_cmdline_user_args():
			print("[lighting] SKIP headless renders no pixels (--allow-skip)")
			get_tree().quit.call_deferred(0)
		else:
			print("[lighting] FAIL headless cannot render; run windowed or pass --allow-skip")
			get_tree().quit.call_deferred(2)
		return
	_run.call_deferred()

func _run() -> void:
	# Measurement frames show the 3D view only: HUD text would count as blown pixels.
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	TouchControls.visible = false
	await _settle()
	var light := get_tree().get_first_node_in_group(&"world_lighting") as WorldLighting
	if light == null or light.sun == null:
		print("[lighting] FAIL no WorldLighting")
		get_tree().quit(1)
		return
	print("[lighting] renderer=%s tod=%.2f sun_energy=%.2f sun_rot=%s exposure=%.2f" % [_tag, Game.time_of_day,
		light.sun.light_energy, light.sun.rotation_degrees, light.world_env.environment.tonemap_exposure])
	var r := await _shadow_ratios(light.sun, "desk")
	var desk_atlas := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096))
	RenderingServer.directional_shadow_atlas_set_size(MOBILE_ATLAS, true)
	var rm := await _shadow_ratios(light.sun, "mobile")
	RenderingServer.directional_shadow_atlas_set_size(desk_atlas, true)
	var ratio: float = r["box"]
	var img := await _frame("camp")
	var blown := _blown_pct(img)
	var ground := _ground_lum(img)
	var disc := _disc_vs_grass(img)
	print("[lighting] shadow_ratio=%.3f" % ratio)
	print("[lighting] thin desk atlas=%d pole=%.3f survivor=%.3f" % [desk_atlas, r["pole"], r["survivor"]])
	print("[lighting] mobile atlas=%d box=%.3f pole=%.3f survivor=%.3f" % [MOBILE_ATLAS, rm["box"], rm["pole"], rm["survivor"]])
	print("[lighting] blown_pct=%.3f" % blown)
	print("[lighting] ground_lum=%.3f" % ground)
	print("[lighting] disc_lum=%.3f grass_lum=%.3f disc_ratio=%.2f" % [disc.x, disc.y, disc.x / maxf(disc.y, 0.0001)])
	# Night must stay readable past the bonfire's reach on a phone screen.
	var night_img := await _shot_at(0.0, "night")
	var night := _ground_lum(night_img, NIGHT_FROM_M)
	print("[lighting] night_lum=%.3f" % night)
	# The dirt pads must not read as black holes on the web renderer at night (lv-dirt-18): the
	# compat moon shadow plus the weak compat fire made them 0.087 vs 0.241 on Forward+.
	var night_disc := _disc_vs_grass(night_img)
	var night_ratio := night_disc.x / maxf(night_disc.y, 0.0001)
	print("[lighting] night_disc_lum=%.3f night_grass_lum=%.3f night_disc_ratio=%.2f (want >= %.2f)" % [night_disc.x, night_disc.y, night_ratio, NIGHT_DISC_RATIO])
	# Grass hue drift between the renderers (Forward+ olive vs compat lime); printed so it is visible.
	var hue := _ground_hue(img)
	print("[lighting] grass_hue_deg=%.0f sat=%.2f renderer=%s" % [hue.x, hue.y, _tag])
	if _out != "":
		await _shot_at(0.73, "dusk")
	var thin_ok := maxf(maxf(r["pole"], r["survivor"]), maxf(rm["pole"], rm["survivor"])) <= MAX_THIN_RATIO
	var disc_ratio := disc.x / maxf(disc.y, 0.0001)
	var disc_ok := disc_ratio >= DISC_RATIO.x and disc_ratio <= DISC_RATIO.y
	var night_disc_ok := night_ratio >= NIGHT_DISC_RATIO
	var ok: bool = ratio <= MAX_SHADOW_RATIO and rm["box"] <= MAX_SHADOW_RATIO and thin_ok and disc_ok and night_disc_ok and night >= MIN_NIGHT_LUM and blown <= MAX_BLOWN_PCT and ground >= GROUND_LUM.x and ground <= GROUND_LUM.y
	print("[lighting] %s" % ("PASS" if ok else "FAIL (box <= %.2f at both atlases, pole and survivor <= %.2f, disc/grass %.1f-%.1f, night disc/grass >= %.2f, night_lum >= %.2f, blown_pct <= %.1f, ground_lum %.2f-%.2f)" % [
		MAX_SHADOW_RATIO, MAX_THIN_RATIO, DISC_RATIO.x, DISC_RATIO.y, NIGHT_DISC_RATIO, MIN_NIGHT_LUM, MAX_BLOWN_PCT, GROUND_LUM.x, GROUND_LUM.y]))
	get_tree().quit(0 if ok else 1)

## Waits out shader compiles (the web renderer can draw blank frames for seconds): at least
## 3 s, then until the coarse frame mean stops moving, at most 20 s.
func _settle() -> void:
	await get_tree().create_timer(3.0).timeout
	var prev := -1.0
	for _i in 34:
		var m := _coarse_mean(await _frame(""))
		if m > 0.05 and absf(m - prev) < 0.004:
			return
		prev = m
		await get_tree().create_timer(0.5).timeout

func _frame(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if label != "" and _out != "":
		img.save_png("%s/lighting_%s_%s.png" % [_out, label, _tag])
	return img

## The verifier's probe, widened to thin casters: grey plane, shadow-only 1x3x1 box, 0.3 m x
## 1.8 m pole and the survivor made shadow-only (so its body cannot cover its own shadow on
## screen). Each ratio is the darkest patch along the cast shadow over two lit points beside
## it. Lower = more visible shadow.
func _shadow_ratios(sun: DirectionalLight3D, label: String) -> Dictionary:
	var rt := World.runtime as IslandRuntime
	# The survivor stays where the game put him (at the camp, feet ~0.9 m up, where his shadow
	# fell into another split and vanished); the plane sits above the 0.08 m dirt discs so
	# every patch is measured on the same grey.
	var p := _player.global_position
	var y := rt.surface_y(p.x, p.z) + 0.15
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(18.0, 18.0)
	plane.mesh = pm
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.35, 0.35)
	plane.material_override = grey
	add_child(plane)
	plane.global_position = Vector3(p.x - 2.0, y, p.z)
	var casters := {"box": [Vector3(p.x - 5.0, y, p.z + 1.0), Vector3(1.0, 3.0, 1.0)],
		"pole": [Vector3(p.x - 3.0, y, p.z - 3.0), Vector3(0.3, 1.8, 0.3)],
		"survivor": [p, Vector3(0.0, 1.7, 0.0)]}
	var props: Array[Node] = []
	for k in ["box", "pole"]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = casters[k][1]
		mi.mesh = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(mi)
		mi.global_position = casters[k][0] + Vector3(0, bm.size.y * 0.5, 0)
		props.append(mi)
	var keep := {}
	for g in _player.find_children("*", "GeometryInstance3D", true, false):
		keep[g] = (g as GeometryInstance3D).cast_shadow
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	await get_tree().create_timer(1.0).timeout
	var img := await _frame("shadows_" + label)
	var dir := -sun.global_basis.z
	var hdir := Vector3(dir.x, 0, dir.z).normalized()
	var per_m := Vector2(dir.x, dir.z).length() / maxf(-dir.y, 0.05)
	var side := Vector3(hdir.z, 0, -hdir.x)
	var out := {}
	# The survivor stands among the camp's own shadows, so his patch is compared with the
	# same patch once he stops casting, not with lit ground beside it.
	for g in keep:
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await get_tree().create_timer(0.3).timeout
	var bare := await _frame("")
	for k in casters:
		var base: Vector3 = casters[k][0]
		# A raised caster's shadow starts downwind of its feet by its height over the plane.
		var start := Vector3(base.x, y, base.z) + hdir * (base.y - y) * per_m
		var length: float = (casters[k][1] as Vector3).y * per_m
		var shade := INF
		var rel := INF
		for i in range(2, 10):
			var at := start + hdir * length * float(i) / 10.0
			var l := _lum_at(img, at)
			shade = minf(shade, l)
			rel = minf(rel, l / maxf(_lum_at(bare, at), 0.0001))
		var mid := start + hdir * length * 0.6
		var lit := (_lum_at(img, mid + side * 1.5) + _lum_at(img, mid - side * 1.5)) * 0.5
		out[k] = rel if k == "survivor" else shade / maxf(lit, 0.0001)
		print("[lighting] %s %s shadow_len=%.2f lum_shadow=%.3f lum_lit=%.3f ratio=%.3f" % [label, k, length, shade, lit, out[k]])
	for g in keep:
		(g as GeometryInstance3D).cast_shadow = keep[g]
	plane.queue_free()
	for n in props:
		n.queue_free()
	await get_tree().create_timer(0.5).timeout
	return out

## Mean Rec.709 luminance of the displayed pixels in a 5x5 patch around a world point.
func _lum_at(img: Image, world: Vector3) -> float:
	var sp := _cam.unproject_position(world)
	var vr := get_viewport().get_visible_rect().size
	var x := int(sp.x * float(img.get_width()) / vr.x)
	var y := int(sp.y * float(img.get_height()) / vr.y)
	var acc := 0.0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			acc += _lum(img.get_pixel(clampi(x + dx, 0, img.get_width() - 1), clampi(y + dy, 0, img.get_height() - 1)))
	return acc / 25.0

func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

## Percent of pixels (every 2nd row and column) whose R, G and B all exceed 0.95.
func _blown_pct(img: Image) -> float:
	var n := 0
	var hot := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			n += 1
			if c.r > 0.95 and c.g > 0.95 and c.b > 0.95:
				hot += 1
	return 100.0 * float(hot) / float(maxi(n, 1))

## Mean luminance of terrain points on a 2 m grid within 8 m of the survivor (10 m, skipping
## the inner from_m, when from_m is set).
func _ground_lum(img: Image, from_m: float = 0.0) -> float:
	var rt := World.runtime as IslandRuntime
	var p := _player.global_position
	var acc := 0.0
	var n := 0
	var half := 4 if from_m <= 0.0 else 5
	for gz in range(-half, half + 1):
		for gx in range(-half, half + 1):
			if Vector2(gx, gz).length() * 2.0 < from_m:
				continue
			var wx := p.x + gx * 2.0
			var wz := p.z + gz * 2.0
			acc += _lum_at(img, Vector3(wx, rt.surface_y(wx, wz), wz))
			n += 1
	return acc / float(n)

## Mean hue (degrees) and saturation of the sampled ground patches; renderer drift is visible here.
func _ground_hue(img: Image) -> Vector2:
	var rt := World.runtime as IslandRuntime
	var p := _player.global_position
	var hx := 0.0
	var hy := 0.0
	var sat := 0.0
	var n := 0
	for gz in range(-2, 3):
		for gx in range(-2, 3):
			var wx := p.x + gx * 2.0
			var wz := p.z + gz * 2.0
			var sp := _cam.unproject_position(Vector3(wx, rt.surface_y(wx, wz), wz))
			var vr := get_viewport().get_visible_rect().size
			var ix := clampi(int(sp.x * float(img.get_width()) / vr.x), 0, img.get_width() - 1)
			var iy := clampi(int(sp.y * float(img.get_height()) / vr.y), 0, img.get_height() - 1)
			var c := img.get_pixel(ix, iy)
			hx += cos(c.h * TAU)
			hy += sin(c.h * TAU)
			sat += c.s
			n += 1
	if n == 0:
		return Vector2.ZERO
	var deg := fposmod(rad_to_deg(atan2(hy / n, hx / n)), 360.0)
	return Vector2(deg, sat / float(n))

func _coarse_mean(img: Image) -> float:
	var acc := 0.0
	var n := 0
	for y in range(0, img.get_height(), int(img.get_height() / 24.0)):
		for x in range(0, img.get_width(), int(img.get_width() / 40.0)):
			acc += _lum(img.get_pixel(x, y))
			n += 1
	return acc / float(maxi(n, 1))

func _shot_at(tod: float, label: String) -> Image:
	Game.time_of_day = tod
	await get_tree().create_timer(1.5).timeout
	var img := await _frame(label)
	print("[lighting] shot %s tod=%.2f" % [label, tod])
	return img

## Median luminance on the camp's dirt discs (ring at 0.6 r) and on grass just outside them
## (ring at r + 1.2 m, skipping points inside any other disc). Medians shrug off the props.
func _disc_vs_grass(img: Image) -> Vector2:
	var rt := World.runtime as IslandRuntime
	var discs: Array = []
	for n in get_tree().root.find_children("Foundation", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var sm := mi.material_override as ShaderMaterial
		if sm != null and mi.global_position.distance_to(_player.global_position) < 12.0:
			discs.append([mi.global_position, float(sm.get_shader_parameter("radius"))])
	var on: Array[float] = []
	var off: Array[float] = []
	for d in discs:
		for k in 16:
			var a := TAU * float(k) / 16.0
			var dir := Vector3(cos(a), 0.0, sin(a))
			var pin: Vector3 = d[0] + dir * d[1] * 0.6
			on.append(_lum_at(img, Vector3(pin.x, rt.surface_y(pin.x, pin.z), pin.z)))
			var pout: Vector3 = d[0] + dir * (d[1] + 1.2)
			if discs.all(func(o: Array) -> bool: return Vector2(pout.x - o[0].x, pout.z - o[0].z).length() > o[1] + 0.5):
				off.append(_lum_at(img, Vector3(pout.x, rt.surface_y(pout.x, pout.z), pout.z)))
	if on.is_empty() or off.is_empty():
		return Vector2(0.0, 1.0)
	on.sort()
	off.sort()
	return Vector2(on[on.size() / 2], off[off.size() / 2])
