class_name Bonfire
extends StaticBody3D
## A fire. Interact: cook at it (station_id=bonfire/campfire) and cauterise a deep bleed.
##
## Owner rules (2026-10-28):
##   stone_fire_pit  permanent "firepit": the rocks stay, its wood shows and burns only while wood is
##                   loaded (load_wood), and when the fuel runs out the wood and flame go cold again.
##   bonfire, campfire  temporary: wood and flame from placement, they burn out after their fuel time,
##                   wear out over time (twice as fast outside a Domain) and are removed at 0.
## Cooking works only while a fire burns (can_cook / cook_block_reason; StationMenu drops COOK).
##
## Durability here is the fire's own wear (data: placed_kinds.<kind>.durability_per_minute); creature
## damage still goes through StructureHealth. Saved as fuel_seconds + durability, not wall time.

var kind: StringName = &"bonfire"
var station_id: StringName = &"bonfire"
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
## Fuel left, in seconds of burning. The campfire also mirrors it in seconds_left (older saves and
## the pack-up rule read that field).
var fuel_seconds: float = 0.0
var fuel_max_seconds: float = 600.0
## Wear durability: 0 for the permanent pit (it never decays).
var durability: float = 0.0
var max_durability: float = 0.0
## ASSUMPTION (docs 10/30/08 give no fire numbers): data defaults, overridable in structures.json.
const CAMPFIRE_SECONDS := 120.0
const FUEL_MAX_DEFAULT := 600.0
const WEAR_PER_MIN_DEFAULT := 1.0
const OUTSIDE_MULT_DEFAULT := 2.0
const WOOD_SECONDS_PER_BRANCH := 120.0
## Left over from the campfire-only lifetime; kept so older saves and pack-up rules read the same field.
var seconds_left: float = -1.0
var _fire_light: OmniLight3D
var _wood: Node3D
var _flame: Node3D
var _flicker_phase: float = randf() * TAU
var _wear_per_min: float = WEAR_PER_MIN_DEFAULT
var _outside_mult: float = OUTSIDE_MULT_DEFAULT
var _wood_seconds: float = WOOD_SECONDS_PER_BRANCH

func _ready() -> void:
	_apply_row()
	if not is_permanent() and fuel_seconds <= 0.0:
		queue_free() # Do not revive a fire saved on its burnout frame.
		return
	add_to_group("placed_building")
	if kind != &"campfire":
		add_to_group("bonfire")
	add_to_group("craft_station")
	if get_node_or_null("Shape") == null and get_node_or_null("Prop") == null and get_node_or_null("FallbackMesh") == null:
		PropVisuals.apply_building_visual(self, kind, Vector3(1.1, 0.7, 1.1), Color(0.85, 0.35, 0.1))
	_build_fire_nodes()
	_setup_fire_light()
	_sync_fire_nodes()
	_maybe_install_probe()

## WINDOWED LAB: the gate renders kitchen_lab and reads one measured "[firepits] RESULT" line. The
## probe lives here (in the fire's own file) so the lab scene needs no hook of its own; headless runs
## and every other lab never load it.
static var _probe_installed := false

func _maybe_install_probe() -> void:
	if _probe_installed or DisplayServer.get_name() == "headless":
		return
	if Game.lab_name != "kitchen_lab":
		return
	var shots := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shots = true
	if not shots:
		return
	_probe_installed = true
	var script := load("res://scripts/world/firepits_lab.gd") as GDScript
	if script == null:
		return
	var probe: Node = script.new()
	probe.name = "FirepitsProbe"
	get_tree().root.add_child.call_deferred(probe)

func _exit_tree() -> void:
	if World.runtime == null:
		return
	var grid: Variant = World.runtime.get("build_grid")
	if grid is BuildGrid:
		(grid as BuildGrid).release(self)

## structures.json placed_kinds gives fuel, wear and reload numbers per fire kind.
func _apply_row() -> void:
	var row := StructurePiece.placed_kind(kind)
	_wear_per_min = maxf(0.0, float(row.get("durability_per_minute", WEAR_PER_MIN_DEFAULT)))
	_outside_mult = maxf(1.0, float(row.get("outside_domain_multiplier", OUTSIDE_MULT_DEFAULT)))
	_wood_seconds = maxf(1.0, float(row.get("wood_seconds_per_branch", WOOD_SECONDS_PER_BRANCH)))
	fuel_max_seconds = maxf(1.0, float(row.get("fuel_max_seconds", FUEL_MAX_DEFAULT)))
	max_durability = 0.0 if is_permanent() else maxf(0.0, float(row.get("max_durability", 300.0)))

