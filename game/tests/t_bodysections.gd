extends SceneTree
## BODY SECTIONS (owner: "I want to be able to click the intended body section"). For every modelled species and
## each model variant: every hurtbox capsule belongs to a named section, the core sections exist (head, torso, a leg),
## each data split (belly, frill, plates) and armoured section exists on that body, a section's own aim point lands
## back in that section (what a ranged shot aims at), and every crit spot sits inside a section, which is flagged crit.
## Usage: godot --headless --path game --script res://tests/t_bodysections.gd -> "[t_bodysections] PASS", exit 0.

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var BS: GDScript
var HB: GDScript
var CS: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_bodysections] %s %s" % ["ok  " if ok else "FAIL", what])

func _run() -> void:
	data = root.get_node("Data")
	BS = load("res://scripts/combat/body_sections.gd")
	HB = load("res://scripts/combat/hurtboxes.gd")
	CS = load("res://scripts/combat/crit_spots.gd")
	host = Node3D.new()
	root.add_child(host)
	var n := 0
	for id in data.creatures:
		var def = data.creature(StringName(id))
		if def == null or not CreatureDef.has_model(def.id):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/%s.json" % id))
		if not (raw is Dictionary and (raw as Dictionary).get("species") is String):
			continue
		for v in _models(def):
			await _check(def, v)
			n += 1
	_expect(n >= 20, "%d modelled bodies checked" % n)
	print("[t_bodysections] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _models(def) -> Array:
	var out := [&""]
	var mv: Dictionary = def.pipeline.get("model_variants", {})
	for v in mv:
		if mv[v] is Dictionary and (mv[v] as Dictionary).has("model"):
			out.append(StringName(str(v)))
	return out

func _check(def, variant: StringName) -> void:
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.spawn(def, variant)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 3:
		await physics_frame
	var tag := "%s%s" % [def.id, "/" + str(variant) if variant != &"" else ""]
	var hb = HB.of(c)
	if hb == null:
		_expect(false, "%s: has hurtboxes" % tag)
		c.queue_free()
		return
	var names: Array = BS.names(c)
	var unmapped := []
	for cap in hb.caps:
		if not BS.cap_section(c, cap) in names:
			unmapped.append(cap["part"])
	_expect(unmapped.is_empty(), "%s: all %d hurtboxes are in a section (%s)" % [tag, hb.caps.size(), ", ".join(names)])
	_expect(&"head" in names and &"torso" in names, "%s: has head and torso" % tag)
	_expect(names.any(func(s: StringName) -> bool: return str(s).contains("leg")), "%s: has a leg section" % tag)
	for s in names:
		_expect(not BS.caps_of(c, s).is_empty(), "%s: %s has capsules" % [tag, s])
		var at: Vector3 = BS.aim_point(c, s, false)
		_expect(BS.section_at(c, at) == s, "%s: aiming at %s lands in it (%s)" % [tag, s, BS.section_at(c, at)])
	var row: Dictionary = (BS.cfg().get("species", {}) as Dictionary).get(str(def.id), {})
	for sp in row.get("splits", []):
		_expect(StringName(str(sp["to"])) in names, "%s: split section %s exists" % [tag, sp["to"]])
	for a in row.get("armoured", []):
		_expect(StringName(str(a)) in names and BS.is_armoured(c, StringName(str(a))), "%s: armoured section %s exists" % [tag, a])
	var crits: Array = BS.crit_sections(c)
	for s in CS.world(c):
		var sec: StringName = BS.section_at(c, s["centre"])
		_expect(sec in names and sec in crits, "%s: crit spot %s is inside section %s (crit)" % [tag, s["name"], sec])
	c.queue_free()
	await physics_frame
