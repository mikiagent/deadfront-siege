class_name StructureSheet
extends RefCounted
## Touch rows for modular building, filled into the HUD's bottom sheet (hunt_hud.gd calls these):
## the Build sheet's tier row and piece buttons, and a structure's card (door, chest, sign actions,
## Upgrade / Repair / Demolish, and Repair all / Upgrade all for the whole building). `btn` is the
## HUD's button maker func(text: String, cb: Callable), `refresh` rebuilds the open sheet in place,
## `close` closes it. Every action goes through BuildPlacer, which pays and gives the notice.

static var tier: StringName = &"thatch"  # the tier the Build sheet's piece buttons place
static var card: StructurePiece          # the piece whose card is open

static func fill_build(player: Player, btn: Callable, refresh: Callable, close: Callable) -> void:
	for t in (StructurePiece.defs().get("tiers", {}) as Dictionary):
		var t_id := StringName(str(t))
		var td := StructurePiece.tier_def(t_id)
		var text := ("● %s" if t_id == tier else "%s") % str(td.get("label", t))
		if StructurePlacer.tier_gate(player, t_id) != "":
			text += "\nConstruction %d" % int(td.get("requires_level", 0))
		btn.call(text, func () -> void:
			tier = t_id
			refresh.call())
	for k in (StructurePiece.defs().get("pieces", {}) as Dictionary):
		var kind := StringName(str(k))
		if StructurePiece.blueprint(kind, tier).is_empty():
			continue
		btn.call("%s\n%s" % [str(StructurePiece.piece_def(kind).get("label", k)), StructurePlacer.cost_text(StructurePiece.cost(kind, tier))], func () -> void:
			close.call()
			player.placer.begin_piece(kind, tier))

## Fills the card of `card` and returns the sheet's title.
static func fill_card(box: Container, player: Player, btn: Callable, close: Callable) -> String:
	var sp := card
	if not is_instance_valid(sp) or sp.is_queued_for_deletion():
		return "Gone"
	var label := str(StructurePiece.piece_def(sp.kind).get("label", sp.kind))
	if sp.kind == &"door":
		btn.call("Close door" if sp.door_open else "Open door", func () -> void:
			sp.interact(player)
			close.call())
	if sp.storage:
		btn.call("Open %s\n%d / %d slots" % [label.to_lower(), sp.storage.used_slots(), sp.storage.slot_count], func () -> void:
			close.call()
			if player.ui:
				player.ui.show_storage(sp.storage, player, {"title": label, "allow_deposit": true}))
	if sp.kind == &"sign":
		var edit := LineEdit.new()
		edit.text = sp.sign_text
		edit.placeholder_text = "Sign text"
		edit.max_length = int(StructurePiece.piece_def(&"sign").get("text_max", 48))
		edit.custom_minimum_size = Vector2(150, UiTokens.TARGET_PRIMARY)
		box.add_child(edit)
		btn.call("Save text", func () -> void:
			sp.set_sign_text(edit.text)
			close.call())
	var up := StructurePlacer.next_tier(sp.tier)
	if up != &"" and not StructurePiece.blueprint(sp.kind, up).is_empty():
		btn.call("Upgrade to %s\n%s" % [str(StructurePiece.tier_def(up).get("label", up)), StructurePlacer.cost_text(StructurePiece.cost(sp.kind, up))], func () -> void:
			close.call()
			player.placer.upgrade(sp, up, player))
	var fix := StructurePlacer.repair_cost(sp)
	if not fix.is_empty():
		btn.call("Repair\n%s" % StructurePlacer.cost_text(fix), func () -> void:
			close.call()
			player.placer.repair(sp, player))
	btn.call("Demolish\nhalf back", func () -> void:
		close.call()
		player.placer.demolish(sp, player))
	var all_fix := StructurePlacer.repair_all_plan(sp)
	if (all_fix["pieces"] as Array).size() > 1:
		btn.call("Repair building (%d)\n%s" % [(all_fix["pieces"] as Array).size(), StructurePlacer.cost_text(all_fix["cost"])], func () -> void:
			close.call()
			player.placer.repair_all(sp, player))
	if up != &"":
		var all_up := StructurePlacer.upgrade_all_plan(sp, up)
		if (all_up["pieces"] as Array).size() > 1:
			btn.call("Building to %s (%d)\n%s" % [str(StructurePiece.tier_def(up).get("label", up)), (all_up["pieces"] as Array).size(), StructurePlacer.cost_text(all_up["cost"])], func () -> void:
				close.call()
				player.placer.upgrade_all(sp, up, player))
	return "%s %s  %.0f / %.0f" % [str(StructurePiece.tier_def(sp.tier).get("label", sp.tier)), label, sp.health.hp, sp.health.max_hp]
