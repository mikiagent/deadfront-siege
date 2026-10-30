class_name RepairPicker
extends TribeAssignPicker
## P3 GEARREPAIR: the station menu's REPAIR list (TribeAssignPicker's modal, 64 px rows). One row per worn
## or broken item the survivor carries or wears: "Stone Axe 12/50 · 2 Stone material · max 50 -> 40
## (repair 1 of 4)". A row that can't be repaired here shows why ("worn out: repaired 4 times", "repair
## at the anvil", "needs 2 Stone material") and can't be tapped. A tap repairs, says so and refreshes.

var player: Player
var station_id: StringName = &""

static func open_for(parent: Node, p: Player, sid: StringName) -> RepairPicker:
	var old := parent.get_node_or_null("TribeAssignPicker")
	if old:
		old.queue_free()
	var pk := RepairPicker.new()
	pk.name = "TribeAssignPicker"  # one modal at a time, shared with Assign
	pk.player = p
	pk.station_id = sid
	parent.add_child(pk)
	pk.refresh()
	return pk

func refresh() -> void:
	title_label.text = "Repair at the %s" % str(station_id).replace("_", " ")
	for c in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	var inv := player.inventory if player else null
	var items: Array[ItemStack] = GearRepair.damaged_in(inv) if inv else []
	if items.is_empty():
		rows_box.add_child(CraftUI._label("Nothing worn: every tool and piece of armor is at full durability.", 18, UiTokens.MUTED))
		return
	for i in items.size():
		var s := items[i]
		var why := GearRepair.block_reason(s, inv, station_id)
		var nm := s.def().display_name if s.def() else str(s.def_id)
		var head := "%s %d/%d" % [nm, s.durability, s.max_durability]
		var line := head + " · " + GearRepair.text(s).trim_prefix("Repair at %s: " % str(station_id).replace("_", " ").capitalize()) if why == "" else "%s — %s" % [head, why]
		var b := CraftUI.mk_btn(line, _repair.bind(s), Vector2(0, 64), "cta" if why == "" else "ghost")
		b.name = "Repair_%d" % i
		b.disabled = why != ""
		b.add_theme_font_size_override("font_size", 20)
		if why != "":
			b.add_theme_color_override("font_disabled_color", UiTokens.LIFE)
		rows_box.add_child(b)

func _repair(s: ItemStack) -> void:
	var why := GearRepair.repair(s, player.inventory, station_id)
	var nm := s.def().display_name if s.def() else str(s.def_id)
	if player:
		player.notice("%s repaired: max %d (repair %d of %d)" % [nm, s.max_durability, GearRepair.count(s), GearRepair.max_repairs()] if why == "" else "Can't repair %s: %s" % [nm, why])
	refresh()
