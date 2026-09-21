extends Node3D
## Main scene glue. Owns the sun and a debug label. Labs replace the default playfield.

@onready var sun: DirectionalLight3D = $Sun
@onready var debug_label: Label = $UI/DebugLabel
@onready var default_playfield: Node3D = $DefaultPlayfield
@onready var iso_camera: Camera3D = $IsoCamera

func _ready() -> void:
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	if Game.lab_name != "":
		default_playfield.visible = false
		default_playfield.process_mode = Node.PROCESS_MODE_DISABLED
		iso_camera.current = false
		var path := "res://scenes/dev/%s.tscn" % Game.lab_name
		if not ResourceLoader.exists(path):
			push_error("[boot] missing lab %s" % path)
		else:
			add_child(load(path).instantiate())
			print("[boot] lab=%s" % Game.lab_name)
	else:
		print("[boot] main scene ready")
		var player := get_tree().get_first_node_in_group("player") as Player
		if player:
			# Modal screens (bag, craft) sit above every other canvas layer (plates 58, world UI 40).
			var modals := CanvasLayer.new()
			modals.name = "Modals"
			modals.layer = 96
			add_child(modals)
			var inv_ui = preload("res://scenes/ui/inventory.tscn").instantiate()
			modals.add_child(inv_ui)
			player.ui = inv_ui
			inv_ui.bind(player.inventory, player)
			var craft = preload("res://scenes/ui/craft.tscn").instantiate()
			modals.add_child(craft)
			player.craft_ui = craft
			craft.bind(player)
			var hud := HuntHud.new()
			hud.name = "HuntHud"
			hud.bind(player)
			$UI.add_child(hud)
			if "--gather-test" in OS.get_cmdline_user_args():
				_gather_test(player)
			if "--combat-test" in OS.get_cmdline_user_args():
				_combat_test(player)

## Headless regression: spawn a compy next to the survivor, hunt it, press Tackle and Kick,
## kill it, press Loot; expect groggy, a push, and the chest screen with items.
func _combat_test(player: Player) -> void:
	await get_tree().create_timer(2.5).timeout
	var sp := Spawner.new()
	sp.species = &"compsognathus"
	sp.count = 1
	sp.radius = 0.5
	sp.as_pack = false
	sp.position = player.global_position + Vector3(1.5, 0, 0)
	World.runtime.add_child(sp)
	var made := sp.spawn_now()
	if made.is_empty():
		print("[combattest] FAIL no creature")
		get_tree().quit(1)
		return
	var c: Creature = made[0]
	c.global_position = player.global_position + Vector3(1.5, 0, 0)
	await get_tree().create_timer(0.5).timeout
	player.hunt.start(c)
	await get_tree().create_timer(0.8).timeout
	print("[combattest] dist=%.2f stamina=%.0f" % [player.global_position.distance_to(c.global_position), player.vitals.energy])
	player.hunt.use_tackle()
	await get_tree().create_timer(0.3).timeout
	print("[combattest] tackle groggy=%s" % c.statuses.has(&"groggy"))
	var before := c.global_position
	player.hunt.use_kick()
	await get_tree().create_timer(0.3).timeout
	print("[combattest] kick moved=%.2f" % before.distance_to(c.global_position))
	c.health.take_damage(9999.0, player)
	await get_tree().create_timer(1.0).timeout
	var corpse := get_tree().get_first_node_in_group("corpse") as Corpse
	print("[combattest] corpse=%s loot_slots=%d dist=%.2f" % [corpse != null, corpse.loot.used_slots() if corpse else -1, player.global_position.distance_to(corpse.global_position) if corpse else -1.0])
	var acts := player.context_actions()
	var ids: Array = []
	for a in acts:
		ids.append(a["id"])
	print("[combattest] context=%s" % [ids])
	player.context_action("loot")
	for k in 12:
		await get_tree().create_timer(0.5).timeout
		if player.ui and player.ui.visible:
			print("[combattest] ok chest open storage=%s" % (player.ui.pet_bag != null))
			get_tree().quit(0)
			return
	print("[combattest] FAIL chest never opened (ui=%s butcher_target=%s nav=%s)" % [player.ui != null, player.butcher_target != null, player.nav_active])
	get_tree().quit(1)

## Headless regression: tap the nearest node that yields branches, pick that hex, wait for
## units to land in the bag. Prints [gathertest] lines and quits 0 on success.
func _gather_test(player: Player) -> void:
	await get_tree().create_timer(2.5).timeout
	var best: HarvestNode = null
	var best_d := INF
	var best_i := -1
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or hn.depleted:
			continue
		var opts := hn.options()
		for i in opts.size():
			if str(opts[i].get("item", "")) == OS.get_environment("GATHER_ITEM") if OS.get_environment("GATHER_ITEM") != "" else str(opts[i].get("item", "")) == "branch":
				var d := player.global_position.distance_to(hn.global_position)
				if d < best_d:
					best_d = d
					best = hn
					best_i = i
	if best == null:
		print("[gathertest] FAIL no branch node")
		get_tree().quit(1)
		return
	var before := player.inventory.count_of(StringName(OS.get_environment("GATHER_ITEM") if OS.get_environment("GATHER_ITEM") != "" else "branch"))
	print("[gathertest] node %s at %.1f m option %d before=%d" % [best.node_id, best_d, best_i, before])
	player._interact_tap_target(best)
	await get_tree().create_timer(0.3).timeout
	print("[gathertest] radial open=%s buttons=%d" % [player._gather_radial.is_open(), player._gather_radial._buttons.size()])
	player._gather_radial._on_pick(best_i)
	for k in 30:
		await get_tree().create_timer(0.5).timeout
		var now := player.inventory.count_of(StringName(OS.get_environment("GATHER_ITEM") if OS.get_environment("GATHER_ITEM") != "" else "branch"))
		print("[gathertest] t=%.1f branch=%d gathering=%s nav=%s target=%s dist=%.2f radial=%s active=%d" % [0.5 * (k + 1), now, player._gathering, player.nav_active, player.gather_target != null, player.global_position.distance_to(best.global_position), player._gather_radial.is_open(), player._gather_radial.active_index])
		if now > before:
			print("[gathertest] ok +%d branch" % (now - before))
			get_tree().quit(0)
			return
	print("[gathertest] FAIL no branches gathered")
	get_tree().quit(1)

func _process(_delta: float) -> void:
	debug_label.visible = false
	if Input.is_action_just_pressed("debug_toggle"):
		Game.debug_overlay = not Game.debug_overlay
