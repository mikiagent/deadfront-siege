extends SceneTree
## Structure-set checks: every building kind resolves to a GLB; Blender GLBs import with the one
## shared atlas material, stay under 4k triangles, match the manifest AABB within 5 %, carry the
## named pivot nodes, the four drying-rack stages are distinct models, and the harbour shows the pier.
## Run: Godot --headless --path game --script res://tests/t_structart.gd

const ATLAS_MAT := "res://assets/props/blender/structures_atlas.tres"
const ATLAS_PNG := "res://assets/props/blender/structures_atlas.png"
const GRID := 8
## Atlas tile order (lib.TILES); only the tiles the stage check reads.
const TILE_INDEX := {"wood": 0, "bark": 3, "canvas": 8, "meat_raw": 24, "meat_drying": 25, "meat_dried": 26, "canvas_slope": 33}
const LIGHTING_JSON := "res://data/world/lighting.json"
## Area-weighted mean of N.sun over the canvas the iso camera sees on the tent at rot 0.
const TENT_MIN_SUNLIT := 0.35
## Owner rule: the stages must read by value, not hue alone. Minimum Rec.709 luma steps between
## tile means, and dried must stay clear of the rack's own bark poles.
const STAGE_LUMA_STEP := 10.0
const DRIED_VS_FRAME := 20.0
const STAND_INS := ["floor", "wall", "wall_doorway", "roof"]
const MAX_TRIS := 4000
const TOL := 0.05
## Rows whose GLB is one piece of a larger assembly: aabb_m is the assembly (the collider), which must
## cover the footprint; the piece itself is only checked for triangles and material.
const ASSEMBLIES := ["taming_pen"]
## W1-HARBOUR's t_harbour: the dock must be a composite of at least this many meshes.
const HARBOUR_MIN_PARTS := 20

var failures: Array[String] = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	# Data is an autoload; `--script` compiles this before singletons exist.
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var data: Node = get_root().get_node("Data")
	var buildings: Dictionary = (data.get("props_manifest") as Dictionary).get("buildings", {})
	_check_rows(buildings)
	_check_stages(buildings)
	_check_tent_faces_sun(buildings)
	_check_pivots(buildings)
	_check_harbour(buildings)
	_check_atlas()
	_check_replacement_marks(buildings)
	# a GDScript runtime error returns the default (false) and carries on, so an aborted check must fail
	if not _check_hooks(buildings):
		failures.append("hook checks aborted by a script error (see above)")
	if failures.is_empty():
		print("[t_structart] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_structart] FAIL %s" % f)
		quit(1)
	return true

func _check_rows(buildings: Dictionary) -> void:
	var blender := 0
	for kind: String in buildings:
		var row: Dictionary = buildings[kind]
		var glb := str(row.get("glb", ""))
		if glb == "":
			var model := str(row.get("model", ""))
			if model == "" or not ResourceLoader.exists("res://assets/props/kenney/%s.glb" % model):
				failures.append("%s resolves to no GLB" % kind)
			elif str(row.get("art_status", "")) != "REPLACE":
				failures.append("%s uses a Kenney placeholder without art_status REPLACE" % kind)
			continue
		blender += 1
		var aabb: Variant = row.get("aabb_m", [])
		if kind in ASSEMBLIES:
			var fp: Array = row.get("footprint", [1, 1])
			if not (aabb is Array and (aabb as Array).size() >= 3 and float(aabb[0]) >= 0.9 * float(fp[0]) and float(aabb[2]) >= 0.9 * float(fp[1])):
				failures.append("%s: aabb_m %s does not cover its %s footprint (it sizes the collider)" % [kind, aabb, fp])
			aabb = null
		_check_glb(kind, glb, aabb)
	if blender < 20:
		failures.append("only %d kinds use Blender GLBs" % blender)

