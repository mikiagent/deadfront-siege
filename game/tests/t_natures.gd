extends SceneTree
## NATURES acceptance (owner 2026-10-28). A creature's nature changes its AI BEHAVIOUR, layers on top
## of the ai.json archetype and temperament, and shows as a prefix on its name ("Timid Velociraptor").
## Each section MEASURES the brain's own decision, not a copied constant:
##   Timid flees at more HP than the default, Brave's ridden pet keeps fighting below the default
##   retreat, Aggressive engages unprovoked inside its radius, Loyal follows closer, Stubborn needs
##   more feeds and ignores fear, Docile needs fewer feeds and deals less damage; the roll from a
##   spawn seed is deterministic, the name reads nature -> variant (Alpha) -> species, and an old pet
##   record with no nature loads with a deterministic one and keeps everything else; and the nature is a
##   TAG under the name (owner 2026-10-28), never a word in it, on the world plate, the Animals screen
##   and the pet radial.
## Run: Godot --headless --path game --script res://tests/t_natures.gd -> "[t_natures] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before the autoloads exist.

const CREATURE_SCENE := "res://scenes/creatures/creature.tscn"

var _fails: PackedStringArray = []
var _started := false
var _sections := 0
var data: Node
var game: Node
var NR: GDScript ## creature_natures.gd
var PR: GDScript ## pet_record.gd
var FT: GDScript ## field_tame.gd
var CA: GDScript ## creature_attack.gd

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	game = root.get_node_or_null("Game")
	if game:
		game.time_of_day = 0.4
		game.debug_overlay = false
	NR = load("res://scripts/creatures/brains/brain_natures.gd")
	PR = load("res://scripts/pets/pet_record.gd")
	FT = load("res://scripts/pets/field_tame.gd")
	CA = load("res://scripts/combat/creature_attack.gd")
	_run()
	return false

func _run() -> void:
	_test_table()
	await _test_roll()
	await _test_name()
	await _test_nature_tag()
	_test_old_save()
	await _test_wild_timid_flees_sooner()
	await _test_brave_ridden_keeps_fighting()
	await _test_aggressive_engages()
	await _test_stubborn_ignores_fear()
	await _test_loyal_follows_closer()
	await _test_taming_numbers()
	await _test_pen_wait()
	_test_docile_damage()
	_test_pet_keeps_nature()
	_finish()

func _finish() -> void:
	var want := 14
	_expect(_sections == want, "only %d of %d test sections completed (a runtime error aborted the rest)" % [_sections, want])
	if _fails.is_empty():
		print("[t_natures] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_natures] FAIL %s" % f)
		print("[t_natures] FAIL count=%d" % _fails.size())
		quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_natures] FAIL %s" % what)

func _creature(id: StringName, at: Vector3 = Vector3.ZERO, nature: StringName = &"", pack: int = 0) -> Node:
	var c: Node = load(CREATURE_SCENE).instantiate()
	root.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id), &"", pack)
	# Tests pin the nature instead of rolling one ("": no nature at all = today's behaviour).
	c.nature = nature
	return c

# ---------------------------------------------------------------- the table and the roll

func _test_table() -> void:
	var t: Dictionary = NR.table()
	var rows: Dictionary = NR.nature_rows()
	var want := ["timid", "brave", "aggressive", "loyal", "stubborn", "docile"]
	for id in want:
		_expect(rows.has(id), "natures.json has no '%s' nature" % id)
		# Owner 2026-10-28: the `loyal` id is shown as "Territorial"; every other label is its id capitalised.
		var want_label := "Territorial" if String(id) == "loyal" else String(id).capitalize()
		_expect(NR.label(StringName(id)) == want_label, "%s label reads '%s'" % [id, NR.label(StringName(id))])
	_expect(NR.ids().size() == 6, "six natures in the table (got %d)" % NR.ids().size())
	# The neutral row: an animal whose nature says nothing behaves exactly as before.
	var d: Dictionary = NR.knobs(&"")
	for k in ["flee_threshold_mult", "retreat_threshold_mult", "aggro_radius_mult", "follow_dist_mult", "guard_radius_mult", "feeds_mult", "tame_window_mult", "pen_time_mult", "damage_dealt_mult"]:
		_expect(is_equal_approx(float(d.get(k, -1.0)), 1.0), "default %s is %s, want 1.0" % [k, d.get(k)])
	for k in ["auto_engage", "protect_owner", "fear_immune"]:
		_expect(not bool(d.get(k, true)), "default %s is true" % k)
	_expect(float(d.get("protect_rider_below_hp", -1.0)) <= 0.0, "default protect_rider_below_hp is %s, want 0" % d.get("protect_rider_below_hp"))
	# Behaviour only: no nature touches HP, attack or speed.
	for id in NR.ids():
		var kn: Dictionary = NR.knobs(id)
		for k in ["hp_mult", "attack_mult", "speed_mult"]:
			_expect(not kn.has(k), "%s carries a stat multiplier %s (natures are behaviour only)" % [id, k])
	_sections += 1

