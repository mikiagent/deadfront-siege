extends SceneTree
## WAVES render probe, run in a window by t_waves once per renderer (forward_plus, gl_compatibility).
## Draws the sea and shore-wash shaders over a bright red block 0.15 m under the sea and reads the
## centre pixel looking straight down, with the block shown and hidden (the red it adds): deep water
## (2.95 m) must hide the block (the owner's "water see-through glitch when on the beach": the seabed
## showed through open water; the pre-fix 0.95 alpha bleeds 0.14 here), shallow water (0.3 m)
## must still show some of it (a soft shallow fade, not a solid lid). Shader compile errors print
## "SHADER ERROR" to the log, which t_waves reads. Prints "[t_waves_render] deep=<redness> shallow=<redness>".

var _water: ShaderMaterial
var _block: MeshInstance3D

func _initialize() -> void:
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 12, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	root3.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root3.add_child(sun)
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(30, 0.1, 30)
	block.mesh = box
	block.position.y = -0.25
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1, 0, 0)
	block.material_override = red
	root3.add_child(block)
	_block = block
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	plane.subdivide_width = 10
	plane.subdivide_depth = 10
	sea.mesh = plane
	sea.position.y = -0.05
	_water = ShaderMaterial.new()
	_water.shader = load("res://scripts/world/water.gdshader")
	_water.set_shader_parameter("map_size", 40.0)
	_water.set_shader_parameter("height_res", 4.0)
	_water.set_shader_parameter("water_y", -0.05)
	_water.set_shader_parameter("noise_tex", load("res://scripts/world/island_terrain.gd").noise_tex())
	sea.material_override = _water
	root3.add_child(sea)
	var skin := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(3, 3)
	skin.mesh = quad
	skin.position = Vector3(8, 0.0, 0)
	var shore := ShaderMaterial.new()
	shore.shader = load("res://scripts/world/shore_wash.gdshader")
	shore.set_shader_parameter("noise_tex", _water.get_shader_parameter("noise_tex"))
	skin.material_override = shore
	root3.add_child(skin)
	_run.call_deferred()

func _ground(h: float) -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RF)
	img.fill(Color(h, 0, 0))
	_water.set_shader_parameter("height_tex", ImageTexture.create_from_image(img))

func _red() -> float:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, img.get_height() / 2).r

## How much red the block under the water adds to the centre pixel.
func _redness() -> float:
	_block.visible = true
	var on := await _red()
	_block.visible = false
	var off := await _red()
	return on - off

func _run() -> void:
	_ground(-3.0)
	var deep := await _redness()
	_ground(-0.35)
	var shallow := await _redness()
	print("[t_waves_render] renderer=%s deep=%.3f shallow=%.3f" % [RenderingServer.get_current_rendering_method(), deep, shallow])
	quit(0)
