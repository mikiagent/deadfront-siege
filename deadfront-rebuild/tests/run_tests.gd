## Headless typed test runner for the M0 core.
##
## Run with:
##   <godot> --headless --path deadfront-rebuild --script res://tests/run_tests.gd
##
## Exits 0 only when every required suite reports no failures; exits 1 otherwise.
## No scene tree is used by the domain suites, so this is a pure headless run.
extends SceneTree

const SUITES: Array[String] = [
	"res://tests/identity_test.gd",
	"res://tests/transfer_test.gd",
	"res://tests/fnd001_fixture_test.gd",
	"res://tests/idempotence_test.gd",
	"res://tests/property_test.gd",
]


func _initialize() -> void:
	var t: TestCase = TestCase.new()
	var started: int = Time.get_ticks_msec()
	print("[m0-core] running %d suites" % SUITES.size())
	var suites_run: int = 0

	for path: String in SUITES:
		var script: Script = load(path) as Script
		if script == null:
			t.suite(path)
			t.ok(false, "suite script failed to load")
			continue
		var suite_obj: RefCounted = script.new() as RefCounted
		if suite_obj == null or not suite_obj.has_method("run"):
			t.suite(path)
			t.ok(false, "suite script has no run(t) method")
			continue
		print("[m0-core] suite %s" % path)
		suite_obj.call("run", t)
		suites_run += 1

	var elapsed: int = Time.get_ticks_msec() - started
	print("[m0-core] suites run: %d/%d" % [suites_run, SUITES.size()])
	print("[m0-core] %d checks, %d failures, %d ms" % [t.checks, t.failures.size(), elapsed])
	# A suite that silently did nothing would otherwise look like a pass.
	if suites_run != SUITES.size():
		t.failures.append("runner: only %d of %d suites ran" % [suites_run, SUITES.size()])
	if t.checks == 0:
		t.failures.append("runner: no checks were executed")
	if t.failures.is_empty():
		print("M0 CORE TESTS PASS")
		quit(0)
		return

	print("M0 CORE TESTS FAIL")
	for failure: String in t.failures:
		print("  - %s" % failure)
	quit(1)
