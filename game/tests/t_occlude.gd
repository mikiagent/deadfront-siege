extends SceneTree
## See-through system (scripts/world/occlusion.gd + occlusion_material.gd): conversion of meshes,
## overrides, release, mode switching, the disabled flag, MultiMesh twins, late children, the inside
## roof fade, StandardMaterial3D parity, material sharing/leaks and the nature sweep.
## Run: Godot --headless --path game --script res://tests/t_occlude.gd
## Game classes are load()ed on the first frame: `--script` compiles this file before they exist.

var _fails: PackedStringArray = []
var _started := false
## Cases that reached their ok line; an aborted case (script error) silently skips it, so the total
## is checked too: a case that dies halfway must not look like a pass.
var _oks := 0
const CASES := 13
var _occ: GDScript
var _om: GDScript

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

## A BoxMesh-shaped ArrayMesh with one surface per material (MultiMesh/explicit-override cases).
static func _array_mesh(mats: Array) -> ArrayMesh:
	var box := BoxMesh.new()
	var arr := ArrayMesh.new()
	for i in mats.size():
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
		arr.surface_set_material(i, mats[i])
	return arr

static func _host() -> Node3D:
	var h := Node3D.new()
	return h

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

func _test_between_mesh() -> void:
	var since := _since()
	var root3 := _host()
	get_root().add_child(root3)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = _mat(Color(0.3, 0.6, 0.2))
	mi.mesh = box
	root3.add_child(mi)
	var n: int = _occ.make_occludable(mi, "between")
	_check(n == 1, "between_mesh: one surface converts (got %d)" % n)
	var d := mi.get_surface_override_material(0) as ShaderMaterial
	_check(d != null, "between_mesh: the surface override becomes a ShaderMaterial")
	_check(d != null and d.shader.code.contains("OCCL_BETWEEN"), "between_mesh: shader defines OCCL_BETWEEN")
	_check(_occ.mode_of(mi) == "between", "between_mesh: mode_of is 'between'")
	_check(int(mi.get_meta(&"occl_surfaces", 0)) == 1, "between_mesh: occl_surfaces meta is 1")
	_occ.release(mi)
	root3.free()
	_ok("between_mesh", since)

func _test_override_paths() -> void:
	var since := _since()
	var root3 := _host()
	get_root().add_child(root3)
	# A material_override is replaced on the instance itself.
	var a := _mat(Color(0.9, 0.1, 0.1))
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = _mat(Color(0.1, 0.9, 0.1))
	mi.mesh = box
	mi.material_override = a
	root3.add_child(mi)
	_check(_occ.make_occludable(mi, "between") == 1, "override_paths: the override converts")
	var d := mi.material_override as ShaderMaterial
	_check(d != null, "override_paths: material_override becomes a ShaderMaterial")
	_check(d != null and _same(d.get_shader_parameter("albedo"), a.albedo_color), "override_paths: derived from the override, not the mesh material")
	# A surface override material wins over the mesh material at that surface.
	var b := _mat(Color(0.1, 0.1, 0.9))
	var mi2 := MeshInstance3D.new()
	var box2 := BoxMesh.new()
	box2.material = a
	mi2.mesh = box2
	mi2.set_surface_override_material(0, b)
	root3.add_child(mi2)
	_check(_occ.make_occludable(mi2, "between") == 1, "override_paths: a surface override converts")
	var d2 := mi2.get_surface_override_material(0) as ShaderMaterial
	_check(d2 != null and _same(d2.get_shader_parameter("albedo"), b.albedo_color), "override_paths: the surface override is the source")
	_occ.release(mi)
	_occ.release(mi2)
	root3.free()
	_ok("override_paths", since)

