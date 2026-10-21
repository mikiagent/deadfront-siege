extends SceneTree
## Spec 18 acceptance (domain banner and claim edges). Walking into claimed land shows "<owner>'s
## Domain" with a portrait: once while staying inside, again after leaving and coming back, again
## when crossing into another owner's land; arriving on the island is not entering; a step over the
## edge and back, or walking along two owners' shared border, does not flash it; an island change
## takes it down; the HUD draws it clear of its blocks, on a landscape phone in its slot above the
## quest card. Claim data says who owns each tile; the dotted outline follows it (a new plot, other
## players' rows in their own colour, touching plots read as one, malformed and off-island rows
## dropped or cut, only the nearest few of a crowd, lit and opaque). Claims refuse another player's
## tiles and a refused claim keeps its stake; the own portrait goes when the look can have changed.
## Run: Godot --headless --path game --script res://tests/t_domain.gd -> "[t_domain] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const ME := "Tess"
const THEM := {"id": "p2", "name": "Rowan"}

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node3D
var _hud: Control
var _world: Node
var _rt: Node3D
var _own: Rect2i
var DB: GDScript
var CO: GDScript
var PP: GDScript
var BG: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_domain] FAIL %s" % what)

func _run() -> void:
	BG = load("res://scripts/world/build_grid.gd")
	_host = Node3D.new()
	_host.name = "TDomainHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("taken_rects"):
			_hud = c
	_world = root.get_node("World")
	_world.player_name = ME
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	await process_frame
	await physics_frame
	_rt = _world.runtime
	_own = _rt.claims[0]
	await _test_hud_banner_on_entry()
	DB = load("res://scripts/ui/domain_banner.gd") if ResourceLoader.exists("res://scripts/ui/domain_banner.gd") else null
	CO = load("res://scripts/world/claim_outline.gd") if ResourceLoader.exists("res://scripts/world/claim_outline.gd") else null
	PP = load("res://scripts/ui/player_portrait.gd") if ResourceLoader.exists("res://scripts/ui/player_portrait.gd") else null
	if DB == null or CO == null or PP == null or not _rt.has_method("owner_at"):
		_expect(false, "spec 18 is not built: domain_banner.gd %s, claim_outline.gd %s, player_portrait.gd %s, IslandRuntime.owner_at %s" % [DB != null, CO != null, PP != null, _rt.has_method("owner_at")])
		_finish()
		return
	_test_owner_at()
	_test_enter_stay_leave()
	_test_arrival_and_edge_step()
	_test_other_owner()
	_test_shared_border_and_island_change()
	_test_malformed_rows()
	_test_outline_follows_claims()
	await _test_crowd()
	_test_claim_refusals()
	_test_portrait()
	await _test_phone_slot()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_domain] PASS")
		quit(0)
	else:
		print("[t_domain] FAIL count=%d" % _fails.size())
		quit(1)

func _at(tile: Vector2i) -> Vector3:
	return BG.tile_centre(tile, _rt)

## Just outside the camp plot's +z edge, and the tile across it: one step apart.
func _outside() -> Vector2i:
	return Vector2i(_own.position.x + _own.size.x / 2, _own.end.y)

func _inside() -> Vector2i:
	return Vector2i(_own.position.x + _own.size.x / 2, _own.end.y - 1)

## Walks the survivor tile by tile (one per frame) from `a` to `b` along z.
func _walk(a: Vector2i, b: Vector2i) -> void:
	var step := 1 if b.y > a.y else -1
	for z in range(a.y, b.y + step, step):
		_player.global_position = _at(Vector2i(a.x, z)) + Vector3(0, 1, 0)
		await process_frame

# ---------------------------------------------------------------- the HUD (fails on the old code)

