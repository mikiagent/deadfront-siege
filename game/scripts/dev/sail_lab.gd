extends Node3D
## The harbour's Sail chart (SailScreen, spec 15 "The Sail menu"), opened the way the dock opens it
## (world_ui.show_harbour). Args after --:
##   --island=<id>     the island you stand on (home_grassland)
##   --survival=<n>    the survivor's Survival level (0)
##   --stones=<n>      T-stones (20)
##   --visited=<a,b>   islands sailed to before (the one you stand on always counts)
##   --scroll=right    scroll to the far right; --scroll=<px> scrolls that far
##   --card=<id>       open that island's card
##   --view=<w>x<h>    headless canvas size (1600x900)
## Prints the chart's numbers and "[sail] lab PASS" or "[sail] lab FAIL <reasons>" from audit(): every
## tap target at least 64x64 px and inside the safe area, no two overlapping, the sea at least twice
## the view wide with no vertical scrolling, node x strictly growing with the level. Headless quits
## after it (exit 1 on FAIL); --shot takes the picture. On a build without the chart it says so.

const TARGET := 64.0

var _args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	if DisplayServer.get_name() == "headless":
		# A headless window is 64x64; --view=<w>x<h> (1600x900) gives the canvas a real size.
		var v := str(_args.get("view", "1600x900")).split("x")
		get_tree().root.size = Vector2i(int(v[0]), int(v[1]))
	var kit := LabKit.build(self, 20.0)
	(kit["nav"] as Node3D).visible = false
	var player: Player = kit["player"]
	World.home_terrain = &"meadow"
	World.harvested.clear()
	World.visited_islands.clear()
	for id in str(_args.get("visited", "")).split(",", false):
		World.visited_islands[id] = true
	World.t_stones = int(_args.get("stones", "20"))
	World.load_island(self, StringName(str(_args.get("island", "home_grassland"))), Vector3(0, 1, 0), false)
	player.global_position = World.runtime.arrival_point() + Vector3.UP
	player.skills.trees["survival"]["level"] = int(_args.get("survival", "0"))
	_open.call_deferred()

func _open() -> void:
	for i in 3:
		await get_tree().process_frame
	var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
	ui.show_harbour()
	for i in 3:
		await get_tree().process_frame
	var found: Array[Node] = ui.find_children("*", "SailScreen", true, false)
	if found.is_empty():
		print("[sail] lab FAIL no Sail chart: show_harbour opened the old route list")
		_quit(1)
		return
	var sail: Control = found[0]
	if _args.has("card"):
		sail.call("open_card", StringName(str(_args["card"])))
	if _args.has("scroll"):
		sail.call("scroll_to", INF if str(_args["scroll"]) == "right" else float(str(_args["scroll"])))
	for i in 2:
		await get_tree().process_frame
	var r := audit(sail)
	print("[sail] view=%s content_w=%.0f (%.2fx) scroll=%.0f/%.0f nodes=%d visible=%s card=%s" % [
		sail.get_viewport_rect().size, r.content_w, r.ratio, sail.get("scroll_x"), r.max_scroll, r.nodes, r.visible, sail.get("card_id")])
	for line in r.lines:
		print("[sail] %s" % line)
	print("[sail] lab %s" % ("PASS" if r.problems.is_empty() else "FAIL " + "; ".join(r.problems)))
	print("[boot] lab=sail_lab")
	_quit(0 if r.problems.is_empty() else 1)

func _quit(code: int) -> void:
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().quit(code)

