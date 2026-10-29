extends SceneTree
## ALPHAS acceptance (owner 2026-10-28: "alpha dinosaurs with special loot but are on steroids and
## really hard to kill"). The spawn rate over many seeded rolls sits inside its data chance; an alpha's
## stats beat a twin's by the ai.json alpha modifier and its tactic knobs follow the class profile's
## alpha block; its carcass guarantees the rare rows, a rare trait on every part and the trophy, and the
## kill pays the XP multiplier; a packmate inside the aura radius is buffed and outside it is not; the
## name keeps "Alpha" with the nature as a chip under it, never in the name.
## Run: Godot --headless --path game --script res://tests/t_alphas.gd -> "[t_alphas] PASS".

const CREATURE_SCENE := "res://scenes/creatures/creature.tscn"

var _fails: PackedStringArray = []
var _started = false
var _sections = 0
var data: Node
var CG: GDScript
var NR: GDScript
var LR: GDScript
var BL: GDScript
var PI: GDScript
var INV: GDScript
var FT: GDScript
var CS: GDScript
var TP: GDScript
var LT: GDScript
var AC: GDScript
var ISS: GDScript
var IS: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	var game = root.get_node_or_null("Game")
	if game:
		game.debug_overlay = false
	CG = load("res://scripts/creatures/creature_genetics.gd")
	NR = load("res://scripts/creatures/brains/brain_natures.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	BL = load("res://scripts/gather/butcher_loot.gd")
	PI = load("res://scripts/creatures/brains/pack_index.gd")
	INV = load("res://scripts/items/inventory.gd")
	FT = load("res://scripts/pets/field_tame.gd")
	CS = load("res://scripts/pets/capture_system.gd")
	TP = load("res://scripts/world/taming_pen.gd")
	LT = load("res://scripts/gather/loot_tables.gd")
	AC = load("res://scripts/ui/alpha_chip.gd")
	ISS = load("res://scripts/items/item_stack.gd")
	IS = load("res://scripts/items/inventory.gd")
	_run()
	return false

func _run() -> void:
	_test_spawn_rate()
	await _test_stats()
	_test_loot()
	await _test_corpse()
	await _test_aura()
	await _test_name()
	_test_alpha_tag()
	await _test_no_tame()
	await _test_alpha_pool()
	var want = 9
	_expect(_sections == want, "only %d of %d sections completed" % [_sections, want])
	if _fails.is_empty():
		print("[t_alphas] PASS")
		quit(0)
	else:
		print("[t_alphas] FAIL count=%d" % _fails.size())
		quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_alphas] FAIL %s" % what)

func _rng(seed_v: int) -> RandomNumberGenerator:
	var r = RandomNumberGenerator.new()
	r.seed = seed_v
	return r

func _rules() -> Dictionary:
	return data.creature_ai["alpha"]

func _test_spawn_rate() -> void:
	var chance = float(_rules()["chance_per_group"])
	var n = 20000
	var hits = 0
	for i in n:
		var idx: int = CG.alpha_pick(3, _rng(i))
		_expect(idx == -1 or idx == 0, "at most one alpha, member 0 (got %d)" % idx)
		hits += 1 if idx == 0 else 0
	var rate = float(hits) / float(n)
	# 3 sigma of a binomial at n = 20000 is about 0.6 % for p = 0.08.
	var tol = 3.0 * sqrt(chance * (1.0 - chance) / float(n))
	_expect(absf(rate - chance) <= tol, "alpha rate %.4f within %.4f of %.3f" % [rate, tol, chance])
	_expect(CG.alpha_pick(3, _rng(99)) == CG.alpha_pick(3, _rng(99)), "seeded alpha roll is deterministic")
	_expect(CG.alpha_pick(0, _rng(1)) == -1, "an empty group has no alpha")
	print("[t_alphas] spawn rate %.4f (chance %.3f)" % [rate, chance])
	_sections += 1

func _spawn(alpha: bool, at: Vector3, pack: int = 0) -> Variant:
	var c = load(CREATURE_SCENE).instantiate()
	root.add_child(c)
	c.global_position = at
	c.genetics = CG.neutral()
	c.alpha_spawn = alpha
	c.spawn(data.creature(&"deinonychus"), &"", pack)
	return c

