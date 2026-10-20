extends SceneTree
## See-through system (scripts/world/occlusion.gd + occlusion_material.gd) after the whole-object
## rework: material conversion, overrides, release, mode switching, the disabled flag, MultiMesh
## twins, late children, the inside roof fade, StandardMaterial3D parity, sharing/leaks, the cylinder
## table, the between-node fade, the dither share, MultiMesh instance fades, the SLOTS cap, forgetting
## freed props, release after a fade and the nature sweep.
## Run: Godot --headless --path game --script res://tests/t_occlude.gd
## Game classes are load()ed on the first frame: `--script` compiles this file before they exist.

var _fails: PackedStringArray = []
var _started := false
## Cases that reached their ok line; an aborted case (script error) silently skips it, so the total
## is checked too: a case that dies halfway must not look like a pass.
var _oks := 0
const CASES := 20
var _occ: GDScript
var _om: GDScript

## The iso camera's forward vector, and the unit vector from the survivor towards it.
const FWD := Vector3(-0.5773503, -0.5773503, -0.5773503)
const BACK := Vector3(0.5773503, 0.5773503, 0.5773503)
## The survivor's chest (the player origin is its capsule centre, 0.9 m above the feet).
const CHEST := Vector3(0, 1.2, 0)
## The fade body every derived material includes.
const INCLUDE := "res://shaders/occlusion/occlusion.gdshaderinc"

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _run() -> void:
	_occ = load("res://scripts/world/occlusion.gd")
	_om = load("res://scripts/world/occlusion_material.gd")
	_test_between_mesh()
	_test_override_paths()
	_test_release_restores()
	_test_mode_switch()
	_test_disabled()
	_test_non_base_material()
	_test_multimesh_single()
	_test_multimesh_multi_surface()
	await _test_late_child()
	await _test_inside_fade()
	_test_parity()
	await _test_shared_cache_and_leak()
	_test_cylinder_table()
	await _test_between_node_fade()
	_test_whole_object_share()
	await _test_multimesh_instances()
	await _test_slots_cap()
	await _test_forget_on_free()
	await _test_release_between()
	_test_nature_sweep()
	if _oks < CASES:
		_fails.append("only %d of %d cases ran to their ok line (a script error aborted one)" % [_oks, CASES])
	if _fails.is_empty():
		print("[t_occlude] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_occlude] FAIL %s" % f)
		quit(1)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)

func _since() -> int:
	return _fails.size()

func _ok(case_name: String, since: int) -> void:
	if _fails.size() == since:
		_oks += 1
		print("[t_occlude] ok %s" % case_name)

## One constant from the system's const map (FADE_S, BETWEEN_DROP, INSIDE_DROP, SLOTS).
func _k(name: String) -> float:
	var map: Dictionary = _occ.get_script_constant_map()
	_check(map.has(name), "the system has constant %s" % name)
	return float(map.get(name, 0.0))

## A BoxMesh-shaped ArrayMesh with one surface per material (MultiMesh/explicit-override cases).
static func _array_mesh(mats: Array) -> ArrayMesh:
	var box := BoxMesh.new()
	var arr := ArrayMesh.new()
	for i in mats.size():
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
		arr.surface_set_material(i, mats[i])
	return arr

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

static func _same(a: Variant, b: Variant) -> bool:
	# A null object comes back from get_shader_parameter as NIL; both mean "no texture".
	if a == null or b == null:
		return a == null and b == null
	if typeof(a) != typeof(b):
		return false
	match typeof(a):
		TYPE_FLOAT: return is_equal_approx(a, b)
		TYPE_COLOR: return (a as Color).is_equal_approx(b)
		TYPE_VECTOR4: return (a as Vector4).is_equal_approx(b)
		TYPE_VECTOR3: return (a as Vector3).is_equal_approx(b)
	return a == b

