extends "res://tests/heavyblade_checks.gd"
## HEAVY BLADES: the two-handed Steel Greatblade (owner: "two handed drags on the ground, you lift it over your head and
## slam it down on the target. also sweep attack that is similar to swinging a bat and bringing it back"). Checks in
## heavyblade_checks.gd: craft, equip, the drag carry, the chain slam -> sweep with both fists on the grip and the hitbox
## on the blade, a Wound from the sweep on a velociraptor, an Armor break from the slam on the stegosaurus plates, and a
## live auto-attack.
## Usage: godot --headless --path game --script res://tests/t_heavyblade_2h.gd -> "[t_heavyblade_2h] PASS", exit 0.

func _setup() -> void:
	tag = "t_heavyblade_2h"
	item = &"steel_greatblade"
	chain = [&"wpn_2h_slam", &"wpn_2h_sweep"]
	wound_move = &"wpn_2h_sweep"
	break_move = &"wpn_2h_slam"
	break_species = &"stegosaurus"
	break_section = &"plates"
	two_handed = true
	materials = [["steel_ingot", 8], ["branch", 3], ["hide_strap", 4]]
