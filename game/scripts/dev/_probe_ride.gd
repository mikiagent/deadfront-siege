extends Node3D
var player: Player
var c: Creature
var t := 0.0
var did := false

func _ready() -> void:
	var kit := LabKit.build(self, 60.0)
	player = kit["player"]
	var def := Data.creature(&"tyrannosaurus")
	var rec := PetRecord.from_def(def, &"A")
	c = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.is_pet = true
	c.pet_record = rec
	c.spawn(def, rec.variant)
	c.global_position = Vector3(6, 0, 0)

func _process(d: float) -> void:
	t += d
	if did or t < 1.0:
		return
	did = true
	player.mount(c)
	await get_tree().create_timer(0.4).timeout
	for clip in [&"idle", &"walk", &"run"]:
		c.view.rig.play(clip)
		for i in 4:
			await get_tree().create_timer(0.15).timeout
			var sad := c.view.rig.skeleton.get_children().filter(func(n): return n is MeshInstance3D and n.name == "saddle")
			var mi: MeshInstance3D = c.view.rig.skeleton.get_node_or_null("saddle")
			var a := mi.get_aabb() if mi else AABB()
			print("PROBE %s aabb pos=%s size=%s xform=%s" % [clip, a.position, a.size, mi.global_transform.origin])
	get_tree().quit(0)
