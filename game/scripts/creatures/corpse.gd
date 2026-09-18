class_name Corpse
extends StaticBody3D
## Knife-butcher interactable spawned when a creature dies.

var species: StringName = &""
var source_pack: int = 0
var butchered: bool = false

func setup(c: Creature) -> void:
	species = c.def.id
	source_pack = c.pack_id
	name = "Corpse_%s" % species

func _ready() -> void:
	add_to_group("corpse")
	collision_layer = 1
	collision_mask = 0
	if get_child_count() > 0:
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 0.35, 0.55)
	mesh.mesh = box
	mesh.position.y = 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.12, 0.1)
	mesh.material_override = mat
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position.y = 0.18
	add_child(cs)

func can_butcher(inv: Inventory) -> String:
	if butchered:
		return "already butchered"
	if not inv.has_tool_class(&"knife"):
		return "need tool knife"
	return ""

func butcher(player: Player) -> Array[ItemStack]:
	var why := can_butcher(player.inventory)
	if why != "":
		print("[item] refused butcher %s: %s" % [species, why])
		return []
	var skill := Data.butchering_level()
	var drops := Data.butcher_drops(species)
	var got: Array[ItemStack] = []
	for row in drops:
		if not row is Dictionary:
			continue
		var need_skill := int(row.get("skill", 0))
		if skill < need_skill:
			continue
		var amin := int(row.get("min", 1))
		var amax := int(row.get("max", amin))
		var n := randi_range(amin, amax)
		var attrs: Dictionary = {}
		var raw_attrs: Variant = row.get("attributes", {})
		if raw_attrs is Dictionary:
			attrs = (raw_attrs as Dictionary).duplicate(true)
		var stack := ItemStack.make(StringName(str(row.get("id", ""))), n, attrs)
		var before := stack.count
		var left := player.inventory.add(stack)
		print("[item] butcher %s +%d %s %s" % [species, before - left, stack.def_id, stack.attributes])
		got.append(stack)
	player.inventory.wear_gather_tool(&"knife")
	butchered = true
	visible = false
	collision_layer = 0
	return got
