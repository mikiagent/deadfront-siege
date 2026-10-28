extends SceneTree
## ECON: the vault bridge between server characters and the economy (VaultBridge), end to end
## over CharacterStore + EconStore: deposits, sales, pets as cages, crash recovery, and a
## 3000-op fuzz with both stores' invariants after every op. The engine's own suite is
## economy_tests.gd (run_all). Exit 0 on PASS, 1 on any failure.

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var script := load("res://tests/econ_bridge_checks.gd") as GDScript
	if script == null or not script.can_instantiate(): # a parse error must fail the run, not exit 0
		print("[t_econ] FAIL tests/econ_bridge_checks.gd did not compile")
		quit(1)
		return true
	var failures: Array = (script.new() as RefCounted).call("run")
	for f in failures:
		print("[t_econ] FAIL %s" % f)
	print("[t_econ] PASS" if failures.is_empty() else "[t_econ] FAIL count=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
	return true
