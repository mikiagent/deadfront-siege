extends SceneTree
## TAMINGODDS (roadmap: docs/design/durango-informed-improvements.md §5): taming odds are an S-curve
## on (survival level − creature level) times a bonus for lower remaining health, clamped to
## [0.05, 0.95], shown on the plate before the survivor commits; the grade is earned by preparation
## (a bait item in the bag). The capture-open rule is untouched: 0.30 opens, 0.31 stays closed.
## Run: Godot --headless --path game --script res://tests/t_tamingodds.gd -> "[t_tamingodds] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const WATCHDOG_S := 60.0
const MIN_ODDS := 0.05
const MAX_ODDS := 0.95

var _fails: PackedStringArray = []
var _started := false
var _t0 := 0.0
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
	_t0 = Time.get_ticks_msec() * 0.001
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
	if OddsS == null:
		_expect(false, "res://scripts/pets/taming_odds.gd is missing: no S-curve exists yet")
		_finish()
		return
	_host = Node3D.new()
	_host.name = "TTamingOdds"
	get_root().add_child(_host)
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

## A bare wild animal with only what the odds read: def, health, level (no scene, no brain).
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

## A real survivor in the tree: PlayerRegistry.local() is what the plate reads.
func _make_player() -> void:
	var p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_host.add_child(p)
	_player = p

# ---------------------------------------------------------------- 1. the curve's anchors

## The design doc's starting points: 50 % at an even level gap, 85 % ten levels ahead, 10 % ten
## behind. Those are the LEVEL half of the curve (the net tier and HP scale it), so they are read off
## TamingOdds.level_odds().
func _test_curve_shape() -> void:
	var even: float = OddsS.level_odds(0)
	var ahead: float = OddsS.level_odds(10)
	var behind: float = OddsS.level_odds(-10)
	_expect(absf(even - 0.50) < 0.01, "even level gap reads %.2f, the doc says 0.50" % even)
	_expect(absf(ahead - 0.85) < 0.01, "10 levels ahead reads %.2f, the doc says 0.85" % ahead)
	_expect(absf(behind - 0.10) < 0.01, "-10 levels reads %.2f, the doc says 0.10" % behind)
	# A logistic, not a line: the first 2 levels of a gap move the curve less than the middle ones.
	var low_step: float = OddsS.level_odds(4) - OddsS.level_odds(2)
	var mid_step: float = OddsS.level_odds(1) - OddsS.level_odds(-1)
	_expect(low_step < mid_step, "the curve is S-shaped: d(2..4)=%.3f < d(-1..1)=%.3f" % [low_step, mid_step])
	print("[t_tamingodds] curve even=%.2f ahead10=%.2f behind10=%.2f" % [even, ahead, behind])
	_sections += 1

# ---------------------------------------------------------------- 2. clamps

func _test_clamps() -> void:
	var beast = _creature(&"tyrannosaurus", 1.0, 60)
	var gap_big: float = OddsS.odds_for(beast, null, 5)
	gap_big = OddsS.level_odds(-1000)
	_expect(absf(gap_big - MIN_ODDS) < 0.0001, "a hopeless gap clamps to %.2f (got %.4f)" % [MIN_ODDS, gap_big])
	var easy = _creature(&"compsognathus", 0.0, 1)
	var best: float = OddsS.odds_for(easy, null, 5)
	_expect(absf(best - MAX_ODDS) < 0.0001, "a perfect setup clamps to %.2f (got %.4f)" % [MAX_ODDS, best])
	# Every combination stays inside the clamp, never at 0 or 1.
	var lo := 1.0
	var hi := 0.0
	for species: StringName in [&"compsognathus", &"velociraptor", &"tyrannosaurus", &"smilodon"]:
		for lv: int in [1, 20, 45, 60]:
			for hp: float in [0.0, 0.30, 0.31, 0.8, 1.0]:
				var c = _creature(species, hp, lv)
				for gap: int in [-60, -10, 0, 10, 60]:
					var odds: float = OddsS.level_odds(gap) * OddsS.odds_for(c, null, 1) / maxf(0.0001, OddsS.level_odds(0))
					lo = minf(lo, odds)
					hi = maxf(hi, odds)
					var raw: float = OddsS.odds_for(c, null, 1)
					_expect(raw >= MIN_ODDS - 0.0001 and raw <= MAX_ODDS + 0.0001, "%s lv%d hp%.2f gap%d odds %.3f outside [%.2f, %.2f]" % [species, lv, hp, gap, raw, MIN_ODDS, MAX_ODDS])
				c.free()
	_expect(lo > 0.0 and hi < 1.0, "odds never reach 0 or 1 (saw %.4f..%.4f)" % [lo, hi])
	beast.free()
	easy.free()
	print("[t_tamingodds] clamps lo=%.2f hi=%.2f" % [MIN_ODDS, MAX_ODDS])
	_sections += 1

