class_name ClaimOutline
extends MeshInstance3D
## Spec 18's claim edge (durango-domain-claims.webp, durango-house-4x4.webp): a dotted line on the
## ground around claimed land, long yellow dashes around yours and short coral dots around other
## players'. One dash per metre of outline, drawn only where the tile across is not the same owner's
## (touching plots read as one domain), each dash a flat quad on the terrain or just above the water.
## One mesh for the island, rebuilt by IslandClaims whenever claims change. Of other players' claims
## only the NEAREST to the survivor draw (picked again as they walk), so a crowded island never
## turns into a lattice. Lit and opaque: the dashes dim at night with the ground, and the water,
## drawn after, cannot wash over them where an edge crosses a river.

const DASH := 0.45  ## metres of dash per metre of edge, yours
const DOT := 0.25  ## the same for other players' edges
const WIDTH := 0.13
const LIFT := 0.07  ## above the ground, or the water plane where an edge crosses a river or the shallows
const COLOR := Color(0.96, 0.82, 0.36)
## ASSUMPTION: the references show one colour (yours); other players' edges get a second one.
const OTHER_COLOR := Color(1.0, 0.58, 0.47)
const NEAREST := 4

var _rt: IslandRuntime
var _drawn := PackedInt32Array()  ## the other_claims rows in the mesh
var _tile := Vector2i(1 << 30, 0)  ## the survivor's tile when they were picked

func _init() -> void:
	name = "ClaimBoundary"
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true  # COLOR is sRGB like albedo_color; as linear the yellow washed out to cream
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# The web renderer ignores that flag and burned the full yellow out to cream in daylight (lab: 232, 226, 190
		# against Forward+'s 221, 199, 136); half the albedo lands it next to Forward+.
		mat.albedo_color = Color(0.5, 0.5, 0.5)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Claims changed: pick the rows to draw and rebuild the mesh.
func rebuild(rt: IslandRuntime) -> void:
	_rt = rt
	_drawn = nearest_others(rt, _focus())
	mesh = build(rt, _drawn)

func _process(_delta: float) -> void:
	if _rt == null or _rt.other_claims.size() <= NEAREST:
		return
	var at := _focus()
	if Vector2i(at.floor()) == _tile:
		return
	_tile = Vector2i(at.floor())
	var near := nearest_others(_rt, at)
	if near != _drawn:
		_drawn = near
		mesh = build(_rt, near)

static func _focus() -> Vector2:
	var p := PlayerRegistry.local()
	return Vector2(p.global_position.x, p.global_position.z) if p else Vector2.ZERO

## Indices of the other_claims rows nearest `at` (all of them when there are NEAREST or fewer).
static func nearest_others(rt: IslandRuntime, at: Vector2) -> PackedInt32Array:
	var order := range(rt.other_claims.size())
	if order.size() > NEAREST:
		var d := []
		for row in rt.other_claims:
			var r: Rect2i = row["rect"]
			d.append(at.distance_squared_to(at.clamp(Vector2(r.position), Vector2(r.end))))
		order.sort_custom(func (a: int, b: int) -> bool: return d[a] < d[b])
		order.resize(NEAREST)
	return PackedInt32Array(order)

static func build(rt: IslandRuntime, others: Variant = null) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var arr := dashes(rt, others)
	var v: PackedVector3Array = arr[0]
	var c: PackedColorArray = arr[1]
	if not v.is_empty():
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		im.surface_set_normal(Vector3.UP)
		for i in v.size():
			im.surface_set_color(c[i])
			im.surface_add_vertex(v[i])
		im.surface_end()
	return im

## [PackedVector3Array, PackedColorArray]: six vertices (two triangles) per dash in world space, and
## each one's colour. `others` lists the other_claims rows to outline (null: all of them); your own
## claims always are. Whose each tile is comes from one lookup painted before the loop.
static func dashes(rt: IslandRuntime, others: Variant = null) -> Array:
	var span := maxi(rt._tile_span, 1)
	var off := Vector2i.ONE * int(rt._size * 0.5)  # tile -> pixel, as IslandTerrain indexes tiles
	var grid := Image.create_empty(span, span, false, Image.FORMAT_RF)  # owner index: 0 nobody, 1 you, 2 + row
	var ids := PackedStringArray(["", IslandClaims.SELF_ID])
	for row in rt.other_claims:
		ids.append(str(row["owner"]["id"]))
	# Painted lowest priority first, so a tile is whoever IslandClaims.owner_at says: yours, then the first row.
	for i in range(rt.other_claims.size() - 1, -1, -1):
		var r: Rect2i = rt.other_claims[i]["rect"]
		grid.fill_rect(Rect2i(r.position + off, r.size), Color(i + 2, 0, 0))
	for r in rt.claims:
		grid.fill_rect(Rect2i(r.position + off, r.size), Color(1, 0, 0))
	var who := func (t: Vector2i) -> String:
		var p := t + off
		return ids[int(grid.get_pixelv(p).r)] if p.x >= 0 and p.y >= 0 and p.x < span and p.y < span else ""
	var rows: Array = []  # [rect, colour, dash length]
	for r in rt.claims:
		rows.append([r, COLOR, DASH])
	for i in (range(rt.other_claims.size()) if others == null else others):
		rows.append([rt.other_claims[i]["rect"], OTHER_COLOR, DOT])
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var seen := {}
	for row in rows:
		var r: Rect2i = row[0]
		var sides: Array = []  # [tile, out] per edge tile
		for i in r.size.x:
			sides.append([Vector2i(r.position.x + i, r.position.y), Vector2i(0, -1)])
			sides.append([Vector2i(r.position.x + i, r.end.y - 1), Vector2i(0, 1)])
		for i in r.size.y:
			sides.append([Vector2i(r.position.x, r.position.y + i), Vector2i(-1, 0)])
			sides.append([Vector2i(r.end.x - 1, r.position.y + i), Vector2i(1, 0)])
		for s in sides:
			var q := _dash(rt, seen, who, s[0], s[1], row[2])
			v.append_array(q)
			for k in q.size():
				c.append(row[1])
	return [v, c]

## The dash on the side of `tile` facing `out`; none when that side is inside the same owner's land
## or another rect already drew it.
static func _dash(rt: IslandRuntime, seen: Dictionary, who: Callable, tile: Vector2i, out: Vector2i, length: float) -> PackedVector3Array:
	var v := PackedVector3Array()
	var mid := Vector2(tile) + Vector2(0.5, 0.5) + Vector2(out) * 0.5
	if seen.has(mid) or who.call(tile) == who.call(tile + out):
		return v
	seen[mid] = true
	var along := Vector2(-out.y, out.x) * length * 0.5
	var across := Vector2(out) * WIDTH * 0.5
	var quad: Array[Vector3] = []
	for p: Vector2 in [mid - along - across, mid + along - across, mid + along + across, mid - along + across]:
		quad.append(Vector3(p.x, maxf(rt.surface_y(p.x, p.y), HarbourSite.WATER_Y) + LIFT, p.y))
	for k in [0, 2, 1, 0, 3, 2]:  # clockwise seen from above, Godot's front face: lit by the sun, not from below
		v.append(quad[k])
	return v
