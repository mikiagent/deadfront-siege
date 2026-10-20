class_name GatherFeedback
extends RefCounted
## Yield numbers by the worked node: "+2 Branch" rises from just above (or beside) the gather ring,
## a rare find rides on top of it in bigger gold and is announced on the HUD. The stack keeps off
## the ring, world pills, HUD text and zones, creature plates and the open gather radial.

const LIFE := 1.4
## The ring is a 72 px hex on the anchor: the stack starts this far above its centre, or this far
## to its side, so it never covers the ring at any zoom or screen size.
const RING_CLEAR := 44.0
const RISE_PX := 32.0
## A stack nudged further than this from the ring no longer reads as that node's: not drawn.
const MAX_SHIFT := 120.0
## Gathering UI stays above pet plates (GAUNTLET): over plates (58), under the radial (64) and ring (65).
const LAYER := 60
const LAYER_NAME := "GatherPopups"
const GOLD := Color(1.0, 0.9, 0.3)
const CREAM := Color(1.0, 0.97, 0.88)

## A stack of lines ([text, color, big], top to bottom) rising from a 3D anchor in screen space.
## Its whole rise is placed once: above the ring, else right or left of it, nudged off what is taken.
static func popup(p: Player, at: Vector3, lines: Array) -> Control:
	if p == null or not p.is_inside_tree() or lines.is_empty():
		return null
	var tree := p.get_tree()
	var cam := p.get_viewport().get_camera_3d()
	if tree.current_scene == null or cam == null or cam.is_position_behind(at):
		return null
	var layer := tree.current_scene.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = LAYER
		tree.current_scene.add_child(layer)
	# One survivor works one node at a time: a new unit's stack replaces the last one.
	for old in layer.get_children():
		old.queue_free()
	var view := p.get_viewport().get_visible_rect().size
	var px := UiTokens.heading(view)  # 24 desktop, 20 on a phone
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -6)
	for ln in lines:
		var big: bool = ln[2]
		var l := Label.new()
		l.text = ln[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", px + 4 if big else px - 2)
		l.add_theme_color_override("font_color", ln[1])
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
		l.add_theme_constant_override("outline_size", 8 if big else 6)
		box.add_child(l)
	layer.add_child(box)
	var sz := box.get_combined_minimum_size()
	box.size = sz
	var a0 := cam.unproject_position(at)
	var taken := taken_rects(p, a0)
	taken.append_array(UiTokens.hud_reserved(view))
	var h := sz.y + RISE_PX
	var cols: Array[Rect2] = [
		Rect2(a0.x - sz.x * 0.5, a0.y - RING_CLEAR - h, sz.x, h),
		Rect2(a0.x + RING_CLEAR, a0.y + sz.y * 0.5 - h, sz.x, h),
		Rect2(a0.x - RING_CLEAR - sz.x, a0.y + sz.y * 0.5 - h, sz.x, h),
	]
	var off := Vector2.INF
	var best := MAX_SHIFT + 1.0
	for col in cols:
		if col.position.x < 8.0 or col.end.x > view.x - 8.0:
			continue
		var spot := UiTokens.free_spot(col, taken, view)
		var shift := absf(spot.position.y - col.position.y)
		if spot.has_area() and shift < best:
			best = shift
			off = spot.position - a0
	if off == Vector2.INF:
		# Like a world label with no free spot near its anchor: not drawn (the HUD toast and notice say it).
		box.queue_free()
		return null
	var follow := func(t: float) -> void:
		if not is_instance_valid(cam) or not is_instance_valid(box):
			return
		box.visible = not cam.is_position_behind(at)
		box.position = cam.unproject_position(at) + off + Vector2(0.0, RISE_PX * (1.0 - t))
	follow.call(0.0)
	var tw := box.create_tween()
	tw.tween_method(follow, 0.0, 1.0, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55)
	tw.tween_callback(box.queue_free)
	return box

## Screen rects a stack keeps off: the gather ring around the anchor, the HUD's drawn blocks (world
## pills, toasts, notices, nameplate), visible creature plates and the open radial's hexes and labels.
static func taken_rects(p: Player, anchor: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(anchor - Vector2(40.0, 40.0), Vector2(80.0, 80.0))]
	var hud := p.get_tree().get_first_node_in_group("hud") as Control
	if hud and hud.get("drawn_blocks") is Dictionary:
		for r in (hud.get("drawn_blocks") as Dictionary).values():
			if r is Rect2:
				out.append(Rect2((r as Rect2).position + hud.global_position, (r as Rect2).size))
	if Game.creature_ui and is_instance_valid(Game.creature_ui):
		for pill in Game.creature_ui.find_children("Pill", "Control", true, false):
			if (pill as Control).is_visible_in_tree():
				out.append((pill as Control).get_global_rect())
	var gr := p._gather_radial
	if gr and gr.is_open():
		out.append_array(gr.label_rects)
		out.append(gr.title_box)
		for c in gr.get_children():
			if c is Control and (c as Control).visible:
				out.append((c as Control).get_global_rect())
	return out

static func item_name(id: StringName) -> String:
	var d := Data.item(id)
	return d.display_name if d and d.display_name != "" else str(id).capitalize()

## "+n Name" in cream over a gathered node, with any rare finds of that unit in gold above it.
static func show_yield(p: Player, at: Vector3, id: StringName, n: int, rares: Array[StringName] = []) -> void:
	var lines: Array = []
	for r in rares:
		lines.append(["RARE  %s" % item_name(r), GOLD, true])
	lines.append(["+%d %s" % [n, item_name(id)], CREAM, false])
	popup(p, at, lines)

## Rare finds off a carcass: gold lines over it and a HUD notice each (the caller toasts pickups).
static func announce_rares(p: Player, at: Vector3, ids: Array[StringName], where: String = "") -> void:
	var lines: Array = []
	for id in ids:
		lines.append(["RARE  %s" % item_name(id), GOLD, true])
		notice_rare(p, id, where)
	popup(p, at, lines)

## Finds are always gold: rarity rims (grey, green) read as an ordinary pickup in the world.
static func notice_rare(p: Player, id: StringName, where: String = "") -> void:
	print("[gather] rare %s%s" % [id, where])
	if p:
		p.notice("Rare find: %s%s" % [item_name(id), where])