func _test_roll() -> void:
	await process_frame
	# A T. rex is never Timid, and Aggressive is a predator's nature first.
	var rex_ok: Array[StringName] = NR.allowed_for(&"tyrant")
	_expect(not (&"timid" in rex_ok), "a tyrant may roll Timid: %s" % [rex_ok])
	var grazer_ok: Array[StringName] = NR.allowed_for(&"horned_charger")
	_expect(&"aggressive" in grazer_ok, "a grazer cannot roll Aggressive at all")
	_expect(NR.weight_for(&"aggressive", &"horned_charger") < NR.weight_for(&"timid", &"horned_charger"), "Aggressive is not rarer than Timid for a grazer")
	_expect(is_equal_approx(NR.weight_for(&"aggressive", &"pack_raptor"), float((NR.table().get("weights", {}) as Dictionary).get("aggressive", 0.0))), "Aggressive is discounted for a raptor too")
	# Deterministic: the same spawn seed rolls the same nature every time.
	var key: String = NR.spawn_key(&"velociraptor", Vector3(12, 1, -4), 7)
	var first: StringName = NR.roll(key, &"pack_raptor")
	var same := true
	for i in 5:
		same = same and NR.roll(key, &"pack_raptor") == first
	_expect(same and first != &"", "the same spawn seed rolled %s then something else" % first)
	# Spread: across many spawns, every allowed nature comes up, Docile and Timid together are the
	# most common pair, and no forbidden nature is ever picked.
	var counts := {}
	for i in 400:
		var n: StringName = NR.roll("spread#%d" % i, &"tyrant")
		counts[str(n)] = int(counts.get(str(n), 0)) + 1
	_expect(not counts.has("timid"), "a tyrant rolled Timid %d times" % int(counts.get("timid", 0)))
	for id in NR.allowed_for(&"tyrant"):
		_expect(int(counts.get(str(id), 0)) > 0, "nature %s never rolled for a tyrant in 400 spawns" % id)
	var common := int(counts.get("docile", 0)) + int(counts.get("timid", 0))
	var rarest := 100000
	for id in [&"stubborn", &"brave"]:
		rarest = mini(rarest, int(counts.get(str(id), 0)))
	_expect(common > rarest, "Docile+Timid (%d) are not commoner than Stubborn/Brave (%d)" % [common, rarest])
	print("[t_natures] roll: 400 tyrant spawns %s" % [counts])
	# A spawned animal carries the nature its seed rolls.
	var at := Vector3(6, 1, 8)
	var want: StringName = NR.roll(NR.spawn_key(&"velociraptor", at, 3), data.creature(&"velociraptor").archetype)
	var rolled := []
	for i in 2:
		var raw: Node = load(CREATURE_SCENE).instantiate()
		root.add_child(raw)
		raw.global_position = at
		raw.spawn(data.creature(&"velociraptor"), &"", 3)
		rolled.append(raw.nature)
		raw.free()
	_expect(rolled[0] == want and rolled[0] != &"", "spawned %s has nature %s, its seed rolls %s" % [rolled[0], rolled[0], want])
	_expect(rolled[1] == rolled[0], "two spawns at the same point rolled %s and %s" % [rolled[0], rolled[1]])
	_sections += 1

func _test_name() -> void:
	# Owner 2026-10-28: the nature is a tag UNDER the name, not part of the name.
	_expect(NR.display_name("", "Velociraptor") == "Velociraptor", "name reads '%s', want 'Velociraptor'" % NR.display_name("", "Velociraptor"))
	_expect(NR.display_name("Alpha", "Raptor") == "Alpha Raptor", "ordering: '%s', want 'Alpha Raptor'" % NR.display_name("Alpha", "Raptor"))
	_expect(NR.display_name("Crested", "Velociraptor") == "Crested Velociraptor", "variant first: '%s'" % NR.display_name("Crested", "Velociraptor"))
	_expect(NR.variant_word(&"velociraptor_crested", &"velociraptor") == "Crested", "variant word '%s'" % NR.variant_word(&"velociraptor_crested", &"velociraptor"))
	_expect(NR.tag(&"timid") == "Timid" and NR.tag(&"") == "", "the nature tag reads '%s' / '%s'" % [NR.tag(&"timid"), NR.tag(&"")])
	# The living animal's plate title: Alpha (the pack leader) and its colour variant, then the
	# species — and NO nature word anywhere in it; the nature comes back as the tag under the name.
	var alpha := _creature(&"velociraptor", Vector3(20, 1, 20), &"brave", 11)
	var beta := _creature(&"velociraptor", Vector3(22, 1, 20), &"timid", 11)
	beta.variant = &"velociraptor_crested"
	var title_a: String = NR.display_title(alpha)
	var title_b: String = NR.display_title(beta)
	print("[t_natures] names: leader='%s' follower='%s' tags '%s'/'%s'" % [title_a, title_b, NR.tag_for(alpha), NR.tag_for(beta)])
	_expect(not title_a.contains("Brave") and title_a.ends_with("Velociraptor"), "leader plate reads '%s' (the nature belongs in its tag '%s')" % [title_a, NR.tag_for(alpha)])
	_expect(not title_b.contains("Timid") and "Crested" in title_b and title_b.ends_with("Velociraptor"), "variant plate reads '%s' (the nature belongs in its tag '%s')" % [title_b, NR.tag_for(beta)])
	_expect(NR.tag_for(alpha) == "Brave" and NR.tag_for(beta) == "Timid", "plate tags read '%s' / '%s'" % [NR.tag_for(alpha), NR.tag_for(beta)])
	# The pack leader is the Alpha whatever the roster order (strongest first), so the alpha's own
	# title carries "Alpha" exactly when the brain names it the leader.
	var is_leader: bool = alpha.brain._is_pack_leader()
	_expect(("Alpha" in title_a) == is_leader, "leader title '%s' (is_leader=%s)" % [title_a, is_leader])
	alpha.free()
	beta.free()
	await process_frame
	_sections += 1