static func make(p_kind: StringName = &"bonfire") -> Bonfire:
	var b := Bonfire.new()
	b.persist_building = true
	b.kind = p_kind
	b.station_id = &"campfire" if p_kind == &"campfire" else &"bonfire"
	b._apply_row()
	# Temporary fires light from placement; the permanent pit waits for wood.
	if not b.is_permanent():
		b.fuel_seconds = float(StructurePiece.placed_kind(p_kind).get("fuel_seconds", CAMPFIRE_SECONDS))
		b.durability = b.max_durability
		if p_kind == &"campfire":
			b.seconds_left = b.fuel_seconds
	b.name = str(p_kind)
	return b

static func from_dict(d: Dictionary) -> Bonfire:
	var saved_kind := StringName(str(d.get("kind", "bonfire")))
	var b := make(saved_kind if saved_kind == &"stone_fire_pit" or saved_kind == &"campfire" else &"bonfire")
	var fuel_v: Variant = d.get("fuel_seconds", null)
	if fuel_v is int or fuel_v is float:
		b.fuel_seconds = clampf(float(fuel_v), 0.0, b.fuel_max_seconds)
	elif d.has("seconds_left") and b.kind == &"campfire":
		# A pre-FIREPITS campfire saved its lifetime as seconds_left.
		b.fuel_seconds = clampf(float(d.get("seconds_left")), 0.0, b.fuel_max_seconds)
	var dur_v: Variant = d.get("durability", null)
	if dur_v is int or dur_v is float:
		b.durability = clampf(float(dur_v), 0.0, b.max_durability)
	if b.kind == &"campfire":
		b.seconds_left = clampf(b.fuel_seconds, 0.0, b.fuel_max_seconds)
	var cell_v: Variant = d.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		b.build_cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	b.build_rot = int(d.get("rot", 0))
	return b

func pack_up(player: Player) -> bool:
	return BuildPlacer.pack_up_node(self, player)

# ASSUMPTION: the campfire is consumed as it burns, so only a fresh one repacks (pack + place would
# otherwise reset its fuel forever). A bonfire is a plain kit and always packs; a lit pit does not.
func pack_up_block_reason() -> String:
	if is_permanent():
		return "Put the fire out before packing it up" if burning() else ""
	if kind != &"campfire":
		return ""
	var initial := float(StructurePiece.placed_kind(kind).get("fuel_seconds", CAMPFIRE_SECONDS))
	return "A lit campfire can't be repacked" if seconds_left < initial - 1.0 else ""

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)

func to_dict() -> Dictionary:
	return {
		"kind": str(kind),
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"fuel_seconds": fuel_seconds,
		"durability": durability,
		"seconds_left": seconds_left,
		"x": global_position.x,
		"z": global_position.z,
	}

# ---------------------------------------------------------------- fire state

func is_permanent() -> bool:
	return kind == &"stone_fire_pit"

func burning() -> bool:
	return fuel_seconds > 0.0 and not is_queued_for_deletion()

func fuel_fraction() -> float:
	return clampf(fuel_seconds / maxf(1.0, fuel_max_seconds), 0.0, 1.0)

## Whether this fire can take another branch right now (the LOAD WOOD hex shows while it can).
func can_load_wood() -> bool:
	return fuel_seconds < fuel_max_seconds

## Seconds of fuel one unit of wood gives this fire.
func seconds_per_wood() -> float:
	return _wood_seconds

## Feed the fire from the player's bag (branches). Returns the seconds of fuel gained (0 when the
## fire is full or the bag holds no wood). This is how the permanent pit is lit.
func load_wood(player: Player) -> float:
	if player == null or not is_instance_valid(player) or player.inventory == null:
		return 0.0
	if fuel_seconds >= fuel_max_seconds:
		player.notice("The fire is already full")
		return 0.0
	var idx := player.inventory.find_first(&"branch")
	if idx < 0:
		player.notice("No branches to burn")
		return 0.0
	var added := minf(_wood_seconds, fuel_max_seconds - fuel_seconds)
	player.inventory.remove_at(idx, 1)
	fuel_seconds += added
	if kind == &"campfire":
		seconds_left = fuel_seconds
	_sync_fire_nodes()
	var mins := int(fuel_seconds) / 60
	print("[fire] %s loaded wood +%ds fuel=%ds (%dm %02ds)" % [kind, int(added), int(fuel_seconds), mins, int(fuel_seconds) % 60])
	return added

