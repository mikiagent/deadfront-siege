class_name PlayerEquipment
extends Node
## Shows worn armor on the survivor. The single survivor mesh is swapped for four body regions; each
## head/body/arms/legs item with a "visual" ("<kit>/<piece>") attaches that kit piece to the live skeleton
## and hides the body regions its kit.json lists. Every clip keeps working: pieces share the base bones.

const ROOT := "res://assets/characters/survivor"
const PIECE_FOR_SLOT := {&"head": "helmet", &"body": "chest", &"arms": "arms", &"legs": "legs"}

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
