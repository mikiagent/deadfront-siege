class_name SnapTouch
extends RefCounted
## snap_build_lab --snap-touch: the build loop driven only by screen touches, as a phone sends them
## (InputEventScreenTouch press/release at screen points: the HUD's BUILD hex and sheet buttons,
## the ROTATE / PLACE / CANCEL hexes, the world for aiming and for tapping a piece). Places two wood
## foundations, a wall, a chest and a sign beside the lab's house, then through each piece's card
## upgrades the wall to stone, repairs it, opens the chest, writes the sign and demolishes the wall.
## Needs the HUD and player hooks (W2-BUILDSYS report). Windowed with --snap-shots=<path stem>, it
## also saves <stem>_<step>.png at each step (not --shot=, which quits the game after its delay). Fixture: building materials are put in the bag up front.

var lab: Node3D
var player: Player
var hud: Node
var shots := ""
var sg: StructureGrid

func _init(p_lab: Node3D) -> void:
	lab = p_lab
	player = lab.get("_player")
	hud = lab.get_tree().get_first_node_in_group("hud")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--snap-shots="):
			shots = a.substr(13)

func run() -> void:
	var ex: Callable = Callable(lab, "_expect")
	if hud == null or not hud.has_method("open_structure"):
		ex.call(false, "the HUD has the W2-BUILDSYS hook (open_structure)")
		return
	if DisplayServer.get_name() == "headless":
		lab.get_window().size = Vector2i(844, 390)  # headless defaults to 64 x 64: no room for a phone layout
		await _frames(3)
	var mats := {&"plank": 60, &"twine": 30, &"stone": 40}
	for id in mats:
		LabKit.give(player, id, mats[id])
	var a: Vector3 = lab.call("_centre", 5, 0, 0)
	var b: Vector3 = lab.call("_centre", 5, 1, 0)
	player.global_position = b + Vector3(1.6, 1.0, 1.4)
	player.reset_physics_interpolation()
	var cam: IsoCamera = lab.get("_cam")
	cam._target = player
	cam.size = 15.0
	cam._snap()
	await _frames(10)
	sg = lab.call("_sg")
	var o: Vector2i = lab.get("_o")
	# Foundations: BUILD hex -> Wood -> Foundation -> tap the ground -> PLACE (twice) -> CANCEL.
	await _pick_piece("Wood", "Foundation")
	ex.call(player.placer.placing == &"foundation" and player.placer.piece_tier == &"wood", "touch: BUILD, Wood, Foundation select a wood foundation ghost")
	var plank0 := player.inventory.count_of(&"plank")
	await _tap_world(_ground(a))
	await _shot("ghost")
	ex.call(player.placer.valid, "touch: a tap on the ground snaps the ghost (reason '%s')" % player.placer.reason)
	await _tap_hex(1)
	var f1 := sg.piece_at(Vector4i(o.x + 5, o.y, 0, StructurePiece.CELL))
	ex.call(f1 != null and f1.kind == &"foundation", "touch: PLACE puts the foundation in the tapped module")
	ex.call(player.inventory.count_of(&"plank") == plank0 - int(StructurePiece.cost(&"foundation", &"wood").get(&"plank", 0)), "touch: the foundation took its planks")
	await _tap_world(_ground(b))
	await _tap_hex(1)
	ex.call(sg.piece_at(Vector4i(o.x + 5, o.y + 1, 0, StructurePiece.CELL)) != null, "touch: a second tap and PLACE add the next foundation")
	await _tap_hex(2)
	ex.call(player.placer.placing == &"", "touch: CANCEL ends placing")
	# A wall on the west edge of the first foundation (the far side from the iso camera, so the chest
	# and sign stay tappable in front of it), rotated once on the way.
	await _pick_piece("", "Wall")
	var west := Vector3(a.x - 0.8, f1.floor0 if f1 else _ground(a).y, a.z)
	await _tap_world(west)
	var rot0 := player.placer.rot_step
	await _tap_hex(0)
	ex.call(player.placer.rot_step == posmod(rot0 + 1, 4), "touch: ROTATE turns the ghost")
	await _tap_world(west)
	await _tap_hex(1)
	var wall := sg.piece_at(Vector4i(o.x + 5, o.y, 0, StructurePiece.EDGE_X))
	ex.call(wall != null and wall.kind == &"wall", "touch: a wall placed on the tapped edge")
	await _tap_hex(2)
	# A chest and a sign, one per foundation.
	await _pick_piece("", "Chest")
	await _tap_world(_ground(a) + Vector3(-0.3, 0, -0.3))
	await _tap_hex(1)
	await _tap_hex(2)
	await _pick_piece("", "Signboard")
	await _tap_world(_ground(b) + Vector3(-0.3, 0, 0.3))
	await _tap_hex(1)
	await _tap_hex(2)
	var chest := sg.piece_at(Vector4i(o.x + 5, o.y, 0, StructurePiece.ON_FLOOR))
	var sign := sg.piece_at(Vector4i(o.x + 5, o.y + 1, 0, StructurePiece.ON_FLOOR))
	ex.call(chest != null and chest.kind == &"chest" and chest.storage != null, "touch: a chest stands on the first foundation")
	ex.call(sign != null and sign.kind == &"signboard", "touch: a sign stands on the second foundation")
	await _shot("placed")
	if wall == null or chest == null or sign == null:
		return
	# The wall's card: upgrade to stone, then repair after a bite, then demolish.
	await _tap_world(wall.global_position + Vector3(0, 1.3, 0))
	ex.call(hud.get("_sheet_kind") == &"structure" and StructureSheet.card == wall, "touch: tapping the wall opens its card")
	await _shot("card")
	var stone0 := player.inventory.count_of(&"stone")
	await _tap_button("Upgrade to Stone")
	ex.call(wall.tier == &"stone" and is_equal_approx(wall.health.hp, StructurePiece.max_durability(&"wall", &"stone")), "touch: Upgrade to Stone swaps the wall in place at full stone durability")
	ex.call(player.inventory.count_of(&"stone") == stone0 - int(StructurePiece.cost(&"wall", &"stone").get(&"stone", 0)), "touch: the upgrade took the stone blueprint")
	wall.health.take_damage(900.0)
	var fix := StructurePlacer.repair_cost(wall)
	var hp_hit := wall.health.hp
	await _tap_world(wall.global_position + Vector3(0, 1.3, 0))
	await _tap_button("Repair")
	ex.call(hp_hit < wall.health.max_hp and is_equal_approx(wall.health.hp, wall.health.max_hp) and not fix.is_empty(), "touch: Repair brings the bitten wall back (%.0f -> %.0f for %s)" % [hp_hit, wall.health.hp, fix])
	# The chest's card opens its storage; the sign's card writes its text.
	await _tap_world(chest.global_position + Vector3(0, 0.4, 0))
	await _tap_button("Open chest")
	ex.call(player.ui != null and player.ui.visible and player.ui.get("pet_bag") == chest.storage, "touch: Open chest shows the chest's storage")
	await _shot("chest")
	player.ui.visible = false
	await _tap_world(sign.global_position + Vector3(0, 1.25, 0))
	var edit := _find(hud, func (n: Node) -> bool: return n is LineEdit) as LineEdit
	if edit:
		edit.text = "Raptors east"  # the phone's keyboard types into the focused LineEdit
	await _tap_button("Save text")
	ex.call(sign.sign_text == "Raptors east", "touch: the sign card saves its text ('%s')" % sign.sign_text)
	await _shot("sign")
	var refund0 := player.inventory.count_of(&"stone")
	await _tap_world(wall.global_position + Vector3(0, 1.3, 0))
	await _tap_button("Demolish")
	await _frames(2)
	ex.call(not is_instance_valid(wall) or wall.is_queued_for_deletion(), "touch: Demolish takes the wall down")
	ex.call(player.inventory.count_of(&"stone") > refund0, "touch: the demolished wall refunds part of its stone")
	# The house's card offers the whole building.
	var house_wall: StructurePiece = sg.piece_at(Vector4i(o.x + 1, o.y + 3, 0, StructurePiece.DOOR_Z))  # the door faces the camera
	if house_wall:
		await _tap_world(house_wall.global_position + Vector3(0, 1.0, 0))
		var whole := _find(hud, func (n: Node) -> bool: return n is Button and (n as Button).text.begins_with("Building to"))
		ex.call(whole != null, "touch: a house wall's card offers the whole building's upgrade (%s)" % ((whole as Button).text.replace("\n", " ") if whole else "none"))
		await _shot("house_card")
		await _tap_control(hud.find_child("SheetClose", true, false) as Control)

