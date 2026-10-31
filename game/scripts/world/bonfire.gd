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
## FIREFUEL (owner 2026-10-28): a branch buys 1 min, a log 5 min, a full fire holds 10 min, and the
## pit shows one log per minute of fire left (MAX_LOGS at full).
const WOOD_SECONDS_PER_BRANCH := 60.0
const WOOD_SECONDS_PER_LOG := 300.0
const MAX_LOGS := 10
const FUEL_ITEMS: Array[StringName] = [&"branch", &"wood_log"]
## Left over from the campfire-only lifetime; kept so older saves and pack-up rules read the same field.
var seconds_left: float = -1.0
var _fire_light: OmniLight3D
var _wood: Node3D
var _flame: Node3D
var _flicker_phase: float = randf() * TAU
var _wear_per_min: float = WEAR_PER_MIN_DEFAULT
var _outside_mult: float = OUTSIDE_MULT_DEFAULT
var _wood_seconds: float = WOOD_SECONDS_PER_BRANCH
var _log_seconds: float = WOOD_SECONDS_PER_LOG
var _logs: Array[Node3D] = []
var _embers: MeshInstance3D
var _fx: Array[CPUParticles3D] = []
## WEATHER (FireWeather): a roof over it, how walled in that module is, the rain's soak (a temporary fire
## goes out at 1), the smoke pooled under the roof (0..1), and the shelter re-check timer. Not saved.
var sheltered := false
var enclosed := 0.0
var roof_y := 0.0
var rain_soak := 0.0
var smoke := 0.0
var shelter_check := 0.0
var _steam: CPUParticles3D
var _smoke_layers: Array[MeshInstance3D] = []

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
	_log_seconds = maxf(1.0, float(row.get("wood_seconds_per_log", WOOD_SECONDS_PER_LOG)))
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
	return fuel_seconds < fuel_max_seconds and not (not burning() and is_inside_tree() and FireWeather.light_blocked(get_tree(), global_position))

## Seconds of fuel one unit of wood gives this fire.
func seconds_per_wood() -> float:
	return _wood_seconds

## Seconds of fuel one unit of `item_id` gives this fire (0: it does not burn here).
func seconds_for(item_id: StringName) -> float:
	match item_id:
		&"branch":
			return _wood_seconds
		&"wood_log":
			return _log_seconds
	return 0.0

## Feed the fire one branch, or a log when the bag has no branch (the old one-tap LOAD WOOD path).
func load_wood(player: Player) -> float:
	if player != null and is_instance_valid(player) and player.inventory != null \
			and player.inventory.find_first(&"branch") < 0 and player.inventory.find_first(&"wood_log") >= 0:
		return add_fuel(player, &"wood_log")
	return add_fuel(player, &"branch")

## Why `item_id` can't go in right now ("" when it can). The fuel sheet greys its button with this.
func fuel_block_reason(player: Player, item_id: StringName) -> String:
	if seconds_for(item_id) <= 0.0:
		return "That doesn't burn"
	if fuel_seconds >= fuel_max_seconds:
		return "The fire is already full"
	if not burning() and is_inside_tree() and FireWeather.light_blocked(get_tree(), global_position):
		return FireWeather.TOO_WET
	if player == null or not is_instance_valid(player) or player.inventory == null or player.inventory.find_first(item_id) < 0:
		return "No %s to burn" % ("logs" if item_id == &"wood_log" else "branches")
	return ""

## Feed the fire one `item_id` (branch or wood_log) from the player's bag. Returns the seconds of fuel
## gained (0 when refused, with a notice). This is how the permanent pit is lit.
## ASSUMPTION: fuel past the 10 min cap is lost (a log into a 7 min fire tops it up to 10 min).
func add_fuel(player: Player, item_id: StringName) -> float:
	if player == null or not is_instance_valid(player) or player.inventory == null:
		return 0.0
	var why := fuel_block_reason(player, item_id)
	if why != "":
		player.notice(why)
		return 0.0
	var added := minf(seconds_for(item_id), fuel_max_seconds - fuel_seconds)
	player.inventory.remove_at(player.inventory.find_first(item_id), 1)
	fuel_seconds += added
	if kind == &"campfire":
		seconds_left = fuel_seconds
	_sync_fire_nodes()
	var mins := int(fuel_seconds) / 60
	print("[fire] %s loaded %s +%ds fuel=%ds (%dm %02ds) logs=%d" % [kind, item_id, int(added), int(fuel_seconds), mins, int(fuel_seconds) % 60, logs_shown()])
	return added

