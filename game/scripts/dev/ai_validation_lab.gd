extends Node3D
## Regression lab for pack locomotion, post-kill retention, pet repeat attacks and ring cleanup.

var player: Player
var alpha: Creature
var follower_a: Creature
var follower_b: Creature
var pet: Creature
var target: Creature
var idle_start: Array[Vector3] = []

func _ready() -> void:
	var kit := LabKit.build(self, 50.0)
	player = kit["player"]
	var cam := kit["cam"] as IsoCamera
	cam.size = 15.0
	player.global_position = Vector3(-20, 1, 0)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	# Flat labs have no World.runtime, so finish the NavigationServer sync before locomotion checks.
	await get_tree().physics_frame
	await get_tree().physics_frame
	alpha = _spawn(&"utahraptor", Vector3(2, 0, 0), 77)
	follower_a = _spawn(&"velociraptor", Vector3(5, 0, -2), 77)
	follower_b = _spawn(&"deinonychus", Vector3(5, 0, 2), 77)
	idle_start = [alpha.global_position, follower_a.global_position, follower_b.global_position]
	cam._target = alpha
	cam._snap()
	print("[aival] alpha=%s raptor_brains=%s/%s/%s" % [alpha.def.id, alpha.brain is RaptorPackBrain, follower_a.brain is RaptorPackBrain, follower_b.brain is RaptorPackBrain])
	get_tree().create_timer(2.5).timeout.connect(_after_idle)

func _spawn(id: StringName, at: Vector3, pack: int = 0) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = at
	c.spawn(Data.creature(id), &"", pack)
	return c

func _after_idle() -> void:
	var moved := [idle_start[0].distance_to(alpha.global_position), idle_start[1].distance_to(follower_a.global_position), idle_start[2].distance_to(follower_b.global_position)]
	print("[aival] idle_moved=%s states=%s/%s/%s active=%s/%s/%s targets=%s/%s/%s nav_done=%s/%s/%s" % [moved, alpha.brain.state, follower_a.brain.state, follower_b.brain.state, alpha._path_active, follower_a._path_active, follower_b._path_active, alpha.brain._roam_target, follower_a.brain._roam_target, follower_b.brain._roam_target, alpha.agent.is_navigation_finished(), follower_a.agent.is_navigation_finished(), follower_b.agent.is_navigation_finished()])
	# Isolate repeat-pet-attack verification away from the pack.
	target = _spawn(&"utahraptor", Vector3(-3, 0, 8), 0)
	target.brain.process_mode = Node.PROCESS_MODE_DISABLED
	pet = _spawn(&"compsognathus", Vector3(-4.0, 0, 8), 0)
	pet.become_pet(PetRecord.from_def(pet.def, &"normal"))
	pet.brain.order(&"attack", target)
	var hp0 := target.health.hp
	for second in 5:
		await get_tree().create_timer(1.0).timeout
		print("[aival] pet_tick=%d damage=%.1f cd=%.2f busy=%s clip=%s state=%s dist=%.2f active=%s" % [second + 1, hp0 - target.health.hp, pet.brain._attack_cd, pet.anim._busy, pet.anim.current_clip, pet.brain.state, pet.global_position.distance_to(target.global_position), pet._path_active])
	print("[aival] pet_repeat damage=%.1f cd=%.2f target_live=%s" % [hp0 - target.health.hp, pet.brain._attack_cd, not target.health.dead])
	# Make the pack finish a pet. Every member must immediately retain player engagement.
	for c in [alpha, follower_a, follower_b]:
		c.brain.attack_target = pet
		c.brain._combat_memory_left = 4.0
		c.brain.state = &"attack"
	pet.health.take_damage(pet.health.max_hp + 1.0, alpha)
	await get_tree().create_timer(0.25).timeout
	print("[aival] post_kill targets=%s/%s/%s states=%s/%s/%s" % [_target_name(alpha), _target_name(follower_a), _target_name(follower_b), alpha.brain.state, follower_a.brain.state, follower_b.brain.state])
	# Force an aggro ring, then prove death removes the node reference.
	alpha.brain.attack_target = player
	alpha.brain.state = &"attack"
	alpha._update_aggro_ring(1.0)
	var had_ring := alpha._aggro_ring != null
	alpha.health.take_damage(alpha.health.max_hp + 1.0, player)
	await get_tree().process_frame
	print("[aival] ring_cleanup had=%s removed=%s" % [had_ring, alpha._aggro_ring == null])
	await get_tree().create_timer(0.25).timeout
	if Game.shot_path == "":
		get_tree().quit(0)

func _target_name(c: Creature) -> String:
	if c.brain.attack_target == player:
		return "player"
	if c.brain.attack_target is Creature:
		return str((c.brain.attack_target as Creature).def.id)
	return "none"
