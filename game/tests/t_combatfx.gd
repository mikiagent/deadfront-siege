extends SceneTree
## COMBATFX (spec 24, owner correction 2026-10-21): every hit shows a small number at the struck
## creature or the survivor. It pops in, then expands while it fades out and floats up. Sizes climb
## normal < big hit < crit; white is damage dealt, gold your crit, red damage taken (survivor or pet),
## green a heal, grey a dodge. Melee, ranged and creature-on-survivor hits all reach it; quick hits
## never overlap; numbers stay whole on screen, move smoothly and clean up. The old code has no
## CombatFx and no crit or big-hit sizing, so this fails there.
## Usage: godot --headless --path game --script res://tests/t_combatfx.gd

const DT := 1.0 / 60.0

var failures: Array[String] = []
var _started := false
var host: Node3D
var cam: Camera3D
## Loaded at run time and used untyped (the t_combat pattern): `--script` compiles this file before
## the autoloads exist, and the old code has no CombatFx, so the test fails cleanly there.
var player
var plates
var fx
var CT  # CombatTuning
var CA  # CreatureAttack
var SP  # StoneProjectile

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("Game") == null:
		return false
	_started = true
	CT = load("res://scripts/combat/combat_tuning.gd")
	CA = load("res://scripts/combat/creature_attack.gd")
	SP = load("res://scripts/combat/stone_projectile.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_combatfx] FAIL %s" % msg)
	else:
		print("[t_combatfx] ok %s" % msg)

func _run() -> void:
	host = Node3D.new()
	host.name = "TCombatFx"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -0.5
	host.add_child(floor)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 20.0
	host.add_child(cam)
	cam.global_position = Vector3(-20, 20, 20)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	plates = (load("res://scripts/ui/creature_plates.gd") as GDScript).new()
	get_root().add_child(plates)
	get_root().get_node("Game").creature_ui = plates
	await physics_frame
	fx = plates.get("fx")
	_expect(fx != null, "CreaturePlates owns a CombatFx that draws the damage numbers")
	if fx == null:
		_finish()
		return
	print("[t_combatfx] view=%s" % fx.get_viewport_rect().size)
	var stego = _spawn(&"stegosaurus", Vector3(5, 0, 0))
	var raptor = _spawn(&"velociraptor", Vector3(-4, 0, 3))
	for i in 4:
		await process_frame
	fx.set_process(false)  # the test steps ages itself
	CT.force_accuracy = 1.0
	CT.force_dodge = 0.0
	_test_melee_ladder(stego)
	_test_ranged(stego)
	_test_taken(raptor)
	_test_heal_and_pet(stego, raptor)
	await _test_status_tick(raptor)
	_test_motion()
	_test_integrated_motion()
	_test_no_overlap()
	_test_edges()
	_test_cleanup()
	CT.reset_overrides()
	_finish()

func _finish() -> void:
	if host:
		host.queue_free()
	if plates:
		plates.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_combatfx] PASS")
		quit(0)
	else:
		print("[t_combatfx] FAIL count=%d" % failures.size())
		quit(1)

