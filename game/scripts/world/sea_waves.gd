class_name SeaWaves
extends Node
## WAVES (owner 2026-10-28: "I want wave effects on the water too"). Drives the sea's look from the
## weather: the swell, chop, foam and wind of water.gdshader and the swash / wet line of
## shore_wash.gdshader, whose skin mesh this builds from the terrain's own beach triangles.
## Visual only: the logical sea stays HarbourSite.WATER_Y (-0.05) for swimming, wading, harbours,
## walkability and building; nothing here is read by gameplay.
## Weather is read by property name (rain_amount, storm, raining) so a runtime without WorldWeather
## keeps the calm sea. Quality: --water-quality=low|high; low (default on web and phones) runs two
## swell waves and two ripple samples on a coarser sea mesh.

const SHORE_SHADER: Shader = preload("res://scripts/world/shore_wash.gdshader")
## Skin height over the terrain triangles it copies (no z-fight, too thin to see from the side).
const LIFT := 0.04
## Clear -> storm. wave_amp m of swell, run_up m of height the swash climbs above the sea.
const CALM := {"wave_amp": 0.08, "chop": 0.25, "foam_amt": 0.55, "run_up": 0.07}
const STORM := {"wave_amp": 0.4, "chop": 1.0, "foam_amt": 1.0, "run_up": 0.2}
## Sea-state change per second (about 6 s from calm to a full storm).
const EASE_PER_S := 1.0 / 6.0

static var high_quality: bool = not (OS.has_feature("mobile") or OS.has_feature("web"))
static var _args_read := false

var water_mat: ShaderMaterial
var shore_mat: ShaderMaterial
## 0 calm .. 1 full storm, eased toward the weather's target.
var state := 0.0
var _set_state := -1.0
var _rt: Node

static func read_args() -> void:
	if _args_read:
		return
	_args_read = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--water-quality="):
			high_quality = a.substr(16) != "low"

## Sea mesh subdivisions: 8 m quads (16 m on low) carry the 17-30 m swell; shorter waves only shade.
static func subdivisions(plane_m: float) -> int:
	read_args()
	return clampi(int(plane_m / (8.0 if high_quality else 16.0)), 24, 200)

## Called by IslandTerrain._sea once the water plane and its material exist.
static func attach(rt: IslandRuntime, water_mat: ShaderMaterial) -> SeaWaves:
	read_args()
	var sw := SeaWaves.new()
	sw.name = "SeaWaves"
	sw._rt = rt
	sw.water_mat = water_mat
	water_mat.set_shader_parameter("hq", high_quality)
	sw.shore_mat = ShaderMaterial.new()
	sw.shore_mat.shader = SHORE_SHADER
	sw.shore_mat.set_shader_parameter("noise_tex", water_mat.get_shader_parameter("noise_tex"))
	sw.shore_mat.set_shader_parameter("water_y", water_mat.get_shader_parameter("water_y"))
	sw.shore_mat.set_shader_parameter("lift", LIFT)
	var surf := surf_mask(rt)
	water_mat.set_shader_parameter("surf_tex", ImageTexture.create_from_image(surf))
	var skin := build_shore_skin(rt, float(water_mat.get_shader_parameter("water_y")), float(STORM["run_up"]), surf)
	if skin:
		var mi := MeshInstance3D.new()
		mi.name = "ShoreWash"
		mi.mesh = skin
		mi.material_override = sw.shore_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sw.add_child(mi)
	rt.add_child(sw)
	sw.settle()
	return sw

## Surf per heightmap vertex (R8): 1 on the sea coast, 0 in and beside the river and on inland water,
## so breakers and swash only run on beaches facing the sea.
static func surf_mask(rt: IslandRuntime) -> Image:
	var res := rt._res
	var shore0: float = rt._shape.shore0 if rt._shape else 1.0e9
	var bytes := PackedByteArray()
	bytes.resize(res * res)
	for i in res * res:
		var river := smoothstep(6.0, 14.0, rt._river_d[i]) if rt._river_d.size() == res * res else 1.0
		var coast := smoothstep(0.8, 0.92, rt._rad[i] / shore0) if rt._rad.size() == res * res else 1.0
		bytes[i] = int(river * coast * 255.0)
	return Image.create_from_data(res, res, false, Image.FORMAT_R8, bytes)

