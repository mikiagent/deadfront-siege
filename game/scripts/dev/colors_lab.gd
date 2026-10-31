extends Node3D
## --lab=colors_lab: eight wild individuals of two species (four velociraptors, four zebraceratops)
## lined up on flat ground in good light, each with its own natural colour profile and hide pattern,
## so the range can be judged by eye. One of them is the 1-in-50 rare morph and is labelled.
## Windowed: godot --path game -- resolution 1600x900 --rendering-method gl_compatibility
## -- --lab=colors_lab --shot=/tmp/colors.png
## Prints "[colors_lab] PASS n=<count>" once every animal is standing with a profile, exits 1 on a
## failure. Also checks that a walking animal's pattern does not slide: the same flank pixels keep
## their colour between two clip frames.

const SPECIES: Array[StringName] = [&"velociraptor", &"zebraceratops"]
const PER_SPECIES := 4
const SPACING := 6.2 # raptors are ~6 m long: anything tighter overlaps head to tail

var _fails: Array[String] = []
var _spawned: Array[Creature] = []
var _cam: Camera3D

func _ready() -> void:
	# LabKit brings the game's own lighting (temperate) and a floor; its player and iso camera are
	# replaced below by a fixed camera framing the line-up.
	var kit := LabKit.build(self, 60.0)
	var player := kit["player"] as Node3D
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var iso := kit.get("cam") as Camera3D
	if iso:
		iso.current = false
	# The HUD is not part of this shot; its plates would sit on top of the animals.
	var ui := kit.get("ui") as CanvasLayer
	if ui:
		ui.visible = false
	# Lighting as every other lab has it: LabKit installs WorldLighting (temperate), which takes the
	# main scene's own sun down; the animals read in its mid-morning light like they do in play.
	_floor_band()
	_spawn_lineup()
	# The name plates are created lazily on the first spawn, so hide them after the line-up exists.
	if Game.creature_ui and is_instance_valid(Game.creature_ui):
		Game.creature_ui.visible = false
	_camera()
	Game.time_of_day = 0.35 # mid-morning sun: colours read as in play
	print("[boot] lab=colors_lab")
	if DisplayServer.get_name() == "headless":
		_finish()
	else:
		# Rendering runs need a few frames before the shot; the pattern check runs after the shot is up.
		await get_tree().create_timer(0.6).timeout
		await _check_pattern_still()
		await _check_look()
		_finish()

## Eight animals, each with a profile chosen so the line-up shows the whole range: stripes, spots,
## dorsal saddle, countershading, a plain hide and one rare morph (labelled). Their spawn points
## differ anyway, which is what a wild spawn rolls from.
func _spawn_lineup() -> void:
	var rows := [
		[&"velociraptor", "stripes", "pale", 0],   # stripes, lighter tone
		[&"velociraptor", "spots", "dark", 0],     # spots, darker tone
		[&"velociraptor", "countershade", "pale", 0],
		[&"velociraptor", "stripes", "rufous", 1], # the rare morph: wider hue, bolder stripes
		[&"zebraceratops", "saddle", "dark", 0],
		[&"zebraceratops", "countershade", "pale", 0],
		[&"zebraceratops", "", "pale", 0],         # plain hide
		[&"zebraceratops", "stripes", "dark", 0],
	]
	var i := 0
	for row in rows:
		var species: StringName = row[0]
		var at := Vector3((float(i % PER_SPECIES) - (PER_SPECIES - 1) * 0.5) * SPACING, 0.0, 3.4 - float(i / PER_SPECIES) * 7.4)
		var def := Data.creature(species)
		var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
		add_child(c)
		c.global_position = at
		# The profile goes on the genetics record before spawn, exactly as a wild individual's does,
		# so the lab exercises the same one-apply path (no second rebind of the skin).
		var genes := CreatureGenetics.roll(null, def.coloration)
		genes.coloration = _forced_profile(def, str(row[1]), str(row[2]), int(row[3]) == 1, at)
		c.genetics = genes
		c.spawn(def)
		c.rotation.y = -PI * 0.5 # flank to the camera: the hide is the point of the shot
		if c.label:
			c.label.visible = false
		c.set_physics_process(false)
		if c.brain:
			c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		_spawned.append(c)
		i += 1

