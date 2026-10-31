extends Node3D
## Spec 18 (domain banner and claim edges), windowed. Boots the home island with the real HUD, walks
## the survivor across its camp claim's edge, stays inside, walks out and back in, then (when the
## runtime takes other players' claims) into a neighbour's domain next door, and last stands in a
## crowd of 36 other plots. Saves <step>_<w>x<h>.png per step and prints what the HUD drew: the
## domain banner ("domain" in HuntHud.drawn_blocks) and the claim boundary mesh.
## Windowed: --resolution 1600x900 -- --lab=domain_lab --shot-dir=DIR [--tod=0.92 for night] (also
## 844x390; add --rendering-method gl_compatibility for the web renderer).
## Prints "[domain] PASS ..." (exit 0) or "[domain] FAIL ..." lines (exit 1).

const NEIGHBOUR := {"id": "lab_neighbour", "name": "Rowan"}

var _out := ""
var _player: Player
var _hud: HuntHud
var _fails: PackedStringArray = []
var _max_dt := 0.0  ## the longest frame since the last step (a first portrait render can hitch)

var _was_up := false
var _was_inside := false

func _process(delta: float) -> void:
	_max_dt = maxf(_max_dt, delta)
	var domain: Variant = _hud.get("_domain") if _hud else null
	if domain == null or World.runtime == null or _player == null:
		return
	var up: bool = domain.call("showing")
	var inside := _claimed_here()
	if up != _was_up or inside != _was_inside:
		print("[domain] t=%.2f tile=%s inside=%s banner=%s" % [Time.get_ticks_msec() / 1000.0, BuildGrid.tile_of(_player.global_position), inside, up])
	_was_up = up
	_was_inside = inside

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("domain")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		if a.begins_with("--tod="):
			Game.time_of_day = float(a.substr(6))
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.player_name = "Milan"
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_run.call_deferred()

func _run() -> void:
	await _wait(2.5)
	var rt := World.runtime
	var own: Rect2i = rt.claims[0]
	# Across the claim's +z edge, the side facing the iso camera (it looks from +x +z).
	var out_tile := Vector2i(own.position.x + own.size.x / 2 + 2, own.end.y + 5)
	var in_tile := Vector2i(out_tile.x, own.end.y - 3)
	_place(out_tile)
	await _wait(2.0)
	_report_edge(rt)
	await _step("outside", false)
	await _walk(in_tile, true)
	await _wait(0.7)
	await _step("entered", true)
	await _wait(4.5)
	await _step("staying", false)
	await _walk(out_tile, false)
	await _wait(1.2)
	await _walk(in_tile, true)
	await _wait(0.7)
	await _step("reentered", true)
	if rt.has_method("set_other_claims"):
		var theirs := Rect2i(own.end.x + 10, own.position.y, 12, 12)
		rt.call("set_other_claims", [{"rect": [theirs.position.x, theirs.position.y, theirs.size.x, theirs.size.y], "owner": NEIGHBOUR}])
		var near := Vector2i(theirs.position.x - 4, theirs.position.y + 6)
		_place(near)
		await _wait(2.0)
		await _walk(Vector2i(theirs.position.x + 3, near.y), true)
		await _wait(0.7)
		await _step("neighbour", true, str(NEIGHBOUR.name))
		# A crowd: 36 plots of 36 owners around the neighbour's; only the nearest few draw.
		var rows := []
		for i in 6:
			for j in 6:
				rows.append({"rect": [theirs.position.x - 30 + i * 12, theirs.position.y - 30 + j * 12, 12, 12], "owner": {"id": "lab_crowd%d" % (i * 6 + j), "name": "Crowd %d" % (i * 6 + j)}})
		rt.call("set_other_claims", rows)
		await _wait(4.6)  # a switch to the crowd plot underfoot shows after 0.5 s, for 3.5 s
		var outline := rt.get_node_or_null("ClaimBoundary")
		var drawn: Variant = outline.get("_drawn") if outline else null
		print("[domain] crowd: %d other claims, %s drawn" % [rt.get("other_claims").size(), drawn.size() if drawn != null else "all"])
		await _step("crowd", false)
	else:
		print("[domain] runtime has no set_other_claims: neighbour step skipped")
	if _fails.is_empty():
		print("[domain] PASS tod=%.2f steps=outside,entered,staying,reentered%s" % [Game.time_of_day, ",neighbour,crowd" if rt.has_method("set_other_claims") else ""])
		get_tree().quit(0)
	else:
		for f in _fails:
			print("[domain] FAIL %s" % f)
		get_tree().quit(1)

