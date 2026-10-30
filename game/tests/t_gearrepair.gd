extends SceneTree
## P3 GEARREPAIR (docs/design/tools-durability-crafting.md 3.5, section 4): repair at the tier's station
## (recipes.json repairs) sets max durability to round(max x 0.8) and refills it: a max-100 item goes 80,
## 64, 51, 41 and the fifth repair is refused ("worn out"); a broken axe costs 2 tier units, a half-worn
## one 1; the wrong station and a full item are refused; the repair count and the cut max survive a save
## round trip (sanitizer) and the vault's deposit check; the station menu offers REPAIR at a workbench with
## a worn tool and its picker repairs; the inspect line and the market row show the count.
## Run: Godot --headless --path game --script res://tests/t_gearrepair.gd -> "[t_gearrepair] PASS".

var _fails: PackedStringArray = []
var _started := false
var IS: GDScript
var INV: GDScript
var GR: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	GR = load("res://scripts/items/gear_repair.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_gearrepair] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _bag_with_stone(n: int):
	var inv = INV.new(20)
	for i in n:
		inv.add(IS.make(&"stone", 1, {}, 1))
	return inv

func _run() -> void:
	_test_chain()
	_test_cost()
	_test_refusals()
	_test_save_and_vault()
	await _test_ui()
	if _fails.is_empty():
		print("[t_gearrepair] PASS")
		quit(0)
	else:
		print("[t_gearrepair] FAIL count=%d" % _fails.size())
		quit(1)

func _test_chain() -> void:
	var inv = _bag_with_stone(20)
	var axe = IS.make(&"work_axe", 1, {"material_tier": "stone"}, 1)
	axe.max_durability = 100
	inv.add(axe)
	var maxes: Array[int] = []
	for i in 4:
		axe.durability = 0
		var why: String = GR.repair(axe, inv, &"workbench")
		_expect(why == "", "repair %d accepted (%s)" % [i + 1, why])
		maxes.append(axe.max_durability)
		_expect(axe.durability == axe.max_durability, "repair %d refills to the new max (%d/%d)" % [i + 1, axe.durability, axe.max_durability])
	_expect(maxes == [80, 64, 51, 41], "a max-100 item repairs to 80, 64, 51, 41 (%s)" % [maxes])
	_expect(GR.count(axe) == 4, "the item counts 4 repairs (%d)" % GR.count(axe))
	axe.durability = 10
	var stone0: int = inv.count_of(&"stone")
	var fifth: String = GR.repair(axe, inv, &"workbench")
	_expect(fifth.contains("worn out") and axe.max_durability == 41 and inv.count_of(&"stone") == stone0, "the fifth repair is refused with '%s' and costs nothing" % fifth)
	_expect(GR.text(axe).contains("worn out"), "the inspect line says worn out ('%s')" % GR.text(axe))

func _test_cost() -> void:
	var inv = _bag_with_stone(5)
	var axe = IS.make(&"work_axe", 1, {"material_tier": "stone"}, 1)
	inv.add(axe)
	var top: int = axe.max_durability
	axe.durability = 0
	_expect(GR.cost(axe) == 2, "a broken axe costs 2 stone (%d)" % GR.cost(axe))
	_expect(GR.repair(axe, inv, &"workbench") == "" and inv.count_of(&"stone") == 3, "the repair took 2 stone (%d left)" % inv.count_of(&"stone"))
	axe.durability = axe.max_durability / 2
	_expect(GR.cost(axe) == 1, "a half-worn axe costs 1 (%d/%d -> %d)" % [axe.durability, axe.max_durability, GR.cost(axe)])
	axe.durability = axe.max_durability - 1
	_expect(GR.cost(axe) == 1, "a barely worn axe costs 1")
	_expect(GR.text(axe).contains("Workbench") and GR.text(axe).contains("max %d -> %d" % [axe.max_durability, roundi(axe.max_durability * 0.8)]) and GR.text(axe).contains("repair 2 of 4"), "the inspect line names station, cost and the new max ('%s')" % GR.text(axe))
	_expect(top > axe.max_durability, "max fell from %d to %d" % [top, axe.max_durability])

func _test_refusals() -> void:
	var inv = _bag_with_stone(5)
	var axe = IS.make(&"work_axe", 1, {"material_tier": "stone"}, 1)
	inv.add(axe)
	_expect(GR.block_reason(axe, inv, &"workbench").contains("full"), "a full item is refused ('%s')" % GR.block_reason(axe, inv, &"workbench"))
	axe.durability = 1
	var why: String = GR.repair(axe, inv, &"anvil")
	_expect(why.contains("workbench") and axe.durability == 1, "a stone axe at the anvil is refused ('%s')" % why)
	var empty = INV.new(4)
	empty.add(axe)
	why = GR.repair(axe, empty, &"workbench")
	_expect(why.contains("needs") and axe.durability == 1, "no tier material is refused ('%s')" % why)
	var helm = IS.make(&"iron_helm", 1, {}, 1)
	helm.durability = 1
	_expect(GR.station_of(helm) == &"anvil" and GR.block_reason(helm, inv, &"workbench").contains("anvil"), "an iron helm repairs at the anvil (%s)" % GR.station_of(helm))
	var log = IS.make(&"wood_log", 1, {}, 1)
	_expect(GR.text(log) == "Repair: Not Possible", "a log has no repair ('%s')" % GR.text(log))

func _test_save_and_vault() -> void:
	var inv = _bag_with_stone(5)
	var axe = IS.make(&"work_axe", 1, {"material_tier": "stone"}, 1)
	axe.stamp_identity("craft")
	inv.add(axe)
	axe = inv.slots[inv.find_first(&"work_axe")]  # add() moves the units into the bag's own instance
	axe.durability = 0
	GR.repair(axe, inv, &"workbench")
	axe.durability -= 3
	var body: Dictionary = JSON.parse_string(JSON.stringify(axe.to_dict()))
	var SS = load("res://scripts/core/save_sanitizer.gd")
	var cleaned: Array = SS.stacks([body])
	var clean: Dictionary = cleaned[0] if not cleaned.is_empty() else {}
	var back = IS.from_dict(clean)
	_expect(back.max_durability == axe.max_durability and back.durability == axe.durability and GR.count(back) == 1, "save round trip keeps max %d, durability %d, repairs %d" % [back.max_durability, back.durability, GR.count(back)])
	var old = IS.from_dict({"id": "work_axe", "count": 1, "level": 1, "attributes": {"material_tier": "stone"}, "durability": 20, "max_durability": 50})
	_expect(GR.count(old) == 0 and GR.text(old).contains("repair 1 of 4"), "an old save's item (no repairs key) reads 0 repairs")
	var V = load("res://scripts/economy/asset_validator.gd").new(load("res://scripts/economy/econ_catalog.gd").from_data(), load("res://scripts/economy/econ_rules.gd").load_default())
	var dep: Dictionary = back.to_dict()
	for k in ["uid", "origin", "creator", "created_at"]:
		dep.erase(k)
	var vwhy: String = V.item(JSON.parse_string(JSON.stringify(dep)))
	_expect(vwhy == "", "the vault takes the repaired axe ('%s')" % vwhy)
	dep["attributes"]["repairs"] = 9
	_expect(V.item(dep) != "", "the vault refuses a forged repair count")
	var row: Dictionary = load("res://scripts/ui/market/market_row.gd").view_of(back.to_dict())
	_expect(str(row.get("type", "")).contains("repaired 1/4"), "the market row shows the repair count ('%s')" % row.get("type", ""))

func _test_ui() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 60.0)
	var player = kit["player"]
	await process_frame
	var inv = player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	inv.equipment.clear()
	var SC = load("res://scripts/items/station_craft.gd")
	_expect(SC.repair_actions(&"workbench", inv).is_empty(), "no REPAIR hex with nothing worn")
	inv.add(IS.make(&"work_axe", 1, {"material_tier": "stone"}, 1))
	var axe = inv.slots[inv.find_first(&"work_axe")]
	inv.add(IS.make(&"stone", 1, {}, 1))
	inv.add(IS.make(&"stone", 1, {}, 1))
	axe.durability = 0
	_expect(not SC.repair_actions(&"workbench", inv).is_empty(), "a broken axe gives the workbench a REPAIR hex")
	_expect(SC.repair_actions(&"anvil", inv).is_empty(), "but not the anvil (stone tier)")
	var layer := CanvasLayer.new()
	host.add_child(layer)
	var pk = load("res://scripts/ui/repair_picker.gd").open_for(layer, player, &"workbench")
	await process_frame
	var btn = pk.rows_box.get_node_or_null("Repair_0")
	_expect(btn != null and not btn.disabled and str(btn.text).contains("Work Axe") and str(btn.text).contains("2 Stone material"), "the picker lists the axe with its cost ('%s')" % (btn.text if btn else "none"))
	if btn:
		btn.pressed.emit()
	_expect(axe.durability == axe.max_durability and GR.count(axe) == 1 and inv.count_of(&"stone") == 0, "tapping it repairs the axe (%d/%d, stone %d)" % [axe.durability, axe.max_durability, inv.count_of(&"stone")])
	host.queue_free()
	await process_frame
