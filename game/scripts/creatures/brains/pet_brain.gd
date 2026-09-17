class_name PetBrain
extends CreatureBrain
## Follow the owner. Attack what they attack. Hold body-blocks. Starved pets skip combat.

var hold: bool = false

func _think(delta: float) -> void:
	var player := creature.get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	hold = player.hunt != null and player.hunt.hold
	if hold:
		state = &"alert"
		var block := player.global_position + -player.global_basis.z * 1.4
		creature.move_to(block)
		return
	if player.hunt and player.hunt.target and creature.hunger > 0.0:
		attack_target = player.hunt.target
		var dist := creature.global_position.distance_to(attack_target.global_position)
		state = &"chase" if dist > 2.0 else &"attack"
		if dist > 2.0:
			creature.move_to(attack_target.global_position)
		else:
			_do_attack()
		return
	state = &"roam"
	var follow := player.global_position + player.global_basis.x * 1.6
	if creature.global_position.distance_to(follow) > 2.2:
		creature.move_to(follow)
	else:
		creature.stop_move()
