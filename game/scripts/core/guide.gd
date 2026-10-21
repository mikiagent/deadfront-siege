class_name Guide
extends RefCounted
## The walkthrough finger's brain (durango-prompts 22): what the current order wants tapped, and which
## orders the finger has finished (World.guide_done, saved).
##
## A step's plan comes from its own data: an item the islands grow is gathered from a node, an item a
## recipe makes is crafted by hand (the HUD's craft control) or at a station. The optional "guide" field
## in objectives.json names a creature where the order is not about a grown or crafted item (meat, tame).

## {"kind": "gather", "item"} | {"kind": "craft"} | {"kind": "station", "stations": [id, ...]} |
## {"kind": "creature", "id"} | {"kind": "none"}.
static func plan(step: Dictionary) -> Dictionary:
	var g: Variant = step.get("guide", null)
	if g is Dictionary and (g as Dictionary).has("creature"):
		return {"kind": "creature", "id": str(g["creature"])}
	var need: Variant = step.get("have", step.get("have_any", null))
	if not need is Dictionary or (need as Dictionary).is_empty():
		return {"kind": "none"}
	var item := str((need as Dictionary).keys()[0])
	for fam: Variant in Data.nature_families.values():
		if fam is Dictionary and (fam as Dictionary).get("harvest", {}) is Dictionary and ((fam as Dictionary)["harvest"] as Dictionary).has(item):
			return {"kind": "gather", "item": item}
	var stations: Array[String] = []
	for rec: Variant in Data.recipe_list:
		var out: Variant = (rec as Dictionary).get("output", {}) if rec is Dictionary else null
		if out is Dictionary and str((out as Dictionary).get("id", "")) == item:
			var sid := Crafting.station_id(rec)
			if sid == "":
				return {"kind": "craft"}
			stations.append(sid)
	return {"kind": "station", "stations": stations} if not stations.is_empty() else {"kind": "none"}

## The plan of World.objective's step (none past the list).
static func current_plan() -> Dictionary:
	return plan(Objectives.step(World.objective))

## Where the finger points for `p` this frame, besides a gather hex (the radial owns those):
## {"node": Node3D} for a thing in the world, {"rect": Rect2} for a HUD control, {} for nothing.
static func world_target(player: Player, p: Dictionary, hud: HuntHud) -> Dictionary:
	match str(p.get("kind", "none")):
		"gather":
			var n := pick_node(player.global_position, StringName(str(p["item"])), player.get_tree().get_nodes_in_group("harvest"), threats(player.get_tree()))
			return {"node": n} if n else {}
		"craft":
			var c := hud.control_for(&"craft") if hud else null
			return {"rect": c.get_global_rect()} if c and c.is_visible_in_tree() else {}
		"station":
			var best: Node3D = null
			for sid: String in p["stations"]:
				var s := Crafting.nearest_station(player, StringName(sid))
				if s and (best == null or player.global_position.distance_to(s.global_position) < player.global_position.distance_to(best.global_position)):
					best = s
			return {"node": best} if best else {}
		"creature":
			var best: Creature = null
			for n in player.get_tree().get_nodes_in_group("creatures"):
				var c := n as Creature
				if c and not c.is_pet and not c.health.dead and c.def and str(c.def.id) == str(p["id"]) \
						and (best == null or player.global_position.distance_to(c.global_position) < player.global_position.distance_to(best.global_position)):
					best = c
			return {"node": best} if best else {}
	return {}

## [[position, aggro radius], ...] of every living wild hunter. # ASSUMPTION: hostile = not a herbivore
## (ai.json is_herbivore); the radius is the leash ring the creature draws while on the survivor.
static func threats(tree: SceneTree) -> Array:
	var out: Array = []
	for n in tree.get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and not c.is_pet and not c.health.dead and c.brain and not bool(c.brain.profile.get("is_herbivore", false)):
			out.append([c.global_position, c.brain.aggro_radius()])
	return out

## The nearest node that still offers `item`, preferring one outside every threat's radius.
# ASSUMPTION: with no safe node the nearest one still gets the finger (the order needs it).
static func pick_node(from: Vector3, item: StringName, nodes: Array, danger: Array) -> HarvestNode:
	var best: HarvestNode = null
	var best_d := INF
	var safe: HarvestNode = null
	var safe_d := INF
	for n in nodes:
		var h := n as HarvestNode
		if h == null or h.depleted or not h.is_inside_tree():
			continue
		var d := from.distance_squared_to(h.global_position)
		if d >= safe_d or not offers(h, item):
			continue
		if d < best_d:
			best = h
			best_d = d
		var clear := true
		for t: Array in danger:
			clear = clear and h.global_position.distance_to(t[0]) > float(t[1])
		if clear:
			safe = h
			safe_d = d
	return safe if safe else best

static func offers(h: HarvestNode, item: StringName) -> bool:
	for o: Dictionary in h.options():
		if StringName(str(o.get("item", ""))) == item and not o.has("blocked_reason"):
			return true
	return false

## Screen-space aim point of a world target: a node's trunk (where the radial anchors), a creature's
## body, a station's top.
static func aim_point(n: Node3D) -> Vector3:
	if n is HarvestNode:
		return n.global_position + Vector3.UP * (n as HarvestNode).top_of_node() * 0.45
	if n is Creature and (n as Creature).def:
		return n.global_position + Vector3.UP * (n as Creature).def.height_meters * 0.6
	return n.global_position + Vector3.UP * 0.6

## World.guide_done from a save: the saved list, or (older saves, no field) every order before the
## saved one, so a returning player is not walked back through orders already finished.
static func done_from_save(data: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var saved: Variant = data.get("guide_done", null)
	if saved is Array:
		for v: Variant in saved:
			out.append(str(v))
		return out
	for i in int(data.get("objective", 0)):
		out.append(str(Objectives.step(i).get("id", "")))
	return out
