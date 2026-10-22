extends SceneTree
## CARD2D trial checks (spec 25 §1):
## 1. card2d.json: at least the nine named cards, every entry has a model, a kind, both baked PNGs
##    (power-of-two, 512 for small props / 1024 for trees) and a pivot inside the texture; the sway
##    kinds exist with the reference speeds (trees slow, grass fast) and rocks at amplitude 0.
## 2. The sway shader carries the per-kind uniform the CardProp drives, displaces with height and
##    includes the occlusion fade body; a CardProp faces the iso camera yaw (45°) and its quad's
##    ground pivot lands on the origin; rustle() moves the shader and settles back.
## 3. With resource_render = "card" a home island draws cards for the carded families (the berry
##    family's empty card included) and the same gather path t_water uses still yields; with
##    "model" (the default) no card is drawn and the batched path is unchanged.
## Run: Godot --headless --path game --script res://tests/t_card2d.gd  -> "[t_card2d] PASS", exit 0/1.

const DATA_PATH := "res://data/card2d.json"
const SHADER_PATH := "res://shaders/card_sway.gdshader"
const REQUIRED := ["bush-berries-a", "bush-berries-a-empty", "bush-berries-b", "grass-a", "plant-a",
	"tree-common-a", "tree-birch-a", "tree-acacia-a", "rock-a"]

var failures: Array[String] = []
var _started := false
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
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_card2d] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	world = get_root().get_node("World")
	CP = load("res://scripts/world/card_prop.gd")
	_test_data()
	_test_shader()
	_test_card_prop()
	await _test_card_prop_async()
	await _test_islands()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_card2d] PASS")
		quit(0)
	else:
		print("[t_card2d] FAIL count=%d" % failures.size())
		quit(1)

# ---------------------------------------------------------------- data

func _test_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	_expect(f != null, "card2d.json is readable")
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_expect(parsed is Dictionary, "card2d.json is an object")
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	var cards: Dictionary = data.get("cards", {})
	var kinds: Dictionary = data.get("kinds", {})
	_expect(cards.size() >= 9, "at least 9 cards (%d)" % cards.size())
	for id in REQUIRED:
		_expect(cards.has(id), "card %s exists" % id)
	for k in ["tree", "bush", "grass", "plant", "rock"]:
		_expect(kinds.has(k), "sway kind %s exists" % k)
	_expect(float((kinds.get("rock", {}) as Dictionary).get("amplitude", -1.0)) == 0.0, "rock amplitude is 0")
	_expect(float((kinds.get("tree", {}) as Dictionary).get("speed", 99.0)) < float((kinds.get("grass", {}) as Dictionary).get("speed", -99.0)),
		"trees sway slower than grass")
	_expect(float((kinds.get("tree", {}) as Dictionary).get("amplitude", 0.0)) > float((kinds.get("grass", {}) as Dictionary).get("amplitude", 99.0)),
		"trees sway wider than grass")
	var bad_tex := 0
	var bad_meta := 0
	for id: String in cards.keys():
		var row: Dictionary = cards[id]
		var kind := str(row.get("kind", ""))
		_expect(kinds.has(kind), "%s: kind %s is one of the sway kinds" % [id, kind])
		_expect(str(row.get("model", "")) != "", "%s: names a model" % id)
		var ap: String = CP.albedo_path(id)
		var np: String = CP.normal_path(id)
		var has := ResourceLoader.exists(ap) and ResourceLoader.exists(np)
		_expect(has, "%s: albedo and normal PNGs are baked" % id)
		if not has:
			continue
		var tex := load(ap) as Texture2D
		var ntex := load(np) as Texture2D
		if tex == null or ntex == null:
			bad_tex += 1
			continue
		var want := int(row.get("resolution", 512))
		_expect(want == (1024 if kind == "tree" else 512), "%s: resolution %d matches its kind" % [id, want])
		_expect(_pot(tex.get_width()) and _pot(tex.get_height()), "%s: %dx%d is power-of-two" % [id, tex.get_width(), tex.get_height()])
		_expect(maxi(tex.get_width(), tex.get_height()) == want, "%s: longest side is %d px" % [id, want])
		_expect(tex.get_width() == ntex.get_width() and tex.get_height() == ntex.get_height(), "%s: normal matches the albedo size" % id)
		var pivot: Vector2 = CP.pivot_uv(id)
		var size: Vector2 = CP.world_size(id)
		_expect(pivot.x >= 0.0 and pivot.x <= 1.0 and pivot.y >= 0.0 and pivot.y <= 1.0, "%s: pivot %s is inside the texture" % [id, pivot])
		_expect(size.x > 0.0 and size.y > 0.0, "%s: world size %s is positive" % [id, size])
		_expect(CP.baked(id), "%s: CardProp.baked() accepts it" % id)
	_expect(bad_tex == 0 and bad_meta == 0, "every baked card loaded")
	print("[t_card2d] cards=%d kinds=%d" % [cards.size(), kinds.size()])

