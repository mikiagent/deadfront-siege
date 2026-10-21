class_name InvActions
extends RefCounted
## The actions an inspected item offers (spec 13 s10: only valid ones) and what each one runs.
## The UI never edits an Inventory: every action goes through the player's PlayerActions verbs
## (or a hook another package sets), so online play sends the same intents.
## ctx = {where: &"bag" | &"storage" | &"cargo" | &"equipment" | &"picker", player, slot?, worn?, container?}
## In &"equipment" (Character / Equipment candidates) `worn` marks the instance in `slot` now.

## Set by the market package (W3-EXCHANGE): called with the exact uid to open Sell prefilled.
## Unset, Sell on Market is not offered (owner 2026-10-20: the market is an online feature).
static var sell_handler: Callable
## Set by the package that owns dropping (a loot bag at the feet); unset, Drop is not offered.
static var drop_handler: Callable
## Why the last run() was refused ("" when it applied), for the screen's status line: the HUD
## notice sits under the opaque bag family.
static var last_refusal := ""

const LABELS := {
	&"eat": "Eat", &"equip": "Equip", &"unequip": "Unequip", &"hold": "Hold", &"place": "Place",
	&"quick1": "Quick Food 1", &"quick2": "Quick Food 2", &"feed": "Feed Pet", &"lock": "Lock",
	&"unlock": "Unlock", &"sell": "Sell on Market", &"drop": "Drop",
	&"store": "Store", &"take": "Take", &"take_all": "Take All", &"use": "Use",
	&"discard": "Discard", &"keep": "Keep",
}

static func label(action: StringName) -> String:
	return str(LABELS.get(action, str(action).capitalize()))

## Valid actions for `stack` in `ctx`; the first is the panel's yellow primary.
static func valid(stack: ItemStack, ctx: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if stack == null or stack.def_id == Inventory.LOCK:
		return out
	var where: StringName = ctx.get("where", &"bag")
	var player: Player = ctx.get("player") as Player
	var d := stack.def()
	var locked := stack.is_locked()
	if where == &"equipment":
		if ctx.get("worn", true):
			out.append(&"unequip")
		elif not locked: # a locked candidate says why instead (Equipment's requirement line)
			out.append(&"hold" if ctx.get("slot") == &"tool" else &"equip")
		return out
	if where != &"bag":
		return out
	var inv := player.inventory if player else null
	if not locked and Inventory.slot_for(d) != &"":
		out.append(&"equip")
	if not locked and d and d.tool_class not in [&"", &"none"] and Inventory.slot_for(d) == &"" \
			and (inv == null or inv.equipped_tool_index < 0 or inv.slots[inv.equipped_tool_index] != stack):
		out.append(&"hold")
	if Food.is_food(stack):
		out.append(&"eat")
	if d and d.place_as != &"":
		out.append(&"place")
	if Food.is_food(stack) and player and player.summoned_pet != null:
		out.append(&"feed")
	if Food.is_food(stack):
		out.append_array([&"quick1", &"quick2"])
	out.append(&"unlock" if locked else &"lock")
	if not locked and sell_handler.is_valid() and stack.uid != "":
		out.append(&"sell")
	if not locked and drop_handler.is_valid():
		out.append(&"drop")
	return out

## Runs `action` on bag slot `index` (or ctx.slot for unequip). True when it applied (offline) or
## was sent; the screen refreshes from the inventory's own `changed`.
static func run(action: StringName, player: Player, index: int, ctx: Dictionary = {}) -> bool:
	last_refusal = ""
	if player == null:
		return false
	var inv := player.inventory
	var stack: ItemStack = inv.slots[index] if index >= 0 and index < inv.slot_count else null
	var pa = player.actions # untyped: the PlayerActions verbs below come from the INVUI hooks patch
	match action:
		&"unequip":
			var off: bool = pa.unequip(StringName(str(ctx.get("slot", ""))))
			if not off and not pa.online:
				last_refusal = "Bag is full."
				player.notice(last_refusal) # the gear stays worn (never dropped)
			return off
		&"lock": # toggles, like the toolbar square
			return stack != null and pa.set_locked(index, not stack.is_locked())
		&"unlock":
			return stack != null and pa.set_locked(index, false)
	if stack == null:
		return false
	match action:
		&"equip":
			var on: bool = pa.equip_at(index, StringName(str(ctx.get("slot", Inventory.slot_for(stack.def())))))
			if not on and not pa.online:
				last_refusal = "Bag is full."
				player.notice(last_refusal) # wearing it would shrink the bag past what it holds
			return on
		&"hold":
			return pa.hold_tool(index)
		&"eat":
			return player.begin_eat_slot(index)
		&"feed":
			return player.feed_summoned_pet_slot(index)
		&"quick1", &"quick2":
			inv.set_quick_food(0 if action == &"quick1" else 1, stack.def_id)
			return true
		&"place":
			player.placer.begin(stack.def().place_as)
			TouchControls.set_context(&"place")
			return true
		&"sell":
			if stack.is_locked() or not sell_handler.is_valid():
				return false
			sell_handler.call(stack.uid)
			return true
		&"drop":
			if stack.is_locked() or not drop_handler.is_valid():
				return false
			drop_handler.call(stack.uid)
			return true
		&"discard": # the in-game Bag's trash, after its confirm
			return not stack.is_locked() and bool(pa.discard(index))
	return false

## The trash square works offline only: the server has no discard op yet (W3), and a lock protects
## an item from it (spec 13 s9).
static func can_discard(player: Player) -> bool:
	return player != null and not bool(player.actions.get("online"))

## True when every bag slot in `indices` holds a locked item (and there is at least one).
static func all_locked(inv: Inventory, indices: Array[int]) -> bool:
	if inv == null or indices.is_empty():
		return false
	for i in indices:
		if inv.slots[i] == null or not inv.slots[i].is_locked():
			return false
	return true

## The toolbar's Lock square on a selection: all locked -> unlock them all; otherwise lock the rest.
static func toggle_locks(player: Player, indices: Array[int], ctx: Dictionary) -> void:
	if player == null or indices.is_empty():
		return
	var want := not all_locked(player.inventory, indices)
	for i in indices:
		var s := player.inventory.slots[i]
		if s and s.is_locked() != want:
			run(&"lock", player, i, ctx)

## Actions that leave the bag screen (eat and place for the world, sell for the market screen):
## the family closes first.
static func closes_ui(action: StringName) -> bool:
	return action in [&"eat", &"place", &"sell"]
