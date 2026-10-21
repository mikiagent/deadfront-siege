extends Node3D
## Eyeshine lab: head close-ups (side + day) and the normal game camera at midnight and noon for
## every species that has an "eyes" block, plus one without (zebraceratops). Measures the peak
## luminance around each eye in the game-camera frame and prints the numbers the gate reads.
##
##   godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=eyeglow_lab --shot-dir=/tmp/eyeglow_shots
##   ... --lab=eyeglow_lab --probe        (head-bone geometry per species, no shots)

const SPECIES: Array[StringName] = [&"tyrannosaurus", &"utahraptor", &"deinonychus",
	&"velociraptor", &"coelophysis", &"compsognathus"]
const PLAIN: Array[StringName] = [&"zebraceratops"]
const NIGHT_TOD := 0.0
const NOON_TOD := 0.5
const WATCHDOG_S := 420.0
const MIN_NIGHT_PEAK := 0.6
const MIN_OVER_HEAD := 0.3
const MAX_DAY_RATIO := 0.6

var shot_dir := "/tmp/eyeglow_shots"
var probe_only := false
var only: StringName = &""
## --aim=<px>,<py>: where the painted eye sits in the 1600x900 side shot; prints Head-local coords.
var aim := Vector2(-1, -1)
var EYES_SETUP_DAY := -1.0
## Vertices this close to the aimed pixel count as being on the painted eye (the mesh is low-poly,
## so the eye is rarely under a vertex exactly).
const AIM_PX := 8.0
var ray_mode := false
## --move=<dx>,<dy>: shift every dot by this many screen pixels in the side shot and print the new
## points (right and up are positive). Used to walk a dot onto the painted eye.
var move := Vector2.ZERO
var _cam: Camera3D
var _probe_cam: Camera3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
		elif a.begins_with("--move="):
			var pair2 := a.substr(7).split(",")
			move = Vector2(float(pair2[0]), float(pair2[1]))
		elif a == "--ray":
			ray_mode = true
		elif a == "--probe":
			probe_only = true
		elif a.begins_with("--species="):
			only = StringName(a.substr(10))
		elif a.begins_with("--day="):
			EYES_SETUP_DAY = float(a.substr(6))
		elif a.begins_with("--aim="):
			var pair := a.substr(6).split(",")
			aim = Vector2(float(pair[0]), float(pair[1]))
	Game.debug_overlay = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var kit := LabKit.build(self, 40.0)
	# The kit's survivor carries a torch; standing next to the animal it lights the head brighter
	# than the eyes and hides the whole effect. The lighting and the HUD come from the kit, the
	# body does not: this lab only needs the animal.
	for k in ["player", "nav"]:
		(kit[k] as Node).queue_free()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	TouchControls.visible = false
	DirAccess.make_dir_recursive_absolute(shot_dir)
	get_tree().create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("[eyeglow] FAIL watchdog")
		get_tree().quit(1))
	if DisplayServer.get_name() == "headless":
		print("[eyeglow] FAIL headless cannot render")
		get_tree().quit(2)
		return
	_cam = Camera3D.new()
	_cam.name = "GameCam"
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = IsoCamera.new().default_size
	_cam.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	_cam.current = true
	add_child(_cam)
	_run.call_deferred()

func _spawn(id: StringName) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.spawn(Data.creature(id))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _apply_day_override() -> void:
	var e: GDScript = load("res://scripts/creatures/creature_eyes.gd")
	if EYES_SETUP_DAY >= 0.0:
		e.day_fraction = EYES_SETUP_DAY

