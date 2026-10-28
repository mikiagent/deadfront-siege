extends SceneTree
## OCCLFIX (owner bug, 2026-10-28): "Trees behind the player (from the camera's perspective) are going
## translucent when they should stay solid until the tree hides the player model."
## The rule: an occluder fades ONLY when it stands between the camera and the survivor (nearer the
## camera along the view ray) AND overlaps the survivor on screen. A prop farther from the camera than
## the survivor stays fully solid, even when its crown overlaps her on screen.
## Real setup: the game's own camera (IsoCamera via lab_kit) follows a Player, and the three spots come
## from that camera's live view ray. Every prop kind goes through the scatter's own path: a plain
## MeshInstance3D (occlusion_material), a VegBatch-style MultiMesh tree (the instance slots) and a
## CARD2D card (make_card_occludable, the card shader's occl_fade).
## The fragment rule cannot be seen headless, so the shader's occl_cut is mirrored in GDScript and
## driven with the inputs the CPU actually sends for each spot (the solid prop of the behind case).
## Run: Godot --headless --path game --script res://tests/t_occlfix.gd -> "[t_occlfix] PASS", exit 0/1.
## Game classes are load()ed on the first frame: `--script` compiles this file before they exist.

var _fails: PackedStringArray = []
var _started := false
var _done := false
var _host: Node3D
var _player: Node3D
var _cam: Camera3D
var _occ: GDScript
var _om: GDScript
## The survivor's screen footprint as Occlusion._send_body publishes it: xy centre, zw half sizes.
var _body := Vector4.ZERO

## Cases that reached their ok line (an aborted case prints no ok line; the total is checked too).
var _oks := 0
var _cases := 0
const WATCHDOG_S := 60.0
const INCLUDE := "res://scripts/world/occlu_fade.gdshaderinc"

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	_watchdog()
	return false

func _watchdog() -> void:
	var t := 0.0
	while t < WATCHDOG_S:
		await create_timer(1.0).timeout
		t += 1.0
		if _done:
			return
	print("[t_occlfix] FAIL watchdog (%.0f s)" % WATCHDOG_S)
	quit(1)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_occlfix] FAIL %s" % what)

func _since() -> int:
	return _fails.size()

func _ok(case_name: String, since: int) -> void:
	_cases += 1
	if _fails.size() == since:
		_oks += 1
		print("[t_occlfix] ok %s" % case_name)

func _k(name: String) -> float:
	var map: Dictionary = _occ.get_script_constant_map()
	_check(map.has(name), "the system has constant %s" % name)
	return float(map.get(name, 0.0))

func _run() -> void:
	_occ = load("res://scripts/world/occlusion.gd")
	_om = load("res://scripts/world/occlusion_material.gd")
	_check(_occ.enabled, "occlusion is enabled in this run")
	_host = Node3D.new()
	_host.name = "TOcclfixHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 80.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 14.0
	_player.global_position = Vector3(0, 1, 0)
	_player.reset_physics_interpolation()
	_cam._snap()
	await process_frame
	_body = _body_ellipse()
	# The driver is added deferred by the first make_occludable(): make one, wait for it, then switch
	# its own _process off so every case steps the fades by hand and reads them synchronously.
	var probe := Node3D.new()
	root.add_child(probe)
	var pm := MeshInstance3D.new()
	pm.mesh = BoxMesh.new()
	pm.material_override = StandardMaterial3D.new()
	probe.add_child(pm)
	_occ.make_occludable(probe, _occ.BETWEEN)
	await process_frame
	await process_frame
	_occ.release(probe)
	probe.queue_free()
	var drv: Node = _occ.driver()
	_check(drv != null, "the occlusion driver exists")
	if drv == null:
		_finish()
		return
	drv.set_process(false)
	await _test_mesh(drv)
	await _test_multimesh(drv)
	await _test_card(drv)
	_test_shader_rule()
	drv.set_process(true)
	_finish()

func _finish() -> void:
	_done = true
	if _fails.is_empty() and _oks == _cases and _cases >= 4:
		print("[t_occlfix] PASS")
		quit(0)
		return
	if _oks != _cases:
		print("[t_occlfix] FAIL only %d of %d cases ran to their ok line (a script error aborted one)" % [_oks, _cases])
	print("[t_occlfix] FAIL count=%d" % _fails.size())
	quit(1)

