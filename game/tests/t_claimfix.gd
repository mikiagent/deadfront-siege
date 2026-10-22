extends SceneTree
## CLAIMFIX acceptance (playtest 2026-10-21): a second CLAIM never takes land without an explicit
## confirm that names what you keep, the placer ghost spawns in front of the survivor on valid
## claimed ground (not under the bottom-left HUD where the pointer still rests), and the placer's
## ROTATE / PLACE / CANCEL hexes clear every other visible HUD control at 1600x900 and 844x390.
## Run: Godot --headless --path game --script res://tests/t_claimfix.gd -> "[t_claimfix] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const ME := "Tess"

var _fails: PackedStringArray = []
var _started := false
var _G: Node
var _host: Node3D
var _player: Node
var _hud: Control
var _rt: Node
var _world: Node
var _kit: Dictionary
var BG: GDScript  ## build_grid.gd, load()ed on the first frame: `--script` compiles this file before autoloads exist
var IS: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	# Watchdog: a run that dies mid-test ends, rather than idling to the outer alarm.
	root.get_tree().create_timer(120.0).timeout.connect(func () -> void:
		print("[t_claimfix] FAIL watchdog: the run did not finish in 120 s")
		quit(1))
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_claimfix] FAIL %s" % what)

func _run() -> void:
	BG = load("res://scripts/world/build_grid.gd")
	IS = load("res://scripts/items/item_stack.gd")
	_G = root.get_node("Game")
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TClaimfixHost"
	root.add_child(_host)
	_kit = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = _kit["player"]
	for c in (_kit["ui"] as CanvasLayer).get_children():
		if c.has_method("taken_rects"):
			_hud = c
	_world.player_name = ME
	_world.home_claims = []
	_world.unstable_claims = []
	_world.free_claim_used = false
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(_kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = _world.runtime
	await _test_second_claim_needs_confirm()
	await _test_ghost_seat()
	await _test_placer_hexes_clear()
	if _fails.is_empty():
		print("[t_claimfix] PASS")
		quit(0)
	else:
		print("[t_claimfix] FAIL count=%d" % _fails.size())
		quit(1)

## Walk the survivor to a dry tile that is not theirs yet; the camp plot stays where it is.
func _stand_outside(min_dist: float) -> bool:
	var own: Rect2i = _rt.claims[0]
	var at: Vector2 = Vector2(own.get_center()) + Vector2(min_dist, 0.0)
	for k in 40:
		var pos := Vector3(at.x + float(k) * 3.0, 0.0, at.y)
		pos.y = _rt.surface_y(pos.x, pos.z) + 0.05
		var tile: Vector2i = BG.tile_of(pos)
		if _rt.spawn_ok(BG.tile_centre(tile, _rt), false) and not _rt.is_claimed(tile):
			_player.global_position = pos
			return true
	return false

func _without_claim(give_stake: bool) -> void:
	_Xc(_hud, "claim_confirm_cancel", [])
	var rt: Node = _rt
	while rt.claims.size() > 1:
		rt.claims.pop_back()
	_world.home_claims = [[rt.claims[0].position.x, rt.claims[0].position.y, rt.claims[0].size.x, rt.claims[0].size.y]]
	if give_stake and _player.inventory.count_of(&"claim_stake") < 1:
		_player.inventory.add(IS.make(&"claim_stake", 1))

## A CLAIM press with land already held asks first and only an orthogonal expansion can be staked
## (PRD 13.1); a non-adjacent or self-overlapping plot is refused with a reason. Nothing held is moved.
func _test_second_claim_needs_confirm() -> void:
	_without_claim(true)
	_expect(_rt.claims.size() == 1, "setup: the camp plot is the only claim (%d)" % _rt.claims.size())
	_expect(not _Ge(_hud, "claim_panel_open"), "the claim confirm panel is closed to begin with")
	var start: Rect2i = _rt.claims[0]
	var saved_before: Array = (_world.home_claims as Array).duplicate()
	# 1. A press away from the land: the panel says why it can't expand, and nothing is staked.
	var far := Vector2i(start.end.x + 22, start.get_center().y)
	_expect(_stand_at(far) != "", "setup: the survivor stands on dry land well off the camp plot (%s)" % far)
	_player.actions.claim()
	await process_frame
	_expect(_rt.claims.size() == 1, "a second CLAIM press does not take land by itself (%d claims)" % _rt.claims.size())
	_expect(_rt.claims[0] == start, "the press left the camp plot where it was (%s -> %s)" % [start, _rt.claims[0]])
	_expect(_world.home_claims == saved_before, "the press saved no new plot (%s)" % [_world.home_claims])
	_expect(_Ge(_hud, "claim_panel_open"), "the press opens the confirm panel")
	if not _Ge(_hud, "claim_panel_open"):
		return
	var far_text := str(_Xu(_hud, "claim_panel_text")).replace("\n", " ")
	print("[t_claimfix] panel away from the land: %s" % far_text)
	_expect(far_text.contains("none of") and far_text.to_lower().contains("edge"), "the panel names what stays and why a plot out there is refused: \"%s\"" % far_text)
	_Xc(_hud, "claim_confirm", [true])
	await process_frame
	_expect(_rt.claims.size() == 1 and _rt.claims[0] == start, "confirming a non-adjacent plot takes nothing (%d claims)" % _rt.claims.size())
	_expect(not _Ge(_hud, "claim_panel_open"), "the panel closes on confirm")
	# 2. A press inside the land: the plot would take your own tiles again; Close takes nothing.
	_expect(_stand_at(start.get_center()) != "", "setup: the survivor stands on the camp plot's centre")
	_player.actions.claim()
	await process_frame
	var mid_text := str(_Xu(_hud, "claim_panel_text")).replace("\n", " ")
	print("[t_claimfix] panel inside the land: %s" % mid_text)
	_expect(mid_text.to_lower().contains("overlap"), "the panel refuses a plot that takes your own land again: \"%s\"" % mid_text)
	_Xc(_hud, "claim_confirm", [false])
	await process_frame
	_expect(not _Ge(_hud, "claim_panel_open") and _rt.claims.size() == 1, "Close takes nothing (%d claims)" % _rt.claims.size())
	# 3. One plot east of the camp plot: shares a full edge, so the panel's EXPAND stakes it.
	var next := Vector2i(start.end.x + start.size.x / 2, start.get_center().y)
	_expect(_stand_at(next) != "", "setup: the survivor stands one plot east of the camp plot (%s)" % next)
	_player.actions.claim()
	await process_frame
	_expect(_Ge(_hud, "claim_panel_open"), "a press next to the land asks again")
	var near_text := str(_Xu(_hud, "claim_panel_text")).replace("\n", " ")
	print("[t_claimfix] panel next to the land: %s" % near_text)
	_expect(near_text.contains("14x14") and near_text.to_lower().contains("edge"), "the panel names the 14x14 expansion and that it shares an edge: \"%s\"" % near_text)
	_Xc(_hud, "claim_confirm", [true])
	await process_frame
	_expect(_rt.claims.size() == 2, "EXPAND adds exactly one plot (%d claims)" % _rt.claims.size())
	_expect(_rt.claims.has(start), "the camp plot is still yours after the confirm (%s)" % [_rt.claims])
	var fresh := _rect(next)
	_expect(_rt.claims.has(fresh), "the added plot is the 14x14 centred on the survivor at %s (%s, got %s)" % [next, fresh, _rt.claims])
	_expect(_world.home_claims.size() == saved_before.size() + 1, "the confirm saved the new plot (%s)" % [_world.home_claims])
	_expect(not _Ge(_hud, "claim_panel_open"), "the panel closes on confirm")
	# 4. A stake is spent only by the commit; the ask and a refused plot keep it.
	_world.island_def = {"kind": "unstable"}
	_world.free_claim_used = true
	_without_claim(true)
	var stakes: int = _player.inventory.count_of(&"claim_stake")
	_expect(stakes == 1, "setup: one claim stake in the bag (%d)" % stakes)
	_expect(_stand_at(next) != "", "setup: the survivor stands one plot east of the camp plot again")
	_player.actions.claim()
	await process_frame
	_expect(_player.inventory.count_of(&"claim_stake") == stakes and _rt.claims.size() == 1, "asking for an expansion spends no stake and takes no land (%d stakes, %d claims)" % [_player.inventory.count_of(&"claim_stake"), _rt.claims.size()])
	_Xc(_hud, "claim_confirm", [true])
	await process_frame
	_expect(_player.inventory.count_of(&"claim_stake") == stakes - 1 and _rt.claims.size() == 2, "the confirm spends the stake and takes the plot (%d stakes, %d claims)" % [_player.inventory.count_of(&"claim_stake"), _rt.claims.size()])
	_world.island_def = {"kind": "private"}
	_world.free_claim_used = false
	_player.inventory.consume(&"claim_stake", _player.inventory.count_of(&"claim_stake"))

## Stand on `tile`; returns the surface height used ("" when the tile is water).
func _stand_at(tile: Vector2i) -> String:
	var c: Vector3 = BG.tile_centre(tile, _rt)
	if not _rt.spawn_ok(c, false):
		return ""
	_player.global_position = Vector3(c.x, float(_rt.surface_y(c.x, c.z)) + 0.05, c.z)
	return "%.2f" % _player.global_position.y

## The ghost starts in front of the survivor on valid claimed ground, not at the pointer's corner.
func _test_ghost_seat() -> void:
	_without_claim(false)
	var own: Rect2i = _rt.claims[0]
	_player.global_position = Vector3(own.get_center().x, 0.0, own.get_center().y)
	_player.global_position.y = _rt.surface_y(_player.global_position.x, _player.global_position.z) + 0.05
	await physics_frame
	_G.set("pointer", Vector2(16.0, 892.0))  # the bottom-left hex the BUILD sheet was tapped on
	var placer: Node = _player.placer
	placer.begin(&"basket")
	await process_frame
	await process_frame
	var ghost: Node3D = placer.get("_ghost_root")
	var gp: Vector3 = ghost.global_position
	var pp: Vector3 = _player.global_position
	var dist := Vector2(gp.x - pp.x, gp.z - pp.z).length()
	print("[t_claimfix] ghost at %s, survivor at %s: %.2f m ahead, valid=%s reason=%s" % [gp, pp, dist, placer.valid, placer.reason])
	_expect(dist <= 6.0, "the ghost spawns within 6 m of the survivor (%.2f m)" % dist)
	_expect(dist >= 1.0, "the ghost spawns in front of the survivor, not on top of them (%.2f m)" % dist)
	_expect(bool(placer.valid), "the ghost lands on ground it can be placed on (valid=%s reason=%s)" % [placer.valid, placer.reason])
	_expect(_rt.is_claimed(BG.tile_of(gp)), "the ghost's tile is inside the claim (%s)" % [BG.tile_of(gp)])
	var forward := Vector2(gp.x - pp.x, gp.z - pp.z).dot(Vector2(-_player.global_transform.basis.z.x, -_player.global_transform.basis.z.z))
	_expect(forward > 0.0, "the ghost is ahead of where the survivor faces (%.2f m along the facing)" % forward)
	placer.cancel()

## Both canvases: no placer hex or its caption overlaps another visible HUD control. Checked against
## every HUD rect taken_rects() reports, its own three hexes the only exemption (HANDS counts too: it
## left the corner while placing, so the row may use it).
func _test_placer_hexes_clear() -> void:
	var was_size: Vector2i = root.size
	var was_scale: Vector2i = root.content_scale_size
	for size in [Vector2i(1600, 900), Vector2i(844, 390)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		await process_frame
		_G.set("pointer", Vector2(16.0, float(size.y) - 46.0))  # the MENU hex, as after a BUILD sheet tap
		var placer: Node = _player.placer
		placer.begin(&"basket")
		await process_frame
		await process_frame
		var mine: Array[Rect2] = []
		var own: Array[Rect2] = []
		var hexes: Array = _hud.get("_place_hexes")
		var shown := 0
		for h in hexes:
			var hb: Node = h
			if not (hb as Control).is_visible_in_tree():
				continue
			shown += 1
			own.append(hb.call("hex_rect"))
			own.append(hb.call("caption_rect"))
			mine.append_array([hb.call("hex_rect"), hb.call("caption_rect")])
			_expect((hb as Control).size.x >= 64.0 and (hb as Control).size.y >= 64.0, "%dx%d: placer hex keeps a 64 px tap target (%s)" % [size.x, size.y, (hb as Control).size])
		_expect(shown == 3, "%dx%d: ROTATE / PLACE / CANCEL are shown while placing (%d)" % [size.x, size.y, shown])
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var hits := 0
		for r in mine:
			_expect(view.encloses(r.grow(-0.5)), "%dx%d: placer rect %s stays inside the view" % [size.x, size.y, r])
			for t in (_hud.call("taken_rects") as Array):
				if own.has(t as Rect2):
					continue
				if (t as Rect2).grow(-1.0).intersects(r.grow(-1.0)):
					hits += 1
					_expect(false, "%dx%d: placer rect %s overlaps the HUD control %s" % [size.x, size.y, r, t])
		print("[t_claimfix] %dx%d: placer rects=%s, HUD overlaps=%d" % [size.x, size.y, mine, hits])
		placer.cancel()
		await process_frame
	root.size = was_size
	root.content_scale_size = was_scale
	await process_frame

## IslandClaims.plot_at without the class name (see BG above).
func _rect(tile: Vector2i, n: int = 14) -> Rect2i:
	return Rect2i(tile - Vector2i(n / 2, n / 2), Vector2i(n, n))

func _Ge(obj: Object, method: String) -> Variant:
	if obj == null or not obj.has_method(method):
		return false
	return obj.call(method)

func _Xu(obj: Object, method: String) -> Variant:
	if obj == null or not obj.has_method(method):
		return ""
	return obj.call(method)

func _Xc(obj: Object, method: String, args: Array) -> void:
	if obj != null and obj.has_method(method):
		obj.callv(method, args)
