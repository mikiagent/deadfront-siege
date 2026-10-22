extends SceneTree
## SWITCH2D checks (owner 2026-10-21: "keep buildings 3D and make resources 2D but realistic").
## 1. Manifest: data/world/sprites2d.json parses; every nature family with painted sprites
##    (kind == family id) resolves to at least one sprite; each such row's PNG is imported. A node's
##    variant is stable for its position and mixes across positions.
## 2. Mapping: CardProp.visual_for() gives painted art where it exists, the family's BAKED card
##    where it does not, and never a 3D model; under resource_render "card" every harvest node on an
##    island draws a card (no VegBatch visual), and buildings stay 3D (a placed building has meshes,
##    no card).
## 3. A painted CardProp draws the PNG, is sized from height_m and the PNG's aspect, and puts the
##    manifest's pivot pixel on its ground point.
## 4. Facing: the card follows the active Camera3D at any angle (read from the camera, never a
##    constant); the camera's [shader_globals] publish the angle; project.godot has no [card2d].
## Run: Godot --headless --path game --script res://tests/t_switch2d.gd  -> "[t_switch2d] PASS".

const SPRITES_PATH := "res://data/world/sprites2d.json"
const SHADER_PATH := "res://shaders/card_sway.gdshader"
## Families a climate scatter actually plants (the painted set the owner has cut so far).
## VinePlant is deliberately absent: the only vine art cut is prop:vine_hanging (a hanging curtain) and
## a sapling, neither of which is a ground vine plant, so it falls back to its painted card.
const PAINTED_QUICK := ["PalmTree", "Plant", "WildGrass", "MangoBush", "HerbPlant",
	"GraniteBoulder", "WoodLog", "WoodLog_Moss", "clay", "TreeStump"]
## A family with no painted art: must fall back to its baked card, never a model.
const NO_PAINTED := "CommonTree"

var failures: Array[String] = []
var _started := false
var _quit_at := 0
var host: Node3D
var player
var CP: GDScript
var world: Node

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_quit_at = Time.get_ticks_msec() + 60000
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_switch2d] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	world = get_root().get_node("World")
	CP = load("res://scripts/world/card_prop.gd")
	if Time.get_ticks_msec() > _quit_at:
		print("[t_switch2d] FAIL watchdog: setup took too long")
		quit(1)
		return
	_test_manifest()
	_test_mapping()
	_test_painted_card()
	await _test_facing()
	await _test_island()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_switch2d] PASS")
		quit(0)
	else:
		print("[t_switch2d] FAIL count=%d" % failures.size())
		quit(1)

# ---------------------------------------------------------------- 1. manifest

func _test_manifest() -> void:
	var f := FileAccess.open(SPRITES_PATH, FileAccess.READ)
	_expect(f != null, "sprites2d.json is readable")
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_expect(parsed is Dictionary, "sprites2d.json is an object")
	if not parsed is Dictionary:
		return
	var sprites: Array = CP.sprites()
	_expect(sprites.size() >= 50, "the manifest lists the cut sprites (%d)" % sprites.size())
	var fams: Dictionary = get_root().get_node("Data").nature_families
	var painted_families := 0
	var missing_png := 0
	for family: String in fams.keys():
		var rows: Array = CP.sprites_for_family(family)
		if rows.is_empty():
			continue
		painted_families += 1
		var loaded := 0
		for row: Dictionary in rows:
			if ResourceLoader.exists(str(row.get("file", ""))):
				loaded += 1
			else:
				missing_png += 1
		_expect(loaded >= 1, "%s: %d painted sprite(s) imported" % [family, loaded])
	_expect(painted_families >= 8, "%d families have painted sprites (%d)" % [painted_families, painted_families])
	_expect(missing_png == 0, "every painted sprite's PNG exists (%d missing)" % missing_png)
	for family in PAINTED_QUICK:
		_expect(not CP.sprites_for_family(family).is_empty(), "%s has painted sprites" % family)
	# A node's variant is stable; different ground points mix the variants.
	var pos := Vector3(12.34, 0.0, -56.78)
	var a := str(CP.pick_painted("Plant", pos).get("id", ""))
	var b := str(CP.pick_painted("Plant", pos).get("id", ""))
	_expect(a != "" and a == b, "the variant is stable for a node position (%s)" % a)
	var seen: Dictionary = {}
	for i in 200:
		var p := Vector3(float(i) * 3.1, 0.0, float(i) * -1.7)
		seen[str(CP.pick_painted("Plant", p).get("id", ""))] = true
	_expect(seen.size() >= 3, "positions mix the variants (%d different sprites over 200 nodes)" % seen.size())
	# Every row the manifest gives a nature family id is one of the loaded families, not a prop/icon.
	var unknowns: Dictionary = {}
	for row: Dictionary in sprites:
		var kind := str(row.get("kind", ""))
		if kind.contains(":"):
			continue  # prop:*, icon:* - not a nature family
		if kind == "unused":
			continue
		if not fams.has(kind):
			unknowns[kind] = true
	_expect(unknowns.is_empty(), "every painted family id is in nature_manifest (%s)" % str(unknowns.keys()))

