extends SceneTree
## Lot identity lives in existing attributes, which already survive save/load.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists("res://scripts/items/material_lot.gd"):
		print("C1 MATERIAL LOT FAIL: material lot support is missing")
		quit(1)
		return
	var lots: GDScript = load("res://scripts/items/material_lot.gd")
	var item: GDScript = load("res://scripts/items/item_stack.gd")
	var inventory: GDScript = load("res://scripts/items/inventory.gd")
	var first: Dictionary = lots.create([{"id": "resilience", "value": 0.15}, {"id": "brittle", "value": -0.1}])
	var second: Dictionary = lots.create([{"id": "resilience", "value": 0.1}, {"id": "brittle", "value": -0.15}])
	var failures: Array[String] = []
	if first.is_empty() or second.is_empty() or first.get("sources", []) == second.get("sources", []):
		failures.append("new lots did not get distinct source identities")
	var combined: Dictionary = lots.combine(first, second)
	if not combined.get("ok", false):
		failures.append("distinct lots did not combine")
	else:
		var lot: Dictionary = combined.get("lot", {})
		var totals: Dictionary = lots.totals(lot)
		if lot.get("traits", []).size() != 4 or not is_equal_approx(float(totals.get("resilience", {}).get("positive", 0)), 0.2) or not is_equal_approx(float(totals.get("brittle", {}).get("negative", 0)), -0.2):
			failures.append("signed records or additive caps were lost")
		if lots.combine(lot, first).get("ok", false):
			failures.append("a repeated ancestor was accepted")
		lot["traits"][0]["value"] = 999
		if float(first.traits[0].value) != 0.15 or float(second.traits[0].value) != 0.1:
			failures.append("combined lot aliases an input record")
	var positive: Dictionary = lots.create([{"id": "strength", "value": 0.1}])
	var negative: Dictionary = lots.create([{"id": "strength", "value": -0.07}])
	var mixed: Dictionary = lots.combine(positive, negative)
	if not mixed.get("ok", false):
		failures.append("opposing signed traits did not combine")
	else:
		var mixed_totals: Dictionary = lots.totals(mixed.lot).get("strength", {})
		if not is_equal_approx(float(mixed_totals.get("positive", 0)), 0.1) or not is_equal_approx(float(mixed_totals.get("negative", 0)), -0.07):
			failures.append("opposing signs cancelled a source trait")
	if not lots.create([{"id": "", "value": 0.1}]).is_empty() or lots.combine(first, {"version": 1, "sources": [], "traits": []}).get("ok", false):
		failures.append("malformed trait data was accepted")
	var stack: Variant = item.make(&"dense_bone", 2, {"material_lot": first}, 4)
	first.traits[0].value = 0.19
	if float(stack.attributes.material_lot.traits[0].value) != 0.15:
		failures.append("a caller can mutate a created stack's source records")
	var bag: Variant = inventory.new(8)
	bag.add(stack)
	var taken: Variant = bag.remove_at(0, 1)
	var split_lot: Dictionary = taken.attributes.get("material_lot", {})
	if lots.combine(split_lot, bag.slots[0].attributes.get("material_lot", {})).get("ok", false):
		failures.append("splitting a stack created a new source")
	var encoded := JSON.stringify(bag.to_array())
	var restored: Variant = inventory.new(8)
	restored.load_array(JSON.parse_string(encoded))
	if not taken.can_merge_with(restored.slots[0]):
		failures.append("same lot could not merge after JSON reload")
	if taken.can_merge_with(item.make(&"dense_bone", 1, {"material_lot": second}, 4)):
		failures.append("different lots merged")
	if not item.make(&"branch", 1).can_merge_with(item.make(&"branch", 1)):
		failures.append("legacy stacks no longer merge")
	if failures.is_empty():
		print("C1 MATERIAL LOT PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("C1 MATERIAL LOT FAIL: %s" % failure)
		quit(1)
