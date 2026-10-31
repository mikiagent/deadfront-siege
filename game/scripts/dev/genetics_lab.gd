extends Node3D
## --lab=genetics_lab: GENETICS + ALPHAS review shots (owner 2026-10-28). Five wild deinonychus with
## their own size and natural colours in a line, then a normal one beside an alpha, from a side lab
## camera and from the game's iso camera (plates on), then the Animals info card of a tamed alpha.
## Windowed: --resolution 1600x900 -- --lab=genetics_lab --shot-dir=DIR [--canvas=844x390]
## Prints "[genetics_lab] shot <path>" per shot, then "[genetics_lab] DONE".

const SPECIES := &"deinonychus"
const SIZES: Array[float] = [0.86, 0.93, 1.0, 1.07, 1.14]
const SEEDS: Array[int] = [11, 23, 5, 40, 77]

var _out := ""
var _phone := false
var _player: Player
var _hud: HuntHud
var _iso: Camera3D
var _cam: Camera3D
var _labels: Array[Label3D] = []
var _lineup: Array[Creature] = []
var _pair: Array[Creature] = []

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("genetics")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			DisplayMode.canvas_override = Vector2i(int(wh[0]), int(wh[1]))
			DisplayMode.fit(get_tree().root)
			_phone = true
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 120.0)
	_player = kit["player"]
	_iso = kit.get("cam") as Camera3D
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	Game.time_of_day = 0.35
	var def := Data.creature(SPECIES)
	var spacing := def.real_length_m * 0.56
	var seeds := _varied_seeds(def)
	for i in SIZES.size():
		var g := CreatureGenetics.for_species(def, _rng(seeds[i]), _rng(seeds[i] * 7 + 1))
		g.size = SIZES[i]
		var at := Vector3((float(i) - 2.0) * spacing, 0.0, -30.0)
		var c := _spawn(def, g, at)
		_lineup.append(c)
		_label("%s  %s" % [CreatureView.size_text(g.size), str(g.coloration.pattern) if g.coloration.pattern != &"" else "plain"], at + Vector3(0, def.height_meters * g.size + 0.8, 0), Color(0.96, 0.96, 0.9))
	var n := CreatureGenetics.for_species(def, _rng(3), _rng(4))
	n.size = 1.0
	var al := CreatureGenetics.for_species(def, _rng(3), _rng(4))
	al.size = 1.0
	al.make_alpha(_rng(9))
	var pn := _spawn(def, n, Vector3(-spacing * 0.6, 0.0, 30.0))
	var pa := _spawn(def, al, Vector3(spacing * 0.75, 0.0, 30.0), true)
	_pair = [pn, pa]
	_label("Normal  %s" % CreatureView.size_text(n.size), pn.global_position + Vector3(0, def.height_meters + 1.2, 0), Color(0.96, 0.96, 0.9))
	_label("ALPHA  %s" % CreatureView.size_text(al.size), pa.global_position + Vector3(0, def.height_meters * al.size + 1.2, 0), Color(1.0, 0.7, 0.3))
	_run.call_deferred()

## Five ordinary wild rolls (no rare morph) that between them show the species' pattern kinds and
## both tones, so the line-up shows the natural range rather than five look-alikes.
func _varied_seeds(def: CreatureDef) -> Array[int]:
	var want: Array[String] = ["stripes", "spots", "", "countershade", "stripes"]
	var morph: Array[String] = ["dark", "pale", "dark", "pale", "pale"]
	var out: Array[int] = []
	var s := 1
	for i in want.size():
		while s < 5000:
			s += 1
			var c := CreatureGenetics.for_species(def, _rng(s), _rng(s * 7 + 1)).coloration
			if not c.rare and str(c.pattern) == want[i] and str(c.morph) == morph[i]:
				out.append(s)
				break
		if out.size() <= i:
			out.append(SEEDS[i])
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _spawn(def: CreatureDef, g: CreatureGenetics, at: Vector3, alpha: bool = false) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = at
	c.genetics = g
	c.alpha_spawn = alpha
	c.spawn(def, &"", 0, null, 0, &"aggressive" if alpha else &"timid")
	c.rotation.y = -PI * 0.5
	if c.label:
		c.label.visible = false
	c.reset_physics_interpolation()
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _label(text: String, at: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.outline_size = 14
	l.position = at
	add_child(l)
	_labels.append(l)

func _side_cam(centre: Vector3, dist: float) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 38.0
		add_child(_cam)
	_cam.global_position = centre + Vector3(0.0, dist * 0.32, dist)
	_cam.look_at(centre + Vector3(0, 1.6, 0), Vector3.UP)
	_cam.current = true

func _plates(on: bool) -> void:
	if Game.creature_ui and is_instance_valid(Game.creature_ui):
		Game.creature_ui.visible = on
	(_hud.get_parent() as CanvasLayer).visible = on

func _run() -> void:
	Game.ensure_creature_plates() # spawn() ran inside the main scene's _ready, before current_scene was set
	await _wait(1.5)
	var def := Data.creature(SPECIES)
	var pre := "phone_" if _phone else ""
	if not _phone:
		_plates(false)
		_side_cam(Vector3(0, 0, -30), def.real_length_m * 2.15)
		await _wait(0.6)
		await _shot("lab_lineup")
		_side_cam(Vector3(0, 0, 30), def.real_length_m * 1.5)
		await _wait(0.4)
		await _shot("lab_alpha_vs_normal")
		Game.time_of_day = 0.92
		await _wait(1.2)
		await _shot("lab_alpha_vs_normal_night")
		Game.time_of_day = 0.35
		await _wait(1.0)
	# The game camera: the survivor beside the pair, plates on (the alpha's says "Alpha Deinonychus").
	for l in _labels:
		l.visible = false
	_cam = null
	_iso.current = true
	_plates(true)
	_player.global_position = Vector3(0.5, 1, 30 + def.real_length_m * 0.35)
	for c in _pair:
		c.note_tapped()
		c.last_damaged_s = Time.get_ticks_msec() / 1000.0
	await _wait(1.2)
	await _shot(pre + "game_alpha_vs_normal")
	_player.global_position = Vector3(0, 1, -30 + def.real_length_m * 0.35)
	for c in _lineup:
		c.note_tapped()
	await _wait(1.2)
	await _shot(pre + "game_lineup")
	# The Animals info card: a tamed alpha, its size and colour swatch.
	var rec := PetRecord.from_def(def, &"", &"", _pair[1].genetics, 35)
	rec.name = "Brute"
	rec.nature = &"aggressive"
	_player.bonded.append(rec)
	var small := PetRecord.from_def(def, &"", &"", _lineup[0].genetics, 12)
	small.nature = &"timid"
	_player.bonded.append(small)
	_hud.open_animals(rec)
	await _wait(1.2)
	await _shot(pre + "card_alpha")
	_hud.get("_animal_screen").call("close_screen")
	for c in _lineup + _pair:
		print("[genetics_lab] %s size=%.2f alpha=%s hp=%.0f atk=%.0f colour=%s name=%s" % [c.def.id, c.size_scale(), c.is_alpha(), c.health.max_hp, c.attack_for(), c.genetics.coloration.label(), CreatureNatures.display_title(c)])
	print("[genetics_lab] DONE")
	get_tree().quit(0)

func _shot(n: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		print("[genetics_lab] no pixels for %s (run windowed)" % n)
		return
	var path := _out.path_join("%s.png" % n)
	img.save_png(path)
	print("[genetics_lab] shot %s" % path)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
