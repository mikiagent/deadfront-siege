class_name LabResult
extends RefCounted
## Shared verdict for labs and probes, so every one of them can fail.
## expect() records a failed check; finish() prints one "[tag] PASS ..." or "[tag] FAIL ..." line
## and quits with 0/1. tools/labs.sh reads exactly those lines and the exit code.
##
##   var r := LabResult.new("island")
##   r.expect(nodes > 0, "island has harvest nodes")
##   r.finish(get_tree(), "nodes=%d" % nodes)

var tag: String
var failures: PackedStringArray = []
var finished: bool = false

func _init(tag_name: String) -> void:
	tag = tag_name

func expect(ok: bool, what: String = "check") -> bool:
	if not ok:
		failures.append(what)
		print("[%s] FAIL %s" % [tag, what])
	return ok

func passed() -> bool:
	return failures.is_empty()

## The verdict line without quitting (for callers that run more than one fixture).
func verdict(detail: String = "") -> String:
	if failures.is_empty():
		return "[%s] PASS %s" % [tag, detail]
	return "[%s] FAIL count=%d %s" % [tag, failures.size(), detail]

## Print the verdict once and quit 0 on pass, 1 on any failed expectation.
func finish(tree: SceneTree, detail: String = "") -> void:
	if finished:
		return
	finished = true
	print(verdict(detail).strip_edges())
	if tree:
		tree.quit(0 if failures.is_empty() else 1)

## Fail and quit if the lab is still running after `seconds` (labs that used to never exit).
func deadline(tree: SceneTree, seconds: float) -> void:
	tree.create_timer(seconds, true, false, true).timeout.connect(func () -> void:
		if not finished:
			expect(false, "deadline %.0f s reached" % seconds)
			finish(tree)
	)

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

## Exposure numbers for a screenshot, sampled on a grid of about 160x90 points:
## mean luma, share of clipped (luma >= 0.98) and black (luma <= 0.02) samples, luma spread.
static func exposure(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(1, mini(w, h) / 90)
	var n := 0
	var sum := 0.0
	var sum_sq := 0.0
	var clipped := 0
	var black := 0
	for y in range(0, h, step):
		for x in range(0, w, step):
			var l := img.get_pixel(x, y).get_luminance()
			sum += l
			sum_sq += l * l
			n += 1
			if l >= 0.98:
				clipped += 1
			elif l <= 0.02:
				black += 1
	var mean := sum / maxf(1.0, float(n))
	return {"mean": mean, "clipped": float(clipped) / maxf(1.0, float(n)),
		"black": float(black) / maxf(1.0, float(n)),
		"spread": sqrt(maxf(0.0, sum_sq / maxf(1.0, float(n)) - mean * mean))}

## Capture path for windowed lab stills: under user:// (isolated per work tree and per gate
## run), never a hardcoded /tmp that every work tree shares.
static func capture_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute("user://lab_shots")
	return ProjectSettings.globalize_path("user://lab_shots/%s.png" % name)