## Owner 2026-10-28: "for animal's natures, put it as a tag under their name, not in the name itself."
## MEASURED on the live nodes, not on the strings the helpers return: the world plate's name label and
## its chip, the Animals screen's row and detail, and the pet radial's centre disc.
func _test_nature_tag() -> void:
	var p: Node = load("res://scenes/player/player.tscn").instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	p.global_position = Vector3(-200, 1, 0)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = p.global_position + Vector3(0, 8, 9)
	cam.look_at(p.global_position + Vector3(0, 1, 0))
	cam.current = true
	# --- the world plate: the name has no nature word, the chip under it carries it.
	var pet := _creature(&"velociraptor", Vector3(-200, 1, 0), &"timid", 3)
	var rec: RefCounted = PR.from_def(pet.def, &"", &"", null, 1)
	rec.name = ""
	rec.nature = &"timid"
	pet.become_pet(rec)
	p.bonded.clear()
	p.bonded.append(rec)
	rec.summoned = true
	var plates: Node = load("res://scripts/ui/creature_plates.gd").new()
	root.add_child(plates)
	await process_frame
	var entry: Dictionary = plates._ensure_entry(pet)
	plates._emphasis_id = pet.get_instance_id()
	plates._update_entry(entry, pet, cam, p, 4.0, 0.016)
	var line1 := entry.get("line1", null) as Label
	var chip := entry.get("chip", null) as Control
	print("[t_natures] plate: name '%s', chip '%s' at %s" % [line1.text if line1 else "", _chip_text(chip), chip.position if chip else Vector2.ZERO])
	_expect(line1 != null and not line1.text.contains("Timid") and line1.text.contains("Velociraptor"), "the plate's name reads '%s', want the species without the nature" % (line1.text if line1 else "<none>"))
	_expect(chip != null and chip.visible and _chip_text(chip) == "Timid", "the plate shows no 'Timid' tag under the name (chip %s '%s')" % [chip.visible if chip else "missing", _chip_text(chip)])
	var plates_s: GDScript = load("res://scripts/ui/creature_plates.gd")
	var bar := entry.get("node", null) as Control
	var bar_node: Control = (bar.get_node_or_null("BarBg") as Control) if bar else null
	_expect(chip != null and bar_node != null and chip.position.y >= 0.0 and chip.position.y + chip.size.y <= bar_node.position.y + 1.0,
		"the tag is under the name and above the HP bar (chip %s-%s, bar at %s)" % [chip.position.y if chip else -1, (chip.position.y + chip.size.y) if chip else -1, bar_node.position.y if bar_node else -1])
	_expect(bar != null and is_equal_approx(bar.size.y, plates_s.FULL_H), "the plate keeps its %s px budget with the tag (%.0f)" % [plates_s.FULL_H, bar.size.y if bar else -1])
	# A nature-less animal: no chip, and the plate is the same size (nothing jumps between creatures).
	var plain := _creature(&"velociraptor", Vector3(-204, 1, 0), &"", 3)
	var pe: Dictionary = plates._ensure_entry(plain)
	plates._emphasis_id = plain.get_instance_id()
	plates._update_entry(pe, plain, cam, p, 4.0, 0.016)
	var plain_chip := pe.get("chip", null) as Control
	_expect(plain_chip != null and not plain_chip.visible and is_equal_approx((pe["node"] as Control).size.y, plates_s.FULL_H), "a nature-less animal draws no tag and the plate keeps its size")
	# The variant word ("Alpha" for a pack leader, a colour variant) STAYS in the name; only the nature moved.
	var alpha := _creature(&"velociraptor", Vector3(-208, 1, -2), &"brave", 21)
	alpha.variant = &"velociraptor_crested"
	var ae: Dictionary = plates._ensure_entry(alpha)
	plates._emphasis_id = alpha.get_instance_id()
	plates._update_entry(ae, alpha, cam, p, 4.0, 0.016)
	var aline := ae.get("line1", null) as Label
	print("[t_natures] plate variant: name '%s', chip '%s', leader=%s" % [aline.text if aline else "", _chip_text(ae.get("chip", null)), alpha.brain._is_pack_leader()])
	_expect(aline != null and aline.text.contains("Crested") and not aline.text.contains("Brave"), "a variant's plate reads '%s' (the variant stays in the name, Brave in the tag)" % (aline.text if aline else ""))
	_expect(NR.display_title(alpha).contains("Crested") and NR.display_title(alpha).ends_with("Velociraptor") and not NR.display_title(alpha).contains("Brave"), "a variant's title reads '%s'" % NR.display_title(alpha))
	_expect(aline != null and (aline.text.contains("Alpha") == alpha.brain._is_pack_leader()), "the pack leader's 'Alpha' stays in the name ('%s', leader=%s)" % [aline.text if aline else "", alpha.brain._is_pack_leader()])
	# --- the Animals screen: the row's name and the detail's name carry no nature; a chip does.
	var screen: Node = load("res://scripts/ui/animal_screen.gd").new()
	root.add_child(screen)
	await process_frame
	screen.open(p)
	await process_frame
	var row_chip: Control = null
	var row_text := ""
	# E1 rebuild: a pack card per pet; its Info column is Name, then the NatureChip directly under it.
	var card := screen.find_child("PackCard0", true, false)
	var info := card.find_child("Info", true, false) if card else null
	if info:
		var nm := info.get_node_or_null("Name") as Label
		row_text = nm.text if nm else ""
		row_chip = info.get_node_or_null("NatureChip") as Control
		_expect(nm != null and row_chip != null and row_chip.get_index() == nm.get_index() + 1, "the Animals row's chip is directly under the name")
	var detail_chip := screen.get("_detail_chip") as Control
	var detail_name := screen.get("_detail_name") as Label
	print("[t_natures] animals: row '%s' chip '%s'; detail name '%s' chip '%s'" % [row_text, _chip_text(row_chip), detail_name.text if detail_name else "", _chip_text(detail_chip)])
	_expect(row_text != "" and not row_text.contains("Timid"), "the Animals row reads '%s', want the name without the nature" % row_text)
	_expect(row_chip != null and row_chip.visible and _chip_text(row_chip) == "Timid", "the Animals row has no 'Timid' tag under the name (%s)" % _chip_text(row_chip))
	_expect(detail_name != null and not detail_name.text.contains("Timid") and detail_name.text.contains("Velociraptor"), "the detail's name reads '%s'" % (detail_name.text if detail_name else "<none>"))
	_expect(detail_chip != null and detail_chip.visible and _chip_text(detail_chip) == "Timid", "the detail has no 'Timid' tag under the name (%s)" % _chip_text(detail_chip))
	# --- the pet radial: the centre disc's name has no nature, the tag sits under it.
	var radial: Control = load("res://scripts/ui/pet_radial.gd").new()
	root.add_child(radial)
	await process_frame
	radial.show_for(pet, [{"id": &"animals", "label": "Animals", "icon": "animals"}])
	await process_frame
	var r_chip := radial.get("_chip") as Control
	var centre: Vector2 = radial.centre
	var r_name_y: float = centre.y + float(radial.r_in) * 0.3
	print("[t_natures] radial: chip '%s' at %s, centre %s" % [_chip_text(r_chip), r_chip.position if r_chip else Vector2.ZERO, centre])
	_expect(r_chip != null and r_chip.visible and _chip_text(r_chip) == "Timid", "the pet radial shows no 'Timid' tag under the name (%s)" % _chip_text(r_chip))
	_expect(r_chip != null and r_chip.position.y > r_name_y and r_chip.position.y + r_chip.size.y <= centre.y + float(radial.r_in),
		"the radial's tag is under the name (%s) and inside the disc (chip %s-%s, disc ends %s)" % [r_name_y, r_chip.position.y if r_chip else -1, (r_chip.position.y + r_chip.size.y) if r_chip else -1, centre.y + float(radial.r_in)])
	# A pet with no nature: no tag, and the ring's own layout is untouched.
	rec.nature = &""
	pet.nature = &""
	radial.show_for(pet, [{"id": &"animals", "label": "Animals", "icon": "animals"}])
	await process_frame
	_expect(r_chip != null and not r_chip.visible, "a nature-less pet draws no radial tag")
	radial.hide_menu()
	plates.free()
	screen.free()
	radial.free()
	pet.free()
	plain.free()
	alpha.free()
	cam.free()
	p.bonded.clear()
	p.free()
	await process_frame
	_sections += 1

