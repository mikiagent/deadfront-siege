class_name InvActions
extends RefCounted
## The actions an inspected item offers (spec 13 s10: only valid ones) and what each one runs.
## The UI never edits an Inventory: every action goes through the player's PlayerActions verbs
## (or a hook another package sets), so online play sends the same intents.
## ctx = {where: &"bag" | &"storage" | &"cargo" | &"equipment" | &"picker", player, slot?, container?}

## Set by the market package (W3-EXCHANGE): called with the exact uid to open Sell prefilled.
## Unset, Sell on Market is not offered (owner 2026-10-20: the market is an online feature).
static var sell_handler: Callable
## Set by the package that owns dropping (a loot bag at the feet); unset, Drop is not offered.
static var drop_handler: Callable

const LABELS := {
	&"eat": "Eat", &"equip": "Equip", &"unequip": "Unequip", &"hold": "Hold", &"place": "Place",
	&"quick1": "Quick Food 1", &"quick2": "Quick Food 2", &"feed": "Feed Pet", &"lock": "Lock",
	&"unlock": "Unlock", &"sell": "Sell on Market", &"drop": "Drop",
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
	if where == &"equipment":
		out.append(&"unequip")
		return out
	if where != &"bag":
		return out
	var locked := stack.is_locked()
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
	if player == null:
		return false
	var inv := player.inventory
	var stack: ItemStack = inv.slots[index] if index >= 0 and index < inv.slot_count else null
	var pa = player.actions # untyped: the PlayerActions verbs below come from the INVUI hooks patch
	match action:
		&"unequip":
			return pa.unequip(StringName(str(ctx.get("slot", ""))))
		&"lock": # toggles, like the toolbar square
			return stack != null and pa.set_locked(index, not stack.is_locked())
		&"unlock":
			return stack != null and pa.set_locked(index, false)
	if stack == null:
		return false
	match action:
		&"equip":
			return pa.equip_at(index, Inventory.slot_for(stack.def()))
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
	return false

## Actions that leave the bag screen for the world (eat, place): the family closes first.
static func closes_ui(action: StringName) -> bool:
	return action in [&"eat", &"place"]