## One step of burning. The test drives this directly; _process calls it with the frame delta.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	fuel_seconds = maxf(0.0, fuel_seconds - delta)
	if not is_permanent():
		var mult := _outside_mult if not _in_domain() else 1.0
		durability = maxf(0.0, durability - _wear_per_min * mult * delta / 60.0)
		if kind == &"campfire":
			seconds_left = fuel_seconds
		if durability <= 0.0 or fuel_seconds <= 0.0:
			# Temporary fires are consumed: gone at burn-out or at 0 durability (no ash pile exists).
			_sync_fire_nodes()
			print("[fire] %s spent fuel=%.0f durability=%.0f -> removed" % [kind, fuel_seconds, durability])
			queue_free()
			return
	_sync_fire_nodes()

## Inside the survivor's Domain: the build grid's own claim check, the same one placement uses.
func _in_domain() -> bool:
	if World == null:
		return false
	if bool(World.is_home()):
		return true
	var rt: Variant = World.runtime
	if rt == null or not is_instance_valid(rt) or not (rt as Object).has_method("is_claimed"):
		return false
	return bool((rt as Object).call("is_claimed", BuildGrid.tile_of(global_position)))

func durability_fraction() -> float:
	if is_permanent() or max_durability <= 0.0:
		return 1.0
	return clampf(durability / max_durability, 0.0, 1.0)

# ---------------------------------------------------------------- cooking

func can_cook() -> bool:
	return burning()

## Why cooking is refused here ("" when the fire burns).
func cook_block_reason() -> String:
	if burning():
		return ""
	if is_permanent():
		return "Load wood to light the fire pit"
	return "The fire has burnt out"

## The structure info/inspect text: fuel left, and durability for a temporary fire.
func info_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if burning():
		out.append("Fuel %s" % _clock(fuel_seconds))
		out.append("Burning")
	else:
		out.append("Fuel 0:00 · Out")
	if not is_permanent():
		out.append("Durability %d/%d" % [int(round(durability)), int(round(max_durability))])
	if not can_cook() and is_permanent():
		out.append("Load wood to cook")
	return out

func info_text() -> String:
	return " · ".join(info_lines())

static func _clock(secs: float) -> String:
	var t := maxi(0, int(ceil(secs)))
	return "%d:%02d" % [t / 60, t % 60]

# ---------------------------------------------------------------- interactions

func cauterise(player: Player) -> void:
	if kind == &"campfire" or not player.statuses.has(&"deep_bleed"):
		return
	player.downed_by = "the bonfire"
	player.vitals.take_damage(5.0)
	player.statuses.clear_id(&"deep_bleed")
	print("[status] %s -deep_bleed cauterise" % player.name)

## PRD :285: a bonfire clears Wet. The HUD's Dry off hex calls this; a fire out of reach does nothing.
const DRY_OFF_REACH := 3.2

func dry_off(player: Player) -> bool:
	if player == null or not is_instance_valid(player) or player.statuses == null:
		return false
	if player.global_position.distance_to(global_position) > DRY_OFF_REACH:
		return false
	if not player.statuses.has(&"wet"):
		return false
	player.statuses.clear_id(&"wet")
	player.notice("Dry off: warmed by the fire")
	print("[status] %s -wet bonfire" % player.name)
	return true

# ---------------------------------------------------------------- visuals

## The permanent pit's baked model includes wood, so it hides the model and builds a stone ring of
## its own; its wood pile is a separate node that only shows while it holds fuel. Temporary fires
## keep their art (wood and flame are part of it) and get a flame that follows the burn state.
func _build_fire_nodes() -> void:
	var prop := get_node_or_null("Prop") as Node3D
	if is_permanent():
		if prop != null:
			prop.visible = false
		if get_node_or_null("StoneRing") == null:
			var ring := _make_stone_ring()
			add_child(ring)
		if get_node_or_null("WoodPile") == null:
			_wood = _make_wood_pile()
			add_child(_wood)
	_flame = _make_flame()
	add_child(_flame)

func _sync_fire_nodes() -> void:
	var lit := burning()
	if _wood != null:
		_wood.visible = lit
	if _flame != null:
		_flame.visible = lit

func wood_visible() -> bool:
	if is_permanent():
		return _wood != null and _wood.visible
	# A temporary fire's wood is part of its model: it is there for as long as the fire is.
	return not is_queued_for_deletion()

func flame_visible() -> bool:
	return _flame != null and _flame.visible