func _chip_text(chip: Control) -> String:
	if chip == null or not chip.has_method("chip_text"):
		return "<none>"
	return str(chip.call("chip_text"))

func _test_old_save() -> void:
	# The checked-in fixture: a whole pet block exactly as a build without natures wrote it.
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pet_record_no_nature.json"))
	_expect(fixture is Dictionary and (fixture as Dictionary).get("pets", []) is Array, "fixture res://tests/fixtures/pet_record_no_nature.json does not load")
	var frow: Dictionary = (fixture as Dictionary).get("pets", [])[0] if fixture is Dictionary and not ((fixture as Dictionary).get("pets", []) as Array).is_empty() else {}
	_expect(not frow.has("nature"), "the no-nature fixture carries a nature already")
	var fpet: RefCounted = PR.from_dict(frow)
	var want_f: StringName = NR.from_uid("p_1a2b3c4d5e6f7a8b", &"velociraptor", &"pack_raptor")
	_expect(fpet.nature == want_f and NR.is_valid(fpet.nature), "the fixture pet loaded with nature '%s', want '%s'" % [fpet.nature, want_f])
	_expect(fpet.name == "Rex II" and fpet.uid == "p_1a2b3c4d5e6f7a8b" and fpet.level == 1 and fpet.tamed_role == [&"mount", &"scout"], "the fixture pet lost a field (name '%s', uid %s, level %d, roles %s)" % [fpet.name, fpet.uid, fpet.level, fpet.tamed_role])
	_expect(PR.from_dict(frow).nature == fpet.nature, "the fixture pet loads with a different nature the second time")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(fpet.to_dict()))
	_expect(saved.get("nature", "") == str(want_f), "a re-saved pet does not carry its nature (%s)" % saved.get("nature", "<none>"))
	# A pet record saved before natures: no "nature" key. It loads with a deterministic nature from
	# its uid, keeps every other field, and round-trips with its nature from then on.
	var def: CreatureDef = data.creature(&"velociraptor")
	var rec: RefCounted = PR.from_def(def, &"", &"", null, 1)
	rec.uid = "p_1a2b3c4d5e6f7a8b"
	rec.name = "Rex II"
	var row: Dictionary = rec.to_dict()
	row.erase("nature")
	var old: RefCounted = PR.from_dict(JSON.parse_string(JSON.stringify(row)))
	var want: StringName = NR.from_uid(old.uid, old.species, def.archetype)
	_expect(old.nature != &"" and NR.is_valid(old.nature), "an old pet record loaded without a nature (%s)" % old.nature)
	_expect(old.nature == want, "old record nature %s, derived from uid %s" % [old.nature, want])
	var again: RefCounted = PR.from_dict(JSON.parse_string(JSON.stringify(row)))
	_expect(again.nature == old.nature, "the same old record loaded twice got %s then %s" % [old.nature, again.nature])
	_expect(old.name == "Rex II" and old.species == &"velociraptor" and old.level == 1, "the old record lost a field on load (name '%s', species %s, level %d)" % [old.name, old.species, old.level])
	var back: RefCounted = PR.from_dict(JSON.parse_string(JSON.stringify(old.to_dict())))
	_expect(back.nature == old.nature and back.uid == old.uid, "a saved nature does not round-trip (%s -> %s)" % [old.nature, back.nature])
	# A forged or unknown nature is replaced by the uid-derived one, never kept.
	row["nature"] = "furious"
	_expect(PR.from_dict(row).nature == want, "an unknown nature in a save was kept")
	_sections += 1

