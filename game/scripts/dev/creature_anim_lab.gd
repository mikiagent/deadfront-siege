extends Node3D
## Showcase for W1-CANIM: four species walk lanes at walk speed then run speed through
## CreatureAnim.set_move_speed (feet should stay planted), then the T. rex plays its authored
## sleep, feed and tail_swipe. Side camera. Headless it prints one [canimlab] line per phase.
## Run: Godot --path game -- --lab=creature_anim_lab [--shot=out.png --shot-delay=3]

const LANES := [[&"velociraptor", 0.0, -8.0], [&"protoceratops", 4.0, 3.0], [&"megaloceros", 8.0, -3.0], [&"tyrannosaurus", 15.0, 4.0]]  # id, lane z, start x
const SPAN := 15.0  # walkers wrap between -SPAN and +SPAN on x
const PHASE_S := 5.0
## ASSUMPTION: walk speed = 40 % of the listed speed (same as tests/t_canim.gd).
const WALK_FRAC := 0.4
const REX_CLIPS: Array[StringName] = [&"sleep", &"feed", &"tail_swipe"]

var _walkers: Array[Creature] = []
var _labels: Array[Label3D] = []
var _t := 0.0
var _phase := -1

func _ready() -> void:
	var kit := LabKit.build(self, 60.0)
	var player := kit["player"] as Player
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 5.0, -15.0), Vector3(0.0, 2.5, 6.0))
	cam.current = true
	for lane in LANES:
		var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
		add_child(c)
		c.position = Vector3(lane[2], 0.0, lane[1])
		c.rotation.y = -PI / 2.0  # face +X
		c.spawn(Data.creature(lane[0]))
		c.set_physics_process(false)  # the lab moves them; no AI, no nav
		if c.brain:
			c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		c.label.visible = false
		var tag := Label3D.new()
		tag.font_size = 32
		tag.pixel_size = 0.008
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.outline_size = 10
		tag.no_depth_test = true
		add_child(tag)
		_walkers.append(c)
		_labels.append(tag)
	print("[boot] lab=creature_anim_lab")

func _process(delta: float) -> void:
	_t += delta
	var phase := int(_t / PHASE_S) % 3
	for i in _walkers.size():
		var c := _walkers[i]
		var top := c.def.move_speed_mps
		var v := 0.0
		if phase < 2:
			v = top * (WALK_FRAC if phase == 0 else 1.0)
			c.anim.set_move_speed(v)
			c.position.x += v * delta
			if c.position.x > SPAN:
				c.position.x -= SPAN * 2.0
		elif phase != _phase:
			# Rest phase: the T. rex shows its authored clips, the others idle.
			c.anim.play_idle()
			if c.def.id == &"tyrannosaurus":
				_rex_clips(c)
		var gait := c.anim.current_clip
		_labels[i].text = "%s  %s x%.2f  %.1f m/s" % [c.def.id, gait, c.anim.cadence(gait), v]
		_labels[i].position = c.position + Vector3(0.0, c.def.height_meters + 0.8, 0.0)
	if phase != _phase:
		_phase = phase
		var parts: Array[String] = []
		for l in _labels:
			parts.append(l.text)
		print("[canimlab] t=%.1f %s" % [_t, " | ".join(parts)])

func _rex_clips(rex: Creature) -> void:
	for k in REX_CLIPS.size():
		get_tree().create_timer(k * PHASE_S / REX_CLIPS.size()).timeout.connect(func () -> void:
			if _phase == 2:
				rex.anim.play_clip(REX_CLIPS[k], true)
		)
	get_tree().create_timer(PHASE_S - 0.1).timeout.connect(func () -> void: rex.anim.play_clip(&"idle"))
