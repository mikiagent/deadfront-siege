class_name TamingPen
extends StaticBody3D
## Holds one captured animal. 30 real minutes, scaled by Game.time_scale. Success bonds the animal
## straight into the survivor's roster (origin capture); failure lets it escape. A full bonded
## roster (Data.bonded_cap(), spec 09) holds the finished animal here, unbonded and uncounted.
## Pen tiers (data/taming_pens.json): each kind takes only species up to its size and value; the
## animal inside is shown at its full size, so a big tame overhangs the fence.

const BASE_SECONDS := 30.0 * 60.0
const SUCCESS_CHANCE := 0.70 ## ASSUMPTION:
## PEN-DIET: a preferred food cuts the remaining wait to 60 % (the pen's old meat rate); an accepted
## food helps half as much, as in field feeding (FieldTame PREFERRED 1.0 / ACCEPTED 0.5).
const PREFERRED_FEED_MULT := 0.6
const ACCEPTED_FEED_MULT := 0.8 ## ASSUMPTION: half the preferred cut
const TIERS_PATH := "res://data/taming_pens.json"

static var _tiers: Dictionary = {}

var kind: StringName = &"makeshift_taming_pen"
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var occupant: ItemStack
var remaining: float = 0.0
var running: bool = false
var force_result: int = 0
var _told_full := false # the roster-full notice shows once per wait, not every frame
## Why the last try_insert refused ("" after a start): the pen screen shows it.
var last_refusal: String = ""
## Why the last feed was refused ("" when it ate or the pen was not taming): the pen screen shows it.
var last_feed_refusal: String = ""
var _shown_species: String = "" # the species the Occupant view was built for

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

static func make(p_kind: StringName = &"makeshift_taming_pen") -> TamingPen:
	var pen := TamingPen.new()
	pen.kind = p_kind if is_pen_kind(p_kind) else &"makeshift_taming_pen"
	pen.persist_building = true
	pen.name = str(pen.kind)
	return pen

## Older saves have no tier: their pen kind was always makeshift_taming_pen (the small pen).
static func from_dict(d: Dictionary) -> TamingPen:
	var pen := make(StringName(str(d.get("kind", "makeshift_taming_pen"))))
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

# --- tiers (data/taming_pens.json) ---

static func tiers() -> Array:
	if _tiers.is_empty() and FileAccess.file_exists(TIERS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIERS_PATH))
		if parsed is Dictionary:
			_tiers = parsed as Dictionary
	return _tiers.get("tiers", []) as Array

static func tier_row(p_kind: StringName) -> Dictionary:
	for t: Variant in tiers():
		if t is Dictionary and str((t as Dictionary).get("kind", "")) == str(p_kind):
			return t as Dictionary
	return {}

static func is_pen_kind(p_kind: StringName) -> bool:
	return not tier_row(p_kind).is_empty()

static func pen_label(p_kind: StringName) -> String:
	return str(tier_row(p_kind).get("label", str(p_kind).replace("_", " ").capitalize()))

## How good a species is for pen purposes: its capture tier, with 0 (cannot be netted) above 5.
static func species_value(def: CreatureDef) -> int:
	return def.capture_tier if def.capture_tier > 0 else int(_tiers.get("zero_capture_tier_value", 6))

static func fits(p_kind: StringName, def: CreatureDef) -> bool:
	var row := tier_row(p_kind)
	if row.is_empty() or def == null:
		return false
	return def.real_length_m <= float(row.get("max_length_m", 0.0)) and species_value(def) <= int(row.get("max_value", 0))

## The smallest pen kind that takes the species (&"" when none does).
static func required_kind(def: CreatureDef) -> StringName:
	for t: Variant in tiers():
		if t is Dictionary and fits(StringName(str((t as Dictionary)["kind"])), def):
			return StringName(str((t as Dictionary)["kind"]))
	return &""

## ALPHATAG (owner 2026-10-29: "not tamable/capturable"): a pen never takes an alpha. The camera's
## stack carries the alpha genome, so a cage saved before this rule is refused like a fresh one.
static func alpha_refusal(stack: ItemStack) -> String:
	return FieldTame.ALPHA_REFUSAL if FieldTame.alpha_stack(stack) else ""

## The refusal for one captured stack: the alpha rule first, then the pen tier.
static func refuse_stack(p_kind: StringName, stack: ItemStack) -> String:
	var alpha := alpha_refusal(stack)
	if alpha != "":
		return alpha
	return refuse_text(p_kind, _species_def(stack))

