class_name CreatureView
extends Node3D
## Wraps the mesh. SCHEMA §3: Meshy faces +Z, Godot forward is -Z, so this node is yawed 180°.

const TINTS := {
	"velociraptor": Color(0.76, 0.58, 0.32),
	"deinonychus": Color(0.42, 0.55, 0.28),
	"utahraptor": Color(0.62, 0.32, 0.18),
}

## GENETICS: the info-card swatch for one individual: the species' body tint with its own natural
## hue / saturation / value shift (CreatureColoration), so two animals of a species read apart.
static func swatch_color(species: StringName, col: CreatureColoration) -> Color:
	var base := species_base_color(species)
	return col.shift_color(base) if col != null else base

static var _base_colors: Dictionary = {}

## The species' mean hide colour, read once from its model's albedo texture (cached); TINTS for a
## species without a GLB. Near-black texels (unused atlas space) are skipped.
static func species_base_color(species: StringName) -> Color:
	if _base_colors.has(species):
		return _base_colors[species]
	var out: Color = TINTS.get(str(species), Color(0.55, 0.5, 0.4))
	var glb := "res://assets/creatures/%s/%s.glb" % [species, species]
	var packed := load(glb) as PackedScene if ResourceLoader.exists(glb) else null
	if packed != null:
		var inst := packed.instantiate()
		var tex := _first_albedo(inst)
		inst.free()
		var img := tex.get_image() if tex != null else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.resize(48, 48, Image.INTERPOLATE_BILINEAR)
			var sum := Vector3.ZERO
			var n := 0
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.v > 0.08:
						sum += Vector3(c.r, c.g, c.b)
						n += 1
			if n > 0:
				sum /= float(n)
				out = Color(sum.x, sum.y, sum.z)
	_base_colors[species] = out
	return out

static func _first_albedo(n: Node) -> Texture2D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m != null and m.albedo_texture != null:
				return m.albedo_texture
	for c in n.get_children():
		var t := _first_albedo(c)
		if t != null:
			return t
	return null

## "1.08x": the size a card prints.
static func size_text(size: float) -> String:
	return "%.2fx" % size

var pose_kind: StringName = &"idle":
	set(v):
		pose_kind = v
		_apply_pose()
var pose_t: float = 0.0:
	set(v):
		pose_t = v
		_apply_pose()

var def: CreatureDef
var variant: StringName = &""
var using_glb: bool = false
var rig: RiggedModel
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _tint: Color = Color.WHITE
var _base_mats: Array[StandardMaterial3D] = []
var _fx_darken: float = 0.0
var _fx_tint: Color = Color.WHITE
var _wobble: float = 0.0
var _mount: Marker3D
var _saddle: Array[MeshInstance3D] = []
var _rider_bone: int = -1
var _rider_offset: Transform3D = Transform3D.IDENTITY
var _hit_flash_left: float = 0.0
var _flinch_tw: Tween
## Per-individual natural coloration (null = neutral, the species texture as authored).
var coloration: CreatureColoration
## One shared shader for every individual; each individual gets its own ShaderMaterial per surface.
const COLOR_SHADER := preload("res://scripts/creatures/creature_color.gdshader")
var _skin_mats: Array[ShaderMaterial] = []
## Authored material per surface, captured before the first colour override (_rebind_glb_surfaces).
var _originals: Dictionary = {}
## Rest-pose mesh already bound per MeshInstance3D (see rest_mesh()).
var _rest_of: Dictionary = {}
## Rest-pose copy of each species mesh (CUSTOM0 = authored vertex position), rebuilt once per mesh
## resource and shared by every individual of that species. Patterns read it, so they never slide.
static var _rest_meshes: Dictionary = {}