# ---------------------------------------------------------------- wild behaviour

## Timid: the same hit that leaves a default predator fighting sends a Timid one running.
func _test_wild_timid_flees_sooner() -> void:
	var fits := []
	for n in [&"", &"timid"]:
		var c := _creature(&"velociraptor", Vector3(0, 1, 30), n)
		var target := Node3D.new()
		root.add_child(target)
		target.global_position = c.global_position + Vector3(2.0, 0, 0)
		c.brain.attack_target = target
		c.brain._set_state(&"approach")
		c.brain._last_hit_s = -999.0
		# A hit worth 60 % of max HP: the default backs off (retreat) at 30 %, Timid only at 54 %.
		var blow: float = c.health.max_hp * 0.6
		c.brain.note_damage(blow)
		var fled: bool = c.brain.state == &"flee"
		fits.append([c, target, fled, c.nature_knob("retreat_threshold_mult")])
	# The raptor pack brain's own retreat line is a nature decision too: an apex_raptor (exempt
	# there) shifts, a plain raptor retreats at 0.30 of its HP by default.
	var apex: Node = _creature(&"velociraptor", Vector3(0, 1, 34), &"timid")
	_expect(is_equal_approx(apex.brain.retreat_fraction(), 0.30 * 1.8), "a Timid raptor's retreat fraction is %.2f, want 0.54" % apex.brain.retreat_fraction())
	apex.free()
	print("[t_natures] timid: default flees=%s timid flees=%s" % [fits[0][2], fits[1][2]])
	_expect(not fits[0][2], "a default raptor fled from a 60 %% hit (it retreats, it does not flee)")
	_expect(fits[1][2], "a Timid raptor did not flee from the hit a default raptor fights through")
	_expect(float(fits[1][3]) > 1.0, "Timid's retreat threshold multiplier is %.2f, want > 1" % fits[1][3])
	for row in fits:
		(row[0] as Node).free()
		(row[1] as Node).free()
	_sections += 1

