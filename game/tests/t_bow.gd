extends SceneTree
## THE BOW (PARTCOMBAT): the PRO-Class Bow, the bow on the Steel Greatblade's rung. Checks:
## 1. craft: the bow and arrows from existing materials (recipes with their skill node learned);
## 2. equip: the bow rides her LEFT hand, its carry clip at idle and the aim clip once she has a target; the fight
##    lab's WEAPON button reaches it (with arrows);
## 3. fire: Hunt.fire_ranged draws (wpn_bow_draw), looses (wpn_bow_release), spends one arrow, and the arrow (faster than a
##    stone) flies at the picked body section and hits it through the hurtboxes, piercing.
## Usage: godot --headless --path game --script res://tests/t_bow.gd -> "[t_bow] PASS", exit 0.

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var IS: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_bow] %s %s" % ["ok  " if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _craft(id: StringName) -> Variant:
	var C: GDScript = load("res://scripts/items/crafting.gd")
	var rec: Dictionary = C.recipe(id)
	_expect(not rec.is_empty() and C.progression_block(player, rec) == "", "%s: recipe (%s) unlocked" % [id, rec.get("station", "by hand")])
	var picks: Array[int] = C.default_picks(player.inventory, rec)
	_expect(C.picks_valid(player.inventory, rec, picks), "%s: the materials fill it" % id)
	var parts: Array = C.consume_for_craft(player.inventory, rec, picks)
	var levels: Array[int] = []
	for p in parts:
		for i in p.count:
			levels.append(p.level)
	var out = C.build_output(rec, parts[0], C.crafted_level_for(rec, levels, player), parts)
	_expect(out != null and out.def_id == id, "%s crafted x%d" % [id, out.count if out else 0])
	player.inventory.add(out)
	return out

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	root.get_node("Game").debug_overlay = false
	var CT: GDScript = load("res://scripts/combat/combat_tuning.gd")
	CT.force_dodge = 0.0
	CT.force_accuracy = 1.0
	load("res://scripts/combat/hunt.gd").shot_rng.seed = 7
	host = Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await _frames(3)
	if player.station_craft == null:
		player.view.setup_ui()
	for tree in player.skills.trees:
		player.skills.trees[tree]["level"] = 60
		player.skills.trees[tree]["unlocked"].append("bow_1")
	player.inventory = load("res://scripts/items/inventory.gd").new()
	for m in [["raptor_bone", 3], ["steel_ingot", 1], ["bowstring", 1], ["branch", 4], ["stone", 4]]:
		player.inventory.add(IS.make(StringName(m[0]), int(m[1]), {}, 30))
	var bow = _craft(&"pro_bow")
	_craft(&"arrow")
	_craft(&"arrow")
	var arrows: int = player.inventory.count_of(&"arrow")
	_expect(arrows == 10, "10 arrows in the bag (%d)" % arrows)
	_expect(bow.def().damage_type == &"piercing" and bow.def().ammo_id == &"arrow", "the bow pierces and shoots arrows")
	player.inventory.equip(load("res://scripts/items/inventory.gd").slot_for(bow.def()), &"pro_bow")
	player.station_craft._sync_hand_tool()
	player.anim.sync_carry()
	await _frames(2)
	var held: Array = player.find_children("HeldWeapon", "", true, false)
	_expect(not held.is_empty() and held[0].get_parent() == player.left_hand_anchor(), "the bow is in her left hand")
	var ap: AnimationPlayer = player.rig.anim_player
	_expect(ap.get_animation(&"idle") == ap.get_animation(&"wpn_bow_carry_idle"), "idle plays the bow carry")

	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = Vector3(0, 0, -10)
	c.spawn(root.get_node("Data").creature(&"velociraptor"))
	c.health.setup(1e9)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.look_at(Vector3(player.global_position.x, c.global_position.y, player.global_position.z), Vector3.UP)
	await _frames(4)
	player.hunt.auto = false
	c.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z - 10.0)
	c.look_at(Vector3(player.global_position.x, 0.0, player.global_position.z), Vector3.UP)
	await _frames(2)
	if root.get_node("World").runtime == null:
		root.get_node("World").runtime = host  # shots fly in the world runtime
	player.hunt.start(c)
	player.hunt.set_aim_section(&"torso")
	player.anim.sync_carry()
	_expect(ap.get_animation(&"idle") == ap.get_animation(&"wpn_bow_aim"), "with a target, idle is the aim hold")
	_expect(c.get_node_or_null("SectionHighlight") != null, "the picked section glows on the animal")
	var hp0: float = c.health.hp
	var landed := [{}]
	var clips := []
	var hook := func(n: Node) -> void:
		if n.has_signal(&"landed") and "aimed_section" in n:  # a StoneProjectile (untyped: tests compile before autoloads)
			n.landed.connect(func(r: Dictionary) -> void: landed[0] = r)
	host.get_tree().node_added.connect(hook)
	var fired: bool = player.hunt.fire_ranged()
	_expect(fired, "fire_ranged looses (%s; busy=%s cd=%.2f clip=%s)" % [player.hunt.last_notice, player.anim._busy, player.hunt._swing_cd, player.anim.current_clip])
	var f := 0
	while landed[0].is_empty() and f < 180:
		if clips.is_empty() or clips[-1] != player.anim.current_clip:
			clips.append(player.anim.current_clip)
		await physics_frame
		f += 1
	_expect(&"wpn_bow_draw" in clips and &"wpn_bow_release" in clips, "she draws and releases (%s)" % [clips])
	_expect(player.inventory.count_of(&"arrow") == arrows - 1, "one arrow spent")
	var r: Dictionary = landed[0]
	_expect(r.get("victim") == c, "the arrow hits the velociraptor (%s, %s)" % [r.get("section", "-"), r.get("part", "-")])
	_expect(r.get("section", &"") != &"", "it hit a body section through the hurtboxes (%s)" % r.get("section", "-"))
	_expect(c.health.hp < hp0, "it deals damage (%.1f)" % (hp0 - c.health.hp))

	# The fight lab's WEAPON button reaches the bow (and hands over arrows).
	player.inventory = load("res://scripts/items/inventory.gd").new()
	var panel = load("res://scripts/dev/lab_spawn_panel.gd").new()
	root.add_child(panel)
	panel.setup(player)
	var got := []
	for i in 4:
		got.append(panel.next_weapon())
		var eq = player.inventory.equipped_weapon()
		_expect((eq.def_id if eq else &"") == got[-1], "fight lab WEAPON -> %s equipped" % got[-1])
	_expect(got == [&"iron_slab_blade", &"steel_greatblade", &"pro_bow", &"iron_slab_blade"], "the fight lab cycles both blades and the bow (%s)" % [got])
	_expect(player.inventory.count_of(&"arrow") >= 50, "the lab hands over arrows with the bow")
	print("[t_bow] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)