## A MeshInstance3D prop with the material on the mesh (no override): the early conversion cases.
static func _plain_prop(parent: Node3D, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.material = _mat(color)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	parent.add_child(mi)
	return mi

## A MeshInstance3D prop with material_override (the headless renderer can only read an instance
## shader parameter back through a material_override).
static func _box_prop(parent: Node3D, pos: Vector3, size := Vector3(2, 6, 2)) -> MeshInstance3D:
	var mat := _mat(Color(0.3, 0.55, 0.2))
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## A MultiMeshInstance3D prop: one instance with an identity transform; the NODE carries the place
## (the headless renderer reads every instance transform back as identity).
static func _mm_prop(parent: Node3D, pos: Vector3) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(2, 6, 2)
	box.material = _mat(Color(0.25, 0.6, 0.3))
	var mmi := _mm_node(parent, box)
	mmi.position = pos
	return mmi

## How many of the 16 dither cells of one 4x4 block keep drop `d` (copy of occl_bayer4; the shader
## discards where d > bayer, so kept means d <= bayer).
static func _bayer(x: float, y: float) -> float:
	var a := Vector2(floorf(x), floorf(y))
	var b := Vector2(floorf(x * 0.5), floorf(y * 0.5))
	return fposmod(b.x * 0.5 + b.y * b.y * 0.75, 1.0) * 0.25 + fposmod(a.x * 0.5 + a.y * a.y * 0.75, 1.0)

static func _kept_share(drop: float) -> float:
	var kept := 0
	for y in 4:
		for x in 4:
			if drop <= _bayer(x + 0.5, y + 0.5):
				kept += 1
	return float(kept) / 16.0

## A Node3D under the root that every case frees at the end.
func _stage() -> Node3D:
	var n := Node3D.new()
	get_root().add_child(n)
	return n

## The driver, one awaited frame after the first make_occludable(), with _process off so the case
## steps the fades by hand and reads the results synchronously.
func _drv() -> Node:
	await process_frame
	var d: Node = _occ.driver()
	_check(d != null, "the occlusion driver exists")
	if d != null:
		d.set_process(false)
	return d

## The fade the driver holds for `node` and the instance parameter `mesh` (under it) reads.
func _check_fade(node: Node, mesh: GeometryInstance3D, fade: float, drop: float, what: String) -> void:
	var got: float = _occ.fade_of(node)
	_check(is_equal_approx(got, fade), "%s: fade is %f (got %f)" % [what, fade, got])
	var read: Variant = mesh.get_instance_shader_parameter(&"occl_fade")
	_check(typeof(read) == TYPE_FLOAT and is_equal_approx(read, fade * drop), "%s: the mesh parameter is %f (got %s)" % [what, fade * drop, read])

## A MultiMeshInstance3D drawing `mesh` once.
static func _mm_node(parent: Node3D, mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	parent.add_child(mmi)
	return mmi

func _test_between_mesh() -> void:
	var since := _since()
	var root3 := _stage()
	var mi := _plain_prop(root3, Color(0.3, 0.6, 0.2))
	var n: int = _occ.make_occludable(mi, "between")
	_check(n == 1, "between_mesh: one surface converts (got %d)" % n)
	var d := mi.get_surface_override_material(0) as ShaderMaterial
	_check(d != null and d.shader.code.contains("occluder_standard"), "between_mesh: the surface override becomes a ShaderMaterial that includes occluder_standard")
	_check(_occ.mode_of(mi) == "between", "between_mesh: mode_of is 'between'")
	_check(int(mi.get_meta(&"occl_surfaces", 0)) == 1, "between_mesh: occl_surfaces meta is 1")
	_occ.release(mi)
	root3.free()
	_ok("between_mesh", since)

func _test_override_paths() -> void:
	var since := _since()
	var root3 := _stage()
	# A material_override is replaced on the instance itself (and wins over the mesh material).
	var a := _mat(Color(0.9, 0.1, 0.1))
	var mi := _plain_prop(root3, Color(0.1, 0.9, 0.1))
	mi.material_override = a
	_check(_occ.make_occludable(mi, "between") == 1, "override_paths: the override converts")
	var d := mi.material_override as ShaderMaterial
	_check(d != null and _same(d.get_shader_parameter("albedo"), a.albedo_color), "override_paths: the material_override becomes a ShaderMaterial derived from the override, not the mesh material")
	# A surface override material wins over the mesh material at that surface.
	var b := _mat(Color(0.1, 0.1, 0.9))
	var mi2 := _plain_prop(root3, Color(0.1, 0.9, 0.1))
	mi2.set_surface_override_material(0, b)
	_check(_occ.make_occludable(mi2, "between") == 1, "override_paths: a surface override converts")
	var d2 := mi2.get_surface_override_material(0) as ShaderMaterial
	_check(d2 != null and _same(d2.get_shader_parameter("albedo"), b.albedo_color), "override_paths: the surface override is the source")
	_occ.release(mi)
	_occ.release(mi2)
	root3.free()
	_ok("override_paths", since)

func _test_release_restores() -> void:
	var since := _since()
	var root3 := _stage()
	var a := _mat(Color(0.2, 0.5, 0.7))
	var b := _mat(Color(0.7, 0.5, 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = _array_mesh([a, a])
	mi.set_surface_override_material(0, b)  # surface 1 has no override
	root3.add_child(mi)
	_check(_occ.make_occludable(mi, "between") == 2, "release_restores: two surfaces convert")
	_occ.release(mi)
	_check(mi.get_surface_override_material(0) == b and mi.get_surface_override_material(1) == null, "release_restores: the overridden surface gets its own material back and the null one is null again")
	_check(_occ.mode_of(mi) == "", "release_restores: mode_of is empty")
	_check(not mi.has_meta(&"occl_surfaces") and not mi.has_meta(&"occl_mode"), "release_restores: the occl_* metas are gone")
	_check(not mi.has_meta(&"occl_orig"), "release_restores: occl_orig is gone")
	root3.free()
	_ok("release_restores", since)

func _test_mode_switch() -> void:
	var since := _since()
	var root3 := _stage()
	var mi := _plain_prop(root3, Color(0.4, 0.4, 0.4))
	var n: int = _occ.make_occludable(mi, "between")
	_check(n == 1, "mode_switch: first call converts (got %d)" % n)
	var d1 := mi.get_surface_override_material(0)
	_check(_occ.make_occludable(mi, "between") == n, "mode_switch: same mode returns the same count")
	_check(mi.get_surface_override_material(0) == d1, "mode_switch: same mode keeps the derived material")
	_check(_occ.make_occludable(mi, "inside") == 1, "mode_switch: switching mode reconverts")
	var d2 := mi.get_surface_override_material(0) as ShaderMaterial
	_check(d2 != null, "mode_switch: the inside material is still a ShaderMaterial")
	_check(_occ.mode_of(mi) == "inside", "mode_switch: mode_of follows the switch")
	_occ.release(mi)
	root3.free()
	_ok("mode_switch", since)

func _test_disabled() -> void:
	var since := _since()
	var root3 := _stage()
	var mi := _plain_prop(root3, Color(0.5, 0.5, 0.5))
	_occ.set("enabled", false)
	_check(_occ.make_occludable(mi, "between") == 0, "disabled: returns 0")
	_check(mi.get_surface_override_material(0) == null, "disabled: nothing is converted")
	_check(_occ.mode_of(mi) == "", "disabled: the node is not marked occludable")
	_occ.set("enabled", true)
	# and it still works afterwards
	_check(_occ.make_occludable(mi, "between") == 1, "disabled: enabling again converts")
	_occ.release(mi)
	root3.free()
	_ok("disabled", since)

func _test_non_base_material() -> void:
	var since := _since()
	var root3 := _stage()
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(1.0); }\n"
	var mi := _plain_prop(root3, Color.WHITE)
	mi.mesh.material = sm
	# A ShaderMaterial cannot be rebuilt, so it stays and is reported once (the sweep wants no warnings).
	var warned: Dictionary = _om.get("_warned")
	warned.clear()
	_check(_occ.make_occludable(mi, "between") == 0, "non_base_material: returns 0")
	_check(mi.get_surface_override_material(0) == null, "non_base_material: the ShaderMaterial stays as it is")
	_check(warned.has("ShaderMaterial"), "non_base_material: the un-convertible material is reported")
	warned.clear()
	_occ.release(mi)
	root3.free()
	_ok("non_base_material", since)

func _test_multimesh_single() -> void:
	var since := _since()
	var root3 := _stage()
	var mmi := _mm_node(root3, _array_mesh([_mat(Color(0.2, 0.7, 0.7))]))
	_check(_occ.make_occludable(mmi, "between") == 1, "multimesh_single: the one surface converts")
	_check(mmi.material_override is ShaderMaterial, "multimesh_single: material_override becomes a ShaderMaterial")
	_occ.release(mmi)
	_check(mmi.material_override == null, "multimesh_single: release puts the override back to null")
	root3.free()
	_ok("multimesh_single", since)

func _test_multimesh_multi_surface() -> void:
	var since := _since()
	var root3 := _stage()
	var a := _mat(Color(0.1, 0.8, 0.1))
	var b := _mat(Color(0.8, 0.1, 0.1))
	var orig := _array_mesh([a, b])
	var mmi := _mm_node(root3, orig)
	var mm := mmi.multimesh
	_check(_occ.make_occludable(mmi, "between") == 2, "multimesh_multi_surface: two surfaces convert")
	var twin := mm.mesh as ArrayMesh
	_check(twin != null and twin != orig and twin.get_surface_count() == 2, "multimesh_multi_surface: multimesh.mesh is a twin with both surfaces")
	if twin != null:
		for s in twin.get_surface_count():
			_check(twin.surface_get_material(s) is ShaderMaterial, "multimesh_multi_surface: twin surface %d is a ShaderMaterial" % s)
	_check(orig.surface_get_material(0) == a and orig.surface_get_material(1) == b, "multimesh_multi_surface: the original mesh keeps its materials")
	_occ.release(mmi)
	_check(mm.mesh == orig, "multimesh_multi_surface: release restores the original mesh")
	root3.free()
	_ok("multimesh_multi_surface", since)

func _test_late_child() -> void:
	var since := _since()
	var root3 := _stage()
	var wrap := Node3D.new()
	root3.add_child(wrap)
	_check(_occ.make_occludable(wrap, "between") == 0, "late_child: an empty node converts nothing")
	_check(int(wrap.get_meta(&"occl_surfaces", -1)) == 0, "late_child: occl_surfaces starts at 0")
	var mi := _plain_prop(wrap, Color(0.6, 0.2, 0.8))
	await process_frame
	await process_frame
	_check(mi.get_surface_override_material(0) is ShaderMaterial, "late_child: a mesh added later is converted")
	_check(int(wrap.get_meta(&"occl_surfaces", 0)) >= 1, "late_child: occl_surfaces grew")
	_occ.release(wrap)
	_check(mi.get_surface_override_material(0) == null, "late_child: release still restores the late child")
	root3.free()
	_ok("late_child", since)

func _test_inside_fade() -> void:
	var since := _since()
	var fade_s := _k("FADE_S")
	var inside_drop := _k("INSIDE_DROP")
	var root3 := _stage()
	var roof := Node3D.new()
	roof.position = Vector3(0, 3, 0)
	root3.add_child(roof)
	var mi := _box_prop(roof, Vector3.ZERO, Vector3(4, 0.2, 4))
	_check(_occ.make_occludable(roof, "inside") == 1, "inside_fade: the roof converts")
	var drv: Node = await _drv()
	drv.step_inside(Vector3(0, 0.9, 0), 1.0)
	_check_fade(roof, mi, 1.0, inside_drop, "inside_fade: standing under")
	drv.step_inside(Vector3(10, 0.9, 0), 0.1)
	_check(is_equal_approx(_occ.fade_of(roof), 1.0 - 0.1 / fade_s), "inside_fade: 0.1 s outside moves back delta/FADE_S (got %f)" % _occ.fade_of(roof))
	drv.step_inside(Vector3(10, 0.9, 0), 1.0)
	_check_fade(roof, mi, 0.0, inside_drop, "inside_fade: far outside")
	drv.step_inside(Vector3(0, 6, 0), 1.0)
	_check(is_equal_approx(_occ.fade_of(roof), 0.0), "inside_fade: standing above the roof stays solid")
	drv.set_process(true)
	_occ.release(roof)
	_check(_occ.fade_of(roof) == 0.0, "inside_fade: releasing forgets the roof")
	root3.free()
	_ok("inside_fade", since)

func _test_parity() -> void:
	var since := _since()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.25, 0.75))
	var tex := ImageTexture.create_from_image(img)
	var img2 := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img2.fill(Color(0.2, 0.2, 1.0))
	var tex2 := ImageTexture.create_from_image(img2)
	var green := Vector4(0, 1, 0, 0)
	var blue := Vector4(0, 0, 1, 0)
	# name, BaseMaterial3D properties, expected shader parameters, required code tokens
	var rows: Array = [
		{"n": "albedo colour", "set": {"albedo_color": Color(0.2, 0.35, 0.7, 0.8)}, "p": {"albedo": Color(0.2, 0.35, 0.7, 0.8)}, "c": []},
		{"n": "albedo texture", "set": {"albedo_texture": tex}, "p": {"texture_albedo": tex}, "c": []},
		{"n": "roughness + channel", "set": {"roughness": 0.3, "roughness_texture": tex, "roughness_texture_channel": 1}, "p": {"roughness": 0.3, "texture_roughness": tex, "roughness_texture_channel": green}, "c": []},
		{"n": "metallic + channel", "set": {"metallic": 0.75, "metallic_texture": tex, "metallic_texture_channel": 2}, "p": {"metallic": 0.75, "texture_metallic": tex, "metallic_texture_channel": blue}, "c": []},
		{"n": "normal map", "set": {"normal_enabled": true, "normal_texture": tex2, "normal_scale": 0.6}, "p": {"texture_normal": tex2, "normal_scale": 0.6}, "c": ["OCCL_NORMAL"]},
		{"n": "alpha scissor", "set": {"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "alpha_scissor_threshold": 0.35}, "p": {"alpha_scissor_threshold": 0.35}, "c": ["OCCL_SCISSOR"]},
		{"n": "alpha blend", "set": {"transparency": BaseMaterial3D.TRANSPARENCY_ALPHA}, "p": {}, "c": ["OCCL_ALPHA"]},
		{"n": "cull back", "set": {"cull_mode": BaseMaterial3D.CULL_BACK}, "p": {}, "c": ["cull_back"]},
		{"n": "cull front", "set": {"cull_mode": BaseMaterial3D.CULL_FRONT}, "p": {}, "c": ["cull_front"]},
		{"n": "cull disabled", "set": {"cull_mode": BaseMaterial3D.CULL_DISABLED}, "p": {}, "c": ["cull_disabled"]},
		{"n": "unshaded", "set": {"shading_mode": BaseMaterial3D.SHADING_MODE_UNSHADED}, "p": {}, "c": ["unshaded"]},
		{"n": "vertex colour", "set": {"vertex_color_use_as_albedo": true}, "p": {}, "c": ["OCCL_VCOLOR"]},
		{"n": "uv1", "set": {"uv1_scale": Vector3(2, 3, 1), "uv1_offset": Vector3(0.25, 0.5, 0)}, "p": {"uv1_scale": Vector3(2, 3, 1), "uv1_offset": Vector3(0.25, 0.5, 0)}, "c": []},
		{"n": "emission", "set": {"emission_enabled": true, "emission": Color(1, 0.4, 0.1), "emission_energy_multiplier": 2.5}, "p": {"emission": Color(1, 0.4, 0.1), "emission_energy": 2.5}, "c": ["OCCL_EMISSION"]},
	]
	_check(rows.size() >= 10, "parity: the table has at least 10 materials")
	for row: Dictionary in rows:
		var name := str(row["n"])
		var src := StandardMaterial3D.new()
		var props: Dictionary = row["set"]
		for k in props:
			src.set(k, props[k])
		var d: ShaderMaterial = _om.derive(src)
		_check(d != null, "parity/%s: derive returns a ShaderMaterial" % name)
		if d == null:
			continue
		_check(d.shader.code.contains("occluder_standard"), "parity/%s: the shader includes occluder_standard" % name)
		for token: String in row["c"]:
			_check(d.shader.code.contains(token), "parity/%s: shader carries %s" % [name, token])
		var params: Dictionary = row["p"]
		for p in params:
			var got: Variant = d.get_shader_parameter(p)
			_check(_same(got, params[p]), "parity/%s: %s carried over (got %s, want %s)" % [name, p, got, params[p]])
	_ok("parity", since)

func _test_shared_cache_and_leak() -> void:
	var since := _since()
	var root3 := _stage()
	var start: int = _occ.live_materials()
	var shared := _mat(Color(0.45, 0.55, 0.65))
	var box := BoxMesh.new()
	box.material = shared
	for i in 2:
		_box_prop(root3, Vector3.ZERO).material_override = shared
	for mi: MeshInstance3D in root3.get_children():
		mi.mesh = box
		_check(_occ.make_occludable(mi, "between") == 1, "shared_cache: each mesh converts")
	var nodes: Array = root3.get_children()
	var d1: Variant = nodes[0].material_override
	var d2: Variant = nodes[1].material_override
	_check(d1 != null and d1 == d2, "shared_cache: one source material gives the same derived material")
	_check(_occ.live_materials() == start + 1, "shared_cache: exactly one derived material is alive (got %d, start %d)" % [_occ.live_materials(), start])
	for mi in nodes:
		_occ.release(mi)
	root3.free()
	d1 = null
	d2 = null
	await process_frame
	await process_frame
	_check(_occ.live_materials() == start, "shared_cache: releasing and freeing returns to the starting count (got %d, start %d)" % [_occ.live_materials(), start])
	_ok("shared_cache_and_leak", since)

func _test_cylinder_table() -> void:
	var since := _since()
	# name, start, unit direction, cylinder centre (xz), radius, y0, y1, expected hit
	var rows: Array = [
		["hit in front", Vector3(0, 1, 0), Vector3(1, 0, 0), Vector2(5, 0), 1.0, 0.0, 3.0, true],
		["miss beside", Vector3(0, 1, 0), Vector3(1, 0, 0), Vector2(5, 5), 1.0, 0.0, 3.0, false],
		["miss behind the start (t < 0 only)", Vector3(0, 1, 0), Vector3(1, 0, 0), Vector2(-5, 0), 1.0, 0.0, 3.0, false],
		["miss above the top", Vector3(0, 1, 0), Vector3(1, 0, 0), Vector2(5, 0), 1.0, 10.0, 12.0, false],
		["miss below the bottom", Vector3(0, 1, 0), Vector3(1, 0, 0), Vector2(5, 0), 1.0, -12.0, -10.0, false],
		["start inside the cylinder", Vector3(0.5, 1, 0), Vector3(1, 0, 0), Vector2(0, 0), 1.0, 0.0, 3.0, true],
		["straight down inside the radius", Vector3(0, 5, 0), Vector3(0, -1, 0), Vector2(0.5, 0.5), 1.0, 0.0, 1.0, true],
		["straight down outside the radius", Vector3(0, 5, 0), Vector3(0, -1, 0), Vector2(3, 0), 1.0, 0.0, 1.0, false],
		["grazing just inside the radius", Vector3(0, 1, 0), Vector3(1, 0, 0), Vector2(5, 0.5), 0.51, 0.0, 3.0, true],
		["grazing just outside the radius", Vector3(0, 1, 0), Vector3(1, 0, 0), Vector2(5, 0.5), 0.49, 0.0, 3.0, false],
		["diagonal crosses off-centre", Vector3(-4, 1, -4), Vector3(0.7071, 0, 0.7071), Vector2(0, 0), 0.5, 0.0, 3.0, true],
		["diagonal passes wide", Vector3(-4, 1, 0), Vector3(0.7071, 0, 0.7071), Vector2(0, 0), 0.5, 0.0, 3.0, false],
	]
	_check(rows.size() >= 10, "cylinder_table: at least 10 rows")
	for row: Array in rows:
		var got: bool = _occ.ray_hits_cylinder(row[1], row[2], row[3], row[4], row[5], row[6])
		_check(got == row[7], "cylinder_table/%s: ray_hits_cylinder = %s (want %s)" % [row[0], got, row[7]])
	_ok("cylinder_table", since)

func _test_between_node_fade() -> void:
	var since := _since()
	var fade_s := _k("FADE_S")
	var drop := _k("BETWEEN_DROP")
	var root3 := _stage()
	var prop := _box_prop(root3, Vector3(3, 3, 3))
	var beside := _box_prop(root3, Vector3(3, 3, -3))
	var behind := _box_prop(root3, Vector3(-3, 3, -3))
	for p in [prop, beside, behind]:
		_check(_occ.make_occludable(p, "between") == 1, "between_node_fade: %s converts" % p.name)
	var drv: Node = await _drv()
	var hits: Dictionary = drv.in_the_way(CHEST, BACK)
	_check(hits.size() == 1, "between_node_fade: exactly one prop is in the way (got %d objects)" % hits.size())
	var objs: Array = drv._owned.get(prop.get_instance_id(), [])
	_check(objs.size() == 1, "between_node_fade: the prop is one object (got %d)" % objs.size())
	_check(objs.size() == 1 and hits.has(objs[0]), "between_node_fade: in_the_way names the prop's own object")
	for other in [beside, behind]:
		var owners: Array = drv._owned.get(other.get_instance_id(), [])
		_check(not owners.is_empty() and not hits.has(owners[0]), "between_node_fade: %s is not in the way" % other.name)
	drv.step_between(hits, fade_s / 2.0, FWD)
	_check_fade(prop, prop, 0.5, drop, "between_node_fade: FADE_S/2 in the way")
	drv.step_between(hits, fade_s, FWD)
	_check_fade(prop, prop, 1.0, drop, "between_node_fade: a full FADE_S more")
	_check(drop < 1.0, "between_node_fade: BETWEEN_DROP leaves some pixels (got %f)" % drop)
	drv.step_between({}, fade_s, FWD)
	_check_fade(prop, prop, 0.0, drop, "between_node_fade: a FADE_S with no hits")
	_check(objs.size() == 1 and not drv._active.has(objs[0]), "between_node_fade: a solid prop leaves _active")
	drv.set_process(true)
	for p in [prop, beside, behind]:
		_occ.release(p)
	root3.free()
	_ok("between_node_fade", since)

func _test_whole_object_share() -> void:
	var since := _since()
	var f := FileAccess.open(INCLUDE, FileAccess.READ)
	_check(f != null, "whole_object_share: %s reads" % INCLUDE)
	var code := f.get_as_text() if f != null else ""
	# The GDScript dither below must copy the shader's, so the formula is checked before it is used.
	_check(code.contains("fract(b.x * 0.5 + b.y * b.y * 0.75) * 0.25 + fract(a.x * 0.5 + a.y * a.y * 0.75)"),
			"whole_object_share: the include still has the 4x4 bayer formula this test copies")
	_check(code.contains("occl_bayer4"), "whole_object_share: the include uses occl_bayer4")
	# The owner rejected a hole cut around the sight line: no fragment may look at it.
	for token in ["VERTEX", "occl_target", "occl_between"]:
		_check(not code.contains(token), "whole_object_share: the include does not mention %s" % token)
	var between := _k("BETWEEN_DROP")
	var inside := _k("INSIDE_DROP")
	var kept_between := _kept_share(between)
	_check(kept_between >= 0.40 and kept_between <= 0.60,
			"whole_object_share: a faded tree keeps 40-60 %% of its pixels (kept %.4f at BETWEEN_DROP %.2f)" % [kept_between, between])
	var kept_inside := _kept_share(inside)
	_check(kept_inside > 0.0 and kept_inside <= 0.30,
			"whole_object_share: a faded roof keeps a faint outline (kept %.4f at INSIDE_DROP %.2f)" % [kept_inside, inside])
	_check(inside > between, "whole_object_share: the roof drops more than a tree (INSIDE_DROP %.2f > BETWEEN_DROP %.2f)" % [inside, between])
	_ok("whole_object_share", since)

func _test_multimesh_instances() -> void:
	var since := _since()
	var fade_s := _k("FADE_S")
	var root3 := _stage()
	var mmi := _mm_prop(root3, Vector3(3, 3, 3))
	_check(_occ.make_occludable(root3, "between") == 1, "multimesh_instances: the instance converts")
	var drv: Node = await _drv()
	# Instance transforms read back a frame late; file them by hand instead of waiting.
	drv._flush_pending()
	var objs: Array = drv._owned.get(root3.get_instance_id(), [])
	_check(objs.size() == 1, "multimesh_instances: one instance is one object (got %d)" % objs.size())
	var hits: Dictionary = drv.in_the_way(CHEST, BACK)
	_check(hits.size() == 1, "multimesh_instances: the instance is in the way (got %d)" % hits.size())
	drv.step_between(hits, fade_s, FWD)
	_check(is_equal_approx(_occ.instance_fade(mmi, 0), 1.0), "multimesh_instances: FADE_S in the way fades the instance fully (got %f)" % _occ.instance_fade(mmi, 0))
	_check(int(drv._slots_used) == 1, "multimesh_instances: one instance takes one shader slot (got %d)" % int(drv._slots_used))
	drv.step_between({}, fade_s, FWD)
	_check(is_equal_approx(_occ.instance_fade(mmi, 0), 0.0), "multimesh_instances: no hits returns the instance to solid")
	_check(int(drv._slots_used) == 0, "multimesh_instances: a solid instance frees its slot (got %d)" % int(drv._slots_used))
	drv.set_process(true)
	_occ.release(root3)
	root3.free()
	_ok("multimesh_instances", since)

func _test_slots_cap() -> void:
	var since := _since()
	var fade_s := _k("FADE_S")
	var slots := int(_k("SLOTS"))
	var root3 := _stage()
	for i in 10:
		_mm_prop(root3, CHEST + BACK * (5.0 + 2.5 * i))
	_check(_occ.make_occludable(root3, "between") == 10, "slots_cap: ten MultiMesh props convert")
	var drv: Node = await _drv()
	drv._flush_pending()
	var objs: Array = drv._owned.get(root3.get_instance_id(), [])
	_check(objs.size() == 10, "slots_cap: ten objects are filed (got %d)" % objs.size())
	var hits: Dictionary = drv.in_the_way(CHEST, BACK)
	_check(hits.size() == 10, "slots_cap: all ten props are on the sight line (got %d hits)" % hits.size())
	for o in hits:
		_check(o.inst and int(o.slot) >= 0 and int(o.slot) < 10, "slots_cap: the hits are MultiMesh instances")
	drv.step_between(hits, fade_s, FWD)
	_check(int(drv._slots_used) == slots, "slots_cap: the shader slots stop at SLOTS=%d, not 10 (got %d)" % [slots, int(drv._slots_used)])
	_check(slots == 8, "slots_cap: the system still has 8 slots (got %d)" % slots)
	drv.set_process(true)
	_occ.release(root3)
	root3.free()
	_ok("slots_cap", since)

func _test_forget_on_free() -> void:
	var since := _since()
	var root3 := _stage()
	var prop := _box_prop(root3, Vector3(3, 3, 3))
	_check(_occ.make_occludable(prop, "between") == 1, "forget_on_free: the prop converts")
	var drv: Node = await _drv()
	var id: int = prop.get_instance_id()
	var objs: Array = drv._owned.get(id, [])
	var obj: Variant = objs[0] if objs.size() == 1 else null
	_check(objs.size() == 1, "forget_on_free: the prop is owned (got %d objects)" % objs.size())
	_check(not drv.in_the_way(CHEST, BACK).is_empty(), "forget_on_free: the prop is in the way before it is freed")
	prop.queue_free()
	await process_frame
	await process_frame
	_check(not drv._owned.has(id), "forget_on_free: a freed prop is no longer owned")
	_check(not drv._active.has(obj), "forget_on_free: a freed prop leaves _active")
	for cell in drv._grid.values():
		_check(not (cell as Array).has(obj), "forget_on_free: no grid cell still files the freed prop's object")
	_check(drv.in_the_way(CHEST, BACK).is_empty(), "forget_on_free: a freed prop is not in the way")
	drv.set_process(true)
	root3.free()
	_ok("forget_on_free", since)

func _test_release_between() -> void:
	var since := _since()
	var fade_s := _k("FADE_S")
	var root3 := _stage()
	var prop := _box_prop(root3, Vector3(3, 3, 3))
	var orig := prop.material_override
	_check(_occ.make_occludable(prop, "between") == 1, "release_between: the prop converts")
	var drv: Node = await _drv()
	var hits: Dictionary = drv.in_the_way(CHEST, BACK)
	_check(hits.size() == 1, "release_between: the prop is in the way (got %d)" % hits.size())
	drv.step_between(hits, fade_s, FWD)
	_check(is_equal_approx(_occ.fade_of(prop), 1.0), "release_between: the prop is fully faded first")
	var id: int = prop.get_instance_id()
	var objs: Array = drv._owned.get(id, [])
	_occ.release(prop)
	_check(prop.material_override == orig, "release_between: release restores the original material")
	_check(prop.get_surface_override_material(0) == null, "release_between: no derived surface override is left")
	var read: Variant = prop.get_instance_shader_parameter(&"occl_fade")
	_check(typeof(read) == TYPE_FLOAT and is_equal_approx(read, 0.0), "release_between: the occl_fade parameter is 0 (got %s)" % read)
	_check(not drv._owned.has(id), "release_between: a released prop is no longer owned")
	_check(objs.size() == 1 and not drv._active.has(objs[0]), "release_between: a released prop leaves _active")
	_check(_occ.fade_of(prop) == 0.0, "release_between: fade_of forgets it")
	drv.set_process(true)
	root3.free()
	_ok("release_between", since)

func _test_nature_sweep() -> void:
	var since := _since()
	var data: Node = get_root().get_node("Data")
	var families: Dictionary = data.get("nature_families")
	var warned: Dictionary = _om.get("_warned")
	warned.clear()
	var root3 := _stage()
	var checked := 0
	for fam in families:
		var row: Dictionary = families[fam]
		var role := str(row.get("role", ""))
		if not (role.begins_with("tree") or role == "rock"):
			continue
		for m in row.get("models", []):
			var path := str(m)
			if not path.begins_with("res://"):
				path = "res://assets/nature/%s.glb" % path
			if not ResourceLoader.exists(path):
				continue
			var packed = load(path)
			if not (packed is PackedScene):
				_check(false, "nature_sweep: %s is not a PackedScene" % path)
				continue
			var inst: Node = (packed as PackedScene).instantiate()
			root3.add_child(inst)
			var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false) + ([inst] if inst is MeshInstance3D else [])
			var sources: Array = []
			for mi: MeshInstance3D in meshes:
				if mi.mesh != null:
					for s in mi.mesh.get_surface_count():
						sources.append([mi, s, mi.mesh.surface_get_material(s)])
			var n: int = _occ.make_occludable(inst, "between")
			_check(n == sources.size() and n >= 1, "nature_sweep: %s converts every surface (%d of %d)" % [path, n, sources.size()])
			for entry: Array in sources:
				var mi: MeshInstance3D = entry[0]
				var s: int = entry[1]
				var src := entry[2] as StandardMaterial3D
				var ov := mi.get_surface_override_material(s) as ShaderMaterial
				_check(ov != null, "nature_sweep: %s surface %d draws a ShaderMaterial" % [path, s])
				if ov != null and src != null:
					_check(_same(ov.get_shader_parameter("albedo"), src.albedo_color), "nature_sweep: %s surface %d keeps its albedo colour" % [path, s])
					_check(_same(ov.get_shader_parameter("texture_albedo"), src.albedo_texture), "nature_sweep: %s surface %d keeps its albedo texture" % [path, s])
			_occ.release(inst)
			inst.free()
			checked += 1
	root3.free()
	_check(warned.is_empty(), "nature_sweep: no nature material reports unsupported features (got %s)" % str(warned.keys()))
	_check(checked >= 20, "nature_sweep: checked at least 20 tree/rock models (got %d)" % checked)
	_ok("nature_sweep models=%d" % checked, since)
