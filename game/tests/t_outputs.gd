extends SceneTree
## OUTPUTS (docs/design/durango-informed-improvements.md §7): one recipe, several outputs by the slot-1
## material. `outputs_by_primary` is keyed by the primary's category, then its material tier; `output`
## is the fallback. Checks: each key and the fallback make the right item; preview == crafted result;
## slot-1 traits carry; a recipe without the key is unchanged; save/load keeps the crafted item; the
## server craft op (act.craft) makes the same item; the craft screens read the same row.
## Run: Godot --headless --path game --script res://tests/t_outputs.gd -> "[t_outputs] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var IS: GDScript
var INV: GDScript
var CR: GDScript
var SS: GDScript
var LT: GDScript
var UI: GDScript

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("[t_outputs] FAIL watchdog")
		quit(1))

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_outputs] FAIL %s" % what)

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	CR = load("res://scripts/items/crafting.gd")
	SS = load("res://scripts/core/save_sanitizer.gd")
	LT = load("res://scripts/gather/loot_tables.gd")
	UI = load("res://scripts/ui/craft_ui.gd")
	_test_keys()
	_test_preview_equals_result()
	_test_traits_carry()
	_test_plain_unchanged()
	_test_save_load()
	_test_server()
	if _fails.is_empty():
		print("[t_outputs] PASS")
	else:
		print("[t_outputs] FAILED %d" % _fails.size())
	quit(0 if _fails.is_empty() else 1)

## A bag with one head material, a branch handle and twine lashing.
func _bag(head: StringName, attrs: Dictionary = {}) -> Object:
	var inv = INV.new(8)
	inv.add(IS.make(head, 2, attrs, 5))
	inv.add(IS.make(&"branch", 1, {}, 5))
	inv.add(IS.make(&"twine", 1, {}, 5))
	return inv

func _id_for(rec: Dictionary, head: StringName) -> String:
	return str(CR.output_for(rec, IS.make(head, 1, {}, 5)).get("id", ""))

func _test_keys() -> void:
	var want := {
		&"improvised_stone_knife": ["stone_knife_work", "bone_knife"],
		&"work_axe": ["work_axe", "bone_axe"],
		&"work_pick": ["work_pick", "bone_pick"],
	}
	for rid: StringName in want:
		var rec: Dictionary = CR.recipe(rid)
		_expect(rec.get("outputs_by_primary") is Dictionary, "%s carries outputs_by_primary" % rid)
		var stone_id: String = want[rid][0]
		var bone_id: String = want[rid][1]
		_expect(_id_for(rec, &"stone") == stone_id, "%s: stone -> %s (got %s)" % [rid, stone_id, _id_for(rec, &"stone")])
		_expect(_id_for(rec, &"bone") == bone_id, "%s: bone -> %s (got %s)" % [rid, bone_id, _id_for(rec, &"bone")])
		_expect(_id_for(rec, &"raptor_bone") == bone_id, "%s: raptor_bone (category bone) -> %s" % [rid, bone_id])
		# metal_shard: no key matches its categories or tier -> the `output` fallback.
		_expect(_id_for(rec, &"metal_shard") == str(rec["output"]["id"]), "%s: metal_shard falls back to output (got %s)" % [rid, _id_for(rec, &"metal_shard")])
		_expect(str(CR.output_for(rec, null).get("id", "")) == str(rec["output"]["id"]), "%s: no slot-1 instance -> output" % rid)
		# The craft screens (D1 list/detail, D3 result) read the same row.
		var inv = _bag(&"bone")
		_expect(str(UI.output_row(inv, rec).get("id", "")) == bone_id, "%s: CraftUI.output_row shows %s for a bone bag" % [rid, bone_id])
	# A tier key: flint's categories (stone, tier_flint) miss, its material tier `flint` hits.
	var tiered := {"id": "t_tiered", "slots": [{"category": "stone", "count": 1, "primary": true}],
		"output": {"id": "work_axe", "count": 1}, "outputs_by_primary": {"flint": {"id": "flint_axe", "count": 1}}}
	_expect(_id_for(tiered, &"flint") == "flint_axe", "a tier key picks flint_axe for flint (got %s)" % _id_for(tiered, &"flint"))
	_expect(_id_for(tiered, &"stone") == "work_axe", "a tier-keyed recipe falls back for stone")

func _test_preview_equals_result() -> void:
	for rid: StringName in [&"improvised_stone_knife", &"work_axe", &"work_pick"]:
		var rec: Dictionary = CR.recipe(rid)
		for head: StringName in [&"stone", &"bone", &"metal_shard"]:
			var inv = _bag(head)
			var picks: Array[int] = CR.default_picks(inv, rec)
			var pv = CR.preview(inv, rec, picks)
			var plan: Dictionary = CR.plan_craft(rec, inv, picks, CR.ability_of(60), 5, 60, RandomNumberGenerator.new())
			plan["outcome"] = {"success": true}
			var res: Dictionary = CR.run_plan(rec, inv, plan)
			var made = res.get("item", null)
			_expect(pv != null and made != null and pv.def_id == made.def_id,
				"%s/%s: preview %s == result %s" % [rid, head, pv.def_id if pv else null, made.def_id if made else null])
			_expect(made != null and str(made.def_id) == _id_for(rec, head), "%s/%s: result is the keyed item" % [rid, head])