## Brave: a ridden pet keeps fighting below the retreat threshold its default sibling flees at.
func _test_brave_ridden_keeps_fighting() -> void:
	var p: Node = load("res://scenes/player/player.tscn").instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	p.global_position = Vector3(-40, 1, -40)
	var out := []
	for n in [&"", &"brave"]:
		var pet := _creature(&"velociraptor", Vector3(-40, 1, -40), n)
		var rec: RefCounted = PR.from_def(pet.def, &"", &"", null, 1)
		rec.nature = n
		pet.become_pet(rec)
		p.bonded.clear()
		p.bonded.append(rec)
		p.mounted_on = pet if n == &"brave" else null
		pet.health.hp = pet.health.max_hp * 0.2  # badly hurt: under both the default and Brave's threshold
		var foe := _creature(&"triceratops", Vector3(-36, 1, -40))
		pet.brain.attack_target = foe
		pet.brain._set_state(&"attack")
		var keep: bool = pet.brain.nature_keeps_fighting()
		out.append([pet, foe, keep])
	print("[t_natures] brave: default ridden keeps=%s brave ridden keeps=%s" % [out[0][2], out[1][2]])
	_expect(not out[0][2], "a default ridden pet keeps fighting past its retreat threshold")
	_expect(out[1][2], "a Brave ridden pet stands down below the retreat threshold")
	# Unridden, Brave's protection of its rider does not apply: it is about the rider.
	p.mounted_on = null  # the owner gets off: Brave only borrows the courage for its rider
	_expect(not out[1][0].brain.nature_keeps_fighting(), "Brave kept fighting while its owner was not riding it")
	for row in out:
		var pet: Node = row[0]
		p.mounted_on = null
		p.bonded.clear()
		pet.free()
		(row[1] as Node).free()
	p.free()
	await process_frame
	_sections += 1

## Aggressive: a territorial grazer that would wait to be hit charges a survivor inside its radius.
func _test_aggressive_engages() -> void:
	var p: Node = load("res://scenes/player/player.tscn").instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	p.global_position = Vector3(60, 1, 60)
	var out := []
	for n in [&"", &"aggressive"]:
		# A defensive grazer (ai.json: waits until hit, no territory) is the harshest case.
		var c := _creature(&"ankylosaurus", Vector3(60, 1, 66), n)
		c.brain.perception = 9.0
		p.global_position = c.global_position + Vector3(0, 0, -4.0)
		c.brain.tick(0.1)  # a roam think: it looks around
		out.append([c, c.brain.state, c.brain.attack_target, c.brain.aggro_radius()])
	print("[t_natures] aggressive: default state=%s aggressive state=%s radius %.1f vs %.1f" % [out[0][1], out[1][1], out[0][3], out[1][3]])
	_expect(out[0][2] != p, "a default grazer engaged the survivor without being provoked (state %s)" % out[0][1])
	_expect(out[1][2] == p, "an Aggressive grazer did not engage a survivor 4 m away (state %s)" % out[1][1])
	_expect(out[1][3] > out[0][3], "Aggressive did not widen the aggro radius (%.1f vs %.1f)" % [out[1][3], out[0][3]])
	for row in out:
		(row[0] as Node).free()
	p.free()
	await process_frame
	_sections += 1

## Stubborn: the hit that provokes a flee never sends it running (it fights back).
func _test_stubborn_ignores_fear() -> void:
	var out := []
	for n in [&"", &"stubborn"]:
		var c := _creature(&"zebraceratops", Vector3(0, 1, -60), n)
		var target := Node3D.new()
		root.add_child(target)
		target.global_position = c.global_position + Vector3(3.0, 0, 0)
		c.brain.attack_target = target
		c.brain._set_state(&"alert")
		c.brain._last_hit_s = -999.0
		c.brain.note_damage(c.health.max_hp * 0.9)
		c.brain._set_state(&"alert")  # the next think resolves alert: flee, or fight back
		c.brain.tick(0.1)
		out.append([c, target, c.brain.state])
	print("[t_natures] stubborn: default grazer state=%s stubborn state=%s" % [out[0][2], out[1][2]])
	_expect(out[0][2] == &"flee", "a default grazer hit for 90 %% did not flee (state %s)" % out[0][2])
	_expect(out[1][2] != &"flee", "a Stubborn grazer fled (state %s)" % out[1][2])
	for row in out:
		(row[0] as Node).free()
		(row[1] as Node).free()
	_sections += 1

# ---------------------------------------------------------------- pet behaviour and taming

## Loyal: the same owner distance makes a Loyal pet follow and a default pet stand still.
func _test_loyal_follows_closer() -> void:
	var p: Node = load("res://scenes/player/player.tscn").instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	p.global_position = Vector3(100, 1, 0)
	var out := []
	for n in [&"", &"loyal"]:
		var pet := _creature(&"velociraptor", Vector3(100, 1, 0), n)
		var rec: RefCounted = PR.from_def(pet.def, &"", &"", null, 1)
		rec.nature = n
		pet.become_pet(rec)
		p.bonded.clear()
		p.bonded.append(rec)
		pet.global_position = p.global_position + Vector3(0, 0, 1.5)
		# The spot beside the owner the pet walks to (its follow point), measured before the think.
		var follow: float = pet.global_position.distance_to(p.global_position + p.global_basis.x * 1.6)
		pet.brain.mode = &"guard"
		pet.brain.hold = false
		pet.brain.attack_target = null
		pet.stop_move()
		pet.brain._think(0.1)
		out.append([pet, pet._path_active, follow, pet.brain.nature_stop_distance()])
	print("[t_natures] loyal: default moves=%s at %.2f m, loyal moves=%s at %.2f m" % [out[0][1], out[0][2], out[1][1], out[1][2]])
	_expect(not out[0][1], "a default pet %.2f m from its follow point walked (it should hold)" % out[0][2])
	_expect(out[1][1], "a Loyal pet %.2f m from its follow point did not close the gap" % out[1][2])
	_expect(float(out[1][3]) < float(out[0][3]), "Loyal's follow distance %.2f m is not under the default %.2f m" % [out[1][3], out[0][3]])
	for row in out:
		var pet: Node = row[0]
		p.bonded.clear()
		pet.free()
	p.free()
	await process_frame
	_sections += 1

