extends SceneTree
## SADDLES: every mount-role species that has a game model either carries mount/saddle.glb + mount/mount.json
## with the keys the game reads (socket, saddle, rider_offset, rider_in_mount, seat, hips_above_socket_m), or
## is declared too small in data/mounts_skip.json with its measured numbers. The skip rule is checked too:
## rider 1.78 m > back height x 1.6 means no saddle, and a skipped species must not ship one.
## The T. rex is the reference and must keep its saddle untouched.

const RIDER_M := 1.78
const LIMIT := 1.6
const REQUIRED := ["mount", "saddle", "socket", "rider_offset", "rider_in_mount", "seat", "hips_above_socket_m"]

func _process(_d: float) -> bool:
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_run()
	return true

func _run() -> void:
	var Data = get_root().get_node("Data")
	var fails: Array[String] = []
	var skips: Dictionary = {}
	var sf := "res://data/mounts_skip.json"
	if FileAccess.file_exists(sf):
		var sj: Variant = JSON.parse_string(FileAccess.get_file_as_string(sf))
		if sj is Dictionary and (sj as Dictionary).get("skip") is Dictionary:
			skips = (sj as Dictionary)["skip"]
		else:
			fails.append("mounts_skip.json has no skip object")
	if float(skips.get("_rider_height_m", RIDER_M)) > 0.0:
		pass
	var counts: Dictionary = {"saddled": 0, "skipped": 0, "fallback": 0}
	var ids: Array = Data.creatures.keys()
	ids.sort()
	for key in ids:
		var def = Data.creatures[key]
		if def == null or not (&"mount" in def.tamed_role):
			continue
		var glb: String = "res://assets/creatures/%s/%s.glb" % [def.id, def.id]
		if not ResourceLoader.exists(glb):
			print("[tmount] %s is a mount with no game model, not checked" % def.id)
			continue
		var dir: String = "res://assets/creatures/%s/mount" % def.id
		var has_saddle: bool = FileAccess.file_exists(dir + "/saddle.glb")
		var has_json: bool = FileAccess.file_exists(dir + "/mount.json")
		var skipped: bool = skips.has(str(def.id))
		if skipped:
			counts["skipped"] += 1
			var s: Dictionary = skips[str(def.id)]
			if has_saddle or has_json:
				fails.append("%s is in mounts_skip.json but ships a saddle" % def.id)
			for k in ["back_height_m", "limit_height_m", "height_meters"]:
				if not s.has(k):
					fails.append("%s skip entry lacks %s" % [def.id, k])
			var back := float(s.get("back_height_m", 0.0))
			if back * LIMIT >= RIDER_M:
				fails.append("%s is skipped but its back (%.2f m) is tall enough for the rider" % [def.id, back])
			continue
		if not (has_saddle and has_json):
			# Only the T. rex may be older than this contract; anything else must be saddled or skipped.
			if def.id == &"tyrannosaurus":
				continue
			fails.append("%s has no saddle and is not in mounts_skip.json" % def.id)
			continue
		counts["saddled"] += 1
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/mount.json"))
		if not (j is Dictionary):
			fails.append("%s mount.json is not an object" % def.id)
			continue
		var mj := j as Dictionary
		for k in REQUIRED:
			# The T. rex howdah predates the seat block; it is the reference and must not be edited.
			if not mj.has(k) and not (def.id == &"tyrannosaurus" and k in ["seat", "hips_above_socket_m"]):
				fails.append("%s mount.json lacks %s" % [def.id, k])
		if mj.has("rider_offset") and (mj["rider_offset"] as Array).size() != 16:
			fails.append("%s rider_offset is not 16 floats" % def.id)
		if mj.has("rider_in_mount") and (mj["rider_in_mount"] as Array).size() != 16:
			fails.append("%s rider_in_mount is not 16 floats" % def.id)
		if mj.has("socket"):
			# The socket must be a bone the species' GLB actually has, or the rider can never attach.
			var inst := (load(glb) as PackedScene).instantiate()
			var sk := inst.find_child("Skeleton3D", true, false) as Skeleton3D
			if sk == null:
				fails.append("%s GLB has no Skeleton3D" % def.id)
			elif sk.find_bone(str(mj["socket"])) < 0:
				fails.append("%s socket %s is not a bone of its GLB" % [def.id, mj["socket"]])
			inst.free()
		# The saddle must be skinned to that skeleton's bones (names shared with the creature) and be small.
		var pin := (load(dir + "/saddle.glb") as PackedScene).instantiate()
		var psk := pin.find_child("Skeleton3D", true, false) as Skeleton3D
		var meshes := pin.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			fails.append("%s saddle.glb has no mesh" % def.id)
		else:
			var tris := 0
			for node in meshes:
				var mi := node as MeshInstance3D
				if mi.mesh == null:
					continue
				for surf in mi.mesh.get_surface_count():
					tris += mi.mesh.surface_get_array_len(surf) / 3
			if tris < 400 or tris > 20000:
				fails.append("%s saddle is %d tris, outside 400..20000" % [def.id, tris])
			if psk == null:
				fails.append("%s saddle.glb has no skeleton" % def.id)
			else:
				var names := {}
				for i in psk.get_bone_count():
					names[psk.get_bone_name(i)] = true
				if not names.has(str(mj.get("socket", ""))):
					fails.append("%s saddle skeleton lacks the socket bone %s" % [def.id, mj.get("socket", "")])
				if not names.has("Neck") and def.id != &"tyrannosaurus":
					fails.append("%s saddle skeleton lacks Neck (reins)" % def.id)
		pin.free()
		print("[tmount] %s saddle ok: socket=%s seat=%s hips_above_socket=%s" % [
			def.id, mj.get("socket"), str(mj.get("seat")), str(mj.get("hips_above_socket_m"))])
	# The reference saddle must still be there, and the T. rex must still be a mount.
	var trex = Data.creature(&"tyrannosaurus")
	if trex == null or not (&"mount" in trex.tamed_role):
		fails.append("tyrannosaurus is no longer a mount")
	for f in ["res://assets/creatures/tyrannosaurus/mount/saddle.glb", "res://assets/creatures/tyrannosaurus/mount/mount.json"]:
		if not FileAccess.file_exists(f):
			fails.append("T. rex saddle missing: %s" % f)
	if counts["saddled"] < 5:
		fails.append("only %d species carry a saddle (need at least 5)" % counts["saddled"])
	# An empty skip list is fine: the owner had the one small mount (zebraceratops) scaled up and saddled.
	print("[tmount] saddled=%d skipped=%d" % [counts["saddled"], counts["skipped"]])
	if fails.is_empty():
		# The shared gate and every other t_*.gd print the bracketed form; keep the old line too for the
		# reports that quote it.
		print("[t_mounts] PASS")
		print("PASS t_mounts")
		quit(0)
		return
	for f in fails:
		print("[tmount] FAIL %s" % f)
	quit(1)
