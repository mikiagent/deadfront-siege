class_name WorldLighting
extends RefCounted
## The island's sun, sky and environment, and the day/night drive that animates them.

var sun: DirectionalLight3D
var world_env: WorldEnvironment
var _sky_mat: ProceduralSkyMaterial

## Builds the environment and the sun under host and takes over the scene's lighting.
func install(host: Node3D) -> void:
	_env(host)
	_sun(host)

func _env(host: Node3D) -> void:
	# The island owns the lighting: every other directional light (main scene, lab kits)
	# is switched off and every other WorldEnvironment is emptied, so day/night works
	# the same in the game and in the labs.
	var root := host.get_tree().root
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l != sun:
			(l as DirectionalLight3D).visible = false
	var envs := root.find_children("*", "WorldEnvironment", true, false)
	for i in envs.size():
		var we := envs[i] as WorldEnvironment
		if i == 0:
			world_env = we
		else:
			we.environment = null
	if world_env:
		if world_env.environment == null:
			world_env.environment = Environment.new()
		_apply_env_setup(world_env.environment)
		return
	world_env = WorldEnvironment.new()
	var e := Environment.new()
	_apply_env_setup(e)
	world_env.environment = e
	host.add_child(world_env)

func _apply_env_setup(e: Environment) -> void:
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.80, 0.86, 0.95)
	e.ambient_light_energy = 0.75
	e.ssao_enabled = false
	e.ssr_enabled = false
	e.glow_enabled = false
	e.fog_enabled = true
	e.fog_density = 0.0022
	e.fog_light_color = Color(0.64, 0.74, 0.83)
	e.fog_sun_scatter = 0.0
	e.fog_height = 0.0
	e.fog_aerial_perspective = 0.2
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color(0.20, 0.42, 0.66)
	_sky_mat.sky_horizon_color = Color(0.66, 0.78, 0.92)
	_sky_mat.ground_bottom_color = Color(0.06, 0.08, 0.10)
	_sky_mat.ground_horizon_color = Color(0.24, 0.29, 0.34)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	e.sky = sky

func _sun(host: Node3D) -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.rotation_degrees = Vector3(-55, 30, 0)
	host.add_child(sun)

## Sun angle, colour and energy plus ambient, fog and sky for time of day tod (0 = midnight).
func drive(tod: float) -> void:
	if sun == null:
		return
	var from_noon := absf(tod - 0.5) * 2.0
	sun.rotation_degrees = Vector3(lerpf(-62.0, 12.0, from_noon), 30.0, 0.0)
	var night_n := smoothstep(0.35, 1.0, from_noon)
	# Real night (reference: dark ground, the fire and the lantern carry the scene).
	sun.light_energy = lerpf(1.3, 0.03, night_n)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(0.55, 0.62, 0.85), night_n)
	if world_env and world_env.environment:
		world_env.environment.ambient_light_energy = lerpf(0.75, 0.10, night_n)
		world_env.environment.ambient_light_color = Color(0.80, 0.86, 0.95).lerp(Color(0.35, 0.42, 0.70), night_n)
		world_env.environment.fog_density = lerpf(0.0022, 0.0044, night_n)
		if _sky_mat:
			_sky_mat.sky_top_color = Color(0.20, 0.42, 0.66).lerp(Color(0.04, 0.08, 0.16), night_n)
			_sky_mat.sky_horizon_color = Color(0.66, 0.78, 0.92).lerp(Color(0.18, 0.22, 0.31), night_n)
			_sky_mat.ground_horizon_color = Color(0.24, 0.29, 0.34).lerp(Color(0.08, 0.10, 0.12), night_n)