## Procedural hurt: a quick shove back and a nod, then settle. Used instead of the synthesised
## hit_react clip ("death 0-35 % reversed") that made transplanted species start collapsing on
## every hit. Works on the rig node (GLB) or the placeholder body.
func flinch(strength: float = 1.0) -> void:
	var node: Node3D = rig if (using_glb and rig) else _body
	if node == null or def == null:
		return
	if _flinch_tw and _flinch_tw.is_valid():
		_flinch_tw.kill()
	var back := clampf(def.real_length_m * 0.07, 0.05, 0.35) * strength
	_flinch_tw = create_tween()
	_flinch_tw.tween_property(node, "position:z", back, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flinch_tw.parallel().tween_property(node, "rotation:x", -0.16 * strength, 0.07)
	_flinch_tw.tween_property(node, "position:z", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flinch_tw.parallel().tween_property(node, "rotation:x", 0.0, 0.2)

func setup(p_def: CreatureDef, p_variant: StringName = &"") -> void:
	def = p_def
	variant = p_variant
	using_glb = false
	_tint = TINTS.get(str(def.id), Color(0.55, 0.5, 0.4))
	var glb := CreatureDef.model_path(def.id)
	var anim_dir := "res://assets/creatures/%s/anim" % def.id
	# A variant with its own body (megaloceros doe): its own GLB and clip folder on the same bone layout.
	var vrow: Variant = model_variants(def).get(str(variant), "")
	if vrow is Dictionary and (vrow as Dictionary).has("model"):
		glb = "res://assets/creatures/%s/%s" % [def.id, (vrow as Dictionary)["model"]]
		anim_dir = "res://assets/creatures/%s/%s" % [def.id, (vrow as Dictionary).get("anim", "anim")]
	if ResourceLoader.exists(glb):
		rotation = Vector3.ZERO
		rig = RiggedModel.new()
		rig.name = "Rig"
		add_child(rig)
		var axis := str(def.pipeline.get("forward_axis", "-Z"))
		if rig.setup(glb, anim_dir, axis, def.height_meters, "creature", false, float(def.pipeline.get("source_height_m", 0.0))):
			# Explicit posed-height scale for imported standins with transformed skin bounds.
			if def.pipeline.has("stand_in_model_scale"):
				rig.mesh_root.scale = Vector3.ONE * float(def.pipeline["stand_in_model_scale"])
			using_glb = true
			rig.fill_missing(CreatureClips.CONTRACT)
			_apply_model_variant()
		else:
			push_error("CreatureView: %s has a model but it failed to load" % glb)
			rig.queue_free()
			rig = null
			_placeholder_if_allowed()
	else:
		_placeholder_if_allowed()
	apply_coloration(coloration)
	# Coloration recursively replaces mesh materials. Add the shared eyeshine material afterwards;
	# the old order stripped it and left the oversized spheres as plain blue-grey geometry.
	if using_glb:
		_add_eyes()
	_mount = Marker3D.new()
	_mount.name = "MountSocket"
	if using_glb and rig and rig.hips_socket:
		rig.hips_socket.add_child(_mount)
		_mount.position = Vector3(0.0, def.height_meters * 0.08, 0.05)
	else:
		_mount.position = Vector3(0.0, def.height_meters * 0.85, 0.0)
		add_child(_mount)

## Model variants (pipeline.model_variants in the species JSON: variant id -> albedo texture next to the GLB, or a
## row {"model": GLB, "anim": clip folder, "tactics": {...}} for a variant with its own body on the same bone layout,
## e.g. the megaloceros stag and doe). A texture variant only swaps the base colour map; "" or an unknown id keeps
## the GLB as authored.
static func model_variants(p_def: CreatureDef) -> Dictionary:
	var raw: Variant = p_def.pipeline.get("model_variants", {}) if p_def else {}
	return raw if raw is Dictionary else {}

## A variant row's extra data ({} for a plain texture variant): e.g. its "tactics" overrides.
static func variant_row(p_def: CreatureDef, p_variant: StringName) -> Dictionary:
	var row: Variant = model_variants(p_def).get(str(p_variant), "")
	return row if row is Dictionary else {}

## ASSUMPTION: a wild spawn picks its variant deterministically from its identity key (50/50 for two).
## "alpha" is reserved for alpha spawns (Creature.spawn) and never rolled here.
static func pick_variant(p_def: CreatureDef, key: String) -> StringName:
	var ids := model_variants(p_def).keys()
	ids.erase("alpha")
	if ids.is_empty():
		return &""
	ids.sort()
	return StringName(str(ids[absi(hash(key)) % ids.size()]))

func _apply_model_variant() -> void:
	var row: Variant = model_variants(def).get(str(variant), "")
	var tex_name := str((row as Dictionary).get("texture", "")) if row is Dictionary else str(row)
	if tex_name.is_empty():
		return
	var tex := load("res://assets/creatures/%s/%s" % [def.id, tex_name]) as Texture2D
	if tex == null:
		push_error("CreatureView: %s variant %s: missing %s" % [def.id, variant, tex_name])
		return
	for mi in rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i) as StandardMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as StandardMaterial3D
			mat.albedo_texture = tex
			m.set_surface_override_material(i, mat)

## Eyeshine dots on the Head bone; only species whose JSON has an "eyes" block get them.
## The block is read straight from the species file: it is a presentation detail, and CreatureDef
## is the stats contract the other agents share.
static var _eyes_cache: Dictionary = {}

static func eyes_block(id: StringName) -> Dictionary:
	if _eyes_cache.has(id):
		return _eyes_cache[id]
	var path := "res://data/creatures/%s.json" % id
	var block: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var raw: Variant = (parsed as Dictionary).get("eyes", {})
			if raw is Dictionary:
				block = raw
	_eyes_cache[id] = block
	return block

func _add_eyes() -> void:
	if def == null:
		return
	var block := eyes_block(def.id)
	if block.is_empty():
		return
	var eyes := CreatureEyes.new()
	eyes.name = "Eyes"
	add_child(eyes)
	if not eyes.setup(self, block):
		eyes.queue_free()
		return

## GENETICS: the whole view at the body size, so the eye dots, the mount socket and the saddle (all
## parented under it) follow; `eye_glow` brightens the eyeshine (an alpha's 2.5x).
func apply_genome(size: float, eye_glow: float = 1.0) -> void:
	scale = Vector3.ONE * maxf(0.01, size)
	var eyes := get_node_or_null("Eyes") as CreatureEyes
	if eyes != null:
		eyes.fit_size(size)
		eyes.set_glow(eye_glow)

func animation_player() -> AnimationPlayer:
	if using_glb and rig:
		return rig.anim_player
	return null

func mount_socket() -> Marker3D:
	return _mount

## Saddled mount (assets/creatures/<id>/mount/mount.json): returns true and the rider then follows
## rider_transform() on rig.skeleton.skeleton_updated. False means no saddle model for this species, so the
## caller keeps the hips-socket path. The saddle mesh itself is show_saddle's (SADDLES: shown while one is
## equipped, ridden or not).
func begin_ride() -> bool:
	var mj := _mount_json()
	if not mj.has("rider_in_mount"):
		return false
	var sk := rig.skeleton
	_rider_bone = sk.find_bone(str(mj.get("socket", "")))
	if _rider_bone < 0:
		return false
	# rider_in_mount is the rider's root in the mount's glTF model space at rest (NOT rider_offset, which is in
	# Blender's re-oriented bone frames). Express it relative to the socket bone's rest pose at the live scale.
	var m: Array = mj["rider_in_mount"]
	var in_model := Transform3D(Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]), Vector3(m[8], m[9], m[10])), Vector3(m[12], m[13], m[14]))
	var bone_rest_world := sk.global_transform * sk.get_bone_global_rest(_rider_bone)
	_rider_offset = bone_rest_world.affine_inverse() * rig.mesh_root.global_transform * in_model
	return true

