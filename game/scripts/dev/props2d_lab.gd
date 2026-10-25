extends Node3D
## PROPS2D lab (specs 27/28): the non-resource props of the home island and of a tropical island,
## drawn as the owner's painted 2D cards instead of 3D meshes, judged in the game camera and measured
## live. Windowed only (frame_post_draw never fires headless):
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=props2d_lab --shot-dir=DIR
## Saves DIR/home_camp.png, DIR/home_props.png, DIR/home_close.png, DIR/tropical_camp.png,
## DIR/tropical_props.png and prints exactly one line:
##   [props2d] RESULT painted_props= model_props= grey_cards= blocks_ok= destroy_ok=
##     cliff_indestructible= clickable_props= ms_frame= ms_base=
## Every number is read from the live island, never a constant:
##   painted_props  props drawn as a card of their own painted sprite, summed over both islands
##   model_props    props that still fell back to a 3D model (must be 0)
##   grey_cards     prop cards whose sprite texture is missing/unpacked (must be 0)
##   blocks_ok      1 when every placed prop's collide matches its data rules on both islands
##   destroy_ok     1 when a destroyable prop clears (card hidden) and a cliff refuses, per island
##   cliff_indestructible  1 when no placed prop 4 m or taller is destroyable
##   clickable_props  props that carry a TapZone or sit in the "harvest" group (must be 0)
##   ms_frame / ms_base  median frame time with the prop cards shown and with them hidden (same frames,
##                       alternating, vsync off), on the tropical island's prop-heavy view

const SHOT_COUNT := 5
## Frames timed per phase, after a warmup, alternating cards-on / cards-off (vsync off: frame times,
## not the display's refresh rate).
const PERF_WARMUP := 20
const PERF_PAIRS := 90

var _player: Player
var _cam: IsoCamera
var _shot_dir := ""
var _shots := 0
var _painted := 0
var _models := 0
var _grey := 0
var _blocks_ok := 1
var _destroy_ok := 1
var _cliffs_ok := 1
var _clickable := 0
var _ms_frame := 0.0
var _ms_base := 0.0
var _pair_on: Array[float] = []
var _pair_off: Array[float] = []
var _pair_mode := false
var _pair_cur_on := true
var _last_us := 0
var _warm := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var kit := LabKit.build(self, 24.0)
	_player = kit["player"]
	_cam = kit["cam"]
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	(kit["ui"] as CanvasLayer).visible = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[boot] lab=props2d_lab")
	# A windowed lab must never hold the runner: quit on its own well inside the gate's alarm.
	get_tree().create_timer(110.0).timeout.connect(func () -> void:
		print("[props2d] FAIL watchdog 110s (shots=%d)" % _shots)
		get_tree().quit(2))
	_run.call_deferred()

func _run() -> void:
	await _island(&"home_grassland")
	await _shot("home_camp")
	await _shot_props("home_props")
	await _shot_close("home_close")
	await _island(&"tropical_25")
	await _shot("tropical_camp")
	await _timing("tropical_props")
	print("[props2d] RESULT painted_props=%d model_props=%d grey_cards=%d blocks_ok=%d destroy_ok=%d cliff_indestructible=%d clickable_props=%d ms_frame=%.2f ms_base=%.2f" % [
		_painted, _models, _grey, _blocks_ok, _destroy_ok, _cliffs_ok, _clickable, _ms_frame, _ms_base])
	print("[props2d] shots=%d dir=%s" % [_shots, _shot_dir])
	get_tree().quit(0 if _shots >= SHOT_COUNT else 1)

# ---------------------------------------------------------------- islands

