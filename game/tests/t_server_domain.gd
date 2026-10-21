extends SceneTree
## W1-SRVDOM: server character store and intent handlers (game/scripts/server/).
## The checks use Crafting and friends, which need the Data autoload, so they load on the
## first frame after it exists (run_all.gd's pattern). Exit 0 on PASS, 1 on any failure.

var tag := "t_server_domain"
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var script := load("res://tests/srvdom_checks.gd") as GDScript
	if script == null or not script.can_instantiate(): # a parse error must fail the run, not exit 0
		print("[%s] FAIL tests/srvdom_checks.gd did not compile" % tag)
		quit(1)
		return true
	var failures: Array = (script.new() as RefCounted).call("run")
	if failures.is_empty():
		print("[%s] PASS" % tag)
		quit(0)
	else:
		for f in failures:
			print("[%s] FAIL %s" % [tag, f])
		quit(1)
	return true
