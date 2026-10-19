class_name WorldWeather
extends RefCounted
## Island rain (timer, particles, the Wet status) plus the per-frame climate and level-gap
## fatigue feed for the player, which rides the same tick.

var raining: bool = false
var _rain_left: float = 0.0
var _rain_cd: float = 40.0
var _wet_refresh: float = 0.0
var _rain_fx: GPUParticles3D

func install(rt: IslandRuntime) -> void:
	_rain_fx = GPUParticles3D.new()
	_rain_fx.emitting = false
	_rain_fx.amount = 400
	_rain_fx.lifetime = 0.9
	_rain_fx.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 20, 80))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 4.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -14, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18, 0.2, 18)
	mat.color = Color(0.65, 0.75, 0.9, 0.7)
	_rain_fx.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.03
	draw.height = 0.12
	_rain_fx.draw_pass_1 = draw
	rt.add_child(_rain_fx)

func tick(rt: IslandRuntime, delta: float) -> void:
	_rain_cd -= delta
	var p := rt.get_tree().get_first_node_in_group("player") as Player
	if raining:
		_rain_left -= delta
		if p:
			# Refresh once a second, not every frame, so the status log and its bookkeeping stay quiet.
			_wet_refresh -= delta
			if _wet_refresh <= 0.0 or not p.statuses.has(&"wet"):
				p.statuses.apply(&"wet", null)
				_wet_refresh = 1.0
		if _rain_fx:
			if p:
				_rain_fx.global_position = p.global_position + Vector3(0, 10, 0)
			_rain_fx.emitting = true
		if _rain_left <= 0.0:
			raining = false
			_rain_cd = randf_range(50.0, 90.0)
			if _rain_fx:
				_rain_fx.emitting = false
	elif _rain_cd <= 0.0:
		raining = true
		_rain_left = 18.0
		print("[world] rain")
	if p:
		p.tick_climate_fatigue(delta, rt._climate)
		if p.vitals:
			var char_level := p.skills.character_level() if p.skills else 1
			var zone_level := rt.material_level(p.global_position, rt._tier)
			p.vitals.gap_zone_level = zone_level
			p.vitals.gap_char_level = char_level
			var fatigue_cfg: Dictionary = Data.world_rules.get("fatigue", {}) as Dictionary
			p.vitals.breakdown_window_s = float(fatigue_cfg.get("breakdown_window_s", 180.0))
			p.vitals.level_gap_mult = ProgressionScaling.fatigue_level_factor(zone_level, char_level, fatigue_cfg)
