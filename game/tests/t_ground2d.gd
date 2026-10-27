extends SceneTree
## GROUND2D checks (islands plan P2 row 2, spec 28 "Tall grasses on terrain"):
## 1. data/world/ground_cover.json names kinds that resolve to sprites in the manifest (never a
##    hard-coded id list), every density/scale/sway is a sane number, and the per-climate sets are the
##    plan's: grassland/temperate grow grass, weeds, ferns, flowers; savannah grows dry golden tufts;
##    swamp grows reeds and lush grass; tropical grows ferns and lush grass; desert, tundra and
##    volcanic grow none at all.
## 2. GroundCover.plan() is deterministic for a seed (same island, same list; another seed differs),
##    stays inside the island's radius (the 32 m cells hold every instance it makes), never places
##    cover on water/sand/ash, and clumps instead of stamping a grid.
## 3. A built island gets a GroundCover with instances, one MultiMesh per 32 m cell, no collider
##    anywhere under it, no shadow casting, and visible-instance thinning at distance that never
##    switches a near cell off.
## Run: Godot --headless --path game --script res://tests/t_ground2d.gd -> "[t_ground2d] PASS", exit 0/1.
## Scripts are load()ed on the first frame (`--script` compiles before the autoloads exist).

const DATA_PATH := "res://data/world/ground_cover.json"
const CELL_M := 32.0

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var GC: GDScript
var IT: GDScript
var IC: GDScript
var BG: GDScript
var _rt: Node3D

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	# A stuck await must not hang the gate: quit with a FAIL after 120 s.
	_watchdog()
	return false

func _watchdog() -> void:
	var t := 0.0
	while t < 120.0:
		await create_timer(1.0).timeout
		t += 1.0
		if not _started:
			continue
		if _done:
			return
	print("[t_ground2d] FAIL watchdog (120 s)")
	quit(1)

var _done := false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_ground2d] FAIL %s" % what)

