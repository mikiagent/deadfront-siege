class_name StructurePiece
extends StaticBody3D
## One modular building piece (foundation, wall, doorway, door, window, ceiling, roof, roof ridge,
## pillar, stairs, ramp, and the chest, large box and sign that stand on a floor) at a slot of the global module lattice. Everything a piece is comes from
## structures.json: its model (a GLB path per tier; empty or missing = StructureMesh stand-in), slot,
## sockets, durability and material cost. A saved piece is a spec-10 building instance (to_dict).
##
## Slot = Vector4i(module x, module z, level, code). Codes: CELL (a module square's slab), EDGE_X
## (the line x = module x * M, running along Z), EDGE_Z (z = module z * M, along X), CORNER, DOOR_X /
## DOOR_Z (the door inside a doorway on that edge), ON_FLOOR (stairs standing on a slab) and STAIRWELL
## (the open slab slots a staircase keeps clear above itself).
##
## Physics: walkable pieces are on LAYER_WALK. Walls, doorways, windows, closed doors and pillars are
## on LAYER_WALK | LAYER_STRUCTURE, so creatures (mask 1) collide with them, and the owning survivor
## gets a collision exception: owned walls let the owner through while blocking enemies (HANDOFF
## section 8). TilePath does the same for paths (StructureGrid.enemy_cells, TilePath for_owner).
# ASSUMPTION: offline every structure belongs to the local survivor (owner_id "local"); W3 replaces
# the exception with a per-owner check on the server.

const LAYER_WALK := 1
const LAYER_TAP := 2
const LAYER_STRUCTURE := 16

const CELL := 0
const EDGE_X := 1
const EDGE_Z := 2
const CORNER := 3
const DOOR_X := 4
const DOOR_Z := 5
const ON_FLOOR := 6
const STAIRWELL := 7

const WALL_KINDS: Array[StringName] = [&"wall", &"doorway", &"window"]
const SLAB_KINDS: Array[StringName] = [&"foundation", &"ceiling", &"roof", &"roof_peak", &"ramp"]
## Rise direction of an oriented piece at rot 0..3, in module (x, z) steps.
const FWD: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

## The one binding to W2-OCCLUDE's see-through system (see _occlusion()).
const OCCLUSION_SCRIPT := "res://scripts/world/occlusion.gd"

static var _defs: Dictionary = {}

var kind: StringName = &"foundation"
var tier: StringName = &"thatch"
var slot: Vector4i = Vector4i.ZERO
var rot: int = 0
var floor0: float = 0.0     # the structure's level-0 floor height (world y)
var variant: int = 0        # foundation skirt / ramp drop in 0.1 m steps (picks the mesh + collider)
var span: int = 0           # slabs: modules from the nearest wall or pillar (structural support)
var uid: String = ""
var owner_id: String = "local"
var build_level: int = 1    # spec 10 finished building level
var inherited_attributes: Array = []
## What the inherited traits did (BuildingQuality.effects): durability added to max_hp, storage
## spaces added to the container. Kept so a save row round-trips the building's real numbers.
var quality_durability: int = 0
var quality_storage: int = 0
var door_open: bool = false
var storage: Inventory      # chests and large boxes (structures.json storage_slots), else null
var sign_text: String = ""  # signs (structures.json text_max)
var health: StructureHealth
var _visual: Node3D

# ------------------------------------------------------------------ definitions

