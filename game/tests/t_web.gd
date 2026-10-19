extends SceneTree
## W1-WEB checks: shell manifest rules, VegBatch 32 m cells, generated props imported without
## emission and at <= 512 px. Run: Godot --headless --path game -s res://tests/t_web.gd

const BIRCH := "res://assets/nature/BirchTree_3.glb"
const ROCK := "res://assets/nature/Rock_1.glb"
const GOOD_SHA := "28fe3771406fcb0f4e3bb7ee13c0aaa1afd7dbbc0366068c2d809241f3748a6b"

var failures: Array[String] = []
var _done := false

## Autoloads (Data, ShellLoader) exist only from the first frame of a --script run.
func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("ShellLoader") == null:
		return false
	_done = true
	_test_manifest_rules()
	_test_boot_refuses_bad_manifest()
	_test_veg_cells()
	_test_generated_imports()
	if failures.is_empty():
		print("[t_web] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_web] FAIL %s" % f)
		quit(1)
	return true

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)

func _pack(name: Variant, sha: Variant = GOOD_SHA, url: Variant = "https://example.invalid/p.pck") -> Dictionary:
	var p := {"name": name, "url": url, "size": 10}
	if sha != null:
		p["sha256"] = sha
	return p

func _test_manifest_rules() -> void:
	var shell := get_root().get_node("ShellLoader")
	var published: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../hosting/builds/manifest.json")))
	_check(published is Dictionary and shell.manifest_error(published) == "", "the published builds manifest passes the rules")
	_check(shell.manifest_error({"packs": [_pack("core"), _pack("assets_2-x")]}) == "", "valid names and hashes pass")
	var bad := {
		"no sha256": [_pack("core", null)],
		"empty sha256": [_pack("core", "")],
		"short sha256": [_pack("core", "abc123")],
		"uppercase sha256": [_pack("core", GOOD_SHA.to_upper())],
		"path in name": [_pack("../core")],
		"slash in name": [_pack("a/b")],
		"uppercase name": [_pack("Core")],
		"name over 32": [_pack("a".repeat(33))],
		"empty name": [_pack("")],
		"newline in name": [_pack("core\n")],
		"number name": [_pack(7)],
		"duplicate name": [_pack("core"), _pack("core")],
		"file url": [_pack("core", GOOD_SHA, "file:///etc/passwd")],
		"no packs": [],
	}
	for why: String in bad:
		var err: String = shell.manifest_error({"packs": bad[why]})
		_check(err != "", "manifest with %s is refused" % why)
	_check(shell.manifest_error({"version": "x"}) != "", "manifest without packs is refused")

func _test_boot_refuses_bad_manifest() -> void:
	for packs: Array in [[_pack("core", null)], [_pack("../../evil")], []]:
		var boot: Control = load("res://shell/boot.gd").new()
		var http := HTTPRequest.new()
		boot.set("_http", http)
		var body := JSON.stringify({"version": "t", "min_shell": 1, "packs": packs}).to_utf8_buffer()
		boot.call("_on_manifest", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body)
		var queued: Array = boot.get("_queue")
		var kept: Dictionary = boot.get("manifest")
		_check(queued.is_empty() and kept.is_empty(), "boot.gd refuses %s" % JSON.stringify(packs))
		boot.free()
		if is_instance_valid(http):
			http.free()