## Logs the pit shows: one per started minute of fire left, 0..MAX_LOGS (0 = out, no wood).
func logs_shown() -> int:
	if not burning():
		return 0
	return clampi(ceili(fuel_seconds / 60.0 - 0.001), 1, MAX_LOGS)

## The look of the fire as it runs down: roaring (7-10 min), burning (3-6), low (1-2, embers), out.
func fuel_state() -> StringName:
	var n := logs_shown()
	if n <= 0:
		return &"out"
	if n >= 7:
		return &"roaring"
	return &"burning" if n >= 3 else &"low"

## Flame size for the state (1 = roaring).
func flame_scale() -> float:
	match fuel_state():
		&"roaring":
			return 1.0
		&"burning":
			return 0.72
		&"low":
			return 0.42
	return 0.0

## One step of burning. The test drives this directly; _process calls it with the frame delta.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var was_burning := burning()
	fuel_seconds = maxf(0.0, fuel_seconds - delta * FireWeather.fuel_mult(self))
	if FireWeather.step(self, delta) and was_burning:
		fuel_seconds = 0.0  # the rain put it out
		print("[fire] %s put out by the rain" % kind)
		var w := FireWeather.weather()
		if w:
			w.fire_out.emit(self)
	if was_burning and fuel_seconds <= 0.0:
		_stop_cooking()
	if not is_permanent():
		var mult := (_outside_mult if not _in_domain() else 1.0) * FireWeather.wear_mult(self)
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

## A craft that was running here when the fire went out stops: inputs stay in the bag (StationCraft
## keeps them until a craft finishes), so nothing is lost and nothing cooks on a dead fire.
func _stop_cooking() -> void:
	for p in PlayerRegistry.all():
		var sc: Variant = p.get("station_craft") if p != null else null
		if sc != null and sc.get("crafting") == true and sc.get("station") == self:
			sc.call("cancel_and_refund")
			p.notice("The fire went out")

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
		out.append({&"roaring": "Burning (roaring)", &"low": "Burning low"}.get(fuel_state(), "Burning"))
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
## its own; its wood pile shows one log per minute of fuel (FIREFUEL). Temporary fires keep their art
## (their wood is part of it). Every fire gets the particle flame, sized by how much fuel is left.
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
	var n := logs_shown()
	if _wood != null:
		_wood.visible = n > 0
		for i in _logs.size():
			_logs[i].visible = i < n
	if _embers != null:
		# Low fires glow hottest in the coals: the flame is small, the bed is the tell.
		var mat := _embers.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 1.7 if fuel_state() == &"low" else 1.0
	if _flame != null:
		_flame.visible = lit
		for e in _fx:
			if e.emitting != lit:
				e.emitting = lit

func wood_visible() -> bool:
	if is_permanent():
		return _wood != null and _wood.visible
	# A temporary fire's wood is part of its model: it is there for as long as the fire is.
	return not is_queued_for_deletion()

## Logs drawn right now (the pit's visible log meshes; the test reads it against logs_shown()).
func visible_log_count() -> int:
	if _wood == null or not _wood.visible:
		return 0
	var c := 0
	for l in _logs:
		if l.visible:
			c += 1
	return c

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
	# The ash bed stays in the cold pit (no wood, no flame: just grey ash inside the rocks).
	var ash := StandardMaterial3D.new()
	ash.albedo_color = Color(0.16, 0.15, 0.14)
	ash.roughness = 1.0
	var bed := MeshInstance3D.new()
	var bed_mesh := CylinderMesh.new()
	bed_mesh.top_radius = 0.62
	bed_mesh.bottom_radius = 0.64
	bed_mesh.height = 0.05
	bed_mesh.radial_segments = 16
	bed.mesh = bed_mesh
	bed.material_override = ash
	bed.position = Vector3(0.0, 0.025, 0.0)
	ring.add_child(bed)
	return ring

