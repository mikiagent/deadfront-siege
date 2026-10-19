extends Node3D
## W1-COMBAT acceptance lab (headless): telegraphs live at the hit frame, the survivor's swing
## lands on the swing, the camera shakes on a heavy hit, kicks respect mass and body edges, and
## a BuildGrid fence ring blocks melee both ways (with a no-fence control). Measures motion and
## health, not bookkeeping. Prints "[combatrules] PASS" and exits 0, else FAIL lines and exit 1.
## Run: godot --headless --path game -- --lab=combat_rules_lab

var _player: Player
var _cam: IsoCamera
var _failures: Array[String] = []
var _game_t := 0.0
var _swing_probe := {}  # set while the swing timing phase watches the survivor

func _ready() -> void:
	# Runs after the survivor and Hunt each frame, so a swing is seen in the frame it starts.
	process_priority = 1000
	var kit := LabKit.build(self, 40.0)
	_player = kit["player"]
	_cam = kit["cam"]
	(kit["nav"] as Node3D).visible = false
	Game.max_creatures_per_island = 0
	print("[boot] lab=combat_rules_lab")
	_run.call_deferred()

## Game time (summed frame deltas), the clock the swing's hit timer runs on.
func _process(delta: float) -> void:
	_game_t += delta
	if _swing_probe.is_empty():
		return
	var c: Creature = _swing_probe["c"]
	if float(_swing_probe["swing_t"]) < 0.0 and _player.anim.current_clip == &"attack_primary":
		_swing_probe["swing_t"] = _game_t
	if float(_swing_probe["hit_t"]) < 0.0 and c.health.hp < float(_swing_probe["hp0"]) - 0.01:
		_swing_probe["hit_t"] = _game_t

func _check(ok: bool, msg: String) -> void:
	print("[combatrules] %s %s" % ["ok" if ok else "FAIL", msg])
	if not ok:
		_failures.append(msg)

func _run() -> void:
	await _secs(0.6)
	await _telegraph_phase()
	await _swing_timing_phase()
	await _camera_phase()
	await _kick_phase()
	await _fence_phase()
	CombatTuning.reset_overrides()
	if _failures.is_empty():
		print("[combatrules] PASS")
		get_tree().quit(0)
	else:
		print("[combatrules] FAIL count=%d" % _failures.size())
		get_tree().quit(1)

func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _now() -> float:
	return Time.get_ticks_msec() * 0.001

func _spawn(species: StringName, at: Vector3, parent: Node = null, think: bool = false) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	c.position = at
	(parent if parent else self).add_child(c)
	c.global_position = at
	c.spawn(Data.creature(species))
	if not think:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _reset_player(at: Vector3) -> void:
	for inst in _player.statuses.instances().duplicate():
		_player.statuses.clear_id(inst.id)
	_player.global_position = at
	_player.vitals.health = 1000.0
	_player.vitals.energy = _player.vitals.max_energy
	_player.hunt.stop()
	_player.hunt._kick_cd = 0.0
	_player.hunt._tackle_cd = 0.0
	_player.hunt._tactic_lock = 0.0

## pc-combat-02: the heavy's ring must still exist when the bite lands (was gone 0.18-0.42 s early).
func _telegraph_phase() -> void:
	for species in [&"velociraptor", &"protoceratops"]:
		var c := _spawn(species, Vector3(6, 0, -6))
		await _frames(2)
		var rec := {"live": -1, "at": 0.0}
		var t0 := _now()
		c.anim.attack_hit.connect(func (clip: StringName) -> void:
			if clip == &"attack_heavy" and int(rec["live"]) < 0:
				rec["live"] = Telegraph.live_for(c)
				rec["at"] = _now() - t0
		)
		c.anim.play_clip(&"attack_heavy")
		var waited := 0.0
		while int(rec["live"]) < 0 and waited < 4.0:
			await get_tree().process_frame
			waited = _now() - t0
		_check(int(rec["live"]) >= 1, "%s heavy: %d live telegraph(s) at the hit frame, %.2f s after windup" % [species, int(rec["live"]), float(rec["at"])])
		c.queue_free()
		await _secs(0.2)

## pc-combat-03: stone-knife damage lands on the swing, not on the press.
func _swing_timing_phase() -> void:
	_reset_player(Vector3(0, 1, 0))
	await _frames(5)
	LabKit.give(_player, &"stone_knife", 1)
	_player.inventory.equip(&"weapon", &"stone_knife")
	var c := _spawn(&"velociraptor", _player.global_position + Vector3(0, -0.9, -1.7))
	await _frames(5)
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	_swing_probe = {"c": c, "hp0": c.health.hp, "swing_t": -1.0, "hit_t": -1.0}
	var t0 := _now()
	_player.hunt.start(c)
	while float(_swing_probe["hit_t"]) < 0.0 and _now() - t0 < 3.0:
		await get_tree().process_frame
	_player.hunt.stop()
	var swing_t := float(_swing_probe["swing_t"])
	var hit_t := float(_swing_probe["hit_t"])
	_swing_probe = {}
	var gap := hit_t - swing_t if hit_t > 0.0 and swing_t > 0.0 else -1.0
	_check(gap >= 0.25, "stone-knife damage lands %.3f s after the swing starts (want >= 0.25)" % gap)
	CombatTuning.reset_overrides()
	c.queue_free()
	await _secs(0.8)

