class_name InvCardFacts
extends RefCounted
## What the item card says about one instance (spec 13 s10-11; the owner's in-game Bag reference,
## "inventory menu while in game, scrollview"), read from the item's own data only, so the card never
## shows a field the game does not have: title, kind and level; durability and the hammer (processing)
## count; its families (categories); its state (Raw, Poisoned); its traits by class; the Info rows
## (energy, pet food and the raw-food risks from the food data, damage, armour, tool, held, locked,
## unstable), its colour (the instance's tint) and a plain description; Maintenance for an item that
## wears; Create: the recipes that take it. ItemInspectPanel lays these out (Bag, storage, picker).

## Recipes listed under Create before "and N more".
const CREATE_MAX := 5

## {title, kind, sub, stats: [[label, value, colour]], families: [category id], states: [[text, colour]],
##  traits: [{text, color, cls}], info: [[key, value, colour]], colour: Color (a = 0: none),
##  flavour: String, sections: [{id, title, rows: [[key, value, colour]]}]}
static func of(s: ItemStack, player: Player) -> Dictionary:
	var d := s.def()
	var item_name := d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(s.def_id))
	var species := str(s.attributes.get("species", ""))
	var info: Array = []
	var f := {
		# A caged animal is titled by its species, as Durango titles the cage "Zebraceratops".
		"title": LevelDisplay.nice_name(species) if species != "" else item_name,
		"kind": item_name,
		"sub": LevelDisplay.label(s.level) if s.level > 0 else "",
		"stats": [], "families": [], "states": [], "traits": [], "info": info,
		"colour": s.tint_color() if str(s.attributes.get("tint", "")).begins_with("#") else Color(0, 0, 0, 0),
		"flavour": str((InvView.data().get("flavour", {}) as Dictionary).get(str(s.def_id), "")),
		"sections": [],
	}
	if s.max_durability > 0:
		f.stats.append(["Durability", "%d / %d%s" % [s.durability, s.max_durability, "  Broken" if s.is_broken() else ""], InvTheme.DANGER if s.is_broken() else InvTheme.PRIMARY_INK])
		f.sections.append({"id": &"care", "title": "Maintenance", "rows": [["Repair", "Not possible", InvTheme.TEXT_2]]}) # no repair exists in the game
	if species == "": # every card carries the hammer count, ×0 too: one template for every item (review r1)
		f.stats.append(["Processed", "×%d" % s.process_count, InvTheme.PRIMARY_INK])
	if d and species == "":
		for c in d.categories:
			f.families.append(str(c))
	if Food.is_raw(s):
		f.states.append(["Raw", InvTheme.TEXT_2])
	if Food.is_poisoned(s):
		f.states.append(["Poisoned", InvTheme.DANGER])
	var sec := InvAttributes.sections(s)
	for cls: StringName in [&"positive", &"negative", &"rare"]:
		for r: Dictionary in sec[str(cls)]:
			f.traits.append({"text": InvAttributes.line(r), "color": InvPaint.pip_color(cls), "cls": cls})
	if s.def_id == &"captured_animal":
		info.append(["Bond it at a taming pen", "", InvTheme.TEXT_2])
	if s.is_fungible() and s.count > 1:
		info.append(["Count", "%d" % s.count, InvTheme.TEXT])
	if Food.is_food(s):
		info.append(["Energy", "+%.0f" % Food.energy_restore(s), InvTheme.TEXT])
		var diet := pet_diet(d)
		if diet != "":
			info.append(["%s food" % diet.capitalize(), "+%.0f" % (Food.energy_restore(s) * 10.0), InvTheme.TEXT]) # Food.feed_pet's hunger fill
		if Food.is_raw(s) and d:
			var sick := 1.0 if Food.is_poisoned(s) else d.poison_chance
			if sick > 0.0:
				info.append(["Stomachache", "%d %%" % roundi(sick * 100.0), InvTheme.TEXT_2])
			if d.tastes_bad_chance > 0.0 and sick < 1.0:
				info.append(["Bad taste", "%d %%" % roundi((1.0 - sick) * d.tastes_bad_chance * 100.0), InvTheme.TEXT_2]) # rolled only when no stomachache
		var buffs := Food.buff_ids(s)
		if not buffs.is_empty():
			info.append(["Buffs", ", ".join(PackedStringArray(buffs.map(func(b: StringName) -> String: return LevelDisplay.nice_name(str(b))))), InvTheme.TEXT])
	if s.scaled_damage() > 0.0:
		info.append(["Damage", "%.0f" % s.scaled_damage(), InvTheme.TEXT])
	if s.scaled_armor() > 0.0:
		info.append(["Armor", "%.0f" % s.scaled_armor(), InvTheme.TEXT])
	if d and d.health_bonus > 0.0:
		info.append(["Max health", "+%.0f" % d.health_bonus_at(s.level), InvTheme.TEXT])
	if d and d.tool_class not in [&"", &"none"]:
		info.append(["Tool", "%s  %.2fx" % [str(d.tool_class).capitalize(), s.gather_power()], InvTheme.TEXT])
	if player and player.inventory.equipped_tool_index >= 0 and player.inventory.slots[player.inventory.equipped_tool_index] == s:
		info.append(["Held tool", "", InvTheme.SELECT])
	if s.is_locked():
		info.append(["Locked", "", InvTheme.TEXT_2])
	if s.is_unstable(): # W2-INV's "U" pip: lost if carried off the unstable island on foot
		info.append(["Unstable", "cargo warp it home", InvTheme.TEXT_2])
	var make := creates(s)
	if not make.is_empty():
		f.sections.append({"id": &"make", "title": "Create", "rows": make})
	return f

## "carnivore" / "herbivore" when a pet of that diet eats it (Food.feed_pet's rule), else "".
static func pet_diet(d: ItemDef) -> String:
	if d == null:
		return ""
	if d.has_category(&"meat") or d.diet == &"carnivore":
		return "carnivore"
	if d.has_category(&"fruit") or d.has_category(&"stalk") or d.diet == &"herbivore":
		return "herbivore"
	return ""

## The recipes one of whose slots takes this item, as [recipe, where it is made, colour] rows, the
## first CREATE_MAX and then how many more.
static func creates(s: ItemStack) -> Array:
	var d := s.def()
	var out: Array = []
	if d == null:
		return out
	var more := 0
	for rec: Dictionary in Crafting.all_recipes():
		var takes := false
		for slot: Variant in rec.get("slots", []):
			takes = takes or (slot is Dictionary and d.has_category(StringName(str((slot as Dictionary).get("category", "")))))
		if not takes:
			continue
		if out.size() >= CREATE_MAX:
			more += 1
			continue
		var station: Variant = rec.get("station")
		out.append([str(rec.get("display_name", LevelDisplay.nice_name(str(rec.get("id", ""))))), LevelDisplay.nice_name(str(station)) if station is String and station != "" else "By hand", InvTheme.TEXT])
	if more > 0:
		out.append(["and %d more" % more, "", InvTheme.TEXT_2])
	return out
