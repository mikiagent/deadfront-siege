extends SceneTree
func _init() -> void:
	for s in ["zebraceratops","megaloceros","protoceratops","gallimimus","velociraptor","utahraptor","coelophysis"]:
		var p := "res://assets/creatures/%s/%s.glb" % [s, s]
		if not ResourceLoader.exists(p):
			print("MISSING ", p)
			continue
		var inst = (load(p) as PackedScene).instantiate()
		var sk := inst.find_child("Skeleton3D", true, false) as Skeleton3D
		var names: Array[String] = []
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		var mi := inst.find_child("*", true, false) as MeshInstance3D
		print("BONES %s %s" % [s, names])
		inst.free()
	quit(0)
