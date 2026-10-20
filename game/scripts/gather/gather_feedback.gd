class_name GatherFeedback
extends RefCounted
## World-space yield numbers: "+2 Branch" rises off the node; a rare find rises bigger in
## gold and is announced on the HUD.

const RISE := 1.3
const LIFE := 1.4
const LIFT := 0.9
## Above the world name labels (40), below touch controls (50) and creature plates (58).
const LAYER := 45
const LAYER_NAME := "GatherPopups"

## A 2D label that follows a rising 3D point, so world name labels never cover it.
static func popup(tree: SceneTree, at: Vector3, text: String, color: Color, big: bool = false, lane: int = 0) -> Label:
	if tree == null or tree.current_scene == null:
		return null
	var cam := tree.root.get_viewport().get_camera_3d()
	if cam == null:
		return null
	var layer := tree.current_scene.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = LAYER
		tree.current_scene.add_child(layer)
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 30 if big else 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	l.add_theme_constant_override("outline_size", 10 if big else 8)
	layer.add_child(l)
	var start := at + Vector3(0.0, LIFT, 0.0)
	var lane_px := 34.0 * float(lane)
	var follow := func(t: float) -> void:
		if not is_instance_valid(cam) or not is_instance_valid(l):
			return
		var p3 := start + Vector3(0.0, RISE * t, 0.0)
		l.visible = not cam.is_position_behind(p3)
		l.position = cam.unproject_position(p3) - Vector2(l.size.x * 0.5, l.size.y + lane_px)
	follow.call(0.0)
	var tw := l.create_tween()
	tw.tween_method(follow, 0.0, 1.0, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55)
	tw.tween_callback(l.queue_free)
	return l

static func item_name(id: StringName) -> String:
	var d := Data.item(id)
	return d.display_name if d and d.display_name != "" else str(id).capitalize()

## "+n Name" in white over a gathered node.
static func show_yield(tree: SceneTree, at: Vector3, id: StringName, n: int) -> void:
	popup(tree, at, "+%d %s" % [n, item_name(id)], Color(1.0, 0.97, 0.88))

## Rare find: gold popup and HUD notice (the caller toasts the pickup).
static func announce_rare(player: Player, at: Vector3, id: StringName, lane: int = 1, where: String = "") -> void:
	# Finds are always gold: rarity rims (grey, green) read as an ordinary pickup in the world.
	var col := Color(1.0, 0.9, 0.3)
	popup(player.get_tree() if player else null, at, "RARE  %s" % item_name(id), col, true, lane)
	print("[gather] rare %s%s" % [id, where])
	if player:
		player.notice("Rare find: %s%s" % [item_name(id), where])