func _test_hud_banner_on_entry() -> void:
	_player.clear_nav()
	var start := _outside() + Vector2i(0, 5)
	_player.global_position = _at(start) + Vector3(0, 1, 0)
	for i in 6:
		await process_frame
	_expect(not _hud.drawn_blocks.has("domain"), "outside the claim the HUD draws no domain banner")
	await _walk(start, _inside() - Vector2i(0, 2))
	for i in 3:
		await process_frame
	var shown: bool = _hud.drawn_blocks.has("domain")
	print("[t_domain] hud entry banner=%s rect=%s" % [shown, _hud.drawn_blocks.get("domain", Rect2())])
	_expect(shown, "walking into your own claim: the HUD draws no \"%s's Domain\" banner" % ME)
	if not shown:
		return
	var domain: Variant = _hud.get("_domain")
	_expect(domain != null and str(domain.call("text")) == "%s's Domain" % ME, "HUD banner reads \"%s's Domain\" (got \"%s\")" % [ME, domain.call("text") if domain != null else ""])
	var box: Rect2 = _hud.drawn_blocks["domain"]
	var view := Rect2(Vector2.ZERO, _hud.get_viewport_rect().size)
	_expect(view.encloses(box), "banner %s inside the view %s" % [box, view])
	for k in ["vitals", "quest", "map_title", "map_text", "statuses", "level", "nameplate"]:
		if _hud.drawn_blocks.has(k):
			_expect(not box.intersects(_hud.drawn_blocks[k]), "banner %s clear of %s %s" % [box, k, _hud.drawn_blocks[k]])
	var map_rect := Rect2(_hud.get("_minimap").position, Vector2.ONE * float((_hud.get_script() as GDScript).get_script_constant_map()["MAP_PX"]))
	_expect(not box.intersects(map_rect), "banner %s clear of the minimap %s" % [box, map_rect])

# ---------------------------------------------------------------- claim data

func _test_owner_at() -> void:
	var mine: Dictionary = _rt.owner_at(_inside())
	_expect(mine.get("name", "") == ME and bool(mine.get("own", false)), "own claim tile is %s's (got %s)" % [ME, mine])
	_expect((_rt.owner_at(_outside()) as Dictionary).is_empty(), "unclaimed tile has no owner")

# ---------------------------------------------------------------- banner timing

func _test_enter_stay_leave() -> void:
	var b: RefCounted = DB.new()
	var out := _at(_outside())
	var inn := _at(_inside())
	b.tick(0.016, _rt, out)
	b.tick(0.5, _rt, out)
	_expect(not b.showing(), "outside: no banner")
	b.tick(0.016, _rt, inn)
	_expect(b.showing() and b.text() == "%s's Domain" % ME, "entering shows \"%s's Domain\" (got \"%s\")" % [ME, b.text()])
	var up := 0.0
	while b.showing() and up < 30.0:
		b.tick(0.1, _rt, inn)
		up += 0.1
	_expect(up >= 2.0 and up <= 6.0, "the banner shows for a few seconds (%.1f s)" % up)
	var again := false
	for i in 100:  # 10 s more inside
		b.tick(0.1, _rt, inn)
		again = again or b.showing()
	_expect(not again, "staying inside does not show it again")
	b.tick(0.3, _rt, out)
	b.tick(0.3, _rt, out)
	_expect(not b.showing(), "walking out shows nothing")
	b.tick(0.016, _rt, inn)
	_expect(b.showing() and b.text() == "%s's Domain" % ME, "leaving and coming back shows it again")
	print("[t_domain] enter/stay/leave: up %.1f s, re-entry %s" % [up, b.showing()])

func _test_arrival_and_edge_step() -> void:
	var b: RefCounted = DB.new()
	b.tick(0.016, _rt, _at(_inside()))
	_expect(not b.showing(), "arriving on the island inside your claim is not entering it")
	var t: RefCounted = DB.new()
	t.tick(0.016, _rt, _at(_outside() + Vector2i(0, 9)))
	t.tick(0.016, _rt, _at(_inside()))
	_expect(not t.showing(), "a teleport (respawn) into your claim is not walking into it")
	t.tick(0.6, _rt, _at(_outside()))
	t.tick(0.016, _rt, _at(_inside()))
	_expect(t.showing(), "after a teleport in, walking out and back shows it")
	for i in 60:
		b.tick(0.1, _rt, _at(_inside()))
	b.tick(0.1, _rt, _at(_outside()))
	b.tick(0.016, _rt, _at(_inside()))
	_expect(not b.showing(), "a 0.1 s step over the edge and back does not flash the banner")
	var c: RefCounted = DB.new()
	c.tick(0.016, _rt, _at(_outside()))
	c.tick(0.016, _rt, _at(_inside()))
	c.tick(5.0, _rt, _at(_inside()))
	_expect(c.showing(), "one 5 s frame right after entering does not swallow the banner")

# ---------------------------------------------------------------- another owner