func _place(tile: Vector2i) -> void:
	_player.clear_nav()
	var at := BuildGrid.tile_centre(tile, World.runtime)
	_player.global_position = at + Vector3(0, 1.0, 0)
	_player.velocity = Vector3.ZERO

## Walks to the tile's centre and returns once the survivor stands inside (or outside) claimed land.
func _walk(tile: Vector2i, inside: bool) -> void:
	_player.nav_to(BuildGrid.tile_centre(tile, World.runtime))
	var left := 8.0
	while left > 0.0 and _claimed_here() != inside:
		await get_tree().process_frame
		left -= get_process_delta_time()
	if _claimed_here() != inside:
		_fails.append("walk to %s never got %s claimed land (at %s)" % [tile, "into" if inside else "out of", BuildGrid.tile_of(_player.global_position)])

func _claimed_here() -> bool:
	var rt := World.runtime
	var tile := BuildGrid.tile_of(_player.global_position)
	if rt.has_method("owner_at"):
		return not (rt.call("owner_at", tile) as Dictionary).is_empty()
	return rt.is_claimed(tile)

func _step(name: String, want_banner: bool, want_name: String = "") -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var banner := _hud.drawn_blocks.has("domain")
	var domain: Variant = _hud.get("_domain")
	var text := str(domain.call("text")) if domain != null and banner else ""
	var tile := BuildGrid.tile_of(_player.global_position)
	print("[domain] %s tile=%s claimed=%s banner=%s text=\"%s\" rect=%s age=%s owner=%s fps=%d max_frame=%.2fs" % [name, tile, _claimed_here(), banner, text, _hud.drawn_blocks.get("domain", Rect2()),
		domain.get("age") if domain != null else "-", domain.get("owner") if domain != null else "-", Engine.get_frames_per_second(), _max_dt])
	_max_dt = 0.0
	if banner != want_banner:
		_fails.append("%s: banner %s, want %s" % [name, banner, want_banner])
		if domain != null and domain.call("showing"):
			print("[domain] %s: banner up but no free spot; taken %s" % [name, _hud.taken_rects()])
	if want_name != "" and not text.begins_with(want_name):
		_fails.append("%s: banner reads \"%s\", want %s's" % [name, text, want_name])
	if banner:
		var box: Rect2 = _hud.drawn_blocks["domain"]
		for k in ["vitals", "quest", "map_title", "map_text", "plate"]:
			if _hud.drawn_blocks.has(k) and box.intersects(_hud.drawn_blocks[k]):
				_fails.append("%s: banner %s covers %s %s" % [name, box, k, _hud.drawn_blocks[k]])
		var minimap := Rect2(_hud._minimap.position, Vector2(HuntHud.MAP_PX, HuntHud.MAP_PX))
		if box.intersects(minimap):
			_fails.append("%s: banner %s covers the minimap %s" % [name, box, minimap])
		if box.intersects(_hud.figure_rect()):
			_fails.append("%s: banner %s covers the survivor %s" % [name, box, _hud.figure_rect()])
		var quest: Rect2 = _hud.drawn_blocks.get("quest", Rect2())
		if HudLayout.landscape_phone(get_viewport().get_visible_rect().size) and quest.has_area() and box.end.y > quest.position.y:
			_fails.append("%s: on a phone the banner %s left its slot above the quest card %s" % [name, box, quest])
		if not Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(box):
			_fails.append("%s: banner %s leaves the view" % [name, box])
	var img := get_tree().root.get_texture().get_image()
	if img and img.get_width() >= 8:
		var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
		img.save_png(path)
		print("[domain] shot %s" % path)

func _report_edge(rt: IslandRuntime) -> void:
	var mi := rt.get_node_or_null("ClaimBoundary") as MeshInstance3D
	if mi == null or mi.mesh == null:
		print("[domain] edge: no ClaimBoundary mesh")
		return
	var mat := mi.material_override as StandardMaterial3D
	if mat:
		print("[domain] edge material: shading=%d transparency=%d vertex_colour=%s albedo=%s" % [mat.shading_mode, mat.transparency, mat.vertex_color_use_as_albedo, mat.albedo_color])
	var prim := "?"
	var verts := 0
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		prim = "lines" if int(RenderingServer.mesh_get_surface(mi.mesh.get_rid(), s).get("primitive", -1)) == RenderingServer.PRIMITIVE_LINES else "triangles"
	print("[domain] edge: ClaimBoundary %s verts=%d colour=%s" % [prim, verts, mat.albedo_color if mat else "?"])

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
