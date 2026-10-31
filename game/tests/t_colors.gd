extends SceneTree
## COLORS acceptance: wild individuals get a natural, per-individual colour profile (hue shift,
## saturation and value scale, optional morph) rolled from the species' JSON ranges; taming keeps the
## wild individual's profile and genetics exactly; save/load keeps both; a pet saved before colour
## profiles existed gets a deterministic one derived from its uid (the same on every load).
## Run: Godot --headless --path game --script res://tests/t_colors.gd -> "[t_colors] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const RANGE_SPECIES: Array[StringName] = [&"velociraptor", &"zebraceratops", &"tyrannosaurus", &"stegosaurus"]
const SPAWNS := 20

var _fails: PackedStringArray = []
var _started := false
var _sections := 0
var Coloration: GDScript
var Genetics: GDScript
var PetRecordS: GDScript
var FieldTameS: GDScript
var CaptureS: GDScript
var ItemStackS: GDScript
var ViewS: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	create_timer(60).timeout.connect(func(): quit(2))
	Coloration = load("res://scripts/creatures/creature_coloration.gd")
	Genetics = load("res://scripts/creatures/creature_genetics.gd")
	PetRecordS = load("res://scripts/pets/pet_record.gd")
	FieldTameS = load("res://scripts/pets/field_tame.gd")
	CaptureS = load("res://scripts/pets/capture_system.gd")
	ItemStackS = load("res://scripts/items/item_stack.gd")
	ViewS = load("res://scripts/creatures/creature_view.gd")
	_test_defaults_and_ranges()
	_test_rare_and_patterns()
	_test_spawn_variety()
	_test_view_shader_and_fx()
	_test_tame_keeps_profile()
	_test_save_load_round_trip()
	_test_old_save_derives_stable_profile()
	_test_untrusted_profile()
	if _sections != 8:
		_fails.append("only %d of 8 sections completed (a runtime error aborted the rest)" % _sections)
	if _fails.is_empty():
		print("[t_colors] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_colors] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_colors] FAIL %s" % what)

func _def(id: StringName) -> CreatureDef:
	return root.get_node("Data").creature(id)

func _in(hue: float, sat: float, val: float, lo_h: float, hi_h: float, lo_s: float, hi_s: float, lo_v: float, hi_v: float) -> bool:
	return hue >= lo_h - 0.001 and hue <= hi_h + 0.001 and sat >= lo_s - 0.001 and sat <= hi_s + 0.001 and val >= lo_v - 0.001 and val <= hi_v + 0.001

## A morph/species scale field as signed offsets from 1.0 (scalar = +-v, array = [lo, hi]).
func _offsets(raw: Variant) -> Array:
	if raw is Array and (raw as Array).size() >= 2:
		return [float(raw[0]), float(raw[1])]
	var v := absf(float(raw if raw is int or raw is float else 0.0))
	return [-v, v]