# ------------------------------------------------------------------ touches

func _pick_piece(tier_prefix: String, piece: String) -> void:
	if hud.get("_sheet_kind") != &"":
		print("[snap] a sheet was still open: tapping its Close")
		await _tap_control(hud.find_child("SheetClose", true, false) as Control)
	await _tap_control(hud.get("_build_hex"))
	if hud.get("_sheet_kind") != &"build":
		lab.call("_expect", false, "touch: BUILD opens the build sheet")
	if tier_prefix != "":
		await _tap_button(tier_prefix)
	await _tap_button(piece + "\n")

func _tap_hex(i: int) -> void:
	var hexes: Array = hud.get("_place_hexes")
	await _tap_control(hexes[i])

func _tap_button(prefix: String) -> void:
	await _frames(4)  # the sheet lays itself out over two frames (HuntHud._toggle_sheet)
	var b := _find(hud, func (n: Node) -> bool: return n is Button and (n as Button).is_visible_in_tree() and ((n as Button).text.begins_with(prefix) or (n as Button).text.begins_with("● " + prefix)))
	if b == null:
		lab.call("_expect", false, "touch: a '%s' button on screen" % prefix.strip_edges())
		return
	var sc := hud.get("_sheet_rows") as ScrollContainer
	var r := (b as Control).get_global_rect()
	if sc and sc.is_ancestor_of(b):
		sc.ensure_control_visible(b as Control)
		await _frames(3)
		r = (b as Control).get_global_rect().intersection(sc.get_global_rect())  # tap the part the player sees
	if r.size.y < 8.0:
		lab.call("_expect", false, "touch: '%s' scrolled into view" % prefix.strip_edges())
		return
	await _tap(r.get_center())

