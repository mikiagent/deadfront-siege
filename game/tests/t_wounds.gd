extends SceneTree
## WOUNDS AND ARMOR BREAKS (owner: "Melee weapons should make their own crits by attacking and focusing the same body part").
## Through Hunt.land_hit with a hit on a body section (the code every survivor swing runs):
## 1. slash hits on one skin section form a Wound at wound_at: the WOUND! float, a gash decal, the bleed; every hit on that
##    section afterwards is a sure crit at wound_mult (float kind wound); a hit elsewhere is not;
## 2. impact hits on an armoured section (ankylosaurus back) first take armour_mult of the damage, form an Armor break at
##    break_at (the ARMOR BREAK! float, a crack decal), and then the same hit deals full damage;
## 3. switching sections keeps only switch_keep of the old section's build, and idle time decays it;
## 4. pierce builds at pierce_rate; the fight clears it all after fight_s.
## Usage: godot --headless --path game --script res://tests/t_wounds.gd -> "[t_wounds] PASS", exit 0.

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var BS: GDScript
var BW: GDScript
var floats: Array = []

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_wounds] %s %s" % ["ok  " if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	BS = load("res://scripts/combat/body_sections.gd")
	BW = load("res://scripts/combat/body_wounds.gd")
	root.get_node("Game").debug_overlay = false
	var CT: GDScript = load("res://scripts/combat/combat_tuning.gd")
	CT.force_dodge = 0.0
	CT.force_accuracy = 1.0
	var tune: Dictionary = CT.section("player_melee")
	tune["crit_base"] = 0.0
	tune["crit_behind"] = 0.0
	tune["crit_per_melee_level"] = 0.0
	tune["blunt_groggy_chance"] = 0.0
	tune["slashing_bleed_chance"] = 0.0
	host = Node3D.new()
	root.add_child(host)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(40, 0.9, 40)
	host.add_child(player)
	await _frames(3)
	var cfg: Dictionary = BW.cfg()
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	var knife = IS.make(&"stone_knife")
	var club = IS.make(&"club")

	# 1. Wound on skin.
	var c = await _spawn(&"velociraptor")
	var plain: Array = _hit(c, knife, &"tail")  # tail first: the torso test then starts on a fresh section
	c.get_node("BodyWounds").clear()
	var base_torso: Array = _hit(c, knife, &"torso")
	c.get_node("BodyWounds").clear()
	var n := int(ceil(float(cfg["wound_at"])))
	for i in n - 1:
		_hit(c, knife, &"torso")
	_expect(not BW.has(c, &"torso", BW.WOUND), "velociraptor: %d slash hits on the torso: no Wound yet" % (n - 1))
	floats.clear()
	_hit(c, knife, &"torso")
	_expect(BW.has(c, &"torso", BW.WOUND), "velociraptor: slash hit %d on the torso forms a Wound" % n)
	_expect(&"wound_formed" in floats, "the WOUND! float shows when it forms (%s)" % [floats])
	_expect(c.statuses.has(StringName(str(cfg["bleed"]))), "the Wound bleeds (%s)" % cfg["bleed"])
	_expect(_decal(c, "WoundDecal"), "a gash decal rides the body")
	c.statuses.clear_all()
	var crit: Array = _hit(c, knife, &"torso")
	_expect(crit[1] == &"wound" and is_equal_approx(crit[0], base_torso[0] * float(cfg["wound_mult"])), "a hit on the Wound is a sure crit x%.1f (%.2f -> %.2f, %s)" % [cfg["wound_mult"], base_torso[0], crit[0], crit[1]])
	c.statuses.clear_all()
	var other: Array = _hit(c, knife, &"tail")
	_expect(other[1] != &"wound" and is_equal_approx(other[0], plain[0]), "a hit on the tail is not (%.2f, %s)" % [other[0], other[1]])
	c.queue_free()

	# 2. Armor break on the ankylosaurus back.
	var a = await _spawn(&"ankylosaurus")
	_expect(BS.is_armoured(a, &"torso"), "ankylosaurus torso (its back) is armoured")
	var unarmoured: Array = _hit(a, club, &"belly")  # the same blow on its soft belly
	a.get_node("BodyWounds").clear()
	a.statuses.clear_all()
	var armoured: Array = _hit(a, club, &"torso")
	a.get_node("BodyWounds").clear()
	a.statuses.clear_all()
	var mult := float(BS.cfg().get("armour_mult", 0.25))
	_expect(armoured[1] == &"armoured" and is_equal_approx(armoured[0], unarmoured[0] * mult), "unbroken armour takes x%.2f (%.2f vs %.2f on the belly)" % [mult, armoured[0], unarmoured[0]])
	floats.clear()
	var k := 0
	while not BW.has(a, &"torso", BW.BREAK) and k < 10:
		_hit(a, club, &"torso")
		a.statuses.clear_all()
		k += 1
	_expect(BW.has(a, &"torso", BW.BREAK) and k == int(ceil(float(cfg["break_at"]))), "%d impact hits crack the armour (Armor break)" % k)
	_expect(&"armor_break" in floats, "the ARMOR BREAK! float shows (%s)" % [floats])
	_expect(_decal(a, "ArmorBreakDecal"), "a crack decal rides the body")
	var broken: Array = _hit(a, club, &"torso")
	_expect(is_equal_approx(broken[0], unarmoured[0]) and broken[0] > armoured[0] * 3.9, "through the Armor break the damage rises to full (%.2f -> %.2f)" % [armoured[0], broken[0]])
	_expect(not BW.has(a, &"torso", BW.WOUND), "impact never cuts a Wound")
	a.queue_free()

	# 3. Switching sections and idling decay the build.
	var r = await _spawn(&"velociraptor")
	_hit(r, knife, &"torso")
	_hit(r, knife, &"torso")
	var w = r.get_node("BodyWounds")
	_expect(is_equal_approx(w.level(&"torso", BW.WOUND), 2.0), "two torso hits build 2.0")
	_hit(r, knife, &"tail")
	var keep := float(cfg["switch_keep"])
	_expect(is_equal_approx(w.level(&"torso", BW.WOUND), 2.0 * keep), "a hit on the tail decays the torso to %.2f (%.2f)" % [2.0 * keep, w.level(&"torso", BW.WOUND)])
	_hit(r, knife, &"torso")
	_expect(not BW.has(r, &"torso", BW.WOUND), "after switching, the third torso hit does not open a Wound")
	w.last_hit[&"torso"] = BW.now() - float(cfg["idle_s"]) - 2.0
	_expect(w.level(&"torso", BW.WOUND) < 2.0 * keep + 1.0 - 0.9, "idle past idle_s decays it (%.2f)" % w.level(&"torso", BW.WOUND))

	# 4. Pierce at its rate, and the fight ending clears everything.
	var before: float = w.level(&"neck", BW.WOUND)
	BW.register(r, &"neck", ["pierce"], r.global_position, &"", player)
	_expect(is_equal_approx(w.level(&"neck", BW.WOUND) - before, float(cfg["pierce_rate"])), "a pierce hit builds %.2f" % cfg["pierce_rate"])
	for i in 4:
		_hit(r, knife, &"head")
	_expect(BW.has(r, &"head", BW.WOUND), "a Wound on the head")
	w._last_any = BW.now() - float(cfg["fight_s"]) - 1.0
	var gone: bool = not BW.has(r, &"head", BW.WOUND)
	await _frames(2)
	_expect(gone and not _decal(r, "WoundDecal"), "after %.0f s without a hit the fight is over: Wounds and decals cleared" % cfg["fight_s"])
	r.queue_free()
	print("[t_wounds] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _spawn(id: StringName):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = Vector3(0, 0, -30)
	c.spawn(root.get_node("Data").creature(id))
	c.health.setup(1e9)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.combat_float.connect(func(_a: float, kind: StringName) -> void: floats.append(kind))
	await _frames(3)
	player.global_position = c.global_position + Vector3(0, 0.9, 3.0)
	await _frames(1)
	return c

## One landed swing on a section (its aim point on the capsule there), as Hitbox.strike reports it: [damage, kind].
func _hit(c, w, section: StringName) -> Array:
	var at: Vector3 = BS.aim_point(c, section, false)
	var part: StringName = BS.cap_at(c, at)["part"]
	var seen := [&""]
	var cb := func(_a: float, kind: StringName) -> void: seen[0] = kind
	c.combat_float.connect(cb)
	var hp0: float = c.health.hp
	player.hunt.land_hit(c, w, {}, {"part": part, "surface": at, "at": at})
	c.combat_float.disconnect(cb)
	return [hp0 - c.health.hp, seen[0]]

func _decal(c, name: String) -> bool:
	return not c.find_children(name, "", true, false).is_empty()
