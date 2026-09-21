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
			var inv_ui = preload("res://scenes/ui/inventory.tscn").instantiate()
			$UI.add_child(inv_ui)
			player.ui = inv_ui
			inv_ui.bind(player.inventory, player)
			var craft = preload("res://scenes/ui/craft.tscn").instantiate()
			$UI.add_child(craft)
			player.craft_ui = craft
			craft.bind(player)
			var hud := HuntHud.new()
			hud.name = "HuntHud"
			hud.bind(player)
			$UI.add_child(hud)
			if "--gather-test" in OS.get_cmdline_user_args():
				_gather_test(player)

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
			if str(opts[i].get("item", "")) == "branch":
				var d := player.global_position.distance_to(hn.global_position)
				if d < best_d:
					best_d = d
					best = hn
					best_i = i
	if best == null:
		print("[gathertest] FAIL no branch node")
		get_tree().quit(1)
		return
	var before := player.inventory.count_of(&"branch")
	print("[gathertest] node %s at %.1f m option %d before=%d" % [best.node_id, best_d, best_i, before])
	player._interact_tap_target(best)
	await get_tree().create_timer(0.3).timeout
	print("[gathertest] radial open=%s buttons=%d" % [player._gather_radial.is_open(), player._gather_radial._buttons.size()])
	player._gather_radial._on_pick(best_i)
	for k in 30:
		await get_tree().create_timer(0.5).timeout
		var now := player.inventory.count_of(&"branch")
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
