class_name Occlusion
extends Node
## One see-through system for whatever can hide the survivor. Props opt in with
## make_occludable(node, mode):
##   "between": only the part between the camera and the survivor fades (tall trees, big rocks,
##              upper walls); the rest of the prop and its shadow stay whole.
##   "inside":  the whole prop fades while the survivor stands under it and is solid from
##              outside (roofs, ceilings).
## The fade is a dithered discard inside the prop's own material (shaders/occlusion/), driven by
## two global shader parameters this node writes every frame: no blending, sorting or extra pass,
## the same in Forward+ and gl_compatibility. Nothing changes on screen while nothing is in the way.
## The first make_occludable() call adds one Occlusion node under the tree root (no autoload).

const BETWEEN := "between"
const INSIDE := "inside"
## Props at least this tall can cover the survivor at the iso pitch (island_scatter's hook).
const TALL_M := 2.4
## Sight-line radius around the survivor's chest. The 1.8 m survivor shows ~1.5 m tall at the iso
## pitch; 1.4 m keeps the whole body and a little ground clear.
const RADIUS_M := 1.4
const CHEST_UP_M := 0.3  # the player's origin is its capsule centre, 0.9 m above the feet
const FADE_PER_S := 5.0
## "inside": how far past a roof's edge the survivor still counts as under it, and how far below.
const EDGE_M := 0.3
const BELOW_M := 10.0

## --no-occlusion turns the system off (baseline frame time and pixels for comparisons).
static var enabled: bool = not ("--no-occlusion" in OS.get_cmdline_user_args())
static var _driver: Occlusion
static var _globals_ready := false
## "<source id>|<mode>" -> WeakRef(ShaderMaterial): props share one derived material per source,
## and it frees itself with the last prop that uses it.
static var _cache: Dictionary = {}
## "<mesh id>|<mode>" -> WeakRef(Mesh): multi-surface meshes drawn by a MultiMesh need a copy.
static var _twins: Dictionary = {}

## Inside-mode nodes: instance id -> {"node", "geoms", "fade"}.
var _inside: Dictionary = {}

## Makes `node` and every mesh under it fade for the survivor in `mode`. Returns the number of
## surfaces that now fade (0 when disabled or nothing convertible). Same mode again is a no-op;
## another mode replaces the first. Meshes added under `node` later are converted too.
static func make_occludable(node: Node, mode: String = BETWEEN) -> int:
	if not enabled or node == null or not (mode in [BETWEEN, INSIDE]):
		return 0
	var cur := mode_of(node)
	if cur == mode:
		return int(node.get_meta(&"occl_surfaces", 0))
	if cur != "":
		release(node)
	_ensure_driver()
	var n := 0
	var geoms: Array = []
	for gi in _geometry(node):
		var k := _convert(gi, mode)
		if k > 0:
			geoms.append(gi)
			n += k
	node.set_meta(&"occl_mode", mode)
	node.set_meta(&"occl_surfaces", n)
	var watch := _driver._on_child.bind(node)
	node.set_meta(&"occl_watch", watch)
	node.child_entered_tree.connect(watch)
	if mode == INSIDE:
		_driver._inside[node.get_instance_id()] = {"node": node, "geoms": geoms, "fade": 0.0}
	return n

## Puts the original materials back and forgets `node`.
static func release(node: Node) -> void:
	if node == null or not node.has_meta(&"occl_mode"):
		return
	for gi in _geometry(node):
		_restore(gi)
	var watch: Callable = node.get_meta(&"occl_watch")
	if node.child_entered_tree.is_connected(watch):
		node.child_entered_tree.disconnect(watch)
	for k in [&"occl_mode", &"occl_surfaces", &"occl_watch"]:
		node.remove_meta(k)
	if _driver:
		_driver._inside.erase(node.get_instance_id())

## "between", "inside" or "" when `node` is not occludable.
static func mode_of(node: Node) -> String:
	return str(node.get_meta(&"occl_mode", "")) if node else ""

