extends SceneTree
## PROPS2D acceptance (specs 27/28, owner 2026-10-21: "resources 2D but realistic and kind of look 3D",
## "the resources have the UI that is clickable and the props do not", "most props can be destroyed
## except for like really big cliffs"):
##   - every prop kind with painted art (data/world/sprites2d.json, kind "prop:*") maps to it through
##     data/world/props.json, and the mapping names art that exists on disk;
##   - no prop draws a 3D mesh: every placed prop is a painted card of its own sprite;
##   - a prop's collision and destroyable follow the data (props.json collide/destroyable + the sprite
##     row's blocks/destroyable), and a big cliff (4 m or more, blocking) never breaks;
##   - props are never clickable: no TapZone, not in "harvest", tap_world() on one walks instead of
##     opening a radial.
## Run: Godot --headless --path game --script res://tests/t_props2d.gd -> "[t_props2d] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const WATCHDOG_S := 120.0

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node3D
var _world: Node
var _rt: Node3D
var _props: Node
var PROPS: GDScript
var BG: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	var timer := create_timer(WATCHDOG_S)
	timer.timeout.connect(func () -> void:
		print("[t_props2d] FAIL watchdog %.0fs" % WATCHDOG_S)
		quit(2))
	PROPS = load("res://scripts/world/island_props.gd")
	BG = load("res://scripts/world/build_grid.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_props2d] FAIL %s" % what)

func _run() -> void:
	_test_mapping()
	_host = Node3D.new()
	_host.name = "TProps2dHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 6.0)
	_player = kit["player"]
	_world = root.get_node("World")
	_world.harvested.clear()
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	var kit_floor := _host.get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	await process_frame
	await physics_frame
	_rt = _world.runtime
	_props = _rt.get("props") if _rt != null else null
	_expect(_props != null, "the island has a props layer")
	if _props == null:
		_finish()
		return
	_test_layer_visuals()
	_test_collision_rules()
	_test_cliffs()
	await _test_clearable()
	_test_web_material()
	_test_not_clickable()
	_finish()

# ------------------------------------------------------------------ the mapping

## Every prop kind in props.json resolves to the painted art it says it draws as, and a kind is never
## left with neither a sprite nor a card (t_props already checks that; this one checks the resolution).
func _test_mapping() -> void:
	var kinds: Dictionary = PROPS.call("kinds")
	var mapped := 0
	var painted := 0
	for k in kinds.keys():
		if str(k).begins_with("_"):
			continue
		var row: Dictionary = kinds[k]
		var sid := str(row.get("sprite_kind", ""))
		var ids: Array = row.get("sprites", []) as Array
		var card := str(row.get("card", ""))
		_expect(sid != "" or not ids.is_empty() or card != "", "%s says which painted sprite it draws as" % k)
		var rows: Array = PROPS.call("card_sprites", k)
		_expect(not rows.is_empty() if (sid != "" or not ids.is_empty()) else true,
			"%s resolves to at least one painted sprite (%d)" % [k, rows.size()])
		if rows.is_empty():
			continue
		mapped += 1
		painted += rows.size()
		for r in rows:
			var file := str((r as Dictionary).get("file", ""))
			_expect(file.begins_with("res://") and ResourceLoader.exists(file), "%s's sprite file exists (%s)" % [k, file])
			var px: Array = (r as Dictionary).get("px", []) as Array
			var pivot: Array = (r as Dictionary).get("pivot", []) as Array
			_expect(px.size() >= 2 and pivot.size() >= 2, "%s's sprite carries px and a pivot" % k)
			_expect(float((r as Dictionary).get("height_m", 0.0)) > 0.0, "%s's sprite carries height_m" % k)
			_expect((r as Dictionary).has("blocks") and (r as Dictionary).has("destroyable"),
				"%s's sprite says blocks/destroyable" % k)
	# Every kind with painted art is mapped: the art is drawn, not left on disk.
	var srows: Array = PROPS.call("_sprite_rows")
	var prop_kinds: Dictionary = {}
	for r in srows:
		var kind := str((r as Dictionary).get("kind", ""))
		if kind.begins_with("prop:"):
			prop_kinds[kind] = true
	_expect(prop_kinds.size() >= 25, "the cut sheets carry the prop:* rows (%d kinds)" % prop_kinds.size())
	print("[t_props2d] mapping kinds=%d mapped=%d sprites=%d prop_kinds=%d" % [
		kinds.size(), mapped, painted, prop_kinds.size()])
	_expect(mapped >= 18, "most prop kinds draw as painted cards (%d of %d)" % [mapped, kinds.size()])
	# The variant is stable per position and mixes between neighbours.
	var a: Dictionary = PROPS.call("pick_card_sprite", "boulder", Vector3(3.0, 1.0, 4.0))
	var b: Dictionary = PROPS.call("pick_card_sprite", "boulder", Vector3(3.0, 1.0, 4.0))
	_expect(str(a.get("id", "")) == str(b.get("id", "")), "a prop draws the same sprite at the same spot")
	var seen := {}
	for i in 24:
		var row: Dictionary = PROPS.call("pick_card_sprite", "fern", Vector3(float(i) * 2.3, 0.0, float(i) * 1.7))
		seen[str(row.get("id", ""))] = true
	_expect(seen.size() >= 3, "neighbouring props mix sprite variants (%d of 24 spots)" % seen.size())
	# The rules: a big blocking card is a cliff; a small one breaks.
	var big: Dictionary = PROPS.call("card_sprites", "mesa_cliff")[0]
	var big_rules: Dictionary = PROPS.call("prop_rules", "mesa_cliff", big, 12.0)
	_expect(bool(big_rules["blocks"]), "a mesa blocks")
	_expect(not bool(big_rules["destroyable"]), "a mesa never breaks")
	var small: Dictionary = PROPS.call("card_sprites", "fern")[0]
	var small_rules: Dictionary = PROPS.call("prop_rules", "fern", small, 0.8)
	_expect(not bool(small_rules["blocks"]), "a fern does not block")
	_expect(bool(small_rules["destroyable"]), "a fern can be cleared")

