extends Node3D
## MEGARUN review shots, self-quitting: the megaloceros stag, doe and an alpha stag gallop in a straight line at their
## run speed through the game's own stride match (CreatureAnim.set_move_speed), filmed side-on by a camera that
## follows the body. Every frame a planted hoof (within 3 cm of its lowest) drops a small disc on the ground where it
## stands, so a slipping hoof smears its discs into a streak. Saves DIR/run_<variant>.png (six frames over one stride).
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=megarun_lab --out=DIR

const TOES := ["FrontFoot.L", "FrontFoot.R", "BackFoot.L", "BackFoot.R"]
const COLS := [Color(0.95, 0.3, 0.2), Color(0.95, 0.75, 0.2), Color(0.2, 0.6, 0.95), Color(0.3, 0.9, 0.4)]
const DT := 1.0 / 60.0

var _out := ""
var _caption: Label
var _cam: Camera3D
var _disc: CylinderMesh
var _mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("megarun_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	_shots.call_deferred()

func _shots() -> void:
	var kit := LabKit.build(self, 600.0)
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	(kit["player"] as Node3D).global_position = Vector3(-200, 0.1, 200)
	_cam = Camera3D.new()
	_cam.fov = 36.0
	add_child(_cam)
	_cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	_disc = CylinderMesh.new()
	_disc.top_radius = 0.12
	_disc.bottom_radius = 0.12
	_disc.height = 0.01
	for c in COLS:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		_mats.append(m)
	var lane := 0
	for row in [[&"stag", false], [&"doe", false], [&"stag", true]]:
		await _film(row[0], row[1], Vector3(-150.0 + 60.0 * lane, 0, 250))
		lane += 1
	get_tree().quit(0)

func _film(v: StringName, alpha: bool, at: Vector3) -> void:
	var c: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	add_child(c)
	c.global_position = at
	var g := CreatureGenetics.new()
	if alpha:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		g.make_alpha(rng)
	c.genetics = g
	c.spawn(Data.creature(&"megaloceros"), v, 0, null, 0, &"aggressive")
	c.set_physics_process(false)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	c.rotation = Vector3.ZERO
	var mps: float = c.move_speed_mps() * Creature.run_speed_mult()
	c.anim.set_move_speed(mps)
	var skel: Skeleton3D = c.view.rig.skeleton
	var bones: Array[int] = []
	for b in TOES:
		bones.append(skel.find_bone(b))
	var lows: Array[float] = [INF, INF, INF, INF]
	var label := "%s%s" % [v, " ALPHA" if alpha else ""]
	var cycle: float = c.anim.player.get_animation(&"run").length / maxf(0.01, c.anim.cadence(&"run"))
	var warm := 150
	var frames: Array[Image] = []
	var shots := 6
	var next_shot := 0
	var t := 0.0
	var k := 0
	while next_shot < shots:
		c.global_position = at + Vector3(0, 0, -mps * DT * k)
		c.anim.tree.advance(DT)
		for j in 4:
			var p := skel.global_transform * skel.get_bone_global_pose(bones[j]).origin
			if k < warm:
				lows[j] = minf(lows[j], p.y)
			elif p.y <= lows[j] + 0.03:
				var d := MeshInstance3D.new()
				d.mesh = _disc
				d.material_override = _mats[j]
				add_child(d)
				d.global_position = Vector3(p.x, 0.005, p.z)
		var h: float = c.def.height_meters * c.size_scale()
		_cam.look_at_from_position(c.global_position + Vector3(h * 3.2, h * 0.55, -h * 0.25), c.global_position + Vector3(0, h * 0.55, -h * 0.25))
		_caption.text = "megaloceros %s  run  size %.2f  %.1f m/s  cadence %.2f\ndiscs = planted hooves: FL red, FR yellow, HL blue, HR green" % [label, c.size_scale(), mps, c.anim.cadence(&"run")]
		if k >= warm + 60:
			t = (k - warm - 60) * DT
			if t >= next_shot * cycle / shots:
				await RenderingServer.frame_post_draw
				frames.append(get_viewport().get_texture().get_image())
				next_shot += 1
				k += 1
				continue
		await get_tree().process_frame
		k += 1
	var w := frames[0].get_width()
	var hh := frames[0].get_height()
	var sheet := Image.create(w * 3, hh * 2, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, w, hh), Vector2i(w * (i % 3), hh * (i / 3)))
	sheet.save_png("%s/run_%s%s.png" % [_out, v, "_alpha" if alpha else ""])
	print("[megarun_lab] saved run_%s%s.png (%d frames over one %.2f s stride)" % [v, "_alpha" if alpha else "", frames.size(), cycle])
	c.queue_free()