func _test_stats() -> void:
	var n = _spawn(false, Vector3(0, 0, 0))
	var a = _spawn(true, Vector3(40, 0, 0))
	await process_frame
	_expect(a.is_alpha() and not n.is_alpha(), "alpha_spawn makes an alpha")
	var top: float = CG.size_range_for(a.def).y
	_expect(a.size_scale() > top, "alpha is bigger than any normal roll (%.3f > %.3f)" % [a.size_scale(), top])
	# ALPHATAG (owner 2026-10-29: "The alpha animals are larger"): the rule's floor is above EVERY normal
	# roll, not just this species', and the alpha's range is a single knob in ai.json.
	var lo := float((_rules()["size_range"] as Array)[0])
	var hi := float((_rules()["size_range"] as Array)[1])
	var top_all := 0.0
	var worst := &""
	for id in data.creatures:
		var d: CreatureDef = data.creatures[id]
		var t: float = CG.size_range_for(d).y
		if t > top_all:
			top_all = t
			worst = id
	_expect(lo > top_all, "the alpha floor %.2f beats every species' top roll (%.2f, %s)" % [lo, top_all, worst])
	_expect(hi >= lo and hi <= CG.SIZE_LIMIT.y, "the alpha range %.2f-%.2f holds inside the save limit %.1f" % [lo, hi, CG.SIZE_LIMIT.y])
	var min_alpha := 2.0
	for i in 40:
		var g: CreatureGenetics = CG.for_species(a.def, _rng(i))
		g.make_alpha(_rng(100 + i))
		min_alpha = minf(min_alpha, g.size)
		_expect(g.size >= lo and g.size <= hi, "#%d a made alpha lands in %.2f-%.2f (%.3f)" % [i, lo, hi, g.size])
	_expect(min_alpha > top_all, "every made alpha outgrows every normal roll (%.2f > %.2f)" % [min_alpha, top_all])
	var st: Dictionary = _rules()["stats"]
	var sf = func(stat: StringName) -> float: return a.genetics.size_factor(stat)
	var hp_ratio = a.health.max_hp / n.health.max_hp
	_expect(absf(hp_ratio - float(st["health"]) * sf.call(&"health")) < 0.001, "alpha HP x %.2f x size (got %.3f)" % [float(st["health"]), hp_ratio])
	_expect(hp_ratio >= float(st["health"]), "alpha HP at least the modifier above normal")
	var atk_ratio = a.attack_for() / n.attack_for()
	_expect(absf(atk_ratio - float(st["melee_attack"]) * sf.call(&"melee_attack")) < 0.001, "alpha attack x modifier x size (got %.3f)" % atk_ratio)
	var def_ratio = a.defense_for() / n.defense_for()
	_expect(absf(def_ratio - float(st["melee_defense"])) < 0.001, "alpha defense x modifier (got %.3f)" % def_ratio)
	var spd_ratio = a.move_speed_mps() / n.move_speed_mps()
	_expect(absf(spd_ratio - float(st["speed"]) * sf.call(&"speed")) < 0.001 and spd_ratio > 1.0, "alpha speed x modifier x size, still faster (got %.3f)" % spd_ratio)
	# Class profile modifier: ai.json archetypes.pack_flanker.tactics.alpha.
	var mod: Dictionary = data.creature_ai["archetypes"]["pack_flanker"]["tactics"]["alpha"]
	for knob in ["tactic_cooldown_mult", "tactic_w_pounce", "tactic_w_charge", "tactic_w_combo"]:
		var r = a.nature_knob(knob, 1.0) / n.nature_knob(knob, 1.0)
		_expect(absf(r - float(mod[knob])) < 0.001, "alpha %s x %.2f (got %.3f)" % [knob, float(mod[knob]), r])
	_expect(a.nature_knob("aggro_radius_mult", 1.0) == n.nature_knob("aggro_radius_mult", 1.0), "non-tactic knobs unchanged")
	# Visibly distinct: darker and richer than the same genes as a normal animal, eyes brighter.
	_expect(a.genetics.coloration.val < n.genetics.coloration.val and a.genetics.coloration.sat > n.genetics.coloration.sat, "alpha is darker and richer (val %.2f sat %.2f)" % [a.genetics.coloration.val, a.genetics.coloration.sat])
	var ea = a.view.get_node_or_null("Eyes")
	var en = n.view.get_node_or_null("Eyes")
	_expect(ea != null and en != null and ea.glow > en.glow and ea.eye_material.emission_energy_multiplier > en.eye_material.emission_energy_multiplier, "alpha eyes glow stronger")
	_expect(a.kill_xp(a.def.tier) == int(round(float(4 + a.def.tier / 5) * float(_rules()["xp_mult"]))) and a.kill_xp(a.def.tier) > n.kill_xp(n.def.tier), "alpha kill pays the XP multiplier (%d vs %d)" % [a.kill_xp(a.def.tier), n.kill_xp(n.def.tier)])
	# A tame keeps size and colours but drops the steroids (PetStats has no alpha term).
	a.is_pet = true
	_expect(a.alpha_stat_mult(&"health") == 1.0 and a.pack_aura_mult("attack") == 1.0, "a pet gets no alpha stat buff")
	a.is_pet = false
	n.queue_free()
	a.queue_free()
	_sections += 1