## The ride ends; the saddle stays on while it is equipped (show_saddle).
func end_ride() -> void:
	pass

## The saddle folder: mount/, or a body variant's own ({"mount": "doe/mount"}: its back is elsewhere).
func _mount_dir() -> String:
	var row := variant_row(def, variant) if def else {}
	return "res://assets/creatures/%s/%s" % [def.id, str(row.get("mount", "mount"))] if def else ""

## This species' mount.json, {} when it has none (or no rigged model to put a saddle on).
func _mount_json() -> Dictionary:
	var path := "%s/mount.json" % _mount_dir()
	if not (def and using_glb and rig and rig.skeleton and FileAccess.file_exists(path)):
		return {}
	var mj: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return mj if mj is Dictionary else {}

## SADDLES: the equipped saddle on the back (null = none), skinned to this skeleton so it follows every
## clip, its leather tinted by the saddle's natural colour (spec 35: the hide it was sewn from). Bone and
## iron fittings keep their colour. A species without a saddle model shows nothing.
func show_saddle(stack: ItemStack) -> void:
	for mi in _saddle:
		mi.queue_free()
	_saddle.clear()
	var mj := _mount_json()
	if stack == null or mj.is_empty():
		return
	var path := "%s/%s" % [_mount_dir(), str(mj.get("saddle", "saddle.glb"))]
	_saddle = RiggedModel.attach_skinned(rig.skeleton, path)
	var tint := stack.tint_color()
	for mi in _saddle:
		mi.set_meta(&"creature_gear", true)  # apply_coloration must not repaint it as skin
		if tint == Color.WHITE:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m and m.resource_name.begins_with("saddle_leather"):
				var t := m.duplicate() as StandardMaterial3D
				t.albedo_color = tint.darkened(0.45) if m.resource_name.ends_with("_dark") else tint
				mi.set_surface_override_material(i, t)

