extends Node3D
## FIREPITS visual lab. kitchen_lab loads the fires, so the fire system installs this probe itself when
## the run carries --shot-dir (the gate's windowed pass). It stages the empty pit, loads wood into it,
## and puts a fresh bonfire and campfire beside it, then prints ONE measured
## "[firepits] RESULT k=v ..." line and saves a PNG per step into --shot-dir, and quits.
## Headless runs never reach frame_post_draw, so it only runs in a window.

const SHOT_WAIT := 0.5

var _player: Player
var _pit: StaticBody3D
var _bonfire: StaticBody3D
var _campfire: StaticBody3D
var _shot_dir := ""
var _shots: Array[String] = []
var _measured := {}
var _cam: Camera3D
var _sub: SubViewport
var _stage: Node3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.substr(11)
	_player = PlayerRegistry.local()
	_build_stage()
	var win := get_tree().root.get_visible_rect().size
	if win.x > 0.0 and win.y > 0.0:
		_sub.size = Vector2i(int(win.x), int(win.y))
		_cam.position = Vector3(1.2, 3.4, 5.0) if win.x > win.y * 1.6 else Vector3(1.2, 5.0, 8.0)
		_cam.look_at(Vector3(0, 0.55, 0))
	_run.call_deferred()

## The stage lives in its own SubViewport (its own World3D, its own camera), so the shots frame the
## three fires and the kitchen lab's own camera and cookroles shots are never disturbed.
func _build_stage() -> void:
	_sub = SubViewport.new()
	_sub.name = "FirepitsViewport"
	_sub.size = Vector2i(1600, 900)
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.world_3d = World3D.new()
	_sub.own_world_3d = true
	add_child(_sub)
	var stage := Node3D.new()
	stage.name = "FirepitsStage"
	_sub.add_child(stage)
	_stage = stage
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(16, 0.4, 10)
	ground.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.30, 0.23)
	ground.material_override = mat
	ground.position = Vector3(0, -0.2, 0)
	stage.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-52, 32, 0)
	stage.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.50, 0.58, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.75, 0.80)
	e.ambient_light_energy = 0.75
	env.environment = e
	stage.add_child(env)
	var B := load("res://scripts/world/bonfire.gd") as GDScript
	_pit = B.make(&"stone_fire_pit") as StaticBody3D
	_pit.position = Vector3(-3.4, 0, 0)
	stage.add_child(_pit)
	_bonfire = B.make(&"bonfire") as StaticBody3D
	_bonfire.position = Vector3(0, 0, 0)
	stage.add_child(_bonfire)
	_campfire = B.make(&"campfire") as StaticBody3D
	_campfire.position = Vector3(3.0, 0, 0)
	stage.add_child(_campfire)
	_cam = Camera3D.new()
	_cam.position = Vector3(1.2, 3.4, 5.0)
	stage.add_child(_cam)
	_cam.look_at(Vector3(0, 0.55, 0))
	_cam.fov = 46.0
	_cam.current = true

func _run() -> void:
	await get_tree().create_timer(0.9).timeout
	print("[firepits] probe start")
	# 1. The empty permanent pit: rocks only, no wood, no flame.
	_measured["pit_wood_empty"] = 1 if bool(_pit.call("wood_visible")) else 0
	_measured["pit_flame_empty"] = 1 if bool(_pit.call("flame_visible")) else 0
	await _shot("firepits_pit_empty")
	# 2. Load wood (from the survivor's bag, or straight into the pit if the lab bag has none).
	var gained := 0.0
	if _player != null and is_instance_valid(_player):
		LabKit.give(_player, &"branch", 4)
		gained = float(_pit.call("load_wood", _player))
	if gained <= 0.0:
		# No survivor in reach (or an already full pit): light it directly so the shot still measures
		# the wood and flame of a burning pit.
		_pit.set("fuel_seconds", 240.0)
		_pit.call("_sync_fire_nodes")
	_measured["pit_fuel_loaded"] = int(round(float(_pit.get("fuel_seconds"))))
	_measured["pit_wood_loaded"] = 1 if bool(_pit.call("wood_visible")) else 0
	_measured["pit_flame_loaded"] = 1 if bool(_pit.call("flame_visible")) else 0
	_measured["pit_burning"] = 1 if bool(_pit.call("burning")) else 0
	await _shot("firepits_pit_loaded")
	# 3. The temporary fires show wood and flame from placement.
	_measured["bonfire_wood"] = 1 if bool(_bonfire.call("wood_visible")) else 0
	_measured["bonfire_flame"] = 1 if bool(_bonfire.call("flame_visible")) else 0
	_measured["campfire_wood"] = 1 if bool(_campfire.call("wood_visible")) else 0
	_measured["campfire_flame"] = 1 if bool(_campfire.call("flame_visible")) else 0
	_measured["bonfire_fuel"] = int(round(float(_bonfire.get("fuel_seconds"))))
	_measured["campfire_fuel"] = int(round(float(_campfire.get("fuel_seconds"))))
	print("[firepits] probe step3 done")
	await _shot("firepits_temporary")
	print("[firepits] probe step4")
	# 4. Wear: one measured minute inside a Domain against one outside it (same fire code, the claim
	#    check swapped on the runtime). Both numbers come off tick() on live nodes.
	print("[firepits] probe wear begin")
	var wear := _measure_wear()
	print("[firepits] probe wear done %s" % str(wear))
	_measured["wear_inside"] = float(wear[0])
	_measured["wear_outside"] = float(wear[1])
	_measured["wear_ratio"] = float(wear[1]) / maxf(0.001, float(wear[0]))
	# 5. Cooking offered only while burning: a freshly placed (cold) pit against the burning bonfire.
	var SM := load("res://scripts/ui/station_menu.gd") as GDScript
	var cold := load("res://scripts/world/bonfire.gd").make(&"stone_fire_pit") as StaticBody3D
	cold.position = Vector3(-6.0, 0, 0)
	add_child(cold)
	await get_tree().process_frame
	var actions: Array = SM.actions_for(&"bonfire", _player)
	_measured["cold_pit_cook"] = 1 if _has_action(SM.filter_actions(cold, actions), "cook") else 0
	_measured["cold_pit_burning"] = 1 if bool(cold.call("burning")) else 0
	cold.queue_free()
	_measured["hot_fire_cook"] = 1 if _has_action(SM.filter_actions(_bonfire, actions), "cook") else 0
	_measured["cold_pit_wood_hex"] = 1 if _has_action(SM.filter_actions(_pit, actions), "wood") else 0
	_measured["cold_pit_cook_only_cold"] = 1 if (int(_measured["cold_pit_cook"]) == 0 and int(_measured["cold_pit_burning"]) == 0) else 0
	# 6. The wood goes when the pit's fuel runs out; the rocks stay.
	var fuel := float(_pit.get("fuel_seconds"))
	_pit.call("tick", fuel + 0.5)
	_measured["pit_wood_after"] = 1 if bool(_pit.call("wood_visible")) else 0
	_measured["pit_flame_after"] = 1 if bool(_pit.call("flame_visible")) else 0
	_measured["pit_alive_after"] = 0 if _pit.is_queued_for_deletion() else 1
	await _shot("firepits_pit_out")
	# 7. Save round trip on the live bonfire.
	var B := load("res://scripts/world/bonfire.gd") as GDScript
	var back: StaticBody3D = B.from_dict(_bonfire.call("to_dict"))
	_measured["save_fuel"] = 1 if is_equal_approx(float(back.get("fuel_seconds")), float(_bonfire.get("fuel_seconds"))) else 0
	_measured["save_durability"] = 1 if is_equal_approx(float(back.get("durability")), float(_bonfire.get("durability"))) else 0
	back.free()
	_measured["all_ok"] = 1 if _all_ok() else 0
	_report()
	get_tree().quit(0)