## pc-feel-01: trauma after a heavy hit on the survivor, back to 0 within 1 s.
func _camera_phase() -> void:
	_reset_player(Vector3(0, 1, 0))
	await _frames(5)
	var c := _spawn(&"velociraptor", _player.global_position + Vector3(0, -0.9, -1.7))
	await _frames(5)
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	_player.vitals.health = 1000.0
	var landed := CreatureAttack.apply_for(c, &"attack_heavy", _player)
	var tr := _cam.trauma
	CombatTuning.reset_overrides()
	await _secs(1.0)
	_check(landed and tr > 0.0 and _cam.trauma == 0.0, "camera trauma %.2f right after a heavy hit, %.2f after 1.0 s" % [tr, _cam.trauma])
	c.queue_free()
	_reset_player(Vector3(0, 1, 0))
	await _secs(0.5)

## phys-kick-01: reach to the body edge; shove scaled by mass, refused for giants.
func _kick_phase() -> void:
	for row in [[&"compsognathus", true], [&"triceratops", false], [&"tyrannosaurus", false]]:
		var species: StringName = row[0]
		var light: bool = row[1]
		_reset_player(Vector3(0, 1, 0))
		await _frames(5)
		var def := Data.creature(species)
		var r := maxf(0.18, def.real_length_m * 0.12)
		var c := _spawn(species, Vector3(0, 0, -(r + 0.35 + 0.05)))  # bodies touching
		await _frames(10)
		_player.hunt.start(c)
		_player.hunt.auto = false
		_player.hunt.last_notice = ""
		var before := c.global_position
		_player.hunt.use_kick()
		await _frames(3)
		var moved := Vector2(c.global_position.x - before.x, c.global_position.z - before.z).length()
		var note := _player.hunt.last_notice
		if light:
			_check(moved >= 1.5, "kick %s moved %.2f m (want >= 1.5)" % [species, moved])
		else:
			_check(moved <= 0.3 and note.to_lower().contains("too heavy") and not note.contains("Too far"),
				"kick %s at contact moved %.2f m, notice '%s'" % [species, moved, note])
		_player.hunt.auto = true
		_player.hunt.stop()
		c.queue_free()
		await _secs(1.2)  # attack clip clears _busy before the next kick

## phys-hit-01: a BuildGrid fence ring between survivor and velociraptor for 10 s: no bite and
## no swing lands through it. Control: same set-up without the fence, >= 3 bites.
func _fence_phase() -> void:
	World.harvested.clear()
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	await _secs(1.0)
	var rt := World.runtime
	if rt == null:
		_check(false, "island runtime loaded")
		return
	var grid := rt.get("build_grid") as BuildGrid
	var origin: Variant = _ring_site(rt, grid)
	if origin == null:
		_check(false, "flat free 6x6 site for the fence ring")
		return
	var pieces := _place_ring(rt, grid, origin as Vector2i)
	await _frames(3)
	var bounds := _inner_bounds(pieces)
	var raptor := _spawn(&"velociraptor", BuildGrid.tile_centre((origin as Vector2i) + Vector2i(9, 3), rt) + Vector3(0, 0.3, 0), rt, true)
	var fenced := await _melee_bout(raptor, bounds, "fence")
	for p in pieces:
		p.queue_free()
	await _frames(3)
	var open := await _melee_bout(raptor, bounds, "control")
	_check(fenced["bites"] == 0 and fenced["hits"] == 0 and fenced["reach_tries"] >= 1,
		"fence ring 10 s: %d bites, %d survivor hits through the wall (%d bite tries at reach, %d swings started)" % [fenced["bites"], fenced["hits"], fenced["reach_tries"], fenced["swings"]])
	_check(open["bites"] >= 3, "control without fence 10 s: %d bites (want >= 3)" % open["bites"])
	raptor.queue_free()

