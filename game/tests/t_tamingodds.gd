extends SceneTree
## TAMINGODDS (roadmap: docs/design/durango-informed-improvements.md 5): the taming odds are an S-curve
## on (survival level - creature level) with a bonus for lower remaining health, clamped to
## [0.05, 0.95], shown on the plate before the survivor commits; the grade is earned by preparation
## (a bait item in the bag). The capture-open rule is untouched: 0.30 opens, 0.31 stays closed.
## Run: Godot --headless --path game --script res://tests/t_tamingodds.gd -> "[t_tamingodds] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const MIN_ODDS := 0.05
const MAX_ODDS := 0.95

var _fails: PackedStringArray = []
var _started := false
var _sections := 0
var _host: Node3D
var _player
var OddsS: GDScript
var FieldTameS: GDScript
var CaptureS: GDScript
var HealthS: GDScript
var StatusS: GDScript
var CreatureS: GDScript
var GeneticsS: GDScript
var ItemStackS: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	OddsS = load("res://scripts/pets/taming_odds.gd")
	FieldTameS = load("res://scripts/pets/field_tame.gd")
	CaptureS = load("res://scripts/pets/capture_system.gd")
	HealthS = load("res://scripts/combat/health.gd")
	StatusS = load("res://scripts/combat/status_effects.gd")
	CreatureS = load("res://scripts/creatures/creature.gd")
	GeneticsS = load("res://scripts/creatures/creature_genetics.gd")
	ItemStackS = load("res://scripts/items/item_stack.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_tamingodds] FAIL %s" % what)

func _run() -> void:
	_host = Node3D.new()
	_host.name = "TTamingOdds"
	get_root().add_child(_host)
	if OddsS == null or not OddsS.has_method("odds_for"):
		_expect(false, "res://scripts/pets/taming_odds.gd is missing odds_for(): no S-curve exists yet")
		_finish()
		return
	_test_curve_shape()
	_test_clamps()
	_test_monotonic()
	_test_capture_boundary()
	await _test_shown_equals_used()
	await _test_grade_by_bait()
	_finish()

func _finish() -> void:
	var want := 6
	if _sections != want and _fails.is_empty():
		_expect(false, "only %d of %d test sections completed (a runtime error aborted the rest)" % [_sections, want])
	if _host and is_instance_valid(_host):
		_host.queue_free()
	if _fails.is_empty():
		print("[t_tamingodds] PASS")
		quit(0)
	else:
		print("[t_tamingodds] FAIL count=%d" % _fails.size())
		quit(1)

## A bare wild animal with only what the odds read: def, health, level (no scene node, no brain).
func _creature(species: StringName, hp_frac: float, lv: int = 1, stunned: bool = true):
	var cr = CreatureS.new()
	cr.def = (get_root().get_node("Data") as Node).creature(species)
	cr.level = lv
	cr.health = HealthS.new()
	cr.health.setup(cr.def.hp)
	cr.add_child(cr.health)
	cr.statuses = StatusS.new()
	cr.add_child(cr.statuses)
	cr.health.hp = cr.def.hp * hp_frac
	cr.is_capturable = true
	if stunned:
		cr.statuses.apply(&"knockdown")
	return cr

# ---------------------------------------------------------------- 1. the curve's anchors

## The design doc's starting points: 50 % at an even level gap, 85 % ten levels ahead, 10 % ten levels
## behind. Those describe the LEVEL half of the curve, so they are read off TamingOdds.level_odds().
func _test_curve_shape() -> void:
	var even: float = OddsS.level_odds(0.0)
	var ahead: float = OddsS.level_odds(10.0)
	var behind: float = OddsS.level_odds(-10.0)
	_expect(absf(even - 0.50) < 0.01, "an even level gap reads %.2f, the doc says 0.50" % even)
	_expect(absf(ahead - 0.85) < 0.01, "10 levels ahead reads %.2f, the doc says 0.85" % ahead)
	_expect(absf(behind - 0.10) < 0.01, "-10 levels reads %.2f, the doc says 0.10" % behind)
	# A logistic, not a line: the middle of the gap moves the curve more than its ends.
	var mid_step: float = OddsS.level_odds(1.0) - OddsS.level_odds(-1.0)
	var end_step: float = OddsS.level_odds(13.0) - OddsS.level_odds(11.0)
	_expect(mid_step > end_step, "S-shaped: d(-1..1)=%.3f > d(11..13)=%.3f" % [mid_step, end_step])
	var even_raw: float = OddsS.raw_odds(25, 0.30, 25, 1)
	_expect(even_raw > MIN_ODDS and even_raw < MAX_ODDS, "an even gap at exactly 30 %% is %.3f, inside the clamps" % even_raw)
	print("[t_tamingodds] curve even=%.2f ahead10=%.2f behind10=%.2f even_raw=%.3f" % [even, ahead, behind, even_raw])
	_sections += 1

