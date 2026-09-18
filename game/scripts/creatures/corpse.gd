class_name Corpse
extends StaticBody3D
## Loot marker + timed corpse lifecycle. The dead creature mesh stays in its death pose.

var species: StringName = &""
var level: int = 1
var source_pack: int = 0
var loot: Inventory = Inventory.new(12)
var _expires_left: float = 90.0 # ASSUMPTION: corpse lifetime on the ground.
var _empty_despawn: float = 20.0 # ASSUMPTION: looted-empty corpses fade sooner.
var _owner: Creature
var _marker: Node3D
var _label_species: String = ""
var _tap_s: float = -999.0
var _fading: bool = false
var _emptied: bool = false

func setup(c: Creature) -> void:
	level = maxi(1, int(c.get("level")) if c.get("level") != null else 1)
	species = c.def.id
	source_pack = c.pack_id
	_owner = c
	_label_species = c.def.species
	name = "Corpse_%s" % species
	_roll_loot()
	_snap_owner_to_ground()

func _ready() -> void:
	add_to_group("corpse")
	collision_layer = 1
	collision_mask = 0
	_marker = _build_marker()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.55
	sh.height = 0.8
	cs.shape = sh
	cs.position.y = 0.4
	add_child(cs)
	_place_on_tile()
	if _owner:
		_owner.visible = true
		_owner.collision_layer = 0
		_owner.collision_mask = 1

func can_butcher(inv: Inventory) -> String:
	if _is_empty():
		return "empty"
	if not inv.has_tool_class(&"knife"):
		return "need tool knife"
	return ""

func butcher(player: Player) -> Array[ItemStack]:
	open_loot(player)
	return []

func open_loot(player: Player) -> void:
	if player == null or player.ui == null:
		return
	note_tapped()
	if _is_empty():
		_on_loot_empty()
		return
	var why := can_butcher(player.inventory)
	var readonly := "needs knife" if why == "need tool knife" else ""
	player.ui.show_storage(loot, player, {
		"title": "Loot · %s" % species_display_name(),
		"take_all": true,
		"readonly_reason": readonly,
		"on_take": Callable(self, "_on_take_from_loot"),
		"on_empty": Callable(self, "_on_loot_empty"),
	})
	if readonly == "":
		player.inventory.wear_gather_tool(&"knife")

## Radial options (Durango reference): one hex per loot stack, 1.6 s each, knife-gated.
func loot_options(inv: Inventory) -> Array:
	var out: Array = []
	var needs_knife := not inv.has_tool_class(&"knife")
	for i in loot.slot_count:
		var st: ItemStack = loot.slots[i]
		if st == null:
			continue
		out.append({"item": str(st.def_id), "min": st.count, "max": st.count, "tool": "knife" if needs_knife else "none", "seconds": 1.6, "slot": i})
	return out

## Take one loot stack (after the 1.6 s butcher). Returns the stack or null.
func take_slot(slot: int, player: Player) -> ItemStack:
	if slot < 0 or slot >= loot.slot_count or loot.slots[slot] == null:
		return null
	var st: ItemStack = loot.slots[slot]
	var taken := loot.remove_at(slot, st.count)
	if taken and player:
		player.inventory.wear_gather_tool(&"knife")
	_on_take_from_loot()
	return taken

func species_display_name() -> String:
	return _label_species if _label_species != "" else str(species).capitalize()

func plate_anchor() -> Vector3:
	return global_position + Vector3(0.0, 1.05, 0.0)

func note_tapped() -> void:
	_tap_s = _now_s()

func tapped_recently(seconds: float) -> bool:
	return _now_s() - _tap_s <= seconds

func _process(delta: float) -> void:
	if _fading:
		return
	_expires_left = maxf(0.0, _expires_left - delta)
	if _expires_left <= 0.0:
		_begin_fade()
		return
	if _is_empty() and not _emptied:
		_emptied = true
		_expires_left = minf(_expires_left, _empty_despawn)

func _roll_loot() -> void:
	var skill := Data.butchering_level()
	for row_v in Data.butcher_drops(species):
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		if skill < int(row.get("skill", 0)):
			continue
		var item_id := StringName(str(row.get("id", "")))
		if item_id == &"":
			continue
		var n := randi_range(int(row.get("min", 1)), int(row.get("max", int(row.get("min", 1)))))
		if n <= 0:
			continue
		var attrs: Dictionary = {}
		var raw_attrs: Variant = row.get("attributes", {})
		if raw_attrs is Dictionary:
			attrs = (raw_attrs as Dictionary).duplicate(true)
		loot.add(ItemStack.make(item_id, n, attrs))

func _on_take_from_loot() -> void:
	if _is_empty():
		_on_loot_empty()

func _on_loot_empty() -> void:
	if not _emptied:
		_emptied = true
		_expires_left = minf(_expires_left, _empty_despawn)

func _is_empty() -> bool:
	return loot.used_slots() <= 0

func _build_marker() -> Node3D:
	var marker := Node3D.new()
	marker.name = "LootMarker"
	add_child(marker)
	var path := "res://assets/props/kenney/box-open.glb"
	var placed := false
	if ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			marker.add_child((packed as PackedScene).instantiate())
			placed = true
	if not placed:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.22
		cyl.height = 0.03
		disc.mesh = cyl
		disc.position.y = 0.02
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.86, 0.84, 0.72, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = mat
		marker.add_child(disc)
		return marker
	marker.scale = Vector3.ONE * 0.35
	return marker

func _place_on_tile() -> void:
	if World.runtime == null:
		return
	var tile := BuildGrid.tile_of(global_position)
	global_position = BuildGrid.tile_centre(tile, World.runtime)
	if _marker:
		_marker.position = Vector3(0.0, 0.08, 0.0)

func _snap_owner_to_ground() -> void:
	if _owner == null or World.runtime == null:
		return
	var tile := BuildGrid.tile_of(_owner.global_position)
	var ground := BuildGrid.tile_centre(tile, World.runtime)
	_owner.global_position = ground + Vector3(0.0, 0.1, 0.0)

func _begin_fade() -> void:
	if _fading:
		return
	_fading = true
	collision_layer = 0
	collision_mask = 0
	print("[world] corpse despawned %s" % species)
	var tw := create_tween()
	if _marker:
		tw.parallel().tween_property(_marker, "scale", Vector3.ZERO, 0.45)
	if _owner and is_instance_valid(_owner):
		tw.parallel().tween_property(_owner, "scale", Vector3.ZERO, 0.55)
	tw.tween_interval(0.56)
	if _owner and is_instance_valid(_owner):
		tw.tween_callback(_owner.queue_free)
	tw.tween_callback(queue_free)

func _now_s() -> float:
	return float(Time.get_ticks_msec()) * 0.001