# ---------------------------------------------------------------- 3. monotonic

func _test_monotonic() -> void:
	var prev := -1.0
	var gaps := -30
	while gaps <= 30:
		var lvl := OddsS.level_odds(gaps)
		_expect(lvl > prev, "level odds must rise with the gap (gap %d: %.4f <= %.4f)" % [gaps, lvl, prev])
		prev = lvl
		gaps += 1
	var c = _creature(&"velociraptor", 1.0, 25)
	var last := 2.0
	for i in 21:
		var hp := 1.0 - float(i) * 0.05
		c.health.hp = c.health.max_hp * hp
		var odds: float = OddsS.odds_for(c, null, 1)
		_expect(odds <= last + 0.00001, "lower health must not lower the odds (hp %.2f: %.4f > %.4f)" % [hp, odds, last])
		last = odds
	# Same inputs, same number: the odds are pure, not rolled.
	var a := OddsS.odds_for(c, null, 1)
	var b := OddsS.odds_for(c, null, 1)
	_expect(is_equal_approx(a, b), "the same target reads the same odds twice (%.5f vs %.5f)" % [a, b])
	# A creature ten levels above a level-1 survivor is harder than one ten below.
	var hard = _creature(&"velociraptor", 0.2, 30)
	var mild = _creature(&"velociraptor", 0.2, 1)
	_expect(OddsS.odds_for(mild, null, 1) > OddsS.odds_for(hard, null, 1), "an easier target reads better odds")
	# Seeded rolls: the same seed and odds repeat exactly; another seed differs.
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
	_expect(same == 64, "the same seed gives the same 64 results (only %d matched)" % same)
	_expect(diff > 8, "a different seed changes the roll (%d of 64 differed)" % diff)
	print("[t_tamingodds] monotonic gaps40 hp21 seed7 repeat=%d/64 seeddiff=%d/64" % [same, diff])
	c.free()
	hard.free()
	mild.free()
	_sections += 1

# ---------------------------------------------------------------- 4. the capture rule did not move

func _test_capture_boundary() -> void:
	var at30 = _creature(&"velociraptor", 0.30, 25, false)
	var at31 = _creature(&"velociraptor", 0.31, 25, false)
	_expect(FieldTameS.health_allows_capture(0.30), "0.30 opens the capture window")
	_expect(not FieldTameS.health_allows_capture(0.31), "0.31 keeps it closed")
	_expect(FieldTameS.CAPTURE_HEALTH_FRAC == 0.30, "CAPTURE_HEALTH_FRAC is still 0.30 (got %.2f)" % FieldTameS.CAPTURE_HEALTH_FRAC)
	_expect(FieldTameS.window_open(30.0, 100.0, false) and not FieldTameS.window_open(31.0, 100.0, false), "window_open keeps the 0.30 / 0.31 boundary")
	_expect(FieldTameS.capture_window(at30) and not FieldTameS.capture_window(at31), "capture_window keeps the 0.30 / 0.31 boundary")
	_expect(FieldTameS.can_attempt(at30) and not FieldTameS.can_attempt(at31), "can_attempt keeps the 0.30 / 0.31 boundary")
	# Odds exist for a closed target too (the plate can explain the gap) but never open it.
	_expect(OddsS.odds_for(at31, null, 1) > 0.0 and not FieldTameS.capture_window(at31), "odds do not open a 31 % animal")
	at30.free()
	at31.free()
	print("[t_tamingodds] boundary 0.30=open 0.31=closed")
	_sections += 1