static func defs() -> Dictionary:
	if _defs.is_empty():
		var f := FileAccess.open("res://data/structures.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f else null
		_defs = parsed if parsed is Dictionary else {"pieces": {}, "tiers": {}, "piece_tiers": {}}
	return _defs

static func piece_def(p_kind: StringName) -> Dictionary:
	var v: Variant = (defs().get("pieces", {}) as Dictionary).get(str(p_kind), {})
	return v if v is Dictionary else {}

static func tier_def(p_tier: StringName) -> Dictionary:
	var v: Variant = (defs().get("tiers", {}) as Dictionary).get(str(p_tier), {})
	return v if v is Dictionary else {}

static func blueprint(p_kind: StringName, p_tier: StringName) -> Dictionary:
	var row: Variant = (defs().get("piece_tiers", {}) as Dictionary).get(str(p_kind), {})
	var v: Variant = (row as Dictionary).get(str(p_tier), {}) if row is Dictionary else {}
	return v if v is Dictionary else {}

static func is_piece_kind(p_kind: StringName) -> bool:
	return (defs().get("pieces", {}) as Dictionary).has(str(p_kind))

static func is_tier(p_tier: StringName) -> bool:
	return (defs().get("tiers", {}) as Dictionary).has(str(p_tier))

static func tier_rank(p_tier: StringName) -> int:
	return int(tier_def(p_tier).get("rank", -1))

static func module_m() -> float:
	return float(defs().get("module_m", 2.0))

static func storey_m() -> float:
	return float(defs().get("storey_m", 2.5))

## Bag materials one piece costs: item id -> count, summed over the blueprint's material_slots.
static func cost(p_kind: StringName, p_tier: StringName) -> Dictionary:
	var out := {}
	for s in blueprint(p_kind, p_tier).get("material_slots", []):
		if s is Dictionary and str(s.get("item", "")) != "":
			var id := StringName(str(s["item"]))
			out[id] = int(out.get(id, 0)) + maxi(0, int(s.get("quantity", 0)))
	return out

static func max_durability(p_kind: StringName, p_tier: StringName) -> float:
	return maxf(1.0, float(blueprint(p_kind, p_tier).get("max_durability", 100.0)))

## Durability and repair materials of a kit-placed kind (structures.json placed_kinds, else "default").
static func placed_kind(p_kind: StringName) -> Dictionary:
	var kinds: Dictionary = defs().get("placed_kinds", {})
	var v: Variant = kinds.get(str(p_kind), kinds.get("default", {}))
	return v if v is Dictionary else {}

## World pose of a piece at a slot. Edge pieces run along X on EDGE_Z lines and along Z on EDGE_X.
static func pose(p_kind: StringName, p_slot: Vector4i, p_rot: int, p_floor0: float) -> Transform3D:
	var m := module_m()
	var y := p_floor0 + float(p_slot.z) * storey_m()
	var x := float(p_slot.x) * m
	var z := float(p_slot.y) * m
	match p_slot.w:
		EDGE_X, DOOR_X:
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, y, z + m * 0.5))
		EDGE_Z, DOOR_Z:
			return Transform3D(Basis(), Vector3(x + m * 0.5, y, z))
		CORNER:
			return Transform3D(Basis(), Vector3(x, y, z))
	var basis := Basis(Vector3.UP, float(posmod(p_rot, 4)) * PI * 0.5) if bool(piece_def(p_kind).get("oriented", false)) else Basis()
	return Transform3D(basis, Vector3(x + m * 0.5, y, z + m * 0.5))

## Every slot key a piece fills: its own slot, plus the second cell and stairwell of a staircase.
static func keys_for(p_kind: StringName, p_slot: Vector4i, p_rot: int) -> Array[Vector4i]:
	var out: Array[Vector4i] = [p_slot]
	if p_kind == &"stairs":
		var f := FWD[posmod(p_rot, 4)]
		out.append(Vector4i(p_slot.x + f.x, p_slot.y + f.y, p_slot.z, ON_FLOOR))
		out.append(Vector4i(p_slot.x, p_slot.y, p_slot.z + 1, STAIRWELL))
		out.append(Vector4i(p_slot.x + f.x, p_slot.y + f.y, p_slot.z + 1, STAIRWELL))
	return out

## The slot code a kind lives in.
static func slot_code(p_kind: StringName, edge_axis: int = EDGE_Z) -> int:
	match str(piece_def(p_kind).get("slot", "cell")):
		"edge":
			return edge_axis
		"door":
			return DOOR_X if edge_axis == EDGE_X else DOOR_Z
		"corner":
			return CORNER
		"on_floor":
			return ON_FLOOR
	return ON_FLOOR if p_kind == &"stairs" else CELL

static func make(p_kind: StringName, p_tier: StringName, p_slot: Vector4i, p_rot: int, p_floor0: float, p_variant: int = 0) -> StructurePiece:
	var p := StructurePiece.new()
	p.kind = p_kind
	p.tier = p_tier
	p.slot = p_slot
	p.rot = posmod(p_rot, 4)
	p.floor0 = p_floor0
	p.variant = p_variant
	p.uid = "b%08x%08x" % [randi(), randi()]
	p.name = "%s_%d_%d_%d_%d" % [p_kind, p_slot.x, p_slot.y, p_slot.z, p_slot.w]
	p.health = StructureHealth.new()
	p.health.name = StructureHealth.NODE_NAME
	p.health.setup(max_durability(p_kind, p_tier), -1.0, float(tier_def(p_tier).get("creature_mult", 1.0)))
	p.add_child(p.health)
	var slots := int(piece_def(p_kind).get("storage_slots", 0))
	if slots > 0:
		p.storage = Inventory.new(slots)
	return p

