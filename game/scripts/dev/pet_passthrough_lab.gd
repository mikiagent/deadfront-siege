extends Node3D
## Verifies: pets never body-block the player (mutual collision exception), while wild
## creatures still collide with the player and pets still collide with wild creatures.

func _ready() -> void:
	var kit := LabKit.build(self)
	var player: Player = kit["player"]
	print("[boot] lab=pet_passthrough_lab")
	if DisplayServer.get_name() == "headless":
		get_tree().create_timer(0.4).timeout.connect(_check.bind(player))

func _check(player: Player) -> void:
	# Summon path: bond a raptor and summon it.
	var rec := PetRecord.new()
	rec.species = &"velociraptor"
	var def := Data.creature(&"velociraptor")
	rec.hp = def.hp
	player.bonded.append(rec)
	player.summon_pet(0)
	var pet: Creature = player.summoned_pets[0]
	# Wild creature next to it.
	var wild: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(wild)
	wild.global_position = player.global_position + Vector3(1.0, 0, 1.0)
	wild.spawn(def, &"")
	# Tame path: become_pet applies the exception immediately.
	var tamed: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(tamed)
	tamed.global_position = player.global_position + Vector3(-1.0, 0, 1.0)
	tamed.spawn(def, &"")
	var rec2 := PetRecord.new()
	rec2.species = def.id
	rec2.hp = def.hp
	tamed.become_pet(rec2)
	var tame_ok := tamed.get_collision_exceptions().has(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Collision exceptions are pair-based: listing the player on the pet is enough, and the
	# player's own list must stay untouched so its roll-through bookkeeping is unaffected.
	var summon_ok := pet.get_collision_exceptions().has(player)
	var wild_ok := not wild.get_collision_exceptions().has(player) and not player.get_collision_exceptions().has(wild)
	var pet_vs_wild := not pet.get_collision_exceptions().has(wild)
	print("[check] summon-path passthrough=%s wild-still-collides=%s pet-vs-wild-collides=%s tame-path=%s" % [summon_ok, wild_ok, pet_vs_wild, tame_ok])
	var passed := summon_ok and wild_ok and pet_vs_wild and tame_ok
	print("CHECK ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)