## Ten log slots, filled in this order so any count reads as a fire: 0-1 two logs crossed on the coals
## (a low fire), 2-7 a six-log teepee over them, 8-9 two more laid against the teepee's foot.
const LOG_SLOTS := [
	# [angle deg, radial offset m, height m, tilt from vertical deg, length m]
	[20.0, 0.0, 0.10, 90.0, 0.95], [110.0, 0.0, 0.19, 90.0, 0.95],
	[0.0, 0.26, 0.36, 28.0, 0.9], [60.0, 0.26, 0.36, 28.0, 0.9], [120.0, 0.26, 0.36, 28.0, 0.9],
	[180.0, 0.26, 0.36, 28.0, 0.9], [240.0, 0.26, 0.36, 28.0, 0.9], [300.0, 0.26, 0.36, 28.0, 0.9],
	[150.0, 0.50, 0.10, 90.0, 0.8], [330.0, 0.50, 0.10, 90.0, 0.8],
]

func _make_wood_pile() -> Node3D:
	var pile := Node3D.new()
	pile.name = "WoodPile"
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.52, 0.36, 0.21)
	bark.roughness = 0.9
	var charred := StandardMaterial3D.new()
	charred.albedo_color = Color(0.16, 0.11, 0.08)
	charred.roughness = 1.0
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.9, 0.35, 0.08)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.26, 0.03)
	hot.emission_energy_multiplier = 1.2
	_embers = MeshInstance3D.new()
	_embers.name = "Embers"
	var em := CylinderMesh.new()
	em.top_radius = 0.34
	em.bottom_radius = 0.40
	em.height = 0.07
	em.radial_segments = 12
	_embers.mesh = em
	_embers.material_override = hot
	_embers.position = Vector3(0.0, 0.05, 0.0)
	pile.add_child(_embers)
	_logs.clear()
	for i in LOG_SLOTS.size():
		var row: Array = LOG_SLOTS[i]
		var a := deg_to_rad(float(row[0]))
		var tilt := deg_to_rad(float(row[3]))
		var length := float(row[4])
		var lg := Node3D.new()
		lg.name = "Log%d" % i
		var r := float(row[1])
		lg.position = Vector3(cos(a) * r, float(row[2]), sin(a) * r)
		# Teepee logs lean their top in over the centre; flat logs lie along their angle.
		var axis := Vector3(-cos(a) * sin(tilt), cos(tilt), -sin(a) * sin(tilt)) if tilt < 1.5 else Vector3(cos(a), 0.0, sin(a))
		lg.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.07
		m.bottom_radius = 0.085
		m.height = length
		m.radial_segments = 7
		mi.mesh = m
		mi.material_override = bark
		lg.add_child(mi)
		var tip := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.072
		tm.bottom_radius = 0.075
		tm.height = length * 0.3
		tm.radial_segments = 7
		tip.mesh = tm
		tip.material_override = charred
		# Charred where it meets the fire: a teepee log's top, a flat log's inner end (the middle of the cross).
		tip.position = Vector3(0.0, length * 0.36 if tilt < 1.5 else (-length * 0.36 if r > 0.0 else 0.0), 0.0)
		lg.add_child(tip)
		pile.add_child(lg)
		_logs.append(lg)
	return pile

## FIREFUEL flame: CPU particles (every renderer, web included) on a soft additive sprite. A tall
## flame body, a bright core, rising embers and a few smoke wisps; ~70 particles a fire at most.
## Built at roaring size; _flame.scale shrinks it as the fuel runs down (local coords, so it all scales).
static var _soft_tex: GradientTexture2D

static func _soft() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(0.5, 0.0)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex

## A flame tongue: pointed top, round soft bottom, hot centre (built once, 32x64).
static var _tongue_tex: ImageTexture

