extends Node3D
## Character creation shots (CHARCREATE). Windowed:
##   godot --path game --resolution 1600x900 -- --lab=charcreate_lab --shot=out.png --shot-delay=6
##     [--cc-step=0|1|2] [--cc-occupation=<id>] [--cc-tab=portrait|appearance|color] [--cc-sub=<id>]
##     [--cc-seed=<n>] (a randomised look) [--cc-gender=f] [--cc-name=<text>] [--cc-height=1.06]
##     [--cc-colors=skin:#603b27,outfit1:#7c3f38] [--cc-outfit=<kit>] (the preview tries a kit on)
##     [--cc-world] [--cc-wear=<kit>] (the look on the player in a lab world, the portrait in a corner)

var _args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cc-"):
			var kv := a.substr(5).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var look := CharacterLook.defaults(str(_args.get("gender", CharacterLook.DEFAULT_GENDER)))
	if _args.has("seed"):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_args["seed"])
		look = CharacterLook.randomized(str(look["gender"]), rng)
	if _args.has("height"):
		look["height"] = float(_args["height"])
	for pair in str(_args.get("colors", "")).split(",", false):
		look["colors"][pair.get_slice(":", 0)] = pair.get_slice(":", 1)
	look = CharacterLook.clean(look)
	if _args.has("world"):
		_world(look)
		return
	var cc := CharacterCreation.new()
	cc.name = "CharacterCreation"
	add_child(cc)
	await get_tree().process_frame
	if _args.has("occupation"):
		cc.select_occupation(str(_args["occupation"]))
	cc._set_look(look)
	if _args.has("name"):
		cc.naming.field.text = str(_args["name"])
	cc._go(int(_args.get("step", "0")))
	if _args.has("tab"):
		cc.create._set_tab(str(_args["tab"]))
	if _args.has("sub"):
		cc.create._set_sub(str(_args["sub"]))
	if _args.has("outfit"):
		cc.preview_outfit(str(_args["outfit"]))
	print("[cclab] step=%d occupation=%s skill=%s outfit=%s look=%s" % [cc.step, cc.occupation(), cc.profession.skill_line.text, cc.stage.outfit, JSON.stringify(cc.look)])

func _world(look: Dictionary) -> void:
	var kit := LabKit.build(self, 20.0)
	var player: Player = kit["player"]
	await get_tree().create_timer(0.5).timeout
	if _args.has("wear"):
		for slot in PlayerEquipment.PIECE_FOR_SLOT:
			player.equipment.equip(slot, "%s/%s" % [_args["wear"], PlayerEquipment.PIECE_FOR_SLOT[slot]])
	CharacterLook.apply(player.rig, look)
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.current = false
	var close := Camera3D.new()
	close.fov = 35.0
	add_child(close)
	close.look_at_from_position(player.global_position + Vector3(1.6, 1.4, -3.4), player.global_position + Vector3(0, 0.1, 0))
	close.current = true
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var pic := TextureRect.new()
	pic.position = Vector2(16, 16)
	pic.size = Vector2(160, 160)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(pic)
	var ps := PortraitService.shared()
	ps.changed.connect(func (t: Texture2D) -> void: pic.texture = t)
	ps.request(look)
	print("[cclab] world look=%s rig_scale=%.3f" % [JSON.stringify(look), player.rig.scale.x])
