extends Node3D
## Visual QA: compy baseline beside the two 3x raptor species. Headless it is a gate: each
## model's visible height must track its data height and the three must keep their order.

## ASSUMPTION: a model may stand 35 % off its data height (pose, head carriage, tail arch).
const HEIGHT_TOLERANCE := 0.35
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
	var heights: Array[float] = []
	for species in [&"compsognathus", &"velociraptor", &"deinonychus"]:
		var want: float = Data.creature(species).height_meters
		var got := _visual_height(_models.get(species) as Node3D)
		heights.append(got)
		print("[dino_scale] %s model_h=%.2f data_h=%.2f ratio=%.2f" % [species, got, want, got / maxf(0.01, want)])
		r.expect(absf(got / maxf(0.01, want) - 1.0) <= HEIGHT_TOLERANCE, "%s model %.2f m vs data %.2f m" % [species, got, want])
	r.expect(heights[0] < heights[1] and heights[1] < heights[2], "compy < velociraptor < deinonychus by model height")
	r.finish(get_tree(), "heights=%.2f/%.2f/%.2f" % [heights[0], heights[1], heights[2]])

## World-space height of every visible mesh under the creature (rest-pose AABBs).
func _visual_height(root: Node3D) -> float:
	if root == null:
		return 0.0
	var top := -INF
	var bottom := INF
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Label3D:
			continue
		var box := vi.global_transform * vi.get_aabb()
		top = maxf(top, box.end.y)
		bottom = minf(bottom, box.position.y)
	return top - bottom if top > bottom else 0.0

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