static func _tongue() -> Texture2D:
	if _tongue_tex == null:
		var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var sv := (float(y) + 0.5) / 64.0  # 0 top, 1 bottom
			var w := pow(sv, 0.75)
			if sv > 0.72:
				w *= sqrt(maxf(0.0, 1.0 - pow((sv - 0.72) / 0.28, 2.0)))
			for x in 32:
				var u := absf((float(x) + 0.5) / 16.0 - 1.0)
				var a := 0.0 if w <= 0.001 else clampf(1.0 - u / w, 0.0, 1.0)
				a = pow(a, 1.3) * smoothstep(0.0, 0.25, sv)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_tongue_tex = ImageTexture.create_from_image(img)
	return _tongue_tex

static func _sprite(size: Vector2, additive: bool, tex: Texture2D = null) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex if tex != null else _soft()
	var q := QuadMesh.new()
	q.size = size
	q.material = mat
	return q

static func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func (r: Array) -> float: return float(r[0])))
	g.colors = PackedColorArray(stops.map(func (r: Array) -> Color: return r[1]))
	return g

static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	return c

func _emitter(nm: String, amount: int, life: float, mesh: QuadMesh) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.name = nm
	e.amount = amount
	e.lifetime = life
	e.mesh = mesh
	e.local_coords = true
	e.preprocess = life
	e.randomness = 0.4
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.direction = Vector3.UP
	e.emitting = false
	_fx.append(e)
	return e

func _make_flame() -> Node3D:
	var flame := Node3D.new()
	flame.name = "Flame"
	flame.position = Vector3(0.0, 0.12, 0.0)
	_fx.clear()
	# Flame body: orange tongues licking up ~1.2 m, narrowing as they rise.
	var body := _emitter("FlameBody", 36, 0.7, _sprite(Vector2(0.42, 0.9), true, _tongue()))
	body.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	body.emission_sphere_radius = 0.2
	body.position = Vector3(0.0, 0.25, 0.0)
	body.spread = 8.0
	body.gravity = Vector3(0.0, 1.6, 0.0)
	body.initial_velocity_min = 0.8
	body.initial_velocity_max = 1.4
	body.scale_amount_min = 0.7
	body.scale_amount_max = 1.25
	body.scale_amount_curve = _curve([Vector2(0.0, 0.6), Vector2(0.25, 1.0), Vector2(1.0, 0.25)])
	body.color_ramp = _ramp([[0.0, Color(1.0, 0.78, 0.35, 0.95)], [0.35, Color(1.0, 0.48, 0.1, 0.85)],
		[0.75, Color(0.75, 0.24, 0.03, 0.3)], [1.0, Color(0.25, 0.06, 0.0, 0.0)]])
	flame.add_child(body)
	# Core: a hot yellow-white heart low in the wood.
	var core := _emitter("FlameCore", 16, 0.45, _sprite(Vector2(0.34, 0.6), true, _tongue()))
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.emission_sphere_radius = 0.14
	core.spread = 8.0
	core.gravity = Vector3(0.0, 0.6, 0.0)
	core.initial_velocity_min = 0.4
	core.initial_velocity_max = 0.8
	core.scale_amount_curve = _curve([Vector2(0.0, 0.8), Vector2(0.3, 1.0), Vector2(1.0, 0.2)])
	core.color_ramp = _ramp([[0.0, Color(1.0, 0.97, 0.8, 0.9)], [0.5, Color(1.0, 0.75, 0.3, 0.7)], [1.0, Color(1.0, 0.4, 0.1, 0.0)]])
	flame.add_child(core)
	# Embers: sparks that shoot up past the flame and drift.
	var sparks := _emitter("Embers", 16, 1.6, _sprite(Vector2(0.035, 0.035), true))
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.2
	sparks.position = Vector3(0.0, 0.2, 0.0)
	sparks.spread = 30.0
	sparks.gravity = Vector3(0.0, 0.2, 0.0)
	sparks.initial_velocity_min = 1.2
	sparks.initial_velocity_max = 2.4
	sparks.damping_min = 0.6
	sparks.damping_max = 1.2
	sparks.color_ramp = _ramp([[0.0, Color(1.0, 0.85, 0.4, 1.0)], [0.6, Color(1.0, 0.45, 0.1, 0.9)], [1.0, Color(0.8, 0.15, 0.0, 0.0)]])
	flame.add_child(sparks)
	# Smoke: a few grey wisps above the flame, growing and drifting off.
	var smoke_fx := _emitter("Smoke", 8, 3.0, _sprite(Vector2(0.55, 0.55), false))
	smoke_fx.position = Vector3(0.0, 1.4, 0.0)
	smoke_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke_fx.emission_sphere_radius = 0.15
	smoke_fx.spread = 15.0
	smoke_fx.gravity = Vector3(0.12, 0.2, 0.05)
	smoke_fx.initial_velocity_min = 0.4
	smoke_fx.initial_velocity_max = 0.7
	smoke_fx.scale_amount_curve = _curve([Vector2(0.0, 0.5), Vector2(1.0, 2.2)])
	smoke_fx.color_ramp = _ramp([[0.0, Color(0.3, 0.29, 0.28, 0.0)], [0.2, Color(0.32, 0.31, 0.3, 0.32)], [1.0, Color(0.45, 0.45, 0.45, 0.0)]])
	flame.add_child(smoke_fx)
	flame.visible = false
	return flame

