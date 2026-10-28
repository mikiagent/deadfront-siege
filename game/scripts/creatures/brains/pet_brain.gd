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

## NATURES: how far a guarding pet looks for threats (9 m today), widened by guard_radius_mult
## (Loyal, Aggressive). With protect_owner the threat is measured from the OWNER as well, so a pet
## answers anything closing on its owner even from across the camp.
func guard_radius(player: Player) -> float:
	var r := 9.0 * creature.nature_knob("guard_radius_mult", 1.0)
	return r

func _threat_distance(c: Creature, player: Player) -> float:
	var d := c.global_position.distance_to(creature.global_position)
	if creature.nature_flag("protect_owner"):
		d = minf(d, c.global_position.distance_to(player.global_position))
	return d

## NATURES: a pet badly hurt drops its fight (retreat_fraction). Its nature can keep it in it:
## protect_rider_below_hp (Brave) while its owner is riding it and its HP is under that fraction.
func nature_keeps_fighting() -> bool:
	var rider_below := creature.nature_knob("protect_rider_below_hp", 0.0)
	if rider_below <= 0.0:
		return false
	var owner := PlayerRegistry.owner_of(creature)
	if owner == null or owner.mounted_on != creature:
		return false
	return creature.health.fraction() < rider_below

## How far from its owner the pet stands: the follow offset and the distance at which it stops
## walking, both scaled by follow_dist_mult (Loyal stands closer).
func nature_stop_distance() -> float:
	var heel := mode == &"heel"
	return (1.6 if heel else 2.4) * creature.nature_knob("follow_dist_mult", 1.0)

func _pick_guard_target(player: Player) -> Creature:
	if player.hunt and player.hunt.target and is_instance_valid(player.hunt.target) and not player.hunt.target.health.dead:
		return player.hunt.target
	var best: Creature = null
	var best_d := guard_radius(player)
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.is_pet or c.health.dead or c.brain == null:
			continue
		if not c.brain.has_method("hunting_player") or not c.brain.hunting_player():
			continue
		var d := _threat_distance(c, player)
		if d < best_d:
			best_d = d
			best = c
	return best

func _think(delta: float) -> void:
	# PetBrain owns its think loop, so it must also advance the inherited attack cooldown.
	# Without this, a SIC order lands exactly one bite and _attack_cd stays at 1.2 forever.
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var player := PlayerRegistry.owner_of(creature)
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
	# NATURES: a badly hurt pet stands down, unless its nature keeps it fighting for its rider.
	if target and creature.health.fraction() < retreat_fraction() and not nature_keeps_fighting():
		target = null
	if target:
		attack_target = target
		var dist := creature.global_position.distance_to(target.global_position)
		if dist > 45.0:
			target = null
		else:
			# Reach is measured to the target's body: a raptor can bite a triceratops' flank.
			var reach := maxf(1.2, float(profile.get("attack_range", 1.8)) + 0.2) + _size_excess(target)
			# Use a wider exit threshold than entry. Without hysteresis, contact separation nudges the
			# pet a few centimetres outside reach after a bite and it oscillates instead of reattacking.
			var attack_exit := reach + 0.65
			if state != &"attack" and dist > reach:
				_set_state(&"chase")
				creature.move_to(target.global_position)
				creature.face_towards(target.global_position, delta)
			elif dist > attack_exit:
				_set_state(&"chase")
				creature.move_to(target.global_position)
				creature.face_towards(target.global_position, delta)
			else:
				_set_state(&"attack")
				_do_attack()
			return
	attack_target = null
	_set_state(&"alert" if mode == &"heel" else &"roam")
	var side := player.global_basis.x * (1.2 if mode == &"heel" else 1.6) * creature.nature_knob("follow_dist_mult", 1.0)
	var follow := player.global_position + side
	if creature.global_position.distance_to(follow) > nature_stop_distance():
		creature.move_to(follow)
	else:
		creature.stop_move()
