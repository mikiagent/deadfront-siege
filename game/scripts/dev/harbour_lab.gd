extends Node3D
## The harbour on the coast. --island=<id> (default home_grassland) loads that island, stands the
## survivor on the dock's arrival point and frames dock, water and beach; --frame=wide frames the
## camp and the harbour together. Prints one [harbour] line; headless quits after it.

func _ready() -> void:
	var island := "home_grassland"
	var wide := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--island="):
			island = a.substr(9)
		elif a == "--frame=wide":
			wide = true
	var kit := LabKit.build(self, 20.0)
	var player: Player = kit["player"]
	var cam: IsoCamera = kit["cam"]
	(kit["nav"] as Node3D).visible = false
	if Game.shot_path != "":
		TouchControls.visible = false
		TouchControls.enabled = false
	World.harvested.clear()
	World.load_island(self, StringName(island), Vector3(0, 1, 0), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.free()
	var rt = World.runtime
	var arrive: Vector3 = rt.arrival_point()
	player.global_position = arrive + Vector3.UP
	var harb: Vector3 = rt._harbour_pos
	var camp: Vector3 = rt._camp_pos
	var focus := Node3D.new()
	focus.name = "Focus"
	add_child(focus)
	focus.global_position = harb.lerp(camp, 0.5) if wide else harb.lerp(arrive, 0.4)
	cam.size = maxf(24.0, Vector2(harb.x - camp.x, harb.z - camp.z).length() * 1.1) if wide else 15.0
	cam._target = focus
	cam._snap()
	print("[harbour] lab island=%s cell=%s rot=%d harbour=(%.1f, %.1f) arrival=(%.1f, %.1f) camp=(%.1f, %.1f) camp_to_harbour_m=%.1f" % [
		island, rt.harbour.build_cell, rt.harbour.build_rot, harb.x, harb.z, arrive.x, arrive.z,
		camp.x, camp.z, Vector2(harb.x - camp.x, harb.z - camp.z).length()])
	print("[boot] lab=harbour_lab")
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().quit(0)