func _make_stone_ring() -> Node3D:
	var ring := Node3D.new()
	ring.name = "StoneRing"
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.52, 0.50, 0.47)
	stone.roughness = 0.95
	var count := 12
	for i in count:
		var a := TAU * float(i) / float(count)
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.20
		m.bottom_radius = 0.23
		m.height = 0.26
		m.radial_segments = 6
		mi.mesh = m
		mi.material_override = stone
		mi.position = Vector3(cos(a) * 0.92, 0.13, sin(a) * 0.92)
		mi.rotation.y = a
		ring.add_child(mi)
	# A second, lower course so the ring reads as two stones deep from the iso camera.
	for i in count:
		var a := TAU * (float(i) + 0.5) / float(count)
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.15
		m.bottom_radius = 0.17
		m.height = 0.18
		m.radial_segments = 6
		mi.mesh = m
		mi.material_override = stone
		mi.position = Vector3(cos(a) * 1.06, 0.09, sin(a) * 1.06)
		mi.rotation.y = a
		ring.add_child(mi)
	return ring

func _make_wood_pile() -> Node3D:
	## Four furze logs laid across the pit's ash, tips meeting in the middle: big and light enough to
	## read from the iso camera at phone size (a dark teepee disappeared under the flame).
	var pile := Node3D.new()
	pile.name = "WoodPile"
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.52, 0.36, 0.21)
	bark.roughness = 0.9
	var charred := StandardMaterial3D.new()
	charred.albedo_color = Color(0.22, 0.16, 0.12)
	charred.roughness = 1.0
	var ash := StandardMaterial3D.new()
	ash.albedo_color = Color(0.30, 0.28, 0.26)
	ash.roughness = 1.0
	var bed := MeshInstance3D.new()
	var bed_mesh := CylinderMesh.new()
	bed_mesh.top_radius = 0.46
	bed_mesh.bottom_radius = 0.48
	bed_mesh.height = 0.06
	bed_mesh.radial_segments = 14
	bed.mesh = bed_mesh
	bed.material_override = ash
	bed.position = Vector3(0.0, 0.03, 0.0)
	pile.add_child(bed)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.35
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.085
		m.bottom_radius = 0.095
		m.height = 1.18
		m.radial_segments = 7
		mi.mesh = m
		mi.material_override = bark
		# Laid across the ash bed, the inner end raised a little on the embers.
		mi.position = Vector3(cos(a) * 0.30, 0.15, sin(a) * 0.30)
		mi.rotation = Vector3(deg_to_rad(84.0), -a, 0.0)
		pile.add_child(mi)
		# A charred end where the log meets the fire.
		var tip := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.086
		tm.bottom_radius = 0.09
		tm.height = 0.2
		tm.radial_segments = 7
		tip.mesh = tm
		tip.material_override = charred
		tip.position = Vector3(cos(a) * 0.13, 0.19, sin(a) * 0.13)
		tip.rotation = Vector3(deg_to_rad(84.0), -a, 0.0)
		pile.add_child(tip)
	return pile

func _make_flame() -> Node3D:
	## A low, bright flame licking between the logs: the wood has to stay readable, so this is a
	## couple of small cones, not a bonfire column.
	var flame := Node3D.new()
	flame.name = "Flame"
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(1.0, 0.62, 0.20)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.48, 0.12)
	hot.emission_energy_multiplier = 2.6
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tongues := [[0.0, 0.0, 0.09, 0.26], [0.10, 0.07, 0.06, 0.18], [-0.09, -0.06, 0.06, 0.16]]
	for row in tongues:
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.005
		m.bottom_radius = float(row[2])
		m.height = float(row[3])
		m.radial_segments = 7
		mi.mesh = m
		mi.material_override = hot
		mi.position = Vector3(float(row[0]), 0.16 + float(row[3]) * 0.5, float(row[1]))
		flame.add_child(mi)
	flame.visible = false
	return flame

func _setup_fire_light() -> void:
	_fire_light = OmniLight3D.new()
	_fire_light.name = "FireLight"
	_fire_light.omni_range = 7.0
	_fire_light.omni_attenuation = 1.4
	_fire_light.light_color = Color(1.0, 0.55, 0.25)
	_fire_light.light_energy = 0.0
	_fire_light.shadow_enabled = false
	_fire_light.position = Vector3(0.0, 0.55, 0.0)
	add_child(_fire_light)
	set_process(true)

func _process(delta: float) -> void:
	tick(delta)
	if _fire_light == null or not is_instance_valid(self) or is_queued_for_deletion():
		return
	if not burning():
		_fire_light.light_energy = 0.0
		return
	var phase := Game.phase_name()
	var on := phase == &"night" or phase == &"dusk" or phase == &"dawn"
	if not on:
		_fire_light.light_energy = 0.0
		return
	var flicker := 1.0 + sin((Time.get_ticks_msec() * 0.001) * 6.5 + _flicker_phase) * 0.12
	flicker += sin((Time.get_ticks_msec() * 0.001) * 13.0 + _flicker_phase * 0.7) * 0.05
	_fire_light.light_energy = 3.6 * flicker