# ------------------------------------------------------------------ instance

func keys() -> Array[Vector4i]:
	return keys_for(kind, slot, rot)

func _ready() -> void:
	add_to_group("structure_piece")
	collision_mask = 0
	global_transform = pose(kind, slot, rot, floor0)
	_rebuild()
	_apply_layer()
	var occl := StringName(str(piece_def(kind).get("occlusion", "none")))
	if occl == &"wall":  # roofs and ceilings fade per storey of a building (StructureGrid.roof_group)
		_occlusion(self, occl)
	_let_owner_through()

## A tap on this piece opens its card (HUD). Floors, stairs and ramps are walked on, so a tap
## there stays a move; the card of a building's floors is reached from any wall's card.
func is_tap_target() -> bool:
	return not (kind in [&"foundation", &"ceiling", &"stairs", &"ramp"])

func set_sign_text(text: String) -> void:
	# ASSUMPTION: 48 characters (structures.json text_max); specs 05/10 and the PRDs give no sign limit.
	sign_text = text.strip_edges().left(int(piece_def(kind).get("text_max", 48)))
	var l := _visual.find_child("SignText", true, false) as Label3D if _visual else null
	if l:
		l.text = sign_text

## A destroyed, collapsed or demolished chest never deletes what it held: StructureHealth.salvage
## puts it in the bag of whoever took it down, then home cargo, then a loot bag at the spot.
func spill_storage(player: Node = null) -> void:
	var out := take_contents()
	if not out.is_empty():
		StructureHealth.salvage(out, pose(kind, slot, rot, floor0).origin, player)  # pose: valid off the tree too

## Empties the storage and returns what it held (the units move; no copy stays behind).
func take_contents() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	if storage == null:
		return out
	for i in storage.slot_count:
		if storage.slots[i] != null:
			out.append(storage.slots[i])
		storage.slots[i] = null
	storage.changed.emit()
	return out

## Reflect the inherited traits in the container's size (Lightweight/Heavy storage spaces, only for
## kinds that have storage at all — StructurePlacer.apply_effects only grants them there).
func apply_storage_bonus() -> void:
	if storage == null:
		return
	var base := int(piece_def(kind).get("storage_slots", 0))
	var want := maxi(1, base + quality_storage)
	if want > storage.slot_count:
		storage.grow_to(want)
		return
	# A Heavy material shrinks the box: only while the slots it would lose are empty, so a
	# re-applied or reloaded bonus can never delete stored items (spec 10 §4).
	while storage.slot_count > want and storage.slots[storage.slot_count - 1] == null:
		storage.slot_count -= 1
		storage.slots.resize(storage.slot_count)

func is_wall_type() -> bool:
	return kind in WALL_KINDS

func is_floor() -> bool:
	return kind == &"foundation" or kind == &"ceiling"

## Roofs and ceilings: their look hangs under the building's roof group, not under the piece.
func is_roof() -> bool:
	return str(piece_def(kind).get("occlusion", "none")) == "roof"

## Move the look under `group` (or back under the piece for null), keeping it where it is.
func attach_visual(group: Node3D) -> void:
	var to: Node = group if group else self
	if _visual == null or _visual.get_parent() == to:
		return
	if _visual.get_parent():
		_visual.reparent(to)
	else:
		to.add_child(_visual)
	_visual.global_transform = global_transform

## Rebuild the look and colliders for the current kind/tier/variant (placement, upgrade, load).
func _rebuild() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			remove_child(c)
			c.queue_free()
	var group: Node3D = _visual.get_parent() as Node3D if _visual and _visual.get_parent() != self else null
	if _visual:
		if _visual.get_parent():
			_visual.get_parent().remove_child(_visual)
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	var holder := _visual
	if kind == &"door":  # the leaf swings on a hinge at the opening's -X jamb
		var o := float((piece_def(&"doorway").get("opening", [1.1]) as Array)[0])
		var hinge := Node3D.new()
		hinge.name = "Hinge"
		hinge.position = Vector3(-o * 0.5 + 0.03, 0.02, 0.0)
		_visual.add_child(hinge)
		holder = hinge
	var model := _model_path()
	if model != "":
		var inst := (load(model) as PackedScene).instantiate()
		inst.name = "Model"
		holder.add_child(inst)
	else:
		var mi := MeshInstance3D.new()
		mi.name = "StandIn"
		mi.mesh = StructureMesh.mesh_for(kind, tier, variant)
		holder.add_child(mi)
	if kind == &"signboard":
		var l := Label3D.new()
		l.name = "SignText"
		l.text = sign_text
		l.position = Vector3(0, 1.25, 0.06)
		l.font_size = 56
		l.pixel_size = 0.005  # ~0.28 m letters: two lines fill the 1 x 0.6 m board, readable at iso zoom
		l.width = 180.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate = Color(0.12, 0.09, 0.06)
		holder.add_child(l)
	add_child(_visual)
	attach_visual(group)  # an upgraded roof keeps its place in the building's roof group
	for row in StructureMesh.shapes_for(kind, variant):
		var cs := CollisionShape3D.new()
		cs.shape = row[0]
		cs.transform = row[1]
		add_child(cs)
	_apply_door_pose()