## The survivor's chest: the sight test's start.
func _chest() -> Vector3:
	return _player.global_position + Vector3.UP * _k("CHEST_UP_M")

## The unit direction from the chest towards the camera (Occlusion._process's `back`).
func _back() -> Vector3:
	if _cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return _cam.global_basis.z
	return (_cam.global_position - _chest()).normalized()

## Distance from the camera along its view: smaller than the survivor's depth = in front of her.
func _depth(p: Vector3) -> float:
	return (_cam.global_position - p).dot(-_cam.global_basis.z)

## The three ground spots, from the live camera: behind = farther from it along the view's ground
## direction (up the screen), front = nearer (down the screen), beside = across it.
func _spots() -> Dictionary:
	var chest := _chest()
	var back := _back()
	var flat := Vector3(back.x, 0.0, back.z).normalized()
	var right := Vector3(_cam.global_basis.x.x, 0.0, _cam.global_basis.x.z).normalized()
	var at := Vector3(chest.x, 0.0, chest.z)
	return {"behind": at - flat * 6.0, "front": at + flat * 6.0, "beside": at + right * 7.0, "flat": flat}

## The survivor's screen footprint, as Occlusion._send_body computes it (pixels, origin top left).
func _body_ellipse() -> Vector4:
	var mid := _player.global_position + Vector3.UP * (_k("CHEST_UP_M") - 0.3)
	var up := Vector3.UP
	var right := Vector3.RIGHT
	if _cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		up = _cam.global_basis.y
		right = _cam.global_basis.x
	var c := _cam.unproject_position(mid)
	var rx := c.distance_to(_cam.unproject_position(mid + right * (_k("BODY_R_M") + 0.08)))
	var ry := c.distance_to(_cam.unproject_position(mid + up * _k("BODY_HALF_M")))
	return Vector4(c.x, c.y, maxf(rx, ry), maxf(rx, ry))

func _stage() -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	return n

## The driver object filed for `node` (one per plain-mesh prop, one per MultiMesh instance).
func _obj_of(drv: Node, node: Node) -> Variant:
	var objs: Array = drv._owned.get(node.get_instance_id(), [])
	return objs[0] if objs.size() == 1 else null

## Somewhere up a prop's own axis (`base` + up to `height`) lands on the survivor's screen silhouette.
func _overlaps_screen(base: Vector3, height: float) -> bool:
	var y := 0.0
	while y <= height + 0.01:
		if _in_ellipse(_cam.unproject_position(base + Vector3.UP * y), _body):
			return true
		y += 0.25
	return false

## One prop kind at the three spots. `made`: drv, behind/front/beside (the nodes, standing on the
## ground at their spot), their heights, the driver objects and read_behind/read_front/read_beside,
## each giving the share of pixels the RENDERER ends up dropping for that prop.
func _spot_case(tag: String, made: Dictionary) -> void:
	var since := _since()
	var drv: Node = made["drv"]
	var chest := _chest()
	var back := _back()
	var fwd := -back
	var heights: Dictionary = made["heights"]
	_check(_depth((made["behind"] as Node3D).global_position) < _depth((made["front"] as Node3D).global_position),
			"%s: the behind prop is farther from the camera than the front one" % tag)
	# Both on-ray crowns must overlap her on screen, else the case proves nothing about her silhouette.
	for k in ["behind", "front"]:
		var base: Vector3 = (made[k] as Node3D).global_position
		_check(_depth(base) < _depth(chest) if k == "behind" else _depth(base) > _depth(chest),
				"%s: the %s prop is %s the survivor in view depth (%.1f m vs her %.1f m)" % [
				tag, k, "behind" if k == "behind" else "in front of", _depth(base), _depth(chest)])
		_check(_overlaps_screen(base, float(heights[k])), "%s: the %s prop's body crosses the survivor's screen silhouette" % [tag, k])
	# The CPU's own selection with the live camera's ray.
	var hits: Dictionary = drv.in_the_way(chest, back)
	_check(not hits.has(made["behind_obj"]), "%s: in_the_way does not select the prop BEHIND the survivor" % tag)
	_check(hits.has(made["front_obj"]), "%s: in_the_way selects the prop in front" % tag)
	_check(not hits.has(made["beside_obj"]), "%s: in_the_way does not select the prop beside" % tag)
	# Two full fades: the front one reaches its share, the others must not move at all.
	drv.step_between(hits, _k("FADE_S"), fwd)
	drv.step_between(hits, _k("FADE_S"), fwd)
	var drop := _k("BETWEEN_DROP")
	var behind: float = made["read_behind"].call()
	var front: float = made["read_front"].call()
	var beside: float = made["read_beside"].call()
	_check(is_equal_approx(behind, 0.0), "%s: the prop BEHIND the survivor stays solid (renderer share %.3f, must be 0)" % [tag, behind])
	_check(is_equal_approx(beside, 0.0), "%s: the prop beside her stays solid (renderer share %.3f, must be 0)" % [tag, beside])
	_check(is_equal_approx(front, drop), "%s: the prop IN FRONT fades to BETWEEN_DROP %.3f (got %.3f)" % [tag, drop, front])
	_ok(tag, since)

