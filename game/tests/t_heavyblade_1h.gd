extends "res://tests/heavyblade_checks.gd"
## HEAVY BLADES: the one-handed Iron Slab Blade (owner: "one-handed is a cross slash 3 combo, last is powerful. impale
## thrust with blade attack. impale and pull up out of target, prepare for the next attack, heavy chop"). Checks in
## heavyblade_checks.gd: craft, equip, the drag carry, the chain cross1 -> cross2 -> cross3 -> impale -> chop with the
## hitbox on the blade, a Wound from the slashes on a velociraptor, an Armor break from the chop on an ankylosaurus back,
## and a live auto-attack.
## Usage: godot --headless --path game --script res://tests/t_heavyblade_1h.gd -> "[t_heavyblade_1h] PASS", exit 0.

func _setup() -> void:
	tag = "t_heavyblade_1h"
	item = &"iron_slab_blade"
	chain = [&"wpn_1h_cross1", &"wpn_1h_cross2", &"wpn_1h_cross3", &"wpn_1h_impale", &"wpn_1h_chop"]
	wound_move = &"wpn_1h_cross1"
	break_move = &"wpn_1h_chop"
	break_species = &"ankylosaurus"
	break_section = &"torso"
	materials = [["iron_ingot", 5], ["branch", 2], ["hide_strap", 3]]
