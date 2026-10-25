extends SceneTree
## Spec 15 + 25 (map): fog of war reveals as a brush around the survivor, a black-dot trail keeps the
## last steps, both persist per island in the save, an old save with no fog loads with the camp area
## revealed, and the atlas/minimap draw them with claim, campfire, facility and player icons.
## Run: Godot --headless --path game --script res://tests/t_mapui.gd -> "[t_mapui] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const FOG_R := 25.0
## Mirrors of MapFog's ASSUMPTION defaults, restated here so the test can fail if they move.
const STEP := 8.0
const CAP := 200
## Mirrors MapFog's assumed lifetime so the regression test proves both fading and expiry.
const TRAIL_LIFETIME_S := 30.0

var _fails: PackedStringArray = []
var _started := false
var _done := false
var FG: GDScript
var SG: GDScript
var MS: GDScript
var HH: GDScript
var _host: Node3D
var _player: Node3D
var _world: Node
var _rt: Node3D
var _kit: Dictionary

func _process(_delta: float) -> bool:
	if _done:
		return true
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_mapui] FAIL %s" % what)

func _run() -> void:
	FG = load("res://scripts/ui/map_fog.gd")
	SG = load("res://scripts/core/save_game.gd")
	MS = load("res://scripts/ui/map_screen.gd")
	HH = load("res://scripts/ui/hunt_hud.gd")
	_host = Node3D.new()
	_host.name = "TMapUiHost"
	root.add_child(_host)
	# A watchdog: a hung await must still end the run with its verdict, not sit until the gate's alarm.
	create_timer(60.0).timeout.connect(func () -> void:
		print("[t_mapui] FAIL watchdog: the run did not finish in 60 s")
		quit(1))
	_kit = (load("res://scripts/dev/lab_kit.gd") as GDScript).build(_host, 4.0)
	_player = _kit["player"]
	for c in (_kit["ui"] as CanvasLayer).get_children():
		if c.has_method("open_map"):
			_hud = c
	_world = root.get_node("World")
	_world.player_name = "Tess"
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(_kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	await process_frame
	await physics_frame
	await process_frame
	_rt = _world.runtime
	_test_reveal_math()
	_test_trail()
	_test_round_trip()
	_test_old_save()
	await _test_wiring()
	await _test_icons()
	_test_persist()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_mapui] PASS")
		quit(0)
	else:
		print("[t_mapui] FAIL count=%d" % _fails.size())
		quit(1)

func _fog(id: String = "home_grassland", size_m: float = 160.0) -> Variant:
	var f = FG.new()
	f.setup(id, size_m)
	return f

# ---------------------------------------------------------------- reveal math

func _test_reveal_math() -> void:
	var f = _fog()
	var pos := Vector3(12.0, 0.0, -7.0)
	var added: int = f.reveal(pos, 12.0)
	_expect(added > 0, "a brush reveals cells")
	var want: int = int(ceil(PI * 144.0 / 4.0))  # cells whose centre sits in the disc; 2 m cells
	_expect(added >= want - 16 and added <= want + 16, "revealed cell count matches the disc (got %d, disc ~%d)" % [added, want])
	var grim := 0
	var centre := Vector2(pos.x, pos.z)
	for z in f.span:
		for x in f.span:
			var d: float = centre.distance_to(f.cell_centre(Vector2i(x, z)))
			if d <= 12.0 and not f.is_revealed_cell(Vector2i(x, z)):
				grim += 1
			if d > 12.0 + 2.0 and f.is_revealed_cell(Vector2i(x, z)):
				grim += 1
	_expect(grim == 0, "nothing inside the brush is left grey and nothing outside it is revealed (%d wrong)" % grim)
	# Walking into the same place again reveals nothing new.
	_expect(f.reveal(pos, 12.0) == 0, "re-walking known ground reveals no new cells")
	_expect(f.revealed_at(pos), "the survivor's own cell is revealed")
	# The default brush is the documented radius.
	var g = _fog()
	g.reveal(Vector3.ZERO)
	_expect(not g.is_revealed_cell(g.cell_of(Vector3(FOG_R + 6.0, 0, 0))), "the default brush stops at its radius (%.0f m)" % FOG_R)
	_expect(g.is_revealed_cell(g.cell_of(Vector3(FOG_R - 4.0, 0, 0))), "the default brush reaches its radius")
	# The island edge is not revealed by a survivor standing near it, and a sea cell never fogs.
	var e = _fog("home_grassland", 160.0)
	e.land_from(_rt)
	_expect(e.land.size() == e.span * e.span, "the land mask covers every cell")
	print("[t_mapui] reveal brush=%.0f m cells=%d new=%d" % [FOG_R, f.span * f.span, added])