# ---------------------------------------------------------------- 2. mapping

func _test_mapping() -> void:
	var fams: Dictionary = get_root().get_node("Data").nature_families
	var no_art: Array[String] = []
	for family: String in fams.keys():
		var role := str((fams[family] as Dictionary).get("role", ""))
		var vis: Dictionary = CP.visual_for(family, Vector3(3, 0, 7))
		var kind := str(vis.get("kind", ""))
		_expect(kind != "model" and kind != "batched", "%s: never resolves to a 3D model" % family)
		var painted: bool = not CP.sprites_for_family(family).is_empty()
		if painted:
			_expect(kind == "painted", "%s: painted art is preferred (%s)" % [family, kind])
			_expect(ResourceLoader.exists(str((vis.get("row", {}) as Dictionary).get("file", ""))), "%s: its sprite's PNG is imported" % family)
		else:
			_expect(kind == "card" or kind == "painted", "%s: no own art -> a baked card or a role sprite (%s)" % [family, kind])
			if kind == "card":
				var cid := str(vis.get("card", ""))
				_expect(cid != "" and CP.baked(cid), "%s: card %s is baked" % [family, cid])
			else:
				_expect(ResourceLoader.exists(str((vis.get("row", {}) as Dictionary).get("file", ""))), "%s: its role sprite exists" % family)
			no_art.append(family)
	var vis_default: Dictionary = CP.visual_for(NO_PAINTED, Vector3(1, 0, 2))
	_expect(str(vis_default.get("kind", "")) == "card", "%s falls back to its baked card" % NO_PAINTED)
	_expect(CP.baked(str(vis_default.get("card", ""))), "%s's card is baked" % NO_PAINTED)
	# data/world/sprites2d_map.json: a family with no art of its own borrows a named sprite.
	var vis_stump: Dictionary = CP.visual_for("tree_stump", Vector3(1, 0, 2))
	_expect(str(vis_stump.get("kind", "")) == "painted", "tree_stump draws the map's stump sprite")
	var want_stump := str(((CP.sprite_map().get("families", {}) as Dictionary).get("tree_stump", {}) as Dictionary).get("sprite", ""))
	_expect(want_stump != "" and str((vis_stump.get("row", {}) as Dictionary).get("id", "")) == want_stump,
		"the override names the stump sprite (%s)" % want_stump)
	var map: Dictionary = CP.sprite_map()
	_expect(not map.is_empty(), "sprites2d_map.json is read")
	var vis_palm: Dictionary = CP.visual_for("PalmTree", Vector3(1, 0, 2))
	_expect(str(vis_palm.get("kind", "")) == "painted", "PalmTree draws a painted sprite")
	# The shader carries both shading paths and the camera globals; no bare pitch/yaw constants.
	var sh := load(SHADER_PATH) as Shader
	_expect(sh != null, "card_sway.gdshader compiles")
	if sh:
		var code := (sh as Shader).code
		_expect(code.contains("shading_mode"), "the shader can draw painted (flat-normal) art")
		_expect(code.contains("camera.gdshaderinc"), "the card takes the camera's global parameters")
		_expect(code.contains("parallax_strength") and code.contains("camera_focus"), "the parallax reads the camera globals")
		for bad in ["45.0", "35.264", "38.7"]:
			_expect(not code.contains(bad), "the shader hard-codes no camera angle (%s)" % bad)
	var src := FileAccess.get_file_as_string("res://scripts/world/card_prop.gd")
	for bad in ["35.264", "38.7", "45.0", "card2d/parallax_strength"]:
		_expect(not src.contains(bad), "card_prop.gd hard-codes no camera angle or [card2d] setting (%s)" % bad)
	var proj := FileAccess.get_file_as_string("res://project.godot")
	_expect(not proj.contains("[card2d]"), "project.godot no longer has the [card2d] section")
	for g in ["camera_focus", "camera_pitch_deg", "camera_yaw_deg", "camera_distance", "parallax_strength"]:
		_expect(proj.contains(g), "project.godot still publishes %s" % g)
	# rules.json switches the default.
	var rules: Dictionary = get_root().get_node("Data").world_rules
	_expect(str(rules.get("resource_render", "")) == "card", "rules.json resource_render is \"card\"")
	_expect(str(rules.get("_resource_render_note", "")) != "", "rules.json explains resource_render")