## A deterministic profile with the given pattern and tone: the lab must show known kinds, not
## whatever a random roll happens to give. Everything is in the species' natural range except the
## one rare morph, which is allowed to go wider (as a wild rare roll does).
func _forced_profile(def: CreatureDef, pattern: String, morph: String, rare: bool, at: Vector3) -> CreatureColoration:
	var p := CreatureColoration.new()
	p.pattern = StringName(pattern)
	p.pattern_scale = 1.0 if pattern != "stripes" else 1.25
	p.pattern_strength = 0.52 if pattern != "" else 0.0
	p.pattern_tone = 1.0 if morph in ["dark", "rufous"] else -1.0
	p.pattern_seed = 7.0
	p.morph = StringName(morph) if morph != "" else &""
	if rare:
		# A rare morph: a stronger hue shift and a bolder pattern, the 1-in-50 outlier.
		p.rare = true
		p.hue_deg = 26.0
		p.sat = 1.28
		p.val = 0.86
		p.pattern_strength = 0.58
	else:
		# Spread the normal individuals through the species range (still inside it), so the line-up
		# shows how much natural variation a wild herd carries.
		var hue_amp := float(def.coloration.get("hue_deg", 12.0))
		var sat_amp := float(def.coloration.get("sat", 0.15))
		var val_amp := float(def.coloration.get("val", 0.10))
		var t := float(_spawned.size() % 5) / 4.0 # 0..1 across the range
		p.hue_deg = lerpf(-hue_amp, hue_amp, t) * (-1.0 if morph == "dark" else 1.0)
		p.sat = 1.0 + sat_amp * lerpf(-0.8, 0.8, t)
		p.val = 1.0 + val_amp * lerpf(0.7, -0.7, t)
	if rare:
		_label("RARE " + pattern, at + Vector3(0, def.height_meters + 1.6, 0), Color(1.0, 0.62, 0.25))
	elif pattern != "":
		_label(pattern, at + Vector3(0, def.height_meters + 1.6, 0), Color(0.96, 0.96, 0.9))
	else:
		_label("plain", at + Vector3(0, def.height_meters + 1.6, 0), Color(0.96, 0.96, 0.9))
	return p

func _label(text: String, at: Vector3, col: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = col
	label.outline_size = 12
	label.no_depth_test = true # a label above a head stays readable over the animal behind it
	label.no_depth_test = false
	label.position = at
	add_child(label)

## Flat ground with a pale band, so a dark morph reads against something neutral (not grass green).
func _floor_band() -> void:
	var band := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(28.0, 3.0)
	band.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.66, 0.62, 0.52)
	band.material_override = mat
	band.position = Vector3(0.0, 0.02, 3.4)
	add_child(band)

func _camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "ColorsCamera"
	_cam.fov = 40.0
	_cam.position = Vector3(15.5, 9.6, 20.0)
	add_child(_cam)
	_cam.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_cam.current = true

