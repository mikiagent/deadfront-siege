class_name HudLayout
extends RefCounted
## HuntHud's layout geometry: where its controls go per canvas shape, the rects it holds, the
## survivor's figure and name, the open sheet's fit. Static functions over the HUD's nodes, split out
## of hunt_hud.gd (review: no god-file growth).

## A landscape phone's 390-452 px canvas: whistles in a row under the vitals; End Combat in the map
## column under the map text (CLAIM and the context row hide in a fight), right above INTERACT; the
## four skills in one row along the bottom between the rail and SPRINT / ATTACK NEAREST (HudField), Auto
## and Feed above the NET / TACKLE seam, the stance text right of Auto.
# ASSUMPTION: these phone placements are ours; the combat reference only fixes End Combat right, skills bottom right.
static func place_landscape_phone(hud: HuntHud, r: Vector2, inset: Vector4) -> void:
	var under_vitals := vitals_rect(hud, r).end.y + 8.0
	for i in hud._whistle_hexes.size():
		HudField.fit(hud._whistle_hexes[i], HudField.px(&"whistle", r))
		hud._whistle_hexes[i].position = Vector2(16.0 + inset.w + float(i) * (HuntHud.HEX + 10.0), under_vitals)
	var ih := hud.field.interact_hex
	hud._end_btn.add_theme_font_size_override("font_size", 14)
	hud._end_btn.custom_minimum_size = Vector2(r.x - 16.0 - inset.x - ih.position.x, 64.0)
	hud._end_btn.size = hud._end_btn.custom_minimum_size
	hud._end_btn.position = Vector2(ih.position.x, hud.map_floor() - 4.0)  # under the "X n  Y n" line, over INTERACT's hex
	var row_y := r.y - UiTokens.xp_line_zone(r).size.y - HuntHud.CAPTION_H - HuntHud.SKILL_HEX - inset.y  # captions clear the XP line
	var x := minf(hud.field.sprint_hex.position.x, hud.field.attack_hex.position.x) - 8.0 - HuntHud.SKILL_HEX
	for i in range(hud._skill_hexes.size() - 1, -1, -1):  # ROLL at the right, NET leftmost
		hud._skill_hexes[i].position = Vector2(x, row_y)
		x -= HuntHud.SKILL_HEX + 8.0
	var net := hud._skill_hexes[0].position
	var up := row_y - 8.0 - HuntHud.CAPTION_H - HuntHud.HEX
	hud._auto_hex.position = Vector2(net.x + HuntHud.SKILL_HEX + 4.0 - HuntHud.HEX * 0.5, up)  # over the NET/TACKLE seam
	hud._feed_hex.position = hud._auto_hex.position - Vector2(HuntHud.HEX + 8.0, 0.0)
	var sw := hud._stance_label.get_combined_minimum_size()
	hud._stance_label.position = Vector2(hud._auto_hex.position.x + HuntHud.HEX + 8.0, up + HuntHud.HEX * 0.5 - sw.y * 0.5)

## A portrait phone's 390 px wide canvas: the desktop cluster ran off the left edge, onto the rail and
## onto CHASE, and the whistle column onto HANDS. From the quick-food row up: the whistle row with End
## Combat at its right (mid-screen, a creature's plate covered it), the four skills in one row, then
## Feed, Auto and the stance text.
static func place_portrait(hud: HuntHud, r: Vector2, inset: Vector4, rail_y: float) -> void:
	var whistle_y := rail_y - 2.0 * (HuntHud.HEX + HuntHud.CAPTION_H) - 20.0  # over the quick-food row
	for i in hud._whistle_hexes.size():
		hud._whistle_hexes[i].position = Vector2(16.0 + inset.w + float(i) * (HuntHud.HEX + 10.0), whistle_y)
	var row_y := whistle_y - 8.0 - HuntHud.CAPTION_H - HuntHud.SKILL_HEX
	var x := r.x - 16.0 - inset.x - HuntHud.SKILL_HEX
	for i in range(hud._skill_hexes.size() - 1, -1, -1):  # ROLL at the right edge, NET leftmost
		hud._skill_hexes[i].position = Vector2(x, row_y)
		x -= HuntHud.SKILL_HEX + 8.0
	var up := row_y - 8.0 - HuntHud.CAPTION_H - HuntHud.HEX
	hud._feed_hex.position = Vector2(16.0 + inset.w, up)
	hud._auto_hex.position = Vector2(16.0 + inset.w + HuntHud.HEX + 10.0, up)
	var end_x := 16.0 + inset.w + 3.0 * (HuntHud.HEX + 10.0) + 4.0
	hud._end_btn.custom_minimum_size = Vector2(r.x - 16.0 - inset.x - end_x, UiTokens.TARGET_PRIMARY)
	hud._end_btn.size = hud._end_btn.custom_minimum_size
	hud._end_btn.position = Vector2(end_x, whistle_y + 4.0)
	var sw := hud._stance_label.get_combined_minimum_size()
	hud._stance_label.position = Vector2(hud._auto_hex.position.x + HuntHud.HEX + 10.0, up + HuntHud.HEX * 0.5 - sw.y * 0.5)