func _test_loot() -> void:
	# The rare row: a 0.01 % row must drop every time on an alpha carcass, almost never on a normal one.
	var base = [{"id": "raptor_meat", "min": 2, "max": 3}, {"id": "raptor_bone", "min": 1, "max": 1}]
	var rare = [{"id": "raptor_hide", "min": 1, "max": 1, "chance": 0.0001}]
	var normal_rares = 0
	for i in 200:
		var res: Dictionary = LR.roll_carcass(base, rare, 30, &"", 5, 0, false, _rng(i), true)
		_expect((res["rares"] as Array).has(&"raptor_hide"), "#%d alpha carcass guarantees the rare row" % i)
		BL.alpha_extras(res, 30, _rng(500 + i))
		var trophies = 0
		for stack in res["stacks"]:
			if stack.def_id == &"alpha_trophy":
				trophies += stack.count
				continue
			var traits = INV.traits(stack)
			var has_rare = false
			for k in traits:
				has_rare = has_rare or traits[k] == true
			_expect(has_rare, "#%d alpha part %s carries a rare trait (%s)" % [i, stack.def_id, traits])
		_expect(trophies == int(_rules()["loot"]["trophy_count"]), "#%d alpha carcass has the trophy" % i)
		var plain: Dictionary = LR.roll_carcass(base, rare, 30, &"", 5, 0, false, _rng(i), false)
		normal_rares += (plain["rares"] as Array).size()
		for stack in plain["stacks"]:
			_expect(stack.def_id != &"alpha_trophy", "#%d a normal carcass has no trophy" % i)
	_expect(normal_rares <= 2, "a normal carcass keeps the shipped odds (%d of 200)" % normal_rares)
	_expect(data.item(&"alpha_trophy") != null, "alpha_trophy is an item")
	_sections += 1

func _test_corpse() -> void:
	var a = _spawn(true, Vector3(80, 0, 0))
	await process_frame
	a.health.take_damage(a.health.max_hp + 1.0, null)
	await process_frame
	var corpse = null
	for n in root.get_children():
		if n.has_method("cut_part") and n._owner == a:
			corpse = n
	_expect(corpse != null and corpse.alpha, "an alpha's corpse is marked alpha")
	if corpse != null:
		_expect(corpse.loot.count_of(&"alpha_trophy") >= 1, "an alpha's corpse holds the alpha trophy")
		corpse.queue_free()
	a.queue_free()
	_sections += 1