func _run() -> void:
	var ids: Array[StringName] = []
	for id in SPECIES:
		if only == &"" or only == id:
			ids.append(id)
	if only == &"" or PLAIN.has(only):
		ids.append_array(PLAIN)
	if probe_only:
		await _probe(ids)
		get_tree().quit(0)
		return
	if move != Vector2.ZERO:
		await get_tree().create_timer(1.5).timeout
		for id in ids:
			await _move_species(id)
		get_tree().quit(0)
		return
	if aim.x >= 0.0 and ray_mode:
		await get_tree().create_timer(1.5).timeout
		for id in ids:
			await _aim_ray_species(id)
		get_tree().quit(0)
		return
	if aim.x >= 0.0:
		print("[eyeglow-aim] aiming ids=%s at %s" % [ids, aim])
		await get_tree().create_timer(1.5).timeout
		for id in ids:
			await _aim_species(id)
		get_tree().quit(0)
		return
	await get_tree().create_timer(2.0).timeout
	_apply_day_override()
	var fails: Array[String] = []
	for id in ids:
		if not await _shoot_species(id, fails):
			continue
	if fails.is_empty():
		print("[eyeglow] PASS")
		get_tree().quit(0)
	else:
		print("[eyeglow] FAIL %s" % [fails])
		get_tree().quit(1)

## Prints what the eye placement needs: the Head bone's world rest position, its axes and scale,
## the model scale and the spots the eye material sits at now.
func _probe(ids: Array[StringName]) -> void:
	for id in ids:
		var c := _spawn(id)
		await get_tree().process_frame
		var sk: Skeleton3D = c.view.rig.skeleton
		if sk == null:
			print("[eyeglow-probe] %s no skeleton" % id)
			c.queue_free()
			continue
		var i := sk.find_bone("Head")
		var g := sk.global_transform * sk.get_bone_global_pose(i)
		print("[eyeglow-probe] %s head_idx=%d bone_rest=%s scale=%.3f model_scale=%s aabb=%s" % [id, i,
			g.origin, g.basis.get_scale().y, c.view.rig.mesh_root.scale, _head_aabb(c)])
		print("[eyeglow-probe] %s basis_x=%s basis_y=%s basis_z=%s head_end=%s" % [id, g.basis.x, g.basis.y, g.basis.z,
			(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head_end"))).origin if sk.find_bone("Head_end") >= 0 else Vector3.ZERO])
		print("[eyeglow-probe] %s bones_head=%s" % [id, _bones_around_head(sk, i)])
		print("[eyeglow-probe] %s eye_world=%s" % [id, _eye_worlds(c)])
		c.queue_free()
		await get_tree().process_frame

## Turns a pixel of the side shot into an eyes point: the pixel gives the eye's height and its
## place along the snout (world y/z), and the widest skull vertex near that spot gives the side
## (world x). The far eye is the same point mirrored across the model's midline. Prints the points
## in Head-bone space, JSON-ready.
func _aim_species(id: StringName) -> void:
	var c := _spawn(id)
	await get_tree().process_frame
	_bind_pose(c)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam := _head_camera(c)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s_aim.png" % [shot_dir, id])
	var sk: Skeleton3D = c.view.rig.skeleton
	var xf := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))
	var hv := _head_vertices(c)
	print("[eyeglow-aim] %s head verts=%d" % [id, hv.size()])
	# Vertices within 3 px of the painted eye, then the one nearest the camera: the side camera
	# looks along -X from +X, and the far cheek projects onto the same pixels (it would bury the dot).
	var best := Vector3.ZERO
	var best_d := INF
	var best_x := -INF
	for v in hv:
		var d := cam.unproject_position(v).distance_to(aim)
		if d > AIM_PX:
			continue
		if v.x > best_x or (v.x == best_x and d < best_d):
			best_x = v.x
			best_d = d
			best = v
	if best_x == -INF:
		var near_d := INF
		var near_px := Vector2.ZERO
		for v in hv:
			var d2 := cam.unproject_position(v).distance_to(aim)
			if d2 < near_d:
				near_d = d2
				near_px = cam.unproject_position(v)
		print("[eyeglow-aim] %s nearest head vertex is %.1f px away (at %s)" % [id, near_d, near_px])
		cam.queue_free()
		c.queue_free()
		await get_tree().process_frame
		return
	var near_local := xf.affine_inverse() * best
	var far_local := xf.affine_inverse() * Vector3(-best.x, best.y, best.z)
	print("[eyeglow-aim] %s near=(%.4f, %.4f, %.4f) far=(%.4f, %.4f, %.4f) px_err=%.1f radius=%.4f" % [id,
		near_local.x, near_local.y, near_local.z, far_local.x, far_local.y, far_local.z, best_d, _head_radius(c) * 0.12])
	cam.queue_free()
	c.queue_free()
	await get_tree().process_frame

## Shifts every eyes point by the given screen offset of the side shot and prints the new points.
func _move_species(id: StringName) -> void:
	var c := _spawn(id)
	await get_tree().process_frame
	_bind_pose(c)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam := _head_camera(c)
	await get_tree().process_frame
	var sk: Skeleton3D = c.view.rig.skeleton
	var xf := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))
	var vp := get_viewport().get_visible_rect().size.y
	var wppx := cam.size / vp
	var world := (-cam.global_basis.x * move.x + cam.global_basis.y * move.y) * wppx
	var delta := xf.basis.inverse() * world
	var e := c.view.get_node_or_null("Eyes")
	if e == null:
		print("[eyeglow-move] %s has no eyes" % id)
	else:
		var out: Array[String] = []
		for dot in e.dots:
			var p: Vector3 = (dot as Node3D).position + delta
			out.append("(%.4f, %.4f, %.4f)" % [p.x, p.y, p.z])
		print("[eyeglow-move] %s points=[%s] world_shift=%s" % [id, ", ".join(out), world])
	cam.queue_free()
	c.queue_free()
	await get_tree().process_frame