## Stubborn needs more feeds, Docile fewer, on the same species; the tame window follows suit.
func _test_taming_numbers() -> void:
	var out := {}
	var nodes := {}
	for n in [&"", &"stubborn", &"docile"]:
		var c := _creature(&"zebraceratops", Vector3(-100, 1, 0), n)
		nodes[str(n)] = c
		out[str(n)] = [c.feeds_needed(), c.tame_window_seconds(), c.def.feeds_needed]
	print("[t_natures] taming: default feeds=%.2f stubborn=%.2f docile=%.2f (species %.2f)" % [out[""][0], out["stubborn"][0], out["docile"][0], out[""][2]])
	_expect(is_equal_approx(float(out[""][0]), float(out[""][2])), "a nature-less animal needs %.2f feeds, the species lists %.2f" % [out[""][0], out[""][2]])
	_expect(float(out["stubborn"][0]) > float(out[""][0]), "Stubborn needs %.2f feeds, default %.2f" % [out["stubborn"][0], out[""][0]])
	_expect(float(out["docile"][0]) < float(out[""][0]), "Docile needs %.2f feeds, default %.2f" % [out["docile"][0], out[""][0]])
	_expect(float(out["stubborn"][1]) < float(out[""][1]) and float(out["docile"][1]) > float(out[""][1]), "tame windows: stubborn %.1f s, default %.1f s, docile %.1f s" % [out["stubborn"][1], out[""][1], out["docile"][1]])
	# FieldTame reads them: a Docile zebraceratops finishes on the feeds Stubborn still wants.
	var docile: Node = nodes["docile"]
	var stubborn: Node = nodes["stubborn"]
	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	player.global_position = Vector3(-100, 1, 0)
	var stack: RefCounted = load("res://scripts/items/item_stack.gd").make(&"berry", 10)
	player.inventory.add(stack)
	# The capture rule still gates every feed (spec 09): bring both to 20 % HP first.
	docile.health.hp = docile.health.max_hp * 0.2
	stubborn.health.hp = stubborn.health.max_hp * 0.2
	docile.torpor = docile.torpor_max()  # FOODTORPOR: knocked out = weak + torpor past the threshold
	stubborn.torpor = stubborn.torpor_max()
	FT.begin_window(docile)
	var window: float = docile.tame_window_left
	var okay: bool = FT.apply_feed(player, docile, &"berry")
	_expect(is_equal_approx(window, docile.tame_window_seconds()), "the window opened at %.1f s, this animal's %.1f s" % [window, docile.tame_window_seconds()])
	_expect(okay and docile.is_pet, "a Docile zebraceratops did not tame on one preferred feed (needs %.2f)" % docile.feeds_needed())
	_expect(docile.pet_record != null and str(docile.pet_record.nature) == "docile", "the tamed Docile animal became a pet with nature '%s'" % (docile.pet_record.nature if docile.pet_record else "no pet"))
	FT.begin_window(stubborn)
	var feeds := 0
	while not stubborn.is_pet and feeds < 20:
		FT.apply_feed(player, stubborn, &"berry")
		feeds += 1
	_expect(stubborn.is_pet and feeds > 1, "Stubborn tamed after %d feed(s), Docile after 1" % feeds)
	if stubborn.is_pet:
		_expect(str(stubborn.pet_record.nature) == "stubborn", "the tamed Stubborn animal became a pet with nature '%s'" % stubborn.pet_record.nature)
	# The capture rule is not touched by any nature (capture09: stunned at any HP, or <= 30 %).
	_expect(FT.health_allows_capture(0.31) == false and FT.health_allows_capture(0.30) == true, "the 30 %% capture rule moved")
	for c in [docile, stubborn]:
		if c.is_pet:
			player.bonded.clear()
		(c as Node).free()
	player.free()
	await process_frame
	_sections += 1

