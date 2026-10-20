class_name IslandClaims
extends RefCounted
## Land claims (M8d Part B) and the dashed boundary mesh that marks them.

## Home: the camp plot (14x14 tiles) is claimed at creation plus whatever was saved.
## Unstable: whatever the player staked this visit. Buildings only go on claimed tiles.
static func setup(rt: IslandRuntime, def: Dictionary) -> void:
	rt.claims.clear()
	var camp_tile := BuildGrid.tile_of(rt._camp_pos)
	var saved: Array = World.claims_for_current()
	if str(def.get("kind", "")) == "private":
		var base := Rect2i(camp_tile - Vector2i(7, 7), Vector2i(14, 14))
		rt.claims.append(base)
		for r in saved:
			if r is Array and (r as Array).size() >= 4:
				rt.claims.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		if saved.is_empty():
			World.home_claims = [[base.position.x, base.position.y, base.size.x, base.size.y]]
	else:
		# ASSUMPTION: the camp landing spot is always buildable on unstable islands (tents, pens).
		rt.claims.append(Rect2i(camp_tile - Vector2i(7, 7), Vector2i(14, 14)))
		for r in saved:
			if r is Array and (r as Array).size() >= 4:
				rt.claims.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	_rebuild_claim_mesh(rt)

static func is_claimed(rt: IslandRuntime, tile: Vector2i) -> bool:
	for r in rt.claims:
		if r.has_point(tile):
			return true
	return false

## Claim a 14x14 plot centred on the tile; returns false when it overlaps water or an existing claim centre.
static func claim_at(rt: IslandRuntime, tile: Vector2i, size: int = 14) -> bool:
	var rect := Rect2i(tile - Vector2i(size / 2, size / 2), Vector2i(size, size))
	var centre := BuildGrid.tile_centre(tile, rt)
	if not rt.spawn_ok(centre, false):
		return false
	rt.claims.append(rect)
	var row := [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if World.is_home():
		World.home_claims.append(row)
	else:
		World.unstable_claims.append(row)
	_rebuild_claim_mesh(rt)
	print("[world] claimed %dx%d at (%d,%d)" % [size, size, tile.x, tile.y])
	return true

static func _rebuild_claim_mesh(rt: IslandRuntime) -> void:
	if rt._claim_mesh == null:
		rt._claim_mesh = MeshInstance3D.new()
		rt._claim_mesh.name = "ClaimBoundary"
		rt._claim_mat = StandardMaterial3D.new()
		rt._claim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rt._claim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Claims should quietly mark ownership, not dominate the camp as a cyan debug ring.
		rt._claim_mat.albedo_color = Color(0.72, 0.74, 0.58, 0.30)
		rt._claim_mat.vertex_color_use_as_albedo = false
		rt._claim_mesh.material_override = rt._claim_mat
		rt._claim_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rt._claim_mesh.extra_cull_margin = 200.0
		rt.add_child(rt._claim_mesh)
	var im := ImmediateMesh.new()
	var any := false
	for r in rt.claims:
		var x0 := float(r.position.x)
		var z0 := float(r.position.y)
		var x1 := float(r.position.x + r.size.x)
		var z1 := float(r.position.y + r.size.y)
		var corners := [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var len := a.distance_to(b)
			var dash := 0.28
			var gap := 0.72
			var t := 0.0
			while t < len:
				var t2 := minf(len, t + dash)
				var pa := a.lerp(b, t / len)
				var pb := a.lerp(b, t2 / len)
				if not any:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					any = true
				im.surface_add_vertex(Vector3(pa.x, rt.surface_y(pa.x, pa.y) + 0.06, pa.y))
				im.surface_add_vertex(Vector3(pb.x, rt.surface_y(pb.x, pb.y) + 0.06, pb.y))
				t += dash + gap
	if any:
		im.surface_end()
	rt._claim_mesh.mesh = im
