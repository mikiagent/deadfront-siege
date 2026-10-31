extends SceneTree
## SLOWLEVELS cross-skill gear (owner 2026-10-28: "Spikey armor, increases Butchering ability -> helps
## you grind for better gear"). Learning Tailoring's Spiky Armor node unlocks both recipes; wearing the
## pieces raises the effective Butchering level; unlearning refunds the SP and locks the recipes again.
## Usage: godot --headless --path game --script res://tests/t_skillgear.gd -> "[t_skillgear] PASS".

var _fails: PackedStringArray = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	_run()
	if _fails.is_empty():
		print("[t_skillgear] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_skillgear] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)

func _run() -> void:
	var SS: GDScript = load("res://scripts/skills/skill_state.gd")
	var Rules: GDScript = load("res://scripts/skills/skill_rules.gd")
	var Inv: GDScript = load("res://scripts/items/inventory.gd")
	var Stack: GDScript = load("res://scripts/items/item_stack.gd")
	var w := get_root().get_node("World")
	w.pioneer_level = 34  # character Lv. 35: SP to spend, cap above Lv. 30
	var sk: Node = SS.new()
	get_root().add_child(sk)
	sk.trees["tailoring"]["level"] = 30  # researched to the node's level
	sk.trees["butchering"]["level"] = 4
	sk._recount_sp()
	for rid in ["spiky_armor", "spiky_armor_helmet"]:
		_expect(str(Rules.recipe_block(sk, rid)) != "", "%s is locked before the node is learned" % rid)
	var sp0: int = sk.sp_now()
	_expect(sk.unlock("tailoring", "spiky_armor"), "Spiky Armor can be learned at Tailoring Lv. 30")
	_expect(sk.sp_now() == sp0 - 4, "learning costs its 4 SP (%d -> %d)" % [sp0, sk.sp_now()])
	for rid in ["spiky_armor", "spiky_armor_helmet"]:
		_expect(str(Rules.recipe_block(sk, rid)) == "", "learning the node unlocks %s (%s)" % [rid, Rules.recipe_block(sk, rid)])
	# Wearing it: a stand-in survivor with the real SkillState and Inventory.
	var src := GDScript.new()
	src.source_code = "extends Node\nvar skills\nvar inventory\n"
	src.reload()
	var who: Node = src.new()
	who.skills = sk
	who.inventory = Inv.new()
	_expect(int(Rules.effective_level(who, "butchering")) == 4, "bare, Butchering acts at its tree level 4")
	for pair in [["spiky_armor", &"body"], ["spiky_armor_helmet", &"head"]]:
		who.inventory.add(Stack.make(StringName(pair[0])))
		_expect(who.inventory.equip(pair[1], StringName(pair[0])), "%s can be worn" % pair[0])
	var worn: int = Rules.effective_level(who, "butchering")
	_expect(worn == 14, "wearing both pieces raises Butchering to 14 (got %d)" % worn)
	_expect(sk.level_of("butchering") == 4, "the tree level itself is unchanged (research reads it)")
	who.inventory.unequip(&"head")
	_expect(int(Rules.effective_level(who, "butchering")) == 9, "taking the helmet off drops it to 9")
	# Unlearn: SP back, recipes locked.
	_expect(sk.refund("tailoring", "spiky_armor"), "Unlearn refunds the node")
	_expect(sk.sp_now() == sp0, "the SP come back (%d)" % sk.sp_now())
	_expect(str(Rules.recipe_block(sk, "spiky_armor")) != "", "after Unlearn the recipe is locked again")
	who.free()
	get_root().remove_child(sk)
	sk.free()
	w.pioneer_level = 0
