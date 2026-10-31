extends SceneTree
## HITBOXES (owner: "We should have hitboxes and it should correlate with whatever is used to attack and
## whatever is hitable on the body"). Checks, for every modelled species and the survivor:
## 1. hurtboxes cover the visible mesh: skinned vertices in the live pose are inside some hurtbox;
## 2. each move's hitbox rides its bone: the baked sweep matches the bone the clip moves, sample by sample,
##    and covers only the move's window (a target where the part is outside the window is not hit);
## 3. a survivor where the part passes is hit once (a real clip, the real hit frame); one beside the
##    animal, where the part never passes, is not;
## 4. a fast part cannot tunnel: a thin target between two sweep samples is hit, though neither sample touches it;
## 5. nothing loses hits: every brain move connects with a survivor at the brain's contact reach (behind it for
##    kicks and the tail whip), and the survivor's auto-attack walks up to every species and lands;
## 6. the hit location reaches damage (vitals / health last_hit_part), the debug draw draws, and 20 creatures'
##    hitbox checks stay under PERF_STRIKE_MS each.
## Usage: godot --headless --path game --script res://tests/t_hitboxes.gd -> "[t_hitboxes] PASS", exit 0.
## With -- --calibrate it prints, per species and move, the part radius a survivor at contact reach needs
## (data/creatures/hitboxes.json "calibrated" radii come from it) and quits.

