class_name SurvivorStage
extends SubViewportContainer
## Character creation's live 3D survivor: the real model playing its idle clip in its own world, on a
## dark stage with a soft key light, a fill, a warm rim and a floor that takes the shadow. Drag to turn
## it. It wears the body regions and armour pieces through PlayerEquipment, the same skeleton path the
## player's armour slots use, so the preview can try a kit on (preview only, nothing is given).

## Radians per dragged pixel.
const TURN_PER_PX := 0.012
## Fixed framing for the default height, so a taller or shorter survivor reads as one. A little above
## the survivor and looking down (as the reference does), so the floor fills the frame: no horizon.
const CAMERA_AT := Vector3(0.0, 2.3, -6.4)
const LOOK_AT := Vector3(0.0, 0.85, 0.0)

var viewport: SubViewport
var rig: RiggedModel
var pivot: Node3D
var camera: Camera3D
var equipment: PlayerEquipment
## The kit the preview wears ("" = the base clothes).
var outfit := ""
var _drag := false

func _init() -> void:
	name = "SurvivorStage"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP

## Built once in the tree: RiggedModel sizes the mesh from its global transform.
func _ready() -> void:
	if viewport != null:
		return
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.115, 0.115, 0.115)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.environment.ambient_light_energy = 0.55
	# Depth fog in the backdrop's colour from just behind the survivor: the far floor fades into the
	# backdrop (no horizon line), the survivor and the shadow stay clear.
	env.environment.fog_enabled = true
	env.environment.fog_mode = Environment.FOG_MODE_DEPTH
	env.environment.fog_light_color = env.environment.background_color
	env.environment.fog_density = 1.0
	env.environment.fog_depth_begin = 9.0
	env.environment.fog_depth_end = 40.0
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, 150.0, 0.0)  # high, from the front-left: the shadow falls back-right
	key.light_energy = 1.15
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 12.0
	viewport.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.8, 1.6, -2.2)  # screen right (the camera looks down +Z)
	fill.omni_range = 6.0
	fill.light_energy = 0.45
	viewport.add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 2.4, 1.6)
	rim.omni_range = 5.0
	rim.light_energy = 0.7
	rim.light_color = Color(1.0, 0.82, 0.62)  # the reference's warm back glow
	viewport.add_child(rim)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.105, 0.1, 0.095)
	mat.roughness = 1.0
	plane.material = mat
	floor_mesh.mesh = plane
	floor_mesh.name = "Stage"
	viewport.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.current = true
	camera.transform = Transform3D(Basis.looking_at(LOOK_AT - CAMERA_AT), CAMERA_AT)
	viewport.add_child(camera)
	pivot = Node3D.new()
	pivot.name = "Turntable"
	pivot.rotation_degrees.y = -14.0  # a touch of three-quarter, like the reference
	viewport.add_child(pivot)
	rig = CharacterLook.build_rig(pivot, "stage")
	equipment = PlayerEquipment.new()
	equipment.name = "PreviewEquipment"
	viewport.add_child(equipment)
	equipment.setup(rig, Inventory.new())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		CharacterLook.release(rig)

func apply_look(look: Dictionary) -> void:
	CharacterLook.apply(rig, look)

## Tries a kit on (every piece it has) or, with "", goes back to the base clothes.
func wear(kit: String) -> void:
	outfit = kit
	for slot in PlayerEquipment.PIECE_FOR_SLOT:
		if kit == "":
			equipment.unequip(slot)
		else:
			equipment.equip(slot, "%s/%s" % [kit, PlayerEquipment.PIECE_FOR_SLOT[slot]])
	CharacterLook.refresh(rig)

## Mouse drags and touch drags turn the survivor. A touch also arrives as an emulated mouse event
## (device -1): only the touch one turns.
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
