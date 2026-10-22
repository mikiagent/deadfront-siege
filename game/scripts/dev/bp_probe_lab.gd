extends Node3D
## Temporary probe (unshaded = identity pipeline): COLOR_0 as exported vs rewrapped as sRGB,
## next to a plain albedo swatch of the authored palette colour.

const PAL := Color(0.62, 0.38, 0.27)

func _ready() -> void:
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	for c in get_tree().root.get_children():
		if c is CanvasLayer:
			c.visible = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 20.0
	add_child(cam)
	cam.position = Vector3(0, 4.8, 40)
	cam.look_at(Vector3(0, 4.8, 0), Vector3.UP)
	cam.current = true
	var swatch := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	swatch.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = PAL
	swatch.material_override = sm
	swatch.position = Vector3(0, 20, 0)
	add_child(swatch)
	var src_scene: PackedScene = load("res://assets/nature/biome/mesa_sandstone.glb")
	var inst: Node3D = src_scene.instantiate()
	add_child(inst)
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var src := mi.mesh as ArrayMesh
	var arr: Array = src.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	for i in cols.size():
		var sc := cols[i].linear_to_srgb()
		cols[i] = Color(sc.r, sc.g, sc.b, 1.0)
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var img: Image = null
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	img = get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var best := Color.BLACK
	for yy in range(int(h * 0.42), int(h * 0.60)):
		for xx in range(int(w * 0.35), int(w * 0.65)):
			var p := img.get_pixel(xx, yy)
			if p.get_luminance() > best.get_luminance():
				best = p
	print("[probe] rewrapped-sRGB brightest=%s authored=%s" % [best, PAL])
	img.save_png("/tmp/bp_vcol_rewrap.png")
	get_tree().quit(0)
