class_name Health
extends Node
## Hit points for a creature. At zero the owner dies and leaves a corpse.

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died(source: Node)

var max_hp: float = 100.0
var hp: float = 100.0
var dead: bool = false

func setup(p_max: float) -> void:
	max_hp = p_max
	hp = p_max
	dead = false

func take_damage(amount: float, source: Node = null) -> float:
	if dead:
		return 0.0
	var dealt := maxf(0.0, amount)
	hp = maxf(0.0, hp - dealt)
	damaged.emit(dealt, source)
	if hp <= 0.0:
		dead = true
		died.emit(source)
	return dealt

func heal(amount: float) -> void:
	if dead:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	var gained := hp - before
	if gained > 0.0:
		healed.emit(gained)

func fraction() -> float:
	return hp / maxf(1.0, max_hp)
