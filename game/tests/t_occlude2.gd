extends SceneTree
## OCCLUDE2 (the survivor is always visible): the selection logic behind the fade — which props
## fade for a given camera and survivor position, each one on its own, and how fast.
## t_occlude.gd keeps the material/shader mechanics; this file covers what the player sees:
## between objects on the sight line only, per-object independence, no pops, roofs (inside mode)
## fading under or behind the survivor, bushes fading while a tree's trunk stays solid.
## Run: Godot --headless --path game --script res://tests/t_occlude2.gd
## Game classes are load()ed on the first frame: `--script` compiles this file before they exist.

var _fails: PackedStringArray = []
var _started := false
## Cases that reached their ok line; an aborted case (script error) skips its ok line, so the total
## is checked too.
var _oks := 0
const CASES := 5
var _occ: GDScript

## The iso camera's forward vector and the unit vector from the survivor towards it (t_occlude.gd).
const FWD := Vector3(-0.5773503, -0.5773503, -0.5773503)
const BACK := Vector3(0.5773503, 0.5773503, 0.5773503)
## The survivor's chest (the player origin is its capsule centre, 0.9 m above the feet).
const CHEST := Vector3(0, 1.2, 0)

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _run() -> void:
	_occ = load("res://scripts/world/occlusion.gd")
	await _test_between_selection()
	await _test_per_object()
	await _test_smooth_fade()
	_test_auto_fade()
	_test_body_rule()
	if _oks < CASES:
		_fails.append("only %d of %d cases ran to their ok line (a script error aborted one)" % [_oks, CASES])
	if _fails.is_empty():
		print("[t_occlude2] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_occlude2] FAIL %s" % f)
		quit(1)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)

func _since() -> int:
	return _fails.size()

func _ok(case_name: String, since: int) -> void:
	if _fails.size() == since:
		_oks += 1
		print("[t_occlude2] ok %s" % case_name)

func _k(name: String) -> float:
	var map: Dictionary = _occ.get_script_constant_map()
	_check(map.has(name), "the system has constant %s" % name)
	return float(map.get(name, 0.0))

## A box prop with material_override (the headless renderer reads instance parameters back only
## through an override), as t_occlude.gd's _box_prop.
static func _box_prop(parent: Node3D, pos: Vector3, size := Vector3(2, 6, 2)) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.55, 0.2)
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## A prop's trunk line as the shader reads it (null before it is ever set counts as 0).
static func _trunk_of(n: GeometryInstance3D) -> float:
	var v: Variant = n.get_instance_shader_parameter(&"occl_trunk")
	return 0.0 if v == null else float(v)

func _stage() -> Node3D:
	var n := Node3D.new()
	get_root().add_child(n)
	return n

## The driver, one frame after the first make_occludable(), with _process off so the case steps
## the fades by hand.
func _drv() -> Node:
	await process_frame
	var d: Node = _occ.driver()
	_check(d != null, "the occlusion driver exists")
	if d != null:
		d.set_process(false)
	return d

## Where the survivor stands behind a tree: only props whose footprint crosses the sight line fade.
func _test_between_selection() -> void:
	var since := _since()
	var root3 := _stage()
	var on_line := _box_prop(root3, CHEST + BACK * 6.0)
	var beside := _box_prop(root3, CHEST + BACK * 6.0 + Vector3(-7, 0, 7))
	var behind := _box_prop(root3, CHEST - BACK * 8.0)
	for p in [on_line, beside, behind]:
		_check(_occ.make_occludable(p, "between") == 1, "between_selection: %s converts" % p.name)
	var drv: Node = await _drv()
	var hits: Dictionary = drv.in_the_way(CHEST, BACK)
	var obj_of := {}
	for p in [on_line, beside, behind]:
		var objs: Array = drv._owned.get(p.get_instance_id(), [])
		_check(objs.size() == 1, "between_selection: %s is one object (got %d)" % [p.name, objs.size()])
		if objs.size() == 1:
			obj_of[p] = objs[0]
	_check(hits.size() == 1, "between_selection: one of the three props is in the way (got %d)" % hits.size())
	_check(hits.has(obj_of.get(on_line)), "between_selection: the prop on the sight line is the hit")
	for p in [beside, behind]:
		_check(not hits.has(obj_of.get(p)), "between_selection: %s stays solid" % p.name)
	drv.step_between(hits, 1.0, FWD)
	_check(is_equal_approx(_occ.fade_of(on_line), 1.0), "between_selection: the hit fades (got %f)" % _occ.fade_of(on_line))
	for p in [beside, behind]:
		_check(is_equal_approx(_occ.fade_of(p), 0.0), "between_selection: %s never fades (got %f)" % [p.name, _occ.fade_of(p)])
	drv.set_process(true)
	for p in [on_line, beside, behind]:
		_occ.release(p)
	root3.free()
	_ok("between_selection", since)