func saddle_meshes() -> Array[MeshInstance3D]:
	return _saddle

## Rest-pose positions for the pattern shader. The skin moves VERTEX, and Tripo UVs are arbitrary,
## so the pattern has to come from the authored position of each vertex: copy it once into CUSTOM0
## (ARRAY_CUSTOM_RGB_FLOAT) and cache the rebuilt mesh by the original resource, so it happens once
## per species rather than once per animal.
##
## What survives the rebuild: materials (re-set per surface) and the shadow mesh (re-attached
## below). What does not: surface LODs. Godot 4.7 has no public ArrayMesh LOD accessor (only the
## internal `_surface_get_lods`), so `surface_get_arrays` cannot carry them over. These creature
## GLBs import as one LOD0 skin surface each (checked on the velociraptor), so nothing is lost
## today; if a future asset ships LODs/CSG, bake the rest channel at import (ImporterMesh +
## generate_lods) instead of rebuilding here.
static func rest_mesh(mesh: Mesh) -> ArrayMesh:
	if mesh == null:
		return null
	if _rest_meshes.has(mesh):
		return _rest_meshes[mesh]
	if not (mesh is ArrayMesh):
		return null
	var out := ArrayMesh.new()
	out.resource_name = "%s_rest" % mesh.resource_name
	for surf in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surf)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var rest := PackedFloat32Array()
		rest.resize(verts.size() * 3)
		for i in verts.size():
			var v: Vector3 = verts[i]
			rest[i * 3] = v.x
			rest[i * 3 + 1] = v.y
			rest[i * 3 + 2] = v.z
		var copy: Array = arrays.duplicate(true)
		copy[Mesh.ARRAY_CUSTOM0] = rest
		var flags: int = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		var material: Material = mesh.surface_get_material(surf)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, copy, [], {}, flags)
		if material != null:
			out.surface_set_material(out.get_surface_count() - 1, material)
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_name(surf) != "":
			out.surface_set_name(out.get_surface_count() - 1, (mesh as ArrayMesh).surface_get_name(surf))
	var shadow := (mesh as ArrayMesh).get_shadow_mesh()
	if shadow != null:
		out.set_shadow_mesh(shadow)
	_rest_meshes[mesh] = out
	return out