func _check_glb(kind: String, path: String, aabb_m: Variant) -> void:
	if not ResourceLoader.exists(path):
		failures.append("%s: %s missing" % [kind, path])
		return
	var root := (load(path) as PackedScene).instantiate() as Node3D
	var tris := 0
	var mats := {}
	for mi: MeshInstance3D in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			tris += (idx as PackedInt32Array).size() / 3 if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var m := mi.get_active_material(s)
			mats[m.resource_path if m else "<none>"] = true
	if tris > MAX_TRIS:
		failures.append("%s: %d tris" % [kind, tris])
	if mats.size() != 1 or not mats.has(ATLAS_MAT):
		failures.append("%s: materials %s, want only %s" % [kind, mats.keys(), ATLAS_MAT])
	var size := _aabb(root, Transform3D.IDENTITY).size
	if aabb_m is Array and (aabb_m as Array).size() >= 3:
		var want := Vector3(float(aabb_m[0]), float(aabb_m[1]), float(aabb_m[2]))
		for k in 3:
			if absf(size[k] - want[k]) > TOL * maxf(want[k], 0.2):
				failures.append("%s: AABB %s vs manifest %s" % [kind, size, want])
				break
	elif aabb_m != null:
		failures.append("%s: no aabb_m" % kind)
	root.free()

func _check_stages(buildings: Dictionary) -> void:
	var before := failures.size()
	var row: Dictionary = buildings.get("drying_rack", {})
	var stages: Array = row.get("stages", [])
	var ids: Array[String] = []
	var uvs: Array[PackedVector2Array] = []
	for st: Dictionary in stages:
		ids.append(str(st.get("id", "")))
		var glb := str(st.get("glb", ""))
		_check_glb("drying_rack." + str(st.get("id", "")), glb, row.get("aabb_m", []))
		var all_uv := PackedVector2Array()
		if ResourceLoader.exists(glb):  # a missing stage is already a failure from _check_glb
			var root := (load(glb) as PackedScene).instantiate() as Node3D
			for mi: MeshInstance3D in _meshes(root):
				all_uv.append_array(mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] as PackedVector2Array)
			root.free()
		uvs.append(all_uv)
	if ids != ["empty", "raw", "drying", "dried"]:
		failures.append("drying_rack stages %s" % [ids])
		return
	# Raw, drying and dried hang the same strips; a stage only reads if its UVs (atlas tile) differ.
	for i in range(1, 4):
		for j in range(i + 1, 4):
			if uvs[i] == uvs[j]:
				failures.append("drying_rack %s and %s look identical" % [ids[i], ids[j]])
	if uvs[0].size() >= uvs[1].size():
		failures.append("empty drying rack is not lighter than the raw stage")
	if failures.size() == before:  # only claim "distinct" when this check added no failure
		print("[t_structart] drying_rack stages %s distinct" % [ids])

