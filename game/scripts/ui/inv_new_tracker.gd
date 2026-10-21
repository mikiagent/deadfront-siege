class_name InvNewTracker
extends RefCounted
## Durango's blue NEW tag (spec 13 s7). A uid'd instance that enters the bag during play (pickup,
## loot, craft output, take from storage) gets the "new" flag; selecting it acknowledges it. Never
## on fungible stacks (a flag would stop them merging) and never on a load (see rebaseline).
# ASSUMPTION: no NEW rule existed in the game; this one is design assumption 3.

## Inventory instance id -> the frame a save load was announced for it.
static var _loading := {}

var inventory: Inventory
var _known := {}

func bind(inv: Inventory) -> void:
	if inventory == inv:
		return
	if inventory and inventory.changed.is_connected(_on_changed):
		inventory.changed.disconnect(_on_changed)
	inventory = inv
	_known.clear()
	_absorb(false)
	if inventory:
		inventory.changed.connect(_on_changed)

## Clears NEW on the instance the player looked at.
func acknowledge(stack: ItemStack) -> void:
	if stack:
		stack.set_flag(&"new", false)

## Call right before load_array: everything that arrives this frame is the save, not a pickup.
static func rebaseline(inv: Inventory) -> void:
	if inv:
		_loading[inv.get_instance_id()] = Engine.get_process_frames()

func _on_changed() -> void:
	var at: Variant = _loading.get(inventory.get_instance_id())
	_absorb(at == null or int(at) != Engine.get_process_frames())

## Records every uid in the bag and on the body; with `flag`, unseen bag instances become NEW.
func _absorb(flag: bool) -> void:
	if inventory == null:
		return
	for s in inventory.slots:
		if s == null or s.uid == "" or s.def_id == Inventory.LOCK or _known.has(s.uid):
			continue
		_known[s.uid] = true
		if flag and not s.is_fungible():
			s.set_flag(&"new", true)
	for v: Variant in inventory.equipment.values():
		if v is ItemStack:
			_known[(v as ItemStack).uid] = true