## Exact surface point under the aimed pixel: the pixel's ray against every triangle of the mesh.
func _aim_ray_species(id: StringName) -> void:
	var c := _spawn(id)
	await get_tree().process_frame
	_bind_pose(c)
	await get_tree().process_frame
	await get_tree().process_frame
	var cam := _head_camera(c)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var sk: Skeleton3D = c.view.rig.skeleton
	var xf := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))
	var from := cam.project_ray_origin(aim)
	var dir := cam.project_ray_normal(aim)
	var hit := _ray_head(c, from, dir)
	if hit == Vector3.INF:
		print("[eyeglow-aim] %s ray missed" % id)
	else:
		var n := xf.affine_inverse() * hit
		var f := xf.affine_inverse() * Vector3(-hit.x, hit.y, hit.z)
		print("[eyeglow-aim] %s near=(%.4f, %.4f, %.4f) far=(%.4f, %.4f, %.4f) hit=%s radius=%.4f" % [id,
			n.x, n.y, n.z, f.x, f.y, f.z, hit, _head_radius(c) * 0.12])
	cam.queue_free()
	c.queue_free()
	await get_tree().process_frame

## Nearest ray/triangle hit on the head's part of the mesh (bind pose: the vertex arrays are the
## rest-pose ones), or Vector3.INF.
func _ray_head(c: Creature, from: Vector3, dir: Vector3) -> Vector3:
	var sk: Skeleton3D = c.view.rig.skeleton
	var g := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))
	var radius := _head_radius(c)
	var best := INF
	var hit := Vector3.INF
	for mi in c.view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var xf := (mi as Node3D).global_transform
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var tri_count := (idx.size() / 3) if idx.size() > 0 else (verts.size() / 3)
			for t in tri_count:
				var a: Vector3 = xf * verts[idx[t * 3] if idx.size() > 0 else t * 3]
				var b: Vector3 = xf * verts[idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1]
				var cc: Vector3 = xf * verts[idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2]
				if a.distance_to(g.origin) > radius and b.distance_to(g.origin) > radius:
					continue
				var at: Variant = Geometry3D.ray_intersects_triangle(from, dir, a, b, cc)
				if at == null:
					continue
				var p := at as Vector3
				var d := from.distance_to(p)
				if d < best:
					best = d
					hit = p
	return hit