## The pattern is drawn from the rest-pose vertex positions (CUSTOM0), never from UV or the skinned
## position, so it cannot slide as the animal animates. Two checks, the second rendering the same
## walking animal at two clip times and comparing its flank pixels:
##  - the mesh data is untouched by skinning: CUSTOM0 and the vertex positions are identical between
##    the two frames, and the pattern mask computed from them (as the shader does) is bit-identical;
##  - the rendered flank keeps the same tones (a small tolerance absorbs the body bob, shadows and
##    the anti-aliased silhouette).
func _check_pattern_still() -> void:
	var striped: Creature = null
	for c in _spawned:
		if c.def.id == &"velociraptor" and str(c.view.coloration.pattern) == "stripes":
			striped = c
			break
	if striped == null:
		_check(false, "a striped animal for the pattern check")
		return
	var anim_player := striped.view.animation_player()
	if anim_player == null:
		_check(false, "the striped raptor has an animation player")
		return
	var mesh := _first_mesh(striped.view)
	if mesh == null:
		_check(false, "the striped raptor has a mesh")
		return
	var rest_before := _rest_positions(mesh)
	var aabb := mesh.get_aabb()
	striped.anim.play_clip(&"walk")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var first := _flank_patch(striped)
	anim_player.seek(0.55, true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var second := _flank_patch(striped)
	var rest_after := _rest_positions(mesh)
	anim_player.seek(0.0, true)
	# 1. The pattern input never moves: the rest buffer and the mask built from it are identical.
	_expect_equal_rest(rest_before, rest_after)
	var a := _stripe_mask(rest_before, aabb, striped.view.coloration)
	var b := _stripe_mask(rest_after, aabb, striped.view.coloration)
	var differed := 0
	for i in mini(a.size(), b.size()):
		if not is_equal_approx(a[i], b[i]):
			differed += 1
	_check(differed == 0, "the pattern mask is identical across walk frames (%d of %d vertices differed)" % [differed, a.size()])
	_check(rest_before.size() >= 1000, "the rest channel covers the whole skin (%d vertices)" % rest_before.size())
	# 2. The rendered flank keeps its tones.
	if first.is_empty() or second.is_empty():
		_check(false, "flank pixels captured (%d/%d)" % [first.size(), second.size()])
		return
	var close := 0
	var total := mini(first.size(), second.size())
	for i in total:
		if _near(first[i], second[i]):
			close += 1
	var share := float(close) / float(maxi(1, total))
	_check(share >= 0.80, "the walk clip keeps the flank pattern still (%.0f%% of pixels within tolerance)" % (share * 100.0))
	print("[colors_lab] pattern still share=%.3f pixels=%d rest_vertices=%d" % [share, total, rest_before.size()])

func _expect_equal_rest(a: PackedFloat32Array, b: PackedFloat32Array) -> void:
	var same := a.size() == b.size()
	if same:
		for i in a.size():
			if a[i] != b[i]:
				same = false
				break
	_check(same, "the rest-pose channel does not change while the clip plays (%d/%d values)" % [a.size(), b.size()])

func _first_mesh(view: CreatureView) -> MeshInstance3D:
	if view.rig == null:
		return null
	for n in view.rig.find_children("*", "MeshInstance3D", true, false):
		return n as MeshInstance3D
	return null

## CUSTOM0 (rest positions, xyz per vertex) as a flat float array; empty if the mesh has none.
func _rest_positions(mi: MeshInstance3D) -> PackedFloat32Array:
	if mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return PackedFloat32Array()
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	if arrays.size() <= Mesh.ARRAY_CUSTOM0 or arrays[Mesh.ARRAY_CUSTOM0] == null:
		return PackedFloat32Array()
	return arrays[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array

## The shader's stripe mask, on the CPU, from the rest positions (normalised by the mesh bounds).
func _stripe_mask(rest: PackedFloat32Array, aabb: AABB, col: CreatureColoration) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(rest.size() / 3)
	var size := aabb.size.max(Vector3(0.0001, 0.0001, 0.0001))
	for i in out.size():
		var v := Vector3(rest[i * 3], rest[i * 3 + 1], rest[i * 3 + 2])
		var n := ((v - aabb.position) / size).clamp(Vector3.ZERO, Vector3.ONE)
		var bands := n.z * 9.0 * col.pattern_scale + col.pattern_seed
		var d := absf(fposmod(bands, 1.0) - 0.5) * 2.0
		out[i] = smoothstep(0.35, 0.85, d)
	return out

## Same colour within a small tolerance (a walking body bobs, so shadowing shifts a little).
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.12 and absf(a.g - b.g) < 0.12 and absf(a.b - b.b) < 0.12

## What the shot shows, asserted: the animals must read as coloured skins, not white blobs. Over
## the pixels of every individual's screen box, few may be near-white and the mean saturation must
## stay above a floor. (The skin once rendered near-white through an emission term; only the render
## catches that.)
func _check_look() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_check(false, "the frame is readable for the look check")
		return
	var cam := get_viewport().get_camera_3d()
	var near_white := 0
	var sampled := 0
	var saturation_total := 0.0
	for c in _spawned:
		var centre := cam.unproject_position(c.global_position + Vector3(0, c.def.height_meters * 0.45, 0))
		var extent := cam.unproject_position(c.global_position + Vector3(0, c.def.height_meters * 0.45, 0) + cam.global_transform.basis.x * c.def.real_length_m * 0.22)
		var half := clampi(int(absf(extent.x - centre.x)), 12, 150)
		for dy in range(-half / 2, half / 2 + 1, 3):
			for dx in range(-half, half + 1, 3):
				var x := clampi(int(centre.x) + dx, 0, img.get_width() - 1)
				var y := clampi(int(centre.y) + dy, 0, img.get_height() - 1)
				var col := img.get_pixel(x, y)
				sampled += 1
				saturation_total += col.s
				if col.v > 0.88 and col.s < 0.12:
					near_white += 1
	if sampled == 0:
		_check(false, "creature pixels in the frame")
		return
	var white_share := float(near_white) / float(sampled)
	var mean_sat := saturation_total / float(sampled)
	_check(white_share <= 0.25, "the skins are not washed out (%.0f%% near-white pixels)" % (white_share * 100.0))
	_check(mean_sat >= 0.18, "the skins carry colour (mean saturation %.2f)" % mean_sat)
	print("[colors_lab] look near_white=%.2f mean_sat=%.2f pixels=%d" % [white_share, mean_sat, sampled])

func _check(ok: bool, what: String) -> void:
	print("[colors_lab] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _finish() -> void:
	var profiles := {}
	var with_profile := 0
	var kinds := {}
	for c in _spawned:
		var ok: bool = c.genetics != null and c.genetics.coloration != null and c.view.coloration != null
		if ok:
			with_profile += 1
			profiles["%s|%s" % [snappedf(c.view.coloration.hue_deg, 0.1), snappedf(c.view.coloration.sat, 0.01)]] = true
			kinds[str(c.view.coloration.pattern)] = true
	var count := _spawned.size()
	_check(count == PER_SPECIES * SPECIES.size(), "%d individuals on the ground (got %d)" % [PER_SPECIES * SPECIES.size(), count])
	_check(with_profile == count, "every individual has a colour profile (got %d/%d)" % [with_profile, count])
	_check(profiles.size() >= 5, "at least 5 distinct profiles in the line-up (got %d)" % profiles.size())
	for k in ["stripes", "spots"]:
		_check(kinds.has(k), "the line-up shows %s" % k)
	var plain := false
	for c in _spawned:
		if str(c.view.coloration.pattern) == "":
			plain = true
	_check(plain, "the line-up shows a plain hide beside the patterns")
	var rare := 0
	for c in _spawned:
		if c.view.coloration.rare:
			rare += 1
	_check(rare == 1, "exactly one rare morph in the line-up, labelled (got %d)" % rare)
	for c in _spawned:
		print("[colors_lab] %s %s" % [c.def.id, c.view.coloration.label() if c.view.coloration else "none"])
	if _fails.is_empty():
		print("[colors_lab] PASS n=%d" % count)
		if DisplayServer.get_name() == "headless" or Game.shot_path == "":
			get_tree().quit(0)
	else:
		if DisplayServer.get_name() == "headless" or Game.shot_path == "":
			get_tree().quit(1)

## Pixels of a small patch on the striped raptor's flank, in screen space.
func _flank_patch(c: Creature) -> Array:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return []
	var centre := _cam.unproject_position(c.global_position + Vector3(0.0, 1.1, 0.0))
	var out: Array = []
	for dy in range(-14, 15, 2):
		for dx in range(-22, 23, 2):
			out.append(img.get_pixel(clampi(int(centre.x) + dx, 0, img.get_width() - 1), clampi(int(centre.y) + dy, 0, img.get_height() - 1)))
	return out
