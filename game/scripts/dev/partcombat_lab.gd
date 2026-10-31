extends Node3D
## PARTCOMBAT review shots, self-quitting. Run windowed off-screen:
##   Godot --path game --position 6000,3000 -- --skip-charcreate --lab=partcombat_lab --out=DIR [--poses]
## --poses: each weapon's clips on the survivor at a few points, from the side and the front (DIR/pose_<clip>_<k>.png).
## Default: the owner's shots at 844x390 2x (the window): the section picker on the target card, a Wound and an Armor
## break built with the heavy blades, aiming the bow and an arrow hit (DIR/<n>_<what>.png).

const WEAPONS := {
	&"iron_slab_blade": [&"wpn_1h_carry_idle", &"wpn_1h_carry_walk", &"wpn_1h_cross1", &"wpn_1h_cross2", &"wpn_1h_cross3", &"wpn_1h_impale", &"wpn_1h_chop"],
	&"steel_greatblade": [&"wpn_2h_carry_idle", &"wpn_2h_carry_run", &"wpn_2h_slam", &"wpn_2h_sweep"],
	&"pro_bow": [&"wpn_bow_carry_idle", &"wpn_bow_draw", &"wpn_bow_aim", &"wpn_bow_release"],
}

var _out := ""
var _caption: Label
var player: Player
var game_cam: Camera3D
var cam: Camera3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("partcombat_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.god_mode = true
	CombatTuning.force_accuracy = 1.0
	CombatTuning.force_dodge = 0.0
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=partcombat_lab")
	_run.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[partcombat_lab] saved %s/%s.png" % [_out, name])

func _run() -> void:
	var kit := LabKit.build(self, 80.0)
	player = kit["player"] as Player
	game_cam = kit["cam"] as Camera3D
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 64)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	if "--poses" in OS.get_cmdline_user_args():
		await _poses(kit)
	else:
		await _shots(kit)
	Game.god_mode = false
	get_tree().quit(0)

func equip(id: StringName) -> ItemStack:
	var s := ItemStack.make(id, 1, {}, 30)
	player.inventory.add(s)
	player.inventory.equip(Inventory.slot_for(s.def()), id)
	if s.def() and s.def().ammo_id != &"":
		player.inventory.add(ItemStack.make(s.def().ammo_id, 200))
	if player.station_craft:
		player.station_craft._sync_hand_tool()
	player.anim.sync_carry()
	player.anim.play_clip(&"idle", true)
	return s

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame

func _poses(kit: Dictionary) -> void:
	(kit["ui"] as CanvasLayer).visible = false
	game_cam.current = false
	cam.current = true
	var at := player.global_position
	player.face_world(at + Vector3(0, 0, -10))
	await _frames(20)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weapon="):
			only = a.substr(9)
	for id in WEAPONS:
		if only != "" and str(id) != only:
			continue
		equip(id)
		if player.station_craft:
			player.station_craft._sync_hand_tool()
		for clip in WEAPONS[id]:
			for k in 4:
				var frac: float = [0.15, 0.4, 0.6, 0.85][k]
				var ap := player.rig.anim_player
				player.anim.play_clip(clip, true)
				ap.speed_scale = 1.0
				ap.seek(ap.current_animation_length * frac, true)
				ap.speed_scale = 0.0
				await _frames(2)
				print("[partcombat_lab] pose %s playing=%s held=%s" % [clip, ap.current_animation, player.station_craft.held_model_id() if player.station_craft else &"-"])
				var mid := at + Vector3(0, 1.0, 0)
				var side := Vector3.RIGHT  # she faces -Z (face_world below): her right is +X
				cam.look_at_from_position(mid + side * 3.6 + Vector3(0, 0.5, 0), mid)
				_caption.text = "%s  %s  %.0f%%  (her right side)" % [id, clip, frac * 100]
				await _snap("pose_%s_%d_side" % [clip, k])
				var fwd := Vector3.FORWARD
				cam.look_at_from_position(mid + fwd * 3.0 + side * 2.0 + Vector3(0, 0.8, 0), mid)
				_caption.text = "%s  %s  %.0f%%  (front)" % [id, clip, frac * 100]
				await _snap("pose_%s_%d_front" % [clip, k])

func _spawn(id: StringName, at: Vector3) -> Creature:
	var c := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
	add_child(c)
	c.global_position = at
	c.spawn(Data.creature(id))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.health.setup(1e9)
	return c

func _face(c: Creature, at: Vector3) -> void:
	c.look_at(Vector3(at.x, c.global_position.y, at.z), Vector3.UP)

