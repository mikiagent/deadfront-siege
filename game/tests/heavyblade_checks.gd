extends SceneTree
## HEAVY BLADES, shared by t_heavyblade_1h and t_heavyblade_2h (each sets the config in _setup). For one blade:
## 1. its recipe crafts it from existing materials (with the recipe's skill node learned) and it equips;
## 2. it shows in her hand(s) while equipped, with its carry clip standing in for idle;
## 3. her swings cycle the weapon's chain of moves, each a clip on the rig with hit windows; the hitbox capsule follows
##    the blade (its tip within reach of the mesh's tip in the clip's hit frame); a two-hander has both fists on the grip;
## 4. each move's channels build what Combat_Math says: slashes a Wound on skin and then a sure crit through it, the
##    impact moves an Armor break on armour and then full damage through it;
## 5. a live auto-attack with it lands through the hitboxes on an animal in front of her.

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var BS: GDScript
var BW: GDScript
var IS: GDScript
var tag := "t_heavyblade"
## Set by the test: the item, the expected chain, the skin test (move, species, section), the armour test, two-handed.
var item := &""
var chain: Array = []
var wound_move := &""
var wound_species := &"velociraptor"
var wound_section := &"torso"
var break_move := &""
var break_species := &"stegosaurus"
var break_section := &"plates"
var two_handed := false
var materials: Array = []

func _setup() -> void:
	pass

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[%s] %s %s" % [tag, "ok  " if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	_setup()
	BS = load("res://scripts/combat/body_sections.gd")
	BW = load("res://scripts/combat/body_wounds.gd")
	IS = load("res://scripts/items/item_stack.gd")
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
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(40, 0.9, 40)
	host.add_child(player)
	await _frames(3)
	if player.station_craft == null:
		player.view.setup_ui()  # the hand model is StationCraft's (the game builds it with the HUD)
	var w = await _craft_and_equip()
	if w == null:
		_finish()
		return
	await _check_held(w)
	await _check_chain(w)
	await _check_build(w)
	await _check_live(w)
	_finish()

func _finish() -> void:
	print("[%s] %s" % [tag, "PASS" if failures.is_empty() else "FAIL %d" % failures.size()])
	quit(0 if failures.is_empty() else 1)

func _craft_and_equip():
	var C: GDScript = load("res://scripts/items/crafting.gd")
	var rec: Dictionary = C.recipe(item)
	_expect(not rec.is_empty(), "%s has a recipe (%s)" % [item, rec.get("station", "by hand")])
	if rec.is_empty():
		return null
	var node := str(rec.get("requires_node", ""))
	for tree in player.skills.trees:
		player.skills.trees[tree]["level"] = 60
		if node != "" and not node in player.skills.trees[tree]["unlocked"]:
			player.skills.trees[tree]["unlocked"].append(node)
	player.inventory = load("res://scripts/items/inventory.gd").new()
	for m in materials:
		player.inventory.add(IS.make(StringName(m[0]), int(m[1]), {}, 30))
	_expect(C.progression_block(player, rec) == "", "%s: the recipe's node is learned (%s)" % [item, C.progression_block(player, rec)])
	var picks: Array[int] = C.default_picks(player.inventory, rec)
	_expect(C.picks_valid(player.inventory, rec, picks), "%s: the materials fill the recipe" % item)
	var parts: Array = C.consume_for_craft(player.inventory, rec, picks)
	var levels: Array[int] = []
	for p in parts:
		for i in p.count:
			levels.append(p.level)
	var out = C.build_output(rec, parts[0], C.crafted_level_for(rec, levels, player), parts)
	_expect(out != null and out.def_id == item, "%s crafted (L%d)" % [item, out.level if out else -1])
	player.inventory.add(out)
	player.inventory.equip(load("res://scripts/items/inventory.gd").slot_for(out.def()), item)
	var eq = player.inventory.equipped_weapon()
	_expect(eq != null and eq.def_id == item, "%s equipped" % item)
	await _frames(4)
	return eq

