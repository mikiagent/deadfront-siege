extends SceneTree
## OUTPUTS (docs/design/durango-informed-improvements.md §7): one recipe, several outputs by the slot-1
## material. `outputs_by_primary` is keyed by the primary's category, then its material tier; `output`
## is the fallback. Checks: each key and the fallback make the right item; preview == crafted result;
## slot-1 traits carry; a recipe without the key is unchanged; save/load keeps the crafted item; the
## server craft op (act.craft) makes the same item; the craft screens read the same row.
## No shipped recipe uses the key yet (owner decision pending), so the test builds its own recipes in
## memory from the shipped work recipes and registers them in Data.recipes for the server path.
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
	_register()
	_test_keys()
	_test_preview_equals_result()
	_test_traits_carry()
	_test_plain_unchanged()
	_test_save_load()
	_test_server()
	_unregister()
	if _fails.is_empty():
		print("[t_outputs] PASS")
	else:
		print("[t_outputs] FAILED %d" % _fails.size())
	quit(0 if _fails.is_empty() else 1)

## In-memory keyed copies of the shipped work recipes: stone, bone and flint keys (flint's declared tier
## tier_flint wins over its `stone` category), `output` as the fallback.
const KEYED := {
	&"t_out_knife": [&"improvised_stone_knife", "stone_knife_work", "bone_knife", "flint_knife"],
	&"t_out_axe": [&"work_axe", "work_axe", "bone_axe", "flint_axe"],
	&"t_out_pick": [&"work_pick", "work_pick", "bone_pick", "flint_pick"],
}

func _register() -> void:
	var data: Node = root.get_node("Data")
	for rid: StringName in KEYED:
		var row: Array = KEYED[rid]
		var rec: Dictionary = (CR.recipe(row[0]) as Dictionary).duplicate(true)
		rec["id"] = str(rid)
		rec["slots"][0]["category"] = "blade_mat"
		rec["outputs_by_primary"] = {"stone": {"id": row[1], "count": 1}, "bone": {"id": row[2], "count": 1}, "flint": {"id": row[3], "count": 1}}
		data.recipes[rid] = rec

func _unregister() -> void:
	var data: Node = root.get_node("Data")
	for rid: StringName in KEYED:
		data.recipes.erase(rid)

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
	for rid: StringName in KEYED:
		var rec: Dictionary = CR.recipe(rid)
		_expect(rec.get("outputs_by_primary") is Dictionary, "%s carries outputs_by_primary" % rid)
		var stone_id: String = KEYED[rid][1]
		var bone_id: String = KEYED[rid][2]
		_expect(_id_for(rec, &"flint") == KEYED[rid][3], "%s: flint (tier key) -> %s (got %s)" % [rid, KEYED[rid][3], _id_for(rec, &"flint")])
		_expect(_id_for(rec, &"stone") == stone_id, "%s: stone -> %s (got %s)" % [rid, stone_id, _id_for(rec, &"stone")])
		_expect(_id_for(rec, &"bone") == bone_id, "%s: bone -> %s (got %s)" % [rid, bone_id, _id_for(rec, &"bone")])
		_expect(_id_for(rec, &"raptor_bone") == bone_id, "%s: raptor_bone (category bone) -> %s" % [rid, bone_id])
		_expect(rec["output"]["id"] == stone_id, "%s: the fallback is the stone row" % rid)
		# metal_shard has no tier category; its computed tier (by hardness, ProgressionScaling) is flint.
		_expect(_id_for(rec, &"metal_shard") == KEYED[rid][3], "%s: metal_shard reads its computed tier flint (got %s)" % [rid, _id_for(rec, &"metal_shard")])
		# Without a flint key nothing matches metal_shard -> the `output` fallback.
		var no_flint: Dictionary = rec.duplicate(true)
		(no_flint["outputs_by_primary"] as Dictionary).erase("flint")
		_expect(_id_for(no_flint, &"metal_shard") == str(rec["output"]["id"]), "%s: an unmatched metal_shard falls back to output (got %s)" % [rid, _id_for(no_flint, &"metal_shard")])
		_expect(str(CR.output_for(rec, null).get("id", "")) == str(rec["output"]["id"]), "%s: no slot-1 instance -> output" % rid)
		# The craft screens (D1 list/detail, D3 result) read the same row.
		var inv = _bag(&"bone")
		_expect(str(UI.output_row(inv, rec).get("id", "")) == bone_id, "%s: CraftUI.output_row shows %s for a bone bag" % [rid, bone_id])
	# The shipped recipes carry no key: no shipped recipe uses the mechanism yet.
	for r: Variant in CR.all_recipes():
		_expect(not (r as Dictionary).has("outputs_by_primary") or str((r as Dictionary).get("id", "")).begins_with("t_out_"),
			"shipped recipe %s has no outputs_by_primary" % (r as Dictionary).get("id", ""))

func _test_preview_equals_result() -> void:
	for rid: StringName in KEYED:
		var rec: Dictionary = CR.recipe(rid)
		for head: StringName in [&"stone", &"bone", &"metal_shard"]:  # flint does not fill a blade_mat slot
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
	var rec: Dictionary = CR.recipe(&"t_out_axe")
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
	var rec: Dictionary = (CR.recipe(&"t_out_axe") as Dictionary).duplicate(true)
	rec.erase("outputs_by_primary")
	_expect(_id_for(rec, &"bone") == "work_axe" and _id_for(rec, &"stone") == "work_axe", "the axe without the key makes work_axe")
	for rid: StringName in [&"work_axe", &"bone_axe", &"twine", &"flint_knife"]:
		var r: Dictionary = CR.recipe(rid)
		_expect(not r.has("outputs_by_primary") and _id_for(r, &"bone") == str(r["output"]["id"]), "%s is unchanged" % rid)

func _test_save_load() -> void:
	var rec: Dictionary = CR.recipe(&"t_out_knife")
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
	var rec: Dictionary = CR.recipe(&"t_out_knife")
	var inv = ch.inventory()
	var picks: Array[int] = CR.default_picks(inv, rec)
	var offline = CR.preview(inv, rec, picks)
	var made: Dictionary = store.apply("act.craft", 1, {"recipe_id": "t_out_knife", "picks": picks}, 2)
	var r: Dictionary = made.get("r", {})
	print("[t_outputs] server craft ok=%s r=%s" % [bool(made.get("ok", false)), r])
	_expect(bool(made.get("ok", false)) and not bool(r.get("failed", false)), "the server craft succeeds (%s)" % str(made.get("err", "")))
	_expect(str(r.get("item", "")) == "bone_knife" and offline != null and str(offline.def_id) == "bone_knife",
		"the server makes the same item as the preview (server %s, preview %s)" % [r.get("item", ""), offline.def_id if offline else null])
