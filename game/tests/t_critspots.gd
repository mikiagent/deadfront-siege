extends SceneTree
## WEAK SPOTS (owner: "since we have hitboxes now, I want you to add crit spots to every animal"). Checks:
## 1. every species in data/creatures has at least one crit spot (a modelled one its own data row; a stand-in the
##    fallback head), and every spot sits on the body: within its radius of a hurtbox (stand-ins: of the body);
## 2. every modelled species' spot bones exist on its skeleton, for each model it has (stag and doe, trike alpha);
## 3. a hitbox sweep through a spot (HX._sweep, the code every strike runs) carries the spot, and the swing
##    it lands (Hunt.land_hit) is a crit at that spot's multiplier; a stone through it too (StoneProjectile.impact);
## 4. a sweep that touches the body away from every spot carries none and does not crit with the chance crit at 0,
##    and crits at crit_mult (not the spot's) with the chance at 1;
## 5. the feedback fires: the WEAK SPOT float kind, the gold burst at the spot, the hit-stop, the spot glow
##    after the first one, and the H debug view draws the spots magenta.
## Usage: godot --headless --path game --script res://tests/t_critspots.gd -> "[t_critspots] PASS", exit 0.

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var player
var CS: GDScript  # CritSpots, CritSpotMarks, Hurtboxes, Hitbox, HitboxDebug: loaded once the autoloads exist
var CM: GDScript
var HB: GDScript
var HX: GDScript
var HD: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_critspots] %s %s" % ["ok  " if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	data = root.get_node("Data")
	CS = load("res://scripts/combat/crit_spots.gd")
	CM = load("res://scripts/combat/crit_spot_marks.gd")
	HB = load("res://scripts/combat/hurtboxes.gd")
	HX = load("res://scripts/combat/hitbox.gd")
	HD = load("res://scripts/combat/hitbox_debug.gd")
	root.get_node("Game").debug_overlay = false
	load("res://scripts/combat/combat_tuning.gd").force_dodge = 0.0
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	CreatureDef.allow_placeholder = true  # stand-ins spawn as their boxes
	host = Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(40, 0.9, 40)
	host.add_child(player)
	await _frames(3)
	var table: Dictionary = (HX.data().get("crit_spots", {}) as Dictionary).get("species", {})
	for id in data.creatures:
		var def = data.creature(StringName(id))
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/%s.json" % id))
		if not (raw is Dictionary and (raw as Dictionary).get("species") is String):
			continue  # hitboxes.json itself loads as a "creature" (its species table is a dictionary)
		var modelled: bool = CreatureDef.has_model(def.id)
		if modelled:
			_expect(table.has(str(def.id)), "%s: has its own crit_spots row" % def.id)
		for v in _models(def):
			await _check_model(def, v, modelled)
	await _check_rules()
	print("[t_critspots] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)

## The base model plus each variant with a model of its own.
func _models(def) -> Array:
	var out := [&""]
	var mv: Dictionary = def.pipeline.get("model_variants", {})
	for v in mv:
		if mv[v] is Dictionary and (mv[v] as Dictionary).has("model"):
			out.append(StringName(str(v)))
	return out

func _spawn(id: StringName, at: Vector3, variant: StringName = &""):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id), variant)
	c.health.setup(1e9)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _check_model(def, variant: StringName, modelled: bool) -> void:
	var c = _spawn(def.id, Vector3.ZERO, variant)
	await _frames(3)
	var tag: String = "%s%s" % [def.id, "/" + str(variant) if variant != &"" else ""]
	var rows: Array = CS.rows(c)
	var spots: Array = CS.world(c)
	_expect(spots.size() >= 1 and spots.size() <= 3, "%s: %d crit spots (%s)" % [tag, spots.size(), ", ".join(spots.map(func(s: Dictionary) -> String: return "%s x%.2f r%.2f" % [s["name"], s["mult"], s["radius"]]))])
	var hb = HB.of(c)
	if modelled and hb != null:
		var sk: Skeleton3D = HB.skeleton_of(c)
		for r in rows:
			_expect(sk.find_bone(str((r as Dictionary).get("bone", ""))) >= 0, "%s: spot %s bone %s is on the skeleton" % [tag, r.get("name"), r.get("bone")])
		for s in spots:
			var gap := INF
			for cap in hb.world_capsules():
				gap = minf(gap, Geometry3D.get_closest_point_to_segment(s["centre"], cap[0], cap[1]).distance_to(s["centre"]) - float(cap[2]))
			_expect(gap <= float(s["radius"]), "%s: spot %s sits on the body (%.2f m from a hurtbox, radius %.2f)" % [tag, s["name"], maxf(gap, 0.0), s["radius"]])
	else:
		for s in spots:
			var local: Vector3 = c.global_transform.affine_inverse() * (s["centre"] as Vector3)
			_expect(local.y > 0.0 and local.y <= def.height_meters * c.size_scale() * 1.01, "%s (no rig): fallback spot %s on the body at %s" % [tag, s["name"], local])
	c.queue_free()
	await _frames(1)

