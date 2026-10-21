class_name ButcherLoot
extends RefCounted
## Fills a fresh carcass from butchering.json: counts scale with the hunter's best knife tier
## and Butchering level, premium parts need a good enough knife (loot_tables.json part_min_tier),
## and "rare" rows roll their odds instead of always dropping. Rare parts are announced when the
## animal falls in the survivor's view; taking them pays the base Butchering XP only.
## Corpse._roll_loot calls roll_into (integrator hook).

static var rng: RandomNumberGenerator = _new_rng()

static func _new_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r

# ASSUMPTION: the local survivor is the butcher, rolled when the animal falls (single player;
# the server rolls for the credited killer in W3). A knife picked up later does not re-roll.
static func roll_into(corpse: Corpse, body: Node3D = null) -> Array[StringName]:
	var p := PlayerRegistry.local()
	var knife: ItemStack = p.inventory.find_gather_tool(&"knife") if p else null
	var skill := maxi(0, p.skills.level_of("butchering")) if p and p.skills else 0
	var table: Dictionary = Data.butcher_tables.get(str(corpse.species), {})
	var res := LootRoller.roll_carcass(table.get("base", []), table.get("rare", []), corpse.level,
			knife.material_tier() if knife else &"", Data.butchering_level(), skill, corpse.poison_spoiled, rng)
	for st in res["stacks"]:
		corpse.loot.add(st)
	var rares: Array[StringName] = []
	for id in res["rares"]:
		rares.append(id)
	if p and not rares.is_empty():
		var at := (body.global_position if body and body.is_inside_tree() else p.global_position) + Vector3(0, 1.4, 0)
		# A kill out of sight (a turret's, a far pack's) rolls silently: no gold notice for a carcass never seen.
		if in_view(p, at):
			GatherFeedback.announce_rares(p, at, rares, " on the %s" % corpse.species_display_name().to_lower())
	return rares

## The point is on the survivor's screen (in front of the camera, inside the viewport).
static func in_view(p: Player, at: Vector3) -> bool:
	if not p.is_inside_tree():
		return false
	var cam := p.get_viewport().get_camera_3d()
	return cam != null and not cam.is_position_behind(at) and p.get_viewport().get_visible_rect().has_point(cam.unproject_position(at))