## Blueprint model when it names an existing GLB, else "" (the stand-in mesh is used).
func _model_path() -> String:
	var path := str(blueprint(kind, tier).get("model", ""))
	if path == "" or not ResourceLoader.exists(path):
		return ""
	return path if load(path) is PackedScene else ""

func _apply_layer() -> void:
	if kind == &"door" and door_open:
		collision_layer = LAYER_TAP  # still tappable to close; nothing collides with it
	elif str(piece_def(kind).get("blocks", "none")) == "none":
		collision_layer = LAYER_WALK
	else:
		collision_layer = LAYER_WALK | LAYER_STRUCTURE

## The owner walks through its own blockers; creatures do not (they have no exception).
# shortcut: the exception lives on the current Player node; a re-instanced Player loses it until
# the pieces reload. Upgrade with the W3 per-owner server check.
func _let_owner_through() -> void:
	if str(piece_def(kind).get("blocks", "none")) == "none" or owner_id != "local":
		return
	var who := get_tree().get_first_node_in_group("player") as PhysicsBody3D
	if who:
		who.add_collision_exception_with(self)

func _apply_door_pose() -> void:
	var hinge := _visual.get_node_or_null("Hinge") as Node3D if _visual else null
	if hinge:
		hinge.rotation.y = deg_to_rad(-100.0) if door_open else 0.0

## Tap on a door toggles it (W2-PLAYER routes the survivor's structure tap here).
func interact(_player: Node = null) -> bool:
	if kind != &"door":
		return false
	set_door_open(not door_open)
	return true

func set_door_open(on: bool) -> void:
	door_open = on
	_apply_layer()
	_apply_door_pose()
	var g := grid()
	if g:
		g.refresh_piece(self)
	print("[struct] door %s" % ("open" if on else "closed"))

## Upgrade in place: same node, slot and pose; new look, colliders and full durability of the tier.
func set_tier(p_tier: StringName) -> void:
	tier = p_tier
	# The inherited traits stay with the piece (they came from its materials); only the tier's own
	# durability changes, plus what those traits add. # ASSUMPTION: spec 10 gives no re-levelling rule.
	health.setup(max_durability(kind, tier) + float(quality_durability), -1.0, float(tier_def(tier).get("creature_mult", 1.0)))
	if is_inside_tree():
		_rebuild()
		_apply_layer()

## Leave the grid, collapse whatever this held up, and free. Returns the pieces that fell with it.
func destroy(reason: String = "demolished", by: Node = null) -> Array[StructurePiece]:
	var fell: Array[StructurePiece] = []
	if is_queued_for_deletion():
		return fell
	var g := grid()
	spill_storage(by)
	if g:
		g.unregister(self)
	print("[struct] %s %s %s at %s" % [tier, kind, reason, slot])
	queue_free()
	if g:
		fell = g.collapse_unsupported()
	return fell

func grid() -> StructureGrid:
	var rt: Node = World.runtime if World else null
	var bg: Variant = rt.get("build_grid") if rt else null
	return (bg as BuildGrid).structures if bg is BuildGrid else null

func _exit_tree() -> void:
	var g := grid()
	if g and g.piece_at(slot) == self:
		g.unregister(self)
	if _visual and _visual.get_parent() != self and is_instance_valid(_visual):
		_visual.queue_free()  # a roof's look lives under its group: it goes with the piece

