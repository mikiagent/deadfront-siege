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
	var r := LabResult.new("skills")
	await get_tree().process_frame
	var sk := _player.skills
	var construction_before := sk.level_of("construction")
	var sp_before := sk.sp_available
	sk.apply_occupation("office_worker")
	print("[skill] construction %d" % sk.level_of("construction"))
	r.expect(sk.level_of("construction") > construction_before, "occupation seeds its skill")
	r.expect(sk.sp_available > sp_before, "occupation grants skill points")
	var lv_before := sk.level_of("gathering")
	var xp_before := sk.xp_of("gathering")
	for i in 10:
		sk.add_xp("gathering", 2)
	print("[skill] gathering level=%d xp=%.0f sp=%d" % [sk.level_of("gathering"), sk.xp_of("gathering"), sk.sp_available])
	r.expect(sk.level_of("gathering") > lv_before or (sk.level_of("gathering") == lv_before and sk.xp_of("gathering") > xp_before), "gathering XP accrues")
	var sp_before_unlock := sk.sp_available
	sk.unlock("gathering", "forage_1")
	r.expect("forage_1" in sk.trees["gathering"]["unlocked"], "unlock is recorded")
	r.expect(sk.sp_available < sp_before_unlock, "unlock spends skill points")
	var d := sk.to_dict()
	var copy := SkillState.new()
	add_child(copy)
	copy.from_dict(d)
	print("[skill] roundtrip construction=%d gathering=%d owned=%s sp=%d" % [copy.level_of("construction"), copy.level_of("gathering"), copy.trees["gathering"]["unlocked"], copy.sp_available])
	for tree_id in sk.trees:
		r.expect(copy.level_of(tree_id) == sk.level_of(tree_id), "roundtrip keeps %s level" % tree_id)
	r.expect(copy.sp_available == sk.sp_available, "roundtrip keeps skill points")
	r.expect(copy.trees["gathering"]["unlocked"] == sk.trees["gathering"]["unlocked"], "roundtrip keeps unlocks")
	print("[skill] character level %d" % sk.character_level())
	r.expect(sk.character_level() >= 1, "character level is at least 1")
	r.finish(get_tree(), "construction=%d gathering=%d sp=%d" % [sk.level_of("construction"), sk.level_of("gathering"), sk.sp_available])
