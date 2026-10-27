extends Node3D
## Throwaway: renders all 25 biome GLBs at the game's iso camera with WorldLighting.

func _ready() -> void:
	WorldLighting.install(self, "temperate")
	Game.time_of_day = 0.35
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	floor_mi.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.36, 0.5, 0.28)
	fmat.roughness = 1.0
	floor_mi.material_override = fmat
	add_child(floor_mi)
	var d := DirAccess.open("res://assets/nature/biome")
	var names: Array[String] = []
	for f in d.get_files():
		if f.ends_with(".glb"):
			names.append(f.get_basename())
	names.sort()
	var cols := 5
	var step := 16.0
	for i in names.size():
		var scene: PackedScene = load("res://assets/nature/biome/%s.glb" % names[i])
		var inst: Node3D = scene.instantiate()
		inst.position = Vector3((i % cols) * step - step * (cols - 1) * 0.5, 0.0,
				(i / cols) * step - step * 2.0)
		add_child(inst)
		var lab := Label3D.new()
		lab.text = names[i]
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.pixel_size = 0.02
		lab.modulate = Color(0.1, 0.1, 0.12)
		lab.position = inst.position + Vector3(0, 0.4, 6)
		add_child(lab)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 44.0
	cam.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	cam.position = Vector3(0, 40, 0) + cam.global_transform.basis.z * -60.0
	add_child(cam)
	cam.position = Vector3(30, 34, 30) + Vector3(0, 0, 0)
	cam.look_at(Vector3(0, 0, 4), Vector3.UP)
	cam.current = true
	for i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/bp_godot_all.png")
	print("[bpgodot] wrote /tmp/bp_godot_all.png %s" % img.get_size())
	get_tree().quit(0)