# ---------------------------------------------------------------- 2. clamps

func _test_clamps() -> void:
	var worst: float = OddsS.odds_for_values(60, 1.0, 1, 1)
	var best: float = OddsS.odds_for_values(1, 0.0, 60, 5)
	_expect(is_equal_approx(worst, MIN_ODDS), "a hopeless setup clamps to %.2f (got %.4f)" % [MIN_ODDS, worst])
	_expect(is_equal_approx(best, MAX_ODDS), "a perfect setup clamps to %.2f (got %.4f)" % [MAX_ODDS, best])
	var lo := 1.0
	var hi := 0.0
	var bad := 0
	for lv: int in [1, 13, 25, 45, 60]:
		for hp: float in [0.0, 0.05, 0.30, 0.31, 0.6, 1.0]:
			for level: int in [1, 10, 25, 60]:
				for tier: int in [1, 3, 5]:
					var odds: float = OddsS.odds_for_values(lv, hp, level, tier)
					lo = minf(lo, odds)
					hi = maxf(hi, odds)
					if odds < MIN_ODDS - 0.0001 or odds > MAX_ODDS + 0.0001:
						bad += 1
	_expect(bad == 0, "%d swept combinations read outside [%.2f, %.2f]" % [bad, MIN_ODDS, MAX_ODDS])
	var c = _creature(&"velociraptor", 0.30, 25)
	var odds_c: float = OddsS.odds_for(c, null, 1)
	_expect(odds_c >= MIN_ODDS and odds_c <= MAX_ODDS, "odds_for reads inside the clamps (%.4f)" % odds_c)
	_expect(OddsS.odds_for(null) == 0.0, "no target has no odds")
	_expect(OddsS.odds_for(c, null, 99) <= MAX_ODDS, "an absurd net tier cannot pass the ceiling")
	c.free()
	print("[t_tamingodds] clamps worst=%.2f best=%.2f swept %.2f..%.2f" % [worst, best, lo, hi])
	_sections += 1

# ---------------------------------------------------------------- 3. monotonic + deterministic

func _test_monotonic() -> void:
	var decreasing := 0
	var prev := -1.0
	for gap in range(-30, 31):
		var lvl: float = OddsS.level_odds(float(gap))
		if lvl <= prev:
			decreasing += 1
		prev = lvl
	_expect(decreasing == 0, "level odds must rise with every gap step (%d did not)" % decreasing)
	var c = _creature(&"velociraptor", 1.0, 25)
	var drops := 0
	var last := -1.0
	for i in 21:
		var hp := 1.0 - float(i) * 0.05
		c.health.hp = c.health.max_hp * hp
		var odds: float = OddsS.odds_for(c, null, 1)
		if odds < last - 0.00001:
			drops += 1
		last = odds
	_expect(drops == 0, "lower health must never lower the odds (%d steps did)" % drops)
	# Pure function: the same target reads the same number twice (nothing is rolled here).
	var a: float = OddsS.odds_for(c, null, 1)
	var b: float = OddsS.odds_for(c, null, 1)
	_expect(is_equal_approx(a, b), "the same target reads the same odds twice (%.5f vs %.5f)" % [a, b])
	var hard = _creature(&"velociraptor", 0.2, 30)
	var mild = _creature(&"velociraptor", 0.2, 1)
	_expect(OddsS.odds_for(mild, null, 1) > OddsS.odds_for(hard, null, 1), "an easier target reads better odds")
	# Seeded rolls: the same seed repeats exactly; another seed gives another sequence.
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	var r3 := RandomNumberGenerator.new()
	r1.seed = 7
	r2.seed = 7
	r3.seed = 8
	var same := 0
	var diff := 0
	for i in 64:
		var x: bool = OddsS.succeeds(0.5, r1)
		var y: bool = OddsS.succeeds(0.5, r2)
		var z: bool = OddsS.succeeds(0.5, r3)
		if x == y:
			same += 1
		if x != z:
			diff += 1
	_expect(same == 64, "the same seed gives the same 64 results (%d of 64 matched)" % same)
	_expect(diff > 8, "a different seed changes the roll (%d of 64 differed)" % diff)
	print("[t_tamingodds] monotonic gaps61 hp21 seed7 repeat=%d/64 seeddiff=%d/64" % [same, diff])
	c.free()
	hard.free()
	mild.free()
	_sections += 1