func _run() -> void:
	GC = load("res://scripts/world/ground_cover.gd")
	IT = load("res://scripts/world/island_terrain.gd")
	IC = load("res://scripts/world/island_claims.gd")
	BG = load("res://scripts/world/build_grid.gd")
	_data_checks()
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TGround2d"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 20.0)
	(kit["nav"] as Node).queue_free()
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	await physics_frame
	_rt = _world.runtime
	await _placement_checks()
	await _node_checks()
	_done = true
	if _fails.is_empty():
		print("[t_ground2d] PASS")
		quit(0)
	else:
		print("[t_ground2d] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- data

func _data_checks() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	_expect(f != null, "ground_cover.json is readable")
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_expect(parsed is Dictionary, "ground_cover.json is an object")
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	var kinds: Dictionary = d.get("kinds", {})
	_expect(kinds.size() >= 5, "at least 5 kinds (%d)" % kinds.size())
	var resolved := 0
	for k: String in kinds.keys():
		var row: Dictionary = kinds[k]
		var sprites: Array = GC.sprites_of(k)
		_expect(sprites.size() > 0, "kind %s resolves to manifest sprites" % k)
		resolved += sprites.size()
		_expect(float(row.get("density", -1.0)) > 0.0, "kind %s has a positive density" % k)
		var sc: Array = row.get("scale", [])
		_expect(sc.size() >= 2 and float(sc[0]) > 0.0 and float(sc[1]) >= float(sc[0]), "kind %s has a scale range" % k)
		_expect(float(row.get("sway", -1.0)) >= 0.0, "kind %s has a sway figure" % k)
	_expect(resolved > 0, "every kind resolves through the manifest (%d sprites)" % resolved)
	# Never hard-code ids: the manifest is the source (a missing id would silently shrink a kind).
	var man: Dictionary = GC.manifest()
	_expect(int(man.get("sprites", []).size()) > 0, "the sprite manifest loads")
	var want := {
		"grassland": ["grass", "weed", "fern", "flower"],
		"temperate": ["grass", "weed", "fern", "flower"],
		"savannah": ["dry"],
		"swamp": ["reed", "grass"],
		"tropical": ["fern", "grass"],
	}
	for climate: String in want.keys():
		var got: Array[String] = GC.kinds_for(climate)
		for k in want[climate]:
			_expect(got.has(k), "%s grows %s (%s)" % [climate, k, got])
		_expect(GC.climate_density(climate) >= 0.3, "%s density is at least 0.3 per m2 (%.2f)" % [climate, GC.climate_density(climate)])
	for climate in ["desert", "tundra", "volcanic"]:
		_expect(GC.kinds_for(climate).is_empty(), "%s grows no ground cover" % climate)
		_expect(GC.climate_density(climate) == 0.0, "%s density is 0" % climate)
	# An unlisted climate grows nothing (never a silent fallback to grass).
	_expect(GC.kinds_for("lava_sea").is_empty(), "an unknown climate grows no cover")

# ---------------------------------------------------------------- placement

func _placement_checks() -> void:
	var radius: float = _rt.land_radius()
	var a: Array[Dictionary] = GC.plan(_rt, "grassland", 1234)
	var b: Array[Dictionary] = GC.plan(_rt, "grassland", 1234)
	var c: Array[Dictionary] = GC.plan(_rt, "grassland", 999)
	_expect(a.size() > 0, "a grassland plan places instances (%d)" % a.size())
	_expect(a.size() == b.size(), "the same seed gives the same count (%d vs %d)" % [a.size(), b.size()])
	var diff := 0
	for i in mini(a.size(), b.size()):
		if (a[i]["pos"] as Vector3).distance_to(b[i]["pos"] as Vector3) > 0.0001 or str(a[i]["kind"]) != str(b[i]["kind"]):
			diff += 1
	_expect(diff == 0, "the same seed gives the same placement (not identical entries: %d)" % diff)
	var moved := a.size() != c.size()
	for i in mini(a.size(), c.size()):
		if moved:
			break
		if (a[i]["pos"] as Vector3).distance_to(c[i]["pos"] as Vector3) > 0.0001:
			moved = true
	_expect(moved, "another seed moves the placement")
	# Every instance is inside the island's radius, on soil, and above the beach.
	var outside := 0
	var wet := 0
	var steep := 0
	for it in a:
		var p: Vector3 = it["pos"]
		if Vector2(p.x, p.z).length() > radius + 0.01:
			outside += 1
		if p.y < 0.4:
			wet += 1
		if IT.slope_deg(_rt, p.x, p.z) > GC.MAX_SLOPE_DEG + 0.5:
			steep += 1
	_expect(outside == 0, "every instance is inside the land radius (%d outside)" % outside)
	_expect(wet == 0, "no instance sits in water or on the beach (%d wet)" % wet)
	_expect(steep == 0, "no instance sits on a face steeper than %d deg (%d)" % [int(GC.MAX_SLOPE_DEG), steep])
	# Owner rule 2026-10-21: claimed land has no ground cover - the camp plot is claimed on the home
	# island, so nothing may stand on its tiles, and an instance list never does.
	var on_claim := 0
	for it in a:
		var p: Vector3 = it["pos"]
		if IC.is_claimed(_rt, BG.tile_of(p)):
			on_claim += 1
	_expect(on_claim == 0, "no instance stands on a claimed tile (%d on the camp plot)" % on_claim)
	_expect(_rt.claims.size() > 0, "the home island has its camp claim to test against")
	# Clearings: every instance stands where the patch mask grows cover, and the mask leaves bare
	# patches (that is what stops the cover reading as a carpet).
	var off_mask := 0
	for it in a:
		var p: Vector3 = it["pos"]
		if not GC.masked(1234, p.x, p.z):
			off_mask += 1
	_expect(off_mask == 0, "every instance stands inside the patch mask (%d outside)" % off_mask)
	var bare := 0
	var grown := 0
	for i in 60:
		for j in 60:
			var x := (float(i) / 59.0 - 0.5) * 2.0 * radius
			var z := (float(j) / 59.0 - 0.5) * 2.0 * radius
			if Vector2(x, z).length() > radius:
				continue
			if GC.masked(1234, x, z):
				grown += 1
			else:
				bare += 1
	var bare_share := float(bare) / float(maxi(1, bare + grown))
	_expect(bare_share > 0.15 and bare_share < 0.6, "the mask leaves clearings (%.0f %% bare)" % (bare_share * 100.0))
	# Cover is a painted card at a pivot over the ground, never a degenerate stamp.
	var bad := 0
	for it in a:
		if float(it["h"]) <= 0.05 or float(it["w"]) <= 0.01:
			bad += 1
		var pv: Vector2 = it["pivot"]
		if pv.x < 0.0 or pv.x > 1.0 or pv.y < 0.0 or pv.y > 1.0:
			bad += 1
	_expect(bad == 0, "every instance has a size and a pivot inside its card (%d bad)" % bad)
	# Clumped, not stamped: the mean nearest-neighbour distance is well below the grid a uniform
	# carpet at this density would make (kinds come in patches of 3-8).
	var want: float = GC.climate_density("grassland") * PI * radius * radius
	var nn := _mean_nearest(a)
	_expect(nn > 0.0 and nn < 2.0, "clumps are packed (mean nearest neighbour %.2f m)" % nn)
	_expect(float(a.size()) > want * 0.5, "the plan reaches most of the wanted density (%d of ~%d)" % [a.size(), int(want)])
	# NONE on the bare climates: their plan is empty even on a real island.
	for climate in ["desert", "tundra", "volcanic"]:
		_expect(GC.plan(_rt, climate, 1234).is_empty(), "%s plans no cover on the island" % climate)
	# Cells: the 32 m bucket of every instance is a key the built cover would use.
	var keys: Dictionary = {}
	for it in a:
		var p: Vector3 = it["pos"]
		keys[Vector2i(floori(p.x / CELL_M), floori(p.z / CELL_M))] = true
	print("[t_ground2d] plan=%d cells=%d nn=%.2f" % [a.size(), keys.size(), nn])

func _mean_nearest(items: Array[Dictionary]) -> float:
	if items.size() < 2:
		return -1.0
	# A coarse grid keeps this O(n) on ~6k instances.
	var grid: Dictionary = {}
	for i in items.size():
		var p: Vector3 = items[i]["pos"]
		var k := Vector2i(floori(p.x / 4.0), floori(p.z / 4.0))
		if not grid.has(k):
			grid[k] = [] as Array[int]
		var list: Array[int] = grid[k]
		list.append(i)
	var sum := 0.0
	var n := 0
	for i in mini(items.size(), 900):
		var p: Vector3 = items[i]["pos"]
		var k := Vector2i(floori(p.x / 4.0), floori(p.z / 4.0))
		var best := 1e9
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var list: Variant = grid.get(Vector2i(k.x + dx, k.y + dz), null)
				if not list is Array:
					continue
				for j in (list as Array):
					if int(j) == i:
						continue
					var q: Vector3 = items[int(j)]["pos"]
					best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
		if best < 1e8:
			sum += best
			n += 1
	return sum / float(maxi(1, n))

# ---------------------------------------------------------------- the built node

func _node_checks() -> void:
	var gc := _rt.get_node_or_null("GroundCover") as Node3D
	_expect(gc != null, "the built island has a GroundCover node")
	if gc == null:
		return
	_expect(gc.instance_count() > 0, "the cover has instances (%d)" % gc.instance_count())
	_expect(gc.claimed_instances() == 0, "claimed tiles are bare (%d on claim)" % gc.claimed_instances())
	_expect(gc.collision_bodies() == 0, "the cover has no collider under it (%d)" % gc.collision_bodies())
	_expect(gc.grey_cards() == 0, "no card draws without its texture")
	_expect(gc.missing_sprites() == 0, "every sprite the atlas drew came from a real PNG")
	var minima: Array = gc.kinds_placed()
	for k in ["grass", "weed", "fern", "flower"]:
		_expect(minima.has(k), "the home island draws %s" % k)
	var cells: Array = gc.cell_nodes()
	_expect(cells.size() > 0, "cover draws cells (%d)" % cells.size())
	# Every instance sits inside its cell's 32 m square (the cell is what draws it).
	var bad := 0
	var inst_total := 0
	for cell in cells:
		var centre: Vector3 = (cell as Node3D).position
		var mm: MultiMesh = (cell as MultiMeshInstance3D).multimesh
		inst_total += mm.instance_count
		if (cell as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			bad += 1
		for i in mm.instance_count:
			var xf := mm.get_instance_transform(i)
			var x: float = xf.origin.x + centre.x
			var z: float = xf.origin.z + centre.z
			if absf(x - centre.x) > CELL_M * 0.5 + 8.0 or absf(z - centre.z) > CELL_M * 0.5 + 8.0:
				bad += 1
	_expect(inst_total >= gc.instance_count(), "the cells hold every instance (%d in cells, %d placed)" % [inst_total, gc.instance_count()])
	_expect(bad == 0, "every instance stays in its cell and no cell casts a shadow (%d bad)" % bad)
	# Placement matches the planner: same seed, same count.
	var planned: Array[Dictionary] = GC.plan(_rt, "grassland", 17)
	_expect(planned.size() == gc.instance_count(), "the island built the planner's list (%d of %d)" % [gc.instance_count(), planned.size()])
	# Distance thinning: near the survivor the cells are whole, far away they are a share.
	var camp: Vector3 = _rt._camp_pos
	var near_n: int = gc.count_within(camp, 25.0)
	_expect(near_n > 0, "cover stands at camp (%d within 25 m)" % near_n)
	# The home island's land radius is 61 m, so the far probe sits near its far shore; the lab
	# measures the plan's 150 m point on an unstable island (land radius 182 m).
	var land: float = _rt.land_radius()
	var far_point := Vector3(-land * 0.7, 2.0, land * 0.7)
	var far_n: int = gc.count_within(far_point, 25.0)
	_expect(far_n > 0, "cover stands at the far shore (%d within 25 m)" % far_n)
	# The camera looks at camp: the near cells show everything, and the far point is thinned, not off.
	var cam := kit_camera()
	if cam != null:
		cam.global_position = camp + Vector3(0, 10, 0)
		gc._apply_thinning()
		var near_off: int = 0
		var far_off: int = 0
		for cell in cells:
			var mm: MultiMesh = (cell as MultiMeshInstance3D).multimesh
			var d := Vector2((cell as Node3D).position.x - camp.x, (cell as Node3D).position.z - camp.z).length()
			var shown := mm.visible_instance_count
			if d < 20.0 and shown != mm.instance_count:
				near_off += 1
			if d > 140.0 and shown >= mm.instance_count and mm.instance_count > 4:
				far_off += 1
		_expect(near_off == 0, "near cells draw every instance (%d thinned)" % near_off)
		_expect(far_off == 0, "far cells are thinned, not switched off (%d unthinned)" % far_off)
		_expect(gc.visible_count() > 0, "thinning keeps the far field drawn (%d visible)" % gc.visible_count())
	# Per-instance tint and sway phase: every instance carries its own (the headless dummy
	# rasteriser does not store them, so the plan is what proves the variation and the MultiMeshes
	# are checked for having the colour/custom-data channels switched on).
	var tinted := 0
	var phased := 0
	for cell in cells:
		var mm2: MultiMesh = (cell as MultiMeshInstance3D).multimesh
		if mm2.use_colors:
			tinted += 1
		if mm2.use_custom_data:
			phased += 1
	_expect(tinted == cells.size() and phased == cells.size(), "every cell carries colour and custom data (%d / %d of %d)" % [tinted, phased, cells.size()])
	var plan_tints: Dictionary = {}
	var plan_spots: Dictionary = {}
	for it in planned:
		plan_tints[(it["tint"] as Color).to_html(false)] = true
		plan_spots[(it["pos"] as Vector3).snapped(Vector3.ONE * 0.01)] = true
	_expect(plan_tints.size() > 20, "instances carry their own tint (%d distinct)" % plan_tints.size())
	_expect(plan_spots.size() > planned.size() * 0.99, "instances stand on their own spots (%d distinct of %d)" % [plan_spots.size(), planned.size()])
	# A plot staked after the build clears its cover at once (CLAIMS2's claims_changed hook lands here).
	# A plot where cover actually stands, so clearing it is measurable.
	var probe: Vector3 = _rt._camp_pos
	for pos in gc.positions():
		if not IC.is_claimed(_rt, BG.tile_of(pos)) and Vector2(pos.x, pos.z).length() < _rt.land_radius() - 8.0:
			probe = pos
			break
	var tile: Vector2i = BG.tile_of(probe)
	var before_claim: int = gc.count_within(rt_surface(probe), 3.0)
	var added: bool = IC.claim_at(_rt, tile, 8)
	if added:
		gc._on_claims_changed(IC.plot_at(tile, 8))
		_expect(gc.claimed_instances() == 0, "a newly staked plot is bare at once (%d on claim)" % gc.claimed_instances())
		var after_claim: int = gc.count_within(rt_surface(probe), 3.0)
		_expect(before_claim > 0, "the probe plot had cover before it was staked (%d)" % before_claim)
		_expect(after_claim == 0, "the new plot's cover was removed (%d -> %d near it)" % [before_claim, after_claim])
	else:
		print("[t_ground2d] skip late-claim probe (plot at %s is refused)" % tile)
	print("[t_ground2d] nodes cells=%d instances=%d near=%d far=%d" % [cells.size(), gc.instance_count(), near_n, far_n])

func rt_surface(p: Vector3) -> Vector3:
	return Vector3(p.x, _rt.surface_y(p.x, p.z), p.z)

func kit_camera() -> Camera3D:
	for c in _host.get_children():
		if c.get_script() == load("res://scripts/camera/iso_camera.gd"):
			return c as Camera3D
	return null