## Damage one swing deals and the float kind it shows, with the chance crit at `chance`.
func _swing(c, spot: Dictionary, chance: float) -> Array:
	var tune: Dictionary = load("res://scripts/combat/combat_tuning.gd").section("player_melee")
	var keep := [tune.get("crit_base"), tune.get("crit_behind"), tune.get("crit_per_melee_level")]
	tune["crit_base"] = chance
	tune["crit_behind"] = 0.0
	tune["crit_per_melee_level"] = 0.0
	var seen := [&""]
	var cb := func(_a: float, kind: StringName) -> void: seen[0] = kind
	c.combat_float.connect(cb)
	c.statuses.clear_all()  # the last swing's groggy would change its defence
	var hp0: float = c.health.hp
	player.hunt.land_hit(c, null, spot)
	c.combat_float.disconnect(cb)
	tune["crit_base"] = keep[0]
	tune["crit_behind"] = keep[1]
	tune["crit_per_melee_level"] = keep[2]
	return [hp0 - c.health.hp, seen[0]]

## A one-sample sweep of a part of radius r from a to b, through the shared sweep code.
func _sweep(c, a: Vector3, b: Vector3, r: float) -> Dictionary:
	var hurt = HB.of(c)
	hurt.sync(true)
	return HX._sweep([[[a, b, r]]], Transform3D.IDENTITY, hurt, false)

func _check_rules() -> void:
	var melee_tune: Dictionary = load("res://scripts/combat/combat_tuning.gd").section("player_melee")
	for id in [&"velociraptor", &"ankylosaurus", &"tyrannosaurus", &"woolly_rhino"]:
		var c = _spawn(id, Vector3(0, 0, -30))
		await _frames(3)
		player.global_position = c.global_position + Vector3(0, 0.9, 3.0)
		await _frames(1)
		for s in CS.world(c):
			var at: Vector3 = s["centre"]
			var hit := _sweep(c, at + Vector3(0.05, 0, 0), at - Vector3(0.05, 0, 0), float(s["radius"]))
			var spot: Dictionary = hit.get("spot", {})
			_expect(not hit.is_empty() and spot.get("name") == s["name"], "%s: a sweep through the %s touches %s and carries the spot (%s)" % [id, s["name"], hit.get("part", "-"), spot.get("name", "none")])
			var plain := _swing(c, {}, 0.0)
			var crit := _swing(c, spot, 0.0)
			_expect(crit[1] == CS.KIND and is_equal_approx(crit[0], plain[0] * float(s["mult"])), "%s %s: a sure crit at x%.2f (%.2f -> %.2f, %s)" % [id, s["name"], s["mult"], plain[0], crit[0], crit[1]])
		# Away from every spot: the tail tip, or the hurtbox farthest from all of them.
		var far := _farthest_cap(c)
		var miss := _sweep(c, far[0], far[1], 0.05)
		_expect(not miss.is_empty() and (miss.get("spot", {}) as Dictionary).is_empty(), "%s: a hit on its %s carries no spot" % [id, miss.get("part", "-")])
		var none := _swing(c, miss.get("spot", {}), 0.0)
		_expect(none[1] != CS.KIND and none[1] != &"crit", "%s: outside a spot, chance 0: no crit (%s)" % [id, none[1]])
		var lucky := _swing(c, miss.get("spot", {}), 1.0)
		_expect(lucky[1] == &"crit" and is_equal_approx(lucky[0], none[0] * float(melee_tune.get("crit_mult", 1.75))), "%s: outside a spot, chance 1: the chance crit at x%.2f (%.2f)" % [id, melee_tune.get("crit_mult", 1.75), lucky[0]])
		c.queue_free()
		await _frames(1)
	await _check_ranged()
	await _check_feedback()