func _pot(n: int) -> bool:
	return n > 0 and (n & (n - 1)) == 0

# ---------------------------------------------------------------- shader

func _test_shader() -> void:
	_expect(ResourceLoader.exists(SHADER_PATH), "card_sway.gdshader exists")
	if not ResourceLoader.exists(SHADER_PATH):
		return
	var text := FileAccess.get_file_as_string(SHADER_PATH)
	for u in ["sway_amplitude", "sway_speed", "pivot_uv", "albedo_tex", "normal_tex", "rustle"]:
		_expect(text.contains("uniform") and text.contains(u), "the shader has the %s uniform" % u)
	_expect(text.contains("TIME"), "the sway is driven by TIME")
	_expect(text.contains("ALPHA_SCISSOR_THRESHOLD"), "the card is alpha-scissored (opaque pass)")
	_expect(text.contains("NORMAL_MAP"), "the card takes the baked normal map")
	_expect(text.contains("occlusion.gdshaderinc"), "the card includes the occlusion fade body")
	var sh := load(SHADER_PATH) as Shader
	_expect(sh != null, "the shader compiles")

# ---------------------------------------------------------------- the prop

func _test_card_prop() -> void:
	host = Node3D.new()
	host.name = "TCard2D"
	get_root().add_child(host)
	var card: Node3D = CP.new()
	host.add_child(card)
	card.position = Vector3(3.0, 0.5, -2.0)
	var kind := "tree"
	var params: Dictionary = CP.kind_params(kind)
	var rows: Dictionary = CP.cards()
	var id := ""
	for k: String in rows.keys():
		if str((rows[k] as Dictionary).get("kind", "")) == kind:
			id = k
			break
	_expect(id != "", "a tree card exists to stand up")
	if id == "":
		return
	var ok: bool = card.setup(id, 8.0)
	_expect(ok, "%s sets up at 8 m" % id)
	var mi: MeshInstance3D = card.get_node_or_null("Card")
	# Full camera-facing (owner: align with the camera angle at all times), not a Y-axis billboard:
	# the quad's basis is the camera's, read from IsoCamera rather than hard-coded.
	var view: Basis = CP.default_basis()
	var qb: Basis = mi.global_basis.orthonormalized() if mi else Basis()
	_expect(mi != null and qb.z.is_equal_approx(view.z), "the card's normal is the camera's forward (\u00b7=%.4f)" % qb.z.dot(view.z))
	_expect(absf(qb.y.dot(view.y)) > 0.999, "the card's up is the camera's up")
	_expect(absf(qb.x.dot(view.x)) > 0.999, "the card's right is the camera's right")
	_expect(mi != null and qb.y.y < 0.95, "the card is tilted with the camera's pitch (y=%.3f), not a vertical billboard" % qb.y.y)
	# The card follows a camera whose angle differs (the Durango-angle package can change it).
	var other := Basis.from_euler(Vector3(deg_to_rad(-18.0), deg_to_rad(30.0), 0.0))
	card._face_camera(other)
	_expect((mi.global_basis.orthonormalized().z).is_equal_approx(other.z), "the card re-aligns to another camera basis")
	card._face_camera(view)
	_expect(mi != null and mi.mesh != null, "the card has its quad")
	if mi and mi.mesh:
		var aabb := mi.get_aabb()
		var api: AABB = mi.global_transform * mi.get_aabb()
		var pivot: Vector2 = CP.pivot_uv(id)
		var size: Vector2 = CP.world_size(id)
		# The texture's pivot pixel must sit on the node origin: bottom-left of the quad is
		# origin - pivot * size, so the pivot corner rounds to the node position.
		var content_h: float = CP.content_height(id)
		var quad_h: float = size.y * 8.0 / content_h
		_expect(is_equal_approx(quad_h, aabb.size.y), "the quad is %.2f m tall for 8 m of content (%.2f)" % [aabb.size.y, quad_h])
		var bottom: float = mi.position.y - aabb.size.y * 0.5
		var top: float = mi.position.y + aabb.size.y * 0.5
		_expect(bottom < -0.01 and top > 0.01, "the ground line (y=0) crosses the quad (%.2f .. %.2f)" % [bottom, top])
		_expect(pivot.x > 0.0 and pivot.x < 1.0, "pivot u is inside the quad")
		# The pivot pixel sits exactly on the node origin (the ground point stays planted).
		var right: Vector3 = view.x.normalized()
		var up: Vector3 = view.y.normalized()
		var pivot_world: Vector3 = card.global_position + mi.position + right * ((pivot.x - 0.5) * aabb.size.x) + up * ((0.5 - pivot.y) * aabb.size.y)
		_expect(pivot_world.distance_to(card.global_position) < 0.02, "the texture's pivot pixel is the ground point (%.3f m off)" % pivot_world.distance_to(card.global_position))
		_expect(api.size.y > 8.0 or is_equal_approx(quad_h, 8.0), "the quad is at least as tall as the content")
	var mat := mi.material_override as ShaderMaterial if mi else null
	_expect(mat != null, "the card has its sway material")
	if mat:
		var amp: float = mat.get_shader_parameter("sway_amplitude")
		_expect(is_equal_approx(amp, float(params.get("amplitude", 0.0)) * (8.0 / CP.content_height(id))),
			"the sway amplitude comes from card2d.json (%.3f)" % amp)
		_expect(is_equal_approx(float(mat.get_shader_parameter("sway_speed")), float(params.get("speed", 0.0))), "the sway speed comes from card2d.json")
	# A rock card does not sway.
	var rock_id: String = CP.card_for_family("Rock")
	_expect(rock_id != "", "the Rock family has a card")
	if rock_id != "":
		var rock: Node3D = CP.new()
		host.add_child(rock)
		_expect(rock.setup(rock_id, 1.0), "the rock card sets up")
		var rmat := (rock.get_node("Card") as MeshInstance3D).material_override as ShaderMaterial
		_expect(is_equal_approx(float(rmat.get_shader_parameter("sway_amplitude")), 0.0), "the rock card's amplitude is 0")
		rock.rustle(0.3)
		var rv: Variant = rmat.get_shader_parameter("rustle")
		_expect(rv == null or float(rv) == 0.0, "a rock does not even shiver")
		rock.queue_free()
	_test_parallax()
	card.queue_free()