## The desktop canvas: End Combat, the honeycomb skill cluster, Auto, Feed, the whistle column, the
## stance label.
static func place_desktop(hud: HuntHud, r: Vector2, inset: Vector4) -> void:
	hud._end_btn.add_theme_font_size_override("font_size", 16)
	hud._end_btn.custom_minimum_size = Vector2(184, 64)
	hud._end_btn.size = hud._end_btn.custom_minimum_size
	hud._end_btn.position = Vector2(r.x - 270.0 - inset.x, r.y * 0.42)  # left of the whistle column (at -200 it sat on GUARD)
	# Honeycomb cluster bottom-right: net / tackle / kick / roll, Auto below-right, stance text.
	var cx := r.x - 480.0 - inset.x  # left of SPRINT / ATTACK NEAREST / INTERACT (HudField)
	var cy := r.y - 250.0 - inset.y
	var slots := [Vector2(-90, -60), Vector2(-10, -20), Vector2(-90, 40), Vector2(70, -50)]
	for i in hud._skill_hexes.size():
		hud._skill_hexes[i].position = Vector2(cx, cy) + slots[i]
	hud._auto_hex.position = Vector2(cx + 84.0, cy + 40.0)  # under ROLL's caption (at +60/+30 it sat on it)
	hud._feed_hex.position = Vector2(cx - 170.0, cy - 20.0)
	# The whistle row stands beside the rail (spec §6), bottom-aligned with it.
	var rail := HudField.px(&"rail", r)
	var wp := HudField.px(&"whistle", r)
	var rail_y := r.y - rail - HuntHud.CAPTION_H - 14.0 - inset.y
	for i in hud._whistle_hexes.size():
		HudField.fit(hud._whistle_hexes[i], wp)
		hud._whistle_hexes[i].position = Vector2(16.0 + inset.w + 3.0 * (rail + 10.0) + 10.0 + float(i) * (wp + 10.0), rail_y + rail - wp)
	# Centred under Auto's caption on the bottom edge, as Durango anchors it to the stance dial.
	var sw := hud._stance_label.get_combined_minimum_size()
	hud._stance_label.position = Vector2(hud._auto_hex.position.x + HuntHud.HEX * 0.5 - sw.x * 0.5, r.y - 8.0 - inset.y - sw.y)

static func landscape_phone(r: Vector2) -> bool:
	return UiTokens.is_compact(r) and not UiTokens.is_narrow(r)

## The vitals panel _draw paints top-left (also the anchor for what sits under it).
static func vitals_rect(hud: HuntHud, r: Vector2) -> Rect2:
	var inset := hud._safe_insets()
	var phone := UiTokens.is_phone(r)
	var x := 16.0 + inset.w
	var big := 16.0 if not phone else 12.0
	var panel_w := 300.0 if not phone else maxf(148.0, hud._minimap.position.x - x - 8.0)
	return Rect2(x - 8.0, 6.0 + inset.z, panel_w, big * 2.0 + ExhaustTreadmill.BELT_H + 6.0 * 2.0 + 36.0)

## Landscape phone: the strip between the vitals and the minimap; portrait: the strip under the map
## text. The quest card lives in it; the target plate and the level-up banner take it over while
## they show. Empty on the desktop (the plate is top centre, the level-up stack top left).
# ASSUMPTION: the quest card may yield to the plate and the banner on a phone; nothing else free fits them.
static func centre_band(hud: HuntHud, r: Vector2) -> Rect2:
	if UiTokens.is_narrow(r):
		return Rect2(12.0 + hud._safe_insets().w, hud._minimap.position.y + HuntHud.MAP_PX + 44.0, r.x - 24.0 - hud._safe_insets().w - hud._safe_insets().x, 84.0)
	if not landscape_phone(r):
		return Rect2()
	var v := vitals_rect(hud, r)
	var left := v.end.x + 12.0
	return Rect2(left, v.position.y, hud._minimap.position.x - 12.0 - left, maxf(v.size.y, hud._minimap.position.y + 72.0 - v.position.y))