func _test_aura() -> void:
	var pack = 7777
	var a = _spawn(true, Vector3(200, 0, 0), pack)
	var mate = _spawn(false, Vector3(205, 0, 0), pack)
	var stranger = _spawn(false, Vector3(206, 0, 0), pack + 1)
	await physics_frame
	PI.invalidate()
	var aura: Dictionary = _rules()["aura"]
	_expect(absf(mate.pack_aura_mult("attack") - float(aura["attack"])) < 0.0001, "packmate inside %.0f m gets the attack buff (%.3f)" % [float(aura["radius_m"]), mate.pack_aura_mult("attack")])
	_expect(absf(mate.pack_aura_mult("speed") - float(aura["speed"])) < 0.0001 and absf(mate.pack_aura_mult("defense") - float(aura["defense"])) < 0.0001, "packmate gets speed and defense buffs")
	var base_atk = mate.stat_value(&"melee_attack") * mate.nature_knob("damage_dealt_mult", 1.0)
	_expect(absf(mate.attack_for() / base_atk - float(aura["attack"])) < 0.001, "the buff reaches attack_for")
	_expect(a.pack_aura_mult("attack") == 1.0, "the alpha does not buff itself")
	_expect(stranger.pack_aura_mult("attack") == 1.0, "another pack is not buffed")
	mate.global_position = a.global_position + Vector3(float(aura["radius_m"]) + 3.0, 0, 0)
	await physics_frame
	PI.invalidate()
	_expect(mate.pack_aura_mult("attack") == 1.0 and mate.pack_aura_mult("speed") == 1.0, "the buff ends outside the radius")
	mate.global_position = a.global_position + Vector3(2, 0, 0)
	await physics_frame
	PI.invalidate()
	a.health.take_damage(a.health.max_hp + 1.0, null)
	await physics_frame
	PI.invalidate()
	_expect(mate.pack_aura_mult("attack") == 1.0, "a dead alpha buffs nobody")
	for c in [a, mate, stranger]:
		c.queue_free()
	for n in root.get_children():
		if n.has_method("cut_part"):
			n.queue_free()
	_sections += 1

func _test_name() -> void:
	var lone = _spawn(true, Vector3(300, 0, 0))
	var plain = _spawn(false, Vector3(330, 0, 0))
	lone.nature = &"timid"
	plain.nature = &"timid"
	await process_frame
	# ALPHATAG (owner 2026-10-29): "Alpha" is a PREFIX TAG, not a word in the name.
	var t: String = NR.display_title(lone)
	_expect(not t.begins_with("Alpha ") and not t.contains("Alpha"), "a lone alpha's NAME carries no \"Alpha\" word (%s)" % t)
	_expect(t.contains("Deinonychus"), "the name is the species (%s)" % t)
	_expect(not NR.display_title(plain).contains("Alpha"), "a lone normal animal is not (%s)" % NR.display_title(plain))
	var chip: String = NR.tag_for(lone)
	_expect(chip != "" and not t.to_lower().contains(chip.to_lower()), "the nature is a chip (%s), not in the name (%s)" % [chip, t])
	_expect(NR.tagged_title(lone) == "[ALPHA] %s" % t, "the plain-text title prefixes the tag (%s)" % NR.tagged_title(lone))
	_expect(NR.tagged_title(plain) == NR.display_title(plain), "a normal animal's plain-text title has no tag (%s)" % NR.tagged_title(plain))
	_expect(NR.alpha_tag(lone) == "ALPHA" and NR.alpha_tag(plain) == "", "alpha_tag reads '%s' / '%s'" % [NR.alpha_tag(lone), NR.alpha_tag(plain)])
	lone.queue_free()
	plain.queue_free()
	_sections += 1