## At rot 0 the iso camera must see sunlit canvas on the tent, not the slope in shade all day (review:
## the default tent rendered as a near-black slab). Sun = W1-LIGHT's noon (mid yaw band, peak elevation).
func _check_tent_faces_sun(buildings: Dictionary) -> void:
	var path := str((buildings.get("tent", {}) as Dictionary).get("glb", ""))
	if not ResourceLoader.exists(path):
		return  # already a failure from _check_rows
	var yaw_band: Array = [-35.0, -85.0]  # W1-LIGHT default profile, used until lighting.json is merged
	var elevation := 58.0
	if FileAccess.file_exists(LIGHTING_JSON):
		var prof: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIGHTING_JSON))
		if prof is Dictionary and (prof as Dictionary).get("default") is Dictionary:
			var d: Dictionary = prof["default"]
			yaw_band = d.get("sun_yaw_deg", yaw_band)
			elevation = float(d.get("sun_max_elevation_deg", elevation))
	var yaw := (float(yaw_band[0]) + float(yaw_band[1])) * 0.5
	# A DirectionalLight3D shines along -Z and the camera looks along -Z, so +Z points at each.
	var to_sun := Basis.from_euler(Vector3(deg_to_rad(-elevation), deg_to_rad(yaw), 0.0)).z
	var to_cam := Basis.from_euler(Vector3(deg_to_rad(-35.264), deg_to_rad(45.0), 0.0)).z
	var seen := 0.0
	var lit := 0.0
	var root := (load(path) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in _meshes(root):
		var xf := _xform_in(root, mi)
		for sidx in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(sidx)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
			for t in range(0, idx.size(), 3):
				var a := idx[t]
				var b := idx[t + 1]
				var c := idx[t + 2]
				var cuv := (uv[a] + uv[b] + uv[c]) / 3.0
				var tile := int(cuv.y * GRID) * GRID + int(cuv.x * GRID)
				if tile != int(TILE_INDEX["canvas"]) and tile != int(TILE_INDEX["canvas_slope"]):
					continue
				var n := (xf.basis * (nrm[a] + nrm[b] + nrm[c])).normalized()
				var facing := n.dot(to_cam)
				if facing <= 0.05:
					continue
				var area := (xf * v[b] - xf * v[a]).cross(xf * v[c] - xf * v[a]).length() * 0.5 * facing
				seen += area
				lit += area * maxf(0.0, n.dot(to_sun))
	root.free()
	var ratio := lit / seen if seen > 0.0 else 0.0
	print("[t_structart] tent at rot 0: camera-side canvas sunlit %.2f (min %.2f), sun yaw %.0f elevation %.0f" % [ratio, TENT_MIN_SUNLIT, yaw, elevation])
	if ratio < TENT_MIN_SUNLIT:
		failures.append("tent at rot 0 shows its shaded slope to the camera (sunlit %.2f < %.2f)" % [ratio, TENT_MIN_SUNLIT])

func _xform_in(root: Node, n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

func _check_pivots(buildings: Dictionary) -> void:
	for pair: Array in [["fence_gate", "LeafL"], ["fence_gate", "LeafR"], ["catapult", "Arm"]]:
		var path := str((buildings.get(pair[0], {}) as Dictionary).get("glb", ""))
		if path == "" or not ResourceLoader.exists(path):
			failures.append("%s glb missing" % pair[0])
			continue
		var root := (load(path) as PackedScene).instantiate() as Node3D
		var n := root.find_child(pair[1], true, false) as Node3D
		if n == null:
			failures.append("%s has no %s node" % [pair[0], pair[1]])
		elif n.position.length() < 0.3:
			failures.append("%s/%s origin %s is not on its hinge/axle" % [pair[0], pair[1], n.position])
		root.free()

## world-harbour-07: harbour.gd shows buildings.harbour.glb in place of its Kenney composite. The row's
## footprint must be HarbourSite's (the layout ghost reads it) and the pier must fit it: its landward
## end stops at the base row, where travel lands the survivor.
func _check_harbour(buildings: Dictionary) -> void:
	var row: Dictionary = buildings.get("harbour", {})
	var glb := str(row.get("glb", ""))
	if glb == "":
		failures.append("harbour has no glb row, so the dock stays the Kenney composite")
		return
	var fp: Vector2i = (load("res://scripts/world/harbour_site.gd") as GDScript).get_script_constant_map()["FOOTPRINT"]
	var row_fp: Array = row.get("footprint", [])
	if row_fp.size() != 2 or Vector2i(int(row_fp[0]), int(row_fp[1])) != fp:
		failures.append("harbour footprint %s is not HarbourSite.FOOTPRINT %s" % [row.get("footprint"), fp])
	var h: Node3D = (load("res://scripts/world/harbour.gd") as GDScript).new()
	get_root().add_child(h)
	var vis := h.get_node_or_null("Visual") as Node3D
	if vis == null or vis.scene_file_path != glb:
		failures.append("harbour Visual is %s, not %s" % [vis.scene_file_path if vis else "<none>", glb])
	else:
		var box := _aabb(vis, Transform3D.IDENTITY)  # harbour space
		if box.size.x > fp.x * (1.0 + TOL) or box.position.z < -fp.y * 0.5 * (1.0 + TOL) or box.end.z > fp.y * 0.5 * (1.0 + TOL):
			failures.append("harbour pier %s overruns its %s footprint" % [box, fp])
		# W1-HARBOUR's t_harbour rule, so this branch cannot turn that test red: the dock is a
		# composite of >= 20 props and never a BoxMesh.
		var meshes := _meshes(vis)
		var boxes := meshes.filter(func(m: MeshInstance3D) -> bool: return m.mesh is BoxMesh).size()
		if meshes.size() < HARBOUR_MIN_PARTS or boxes > 0:
			failures.append("harbour pier is %d meshes (%d boxes); t_harbour wants a prop composite (>= %d meshes, no BoxMesh)" % [meshes.size(), boxes, HARBOUR_MIN_PARTS])
		var col := _harbour_collider(h)
		print("[t_structart] harbour shows %s: %d parts, x %.2f m, z %.2f..%.2f m, deck at y %.2f (footprint %s); tap box z %.2f..%.2f" % [glb.get_file(), meshes.size(), box.size.x, box.position.z, box.end.z, vis.position.y + 1.2, fp, col.position.z, col.end.z])
	h.free()

## The harbour's tap box in harbour space (zero when it has none).
func _harbour_collider(h: Node3D) -> AABB:
	for c in h.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var size: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
			return AABB((c as CollisionShape3D).position - size * 0.5, size)
	return AABB()

## harbour.gd hook: with the manifest pier the tap box ends where the pier does, not 2 m out over water.
func _check_harbour_collider_hook() -> void:
	var h: Node3D = (load("res://scripts/world/harbour.gd") as GDScript).new()
	get_root().add_child(h)
	var vis := h.get_node_or_null("Visual") as Node3D
	if vis:
		var pier := _aabb(vis, Transform3D.IDENTITY)
		var col := _harbour_collider(h)
		if absf(col.position.z - pier.position.z) > 0.25 or absf(col.end.z - pier.end.z) > 0.25 or col.size.x < pier.size.x - 0.1:
			failures.append("hook: harbour tap box z %.2f..%.2f x %.2f does not match the pier z %.2f..%.2f x %.2f" % [col.position.z, col.end.z, col.size.x, pier.position.z, pier.end.z, pier.size.x])
	h.free()

func _check_atlas() -> void:
	# Without mipmaps the grain aliases and shimmers at iso distance (the pier deck went moire).
	var tex := load(ATLAS_PNG) as Texture2D
	if tex == null or not tex.get_image().has_mipmaps():
		failures.append("%s imported without mipmaps" % ATLAS_PNG)
	var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PNG))
	if img == null:
		failures.append("cannot read %s" % ATLAS_PNG)
		return
	var luma := {}
	for tile: String in TILE_INDEX:
		luma[tile] = _tile_luma(img, int(TILE_INDEX[tile]))
	var order := ["meat_raw", "meat_drying", "meat_dried"]
	for i in range(order.size() - 1):
		if float(luma[order[i]]) - float(luma[order[i + 1]]) < STAGE_LUMA_STEP:
			failures.append("%s luma %.0f is not clearly darker than %s %.0f" % [order[i + 1], luma[order[i + 1]], order[i], luma[order[i]]])
	if float(luma["bark"]) - float(luma["meat_dried"]) < DRIED_VS_FRAME:
		failures.append("dried strips (luma %.0f) camouflage against the bark frame (%.0f)" % [luma["meat_dried"], luma["bark"]])
	print("[t_structart] stage luma raw %.0f drying %.0f dried %.0f, frame bark %.0f" % [luma["meat_raw"], luma["meat_drying"], luma["meat_dried"], luma["bark"]])

