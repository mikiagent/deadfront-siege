class_name GatherFeedback
extends RefCounted
## World-space yield numbers: "+2 Branch" rises off the node; a rare find rises bigger in its
## rarity colour and is announced on the HUD.

const RISE := 1.3
const LIFE := 1.4

static func popup(tree: SceneTree, at: Vector3, text: String, color: Color, big: bool = false, lane: int = 0) -> Label3D:
	if tree == null or tree.current_scene == null:
		return null
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011 if big else 0.0008
	l.font_size = 44
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.04, 0.03, 0.9)
	l.render_priority = 10
	tree.current_scene.add_child(l)
	l.global_position = at + Vector3(0.0, 0.35 * float(lane), 0.0)
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", l.global_position.y + RISE, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55)
	tw.tween_callback(l.queue_free)
	return l

static func item_name(id: StringName) -> String:
	var d := Data.item(id)
	return d.display_name if d and d.display_name != "" else str(id).capitalize()

## "+n Name" in white over a gathered node.
static func show_yield(tree: SceneTree, at: Vector3, id: StringName, n: int) -> void:
	popup(tree, at, "+%d %s" % [n, item_name(id)], Color(1.0, 0.97, 0.88))

## Rare find: rarity-coloured popup, HUD notice and pickup toast.
static func announce_rare(player: Player, at: Vector3, id: StringName, lane: int = 1, where: String = "") -> void:
	# A find is gold even when the item itself is common (grey rim would read as nothing).
	var r := ItemArt.rarity(id)
	var col := Color(1.0, 0.8, 0.25) if r == &"common" else ItemArt.color_for_rarity(r)
	popup(player.get_tree() if player else null, at, "RARE  %s" % item_name(id), col, true, lane)
	print("[gather] rare %s%s" % [id, where])
	if player:
		player.notice("Rare find: %s%s" % [item_name(id), where])