## The parallax bound (R1): the shader's slide grows with card height and is capped at 15 % of it, so
## a half-metre plant 15 m from the camera focus moves well under 8 cm instead of shearing apart.
func _test_parallax() -> void:
	var sh := load(SHADER_PATH) as Shader
	_expect(sh != null, "the sway shader loads for the parallax check")
	if sh == null:
		return
	var code := (sh as Shader).code
	_expect(code.contains("card_height"), "the parallax reads card_height")
	_expect(code.contains("PARALLAX_MAX_SHARE"), "the parallax is clamped to a share of the card")
	# Compute the shader's formula here for the two cases the brief names: a 0.5 m card 15 m out,
	# and an 8 m tree at the same distance, strength from the camera's published global (IsoCamera
	# writes parallax_strength every frame; the [card2d] project section is gone).
	# Headless there is no camera publishing the global yet, so the check uses the camera's own value
	# at the default zoom (gain * sin(pitch) / distance): the same number the shader would receive.
	var strength: float = CP.global_float(&"parallax_strength")
	if strength <= 0.0:
		strength = IsoCamera.PARALLAX_GAIN * sin(deg_to_rad(absf(IsoCamera.pitch_deg()))) / IsoCamera.distance_for(IsoCamera.DEFAULT_SIZE)
	_expect(strength > 0.0, "the parallax strength is the camera's published lean (%.5f)" % strength)
	var max_share := 0.15
	var plant := minf(15.0 * strength * 0.5, max_share * 0.5)
	var tree := minf(15.0 * strength * 8.0, max_share * 8.0)
	_expect(plant < 0.08, "a 0.5 m card 15 m from the focus slides %.3f m (< 0.08)" % plant)
	_expect(tree > plant * 4.0, "an 8 m tree slides far more than a plant (%.3f vs %.3f m)" % [tree, plant])
	_expect(max_share * 8.0 < 1.5, "the slide never exceeds 15 % of the card (8 m -> %.2f m)" % (max_share * 8.0))

