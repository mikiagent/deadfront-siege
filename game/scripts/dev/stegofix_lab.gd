extends Node3D
## STEGOFIX review shots, self-quitting.
##   --out=DIR (required) --mode=sheet: both stegosaurus variants (graded left, ochre right) side by side with the
##     survivor between them; every clip is posed at 30 % and 60 % and saved as DIR/<clip>_30.png, _60.png.
##   --mode=world [--island=temperate_45]: loads the island, waits for its spawns, frames the nearest stegosaurus
##     group with the game's iso camera and saves DIR/world_wide.png and DIR/world_close.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=stegofix_lab --out=...

const VARIANTS: Array[StringName] = [&"graded", &"ochre"]
const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"walk_back", &"strafe_left", &"strafe_right", &"attack_primary",
	&"attack_heavy", &"kick", &"charge", &"hit_react", &"alert", &"knockdown", &"death"]

var _out := ""
var _mode := "sheet"
var _island := "temperate_45"
var _views: Array = []
var _caption: Label

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--mode="):
			_mode = a.substr(7)
		elif a.begins_with("--island="):
			_island = a.substr(9)
	if _out == "":
		push_error("stegofix_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=stegofix_lab mode=%s" % _mode)
	if _mode == "world":
		_world.call_deferred()
	else:
		_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[stegofix] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	player.global_position = Vector3(0, 0.1, 5.5)
	player.rotation.y = PI
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 4.5, 23.0), Vector3(0.0, 3.6, 0.0))  # lit side
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(_caption)
	var def: CreatureDef = Data.creature(&"stegosaurus")
	for i in VARIANTS.size():
		var v: CreatureView = CreatureView.new()
		add_child(v)
		v.setup(def, VARIANTS[i])
		v.apply_coloration(CreatureColoration.neutral())
		v.position = Vector3(-7.5 if i == 0 else 7.5, 0.0, 0.0)
		v.rotation.y = PI / 2.0  # side profile to the camera
		_views.append(v)
	for _f in 10:
		await get_tree().process_frame
	for clip in CLIPS:
		for pct in [30, 60]:
			for v in _views:
				var ap: AnimationPlayer = v.rig.anim_player
				ap.play(clip)
				ap.seek(ap.get_animation(clip).length * pct / 100.0, true)
				ap.pause()
			_caption.text = "stegosaurus  %s %d%%   left: graded   right: ochre   (survivor for scale)" % [clip, pct]
			await get_tree().process_frame
			await _snap("%s_%d" % [clip, pct])
	get_tree().quit(0)

func _world() -> void:
	var kit := LabKit.build(self, 20.0)
	var player: Player = kit["player"]
	var cam: IsoCamera = kit["cam"]
	(kit["nav"] as Node3D).visible = false
	World.harvested.clear()
	World.load_island(self, StringName(_island), Vector3(0, 1, 0), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.free()
	var stegos: Array = []
	for _f in 600:
		await get_tree().process_frame
		stegos = get_tree().get_nodes_in_group(&"creatures").filter(func(c): return c.def and c.def.id == &"stegosaurus")
		if not stegos.is_empty():
			break
	if stegos.is_empty():
		print("[stegofix] FAIL no stegosaurus spawned on %s" % _island)
		get_tree().quit(1)
		return
	# The biggest herd (most likely to hold both variants).
	var group: Array = []
	for s in stegos:
		var near := stegos.filter(func(c): return c.global_position.distance_to(s.global_position) < 40.0)
		if near.size() > group.size():
			group = near
	print("[stegofix] all variants: %s" % " ".join(stegos.map(func(c): return str(c.variant))))
	var centre := Vector3.ZERO
	var looks: Array[String] = []
	for c in group:
		centre += c.global_position
		looks.append("%s(glb=%s boxes=%d)" % [c.variant, c.view.using_glb, c.view.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.mesh is BoxMesh).size()])
		c.set_physics_process(false)  # hold the pose for the shot
	centre /= group.size()
	print("[stegofix] island=%s stegosaurs=%d group=%d %s" % [_island, stegos.size(), group.size(), " ".join(looks)])
	player.global_position = centre + Vector3(9, 1, 9)
	var focus := Node3D.new()
	add_child(focus)
	focus.global_position = centre
	cam._target = focus
	cam.size = 46.0
	cam._snap()
	# Staged: turn the herd broadside to the camera so the shot shows plates and legs, not tails.
	var side := cam.global_transform.basis.x
	for c in group:
		c.rotation.y = atan2(side.x, side.z)
	for _f in 30:
		await get_tree().process_frame
	_close_maps()
	await _snap("world_wide")
	cam.size = 22.0
	cam._snap()
	for _f in 10:
		await get_tree().process_frame
	_close_maps()
	await _snap("world_close")
	get_tree().quit(0)

## The atlas can pop open while the island settles (the lab drops the survivor next to the herd); it is not the shot.
func _close_maps() -> void:
	for m in get_tree().root.find_children("*", "MapScreen", true, false):
		if (m as CanvasItem).visible:
			m.close()
