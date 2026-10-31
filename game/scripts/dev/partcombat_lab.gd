extends Node3D
## PARTCOMBAT review shots, self-quitting. Run windowed off-screen:
##   Godot --path game --position 6000,3000 -- --skip-charcreate --lab=partcombat_lab --out=DIR [--poses]
## --poses: each weapon's clips on the survivor at a few points, from the side and the front (DIR/pose_<clip>_<k>.png).
## Default: the owner's shots at 844x390 2x (the window): the section picker on the target card, a Wound and an Armor
## break built with the heavy blades, aiming the bow and an arrow hit (DIR/<n>_<what>.png).

const WEAPONS := {
	&"iron_slab_blade": [&"wpn_1h_carry_idle", &"wpn_1h_carry_walk", &"wpn_1h_cross1", &"wpn_1h_cross2", &"wpn_1h_cross3", &"wpn_1h_impale", &"wpn_1h_chop"],
	&"steel_greatblade": [&"wpn_2h_carry_idle", &"wpn_2h_carry_run", &"wpn_2h_slam", &"wpn_2h_sweep"],
	&"pro_bow": [&"wpn_bow_carry_idle", &"wpn_bow_draw", &"wpn_bow_aim", &"wpn_bow_release"],
}

var _out := ""
var _caption: Label
var player: Player
var game_cam: Camera3D
var cam: Camera3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("partcombat_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.god_mode = true
	CombatTuning.force_accuracy = 1.0
	CombatTuning.force_dodge = 0.0
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=partcombat_lab")
	_run.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[partcombat_lab] saved %s/%s.png" % [_out, name])

func _run() -> void:
	var kit := LabKit.build(self, 80.0)
	player = kit["player"] as Player
	game_cam = kit["cam"] as Camera3D
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 64)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	if "--poses" in OS.get_cmdline_user_args():
		await _poses(kit)
	else:
		await _shots(kit)
	Game.god_mode = false
	get_tree().quit(0)

func equip(id: StringName) -> ItemStack:
	var s := ItemStack.make(id, 1, {}, 30)
	player.inventory.add(s)
	player.inventory.equip(Inventory.slot_for(s.def()), id)
	if s.def() and s.def().ammo_id != &"":
		player.inventory.add(ItemStack.make(s.def().ammo_id, 200))
	return s

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame

func _poses(kit: Dictionary) -> void:
	(kit["ui"] as CanvasLayer).visible = false
	game_cam.current = false
	cam.current = true
	var at := player.global_position
	player.face_world(at + Vector3(0, 0, -10))
	await _frames(20)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weapon="):
			only = a.substr(9)
	for id in WEAPONS:
		if only != "" and str(id) != only:
			continue
		equip(id)
		if player.station_craft:
			player.station_craft._sync_hand_tool()
		for clip in WEAPONS[id]:
			for k in 4:
				var frac: float = [0.15, 0.4, 0.6, 0.85][k]
				var ap := player.rig.anim_player
				player.anim.play_clip(clip, true)
				ap.speed_scale = 1.0
				ap.seek(ap.current_animation_length * frac, true)
				ap.speed_scale = 0.0
				await _frames(2)
				print("[partcombat_lab] pose %s playing=%s held=%s" % [clip, ap.current_animation, player.station_craft.held_model_id() if player.station_craft else &"-"])
				var mid := at + Vector3(0, 1.0, 0)
				var side := Vector3.RIGHT  # she faces -Z (face_world below): her right is +X
				cam.look_at_from_position(mid + side * 3.6 + Vector3(0, 0.5, 0), mid)
				_caption.text = "%s  %s  %.0f%%  (her right side)" % [id, clip, frac * 100]
				await _snap("pose_%s_%d_side" % [clip, k])
				var fwd := Vector3.FORWARD
				cam.look_at_from_position(mid + fwd * 3.0 + side * 2.0 + Vector3(0, 0.8, 0), mid)
				_caption.text = "%s  %s  %.0f%%  (front)" % [id, clip, frac * 100]
				await _snap("pose_%s_%d_front" % [clip, k])

func _shots(_kit: Dictionary) -> void:
	pass
