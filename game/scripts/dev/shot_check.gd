extends SceneTree
## Exposure check for gate screenshots (tools/labs.sh --shots): prints mean luma and the share of
## clipped and black samples per PNG, and fails a frame that is black, blank (one flat colour,
## e.g. a loader or an error screen) or blown out. W1-LIGHT owns the lighting; these bounds only
## catch gross failures and should tighten once its builder lands.
## Run: godot --headless --path game --script res://scripts/dev/shot_check.gd -- a.png b.png

# ASSUMPTION: gross-failure bounds, not a colour sign-off (that stays in desktop Chrome).
const MIN_MEAN := 0.04
const MIN_SPREAD := 0.015
const MAX_CLIPPED := 0.35

func _init() -> void:
	var r := LabResult.new("shot")
	var n := 0
	for path in OS.get_cmdline_user_args():
		var img := Image.load_from_file(path)
		if not r.expect(img != null and not img.is_empty(), "unreadable %s" % path):
			continue
		n += 1
		var e := LabResult.exposure(img)
		print("[shot] %s %dx%d mean=%.3f clipped=%.3f black=%.3f spread=%.3f" % [path.get_file(),
			img.get_width(), img.get_height(), e["mean"], e["clipped"], e["black"], e["spread"]])
		r.expect(e["mean"] >= MIN_MEAN, "%s is black (mean %.3f)" % [path.get_file(), e["mean"]])
		r.expect(e["spread"] >= MIN_SPREAD, "%s is one flat colour (spread %.3f)" % [path.get_file(), e["spread"]])
		r.expect(e["clipped"] <= MAX_CLIPPED, "%s is blown out (%.0f %% clipped)" % [path.get_file(), e["clipped"] * 100.0])
	r.expect(n > 0, "no screenshots given")
	r.finish(self, "shots=%d" % n)
