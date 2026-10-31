extends Node3D
## WEAK SPOTS review shots, self-quitting. The hitbox debug view (H): hurtboxes green, crit spots magenta, on six
## species; then, from the game camera, the survivor's auto-attack on a velociraptor until a swing lands in its head
## spot (the WEAK SPOT float, the gold burst and flash, the spot glow). Saves DIR/<species>.png and DIR/crit_landing.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=critspot_lab --out=DIR

const SPECIES := [&"velociraptor", &"tyrannosaurus", &"ankylosaurus", &"stegosaurus", &"triceratops", &"woolly_rhino"]

var _out := ""
var _caption: Label

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("critspot_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.god_mode = true
	CombatTuning.force_accuracy = 1.0
	CombatTuning.force_dodge = 0.0
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=critspot_lab")
	_run.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[critspot_lab] saved %s/%s.png" % [_out, name])

func _run() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	var game_cam := kit["cam"] as Camera3D
	(kit["ui"] as CanvasLayer).visible = false
	game_cam.current = false
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.current = true
	player.global_position = Vector3(30, player.global_position.y, 30)  # out of the way
	Hitbox.debug_draw = true
	for id in SPECIES:
		var c := _spawn(id, Vector3.ZERO)
		for _f in 10:
			await get_tree().physics_frame
		# Frame the whole body (its hurtboxes) from three-quarter front-left and a little above.
		var box := AABB(c.global_position, Vector3.ZERO)
		for cap in Hurtboxes.of(c).world_capsules():
			box = box.expand(cap[0]).expand(cap[1])
		var d := maxf(3.0, box.get_longest_axis_size() * 0.95)
		var mid := box.get_center()
		cam.look_at_from_position(mid + Vector3(-d * 0.8, d * 0.12, -d * 0.65), mid)  # low, so the bellies and throats show
		var names := []
		for s in CritSpots.world(c):
			names.append("%s x%.1f" % [s["name"], s["mult"]])
		_caption.text = "%s crit spots (magenta): %s" % [id, ", ".join(names)]
		await get_tree().process_frame
		await _snap(str(id))
		c.queue_free()
		for _f in 3:
			await get_tree().physics_frame
	await _crit_landing(player, game_cam, cam)
	Hitbox.debug_draw = false
	Game.god_mode = false
	get_tree().quit(0)

## The real auto-attack from the game camera until one swing lands in the velociraptor's head spot; she steps
## around it between tries. The plates float and the camera shake are the game's own.
func _crit_landing(player: Player, game_cam: Camera3D, cam: Camera3D) -> void:
	cam.current = false
	Hitbox.debug_draw = false  # the game view: the float, the gold burst and the spot glow, no debug lines
	game_cam.current = true
	(game_cam as IsoCamera).size = (game_cam as IsoCamera).min_size  # zoomed in, so the float and the burst read
	(game_cam.get_parent().get_node("UI") as CanvasLayer).visible = true
	var c := _spawn(&"velociraptor", Vector3(0, 0, 0))
	var landed := [false]
	player.hunt.hit_landed.connect(func(t: Creature) -> void:
		if t == c and t.has_meta(CritSpots.FOUND_META) and not landed[0]:
			landed[0] = true
			_caption.text = "survivor swing lands in the velociraptor's head: WEAK SPOT, x%.1f" % CritSpots.world(c)[0]["mult"]
			get_tree().paused = true)
	var tries := 0
	while not landed[0] and tries < 24:
		c.health.hp = c.health.max_hp
		var ang := TAU * float(tries) / 8.0
		player.global_position = Vector3(sin(ang) * 1.4, player.global_position.y, -cos(ang) * 1.4 - 0.6)
		player.hunt.start(c)
		var f := 0
		while not landed[0] and f < 90:
			await get_tree().physics_frame
			f += 1
		tries += 1
	if not landed[0]:
		# No natural head hit in 24 tries: land one through the same code with the spot's hit, and say so.
		_caption.text = "SCRIPTED (no natural head hit in %d tries): weak-spot swing on the velociraptor head" % tries
		player.hunt.land_hit(c, null, CritSpots.world(c)[0])
		get_tree().paused = true
	print("[critspot_lab] crit landing after %d tries, natural=%s" % [tries, landed[0]])
	for _f in 4:
		await get_tree().process_frame
	await _snap("crit_landing")
	get_tree().paused = false

func _spawn(id: StringName, at: Vector3) -> Creature:
	var c := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
	add_child(c)
	c.global_position = at
	c.spawn(Data.creature(id))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.health.setup(1e9)
	return c
