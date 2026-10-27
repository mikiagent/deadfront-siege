class_name BiomeLab
extends Node3D
## BIOMEZONES lab. Two parts:
## 1. one 40x40 m ground patch per climate under the shared sun (used by t_biome for detail and
##    the rock band), saved as <out>/biome_<climate>.png;
## 2. real islands (home + three climates): a top-down zone shot, a camp-level ground shot and the
##    minimap/atlas texture, then one "[biome]" line per island with its zone shares.
## Windowed: --lab=biome_lab -- --shot-dir=DIR [--islands=home_grassland,savannah_15,...]
## Headless renders nothing: it builds the materials and prints the zone shares only.

const PATCH := BiomePatch.PATCH
const MIN_DIST := 0.08
## Pairs the spec allows to look alike.
const ALIKE := [["tropical", "blue_tropical"], ["tundra", "snowfield"]]
## One island per look the owner named: starter, golden savanna, red canyon, black basalt.
const ISLANDS := ["home_grassland", "savannah_15", "desert_35", "volcanic_60"]

var _mesh: MeshInstance3D
var _cam: Camera3D
var _player: Player
var _kit: Dictionary = {}
var _out := ""
var _ids: Array[String] = []

func _ready() -> void:
	_hide_overlays()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		if a.begins_with("--biome-out="):
			_out = a.substr(12)
		if a.begins_with("--islands="):
			_ids.clear()
			for id in a.substr(10).split(",", false):
				_ids.append(str(id))
	if _out == "":
		_out = OS.get_user_data_dir().path_join("biome_lab")
	if _ids.is_empty():
		for id in ISLANDS:
			_ids.append(str(id))
	DirAccess.make_dir_recursive_absolute(_out)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 20.0  # 35.5 x 20 m view at 16:9: only ground in frame
	_cam.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	_cam.position = Vector3(0.0, 1.0, 0.0) + _cam.basis.z * 40.0
	_cam.far = 200.0
	add_child(_cam)
	_cam.current = true
	# A windowed lab that never reaches quit() holds a Godot slot; give it a ceiling.
	get_tree().create_timer(600.0).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()

func _hide_overlays() -> void:
	var host := get_parent()
	if host and host.get_node_or_null("UI") is CanvasLayer:
		(host.get_node("UI") as CanvasLayer).visible = false
	var perf := get_node_or_null("/root/Game/PerfHud") as CanvasLayer  # no Game identifier: t_biome loads this class before autoloads
	if perf:
		perf.visible = false

func _run() -> void:
	await _climate_patches()
	await _island_shots()
	print("[biome_lab] done")
	get_tree().quit(0)

## Every climate's baked set on one flat patch, top of frame: the fastest read of the palettes.
func _climate_patches() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BiomePatch.patch_mesh()
	add_child(_mesh)
	var tile_map := _tile_map()
	var means := {}
	var headless := DisplayServer.get_name() == "headless"
	for climate in BiomeMaterial.climates():
		_mesh.material_override = BiomeMaterial.terrain(climate, PATCH, tile_map)
		if headless:
			continue
		for i in 4:  # let textures stream and the shadow map settle
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/biome_%s.png" % [_out, climate])
		means[climate] = _mean(img)
		var m: Color = means[climate]
		print("[biome_lab] %s mean=(%.3f, %.3f, %.3f)" % [climate, m.r, m.g, m.b])
	if headless:
		print("[biome_lab] headless: built %d materials, no pixels" % BiomeMaterial.climates().size())
	else:
		var fails := 0
		var keys: Array = means.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				var a: Color = means[keys[i]]
				var b: Color = means[keys[j]]
				var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
				var exempt := _alike(keys[i], keys[j])
				if d < MIN_DIST and not exempt:
					fails += 1
					print("[biome_lab] FAIL %s/%s dist=%.3f" % [keys[i], keys[j], d])
				elif d < 0.15:
					print("[biome_lab] close %s/%s dist=%.3f%s" % [keys[i], keys[j], d, " (allowed)" if exempt else ""])
		print("[biome_lab] %s %d patches, %d pairs under %.2f" % ["PASS" if fails == 0 else "FAIL", keys.size(), fails, MIN_DIST])
	if _mesh:
		_mesh.queue_free()
		_mesh = null

