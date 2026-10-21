class_name GatherFeedback
extends RefCounted
## Yield numbers by the worked node: "+2 Branch" rises from just above (or beside) the gather ring,
## a rare find rides on top of it in bigger gold (a HUD notice says it only when the stack cannot be
## drawn). The stack keeps off the ring, world pills, HUD text and zones, creature plates and the open radial.

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

## A replaced stack shown for less than this still owes its finds to the HUD (its fallback runs).
const SHOWN_MS := 500

## A stack of lines ([text, color, big], top to bottom) rising from a 3D anchor in screen space.
## Its whole rise is placed once, a frame later: above the ring, else right or left of it, nudged off what is taken.
## `fallback` runs (once) when the stack ends up not drawn or is cut short, so what it said still reaches the HUD.
static func popup(p: Player, at: Vector3, lines: Array, fallback: Callable = Callable()) -> Control:
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
	# One survivor works one node at a time: a new unit's stack replaces the last one. One that was
	# barely seen (two finds in one frame: a unit and a pet's kill) hands its finds to the HUD.
	for old in layer.get_children():
		var ost: Dictionary = old.get_meta(&"st", {})
		if not ost.is_empty() and (int(ost["shown_ms"]) < 0 or Time.get_ticks_msec() - int(ost["shown_ms"]) < SHOWN_MS):
			_owe(ost)
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
	box.size = box.get_combined_minimum_size()
	box.visible = false
	# Shared by the placement, the follow tween and a later popup that replaces this one.
	var st := {"fallback": fallback, "fell_back": false, "shown_ms": -1}
	box.set_meta(&"st", st)
	# Placed next frame: by then the HUD has drawn this unit's toast and rare notice, which the stack keeps off.
	# A lambda per stack: a bound static method is one callable, so a second stack in the same frame
	# failed to connect and both finds were lost. Weak refs: a stack replaced this frame is freed by
	# then, and a lambda holding a freed object logs an engine ERROR.
	var refs := [weakref(p), weakref(cam), weakref(box)]
	tree.process_frame.connect(func() -> void:
		var pl := refs[0].get_ref() as Player
		var c := refs[1].get_ref() as Camera3D
		var b := refs[2].get_ref() as Control
		if pl and c and b:
			_place(pl, c, at, b, st)
		else:
			_owe(st)
	, CONNECT_ONE_SHOT)
	return box

## Runs a stack's fallback once (its finds go to the HUD notice).
static func _owe(st: Dictionary) -> void:
	if st["fell_back"]:
		return
	st["fell_back"] = true
	var fb: Callable = st["fallback"]
	if fb.is_valid():
		fb.call()

static func _place(p: Player, cam: Camera3D, at: Vector3, box: Control, st: Dictionary) -> void:
	if cam.is_position_behind(at):
		box.queue_free()
		_owe(st)
		return
	var view := p.get_viewport().get_visible_rect().size
	var sz := box.size
	var a0 := cam.unproject_position(at)
	# Roomiest first. A phone's HUD band can leave no room by the node: nature-node pills give way,
	# then the stack holds still (no rise); the ring, HUD, plates and radial never give way.
	var off := Vector2.INF
	var rise := RISE_PX
	for step in 3:
		rise = RISE_PX if step < 2 else 0.0
		off = _best_offset(_columns(a0, sz, sz.y + rise), taken_rects(p, a0, step == 0), a0, view)
		if off != Vector2.INF:
			break
	if off == Vector2.INF:
		# Like a world label with no free spot near its anchor: not drawn (the HUD toast and notice say it).
		print("[gather] yield stack skipped: no free spot by the node")
		box.queue_free()
		_owe(st)
		return
	st["off"] = off  # in the shared Dictionary: lambda captures are copies
	st["rise"] = rise
	var follow := func(t: float) -> void:
		if not is_instance_valid(cam) or not is_instance_valid(box) or not is_instance_valid(p):
			return
		var a := cam.unproject_position(at)
		box.position = a + (st["off"] as Vector2) + Vector2(0.0, float(st["rise"]) * (1.0 - t))
		box.visible = not cam.is_position_behind(at)
		if box.visible and int(st["shown_ms"]) < 0:
			st["shown_ms"] = Time.get_ticks_msec()
		# The HUD re-places its notices and toasts every frame without knowing this stack (a level-up
		# banner pushed a phone's "Rare find" notice onto it): when anything moves onto it, move off, held still.
		var taken := taken_rects(p, a, false)
		taken.append_array(UiTokens.hud_reserved(view))
		if not _hits(Rect2(box.position, box.size), taken):
			return
		var o := _best_offset(_columns(a, box.size, box.size.y), taken, a, view)
		if o == Vector2.INF:
			box.visible = false  # nowhere free this frame: the HUD toast and (once) the fallback notice say it
			_owe(st)
			return
		st["off"] = o
		st["rise"] = 0.0
		box.position = a + o
	follow.call(0.0)
	var tw := box.create_tween()
	tw.tween_method(follow, 0.0, 1.0, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55)
	tw.tween_callback(box.queue_free)