## World-space mesh vertices within a head's radius of the Head bone.
## Rest pose, labels off: the AnimationTree drives the skeleton too, so it has to stop as well.
func _bind_pose(c: Creature) -> void:
	if c.anim and c.anim.tree:
		c.anim.tree.active = false
	c.view.rig.anim_player.stop()
	if c.label:
		c.label.visible = false
	(c.view.rig.skeleton as Skeleton3D).reset_bone_poses()

func _head_vertices(c: Creature) -> Array[Vector3]:
	var sk: Skeleton3D = c.view.rig.skeleton
	var g := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))
	var radius := _head_radius(c)
	var out: Array[Vector3] = []
	for mi in c.view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var xf := (mi as Node3D).global_transform
			for v in verts:
				var w := xf * v
				if w.distance_to(g.origin) <= radius:
					out.append(w)
	return out

func _eye_worlds(c: Creature) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var e := c.view.get_node_or_null("Eyes")
	if e == null:
		return out
	for dot in e.dots:
		out.append((dot as Node3D).global_position)
	return out

## Bounds of the mesh vertices around the Head bone, in the head bone's space: every vertex within
## twice the Head→Head_end bone length of the head bone's origin. Good enough to frame a close-up.
func _head_aabb(c: Creature) -> AABB:
	var sk: Skeleton3D = c.view.rig.skeleton
	var i := sk.find_bone("Head")
	var g := sk.global_transform * sk.get_bone_global_pose(i)
	var radius := _head_span_world(c) * 0.5
	var best := AABB()
	var first := true
	for mi in c.view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var xf := (mi as Node3D).global_transform
			for v in verts:
				var world := xf * v
				if world.distance_to(g.origin) > radius:
					continue
				var local := g.affine_inverse() * world
				var p := AABB(local, Vector3.ZERO)
				best = p if first else best.merge(p)
				first = false
	return best

## How much of the mesh counts as the head, in world metres. The bone chain is the honest measure
## where the rig has Head_end; the T. rex transplant has no Head_end and a skull several metres
## long, so a share of the model height stands in for it.
func _head_radius(c: Creature) -> float:
	var by_bones := _head_span_world(c) * 1.4
	var by_model := maxf(0.4, c.def.height_meters * 0.28)
	return maxf(by_bones, by_model)

## Head bone → Head_end bone length in world metres (twice that is about the head's length).
func _head_span_world(c: Creature) -> float:
	var sk: Skeleton3D = c.view.rig.skeleton
	var i := sk.find_bone("Head")
	var e := sk.find_bone("Head_end")
	var g := sk.global_transform * sk.get_bone_global_pose(i)
	if e < 0:
		return 0.5
	var tip := sk.global_transform * sk.get_bone_global_pose(e)
	return maxf(0.05, g.origin.distance_to(tip.origin))

func _bones_around_head(sk: Skeleton3D, i: int) -> String:
	var out: Array[String] = []
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		if p == i:
			out.append("%s@%s" % [sk.get_bone_name(b), sk.get_bone_global_pose(b).origin])
	return ", ".join(out)

