class_name WeatherFx
extends CanvasLayer
## WEATHER's screen layer for WorldWeather, on a canvas layer under every HUD layer, so the HUD, its taken
## rects and the combat red edge (StatusFx.draw_vignette) always draw over it. Heat: an orange edge, a warm
## wash, the shimmer (high quality) and a slow sway. Cold: a blue-white edge and frost creeping in from the
## borders, with shivers. Storm: the lightning flash, then the thunder's rumble. While a hunt or a red-edge
## status is on, the weather edges drop to 35 % so the red one reads first.
## It also pulses the sun (or the moon at night) on a strike and dims the sun in rain, on top of what
## WorldLighting wrote this frame (process_priority runs it after), and hands the camera its weather shake.

const LAYER := -1
const COMBAT_EDGE_SCALE := 0.35
## Light added at a full flash, on top of the profile's sun / moon energy.
const FLASH_SUN := 1.8
const FLASH_MOON := 3.0
## Sun energy lost at full rain (a storm): an overcast day.
const RAIN_DIM := 0.5
## High: the heat shimmer (one screen copy and one full-screen pass while it is hot). Low: everything else.
## --weather-quality=low|high. ASSUMPTION: low on iOS / Android, high elsewhere (web included). Measured on
## the dev Mac at 1600x900: the shimmer adds ~1.2 ms a frame on Forward+, nothing visible at the 120 Hz cap on
## gl_compatibility; the edge/frost pass is below the noise. Not measured on a phone yet.
static var high_quality: bool = not OS.has_feature("mobile")

var weather: WorldWeather
var shimmer: ColorRect
var edge: ColorRect
## The camera offset handed over this frame (metres), and the edges' combat scale.
var shake := Vector2.ZERO
var edge_scale := 1.0
var _edge_mat: ShaderMaterial
var _shimmer_mat: ShaderMaterial
var _t := 0.0

func _init() -> void:
	name = "WeatherFx"
	layer = LAYER
	process_priority = 100
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weather-quality="):
			high_quality = a.substr(18) != "low"
	shimmer = _rect("Shimmer", preload("res://shaders/weather/weather_shimmer.gdshader"))
	_shimmer_mat = shimmer.material
	edge = _rect("Edge", preload("res://shaders/weather/weather_edge.gdshader"))
	_edge_mat = edge.material

func _rect(n: String, sh: Shader) -> ColorRect:
	var r := ColorRect.new()
	r.name = n
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	add_child(r)
	return r

func _process(delta: float) -> void:
	if weather == null:
		return
	_t += delta
	var w := weather
	edge_scale = COMBAT_EDGE_SCALE if red_edge_on(PlayerRegistry.local()) else 1.0
	edge.visible = maxf(maxf(w.heat, w.cold), maxf(maxf(w.frost, w.flash), w.rain_amount)) > 0.002
	if edge.visible:
		_edge_mat.set_shader_parameter(&"px", edge.size)
		_edge_mat.set_shader_parameter(&"heat", w.heat)
		_edge_mat.set_shader_parameter(&"cold", w.cold)
		_edge_mat.set_shader_parameter(&"frost", w.frost)
		_edge_mat.set_shader_parameter(&"rain", w.rain_amount)
		_edge_mat.set_shader_parameter(&"flash", w.flash)
		_edge_mat.set_shader_parameter(&"edge_scale", edge_scale)
	shimmer.visible = high_quality and w.heat > 0.01
	if shimmer.visible:
		_shimmer_mat.set_shader_parameter(&"heat", w.heat)
	_light(w)
	shake = w.shake_offset(_t)
	var cam := get_viewport().get_camera_3d() as IsoCamera if is_inside_tree() else null
	if cam:
		cam.weather_offset = shake

func _exit_tree() -> void:
	var cam := get_viewport().get_camera_3d() as IsoCamera
	if cam:
		cam.weather_offset = Vector2.ZERO

## A hunt in progress or a status that draws the red screen edge (bleed, deep bleed).
static func red_edge_on(p: Player) -> bool:
	if p == null:
		return false
	if p.hunt != null and is_instance_valid(p.hunt.target):
		return true
	if p.statuses:
		for inst in p.statuses.instances():
			var def := Data.status(inst.id)
			if def and def.fx_vignette:
				return true
	return false

func _light(w: WorldWeather) -> void:
	var rt := get_parent() as IslandRuntime
	var wl := rt.lighting if rt else null
	if wl == null or wl.sun == null:
		return
	# Only on values WorldLighting rewrote this frame: a paused lighting must not compound the dimming.
	if not (wl.is_processing() and wl.can_process()):
		return
	wl.sun.light_energy = wl.sun.light_energy * (1.0 - RAIN_DIM * w.rain_amount) + (w.flash * FLASH_SUN if wl.sun.visible else 0.0)
	if wl.moon and wl.moon.visible:
		wl.moon.light_energy += w.flash * FLASH_MOON