## The pen waits the base 30 minutes times the animal's nature (Stubborn longer, Docile shorter).
func _test_pen_wait() -> void:
	var pen_s: GDScript = load("res://scripts/world/taming_pen.gd")
	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	player.global_position = Vector3(-140, 1, 0)
	var waits := {}
	for n in [&"", &"stubborn", &"docile"]:
		for i in player.inventory.slot_count:
			player.inventory.slots[i] = null
		var stack: RefCounted = load("res://scripts/items/item_stack.gd").make(&"captured_animal", 1, {"species": "zebraceratops", "level": 1, "nature": str(n)})
		player.inventory.add(stack)
		var pen = pen_s.make()
		root.add_child(pen)
		var took: bool = pen.try_insert(player)
		waits[str(n)] = pen.remaining
		_expect(took, "the pen refused a captured zebraceratops (nature '%s')" % n)
		if took:
			_expect(str(pen.occupant.attributes.get("nature", "")) == str(n), "the pen lost the animal's nature '%s'" % n)
		pen.free()
	print("[t_natures] pen: default %.0f s, stubborn %.0f s, docile %.0f s" % [waits[""], waits["stubborn"], waits["docile"]])
	_expect(is_equal_approx(float(waits[""]), float(pen_s.BASE_SECONDS)), "a nature-less animal waits %.0f s, base %.0f s" % [waits[""], pen_s.BASE_SECONDS])
	_expect(float(waits["stubborn"]) > float(waits[""]) and float(waits["docile"]) < float(waits[""]), "pen waits: stubborn %.0f s, default %.0f s, docile %.0f s" % [waits["stubborn"], waits[""], waits["docile"]])
	player.free()
	await process_frame
	_sections += 1

## Docile deals less damage: the hit path reads attack_for (the one place a nature's damage
## multiplier lives) and a landed plain blow is exactly that attacker's mitigated damage.
func _test_docile_damage() -> void:
	var dealt := {}
	var atk := {}
	var GS: GDScript = load("res://scripts/creatures/creature_genetics.gd")
	for n in [&"", &"docile"]:
		# Neutral IVs on both sides: the same fight twice, so the only difference is the nature.
		var pet := _creature(&"velociraptor", Vector3(0, 1, 120), n)
		pet.genetics = GS.neutral()
		var rec: RefCounted = PR.from_def(pet.def, &"", &"", GS.neutral(), 1)
		rec.nature = n
		pet.become_pet(rec)
		atk[str(n)] = pet.attack_for(false)
		# Swings roll to hit and to crit, so the plain blow is the SMALLEST landed one over 30 swings.
		var least := INF
		for i in 30:
			var victim := _creature(&"triceratops", Vector3(2, 1, 120))
			var before: float = victim.health.hp
			CA.apply_for(pet, &"attack_primary", victim)
			var dmg: float = before - victim.health.hp
			if dmg > 0.0:
				least = minf(least, dmg)
			victim.free()
		dealt[str(n)] = least
		print("[t_natures] docile: nature '%s' attack_for=%.2f plain blow %.2f" % [n, atk[str(n)], least])
		pet.free()
	_expect(float(atk.get("docile", 0.0)) > 0.0 and float(atk.get("docile", 1.0)) < float(atk.get("", 0.0)), "Docile's attack is %.2f, default %.2f" % [atk.get("docile", -1.0), atk.get("", -1.0)])
	# And the blow landed is that attack through the real mitigation, not some other number.
	_expect(float(dealt.get("", 0.0)) > 0.0 and float(dealt.get("docile", 0.0)) > 0.0, "no damage was dealt through the hit path (%s)" % [dealt])
	_expect(float(dealt.get("docile", 1.0)) < float(dealt.get("", 1.0)), "Docile dealt %.2f, default %.2f" % [dealt.get("docile", -1.0), dealt.get("", -1.0)])
	_sections += 1

func _test_pet_keeps_nature() -> void:
	var c := _creature(&"velociraptor", Vector3(0, 1, -120), &"brave")
	var rec: RefCounted = PR.from_def(c.def, &"", &"", null, 1)
	var wild: StringName = c.nature
	c.become_pet(rec)
	c.pet_record.nature = wild
	_expect(c.nature_id() == wild, "a tamed animal's brain reads nature %s, its wild nature was %s" % [c.nature_id(), wild])
	# A pet record without its nature (an old save) drives the brain's knobs from its uid-derived one.
	c.pet_record.nature = PR.from_dict({"uid": "p_0badf00d", "species": "velociraptor"}).nature
	_expect(c.nature_id() == c.pet_record.nature and c.nature_id() != &"", "the pet's brain reads %s, its record %s" % [c.nature_id(), c.pet_record.nature])
	# The tame itself carries it: FieldTame stamps the animal's nature onto the record it makes.
	var fresh := _creature(&"zebraceratops", Vector3(0, 1, -126), &"stubborn")
	fresh.health.hp = fresh.health.max_hp * 0.2
	fresh.torpor = fresh.torpor_max()  # FOODTORPOR
	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	player.global_position = Vector3(0, 1, -126)
	player.inventory.add(load("res://scripts/items/item_stack.gd").make(&"berry", 12))
	FT.begin_window(fresh)
	for i in 6:
		if not fresh.is_pet:
			FT.apply_feed(player, fresh, &"berry")
	_expect(fresh.is_pet and fresh.pet_record != null and str(fresh.pet_record.nature) == "stubborn", "a tamed Stubborn animal's pet record reads '%s'" % (fresh.pet_record.nature if fresh.pet_record else "no record"))
	player.bonded.clear()
	player.free()
	fresh.free()
	c.free()
	_sections += 1