# ---------------------------------------------------------------- 4. the capture rule did not move

func _test_capture_boundary() -> void:
	var at30 = _creature(&"velociraptor", 0.30, 25, false)
	var at31 = _creature(&"velociraptor", 0.31, 25, false)
	_expect(FieldTameS.CAPTURE_HEALTH_FRAC == 0.30, "CAPTURE_HEALTH_FRAC is still 0.30 (got %.3f)" % FieldTameS.CAPTURE_HEALTH_FRAC)
	_expect(FieldTameS.health_allows_capture(0.30), "0.30 opens the capture window")
	_expect(not FieldTameS.health_allows_capture(0.31), "0.31 keeps it closed")
	_expect(FieldTameS.window_open(30.0, 100.0, false) and not FieldTameS.window_open(31.0, 100.0, false), "window_open keeps the 0.30 / 0.31 boundary")
	_expect(FieldTameS.capture_window(at30) and not FieldTameS.capture_window(at31), "capture_window keeps the 0.30 / 0.31 boundary")
	_expect(FieldTameS.can_attempt(at30) and not FieldTameS.can_attempt(at31), "can_attempt keeps the 0.30 / 0.31 boundary")
	# Odds exist above the threshold (the plate can explain the gap) but never open it.
	_expect(OddsS.odds_for(at31, null, 1) > 0.0 and not FieldTameS.capture_window(at31), "odds do not open a 31 %% animal")
	# The data copy of the threshold agrees with the rule in code; the rule in code is the one read.
	_expect(is_equal_approx(float(OddsS.knobs().get("capture_health_frac", -1.0)), FieldTameS.CAPTURE_HEALTH_FRAC), "data/taming_odds.json capture_health_frac agrees with FieldTame")
	_expect(is_equal_approx(OddsS.capture_frac(), FieldTameS.CAPTURE_HEALTH_FRAC), "the curve reads FieldTame's threshold, not its own copy")
	at30.free()
	at31.free()
	print("[t_tamingodds] boundary 0.30=open 0.31=closed")
	_sections += 1

# ---------------------------------------------------------------- 5. shown == used