func _test_veg_cells() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var b := VegBatch.get_for(host, BIRCH)
	_check(b != null, "birch batch builds")
	if b == null:
		return
	var tall := Basis.IDENTITY.scaled(Vector3.ONE * (8.0 / VegBatch.mesh_height(BIRCH)))
	var pts: Array[Vector3] = [Vector3(5, 0, 5), Vector3(20, 0, 3), Vector3(40, 0, 5), Vector3(-5, 0, -70)]
	for p in pts:
		b.add(Transform3D(tall, p))
	b.commit()
	_check(b.get_child_count() == 3, "4 trees in 3 cells make 3 cell nodes (got %d)" % b.get_child_count())
	_check(b.cell_for(0) == b.cell_for(1) and b.cell_for(0) != b.cell_for(2), "trees share a cell only inside one 32 m cell")
	# The headless RenderingServer does not store MultiMesh transforms, so read what VegBatch writes.
	for i in pts.size():
		var cell := b.cell_for(i)
		var local: Transform3D = b._local_xform(i, cell.position)
		_check((cell.position + local.origin).distance_to(pts[i]) < 0.001, "instance %d keeps its world position" % i)
		_check(is_equal_approx(cell.visibility_range_end, VegBatch.CELL_RANGE_END_M), "cell %d has a visibility range" % i)
		_check(cell.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "an 8 m tree casts a shadow")
		_check(absf(cell.position.x - pts[i].x) <= VegBatch.CELL_M * 0.5 and absf(cell.position.z - pts[i].z) <= VegBatch.CELL_M * 0.5, "cell %d sits on its trees" % i)
	b.set_shown(1, false)
	var c := b.cell_for(1)
	_check(b._local_xform(1, c.position).basis.get_scale().x < 0.01, "set_shown(false) hides that instance")
	_check(b._local_xform(0, c.position).basis.get_scale().x > 0.5, "set_shown leaves its cell mate visible")
	b.set_shown(1, true)
	_check(b._local_xform(1, c.position).basis.get_scale().x > 0.5, "set_shown(true) shows it again")
	var j := b.add(Transform3D(tall, Vector3(41, 0, 6)))
	_check(b.cell_for(j) == b.cell_for(2) and b.cell_for(j).multimesh.instance_count == 2, "add after commit lands in its cell")
	_check(b._xforms[j].origin == Vector3(41, 0, 6) and b.instance_count() == 5, "_xforms keeps world transforms by index")
	var r := VegBatch.get_for(host, ROCK)
	_check(r != null, "rock batch builds")
	if r:
		var rock_m := func(m: float) -> Basis: return Basis.IDENTITY.scaled(Vector3.ONE * (m / VegBatch.mesh_height(ROCK)))
		r.add(Transform3D(rock_m.call(1.0), Vector3(3, 0, 3)))
		r.commit()
		_check(r.cell_for(0).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a 1 m rock casts no shadow")
		# Shadows are per cell: a tall rock added later in another cell turns on only that cell.
		var far := r.add(Transform3D(rock_m.call(4.0), Vector3(70, 0, 3)))
		_check(r.cell_for(far).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "a 4 m rock casts a shadow")
		_check(r.cell_for(0).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the 1 m rock's cell stays shadowless")
		var late := r.add(Transform3D(rock_m.call(1.0), Vector3(3, 0, 70)))
		_check(r.cell_for(late).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a 1 m rock added after a tall one stays shadowless")
		var near := r.add(Transform3D(rock_m.call(4.0), Vector3(6, 0, 6)))
		_check(r.cell_for(near) == r.cell_for(0) and r.cell_for(0).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "a tall add re-decides its cell's shadow")
	_check(VegBatch.get_for(host, BIRCH) == b, "get_for reuses the batch")
	host.free()

func _test_generated_imports() -> void:
	var glbs := 0
	var mats := 0
	var emissive := 0
	var textures := 0
	var over := 0
	for dir in ["res://assets/nature/generated", "res://assets/resources/generated"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".glb"):
				continue
			var packed := load(dir.path_join(f)) as PackedScene
			_check(packed != null, "%s loads" % f)
			if packed == null:
				continue
			glbs += 1
			var inst := packed.instantiate()
			for n in inst.find_children("*", "MeshInstance3D", true, false):
				var mesh := (n as MeshInstance3D).mesh
				for s in (mesh.get_surface_count() if mesh else 0):
					var m := mesh.surface_get_material(s) as BaseMaterial3D
					if m == null:
						continue
					mats += 1
					if m.emission_enabled or m.emission_texture != null:
						emissive += 1
					for p in BaseMaterial3D.TEXTURE_MAX:
						var tex := m.get_texture(p as BaseMaterial3D.TextureParam)
						if tex:
							textures += 1
							if maxi(tex.get_width(), tex.get_height()) > 512:
								over += 1
			inst.free()
	print("[t_web] generated glbs=%d materials=%d emissive=%d texture_slots=%d over_512px=%d" % [glbs, mats, emissive, textures, over])
	_check(glbs >= 60 and mats >= glbs, "every generated GLB loads with materials")
	_check(emissive == 0, "no generated material keeps emission (%d do)" % emissive)
	_check(textures > 0 and over == 0, "generated textures are capped at 512 px (%d over)" % over)
