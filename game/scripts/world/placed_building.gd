extends StaticBody3D
## Home-island buildings: basket, tent, fence, gate, sign. Protected, no decay.

var kind: StringName = &"basket"
var storage: Inventory
var sign_text: String = ""
var is_cargo: bool = false
var protected: bool = true

const BASKET_SLOTS := 60 ## ASSUMPTION: PRD ~100; 60 for mobile UI.

static func make(p_kind: StringName):
	var b = (load("res://scripts/world/placed_building.gd") as GDScript).new()
	b.kind = p_kind
	b.name = str(p_kind)
	if p_kind == &"basket":
		b.storage = Inventory.new(BASKET_SLOTS)
	return b

static func from_dict(d: Dictionary):
	var b = make(StringName(str(d.get("kind", "basket"))))
	b.sign_text = str(d.get("text", ""))
	b.is_cargo = bool(d.get("cargo", false))
	if b.storage and d.has("contents"):
		b.storage.load_array(d.get("contents", []))
	return b

func to_dict() -> Dictionary:
	return {
		"kind": str(kind),
		"x": global_position.x,
		"z": global_position.z,
		"text": sign_text,
		"cargo": is_cargo,
		"contents": storage.to_array() if storage else [],
	}

func _ready() -> void:
	add_to_group("placed_building")
	add_to_group(str(kind))
	if kind == &"tent":
		add_to_group("tent")
	if kind == &"basket":
		add_to_group("basket")
	if get_child_count() > 0:
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	match kind:
		&"tent":
			box.size = Vector3(2.2, 1.6, 2.2)
		&"fence":
			box.size = Vector3(2.0, 1.2, 0.2)
		&"gate":
			box.size = Vector3(2.4, 1.6, 0.25)
		&"sign":
			box.size = Vector3(0.3, 1.5, 0.8)
		_:
			box.size = Vector3(1.2, 0.9, 1.2)
	mesh.mesh = box
	mesh.position.y = box.size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color()
	mesh.material_override = mat
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position.y = box.size.y * 0.5
	add_child(cs)
	if kind == &"tent":
		var area := Area3D.new()
		area.name = "Rest"
		var acs := CollisionShape3D.new()
		var ash := BoxShape3D.new()
		ash.size = Vector3(2.4, 2.0, 2.4)
		acs.shape = ash
		acs.position.y = 1.0
		area.add_child(acs)
		add_child(area)
		area.body_entered.connect(func (b: Node) -> void:
			if b is Player:
				World.resting_in_tent = true
		)
		area.body_exited.connect(func (b: Node) -> void:
			if b is Player:
				World.resting_in_tent = false
		)

func pack_up(player: Player) -> void:
	if not World.is_home():
		return
	var kit := _kit_id()
	if kit != &"":
		player.inventory.add(ItemStack.make(kit, 1))
	if storage:
		for i in storage.slot_count:
			var s := storage.slots[i]
			if s:
				player.inventory.add(s.duplicate_stack())
	print("[item] packed %s" % kind)
	queue_free()

func _kit_id() -> StringName:
	match kind:
		&"tent":
			return &"tent_kit"
		&"basket":
			return &"basket_kit"
		&"fence":
			return &"fence_kit"
		&"gate":
			return &"gate_kit"
		&"sign":
			return &"sign_kit"
		&"workbench":
			return &"workbench_kit"
		&"drying_rack":
			return &"drying_rack_kit"
		&"bonfire":
			return &"bonfire_kit"
		&"makeshift_taming_pen":
			return &"makeshift_taming_pen"
		_:
			return &""

func _color() -> Color:
	match kind:
		&"tent":
			return Color(0.55, 0.4, 0.22)
		&"fence", &"gate":
			return Color(0.4, 0.28, 0.14)
		&"sign":
			return Color(0.62, 0.5, 0.28)
		_:
			return Color(0.7, 0.55, 0.28)