const COVER_MIN := 0.85  ## share of sampled skinned vertices inside a hurtbox
const BONE_TOL_M := 0.05  ## the player's seek and the bake's track sampling interpolate a hair apart
const PERF_STRIKE_MS := 3.0  ## one strike (sync + sweep) against a survivor; a MegaRex sweep with its widened parts, on a busy machine, ran 1.7 ms
const PERF_TOTAL_MS := 12.0  ## 20 creatures striking once each
const APPROACH_S := 8.0
## Calibrated radii reach this much past the closest pass: the idle sway of both bodies differs run to run.
const CALIB_MARGIN_M := 0.2
const SURVIVOR_MOVES := [[&"punch", &""], [&"swing", &"slashing"], [&"heavy", &"blunt"], [&"kick", &""], [&"tackle", &""]]

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var player
var HB: GDScript
var HX: GDScript
var MQ: GDScript
var calibrate := false
var _calib := []

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_hitboxes] %s %s" % ["ok  " if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	calibrate = "--calibrate" in OS.get_cmdline_user_args()
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	HB = load("res://scripts/combat/hurtboxes.gd")
	HX = load("res://scripts/combat/hitbox.gd")
	MQ = load("res://scripts/combat/melee_query.gd")
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
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
	root.get_node("Game").god_mode = true  # hits land (flinch, signals) but she never dies
	var species: Array[StringName] = []
	var PANEL = load("res://scripts/dev/lab_spawn_panel.gd")
	for id in PANEL.all_species():
		if CreatureDef.has_model(id):
			# A species with its own model per variant (megaloceros stag / doe) is checked once per model.
			var mv: Dictionary = data.creature(id).pipeline.get("model_variants", {})
			var own := []
			for v in mv:
				if mv[v] is Dictionary and (mv[v] as Dictionary).has("model"):
					own.append(v)
			if own.is_empty():
				species.append(id)  # colour morphs share one model
			else:
				for v in mv:
					species.append(StringName("%s/%s" % [id, v]))
	if calibrate:
		var only := Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return a.begins_with("--species="))
		if not only.is_empty():  # -- --calibrate --species=carnotaurus: one species only
			species = species.filter(func(id: StringName) -> bool: return str(id).get_slice("/", 0) == (only[0] as String).trim_prefix("--species="))
		for id in species:
			await _calibrate_species(id)
		print("[t_hitboxes] CALIBRATE %s" % JSON.stringify(_calib))
		quit(0)
		return
	_test_survivor_cover()
	for id in species:
		await _test_species(id)
	await _test_clip_hit_once()
	await _test_tunnel()
	await _test_survivor_moves()
	for id in species:
		await _approach(id)
	await _test_perf(species)
	_test_debug_draw()
	root.get_node("Game").god_mode = false
	print("[t_hitboxes] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)

## id is a species, or "species/variant" for one of its models.
func _spawn(id: StringName, at: Vector3, brain_on: bool = false, size: float = 0.0):
	var variant := StringName(str(id).get_slice("/", 1)) if str(id).contains("/") else &""
	id = StringName(str(id).get_slice("/", 0))
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	if size > 0.0:
		c.genetics = load("res://scripts/creatures/creature_genetics.gd").new()
		c.genetics.size = size
	c.spawn(data.creature(id), variant)
	c.health.setup(1e9)
	if not brain_on:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

## Share of the body's skinned vertices (live pose) inside one of its hurtboxes.
func _cover(body) -> float:
	var hb = HB.of(body)
	var sk: Skeleton3D = HB.skeleton_of(body)
	var smp: Array = HB.rest_samples(sk, 3000)
	var pts: PackedVector3Array = smp[0]
	var bones: PackedInt32Array = smp[1]
	var caps: Array = hb.world_capsules()
	var inside := 0
	for i in pts.size():
		var b := bones[i]
		var w: Vector3 = sk.global_transform * (sk.get_bone_global_pose(b) * (sk.get_bone_global_rest(b).affine_inverse() * pts[i]))
		for cap in caps:
			if Geometry3D.get_closest_point_to_segment(w, cap[0], cap[1]).distance_to(w) <= float(cap[2]):
				inside += 1
				break
	return float(inside) / maxf(1.0, float(pts.size()))

func _test_survivor_cover() -> void:
	var hb = HB.of(player)
	_expect(hb != null and hb.caps.size() >= 8, "survivor has hurtboxes (%d)" % (hb.caps.size() if hb else 0))
	_expect(hb.collision_layer == HB.LAYER and hb.collision_mask == 0, "hurtboxes sit on their own layer and collide with nothing")
	var share := _cover(player)
	_expect(share >= COVER_MIN, "survivor: %.0f %% of the skinned mesh inside a hurtbox" % (share * 100.0))

## The brain moves a species plays at a survivor, each [move, hit_index, behind, distances]: its contact
## reach (centre to centre), and for the pounce also where the leap lands (TacticalBrain: body radius + 0.2).
func _moves_of(c) -> Array:
	var out := []
	var id: StringName = c.def.id
	var ap: AnimationPlayer = c.view.rig.anim_player
	var reach: float = c.brain.contact_reach()
	var tac: Dictionary = c.brain.get(&"tac") if c.brain.get(&"tac") is Dictionary else {}
	# A TyrantBrain swings at anything inside its reach, so its timed moves must also land well inside it.
	var tyrant: bool = c.brain.get_script().get_global_name() in [&"TyrantBrain", &"MegaRexBrain"]
	# Any brain bites prey that walked inside its reach too: a little closer for most, well inside for a tyrant.
	var near: Array = [reach * 0.6, reach] if tyrant else [reach * 0.85, reach]
	var club_tail: bool = c.brain.get_script().get_global_name() == &"ClubTailBrain"
	out.append([&"attack_primary", 0, false, near])
	# tactics.heavy_reach_m: an in-place kick fires only that close (the gallimimus rake).
	out.append([&"attack_heavy", 0, false, [minf(reach, float(tac.get("heavy_reach_m", 1e9)))]])
	if ap.has_animation(&"bite_combo"):
		for i in 3:
			out.append([&"bite_combo", i, false, near])
	# TacticalBrain moves from the species' resolved tactics (ClubTailBrain's ankylosaurus is t_ankyloai's).
	var steps := {}
	for sq in tac.get("sequences", []):
		for st in (sq as Dictionary).get("steps", []):
			steps[str(st)] = true
	if steps.has("pounce"):
		var land: float = c.brain._land_short()  # TacticalBrain lands the leap this far short of her centre
		out.append([&"pounce", 0, false, [land, (land + reach) * 0.5, reach]])
	if steps.has("charge") and tac.get("charge_straight", false):
		out.append([&"charge", 0, false, [reach]])
	if tac.get("pin", false) and ap.has_animation(&"pin_stab"):
		for i in 2:  # the sabres stab twice into prey held pin_reach_m in front (TacticalBrain._pin)
			out.append([&"pin_stab", i, false, [float(tac.get("pin_reach_m", 1.5)) * c.size_scale()]])
	if ap.has_animation(&"kick") and (steps.has("kick") or tac.get("charge_straight", false)):
		out.append([&"kick", 0, true, [reach]])  # the hind kick at prey behind it (after a charge, or point blank)
	# ALLOFEEL: tactics.moves rows (the allosaurus' arm rake, hatchet slash, shoulder-checks). A front move at the middle and
	# the far end of its min_m..max_m; a side move with her beside its flank, 60 and 90 deg off its facing, at 0.8 max_m.
	var mvs: Variant = tac.get("moves")
	if mvs is Dictionary:
		var sz: float = c.size_scale()
		for k in mvs:
			var r: Variant = mvs[k]
			if not (r is Dictionary):
				continue
			var lo := float(r.get("min_m", 0.0)) * sz
			var hi := float(r.get("max_m", reach)) * sz
			if str(r.get("arc", "front")) == "side":
				for sd in [["clip_right", 1.0], ["clip_left", -1.0]]:
					var clip := StringName(str(r.get(sd[0], "")))
					if ap.has_animation(clip):
						var at := []
						for deg in [60.0, 90.0]:
							at.append(Vector3(float(sd[1]) * sin(deg_to_rad(deg)), 0.0, -cos(deg_to_rad(deg))) * hi * 0.8)
						out.append([clip, 0, false, at])
			elif ap.has_animation(StringName(str(r.get("clip", "")))):
				out.append([StringName(str(r["clip"])), 0, false, [(lo + hi) * 0.5, hi]])
	if club_tail:
		out.clear()  # its club moves sweep the club live (t_ankyloai); only the close moves are clip strikes
	# ClubTailBrain's close moves (ANKYLOCLOSE): judged with her on each move's aim spot.
	var close: Dictionary = c.brain.get(&"close_moves") if c.brain.get(&"close_moves") is Dictionary else {}
	for move_id in close:
		var row: Dictionary = close[move_id]
		if row.has("lunge_m") or row.has("carry_m") or row.has("turn_deg") or row.has("line_bone") or not ap.has_animation(StringName(str(row.get("clip", "")))):
			continue  # the tackle's leap and the slam's throw are swept live (ClubTailBrain._tick_leap); a turn has no hit; a line_bone move (STEGOSPIN spin) by its body line
		var spot: Vector3 = c.brain.strike_spot(StringName(str(move_id))) - c.global_position
		out.append([StringName(str(row["clip"])), 0, false, [Vector3(spot.x, 0.0, spot.z)]])
	if club_tail:
		return out
	if tac.get("charge_impale", false) and ap.has_animation(&"impale"):
		# STYRAFIX: the impale's hit frame comes when she stands impale_reach_m ahead on the charge line.
		out.append([&"impale", 0, false, [float(tac.get("impale_reach_m", reach)) * c.size_scale()]])
	if ap.has_animation(&"bite_shake"):
		out.append([&"bite_shake", 0, false, near])  # MegaRexBrain's grab
	if ap.has_animation(&"tail_swipe"):
		out.append([&"tail_swipe", 0, true, [reach]])
	return out

func _test_species(id: StringName) -> void:
	var c = _spawn(id, Vector3.ZERO)
	await _frames(3)
	var hb = HB.of(c)
	_expect(hb != null and hb.caps.size() >= 6, "%s has hurtboxes (%d)" % [id, hb.caps.size() if hb else 0])
	var regions := {}
	for cap in hb.caps:
		regions[cap["region"]] = true
	_expect(regions.has(&"head") or regions.has(&"neck"), "%s: a head or neck hurtbox (%s)" % [id, regions.keys()])
	_expect(regions.has(&"leg"), "%s: leg hurtboxes" % id)
	var share := _cover(c)
	_expect(share >= COVER_MIN, "%s: %.0f %% of the skinned mesh inside a hurtbox" % [id, share * 100.0])
	_bone_track_check(c)
	if true:  # the ankylosaurus's club moves are t_ankyloai's; its close moves are listed by _moves_of
		var reach: float = c.brain.contact_reach()
		for row in _moves_of(c):
			var mv: StringName = row[0]
			var side: float = 1.0 if row[2] else -1.0
			for dist in row[3]:
				_place_survivor(dist if dist is Vector3 else Vector3(0, 0, side * float(dist)), c)
				await _pose_for(mv, c)
				var hit: Dictionary = HX.strike(c, mv, player, int(row[1]))
				if hit.is_empty() and OS.has_environment("HB_DEBUG"):
					var dbg := {}
					_calib_need(c, HB.skeleton_of(c), row, c.size_scale(), dbg)
					print("[hbdebug] %s %s size %.3f need %s spec %s pos %s anim %s pclip %s" % [id, mv, c.size_scale(), dbg, HX.move_spec(c, mv, int(row[1])), player.global_position, c.anim.current_clip, player.anim.current_clip])
				await _unpose(mv)
				_expect(not hit.is_empty(), "%s %s[%d]: connects with a survivor %s at %s m (contact reach %.2f) (%s)" % [id, mv, row[1], "behind it" if row[2] else "in front", str(dist) if dist is Vector3 else "%.2f" % dist, reach, hit.get("part", "-")])
			if not row[2] and mv != &"charge" and not (row[3][0] is Vector3):
				_place_survivor(Vector3(reach + 0.3, 0, 1.0), c)
				await _frames(1)
				_expect(HX.strike(c, mv, player, int(row[1])).is_empty(), "%s %s[%d]: misses a survivor beside its hips" % [id, mv, row[1]])
	c.queue_free()
	await _frames(1)

## A pin_stab lands on prey lying Pinned in front of it: lay her down as PinHold does and let the pose settle.
func _pose_for(mv: StringName, c) -> void:
	if mv != &"pin_stab":
		await _frames(1)
		return
	player.statuses.apply(&"pinned", c, 1)
	player.face_world(player.global_position + c.global_basis.z)
	await _frames(60)

func _unpose(mv: StringName) -> void:
	if mv != &"pin_stab":
		return
	player.statuses.clear_all()
	for _f in 180:  # she gets back up before the next check stands her in front of something
		await physics_frame
		if player.anim.current_clip in [&"idle", &"walk", &"run"]:
			break
	await _frames(10)

func _place_survivor(at: Vector3, face) -> void:
	player.global_position = Vector3(at.x, 0.9, at.z)
	player.velocity = Vector3.ZERO
	if face:
		player.face_world(face.global_position)

## The baked sweep of attack_primary's first part is that bone, sample by sample, in the move's window only.
func _bone_track_check(c) -> void:
	var mv := &"attack_primary"
	var spec: Dictionary = HX.move_spec(c, mv)
	var part: Dictionary = (spec["parts"] as Array)[0]
	var sk: Skeleton3D = HB.skeleton_of(c)
	var bone := sk.find_bone(str(part["bone"]))
	var smp: Array = HX.baked(c, mv)
	var ap: AnimationPlayer = c.view.rig.anim_player
	var anim := ap.get_animation(spec["clip"])
	c.anim.tree.active = false  # the AnimationPlayer drives the pose while it is seeked
	var w: Vector2 = spec["window"]
	var worst := 0.0
	ap.play(spec["clip"])
	for k in smp.size():
		var t := lerpf(anim.length * w.x, anim.length * w.y, float(k) / float(smp.size() - 1))
		ap.seek(t, true)
		var live := (sk.global_transform * sk.get_bone_global_pose(bone)).origin
		worst = maxf(worst, live.distance_to(sk.global_transform * (smp[k][0][0] as Vector3)))
	_expect(bone >= 0 and worst <= BONE_TOL_M, "%s %s: the hitbox rides %s through the clip (worst %.3f m off the live bone)" % [c.def.id, mv, part["bone"], worst])
	_expect(w.y > w.x and absf(w.y - load("res://scripts/creatures/creature_clips.gd")._hit_frac(mv)) < 0.001, "%s %s: window %.2f-%.2f of the clip, closing on its hit frame" % [c.def.id, mv, w.x, w.y])
	# Outside the window: where the part is at the clip's first frame, unless the window passes there too.
	ap.seek(0.0, true)
	var start := (sk.global_transform * sk.get_bone_global_pose(bone)).origin
	var r: float = smp[0][0][2]
	var clear := true
	for row in smp:
		if (sk.global_transform * (row[0][0] as Vector3)).distance_to(start) < r + 0.15:
			clear = false
	if clear:
		var fake = _fake_target(start, 0.1)
		var first_part := []
		for row in smp:
			first_part.append([row[0]])
		_expect(HX._sweep(first_part, sk.global_transform, fake, false).is_empty(), "%s %s: a target where the part is before the window is not hit" % [c.def.id, mv])
		fake.free()
	c.anim.tree.active = true
	ap.stop()

## A Hurtboxes with one small sphere at `at` (never in the tree): what a sweep tests against.
func _fake_target(at: Vector3, r: float):
	var fake = HB.new()
	fake.caps.assign([{"bone": 0, "part": &"probe", "region": &"body", "wa": at, "wb": at, "wr": r}])
	return fake

## A real raptor bite: the survivor where the jaws pass is hit exactly once; beside the raptor, never.
func _test_clip_hit_once() -> void:
	var c = _spawn(&"velociraptor", Vector3(10, 0, 0))
	await _frames(3)
	c.brain.attack_target = player
	var reach: float = c.brain.contact_reach()
	for case in [["in its jaws", Vector3(10, 0, -reach + 0.2), 1], ["beside it", Vector3(10 + reach, 0, 0.6), 0]]:
		_place_survivor(case[1], c)
		player.vitals.last_hit_part = &""
		var hits := [0]
		var cb := func() -> void: hits[0] += 1
		player.vitals.damaged.connect(cb)
		c.anim.play_clip(&"attack_primary")
		await _frames(90)
		player.vitals.damaged.disconnect(cb)
		_expect(hits[0] == case[2], "velociraptor attack_primary: a survivor %s is hit %d time(s) (%d)" % [case[0], case[2], hits[0]])
		if case[2] == 1:
			_expect(player.vitals.last_hit_part != &"", "the hit location reaches her vitals (%s)" % player.vitals.last_hit_part)
	c.queue_free()
	await _frames(1)

## Two samples far apart along a fast part's path: a thin target between them is hit only by the sweep.
func _test_tunnel() -> void:
	var c = _spawn(&"tyrannosaurus", Vector3(-20, 0, 0))
	await _frames(3)
	var sk: Skeleton3D = HB.skeleton_of(c)
	var smp: Array = HX.baked(c, &"tail_swipe")
	var best := 0.0
	var pair := [0, 1]
	for k in range(1, smp.size()):
		var d := (smp[k][0][0] as Vector3).distance_to(smp[0][0][0])
		if d > best:
			best = d
			pair = [0, k]
	var a: Vector3 = sk.global_transform * (smp[pair[0]][0][0] as Vector3)
	var b: Vector3 = sk.global_transform * (smp[pair[1]][0][0] as Vector3)
	var r: float = smp[0][0][2]
	var coarse := [smp[pair[0]], smp[pair[1]]]
	var fake = _fake_target((a + b) * 0.5, 0.05)
	var gap := a.distance_to(b) * 0.5 - r - 0.05
	_expect(gap > 0.0, "tail whip: two samples %.1f m apart, the midpoint %.2f m clear of both" % [a.distance_to(b), gap])
	_expect(not HX._sweep(coarse, sk.global_transform, fake, false).is_empty(), "a thin target between them is hit by the sweep")
	_expect(HX._sweep([smp[pair[0]]], sk.global_transform, fake, false).is_empty() and HX._sweep([smp[pair[1]]], sk.global_transform, fake, false).is_empty(), "neither sample alone touches it (it would have tunnelled)")
	fake.free()
	c.queue_free()
	await _frames(1)

## The survivor's moves ride her bones: the fist / blade / foot / chest sweep their clips' windows.
func _test_survivor_moves() -> void:
	var sk: Skeleton3D = HB.skeleton_of(player)
	for mw in SURVIVOR_MOVES:
		var smp: Array = HX.baked(player, mw[0], 0, mw[1])
		var spec: Dictionary = HX.move_spec(player, mw[0], 0, mw[1])
		_expect(smp.size() >= 2 and not (smp[0] as Array).is_empty(), "survivor %s%s: %d samples over %s" % [mw[0], "/" + str(mw[1]) if mw[1] != &"" else "", smp.size(), spec["window"]])
	# A creature in front at arm's length is hit by the swing; one behind her is not.
	var c = _spawn(&"zebraceratops", Vector3(-10, 0, 0))
	await _frames(3)
	c.look_at(Vector3(-10, 0, 10), Vector3.UP)
	_place_survivor(Vector3(-10, 0, -1.6), c)
	await _frames(1)
	var front: Dictionary = HX.strike(player, &"swing", c, 0, &"slashing")
	_expect(not front.is_empty(), "survivor swing: hits a zebraceratops in front of her (%s)" % front.get("part", "-"))
	_place_survivor(Vector3(-10, 0, -2.4), null)
	player.face_world(player.global_position + Vector3(0, 0, -5))  # turned away, out of her backswing
	await _frames(1)
	_expect(HX.strike(player, &"swing", c, 0, &"slashing").is_empty(), "survivor swing: misses it when she faces away")
	player.face_world(c.global_position)
	_expect(not HX.strike(player, &"swing", c, 0, &"slashing").is_empty(), "survivor swing: the same spot facing it hits")
	# Damage carries the hurtbox: a real swing through Hunt.
	_place_survivor(Vector3(-10, 0, -1.6), c)
	var h = player.hunt
	h.start(c)
	h.auto = false
	h._swing_cd = 0.0
	h._swing_pending = false
	c.health.last_hit_part = &""
	var started: bool = h.swing_now()
	await create_timer(h.hit_delay(null) + 0.15).timeout
	_expect(started and c.health.last_hit_part != &"", "a landed swing hands its hurtbox to the creature's health (%s)" % c.health.last_hit_part)
	h.stop()
	h.auto = true
	c.queue_free()
	await _frames(1)

## Auto-attack from 6 m off its flank: she walks to a part she can reach and lands a swing.
func _approach(id: StringName) -> void:
	var c = _spawn(id, Vector3(0, 0, -30))
	await _frames(3)
	var h = player.hunt
	_place_survivor(c.global_position + Vector3(6.0 + MQ.body_radius(c), 0, 0), null)
	await _frames(2)
	h.auto = true
	h.auto_ability = false
	h.hold = false
	var landed := [0]
	var cb := func(_t) -> void: landed[0] += 1
	h.hit_landed.connect(cb)
	h.start(c)
	var t := 0.0
	while t < APPROACH_S and landed[0] < 1:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	h.hit_landed.disconnect(cb)
	_expect(landed[0] >= 1, "%s: her auto-attack walks up from its flank and lands (%.1f s)" % [id, t])
	h.stop()
	h.auto_ability = true
	c.queue_free()
	await _frames(2)

## 20 creatures round her, each judging attack_primary against her once (bakes warmed first).
func _test_perf(species: Array[StringName]) -> void:
	_place_survivor(Vector3(0, 0, 60), null)
	var cs := []
	for i in 20:
		var a := TAU * float(i) / 20.0
		var c = _spawn(species[i % species.size()], Vector3(sin(a) * 6.0, 0, 60 + cos(a) * 6.0))
		cs.append(c)
	await _frames(3)
	for c in cs:
		HX.strike(c, &"attack_primary", player)  # warm: hurtbox fit, bake
	await _frames(1)
	var worst := 0
	var t0 := Time.get_ticks_usec()
	for c in cs:
		var s := Time.get_ticks_usec()
		HX.strike(c, &"attack_primary", player)
		worst = maxi(worst, Time.get_ticks_usec() - s)
	var total := Time.get_ticks_usec() - t0
	_expect(float(worst) / 1000.0 <= PERF_STRIKE_MS and float(total) / 1000.0 <= PERF_TOTAL_MS,
		"perf: 20 creatures' hitbox checks %.2f ms in all, worst %.3f ms (gates %.0f / %.1f ms)" % [total / 1000.0, worst / 1000.0, PERF_TOTAL_MS, PERF_STRIKE_MS])
	var s2 := Time.get_ticks_usec()
	for c in cs:
		HB.of(c).sync(true)
	_expect((Time.get_ticks_usec() - s2) / 1000.0 <= PERF_TOTAL_MS, "perf: syncing 20 creatures' hurtboxes %.2f ms" % ((Time.get_ticks_usec() - s2) / 1000.0))
	for c in cs:
		c.queue_free()
	await _frames(1)

func _test_debug_draw() -> void:
	HX.debug_draw = true
	var c = _spawn(&"velociraptor", Vector3(30, 0, 0))
	_place_survivor(Vector3(30, 0, -1.5), c)
	HX.strike(c, &"attack_primary", player)
	_expect(not HX.recent.is_empty(), "debug draw: the swing's sweep is queued red")
	var dbg = root.get_node_or_null("HitboxDebug")
	await process_frame
	await process_frame
	dbg = root.get_node_or_null("HitboxDebug")
	_expect(dbg != null and (dbg.mesh as ImmediateMesh).get_surface_count() > 0, "debug draw: hurtboxes and hitboxes drawn")
	HX.debug_draw = false
	c.queue_free()

## The radius each move's parts need to reach a survivor at contact reach (front; behind for kick / tail), at
## both ends of the species' size range, in metres at size 1.0 (data radii scale with the body).
func _calibrate_species(id: StringName) -> void:
	var done := {}
	var range_: Vector2 = load("res://scripts/creatures/creature_genetics.gd").size_range_for(data.creature(StringName(str(id).get_slice("/", 0))))
	for size in [range_.x, (range_.x + range_.y) * 0.5, range_.y, 0.0]:  # 0: the size this test's own spawn rolls
		var c = _spawn(id, Vector3.ZERO, false, size)
		size = c.size_scale()
		_bone_track_check(c)  # the same state the checks run in (the seeked AnimationPlayer, then the tree again)
		await _frames(3)
		var sk: Skeleton3D = HB.skeleton_of(c)
		for row in _moves_of(c):
			for dist in row[3]:
				_place_survivor(dist if dist is Vector3 else Vector3(0, 0, (1.0 if row[2] else -1.0) * float(dist)), c)
				await _pose_for(row[0], c)
				_calib_need(c, sk, row, size, done)
				await _unpose(row[0])
		c.queue_free()
		await _frames(1)
	for key in done:
		_calib.append([str(id), "%s|%.2f" % [key, done[key][1]], snappedf(float(done[key][0]), 0.01)])

## Each part's closest pass to the survivor where she stands now, into done ("move|bone|radius" -> need, at size 1).
func _calib_need(c, sk: Skeleton3D, row: Array, size: float, done: Dictionary) -> void:
	var caps: Array = HB.of(player).world_capsules()
	var smp: Array = HX.baked(c, row[0], row[1])
	var spec: Dictionary = HX.move_spec(c, row[0], row[1])
	for pi in (smp[0] as Array).size():
		var need := INF
		for k in smp.size():
			var a: Vector3 = sk.global_transform * (smp[k][pi][0] as Vector3)
			var pa: Vector3 = sk.global_transform * (smp[maxi(0, k - 1)][pi][0] as Vector3)
			for cap in caps:
				var pts := Geometry3D.get_closest_points_between_segments(pa, a, cap[0], cap[1])
				need = minf(need, pts[0].distance_to(pts[1]) - float(cap[2]))
		var key := "%s|%s" % [row[0], spec["parts"][pi]["bone"]]
		var was: Array = done.get(key, [-INF, 0.0])
		done[key] = [maxf(float(was[0]), (need + CALIB_MARGIN_M) / size), maxf(float(was[1]), float(smp[0][pi][2]) / size)]
