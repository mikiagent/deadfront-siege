class_name HeldModel
extends RefCounted
## The one place that puts a tool or weapon GLB in the survivor's right fist, so the gather
## tool and the hunting weapon share the same grip.

## survivor-v2's RightHand bone frame, measured from the rest pose: +Y runs wrist -> fingers,
## +Z leaves the palm, +X points out of the thumb side. Metres; the bone's cm scale is undone.
const PALM := Vector3(0.0, 0.11, 0.03)
## Kenney and Meshy props stand on +Y (butt at the bottom, head at the top) with the blade or
## head on -X. The handle runs out of the thumb side; the blade faces where the fingers point.
const GRIP := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
const GRIP_FROM_BUTT := 0.12  # the fist closes this far up the handle (fraction of its length)
const TOOL_SCALE := 0.55  # Kenney tools are ~1 m; this reads as a hand tool

## Weapon row while hunting, else the gather tool model. Null when neither has a model.
static func attach(anchor: Node3D, def_id: StringName, hunting: bool) -> Node3D:
	var path := ""
	var size := TOOL_SCALE
	if hunting:
		var row := weapon_row(def_id)
		var model := str(row.get("model", ""))
		if model != "" and model != "<null>":
			path = model if model.begins_with("res://") else "res://assets/props/%s.glb" % model
			# The crossbow ships oversized (props_manifest note): scale it to ~0.9 m in hand.
			var length := float(row.get("length_m", 0.0))
			if length > 0.0:
				size = 0.9 / length
	if path == "" or not ResourceLoader.exists(path):
		var key := PropVisuals.tool_model_key(def_id)
		path = "res://assets/props/kenney/%s.glb" % key if key != "" else ""
		size = TOOL_SCALE
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	var inst := packed.instantiate() as Node3D if packed else null
	if inst == null:
		return null
	inst.name = "HeldWeapon" if hunting else "HeldTool"
	anchor.add_child(inst)
	grip(inst, anchor, size)
	return inst

## props_manifest "weapons" row; blunt weapons without a row borrow the club's.
static func weapon_row(def_id: StringName) -> Dictionary:
	var rows: Dictionary = Data.props_manifest.get("weapons", {})
	var row: Variant = rows.get(str(def_id), null)
	var d := Data.item(def_id)
	# ASSUMPTION: maul and hammer read as clubs until they get their own models.
	if row == null and d and d.tool_class == &"none" and d.range_m <= 0.0:
		row = rows.get("club", null)
	return row if row is Dictionary else {}

## Handle through the palm, `size` metres per model unit, whatever the bone's own scale.
static func grip(inst: Node3D, anchor: Node3D, size: float) -> void:
	var s := anchor.global_basis.get_scale().x
	s = s if s > 0.0001 else 1.0
	var box := _bounds(inst, Transform3D.IDENTITY)
	var b := GRIP.scaled(Vector3.ONE * (size / s))
	# The handle runs up the model's own Y axis (x = z = 0) in every prop we ship.
	var hold := Vector3(0.0, box.position.y + box.size.y * GRIP_FROM_BUTT, 0.0)
	inst.transform = Transform3D(b, PALM / s - b * hold)

## Mesh bounds in the model's own space.
static func _bounds(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	if n is MeshInstance3D:
		out = xf * (n as MeshInstance3D).get_aabb()
	for c in n.get_children():
		var a := _bounds(c, xf * (c as Node3D).transform if c is Node3D else xf)
		if a.size != Vector3.ZERO:
			out = a if out.size == Vector3.ZERO else out.merge(a)
	return out
