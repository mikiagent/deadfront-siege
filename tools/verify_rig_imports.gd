extends SceneTree
## Run with Godot --headless --path game --script ../tools/verify_rig_imports.gd.
## Uses the production clip loader so the test covers remapping and import.
const MODEL = preload("res://scripts/core/rigged_model.gd")
const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy", &"hit_react", &"knockdown", &"death", &"alert"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var creatures := DirAccess.open("res://assets/creatures")
	var failures: Array[String] = []
	var checked := 0
	for species in creatures.get_directories():
		var folder := "res://assets/creatures/" + species
		var base := folder + "/" + species + ".glb"
		if not ResourceLoader.exists(base):
			continue
		var model: Node3D = MODEL.new()
		root.add_child(model)
		if not model.setup(base, folder + "/anim", "+Z", 1.0, "rig-check"):
			failures.append(species + ": setup failed")
			model.free()
			continue
		for clip in CLIPS:
			if not model.has_clip(clip):
				failures.append(species + ": missing " + clip)
				continue
			var animation: Animation = model.library.get_animation(clip)
			if animation.length <= 0.0:
				failures.append(species + ": zero duration " + clip)
			model.play(clip)
			for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
				model.anim_player.seek(animation.length * fraction, true)
				model.skeleton.force_update_all_bone_transforms()
				for bone in model.skeleton.get_bone_count():
					var pose: Transform3D = model.skeleton.get_bone_global_pose(bone)
					if not pose.is_finite() or absf(pose.basis.determinant()) < 0.00001:
						failures.append(species + ": invalid pose " + clip)
			checked += 1
		model.free()
	if failures.is_empty() and checked > 0:
		print("RIG IMPORT PASS: %d clips through production loader" % checked)
		quit(0)
	else:
		push_error("RIG IMPORT FAIL: " + str(failures))
		quit(1)
