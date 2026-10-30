extends SceneTree
## RECIPETOOLS (docs/design/tools-durability-crafting.md §3.4, P2): recipes declare requires_tool {class,
## min_tier}; only a WORK tool in the bag counts (never a Stone Dagger, never the worn weapon slot); each
## craft run wears that tool 1, success or failure; the hoe rows are enforced; a tribe member's ASSIGN
## and its craft use the member's own held tool; a ladder audit proves every gated tool can be made
## before anything needs it.
## Usage: godot --headless --path game --script res://tests/t_recipetools.gd -> "[t_recipetools] PASS".

var _fails: PackedStringArray = []
var _started := false
var player
var host: Node3D
var CR: GDScript
var IS: GDScript
var PS: GDScript

func _process(_delta: float) -> bool:
	if _started or root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	CR = load("res://scripts/items/crafting.gd")
	IS = load("res://scripts/items/item_stack.gd")
	PS = load("res://scripts/items/progression_scaling.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_recipetools] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	host = Node3D.new()
	host.name = "TRecipeTools"
	root.add_child(host)
	player = load("res://scripts/dev/lab_kit.gd").build(host, 20.0)["player"]
	await physics_frame
	_test_data_form()
	_test_gates()
	_test_wear()
	_test_tiers_and_hoe()
	_test_weapon_slot()
	await _test_tribe()
	_test_ladder()
	host.queue_free()
	await process_frame
	if _fails.is_empty():
		print("[t_recipetools] PASS")
		quit(0)
	else:
		print("[t_recipetools] FAIL count=%d" % _fails.size())
		quit(1)

func _clear() -> void:
	var inv = player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	inv.equipment.clear()
	inv.equipped_tool_index = -1

func _add(id: StringName, n: int = 1, attrs: Dictionary = {}):
	var s = IS.make(id, n, attrs, 1)
	player.inventory.add(s)
	for t in player.inventory.slots:
		if t != null and t.def_id == id:
			return t
	return null

## A craft through the shared plan/run path (the one the survivor, the server and the tribe use).
func _run_craft(rid: StringName, success: bool = true) -> Dictionary:
	var rec: Dictionary = CR.recipe(rid)
	var inv = player.inventory
	var plan: Dictionary = CR.plan_craft(rec, inv, CR.default_picks(inv, rec), 100.0, 1, 1)
	if plan.is_empty():
		return {"status": "noplan"}
	plan["outcome"] = {"success": success, "flawless": false, "rare": &""}
	return CR.run_plan(rec, inv, plan)

func _test_data_form() -> void:
	var need: Dictionary = CR.tool_need({"requires_tool": "hoe"})
	_expect(need.get("class") == "hoe" and need.get("min_tier") == "stone", "the old string form reads as that class at stone tier (%s)" % need)
	_expect(CR.tool_need({}).is_empty(), "a recipe without requires_tool needs nothing")
	var want := {"plank": "axe", "pillar": "axe", "plank_shape": "axe", "pillar_shape": "axe", "trimmed_plank": "axe", "fine_plank": "axe", "hide_strap": "knife", "field_small": "hoe", "field_large": "hoe"}
	for rid in want:
		var n: Dictionary = CR.tool_need(CR.recipe(StringName(rid)))
		_expect(n.get("class", "") == want[rid], "%s needs a %s (%s)" % [rid, want[rid], n])
	_expect(CR.tool_need(CR.recipe(&"fine_plank")).get("min_tier") == "flint", "fine_plank needs a flint axe or better")
	_expect(CR.tool_need(CR.recipe(&"dried_hide")).is_empty(), "drying a hide needs no tool")

func _test_gates() -> void:
	_clear()
	_add(&"wood_log", 4)
	var rec: Dictionary = CR.recipe(&"plank_shape")
	var why: String = CR.progression_block(player, rec)
	_expect(why == "Needs work axe (stone)", "plank shape without an axe is refused with the reason ('%s')" % why)
	var res := _run_craft(&"plank_shape")
	_expect(str(res.get("status")) == "tool" and player.inventory.count_of(&"wood_log") == 4, "run_plan refuses without the axe and spends nothing (%s)" % res.get("status"))
	# plank (split_wood node) gates on the tool too; the shared path refuses it with the same reason.
	_add(&"split_wood", 2)
	_expect(CR.tool_block(player.inventory, CR.recipe(&"plank")) == "Needs work axe (stone)", "plank without an axe: '%s'" % CR.tool_block(player.inventory, CR.recipe(&"plank")))
	# A Stone Dagger (a knife, not a work tool) never satisfies a knife recipe.
	_add(&"dried_hide", 1)
	_add(&"stone_knife")
	_expect(CR.tool_block(player.inventory, CR.recipe(&"hide_strap")) == "Needs work knife (stone)", "a Stone Dagger alone does not cut a hide strap")
	_expect(str(_run_craft(&"hide_strap").get("status")) == "tool", "run_plan refuses the strap with only the dagger")
	var knife = _add(&"stone_knife_work")
	_expect(CR.tool_block(player.inventory, CR.recipe(&"hide_strap")) == "", "the Work Knife cuts it")
	var before: int = knife.durability
	_expect(str(_run_craft(&"hide_strap").get("status")) == "made" and knife.durability == before - 1, "the strap is made and the Work Knife loses 1 (%d -> %d)" % [before, knife.durability])
	var dagger = null
	for s in player.inventory.slots:
		if s != null and s.def_id == &"stone_knife":
			dagger = s
	_expect(dagger != null and dagger.durability == dagger.max_durability, "the Stone Dagger takes no craft wear")

func _test_wear() -> void:
	_clear()
	_add(&"wood_log", 4)
	var axe = _add(&"work_axe")
	var d0: int = axe.durability
	var res := _run_craft(&"plank_shape")
	_expect(str(res.get("status")) == "made" and axe.durability == d0 - 1, "with a work axe the plank shape runs and the axe loses 1 (%d -> %d)" % [d0, axe.durability])
	res = _run_craft(&"plank_shape", false)
	_expect(str(res.get("status")) == "failed" and axe.durability == d0 - 2, "a failed run wears the axe too (%d)" % axe.durability)
	_expect(CR.progression_block(player, CR.recipe(&"plank_shape")) == "", "the gate opens with the axe in the bag")
	# A broken axe no longer counts.
	axe.durability = 0
	_expect(CR.tool_block(player.inventory, CR.recipe(&"plank_shape")) != "", "a broken axe does not satisfy the gate")

func _test_tiers_and_hoe() -> void:
	_clear()
	_add(&"plank_shape", 2)
	var axe = _add(&"work_axe")
	_expect(axe.material_tier() == &"stone", "a work axe from stone is stone tier")
	_expect(CR.tool_block(player.inventory, CR.recipe(&"fine_plank")) == "Needs work axe (flint)", "fine plank refuses a stone axe: '%s'" % CR.tool_block(player.inventory, CR.recipe(&"fine_plank")))
	var flint = _add(&"flint_axe")
	_expect(CR.recipe_tool(player.inventory, CR.recipe(&"fine_plank")) == flint, "fine plank takes the flint axe")
	var f0: int = flint.durability
	var a0: int = axe.durability
	_expect(str(_run_craft(&"fine_plank").get("status")) == "made" and flint.durability == f0 - 1 and axe.durability == a0, "the flint axe wears, the stone one does not")
	_clear()
	_add(&"clay", 4)
	_expect(CR.tool_block(player.inventory, CR.recipe(&"field_small")) == "Needs hoe (stone)", "a field refuses without a hoe ('%s')" % CR.tool_block(player.inventory, CR.recipe(&"field_small")))
	_expect(str(_run_craft(&"field_small").get("status")) == "tool", "run_plan refuses the field without a hoe")
	var hoe = _add(&"hoe")
	var h0: int = hoe.durability
	_expect(str(_run_craft(&"field_small").get("status")) == "made" and hoe.durability == h0 - 1, "with a hoe the field is made and the hoe loses 1")

func _test_weapon_slot() -> void:
	_clear()
	_add(&"wood_log", 2)
	var axe = _add(&"work_axe")
	var at: int = player.inventory.slots.find(axe)
	player.inventory.slots[at] = null
	player.inventory.equipment[&"weapon"] = axe
	_expect(CR.tool_block(player.inventory, CR.recipe(&"plank_shape")) != "", "an axe in the weapon slot does not count for a recipe")
	_expect(player.inventory.find_gather_tool(&"axe") == axe, "the same axe still chops trees from the weapon slot (field gathering unchanged)")

func _test_tribe() -> void:
	_clear()
	var T = load("res://scripts/tribe/tribe.gd")
	var TW = load("res://scripts/tribe/tribe_work.gd")
	T.reset()
	var wb = load("res://scripts/world/craft_station.gd").make(&"workbench")
	host.add_child(wb)
	wb.global_position = player.global_position + Vector3(1.5, 0, 0)
	await physics_frame
	var r = T.make_recruit(T.rng)
	r.name = "Joss"
	T.members.append(r)
	var world = root.get_node("World")
	world.pioneer_crafts["pillar"] = true
	var rec: Dictionary = CR.recipe(&"pillar")
	var o: Dictionary = TW.craft_offer(player, r, rec, wb)
	_expect(str(o["why"]) == "Needs work axe (stone)", "ASSIGN refuses a member without an axe: '%s'" % o["why"])
	_add(&"work_axe")
	o = TW.craft_offer(player, r, rec, wb)
	_expect(str(o["why"]) == "Needs work axe (stone)", "the survivor's axe in her bag does not arm the member")
	var axe = IS.make(&"work_axe", 1, {}, 1)
	r.equipment.put(&"weapon", axe)
	o = TW.craft_offer(player, r, rec, wb)
	_expect(str(o["why"]) == "", "with a work axe in hand the member takes the order ('%s')" % o["why"])
	# The member's run uses and wears its own tool.
	r.escrow.add(IS.make(&"wood_log", 2, {}, 1))
	var plan: Dictionary = CR.plan_craft(rec, r.escrow, CR.default_picks(r.escrow, rec), 100.0, 1, 1)
	var none := Array([], TYPE_OBJECT, &"RefCounted", IS)  # Array[ItemStack] without naming the class at compile time
	var d0: int = axe.durability
	var res: Dictionary = CR.run_plan(rec, r.escrow, plan, none, TW.tool_bag(r))
	_expect(str(res.get("status")) == "made" and axe.durability == d0 - 1, "the member's craft wears its own axe (%s, %d -> %d)" % [res.get("status"), d0, axe.durability])
	T.members.clear()
	# The workbench runs Trimmed Plank by itself: loading it needs the axe in the bag and wears it once.
	_clear()
	_add(&"plank_shape", 1)
	var ps = wb.get_node_or_null("ProcessStation")
	if ps == null:
		for c in wb.get_children():
			if c.has_method("load_from"):
				ps = c
	_expect(ps != null, "the workbench has its process station")
	if ps:
		var why: String = ps.refuse_reason(player.inventory, &"trimmed_plank")  # no player: skip the skill-node gate
		_expect(why == "Needs work axe (stone)", "the workbench refuses to load Trimmed Plank without an axe ('%s')" % why)
		var bag_axe = _add(&"work_axe")
		var b0: int = bag_axe.durability
		var n: int = ps.load_from(player.inventory, &"trimmed_plank", 1)
		_expect(n == 1 and bag_axe.durability == b0 - 1, "with the axe it loads and the axe loses 1 (%d, %d -> %d)" % [n, b0, bag_axe.durability])
	wb.queue_free()

## Breadth-first from an empty bag: a recipe runs once the tools it needs have been made; a made work tool
## adds its class at the tier its id names (conservative: a work axe counts as stone even from flint).
## Every gated recipe must become runnable; a deadlock names the recipe.
func _test_ladder() -> void:
	var have := {}  # class -> best tier index made so far
	var recs: Array = CR.all_recipes()
	var changed := true
	while changed:
		changed = false
		for rec in recs:
			if not _runnable(rec, have):
				continue
			var outs: Array = [rec.get("output", {})]
			var by: Variant = rec.get("outputs_by_primary", null)
			if by is Dictionary:
				outs.append_array((by as Dictionary).values())
			for row in outs:
				var d = root.get_node("Data").item(StringName(str((row as Dictionary).get("id", ""))))
				if d == null or not d.is_work_tool or d.tool_class == &"":
					continue
				var t: int = PS.tier_index(PS.material_tier(d.id, {}))
				if t > int(have.get(str(d.tool_class), -1)):
					have[str(d.tool_class)] = t
					changed = true
	var stuck: PackedStringArray = []
	for rec in recs:
		if not CR.tool_need(rec).is_empty() and not _runnable(rec, have):
			stuck.append(str(rec.get("id", "")))
	_expect(stuck.is_empty(), "ladder: every tool-gated recipe's tool can be made first (made %s; deadlocked: %s)" % [have, ", ".join(stuck)])

func _runnable(rec: Dictionary, have: Dictionary) -> bool:
	var need: Dictionary = CR.tool_need(rec)
	if need.is_empty():
		return true
	return int(have.get(str(need["class"]), -1)) >= PS.tier_index(StringName(str(need["min_tier"])))
