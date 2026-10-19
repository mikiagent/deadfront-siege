extends SceneTree
## Unit checks for the gate helpers themselves (LabResult verdicts, screenshot exposure maths).
## Run: godot --headless --path game --script res://tests/t_qa.gd
## With `-- --shots a.png b.png` it is instead the exposure check tools/labs.sh --shots runs on
## gate stills: one "[shot] <file> mean=..." line per PNG, then "[shot] PASS" or "[shot] FAIL".

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "--shots":
		_check_shots(args.slice(1))
		return false
	var t := LabResult.new("t_qa")

	var sample := LabResult.new("sample")
	t.expect(sample.passed() and sample.verdict("n=1").begins_with("[sample] PASS n=1"), "fresh result passes")
	t.expect(sample.expect(true, "ok") and sample.passed(), "a true expectation keeps the pass")
	t.expect(not sample.expect(false, "boom"), "a false expectation returns false")
	t.expect(not sample.passed() and sample.failures == PackedStringArray(["boom"]), "failure is recorded by name")
	t.expect(sample.verdict().begins_with("[sample] FAIL count=1"), "verdict reports the failure count")
	t.expect(not sample.finished, "verdict() does not finish")

	var saved_logs := OS.get_environment("LABS_LOG_DIR")
	OS.unset_environment("LABS_LOG_DIR")
	var shot := LabResult.capture_path("t_qa_probe")
	t.expect(shot.begins_with(OS.get_user_data_dir()) and shot.ends_with("/lab_shots/t_qa_probe.png"),
		"lab captures land under user://, not a shared /tmp: %s" % shot)
	var gate_dir := OS.get_user_data_dir().path_join("t_qa_logs")
	OS.set_environment("LABS_LOG_DIR", gate_dir)
	shot = LabResult.capture_path("t_qa_probe")
	t.expect(shot == gate_dir.path_join("lab_shots/t_qa_probe.png"), "under the gate, captures land in LABS_LOG_DIR (kept): %s" % shot)
	if saved_logs.is_empty():
		OS.unset_environment("LABS_LOG_DIR")
	else:
		OS.set_environment("LABS_LOG_DIR", saved_logs)

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
	t.expect(LabResult.shot_problems(LabResult.exposure(black)).size() > 0, "a black still fails the shot check")
	t.expect(LabResult.shot_problems(LabResult.exposure(white)).size() > 0, "a blown-out still fails the shot check")
	var flat := Image.create(160, 90, false, Image.FORMAT_RGB8)
	flat.fill(Color(0.3, 0.4, 0.5))
	t.expect(LabResult.shot_problems(LabResult.exposure(flat)).size() > 0, "a flat loader-colour still fails the shot check")
	var scene := Image.create(160, 90, false, Image.FORMAT_RGB8)
	for x in 160:
		scene.fill_rect(Rect2i(x, 0, 1, 90), Color.from_hsv(0.3, 0.5, 0.15 + 0.6 * float(x) / 160.0))
	t.expect(LabResult.shot_problems(LabResult.exposure(scene)).is_empty(), "a lit graded still passes the shot check: %s" % LabResult.exposure(scene))
	t.finish(self)
	return false

## Exposure check over gate stills (tools/labs.sh --shots).
func _check_shots(paths: PackedStringArray) -> void:
	var r := LabResult.new("shot")
	var n := 0
	for path in paths:
		var img := Image.load_from_file(path)
		if not r.expect(img != null and not img.is_empty(), "unreadable %s" % path):
			continue
		n += 1
		var e := LabResult.exposure(img)
		print("[shot] %s %dx%d mean=%.3f clipped=%.3f black=%.3f spread=%.3f" % [path.get_file(),
			img.get_width(), img.get_height(), e["mean"], e["clipped"], e["black"], e["spread"]])
		for why in LabResult.shot_problems(e):
			r.expect(false, "%s is %s" % [path.get_file(), why])
	r.expect(n > 0, "no screenshots given")
	r.finish(self, "shots=%d" % n)
