extends Node3D
## M10 acceptance: occupation seed, XP → a character level-up with SP, unlock, save/load round trip.

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
	# W2-SKILLS: SP come from character levels (spec 03). Gathering XP (every skill gain is World XP
	# too) earns the next character level and its SP; one SP buys Till Small Field (Farming Lv. 1).
	var lv := sk.character_level()
	var sp := sk.sp_available
	var paid := sk.sp_for_level(lv + 1)
	sk.add_xp("gathering", float(World.xp_for_level(World.pioneer_level) - World.pioneer_xp))
	print("[skill] character level %d gathering level=%d sp=%d" % [sk.character_level(), sk.level_of("gathering"), sk.sp_available])
	var ok := sk.character_level() == lv + 1 and sk.sp_available == sp + paid
	ok = sk.unlock("farming", "small_field") and sk.sp_available == sp + paid - 1 and ok
	var copy := SkillState.new()
	add_child(copy)
	copy.from_dict(sk.to_dict())
	print("[skill] roundtrip construction=%d gathering=%d farming owned=%s sp=%d" % [copy.level_of("construction"), copy.level_of("gathering"), copy.trees["farming"]["unlocked"], copy.sp_available])
	ok = ok and copy.level_of("construction") == 20 and copy.is_unlocked("farming", "small_field") and copy.sp_available == sp + paid - 1
	print("[skill] %s level-up pays %d SP, small_field bought" % ["PASS" if ok else "FAIL", paid])
	get_tree().quit(0 if ok else 1)