## The sheet stands on the rail and grows up to the top of the view; past that its rows scroll
## (on a 390 px canvas the menu ran 192 px off the top, title, Bag and Craft out of reach). A
## landscape phone has no room above the rail, so there it hangs from the vitals' corner and covers
## them whole (standing on the rail it hid half of them).
static func fit_sheet(hud: HuntHud, r: Vector2, inset: Vector4, rail_y: float) -> void:
	if hud._sheet_rows == null or hud._sheet_rows.get_child_count() == 0:
		return
	var land := landscape_phone(r)
	var v := vitals_rect(hud, r)
	var bottom := rail_y - 10.0
	var top := v.position.y if land else 8.0 + inset.z
	hud._sheet.custom_minimum_size.x = v.size.x if land else 0.0
	hud._sheet_rows.custom_minimum_size.y = 0.0
	var room := bottom - top - hud._sheet.get_combined_minimum_size().y
	var rows_h := (hud._sheet_rows.get_child(0) as Control).get_combined_minimum_size().y
	hud._sheet_rows.custom_minimum_size.y = minf(rows_h, maxf(room, UiTokens.TARGET_PRIMARY))
	hud._sheet.size = Vector2.ZERO  # shrink to the new minimum
	hud._sheet.position = v.position if land else Vector2(16.0 + inset.w, bottom - hud._sheet.size.y)

## Where the placer's ROTATE / PLACE / CANCEL row sits: the anchor nearest `near` (the ghost on
## screen) whose three hex rects and their captions are all inside the view's safe area and clear of
## every other HUD rect. The row used to be hung 40 px under the ghost whatever was there, so with the
## ghost under the bottom-left rail (the pointer still on MENU) it lay on MENU / ANIMALS / BUILD and ran
## off the canvas at both 1600x900 and 844x390. Falls back to the nearest clearing spot in a sweep,
## and to `near` itself when the whole canvas is packed (it never is: the centre is empty).
## `rel` is what each of the three hexes draws, relative to its own top-left corner: its hexagon and its
## caption box (HexButton.hex_rect / caption_rect, taken from the hexes themselves so the check matches
## what is drawn). One score per candidate: off-screen rects count 100 each, HUD overlaps 1; zero wins.
static func placer_anchor(near: Vector2, offsets: Array, rel: Array, taken: Array, view: Vector2, inset: Vector4) -> Vector2:
	var cands: Array[Vector2] = [near]
	for dy in [-150.0, 110.0, -250.0]:
		for dx in [-130.0, 130.0, -260.0, 260.0]:
			cands.append(near + Vector2(dx, dy))
	cands.append(Vector2(view.x * 0.5, view.y - 150.0 - inset.y))
	cands.append(Vector2(view.x * 0.5, 250.0 + inset.z))
	cands.append(Vector2(view.x - 250.0 - inset.x, view.y * 0.5))
	cands.append(Vector2(250.0 + inset.w, view.y * 0.5))
	var step := 56.0
	var y := 140.0 + inset.z
	while y < view.y - 110.0 - inset.y:
		var x := 90.0 + inset.w
		while x < view.x - 90.0 - inset.x:
			cands.append(Vector2(x, y))
			x += step
		y += step
	# The first spot that is off nothing wins; when a corner of a small canvas is packed (the ghost
	# below the rail, the vitals over the top-left), the spot off the least HUD wins rather than the
	# row staying on the rail. Off-screen counts worst: a hex there cannot be tapped at all.
	var best := near
	var best_score := 1 << 30
	for c in cands:
		var score := _placer_row_score(c, offsets, rel, taken, view, inset)
		if score < best_score:
			best_score = score
			best = c
			if score == 0:
				break
	return best