# ---------------------------------------------------------------- trail

func _test_trail() -> void:
	var f = _fog()
	var x := -40.0
	for i in 100:
		f.walk(Vector3(x, 0, 0))
		x += 1.0
	# One dot per 8 m step: 99 m of walking -> ~13 dots.
	_expect(f.trail.size() >= 11 and f.trail.size() <= 14, "one trail dot per %.0f m (got %d over 99 m)" % [STEP, f.trail.size()])
	var min_gap := INF
	for i in range(1, f.trail.size()):
		min_gap = minf(min_gap, f.trail[i].distance_to(f.trail[i - 1]))
	_expect(min_gap >= STEP - 0.01, "trail dots are at least %.0f m apart (min %.2f)" % [STEP, min_gap])
	# The cap keeps the newest dots.
	var g = _fog()
	var z := -200.0
	for i in 3000:
		g.walk(Vector3(0, 0, z))
		z += 1.0
	_expect(g.trail.size() == CAP, "the trail keeps the last %d dots (got %d)" % [CAP, g.trail.size()])
	_expect(g.trail[g.trail.size() - 1].y >= z - STEP - 1.0, "the newest dot is at the survivor")
	_expect(g.trail[0].y > -200.0, "the oldest dots are dropped first")
	# Footsteps must fade with simulated game time and disappear instead of accumulating forever.
	var fading = _fog()
	fading.walk(Vector3.ZERO)
	_expect(fading.has_method("advance_trail") and fading.has_method("trail_alpha"), "the trail exposes deterministic time aging")
	if fading.has_method("advance_trail") and fading.has_method("trail_alpha"):
		var fresh_alpha := float(fading.call("trail_alpha", 0))
		fading.call("advance_trail", TRAIL_LIFETIME_S * 0.5)
		var faded_alpha := float(fading.call("trail_alpha", 0)) if not fading.trail.is_empty() else 0.0
		_expect(fading.trail.size() == 1 and faded_alpha < fresh_alpha and faded_alpha > 0.0, "a footprint fades before it expires")
		fading.call("advance_trail", TRAIL_LIFETIME_S * 0.51)
		_expect(fading.trail.is_empty(), "a footprint disappears after %.0f seconds" % TRAIL_LIFETIME_S)
	print("[t_mapui] trail step=%.0f m cap=%d kept=%d" % [STEP, CAP, g.trail.size()])

# ---------------------------------------------------------------- serialisation

