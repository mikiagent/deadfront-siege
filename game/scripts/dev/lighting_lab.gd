extends Node3D
## Lighting acceptance (W1-LIGHT): temperate_25 under the shared WorldLighting. Measures a
## 1x3x1 shadow-only box's shadow against lit grey ground, then the camp view's blown pixels
## and ground luminance; prints [lighting] lines and exits 0 on PASS, 1 on FAIL. Windowed only.
## --light-shots=<dir> also saves the frames plus night (tod 0.0) and dusk (tod 0.73) views.

## ASSUMPTION: mid-morning (sun ~51 deg up) is the measured daylight; the spec names no time.
const TOD := 0.42
const MAX_SHADOW_RATIO := 0.75
const MAX_BLOWN_PCT := 1.0
const GROUND_LUM := Vector2(0.25, 0.55)

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
	if DisplayServer.get_name() == "headless":
		print("[lighting] SKIP headless renders no pixels; run windowed")
		get_tree().quit.call_deferred(0)
		return
	_run.call_deferred()

func _run() -> void:
	# Measurement frames show the 3D view only: HUD text would count as blown pixels.
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	TouchControls.visible = false
	await _settle()
	var light := get_tree().get_first_node_in_group(&"world_lighting") as WorldLighting
	print("[lighting] renderer=%s tod=%.2f sun_energy=%.2f sun_rot=%s exposure=%.2f" % [_tag, Game.time_of_day,
		light.sun.light_energy, light.sun.rotation_degrees, light.world_env.environment.tonemap_exposure])
	var ratio := await _shadow_ratio(light.sun)
	var img := await _frame("camp")
	var blown := _blown_pct(img)
	var ground := _ground_lum(img)
	print("[lighting] shadow_ratio=%.3f" % ratio)
	print("[lighting] blown_pct=%.3f" % blown)
	print("[lighting] ground_lum=%.3f" % ground)
	if _out != "":
		await _shot_at(0.0, "night")
		await _shot_at(0.73, "dusk")
	var ok := ratio <= MAX_SHADOW_RATIO and blown <= MAX_BLOWN_PCT and ground >= GROUND_LUM.x and ground <= GROUND_LUM.y
	print("[lighting] %s" % ("PASS" if ok else "FAIL (shadow_ratio <= %.2f, blown_pct <= %.1f, ground_lum %.2f-%.2f)" % [
		MAX_SHADOW_RATIO, MAX_BLOWN_PCT, GROUND_LUM.x, GROUND_LUM.y]))
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

## The verifier's probe: grey plane, shadow-only box, mean luminance of two points inside the
## cast shadow over two lit points beside it. Lower = more visible shadow.
func _shadow_ratio(sun: DirectionalLight3D) -> float:
	var rt := World.runtime as IslandRuntime
	var bx := _player.global_position.x - 5.0
	var bz := _player.global_position.z + 1.0
	var base := Vector3(bx, rt.surface_y(bx, bz) + 0.06, bz)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.0, 12.0)
	plane.mesh = pm
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.35, 0.35)
	plane.material_override = grey
	add_child(plane)
	plane.global_position = base
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 3.0, 1.0)
	box.mesh = bm
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(box)
	box.global_position = base + Vector3(0, 1.5, 0)
	await get_tree().create_timer(1.0).timeout
	var img := await _frame("box")
	var dir := -sun.global_basis.z
	var tip := base + Vector3(0, 3.0, 0) + dir * (3.0 / maxf(-dir.y, 0.05))
	tip.y = base.y
	var hv := tip - base
	var side := Vector3(hv.z, 0, -hv.x).normalized() * 3.0
	var shade := (_lum_at(img, base + hv * 0.45) + _lum_at(img, base + hv * 0.7)) * 0.5
	var lit := (_lum_at(img, base - hv * 0.45) + _lum_at(img, base + side)) * 0.5
	plane.queue_free()
	box.queue_free()
	await get_tree().create_timer(0.5).timeout
	print("[lighting] box shadow_len=%.2f lum_shadow=%.3f lum_lit=%.3f" % [hv.length(), shade, lit])
	return shade / maxf(lit, 0.0001)

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

## Mean luminance of terrain points on a 2 m grid within 8 m of the survivor.
func _ground_lum(img: Image) -> float:
	var rt := World.runtime as IslandRuntime
	var p := _player.global_position
	var acc := 0.0
	var n := 0
	for gz in range(-4, 5):
		for gx in range(-4, 5):
			var wx := p.x + gx * 2.0
			var wz := p.z + gz * 2.0
			acc += _lum_at(img, Vector3(wx, rt.surface_y(wx, wz), wz))
			n += 1
	return acc / float(n)

func _coarse_mean(img: Image) -> float:
	var acc := 0.0
	var n := 0
	for y in range(0, img.get_height(), int(img.get_height() / 24.0)):
		for x in range(0, img.get_width(), int(img.get_width() / 40.0)):
			acc += _lum(img.get_pixel(x, y))
			n += 1
	return acc / float(maxi(n, 1))

func _shot_at(tod: float, label: String) -> void:
	Game.time_of_day = tod
	await get_tree().create_timer(1.5).timeout
	await _frame(label)
	print("[lighting] shot %s tod=%.2f" % [label, tod])