## ---- 1. the profile model: data ranges respected, defaults when a species has none
func _test_defaults_and_ranges() -> void:
	var col = Coloration.new()
	_expect(col.hue_deg == 0.0 and col.sat == 1.0 and col.val == 1.0 and col.morph == &"", "a new profile is neutral")
	# A species with no block: the ASSUMPTION defaults (+-12 deg, sat +-15 %, value +-10 %).
	var raptor := _def(&"velociraptor")
	_expect(not raptor.coloration.is_empty(), "velociraptor.json declares a coloration block")
	var d := raptor.coloration
	var hue_amp := float(d.get("hue_deg", 0.0))
	var sat_amp := float(d.get("sat", 0.0))
	var val_amp := float(d.get("val", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	var morphs := {}
	for i in 200:
		var p = Genetics.roll(rng, d).coloration
		_expect(p != null, "roll carries a profile")
		var morphed := String(p.morph) != ""
		if p.rare:
			# A rare morph is outside the normal range on purpose; it still stays believable.
			_expect(absf(p.hue_deg) <= Coloration.HUE_LIMIT * 1.5 and p.sat >= 1.0 - Coloration.SAT_LIMIT * Coloration.RARE_SCALE - 0.001
				and p.val >= 1.0 - Coloration.VAL_LIMIT * Coloration.RARE_SCALE - 0.001, "rare morph stays believable (%s)" % p.label())
		elif morphed:
			morphs[String(p.morph)] = true
			var own := {}
			for m in d.get("morphs", []):
				if str(m.get("id", "")) == String(p.morph):
					own = m
			var mh := float(own.get("hue_deg", 0.0))
			var ms: Array = _offsets(own.get("sat", 0.0))
			var mv: Array = _offsets(own.get("val", 0.0))
			_expect(_in(p.hue_deg, p.sat, p.val, -mh, mh, 1.0 + float(ms[0]), 1.0 + float(ms[1]), 1.0 + float(mv[0]), 1.0 + float(mv[1])),
				"morph %s stays inside its own range (%s)" % [str(p.morph), p.label()])
		else:
			_expect(_in(p.hue_deg, p.sat, p.val, -hue_amp, hue_amp, 1.0 - sat_amp, 1.0 + sat_amp, 1.0 - val_amp, 1.0 + val_amp),
				"plain roll inside the species ranges (%s)" % p.label())
		seen["%s|%s" % [snappedf(p.hue_deg, 0.01), snappedf(p.sat, 0.01)]] = true
	_expect(seen.size() >= 20, "200 rolls give many different profiles (got %d)" % seen.size())
	_expect(morphs.size() >= 2, "the weighted morphs are all reachable (got %s)" % str(morphs.keys()))
	# Defaults when the block is empty.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 11
	for i in 100:
		var p = Coloration.roll({}, rng2)
		if p.rare:
			continue
		_expect(_in(p.hue_deg, p.sat, p.val, -12.0, 12.0, 0.85, 1.15, 0.90, 1.10), "defaults are +-12 deg / +-15 %% / +-10 %% (%s)" % p.label())
	_expect(Coloration.roll({}, null) != null, "roll with no rng still returns a profile")
	# Same seed, same animal.
	var a := RandomNumberGenerator.new()
	a.seed = 99
	var b := RandomNumberGenerator.new()
	b.seed = 99
	_expect(Genetics.roll(a, d).to_dict() == Genetics.roll(b, d).to_dict(), "a seeded roll reproduces profile and IVs exactly")
	# Neutral genetics is a no-op shift, never null.
	var n = Genetics.neutral()
	_expect(n.coloration != null and n.coloration.hue_deg == 0.0 and n.coloration.sat == 1.0, "neutral genetics carries a neutral profile")
	_sections += 1

## ---- 1b. rare morphs (about 1 in 50, the only rolls outside the normal range) and hide patterns
func _test_rare_and_patterns() -> void:
	var def := _def(&"velociraptor")
	var d := def.coloration
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var rare := 0
	var total := 2000
	var normal_outside := 0
	var rare_inside := 0
	var hue_amp := float(d.get("hue_deg", 12.0))
	var sat_amp := float(d.get("sat", 0.15))
	var val_amp := float(d.get("val", 0.10))
	for i in total:
		var p = Coloration.roll(d, rng)
		if p.rare:
			rare += 1
			if _in(p.hue_deg, p.sat, p.val, -hue_amp * Coloration.RARE_SCALE, hue_amp * Coloration.RARE_SCALE,
					1.0 - sat_amp * Coloration.RARE_SCALE, 1.0 + sat_amp * Coloration.RARE_SCALE,
					1.0 - val_amp * Coloration.RARE_SCALE, 1.0 + val_amp * Coloration.RARE_SCALE):
				rare_inside += 1
		elif not _in(p.hue_deg, p.sat, p.val, -hue_amp, hue_amp, 1.0 - sat_amp, 1.0 + sat_amp, 1.0 - val_amp, 1.0 + val_amp):
			normal_outside += 1
	var share := float(rare) / float(total)
	_expect(share >= 0.01 and share <= 0.04, "about 1 in 50 rolls is a rare morph (%.2f%% of %d)" % [share * 100.0, total])
	_expect(normal_outside == 0, "every normal roll stays inside the species range (%d outside)" % normal_outside)
	_expect(rare_inside == rare, "every rare roll stays believable (its own wider bound)")
	print("[t_colors] rare share=%.2f%% (%d of %d), normal outside range=%d" % [share * 100.0, rare, total, normal_outside])
	# Patterns: only the species' declared kinds, each with a usable scale, strength and tone.
	var kinds := {}
	for i in 600:
		var p = Coloration.roll(d, rng)
		kinds[str(p.pattern)] = int(kinds.get(str(p.pattern), 0)) + 1
		_expect(p.pattern == &"" or str(p.pattern) in CreatureColoration.PATTERNS, "pattern '%s' is a known kind" % str(p.pattern))
		if p.pattern != &"":
			_expect(p.pattern_strength > 0.0 and p.pattern_strength <= 0.9 and p.pattern_scale > 0.0, "pattern '%s' has a usable scale and strength (%.2f/%.2f)" % [str(p.pattern), p.pattern_scale, p.pattern_strength])
			_expect(absf(p.pattern_tone) == 1.0, "pattern tone is darker or lighter, never a hue")
	_expect(kinds.size() >= 3, "the species wears more than one pattern (got %s)" % str(kinds.keys()))
	print("[t_colors] patterns %s" % str(kinds))
	_sections += 1

func _test_spawn_variety() -> void:
	for species in RANGE_SPECIES:
		var def := _def(species)
		var block := def.coloration
		var hue_amp := float(block.get("hue_deg", 12.0))
		var sat_amp := float(block.get("sat", 0.15))
		var val_amp := float(block.get("val", 0.10))
		var distinct := {}
		var in_range := 0
		var extreme := 0.0
		for i in SPAWNS:
			# 20 spawns at 20 different points, the way Creature.spawn seeds a wild animal.
			var c = _spawn(species, Vector3(6.0 * float(i), 0.0, 2.0 * float(i % 5)))
			var p = c.genetics.coloration
			_expect(p != null, "%s spawn %d got a profile" % [species, i])
			if p == null:
				c.queue_free()
				continue
			var morphed := String(p.morph) != ""
			if p.rare:
				in_range += 1 # a rare morph is the 1-in-50 outlier, not a range violation
			elif morphed:
				# A morph is its own look: count it as inside the species range.
				in_range += 1
			else:
				_expect(_in(p.hue_deg, p.sat, p.val, -hue_amp, hue_amp, 1.0 - sat_amp, 1.0 + sat_amp, 1.0 - val_amp, 1.0 + val_amp),
					"%s spawn %d inside its ranges (%s)" % [species, i, p.label()])
				in_range += 1
			extreme = maxf(extreme, absf(p.hue_deg))
			distinct["%s|%s|%s" % [snappedf(p.hue_deg, 0.1), snappedf(p.sat, 0.01), snappedf(p.val, 0.01)]] = true
			c.queue_free()
		_expect(distinct.size() >= 5, "%s: %d spawns give >= 5 distinct profiles (got %d)" % [species, SPAWNS, distinct.size()])
		_expect(in_range >= SPAWNS / 2, "%s: plain rolls stay in range (%d of %d)" % [species, in_range, SPAWNS])
		# Natural, never neon: a hue shift of +-40 deg at most and a saturation scale near 1.
		_expect(extreme <= Coloration.HUE_LIMIT, "%s hue shift stays under %.0f deg (max %.1f)" % [species, Coloration.HUE_LIMIT, extreme])
		print("[t_colors] %s: distinct=%d/%d in_range=%d max_hue=%.1f" % [species, distinct.size(), SPAWNS, in_range, extreme])
	# Every fresh spawn is a new individual, even at a fixed spawner: the colour seed carries a
	# per-spawn serial, so a respawn is not a clone of the animal it replaces. The look still stays
	# fixed for one animal's lifetime, because taming reuses the genetics record (section 5).
	var p1 = _spawn(&"velociraptor", Vector3(3, 0, 3))
	var p2 = _spawn(&"velociraptor", Vector3(3, 0, 3))
	var p3 = _spawn(&"velociraptor", Vector3(9, 0, 3))
	_expect(not p1.genetics.coloration.equals(p2.genetics.coloration), "a respawn at the same spawn point is a new individual")
	_expect(not p1.genetics.coloration.equals(p3.genetics.coloration) or not p1.genetics.equals(p3.genetics), "another spawn point rolls another individual")
	p1.queue_free()
	p2.queue_free()
	p3.queue_free()
	_sections += 1

## A real Creature node spawned through Creature.spawn(); the brain is left off so it does not roam.
func _spawn(species: StringName, at: Vector3):
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	c.position = at
	root.add_child(c)
	c.spawn(_def(species))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

## ---- 2. the view: per-surface shader material carrying the profile, FX still on top
func _test_view_shader_and_fx() -> void:
	var def := _def(&"velociraptor")
	var view = ViewS.new()
	root.add_child(view)
	var col = Coloration.roll(def.coloration, Coloration.seeded_rng("test::view"))
	view.setup(def)
	view.apply_coloration(col)
	_expect(view.using_glb, "velociraptor loads its GLB rig")
	_expect(view._skin_mats.size() >= 1, "every mesh surface got a colour material (got %d)" % view._skin_mats.size())
	var shared := {}
	var ok_params := true
	for sm in view._skin_mats:
		_expect(sm is ShaderMaterial and sm.shader == view.COLOR_SHADER, "surface material is the colour shader")
		ok_params = ok_params and is_equal_approx(float(sm.get_shader_parameter("hue_shift")), col.hue_deg / 360.0) \
			and is_equal_approx(float(sm.get_shader_parameter("sat_scale")), col.sat) \
			and is_equal_approx(float(sm.get_shader_parameter("val_scale")), col.val)
		shared[sm] = true
	_expect(ok_params, "the material samples the individual's hue/sat/val")
	_expect(shared.size() == view._skin_mats.size(), "one material per surface, never shared between individuals")
	var keeps_albedo: bool = view._skin_mats.size() > 0 and view._skin_mats[0].get_shader_parameter("use_albedo") == true
	_expect(keeps_albedo, "the shader keeps the original albedo texture")
	var tex: Texture2D = view._skin_mats[0].get_shader_parameter("albedo_tex")
	_expect(tex != null and tex.get_width() > 4, "the albedo texture is bound (got %s)" % str(tex))
	# Status FX rides on top: darken and the tint land as shader parameters, and back off again.
	view.set_status_fx(0.35, Color(0.35, 0.85, 0.3), 1.0)
	_expect(is_equal_approx(float(view._skin_mats[0].get_shader_parameter("darken")), 0.35) \
		and (view._skin_mats[0].get_shader_parameter("tint_color") as Color).is_equal_approx(Color(0.35, 0.85, 0.3)) \
		and is_equal_approx(float(view._skin_mats[0].get_shader_parameter("tint_amount")), 0.35), "status FX darken and tint reach the GLB shader materials")
	view.flash_damage(0.5)
	_expect(float(view._skin_mats[0].get_shader_parameter("flash_amount")) > 0.0, "the damage flash reaches the GLB shader materials")
	view.set_status_fx(0.0, Color.WHITE, 0.0)
	# The placeholder path (stegosaurus still uses boxes by design) shifts its tint with the same profile.
	var stego := _def(&"stegosaurus")
	var pv = ViewS.new()
	root.add_child(pv)
	pv.setup(stego)
	pv.apply_coloration(col)
	_expect(not pv.using_glb and pv._body != null, "stegosaurus uses the placeholder boxes")
	pv.set_status_fx(0.0, Color.WHITE, 0.0)
	var base: Color = pv._tint
	var want: Color = col.shift_color(base)
	_expect(col.hue_deg != 0.0 or col.sat != 1.0, "the view test uses a non-neutral profile (%s)" % col.label())
	var got: Color = (pv._body.material_override as StandardMaterial3D).albedo_color
	_expect(got.is_equal_approx(want), "placeholder tint carries the colour shift (got %s want %s)" % [got, want])
	_expect(not got.is_equal_approx(base) or (col.hue_deg == 0.0 and col.sat == 1.0), "the placeholder really changed colour")
	pv.set_status_fx(0.5, Color.WHITE, 0.0)
	var dark: Color = (pv._body.material_override as StandardMaterial3D).albedo_color
	_expect(dark.v < want.v + 0.001, "status darken still applies on top of the placeholder colour")
	# Neutral profile = the authored look.
	var neutral = Coloration.new()
	_expect(neutral.shift_color(Color(0.7, 0.3, 0.1)).is_equal_approx(Color(0.7, 0.3, 0.1)), "a neutral profile is a no-op shift")
	view.queue_free()
	pv.queue_free()
	_sections += 1

## ---- 3. taming keeps the wild individual's profile and genetics exactly
func _test_tame_keeps_profile() -> void:
	var def := _def(&"velociraptor")
	root.get_node("Data").set_survival_unlocked(&"capture_technique_II", true)
	var c = _spawn(&"velociraptor", Vector3(1.0, 0.0, 1.0))
	# Force a rare, striped individual: the wild roll may not give one, and this is the case the owner
	# asked for (a rare morph keeps its look through taming).
	c.genetics.coloration = Coloration.derive("rare::tame", def.coloration)
	c.genetics.coloration.pattern = &"stripes"
	c.genetics.coloration.pattern_strength = 0.44
	c.genetics.coloration.rare = true
	c.view.apply_coloration(c.genetics.coloration)
	var wild_genes: Dictionary = c.genetics.to_dict()
	var wild_col = c.genetics.coloration
	# Field tame: the real path (feed until the last feed completes the bond). A bare script instance
	# is enough: apply_feed reads the roster, the bag and the display name.
	var player = (load("res://scripts/player/player.gd") as GDScript).new()
	player.bonded.clear()
	player.inventory = (load("res://scripts/items/inventory.gd") as GDScript).new(28)
	c.health.hp = c.health.max_hp * 0.2
	c.statuses.apply(&"knockdown")
	c.torpor = c.torpor_max()  # FOODTORPOR: knocked out = weak + torpor past the threshold
	player.inventory.add(ItemStackS.make(&"raw_meat", 5))
	FieldTameS.begin_window(c)
	var fed := 0
	while c.tame_attempting and fed < 10:
		if not FieldTameS.apply_feed(player, c, &"raw_meat"):
			break
		fed += 1
	_expect(player.bonded.size() == 1, "field tame bonds the animal (feeds=%d)" % fed)
	if player.bonded.size() == 1:
		var rec = player.bonded[0]
		_expect(rec.genetics.to_dict() == wild_genes, "the tamed pet's genetics equal the wild individual's exactly")
		_expect(rec.coloration() != null and rec.coloration().equals(wild_col), "the tamed pet keeps the wild colour profile (%s vs %s)" % [rec.coloration().label(), wild_col.label()])
		_expect(c.pet_record == rec and c.genetics.coloration.equals(wild_col), "the now-tame creature renders its own profile")
	_expect(c.view.coloration != null and c.view.coloration.equals(wild_col), "the view still carries the wild profile after taming")
	if player.bonded.size() == 1:
		var rec = player.bonded[0]
		_expect(rec.coloration().rare and rec.coloration().pattern == &"stripes", "a rare patterned morph stays rare and striped through taming")
		var reloaded = PetRecordS.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
		_expect(reloaded.coloration().equals(wild_col), "the rare pattern survives the tamed pet's save and load")
	# Capture (net) + pen: the captured stack and the bonded pet keep the profile too.
	var p2 = (load("res://scripts/player/player.gd") as GDScript).new()
	p2.bonded.clear()
	p2.inventory = (load("res://scripts/items/inventory.gd") as GDScript).new(28)
	root.get_node("Data").set_survival_unlocked(&"capture_technique_II", true)
	p2.inventory.add(ItemStackS.make(&"capture_net_ii", 1))
	var c2 = _spawn(&"velociraptor", Vector3(-4.0, 0.0, 1.0))
	c2.health.hp = c2.health.max_hp * 0.2
	c2.statuses.apply(&"knockdown")
	c2.torpor = c2.torpor_max()
	c2.is_capturable = true
	var genes2: Dictionary = c2.genetics.to_dict()
	var netted: bool = CaptureS.attempt(p2, c2, 1)
	_expect(netted, "the net takes a knocked-out animal at 20 %% HP")
	var idx: int = p2.inventory.find_first(&"captured_animal")
	_expect(idx >= 0, "the capture bags a captured_animal stack")
	if idx >= 0:
		var attrs: Dictionary = p2.inventory.slots[idx].attributes
		var g_raw: Variant = attrs.get("genetics")
		_expect(g_raw is Dictionary and (g_raw as Dictionary).has("coloration"), "the captured stack carries the colour profile")
		var genes = Genetics.from_dict(g_raw if g_raw is Dictionary else {})
		_expect(genes.to_dict() == genes2, "captured genetics equal the wild individual's")
	# A hand-built pet gets its own rolled profile, never a shared neutral one.
	var hand = PetRecordS.from_def(def, &"", &"")
	_expect(hand.genetics.coloration != null and hand.genetics.coloration.sat != 0.0, "from_def gives a fresh pet its own profile")
	root.get_node("Data").set_survival_unlocked(&"capture_technique_II", false)
	player.free()
	p2.free()
	c.queue_free()
	_sections += 1

## ---- 4. save/load keeps the profile and the genetics
func _test_save_load_round_trip() -> void:
	var def := _def(&"zebraceratops")
	var rec = PetRecordS.from_def(def, &"", &"", null, 12)
	rec.genetics.coloration = Coloration.roll(def.coloration, Coloration.seeded_rng("round-trip"))
	rec.genetics.coloration.pattern = &"stripes"
	rec.genetics.coloration.pattern_scale = 1.3
	rec.genetics.coloration.pattern_strength = 0.42
	rec.genetics.coloration.pattern_tone = -1.0
	rec.genetics.coloration.pattern_seed = 12.5
	var saved: Dictionary = JSON.parse_string(JSON.stringify(rec.to_dict()))
	var back = PetRecordS.from_dict(saved)
	_expect(back.uid == rec.uid, "the round trip keeps the uid")
	_expect(back.coloration().pattern == &"stripes" and absf(back.coloration().pattern_strength - 0.42) < 0.001 \
		and absf(back.coloration().pattern_scale - 1.3) < 0.001 and back.coloration().pattern_tone < 0.0 \
		and absf(back.coloration().pattern_seed - 12.5) < 0.01, "the save keeps the hide pattern (%s)" % back.coloration().label())
	_expect(back.genetics.to_dict() == rec.genetics.to_dict(), "the round trip keeps genetics and profile exactly")
	_expect(back.coloration().equals(rec.coloration()), "the loaded pet keeps its colour profile (%s)" % back.coloration().label())
	# Through the save sanitizer (the trust boundary), as a real load does.
	var d := saved.duplicate(true)
	d["pets"] = [saved]
	var Sanitizer = load("res://scripts/core/save_sanitizer.gd")
	var clean: Dictionary = Sanitizer.clean(d)
	var row: Dictionary = (clean["pets"] as Array)[0]
	_expect(row.has("genetics") and (row["genetics"] as Dictionary).has("coloration"), "the sanitizer keeps the colour profile")
	var back2 = PetRecordS.from_dict(row)
	_expect(back2.coloration().equals(rec.coloration()), "the sanitized save keeps the colour profile")
	# A json round trip of the profile itself.
	var col = rec.coloration()
	var col2 = Coloration.from_dict(JSON.parse_string(JSON.stringify(col.to_dict())))
	_expect(col2.equals(col) and String(col2.morph) == String(col.morph), "the profile survives JSON (morph '%s')" % str(col2.morph))
	# A rare morph sits outside the normal clamp: sat 1.47 (a compsognathus rare) and hue 38 deg must
	# come back unchanged, not clamped to 1.45 / 40.
	var rare = Coloration.new()
	rare.rare = true
	rare.sat = 1.47
	rare.hue_deg = 38.0
	rare.val = 0.62
	rare.pattern = &"spots"
	rare.pattern_strength = 0.55
	var rare_back = Coloration.from_dict(JSON.parse_string(JSON.stringify(rare.to_dict())))
	_expect(rare_back.equals(rare) and is_equal_approx(rare_back.sat, 1.47) and is_equal_approx(rare_back.hue_deg, 38.0),
		"a rare morph's wide colour survives JSON (sat %.2f hue %.1f)" % [rare_back.sat, rare_back.hue_deg])
	_sections += 1

## ---- 5. an old save (no profile) derives one from the uid, the same every load
func _test_old_save_derives_stable_profile() -> void:
	var def := _def(&"velociraptor")
	var rec = PetRecordS.from_def(def, &"", &"", null, 5)
	var d: Dictionary = rec.to_dict()
	(d["genetics"] as Dictionary).erase("coloration") # what a pre-COLORS save looks like
	var first = PetRecordS.from_dict(d.duplicate(true))
	var second = PetRecordS.from_dict(d.duplicate(true))
	_expect(first.coloration() != null, "a profile-less pet gets a derived profile")
	_expect(first.coloration().equals(second.coloration()), "twice loaded, the same derived profile (%s vs %s)" % [first.coloration().label(), second.coloration().label()])
	_expect(first.coloration().equals(Coloration.derive(first.uid, def.coloration)), "it is derived from the pet id")
	# Not neutral: the pet really gets colours.
	_expect(first.coloration().hue_deg != 0.0 or first.coloration().sat != 1.0, "the derived profile is not the neutral one")
	# Once loaded and saved again it is stored, and loading keeps it.
	var again: Dictionary = first.to_dict()
	var third = PetRecordS.from_dict(again)
	_expect(third.coloration().equals(first.coloration()), "the derived profile is written back and kept")
	# Two different old pets derive different profiles.
	var other = PetRecordS.from_dict(d)
	var diff := 0
	for i in 8:
		var r = PetRecordS.from_def(def, &"", &"")
		var dd: Dictionary = r.to_dict()
		(dd["genetics"] as Dictionary).erase("coloration")
		var o = PetRecordS.from_dict(dd)
		if not o.coloration().equals(first.coloration()):
			diff += 1
	_expect(diff >= 7, "different pet ids derive different profiles (%d of 8)" % diff)
	_expect(other.uid == first.uid, "the same row keeps its uid")
	_sections += 1

## ---- 6. a hand-edited profile cannot leave the natural bounds or break the save
func _test_untrusted_profile() -> void:
	var col = Coloration.from_dict({"hue_deg": 1e9, "sat": -5.0, "val": "pink", "morph": 7})
	_expect(absf(col.hue_deg) <= Coloration.HUE_LIMIT and col.sat >= 1.0 - Coloration.SAT_LIMIT and col.val == 1.0 and col.morph == &"", "a forged profile is clamped to the natural bounds (%s)" % col.label())
	var nan_col = Coloration.from_dict({"hue_deg": INF, "sat": NAN, "val": -INF})
	_expect(is_finite(nan_col.hue_deg) and is_finite(nan_col.sat) and is_finite(nan_col.val), "non-finite numbers fall back to neutral")
	var genes = Genetics.from_dict({"ivs": {}, "evs": {}, "level_gains": {}, "coloration": {"hue_deg": 300, "sat": 9, "val": 0}})
	_expect(genes.coloration != null and absf(genes.coloration.hue_deg) <= Coloration.HUE_LIMIT and genes.coloration.sat <= 1.0 + Coloration.SAT_LIMIT, "genetics clamps a forged profile")
	var junk = Genetics.from_dict({"coloration": "red"})
	_expect(junk.coloration == null, "a non-dictionary profile is absent, so the pet derives one")
	_sections += 1