# ---------------------------------------------------------------- 3. painted card

func _test_painted_card() -> void:
	host = Node3D.new()
	host.name = "TSwitch2D"
	get_root().add_child(host)
	var rows: Array = CP.sprites_for_family("PalmTree")
	_expect(rows.size() > 0, "a palm sprite exists")
	if rows.is_empty():
		return
	var row: Dictionary = rows[0]
	var h := 9.0
	var card = CP.new()
	host.add_child(card)
	card.position = Vector3(0.0, 0.0, 0.0)
	var ok: bool = card.setup_painted(row, h)
	_expect(ok, "a painted palm card sets up")
	if not ok:
		card.queue_free()
		return
	var mi: MeshInstance3D = card.get_node_or_null("Card")
	_expect(mi != null, "the painted card has its quad")
	if mi == null:
		return
	var mat := mi.material_override as ShaderMaterial
	_expect(mat != null, "the painted card has its material")
	var tex: Texture2D = mat.get_shader_parameter("albedo_tex") if mat else null
	_expect(tex != null, "the painted card draws a texture")
	var png: Texture2D = load(str(row.get("file", ""))) as Texture2D
	_expect(png != null and tex != null and tex.get_width() == png.get_width() and tex.get_height() == png.get_height(),
		"the texture is the manifest's PNG (%dx%d)" % [tex.get_width() if tex else 0, tex.get_height() if tex else 0])
	_expect(int(mat.get_shader_parameter("shading_mode")) == CP.SHADE_PAINTED, "a painted card is lit flat, not unlit")
	var px: Array = row.get("px", [1, 1])
	var want := Vector2(h * float(px[0]) / float(px[1]), h)
	var quad := mi.mesh as PlaneMesh
	_expect(quad != null and quad.size.is_equal_approx(want), "the quad is %.2f x %.2f m for %.1f m of art (aspect of the PNG)" % [want.x, want.y, h])
	var pivot: Vector2 = CP.sprite_pivot_uv(row)
	_expect(pivot.is_equal_approx(Vector2(float(row["pivot"][0]) / float(px[0]), float(row["pivot"][1]) / float(px[1]))),
		"the pivot is the manifest's pivot pixel (%s)" % pivot)
	_expect(mat.get_shader_parameter("pivot_uv") == pivot, "the shader gets the manifest pivot")
	# The pivot pixel sits on the node's ground point for the camera basis the card used.
	var b: Basis = CP.default_basis()
	var pivot_world: Vector3 = card.global_position + mi.position + b.x.normalized() * ((pivot.x - 0.5) * want.x) + b.y.normalized() * ((0.5 - pivot.y) * want.y)
	_expect(pivot_world.distance_to(card.global_position) < 0.02, "the pivot pixel is the ground point (%.3f m off)" % pivot_world.distance_to(card.global_position))
	# A rock sprite does not sway; a palm does.
	_expect(float(mat.get_shader_parameter("sway_amplitude")) > 0.0, "a palm card sways")
	var rock_rows: Array = CP.sprites_for_family("GraniteBoulder")
	if rock_rows.size() > 0:
		var rock = CP.new()
		host.add_child(rock)
		_expect(rock.setup_painted(rock_rows[0] as Dictionary, 2.0), "a boulder painted card sets up")
		var rmat := (rock.get_node("Card") as MeshInstance3D).material_override as ShaderMaterial
		_expect(is_equal_approx(float(rmat.get_shader_parameter("sway_amplitude")), 0.0), "a boulder card does not sway")
		rock.queue_free()
	# A card built without a camera stands at the published camera angle.
	var b2: Basis = CP.default_basis()
	_expect(not b2.is_equal_approx(Basis.IDENTITY), "the fallback basis comes from the camera globals, not identity")
	card.queue_free()

# ---------------------------------------------------------------- 4. facing

