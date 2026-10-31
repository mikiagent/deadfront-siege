extends SceneTree
## BONEPARTS checks: every carcass species gives its own named bone parts, the old ids still load,
## every recipe slot that took bone still has inputs, and every part has its own rendered icon
## (never the old skeleton glyph). Run: Godot --headless --path game --script res://tests/t_boneparts.gd

## The bone-type parts each species' carcass offers (data/butchering.json, base and rare rows).
const PARTS := {
	"velociraptor": ["raptor_bone", "raptor_talon"],
	"deinonychus": ["raptor_bone", "raptor_talon"],
	"utahraptor": ["raptor_bone", "raptor_talon"],
	"raptor": ["raptor_bone", "raptor_talon"],
	"compsognathus": ["hollow_bone"],
	"coelophysis": ["hollow_bone"],
	"gallimimus": ["hollow_bone"],
	"dilophosaurus": ["hollow_bone"],
	"megaloceros": ["bone"],
	"smilodon": ["bone"],
	"protoceratops": ["stout_leg_bone", "dense_bone", "frill_plate"],
	"zebraceratops": ["stout_leg_bone", "brow_horn", "frill_plate"],
	"triceratops": ["large_leg_bone", "brow_horn", "frill_plate"],
	"styracosaurus": ["large_leg_bone", "brow_horn", "frill_plate"],
	"woolly_rhino": ["large_leg_bone", "brow_horn"],
	"stegosaurus": ["large_leg_bone", "tail_spike", "dorsal_plate"],
	"ankylosaurus": ["large_leg_bone", "tail_club", "armor_scute"],
	"allosaurus": ["large_leg_bone"],
	"brachiosaurus": ["large_leg_bone", "dense_bone", "armor_scute"],
	"tarbosaurus": ["large_leg_bone", "dense_bone", "skull_plate"],
	"tyrannosaurus": ["large_leg_bone", "dense_bone", "skull_plate"],
}
## Recipe categories a bone part may fill; a part keeps the ones of the generic id it replaced.
const BONE_CATS := ["bone", "dense_bone", "talon", "scute", "tier_bone"]
const OLD_IDS := ["bone", "raptor_bone", "raptor_talon", "dense_bone", "armor_scute"]
const GLYPH := "res://assets/icons/sym/raptor_bone.png"

var failures: Array[String] = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var data: Node = get_root().get_node("Data")
	_test_species(data)
	_test_old_ids(data)
	_test_recipes(data)
	_test_icons()
	if failures.is_empty():
		print("[t_boneparts] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_boneparts] FAIL %s" % f)
		quit(1)
	return true

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _all_parts() -> Array:
	var out := []
	for sp in PARTS:
		for id in PARTS[sp]:
			if not out.has(id):
				out.append(id)
	return out

func _test_species(data: Node) -> void:
	var tables: Dictionary = data.butcher_tables
	for sp: String in tables:
		_check(PARTS.has(sp), "%s has a carcass but no bone part list here" % sp)
	for sp: String in PARTS:
		var got := []
		for kind in ["base", "rare"]:
			for row: Dictionary in tables.get(sp, {}).get(kind, []):
				var def: ItemDef = data.item(StringName(str(row["id"])))
				if def != null and BONE_CATS.any(func(c: String) -> bool: return def.has_category(StringName(c))):
					if not got.has(str(row["id"])):
						got.append(str(row["id"]))
		got.sort()
		var want: Array = (PARTS[sp] as Array).duplicate()
		want.sort()
		_check(got == want, "%s bone parts %s, want %s" % [sp, got, want])
		for id: String in got:
			var def: ItemDef = data.item(StringName(id))
			_check(def.display_name != "" and def.display_name != "Bone" and def.display_name != "Raptor Bone",
				"%s part %s has a specific name (%s)" % [sp, id, def.display_name])

func _test_old_ids(data: Node) -> void:
	# Saves hold ids; the old ones are kept (renamed only), so a save row loads unchanged.
	for id: String in OLD_IDS:
		var s: Variant = (load("res://scripts/items/item_stack.gd") as GDScript).from_dict({"id": id, "count": 2, "level": 5})
		_check(s != null and s.def_id == StringName(id) and data.item(s.def_id) != null, "old id %s still loads" % id)

func _test_recipes(data: Node) -> void:
	var recipes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
	var n := 0
	for r: Dictionary in (recipes as Dictionary).get("recipes", []):
		for slot: Dictionary in r.get("slots", []):
			var cat := str(slot.get("category", ""))
			if not BONE_CATS.has(cat):
				continue
			n += 1
			var fits := 0
			for id in _all_parts():
				if data.item(StringName(id)).has_category(StringName(cat)):
					fits += 1
			_check(fits > 0, "recipe %s slot %s takes no bone part" % [r.get("id", ""), cat])
			for id in slot.get("allowed_ids", []):
				_check(data.item(StringName(str(id))) != null, "recipe %s allows unknown %s" % [r.get("id", ""), id])
	_check(n > 0, "found recipes with bone slots")
	# Each new part keeps every category the generic id it replaced had, so recipes accept it.
	for pair in [["hollow_bone", "bone"], ["large_leg_bone", "bone"], ["stout_leg_bone", "raptor_bone"],
			["brow_horn", "dense_bone"], ["tail_spike", "dense_bone"], ["tail_club", "dense_bone"],
			["dorsal_plate", "armor_scute"], ["frill_plate", "armor_scute"], ["skull_plate", "armor_scute"]]:
		var a: ItemDef = data.item(StringName(pair[0]))
		var b: ItemDef = data.item(StringName(pair[1]))
		# Keeps every one; a part may add its own shape tags (CRAFTRADIAL: leg bones are thick_pillar).
		_check(a != null and b != null and b.categories.all(func (c: StringName) -> bool: return c in a.categories), "%s keeps %s categories" % pair)
		_check(_gate(pair[0]) == _gate(pair[1]), "%s has the same Butchering gate as %s" % pair)

## The trees.json node whose butcher effect lists `id` ("" = ungated).
func _gate(id: String) -> String:
	var trees: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/trees.json"))
	return _find_gate(trees, id, "")

func _find_gate(o: Variant, id: String, node: String) -> String:
	if o is Dictionary:
		var d := o as Dictionary
		var here := str(d.get("id", node)) if d.has("effects") else node
		if str(d.get("type", "")) == "butcher" and (d.get("items", []) as Array).has(id):
			return node
		for v in d.values():
			var g := _find_gate(v, id, here)
			if g != "":
				return g
	elif o is Array:
		for v in o:
			var g := _find_gate(v, id, node)
			if g != "":
				return g
	return ""

func _test_icons() -> void:
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/icons/render/manifest.json"))
	var items: Dictionary = (man as Dictionary).get("items", {})
	for id: String in _all_parts():
		var png := "res://assets/icons/render/%s.png" % id
		_check(items.has(id) and FileAccess.file_exists(png), "%s has a rendered icon" % id)
		var p: String = (load("res://scripts/ui/item_icons.gd") as GDScript).path_for(StringName(id))
		_check(p == png, "%s symbol lookup shows its render, not %s" % [id, p])
		_check(p != GLYPH, "%s no longer uses the skeleton glyph" % id)
