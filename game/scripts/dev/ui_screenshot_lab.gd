extends Node3D
## Opens the major screens at 1600x900 and 390x844 and checks clipping, long strings and counts.

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(390, 844)]
const SHOT_DIR := "/tmp/deadfront-ui-shots"

var _fails: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var kit := LabKit.build(self, 40.0)
	Game.debug_overlay = false
	var player: Player = kit["player"]
	World.player_name = "Stegosaurus Compsognathus"
	World.occupation = "Gatherer"
	World.pioneer_level = 100
	LabKit.give(player, &"stone", 999)
	for id in [&"stegosaurus", &"compsognathus", &"protoceratops"]:
		var rec := PetRecord.from_def(Data.creature(id), &"B")
		rec.level = 100
		rec.xp = 18
		if id == &"stegosaurus":
			rec.respawn_left = 999.0
		player.bonded.append(rec)
	await get_tree().process_frame
	for size in SIZES:
		await _audit_size(player, size)
	if _fails.is_empty():
		print("[uishot] PASS screens=hud,inventory,animals,craft,atlas,death,radial sizes=1600x900,390x844 shots=%s" % SHOT_DIR)
		get_tree().quit(0)
	else:
		for failure in _fails:
			print("[uishot] FAIL %s" % failure)
		get_tree().quit(1)