# ------------------------------------------------------------------ the placed props

## No placed prop draws a 3D mesh: every row is a painted card and the card layer holds that many
## instances, each with live art.
func _test_layer_visuals() -> void:
	var rows: Array = _props.get("_rows")
	var cards: Node = _props.get("cards")
	_expect(cards != null, "the props layer builds its card layer")
	if cards == null:
		return
	var n := rows.size()
	var painted := 0
	var models := 0
	var missing := 0
	for r in rows:
		var row := r as Dictionary
		if bool(row.get("cleared", false)):
			continue
		if row.get("batch") != null or row.get("path", "") != "":
			models += 1
		var sprite: Dictionary = row.get("sprite", {}) as Dictionary
		if not sprite.is_empty() and ResourceLoader.exists(str(sprite.get("file", ""))):
			painted += 1
		else:
			missing += 1
	var instances := int(cards.call("instance_count"))
	var grey := int(cards.call("grey_cards"))
	var meshes := int(cards.call("model_meshes"))
	print("[t_props2d] props=%d painted=%d model_props=%d missing=%d cards=%d meshes=%d" % [
		n, painted, models, missing, instances, meshes])
	_expect(n >= 100, "the home island is scattered with props (%d)" % n)
	_expect(models == 0, "no prop draws a 3D model (%d do)" % models)
	_expect(painted == n, "every prop draws a painted card (%d of %d)" % [painted, n])
	_expect(instances == n, "the card layer holds one instance per prop (%d of %d)" % [instances, n])
	_expect(grey == 0, "no prop card is grey (art missing) (%d)" % grey)
	_expect(meshes == 0, "the card layer draws no 3D mesh (%d)" % meshes)
	# Nothing under the props layer is a batched 3D model any more.
	var veg := 0
	for c in _props.get_children():
		if c is VegBatch:
			veg += 1
	_expect(veg == 0, "props build no 3D VegBatch (%d)" % veg)
	# Cards are scenery, not resources: darker than the same art on a harvest node.
	_expect(cards.call("tint") != Color.WHITE, "prop cards carry a scenery tint")
	# A MultiMesh per sprite, not a node per prop: the batch count stays well under the prop count.
	_expect(cards.get_child_count() <= 260, "cards batch into cells (%d MultiMesh nodes for %d props)" % [cards.get_child_count(), n])

## Collision and destroyable follow the data, per placed prop.
func _test_collision_rules() -> void:
	var rows: Array = _props.get("_rows")
	var mismatched := 0
	var colliding := 0
	var destroyable := 0
	var indestructible := 0
	var blocked: Array = _props.call("blocked_cells")
	for r in rows:
		var row := r as Dictionary
		var kind := str(row.get("kind", ""))
		var sprite: Dictionary = row.get("sprite", {}) as Dictionary
		var height := float(row.get("height", 1.0))
		var rules: Dictionary = PROPS.call("prop_rules", kind, sprite, height)
		var want_blocks := bool(rules["blocks"])
		var want_destroy: bool = bool(rules["destroyable"])
		if bool(row.get("collide", false)) != want_blocks or bool(row.get("destroyable", true)) != want_destroy:
			mismatched += 1
			if mismatched <= 5:
				print("[t_props2d] rules mismatch %s collide=%s/%s destroyable=%s/%s h=%.1f" % [
					kind, row.get("collide", false), want_blocks, row.get("destroyable", true), want_destroy, height])
		if want_blocks:
			colliding += 1
			_expect(row.get("body") != null, "%s (%s) has a collider" % [kind, str(sprite.get("id", ""))])
		else:
			_expect(row.get("body") == null, "%s (%s) has no collider" % [kind, str(sprite.get("id", ""))])
		if want_destroy:
			destroyable += 1
		else:
			indestructible += 1
	_expect(mismatched == 0, "every prop's collision and destroyable follow sprites2d.json (%d differ)" % mismatched)
	print("[t_props2d] rules colliding=%d destroyable=%d indestructible=%d blocked_cells=%d" % [
		colliding, destroyable, indestructible, blocked.size()])
	_expect(colliding > 0 and destroyable > colliding, "both colliding (%d) and walk-through props are placed" % colliding)
	_expect(indestructible >= 0, "indestructible props (%d)" % indestructible)