func _test_release_restores() -> void:
	var since := _since()
	var root3 := _host()
	get_root().add_child(root3)
	var a := _mat(Color(0.2, 0.5, 0.7))
	var b := _mat(Color(0.7, 0.5, 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = _array_mesh([a, a])
	mi.set_surface_override_material(0, b)  # surface 1 has no override
	root3.add_child(mi)
	_check(_occ.make_occludable(mi, "between") == 2, "release_restores: two surfaces convert")
	_occ.release(mi)
	_check(mi.get_surface_override_material(0) == b, "release_restores: the overridden surface gets its own material back")
	_check(mi.get_surface_override_material(1) == null, "release_restores: a null override is null again")
	_check(_occ.mode_of(mi) == "", "release_restores: mode_of is empty")
	_check(not mi.has_meta(&"occl_surfaces") and not mi.has_meta(&"occl_mode"), "release_restores: the occl_* metas are gone")
	_check(not mi.has_meta(&"occl_orig"), "release_restores: occl_orig is gone")
	root3.free()
	_ok("release_restores", since)

func _test_mode_switch() -> void:
	var since := _since()
	var root3 := _host()
	get_root().add_child(root3)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = _mat(Color(0.4, 0.4, 0.4))
	mi.mesh = box
	root3.add_child(mi)
	var n: int = _occ.make_occludable(mi, "between")
	_check(n == 1, "mode_switch: first call converts (got %d)" % n)
	var d1 := mi.get_surface_override_material(0)
	_check(_occ.make_occludable(mi, "between") == n, "mode_switch: same mode returns the same count")
	_check(mi.get_surface_override_material(0) == d1, "mode_switch: same mode keeps the derived material")
	_check(_occ.make_occludable(mi, "inside") == 1, "mode_switch: switching mode reconverts")
	var d2 := mi.get_surface_override_material(0) as ShaderMaterial
	_check(d2 != null and d2.shader.code.contains("OCCL_INSIDE"), "mode_switch: the inside shader defines OCCL_INSIDE")
	_check(_occ.mode_of(mi) == "inside", "mode_switch: mode_of follows the switch")
	_occ.release(mi)
	root3.free()
	_ok("mode_switch", since)

func _test_disabled() -> void:
	var since := _since()
	var root3 := _host()
	get_root().add_child(root3)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = _mat(Color(0.5, 0.5, 0.5))
	mi.mesh = box
	root3.add_child(mi)
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
	var root3 := _host()
	get_root().add_child(root3)
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(1.0); }\n"
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = sm
	mi.mesh = box
	root3.add_child(mi)
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
	var root3 := _host()
	get_root().add_child(root3)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.material = _mat(Color(0.2, 0.7, 0.7))
	mm.mesh = box
	mm.instance_count = 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root3.add_child(mmi)
	_check(_occ.make_occludable(mmi, "between") == 1, "multimesh_single: the one surface converts")
	_check(mmi.material_override is ShaderMaterial, "multimesh_single: material_override becomes a ShaderMaterial")
	_occ.release(mmi)
	_check(mmi.material_override == null, "multimesh_single: release puts the override back to null")
	root3.free()
	_ok("multimesh_single", since)

func _test_multimesh_multi_surface() -> void:
	var since := _since()
	var root3 := _host()
	get_root().add_child(root3)
	var a := _mat(Color(0.1, 0.8, 0.1))
	var b := _mat(Color(0.8, 0.1, 0.1))
	var orig := _array_mesh([a, b])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = orig
	mm.instance_count = 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root3.add_child(mmi)
	_check(_occ.make_occludable(mmi, "between") == 2, "multimesh_multi_surface: two surfaces convert")
	var twin := mm.mesh
	_check(twin != null and twin != orig, "multimesh_multi_surface: multimesh.mesh becomes a twin")
	if twin != null and twin != orig:
		_check(twin.get_surface_count() == 2, "multimesh_multi_surface: the twin keeps both surfaces")
		for s in twin.get_surface_count():
			_check(twin.surface_get_material(s) is ShaderMaterial, "multimesh_multi_surface: twin surface %d is a ShaderMaterial" % s)
	_check(orig.surface_get_material(0) == a and orig.surface_get_material(1) == b, "multimesh_multi_surface: the original mesh keeps its materials")
	_occ.release(mmi)
	_check(mm.mesh == orig, "multimesh_multi_surface: release restores the original mesh")
	root3.free()
	_ok("multimesh_multi_surface", since)

func _test_late_child() -> void:
	var since := _since()
	var root3 := _host()
	get_root().add_child(root3)
	var wrap := Node3D.new()
	root3.add_child(wrap)
	_check(_occ.make_occludable(wrap, "between") == 0, "late_child: an empty node converts nothing")
	_check(int(wrap.get_meta(&"occl_surfaces", -1)) == 0, "late_child: occl_surfaces starts at 0")
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = _mat(Color(0.6, 0.2, 0.8))
	mi.mesh = box
	wrap.add_child(mi)
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
	var root3 := _host()
	get_root().add_child(root3)
	var roof := Node3D.new()
	roof.position = Vector3(0, 3, 0)
	root3.add_child(roof)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 0.2, 4)
	box.material = _mat(Color(0.5, 0.3, 0.3))
	mi.mesh = box
	# material_override: the headless renderer can only read instance parameters through it.
	mi.material_override = box.material
	roof.add_child(mi)
	_check(_occ.make_occludable(roof, "inside") == 1, "inside_fade: the roof converts")
	await process_frame  # the driver node is added deferred
	var drv = _occ.driver()
	_check(drv != null, "inside_fade: a driver exists")
	if drv == null:
		root3.free()
		_ok("inside_fade", since)
		return
	drv.step_inside(Vector3(0, 0.9, 0), 1.0)
	_check(is_equal_approx(_occ.fade_of(roof), 1.0), "inside_fade: standing under fades the roof fully (got %f)" % _occ.fade_of(roof))
	var read: Variant = mi.get_instance_shader_parameter(&"occl_fade")
	_check(typeof(read) == TYPE_FLOAT and is_equal_approx(read, 1.0), "inside_fade: the fade reaches the mesh (got %s)" % read)
	drv.step_inside(Vector3(10, 0.9, 0), 0.1)
	_check(is_equal_approx(_occ.fade_of(roof), 0.5), "inside_fade: 0.1 s outside moves halfway back (got %f)" % _occ.fade_of(roof))
	drv.step_inside(Vector3(10, 0.9, 0), 1.0)
	_check(is_equal_approx(_occ.fade_of(roof), 0.0), "inside_fade: far outside returns to solid")
	drv.step_inside(Vector3(0, 6, 0), 1.0)
	_check(is_equal_approx(_occ.fade_of(roof), 0.0), "inside_fade: standing above the roof stays solid")
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
		var d: ShaderMaterial = _om.derive(src, "between")
		_check(d != null, "parity/%s: derive returns a ShaderMaterial" % name)
		if d == null:
			continue
		_check(d.shader.code.contains("OCCL_BETWEEN"), "parity/%s: defines OCCL_BETWEEN" % name)
		for token: String in row["c"]:
			_check(d.shader.code.contains(token), "parity/%s: shader carries %s" % [name, token])
		var params: Dictionary = row["p"]
		for p in params:
			var got: Variant = d.get_shader_parameter(p)
			_check(_same(got, params[p]), "parity/%s: %s carried over (got %s, want %s)" % [name, p, got, params[p]])
	_ok("parity", since)