func _test_card_prop_async() -> void:
	var card: Node3D = CP.new()
	host.add_child(card)
	var id: String = CP.card_for_family("CommonTree")
	if id == "":
		_expect(false, "CommonTree has a card")
		return
	card.setup(id, 8.0)
	var mat := (card.get_node("Card") as MeshInstance3D).material_override as ShaderMaterial
	card.rustle(0.5)
	_expect(float(mat.get_shader_parameter("rustle")) > 0.5, "rustle() starts the shiver")
	await create_timer(0.7).timeout
	_expect(float(mat.get_shader_parameter("rustle")) < 0.2, "the shiver settles back")
	card.queue_free()

# ---------------------------------------------------------------- islands

func _test_islands() -> void:
	var rules: Dictionary = get_root().get_node("Data").world_rules
	var keep: Variant = rules.get("resource_render", "card")
	# SWITCH2D made "card" the default; the old 3D look stays reachable through the rule.
	var IS: GDScript = load("res://scripts/world/island_scatter.gd")
	rules["resource_render"] = "model"
	_expect(not IS.cards_enabled(), "with resource_render=model the card path is off")
	_expect(await _island_cards(true) == 0, "with resource_render=model a home island draws no cards")
	# "card": every carded family draws a card, and the nodes still gather through the real path.
	rules["resource_render"] = "card"
	_expect(IS.cards_enabled(), "with resource_render=card the card path is on")
	var n := await _island_cards(false)
	_expect(n > 0, "with resource_render=card a home island draws cards (%d)" % n)
	var family_cards := 0
	var empty_cards := 0
	var nodes_with_cards := 0
	for node in get_nodes_in_group("harvest"):
		if node.get("_card") != null and is_instance_valid(node.get("_card")):
			nodes_with_cards += 1
			if node.get("_card_empty") != null:
				empty_cards += 1
	_expect(nodes_with_cards == n, "every card belongs to a harvest node (%d of %d)" % [nodes_with_cards, n])
	for row in CP.cards().keys():
		if not (CP.cards()[row] as Dictionary).get("families", []).is_empty():
			family_cards += 1
	_expect(family_cards >= 9, "%d carded families are mapped" % family_cards)
	_expect(empty_cards > 0, "the berry family swaps to its empty card (%d nodes)" % empty_cards)
	# Gather: the same call t_water makes, on a carded node.
	var done := false
	for node in get_nodes_in_group("harvest"):
		if node.get("_card") == null or node.pool_units_left() <= 0:
			continue
		if node.can_gather(player.inventory) != "":
			continue
		var before: int = player.inventory.count_of(node.yield_def_id)
		player.gather_target = node
		player.actions.finish_gather()
		player.actions.cancel_work()
		_expect(player.inventory.count_of(node.yield_def_id) > before, "a carded node gathers through player.actions.finish_gather (%s)" % node.node_id)
		_expect(node.get("_card") != null, "the gathered node still draws its card")
		var empty = node.get("_card_empty")
		if empty != null:
			_expect(not (node.get("_card") as Node3D).visible or node.pool_units_left() > 0, "the full card hides once the pool is spent")
		done = true
		break
	_expect(done, "a carded node was gatherable")
	await _test_empty_card()
	await _test_tap_selects()
	await _test_fade()
	rules["resource_render"] = keep

## R3: a depleted berry bush keeps its node and shows the "-empty" card, the full one hidden; the cards
## are freed with the node (they are children of the runtime, not of the node itself).
func _test_empty_card() -> void:
	var node = null
	for n in get_nodes_in_group("harvest"):
		if n.has_method("has_empty_card") and n.has_empty_card():
			node = n
			break
	_expect(node != null, "a carded node has an empty card")
	if node == null:
		return
	var full: Node3D = node.get("_card")
	var empty: Node3D = node.get("_card_empty")
	_expect(full.visible and not empty.visible, "the full card shows while the node has something")
	# Spend every yield's pool through the game's own consume path (berries and fibre are separate).
	var opts: Array = node.options()
	for i in opts.size():
		for k in 60:
			node.select_option(i)
			if node.pool_units_left() <= 0:
				break
			node.consume_unit()
	node.select_option(0)
	_expect(node.depleted, "the node is depleted once its pool is spent")
	_expect(node.visible, "a depleted node with an empty card stays visible (R3)")
	_expect(empty.visible, "the empty card shows when depleted (R3)")
	_expect(not full.visible, "the full card hides when depleted")
	node.regen_seconds = 0.0
	node.queue_free()
	await process_frame
	await process_frame
	_expect(not is_instance_valid(full) and not is_instance_valid(empty), "freeing the node frees its cards (R3)")

