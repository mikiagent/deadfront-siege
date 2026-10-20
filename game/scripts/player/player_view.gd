class_name PlayerView
extends RefCounted
## Survivor presentation: the rig grounded on the capsule bottom, armor and hand sockets, the hip
## lantern, tap markers and route line, the beacon ring, UI hosts, footsteps and the ear.

const SURVIVOR_JSON := "res://data/characters/survivor.json"
const SURVIVOR_BASE_GLB := "res://assets/characters/survivor/survivor.glb"
const SURVIVOR_ANIM_DIR := "res://assets/characters/survivor/anim"
## Footfall spacing in metres of travel (one foot each time). ASSUMPTION: 0.75 m walking, 1.0 m running.
const STRIDE_WALK := 0.75
const STRIDE_RUN := 1.0
## The ear sits where a head would be, not at the iso camera 40 m away (audio-spatial-12).
const EAR_ABOVE_FEET := 1.65

var p: Player
var listener: AudioListener3D
## Rig height offset that puts its feet on the capsule bottom (pc-anim-01); 0 before setup.
var ground_y: float = 0.0
var _visual_rest_y: float = 0.0
var _ground_marker: MeshInstance3D
var _path_line: MeshInstance3D
var _ripple: MeshInstance3D
var _marker_t: float = 0.0
var _lantern: OmniLight3D
var _lantern_phase: float = randf() * TAU
var _right_hand_anchor: Marker3D
var _hips_anchor: Marker3D
var _stride_left: float = 0.0
var _foot: int = 0

func _init(player: Player) -> void:
	p = player

func setup() -> void:
	_setup_survivor()
	_setup_lantern()
	_setup_ground_marker()
	_setup_beacon()
	_setup_gather_ring()
	_setup_listener()

func setup_ui() -> void:
	_setup_gather_radial()
	_setup_station_craft()
	_setup_eat_session()

## Every frame after movement: grounding, lantern, footsteps, the ear's facing.
func tick(delta: float) -> void:
	_keep_grounded()
	_drive_lantern()
	_tick_footsteps(delta)
	var cam := p.get_viewport().get_camera_3d()
	if listener and cam:
		# Screen-left is ear-left: the ear turns with the camera, not with the survivor's facing.
		listener.global_basis = cam.global_basis.orthonormalized()

# ---------------------------------------------------------------- survivor rig

func _setup_survivor() -> void:
	var meta := survivor_meta()
	var pipeline: Dictionary = meta.get("pipeline", {})
	var axis := str(pipeline.get("forward_axis", "+Z"))
	var height := float(meta.get("height_meters", 1.72))
	var rig := p.rig
	if rig == null:
		print("[player] missing Rig node")
		return
	if not rig.setup(SURVIVOR_BASE_GLB, SURVIVOR_ANIM_DIR, axis, height, "player", true, float(pipeline.get("source_height_m", height))):
		print("[player] survivor GLB missing %s" % SURVIVOR_BASE_GLB)
		return
	_make_web_safe()
	# A small silhouette lift keeps the survivor legible at the phone-landscape camera size.
	rig.scale *= 1.18
	# The model's feet are at its root; the body's origin is the capsule centre. Lower the rig by
	# half the capsule so she stands on the floor instead of 0.9 m above it.
	ground_y = -p.half_height()
	rig.position.y = ground_y
	_visual_rest_y = p.visual.position.y
	_bind_rig_markers()
	p.equipment = PlayerEquipment.new()
	p.equipment.name = "Equipment"
	p.add_child(p.equipment)
	p.equipment.setup(rig, p.inventory)
	if p.anim:
		p.anim.setup(p, rig)

## PlayerAnim lowers Visual by the capsule's height above the terrain while she sleeps, because the
## rig used to float. Now the rig itself is grounded, so cancel that drop on the rig: feet (and the
## lying body) stay on the floor through the whole sleep tween. Saddle rides pose the rig themselves.
# shortcut: reads Visual's drop instead of changing player_anim.gd (W2-PANIM owns it); when W2-PANIM
# removes _ground_sleep_visual's offset this line becomes a no-op and can go.
func _keep_grounded() -> void:
	if p.rig == null or p._saddle_view != null:
		return
	p.rig.position.y = ground_y + (_visual_rest_y - p.visual.position.y)

func _make_web_safe() -> void:
	if p.rig == null or p.rig.mesh_root == null:
		return
	for node in p.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		web_safe_mesh(node as MeshInstance3D)

## Meshy's material relies on an emissive texture plus KHR material extensions. It can
## vanish in the Compatibility/WebGL renderer even though the skinned mesh is present.
## Override it with a plain double-sided PBR material on web/mobile; textures are preserved
## when available, while a warm fallback guarantees that the body remains visible.
## Body regions and armor pieces get the same treatment so they match the base look.
static func web_safe_mesh(mi: MeshInstance3D) -> void:
	if mi == null:
		return
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.extra_cull_margin = 1.0
	for surface in mi.mesh.get_surface_count() if mi.mesh else 0:
		var original := mi.get_active_material(surface) as BaseMaterial3D
		var safe := StandardMaterial3D.new()
		safe.cull_mode = BaseMaterial3D.CULL_DISABLED
		safe.albedo_color = Color(0.70, 0.45, 0.28)
		safe.roughness = 0.82
		if original:
			safe.albedo_color = original.albedo_color
			safe.albedo_texture = original.albedo_texture
		mi.set_surface_override_material(surface, safe)