func _test_other_owner() -> void:
	var theirs := Rect2i(_own.end.x, _own.position.y, 12, 12)  # touching the camp plot's east edge
	var before: Object = _rt.get("_claim_mesh").mesh
	_rt.set_other_claims([{"rect": [theirs.position.x, theirs.position.y, theirs.size.x, theirs.size.y], "owner": THEM}])
	_expect(_rt.get("_claim_mesh").mesh != before, "other players' claims rebuild the outline mesh")
	var their_tile := Vector2i(theirs.position.x + 1, theirs.position.y + 4)
	var o: Dictionary = _rt.owner_at(their_tile)
	_expect(o.get("id", "") == THEM.id and o.get("name", "") == THEM.name and not bool(o.get("own", false)), "their tile is %s's (got %s)" % [THEM.name, o])
	_expect(not _rt.is_claimed(their_tile), "another owner's land is not yours to build on")
	var b: RefCounted = DB.new()
	var my_edge := _at(Vector2i(_own.end.x - 1, their_tile.y))
	b.tick(0.016, _rt, my_edge)
	for i in 6:
		b.tick(0.1, _rt, _at(their_tile))
	_expect(b.showing() and b.text() == "%s's Domain" % THEM.name and not bool(b.shown.get("own", false)), "crossing from your land into %s's shows \"%s's Domain\" (got \"%s\")" % [THEM.name, THEM.name, b.text()])
	for i in 6:
		b.tick(0.1, _rt, my_edge)
	_expect(b.text() == "%s's Domain" % ME, "crossing back shows yours again (got \"%s\")" % b.text())
	# The shared edge is one line: drawn once, not twice, in your colour; their other sides in theirs.
	var arr: Array = CO.dashes(_rt)
	var v: PackedVector3Array = arr[0]
	var col: PackedColorArray = arr[1]
	var on_shared := 0
	var shared_col := true
	var theirs_col := 0
	for i in v.size():
		var p := v[i]
		if absf(p.x - float(theirs.position.x)) < 0.2 and p.z >= float(theirs.position.y) and p.z <= float(theirs.end.y):
			on_shared += 1
			shared_col = shared_col and col[i] == CO.COLOR
		elif p.x > float(theirs.position.x) + 0.2:
			theirs_col += 1 if col[i] == CO.OTHER_COLOR else 0
	_expect(on_shared == 6 * theirs.size.y and shared_col, "the edge between two owners is drawn once, yellow (%d vertices, want %d)" % [on_shared, 6 * theirs.size.y])
	_expect(theirs_col == 6 * 3 * theirs.size.x, "%s's other three sides are in the other-owner colour (%d vertices)" % [THEM.name, theirs_col])
	_expect(CO.OTHER_COLOR.h != CO.COLOR.h and CO.DOT < CO.DASH, "other owners' edges differ in colour and dash")
	_rt.set_other_claims([])
	_expect((_rt.owner_at(their_tile) as Dictionary).is_empty(), "clearing other claims frees their land")

## Walking along the border you share with another owner (a step either side every 0.2 s) shows
## neither banner; an island change takes a showing banner down.
func _test_shared_border_and_island_change() -> void:
	var theirs := Rect2i(_own.end.x, _own.position.y, 12, 12)
	_rt.set_other_claims([{"rect": [theirs.position.x, theirs.position.y, theirs.size.x, theirs.size.y], "owner": THEM}])
	var mine := _at(Vector2i(_own.end.x - 1, theirs.position.y + 4))
	var their := _at(Vector2i(theirs.position.x, theirs.position.y + 4))
	var b: RefCounted = DB.new()
	b.tick(0.016, _rt, mine)
	var flashes := 0
	for i in 20:
		b.tick(0.2, _rt, their if i % 2 == 0 else mine)
		flashes += 1 if b.showing() else 0
	_expect(flashes == 0, "walking along a shared border does not flash either banner (%d ticks showing)" % flashes)
	_rt.set_other_claims([])
	var c: RefCounted = DB.new()
	c.tick(0.016, _rt, _at(_outside()))
	c.tick(0.016, _rt, _at(_inside()))
	var other_island := Node.new()
	c.tick(0.016, other_island, _at(_inside()))
	_expect(not c.showing(), "sailing to another island takes the banner down")
	other_island.free()

func _test_malformed_rows() -> void:
	var rows := [
		{"rect": [1, 2], "owner": THEM}, {"rect": [0, 0, 4, 4]}, {"rect": [0, 0, 4, 4], "owner": {"id": "", "name": "x"}},
		{"rect": [0, 0, 4, 4], "owner": {"id": "self", "name": "forged"}}, {"rect": [0, 0, 0, 4], "owner": THEM}, "junk", 7,
		{"rect": [5000, 5000, 12, 12], "owner": THEM},
	]
	_rt.set_other_claims(rows)
	_expect((_rt.get("other_claims") as Array).is_empty(), "malformed and off-island claim rows are dropped (kept %d)" % (_rt.get("other_claims") as Array).size())

