class_name PlayerPortrait
extends RefCounted
## Portraits for HUD labels (spec 18's domain banner). This survivor's is one render of the head
## from the live model, worn gear included, cached for the session; an owner this client has no
## look for (other players, until the server sends appearances) gets a neutral silhouette.

const SIZE := 128
const BACKDROP := Color("#3B3A2C")

static var _cache: Dictionary = {}  ## owner id -> Texture2D
static var _silhouette: ImageTexture

## The owner's portrait: the silhouette until the snapshot (own claims, a GPU) has rendered.
static func texture_for(owner: Dictionary, host: Node) -> Texture2D:
	var key := str(owner.get("id", ""))
	if not _cache.has(key):
		_cache[key] = silhouette()
		var me := PlayerRegistry.local() if bool(owner.get("own", false)) else null
		if me and me.rig and me.rig.mesh_root and host and host.is_inside_tree() and DisplayServer.get_name() != "headless":
			_snapshot(me.rig.mesh_root, host, key)
	return _cache[key]

## Head and shoulders in grey on the portrait backdrop.
static func silhouette() -> Texture2D:
	if _silhouette == null:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		img.fill(BACKDROP)
		var ink := Color(0.60, 0.58, 0.52)
		for y in SIZE:
			for x in SIZE:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(SIZE)
				var head := p.distance_to(Vector2(0.5, 0.40)) < 0.18
				var shoulders := p.y > 0.64 and Vector2((p.x - 0.5) / 0.36, (p.y - 0.98) / 0.32).length() < 1.0
				if head or shoulders:
					img.set_pixel(x, y, ink)
		img.generate_mipmaps()
		_silhouette = ImageTexture.create_from_image(img)
	return _silhouette

## Renders a copy of the model once in its own world, keeps the pixels, frees the viewport.
static func _snapshot(model: Node3D, host: Node, key: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = BACKDROP
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.53, 0.48)
	vp.add_child(env)
	var body := model.duplicate() as Node3D
	vp.add_child(body)
	host.add_child(vp)
	# The face: between the Head and HeadTop_End bones, else the box top.
	var box := _bounds(body)
	var head := Vector3(box.get_center().x, box.end.y - box.size.y * 0.09, box.get_center().z)
	var span := box.size.y * 0.12
	var skels := body.find_children("*", "Skeleton3D", true, false)
	var sk := skels[0] as Skeleton3D if not skels.is_empty() else null
	if sk:
		sk.reset_bone_poses()  # rest pose: a mid-stride copy looked at its feet
	if sk and sk.find_bone("Head") >= 0 and sk.find_bone("HeadTop_End") >= 0:
		var low := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
		var high := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("HeadTop_End")).origin
		head = (low + high) * 0.5
		span = low.distance_to(high)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	# The rig faces -Z (RiggedModel._orient), so the camera stands on that side, a little to one side.
	cam.look_at_from_position(head + Vector3(-0.25, 0.08, -1.0).normalized() * span * 4.5, head)
	var sun := DirectionalLight3D.new()
	vp.add_child(sun)
	sun.look_at_from_position(head + Vector3(-0.6, 1.0, -1.2), head)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image() if is_instance_valid(vp) else null
	if img and not img.is_empty():
		img.generate_mipmaps()
		_cache[key] = ImageTexture.create_from_image(img)
	if is_instance_valid(vp):
		vp.queue_free()

static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 1.8, 0.6))
