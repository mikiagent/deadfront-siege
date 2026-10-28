class_name AnimalStage
extends SubViewportContainer
## The Animals screen's portrait (§7 E1): the pet's own model, in its own natural colours, playing
## idle on a dark stage in three-quarter view. Drag to turn it. Framed from the species' length and
## height, so a compy and a zebraceratops both fill the frame. Built the way Creature.spawn builds
## its view (CreatureView.setup + coloration + CreatureClips), with no body, brain or physics.

const TURN_PER_PX := 0.012
const BACKDROP := Color(0.07, 0.11, 0.15)

var viewport: SubViewport
var pivot: Node3D
var camera: Camera3D
var view: CreatureView
var shown_uid := ""
var _drag := false

func _init() -> void:
	name = "AnimalStage"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	if viewport != null:
		return
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.68, 0.75)
	env.environment.ambient_light_energy = 0.6
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, 145.0, 0.0)
	key.light_energy = 1.2
	viewport.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.0, 2.5, 3.0)
	rim.omni_range = 9.0
	rim.light_energy = 0.8
	rim.light_color = Color(1.0, 0.84, 0.62)
	viewport.add_child(rim)
	camera = Camera3D.new()
	camera.fov = 28.0
	camera.current = true
	viewport.add_child(camera)
	pivot = Node3D.new()
	pivot.name = "Turntable"
	viewport.add_child(pivot)

## Shows `rec` (same uid: keeps the current model and its turn).
func show_pet(rec: PetRecord) -> void:
	if viewport == null:
		_ready()
	var key := rec.uid if rec else ""
	if key == shown_uid and view != null:
		return
	shown_uid = key
	if view:
		view.queue_free()
		view = null
	var def := Data.creature(rec.species) if rec else null
	if def == null:
		return
	view = CreatureView.new()
	view.name = "View"
	pivot.add_child(view)
	view.coloration = rec.coloration()
	view.setup(def, rec.variant)
	var ap := view.animation_player()
	if ap:
		CreatureClips.attach(ap, view, def)
		if ap.has_animation(&"idle"):
			ap.play(&"idle")
	pivot.rotation_degrees.y = -35.0  # three-quarter, head to screen left like the canvas
	_frame(def)

## Camera at a distance that fits the longer of length and height, aimed at mid-body.
func _frame(def: CreatureDef) -> void:
	var span := maxf(def.real_length_m, def.height_meters * 1.4)
	var aim := Vector3(0.0, def.height_meters * 0.5, 0.0)
	var dist := span * 0.5 / tan(deg_to_rad(camera.fov * 0.5)) * 0.95
	var from := aim + Vector3(0.0, def.height_meters * 0.35, dist)
	camera.transform = Transform3D(Basis.looking_at(aim - from), from)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		pivot.rotate_y((event as InputEventMouseMotion).relative.x * TURN_PER_PX)
		accept_event()
	elif event is InputEventScreenDrag:
		pivot.rotate_y((event as InputEventScreenDrag).relative.x * TURN_PER_PX)
		accept_event()