func _tap_control(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		lab.call("_expect", false, "touch: control on screen (%s)" % (c.name if c else "null"))
		return
	await _tap(c.get_global_rect().get_center())

## Tap a world point the way a player would: on visible ground, so when a HUD hex covers the point
## the tap moves up to 0.6 m within the same module (the ghost still snaps to the same socket).
func _tap_world(at: Vector3) -> void:
	var cam := lab.get_viewport().get_camera_3d()
	var pos := cam.unproject_position(at)
	for off in [Vector3.ZERO, Vector3(0.6, 0, 0), Vector3(0, 0, 0.6), Vector3(-0.6, 0, 0), Vector3(0, 0, -0.6), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, -0.5)]:
		pos = cam.unproject_position(at + off)
		if not await _covered(pos):
			break
	await _tap(pos)

## The game's own test (PlayerInput.tap_blocked: the control under the pointer stops input).
func _covered(pos: Vector2) -> bool:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	Input.parse_input_event(mv)
	await _frames(1)
	return bool(player.controls.tap_blocked())

func _tap(pos: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(3)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(4)

## The terrain under a lattice point (the touch pads east of the house have their own floor).
func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, sg._terrain_y(p), p.z)

func _frames(n: int) -> void:
	for i in n:
		await lab.get_tree().process_frame

func _shot(step: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(8)
	RenderingServer.force_draw()  # an occluded window throttles its redraws; the grab must be this frame
	var path := "%s_%s.png" % [shots, step]
	lab.get_viewport().get_texture().get_image().save_png(path)
	print("[snap] shot %s" % path)

static func _find(root: Node, pred: Callable) -> Node:
	for c in root.get_children():
		if pred.call(c):
			return c
		var deep := _find(c, pred)
		if deep:
			return deep
	return null
