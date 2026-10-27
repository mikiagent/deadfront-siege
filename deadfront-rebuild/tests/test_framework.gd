## Tiny deterministic test harness. No engine test plugin, no scene tree.
##
## A test runner script extends this, calls the *_test.gd suites (each a RefCounted
## with run(t) methods), and exits non-zero if any assertion failed. Every check
## reports its own name so a failure names the exact contract that broke.
class_name TestCase
extends RefCounted

var failures: Array[String] = []
var checks: int = 0
var _suite: String = ""


func suite(name: String) -> void:
	_suite = name


func ok(condition: bool, what: String) -> bool:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [_suite, what])
		print("  FAIL  [%s] %s" % [_suite, what])
	return condition


func eq(actual: Variant, expected: Variant, what: String) -> bool:
	var pass_check: bool = actual == expected
	checks += 1
	if not pass_check:
		failures.append("%s: %s (expected %s, got %s)" % [_suite, what, str(expected), str(actual)])
		print("  FAIL  [%s] %s (expected %s, got %s)" % [_suite, what, str(expected), str(actual)])
	return pass_check


func dict_eq(actual: Dictionary, expected: Dictionary, what: String) -> bool:
	var same: bool = actual == expected
	checks += 1
	if not same:
		failures.append("%s: %s\n    expected %s\n    got      %s" % [_suite, what, JSON.stringify(expected), JSON.stringify(actual)])
		print("  FAIL  [%s] %s\n    expected %s\n    got      %s" % [_suite, what, JSON.stringify(expected), JSON.stringify(actual)])
	return same