func _island_shots() -> void:
	var headless := DisplayServer.get_name() == "headless"
	if not headless:
		_kit = LabKit.build(self, 4.0)
		_player = _kit["player"]
		World.player_name = "Milan"
	World.home_terrain = &"meadow"
	for id in _ids:
		var t0 := Time.get_ticks_usec()
		World.load_island(self, StringName(id), Vector3(0, 1, 0), false)
		var ms := int((Time.get_ticks_usec() - t0) / 1000)
		await get_tree().process_frame
		await get_tree().process_frame
		var rt: IslandRuntime = World.runtime
		if rt == null:
			print("[biome] id=%s FAIL no runtime" % id)
			continue
		# Top shots are about colour, not haze: the island's day fog would wash the palette.
		if rt.world_env and rt.world_env.environment:
			rt.world_env.environment.fog_enabled = false
		var shares: Dictionary = BiomeZones.shares(rt)
		var parts := PackedStringArray()
		var land := maxi(1, _land_tiles(rt))
		for zone in shares:
			parts.append("%s:%d%%" % [zone, int(round(float(shares[zone]) * 100.0 / float(land)))])
		print("[biome] id=%s zones=%d share=%s build_ms=%d" % [id, shares.size(), ",".join(parts), ms])
		if headless:
			continue
		var kn: Node = _kit.get("nav")
		if kn and is_instance_valid(kn):
			(kn as Node).queue_free()
			_kit["nav"] = null
		# The minimap/atlas texture, as the HUD builds it.
		var mp: Image = BiomeZones.map_image(rt)
		mp.save_png("%s/%s_map.png" % [_out, id])
		# Top-down: the zone patchwork over the whole island.
		var top := Camera3D.new()
		top.projection = Camera3D.PROJECTION_ORTHOGONAL
		var size: float = rt._size
		top.size = size * 1.02
		top.far = 900.0
		top.position = Vector3(0.0, 400.0, 0.0)
		top.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(top)
		top.make_current()
		await _shot("%s/%s_top.png" % [_out, id])
		# Camp level: what the survivor sees.
		var camp: Vector3 = rt._camp_pos
		var cy: float = rt.surface_y(camp.x, camp.z)
		_player.global_position = Vector3(camp.x, cy + 1.0, camp.z + 6.0)
		var iso: IsoCamera = _kit.get("cam")
		if iso:
			iso.make_current()
			iso._snap()
		await _shot("%s/%s_camp.png" % [_out, id])
		top.queue_free()
		# Mid-zoom across a zone edge: the boundary the shader paints, close enough to judge.
		await _edge_shot(rt, id)

## Halfway between camp level and the top shot, across the second-largest zone's border: the
## soft painted edge (palette blend plus texture mix), not the island from orbit.
func _edge_shot(rt: IslandRuntime, id: String) -> void:
	var pos: Variant = _edge_pos(rt)
	if pos == null:
		return
	var iso: IsoCamera = _kit.get("cam")
	if iso == null:
		return
	# A low three-quarter camera 45 m out looks along the boundary, so both zones fill the frame.
	var at: Vector3 = pos
	_player.global_position = at
	iso.size = clampf(22.0, iso.min_size, iso.max_size)  # mid zoom: ~1.5 screens of ground
	iso.make_current()
	iso._snap()
	await _shot("%s/%s_edge.png" % [_out, id])

## A tile on the border between the island's two biggest zones, drawn toward the island centre so
## the edge sits in open ground rather than in a corner of the map.
func _edge_pos(rt: IslandRuntime) -> Variant:
	var arr := BiomeZones.biome_types(rt)
	if arr.is_empty():
		return null
	var span := rt._tile_span
	var counts := {}
	for z in span:
		for x in span:
			var b := int(arr[x + z * span])
			counts[b] = int(counts.get(b, 0)) + 1
	var ranked: Array = counts.keys()
	ranked.sort_custom(func (a: int, b: int) -> bool: return int(counts[a]) > int(counts[b]))
	if ranked.size() < 2:
		return null
	var za := int(ranked[0])
	var zb := int(ranked[1])
	var best := -1.0
	var pick := Vector3.ZERO
	for z in range(4, span - 4):
		for x in range(4, span - 4):
			var b := int(arr[x + z * span])
			if b != za:
				continue
			var nb := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if int(arr[(x + d.x) + (z + d.y) * span]) == zb:
					nb = true
					break
			if not nb:
				continue
			var wx := -rt._size * 0.5 + float(x) + 0.5
			var wz := -rt._size * 0.5 + float(z) + 0.5
			var score := -Vector2(wx, wz).length()
			if score > best:
				best = score
				pick = Vector3(wx, 0.0, wz)
	if best == -1.0:
		return null
	pick.y = rt.surface_y(pick.x, pick.z)
	return pick

func _land_tiles(rt: IslandRuntime) -> int:
	var n := 0
	var arr := BiomeZones.biome_types(rt)
	for idx in arr.size():
		var t := int(rt.tile_types[idx]) if idx < rt.tile_types.size() else 0
		if t != IslandTerrain.TileType.SHALLOW and t != IslandTerrain.TileType.DEEP \
				and t != IslandTerrain.TileType.SAND and t != IslandTerrain.TileType.WET:
			n += 1
	return n

func _shot(path: String) -> void:
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[biome_lab] shot %s %dx%d" % [path, img.get_width(), img.get_height()])

func _alike(a: String, b: String) -> bool:
	for pair in ALIKE:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false

func _mean(img: Image) -> Color:
	var small := img.duplicate() as Image
	small.resize(64, 36, Image.INTERPOLATE_BILINEAR)
	var sum := Vector3.ZERO
	for y in small.get_height():
		for x in small.get_width():
			var c := small.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
	sum /= float(small.get_width() * small.get_height())
	return Color(sum.x, sum.y, sum.z)

## Tile ids as island_runtime stamps them: a dirt square (2) and a mud strip (6), so the
## override layers show too. RG8: the G channel carries a zone id, as on an island.
func _tile_map() -> ImageTexture:
	var n := int(PATCH)
	var img := Image.create(n, n, false, Image.FORMAT_RG8)
	img.fill(Color(0.0, 0.0, 0.0))
	for z in range(24, 30):
		for x in range(6, 12):
			img.set_pixel(x, z, Color(2.0 / 255.0, 1.0 / 255.0, 0.0))
	for z in range(10, 13):
		for x in range(14, 26):
			img.set_pixel(x, z, Color(6.0 / 255.0, 5.0 / 255.0, 0.0))
	# Zone 0 (meadow) is the neutral tint, so a patch's mean still measures the climate's own
	# baked set, as t_biome checks. The painted zones are shown on real islands instead.
	return ImageTexture.create_from_image(img)