func _test_facing() -> void:
	var rows: Array = CP.sprites_for_family("Plant")
	_expect(rows.size() > 0, "a plant sprite exists")
	if rows.is_empty():
		return
	var card = CP.new()
	host.add_child(card)
	card.global_position = Vector3(4.0, 0.0, -3.0)
	_expect(card.setup_painted(rows[0] as Dictionary, 1.0), "the facing card sets up")
	var cam := Camera3D.new()
	cam.name = "Switch2DCam"
	host.add_child(cam)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 4.3
	cam.current = true
	# Two angles nothing in the card knows: a low, yawed perspective camera, then a high one.
	for euler in [Vector3(-38.7, 45.0, 0.0), Vector3(-14.0, 118.0, 0.0), Vector3(-55.0, -20.0, 0.0)]:
		cam.global_position = Vector3(30.0, 25.0, 44.0)
		cam.rotation_degrees = euler
		cam.look_at(Vector3.ZERO, Vector3.UP)
		await process_frame
		await process_frame
		var mi := card.get_node_or_null("Card") as MeshInstance3D
		var normal: Vector3 = mi.global_basis.orthonormalized().z
		var to_cam: Vector3 = -cam.global_basis.z
		var err := rad_to_deg(acos(clampf(absf(normal.dot(to_cam)), 0.0, 1.0)))
		_expect(err < 0.5, "the card faces a camera at %s (%.2f deg off)" % [euler, err])
		var q: Basis = mi.global_basis.orthonormalized()
		var cb: Basis = cam.global_basis.orthonormalized()
		_expect(q.x.is_equal_approx(cb.x) and q.y.is_equal_approx(cb.y), "the card's screen axes are the camera's at %s" % euler)
		cam.current = false
		await process_frame
		cam.current = true
	cam.current = false
	card.queue_free()
	cam.queue_free()

# ---------------------------------------------------------------- 5. islands and buildings

func _test_island() -> void:
	var rules: Dictionary = get_root().get_node("Data").world_rules
	var keep: Variant = rules.get("resource_render", "card")
	var IS: GDScript = load("res://scripts/world/island_scatter.gd")
	rules["resource_render"] = "card"
	_expect(IS.cards_enabled(), "with resource_render=card the card path is on")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	await process_frame
	if player == null:
		player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
		host.add_child(player)
		player.global_position = world.runtime._camp_pos + Vector3(0, 1, 0)
		await process_frame
	var painted := 0
	var baked := 0
	var nodes := 0
	var with_mesh := 0
	for node in get_nodes_in_group("harvest"):
		nodes += 1
		var card = node.get("_card")
		if card == null or not is_instance_valid(card):
			continue
		if card.has_meta(&"sprite"):
			painted += 1
		else:
			baked += 1
		if node.get("_batch") != null:
			with_mesh += 1
	_expect(nodes > 20, "the home island has resource nodes (%d)" % nodes)
	_expect(painted > 0, "painted cards are drawn (%d)" % painted)
	_expect(baked > 0, "families without painted art keep their baked card (%d)" % baked)
	_expect(with_mesh == 0, "no resource node keeps a 3D batch visual under card mode (%d)" % with_mesh)
	_expect(painted + baked == nodes, "every resource node is a card (%d painted + %d baked = %d nodes)" % [painted, baked, nodes])
	# Buildings stay 3D: a placed building (the camp's fire/stations) has meshes and no card.
	var buildings := 0
	var cards_on_buildings := 0
	for b in get_nodes_in_group("placed_building"):
		buildings += 1
		if b.find_children("*", "CardProp", true, false).size() > 0:
			cards_on_buildings += 1
	_expect(buildings > 0, "the island has placed buildings (%d)" % buildings)
	_expect(cards_on_buildings == 0, "no building draws as a card (%d cards on buildings)" % cards_on_buildings)
	# Switching back gives the old 3D look: cards gone, batched models back. That proves the rule, not a
	# hard-coded look, decides what a resource draws.
	rules["resource_render"] = "model"
	_expect(not IS.cards_enabled(), "with resource_render=model the card path is off")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	await process_frame
	var model_cards := 0
	var model_batches := 0
	for node in get_nodes_in_group("harvest"):
		if node.get("_card") != null:
			model_cards += 1
		if node.get("_batch") != null:
			model_batches += 1
	_expect(model_cards == 0, "under model mode no resource draws a card (%d)" % model_cards)
	_expect(model_batches > 20, "under model mode resources draw the batched 3D props (%d)" % model_batches)
	# The default (no --models) is the card path.
	rules["resource_render"] = keep
	_expect(str(keep) == "card", "the shipped rule is \"card\" (was %s)" % str(keep))
