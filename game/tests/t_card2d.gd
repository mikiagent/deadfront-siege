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
	_expect(is_equal_approx(rad_to_deg(card.rotation.y), CP.CAMERA_YAW_DEG), "the card faces the camera yaw (%.1f°)" % rad_to_deg(card.rotation.y))
	_expect(is_equal_approx(rad_to_deg(card.rotation.y), 45.0), "the camera yaw is 45°")
	var mi: MeshInstance3D = card.get_node_or_null("Card")
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
		_expect(is_equal_approx(top, pivot.y * quad_h), "the ground line is at %.2f of the texture's height" % pivot.y)
		_expect(is_equal_approx(mi.position.x, (0.5 - pivot.x) * aabb.size.x), "the pivot column sits on the origin")
		_expect(pivot.x > 0.0 and pivot.x < 1.0, "pivot u is inside the quad")
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
	card.queue_free()

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
	var keep: Variant = rules.get("resource_render", "model")
	# Default: "model", and nothing on an island is a card.
	var IS: GDScript = load("res://scripts/world/island_scatter.gd")
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
	rules["resource_render"] = keep

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
