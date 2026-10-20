class_name LootBag
extends StaticBody3D
## What a destroyed, collapsed or demolished structure held when neither the bag nor home cargo had
## room: a loot bag on the ground at the spot, saved with the island's buildings until it is emptied
## (spec 10:102 "must not silently delete stored items", spec 11:155). Tap it to take things out.

var kind: StringName = &"loot_bag"
var storage: Inventory
var persist_building := true  # SaveGame._live_buildings saves it like any building row

## A bag at `at` (dropped to the ground) holding `stacks`; sized so every stack fits.
static func drop(at: Vector3, stacks: Array[ItemStack]) -> LootBag:
	var span := 0
	for s in stacks:
		span += s.slot_span()
	var b := LootBag.new()
	b.storage = Inventory.new(maxi(1, span))
	for s in stacks:
		b.storage.add(s)
	b.position = at
	if World.runtime:
		World.runtime.add_child(b)
	print("[struct] loot bag at %s holds %d stacks" % [at.snapped(Vector3.ONE * 0.1), b.storage.used_slots()])
	return b

## Save rows are user-editable: contents go through Inventory.load_array (ItemStack.from_dict checks
## each), position must be numbers.
static func from_dict(d: Dictionary) -> LootBag:
	var raw: Variant = d.get("contents", [])
	var rows: Array = raw if raw is Array else []
	var b := LootBag.new()
	b.storage = Inventory.new(maxi(1, rows.size()))
	b.storage.load_array(rows)
	var x: Variant = d.get("x", 0.0)
	var z: Variant = d.get("z", 0.0)
	b.position = Vector3(float(x) if x is float or x is int else 0.0, 0.0, float(z) if z is float or z is int else 0.0)
	return b

func to_dict() -> Dictionary:
	return {"kind": str(kind), "x": position.x, "z": position.z, "contents": storage.to_array()}

func _ready() -> void:
	add_to_group("placed_building")  # the survivor's building tap reaches interact()
	collision_layer = StructurePiece.LAYER_TAP  # tappable; creatures and the survivor walk through
	collision_mask = 0
	var rt := World.runtime
	if rt and rt.has_method("surface_y"):
		position.y = float(rt.surface_y(position.x, position.z))
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.5
	cs.shape = sh
	cs.position.y = 0.4
	add_child(cs)
	var tex := ItemIcons.texture(&"loot_bag")
	if tex:
		var icon := Sprite3D.new()
		icon.texture = tex
		icon.pixel_size = 0.0042
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.shaded = false
		icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		icon.position.y = 0.42
		add_child(icon)
	if storage.used_slots() <= 0:
		queue_free()

func interact(player: Node) -> bool:
	var ui: Variant = player.get("ui")
	if ui == null:
		return false
	ui.show_storage(storage, player, {"title": "Loot bag", "take_all": true, "on_empty": _on_empty})
	return true

func _on_empty() -> void:
	print("[struct] loot bag emptied")
	queue_free()
