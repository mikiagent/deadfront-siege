extends SceneTree
## Runs tests/net_checks.gd (the network core over real localhost sockets):
## `--headless --path game --script res://tests/net_tests.gd`. `--script` compiles this file before
## the autoloads exist, so the checks (which use them) load on the first frame after Data does.
## Exit 0 after [net_tests] PASS, 1 after a FAIL line for each failed check.

var failures: Array[String] = []
var _checks: RefCounted  # held here so the coroutine's instance outlives its awaits
var _started := false

func _process(_delta: float) -> bool:
	if not _started and get_root() != null and get_root().get_node_or_null("Data") != null:
		_started = true
		_main()
	return false

func _main() -> void:
	var script := load("res://tests/net_checks.gd") as GDScript
	if script == null or not script.can_instantiate():  # a parse error must fail the run, not exit 0
		failures.append("tests/net_checks.gd did not compile")
	else:
		_checks = script.new()
		await _checks.run(self, func (ok: bool, msg: String) -> void:
			if not ok:
				failures.append(msg))
	for f in failures:
		print("[net_tests] FAIL %s" % f)
	print("[net_tests] PASS" if failures.is_empty() else "[net_tests] FAIL count=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
