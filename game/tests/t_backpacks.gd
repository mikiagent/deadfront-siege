extends SceneTree
## Worn bags show on the survivor: equipping a bag attaches exactly one bag mesh (bag_body, bag_trim,
## bag_bone) to the skeleton, unequipping removes it, swapping replaces it, a save/load restores it,
## and the natural-colour tint lands on bag_body only. A crafted bag keeps its hide's tint.
## Usage: godot --headless --path game --script res://tests/t_backpacks.gd -> "[t_backpacks] PASS"

var failures: Array[String] = []
var _started := false
var player
var IS: GDScript
var INV: GDScript
var PE: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	PE = load("res://scripts/player/player_equipment.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_backpacks] %s %s" % ["ok" if ok else "FAIL", msg])

## Bag meshes under the skeleton: the ones whose surfaces carry the bag_* materials.
func _bag_meshes() -> Array:
	var out := []
	for mi in player.rig.skeleton.get_children():
		if mi is MeshInstance3D and not mi.is_queued_for_deletion() and mi.mesh and mi.mesh.get_surface_count() > 0:
			var m: Material = mi.mesh.surface_get_material(0)
			if m and m.resource_name.begins_with("bag_"):
				out.append(mi)
	return out

func _names(mi: MeshInstance3D) -> Array:
	var out := []
	for s in mi.mesh.get_surface_count():
		out.append(mi.mesh.surface_get_material(s).resource_name)
	return out

func _shown(mi: MeshInstance3D, mat_name: String) -> Color:
	for s in mi.mesh.get_surface_count():
		if mi.mesh.surface_get_material(s).resource_name == mat_name:
			return (mi.get_active_material(s) as StandardMaterial3D).albedo_color
	return Color.TRANSPARENT

func _src(mi: MeshInstance3D, mat_name: String) -> Color:
	for s in mi.mesh.get_surface_count():
		if mi.mesh.surface_get_material(s).resource_name == mat_name:
			return (mi.mesh.surface_get_material(s) as StandardMaterial3D).albedo_color
	return Color.TRANSPARENT

func _wear(def_id: StringName, attrs: Dictionary = {}) -> void:
	var inv = player.inventory
	inv.add(IS.make(def_id, 1, attrs, 5))
	var idx: int = inv.find_first(def_id)
	_expect(inv.equip_at(idx, &"accessory2"), "%s equips into accessory2" % def_id)

func _run() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	await process_frame
	_expect(player.rig != null and player.rig.skeleton != null and player.equipment != null, "survivor rig and equipment exist")
	_expect(_bag_meshes().is_empty(), "no bag mesh before a bag is worn")
	# Equip: one mesh, three materials, tint on bag_body only.
	_wear(&"basic_bag", {"tint": "#6b5a3e"})
	var bags := _bag_meshes()
	_expect(bags.size() == 1, "equipping basic_bag attaches exactly one bag mesh (%d)" % bags.size())
	if bags.size() == 1:
		var mi: MeshInstance3D = bags[0]
		_expect(_names(mi) == ["bag_body", "bag_trim", "bag_bone"], "the bag mesh has bag_body, bag_trim, bag_bone (%s)" % [_names(mi)])
		_expect(mi.skin != null and mi.get_node_or_null(mi.skeleton) == player.rig.skeleton, "the bag is skinned to the survivor skeleton")
		var want: Color = _src(mi, "bag_body") * Color("#6b5a3e")
		_expect(_shown(mi, "bag_body").is_equal_approx(want), "bag_body is multiplied by the bag's tint (%s vs %s)" % [_shown(mi, "bag_body"), want])
		_expect(_shown(mi, "bag_trim").is_equal_approx(_src(mi, "bag_trim")), "bag_trim keeps its colour")
		_expect(_shown(mi, "bag_bone").is_equal_approx(_src(mi, "bag_bone")), "bag_bone keeps its colour")
	# Unequip removes it.
	_expect(player.inventory.unequip(&"accessory2"), "basic_bag unequips")
	_expect(_bag_meshes().is_empty(), "unequipping removes the bag mesh (%d left)" % _bag_meshes().size())
	# Swap: wear basic, then advanced in the same slot -> one mesh, the advanced one.
	_wear(&"basic_bag")
	_wear(&"advanced_backpack")
	bags = _bag_meshes()
	_expect(bags.size() == 1 and str(bags[0].name).contains("advanced"), "swapping bags replaces the mesh (%s)" % [bags.map(func (m): return m.name)])
	var adv_mesh: Mesh = bags[0].mesh if bags.size() == 1 else null
	if bags.size() == 1:
		_expect(_shown(bags[0], "bag_body").is_equal_approx(_src(bags[0], "bag_body") * PE.DEFAULT_BAG_TINT), "an untinted bag wears the default hide colour")
	# Save/load: rows and extras through JSON into the live inventory (SaveGame's path).
	var inv = player.inventory
	var rows = JSON.parse_string(JSON.stringify(inv.to_array()))
	var extras = JSON.parse_string(JSON.stringify(inv.extras_to_dict()))
	inv.unequip(&"accessory2")
	_expect(_bag_meshes().is_empty(), "bag gone before reload")
	inv.load_array(rows)
	inv.extras_from_dict(extras)
	bags = _bag_meshes()
	_expect(bags.size() == 1 and bags[0].mesh == adv_mesh, "loading the save restores the worn bag mesh (%d)" % bags.size())
	# A crafted bag keeps its primary hide's natural colour.
	var BC: GDScript = load("res://scripts/items/bag_capacity.gd")
	var out = IS.make(&"basic_bag", 1)
	BC.apply_inheritance(out, IS.make(&"dried_hide", 1, {"tint": "#6b5a3e", "feathered": 1}))
	_expect(str(out.attributes.get("tint", "")) == "#6b5a3e" and not out.attributes.has("feathered"), "a crafted bag keeps its hide's tint, not its traits (%s)" % out.attributes)
	host.queue_free()
	await process_frame
	print("[t_backpacks] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)