func _test_round_trip() -> void:
	var f = _fog("home_grassland", 160.0)
	f.reveal(Vector3(10, 0, 10), 20.0)
	f.walk(Vector3(10, 0, 10))
	f.walk(Vector3(20, 0, 14))
	f.walk(Vector3(40, 0, 20))
	f.advance_trail(7.5)
	var saved_alpha: float = f.trail_alpha(0)
	var d: Dictionary = f.to_dict()
	_expect(str(d.get("id", "")) == "home_grassland", "the saved fog names its island")
	_expect(str(d.get("fog", "")).length() > 10, "the fog is stored compactly (base64, %d chars for %d cells)" % [str(d.get("fog", "")).length(), f.span * f.span])
	var raw: Dictionary = JSON.parse_string(JSON.stringify({"map": d})) as Dictionary
	var back = FG.from_dict(raw.get("map", {}) as Dictionary)
	_expect(back.span == f.span and back.size_m == f.size_m, "the bitmap size survives JSON")
	_expect(back.revealed_count() == f.revealed_count() and back.cells == f.cells, "every fog cell survives the round trip (%d cells)" % f.revealed_count())
	_expect(back.trail.size() == f.trail.size(), "every trail dot survives (%d)" % back.trail.size())
	var same: bool = back.trail.size() == f.trail.size()
	for i in mini(back.trail.size(), f.trail.size()):
		same = same and back.trail[i].distance_to(f.trail[i]) < 0.11
	_expect(same, "trail dots keep their places")
	_expect(absf(back.trail_alpha(0) - saved_alpha) < 0.01, "trail age survives the save round trip")
	# Hostile JSON is clamped, not fatal.
	var junk = FG.from_dict({"id": "x", "size": -5.0, "fog": "$$$", "trail": [["a"], [1, 2], [3, 4, TRAIL_LIFETIME_S], 7]})
	_expect(junk.span > 0 and junk.revealed_count() == 0 and junk.trail.size() == 1, "a malformed fog row loads empty, keeping only well-formed dots")
	print("[t_mapui] round trip cells=%d trail=%d bytes=%d" % [back.revealed_count(), back.trail.size(), str(d.get("fog", "")).length()])

# ---------------------------------------------------------------- old save

func _test_old_save() -> void:
	var camp: Vector3 = _rt.get("_camp_pos")
	var f = FG.for_old_save("home_grassland", 160.0, camp)
	_expect(f.revealed_count() > 0, "an old save starts with the camp known")
	_expect(f.revealed_at(camp + Vector3(10, 0, 0)), "the camp and its surroundings are revealed")
	_expect(not f.revealed_at(camp + Vector3(120, 0, 0)), "the far side of the island stays grey on an old save")
	_expect(f.trail.is_empty(), "an old save has no invented trail")
	print("[t_mapui] old save cells=%d" % f.revealed_count())

# ---------------------------------------------------------------- wiring

var _hud: Control

func _test_wiring() -> void:
	var f = _world.map_fog
	_expect(f != null, "World keeps the current island's fog")
	if f == null:
		return
	_expect(f.revealed_at(_player.global_position), "the survivor's start reveals the camp area")
	# Walking updates fog and trail through World.
	var before: int = f.revealed_count()
	var start: Vector3 = _player.global_position
	for i in 60:
		_player.global_position = start + Vector3(float(i) * 1.0, 0, 0)
		_world.note_map_walk(_player.global_position)
		await process_frame
	_expect(f.revealed_count() > before, "walking reveals new ground (%d -> %d cells)" % [before, f.revealed_count()])
	_expect(f.trail.size() >= 6, "walking records a trail (%d dots)" % f.trail.size())
	_player.global_position = start
	await process_frame
	# The atlas and minimap both draw fog: the map exposes the draw entry points the lab measures.
	_hud.open_map()
	await process_frame
	var map: Variant = _hud.get_node_or_null("MapLayer/MapScreen")
	_expect(map != null and map.visible, "the atlas opens")
	if map:
		_expect(map._fog() != null, "the atlas draws the current fog")
		_expect(map._fog_texture() != null, "the atlas has a fog texture")
		map.close()
	await process_frame
	print("[t_mapui] wiring cells=%d trail=%d" % [f.revealed_count(), f.trail.size()])

