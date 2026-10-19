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
	var checks: RefCounted = (load("res://scripts/server/domain_checks.gd") as GDScript).new()
	var failures: Array = checks.call("run")
	if failures.is_empty():
		print("[%s] PASS" % tag)
		quit(0)
	else:
		for f in failures:
			print("[%s] FAIL %s" % [tag, f])
		quit(1)
	return true