## A big cliff cannot be destroyed; a walk-through prop never blocks a path or a build.
func _test_cliffs() -> void:
	var rows: Array = _props.get("_rows")
	var cliffs := 0
	for r in rows:
		var row := r as Dictionary
		if float(row.get("height", 0.0)) >= 4.0 and bool(row.get("collide", false)):
			cliffs += 1
			_expect(not bool(row.get("destroyable", true)), "a cliff %s at %.1f m is indestructible" % [
				str(row.get("kind", "")), float(row.get("height", 0.0))])
			_expect(not bool(_props.call("clear_at_tile", row["tile"])), "a cliff refuses clear_at_tile")
	print("[t_props2d] cliffs=%d (all indestructible)" % cliffs)
	# Placed by hand, on dry ground: a boulder blocks, reeds do not.
	var at := _dry_near(_rt._camp_pos, 8.0)
	_expect(bool(_props.call("add_prop", "boulder", at, 2.2)), "a boulder is placed for the blocker check")
	var bt: Vector2i = BG.call("tile_of", at)
	var blocked: Array = _props.call("blocked_cells")
	_expect(blocked.has(bt), "the boulder's tile is a path blocker")
	var at2 := _dry_near(at, 2.5)
	_expect(bool(_props.call("add_prop", "reeds", at2, 1.4)), "reeds are placed for the walk-through check")
	var rt2: Vector2i = BG.call("tile_of", at2)
	_expect(not (_props.call("blocked_cells") as Array).has(rt2), "the reeds' tile is not a path blocker")

## A clearable prop clears, its card is hidden, and its tile is remembered.
func _test_clearable() -> void:
	var at := _dry_near(_rt._camp_pos, 15.0)
	_expect(bool(_props.call("add_prop", "fallen_log", at, 3.0)), "a fallen log is placed to be cleared")
	var row := _last_row("fallen_log")
	if row.is_empty():
		return
	var idx := int(row.get("card_idx", -1))
	_expect(idx >= 0, "the cleared prop knows its card index (%d)" % idx)
	var ok := bool(_props.call("clear_at_tile", row["tile"]))
	await process_frame
	_expect(ok, "a fallen log clears")
	_expect(bool(_props.call("is_cleared", row["tile"])), "the cleared tile is remembered")
	var cards: Node = _props.get("cards")
	_expect(not bool(cards.call("is_shown", idx)), "the cleared prop's card is hidden")

func _last_row(kind: String) -> Dictionary:
	var arr: Array = _props.get("_rows")
	for i in range(arr.size() - 1, -1, -1):
		if str((arr[i] as Dictionary).get("kind", "")) == kind:
			return arr[i]
	return {}

func _dry_near(from: Vector3, min_d: float) -> Vector3:
	for i in 32:
		var ang := float(i) * TAU / 32.0
		var p := Vector3(from.x + cos(ang) * min_d, 0.0, from.z + sin(ang) * min_d)
		if _rt == null or not _rt.is_dry(p):
			continue
		if not (_props.call("prop_at_tile", BG.call("tile_of", p)) as Dictionary).is_empty():
			continue
		p.y = _rt.surface_y(p.x, p.z)
		return p
	return from + Vector3(min_d, 0.0, 0.0)

