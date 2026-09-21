class_name PetBrain
extends CreatureBrain
## Pet orders (whistles): "guard" (default) follows the owner and fights whatever the owner
## fights or whatever hunts the owner; "attack" goes for one ordered target until it is dead;
## "heel" stays at the owner's side and does not fight. A hungry pet still fights, just slower.

var hold: bool = false
var mode: StringName = &"guard"
var order_target: Creature

func order(cmd: StringName, target: Creature = null) -> void:
	mode = cmd
	order_target = target if cmd == &"attack" else null
	print("[pet] %s order %s%s" % [creature.def.id, cmd, (" -> " + str(target.def.id)) if target else ""])

func _pick_guard_target(player: Player) -> Creature:
	if player.hunt and player.hunt.target and is_instance_valid(player.hunt.target) and not player.hunt.target.health.dead:
		return player.hunt.target
	var best: Creature = null
	var best_d := 9.0
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.is_pet or c.health.dead or c.brain == null:
			continue
		if not c.brain.has_method("hunting_player") or not c.brain.hunting_player():
			continue
		var d := c.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best

func _think(delta: float) -> void:
	# PetBrain owns its think loop, so it must also advance the inherited attack cooldown.
	# Without this, a SIC order lands exactly one bite and _attack_cd stays at 1.2 forever.
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var player := creature.get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	hold = player.hunt != null and player.hunt.hold
	var target: Creature = null
	if mode == &"attack":
		if order_target and is_instance_valid(order_target) and not order_target.health.dead:
			target = order_target
		else:
			mode = &"guard"
			order_target = null
	if mode == &"guard" and not hold:
		target = _pick_guard_target(player)
	if target:
		attack_target = target
		var dist := creature.global_position.distance_to(target.global_position)
		if dist > 45.0:
			target = null
		else:
			var reach := maxf(1.2, float(profile.get("attack_range", 1.8)) + 0.2)
			state = &"chase" if dist > reach else &"attack"
			if dist > reach:
				creature.move_to(_pet_attack_slot(target, reach))
				creature.face_towards(target.global_position, delta)
			else:
				_do_attack()
			return
	attack_target = null
	state = &"alert" if mode == &"heel" else &"roam"
	var side := player.global_basis.x * (1.2 if mode == &"heel" else 1.6)
	var follow := player.global_position + side
	if creature.global_position.distance_to(follow) > (1.6 if mode == &"heel" else 2.4):
		creature.move_to(follow)
	else:
		creature.stop_move()

func _pet_attack_slot(target: Creature, reach: float) -> Vector3:
	var away := creature.global_position - target.global_position
	away.y = 0.0
	if away.length_squared() <= 0.001:
		away = Vector3.BACK
	var slot := target.global_position + away.normalized() * reach
	# Repel this slot from other live pets. This keeps several SIC attackers from selecting the
	# same contact point even before CharacterBody collision / local steering is involved.
	var separation := Vector3.ZERO
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var other := n as Creature
		if other == null or other == creature or not other.is_pet or other.health.dead:
			continue
		var from_other := slot - other.global_position
		from_other.y = 0.0
		var d := from_other.length()
		if d < 2.0:
			separation += (from_other.normalized() if d > 0.01 else Vector3.RIGHT * _flank_sign) * (2.0 - d)
	return slot + separation