## The individual's natural colours. Called by Creature.spawn() after setup() (and by the pet summon
## path). GLB rigs: every mesh surface gets its own copy of the original material, re-bound to the
## HSV-shift shader, so one individual never repaints another. Placeholders: the same shift on _tint.
func apply_coloration(col: CreatureColoration) -> void:
	coloration = col
	_skin_mats.clear()
	if using_glb and rig and rig.mesh_root:
		_rebind_glb_surfaces(rig.mesh_root)
	_apply_fx()

## HSL/HSV shift for one surface: copies the albedo, normal, roughness and metallic of `src`.
func _color_material(src: Material, col: CreatureColoration) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = COLOR_SHADER
	if col != null:
		sm.set_shader_parameter("hue_shift", col.hue_deg / 360.0)
		sm.set_shader_parameter("sat_scale", col.sat)
		sm.set_shader_parameter("val_scale", col.val)
	var std := src as StandardMaterial3D
	if std == null:
		# Not a standard PBR material (or none): keep its colour as flat albedo when we can read one.
		if src is BaseMaterial3D:
			sm.set_shader_parameter("albedo_color", (src as BaseMaterial3D).albedo_color)
		return sm
	sm.set_shader_parameter("albedo_color", std.albedo_color)
	var albedo := std.albedo_texture
	if albedo != null:
		sm.set_shader_parameter("use_albedo", true)
		sm.set_shader_parameter("albedo_tex", albedo)
	sm.set_shader_parameter("use_vertex_color", std.vertex_color_use_as_albedo)
	var nm := std.normal_texture
	if nm != null:
		sm.set_shader_parameter("use_normal", true)
		sm.set_shader_parameter("normal_tex", nm)
		sm.set_shader_parameter("normal_strength", std.normal_scale)
	var rm := std.roughness_texture
	if rm != null:
		sm.set_shader_parameter("use_roughness_tex", true)
		sm.set_shader_parameter("roughness_tex", rm)
		sm.set_shader_parameter("roughness_channel", int(std.roughness_texture_channel))
	var mm := std.metallic_texture
	if mm != null:
		sm.set_shader_parameter("use_metallic_tex", true)
		sm.set_shader_parameter("metallic_tex", mm)
		sm.set_shader_parameter("metallic_channel", int(std.metallic_texture_channel))
	sm.set_shader_parameter("roughness", std.roughness)
	sm.set_shader_parameter("metallic", std.metallic)
	sm.set_shader_parameter("specular", std.metallic_specular)
	if std.uv1_scale != Vector3.ONE or std.uv1_offset != Vector3.ZERO:
		sm.set_shader_parameter("uv_scale", Vector2(std.uv1_scale.x, std.uv1_scale.y))
		sm.set_shader_parameter("uv_offset", Vector2(std.uv1_offset.x, std.uv1_offset.y))
	return sm

