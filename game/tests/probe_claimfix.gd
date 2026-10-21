extends SceneTree
## CLAIMFIX probe (before/after numbers). Reproduces the playtest 2026-10-21 findings on whatever
## code is in the tree, writes the numbers to user://claimfix-probe.log (headless has no stdout that
## survives a crash) and prints them with [probe] tags.
## 1. A second CLAIM near the old plot appended another 14x14 instead of refusing or expanding.
## 2. The build placer's ghost spawns at the tile under the screen pointer (0,0 = bottom-left HUD)
##    and the ROTATE/PLACE/CANCEL hexes are placed off a bottom-left HUD control.
## Run: Godot --headless --path game --script res://tests/probe_claimfix.gd

const ME := "Tess"

var _started := false
var _G: Node
var _host: Node3D
var _player: Node
var _hud: Control
var _rt: Node
var _lines: PackedStringArray = []

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	# Watchdog: a probe that dies mid-run must end, not idle until the outer alarm.
	root.get_tree().create_timer(90.0).timeout.connect(func () -> void:
		print("[probe] WATCHDOG quit(2)")
		quit(2))
	_run()
	return false

func _say(s: String) -> void:
	print("[probe] %s" % s)
	_lines.append(s)

func _run() -> void:
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host_of(), 4.0)
	_player = kit["player"]
	_hud = null
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("taken_rects"):
			_hud = c
	var world: Node = root.get_node("World")
	_G = root.get_node("Game")
	world.player_name = ME
	for k in ["home_claims", "unstable_claims"]:
		world.set(k, [])
	world.set("free_claim_used", false)
	world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = world.runtime
	var start: Rect2i = Rect2i() if _rt.claims.is_empty() else _rt.claims[0]
	_say("claims on load: %s" % [_rt.claims])
	# 1. Walk 12 m east onto unclaimed land, press CLAIM (what the playtest did twice).
	_player.global_position = Vector3(12.0, _rt.surface_y(12.0, 18.0), 18.0)
	await physics_frame
	_player.actions.claim()
	await process_frame
	_say("after claim #1 at tile (12,18): claims=%s saved=%s" % [_rt.claims, world.claims_for_current()])
	_say("start plot still present: %s" % (_rt.claims.has(start)))
	var n_before: int = _rt.claims.size()
	var old: Rect2i = _rt.claims[n_before - 1] if n_before > 0 else Rect2i()
	_player.global_position = Vector3(14.5, _rt.surface_y(14.5, 24.0), 24.0)
	await physics_frame
	_player.actions.claim()
	await process_frame
	_say("after claim #2 3 m east: claims=%d (was %d), moved=%s" % [_rt.claims.size(), n_before, _rt.claims.has(old) and _rt.claims.size() == n_before])
	_say("claim panel opened by a second CLAIM: %s" % (_hud.call("claim_panel_open") if _hud.has_method("claim_panel_open") else "no panel in this build"))
	if _hud.has_method("claim_confirm_cancel"):
		_hud.call("claim_confirm_cancel")
	# 2. Ghost spawn.
	_G.set("pointer", Vector2.ZERO)
	var placer: Node = _player.placer
	placer.begin(&"basket")
	await process_frame
	var ghost: Node3D = placer.get("_ghost_root")
	var gp: Vector3 = ghost.global_position
	var pp: Vector3 = _player.global_position
	_say("pointer=%s ghost at %s, survivor at %s: %.2f m from the survivor (want <= 6), valid=%s reason=%s cell=%s" % [_G.get("pointer"), gp, pp, Vector2(gp.x - pp.x, gp.z - pp.z).length(), placer.valid, placer.reason, placer.cell])
	placer.cancel()
	# 3. Placer hexes against the HUD at both canvases.
	for size in [Vector2i(1600, 900), Vector2i(844, 390)]:
		root.content_scale_size = size
		root.size = size
		await process_frame
		await process_frame
		_G.set("pointer", Vector2(16.0, size.y - 46.0))  # taps the bottom-left hex (MENU) if a touch slips through
		placer.begin(&"basket")
		await process_frame
		await process_frame
		print("[probe]   view=%s placer hexes=%s" % [size, _placer_rects()])
		print("[probe]   MENU hex=%s" % [(_hud.get("_menu_hex") as HexButton).hex_rect()])
		var hits := _hex_hits()
		_say("%dx%d: placer hex hits on other HUD controls=%d %s" % [size.x, size.y, hits.size(), hits])
		placer.cancel()
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	var f := FileAccess.open("user://claimfix-probe.log", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	quit(0)

func _host_of() -> Node3D:
	if _host == null:
		_host = Node3D.new()
		_host.name = "ProbeClaimfixHost"
		root.add_child(_host)
	return _host

## [name, rect] of every visible placer hex that intersects another visible HUD control.
func _placer_rects() -> Array:
	var out: Array = []
	for h in _hud.get("_place_hexes"):
		if (h as Control).is_visible_in_tree():
			out.append((h as HexButton).hex_rect())
	return out

func _hex_hits() -> Array:
	var self_hexes: Array = _hud.get("_place_hexes")
	var mine: Array[Rect2] = []
	for h in self_hexes:
		if (h as Control).is_visible_in_tree():
			mine.append((h as HexButton).hex_rect())
	var taken: Array[Rect2] = _hud.call("taken_rects")
	var out: Array = []
	for r in taken:
		for m in mine:
			if r.grow(-0.5).intersects(m.grow(-0.5)):
				out.append(r)
	return out