func _spawn(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.global_position = at
	c.spawn(get_root().get_node("Data").creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _last_on(anchor: Node) -> Dictionary:
	for i in range(fx.floats.size() - 1, -1, -1):
		var f: Dictionary = fx.floats[i]
		if int(f["target"]) == anchor.get_instance_id() and str(f["kind"]) != "status":  # BLEEDING etc. follow a hit
			return f
	return {}

func _height_at(f: Dictionary, age: float) -> float:
	return float(f["h"]) * float(fx.scale_at(f, age))

func _is(col: Color, hex: String) -> bool:
	var want := Color.html(hex)
	return absf(col.r - want.r) < 0.02 and absf(col.g - want.g) < 0.02 and absf(col.b - want.b) < 0.02

## The survivor's crit chance comes from data: 1.0 always crits, -1.0 never (the from-behind bonus is 0.2).
func _melee_crit(on: bool) -> void:
	CT.section("player_melee")["crit_base"] = 1.0 if on else -1.0

## Seeds the combat RNG so a creature's next swing (hit roll, then crit roll) does or does not crit.
func _seed_creature_crit(attacker, on: bool) -> void:
	var chance: float = attacker.crit_chance()
	for s in 100000:
		CT.rng.seed = s
		CT.rng.randf()
		if (CT.rng.randf() < chance) == on:
			CT.rng.seed = s
			return

func _test_melee_ladder(stego) -> void:
	var club = load("res://scripts/items/item_stack.gd").make(&"club", 1)
	stego.health.max_hp = 1.0e6  # a hit is a sliver of it: an ordinary number
	_melee_crit(false)
	player.hunt.land_hit(stego, club)
	var hit := _last_on(stego)
	_expect(str(hit.get("tier", "")) == "normal", "a melee hit makes a normal number (%s %s)" % [hit.get("tier", "none"), hit.get("text", "")])
	if hit.is_empty():
		return
	_expect(_is(hit["color"], "#ffffff"), "damage you deal is white (%s)" % (hit["color"] as Color).to_html(false))
	_expect(str(hit["text"]).is_valid_int(), "it reads as the bare damage (%s)" % hit["text"])
	var amount := float(str(hit["text"]))
	stego.health.max_hp = amount * 4.0  # a quarter of its HP in one hit
	stego.health.hp = stego.health.max_hp
	player.hunt.land_hit(stego, club)
	var big := _last_on(stego)
	_expect(str(big.get("tier", "")) == "big", "a hit taking %.0f%% of max HP is a big number (%s)" % [100.0 / 4.0, big.get("tier", "none")])
	stego.health.max_hp = 1.0e6
	stego.health.hp = stego.health.max_hp
	_melee_crit(true)
	player.hunt.land_hit(stego, club)
	var crit := _last_on(stego)
	_expect(str(crit.get("tier", "")) == "crit", "a melee crit makes a crit number (%s)" % crit.get("tier", "none"))
	if big.is_empty() or crit.is_empty():
		return
	_expect(_is(crit["color"], "#ffd21c"), "your crit is gold (%s)" % (crit["color"] as Color).to_html(false))
	_expect(float(crit["outline_px"]) > float(hit["outline_px"]), "and outlined heavier (%.0f vs %.0f px)" % [crit["outline_px"], hit["outline_px"]])
	_expect(_is(big["color"], "#ffffff"), "a big hit you deal stays white")
	for age in [0.0, 0.05, 0.1, 0.3, 0.6]:
		var n := _height_at(hit, age)
		var b := _height_at(big, age)
		var c := _height_at(crit, age)
		_expect(n < b and b < c, "at %.2f s the size ladder holds: normal %.1f < big %.1f < crit %.1f px" % [age, n, b, c])
	var ratio := _height_at(crit, 0.1) / _height_at(hit, 0.1)
	_expect(ratio > 1.4 and ratio < 1.6, "a crit starts about 1.5x a normal number (%.2fx)" % ratio)
	var view: Vector2 = fx.get_viewport_rect().size
	var peak: float = float(crit["h"]) * fx.num("expand_to", 1.4)
	_expect(peak < 0.06 * view.y, "even at its widest a crit stays small (%.0f px of %.0f)" % [peak, view.y])
	_expect(float(hit["h"]) <= 22.0 and float(hit["h"]) >= 12.0, "a normal number is small but readable (%.0f px)" % hit["h"])
	_melee_crit(false)

func _test_ranged(stego) -> void:
	for on in [false, true]:
		CT.section("ranged")["crit_base"] = 1.0 if on else -1.0
		var shot = SP.new()
		shot.source = player
		shot.damage = 45.0
		shot.impact(stego)
		shot.free()
		var f := _last_on(stego)
		_expect(str(f.get("tier", "")) == ("crit" if on else "normal"), "a ranged (slingshot) %s makes a %s number (%s)" % ["crit" if on else "hit", "crit" if on else "normal", f.get("tier", "none")])
	CT.section("ranged")["crit_base"] = 0.08

func _test_taken(raptor) -> void:
	player.vitals.max_health = 1.0e5  # every bite a sliver: the normal number
	player.vitals.health = player.vitals.max_health
	var before_on_raptor := _last_on(raptor)
	_seed_creature_crit(raptor, false)
	var landed: bool = CA._deal_damage(raptor, player)
	var bite := _last_on(player)
	_expect(landed and str(bite.get("tier", "")) == "normal", "a creature's bite puts a normal number over the survivor (%s)" % bite.get("tier", "none"))
	_seed_creature_crit(raptor, true)
	CA._deal_damage(raptor, player)
	var crit := _last_on(player)
	_expect(str(crit.get("tier", "")) == "crit", "its crit puts a crit-sized number over the survivor (%s)" % crit.get("tier", "none"))
	_expect(_last_on(raptor) == before_on_raptor, "and nothing over the attacker")
	if bite.is_empty() or crit.is_empty():
		return
	_expect(_is(bite["color"], "#ff4a3a") and _is(crit["color"], "#ff4a3a"), "damage taken is red, crit or not")
	_expect(_height_at(crit, 0.1) > 1.4 * _height_at(bite, 0.1), "the taken crit starts bigger")
	player.vitals.max_health = 100.0
	player.vitals.health = 100.0
	_seed_creature_crit(raptor, false)
	CA._deal_damage(raptor, player)
	var dealt := float(str(_last_on(player).get("text", "0")))
	var expect_tier: String = "big" if dealt >= fx.num("big_hit_frac", 0.1) * 100.0 else "normal"
	_expect(str(_last_on(player).get("tier", "")) == expect_tier, "a %.0f HP bite on 100 HP is %s" % [dealt, expect_tier])
	CT.force_accuracy = 0.0
	CA._deal_damage(raptor, player)
	var miss := _last_on(player)
	_expect(str(miss.get("text", "")) == "DODGE" and str(miss.get("tier", "")) == "small" and _is(miss.get("color", Color.BLACK), "#c4c4c4"), "a dodged bite shows a small grey DODGE (%s)" % miss.get("text", "none"))
	CT.force_accuracy = 1.0

func _test_heal_and_pet(stego, raptor) -> void:
	stego.health.hp = stego.health.max_hp - 50.0
	stego.health.heal(25.0)
	var heal := _last_on(stego)
	_expect(str(heal.get("text", "")) == "+25" and _is(heal.get("color", Color.BLACK), "#72ff80"), "a heal is a green +25 (%s)" % heal.get("text", "none"))
	raptor.is_pet = true
	raptor.combat_float.emit(9.0, &"hit")
	var f := _last_on(raptor)
	_expect(_is(f.get("color", Color.BLACK), "#ff4a3a"), "a hit on your pet reads as damage taken (red)")
	raptor.is_pet = false

## A bleed tick shows one small number (the old code printed every tick twice, a "hit" and a "dot").
func _test_status_tick(raptor) -> void:
	fx.floats.clear()
	raptor.health.hp = raptor.health.max_hp
	raptor.statuses.apply(&"bleeding_target", player)  # 3 HP a tick on a raptor (bleed x1.5)
	var until := Time.get_ticks_msec() + 1200  # wall clock: two 0.5 s ticks
	while Time.get_ticks_msec() < until:
		await process_frame
	var ticks: Array[String] = []
	for f in fx.floats:
		if int(f["target"]) == raptor.get_instance_id() and str(f["kind"]) != "status":
			ticks.append("%s:%s" % [f["kind"], f["tier"]])
	_expect(not ticks.is_empty() and ticks.all(func (k: String) -> bool: return k == "dot:small"), "each bleed tick is one small number (%s)" % [ticks])
	raptor.statuses.clear_id(&"bleeding_target")

## The motion the owner described: a quick pop, then expand outward while dissipating, floating up
## about one number-height, eased out, with no jumps.
func _test_motion() -> void:
	var dummy := Node3D.new()
	host.add_child(dummy)
	fx.add_number(dummy, 42.0, &"hit")
	var f := _last_on(dummy)
	var life := float(f["life"])
	var pop_s: float = fx.num("pop_s", 0.08)
	var expand: float = fx.num("expand_to", 1.4)
	var h := float(f["h"])
	_expect(absf(fx.scale_at(f, 0.0) - fx.num("pop_from", 0.6)) < 0.01 and absf(fx.scale_at(f, pop_s) - 1.0) < 0.01, "it pops in from %.1fx to 1.0x in %.2f s" % [fx.num("pop_from", 0.6), pop_s])
	_expect(absf(fx.scale_at(f, life) - expand) < 0.01, "then swells to %.2fx by the end of its life (%.2fx)" % [expand, fx.scale_at(f, life)])
	_expect(fx.alpha_at(f, life) < 0.01 and fx.alpha_at(f, 0.15) > 0.9, "it fades to nothing (%.2f) after reading clearly (%.2f at 0.15 s)" % [fx.alpha_at(f, life), fx.alpha_at(f, 0.15)])
	_expect(absf(fx.lift_at(f, life) - fx.num("rise_lines", 1.0) * h) < 0.5, "and floats up one number-height (%.1f of %.1f px)" % [fx.lift_at(f, life), h])
	_expect(life >= 0.6 and life <= 0.8, "over %.2f s" % life)
	var pop_step := 0.0
	var worst_scale := 0.0
	var worst_lift := 0.0
	var reversals := 0
	var prev_s: float = fx.scale_at(f, 0.0)
	var prev_l: float = fx.lift_at(f, 0.0)
	var prev_a: float = fx.alpha_at(f, pop_s)
	var age := DT
	while age <= life:
		var s: float = fx.scale_at(f, age)
		var l: float = fx.lift_at(f, age)
		var a: float = fx.alpha_at(f, age)
		if age <= pop_s + 1e-6:
			pop_step = maxf(pop_step, absf(s - prev_s))
		else:
			worst_scale = maxf(worst_scale, absf(s - prev_s))
		worst_lift = maxf(worst_lift, absf(l - prev_l))
		reversals += (1 if s < prev_s - 1e-6 else 0) + (1 if l < prev_l - 1e-6 else 0) + (1 if age > pop_s and a > prev_a + 1e-6 else 0)
		prev_s = s
		prev_l = l
		if age > pop_s:
			prev_a = a
		age += DT
	_expect(reversals == 0, "size and height only grow and opacity only falls after the pop (%d reversals)" % reversals)
	_expect(pop_step < 0.16, "the pop takes several frames (biggest step %.3fx)" % pop_step)
	_expect(worst_scale < 0.02 and worst_lift < 0.08 * h, "then no frame jumps: biggest step %.4fx size, %.2f px height" % [worst_scale, worst_lift])
	fx.floats.erase(f)
	dummy.free()

## The same motion through _process and placement: a still anchor's number keeps its x, rises every
## frame and grows every frame after the pop, centred on itself.
func _test_integrated_motion() -> void:
	var dummy := Node3D.new()
	host.add_child(dummy)
	dummy.global_position = Vector3(0, 0, 0)
	fx.add_number(dummy, 86.0, &"crit")
	var f := _last_on(dummy)
	var xs: Array[float] = []
	var ys: Array[float] = []
	var hs: Array[float] = []
	while fx.floats.has(f):
		var r: Rect2 = fx.screen_rect(f, cam)
		xs.append(r.get_center().x)
		ys.append(r.get_center().y)
		hs.append(r.size.y)
		fx._process(DT)
	var x_drift := 0.0
	var y_back := 0
	var h_back := 0
	for i in range(1, xs.size()):
		x_drift = maxf(x_drift, absf(xs[i] - xs[0]))
		y_back += 1 if ys[i] > ys[i - 1] + 1e-3 else 0
		h_back += 1 if hs[i] < hs[i - 1] - 1e-3 else 0
	_expect(xs.size() >= 40, "it lives %d frames at 60 fps" % xs.size())
	_expect(x_drift < 0.01 and y_back == 0 and h_back == 0, "over the frame sequence it stays centred (x drift %.3f px), only rises (%d dips) and only grows (%d shrinks)" % [x_drift, y_back, h_back])
	dummy.free()

## Ten hits a second (one crit in five) on one target for 1.5 s: at no frame do two readable numbers overlap.
func _test_no_overlap() -> void:
	var dummy := Node3D.new()
	host.add_child(dummy)
	dummy.global_position = Vector3(0, 0, 0)
	var t := 0.0
	var next := 0.0
	var n := 0
	var worst := 0
	var live_max := 0
	var vis: float = fx.num("visible_alpha", 0.3)
	var spawn_us := 0
	var furthest := 0.0
	var furthest_px := 0.0
	while t < 1.5:
		if t >= next:
			var t0 := Time.get_ticks_usec()
			fx.add_number(dummy, 10.0 + n * 7, &"crit" if n % 5 == 0 else &"hit")
			spawn_us = maxi(spawn_us, Time.get_ticks_usec() - t0)
			furthest = maxf(furthest, absf(float(fx.floats[-1]["lane"])) / float(fx.floats[-1]["w"]))
			furthest_px = maxf(furthest_px, absf(float(fx.floats[-1]["lane"])))
			n += 1
			next += 0.1
		var rects: Array[Rect2] = []
		for f in fx.floats:
			if int(f["target"]) == dummy.get_instance_id() and fx.alpha_at(f, float(f["age"])) >= vis:
				rects.append(fx.screen_rect(f, cam))
		live_max = maxi(live_max, rects.size())
		var overlaps := 0
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				overlaps += 1 if rects[i].grow(-1.0).intersects(rects[j].grow(-1.0)) else 0

		worst = maxi(worst, overlaps)
		fx._process(DT)
		t += DT
	var both := Node3D.new()
	host.add_child(both)
	fx.add_number(both, 34.0, &"crit")
	fx.add_word(both, "BLEEDING", Color.RED)
	var pair: Array = fx.floats.filter(func (f: Dictionary) -> bool: return int(f["target"]) == both.get_instance_id())
	var met := 0
	for i in 40:
		fx._process(DT)
		met += 1 if pair.size() == 2 and fx.screen_rect(pair[0], cam).intersects(fx.screen_rect(pair[1], cam)) else 0
	_expect(pair.size() == 2 and met == 0, "a crit and its status word in the same frame sit apart (%d frames overlapping)" % met)
	both.free()
	_expect(worst == 0, "10 hits/s for 1.5 s: no two readable numbers overlap (worst frame %d, up to %d readable at once)" % [worst, live_max])
	_expect(spawn_us < 2000, "placing a number costs at most %d us" % spawn_us)
	_expect(furthest <= 5.0, "the offsets stay small: the furthest number sits %.1f of its widths (%.0f px) beside the anchor" % [furthest, furthest_px])
	dummy.free()
	_drain()

## Anchors far past each screen edge: every number stays whole on screen for its whole life.
func _test_edges() -> void:
	var view: Vector2 = fx.get_viewport_rect().size
	var screen := Rect2(Vector2.ZERO, view)
	var bad := 0
	var tried := 0
	for dir in [cam.global_basis.x, -cam.global_basis.x, cam.global_basis.y, -cam.global_basis.y]:
		var edge := Node3D.new()
		host.add_child(edge)
		edge.global_position = dir * 60.0
		fx.add_number(edge, 186.0, &"crit")
		var f := _last_on(edge)
		var age := 0.0
		while age <= float(f["life"]):
			f["age"] = age
			var r: Rect2 = fx.screen_rect(f, cam)
			tried += 1
			bad += 0 if r.has_area() and screen.encloses(r) else 1
			age += 0.05
		fx.floats.erase(f)
		edge.free()
	_expect(tried > 0 and bad == 0, "a crit past any screen edge stays whole on screen all its life (%d of %d frames clipped)" % [bad, tried])

## Numbers go when their life ends, also when the creature under them is freed mid-flight.
func _test_cleanup() -> void:
	var gone := Node3D.new()
	host.add_child(gone)
	gone.global_position = Vector3(2, 0, 2)
	fx.add_number(gone, 30.0, &"hit")
	var f := _last_on(gone)
	fx._process(0.2)
	var at: Vector3 = f["at"]
	gone.free()
	var r: Rect2 = fx.screen_rect(f, cam)
	_expect(r.has_area() and (f["at"] as Vector3).is_equal_approx(at), "a number over a freed creature finishes where it was")
	_drain()
	_expect(fx.floats.is_empty(), "every number is gone after its life (%d left)" % fx.floats.size())

func _drain() -> void:
	for i in 120:
		fx._process(DT)
