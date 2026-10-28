class_name TamingPen
extends StaticBody3D
## Holds one captured animal. 30 real minutes, scaled by Game.time_scale. Success bonds the animal
## straight into the survivor's roster (origin capture); failure lets it escape. A full bonded
## roster (Data.bonded_cap(), spec 09) holds the finished animal here, unbonded and uncounted.

const BASE_SECONDS := 30.0 * 60.0
const SUCCESS_CHANCE := 0.70 ## ASSUMPTION:

var kind: StringName = &"makeshift_taming_pen"
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var occupant: ItemStack
var remaining: float = 0.0
var running: bool = false
var force_result: int = 0
var _told_full := false # the roster-full notice shows once per wait, not every frame

func _ready() -> void:
	add_to_group("placed_building")
	add_to_group("taming_pen")
	if get_node_or_null("Shape") == null and get_node_or_null("PropRing") == null and get_node_or_null("FallbackMesh") == null:
		_build_visual()

func _exit_tree() -> void:
	if World.runtime == null:
		return
	var grid: Variant = World.runtime.get("build_grid")
	if grid is BuildGrid:
		(grid as BuildGrid).release(self)

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)

func to_dict() -> Dictionary:
	var rec := {
		"kind": str(kind),
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"x": global_position.x,
		"z": global_position.z,
		"running": running,
		"remaining": remaining,
	}
	rec["occupant"] = occupant.to_dict() if occupant else null
	return rec

static func make() -> TamingPen:
	var pen := TamingPen.new()
	pen.kind = &"makeshift_taming_pen"
	pen.persist_building = true
	pen.name = "makeshift_taming_pen"
	return pen

static func from_dict(d: Dictionary) -> TamingPen:
	var pen := make()
	var cell_v: Variant = d.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		pen.build_cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	pen.build_rot = int(d.get("rot", 0))
	pen.running = bool(d.get("running", false))
	pen.remaining = float(d.get("remaining", 0.0))
	var occ: Variant = d.get("occupant", null)
	if occ is Dictionary:
		pen.occupant = ItemStack.from_dict(occ as Dictionary)
	return pen

func try_insert(player: Player) -> bool:
	if running or occupant != null:
		return false  # an animal is already inside; inserting would overwrite (and lose) it
	# Older saves can hold a tamed_animal item from the pen's old ending; a pen bonds it, then still
	# takes a captured_animal in the same tap (a survivor can hold both).
	if player.inventory.find_first(&"tamed_animal") >= 0:
		var before := player.bonded.size()
		player.bond_from_inventory()
		if player.bonded.size() > before:
			player.notice("Bonded the animal from your bag.")
		else:
			player.notice("Bonded roster full (%d / %d): the tamed animal stays in your bag." % [player.bonded.size(), Data.bonded_cap()])
			return true  # at the bonded cap: the legacy item stays, nothing else can start
	var idx := player.inventory.find_first(&"captured_animal")
	if idx < 0:
		return false
	occupant = player.inventory.remove_at(idx, 1)
	# NATURES: the pen wait is the base 30 minutes times the animal's nature (Stubborn longer,
	# Docile shorter). Read once, at insert: the animal's nature rides on the captured stack.
	var nat := StringName(str(occupant.attributes.get("nature", "")))
	remaining = BASE_SECONDS * float(CreatureNatures.knobs(nat).get("pen_time_mult", 1.0))
	running = true
	print("[capture] pen start %s" % occupant.attributes.get("species", "?"))
	return true

func feed(player: Player) -> bool:
	if not running or occupant == null:
		return false
	if remaining <= 0.0:
		_notice_full(player) # finished and waiting for a bonded slot: meat would only restart the timer
		return false
	var meat := player.inventory.find_first(&"raptor_meat")
	if meat < 0:
		return false
	player.inventory.remove_at(meat, 1)
	remaining = maxf(5.0, remaining * 0.6)
	print("[capture] pen fed remaining=%.1fs" % remaining)
	return true

