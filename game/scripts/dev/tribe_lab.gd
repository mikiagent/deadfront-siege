extends Node3D
## TRIBE M1 screenshots on the real home island: a member mining a rock at camp into a basket, then a
## guarding member fighting a raptor beside the survivor. One PNG each into --shot-dir, suffixed with
## the canvas. Windowed: Godot --path game --resolution 1600x900 -- --lab=tribe_lab --shot-dir=DIR

var _out := ""
var _player: Player
var _hud: HuntHud

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("tribe")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	Game.time_of_day = 0.4
	# A windowed capture must not take the desk's stray keys and clicks (one opened the atlas mid-run).
	get_tree().root.gui_disable_input = true
	for n: Node in [_player, _hud]:
		n.set_process_input(false)
		n.set_process_unhandled_input(false)
		n.set_process_unhandled_key_input(false)
	_run.call_deferred()

func _shot(tag: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var v := get_tree().root.get_visible_rect().size
	var path := _out.path_join("%s_%dx%d.png" % [tag, int(v.x), int(v.y)])
	img.save_png(path)
	print("[tribe_lab] shot %s" % path)

## A rock near camp in the open (farthest from any tree within 30 m of camp), so the shot shows the worker.
func _nearest_rock(at: Vector3) -> HarvestNode:
	var tools := Inventory.new(1)
	tools.slots[0] = ItemStack.make(&"work_pick", 1, {"material_tier": "stone"}, 1)
	var trees: Array[Vector3] = []
	for n in get_tree().get_nodes_in_group("harvest"):
		if (n as HarvestNode).is_tree() or (n as HarvestNode).gather_kind() == &"gather":
			trees.append((n as Node3D).global_position)
	var best: HarvestNode = null
	var best_score := -INF
	for n in get_tree().get_nodes_in_group("harvest"):
		var h := n as HarvestNode
		if h == null or h.gather_kind() != &"mine" or h.pool_units_left() <= 0 or h.can_gather(tools) != "":
			continue
		var d := h.global_position.distance_to(at)
		if d > 30.0 or d < 4.0:
			continue
		var clear := INF
		for t in trees:
			clear = minf(clear, t.distance_to(h.global_position))
		if clear - d * 0.05 > best_score:
			best_score = clear - d * 0.05
			best = h
	return best

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, World.runtime.surface_y(x, z), z)

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Tribe.reset()
	Tribe.seeded = true
	var camp: Vector3 = World.runtime.get("_camp_pos")
	var rock := _nearest_rock(camp)
	print("[tribe_lab] camp %s rock %s" % [camp, rock.global_position if rock else Vector3.INF])
	var basket = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	World.runtime.add_child(basket)
	var rp := rock.global_position if rock else camp
	basket.global_position = _ground(rp.x + 2.5, rp.z + 2.0)
	var miner := Tribe.make_recruit(Tribe.rng)
	miner.name = "Wren"
	miner.equipment.put(&"weapon", ItemStack.make(&"work_pick", 1, {"material_tier": "stone"}, 1))
	Tribe.members.append(miner)
	Tribe.set_job(miner, &"mine", rp, basket.global_position, 3.0)
	var stand := rp.z + TribeMember.work_reach(rock) - 0.2
	miner.pos = [rp.x, World.runtime.surface_y(rp.x, stand) + 1.05, stand]  # the camera side of the rock
	_player.global_position = _ground(rp.x - 3.2, rp.z + 3.0) + Vector3(0, 1.0, 0)
	_player.face_world(rp)
	await get_tree().create_timer(5.5).timeout
	var body := _player.tribe.body_of(miner)
	print("[tribe_lab] miner state=%s harvests=%d at %s ground %.2f clip %s player %s node %s reach %.2f" % [body.state if body else &"none", body.harvests.size() if body else -1, body.global_position, World.runtime.surface_y(body.global_position.x, body.global_position.z), body._clip, _player.global_position, body._work_node.global_position if body._work_node else Vector3.INF, TribeMember.work_reach(body._work_node) if body._work_node else -1.0])
	await _shot("tribe_mining")
	# A guarding member and the survivor against a raptor that came for her.
	var guard := Tribe.make_recruit(Tribe.rng)
	guard.name = "Joss"
	guard.equipment.put(&"weapon", ItemStack.make(&"stone_knife", 1, {}, 1))
	var at := _ground(camp.x - 5.0, camp.z + 5.0)
	_player.global_position = at + Vector3(0, 1.0, 0)
	_player.vitals.max_health = 1000.0
	_player.vitals.health = 1000.0
	await get_tree().create_timer(0.5).timeout
	Tribe.members.append(guard)
	Tribe.set_order(guard, &"guard")
	await get_tree().create_timer(1.0).timeout
	var gbody := _player.tribe.body_of(guard)
	if gbody:
		gbody.health.max_hp = 1000.0  # the shot is of the fight, not of a level-1 recruit going down
		gbody.health.hp = 1000.0
		gbody.global_position = at + Vector3(2.2, 1.0, 0.6)  # on her right, toward the camera
	var c: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	World.runtime.add_child(c)
	c.global_position = at + Vector3(0.5, 1.0, -5.0)  # from the far side, so both humans face the camera
	c.spawn(Data.creature(&"velociraptor"))
	c.health.max_hp = 4000.0
	c.health.hp = 4000.0
	c.brain.on_aggro(_player)
	_player.actions.attack(c)
	await get_tree().create_timer(2.0).timeout
	var gb := _player.tribe.body_of(guard)
	print("[tribe_lab] held miner=%s guard=%s" % [_player.tribe.body_of(miner)._held, gb._held if gb else null])
	print("[tribe_lab] guard state=%s raptor hp=%.0f guard %s raptor %s player %s" % [gb.state if gb else &"none", c.health.hp, gb.global_position if gb else Vector3.INF, c.global_position, _player.global_position])
	# On a phone canvas the combat hexes cover the centre of the screen, where the fight is: shoot it bare.
	if UiTokens.is_compact(get_viewport().get_visible_rect().size):
		_hud.visible = false
	await _shot("tribe_fight")
	# The Tribe tab with one recruit waiting at the dock and the two members.
	_hud.visible = true
	Tribe.arrive()
	_player.inventory.add(ItemStack.make(&"stone_knife", 1, {}, 1))
	_hud.open_tribe(Tribe.members[0])
	await get_tree().create_timer(0.6).timeout
	await _shot("tribe_screen")
	print("[tribe_lab] DONE")
	get_tree().quit(0)
