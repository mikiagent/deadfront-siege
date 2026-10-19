extends Node3D
## Visual QA: compy baseline beside the two 3x raptor species. Headless it is a gate on body
## LENGTH: RiggedModel.setup scales every model to its data height, so height always matches by
## construction (printed only). Length is the mesh's own proportion, which normalisation does not
## set: a stubby or stretched model shows up as length far off real_length_m.

## ASSUMPTION: a model's nose-to-tail extent may sit 35 % off real_length_m (tail curl, pose).
const LENGTH_TOLERANCE := 0.35
var _models: Dictionary = {}

func _ready() -> void:
	var kit := LabKit.build(self, 36.0)
	var player := kit["player"] as Player
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_spawn_frozen(&"compsognathus", Vector3(-3.2, 0.0, 0.0))
	_spawn_frozen(&"velociraptor", Vector3(0.0, 0.0, 0.0))
	_spawn_frozen(&"deinonychus", Vector3(4.0, 0.0, 0.0))
	var compy := Data.creature(&"compsognathus")
	var raptor := Data.creature(&"velociraptor")
	var deino := Data.creature(&"deinonychus")
	print("[dino_scale] compy h=%.2f l=%.2f velociraptor h=%.2f l=%.2f deinonychus h=%.2f l=%.2f" % [compy.height_meters, compy.real_length_m, raptor.height_meters, raptor.real_length_m, deino.height_meters, deino.real_length_m])
	_label("COMPY  2x", Vector3(-3.2, compy.height_meters + 0.5, 0.0))
	_label("VELOCIRAPTOR  3x", Vector3(0.0, raptor.height_meters + 0.5, 0.0))
	_label("DEINONYCHUS  3x", Vector3(4.0, deino.height_meters + 0.5, 0.0))
	print("[boot] lab=raptor_scale_lab")
	if LabResult.headless():
		call_deferred("_gate")

func _gate() -> void:
	var r := LabResult.new("raptor_scale")
	await get_tree().process_frame
	var lengths: Array[float] = []
	for species in [&"compsognathus", &"velociraptor", &"deinonychus"]:
		var def := Data.creature(species)
		var box := _visual_box(_models.get(species) as Node3D)
		var got := maxf(box.size.x, box.size.z)
		lengths.append(got)
		# Height is normalised by RiggedModel, so this ratio is 1.00 by construction: info only.
		print("[dino_scale] %s model_h=%.2f data_h=%.2f (normalised) model_l=%.2f data_l=%.2f l_ratio=%.2f" % [species,
			box.size.y, def.height_meters, got, def.real_length_m, got / maxf(0.01, def.real_length_m)])
		r.expect(absf(got / maxf(0.01, def.real_length_m) - 1.0) <= LENGTH_TOLERANCE,
			"%s model length %.2f m vs data %.2f m" % [species, got, def.real_length_m])
	r.expect(lengths[0] < lengths[1] and lengths[1] < lengths[2], "compy < velociraptor < deinonychus by model length")
	r.finish(get_tree(), "lengths=%.2f/%.2f/%.2f" % [lengths[0], lengths[1], lengths[2]])

## World-space bounds of every visible mesh under the creature (rest-pose AABBs).
func _visual_box(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	if root == null:
		return out
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Label3D:
			continue
		var box := vi.global_transform * vi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out

func _spawn_frozen(species: StringName, at: Vector3) -> void:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = at
	c.spawn(Data.creature(species))
	c.process_mode = Node.PROCESS_MODE_DISABLED
	_models[species] = c

func _label(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 34
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.position = at
	add_child(label)