func _process(delta: float) -> void:
	if not running or occupant == null:
		running = false
		return
	remaining -= delta * Game.time_scale
	if remaining > 0.0:
		return
	var player := PlayerRegistry.local()
	if player == null:
		return  # stays finished-but-running until a survivor is around to receive it
	# Spec 09: a bond takes a bonded slot. At the cap the animal waits here (caged and penned animals
	# never count) and the pen resolves on the first frame a slot is free: nothing is lost or rolled twice.
	if player.bonded.size() >= Data.bonded_cap():
		if not _told_full:
			_told_full = true
			_notice_full(player)
		return
	_told_full = false
	var species := StringName(str(occupant.attributes.get("species", "velociraptor")))
	var def := Data.creature(species)
	if def == null:
		# The species left data while the animal was in the pen: keep it and keep the pen running
		# (retry each game minute), so a save made now finishes it once the data is back. Pack-up
		# still hands the animal back.
		remaining = 60.0
		print("[capture] pen occupant %s is not in data; pen left waiting" % species)
		return
	running = false
	var ok := randf() < SUCCESS_CHANCE
	if force_result > 0:
		ok = true
	elif force_result < 0:
		ok = false
	if ok:
		var genes_raw: Variant = occupant.attributes.get("genetics", {})
		var genes := CreatureGenetics.from_dict(genes_raw) if genes_raw is Dictionary else CreatureGenetics.roll(null, def.coloration)
		var rec := PetRecord.from_def(def, &"", StringName(str(occupant.attributes.get("variant", ""))), genes, int(occupant.attributes.get("level", 1)))
		rec.origin = &"capture"
		# NATURES: the animal keeps the nature it had in the field (from_dict derives one otherwise).
		var nat := StringName(str(occupant.attributes.get("nature", "")))
		rec.nature = nat if CreatureNatures.is_valid(nat) else CreatureNatures.from_uid(rec.uid, rec.species, def.archetype)
		rec.tamer = player.display_name()
		player.bonded.append(rec)
		player.notice("%s bonded (grade %s, Lv. %d)." % [str(def.species), rec.grade, rec.level])
		print("[capture] pen %s bonded grade=%s lv=%d uid=%s" % [species, rec.grade, rec.level, rec.uid])
	else:
		print("[capture] pen %s escaped" % species)
		_spawn_wild(def)
	occupant = null

func _notice_full(player: Player) -> void:
	var species := str(occupant.attributes.get("species", "animal")).capitalize() if occupant else "Animal"
	player.notice("Bonded roster full (%d / %d): the %s waits in the pen. Animal Handling (Survival) adds slots." % [player.bonded.size(), Data.bonded_cap(), species])

func _spawn_wild(def: CreatureDef) -> void:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	get_parent().add_child(c)
	c.global_position = global_position + Vector3(2, 0, 0)
	c.spawn(def)
	c.brain.state = &"flee"

func _build_visual() -> void:
	PropVisuals.ensure_foundation(self, &"makeshift_taming_pen")
	PropVisuals.ensure_collision(self, Vector3(4.0, 1.8, 4.0))
	var ring := Node3D.new()
	ring.name = "PropRing"
	add_child(ring)
	var fence_path := PropVisuals.model_path(&"makeshift_taming_pen")
	var gate_path := PropVisuals.model_path(&"gate")
	var placed := 0
	for part in _ring_layout():
		var node: Node3D = null
		var path := gate_path if bool(part["gate"]) else fence_path
		if path != "" and ResourceLoader.exists(path):
			var packed := load(path)
			if packed is PackedScene:
				node = (packed as PackedScene).instantiate() as Node3D
		if node == null:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(2.0, 1.4, 0.2)
			mesh.mesh = box
			mesh.position.y = 0.7
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.55, 0.4, 0.22)
			mesh.material_override = mat
			node = mesh
		node.position = part["pos"]
		node.rotation.y = deg_to_rad(float(part["rot"]))
		ring.add_child(node)
		placed += 1
	if placed <= 0:
		PropVisuals.apply_building_visual(self, &"makeshift_taming_pen", Vector3(3.2, 1.4, 3.2), Color(0.55, 0.4, 0.22))

func _ring_layout() -> Array[Dictionary]:
	return [
		{"pos": Vector3(-1.0, 0.0, -1.92), "rot": 0, "gate": false},
		{"pos": Vector3(1.0, 0.0, -1.92), "rot": 0, "gate": false},
		{"pos": Vector3(-1.0, 0.0, 1.92), "rot": 0, "gate": false},
		{"pos": Vector3(1.0, 0.0, 1.92), "rot": 0, "gate": true},
		{"pos": Vector3(-1.92, 0.0, -1.0), "rot": 90, "gate": false},
		{"pos": Vector3(-1.92, 0.0, 1.0), "rot": 90, "gate": false},
		{"pos": Vector3(1.92, 0.0, -1.0), "rot": 90, "gate": false},
		{"pos": Vector3(1.92, 0.0, 1.0), "rot": 90, "gate": false},
	]