## Plain 3D props: the material conversion path (occlusion_material -> occlu_occluder_standard).
func _test_mesh(drv: Node) -> void:
	var root3 := _stage()
	var spots := _spots()
	var behind := _box_prop(root3, spots["behind"])
	var front := _box_prop(root3, spots["front"])
	var beside := _box_prop(root3, spots["beside"])
	for p in [behind, front, beside]:
		_check(_occ.make_occludable(p, _occ.BETWEEN) == 1, "mesh: %s converts" % p.name)
	var drop := _k("BETWEEN_DROP")
	var made := {
		"drv": drv, "behind": behind, "front": front, "beside": beside,
		"heights": {"behind": 6.0, "front": 6.0, "beside": 6.0},
		"behind_obj": _obj_of(drv, behind), "front_obj": _obj_of(drv, front), "beside_obj": _obj_of(drv, beside),
		"read_behind": func() -> float: return float(_occ.fade_of(behind)) * drop,
		"read_front": func() -> float: return float(_occ.fade_of(front)) * drop,
		"read_beside": func() -> float: return float(_occ.fade_of(beside)) * drop,
	}
	_spot_case("mesh", made)
	# The instance parameter the occluder shader actually reads (0 while solid).
	var raw: Variant = behind.get_instance_shader_parameter(&"occl_fade")
	_check(typeof(raw) == TYPE_FLOAT and is_equal_approx(float(raw), 0.0), "mesh: the behind prop's occl_fade is 0 (got %s)" % raw)
	raw = front.get_instance_shader_parameter(&"occl_fade")
	_check(typeof(raw) == TYPE_FLOAT and is_equal_approx(float(raw), drop), "mesh: the front prop's occl_fade is BETWEEN_DROP (got %s)" % raw)
	for p in [behind, front, beside]:
		_occ.release(p)
	root3.free()

## A 6 m tall box standing on `pos` (its feet at the spot, like a VegBatch cell).
static func _box_prop(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.55, 0.2)
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 6, 1.4)
	box.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Prop"
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos + Vector3.UP * 3.0
	parent.add_child(mi)
	return mi

## MultiMesh trees, one instance each, filed the way a VegBatch tree is.
func _test_multimesh(drv: Node) -> void:
	var root3 := _stage()
	var spots := _spots()
	var nodes := {}
	for k in ["behind", "front", "beside"]:
		nodes[k] = _mm_tree(root3, spots[k])
	for k in nodes:
		_check(_occ.make_occludable(nodes[k], _occ.BETWEEN) == 1, "multimesh: the %s tree converts" % k)
	for i in 40:
		drv._flush_pending()
		if _obj_of(drv, nodes["behind"]) != null and _obj_of(drv, nodes["front"]) != null:
			break
		await process_frame
	var objs := {}
	for k in nodes:
		objs[k] = _obj_of(drv, nodes[k])
		_check(objs[k] != null, "multimesh: the %s tree is filed as one object" % k)
		if objs[k] != null:
			_check(bool((objs[k] as Object).get("inst")), "multimesh: the %s tree is a MultiMesh instance object" % k)
	var drop := _k("BETWEEN_DROP")
	var made := {
		"drv": drv, "behind": nodes["behind"], "front": nodes["front"], "beside": nodes["beside"],
		"heights": {"behind": 9.0, "front": 9.0, "beside": 9.0},
		"behind_obj": objs["behind"], "front_obj": objs["front"], "beside_obj": objs["beside"],
		"read_behind": func() -> float: return _instance_share(objs["behind"], drop),
		"read_front": func() -> float: return _instance_share(objs["front"], drop),
		"read_beside": func() -> float: return _instance_share(objs["beside"], drop),
	}
	_spot_case("multimesh", made)
	_occ.release(root3)
	root3.free()

