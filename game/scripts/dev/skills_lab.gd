extends Node3D
## M10 acceptance: occupation seed, XP → level-ups with SP, unlock, save/load round trip.

var _player: Player

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	print("[boot] lab=skills_lab")
	if DisplayServer.get_name() == "headless":
		call_deferred("_demo")

func _demo() -> void:
	await get_tree().process_frame
	var sk := _player.skills
	sk.apply_occupation("office_worker")
	print("[skill] construction %d" % sk.level_of("construction"))
	for i in 10:
		sk.add_xp("gathering", 2)
	print("[skill] gathering level=%d xp=%.0f sp=%d" % [sk.level_of("gathering"), sk.xp_of("gathering"), sk.sp_available])
	sk.unlock("gathering", "forage_1")
	var d := sk.to_dict()
	var copy := SkillState.new()
	add_child(copy)
	copy.from_dict(d)
	print("[skill] roundtrip construction=%d gathering=%d owned=%s sp=%d" % [copy.level_of("construction"), copy.level_of("gathering"), copy.trees["gathering"]["unlocked"], copy.sp_available])
	print("[skill] character level %d" % sk.character_level())
	get_tree().quit(0)
