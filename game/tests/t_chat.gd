extends SceneTree
## Region chat checks (spec 20): `--headless --path game --script res://tests/t_chat.gd`.
## The checks (tests/chat_checks.gd) reach autoloads, which `--script` has not made yet when it
## compiles this file, so they load on the first frame after Data. Prints "[t_chat] PASS" (exit 0)
## or one FAIL line per failed check and "[t_chat] FAIL count=N" (exit 1).

var failures: Array[String] = []
var _checks: RefCounted  # held here so the coroutine's instance outlives its awaits
var _started := false

func _process(_delta: float) -> bool:
	if not _started and get_root() != null and get_root().get_node_or_null("Data") != null:
		_started = true
		_main()
	return false

func _main() -> void:
	var script := load("res://tests/chat_checks.gd") as GDScript
	if script == null or not script.can_instantiate():  # a parse error must fail the run, not exit 0
		failures.append("tests/chat_checks.gd did not compile")
	else:
		_checks = script.new()
		await _checks.run(self, func (ok: bool, msg: String) -> void:
			if not ok:
				failures.append(msg))
	for f in failures:
		print("[t_chat] FAIL %s" % f)
	print("[t_chat] PASS" if failures.is_empty() else "[t_chat] FAIL count=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