func _test_shared_cache_and_leak() -> void:
	var since := _since()
	var root3 := _host()
	get_root().add_child(root3)
	var start: int = _occ.live_materials()
	var shared := _mat(Color(0.45, 0.55, 0.65))
	var box := BoxMesh.new()
	box.material = shared
	var nodes: Array[MeshInstance3D] = []
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = shared
		root3.add_child(mi)
		nodes.append(mi)
	for mi in nodes:
		_check(_occ.make_occludable(mi, "between") == 1, "shared_cache: each mesh converts")
	var d1 := nodes[0].material_override
	var d2 := nodes[1].material_override
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

func _test_nature_sweep() -> void:
	var since := _since()
	var data: Node = get_root().get_node("Data")
	var families: Dictionary = data.get("nature_families")
	var warned: Dictionary = _om.get("_warned")
	warned.clear()
	var root3 := _host()
	get_root().add_child(root3)
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
			var meshes: Array = []
			if inst is MeshInstance3D:
				meshes.append(inst)
			meshes.append_array(inst.find_children("*", "MeshInstance3D", true, false))
			var sources: Array = []
			for mi: MeshInstance3D in meshes:
				if mi.mesh == null:
					continue
				for s in mi.mesh.get_surface_count():
					sources.append([mi, s, mi.mesh.surface_get_material(s)])
			var n: int = _occ.make_occludable(inst, "between")
			_check(n >= 1, "nature_sweep: %s converts at least one surface" % path)
			_check(n == sources.size(), "nature_sweep: %s converts every surface (%d of %d)" % [path, n, sources.size()])
			for entry: Array in sources:
				var mi: MeshInstance3D = entry[0]
				var s: int = entry[1]
				var src := entry[2] as StandardMaterial3D
				var ov := mi.get_surface_override_material(s) as ShaderMaterial
				_check(ov != null, "nature_sweep: %s surface %d draws a ShaderMaterial" % [path, s])
				if ov == null or src == null:
					continue
				_check(_same(ov.get_shader_parameter("albedo"), src.albedo_color), "nature_sweep: %s surface %d keeps its albedo colour" % [path, s])
				_check(_same(ov.get_shader_parameter("texture_albedo"), src.albedo_texture), "nature_sweep: %s surface %d keeps its albedo texture" % [path, s])
			_occ.release(inst)
			inst.free()
			checked += 1
	root3.free()
	_check(warned.is_empty(), "nature_sweep: no nature material reports unsupported features (got %s)" % str(warned.keys()))
	_check(checked >= 20, "nature_sweep: checked at least 20 tree/rock models (got %d)" % checked)
	if _fails.size() == since:
		_oks += 1
		print("[t_occlude] ok nature_sweep models=%d" % checked)
