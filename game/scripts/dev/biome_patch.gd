class_name BiomePatch
extends RefCounted
## The lab's flat 40x40 m ground patch and its slope probe. Kept apart from BiomeLab because
## t_biome loads this class under `--script`, before autoloads exist (BiomeLab names World).

const PATCH := 40.0
const GRID := 80

## Mostly flat ground at 1 m (the ground band), a gentle mound (peaks near 36 degrees, so it only
## reaches the dry band), a mesa with 2 m walls over 1 m (about 63 degrees, v_slope ~0.55: past every
## climate's slope_rock_hi, so the rock layer shows) and a shore on +x down to the shallows.
static func height(x: float, z: float) -> float:
	var h := 1.0
	h += 3.2 * exp(-(Vector2(x + 9.0, z + 3.0).length_squared()) / 14.0)
	h += 2.0 * clampf(4.0 - Vector2(x - 3.0, z - 2.0).length(), 0.0, 1.0)
	h -= clampf((x - 11.0) / 5.0, 0.0, 1.0) * 1.4
	return h

## Steepest face of the patch as the shader's v_slope (1 - normal.y); t_biome checks it.
static func max_slope() -> float:
	var arr := patch_mesh().surface_get_arrays(0)
	var top := 0.0
	for n: Vector3 in arr[Mesh.ARRAY_NORMAL]:
		top = maxf(top, 1.0 - clampf(n.y, 0.0, 1.0))
	return top

static func patch_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := PATCH / float(GRID)
	for zi in GRID:
		for xi in GRID:
			var x0 := -PATCH * 0.5 + xi * step
			var z0 := -PATCH * 0.5 + zi * step
			var quad := [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
			for k in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = quad[k]
				st.set_color(Color.WHITE)
				st.add_vertex(Vector3(p.x, height(p.x, p.y), p.y))
	st.generate_normals()
	return st.commit()

