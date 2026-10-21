extends SceneTree
## Spec 18 acceptance (domain banner and claim edges). Walking into claimed land shows "<owner>'s
## Domain" with a portrait: once while staying inside, again after leaving and coming back, again
## when stepping straight into another owner's land; arriving on the island is not entering; a step
## over the edge and back does not flash it; the HUD draws it clear of its blocks. Claim data says
## who owns each tile; the dotted outline follows it (a new plot, other players' rows, touching
## plots read as one, malformed rows dropped).
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
	_test_malformed_rows()
	_test_outline_follows_claims()
	_test_portrait()
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
	b.tick(0.016, _rt, _at(their_tile))
	_expect(b.showing() and b.text() == "%s's Domain" % THEM.name and not bool(b.shown.get("own", false)), "stepping from your land into %s's shows \"%s's Domain\" (got \"%s\")" % [THEM.name, THEM.name, b.text()])
	b.tick(0.016, _rt, my_edge)
	_expect(b.text() == "%s's Domain" % ME, "stepping back shows yours again (got \"%s\")" % b.text())
	# The shared edge is one line: drawn once, not twice.
	var v: PackedVector3Array = CO.vertices(_rt)
	var on_shared := 0
	for p in v:
		if absf(p.x - float(theirs.position.x)) < 0.2 and p.z >= float(theirs.position.y) and p.z <= float(theirs.end.y):
			on_shared += 1
	_expect(on_shared == 6 * theirs.size.y, "the edge between two owners is drawn once (%d vertices, want %d)" % [on_shared, 6 * theirs.size.y])
	_rt.set_other_claims([])
	_expect((_rt.owner_at(their_tile) as Dictionary).is_empty(), "clearing other claims frees their land")

func _test_malformed_rows() -> void:
	var rows := [
		{"rect": [1, 2], "owner": THEM}, {"rect": [0, 0, 4, 4]}, {"rect": [0, 0, 4, 4], "owner": {"id": "", "name": "x"}},
		{"rect": [0, 0, 4, 4], "owner": {"id": "self", "name": "forged"}}, {"rect": [0, 0, 0, 4], "owner": THEM}, "junk", 7,
	]
	_rt.set_other_claims(rows)
	_expect((_rt.get("other_claims") as Array).is_empty(), "malformed claim rows are dropped (kept %d)" % (_rt.get("other_claims") as Array).size())

# ---------------------------------------------------------------- the outline

func _test_outline_follows_claims() -> void:
	var mi := _rt.get_node_or_null("ClaimBoundary") as MeshInstance3D
	var mat := mi.material_override as StandardMaterial3D if mi else null
	_expect(mat != null and mat.albedo_color.r > 0.85 and mat.albedo_color.g > 0.7 and mat.albedo_color.b < 0.5, "the claim edge is yellow (%s)" % [mat.albedo_color if mat else "no mesh"])
	var v0: PackedVector3Array = CO.vertices(_rt)
	_expect(v0.size() == 6 * 4 * _own.size.x, "one camp plot: one dash per metre of its edge (%d vertices)" % v0.size())
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
			var v1: PackedVector3Array = CO.vertices(_rt)
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

# ---------------------------------------------------------------- portraits

func _test_portrait() -> void:
	var own: Texture2D = PP.texture_for(_rt.owner_at(_inside()), _hud)
	var other: Texture2D = PP.texture_for(THEM, _hud)
	_expect(own != null and other != null, "every owner gets a portrait")
	_expect(PP.texture_for(THEM, _hud) == other, "portraits are cached per owner")
	_expect(other == PP.silhouette(), "an owner with no known look gets the neutral silhouette")
	var img := (PP.silhouette() as Texture2D).get_image()
	_expect(img != null and img.get_width() == PP.SIZE and img.get_pixel(PP.SIZE / 2, PP.SIZE * 2 / 5) != img.get_pixel(4, 4), "the silhouette has a head on its backdrop")