## Real swings of the equipped blade (Hunt.begin_swing: its clip, its hitbox sweep through Hitbox.strike, land_hit) with
## the section focused, from where she stands next to the animal, until `done` holds or `seconds` pass. Her own
## locomotion is held (the lab only needs the swing), so each swing is aimed at the focused section's reachable point.
func _fight_until(c: Creature, section: StringName, done: Callable, seconds: float) -> bool:
	player.hunt.auto = false
	player.hunt.start(c)
	player.hunt.set_aim_section(section)
	var t := 0.0
	while not done.call() and t < seconds:
		c.health.hp = c.health.max_hp
		if not player.hunt._swing_pending and player.hunt._swing_cd <= 0.0 and not player.anim._busy:
			var p := player.hunt.aim_point(c)
			var back := (player.global_position - p)
			back.y = 0.0
			player.global_position = Vector3(p.x, player.global_position.y, p.z) + back.normalized() * 1.1
			player.face_world(p)
			player.hunt.begin_swing()
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return done.call()

## A camera on the newest Wound or Armor break decal, from her side of the animal, 3 m off.
func _decal_view(c: Creature) -> void:
	var w := BodyWounds.of(c, false)
	if w == null or w._decals.is_empty() or not is_instance_valid(w._decals[-1]):
		return
	var piece := (w._decals[-1].get_child(0) as Node3D).get_child(0) as Node3D
	var at := piece.global_position
	var n := piece.global_basis.z.normalized()  # the decal faces out of the skin
	var d := 2.4 + c.body_radius() * 1.6
	c.statuses.clear_all()  # the bleed's red tint would hide the decal's colour
	cam.current = true
	game_cam.current = false
	cam.look_at_from_position(at + n * d + Vector3(0, 0.25 * d, 0), at)

func _game_view(size: float) -> void:
	cam.current = false
	game_cam.current = true
	if game_cam is IsoCamera:
		(game_cam as IsoCamera).size = size