func _bind_rig_markers() -> void:
	_right_hand_anchor = _marker_from_socket(p.rig.hand_socket, "RightHand")
	_hips_anchor = _marker_from_socket(p.rig.hips_socket, "Hips")
	p.pets.mount_hips_offset = p.to_local(_hips_anchor.global_position) if _hips_anchor else Vector3.ZERO

func _marker_from_socket(socket: BoneAttachment3D, fallback_name: String) -> Marker3D:
	if socket == null:
		return null
	for child in socket.get_children():
		if child is Marker3D:
			return child as Marker3D
	var marker := Marker3D.new()
	marker.name = fallback_name
	socket.add_child(marker)
	return marker

func right_hand_anchor() -> Marker3D:
	return _right_hand_anchor

func hips_anchor() -> Marker3D:
	return _hips_anchor

func survivor_meta() -> Dictionary:
	var fallback := {"height_meters": 1.72, "pipeline": {"forward_axis": "+Z"}}
	if not FileAccess.file_exists(SURVIVOR_JSON):
		return fallback
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SURVIVOR_JSON))
	return parsed if parsed is Dictionary else fallback

# ---------------------------------------------------------------- lantern, beacon, ear, footsteps

func _setup_lantern() -> void:
	_lantern = OmniLight3D.new()
	_lantern.name = "HipLantern"
	_lantern.omni_range = 14.0
	_lantern.omni_attenuation = 1.15
	_lantern.light_color = Color(1.0, 0.82, 0.55)
	_lantern.light_energy = 0.0
	_lantern.shadow_enabled = false
	if _hips_anchor:
		_hips_anchor.add_child(_lantern)
		_lantern.position = Vector3.ZERO
	else:
		p.add_child(_lantern)
		_lantern.position = Vector3(0.0, 0.9 + ground_y, 0.0)

func _drive_lantern() -> void:
	if _lantern == null:
		return
	if _hips_anchor and _lantern.get_parent() != _hips_anchor:
		_lantern.reparent(_hips_anchor)
		_lantern.position = Vector3.ZERO
	var from_noon := absf(Game.time_of_day - 0.5) * 2.0
	var night := smoothstep(0.35, 1.0, from_noon)
	var flicker := 1.0 + sin((Time.get_ticks_msec() * 0.001) * 7.0 + _lantern_phase) * 0.05
	_lantern.light_energy = 9.0 * night * flicker

func _setup_beacon() -> void:
	# On a phone the survivor occupies only a few pixels. A soft ring makes the spawn and
	# movement readable without covering the character model or becoming a debug marker.
	var ring := MeshInstance3D.new()
	ring.name = "PlayerBeacon"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.56
	torus.outer_radius = 0.66
	torus.rings = 16
	torus.ring_segments = 8
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.30, 0.88, 0.56, 0.42)
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.72, 0.42)
	mat.emission_energy_multiplier = 0.7
	ring.material_override = mat
	ring.position.y = -p.half_height() + 0.04
	p.visual.add_child(ring)

func _setup_listener() -> void:
	listener = AudioListener3D.new()
	listener.name = "Ear"
	listener.position = Vector3(0.0, EAR_ABOVE_FEET - p.half_height(), 0.0)
	p.add_child(listener)
	listener.make_current()

## One footstep signal per stride while she walks on the ground (audio-footsteps-08). Surface is the
## island TileType under her feet (-1 off the island, -2 in water) so the audio layer picks the sound.
func _tick_footsteps(delta: float) -> void:
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	if speed < 0.5 or not p.is_on_floor() or p.rolling or p.mounted_on or p.dead:
		_stride_left = 0.0
		return
	_stride_left -= speed * delta
	if _stride_left > 0.0:
		return
	var running := p.sim.running if p.sim else false
	_stride_left += STRIDE_RUN if running else STRIDE_WALK
	_foot = 1 - _foot
	p.footstep.emit(_foot, surface_under(), speed)

func surface_under() -> int:
	if p.in_water:
		return -2
	var rt := World.runtime
	if rt is IslandRuntime:
		return IslandTerrain.tile_type_at_world(rt as IslandRuntime, p.global_position.x, p.global_position.z)
	return -1

# ---------------------------------------------------------------- tap feedback

func _setup_ground_marker() -> void:
	_ground_marker = MeshInstance3D.new()
	_ground_marker.name = "GroundMarker"
	_ground_marker.top_level = true
	_ground_marker.visible = false
	var tile := PlaneMesh.new()
	tile.size = Vector2(1.0, 1.0)
	_ground_marker.mesh = tile
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.25, 0.85, 0.55, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ground_marker.material_override = mat
	p.add_child(_ground_marker)