## The drawn ground's triangles whose cell spans the swash zone (sea level to the storm run-up), lifted
## LIFT. Reads the refined drawn surface (_surf, TERRAINSMOOTH) when the runtime has one, else the data
## grid; both use IslandTerrain's diagonal, so the skin lies exactly on the ground it covers.
static func build_shore_skin(rt: IslandRuntime, water_y: float, max_run: float, surf: Image) -> ArrayMesh:
	var hts: PackedFloat32Array = rt._heights
	var fine: Variant = rt.get("_surf")
	if fine is PackedFloat32Array and not (fine as PackedFloat32Array).is_empty():
		hts = fine
	var res := int(round(sqrt(float(hts.size()))))
	var cres := surf.get_width()
	var to_c := float(cres - 1) / float(res - 1)
	var cell := rt._size / float(res - 1)
	var lo := water_y - 0.03
	var hi := water_y + max_run + 0.03
	var sb := surf.get_data()
	var verts := PackedVector3Array()
	var surfs := PackedFloat32Array()
	var idx := PackedInt32Array()
	var vmap := {}
	for z in res - 1:
		for x in res - 1:
			var i0 := x + z * res
			var a := hts[i0]
			var b := hts[i0 + 1]
			var c := hts[i0 + res]
			var d := hts[i0 + res + 1]
			if minf(minf(a, b), minf(c, d)) > hi or maxf(maxf(a, b), maxf(c, d)) < lo:
				continue
			var q: Array[int] = []
			var any := 0.0
			for k: int in [i0, i0 + 1, i0 + res, i0 + res + 1]:
				if not vmap.has(k):
					vmap[k] = verts.size()
					var kx := k % res
					var kz := k / res
					verts.append(Vector3(-rt._size * 0.5 + float(kx) * cell, hts[k] + LIFT, -rt._size * 0.5 + float(kz) * cell))
					surfs.append(float(sb[roundi(kx * to_c) + roundi(kz * to_c) * cres]) / 255.0)
				q.append(vmap[k])
				any += surfs[vmap[k]]
			if any > 0.0:
				# (x,z) (x+1,z) (x,z+1) and (x+1,z) (x+1,z+1) (x,z+1): IslandTerrain's diagonal.
				idx.append_array([q[0], q[1], q[2], q[1], q[3], q[2]])
	if idx.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		st.set_color(Color(surfs[i], 0.0, 0.0))  # COLOR.r = surf
		st.add_vertex(verts[i])
	for i in idx:
		st.add_index(i)
	st.generate_normals()
	return st.commit()

## The weather's target sea state, 0 calm .. 1 storm. Calm when the runtime has no weather.
static func target_state(weather: Object) -> float:
	if weather == null:
		return 0.0
	var rain: Variant = weather.get("rain_amount")
	var storm: Variant = weather.get("storm")
	var raining: Variant = weather.get("raining")
	var r := float(rain) if rain != null else 0.0
	var s: bool = storm == true and raining != false
	return clampf(r * 0.5 + (0.5 if s else 0.0), 0.0, 1.0)

func _process(delta: float) -> void:
	state = move_toward(state, target_state(_rt.get("weather") as Object), delta * EASE_PER_S)
	if absf(state - _set_state) > 0.003:
		_apply()

## Jump straight to the weather's sea state (build, labs and tests).
func settle() -> void:
	state = target_state(_rt.get("weather") as Object)
	_apply()

func param(key: String) -> float:
	return lerpf(float(CALM[key]), float(STORM[key]), state)

func _apply() -> void:
	_set_state = state
	# The wind swings round a little as weather builds; ASSUMPTION: no wind model exists, one prevailing direction.
	var wind := Vector2(0.94, 0.34).rotated(state * 0.5)
	for k: String in ["wave_amp", "chop", "foam_amt"]:
		water_mat.set_shader_parameter(k, param(k))
	shore_mat.set_shader_parameter("foam_amt", param("foam_amt"))
	water_mat.set_shader_parameter("wind_dir", wind)
	water_mat.set_shader_parameter("sea_state", state)
	shore_mat.set_shader_parameter("run_up", param("run_up"))