# ---------------------------------------------------------------- the outline

func _test_outline_follows_claims() -> void:
	var mi := _rt.get_node_or_null("ClaimBoundary") as MeshInstance3D
	var mat := mi.material_override as StandardMaterial3D if mi else null
	_expect(CO.COLOR.r > 0.85 and CO.COLOR.g > 0.7 and CO.COLOR.b < 0.5, "your claim edge is yellow (%s)" % CO.COLOR)
	# Lit, so it dims at night with the ground; opaque, so the water drawn after it cannot cover it.
	_expect(mat != null and mat.vertex_color_use_as_albedo and mat.vertex_color_is_srgb and mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
		"the claim edge is lit and opaque (shading %s, transparency %s)" % [mat.shading_mode if mat else -1, mat.transparency if mat else -1])
	var v0: PackedVector3Array = CO.dashes(_rt)[0]
	_expect(v0.size() == 6 * 4 * _own.size.x, "one camp plot: one dash per metre of its edge (%d vertices)" % v0.size())
	var down := 0
	for i in range(0, v0.size(), 3):  # Godot's front faces wind clockwise; a lit dash facing down is black
		down += 1 if (v0[i + 2] - v0[i]).cross(v0[i + 1] - v0[i]).y <= 0.0 else 0
	_expect(down == 0, "every dash faces up (%d of %d triangles face down)" % [down, v0.size() / 3])
	var low := INF
	for p in v0:
		low = minf(low, p.y - maxf(_rt.surface_y(p.x, p.z), -0.05))
	_expect(low > 0.0 and low < 0.2, "dashes lie just above the ground (lowest %.3f m)" % low)
	# A touching plot of your own merges: the line between them goes.
	var shared_x := 0
	var added := false
	for d: Vector2i in [Vector2i(14, 0), Vector2i(-14, 0), Vector2i(0, 14), Vector2i(0, -14)]:
		var centre := _own.get_center() + d
		var before: Object = _rt.get("_claim_mesh").mesh
		if _rt.claim_at(centre):
			added = true
			_expect(_rt.get("_claim_mesh").mesh != before, "a new claim rebuilds the outline mesh")
			var v1: PackedVector3Array = CO.dashes(_rt)[0]
			var inner := 0
			for p in v1:
				var on_line: bool = (d.x > 0 and absf(p.x - _own.end.x) < 0.2) or (d.x < 0 and absf(p.x - _own.position.x) < 0.2) \
					or (d.y > 0 and absf(p.z - _own.end.y) < 0.2) or (d.y < 0 and absf(p.z - _own.position.y) < 0.2)
				var within: bool = (p.z > _own.position.y + 0.5 and p.z < _own.end.y - 0.5) if d.x != 0 else (p.x > _own.position.x + 0.5 and p.x < _own.end.x - 0.5)
				if on_line and within:
					inner += 1
			_expect(inner == 0, "two touching plots read as one domain: no dashes on the line between them (%d)" % inner)
			_expect(v1.size() == v0.size() + 6 * 2 * _own.size.x, "the merged outline grows by the new plot's three outer sides (%d -> %d)" % [v0.size(), v1.size()])
			shared_x = d.x
			break
	_expect(added, "a plot next to the camp claim could be staked")
	print("[t_domain] outline: %d dashes, merged plot %s (dx=%d)" % [v0.size() / 6, added, shared_x])