## Loads one island, stands the survivor at the camp and audits its props (visuals, rules, cliffs,
## clickability) and destroys/refuses one prop pair. The counters accumulate over both islands.
func _island(id: StringName) -> void:
	World.load_island(self, id, Vector3(0, 1, 18), false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var rt: IslandRuntime = World.runtime
	if rt == null:
		_fail("no island for %s" % str(id))
		return
	var props: Node = rt.get("props")
	if props == null:
		_fail("no props layer on %s" % str(id))
		return
	_stand(rt._camp_pos, 20.0)
	await _settle()
	_audit(id, rt, props)
	print("[props2d] island=%s %s" % [str(id), str(props.call("counts_line"))])

func _audit(id: StringName, rt: IslandRuntime, props: Node) -> void:
	var rows: Array = props.get("_rows")
	var cards: Node = props.get("cards")
	if cards == null:
		_fail("%s has no card layer" % str(id))
		return
	var painted := 0
	for r in rows:
		var row := r as Dictionary
		var sprite: Dictionary = row.get("sprite", {}) as Dictionary
		var file := str(sprite.get("file", ""))
		if not sprite.is_empty() and ResourceLoader.exists(file):
			painted += 1
		else:
			_models += 1
		var height := float(row.get("height", 1.0))
		if height >= 4.0 and bool(row.get("collide", false)) and bool(row.get("destroyable", true)):
			_cliffs_ok = 0
			print("[props2d] FAIL a %s at %.1f m is destroyable" % [str(row.get("kind", "")), height])
	_painted += painted
	_grey += int(cards.call("grey_cards"))
	if int(cards.call("instance_count")) != rows.size():
		_blocks_ok = 0
		print("[props2d] FAIL %s: %d cards for %d props" % [str(id), int(cards.call("instance_count")), rows.size()])
	# Collision rules re-derived from data for every placed prop.
	for r in rows:
		var row := r as Dictionary
		var kind := str(row.get("kind", ""))
		var sprite: Dictionary = row.get("sprite", {}) as Dictionary
		var rules: Dictionary = IslandProps.prop_rules(kind, sprite, float(row.get("height", 1.0)))
		if bool(row.get("collide", false)) != bool(rules["blocks"]) \
				or bool(row.get("destroyable", true)) != bool(rules["destroyable"]):
			_blocks_ok = 0
			print("[props2d] FAIL %s rules differ (collide %s/%s destroyable %s/%s)" % [
				kind, row.get("collide", false), rules["blocks"], row.get("destroyable", true), rules["destroyable"]])
			break
	# Clickable: no prop carries a TapZone, none is in "harvest".
	for c in get_tree().get_nodes_in_group("props"):
		if c is Node:
			for n in (c as Node).find_children("*", "Area3D", true, false):
				_clickable += 1
	for c in get_tree().get_nodes_in_group("harvest"):
		if c.is_in_group("props"):
			_clickable += 1
	# Clear one destroyable prop, refuse one cliff.
	var clear_row := _nearest_row(props, ["fallen_log", "boulder", "mossy_stone", "tree_stump", "fern", "reeds"])
	if not clear_row.is_empty():
		var idx := int(clear_row.get("card_idx", -1))
		var tile: Vector2i = clear_row["tile"]
		var ok := bool(props.call("clear_at_tile", tile))
		if not ok or (idx >= 0 and bool(cards.call("is_shown", idx))):
			_destroy_ok = 0
			print("[props2d] FAIL %s: %s did not clear (ok=%s shown=%s)" % [
				str(id), str(clear_row.get("kind", "")), ok, cards.call("is_shown", idx) if idx >= 0 else "-"])
	var cliff := _nearest_row(props, ["cliff_rock", "mesa_cliff", "basalt_column", "rock_spire", "stone_arch", "pillar", "waterfall"])
	if not cliff.is_empty():
		if bool(props.call("clear_at_tile", cliff["tile"])):
			_cliffs_ok = 0
			print("[props2d] FAIL %s: a cliff cleared (%s)" % [str(id), str(cliff.get("kind", ""))])
	else:
		print("[props2d] island=%s no naturally placed cliff to refuse" % str(id))

func _nearest_row(props: Node, kinds: Array) -> Dictionary:
	var rows: Array = props.get("_rows")
	var p := _player.global_position
	var best: Dictionary = {}
	var best_d := 1e9
	for r in rows:
		var row := r as Dictionary
		if bool(row.get("cleared", false)) or not (str(row.get("kind", "")) in kinds):
			continue
		var d := p.distance_to(row["pos"] as Vector3)
		if d < best_d:
			best_d = d
			best = row
	return best

func _fail(what: String) -> void:
	_painted = 0
	_models += 1
	print("[props2d] FAIL %s" % what)

# ---------------------------------------------------------------- shots

func _stand(at: Vector3, size: float) -> void:
	var rt: IslandRuntime = World.runtime
	var y := at.y + 1.0
	if rt != null:
		y = rt.surface_y(at.x + 2.4, at.z + 2.4) + 1.0
	_player.global_position = Vector3(at.x + 2.4, y, at.z + 2.4)
	_cam.size = size
	_cam._snap()

func _settle() -> void:
	for i in 10:
		await get_tree().process_frame

func _shot(tag: String) -> void:
	await _shot_file(tag)

func _shot_props(tag: String) -> void:
	var rt: IslandRuntime = World.runtime
	var props: Node = rt.get("props") if rt != null else null
	if props == null:
		return
	var row := _nearest_row(props, ["boulder", "rock_spire", "cliff_rock", "fallen_log", "termite_mound", "tree_stump"])
	if row.is_empty():
		await _shot(tag)
		return
	_stand(row["pos"] as Vector3, 12.0)
	await _settle()
	await _shot(tag)

func _shot_close(tag: String) -> void:
	var rt: IslandRuntime = World.runtime
	var props: Node = rt.get("props") if rt != null else null
	if props == null:
		return
	var row := _nearest_row(props, ["fern", "reeds", "plume_grass", "shells", "mossy_stone", "pebbles"])
	if row.is_empty():
		await _shot(tag)
		return
	_stand(row["pos"] as Vector3, 5.0)
	await _settle()
	await _shot(tag)

func _shot_file(tag: String) -> void:
	for i in 4:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("[props2d] shot %s failed" % tag)
		return
	var path := "%s/props2d_%s.png" % [_shot_dir, tag]
	img.save_png(path)
	_shots += 1
	print("[props2d] shot %s" % path)

# ---------------------------------------------------------------- timing

## Median frame time with the prop cards shown vs hidden, alternating every frame after a warmup. The
## view is the prop-heavy one `tag` stands in, so the number says what the cards cost here.
func _timing(tag: String) -> void:
	await _shot_props(tag)
	var rt: IslandRuntime = World.runtime
	var props: Node = rt.get("props") if rt != null else null
	var cards: Node = props.get("cards") if props != null else null
	if cards == null:
		return
	_pair_mode = true
	_pair_on.clear()
	_pair_off.clear()
	_pair_cur_on = true
	_warm = 0
	_last_us = 0
	for i in PERF_WARMUP:
		await get_tree().process_frame
	_last_us = 0
	while _pair_on.size() + _pair_off.size() < PERF_PAIRS * 2:
		await get_tree().process_frame
	_pair_mode = false
	(cards as Node3D).visible = true
	_pair_on.sort()
	_pair_off.sort()
	_ms_frame = _median(_pair_on)
	_ms_base = _median(_pair_off)
	print("[props2d] timing cards n=%d median=%.2f mean=%.2f | hidden n=%d median=%.2f mean=%.2f" % [
		_pair_on.size(), _ms_frame, _mean(_pair_on), _pair_off.size(), _ms_base, _mean(_pair_off)])

func _process(_delta: float) -> void:
	if not _pair_mode:
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var ms := float(now - _last_us) / 1000.0
		if _pair_cur_on:
			_pair_on.append(ms)
		else:
			_pair_off.append(ms)
		_pair_cur_on = not _pair_cur_on
		var rt: IslandRuntime = World.runtime
		var props: Node = rt.get("props") if rt != null else null
		var cards: Node = props.get("cards") if props != null else null
		if cards != null:
			(cards as Node3D).visible = _pair_cur_on
	_last_us = now

func _median(a: Array[float]) -> float:
	return a[a.size() / 2] if not a.is_empty() else 0.0

func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var sum := 0.0
	for x in a:
		sum += x
	return sum / float(a.size())