func _shots(kit: Dictionary) -> void:
	_caption.position = Vector2(16, get_viewport().get_visible_rect().size.y - 40)
	_caption.add_theme_font_size_override("font_size", 16)
	(kit["ui"] as CanvasLayer).visible = true
	var origin := player.global_position
	player.set_physics_process(false)  # held still: the lab places her (see _fight_until)
	var iso := game_cam as IsoCamera
	var near := iso.min_size if iso else 12.0

	# 1. The section picker on the target card (an ankylosaurus: armoured back, crit belly and throat).
	equip(&"iron_slab_blade")
	var ank := _spawn(&"ankylosaurus", origin + Vector3(2.5, 0, -6))
	_face(ank, origin + Vector3(8.5, 0, -6))  # side-on
	await _frames(10)
	player.hunt.auto = false
	player.hunt.start(ank)
	player.hunt.set_aim_section(&"torso")
	var picker := get_tree().root.find_child("SectionPicker", true, false) as SectionPicker
	if picker:
		picker.open(true)
	_game_view(near * 1.7)
	await _frames(20)
	_caption.text = "Section picker on the target card: AIM chip + grid (ARMOUR / WEAK tags); the picked section glows cyan"
	await _snap("1_section_picker")
	if picker:
		picker.open(false)
	player.hunt.stop()
	ank.queue_free()
	player.hunt.auto = true

	# 2. A Wound from the one-handed slab blade's cross-slash combo on a velociraptor.
	player.global_position = origin
	var rap := _spawn(&"velociraptor", origin + Vector3(0, 0, -4.0))
	_face(rap, origin + Vector3(6, 0, -4.0))
	await _frames(10)
	var formed := [false]
	rap.combat_float.connect(func(_a: float, kind: StringName) -> void:
		if kind == &"wound_formed" and not formed[0]:
			formed[0] = true
			SectionHighlight.show_on(player.hunt.target, &"")  # the decal, not the pick, is the subject now
			get_tree().create_timer(1.0, true, false, true).timeout.connect(func() -> void: get_tree().paused = true))
	_game_view(near)
	var natural: bool = await _fight_until(rap, &"torso", func() -> bool: return get_tree().paused, 25.0)
	if not natural:
		for i in 3:
			player.hunt.land_hit(rap, player.inventory.equipped_weapon(), {}, {"part": BodySections.cap_at(rap, BodySections.aim_point(rap, &"torso", false))["part"], "surface": BodySections.aim_point(rap, &"torso", false), "move": &"wpn_1h_cross1"})
		while not get_tree().paused:
			await get_tree().physics_frame
	var where := ""
	for s2 in BodySections.names(rap):
		if BodyWounds.has(rap, s2, BodyWounds.WOUND):
			where = str(s2)
	_caption.text = "Iron Slab Blade cross-slash combo opens a WOUND on the velociraptor %s (red gash; hits there now crit)%s" % [where, "" if natural else " [SCRIPTED hits]"]
	_decal_view(rap)
	await _frames(3)
	await _snap("2_wound_slab_blade")
	get_tree().paused = false
	player.hunt.stop()
	rap.queue_free()
	_game_view(near)

	# 3. An Armor break from the two-handed greatblade's overhead slam on an ankylosaurus back.
	equip(&"steel_greatblade")
	player.global_position = origin
	ank = _spawn(&"ankylosaurus", origin + Vector3(0, 0, -6.0))
	_face(ank, origin + Vector3(6, 0, -6.0))
	await _frames(10)
	formed[0] = false
	ank.combat_float.connect(func(_a: float, kind: StringName) -> void:
		if kind == &"armor_break" and not formed[0]:
			formed[0] = true
			SectionHighlight.show_on(player.hunt.target, &"")  # the decal, not the pick, is the subject now
			get_tree().create_timer(1.0, true, false, true).timeout.connect(func() -> void: get_tree().paused = true))
	natural = await _fight_until(ank, &"torso", func() -> bool: return get_tree().paused, 50.0)
	if not natural:
		for i in 2:
			player.hunt.land_hit(ank, player.inventory.equipped_weapon(), {}, {"part": BodySections.cap_at(ank, BodySections.aim_point(ank, &"torso", false))["part"], "surface": BodySections.aim_point(ank, &"torso", false), "move": &"wpn_2h_slam"})
		while not get_tree().paused:
			await get_tree().physics_frame  # the formation's own timer pauses it a second later
	where = ""
	for s2 in BodySections.names(ank):
		if BodyWounds.has(ank, s2, BodyWounds.BREAK):
			where = str(s2)
	_caption.text = "Steel Greatblade overhead slam cracks the ankylosaurus %s: ARMOR BREAK (glowing fracture; full damage there now)%s" % [where, "" if natural else " [SCRIPTED hits]"]
	_decal_view(ank)
	await _frames(3)
	await _snap("3_armor_break_greatblade")
	get_tree().paused = false
	player.hunt.stop()
	ank.queue_free()
	_game_view(near)

	# 4. Aiming the bow at a tyrannosaurus head (out of the collision capsule: shootable now).
	equip(&"pro_bow")
	await _frames(30)
	get_tree().paused = false  # a late timer from the armour shot may have paused it again
	player.global_position = origin
	var rex := _spawn(&"tyrannosaurus", origin + Vector3(0, 0, -14))
	_face(rex, origin + Vector3(14, 0, -14))
	await _frames(10)
	player.hunt.auto = false
	player.hunt.start(rex)
	player.hunt.set_aim_section(&"head")
	player.face_world(rex.global_position)
	if World.runtime == null:
		var rt := Node3D.new()
		rt.name = "Runtime"
		add_child(rt)
		World.runtime = rt  # shots fly in the world runtime
	player.anim.sync_carry()  # her physics is held in this lab: the aim hold swaps in by hand
	player.anim.play_clip(&"idle", true)
	# Over her shoulder towards the tyrannosaurus.
	cam.current = true
	game_cam.current = false
	var mid := (player.global_position + rex.global_position) * 0.5 + Vector3(0, 2.0, 0)
	cam.look_at_from_position(player.global_position + Vector3(-5.5, 4.0, 7.5), mid)
	await _frames(40)
	_caption.text = "PRO-Class Bow: aim hold, the tyrannosaurus head picked (cyan); arrows fly at 45 m/s vs a stone's 18"
	await _snap("4_bow_aim")
	# 5. The arrow hit.
	var hit := [{}]
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is StoneProjectile:
			(n as StoneProjectile).landed.connect(func(r: Dictionary) -> void:
				if hit[0].is_empty():
					hit[0] = r
					get_tree().create_timer(0.1, true, false, true).timeout.connect(func() -> void: get_tree().paused = true)))
	var tries := 0
	get_tree().paused = false
	while hit[0].is_empty() and tries < 6:
		player.hunt._swing_cd = 0.0
		player.anim._busy = false
		player.hunt.fire_ranged()
		var f := 0
		while hit[0].is_empty() and f < 120:
			await get_tree().physics_frame
			f += 1
		tries += 1
	var r: Dictionary = hit[0]
	_caption.text = "Arrow hit: %s section %s%s" % [rex.def.id, r.get("section", "-"), ", WEAK SPOT" if not (r.get("spot", {}) as Dictionary).is_empty() else ""]
	await _frames(3)
	await _snap("5_arrow_hit")
	get_tree().paused = false
	player.hunt.stop()
	rex.queue_free()

	# 6. Close-up of the greatblade, dragged at her side.
	equip(&"steel_greatblade")
	await _frames(20)
	var held := player.find_children("HeldWeapon", "", true, false)
	if not held.is_empty():
		var hx := (held[0] as Node3D).global_transform
		var tip := hx * Vector3(0, 1.3, 0)
		cam.current = true
		game_cam.current = false
		(kit["ui"] as CanvasLayer).visible = false
		# Square onto the blade's flat, a little above, so the ridge, the bright edges and the point read.
		cam.look_at_from_position(tip + hx.basis.z.normalized() * 1.6 + Vector3(0, 0.5, 0), tip)
		_caption.text = "Steel Greatblade close-up: ridged diamond section, bright ground edges, ricasso, hard angled point"
		await _frames(3)
		await _snap("6_greatblade_closeup")