## The plate's number and the roll the net makes are the same function of the same inputs.
func _test_shown_equals_used() -> void:
	var data: Node = get_root().get_node("Data")
	data.set_survival_unlocked(&"capture_technique_II", true)
	_player.skills.trees["survival"]["level"] = 22
	_player.inventory.add(ItemStackS.make(&"capture_net_ii", 1))
	_player.inventory.add(ItemStackS.make(&"raw_meat", 4))
	var c = _creature(&"velociraptor", 0.30, 25)
	_host.add_child(c)
	var shown: float = OddsS.odds_for(c, _player, 2)
	var used: float = CaptureS.chance_for(c, 2, _player)
	_expect(is_equal_approx(shown, used), "the shown odds %.4f are the odds the net rolls %.4f" % [shown, used])
	_expect(shown > MIN_ODDS and shown < MAX_ODDS, "Survival 22 vs a Lv25 animal at 30 %% reads %.3f, unclamped" % shown)
	var hint: Dictionary = FieldTameS.plate_hint(c, _player.inventory, _player)
	_expect(hint.has("odds"), "the plate hint carries the odds")
	_expect(is_equal_approx(float(hint.get("odds", -1.0)), shown), "the plate's odds %.4f equal odds_for %.4f" % [float(hint.get("odds", -1.0)), shown])
	var label: String = str(hint.get("text", ""))
	_expect(label.contains(OddsS.caption(shown)), "the plate reads '%s' for %.3f" % [label, shown])
	# The same animal reads better as the survivor levels and as the net improves.
	_player.skills.trees["survival"]["level"] = 45
	var better: float = CaptureS.chance_for(c, 2, _player)
	_expect(better > used, "Survival 45 reads %.3f > Survival 22's %.3f" % [better, used])
	_player.skills.trees["survival"]["level"] = 25
	var t1: float = CaptureS.chance_for(c, 1, _player)
	var t5: float = CaptureS.chance_for(c, 5, _player)
	_expect(t5 > t1, "a better net reads better odds (tier 5 %.3f > tier 1 %.3f)" % [t5, t1])
	_expect(t1 < better, "no survivor reads worse odds than a level-45 one (%.3f vs %.3f)" % [t1, better])
	# attempt() rolls the shown odds: a far-ahead gap at 0 % HP lands nearly every seeded throw.
	var ceiling: float = OddsS.odds_for_values(1, 0.0, 25, 2)
	_expect(ceiling > 0.90, "a far-ahead gap at 0 %% HP reads %.3f" % ceiling)
	var netted := 0
	var tries := 40
	for i in tries:
		var prey = _creature(&"compsognathus", 0.0, 1)
		_host.add_child(prey)
		_player.inventory.add(ItemStackS.make(&"capture_net_ii", 1))
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		if CaptureS.attempt(_player, prey, 0, rng):
			netted += 1
			_player.inventory.consume(&"captured_animal", 1)  # the throw is what is measured, not the bag
		if is_instance_valid(prey) and not prey.is_queued_for_deletion():
			prey.free()
	var rate := float(netted) / float(tries)
	_expect(rate > 0.85, "%d seeded throws at %.2f landed %.0f %% of the time" % [tries, ceiling, 100.0 * rate])
	# Same seed, same inputs, same result on two fresh animals.
	var two_a = _creature(&"compsognathus", 0.0, 1)
	var two_b = _creature(&"compsognathus", 0.0, 1)
	_host.add_child(two_a)
	_host.add_child(two_b)
	var ra := RandomNumberGenerator.new()
	var rb := RandomNumberGenerator.new()
	ra.seed = 4242
	rb.seed = 4242
	_player.inventory.add(ItemStackS.make(&"capture_net_ii", 2))
	var ok_a: bool = CaptureS.attempt(_player, two_a, 0, ra)
	var ok_b: bool = CaptureS.attempt(_player, two_b, 0, rb)
	_expect(ok_a == ok_b, "the same seed and inputs give the same result (%s vs %s)" % [ok_a, ok_b])
	for n in [two_a, two_b]:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			n.free()
	_player.inventory.consume(&"captured_animal", _player.inventory.count_of(&"captured_animal"))
	_expect(CaptureS.attempt(_player, c, -1, null) == false, "a forced failure still fails the throw")
	_expect(c.is_capturable == false and c.statuses.has(&"enraged"), "a failed throw clears the knockdown and enrages")
	_player.inventory.add(ItemStackS.make(&"capture_net_ii", 1))
	c.statuses.clear_id(&"enraged")
	c.statuses.apply(&"knockdown")
	_player.inventory.consume(&"captured_animal", _player.inventory.count_of(&"captured_animal"))
	_expect(CaptureS.attempt(_player, c, 1, null), "a forced success still takes the animal")
	data.set_survival_unlocked(&"capture_technique_II", false)
	print("[t_tamingodds] shown=%.3f used=%.3f label='%s' ceiling=%.2f seeded_rate=%.2f same_seed=%s" % [shown, used, label, ceiling, rate, ok_a == ok_b])
	_sections += 1

# ---------------------------------------------------------------- 6. grade earned by preparation

