extends SceneTree
## TRIKELAND: the triceratops spawns where its island table names it (swamp_55, NOBOXES only lets a species with a
## model spawn), draws its rigged GLB with no box parts, and every clip in its pipeline list is authored and loaded.
## Run: Godot --headless --path game --script res://tests/t_trikeland.gd -> "[t_trikeland] PASS", 0/1.

var _fails: PackedStringArray = []
var _started := false

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_trikeland] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _run() -> void:
	var W: Node = root.get_node("World")
	var CD: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(CD.has_model(&"triceratops"), "triceratops has a model")
	_expect(not CD.allow_placeholder, "placeholders off")
	W.creation_pending = true
	var host := Node3D.new()
	root.add_child(host)
	(load("res://scripts/dev/lab_kit.gd") as GDScript).build(host)
	W.load_island(host, &"swamp_55", Vector3(0, 1, 12), false)
	await process_frame
	var trikes: Array = []
	for c in get_nodes_in_group("creatures"):
		if not c.is_queued_for_deletion() and c.def and c.def.id == &"triceratops":
			trikes.append(c)
	_expect(trikes.size() > 0, "swamp_55 spawns triceratops (%d)" % trikes.size())
	var def = root.get_node("Data").creature(&"triceratops")
	for c in trikes.slice(0, 1):
		_expect(c.view != null and c.view.using_glb and c.view._body == null, "it draws the GLB, no boxes")
		for clip in def.pipeline.get("clips", []):
			_expect(c.view.rig != null and c.view.rig.has_clip(StringName(clip)), "clip %s loaded" % clip)
	if _fails.is_empty():
		print("[t_trikeland] PASS")
		quit(0)
	else:
		print("[t_trikeland] FAIL %d" % _fails.size())
		quit(1)
