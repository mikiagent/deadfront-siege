class_name PlayerRegistry
extends RefCounted
## Every survivor in the scene, and the one place that answers "which player?". AI, pets, kill
## credit and UI ask here instead of taking the first node in the group (net-single-04), so a
## second survivor (W3 online) needs no change at the call sites. Offline there is exactly one.

const GROUP := &"player"

static func all() -> Array[Player]:
	var out: Array[Player] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for n in tree.get_nodes_in_group(GROUP):
		if n is Player:
			out.append(n as Player)
	return out

## The survivor this client controls. shortcut: the first one in the group; when W3 adds remote
## survivor replicas, keep them out of GROUP or give Player a remote flag and skip it here.
static func local() -> Player:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(GROUP) as Player if tree else null

## Nearest living survivor within max_d of pos (AI targeting, area effects, kill credit).
static func nearest(pos: Vector3, max_d: float = INF) -> Player:
	var best: Player = null
	var best_d := max_d
	for p in all():
		if p.dead:
			continue
		var d := p.global_position.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = p
	return best

## The survivor a pet is bonded to (its record is in their bonded list), or null for wild animals.
static func owner_of(c: Creature) -> Player:
	if c == null or c.pet_record == null:
		return null
	for p in all():
		if p.bonded.has(c.pet_record):
			return p
	return null

## Who earns credit for something `source` did: a survivor, the owner of a pet, else null.
static func credit_for(source: Object) -> Player:
	if source is Player:
		return source as Player
	if source is Creature:
		return owner_of(source as Creature)
	return null
