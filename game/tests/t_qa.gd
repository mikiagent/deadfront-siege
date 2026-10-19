extends SceneTree
## Unit checks for the gate helpers themselves (LabResult verdicts, screenshot exposure maths).
## Run: godot --headless --path game --script res://tests/t_qa.gd

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var t := LabResult.new("t_qa")

	var sample := LabResult.new("sample")
	t.expect(sample.passed() and sample.verdict("n=1").begins_with("[sample] PASS n=1"), "fresh result passes")
	t.expect(sample.expect(true, "ok") and sample.passed(), "a true expectation keeps the pass")
	t.expect(not sample.expect(false, "boom"), "a false expectation returns false")
	t.expect(not sample.passed() and sample.failures == PackedStringArray(["boom"]), "failure is recorded by name")
	t.expect(sample.verdict().begins_with("[sample] FAIL count=1"), "verdict reports the failure count")
	t.expect(not sample.finished, "verdict() does not finish")

	var shot := LabResult.capture_path("t_qa_probe")
	t.expect(shot.begins_with(OS.get_user_data_dir()) and shot.ends_with("/lab_shots/t_qa_probe.png"),
		"lab captures land under user://, not a shared /tmp: %s" % shot)

	var black := Image.create(160, 90, false, Image.FORMAT_RGB8)
	black.fill(Color.BLACK)
	var e := LabResult.exposure(black)
	t.expect(is_zero_approx(e["mean"]) and is_equal_approx(e["black"], 1.0) and is_zero_approx(e["clipped"]), "black frame reads black: %s" % e)
	var white := Image.create(160, 90, false, Image.FORMAT_RGB8)
	white.fill(Color.WHITE)
	e = LabResult.exposure(white)
	t.expect(is_equal_approx(e["clipped"], 1.0) and is_equal_approx(e["mean"], 1.0), "white frame reads clipped: %s" % e)
	var half := Image.create(100, 100, false, Image.FORMAT_RGB8)
	half.fill(Color.BLACK)
	half.fill_rect(Rect2i(0, 0, 50, 100), Color.WHITE)
	e = LabResult.exposure(half)
	t.expect(absf(e["clipped"] - 0.5) < 0.05 and absf(e["mean"] - 0.5) < 0.05 and e["spread"] > 0.45, "half-white frame: %s" % e)
	t.finish(self)
	return false