func _tile_luma(img: Image, index: int) -> float:
	var tile := img.get_width() / GRID
	var x0 := (index % GRID) * tile
	var y0 := (index / GRID) * tile
	var sum := 0.0
	var n := 0
	for y in range(y0, y0 + tile, 2):
		for x in range(x0, x0 + tile, 2):
			var c := img.get_pixel(x, y)  # PNG values are sRGB-encoded, which is what the review measured
			sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return sum / n * 255.0

func _check_replacement_marks(buildings: Dictionary) -> void:
	# Owner rule (2026-10-19): low-quality / low-poly assets are marked for replacement.
	for kind: String in STAND_INS:
		if str((buildings.get(kind, {}) as Dictionary).get("art_status", "")) != "REPLACE":
			failures.append("building-system stand-in %s is not marked REPLACE" % kind)
	for kind: String in buildings:
		var row: Dictionary = buildings[kind]
		if str(row.get("glb", "")) != "" and str(row.get("upgrade", "")) == "":
			failures.append("%s: low-poly Blender row has no upgrade path" % kind)

## Integrator hooks (tools/blender/structures/integrator_hooks.patch on W1-BUILD's files). Checked only
## once applied, i.e. when PropVisuals resolves the gate to the Blender GLB; before that the Kenney
## gate is expected and this is skipped.
func _check_hooks(buildings: Dictionary) -> bool:
	# loaded at run time: PropVisuals reads the Data autoload, which a --script cannot see at compile time
	var pv := load("res://scripts/world/prop_visuals.gd") as GDScript
	var gate_glb := str((buildings.get("fence_gate", {}) as Dictionary).get("glb", ""))
	if str(pv.call("model_path", &"gate")) != gate_glb:
		print("[t_structart] hooks not applied (gate resolves to %s), hook checks skipped" % pv.call("model_path", &"gate"))
		return true
	for kind: String in buildings:
		var glb := str((buildings[kind] as Dictionary).get("glb", ""))
		var as_kind: StringName = &"gate" if kind == "fence_gate" else (&"makeshift_taming_pen" if kind == "taming_pen" else StringName(kind))
		if glb != "" and str(pv.call("model_path", as_kind)) != glb:
			failures.append("hook: %s resolves to %s, not %s" % [kind, pv.call("model_path", as_kind), glb])
	var pen: Vector3 = pv.call("collision_size", &"makeshift_taming_pen", null)
	if pen.x < 3.6 or pen.z < 3.6:
		failures.append("hook: taming pen collider %s is a fence segment, not the 4x4 ring" % pen)
	_check_gate_hook()
	_check_catapult_hook()
	_check_harbour_collider_hook()
	print("[t_structart] hooks applied: gate leaves, catapult model, pen collider and harbour tap box checked")
	return true