## The plan's layout gates for a SailScreen as it shows now. Returns {problems, lines, content_w,
## ratio, max_scroll, nodes, visible (ids fully in view), order (ids by x)}. Shared with t_sailui.
static func audit(sail: Control) -> Dictionary:
	var problems: PackedStringArray = []
	var lines: PackedStringArray = []
	var view_size: Vector2 = sail.get_viewport_rect().size
	var view: Rect2 = sail.call("view_rect")
	var safe: Rect2 = sail.call("safe_rect")
	var content_w: float = sail.get("content_w")
	var nodes: Dictionary = sail.get("nodes")
	if content_w < view_size.x * 2.0:
		problems.append("sea %.0f px is under 2x the %.0f px view" % [content_w, view_size.x])
	if not sail.find_children("*", "VScrollBar", true, false).is_empty():
		problems.append("a vertical scrollbar exists")
	for c in sail.find_children("*", "ScrollContainer", true, false):
		if (c as ScrollContainer).vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			problems.append("%s can scroll vertically" % c.name)
	var chart: Control = sail.find_child("Chart", true, false)
	if chart and chart.size.y > view.size.y + 0.5:
		problems.append("sea %.0f px is taller than its %.0f px view" % [chart.size.y, view.size.y])
	if not safe.grow(0.5).encloses(view):
		problems.append("sea view %s leaves the safe area %s" % [view, safe])
	# Nodes: big enough, never overlapping each other (all of them, scrolled or not), x by level.
	var list: Array = nodes.values()
	list.sort_custom(func (a: Control, b: Control) -> bool: return a.position.x < b.position.x)
	var order: PackedStringArray = []
	var shown: PackedStringArray = []
	var card: Control = sail.find_child("Card", true, false)
	var card_rect := card.get_global_rect() if card and card.visible else Rect2()
	if card_rect.has_area() and not view.grow(0.5).encloses(card_rect):
		problems.append("the card %s runs out of the sea view %s" % [card_rect, view])
	for i in list.size():
		var n: Control = list[i]
		order.append(str(n.get("island_id")))
		if n.size.x < TARGET or n.size.y < TARGET:
			problems.append("node %s is %s, under 64x64" % [n.get("island_id"), n.size])
		for j in range(i + 1, list.size()):
			var o: Control = list[j]
			if Rect2(n.position, n.size).intersects(Rect2(o.position, o.size)):
				problems.append("nodes %s and %s overlap" % [n.get("island_id"), o.get("island_id")])
		var g := n.get_global_rect()
		if view.grow(0.5).encloses(g) and not (card_rect.has_area() and card_rect.intersects(g)):
			shown.append(str(n.get("island_id")))
	for a in list:
		for b in list:
			if int(a.get("tier")) < int(b.get("tier")) and not a.position.x + a.size.x * 0.5 < b.position.x + b.size.x * 0.5:
				problems.append("node x does not grow with level: %s (Lv %d) is not left of %s (Lv %d)" % [a.get("island_id"), a.get("tier"), b.get("island_id"), b.get("tier")])
	# Header and card buttons: 64x64, inside the safe area, no two overlapping, none over a node it hides.
	var targets: Array = sail.call("tap_targets")
	for i in targets.size():
		var b: Control = targets[i]
		var g := b.get_global_rect()
		lines.append("button \"%s\" %s" % [(b as Button).text if (b as Button).text != "" else b.tooltip_text, g])
		if g.size.x < TARGET - 0.5 or g.size.y < TARGET - 0.5:
			problems.append("button \"%s\" is %s, under 64x64" % [(b as Button).text if (b as Button).text != "" else b.tooltip_text, g.size])
		if not safe.grow(0.5).encloses(g):
			problems.append("button \"%s\" leaves the safe area" % (b as Button).text)
		for j in range(i + 1, targets.size()):
			if g.intersects((targets[j] as Control).get_global_rect()):
				problems.append("buttons \"%s\" and \"%s\" overlap" % [(b as Button).text, (targets[j] as Button).text])
		if not card_rect.has_area() or not card_rect.encloses(g):
			for id in shown:
				if g.intersects((nodes[id] as Control).get_global_rect()):
					problems.append("button \"%s\" covers node %s" % [(b as Button).text, id])
	var max_scroll := maxf(0.0, content_w - view.size.x)
	return {"problems": problems, "lines": lines, "content_w": content_w, "ratio": content_w / maxf(1.0, view_size.x),
		"max_scroll": max_scroll, "nodes": list.size(), "visible": shown, "order": order}