## Walks the rig's meshes (nested under skeleton or node roots) and overrides every surface. The
## authored material of each surface is remembered on first bind: a second apply (a pet summon, a
## re-roll) must copy the original textures again, not the shader material bound a moment ago.
func _rebind_glb_surfaces(node: Node) -> void:
	# Eyeshine is a shared presentation material, not skin. Re-coloring an individual must not strip it.
	if node.has_meta(&"creature_eyeshine") or node.has_meta(&"creature_gear"):
		return
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		mi.material_override = null
		var count := mi.mesh.get_surface_count()
		# Only ever rebuild once per mesh instance: a second apply (the lab forcing a profile, a pet
		# summon) must reuse the rest mesh it already has, not rebuild a mesh from itself.
		var rest: ArrayMesh = _rest_of.get(mi, null)
		if rest == null:
			rest = rest_mesh(mi.mesh)
			if rest != null:
				mi.mesh = rest
				_rest_of[mi] = rest
			count = mi.mesh.get_surface_count() if rest != null else count
		else:
			mi.mesh = rest
			count = rest.get_surface_count()
		var originals: Array = _originals.get(mi, [])
		if originals.is_empty():
			for i in count:
				originals.append(mi.get_active_material(i))
			_originals[mi] = originals
		for i in count:
			var src: Material = originals[i] if i < originals.size() else mi.get_active_material(i)
			var sm := _color_material(src, coloration)
			_apply_pattern(sm, mi.mesh)
			mi.set_surface_override_material(i, sm)
			_skin_mats.append(sm)
	for child in node.get_children():
		_rebind_glb_surfaces(child)

## Pattern uniforms: kind, scale, strength, tone and seed from the profile, plus the mesh bounds the
## shader normalises the rest positions by (body axis = the longest bounds axis, up = +Y).
func _apply_pattern(sm: ShaderMaterial, mesh: Mesh) -> void:
	var kind := 0
	if coloration != null:
		kind = CreatureColoration.PATTERNS.find(String(coloration.pattern)) + 1
	sm.set_shader_parameter("pattern_kind", kind)
	if coloration != null:
		sm.set_shader_parameter("pattern_scale", coloration.pattern_scale)
		sm.set_shader_parameter("pattern_strength", coloration.pattern_strength if kind > 0 else 0.0)
		sm.set_shader_parameter("pattern_tone", coloration.pattern_tone)
		sm.set_shader_parameter("pattern_seed", coloration.pattern_seed)
	var aabb := mesh.get_aabb() if mesh != null else AABB(Vector3.ZERO, Vector3.ONE)
	sm.set_shader_parameter("pattern_min", aabb.position)
	sm.set_shader_parameter("pattern_size", aabb.size)
	var axis := 2
	if aabb.size.x >= aabb.size.y and aabb.size.x >= aabb.size.z:
		axis = 0
	elif aabb.size.y >= aabb.size.z:
		axis = 1
	sm.set_shader_parameter("pattern_axis", axis)

## Where the rider's model root goes this frame. Read it on skeleton_updated, not in _process.
## The basis is orthonormalised: _rider_offset carries the mount's own scale (the game scales the GLB to
## height_meters, K = 1 only for the T. rex), and the survivor rig must not inherit it. The translation
## keeps it, so a scaled saddle still places the rider at the right spot in world space.
func rider_transform() -> Transform3D:
	var sk := rig.skeleton
	var t := sk.global_transform * sk.get_bone_global_pose(_rider_bone) * _rider_offset
	return Transform3D(t.basis.orthonormalized(), t.origin)

func set_status_fx(darken: float, tint: Color, wobble: float) -> void:
	_fx_darken = darken
	_fx_tint = tint
	_wobble = wobble
	_apply_fx()

func flash_damage(seconds: float = 0.1) -> void:
	_hit_flash_left = maxf(_hit_flash_left, seconds)
	_apply_fx()

## NOBOXES: the generic boxes only where a lab or test asked (CreatureDef.allow_placeholder); in
## normal play a model-less view stays empty (spawns already filter those species out).
func _placeholder_if_allowed() -> void:
	if not CreatureDef.allow_placeholder:
		push_warning("CreatureView: %s has no model; no placeholder in normal play" % def.id)
		return
	# Placeholder nose sits at +Z; yaw the view so it still faces Godot -Z like before.
	rotation_degrees.y = 180.0
	_build_placeholder()