func _check_gate_hook() -> void:
	var gate: Node3D = (load("res://scripts/world/placed_building.gd") as GDScript).call("make", &"gate")
	get_root().add_child(gate)
	var prop := gate.get_node_or_null("Prop")
	var leaves: Array[MeshInstance3D] = []
	for n: String in ["LeafL", "LeafR"]:
		var leaf: MeshInstance3D = prop.find_child(n, true, false) as MeshInstance3D if prop else null
		if leaf == null:
			failures.append("hook: placed gate has no Prop/%s" % n)
		else:
			leaves.append(leaf)
	# W1-BUILD's plank leaf was placed for the Kenney doorway; on the Blender gate it is a stray panel.
	if gate.get_node_or_null("GateHinge") != null:
		failures.append("hook: the Kenney plank GateHinge leaf still spawns on the Blender gate")
	if leaves.size() == 2:
		if not _doorway_blocked(gate, leaves):
			failures.append("hook: closed gate leaves do not span the doorway")
		gate.call("set_gate_open", true)
		if _doorway_blocked(gate, leaves):
			failures.append("hook: open gate leaves still cross the doorway (L %.0f deg, R %.0f deg)" % [leaves[0].rotation_degrees.y, leaves[1].rotation_degrees.y])
		gate.call("set_gate_open", false)
		if not _doorway_blocked(gate, leaves):
			failures.append("hook: gate leaves do not close again")
	gate.free()

## True when any leaf covers the middle of the 1.6 m doorway (|x| < 0.5 in gate space).
func _doorway_blocked(gate: Node3D, leaves: Array[MeshInstance3D]) -> bool:
	for leaf in leaves:
		var box := gate.global_transform.affine_inverse() * leaf.global_transform * leaf.mesh.get_aabb()
		if box.position.x < 0.5 and box.end.x > -0.5:
			return true
	return false

func _check_catapult_hook() -> void:
	var cat: Node3D = (load("res://scripts/world/field_catapult.gd") as GDScript).new()
	get_root().add_child(cat)
	if cat.get_node_or_null("Prop") == null:
		failures.append("hook: field catapult did not attach the Blender model")
	for c in cat.get_children():
		if c is MeshInstance3D and ((c as MeshInstance3D).mesh is BoxMesh or (c as MeshInstance3D).mesh is CylinderMesh):
			failures.append("hook: field catapult still builds its primitive placeholder")
			break
	cat.free()

## Same corner-transform measure PropVisuals uses for colliders, kept local so this test does not
## depend on W1-BUILD's file.
func _aabb(n: Node, parent: Transform3D) -> AABB:
	var xf := parent * (n as Node3D).transform if n is Node3D else parent
	var box := AABB()
	var have := false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		box = xf * (n as MeshInstance3D).mesh.get_aabb()
		have = true
	for c in n.get_children():
		var cb := _aabb(c, xf)
		if cb.size != Vector3.ZERO:
			box = box.merge(cb) if have else cb
			have = true
	return box

func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
