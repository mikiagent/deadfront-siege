extends SceneTree
## KNIFESPLIT (owner 2026-10-30): a Work Knife for butchering and a Stone Dagger for combat; combat never
## wears the Work Knife. Combat hits with only the Work Knife in hand fight bare-handed and leave its
## durability alone; the Dagger wears in combat; butchering wears the Work Knife, never a held Dagger;
## the Dagger butchers (at weapon wear) only when no Work Knife is carried; a pre-split save's worn Work
## Knife goes back to the bag; display names and recipes.
## Usage: godot --headless --path game --script res://tests/t_knifesplit.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var data: Node
var ITEM: GDScript
var INV: GDScript
var CR: GDScript
var TUNE: GDScript
var PANEL: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	ITEM = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	CR = load("res://scripts/items/crafting.gd")
	TUNE = load("res://scripts/combat/combat_tuning.gd")
	PANEL = load("res://scripts/ui/item_inspect_panel.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_knifesplit] FAIL %s" % msg)
	else:
		print("[t_knifesplit] ok %s" % msg)

func _run() -> void:
	host = Node3D.new()
	host.name = "TKnifesplit"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	_test_names()
	_test_combat()
	_test_butcher()
	_test_old_save()
	TUNE.reset_overrides()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_knifesplit] PASS")
		quit(0)
	else:
		print("[t_knifesplit] FAIL count=%d" % failures.size())
		quit(1)

func _clear_bag() -> void:
	var inv = player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	inv.equipment.clear()
	inv.equipped_tool_index = -1

func _test_names() -> void:
	var work = data.item(&"stone_knife_work")
	var dagger = data.item(&"stone_knife")
	_expect(work.display_name == "Work Knife" and dagger.display_name == "Stone Dagger", "names: %s / %s" % [work.display_name, dagger.display_name])
	_expect(work.is_work_tool and not work.has_category(&"weapon") and INV.slot_for(work) == &"", "the Work Knife is a work tool and never a weapon")
	_expect(not dagger.is_work_tool and INV.slot_for(dagger) == &"weapon" and dagger.tool_class == &"knife", "the Stone Dagger is a weapon that can still cut")
	var r_work: Dictionary = CR.recipe(&"improvised_stone_knife")
	var r_dag: Dictionary = CR.recipe(&"stone_knife")
	_expect(str(r_work.get("output", {}).get("id", "")) == "stone_knife_work" and CR.station_id(r_work) == "", "Work Knife recipe: by hand")
	_expect(str(r_dag.get("output", {}).get("id", "")) == "stone_knife" and not r_dag.has("requires_node"), "Stone Dagger recipe: no skill node gate, reachable before the first hunt")
	var rows: Array = PANEL.rows_for(ITEM.make(&"stone_knife_work", 1))
	_expect(rows.any(func (r: Dictionary) -> bool: return str(r["text"]).contains("never used in combat")), "the Work Knife's card says it never fights")

func _test_combat() -> void:
	TUNE.force_dodge = 0.0
	TUNE.force_accuracy = 1.0
	_clear_bag()
	var inv = player.inventory
	inv.add(ITEM.make(&"stone_knife_work", 1))
	var ki: int = inv.find_first(&"stone_knife_work")
	var knife = inv.slots[ki]
	inv.set_equipped_tool_index(ki)  # the Work Knife is the thing in hand
	_expect(not inv.equip(&"weapon", &"stone_knife_work"), "the Work Knife cannot go in the weapon slot")
	var target = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	target.position = Vector3(0, 0, -1.6)
	host.add_child(target)
	target.spawn(data.creature(&"velociraptor"))
	target.brain.process_mode = Node.PROCESS_MODE_DISABLED
	var before: int = knife.durability
	for i in 5:
		target.health.hp = target.health.max_hp
		player.hunt.land_hit(target, player.hunt._weapon())
	_expect(player.hunt._weapon() == null and knife.durability == before, "5 hits with only the Work Knife in hand: fists, durability %d -> %d" % [before, knife.durability])
	inv.add(ITEM.make(&"stone_knife", 1))
	var dagger = inv.slots[inv.find_first(&"stone_knife")]
	inv.add(ITEM.make(&"work_axe", 1))
	_expect(player.hunt._weapon() == dagger, "with a Stone Dagger carried, combat takes the dagger (over the axe), not the knife")
	var d0: int = dagger.durability
	for i in 5:
		target.health.hp = target.health.max_hp
		player.hunt.land_hit(target, player.hunt._weapon())
	_expect(dagger.durability == d0 - 5 and knife.durability == before, "5 dagger hits: dagger %d -> %d, Work Knife untouched (%d)" % [d0, dagger.durability, knife.durability])
	target.free()
	TUNE.reset_overrides()

func _test_butcher() -> void:
	_clear_bag()
	var inv = player.inventory
	inv.add(ITEM.make(&"stone_knife_work", 1))
	inv.add(ITEM.make(&"stone_knife", 1))
	var knife = inv.slots[inv.find_first(&"stone_knife_work")]
	var di: int = inv.find_first(&"stone_knife")
	var dagger = inv.slots[di]
	inv.set_equipped_tool_index(di)  # even with the dagger picked as the held tool
	var k0: int = knife.durability
	var d0: int = dagger.durability
	inv.wear_gather_tool(&"knife")
	_expect(knife.durability == k0 - 1 and dagger.durability == d0, "butchering wears the Work Knife (%d -> %d), not the dagger (%d -> %d)" % [k0, knife.durability, d0, dagger.durability])
	inv.slots[inv.find_first(&"stone_knife_work")] = null
	inv.wear_gather_tool(&"knife")
	_expect(dagger.durability == d0 - 3, "with no Work Knife the dagger butchers at weapon wear (%d -> %d)" % [d0, dagger.durability])

func _test_old_save() -> void:
	_clear_bag()
	var inv = player.inventory
	var knife = ITEM.make(&"stone_knife_work", 1)
	inv.extras_from_dict({"worn": {"weapon": knife.to_dict()}, "tool_index": -1})
	_expect(inv.worn(&"weapon") == null and inv.count_of(&"stone_knife_work") == 1, "a pre-split save's worn Work Knife returns to the bag")
	_expect(inv.equipped_weapon() == null, "and the survivor fights with fists until a dagger is made")