## 10 s bout. Every 0.5 s the survivor stands at the inside point nearest the raptor, so the
## raptor is always as close as the wall allows.
func _melee_bout(raptor: Creature, bounds: Rect2, tag: String) -> Dictionary:
	var rt := World.runtime
	var out := {"bites": 0, "hits": 0, "reach_tries": 0, "swings": 0}
	# Wrap the raptor's own hit handler: arm the survivor's health just before it, read it
	# just after. A drop between the two is a landed bite (vitals clamp health every frame,
	# so a frame-to-frame comparison would miscount).
	var pre := func (_clip: StringName) -> void:
		_player.vitals.health = 1000.0
		var d := Vector2(raptor.global_position.x - _player.global_position.x, raptor.global_position.z - _player.global_position.z).length()
		if d <= raptor.brain.contact_reach() + 0.3:
			out["reach_tries"] += 1
	var post := func (_clip: StringName) -> void:
		if _player.vitals.health < 1000.0 - 0.01:
			out["bites"] += 1
			print("[combatrules] %s bite lands d=%.2f" % [tag, Vector2(raptor.global_position.x - _player.global_position.x, raptor.global_position.z - _player.global_position.z).length()])
	raptor.anim.attack_hit.disconnect(raptor._on_hit)
	raptor.anim.attack_hit.connect(pre)
	raptor.anim.attack_hit.connect(raptor._on_hit)
	raptor.anim.attack_hit.connect(post)
	_reset_player(_player.global_position)
	_player.hunt.start(raptor)
	raptor.brain.on_aggro(_player)
	var hp_r := raptor.health.max_hp
	var t := 0.0
	var next_place := 0.0
	var last_clip := &""
	while t < 10.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t >= next_place:
			next_place += 0.5
			var x := clampf(raptor.global_position.x, bounds.position.x, bounds.end.x)
			var z := clampf(raptor.global_position.z, bounds.position.y, bounds.end.y)
			_player.clear_nav()
			_player.global_position = Vector3(x, rt.surface_y(x, z) + 1.0, z)
			if _player.hunt.target == null:
				_player.hunt.start(raptor)
		if raptor.health.hp < hp_r - 0.01:
			out["hits"] += 1
		if _player.anim.current_clip == &"attack_primary" and last_clip != &"attack_primary":
			out["swings"] += 1
		last_clip = _player.anim.current_clip
		_player.dead = false
		_player.vitals.dead = false
		_player.vitals.health = 1000.0
		raptor.health.hp = raptor.health.max_hp
		hp_r = raptor.health.hp
	raptor.anim.attack_hit.disconnect(pre)
	raptor.anim.attack_hit.disconnect(post)
	_player.hunt.stop()
	print("[combatrules] %s bout: %s" % [tag, out])
	return out

func _ring_site(rt: Node, grid: BuildGrid) -> Variant:
	var harvest_tiles := {}
	for n in get_tree().get_nodes_in_group("harvest"):
		harvest_tiles[BuildGrid.tile_of((n as Node3D).global_position)] = true
	var used := grid.occupied_cells() + grid.reserved_cells()
	for r in range(0, 40):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var o := Vector2i(dx, 12 + dz)
				var ok := true
				for z in range(-3, 9):
					for x in range(-3, 14):
						var c := o + Vector2i(x, z)
						var at := BuildGrid.tile_centre(c, rt)
						if c in used or harvest_tiles.has(c) or not rt.spawn_ok(at, false) or rt._slope_deg(at.x, at.z) >= 12.0:
							ok = false
							break
					if not ok:
						break
				if ok:
					return o
	return null

## Closed 6x6 ring: top/bottom rows rot 0 (2x1 pieces), left/right columns rot 1 (1x2).
func _place_ring(rt: Node, grid: BuildGrid, origin: Vector2i) -> Array[Node3D]:
	var specs := []
	for i in 3:
		specs.append([origin + Vector2i(i * 2, 0), 0])
		specs.append([origin + Vector2i(i * 2, 5), 0])
	for j in 2:
		specs.append([origin + Vector2i(0, 1 + j * 2), 1])
		specs.append([origin + Vector2i(5, 1 + j * 2), 1])
	var out: Array[Node3D] = []
	for sp in specs:
		var b = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"fence")
		rt.add_child(b)
		b.global_transform = grid.placement_transform(&"fence", sp[0], sp[1])
		b.set_grid_pose(sp[0], sp[1])
		grid.occupy(b, grid.cells_for(&"fence", sp[0], sp[1]))
		b.set_meta("rot", sp[1])
		out.append(b)
	return out

## Where the survivor's centre may stand inside the ring (wall lines minus wall half-thickness
## and capsule radius).
func _inner_bounds(pieces: Array[Node3D]) -> Rect2:
	var xs: Array[float] = []
	var zs: Array[float] = []
	for p in pieces:
		if int(p.get_meta("rot")) == 1:
			xs.append(p.global_position.x)
		else:
			zs.append(p.global_position.z)
	var pad := 0.1 + 0.35 + 0.1
	var lo := Vector2(xs.min() + pad, zs.min() + pad)
	var hi := Vector2(xs.max() - pad, zs.max() - pad)
	print("[combatrules] ring inner x %.2f..%.2f z %.2f..%.2f" % [lo.x, hi.x, lo.y, hi.y])
	return Rect2(lo, hi - lo)
