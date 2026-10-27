extends SceneTree
## The preview is read-only and must describe the exact lots consumed next.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var inv: Variant = (load("res://scripts/items/inventory.gd") as GDScript).new(8)
	var item: GDScript = load("res://scripts/items/item_stack.gd")
	var craft: GDScript = load("res://scripts/items/crafting.gd")
	inv.add(item.make(&"branch", 1, {"quality": -2}, 3))
	inv.add(item.make(&"branch", 1, {"quality": 4}, 7))
	inv.add(item.make(&"twine", 1, {}, 2))
	var recipe := {"slots": [{"category": "wood", "count": 2, "primary": true}, {"category": "lashing", "count": 1}]}
	var before: String = JSON.stringify(inv.to_array())
	var picks: Array[int] = craft.default_picks(inv, recipe)
	var rows: Array[Dictionary] = craft.slot_level_contributions(inv, recipe, picks)
	var failures: Array[String] = []
	if rows.size() != 3:
		failures.append("expected both wood lots and the lashing")
	else:
		if rows[0].get("attributes", {}).get("quality") != -2 or rows[1].get("attributes", {}).get("quality") != 4:
			failures.append("lot attributes were not preserved in preview")
		if not rows[0].get("primary", false) or rows[1].get("primary", true) or rows[2].get("primary", true):
			failures.append("primary ingredient role was not identified")
		var attrs: Dictionary = rows[0].get("attributes", {})
		attrs["quality"] = 999
		if JSON.stringify(inv.to_array()) != before:
			failures.append("preview mutated the inventory")
		rows = craft.slot_level_contributions(inv, recipe, picks)
		var consumed: Array = craft.consume_for_craft(inv, recipe, picks)
		if consumed.size() != rows.size():
			failures.append("preview and consumption counts differ")
		else:
			for i in rows.size():
				if str(consumed[i].def_id) != rows[i].get("def_id") or consumed[i].count != rows[i].get("count") or consumed[i].level != rows[i].get("level") or consumed[i].attributes != rows[i].get("attributes"):
					failures.append("preview does not match the consumed lot")
	if failures.is_empty():
		print("C1 MATERIAL PREVIEW PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("C1 MATERIAL PREVIEW FAIL: %s" % failure)
		quit(1)
