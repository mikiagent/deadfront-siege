extends Node3D
## Survivor v2 armor + T. rex howdah acceptance. Real inventory equip path drives PlayerEquipment; a
## mount-role T. rex pet exercises Player.mount() with the saddle socket. Screenshots go to /tmp/dfs-equip-*.png
## when run with a display: godot --path game -- --lab=equip_mount_lab
var player: Player
var cam: Camera3D

const KITS := {
	"travel": [&"travel_shirt", &"travel_sleeves", &"travel_trousers"],
	"forager": [&"forager_hood", &"forager_vest", &"forager_wraps", &"forager_leggings"],
	"hide_bone": [&"hide_bone_helm", &"hide_bone_cuirass", &"hide_bone_bracers", &"hide_bone_greaves"],
}

func _ready() -> void:
	var kit := LabKit.build(self, 60.0)
	player = kit["player"]
	Game.debug_overlay = false
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	for set_ids in KITS.values():
		for id in set_ids:
			LabKit.give(player, id, 1)
	call_deferred("_demo")

func _demo() -> void:
	await get_tree().create_timer(0.5).timeout
	var eq := player.equipment
	assert(eq != null and eq.body.size() == 4, "four body regions attached")
	assert(Inventory.EQUIP_SLOTS.has(&"arms"))
	assert(Inventory.slot_for(Data.item(&"travel_sleeves")) == &"arms", "armor_arms wins over clothing")
	assert(Inventory.slot_for(Data.item(&"travel_trousers")) == &"legs")
	await _shot("0_unarmored", 2.5)
	var armor_before := player.inventory.equipped_armor()
	for kit_name in KITS:
		for slot in [&"head", &"body", &"arms", &"legs"]:
			player.inventory.unequip(slot)
		_wear(KITS[kit_name])
		if kit_name == "travel":
			# travel_clothes has no helmet, so the bare head stays.
			assert(_vis("helmet") and not _vis("chest") and not _vis("arms") and not _vis("legs"), "travel hides chest/arms/legs only")
		await _shot("1_%s" % kit_name, 1.6)
	assert(player.inventory.equipped_armor() > armor_before + 700.0, "four hide-and-bone slots count, arms included")
	assert(player.inventory.equipped_health_bonus() >= 40.0)
	_wear([&"hide_bone_helm", &"forager_vest", &"travel_sleeves", &"hide_bone_greaves"])
	await _shot("2_mixed", 1.6)
	for slot in [&"head", &"body", &"arms", &"legs"]:
		assert(eq.equipped.has(slot))
		player.inventory.unequip(slot)
	assert(eq.equipped.is_empty() and _vis("helmet") and _vis("chest") and _vis("arms") and _vis("legs"), "unequip restores body")
	await _shot("3_unequipped", 1.0)
	print("[equiplab] equip: 3 kits, mixed, unequip OK")
	_wear(KITS["hide_bone"])
	await _ride()
	print("[equiplab] PASS")
	get_tree().quit(0)

func _wear(ids: Array) -> void:
	for id in ids:
		player.inventory.equip(Inventory.slot_for(Data.item(id)), id)

func _vis(region: String) -> bool:
	return (player.equipment.body[region][0] as MeshInstance3D).visible

func _ride() -> void:
	var def := Data.creature(&"tyrannosaurus")
	var rec := PetRecord.from_def(def, &"A")
	# Lab only: tyrannosaurus.json has no mount role yet.
	rec.tamed_role = [&"mount"]
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	player.get_parent().add_child(c)
	c.is_pet = true
	c.pet_record = rec
	c.spawn(def, rec.variant)
	c.global_position = player.global_position + Vector3(6, 0, 0)
	await get_tree().create_timer(0.5).timeout
	var rest := player.rig.transform
	player.mount(c)
	assert(player.mounted_on == c and player._saddle_view != null, "T. rex uses the saddle path")
	await get_tree().create_timer(0.6).timeout
	var sk := player.rig.skeleton
	var hips := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin
	var socket := c.view.rider_transform().origin
	print("[equiplab] rider hips %s rider root %s mount root %s rig scale %.3f" % [hips, socket, c.global_position, player.rig.global_basis.get_scale().x])
	assert(hips.y > c.global_position.y + 6.0, "rider sits on the howdah, not the ground")
	assert(player.rig.global_basis.get_scale().x < 1.1, "1.18 lift dropped while mounted")
	assert(player.anim.current_clip == &"mount_idle")
	await _ride_shot("4_ride_side", c, Vector3(-1, 0.15, 0.3), 1.2)
	await _ride_shot("5_ride_front", c, Vector3(0.6, 0.2, -0.8), 1.2)
	c.view.rig.play(&"walk")
	await _ride_shot("6_ride_walk", c, Vector3(1, 0.15, 0.3), 1.5)
	await _ride_shot("7_rider_close", c, Vector3(1, 0.1, 0.2), 1.0, true)
	player.dismount()
	assert(player.mounted_on == null and player.rig.transform.is_equal_approx(rest), "dismount restores rig")
	print("[equiplab] ride: saddle socket, mount_idle, dismount OK")

func _shot(stage: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	var t := player.rig.global_position
	cam.size = 2.4
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.look_at_from_position(t + Vector3(2.5, 1.6, 4.0), t + Vector3(0, 0.95, 0))
	await _save(stage)

func _ride_shot(stage: String, c: Creature, dir: Vector3, wait: float, close := false) -> void:
	await get_tree().create_timer(wait).timeout
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var focus := c.global_position + Vector3(0, 5.0, 0)
	cam.size = 11.0
	if close:
		focus = player.rig.global_position + Vector3(0, 0.6, 0)
		cam.size = 3.2
	cam.look_at_from_position(focus + c.global_basis * dir.normalized() * 30.0, focus)
	await _save(stage)

func _save(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame  # let the moved camera render once
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/dfs-equip-%s.png" % stage)
	print("[equiplab] shot %s" % stage)