## ALPHATAG (owner 2026-10-29: "Alpha should be a tag in front of the name (prefix tag)"): the world
## plate draws a gold "ALPHA" chip BEFORE the name (the name label starts to its right), a normal
## animal draws none, and the target plate's drawn rects carry the tag ahead of the name.
func _test_alpha_tag() -> void:
	_expect(AC != null and AC.text_for(true) == "ALPHA" and AC.text_for(false) == "", "the tag text is ALPHA")
	var font: Font = ThemeDB.fallback_font
	_expect(AC.rect_at(font, Vector2.ZERO, false).has_area() == false and AC.rect_at(font, Vector2(10, 4), true).size.x > 0.0, "the drawn tag box is empty for a normal animal and real for an alpha")
	_expect(AC.prefix_width(false) == 0.0 and AC.prefix_width(true) > 0.0, "a normal animal takes no prefix width (%.1f / %.1f)" % [AC.prefix_width(false), AC.prefix_width(true)])
	var made = AC.make(false)
	_expect(not made.visible, "a normal animal's chip is hidden")
	made.free()
	var plates: Node = load("res://scripts/ui/creature_plates.gd").new()
	root.add_child(plates)
	var hero: Node = load("res://scenes/player/player.tscn").instantiate()
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(hero)
	hero.global_position = Vector3(400, 1, 0)
	var a = _spawn(true, Vector3(400, 0, 0))
	var n = _spawn(false, Vector3(430, 0, 0))
	await process_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(400, 6, 12)
	cam.look_at(Vector3(400, 1, 0))
	cam.current = true
	var ae: Dictionary = plates._ensure_entry(a)
	plates._emphasis_id = a.get_instance_id()
	plates._update_entry(ae, a, cam, hero, 6.0, 0.016)
	var ne: Dictionary = plates._ensure_entry(n)
	plates._emphasis_id = n.get_instance_id()
	plates._update_entry(ne, n, cam, hero, 6.0, 0.016)
	var achip = ae.get("alpha_chip", null)
	var aline = ae.get("line1", null)
	var nchip = ne.get("alpha_chip", null)
	var nline = ne.get("line1", null)
	print("[t_alphas] plate: alpha chip '%s' at %s, name at %s ('%s'); normal chip %s" % [
		achip.chip_text() if achip else "<none>", achip.position if achip else Vector2.ZERO,
		aline.position if aline else Vector2.ZERO, aline.text if aline else "", nchip.visible if nchip else "missing"])
	_expect(achip != null and achip.visible and achip.chip_text() == "ALPHA", "the alpha's plate draws the ALPHA tag (chip %s)" % (achip.chip_text() if achip else "missing"))
	_expect(achip != null and aline != null and aline.position.x >= achip.position.x + achip.size.x, "the tag is in FRONT of the name (chip ends %.1f, name starts %.1f)" % [achip.end_x() if achip else -1.0, aline.position.x if aline else -1.0])
	_expect(achip != null and aline != null and achip.position.y + achip.size.y <= aline.position.y + 16.0 + 1.0, "the tag rides the name's row, not under it")
	_expect(aline != null and not aline.text.contains("Alpha"), "the plate's name carries no Alpha word ('%s')" % (aline.text if aline else ""))
	_expect(nchip != null and not nchip.visible and nline != null and is_equal_approx(nline.position.x, 8.0), "a normal animal has no tag and its name starts at the margin")
	# The HUD's drawn target plate uses the same geometry: the tag's rect on the name's row, ahead of it.
	var HH: GDScript = load("res://scripts/ui/hunt_hud.gd")
	var name_pos := Vector2(100.0, 60.0)
	var tpos: Vector2 = HH.alpha_tag_pos(name_pos, true)
	var trect: Rect2 = AC.rect_at(font, tpos, true)
	_expect(trect.has_area() and is_equal_approx(tpos.x, name_pos.x) and trect.size.x > 0.0, "the target plate's tag starts at the name's left (%.1f vs %.1f)" % [tpos.x, name_pos.x])
	_expect(absf((tpos.y + trect.size.y) - (name_pos.y + 2.0)) <= 3.0, "the tag rides the name's baseline row (tag bottom %.1f, name y %.1f)" % [tpos.y + trect.size.y, name_pos.y])
	_expect(HH.alpha_tag_pos(name_pos, false) == name_pos, "the target plate places no tag for a normal animal")
	# The name is the species alone (the tag is the chip), never "Alpha Deinonychus".
	_expect(aline != null and aline.text.contains("Deino"), "the plate still names the species ('%s')" % (aline.text if aline else ""))
	cam.queue_free()
	plates.queue_free()
	hero.queue_free()
	a.queue_free()
	n.queue_free()
	_sections += 1