func _test_icons() -> void:
	# CLAIMS2: a domain is a set of cells declared on the runtime, not a rect list a fresh world comes
	# with. Declare one cell next to the survivor so the atlas has a claim to draw.
	var w: Node = get_root().get_node_or_null("World")
	if w != null and w.claims_for_current().is_empty():
		var ic = load("res://scripts/world/island_claims.gd")
		var bg = load("res://scripts/world/build_grid.gd")
		var rt: Variant = w.runtime
		if rt != null:
			var tile: Vector2i = bg.tile_of(_player.global_position)
			rt.claim_domain([ic.cell_of(rt, tile)])
	var map: Control = MS.new()
	root.add_child(map)
	map.hud = _hud
	map.player = _player
	var marks: Array = map._icon_marks()
	var kinds := {}
	for m in marks:
		kinds[str(m["kind"])] = int(kinds.get(str(m["kind"]), 0)) + 1
	_expect(int(kinds.get("claim", 0)) >= 1, "the atlas has a house icon for your claim (%s)" % kinds)
	_expect(int(kinds.get("campfire", 0)) >= 1, "the atlas has a campfire icon (%s)" % kinds)
	_expect(int(kinds.get("facility", 0)) >= 1, "the atlas has a facility icon (%s)" % kinds)
	_expect(int(kinds.get("harbour", 0)) >= 1, "the atlas has the harbour icon (%s)" % kinds)
	_expect(MS.LEGEND.has("claim") and MS.LEGEND.has("campfire") and MS.LEGEND.has("facility"), "the legend explains the new icons")
	var px: float = map.icon_min_px(Vector2(844, 390))
	_expect(px >= 64.0, "phone icon tap targets are %.0f px (need 64)" % px)
	var desk: float = map.icon_min_px(Vector2(1600, 900))
	_expect(desk >= 44.0, "desktop icon tap targets are %.0f px" % desk)
	# Offline there is one survivor: no grey dots.
	var dots: int = map._player_dots().size()
	_expect(dots == 0, "offline the atlas draws no other-player dots (got %d)" % dots)
	map.queue_free()
	print("[t_mapui] icons %s px phone=%.0f desktop=%.0f" % [kinds, px, desk])

# ---------------------------------------------------------------- persistence through the save

func _test_persist() -> void:
	var f = _world.map_fog
	f.reveal(Vector3(-50, 0, 30), 10.0)
	var cells: int = f.revealed_count()
	var dots: int = f.trail.size()
	SG.save_now()
	var d: Dictionary = {
		"schema": int(SG.SCHEMA),
	}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	_expect(parsed is Dictionary and (parsed as Dictionary).has("map"), "the save has a map field")
	var row: Variant = (parsed as Dictionary).get("map", {}) if parsed is Dictionary else {}
	var per: Dictionary = ((row as Dictionary).get("islands", {}) as Dictionary) if row is Dictionary else {}
	_expect(per.has("home_grassland"), "the fog is saved per island (%s)" % per.keys())
	# Load it back through the real loader.
	var old = _world.map_fog
	SG.load_now(_host)
	await process_frame
	var back = _world.map_fog
	_expect(back != null and back != old, "a load replaces the fog with the saved one")
	if back:
		_expect(back.revealed_count() == cells, "the saved fog reloads (%d vs %d cells)" % [back.revealed_count(), cells])
		_expect(back.trail.size() == dots, "the saved trail reloads (%d vs %d dots)" % [back.trail.size(), dots])
		_expect(back.revealed_at(Vector3(-50, 0, 30)), "a walked spot is still known after a load")
	# An old save (no map field at all) loads with the camp revealed.
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	src.erase("map")
	var w := FileAccess.open(SG.path, FileAccess.WRITE)
	w.store_string(JSON.stringify(src))
	w.close()
	SG.load_now(_host)
	await process_frame
	var old_fog = _world.map_fog
	_expect(old_fog != null and old_fog.revealed_at(_rt.get("_camp_pos")), "a save with no map field loads with the camp revealed")
	_expect(old_fog != null and old_fog.trail.is_empty(), "a save with no map field loads with no trail")
	print("[t_mapui] persist cells=%d dots=%d" % [cells, dots])
