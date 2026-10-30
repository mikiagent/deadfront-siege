extends SceneTree
## TRAITGEAR (docs/design/tools-durability-crafting.md §3.6, P4): the primary material's traits change the
## crafted gear's stats (rules.json crafting.gear_traits): high/low density -> max durability +-3 %/level,
## firm/soft -> damage +-2 %, tough/soft fiber -> armour +-2 %, high elasticity -> gather power +2 %; the
## sum per stat clamps at +-15 %; only gear crafted after P4 carries the effect (a stored max is never
## recalculated), and the item card lists each effect line.
## Usage: godot --headless --path game --script res://tests/t_traitgear.gd -> "[t_traitgear] PASS".

var _fails: PackedStringArray = []
var _started := false
var CR: GDScript
var IS: GDScript
var PANEL: GDScript

func _process(_delta: float) -> bool:
	if _started or root == null or root.get_node_or_null("Data") == null:
		return false
	_started = true
	CR = load("res://scripts/items/crafting.gd")
	IS = load("res://scripts/items/item_stack.gd")
	PANEL = load("res://scripts/ui/item_inspect_panel.gd")
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_traitgear] %s %s" % ["ok" if ok else "FAIL", what])

## Gear crafted through the shared output builder from a primary carrying `attrs`.
func _craft(rid: StringName, primary_id: StringName, attrs: Dictionary):
	return CR.build_output(CR.recipe(rid), IS.make(primary_id, 1, attrs, 1), 1)

func _run() -> void:
	var plain = _craft(&"work_axe", &"stone", {})
	var dense = _craft(&"work_axe", &"stone", {"high_density": 3})
	var loose = _craft(&"work_axe", &"stone", {"low_density": 3})
	var base: float = 50.0 * plain.stat_multiplier()
	_expect(plain.max_durability == roundi(base), "a plain stone work axe keeps its max (%d)" % plain.max_durability)
	_expect(is_equal_approx(dense.trait_mult(&"durability"), 1.09) and dense.max_durability == roundi(base * 1.09) and dense.durability == dense.max_durability,
		"High Density 3: max durability x1.09 (%d vs %d)" % [dense.max_durability, plain.max_durability])
	_expect(is_equal_approx(loose.trait_mult(&"durability"), 0.91) and loose.max_durability == roundi(base * 0.91), "Low Density 3: x0.91 (%d)" % loose.max_durability)
	var dagger = _craft(&"stone_knife", &"stone", {})
	var firm = _craft(&"stone_knife", &"stone", {"firm": 3})
	var soft = _craft(&"stone_knife", &"stone", {"soft": 3})
	_expect(is_equal_approx(firm.scaled_damage(), dagger.scaled_damage() * 1.06), "Firm 3 raises damage x1.06 (%.2f vs %.2f)" % [firm.scaled_damage(), dagger.scaled_damage()])
	_expect(is_equal_approx(soft.scaled_damage(), dagger.scaled_damage() * 0.94), "Soft 3 lowers damage x0.94")
	var helm = _craft(&"leather_helm", &"dried_hide", {})
	var tough = _craft(&"leather_helm", &"dried_hide", {"tough_fiber": 3})
	_expect(helm.scaled_armor() > 0.0 and is_equal_approx(tough.scaled_armor(), helm.scaled_armor() * 1.06), "Tough Fiber 3 raises armour x1.06 (%.2f vs %.2f)" % [tough.scaled_armor(), helm.scaled_armor()])
	var springy = _craft(&"work_axe", &"stone", {"high_elasticity": 3})
	_expect(is_equal_approx(springy.gather_power(), plain.gather_power() * 1.06), "High Elasticity 3 raises gather power x1.06")
	# The clamp: a sum past 15 % stops at 15 %, both ways.
	var over = _craft(&"work_axe", &"stone", {"high_density": 7})
	var under = _craft(&"stone_knife", &"stone", {"soft": 9})
	_expect(is_equal_approx(over.trait_mult(&"durability"), 1.15) and over.max_durability == roundi(base * 1.15), "High Density 7 (+21 %%) clamps at +15 %% (%d)" % over.max_durability)
	_expect(is_equal_approx(under.trait_mult(&"damage"), 0.85), "Soft 9 (-18 %) clamps at -15 %")
	# A trait that feeds nothing (TD9) and a material (not gear) change nothing.
	var sharp = _craft(&"work_axe", &"stone", {"sharp_section": 3})
	_expect(sharp.max_durability == plain.max_durability and is_equal_approx(sharp.trait_mult(&"damage"), 1.0), "Sharp Section stays inert on gear")
	var mat = IS.make(&"stone", 1, {"high_density": 3}, 1)
	_expect(is_equal_approx(mat.trait_mult(&"durability"), 1.0), "a material is not gear: no effect")
	# Gear from before P4 (no stamp) keeps its stats, and a stored max survives a save round trip.
	var old = IS.make(&"work_axe", 1, {"high_density": 3, "firm": 3}, 1)
	_expect(is_equal_approx(old.trait_mult(&"durability"), 1.0) and is_equal_approx(old.scaled_damage(), plain.scaled_damage()), "old gear with traits gains nothing (no recalculation)")
	old.max_durability = 47
	old.durability = 30
	var back = IS.from_dict(old.to_dict())
	_expect(back.max_durability == 47 and back.durability == 30 and is_equal_approx(back.trait_mult(&"durability"), 1.0), "old gear keeps its stored max after load (%d/%d)" % [back.durability, back.max_durability])
	var dense_back = IS.from_dict(dense.to_dict())
	_expect(dense_back.max_durability == dense.max_durability and is_equal_approx(dense_back.trait_mult(&"durability"), 1.09), "new gear keeps its trait max after load")
	# P3 repair shrinks the trait-adjusted max it finds (x0.8 per repair), and the trait line stays.
	var GR: GDScript = load("res://scripts/items/gear_repair.gd")
	var inv = load("res://scripts/items/inventory.gd").new(8)
	inv.add(IS.make(&"stone", 10, {}, 1))
	var fixed = _craft(&"work_axe", &"stone", {"high_density": 3})
	var m0: int = fixed.max_durability
	fixed.durability = 0
	var why: String = GR.repair(fixed, inv, &"workbench")
	_expect(why == "" and fixed.max_durability == maxi(1, roundi(m0 * 0.8)) and fixed.durability == fixed.max_durability, "repair takes the High Density max %d to %d ('%s')" % [m0, fixed.max_durability, why])
	_expect(is_equal_approx(fixed.trait_mult(&"durability"), 1.09) and IS.from_dict(fixed.to_dict()).max_durability == fixed.max_durability, "the repaired max is stored, not recomputed from traits on load")
	# The item card lists each effect.
	var lines: Array = []
	for r in PANEL.rows_for(dense):
		lines.append(str(r.text))
	_expect(lines.has("+9 % durability (High Density 3)"), "the card shows '+9 %% durability (High Density 3)' (%s)" % [lines])
	lines.clear()
	for r in PANEL.rows_for(over):
		lines.append(str(r.text))
	_expect(lines.has("+15 % durability (High Density 7, capped)"), "the card says when the clamp bites (%s)" % [lines])
	if _fails.is_empty():
		print("[t_traitgear] PASS")
		quit(0)
	else:
		print("[t_traitgear] FAIL count=%d" % _fails.size())
		quit(1)
