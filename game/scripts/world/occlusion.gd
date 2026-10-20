class_name Occlusion
extends Node
## One see-through system for whatever can hide the survivor. Props opt in with
## make_occludable(node, mode):
##   "between": a prop standing between the camera and the survivor fades AS A WHOLE OBJECT to
##              about half its pixels (BETWEEN_DROP) over FADE_S, so its trunk, crown and outline
##              stay readable while the survivor shows through (tall trees, big rocks, upper walls).
##              Each MultiMesh instance (a VegBatch tree) is its own object; any other node is one
##              object made of every mesh under it.
##   "inside":  the whole prop fades to a faint outline (INSIDE_DROP) while the survivor stands
##              under it and is solid from outside (roofs, ceilings).
## The fade is an ordered-dither discard inside the prop's own material (shaders/occlusion/): no
## blending, sorting or extra pass, the same in Forward+ and gl_compatibility. This node decides
## each frame which props are in the way (a grid lookup along the sight line, then a few cylinder
## or box tests) and steps their fades. Nothing changes on screen while nothing is in the way.
## The first make_occludable() call adds one Occlusion node under the tree root (no autoload).

const BETWEEN := "between"
const INSIDE := "inside"
## Props at least this tall can cover the survivor at the iso pitch (island_scatter's hook).
## ASSUMPTION: 2.4 m; every scattered rock today is under 1.5 m, so only trees and palms fade.
const TALL_M := 2.4
## Share of pixels a faded prop drops: 9 of the 16 dither cells, so the prop keeps 7/16 (44 %) and
## a survivor fully behind it shows 9/16 (56 %). Owner 2026-10-20: partly see-through, never a hole.
## ASSUMPTION: 9/16, the dither level nearest half that still shows at least half the survivor.
const BETWEEN_DROP := 0.55
## ASSUMPTION: 14 of 16 cells: a roof over the survivor keeps a faint readable outline.
const INSIDE_DROP := 0.85
const FADE_S := 0.25
const CHEST_UP_M := 0.3  # the player's origin is its capsule centre, 0.9 m above the feet
## The survivor's body around the chest for the sight test: half width, head above, feet below.
const BODY_R_M := 0.3
const HEAD_M := 0.6
const FEET_M := 1.2
## "inside": how far past a roof's edge the survivor still counts as under it, and how far below.
const EDGE_M := 0.3
const BELOW_M := 10.0
## Sight-test grid cell. Objects are filed by centre, so a lookup widens by the largest radius.
const GRID_M := 8.0
## MultiMesh instances that can fade at once (occl_slot_0..7 in the shader).
const SLOTS := 8
const SLOT_NAMES: Array[StringName] = [&"occl_slot_0", &"occl_slot_1", &"occl_slot_2", &"occl_slot_3",
	&"occl_slot_4", &"occl_slot_5", &"occl_slot_6", &"occl_slot_7"]
## Longest sight line tested, metres along the view ray.
const REACH_MAX_M := 60.0

## --no-occlusion turns the system off (baseline frame time and pixels for comparisons).
static var enabled: bool = not ("--no-occlusion" in OS.get_cmdline_user_args())
static var _driver: Occlusion
static var _globals_ready := false
## "<source id>" -> WeakRef(ShaderMaterial): props share one derived material per source, and it
## frees itself with the last prop that uses it.
static var _cache: Dictionary = {}
## "<mesh id>" -> WeakRef(Mesh): multi-surface meshes drawn by a MultiMesh need a copy.
static var _twins: Dictionary = {}

## One thing that fades as a whole: a MultiMesh instance (mmi + slot) or a node's meshes (geoms).
class Obj:
	var owner_id: int
	var key: Vector2i
	var inst := false  # a MultiMesh instance (mmi + slot), else a node's meshes
	var mmi: MultiMeshInstance3D
	var slot: int = -1
	var origin: Vector3  # instance: world origin (the shader finds itself by it); node: box centre
	var geoms: Array = []
	var box: AABB  # node object: world bounds of its meshes
	var fade: float = 0.0
	var sent: float = 0.0