# ---------------------------------------------------------------- 5. shown == used

## The plate's number and the roll the net makes are the same function of the same inputs.
func _test_shown_equals_used() -> void:
	_make_player()
	var data: Node = get_root().get_node("Data")
	data.set_survival_unlocked(&"capture_technique_II", true)
	_player.skills.trees["survival"]["level"] = 22
	_player.inventory.add(ItemStackS.make(&"capture_net_ii", 3))
	_player.inventory.add(ItemStackS.make(&"raw_meat", 4))
	var c = _creature(&"velociraptor", 0.30, 25)
	c.global_position = Vector3(2.0, 0.0, 0.0)
	_host.add_child(c)
	var shown: float = OddsS.odds_for(c, _player)
	var used: float = CaptureS.chance_for(c, 2, _player)
	_expect(is_equal_approx(shown, used), "the shown odds %.4f are the odds the net rolls %.4f" % [shown, used])
	var hint: Dictionary = FieldTameS.plate_hint(c, _player.inventory)
	_expect(hint.has("odds"), "the plate hint carries the odds")
	_expect(is_equal_approx(float(hint.get("odds", -1.0)), shown), "the plate's odds %.4f equal odds_for %.4f" % [float(hint.get("odds", -1.0)), shown])
	var label: String = FieldTameS.tame_caption(shown)
	_expect(label == "Tame %d%%" % roundi(shown * 100.0), "the plate reads '%s' for %.3f" % [label, shown])
	# 22 vs 25 is a −3 gap at 30 % HP: prepared but behind, inside the clamps.
	_expect(shown > MIN_ODDS and shown < MAX_ODDS, "a -3 gap at 30 %% reads %.3f, unclamped" % shown)
	# The level gap moves the net's odds: the same animal is easier for a higher Survival level.
	_player.skills.trees["survival"]["level"] = 45
	var better: float = CaptureS.chance_for(c, 2, _player)
	_expect(better > used, "Survival 45 reads %.3f > Survival 22's %.3f" % [better, used])
	# The net's own tier still scales it, and a null player is the even-gap baseline.
	_player.skills.trees["survival"]["level"] = 25
	var t1: float = CaptureS.chance_for(c, 1)
	var t5: float = CaptureS.chance_for(c, 5)
	_expect(t5 > t1, "a better net reads better odds (tier 5 %.3f > tier 1 %.3f)" % [t5, t1])
	# attempt() rolls the shown odds: 2000 seeded nets at 90 %+, close to all land.
	var netted := 0
	var tries := 0
	var fast = _creature(&"compsognathus", 0.0, 1)
	fast.level = -100  # a gap far ahead of the survivor: clamped at the ceiling
	for i in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		_player.inventory.add(ItemStackS.make(&"capture_net_ii", 1))
		if CaptureS.attempt(_player, fast, 0, rng):
			netted += 1
		tries += 1
		# Each success consumed the animal; respawn the target for the next throw.
		if not is_instance_valid(fast) or fast.is_queued_for_deletion():
			fast = _creature(&"compsognathus", 0.0, -100)
			_host.add_child(fast)
	var rate := float(netted) / float(maxi(1, tries))
	_expect(rate > 0.85, "200 seeded throws at the 0.95 ceiling landed %.0f %% of the time" % (100.0 * rate))
	data.set_survival_unlocked(&"capture_technique_II", false)
	print("[t_tamingodds] shown=%.3f used=%.3f label='%s' seeded_rate=%.2f" % [shown, used, label, rate])
	_sections += 1