## 400 other players' plots (a server's worth) plus rows reaching off the island: they are cut to the
## island, the rebuild stays under 20 ms, and of the crowd only the NEAREST to the survivor draw, picked
## again as they walk.
func _test_crowd() -> void:
	var half := int(float(_rt.get("_size")) * 0.5)
	var span: int = _rt.get("_tile_span")
	var side := span / 20  # 400 plots tile the island
	var rows := []
	for i in 20:
		for j in 20:
			rows.append({"rect": [-half + i * side, -half + j * side, side, side], "owner": {"id": "p%d" % (i * 20 + j), "name": "N%d" % i}})
	rows.append({"rect": [half - 4, 0, 12, 12], "owner": THEM})  # 8 tiles of it past the island's edge
	var t0 := Time.get_ticks_usec()
	_rt.set_other_claims(rows)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var kept: Array = _rt.get("other_claims")
	var last: Rect2i = kept.back()["rect"] if not kept.is_empty() else Rect2i()
	print("[t_domain] crowd: %d rows, rebuild %.2f ms, island %d tiles, last row %s" % [kept.size(), ms, span, last])
	_expect(ms < 20.0, "400 claims rebuild in under 20 ms (%.2f ms)" % ms)
	var island := Rect2i(-half, -half, span, span)
	var want := 0
	for row in rows:
		var a: Array = row["rect"]
		want += 1 if Rect2i(a[0], a[1], a[2], a[3]).intersects(island) else 0
	_expect(kept.size() == want and want == 401, "every row on the island is kept (%d of %d)" % [kept.size(), want])
	_expect(last == Rect2i(half - 4, 0, 12, 12).intersection(island) and last.size.x == span - half - (half - 4), "a row reaching off the island is cut to it (%s)" % last)
	var outline: Object = _rt.get("_claim_mesh")
	var drawn: PackedInt32Array = outline.get("_drawn")
	_expect(drawn.size() == CO.NEAREST, "of 401 other claims only the %d nearest draw (%d)" % [CO.NEAREST, drawn.size()])
	_expect(_nearest_ok(drawn), "the drawn claims are the ones nearest the survivor")
	var dashes: int = (CO.dashes(_rt, drawn)[0] as PackedVector3Array).size() / 6
	_expect(dashes <= 4 * 14 + CO.NEAREST * 4 * side, "a crowd draws at most your plot and %d others (%d dashes)" % [CO.NEAREST, dashes])
	_player.global_position = _at(Vector2i(-half + 5, -half + 5)) + Vector3(0, 1, 0)
	await process_frame
	await process_frame
	var moved: PackedInt32Array = outline.get("_drawn")
	_expect(moved != drawn and _nearest_ok(moved), "walking elsewhere picks the claims nearest there (%s -> %s)" % [drawn, moved])
	_rt.set_other_claims([])
	_player.global_position = _at(_outside() + Vector2i(0, 5)) + Vector3(0, 1, 0)

func _nearest_ok(drawn: PackedInt32Array) -> bool:
	var at := Vector2(_player.global_position.x, _player.global_position.z)
	var far := 0.0
	var near := INF
	var kept: Array = _rt.get("other_claims")
	for i in kept.size():
		var r: Rect2i = kept[i]["rect"]
		var d := at.distance_to(at.clamp(Vector2(r.position), Vector2(r.end)))
		if i in drawn:
			far = maxf(far, d)
		else:
			near = minf(near, d)
	return far <= near

## Claiming refuses a plot that would take another player's tiles, and a refused claim keeps the
## claim stake; a successful one spends it.
func _test_claim_refusals() -> void:
	var theirs := Rect2i(_own.end.x + 20, _own.position.y, 12, 12)
	_rt.set_other_claims([{"rect": [theirs.position.x, theirs.position.y, theirs.size.x, theirs.size.y], "owner": THEM}])
	var n: int = _rt.claims.size()
	var mid := theirs.get_center()
	_expect(_rt.spawn_ok(_at(mid), false), "setup: the middle of their plot is dry land (claimable but for them)")
	_expect(not _rt.claim_at(mid), "a plot on another player's land is refused")
	var reach := Vector2i(1 << 30, 0)  # dry, outside theirs, its 14x14 plot overlapping theirs
	for k in range(1, 7):
		var t := Vector2i(theirs.position.x - k, mid.y)
		if _rt.spawn_ok(_at(t), false):
			reach = t
			break
	_expect(reach.x != 1 << 30 and not _rt.claim_at(reach), "a plot reaching into another player's land is refused (from %s)" % reach)
	_expect(_rt.claims.size() == n, "a refused claim adds no plot")
	var def_was: Dictionary = _world.island_def
	var free_was: bool = _world.free_claim_used
	var unstable_was: Array = _world.unstable_claims.duplicate()
	_world.island_def = {"kind": "unstable"}
	_world.free_claim_used = true
	_player.inventory.add(load("res://scripts/items/item_stack.gd").make(&"claim_stake", 1))
	var stakes: int = _player.inventory.count_of(&"claim_stake")
	_player.global_position = _at(theirs.get_center()) + Vector3(0, 1, 0)
	_player.actions.claim()
	_expect(_player.inventory.count_of(&"claim_stake") == stakes and _rt.claims.size() == n, "claiming on another player's land keeps the stake (%d -> %d)" % [stakes, _player.inventory.count_of(&"claim_stake")])
	var free := Vector2i(1 << 30, 0)
	for k in 40:
		var t := Vector2i(theirs.end.x + 10 + k * 3, theirs.position.y + 6)
		if _rt.spawn_ok(_at(t), false):
			free = t
			break
	if free.x != 1 << 30:
		_player.global_position = _at(free) + Vector3(0, 1, 0)
		_player.actions.claim()
		_expect(_player.inventory.count_of(&"claim_stake") == stakes - 1 and _rt.claims.size() == n + 1, "a claim that succeeds spends the stake (%d -> %d)" % [stakes, _player.inventory.count_of(&"claim_stake")])
	else:
		_expect(false, "no free dry tile east of %s to claim" % theirs)
	while _rt.claims.size() > n:
		_rt.claims.pop_back()
	_world.island_def = def_was
	_world.free_claim_used = free_was
	_world.unstable_claims = unstable_was
	_player.inventory.consume(&"claim_stake", _player.inventory.count_of(&"claim_stake"))
	_rt.set_other_claims([])