## "" when this pen takes the species, else the player-facing reason.
static func refuse_text(p_kind: StringName, def: CreatureDef) -> String:
	if def == null or fits(p_kind, def):
		return ""
	var row := tier_row(p_kind)
	var what := "too big" if def.real_length_m > float(row.get("max_length_m", 0.0)) else "too valuable"
	var need := required_kind(def)
	return "The %s is %s for a %s: it needs a %s." % [str(def.species), what, pen_label(p_kind), pen_label(need) if need != &"" else "bigger pen"]

## `slot`: the bag slot of the captured animal to put in (the Taming Pen screen's pick); -1 takes the
## first one in the bag this pen can hold.
func try_insert(player: Player, slot: int = -1) -> bool:
	last_refusal = ""
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
	var idx := -1
	if slot >= 0 and slot < player.inventory.slots.size() and player.inventory.slots[slot] != null and player.inventory.slots[slot].def_id == &"captured_animal":
		idx = slot
	else:
		# The first animal this pen can hold, else the first one (refused below with its reason).
		for i in player.inventory.slots.size():
			var st: ItemStack = player.inventory.slots[i]
			if st == null or st.def_id != &"captured_animal":
				continue
			if refuse_stack(kind, st) == "":
				idx = i
				break
			if idx < 0:
				idx = i
	if idx < 0:
		return false
	last_refusal = refuse_stack(kind, player.inventory.slots[idx])
	if last_refusal != "":
		player.notice(last_refusal)
		print("[capture] pen refused: %s" % last_refusal)
		return false
	occupant = player.inventory.remove_at(idx, 1)
	# NATURES: the pen wait is the base 30 minutes times the animal's nature (Stubborn longer,
	# Docile shorter). Read once, at insert: the animal's nature rides on the captured stack.
	var nat := StringName(str(occupant.attributes.get("nature", "")))
	remaining = BASE_SECONDS * float(CreatureNatures.knobs(nat).get("pen_time_mult", 1.0))
	running = true
	print("[capture] pen start %s" % occupant.attributes.get("species", "?"))
	_sync_occupant()
	return true

## The pen's taming roll, on the same S-curve the field capture plate shows (TamingOdds): survival
## level against the animal's level, at the capture threshold's health (the health term is 0) and a
## tier-1 net. # ASSUMPTION: the pen reuses the capture curve; the old flat 70 % (SUCCESS_CHANCE) is
## only the fallback for an animal with no stack.
func odds(player: Player = null, st: ItemStack = null) -> float:
	var s := st if st != null else occupant
	if s == null:
		return SUCCESS_CHANCE
	return TamingOdds.odds_for_values(int(s.attributes.get("level", 1)), TamingOdds.capture_frac(), TamingOdds.taming_level(player), 1)

static func _species_def(st: ItemStack) -> CreatureDef:
	return Data.creature(StringName(str(st.attributes.get("species", "")))) if st else null

## PEN-DIET (spec 02: "validate food items and consume them exactly once"): the animal eats from
## its species' taming diet, preferred food first, then accepted food, one item per feed, and only
## after every refusal check. Spoiled meat and rot are in no diet, so they are refused.
func feed(player: Player) -> bool:
	last_feed_refusal = ""
	if not running or occupant == null:
		return false
	if remaining <= 0.0:
		_notice_full(player) # finished and waiting for a bonded slot: food would only restart the timer
		return false
	if remaining <= 5.0:
		last_feed_refusal = "Almost tamed: it does not need more food."
		return false # food cannot shorten a wait already at the 5 s floor, so none is eaten
	var def := _species_def(occupant)
	# ASSUMPTION: no capture-technique lock in the pen: the animal is already caught.
	var food := FieldTame.diet_food_in_bag(player.inventory, def)
	if food == &"":
		last_feed_refusal = feed_hint(def)
		print("[capture] pen refused feed: %s" % last_feed_refusal)
		return false
	var mult := PREFERRED_FEED_MULT if food in def.preferred_food else ACCEPTED_FEED_MULT
	player.inventory.remove_at(player.inventory.find_first(food), 1)
	remaining = maxf(5.0, remaining * mult) # remaining > 5 here, so a feed never lengthens the wait
	print("[capture] pen fed %s remaining=%.1fs" % [food, remaining])
	return true

## What the pen screen says when nothing in the bag fits: "Needs berry or herb leaf (or fibre stalk)."
static func feed_hint(def: CreatureDef) -> String:
	if def == null or (def.preferred_food.is_empty() and def.accepted_food.is_empty()):
		return "This animal takes no food here."
	var text := "Needs %s" % _food_names(def.preferred_food)
	if not def.accepted_food.is_empty():
		text += " (or %s)" % _food_names(def.accepted_food)
	return text + " in your bag."