static func _hits(r: Rect2, taken: Array[Rect2]) -> bool:
	for t in taken:
		if r.intersects(t):
			return true
	return false

## Where a stack of size `sz` rising `h` px may sit: above the ring, else right or left of it.
static func _columns(a0: Vector2, sz: Vector2, h: float) -> Array[Rect2]:
	return [
		Rect2(a0.x - sz.x * 0.5, a0.y - RING_CLEAR - h, sz.x, h),
		Rect2(a0.x + RING_CLEAR, a0.y + sz.y * 0.5 - h, sz.x, h),
		Rect2(a0.x - RING_CLEAR - sz.x, a0.y + sz.y * 0.5 - h, sz.x, h),
	]

## The offset from the anchor to the free column spot nudged least (at most MAX_SHIFT), or INF.
static func _best_offset(cols: Array[Rect2], taken: Array[Rect2], a0: Vector2, view: Vector2) -> Vector2:
	taken.append_array(UiTokens.hud_reserved(view))
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
	return off

## Screen rects a stack keeps off: the gather ring around the anchor, the HUD's drawn blocks (world
## pills unless with_pills is false, toasts, notices, nameplate), visible creature plates and the
## open radial's hexes and labels.
static func taken_rects(p: Player, anchor: Vector2, with_pills: bool = true) -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(anchor - Vector2(40.0, 40.0), Vector2(80.0, 80.0))]
	var hud := p.get_tree().get_first_node_in_group("hud") as Control
	if hud and hud.get("drawn_blocks") is Dictionary:
		var blocks := hud.get("drawn_blocks") as Dictionary
		for k in blocks:
			var r: Variant = blocks[k]
			if r is Rect2 and (with_pills or not str(k).begins_with("pill")):
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
	_popup_or_notice(p, at, lines, rares)

## Rare finds off a carcass: gold lines over it (the caller toasts pickups).
static func announce_rares(p: Player, at: Vector3, ids: Array[StringName], where: String = "") -> void:
	var lines: Array = []
	for id in ids:
		lines.append(["RARE  %s" % item_name(id), GOLD, true])
	_popup_or_notice(p, at, lines, ids, where)

## The gold stack announces finds; only when it cannot be drawn by the node does the HUD notice say
## them (a notice beside a drawn stack said the same find twice, and on a phone crowded it off).
static func _popup_or_notice(p: Player, at: Vector3, lines: Array, rares: Array[StringName], where: String = "") -> void:
	for r in rares:
		print("[gather] rare %s%s" % [r, where])
	var fb := Callable()
	if not rares.is_empty():
		fb = func() -> void:
			for r in rares:
				notice_rare(p, r, where)
	if popup(p, at, lines, fb) == null and fb.is_valid():
		fb.call()

## Finds are always gold, in the HUD too: a gold notice, not the red refusal box (a phone with the
## radial open always lands here). Rarity rims (grey, green) read as an ordinary pickup.
static func notice_rare(p: Player, id: StringName, where: String = "") -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var text := "Rare find: %s%s" % [item_name(id), where]
	print("[ui] notice %s (gold)" % text)
	var hud := p.get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("notice"):
		hud.notice(text, true)