func _check_held(_w) -> void:
	player.station_craft._sync_hand_tool()  # StationCraft's own _process does this each frame in the game
	player.anim.sync_carry()
	var held: Node3D = null
	for n in player.find_children("HeldWeapon", "", true, false):
		held = n
	_expect(held != null, "%s is in her hand while equipped, out of a fight" % item)
	var row: Dictionary = load("res://scripts/items/held_model.gd").weapon_row(item)
	var carry: Dictionary = row.get("carry", {})
	var ap: AnimationPlayer = player.rig.anim_player
	if carry.has("idle"):
		_expect(ap.get_animation(&"idle") == ap.get_animation(StringName(carry["idle"])), "idle plays the carry clip %s" % carry["idle"])

## The hitbox capsule's world segment for a survivor move at a clip time (from the live bone, as Hitbox bakes it).
func _blade_segment(spec_part: Dictionary) -> Array:
	var sk: Skeleton3D = player.rig.skeleton
	var b := sk.find_bone(str(spec_part["bone"]))
	var g: Transform3D = sk.global_transform * sk.get_bone_global_pose(b)
	var basis := g.basis.orthonormalized()
	var off: Array = spec_part.get("offset", [0, 0, 0])
	var ax: Array = spec_part.get("axis", [1, 0, 0])
	var a: Vector3 = g.origin + basis * Vector3(float(off[0]), float(off[1]), float(off[2]))
	var e: Vector3 = a + basis * Vector3(float(ax[0]), float(ax[1]), float(ax[2])).normalized() * float(spec_part.get("length", 0.0))
	return [a, e]

func _check_chain(w) -> void:
	var HX: GDScript = load("res://scripts/combat/hitbox.gd")
	var seen := []
	for i in chain.size() + 1:
		var mv: Array = player.hunt.swing_move(w)
		seen.append(mv[0])
		player.hunt._chain_i += 1
		player.hunt._chain_at = Time.get_ticks_msec() * 0.001
	player.hunt._chain_i = 0
	_expect(seen.slice(0, chain.size()) == chain and seen[chain.size()] == chain[0], "her swings cycle %s" % [seen])
	var ap: AnimationPlayer = player.rig.anim_player
	var held: Node3D = player.find_children("HeldWeapon", "", true, false)[0]
	for mv in chain:
		var row: Dictionary = player.hunt.move_row(mv)
		var clip := StringName(str(row.get("clip", mv)))
		_expect(ap.has_animation(clip), "%s: clip %s on the rig (%.2f s)" % [mv, clip, ap.get_animation(clip).length if ap.has_animation(clip) else 0.0])
		var baked: Array = HX.baked(player, mv, 0, player.hunt.weapon_class(w.def()))
		_expect(not baked.is_empty() and not (baked[0] as Array).is_empty(), "%s: the blade's hitbox bakes through its window" % mv)
		# The hit frame: the hitbox capsule rides the blade (its far end within 0.35 m of the mesh's tip).
		var hits: Array = row.get("hits", [])
		ap.play(clip)
		ap.seek(ap.get_animation(clip).length * float(hits[0][1]), true)
		ap.speed_scale = 0.0
		await _frames(2)
		var spec: Dictionary = HX.move_spec(player, mv, 0, player.hunt.weapon_class(w.def()))
		var seg := _blade_segment(spec["parts"][0])
		var tip := _mesh_tip(held, seg[0])
		var reach: float = (seg[1] as Vector3).distance_to(tip)
		_expect(reach < 0.35, "%s: at the hit frame the hitbox tip is %.2f m from the blade's tip" % [mv, reach])
		if two_handed:
			var sk: Skeleton3D = player.rig.skeleton
			var lh: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftHand"))).origin
			var rh: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand"))).origin
			var gap := Geometry3D.get_closest_point_to_segment(lh, seg[0] - (seg[1] - seg[0]).normalized() * 0.5, seg[1]).distance_to(lh)
			_expect(gap < 0.15 and lh.distance_to(rh) < 0.45, "%s: both fists on the grip (left wrist %.2f m from the handle, %.2f m from the right)" % [mv, gap, lh.distance_to(rh)])
		ap.speed_scale = 1.0
	ap.stop()