static func _food_names(ids: Array[StringName]) -> String:
	var names: Array[String] = []
	for id in ids:
		var item := Data.item(id)
		names.append(item.display_name.to_lower() if item != null and item.display_name != "" else str(id).replace("_", " "))
	return " or ".join(names)

func _process(delta: float) -> void:
	_sync_occupant()
	_sync_label()
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
	var ok := TamingOdds.succeeds(odds(player))
	if force_result > 0:
		ok = true
	elif force_result < 0:
		ok = false
	if ok:
		var genes_raw: Variant = occupant.attributes.get("genetics", {})
		var genes := CreatureGenetics.from_dict(genes_raw) if genes_raw is Dictionary else CreatureGenetics.for_species(def)
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

## The animal in the pen, at its own size (its genetics' body size, never shrunk to the fence): a
## big tame's tail hangs over the rails. Gone when the pen is empty.
func _sync_occupant() -> void:
	var sp := str(occupant.attributes.get("species", "")) if occupant else ""
	if sp == _shown_species:
		return
	_shown_species = sp
	var old := get_node_or_null("Occupant")
	if old:
		remove_child(old)
		old.queue_free()
	var def := Data.creature(StringName(sp)) if sp != "" else null
	if def == null:
		return
	var view := CreatureView.new()
	view.name = "Occupant"
	add_child(view)
	view.setup(def, StringName(str(occupant.attributes.get("variant", ""))))
	var genes_raw: Variant = occupant.attributes.get("genetics", {})
	if genes_raw is Dictionary and not (genes_raw as Dictionary).is_empty():
		var genes := CreatureGenetics.from_dict(genes_raw)
		if genes.coloration != null:
			view.apply_coloration(genes.coloration)
		view.apply_genome(genes.size)
	view.rotation.y += deg_to_rad(35.0) # a little off the fence line, so the body reads from the iso camera
	var ap := view.animation_player()
	if ap:
		for clip in ["idle", "Idle"]:
			if ap.has_animation(clip):
				ap.play(clip)
				break

## "Taming 24m 10s" over an occupied pen, "Tamed: waiting for a pack slot" when done; hidden when empty.
func status_text() -> String:
	if occupant == null:
		return ""
	if remaining <= 0.0:
		return "Tamed: waiting for a pack slot"
	return "Taming %s" % FieldPlot.duration_text(ceili(remaining / maxf(0.01, Game.time_scale)))

func _sync_label() -> void:
	var t := status_text()
	var l := get_node_or_null("PenStatus") as Label3D
	if l == null:
		if t == "":
			return
		l = StationState.floating_label("PenStatus", 2.6)
		add_child(l)
	l.text = t
	l.visible = t != ""

func size_m() -> float:
	return float(tier_row(kind).get("size_m", 4.0))

func _build_visual() -> void:
	var side := size_m()
	PropVisuals.ensure_foundation(self, kind)
	PropVisuals.ensure_collision(self, Vector3(side, 1.8, side))
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
		node.scale.x = float(part.get("stretch", 1.0))
		ring.add_child(node)
		placed += 1
	if placed <= 0:
		PropVisuals.apply_building_visual(self, kind, Vector3(side - 0.8, 1.4, side - 0.8), Color(0.55, 0.4, 0.22))

## 2 m fence segments around a square of size_m(), stretched to fill a side; the gate is the last
## segment of the +Z side. The 4 m pen keeps its original 8 segments at +/-1.92.
func _ring_layout() -> Array[Dictionary]:
	var side := size_m()
	var n := maxi(1, roundi(side / 2.0))
	var seg := side / float(n)
	var edge := side * 0.5 - 0.08
	var out: Array[Dictionary] = []
	for i in n:
		var t := -side * 0.5 + seg * (float(i) + 0.5)
		var stretch := seg / 2.0
		out.append({"pos": Vector3(t, 0.0, -edge), "rot": 0, "gate": false, "stretch": stretch})
		out.append({"pos": Vector3(t, 0.0, edge), "rot": 0, "gate": i == n - 1, "stretch": stretch})
		out.append({"pos": Vector3(-edge, 0.0, t), "rot": 90, "gate": false, "stretch": stretch})
		out.append({"pos": Vector3(edge, 0.0, t), "rot": 90, "gate": false, "stretch": stretch})
	return out
