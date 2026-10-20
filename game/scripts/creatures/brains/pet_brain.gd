class_name PetBrain
extends CreatureBrain
## Pet orders. Stance (who it fights): "passive" never fights, "defend" (default; the old
## "guard") fights what the owner fights and whatever hunts the owner or the pet, "aggressive"
## also goes for any hostile wild animal near it. Movement: "follow" (default) keeps to the
## owner's side, "stay" holds the spot it was told to stay on. "attack" goes for one ordered
## target until it is dead; "heel" is passive at the owner's side (old whistle). A hungry pet
## still fights, just slower.

## ASSUMPTION: an aggressive pet picks fights within 9 m of itself; a staying pet chases no
## farther than 12 m from its stay spot.
const AGGRESSIVE_M := 9.0
const STAY_LEASH_M := 12.0

var hold: bool = false
var mode: StringName = &"guard"
var stance: StringName = &"defend"
var staying: bool = false
var stay_point: Vector3 = Vector3.ZERO
var order_target: Creature

func order(cmd: StringName, target: Creature = null) -> void:
	match cmd:
		&"attack":
			mode = &"attack"
			order_target = target
		&"heel":
			mode = &"heel"
			order_target = null
			staying = false
		&"guard", &"defend":
			mode = &"guard"
			stance = &"defend"
			order_target = null
		&"passive", &"aggressive":
			mode = &"guard"
			stance = cmd
			order_target = null
		&"stay":
			staying = true
			stay_point = creature.global_position
		&"follow":
			staying = false
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
		var on_us := c.brain.attack_target == creature or (c.brain.has_method("hunting_player") and c.brain.hunting_player())
		if not on_us:
			continue
		var d := c.global_position.distance_to(player.global_position)
		if c.brain.attack_target == creature:
			d = minf(d, c.global_position.distance_to(creature.global_position))
		if d < best_d:
			best_d = d
			best = c
	return best

## Aggressive: the nearest wild animal near the pet that would fight (not a skittish grazer).
func _pick_aggressive_target() -> Creature:
	var best: Creature = null
	var best_d := AGGRESSIVE_M
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.is_pet or c.health.dead or c.brain == null:
			continue
		if c.brain._flees_on_sight():
			continue
		var d := c.global_position.distance_to(creature.global_position)
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
	if mode == &"guard" and not hold and stance != &"passive":
		target = _pick_guard_target(player)
		if target == null and stance == &"aggressive":
			target = _pick_aggressive_target()
	if target and staying and mode != &"attack" and target.global_position.distance_to(stay_point) > STAY_LEASH_M:
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
	if staying:
		_set_state(&"stay")
		if creature.global_position.distance_to(stay_point) > 1.5:
			creature.move_to(stay_point)
		else:
			creature.stop_move()
		return
	_set_state(&"alert" if mode == &"heel" else &"roam")
	var side := player.global_basis.x * (1.2 if mode == &"heel" else 1.6)
	var follow := player.global_position + side
	if creature.global_position.distance_to(follow) > (1.6 if mode == &"heel" else 2.4):
		creature.move_to(follow)
	else:
		creature.stop_move()
