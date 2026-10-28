extends SceneTree

func _process(_d: float) -> bool:
	var f := ThemeDB.fallback_font
	for s in [11, 12, 13, 14]:
		print("size %d height %.1f ascent %.1f descent %.1f" % [s, f.get_height(s), f.get_ascent(s), f.get_descent(s)])
	var chip := load("res://scripts/ui/nature_chip.gd").make(&"timid")
	root.add_child(chip)
	await process_frame
	print("chip min %s size %s text '%s'" % [chip.get_combined_minimum_size(), chip.size, chip.chip_text()])
	chip.configure(&"")
	print("empty chip visible %s min %s" % [chip.visible, chip.get_combined_minimum_size()])
	quit(0)
	return false