## Spec-10 building instance row (plus the slot fields the grid needs to rebuild it).
func to_dict() -> Dictionary:
	return {
		"kind": str(kind),
		"blueprint_id": str(kind),
		"tier": str(tier),
		"id": uid,
		"owner_id": owner_id,
		"level": build_level,
		"inherited_attributes": inherited_attributes.duplicate(true),
		"quality_durability": quality_durability,
		"quality_storage": quality_storage,
		"max_durability": health.max_hp,
		"current_durability": health.hp,
		"position": [slot.x, slot.y, slot.z, slot.w],
		"rotation": rot,
		"floor_y": floor0,
		"variant": variant,
		"open": door_open,
		"container_id": uid if storage else "",
		"contents": storage.to_array() if storage else [],
		"text": sign_text,
	}

## A saved row back into a piece, or null when the row is not a well-formed piece. Save files are
## user-editable and SaveSanitizer only shapes kit fields, so every field is type-checked here.
static func from_dict(row: Dictionary) -> StructurePiece:
	var k := StringName(str(row.get("kind", "")))
	var pos: Variant = row.get("position")
	if not is_piece_kind(k) or not pos is Array or (pos as Array).size() != 4:
		return null
	for v in pos:
		if not (v is int or v is float) or absf(float(v)) > 4000.0:
			return null
	var code := int(pos[3])
	if code < CELL or code > ON_FLOOR:
		return null  # STAIRWELL is never a piece's own slot
	var t := StringName(str(row.get("tier", "thatch")))
	var p := make(k, t if is_tier(t) else &"thatch", Vector4i(int(pos[0]), int(pos[1]), clampi(int(pos[2]), 0, 8), code),
		int(_num(row.get("rotation"), 0.0, 3.0, 0.0)), _num(row.get("floor_y"), -500.0, 500.0, 0.0), int(_num(row.get("variant"), 0.0, 40.0, 0.0)))
	if str(row.get("id", "")) != "":
		p.uid = str(row["id"]).left(32)
	p.owner_id = str(row.get("owner_id", "local")).left(64)
	# A row from before building quality (no `level`) loads as a sane level-1, trait-less piece.
	p.build_level = int(_num(row.get("level"), 1.0, 60.0, 1.0))
	var attrs: Variant = row.get("inherited_attributes", [])
	p.inherited_attributes = BuildingQuality.clean_attrs(attrs)
	var dq: Variant = row.get("quality_durability", 0)
	p.quality_durability = clampi(int(dq) if dq is int or dq is float else 0, 0, 600)
	if p.quality_durability != 0:  # only a row that kept its trait bonus gets it back
		p.health.setup(p.health.max_hp + float(p.quality_durability), -1.0, float(tier_def(p.tier).get("creature_mult", 1.0)))
	var sq: Variant = row.get("quality_storage", 0)
	p.quality_storage = clampi(int(sq) if sq is int or sq is float else 0, -p.storage.slot_count if p.storage else 0, 600)
	p.apply_storage_bonus()
	p.health.hp = _num(row.get("current_durability"), 0.0, p.health.max_hp, p.health.max_hp)
	p.door_open = k == &"door" and row.get("open", false) == true
	var contents: Variant = row.get("contents", [])
	if p.storage and contents is Array:
		p.storage.load_array(contents)
	var text: Variant = row.get("text", "")
	if k == &"signboard" and text is String:
		p.sign_text = (text as String).strip_edges().left(int(piece_def(k).get("text_max", 48)))
	return p

static func _num(v: Variant, lo: float, hi: float, fallback: float) -> float:
	return clampf(float(v), lo, hi) if (v is int or v is float) and not is_nan(float(v)) else fallback

## The one adapter to W2-OCCLUDE (Occlusion.make_occludable(node, "inside" | "between")): roofs and
## ceilings fade while the survivor is under them, walls and pillars where they stand between the
## camera and the survivor. How far they fade is the occlusion package's rule (owner 2026-10-20:
## partly see-through, never a clear hole; roofs keep a faint outline). Guarded so pieces simply
## stay opaque until that package merges. Mode &"none" releases the node (materials restored).
## Returns the surfaces that now fade.
static func _occlusion(node: Node3D, mode: StringName) -> int:
	if not ResourceLoader.exists(OCCLUSION_SCRIPT):
		return 0
	var occ: Variant = load(OCCLUSION_SCRIPT)
	if not occ is GDScript:
		return 0
	var fn := "release" if mode == &"none" else "make_occludable"
	for m in (occ as GDScript).get_script_method_list():
		if str(m.get("name", "")) == fn:
			if mode == &"none":
				(occ as GDScript).call(fn, node)
				return 0
			return int((occ as GDScript).call(fn, node, "inside" if mode == &"roof" else "between"))
	return 0