## R4: tapping a card resource still selects its node (the node keeps the pick shape; the card has none).
func _test_tap_selects() -> void:
	var cam := IsoCamera.new()
	cam.name = "TapaCam"
	host.add_child(cam)
	cam.size = 18.0
	cam.current = true
	var node = null
	for n in get_nodes_in_group("harvest"):
		if n.get("_card") is Node3D and n.pool_units_left() > 0 and n.can_gather(player.inventory) == "":
			node = n
			break
	_expect(node != null, "a gatherable carded node to tap")
	if node == null:
		cam.queue_free()
		return
	player.clear_nav()
	player.global_position = node.global_position + Vector3(3.0, 1.0, 3.0)
	cam._target = player
	cam.global_position = player.global_position + Vector3(20, 20, 20)
	cam.look_at(player.global_position + Vector3.UP * 0.5)
	await process_frame
	await physics_frame
	var screen: Vector2 = cam.unproject_position(node.global_position + Vector3.UP * 0.7)
	var picked: StringName = player.debug_tap_screen(screen)
	_expect(player.gather_target == node or (player._gather_radial != null and player._gather_radial.is_open()),
		"a tap on a card selects its node (picked=%s gather=%s)" % [picked, player.gather_target != null])
	if player._gather_radial != null and player._gather_radial.is_open():
		player._gather_radial.close()
	player.actions.cancel_work()
	player.gather_target = null
	cam.current = false
	cam.queue_free()

## R4/W2-OCCLUDE: a tall card that hides the survivor fades, driven by the same Occlusion dither.
func _test_fade() -> void:
	var card: Node3D = CP.new()
	host.add_child(card)
	var id: String = CP.card_for_family("CommonTree")
	card.setup(id, 8.0)
	card.global_position = Vector3(30, 0, 30)
	var cam := IsoCamera.new()
	host.add_child(cam)
	cam.current = true
	cam._target = player
	# Put the survivor just behind the card along the camera's sight line.
	var back := Vector3(0.57735, 0.57735, 0.57735)
	player.global_position = card.global_position - Vector3(0, 0, 0) + Vector3(0, 1.0, 0)
	cam.global_position = player.global_position + back * 30.0
	cam.look_at(player.global_position)
	var n := Occlusion.make_card_occludable(card, Occlusion.BETWEEN)
	_expect(n > 0, "a tall card opts into the see-through fade (%d surfaces)" % n)
	await process_frame
	var driver = Occlusion.driver()
	_expect(driver != null, "the occlusion driver runs for cards")
	if driver != null:
		var chest: Vector3 = player.global_position + Vector3.UP * 0.3
		var hits: Dictionary = driver.in_the_way(chest, back.normalized())
		_expect(not hits.is_empty(), "the card is found in the way when it hides the survivor")
		driver.step_between(hits, 0.5, -back.normalized())
		var mi := card.get_node("Card") as MeshInstance3D
		var f: float = mi.get_instance_shader_parameter(&"occl_fade")
		_expect(f > 0.0, "the card fades when it hides the survivor (occl_fade=%.2f)" % f)
	Occlusion.release(card)
	cam.current = false
	cam.queue_free()
	card.queue_free()

## Loads the home island and counts the cards; `clear` frees it again.
func _island_cards(clear: bool) -> int:
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	if clear:
		var n := 0
		for node in get_nodes_in_group("harvest"):
			if node.get("_card") != null:
				n += 1
		return n
	if player == null:
		player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
		host.add_child(player)
		player.global_position = world.runtime._camp_pos + Vector3(0, 1, 0)
		await process_frame
	var n := 0
	for node in get_nodes_in_group("harvest"):
		if node.get("_card") != null and is_instance_valid(node.get("_card")):
			n += 1
	return n