# ---------------------------------------------------------------- portraits

func _test_portrait() -> void:
	var own: Texture2D = PP.texture_for(_rt.owner_at(_inside()), _hud)
	var other: Texture2D = PP.texture_for(THEM, _hud)
	_expect(own != null and other != null, "every owner gets a portrait")
	_expect(PP.texture_for(THEM, _hud) == other, "portraits are cached per owner")
	_expect(other == PP.silhouette(), "an owner with no known look gets the neutral silhouette")
	var img := (PP.silhouette() as Texture2D).get_image()
	_expect(img != null and img.get_width() == PP.SIZE and img.get_pixel(PP.SIZE / 2, PP.SIZE * 2 / 5) != img.get_pixel(4, 4), "the silhouette has a head on its backdrop")
	# Your portrait is rendered again after a gear change, a save load or a new survivor.
	var mine: Dictionary = _rt.owner_at(_inside())
	var cache: Dictionary = PP.get("_cache")
	var held := ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
	cache["self"] = held
	_expect(PP.texture_for(mine, _hud) == held, "your portrait stays cached while nothing changes")
	_player.inventory.add(load("res://scripts/items/item_stack.gd").make(&"raid_helm", 1))  # W2-INV: equip wears an instance from the bag
	_expect(_player.inventory.equip(&"head", &"raid_helm"), "the test helm is worn")
	_expect(PP.texture_for(mine, _hud) != held, "equipping gear drops your cached portrait")
	_player.inventory.unequip(&"head")
	_player.inventory.consume(&"raid_helm", 1)
	PP.texture_for(mine, _hud)
	cache["self"] = held
	var occ: String = _world.occupation
	_world.occupation = "t_domain_other"  # what a save load or a new survivor sets
	_expect(PP.texture_for(mine, _hud) != held, "a save load or a new survivor drops your cached portrait")
	_world.occupation = occ

# ---------------------------------------------------------------- the phone HUD

## At 844x390 the banner takes its slot at the top, above the quest card: off the play area and
## the survivor.
func _test_phone_slot() -> void:
	var was_size := root.size
	var was_scale := root.content_scale_size
	root.size = Vector2i(844, 390)
	root.content_scale_size = Vector2i(844, 390)
	_player.clear_nav()
	var start := _outside() + Vector2i(0, 5)
	_player.global_position = _at(start) + Vector3(0, 1, 0)
	for i in 4:
		await process_frame
	await create_timer(0.7).timeout
	await _walk(start, _inside() - Vector2i(0, 2))
	for i in 3:
		await process_frame
	var view: Vector2 = _hud.get_viewport_rect().size
	var box: Rect2 = _hud.drawn_blocks.get("domain", Rect2())
	var quest: Rect2 = _hud.drawn_blocks.get("quest", Rect2())
	var fig: Rect2 = _hud.figure_rect()
	print("[t_domain] phone view=%s banner=%s quest=%s figure=%s" % [view, box, quest, fig])
	_expect(view == Vector2(844, 390), "the HUD canvas is 844x390 (%s)" % view)
	_expect(box.has_area(), "on a landscape phone the banner shows")
	_expect(box.has_area() and quest.has_area() and box.end.y <= quest.position.y, "on a landscape phone the banner sits above the quest card (%s, quest %s)" % [box, quest])
	_expect(not box.intersects(fig), "on a landscape phone the banner is clear of the survivor (%s, %s)" % [box, fig])
	root.size = was_size
	root.content_scale_size = was_scale
	await process_frame
