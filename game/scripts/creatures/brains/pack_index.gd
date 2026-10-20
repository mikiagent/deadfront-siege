class_name PackIndex
extends RefCounted
## Live wild members of every pack, strongest first. One group scan + sort per physics frame
## for all packs (it was a scan + sort per call, several calls per brain per think).

static var _index: Dictionary = {} ## pack_id -> Array[Creature]
static var _frame: int = -1

## Shared read-only list; callers must not modify it.
static func members(creature: Creature) -> Array[Creature]:
	var none: Array[Creature] = []
	if creature == null or creature.pack_id <= 0 or not creature.is_inside_tree():
		return none
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_index.clear()
		for n in creature.get_tree().get_nodes_in_group("creatures"):
			var c := n as Creature
			if c == null or c.pack_id <= 0 or c.is_pet or c.health == null or c.health.dead:
				continue
			if not _index.has(c.pack_id):
				var fresh: Array[Creature] = []
				_index[c.pack_id] = fresh
			(_index[c.pack_id] as Array[Creature]).append(c)
		for id in _index:
			(_index[id] as Array[Creature]).sort_custom(stronger)
	var live: Array[Creature] = _index.get(creature.pack_id, none)
	# A member can be freed inside the frame this list was built in (island unload, despawn); callers
	# read c.brain without is_instance_valid, so drop the stale entries before handing it out.
	var kept := live.filter(func(c: Creature) -> bool: return is_instance_valid(c))
	if kept.size() != live.size():
		_index[creature.pack_id] = kept
	return kept

## Forget this frame's lists (tests that build and free packs inside one frame).
static func invalidate() -> void:
	_frame = -1

## Alpha means strongest, not first spawned. Tier dominates, then combat stats break ties.
static func stronger(a: Creature, b: Creature) -> bool:
	var sa := float(a.def.tier) * 1000000.0 + a.health.max_hp * 100.0 + a.def.attack * 10.0 + a.def.defense
	var sb := float(b.def.tier) * 1000000.0 + b.health.max_hp * 100.0 + b.def.attack * 10.0 + b.def.defense
	if not is_equal_approx(sa, sb):
		return sa > sb
	return a.get_instance_id() < b.get_instance_id()
