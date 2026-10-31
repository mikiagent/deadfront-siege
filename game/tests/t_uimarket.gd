extends SceneTree
## UIMARKET: the Island Market screens (Buy / My Market / Sell). Offline (the player build): every
## tab shows the honest offline card and sends nothing. On the local test server (MarketHarness,
## the real VaultBridge): Buy lists one row per instance and buys one, Receive All takes storage into
## the bag, Sell lists one exact instance, My Market cancels it. At 1600x900 and 844x390: the key
## controls are on screen, >= 64 px, and the header, rail and panes do not overlap.
## Run: godot --headless --path game --script res://tests/t_uimarket.gd -> "[t_uimarket] PASS".

var _done := false

## Returns false until the checks finish: a SceneTree script that returns true from _process ends
## the main loop, which would cut the awaiting checks off mid-run.
func _process(_delta: float) -> bool:
	if _done or get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	_run()
	return false

## The checks reach autoloads (Data, World), so they compile on the first frame, not with this file.
func _run() -> void:
	var script := load("res://tests/uimarket_checks.gd") as GDScript
	if script == null or not script.can_instantiate(): # a parse error must fail the run, not exit 0
		print("[t_uimarket] FAIL tests/uimarket_checks.gd did not compile")
		quit(1)
		return
	var failures: Array = await (script.new() as RefCounted).call("run", self)
	for f in failures:
		print("[t_uimarket] FAIL %s" % f)
	print("[t_uimarket] PASS" if failures.is_empty() else "[t_uimarket] FAIL count=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