func _shoot_species(id: StringName, fails: Array[String]) -> bool:
	var c := _spawn(id)
	c.global_position = Vector3.ZERO
	await get_tree().process_frame
	# Bind pose for every shot and every number: the clip's first frame moves the head, the mesh's
	# vertex arrays are the rest pose, and aim/side/game frames have to agree on where the head is.
	_bind_pose(c)
	await get_tree().process_frame
	await get_tree().process_frame
	var eyes := c.view.get_node_or_null("Eyes") as CreatureEyes
	if eyes == null:
		print("%s" % ("[eyeglow] none %s eyes=0" % id if PLAIN.has(id) else "[eyeglow] FAIL %s has no eyes node" % id))
		c.queue_free()
		if not PLAIN.has(id):
			fails.append(str(id))
		return false
	if eyes.dots.size() != 2:
		print("[eyeglow] FAIL %s dots=%d" % [id, eyes.dots.size()])
		fails.append(str(id))
		c.queue_free()
		return false
	# Close-ups: side of the head, midnight and noon.
	_probe_cam = _head_camera(c)
	Game.time_of_day = NIGHT_TOD
	await _settle()
	await _save("%s_night_side" % id)
	Game.time_of_day = NOON_TOD
	await _settle()
	await _save_marked("%s_day_side" % id, eyes)
	# Game camera: the normal iso view and zoom, centred on the animal.
	Game.time_of_day = NIGHT_TOD
	_frame_game_camera(c)
	await _settle()
	var night_img := await _frame("%s_night_game" % id)
	var night_head := _head_lum(night_img, c, eyes)
	Game.time_of_day = NOON_TOD
	await _settle()
	var day_img := await _frame("%s_day_game" % id)
	# The eye that is actually visible: the far one sits behind the skull and its window shows skin by
	# day, so the darker of the two day windows is the near eye. Both frames then read that dot.
	var lit_eye := _darker_eye(day_img, eyes)
	var eye_pixel := _eye_screen(eyes, eyes.dots[lit_eye]) * _img_scale(day_img)
	var night_peak := _patch_max(night_img, eye_pixel, 2)
	var day_peak := _patch_max(day_img, eye_pixel, 2)
	var eye_px := _eye_px(night_img, eyes)
	print("[eyeglow] %s night_peak=%.2f day_peak=%.2f night_head=%.2f eye_px=%.1f" % [id, night_peak, day_peak, night_head, eye_px])
	if not (night_peak >= MIN_NIGHT_PEAK and night_peak >= night_head + MIN_OVER_HEAD and day_peak <= MAX_DAY_RATIO * night_peak):
		fails.append("%s numbers" % id)
	_probe_cam.queue_free()
	c.queue_free()
	await get_tree().process_frame
	return true

## Orthographic side camera framed on the head: right-hand side of the animal, close enough that
## the eye is a large disc.
func _head_camera(c: Creature) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var sk: Skeleton3D = c.view.rig.skeleton
	var i := sk.find_bone("Head")
	var g := sk.global_transform * sk.get_bone_global_pose(i)
	# Head group looks along -Z after the 180 deg yaw for +Z sources; the camera looks +X -> -X.
	var head_mid := g.origin
	# The head plus a neck's width: the side of the skull fills two thirds of the frame.
	cam.size = maxf(0.2, _head_radius(c) * 2.6)
	add_child(cam)
	cam.global_position = head_mid + Vector3(cam.size * 2.0, 0.0, 0.0)
	cam.look_at(head_mid, Vector3.UP)
	cam.current = true
	return cam

func _head_span(c: Creature) -> float:
	var a := _head_aabb(c)
	return maxf(a.size.x, maxf(a.size.y, a.size.z))

## The normal game view: IsoCamera's fixed pitch, yaw, 40 m distance and default 15 m screen height,
## centred on the animal's body. The basis is set every time: look_at() would flip it for an animal
## below the previous target and shoot the next species from under the floor.
func _frame_game_camera(c: Creature) -> void:
	var sk: Skeleton3D = c.view.rig.skeleton
	var i := sk.find_bone("Head")
	var g := sk.global_transform * sk.get_bone_global_pose(i)
	var mid := Vector3(g.origin.x, c.global_position.y + c.def.height_meters * 0.5, g.origin.z)
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 15.0
	_cam.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	_cam.global_position = mid + _cam.global_basis.z * 40.0
	_cam.current = true

func _settle() -> void:
	# Wait for the lighting step and a few drawn frames with every shader compiled.
	await get_tree().create_timer(0.4).timeout
	for _i in 3:
		await RenderingServer.frame_post_draw

## Side frame with a magenta cross on each dot's screen position, so the placement can be judged
## against the painted eye in one look.
func _save_marked(name: String, eyes: CreatureEyes) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var sc := _img_scale(img)
	for dot in eyes.dots:
		var sp := _probe_cam.unproject_position(dot.global_position) * sc
		for d in range(-14, 15):
			img.set_pixel(clampi(int(sp.x) + d, 0, img.get_width() - 1), clampi(int(sp.y), 0, img.get_height() - 1), Color.MAGENTA)
			img.set_pixel(clampi(int(sp.x), 0, img.get_width() - 1), clampi(int(sp.y) + d, 0, img.get_height() - 1), Color.MAGENTA)
	img.save_png("%s/%s.png" % [shot_dir, name])

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shot_dir, name])

