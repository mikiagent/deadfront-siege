class_name RemotePuppet
extends Node3D
## Another player's survivor: the same rigged model and clips as the local Player
## (Player._setup_survivor), moved by relayed presence with 100 ms interpolation, plus a
## nameplate and a short-lived chat bubble.

const LERP_TIME := 0.1
const SNAP_DISTANCE := 15.0  # farther than this between updates is a respawn or recall: jump
const BUBBLE_SECONDS := 6.0

var account_id := 0
var display_name := ""
var anim := ""
var visual: Node3D
var rig: RiggedModel
var bubble: Label3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _from_yaw := 0.0
var _to_yaw := 0.0
var _t := 1.0
var _bubble_left := 0.0

## Call after add_child: the rig measures the mesh in the tree.
func setup(id: int, nm: String, p: Vector3, yaw: float) -> void:
	account_id = id
	display_name = nm
	name = "Remote_%d" % id
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	rig = RiggedModel.new()
	rig.name = "Rig"
	visual.add_child(rig)
	var meta := _survivor_meta()
	var pipeline: Dictionary = meta.get("pipeline", {}) if meta.get("pipeline") is Dictionary else {}
	var height := float(meta.get("height_meters", 1.72))
	if rig.setup(Player.SURVIVOR_BASE_GLB, Player.SURVIVOR_ANIM_DIR, str(pipeline.get("forward_axis", "+Z")),
			height, "remote", false, float(pipeline.get("source_height_m", height))):
		rig.scale *= 1.18  # the same silhouette lift as the local survivor
		_web_safe_materials()
	_label(nm, 2.35, 44, Color(0.96, 0.94, 0.82))
	bubble = _label("", 2.8, 36, Color.WHITE)
	bubble.visible = false
	position = p
	_from = p
	_to = p
	visual.rotation.y = yaw
	_to_yaw = yaw
	set_target(p, yaw, "idle")

func set_target(p: Vector3, yaw: float, clip: String) -> void:
	if position.distance_to(p) > SNAP_DISTANCE:
		position = p
		_to = p
		_t = 1.0
		visual.rotation.y = yaw
		_to_yaw = yaw
	else:
		_from = position
		_to = p
		_from_yaw = visual.rotation.y
		_to_yaw = yaw
		_t = 0.0
	if clip != anim and rig and rig.has_clip(StringName(clip)):
		anim = clip
		rig.play(StringName(clip), 1.0, 0.15)

func say(text: String) -> void:
	bubble.text = text
	bubble.visible = true
	_bubble_left = BUBBLE_SECONDS

func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta / LERP_TIME)
		position = _from.lerp(_to, _t)
		visual.rotation.y = lerp_angle(_from_yaw, _to_yaw, _t)
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			bubble.visible = false

func _label(text: String, y: float, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position.y = y
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.outline_size = 10
	l.pixel_size = 0.006
	l.modulate = color
	l.width = 420.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l

func _survivor_meta() -> Dictionary:
	var json := JSON.new()
	if FileAccess.file_exists(Player.SURVIVOR_JSON) and json.parse(FileAccess.get_file_as_string(Player.SURVIVOR_JSON)) == OK and json.data is Dictionary:
		return json.data
	return {"height_meters": 1.72, "pipeline": {"forward_axis": "+Z"}}

## Same override as Player._make_survivor_web_safe: the Meshy material can vanish on WebGL.
func _web_safe_materials() -> void:
	if rig.mesh_root == null:
		return
	for node in rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.extra_cull_margin = 1.0
		for surface in mi.mesh.get_surface_count():
			var original := mi.get_active_material(surface) as BaseMaterial3D
			var safe := StandardMaterial3D.new()
			safe.cull_mode = BaseMaterial3D.CULL_DISABLED
			safe.albedo_color = original.albedo_color if original else Color(0.70, 0.45, 0.28)
			safe.albedo_texture = original.albedo_texture if original else null
			safe.roughness = 0.82
			mi.set_surface_override_material(surface, safe)