## WEATHER: in rain the flame shrinks and sputters and steam hisses off it; under a roof smoke pools.
func _weather_look() -> void:
	var lvl := 0 if sheltered else FireWeather.rain_level()
	var lit := burning()
	if _flame:
		var t := Time.get_ticks_msec() * 0.001
		var damp := clampf(0.12 * float(lvl) + 0.4 * rain_soak, 0.0, 0.65)
		var sputter := (0.18 * float(lvl) / 3.0) * absf(sin(t * 23.0 + _flicker_phase) * sin(t * 7.3))
		var k := maxf(0.2, 1.0 - damp - sputter)
		var f := maxf(0.05, flame_scale())
		_flame.scale = Vector3(lerpf(1.0, k, 0.5), k, lerpf(1.0, k, 0.5)) * f
	if lvl > 0 and lit and _steam == null:
		_steam = _make_steam()
		add_child(_steam)
	if _steam:
		_steam.emitting = lvl > 0 and lit
	if smoke > 0.01 and _smoke_layers.is_empty():
		for i in 2:
			_smoke_layers.append(_make_smoke_layer(i))
	for i in _smoke_layers.size():
		var layer := _smoke_layers[i]
		layer.visible = smoke > 0.01
		layer.position.y = roof_y - global_position.y - 0.35 - 0.45 * float(i)
		(layer.material_override as StandardMaterial3D).albedo_color.a = smoke * 0.55 if i == 0 else smoke * smoke * 0.5

## Steam and hiss: pale puffs rising off the wet fire (CPU, at most 10 alive).
func _make_steam() -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.name = "Steam"
	e.amount = 10
	e.lifetime = 1.1
	e.position = Vector3(0.0, 0.3, 0.0)
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.2
	e.direction = Vector3.UP
	e.spread = 20.0
	e.gravity = Vector3(0.0, 0.8, 0.0)
	e.initial_velocity_min = 0.3
	e.initial_velocity_max = 0.7
	e.scale_amount_min = 0.8
	e.scale_amount_max = 1.6
	var m := SphereMesh.new()
	m.radius = 0.07
	m.height = 0.14
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.86, 0.88, 0.9, 0.45)
	m.material = mat
	e.mesh = m
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.6))
	fade.add_point(Vector2(1.0, 1.4))
	e.scale_amount_curve = fade
	return e

## A sheet of grey smoke hanging under the roof (two: a top one, and a lower one once it is thick).
func _make_smoke_layer(i: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "SmokeLayer%d" % i
	var pm := PlaneMesh.new()
	var side := StructurePiece.module_m() * (1.05 - 0.15 * float(i))
	pm.size = Vector2(side, side)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.42, 0.42, 0.44, 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

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
	_weather_look()
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
	_fire_light.light_energy = 3.6 * flicker * maxf(0.35, flame_scale())