func _frame(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if name != "":
		img.save_png("%s/%s.png" % [shot_dir, name])
	return img

func _eye_screen(eyes: CreatureEyes, dot: MeshInstance3D) -> Vector2:
	return _cam.unproject_position(dot.global_position)

## Index of the eye whose 5x5 window is darkest: the near eye, since the far one is behind the skull.
func _darker_eye(img: Image, eyes: CreatureEyes) -> int:
	var best := INF
	var at := 0
	for k in eyes.dots.size():
		var sp := _eye_screen(eyes, eyes.dots[k]) * _img_scale(img)
		var lum := _patch_mean(img, sp, 2)
		if lum < best:
			best = lum
			at = k
	return at

## Mean luminance of 5x5 patches on the head away from the eyes: the head's own brightness.
func _head_lum(img: Image, c: Creature, eyes: CreatureEyes) -> float:
	var sk: Skeleton3D = c.view.rig.skeleton
	var i := sk.find_bone("Head")
	var g := sk.global_transform * sk.get_bone_global_pose(i)
	var span := _head_span(c)
	var skip: Array[Vector2] = []
	for dot in eyes.dots:
		skip.append(_eye_screen(eyes, dot) * _img_scale(img))
	var samples: Array[float] = []
	for dy in [-0.25, 0.0, 0.25]:
		for dz in [-0.25, 0.0, 0.25]:
			if dy == 0.0 and dz == 0.0:
				continue
			var at := g.origin + g.basis.y * (span * float(dy)) + g.basis.z * (span * float(dz))
			var sp := _cam.unproject_position(at) * _img_scale(img)
			var near_eye := false
			for s in skip:
				if sp.distance_to(s) < 12.0:
					near_eye = true
			if near_eye:
				continue
			samples.append(_patch_mean(img, sp, 2))
	if samples.is_empty():
		return 0.0
	var acc := 0.0
	for v in samples:
		acc += v
	return acc / float(samples.size())

## The dot's radius on screen in pixels (its world radius through the orthographic camera).
func _dot_screen_radius(eyes: CreatureEyes, dot: MeshInstance3D, img: Image) -> float:
	var ball := dot.mesh as SphereMesh
	if ball == null:
		return 0.0
	var world_r := ball.radius * dot.global_transform.basis.get_scale().x
	var a := _cam.unproject_position(dot.global_position)
	var b := _cam.unproject_position(dot.global_position + _cam.global_basis.x * world_r)
	return a.distance_to(b) * _img_scale(img).x

func _eye_px(img: Image, eyes: CreatureEyes) -> float:
	var a := _eye_screen(eyes, eyes.dots[0])
	var b := _eye_screen(eyes, eyes.dots[1])
	return a.distance_to(b) * _img_scale(img).x

func _img_scale(img: Image) -> Vector2:
	var vr := get_viewport().get_visible_rect().size
	return Vector2(float(img.get_width()) / vr.x, float(img.get_height()) / vr.y)

func _patch_max(img: Image, sp: Vector2, r: int) -> float:
	var best := 0.0
	var x := int(sp.x)
	var y := int(sp.y)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			best = maxf(best, _lum(img.get_pixel(clampi(x + dx, 0, img.get_width() - 1), clampi(y + dy, 0, img.get_height() - 1))))
	return best

func _patch_mean(img: Image, sp: Vector2, r: int) -> float:
	var acc := 0.0
	var x := int(sp.x)
	var y := int(sp.y)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			acc += _lum(img.get_pixel(clampi(x + dx, 0, img.get_width() - 1), clampi(y + dy, 0, img.get_height() - 1)))
	return acc / 25.0

func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
