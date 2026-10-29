class_name CraftStation
extends StaticBody3D
## Workbench or drying rack. Recipes with a matching station_id need the player within 2 m.
## Kinds with a processing.json row also run timed jobs through a ProcessStation child.

@export var station_id: StringName = &"workbench"
var kind: StringName = &"workbench"
## Spec 30 §10: capabilities are data-driven tags plus a station level, never the display name. A
## crafted Workbench gets its tags and the level computed from its ingredients (BuildFlow.complete);
## a kit-placed one starts at level 1 (one step below the blueprint's minimum, so it cannot fake a
## crafted level). Recipes requiring Workbench >= N therefore refuse it.
var station_tags: Array[StringName] = []
var station_level: int = 1
## Spec 10 §§2-3: what the exact materials gave the station. `inherited_attributes` are the primary
## material's traits ([{id, level}]); the rest is what those traits do here (BuildingQuality.effects).
var inherited_attributes: Array = []
var quality_durability: int = 0
var quality_duration_mult: float = 1.0
var quality_slots: int = 0
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var _pending_process: Dictionary = {}  # saved jobs, applied once the ProcessStation exists

func _ready() -> void:
	kind = station_id
	if station_tags.is_empty():
		station_tags = default_tags(station_id)
	add_to_group("craft_station")
	add_to_group("placed_building")
	add_to_group(str(station_id))
	if get_node_or_null("Shape") == null and get_node_or_null("Prop") == null and get_node_or_null("FallbackMesh") == null:
		PropVisuals.apply_building_visual(self, station_id, _fallback_size(), _fallback_color())
	_ensure_tap_zone()
	_apply_quality_health()
	# A saved row with jobs gets a ProcessStation even when processing.json no longer lists the kind:
	# its jobs come back as collectable outputs, so COLLECT and pack-up still work (never stranded).
	var ps := ProcessStation.attach_to(self, station_id, not _pending_process.is_empty())
	if ps:
		ps.quality_duration_mult = quality_duration_mult
		ps.quality_slots = quality_slots
		if not _pending_process.is_empty():
			ps.load_dict(_pending_process)
			_pending_process = {}
	StationState.attach_to(self, station_id)  # busy/idle props (spit, forge glow) for kinds with a row

## What a kind can do before a crafted instance gives it more (processing.json/recipes' station_tags
## take the crafted tags first). # ASSUMPTION: only the workbench family is tagged so far.
static func default_tags(sid: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	out.append(&"workbench" if sid == &"workbench" else sid)
	return out

func has_station_tag(tag: StringName) -> bool:
	return tag in station_tags

## Fold the inherited traits' durability into the station's health (created lazily, as ever, only
## when the traits actually add any: a plain station keeps the old lazily-created behaviour).
func _apply_quality_health() -> void:
	if quality_durability == 0:
		return
	var h := StructureHealth.of(self, true)
	if h:
		h.setup(maxf(1.0, h.max_hp + float(quality_durability)))

## The station's inspect line: "Lv 12 · High Density 3" ("" for a plain station with no traits,
## which keeps showing its name; the chip reads this from ProcessStation.label_text).
func quality_chip_text() -> String:
	return "" if inherited_attributes.is_empty() else quality_text()

## "Lv 12 · High Density 3".
func quality_text() -> String:
	return BuildingQuality.summary(station_level, inherited_attributes)

## Spec 10 §3: the trait-by-trait lines ("High Density Lv 2: +4 durability").
func quality_lines() -> PackedStringArray:
	var eff := BuildingQuality.effects(BuildingQuality.supported({}), inherited_attributes, true)
	return BuildingQuality.effect_lines(inherited_attributes, eff)

## Tag + minimum level per recipe (data: station_tags / station_level). "" when this station
## qualifies, else the player-facing reason. A recipe with no station tags keeps the old rule:
## it runs where its `station` names this kind.
static func station_gate(rec: Dictionary, tags: Array[StringName], level: int, sid: StringName) -> String:
	var want: Array = rec.get("station_tags", [])
	if want.is_empty():
		return "" if str(rec.get("station", "")) == str(sid) else "Needs a %s" % str(rec.get("station", "")).replace("_", " ")
	for t: Variant in want:
		var tag := StringName(str(t))
		if not (tag in tags):
			return "Needs a station tagged %s" % str(tag).replace("_", " ")
	var need := int(rec.get("station_level", 0))
	if level < need:
		return "Needs %s %d (this one is %d)" % [str((want[0] as Variant) if one_tag(want) else "station").replace("_", " ").capitalize(), need, level]
	return ""

static func one_tag(want: Array) -> bool:
	return want.size() == 1

func _exit_tree() -> void:
	if World.runtime == null:
		return
	var grid: Variant = World.runtime.get("build_grid")
	if grid is BuildGrid:
		(grid as BuildGrid).release(self)

func pack_up(player: Player) -> bool:
	return BuildPlacer.pack_up_node(self, player)

## Asked by BuildPlacer.pack_up_blocker on every pack-up path: a process station packs up only empty.
func pack_up_block_reason() -> String:
	var ps := ProcessStation.of(self)
	if ps:
		return ps.pack_up_block_reason()
	return "" if _pending_process.is_empty() else "collect the %s first" % str(station_id).replace("_", " ")

## What the station held, taken off it so no copy stays behind. Duck-typed: W2-BUILDSYS's
## StructureHealth calls it when damage destroys the station and drops the stacks into the bag, home
## cargo or a loot bag (spec 10:102, 11:155: never deleted).
func salvage_contents() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	var ps := ProcessStation.of(self)
	if ps:
		out = ps.salvage_contents()
	out.append_array(ProcessStation.saved_stacks(_pending_process))
	_pending_process = {}
	return out

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)

