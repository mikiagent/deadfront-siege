class_name StationState
extends Node3D
## A stand-and-craft station shows what is happening at it (owner 2026-10-28: "The state of the stations
## shows what is happening at the station"): data/station_state.json `busy` parts (the stone grill's
## spit and meat, the forge's hot coals, glow and sparks) show only while a craft runs there, `idle`
## parts only while it is empty. Attached by CraftStation._ready for kinds with a row.

const NODE_NAME := "StationState"
const PATH := "res://data/station_state.json"
const POLL_S := 0.2

static var _rows: Dictionary = {}
static var _all: Dictionary = {}
## shortcut: labs only (stationstate_lab's busy shot shows every station working at once; one
## survivor can only run one craft). Never set in play.
static var lab_force_busy: bool = false

var station_id: StringName = &""
var cfg: Dictionary = {}
var _busy_nodes: Array[Node3D] = []
var _idle_nodes: Array[Node3D] = []
var _shown: int = -1 # -1 unknown, 0 idle, 1 busy
var _poll: float = 0.0

static func config_for(sid: StringName) -> Dictionary:
	if _rows.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_all = parsed as Dictionary
			_rows = _all.get("stations", {})
	var row: Variant = _rows.get(str(sid), {})
	return row if row is Dictionary else {}

## The survivor's work loop at a station kind (station_state.json `work_anim`), &"" for none.
static func work_kind(sid: StringName) -> StringName:
	config_for(sid)
	var m: Variant = _all.get("work_anim", {})
	return StringName(str((m as Dictionary).get(str(sid), ""))) if m is Dictionary else &""

static func of(host: Node) -> StationState:
	return host.get_node_or_null(NODE_NAME) as StationState if host else null

static func attach_to(host: Node3D, sid: StringName) -> StationState:
	var c := config_for(sid)
	if c.is_empty() or of(host) != null:
		return of(host)
	var st := StationState.new()
	st.name = NODE_NAME
	st.station_id = sid
	st.cfg = c
	host.add_child(st)
	return st

## A craft is running at `host`: a timed job on its ProcessStation, or a survivor's stand-and-craft.
static func host_busy(host: Node) -> bool:
	if lab_force_busy:
		return true
	var ps := ProcessStation.of(host)
	if ps != null and ps.is_active():
		return true
	for p in PlayerRegistry.all():
		var sc: StationCraft = p.station_craft
		if sc != null and sc.crafting and sc.station == host:
			return true
	return false

func is_busy() -> bool:
	return host_busy(get_parent())

func _ready() -> void:
	var host := get_parent()
	# The kind has no model (only the fallback box): its body comes from data.
	var fallback := host.get_node_or_null("FallbackMesh") as Node3D
	if host.get_node_or_null("Prop") == null and cfg.has("body"):
		if fallback:
			fallback.visible = false
		for part: Variant in cfg.get("body", []):
			add_child(_part(part))
	for part: Variant in cfg.get("idle", []):
		var n := _part(part)
		add_child(n)
		_idle_nodes.append(n)
	for part: Variant in cfg.get("busy", []):
		var n := _part(part)
		add_child(n)
		_busy_nodes.append(n)
	var lt: Variant = cfg.get("light")
	if lt is Dictionary:
		var l := OmniLight3D.new()
		l.name = "Glow"
		l.light_color = Color(str((lt as Dictionary).get("color", "#ff7a2a")))
		l.light_energy = float((lt as Dictionary).get("energy", 2.0))
		l.omni_range = float((lt as Dictionary).get("range", 3.0))
		l.position = ProcessFx.vec3((lt as Dictionary).get("pos"), Vector3(0, 1, 0))
		add_child(l)
		_busy_nodes.append(l)
	var sp: Variant = cfg.get("sparks")
	if sp is Dictionary:
		var fx := _sparks()
		fx.position = ProcessFx.vec3((sp as Dictionary).get("pos"), Vector3(0, 1, 0))
		add_child(fx)
		_busy_nodes.append(fx)
	sync()

func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_S
	sync()

## Show the busy or idle parts for the station's state now (tests call it directly).
func sync() -> void:
	var b := 1 if is_busy() else 0
	if b == _shown:
		return
	_shown = b
	for n in _busy_nodes:
		n.visible = b == 1
		if n is CPUParticles3D:
			(n as CPUParticles3D).emitting = b == 1
	for n in _idle_nodes:
		n.visible = b == 0

func busy_nodes() -> Array[Node3D]:
	return _busy_nodes

## The floating status line over a field, pen or worksite ("4m 13s", "Taming 24m 10s", "Building 40%"),
## sized like the other world labels (field catapult, comm center): world-sized, billboarded.
static func floating_label(node_name: String, y: float) -> Label3D:
	var l := Label3D.new()
	l.name = node_name
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 36
	l.pixel_size = 0.01
	l.outline_size = 8
	l.modulate = Color(1.0, 0.97, 0.88)
	l.outline_modulate = Color(0.12, 0.09, 0.05, 0.9)
	l.no_depth_test = true  # a tall tame or a roof must not cut the line
	l.position = Vector3(0.0, y, 0.0)
	return l

static func _part(part: Variant) -> MeshInstance3D:
	var d: Dictionary = part if part is Dictionary else {}
	var size := ProcessFx.vec3(d.get("size"), Vector3(0.2, 0.2, 0.2))
	var mi := MeshInstance3D.new()
	mi.name = str(d.get("name", "Part"))
	match str(d.get("mesh", "box")):
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = size.x
			c.bottom_radius = size.x
			c.height = size.y
			c.radial_segments = 8
			mi.mesh = c
		"capsule":
			var cap := CapsuleMesh.new()
			cap.radius = size.x
			cap.height = maxf(size.y, size.x * 2.0)
			cap.radial_segments = 10
			mi.mesh = cap
		"sphere":
			var s := SphereMesh.new()
			s.radius = size.x
			s.height = size.y
			mi.mesh = s
		_:
			var b := BoxMesh.new()
			b.size = size
			mi.mesh = b
	mi.position = ProcessFx.vec3(d.get("pos"), Vector3.ZERO)
	mi.rotation_degrees = ProcessFx.vec3(d.get("rot"), Vector3.ZERO)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(str(d.get("color", "#888888")))
	mat.roughness = 0.9
	if d.has("emit"):
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = float(d["emit"])
	mi.material_override = mat
	return mi

## Forge sparks: small hot points kicked up and falling back.
static func _sparks() -> CPUParticles3D:
	var fx := CPUParticles3D.new()
	fx.name = "Sparks"
	fx.amount = 24
	fx.lifetime = 0.9
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fx.emission_box_extents = Vector3(0.25, 0.02, 0.2)
	fx.direction = Vector3.UP
	fx.spread = 35.0
	fx.initial_velocity_min = 1.2
	fx.initial_velocity_max = 2.4
	fx.gravity = Vector3(0, -3.0, 0)
	fx.scale_amount_min = 0.6
	fx.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(1.0, 0.75, 0.3)
	quad.material = mat
	fx.mesh = quad
	fx.emitting = false
	return fx