func _audit_size(player: Player, size: Vector2i) -> void:
	print("[uishot] size %s" % size)
	var host := _viewport(size)
	if host == null:
		_fails.append("viewport host missing at %s" % size)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var view := host.size
	_expect(is_equal_approx(view.x, float(size.x)) and is_equal_approx(view.y, float(size.y)), "viewport host is %s, got %s" % [size, view])
	_check_tokens(view)
	var ui: InventoryUI = preload("res://scenes/ui/inventory.tscn").instantiate()
	host.add_child(ui)
	ui.bind(player.inventory, player)
	ui.visible = true
	ui.rebuild()
	await get_tree().process_frame
	_audit_tree(ui, view, "inventory")
	_expect(ui._grid.columns == 5, "inventory keeps a 5-column bag at %s" % size)
	_expect(ui._profile != null and ui._profile.text.contains("Lv."), "inventory profile is present at %s" % size)
	_expect(not ui._profile.text.contains("Stegosaurus Compsognathus") or ui._profile.size.x >= 160.0, "long survivor name has room or an ellipsis at %s" % size)
	await _shot(host, "inventory_%dx%d" % [size.x, size.y])
	ui.queue_free()
	var animals := AnimalScreen.new()
	host.add_child(animals)
	animals.open(player)
	await get_tree().process_frame
	_audit_tree(animals, view, "animals")
	_expect(animals._list.get_child_count() == 3, "animal roster count at %s" % size)
	_expect(animals._detail.text.contains("GROWTH / POTENTIAL"), "growth header stays visible at %s" % size)
	_expect(animals._detail.text.contains("Ranged Defense") or animals._detail.text.contains("Ranged defense"), "long stat name is reserved at %s" % size)
	_expect(animals._active.get_child_count() == Player.MAX_PETS_OUT, "three active slots are pinned at %s" % size)
	await _shot(host, "animals_%dx%d" % [size.x, size.y])
	animals.queue_free()
	var craft: CraftUI = preload("res://scenes/ui/craft.tscn").instantiate()
	host.add_child(craft)
	craft.bind(player)
	craft.show_ui()
	await get_tree().process_frame
	_audit_tree(craft, view, "craft")
	_expect(craft._detail != null and craft._detail.get_child_count() > 0, "craft detail column is filled at %s" % size)
	await _shot(host, "craft_%dx%d" % [size.x, size.y])
	craft.queue_free()
	var hud := HuntHud.new()
	hud.bind(player)
	host.add_child(hud)
	await get_tree().process_frame
	await _shot(host, "hud_%dx%d" % [size.x, size.y])
	hud.open_map()
	await get_tree().process_frame
	var map := hud.get_node_or_null("MapLayer/MapScreen") as MapScreen
	if map == null:
		_fails.append("atlas missing at %s" % size)
	else:
		_audit_tree(map, view, "atlas")
		_expect(map._cards != null and map._cards.get_child_count() > 0, "atlas region cards at %s" % size)
		await _shot(host, "atlas_%dx%d" % [size.x, size.y])
		map.close()
	player.downed_by = "Stegosaurus"
	player.dead = true
	hud._tick_death(1.0)
	await get_tree().process_frame
	var death := _find_named(hud, "DeathCard")
	_expect(death != null, "death card exists at %s" % size)
	if death:
		_audit_tree(death, view, "death")
	await _shot(host, "death_%dx%d" % [size.x, size.y])
	player.respawn()
	hud._tick_death(2.0)
	var death_panel := hud.get_node_or_null("DeathLayer/Death") as CanvasItem
	if death_panel:
		death_panel.visible = false
	var radial := GatherRadial.new()
	host.add_child(radial)
	var anchor := Node3D.new()
	host.add_child(anchor)
	var options: Array = [
		{"item": "obsidian_pickaxe", "seconds": 1.8, "left": 999, "tool": "none", "min": 1, "max": 1},
		{"item": "stone", "seconds": 1.2, "left": 100, "tool": "none", "min": 1, "max": 1},
	]
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.0
	cam.position = Vector3(0, 12, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	host.get_viewport().add_child(cam)
	anchor.position = Vector3(2.4, 0, 0.6)
	radial.open_options(anchor, "Ancient Tree", 100, 1.0, options, player.inventory)
	await get_tree().process_frame
	_expect(radial._buttons.size() == 2, "gather radial opened at %s" % size)
	for button in radial._buttons:
		var rect := button.get_global_rect()
		_expect(rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= view.x + 1.0 and rect.end.y <= view.y + 1.0, "radial hex inside %s" % size)
	await _shot(host, "radial_%dx%d" % [size.x, size.y])
	radial.queue_free()
	hud.queue_free()

func _viewport(size: Vector2i) -> Control:
	var vp := SubViewport.new()
	vp.name = "Shot%s" % size.x
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	var root := Control.new()
	root.position = Vector2.ZERO
	root.size = Vector2(size)
	root.custom_minimum_size = Vector2(size)
	vp.add_child(root)
	return root

func _check_tokens(view: Vector2) -> void:
	_expect(UiTokens.body(view) >= 14, "body floor %s" % view)
	_expect(UiTokens.meta(view) >= 12, "meta floor %s" % view)

func _audit_tree(node: Node, view: Vector2, tag: String) -> void:
	_audit_tree_from(node, node, view, tag)

func _audit_tree_from(node: Node, host: Node, view: Vector2, tag: String) -> void:
	if node is Control and host is Control:
		var control := node as Control
		if control.visible and not _in_scroll(control) and control.size.x > 8.0 and control.size.y > 8.0:
			var local := _local_rect(control, host as Control)
			if local.position.x < -24.0 or local.position.y < -24.0 or local.end.x > view.x + 8.0 or local.end.y > view.y + 8.0:
				_fails.append("%s control outside %s: %s at %s" % [tag, view, control.name, local])
	for child in node.get_children():
		_audit_tree_from(child, host, view, tag)

func _local_rect(control: Control, host: Control) -> Rect2:
	var xf := host.get_global_transform_with_canvas().affine_inverse() * control.get_global_transform_with_canvas()
	return Rect2(xf.origin, control.size * xf.get_scale())

func _in_scroll(node: Node) -> bool:
	var cursor := node.get_parent()
	while cursor:
		if cursor is ScrollContainer:
			return true
		cursor = cursor.get_parent()
	return false

func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found:
			return found
	return null

func _shot(host: Control, file_name: String) -> void:
	var vp := host.get_viewport()
	if vp == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.get_width() < 8:
		print("[uishot] pixels unavailable %s" % file_name)
		return
	var path := "%s/%s.png" % [SHOT_DIR, file_name]
	img.save_png(path)
	print("[uishot] shot %s %dx%d" % [path, img.get_width(), img.get_height()])

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)
