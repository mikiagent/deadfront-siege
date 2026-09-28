extends RefCounted
## Loaded after Data is ready by run_all.gd (its --script boot compiles too early).
func run() -> Dictionary:
	var result := {}
	var inv := Inventory.new()
	var rec := Crafting.recipe(&"canvas_tent_kit")
	inv.add(ItemStack.make(&"fibre_stalk", 3, {"tint": "#aaaaaa"}, 1))
	inv.add(ItemStack.make(&"fibre_stalk", 3, {"tint": "#bbbbbb"}, 3))
	inv.add(ItemStack.make(&"branch", 3))
	inv.add(ItemStack.make(&"bark_strip", 2))
	var picks := Crafting.default_picks(inv, rec)
	result["canvas accepts split fibre"] = Crafting.picks_valid(inv, rec, picks) and Crafting.missing_ingredient_name(inv, rec) == ""
	var preview := Crafting.preview(inv, rec, picks)
	result["preview inherits primary lead"] = preview != null and preview.attributes.get("tint", "") == "#aaaaaa"
	var levels := Crafting.consumed_levels(inv, rec, picks)
	result["level includes both fibre stacks"] = levels.count(1) == 8 and levels.count(3) == 3
	var used := Crafting.consume_for_craft(inv, rec, picks)
	result["split stacks preserved for refund"] = used.size() == 4 and used[0].count == 3 and used[1].level == 3
	result["full recipe consumed"] = inv.count_of(&"fibre_stalk") == 0 and inv.count_of(&"branch") == 0 and inv.count_of(&"bark_strip") == 0
	for stack in used: inv.add(stack)
	result["cancel refunds split materials"] = inv.count_of(&"fibre_stalk") == 6 and inv.count_of(&"branch") == 3 and inv.count_of(&"bark_strip") == 2
	inv.remove_at(inv.find_first(&"bark_strip"), 1)
	result["short lashing blocks"] = not Crafting.picks_valid(inv, rec, Crafting.default_picks(inv, rec)) and Crafting.missing_ingredient_name(inv, rec) != ""
	var dual := Inventory.new()
	dual.add(ItemStack.make(&"twine", 4))
	var straw := Crafting.recipe(&"straw_roll_kit")
	var dual_picks := Crafting.default_picks(dual, straw)
	result["dual-category stack serves two slots"] = Crafting.picks_valid(dual, straw, dual_picks)
	var dual_used := Crafting.consume_for_craft(dual, straw, dual_picks)
	var total := 0
	for stack in dual_used: total += stack.count
	result["dual-category units spent once"] = total == 4 and dual.count_of(&"twine") == 0
	return result