static func _placer_row_score(at: Vector2, offsets: Array, rel: Array, taken: Array, view: Vector2, inset: Vector4) -> int:
	var room := Rect2(Vector2(6.0 + inset.w, 6.0 + inset.z), view - Vector2(12.0 + inset.w + inset.x, 12.0 + inset.z + inset.y))
	var score := 0
	for i in offsets.size():
		var o: Vector2 = at + (offsets[i] as Vector2)
		for k in 2:
			var r: Rect2 = (rel[i] as Array)[k]
			var box := Rect2(o + r.position, r.size)
			if not room.encloses(box):
				score += 100
				continue
			for t in taken:
				if (t as Rect2).grow(-1.0).intersects(box.grow(-1.0)):
					score += 1
	return score

## Screen rects the HUD holds this frame: the blocks _draw has painted so far (drawn_blocks, minus
## keys starting with one of `skip`), every visible hex on screen (HUD, station and gather radials)
## with its caption, the HUD's other controls, HANDS and the open pet radial. Moving text (world pills, toasts, notices)
## and the creature plates keep off them: at 844x390 they drew over the quest card and the COOK hex.
static func taken_rects(hud: HuntHud, skip: PackedStringArray = []) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k in hud.drawn_blocks:
		var keep := true
		for p in skip:
			keep = keep and not str(k).begins_with(p)
		if keep:
			out.append(hud.drawn_blocks[k])
	for n in hud.get_tree().get_nodes_in_group(&"hex_button"):
		var h := n as HexButton
		if h and h.is_visible_in_tree():
			out.append(h.hex_rect())
			if h.caption != "":
				out.append(h.caption_rect())
	for c in hud.get_children():
		var ctl := c as Control
		if ctl == null or ctl is HexButton or not ctl.is_visible_in_tree() or ctl.size.x < 8.0 or ctl.size.y < 8.0:
			continue
		if ctl is Label and (ctl as Label).text.strip_edges() == "":
			continue
		out.append(ctl.get_global_rect())
	var held: Control = hud.player.station_craft.held_slot if hud.player and hud.player.station_craft else null
	if held and held.is_visible_in_tree():
		out.append(Rect2(held.get_global_rect().position, held.size + Vector2(0, 18)))
	var fig := figure_rect(hud)
	if fig.has_area():
		out.append(fig)
	# The open pet radial: a creature plate drew over its Animals label, a "Bush Berries" pill in its centre.
	var pet_radial: PetRadial = hud.player.pets.menu if hud.player and hud.player.pets else null
	if pet_radial and pet_radial.visible:
		out.append(pet_radial.ring_rect())
		out.append_array(pet_radial.label_rects)
	return out

## The survivor on screen, head to name. Moving text keeps off it (a notice and a creature plate sat
## on the survivor at the centre of a landscape phone); the HUD's fixed controls do not need to.
# ASSUMPTION: the survivor stands about 1.8 m tall.
static func figure_rect(hud: HuntHud) -> Rect2:
	var cam := hud.get_viewport().get_camera_3d() if hud.is_inside_tree() else null
	if cam == null or hud.player == null:
		return Rect2()
	var plate := nameplate_rect(cam, hud.player, hud._font)
	var head := cam.unproject_position(hud.player.get_global_transform_interpolated().origin + Vector3(0.0, 1.8, 0.0))
	var w := maxf(plate.size.x, 44.0)
	return Rect2(plate.get_center().x - w * 0.5, head.y, w, maxf(0.0, plate.end.y - head.y))

## The survivor's name under its feet, in screen space. Radial labels keep off it (the gather
## radial's option label covered it on a landscape phone).
static func nameplate_rect(cam: Camera3D, who: Player, font: Font) -> Rect2:
	var p := cam.unproject_position(nameplate_anchor(who))
	var nw := font.get_string_size(who.display_name(), HORIZONTAL_ALIGNMENT_CENTER, -1, HuntHud.NAME_PX).x
	return Rect2(p.x - nw * 0.5, p.y + 20.0 - HuntHud.NAME_PX, nw + 1.0, HuntHud.NAME_PX + 6.0)

## The world point the name hangs from. Seated or lying, the visual is lowered to the ground
## (PlayerAnim._ground_sleep_visual) and the anchor follows it down, so the name stays under her and off
## the torso (REST pre-merge fix). It rides the visual's tween, so it glides rather than snaps.
static func nameplate_anchor(who: Player) -> Vector3:
	var sink := minf(0.0, who.visual.position.y - who.anim._visual_rest_y) if who.visual and who.anim else 0.0
	return who.get_global_transform_interpolated().origin + Vector3(0, sink - 0.05, 0)
