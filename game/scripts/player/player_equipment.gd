class_name PlayerEquipment
extends Node
## Shows worn armor on the survivor. The single survivor mesh is swapped for four body regions; each
## head/body/arms/legs item with a "visual" ("<kit>/<piece>") attaches that kit piece to the live skeleton
## and hides the body regions its kit.json lists. Every clip keeps working: pieces share the base bones.
## A worn bag (either accessory slot) attaches its mesh from assets/characters/survivor/bags, tinted by
## the bag's natural colour (spec 35): only the "bag_body" material, straps and toggles keep theirs.

const ROOT := "res://assets/characters/survivor"
const PIECE_FOR_SLOT := {&"head": "helmet", &"body": "chest", &"arms": "arms", &"legs": "legs"}
const BAG_SLOTS: Array[StringName] = [&"accessory1", &"accessory2"]
const BAG_TINT_MATERIAL := "bag_body"
## ASSUMPTION: a bag without a recorded natural colour (crafted from untinted hide, old saves) draws
## as plain tanned hide; no material in data/items.json defines a default hide colour.
const DEFAULT_BAG_TINT := Color("#9a7a55")

var rig: RiggedModel
var inventory: Inventory
var body: Dictionary = {}      # region -> Array[MeshInstance3D]
var equipped: Dictionary = {}  # slot -> {"visual": String, "meshes": Array, "hides": Array}
var _kits: Dictionary = {}     # kit name -> kit.json "slots"

func setup(p_rig: RiggedModel, p_inventory: Inventory) -> void:
	rig = p_rig
	inventory = p_inventory
	if rig == null or rig.skeleton == null or rig.mesh_root == null:
		return
	var base := rig.mesh_root.find_children("*", "MeshInstance3D", true, false)
	for region in PIECE_FOR_SLOT.values():
		body[region] = RiggedModel.attach_skinned(rig.skeleton, "%s/body/body_%s.glb" % [ROOT, region])
		if (body[region] as Array).is_empty():
			# No body regions: keep the single mesh (armor still attaches, nothing gets hidden).
			_free_body()
			break
	if not body.is_empty():
		for m in base:
			(m as MeshInstance3D).visible = false
	for region in body:
		for m in body[region]:
			PlayerView.web_safe_mesh(m)
	inventory.changed.connect(refresh)
	refresh()

## Equip or unequip whatever differs between the inventory and what is shown.
func refresh() -> void:
	if rig == null or rig.skeleton == null:
		return
	for slot in PIECE_FOR_SLOT:
		var item := inventory.equipped_in(slot)
		var visual := item.def().visual if item and item.def() else ""
		var shown := str((equipped.get(slot, {}) as Dictionary).get("visual", ""))
		if visual == shown:
			continue
		if visual == "":
			unequip(slot)
		else:
			equip(slot, visual)
	for slot in BAG_SLOTS:
		var bag := inventory.equipped_in(slot)
		var bag_id := str(BagCapacity.bag_id_of(bag.def_id)) if bag else ""
		var tint := bag_tint(bag) if bag_id != "" else Color.WHITE
		var visual := "bags/%s#%s" % [bag_id, tint.to_html()] if bag_id != "" else ""
		if visual == str((equipped.get(slot, {}) as Dictionary).get("visual", "")):
			continue
		if visual == "":
			unequip(slot)
		else:
			equip_bag(slot, bag_id, tint, visual)

## The bag instance's natural colour: the "tint" its primary material carried into the craft.
static func bag_tint(bag: ItemStack) -> Color:
	return bag.tint_color() if bag and bag.attributes.has("tint") else DEFAULT_BAG_TINT

func equip_bag(slot: StringName, bag_id: String, tint: Color, visual: String = "") -> void:
	unequip(slot)
	var meshes := RiggedModel.attach_skinned(rig.skeleton, "%s/bags/%s.glb" % [ROOT, bag_id])
	for m in meshes:
		PlayerView.web_safe_mesh(m)
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			var mat := m.get_surface_override_material(s) as StandardMaterial3D
			if src and mat and src.resource_name == BAG_TINT_MATERIAL:
				mat.albedo_color *= tint
	equipped[slot] = {"visual": visual, "meshes": meshes, "hides": []}

func equip(slot: StringName, visual: String) -> void:
	unequip(slot)
	var kit := visual.get_slice("/", 0)
	var piece := visual.get_slice("/", 1)
	var meshes := RiggedModel.attach_skinned(rig.skeleton, "%s/armor/%s/%s.glb" % [ROOT, kit, piece])
	for m in meshes:
		PlayerView.web_safe_mesh(m)
	CharacterLook.refresh(rig) # the survivor's chosen colours carry onto the new piece
	# A kit without this piece (travel_clothes has no helmet) attaches nothing and hides nothing.
	equipped[slot] = {"visual": visual, "meshes": meshes, "hides": _hides(kit, piece) if not meshes.is_empty() else []}
	_sync_body()

func unequip(slot: StringName) -> void:
	var cur: Dictionary = equipped.get(slot, {})
	for m in cur.get("meshes", []):
		(m as Node).queue_free()
	equipped.erase(slot)
	_sync_body()

## A body region shows unless some equipped piece hides it.
func _sync_body() -> void:
	var hidden := {}
	for slot in equipped:
		for region in (equipped[slot] as Dictionary)["hides"]:
			hidden[str(region)] = true
	for region in body:
		for m in body[region]:
			(m as MeshInstance3D).visible = not hidden.has(region)

func _hides(kit: String, piece: String) -> Array:
	if not _kits.has(kit):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/armor/%s/kit.json" % [ROOT, kit]))
		_kits[kit] = (parsed as Dictionary).get("slots", {}) if parsed is Dictionary else {}
	var slot_info: Variant = (_kits[kit] as Dictionary).get(piece, {})
	return (slot_info as Dictionary).get("hides", [piece]) if slot_info is Dictionary else [piece]

func _free_body() -> void:
	for region in body:
		for m in body[region]:
			(m as Node).queue_free()
	body.clear()
