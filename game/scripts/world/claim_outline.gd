class_name ClaimOutline
extends RefCounted
## Spec 18's claim edge (durango-domain-claims.webp, durango-house-4x4.webp): a dotted yellow line on
## the ground around claimed land. One dash per metre of outline, drawn only where the tile across
## is not the same owner's (touching plots read as one domain), each dash a flat quad on the
## terrain: one mesh for the island, rebuilt by IslandClaims whenever claims change. Quads, not
## lines: a line is 1 px in both renderers and vanished on the grass.

const DASH := 0.45  ## metres of dash per metre of edge
const WIDTH := 0.13
const LIFT := 0.07  ## above the ground (or the sea, where an edge runs into the shallows)
const COLOR := Color(0.96, 0.82, 0.36, 0.85)

static func make_instance() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "ClaimBoundary"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = COLOR
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## The dashes around every claimed region on the runtime (its own claims and other players').
static func build(rt: IslandRuntime) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var v := vertices(rt)
	if not v.is_empty():
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in v:
			im.surface_add_vertex(p)
		im.surface_end()
	return im

## Six vertices (two triangles) per dash, world space.
static func vertices(rt: IslandRuntime) -> PackedVector3Array:
	var rects: Array[Rect2i] = rt.claims.duplicate()
	for row in rt.other_claims:
		rects.append(row["rect"])
	var out := PackedVector3Array()
	var seen := {}
	for r in rects:
		for i in r.size.x:
			out.append_array(_dash(rt, seen, Vector2i(r.position.x + i, r.position.y), Vector2i(0, -1)))
			out.append_array(_dash(rt, seen, Vector2i(r.position.x + i, r.end.y - 1), Vector2i(0, 1)))
		for i in r.size.y:
			out.append_array(_dash(rt, seen, Vector2i(r.position.x, r.position.y + i), Vector2i(-1, 0)))
			out.append_array(_dash(rt, seen, Vector2i(r.end.x - 1, r.position.y + i), Vector2i(1, 0)))
	return out

## The dash on the side of `tile` facing `out`; none when that side is inside the same owner's land
## or another rect already drew it.
static func _dash(rt: IslandRuntime, seen: Dictionary, tile: Vector2i, out: Vector2i) -> PackedVector3Array:
	var v := PackedVector3Array()
	var mid := Vector2(tile) + Vector2(0.5, 0.5) + Vector2(out) * 0.5
	if seen.has(mid) or _owner_id(rt, tile) == _owner_id(rt, tile + out):
		return v
	seen[mid] = true
	var along := Vector2(-out.y, out.x) * DASH * 0.5
	var across := Vector2(out) * WIDTH * 0.5
	var quad := [mid - along - across, mid + along - across, mid + along + across, mid - along + across]
	for k in [0, 1, 2, 0, 2, 3]:
		var p: Vector2 = quad[k]
		v.append(Vector3(p.x, maxf(rt.surface_y(p.x, p.y), HarbourSite.WATER_Y) + LIFT, p.y))
	return v

static func _owner_id(rt: IslandRuntime, tile: Vector2i) -> String:
	return str(IslandClaims.owner_at(rt, tile).get("id", ""))