func _measure_wear() -> Array:
	var B := load("res://scripts/world/bonfire.gd") as GDScript
	var rt := World.runtime
	var fake := ClaimFake.new()
	add_child(fake)
	fake.claimed = true
	World.runtime = fake
	var inside: StaticBody3D = B.make(&"bonfire") as StaticBody3D
	add_child(inside)
	var in0 := float(inside.get("durability"))
	inside.call("tick", 60.0)
	var inside_loss := in0 - float(inside.get("durability"))
	inside.queue_free()
	fake.claimed = false
	var outside: StaticBody3D = B.make(&"bonfire") as StaticBody3D
	add_child(outside)
	var out0 := float(outside.get("durability"))
	outside.call("tick", 60.0)
	var outside_loss := out0 - float(outside.get("durability"))
	outside.queue_free()
	fake.queue_free()
	World.runtime = rt
	return [inside_loss, outside_loss]

class ClaimFake:
	extends Node3D
	var claimed: bool = true
	func is_claimed(_tile: Vector2i) -> bool:
		return claimed

func _has_action(actions: Array, id: String) -> bool:
	for a: Variant in actions:
		if str((a as Dictionary).get("id", "")) == id:
			return true
	return false

func _all_ok() -> bool:
	return int(_measured.get("pit_wood_empty", 1)) == 0 \
		and int(_measured.get("pit_flame_empty", 1)) == 0 \
		and int(_measured.get("pit_wood_loaded", 0)) == 1 \
		and int(_measured.get("pit_flame_loaded", 0)) == 1 \
		and int(_measured.get("pit_burning", 0)) == 1 \
		and int(_measured.get("bonfire_wood", 0)) == 1 \
		and int(_measured.get("bonfire_flame", 0)) == 1 \
		and int(_measured.get("campfire_wood", 0)) == 1 \
		and int(_measured.get("campfire_flame", 0)) == 1 \
		and is_equal_approx(float(_measured.get("wear_ratio", 0.0)), 2.0) \
		and int(_measured.get("cold_pit_cook", 1)) == 0 \
		and int(_measured.get("hot_fire_cook", 0)) == 1 \
		and int(_measured.get("pit_wood_after", 1)) == 0 \
		and int(_measured.get("pit_alive_after", 0)) == 1 \
		and int(_measured.get("save_fuel", 0)) == 1 \
		and int(_measured.get("save_durability", 0)) == 1

func _shot(shot_name: String) -> void:
	if _shot_dir == "" or _sub == null:
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _sub.get_texture().get_image()
	if img == null:
		return
	var path := "%s/%s_%dx%d.png" % [_shot_dir, shot_name, _sub.size.x, _sub.size.y]
	img.save_png(path)
	_shots.append(path)
	print("[firepits] shot %s" % path)

func _report() -> void:
	var bits: PackedStringArray = []
	for k in _measured:
		var v: Variant = _measured[k]
		bits.append("%s=%s" % [k, ("%.3f" % float(v)) if v is float else str(int(v))])
	print("[firepits] RESULT %s" % " ".join(bits))
	print("[firepits] shots %s" % str(_shots))