## The share the occluder shader ends up with for one MultiMesh instance: the driver's fade for it
## (which is what goes into a slot and what occl_match returns), or 0 when it does not fade.
func _instance_share(o: Variant, drop: float) -> float:
	if o == null:
		return 0.0
	return float((o as Object).get("fade")) * drop

static func _mm_tree(parent: Node3D, pos: Vector3) -> MultiMeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.6, 0.3)
	var box := BoxMesh.new()
	box.size = Vector3(2, 9, 2)
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = 1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	mmi.position = pos + Vector3.UP * 4.5
	parent.add_child(mmi)
	return mmi

## CARD2D cards: the scatter's card path (make_card_occludable) and its occl_fade instance parameter.
func _test_card(drv: Node) -> void:
	var root3 := _stage()
	var spots := _spots()
	var nodes := {}
	for k in ["behind", "front", "beside"]:
		var card := _card(root3, spots[k])
		var n: int = _occ.make_card_occludable(card, _occ.BETWEEN)
		_check(n == 1, "card: the %s card files one mesh (got %d)" % [k, n])
		nodes[k] = card
	var drop := _k("BETWEEN_DROP")
	var made := {
		"drv": drv, "behind": nodes["behind"], "front": nodes["front"], "beside": nodes["beside"],
		"heights": {"behind": 9.0, "front": 9.0, "beside": 9.0},
		"behind_obj": _obj_of(drv, nodes["behind"]), "front_obj": _obj_of(drv, nodes["front"]),
		"beside_obj": _obj_of(drv, nodes["beside"]),
		"read_behind": func() -> float: return float(_occ.fade_of(nodes["behind"])) * drop,
		"read_front": func() -> float: return float(_occ.fade_of(nodes["front"])) * drop,
		"read_beside": func() -> float: return float(_occ.fade_of(nodes["beside"])) * drop,
	}
	_spot_case("card", made)
	var raw: Variant = (nodes["behind"] as GeometryInstance3D).get_instance_shader_parameter(&"occl_fade")
	_check(typeof(raw) == TYPE_FLOAT and is_equal_approx(float(raw), 0.0), "card: the behind card's occl_fade is 0 (got %s)" % raw)
	raw = (nodes["front"] as GeometryInstance3D).get_instance_shader_parameter(&"occl_fade")
	_check(typeof(raw) == TYPE_FLOAT and is_equal_approx(float(raw), drop), "card: the front card's occl_fade is BETWEEN_DROP (got %s)" % raw)
	_occ.release(nodes["behind"])
	root3.free()

## A camera-facing quad standing on `pos`, 9 m tall, with the fade body's per-instance parameter.
static func _card(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 9.0)
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode cull_disabled, depth_draw_opaque, unshaded;\ninstance uniform float occl_fade = 0.0;\nvoid fragment() { ALBEDO = vec3(0.2, 0.5, 0.2); }\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MeshInstance3D.new()
	mi.name = "Card"
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos + Vector3.UP * 4.5
	parent.add_child(mi)
	return mi