func show_ground_marker(at: Vector3) -> void:
	if _ground_marker == null:
		return
	_ground_marker.global_position = at + Vector3(0.0, 0.05, 0.0)
	_ground_marker.visible = true
	_marker_t = 0.0
	_ripple_at(at)

func clear_ground_marker() -> void:
	if _ground_marker:
		_ground_marker.visible = false
	if _path_line:
		_path_line.visible = false

## Tap feedback: an expanding ring on the tapped tile (pathfinding UI).
func _ripple_at(at: Vector3) -> void:
	if _ripple == null:
		_ripple = MeshInstance3D.new()
		_ripple.name = "TapRipple"
		_ripple.top_level = true
		var tor := TorusMesh.new()
		tor.inner_radius = 0.42
		tor.outer_radius = 0.5
		tor.rings = 24
		tor.ring_segments = 8
		_ripple.mesh = tor
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.9)
		_ripple.material_override = m
		_ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(_ripple)
	_ripple.global_position = at + Vector3(0, 0.08, 0)
	_ripple.scale = Vector3.ONE * 0.4
	_ripple.visible = true
	var mat := _ripple.material_override as StandardMaterial3D
	mat.albedo_color = Color(1, 1, 1, 0.9)
	var tw := p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_ripple, "scale", Vector3.ONE * 2.4, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color(1, 1, 1, 0.0), 0.45)
	tw.chain().tween_callback(func () -> void: _ripple.visible = false)

## Dotted line along the planned route (tile path), redrawn while walking; the target pulses.
func draw_path_line(delta: float) -> void:
	if _path_line == null:
		_path_line = MeshInstance3D.new()
		_path_line.name = "PathLine"
		_path_line.top_level = true
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.75)
		_path_line.material_override = m
		_path_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(_path_line)
	var points := p.sim.path_points()
	var from_index := p.sim.path_index()
	if not p.nav_active or points.size() < 2:
		_path_line.visible = false
		return
	_marker_t += delta
	if _ground_marker and _ground_marker.visible:
		_ground_marker.scale = Vector3.ONE * (1.0 + 0.12 * sin(_marker_t * 6.0))
	if from_index >= points.size():
		_path_line.visible = false
		return
	var im := ImmediateMesh.new()
	var vertices_added := 0
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var prev := p.global_position
	var dash := 0.35
	var gap := 0.3
	for i in range(from_index, points.size()):
		var nxt := points[i]
		var len := prev.distance_to(nxt)
		var t := 0.0
		while t < len:
			var t2 := minf(len, t + dash)
			var a := prev.lerp(nxt, t / maxf(0.001, len))
			var b := prev.lerp(nxt, t2 / maxf(0.001, len))
			im.surface_add_vertex(Vector3(a.x, a.y + 0.12, a.z))
			im.surface_add_vertex(Vector3(b.x, b.y + 0.12, b.z))
			vertices_added += 2
			t += dash + gap
		prev = nxt
	if vertices_added == 0:
		_path_line.visible = false
		return
	im.surface_end()
	_path_line.mesh = im
	_path_line.visible = true

# ---------------------------------------------------------------- UI hosts

func _setup_gather_ring() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 65
	layer.name = "GatherRingLayer"
	p.add_child(layer)
	var script := load("res://scripts/ui/gather_ring.gd") as GDScript
	if script:
		p._gather_ring = script.new()
		layer.add_child(p._gather_ring)

func _setup_gather_radial() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GatherRadialLayer"
	layer.layer = 64
	p.add_child(layer)
	p._gather_radial = GatherRadial.new()
	p._gather_radial.name = "GatherRadial"
	layer.add_child(p._gather_radial)
	p._gather_radial.picked.connect(p.actions.on_option_picked)

func _setup_station_craft() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ContextUI"
	layer.layer = 64
	var scene := p.get_tree().current_scene
	if scene:
		scene.add_child(layer)
	else:
		p.add_child(layer)
	p.station_craft = StationCraft.new()
	p.station_craft.name = "StationCraft"
	p.add_child(p.station_craft)
	p.station_craft.setup(p, layer)
	p.pets.setup_menu(layer)

func _setup_eat_session() -> void:
	var layer := ui_layer()
	p.eat_session = EatSession.new()
	p.eat_session.name = "EatSession"
	p.add_child(p.eat_session)
	p.eat_session.setup(p, layer)

func ui_layer() -> CanvasLayer:
	var scene := p.get_tree().current_scene
	if scene:
		var existing := scene.get_node_or_null("UI") as CanvasLayer
		if existing:
			return existing
		for c in scene.get_children():
			if c is CanvasLayer and str(c.name) == "UI":
				return c as CanvasLayer
	var layer := CanvasLayer.new()
	layer.layer = 28
	layer.name = "StationCraftLayer"
	if scene:
		scene.add_child(layer)
	else:
		p.add_child(layer)
	return layer