func to_dict() -> Dictionary:
	var d := {
		"kind": str(station_id),
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"x": global_position.x,
		"z": global_position.z,
		"station_level": station_level,
		"station_tags": _tag_strings(),
		"inherited_attributes": inherited_attributes.duplicate(true),
		"quality_durability": quality_durability,
		"quality_duration_mult": quality_duration_mult,
		"quality_slots": quality_slots,
	}
	var ps := ProcessStation.of(self)
	if ps and not ps.contents().is_empty():
		d["process"] = ps.to_dict()
	elif not _pending_process.is_empty():
		d["process"] = _pending_process
	return d

static func from_dict(d: Dictionary) -> CraftStation:
	var id := StringName(str(d.get("kind", "workbench")))
	var s := CraftStation.make(id)
	var cell_v: Variant = d.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		s.build_cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	s.build_rot = int(d.get("rot", 0))
	s.station_level = clampi(int(d.get("station_level", 1)), 1, SaveSanitizer.MAX_LEVEL)
	var tags: Variant = d.get("station_tags", [])
	if tags is Array and not (tags as Array).is_empty():
		s.station_tags.clear()
		for t: Variant in tags:
			s.station_tags.append(StringName(str(t)))
	var attrs: Variant = d.get("inherited_attributes", [])
	s.inherited_attributes = BuildingQuality.clean_attrs(attrs)
	var qd: Variant = d.get("quality_durability", 0)
	s.quality_durability = clampi(int(qd) if qd is int or qd is float else 0, 0, 600)
	var dm: Variant = d.get("quality_duration_mult", 1.0)
	s.quality_duration_mult = clampf(float(dm) if dm is int or dm is float else 1.0, 0.1, 1.0)
	var qs: Variant = d.get("quality_slots", 0)
	s.quality_slots = clampi(int(qs) if qs is int or qs is float else 0, 0, 8)
	var proc: Variant = d.get("process", {})
	if proc is Dictionary:
		s._pending_process = proc as Dictionary
	return s

func _tag_strings() -> Array:
	var out: Array = []
	for t in station_tags:
		out.append(str(t))
	return out

static func make(id: StringName) -> CraftStation:
	var s := CraftStation.new()
	s.station_id = id
	s.kind = id
	s.persist_building = true
	s.name = str(id)
	return s

func _fallback_size() -> Vector3:
	if station_id == &"forge":
		return Vector3(1.0, 1.0, 0.9)  # the data-built hearth (station_state.json body)
	return Vector3(1.6, 0.9, 0.8) if station_id == &"workbench" else Vector3(1.4, 1.4, 0.5)

func _fallback_color() -> Color:
	return Color(0.45, 0.32, 0.18) if station_id == &"workbench" else Color(0.62, 0.55, 0.38)

## A forgiving touch target over the whole visible station. The model's fitted physics box is
## deliberately tight for movement, but that made clicks near the workbench edges hit terrain.
func _ensure_tap_zone() -> void:
	if get_node_or_null("TapZone") != null:
		return
	var zone := Area3D.new()
	zone.name = "TapZone"
	zone.collision_layer = 2
	zone.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	var base := PropVisuals.collision_size(station_id, get_node_or_null("Prop") as Node3D, _fallback_size())
	box.size = Vector3(maxf(2.2, base.x + 0.8), maxf(1.6, base.y + 0.5), maxf(1.8, base.z + 0.8))
	cs.shape = box
	cs.position.y = box.size.y * 0.5
	zone.add_child(cs)
	add_child(zone)