## Inside mode: 0 solid .. 1 gone.
static func fade_of(node: Node) -> float:
	if _driver == null or node == null or not _driver._inside.has(node.get_instance_id()):
		return 0.0
	return float(_driver._inside[node.get_instance_id()]["fade"])

## Derived materials still alive (a leak check: back to the old count once props are released or freed).
static func live_materials() -> int:
	for k in _cache.keys():
		if (_cache[k] as WeakRef).get_ref() == null:
			_cache.erase(k)
	return _cache.size()

## The node every frame runs on; null until the first make_occludable().
static func driver() -> Occlusion:
	return _driver

static func _ensure_driver() -> void:
	if not _globals_ready:
		# Added from code, once per run, so project.godot stays untouched (get_list is editor-only).
		_globals_ready = true
		for g in [&"occl_target", &"occl_view"]:
			RenderingServer.global_shader_parameter_add(g, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
	if is_instance_valid(_driver):
		return
	var tree := Engine.get_main_loop() as SceneTree
	_driver = Occlusion.new()
	_driver.name = "Occlusion"
	_driver.process_mode = Node.PROCESS_MODE_ALWAYS
	# Deferred: the first caller is usually a scene still setting up its children.
	tree.root.add_child.call_deferred(_driver)

static func _geometry(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		out.append(node)
	for c in node.find_children("*", "GeometryInstance3D", true, false):
		if c is MeshInstance3D or c is MultiMeshInstance3D:
			out.append(c)
	return out

## Swaps one mesh's materials for derived ones; remembers the originals on the node.
static func _convert(gi: GeometryInstance3D, mode: String) -> int:
	if gi.has_meta(&"occl_orig"):
		return 0
	var orig := {}
	var n := 0
	var mesh: Mesh = (gi as MeshInstance3D).mesh if gi is MeshInstance3D else null
	var mm: MultiMesh = (gi as MultiMeshInstance3D).multimesh if gi is MultiMeshInstance3D else null
	if mm:
		mesh = mm.mesh
	if mesh == null:
		return 0
	if gi.material_override or (mm and mesh.get_surface_count() == 1):
		var d := _derived(gi.material_override if gi.material_override else mesh.surface_get_material(0), mode)
		if d:
			orig["override"] = gi.material_override
			gi.material_override = d
			n = mesh.get_surface_count()
	elif mm:
		var twin := _twin(mesh, mode)
		if twin:
			orig["mesh"] = mesh
			mm.mesh = twin
			n = mesh.get_surface_count()
	else:
		var mi := gi as MeshInstance3D
		var subs: Array = []
		for s in mesh.get_surface_count():
			var cur := mi.get_surface_override_material(s)
			subs.append(cur)
			var d := _derived(cur if cur else mesh.surface_get_material(s), mode)
			if d:
				mi.set_surface_override_material(s, d)
				n += 1
		if n > 0:
			orig["surfaces"] = subs
	if n > 0:
		gi.set_meta(&"occl_orig", orig)
	return n

static func _restore(gi: GeometryInstance3D) -> void:
	if not gi.has_meta(&"occl_orig"):
		return
	var orig: Dictionary = gi.get_meta(&"occl_orig")
	gi.remove_meta(&"occl_orig")
	gi.set_instance_shader_parameter(&"occl_fade", 0.0)
	if orig.has("override"):
		gi.material_override = orig["override"]
	if orig.has("mesh"):
		(gi as MultiMeshInstance3D).multimesh.mesh = orig["mesh"]
	if orig.has("surfaces"):
		var subs: Array = orig["surfaces"]
		for s in subs.size():
			(gi as MeshInstance3D).set_surface_override_material(s, subs[s])

static func _derived(src: Material, mode: String) -> ShaderMaterial:
	if src == null:
		return null
	var key := "%d|%s" % [src.get_instance_id(), mode]
	var d := (_cache[key] as WeakRef).get_ref() as ShaderMaterial if _cache.has(key) else null
	if d == null:
		d = OcclusionMaterial.derive(src, mode)
		if d == null:
			if not OcclusionMaterial._warned.has(src.get_class()):
				OcclusionMaterial._warned[src.get_class()] = true
				print("[occlusion] %s stays solid: only BaseMaterial3D can fade" % src.get_class())
			return null
		_cache[key] = weakref(d)
	return d

static func _twin(mesh: Mesh, mode: String) -> Mesh:
	var key := "%d|%s" % [mesh.get_instance_id(), mode]
	var t := (_twins[key] as WeakRef).get_ref() as Mesh if _twins.has(key) else null
	if t:
		return t
	t = mesh.duplicate() as Mesh
	if t == null or t.get_surface_count() != mesh.get_surface_count():
		return null
	var any := false
	for s in t.get_surface_count():
		var d := _derived(mesh.surface_get_material(s), mode)
		if d:
			t.surface_set_material(s, d)
			any = true
	if not any:
		return null
	_twins[key] = weakref(t)
	return t

## A mesh added under an occludable node later (a VegBatch cell committed after the hook ran).
func _on_child(child: Node, owner_node: Node) -> void:
	_adopt.call_deferred(child, owner_node)

func _adopt(child: Node, owner_node: Node) -> void:
	if not is_instance_valid(child) or not is_instance_valid(owner_node):
		return
	var mode := mode_of(owner_node)
	if mode == "" or not child.is_inside_tree():
		return
	var added := 0
	for gi in _geometry(child):
		var k := _convert(gi, mode)
		if k > 0:
			added += k
			if _inside.has(owner_node.get_instance_id()):
				(_inside[owner_node.get_instance_id()]["geoms"] as Array).append(gi)
	owner_node.set_meta(&"occl_surfaces", int(owner_node.get_meta(&"occl_surfaces", 0)) + added)

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var who := get_tree().get_first_node_in_group("player") as Node3D
	if cam == null or who == null or not who.is_inside_tree():
		RenderingServer.global_shader_parameter_set(&"occl_target", Vector4.ZERO)
		return
	var p := who.get_global_transform_interpolated().origin
	var chest := p + Vector3.UP * CHEST_UP_M
	var fwd := -cam.global_basis.z
	RenderingServer.global_shader_parameter_set(&"occl_target", Vector4(chest.x, chest.y, chest.z, RADIUS_M))
	RenderingServer.global_shader_parameter_set(&"occl_view", Vector4(fwd.x, fwd.y, fwd.z, 0.0))
	step_inside(p, delta)

## Moves every inside-mode fade toward "survivor under it" (public so tests can drive it).
func step_inside(p: Vector3, delta: float) -> void:
	for id in _inside.keys():
		var e: Dictionary = _inside[id]
		if not is_instance_valid(e["node"]):
			_inside.erase(id)
			continue
		var target := 1.0 if _under(e["geoms"], p) else 0.0
		var f := move_toward(float(e["fade"]), target, FADE_PER_S * delta)
		if f == float(e["fade"]):
			continue
		e["fade"] = f
		for gi in e["geoms"]:
			if is_instance_valid(gi):
				(gi as GeometryInstance3D).set_instance_shader_parameter(&"occl_fade", f)

## Under any of the meshes' footprints, below its top and not far below its bottom.
static func _under(geoms: Array, p: Vector3) -> bool:
	for gi in geoms:
		if not is_instance_valid(gi) or not (gi as Node3D).is_inside_tree():
			continue
		var g := gi as GeometryInstance3D
		var box := g.get_aabb()
		var q := g.global_transform.affine_inverse() * p
		if q.y < box.end.y and q.y > box.position.y - BELOW_M \
				and q.x > box.position.x - EDGE_M and q.x < box.end.x + EDGE_M \
				and q.z > box.position.z - EDGE_M and q.z < box.end.z + EDGE_M:
			return true
	return false