## The fragment rule. The shader only has the survivor's screen ellipse and this prop's fade, so its
## maths is mirrored here (see _shader_cut) and driven with what the CPU sends for a solid prop.
func _test_shader_rule() -> void:
	var since := _since()
	var f := FileAccess.open(INCLUDE, FileAccess.READ)
	_check(f != null, "shader_rule: %s reads" % INCLUDE)
	if f == null:
		return
	var code := f.get_as_text()
	_check(code.contains("fract(b.x * 0.5 + b.y * b.y * 0.75) * 0.25 + fract(a.x * 0.5 + a.y * a.y * 0.75)"),
			"shader_rule: the include still has the 4x4 bayer formula this test copies")
	var at := code.find("OCCL_COVER_DROP = ")
	var cover := 0.0
	if at > 0:
		cover = float(code.substr(at, code.find(";", at) - at).get_slice("=", 1).strip_edges())
	_check(is_equal_approx(cover, _k("BODY_DROP")), "shader_rule: OCCL_COVER_DROP %.4f matches BODY_DROP" % cover)
	_body = _body_ellipse()
	_check(_body.z > 1.0 and _body.w > 1.0, "shader_rule: the camera projects the survivor's silhouette (rx %.1f ry %.1f px)" % [_body.z, _body.w])
	# A prop that is NOT fading (the tree behind her, and everything beside her) must not dither at
	# all, over her silhouette or anywhere else.
	var solid_in := 0
	var solid_out := 0
	var solid_samples := 0
	for yi in 40:
		for xi in 40:
			var px := _probe(xi, yi, 40)
			if _in_ellipse(px, _body):
				if _shader_cut(0.0, 4.0, 0.0, px, _body, cover):
					solid_in += 1
			else:
				solid_samples += 1
				if _shader_cut(0.0, 4.0, 0.0, px, _body, cover):
					solid_out += 1
	_check(solid_in == 0, "shader_rule: a solid prop (fade 0: the tree BEHIND the survivor) drops NO pixels over her silhouette (drops %d of them)" % solid_in)
	_check(solid_out == 0, "shader_rule: a solid prop drops nothing outside her silhouette either (drops %d of %d)" % [solid_out, solid_samples])
	# A prop that IS fading still opens over her, so she shows through it.
	var faded_in := 0
	var inside := 0
	for yi in 40:
		for xi in 40:
			var px := _probe(xi, yi, 40)
			if _in_ellipse(px, _body):
				inside += 1
				if _shader_cut(_k("BETWEEN_DROP"), 4.0, 0.0, px, _body, cover):
					faded_in += 1
	var share := float(faded_in) / maxf(1.0, float(inside))
	_check(inside > 400, "shader_rule: the ellipse covers a real area (%d of 1600 probe pixels)" % inside)
	_check(share > 0.6, "shader_rule: a prop that IS fading still opens over her silhouette (drops %.0f%%, must be > 60%%)" % (share * 100.0))
	_ok("shader_rule", since)

## A probe pixel in the survivor-centred square that covers the ellipse and its surroundings.
func _probe(xi: int, yi: int, n: int) -> Vector2:
	var hw := _body.z * 1.6
	var hh := _body.w * 1.6
	return Vector2(_body.x - hw + (xi + 0.5) * hw * 2.0 / n, _body.y - hh + (yi + 0.5) * hh * 2.0 / n)

## occl_cut, transcribed (occlu_fade.gdshaderinc): a trunk never dithers; over the survivor's
## silhouette a FADING prop drops at least OCCL_COVER_DROP; elsewhere it drops its own share against
## the dither. Returns true when the pixel is discarded.
func _shader_cut(drop: float, y: float, trunk_line: float, px: Vector2, body: Vector4, cover: float) -> bool:
	var trunk := y < trunk_line
	var q := (px - Vector2(body.x, body.y)) / Vector2(maxf(body.z, 0.001), maxf(body.w, 0.001))
	if body.w > 0.0 and q.length_squared() < 1.0:
		if maxf(0.0 if trunk else drop, cover) > _bayer4(px):
			return true
		return false
	if trunk:
		return false
	return drop > _bayer4(px)

static func _bayer4(p: Vector2) -> float:
	var a := Vector2(floor(p.x), floor(p.y))
	var b := Vector2(floor(p.x * 0.5), floor(p.y * 0.5))
	return _fract(b.x * 0.5 + b.y * b.y * 0.75) * 0.25 + _fract(a.x * 0.5 + a.y * a.y * 0.75)

static func _fract(x: float) -> float:
	return x - floor(x)

func _in_ellipse(p: Vector2, body: Vector4) -> bool:
	if body.z <= 0.0 or body.w <= 0.0:
		return false
	var q := (p - Vector2(body.x, body.y)) / Vector2(body.z, body.w)
	return q.length_squared() < 1.0