## The hurtbox capsule farthest from every spot, shrunk to its axis.
func _farthest_cap(c) -> Array:
	var spots: Array = CS.world(c)
	var best := []
	var best_d := -INF
	for cap in HB.of(c).world_capsules():
		var d := INF
		for s in spots:
			d = minf(d, Geometry3D.get_closest_point_to_segment(s["centre"], cap[0], cap[1]).distance_to(s["centre"]) - float(s["radius"]))
		if d > best_d:
			best_d = d
			best = [cap[0], cap[1]]
	return best

func _check_ranged() -> void:
	var c = _spawn(&"woolly_rhino", Vector3(0, 0, -30))
	await _frames(3)
	var s: Dictionary = CS.world(c)[0]
	var at: Vector3 = s["centre"]
	var spot: Dictionary = CS.on_path(c, at + Vector3(-3, 0, 0), at + Vector3(3, 0, 0), 0.08)
	_expect(spot.get("name") == s["name"], "a stone's flight through the %s finds it" % s["name"])
	_expect(CS.on_path(c, at + Vector3(-3, 6, 0), at + Vector3(3, 6, 0), 0.08).is_empty(), "a stone's flight 6 m over it finds none")
	var shot = (load("res://scripts/combat/stone_projectile.gd") as GDScript).new()
	shot.source = player
	shot.damage = 20.0
	var hp0: float = c.health.hp
	shot.impact(c)
	var plain: float = hp0 - c.health.hp
	hp0 = c.health.hp
	shot.impact(c, spot)
	_expect(is_equal_approx(hp0 - c.health.hp, plain * float(s["mult"])), "a stone in the %s hits x%.2f (%.2f -> %.2f)" % [s["name"], s["mult"], plain, hp0 - c.health.hp])
	shot.free()
	c.queue_free()
	await _frames(1)

func _check_feedback() -> void:
	var c = _spawn(&"velociraptor", Vector3(0, 0, -30))
	await _frames(3)
	var s: Dictionary = CS.world(c)[0]
	_expect(c.get_node_or_null(NodePath(CM.NAME)) == null, "no spot glow before the first weak-spot hit")
	var bursts_before: int = c.find_children("*", "GPUParticles3D", false, false).size()
	var hit := _swing(c, s, 0.0)
	_expect(hit[1] == CS.KIND, "the damage float reads WEAK SPOT (kind %s)" % hit[1])
	var burst_at := INF
	for p in c.find_children("*", "GPUParticles3D", false, false):
		burst_at = minf(burst_at, (p as Node3D).global_position.distance_to(s["centre"]))
	_expect(c.find_children("*", "GPUParticles3D", false, false).size() > bursts_before and burst_at < 0.01, "a burst on the spot itself (%.3f m)" % burst_at)
	_expect(is_zero_approx(float(c.anim._time_factors.get(&"hit_stop", 1.0))), "hit-stop: the animal's animation holds")
	_expect(c.view._hit_flash_left > 0.0 and c.view._flash_col == CS.BURST, "a gold hit flash")
	await create_timer(CS.HIT_STOP_S + 0.1).timeout
	_expect(is_equal_approx(float(c.anim._time_factors.get(&"hit_stop", 1.0)), 1.0), "the hit-stop lets go after %.2f s" % CS.HIT_STOP_S)
	var marks = c.get_node_or_null(NodePath(CM.NAME))
	await process_frame
	await process_frame
	_expect(marks == null, "no spot glow in normal play, even after a weak-spot hit (debug only)")
	HX.debug_draw = true
	await process_frame
	await process_frame
	var dbg := root.get_node_or_null("HitboxDebug") as MeshInstance3D
	var magenta := false
	if dbg and (dbg.mesh as ImmediateMesh).get_surface_count() > 0:
		var cols: PackedColorArray = (dbg.mesh as ImmediateMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		magenta = cols.has(HD.SPOT)
	_expect(magenta, "the H debug view draws crit spots in their own colour")
	HX.debug_draw = false
	c.queue_free()
	await _frames(1)