## Inside-mode nodes: instance id -> {"node", "geoms", "fade"}.
var _inside: Dictionary = {}
## Between objects: grid cell -> Array of Obj; owner node id -> Array of Obj.
var _grid: Dictionary = {}
var _owned: Dictionary = {}
## Obj -> true while it is in the way or still fading back.
var _active: Dictionary = {}
## [owner id, MultiMeshInstance3D, frames waited] still to be read (see _add_instances).
var _pending: Array = []
var _max_r := 0.0
var _max_top := -INF
var _slots_used := 0

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
		var k := _convert(gi)
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
	else:
		_driver._add_objects(node, geoms)
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
		_driver._forget(node.get_instance_id())

## "between", "inside" or "" when `node` is not occludable.
static func mode_of(node: Node) -> String:
	return str(node.get_meta(&"occl_mode", "")) if node else ""

## 0 solid .. 1 fully faded (to its mode's share): an inside node, or a between node's own meshes.
static func fade_of(node: Node) -> float:
	if _driver == null or node == null:
		return 0.0
	var id := node.get_instance_id()
	if _driver._inside.has(id):
		return float(_driver._inside[id]["fade"])
	for o: Obj in _driver._owned.get(id, []):
		if not o.inst:
			return o.fade
	return 0.0

## 0 solid .. 1 fully faded: one MultiMesh instance of a between node.
static func instance_fade(mmi: MultiMeshInstance3D, slot: int) -> float:
	if _driver == null or mmi == null:
		return 0.0
	for o: Obj in _driver._active:
		if o.inst and o.mmi == mmi and o.slot == slot:
			return o.fade
	return 0.0

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
		RenderingServer.global_shader_parameter_add(&"occl_view", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
		for g in SLOT_NAMES:
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
static func _convert(gi: GeometryInstance3D) -> int:
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
		var d := _derived(gi.material_override if gi.material_override else mesh.surface_get_material(0))
		if d:
			orig["override"] = gi.material_override
			gi.material_override = d
			n = mesh.get_surface_count()
	elif mm:
		var twin := _twin(mesh)
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
			var d := _derived(cur if cur else mesh.surface_get_material(s))
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

static func _derived(src: Material) -> ShaderMaterial:
	if src == null:
		return null
	var key := str(src.get_instance_id())
	var d := (_cache[key] as WeakRef).get_ref() as ShaderMaterial if _cache.has(key) else null
	if d == null:
		d = OcclusionMaterial.derive(src)
		if d == null:
			if not OcclusionMaterial._warned.has(src.get_class()):
				OcclusionMaterial._warned[src.get_class()] = true
				print("[occlusion] %s stays solid: only BaseMaterial3D can fade" % src.get_class())
			return null
		_cache[key] = weakref(d)
	return d

static func _twin(mesh: Mesh) -> Mesh:
	var key := str(mesh.get_instance_id())
	var t := (_twins[key] as WeakRef).get_ref() as Mesh if _twins.has(key) else null
	if t:
		return t
	t = mesh.duplicate() as Mesh
	if t == null or t.get_surface_count() != mesh.get_surface_count():
		return null
	var any := false
	for s in t.get_surface_count():
		var d := _derived(mesh.surface_get_material(s))
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
	var geoms: Array = []
	for gi in _geometry(child):
		var k := _convert(gi)
		if k > 0:
			added += k
			geoms.append(gi)
	if mode == INSIDE and _inside.has(owner_node.get_instance_id()):
		(_inside[owner_node.get_instance_id()]["geoms"] as Array).append_array(geoms)
	elif mode == BETWEEN:
		_add_objects(owner_node, geoms)
	owner_node.set_meta(&"occl_surfaces", int(owner_node.get_meta(&"occl_surfaces", 0)) + added)

## Files `geoms` of a between node: one object per MultiMesh instance, one for all plain meshes.
func _add_objects(owner_node: Node, geoms: Array) -> void:
	if geoms.is_empty():
		return
	if not owner_node.is_inside_tree():
		owner_node.tree_entered.connect(_add_objects.bind(owner_node, geoms), CONNECT_ONE_SHOT)
		return
	var id := owner_node.get_instance_id()
	if not _owned.has(id):
		_owned[id] = []
		# shortcut: a between node taken out of the tree stops fading for good; re-add it with release() + make_occludable().
		var bye := _forget.bind(id)
		if not owner_node.tree_exiting.is_connected(bye):
			owner_node.tree_exiting.connect(bye, CONNECT_ONE_SHOT)
	var plain: Obj = null
	for o: Obj in _owned[id]:
		if not o.inst:
			plain = o
	for gi in geoms:
		if gi is MultiMeshInstance3D:
			_pending.append([id, gi, 0])
			continue
		if plain == null:
			plain = Obj.new()
			plain.owner_id = id
			plain.box = (gi as GeometryInstance3D).global_transform * (gi as GeometryInstance3D).get_aabb()
			_owned[id].append(plain)
		else:
			_unfile(plain)
		plain.geoms.append(gi)
		plain.box = plain.box.merge((gi as GeometryInstance3D).global_transform * (gi as GeometryInstance3D).get_aabb())
		plain.origin = plain.box.get_center()
		_file(plain, 0.5 * Vector2(plain.box.size.x, plain.box.size.z).length(), plain.box.end.y)

## Instance transforms read back as zero until the next physics-interpolation tick, so cells are
## filed a frame (or a few) after they arrive.
func _flush_pending() -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var e: Array = _pending[i]
		if not is_instance_valid(e[1]) or not _owned.has(e[0]):
			_pending.remove_at(i)
			continue
		var mmi := e[1] as MultiMeshInstance3D
		var mm := mmi.multimesh
		var ready := mm == null or mm.instance_count == 0 or mm.get_instance_transform(0).basis.determinant() != 0.0
		if ready or e[2] > 30:
			_pending.remove_at(i)
			_add_instances(e[0], mmi)
		else:
			e[2] += 1

## shortcut: instances are read once, when the cell is filed; one added to that MultiMesh later
## never fades (VegBatch commits every cell once, after the scatter). Upgrade if batches grow at runtime.
func _add_instances(id: int, mmi: MultiMeshInstance3D) -> void:
	var mm := mmi.multimesh
	if mm == null or mm.mesh == null or not mmi.is_inside_tree():
		return
	var box := mm.mesh.get_aabb()
	var gx := mmi.global_transform
	for slot in mm.instance_count:
		var xf := gx * mm.get_instance_transform(slot)
		var o := Obj.new()
		o.owner_id = id
		o.inst = true
		o.mmi = mmi
		o.slot = slot
		o.origin = xf.origin
		var s := xf.basis.get_scale()
		_file(o, 0.5 * maxf(box.size.x * s.x, box.size.z * s.z), (xf * box).end.y)
		_owned[id].append(o)

func _file(o: Obj, r: float, top: float) -> void:
	o.key = Vector2i(floori(o.origin.x / GRID_M), floori(o.origin.z / GRID_M))
	if not _grid.has(o.key):
		_grid[o.key] = []
	_grid[o.key].append(o)
	_max_r = maxf(_max_r, r)
	_max_top = maxf(_max_top, top)

func _unfile(o: Obj) -> void:
	var cell: Array = _grid.get(o.key, [])
	cell.erase(o)
	if cell.is_empty():
		_grid.erase(o.key)

func _forget(id: int) -> void:
	for o: Obj in _owned.get(id, []):
		_unfile(o)
		_active.erase(o)
	_owned.erase(id)

func _process(delta: float) -> void:
	if not _pending.is_empty():
		_flush_pending()
	var cam := get_viewport().get_camera_3d()
	# ASSUMPTION: the survivor is the one this screen follows (IsoCamera's target), so other players
	# never drive the fade; the first "player" in the group otherwise.
	var t: Variant = cam.get(&"_target") if cam else null
	var who: Node3D = t if is_instance_valid(t) and t is Node3D else get_tree().get_first_node_in_group("player") as Node3D
	var hits := {}
	if cam and who and who.is_inside_tree():
		var p := who.get_global_transform_interpolated().origin
		var chest := p + Vector3.UP * CHEST_UP_M
		var back := cam.global_basis.z if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else (cam.global_position - chest).normalized()
		hits = in_the_way(chest, back)
		var fwd := -cam.global_basis.z
		step_between(hits, delta, fwd)
		step_inside(p, delta)
	else:
		step_between(hits, delta, Vector3.ZERO)

## Between objects whose bounds (widened by the survivor's body) cross the sight line from `chest`
## towards the camera along `back` (unit). Obj -> true. Public so tests can drive it.
func in_the_way(chest: Vector3, back: Vector3) -> Dictionary:
	var out := {}
	if _grid.is_empty():
		return out
	var reach := REACH_MAX_M
	if back.y > 0.05:
		reach = clampf((_max_top + FEET_M - chest.y) / back.y, 0.0, REACH_MAX_M)
	var dxz := Vector2(back.x, back.z)
	var flat := dxz.length()
	var dir := dxz / flat if flat > 0.01 else Vector2.ZERO
	var far := Vector2(chest.x, chest.z) + dxz * reach
	var pad := _max_r + BODY_R_M
	var lo := Vector2(minf(chest.x, far.x), minf(chest.z, far.y)) - Vector2.ONE * pad
	var hi := Vector2(maxf(chest.x, far.x), maxf(chest.z, far.y)) + Vector2.ONE * pad
	var reach_xz := reach * flat
	for gx in range(floori(lo.x / GRID_M), floori(hi.x / GRID_M) + 1):
		for gz in range(floori(lo.y / GRID_M), floori(hi.y / GRID_M) + 1):
			var cell: Array = _grid.get(Vector2i(gx, gz), [])
			for i in range(cell.size() - 1, -1, -1):
				var o: Obj = cell[i]
				# Cheap reject on the filed origin first: most of the box is off the line.
				var rel := Vector2(o.origin.x - chest.x, o.origin.z - chest.z)
				var along := rel.dot(dir)
				if along < -pad or along > reach_xz + pad or absf(rel.cross(dir)) > pad:
					continue
				if not o.inst:
					if _box_hit(o.box, chest, back, reach):
						out[o] = true
				elif not is_instance_valid(o.mmi):
					cell.remove_at(i)
				elif _instance_hit(o, chest, back):
					out[o] = true
	return out

## Live transform: a harvested VegBatch tree is shrunk in place, a regrown one comes back.
static func _instance_hit(o: Obj, chest: Vector3, back: Vector3) -> bool:
	var mm := o.mmi.multimesh
	if o.slot >= mm.instance_count:
		return false
	var xf := o.mmi.global_transform * mm.get_instance_transform(o.slot)
	var s := xf.basis.get_scale()
	var box := mm.mesh.get_aabb()
	var wb := xf * box
	if wb.size.y < 0.05:
		return false
	var c := wb.get_center()
	var r := 0.5 * maxf(box.size.x * s.x, box.size.z * s.z) + BODY_R_M
	return ray_hits_cylinder(chest, back, Vector2(c.x, c.z), r, wb.position.y - HEAD_M, wb.end.y + FEET_M)

static func _box_hit(box: AABB, chest: Vector3, back: Vector3, reach: float) -> bool:
	var b := box.grow(BODY_R_M)
	b.position.y -= HEAD_M - BODY_R_M
	b.size.y += HEAD_M + FEET_M - 2.0 * BODY_R_M
	return b.has_point(chest) or b.intersects_segment(chest, chest + back * maxf(reach, 1.0))

## Does the ray from `s` along unit `b` (t >= 0) cross the vertical cylinder at `c` (xz)?
static func ray_hits_cylinder(s: Vector3, b: Vector3, c: Vector2, r: float, y0: float, y1: float) -> bool:
	var o := Vector2(s.x - c.x, s.z - c.y)
	var d := Vector2(b.x, b.z)
	var a := d.length_squared()
	var t0 := 0.0
	var t1 := 1e6
	if a < 1e-6:
		if o.length_squared() > r * r:
			return false
	else:
		var k := o.dot(d)
		var disc := k * k - a * (o.length_squared() - r * r)
		if disc < 0.0:
			return false
		var sq := sqrt(disc)
		t0 = maxf((-k - sq) / a, 0.0)
		t1 = (-k + sq) / a
		if t1 < t0:
			return false
	var ya := s.y + b.y * t0
	var yb := s.y + b.y * t1
	return maxf(ya, yb) >= y0 and minf(ya, yb) <= y1

## Moves every between fade toward "in the way" and sends the values (public so tests can drive it).
func step_between(hits: Dictionary, delta: float, fwd: Vector3) -> void:
	for o in hits:
		_active[o] = true
	var slotted: Array = []
	for o: Obj in _active.keys():
		o.fade = move_toward(o.fade, 1.0 if hits.has(o) else 0.0, delta / FADE_S)
		if o.inst:
			if o.fade > 0.0 and is_instance_valid(o.mmi):
				slotted.append(o)
		elif absf(o.fade - o.sent) > 0.001 or (o.fade == 0.0 and o.sent != 0.0):
			o.sent = o.fade
			for gi in o.geoms:
				if is_instance_valid(gi):
					(gi as GeometryInstance3D).set_instance_shader_parameter(&"occl_fade", o.fade * BETWEEN_DROP)
		if o.fade == 0.0 and not hits.has(o):
			_active.erase(o)
	_send_slots(slotted, fwd)

## The fadingest MultiMesh instances go to the shader's slots.
## shortcut: past SLOTS at once the faintest stay solid; a denser forest needs more slots or custom data.
func _send_slots(slotted: Array, fwd: Vector3) -> void:
	slotted.sort_custom(func(a: Obj, b: Obj) -> bool: return a.fade > b.fade)
	var used := mini(slotted.size(), SLOTS)
	RenderingServer.global_shader_parameter_set(&"occl_view", Vector4(fwd.x, fwd.y, fwd.z, float(used)))
	if used == 0 and _slots_used == 0:
		return
	for i in maxi(used, _slots_used):
		var v := Vector4(0.0, -1e6, 0.0, 0.0)
		if i < used:
			var o: Obj = slotted[i]
			v = Vector4(o.origin.x, o.origin.y, o.origin.z, o.fade * BETWEEN_DROP)
		RenderingServer.global_shader_parameter_set(SLOT_NAMES[i], v)
	_slots_used = used

## Moves every inside-mode fade toward "survivor under it" (public so tests can drive it).
func step_inside(p: Vector3, delta: float) -> void:
	for id in _inside.keys():
		var e: Dictionary = _inside[id]
		if not is_instance_valid(e["node"]):
			_inside.erase(id)
			continue
		var target := 1.0 if _under(e["geoms"], p) else 0.0
		var f := move_toward(float(e["fade"]), target, delta / FADE_S)
		if f == float(e["fade"]):
			continue
		e["fade"] = f
		for gi in e["geoms"]:
			if is_instance_valid(gi):
				(gi as GeometryInstance3D).set_instance_shader_parameter(&"occl_fade", f * INSIDE_DROP)

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