func _test_traits_carry() -> void:
	var rec: Dictionary = CR.recipe(&"work_axe")
	var traits: Array = LT.material_traits(&"bone")
	_expect(not traits.is_empty(), "bone has rare traits to carry")
	if traits.is_empty():
		return
	var t := str(traits[0])
	var inv = _bag(&"bone", {t: true})
	var picks: Array[int] = CR.default_picks(inv, rec)
	var pv = CR.preview(inv, rec, picks)
	_expect(pv != null and pv.def_id == &"bone_axe" and pv.attributes.get(t, false) == true,
		"slot-1 rare %s carries into the bone axe (%s)" % [t, pv.attributes if pv else null])
	_expect(pv != null and str(pv.attributes.get("material_tier", "")) == "bone", "the bone axe records material_tier bone")

func _test_plain_unchanged() -> void:
	# The same recipe with the key removed makes the old single output whatever slot 1 is.
	var rec: Dictionary = (CR.recipe(&"work_axe") as Dictionary).duplicate(true)
	rec.erase("outputs_by_primary")
	_expect(_id_for(rec, &"bone") == "work_axe" and _id_for(rec, &"stone") == "work_axe", "work_axe without the key makes work_axe")
	for rid: StringName in [&"bone_axe", &"twine", &"flint_knife"]:
		var r: Dictionary = CR.recipe(rid)
		_expect(not r.has("outputs_by_primary") and _id_for(r, &"bone") == str(r["output"]["id"]), "%s is unchanged" % rid)

func _test_save_load() -> void:
	var rec: Dictionary = CR.recipe(&"improvised_stone_knife")
	var inv = _bag(&"bone")
	var picks: Array[int] = CR.default_picks(inv, rec)
	var plan: Dictionary = CR.plan_craft(rec, inv, picks, CR.ability_of(60), 5, 60, RandomNumberGenerator.new())
	plan["outcome"] = {"success": true}
	var made = CR.run_plan(rec, inv, plan).get("item", null)
	_expect(made != null and made.def_id == &"bone_knife", "the bone knife was crafted")
	if made == null:
		return
	var raw: Variant = JSON.parse_string(JSON.stringify(inv.to_array()))
	var clean: Dictionary = SS.clean({"player": {"inventory": raw}, "player_name": "Outputs"})
	var back = INV.new(8)
	back.load_array(clean.get("player", {}).get("inventory", []))
	var found = null
	for s in back.slots:
		if s and s.def_id == &"bone_knife":
			found = s
	_expect(found != null and found.uid == made.uid and found.level == made.level
		and str(found.attributes.get("material_tier", "")) == "bone",
		"the bone knife survives save -> sanitizer -> load (%s)" % (found.to_dict() if found else null))

func _test_server() -> void:
	var WF: GDScript = load("res://scripts/server/world_facade.gd")
	var ST: GDScript = load("res://scripts/server/character_store.gd")
	var world = WF.new()
	var store = ST.new(world, "", 7)
	store.apply("char.create", 1, {"name": "Outputs"}, 1)
	var ch = store.character(1)
	ch.d.skills["weapon_tools"] = {"level": 60, "xp": 0.0, "unlocked": []}
	ch.d.bag[0] = IS.make(&"bone", 2, {}, 5).to_dict()
	ch.d.bag[1] = IS.make(&"branch", 1, {}, 5).to_dict()
	ch.d.bag[2] = IS.make(&"twine", 1, {}, 5).to_dict()
	var rec: Dictionary = CR.recipe(&"improvised_stone_knife")
	var inv = ch.inventory()
	var picks: Array[int] = CR.default_picks(inv, rec)
	var offline = CR.preview(inv, rec, picks)
	var made: Dictionary = store.apply("act.craft", 1, {"recipe_id": "improvised_stone_knife", "picks": picks}, 2)
	var r: Dictionary = made.get("r", {})
	print("[t_outputs] server craft ok=%s r=%s" % [bool(made.get("ok", false)), r])
	_expect(bool(made.get("ok", false)) and not bool(r.get("failed", false)), "the server craft succeeds (%s)" % str(made.get("err", "")))
	_expect(str(r.get("item", "")) == "bone_knife" and offline != null and str(offline.def_id) == "bone_knife",
		"the server makes the same item as the preview (server %s, preview %s)" % [r.get("item", ""), offline.def_id if offline else null])