## ALPHATAG (owner 2026-10-29: "The alpha animals are larger, not tamable/capturable"): every capture
## path refuses an alpha with the same message, and no tame completes.
func _test_no_tame() -> void:
	var p: Node = load("res://scenes/player/player.tscn").instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	p.global_position = Vector3(-400, 1, 0)
	var a = _spawn(true, Vector3(-400, 0, 0))
	var n = _spawn(false, Vector3(-404, 0, 0))
	await process_frame
	# Both are collapsed and inside the window's health rule: only the alpha is refused.
	for c in [a, n]:
		c.health.hp = c.health.max_hp * 0.1
		c.is_capturable = true
	_expect(FT.capture_window(n), "a normal animal at 10 %% HP is in the capture window")
	_expect(not FT.capture_window(a), "an alpha at 10 %% HP is NOT in the capture window")
	_expect(not FT.can_attempt(a), "the feeding tame refuses an alpha")
	_expect(FT.alpha_lock(a) == FT.ALPHA_REFUSAL and FT.alpha_lock(n) == "", "alpha_lock reads '%s' / '%s'" % [FT.alpha_lock(a), FT.alpha_lock(n)])
	_expect(FT.refuse_message(a) == FT.ALPHA_REFUSAL, "the refusal message is '%s' (got '%s')" % [FT.ALPHA_REFUSAL, FT.refuse_message(a)])
	# The net: the capture attempt refuses, the bag gains nothing, and the animal stays.
	var before: int = p.inventory.count_of(&"captured_animal") if p.inventory.has_method("count_of") else 0
	var netted: bool = CS.attempt(p, a, 1, _rng(3))
	_expect(not netted, "CaptureSystem.attempt refuses an alpha even with a forced success")
	var after: int = p.inventory.count_of(&"captured_animal") if p.inventory.has_method("count_of") else 0
	_expect(after == before and is_instance_valid(a) and not a.is_queued_for_deletion(), "the alpha is not bagged and not freed")
	_expect(not a.capturable(), "Creature.capturable() is false for an alpha")
	# The net, through the hunt overlay the survivor actually presses (Hunt.use_net): the refusal is the
	# alpha rule, not the "weaken it to 30 %" hint, and the throw is never made.
	p.hunt.start(a)
	p.hunt.use_net()
	_expect(p.hunt.last_notice == FT.ALPHA_REFUSAL, "Hunt.use_net refuses an alpha with '%s' (got '%s')" % [FT.ALPHA_REFUSAL, p.hunt.last_notice])
	_expect(p.hunt.target == a and is_instance_valid(a) and not a.is_queued_for_deletion(), "the netted alpha is still the target and still alive")
	p.hunt.stop()
	# The field tame action (the tap path).
	var started: bool = p.actions.begin_field_tame(a) if p.get("actions") else false
	_expect(not started and p.tame_target == null, "the field tame action refuses an alpha")
	# The pen: a stack carrying an alpha's genome never goes in, and the refusal is the alpha rule.
	var stack = ISS.make(&"captured_animal", 1, {"species": "deinonychus", "level": 5, "genetics": a.genetics.to_dict()})
	_expect(FT.alpha_stack(stack), "an alpha's cage stack is recognised by its genome")
	_expect(TP.alpha_refusal(stack) == FT.ALPHA_REFUSAL, "the pen refuses an alpha stack ('%s')" % TP.alpha_refusal(stack))
	var plain_stack = ISS.make(&"captured_animal", 1, {"species": "deinonychus", "level": 5, "genetics": n.genetics.to_dict()})
	_expect(not FT.alpha_stack(plain_stack) and TP.alpha_refusal(plain_stack) == "", "a normal animal's cage is not refused by the alpha rule")
	# A normal animal still tames through the same entry points.
	_expect(FT.can_attempt(n) and FT.refuse_message(n) != FT.ALPHA_REFUSAL, "a normal animal keeps its normal capture path")
	a.queue_free()
	n.queue_free()
	p.queue_free()
	_sections += 1

