extends SceneTree
## Wild AI unit checks (W1-AI). Run: godot --headless --path game --script res://tests/t_ai.gd
## Prints "[t_ai] PASS" or "[t_ai] FAIL ..." lines and quits 0/1.

var _done := false

## The cases use the Data autoload, which does not exist while --script compiles this file, so
## they live in t_ai_cases.gd and are loaded on the first frame that has it.
func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var cases: RefCounted = load("res://tests/t_ai_cases.gd").new()
	var failures: Array[String] = cases.run(get_root())
	if failures.is_empty():
		print("[t_ai] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_ai] FAIL %s" % f)
		quit(1)
	return true