func _build_placeholder() -> void:
	var h := def.height_meters
	var L := def.real_length_m
	_body = _box(Vector3(h * 0.28, h * 0.32, L * 0.42), Vector3(0, h * 0.42, 0), _tint)
	_head = _box(Vector3(h * 0.22, h * 0.22, h * 0.32), Vector3(0, h * 0.62, L * 0.28), _tint.lightened(0.1))
	_tail = _box(Vector3(h * 0.08, h * 0.08, L * 0.45), Vector3(0, h * 0.48, -L * 0.32), _tint.darkened(0.15))
	_leg_l = _cyl(h * 0.05, h * 0.42, Vector3(-h * 0.1, h * 0.2, 0.05), _tint.darkened(0.2))
	_leg_r = _cyl(h * 0.05, h * 0.42, Vector3(h * 0.1, h * 0.2, 0.05), _tint.darkened(0.2))
	_body.name = "Body"

func _box(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	_base_mats.append(mat)
	add_child(mi)
	return mi

func _cyl(r: float, h: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	_base_mats.append(mat)
	add_child(mi)
	return mi

func _apply_pose() -> void:
	if using_glb or _body == null:
		if using_glb and rig:
			rig.rotation.z = sin(Time.get_ticks_msec() * 0.01) * _wobble * 0.15
		else:
			rotation.z = sin(Time.get_ticks_msec() * 0.01) * _wobble * 0.15
		return
	var t := pose_t
	var bob := sin(t * TAU) * 0.03
	match pose_kind:
		&"idle":
			_body.position.y = def.height_meters * 0.42 + bob
			_head.rotation.x = bob * 2.0
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = 0.0
		&"walk", &"run":
			var amp := 0.55 if pose_kind == &"run" else 0.35
			_leg_l.rotation.x = sin(t * TAU) * amp
			_leg_r.rotation.x = sin(t * TAU + PI) * amp
			_body.position.y = def.height_meters * 0.42 + absf(sin(t * TAU)) * 0.04
		&"attack_primary":
			_body.position.z = sin(t * PI) * 0.35
			_head.rotation.x = -t * 0.4
		&"attack_heavy":
			var lunge := 0.0 if t < 0.45 else sin((t - 0.45) / 0.55 * PI) * 0.8
			_body.position.z = lunge
			_body.rotation.x = -lunge * 0.4
		&"hit_react":
			_body.position.z = -sin(t * PI) * 0.2
		&"knockdown":
			rotation.z = lerpf(0.0, -PI * 0.5, clampf(t * 1.4, 0.0, 1.0))
		&"death":
			rotation.z = lerpf(0.0, PI * 0.5, clampf(t, 0.0, 1.0))
			_body.position.y = def.height_meters * 0.2
		&"alert":
			_head.position.y = def.height_meters * 0.62 + sin(t * PI) * 0.15
		&"feed":
			_head.rotation.x = 0.6
	rotation.z += sin(Time.get_ticks_msec() * 0.012) * _wobble * 0.12

func _apply_fx() -> void:
	if _hit_flash_left > 0.0:
		_hit_flash_left = maxf(0.0, _hit_flash_left - get_process_delta_time())
	var tint_amount := 0.35 if _fx_tint != Color.WHITE else 0.0
	var flash_amount := 0.65 if _hit_flash_left > 0.0 else 0.0
	for mat in _base_mats:
		# The placeholder path carries the colour profile itself: shift the base tint, then FX on top.
		var c := coloration.shift_color(_tint) if coloration != null else _tint
		c = c.darkened(_fx_darken)
		c = c.lerp(_fx_tint, tint_amount)
		if flash_amount > 0.0:
			c = c.lerp(Color(1.0, 0.2, 0.2), flash_amount)
		mat.albedo_color = c
	for sm in _skin_mats:
		if not is_instance_valid(sm):
			continue
		sm.set_shader_parameter("darken", _fx_darken)
		sm.set_shader_parameter("tint_color", _fx_tint)
		sm.set_shader_parameter("tint_amount", tint_amount)
		sm.set_shader_parameter("flash_amount", flash_amount)