## Props are never clickable: no TapZone under any prop body, none in "harvest", and a tap that lands
## on a prop opens no radial (it is ground, so the survivor walks there).
func _test_not_clickable() -> void:
	var zones := 0
	var bodies := 0
	for c in get_nodes_in_group("props"):
		bodies += 1
		if c is Node:
			for n in (c as Node).find_children("*", "Area3D", true, false):
				zones += 1
	_expect(zones == 0, "no prop carries a TapZone (%d)" % zones)
	var harvest_props := 0
	for c in get_nodes_in_group("harvest"):
		if c.is_in_group("props") or c.get_parent() != null and (c.get_parent() as Node).is_in_group("props"):
			harvest_props += 1
	_expect(harvest_props == 0, "no prop is in the harvest group (%d)" % harvest_props)
	_expect(bodies > 0, "colliding props are in the 'props' group (%d)" % bodies)
	# A tap on a prop's own screen point is a ground tap: no radial opens.
	var cam := _player.get_viewport().get_camera_3d() if _player is Node3D else null
	if cam == null:
		_expect(false, "the test has a camera to tap through")
		return
	var rows: Array = _props.get("_rows")
	var best: Dictionary = {}
	var best_d := 1e9
	for r in rows:
		var row := r as Dictionary
		if bool(row.get("cleared", false)) or not bool(row.get("collide", false)):
			continue
		var d := (_player as Node3D).global_position.distance_to(row["pos"] as Vector3)
		if d < best_d:
			best_d = d
			best = row
	if best.is_empty():
		return
	var pos: Vector3 = best["pos"]
	var sp := cam.unproject_position(pos + Vector3(0, 0.4, 0))
	var radial_before := _radial_open()
	# The Game autoload publishes the pointer the tap ray runs through; it does not exist at compile
	# time of a --script file, so it is reached by node here.
	var game := root.get_node_or_null("Game")
	if game != null:
		game.set("pointer", sp)
	var hit: Variant = _player.call("debug_tap_screen", sp)
	var radial_after := _radial_open()
	print("[t_props2d] tap kind=%s hit=%s radial=%s" % [str(best.get("kind", "")), str(hit), str(radial_after)])
	_expect(radial_before == false, "no radial is open before the tap")
	_expect(not radial_after, "a tap on a prop opens no radial")
	_expect(str(hit) != "interact", "a tap on a prop is not an interaction (got %s)" % str(hit))

## Web/Compatibility holds only 1,024 shader-variable buffer items and reserves 16 for every geometry
## instance whose material declares an instance uniform, so with occlusion off (every web build) not
## one prop card may carry one - tall cards included. With occlusion on, only tall cards fade.
func _test_web_material() -> void:
	var kept := Occlusion.enabled
	var layer := PropCards.new()
	layer.name = "TProps2dWebCheck"
	root.add_child(layer)
	Occlusion.enabled = false
	var short_web: ShaderMaterial = layer.call("_material", false)
	var tall_web: ShaderMaterial = layer.call("_material", true)
	_expect(short_web != null and tall_web != null, "the card layer builds its short and tall materials")
	if short_web != null and tall_web != null:
		_expect(short_web.shader == tall_web.shader, "with occlusion off, tall cards share the fade-free shader")
		_expect(not _shader_uses_instance_uniform(short_web), "web: a short prop card has no instance uniform")
		_expect(not _shader_uses_instance_uniform(tall_web), "web: a tall prop card has no instance uniform either")
	Occlusion.enabled = true
	var native_layer := PropCards.new()
	native_layer.name = "TProps2dNativeCheck"
	root.add_child(native_layer)
	var native_short: ShaderMaterial = native_layer.call("_material", false)
	var native_tall: ShaderMaterial = native_layer.call("_material", true)
	if native_short != null and native_tall != null:
		_expect(not _shader_uses_instance_uniform(native_short), "native: a short prop card has no instance uniform")
		_expect(native_tall.shader != native_short.shader, "native: a tall prop card gets the fade body")
		_expect(_shader_uses_instance_uniform(native_tall), "native: a tall prop card keeps the occlusion fade")
	else:
		_expect(false, "the card layer builds its native materials")
	Occlusion.enabled = kept
	layer.queue_free()
	native_layer.queue_free()

func _shader_uses_instance_uniform(mat: ShaderMaterial) -> bool:
	var shader := mat.shader
	if shader == null:
		return false
	return _expand_includes(shader.code, "", {}).contains("instance uniform")

func _expand_includes(source: String, base: String, seen: Dictionary) -> String:
	var out := PackedStringArray()
	for line in source.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.begins_with("#include"):
			out.append(line)
			continue
		var first := trimmed.find('"')
		var last := trimmed.find('"', first + 1)
		if first < 0 or last <= first:
			out.append(line)
			continue
		var path := trimmed.substr(first + 1, last - first - 1)
		if not path.begins_with("res://"):
			path = base.path_join(path).simplify_path()
		if seen.has(path):
			continue
		seen[path] = true
		var included := FileAccess.get_file_as_string(path)
		out.append(_expand_includes(included, path.get_base_dir(), seen))
	return "\n".join(out)

func _radial_open() -> bool:
	for n in get_nodes_in_group("gather_radial"):
		if n is CanvasItem and (n as CanvasItem).visible:
			return true
	var r: Variant = _player.get("_gather_radial")
	if r is CanvasItem:
		return (r as CanvasItem).visible
	return false

func _finish() -> void:
	if _fails.is_empty():
		print("[t_props2d] PASS")
		quit(0)
	else:
		print("[t_props2d] FAIL %d check(s)" % _fails.size())
		quit(1)
