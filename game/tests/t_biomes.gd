extends SceneTree
## BIOMEZONES acceptance: every island has >= 3 zones, the starter has meadow, forest, riverbank
## (wetland), rocky and beach, every climate has a palette, and the tile image's G channel matches
## the zone array. Run: Godot --headless --path game --script res://tests/t_biomes.gd
## Scripts are load()ed on the first frame, like t_domain: `--script` compiles this file before
## the autoloads exist, so nothing here names Data, World or a class that depends on them.

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var BZ: GDScript
var BM: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if ok:
		print("[t_biomes] ok %s" % what)
	else:
		_fails.append(what)
		print("[t_biomes] FAIL %s" % what)

func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(2))
	BZ = load("res://scripts/world/biome_zones.gd")
	BM = load("res://scripts/world/biome_material.gd")
	_host = Node3D.new()
	_host.name = "TBiomesHost"
	root.add_child(_host)
	var zone_count: int = BZ.zone_count()
	var pal: Image = BZ.palette_image("volcanic")
	print("[t_biomes] volcanic basalt tint=%s mix=%s" % [pal.get_pixel(4, 0), pal.get_pixel(4, 1)])
	_expect(pal.get_pixel(4, 0) != Color.WHITE, "basalt has a dark tint")
	var data: Node = root.get_node("Data")
	var ids: Array[String] = []
	var islands: Dictionary = data.get("world_islands")
	for k in islands:
		if not str(k).begins_with("_") and islands[k] is Dictionary:
			ids.append(str(k))
	var climates: Dictionary = data.get("world_climates")
	for climate in climates:
		if str(climate).begins_with("_"):
			continue
		var crow: Dictionary = climates[climate]
		var cpal: Variant = crow.get("palette", {})
		_expect(cpal is Dictionary and (cpal as Dictionary).size() >= 5, "%s climates.json palette has 5 keys" % climate)
		if cpal is Dictionary and cpal.has("sand"):
			var sc := Color.from_string(str((cpal as Dictionary)["sand"]), Color.WHITE)
			# ASSUMPTION: 0.95 is the cap; the plan's brightest sand (blue_tropical #f0e6c8) is 0.94.
			_expect(sc.v <= 0.95, "%s sand %s is not blown white" % [climate, sc.to_html(false)])
		var row: Dictionary = BM.row(str(climate))
		_expect(not row.is_empty(), "%s has a biomes.json row" % climate)
		var tinted := 0
		var img: Image = BZ.palette_image(str(climate))
		for i in zone_count:
			if img.get_pixel(i, 0) != Color.WHITE:
				tinted += 1
		_expect(tinted >= zone_count - 1, "%s palette tints %d/%d zones" % [climate, tinted, zone_count])
	var w: Node = root.get_node("World")
	for id in ids:
		w.load_island(_host, StringName(id), Vector3(0, 1, 0), false)
		await process_frame
		var rt: Node3D = w.runtime
		var span: int = int(rt.get("_tile_span"))
		var arr: PackedByteArray = BZ.biome_types(rt)
		_expect(arr.size() == span * span, "%s zone array covers the tile map" % id)
		var shares: Dictionary = BZ.shares(rt)
		print("[t_biomes] %s zones=%d %s" % [id, shares.size(), shares])
		_expect(shares.size() >= 3, "%s has >= 3 zones (%d)" % [id, shares.size()])
		var img_rt: Image = rt.get("_tile_map_image")
		var mism := 0
		for z in range(0, span, 5):
			for x in range(0, span, 5):
				var c: Color = img_rt.get_pixel(x, z)
				if int(round(c.g * 255.0)) != int(arr[x + z * span]):
					mism += 1
		_expect(mism == 0, "%s tile image G matches zones (%d mismatches)" % [id, mism])
		if id == "home_grassland":
			for zone in ["meadow", "forest", "wetland", "rocky", "beach"]:
				_expect(int(shares.get(zone, 0)) > 0, "home has %s (%d tiles)" % [zone, int(shares.get(zone, 0))])
		var probe: int = BZ.biome_at(rt, 0.0, 0.0)
		_expect(probe >= 0 and probe < zone_count, "%s biome_at(0,0) = %s" % [id, BZ.zone_name(probe)])
	if _fails.is_empty():
		print("[t_biomes] PASS")
		quit(0)
	else:
		print("[t_biomes] FAIL %d checks" % _fails.size())
		quit(1)