## The point of the held mesh farthest from the fist.
func _mesh_tip(held: Node3D, fist: Vector3) -> Vector3:
	var best := fist
	for mi in held.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var arr: Array = m.mesh.surface_get_arrays(0)
		for v in arr[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var p: Vector3 = m.global_transform * v
			if p.distance_to(fist) > best.distance_to(fist):
				best = p
	return best

func _spawn(id: StringName):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = Vector3(0, 0, -30)
	c.spawn(root.get_node("Data").creature(id))
	c.health.setup(1e9)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	player.global_position = c.global_position + Vector3(0, 0.9, 4.0)
	await _frames(1)
	return c

func _hit(c, w, section: StringName, move: StringName) -> Array:
	var at: Vector3 = BS.aim_point(c, section, false)
	var seen := [&""]
	var cb := func(_a: float, kind: StringName) -> void:
		if kind != &"wound_formed" and kind != &"armor_break":
			seen[0] = kind
	c.combat_float.connect(cb)
	var hp0: float = c.health.hp
	player.hunt.land_hit(c, w, {}, {"part": BS.cap_at(c, at)["part"], "surface": at, "at": at, "move": move})
	c.combat_float.disconnect(cb)
	c.statuses.clear_all()
	return [hp0 - c.health.hp, seen[0]]

func _check_build(w) -> void:
	# Skin: the slashing move opens a Wound; the next hit there is a sure crit.
	var c = await _spawn(wound_species)
	var plain: Array = _hit(c, w, wound_section, wound_move)
	c.get_node("BodyWounds").clear()
	var n := 0
	while not BW.has(c, wound_section, BW.WOUND) and n < 10:
		_hit(c, w, wound_section, wound_move)
		n += 1
	_expect(BW.has(c, wound_section, BW.WOUND), "%s: %d x %s on the %s %s open a Wound" % [item, n, wound_move, wound_species, wound_section])
	var crit: Array = _hit(c, w, wound_section, wound_move)
	_expect(crit[1] == &"wound" and crit[0] > plain[0] * 1.9, "%s: then %s crits through the Wound (%.1f -> %.1f, %s)" % [item, wound_move, plain[0], crit[0], crit[1]])
	c.queue_free()
	# Armour: the impact move cracks it; the next hit there deals full damage.
	var a = await _spawn(break_species)
	_expect(BS.is_armoured(a, break_section), "%s %s is armoured" % [break_species, break_section])
	var first: Array = _hit(a, w, break_section, break_move)
	_expect(first[1] == &"armoured", "%s: %s on unbroken %s is cut by the armour (%.1f)" % [item, break_move, break_section, first[0]])
	var k := 1
	while not BW.has(a, break_section, BW.BREAK) and k < 10:
		_hit(a, w, break_section, break_move)
		k += 1
	_expect(BW.has(a, break_section, BW.BREAK), "%s: %d x %s crack the %s %s (Armor break)" % [item, k, break_move, break_species, break_section])
	var through: Array = _hit(a, w, break_section, break_move)
	_expect(through[1] != &"armoured" and through[0] > first[0] * 3.9, "%s: through the Armor break %s deals full damage (%.1f -> %.1f)" % [item, break_move, first[0], through[0]])
	a.queue_free()
	await _frames(2)

func _check_live(w) -> void:
	var c = await _spawn(&"velociraptor")
	player.global_position = c.global_position + Vector3(0, 0.9, 2.2)
	var landed := [0]
	var moves := []
	player.hunt.hit_landed.connect(func(_t) -> void: landed[0] += 1)
	player.hunt.swing_started.connect(func() -> void: moves.append(player.anim.current_clip))
	player.hunt.start(c)
	var f := 0
	while landed[0] < 2 and f < 60 * 12:
		await physics_frame
		f += 1
	_expect(landed[0] >= 2, "live: her auto-attack with the %s lands %d hits through the hitboxes in %.1f s (clips %s)" % [item, landed[0], f / 60.0, moves])
	_expect(moves.size() >= 2 and moves[0] != moves[1], "live: consecutive swings play different chain moves")
	player.hunt.stop()
	c.queue_free()