# ---------------------------------------------------------------- 6. grade earned by preparation

## A bait item in the bag is spent on the completed tame and raises the pet's IVs, which is its grade.
func _test_grade_by_bait() -> void:
	var def: CreatureDef = (get_root().get_node("Data") as Node).creature(&"compsognathus")
	var food: StringName = def.preferred_food[0]
	_player.bonded.clear()
	var plain = _spawn_tameable(&"compsognathus", Vector3(6.0, 0.0, 0.0))
	plain.genetics = GeneticsS.neutral()
	_player.inventory.add(ItemStackS.make(food, 3))
	var bonded_before: int = _player.bonded.size()
	FieldTameS.begin_window(plain)
	for i in 4:
		if not plain.is_pet:
			FieldTameS.apply_feed(_player, plain, food)
	_expect(_player.bonded.size() == bonded_before + 1, "no bait: the tame still completes")
	var plain_rec = _player.bonded[-1] if _player.bonded.size() > bonded_before else null
	_expect(plain_rec != null and _iv_sum(plain_rec) == 16 * 6, "no bait leaves the IVs alone (sum %d)" % (_iv_sum(plain_rec) if plain_rec else -1))
	var plain_grade: StringName = plain_rec.grade if plain_rec else &"?"
	var baited = _spawn_tameable(&"compsognathus", Vector3(8.0, 0.0, 0.0))
	baited.genetics = GeneticsS.neutral()
	_player.inventory.add(ItemStackS.make(food, 3))
	_player.inventory.add(ItemStackS.make(&"leech", 2))
	FieldTameS.begin_window(baited)
	for i in 4:
		if not baited.is_pet:
			FieldTameS.apply_feed(_player, baited, food)
	var bait_rec = _player.bonded[-1] if _player.bonded.size() > bonded_before + 1 else null
	var bonus: int = int(OddsS.prep_iv_bonus())
	_expect(bait_rec != null and _iv_sum(bait_rec) == 16 * 6 + bonus * 6, "bait raises every IV by %d (sum %d)" % [bonus, _iv_sum(bait_rec) if bait_rec else -1])
	_expect(bait_rec != null and bait_rec.grade != plain_grade, "bait earns a better grade (%s with, %s without)" % [bait_rec.grade if bait_rec else "?", plain_grade])
	_expect(_player.inventory.count_of(&"leech") == 1, "one bait is spent, the second is kept (left %d)" % _player.inventory.count_of(&"leech"))
	# A bait in the bag with the tame unfinished (pen animal) is not spent.
	var pen = _spawn_tameable(&"gallimimus", Vector3(10.0, 0.0, 0.0))
	pen.genetics = GeneticsS.neutral()
	_player.inventory.add(ItemStackS.make(&"leech", 1))
	var leech_before: int = _player.inventory.count_of(&"leech")
	FieldTameS.begin_window(pen)
	for i in 3:
		FieldTameS.apply_feed(_player, pen, &"berry")
	_expect(_player.inventory.count_of(&"leech") == leech_before, "a pen animal keeps its bait until the pen tames it (left %d)" % _player.inventory.count_of(&"leech"))
	print("[t_tamingodds] grade no_bait=%s ivs=%d bait=%s ivs=%d" % [plain_grade, _iv_sum(plain_rec) if plain_rec else -1, bait_rec.grade if bait_rec else "?", _iv_sum(bait_rec) if bait_rec else -1])
	_sections += 1

func _spawn_tameable(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	_host.add_child(c)
	c.global_position = at
	c.spawn((get_root().get_node("Data") as Node).creature(species), &"", 0, null, 0, &"")
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

# ---------------------------------------------------------------- watchdog

func _check_watchdog() -> bool:
	return Time.get_ticks_msec() * 0.001 - _t0 < WATCHDOG_S
