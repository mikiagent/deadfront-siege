class_name CombatAvoid
## The one place an attack is decided avoided: a roll's i-frames, a dodge-chance miss, a block.
## It floats "Dodged" / "Blocked" over the defender (survivor or creature). Anything else that should
## follow an avoided hit (Defense XP from dodges/blocks, claude/mmo-slowlevels) hooks in here.

const TEXT := {&"dodge": "Dodged", &"block": "Blocked"}
const COLOR := Color(0.82, 0.82, 0.82)
const PX := 17  # under a hit's 22 px number: an avoided hit reads quieter than damage

## `how` is &"dodge" or &"block". `attacker` may be null (a projectile whose thrower is gone).
## `earned`: the survivor's own action avoided a hit that would have landed. Only then does it train
## Defense (owner 2026-10-28: "defense skill should only be levelled up by successful dodge, block,
## etc"); an accuracy miss or a roll through an attack that would have missed anyway pays nothing.
static func avoided(defender: Node, attacker: Node, how: StringName = &"dodge", earned: bool = true) -> void:
	if earned and defender is Player and (defender as Player).skills:
		(defender as Player).skills.add_xp("defense", RollRules.defense_xp())
	if defender is Creature:
		(defender as Creature).combat_float.emit(0.0, how)
	elif defender is Player and defender.is_inside_tree():
		var hud := defender.get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("avoid_on_player"):
			hud.avoid_on_player(str(TEXT.get(how, "Dodged")))
	print("[combat] avoided %s by %s from %s" % [how, defender.name, attacker.name if attacker else "?"])