## A bait item in the bag is spent on the completed tame and raises the pet's IVs, which is its grade.
func _test_grade_by_bait() -> void:
	var base_ivs: int = 16 * GeneticsS.STATS.size()
	var def: CreatureDef = (get_root().get_node("Data") as Node).creature(&"compsognathus")
	var food: StringName = def.preferred_food[0]
	var before: int = _player.bonded.size()
	_player.inventory.consume(&"leech", _player.inventory.count_of(&"leech"))
	var plain = _spawn_tameable(&"compsognathus", Vector3(6.0, 0.0, 0.0))
	plain.genetics = GeneticsS.neutral()
	_player.inventory.add(ItemStackS.make(food, 3))
	FieldTameS.begin_window(plain)
	for i in 4:
		if not plain.is_pet:
			FieldTameS.apply_feed(_player, plain, food)
	_expect(_player.bonded.size() == before + 1, "no bait: the tame still completes (%d bonded)" % _player.bonded.size())
	var plain_rec = _player.bonded[-1] if _player.bonded.size() > before else null
	_expect(plain_rec != null and _iv_sum(plain_rec) == base_ivs, "no bait leaves the IVs alone (sum %d, want %d)" % [_iv_sum(plain_rec) if plain_rec else -1, base_ivs])
	var plain_grade: StringName = plain_rec.grade if plain_rec else &"?"
	# The bait is spent by the LAST feed only: an unfinished tame keeps it.
	var spent_early = _spawn_tameable(&"protoceratops", Vector3(7.0, 0.0, 0.0))
	spent_early.genetics = GeneticsS.neutral()
	_player.inventory.add(ItemStackS.make(&"leech", 1))
	_player.inventory.add(ItemStackS.make(food, 3))
	FieldTameS.begin_window(spent_early)
	FieldTameS.apply_feed(_player, spent_early, food)
	_expect(not spent_early.is_pet and _player.inventory.count_of(&"leech") == 1, "an unfinished tame keeps its bait (left %d)" % _player.inventory.count_of(&"leech"))
	var baited = _spawn_tameable(&"compsognathus", Vector3(8.0, 0.0, 0.0))
	baited.genetics = GeneticsS.neutral()
	_player.inventory.add(ItemStackS.make(food, 3))
	FieldTameS.begin_window(baited)
	for i in 4:
		if not baited.is_pet:
			FieldTameS.apply_feed(_player, baited, food)
	var bait_rec = _player.bonded[-1] if _player.bonded.size() > before + 1 else null
	var bonus: int = int(OddsS.prep_iv_bonus())
	_expect(bonus > 0, "the bait bonus is a positive number of IV points (got %d)" % bonus)
	_expect(bait_rec != null and _iv_sum(bait_rec) == base_ivs + bonus * GeneticsS.STATS.size(), "bait raises every IV by %d (sum %d, want %d)" % [bonus, _iv_sum(bait_rec) if bait_rec else -1, base_ivs + bonus * GeneticsS.STATS.size()])
	_expect(bait_rec != null and bait_rec.grade != plain_grade, "bait earns a better grade (%s with, %s without)" % [bait_rec.grade if bait_rec else "?", plain_grade])
	_expect(_player.inventory.count_of(&"leech") == 0, "the bait is spent on the completed tame (left %d)" % _player.inventory.count_of(&"leech"))
	# The record's grade is still its genetics' grade (PetRecord.recompute: one source).
	_expect(bait_rec != null and bait_rec.grade == bait_rec.genetics.overall_tier(), "the baited pet's grade is its genetics' grade (%s)" % (bait_rec.grade if bait_rec else "?"))
	print("[t_tamingodds] grade no_bait=%s ivs=%d bait=%s ivs=%d leech=%d" % [plain_grade, _iv_sum(plain_rec) if plain_rec else -1, bait_rec.grade if bait_rec else "?", _iv_sum(bait_rec) if bait_rec else -1, _player.inventory.count_of(&"leech")])
	_sections += 1

func _spawn_tameable(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	_host.add_child(c)
	c.global_position = at
	c.spawn((get_root().get_node("Data") as Node).creature(species), &"", 0)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.health.hp = c.health.max_hp * 0.2
	c.statuses.apply(&"knockdown")
	return c

func _iv_sum(rec) -> int:
	var total := 0
	if rec == null or rec.genetics == null:
		return -1
	for v in rec.genetics.ivs.values():
		total += int(v)
	return total