## Props fade one by one: two on the line, one leaves the line, the other keeps its fade.
func _test_per_object() -> void:
	var since := _since()
	var root3 := _stage()
	var near := _box_prop(root3, CHEST + BACK * 4.0)
	var far := _box_prop(root3, CHEST + BACK * 10.0)
	for p in [near, far]:
		_check(_occ.make_occludable(p, "between") == 1, "per_object: %s converts" % p.name)
	var drv: Node = await _drv()
	var hits: Dictionary = drv.in_the_way(CHEST, BACK)
	_check(hits.size() == 2, "per_object: both props are on the sight line (got %d)" % hits.size())
	drv.step_between(hits, 1.0, FWD)
	_check(is_equal_approx(_occ.fade_of(near), 1.0) and is_equal_approx(_occ.fade_of(far), 1.0),
			"per_object: both fade fully (%f, %f)" % [_occ.fade_of(near), _occ.fade_of(far)])
	# The far prop alone leaves the line (a step around it), the near one is still in the way.
	var far_obj: Variant = (drv._owned.get(far.get_instance_id(), []) as Array)[0]
	var only := hits.duplicate()
	only.erase(far_obj)
	drv.step_between(only, 1.0, FWD)
	_check(is_equal_approx(_occ.fade_of(near), 1.0), "per_object: the prop still in the way keeps its fade")
	_check(is_equal_approx(_occ.fade_of(far), 0.0), "per_object: the prop out of the way goes back to solid (got %f)" % _occ.fade_of(far))
	drv.set_process(true)
	for p in [near, far]:
		_occ.release(p)
	root3.free()
	_ok("per_object", since)

## The scatter's one hook: bushes (1.4 m and up) opt in, rocks do not, trees get a solid trunk line.
func _test_auto_fade() -> void:
	var since := _since()
	var tall := _k("TALL_M")
	var tree_m := _k("TREE_M")
	var frac := _k("TRUNK_FRAC")
	_check(tall > 1.3 and tall <= 2.2, "auto_fade: a bush (1.5-2.2 m) is tall enough to fade (TALL_M %f)" % tall)
	_check(tree_m > tall and tree_m < 7.0, "auto_fade: a tree starts above a bush and under the shortest palm (TREE_M %f)" % tree_m)
	var root3 := _stage()
	var rock := _box_prop(root3, Vector3(20, 0, 20), Vector3(1, 1, 1))
	_check(not _occ.auto_fade(rock, 1.0), "auto_fade: a 1 m rock stays solid")
	_check(_occ.mode_of(rock) == "", "auto_fade: the rock is not made occludable")
	var bush := _box_prop(root3, Vector3(20, 0, 24), Vector3(1.6, 0.9, 1.6))
	_check(_occ.auto_fade(bush, 1.8), "auto_fade: a 1.8 m bush fades")
	_check(_occ.mode_of(bush) == _occ.BETWEEN, "auto_fade: the bush is a between prop")
	_check(_trunk_of(bush) == 0.0, "auto_fade: the whole bush fades (no trunk line)")
	var tree := _box_prop(root3, Vector3(20, 0, 28), Vector3(1, 9, 1))
	_check(_occ.auto_fade(tree, 9.0), "auto_fade: a 9 m tree fades")
	_check(is_equal_approx(_trunk_of(tree), 9.0 * frac),
			"auto_fade: the tree's trunk line is TRUNK_FRAC of its height (got %f)" % _trunk_of(tree))
	_check(is_equal_approx(float(tree.get_meta(&"occl_trunk", 0.0)), 9.0 * frac), "auto_fade: the trunk line is on the node too")
	_occ.release(tree)
	_check(_trunk_of(tree) == 0.0, "auto_fade: release clears the trunk line")
	for p in [rock, bush, tree]:
		_occ.release(p)
	root3.free()
	_ok("auto_fade", since)