## ALPHATAG (owner 2026-10-29: "special loot pools specific to alpha animals"): loot_tables.json
## "alpha" rows drop from an alpha carcass only; a normal carcass never yields one.
func _test_alpha_pool() -> void:
	var pool: Array = LT.alpha_pool(&"deinonychus")
	_expect(not pool.is_empty(), "the default alpha pool has rows (%d)" % pool.size())
	var ids: Array = LT.alpha_pool_ids()
	_expect(not ids.is_empty(), "the alpha pool names items (%s)" % [ids])
	for id in ids:
		_expect(data.item(StringName(str(id))) != null, "alpha-pool item %s exists" % id)
	var own: Array = LT.alpha_pool(&"tyrannosaurus")
	_expect(own != pool and not own.is_empty(), "a species override replaces the default pool (%d rows)" % own.size())
	# No normal butchering table may name an alpha-pool item.
	for sp in data.butcher_tables:
		var t: Dictionary = data.butcher_tables[sp]
		for row in t.get("base", []) + t.get("rare", []):
			_expect(not ids.has(StringName(str(row.get("id", "")))), "normal table %s never holds the alpha item %s" % [sp, row.get("id", "")])
	# Drops: every alpha carcass yields pool items, a normal one never does.
	var seen := {}
	for i in 60:
		var r := _rng(900 + i)
		var drops: Array = LR.roll_alpha_pool(&"deinonychus", 12, r)
		_expect(not drops.is_empty(), "#%d the alpha pool drops something" % i)
		for st in drops:
			_expect(ids.has(st.def_id), "#%d an alpha drop is a pool item (%s)" % [i, st.def_id])
			seen[st.def_id] = true
		var base = [{"id": "raptor_meat", "min": 2, "max": 3}]
		var plain: Dictionary = LR.roll_carcass(base, [], 12, &"", 5, 0, false, _rng(400 + i), false)
		for st in plain["stacks"]:
			_expect(not ids.has(st.def_id), "#%d a normal carcass never drops %s" % [i, st.def_id])
	# Through alpha_extras: the pool rides on top of the trophy, and a normal res gets nothing.
	var total := 0
	for i in 40:
		var res: Dictionary = LR.roll_carcass([{"id": "raptor_meat", "min": 2, "max": 3}], [], 20, &"", 5, 0, false, _rng(1200 + i), true)
		var before: int = (res["stacks"] as Array).size()
		BL.alpha_extras(res, 20, _rng(1300 + i), &"deinonychus")
		var added := (res["stacks"] as Array).size() - before
		_expect(added >= 1, "#%d alpha_extras adds the alpha pool (%d stacks)" % [i, added])
		total += added
		var plain: Dictionary = LR.roll_carcass([{"id": "raptor_meat", "min": 2, "max": 3}], [], 20, &"", 5, 0, false, _rng(1400 + i), false)
		var n_before: int = (plain["stacks"] as Array).size()
		var plain_before := n_before
		for st in plain["stacks"]:
			_expect(not ids.has(st.def_id), "#%d a normal carcass holds no alpha item (%s)" % [i, st.def_id])
		_expect(plain["stacks"].size() == plain_before, "the normal roll is untouched")
	# Through the corpse that really dies (Creature -> Corpse -> ButcherLoot.roll_into), so nothing is
	# stubbed: an alpha carcass carries pool items, a normal carcass of the same species never does.
	var hero: Node = load("res://scenes/player/player.tscn").instantiate()
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(hero)
	hero.global_position = Vector3(600, 1, 0)
	var alpha_body = _spawn(true, Vector3(600, 0, 0))
	var plain_body = _spawn(false, Vector3(610, 0, 0))
	await process_frame
	for body in [alpha_body, plain_body]:
		body.health.take_damage(body.health.max_hp + 1.0, null)
	await process_frame
	var alpha_corpse = null
	var plain_corpse = null
	for n in root.get_children():
		if n.has_method("cut_part") and n._owner == alpha_body:
			alpha_corpse = n
		if n.has_method("cut_part") and n._owner == plain_body:
			plain_corpse = n
	_expect(alpha_corpse != null and plain_corpse != null, "both carcasses exist")
	if alpha_corpse != null:
		var has_pool := false
		for i in alpha_corpse.loot.slot_count:
			var st = alpha_corpse.loot.slots[i]
			if st != null and ids.has(st.def_id):
				has_pool = true
		_expect(has_pool, "a real alpha carcass holds alpha-pool loot")
		alpha_corpse.queue_free()
	if plain_corpse != null:
		for i in plain_corpse.loot.slot_count:
			var st = plain_corpse.loot.slots[i]
			_expect(st == null or not ids.has(st.def_id), "a real normal carcass holds no alpha-pool loot (%s)" % (st.def_id if st else ""))
		plain_corpse.queue_free()
	alpha_body.queue_free()
	plain_body.queue_free()
	hero.queue_free()
	print("[t_alphas] alpha pool: %d items over 40 carcasses (%s)" % [total, seen.keys()])
	_expect(seen.size() >= mini(2, ids.size()), "both pool items can drop (%s)" % [seen.keys()])
	_sections += 1
