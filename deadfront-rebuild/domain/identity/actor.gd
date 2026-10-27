## A minimal persistent actor reference. M0 has no character stats, progression,
## vitals or combat: an actor exists only so a command carries a stable,
## resolvable "who asked" ID and so tests can prove typed IDs are unique across
## kinds. Later milestones attach real aggregate state behind the same ID.
class_name Actor
extends RefCounted

var id: EntityId
var label: String


static func create(p_id: EntityId, p_label: String) -> Actor:
	if p_id == null:
		push_error("Actor.create: null id")
		return null
	var actor: Actor = Actor.new()
	actor.id = p_id
	actor.label = p_label
	return actor