## The survivor's own silhouette: the shader's cover share and the CPU's constant agree, and the rule
## sits where every fade has to pass (the include's occl_cut, called by every occluder shader).
func _test_body_rule() -> void:
	var since := _since()
	var f := FileAccess.open("res://scripts/world/occlu_fade.gdshaderinc", FileAccess.READ)
	_check(f != null, "body_rule: the include reads")
	var code := f.get_as_text() if f else ""
	_check(code.contains("global uniform vec4 occl_body"), "body_rule: the include has the survivor's screen silhouette")
	_check(code.contains("instance uniform float occl_trunk"), "body_rule: the trunk line is a per-prop parameter")
	var drop := _k("BODY_DROP")
	var at := code.find("OCCL_COVER_DROP = ")
	_check(at > 0, "body_rule: the include declares OCCL_COVER_DROP")
	if at > 0:
		var line := code.substr(at, code.find(";", at) - at)
		var v := float(line.get_slice("=", 1).strip_edges())
		_check(is_equal_approx(v, drop), "body_rule: BODY_DROP (%f) matches the shader's OCCL_COVER_DROP (%f)" % [drop, v])
		_check(drop > 0.55 and drop < 0.9, "body_rule: the cover share hides most, not all, of the prop (%f)" % drop)
	var cut := code.find("void occl_cut(")
	_check(cut > 0 and code.substr(cut).contains("occl_body"), "body_rule: the survivor's silhouette is applied in occl_cut")
	var body := code.substr(cut)
	# Inside the survivor's silhouette a trunked prop must still thin (they show through their own trunk),
	# so the rule there is the cover share whatever the trunk line says.
	_check(body.contains("max(trunk ? 0.0 : occl_drop, OCCL_COVER_DROP)"),
			"body_rule: the survivor's silhouette ignores the trunk line (a trunk may hide them)")
	var b := FileAccess.open("res://scripts/world/occlu_occluder_standard.gdshaderinc", FileAccess.READ)
	var std := b.get_as_text() if b else ""
	_check(std.contains("occl_cut(FRAGCOORD.xy);"), "body_rule: the standard occluder calls occl_cut")
	_check(std.rfind("occl_cut(FRAGCOORD.xy);") > std.rfind("ALBEDO ="), "body_rule: the cut comes after the pixels are shaded")
	_ok("body_rule", since)

## No pops: the fade takes at least 0.15 s and no single 60 Hz frame moves the drop by > 0.25.
func _test_smooth_fade() -> void:
	var since := _since()
	var fade_s := _k("FADE_S")
	var drop := _k("BETWEEN_DROP")
	_check(fade_s >= 0.15, "smooth_fade: FADE_S is at least 0.15 s (got %f)" % fade_s)
	var root3 := _stage()
	var prop := _box_prop(root3, CHEST + BACK * 6.0)
	_check(_occ.make_occludable(prop, "between") == 1, "smooth_fade: the prop converts")
	var drv: Node = await _drv()
	var hits: Dictionary = drv.in_the_way(CHEST, BACK)
	_check(hits.size() == 1, "smooth_fade: the prop is in the way (got %d)" % hits.size())
	var dt := 1.0 / 60.0
	var prev := 0.0
	var worst := 0.0
	var frames := 0
	while _occ.fade_of(prop) < 1.0 and frames < 600:
		drv.step_between(hits, dt, FWD)
		var f: float = _occ.fade_of(prop)
		worst = maxf(worst, absf(f - prev) * drop)
		prev = f
		frames += 1
	_check(is_equal_approx(_occ.fade_of(prop), 1.0), "smooth_fade: the fade reaches full (got %f)" % _occ.fade_of(prop))
	_check(frames * dt >= 0.15 - 1e-4, "smooth_fade: the fade takes %.3f s (>= 0.15)" % (frames * dt))
	_check(worst <= 0.25, "smooth_fade: the biggest one-frame alpha step is %.3f (<= 0.25)" % worst)
	# And back out, same rule.
	prev = 1.0
	worst = 0.0
	frames = 0
	while _occ.fade_of(prop) > 0.0 and frames < 600:
		drv.step_between({}, dt, FWD)
		var f: float = _occ.fade_of(prop)
		worst = maxf(worst, absf(f - prev) * drop)
		prev = f
		frames += 1
	_check(worst <= 0.25, "smooth_fade: the fade back is %.3f per frame at most (<= 0.25)" % worst)
	drv.set_process(true)
	_occ.release(prop)
	root3.free()
	_ok("smooth_fade", since)
